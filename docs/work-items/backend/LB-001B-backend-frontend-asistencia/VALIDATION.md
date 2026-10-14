# VALIDATION — LB-001B: alineación contractual backend ↔ frontend del Golden Path de asistencia

## Dictamen

**PASS del análisis (`CONTRACT_ANALYSIS`) con `VALIDATION_BLOCKED_BY_ENVIRONMENT` parcial:** no hubo ejecución E2E backend+frontend con `USE_MOCKS=false` (MV-001 no disponible), por lo que los hallazgos runtime están marcados `BLOCKED_BY_MISSING_EVIDENCE` (B-01…B-05) y **no** se declaran probados. Resultado del contrato: `NOT_READY_FOR_LB001C`, ver [CLOSURE](CLOSURE.md).

Auditor: el propio agente que redactó el análisis; **independencia real: ninguna** (autorrevisión sin revisor conceptualmente independiente). Se recomienda revisión humana antes de LB-001C.

## Comandos ejecutados

Entorno: Windows 11, Git Bash/PowerShell, Node v22.20.0, npm 11.6.2, Chrome instalado localmente (ChromeHeadless). Fecha: 2026-09-20 (hora local UTC-5). Backend `fa9aa901…` (rama `sergio`, **sucio**); frontend `71ee6d3…` (rama `develop`, limpio).

| Fecha/entorno/base | Comando | Exit code | Resultado | Evidencia sanitizada |
|---|---|---|---|---|
| 19:33 · backend | `git rev-parse --abbrev-ref HEAD; git rev-parse HEAD; git status --short` | 0 | rama `sergio`, HEAD `fa9aa90…`, 59 entradas (dirty) | [CONTRACT_MATRIX §1](CONTRACT_MATRIX.md#1-evidencia-y-snapshots) |
| 19:33 · frontend | ídem | 0 | rama `develop`, HEAD `71ee6d3…`, limpio | ídem |
| 19:33 · ambos | listado de `pom.xml`, `src/main/java`, `AGENTS.md` / `package.json`, `angular.json`, `src/app`, `src/environments` | 0 | archivos requeridos presentes | — |
| 19:38-19:39 · frontend | `npm run test:ci` (`ng test --watch=false --browsers=ChromeHeadless --code-coverage`) | **0** | **97 de 97 SUCCESS**; cobertura: sentencias 75,43 % (436/578), ramas 55,09 % (200/363), funciones 66,14 % (84/127), líneas 76,43 % (425/556). Los `WARN` del log son fixtures esperados de specs (p. ej. «network down») | log local del ejecutor (no versionado) |
| 19:39 · frontend | `npm run build` (`ng build`, configuración por defecto) | **0** | *Application bundle generation complete* (12,2 s); initial total 392,37 kB / 99,99 kB transferidos; sin errores | log local |
| 2026-09-20 (tras el build) · frontend | `npm run coverage:realtime:check` | **0** | PASSED: líneas 95,56 % (≥90 %), ramas 87,04 % (≥80 %) sobre los 6 archivos realtime | salida de consola |
| 2026-09-20 (cierre del análisis) · backend | `find` de archivos modificados tras el inicio del análisis en `src/`, `pom.xml`, `contracts/`, `infra/`, `.github/` | 0 | **ninguno**; solo archivos de `docs/` permitidos (work item, TECHNICAL_DEBT, LINEA_BASE) | — |
| 2026-09-20 (cierre del análisis) · frontend | `git status --short` | 0 | vacío (limpio) tras ejecutar test y build; `coverage/`, `dist/` y `.angular/cache/` están ignorados por git | — |
| 2026-09-20 (cierre del análisis) · ambos | recomputo `sha256sum` de los 41 + 46 archivos de evidencia y comparación con las tablas de la matriz | 0 | **sin deriva** (0 diferencias) | CONTRACT_MATRIX §1.1/§1.2 |
| 2026-09-20 (cierre del análisis) · backend | verificador de enlaces Markdown y anclas (script local) sobre PLAN, CONTRACT_MATRIX, TEST_PLAN, CLOSURE, VALIDATION, TECHNICAL_DEBT, LINEA_BASE | 0 | ver §Checks (enlaces) | — |
| 2026-09-20 (cierre del análisis) · backend | `git diff --check` | 0 | sin errores de espacios en cambios trackeados; los archivos nuevos (no trackeados) se revisaron con `grep` de espacios finales y marcadores de conflicto: ninguno | — |
| 2026-09-20 (cierre del análisis) · backend | `grep` de patrones de secretos en los documentos escritos | 0 (sin coincidencias) | ninguna credencial/token; la credencial por defecto del frontend se reporta solo por archivo/tipo (TD-032) | — |

No se ejecutó `./mvnw verify` ni `npm ci`: el backend no cambió (el gate técnico vigente es el de [TECH-001](../TECH-001-restaurar-gate-arquitectura/VALIDATION.md)) y `node_modules` del frontend es la instalación local previa (no proviene de un ZIP), usada para ejecutar la suite y leer `fetch-event-source`. Advertencia: no se confirmó que `node_modules` coincida con `package-lock.json`.

## Baseline del frontend (sin modificar)

| Dato | Valor |
|---|---|
| Proyecto | `gestio-asistencia-frontend@0.0.0` |
| Angular | `@angular/core` 18.2.14 · CLI 18.2.21 · TypeScript `~5.5.2` · RxJS `~7.8.0` |
| Librerías relevantes | `@microsoft/fetch-event-source` 2.0.1 · `keycloak-js` ^26.0.0 |
| Scripts | `ng`, `start`, `watch`, `build`, `test`, `test:ci`, `coverage:realtime:check`, `e2e:realtime:smoke`, `verify` (= `test:ci` + `coverage:realtime:check` + `build --configuration=production`) |
| Suite | 97/97 SUCCESS; cobertura global 76,43 % líneas / 55,09 % ramas (por debajo del objetivo histórico de 80 % de LINEA_BASE; **baseline, no se corrige aquí**) |
| Build | OK; sin fallos |
| No ejecutados | `npm run verify` completo (build de producción), `e2e:realtime:smoke` (requiere backend real) |

## Checks

| Nivel | Check | PASS / FAIL / NO APLICA / BLOQUEADO | Evidencia/motivo |
|---|---|---|---|
| Alcance | Plan/criterios; clase `CONTRACT_ANALYSIS`; write-scope | PASS | [PLAN](PLAN.md); solo los 5 documentos del work item, TECHNICAL_DEBT y LINEA_BASE (`find` por mtime) |
| Alcance | Backend `src/**`, `pom.xml`, `contracts/openapi/**` sin cambios | PASS | 0 archivos con mtime posterior al inicio; los `M` de `git status` son previos (TECH-001/LB-000) |
| Alcance | Frontend sin cambios | PASS | `git status` vacío antes y después |
| Alcance | DB sin cambios; no OpenAPI; no JPA; no LB-001C | PASS | ninguna escritura fuera de `docs/`; `contracts/openapi/` solo contiene `README.md` |
| Arquitectura | ArchUnit/dependencias | NO APLICA | sin cambios de código |
| Contratos | HTTP/seguridad/eventos comparados con evidencia por fila | PASS | [CONTRACT_MATRIX](CONTRACT_MATRIX.md): 92 filas, un estado permitido cada una; sin etiquetas ambiguas |
| Contratos | Cada `MISMATCH` clasificado y cada `DECISION_REQUIRED` explícito | PASS | 5 `MISMATCH` con owner action; 6 `DECISION_REQUIRED` → DR-001…DR-010 (`PENDING`) |
| Contratos | Claims con evidencia | PASS con reservas | cada fila cita archivo+línea; los claims de runtime están `BLOCKED_BY_MISSING_EVIDENCE`; C-007d es **inferencia estática** declarada como tal |
| Tests | RED → GREEN | NO APLICA | análisis; [TEST_PLAN](TEST_PLAN.md) solo lista pruebas futuras |
| Tests | Suite frontend | PASS | 97/97 |
| Coverage | Backend LINE ≥80 %/BRANCH ≥70 % | NO APLICA | backend no modificado |
| Coverage | Frontend | Baseline | 76,43 % / 55,09 % globales; gate realtime PASS |
| Integración | DB real / E2E `USE_MOCKS=false` | BLOQUEADO | no hay ambiente autorizado; MV-001 pendiente (B-04) |
| Build | `mvn verify` | NO APLICA | ver nota arriba |
| Build | `npm run build` | PASS | exit 0 |
| Seguridad | Secretos | PASS | `.env` no leído; sin secretos en los documentos; `SECURITY_FINDING` TD-032 sin valor |
| Seguridad | RBAC/ownership | PASS (análisis) | comparado contra `SecurityConfig` y use cases; sin prueba runtime |
| Evidencia | SHA-256 de archivos externos | PASS | 41 backend + 46 frontend, sin deriva |
| Documentos | Enlaces Markdown y anclas | PASS | 163 enlaces relativos comprobados, 0 rotos; ver nota final de esta tabla |
| Documentos | `git diff --check` / espacios | PASS | ver comandos |
| Documentos | Deuda reconciliada sin duplicar | PASS | TD-017/005/009/030 actualizadas; TD-031…033 nuevas sin equivalente |

Resultado de enlaces: se comprobaron **todos** los enlaces relativos de los siete documentos, incluidas anclas, con `0` rotos tras crear este archivo (los 2 avisos iniciales apuntaban a `VALIDATION.md`, aún inexistente).

## Integridad de RED

**NO APLICA** (sin RED ni tests escritos).

## Bloqueantes y limitaciones

- Backend sucio (rama `sergio`, 59 entradas): `HEAD` no identifica el snapshot; `GlobalExceptionHandler.java` y `SesionControllerContractTest.java` (usados como evidencia) difieren de `HEAD`.
- Sin E2E ni tráfico real: B-01…B-05 abiertos.
- El frontend se analizó en su snapshot `71ee6d3`; `node_modules` local sin verificar contra el lockfile.
- No se leyó `.env` ni configuración de secretos.
- La independencia de la revisión es nula (mismo agente).

## Evidencias remotas/manuales pendientes

[MV-001](../../baseline/MANUAL_VALIDATION_LEDGER.md) (E2E Golden Path con Keycloak + SQL Server + SSE, `USE_MOCKS=false`); certificación externa DB de B-01/B-02; CI remoto ([MV-004](../../baseline/MANUAL_VALIDATION_LEDGER.md)) no evaluado.
