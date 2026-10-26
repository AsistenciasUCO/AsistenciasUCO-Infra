---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# CONTRACT — HU104 / HU105 / HU109 / HU119 / HU145

Todos los endpoints: `GET`, rol `DECANO` (regla existente `/api/v1/decano/**`). Listas: `ApiListResponse` `{ exitoso, datos[], total }`; ficha: `ApiDataResponse` `{ exitoso, datos }`. Paginación `pagina` (≥ 1, por defecto 1) y `tamano` (1..100, por defecto 10).

| Endpoint | Filtros | SP |
|---|---|---|
| `/api/v1/decano/estudiantes` | `busqueda` (nombre o documento, ≤ 100), `idPrograma`, `estaActivo` | `usp_consultar_estudiantes_facultad_paginado` |
| `/api/v1/decano/estudiantes/{estudianteId}` | — | `usp_consultar_estudiante_facultad_detalle` |
| `/api/v1/decano/estructura` | — | `usp_consultar_estructura_facultad` |
| `/api/v1/decano/sesiones` | `desde`, `hasta` (ISO `yyyy-MM-dd`, inclusivos, `desde ≤ hasta`), `idPrograma` | `usp_consultar_sesiones_facultad_paginado` |

## Elementos

- **Estudiante:** `idEstudiante, numeroIdentificacion, nombreCompleto, correo, activo, programas, totalGrupos`.
- **Ficha:** `idEstudiante, numeroIdentificacion, nombreCompleto, activo, matriculas[ { idPrograma, nombrePrograma, inpPlanEstudio, idAsignatura, nombreAsignatura, idGrupo, nombreGrupo } ]`.
- **Estructura:** `[ { id, nombre, nombreDecano, activa, programas[ { id, nombre, nombreCoordinador, activo, nombreTipoPrograma, nombreModalidad, nombreJornada, planes[ { id, inp, activo, totalSemestres } ] } ] } ]`.
- **Sesión:** `id, nombre, codigo, numeroSemana, fechaHoraInicio, fechaHoraFin, idGrupo, codigoGrupo, nombreGrupo, idAsignatura, nombreAsignatura, idPrograma, nombrePrograma`.

## Errores

| Caso | HTTP |
|---|---|
| Usuario sin facultad de decano | 403 `FORBIDDEN` |
| Ficha de un estudiante que no es de la facultad | 404 |
| Paginación fuera de rango (`PAG_001` o caso de uso), `desde > hasta`, búsqueda > 100, UUID inválido | 400 |
