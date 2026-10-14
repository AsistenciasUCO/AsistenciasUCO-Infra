---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-24
---

# VALIDATION — LB-001B.4: Final Backend Contract Closure

Fecha: 2026-09-23. Rama `sergio`, base `fa9aa901c73e55ae31071f4e74cfb2245189243a` (worktree sucio heredado de LB-001B.3, sin commit nuevo). Java 25 (Oracle JDK 25 vía `mvnw`), DB `sql_server_asistencias` / `gestionasistenciadb`. Las cifras provienen de las corridas registradas por el implementador/auditor (ver [AUDIT](AUDIT.md)); esta fase de cierre no ejecutó comandos ni modificó código, tests ni DB.

## Dictamen

- **Golden Path (DB↔Backend): PASS.** `GOLDEN_PATH_SQL_CONTRACT: PASS`.
- **Build unitario (`TECHNICAL_BUILD_GATE`): PASS.**
- **Perfil de integración completo (`FULL_INTEGRATION_PROFILE`): `RED_NON_GOLDEN_TD043` — NOT_GREEN.** No se declara verde el backend completo contra DB; los 6 fallos pertenecen a [TD-043](../../baseline/TECHNICAL_DEBT.md#td-043) y están fuera del Golden Path.
- Auditor: `05-auditor`, mismo agente/repositorio con revisión conceptualmente independiente; **no es verificación externa** ([AUDIT](AUDIT.md), dictamen final: PASS técnico con condiciones).

## Validación LB-001B.4A (2026-09-24, Session contract polish)

| Comando | Exit code | Resultado |
|---|---|---|
| `mvn -B -ntp verify` (JDK 25, unit + ArchUnit + JaCoCo; ejecutado por el auditor) | 0 | BUILD SUCCESS; 967 tests, 0 F / 0 E / 0 S; ArchUnit `CleanArchitectureRulesTest` 20/20; "All coverage checks have been met"; JaCoCo LINE 86,48 % / BRANCH 70,93 % (gate LINE ≥80 / BRANCH ≥70; margen BRANCH 0,93 pp) |
| `RealtimeEventResponseSpringJsonTest` (`@SpringBootTest`) | 0 | PASS; `occurredAt` ISO-8601 con `Z` con el `JsonMapper` de Spring → TD-042 CLOSED |

**No ejecutado en 4A:** `-Pintegration` y Golden Path IT con DB (sin DB, fuera de alcance). Su resultado vigente es el de la corrida de LB-001B.4 inicial (tabla siguiente); no se presume re-verificado.

Dictamen 4A: PASS técnico. Hallazgo F-4A-1 ([TD-048](../../baseline/TECHNICAL_DEBT.md#td-048)) `Sesion.nombre` nvarchar(50) vs 1..150: resuelto en 4B (ver sección siguiente). MV-001 y MV-004 siguen pendientes. Las cifras siguientes (959 tests, LINE 87,89 %, BRANCH 71,60 %) son evidencia histórica de LB-001B.4 previa a 4A y no se alteran.

## Validación LB-001B.4B (2026-09-24, Session name length alignment; cierra TD-048)

| Comando | Exit code | Resultado |
|---|---|---|
| Subset Sesion (JDK 25) | 0 | 100 tests, 0F/0E/0S |
| `mvn -B -ntp verify` (JDK 25, una vez, sin `-Pintegration`) | 0 | BUILD SUCCESS; **970 tests, 0F/0E/0S**; ArchUnit `CleanArchitectureRulesTest` 20/20; JaCoCo LINE 86,48 % / BRANCH 70,93 % (gates 80/70 cumplidos) |

No ejecutados: IT y `-Pintegration` (persistence/SP sin cambios en 4B; sin DB). `TEST_CONTRACT_CONFLICT` (`INVALID_LENGTH` vs `FIELD_INVALID_LENGTH`) resuelto corrigiendo la aserción del test al wire code real. Contrato: `Sesion.nombre` string requerido 1..50; SHA-256 `.sha256` = `02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121` (coincide con `Get-FileHash`). Dictamen 4B: **PASS** ([AUDIT](AUDIT.md)). **DB↔BACKEND ALIGNED; READY FOR FRONTEND VERIFICATION: YES.** MV-001 y MV-004 siguen pendientes. Las cifras de 4A (967 tests) y anteriores son históricas.

## Comandos ejecutados (LB-001B.4 inicial, histórico)

| Fecha/entorno/base | Comando | Exit code | Resultado | Evidencia sanitizada |
|---|---|---|---|---|
| 2026-09-23, Java 25, `fa9aa90` + worktree | `mvnw -B -ntp verify` (unit + ArchUnit + JaCoCo; repetido por el auditor) | 0 | 959 tests, 0 F / 0 E / 0 S; BUILD SUCCESS; "All coverage checks have been met" | `target/surefire-reports`, `target/site/jacoco/jacoco.csv` |
| 2026-09-23, DB `gestionasistenciadb` | IT Golden Path: `AsistenciaRepositorySqlServerIT` | 0 | 6 ejecutados / 6 pass / 0 skip | failsafe |
| 2026-09-23, DB `gestionasistenciadb` | IT Golden Path: `GoldenPathSqlStoredProcedureContractIT` | 0 | 16/16 pass, 0 skip → `GOLDEN_PATH_SQL_CONTRACT: PASS` | failsafe |
| 2026-09-23, DB `gestionasistenciadb` (corrida de las 16:00, no repetida por el auditor) | `mvnw verify -Pintegration` (perfil completo) | != 0 | 53 tests, 6 failures, 0 errors, 2 skipped → `FULL_INTEGRATION_PROFILE: RED_NON_GOLDEN_TD043` | `target/failsafe-reports` |
| 2026-09-23 | Contraste SHA-256 del contrato DB importado | — | `DB_BASELINE_CONTRACT.md` = `.sha256` = `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec` (= PLAN/CONTRACT_MATRIX/PRECHECK): MATCH | [PRECHECK_SNAPSHOT](PRECHECK_SNAPSHOT.md) |
| 2026-09-23 | `SELECT` dinámico de solo lectura sobre columnas de texto de todas las tablas, prefijo `IT-LB001B4-` | — | 0 filas residuales (cleanup OK) | [AUDIT](AUDIT.md) |
| 2026-09-23 (06-cierre inicial; histórico) | `sha256sum -c BACKEND_GOLDEN_PATH_CONTRACT.sha256` | 0 | `BACKEND_GOLDEN_PATH_CONTRACT.md: OK` (`db15b1a6e2bf03be10efe8d6fb8ed6739b9c5fdaac1cd028424c533ab170fbc4`; tras 4A el hash vigente es `d74317dc08360b079edd0fcb29f0024c944aa5ef8f53c136347f3474abb1be6d`, verificado con Get-FileHash) | contrato y `.sha256` |

## Fallos y omisiones del perfil de integración completo (TD-043, separado)

| Suite | Fallos | Causa |
|---|---|---|
| `SqlStoredProcedureContractIT` | 3: `[1]` `usp_sincronizar_usuario`, `[7]` `usp_registrar_o_actualizar_plan_estudio`, `[12]` `usp_registrar_estudiante_en_grupo_usuario_no_existente` | SP inexistente en la DB oficial |
| `GrupoRepositorySqlServerIT` | 2 | `DatabaseOperationException` al invocar `usp_registrar_estudiante_en_grupo_usuario_no_existente` |
| `UsuarioPasswordHashSqlServerIT` | 1 | `DatabaseOperationException` al invocar `usp_sincronizar_usuario` |
| `DocenteRepositorySqlServerIT` | 2 skips (`assumeTrue` por datos) | sin fixture; `consultarAsignacionesAcademicas`, fuera del Golden Path → [TD-044](../../baseline/TECHNICAL_DEBT.md#td-044) |

Los 3 SP se invocan solo desde `UsuarioRepositorySqlServerAdapter`, `GrupoRepositorySqlServerAdapter.registrarEstudianteEnGrupo` y `PlanEstudioSqlServerAdapter`; ningún use case de asistencia, sesión, docente/estudiante ni realtime los usa ([CONTRACT_DECISION_TD043](CONTRACT_DECISION_TD043.md), [AUDIT](AUDIT.md)). Los tests `SqlStoredProcedureContractIT` no fueron ocultados ni deshabilitados (sin `@Disabled`/`assume`; hash idéntico al RED).

## Checks

| Nivel | Check | Resultado | Evidencia/motivo |
|---|---|---|---|
| Alcance | Plan/criterios | PASS | [PLAN](PLAN.md); sin OpenAPI/JPA/Redis/serverless, sin cambios en DB ni frontend |
| Arquitectura | ArchUnit | PASS | 67/67 (16 clases en `architecture/**`, `CleanArchitectureRulesTest` 20/20) |
| Contratos | DB SHA / DBCODE / mapping | PASS | SHA MATCH; `DbTechnicalError`+`DbFailureClassifier`; DBCODE desconocido/malformado -> `ERR_DB_UNCLASSIFIED` (fail-closed); clasificación por texto en Golden Path = 0 |
| Contratos | SEC_002 / RC_001 en integración real | PASS | `ForbiddenException`/`FORBIDDEN`; `ValidationException`/`VALIDATION_ERROR`; cero escrituras, `RazonCausa` intacto. El IT afirma la excepción semántica, no el DBCODE crudo (lo cubren `DbExceptionTranslatorTest` y la inspección de SP) |
| Contratos | Ghost fields | PASS | `aula` en `src/main` = 0; SQL de Grupo sin `@aula`; IT afirma ausencia de `aula` en `uv_horario_estudiante`, `uv_horario_docente`, `uv_sesion`, `uv_grupo` |
| Contratos | Sesion create/update | PASS | `usp_crear_sesion`/`usp_actualizar_sesion` sin `@idDocente`; `@idUsuarioEjecutor` = usuario autenticado |
| Contratos | UTC | PASS | 4 lectores con `toLocalDateTimeUtc`; `RealtimeEventResponseTest` afirma `occurredAt` con `Z` (ver limitación TD-042) |
| Contratos | `X-Correlation-Id` | PASS | `CorrelationIdFilterTest`; `AuditHttpIT` 2/2 |
| Contratos | AN/SJC/EX (DR-006) | PASS con riesgo | escritura validada; lectura fail-closed; riesgo `CPI`/`CPVP` → [TD-045](../../baseline/TECHNICAL_DEBT.md#td-045) |
| Tests | RED → GREEN | PASS | hashes de [RED_SNAPSHOT](RED_SNAPSHOT.md) coinciden; 2 entradas revisadas por `TEST_CONTRACT_CONFLICT` dictaminado por el auditor (Grupo mapper, `SesionMateriaEstudiante`); implementador no alteró RED |
| Coverage | LINE ≥80 % / BRANCH ≥70 % | PASS | LINE 87,89 %, BRANCH 71,60 % (`jacoco.csv`). Margen BRANCH 1,6 pp, estrecho; gate del `pom.xml` sin relajar |
| Integración | Golden Path | PASS | 22/22, 0 skips |
| Integración | Perfil completo | **FAIL (NON-GOLDEN, TD-043)** | 53 / 6 F / 2 S; no ocultado |
| Build | `mvn verify` | PASS | exit 0, 959 tests |
| Seguridad | Secretos | PASS | sin secretos en evidencias (solo `SELECT`, valores no impresos) |
| Seguridad | RBAC | PASS | roles del contrato tomados de `SecurityConfig`; sin cambios de RBAC |
| Documentos | Contrato, deuda, DR, LINEA_BASE | PASS | ver [CLOSURE](CLOSURE.md); `sha256sum -c` OK |
| CI | Checks remotos | NO EJECUTADO | pendiente, no inferido de Maven local ([MV-004](../../baseline/MANUAL_VALIDATION_LEDGER.md)) |

## Integridad de RED

Los hashes finales de `RED_SNAPSHOT.md` coinciden con los archivos actuales. Las dos entradas superadas (`GrupoHttpMapperContractTest` y `SesionMateriaEstudianteSqlServerAdapterTest`) corresponden a la revisión controlada por `TEST_CONTRACT_CONFLICT` (ver [AUDIT](AUDIT.md), dictamen preliminar): la primera retiró la expectativa del ghost field `aula`; la segunda sustituyó `Timestamp.valueOf(LocalDateTime)` por `Timestamp.from(Instant)`. `SqlStoredProcedureContractIT` intacto.

## Bloqueantes y limitaciones

- **Limitación principal:** `-Pintegration verify` termina en rojo por TD-043 hasta que el owner decida (crear los SP en DB o retirar/adaptar los adapters). No es un verde global de integración.
- La corrida `-Pintegration` (53/6/2) es la de `target/failsafe-reports` de las 16:00; el auditor no la repitió. La unitaria sí se repitió.
- Origen del contrato DB: `GENERATED_FROM_COMMIT: UNCOMMITTED_WORKTREE` del repo DB (TD-041).
- TD-042: (histórico) `RealtimeEventResponseTest` usaba un `JsonMapper` manual; **CLOSED en 4A** con test `@SpringBootTest` real.
- Los 2 skips de `DocenteRepositorySqlServerIT` no están cubiertos (TD-044).
- Auditoría no externa: mismo agente/repositorio.

## Evidencias remotas/manuales pendientes

- [MV-001](../../baseline/MANUAL_VALIDATION_LEDGER.md): E2E frontend + Keycloak + SQL Server + SSE — **PENDIENTE**, no presumido.
- MV-004: CI remoto — PENDIENTE.
- Verificación del frontend contra [BACKEND_GOLDEN_PATH_CONTRACT](../../contracts/BACKEND_GOLDEN_PATH_CONTRACT.md) — pendiente (habilita LB-001C).
