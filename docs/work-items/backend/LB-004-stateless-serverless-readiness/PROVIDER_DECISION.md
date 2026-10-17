---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# PROVIDER DECISION — LB-004B.0/B.1 (histórico) + LB-004B.2 (vigente)

## Estado LB-004B.2 (vigente — reemplaza la sección "Estado LB-004B.1")

```text
STORAGE_PROVIDER: MINIO
PROVIDER_DECISION_STATUS: APPROVED
OBJECT_VISIBILITY: PRIVATE
STORAGE_ACCESS: BACKEND_ONLY
DOWNLOAD: BACKEND_MEDIATED
UPLOAD: BACKEND_MEDIATED
PRESIGNED_URLS: NOT_USED
```

Decisión humana explícita recibida en LB-004B.2; reemplaza `AZURE_BLOB_STORAGE` (sección histórica
abajo). Texto completo de la decisión, alcance y límites: [PROFESSOR_DECISION](PROFESSOR_DECISION.md).
MinIO corre local vía `infra/files/compose.yaml` (bucket privado `asistencias-soportes`, volumen Docker
dedicado que pertenece al storage, no al backend — ver [MINIO_STORAGE_CONTRACT](MINIO_STORAGE_CONTRACT.md)).
Esta decisión es de **nivel arquitectónico/contractual**: qué provider satisface el requisito y cómo
se expone por Port/HTTP. No cambia ninguna otra decisión congelada (ownership, file identity,
contrato HTTP conceptual, tamaño máximo) — esas heredan sin modificación desde LB-004B.1.

La comparación local-fs / shared-fs / Azure Blob de la sección histórica sigue siendo válida como
evidencia de **por qué no** se usa filesystem local ni compartido (stateless, multi-instancia,
ownership): ese razonamiento aplica igual a MinIO. Solo cambió la columna de provider ganador entre
"Azure Blob" y "MinIO"; ningún argumento en contra de filesystem local/compartido cambia.

## Estado LB-004B.1 (histórico — `SUPERSEDED` por `D-LB004B2-001`)

```text
PROVIDER_DECISION_STATUS: SUPERSEDED (ver Estado LB-004B.2 arriba)
```

Se congela como `APPROVED` en LB-004B.1 conforme a la instrucción de la tarea: no hay evidencia
contraria en este documento ni en `RISKS.md`/`AS_IS.md` que contradiga la selección. Este `APPROVED`
es de **nivel arquitectónico/contractual** (qué provider satisface el requisito y cómo se expone por
Port/HTTP): no aprueba, sustituye ni certifica el provisioning operacional. `STORAGE_PROVIDER`,
`OBJECT_VISIBILITY` y `DOWNLOAD` quedan congelados como se describe abajo. Las precondiciones
operacionales (contenedor privado, permisos mínimos, SLO, IaC) siguen pendientes y siguen siendo
`LB-006`; no se provisiona ni configura nada en esta microfase.

> **Nota de alcance:** el resto de este documento (`Comparación`, `Decisión propuesta` con
> `AZURE_BLOB_STORAGE`, `Rollout y rollback` en 7 pasos con migración de objetos, `Precondiciones`
> orientadas a un recurso Blob operacional) se conserva como evidencia histórica de LB-004B.0/B.1: el
> razonamiento de fondo (por qué no local/compartido) sigue siendo válido, pero los pasos específicos
> de rollout/migración fueron escritos para un provider cloud con objetos preexistentes que migrar.
> MinIO en LB-004B.2 corre local, recién provisionado por `infra/files/compose.yaml`, sin objetos previos que
> migrar — el rollout/contrato equivalente para MinIO está en
> [MINIO_STORAGE_CONTRACT](MINIO_STORAGE_CONTRACT.md).

## Evidencia de ambiente

- Azure es un runtime provider vigente para Key Vault y App Configuration, con `DefaultAzureCredential`, Composition Root y Cloud Integration real de solo lectura validada en ambiente dev por LB-001D.2.
- Esa evidencia no prueba que exista una cuenta/contenedor Blob, permisos, SLO, topología de cómputo ni despliegue productivo. Provisioning/IaC sigue en LB-006.
- **Actualización LB-004B.2:** la norma de arquitectura (`adapter-composition-standard.md §11`) ya
  mencionaba MinIO como ejemplo del flujo objetivo (`ArchivoController -> InputPort -> UseCase ->
  FileStoragePort -> MinioFileStorageAdapter`). Con la decisión humana de `D-LB004B2-001`, MinIO deja
  de ser solo ejemplo normativo y pasa a ser el provider `APPROVED` real de esta línea base; ver
  "Estado LB-004B.2" arriba.

## Comparación

| Criterio | Filesystem local | Filesystem compartido | Azure Blob Storage |
|---|---|---|---|
| Stateless / multi-instancia | no: bytes ligados a la réplica | sí si todas las réplicas montan el mismo volumen | sí: objetos externos accesibles por todas las réplicas autorizadas |
| Durabilidad | depende del disco/host; no demostrada | depende del servicio de archivos y su HA; no existe evidencia del proyecto | servicio de object storage durable; configuración/SLO concretos deben aprobarse operacionalmente |
| Seguridad | permisos del proceso y nombres conocidos; ownership ausente | añade permisos de montaje, pero no resuelve ownership de Application | contenedor privado, identidad autorizada y backend mediador; permite mantener objetos no públicos |
| Provider internals en HTTP | ruta local hoy filtrada indirectamente por nombre guardado | riesgo de acoplar paths/UNC/mounts | puede ocultarse: HTTP expone `fileId`/endpoint backend, no blob URL ni object key |
| Integración Java | ya existe código directo, pero viola la arquitectura target | requiere adapter y operación de mounts | requiere adapter Azure en Infrastructure; el patrón `DefaultAzureCredential` ya existe |
| Rollback | no puede leer objetos creados en Blob | solo si se migran objetos y metadata | soporta rollout por selector; rollback debe permanecer en una release compatible con Blob |
| Coste operacional | bajo localmente, inaceptable para reemplazo de réplica | servicio/mount/backup/HA adicional sin owner evidenciado | nuevo recurso, capacidad, egress, lifecycle y permisos; encaja con el modelo Azure ya operado |
| Evidencia del proyecto | AS-IS confirmado y bloqueante | ninguna | Azure runtime y credenciales existentes; Blob específico aún no provisionado/validado |

## Decisión propuesta

```text
STORAGE_PROVIDER: AZURE_BLOB_STORAGE
PROVIDER_DECISION_STATUS: APPROVED
OBJECT_VISIBILITY: PRIVATE
```

Se selecciona Azure Blob como target porque satisface persistencia multi-instancia, objetos privados y acceso neutral por Port, y porque el proyecto ya tiene un patrón operativo real de identidad Azure. No se selecciona únicamente por “usar Azure”: local falla el requisito principal y shared filesystem carece de evidencia, owner y ventaja contractual frente a object storage.

La selección no autoriza SDK, recursos, credenciales, configuración runtime ni despliegue. La integración futura debe mantener Azure SDK solo en Infrastructure y fail-fast para selector/config inválidos.

## Contrato de URL/download

Alternativas:

| Opción | Evaluación |
|---|---|
| A. URL directa del provider | rechazada: filtra provider/object key y dificulta autorización estable |
| B. URL firmada temporal | no seleccionada como contrato público principal; expone provider y añade expiración al consumer |
| C. endpoint mediado por backend | seleccionada: Application autoriza por `fileId`, Infrastructure lee Blob y el HTTP permanece provider-neutral |
| D. redirect backend a URL firmada | no seleccionada ahora; además la navegación Angular actual no envía Bearer al primer request |

Target conceptual:

```text
POST /api/v1/archivos/subir
  -> respuesta compatible con nombre/url y un identificador durable

GET /api/v1/archivos/{fileId}
  -> Bearer + ownership en Application
  -> bytes desde FileStoragePort
```

La ruta puede conservarse, pero Angular debe descargar mediante `HttpClient` como `Blob` para que el interceptor agregue Bearer; `window.open` directo no es compatible con la seguridad vigente. `url` puede seguir siendo una ruta relativa del backend construida sobre `fileId`; nunca una URL aportada por el frontend ni una URL Blob pública.

```text
HTTP_COMPATIBILITY: CHANGE_REQUIRED
```

El cambio requerido está en el comportamiento de download del consumer y en congelar `{fileId}`; POST, wrapper y campos actuales pueden preservarse de forma compatible. No se modifica OpenAPI en esta microfase.

## Rollout y rollback

1. Inventariar, sin leer contenido sensible, objetos/referencias existentes por ambiente. Cero archivos en el checkout no prueba cero objetos desplegados.
2. Liberar primero una versión compatible que conozca `fileId`, metadata durable y el adapter Blob, manteniendo writes en el provider anterior durante la validación. No dual-write.
3. Migrar objetos existentes una sola vez, verificando tamaño/hash y vínculo; conservar la fuente anterior read-only durante la ventana de rollback aprobada.
4. Activar Blob para nuevos writes solo después de validar reads, ownership, restart y dos instancias.
5. Rollback de aplicación: volver únicamente a la release compatible que aún lee Blob; no volver al binario pre-Port.
6. Rollback de provider: solo después de migrar también los objetos nuevos al destino anterior y verificar metadata. Cambiar `provider=local` por sí solo está prohibido.
7. Fallo Blob durante runtime: error seguro y retry acotado según contrato futuro; cero fallback silencioso y cero referencia adjunta confirmada.

```text
ROLLBACK_STRATEGY: DEFINED
```

## Precondiciones antes de implementación

- ~~aprobación humana de esta decisión~~ → `APPROVED` en LB-004B.1 (nivel arquitectónico);
- ownership/retención → `FROZEN` en [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md) (LB-004B.1);
- contrato HTTP conceptual → `FROZEN` en [HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md) (LB-004B.1);
- contrato DB de metadata durable y migración → sigue `DECISION_REQUIRED`, ver
  [METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md) y [DECISIONS](DECISIONS.md);
- owner operacional, contenedor privado, permisos mínimos y configuración de lifecycle/backup aprobados
  → pendiente, `LB-006`;
- cambio frontend coordinado → matriz definida en
  [CONSUMER_MATRIX §FRONTEND CONTRACT DELTA](CONSUMER_MATRIX.md#frontend-contract-delta-lb-004b1);
  implementación real es una fase frontend independiente;
- TEST_PLAN congelado y RED independiente → ver [TEST_PLAN](TEST_PLAN.md); RED aplica después de
  resolver la dependencia DB;
- ambiente Blob real controlado para Cloud Integration y E2E multi-instancia → pendiente, no
  provisionado en esta microfase.

