---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# SEC-001 — plan de certificación por escenarios

| ID | Requisito | Observación | Wrong implementation caught | Nivel |
|---|---|---|---|---|
| ARCH-01 | 20 clases arquitectura | Surefire XML de los 20 tipos, 0 failures/errors/skips | report vacío o clase excluida | JDK25/JUnit/ArchUnit |
| ARCH-02 | Isolation In/Out Ports | RulesTest falla al añadir dependencia Domain→Infrastructure | capa corrupta aceptada | ArchUnit |
| ARCH-03 | Storage/MinIO isolation | Rule prohíbe SDK MinIO fuera de adapter dedicado | dependencia importada en UseCase | ArchUnit |
| ARCH-04 | JPA-only | Rule prohíbe JDBC en Repository JPA | reintroducción JDBC | ArchUnit |
| TRV-01 | repo packages/config | SARIF fs conserva findings HIGH/CRITICAL | dependencias/config ignoradas silenciosamente | Trivy fs |
| TRV-02 | imagen **construida** del SHA | SARIF imagen evalúa OS/JVM dependencias reales | escanear imagen remota/desactualizada | Trivy image |
| TRV-03 | supply chain | action fijo a SHA seguro y Trivy versión explícita | tag mutable secuestrado | static review |
| TRV-04 | permisos least privilege | token read, security-events write solo jobs SARIF | token admin innecesario | workflow audit |
| GATE-01 | no confundir inventory y PASS | CVEs hallados registrados en triage, aunque exit-code 0 | declarar ausencia CVE por workflow verde | auditor |

Ejecución remota NO EJECUTADA durante autoría documental. ArchUnit ya corre en backend-ci; ejecución dirigida añade evidencia visible. Policy report-only primera ronda; convertir en required check por decisión posterior, con excepciones justificadas. No modificar tests/código funcional, ni cambiar expected para pasar.
