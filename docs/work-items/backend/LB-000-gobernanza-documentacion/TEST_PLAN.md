---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# TEST_PLAN — LB-000

Fuente: solicitud del usuario, PLAN, arquitectura/config/tests existentes. No hay implementación funcional: RED/GREEN Java **NO APLICA**; crear pruebas de funcionalidad aquí violaría el alcance.

| ID | Comportamiento a verificar | Método/evidencia esperada |
|---|---|---|
| DOC-01 | Un AGENTS raíz, CLAUDE adaptador | Recorrido Markdown fuera de worktrees/cache; referencias válidas |
| DOC-02 | Seis agentes, ocho skills, seis plantillas | Nombres requeridos, metadata validada, fuentes y límites explícitos |
| DOC-03 | Autoridad única | DoR/DoD/roadmap/ledger únicos; documentos superseded solo en archivo |
| DOC-04 | Sin pérdida vigente | Matriz inicial, destinos, TD-001..029, históricos y revisión de fusión antes de eliminar pack |
| DOC-05 | Enlaces reales | Resolver enlaces Markdown locales y anchors, excluyendo ejemplos/estado local; comprobar routers |
| DOC-06 | Estado Claude local | Nueve patrones ignore; cero worktrees en índice; ningún contenido movido |
| DOC-07 | Sin funcionalidad modificada | Hashes de todos los archivos versionados ajenos a Markdown/.gitignore iguales al snapshot inicial; git diff de src/pom/config/workflows vacío |
| BUILD-01 | Estado previo de Maven | Java 25, mvn verify y resumen Surefire; distinguir red frente a test real |
| BUILD-02 | Estado final de Maven | Mismo comando y comparación de conteos/fallo; no editar test RED ni gates |
| SEC-01 | Sin secretos nuevos | Revisar documentos y patrones de secretos versionados; no imprimir valores ni .env |

Bordes: links relativos tras mover, rutas antiguas en texto, YAML ejecutable inventariado pero intacto, archivar prompts sin ejecutarlos, nombres propuestos marcados TARGET. Integración DB/E2E NO APLICA a este diff; no ejecutar IT que escribe DB para reorganizar docs. Validación de contrato documental sí aplica; no gate OpenAPI inexistente.

No hay tests RED funcionales que congelar. La suite Java y configuración existentes se protegen por hashes y Git diff; el implementador no actúa en este work item.
