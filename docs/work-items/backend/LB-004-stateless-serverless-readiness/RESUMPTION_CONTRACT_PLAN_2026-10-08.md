---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---

# LB-004 — plan de reanudación DB → backend JPA → frontend → E2E

## Autorización, alcance y estado

- **Estado:** `CONTRACT_ANALYSIS_PLANNED`, `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT`, `FULL_E2E: PENDING`; LB-004 NO está DONE ni se reanudan implementaciones por publicar este plan.
- Dependencias: PR backend #15 (JPA-only/storage foundation) supera CI al HEAD `255431254632975cac059bbef40bbcc48fc73b28` pero sigue **sin merge** y requiere revisión/aprobación; documentar SHA de merge cuando ocurra. Además, `LB-008/CLOSURE.md` debe comprobarse según [PAUSE](PAUSE.md) antes de cambiar estado de fase.
- Clase de este plan: `DOCUMENTATION_ONLY / CONTRACT_ANALYSIS`. Variable principal: acordar cómo relacionar un soporte almacenado con la solicitud académica de forma durable y autorizable.
- Owner de persistencia: `johnjduque/gestion-asistencia-db`. Backend solo define necesidades consumidor, nunca migra esquema por sí mismo. Contratos aprobados/freeze y work item DB son condición previa.
- No modificar en esta tarea: SQL, `src/main/**`, frontend, roles, OpenAPI congelado, `pom.xml`, infra; no arrancar implementación hasta DoR de microfase por repo.
- Fuentes: [PROFESSOR_DECISION](PROFESSOR_DECISION.md), [METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md), [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md), [HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md), [CONTENT_SECURITY](CONTENT_SECURITY.md), [STORAGE_LIFECYCLE](STORAGE_LIFECYCLE.md), [E2E_PLAN](E2E_PLAN.md), [PAUSE](PAUSE.md), [auditoría PR](../QUALITY-PR15-recovery/INDEPENDENT_REVIEW_2026-10-08.md).

## Bloqueo DB verificado en el repo dueño

Revisión de `johnjduque/gestion-asistencia-db` `develop`, árbol commit `f2871a9564d6c4cc5abc3745854414243bfda238` (2026-10-08):
- `schema/tables/SolicitudRevisionAsistencia.sql`: tabla contiene id, nombre, asistencia, fecha, estado, justificación solicitud/respuesta. **Sin columna ni vínculo durable del archivo.**
- `schema/stored-procedures/usp_radicar_solicitud_revision_asistencia.sql`: recibe `@soporteNombre` y `@soporteUrl` y los normaliza, pero `INSERT dbo.SolicitudRevisionAsistencia` **no los persiste**.
- `usp_resolver_solicitud_revision_asistencia.sql`: resuelve la solicitud y valida docente titular del grupo, pero no proporciona una consulta para acceder a soporte por `fileId`.
- `docs/contracts/DB_DEVELOP_FREEZE_ADDENDUM.md`: cambios de esquema post-freeze requieren work item y decisión contractual.
- Por lo tanto, **no** inferir que subir a MinIO certifica reclamo radicado/descargable por docente.

## Fases y puertas de aprobación

| Fase | Owner | Trabajo | Gate |
|---|---|---|---|
| D0 — contrato DB (PR separado) | Equipo DB + consumidor backend | Capturar AS-IS/freeze; aprobar alternativa de metadata (A/B); diseñar estado `DRAFT/ATTACHED/ORPHAN/REPLACED`, `fileId UUID`, owner, checksum, MIME verificado, size, createdAt UTC, referencia a revisión, ciclo de vida. Separar bytes (MinIO) de metadata SQL | Contrato/ADR aprobados y nueva release/version DB; pruebas SQL RED/GREEN + rollback + manifest |
| D1 — consultas DB/ownership | Equipo DB | Entregar comandos/mapeos para `fileId→revisión→asistencia→sesión→grupo→docente titular`, permisos institución y titularidad; lectura por dueño/relacionado sin fuga | SP resultado canónico de cuatro campos cuando sea command; query/view de lectura aprobadas; test cross-user/cross-role, 0/N, no-match |
| B1 — backend JPA | Backend | Nuevo puerto de metadata/attachment, adapters JPA en Infrastructure; asociar `soporteArchivoId` de forma transaccional en SQL al radicar; compensación entre MinIO y SQL, idempotencia y reconciliación; implementar lectura docente contextual con `DENY_BY_DEFAULT` antes de confirmar vínculo | Contract-first, DoR READY, RED→GREEN, SQL Server IT, ArchUnit/OpenAPI, seguridad 401/404, sin JDBC runtime |
| F1 — Angular | Frontend | Subida por backend, tomar `fileId`, asociar a radicación, descarga con HttpClient Blob + Bearer; no usar `window.open` ni token en URL; coherencia de máximo 5 MiB | Pruebas UI, manejo de errores de malware/content-type, contrato de consumer comprobado |
| E1 — E2E funcional | Backend + DB + Frontend | Sesión estudiante→upload→radicación→docente titular→descarga bytes SHA256 idénticos; segundo docente no titular 404; restart backend y persistencia; virus EICAR test; ClamAV caído; archivo corrupto; expiración/huérfano | Real MinIO/ClamAV/SQL Server/JWT/Angular; datos aislados, teardown, 0 skips necesarios, evidencias |
| L1 — lifecycle | Equipo + profesor | Retención, purga, archivos abandonados, cold tier y repositorio institucional; tiempos/tier aún **DECISION_REQUIRED** | Decisión aprobada, jobs/compensación, auditoría y alertas; pruebas de no borrar trabajos vigentes |

## Matriz mínima de contrato DB que debe aprobar el owner

| Item | Requisito del consumidor | Estado |
|---|---|---|
| File identity | UUID opaco `fileId`, no filename ni URL externa | DECIDED por backend, persistencia DB pendiente |
| Localización | referencia lógica durable interna; `objectKey` no expuesto al frontend ni usado como identidad pública | DB_DECISION_REQUIRED |
| Estado | `DRAFT`, `ATTACHED`, `ORPHAN`, `REPLACED`; transiciones válidas y fecha UTC | DB_DECISION_REQUIRED |
| Owner | identidad institucional de estudiante validada desde JWT, no valor del cliente | DB_DECISION_REQUIRED |
| Vínculo | archivo asociado a una revisión académica y consultable vía sesión/grupo/docente | BLOCKED |
| Reuso | un archivo no debe asociarse a revisión ajena o a dos revisiones por carrera si contrato no lo permite | DB_DECISION_REQUIRED |
| Transacciones | SQL atomicidad attach; operación storage no participa en tx SQL, diseñar compensación/reconciliación | DB_BACKEND_DECISION |
| Consultas | acceso por `fileId` con contextos y scopes, sin direct storage permission usuario | DB_DECISION_REQUIRED |
| Procedimientos | conservar contrato canónico de cuatro campos (`idCorrelacion`, `mensajeUsuarioResultado`, `mensajeTecnicoResultado`, `estadoResultado`) | REQUIRED |
| Compatibilidad | plan de deprecación `soporteNombre/soporteUrl` y evolución a `soporteArchivoId` | DECISION_REQUIRED |
| Purga | retención declarada, export institucional y cleanup de borradores | FUTURE_DECISION |

## Pruebas DB que deben anteceder B1

- RED: esquema/constraints, `fileId` único; ownership DRAFT/ATTACHED, existencia de revisión, sesión/grupo/docente correctos.
- RED: radicación con archivo propio válida; rechazo ajeno, reutilización o carrera; sin filas huérfanas por error SQL; idempotencia por correlación cuando aprobada.
- RED: lectura de docente relacionado permite, ajeno no revela, estudiante propietario preserva lectura; lifecycle no borra objeto con revisión activa.
- GREEN: ejecución reproducible `test_summary.ps1` de repositorio DB, contrato SP, catálogo de errores, rollback e integridad; nueva freeze manifest sin alterar baseline anterior.
- Backend solo después de release DB: integración real SQL Server con nuevos adapters JPA, salida canónica de SP, pruebas de tenant/scope y persistencia tras restart.

## Decisiones pendientes de producto/seguridad

1. Modelo DB A (tabla metadata separada) vs B (reuso autorizado de estructura actual): **no decidir unilateralmente**. Si se elige A, DB define columnas y migraciones; esta documentación no representa diseño SQL aprobado.
2. Momento de creación de DRAFT/attach y contrato compensación storage↔SQL.
3. Cambiar descarga `inline` a `attachment`, agregar `X-Content-Type-Options: nosniff`, y política de CSP según experiencia Angular; requiere decisión y tests.
4. Comportamiento ante metadatos inconsistentes, huérfanos y archivo reemplazado; define una estrategia de purga durable sin inventar plazo.
5. Cold storage/archival y entrega final a repositorio institucional **no** son requisitos implementados por este plan.

## Comandos y evidencias orientativos

- DB: ejecutar scripts del repo DB en ambiente de pruebas aislado con identidad técnica autorizada; reportar release SHA, `test_summary.ps1`, resultados y skips. **No** reescribir DB local con migrate silencioso.
- Backend Java 25: `./mvnw -B -ntp clean verify`; `./mvnw -B -ntp clean verify -Pintegration` en entorno con SQL/MinIO/ClamAV y fixtures. Verificar `mvnw.cmd` en Windows.
- Frontend: pruebas contract UI y manual E2E con dos identidades de prueba; capturas sanitizadas, correlación, checksum y logs.
- Cierre: `TEST_PLAN`, `VALIDATION`, `CLOSURE` de cada microfase; cero `NOT_RUN` obligatorio, sin asumir `LB-004 DONE` por tener MinIO levantado.

## Stop conditions

No crear esquema DB desde backend; sin SQL contractual liberado, mantener `DOCENTE_READ_RELATED = DENY_BY_DEFAULT`. No exponer bucket, `objectKey`, presigned URLs ni credenciales al frontend; no mover almacenamiento al filesystem local. No modificar los cuatro campos de salida SP, no inventar nuevos roles. Ninguna etapa arranca automáticamente solo porque este plan existe.
