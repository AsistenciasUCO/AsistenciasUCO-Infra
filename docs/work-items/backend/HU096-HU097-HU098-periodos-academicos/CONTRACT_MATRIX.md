---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# CONTRACT MATRIX — HU096-HU097-HU098-periodos-academicos

Formulario del [protocolo de alineación contractual](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md). Sin implementación. Sin secretos.

## Evidencia

| Sistema | Repo/versión | Archivo/objeto | Hash/commit | Autoridad |
|---|---|---|---|---|
| DB | gestion-asistencia-db `develop` | `usp_crear_periodo_academico`, `usp_actualizar_periodo_academico`, `usp_eliminar_periodo_academico`, `usp_resolver_institucion_gestor_periodo_interno` | PR #44 (merge `b935f28`) | OWNER |
| Backend | AsistenciasUCO `develop` | `PeriodoAcademicoCommandJpaRepository`, `AdminPeriodoAcademicoController` | PR #41 (merge `758d555`) | CONSUMER |

## Matriz

| ID | Capacidad | Provider contract | Backend expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-096 | Crear período | EXEC con id, `@nombre`, `@fechaInicio`, `@fechaFin`, correlación y ejecutor; 4 columnas | `POST /api/v1/admin/periodos-academicos` | MATCH | T-096-01..03 | — | — |
| C-097 | Modificar período | EXEC con id, nombre y fechas | `PUT /api/v1/admin/periodos-academicos/{id}` | MATCH | T-097-01/02 | — | — |
| C-098 | Eliminar período sin grupos | EXEC con id | `DELETE /api/v1/admin/periodos-academicos/{id}` | MATCH | T-098-01 | — | — |

## Tipos y campos

| Campo | DB type/nullability | Java type/nullability | Semántica | Status |
|---|---|---|---|---|
| `fechaInicio` / `fechaFin` | DATE NOT NULL | LocalDate no nulo | `fechaInicio < fechaFin` | MATCH |
| `nombre` | NVARCHAR NOT NULL | String no vacío | Único por institución | MATCH |
| `codigo` / `anio` | derivados en el SP | no se envían | 2026-2 ⇒ 20262 | MATCH |

## Códigos/enums

`PER_001`..`PER_006` (`schema/seed/17_mensajes_periodo_academico.sql`).

## Error semantics

`DbFailureClassifier`: `PER_001` → 404; `PER_002` → 400; `PER_003`, `PER_004` → 409; `PER_005` → 403.

## Transacción/atomicidad

Transacción propia o savepoint por SP; eliminar verifica la ausencia de grupos dentro de la misma transacción.

## Tiempo/UTC

Fechas de calendario (DATE) sin hora: no aplica conversión UTC.

## Decisiones requeridas

| ID mismatch | OWNER | CONSUMER | Opciones | Decisión / aprobador / referencia |
|---|---|---|---|---|
| NO APLICA | — | — | — | Sin mismatches abiertos. Decisión de producto (solo ADMINISTRADOR; HU098 = eliminar) en [PLAN](PLAN.md). |

## Bloqueos

Ninguno.

## Contrato congelado

APPROVED

Evidence of approval: PR integrados en `develop` con CI remoto en verde; [VALIDATION](VALIDATION.md).
