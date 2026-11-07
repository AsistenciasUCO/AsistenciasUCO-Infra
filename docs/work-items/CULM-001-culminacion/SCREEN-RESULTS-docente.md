# SCREEN-RESULTS-docente (CULM-001 Fase 1, rol DOCENTE)

Usuario: `uco-docente`. App `http://localhost:4200`, backend `http://localhost:8080`. Fecha de ejecución: 2026-11-06 (hora local UTC-5).
Notas de método: en el navegador integrado la vista de escritorio mide 1139x477; las cargas por URL directa requieren ~4 s de espera antes de leer la página. Los pasos marcados NO APLICA o NO EJECUTADO quedan explicados en la columna Observación.

## (1) Tabla de pasos

| Paso | Vista (escritorio/tablet/móvil) | Resultado | Observación |
| :--- | :--- | :--- | :--- |
| P1.1 Login | escritorio | OK | Login con `uco-docente` por Keycloak local; llega a `/app/docente/grupos`. Sin 401/403 del PDP en el flujo. |
| P1.2 Dashboard | escritorio, móvil | FALLO | Contadores coherentes (2 asignaturas, 15 alumnos, 1 reclamo pendiente). Pero las tarjetas muestran "undefined • Grupo 001 - Arq Software" (F-DOC-S02). Mensajes fijos del frontend. |
| P1.3 Menú lateral | escritorio | OK | Menú: Panel Principal, Mis Grupos, Mis Horarios. No hay "Reclamos" ni "Tomar asistencia" (esperado según F-DOC-008). |
| P1 móvil | móvil 375x812 | OK | `scrollWidth` = `innerWidth` = 375 en dashboard. |
| P2.1 Lista de grupos | escritorio | FALLO | Exactamente 2 grupos. Filtro "postgrado" y búsqueda sin coincidencias dejan la lista vacía sin mensaje de estado vacío (F-DOC-S01). |
| P2.2 Cupo y activos | escritorio | OK | G1 10/30 y G2 5/42, coherente con guion. |
| P2.3 GUID inventado en URL | escritorio | FALLO | `courseId=00000000-0000-4000-8000-0000000000aa` no lanza petición ni mensaje del backend; la pantalla muestra datos de Grupo 001 (F-DOC-S05). |
| P3 Hub y configuración (HU043/HU044) | escritorio | NO EJECUTADO | El hub real es `/app/docente/grupos?grupo=<id>` con pestañas Horario, Alumnos Matriculados, Solicitudes de Ingreso, Reclamos y Novedades, Sábana de Asistencia (Matriz). No se encontró pestaña "Configuración" ni botón "Proyectar Auto-Registro"; el guion describe otra estructura (F-DOC-S06). No se editó observaciones/aforo para no tocar grupos sembrados. |
| P4.1 Padrón G1 | escritorio, móvil | OK | 10 filas, coherente con BD. Sin paginación visible (F-DOC-007). Buscador predictivo y estado vacío no probados. |
| P4.2 Modal Retirar (HU051) | escritorio | OK | Modal abierto sobre estudiante sembrado, contador "494/500" con maxlength 500 (no permitió superar 500). Cancelado sin enviar. No se pulsó "Retirar estudiante" para no retirar un estudiante sembrado. Validación de motivo vacío no comprobada. |
| P5.1 Matrícula manual | escritorio | NO EJECUTADO | No se creó `CULM1-Estudiante Uno` para no alterar el padrón sembrado sin necesidad del hallazgo; no se probó duplicado/correo ni modo offline. |
| P5.2 QR / PIN Matrícula (G2) | escritorio | NO EJECUTADO | No ejecutado en esta sesión. |
| P5.3 a P5.5 (estudiante, cierre, SSE offline) | escritorio | NO APLICA | Requiere sesión de `uco-estudiante` y pasos de matrícula no ejecutados. |
| P5.6 QR/PIN en 375 px | móvil | NO EJECUTADO | No ejecutado. |
| P6 Solicitudes de ingreso | escritorio | OK | Pestaña presente (contador 2 en "Solicitudes de Ingreso"); no evaluada por diseño (HU053-055 retiradas). |
| P7.1 Lista de sesiones | escritorio | FALLO | En la primera carga de `/app/asistencia` la lista aparece vacía ("No hay sesiones programadas") aunque `GET /api/v2/sesiones/grupo/...` responde 200 con `total: 5`. Tras recargar sí aparecen las 5 con folio SES-01..SES-05 (F-DOC-S04). |
| P7.2 Crear `CULM1-Sesion hoy` | escritorio | NO APLICA | La sesión ya existe (SES-03, creada por API). No se creó duplicado. |
| P7.3 Cruce de horario (HU034) | escritorio | NO APLICA | El solape ya existe sembrado (`CULM1-Solape G1`, SES-05); no se creó otro para no contaminar datos. |
| P7.4 Validaciones de formulario | escritorio | NO EJECUTADO | No ejecutado en esta sesión. |
| P7.5 Editar sesión futura | escritorio | NO EJECUTADO | No ejecutado. |
| P7.6 HU047 sin "Cancelar sesión" | escritorio | OK | En la vista de sesión no aparece "Cancelar sesión" (revisado en lista y detalle del cronograma). |
| P7.7 Detalle de sesión | escritorio | NO EJECUTADO | No ejecutado. |
| P8.1 Tomar lista en sesión abierta | escritorio | OK | `CULM1-Solape G1` abierta (22:45-23:35 local); 10 alumnos activos listados. |
| P8.2 Todos Presentes y guardar | escritorio | OK (con observación) | `POST /api/v1/asistencias/lote` respondió **201** (el guion esperaba 200). Estados quedaron "Asistencia Normal" tras guardar. No se capturó el toast. Ver F-DOC-S07. |
| P8.3 Ausentes/excusa y persistencia | escritorio | NO EJECUTADO | No ejecutado (se priorizó P8.2 y P9). |
| P8.4 Métricas y semáforo | escritorio | NO EJECUTADO | No comparado con sábana por el fallo de F-DOC-S03. |
| P8.5 SSE entre pestañas | escritorio | NO EJECUTADO | No ejecutado. Se observó `GET /api/v1/realtime/stream?grupoId=...` conectado sin token en la URL. |
| P8.6 Proyectar QR (HU175) | escritorio | FALLO | El modal muestra QR y PIN **392-817** con texto "Válido exclusivamente en red Wi-Fi Campus UCO" y TTL de 36 s; el código es simulado (F-DOC-002 ya conocido) y se presenta como real (F-DOC-S08). |
| P9.1 Fuera de ventana | escritorio | OK | En `CULM1-Sesion futura` aparece "La sesión aún no ha iniciado; la asistencia solo se registra durante la sesión." y "Todos Presentes" y "Guardar Asistencia" están `disabled`. Texto de ventana fijo del frontend (no del backend). |
| P9.2 Envío tras vencer ventana (409) | escritorio | NO EJECUTADO | No se editó la fecha de fin de una sesión para no alterar datos. |
| P10.1 Sábana G1 | escritorio | FALLO | Se muestran 10 filas con "undefined undefined / ID: N/A" y todas las celdas "—", "0 / 5", 0%, "Regular Normal", pese a que `/estudiantes` y `/asistencias` responden 200 y a que se guardó asistencia presente en la sesión #5 (F-DOC-S03). |
| P10.2 Comparar faltas y % | escritorio | NO EJECUTADO | Bloqueado por F-DOC-S03. |
| P10.3 Sábana en 375 px | móvil | NO EJECUTADO | No ejecutado. |
| P11 Reclamos | escritorio | NO APLICA | Requiere reclamo previo creado por `uco-estudiante` (PRE). Sin esos datos no se ejecutó. Solo se vio el contador "Reclamos Pendientes: 1" del dashboard. |
| P12.1 Horario docente | escritorio | OK | `/app/docente/horarios`: "0 Horas / Semana", días sin clases; coherente con grupos "Sin horario asignado". Sin error. |
| P12.2 Perfil | escritorio | NO EJECUTADO | No ejecutado. |
| P13.1 Conexiones SSE y polling | escritorio | NO EJECUTADO (parcial) | Se verificó una conexión `realtime/stream?grupoId=...` sin token en URL. No se midió 2 min sin peticiones periódicas. Se observaron GET repetidos de `/estudiantes` y `/asistencias` al cambiar de pestaña (F-DOC-S11). |
| P13.2 Campana de notificaciones | escritorio | NO EJECUTADO | No ejecutado. |
| P14 Cierre de sesión | escritorio | OK | Botón "Cerrar sesión" del menú lateral (primer clic sobre el modal de proyección no funcionó; se cerró el modal recargando el panel). Quedó en `/login`. |
| Restablecer vista | escritorio | OK | `preset: desktop` aplicado al final. |

Errores de consola (`onlyErrors`): en la sesión aparecen 401 (cinco), 400 (varios), 500 (uno), CORS en `http://localhost:8080/api/v1/public/matricula-qr/validar` y `net::ERR_FAILED`. No pude asociarlos a un paso concreto del docente porque ya estaban en el registro de consola antes de mi login. Ver F-DOC-S12.

## (2) Hallazgos nuevos

| ID | Rol | HU | Severidad | Tipo | Pasos | Esperado | Obtenido | Evidencia | Capa sospechosa | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| F-DOC-S01 | DOCENTE | HU058 | media | UX | P2.1 | Mensaje de estado vacío cuando el filtro o la búsqueda no devuelve grupos | Lista vacía sin texto alguno (postgrado, búsqueda "zzqinexistente") | `/app/docente/grupos`, sin petición de error de red; captura visual de lista en blanco | Frontend: componente de lista de grupos (plantilla sin rama vacía) | abierto |
| F-DOC-S02 | DOCENTE | HU031 | media | bug | P1.2 | Nombre de asignatura visible en las tarjetas "Mis Asignaturas" | "undefined • Grupo 001 - Arq Software" y "undefined • Grupo 03 (prueba)" | `/app/dashboard`, `GET /api/v1/docente/asignaturas` 200 | Frontend: mapeo de campo de asignatura en tarjetas del dashboard (o contrato de `docente/asignaturas`) | abierto |
| F-DOC-S03 | DOCENTE | HU029, HU040 | alta | bug | P10.1, P10.2 | Sábana con nombre, documento y marcas por sesión de cada estudiante; % calculado | 10 filas "undefined undefined / ID: N/A", celdas "—", "0 / 5" y 0% para todos, aunque la sesión #5 tiene 10 presentes guardados | `GET /api/v1/grupos/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d/estudiantes` 200; `GET /api/v1/grupos/.../asistencias` 200; `/app/docente/grupos?grupo=...` pestaña Sábana | Frontend: mapeo de DTO de sábana (campos nombre/documento/estado). Revisar también forma de respuesta de `asistencias` | abierto |
| F-DOC-S04 | DOCENTE | HU027, HU028 | alta | bug | P7.1 | Lista de sesiones del grupo al entrar a Control de Asistencia | "No hay sesiones programadas" en la primera carga, pese a `GET /api/v2/sesiones/grupo/a1b2c3d4-...` 200 con `total: 5`; tras recargar aparecen las 5 | `/app/asistencia?courseId=a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d`, correlationId no capturado | Frontend: carga/estado inicial de sesiones (orden de peticiones o signal no actualizado) | abierto |
| F-DOC-S05 | DOCENTE | HU043 | media | bug | P2.3 | Mensaje de backend o pantalla de no encontrado para grupo inexistente | Muestra datos de Grupo 001 sin petición nueva ni error | `/app/asistencia?courseId=00000000-0000-4000-8000-0000000000aa`; no hubo llamada de red con ese id | Frontend: resolución de `courseId` desde la URL y caché de estado del grupo | abierto |
| F-DOC-S06 | DOCENTE | HU043, HU044 | baja | inconsistencia | P2, P3 | Flujo de guion: "Ver Grupo" lleva al hub con pestañas y configuración | "Ver Grupo" lleva a `/app/asistencia`; el hub está en `/app/docente/grupos?grupo=` y no hay pestaña "Configuración" | Navegación observada | Documento de guion desfasado respecto a la UI, o enlace incorrecto en la lista de grupos | abierto |
| F-DOC-S07 | DOCENTE | HU027 | baja | inconsistencia | P8.2 | `POST /api/v1/asistencias/lote` responde 200 según guion | Respuesta **201** | `read_network_requests`: `POST http://localhost:8080/api/v1/asistencias/lote → 201` | Contrato backend/guion: confirmar código esperado para creación de lote | abierto |
| F-DOC-S08 | DOCENTE | HU175 | alta | seguridad | P8.6 | Proyección de QR/PIN solo con códigos reales de un registro de auto-asistencia, o no ofrecida | Modal muestra QR y PIN 392-817 con texto "Válido exclusivamente en red Wi-Fi Campus UCO" y TTL 36 s, siendo simulado | Captura del modal "Proyectar QR" (sesión `CULM1-Solape G1`) | Backend/contrato de auto-registro (validación de código) y frontend (no ofrecer proyección simulada) | abierto |
| F-DOC-S09 | DOCENTE | HU027 | baja | UX | P8 | Sesión seleccionada por defecto coherente con "Tomar Asistencia Hoy" del hub | Por defecto aparece "CULM1-Solape G1" (22:45-23:35) y no "CULM1-Sesion hoy" (22:30-00:35), ambas de hoy | `/app/asistencia?courseId=...` | Frontend: selección por defecto de sesión | abierto |
| F-DOC-S10 | DOCENTE | HU029 | baja | rendimiento | P13.1 | Sin peticiones repetidas innecesarias al cambiar de pestaña | Se repiten `GET /estudiantes` y `GET /asistencias` (dos veces cada uno en pocos segundos) | `read_network_requests` sobre `/api/v1/grupos/.../estudiantes` y `/asistencias` | Frontend: suscripciones/efectos que recargan datos al cambiar de vista | abierto |
| F-DOC-S11 | DOCENTE | HU042 | baja | notificación | P13 | Sin llamadas periódicas | No medido a 2 min; se observan recargas repetidas (ver F-DOC-S10) | Red | Frontend realtime | abierto |
| F-DOC-S12 | DOCENTE | transversal | media | bug | Consola general | Consola sin errores en flujo docente | Errores acumulados: 401 x5, 400 x varios, 500 x1, CORS en `/api/v1/public/matricula-qr/validar`, `net::ERR_FAILED`. No reproducido dentro del flujo docente | `read_console_messages` onlyErrors | Backend (CORS del endpoint público de matrícula QR y 500) y frontend (llamadas previas al login) | abierto |

## Cobertura no ejecutada (para la siguiente pasada)
- P3 (configuración HU044), P5.1-P5.6 (matrícula manual y QR/PIN con SSE), P7.4, P7.5, P7.7, P8.3-P8.5, P9.2, P10.3, P11 (requiere estudiante), P12.2, P13.2 y medición de 2 min de P13.1.
