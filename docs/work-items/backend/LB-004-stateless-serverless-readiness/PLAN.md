---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# PLAN — LB-004A / LB-004B.0 / LB-004B.1 / LB-004B.2 (histórico) + LB-004B.2H (vigente)

> LB-004B.2H tiene su propia sección al final y constituye el plan vigente. Las secciones anteriores
> documentan LB-004A/B.0/B.1/B.2 y se conservan como evidencia histórica; sus referencias a Azure
> Blob o al `docker-compose.yml` raíz están `SUPERSEDED` por B.2/B.2H.

## Identidad y objetivo

- Fecha / rol / base Git backend: 2026-09-29 / contratos (`02-contratos`) / `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d`.
- Rama backend: `jose-valencia/lb-004-stateless-serverless-readiness`.
- Entrada humana: LB-004A `ASSESSMENT: APPROVED`; LB-004B.0 `READY_FOR_HUMAN_REVIEW`.
- Consumer: `AsistenciasUCO-Frontend`, `develop@b0c2225e8a9dd9960d124d960725cb94b7b0abb8`, árbol limpio.
- Objetivo LB-004B.1: convertir las propuestas de LB-004B.0 en contrato congelado — ownership,
  identidad de objeto, contrato HTTP conceptual, tamaño, content security y provider — y revisar el
  supuesto `DB_SCHEMA_CHANGE_REQUIRED` sin diseñar SQL ni inventar decisión de producto.
- Criterio de salida: `OWNERSHIP_CONTRACT`, `FILE_ID_CONTRACT`, `HTTP_CONTRACT`, `STORAGE_PROVIDER`,
  `FRONTEND_DELTA`, `TEST_PLAN` con veredicto explícito; un único bloqueo restante identificado
  (`DR-LB004-DB-002`) y su microfase siguiente indicada. Sin implementar Java ni crear RED.
- Skills: `uco-contratos` (obligatoria), `uco-seguridad`, `uco-azure`, `uco-persistencia`.

## Variable principal

`PRIMARY_VARIABLE`: capacidad de almacenar y autorizar soportes de revisión sin depender del filesystem, heap o URL de una réplica.

## AS-IS comprobado

| Hecho | Evidencia | Consecuencia |
|---|---|---|
| bytes locales | `ArchivoController` escribe `uploads/soportes` | falla reemplazo/multi-instancia |
| seguridad Layer 1 | `/api/v1/archivos/** -> authenticated()` | cualquier identidad con nombre conocido puede leer; no hay ownership |
| binding débil | revisión persiste `soporteNombre`/`soporteUrl` del cliente | no prueba existencia, owner ni provider |
| consumer estudiante | selector de archivo → upload inmediato → attach opcional | upload puede quedar huérfano antes de enviar/cancelar |
| consumer docente | UI intenta `window.open(url)` | no envía Bearer; download real es incompatible |
| metadata | no existe fileId/owner/state/binding durable | Application no puede autorizar tras restart |
| Azure | Key Vault/App Configuration con Azure real dev y `DefaultAzureCredential` | patrón Azure existente; Blob específico no está provisionado ni validado |
| caches | estado derivado local | `NO_DISTRIBUTED_CACHE_REQUIRED` |

Detalle: [AS_IS](AS_IS.md), [STATE_INVENTORY](STATE_INVENTORY.md), [CONSUMER_MATRIX](CONSUMER_MATRIX.md).

## TARGET congelado (LB-004B.1)

1. Application usa `fileId` UUID; provider key, ruta y URL no son identidad de negocio. **`FROZEN`.**
2. Metadata durable conserva owner, estado y binding. Alternativas A/B analizadas sin diseñar schema:
   `DB_SCHEMA_CHANGE_REQUIRED: DECISION_REQUIRED`, `DB_PUBLIC_CONTRACT_CHANGE_REQUIRED: YES`. Ver
   [METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md).
3. `ArchivoController` futuro delega a InputPort/UseCase; Application usa `FileStoragePort`; Azure SDK vive solo en Infrastructure. **Sin cambios; no implementado en esta microfase.**
4. Provider target: Azure Blob privado, seleccionado mediante Composition Root, sin fallback silencioso. **`APPROVED`** (nivel arquitectónico).
5. Download target: endpoint backend mediado y autorizado por `fileId`; no URL pública/directa del provider. **`FROZEN`.**
6. Foreign file: 404 después de autenticar, sin revelar existencia. **`FROZEN`.**
7. Lifecycle durable `DRAFT -> ATTACHED`; `ORPHAN/REPLACED` reconciliables sin plazo numérico inventado; `DELETE_ENDPOINT: NO`; `POST_ATTACH_REPLACEMENT: OUT_OF_SCOPE`. **`FROZEN`**, ver [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md).
8. Rutas HTTP existentes se preservan; `soporteArchivoId` reemplaza la confianza en `soporteUrl`/`nombreGuardado` del cliente; Angular debe cambiar de `window.open` a descarga autenticada con `HttpClient`. **`FROZEN`**, ver [HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md) y [CONSUMER_MATRIX §FRONTEND CONTRACT DELTA](CONSUMER_MATRIX.md#frontend-contract-delta-lb-004b1).
9. No Redis y no realtime distribuido en LB-004. **Sin cambios.**
10. `MAX_FILE_SIZE_FINAL: 5 MiB`; content security (extensiones, magic bytes, Content-Disposition, sanitización de nombre) `FROZEN`; antivirus/malware scanning `DEFERRED`. Ver [HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md).

## Clase de cambio y rutas

- Change class: `CONTRACT_ANALYSIS`.
- ALLOWED_PATHS: `docs/work-items/LB-004-stateless-serverless-readiness/**`.
- FORBIDDEN_PATHS: `src/main/**`, `src/test/**`, `pom.xml`, `.github/**`, `infra/**`, `.env*`, `docs/contracts/openapi/**`, frontend, repositorio DB y configuración runtime.
- CONTRACTS: se congela ownership/file-identity/HTTP conceptual/content-security/tamaño/provider a partir del AS-IS y las propuestas de LB-004B.0; no se modifica OpenAPI.
- PROVIDERS: `STORAGE_PROVIDER: AZURE_BLOB_STORAGE` congelado a nivel arquitectónico (`APPROVED`); no SDK, recurso ni configuración.
- SECURITY_IMPACT: alto; ownership/404 y corte de confianza en `soporteUrl` de cliente quedan congelados en esta tarea (rol contratos + seguridad), no delegados a producto porque no otorgan acceso nuevo a terceros.
- OBSERVABILITY_IMPACT: futuro adapter debe preservar correlation y registrar clasificación de fallo sin file names sensibles/object keys/tokens; cero cambio actual.
- TEST_LEVEL_REQUIRED: Application, HTTP/security, architecture, wiring, SQL Server si cambia contrato DB, Cloud Integration Blob y E2E multi-instancia (sin cambios respecto a LB-004B.0).
- CONSUMERS: Angular estudiante/docente confirmado; coordinador/administrador sin consumer de soportes (`OUT_OF_SCOPE`).

Lo no listado como Allowed no se modifica.

## Alcance

- congelar snapshot del frontend y matriz de consumo;
- proponer matriz mínima de ownership y marcar decisiones de producto;
- decidir identidad durable y necesidad de metadata/DB;
- seleccionar provider target por evidencia;
- decidir contrato conceptual de download;
- definir lifecycle, migración y rollback practicable;
- actualizar PLAN/DECISIONS/RISKS/TEST_PLAN y fuentes AS-IS del work item.

## No alcance

- Java, tests RED, SQL/schema/SP, frontend, OpenAPI, SDK Blob, secrets/configuración, recursos Azure, deploy o E2E;
- aprobar por cuenta propia reglas de producto;
- LB-005 realtime distribuido;
- LB-006 IaC/CD/topología/operación cloud;
- cerrar TD-004.

## Archivos documentales

### Actualizados

- `PLAN.md`, `DECISIONS.md`, `RISKS.md`, `TEST_PLAN.md`.
- `AS_IS.md`, `STATE_INVENTORY.md` para retirar el bloqueo de consumer ya resuelto.
- `VALIDATION.md` con evidencia documental y gates `NOT_RUN`.
- `docs/baseline/LINEA_BASE.md` para reflejar LB-004B.0 sin autorizar implementación.

### Nuevos (LB-004B.0)

- [CONSUMER_MATRIX](CONSUMER_MATRIX.md).
- [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md).
- [PROVIDER_DECISION](PROVIDER_DECISION.md).

### Nuevos (LB-004B.1)

- [HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md).
- [METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md).

### Propuestos para fases posteriores, no autorizados

- contrato DB durable de metadata/binding (`DR-LB004-DB-002`, insumo entregado en `METADATA_CONTRACT_TARGET.md`);
- InputPorts/UseCases y `FileStoragePort`;
- adapter Azure Blob + properties + Composition Root;
- cambio Angular a descarga Blob autenticada (insumo entregado en `CONSUMER_MATRIX.md §FRONTEND CONTRACT DELTA`);
- RED independiente y pruebas con provider real.

No se fijan clases, tablas, columnas ni SQL.

## Contratos y consumidores

| Ámbito | AS-IS | Resultado LB-004B.1 |
|---|---|---|
| DOMAIN/Application | nombre/URL sin file identity | `fileId UUID` — `FROZEN` |
| HTTP | POST upload + GET por nombre; revisión recibe name/URL | `FROZEN` (conceptual): `soporteArchivoId`, 404 ajeno, `fileId` en path; ver `HTTP_CONTRACT_TARGET.md` |
| PERSISTENCE | revisión guarda dos strings | `DECISION_REQUIRED` (`DR-LB004-DB-002`); insumo entregado en `METADATA_CONTRACT_TARGET.md`, diseño pendiente del owner DB |
| SECURITY | archivos: authenticated sin Layer 2 | ownership `FROZEN` en `OWNERSHIP_DECISION.md`; sin `PRODUCT_DECISION_REQUIRED` abiertos |
| PROVIDER | local filesystem directo | Azure Blob privado `APPROVED` (nivel arquitectónico) |
| CONSUMER | estudiante upload/attach; docente open URL | delta exacto `DEFINED` en `CONSUMER_MATRIX.md`; implementación frontend pendiente (prompt independiente) |
| REALTIME | SSE local | fuera de alcance LB-004 |

## Dependencias y bloqueos

- ~~Producto/seguridad: estudiante READ, coordinador/admin, retención, delete y reemplazo~~ →
  resuelto dentro de contratos en `OWNERSHIP_DECISION.md` (`FROZEN`/`OUT_OF_SCOPE`, sin acceso nuevo
  a terceros).
- ~~Contratos/frontend: `fileId`, 404, descarga autenticada, límite de tamaño~~ → `FROZEN` en
  `HTTP_CONTRACT_TARGET.md` y `CONSUMER_MATRIX.md`.
- DB: contrato durable para metadata/binding → **sigue abierto**, `DR-LB004-DB-002`, único bloqueo
  real de implementación.
- Operaciones: inventario de objetos existentes y ambiente Blob privado → pendiente, `LB-006`/operaciones.
- ~~Auditor humano: aprobar o rechazar provider/ownership/rollback antes de RED~~ → provider
  `APPROVED` por instrucción de esta tarea (sin evidencia contraria); ownership/rollback congelados
  dentro del alcance de contratos.

Ver [DECISIONS](DECISIONS.md) y [RISKS](RISKS.md).

## Rollback y stop conditions

- Rollback documental: revertir únicamente archivos de este work item/LINEA_BASE.
- Rollback futuro: staged release + migración verificada; nunca selector a local sin que local contenga los objetos.
- STOP: no crear RED hasta resolver `DR-LB004-DB-002`; no implementar con DB pendiente aunque
  ownership/HTTP/provider ya estén congelados; no provisionar Azure; no modificar frontend/DB/OpenAPI.
- No hay `CONTRACT_CONFLICT` demostrado. Sí hay `DECISION_REQUIRED` (`DR-LB004-DB-002`) y evidencia
  operacional faltante de objetos existentes y Blob real (`ME-LB004-MIG-001`, `ME-LB004-BLOB-001`).

## Testing

Referencia: [TEST_PLAN](TEST_PLAN.md). `RED_SNAPSHOT: APPLIES_NOW=NO` (bloqueo único:
`DR-LB004-DB-002`); ver `RED_READINESS_BY_AREA` en `TEST_PLAN.md` para el detalle por escenario. No
se ejecuta `clean verify` por instrucción; solo validación documental.

## Deuda

- TD-004: `OPEN`, bloquea LB-004.
- TD-003/TD-011: LB-005.
- TD-022/TD-023 residual/TD-027: LB-006 o validación cloud según capacidad.
- Cache: `NO_DISTRIBUTED_CACHE_REQUIRED`.

## Definition of Ready — LB-004B.1

```text
OWNERSHIP_CONTRACT: FROZEN
FILE_ID_CONTRACT: FROZEN
HTTP_CONTRACT: FROZEN
DB_SCHEMA_CHANGE_REQUIRED: DECISION_REQUIRED
DB_PUBLIC_CONTRACT_CHANGE_REQUIRED: YES
STORAGE_PROVIDER: APPROVED
FRONTEND_DELTA: DEFINED
TEST_PLAN: NOT_READY (bloqueado únicamente por DR-LB004-DB-002)
LB004_IMPLEMENTATION_READY: NO
```

Motivo: ownership, identidad de objeto, contrato HTTP conceptual, tamaño, content security y
provider quedan congelados/aprobados en esta microfase (ver `DECISIONS.md`). El único bloqueo
relevante para crear RED es `DR-LB004-DB-002` (contrato DB de metadata/binding,
`METADATA_CONTRACT_TARGET.md`), que no es competencia de este backend resolver por sí mismo. No
quedan `PRODUCT_DECISION_REQUIRED` abiertos: `COORDINADOR`/`ADMINISTRADOR` y retención se congelan
como `OUT_OF_SCOPE` con tratamiento explícito, no como decisiones pendientes.

## Siguiente microfase (histórico)

`NEXT: DB CONTRACT MICROPHASE` (repositorio DB, prompt independiente) para resolver
`DR-LB004-DB-002`. Solo después: `LB-004B.2 — TEST RED`, directamente sobre el contrato ya congelado
aquí, sin nuevas decisiones de ownership/HTTP/provider.

**Nota:** en la práctica, LB-004B.2 se ejecutó con una decisión humana adicional que reemplazó el
provider (`D-LB004B2-001`) y con `REVIEW_BINDING` aislado como `BLOCKED_BY_DB_CONTRACT` en vez de
esperar la microfase DB. Ver sección siguiente.

---

# PLAN — LB-004B.2 — MinIO Storage Foundation (RED → GREEN + integración local)

## Identidad y objetivo

- Fecha / rol / base Git backend: 2026-09-30 / continuación de contratos + implementación en la
  misma tarea (instrucción explícita autoriza backend, tests, configuración local, Docker/Compose y
  documentación) / branch `jose-valencia/lb-004-stateless-serverless-readiness`.
- Entrada humana: decisión de provider/malware registrada en [PROFESSOR_DECISION](PROFESSOR_DECISION.md)
  (`D-LB004B2-001`), más autorización explícita de implementación para esta microfase.
- Objetivo: externalizar los bytes de soporte fuera de la réplica backend mediante un puerto neutral
  (`FileStoragePort`) y MinIO privado, con validación de contenido y malware obligatorias, sin
  resolver todavía el binding completo `fileId → revisión → sesión → grupo → docente` si el contrato
  DB no lo permite.
- Skills aplicadas: `uco-arquitectura`, `uco-seguridad`, `uco-testing`, `uco-contratos`
  (para el freeze heredado), `uco-observabilidad` (logs/metrics sanitizados).

## Variable principal

`PRIMARY_VARIABLE`: externalizar los bytes de soporte fuera de la réplica backend mediante un puerto
neutral y MinIO privado, agregando validación segura de contenido y malware. Esta fase **no**
resuelve todavía el binding completo si el contrato DB actual no da evidencia suficiente — eso queda
explícitamente separado como `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT`.

## Clase de cambio y rutas

- Change class: `BEHAVIOR_CHANGE` + `INFRASTRUCTURE` (nuevo adapter/Port, nuevo servicio Docker,
  refactor de controller existente hacia Clean Architecture, nueva dependencia Maven).
- `TECHNICAL_BUILD_GATE`: base verificada verde antes de empezar (ver `LB-004B.2-VALIDATION.md`).
- ALLOWED_PATHS:
  - `src/main/java/co/edu/uco/asistenciasuco/**` (nuevo Port/UseCase/Adapter/Composition Root de
    storage y malware scan; refactor de `ArchivoController`; nueva excepción si aplica).
  - `src/test/java/co/edu/uco/asistenciasuco/**` (RED, GREEN, IT, ArchUnit nuevo).
  - `src/main/resources/application*.yml` (properties de storage MinIO/ClamAV, multipart).
  - `pom.xml` (dependencia oficial MinIO Java SDK, scope adecuado).
  - `docker-compose.yml` (servicios `minio`, `minio-init` o equivalente, `clamav`).
  - `.env.example` (solo nombres de variable, sin secretos reales).
  - `docs/work-items/LB-004-stateless-serverless-readiness/**`.
- FORBIDDEN_PATHS: repositorio DB, frontend (`AsistenciasUCO-Frontend`), `docs/contracts/openapi/**`
  (archivos fuera del Golden Path OpenAPI, sin cambio), `infra/keycloak/**`, `infra/observability/**`
  salvo lectura, `.env` real, cualquier introducción de Redis/RabbitMQ/Kafka/CQRS/outbox, inicio de
  LB-005/LB-006.
- PROVIDERS: `STORAGE_PROVIDER: MINIO` (`D-LB004B2-001`); nuevo `MALWARE_SCAN_PROVIDER: CLAMAV`.
- SECURITY_IMPACT: alto — cierra el `SECURITY_FINDING OBJECT_LEVEL_AUTHORIZATION_MISSING` para
  estudiante-owner; introduce malware scanning obligatorio; mantiene `DOCENTE_FILE_ACCESS:
  DENY_BY_DEFAULT` hasta `REVIEW_BINDING` resuelto (no otorga acceso nuevo a terceros).
- OBSERVABILITY_IMPACT: logs sanitizados de storage/scan (fileId, operation, result, size,
  scanResult), sin credenciales ni contenido; correlationId preservado.
- TEST_LEVEL_REQUIRED: unit/component (Application, HTTP/security, ArchUnit, wiring), integration
  real (`MinioFileStorageAdapterIT`, `ClamAvMalwareScanAdapterIT`, E2E HTTP→MinIO→ClamAV→HTTP).
- CONSUMERS: ninguno nuevo; Angular no se modifica en esta tarea (sigue usando el contrato AS-IS de
  `nombre`/`url`/`nombreGuardado`; el campo `fileId` se agrega de forma aditiva a la response).

Lo no listado como Allowed no se modifica.

## Alcance

- Registrar la decisión humana de provider/malware (`PROFESSOR_DECISION.md`) y actualizar la cadena
  de gobernanza (`DECISIONS.md`, `PROVIDER_DECISION.md`, `HTTP_CONTRACT_TARGET.md`, `RISKS.md`,
  `OWNERSHIP_DECISION.md`) marcando lo superado como `SUPERSEDED`, sin borrar historial.
- Crear `FileStoragePort`, `MalwareScanPort` y sus UseCases (`SubirArchivo`, `DescargarArchivo`) en
  Application, con `MinioFileStorageAdapter` y `ClamAvMalwareScanAdapter` exclusivamente en
  Infrastructure, conectados por Composition Root (`app.adapters.storage.provider=minio`).
- Refactorizar `ArchivoController` para depender solo de InputPorts.
- Implementar validación de contenido (tamaño, extensión, magic bytes, sanitización de nombre,
  path traversal) y política de compresión evaluada (no cosmética).
- Integrar MinIO y ClamAV a `docker-compose.yml` (versión pinneada, healthcheck, bucket privado
  provisionado, volumen Docker dedicado al storage).
- RED causal (`LB-004B.2-RED-SNAPSHOT.md`) antes de GREEN; implementador no modifica RED.
- Integration tests reales contra Docker local; certificación parcial de statelessness.
- Actualizar `TECHNICAL_DEBT.md` (TD-004) solo si su estado factual cambia; no cerrarlo mientras
  `REVIEW_BINDING`/E2E frontend/docente sigan pendientes.

## No alcance

- Resolver `DR-LB004-DB-002` (contrato DB de metadata/binding) ni tocar el repositorio DB.
- Modificar el frontend Angular.
- Autorización docente/coordinador/administrador más allá de `DENY_BY_DEFAULT`.
- OpenAPI, LB-005, LB-006, Redis/RabbitMQ/Kafka/CQRS/outbox, IaC, despliegue cloud.
- Retención/borrado con plazo numérico (sigue `OUT_OF_SCOPE`, sin inventar).

## Definition of Ready — LB-004B.2

```text
TECHNICAL_BUILD_GATE: ver LB-004B.2-VALIDATION.md (verificado antes de iniciar RED)
OWNERSHIP_CONTRACT: FROZEN (heredado, sin cambio)
FILE_ID_CONTRACT: FROZEN (heredado, sin cambio)
HTTP_CONTRACT: FROZEN (heredado, sin cambio)
STORAGE_PROVIDER: APPROVED (MINIO, D-LB004B2-001)
MALWARE_SCAN: REQUIRED (D-LB004B2-001)
REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT (aislado; no bloquea esta microfase)
CONTRACT_CONFLICT: NONE_OPEN (el detectado en preflight fue resuelto por D-LB004B2-001)
TEST_CONTRACT_CONFLICT: NONE
LB004B2_IMPLEMENTATION_READY: YES (alcance: storage foundation)
```

## Rollback y stop conditions

- Rollback documental: revertir únicamente los archivos listados en `FILES_CREATED`/`FILES_MODIFIED`
  del reporte final; sin commit/push, el rollback es simplemente descartar working tree si el humano
  lo decide.
- STOP si aparece necesidad de modificar tablas DB sin contrato, conflicto con el SP real, ownership
  docente no resoluble sin nueva capacidad DB, contrato frontend desconocido, secreto requerido
  inexistente o incompatibilidad arquitectónica real — ver `RISKS.md §Stop conditions`.
- La storage foundation puede cerrarse aunque `REVIEW_BINDING = BLOCKED_BY_DB_CONTRACT`, siempre que
  quede aislado y documentado (confirmado por `PROFESSOR_DECISION.md`).

## Testing

Referencia: [TEST_PLAN](TEST_PLAN.md) §`RED_READINESS_BY_AREA (LB-004B.2)`. Detalle de escenarios,
comandos y evidencia: [LB-004B.2-RED-SNAPSHOT](LB-004B.2-RED-SNAPSHOT.md),
[LB-004B.2-IMPLEMENTATION](LB-004B.2-IMPLEMENTATION.md), [LB-004B.2-VALIDATION](LB-004B.2-VALIDATION.md).

---

# PLAN — LB-004B.2H — Infrastructure + Security Hardening + Consistency Fix

## Autoridad, objetivo y variable principal

- Entrada humana: revisión final del profesor recibida el `2026-09-30`; se registra sin borrar la
  historia previa en [PROFESSOR_DECISION](PROFESSOR_DECISION.md).
- Change class: `BEHAVIOR_CHANGE` + `INFRASTRUCTURE` + corrección documental.
- `PRIMARY_VARIABLE`: endurecer la storage foundation ya implementada para que el único acceso sea
  backend-mediated, con identidad técnica de mínimo privilegio, validación MIME real, semántica
  técnica segura ante outage y verificación de integridad en lectura.
- Objetivo: corregir los hallazgos de revisión de LB-004B.2 y dejar evidencia honesta para una
  nueva revisión humana; no cerrar `REVIEW_BINDING` ni LB-004.

## Alcance autorizado

- `infra/files/**` (NUEVO): Compose aislado, build MinIO Community desde source fijado, bootstrap,
  policy mínima, configuración ClamAV, documentación y validación de infraestructura.
- `docker-compose.yml`: restaurar su responsabilidad original del backend.
- `.env.example` e `infra/files/.env.example`: separar credenciales backend de root/bootstrap.
- `src/main/java/co/edu/uco/asistenciasuco/application/features/archivo/**`: MIME declarado,
  semántica de error técnico e integridad SHA-256 en lectura.
- `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/archivo/**`:
  transportar el `Content-Type` multipart ya publicado, sin cambiar ruta ni response exitosa.
- `src/main/resources/application.yml`: threshold multipart coherente con 5 MiB.
- tests equivalentes bajo `src/test/**`, configuración de test y documentos de este work item.
- `docs/baseline/{LINEA_BASE,TECHNICAL_DEBT}.md` únicamente para reflejar estado factual.

## Fuera de alcance / rutas prohibidas

- DB, SQL/schema/SP, repositorio DB y cualquier persistencia nueva.
- Frontend, OpenAPI canónico, endpoints nuevos, scheduler local/JVM, `@Scheduled`, lifecycle con
  plazo numérico, cold storage implementado, LB-005/LB-006, commit, push o PR.
- Autorización docente/coordinador/administrador: permanece `DENY_BY_DEFAULT` mientras
  `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT`.

## Contratos y decisiones

- HTTP: rutas/status exitosos no cambian. Archivo infectado conserva error 4xx controlado; outage,
  timeout o protocolo inválido del scanner usa el error técnico estándar existente (500), porque
  el catálogo vigente no define 503 y esta microfase no inventa una taxonomía paralela.
- Security: root MinIO solo existe en `minio`/`minio-init`; Spring Boot recibe exclusivamente
  credenciales de aplicación. Bucket privado, sin anonymous access ni presigned URL pública.
- Storage policy: `GetObject`, `PutObject`, `DeleteObject` sobre
  `arn:aws:s3:::asistencias-soportes/soportes/*`; `HeadObject` queda cubierto por `GetObject` en S3.
  `GetBucketLocation` se limita al bucket contractual porque el SDK MinIO Java lo requiere antes de
  `PutObject`. No se concede administración, creación de bucket ni acceso a buckets/prefixes
  arbitrarios.
- Lifecycle: `PURGE_CAPABILITY: REQUIRED`, `DELETE_PUBLIC_ENDPOINT: NO`,
  `NUMERIC_RETENTION: DECISION_REQUIRED`, `COLD_STORAGE_STRATEGY: REQUIRED_TO_DESIGN`.

## Definition of Ready — LB-004B.2H

```text
REQUIREMENT_AUTHORITY: HUMAN_REVIEW_2026-09-30
CONTRACTS_AFFECTED: STORAGE_SECURITY + CONTENT_VALIDATION + ERROR_SEMANTICS + INTEGRITY
DB_CHANGE_REQUIRED: NO
FRONTEND_CHANGE_REQUIRED: NO
REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT (aislado)
CONTRACT_CONFLICT: NONE_OPEN_FOR_THIS_SCOPE
TEST_CONTRACT_CONFLICT: NONE
REAL_PROVIDER_REQUIRED: YES (MinIO + ClamAV local controlado)
LB004B2H_IMPLEMENTATION_READY: YES
```

## Rollback y stop conditions

- Rollback: revertir solo los archivos enumerados en el reporte final; no reset general.
- STOP si el hardening exige DB/frontend/OpenAPI, amplía permisos de storage, expone root al
  backend, requiere un plazo de retención inventado o necesita relajar gates/tests.

