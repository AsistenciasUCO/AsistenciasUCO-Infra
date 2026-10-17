---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# Encargo integral de ejecución Q1–Q4 para Codex / Claude

## Objetivo y autoridad
Trabajar únicamente en el repositorio `alejovh12/AsistenciasUCO`, PR #15, rama `jose-valencia/lb-004-stateless-serverless-readiness`; actualizar a HEAD remoto antes de comenzar. Asegurar calidad real de la migración JPA-only y storage foundation, sin alterar políticas ni la base de datos congelada. La etapa de tests de este archivo es autoría del rol tester, **todavía sin compilar ni ejecutar**.

Lee: `AGENTS.md`; `.claude/skills/uco-quality-gate/SKILL.md`, `uco-testing`, `uco-files`, `uco-persistencia`, `uco-seguridad`; `docs/governance/SOURCE_OF_TRUTH.md`, `DEFINITION_OF_READY.md`; `docs/testing/TESTING_STANDARD.md`, `.github/CI.md`; `QUALITY-PR15-recovery/{PLAN,TEST_PLAN,COVERAGE_MATRIX,SONAR_TRIAGE,VALIDATION,HANDOFF}.md`; `LB-004-stateless-serverless-readiness/{PAUSE,PROFESSOR_DECISION,CONTENT_SECURITY,E2E_PLAN,METADATA_CONTRACT_TARGET}.md`; `LB-008-jpa-only-persistence-migration/{PLAN,VALIDATION}.md`.

## Fase 1 — Preflight, recuperar evidencia exacta y baseline
1. Confirmar `git status --short`, rama, SHA, `origin/develop`, merge-base. Nunca `git clean/reset/stash/rebase` automático, nunca perder cambios de otros.
2. Comprobar JDK 25, Maven wrapper, variables requeridas en entorno (sin imprimir secretos), Docker/SQL Server/MinIO/ClamAV disponibles cuando se necesiten.
3. Obtener **issues exactos de SonarCloud** del PR y SHA analizado (issue key, rule key, tipo, severidad, línea, dataflow, condición que denuncia). Rating C no prueba cuál clase/renglón es culpable. Registrar información en SONAR_TRIAGE, respetando datos confidenciales.
4. Reproducir pipeline normal `./mvnw -B -ntp clean verify`, comprobar reportes Surefire, JaCoCo XML, ArchUnit, OpenAPI, tests skipped. Distinguir fallos intencionales RED de errores de setup y del quality gate previo. Baseline histórico 48.4% New Code, 82.6% JaCoCo global, Security C, Reliability C; métricas históricas no reutilizables como resultados presentes.

## Fase 2 — Certificar las suites RED candidatas y reparar tests inválidos
Ejecutar en grupos con Java 25:
```powershell
.\mvnw.cmd -B -ntp "-Dtest=ClamAvProtocolBoundaryTest,CompressionPolicyExpansionBoundaryTest,MinioReadBudgetTest" test
.\mvnw.cmd -B -ntp "-Dtest=ParameterCatalogJpaBehaviorTest,MessageCatalogJpaBehaviorTest,CoreViewJpaProjectionBehaviorTest,AcademicViewJpaProjectionBehaviorTest,ArchivoControllerSecurityBoundaryTest" test
```
- **NO asumir que compilan**. Los tests se escribieron sin JDK25 ni Maven accesible. Comprobar imports, excepciones, tipos MinIO/Mockito/JPA, respuestas socket clamd con delimitador NUL, fixtures y nombres de métodos del modelo. Los tres anteriores también eran candidatos no certificados.
- Un error de compilación o stub inválido NO es RED funcional. En rol tester corregir solamente `src/test/**`, explicar cada corrección y registrar commit/hash de nueva congelación RED. No modificar producción para arreglar una prueba mala.
- Clasificar pruebas actuales GREEN de regresión vs tests RED causales. Comprobar que el test falla contra un comportamiento incorrecto y pasa cuando el comportamiento es correcto; asegurar que asserts no codifiquen accidentalmente la implementación actual.
- Revisión especial: ClamAV debe rechazar respuesta malformada y EOF; comprobar protocolo clamd y parser con proveedor real antes de endurecer; MinIO read budget debe distinguir límites de bytes originales vs comprimidos y evitar lectura ilimitada; CompressionPolicy deber limitar inflate; code/null JPA debe conservar semántica del baseline. Algunos tests requieren decisiones de contrato y podrían quedar `TEST_CONTRACT_CONFLICT` hasta aprobación.
- No declarar RED aprobado sin: base SHA, paths, SHA-256, comando, exit code, test, fallo exacto semántico, controles positivos y responsable de revisión.

## Fase 3 — Q2: Seguridad, compresión, storage (implementación completa)
Con RED certificado y DoR READY del lote, implementar exclusivamente las correcciones justificadas. Sub-bloques:
A. `ClamAvMalwareScanAdapter`: reconocer únicamente respuesta CLEAN exacta del protocolo; reconocer FOUND por forma legítima; error/EOF/timeout desconocidos fail closed; limitar respuesta/tiempo, no filtrar payload.
B. `MinioFileStorageAdapter`: lectura acotada basada en tamaño real autorizado (original/almacenado) y metadata consistente; ausencia de objeto traduce not found; otras excepciones técnicas no enmascaran 404; cierre del stream. No consumir el objeto entero antes de validar presupuesto.
C. `CompressionPolicy`: expansión limitada, checksum sobre bytes originales, sin corromper PDFs/PNG/JPEG; umbral beneficio >=10%, tamaño máximo 5MiB original; no introducir zip genérico ni degradar datos válidos.
D. `ArchivoController` y use cases: identidad antes de almacenamiento/descarga, sanitización de nombre y cabeceras, Content-Type verificado, no revelar archivo ajeno. Respetar HTTP/status congelados y negar acceso docente hasta binding DB liberado; no inventar auth claims ni exposición directa MinIO.
E. Obtener issues Sonar exactos y corregirlos por causa real aunque no coincidan con los riesgos anteriores; añadir test RED por issue de ser factible.
Tras cada bloque: tests dirigidos, verify normal, integration real en entorno controlado, evidencia y commit pequeño. El implementador no altera los tests RED congelados.

## Fase 4 — Q3: recuperar cobertura de JPA sin reintroducir JDBC
- Ejecutar casos de ParameterCatalog y MessageCatalog: cache hit/miss, valores ausentes, formatos, conversiones tipadas, excepción provider preservada, consulta JPQL parametrizada; no inferir que EntityManager mock comprueba SQL real.
- Academic/Core projection mappers: proyecciones **completas**, nulos, flag BIT/INT, UTC sesión y LocalTime de horario (no desplazar horas académicas). Contrastar null vs string "null" con oracle JDBC test-only y aprobar el contrato antes de cambiar código.
- Inventariar tests JDBC eliminados (por archivo/contrato), encontrar suite JPA actual y brecha real; preservar paridad queries/commands SP de cuatro campos, transacciones y rollback. Sin nuevas dependencias JDBC productivas.
- Integración real contra SQL Server con `-Pintegration`, usando fixtures aislados y sin mutar DB ajena. Revisar `CatalogJpaParityIT`, `AcademicQueryJpaParityIT`, `AuthorizationReportJpaParityIT` y suites JPA vigentes; reparar gaps con tests IT si falta escenario; anotar skips. Aumentar cobertura por comportamiento, no por getters/trucos Sonar.
- Si falta tiempo/contrato de integración, registrar `VALIDATION_BLOCKED_BY_ENVIRONMENT`; no afirmar PASS.

## Fase 5 — Q4: verificar y preparar merge
- `./mvnw -B -ntp clean verify` pasa con Java25, JUnit/ArchUnit/OpenAPI/JaCoCo.
- `./mvnw -B -ntp clean verify -Pintegration` pasa cuando entorno/fixture existe; separar reports Failsafe.
- Analizar nueva cobertura JaCoCo global LINE >=80% BRANCH >=70%; Sonar New Code >=80% Security A Reliability A para el **mismo nuevo SHA**; cerrar issue key/rule con verificación, no ocultarlo en plataforma.
- CodeQL/Dependency Review según required checks; Docker/JAR construidos si el workflow los ejecuta; no declarar skipped PASS.
- Actualizar VALIDATION/COVERAGE_MATRIX/SONAR_TRIAGE con cifras nuevas y evidencia (links, run IDs, timestamps, exit codes). Auditor revisa sin implementar; cierre evalúa DoD.
- Solicitar revisión y aprobación para el merge; **no hacer merge automáticamente**. No bajar umbrales Sonar, no modificar config/exclusions, no force push, no suprimir tests ni secrets.

## Separación obligatoria respecto de LB-004 funcional
En este PR se recupera calidad del código ya presente. Contrato durable `fileId→revisión→sesión→grupo→docente` sigue `BLOCKED_BY_DB_CONTRACT` y pertenece al owner DB. No añadir schema/SP ni cambiar Angular durante Q2/Q3. Después del merge autorizado, iniciar fase separada DB→backend JPA attach/ownership→Angular HttpClient Bearer→E2E estudiante/docente→purga/retención. No marcar LB-004 CLOSED por sólo pasar CI.

## Formato final del reporte de ejecución
Producir: HEAD/base/branch; tabla por issue Sonar key+fix; tabla por suite RED/compilation/GREEN; contratos aprobados/conflictos; archivos modificados; commits por lote; métricas nuevas por clase Sonar/JaCoCo; resultados Maven/SQL MinIO/ClamAV; skips y fallos; amenazas y mitigación; required checks GitHub; riesgos residual; decisión `PR_READY_FOR_REVIEW` o `BLOCKED`, sin exagerar evidencias.
