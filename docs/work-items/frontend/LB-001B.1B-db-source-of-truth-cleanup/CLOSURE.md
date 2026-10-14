---
status: draft
type: work-item
scope: frontend
owner: frontend-team
last-reviewed: 2026-09-22
---

# CLOSURE — LB-001B.1B: DB source of truth — limpieza contractual de Sesion/docenteName (frontend)

Fase 06-cierre. Fecha de cierre: 2026-09-22 (America/Bogota).

**Estado: CERRADO — DoD cumplido**, con dos anotaciones de gobernanza registradas (no
bloqueantes, ver "Desviación documentada") y un hallazgo de discrepancia sobre la referencia
cruzada al work item hermano backend (ver "Referencia cruzada").

## 0. Verificación ligera de cierre (propia de esta fase)

`git status --porcelain` del árbol de trabajo confirma exactamente el estado descrito por
`AUDIT.md` §2: 56 rutas sin commitear (32 de `LB-001B.1A` ya cerrado + las de `LB-001B.1B`),
más los `.spec.ts` nuevos de `03-tester-red`. No se encontraron cambios adicionales que
contradigan lo auditado. `docs/frontend-features-pending.md` tenía, antes de esta fase, un
único cambio pendiente sin commitear (la línea de "Excusas" heredada del cierre de
`LB-001B.1A`); no había ninguna entrada previa para `attendance.mapper.ts`/residuo `|| 'AN'`
pese a que el `CLOSURE.md` de `LB-001B.1A` anunciaba su registro — se corrige en esta fase
(ver sección 3).

## 1. Qué se resolvió

Se retiró, en comportamiento de runtime (no en superficie de tipo — ver "Desviación
documentada"), la síntesis de datos que no existen en la DB (`Sesion`: `topic`, `room`,
`tipo`, `status`; `Course`: `docenteName`) de las 20 rutas de producción identificadas en
`PLAN.md` (2 modelos, 2 servicios, 1 mock, 1 componente Golden Path, 9 pantallas ampliadas +
`course.mapper.ts` como ajuste de tipo menor no anticipado), sin sustituir ese drift por una
nueva síntesis de UI:

- `session.service.ts`: ningún punto de construcción de `ClassSession` (mocks, mapeo real de
  `getSessionsByGroup()`, `createSession()`, `cancelarSesion()`) asigna `topic/room/tipo/status`;
  el `POST /sesiones` deja de enviar los parámetros fantasma `descripcion/aula/tipo`.
- `course.service.ts`/`course.mock.ts`: se retiran los literales `'Docente UCO'`/
  `'Docente Titular'`/`'Dra. María Elena Rostagno'`; `crearGrupo()`/`actualizarGrupo()` dejan
  de enviar `docenteName` en el payload HTTP real (confirmado como `CONTRACT_DRIFT` también en
  escritura: `Grupo.docente` en DB es solo FK UUID, ver `PLAN.md` riesgo #3).
- 9 pantallas ampliadas + Golden Path (`attendance-control.component.ts`): retiran la
  lectura/edición de `docenteName`/`status` sin sustituto sintético; el hallazgo nuevo #22
  (síntesis `AN`/`SJC` por paridad de ID en `teacher-grupos.component.ts:658-666`) fue
  eliminado por depender directamente de `sesion.status`.
- Verificado por `grep` exhaustivo en todo `src/app` (AUDIT.md §3): cero asignaciones de
  producción a los 4 campos de `ClassSession` fuera de `attendance.mapper.ts` (excluido por
  decisión humana explícita desde `PLAN.md`).

Evidencia numérica (reproducida de forma independiente en `AUDIT.md`, no solo declarada por
`VALIDATION.md`): 177/177 specs GREEN, build de producción exit 0, `coverage:realtime:check`
PASSED (Lines 95.62%/Branches 87.50%, umbral 90%/80%), `npm run verify` (gate compuesto real
del repo: `test:ci` + `coverage:realtime:check` + build producción) exit 0.

## 2. Desviación documentada y aceptada — `@deprecated` en vez de retiro literal

**Qué se decidió:** `ClassSession` conserva los 4 campos (`topic`, `room?`, `tipo?`, `status`)
en el **tipo**, marcados `@deprecated` con nota explicando la razón, en vez de retirarlos
literalmente de la interfaz como pedía el TARGET original del `PLAN.md`. El comportamiento en
runtime sí implementa el TARGET completo: estos campos quedan siempre `undefined` en los
puntos de construcción de producción (con un type-escape-hatch `as unknown as ClassSession`
documentado inline y acotado a esos puntos), verificado por los 28 tests RED y por el grep
exhaustivo de `AUDIT.md` §3.

**Por qué fue necesario (verificado, no solo alegado):** retirar los campos literalmente
rompe la compilación TypeScript (`strict`, excess-property checks) en dos grupos de archivos
que 04-implementador no tiene autoridad para editar: (1) `attendance.mapper.ts`
(`sessionToDTO()` hace `tema: model.topic`/`estado_sesion: model.status` sin coalescencia,
exigiendo no-opcionalidad), explícitamente prohibido de tocar por ser TECHNICAL_DEBT fuera de
alcance; (2) 5 specs RED ya congelados con fixtures tipados que declaran los 4 campos.
Confirmado con repro mínimo (`tsc --strict --noEmit`) antes de decidir, según `VALIDATION.md`
§5.

**Lección de proceso a registrar (no defecto de código):** este es un `TEST_CONTRACT_CONFLICT`
según la propia tipificación de `VALIDATION.md` §5, y el protocolo de `AGENTS.md`/`uco-testing`
exige que ese tipo de conflicto se resuelva con trazabilidad por el rol correspondiente
**antes** de codificar, no que 04-implementador lo descubra y resuelva unilateralmente durante
la implementación y lo documente post-hoc — aunque la resolución técnica sea correcta en
comportamiento (confirmado por `AUDIT.md` §3, independiente). `05-auditor` señaló lo mismo
sobre el toque de `course.mapper.ts` (archivo no listado en "Allowed" ni en "Forbidden" del
`PLAN.md`, ajuste mínimo y correcto pero no anunciado antes de aplicarse). Ambas quedan
registradas aquí como **excepciones de proceso aceptadas retroactivamente por auditoría, no
como precedente** para que futuras fases repitan el patrón "decidir primero, informar
después" ante un `TEST_CONTRACT_CONFLICT`.

## 3. Qué queda abierto (deuda técnica y follow-ups, no cubiertos aquí)

- **`docenteName` real, no wireado.** El contrato real para el nombre del docente existe y
  está disponible hoy vía `GET /api/v1/docentes/{docenteId}` (y `GET /api/v1/docentes`),
  verificado directamente contra `DocenteController.java` del backend (`PLAN.md` riesgo 3b).
  Por instrucción explícita del alcance de este work item, **no se integra aquí** — sería una
  integración nueva (resolver N nombres de docente por pantalla), no una eliminación de
  drift. Queda como follow-up futuro documentado, registrado también en
  `docs/frontend-features-pending.md` (sección 3 de este documento).
- **4 campos `@deprecated` en `ClassSession` pendientes de retiro literal.** El retiro
  literal de `topic/room/tipo/status` de la interfaz queda bloqueado mientras
  `attendance.mapper.ts` (y sus 5 specs consumidores congelados) sigan acoplados a esos
  nombres sin operador de coalescencia. Retirarlos requiere, en un work item posterior,
  resolver primero esa TECHNICAL_DEBT (o confirmar que `attendance.mapper.ts` es código
  muerto y eliminarlo) y ajustar los fixtures de specs afectados — decisión que no le
  corresponde a este work item ni a un implementador actuando solo.
- **`attendance.mapper.ts` — residuo `(dto.estado_asistencia as AttendanceStatus) || 'AN'`**
  (`studentFromDTO()`, línea 49): TECHNICAL_DEBT ya conocida y registrada en el cierre de
  `LB-001B.1A` (`CLOSURE.md` de esa fase, sección "Qué queda"); confirmada intacta y sin
  regresión por `AUDIT.md` §7 de esta fase. No se corrige aquí, por la misma decisión de
  alcance de `LB-001B.1A` y `LB-001B.1B`.
- **El margen de cobertura global no es un gate real del proyecto.** `AUDIT.md` §5 confirma
  que no existe script de gate para cobertura global en `package.json` — el único gate
  automatizado es `coverage:realtime:check` (acotado a `src/app/core/realtime/**`), que pasa
  sin cambios. La caída aparente de Lines/Branches globales (78.62%/62.64% en `LB-001B.1A` →
  60.72%/41.47% aquí) es un efecto estructural de que 03-tester-red agregó specs nuevos para
  9 pantallas que antes no tenían ningún test, arrastrando al bundle de cobertura servicios
  grandes previamente invisibles (`attendance-claim.service.ts`, `admin-management.service.ts`,
  entre otros, ninguno tocado por este work item). No se trata como regresión ni como
  bloqueante; se recomienda a un work item de mantenimiento futuro decidir si fijar un nuevo
  piso de cobertura global sobre la base de 177 tests.
- **`docenteId`:** no evaluado por este work item (distinto de `docenteName`); queda fuera,
  sin evidencia de que esté limpio o sucio.

## 4. Estado de LB-001B.1A y cierre de LB-001B.1B

- **LB-001B.1A (frontend contract corrections):** ya **CERRADO — DoD cumplido**, confirmado
  por lectura directa de `docs/work-items/LB-001B.1A-frontend-contract-corrections/CLOSURE.md`
  en esta misma sesión de cierre (151/151 tests, cobertura 78.62%/62.64%, build exit 0, sin
  literales de contraseña productiva). No se reabre ni se modifica en esta fase.
- **LB-001B.1B (este work item):** se declara **CERRADO — DoD cumplido** en esta fecha, sobre
  la base de: `PLAN.md` READY_FOR_IMPLEMENTATION, `RED_SNAPSHOT.md` (28 RED reproducibles),
  `VALIDATION.md` (GREEN con la desviación documentada en sección 2 de este documento), y
  `AUDIT.md` (veredicto independiente "LISTO PARA 06-cierre", con las dos anotaciones de
  gobernanza ya incorporadas arriba). No quedan bloqueos activos sobre el alcance declarado.

## 5. Referencia cruzada al work item hermano backend `LB-001B.1`

La instrucción de esta tarea describía el work item backend `LB-001B.1` (repo
`AsistenciasUCO`, rama `sergio`) como "cerrado el mismo día". **Verificación propia de esta
fase encuentra lo contrario y lo registra aquí en vez de asumir el dato recibido:**

- `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/` en el repo backend es un directorio
  **no trackeado** (`git status --porcelain` lo reporta como `??`, nunca commiteado).
- No existe `CLOSURE.md` en ese work item backend.
- El propio `VALIDATION.md` backend declara explícitamente, en su última sección: *"Cierre
  del work item (`CLOSURE.md`...): no ejecutado, corresponde a 06-cierre tras resolver el
  hallazgo bloqueante de arriba"*.
- El `AUDIT.md` backend (fase 05-auditor de esa línea de trabajo) concluye: *"no declaro este
  work item listo para 06-cierre tal cual está documentado hoy"*, señalando como hallazgo
  bloqueante documental (H1) que `VALIDATION.md` describe un estado ya superado (BUILD
  FAILURE) en vez del resultado GREEN final (933/933, BUILD SUCCESS, JaCoCo PASS) — el código
  backend está correcto y verificado, pero el registro documental de cierre no se completó.

**Conclusión de esta fase:** el cierre de `LB-001B.1B` (frontend) es autocontenible — su
propia evidencia (specs, build, coverage, auditoría independiente) no depende del estado
documental del work item backend — y por tanto **no se bloquea** por este hallazgo. Pero no
se declara aquí que `LB-001B.1` (backend) esté cerrado, porque la evidencia propia contradice
esa premisa. Se recomienda que el backend complete su propio 06-cierre (actualizar
`VALIDATION.md` con el resultado GREEN final antes de escribir su `CLOSURE.md`) para que la
cadena `LB-001B` quede consistente en ambos repos.

## 6. Evidencia de DoD (frontend, esta fase)

- Suite de tests: 177/177 SUCCESS, exit code 0 (`npx ng test`, reproducido por 05-auditor).
- `npm run coverage:realtime:check`: PASSED (Lines 95.62%/Branches 87.50%, único gate de
  cobertura real del repo).
- Build de producción: exit code 0.
- `npm run verify` (gate compuesto): exit code 0, reproducido por 05-auditor como comando
  único.
- Alcance de archivos respetado: 18 archivos de producción tocados (17 declarados +
  `course.mapper.ts`, ambos justificados), ningún `*.spec.ts` creado/editado/eliminado por
  04-implementador, `attendance.mapper.ts` intacto.
- Dictamen de auditoría independiente (misma sesión, gobernanza declarada sin ocultar la
  limitación de no ser una segunda identidad revisora): "LISTO PARA 06-cierre".

Detalle completo de comandos, salidas y grep dirigidos en `AUDIT.md` y `VALIDATION.md` (mismo
directorio).
