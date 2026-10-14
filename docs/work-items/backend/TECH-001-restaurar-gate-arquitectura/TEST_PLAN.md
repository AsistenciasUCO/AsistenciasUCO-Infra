---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# TEST_PLAN — TECH-001

## Fuentes

Requisito de la tarea, [PLAN](PLAN.md), [TESTING_STANDARD](../../testing/TESTING_STANDARD.md), TD-029.

## Comportamiento esperado

| ID | Escenario | Nivel | Acción | Assert observable |
|---|---|---|---|---|
| A | Catálogo contiene mensaje | unit (UseCaseImpl e Interactor) | `execute("COD")` | `Optional.of(mensaje)` |
| B | Catálogo sin mensaje | unit | `findUserMessage` → empty | `Optional.empty()` |
| C | Catálogo devuelve blank | unit | `Optional.of("  ")` | `Optional.empty()` |
| D | Catálogo lanza excepción | unit | `findUserMessage` lanza `RuntimeException` | no propaga; `Optional.empty()` |
| D2 | Código nulo/blank | unit | `execute(null)` / `""` | `Optional.empty()`, catálogo no consultado |
| E | Handler: resolver devuelve mensaje | unit | `handleApplication` | body.message = mensaje del catálogo |
| F | Handler: resolver vacío | unit | idem | body.message = `descriptor.message()` |
| G | Handler: resolver lanza | unit | idem | body.message = `descriptor.message()` (sin propagar) |
| H | descriptor.message vacío | unit | resolver vacío y descriptor sin mensaje | body.message = reason phrase HTTP |
| I | Conserva metadata | unit | idem | status, code, correlationId, details |
| J | Wiring | unit | `CatalogoWiringConfiguration` con `MessageCatalogPort` mock | InputPort creado y resuelve |
| K | Arquitectura | ArchUnit existente | sin cambios | `ControllersMustDependOnlyOnInputPortsTest` PASS |

Seguridad/persistencia/contrato HTTP: NO APLICA (sin cambio); los tests existentes del handler y de controllers sirven de regresión.

## Pruebas RED requeridas

`ControllersMustDependOnlyOnInputPortsTest` (existente, no modificado) falla hoy por `GlobalExceptionHandler → MessageCatalogPort`; se ejecuta antes de implementar y se registra en VALIDATION. Los tests A–D/J se escriben antes del código (RED por ausencia de tipo).

## Congelación

El test ArchUnit no se modifica (`git diff` vacío del archivo). Tests A–J se derivan de este plan, no de la implementación.

## Integración y E2E

NO APLICA (sin persistencia ni red). El provider real Azure/SQL sigue fuera (TD-027).

## Falsos positivos que deben evitarse

No mockear el SUT; D verifica que el interactor no filtre excepciones; G usa un resolver que lanza; no excluir clases nuevas de JaCoCo.
