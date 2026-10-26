---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-24
---

# CONTRACT — HU081 / HU082 / HU083

## 1. HTTP (rol `COORDINADOR`)

| Método y ruta | Cuerpo | Éxito | Rechazos |
|---|---|---|---|
| `PATCH /api/v1/coordinador/planes-estudio/{id}/toggle-estado` | — | `200 {exitoso: true, datos: null}` | `403` sin programa; `404` plan fuera del programa del coordinador |
| `POST /api/v1/coordinador/planes-estudio/{id}/semestres` | — | `200 {exitoso: true, datos: null}` | `403`; `404 PLA_002`; `409 PLA_003` (máximo de semestres) |
| `DELETE /api/v1/coordinador/planes-estudio/{id}/semestres/{numero}` | — | `200 {exitoso: true, datos: null}` | `400` número no positivo; `403`; `404 PLA_002/PLA_004`; `409 PLA_005` (no es el último), `409 PLA_006` (tiene asignaturas) |
| `GET /api/v1/coordinador/planes-estudio` | — | cada plan agrega `totalSemestres` (entero, 0 si no tiene semestres) | sin cambios |

## 2. DB (procedimientos públicos, resultset canónico de 4 columnas)

| SP | Parámetros | Reglas |
|---|---|---|
| `usp_cambiar_estado_plan_estudio` | `@idPlanEstudio`, `@estaActivo BIT`, `@idCorrelacion`, `@idUsuarioEjecutor` | ejecutor obligatorio; RBAC `COORDINADOR`; `PLA_002` plan inexistente; titularidad `PROGRAMA` (`SEC_002`); idempotente |
| `usp_agregar_semestre_plan_estudio` | `@idPlanEstudio`, `@idCorrelacion`, `@idUsuarioEjecutor` | igual validación; siguiente número `MAX + 1`; `PLA_003` si no existe en `dbo.Semestre`; bloqueo `UPDLOCK, HOLDLOCK` del plan |
| `usp_quitar_semestre_plan_estudio` | `@idPlanEstudio`, `@numeroSemestre`, `@idCorrelacion`, `@idUsuarioEjecutor` | igual validación; `PLA_004` no pertenece; `PLA_005` no es el último; `PLA_006` tiene asignaturas |

Vista `uv_plan_estudio`: `estaActivoPlanEstudio = 0` si el programa está inactivo **o** `PlanEstudio.estado = 0`.

## 3. Clasificación de códigos en el backend

| Código | HTTP |
|---|---|
| `PLA_002`, `PLA_004` | 404 `RESOURCE_NOT_FOUND` |
| `PLA_003`, `PLA_005`, `PLA_006` | 409 `CONFLICT` |
| `SEC_001`, `SEC_002` | 403 (existente) |
