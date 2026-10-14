---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-22
---

# TEST_PLAN — LB-001B.1: DB source of truth — limpieza contractual de Sesion (backend)

Fase 03-tester-red. Ningun archivo de `src/main/**`, SQL, `pom.xml` ni el repo frontend fue modificado
en esta sesion. Solo se tocaron los 11 archivos de test listados abajo, todos bajo `src/test/java/**`.

## Fuentes

- [PLAN.md](PLAN.md) (01-planificador, sub-alcance BACKEND `READY`).
- [CONTRACT_FREEZE.md](CONTRACT_FREEZE.md) (02-contratos, contrato TARGET congelado campo-por-campo).
- [TESTING_STANDARD.md](../../testing/TESTING_STANDARD.md) y [VALIDATION_RUNBOOK.md](../../testing/VALIDATION_RUNBOOK.md).
- `JacksonInputConfig.java` (l.16-20, `FAIL_ON_UNKNOWN_PROPERTIES` activo) y `JacksonInputErrorResolver.java`
  (mapeo `UnrecognizedPropertyException` -> `FIELD_UNKNOWN`, `GlobalExceptionHandler` -> 400), leidos
  directamente en esta sesion para confirmar el comportamiento exacto exigido por CONTRACT_FREEZE secc. 2.

## Comportamiento esperado

| ID | Criterio/fuente | Escenario | Nivel | Precondicion | Accion | Assert observable |
|---|---|---|---|---|---|---|
| A1 | CONTRACT_FREEZE 3.2/3.4 | `CrearSesionDomain`/`CrearSesionDTO` construidos sin descripcion/aula/tipo (6 params) | Unit domain | Datos validos | Construir domain/DTO | Getters de grupo/tema/fechas/docente/usuarioEjecutor devuelven lo esperado; no existe `getDescripcion()`/`getAula()`/`getTipo()` |
| A2 | CONTRACT_FREEZE 3.4 | Validaciones de grupo/tema/fechas/docente/usuarioEjecutor se preservan | Unit domain | Datos invalidos uno a uno | Construir domain | `ValidationException` con el codigo correspondiente |
| A3 | CONTRACT_FREEZE 3.5/3.6 | Mappers/UseCaseImpl de crear propagan el domain de 6 params | Unit mapper/usecase | Domain/DTO validos | `toDomain`/`toRepositoryDTO`/`execute` | Campos supervivientes mapeados; docente reescrito por scope institucional |
| B1-B3 | CONTRACT_FREEZE 3.7/3.8/3.10/3.11 | Simetrico a A1-A3 para `ActualizarSesionDTO`/`ActualizarSesionDomain`/`ActualizarSesionRepositoryDTO` (8 -> 6 params) | Unit domain/mapper/usecase | Datos validos/invalidos | Igual que arriba | Igual que arriba |
| C1 | CONTRACT_FREEZE 6/7#17 | `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION` sin `@descripcion`/`@aula`/`@tipo` | Adapter unit | DTO de repositorio de 6 params | `adapter.crearSesion(...)`/`adapter.actualizarSesion(...)` | SQL no contiene esos placeholders; `MapSqlParameterSource` no tiene esas keys (`hasValue(...)==false`) |
| C2 | CONTRACT_FREEZE 3.3/3.9 | `SesionRepositoryMockAdapterTest` construye los DTO de repositorio con 6 params | Adapter unit (test double) | — | Construir y pasar DTO | No lanza; compila contra el constructor TARGET |
| D1 | CONTRACT_FREEZE 3.1/4 | `POST /api/v1/sesiones` sin descripcion/aula/tipo/room sigue aceptando el subconjunto superviviente | HTTP contract | Body minimo valido | POST | 201, `CrearSesionDTO` capturado sin aula/tipo (metodos retirados) |
| D2 | CONTRACT_FREEZE 2/3.1/7#17 | `POST /api/v1/sesiones` con `descripcion`/`aula`/`tipo`/`room` debe ser rechazado | HTTP contract | Body con 1 campo retirado a la vez | POST | 400, `details[0].field`=campo enviado, `details[0].code`=`FIELD_UNKNOWN`; input port sin invocar |
| E1 | CONTRACT_FREEZE 3.7/4 | `PUT /api/v1/sesiones/{id}` sin aula/descripcion/room sigue aceptando el subconjunto superviviente | HTTP contract | Body minimo valido | PUT | 200, `ActualizarSesionDTO` capturado sin aula (metodo retirado) |
| E2 | CONTRACT_FREEZE 2/3.7/7#17 | `PUT /api/v1/sesiones/{id}` con `descripcion`/`aula`/`room` debe ser rechazado | HTTP contract | Body con 1 campo retirado a la vez | PUT | 400, `details[0].field`=campo enviado, `details[0].code`=`FIELD_UNKNOWN`; input port sin invocar |
| F1 | CONTRACT_FREEZE 3.14 (regresion, sin cambio) | `SesionConsultadaDTO`/consulta HTTP no ganan campos nuevos | HTTP contract (regresion) | — | `GET /api/v1/sesiones/{id}` y `POST /api/v1/sesiones/consultas` | Response exacto con los 10 campos de `uv_sesion`, sin `descripcion`/`aula`/`tipo`/`status`; test ya existente, no modificado, permanece GREEN antes y despues |

NO APLICA: OpenAPI (TD-002, sin gate configurado), integracion SQL Server real (fuera de alcance de
esta fase; `AsistenciaRepositorySqlServerIT.java` queda documentada como hallazgo, ver seccion "Hallazgo
fuera de alcance"), frontend (ejecucion en `LB-001B.1B`, otro repo).

## Pruebas RED requeridas

Contrato TARGET congelado por CONTRACT_FREEZE.md. Cada archivo se ajusto para asertar el contrato
DESPUES (sin descripcion/aula/tipo/room), no el AS-IS. El tester no modifico produccion: el RED se
origina exclusivamente porque `src/main/**` todavia expone las firmas/comportamiento AS-IS.

### Grupo 1 — RED por firma de constructor (compilacion), 10 archivos

Los 8 tests unitarios de dominio/mapper/usecase y los 2 tests de adapter llaman a los constructores
TARGET de 6 parametros (`CrearSesionDomain`, `CrearSesionDTO`, `CrearSesionRepositoryDTO`) y 6
parametros (`ActualizarSesionDomain`, `ActualizarSesionDTO`, `ActualizarSesionRepositoryDTO`). Como
`src/main/**` todavia declara los constructores AS-IS (9 y 8 parametros respectivamente), el modulo
completo falla en la fase `test-compile` de Maven (Maven compila todo `src/test/**` en un solo paso;
el filtro `-Dtest=<clase>` no evita esto). Este es el RED esperado y causal para un `CONTRACT_CHANGE`
de firma: el fallo cita exactamente los constructores TARGET que produccion aun no implementa, no un
error tipografico ni un archivo no relacionado.

| Archivo | Constructor TARGET esperado | Constructor AS-IS actual |
|---|---|---|
| `CrearSesionDomainTest.java` | `CrearSesionDomain(UUID,String,LocalDateTime,LocalDateTime,UUID,UUID)` | `CrearSesionDomain(UUID,String,String,LocalDateTime,LocalDateTime,String,String,UUID,UUID)` |
| `CrearSesionMapperTest.java` | `CrearSesionDTO(UUID,String,LocalDateTime,LocalDateTime,UUID,UUID)` | 9 parametros (igual patron AS-IS) |
| `CrearSesionRepositoryMapperTest.java` | `CrearSesionDomain(...)` 6 params (mismo constructor que arriba) | 9 parametros |
| `CrearSesionUseCaseImplTest.java` | `CrearSesionDomain(...)` 6 params | 9 parametros |
| `ActualizarSesionDomainTest.java` | `ActualizarSesionDomain(UUID,String,LocalDateTime,LocalDateTime,UUID,UUID)` | `ActualizarSesionDomain(UUID,String,LocalDateTime,LocalDateTime,String,String,UUID,UUID)` |
| `ActualizarSesionMapperTest.java` | `ActualizarSesionDTO(UUID,String,LocalDateTime,LocalDateTime,UUID,UUID)` | 8 parametros |
| `ActualizarSesionRepositoryMapperTest.java` | `ActualizarSesionDomain(...)` 6 params | 8 parametros |
| `ActualizarSesionUseCaseImplTest.java` | `ActualizarSesionDomain(...)` 6 params | 8 parametros |
| `SesionRepositorySqlServerAdapterTest.java` | `CrearSesionRepositoryDTO(...)` 6 params, `ActualizarSesionRepositoryDTO(...)` 6 params, SQL sin `@descripcion/@aula/@tipo` | 9/8 parametros, SQL con los 3 placeholders |
| `SesionRepositoryMockAdapterTest.java` | Igual que el anterior (constructores) | Igual AS-IS |

Comando: `.\mvnw.cmd -o test-compile` (offline, JDK 25 via `JAVA_HOME`).
Resultado real obtenido en esta sesion: **BUILD FAILURE**, exit code 1, 123 lineas `[ERROR]` de
`javac`, todas del tipo "no suitable constructor found" / "constructor ... cannot be applied to given
types", exactamente en los 10 archivos de la tabla y en ninguno mas. No hay errores de sintaxis,
imports rotos ni archivos ajenos al alcance — evidencia archivada integramente (comando + salida) en
este work item via la sesion de 03-tester-red (ver `RED_SNAPSHOT`).

### Grupo 2 — RED en runtime (ejecutable), `SesionControllerContractTest.java`

A diferencia del Grupo 1, este archivo no requiere firmas nuevas (usa unicamente getters de
`CrearSesionDTO`/`ActualizarSesionDTO` que sobreviven en TARGET: grupo/tema/fechas/docente/
usuarioEjecutor). Compila hoy contra AS-IS. Para aislar su RED en ejecucion real (sin que el Grupo 1
lo arrastre a un fallo de compilacion), se revirtieron temporalmente los 10 archivos del Grupo 1 a
`HEAD` (`git checkout HEAD -- <10 archivos>`), se ejecuto la clase sola, y luego se restauraron los 10
archivos desde una copia identica (verificado con `diff -rq`, sin diferencias). El archivo final
entregado es el mismo en ambas corridas.

Comando: `.\mvnw.cmd -o test -Dtest=SesionControllerContractTest`
Resultado real (con los 10 archivos del Grupo 1 revertidos a HEAD, controller test en su version
final): **7 tests ejecutados, 5 PASS, 2 FAIL**.

| Test | Resultado | Causa exacta del fallo |
|---|---|---|
| `createAcceptsMinimalContractAndPassesParsedDatesAndActor` | PASS (no es RED; ver nota) | Body minimo ya funciona identico en AS-IS |
| `createRejectsRetiredFieldsWithBadRequest` | **FAIL (RED esperado)** | `AssertionError: Status expected:<400> but was:<201>` en `descripcion` (primer campo probado); produccion hoy SI reconoce `descripcion`/`aula`/`tipo`/`room` en `CrearSesionRequest`, por lo que Jackson no lanza `UnrecognizedPropertyException` y el input port SI se invoca |
| `queryByPathAndLegacyBodyPreserveCompleteSessionResponse` | PASS (regresion, no RED; ver F1) | `SesionConsultadaDTO` ya cumple el contrato de lectura sin cambios |
| `updateCloseAndGeneratePassPathBodyAndActor` | PASS (no es RED; ver nota) | Body minimo ya funciona identico en AS-IS |
| `updateRejectsRetiredFieldsWithBadRequest` | **FAIL (RED esperado)** | `AssertionError: Status expected:<400> but was:<200>` en `descripcion` (primer campo probado); produccion hoy SI reconoce `descripcion`/`aula`/`room` en `ActualizarSesionRequest` |
| `invalidBodyIsRejectedBeforeCallingPorts` | PASS (sin cambio) | Comportamiento de validacion de campos obligatorios, no tocado |
| `groupListingDelegatesToInputPortWithAuthenticatedActor` | PASS (sin cambio) | Comportamiento de listado, no tocado |

Nota: los 3 tests marcados "PASS (no es RED)" no demuestran el contrato TARGET todavia inexistente;
demuestran que el subconjunto de campos que SI sobrevive (grupo/tema/fechas/docente/usuarioEjecutor
en creacion; nombre/fechas/docente/usuarioEjecutor en actualizacion) sigue funcionando igual bajo
AS-IS y bajo TARGET, por lo que no requieren cambio de produccion para quedar en verde. Se incluyen
para dejar el contrato superviviente explicito y evitar que 04-implementador rompa el subconjunto
compatible al retirar los campos.

## RED_SNAPSHOT

| Campo | Valor |
|---|---|
| Base commit | `fa9aa901c73e55ae31071f4e74cfb2245189243a` (branch `sergio`, HEAD sin cambios durante esta fase) |
| Archivos de test | Ver lista con SHA-256 abajo (11 archivos, todos bajo `src/test/java/**`) |
| Comando (Grupo 1, compilacion) | `.\mvnw.cmd -o test-compile` (JDK 25 via `JAVA_HOME=C:\Program Files\Java\jdk-25`) |
| Exit code (Grupo 1) | `1` (BUILD FAILURE) |
| Fallo esperado (Grupo 1) | 123 errores `javac`: "no suitable constructor found" / "constructor ... cannot be applied to given types" en los 10 archivos de la tabla del Grupo 1; causa raiz: `src/main/**` aun declara los constructores AS-IS (9/8 parametros) que el contrato TARGET retira |
| Comando (Grupo 2, runtime) | `.\mvnw.cmd -o test -Dtest=SesionControllerContractTest` (con los 10 archivos del Grupo 1 temporalmente en `HEAD` para aislar la compilacion; restaurados de forma identica despues, verificado con `diff -rq`) |
| Exit code (Grupo 2) | `1` (2 failures de 7 tests) |
| Fallo esperado (Grupo 2) | `createRejectsRetiredFieldsWithBadRequest` y `updateRejectsRetiredFieldsWithBadRequest`: `AssertionError: Status expected:<400> but was:<201>/<200>` porque `CrearSesionRequest`/`ActualizarSesionRequest` todavia reconocen `descripcion`/`aula`/`tipo`/`room` (incluido el alias `setRoom`) |

### SHA-256 de los 11 archivos de test (estado RED final, working tree, sin commitear)

```
cb24e1e25c2b3dd485bced753a0dde74a14fff015bf7c6ab824843439474d080  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/usecase/mapper/CrearSesionRepositoryMapperTest.java
388c8e7e224d6da28b723b731dfb198f395a89e9188f3de570af62e14a33e3e7  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/usecase/domain/CrearSesionDomainTest.java
14729406b60e6dd326fcb6188ad5bea32e871e983adf4a6a3f3896b4505e0be8  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/usecase/impl/CrearSesionUseCaseImplTest.java
09352a3672c29ed28c5cb15aa7d2bca4c7a3bf78d7c3c9ea21d6c7f237e60b83  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/primaryports/mapper/CrearSesionMapperTest.java
0628c7bf40c01b00be73ca3cc263e5f43f1227debbb609de1876262dfe019598  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/usecase/mapper/ActualizarSesionRepositoryMapperTest.java
10f9180ed00b38d185e628aab07c804e6dddcaa88a636ca5c97d8c366857e76b  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/usecase/domain/ActualizarSesionDomainTest.java
4c19f2c6200c9c4e0641e88316e38d8599d1e226614152dbf01a82c67877cc26  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/usecase/impl/ActualizarSesionUseCaseImplTest.java
165e3d2d8da8a042fad880774bc4904921fffa55ba3a18c2c4919c46b9cd08e5  src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/primaryports/mapper/ActualizarSesionMapperTest.java
f9a3973e0ebbe2de3e41de14cf4775364aa07de244aa9e87b5bc4c3ed39277cc  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/SesionControllerContractTest.java
57e1a7b404f3f1b0fa1be5ee19534c965e2008105bd4e77e3f6562cf1b618db6  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapterTest.java
3e3e295316d367630928712a53582f1bf00eb6247f44692aeac209463ee37c42  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/testdouble/SesionRepositoryMockAdapterTest.java
```

Hash calculado con `sha256sum` (Git Bash) sobre el contenido tal como quedo en el working tree al
cierre de esta fase (ningun commit fue creado; el work item permanece en la rama `sergio` sobre el
mismo `HEAD`).

### Resolución TEST_CONTRACT_CONFLICT — arnés de `SesionControllerContractTest.java` (2026-09-22)

Contexto: 04-implementador ejecutó CONTRACT_FREEZE.md §7 completo sobre `src/main/**` (931/933 GREEN
en `.\mvnw.cmd -B -ntp verify`), dejando en RED únicamente `createRejectsRetiredFieldsWithBadRequest`
y `updateRejectsRetiredFieldsWithBadRequest` (esperado <400>, obtenido <201>/<200>). El orquestador
verificó directamente el código fuente (no una hipótesis) y emitió dictamen: el contrato de
producción es correcto (`JacksonInputConfig.java` l.15-18 registra `JsonMapperBuilderCustomizer` con
`FAIL_ON_UNKNOWN_PROPERTIES` habilitado, aplicado por Spring Boot autoconfiguration al `JsonMapper`
real); el RED es un defecto del **arnés de prueba**, no de las aserciones: `MockMvcBuilders.standaloneSetup(...)`
arma su propio `JsonMapper`/`HttpMessageConverter` sin pasar por ningún bean gestionado por Spring, y
en Jackson 3 (`tools.jackson.*`, este proyecto) `FAIL_ON_UNKNOWN_PROPERTIES` es `false` por defecto
(era `true` en Jackson 2), por lo que el `MockMvc` standalone ignoraba silenciosamente los campos
retirados en vez de rechazarlos con 400.

**Causa raíz confirmada:** arnés de prueba desalineado del `ObjectMapper`/`JsonMapper` real de
producción, no una aserción incorrecta ni un contrato mal derivado.

**Qué cambió exactamente (solo setup, `@BeforeEach`/inicialización de campos de instancia, cero
cambios en cuerpos de `@Test`):**
- Se agregaron 4 imports: `co.edu.uco.asistenciasuco.infrastructure.config.jackson.JacksonInputConfig`,
  `org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer`,
  `org.springframework.context.annotation.AnnotationConfigApplicationContext`,
  `org.springframework.http.converter.json.JacksonJsonHttpMessageConverter`,
  `tools.jackson.databind.json.JsonMapper`.
- El campo `mvc` pasó de `MockMvcBuilders.standaloneSetup(controller).setControllerAdvice(...).build()`
  a la misma cadena con `.setMessageConverters(new JacksonJsonHttpMessageConverter(buildProductionJsonMapper()))`
  agregado antes de `.build()`.
- Se agregó el método privado estático `buildProductionJsonMapper()`, que **no reimplementa ni
  duplica** la lógica de `JacksonInputConfig` (eso hubiera requerido tocar producción o arriesgar
  divergencia futura): levanta un `AnnotationConfigApplicationContext` mínimo con la clase
  `@Configuration` real `JacksonInputConfig` (sin modificarla, sin cambiar su visibilidad
  package-private del método `@Bean`), obtiene el bean `JsonMapperBuilderCustomizer` tal como lo
  hace Spring Boot autoconfiguration en producción, lo aplica a un `JsonMapper.Builder` nuevo, y
  cierra el contexto. Intento previo descartado: invocar
  `new JacksonInputConfig().strictJsonInputCoercionCustomizer()` directamente — no compila porque el
  método `@Bean` es package-private en `co.edu.uco.asistenciasuco.infrastructure.config.jackson` y el
  test vive en `co.edu.uco.asistenciasuco.infrastructure.adapter.primary.controller.sesion` (paquete
  distinto); cambiar esa visibilidad habría sido tocar `src/main/**`, fuera de alcance del tester, por
  lo que se usó el `ApplicationContext` real en su lugar (cero cambios en producción).

**Evidencia de que las 7 aserciones NO cambiaron respecto al RED previo:** el `git diff` de esta
sesión contra `HEAD` (`fa9aa90`) muestra únicamente: (a) los 4 imports nuevos, (b) la línea
`.setMessageConverters(...)` agregada al builder de `mvc`, y (c) el nuevo método
`buildProductionJsonMapper()` insertado antes del primer `@Test`. Ningún `@Test`, ningún
`assertEquals`/`andExpect`/`verify`/`verifyNoInteractions`, ningún literal JSON de body, y ningún
nombre de método de test fue tocado en esta sesión. Los 2 tests marcados RED
(`createRejectsRetiredFieldsWithBadRequest`, `updateRejectsRetiredFieldsWithBadRequest`) mantienen
exactamente las mismas aserciones (`status().isBadRequest()`, `jsonPath("$.details[0].field")`,
`jsonPath("$.details[0].code").value("FIELD_UNKNOWN")`, `verifyNoInteractions(create)`/`verifyNoInteractions(update)`)
que las que 03-tester-red congeló en la fase RED original (visibles en las líneas 88-105 y 178-195 del
archivo final, sin diferencia).

**Resultado tras la corrección:**
- `.\mvnw.cmd -o test -Dtest=SesionControllerContractTest` → `Tests run: 7, Failures: 0, Errors: 0,
  Skipped: 0` (7/7 GREEN, incluidos los 2 antes RED).
- `.\mvnw.cmd -B -ntp verify` → `Tests run: 933, Failures: 0, Errors: 0, Skipped: 0`, ArchUnit
  (`CleanArchitectureRulesTest`) `Tests run: 20, Failures: 0, Errors: 0, Skipped: 0`, JaCoCo
  `jacoco:check` → "All coverage checks have been met." (gates LINE≥80%/BRANCH≥70% del `pom.xml`),
  `BUILD SUCCESS`.
- SHA-256 del archivo tras esta resolución (working tree, sin commitear):
  `2b8d30a6f15f8c164354555d17c086a38799fb33cb5b6cc7f04d28d921ec8314` — reemplaza el valor previo de
  esta tabla para `SesionControllerContractTest.java` (el cambio de hash corresponde exclusivamente al
  arnés descrito arriba, no a las aserciones).

**Alcance respetado:** ningún archivo de `src/main/**`, ningún otro archivo de `src/test/**`, `pom.xml`
ni configuración de runtime fue modificado en esta resolución. `JacksonInputConfig.java` se leyó y se
usó (vía `AnnotationConfigApplicationContext`) pero no se editó.

## Congelación

Revisor/decision de aprobacion: pendiente (corresponde a 05-auditor). Archivos + SHA-256 de RED:
tabla anterior. Cualquier cambio posterior a estos 11 archivos por parte de 04-implementador es
`TEST_CONTRACT_CONFLICT` y debe volver a 03-tester-red/02-contratos con dictamen del auditor,
conforme a AGENTS.md §4 y TESTING_STANDARD.md.

## Integración y E2E

NO APLICA en esta fase. `SesionRepositorySqlServerAdapterTest.java` es unit (SP/JDBC mockeados, sin
motor real). No se ejecuto el perfil `-Pintegration` (Failsafe, `**/*IT.java`) porque esta tarea no
declara evidencia de ambiente SQL Server controlado disponible en esta sesion, y el PLAN.md no lo
exige para el sub-alcance backend de retiro de campos. Ver hallazgo fuera de alcance abajo sobre
`AsistenciaRepositorySqlServerIT.java`.

## Hallazgo fuera de alcance (reportado, no corregido en esta fase)

`src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/AsistenciaRepositorySqlServerIT.java`
(l.222-235, metodo `crearSesionDePrueba()`) construye `new CrearSesionRepositoryDTO(grupoId, nombreUnico,
"Sesion de certificacion de integracion (IT), eliminada al finalizar.", inicio, inicio.plusHours(2), null,
"PRESENCIAL", docenteId, docenteAUsuarioId)` con el constructor AS-IS de 9 parametros, como fixture para
un test de integracion del dominio **Asistencia** (fuera del alcance de esta vertical Sesion
crear/actualizar). No asevera `descripcion`/`aula`/`tipo` como datos reales persistidos de `Sesion` —
solo los pasa para satisfacer la firma del constructor AS-IS — por lo que **no es un
`TEST_CONTRACT_CONFLICT`**. Sin embargo, cuando 04-implementador reduzca `CrearSesionRepositoryDTO` a 6
parametros, este archivo (compilado unicamente bajo el perfil Maven `integration`, `**/*IT.java` via
Failsafe) dejara de compilar si no se ajusta la llamada al constructor. Se reporta aqui para que
04-implementador lo ajuste mecanicamente (quitar los 3 argumentos retirados) al mismo tiempo que los
11 archivos de este TEST_PLAN, evitando que el gate de integracion se rompa por sorpresa. No se
modifico en esta fase por estar fuera del alcance de dominio (`Sesion` vs `Asistencia`) declarado en
PLAN.md.

No se encontro ningun otro test, dentro o fuera de los 11 archivos listados, que afirme expresamente
`descripcion`/`aula`/`tipo` como datos reales persistidos de `Sesion` (busqueda dirigida por
`CrearSesionRequest|ActualizarSesionRequest|CrearSesionDTO|ActualizarSesionDTO|CrearSesionRepositoryDTO|
ActualizarSesionRepositoryDTO` en todo `src/test/java`, 11 coincidencias: las 9 de este TEST_PLAN que
referencian esos tipos directamente + `SesionRepositoryMockAdapter.java` de produccion-test-double, que
solo referencia el tipo como parametro sin construirlo, sin impacto).

## Decision de alcance (03-tester-red): `SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA`

CONTRACT_FREEZE.md secc. 3.4 deja explicitamente esta decision a 03-tester-red. Decision: **se
mantiene la constante** (no se exige su retiro en ningun test RED de este TEST_PLAN). Motivo: retirar
una entrada de `SesionErrorCode`/su catalogo de mensajes toca `uco-catalogos` (fuera del alcance
declarado en PLAN.md, que es "retiro de campos de contrato de creacion/actualizacion de Sesion", no
"limpieza de catalogo de errores"), y el PLAN.md no lo pide. Queda como candidato a `TECHNICAL_DEBT`
(codigo muerto documentado) para que 06-cierre lo registre si aplica. Ningun test de este TEST_PLAN
referencia `ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA`, asi que su presencia o retiro no afecta el
RED/GREEN de esta vertical.

## Falsos positivos que deben evitarse

- Ningun assert de este TEST_PLAN usa `assertTrue(true)`, `assertDoesNotThrow` como unica evidencia,
  ni `try/catch` que consuma la excepcion esperada.
- Los tests D2/E2 (`createRejectsRetiredFieldsWithBadRequest`/`updateRejectsRetiredFieldsWithBadRequest`)
  verifican `status 400` + `details[0].field`/`details[0].code` exactos (no solo "no 2xx"), y ademas
  `verifyNoInteractions(create)`/`verifyNoInteractions(update)` para descartar que el rechazo ocurra
  por una ruta distinta a la validacion de Jackson.
- Los tests de dominio/mapper NO llaman a getters retirados (`getDescripcion()`/`getAula()`/`getTipo()`)
  aun cuando el compilador AS-IS los seguiria aceptando hoy: esto evita que el test quede "verde por
  casualidad" contra produccion vieja una vez que el RED de firma se resuelva.
- Los 3 tests "PASS (no es RED)" del Grupo 2 estan documentados explicitamente como regresion del
  subconjunto superviviente, no como evidencia de RED, para que el auditor no los confunda con
  cobertura del cambio de contrato.
- No se modifico ningun assert para hacer coincidir una implementacion ya existente: todas las
  aserciones derivan directamente de CONTRACT_FREEZE.md (campo por campo, seccion 3 y 6).
