---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# TEST_PLAN — LB-004B.0/B.1 (histórico) + LB-004B.2/B.2H (vigente)

## Estado

LB-004B.2/B.2H implementa y valida la storage foundation con MinIO + ClamAV. Las referencias a
Azure Blob que permanezcan en las secciones B.0/B.1 son historia `SUPERSEDED`, no decisión vigente.
El único bloqueo contractual restante es `DR-LB004-DB-002` (metadata/binding DB), documentado en
[METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md).

## Fuentes

- [PLAN](PLAN.md), [DECISIONS](DECISIONS.md), [CONSUMER_MATRIX](CONSUMER_MATRIX.md).
- [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md) — `FROZEN`.
- [PROVIDER_DECISION](PROVIDER_DECISION.md) — `APPROVED`.
- [HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md) — `FROZEN`.
- [METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md) — `DECISION_REQUIRED` (bloqueo restante).
- DEFINITION_OF_READY, TESTING_STANDARD y VALIDATION_RUNBOOK.
- Frontend develop@b0c2225e8a9dd9960d124d960725cb94b7b0abb8.

## Behavioral Matrix

| ID | Requirement | Scenario | Precondition | Action | Observable | Expected | Wrong implementation caught | Level |
|---|---|---|---|---|---|---|---|---|
| STORAGE-001 | fileId durable | upload válido | estudiante/contexto válidos | subir | response + metadata | UUID opaco; nombre/path/URL no son identidad | usar filename/object key como ID | Application/HTTP |
| STORAGE-002 | confirmación consistente | MinIO guarda y metadata falla | fallo DB inducido | subir | HTTP, MinIO, DB, logs | error seguro; no DRAFT confirmado; objeto reconciliable | devolver 201 con metadata ausente | Application/Integration |
| STORAGE-003 | attach consistente | draft propio válido | metadata DRAFT | radicar revisión | DB/provider | binding ATTACHED una vez | aceptar URL arbitraria o file ajeno | Application/SQL Server IT |
| STORAGE-004 | revisión opcional | sin soporte | estudiante/sesión válidos | radicar revisión | HTTP + DB | éxito sin fileId | volver soporte obligatorio | HTTP/Integration |
| STORAGE-005 | segunda instancia | A sube, B lee | dos procesos/discos, MinIO real | upload A; download B | bytes/metadata | mismo objeto autorizado | filesystem/heap local como autoridad | E2E multi-instance/Integration |
| STORAGE-006 | restart | objeto ATTACHED | provider/metadata reales | reiniciar y leer | bytes/ownership | mismo resultado | estado solo en proceso | Integration/E2E |
| STORAGE-007 | filesystem neutral | MinIO activo | working dir aislado/read-only | upload/download | filesystem | cero bytes de negocio locales | controller escribe uploads | Component/E2E |
| STORAGE-008 | selector fail-closed | provider inválido | config explícita | iniciar | startup | falla clara; no local fallback | typo activa local | Wiring |
| STORAGE-009 | provider failure | timeout/403/5xx MinIO | sin attach confirmado | subir/leer | HTTP/log/correlation | error seguro, sin secreto/key, side effects controlados | filtrar SDK o confirmar referencia rota | Unit/Integration |
| AUTH-001 | autenticación | sin Bearer | endpoint protegido | upload/download | HTTP | 401 | endpoint público | HTTP security |
| AUTH-002 | archivo ajeno | fileId de otro estudiante | actor no relacionado | read/attach | HTTP/provider | 404; cero bytes/binding | IDOR o existencia revelada | Application/HTTP |
| AUTH-003 | estudiante owner | regla aprobada | objeto propio | read | HTTP/bytes | resultado aprobado | regla demasiado restrictiva/permisiva | Application/HTTP |
| AUTH-004 | docente relacionado | revisión grupo propio | docente titular | read | bytes | 200 | rol sin scope o bloqueo del titular | Application/HTTP/DB |
| AUTH-005 | docente ajeno | revisión de otro docente | docente autenticado | read | HTTP | 404 | autorización solo por rol | Application/HTTP/DB |
| AUTH-006 | coordinador/admin | decisión aprobada | actor correspondiente | read | HTTP | resultado exacto aprobado | bypass administrativo inventado | Application/HTTP |
| LIFE-001 | draft huérfano | upload y cancelación | TTL aprobada | reconciliar | metadata/Blob | cleanup idempotente después del plazo | delete inmediato o fuga | Integration |
| LIFE-002 | attach fallido | draft válido, DB falla | provider real | attach | estados | draft trazable; no ATTACHED falso | pérdida o binding parcial | Integration |
| LIFE-003 | reemplazo | soporte reemplazado | política aprobada | subir nuevo/rebind | fileIds/bytes | nuevo fileId; anterior según retención | overwrite/reuse key | Application/Integration |
| LIFE-004 | retención | objeto ATTACHED resuelto | política aprobada | lifecycle | objeto/metadata | conserva/elimina según contrato | borrar antes de plazo | Cloud Integration |
| HTTP-001 | upload compatible | archivo dentro del límite | consumer real | multipart archivo | status/body | 2xx acordado, exitoso, datos.nombre/url | cambiar wrapper/campo usado | Contract/Frontend |
| HTTP-002 | límite único | exacto y +1 | valor congelado | seleccionar/subir | UI + HTTP | frontend/backend coinciden | UI 10 MB/backend 5 MiB | Frontend/HTTP |
| HTTP-003 | download autenticado | URL backend | Angular con Bearer | HttpClient Blob | headers/bytes | Authorization presente; object URL local | window.open directo o Blob público | Frontend E2E |
| HTTP-004 | provider neutral | MinIO activo | upload confirmado | inspeccionar response | URL/body | sin hostname MinIO, presigned URL, key ni path | provider internals en HTTP | Contract |
| MIG-001 | archivos legacy | inventario/fixture | local + Blob controlados | migrar | hash/tamaño/binding | equivalencia; fuente read-only | referencias rotas | Migration/Integration |
| ROLLBACK-001 | rollback release | writes Blob activos | release compatible previa | rollback | reads/writes | continuidad con Blob | volver a binario pre-Port | E2E |
| ROLLBACK-002 | provider rollback | objetos nuevos Blob | migración inversa | cambiar provider | reads | todos accesibles | solo cambiar property | Provider Integration |
| CACHE-001 | cache no autoridad | reinicio/dos réplicas | source of truth disponible | refetch | valor | converge según política | depender de heap/añadir Redis | Integration |
| REG-001 | Golden Path intacto | baseline LB-003 | storage integrado | gates | tests/hash | sin cambio Golden Path | alterar contrato/capas | Regression/Architecture |

## Cobertura negativa y límites

- Archivo vacío, límite exacto, límite+1, extensión permitida con contenido incompatible y path traversal.
- fileId inexistente, malformado, ajeno, expirado o ya reemplazado.
- Attach sin soporte, con draft propio, ajeno, expirado, ya adjunto y concurrente.
- Provider timeout, throttling, 401/403/404/5xx; retry solo si el contrato lo permite.
- DB failure antes/después de bytes; reconciliación repetida.
- Rol incorrecto, docente no titular y decisiones explícitas de coordinador/admin.
- Ausencia de Bearer en navegación directa frontend.
- Logs/correlation sin filename sensible, object key, SAS ni payload.

## Integración requerida

| Campo | Decisión |
|---|---|
| REAL_PROVIDER_REQUIRED | YES |
| PROVIDER | MINIO, aprobado por `D-LB004B2-001` |
| MOCK_SUFFICIENT_FOR_DURABILITY | NO |
| MULTI_INSTANCE_REQUIRED | YES |
| SQL_SERVER_REQUIRED | YES cuando exista contrato de metadata/binding |
| FRONTEND_E2E_REQUIRED | YES para download autenticado |

El ambiente requiere dos procesos con working directories separados, MinIO privado controlado,
identidad de mínimo privilegio, SQL Server/fixtures autorizados cuando aplique y cleanup de un
namespace inequívoco. La integración real no corre en la suite normal y no imprime URLs firmadas ni secretos.

## Side effects y rollback

- Asertar bytes, metadata, binding y ausencia de side effects.
- Cleanup solo de fixtures del test.
- Migración compara hash/tamaño y relación, no solo conteos.
- Rollback se prueba con objetos anteriores y posteriores al cutover.
- Prohibido dual-write oculto y fallback local silencioso.

## RED requerido después del freeze

El tester independiente deberá crear RED causal para:

1. fileId, metadata y lifecycle;
2. ownership por actor y 404 ajeno;
3. upload/attach/download HTTP;
4. wiring, provider fail-closed y ArchUnit;
5. MinIO real, restart y dos instancias;
6. fallos, cleanup, migración y rollback;
7. consumer Angular, límite y descarga Bearer;
8. regresión Golden Path.

Los archivos, hashes y comandos se fijarán en LB-004B.2. El implementador no modificará esos tests.

## RED_READINESS_BY_AREA (LB-004B.1)

| Área / IDs | Contrato congelado | RED_APPLIES_NOW | Bloqueo restante |
|---|---|---|---|
| `STORAGE-001`, `STORAGE-005..009` (fileId, provider, wiring, selector) | `FILE_ID_CONTRACT`, `PROVIDER_DECISION` | NO | Ninguna decisión humana pendiente; requiere ambiente Blob real (`ME-LB004-BLOB-001`), no una decisión |
| `AUTH-001`, `AUTH-003`, `AUTH-006` (autenticación, estudiante-owner, coordinador/admin) | `OWNERSHIP_DECISION` | NO | Ninguna decisión pendiente; requiere implementación del Use Case/Port |
| `AUTH-002` (archivo ajeno estudiante) | `OWNERSHIP_DECISION` | NO | Ninguna decisión pendiente |
| `AUTH-004`, `AUTH-005` (docente relacionado/ajeno) | `OWNERSHIP_DECISION` | **BLOQUEADO** | Depende de `DR-LB004-DB-002`: la capability de consulta fileId→revisión/grupo/docente no existe |
| `STORAGE-002`, `STORAGE-003`, `LIFE-001..004` (metadata, attach, lifecycle DB) | `METADATA_CONTRACT_TARGET` | **BLOQUEADO** | `DR-LB004-DB-002` sin resolver |
| `HTTP-001`, `HTTP-002`, `HTTP-004` (upload compatible, límite, provider neutral) | `HTTP_CONTRACT_TARGET` | NO | Ninguna decisión pendiente |
| `HTTP-003` (download autenticado Angular) | `CONSUMER_MATRIX §FRONTEND CONTRACT DELTA` | NO | Requiere implementación frontend (prompt independiente), no decisión |
| `MIG-001`, `ROLLBACK-001..002` | `PROVIDER_DECISION` | NO | Requiere ambiente/objetos reales, no decisión |
| `REG-001` (regresión Golden Path) | `AS_IS.md` (`GOLDEN_PATH_STORAGE_DEPENDENCY: NONE FOUND`) | NO | Ninguna |
| `CACHE-001` | `DECISIONS.md` (`NO_DISTRIBUTED_CACHE_REQUIRED`) | NO | Ninguna |

Todas las áreas quedan `RED_APPLIES_NOW: NO` en LB-004B.1 porque la tarea prohíbe crear RED en esta
microfase (`CONTRACT_ANALYSIS`), no porque falten decisiones humanas adicionales: el único bloqueo
de **decisión** que resta es `DR-LB004-DB-002`. Una vez resuelto, `LB-004B.2` puede derivar RED para
todas las filas sin requerir una nueva aprobación de producto/seguridad/HTTP/provider.

## RED_SNAPSHOT

| Campo | Valor |
|---|---|
| APPLIES_NOW | NO |
| REASON | Microfase `CONTRACT_ANALYSIS`; además, `DR-LB004-DB-002` (metadata/binding DB) sigue `DECISION_REQUIRED` y bloquea las filas de persistencia/docente-read |
| FUTURE_REQUIREMENT | YES |
| REMAINING_HUMAN_DECISIONS_AFTER_THIS_FREEZE | 1 (`DR-LB004-DB-002`, equipo DB) |

## Falsos positivos prohibidos

- Mock/fake presentado como Azure Blob real.
- Dos clientes contra una sola JVM.
- Dos instancias compartiendo accidentalmente disco.
- 404 de B aceptado como degradación.
- RBAC sin ownership.
- window.open considerado autenticado por existir interceptor Angular.
- Selector local presentado como rollback.
- Checkout uploads vacío presentado como inventario de ambientes.
- mvn verify presentado como E2E Blob/multi-instancia.

## Validación de LB-004B.0 / LB-004B.1

Por instrucción no se ejecuta clean verify. Aplican validación documental, enlaces, consistencia de estados, git diff --check, diff de alcance y estado Git. Pruebas no ejecutadas permanecen NOT_RUN, nunca PASS.

---

# TEST_PLAN — LB-004B.2 (MinIO Storage Foundation, RED → GREEN)

Las filas `STORAGE-001..009`/`AUTH-*`/`LIFE-*`/`HTTP-*`/`MIG-*`/`ROLLBACK-*`/`CACHE-001`/`REG-001`
arriba pertenecen a LB-004B.1 y numeran escenarios a nivel de contrato Azure-Blob-neutral; muchas se
heredan conceptualmente pero LB-004B.2 usa **IDs propios**, definidos por la instrucción recibida,
para el alcance concreto de esta microfase (storage foundation + content security + malware). Este
matrix reemplaza, para efectos de ejecución en B.2, únicamente las filas equivalentes a
`fileId`/ownership/content/HTTP de arriba; `LIFE-*`/`AUTH-004`/`AUTH-005`/`MIG-*`/`ROLLBACK-*`
permanecen `BLOCKED_BY_DB_CONTRACT` bajo `REVIEW_BINDING` y no se crean en B.2 (ver tabla de abajo).

## Behavioral Matrix LB-004B.2

| ID | Requirement | Scenario | Expected | Level |
|---|---|---|---|---|
| STORAGE-001 | controller sin filesystem directo | inspección estática/ArchUnit | `ArchivoController` no importa `java.nio.file.Files`/`Paths` ni SDK MinIO | ArchUnit |
| STORAGE-002 | round-trip store/read vía `FileStoragePort` | store bytes, read por fileId | bytes idénticos | Unit/Component |
| STORAGE-003 | `fileId` UUID independiente de filename | subir con nombres distintos, mismo contenido | `fileId` generado por backend, no derivado del filename | Application/HTTP |
| STORAGE-004 | `MinioFileStorageAdapter` persiste y recupera bytes | store real contra MinIO | bytes idénticos, checksum estable | Integration (`MinioFileStorageAdapterIT`) |
| STORAGE-005 | restart no pierde objeto | store, recrear adapter/cliente, read | mismo objeto disponible | Integration |
| STORAGE-006 | dos instancias/adapters mismo MinIO | adapter A store, adapter B (cliente independiente) read | mismo objeto autorizado | Integration (`STATELESS-001`) |
| SEC-001 | autenticación | sin Bearer | `401` | HTTP/Security |
| SEC-002 | owner válido | estudiante propietario | `200`/`201` según operación | Application/HTTP |
| SEC-003 | actor no owner | estudiante ajeno / docente sin capability | `404` (fail-closed, nunca revela existencia) | Application/HTTP |
| CONTENT-001 | PDF válido | magic bytes `%PDF-`, extensión `pdf` | aceptado | Unit |
| CONTENT-002 | PNG válido | magic bytes `89 50 4E 47 0D 0A 1A 0A` | aceptado | Unit |
| CONTENT-003 | JPEG válido | magic bytes `FF D8 FF` | aceptado | Unit |
| CONTENT-004 | extensión/MIME/magic mismatch | `.exe` renombrado a `.pdf`, magic bytes incorrectos | rechazado, `400` | Unit/HTTP |
| CONTENT-005 | tamaño > 5 MiB | `5*1024*1024 + 1` bytes | rechazado, `400` | Unit/HTTP |
| CONTENT-006 | filename path traversal | `../etc/passwd.pdf`, ruta absoluta, separadores | rechazado/sanitizado | Unit |
| MALWARE-001 | EICAR detectado | subir fixture EICAR | rechazado, nunca almacenado | Integration (`ClamAvMalwareScanAdapterIT`) |
| MALWARE-002 | archivo limpio | PDF/PNG/JPEG válido sin firma | aceptado | Integration |
| MALWARE-003 | ClamAV no disponible/error | scanner inalcanzable | `FAIL CLOSED`, rechazado, nunca `CLEAN` por defecto | Integration/Unit (adapter con cliente simulado solo para este caso de error de transporte) |
| COMPRESSION-001 | contenido sin beneficio (PDF/PNG/JPEG ya comprimidos) | evaluar compresión | se almacena original; `compressed=false` | Unit |
| COMPRESSION-002 | contenido con beneficio | fixture compresible sintético dentro de los tipos permitidos | round-trip recupera bytes originales exactos; `compressed` según resultado | Unit |
| INTEGRITY-001 | checksum estable | mismo contenido subido dos veces | mismo SHA-256 | Unit |

## RED_READINESS_BY_AREA (LB-004B.2)

| Área / IDs | Contrato congelado | RED_APPLIES_NOW | Bloqueo |
|---|---|---|---|
| `STORAGE-001..006` | `PROFESSOR_DECISION.md` (`D-LB004B2-001`), `MINIO_STORAGE_CONTRACT.md` | **YES** | Ninguno |
| `SEC-001..003` | `OWNERSHIP_DECISION.md` (heredado, `FROZEN`) | **YES** | Ninguno (ownership técnico sobre objeto, no requiere `DR-LB004-DB-002`) |
| `CONTENT-001..006` | `CONTENT_SECURITY.md`, `HTTP_CONTRACT_TARGET.md` | **YES** | Ninguno |
| `MALWARE-001..003` | `PROFESSOR_DECISION.md` (`D-LB004B2-001`), `CONTENT_SECURITY.md` | **YES** | Ninguno |
| `COMPRESSION-001..002` | `CONTENT_SECURITY.md` | **YES** | Ninguno |
| `INTEGRITY-001` | `MINIO_STORAGE_CONTRACT.md` | **YES** | Ninguno |
| `AUTH-004`/`AUTH-005` (docente relacionado/ajeno), `STORAGE-002/003`(B.1)/`LIFE-001..004` (attach/lifecycle DB-dependiente) | `OWNERSHIP_DECISION.md §Addendum LB-004B.2` | **NO** | `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT` (`DR-LB004-DB-002`) — fuera de alcance de esta microfase por diseño, no por omisión |
| `MIG-001`, `ROLLBACK-001..002` (B.1) | `PROVIDER_DECISION.md` | **NO** | No aplica a MinIO local recién provisionado (sin objetos preexistentes que migrar); reevaluar si se introduce un provider cloud en una fase posterior |
| `REG-001` (regresión Golden Path) | `AS_IS.md` | **YES** (verificación de no-regresión en `verify`) | Ninguno |

## RED_SNAPSHOT (LB-004B.2)

Ver [LB-004B.2-RED-SNAPSHOT](LB-004B.2-RED-SNAPSHOT.md) para archivos, hash de base, comando y
exit code exacto del RED.

## Falsos positivos prohibidos (adicional a LB-004B.1)

- Presentar un mock de `MinioClient`/ClamAV como IT real contra Docker.
- Presentar EICAR como si certificara detección de malware real arbitrario.
- Tratar `SCAN_ERROR`/timeout de ClamAV como `CLEAN`.
- Presentar `mvn verify` (sin `-Pintegration`, sin Docker corriendo) como prueba de `STORAGE-004..006`/`MALWARE-*`.
- Tratar `DOCENTE_FILE_ACCESS: DENY_BY_DEFAULT` como si fuera la implementación final de
  `DOCENTE_READ_RELATED` (es una postura fail-closed temporal, no el cierre del requisito).

---

# TEST_PLAN — LB-004B.2H hardening posterior a revisión

## Behavioral Matrix

| ID | Requirement | Scenario | Input/State | Observable | Expected | Wrong implementation caught | Level |
|---|---|---|---|---|---|---|---|
| CONTENT-007 | MIME declarado coherente | PDF bytes con `image/png` | `.pdf` + PDF magic | upload/use case | rechazo 400; no scan/store | ignorar `MultipartFile.getContentType()` | Unit/HTTP |
| CONTENT-008 | MIME declarado coherente | PNG bytes con `application/pdf` | `.png` + PNG magic | upload/use case | rechazo 400; no scan/store | validar solo extensión/magic | Unit/HTTP |
| CONTENT-009 | JPEG válido | JPEG declarado correctamente | `.jpeg` + `image/jpeg` + JPEG magic | upload/use case | aceptado | rechazar alias jpeg válido | Unit |
| MALWARE-004 | outage es técnico | scanner timeout/unavailable/protocol error | `MalwareScanException` | HTTP error envelope | 5xx técnico seguro; sin host/puerto/respuesta | mapear outage a 400 de archivo | Application/HTTP |
| INTEGRITY-002 | checksum read | bytes originales no coinciden con metadata | stored object corrupto | download | fail-closed; cero bytes retornados | confiar en metadata sin recalcular | Unit |
| MULTIPART-001 | valid payload en memoria | configuración runtime | `file-size-threshold` | config cargada | `5MB`, nunca `0` | regresión a threshold que permite spool inmediato | Config |
| POLICY-001 | app least privilege | app identity en bucket target | Put/Get/Delete prefix | provider real | PASS | usar root o policy demasiado restrictiva | Infrastructure |
| POLICY-002 | aislamiento | otro bucket + create bucket + anonymous | app/anonymous identity | provider real | DENIED | credencial root o wildcard bucket | Infrastructure |

## RED_SNAPSHOT — LB-004B.2H

Los tests de regresión se agregan antes de producción. El snapshot causal se registra en
`LB-004B.2-VALIDATION.md` con comando, exit code y fallos observados. Los scripts de policy requieren
MinIO real y no se reemplazan por mocks. `verify` normal no certifica `POLICY-001/002`.

