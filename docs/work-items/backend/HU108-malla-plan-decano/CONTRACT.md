---
status: active
type: work-item
scope: backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# CONTRACT — HU108 (parte de planes)

## `GET /api/v1/decano/planes-estudio/{planId}/asignaturas`

- **Rol:** `DECANO` (regla existente `/api/v1/decano/**`).
- **Respuesta:** `ApiListResponse<AsignaturaDTO>` `{ exitoso, datos[], total }`, con la misma forma que `GET /api/v1/coordinador/planes-estudio/{id}/asignaturas`: `id, codigo, nombre, credito, idArea, nombreArea, idComponente, nombreComponente, idSemestrePlanEstudio, idPlanEstudio, idPrograma, nombrePrograma, codigoSemestre, estaActivaAsignatura, estaActivaTextoAsignatura`.
- **Ámbito:** el programa del plan debe ser de la facultad del decano.

| Caso | HTTP |
|---|---|
| Plan de un programa de su facultad | 200 con la malla |
| Plan sin asignaturas | 200 con lista vacía |
| Usuario sin facultad de decano, o plan de otra facultad | 403 `FORBIDDEN` |
| `planId` no es UUID | 400 |

La ficha del plan (programa, INP, semestres, vigencia) se toma de `GET /api/v1/decano/estructura` (contrato de HU109/HU119).
