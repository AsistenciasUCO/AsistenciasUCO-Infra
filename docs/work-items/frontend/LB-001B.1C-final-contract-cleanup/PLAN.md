# LB-001B.1C final contract cleanup - PLAN

Fecha: 2026-09-22

## Alcance

Clase de cambio: CONTRACT_CHANGE + BEHAVIOR_CHANGE + DEAD_CODE_CLEANUP.

Variable principal: contrato frontend de `Sesion`, alineado al backend/DB como fuente de verdad.

## Contrato congelado

Backend confirmado en `C:\Users\josev\AsistenciasUCO\AsistenciasUCO`:

- Crear sesión: `grupo`, `nombre`/`tema`, `fechaHoraInicio`, `fechaHoraFin`.
- Actualizar sesión: `nombre`/`tema`, `fechaHoraInicio`, `fechaHoraFin`.
- Consultar sesión: `sesion`, `grupo`, `nombre`, `numero`, `codigo`, `numeroSemana`, `codigoGrupo`, `nombreGrupo`, `fechaHoraInicio`, `fechaHoraFin`.

No forman parte de `Sesion`: `descripcion`, `aula`, `tipo`, `topic`, `room`, `status`, `PROGRAMADA`, `EN_CURSO`, `CONCLUIDA`.

`Course.room` / `Grupo.aula` se conserva como dato de grupo.

## Cambios planificados

- Retirar `topic`, `room`, `tipo`, `status` de `ClassSession`.
- Eliminar el contrato paralelo muerto `ClassSessionDTO` y los mappers `sessionFromDTO/sessionToDTO/studentFromDTO/studentToDTO`.
- Eliminar `course.mapper.ts` y `crear-sesion-request.model.ts` si no tienen consumidores.
- Corregir `SessionService.updateSession()` para recibir un input explícito y serializar exactamente `{ nombre, fechaHoraInicio, fechaHoraFin }`.
- Retirar inputs fantasma de formularios de sesión.
- Corregir presentación de asistencia nula en detalle: `null -> Sin registrar`.
- Mantener `Course.room` como "Aula del grupo" cuando se muestre como contexto.

## Fuera de alcance

- Backend productivo `src/**`.
- DB.
- OpenAPI/JPA/WebSocket/NgRx/providers/endpoints nuevos.
