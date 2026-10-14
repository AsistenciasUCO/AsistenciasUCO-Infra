# CONTRACT MATRIX — LB-001B.4

## Evidencia

| Sistema | Repo/versión | Archivo/objeto | Identidad | Autoridad |
|---|---|---|---|---|
| DB | `gestion-asistencia-db`, rama `feat/db-golden-path-baseline-freeze` | `docs/contracts/DB_BASELINE_CONTRACT.md` | SHA-256 `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec`; HEAD observado `99190f0...`; `GENERATED_FROM_COMMIT: UNCOMMITTED_WORKTREE` | OWNER / snapshot aprobado |
| Backend | `AsistenciasUCO`, rama `sergio` | código/tests citados | base `fa9aa901...`, worktree sucio heredado | CONSUMER DB / OWNER HTTP |

## Matriz

| ID | Capacidad | DB provider | Backend AS-IS | TARGET aprobado | Estado inicial |
|---|---|---|---|---|---|
| B4-01 | Canal técnico | `DBCODE=<code>|<detail>`; detalle no estable | Clasificación por frases | Parser formal; detalle irrelevante | MISMATCH |
| B4-02 | `SEC_001`, `SEC_002` | autorización/titularidad | Sin rama formal, 500 | `403/FORBIDDEN` | MISMATCH |
| B4-03 | `ATT_001-003` | JSON/lote inválido/duplicado | Sin rama formal | `400/VALIDATION_ERROR` | MISMATCH |
| B4-04 | `GEN_002` | input obligatorio inválido | Sin rama formal | `400/VALIDATION_ERROR` | MISMATCH |
| B4-05 | `RC_001` | estado de asistencia inválido | Texto libre | `400/VALIDATION_ERROR` | MISMATCH |
| B4-06 | `SES_001` | sesión inexistente | Texto libre | `404/RESOURCE_NOT_FOUND` | MISMATCH |
| B4-07 | `SES_003` | cierre legacy no soportado | 500 | `501/FEATURE_UNAVAILABLE`; fuera del Golden Path endpoint target | MISMATCH |
| B4-08 | `SES_004` | ventana temporal inválida | 500 | `400/VALIDATION_ERROR` | MISMATCH |
| B4-09 | `EST_004` | estudiante sin pertenencia activa | Texto libre | `403/FORBIDDEN` | MISMATCH |
| B4-10 | Código desconocido/malformado | no catalogado/no contractual | puede caer a heurística | 500 controlado; jamás validación accidental | MISMATCH |
| B4-11 | Legacy sin DBCODE | contratos antiguos | heurística existente | conservar compatibilidad fuera del Golden Path | MATCH (a preservar) |
| B4-12 | Grupo `aula` | campo inexistente; SP sin `@aula` | HTTP→JDBC todavía lo usa | retirar vertical completa | MISMATCH |
| B4-13 | HorarioEstudiante `aula` | snapshot compacto no congela la vista | cadena completa lo usa | no fabricar; comprobar DB oficial antes de retirar/cerrar | BLOCKED_BY_MISSING_EVIDENCE |
| B4-14 | Sesión create/update ghosts | no existen / firmas sin `idDocente` | corregido en LB-001B.3 | preservar | MATCH |
| B4-15 | SesionMateriaEstudiante UTC | `DATETIME2` UTC target | mapper dependiente del timezone host | `toLocalDateTimeUtc` | MISMATCH |
| B4-16 | Realtime `occurredAt` | contrato `Instant`/UTC | tipo correcto, test wire ausente | ISO-8601 con `Z` probado | MISSING_IN_CONSUMER |
| B4-17 | GET estudiantes grupo | response usa vistas secundarias no listadas en snapshot compacto | adapter y tests existentes | validar mapping/response e IT; sin inventar columnas | BLOCKED_BY_MISSING_EVIDENCE hasta validación |
| B4-18 | Serverless | HTTP/DB stateless; SSE local | `Sinks` en memoria | `SINGLE_INSTANCE_OK / MULTI_INSTANCE_PROVIDER_REQUIRED` documental | MATCH con limitación |

## Contrato de errores aprobado

El mapping formal es por código, no por texto posterior a `|`:

| DBCODE | HTTP | `ApiErrorResponse.code` | Excepción semántica |
|---|---:|---|---|
| `SEC_001`, `SEC_002`, `EST_004` | 403 | `FORBIDDEN` | `ForbiddenException` |
| `ATT_001`, `ATT_002`, `ATT_003`, `GEN_002`, `RC_001`, `SES_004` | 400 | `VALIDATION_ERROR` | `ValidationException` |
| `SES_001` | 404 | `RESOURCE_NOT_FOUND` | `ResourceNotFoundException` |
| `SES_003` | 501 | `FEATURE_UNAVAILABLE` | `FeatureUnavailableException` |
| desconocido/malformado | 500 | `ERR_DB_UNCLASSIFIED` en frontera técnica; envelope controlado | `DatabaseOperationException` |

`DBCODE`, `mensajeTecnicoResultado` y su detalle no se exponen al frontend. `RESOURCE_NOT_FOUND` es el código vigente del catálogo backend para la semántica NOT_FOUND.

## LB-001B.4A — Session contract polish (2026-09-24)

| ID | Capacidad | DB provider | Backend | Estado |
|---|---|---|---|---|
| B4A-01 | `tema` en `Sesion` | inexistente | eliminado; `tema/topic/descripcion/aula/tipo/status/room` → 400 `FIELD_UNKNOWN` | MATCH |
| B4A-02 | `docente` en create/update | SP sin `@idDocente` | eliminado del transporte; rol validado vía `findDocenteIdByUsuario` | MATCH |
| B4A-03 | Params `usp_crear_sesion`/`usp_actualizar_sesion` | `@idGrupo`/`@idSesion`, `@nombre`, `@fechaHoraInicio`, `@fechaHoraFin`, `@idCorrelacion`, `@idUsuarioEjecutor` | sin cambios | MATCH |
| B4A-04 | Longitud `Sesion.nombre` | `nvarchar(50)` (LB-001B.1 PLAN) | valida 1..150 | **ALIGNED (4B)** — TD-048 CLOSED; `nombre` 1..50 = DB `nvarchar(50)` |
| B4A-05 | DR-010 listas | n/a | listas completas AS-IS, sin paginación ni orden garantizado | RESOLVED Opción A |

## Contrato congelado

**APPROVED** para B4-01..B4-12 y B4-14..B4-18 con los gates de evidencia indicados.

Evidence of approval: instrucción explícita del usuario `LB-001B.4 — FINAL BACKEND CONTRACT CLOSURE`, 2026-09-23, y snapshot DB final cuyo SHA coincide. B4-13/B4-17 no autorizan inventar shape; solo validación contra DB oficial o evidencia del adapter/response según la tarea.
