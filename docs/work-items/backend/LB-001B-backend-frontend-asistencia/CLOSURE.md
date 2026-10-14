# CLOSURE — LB-001B: alineación contractual backend ↔ frontend del Golden Path de asistencia

## Resultado

**ANALYSIS COMPLETE / HTTP-FRONTEND CONTRACT NOT FROZEN.** `CONTRACT_STATUS = NOT_READY_FOR_LB001C`.

Es un cierre válido de `CONTRACT_ANALYSIS`: el contrato **no** está alineado (`ALIGNED` requiere cero `MISMATCH`/`DECISION_REQUIRED` sin resolver) y no se congela. Validación: [VALIDATION](VALIDATION.md) (`PASS` del análisis, con las limitaciones allí listadas). `HUMAN_APPROVAL = APPROVED` para ejecutar el análisis ([PLAN](PLAN.md)); **no** hay aprobación de contrato ni de decisiones.

## Alcance entregado y decisiones

- Inventario del Golden Path desde código: 6 endpoints (E-01…E-06) y sus dimensiones, en [CONTRACT_MATRIX](CONTRACT_MATRIX.md) (16 capacidades C-001…C-016; 92 filas con un único estado cada una, más C-015 y C-016 como secciones descriptivas NOT_APPLICABLE).
- Resultado por estado (conteo de las 92 filas): **MATCH** 47 (wrappers, DTOs, batch, envelope de error, SSE, payload, correlation, Bearer); **MISMATCH** 5 (`date/startTime/endTime` del consumer ×3, roles de la ruta, orden de interceptores en 401); **MISSING_IN_PROVIDER** 8 (estado de sesión, `topic`, `room`, `tipo`, `docenteName`, causa de excusa, campos legacy); **MISSING_IN_CONSUMER** 12 (campos y señales no usados, p. ej. `correlationId`, `code`, `totalRegistros`, estado realtime); **DECISION_REQUIRED** 6; **BLOCKED_BY_MISSING_EVIDENCE** 10; **NOT_APPLICABLE** 4 (+ C-015, C-016).
- Hallazgos de mayor impacto: (1) ausencia de registro ⇒ el consumer asigna `AN` y lo persiste al guardar (DR-002); (2) el estado de sesión no existe en el provider y el consumer lo fuerza a `PROGRAMADA`, por lo que sus protecciones nunca actúan (DR-001); (3) `estado` en lectura es `codigoRazonCausa` sin filtrar mientras TS lo restringe a 3 valores (DR-006); (4) los mocks ocultan los mismatches de sesión (C-015).
- **Decisiones pendientes** (todas `PENDING`, sin aprobar): DR-001 estado de sesión · DR-002 ausencia de registro · DR-003 temporalidad · DR-004 campos de presentación · DR-005 causa de excusa · DR-006 dominio de `estado` en lectura · DR-007 elegibilidad de estudiantes · DR-008 roles de la pantalla · DR-009 errores de autorización (TD-030) · DR-010 listado/paginación. Detalle con opciones e impacto en la matriz.
- Realtime: documentado extremo a extremo (transporte, envelope, payload, heartbeat, reconexión, HTTP como source of truth). Sin `MISMATCH` de forma; el comportamiento runtime queda en B-04.
- Provider y consumer no se modificaron; no se decidió quién corrige cada diferencia.

## Deuda

| TD | Estado | Acción en este work item |
|---|---|---|
| [TD-030](../../baseline/TECHNICAL_DEBT.md#td-030) | ABIERTA | Registrada como DR-009; **bloquea el freeze completo del contrato de errores en LB-001C**; no resuelta |
| [TD-017](../../baseline/TECHNICAL_DEBT.md#td-017) | ABIERTA | Reconciliada: hay evidencia estática del consumer; E2E pendiente (MV-001) |
| [TD-005](../../baseline/TECHNICAL_DEBT.md#td-005) | ABIERTA | Referenciada desde DR-003; timezone **no** resuelto |
| [TD-009](../../baseline/TECHNICAL_DEBT.md#td-009) | ABIERTA | Referenciada desde DR-006 (lado lectura) |
| TD-002, TD-003, TD-006, TD-011, TD-016, TD-021 | ABIERTAS | Citadas como contexto; sin cambios |
| [TD-031](../../baseline/TECHNICAL_DEBT.md#td-031) | PENDIENTE DE VALIDACIÓN (nueva) | Orden de interceptores frontend en 401 (inferido estáticamente) |
| [TD-032](../../baseline/TECHNICAL_DEBT.md#td-032) | ABIERTA (nueva) | `SECURITY_FINDING`: credencial por defecto en el frontend (valor no reproducido) |
| [TD-033](../../baseline/TECHNICAL_DEBT.md#td-033) | ABIERTA (nueva) | Errores de sesiones/realtime no visibles en el frontend |

Las decisiones contractuales (DR-*) **no** se convirtieron en TD.

## Validación manual

[MV-001](../../baseline/MANUAL_VALIDATION_LEDGER.md) (Golden Path frontend + Keycloak + SQL Server + SSE) sigue **pendiente**: no hubo E2E con `USE_MOCKS=false`. B-04 depende de ella.

## ADR relacionados

Ninguno nuevo. Las decisiones DR-* podrán requerir ADR en LB-001C (p. ej. DR-001, DR-002) si cambian el contrato.

## Elementos pendientes y bloqueos

- `BLOCKED_BY_MISSING_EVIDENCE`: B-01 (semántica SP: re-guardado, unicidad, estado de sesión), B-02 (nulabilidad DB), B-03 (serialización JSON de `LocalTime`/`Instant`), B-04 (runtime/E2E), B-05 (orden de interceptores en 401).
- Baseline del backend: la rama `sergio` está **sucia** (59 entradas al inicio): la evidencia se identifica por SHA-256 (CONTRACT_MATRIX §1.1), dos de cuyos archivos difieren de `HEAD`. Recomendable fijar un commit antes de LB-001C.
- Cobertura frontend: 76,43 % líneas / 55,09 % ramas (`test:ci`) frente al objetivo histórico de 80 % de [LINEA_BASE](../../baseline/LINEA_BASE.md); el gate propio de realtime (`coverage:realtime:check`) pasa (95,56 % / 87,04 %). Es baseline, no se corrige aquí.

## Cambios fuera de alcance

Ninguno. Escritura limitada a este directorio, [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md) y [LINEA_BASE](../../baseline/LINEA_BASE.md). Backend `src/**`, `pom.xml`, `contracts/openapi/**`, frontend, DB, `infra/**` y `.github/**`: sin cambios.

## Siguiente paso recomendado

1. Revisión humana de esta matriz y decisión de DR-001…DR-010 (prioridad: DR-002, DR-001, DR-006, DR-008).
2. Aportar B-01/B-02 (equipo DB) y B-03 (test de contrato de serialización) y, si es posible, B-04 (MV-001) con `USE_MOCKS=false`.
3. Fijar un commit limpio del backend y del frontend como snapshot.
4. Solo entonces, autorizar LB-001C (freeze Contract First), que sigue bloqueada para el contrato de errores por TD-030.

## Condición de parada

No iniciar automáticamente la siguiente fase. LB-001C **no** está iniciada ni autorizada.
