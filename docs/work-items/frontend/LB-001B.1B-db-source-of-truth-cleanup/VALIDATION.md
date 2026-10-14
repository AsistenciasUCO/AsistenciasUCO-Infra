---
status: draft
type: work-item
scope: frontend
owner: frontend-team
last-reviewed: 2026-09-22
---

# VALIDATION — LB-001B.1B: DB source of truth — limpieza contractual de Sesion/docenteName (frontend)

Fase 04-implementador. Implementa el contrato TARGET de `PLAN.md` sobre los 28 tests RED de
`RED_SNAPSHOT.md`. Ningún archivo `*.spec.ts` fue modificado (verificado, ver sección 4).

## 1. Resultado global

**PASS con una excepción documentada (TEST_CONTRACT_CONFLICT, sección 5) y una nota de
cobertura global no comparable 1:1 (sección 3).**

- Tests: **177/177 SUCCESS (0 FAILED)** — meta cumplida (`0 FAILED`, sin regresión en los
  149 que ya pasaban antes de esta fase).
- Build de producción: **exit code 0**.
- `coverage:realtime:check` (único gate de cobertura con script dedicado en el repo):
  **PASSED**.
- Cobertura global (`--code-coverage`, sin script de gate propio): **por debajo** del piso
  documentado en `VALIDATION.md` de LB-001B.1A (Lines 78.62%/Branches 62.64%), pero por una
  razón estructural ajena al diff de esta fase — ver sección 3.

## 2. Comandos ejecutados, salida relevante y exit codes

### 2.1 `npx ng test --watch=false --browsers=ChromeHeadless`

```
Chrome Headless 153.0.0.0 (Windows 10): Executed 177 of 177 SUCCESS (0.846 secs / 0.758 secs)
TOTAL: 177 SUCCESS
```

Exit code: `0`. Corrida repetida dos veces (con y sin `--code-coverage`) con el mismo
resultado estable: `177 SUCCESS`, `0 FAILED`. La corrida basal de `RED_SNAPSHOT.md` era
`28 FAILED, 149 SUCCESS` (177 specs) — los 28 RED pasaron a GREEN y los 149 que ya pasaban
siguen pasando.

Nota: durante una corrida se observó un WARN no bloqueante de
`auth.service.spec.ts` (`'No se pudo hidratar el perfil desde el backend:', Error: network
down`) — es un log de consola esperado por el propio test (simula un fallo de red), no un
fallo de test; el resultado de esa spec fue SUCCESS en las tres corridas.

### 2.2 `npm run build -- --configuration=production` (equivalente a `ng build --configuration=production`)

```
Application bundle generation complete. [17.028 seconds]
Output location: .../dist/gestio-asistencia-frontend
```

Exit code: `0`.

### 2.3 `npx ng build --configuration=development` (verificación intermedia, previa a la corrida de tests)

Exit code: `0`. Usado como chequeo rápido de compilación AOT/`strictTemplates` antes de
ejecutar la suite completa de Karma.

### 2.4 `npm run test:ci` (`ng test --watch=false --browsers=ChromeHeadless --code-coverage`)

```
TOTAL: 177 SUCCESS

=============================== Coverage summary ===============================
Statements   : 59.4% ( 1538/2589 )
Branches     : 41.47% ( 501/1208 )
Functions    : 45.9% ( 308/671 )
Lines        : 60.72% ( 1498/2467 )
================================================================================
```

Exit code: `0`.

### 2.5 `node scripts/check-realtime-coverage.mjs` (`npm run coverage:realtime:check`)

```
[coverage:realtime] TOTAL LINE: 95.62% (131/137)  threshold >= 90%
[coverage:realtime] TOTAL BRANCH: 87.50% (49/56)  threshold >= 80%

[coverage:realtime] PASSED
```

Exit code: `0`. Este es el **único** script de cobertura con gate automatizado en el
repositorio (`package.json`); está acotado a `src/app/core/realtime/**` y
`*realtime-sync.service.ts` — no toca ningún archivo de este work item, y no se degradó.

## 3. Cobertura global: antes/después (no comparable 1:1 — hallazgo documentado)

| Métrica | LB-001B.1A (`VALIDATION.md`, 151 tests) | LB-001B.1B (esta fase, 177 tests) |
|---|---|---|
| Lines | 78.62% (1067/1357) | 60.72% (1498/2467) |
| Branches | 62.64% (436/696) | 41.47% (501/1208) |

**El denominador (`LF`/`BRF`) casi se duplicó** (1357→2467 líneas instrumentadas,
696→1208 branches) entre ambas corridas, mientras que el numerador de líneas cubiertas
también subió (1067→1498). Esto **no es una regresión introducida por el diff de
04-implementador**: es consecuencia de que 03-tester-red agregó specs nuevos para 9
pantallas que antes no tenían ningún test (`teacher-grupo-hub`, `teacher-grupo-form`,
`teacher-grupos-list`, `teacher-grupo-sabana`, `teacher-grupo-sesiones`,
`teacher-sesion-detalle-modal`, `dean-faculty`, `coordinator-students`,
`coordinator-docentes`) más `teacher-grupos.component.spec.ts`. El instrumentador de
cobertura de Angular/Karma solo cuenta un archivo si queda incluido en el bundle de test
(vía import transitivo desde algún `*.spec.ts`); al agregar specs para esas pantallas, se
arrastraron al bundle —por primera vez— servicios grandes que esos specs no ejercitan a
fondo (se mockean con spies), por ejemplo:

```
  1.4%   attendance-claim.service.ts     (1/71 líneas)
  2.6%   app.routes.ts                   (1/39 líneas)
  6.9%   coordinator-management.service.ts (12/174 líneas)
 10.0%   catalog.service.ts              (2/20 líneas)
 14.0%   admin-management.service.ts     (18/129 líneas)
```

Ninguno de estos 5 archivos fue tocado por esta fase (verificado, ver sección 4) — su
presencia con cobertura casi nula en el reporte es exclusivamente un efecto de que ahora
son alcanzables desde el bundle de test, no un retroceso de calidad. Evidencia:
`coverage/gestio-asistencia-frontend/lcov.info` generado en esta sesión.

Los archivos efectivamente tocados por este work item tienen cobertura razonable y ninguno
quedó en 0%: `session.service.ts` 71.7%, `course.service.ts` 57.5%,
`teacher-grupos.component.ts` 54.6%, `dean-faculty.component.ts` 81.6%,
`teacher-grupo-sabana.component.ts` 85.0%, `teacher-grupo-sesiones.component.ts` 100%,
`teacher-sesion-detalle-modal.component.ts` 100%, `teacher-grupos-list.component.ts` 91.3%,
`coordinator-students.component.ts` 48.5%, `coordinator-docentes.component.ts` 32.8%,
`teacher-grupo-form.component.ts` 38.9% (todos con al menos el test RED correspondiente
pasando).

**No hay script de gate para la cobertura global** (`coverage:realtime:check` es el único
gate automatizado, acotado al vertical realtime, y pasa). La comparación contra el piso de
LB-001B.1A (78.62%/62.64%) queda documentada aquí como referencia histórica, no como un
gate incumplido: ese piso se midió sobre una base de 151 tests que no incluía los 26 specs
nuevos de 03-tester-red. Se recomienda a 06-cierre decidir si conviene fijar un nuevo piso
de cobertura global sobre la base de 177 tests, o añadir cobertura a los servicios
recién-visibles en un work item de mantenimiento separado (no forma parte del alcance de
limpieza contractual de este work item).

## 4. Confirmación de alcance respetado

```
git status --porcelain | grep -i "\.spec\.ts"
```

Todos los `*.spec.ts` listados como modificados (`M`) ya estaban modificados en el árbol de
trabajo **antes** de que esta fase empezara (confirmado contra el `git status` inicial de la
sesión: `attendance.mapper.spec.ts`, `course.service.spec.ts`, `session.service.spec.ts`,
`attendance-realtime-sync.service.spec.ts` eran parte del trabajo previo de LB-001B.1A/
03-tester-red). Los `*.spec.ts` nuevos (`??`) son exactamente los 10 creados por
03-tester-red según `RED_SNAPSHOT.md`. **Ningún `*.spec.ts` fue creado, editado ni
eliminado por esta fase.**

Archivos de producción modificados por 04-implementador (17):

- `src/app/core/models/attendance.model.ts`
- `src/app/core/models/course.model.ts`
- `src/app/core/services/session.service.ts`
- `src/app/core/services/course.service.ts`
- `src/app/core/mocks/course.mock.ts`
- `src/app/core/mappers/course.mapper.ts` (fuera de la lista "Allowed" original del
  PLAN.md — ver justificación en sección 5, punto 2; no es `attendance.mapper.ts` ni su
  spec, no tiene spec propio, no tiene consumidores en producción)
- `src/app/features/attendance/attendance-control/attendance-control.component.ts`
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

`src/app/core/mappers/attendance.mapper.ts` y su spec: **no tocados** (confirmado, ver
sección 5 punto 1 para la razón estructural por la que esto obligó una desviación del
TARGET literal). DB, backend, OpenAPI, JPA: sin cambios.

## 5. TEST_CONTRACT_CONFLICT encontrado y resuelto (desviación documentada del TARGET literal)

**Hallazgo (no anticipado por PLAN.md ni por RED_SNAPSHOT.md):** el TARGET original pedía
retirar `topic`, `room`, `tipo`, `status` de la interfaz `ClassSession`, dejándola con
exactamente `id, courseId, sessionNumber, title, date, startTime, endTime, records`. Al
intentarlo literalmente, la compilación de TypeScript (`strict: true`, excess-property
checks) falla en **dos grupos de archivos protegidos que 04-implementador no puede editar**:

1. **`attendance.mapper.ts`** (explícitamente prohibido de tocar, TECHNICAL_DEBT) —
   `sessionFromDTO()`/`sessionToDTO()` construyen y leen los 4 campos como parte de un
   round-trip hacia `ClassSessionDTO` propio del archivo. En particular,
   `sessionToDTO()` hace `tema: model.topic` y `estado_sesion: model.status` contra un DTO
   donde ambos campos son no-opcionales — esto exige que `ClassSession.topic`/`.status`
   sigan siendo no-opcionales también, no solo presentes.
2. **5 specs RED ya congelados** de `RED_SNAPSHOT.md` (fuera de alcance de edición de
   04-implementador): `teacher-grupos.component.spec.ts`, `dean-faculty.component.spec.ts`,
   `teacher-grupo-sabana.component.spec.ts`, `teacher-grupo-sesiones.component.spec.ts`,
   `teacher-sesion-detalle-modal.component.spec.ts` — los 7 fixtures
   `const x: ClassSession = { ...topic, status... }` (tipados explícitamente) fallan por
   excess-property-check si `topic`/`status` se retiran del tipo.

Confirmado con un repro mínimo (`tsc --strict --noEmit`) antes de decidir: el error es real
y bloquea la compilación completa de la suite (`ng test` no llega a ejecutar ningún spec si
cualquier archivo no compila), no solo de los archivos afectados.

**Resolución aplicada (04-implementador, sin editar ningún archivo protegido):**
`ClassSession` conserva `topic: string`, `room?: string`, `tipo?: 'REGULAR'|...`,
`status: 'PROGRAMADA'|...` en el **tipo**, documentados con `@deprecated` y una nota
extensa explicando por qué no se pudieron retirar. El **comportamiento real** sí implementa
el TARGET por completo: ningún flujo de datos de producción (`session.service.ts`,
`course.service.ts`, las 10 pantallas) lee, escribe o sintetiza estos 4 campos — quedan
siempre `undefined` en runtime, verificado por los 28 tests RED (que aseran exactamente
eso: `expect(session.topic).toBeUndefined()`, ausencia de literales renderizados, etc.). En
los puntos de construcción de `session.service.ts` donde antes se asignaban estos campos,
ahora se omiten y el objeto resultante se castea explícitamente (`as unknown as
ClassSession`/`ClassSession[]`) con un comentario que documenta la razón — es un
type-escape-hatch deliberado y acotado a esos 4 puntos, no una relajación general del
tipado del archivo.

`course.mapper.ts` (no protegido, sin spec propio, sin consumidores en producción — solo
se llama a sí mismo y es llamado únicamente por código muerto de `attendance.mapper.ts`)
tuvo un ajuste equivalente y menor: `CourseDTO.nombre_docente` pasó a opcional para reflejar
que `Course.docenteName` ya es opcional (mismo AS-IS #9).

**Impacto:** cero en runtime/comportamiento — los 28 RED assertions pasan exactamente por
la razón que piden (valores ausentes). El único costo es que `ClassSession` no queda
"textualmente" reducida a 8 campos como decía el TARGET original; queda reducida en
comportamiento pero no en superficie de tipo, por el acoplamiento estructural descrito. Se
recomienda a 06-cierre registrar esto como TECHNICAL_DEBT de seguimiento: limpiar
`attendance.mapper.ts`/`course.mapper.ts` (o confirmar que son código muerto y eliminarlos)
en un work item posterior permitiría entonces sí retirar los 4 campos del tipo sin tocar
specs congelados, si además se decide ajustar esos 5 fixtures de specs (lo cual, por
gobernanza de este work item, no le corresponde decidir a 04-implementador).

No se encontró ningún otro `TEST_CONTRACT_CONFLICT`. Los dos ya resueltos por
03-tester-red en `RED_SNAPSHOT.md` (`session.service.contract.spec.ts`,
`attendance-control.workflows.spec.ts`) se validaron en GREEN sin necesidad de ajuste
adicional.

## 6. Bloqueos

Ninguno. `READY_FOR_IMPLEMENTATION` del PLAN.md se ejecutó en su totalidad (lectura y
escritura de `Sesion`/`Course`/`Grupo.docenteName` en las rutas listadas), con la única
desviación documentada en la sección 5.
