# SCREEN-RESULTS-decano (CULM-001 Fase 1, rol DECANO)

Ejecucion parcial. La sesion del decano (`uco-decano`) se cayo varias veces: al recargar rutas profundas la app vuelve a `/login?code=...` y no completa el callback OIDC. Desde el punto de caida no se pudo volver a autenticar, por lo que los pasos marcados como NO EJECUTADO no se verificaron. No se hizo logout explicito (la app quedo en `/login` sin sesion). Viewport restaurado a desktop.

## 1. Tabla de pasos

| Paso | Vista | Resultado | Observacion |
| :--- | :--- | :--- | :--- |
| 0 | Datos previos (admin, CULM1-Facultad B) | NO APLICA | No se ejecuto con el admin. Se usa la facultad `CULM1-Facultad B` ya existente. |
| 1.1 | `/app/decano/facultad` | OK | Resumen con KPIs reales (2 grupos, 15/72 inscritos, 1 plan, 1 area). Sin 94% fijo. |
| 1.2 | Menu lateral | OK | Entradas: Indicadores, Facultad, Grupos, Programas, Periodos, Infraestructura (Areas de Conocimiento), Coordinadores. No hay Sedes, Bloques, Aulas ni Espacios. |
| 1.3 | `/app/admin/facultades`, `/app/coordinador/grupos` | OK | Redirigen a `/app/decano/coordinadores` sin datos ni pantalla 403 explicita. |
| 2 | `/app/decano/indicadores` | OK (parcial) | Carga KPIs (retencion 100%, ausentismo 0%, aforo 20.83%) y tabla de grupos. Filtros de programa e "incluir no habilitados" NO EJECUTADO. Comparacion con coordinador NO EJECUTADO. |
| 3 | `/app/decano/programas` | FALLO (parcial) | Lista correcta tras ~4 s (al inicio muestra "Cargando" y "0 Planes"). Modal "Nuevo programa": submit vacio sin mensaje visible. Crear programa bloqueado: el selector de coordinador no tiene opciones. Cancelado sin crear nada. Editar/desactivar NO EJECUTADO. |
| 4 | `/app/decano/coordinadores` | FALLO (parcial) | Directorio correcto (1 coordinador). Formulario "Registrar Nuevo": submit vacio sin mensaje visible. No se creo coordinador. Edicion y desactivacion NO EJECUTADO. |
| 5 | `/app/decano/estudiantes` | OK | Directorio paginado (10 de 13), busqueda, filtros visibles. "Ver ficha" NO EJECUTADO. Busqueda de estudiantes de facultad B NO EJECUTADO. |
| 6 | `/app/decano/docentes` y `/app/decano/asignaturas` | OK | Docentes: 1 con filtro de programa y estado. Asignaturas: 1 (ARQ-402) con filtro de estado. |
| 7 | `/app/decano/grupos` y detalle | FALLO (parcial) | Lista OK (10/30 y 5/42). Detalle del grupo 001 OK, sin boton de registrar o editar asistencia. Error de consola `SessionTimeZoneError` al pintar fechas de sesiones. GUID inexistente muestra grupo vacio ("0 sesiones") sin mensaje de no encontrado. |
| 8 | `/app/decano/estructura`, `/cronograma`, `/periodos`, `/infraestructura` | OK | Arbol facultad/programa/plan OK. Cronograma: 6 sesiones, incluye sesiones solapadas (CULM1-Sesion solape). Periodo 2026-2 activo. Areas: ISW. Filtros desde/hasta NO EJECUTADO. |
| 9 | Descartadas (HU113-115, 118, 125-127, 129, 140, 141) | NO EJECUTADO | No revisado. |
| 10 | HU146 notificaciones / SSE | NO EJECUTADO | Requiere justificacion rechazada previa (CULM1-). |
| 11 | Consolidado de asistencia (solo lectura) | OK | `/app/decano/consolidado-asistencia` muestra 2 grupos sin controles de registrar o modificar asistencia. |
| 12 | Movil 375x812 | FALLO (parcial) | Sesion caida antes de medir rutas reales. Sin medicion valida de scroll horizontal. |
| Final | Cerrar sesion | NO EJECUTADO | Sesion ya caida; app en `/login`. |

Consola: 401 repetidos en la carga inicial, 400/500 en llamadas, y bloqueo CORS sobre `http://localhost:8080/api/v1/public/matricula-qr/validar` desde `http://localhost:4200`.

## 2. Hallazgos

| ID | Rol | HU | Severidad | Tipo | Pasos | Esperado | Obtenido | Evidencia | Capa sospechosa | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| F-DEC-S01 | DECANO | general (auth) | Alta | Bug | Recargar `/app/decano/grupos/:id` o `/app/decano/indicadores` directamente | Carga la pantalla con sesion activa | Vuelve a `/login?code=...` y se queda ahi; hace falta navegar varias veces | Tab URL `/login?state=...&code=REDACTED` tras navegacion directa | Auth / callback OIDC (frontend guard + BFF) | abierto |
| F-DEC-S02 | DECANO | HU076 | Alta | Bug | Programas > Nuevo programa > sin coordinador disponible | Permite elegir un coordinador o crear uno nuevo desde el flujo | Selector de coordinador sin opciones; no se puede crear programa | read_page del dialogo: `combobox "-- Selecciona un coordinador --"` sin opciones | Backend (listado de coordinadores disponibles) / frontend | abierto |
| F-DEC-S03 | DECANO | HU076 | Media | UX | Submit vacio en Nuevo programa | Mensaje de validacion visible por campo | Sin mensaje visible; el modal permanece | get_page_text tras submit | Frontend (formulario reactivo) | abierto |
| F-DEC-S04 | DECANO | HU120 | Media | UX | Submit vacio en Registrar coordinador | Mensaje de validacion visible por campo | Sin mensaje visible; el formulario permanece | get_page_text tras submit | Frontend (formulario) | abierto |
| F-DEC-S05 | DECANO | HU144 | Media | Bug | Detalle de grupo con GUID inexistente | Mensaje "grupo no encontrado" sin datos | Muestra "Volver a Grupos" y "0 sesiones", sin nombre ni aviso | get_page_text en `/app/decano/grupos/00000000-0000-0000-0000-000000000099` | Backend (codigo 404 del endpoint) / frontend (manejo de error) | abierto |
| F-DEC-S06 | DECANO | HU144 | Baja | Bug | Abrir detalle de grupo 001 con sesiones | Sin errores en consola | `ERROR SessionTimeZoneError: Instante o zona IANA invalidos` al formatear fecha de sesion | read_console_messages (onlyErrors) | Frontend (SessionTimeZoneService / DeanGrupoDetalleComponent) | abierto |
| F-DEC-S07 | DECANO | general | Media | Bug | Carga inicial de programas, o login | Sin 401/400/500 esperados ni bloqueo CORS | 401 repetidos, 400/500, y CORS bloqueado en `/api/v1/public/matricula-qr/validar` desde localhost:4200 | read_console_messages (onlyErrors) | Backend (CORS en endpoint publico) y llamadas tempranas del frontend | abierto |
| F-DEC-S08 | DECANO | HU076 | Baja | UX | Entrar a Programas | Lista visible desde el primer render | "Cargando programas..." con "0 Planes" durante unos segundos | get_page_text a 2 s y a 4 s | Frontend (estado de carga) | abierto |
| F-DEC-S09 | DECANO | HU 1.3 (ambito) | Baja | Observacion | Ir a `/app/admin/facultades` y `/app/coordinador/grupos` | Pantalla de acceso denegado o 403 explicito | Redireccion silenciosa a `/app/decano/coordinadores` | tabs_context y get_page_text | Frontend (guards de rol) | abierto |
