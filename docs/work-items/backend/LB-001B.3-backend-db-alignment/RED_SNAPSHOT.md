---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# RED_SNAPSHOT — LB-001B.3: Backend alignment against frozen DB baseline

Fase 03-tester-red. Documento standalone exigido por `TASK_AUTORIZADA.md` §3 (lista de archivos del
work item) ademas de la seccion `RED_SNAPSHOT` embebida en [TEST_PLAN.md](TEST_PLAN.md) conforme a
`docs/testing/TESTING_STANDARD.md` ("Todo TEST_PLAN con RED incluye una seccion RED_SNAPSHOT"). El
contenido es el mismo; este archivo existe para que 05-auditor pueda referenciarlo directamente sin
abrir el TEST_PLAN completo, tal como pide la tarea autorizada.

Alcance de esta sesion: solo las porciones congeladas en `CONTRACT_FREEZE.md` §1-5 (puntos A, B, C,
D, E, F, G, H, N, P de `TASK_AUTORIZADA.md` §27). Punto O evaluado, no alcanzado (ver TEST_PLAN.md).
Puntos I/J/K/M explicitamente fuera de alcance (`CONTRACT_CONFLICT` sin resolver, `CONTRACT_MATRIX.md`
fila M-19, decision explicita del usuario 2026-09-23).

## Identidad

| Campo | Valor |
|---|---|
| Base commit | `fa9aa901c73e55ae31071f4e74cfb2245189243a` |
| Branch | `sergio` |
| Working tree | dirty (incluye trabajo sin commit de LB-001B.1 y gobernanza `??`, no tocado) |
| JDK | 25 (`JAVA_HOME` apuntando a `jdk-25`, enforcer `[25,26)` en `pom.xml`) |
| Archivos de test tocados/creados en esta sesion | 5, todos bajo `src/test/java/**`, ninguno bajo `src/main/**` |

## Archivos de test y SHA-256 (estado RED final, working tree, sin commitear)

| Archivo | Tipo de cambio | SHA-256 |
|---|---|---|
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapterTest.java` | Modificado (2 tests existentes ajustados: puntos A/B) | `df3cdbcdbf7e68a8c513694ec9b135c8cd533e481cf4cb94c37a9866ceba22ae` |
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapterTest.java` | Modificado (1 test existente ajustado: punto D, capa adapter) | `8e11f9084a5941260c6f37d6d4312e895c1148364a24ac10c4326b0494a44304` |
| `src/test/java/co/edu/uco/asistenciasuco/application/features/docente/consultarhorarios/usecase/mapper/ConsultarHorariosDocenteRepositoryMapperTest.java` | Nuevo (punto D, capa mapper→domain) | `7e039a96293c52961f775345db6166ed549969ea9ff106829e975900dcd1a7ec` |
| `src/test/java/co/edu/uco/asistenciasuco/application/features/docente/consultarhorarios/primaryports/mapper/ConsultarHorariosDocenteMapperTest.java` | Nuevo (punto D, capa mapper→DTO HTTP) | `a6b06a3862d0bee9d75dfd8fdbd893a01164dbb21924a2c45b5bd48f712d73f0` |
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/JdbcValueMapperTest.java` | Modificado (1 test nuevo agregado: punto N) | `5ab16c3cd7c5b0a838b2948734bf5d2d6d19760a4d1e174556d407f0d64f3f10` |

Hash calculado con `sha256sum` (Git Bash) sobre el contenido tal como quedo en el working tree al
cierre de esta fase.

## Comandos ejecutados y salida real

### 1. Compilacion completa (los 5 archivos en su ubicacion final del repo)

Comando: `.\mvnw.cmd -o -q test-compile`

Exit code: `1` (BUILD FAILURE)

Fallo esperado y obtenido: 2 errores `javac`, ambos "constructor ... cannot be applied to given
types" / "actual and formal argument lists differ in length":

```
[ERROR] .../application/features/docente/consultarhorarios/primaryports/mapper/ConsultarHorariosDocenteMapperTest.java:[31,45]
  constructor HorarioDocenteDomain in record ...HorarioDocenteDomain cannot be applied to given types;
  required: UUID,UUID,UUID,String,String,String,String,LocalTime,LocalTime,String,Integer
  found:    UUID,UUID,UUID,String,String,String,String,LocalTime,LocalTime,int
  reason: actual and formal argument lists differ in length

[ERROR] .../application/features/docente/consultarhorarios/usecase/mapper/ConsultarHorariosDocenteRepositoryMapperTest.java:[31,53]
  constructor HorarioDocenteProjection in record ...HorarioDocenteProjection cannot be applied to given types;
  required: UUID,UUID,UUID,String,String,String,String,LocalTime,LocalTime,String,Integer
  found:    UUID,UUID,UUID,String,String,String,String,LocalTime,LocalTime,int
  reason: actual and formal argument lists differ in length
```

Causa raiz: `HorarioDocenteDomain`/`HorarioDocenteProjection` en `src/main/**` todavia declaran el
constructor AS-IS de 11 parametros (con `aula`); los 2 archivos nuevos usan el constructor TARGET de
10 (CONTRACT_FREEZE.md §4). Ningun otro archivo aparece en la salida de error.

### 2. Runtime aislado (los 2 archivos de compilacion movidos temporalmente fuera del arbol de codigo)

Para observar en ejecucion real el RED de los puntos A, B, D (nivel adapter) y N sin que el RED de
compilacion del punto D (nivel record) bloquee toda la fase `test`, se movieron
`ConsultarHorariosDocenteRepositoryMapperTest.java` y `ConsultarHorariosDocenteMapperTest.java` a un
directorio de scratch fuera del repositorio (no `git stash`/`checkout` porque son archivos nuevos sin
version previa en `HEAD`), se ejecuto el comando siguiente, y luego se restauraron ambos archivos a
su ubicacion original, verificado con `diff -q` (sin diferencias) contra la copia usada en la corrida.

Comando: `.\mvnw.cmd -o test "-Dtest=SesionRepositorySqlServerAdapterTest,HorarioDocenteSqlServerAdapterTest,JdbcValueMapperTest"`

Exit code: `1`

Resultado: `Tests run: 33, Failures: 4, Errors: 0, Skipped: 0` (27 en `JdbcValueMapperTest` + 4 en
`SesionRepositorySqlServerAdapterTest` + 2 en `HorarioDocenteSqlServerAdapterTest`).

Salida real (resumen de fallos):

```
[ERROR] HorarioDocenteSqlServerAdapterTest.consultarHorarioDocente_mapea_proyeccion_completa:70
  uv_horario_docente congelada no expone aula (CONTRACT_FREEZE.md secc. 4)
  ==> expected: <false> but was: <true>

[ERROR] SesionRepositorySqlServerAdapterTest.createPassesConfirmedProcedureAndParameters:86
  usp_crear_sesion congelado no declara @idDocente (CONTRACT_FREEZE.md secc. 1)
  ==> expected: <false> but was: <true>

[ERROR] SesionRepositorySqlServerAdapterTest.updateCloseAndGeneratePassThePublicProcedures:136
  usp_actualizar_sesion congelado no declara @idDocente (CONTRACT_FREEZE.md secc. 2)
  ==> expected: <false> but was: <true>

[ERROR] JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion:174
  Sesion.fechaHoraInicio/fechaHoraFin debe leerse igual sin importar user.timezone de la JVM
  (DB_BASELINE_CONTRACT.md declara DATETIME2 con semantica UTC; prohibido
  ZoneId.systemDefault()/TimeZone.getDefault() implicito, CONTRACT_FREEZE.md secc. 5).
  ==> expected: <2026-06-15T08:30> but was: <2026-06-15T03:30>

[ERROR] Tests run: 33, Failures: 4, Errors: 0, Skipped: 0
```

Cada fallo cita la causa exacta esperada por CONTRACT_FREEZE.md (idDocente/aula presentes cuando
deberian estar ausentes; LocalDateTime desplazado 5 horas por dependencia de systemDefault), no un
error de red/DB/tipografia ni un archivo fuera del alcance de los 5 listados.

### 3. Re-confirmacion de compilacion tras restaurar los 2 archivos a su ubicacion final

Comando: `.\mvnw.cmd -o -q test-compile`

Exit code: `1` — misma salida identica a la seccion 1 (verificado). Confirma que el estado final
entregado (5 archivos en su ubicacion definitiva) reproduce el mismo RED de compilacion documentado
arriba, sin diferencias introducidas por el movimiento temporal.

## Alcance NO cubierto en este snapshot (explicito, no un olvido)

- **Puntos I/J/K/M** (`SEC_001→403`, `SEC_002→403`, `SES_001→not found`, `ATT errors`): `NOT_READY`
  por `CONTRACT_CONFLICT` sin resolver (`CONTRACT_MATRIX.md` fila M-19, `CONTRACT_FREEZE.md` §6).
  Decision explicita del usuario (2026-09-23) de no tocar `DbFailureClassifier.java`/
  `DbExceptionTranslator.java` en esta sesion. Ningun archivo relacionado fue leido con intencion de
  derivar RED, conforme a la instruccion recibida.
- **Punto O** (realtime `occurredAt` serializacion): evaluado, no alcanzado por riesgo de RED
  fabricado por el arnes de prueba (sin `JacksonOutputConfig` de produccion ni `ApplicationContext`
  de Spring Boot real disponible en el patron unit-first de esta fase). Ver `TEST_PLAN.md`, seccion
  "Punto O".

## Congelacion

Revisor: pendiente (05-auditor). Cualquier modificacion de los 5 archivos listados arriba por parte
de 04-implementador, mas alla de lo necesario para que la produccion los haga pasar a GREEN sin
tocar sus aserciones, es `TEST_CONTRACT_CONFLICT` conforme a `AGENTS.md` §4 y
`docs/testing/TESTING_STANDARD.md`.

## Ajuste puntual — CONTRACT_FREEZE.md §5 revisado (dictamen 05-auditor, `AUDIT.md` §3.1-3.2/§4)

Sesion separada de 03-tester-red, posterior al RED_SNAPSHOT original de arriba. `CONTRACT_FREEZE.md`
§5 fue reescrito por `02-contratos` tras un `TEST_CONTRACT_CONFLICT` real detectado por
`04-implementador` (`VALIDATION.md` §4, punto N) y dictaminado por `05-auditor`. Este ajuste ejecuta
exactamente `CONTRACT_FREEZE.md` §5.3 (re-apuntar el test N) y §5.4 (corregir el fixture de
`queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`) — **no** reinterpreta el contrato. Base
commit sin cambio: `fa9aa901c73e55ae31071f4e74cfb2245189243a` (branch `sergio`, ningun commit nuevo
creado en esta sesion). Ningun archivo de `src/main/**` fue tocado.

### Cambio 1 — `JdbcValueMapperTest.java` (l.172, unica linea)

Conforme a `CONTRACT_FREEZE.md` §5.3: la unica linea modificada es la invocacion al metodo bajo
prueba en `toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`:

```java
// ANTES
final LocalDateTime resultadoBajoOtroTimezone = JdbcValueMapper.toLocalDateTime(timestampDesdeJdbc);
// DESPUES
final LocalDateTime resultadoBajoOtroTimezone = JdbcValueMapper.toLocalDateTimeUtc(timestampDesdeJdbc);
```

Ninguna aserción cambió. `toLocalDateTime_con_timestamp_lo_convierte` (l.124-128) permanece exactamente
igual, cero líneas tocadas — verificado por diff de git (ver comando/salida abajo).

### Cambio 2 — `SesionRepositorySqlServerAdapterTest.java` (fixture de `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`, l.173-174 originales)

Conforme a `CONTRACT_FREEZE.md` §5.4: se capturó `TimeZone.getDefault()` en una variable, se fijó
`TimeZone.setDefault(TimeZone.getTimeZone("UTC"))`, se construyeron ambos `Timestamp.valueOf(...)` bajo
esa zona, y se restauró la zona original en un bloque `finally` — mismo patrón que
`JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`.
Ninguna aserción de valor esperado cambió; `createPassesConfirmedProcedureAndParameters`,
`updateCloseAndGeneratePassThePublicProcedures` y `rejectsMissingDtoAndWrapsJdbcFailure` no se tocaron.

### Comandos ejecutados y salida real

**Comando (estado final entregado, ambos cambios aplicados a la vez):**
`.\mvnw.cmd test -Dtest=JdbcValueMapperTest,SesionRepositorySqlServerAdapterTest`

**Exit code: `1`** (BUILD FAILURE, fase `test-compile`)

```
[ERROR] COMPILATION ERROR :
[ERROR] .../support/mapping/JdbcValueMapperTest.java:[172,76] cannot find symbol
  symbol:   method toLocalDateTimeUtc(java.sql.Timestamp)
  location: class co.edu.uco.asistenciasuco.infrastructure.adapter.secondary.persistence.sqlserver.support.mapping.JdbcValueMapper
[INFO] 1 error
```

**Causa esperada y confirmada:** `JdbcValueMapper.toLocalDateTimeUtc(Object)` (CONTRACT_FREEZE.md §5.1)
todavía no existe en `src/main/**` — no fue creado por 03-tester-red (fuera de su alcance) ni por
04-implementador (todavía no le corresponde en esta sesión). Es RED de **compilación**, no un error de
fixture ni un test mal escrito: el símbolo referenciado en la línea 172 no existe en producción. Esto
bloquea la compilación de `src/test/**` completo (Maven compila el módulo de test en un solo paso), por
lo que este único comando no puede reportar en runtime el estado de
`toLocalDateTime_con_timestamp_lo_convierte` ni de `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`
en la misma corrida.

**Aislamiento para confirmar los otros 2 tests (revert temporal de 1 línea, NO parte del entregable
final):** se revirtió temporalmente solo la línea 172 de `JdbcValueMapperTest.java` a
`JdbcValueMapper.toLocalDateTime(...)` (dejando intacto el cambio 2 de `SesionRepositorySqlServerAdapterTest.java`),
se ejecutó el mismo comando, y se re-aplicó el cambio 1 después. Resultado de esa corrida aislada:

```
Tests run: 31, Failures: 2, Errors: 0, Skipped: 0
[ERROR] SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent:200
  expected: <2026-09-14T08:00> but was: <2026-09-14T03:00>
[ERROR] JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion:174
  ==> expected: <2026-06-15T08:30> but was: <2026-06-15T03:30>
```

- `toLocalDateTime_con_timestamp_lo_convierte`: **GREEN**, confirmado (no aparece en la lista de
  fallos; 27 tests de `JdbcValueMapperTest` con 1 sola falla, la del test N intacto pero todavía
  apuntando a `toLocalDateTime` en esta corrida aislada).
- `createPassesConfirmedProcedureAndParameters`, `updateCloseAndGeneratePassThePublicProcedures`,
  `rejectsMissingDtoAndWrapsJdbcFailure`: **GREEN**, confirmado (4 tests en
  `SesionRepositorySqlServerAdapterTest`, 1 sola falla — la de `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`).
- **Hallazgo relevante, no un error del ajuste:** `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`
  **NO** queda en GREEN en esta máquina de build con producción AS-IS (`consultarSesion(...)` todavía
  invoca `JdbcValueMapper.toLocalDateTime`, dependiente de `TimeZone.getDefault()`). La zona por
  defecto real de esta máquina es `America/Bogota` (UTC-05:00, confirmado por el offset `-05:00` en el
  log de Maven y por el desplazamiento exacto de 5 horas en el fallo). Con el fixture construyendo el
  `Timestamp` bajo UTC explícito (§5.4) y la producción decodificando todavía bajo el default real de
  la máquina (no UTC), el round-trip deja de ser simétrico — exactamente la dependencia oculta que
  `CONTRACT_FREEZE.md` §5.4 describe como "pasaba por accidente" antes del ajuste. Este test **vuelve
  a GREEN recién cuando `04-implementador` aplique `CONTRACT_FREEZE.md` §5.2 completo**, incluyendo los
  2 puntos de uso dentro de `SesionRepositorySqlServerAdapter.java` (l.179-180, l.209-210) que deben
  pasar a `toLocalDateTimeUtc`. En una máquina cuyo `TimeZone.getDefault()` real fuera ya `UTC`, este
  mismo ajuste de fixture habría quedado GREEN "por accidente" incluso con producción AS-IS — no es el
  caso en esta máquina de build, y se documenta la causa exacta en vez de forzar un GREEN no real.

**Conclusión de RED para el entregable final (ambos cambios juntos, comando principal de arriba):**
`toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion` permanece en RED
por razón correcta (`toLocalDateTimeUtc` inexistente en producción → RED de compilación, exit code
`1`). `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`, aislada de ese RED de compilación, es
**también RED hoy** en esta máquina de build (no GREEN), por la misma causa raíz de fondo (producción
sin `toLocalDateTimeUtc` en sus 3 puntos de uso) — consistente con, no contradictorio con, el ajuste
autorizado en `CONTRACT_FREEZE.md` §5.4. `toLocalDateTime_con_timestamp_lo_convierte` permanece
GREEN e intacto, confirmado.

### SHA-256 de los 2 archivos tocados en este ajuste (estado final, working tree, sin commitear)

```
096bde19956a047662075b103495f45c9503434f008c2a5a316f794458fe86d4  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/JdbcValueMapperTest.java
a428556516d737c2697fb0253527b5af3a90915b880dda653fb3775656df094b  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapterTest.java
```

Hash calculado con `sha256sum` (Git Bash), estado final entregado (ambos cambios aplicados, ningún
revert temporal incluido). Reemplaza los hashes de estos 2 archivos en la tabla de la sección
"Archivos de test y SHA-256" de arriba — los otros 3 archivos de esa tabla no se tocaron en este ajuste
y conservan su hash original.

**Congelación de este ajuste:** revisor pendiente (05-auditor), para comparar este snapshot contra la
versión que finalmente use 04-implementador al pasar a GREEN. Cualquier modificación adicional a estos
2 archivos más allá de lo descrito aquí es `TEST_CONTRACT_CONFLICT`.
