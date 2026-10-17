---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# SEC-001 — Scan externo postmerge con Trivy + evidencia ArchUnit

## Objetivo
Atender indicación del profesor Farid (25/09/2026): tras Sonar ejecutar Trivy para dependencias/imagen y ArchUnit para arquitectura. PR #15 fusionado en develop (merge SHA 551594179c2de582cbe62b4490276879d1ffc886); escaneo externo aún NO realizado al crear este plan.

## AS-IS comprobado
- `develop` contiene PR #15; su nuevo Backend Security (CodeQL) aprobó, Backend CI postmerge estaba ejecutándose en la consulta.
- `pom.xml` incluye `archunit-junit5:1.4.2`; 20 clases de tests bajo `src/test/java/.../architecture`, incluidas reglas CleanArchitecture, controllers/InputPorts, JPA y StorageProviderIsolation.
- `backend-ci.yml` ejecuta Maven `clean verify`, que incluye JUnit/ArchUnit, pero no había reporte separado de arquitectura.
- `.github/workflows` tenía backend-ci, security(CodeQL/Dependency Review), integration (manual). No Trivy.
- Trivy y Docker no disponibles en el entorno de análisis; no inventar reportes ni cantidades de CVE.

## TARGET y contratos
Nueva workflow `security-deep-scan.yml` independiente con:
1. ArchUnit dirigido Java25: ejecuta 20 clases existentes y conserva XML.
2. Trivy filesystem: vulnerabilidades HIGH/CRITICAL y configuraciones, SARIF.
3. Trivy imagen: compila Dockerfile productivo del commit y analiza paquetes OS/bibliotecas, SARIF.
4. Publica SARIF en Code Scanning y artifacts con retención 21 días.

## Seguridad de cadena de suministro
Trivy registró incidente oficial marzo de 2026: tags comprometidos; usar `aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25` (commit de tag firmado v0.36.0) con `version: v0.74.0` verificadas en repositorio upstream. Dependencia interna `setup-trivy` usa SHA fijo en action.yaml. NO usar `@latest` ni tags mutables en estas acciones.

## Escenario y política inicial
- Change class: INFRASTRUCTURE (CI solo) + DOCUMENTATION; sin src/**/SQL/pom ni secretos.
- PRIMARY_VARIABLE: evidencia reproducible seguridad/arq.
- ALLOWED: `.github/workflows/security-deep-scan.yml`, `docs/testing/TRIVY_ARCHUNIT_RUNBOOK.md`, `docs/work-items/SEC-001-trivy-archunit/**`, `.github/CI.md`, `docs/README.md`.
- FORBIDDEN: `develop` directo; código Java, migraciones DB, Angular, gates existentes.
- Contratos funcionales: NO CAMBIAN; Providers: acciones GitHub y scanner Trivy.
- Inicialmente `exit-code: 0` al hallar CVE: **INVENTARIO**, NO APROBACIÓN DE SEGURIDAD. Errores de runner/herramienta siguen fallando el job. El owner debe fijar severidades/aceptación/allowlist de vulnerabilidades con evidencia; entonces cambiar por nueva microfase a `exit-code: 1` de forma deliberada.
- SARIF/paths pueden ser sensibles: no imprimir secretos en logs, no subir archivos .env ni dumps de secretos. Scanner secret está excluido del primer reporte para prevenir exposición accidental; se planificará modo privado/controlado y revisión.
- Stop: vulnerabilidades críticas reales en base image/config se elevan; rollback = revert del PR de workflow, sin tocar backend.
- DoR para crear PR de escaneo: READY. DoD de SEC-001: **PENDIENTE** hasta runs reales en GitHub, XML ArchUnit, SARIF y triage de findings.

## Próxima ejecución
Abrir PR contra develop; la workflow debe correr por `pull_request`. Revisar acciones de repo, permisos `security-events:write` y disponibilidad de base de datos Trivy. Registrar runId/SHA, 20 clases presentes, CVEs reales con CVE/pkgs/fixedVersion/exposure, severidad, remediation owner y bloqueos; preservar reportes sin falsa afirmación "0 vulnerabilidades". No fusionar PR automáticamente.
