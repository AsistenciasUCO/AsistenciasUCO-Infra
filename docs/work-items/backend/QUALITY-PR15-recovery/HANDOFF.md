---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# Handoff para Codex y Claude — PR #15

**Lectura obligatoria:** AGENTS.md → uco-quality-gate → PLAN → SONAR_TRIAGE → COVERAGE_MATRIX → TEST_PLAN → VALIDATION; cargar uco-files/testing/seguridad/persistencia según caso.

## Q1, primera sesión: solo diagnóstico
- Ejecutar git fetch y git status --short; verificar rama actual, HEAD y merge-base contra origin/develop; no reset/clean/stash automático.
- Recuperar nuevo run, SHA y issues de Sonar (key, rule, file:line, severity, dataflow) y reproducir condiciones con evidencia sanitizada.
- Confirmar XML JaCoCo importado, diferencia entre New Code y BUNDLE, unidad Surefire vs integración Failsafe.
- Completar SONAR_TRIAGE y COVERAGE_MATRIX. Si issues no recuperables, bloqueo explícito.
- PLAN funcional acotado y DoR READY independiente; Q0 documental no autoriza Java.
## Q2 almacenamiento/seguridad
Tester RED causal (ClamAV protocolo/errores; MinIO SDK/metadata; lectura e inflate acotados; checksum; response headers), snapshot commit/hash, implementador GREEN sin editar RED, unit Surefire + MinIO/ClamAV IT. Sin nuevo permiso docente.
## Q3 JPA
Mapear pruebas JDBC retiradas al contrato observable y equivalentes JPA, cubrir mappers/catalogos/queries y negativos; EntityManager mock solo unit; SQL Server real para IT/paridad. JPA-only permanece.
## Q4 cierre PR
Por commit: Maven clean verify Java25, ArchUnit/OpenAPI, JaCoCo XML nuevo, -Pintegration según alcance, push sin force, inspeccionar Sonar New Code >=80%/Security A/Reliability A y GitHub CodeQL/Dependency Review/Docker. Registrar skips, issues y SHA. No hacer merge hasta aprobación humana.
## LB-004 separada
Tras Q4 merge aprobado: equipo DB decide/libera metadata y relación fileId→revisión; backend JPA integra attach/ownership docente; Angular usa fileId/HttpClient Bearer y límite 5MiB; E2E real estudiante→docente; purga y cold tier bajo decisiones aprobadas. PAUSE no se reescribe retroactivamente.

## Immediate handoff: tests already committed (unverified)
Before touching production: use Java 25 and run `./mvnw -B -ntp -Dtest=ClamAvProtocolBoundaryTest,CompressionPolicyExpansionBoundaryTest,MinioReadBudgetTest test` (Windows: `.\\mvnw.cmd -B -ntp '-Dtest=ClamAvProtocolBoundaryTest,CompressionPolicyExpansionBoundaryTest,MinioReadBudgetTest' test`). Record compiler errors separately from true assertion RED; if the SDK mock or fake socket helper needs a test-only correction, do it with tester role and re-freeze test SHA before implementation. Confirm valid controls PASS and malformed/oversize behaviors fail as intended. THEN seek approval/DoR for Q2 implementation and preserve tests unchanged. Sonar issue extraction Q1 is still pending; treat these as independent hardening tests, not a claim of vulnerability identification. See TEST_PLAN and VALIDATION.

## Encargo integral a Codex/Claude

Texto completo, con autoridad y stop conditions, en [IMPLEMENTATION_BRIEF](IMPLEMENTATION_BRIEF.md). Recomendación: ejecutar Q1+validación RED+Q2 y Q3 por lotes pequeños, haciendo test-only repairs primero si corresponde, preservando los hashes de RED. **No** cambiar expected/assertions desde implementador para obtener GREEN. Q4 sólo después de nuevo CI remote SHA.
