---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# SEC-001 — evidencia y estado

PREPARACIÓN: workflow y documentación redactados desde merge develop `551594179c2de582cbe62b4490276879d1ffc886`. Java25/Trivy/Docker **NO EJECUTADOS** por esta herramienta, aún no se dispone de resultados SARIF/CVE. Si el PR genera runs, registrar:
| SHA | Run | ArchUnit clases/tests/skips | Trivy FS findings | Trivy image findings | Verdict |
|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | NOT_RUN | NOT_RUN | NOT_RUN | NOT_CERTIFIED |

Criterio: no afirmar `TRIVY_PASS` solo porque los jobs estén verdes; salida `exit-code:0` significa inventario inicial. Registrar CVEs con ID, severidad, pkg/version, fixed version, incidencia y resolución. Si falla setup/download, no convertirlo en "0 hallazgos". La integración SQL/MinIO/ClamAV no se sustituye por Trivy/ArchUnit.


## 2026-10-08 — Resultados remotos primera ejecución y corrección propuesta

PR #16 HEAD previo `64bf99d50c1184eace534b2289e2d7a8ff2999a9`. Workflow `Backend Deep Security Scan` [run 37868603212](https://github.com/alejovh12/AsistenciasUCO/actions/runs/37868603212):

| Job | Estado comprobado | Evidencia |
|---|---|---|
| ArchUnit Architectural Guardrails | PASS | 82 tests, 0 fails/errors/skips; XML artifact 11588728944 |
| Trivy Production Docker Image Scan | SUCCESS **de ejecución** | Imagen compilada; SARIF subido y artifact 11589532341. No implica CVE-free: exit-code=0 para hallazgos |
| Trivy Repository Vulnerability and Misconfiguration Scan | FAIL por infraestructura | Trivy 0.74.0: Maven Central HTTP 429, `spring-framework-bom-7.0.7.pom`, `Retry-After: 1800`. No generó SARIF; **NO_CERTIFIED** |
| Backend CI / Backend Security del mismo SHA | PASS | runs 37868603126 / 37868603132 |

El 429 **no** es una vulnerabilidad del BOM: el analizador dependía de consultas remotas para resolver el árbol Maven. Mitigación del follow-up: JDK 25, cache Maven en GitHub Actions, `dependency:go-offline dependency:resolve` antes de ejecutar Trivy filesystem. Fuente oficial: https://trivy.dev/docs/dev/guide/references/troubleshooting/ .

**Nuevo scan: PENDIENTE** hasta comprobar próximo run sobre commit que incluye esta modificación. No afirmar que la mitigación es eficaz antes de ejecutar. No usar `--offline-scan` ni omitir `pom.xml`: puede ocultar transitivas. Si persiste 429, documentar reintento tras Retry-After y evaluar mirrors aprobados.

Los hallazgos de imagen de la ejecución inicial requieren inventario CVE por rule-id, paquete, versión instalada/corregida, fix y exposición; el job verde no los resuelve. Ver [triage](TRIAGE-2026-10-08.md).
