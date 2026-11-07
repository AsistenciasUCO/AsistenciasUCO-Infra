# SCREEN-TESTS-decano — guion de recorrido en pantalla (CULM-001 Fase 1)

Usuario: `uco-decano` (Facultad de Ingenieria; unica facultad sembrada, 1 programa "Ingenieria de Sistemas", 2 grupos de "Arquitectura de Software"). Clave: ver `docs/CREDENCIALES_PRUEBAS_LOCAL.md` (no copiarla). Login: `http://localhost:4200` -> ingreso -> Keycloak `keycloak.localhost:19090`. Cerrar sesion al terminar.

Convenciones: [M] = repetir en movil 375x812. [PRE] = necesita datos previos de otro rol. En cada paso mirar consola (0 errores) y red (sin llamadas repetidas periodicas; sin 4xx/5xx inesperados). Datos creados llevan prefijo `CULM1-`.

## 0. Datos previos (rol administrador, ANTES del recorrido del decano) [PRE]
- Con `uco-administrador` crear una segunda facultad `CULM1-Facultad B` con un programa `CULM1-Programa B` y, si es posible, un grupo. Sin ella NO se puede probar fuga de ambito entre facultades en pantalla (solo hay una facultad sembrada). Anotar los GUID (BD: SELECT en `uv_facultad`, `uv_programa`, `uv_grupo`).

## 1. Acceso y shell [M]
1. Ir a `/app/decano/facultad`. Esperado: resumen de la facultad de Ingenieria, tarjetas de KPIs con datos reales (sin 94% fijo).
2. Menu lateral: confirmar que NO hay entradas de Sedes, Bloques, Aulas ni Espacios fisicos. Existe «Areas de Conocimiento» (ruta `/app/decano/infraestructura`): debe listar areas, no sedes.
3. Ir por URL a `/app/admin/facultades` y `/app/coordinador/...`. Esperado: redireccion/403 sin datos.

## 2. HU102/HU103/HU106/HU144 Indicadores [M]
1. `/app/decano/indicadores`. Esperado: KPIs ausentismo, retencion, aforo; barras comparativas por programa; estado de carga, vacio y error.
2. Cambiar filtro de programa y marcar «incluir no habilitados». Red: una sola llamada por cambio, sin repeticion periodica.
3. Comparar KPIs con `/app/decano/facultad` y con el coordinador (`uco-coordinador` en `/app/coordinador/...`): mismo % de inasistencia/estudiantes. Anotar diferencias.
4. Selector de periodos anteriores (HU142) si aparece.

## 3. HU076/HU077/HU078/HU108/HU112 Programas [M]
1. `/app/decano/programas`: lista paginada (PaginationComponent), tabla de programas y creditos.
2. Crear `CULM1-Programa` (valido) -> toast con mensaje del backend. Intentar nombre vacio, nombre duplicado, nombre >limite -> mensaje del backend (400/409).
3. Editar modalidad/jornada de `CULM1-Programa`. Alternar su estado (modal de confirmacion) y reactivarlo. NO tocar «Ingenieria de Sistemas».
4. Abrir `/app/decano/programas/:planId` (malla): asignaturas del plan por semestre; plan inexistente/ajeno -> estado de error claro.

## 4. HU120-HU124 Coordinadores [M]
1. `/app/decano/coordinadores`: directorio (nota: sin paginacion, ver F-DEC-004). Buscador predictivo.
2. Crear `CULM1-Coordinador` (documento, correo, programa, clave inicial): validar mensajes por campo vacio, correo invalido, clave debil, correo/documento duplicado. Esperado: mensajes provenientes del backend.
3. Editar nombres/correo del coordinador creado. Alternar estado (el sembrado `uco-coordinador` NO se desactiva; probar con el creado). Intentar desactivar uno con programa activo -> `COO_001` con mensaje claro.

## 5. HU104/HU105 Estudiantes [M]
1. `/app/decano/estudiantes`: directorio paginado, busqueda por nombre/documento/correo, filtros. Estado vacio con busqueda sin resultados.
2. Abrir ficha de un estudiante: matriculas, historial; el panel recibe foco; si el historial falla la ficha sigue visible.
3. [PRE] Con facultad B creada, buscar el nombre de un estudiante de B: 0 resultados.

## 6. HU128/HU136 Docentes y HU143 Asignaturas [M]
1. `/app/decano/docentes`: listado paginado, selector de programa, busqueda; estados vacio/error.
2. `/app/decano/asignaturas`: busqueda transversal paginada; filtro por estado.

## 7. Grupos y detalle (HU144) [M]
1. `/app/decano/grupos`: tabla con cupos/aforo. Verificar el valor de cupo (si un grupo no tiene cupo definido aparece «/30»: ver F-DEC-005). Probar buscador.
2. Abrir detalle `/app/decano/grupos/:grupoId`: datos del grupo y sesiones; solo lectura (no hay botones de registrar/editar asistencia).
3. Pegar en URL un GUID inexistente y, [PRE], un GUID de grupo de la facultad B: esperado mensaje de no encontrado, sin datos.
4. Red: el detalle pide sesiones pagina a pagina a `/decano/sesiones` (comprobar cantidad de llamadas).

## 8. HU109/HU119 Estructura y HU145 Cronograma [M]
1. `/app/decano/estructura`: arbol facultad -> programa -> plan; plegar/desplegar con teclado.
2. `/app/decano/cronograma`: sesiones paginadas; filtros desde/hasta (desde > hasta debe avisar); sin sede.
3. `/app/decano/periodos`: lista de periodos (solo lectura).

## 9. Descartadas: confirmar que NO hay rastro visible (HU113-115, 118, 125-127, 129, 140, 141)
- Buscar en pantallas de programa/docente/facultad: sin «registro calificado», «suspender oferta», «bloqueo temporal», «departamento», «contrato», «horas contratadas», «sede», «escalafon».

## 10. HU146 Notificaciones
- [PRE] Docente rechaza una justificacion (CULM1-): verificar si el decano recibe aviso informativo; revisar campana y el SSE `/api/v1/realtime/stream` en red (una sola conexion, sin polling).

## 11. Solo lectura de asistencia
- En `/app/decano/consolidado-asistencia` y detalle de grupo: no deben existir controles de registrar/modificar asistencia.

## 12. Responsive y accesibilidad (resumen) [M]
- 375x812: sin scroll horizontal de pagina en cada ruta (las tablas pueden desplazarse en su contenedor); botones >= 44 px; modales cierran con Esc y atrapan foco; buscadores sin etiqueta visible (ver F-DEC-007).
