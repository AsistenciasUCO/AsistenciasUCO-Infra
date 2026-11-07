# AUDIT en pantalla — B.2 (tomas por horas, QR/PIN) — 2026-11-07

Entorno: backend `integracion/CULM-001` (A+B.1+B.2, jar reconstruido con `clean package`), frontend `integracion/CULM-001` (B.2 + E.2), BD restaurada al respaldo base + migraciones 13–16 + esquema B.2 (datos canónicos), PDP sincronizado (DEC-046).

| # | Pantalla / ruta | Rol | Resultado | Evidencia |
| :-- | :-- | :-- | :-- | :-- |
| 1 | `/app/estudiante/materias` | ESTUDIANTE | OK | Indicadores por horas desde el backend: "0% de inasistencia · Regular · 0 h de falta de 4 h dictadas · Advertencia desde 15% · pérdida desde 20%"; tarjetas "Materias en riesgo" y "Horas de falta"; botón "Registrar asistencia con PIN" (cierra F-EST-002/F-EST-009) |
| 2 | `/app/estudiante/horarios` | ESTUDIANTE | OK | 200 tras la reparación de la BD compartida (el 500 previo `Invalid object name 'AsignaturaPlanEstudio'` fue un despliegue parcial del agente de B2, revertido) |
| 3 | `/app/asistencia` (hub del docente) | DOCENTE | OK | KPI "Asistencia promedio 20 % · promedio por horas del grupo" y "Alerta inasistencia (horas)" desde el resumen del backend (cierra F-DOC-004); menú lateral con "Tomar Asistencia" y "Reclamos" (F-DOC-008) |
| 4 | `/app/asistencia?sessionId=…` (sesión #2) | DOCENTE | OK | `GET /api/v1/sesiones/{id}/tomas` → 200 (PDP autoriza la ruta nueva); panel "Tomas de asistencia · 1 de 4 tomas · 2 h de sesión"; "Toma 1 · Manual · Cerrada · 2 h · 2 presentes"; botón "Nueva toma" deshabilitado con el mensaje del backend "La ventana de asistencia de la sesión está cerrada" (sesión de agosto); "Ver faltantes" disponible; botón "Proyectar QR" visible; sábana sin "undefined" (F-DOC-S03) |
| 5 | Proyección QR / rotación / cierre con faltantes / registro por PIN del estudiante | DOCENTE + ESTUDIANTE | PENDIENTE en pantalla | Requiere una sesión con ventana abierta "ahora" (no existe en los datos canónicos y el modal "+ Nueva Sesión" no abrió desde la vista de asistencia). Cubierto por los IT de backend `TomaAsistenciaQrSqlServerIT` (flujo completo) y `AsistenciaQrConcurrenciaIT` (5×40 y 20×40 sin duplicados ni 429) y por los specs del frontend (B2-F-xx). Se ejecuta en el recorrido final de la Fase 3 con una sesión creada para el día |

Hallazgos nuevos: ninguno bloqueante. Observaciones: en los datos canónicos el grupo muestra "Docente: No informado" y "Horario no informado" para el estudiante (datos de semilla, no de código).
