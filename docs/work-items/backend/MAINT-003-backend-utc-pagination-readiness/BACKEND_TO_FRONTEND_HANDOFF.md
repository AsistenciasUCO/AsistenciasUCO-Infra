---
status: active
type: handoff
scope: backend
last-reviewed: 2026-10-09
---

# Backend → Frontend: contrato de salida, NO desbloqueado

## Paginación existente (PR18)
`GET /api/v1/estudiantes?page=0&size=5&nombre=Ada&activo=true`
Authorization Bearer de `COORDINADOR` o `ADMINISTRADOR`. Estructura `{items:[{id,idUsuario,tipoIdentificacionId,numeroIdentificacion,primerApellido,segundoApellido,primerNombre,segundoNombre,nombreCompleto,correo,estaActivoUsuario}],totalItems,totalPages,page,size}`. Response es objeto raíz y `page` **0-based**; visual Angular `app-pagination` es 1-based. Filtros: `nombre,correo,numeroIdentificacion,tipoIdentificacionId,institucionId,facultadId,programaId,grupoId,activo`. `size` 1..100, default 20. **No devuelve semestre, programa textual, promedio, código institucional, estado matrícula, gruposInscritos**. El endpoint legacy `/coordinador/estudiantes` no es sustituto automático. Los datos se obtienen desde `dbo.uv_estudiante_identidad` + `dbo.uv_usuario`, `EXISTS` sobre `dbo.uv_estudiante` para filtros.

## Fechas y horarios
- **Actual v1** `/api/v1/sesiones`: entrada y salida `yyyy-MM-ddTHH:mm:ss` **sin offset**. Consumidores NO asumir automáticamente la zona del navegador. El DB declara UTC convencional en `DATETIME2`, pero no puede expresar su zona.
- **TARGET v2 no implementado**: `fechaHoraInicio/Fin` requieren RFC3339 con `Z` o `±HH:mm`; salida UTC `Z`. Activación solo por aprobación y tests reales. Ruta final y swagger se deben versionar en el commit de implementación.
- `HorarioDocente` y `HorarioEstudiante` usan `LocalTime` recurrente por día; no aplicar conversión UTC sin zona institucional y fecha.
- Audit `occurredAt` es instante offset +00:00, no inventar conversiones.

## Semáforo del handoff
`BLOCKED` hasta VALIDATION final con: hashes de GitHub PR18, PR19, UTC v2, evidencia SQL DB read/write, historial legacy, tests horarios Berlín/Londres/Bogotá+verano/invierno, seguridad y permisos, frontend Swagger contract freeze. No ir a fase frontend integral antes de publicación del contrato de backend.

Ejecución independiente y estado actualizado: [BACKEND_READY_FOR_FRONTEND](BACKEND_READY_FOR_FRONTEND.md). Decisiones UTC pendientes de aprobación: [UTC_API_V2_PROPOSAL](UTC_API_V2_PROPOSAL.md).
