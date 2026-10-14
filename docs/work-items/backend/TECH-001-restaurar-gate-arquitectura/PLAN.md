---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# PLAN — TECH-001: Restaurar TECHNICAL_BUILD_GATE (TD-029 / CF-002)

## Identidad y objetivo

- Fecha / rol / base Git: 2026-09-20 / backend-team / rama `sergio`, base `fa9aa90` + árbol de gobernanza LB-000 sin commit.
- Objetivo: eliminar la dependencia `GlobalExceptionHandler → MessageCatalogPort` sin relajar ArchUnit y restaurar `mvn verify` = BUILD SUCCESS.
- Criterios: `ControllersMustDependOnlyOnInputPortsTest` PASS sin modificarlo; verify verde con gates JaCoCo del `pom.xml` (LINE ≥0.80, BRANCH ≥0.70); comportamiento HTTP del handler idéntico.
- Skills/fuentes: uco-arquitectura, uco-catalogos, uco-testing, uco-baseline; [adapter-composition-standard](../../architecture/adapter-composition-standard.md), [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md#td-029), [FINDINGS LB-000](../LB-000-gobernanza-documentacion/FINDINGS.md).

## APPROVED_EXCEPTION

Se permite `REFACTOR` exclusivamente para resolver TD-029, porque TD-029 es la causa del `TECHNICAL_BUILD_GATE` rojo. No autoriza cambios adicionales (JPA, OpenAPI, DB, frontend, funcionalidades nuevas). Aprobación: instrucción humana explícita de la tarea (usuario del repositorio, 2026-09-20).

## AS-IS y evidencia

| Hecho | Archivo + símbolo | Evidencia y límites |
|---|---|---|
| Primary adapter depende de secondary port | `infrastructure/adapter/primary/controller/error/GlobalExceptionHandler` (campo, constructor, `resolveErrorMessage` → `findUserMessage`) | RED existente: `architecture/ControllersMustDependOnlyOnInputPortsTest` |
| Dos constructores públicos (`(MessageCatalogPort)` y `()` → `this(null)`) | mismo archivo | Con dos constructores sin `@Autowired`, Spring usa el constructor sin argumentos: en runtime el catálogo podría no consultarse hoy (hallazgo AS-IS; no verificado con contexto real) |
| Tests construyen `new GlobalExceptionHandler()` | 10 tests de controllers + `GlobalExceptionHandlerTest` | El constructor vacío existe solo para esos tests / esquivar wiring |
| Provider de `MessageCatalogPort` | `config/adapters/catalog/azure/AzureAppConfigMessageCatalogAdapterConfiguration` (`provider=azure`, matchIfMissing), `config/adapters/persistence/sqlserver/SqlServerCatalogAdapterConfiguration` (`provider=sqlserver`) | Sin cambios |
| Patrón de casos | `features/<x>/<caso>/primaryports/{InputPort,interactor}` + `usecase/{UseCase,impl}` + `config/wiring/<X>WiringConfiguration` (`@Bean` explícitos, sin anotaciones Spring en Application) | p. ej. tipoidentificacion |

## TARGET

`GlobalExceptionHandler → ResolverMensajeUsuarioInputPort → Interactor → UseCase(Impl) → MessageCatalogPort → Provider`.
Handler con un único constructor explícito que recibe el InputPort. El InputPort es neutral: `Optional<String> execute(String codigo)` (contrato `InteractorWithReturn<String, Optional<String>>`); sin tipos Spring/Web/`ApiErrorDescriptor`.

## Clase de cambio y alcance de rutas

- Change class: REFACTOR (excepción aprobada arriba).
- Variable principal: dirección de dependencia del handler hacia el catálogo de mensajes.
- Allowed: `application/features/catalogo/resolvermensajeusuario/**` (NUEVO); `infrastructure/config/wiring/CatalogoWiringConfiguration.java` (NUEVO); `GlobalExceptionHandler.java`; tests nuevos del resolver, `GlobalExceptionHandlerTest` y, en los tests de controllers, solo la línea de construcción del handler; `docs/work-items/TECH-001-*/**`; `docs/baseline/{LINEA_BASE,TECHNICAL_DEBT}.md`.
- Forbidden: `gestion-asistencia-db`, frontend, `contracts/openapi/**`, `AsistenciaRepositorySqlServerAdapter`, SP contracts, realtime, seguridad, JPA, `pom.xml`, `ControllersMustDependOnlyOnInputPortsTest` y demás reglas ArchUnit, FINDINGS/LB-000 históricos.

## Alcance

Nuevo InputPort/Interactor/UseCase/Impl, wiring, refactor del handler, tests, actualización documental de cierre y evidencia DB certificada externamente, alta de TD por VAL_003.

## No alcance

Cambios de códigos/mensajes públicos, caché/TTL del catálogo, corrección de VAL_003 en DB, cualquier otro refactor.

## Archivos afectados

- EXISTENTES: `GlobalExceptionHandler`, `GlobalExceptionHandlerTest`, tests de controllers que construyen el handler, LINEA_BASE, TECHNICAL_DEBT.
- NUEVOS: `application/features/catalogo/resolvermensajeusuario/{primaryports/ResolverMensajeUsuarioInputPort, primaryports/interactor/ResolverMensajeUsuarioInteractor, usecase/ResolverMensajeUsuarioUseCase, usecase/impl/ResolverMensajeUsuarioUseCaseImpl}`, `infrastructure/config/wiring/CatalogoWiringConfiguration`, tests asociados, este work item.

## Contratos y consumidores afectados

HTTP: ninguno (mismos status/code/path/timestamp/correlationId/details/message con la misma cadena de fallback). SECURITY/REALTIME/PERSISTENCE: ninguno. Nota: con un único constructor Spring inyecta el resolver, por lo que el catálogo se consulta realmente en runtime (ver riesgos).

## Riesgos y dependencias

- R1: si hoy Spring usaba el constructor vacío, el mensaje del catálogo empezará a usarse en runtime. Es la conducta declarada del handler; sin datos en catálogo el fallback es idéntico. Se registra en VALIDATION.
- R2: un contexto sin bean `MessageCatalogPort` falla al arrancar (fail-fast). Ambos providers definen el bean; se verifica con la suite.
- R3: el log de degradación no incluye mensaje de excepción (posibles secretos): solo código y tipo de excepción.

## Test plan

Ver [TEST_PLAN](TEST_PLAN.md). RED existente: ArchUnit (sin tocar). Tests nuevos antes de implementar.

## Rollback

`git revert` del commit; restaura el estado previo (gate rojo). Sin migración ni datos.

## Stop conditions

Si tras el cambio ArchUnit sigue rojo → FAIL, no relajar. Si un test existente contradice el contrato → TEST_CONTRACT_CONFLICT.

## Deuda conocida y validación manual

TD-029 (se cierra), TD-027 (Azure operacional, sin cambios), TD-030 nueva (VAL_003). MV: ninguna nueva.

## Definition of Ready

READY por excepción aprobada (`APPROVED_EXCEPTION`); CF-002 es el objeto del trabajo, sin otro conflicto abierto relevante. TEST_PLAN previo a implementar.
