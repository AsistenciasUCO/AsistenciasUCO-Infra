---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# VALIDATION — LB-000

Ejecutado el 2026-09-20 sobre base `fa9aa901c73e55ae31071f4e74cfb2245189243a` con cambios sin commit.

**DOCUMENTATION_VALIDATION = PASS**
**TECHNICAL_BUILD_GATE = FAIL** (CF-002 / TD-029, preexistente)

## Checks documentales

| Check | Resultado |
|---|---|
| Markdown versionable/no ignorado inspeccionado | 82 archivos |
| Enlaces locales (rutas y anchors, sin fences ni código en línea) | 585 comprobados, 0 errores |
| Frontmatter en `docs/**` (status/type/scope/owner/last-reviewed; valores permitidos) | 54 archivos, 0 errores |
| Skills (name = carpeta, description, fuentes existentes) | 9, 0 errores |
| Agentes (name = archivo, enlaces existentes) | 6, 0 errores |
| Plantillas | 7 |
| Referencias de fase (`LB-00x`) en AGENTS, CLAUDE y `.claude/**` | 0 |
| Secretos (patrones; solo archivo:línea) | 2 coincidencias, ambas placeholders documentales (`client_secret={...}`, `<secret...>`) en docs/security; ningún valor real; `.env` no leído ni versionado |
| `.tmp-log-metadata/` | no existe |
| `.workspace/` | ignorado (`git check-ignore`) |
| `.claude/worktrees/` indexado | no |
| `git diff --check` | exit 0 (solo aviso LF→CRLF de `.gitignore`) |
| Cambios en `src/`, `pom.xml` | 0 archivos (`git status --short src pom.xml`) |

## Build técnico

- Comando: `mvn -B -ntp verify`, JDK 25 (`C:\Program Files\Java\jdk-25`), inicio 2026-09-20T16:59:23-05:00, 01:29 min.
- Resultado: `BUILD FAILURE`, exit code 1. **Tests run: 920, Failures: 1, Errors: 0, Skipped: 0.**
- Fallo: `ControllersMustDependOnlyOnInputPortsTest.controllers_no_dependen_de_secondary_ports_adapters_jdbc_ni_java_sql`; `GlobalExceptionHandler` (constructor, campo `messageCatalogPort` y `resolveErrorMessage`) depende de `MessageCatalogPort`.
- El fallo detiene `verify` antes de los gates JaCoCo LINE ≥80 % / BRANCH ≥70 %: **la cobertura no se evaluó**.
- Coincide con las corridas previas de LB-000 (920 tests, 1 failure). No se modificó código ni tests para alterarlo.

## No ejecutado

Integración SQL Server (`-Pintegration`), E2E, checks remotos de CI: NO APLICA a este diff documental, no ejecutados.
