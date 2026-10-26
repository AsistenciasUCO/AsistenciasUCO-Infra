---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# VALIDATION — HU062 / HU063 / HU089 / HU090 / HU091 (tanda 1)

Alcance validado: directorio paginado, búsqueda, catálogo de vinculación y vinculación de docentes (persona nueva o existente) con aprovisionamiento Keycloak. **HU092 y HU093 siguen pendientes** (tandas 2 y 3). Ramas `feature/HU062-HU093-docentes-coordinacion` en los worktrees `db-docentes`, `backend-docentes` y `frontend-docentes`. Sin push.

## Evidencia por capa

| Capa | Comando | Resultado |
|---|---|---|
| DB | `test_migracion_docente_programa`, `test_usp_vincular_docente_programa`, `test_usp_consultar_docentes_programa`, `test_usp_consultar_candidatos_docente_programa` (SQL Server 2022 propio, puerto 14331) | PASS |
| DB | `test_docente_programa_concurrencia.ps1` (T-091-13) | PASS (uno OK, uno DOC_006) |
| DB | `test_contract_closure`, `test_public_objects`, `test_authorized_views_rbac`, `test_usp_crear_coordinador`, `test_usp_crear_actualizar_grupo`, `test_transaction_ownership`, `test_titularidad_jerarquica`, `test_usp_sincronizar_usuario`, `test_reactive_academic` | PASS |
| DB | `test_suite.sql` completo | **No ejecutado de punta a punta**: se detiene en `test_lb004d_support_binding` por fixture LB004D no sembrado en el contenedor de pruebas (preexistente, ajeno a esta HU) |
| Backend | `.\mvnw.cmd -o test` | 1714 tests; 1 fallo (`JpaRepositoryBeanUniquenessTest`, inventario 32→34) corregido; re-ejecutado el test: PASS |
| Backend | `.\mvnw.cmd -o verify` | BUILD SUCCESS, `All coverage checks have been met` |
| Backend | JaCoCo del código nuevo (use cases, controllers, validator, adapter, mapper, wiring) | líneas 95,3 %, ramas 80,2 % |
| Backend | E2E `scratch/test_hu091.ps1` con JWT real (Keycloak 8081, backend en 18081, SQL 14331) | PASS (15 comprobaciones) |
| Frontend | `npm run verify` (test:ci + coverage:realtime:check + build producción) | 840 specs PASS; realtime 95,06 % líneas / 84,52 % ramas |
| Frontend | Cobertura del código nuevo (componente, modal, servicio) | líneas ≈ 89 %, ramas ≈ 73 % |
| Infra | `.\infra.ps1 verify` y `verify-contracts.ps1` contra los tres worktrees | PASS (18 comprobaciones WORM y paridad) |

## Resultado del E2E (extracto)
Catálogo de tipos (≥ 4) · `GET /coordinador/docentes` 200 (antes 501) · alta nueva 201 con CAT y 0 grupos · el docente nuevo inicia sesión en Keycloak con la contraseña asignada y su token trae el rol `DOCENTE` · reintento del alta idempotente (201) · vincular dos veces 409 · búsqueda por cédula y por nombre · candidatos con 2 caracteres 400 · alta sin modo 400 · decano 403 · `sqlcmd` confirma un solo vínculo.

## Efectos secundarios del E2E
Se crearon en el Keycloak compartido las cuentas `e2e.hu091.docente@uco.edu.co` y `e2e.hu091b@uco.edu.co` (DOCENTE) y sus filas en la DB de pruebas `sql_docentes`. No hay operación de desactivación hasta IAM-001: retirarlas manualmente.

## Cambios de prueba por cambio formal (no relajaciones)
- `CoordinadorPortalControllerTest`: se quitan las referencias a `consultarDocentesPrograma`/`crearDocente` (ahora reales en `CoordinadorDocentesController`).
- `JpaRepositoryBeanUniquenessTest`: inventario 32 → 34 repositories.
- DB: transacción externa con `XACT_ABORT ON` queda condenada y el SP la propaga (patrón de ownership); la paginación se normaliza como `usp_consultar_grupos_paginado` (no existe `PAG_001`).
- Frontend: specs de docentes reemplazados por el nuevo diseño; el 409 usa el código de feature `ERR_DOCENTE_YA_VINCULADO_PROGRAMA` (el cliente solo muestra el mensaje del backend para códigos de feature).

## Pendiente y deuda
- **D6 diferido:** retirar `POST /docentes` y `POST /docentes/asignaciones/grupo` (siempre 501). Toca ~45 archivos (features `docente`, `DocenteController`, `DocenteWiringConfiguration` caliente, ports, DTO y tests). El frontend aún declara `TeacherService.assignTeacherToGroup` (sin llamadores). Recomendado como tarea propia al final, coordinada con las otras pistas.
- `GET /api/v1/docentes` sin ámbito institucional (TD nueva, ver PLAN §13).
- TD-015: si Keycloak falla después del commit, el vínculo queda sin cuenta; reintento idempotente (D14). Reconciliación formal en IAM-001.
- Cierre documental en Infra (`HU-CATALOG.md`) y `CLOSURE.md`: al terminar HU092/HU093.

## Tanda 2 — HU092 (editar tipo de vinculación y nombres)

| Capa | Evidencia | Resultado |
|---|---|---|
| DB | `test_usp_actualizar_docente_programa` (T-092-01..05); `test_contract_closure`, `test_public_objects`, `test_usp_vincular_docente_programa` tras el cambio | PASS |
| Backend | `Actualizar*Test`, `CoordinadorDocentesControllerTest` (13), `DocenteProgramaJpaRepositoryTest`, `DocenteProgramaWiringConfigurationTest`, `RbacSecurityFilterChainTest` (44), ArchUnit | 136 tests PASS |
| Frontend | `ng test` completo | 853 specs PASS |
| E2E | `scratch/test_hu092.ps1` con JWT real: PUT 200 con releída de DB, correo/documento intactos, `sqlcmd` confirma nombres, el docente sigue iniciando sesión, `{}` 400, tipo inexistente 400 `ERR_TIPO_VINCULACION_INVALIDO`, sin vínculo 404, decano 403 | PASS (10 comprobaciones) |

Notas: los nombres editados **no** se propagan a Keycloak (D11; deuda hasta IAM-001). El E2E creó la cuenta `e2e.hu092.docente@uco.edu.co` en el Keycloak compartido (retirar manualmente). La suite completa de backend, `mvnw verify`, `npm run verify` e `infra.ps1 verify` se re-ejecutan en el cierre final tras HU093.

## Tanda 3 — HU093 y cierre final (2026-10-22)

| Capa | Evidencia | Resultado |
|---|---|---|
| DB | `test_usp_cambiar_estado_docente_programa` (T-093-01..04 y regla D12 en grupos) y 36/37 archivos de `test_suite.sql` ejecutados uno a uno + concurrencia T-091-13 | PASS (el restante, `test_lb004d_support_binding`, exige fixture LB004D preexistente) |
| Backend | `.\mvnw.cmd -o verify` completo | 1754 tests PASS, `All coverage checks have been met` |
| Backend | JaCoCo del código nuevo (HU091–HU093) | líneas 96,7 %, ramas 82,1 % |
| Frontend | `npm run verify` | 860 specs PASS; realtime 95,06 % / 84,52 %; build de producción OK |
| Frontend | Cobertura del código nuevo (componente, modales, servicio) | líneas ≈ 90,8 %, ramas ≈ 74,1 % |
| Infra | `infra.ps1 verify` y `verify-contracts.ps1` sobre los tres worktrees | PASS (18 comprobaciones) |
| E2E | `scratch/test_hu093.ps1` (10 comprobaciones) + regresión de `test_hu091.ps1` y `test_hu092.ps1` con JWT real | PASS |

Hallazgo del E2E de HU093: tras inactivar el vínculo, `Usuario.estado` sigue en 1, el docente sigue iniciando sesión en Keycloak y el filtro `estaActivo=false` lo lista.

Limitación declarada: en el frontend los specs de HU092 y HU093 se escribieron junto con el código y se separaron en commits después, sin observar su fallo previo; en DB y Backend el RED se observó fallando.
