---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-24
---

# CLOSURE — LB-001B.4: Final Backend Contract Closure

Fase 06-cierre. Fechas: cierre inicial 2026-09-23; cierre final incl. LB-001B.4A 2026-09-24. Rama `sergio`, base `fa9aa901c73e55ae31071f4e74cfb2245189243a`; sin commit creado (worktree sucio heredado).

**Alcance de modificación:** la fase **06-cierre** (inicial y final) solo modificó documentación. El work item **LB-001B.4 completo (incluida 4A)** sí modificó producción, tests y documentación en sus fases 03-tester-red/04-implementador; la evidencia histórica de esas fases (RED_SNAPSHOT, AUDIT, cifras de 959 tests) se conserva sin alterar.

## Resultado

| Dimensión | Estado |
|---|---|
| LB-001B.4 | **DONE FINAL** (incluye 4A SESSION CONTRACT POLISH y 4B SESSION NAME LENGTH ALIGNMENT) |
| DB ↔ BACKEND GOLDEN PATH | **ALIGNED** (DB↔BACKEND ALIGNED; longitud de `Sesion.nombre` alineada en 4B, [TD-048](../../baseline/TECHNICAL_DEBT.md#td-048) CLOSED) |
| READY FOR FRONTEND VERIFICATION | **YES** |
| READY FOR LB-001C | **NO** (primero verificación frontend + MV-001) |
| Perfil de integración completo | **NOT_GREEN — TD-043 NON-GOLDEN** (`RED_NON_GOLDEN_TD043`; 53 tests, 6 fallos, 2 skips) |
| LB-001B.3 | DONE / superado por LB-001B.4 |

El DONE se declara sobre el alcance del Golden Path (VALIDATION es PASS para el Golden Path y el gate técnico). **No** se declara verde todo el backend contra DB: los 6 fallos de `-Pintegration` pertenecen a [TD-043](../../baseline/TECHNICAL_DEBT.md#td-043), fuera del Golden Path, y siguen visibles. MV-001 sigue pendiente. Evidencia: [VALIDATION](VALIDATION.md), [AUDIT](AUDIT.md).

### LB-001B.4A — Session contract polish (2026-09-24)

- `tema` eliminado del contrato de `Sesion`. Requests exactos: `POST /sesiones {grupo, nombre, fechaHoraInicio, fechaHoraFin}`; `PUT /sesiones/{id} {nombre, fechaHoraInicio, fechaHoraFin}`. `tema/topic/descripcion/aula/tipo/status/room` → 400 `FIELD_UNKNOWN`.
- `docente` redundante eliminado de create/update (solo `usuarioEjecutor`); el rol se valida vía `institutionalScopePort.findDocenteIdByUsuario` como chequeo. Parámetros de los SP sin cambios.
- Códigos `ERR_TEMA_SESION_*` → `ERR_NOMBRE_SESION_*` (sin consumidores externos).
- TD-042 verificado con test `@SpringBootTest` real (`RealtimeEventResponseSpringJsonTest`) → **CLOSED**.
- DR-010 **RESOLVED, Opción A**: listas completas AS-IS, sin `page/size/sort/q`; asistencias sin orden público garantizado; paginación = future feature.
- Validación 4A: `mvn -B -ntp verify` (JDK 25) BUILD SUCCESS, **967 tests, 0 fallos**, ArchUnit 20/20 (`CleanArchitectureRulesTest`), JaCoCo LINE 86,48 % / BRANCH 70,93 % (margen BRANCH 0,93 pp). `-Pintegration` y Golden Path IT con DB **no ejecutados** en 4A (sin DB, fuera de alcance); su último resultado es el de LB-001B.4 inicial.
- Hallazgo F-4A-1 (histórico de 4A; RESUELTO en 4B, ver abajo): `Sesion.nombre` es `nvarchar(50)` según [LB-001B.1 PLAN](../LB-001B.1-db-source-of-truth-cleanup/PLAN.md), pero el backend valida 1..150 → decisión pendiente de contratos (propuesta máx. 50, a confirmar con el equipo DB); registrado como [TD-048](../../baseline/TECHNICAL_DEBT.md#td-048). No se cambió código en 4A.

### LB-001B.4B — Session name length alignment (2026-09-24, cierra TD-048)

- Decisión humana: `Sesion.nombre` máx. 50 (DB `NVARCHAR(50)`). Implementación: 1..50 en `CrearSesionRequestValidator`, `CrearSesionDomain`, `ActualizarSesionDomain` y `SesionConsultadaEntity`; mensaje "El nombre de la sesion debe tener entre 1 y 50 caracteres."; wire code HTTP `FIELD_INVALID_LENGTH` (POST); PUT sin validador HTTP (solo Domain, `ERR_NOMBRE_SESION_LONGITUD_INVALIDA`).
- `TEST_CONTRACT_CONFLICT` (`INVALID_LENGTH` vs `FIELD_INVALID_LENGTH`) resuelto corrigiendo la aserción del test al wire code real `FIELD_INVALID_LENGTH`; sin cambio de producción por ese conflicto.
- Validación JDK 25: subset Sesion 100/0/0/0; `mvn -B -ntp verify` (una vez, sin `-Pintegration`): BUILD SUCCESS, **970 tests, 0F/0E/0S**, ArchUnit 20/20, JaCoCo LINE 86,48 % / BRANCH 70,93 %. IT/`-Pintegration` **no ejecutados** (persistence/SP sin cambios).
- Auditoría 4B: PASS sin bloqueantes ([AUDIT](AUDIT.md)). Contrato actualizado, SHA-256 vigente `02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121`.
- **DB↔BACKEND ALIGNED. READY FOR FRONTEND VERIFICATION: YES.** READY FOR LB-001C: NO.

## Alcance entregado y decisiones

- Canal formal `DBCODE` con parser estricto y mapping por código (`SEC_001/SEC_002/EST_004 -> 403/FORBIDDEN`; `ATT_001-003/GEN_002/RC_001/SES_004 -> 400/VALIDATION_ERROR`; `SES_001 -> 404/RESOURCE_NOT_FOUND`; `SES_003 -> 501/FEATURE_UNAVAILABLE`; desconocido/malformado -> `ERR_DB_UNCLASSIFIED`, fail-closed). DBCODE nunca sale al frontend.
- Ghost fields retirados (`aula` en Grupo y HorarioEstudiante); Sesion create/update alineadas con la DB congelada.
- UTC en los lectores de `Sesion`; `occurredAt` con `Z`.
- Contrato backend del Golden Path: [BACKEND_GOLDEN_PATH_CONTRACT.md](../../contracts/BACKEND_GOLDEN_PATH_CONTRACT.md), SHA-256 vigente `02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121` (recalculado tras 4B; histórico: `d74317dc08360b079edd0fcb29f0024c944aa5ef8f53c136347f3474abb1be6d` tras 4A; `db15b1a6...fbc4` en el cierre inicial) ([.sha256](../../contracts/BACKEND_GOLDEN_PATH_CONTRACT.sha256), verificado). No es OpenAPI.
- Contrato DB consumido: SHA-256 `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec` (MATCH; origen `UNCOMMITTED_WORKTREE`).
- Decisiones (DR) en [CONTRACT_MATRIX de LB-001B](../LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md): DR-001, 002, 004, 005, 006 (Opción A, fail-closed), 007, 008, 009 **RESOLVED**; DR-003 mapping RESOLVED (dependencia temporal en TD-005/LB-001C); **DR-010 RESOLVED — Opción A** (LB-001B.4A, 2026-09-24; el cierre inicial lo había dejado PENDING).
- Enlaces: [PLAN](PLAN.md), [CONTRACT_MATRIX](CONTRACT_MATRIX.md), [TEST_PLAN](TEST_PLAN.md), [RED_SNAPSHOT](RED_SNAPSHOT.md), [CONTRACT_DECISION_TD043](CONTRACT_DECISION_TD043.md).

## Deuda

Detalle único en [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md); no se duplica aquí.

| TD | Estado |
|---|---|
| TD-036 | CLOSED |
| TD-037 | CLOSED |
| TD-038 | CLOSED |
| TD-040 | CLOSED — EVIDENCE_RESOLVED (salvedad: documentar las vistas en el contrato DB, TD-046) |
| TD-030 | RESOLVED BY FROZEN DB BASELINE |
| TD-005 | CLOSED_FOR_GOLDEN_PATH; freeze HTTP en LB-001C; no se declara cerrada una migración temporal global |
| TD-042 | **CLOSED (LB-001B.4A)** — `RealtimeEventResponseSpringJsonTest` con `@SpringBootTest` real (histórico: abierta en el cierre inicial por usar un `JsonMapper` manual) |
| TD-043 | ABIERTA (NON_GOLDEN): 3 SP inexistentes; mantiene `-Pintegration` NOT_GREEN; requiere decisión del owner (crear SP o retirar/adaptar adapters) antes de liberar esas features |
| TD-044 | NUEVA: 2 skips de `DocenteRepositorySqlServerIT` sin fixture |
| TD-045 | NUEVA: `CPI`/`CPVP` históricos vs lectura fail-closed |
| TD-046 | NUEVA: vistas sin documentar en `DB_BASELINE_CONTRACT.md` (acción equipo DB) |
| TD-047 | NUEVA: `USU_001` sin mapeo formal DBCODE |
| TD-041 | ABIERTA (seguimiento externo del origen del contrato DB) |
| TD-048 | **CLOSED (4B)** — backend aligned to frozen DB NVARCHAR(50) (nació en 4A como F-4A-1) |
| TD-034 | ABIERTA, no bloqueante (sin cambios) |

## Validación manual

[MV-001](../../baseline/MANUAL_VALIDATION_LEDGER.md) (Golden Path E2E frontend + Keycloak + SQL Server + SSE): **PENDIENTE**, no ejecutado ni presumido. Responsable: backend-team + frontend/DB. MV-004 (CI remoto) también pendiente.

## ADR relacionados

Ninguno nuevo. Las decisiones quedan en CONTRACT_MATRIX/DR y en el contrato del Golden Path; ADR-001 (Golden Path) sigue vigente. Si el equipo considera el canal `DBCODE` una decisión duradera, puede elevarse a ADR (no realizado aquí).

## Elementos pendientes y bloqueos

- Verificación frontend contra el contrato backend y MV-001 (condición previa para `READY FOR LB-001C`, hoy NO).
- Decisión del owner sobre TD-043.
- Representación HTTP temporal (TD-005): pendiente de LB-001C; no bloquea el Golden Path funcional. (DR-010 y TD-042 ya resueltos en 4A.)
- Riesgo BRANCH JaCoCo 70,93 % (margen 0,93 pp; era 71,60 % antes de 4A; sin cambio en 4B).
- IT con DB no re-ejecutados en 4A/4B (persistence/SP sin cambios).
- SSE `SINGLE_INSTANCE_OK`; `MULTI_INSTANCE_PROVIDER_REQUIRED` sin implementar (TD-003, LB-005).
- Auditoría no externa (mismo agente/repositorio).

## Cambios fuera de alcance

Ninguno por la fase 06-cierre (solo documentación; no se modificó código, tests, DB ni frontend; sin commit ni push; sin secretos). Los cambios de producción/tests de LB-001B.4/4A pertenecen a sus fases de implementación y están auditados en [AUDIT](AUDIT.md).

## Documentos actualizados en el cierre

`docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` (+ `.sha256`; 4A: sin `tema`, DR-010; 4B: `nombre` 1..50, TD-048 CLOSED), este `VALIDATION.md`/`CLOSURE.md`, `docs/baseline/LINEA_BASE.md`, `docs/baseline/TECHNICAL_DEBT.md`, `docs/work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md`, banner de superación en `LB-001B.3/CLOSURE.md`.

## Condición de parada

No iniciar automáticamente LB-001C ni ninguna fase siguiente. Requiere autorización explícita, verificación frontend y MV-001 resueltos (READY FOR LB-001C: NO).
