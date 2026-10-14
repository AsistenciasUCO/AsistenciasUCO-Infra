---
status: draft
type: work-item
scope: frontend
owner: frontend-team
last-reviewed: 2026-09-22
---

# AUDIT — LB-001B.1B: DB source of truth — limpieza contractual de Sesion/docenteName (frontend)

Fase 05-auditor. **Mismo agente que ejecutó las fases previas de esta sesión (01→04); este
dictamen NO es una revisión externa/independiente de otra identidad, es un pase de
auditoría con la misma gobernanza y límites de escritura (`AUDIT.md` únicamente, ningún
`*.ts` tocado).** Todo lo reportado abajo fue re-ejecutado por mí en esta fase, no copiado
de `VALIDATION.md`.

## 1. Comandos re-ejecutados (evidencia propia)

| Comando | Resultado obtenido por mí | Coincide con VALIDATION.md |
|---|---|---|
| `npx ng test --watch=false --browsers=ChromeHeadless` | `Chrome Headless 153.0.0.0 (Windows 10): Executed 177 of 177 SUCCESS`, `TOTAL: 177 SUCCESS`. Mismo WARN benigno de `auth.service.spec.ts` (`network down`), test SUCCESS. | Sí |
| `npm run coverage:realtime:check` | `TOTAL LINE: 95.62% (131/137) threshold >= 90%`; `TOTAL BRANCH: 87.50% (49/56) threshold >= 80%`; `PASSED` | Sí, exacto |
| `npm run build -- --configuration=production` | `Application bundle generation complete.`, exit 0 | Sí |
| `npm run test:ci` (`--code-coverage`) | `TOTAL: 177 SUCCESS`; `Statements 59.4% (1538/2589)`, `Branches 41.47% (501/1208)`, `Functions 45.9% (308/671)`, `Lines 60.72% (1498/2467)` | Sí, exacto |
| `npm run verify` (test:ci + coverage:realtime:check + build prod, el gate real del repo) | Exit 0 completo, sin fallos | No lo corrió el implementador como comando único, pero sus 3 componentes ya estaban verificados por separado; confirmado aquí como gate compuesto |

No hubo ninguna desconexión de Chrome Headless en mis corridas (a diferencia de la corrida
descartada de `RED_SNAPSHOT.md`); no fue necesario reintentar.

## 2. Verificación de `git status`/`git diff` — alcance de archivos

El `git status --porcelain` completo del árbol de trabajo tiene 56 rutas (32 de
`LB-001B.1A` + las de `LB-001B.1B`, todas sin commitear, tal como advierte el PLAN.md línea
17). Confirmé archivo por archivo que el conjunto declarado por `VALIDATION.md` §4 (17
archivos de producción) es exactamente el subconjunto tocado por esta fase:

- `attendance.mapper.ts` y `attendance.mapper.spec.ts` **sí** aparecen como `M` en
  `git status`, pero el `git diff` de ambos muestra el cambio `estado_asistencia ?? null`
  (patrón DR-002) que corresponde a **LB-001B.1A** (confirmado cruzando
  `LB-001B.1A/VALIDATION.md:14` y `CLOSURE.md:20`, que documentan exactamente ese diff como
  cerrado antes de que existiera el PLAN.md de LB-001B.1B). El residuo
  `studentFromDTO()` línea 49 (`(dto.estado_asistencia as AttendanceStatus) || 'AN'`) sigue
  intacto — confirmado leyendo el archivo actual. **No hay contradicción**: la afirmación de
  `VALIDATION.md`/`RED_SNAPSHOT.md` ("`attendance.mapper.ts` y su spec no tocados [por esta
  fase]") es correcta; mi primera lectura del `git status` plano fue ambigua y quedó resuelta
  con el `git diff` de contenido.
- Otros `M` del `git status` que **no** están en la lista de VALIDATION.md (`app.routes.ts`,
  `auth.interceptor.ts`, `error.interceptor.ts`, `student.service.ts`,
  `attendance-realtime-sync.service.ts`, `attendance-control-table.component.ts`,
  `register.component.ts`, `overview-hero.component.ts`, `toast.component.ts`, y el archivo
  borrado `attendance-excuse-modal.component.ts`) pertenecen a trabajo previo de
  LB-001B.1A/otras fases, no a esta. No los audité en profundidad (fuera del alcance de esta
  tarea), solo confirmo que ninguno aparece en la lista "Archivos afectados" del PLAN.md de
  LB-001B.1B ni tiene relación textual con `topic/room/tipo/status/docenteName`.
- Ningún `*.spec.ts` fue creado/editado/eliminado por 04-implementador: los `??` (nuevos) del
  `git status` coinciden 1:1 con los 10 specs nuevos listados en `RED_SNAPSHOT.md`; los `M`
  de specs (`session.service.spec.ts`, `course.service.spec.ts`) ya estaban modificados por
  03-tester-red antes de esta fase (confirmado por su contenido: assertions sobre ausencia
  de `topic/room/tipo/status/docenteName`, exactamente lo descrito en `RED_SNAPSHOT.md`).

## 3. Dictamen sobre la desviación `@deprecated` (TEST_CONTRACT_CONFLICT, VALIDATION.md §5)

**Acepto la desviación como resuelta correctamente, con reserva de forma (no de fondo).**

Verifiqué directamente:
- `attendance.model.ts`: los 4 campos permanecen en la interfaz `ClassSession`, marcados
  `@deprecated` con nota extensa; `topic`/`status` siguen no-opcionales (tal como exige el
  acoplamiento con `attendance.mapper.ts::sessionToDTO()`).
- `session.service.ts`: ningún punto de construcción de `ClassSession` (mocks estáticos,
  `getSessionsByGroup()` rama real y mock, `createSession()`, `cancelarSesion()`) asigna
  `topic/room/tipo/status`; los objetos se construyen sin esos campos y se castean con
  `as unknown as ClassSession`/`ClassSession[]`, documentado inline. `createSession()` ya no
  acepta `topic/room/tipo` en su firma y el `POST /sesiones` solo envía
  `grupo/nombre/fechaHoraInicio/fechaHoraFin`.
- Búsqueda dirigida (`grep` de `\.topic\s*[:=]|\.room\s*[:=]|\.tipo\s*[:=]|\.status\s*[:=]`)
  en todo `src/app` fuera de `attendance.mapper.ts`: **cero** asignaciones de producción a
  estos 4 campos de `ClassSession`. Las únicas coincidencias de `.status` son
  `HttpErrorResponse.status` (dominio HTTP, no relacionado) y `StudentAttendance.status`/
  `rec.status` (dominio AN/SJC/EX, explícitamente fuera de alcance por el PLAN.md).
- El gate de negocio `isSessionConcluded` en el Golden Path fue **retirado del componente
  padre** (`attendance-control.component.ts` ya no lo computa ni lo pasa a los hijos); los
  componentes hijos (`attendance-control-header.component.ts`,
  `attendance-control-table.component.ts`) mantienen el `input<boolean>(false)` con default
  `false` (nunca reciben `true` desde el padre), consistente con "sin sustituto sintético".
- `teacher-grupos.component.ts:658-666`: la síntesis `endsWith('2') ? 'SJC' : 'AN'` fue
  eliminada por completo; `abrirDetalleSesionModal()` ya no construye `records` sintéticos.
  La selección de sesión activa (línea 571, antes 573) usa `sesiones[0]` sin heurística por
  `status`, exactamente el supuesto documentado en `RED_SNAPSHOT.md` punto 24. La selección
  de sesión en `attendance-control.component.ts:430` (`onCourseSelect`) usa el mismo patrón
  `sessions[0]`.

**Por qué acepto la desviación:** el TARGET literal del PLAN.md ("retira topic/room/tipo/
status de la interfaz") es una instrucción de forma; el objetivo real declarado en el mismo
PLAN.md ("ningún dato sintético se lee/escribe en runtime") es de fondo, y está cumplido de
forma verificable y exhaustiva (no encontré ninguna asignación de producción a estos campos
fuera del archivo explícitamente protegido). El conflicto (`attendance.mapper.ts` prohibido
de tocar + 5 specs RED congelados que tipan fixtures completos) es real — lo repliqué
mentalmente contra el código: `sessionToDTO()` en `attendance.mapper.ts` efectivamente hace
`tema: model.topic` y `estado_sesion: model.status` sin operador de coalescencia,
exigiendo no-opcionalidad.

**Reserva de forma — por qué esto SÍ debió ser un alto y pedir dictamen, no una decisión
unilateral:** `AGENTS.md`/`uco-testing` exigen que un `TEST_CONTRACT_CONFLICT` (que es
literalmente cómo lo tipifica el propio `VALIDATION.md` §5) sea resuelto por el rol
correspondiente con trazabilidad, no decidido unilateralmente por 04-implementador sobre la
marcha, aunque la resolución técnica sea correcta. El PLAN.md (riesgo #4, stop condition
"TEST_CONTRACT_CONFLICT: ninguno identificado todavía... a confirmar en 03-tester-red") y el
propio `RED_SNAPSHOT.md` (sección "TEST_CONTRACT_CONFLICT encontrados y resueltos") ya habían
establecido el patrón correcto: cuando 03-tester-red encontró 2 conflictos de este tipo, los
resolvió y los documentó como tales *antes* de declarar RED estable. El conflicto de
`@deprecated` fue descubierto **durante la implementación** (fase 04), un nivel más adelante
en el pipeline REQUIREMENT→CONTRACT→TEST_PLAN→RED→IMPLEMENTATION donde el implementador no
tiene autoridad para reinterpretar el TARGET, solo para ejecutarlo o detenerse. La
justificación técnica documentada en `VALIDATION.md` §5 es sólida y verificable, pero el
proceso correcto era detenerse con `BLOCKED_BY_MISSING_EVIDENCE`/`TEST_CONTRACT_CONFLICT`
antes de escribir código, no resolverlo y documentarlo post-hoc. Dado que la verificación
independiente confirma que el resultado es correcto en comportamiento, no rechazo el
work item por esto, pero lo señalo como una desviación de gobernanza a registrar (no un
defecto técnico).

## 4. `course.mapper.ts` — verificación del cambio fuera de la lista "Allowed"

`git diff` muestra un cambio de una sola línea: `nombre_docente: string` →
`nombre_docente?: string`, con comentario explicando la razón (reflejar que
`Course.docenteName` ya es opcional). Confirmé:
- El archivo no tiene spec propio (`find` no encontró `course.mapper.spec.ts`).
- No se identificaron consumidores de `CourseDTO`/`course.mapper.ts` en código de
  producción activo más allá de sí mismo (declarado en VALIDATION.md; no encontré evidencia
  en contra durante mi revisión).
- El cambio es mínimo, de tipo únicamente (no agrega lógica, no cambia comportamiento en
  runtime), y necesario por la misma cadena de acoplamiento que motivó la desviación de
  `attendance.model.ts` (mismo AS-IS #9).

**Dictamen: aceptable.** Es una consecuencia directa y proporcional del mismo TEST_CONTRACT_
CONFLICT ya evaluado en la sección 3, no una ampliación de alcance no relacionada. Formalmente
tampoco estaba en la lista "Forbidden" del PLAN.md, así que no hay una prohibición explícita
violada — pero por la misma razón de gobernanza señalada arriba, debió mencionarse como
BLOCKED/consulta antes de tocar un archivo no listado, en vez de solo justificarlo en
retrospectiva.

## 5. Verificación de la caída de cobertura global

Reproduje `npm run test:ci` y obtuve exactamente `Lines 60.72% (1498/2467)`,
`Branches 41.47% (501/1208)` — coincide byte a byte con lo reportado.

Verifiqué en `coverage/gestio-asistencia-frontend/lcov.info` (generado en mi propia corrida):

```
SF:src\app\core\services\admin-management.service.ts   LF:129  LH:18   (14.0%)
SF:src\app\core\services\attendance-claim.service.ts    LF:71   LH:1    (1.4%)
```

Coincide con los porcentajes citados en `VALIDATION.md` §3. Confirmé con `git status
--porcelain` dirigido a ambos archivos que **ninguno de los dos tiene cambios pendientes**
(no fueron tocados por ningún trabajo de esta sesión, ni LB-001B.1A ni LB-001B.1B). Confirmé
también que ninguno de los dos tiene `*.spec.ts` propio (`find src/app -iname
"*attendance-claim*"`/`"*admin-management*"` solo devuelve el `.ts`).

**Dictamen:** el argumento estructural es correcto — estos archivos entraron al bundle de
cobertura de Karma porque quedaron alcanzables transitivamente desde los 10 specs nuevos de
pantallas antes sin test, no porque el diff de 04-implementador les haya quitado cobertura
que antes tenían (tenían cero specs antes y después). El único gate de cobertura real y
automatizado del repositorio (`coverage:realtime:check`, acotado a `src/app/core/realtime/**`)
pasa sin cambios. **No hay script de gate para cobertura global en este repositorio** —
confirmado leyendo `package.json` (`verify` solo encadena `test:ci` + el gate realtime + build
producción, ningún umbral global). Por tanto, la comparación contra el piso de LB-001B.1A
(78.62%/62.64%) es una referencia histórica sin fuerza de gate, no una regresión de un
requisito exigible; documentar la recomendación de fijar un nuevo piso es apropiado para
06-cierre, no un bloqueante.

## 6. Verificación puntual de pantallas ampliadas y hallazgos del PLAN.md

Confirmado por lectura directa de cada archivo (no solo por el resultado de los tests):

| AS-IS | Archivo | Resultado |
|---|---|---|
| #9, #14-17 | `dean-faculty.component.ts` | Cero referencias a `docenteName`/`ClassSession.status` (búsqueda dirigida sin resultados) |
| #18 | `coordinator-students.component.ts` | Cero referencias a `docenteName` |
| #19 | `coordinator-docentes.component.ts` | Heurística `verFichaDocente()` retirada; solo queda un comentario explicativo |
| #13 | `teacher-grupo-hub.component.ts` | Cero referencias a `docenteName` |
| #20-23 | `teacher-grupos.component.ts` / `teacher-grupo-form.component.ts` | Literal `'Dra. María Elena Rostagno'` retirado de ambos defaults/placeholders; `guardarGrupo()` no incluye `docenteName` en los payloads de `crearGrupo`/`actualizarGrupo` |
| #21, #22 | `teacher-grupos.component.ts:571,647-654` | `sesiones[0]` sin heurística; síntesis AN/SJC eliminada |
| #25-27 | `teacher-grupo-sabana.component.ts`, `teacher-grupo-sesiones.component.ts`, `teacher-sesion-detalle-modal.component.ts` | `rec.status`/`sesion.status` de `StudentAttendance` (dominio correcto, no tocado); gate de negocio en botones "Ajustar Horario"/"Cancelar" retirado sin `[disabled]` sintético |
| #28-30 | `attendance-control.component.ts` | `isSessionConcluded` retirado del padre; selección de sesión usa `sessions[0]` |
| #9, #11 | `course.service.ts` | `getCurrentTeacherCourses()` sin `docenteName` hardcodeado; `crearGrupo()`/`actualizarGrupo()` (mock y HTTP real) sin `docenteName` en el payload (destructuring explícito para excluirlo) |

Ningún hallazgo contradice lo reportado por 04-implementador en estos puntos.

## 7. Criterios de aceptación aplicables (subset frontend citado en la tarea)

| Criterio | Estado |
|---|---|
| Frontend no sintetiza status/room/aula/tipo (ClassSession) | PASS — verificado por grep exhaustivo + lectura de servicio |
| Frontend no hardcodea docenteName | PASS |
| Mocks respetan contrato real | PASS (mocks de `session.service.ts`/`course.service.ts`/`course.mock.ts` alineados) |
| Ningún mapper usa ausencia→AN | PARCIAL — `fromGroupStudentsAndAttendances` corregido (LB-001B.1A); `studentFromDTO()` línea 49 conserva el residuo `|| 'AN'`, pero es TECHNICAL_DEBT explícitamente fuera de alcance de ambas fases (1A y 1B), documentado en `CLOSURE.md` de 1A y en el PLAN.md de 1B. No es una regresión de esta fase. |
| Ningún consumer usa null→SJC | PASS — `attendance-control-table.component.ts` verifica `student.status === null` explícitamente, sin reconvertir a `'SJC'` |
| No asistencias académicas sintéticas | PASS — síntesis AN/SJC por paridad de ID retirada |
| Frontend verify PASS | PASS — `npm run verify` (test:ci + coverage:realtime:check + build producción) ejecutado por mí, exit 0 |

## 8. Veredicto final

**LISTO PARA 06-cierre, con dos anotaciones de gobernanza que 06-cierre debe registrar
explícitamente en el cierre documental (no bloquean, no requieren volver a 04-implementador):**

1. La desviación `@deprecated` (sección 3) es técnicamente correcta y verificada en
   comportamiento, pero fue una decisión unilateral de 04-implementador ante un
   `TEST_CONTRACT_CONFLICT` descubierto en fase de implementación, cuando el protocolo
   exigía detenerse y pedir dictamen antes de codificar la solución. Registrar como
   excepción de proceso aceptada retroactivamente por auditoría, no como precedente para
   futuras fases.
2. El toque de `course.mapper.ts` (fuera de la lista "Allowed" del PLAN.md, aunque tampoco
   en "Forbidden") debió anunciarse antes de aplicarse, por la misma razón. Cambio mínimo y
   correcto, aceptado en retrospectiva.

Ningún hallazgo de esta auditoría contradice los resultados numéricos declarados por
`VALIDATION.md` (177/177, build exit 0, coverage:realtime:check PASSED). La caída de
cobertura global está correctamente explicada y no representa una regresión real dado que
el repositorio no tiene gate de cobertura global. Los 18 archivos de producción, los 4 campos
retirados en comportamiento (aunque no en superficie de tipo) y el retiro de las dos síntesis
de negocio conocidas (`status` sintético como gate, `AN`/`SJC` por paridad de ID) quedaron
verificados por evidencia directa de código, no solo por los tests declarados en verde.

## 9. Declaración de independencia

Este dictamen fue producido por el mismo agente (misma sesión de Claude Code) que ejecutó
01-planificador, 03-tester-red (verificado por lectura, no ejecutado por mí en esta fase) y
04-implementador en esta línea de trabajo. **No constituye una revisión externa
independiente.** Toda la evidencia de esta fase (comandos, greps, lecturas de archivo) fue
generada de nuevo en esta sesión de auditoría, no copiada de `VALIDATION.md`/`RED_SNAPSHOT.md`,
pero la ausencia de una segunda identidad revisora es una limitación estructural declarada,
no oculta.
