---
status: active
type: active
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# Work items versionables

Convención: `LB-XXX-descripcion/`, con `PLAN.md`, `TEST_PLAN.md`, `VALIDATION.md`, `CLOSURE.md`. Se puede descomponer una fase en tareas acotadas dentro de su plan, conservando ID de fase y trazabilidad. No crear carpetas vacías.

- Copiar las [plantillas](../../.claude/templates/PLAN.md) y resolver campos con evidencia o NO APLICA justificado. Todo PLAN declara clase de cambio, rutas permitidas/prohibidas y variable principal. Para comparar contratos entre repositorios usar [CONTRACT_MATRIX](../../.claude/templates/CONTRACT_MATRIX.md).
- PLAN guarda AS-IS/TARGET, alcance, fuentes, consumidores, riesgos, rollback y resultado de [DoR](../governance/DEFINITION_OF_READY.md).
- TEST_PLAN fija conducta esperada y RED antes de implementación; registra archivos/hash o commit de los tests aprobados mediante la sección `RED_SNAPSHOT` ([estándar](../testing/TESTING_STANDARD.md#red_snapshot)).
- VALIDATION conserva comandos, resultados, cobertura, skips, dictamen y bloqueos. No versionar logs crudos/secretos.
- CLOSURE vincula [DoD](../baseline/DEFINITION_OF_DONE.md), deuda y manuales; no marca DONE si falla un gate aplicable.

`.workspace/plans`/`.workspace/validation` no son la fuente oficial. Si aparecen, trasladar solo evidencia útil y sanitizada; no copiar estado local ni worktrees.

Los work items activos se determinan desde [LINEA_BASE.md](../baseline/LINEA_BASE.md). La carpeta conserva trabajo activo y cerrado.

Ejemplo de work item técnico cerrado: [TECH-001](TECH-001-restaurar-gate-arquitectura/CLOSURE.md).
