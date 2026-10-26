---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# CONTRACT MATRIX — HU081-HU082-HU083-plan-estudio-estado-semestres

Formulario del [protocolo de alineación contractual](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md). Sin implementación. Sin secretos.

## Evidencia

| Sistema | Repo/versión | Archivo/objeto | Hash/commit | Autoridad |
|---|---|---|---|---|
| DB | gestion-asistencia-db `develop` | `usp_cambiar_estado_plan_estudio`, `usp_agregar_semestre_plan_estudio`, `usp_quitar_semestre_plan_estudio`, `uv_plan_estudio` | PR #46 (merge `f8c1554`) | OWNER |
| Backend | AsistenciasUCO `develop` | `PlanEstudioJpaRepository`, `CoordinadorPortalController` | PR #41/#42 (merge `758d555`) | CONSUMER |

## Matriz

| ID | Capacidad | Provider contract | Backend expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-081 | Activar/inactivar plan | EXEC con `@idPlanEstudio`, `@estaActivo`, `@idCorrelacion`, `@idUsuarioEjecutor`; resultset canónico de 4 columnas | `PATCH .../planes-estudio/{id}/toggle-estado` calcula el estado opuesto y ejecuta el SP | MATCH | T-081-01/02 + tests de repository y caso de uso | — | — |
| C-082 | Añadir semestre | EXEC con `@idPlanEstudio` | `POST .../planes-estudio/{id}/semestres` | MATCH | T-082-01..03 | — | — |
| C-083 | Quitar semestre | EXEC con `@idPlanEstudio`, `@numeroSemestre` | `DELETE .../planes-estudio/{id}/semestres/{numero}` | MATCH | T-083-01/02 | — | — |
| C-08X | Total de semestres del plan | `uv_semestre_plan_estudio` | HQL de conteo `totalSemestres` en la consulta de planes | MATCH | tests de consulta de planes | — | — |

## Tipos y campos

| Campo | DB type/nullability | Java type/nullability | Semántica | Status |
|---|---|---|---|---|
| `idPlanEstudio` | UNIQUEIDENTIFIER NOT NULL | UUID no nulo | Plan a modificar | MATCH |
| `numeroSemestre` | INT NOT NULL | Integer no nulo | Semestre a quitar (el último) | MATCH |
| `estadoResultado` | BIT | boolean | 1 éxito / 0 rechazo | MATCH |

## Códigos/enums

`PLA_002`..`PLA_006` (`schema/seed/17_mensajes_plan_estudio.sql`); `SEC_001`/`SEC_002` (RBAC y titularidad).

## Error semantics

`DbFailureClassifier`: `PLA_002` → 404; `PLA_003`..`PLA_006` → 409; `SEC_*` → 403.

## Transacción/atomicidad

Cada SP abre transacción propia o savepoint y bloquea la fila del plan; el backend no anida transacciones.

## Tiempo/UTC

NO APLICA: el contrato no tiene fechas.

## Decisiones requeridas

| ID mismatch | OWNER | CONSUMER | Opciones | Decisión / aprobador / referencia |
|---|---|---|---|---|
| NO APLICA | — | — | — | Sin mismatches abiertos. |

## Bloqueos

Ninguno.

## Contrato congelado

APPROVED

Evidence of approval: PR integrados en `develop` con CI remoto en verde; [VALIDATION](VALIDATION.md).
