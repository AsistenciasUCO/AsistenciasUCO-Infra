# SCREEN-TESTS — Coordinador de programa

Usuario: `uco-coordinador` (Ingenieria de Sistemas). Clave: documento de credenciales. Todo dato creado lleva prefijo `CULM1-`. Consola y Red abiertas en todos los pasos: esperado 0 errores de consola, ninguna llamada repetida periodica (sin polling), ningun token en la URL. Marcas: [M] repetir en movil 375x812; [D:rol] requiere datos previos de ese rol.

1. Login (`http://localhost:4200` -> Keycloak). Esperado: aterriza en `/app/coordinador/docentes`. Cerrar sesion al final.
2. Menu lateral: solo opciones de coordinador (docentes, planes, periodos, indicadores, estudiantes, grupos, materias, asistencias, consolidado); sin sedes ni solicitudes de matricula. [M] menu colapsable.

## Docentes (HU062, HU063, HU089-HU095)
3. `/app/coordinador/docentes`: lista paginada (1 docente: Maria Elena Rostagno Valencia), contadores por estado/tipo (HU095). Red: `GET /coordinador/docentes`, `/docentes/resumen`. [M]
4. Buscar por cedula (`1017112233`) y por nombre; buscar "Dos" (docente ajeno) -> 0 resultados, estado vacio legible.
5. Ficha del docente (HU094): historial de grupos y carga; cerrar con Esc y con el boton; foco vuelve al disparador (a11y). [M]
6. Alta de docente (HU091): modal; enviar vacio -> mensajes del backend; crear persona nueva `CULM1-Docente` con tipo de vinculacion (HU090, lista controlada). Esperado toast del backend. Verificar luego en lista.
7. Editar docente (HU092) incluyendo correccion de documento con motivo; activar/inactivar con confirmacion (HU093). Esperado: estado actualizado sin recargar manual.

## Planes, malla y asignaturas (HU071, HU073-HU075, HU079-HU087)
8. `/app/coordinador/planes-estudio`: lista de planes; crear plan `CULM1-PLAN` (HU079), editar (HU080), activar/inactivar (HU081). Enviar vacio -> errores del backend. [M]
9. Malla de un plan (HU075/HU084): ver semestres 1-10; añadir semestre (HU082) y quitar semestre vacio (HU083); intentar quitar uno con asignaturas -> mensaje del backend.
10. Crear asignatura `CULM1-ASIG` (HU085) con creditos/horas/area/componente; editarla (HU087); filtros por area/componente (HU086).
11. **F-COO-005**: en la malla pulsar quitar/desvincular una asignatura: hoy sale `confirm()` nativo y luego error 501. Registrar texto del toast. No confirmar sobre asignaturas sembradas.
12. `/app/coordinador/materias`: activar/inactivar asignatura con confirmacion (HU074) sobre `CULM1-ASIG`; revertir. Mirar a11y de los filtros (F-COO-010). [M]
13. `/app/coordinador/periodos`: solo lectura (texto "Los periodos los administra la institucion"); sin botones de crear/editar/eliminar.

## Grupos y asistencia solo lectura (HU060, HU064, HU076B)
14. `/app/coordinador/grupos`: listado de los 2 grupos del programa (sin paginacion, F-COO-009). Crear grupo `CULM1-G` (HU076B) con docente del programa, asignatura, periodo y cupo; probar cupo 0/negativo y horario cruzado -> mensajes del backend. Red: `GET /grupos` (F-COO-003). [M]
15. `/app/coordinador/asistencias`: filtrar por periodo y busqueda; abrir un grupo -> sesiones -> asistencias por sesion. Esperado: **ningun control para editar o registrar asistencia** (checkbox, boton guardar, menu). Filtro fechas desde > hasta -> mensaje. Paginacion presente. [M]
16. Consolidado `/app/coordinador/consolidado-asistencia` (HU061): filtros cohorte/materia/docente/componente; comparar con el docente: porcentajes del grupo 001 (F-COO-007: asistencia 10 % con inasistencia 0 %). Estado vacio con filtro sin resultados. [M]

## Estudiantes e indicadores (HU065-HU070)
17. `/app/coordinador/estudiantes`: contar filas totales. **F-COO-001**: esperado 12; hoy muestra 22 (incluye `b1a2c3d4-...-0101` a `0109`). Anotar total y paginacion. Buscar por documento/nombre/codigo; filtro de estado. [M]
18. Abrir ficha de estudiante del programa (HU069): contacto, resumen por asignatura, bitacora paginada (HU067), permanencia (HU070). Abrir la ficha de un estudiante fuera de programa si aparece en la lista: esperado error/404 sin datos (F-COO-002).
19. `/app/coordinador/indicadores`: KPIs (HU065) y semaforo de alerta temprana (HU066, filtro por color, paginado). Contrastar `totalEstudiantes` (13) con el total de estudiantes (12) (F-COO-006). Tarjetas y tabla legibles en [M].

## Consistencia entre roles [D:docente] [D:estudiante]
20. El docente (`uco-docente`) registra 1 falta a un estudiante del grupo 001 (usar `CULM1-` en observacion). Coordinador: el consolidado, la alerta temprana, la ficha y la bitacora reflejan la falta; el % de inasistencia coincide con el visto por el docente y por el estudiante (`uco-estudiante`). Tiempo real: con la vista del coordinador abierta no debe requerir recarga (SSE `realtime/stream`, una sola conexion, sin polling en 3 min).

## Seguridad en pantalla
21. Pegar en la barra rutas ajenas: `/app/admin/...`, `/app/decano/...`, `/app/docente/...` -> redireccion o pagina 403 clara.
22. Sin sesion abrir `/app/coordinador/docentes` -> redirige a login.
23. Sesion expirada (esperar 5 min o limpiar cookies): la accion siguiente muestra el mensaje de sesion y vuelve a login sin pantalla en blanco.

## Estados y responsive generales
24. En cada pantalla: estado de carga (skeleton/spinner) al refrescar con red lenta (throttling), estado vacio y estado de error (bloquear `/api/v1/coordinador/*` en la consola de red) con mensaje y boton reintentar. [M] sin scroll horizontal de pagina, gutters 16 px, tablas con scroll interno.
25. Teclado: Tab recorre filtros, tabla, paginacion y modales con foco visible; contraste de badges (success/warning/danger) legible.
26. Cerrar sesion desde el menu de usuario; confirmar que volver atras no muestra datos.
