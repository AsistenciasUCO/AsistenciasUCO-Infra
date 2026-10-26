---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# TEST_PLAN — HU104 / HU105 / HU109 / HU119 / HU145

## DB (`test/test_consultas_decano_facultad.sql`)

| ID | Caso |
|---|---|
| T-104-01 | El decano titular ve estudiantes solo de su facultad, sin repetidos; un decano ajeno y un usuario sin ámbito no ven nada. |
| T-105-01 | La búsqueda por documento encuentra al estudiante; la ficha incluye su matrícula; el decano ajeno no la ve. |
| T-119-01 | La estructura incluye el programa y su plan; el decano ajeno ve solo su facultad sin programas; sin ámbito, nada. |
| T-145-01 | El cronograma con rango de un día y programa devuelve la sesión y respeta los filtros; el decano ajeno no ve sesiones. |
| T-PAG-01 | Página 0 y tamaño 0 se rechazan con `PAG_001`. |

## Backend

| Clase | Cobertura |
|---|---|
| `ConsultarFacultadDecanoUseCaseImplTest` | valores por defecto, búsqueda normalizada y longitud, 403 sin facultad, paginación 400, ficha 400/404, rango de fechas, mapeo del interactor y armado del árbol. |
| `FacultadDecanoJpaRepositoryTest` | `EXEC` nombrado de los 4 SP con todos los parámetros, mapeo de totales y banderas, `PAG_001` ⇒ `ValidationException`, fallo técnico ⇒ `DatabaseOperationException`. |
| `DecanoFacultadConsultaControllerTest` | serialización de las 4 rutas, 403, 404 y 400. |
| `JpaRepositoryBeanUniquenessTest` | conteo de repositories +1. |

## Frontend

| Spec | Cobertura |
|---|---|
| `dean-estudiantes.component.spec.ts` | directorio, búsqueda, filtro de estado, paginación, errores, ficha. |
| `dean-estructura.component.spec.ts` | árbol, totales, plegado, facultad sin programas, sin datos, error. |
| `dean-cronograma.component.spec.ts` | listado, rango de fechas, rango invertido, paginación, error y simulación mock de las 4 consultas. |
