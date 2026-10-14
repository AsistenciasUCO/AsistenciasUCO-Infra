---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# VALIDATION — TECH-001

## Dictamen

**PASS.** `TECHNICAL_BUILD_GATE = PASS`. Ejecutado por el implementador (sin auditor independiente: independencia conceptual limitada; el cierre queda sujeto a revisión humana).

## Comandos ejecutados

| Fecha/entorno/base | Comando | Exit code | Resultado |
|---|---|---|---|
| 2026-09-20, Windows, Maven 3.9.11 con Java 25 (Oracle), rama `sergio` | `mvn -B -ntp test -Dtest=ControllersMustDependOnlyOnInputPortsTest` (antes de implementar) | 1 | **RED**: 1 test, 1 failure; 3 violaciones de `GlobalExceptionHandler` (parámetro de constructor, campo y llamada `findUserMessage`) |
| idem | `mvn -B -ntp test -Dtest=ResolverMensajeUsuarioTest,CatalogoWiringConfigurationTest,GlobalExceptionHandlerTest,ControllersMustDependOnlyOnInputPortsTest,*ControllerTest,*ControllerContractTest` | 0 | 116 tests, 0 failures, 0 errors, 0 skipped |
| idem | `mvn -B -ntp verify` (1.ª corrida tras el refactor) | 1 | 932 tests, 35 errores: `@WebMvcTest` de `SecurityConfigTest`/`RbacSecurityFilterChainTest` sin bean `ResolverMensajeUsuarioInputPort` |
| idem | `mvn -B -ntp verify` (tras añadir bean stub en sus `@TestConfiguration`) | 0 | **BUILD SUCCESS**: 932 tests, 0 failures, 0 errors, 0 skipped; "All coverage checks have been met" |

Nota: el `java` del PATH es 17, pero Maven reporta `Java version: 25` (JAVA_HOME); la corrida usó JDK 25.

## Checks

| Nivel | Check | Resultado | Evidencia |
|---|---|---|---|
| Alcance | Plan/criterios | PASS | Solo rutas Allowed del [PLAN](PLAN.md) |
| Arquitectura | ArchUnit | PASS | `ControllersMustDependOnlyOnInputPortsTest` sin modificar (`git diff` vacío de `src/test/**/architecture`); sin exclusiones ni cambios de regla |
| Contratos | HTTP/DB/security/eventos | NO APLICA | Sin cambios; tests existentes de handler/controllers en verde |
| Tests | RED → GREEN | PASS | Escenarios A–K de [TEST_PLAN](TEST_PLAN.md) |
| Coverage | LINE ≥80 %, BRANCH ≥70 % (`pom.xml`, BUNDLE) | PASS | Global (jacoco.csv): líneas 6992/8113 = 86,18 %; ramas 1397/1983 = 70,45 % (margen estrecho). Clases nuevas: 0 líneas y 0 ramas sin cubrir; ninguna excluida |
| Integración | DB real | NO APLICA | Sin perfil `integration` |
| Build | `mvn verify` | PASS | BUILD SUCCESS |
| Seguridad | Secretos | PASS | Sin secretos; el log de degradación registra solo código y tipo de excepción |
| Documentos | Deuda/línea base | PASS | TD-029 cerrada, TD-030 abierta, LINEA_BASE actualizada |

## Integridad de RED

`ControllersMustDependOnlyOnInputPortsTest` no fue modificado. Se modificaron tests que construían `new GlobalExceptionHandler()` (constructor eliminado): ahora pasan un resolver lambda vacío; y dos `@TestConfiguration` de seguridad reciben un bean stub. Son adaptaciones de construcción, sin cambiar assertions previas.

## Hallazgo AS-IS confirmado

Antes del cambio, con dos constructores y sin `@Autowired`, Spring instanciaba `GlobalExceptionHandler` con el constructor vacío: el catálogo de mensajes **no se consultaba en runtime** (lo demostró la 1.ª corrida verify: los slices que solo importaban el handler funcionaban sin el bean). Con el único constructor, el catálogo se consulta realmente en la aplicación; si el catálogo no tiene un código el fallback es idéntico. Efecto operacional a observar en TD-027 (Azure).

## Bloqueantes y limitaciones

Un mock no certifica el provider real (TD-027). Margen de BRANCH sobre el gate: 0,45 puntos.

## Evidencias remotas/manuales pendientes

CI remoto (MV-004) no ejecutado en esta tarea.
