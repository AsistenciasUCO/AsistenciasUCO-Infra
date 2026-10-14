---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# PRECHECK + SNAPSHOT — LB-001B.3

Ejecutado antes de invocar cualquier agente de la pipeline (secciones 1-2 de [TASK_AUTORIZADA.md](TASK_AUTORIZADA.md)).

## 1. Precheck del contrato DB

`docs/contracts/external/db/DB_BASELINE_CONTRACT.md` **no existía** en este repo al iniciar la tarea (búsqueda exhaustiva en `docs/`, ningún archivo `DB_BASELINE_CONTRACT*`). Esto es un `BLOCKED_BY_MISSING_EVIDENCE` literal según la sección 1 de la tarea. Se detuvo el trabajo y se preguntó al usuario cómo resolverlo (no se decidió unilateralmente). El usuario autorizó explícitamente (2026-09-23, en chat) importar el snapshot desde el repo DB.

Origen importado, procedencia completa en [docs/contracts/external/db/PROVENANCE.md](../../contracts/external/db/PROVENANCE.md):

- Repo: `gestion-asistencia-db`, rama `feat/db-golden-path-baseline-freeze`, commit `99190f07436bc64299b7d3a35c8e4486f49f9cd6`.
- **Esa rama NO está fusionada a `main`/`develop`** del repo DB al momento de esta captura — es la advertencia más importante para el resto de la pipeline: se trabaja contra un baseline de feature branch, no contra un `main` DB ya fusionado.

Verificación SHA-256 tras la copia a `docs/contracts/external/db/`:

```
DB_BASELINE_CONTRACT.sha256 (publicado):  1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103
DB_BASELINE_CONTRACT.md (recalculado):    1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103
```

**DB CONTRACT SHA: VERIFIED** (coincide exactamente).

## 2. Snapshot backend

- Branch: `sergio`
- HEAD: `fa9aa901c73e55ae31071f4e74cfb2245189243a` (`feat(cloud): integrate Azure Key Vault, App Configuration parameter & message catalogs`)
- Git status: **dirty**, 87 entradas (`git status --porcelain=v1`, capturado 2026-09-23). No se revirtió nada.
- Java: JDK 25 (`Oracle Corporation`, detectado por `mvnw` — `java -version` del PATH por defecto muestra Temurin 17, pero Maven usa Java 25 vía su propia resolución de toolchain; confirmar con `./mvnw.cmd -v` antes de cualquier build real).
- Maven: Apache Maven 3.9.15 (wrapper).
- Spring Boot: no confirmado en esta sesión desde `pom.xml`; pendiente para 01-planificador/02-contratos al leer `pom.xml` (la tarea asume Spring Boot 4 — verificar, no asumir).

### Trabajo existente sin commit (NO revertir)

El diff sin commitear en `src/main/java/.../sesion/**` (crear/actualizar) corresponde a la implementación ya cerrada de **LB-001B.1** (`docs/work-items/LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md`, estado `DONE`, 2026-09-22): retiro de `descripcion/aula/tipo` de `CrearSesion`/`ActualizarSesion` en HTTP/Application/Domain/adapter. Esa fase reporta `mvn verify` en verde (933/933 tests) y ArchUnit 20/20 + 67/67, pero **sin commit nuevo** — el resultado quedó en el working tree. LB-001B.3 hereda este estado como punto de partida; no debe revertirlo, y debe auditar si aún alinea con `DB_BASELINE_CONTRACT.md` (p. ej. `idDocente` como parámetro de `usp_crear_sesion`/`usp_actualizar_sesion` — el contrato importado ya NO lo incluye en ninguna de las dos firmas, lo cual es un dato nuevo para 02-contratos: verificar si LB-001B.1 ya lo retiró o si sigue pendiente).

Archivos Golden Path modificados (`M`) con SHA-256 registrado en [GOLDEN_PATH_DIRTY_FILE_HASHES.txt](GOLDEN_PATH_DIRTY_FILE_HASHES.txt) (18 archivos de `src/main/java`: DTOs, mappers, domain, use cases, controller, request, validator y `SesionRepositorySqlServerAdapter` de crear/actualizar Sesion, más `GlobalExceptionHandler`).

Además hay ~30 archivos de test (`src/test/java`) modificados sin commit (mismos módulos + controllers/security no relacionados con Sesion) y varios documentos de gobernanza (`AGENTS.md`, `.claude/`, `docs/baseline/`, `docs/governance/`, `docs/work-items/`, etc.) que están **untracked (`??`)** — es decir, todo el andamiaje de gobernanza de este repo (agentes, skills, plantillas, DoR/DoD) tampoco está comiteado todavía. No se tocó nada de esto en este precheck salvo crear los archivos nuevos de este work item y `docs/contracts/external/db/`.

No se trabajó sobre `target/**`, `.workspace/**`, `.claude/worktrees/**` ni copias/ZIPs — no existen en este árbol de trabajo actual (confirmado por `git status` limpio de esas rutas).

## Resultado de este paso

- `DB CONTRACT SHA`: **VERIFIED**
- `BLOCKED_BY_MISSING_EVIDENCE` inicial: **RESUELTO** por autorización explícita del usuario (importación documentada, no asumida)
- Snapshot backend: **registrado**
- Listo para 01-planificador.
