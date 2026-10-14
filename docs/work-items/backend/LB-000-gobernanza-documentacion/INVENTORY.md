---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# Inventario previo LB-000

Fecha: 2026-09-20. HEAD inicial: `fa9aa901c73e55ae31071f4e74cfb2245189243a`. 1043 archivos versionados; 71 Markdown/YAML candidatos. Estado inicial: únicamente el paquete temporal estaba sin seguimiento.

Se recorrieron archivos versionados y Markdown/YAML ocultos del paquete. `.claude/worktrees/` contiene estado local: no se leyó como autoridad, no se movió y no se incorporó a Git. `.workspace/plans` y `.workspace/validation` no existen en la raíz. `.env` no se imprimió ni se usó para documentación. Binarios, cachés, uploads y salidas de build no son fuentes documentales.

| Archivo | Propósito actual | Autoridad inicial | Estado inicial/clasificación | Destino propuesto | Acción |
|---|---|---|---|---|---|
| `.github/CI.md` | Referencia técnica existente | runbook / evidencia AS-IS | active | `.github/CI.md` | `KEEP` |
| `.github/workflows/backend-ci.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `.github/workflows/backend-ci.yml` | `KEEP` |
| `.github/workflows/integration.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `.github/workflows/integration.yml` | `KEEP` |
| `.github/workflows/security.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `.github/workflows/security.yml` | `KEEP` |
| `HELP.md` | Ayuda generada de Spring; no arquitectura | historical | superseded | `docs/archive/HELP.md` | `MOVE` |
| `README.md` | Referencia técnica existente | normative | active | `README.md` | `KEEP` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/agents/1-planificador.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/agents/01-planificador.md` | `RENAME` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/agents/2-contratos.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/agents/02-contratos.md` | `RENAME` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/agents/3-tester-red.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/agents/03-tester-red.md` | `RENAME` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/agents/4-implementador.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/agents/04-implementador.md` | `RENAME` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/agents/5-validador.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/agents/05-auditor.md` | `RENAME` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/agents/6-cierre.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/agents/06-cierre.md` | `RENAME` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/skills/uco-arquitectura/SKILL.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/skills/uco-arquitectura/SKILL.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/skills/uco-baseline/SKILL.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/skills/uco-baseline/SKILL.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/skills/uco-contratos/SKILL.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/skills/uco-contratos/SKILL.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/skills/uco-jpa/SKILL.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/skills/uco-persistencia/SKILL.md` | `RENAME` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/skills/uco-testing/SKILL.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/skills/uco-testing/SKILL.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/templates/PLAN.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/templates/PLAN.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/templates/TECH_DEBT_ENTRY.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/templates/TECH_DEBT_ENTRY.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/templates/TEST_PLAN.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/templates/TEST_PLAN.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.claude/templates/VALIDATION.md` | Paquete temporal de gobernanza | propuesta | draft | `.claude/templates/VALIDATION.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/.workspace/README_ONLY/README.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/work-items/README.md` | `DELETE_AFTER_MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/AGENTS.md` | Paquete temporal de gobernanza | propuesta | draft | `AGENTS.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/CLAUDE.md` | Paquete temporal de gobernanza | propuesta | draft | `CLAUDE.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/MANIFEST.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/archive/governance-pack/MANIFEST.md` | `ARCHIVE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/PROMPT_01_INSTALAR_GOBERNANZA.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/archive/governance-pack/PROMPT_01_INSTALAR_GOBERNANZA.md` | `ARCHIVE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/PROMPT_02_PLANIFICAR_GOLDEN_PATH_Y_JPA.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/archive/governance-pack/PROMPT_02_PLANIFICAR_GOLDEN_PATH_Y_JPA.md` | `ARCHIVE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/adr/ADR-001-golden-path-asistencia.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/adr/ADR-001-golden-path-asistencia.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/adr/ADR-002-jpa-incremental.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/adr/ADR-002-jpa-incremental.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/ai/README.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/governance/DOCUMENTATION_POLICY.md` | `DELETE_AFTER_MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/ai/REFERENCE_ADAPTATION.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/governance/REFERENCE_ADAPTATION.md` | `MOVE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/baseline/DEFINITION_OF_DONE.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/baseline/DEFINITION_OF_DONE.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/baseline/GOLDEN_PATH_ASISTENCIA.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/baseline/GOLDEN_PATH_ASISTENCIA.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/baseline/LINEA_BASE.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/baseline/LINEA_BASE.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/baseline/MANUAL_VALIDATION_LEDGER.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/baseline/MANUAL_VALIDATION_LEDGER.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/baseline/TECHNICAL_DEBT.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/baseline/TECHNICAL_DEBT.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/contracts/OPENAPI_STANDARD.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/contracts/OPENAPI_STANDARD.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/persistence/JDBC_TO_JPA.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/persistence/JDBC_TO_JPA.md` | `MERGE` |
| `asistencias-uco-ai-governance-pack/asistencias-uco-ai-governance-pack/docs/testing/TESTING_STANDARD.md` | Paquete temporal de gobernanza | propuesta | draft | `docs/testing/TESTING_STANDARD.md` | `MERGE` |
| `docker-compose.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `docker-compose.yml` | `KEEP` |
| `docs/architecture/adapter-composition-standard.md` | Referencia técnica existente | normative | active | `docs/architecture/adapter-composition-standard.md` | `KEEP` |
| `docs/architecture/backend-package-structure.md` | Referencia técnica existente | normative | active | `docs/architecture/backend-package-structure.md` | `KEEP` |
| `docs/architecture/backend-roadmap.md` | Evoluciones a LINEA_BASE; deudas al ledger | historical | superseded | `docs/archive/backend-roadmap.md` | `ARCHIVE` |
| `docs/architecture/external-services.md` | Referencia técnica existente | normative | active | `docs/architecture/external-services.md` | `KEEP` |
| `docs/architecture/http-command-query-guidelines.md` | Referencia técnica existente | normative | active | `docs/architecture/http-command-query-guidelines.md` | `KEEP` |
| `docs/architecture/http-success-responses.md` | Referencia técnica existente | normative | active | `docs/architecture/http-success-responses.md` | `KEEP` |
| `docs/architecture/infrastructure-refactor-mapping.md` | Arqueología del refactor, no norma | historical | superseded | `docs/archive/infrastructure-refactor-mapping.md` | `MOVE` |
| `docs/architecture/infrastructure-structure.md` | Referencia técnica existente | normative | active | `docs/architecture/infrastructure-structure.md` | `KEEP` |
| `docs/architecture/input-validation.md` | Referencia técnica existente | normative | active | `docs/architecture/input-validation.md` | `KEEP` |
| `docs/architecture/pendientes-arquitectura.md` | Deuda DB trasladada a TECHNICAL_DEBT | historical | superseded | `docs/archive/pendientes-arquitectura.md` | `ARCHIVE` |
| `docs/architecture/reactive-realtime.md` | Referencia técnica existente | normative | active | `docs/architecture/reactive-realtime.md` | `KEEP` |
| `docs/backend-baseline-contract.md` | Matriz HTTP estática; deudas DB al ledger | AS-IS | superseded | `docs/contracts/HTTP_AS_IS_MATRIX.md` | `RENAME` |
| `docs/integration/frontend-contract-alignment.md` | Comparación frontend antigua; nueva guía sin suponer consumidor | historical | superseded | `docs/archive/frontend-contract-alignment.md` | `ARCHIVE` |
| `docs/integration/repository-mock-inventory.md` | Referencia técnica existente | runbook / evidencia AS-IS | active | `docs/integration/repository-mock-inventory.md` | `KEEP` |
| `docs/integration/sqlserver-connection.md` | Referencia técnica existente | runbook / evidencia AS-IS | active | `docs/integration/sqlserver-connection.md` | `KEEP` |
| `docs/repository-cleanup.md` | Precauciones históricas de uploads; seguimiento TD-024 | historical | superseded | `docs/archive/repository-cleanup.md` | `ARCHIVE` |
| `docs/security/keycloak-identity-provider.md` | Referencia técnica existente | normative | active | `docs/security/keycloak-identity-provider.md` | `KEEP` |
| `docs/security/keycloak-service-account.md` | Referencia técnica existente | normative | active | `docs/security/keycloak-service-account.md` | `KEEP` |
| `docs/security/runtime-security-provider-architecture.md` | Referencia técnica existente | normative | active | `docs/security/runtime-security-provider-architecture.md` | `KEEP` |
| `docs/testing/backend-validation-guide.md` | Referencia técnica existente | runbook / evidencia AS-IS | active | `docs/testing/backend-validation-guide.md` | `KEEP` |
| `infra/keycloak/README.md` | Referencia técnica existente | runbook / evidencia AS-IS | active | `infra/keycloak/README.md` | `KEEP` |
| `infra/keycloak/compose.yaml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `infra/keycloak/compose.yaml` | `KEEP` |
| `infra/observability/compose.yaml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `infra/observability/compose.yaml` | `KEEP` |
| `infra/observability/grafana/provisioning/dashboards/dashboards.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `infra/observability/grafana/provisioning/dashboards/dashboards.yml` | `KEEP` |
| `infra/observability/grafana/provisioning/datasources/datasources.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `infra/observability/grafana/provisioning/datasources/datasources.yml` | `KEEP` |
| `infra/observability/loki/loki-config.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `infra/observability/loki/loki-config.yml` | `KEEP` |
| `infra/observability/prometheus/prometheus.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `infra/observability/prometheus/prometheus.yml` | `KEEP` |
| `infra/observability/tempo/tempo.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `infra/observability/tempo/tempo.yml` | `KEEP` |
| `src/main/resources/application.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `src/main/resources/application.yml` | `KEEP` |
| `src/test/resources/application-integration.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `src/test/resources/application-integration.yml` | `KEEP` |
| `src/test/resources/application.yml` | Configuración ejecutable/CI; inspección sin edición | evidencia AS-IS | active | `src/test/resources/application.yml` | `KEEP` |

Las acciones MERGE/RENAME del paquete incluyen su retirada tras comprobar destinos. Los archivos CREATE y el resultado definitivo constan en el informe de cierre. KEEP permite corregir enlaces, clasificación y afirmaciones obsoletas con evidencia; no cambia funcionalidad.
