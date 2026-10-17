---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# QUALITY-PR15 — Q0 VALIDATION

## Clasificación
DOCUMENTATION_ONLY; no se modificó Java, SQL, frontend, pom, workflow ni contrato. RED Java NO APLICA. No se ejecutaron Maven, JUnit, SQL Server, MinIO, ClamAV ni E2E en Q0.
Baseline PR antes de Q0: 4cae0a3f5b0302b9a634932905e6bb04cd36411b.
Evidencia remota anterior: clean verify PASS, Sonar FAIL, new coverage 48.4%, Security C, Reliability C; CodeQL PASS histórico.
Q0 solamente valida enlaces/scope/documentación al publicar. Quality Gate PR y Q2/Q3/Q4 quedan OPEN, nunca PASS por esta escritura.
## Matriz
| Check | Estado | Límite |
|---|---|---|
| Gobernanza/DoR/DoD/CI leídos | PASS documental | no revisión runtime |
| Archivos/rutas/enlaces | comprobar después de commit | consulta GitHub tree |
| Sólo documentación | comprobar diff del nuevo commit | no funcional |
| Java 25 / Maven | NOT_RUN | no aplica Q0 |
| RED/GREEN funcional | NOT_RUN | corresponde Q2/Q3 |
| Sonar post-push | PENDING | nuevo SHA |
| SQL/MinIO/ClamAV/E2E | NOT_RUN | integración posterior |
| Issues Sonar exactos | NOT_RETRIEVED | Q1 |

No declarar DONE integral ni LB-004 CLOSED a partir de Q0. Auditoría independiente humana pendiente.

## Candidate unit tests added after Q0
Three **new src/test/** files were authored; no src/main, DB, pom or runtime configuration changed. JDK25 and dependencies were not available for reliable Maven verification in the authoring environment (Java21 only). State: TEST_SOURCE_PREPARED / COMPILATION_NOT_RUN / RED_NOT_CERTIFIED / GREEN_NOT_RUN. Codex/Claude must run directed tests, repair test-only compilation defects through tester role and record exact RED cause and SHA before implementation. Existing CI will remain red intentionally until correct implementation. No Sonar issues attributed to these tests. Q0 documentation remains a separate completed commit.

## Ampliación del alcance TESTER (candidatos, no certificados)

Se añadieron cinco nuevas suites de pruebas unitarias JPA/mappers/seguridad (29 casos) y dos escenarios adicionales en ClamAvProtocolBoundaryTest (FOUND válido y respuesta ERROR). Ninguna fue ejecutada con Java25; compilación NO VERIFICADA, RED NOT_RUN, GREEN NOT_RUN; validar aislamiento antes de implementar. Esta iteración modifica src/test/** + documentación, no src/main/**. La ejecución de `clean verify` en CI podría fallar por los RED deliberados: no confundir ese estado con regresión de producción o CI recuperado. El auditor debe verificar validez de los mocks y tipos Mockito/JUnit antes de atribuir el fallo a funcionalidad.

## Q1–Q3 ejecución con Java 25 (2026-10-08, Claude; independencia limitada tester/implementador)
Base `31dbddd`; HEAD validado `812a313b78c0d873afd5db21daf8c2d88fe3e17d`. Entorno: Windows 11, JDK 25 (`mvnw.cmd`), SQL Server local `gestionasistenciadb`, MinIO y ClamAV de `infra/files` (contenedores sanos). Credenciales cargadas desde `.env` sin imprimirse.

| Check | Comando | Resultado |
|---|---|---|
| Compilación de las 8 suites candidatas | `mvnw -B -ntp test-compile` | PASS (exit 0) |
| Certificación RED inicial (8 suites) | ver RED_SNAPSHOT §1 | 37 tests, 5 failures, 0 errors (exit 1) |
| RED congelado (12 suites) | ver RED_SNAPSHOT §4, commit `de714e8` | 79 tests, 25 failures semánticas, 0 errors (exit 1) |
| GREEN Q2 dirigido | `-Dtest=ClamAv*Boundary*,CompressionPolicy*Test,MinioReadBudgetTest,ByteArrayRecordValueSemanticsTest,DescargarArchivo*Test,SubirArchivo*Test,ArchivoController*Test,ContentSecurityValidatorTest` | 91/91 PASS (exit 0) |
| Provider IT Q2 (ClamAV + MinIO + flujo HTTP) | `-Pintegration -Dit.test=ClamAvMalwareScanAdapterIT,MinioFileStorageAdapterIT,ArchivoUploadDownloadFlowIT` | 11/11 PASS, 0 skips (exit 0); EICAR detectado |
| GREEN Q3 dirigido | `-Dtest=CoreView*Test,EstudianteJpaQueryContractTest,AcademicView*Test,*Catalog*Test,JpaRepository*Test` | 110/110 PASS (exit 0) |
| Paridad SQL Server Q3 | `-Pintegration -Dit.test=CoreViewQueriesJpaParityIT,AcademicQueryJpaParityIT,CatalogJpaParityIT,AuthorizationReportJpaParityIT` + `EstudianteAcademicFilterJpaParityIT` | 29/29 + 3/3 PASS, 0 skips |
| `clean verify` final (HEAD 812a313) | `mvnw -B -ntp clean verify` | **1443 tests, 0 failures, 0 errors, 0 skipped**; ArchUnit/OpenAPI incluidos; JaCoCo check PASS (exit 0) |
| JaCoCo global (mismo run) | `target/site/jacoco/jacoco.xml` | **LINE 90.25 %, BRANCH 80.22 %** (gate 80/70) |
| Estimación New Code (diff `0b7905c..HEAD`, src/main, líneas+condiciones JaCoCo) | script local sobre XML | 87.6 % (líneas 1475/1644, ramas 357/448). Estimación: **no** sustituye a Sonar |
| Integración completa | `mvnw -B -ntp -Pintegration -Dtest=NoSuchUnitTest -Dsurefire.failIfNoSpecifiedTests=false -Djacoco.skip=true verify` | **191 IT, 0 failures, 0 errors, 1 skipped** (exit 0). Skip: `DocenteRepositorySqlServerIT`, `assumeTrue` por ausencia de docente con múltiples asignaciones en la DB local (preexistente, no tocado) |

Primera corrida de `clean verify` (HEAD `c741b66`, antes de las suites de cobertura): 1389 tests PASS, LINE 85.05 % / BRANCH 76.70 %, New Code estimado 62.5 %.

## Evidencia remota (mismo SHA)
| SHA | Check | Resultado |
|---|---|---|
| 812a313 | Backend Quality Gate (run 37745…, job 113203694471) | FAIL solo por el paso Sonar `qualitygate.wait` (Reliability E por S2095/S5863 nuevos); Maven verify y JaCoCo previos PASS |
| 812a313 | SonarCloud | coverage 87.47 %, Security A, Reliability E → corregido en ab3e9fa |
| 812a313 | CodeQL / CodeQL Java / Dependency Review | PASS |
| **ab3e9fa** | Backend Quality Gate — https://github.com/alejovh12/AsistenciasUCO/actions/runs/37745656337/job/113206399619 | **PASS** |
| **ab3e9fa** | SonarCloud Code Analysis — https://github.com/alejovh12/AsistenciasUCO/runs/113207525976 | **PASS**: new_coverage 87.5 %, Reliability A, Security A, Maintainability A, duplicación 1.6 %, hotspots 100 %; 0 issues SECURITY/RELIABILITY abiertos |
| **ab3e9fa** | CodeQL — https://github.com/alejovh12/AsistenciasUCO/runs/113207348986 | PASS |
| **ab3e9fa** | CodeQL Java Analysis — job 113206400160 | PASS |
| **ab3e9fa** | Dependency Review — job 113206399920 | PASS |

Local para ab3e9fa: `clean verify` 1443 tests PASS, JaCoCo LINE 90.24 % / BRANCH 80.22 %.
Estado: **PR_READY_FOR_REVIEW** (gates de calidad verdes). Merge a `develop` NO realizado: requiere revisión y autorización humana. Auditoría independiente pendiente (tester e implementador fueron la misma herramienta). LB-004 funcional sigue abierto: `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT`, docente `DENY_BY_DEFAULT`; sin cambios de esquema SQL ni Angular en este PR.

## Adenda de revisión independiente estática (2026-10-08, HEAD 2554312)

Ver [INDEPENDENT_REVIEW](INDEPENDENT_REVIEW_2026-10-08.md). GitHub confirmó para este HEAD: Backend CI SUCCESS (run 37746517241), Backend Security SUCCESS (run 37746517267); comentario Sonar Quality Gate PASSED, new coverage 87,5 %, duplicación 1,6 %, 206 issues nuevos y 0 accepted issues. No atribuir tipología a esos 206 hasta exportar issue inventory. Esta revisión no ejecutó Java/Docker/DB ni validó frontend. Persiste un IT saltado según VALIDATION del implementador; evidencia independiente y excepción/reproducción del fixture pendientes. Estado recomendado: `PR_READY_FOR_HUMAN_REVIEW_WITH_RESIDUAL_ACTIONS`, no merge automático, no LB-004 DONE.
