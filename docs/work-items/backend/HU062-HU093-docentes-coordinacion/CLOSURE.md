---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# CLOSURE — HU062 / HU063 / HU089 / HU090 / HU091 / HU092 / HU093

**Estado:** implementado y verificado en ramas `feature/HU062-HU093-docentes-coordinacion` (worktrees `db-docentes`, `backend-docentes`, `frontend-docentes`). **Sin push ni PR.** Pendiente de aprobación del owner para integrar.

## Entregado
| HU | Capacidad |
|---|---|
| HU062 / HU089 | Directorio paginado de docentes del programa (incluye docentes sin grupos) |
| HU063 | Búsqueda por prefijo de cédula o nombre, en servidor, con debounce en cliente |
| HU090 | Catálogo `TipoVinculacion` (PLA/MTI/CAT/OCA) y `GET /tipos-vinculacion` |
| HU091 | Vincular docente (nuevo con contraseña inicial asignada, o existente por candidatos) con aprovisionamiento Keycloak tras confirmar en DB |
| HU092 | Editar tipo de vinculación y nombres |
| HU093 | Activar/inactivar el vínculo con el programa (sin tocar persona, grupos ni cuenta) |

## Evidencia
Ver [VALIDATION.md](VALIDATION.md). Resumen final: DB 36/37 archivos de `test_suite.sql` en verde (el restante, `test_lb004d_support_binding`, requiere un fixture LB004D preexistente); Backend `mvnw verify` 1754 tests y cobertura del código nuevo 96,7 % líneas / 82,1 % ramas; Frontend `npm run verify` 860 specs; `infra.ps1 verify` PASS; E2E con JWT real de HU091, HU092 y HU093.

## Pendiente (fuera de este cierre)
1. ~~**D6**~~ **Hecho (2026-10-22):** retirados `POST /docentes` y `POST /docentes/asignaciones/grupo` (siempre 501) con sus features, DTO, validators, wiring y tests (Backend, 1745 tests PASS), y `TeacherService.assignTeacherToGroup` (Frontend, 859 specs PASS). Commits aislados `refactor(backend/controller)` y `refactor(frontend/docente)`. Quedan respondiendo 404 (ruta inexistente). Pendiente de re-ejecutar `mvnw verify` e `infra.ps1 verify` antes de integrar.
2. **Infra:** actualizar `HU-CATALOG.md` (HU062, HU063, HU089–HU093) y el espejo de work items cuando el owner apruebe.
3. **IAM-001:** sincronizar nombres/correo con Keycloak y reconciliación formal (TD-015).
4. `GET /api/v1/docentes` sin ámbito institucional (TD nueva).
5. Cuentas de prueba del E2E en el Keycloak compartido: `e2e.hu091*`, `e2e.hu092*`, `e2e.hu093*` (retirar a mano).
