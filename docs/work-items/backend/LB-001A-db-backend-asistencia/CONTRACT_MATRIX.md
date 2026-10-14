---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# CONTRACT MATRIX — LB-001A

Formulario del [protocolo de alineación contractual](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md). Sin implementación. Registra únicamente evidencia ya aprobada; no fue re-ejecutada aquí.

## Evidencia

| Sistema | Fuente | Autoridad |
|---|---|---|
| DB | Cierre validado del repositorio DB (DB GATE) | OWNER; evidencia externa reportada por el responsable |
| Backend | Integration tests `SqlStoredProcedureContractIT`, `AsistenciaRepositorySqlServerIT` | CONSUMER; resultados reportados |

## Matriz

| ID | Capacidad | Provider contract (DB) | Backend expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| M-01 | Código de razón/causa | `uv_razon_causa` expone `codigo` | Lee `codigo` | MATCH | DB GATE; IT backend | Ninguno | — |
| M-02 | Detalle de asistencia | `uv_detalle_asistencia` expone `codigoRazonCausa` | Lee `codigoRazonCausa` | MATCH | DB GATE; IT backend | Ninguno | — |
| M-03 | Batch público | AN / SJC / EX | AN / SJC / EX | MATCH | DB GATE; IT backend | Ninguno | — |
| M-04 | Estado inválido | Error `RC_001` | Espera `RC_001` | MATCH | DB GATE; IT backend | Ninguno | — |
| M-05 | RazonCausa dinámica | No se crea dinámicamente | No la espera | MATCH | DB GATE; IT backend | Ninguno | — |
| M-06 | idUsuarioEjecutor | `Usuario.id`, requerido semánticamente | Envía `Usuario.id` | MATCH | DB GATE; IT backend | Ninguno | — |
| M-07 | Titularidad | Resuelve Usuario → Docente/Coordinador/Decano | Ídem | MATCH | DB GATE; IT backend | Ninguno | — |
| M-08 | Atomicidad | Preservada | Preservada | MATCH | DB GATE; IT backend | Ninguno | — |
| M-09 | Result set del SP | Preservado | Preservado | MATCH | DB GATE; IT backend | Ninguno | — |

## Error semantics

Contrato de errores **fuera de este contrato**: [TD-030](../../baseline/TECHNICAL_DEBT.md#td-030) — `VAL_003` posee semántica incorrecta para autorización/titularidad. No invalida la alineación de persistencia funcional, pero **bloquea el contrato de errores para LB-001C**.

## Transacción/atomicidad

M-08: MATCH. `@@TRANCOUNT=0` tras el gate.

## Decisiones requeridas

Ninguna para persistencia. Decisión pendiente para LB-001C: semántica de error de autorización/titularidad (TD-030).

## Bloqueos

Ninguno para persistencia. TD-030 bloquea únicamente el contrato de errores de LB-001C.

## Contrato congelado

**PERSISTENCE CONTRACT GOLDEN PATH: READY_FOR_FREEZE.**

Este estado no congela OpenAPI ni el contrato de errores; la aprobación del freeze corresponde a LB-001C.
