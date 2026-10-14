---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-22
---

# PLAN — LB-001B.1: DB source of truth — limpieza contractual de Sesion (backend ↔ frontend)

Fase 01-planificador. Solo planificación: ninguna línea de producción, test ni DB fue modificada en esta sesión.

## Identidad y objetivo

- Fecha: 2026-09-22 (America/Bogota). Rol: 01-planificador.
- Autorización humana: instrucción pegada verbatim por el usuario en esta sesión (2026-09-22), sección "0. DECISIÓN ARQUITECTÓNICA HUMANA — OBLIGATORIA" y secciones 12-16. Es la referencia de aprobación citada en la sección DoR de este documento.
- Base Git de los tres repos (confirmada de nuevo en esta sesión, coincide con el snapshot que el usuario pegó):
  - BACKEND_ROOT `C:\Users\josev\AsistenciasUCO\AsistenciasUCO`: branch `sergio`, HEAD `fa9aa901c73e55ae31071f4e74cfb2245189243a`, 59 entradas `git status --short` (mezcla de trabajo previo "feat(cloud): integrate Azure Key Vault…", sin relación demostrada con este work item).
  - DB_ROOT `C:\Users\josev\OneDrive\Documentos\AsisteciaUco_db\git\gestion-asistencia-db`: branch `develop`, HEAD `cb63f6f76335209f3b8666a01fb800fb91a423c3`, 16 entradas modificadas + 1 archivo sin trackear (`test/test_titularidad_jerarquica.sql`). **READ ONLY**: ninguna de esas 17 entradas se tocó ni se revirtió en esta sesión.
  - FRONTEND_ROOT `C:\Users\josev\OneDrive\Documentos\Front_Asistecias\AsistenciasUCO-Frontend`: branch `develop`, HEAD `71ee6d32bfe1c6c58c04d0e986e525850ff6eb52`, 32 entradas (19 `M`/`D` + 13 `??`). Confirmado en esta sesión: las entradas `??` incluyen `docs/work-items/LB-001B.1A-frontend-contract-corrections/{PLAN.md,TEST_PLAN.md}` — **ya existe un work item frontend en curso, sin commitear**, que implementa DR-002/DR-003(parcial)/DR-005/DR-007/DR-008 y TD-031/032/033. Ver AS-IS #15-16.
- Objetivo: acotar el contrato de `Sesion` (backend HTTP/DTO/persistencia y frontend DTO/modelo) exactamente a los campos reales de la tabla/vista `Sesion` vigente en DB_ROOT, retirando del contrato de aplicación los campos que la DB no persiste (`descripcion`, `aula`, `tipo`, `topic`, `room`, `docenteName`, `status`), sin modificar DB.
- Criterios de aceptación: los 18 ítems de la sección 32 de la tarea autorizada (matriz completa backend=DB, requests sin campos no persistidos, responses sin campos inexistentes, frontend alineado, sin síntesis de status/room/aula/tipo, sin `docenteName` hardcodeado, mocks fieles, sin mapeo ausencia→AN, sin null→SJC, sin asistencias sintéticas, correcciones 401 intactas, scan de password=0, verify backend y frontend PASS, DB sin modificar, OpenAPI/JPA no iniciados). Esta fase de planificación no verifica ninguno; los deja como criterio de cierre para 05-auditor/06-cierre.
- Skills aplicadas: `uco-baseline` (fase LB, una variable principal), `uco-contratos` (AS-IS→diff→decisión→TARGET, no inventar contrato), `uco-persistencia` (lectura SQL real, sin tocar DB), `uco-testing` (referencia para 03-tester-red).
- Fuentes autoritativas: [AGENTS.md](../../../AGENTS.md), [DEFINITION_OF_READY](../../governance/DEFINITION_OF_READY.md), [LINEA_BASE](../../baseline/LINEA_BASE.md), [LB-001A CLOSURE](../LB-001A-db-backend-asistencia/CLOSURE.md), [LB-001B CLOSURE](../LB-001B-backend-frontend-asistencia/CLOSURE.md) y [CONTRACT_MATRIX](../LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md) (DR-001, DR-004, DR-002/003/005/006/007/008/009), [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md) (TD-005, TD-006, TD-009, TD-019, TD-030, TD-031, TD-032, TD-033), [CONTRACT_ALIGNMENT_PROTOCOL](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md), y el schema SQL real de DB_ROOT (`schema/tables/Sesion.sql`, `schema/views/uv_sesion.sql`, `schema/stored-procedures/usp_crear_sesion.sql`, `schema/stored-procedures/usp_actualizar_sesion.sql`), leído directamente en esta sesión — no se usó documentación narrativa como autoridad mayor que el SQL.

## DB SESSION CONTRACT (evidencia dura, leída directamente del SQL de DB_ROOT)

| Campo | SQL type | Nullability | Origen | Expuesto por `uv_sesion` | Semántica |
|---|---|---|---|---|---|
| `id` | `uniqueidentifier` | NOT NULL (PK) | `Sesion.id` | sí (`id`) | Identificador de sesión |
| `nombre` | `nvarchar(50)` | NOT NULL | `Sesion.nombre` | sí (`nombre`) | Nombre/título de la sesión; `usp_crear_sesion` lo calcula de `@nombre` o `'Sesión #N'` por defecto |
| `numero` | `int` | NOT NULL | `Sesion.numero` | sí (`numero`) | Correlativo dentro del grupo |
| `codigo` | `nvarchar(50)` | NOT NULL | `Sesion.codigo` | sí (`codigo`) | `'SES-' + numero` (generado por el SP) |
| `numeroSemana` | `int` | NOT NULL | `Sesion.numeroSemana` | sí (`numeroSemana`) | Igual a `numero` en la inserción actual |
| `grupo` | `uniqueidentifier` (FK) | NOT NULL | `Sesion.grupo` | sí, como `idGrupo` (+ `codigoGrupo`, `nombreGrupo` vía `JOIN uv_grupo`) | Grupo dueño de la sesión |
| `fechaHoraInicio` | `datetime2` | NOT NULL | `Sesion.fechaHoraInicio` | sí | Inicio real, sin zona horaria explícita (TD-005) |
| `fechaHoraFin` | `datetime2` | NOT NULL | `Sesion.fechaHoraFin` | sí | Fin real, sin zona horaria explícita (TD-005) |

**No existen** en la tabla `Sesion`, en `uv_sesion` ni en las columnas `INSERT`/`UPDATE` de `usp_crear_sesion`/`usp_actualizar_sesion`: `descripcion`, `aula`, `tipo`, `topic`, `room`, `docenteName`, `estado`/`status`. Confirmado leyendo `schema/tables/Sesion.sql` (8 columnas), `schema/views/uv_sesion.sql` (10 columnas, mismas + `idGrupo/codigoGrupo/nombreGrupo`), y el cuerpo `INSERT`/`UPDATE` de ambos SP (no solo su firma de parámetros).

**Hallazgo central (ghost parameters):** `usp_crear_sesion` declara `@descripcion NVARCHAR(250)`, `@aula NVARCHAR(50)`, `@tipo NVARCHAR(50)` y `usp_actualizar_sesion` declara `@aula NVARCHAR(100)`, `@descripcion NVARCHAR(MAX)` — ambos los reciben, los normalizan (`TRIM`/`NULLIF`) y **nunca los usan en el `INSERT`/`UPDATE`** (`usp_crear_sesion.sql` l.8-19 vs l.95-108; `usp_actualizar_sesion.sql` l.8-19 vs l.107-111). Es evidencia SQL directa, no inferencia.

Límite de esta evidencia: se inspeccionaron 2 stored procedures (`usp_crear_sesion`, `usp_actualizar_sesion`), la tabla `Sesion` y la vista `uv_sesion`; no se releyó el 100% de `schema/` (89 archivos) ni `migrations/` en busca de otra definición histórica de `Sesion`. No se ejecutó SQL contra una instancia real (DB_ROOT es solo el repo de definiciones versionadas); `test/test_usp_crear_actualizar_sesion.sql` no asertó estos campos (revisado, sin hallazgos de `descripcion/aula/tipo` como datos de dominio).

## Clasificación de campos (sección 5 de la tarea autorizada)

| Campo | Clasificación | Evidencia |
|---|---|---|
| `descripcion` (Sesion, crear/actualizar) | CONTRACT_DRIFT | Aceptado por ambos SP, nunca persistido; propagado end-to-end en backend (`CrearSesionDTO`, `ActualizarSesionDTO`, `*RepositoryDTO`, `SesionRepositorySqlServerAdapter`) |
| `aula` (Sesion, crear/actualizar) | CONTRACT_DRIFT | Idéntico patrón que `descripcion` |
| `tipo` (Sesion, crear) | CONTRACT_DRIFT | Aceptado por `usp_crear_sesion`, nunca persistido; `usp_actualizar_sesion` ni siquiera lo acepta |
| `topic` (frontend `ClassSession`) | CONTRACT_DRIFT + FIELD_SYNTHESIZED_BY_FRONTEND | No existe en `SesionConsultadaDTO` ni en DB; `session.service.ts` lo deriva de `nombre` (LB-001B F-05/DR-004) |
| `room` (frontend `ClassSession`) | CONTRACT_DRIFT | No existe en `SesionConsultadaDTO` ni en DB; frontend lo deja `undefined` |
| `docenteName` (frontend `Course`, y reutilizado en pantallas de gestión de grupo) | CONTRACT_DRIFT + FIELD_SYNTHESIZED_BY_FRONTEND | No existe en `HorarioDocenteDTO`; `course.service.ts` hardcodea `'Docente UCO'`/`'Docente Titular'` (LB-001B F-01/DR-004) |
| `status`/`estado` de sesión (frontend `ClassSession.status`, backend: ninguno) | CONTRACT_DRIFT + FIELD_SYNTHESIZED_BY_FRONTEND | No existe en `SesionConsultadaDTO` ni en `uv_sesion`; frontend fuerza `'PROGRAMADA'`/`'CONCLUIDA'` (LB-001B F-04/DR-001) |
| `id, nombre, numero, codigo, numeroSemana, grupo/idGrupo, codigoGrupo, nombreGrupo, fechaHoraInicio, fechaHoraFin` | DB_FIELD | Tabla/vista reales; `SesionConsultadaDTO` ya expone exactamente estos 10 campos — **sin drift en lectura** |
| Historial `migrations/` con otros campos de Sesion | HISTORICAL_DRIFT (no verificado en esta sesión; ver riesgo #10) | No revisado a fondo — limitación declarada |

## AS-IS y evidencia

| Hecho | Archivo + símbolo / contrato + versión | Evidencia y límites |
|---|---|---|
| 1 | `schema/tables/Sesion.sql` (DB_ROOT `develop@cb63f6f`, archivo limpio respecto a `HEAD`) — 8 columnas, todas NOT NULL | Leído completo en esta sesión |
| 2 | `schema/views/uv_sesion.sql` — 10 columnas, `JOIN uv_grupo` | Leído completo |
| 3 | `schema/stored-procedures/usp_crear_sesion.sql` — firma acepta `@descripcion/@aula/@tipo`, `INSERT` (l.95-108) no los usa | Leído completo, incluido el cuerpo `TRY/CATCH` |
| 4 | `schema/stored-procedures/usp_actualizar_sesion.sql` — firma acepta `@aula/@descripcion`, `UPDATE` (l.107-111) no los usa | Leído completo |
| 5 | Backend: `CrearSesionDTO.java`, `CrearSesionRequest.java` (l.7-14), `CrearSesionRepositoryDTO.java` propagan `tema,descripcion,fechaHoraInicio,fechaHoraFin,aula,tipo,docente,usuarioEjecutor` end-to-end hasta `SesionRepositorySqlServerAdapter` (`SQL_CREAR_SESION`, l.45-56) | Leído completo cada archivo |
| 6 | Backend: `ActualizarSesionDTO.java`, `ActualizarSesionRequest.java` (l.5-10), `ActualizarSesionRepositoryDTO.java` (record) propagan `nombre,fechaHoraInicio,fechaHoraFin,aula,descripcion,docente,usuarioEjecutor` hasta `SQL_ACTUALIZAR_SESION` (l.69-77) y `MapSqlParameterSource` (l.166-169) | Leído completo |
| 7 | `SesionConsultadaDTO.java` (lado de lectura) expone exactamente `sesion,grupo,nombre,numero,codigo,numeroSemana,codigoGrupo,nombreGrupo,fechaHoraInicio,fechaHoraFin` — **coincide 1:1 con `uv_sesion`, sin drift** | Leído completo; confirma MATCH ya documentado en LB-001B C-002b |
| 8 | Frontend `attendance.model.ts` (l.9,18,22-24): `ClassSession.topic: string`, `room?: string`, `tipo?: 'REGULAR'\|'EXTRAORDINARIA'\|'REPOSICION'`, `status: 'PROGRAMADA'\|'EN_CURSO'\|'CONCLUIDA'` | Leído con grep dirigido |
| 9 | Frontend `session.service.ts`: múltiples asignaciones literales `status: 'PROGRAMADA'`/`'CONCLUIDA'` (mocks y mapeo real, líneas 28,42,56,70,86,100,126,158,208,296) | grep; coincide con LB-001B F-04 |
| 10 | Frontend `course.service.ts` (l.83,109): `docenteName: 'Docente UCO'` / `nuevo.docenteName \|\| 'Docente Titular'` | grep; coincide con LB-001B F-01 |
| 11 | `docenteName` se usa además en pantallas **fuera** de `attendance-control` (el Golden Path analizado por LB-001B): `teacher-grupo-hub.component.ts` l.64, `dean-faculty.component.ts` l.165,416,646, `coordinator-students.component.ts` l.234, `coordinator-docentes.component.ts` l.600, `teacher-grupos.component.ts` l.191,269,290,319,344, `teacher-grupo-form.component.ts` l.158,244, `teacher-grupos-list.component.ts` l.132 | grep global en `src/app`; no analizado en profundidad — ver riesgo de alcance #4 |
| 12 | `status`/`isSessionConcluded` también se usa fuera de `attendance-control`: `teacher-grupo-sabana.component.ts` l.77, `teacher-sesion-detalle-modal.component.ts` l.28, `teacher-grupo-sesiones.component.ts` l.92,113, `teacher-grupos.component.ts` l.573,658 | grep global; mismo riesgo de alcance |
| 13 | `attendance.mapper.ts` contiene **dos contratos paralelos**: (a) `fromGroupStudentsAndAttendances()` (el que LB-001B documentó como Golden Path real, `estado ?? null`, ya correcto — DR-002 no revertido) y (b) `studentFromDTO()`/`StudentAttendanceDTO`/`ClassSessionDTO` (snake_case, con `aula`, `tipo_sesion`, `estado_sesion`, `tema`, y `estado_asistencia \|\| 'AN'` — residuo idéntico al prohibido en la sección 18 de la tarea) | Leído completo el archivo (l.1-100); consumidores de `studentFromDTO`/`ClassSessionDTO` **no identificados** en esta sesión |
| 14 | Frontend `attendance-control.component.ts` (l.318-337,377): el password de matrícula ya no tiene fallback literal — usa `data.password?.trim() ?? ''` con `passwordError` obligatorio si está vacío | Leído; TD-032 parece remediado en el árbol sucio, pero sigue `ABIERTA` en el ledger (sin VALIDATION/CLOSURE) |
| 15 | `AsistenciasUCO-Frontend/docs/work-items/LB-001B.1A-frontend-contract-corrections/PLAN.md` (sin commitear) declara alcance DR-002/003(parcial)/005/007/008 + TD-031/032/033, **excluye explícitamente** DR-001, DR-004, DR-006, DR-009/TD-030, y su "Stop conditions" dice literalmente "No iniciar LB-001B.1B" | Leído completo el PLAN.md; `TEST_PLAN.md` no leído a fondo en esta sesión |
| 16 | `AsistenciasUCO-Frontend` tiene `TEST_PLAN.md` de LB-001B.1A pero **no** `VALIDATION.md` ni `CLOSURE.md` — el work item frontend está implementado pero no cerrado | `find docs/work-items` en frontend, solo 2 archivos |
| 17 | Git status de los tres repos confirmado de nuevo en esta sesión coincide con el snapshot pegado por el usuario (backend 59, frontend 32, DB 16 M + 1 `??`) | `git status --short` ejecutado en los tres repos en esta sesión |

## TARGET (derivado de la decisión humana, secciones 0 y 12-16 de la tarea autorizada — Opción B de DR-001 y DR-004 en el CONTRACT_MATRIX de LB-001B)

- **Backend — crear/actualizar Sesion:** `CrearSesionRequest`/`CrearSesionDTO`/`CrearSesionRepositoryDTO` retiran `descripcion`, `aula`, `tipo` (conservan `grupo`, `tema`→`nombre`, `fechaHoraInicio`, `fechaHoraFin`, `docente`, `usuarioEjecutor`). `ActualizarSesionRequest`/`ActualizarSesionDTO`/`ActualizarSesionRepositoryDTO` retiran `aula`, `descripcion`. `SesionRepositorySqlServerAdapter` deja de enviar `@descripcion/@aula/@tipo` en `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION` (los SP siguen aceptándolos como parámetros opcionales — no se toca DB; simplemente el backend no los completa, o si Jackson exige `FAIL_ON_UNKNOWN_PROPERTIES`, el campo deja de existir en el request y se rechaza si el cliente lo envía).
- **Backend — lectura de Sesion:** `SesionConsultadaDTO` **sin cambios** — ya coincide con `uv_sesion`. No se agrega `status`/`topic`/`room`/`tipo`/`docenteName`.
- **Frontend — `ClassSession`:** retira `topic`, `room`, `tipo`, `status`. `SessionService` deja de sintetizar esos valores. UI (`isSessionConcluded()` y sus consumidores en `attendance-control*`) se retira sin sustituir por otra regla inventada (sección 12 de la tarea); el backend/SP sigue siendo la única autoridad para rechazar operaciones sobre una sesión ya cerrada (vía error de negocio existente, no vía un `status` de UI).
- **Frontend — `Course.docenteName`:** retira el literal `'Docente UCO'`/`'Docente Titular'`; **no** se crea un endpoint nuevo para resolverlo (fuera de alcance por instrucción explícita, sección 16). Las pantallas que hoy muestran `docenteName` quedan con el campo ausente hasta una tarea posterior — **decisión de alcance pendiente**, ver riesgo #4.
- **Mocks:** `session.mock`/`course.mock` (no inspeccionados aún en esta sesión) deben alinearse al mismo contrato real — verificación pendiente en 02-contratos.
- **DR-001 y DR-004** (LB-001B CONTRACT_MATRIX): pasan de `PENDING` a `RESOLVED — Opción B`, con decisión/aprobador/referencia = esta autorización humana (2026-09-22, pegada verbatim en esta sesión). **No se edita el CONTRACT_MATRIX.md de LB-001B en esta fase** (ya está cerrado); la resolución formal de esos DR queda registrada aquí y su traslado al documento original es tarea de 02-contratos/06-cierre con aprobación explícita de reabrir un work item cerrado.

## Clase de cambio y alcance de rutas

- **Change class:** `CONTRACT_CHANGE` + `BEHAVIOR_CHANGE` (tal como lo declara la tarea autorizada).
- **Variable principal (una sola):** el contrato de `Sesion` (backend HTTP/DTO/persistencia + frontend DTO/modelo) debe limitarse exactamente a los campos reales de la tabla/vista `Sesion` vigente en DB_ROOT, retirando todo campo no persistido (`descripcion/aula/tipo/topic/room/docenteName/status`).
  - Nota de gobernanza (`uco-baseline`: "conserva una variable principal por tarea"): la tarea autorizada agrupa además verificación de residuos `||'AN'`/asistencias sintéticas/password (secciones 18-22). Se tratan aquí como **verificación confirmatoria** de decisiones ya resueltas por DR-002/DR-007 y TD-031/032/033 en LB-001B.1A (frontend), no como una segunda variable de decisión. Si en 02-contratos aparece un hallazgo de residuo `AN`/asistencia sintética que **no** esté ya cubierto por LB-001B.1A (p. ej. el `studentFromDTO()`/`ClassSessionDTO` de AS-IS #13), se abre como work item o TD separado, no se resuelve dentro de esta variable.
- **Allowed (rutas permitidas, para 02-contratos/03-tester-red/04-implementador; nada se escribió aquí):**
  - `src/main/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/**`
  - `src/main/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/**`
  - `src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/repository/dto/CrearSesionRepositoryDTO.java`
  - `src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/repository/dto/ActualizarSesionRepositoryDTO.java`
  - `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/request/CrearSesionRequest.java`
  - `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/request/ActualizarSesionRequest.java`
  - `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/validation/CrearSesionRequestValidator.java` (y su equivalente de actualizar si existe)
  - `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/mapper/SesionHttpMapper.java` (solo si mapea `descripcion/aula/tipo`; a confirmar en 02-contratos)
  - `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` (solo `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION` y sus `PARAM_*`/`MapSqlParameterSource` de creación/actualización; **no** tocar `SQL_CONSULTAR_*`)
  - `src/test/java/**` equivalentes a los paquetes anteriores
  - `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/**` (este work item)
- **Forbidden (rutas prohibidas):**
  - **DB_ROOT completo** — read-only absoluto; ni los 16+1 archivos ya sucios se tocan ni se revierten.
  - `contracts/openapi/**`, cualquier anotación/dependencia OpenAPI nueva, JPA, nuevas dependencias/tecnología.
  - `SesionConsultadaDTO.java` y su mapper/consulta de lectura (ya alineados; cualquier cambio ahí sería fuera de esta variable).
  - `docs/baseline/LINEA_BASE.md` (se actualiza en 06-cierre, no en planificación).
  - `docs/work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md` — cerrado; no se edita en esta fase (ver TARGET).
  - Cualquier archivo del repo **frontend** — en esta sesión solo se leyó para evidencia; su escritura no está autorizada desde esta sesión backend (ver Riesgos #2 y "No alcance").

## Alcance

- Backend: retirar `descripcion/aula/tipo` del contrato de creación/actualización de `Sesion` (request HTTP → DTO aplicación → DTO de puerto secundario → llamada SP), en las verticales `crearsesion` y `actualizarsesion`.
- Confirmar (ya confirmado, sin cambio) que `SesionConsultadaDTO` no requiere modificación.
- Registrar formalmente la resolución de DR-001/DR-004 (Opción B) como evidencia trazable para que 02-contratos la aplique.
- **Decisión humana (2026-09-22, resuelve riesgo #4):** el alcance de `docenteName`/`status` se AMPLÍA a todas las pantallas encontradas por búsqueda global (§31 de la tarea autorizada), no solo `attendance-control`. Incluye explícitamente `teacher-grupo-hub.component.ts`, `dean-faculty.component.ts`, `coordinator-students.component.ts`, `coordinator-docentes.component.ts`, `teacher-grupos.component.ts`, `teacher-grupo-form.component.ts`, `teacher-grupos-list.component.ts`, `teacher-grupo-sabana.component.ts`, `teacher-sesion-detalle-modal.component.ts`, `teacher-grupo-sesiones.component.ts` (AS-IS #11-12). Cada ocurrencia se corrige solo si pertenece al dominio `Sesion`/`docenteName` de este contrato (no se tocan usos de otros dominios que compartan nombre por coincidencia — confirmar en 02-contratos antes de editar cada archivo).
- **Decisión humana (2026-09-22, resuelve riesgo #5):** `attendance.mapper.ts` → `StudentAttendanceDTO`/`ClassSessionDTO`/`studentFromDTO()` (AS-IS #13) **no se modifica en este work item**. Se registra como TECHNICAL_DEBT nuevo en `docs/baseline/TECHNICAL_DEBT.md` (repo frontend) por 06-cierre, describiendo el contrato paralelo y el residuo `estado_asistencia || 'AN'` sin resolver, para una tarea futura.
- **Decisión humana (2026-09-22, resuelve riesgos #2/#3):** se construye sobre el árbol frontend ya sucio. Antes de tocar archivos frontend compartidos: (a) cerrar formalmente LB-001B.1A generando `VALIDATION.md`/`CLOSURE.md` en `docs/work-items/LB-001B.1A-frontend-contract-corrections/` del repo frontend, sobre el diff ya implementado (DR-002/003(parcial)/005/007/008, TD-031/032/033); (b) el trabajo de esta tarea en frontend (retiro de `topic/room/tipo/status/docenteName`, es decir DR-001/DR-004 + el alcance ampliado de este punto) se registra como un work item **nuevo en el repo frontend**, nombrado `LB-001B.1B-db-source-of-truth-cleanup`, consistente con el nombre que el propio `PLAN.md` de LB-001B.1A ya anticipaba ("No iniciar LB-001B.1B") — evita fragmentar trazabilidad entre repos. El work item backend conserva su nombre `LB-001B.1` (ya creado, sin cambio).

## No alcance

- DR-002, DR-003, DR-005, DR-006, DR-007, DR-008, DR-009/TD-030: no se reabren. DR-002/003/005/007/008 son responsabilidad de LB-001B.1A (frontend, en curso); DR-006 y DR-009/TD-030 permanecen abiertos y bloquean LB-001C (sin cambio aquí).
- TD-005 (timezone), TD-006 (identificación numérica), TD-009 (estados legacy de asistencia), TD-019 (contratos DB ausentes de Grupo/Horario) — contexto citado, no se resuelven.
- OpenAPI freeze (LB-001C): sigue `NOT STARTED`, bloqueada por TD-030; esta tarea no la inicia.
- Implementación real en el repo frontend: queda documentada como AS-IS/TARGET aquí, pero su PLAN/TEST_PLAN/implementación pasa a `LB-001B.1B-db-source-of-truth-cleanup` en el repo frontend, bajo el pipeline de gobernanza propio de ese repo (fuera de la autoridad de escritura de esta sesión backend).
- `attendance.mapper.ts` (`StudentAttendanceDTO`/`ClassSessionDTO`/`studentFromDTO()`): se documenta como TECHNICAL_DEBT nuevo, no se corrige aquí (decisión humana 2026-09-22).
- Cambio de firma de los stored procedures `usp_crear_sesion`/`usp_actualizar_sesion` (retirar `@descripcion/@aula/@tipo` de su firma): es cambio de DB, prohibido en este work item; el backend simplemente deja de enviarlos.

## Archivos afectados

**EXISTENTES (ruta comprobada, backend):**
`CrearSesionDTO.java`, `CrearSesionRequest.java`, `CrearSesionRepositoryDTO.java`, `CrearSesionMapper.java`, `CrearSesionRepositoryMapper.java`, `CrearSesionDomain.java`, `CrearSesionUseCaseImpl.java`, `CrearSesionRequestValidator.java`, `ActualizarSesionDTO.java`, `ActualizarSesionRequest.java`, `ActualizarSesionRepositoryDTO.java`, `ActualizarSesionMapper.java`, `ActualizarSesionRepositoryMapper.java`, `ActualizarSesionDomain.java`, `ActualizarSesionUseCaseImpl.java`, `SesionRepositorySqlServerAdapter.java` (secciones de creación/actualización), `SesionHttpMapper.java` (a confirmar), y sus tests unitarios homónimos ya localizados por grep (`CrearSesionRepositoryMapperTest.java`, `CrearSesionDomainTest.java`, `CrearSesionUseCaseImplTest.java`, `CrearSesionMapperTest.java`, `ActualizarSesionRepositoryMapperTest.java`, `ActualizarSesionDomainTest.java`, `ActualizarSesionUseCaseImplTest.java`, `ActualizarSesionMapperTest.java`, `SesionControllerContractTest.java`, `SesionRepositorySqlServerAdapterTest.java`, `SesionRepositoryMockAdapterTest.java`).

**EXISTENTES (evidencia frontend, no se escriben desde esta sesión backend — ejecución vía `LB-001B.1B-db-source-of-truth-cleanup` en el repo frontend):** `attendance.model.ts`, `session.service.ts`, `course.service.ts`; mocks `session.mock.ts`/`course.mock.ts` (rutas no confirmadas aún — pendiente en 02-contratos); pantallas con `docenteName`/`status` listadas en AS-IS #11-12 — **alcance confirmado por decisión humana 2026-09-22** (ver "Alcance"), cada archivo se valida contra el contrato real antes de editar. `attendance.mapper.ts` queda explícitamente excluido (TECHNICAL_DEBT, no se edita).

**NUEVOS:** ninguno — este work item retira campos, no agrega DTOs ni endpoints.

**RETIRAR (condición previa a implementar):** los campos `descripcion`, `aula`, `tipo` de todos los DTO/request de creación/actualización de `Sesion` listados arriba; `topic`, `room`, `tipo`, `status` de `ClassSession` (frontend); el literal `'Docente UCO'`/`'Docente Titular'` de `course.service.ts`.

## Contratos y consumidores afectados

- **DOMAIN:** `Sesion` (backend), `ClassSession` (frontend) — se reduce su superficie a los campos reales.
- **HTTP:** `POST /api/v1/sesiones` (crear) y el endpoint de actualización de sesión (`PUT`/`PATCH`, a confirmar el verbo exacto en 02-contratos) — cambio de request body que **retira** campos hoy aceptados. Sin OpenAPI publicado (TD-002), el impacto de compatibilidad se limita a los consumidores reales identificados.
- **PERSISTENCE:** sin cambios en DB_ROOT; el backend deja de enviar parámetros que los SP ya ignoran. Los SP conservan sus parámetros opcionales (`= NULL`), por lo que dejar de enviarlos es compatible sin cambio de firma DB.
- **Consumidor confirmado:** `AsistenciasUCO-Frontend` (`session.service.ts`, formularios de creación/actualización de sesión) — el mapeo exacto de sus requests HTTP a estos campos no se inspeccionó a fondo en esta sesión (se confirmó el modelo de lectura `ClassSession` y los usos de `topic/room/tipo/status/docenteName`, no el payload exacto que envía al crear/actualizar). **Pendiente en 02-contratos.**
- Sin evidencia de otros consumidores (no se encontró colección Postman ni cliente externo del backend en este checkout).

## Riesgos y dependencias

1. **Baseline sucio en los tres repos:** backend 59 entradas, frontend 32, DB 16+1; ninguno es un snapshot limpio. El rollback de este work item debe basarse en diff por archivo, no en `git reset`/`checkout` a `HEAD`. Recomendación antes de 04-implementador: aislar o commitear el trabajo no relacionado (Azure Key Vault en backend; LB-001B.1A en frontend) para no mezclar diffs de distintos work items en el mismo archivo.
2. **RESUELTO (decisión humana 2026-09-22):** LB-001B.1A (frontend) se cierra primero (`VALIDATION.md`/`CLOSURE.md` sobre su diff ya implementado) y el trabajo de esta tarea en frontend se ejecuta como work item separado `LB-001B.1B-db-source-of-truth-cleanup`, construido encima de ese estado. Ver "Alcance".
3. **RESUELTO (decisión humana 2026-09-22):** `LB-001B.1` (backend, este work item) y `LB-001B.1B` (frontend, nuevo) son IDs distintos y complementarios — no hay fragmentación: `LB-001B.1B` es exactamente la fase que el `PLAN.md` de LB-001B.1A ya anticipaba con ese nombre.
4. **RESUELTO (decisión humana 2026-09-22):** el alcance de `docenteName`/`status` se amplía a todas las pantallas listadas en AS-IS #11-12, no solo `attendance-control`. Ver "Alcance".
5. **RESUELTO (decisión humana 2026-09-22):** `attendance.mapper.ts` (`StudentAttendanceDTO`/`ClassSessionDTO`/`studentFromDTO()`) no se corrige en este work item; se documenta como TECHNICAL_DEBT nuevo en 06-cierre (repo frontend). No bloquea el resto del alcance.
6. B-01/B-02/B-03 de LB-001B (semántica de re-guardado SP, nullability DB, serialización `LocalTime`) siguen `BLOCKED_BY_MISSING_EVIDENCE`; no bloquean el alcance de este work item (retiro de campos) pero sí cualquier expansión futura del contrato de `Sesion`.
7. DR-006 y DR-009/TD-030 permanecen abiertos y bloquean explícitamente LB-001C; este work item no los resuelve ni habilita `READY_FOR_LB001C`.
8. Las verificaciones de residuo `AN`/null→SJC/asistencias sintéticas (secciones 18-20 de la tarea) se solapan con DR-002/DR-007 ya cubiertos por LB-001B.1A; repetirlas aquí es confirmatorio (ver AS-IS #13 para la única brecha nueva detectada) y no debe convertirse en una segunda decisión de producto dentro de esta variable principal.
9. `TECHNICAL_BUILD_GATE = PASS` según LINEA_BASE (evidencia de TECH-001); no se volvió a ejecutar `mvn verify` en esta sesión de planificación. Recomendación: confirmarlo antes de 04-implementador.
10. No se revisó `migrations/` de DB_ROOT en busca de HISTORICAL_DRIFT (campos de `Sesion` en versiones anteriores del esquema); si existieran, no cambian el TARGET (la DB vigente manda) pero podrían explicar por qué el backend/frontend original introdujo esos campos — evidencia pendiente, no bloqueante.
11. El equipo DB no ha confirmado si planea retirar `@descripcion/@aula/@tipo` de la firma de los SP (cambio de DB, fuera de este work item) o si estos quedarán como parámetros opcionales sin uso permanentemente. No cambia el TARGET del backend (deja de enviarlos de cualquier forma) pero es información pendiente para el equipo DB.

## Test plan

Referencia para 03-tester-red (ningún test se escribe en esta fase):

- **A.** `CrearSesionRequest`/`ActualizarSesionRequest` ya no deserializan `descripcion/aula/tipo`; verificar el comportamiento exacto según `JacksonInputConfig` (¿`FAIL_ON_UNKNOWN_PROPERTIES` rechaza el campo si un cliente lo envía, o simplemente se ignora?) antes de fijar el RED.
- **B.** `CrearSesionDTO`/`CrearSesionRepositoryDTO`/`ActualizarSesionDTO`/`ActualizarSesionRepositoryDTO` sin esos campos; mappers y `UseCaseImpl` actualizados; tests unitarios existentes ajustados (no se modifican para forzar GREEN sin justificación — si un test actual afirma el comportamiento viejo, es un `TEST_CONTRACT_CONFLICT` a resolver por 03-tester-red, no por el implementador).
- **C.** `SesionRepositorySqlServerAdapter`: `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION` sin `:descripcion/:aula/:tipo`; test de contrato SQL (`SqlStoredProcedureContractIT` o equivalente) confirma que el SP sigue aceptando la llamada sin esos parámetros (son opcionales `= NULL` en el SP).
- **D.** `SesionConsultadaDTO`: test de regresión (no RED nuevo) confirmando que no se le agregó ningún campo.
- **E.** Registro documental: DR-001/DR-004 quedan citados como `RESOLVED — Opción B` con referencia a esta autorización humana, trasladado al `CONTRACT_MATRIX` de LB-001B solo con aprobación explícita de reabrir ese work item cerrado.
- **F (frontend, fuera de mi escritura):** `ClassSession` sin `topic/room/tipo/status`; `SessionService` sin síntesis; specs actualizados. A coordinar con el pipeline de gobernanza del repo frontend, idealmente después de que LB-001B.1A cierre.

## Rollback

- **Backend:** revertir únicamente los archivos listados en "Archivos afectados" vía diff por archivo (no `git reset --hard`/`checkout .`, dado que el árbol ya estaba sucio con trabajo previo no relacionado). Sin migración DB ni dato persistido que revertir — los SP nunca guardaron esos campos.
- **DB:** no aplica — `READ ONLY`, sin cambios de ningún tipo.
- **Frontend:** fuera de la escritura de esta sesión; su rollback es responsabilidad del pipeline de gobernanza del repo frontend.

## Stop conditions

- **CONTRACT_CONFLICT:** ninguno nuevo dentro del alcance de esta tarea (TD-028 sobre métodos HTTP y TD-030 sobre códigos de error no aplican a este retiro de campos).
- **BLOCKED_BY_MISSING_EVIDENCE:**
  - (a) Confirmación del payload exacto que el frontend envía hoy al crear/actualizar una sesión (contratos y consumidores, sin inspección profunda en esta sesión) — pendiente en 02-contratos.
  - (b) Generación de `VALIDATION.md`/`CLOSURE.md` de LB-001B.1A (frontend) antes de tocar archivos frontend compartidos — acción de 06-cierre/pipeline frontend, ya no es una decisión pendiente (resuelta, ver riesgo #2).
  - Riesgos #4 (alcance `docenteName`/`status`) y #5 (`attendance.mapper.ts`) quedan **RESUELTOS** por decisión humana 2026-09-22 — ya no bloquean.
- **TEST_CONTRACT_CONFLICT:** ninguno identificado todavía — no existen tests RED nuevos en este alcance; si un test unitario existente afirma expresamente que `descripcion/aula/tipo` se persisten o se exponen, eso sería un `TEST_CONTRACT_CONFLICT` a resolver por 03-tester-red, no observado en la lectura de esta sesión.

## Deuda conocida y validación manual

- TD-005 (timezone), TD-006 (identificación numérica), TD-009 (estados legacy de asistencia), TD-019 (contratos DB ausentes de Grupo/Horario), TD-030 (VAL_003) — citadas como contexto; sin cambio de estado en este work item.
- TD-031/TD-032/TD-033 — pendientes de `VALIDATION.md`/`CLOSURE.md` en el work item frontend LB-001B.1A. TD-032 (password por defecto) parece remediado en el árbol sucio (AS-IS #14) pero **no se cierra aquí**; su cierre formal corresponde al pipeline frontend.
- MV-001 (E2E frontend + Keycloak + SQL Server + SSE, `USE_MOCKS=false`) sigue pendiente; no se ejecuta en esta fase.

## Definition of Ready

**Resultado: READY (parcial) / NOT_READY (parcial)** — ver desglose por sub-alcance, tal como exige DEFINITION_OF_READY para clases `CONTRACT_CHANGE`/`BEHAVIOR_CHANGE`.

### READY para el sub-alcance BACKEND (retiro de `descripcion/aula/tipo` del contrato de creación/actualización de `Sesion`, sin tocar el lado de lectura)

Fundamento, punto por punto contra DEFINITION_OF_READY:

- Repositorios/snapshots identificados y hashes/HEAD registrados (ver "Identidad y objetivo").
- Owner (backend-team) y consumer (frontend) identificados.
- Golden Path definido ([GOLDEN_PATH_ASISTENCIA](../../baseline/GOLDEN_PATH_ASISTENCIA.md), [LB-001B CONTRACT_MATRIX §2](../LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md)) y alcance de objetos DB acotado a `Sesion` (tabla + vista + 2 stored procedures, leídos como SQL real, no como documentación narrativa).
- Sin secretos en la evidencia recolectada.
- Capacidad de inspección de provider (backend) y consumer (frontend) confirmada — ya ejercida en esta sesión.
- `TECHNICAL_BUILD_GATE = PASS` según LINEA_BASE, sin excepción activa requerida para esta clase de cambio.
- **Contrato aprobado:** la decisión humana pegada verbatim en esta tarea (secciones 0 y 12-16, 2026-09-22) resuelve DR-001 y DR-004 en **Opción B** ("no se agrega campo a DB/backend; se retira del contrato de aplicación"). Esto constituye la aprobación con decisión/responsable/referencia que exige DEFINITION_OF_READY — la referencia es el propio mensaje autorizado citado en este PLAN, no un archivo generado por el agente.
- Cero `CONTRACT_CONFLICT`/`TEST_CONTRACT_CONFLICT` abiertos relevantes al sub-alcance backend.

### Decisiones humanas recibidas (2026-09-22) que desbloquean alcance — READY condicionado a la secuencia declarada

- **Alcance `docenteName`/`status` ampliado** a todas las pantallas de AS-IS #11-12 (ya no `BLOCKED`; ver "Alcance"). Cada archivo se confirma contra el contrato real en 02-contratos antes de editarlo.
- **`attendance.mapper.ts`** queda fuera de alcance de implementación; se registra como TECHNICAL_DEBT (ya no `BLOCKED`; no requiere identificar consumidores para *este* work item).
- **Secuencia frontend acordada:** 1) cerrar LB-001B.1A (`VALIDATION.md`/`CLOSURE.md` sobre el diff ya implementado en el árbol sucio) → 2) crear y ejecutar `LB-001B.1B-db-source-of-truth-cleanup` en el repo frontend para DR-001/DR-004 + alcance ampliado. Ninguna de las dos es responsabilidad de escritura de esta sesión backend, pero quedan planificadas y con nombre fijado.

### NOT_READY para los siguientes sub-alcances (no bloquean el anterior; se listan para que 02-contratos/03-tester-red no los den por autorizados)

- **Confirmación del payload exacto de creación/actualización de sesión que envía el frontend hoy:** pendiente de inspección profunda en 02-contratos.
- **Ejecución real de la secuencia frontend** (cierre LB-001B.1A + creación/ejecución de LB-001B.1B): planificada aquí, pero su ejecución corresponde al pipeline de gobernanza del repo frontend — no ocurre automáticamente por haberla documentado en este PLAN backend.
- **SESSION CONTRACT: ALIGNED_WITH_DB** y los demás cierres declarativos de la sección 33 de la tarea autorizada: requieren que 04-implementador complete y 05-auditor verifique; esta fase solo planifica.

**No se declara `READY_FOR_LB001C`.** DR-006, DR-009/TD-030 y la política temporal (TD-005) permanecen abiertos, tal como exige explícitamente la sección 33 de la tarea autorizada. `LB-001C` sigue `NOT STARTED`.
