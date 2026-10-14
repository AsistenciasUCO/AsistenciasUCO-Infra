# LB-001B.1C final contract cleanup - TEST PLAN

## RED

1. `ClassSession` compila con campos reales y rechaza por tipo `topic`, `room`, `tipo`, `status`.
2. `SessionService.updateSession()` rechaza datos fantasma por tipo.
3. `PUT /api/v1/sesiones/{id}` serializa exactamente `nombre`, `fechaHoraInicio`, `fechaHoraFin`.
4. Formularios de sesión no renderizan inputs `tipo`, `aula/room`, `descripcion/topic`.
5. Detalle de sesión mapea `null`, `AN`, `SJC`, `EX` explícitamente.
6. Ausencia de asistencia permanece `null`.
7. No existe síntesis por `endsWith('2')`.
8. No existe contrato paralelo `ClassSessionDTO`.

## GREEN / validación

- `npm run verify`.
- Scans con `rg` para residuos contractuales.
- `ng build --configuration=production` queda cubierto dentro de `verify`.

## Riesgos

- El repo venía con cambios locales previos amplios. No se revierte trabajo ajeno.
- Los términos `room/aula/tipo/status` aparecen en otros dominios legítimos: `Course.room`, catálogos, `StudentAttendance.status`, `HttpError.status`, `User.status`.
