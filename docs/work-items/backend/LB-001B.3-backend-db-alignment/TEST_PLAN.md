---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# TEST_PLAN — LB-001B.3: Backend alignment against frozen DB baseline

Fase 03-tester-red. Ningun archivo de `src/main/**`, contrato aprobado, SQL, `pom.xml` ni el repo
frontend fue modificado en esta sesion. Se tocaron/crearon 5 archivos de test, todos bajo
`src/test/java/**`. Alcance autorizado por el usuario (2026-09-23, verbatim en el prompt de esta
sesion): **solo** las porciones ya congeladas en `CONTRACT_FREEZE.md` §1-5 (puntos A, B, C, D, E, F,
G, H, N, P de `TASK_AUTORIZADA.md` §27). **NO** se derivo RED para los puntos I/J/K/M (mapeo de
errores DB `SEC_001`/`SEC_002`/`SES_001`/`ATT_*`) porque `CONTRACT_MATRIX.md` fila M-19 y
`CONTRACT_FREEZE.md` §6 declaran ese alcance `CONTRACT_CONFLICT`/`NOT_READY` — decision explicita del
usuario de dejarlo en espera, no una omision de esta fase.

## Fuentes

- [PLAN.md](PLAN.md) (01-planificador).
- [CONTRACT_MATRIX.md](CONTRACT_MATRIX.md) y [CONTRACT_FREEZE.md](CONTRACT_FREEZE.md) (02-contratos,
  contrato TARGET congelado campo por campo — CONTRACT_FREEZE.md es la unica fuente de alcance para
  derivar RED en esta fase).
- [TESTING_STANDARD.md](../../testing/TESTING_STANDARD.md) y skill `uco-testing`.
- `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/TEST_PLAN.md` (patron de referencia RED
  "Grupo 1 compilacion / Grupo 2 runtime" para firmas de contrato, reutilizado aqui).
- Codigo backend real leido en esta sesion (no modificado): `SesionRepositorySqlServerAdapter.java`,
  `SesionRepositorySqlServerAdapterTest.java`, `HorarioDocenteSqlServerAdapter.java`,
  `HorarioDocenteSqlServerAdapterTest.java`, `HorarioDocenteProjection.java`,
  `HorarioDocenteDomain.java`, `HorarioDocenteDTO.java`, `ConsultarHorariosDocenteRepositoryMapper.java`,
  `ConsultarHorariosDocenteMapper.java`, `ConsultarHorariosDocenteUseCaseImplTest.java`,
  `JdbcValueMapper.java`, `JdbcValueMapperTest.java`, `RegistroAsistenciaSesionDomain.java`,
  `RegistroAsistenciaSesionDomainTest.java`, `AsistenciaRepositorySqlServerAdapterTest.java`,
  `ConsultarAsistenciasPorGrupoUseCaseImplTest.java`, `SecurityContextAuthenticatedUserResolverTest.java`,
  `RealtimeEvent.java`, `RealtimeEventResponse.java`, `RealtimeEventsControllerTest.java`,
  `JacksonInputConfig.java`.

Confirmado antes de tocar nada: el trabajo sin commit de LB-001B.1 (retiro de
`descripcion`/`aula`/`tipo` de Sesion) ya esta GREEN en `src/main/**` y en los tests existentes — no
se duplico ni se reviritio. `SesionRepositorySqlServerAdapterTest.java` AS-IS (antes de esta sesion)
ya asertaba la ausencia de `descripcion`/`aula`/`tipo`; esas aserciones se conservan como regresion,
no como RED de esta fase.

## Comportamiento esperado

| Punto §27 | Criterio/fuente | Escenario | Nivel | Archivo | Assert observable |
|---|---|---|---|---|---|
| A | CONTRACT_FREEZE.md §1 | `usp_crear_sesion` congelado sin `@idDocente` | Adapter unit | `SesionRepositorySqlServerAdapterTest.createPassesConfirmedProcedureAndParameters` | `SQL_CREAR_SESION` no contiene `@idDocente`; `MapSqlParameterSource.hasValue("idDocente")==false` |
| B | CONTRACT_FREEZE.md §2 | `usp_actualizar_sesion` congelado sin `@idDocente`; `usp_cerrar_sesion` preserva `@idDocente` AS-IS (§3, fuera de este freeze) | Adapter unit | `SesionRepositorySqlServerAdapterTest.updateCloseAndGeneratePassThePublicProcedures` | `SQL_ACTUALIZAR_SESION` sin `@idDocente`/`hasValue("idDocente")==false`; `SQL_CERRAR_SESION` conserva `@idDocente` |
| C | CONTRACT_MATRIX.md M-04 (MATCH) | Mapper `uv_sesion` ya exacto | Adapter unit (confirmacion, sin cambio) | `SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` | Cobertura ya existente confirmada; ver "Cobertura confirmada sin cambios" |
| D | CONTRACT_FREEZE.md §4 | `uv_horario_docente` congelada sin `aula`; records 11→10 componentes | Adapter unit + unit domain/mapper | `HorarioDocenteSqlServerAdapterTest`, `ConsultarHorariosDocenteRepositoryMapperTest` (nuevo), `ConsultarHorariosDocenteMapperTest` (nuevo) | SELECT sin columna `aula`; constructores TARGET de 10 parametros de `HorarioDocenteProjection`/`HorarioDocenteDomain`/`HorarioDocenteDTO` |
| E | CONTRACT_MATRIX.md M-14 (MATCH, GUARANTEED) | Batch solo `AN`/`SJC`/`EX` | Unit domain (confirmacion) | `RegistroAsistenciaSesionDomainTest.constructor_acepta_exclusivamente_el_contrato_canonico` | Ya cubierto; ver "Cobertura confirmada sin cambios" |
| F | CONTRACT_MATRIX.md M-14 | Unknown fail-closed, nunca alias legado `A/F/J/T` | Unit domain (confirmacion) | `RegistroAsistenciaSesionDomainTest.constructor_rechaza_estados_fuera_del_contrato_canonico` | Ya cubierto |
| G | CONTRACT_MATRIX.md M-13 (MATCH) | Ausencia de fila != `AN` (sin sintesis) | Adapter unit + use-case unit (confirmacion) | `AsistenciaRepositorySqlServerAdapterTest.queryMapsAttendanceFromConfirmedView` (solo `INNER JOIN`) + `ConsultarAsistenciasPorGrupoUseCaseImplTest` (mapeo 1:1) | Ya cubierto |
| H | CONTRACT_MATRIX.md M-15 (MATCH) | `idUsuarioEjecutor` obligatorio, provider-neutral | Unit (confirmacion) | `JwtAuthenticatedUserProviderTest` (`SecurityContextAuthenticatedUserResolver`) + `SesionRepositorySqlServerAdapterTest`/`AsistenciaRepositorySqlServerAdapterTest` (propagacion a los 7 SP) | Ya cubierto |
| N | CONTRACT_FREEZE.md §5, punto 2 | Sesion temporal nunca depende de `systemDefault()` | Unit (nuevo) | `JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion` | Mismo `Timestamp` de entrada produce distinto `LocalDateTime` bajo `TimeZone` UTC vs `America/Bogota` — RED real, no solo documental |
| P | CONTRACT_MATRIX.md M-16/M-17 (MATCH) | Correlacion propagada a los 7 SP (Sesion + Asistencia) | Adapter unit (confirmacion) | `SesionRepositorySqlServerAdapterTest` + `AsistenciaRepositorySqlServerAdapterTest` | Ya cubierto |
| O | CONTRACT_MATRIX.md M-22 (MISSING_IN_BACKEND, opcional) | Realtime `occurredAt` serializa ISO-8601 UTC con `Z` | HTTP contract | — | **NO_ALCANZADO en esta sesion** — ver seccion dedicada abajo |
| I/J/K/M | CONTRACT_MATRIX.md M-19 (CONTRACT_CONFLICT) | Mapeo `SEC_001`/`SEC_002`/`SES_001`/`ATT_*` | — | — | **NOT_READY, fuera de alcance de esta sesion por decision explicita del usuario** |

NO APLICA: OpenAPI (sin gate configurado), integracion SQL Server real (`-Pintegration`, sin
evidencia de ambiente controlado disponible en esta sesion — ver seccion "Integracion y E2E"),
frontend (otro repo, prohibido abrir en esta tarea).

## Pruebas RED requeridas

### Punto A/B — `SesionRepositorySqlServerAdapterTest.java` (RED runtime, sin cambio de firma)

Contrato TARGET congelado en `CONTRACT_FREEZE.md` §1-2: `usp_crear_sesion`/`usp_actualizar_sesion`
congelados NO declaran `@idDocente`. El adapter AS-IS (`SesionRepositorySqlServerAdapter.java`
l.42-51, 61-70, 129-140, 144-161) todavia lo envia en ambos SP. `CrearSesionRepositoryDTO`/
`ActualizarSesionRepositoryDTO` **no cambian de firma** (CONTRACT_FREEZE.md §1-2: el campo `docente`
se conserva, solo deja de viajar al SP) — por eso este RED es de tipo runtime (assertion failure),
no de compilacion, a diferencia del RED de punto D.

Se modificaron los 2 tests existentes que ya cubrian estos metodos (`createPassesConfirmedProcedureAndParameters`,
`updateCloseAndGeneratePassThePublicProcedures`), agregando aserciones de ausencia de `@idDocente`/
`idDocente` para crear/actualizar, y preservando explicitamente la aserticion de que `cerrarSesion`
(`usp_cerrar_sesion`, fuera de este freeze por CONTRACT_FREEZE.md §3) SI sigue enviando `idDocente`
sin cambio. Las aserciones AS-IS de `aula`/`descripcion`/`tipo` (LB-001B.1, ya GREEN) se conservaron
sin tocar como regresion.

Resultado real obtenido en esta sesion (comando y salida abajo, seccion RED_SNAPSHOT):
`createPassesConfirmedProcedureAndParameters` y `updateCloseAndGeneratePassThePublicProcedures`
fallan exactamente en la asercion nueva de ausencia de `@idDocente`, con mensaje causal explicito
(`expected: <false> but was: <true>`), sin ningun otro assert afectado.

### Punto D — Horario docente sin `aula` (RED mixto: compilacion + runtime)

Contrato TARGET congelado en `CONTRACT_FREEZE.md` §4: `uv_horario_docente` congelada NO expone
`aula`; el pipeline completo (`HorarioDocenteSqlServerAdapter` → `HorarioDocenteProjection` →
`HorarioDocenteDomain` → `HorarioDocenteDTO` — este ultimo es la respuesta HTTP directa de
`GET /api/v1/docente/horarios`, sin wrapper) debe reducirse de 11 a 10 componentes.

- **`HorarioDocenteSqlServerAdapterTest.java`** (RED runtime, sin cambio de firma): se agrego captura
  del SQL ejecutado y una aserticion de que el `SELECT` no contiene la subcadena `aula`
  (case-insensitive). El adapter AS-IS (`HorarioDocenteSqlServerAdapter.java` l.24) todavia proyecta
  `aula`, por lo que la aserticion falla hoy.
- **`ConsultarHorariosDocenteRepositoryMapperTest.java`** (nuevo, RED de compilacion): construye
  `HorarioDocenteProjection` con el constructor TARGET de 10 parametros (sin `aula`) y verifica que
  `ConsultarHorariosDocenteRepositoryMapper.toDomain(...)` propaga los 10 campos supervivientes.
  `HorarioDocenteProjection` AS-IS todavia declara el constructor de 11 parametros (con `aula` como
  decimo componente) — Maven falla en `test-compile` con "no suitable constructor found"/"actual and
  formal argument lists differ in length", exactamente en la linea del constructor, sin errores en
  ningun otro archivo.
- **`ConsultarHorariosDocenteMapperTest.java`** (nuevo, RED de compilacion, mismo patron): construye
  `HorarioDocenteDomain` con el constructor TARGET de 10 parametros y verifica que
  `ConsultarHorariosDocenteMapper.toDTO(...)` propaga los 10 campos hasta `HorarioDocenteDTO`.

Como el RED de compilacion de estos 2 archivos nuevos bloquea la fase `test-compile` de todo el
modulo (Maven compila `src/test/**` en un solo paso, igual que documento LB-001B.1 Grupo 1), para
aislar y confirmar en ejecucion real el RED runtime de `HorarioDocenteSqlServerAdapterTest`,
`SesionRepositorySqlServerAdapterTest` y `JdbcValueMapperTest` (punto N) se movieron temporalmente
los 2 archivos nuevos fuera del arbol de codigo (a un directorio de scratch fuera del repo, NO a
`git stash`/`checkout`, porque son archivos nuevos sin historial), se ejecuto
`.\mvnw.cmd -o test "-Dtest=SesionRepositorySqlServerAdapterTest,HorarioDocenteSqlServerAdapterTest,JdbcValueMapperTest"`,
y luego se restauraron ambos archivos de vuelta a su ubicacion original, verificado con `diff -q`
(sin diferencias) antes y despues. El contenido final entregado es identico en ambas corridas — mismo
patron aplicado por 03-tester-red en `LB-001B.1-db-source-of-truth-cleanup/TEST_PLAN.md` (Grupo 2),
adaptado aqui a "mover fuera del arbol" en vez de "revertir a HEAD" porque los archivos aislados son
nuevos (sin version previa en `HEAD` a la cual revertir).

**Hallazgo fuera de alcance (reportado, no corregido en esta fase):**
`ConsultarHorariosDocenteUseCaseImplTest.java` (l.41-43,
`execute_consulta_horarios_del_docente_resuelto`) tambien construye `HorarioDocenteProjection` con
el constructor AS-IS de 11 parametros (incluye `"Aula 1"`). No se referencia en
`CONTRACT_FREEZE.md` §7 ("Tests a crear/ajustar") como archivo a tocar por 03-tester-red, y no se
modifico en esta sesion para no ampliar el alcance mas alla de lo congelado. Cuando 04-implementador
reduzca `HorarioDocenteProjection` a 10 parametros, este archivo dejara de compilar si no se ajusta
al mismo tiempo (mismo patron que `AsistenciaRepositorySqlServerIT.java` reportado en
`LB-001B.1-db-source-of-truth-cleanup/TEST_PLAN.md`). Se reporta aqui para que 04-implementador lo
ajuste mecanicamente (quitar el argumento `"Aula 1"`) junto con los archivos de produccion listados
en `CONTRACT_FREEZE.md` §7.

### Punto N — Estabilidad temporal sin `systemDefault()` (RED runtime, nuevo)

Contrato TARGET congelado en `CONTRACT_FREEZE.md` §5, punto 2: `Sesion.fechaHoraInicio`/
`fechaHoraFin` deben leerse igual sin importar el `user.timezone` de la JVM (DB declara `DATETIME2`
con semantica UTC; prohibido `ZoneId.systemDefault()`/equivalentes implicitos).

Se agrego `JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`:
construye un `java.sql.Timestamp` bajo `TimeZone.setDefault(UTC)` a partir de
`LocalDateTime.of(2026, 6, 15, 8, 30, 0)`, cambia el default de la JVM a `America/Bogota`
(UTC-05:00) y llama `JdbcValueMapper.toLocalDateTime(timestamp)`. **Hallazgo real, no solo
documental:** `java.sql.Timestamp#toLocalDateTime()` (usado internamente por
`JdbcValueMapper.toLocalDateTime`) deriva year/month/day/hour/minute/second via
`java.util.Date`, cuyos accesores (`getYear()`/`getHours()`/etc.) normalizan usando
`TimeZone.getDefault()` **en el momento de la lectura**, no en el de la escritura — es una
dependencia oculta real de `systemDefault()`, no solo una "semantica implicita sin bug activo" como
caracterizaba `CONTRACT_MATRIX.md` M-20 antes de esta evidencia. Resultado real obtenido en esta
sesion: `expected: <2026-06-15T08:30> but was: <2026-06-15T03:30>` (desplazamiento de exactamente 5
horas, consistente con UTC-05:00) — RED confirmado con evidencia real de ejecucion, no una hipotesis.

### Puntos C, E, F, G, H, P — cobertura confirmada sin cambios

Conforme al alcance autorizado ("si ya hay tests que lo cubren, NO los toques ni los dupliques; si
falta un caso explicito, agregalo"), se inspecciono la cobertura existente de cada punto y se
confirmo que ya es explicita y suficiente, sin necesidad de un test nuevo:

| Punto | Archivo(s) ya existentes | Por que ya cubre el contrato |
|---|---|---|
| C | `SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` | Aserta columnas exactas de `uv_sesion` (10 columnas del contrato) y el caso "sin fila → null" |
| E | `RegistroAsistenciaSesionDomainTest.constructor_acepta_exclusivamente_el_contrato_canonico` (`@ParameterizedTest` con `AN`/`SJC`/`EX`) | Aserta que el dominio solo acepta los 3 estados canonicos |
| F | `RegistroAsistenciaSesionDomainTest.constructor_rechaza_estados_fuera_del_contrato_canonico` (`@ParameterizedTest` con `ABC`/`ASISTIO`/`PRESENTE`/`AUSENTE`/`A`/`F`/`T`/`J`) | Aserta fail-closed explicito para unknown Y para los 4 alias legado citados en TASK_AUTORIZADA.md §13 (`A`/`F`/`J`/`T`), lanzando `ValidationException` en todos los casos — nunca conversion a `AN` |
| G | `AsistenciaRepositorySqlServerAdapterTest.queryMapsAttendanceFromConfirmedView` (solo `INNER JOIN`, sin `LEFT JOIN`/roster) + `ConsultarAsistenciasPorGrupoUseCaseImplTest` (mapeo 1:1 de lo que el repositorio retorna, sin relleno) | Ninguna ruta de codigo sintetiza `AN` para estudiantes sin fila persistida |
| H | `JwtAuthenticatedUserProviderTest` (4 tests: UUID valido, sin authentication, no autenticada, principal invalido — todos exigen `ForbiddenException` o UUID real, nunca null) + `SesionRepositorySqlServerAdapterTest`/`AsistenciaRepositorySqlServerAdapterTest` (verifican `idUsuarioEjecutor` propagado a los 7 SP: crear/actualizar/cerrar/generarSesiones + registrarAsistenciasSesion/registrarAsistenciaAutonoma/solicitarRevision/resolverSolicitud) | Cubre "obligatorio" (resolver nunca retorna null, lanza Forbidden) y "provider-neutral" (el resolver solo lee `Authentication.getName()`, sin Keycloak) |
| P | `SesionRepositorySqlServerAdapterTest` (`params.getAllValues().forEach(value -> assertEquals(CORRELATION, ...))`, 4 SP) + `AsistenciaRepositorySqlServerAdapterTest` (mismo patron, 4 SP) | Los 7 SP de escritura del Golden Path (Sesion x4, Asistencia x4, con solape de 1) propagan `CorrelationIdContext.require()` |

Ningun archivo de esta tabla fue modificado en esta sesion.

### Punto O — Realtime `occurredAt` serializacion ISO-8601 UTC — NO_ALCANZADO

Se evaluo pero **no se creo el test** en esta sesion (punto explicitamente opcional en el alcance:
"si logras el test de serialización realtime, ver abajo"). Motivo tecnico: a diferencia de
`JacksonInputConfig.java` (usado para el input, con precedente de reuso via
`AnnotationConfigApplicationContext` en `SesionControllerContractTest.java` de LB-001B.1), no existe
ningun `JacksonOutputConfig`/customizer explicito para la serializacion de salida en
`src/main/java` — el comportamiento real de `GET .../realtime/stream` para `Instant` depende
enteramente del autoconfigure default de Spring Boot (`spring.jackson.serialization.write-dates-as-timestamps`,
tipicamente `false` en Spring Boot, lo que produce ISO-8601 con `Z`). Reproducir ese autoconfigure
fielmente en un test unitario sin un `ApplicationContext` de Spring Boot completo (`@SpringBootTest`/
`@JsonTest`, fuera del patron unit-first de esta fase) arriesga un RED fabricado por el arnes de
prueba (un `JsonMapper.builder().findAndAddModules().build()` "pelado" invierte por defecto
`WRITE_DATES_AS_TIMESTAMPS=true`, lo que produciria un RED que no refleja el comportamiento real de
produccion — el mismo tipo de defecto de arnes que 04-implementador diagnostico y corrigio en
`LB-001B.1-db-source-of-truth-cleanup/TEST_PLAN.md`, seccion "Resolución TEST_CONTRACT_CONFLICT").
Dado que este punto es opcional y el tiempo de esta sesion se prioriza a los 10 puntos obligatorios
(A-H, N, P), se deja documentado como pendiente para una sesion posterior de 03-tester-red, con la
recomendacion explicita de usarlo solo con evidencia de un `ApplicationContext`/`@SpringBootTest`
real (o de confirmar/crear un `JacksonOutputConfig` de produccion equivalente a `JacksonInputConfig`
antes de escribir el test), no con un `JsonMapper` construido a mano. `CONTRACT_MATRIX.md` M-22
permanece `MISSING_IN_BACKEND` (tipo `Instant` correcto, test ausente) sin cambio.

## RED_SNAPSHOT

| Campo | Valor |
|---|---|
| Base commit | `fa9aa901c73e55ae31071f4e74cfb2245189243a` (branch `sergio`, HEAD sin cambios durante esta fase) |
| Archivos de test (5, todos bajo `src/test/java/**`) | Ver tabla de SHA-256 abajo |
| Comando (compilacion completa, con los 5 archivos en su ubicacion final) | `.\mvnw.cmd -o -q test-compile` |
| Exit code (compilacion completa) | `1` (BUILD FAILURE) |
| Fallo esperado (compilacion completa) | 2 errores `javac`, ambos "constructor ... cannot be applied to given types" / "actual and formal argument lists differ in length", exactamente en `ConsultarHorariosDocenteMapperTest.java:31` (`HorarioDocenteDomain`, 10 args vs 11 requeridos) y `ConsultarHorariosDocenteRepositoryMapperTest.java:31` (`HorarioDocenteProjection`, 10 args vs 11 requeridos); ningun otro archivo afectado |
| Comando (runtime aislado, con los 2 archivos de compilacion movidos temporalmente fuera del arbol) | `.\mvnw.cmd -o test "-Dtest=SesionRepositorySqlServerAdapterTest,HorarioDocenteSqlServerAdapterTest,JdbcValueMapperTest"` |
| Exit code (runtime aislado) | `1` (4 failures de 33 tests: 27 `JdbcValueMapperTest` + 4 `SesionRepositorySqlServerAdapterTest` + 2 `HorarioDocenteSqlServerAdapterTest`) |
| Fallo esperado (runtime aislado) | 4 `AssertionFailedError`, uno por punto: `SesionRepositorySqlServerAdapterTest.createPassesConfirmedProcedureAndParameters` (`expected:<false> but was:<true>` en ausencia de `@idDocente`, punto A), `SesionRepositorySqlServerAdapterTest.updateCloseAndGeneratePassThePublicProcedures` (idem, punto B), `HorarioDocenteSqlServerAdapterTest.consultarHorarioDocente_mapea_proyeccion_completa` (`expected:<false> but was:<true>` en ausencia de `aula`, punto D), `JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion` (`expected:<2026-06-15T08:30> but was:<2026-06-15T03:30>`, punto N) |
| Restauracion verificada | Los 2 archivos movidos temporalmente (`ConsultarHorariosDocenteRepositoryMapperTest.java`, `ConsultarHorariosDocenteMapperTest.java`) se restauraron a su ubicacion original en `src/test/java/**`; `diff -q` contra la copia de scratch usada en la corrida runtime confirma contenido identico antes y despues — ningun byte cambio entre la corrida runtime aislada y el estado final entregado |

### SHA-256 de los 5 archivos de test (estado RED final, working tree, sin commitear)

```
df3cdbcdbf7e68a8c513694ec9b135c8cd533e481cf4cb94c37a9866ceba22ae  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapterTest.java
8e11f9084a5941260c6f37d6d4312e895c1148364a24ac10c4326b0494a44304  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapterTest.java
7e039a96293c52961f775345db6166ed549969ea9ff106829e975900dcd1a7ec  src/test/java/co/edu/uco/asistenciasuco/application/features/docente/consultarhorarios/usecase/mapper/ConsultarHorariosDocenteRepositoryMapperTest.java
a6b06a3862d0bee9d75dfd8fdbd893a01164dbb21924a2c45b5bd48f712d73f0  src/test/java/co/edu/uco/asistenciasuco/application/features/docente/consultarhorarios/primaryports/mapper/ConsultarHorariosDocenteMapperTest.java
5ab16c3cd7c5b0a838b2948734bf5d2d6d19760a4d1e174556d407f0d64f3f10  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/JdbcValueMapperTest.java
```

Hash calculado con `sha256sum` (Git Bash) sobre el contenido tal como quedo en el working tree al
cierre de esta fase (ningun commit fue creado; el work item permanece en la rama `sergio` sobre el
mismo `HEAD` `fa9aa90`).

## Congelacion

Revisor/decision de aprobacion: pendiente (corresponde a 05-auditor). Archivos + SHA-256 de RED:
tabla anterior. Cualquier cambio posterior a estos 5 archivos por parte de 04-implementador es
`TEST_CONTRACT_CONFLICT` y debe volver a 03-tester-red/02-contratos con dictamen del auditor,
conforme a AGENTS.md §4 y TESTING_STANDARD.md. 04-implementador SI puede (y debe) ajustar
mecanicamente `ConsultarHorariosDocenteUseCaseImplTest.java` (hallazgo fuera de alcance documentado
arriba) porque ese archivo no forma parte de este congelamiento RED — no aserta el contrato TARGET
de esta fase, solo deja de compilar como efecto colateral mecanico del cambio de firma.

## Integración y E2E

NO APLICA en esta fase. Los 5 archivos de test son unit/adapter-unit (SP/JDBC mockeados o llamadas
puras, sin motor real). No se ejecuto el perfil `-Pintegration` (Failsafe, `**/*IT.java`) porque esta
tarea no declara evidencia de ambiente SQL Server controlado disponible en esta sesion (conforme a
`TASK_AUTORIZADA.md` §30, que exige una instancia CLEAN construida desde el baseline DB congelado, no
`sql_server_asistencias` si sigue `DEV_INSTANCE_REBUILD_REQUIRED` — no verificado en esta sesion, sin
evidencia de que dicha instancia este disponible). Esto se registra como limitacion, no como PASS
asumido: `VALIDATION_BLOCKED_BY_ENVIRONMENT` para el subconjunto de integracion, a resolver por
04-implementador/05-auditor con el runbook correspondiente cuando ejecuten `mvn -Pintegration verify`.

## Falsos positivos que deben evitarse

- Ningun assert de este TEST_PLAN usa `assertTrue(true)`, `assertDoesNotThrow` como unica evidencia,
  ni `try/catch` que consuma la excepcion esperada.
- Los 4 aserciones RED runtime (A, B, D, N) verifican el valor exacto esperado (`hasValue(...)==false`,
  ausencia de subcadena SQL, `LocalDateTime` exacto), no solo "no lanza"/"no es null".
- El RED de punto N se verifico con evidencia real de ejecucion (desplazamiento de 5 horas
  reproducido), no se asumio la dependencia de `systemDefault()` por lectura de codigo unicamente.
- Los tests de punto C/E/F/G/H/P confirmados como cobertura existente NO se modificaron ni se
  duplicaron — se documentan por referencia exacta a metodo/archivo, no se reescriben.
- Ningun assert de `SesionRepositorySqlServerAdapterTest`/`HorarioDocenteSqlServerAdapterTest` llama a
  getters/parametros que el contrato TARGET retira (`idDocente` para crear/actualizar Sesion, `aula`
  para horario docente) como si existieran legítimamente — la ausencia se aserta explicitamente
  (`hasValue(...)==false`, `!contains(...)`), no se omite silenciosamente.
- No se modifico ningun assert para hacer coincidir una implementacion ya existente: todas las
  aserciones derivan directamente de `CONTRACT_FREEZE.md` §1, §2, §4, §5.
- Los puntos I/J/K/M NO se tocaron ni se dejaron "medio resueltos" con heuristicas de texto libre —
  se documentan explicitamente como fuera de alcance por `CONTRACT_CONFLICT` no resuelto, conforme a
  `TASK_AUTORIZADA.md` §18 ("no clasificar por una frase humana fragil sin test contractual").

## Ajuste puntual — CONTRACT_FREEZE.md §5 revisado (dictamen 05-auditor)

Sesión separada de 03-tester-red, ejecutando `CONTRACT_FREEZE.md` §5 reescrito (§5.0-5.6) tras el
`TEST_CONTRACT_CONFLICT` de `VALIDATION.md` §4 (punto N) dictaminado por `05-auditor` en `AUDIT.md`
§3.1-3.2/§4. Detalle completo, comandos y salida real en
[RED_SNAPSHOT.md](RED_SNAPSHOT.md), sección "Ajuste puntual — CONTRACT_FREEZE.md §5 revisado" — este
apartado resume solo lo que cambia del `TEST_PLAN` respecto al punto N/C original de arriba.

**Punto N (fila de la tabla "Comportamiento esperado" de arriba) — actualización:** el test
`JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`
ahora ejercita `JdbcValueMapper.toLocalDateTimeUtc(Object)` (método nuevo, todavía no creado en
`src/main/**` — por diseño, es responsabilidad de 04-implementador, `CONTRACT_FREEZE.md` §5.1), no ya
`JdbcValueMapper.toLocalDateTime(Object)` (el helper genérico, que permanece intacto conforme a §5.3).
Único cambio: la línea de invocación al método bajo prueba (l.172). Ninguna aserción cambió.

**Punto C (fila de la tabla de arriba) — corrección del fixture, sin cambio de intención:**
`SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` seguía
cubriendo el punto C correctamente en su intención (mapeo de columnas de `uv_sesion`), pero su fixture
construía los `Timestamp` de entrada bajo la zona horaria ambiental real de la máquina de build, no
bajo una zona controlada — un round-trip simétrico que pasaba sin verificar semántica UTC
(`CONTRACT_FREEZE.md` §5.4, dictamen de `05-auditor`). Se corrigió la construcción del fixture (no las
aserciones) para fijar `TimeZone.setDefault(UTC)` explícitamente antes de construir los 2 `Timestamp`,
restaurando la zona original en `finally` — mismo patrón que el test N.

**Resultado real, no asumido:** en esta máquina de build (zona real `America/Bogota`, UTC-05:00,
confirmado por `RED_SNAPSHOT.md`), tras la corrección del fixture,
`queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` pasa de GREEN-por-accidente a **RED real**
mientras la producción no aplique `CONTRACT_FREEZE.md` §5.2 (los 3 puntos de uso, incluidos los 2
dentro de `SesionRepositorySqlServerAdapter.java`). Esto no es un defecto del ajuste: es exactamente el
resultado esperado de dejar de depender implícitamente de que la máquina de build tenga zona UTC. El
test vuelve a GREEN junto con el test N cuando 04-implementador complete §5.1-5.2 completos (el método
nuevo **y** sus 3 puntos de uso, no solo el método). Se documenta así para que 05-auditor no lo
confunda con un RED fabricado por el arnés de prueba: la causa es la misma dependencia de
`systemDefault()` que motivó toda esta revisión de §5, alcanzando ahora también a
`SesionRepositorySqlServerAdapter.consultarSesion(...)`, no solo a `JdbcValueMapper.toLocalDateTime`
en aislamiento.

**Archivos tocados en este ajuste (2, ambos ya listados en el RED_SNAPSHOT original de arriba, hash
actualizado):** `JdbcValueMapperTest.java`, `SesionRepositorySqlServerAdapterTest.java`. Ningún archivo
nuevo, ningún archivo de `src/main/**`.
