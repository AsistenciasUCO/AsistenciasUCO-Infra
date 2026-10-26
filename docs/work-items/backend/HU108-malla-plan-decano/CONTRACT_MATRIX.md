---
status: active
type: work-item
scope: backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# CONTRACT MATRIX — HU108-malla-plan-decano

Formulario del [protocolo de alineación contractual](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md). Sin implementación. Sin secretos.

## Evidencia

| Sistema | Repo/versión | Archivo/objeto | Hash/commit | Autoridad |
|---|---|---|---|---|
| Backend | AsistenciasUCO `feature/HU108-malla-plan-decano` | `ConsultarAsignaturasPlanUseCaseImpl` (existente), `DecanoPlanEstudioController` | `e7038ed` (PR #44) | OWNER |
| Frontend | AsistenciasUCO-Frontend `feature/HU108-malla-plan-decano` | `DeanFacultadService.getAsignaturasPlan`, `DeanPlanMallaComponent`, `DeanProgramasComponent` | `124203b` (PR #10) | CONSUMER |

## Matriz

| ID | Capacidad | Provider contract | Backend expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-108 | Malla del plan para el decano | `GET /api/v1/decano/planes-estudio/{id}/asignaturas` → `ApiListResponse<AsignaturaDTO>` | `normalizarAsignaturaPlan` (`credito`→`creditos`, `codigoSemestre`→`semestre`) | MATCH | `DecanoPlanEstudioControllerTest`, `dean-plan-malla.component.spec.ts` | — | — |
| C-108B | Ficha y lista de planes | `GET /api/v1/decano/estructura` (HU119) | `planesDeLaEstructura` | MATCH | `dean-programas.component.spec.ts` | — | — |

## Tipos y campos

| Campo | DB type/nullability | Java type/nullability | Semántica | Status |
|---|---|---|---|---|
| `credito` | INT | Integer | Créditos de la asignatura | MATCH |
| `codigoSemestre` | NVARCHAR | String | Semestre (`S1`..`S10`) | MATCH |

## Códigos/enums

NO APLICA: sin códigos nuevos.

## Error semantics

Plan de otra facultad → 403 (caso de uso existente); `planId` inválido → 400.

## Transacción/atomicidad

Solo lectura.

## Tiempo/UTC

NO APLICA: sin fechas.

## Decisiones requeridas

| ID mismatch | OWNER | CONSUMER | Opciones | Decisión / aprobador / referencia |
|---|---|---|---|---|
| NO APLICA | — | — | — | Sin SP nuevo: se reutiliza el caso de uso con ámbito ya probado (D1 del [PLAN](PLAN.md)). |

## Bloqueos

Ninguno.

## Contrato congelado

APPROVED (PR en verde, pendiente de merge)

Evidence of approval: checks remotos de backend #44 y frontend #10 en verde.
