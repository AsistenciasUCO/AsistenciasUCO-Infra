---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# CLOSURE — HU104-HU105-HU109-HU119-HU145-lecturas-decano: Consultas del decano sobre su facultad

## Resultado

**PENDIENTE.** Integrado en `develop` con CI remoto en verde y validación local completa; falta MV-008. Evidencia: [VALIDATION](VALIDATION.md).

## Alcance entregado y decisiones

Directorio y ficha de estudiantes, estructura Facultad → Programa → Plan y cronograma de sesiones, solo lectura y aislados por facultad.

## Deuda

Sin TD nuevas. Ninguna desviación del contrato queda abierta como deuda.

## Validación manual

[MV-008](../../baseline/MANUAL_VALIDATION_LEDGER.md) PENDIENTE.

## ADR relacionados

NO APLICA: las decisiones de alcance (D1..Dn) quedan en [PLAN](PLAN.md) y no cambian una decisión arquitectónica duradera.

## Elementos pendientes y bloqueos

MV-008. La sesión no modela sede, por lo que HU145 no la muestra.

## Cambios fuera de alcance

Ninguno. `SecurityConfig` sin cambios.

## Condición de parada

No iniciar automáticamente la siguiente fase.
