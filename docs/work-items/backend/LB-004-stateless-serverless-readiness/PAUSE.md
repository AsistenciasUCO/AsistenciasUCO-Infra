# PAUSE — LB-004 Stateless / Serverless readiness

- Fecha: 2026-10-03
- Rama: `jose-valencia/lb-004-stateless-serverless-readiness`
- HEAD base observado: `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d`
- Autoridad de la pausa: decisión humana nueva (migración JPA-only, reunión con el profesor), registrada en [LB-008](../LB-008-jpa-only-persistence-migration/PLAN.md).

```text
STATE: PAUSED / FROZEN_BY_JPA_MIGRATION
REASON: nueva prioridad humana — migración completa JDBC → JPA
LAST_VALIDATED_STATE: LB-004B.2H
STORAGE_FOUNDATION: GREEN
REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT
FULL_E2E: PENDING
RESUME_CONDITION: cierre de la migración JPA-only o decisión humana explícita
```

## Qué significa la pausa

- **No es una reversión.** LB-004 no se revierte ni se marca `DONE`.
- **No se cierran sus deudas.** TD-004 permanece `PARTIAL` tal como está; no se añaden cierres nuevos.
- **Se conserva íntegramente** (sin modificar durante LB-008):
  - MinIO y ClamAV (`infrastructure/adapter/secondary/storage/minio`, `…/malwarescan/clamav`, configuración asociada).
  - `FileStoragePort` y la storage foundation (`application/secondaryports/storage`, `…/malwarescan`).
  - Seguridad de archivos y ownership técnico del estudiante propietario.
  - Contratos ya congelados de `fileId`, documentación y decisiones de LB-004 (`PLAN.md`, `DECISIONS.md`, `PROFESSOR_DECISION.md`, `LB-004B.2-VALIDATION.md`).
  - Tests asociados (unit, ArchUnit e integración MinIO/ClamAV).
- **Pendiente congelado:** `REVIEW_BINDING` (`fileId → revisión → sesión → grupo → docente`) sigue `BLOCKED_BY_DB_CONTRACT` (`DR-LB004-DB-002`). `FULL_E2E` sigue `PENDING`.

## Cambios de trabajo en curso (no se mezclan con JPA)

El árbol de trabajo contiene cambios sin consolidar de LB-004 (`git status --short`, 33 entradas al inicio de LB-008). Ninguno se commitea, descarta ni limpia como parte de la migración JPA. Su revisión y consolidación quedan para el momento de reanudar LB-004.

## Condición de reanudación

Solo cuando ocurra una de estas:

1. Cierre de la migración JPA-only (LB-008 `CLOSURE.md` con `DIRECT_JDBC_IN_SRC_MAIN = 0`).
2. Decisión humana explícita registrada en el work item.

Hasta entonces, LB-004 no puede implementarse ni validarse de extremo a extremo.
