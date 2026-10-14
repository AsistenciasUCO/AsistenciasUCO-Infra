# MV-001 — Golden Path E2E real (checklist)

Estado: **BLOCKED_BY_ENVIRONMENT** (no ejecutado, no se declara PASS).

> Actualización: MV-001 se ejecutó después contra el entorno local real (ver `docs/work-items/MV-001-golden-path-real-e2e/MV-001-REPORT.md`); reveló los defectos `MV001-R01` y `MV001-A01`, corregidos por MV-001A. Este archivo queda como checklist original.

Motivo verificado el 2026-09-24: sin respuesta en `localhost:8080` (backend), `:8081` (Keycloak), `:1433` (SQL Server) ni `:4200` (frontend); Docker Desktop no está en ejecución (`dockerDesktopLinuxEngine` inaccesible). Levantar backend/DB queda fuera del alcance de LB-001B.5 (repos de solo lectura).

## Precondiciones

- Frontend con `USE_MOCKS=false` (sin `localStorage.USE_MOCKS`, `window.env.USE_MOCKS` ausente o `false`).
- Backend Golden Path (SHA de contrato `02a17456…db121`), Keycloak con realm `asistencias-uco`, contenedor `sql_server_asistencias`.
- Dos clientes/navegadores con el mismo docente titular del grupo (A y B) y un tercer usuario docente no titular.

## Escenario

| # | Paso | Esperado |
|---|---|---|
| 1 | Login docente | Redirige a `/app/docente/grupos` |
| 2 | Consultar horario | `GET /docente/horarios` 200 |
| 3 | Seleccionar grupo | `GET /sesiones/grupo/{id}` 200 |
| 4 | Consultar sesiones y estudiantes | `GET /grupos/{id}/estudiantes` 200 |
| 5 | Sin registros previos | Todos «Sin registrar»; ningún `AN` sintético |
| 6 | Marcar AN / SJC / EX a algunos | Solo esos quedan seleccionados |
| 7 | Guardar lote | `POST /asistencias/lote` 201, body solo `{sesionId, registros[{estudianteId, estado}]}` |
| 8 | Persistencia | `GET /grupos/{id}/asistencias?sesionId=` devuelve solo los guardados; el resto sigue «Sin registrar» |
| 9 | Cliente B recibe SSE | Evento `ASISTENCIAS_SESION_ACTUALIZADAS` con `payload {grupo, sesion, totalRegistros}` |
| 10 | Cliente B refresca | Nuevo `GET .../asistencias` HTTP tras el evento |
| 11 | Desconectar B (offline) | Estado `RECONNECTING`, sin sondeo |
| 12 | Reconectar red de B | Nuevo `GET /realtime/stream` inmediato; estado `CONNECTED`; refresco HTTP |
| 13 | A guarda otro cambio | B lo ve sin refresh manual |

## Negativos

| Caso | Esperado |
|---|---|
| Docente no titular | 403 `FORBIDDEN` |
| Estado inválido (p. ej. `A`) | 400 `VALIDATION_ERROR` |
| Sesión inexistente | 404 `RESOURCE_NOT_FOUND` |
| Sin Bearer | 401 `UNAUTHORIZED` |
| `nombre` de 51 caracteres | El frontend no llama al backend (mensaje local) |

Registrar `X-Correlation-Id` de cada request y el `correlationId` de cada error para el reporte.
