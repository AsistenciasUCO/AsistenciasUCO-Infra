---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-24
---

# TEST_PLAN — HU081 / HU082 / HU083

## DB (`test/test_usp_plan_estudio_estado_semestres.sql`, registrado en `test_suite.sql`)

| ID | Caso |
|---|---|
| T-081-01 | Inactivar, idempotencia y reactivar el plan propio; `uv_plan_estudio` refleja el estado |
| T-081-02 | Plan ajeno (`SEC_002`), ejecutor docente (`SEC_001`), plan inexistente (`PLA_002`), `@estaActivo` y ejecutor obligatorios |
| T-082-01 | Altas consecutivas desde un plan sin semestres (1 y 2) |
| T-082-02 | No supera el máximo del catálogo (`PLA_003`) |
| T-082-03 | Plan ajeno (`SEC_002`) y plan inexistente (`PLA_002`) |
| T-083-01 | Semestre intermedio (`PLA_005`), semestre ajeno al plan (`PLA_004`), semestre con asignatura inactiva (`PLA_006`) |
| T-083-02 | Quitar el último vacío, plan ajeno, número obligatorio y reponerlo agregando |

## Backend (JUnit)

- `GestionarPlanEstudioUseCaseImplTest`: toggle activo↔inactivo, plan fuera del programa (404 sin comando), comandos sin programa (403), delegación con el coordinador como ejecutor, número de semestre inválido (400).
- `CoordinadorPortalControllerTest`: los tres endpoints delegan con el actor autenticado; 409/404 se preservan.
- `PlanEstudioJpaRepositoryTest`: EXEC y parámetros de los tres SP, ejecutor obligatorio, `totalSemestres` por plan y sin consulta extra cuando no hay planes.
- `DbFailureClassifierPlanEstudioTest`: `PLA_*` → 404/409.

## Frontend (Karma)

- `coordinator-management.service.spec`: ruta `toggle-estado`, adaptación `normalizarPlanEstudio`.
- `study-plan-mesh-page.component.spec`: agregar/quitar semestre con los endpoints reales y rechazo 409 sin cambiar el plan.
- `mock-backend.interceptor.spec`: rutas mock alineadas.

## E2E local

Backend y frontend contra la DB local: activar/inactivar un plan, agregar y quitar semestres en la malla, rechazo al quitar un semestre con asignaturas.
