---
status: active
type: work-item
scope: backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# TEST_PLAN — HU108 (parte de planes)

## Backend

| Clase | Cobertura |
|---|---|
| `DecanoPlanEstudioControllerTest` | T-108-01 malla del plan con el actor autenticado; T-108-02 plan de otra facultad ⇒ 403; T-108-03 id inválido ⇒ 400; dependencias nulas. |
| `ConsultarAsignaturasPlanUseCaseImplTest` (existente) | decano con plan de su facultad, plan de otra facultad ⇒ 403, plan sin asignaturas, usuario sin ámbito. |

## Frontend

| Spec | Cobertura |
|---|---|
| `dean-plan-malla.component.spec.ts` | ficha desde la estructura y malla desde el endpoint del decano (sin rutas del coordinador), créditos calculados, filtros por semestre y texto, 403 con mensaje, error de estructura, sin plan en la ruta. |
| `dean-programas.component.spec.ts` | planes desde la estructura (INP, programa, vigencia), navegación a la malla, error de estructura ⇒ lista vacía. |
| `dean-cronograma.component.spec.ts` | simulación mock de la malla del decano. |
