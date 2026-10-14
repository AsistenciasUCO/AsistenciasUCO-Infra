---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-22
---

# VALIDATION — LB-001B.1 (backend): retiro de `descripcion/aula/tipo` en crear/actualizar Sesion

Fase 04-implementador. Fecha: 2026-09-22 (America/Bogota). Branch `sergio`, HEAD base
`fa9aa901c73e55ae31071f4e74cfb2245189243a` (sin commitear; working tree ya estaba sucio
con trabajo previo no relacionado, ver PLAN.md riesgo #1). JDK 25 (`JAVA_HOME=C:\Program
Files\Java\jdk-25`).

## ACTUALIZACIÓN — resolución final (2026-09-22, posterior a este documento)

**Estado final: BUILD SUCCESS. 933/933 tests, 0 failures, 0 errors.** El hallazgo bloqueante
descrito más abajo (`SesionControllerContractTest` 5/7 GREEN por defecto de arnés de prueba,
no de producción) fue diagnosticado correctamente por 04-implementador (sección "Hallazgo
bloqueante" abajo, íntegra y vigente como diagnóstico) y resuelto por 03-tester-red en una
segunda pasada: se corrigió **únicamente el setup** de `SesionControllerContractTest.java`
(construcción de `JsonMapper` reutilizando el `JsonMapperBuilderCustomizer` real de
`JacksonInputConfig` vía `AnnotationConfigApplicationContext`, sin tocar `src/main/**` ni
ninguna de las 7 aserciones del test). Detalle completo, diff exacto y SHA-256 de la
corrección: ver `TEST_PLAN.md`, sección "Resolución TEST_CONTRACT_CONFLICT". Verificado de
forma independiente por 05-auditor en `AUDIT.md` (re-ejecución propia de `verify`, diff línea
por línea de `SesionControllerContractTest.java` confirmando que solo cambió el setup).

**JaCoCo real (ejecutado, no solo informativo):** "All coverage checks have been met" — LINE
86,4%, BRANCH 70,53% (margen ajustado, ~0,5pp sobre el mínimo del `pom.xml`; señalado por
05-auditor como riesgo a vigilar en cambios futuros, no como fallo). ArchUnit: 20/20
`CleanArchitectureRulesTest` + resto de clases de arquitectura, 0 failures.

El resto de esta sección y de "Hallazgo bloqueante" (abajo) se conserva **como registro
histórico del diagnóstico** que llevó a la resolución — ya no describe el estado final del
work item.

---

## Resultado global (histórico — ver ACTUALIZACIÓN arriba para el estado final)

**BUILD FAILURE en `.\mvnw.cmd -B -ntp verify` — NO se declara cierre.** El contrato TARGET
congelado en CONTRACT_FREEZE.md quedo implementado en los 17 archivos de produccion + el
hallazgo #18 (fixture IT), y **9 de los 11 archivos de test RED quedaron 100% GREEN**; el
archivo 10 (`SesionRepositorySqlServerAdapterTest.java`, parte del Grupo 1 de compilacion)
tambien GREEN. El archivo 11 (`SesionControllerContractTest.java`) quedo **5/7 tests GREEN,
2/7 tests RED** por una causa raiz diagnosticada y documentada abajo, **no corregible desde
las rutas autorizadas de este work item**. Se reporta como hallazgo bloqueante para
02-contratos/03-tester-red/05-auditor, sin modificar el test ni ampliar el alcance de rutas.

## Verificacion previa: integridad del RED congelado

Antes de tocar codigo, se recalcularon los SHA-256 de los 11 archivos de test listados en
TEST_PLAN.md `RED_SNAPSHOT` y coincidieron exactamente (mismo valor, unica diferencia el
prefijo `*`/espacio propio del formato binario de `sha256sum`, sin diferencia de contenido).
**Ningun archivo de test fue modificado en esta fase** (verificado de nuevo al cierre de la
sesion con el mismo comando, mismo resultado).

## Comandos ejecutados y evidencia

### 1. Compilacion aislada (offline, replica del Grupo 1 de TEST_PLAN.md)

```
.\mvnw.cmd -o test-compile
```
Resultado: **BUILD SUCCESS**. 766 archivos de `src/main` + 221 de `src/test` compilan contra
los constructores TARGET (6 parametros) que los 11 tests RED ya exigian. El RED por firma de
constructor (123 errores `javac` documentados en TEST_PLAN.md) quedo resuelto.

### 2. Suite completa

```
.\mvnw.cmd -B -ntp verify
```
Resultado: **BUILD FAILURE**, exit code 1, en la fase `test` (surefire). El pipeline nunca
llega a la fase `verify`/`jacoco:check` (Maven detiene el reactor en el primer fallo de fase).

```
[ERROR] Failures:
[ERROR]   SesionControllerContractTest.createRejectsRetiredFieldsWithBadRequest:89->assertCreateRejectsUnknownField:102 Status expected:<400> but was:<201>
[ERROR]   SesionControllerContractTest.updateRejectsRetiredFieldsWithBadRequest:180->assertUpdateRejectsUnknownField:192 Status expected:<400> but was:<200>
[ERROR] Tests run: 933, Failures: 2, Errors: 0, Skipped: 0
```

933 tests ejecutados en total (todo el modulo, no solo Sesion), **931 GREEN, 2 RED, 0
errores**. Ningun otro test del modulo (incluidos los que tocan `Sesion` indirectamente,
como `SesionWiringConfigurationTest`) se rompio por este cambio.

### 3. ArchUnit — PASS completo

Las 15 clases de `co.edu.uco.asistenciasuco.architecture.*` corrieron dentro de la misma
ejecucion de `verify` (933 tests incluye estas) y **las 15 pasaron con 0 failures/errors**:
`AdapterCompositionRootRulesTest` (8), `AdaptersShouldNotBeUsedByDomainTest` (4),
`ApplicationMustNotUsePortalConceptsTest` (2), `ApplicationShouldNotCarryTechnicalCorrelationTest` (1),
`ApplicationShouldNotDependOnInfrastructureTest` (3), `ApplicationShouldNotDependOnReactiveInfrastructureTest` (1),
`ApplicationShouldNotUseInfrastructureTechnicalApisTest` (1), `CleanArchitectureRulesTest` (20),
`ControllersMustDependOnlyOnInputPortsTest` (1), `DomainShouldNotDependOnSpringTest` (4),
`IdentityProviderIsolationRulesTest` (6), `InfrastructureStructureRulesTest` (5),
`InstitutionalRolePurityTest` (3), `SecurityProviderIsolationRulesTest` (6),
`SourcePackageConsistencyTest` (1), `UseCasesShouldNotKnowSqlResultProtocolTest` (1).
El retiro de campos no introdujo ninguna violacion de capas/puertos/Composition Root.

### 4. JaCoCo — gate `jacoco:check` NO se ejecuto (build detenido antes)

Conforme a AGENTS.md ("una prueba no ejecutada no es PASS"), **no se declara PASS/FAIL del
gate LINE≥80%/BRANCH≥70%** porque `mvn verify` nunca llega a esa fase con 2 fallos de
surefire previos. Como evidencia informativa (no como gate ejecutado), se genero el reporte
HTML sobre los datos de ejecucion ya recolectados por el agente JaCoCo durante el `test` que
si corrio completo:

```
.\mvnw.cmd -o jacoco:report
```
Bundle `AsistenciasUCO`, 642 clases analizadas. Totales del reporte (`target/site/jacoco/index.html`):
INSTRUCTION 85% (28.147/33.037 cubiertas), BRANCH 70% (1.388/1.971 cubiertas — el mismo
counter que exige el gate del `pom.xml`), LINE 86% (6.898/8.013 cubiertas). Estos numeros
son **coherentes con el gate configurado** (LINE≥80%, BRANCH≥70%) pero no reemplazan su
ejecucion formal por Maven, que solo ocurrira cuando los 2 fallos de abajo se resuelvan.
No hay baseline de cobertura "antes" capturado en una sesion previa de este work item con la
que comparar (01-planificador/02-contratos/03-tester-red no ejecutaron `verify` — ver PLAN.md
riesgo #9); esta es la primera medicion de cobertura de todo el work item.

### 5. Perfil `integration` (`-Pintegration`)

**No ejecutado.** No hay evidencia de un entorno SQL Server controlado disponible en esta
sesion (mismo hallazgo que TEST_PLAN.md documento para 03-tester-red). El PLAN.md no exige
este perfil para el sub-alcance backend de retiro de campos (seccion "Validacion minima" de
AGENTS.md: "Si cambia persistencia/integracion" — este cambio retira parametros de una
llamada SP existente, no cambia el contrato de persistencia en si). Se documenta el skip en
vez de presumir una ejecucion que no ocurrio.

## Estado GREEN de los 11 archivos de test RED

| # | Archivo | Estado |
|---|---|---|
| 1 | `CrearSesionDomainTest.java` | GREEN (2/2 tests) |
| 2 | `CrearSesionMapperTest.java` | GREEN (2/2 tests) |
| 3 | `CrearSesionRepositoryMapperTest.java` | GREEN (2/2 tests) |
| 4 | `CrearSesionUseCaseImplTest.java` | GREEN (3/3 tests) |
| 5 | `ActualizarSesionDomainTest.java` | GREEN (3/3 tests) |
| 6 | `ActualizarSesionMapperTest.java` | GREEN (2/2 tests) |
| 7 | `ActualizarSesionRepositoryMapperTest.java` | GREEN (2/2 tests) |
| 8 | `ActualizarSesionUseCaseImplTest.java` | GREEN (3/3 tests) |
| 9 | `SesionRepositorySqlServerAdapterTest.java` | GREEN (4/4 tests) |
| 10 | `SesionRepositoryMockAdapterTest.java` | GREEN (4/4 tests) |
| 11 | `SesionControllerContractTest.java` | **PARCIAL: 5/7 GREEN, 2/7 RED** |

## Hallazgo bloqueante (no corregido): `createRejectsRetiredFieldsWithBadRequest` / `updateRejectsRetiredFieldsWithBadRequest`

**Clasificacion: hallazgo de implementacion fuera de las rutas autorizadas del PLAN.md —
reportado sin corregir, conforme a mi rol (04-implementador no modifica tests RED ni amplia
alcance; si discrepa, reporta para que 02-contratos/03-tester-red/05-auditor decidan).**

### Diagnostico causal (confirmado empiricamente, no supuesto)

1. `CrearSesionRequest`/`ActualizarSesionRequest` ya NO tienen `descripcion`/`aula`/`tipo`/
   `setRoom` (implementado). Un cliente que los envie a la aplicacion real (contexto Spring
   Boot completo) recibe 400, porque `JacksonInputConfig.strictJsonInputCoercionCustomizer`
   (bean `JsonMapperBuilderCustomizer`, fuera de las rutas permitidas de este work item)
   habilita `DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES` sobre el `ObjectMapper` que
   Spring Boot autoconfigura para la app real.
2. `SesionControllerContractTest` construye su propio `MockMvc` con
   `MockMvcBuilders.standaloneSetup(controller).setControllerAdvice(...).build()` — **sin
   contexto Spring Boot**, por lo que el bean `strictJsonInputCoercionCustomizer` nunca se
   aplica al converter JSON que ese test usa.
3. Se confirmo por lectura de codigo fuente (`tools.jackson.databind.DeserializationFeature`,
   Jackson 3.1.2, dependencia real del proyecto via `spring-boot-starter-jackson:4.0.6`) que
   **en Jackson 3, `FAIL_ON_UNKNOWN_PROPERTIES` cambio su valor por defecto a `false`**
   (en Jackson 2 el valor por defecto era `true`). Por eso, sin el bean de `JacksonInputConfig`
   aplicado, el `MockMvc` standalone de este test ignora silenciosamente cualquier campo
   desconocido (`descripcion`, `aula`, `tipo`, `room`) en vez de rechazarlo — de ahi que la
   peticion complete con 201/200 en vez de 400.
4. Se intento (y se revirtio, por no funcionar) anotar `CrearSesionRequest`/
   `ActualizarSesionRequest` con `@JsonIgnoreProperties(ignoreUnknown = false)` — mecanismo
   estandar de Jackson confinado a las dos clases ya autorizadas por CONTRACT_FREEZE.md
   seccion 7 (#1 y #2). Se confirmo por lectura de
   `tools.jackson.databind.deser.bean.BeanDeserializerBase` (Jackson 3.1.2) que esta
   anotacion **solo puede relajar** el comportamiento (forzar que se ignoren desconocidos
   aunque el mapper global sea estricto); cuando `ignoreUnknown=false` (el default, tanto si
   se omite como si se declara explicitamente), el deserializador cae al chequeo del feature
   global del `ObjectMapper` — que en este test standalone es `false`. **No existe mecanismo
   de anotacion a nivel de clase que fuerce estrictez cuando el `ObjectMapper` que procesa la
   peticion es permisivo.** Verificado empiricamente: con la anotacion presente, los dos
   tests seguian fallando exactamente igual (201/200); se revirtio para no dejar codigo sin
   efecto.

### Por que no se corrige en esta fase

Las unicas formas conocidas de hacer que estos dos tests pasen requieren una de las
siguientes, todas fuera de mi autoridad como 04-implementador:

- Modificar `JacksonInputConfig.java` o registrar el `ObjectMapper`/converter de la app en el
  `MockMvc` de `SesionControllerContractTest` — **archivo fuera de las rutas permitidas** del
  PLAN.md (no listado en "Allowed").
- Modificar el propio `SesionControllerContractTest.java` (por ejemplo,
  `.setMessageConverters(...)` con el `ObjectMapper` real de la app) — **prohibido**: es uno
  de los 11 archivos de test RED congelados, y esta fuera de mi rol modificarlo aunque el
  cambio fuese solo al setup del test y no a sus aserciones.
- Implementar un mecanismo no estandar (p. ej. `@JsonAnySetter` construyendo manualmente una
  `UnrecognizedPropertyException` con un `JsonParser` nulo) dentro de
  `CrearSesionRequest`/`ActualizarSesionRequest` — evaluado y descartado: requiere invocar la
  API interna de Jackson de forma no soportada (el constructor/factory de
  `UnrecognizedPropertyException` depende de un `JsonParser` real para calcular la ubicacion
  del error), no esta descrito en CONTRACT_FREEZE.md, y seria un hack fragil no trazable al
  contrato congelado.

Esto es exactamente el escenario que AGENTS.md describe: *"Si discrepa: `TEST_CONTRACT_CONFLICT`,
detener el cambio afectado y devolverlo a contratos/tester tras dictamen del auditor."* La
discrepancia no es que el test contradiga el CONTRACT_FREEZE (su intencion — rechazar con 400
los campos retirados — es exactamente el contrato TARGET), sino que **el mecanismo asumido por
CONTRACT_FREEZE.md seccion 2 ("ya cubierto por los tests de SesionControllerContractTest") no
es alcanzable desde las rutas de codigo que ese mismo documento autorizo**, dado el cambio de
default de Jackson 3 que 02-contratos no verifico empiricamente contra el arnes de test real
(solo leyo `JacksonInputConfig.java` de forma aislada).

### Recomendacion para 02-contratos/03-tester-red/05-auditor

Alguna de estas rutas de resolucion (ninguna decidida aqui, corresponde a las fases con
autoridad sobre contrato/tests):

1. Ampliar las rutas permitidas de este work item para incluir `JacksonInputConfig.java` (o
   una clase utilitaria nueva) de forma que `SesionControllerContractTest` pueda construir su
   `MockMvc` reutilizando el `ObjectMapper`/customizer real de la app — requiere decidir si
   eso es un cambio de test (edicion del `MockMvcBuilders.standaloneSetup(...)`) o de
   produccion (exponer un converter reusable), y quien lo autoriza.
2. Verificar si existe ya en el proyecto un patron establecido para tests de contrato HTTP que
   necesiten `FAIL_ON_UNKNOWN_PROPERTIES` real (por ejemplo, `@SpringBootTest` con
   `@AutoConfigureMockMvc` en lugar de `standaloneSetup`) y decidir si
   `SesionControllerContractTest` debe migrar a ese patron (cambio de test, fuera de mi rol).
3. Aceptar que estos 2 casos (rechazo de campos retirados via 400) se cubran unicamente por un
   test de integracion HTTP con contexto Spring completo (nuevo test, no el existente), y
   marcar los 2 metodos actuales como cubiertos de otra forma — decision de alcance de
   contrato/tester, no del implementador.

## Archivos modificados (produccion + fixture, dentro de rutas autorizadas)

17 archivos de produccion listados en CONTRACT_FREEZE.md seccion 7 (#1-#17) + el hallazgo #18
(`AsistenciaRepositorySqlServerIT.java`, ajuste mecanico del constructor 9→6 parametros, sin
tocar su logica de aserciones). Ningun archivo fuera de estas rutas fue tocado. El resto de
diffs que aparecen en `git status`/`git diff` del repositorio (p. ej. `GlobalExceptionHandler.java`,
`GlobalExceptionHandlerTest.java`, controllers de otros dominios) son **trabajo previo no
relacionado ya presente en el working tree sucio antes de esta sesion** (ver PLAN.md,
"Identidad y objetivo": 59 entradas de git status ya existian sobre HEAD `fa9aa90` antes de
que este work item empezara) — no se tocaron ni se revirtieron.

## Codigo muerto confirmado, no retirado (decision ya tomada por 03-tester-red)

`SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` queda sin ningun lanzador en
produccion tras este cambio (confirmado: ya no hay `validarDescripcion(...)` en
`CrearSesionDomain`/`ActualizarSesionDomain`). Conforme a TEST_PLAN.md ("Decision de alcance:
se mantiene la constante"), no se retiro en esta fase — queda como candidato a
`TECHNICAL_DEBT` para 06-cierre.

## No alcance confirmado en esta fase

- `SesionConsultadaDTO.java` y su flujo de lectura: no tocado (confirmado por `git diff`,
  cero cambios en ese archivo/mapper/consulta).
- DB_ROOT: no tocado (sesion backend, sin acceso a ese repo).
- Repo frontend: no tocado.
- Cierre del work item (`CLOSURE.md`, traslado de DR-001/DR-004 a `RESOLVED` en el
  `CONTRACT_MATRIX` de LB-001B): no ejecutado, corresponde a 06-cierre tras resolver el
  hallazgo bloqueante de arriba.
