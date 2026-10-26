---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# TEST_PLAN — HU064 / HU060 / HU061

## DB (`test/test_consultas_coordinador_programa.sql`)

| ID | Caso |
|---|---|
| T-064-01 | El coordinador titular ve el grupo de su programa y solo grupos de su programa; un coordinador de otro programa no lo ve. |
| T-060-01 | El titular ve las sesiones del grupo; el coordinador ajeno recibe lista vacía. |
| T-061-01 | El titular ve el detalle de asistencia de la sesión (si la sesión tiene asistencias); el ajeno no ve nada. |

## Backend

| Clase | Cobertura |
|---|---|
| `ConsultarAsistenciaProgramaUseCaseImplTest` | valores por defecto, búsqueda normalizada, 403 sin programa, paginación 400, rango de fechas, grupo/sesión obligatorios, filtro `asistio`, mapeo del interactor. |
| `AsistenciaProgramaJpaRepositoryTest` | `EXEC` nombrado con todos los parámetros, mapeo de `totalRegistros`, lista vacía ⇒ total 0, `PAG_001` ⇒ `ValidationException`, fallo técnico ⇒ `DatabaseOperationException`. |
| `CoordinadorAsistenciaProgramaControllerTest` | serialización de las 3 rutas, filtros, 403 y 400. |
| `JpaRepositoryBeanUniquenessTest` | conteo de repositories +1. |

## Frontend

| Spec | Cobertura |
|---|---|
| `coordinator-attendance.component.spec.ts` | carga inicial, filtros período/búsqueda, paginación, errores, navegación grupo → sesiones → detalle, rango invertido, filtro asistió, simulación mock. |
