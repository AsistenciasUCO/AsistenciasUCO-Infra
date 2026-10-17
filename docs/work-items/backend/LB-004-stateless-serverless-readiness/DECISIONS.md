---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# DECISIONS — LB-004A / LB-004B.0 / LB-004B.1

## Estado de entrada

- LB-004A: `ASSESSMENT: APPROVED` por revisión humana.
- LB-004B.0: `CONTRACT_ANALYSIS`; documentación preparada para revisión humana.
- LB-004B.1: `CONTRACT_ANALYSIS` — congela ownership, file identity, contrato HTTP conceptual y
  provider; deja abierto un único bloqueo de DB. Java, RED, DB, frontend, OpenAPI, runtime y
  workflows permanecen sin cambios en esta microfase.
- LB-004B.2: `BEHAVIOR_CHANGE` + `INFRASTRUCTURE` — implementa RED→GREEN de la storage foundation
  (MinIO + ClamAV) sobre decisión humana explícita que reemplaza el provider congelado en B.1. Ver
  [PROFESSOR_DECISION](PROFESSOR_DECISION.md) y `D-LB004B2-001` abajo.

## D-LB004B2-001 — Reversión de provider y política de malware (autoridad humana)

**Estado:** `APPROVED` (decisión humana explícita recibida en esta tarea).

`D-LB004B1-005` (`STORAGE_PROVIDER: AZURE_BLOB_STORAGE`) y la cláusula de antivirus `DEFERRED` de
`D-LB004B1-004` quedan `SUPERSEDED`. No se borra el historial de esas decisiones; se conservan como
evidencia de por qué se descartó filesystem local/compartido (ese razonamiento sigue vigente), pero
la columna de provider ganador y la política de malware cambian por instrucción humana directa,
registrada íntegramente en [PROFESSOR_DECISION](PROFESSOR_DECISION.md).

```text
STORAGE_PROVIDER: MINIO / APPROVED (SUPERSEDES D-LB004B1-005)
MALWARE_SCAN: REQUIRED (SUPERSEDES cláusula DEFERRED de D-LB004B1-004)
FRONTEND_DIRECT_STORAGE_ACCESS: FORBIDDEN
PRESIGNED_URLS: NOT_USED
STORAGE_ACCESS: BACKEND_ONLY
```

Esta decisión no reabre `OWNERSHIP_CONTRACT`, `FILE_ID_CONTRACT` ni el resto de `HTTP_CONTRACT`
(`D-LB004B0-002`, `D-LB004B1-001/002/003`), que permanecen `FROZEN` sin cambio: el reemplazo es
exclusivamente de provider y de política de malware. Detalle completo, alcance y límites explícitos
(qué NO decide): [PROFESSOR_DECISION](PROFESSOR_DECISION.md).

## D-LB004B0-001 — Consumer real

**Estado:** `CONFIRMED`.

Se inspeccionó `AsistenciasUCO-Frontend`, `develop@b0c2225e8a9dd9960d124d960725cb94b7b0abb8`, árbol limpio. El flujo real es:

```text
ESTUDIANTE selecciona archivo
  -> POST /api/v1/archivos/subir inmediato
  -> conserva nombre + url (ignora nombreGuardado)
  -> POST /api/v1/asistencias/revisiones con soporteNombre/soporteUrl opcionales

DOCENTE relacionado
  -> UI de reclamos muestra soporte
  -> window.open(url) para descargar/visualizar
```

Una revisión puede existir sin soporte. Detalle: [CONSUMER_MATRIX](CONSUMER_MATRIX.md).

Hallazgos de compatibilidad:

- UI: máximo 10 MB; backend: máximo 5 MiB.
- `window.open` no adjunta Bearer; el GET backend está protegido.
- `GET /docente/reclamos` existe pero responde feature unavailable, por lo que la descarga docente no está certificada E2E.

## D-LB004B0-002 — Identidad durable

**Estado:** `DECIDED`.

Application manejará un `fileId` UUID opaco y estable. No manejará como identidad:

- nombre original;
- `nombreGuardado` heredado;
- path físico;
- object key;
- URL de frontend/provider.

El `objectKey` es detalle interno del provider. La metadata durable mínima debe representar: `fileId`, object key/proveedor interno, original filename sanitizado, content type verificado, size verificado, owner institucional, estado lifecycle, timestamps y binding a revisión/recurso. No se diseña schema en esta microfase.

```text
OBJECT_IDENTITY: DECIDED
METADATA_DURABILITY_REQUIRED: YES
DB_CHANGE_REQUIRED: YES
```

Justificación DB: el contrato actual solo persiste `soporteNombre`/`soporteUrl`; no hay store durable aprobado para owner, estado, `fileId` y binding. El cambio requerido es de contrato externo de persistencia y debe diseñarlo/aprobarlo el equipo DB; este backend no crea schema. No se afirma tabla, columna ni SQL.

## D-LB004B0-003 — Ownership

**Estado:** `PRODUCT_DECISION_REQUIRED`.

La propuesta mínima es estudiante autenticado que sube/adjunta a su propia revisión y docente titular relacionado que lee para resolverla. No hay evidencia para acceso de coordinador/administrador, retención, hard delete o reemplazo post-attach. El archivo ajeno devuelve 404 para no revelar existencia.

Detalle y estados `DRAFT/ATTACHED/ORPHAN/REPLACED`: [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md).

## D-LB004B0-004 — Provider

**Estado:** `AZURE_BLOB_STORAGE / PROPOSED_FOR_HUMAN_APPROVAL`.

Se selecciona Azure Blob privado como target conceptual. Local no cumple multi-instancia; shared filesystem no tiene evidencia/owner; Azure Blob cumple durabilidad, objetos privados y acceso multi-instancia, y encaja con el patrón Azure/`DefaultAzureCredential` ya validado para otras capabilities. No existe evidencia de Blob provisionado: recursos, permisos, SLO e IaC siguen pendientes y no se presumen.

Detalle: [PROVIDER_DECISION](PROVIDER_DECISION.md).

## D-LB004B0-005 — URL y download

**Estado:** `BACKEND_MEDIATED / CHANGE_REQUIRED`.

- Se preservan por defecto `POST /api/v1/archivos/subir` y `GET /api/v1/archivos/{...}`.
- El segmento del GET pasa conceptualmente a identificar `fileId`, no filename ni object key.
- `url` puede seguir siendo una ruta relativa del backend; no expone URL Blob.
- La descarga exige Bearer y autorización contextual; Angular debe usar `HttpClient`/Blob en vez de navegación directa.
- URL directa o firmada del provider no es el contrato HTTP principal.

```text
HTTP_COMPATIBILITY: CHANGE_REQUIRED
```

No se cambia OpenAPI en LB-004B.0; la decisión debe congelarse en una microfase contractual posterior.

## D-LB004B0-006 — Lifecycle y rollback

**Estado:** `DEFINED_WITH_PRODUCT_VALUES_PENDING`.

- Upload confirmado = bytes en provider + metadata durable `DRAFT`.
- Attach confirmado = ownership/contexto validados + binding durable aceptado.
- Storage success + metadata/attach failure = objeto reconciliable, nunca referencia confirmada falsa.
- Cleanup idempotente de huérfanos desde estado durable; no depende del heap de una réplica.
- Reemplazo crea objeto/fileId nuevo; no sobreescribe.
- Retención y delete exactos requieren producto/legal.
- Rollout en dos releases y migración verificada; rollback vuelve a una release compatible con Blob. Nunca `provider=local` sin migración inversa de objetos.

```text
ROLLBACK_STRATEGY: DEFINED
```

## D-LB004B0-007 — Cache y límites de fase

**Estado:** `NO_DISTRIBUTED_CACHE_REQUIRED`.

No Redis. Las caches existentes siguen siendo derivadas. Realtime continúa fuera de alcance en LB-005. IaC/provisioning y topología cloud continúan en LB-006.

## D-LB004B1-001 — Ownership final

**Estado:** `FROZEN`.

Congela la matriz mínima de acceso: `ESTUDIANTE` upload/attach/read de su propio recurso (`DECIDED
YES` para las tres), `DOCENTE` read de revisiones relacionadas (`DECIDED YES`, implementación
bloqueada por dependencia DB), `COORDINADOR`/`ADMINISTRADOR` `OUT_OF_SCOPE`/`DENY_BY_DEFAULT`,
`SUPPORT_OPTIONAL: YES`, `POST_ATTACH_REPLACEMENT: OUT_OF_SCOPE`, `DELETE_ENDPOINT: NO`,
`RETENTION: OUT_OF_SCOPE` con tratamiento de huérfanos definido sin inventar plazo, `FOREIGN_FILE_HTTP: 404`.
Detalle: [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md). Esto resuelve `DR-LB004-OWN-001` como
decisión congelada dentro de esta tarea de contratos; no fue necesario escalar a producto porque
ninguna regla otorga acceso nuevo a un tercero — todo lo `OUT_OF_SCOPE` permanece denegado por
defecto y todo lo `DECIDED` es la extensión mínima del principio de ownership ya aceptado.

## D-LB004B1-002 — Contrato HTTP conceptual

**Estado:** `FROZEN` (conceptual; OpenAPI no se modifica).

`POST /api/v1/archivos/subir` responde como mínimo `{fileId, nombre, url, tamanio}` con `url`
relativa construida desde `fileId`. `GET /api/v1/archivos/{fileId}` exige Bearer + ownership,
foráneo → 404. `POST /api/v1/asistencias/revisiones` incorpora `soporteArchivoId` (fileId) como
campo autoritativo; `soporteNombre`/`soporteUrl` de request quedan `DEPRECATE` con corte
coordinado (no ventana de doble confianza), por ser una corrección de seguridad, no una preferencia
de UX. Ningún `PUT`/`DELETE` nuevo: `METHOD_EXCEPTION` no aplica. Detalle:
[HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md). Resuelve `DR-LB004-HTTP-001` en su parte
conceptual; la implementación sigue bloqueada por `DR-LB004-DB-002` (ver abajo) porque el binding
`ATTACHED` depende de la representación DB elegida.

## D-LB004B1-003 — Tamaño máximo

**Estado:** `DECIDED`.

`MAX_FILE_SIZE_FINAL: 5 MiB (5 242 880 bytes)`, preservando el límite backend AS-IS. No hay
requisito funcional que demuestre necesidad de subir a 10 MB; el frontend debe bajar su límite
anunciado. Resuelve el riesgo `R-LB004-007`.

## D-LB004B1-004 — Content security

**Estado:** `FROZEN` (política; scanning `DEFERRED`).

Extensiones `pdf/png/jpg/jpeg` preservadas; verificación de content-type contra bytes reales
(magic bytes) `REQUIRED` para la implementación futura; `Content-Disposition: inline` preservado
dado el whitelist cerrado; nombre original sanitizado `REQUIRED` para el valor mostrado, no solo
para el nombre guardado. Antivirus/malware scanning: **`SUPERSEDED` por `D-LB004B2-001`** — pasa de
`DEFERRED` a `REQUIRED` por decisión humana explícita en LB-004B.2 (ClamAV, fail-closed). Ver
[PROFESSOR_DECISION](PROFESSOR_DECISION.md). El resto de esta política de content security
permanece `FROZEN` sin cambio. Detalle: [HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md).

## D-LB004B1-005 — Provider (`SUPERSEDED` por `D-LB004B2-001`)

**Estado:** `SUPERSEDED`. Conservado como evidencia histórica; no rige la implementación.

`STORAGE_PROVIDER: AZURE_BLOB_STORAGE`, `OBJECT_VISIBILITY: PRIVATE`, `DOWNLOAD: BACKEND_MEDIATED`
se congelaron como `APPROVED` en LB-004B.1. En LB-004B.2, decisión humana explícita reemplaza el
provider por `MINIO` sin reabrir el resto del contrato (ownership/HTTP/tamaño). Ver
`D-LB004B2-001` y [PROFESSOR_DECISION](PROFESSOR_DECISION.md). El razonamiento de por qué se
descartó filesystem local/compartido en [PROVIDER_DECISION](PROVIDER_DECISION.md) permanece válido;
solo cambia la columna de provider ganador.

## D-LB004B1-006 — DB metadata/binding (bloqueo restante)

**Estado:** `DECISION_REQUIRED` (sin resolver; único bloqueo real de implementación tras esta
microfase).

`DB_SCHEMA_CHANGE_REQUIRED: DECISION_REQUIRED`. `DB_PUBLIC_CONTRACT_CHANGE_REQUIRED: YES`. Se
analizaron dos alternativas sin diseñar SQL: (A) objeto de persistencia nuevo para metadata/binding;
(B) reutilizar `soporteNombre`/`soporteUrl` existentes para `ATTACHED` + metadata durable del objeto
en el provider para `DRAFT` + nueva capability de consulta. Ninguna requiere expandir columnas de
una tabla existente, pero no hay evidencia versionada del shape real que respalda
`usp_radicar_solicitud_revision_asistencia` (`DB_BASELINE_CONTRACT.md` no lo cubre) para descartar
una u otra, ni evidencia de que la reconciliación de `DRAFT`/`ORPHAN` sea viable solo con metadata
de provider a escala. Detalle completo, evidencia y el contrato exacto solicitado al equipo DB:
[METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md).

**Actualización LB-004B.2:** la instrucción recibida separa explícitamente la storage foundation
(bytes fuera del backend, validados, autorizados por ownership técnico sobre el objeto) del binding
completo `fileId → revisión → sesión → grupo → docente`. `DR-LB004-DB-002` sigue `DECISION_REQUIRED`
y el backend no diseña SQL ni modifica el repositorio DB en esta tarea, pero eso ya no bloquea el
cierre de la storage foundation en sí misma:

```text
REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT (aislado; no bloquea STORAGE_FOUNDATION)
```

## Bloqueos vigentes

| ID | Estado | Bloquea | Responsable/evidencia necesaria |
|---|---|---|---|
| DR-LB004-OWN-001 | `RESOLVED_BY_D-LB004B1-001` | — | congelado dentro de contratos; ver `OWNERSHIP_DECISION.md` |
| DR-LB004-DB-002 | `DECISION_REQUIRED`, aislado como `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT` | attach/lifecycle DB-dependiente, docente-read, fila SQL de metadata | equipo DB: elegir Alternativa A/B para metadata/binding y proveer capability de consulta fileId→revisión; ver `METADATA_CONTRACT_TARGET.md`. Ya **no** bloquea la storage foundation (upload/download/ownership técnico/content-security/malware) — ver `D-LB004B2-001` |
| DR-LB004-HTTP-001 | `RESOLVED_BY_D-LB004B1-002` (conceptual) | — | contrato congelado; implementación GREEN en LB-004B.2 |
| DR-LB004-PROVIDER-001 | `RESOLVED_BY_D-LB004B2-001` | — | `STORAGE_PROVIDER: AZURE_BLOB_STORAGE` reemplazado por `MINIO` vía decisión humana; ver `PROFESSOR_DECISION.md` |
| DR-LB004-MALWARE-001 | `RESOLVED_BY_D-LB004B2-001` | — | `DEFERRED` reemplazado por `REQUIRED` (ClamAV) vía decisión humana; ver `PROFESSOR_DECISION.md` |
| ME-LB004-MIG-001 | `BLOCKED_BY_MISSING_EVIDENCE` | cutover/rollback operacional de un futuro provider cloud | fuera de alcance LB-004B.2 (MinIO local no requiere migración de objetos preexistentes) |
| ME-LB004-BLOB-001 | `SUPERSEDED` | — | ya no aplica: no hay recurso Blob que provisionar; MinIO corre local vía `infra/files/compose.yaml` |

El bloqueo anterior de consumer queda cerrado:

```text
ME-LB004-001: RESOLVED_BY_FRONTEND_SNAPSHOT_b0c2225
CONTRACT_CONFLICT: NONE_DEMONSTRATED
TEST_CONTRACT_CONFLICT: NONE
```

## Dictamen LB-004B.1 (histórico)

```text
FRONTEND_CONSUMER: CONFIRMED
OWNERSHIP_CONTRACT: FROZEN
FILE_ID_CONTRACT: FROZEN
HTTP_CONTRACT: FROZEN
DB_SCHEMA_CHANGE_REQUIRED: DECISION_REQUIRED
DB_PUBLIC_CONTRACT_CHANGE_REQUIRED: YES
STORAGE_PROVIDER: APPROVED (AZURE_BLOB_STORAGE) -- SUPERSEDED, ver D-LB004B2-001
FRONTEND_DELTA: DEFINED
TEST_PLAN: NOT_READY (bloqueado únicamente por DR-LB004-DB-002)
ROLLBACK_STRATEGY: DEFINED
CACHE: NO_DISTRIBUTED_CACHE_REQUIRED
TD004: OPEN
LB004_IMPLEMENTATION_READY: NO
```

## Dictamen LB-004B.2

```text
STORAGE_PROVIDER: APPROVED (MINIO) -- D-LB004B2-001, autoridad humana
MALWARE_SCAN: REQUIRED -- D-LB004B2-001
OWNERSHIP_CONTRACT: FROZEN (heredado de B.1, sin cambio)
FILE_ID_CONTRACT: FROZEN (heredado de B.1, sin cambio)
HTTP_CONTRACT: FROZEN (heredado de B.1, sin cambio)
REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT (aislado; DR-LB004-DB-002 sin resolver, no bloquea storage foundation)
DB_CHANGE_PERFORMED: NO
FRONTEND_CHANGE_PERFORMED: NO
STORAGE_FOUNDATION_SCOPE: RED_GREEN_AUTHORIZED
TD004: PARTIAL (tras GREEN; ver TECHNICAL_DEBT.md)
LB004_IMPLEMENTATION_READY: YES (alcance storage foundation únicamente)
```

## Siguiente microfase

`LB-004B.2` ejecuta RED→GREEN de la storage foundation (MinIO + ClamAV) sobre el contrato ya
congelado en B.1 más la reversión de provider/malware de `D-LB004B2-001`. `REVIEW_BINDING` queda
`BLOCKED_BY_DB_CONTRACT` y aislado explícitamente: no bloquea el cierre de esta microfase. Después
de esta tarea, `NEXT: DB CONTRACT MICROPHASE` (repositorio DB, prompt independiente) sigue siendo
el paso requerido para `DR-LB004-DB-002` antes de poder implementar attach/lifecycle DB-dependiente
y lectura docente (`FASE 2/3` de `E2E_PLAN.md`).

