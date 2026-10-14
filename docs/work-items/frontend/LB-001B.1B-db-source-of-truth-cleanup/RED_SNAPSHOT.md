---
status: draft
type: work-item
scope: frontend
owner: frontend-team
last-reviewed: 2026-09-22
---

# RED_SNAPSHOT — LB-001B.1B: DB source of truth — limpieza contractual de Sesion/docenteName (frontend)

Fase 03-tester-red. Deriva y escribe pruebas RED desde el contrato TARGET de `PLAN.md`
(mismo work item). **No se modificó código de producción** (`src/app/**/*.ts`, salvo
archivos `*.spec.ts`). `attendance.mapper.ts` y su spec no fueron tocados (fuera de
alcance, TECHNICAL_DEBT confirmado por el PLAN.md).

## Comandos ejecutados

```
npx ng test --watch=false --browsers=ChromeHeadless
```

Ejecutado 4 veces durante la sesión: 2 corridas iniciales de diagnóstico (una con un
desconexión transitoria de Chrome Headless no relacionada con el contrato — ver nota al
final —, otra con un fallo real de configuración en 2 specs nuevos), y 2 corridas finales
tras corregir la configuración de los specs, con resultado estable y reproducible:

```
TOTAL: 28 FAILED, 149 SUCCESS
```

(177 specs totales en el proyecto; ninguno de los 149 que pasan pertenece a este work
item o fue tocado por esta sesión más allá de los archivos listados abajo — no hubo
regresión en la suite existente).

## Archivos tocados en esta fase (todos `*.spec.ts` o documentación del work item)

**Ajustados (ya existían):**
- `src/app/core/services/session.service.spec.ts`
- `src/app/core/services/session.service.contract.spec.ts`
- `src/app/core/services/course.service.spec.ts`
- `src/app/features/attendance/attendance-control/attendance-control.component.spec.ts`
- `src/app/features/attendance/attendance-control/attendance-control.workflows.spec.ts`

**Nuevos (la pantalla no tenía spec):**
- `src/app/features/teacher/teacher-grupos/teacher-grupos.component.spec.ts`
- `src/app/features/teacher/teacher-grupos/components/teacher-grupo-hub.component.spec.ts`
- `src/app/features/teacher/teacher-grupos/components/teacher-grupo-form.component.spec.ts`
- `src/app/features/teacher/teacher-grupos/components/teacher-grupos-list.component.spec.ts`
- `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sabana.component.spec.ts`
- `src/app/features/teacher/teacher-grupos/components/teacher-grupo-sesiones.component.spec.ts`
- `src/app/features/teacher/teacher-grupos/components/modals/teacher-sesion-detalle-modal.component.spec.ts`
- `src/app/features/dean/dean-faculty/dean-faculty.component.spec.ts`
- `src/app/features/coordinator/coordinator-students/coordinator-students.component.spec.ts`
- `src/app/features/coordinator/coordinator-docentes/coordinator-docentes.component.spec.ts`

**Documentación:**
- `docs/work-items/LB-001B.1B-db-source-of-truth-cleanup/RED_SNAPSHOT.md` (este archivo)

No se creó spec para `ClassSession` (modelo) — el PLAN.md indica que no es necesario
crear uno solo para el retiro de campos; TypeScript lo verificará en compilación cuando
04-implementador retire `topic/room/tipo/status` del modelo.

## Los 28 tests en RED y por qué (mapeo a AS-IS/TARGET del PLAN.md)

### A. `session.service.spec.ts` (3 tests nuevos)
1. **"mapea la respuesta real de /sesiones/grupo sin topic/room/tipo/status sintéticos"** —
   RED porque `getSessionsByGroup()` (rama HTTP real) todavía asigna
   `topic: session.nombre` y `status: 'PROGRAMADA'` (AS-IS #4, `session.service.ts:154,158`).
2. **"los mocks de sesiones (rama useMocks) no inventan topic/room/tipo/status"** — RED
   porque `initialSessions`/rama mock de `getSessionsByGroup()` siguen inventando esos 4
   campos (AS-IS #2,#3).
3. **"cancelarSesion (mock) no muta status ni prefija topic con [CANCELADA]"** — RED
   porque la rama mock de `cancelarSesion()` fuerza `status: 'CONCLUIDA'` y reescribe
   `topic` con el prefijo `[CANCELADA]` (AS-IS #6, `session.service.ts:296`).

### B. `session.service.contract.spec.ts` (1 test **ajustado** — TEST_CONTRACT_CONFLICT resuelto)
4. **"crea una sesión serializando LocalDateTime sin conversión de zona ni parámetros
   fantasma"** — el test original afirmaba expresamente el comportamiento viejo (el body
   de `POST /sesiones` **debía** incluir `descripcion/aula/tipo`). Es exactamente el
   escenario de la sección G del PLAN.md ("test plan de referencia"): un test existente
   que afirma el comportamiento viejo es un `TEST_CONTRACT_CONFLICT` que 03-tester-red
   debe resolver, no forzar en verde. Se ajustó la aserción al TARGET (AS-IS #5): el body
   debe limitarse a `grupo/nombre/fechaHoraInicio/fechaHoraFin`. RED porque
   `createSession()` (rama HTTP real) todavía envía los 3 parámetros fantasma.

### C. `course.service.spec.ts` (3 tests nuevos)
5. **"getCurrentTeacherCourses() no hardcodea docenteName..."** — RED porque
   `course.service.ts:83` sigue asignando `docenteName: 'Docente UCO'` (AS-IS #9).
6. **"crearGrupo() (HTTP real) no envía docenteName..."** — RED porque el body de
   `POST /grupos` sigue incluyendo `docenteName` (AS-IS #11, riesgo #3 RESUELTO:
   `Grupo.docente` en DB es solo FK UUID, sin campo `docenteName` en el backend).
7. **"actualizarGrupo() (HTTP real) no envía docenteName..."** — RED porque
   `actualizarGrupo()` reenvía `cambios` tal cual, incluyendo `docenteName` si el llamador
   lo pasa (mismo TARGET que crearGrupo, riesgo #3 RESUELTO).

### D. Golden Path — `attendance-control.*.spec.ts` (4 tests: 1 ajustado + 3 nuevos)
8. **`attendance-control.workflows.spec.ts` — "crea una sesión... sin topic/room/tipo en
   el payload"** (ajustado, mismo patrón de TEST_CONTRACT_CONFLICT que el punto B: el test
   original esperaba `topic`/`room` en el payload de `createSession()`). RED porque
   `onCreateSessionSubmit()` sigue construyendo `topic/room/tipo` (AS-IS #29).
9. **`attendance-control.component.spec.ts` — "permite marcar EX aunque la sesión traiga
   un status sintético CONCLUIDA"** — RED porque `isSessionConcluded` sigue bloqueando
   `openExcuseModal()` cuando `status === 'CONCLUIDA'` (AS-IS #28, riesgo #2: el TARGET
   retira el gate sin sustituto).
10. **`attendance-control.workflows.spec.ts` — "openExcuseModal ya no bloquea..."** —
    mismo gate, mismo RED, cubierto también en el archivo de workflows por instrucción
    explícita de la tarea.
11. **`attendance-control.workflows.spec.ts` — "markAllPresent/markAllAbsent/
    saveAttendance ya no se bloquean por status sintético"** — RED porque `setStatus()`/
    `saveAttendance()` siguen retornando temprano cuando `isSessionConcluded()` es true.

### E. Pantallas ampliadas (9 archivos nuevos, 15 tests)

Estrategia de test aplicada de forma consistente: para campos de **solo lectura**
(`docenteName`, `status` mostrado como texto/badge), cada test coloca un valor
**marcador distintivo** en el campo y afirma que ese marcador **no aparece** en el DOM
renderizado. Esta estrategia es independiente del rediseño visual concreto que elija
04-implementador (columna eliminada, celda en blanco, etc.): solo exige que el campo deje
de leerse, no prescribe cómo se ve la pantalla después.

12. `teacher-grupo-hub.component.spec.ts` — docenteName en ficha (AS-IS #13). RED: el
    marcador aparece en el texto renderizado (`docenteName` se interpola directamente).
13. `teacher-grupo-form.component.spec.ts` — placeholder sintetizado (AS-IS #23). RED: el
    placeholder `'Ej. Dra. María Elena Rostagno'` sigue presente.
14. `teacher-grupos-list.component.spec.ts` — docenteName en tarjeta (AS-IS #24). RED:
    igual patrón de marcador.
15. `teacher-grupo-sabana.component.spec.ts` — `status` como `title` del indicador visual
    (AS-IS #25). RED: `title="CONCLUIDA"` presente.
16. `teacher-grupo-sesiones.component.spec.ts` — gate de negocio real (AS-IS #27). RED:
    con `status: 'CONCLUIDA'`, los botones "Ajustar Horario" y "Cancelar" **no** se
    renderizan (el test afirma que SÍ deben aparecer, TARGET = sin gate sintético).
17. `teacher-sesion-detalle-modal.component.spec.ts` — status en header (AS-IS #26). RED:
    el texto `'PROGRAMADA'` aparece en el DOM.
18. `dean-faculty.component.spec.ts` (4 tests): tabla de grupos (#14), ficha resumen
    (#15), badge de status de sesión (#16) y `filteredCourses()` por docenteName (#17).
    Los 4 en RED por las razones ya descritas (marcador visible / búsqueda coincide).
19. `coordinator-students.component.spec.ts` — ficha de curso en matrícula (AS-IS #18).
    RED: marcador visible en `curso.docenteName`.
20. `coordinator-docentes.component.spec.ts` — heurística de `verFichaDocente()`
    (AS-IS #19). RED: el curso con `docenteName: 'Equipo Docente Regular'` se empareja
    igual por el literal fallback `'docente'`, cuando el TARGET es no leer `docenteName`
    en absoluto (`cursosDocente()` debería quedar vacío al no haber coincidencia real por
    `docenteId`/nombre del docente).

### F. `teacher-grupos.component.spec.ts` (5 tests nuevos)
21. **"abrirCrearGrupo() ya no precarga el literal 'Dra. María Elena Rostagno'"** — RED
    (AS-IS #20, `teacher-grupos.component.ts:269`).
22. **"guardarGrupo() (CREAR) no envía docenteName a crearGrupo()"** — RED (AS-IS #20,
    l.319).
23. **"guardarGrupo() (EDITAR) no envía docenteName a actualizarGrupo()"** — RED (AS-IS
    #20, l.344).
24. **"abrirModalProyeccionParaGrupo() ya no selecciona la sesión activa por status
    sintético"** — RED (AS-IS #21, l.573). **Supuesto documentado**: el PLAN.md no fija
    el comportamiento de reemplazo exacto ("sin sustituto sintético" es el principio, no
    una regla concreta de selección). El test asume la interpretación más simple
    consistente con ese principio — tomar `sesiones[0]` tal como la entrega el backend,
    sin heurística por `status` — porque ya existe como fallback (`|| sesiones[0]`) en el
    código actual. Si 04-implementador o una revisión humana decide un criterio distinto
    (p. ej. mantener algún orden explícito del backend, o requerir selección manual), este
    test deberá ajustarse; se deja documentado aquí para que no se interprete como
    contrato cerrado.
25. **"abrirDetalleSesionModal() ya no sintetiza AN/SJC por paridad del ID del
    estudiante"** — RED (hallazgo nuevo #22, `teacher-grupos.component.ts:658-666`): hoy
    sintetiza `status: id.endsWith('2') ? 'SJC' : 'AN'` para sesiones con
    `status === 'CONCLUIDA'` sin `records`; el test afirma que `sesionDetalle().records`
    debe permanecer vacío (sin sustituto), consistente con el mismo principio que DR-002
    ya aplicado por LB-001B.1A en otros archivos.

## Fixes de configuración durante la fase (no cambian el contrato, solo corrigen el arnés de test)

Durante la primera ejecución se detectaron 2 problemas de configuración de test (no de
contrato) que se corrigieron sin tocar el contrato afirmado:

1. **`session.service.spec.ts`** — dos tests de la rama `useMocks` no usaban
   `fakeAsync`/`tick()` para esperar el `delay(200)`/`delay(250)` interno del servicio
   mock; el primer intento resultó en "Spec has no expectations" (falso verde silencioso,
   no una prueba real). Se corrigió envolviendo ambos tests en `fakeAsync(...)` con
   `tick(...)` explícito, quedando correctamente en RED por la razón esperada.
2. **`coordinator-docentes.component.spec.ts`** — el componente importa
   `UserPickerModalComponent`, que a su vez inyecta `TeacherService` (con `HttpClient`
   real). El primer intento fallaba con `NullInjectorError: No provider for HttpClient`
   (error de arnés, no del contrato). Se agregaron `provideHttpClient()` +
   `provideHttpClientTesting()` al `TestBed` del spec.
3. **`teacher-grupos.component.spec.ts`** — faltaba un valor por defecto para
   `sessionService.getSessionsByGroup` en el spy, causando `TypeError: Cannot read
   properties of undefined (reading 'subscribe')` en `cargarSesiones()` al llamar
   `verHubGrupo()` desde el test de `abrirDetalleSesionModal()`. Se agregó el default
   `of({ exitoso: true, datos: [], total: 0 })` en el `beforeEach`.

Tras estos 3 ajustes, dos corridas consecutivas de la suite completa dieron el mismo
resultado estable: `TOTAL: 28 FAILED, 149 SUCCESS`, sin `NullInjectorError`, `TypeError`
ni "no expectations" en ningún spec — los 28 fallos son exclusivamente aserciones sobre
el contrato TARGET, fallando por la razón correcta (el código de producción todavía tiene
los campos/lógica vieja).

**Nota sobre una corrida descartada:** la primera corrida de la sesión sufrió una
desconexión de Chrome Headless ("Disconnected, because no message in 30000 ms") a mitad
de la suite, con un `AuthService` test marcado FAILED de forma no reproducible en esa
única corrida (no relacionado con ningún archivo de este work item — `auth.service.ts`
no fue tocado por LB-001B.1A ni por esta fase). En las 3 corridas posteriores esa falla
no volvió a aparecer; se interpreta como flakiness del entorno (Chrome Headless
sandboxed), no como una regresión introducida aquí.

## TEST_CONTRACT_CONFLICT encontrados y resueltos

Dos tests existentes afirmaban expresamente el comportamiento viejo que este work item
retira (sección G del "Test plan de referencia" del PLAN.md). Ambos fueron **ajustados**
al TARGET en esta fase, no forzados en verde ni dejados para el implementador:

1. `session.service.contract.spec.ts` → *"crea una sesión serializando LocalDateTime sin
   conversión de zona"* afirmaba que el body de `POST /sesiones` debía incluir
   `descripcion/aula/tipo`. Ajustado a afirmar su ausencia (AS-IS #5 / TARGET).
2. `attendance-control.workflows.spec.ts` → *"crea una sesión y selecciona la recién
   creada"* afirmaba `topic`/`room` en el payload de `createSession()`. Ajustado a
   afirmar su ausencia (AS-IS #29 / TARGET).

No se encontró ningún otro `TEST_CONTRACT_CONFLICT` no resuelto. No hay
`BLOCKED_BY_MISSING_EVIDENCE` nuevo: los únicos pendientes (`docenteId` no evaluado,
wiring del contrato real de `docenteName` vía `GET /api/v1/docentes/{id}`) ya estaban
señalados como fuera de alcance por el PLAN.md y no bloquean 03-tester-red.

## Supuestos que 04-implementador debe validar (no son contrato cerrado)

- **`teacher-grupos.component.ts:573`** (`abrirModalProyeccionParaGrupo`): se asumió
  "tomar `sesiones[0]`" como sustituto de la selección por `status === 'EN_CURSO'`. Ver
  punto 24 arriba.
- **Pantallas de solo lectura** (hub, form, list, sábana, detalle, dean-faculty,
  coordinator-*): los tests solo exigen que el campo synthesized deje de leerse/mostrarse
  (vía el patrón de "marcador ausente"); no prescriben el rediseño visual exacto
  (eliminar columna vs. dejarla en blanco vs. reemplazar contenido). 04-implementador
  tiene libertad de diseño mientras el marcador no aparezca.

## Confirmación de alcance respetado

- No se modificó ningún archivo `src/app/**/*.ts` que no sea `*.spec.ts`.
- No se tocó `attendance.mapper.ts` ni `attendance.mapper.spec.ts`.
- No se tocó DB, SQL, stored procedures, backend ni OpenAPI.
- Todos los archivos de spec tocados/creados están dentro de la lista "Allowed" del
  PLAN.md (sección "Clase de cambio y alcance de rutas").
