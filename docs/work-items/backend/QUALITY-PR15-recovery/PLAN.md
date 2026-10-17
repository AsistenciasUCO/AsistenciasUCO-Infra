---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# QUALITY-PR15 — Etapa cero y programa de recuperación

## Identidad y decisión de alcance
PR: https://github.com/alejovh12/AsistenciasUCO/pull/15
Rama: jose-valencia/lb-004-stateless-serverless-readiness → develop.
SHA auditado: 4cae0a3f5b0302b9a634932905e6bb04cd36411b.
Clase: DOCUMENTATION_ONLY. PRIMARY_VARIABLE: preparar recuperación trazable de PR #15.
Autoridades: AGENTS, SOURCE_OF_TRUTH, DEFINITION_OF_READY, DEFINITION_OF_DONE, TESTING_STANDARD, CI y ADR-003.
No confundir la certificación JPA-only con el cierre funcional de LB-004.

## AS-IS (evidencia histórica, no nueva ejecución)
- GitHub PR abierto y sin conflictos; ahead=1, behind=0 antes de Q0.
- Workflow Backend Quality Gate: Maven clean verify PASS, JaCoCo XML generado; Sonar FAIL; Docker/JAR posteriores omitidos.
- Surefire del run auditado: 1310 tests, 0 fallos. Integration *IT fuera del clean verify estándar.
- Sonar new coverage 48.4% (requiere >=80%), New Code Security C y Reliability C (requiere A/A).
- JaCoCo global LINE 82.6% en reporte auditado; métricas de denominadores distintos.
- CodeQL workflow PASS histórico, no reemplaza Sonar Security.
- Exactas issue keys, reglas, severidades y líneas Sonar: NO RECUPERADAS.
- LB-008 declara DIRECT_JDBC_IN_SRC_MAIN=0; target JPA-only; CI remoto aún bloquea merge.
- LB-004 MinIO/ClamAV foundation histórica GREEN; REVIEW_BINDING DB pendiente, docente E2E pendiente.

## Objetivo / acceptance criteria
1. Q1: extraer todos los issues del PR sobre NEW CODE (key, rule, type, severidad, fichero/línea, causa, reproducción), o reportar BLOCKED_BY_MISSING_EVIDENCE.
2. Q2: tests RED y correcciones reales de seguridad/almacenamiento (protocolo ClamAV fail closed; lectura/descompresión acotadas; MinIO, integridad y cabeceras) con Surefire unit y provider IT correspondiente.
3. Q3: pruebas conductuales JPA/mappers/catálogos/scope y equivalencia de contratos retirados JDBC; SQL Server real para paridad.
4. Q4: mismo SHA de PR con clean verify, ArchUnit, OpenAPI, JaCoCo LINE >=80%, BRANCH >=70%; Sonar New Code Coverage >=80%, Security A, Reliability A; CodeQL/Dependency Review y otros required checks PASS.
5. No bajar gates, alterar exclusions, ignorar vulnerabilities, hacer tests tautológicos ni false positive sin análisis.
6. Mantener el PR #15 y commits de alcance pequeño; no force push ni merge antes de evidencia y aprobación.
7. Tras merge autorizado: retomar LB-004 en trabajo independiente DB → backend → Angular → E2E/retención.

## Allowed / Forbidden paths para Q0
ALLOWED: AGENTS.md, docs/README.md, docs/work-items/README.md, docs/testing/TESTING_STANDARD.md, .github/CI.md, .claude/agents/{01-planificador,03-tester-red,05-auditor,06-cierre}.md, .claude/skills/uco-testing/SKILL.md, nuevos .claude/skills/uco-quality-gate y uco-files, docs/work-items/QUALITY-PR15-recovery/**.
FORBIDDEN: src/**, src/test/**, pom.xml, .github/workflows/**, infra/**, SQL, repos DB/frontend, ADR/contratos congelados, configuraciones Sonar.
CONTRACTS: ninguno modificado. PROVIDERS: ninguno ejercitado. EXTERNAL_ENVIRONMENT: GitHub documental. SECURITY_IMPACT: instrucciones, sin cambio runtime. OBSERVABILITY_IMPACT: NO APLICA.
ROLLBACK: revert de este commit documental sin reescribir historia.
STOP: HEAD divergente, secreto, drift contractual, archivo fuera de scope, ausencia de contrato/RED para implementación.

## Microfases gobernadas
| Fase | Entrega | Gate y responsabilidad |
|---|---|---|
| Q0 | Documentos, skills, handoff | integridad documental; autor documentación |
| Q1 | Triage exacto issues + cobertura por SHA | auditor/planificador; lectura sin cambios runtime |
| Q2 | RED→GREEN seguridad y storage | tester y luego implementador; DoR READY específico |
| Q3 | RED→GREEN JPA y paridad | tester y luego implementador; SQL real y DoR READY |
| Q4 | Verificar gates y cierre PR | auditor y cierre, resultados remotos mismo SHA |
| L4 | Contrato DB metadata/binding | owner repositorio DB, nueva aprobación |
| L5 | Backend attach/ownership docente, frontend, E2E | DB released; pruebas reales |

## Riesgos y bloqueos
- SONAR_ISSUES_UNKNOWN: BLOCKED_BY_MISSING_EVIDENCE para atribución exacta, no para Q0.
- Provider IT separado del gate: no contar cobertura de pruebas NO ejecutadas.
- JDBC→JPA: riesgo de pérdida de equivalencia; inventariar cada test eliminado.
- ClamAV endsWith("OK"), lecturas transferTo sin presupuesto y inflate sin límite: riesgos detectados en auditoría previa, NO issues Sonar atribuidos.
- LB-004: REVIEW_BINDING BLOCKED_BY_DB_CONTRACT; no modificar DB durante QUALITY PR.
- Distinguir evidencia previa de tests repetidos; nunca NOT_RUN=PASS.

## DoR
Q0 DOCUMENTATION_ONLY: READY. Q1 análisis: READY para investigar. Q2/Q3 IMPLEMENTATION: NOT_READY hasta matrices, contrato aprobado y RED causal. LB-004 binding: NOT_READY hasta release DB.
Véanse [TEST_PLAN](TEST_PLAN.md), [COVERAGE_MATRIX](COVERAGE_MATRIX.md), [SONAR_TRIAGE](SONAR_TRIAGE.md), [HANDOFF](HANDOFF.md), [VALIDATION](VALIDATION.md), [PAUSE](../LB-004-stateless-serverless-readiness/PAUSE.md).

## Q2-RED candidate preparation (2026-10-08)
The user authorized the tester role to add three independent unit-test suites ahead of implementation; production remains untouched. Test sources: ClamAvProtocolBoundaryTest, CompressionPolicyExpansionBoundaryTest, MinioReadBudgetTest. Contract sources: CONTENT_SECURITY, MalwareScanPort, FileStoragePort and the existing adapters. They are **UNEXECUTED RED CANDIDATES** until Java25 Surefire confirms compilation and the expected behavioral failures. Q1 exact Sonar issue identification remains pending, so none of these tests is presented as a fix for a confirmed Sonar issue. Q2 implementation DoR remains NOT_READY until tester verifies RED and auditor/contract owners approve the scope. No implementation authorized by this documentation.

## Estado 2026-10-08 (tras Q1–Q3)
Q1 COMPLETADO (SONAR_TRIAGE). Q2/Q3: RED certificado y congelado en `de714e8` (RED_SNAPSHOT), GREEN en `df21fa4`, `c741b66`, `ab3e9fa`; cobertura conductual en `7040b68`, `ac63aa9`, `812a313`. Q4: checks remotos verdes en `ab3e9fa` (VALIDATION). Pendiente: auditoría independiente, decisión `nosniff` y booleano inválido de ParameterCatalog (`DECISION_REQUIRED`), aprobación humana del merge. L4/L5 (LB-004 funcional) sin iniciar.
