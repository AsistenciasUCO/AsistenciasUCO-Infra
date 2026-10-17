---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# OWNERSHIP DECISION — LB-004B.1 (FROZEN)

## Autoridad y límite

Esta matriz congela la decisión mínima de acceso para LB-004B.1 a partir del consumer confirmado
en LB-004B.0 y del AS-IS backend. Es contrato aprobado dentro del alcance de esta microfase
(`CONTRACT_ANALYSIS`); no amplía RBAC más allá de lo aquí escrito y no autoriza implementación por
sí sola — eso exige `TEST_PLAN` congelado y DoR `READY`. Donde no hay requisito/consumer evidenciado,
el resultado es `DENY_BY_DEFAULT` / `OUT_OF_SCOPE`, nunca acceso inferido por rol.

## 401 vs 404 (Layer 1 y ownership)

| Situación | HTTP | Razonamiento |
|---|---|---|
| Sin Bearer o Bearer inválido | `401` | Layer 1, `SecurityConfig`; comportamiento ya vigente para `/api/v1/**` |
| Bearer válido, rol excluido por la política HTTP aprobada | `403` | Layer 1; no aplica hoy porque la regla es `authenticated()` global, no por rol, para `/archivos/**` |
| Bearer válido, rol permitido, sin relación (ownership) con el `fileId`/revisión solicitado | `404` | Application; no se revela existencia del objeto a un actor sin relación |
| Bearer válido, rol permitido, con relación confirmada | `200`/`201`/`202` según operación | Application autoriza y ejecuta |

`FOREIGN_FILE_HTTP: 404` se congela para upload de terceros, download ajeno y attach sobre un
`fileId`/revisión que no pertenece al actor. Nunca `403` para ocultar existencia de un recurso
ajeno cuando el rol sí tiene la capability HTTP.

## Matriz funcional final por actor

| Actor | UPLOAD | ATTACH | READ | Estado |
|---|---|---|---|---|
| `ESTUDIANTE` propietario | `DECIDED: YES`. Autenticado; el owner del objeto nuevo es siempre la identidad institucional resuelta del JWT, nunca un campo de request. Un draft nace ligado a esa identidad, sin relación de sesión/revisión todavía (la relación se fija en `ATTACH`). | `DECIDED: YES`, solo si el `fileId` es `DRAFT`, pertenece al estudiante autenticado, no está expirado/huérfano y la revisión destino es del propio estudiante. `fileId` ajeno o ya `ATTACHED`/`REPLACED` → `404`. | `DECIDED: YES`. El estudiante propietario puede leer (descargar) su propio soporte, en cualquier estado `DRAFT` o `ATTACHED` que le pertenezca. Es la extensión mínima y no controvertida del principio de ownership ya congelado (el dueño de un recurso lee su propio recurso); no crea acceso a datos de terceros y no requiere una decisión de producto adicional. El frontend confirmado hoy no consume esta lectura, lo cual no la prohíbe como capability backend. | `FROZEN` |
| `DOCENTE` relacionado | `OUT_OF_SCOPE`. Ningún consumer ni requisito evidenciado; no se crea capability de upload para docente. | `OUT_OF_SCOPE`. El docente nunca adjunta en nombre del estudiante. | `DECIDED: YES`, únicamente para soportes de revisiones de sesiones/grupos bajo su titularidad institucional (mismo patrón `InstitutionalScopePort`/SEC_002 usado en el Golden Path para `grupoId`). Docente sin relación con el grupo/sesión de la revisión → `404`. **Dependencia de implementación:** esta regla exige una capability de consulta que hoy no existe (`GET /docente/reclamos` responde `FeatureUnavailable` AS-IS); ver `DB_PUBLIC_CONTRACT_CHANGE_REQUIRED: YES` en [DECISIONS](DECISIONS.md). La regla de ownership queda `FROZEN`; su implementación queda bloqueada por la dependencia DB, no por falta de decisión. | `FROZEN` (regla), `BLOCKED_ON_DB` (implementación) |
| `COORDINADOR` | `OUT_OF_SCOPE` / `DENY_BY_DEFAULT` | `OUT_OF_SCOPE` / `DENY_BY_DEFAULT` | `OUT_OF_SCOPE` / `DENY_BY_DEFAULT` | `FROZEN`: no se inventa acceso por rol. Un requerimiento futuro exige su propio `PRODUCT_DECISION` y work item; no se reabre dentro de LB-004. |
| `ADMINISTRADOR` | `OUT_OF_SCOPE` / `DENY_BY_DEFAULT` | `OUT_OF_SCOPE` / `DENY_BY_DEFAULT` | `OUT_OF_SCOPE` / `DENY_BY_DEFAULT` | `FROZEN`: un rol administrativo no implica acceso a documentos potencialmente sensibles; no se crea bypass global por conveniencia técnica ni operacional. |

El ownership se resuelve en Application mediante identidad institucional (JWT) y relación durable
con la revisión/sesión/grupo. Nunca por nombre, object key, URL, rol aislado, ni por el hecho de
conocer un `fileId`.

## Decisiones de lifecycle/HTTP congeladas en esta microfase

| Campo | Decisión | Justificación |
|---|---|---|
| `SUPPORT_OPTIONAL` | `YES` | Ya confirmado por AS-IS backend y frontend: una revisión puede radicarse sin soporte. No cambia. |
| `POST_ATTACH_REPLACEMENT` | `OUT_OF_SCOPE` (no permitido en esta fase; no se crea endpoint ni operación) | No hay consumer ni requisito para reemplazar un soporte ya `ATTACHED`. El frontend solo reemplaza *antes* de radicar (`REPLACED` como candidato huérfano del draft anterior), lo cual ya está cubierto por el estado `REPLACED` de `OWNERSHIP_DECISION` previo. Reemplazar un adjunto ya confirmado requeriría una decisión de producto y un contrato explícito futuros; no se inventa aquí. |
| `DELETE_ENDPOINT` | `NO` | No existe requisito, retención ni evidencia legal que sostenga un `METHOD_EXCEPTION` conforme a `API_DESIGN_RULES` (`FULL_REPLACEMENT_OR_TRUE_DELETE` no tiene evidencia). No se crea `DELETE` público. La limpieza de huérfanos (`ORPHAN`) es un proceso interno de reconciliación, no un endpoint HTTP invocable por el cliente. |
| `RETENTION` | `OUT_OF_SCOPE` (sin plazo numérico inventado) | No hay autoridad de producto/legal para fijar un plazo. Tratamiento explícito mientras no se apruebe: un `DRAFT` no adjuntado dentro de una ventana operacional (el valor de la ventana es `PRODUCT_DECISION_REQUIRED`, no se inventa un número) pasa a candidato `ORPHAN` y se limpia mediante un reconciliador idempotente basado en estado durable, nunca en heap de una réplica. Un objeto `ATTACHED` se conserva indefinidamente — no se borra automáticamente — hasta que exista un contrato de retención/borrado aprobado. Un objeto `REPLACED` sigue el mismo tratamiento que `ORPHAN` para el objeto sustituido. |

## Estados del archivo (sin cambios respecto a LB-004B.0, confirmados)

| Estado | Definición contractual | Transición / tratamiento |
|---|---|---|
| `DRAFT` | Bytes guardados y metadata durable registrada para el estudiante autenticado, todavía sin revisión vinculada. | Nace solo cuando storage y metadata quedan confirmados; puede adjuntarse una vez. |
| `ATTACHED` | Objeto vinculado de forma durable a una revisión aceptada. | No cambia de dueño ni se sobrescribe; la lectura usa la relación con revisión/sesión/grupo. |
| `ORPHAN` | Bytes sin metadata confirmada, o draft no adjunto que superó la ventana permitida. | Reconciliación/cleanup idempotente; nunca se publica ni se trata como soporte válido. |
| `REPLACED` | Objeto anterior cuyo vínculo fue sustituido por uno nuevo. | Reemplazar crea un nuevo `fileId`; no sobreescribe bytes ni reutiliza object key. |

## Resultado

```text
OWNERSHIP_CONTRACT: FROZEN
ESTUDIANTE_UPLOAD: DECIDED YES (own identity only)
ESTUDIANTE_ATTACH: DECIDED YES (own draft, own revision)
ESTUDIANTE_READ_OWN: DECIDED YES
DOCENTE_READ_RELATED: DECIDED YES (rule frozen; implementation BLOCKED_ON_DB query capability)
COORDINADOR: OUT_OF_SCOPE / DENY_BY_DEFAULT
ADMINISTRADOR: OUT_OF_SCOPE / DENY_BY_DEFAULT
SUPPORT_OPTIONAL: YES
POST_ATTACH_REPLACEMENT: OUT_OF_SCOPE
DELETE_ENDPOINT: NO
RETENTION: OUT_OF_SCOPE (treatment defined, no numeric plazo)
FOREIGN_FILE_HTTP: 404
```

## Addendum LB-004B.2 — runtime posture mientras `REVIEW_BINDING` está bloqueado

La regla `DOCENTE_READ_RELATED: DECIDED YES` permanece congelada como decisión de producto y no se
retira. Pero mientras `DR-LB004-DB-002` no esté resuelto (ver [PROFESSOR_DECISION](PROFESSOR_DECISION.md)
y `DECISIONS.md §D-LB004B2-001`), la capability de consulta `fileId → revisión → sesión → grupo →
docente` no existe. El GREEN de LB-004B.2 implementa, por lo tanto, la postura fail-closed explícita
pedida por la instrucción recibida en vez de simular la regla con datos no verificables:

```text
DOCENTE_FILE_ACCESS: DENY_BY_DEFAULT / BLOCKED_BY_DB_CONTRACT (runtime, hasta resolver DR-LB004-DB-002)
COORDINADOR_FILE_ACCESS: DENY_BY_DEFAULT (sin cambio)
ADMINISTRADOR_FILE_ACCESS: DENY_BY_DEFAULT (sin cambio)
```

Es preferible romper temporalmente una lectura docente insegura que mantener `authenticated() +
rol` como si fuera ownership. `ESTUDIANTE_UPLOAD`/`ESTUDIANTE_ATTACH_OWN_DRAFT`/`ESTUDIANTE_READ_OWN`
se implementan en GREEN sin bloqueo, porque dependen únicamente de la identidad institucional del
JWT y de metadata técnica del objeto (`ownerSubject`), no de `DR-LB004-DB-002`.

`ownerSubject` de MinIO es únicamente una protección técnica temporal para objetos `DRAFT`; no se
convierte en autoridad académica. La autorización final de `ATTACHED` debe combinar JWT con la
relación durable en SQL Server (`revisión/estudiante/sesión/grupo/docente`). MinIO nunca autoriza a
un usuario final.
