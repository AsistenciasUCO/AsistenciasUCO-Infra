---
status: active
type: test-plan
scope: frontend-manual
owner: fullstack-team
last-reviewed: 2026-11-17
---

# Guion de pruebas manuales del cierre (demostración)

Recorrido por rol en el navegador (`http://localhost:4200`) para la demostración. No reemplaza las listas del 2026-11-06
(`SCREEN-TESTS-<rol>.md` en [CULM-001-culminacion](../CULM-001-culminacion/)): esas son la **base de regresión** de cada pantalla
([administrador](../CULM-001-culminacion/SCREEN-TESTS-administrador.md), [decano](../CULM-001-culminacion/SCREEN-TESTS-decano.md),
[coordinador](../CULM-001-culminacion/SCREEN-TESTS-coordinador.md), [docente](../CULM-001-culminacion/SCREEN-TESTS-docente.md),
[estudiante](../CULM-001-culminacion/SCREEN-TESTS-estudiante.md), [transversal](../CULM-001-culminacion/SCREEN-TESTS-transversal.md)).
Este guion se centra en (i) lo que **cambió a la vista del usuario** en el cierre y (ii) los hallazgos F-* del recorrido del 2026-11-15
(`GestioAsistenciaBackend/docs/work-items/FASE-2B-certificacion-integral/VALIDATION.md`) que los paquetes dicen haber corregido o que siguen abiertos.

Contexto del cierre, paquetes y PR: [README](README.md). Deuda: [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md).

## Cómo usar este guion

- Cada caso tiene un ID `CIE-<ROL>-NN`, la ruta, los pasos, el resultado esperado y la casilla `[ ]` para marcarlo.
- La columna "Origen" indica el paquete del cierre (W1A, W1B, W2A, W2B, W3M, W3I, Ola 0) o el hallazgo F-*; "abierto" significa que el
  comportamiento NO está corregido y se espera ver el defecto descrito.
- Los rótulos entre comillas se comprobaron en el código del frontend (`core/messages/mensajes-ui.ts` y los componentes); donde no se pudo
  confirmar el texto exacto se describe el elemento sin comillas.
- Un caso marcado **DESTRUCTIVO** cambia datos de forma que no se deshace desde la interfaz; no se ejecuta en el camino feliz sin decisión expresa.

## Preparación

1. Levantar el laboratorio como indica [PRUEBAS_LOCALES](../../runbooks/PRUEBAS_LOCALES.md) (desde la raíz del workspace):
   `.\AsistenciasUCO-Infra\infra.ps1 stack up basico` y `stack status`. Para probar correos, soportes o tiempo real, usar la sección
   correspondiente de `stack up` (`mensajes`, `soportes`, `parametros`, `observabilidad`).
2. Datos: el laboratorio ya trae el conjunto variado (73 usuarios, período 2026-2 vigente del 1 de agosto al 15 de diciembre de 2026,
   período 2026-1 terminado sin cierre masivo). Recargarlo solo si hace falta: `infra.ps1 datos-prueba cargar -Yes` (respalda antes).
3. Comprobar que el frontend arrancó en modo real: sin `USE_MOCKS` y con proveedor de seguridad `baseline` (caso `CIE-TRA-05`).
4. Cuentas (la lista completa con rol, programa y grupos está en
   [USUARIOS.md](../../../../GestioAsistenciaDB/scripts/datos-prueba/USUARIOS.md)). La contraseña común de laboratorio está
   documentada en `AGENTS.md`, sección 7, y en `PRUEBAS_LOCALES.md`; **no se escribe aquí**. Se entra por correo o por usuario.

| Rol | Cuenta principal | Quién es en el conjunto de datos |
| :--- | :--- | :--- |
| Administrador | `uco-administrador` | Administrador institucional |
| Decano | `uco-decano` | Decano de la Facultad de Ingeniería |
| Coordinador | `uco-coordinador` | Coordinadora de Ingeniería de Sistemas |
| Docente | `uco-docente` | María Rostagno (Programación I, Desarrollo Web, Arquitectura de Software) |
| Estudiante | `uco-estudiante` | Carlos, estudiante con materias inscritas |

Cuentas con nombre que usa `scripts/tests/verificar_datos_prueba.py` y que sirven para casos concretos:

| Cuenta | Para qué se usa en este guion |
| :--- | :--- |
| `hernan.valencia` | Decano de Ciencias Sociales (estudiantes de Psicología: 5) |
| `paula.zuluaga` | Decana de Ciencias de la Salud (facultad sin programas) |
| `andres.ospina` | Decano sin facultad (debe verse el aviso de falta de facultad y no tener alcance) |
| `lina.agudelo` | Coordinadora de Psicología (6 estudiantes) |
| `mauricio.quintero` | Coordinador sin programa (0 estudiantes) |
| `diana.londono` | Coordinadora de Tecnología en Desarrollo de Software y además docente (doble rol) |
| `alejandro.cardenas` | Docente con una revisión de cancelación pendiente (Brayan, Ética y Humanismo, 26,7 %) |
| `julian.hoyos` | Docente sin grupos |
| `santiago.restrepo` | Estudiante con alertas de riesgo y de pérdida (2) |
| `mateo.giraldo` | Estudiante con una alerta de riesgo |
| `miguel.rojas` | Estudiante sin grupos (oferta académica) |
| `esteban.rendon` | Coordinador inactivo: no debe poder iniciar sesión |

Otros casos preparados (reclamos de María Rostagno, Hugo Serna y Sebastián Toro; solicitudes de sesión de Sistemas y Tec. Software;
cierre masivo del período 2026-1) están en la sección 3 de `PRUEBAS_LOCALES.md`.

---

## Administrador (`uco-administrador`)

| ID | Pantalla / ruta | Pasos | Resultado esperado | Origen | OK |
| :--- | :--- | :--- | :--- | :--- | :---: |
| CIE-ADM-01 | Inicio (`/app/dashboard`) | 1. Entrar como administrador. 2. Mirar la tarjeta "Facultades Activas" y compararla con la lista de facultades activas de Estructura. | La cifra cuenta todas las facultades activas de la institución, **incluidas las que no tienen decano**, y coincide con la lista. "Decanos en ejercicio" cuenta solo decanos con usuario, rol y facultad activos. | W3I | [ ] |
| CIE-ADM-02 | Inicio | 1. Recargar con la red lenta (herramientas del navegador) o mirar el instante de carga. | Mientras llegan los datos se ve estado de carga; nunca una cifra 0 inventada. Si el servidor falla, la tarjeta indica que no hay datos. | W3I | [ ] |
| CIE-ADM-03 | Estructura > Facultades > Nueva facultad (`/app/admin/estructura/facultades`) | 1. Abrir el formulario de nueva facultad. 2. Observar los selectores de institución y de decano. 3. Escribir solo el nombre y guardar. | Ni la institución ni el decano vienen preseleccionados. Guardar sin decano muestra el aviso "Seleccione el decano titular de la facultad." y no se crea nada. | F-ADM-01 (corregido); Ola 0 | [ ] |
| CIE-ADM-04 | Personas > Decanos (`/app/admin/personas/decanos`) > Nuevo decano | 1. Crear un decano **sin elegir facultad**. | Se crea el decano sin facultad (queda como decano sin facultad, que luego se puede asignar). | BD PR 140 (alta de decano) | [ ] |
| CIE-ADM-05 | Personas > Decanos > Nuevo decano | 1. Crear un decano indicando una facultad que **no existe** (escrita a mano o con un identificador que no existe; si la interfaz solo ofrece facultades existentes, probar con el nombre aproximado, por ejemplo una parte del nombre de una facultad real). | El alta se rechaza con un mensaje de error del servidor y **no se crea el decano**. Un nombre aproximado ya no se resuelve a otra facultad. La coincidencia por nombre es exacta (sin distinguir mayúsculas). | BD PR 140; también pruebas `FIX001_DEC_01` a `_07` | [ ] |
| CIE-ADM-06 | Personas > Decanos > Nombrar decano existente | 1. Abrir el selector de personas. 2. Escribir parte de un nombre. 3. Cambiar de página. | El selector busca en el servidor (no solo en la página cargada), muestra el total que entrega el servidor y pagina; no hay lista simulada de respaldo. Los nombres y apellidos aparecen separados correctamente (primer nombre, segundo nombre, apellidos). | W1B; F-ADM-05 (corregido por el origen de los nombres) | [ ] |
| CIE-ADM-07 | Personas > Decanos > Nombrar decano existente > Vincular | 1. Elegir un docente que ya tiene cuenta. 2. Revisar el formulario que se abre. | **Abierto:** el formulario sigue exigiendo "contraseña inicial de acceso" aunque la persona ya tenga cuenta (existe el mensaje `UI_ADMIN_DECANOS_008`). Anotar si ocurre. | F-ADM-04 (abierto) | [ ] |
| CIE-ADM-08 | Personas > Docentes (`/app/admin/personas/docentes`) | 1. Abrir la lista. 2. Buscar un docente que nunca tuvo vínculo con un programa. | La lista muestra por defecto solo docentes con vínculo activo (regla HU136): un docente sin vínculo no aparece. Es el comportamiento definido (TD-121). | W1B; TD-121 | [ ] |
| CIE-ADM-09 | Sistema > Cierre masivo (`/app/admin/sistema`) | 1. Ir a "Cierre Masivo de Asistencia". 2. Sin elegir período, intentar ejecutar. | Se pide un período válido (mensaje `UI_ADMIN_SYSTEM_001`) y no se cierra nada. | Ola 0 (BD PR 140) | [ ] |
| CIE-ADM-10 | Sistema > Cierre masivo (prueba de BD, no de interfaz) | 1. El período inexistente no se puede elegir en la lista. Su rechazo (`PER_001`) y el del código vacío (`GEN_002`) se verifican con las pruebas `FIX001_CIE_01` y `FIX001_CIE_02` de la suite de BD. 2. Si se ejecutan, confirmar después que el período vigente no cambió de estado. | Con código inexistente o vacío, el procedimiento responde error y **no cierra ni audita nada**; ya no cierra el período más reciente. | BD PR 140 (TD-097) | [ ] |
| CIE-ADM-11 | Sistema > Cierre masivo, camino feliz — **DESTRUCTIVO** | 1. Elegir un período y pulsar "Ejecutar cierre definitivo". | Cierra ese período y solo ese (cancela matrículas por inasistencia y consolida estados) y aparece en "Historial de Cierres Masivos Realizados". **No ejecutar sobre el período vigente de la base de la demostración salvo decisión expresa.** Si se decide hacerlo, usar el período 2026-1 (terminado, sin cierre) y reservar antes un respaldo (`infra.ps1 db-reset-qa -Mode Snapshot`). | Ola 0 | [ ] |

## Decano (`uco-decano`, y `hernan.valencia`, `paula.zuluaga`, `andres.ospina`)

| ID | Pantalla / ruta | Pasos | Resultado esperado | Origen | OK |
| :--- | :--- | :--- | :--- | :--- | :---: |
| CIE-DEC-01 | Inicio (`/app/dashboard`) | 1. Mirar "Grupos en Curso" y el período vigente justo después de entrar. | Primero un estado de carga; después la cifra y el nombre del período vigente. "Sin período vigente" solo aparece si el servidor devolvió que no hay período; si falla, se indica que no hay datos. Coincide con lo que muestra Períodos Académicos. | F-DEC-01 (corregido, W3I) | [ ] |
| CIE-DEC-02 | Inicio | 1. Comparar "Docentes de Facultad" con el directorio de docentes del decano (`/app/decano/directorio/docentes`). | La cifra sale del servidor y cuenta **cada docente una sola vez**, aunque esté vinculado a varios programas. "Coordinadores Asignados" cuenta coordinadores activos de la facultad (una vez por persona). | W3I | [ ] |
| CIE-DEC-03 | Inicio | 1. Leer el subtítulo de "Coordinadores Asignados". | **Abierto:** el subtítulo sigue diciendo "Programas de facultad", que no describe lo que se cuenta (coordinadores). Anotar si ocurre. | F-DEC-04 (abierto) | [ ] |
| CIE-DEC-04 | Mi facultad > Coordinadores (`/app/decano/mi-facultad/coordinadores`) | 1. Buscar por nombre, documento, correo y programa. 2. Filtrar por estado. 3. Filtrar "sin programa". 4. Cambiar de página. | Cada filtro lo resuelve el servidor; la lista no se trunca en 100 (con coordinadores sobrantes se ve el total real y todas las páginas). Cada coordinador sale una sola vez. Con `uco-decano` (Ingeniería) el conjunto de datos original tiene 4 coordinadores; ver la advertencia de datos del laboratorio. Mauricio Quintero aparece al filtrar "sin programa". | W1B | [ ] |
| CIE-DEC-05 | Mi facultad > Coordinadores > Nombrar coordinador existente | 1. Elegir un docente existente y vincular. 2. Revisar nombres. | Los nombres y apellidos se precargan completos y bien repartidos. **Abierto:** el formulario puede seguir pidiendo contraseña inicial (`UI_DEAN_COORDINADORES_004`). | F-DEC-03 (nombres corregidos por W1B; contraseña abierta) | [ ] |
| CIE-DEC-06 | Mi facultad > Programas (`/app/decano/mi-facultad/programas`) | 1. Revisar planes, créditos y asignaturas por plan. | Los créditos y las asignaturas por plan se piden paginados al servidor; mientras falte algún plan la suma total no se muestra (guion "-"), nunca un total parcial como si fuera completo. Los totales de la facultad (grupos, inscritos, cupos) vienen del indicador del servidor. | W3I; TD-119 | [ ] |
| CIE-DEC-07 | Directorio (`/app/decano/directorio/grupos`) | 1. Abrir grupos. 2. Buscar por texto y paginar. 3. Entrar al detalle de un grupo. | El directorio de grupos pagina y busca en el servidor y muestra los grupos del **período vigente**. El detalle no pide rutas del docente (no hay 403). | Ola 0 | [ ] |
| CIE-DEC-08 | Seguimiento > Indicadores (`/app/decano/seguimiento/indicadores`) | 1. Abrir indicadores con la red lenta. 2. Mirar "Ausentismo por programa" durante y después de la carga. | Durante la carga se ve "Cargando", si falla se ve el error con reintento, y solo con respuesta recibida y vacía se afirma que no hay programas. Nunca "No hay programas" cuando la misma pantalla indica programas. | F-DEC-02 (corregido, W3I) | [ ] |
| CIE-DEC-09 | Seguimiento > Consolidado (`/app/decano/seguimiento/consolidado`) | 1. Abrir los filtros de asignatura y de docente. 2. Cambiar el período. | Las opciones de asignatura y de docente son **completas** para el ámbito de la facultad y el período (no solo las de la página visible). El nivel de asistencia de cada fila (semáforo) lo entrega el servidor. | W2A; W3I | [ ] |
| CIE-DEC-10 | Seguimiento > Consolidado + Indicadores | 1. Anotar la cantidad en pérdida del consolidado. 2. Compararla con la del indicador del decano. | Las cifras pueden **no coincidir**: el consolidado cuenta matrículas (incluye canceladas por inasistencia y todos los períodos del filtro) y el indicador cuenta personas con matrícula activa en el período vigente. Es comportamiento conocido, no un error (caso observado: 958 frente a 675). | W3I; TD-116 (decisión pendiente) | [ ] |
| CIE-DEC-11 | `andres.ospina` (decano sin facultad) | 1. Entrar y navegar. | Se ve el aviso de que aún no tiene facultad asignada y no hay datos de facultad; las rutas con alcance de facultad responden acceso denegado. | Regresión HU178 | [ ] |
| CIE-DEC-12 | `paula.zuluaga` (facultad sin programas) | 1. Entrar y abrir Mi facultad > Programas. | Lista vacía correcta (estado vacío real) sin error. | Regresión | [ ] |

## Coordinador (`uco-coordinador`, y `lina.agudelo`, `mauricio.quintero`, `diana.londono`)

| ID | Pantalla / ruta | Pasos | Resultado esperado | Origen | OK |
| :--- | :--- | :--- | :--- | :--- | :---: |
| CIE-COO-01 | Inicio (`/app/dashboard`) | 1. Mirar "Estudiantes Registrados" y compararlo con "Total en el Programa" de la pantalla de estudiantes (`/app/coordinador/estudiantes`). | Ya no sale 0 mientras la otra pantalla muestra miles: ambas cifras coinciden (el padrón del programa). Si falla, se ve "Sin datos", no un 0. La pantalla carga en una sola petición. | F-COORD-01 (corregido, W3I) | [ ] |
| CIE-COO-02 | Inicio | 1. Revisar "Planta Docente Activa", "Grupos en Curso" y "Estudiantes en Riesgo". | "Planta Docente Activa" cuenta los vínculos activos del programa (una vez por docente, sin tope de página). "Grupos en Curso" muestra el período real que resolvió el servidor (no un rótulo fijo). Sin período vigente, los grupos y cupos son 0 y el aforo no se inventa. | W3I | [ ] |
| CIE-COO-03 | Programa > Grupos (`/app/coordinador/programa/grupos`) | 1. Buscar un grupo por nombre, código o asignatura. 2. Cambiar de página y de período. | La búsqueda, el período y la paginación los resuelve el servidor; el total mostrado es el del filtro. Cada grupo muestra su horario semanal (franjas); un grupo sin horario no muestra franjas. | W2A | [ ] |
| CIE-COO-04 | Programa > Grupos > Nuevo grupo | 1. Crear un grupo con un docente y un horario que se cruce con otro grupo del mismo docente. | El formulario muestra de forma visible el mensaje del backend sobre el cruce de horario y **no se crea** el grupo. | F-COORD-02 (corregido; el componente muestra el error del servidor) | [ ] |
| CIE-COO-05 | Programa > Grupos > Nuevo grupo | 1. Repetir con un código de grupo duplicado. | Se muestra un mensaje visible de conflicto. El código de error del servidor sigue siendo genérico (`CONFLICT`) y no específico. | F-COORD-05 (menor, abierto en el contrato de error) | [ ] |
| CIE-COO-06 | Programa > Materias (`/app/coordinador/programa/materias`) | 1. Filtrar por carácter (obligatoria u optativa). 2. Combinar con búsqueda y paginar. | El filtro por carácter lo resuelve el servidor y las opciones del filtro salen del catálogo de caracteres. Un carácter sin resultados da lista vacía sin error. La ocupación de cupos viene del indicador del servidor, no de la página visible. | W2A; W3I | [ ] |
| CIE-COO-07 | Programa > Períodos (`/app/coordinador/programa/periodos`) | 1. Revisar el estado de cada período. 2. Filtrar por estado. | Cada período muestra un estado de los tres posibles (planeación, activo, cerrado) coherente con sus fechas (hoy dentro de las fechas = activo; antes = planeación; después = cerrado). El estado lo calcula la base, no el reloj del navegador. | W2A | [ ] |
| CIE-COO-08 | Asistencia (`/app/coordinador/asistencia`) | 1. Abrir el consolidado y sus filtros de asignatura y docente. 2. Mirar "Alertas tempranas por estudiante". | Las opciones de asignatura y docente son completas para el programa y el período. La sección de alertas existe y muestra el nivel entregado por el servidor. Anotar si aparece vacía sin mensaje de estado vacío. | W2A; F-COORD-03 (no ubicado en los paquetes: verificar) | [ ] |
| CIE-COO-09 | Asistencia y Revisiones de cancelación (`/app/coordinador/revisiones-cancelacion`) | 1. Abrir la vista completa sin "solo pendientes". 2. Revisar la columna de acción frente al estado. | Se ve el nivel de permanencia de cada matrícula (campo del servidor). **Abierto/por verificar:** en el recorrido anterior la acción decía "Resuelta" en filas pendientes de decisión del docente. Anotar si ocurre. | W3I; F-COORD-04 (no ubicado en los paquetes: verificar) | [ ] |
| CIE-COO-10 | Alcance de docentes (`/app/coordinador/programa/docentes`) | 1. Entrar con `uco-coordinador` (Sistemas). 2. Revisar los docentes. 3. Repetir con `lina.agudelo` (Psicología). | Cada coordinador ve **solo los docentes vinculados a sus programas**; los de otros programas no aparecen y la ruta general de docentes ya no existe. | W1B (TD-098) | [ ] |
| CIE-COO-11 | `mauricio.quintero` (sin programa) | 1. Entrar y abrir estudiantes y grupos. | Aviso de que aún no tiene programa asignado; 0 estudiantes; sin errores. | Regresión HU178 | [ ] |
| CIE-COO-12 | Cualquier pantalla de asistencia | 1. Buscar un control para editar una asistencia. | No existe: el coordinador solo consulta y audita; la asistencia es exclusiva del docente titular. | Regla de negocio | [ ] |
| CIE-COO-13 | `diana.londono` (doble rol) | 1. Entrar y ver las áreas de coordinación y las de docente. | Ve sus grupos de coordinación y, aparte, sus asignaturas como docente (Pruebas de Software), sin mezclar ámbitos. | Regresión | [ ] |

## Docente (`uco-docente`, `alejandro.cardenas`, `julian.hoyos`, y las cuentas con reclamos)

| ID | Pantalla / ruta | Pasos | Resultado esperado | Origen | OK |
| :--- | :--- | :--- | :--- | :--- | :---: |
| CIE-DOC-01 | Inicio (`/app/dashboard`) | 1. Revisar "Asignaturas a Cargo" y "Alumnos Matriculados". | "Alumnos Matriculados" sale del servidor (grupos habilitados del período vigente) y coincide con la suma de matriculados activos de la lista de grupos. | W3I | [ ] |
| CIE-DOC-02 | Inicio | 1. Leer el rótulo del período en las tarjetas. | **Abierto:** el rótulo del semestre está escrito a mano en la pantalla ("Semestre 2026-II") y no sale del servidor. | TD-113 (abierto) | [ ] |
| CIE-DOC-03 | Reclamos (`/app/docente/reclamos`) | 1. Buscar por nombre del estudiante, asignatura o parte de la justificación. 2. Cambiar de página con la búsqueda activa. | La búsqueda la resuelve el servidor sobre **todos** los reclamos del docente (no solo la página cargada); el total mostrado es el del filtro. | W1A | [ ] |
| CIE-DOC-04 | Reclamos | 1. Filtrar por grupo. 2. Probar con un grupo en el que el docente no es titular (por ejemplo cambiando el identificador por otro docente en una prueba técnica). | El filtro por grupo muestra solo reclamos de ese grupo. Un grupo ajeno devuelve vacío, no un error. | W1A | [ ] |
| CIE-DOC-05 | Reclamos | 1. Mirar el folio de cada reclamo y abrir el expediente. | El folio tiene la forma `REC-XXXXXXXX` (sin `#` delante) y es el mismo en la lista, en el expediente y en la vista del estudiante. Lo genera el servidor. | W1A | [ ] |
| CIE-DOC-06 | Mis grupos > un grupo > Padrón y retiros (`/app/docente/grupos`) | 1. Abrir el padrón. 2. Buscar por nombre o documento. 3. Cambiar de página. | El padrón se pide paginado al servidor, con la búsqueda aplicada a todo el grupo y el total del filtro. Incluye todos los estados de matrícula (activos y retirados). Si nada coincide, aparece el mensaje de lista vacía (texto literal fuera del catálogo, TD-113). | W1A; TD-113 | [ ] |
| CIE-DOC-07 | Mis grupos > un grupo > Planilla ("Matriz General de Asistencia Semestral") | 1. Abrir la planilla. 2. Buscar a un estudiante. 3. Paginar. | Planilla paginada y buscada en el servidor: filas por estudiante y una columna por sesión. Una sesión con asistencia parcial muestra los minutos asistidos sobre los de la sesión (leyenda "Parcial (minutos asistidos)") y no una falta. | W3M | [ ] |
| CIE-DOC-08 | Planilla | 1. Buscar un estudiante retirado del grupo. | Aparece con su estado de matrícula y **sus marcas reales** de las sesiones en que asistió (ya no una fila de guiones). | W3M | [ ] |
| CIE-DOC-09 | Mis grupos > un grupo > Sesiones | 1. Revisar el resumen de sesiones y el promedio de asistencia. 2. Probar con un grupo sin clases dictadas. | Los conteos (programadas, ejecutadas, canceladas, en curso), el promedio y los estudiantes en riesgo vienen del servidor y cuentan solo matrículas activas. Con un grupo sin horas dictadas el promedio dice que no hay registros de asistencia, no "0 %". Cada sesión muestra su estado (programada, en curso, ejecutada, cancelada) calculado por la base; una sesión sin horario confirmado queda programada. | W3M; F-DOC-02 (probable corrección, verificar) | [ ] |
| CIE-DOC-10 | Mis grupos > Decisiones pendientes (`alejandro.cardenas`) | 1. Abrir la revisión de Brayan (Ética y Humanismo). 2. Pulsar Decidir. | El modal muestra **solo las acciones que entrega el backend** (por ejemplo mantener o proponer cancelación), sin ninguna preseleccionada. Se puede confirmar solo con una acción elegida. | F-DOC-01 (corregido); BD PR 140 | [ ] |
| CIE-DOC-11 | Decisiones pendientes | 1. Abrir una revisión que ya no espera la decisión del docente (por ejemplo una en propuesta). | El modal informa que no hay acciones disponibles porque el caso no espera la decisión del docente; no hay botones de acción. | F-DOC-01; BD PR 140 | [ ] |
| CIE-DOC-12 | Inicio y grupos | 1. Buscar desde el tablero un enlace directo a las decisiones pendientes. | **Abierto:** no hay enlace directo; las decisiones viven en el hub de cada grupo. Es una decisión pendiente. | F-DOC-03 (abierto); TD-117 | [ ] |
| CIE-DOC-13 | Acceso a grupo ajeno (`uco-docente`) | 1. Intentar abrir un grupo donde no es titular (por ejemplo Bases de Datos G1, que es de otro docente) por su dirección. | Acceso denegado (el servidor responde prohibido) y se ve el aviso; no se listan estudiantes del grupo ajeno. | W1A; regresión de ámbito | [ ] |
| CIE-DOC-14 | Control de asistencia (`/app/asistencia`) | 1. Abrir una sesión del día, tomar asistencia de varios estudiantes y guardar. | La toma en vivo sigue funcionando: se registra la asistencia y la planilla la refleja. Las reglas de marcado masivo y la ventana de toma siguen evaluándose en el cliente y el backend las revalida (TD-119). | Regresión; TD-119 | [ ] |
| CIE-DOC-15 | `julian.hoyos` (sin grupos) | 1. Entrar y abrir Mis grupos. | Estado vacío correcto; sin errores. | Regresión | [ ] |

## Estudiante (`uco-estudiante`, `santiago.restrepo`, `mateo.giraldo`, `miguel.rojas`)

| ID | Pantalla / ruta | Pasos | Resultado esperado | Origen | OK |
| :--- | :--- | :--- | :--- | :--- | :---: |
| CIE-EST-01 | Inicio (`/app/dashboard`) | 1. Mirar "Materias Matriculadas" y compararlo con Mis Materias (`/app/estudiante/mis-materias/materias`). | Las dos pantallas coinciden. Mientras llega el dato se ve "Cargando tus materias…" o "No disponible"; si falla, un mensaje de error; el cero solo aparece con un cero real confirmado por el servidor. | F-EST-01 (corregido, W2B) | [ ] |
| CIE-EST-02 | Inicio | 1. Revisar "Materias en riesgo" y "Horas de falta". 2. Probar con `santiago.restrepo`. | Las cifras vienen del resumen de la base (no se recalculan en el cliente); con umbrales sin configurar o sin datos de asistencia se ve "No disponible", nunca un 0 falso. Los créditos totales son la suma de las materias del listado. | W2B | [ ] |
| CIE-EST-03 | Inicio | 1. Leer el rótulo del período. | **Abierto:** el rótulo "Semestre 2026-II" está escrito a mano. | TD-113 (abierto) | [ ] |
| CIE-EST-04 | Mis Materias > detalle de una materia | 1. Abrir una materia con varias sesiones. 2. Cambiar de página. 3. Elegir otro grupo de la misma asignatura si existe. | Las sesiones salen ordenadas por fecha y hora de inicio y número, sin repetir ni saltar filas entre páginas; el total es el del filtro. El filtro por grupo muestra solo ese grupo. | W2B | [ ] |
| CIE-EST-05 | Mis Materias > Matricularse con código | 1. Escribir un PIN de 6 dígitos que no existe (por ejemplo `999999`) y confirmar. | Aparece un mensaje visible de error del servidor (código no válido o ya no disponible). | F-EST-02 (corregido; el modal muestra el error) | [ ] |
| CIE-EST-06 | Mis Materias > Matricularse con código | 1. Escribir un PIN con letras y enviar. | **Por verificar:** en el recorrido anterior no se mostraba ningún mensaje. Anotar el comportamiento actual. | F-EST-03 (menor, no ubicado en los paquetes) | [ ] |
| CIE-EST-07 | Rutas de otro rol | 1. Escribir en la barra la dirección de Mis grupos del docente (`/app/docente/grupos`). | Página de acceso denegado con aviso; no se carga ninguna pantalla de docente. | Regresión de roles | [ ] |
| CIE-EST-08 | `miguel.rojas` (sin grupos) | 1. Abrir Oferta académica. | Se ve la oferta de grupos disponibles; las demás pantallas muestran estado vacío correcto. | Regresión | [ ] |
| CIE-EST-09 | Alertas (`/app/estudiante/alertas`, `santiago.restrepo` y `mateo.giraldo`) | 1. Abrir las alertas. | Santiago ve 2 (riesgo y pérdida) y Mateo ve 1 (riesgo). Cada alerta trae el nivel de permanencia que entrega el servidor (el cliente solo lo pinta, sin umbrales propios). | W3I; regresión | [ ] |

## Transversal

| ID | Pantalla / ruta | Pasos | Resultado esperado | Origen | OK |
| :--- | :--- | :--- | :--- | :--- | :---: |
| CIE-TRA-01 | Cualquier modal con acción que falle | 1. Abrir un modal de alta (por ejemplo nuevo decano o nuevo grupo). 2. Provocar un rechazo del servidor. 3. Esperar. | El aviso flotante se ve **por encima del modal** (no queda tapado) y permanece su tiempo completo antes de desaparecer. | Ola 0 (componente de avisos) | [ ] |
| CIE-TRA-02 | Ruta de otro rol | 1. Con cualquier rol, escribir la dirección de una pantalla de otro rol. | Redirección a la página de acceso denegado y aviso "Acceso denegado: No cuenta con los permisos necesarios para acceder a esta sección." | Regresión (roleGuard) | [ ] |
| CIE-TRA-03 | Acción sin permiso (403 del servidor) | 1. Provocar una petición que el servidor niegue (por ejemplo la del caso `CIE-DOC-13`). | Aviso de acceso denegado por la acción, con código de referencia cuando el servidor lo entrega. | Regresión (interceptor) | [ ] |
| CIE-TRA-04 | Error del servidor (5xx) | 1. Con el backend detenido (por ejemplo, el contenedor del backend), abrir una lista. | Se ve el estado de error con la opción de reintentar, no una lista vacía ni un 0. Al volver a levantar, el reintento carga los datos. | Ola 0 (errores visibles) | [ ] |
| CIE-TRA-05 | Arranque del frontend | 1. Comprobar el entorno del contenedor del frontend (variables). 2. Opcional: levantarlo con `USE_MOCKS=true` y sin `ALLOW_MOCKS=true`. | Con `USE_MOCKS=false` y proveedor `baseline` la interfaz usa el backend real y el login redirige al proveedor de seguridad. Con `USE_MOCKS=true` sin `ALLOW_MOCKS=true` el contenedor **no arranca** y deja un mensaje en el registro. El simulador sigue empaquetado en el build (TD-106). | Ola 0 (TD-102) | [ ] |
| CIE-TRA-06 | Cierre de sesión | 1. Cerrar sesión desde el menú de usuario. 2. Pulsar atrás en el navegador. | La sesión termina (el token vive solo en memoria), no se puede volver a una pantalla protegida sin autenticarse. | Decisión del responsable (Bearer en memoria) | [ ] |
| CIE-TRA-07 | Tiempo real (SSE) | 1. Abrir dos sesiones del navegador: docente (control de asistencia de una sesión abierta) y estudiante o coordinador viendo la misma sesión. 2. Registrar una asistencia como docente. | La otra pantalla se actualiza sin recargar y sin sondeos periódicos; el canal es el stream `/realtime/stream`. | Regresión realtime | [ ] |
| CIE-TRA-08 | Caché del frontend | 1. Recargar con Ctrl+F5 y comprobar en las herramientas de red la cabecera de `index.html` y de un archivo `.js` con hash. | `index.html` con `no-cache` y los archivos con hash con caché larga inmutable; `assets/env.js` sin caché. | Ola 0 (TD-109) | [ ] |

---

## Hallazgos F-* del 2026-11-15: situación según este cierre

| Situación | Hallazgos |
| :--- | :--- |
| Corregidos (según contratos del cierre) | F-DEC-01, F-DEC-02, F-COORD-01 (W3I); F-EST-01 (W2B); F-DOC-01 (W2B y BD PR 140); F-ADM-05 y la pérdida de datos del nombre de F-DEC-03 (W1B, nombres desde el servidor) |
| Corregidos según lectura del código (no los nombra un contrato del cierre) | F-ADM-01 (formulario de facultad sin valores por defecto), F-COORD-02 (el formulario de grupo muestra el error del servidor), F-EST-02 (el modal de matrícula muestra el error) |
| Siguen abiertos | F-ADM-04 y la contraseña de F-DEC-03 (el formulario de vincular persona existente exige contraseña); F-DEC-04 (subtítulo "Programas de facultad"); F-DOC-03 (sin enlace directo, TD-117); F-COORD-05 (código de error genérico) |
| No ubicados en los paquetes del cierre (verificar con los casos) | F-ADM-02, F-ADM-03, F-ADM-06, F-COORD-03, F-COORD-04, F-DOC-02 (posible efecto de W3M), F-DOC-04, F-EST-03 |

## Comportamientos conocidos y fuera de alcance

| Tema | Qué se ve | Deuda |
| :--- | :--- | :--- |
| Cifras de pérdida | Consolidado (matrículas) y indicador del decano (personas) no coinciden | TD-116 (decisión pendiente) |
| Decisiones del docente | No hay enlace directo desde el tablero | TD-117 (decisión pendiente) |
| Marca del resolutor | `esResolutorActual` del docente siempre 0 (el cliente no la usa) | TD-118 |
| Textos y rótulos | Mensajes literales en la planilla y "Semestre 2026-II" en tableros | TD-113 |
| Código sin uso | Servicios del frontend sin llamadores y uno duplicado | TD-114 |
| Restos en el cliente | Totales de créditos, filtros de catálogos pequeños, `'CC'` por defecto, ventana de toma | TD-119 |
| Avisos de error | Solo 403 y 5xx son globales; 400/409/422 dependen de la pantalla | TD-120 |
| Docentes del administrador | Solo con vínculo activo | TD-121 |
| Simulador | Sigue empaquetado y diverge del backend real | TD-106, TD-112 |
| Pruebas de BD inestables | Una falla aislada puede repetirse y pasar | TD-111 |
| Contenedores y producción | Despliegue real fuera de alcance (demostración con imágenes Docker) | [REQUISITOS_PRODUCCION](../../runbooks/REQUISITOS_PRODUCCION.md) |

## Datos del laboratorio

- El laboratorio tiene **14 cuentas de prueba posteriores** al conjunto de datos: `culm1-e2e-*`, `PAULA PASAPORTE`,
  `VALENTINA PRERREGISTRO PRUEBA`, `LAURA ACTIVACION` y `TEST HOY`. Alteran los conteos: coordinadores de Ingeniería 9 en lugar de 4 y
  estudiantes de Sistemas 10 en lugar de 8 (TD-122). **No son un defecto de permisos.**
- Por eso `scripts/tests/verificar_datos_prueba.py` da 26 de 28; las otras 20 rutas nuevas de los paquetes estaban correctas por rol el 2026-11-17.
- Para comparar cifras con los casos de este guion (por ejemplo `CIE-DEC-04`), eliminar esas cuentas o recargar el conjunto de datos
  (`infra.ps1 datos-prueba cargar -Yes`) antes de la demostración.
- El período 2026-2 termina el 15 de diciembre de 2026; después de esa fecha el generador de sesiones rechaza el período y hay que mover
  las fechas (ver `PRUEBAS_LOCALES.md`).
- El historial de asistencia se registra hasta el momento de la carga: las cifras exactas cambian según el día.
