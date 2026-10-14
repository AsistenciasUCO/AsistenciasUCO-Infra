# PLAN — LB-001B: alineación contractual backend ↔ frontend del Golden Path de asistencia

## Identidad y objetivo

- Fecha / rol / base Git: 2026-09-20 / agente de contratos (CONTRACT_ANALYSIS) / backend `fa9aa901c73e55ae31071f4e74cfb2245189243a` en rama `sergio` (**working tree sucio**, ver [CONTRACT_MATRIX §Evidencia](CONTRACT_MATRIX.md#1-evidencia-y-snapshots)); frontend `71ee6d32bfe1c6c58c04d0e986e525850ff6eb52` en rama `develop` (limpio).
- **HUMAN_APPROVAL = APPROVED** — orden explícita del responsable en el chat de la sesión del 2026-09-20: «Se autoriza iniciar: LB-001B — BACKEND ↔ FRONTEND CONTRACT ALIGNMENT, Change class CONTRACT_ANALYSIS». Autoriza el análisis; no autoriza LB-001C, OpenAPI, JPA ni correcciones.
- Objetivo: determinar, con evidencia verificable y sin decidir cómo corregir, si el contrato HTTP + realtime que ofrece AsistenciasUCO (provider) coincide con el que consume AsistenciasUCO-Frontend (consumer) en el Golden Path (`horarios → sesiones → estudiantes → asistencias → POST lote → evento SSE → refresh`).
- Criterios de aceptación: ver §Criterio de salida.
- Skills y fuentes autoritativas cargadas: `uco-contratos`, `uco-seguridad`, `uco-realtime`, `uco-testing`, `uco-baseline`; [AGENTS](../../../AGENTS.md), [CONTRACT_ALIGNMENT_PROTOCOL](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md), [SOURCE_OF_TRUTH](../../governance/SOURCE_OF_TRUTH.md), [DEFINITION_OF_READY](../../governance/DEFINITION_OF_READY.md), [GOLDEN_PATH_ASISTENCIA](../../baseline/GOLDEN_PATH_ASISTENCIA.md), [HTTP_AS_IS_MATRIX](../../contracts/HTTP_AS_IS_MATRIX.md), [REALTIME_EVENT_STANDARD](../../contracts/REALTIME_EVENT_STANDARD.md), [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md), plantillas de `.claude/templates/`.

## AS-IS y evidencia

| Hecho | Archivo + símbolo | Evidencia y límites |
|---|---|---|
| El backend es provider AS-IS del contrato HTTP/realtime; no existe OpenAPI aprobado | [CONTRACT_ALIGNMENT_PROTOCOL](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md), [TD-002](../../baseline/TECHNICAL_DEBT.md#td-002) | Instrucción del responsable para esta fase: backend AS-IS = provider, frontend AS-IS = consumer |
| LB-001A cerró DB ↔ backend (`READY_FOR_FREEZE`) | [LB-001A CLOSURE](../LB-001A-db-backend-asistencia/CLOSURE.md) | Evidencia DB certificada externamente; no reproducida aquí |
| El frontend real existe con `package.json`, `angular.json`, `src/app/`, `src/environments/` | ruta del frontend (ver matriz) | Comprobado por listado de directorio |
| Este análisis es estático + ejecución de la suite frontend | [VALIDATION](VALIDATION.md) | **No se ejecutó E2E backend+frontend con `USE_MOCKS=false`**; ningún hallazgo runtime se afirma como probado |

## TARGET

No aplica: `CONTRACT_ANALYSIS` no define contrato TARGET. LB-001C congelará el contrato a partir de este AS-IS y de las decisiones `DR-*` aprobadas.

## Clase de cambio y alcance de rutas

- Change class: **CONTRACT_ANALYSIS**
- Variable principal: coincidencia (o no) del contrato HTTP + realtime entre provider y consumer en el Golden Path.
- Allowed (WRITE): `docs/work-items/LB-001B-backend-frontend-asistencia/**`, `docs/baseline/TECHNICAL_DEBT.md`, `docs/baseline/LINEA_BASE.md` (solo si el análisis lo justifica).
- Forbidden (WRITE): backend `src/**`, `pom.xml`, `contracts/openapi/**`, frontend (todo), `database/**`, `infra/**`, `.github/**`. Backend y frontend son READ-ONLY para código.

## Alcance

Inventario del Golden Path desde código; comparación por endpoint (método, path, params, body, respuesta, status, auth, content-type, error, correlation); wrappers `ApiListResponse/ApiMessageResponse/ApiDataResponse/ApiErrorResponse`; docente/grupos; sesiones (incluido estado y fechas); estudiantes; consulta de asistencia; ausencia de registro; batch; realtime extremo a extremo (envelope, payload, heartbeat, reconexión); auth; correlation; errores; mocks y fallbacks; listado/filtro/paginación; tests frontend como evidencia del consumer; baseline frontend (`test:ci`, `build`).

## No alcance

Implementar o corregir backend/frontend, crear OpenAPI, iniciar JPA, modificar DB, resolver TD-030, resolver timezone/UTC, agregar campos, paginación o estado de sesión, eliminar mocks, iniciar LB-001C. Endpoints fuera del Golden Path (crear/cerrar/cancelar sesión, matrícula, QR) solo se mencionan como observaciones adyacentes.

## Archivos afectados

- NUEVOS: `PLAN.md`, `CONTRACT_MATRIX.md`, `VALIDATION.md`, `CLOSURE.md`, `TEST_PLAN.md` (solo pruebas **futuras** derivadas de hallazgos; ningún test escrito) en esta carpeta.
- EXISTENTES: [TECHNICAL_DEBT.md](../../baseline/TECHNICAL_DEBT.md) (reconciliación sin duplicar) y [LINEA_BASE.md](../../baseline/LINEA_BASE.md) (estado de LB-001B).
- RETIRAR: nada.

## Contratos y consumidores afectados

HTTP, realtime y seguridad se **analizan**, no se modifican. Consumidor: AsistenciasUCO-Frontend (`develop@71ee6d3`). Sin cambios de compatibilidad; sin aprobación de contrato (DRAFT).

## Riesgos y dependencias

- El backend está en rama `sergio` con working tree sucio (59 entradas de `git status --short`); `HEAD` no identifica el snapshot, por lo que cada archivo de evidencia lleva SHA-256 y estado (limpio/modificado). Dos archivos usados como evidencia están modificados respecto a `HEAD`: `GlobalExceptionHandler.java` y `SesionControllerContractTest.java`.
- Sin ejecución runtime: la serialización real de `LocalTime`, la nulabilidad DB y el comportamiento del SP ante re-guardado quedan `BLOCKED_BY_MISSING_EVIDENCE`.
- Dependencia: TD-030 abierta bloquea el freeze del contrato de errores.

## Test plan

Ver [TEST_PLAN.md](TEST_PLAN.md): solo pruebas futuras; no hay RED/GREEN en esta fase (documental/analítica: NO APLICA).

## Rollback

Eliminar la carpeta `docs/work-items/LB-001B-backend-frontend-asistencia/` y revertir las ediciones a `TECHNICAL_DEBT.md` / `LINEA_BASE.md`. No hay cambios en código, DB ni frontend que revertir. La ejecución de `npm run test:ci` y `npm run build` solo regeneró `coverage/` y `dist/` del frontend, ambos ignorados por git (`git status` del frontend: limpio antes y después).

## Stop conditions

- `BLOCKED_BY_MISSING_EVIDENCE`: B-01…B-05 (ver CONTRACT_MATRIX §Bloqueos). No bloquean el análisis; bloquean el freeze de las filas afectadas.
- `CONTRACT_CONFLICT`: no se abre ninguno; los `MISMATCH` no implican que una fuente autoritativa contradiga a otra sino que provider y consumer difieren, y se resuelven vía `DR-*`.
- Ninguna fase siguiente comienza automáticamente.

## Deuda conocida y validación manual

TD-002, TD-003, TD-005, TD-006, TD-009, TD-016, TD-017, TD-021, TD-030 (ver [CLOSURE](CLOSURE.md)). Validación manual: MV-001 (E2E realtime) permanece pendiente — [MANUAL_VALIDATION_LEDGER](../../baseline/MANUAL_VALIDATION_LEDGER.md).

## Criterio de salida

`ANALYSIS COMPLETE / HTTP-FRONTEND CONTRACT NOT FROZEN` es un resultado válido. Se considera ALIGNED solo si: cada endpoint tiene contrato identificado; no quedan `MISMATCH` sin clasificar; cada `DECISION_REQUIRED` está explícito; realtime completamente documentado; mocks/fallbacks identificados; consumer/provider trazados.

## Definition of Ready

**READY para `CONTRACT_ANALYSIS`** ([DoR](../../governance/DEFINITION_OF_READY.md)): repositorios identificados y versionados (SHA-256 por archivo por estar el backend sucio); owner (backend) y consumer (frontend) identificados; Golden Path y alcance definidos; ninguna evidencia contiene secretos (`.env` no leído; los valores de `environment.ts` no son secretos); provider y consumer inspeccionables. **NOT_READY para implementación** — no se autoriza ninguna.
