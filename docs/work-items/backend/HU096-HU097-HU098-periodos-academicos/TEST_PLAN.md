---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# TEST_PLAN — HU096 / HU097 / HU098

## DB (`test/test_usp_periodo_academico_gestion.sql`, registrado en `test_suite.sql`)

| ID | Caso |
|---|---|
| T-096-01 | El administrador crea un período: institución, nombre recortado, `codigo` 20901 y `anio` 2090; visible en `uv_periodo_academico` |
| T-096-02 | Segundo semestre: `codigo` terminado en 2 |
| T-096-03 | Id nulo, nombre duplicado sin distinguir mayúsculas (`PER_003`), fechas invertidas (`PER_002`), COORDINADOR/DECANO/DOCENTE `SEC_001`, admin de institución inactiva `PER_005`, ejecutor nulo; ningún rechazo crea |
| T-097-01 | El administrador modifica; recalcula `codigo` y `anio`; conservar el mismo nombre está permitido |
| T-097-02 | Inexistente `PER_001`, nombre de otro período `PER_003`, fechas iguales `PER_002`, COORDINADOR rechazado; ningún rechazo modifica |
| T-098-01 | Período con grupos `PER_004` (se conserva), DECANO rechazado, el administrador elimina uno sin grupos, eliminar de nuevo `PER_001` |

## Backend (JUnit)

- `GestionarPeriodoAcademicoUseCaseImplTest`: id generado, nombre recortado, validaciones de nombre y fechas sin llamar a la DB, actualizar/eliminar exigen id, interactor.
- `AdminPeriodoAcademicoControllerTest`: mapeo de cuerpo/ruta/actor, 409 al eliminar, 400 sin cuerpo.
- `PeriodoAcademicoCommandJpaRepositoryTest`: EXEC y parámetros de los tres SP, ejecutor obligatorio.
- `DbFailureClassifierPeriodoAcademicoTest`: `PER_*` → 404/400/409/403.
- `RbacSecurityFilterChainTest`: POST/PUT/DELETE en `/api/v1/admin/periodos-academicos` permitidos solo a ADMINISTRADOR; 403 a DECANO, COORDINADOR, DOCENTE y ESTUDIANTE; 401 sin token.
- `JpaRepositoryBeanUniquenessTest`: conteo de repositories productivos +1 (`PeriodoAcademicoCommandJpaRepository`).

## Frontend (Karma)

- `admin-periodos.component.spec`: carga, crear y modificar por `/admin/periodos-academicos`, error al guardar, eliminar con confirmación/cancelación/rechazo 409.
- `coordinator-management.service.spec`: adaptación del período del backend, estado por fechas, `DELETE` del administrador.
- `coordinator-periods.component.spec`: consulta (solo lectura).
- `mock-backend.interceptor.spec`: rutas mock del administrador.
