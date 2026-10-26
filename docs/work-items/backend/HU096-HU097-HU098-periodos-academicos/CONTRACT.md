---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# CONTRACT — HU096 / HU097 / HU098

## 1. HTTP

| Método y ruta | Roles | Cuerpo | Éxito | Rechazos |
|---|---|---|---|---|
| `POST /api/v1/admin/periodos-academicos` | `ADMINISTRADOR` | `{nombre, fechaInicio, fechaFin}` (fechas `YYYY-MM-DD`) | `200 {exitoso: true, datos: null}` | `400` nombre vacío o fechas inválidas (`PER_002`); `403` otro rol o sin institución (`PER_005`); `409` nombre duplicado (`PER_003`) |
| `PUT /api/v1/admin/periodos-academicos/{id}` | `ADMINISTRADOR` | igual | `200` | `400`; `403`; `404 PER_001`; `409 PER_003` |
| `DELETE /api/v1/admin/periodos-academicos/{id}` | `ADMINISTRADOR` | — | `200` | `403`; `404 PER_001`; `409 PER_004` (tiene grupos o sesiones) |
| `GET /api/v1/coordinador/periodos-academicos` | `DECANO`, `COORDINADOR`, `ADMINISTRADOR` | — | sin cambios | — |
| `POST/PUT /api/v1/coordinador/periodos-academicos` | — | — | ya no existen (antes 501) | — |
| `PATCH /api/v1/coordinador/periodos-academicos/{id}/estado` | — | — | sigue `501` | — |

## 2. DB (resultset canónico de 4 columnas)

| SP | Parámetros | Reglas |
|---|---|---|
| `usp_crear_periodo_academico` | `@idPeriodo`, `@nombre`, `@fechaInicio`, `@fechaFin`, `@idCorrelacion`, `@idUsuarioEjecutor` | ejecutor obligatorio; `ADMINISTRADOR` con institución activa (`SEC_001`/`PER_005`); nombre obligatorio; `PER_002`; `PER_003` (id o nombre existente en la institución); `codigo = YEAR*10 + (1 ene-jun, 2 jul-dic)`, `anio = YEAR(fechaInicio)` |
| `usp_actualizar_periodo_academico` | mismos | `PER_001` (no existe en la institución del ejecutor), `PER_002`, `PER_003` (nombre de otro período); recalcula `codigo` y `anio` |
| `usp_eliminar_periodo_academico` | `@idPeriodo`, `@idCorrelacion`, `@idUsuarioEjecutor` | `PER_001`; `PER_004` si existe `dbo.Grupo` del período; éxito `PER_006` |
| `usp_resolver_institucion_gestor_periodo_interno` | interno | RBAC `ADMINISTRADOR` y `dbo.Administrador.institucion` activa; denegado al runtime |

## 3. Clasificación backend

| Código | HTTP |
|---|---|
| `PER_001` | 404 |
| `PER_002` | 400 |
| `PER_003`, `PER_004` | 409 |
| `PER_005`, `SEC_001` | 403 |
