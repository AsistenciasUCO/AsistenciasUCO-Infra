# AUDIT-PANTALLA-B1 — Auditoría en pantalla del subpaquete B.1 (HU047 cancelar sesión, estado cancelada, festivos)

Fecha: 2026-11-07. Entorno: backend integración :8080, frontend :4200 (rama integracion/CULM-001), navegador integrado. Roles: docente, estudiante, coordinador, decano, administrador. Dato creado: sesión `CULM1-AUD-B1` (SES-16, Grupo 001, 2026-12-15 10:00-11:00), luego cancelada con motivo `CULM1 auditoría B.1`.

## Pasos

| # | Rol | Ruta | Resultado | Detalle |
| :--- | :--- | :--- | :--- | :--- |
| 1 | DOCENTE | `/app/docente/grupos?grupo=<G1>` (hub, botón Padrón) -> "Programar Sesión Extraordinaria" | OK | Sesión creada, toast "Sesion creada correctamente." |
| 2 | DOCENTE | hub, lista de sesiones | OK | Acción "Cancelar" en cada sesión no cancelada (15 botones, alto 44 px en móvil). En `/app/asistencia` NO hay acción Cancelar (solo en el hub; ver F-B1-S02) |
| 3 | DOCENTE | modal "Cancelar Sesión #16", motivo vacío y 5 caracteres | OK | Botón "Confirmar Cancelación" deshabilitado, contador "5/500 · mínimo 10 caracteres"; no se envía petición |
| 4 | DOCENTE | `PATCH /docente/sesiones/{id}/cancelar` con motivo válido | OK | 200; toast "Sesión cancelada. Estudiantes notificados: 10."; fila con etiqueta "Cancelada", título tachado, Tomar Asistencia y Ajustar Horario deshabilitados |
| 5 | DOCENTE | motivo visible tras cancelar | OBSERVACIÓN | Justo tras cancelar el hub solo muestra la etiqueta; tras recargar sí muestra "Cancelada / CULM1 auditoría B.1" (F-B1-S03) |
| 6 | DOCENTE | cancelar `CULM1-Sesion hoy` (SES-03) y `CULM1-Solape G1` (SES-05) | OK | 409 `SES_016` con mensaje del backend "La sesión ya terminó y tiene asistencia registrada; no se puede cancelar. Las correcciones se hacen por reclamo." mostrado en el modal; sin 500. `SES_012` no reproducible (F-B1-S08) |
| 7 | DOCENTE | `/app/asistencia?courseId=..&sessionId=<cancelada>` | OK con matiz | Mensaje "La sesión está cancelada; no es posible registrar asistencia. CULM1 auditoría B.1. La consulta del registro sigue disponible." (texto del frontend, F-B1-S05). El botón queda habilitado y navega |
| 8 | DOCENTE | `/app/asistencia` lista | OK | "Cancelada" + motivo; CRONOGRAMA 15 (excluye la cancelada; hay 16 sesiones) |
| 9 | DOCENTE | hub, sábana | OK con matiz | Columna "#16 CANCELADA", denominador 0/15 (excluye). La tarjeta "Sesiones de Clase" del hub dice 16 (F-B1-S04). Filas "undefined undefined / ID: N/A" (F-B1-S06) |
| 10 | DOCENTE | realtime | OK | `GET /api/v1/realtime/stream?grupoId=` presente (200; varios ERR_ABORTED por cambio de vista/reconexión); 0 peticiones nuevas en 20 s tras cancelar (sin polling) |
| 11 | DOCENTE móvil 375x812 | hub, sesiones | OK | Sin scroll horizontal (scrollWidth 375), tarjeta cancelada con etiqueta y motivo, botones de 44 px |
| 12 | ESTUDIANTE | `/app/estudiante/materias` -> Ver Detalle | OK | Sesión #16 "Cancelada / CULM1 auditoría B.1", sin botón de reclamo; API `estado:"CANCELADA"`, `reclamable:false` |
| 13 | ESTUDIANTE | búsqueda de `codigo` | OK | El texto de la página no contiene "código" ni `SES-nn`; la respuesta `GET /estudiante/materias/{id}/sesiones` no trae clave `codigo` (solo `codigoGrupo`) |
| 14 | ESTUDIANTE móvil | detalle | OK | scrollWidth 375 |
| 15 | COORDINADOR | `/app/coordinador/asistencias` -> Ver sesiones (pág. 2) | OK | "CULM1-AUD-B1 SES-16 / Cancelada / CULM1 auditoría B.1"; solo "Ver asistencia" (lectura); detalle "No hay registros de asistencia para esta sesión." |
| 16 | DECANO | `/app/decano/cronograma` | OK | AUD-B1 "Cancelada" + motivo, sin controles; también 2 sesiones canceladas por festivo ("Día festivo: Independencia de Cartagena") |
| 17 | ADMINISTRADOR | menú "Festivos" `/app/admin/festivos` | BLOQUEADO-PDP (B-01 PDP) | `GET /api/v1/admin/festivos?anio=2026` 403 `FORBIDDEN` "No tiene permisos para realizar esta operacion." (cid 82c232b9-cd3d-4844-b890-1dfbd20cddf9); la pestaña "Sesiones en festivo con asistencia" también. UI correcta: selector 2026/2027, "Recargar año", atribución "Fuente: Calendarios Nacionales" con enlace https://calendariosnacionales.com/, error del backend y "Reintentar". Tabla y recarga no verificables en pantalla |
| 18 | ADMINISTRADOR móvil | `/app/admin/festivos` | OK (solo estado de error) | scrollWidth 375 |
| 19 | BD | SELECT `DiaFestivo`, `SesionCancelacion` | OK | `DiaFestivo`: 2026 = 19, 2027 = 19. `SesionCancelacion` = 4 antes de la auditoría (todas por festivo, 2026-11-07 16:16 UTC: Inmaculada Concepción x2, Independencia de Cartagena x2); con AUD-B1 son 5 |

Consola (onlyErrors): 400/404/409 previos de otras sesiones, mis 2 x 409 `SES_016` y 2 x 403 de festivos. Ningún 500 ni error de JS.

## Hallazgos

| ID | Rol | HU | Severidad | Tipo | Pasos | Esperado | Obtenido | Evidencia | Capa sospechosa | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| F-B1-S01 | ADMINISTRADOR | Festivos (B.1) | media | bloqueo-entorno | Menú Festivos -> `/app/admin/festivos` | Tabla con 19 festivos 2026 y sesiones en festivo | 403 `FORBIDDEN` del PDP en `GET /api/v1/admin/festivos?anio=2026` y en la pestaña de sesiones. "B-01 PDP": no es fallo de producto | `GET /api/v1/admin/festivos?anio=2026` 403 cid 82c232b9-cd3d-4844-b890-1dfbd20cddf9 | Infra (PDP) | abierto (B-01) |
| F-B1-S02 | DOCENTE | HU047 | baja | UX/UI | `/app/asistencia` -> historial de sesiones | Acción cancelar accesible desde la lista de sesiones | "Cancelar" solo existe en el hub `/app/docente/grupos?grupo=<id>` (botón Padrón); en `/app/asistencia` la tabla solo ofrece "Tomar Asistencia", y "Ver Grupo" de la tarjeta lleva a `/app/asistencia`. Descubribilidad baja | `teacher-grupo-sesiones.component.ts:125`; `attendance-control` sin acción cancelar | Frontend | abierto |
| F-B1-S03 | DOCENTE | HU047 | baja | bug | Cancelar una sesión en el hub y mirar la fila sin recargar | Etiqueta "Cancelada" y motivo visibles al instante | Se ve la etiqueta pero no el motivo hasta recargar | Fila #16 sin motivo tras PATCH 200; con recarga "CULM1 auditoría B.1" | Frontend | abierto |
| F-B1-S04 | DOCENTE | HU047, HU029 | baja | inconsistencia | Hub del grupo tras cancelar | Contadores coherentes (sábana y `/app/asistencia` excluyen canceladas: 15) | La tarjeta "Sesiones de Clase" muestra 16 (incluye la cancelada) | hub "Sesiones de Clase 16" vs sábana 0/15 y CRONOGRAMA 15 | Frontend | abierto |
| F-B1-S05 | DOCENTE | HU047 | baja | inconsistencia | `/app/asistencia?...&sessionId=<cancelada>` | Mensaje institucional del backend (AGENTS 3.3.4) | El texto "La sesión está cancelada; no es posible registrar asistencia..." sale de una constante del frontend con el motivo concatenado | `session-attendance-window.util.ts:18` | Frontend | abierto |
| F-B1-S06 | DOCENTE | HU029 | media | bug | Hub -> Sábana de Asistencia (Grupo 001, 10 matriculados) | Nombres y documento de los 10 estudiantes y resultados por sesión | Todas las filas "undefined undefined / ID: N/A" con guiones en todas las sesiones (incluidas SES-03 y SES-05 con asistencia). Probablemente previa a B.1 (carga de `/grupos/{id}/estudiantes` y `/asistencias`); no atribuible a la cancelación | texto de la sábana del hub; `GET /grupos/{G1}/estudiantes` 200 | Frontend / Backend | abierto (por confirmar) |
| F-B1-S07 | DOCENTE | Rendimiento | baja | rendimiento | `/app/docente/grupos?grupo=<G1>` | Hub listo en pocos segundos | Hasta ~8 s con "Grupos Habilitados 0 / Estudiantes Registrados 0" mientras carga (contadores en 0 engañosos) | observado dos veces | Frontend | abierto |
| F-B1-S08 | DOCENTE | HU047 | baja | cobertura | Provocar `SES_012` | Mensaje del backend para sesión en curso con asistencia | No reproducible con los datos: las dos sesiones con asistencia ya terminaron y devuelven `SES_016` | PATCH 409 SES_016 en SES-03 y SES-05 | Datos de prueba | pendiente |
