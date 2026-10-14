---
status: draft
type: work-item
scope: frontend
owner: frontend-team
last-reviewed: 2026-09-22
---

# PLAN — LB-001B.1B: DB source of truth — limpieza contractual de Sesion/docenteName (frontend)

Fase 01-planificador. Solo planificación: ninguna línea de producción, ni de test, fue modificada en esta sesión. Este documento continúa la fase `LB-001B.1` del repo backend (`C:\Users\josev\AsistenciasUCO\AsistenciasUCO\docs\work-items\LB-001B.1-db-source-of-truth-cleanup\PLAN.md`), que dejó la ejecución en frontend explícitamente fuera de su autoridad de escritura y nombró esta fase.

## Identidad y autorización

- Fecha: 2026-09-22 (America/Bogota).
- Change class: `CONTRACT_CHANGE` + `BEHAVIOR_CHANGE` (heredado del work item backend de referencia).
- Frontend: rama `develop`, working tree con 32 rutas modificadas/nuevas correspondientes a `LB-001B.1A-frontend-contract-corrections`, ya cerrado en esta misma sesión (`VALIDATION.md`/`CLOSURE.md` con resultado PASS).
- Backend de referencia: rama `sergio`, `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/PLAN.md` — fuente de verdad del contrato DB de `Sesion` (leído completo en esta sesión).
- Aprobación humana (2026-09-22, instrucción de esta tarea): DR-001 y DR-004 quedan resueltos en **Opción B** ("no se agrega campo a DB/backend; se retira del contrato de aplicación"); el alcance de limpieza de `docenteName`/`status` se amplía a las 10 pantallas listadas más abajo; `attendance.mapper.ts` (`StudentAttendanceDTO`/`ClassSessionDTO`/`studentFromDTO()`) queda explícitamente fuera de alcance.
- Objetivo de esta fase: producir el PLAN AS-IS→TARGET con evidencia real (archivo+línea) para que una fase posterior (03-tester-red/04-implementador) ejecute el retiro de campos fantasma. **No se implementa nada en esta sesión.**

## DB SESSION CONTRACT (heredado del backend, no reverificado contra SQL en esta sesión — ver límite)

Tabla `Sesion` en DB solo tiene: `id, nombre, numero, codigo, numeroSemana, grupo, fechaHoraInicio, fechaHoraFin`. **No existen** `descripcion`, `aula`, `tipo`, `topic`, `room`, `docenteName`, `status`/`estado`. Los stored procedures `usp_crear_sesion`/`usp_actualizar_sesion` aceptan `@descripcion`/`@aula`/`@tipo` pero nunca los persisten (ghost parameters, confirmado por lectura directa de SQL en el PLAN.md backend, secciones "DB SESSION CONTRACT" y "Hallazgo central").

**Límite de esta fase:** esta sesión no releyó el SQL de `DB_ROOT` directamente; se apoya en la evidencia ya citada (archivo+línea de SQL) del PLAN.md backend `LB-001B.1`, fechado el mismo día. Si esa evidencia se invalida, este PLAN debe revisarse antes de pasar a 03-tester-red.

`SesionConsultadaApiDto` (frontend, lado de lectura) confirmado en esta sesión — `src/app/core/api/models/sesion-consultada-api-dto.model.ts` — expone exactamente `sesion, grupo, nombre, numero, codigo, numeroSemana, codigoGrupo, nombreGrupo, fechaHoraInicio, fechaHoraFin` (10 campos): **coincide 1:1 con `uv_sesion`, sin drift en lectura backend→frontend DTO**. El drift ocurre en el mapeo de ese DTO a `ClassSession` (modelo de UI) y en el payload de creación/actualización que el frontend envía.

## Clasificación de campos

| Campo | Clasificación | Evidencia (este repo) |
|---|---|---|
| `ClassSession.topic` | CONTRACT_DRIFT + FIELD_SYNTHESIZED_BY_FRONTEND | No existe en `SesionConsultadaApiDto`; `session.service.ts:154` lo deriva de `session.nombre` en el mapeo real; en mocks es texto libre inventado (`session.service.ts:27,41,55,69,85,99,125`) |
| `ClassSession.room` | CONTRACT_DRIFT | No existe en `SesionConsultadaApiDto`; ausente en el mapeo real (`session.service.ts:149-160`, no se asigna `room`); presente solo en mocks/creación (`session.service.ts:24,38,52,66,82,96,122,206`) |
| `ClassSession.tipo` | CONTRACT_DRIFT | No existe en `SesionConsultadaApiDto`; ausente en el mapeo real; presente solo en mocks/creación (`session.service.ts:25,39,53,67,83,97,123,207`) |
| `ClassSession.status` | CONTRACT_DRIFT + FIELD_SYNTHESIZED_BY_FRONTEND | No existe en `SesionConsultadaApiDto` ni en `uv_sesion`; el mapeo real fuerza `status: 'PROGRAMADA'` de forma incondicional (`session.service.ts:158`); mocks usan `'CONCLUIDA'`/`'PROGRAMADA'` fijos; `cancelarSesion()` fuerza `'CONCLUIDA'` en mock (`session.service.ts:296`) |
| `descripcion`/`aula`/`tipo` en `createSession()` (payload HTTP real) | CONTRACT_DRIFT (ghost parameters aceptados y descartados por el SP) | `session.service.ts:224-232`: `this.http.post(.../sesiones, { grupo, nombre, descripcion: data.topic, fechaHoraInicio, fechaHoraFin, aula: data.room, tipo: data.tipo })` — envía exactamente los 3 parámetros fantasma que el backend PLAN confirma como no persistidos |
| `Course.docenteName` | CONTRACT_DRIFT + FIELD_SYNTHESIZED_BY_FRONTEND | No existe en `HorarioDocenteApiDto` (`horario-docente-api-dto.model.ts`, 10 campos, sin `docenteName`); `course.service.ts:83` hardcodea `docenteName: 'Docente UCO'` en el mapeo real de `GET /docente/horarios`; `course.service.ts:109` usa fallback `'Docente Titular'` en mock de creación; `course.service.ts:122-136` (`crearGrupo`, payload HTTP real) sí envía `docenteName: nuevo.docenteName` al backend — **contrato de escritura no confirmado**, ver riesgo #6 |
| `id, nombre, numero, codigo, numeroSemana, grupo/idGrupo, codigoGrupo, nombreGrupo, fechaHoraInicio, fechaHoraFin` | DB_FIELD | `SesionConsultadaApiDto` — sin drift, confirmado en esta sesión |
| `attendance.mapper.ts` — `StudentAttendanceDTO`/`ClassSessionDTO`/`studentFromDTO()` (`estado_asistencia \|\| 'AN'`, l.49; `aula`, `tipo_sesion`, `estado_sesion`, `tema` en el DTO paralelo, l.1-20) | CONTRACT_DRIFT (residuo conocido) | **Fuera de alcance por decisión humana explícita** — se documenta como TECHNICAL_DEBT nuevo, no se corrige en este work item (ver "No alcance") |

## AS-IS y evidencia (archivo + línea, leído directamente en esta sesión)

### `ClassSession` — modelo de UI

| # | Archivo:línea | Evidencia |
|---|---|---|
| 1 | `src/app/core/models/attendance.model.ts:13-26` | `ClassSession` declara `topic: string`, `room?: string`, `tipo?: 'REGULAR'\|'EXTRAORDINARIA'\|'REPOSICION'`, `status: 'PROGRAMADA'\|'EN_CURSO'\|'CONCLUIDA'` junto a los campos reales (`id, courseId, sessionNumber, title, date, startTime, endTime, records`) |

### `session.service.ts` — servicio de sesiones

| # | Archivo:línea | Evidencia |
|---|---|---|
| 2 | `src/app/core/services/session.service.ts:15-104` | `initialSessions` (mock estático de 6 sesiones) asigna `room`, `tipo`, `topic`, `status` con valores inventados para cada sesión |
| 3 | `src/app/core/services/session.service.ts:110-137` | `getSessionsByGroup()` (rama `useMocks`) genera una sesión por defecto con `room: 'Aula Asignada'`, `tipo: 'REGULAR'`, `topic`, `status: 'PROGRAMADA'` inventados |
| 4 | `src/app/core/services/session.service.ts:139-170` | `getSessionsByGroup()` (rama HTTP real) mapea `SesionConsultadaApiDto` → `ClassSession`: `topic: session.nombre` (derivado, no real) y `status: 'PROGRAMADA'` (constante forzada, línea 158); **no** asigna `room` ni `tipo` en esta rama (quedan `undefined` en runtime pese a que el tipo los declara) |
| 5 | `src/app/core/services/session.service.ts:182-232` | `createSession()`: firma acepta `topic, room?, tipo?`; rama mock los usa para construir `ClassSession`; rama HTTP real (l.224-232) los envía como `descripcion: data.topic`, `aula: data.room`, `tipo: data.tipo` al `POST /sesiones` — **estos 3 quedan aceptados y descartados por `usp_crear_sesion`, confirmado por el backend PLAN** |
| 6 | `src/app/core/services/session.service.ts:296` | `cancelarSesion()` (rama mock) fuerza `status: 'CONCLUIDA' as const` y reescribe `topic` con un prefijo `[CANCELADA]` — patrón de codificar estado de negocio dentro de un campo de texto libre |

### `course.service.ts` — servicio de cursos/grupos

| # | Archivo:línea | Evidencia |
|---|---|---|
| 7 | `src/app/core/models/course.model.ts:12` | `Course.docenteName: string` (no opcional) |
| 8 | `src/app/core/api/models/horario-docente-api-dto.model.ts:1-13` | `HorarioDocenteApiDto` no declara `docenteName` (10 campos: `id, idDocente, idGrupo, codigoMateria, nombreMateria, seccion, dia, horaInicio, horaFin, aula, totalEstudiantes`) |
| 9 | `src/app/core/services/course.service.ts:74-87` | `getCurrentTeacherCourses()` (rama HTTP real) mapea `HorarioDocenteApiDto` → `Course` con `docenteName: 'Docente UCO'` hardcodeado (línea 83) |
| 10 | `src/app/core/services/course.service.ts:98-120` | `crearGrupo()` (rama mock) usa `nuevo.docenteName \|\| 'Docente Titular'` (línea 109) |
| 11 | `src/app/core/services/course.service.ts:122-136` | `crearGrupo()` (rama HTTP real) envía `docenteName: nuevo.docenteName` en el `POST /grupos` — dominio `Grupo`, no `Sesion`; **el contrato real de este endpoint no fue confirmado en esta sesión** (ver riesgo #6) |
| 12 | `src/app/core/mocks/course.mock.ts:13,25,37` | 3 cursos mock con `docenteName: 'Dra. María Elena Rostagno'` fijo |

### Pantallas ampliadas (alcance ampliado por decisión humana 2026-09-22)

| # | Archivo:línea | Campo | Evidencia y dominio |
|---|---|---|---|
| 13 | `src/app/features/teacher/teacher-grupos/components/teacher-grupo-hub.component.ts:64` | `docenteName` | Interpolación directa `selectedCourse()?.docenteName` en cabecera informativa |
| 14 | `src/app/features/dean/dean-faculty/dean-faculty.component.ts:165` | `docenteName` | `{{ c.docenteName \|\| 'Docente UCO' }}` en tabla de cursos de la facultad |
| 15 | `src/app/features/dean/dean-faculty/dean-faculty.component.ts:416` | `docenteName` | Ficha resumen de grupo seleccionado |
| 16 | `src/app/features/dean/dean-faculty/dean-faculty.component.ts:472` | `status` (de `ClassSession`, vía `s.status`) | `<app-badge [variant]="s.status === 'CONCLUIDA' ? 'success' : 'info'">{{ s.status }}</app-badge>` en cronograma de sesiones del grupo |
| 17 | `src/app/features/dean/dean-faculty/dean-faculty.component.ts:646` | `docenteName` | Filtro de búsqueda: `c.docenteName && c.docenteName.toLowerCase().includes(q)` |
| 18 | `src/app/features/coordinator/coordinator-students/coordinator-students.component.ts:234` | `docenteName` | Ficha de curso seleccionado en matrícula de estudiantes |
| 19 | `src/app/features/coordinator/coordinator-docentes/coordinator-docentes.component.ts:600` | `docenteName` | `verFichaDocente()`: heurística de coincidencia de texto libre contra `docenteName` (incluye literales `'maria'`/`'docente'` como fallback, líneas 598-602) — evidencia de fragilidad aguas abajo del hardcode de `course.service.ts:83` |
| 20 | `src/app/features/teacher/teacher-grupos/teacher-grupos.component.ts:191,269,290,319,344` | `docenteName` | `grupoForm.docenteName` (modelo de formulario), default hardcodeado `'Dra. María Elena Rostagno'` al crear (l.269), precarga desde `course.docenteName` al editar (l.290), enviado en payload de `crearGrupo`/`actualizarGrupo` (l.319,344) |
| 21 | `src/app/features/teacher/teacher-grupos/teacher-grupos.component.ts:573` | `status` | `sesiones.find((s) => s.status === 'EN_CURSO')` para seleccionar sesión activa al proyectar QR |
| 22 | `src/app/features/teacher/teacher-grupos/teacher-grupos.component.ts:658-666` | `status` (gate) + **síntesis nueva de `StudentAttendance.status`** | `abrirDetalleSesionModal()`: si `sesion.status === 'CONCLUIDA'` y hay estudiantes sin `records`, **inventa** `status: (st.studentId \|\| st.id).endsWith('2') ? 'SJC' : 'AN'` por paridad de ID — mismo patrón DR-002 (fabricación de asistencia) que LB-001B.1A ya corrigió en `attendance-control.component.ts` y `teacher-grupo-sabana.component.ts`, pero **no cubierto** por ese work item en este archivo. Hallazgo nuevo, no anticipado por el PLAN.md backend. |
| 23 | `src/app/features/teacher/teacher-grupos/components/teacher-grupo-form.component.ts:158,244` | `docenteName` | Campo de formulario libre "Docente Responsable"; placeholder `'Dra. María Elena Rostagno'` (mismo literal que el default de `teacher-grupos.component.ts`) |
| 24 | `src/app/features/teacher/teacher-grupos/components/teacher-grupos-list.component.ts:132` | `docenteName` | `{{ course.docenteName }}` en tarjeta de listado |
| 25 | `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sabana.component.ts:77-78` | `status` | `[class]="ses.status === 'CONCLUIDA' ? ... "`, `[title]="ses.status"` — indicador visual por sesión en la sábana. (Nota: la síntesis de `AN`/`SJC` por paridad de ID que existía en este archivo **ya fue retirada por LB-001B.1A**; el `status` de `ClassSession` en sí no fue tocado, correctamente, por estar fuera del alcance DR-001 de esa fase.) |
| 26 | `src/app/features/teacher/teacher-grupos/components/modals/teacher-sesion-detalle-modal.component.ts:28,30` | `status` (de `ClassSession`, vía `sesion()?.status`) | Badge de estado de la sesión en el modal de detalle. **Distinto** de `rec.status` (líneas 66-68 del mismo archivo), que es `StudentAttendance.status` (`AN`/`SJC`/`EX`) — campo real, persistido, **no se toca** (coincidencia de nombre, no de dominio) |
| 27 | `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sesiones.component.ts:47-49,55,60-63,92,105-110,113` | `tipo`, `room`, `topic`, `status` (gate de negocio) | Badge de `tipo`; `Aula: {{ sesion.room \|\| selectedCourse()?.room }}`; `{{ sesion.topic }}`; **`sesion.status !== 'CONCLUIDA'`** habilita/deshabilita los botones "Ajustar Horario" y "Cancelar" (líneas 92,113) — el `status` sintético gobierna una decisión de negocio real en la UI, no solo presentación |

### Golden Path (`attendance-control`) — confirmado explícitamente fuera de alcance de LB-001B.1A, dentro de alcance de LB-001B.1B

| # | Archivo:línea | Evidencia |
|---|---|---|
| 28 | `src/app/features/attendance/attendance-control/attendance-control.component.ts:243` | `isSessionConcluded = computed(() => this.currentSession()?.status === 'CONCLUIDA')` — gate de negocio real: bloquea `openExcuseModal()` (línea 252) y, por extensión, la edición de asistencia cuando `status` sintético indica sesión concluida |
| 29 | `src/app/features/attendance/attendance-control/attendance-control.component.ts:268,272-273` | `onCreateSessionSubmit()` construye el payload de `createSession()` con `topic`, `room`, `tipo` tomados de un formulario de UI — alimenta directamente el AS-IS #5 (ghost parameters enviados al backend) |
| 30 | `src/app/features/attendance/attendance-control/attendance-control.component.ts:439-440` | Selección de sesión activa por `s.status === 'EN_CURSO'` / `'PROGRAMADA'` |

### Confirmación de exclusión — `attendance.mapper.ts`

| # | Archivo:línea | Evidencia |
|---|---|---|
| 31 | `src/app/core/mappers/attendance.mapper.ts:1-20,49,66` | `StudentAttendanceDTO`/`ClassSessionDTO` (snake_case: `aula`, `tipo_sesion`, `estado_sesion`, `tema`) y `studentFromDTO()` con `(dto.estado_asistencia as AttendanceStatus) \|\| 'AN'` (línea 49) — contrato paralelo, no identificado ningún consumidor en esta sesión. **Confirmado sin tocar**, ya validado en el cierre de LB-001B.1A (`VALIDATION.md` de esa fase, punto 1) |

## TARGET (derivado de la decisión humana 2026-09-22 — Opción B de DR-001/DR-004)

- **`ClassSession` (modelo):** retira `topic`, `room`, `tipo`, `status`. Campos finales: `id, courseId, sessionNumber, title, date, startTime, endTime, records` (+ los que agregue DR-003/otros ya resueltos, sin cambio aquí).
- **`session.service.ts`:**
  - `getSessionsByGroup()` (rama real): deja de asignar `topic: session.nombre` y `status: 'PROGRAMADA'`; el mapeo usa exactamente los campos de `SesionConsultadaApiDto` más el split de `date/startTime/endTime` ya resuelto por DR-003.
  - `getSessionsByGroup()` / `initialSessions` (rama mock): mocks se alinean al mismo contrato reducido — sin `topic/room/tipo/status` inventados.
  - `createSession()`: la firma deja de aceptar `topic`, `room`, `tipo`; el `POST /sesiones` deja de enviar `descripcion`, `aula`, `tipo`.
  - `cancelarSesion()` (mock): deja de mutar `status`/`topic`; el estado "cancelada" pasa a representarse solo en la respuesta del backend (`datos: { estado: 'CANCELADA', ... }`, que ya existe en la rama HTTP real) — **no se sintetiza un reemplazo de UI**, consistente con TARGET del backend.
- **`course.service.ts` / `Course`:** retira el literal `'Docente UCO'`/`'Docente Titular'`. `Course.docenteName` pasa a opcional (`docenteName?: string`) o se retira del modelo, sujeto a confirmación de si `crearGrupo`/`actualizarGrupo` (payload HTTP real) tiene un contrato backend legítimo para este campo — **no se crea un endpoint nuevo** para resolverlo (fuera de alcance).
- **Pantallas ampliadas (AS-IS #13-27):** cada una retira la lectura/edición de `docenteName`/`status` de `ClassSession`/`Course` según corresponda, **sin sustituir por una nueva síntesis**. Casos que gatean una decisión de negocio real (`attendance-control.component.ts:243,252`; `teacher-grupo-sesiones.component.ts:92,113`; `teacher-grupos.component.ts:573,658`) se resuelven dejando que el backend sea la única autoridad (error de negocio existente ante operación inválida), no inventando una regla de UI de reemplazo — mismo principio que el TARGET del backend.
- **Hallazgo nuevo #22 (`teacher-grupos.component.ts:658-666`):** la síntesis `status: ... endsWith('2') ? 'SJC' : 'AN'` se retira como parte de este work item (es DR-002-equivalente, no cubierto por LB-001B.1A en este archivo). Se trata como parte de la misma variable principal (retiro de campos fantasma) porque depende directamente de `sesion.status === 'CONCLUIDA'`, que también se retira aquí.
- **`attendance.mapper.ts`:** sin cambios — permanece TECHNICAL_DEBT registrado en `CLOSURE.md` de LB-001B.1A.

## Clase de cambio y alcance de rutas

- **Change class:** `CONTRACT_CHANGE` + `BEHAVIOR_CHANGE`.
- **Variable principal (una sola):** el contrato de `ClassSession`/`Course` en el frontend debe limitarse exactamente a los campos reales expuestos por `SesionConsultadaApiDto`/`HorarioDocenteApiDto`, retirando `topic/room/tipo/status/docenteName` sintetizados, en el modelo, los servicios y las 10+2 pantallas identificadas (Golden Path incluido).
- **Allowed (rutas permitidas para 02-contratos/03-tester-red/04-implementador; nada se escribió aquí):**
  - `src/app/core/models/attendance.model.ts`
  - `src/app/core/models/course.model.ts`
  - `src/app/core/services/session.service.ts` (+ `session.service.spec.ts`, `session.service.contract.spec.ts`)
  - `src/app/core/services/course.service.ts` (+ spec si existe)
  - `src/app/core/mocks/course.mock.ts`
  - `src/app/features/attendance/attendance-control/attendance-control.component.ts` (+ spec)
  - `src/app/features/teacher/teacher-grupos/teacher-grupos.component.ts`
  - `src/app/features/teacher/teacher-grupos/components/teacher-grupo-hub.component.ts`
  - `src/app/features/teacher/teacher-grupos/components/teacher-grupo-form.component.ts`
  - `src/app/features/teacher/teacher-grupos/components/teacher-grupos-list.component.ts`
  - `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sabana.component.ts`
  - `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sesiones.component.ts`
  - `src/app/features/teacher/teacher-grupos/components/modals/teacher-sesion-detalle-modal.component.ts`
  - `src/app/features/dean/dean-faculty/dean-faculty.component.ts`
  - `src/app/features/coordinator/coordinator-students/coordinator-students.component.ts`
  - `src/app/features/coordinator/coordinator-docentes/coordinator-docentes.component.ts`
  - `docs/work-items/LB-001B.1B-db-source-of-truth-cleanup/**` (este work item)
- **Forbidden (rutas prohibidas):**
  - `src/app/core/mappers/attendance.mapper.ts` y su spec — TECHNICAL_DEBT, no se toca.
  - `src/app/core/api/models/sesion-consultada-api-dto.model.ts`, `horario-docente-api-dto.model.ts` — DTOs de lectura ya alineados con la DB; no requieren cambio.
  - Backend, DB, OpenAPI, JPA — sin cambio, tal como el work item backend `LB-001B.1`.
  - `rec.status` (StudentAttendance) en cualquier archivo — es un campo real (AN/SJC/EX), no se confunde con `ClassSession.status`.
  - `docenteId` (distinto de `docenteName`) — no evaluado, presuntamente real (`HorarioDocenteApiDto.idDocente` existe); confirmar en 02-contratos antes de asumir que está limpio.

## Alcance

- Retirar `topic`, `room`, `tipo`, `status` de `ClassSession` y de todo su ciclo de vida en `session.service.ts` (mocks, mapeo de lectura real, `createSession()`, `cancelarSesion()`).
- Retirar el literal `docenteName` hardcodeado de `course.service.ts` y de `course.mock.ts`.
- Aplicar el retiro/ajuste en las 10 pantallas listadas en la decisión humana (AS-IS #13-27), más el Golden Path `attendance-control.component.ts` (AS-IS #28-30), confirmando en cada archivo que el uso pertenece a este contrato antes de editar (ya confirmado en esta sesión para todos los citados; `rec.status` de `teacher-sesion-detalle-modal.component.ts` queda explícitamente excluido por ser otro dominio).
- Incluir el hallazgo nuevo #22 (`teacher-grupos.component.ts:658-666`, síntesis de `AN`/`SJC`) como parte de esta variable, por su dependencia directa de `sesion.status`.
- Confirmar en 02-contratos si `crearGrupo`/`actualizarGrupo` (`course.service.ts:122-136,183`) tiene un contrato backend real para `docenteName` antes de decidir si el payload HTTP lo retira o lo conserva (riesgo #6).

## No alcance

- DR-002, DR-003, DR-005, DR-006, DR-007, DR-008, DR-009/TD-030: no se reabren (ya resueltos por LB-001B.1A o explícitamente fuera de ambas fases).
- `attendance.mapper.ts` (`StudentAttendanceDTO`/`ClassSessionDTO`/`studentFromDTO()`, residuo `estado_asistencia || 'AN'`): TECHNICAL_DEBT registrado, no se corrige en este work item.
- Cambios de DB, SQL, stored procedures, OpenAPI, JPA: prohibidos, igual que en el work item backend.
- Creación de un endpoint nuevo para resolver `docenteName` "de verdad" (p. ej. join con tabla de docentes): fuera de alcance; la decisión aprobada es **retirar** el campo sintetizado, no sustituirlo por una fuente de datos nueva.
- `docenteId` y cualquier campo no citado explícitamente en AS-IS: no se tocan sin evidencia adicional.

## Archivos afectados

**EXISTENTES (a modificar en una fase posterior, ruta comprobada en esta sesión):**
`src/app/core/models/attendance.model.ts`, `src/app/core/models/course.model.ts`, `src/app/core/services/session.service.ts`, `src/app/core/services/session.service.spec.ts`, `src/app/core/services/session.service.contract.spec.ts`, `src/app/core/services/course.service.ts`, `src/app/core/mocks/course.mock.ts`, `src/app/features/attendance/attendance-control/attendance-control.component.ts`, `src/app/features/attendance/attendance-control/attendance-control.component.spec.ts`, `src/app/features/attendance/attendance-control/attendance-control.workflows.spec.ts`, `src/app/features/teacher/teacher-grupos/teacher-grupos.component.ts`, `src/app/features/teacher/teacher-grupos/components/teacher-grupo-hub.component.ts`, `src/app/features/teacher/teacher-grupos/components/teacher-grupo-form.component.ts`, `src/app/features/teacher/teacher-grupos/components/teacher-grupos-list.component.ts`, `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sabana.component.ts`, `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sesiones.component.ts`, `src/app/features/teacher/teacher-grupos/components/modals/teacher-sesion-detalle-modal.component.ts`, `src/app/features/dean/dean-faculty/dean-faculty.component.ts`, `src/app/features/coordinator/coordinator-students/coordinator-students.component.ts`, `src/app/features/coordinator/coordinator-docentes/coordinator-docentes.component.ts`.

**Total: 20 archivos de producción/test existentes** (2 modelos, 2 servicios + 2 specs de servicio, 1 mock, 1 componente Golden Path + 2 specs, 9 pantallas ampliadas).

**NUEVOS:** ninguno — este work item retira campos, no agrega DTOs, modelos ni pantallas.

**RETIRAR (condición previa a implementar):** `topic`, `room`, `tipo`, `status` de `ClassSession` y de cada archivo listado; el literal `'Docente UCO'`/`'Docente Titular'`/`'Dra. María Elena Rostagno'` de `course.service.ts`, `course.mock.ts`, `teacher-grupos.component.ts`, `teacher-grupo-form.component.ts`; la síntesis `endsWith('2') ? 'SJC' : 'AN'` de `teacher-grupos.component.ts:663`.

## Contratos y consumidores afectados

- **DOMAIN:** `ClassSession`, `Course` (frontend) — se reduce su superficie a los campos reales.
- **HTTP (consumo):** `GET /sesiones/grupo/{grupoId}`, `POST /sesiones`, `GET /docente/horarios`, `POST /grupos`, `PUT /grupos/{id}` — el frontend deja de enviar `descripcion/aula/tipo` en la creación de sesión; el contrato de `docenteName` en `POST/PUT /grupos` queda pendiente de confirmación (riesgo #6).
- **Consumidor:** ninguno adicional identificado — `ClassSession`/`Course` son modelos internos de UI, no expuestos a otros sistemas.

## Riesgos y dependencias

1. **Baseline:** el árbol frontend ya tiene 32 rutas de `LB-001B.1A` (ahora cerrado con `VALIDATION.md`/`CLOSURE.md` en esta misma sesión); el rollback de este work item futuro debe basarse en diff por archivo sobre ese estado, no en `git reset`/`checkout` a `HEAD`.
2. **`isSessionConcluded` y gates de negocio en UI (AS-IS #21,22,27,28,30):** retirar `status` sin sustituto requiere decidir cómo la UI refleja "sesión concluida" — la decisión de diseño (TARGET) es no sintetizar un reemplazo y dejar que el backend rechace la operación inválida; esto puede degradar la UX (sin aviso previo al usuario) hasta que exista un contrato backend real para el estado de sesión. Se acepta como consecuencia conocida de Opción B, documentado también en el PLAN.md backend.
3. **RESUELTO (verificado directamente 2026-09-22, fuera de sesión de agente — lectura de SQL y código backend reales):** `docenteName` en `crearGrupo`/`actualizarGrupo` es CONTRACT_DRIFT, mismo patrón que `Sesion`. Evidencia: `Grupo.sql` (DB_ROOT) declara `[docente] uniqueidentifier NOT NULL` — solo una FK a `Docente.id`, nunca un texto/nombre. `usp_crear_grupo.sql`/`usp_actualizar_grupo.sql` solo validan y persisten ese UUID (`usp_validar_docente_exista_por_id_interno`, columna `docente`). El backend `CrearGrupoRequest.java`/`ActualizarGrupoRequest.java` (`infrastructure/adapter/primary/controller/grupo/request/`) solo declaran `idDocente`/`docenteId` (UUID) — **no existe ningún campo `docenteName`** en ninguno de los dos. Con `FAIL_ON_UNKNOWN_PROPERTIES` activo (confirmado por 02-contratos backend para el request de Sesion, mismo `JacksonInputConfig` global), enviar `docenteName` en el body de `POST/PUT /grupos` hoy debería producir 400, no ser ignorado silenciosamente — a confirmar el comportamiento exacto en 03-tester-red. **TARGET:** `crearGrupo()`/`actualizarGrupo()` en `course.service.ts` dejan de enviar `docenteName` en el payload HTTP real (AS-IS #11), igual que su retiro del modelo de lectura.
3b. **Contrato real de `docenteName` para lectura, sí existe (pero no se usa en este work item):** `Docente`→`uv_docente_identidad`(`nombreCompleto`)→`uv_docente`, ya expuesto por endpoints backend **existentes** `GET /api/v1/docentes` y `GET /api/v1/docentes/{docenteId}` (`DocenteController.java:82-87`); `uv_grupo` ya expone `idDocente`. Verificado directamente en DB_ROOT y backend fuera de esta sesión de agente. Por instrucción explícita de la tarea (§16: "usar ese contrato en una tarea posterior o existente; no ampliar este cambio creando endpoints nuevos"), **no se wire-ea aquí** — sería una integración nueva (resolver N nombres de docente por pantalla), no una eliminación de drift. Se documenta como TECHNICAL_DEBT/follow-up en 06-cierre: "docenteName real disponible vía GET /api/v1/docentes/{id}, no wireado; requiere tarea de integración separada, no de limpieza contractual."
4. **Hallazgo nuevo #22 (síntesis `AN`/`SJC` en `teacher-grupos.component.ts`):** no fue anticipado por el PLAN.md backend (que solo mencionó `attendance.mapper.ts` como residuo conocido). Se incluye aquí por decisión de planificación propia; si se prefiere tratarlo como un TD separado en vez de parte de esta variable, debe decidirse antes de 03-tester-red.
5. **Cobertura de tests:** retirar campos de `ClassSession` puede reducir líneas/branches cubiertas por specs existentes que hoy ejercitan `topic/room/tipo/status`; debe verificarse que la cobertura post-cambio no caiga por debajo del piso vigente (Lines ≥ 78.62% / Branches ≥ 62.64%, confirmado en `VALIDATION.md` de LB-001B.1A).
6. **`docenteId` no evaluado:** ver "Forbidden" — riesgo de asumir que está limpio sin evidencia.
7. **Concurrencia con trabajo no relacionado:** si el árbol frontend acumula más cambios no relacionados antes de que esta fase se ejecute, el diff de implementación deberá revalidarse contra un nuevo `git status`.

## Test plan de referencia (para 03-tester-red — ningún test se escribe en esta fase)

- **A.** `ClassSession` sin `topic/room/tipo/status`: test de tipo/compilación (TypeScript) más specs de modelo si existen.
- **B.** `session.service.spec.ts`/`session.service.contract.spec.ts`: mocks y mapeo de `getSessionsByGroup()` sin esos campos; `createSession()` no envía `descripcion/aula/tipo` en el `POST /sesiones` (assert sobre el body exacto); `cancelarSesion()` sin mutación de `status`/`topic`.
- **C.** `course.service.ts`: `getCurrentTeacherCourses()` sin `docenteName` hardcodeado (o con el campo retirado del modelo); `crearGrupo()` — pendiente de decisión (riesgo #3) antes de fijar el RED.
- **D.** `attendance-control.component.spec.ts`/`workflows.spec.ts`: `isSessionConcluded` reemplazado o retirado; `onCreateSessionSubmit()` sin `topic/room/tipo` en el payload.
- **E.** Specs (nuevos o ajustados) por cada una de las 9 pantallas ampliadas, verificando ausencia de `docenteName`/`status` sintetizado en el render y en cualquier lógica de filtro/gate.
- **F.** Regresión: `SesionConsultadaApiDto`/`HorarioDocenteApiDto` sin cambios (confirmar que nadie les agregó campos).
- **G.** Si un test existente afirma expresamente el comportamiento viejo (p. ej. que `status` debe ser `'PROGRAMADA'`), es un `TEST_CONTRACT_CONFLICT` a resolver por 03-tester-red, no a forzar en verde por el implementador.

## Rollback

- Revertir únicamente los archivos listados en "Archivos afectados" vía diff por archivo (no `git reset --hard`/`checkout .`, dado que el árbol frontend ya tiene trabajo previo de `LB-001B.1A` commiteable pero no commiteado aún).
- Sin dato persistido en DB que revertir — es un cambio exclusivo de contrato de aplicación (frontend) y, del lado backend (`LB-001B.1`), de parámetros que el SP ya ignoraba.

## Stop conditions

- **CONTRACT_CONFLICT:** ninguno nuevo identificado en esta fase.
- **RESUELTO:** (a) Esquema real de `Grupo` confirmado — ver riesgo #3: `docenteName` es CONTRACT_DRIFT también en `crearGrupo`/`actualizarGrupo`, mismo TARGET que el resto (retirar del payload).
- **BLOCKED_BY_MISSING_EVIDENCE:** (b) `docenteId` no confirmado como limpio (riesgo #6) — no bloquea el resto del alcance, es un campo aparte no tocado.
- **TEST_CONTRACT_CONFLICT:** ninguno identificado todavía en esta sesión (no se leyeron a fondo los specs existentes de las 9 pantallas ampliadas más allá de confirmar los usos de producción vía grep dirigido — límite declarado); a confirmar en 03-tester-red.

## Definition of Ready

**Resultado: READY (parcial) / NOT_READY (parcial).**

### READY

- `ClassSession` (retiro de `topic/room/tipo/status`) y `Course.docenteName` en el flujo de **lectura**: evidencia AS-IS completa con archivo+línea; TARGET derivado de decisión humana explícita (Opción B); `SesionConsultadaApiDto`/`HorarioDocenteApiDto` confirmados sin drift de lectura.
- Las 9 pantallas ampliadas: alcance confirmado por decisión humana 2026-09-22; cada uso fue localizado y clasificado (dominio `Sesion`/`docenteName` vs. dominio distinto — `rec.status` excluido explícitamente).
- `attendance.mapper.ts`: exclusión confirmada, no bloquea el resto.
- Golden Path (`attendance-control.component.ts`): evidencia AS-IS completa (#28-30); TARGET aplica el mismo principio (sin sustituto sintético).

### READY (actualizado tras verificación directa de `Grupo.sql`/`usp_crear_grupo`/`usp_actualizar_grupo`/`CrearGrupoRequest.java`/`ActualizarGrupoRequest.java`)

- **`docenteName` en el flujo de escritura** (`crearGrupo`/`actualizarGrupo`, `POST/PUT /grupos`): CONFIRMADO CONTRACT_DRIFT — `Grupo.docente` es solo FK UUID, backend no declara `docenteName`. TARGET fijado: se retira del payload, igual que el resto de `docenteName`.

### NOT_READY

- **`docenteId`**: no evaluado, fuera de este work item.
- Wiring del contrato real de `docenteName` (`GET /api/v1/docentes/{id}`, existente pero no usado hoy en estas pantallas): explícitamente diferido a una tarea de integración separada (riesgo 3b), no es parte de esta limpieza.
- Ejecución de 04-implementador: pendiente de 03-tester-red (RED tests).

**READY_FOR_IMPLEMENTATION: sí, para todo el alcance declarado** (lectura y escritura de `Sesion`/`Course`/`Grupo.docenteName` en las 20 rutas listadas). Sin bloqueos activos. Continuar a 03-tester-red.
