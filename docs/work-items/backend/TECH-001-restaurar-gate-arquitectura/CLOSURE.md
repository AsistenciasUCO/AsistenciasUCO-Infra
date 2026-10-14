---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# CLOSURE — TECH-001

## Resultado

**DONE**, con revisión humana **APROBADA** (2026-09-20). Ver [VALIDATION](VALIDATION.md): `mvn verify` BUILD SUCCESS, ArchUnit PASS, JaCoCo dentro de los gates.

## Revisión humana

**HUMAN REVIEW: APPROVED.** El responsable humano confirma: arquitectura correcta; ArchUnit no debilitado; build reportado verde; alcance respetado; se autoriza el cierre de TECH-001. Este registro no añade evidencia técnica nueva.

TECH-001 precede la política [RED_SNAPSHOT](../../testing/TESTING_STANDARD.md#red_snapshot): posee evidencia RED documental (ver [TEST_PLAN](TEST_PLAN.md)), pero no snapshot criptográfico (SHA-256/commit del estado RED). No se altera retroactivamente.

| Elemento | Estado |
|---|---|
| TD-029 | CLOSED |
| CF-002 | RESOLVED |
| TECHNICAL_BUILD_GATE | PASS |
| ME-001 | CLOSED (ver abajo) |

## Alcance entregado y decisiones

`GlobalExceptionHandler` depende solo de `ResolverMensajeUsuarioInputPort` (`Optional<String> execute(String)`), implementado por `ResolverMensajeUsuarioInteractor` → `ResolverMensajeUsuarioUseCaseImpl` → `MessageCatalogPort`; wiring explícito en `CatalogoWiringConfiguration`, independiente del provider. Constructor único, sin constructor vacío ni Service Locator. Ver [PLAN](PLAN.md) (incluye `APPROVED_EXCEPTION`).

## Evidencia DB ↔ backend del Golden Path (certificada externamente)

Reportada por el responsable humano; no ejecutada ni reproducida en esta tarea:

- DB GATE: 76 PASS, 0 FAIL, 1 SKIP autorizado; CRITICAL_MISSING=0; SQL_ERROR_COUNT=0; @@TRANCOUNT=0.
- Backend integración: `SqlStoredProcedureContractIT` 20/20; `AsistenciaRepositorySqlServerIT` 6/6 (repository IT del adapter SQL Server).

ME-001 (ausencia de evidencia DB del Golden Path) queda CLOSED en [LINEA_BASE](../../baseline/LINEA_BASE.md). El historial de [FINDINGS](../LB-000-gobernanza-documentacion/FINDINGS.md) de LB-000 no se modifica.

## Deuda

- TD-029: CLOSED.
- TD-030 (nueva): `VAL_003` usado para fallos de autorización/titularidad en SPs internos; abierta hasta el contrato de errores previo al freeze OpenAPI.
- TD-027: sin cambios.

## Validación manual

Ninguna nueva.

## ADR relacionados

Ninguno (aplicación de la decisión vigente Primary Adapter → Input Port).

## Elementos pendientes y bloqueos

Ninguno de revisión (aprobada). Observar en Azure (TD-027) que el catálogo, ahora realmente consultado por el handler, no altera respuestas esperadas.

## Cambios fuera de alcance

Ninguno. DB, frontend, OpenAPI, JPA, adapter SQL, SP contracts, realtime y seguridad no modificados.

## Condición de parada

No iniciar LB-001B ni ninguna fase siguiente sin aprobación humana.
