---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# AUDIT — LB-001B.3: Backend alignment against frozen DB baseline

Fase `05-auditor`. **Este documento contiene, hasta ahora, únicamente un dictamen parcial** sobre un
`TEST_CONTRACT_CONFLICT` puntual reportado por `04-implementador` en `VALIDATION.md` §4
(punto N de `TASK_AUTORIZADA.md` §27, semántica UTC de `Sesion.fechaHoraInicio`/`fechaHoraFin`).

**No es la auditoría de cierre exigida por `TASK_AUTORIZADA.md` §32.** Esa auditoría global (búsqueda
de `aula`/`idDocente`/estados legacy/`ZoneId.systemDefault`/etc. en todo el backend, y el veredicto
`SESSION GHOST CONTRACT = 0` / `LEGACY ATTENDANCE STATE = 0` / etc.) no puede ejecutarse todavía: el
work item sigue con un `CONTRACT_CONFLICT` sin resolver (mapeo de errores DB, `CONTRACT_MATRIX.md`
fila M-19, decisión explícita del usuario de dejarlo fuera de alcance) y ahora también con este
`TEST_CONTRACT_CONFLICT` sin resolver. Este documento se ampliará con la auditoría §32 cuando el work
item llegue a GREEN completo.

Pase realizado por el mismo agente de la pipeline (rol `05-auditor` invocado en esta sesión), **sin
independencia externa real** — se declara conforme a `AGENTS.md` §31 ("declara si fue un pase del
mismo agente, sin fingir independencia externa").

## 1. Alcance de este dictamen

Responder, con evidencia propia verificada directamente en el repo (no solo repetir lo que reportó
`04-implementador`):

1. ¿Es un `TEST_CONTRACT_CONFLICT` real?
2. ¿El test preexistente `JdbcValueMapperTest.toLocalDateTime_con_timestamp_lo_convierte` es un
   contrato legítimo del helper genérico AS-IS, o congela un comportamiento accidental que nunca
   debió aplicarse al caso Sesion?
3. Recomendación concreta y accionable para `02-contratos`.

## 2. Evidencia propia verificada

Archivos leídos directamente para este dictamen (no solo el resumen de 04-implementador):

- `AGENTS.md` (raíz) §"Flujo y evidencia" punto 4.
- `docs/work-items/LB-001B.3-backend-db-alignment/TASK_AUTORIZADA.md` §20-21, §27 punto N.
- `docs/work-items/LB-001B.3-backend-db-alignment/CONTRACT_FREEZE.md` §5.
- `docs/work-items/LB-001B.3-backend-db-alignment/VALIDATION.md` §4 completo.
- `docs/work-items/LB-001B.3-backend-db-alignment/RED_SNAPSHOT.md` (verificación de integridad).
- `infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/JdbcValueMapper.java`
  (método `toLocalDateTime`, incluyendo el Javadoc agregado por 04-implementador).
- `src/test/java/.../support/mapping/JdbcValueMapperTest.java` (los 2 tests en conflicto).
- `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java`
  (método `consultarSesion`/`consultarSesionesPorGrupo`, extracción del `ResultSet`).
- `src/test/java/.../core/SesionRepositorySqlServerAdapterTest.java`
  (`queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`, líneas 161-194).
- `infrastructure/adapter/secondary/persistence/sqlserver/reporting/ReporteAsistenciaSqlServerAdapter.java`
  y `infrastructure/adapter/secondary/persistence/sqlserver/academic/SesionMateriaEstudianteSqlServerAdapter.java`
  (verificación de la afirmación "3 llamadores exclusivos de `Sesion.fechaHoraInicio`/`fechaHoraFin`").
- `pom.xml` (confirmación de dependencia `mssql-jdbc`, scope `runtime`; sin acceso a su código fuente
  desde este repo).

### 2.1 Integridad RED (verificación propia)

Los SHA-256 de los 5 archivos listados en `RED_SNAPSHOT.md` coinciden byte a byte con los reportados
como "antes/después" en `VALIDATION.md` §1. No hay indicio de que `04-implementador` haya alterado
ningún test congelado. `JdbcValueMapper.toLocalDateTime(Object)` en producción permanece exactamente
como estaba (`timestamp.toLocalDateTime()`, sin conversión de zona) — solo se agregó Javadoc, sin
cambio de bytecode ejecutable.

### 2.2 Verificación independiente de la prueba de imposibilidad

Reconstruí el razonamiento sin partir del texto de `04-implementador`:

- `java.sql.Timestamp` no retiene información de zona horaria; internamente es epoch-millis + nanos.
  `Timestamp.toLocalDateTime()` decodifica año/mes/día/hora/minuto/segundo delegando en los accesores
  heredados de `java.util.Date`, que se recalculan usando `TimeZone.getDefault()` **en el momento de
  la llamada**, no en el de la construcción del objeto. Esto es coherente con el comportamiento
  documentado de `java.util.Date`/`java.sql.Timestamp` desde JDK 1.1 y no depende de una lectura del
  código fuente del JDK que yo no pueda hacer aquí — es el contrato público documentado de esas clases.
- `toLocalDateTime_con_timestamp_lo_convierte` (línea 125-128 de `JdbcValueMapperTest.java`) construye
  `Timestamp.valueOf(ldt)` y lo decodifica inmediatamente, **sin ninguna manipulación de
  `TimeZone.setDefault`** en ese test. Por tanto construcción y lectura ocurren bajo la MISMA zona
  ambiental (la que tenga la JVM en ese instante — en la máquina de build real de esta sesión,
  `America/Bogota`, según `VALIDATION.md` §4). Un round-trip simétrico (misma zona en ambos extremos)
  siempre es exitoso independientemente de cuál sea esa zona — el test es válido y pasa hoy, pero es
  **agnóstico de zona por construcción**: nunca ha verificado semántica UTC, solo consistencia interna
  de la conversión naive.
- `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` (línea 161-194 de
  `SesionRepositorySqlServerAdapterTest.java`) usa exactamente el mismo patrón: mockea
  `ResultSet.getObject("fechaHoraInicio")` para retornar `Timestamp.valueOf(start)` sin fijar
  `TimeZone`, y asevera `assertEquals(start, result.getFechaHoraInicio())`. Es el mismo round-trip
  simétrico agnóstico de zona, aplicado a través de `SesionRepositoryProjection` en vez de
  directamente sobre `JdbcValueMapper`.
- `toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion` (el test nuevo,
  línea 163-182) rompe deliberadamente esa simetría: construye bajo `TimeZone=UTC` fijado
  explícitamente y lee bajo `TimeZone=America/Bogota` fijado explícitamente. Exige que la función de
  decodificación **ignore** la zona ambiental vigente en el momento de la lectura y use siempre UTC.
- Para que una única función `f(Timestamp)` satisfaga los 3 tests a la vez, `f` debería decodificar
  usando "la zona ambiental vigente en el momento de la lectura" (para los 2 tests preexistentes, en
  una máquina cuya zona ambiental real no es UTC) **y**, simultáneamente, "siempre UTC fijo,
  ignorando la zona ambiental" (para el test nuevo). Son requisitos disjuntos sobre la misma entrada
  cuando la zona ambiental real de la máquina de build no es UTC — que es el caso confirmado y
  reproducido en esta sesión (`America/Bogota`, sin ninguna variable de entorno ni propiedad de
  sistema que fuerce `user.timezone=UTC` en `pom.xml`/`.mvn/jvm.config`, verificado por mí mismo
  revisando ambos archivos). **Confirmo, de forma independiente, que la prueba de imposibilidad de
  `04-implementador` es matemáticamente correcta**, condicionada — como el propio `VALIDATION.md`
  declara explícitamente — a que la zona ambiental de la máquina de build no sea UTC.

### 2.3 Evaluación de la "tercera opción" (extracción con `Calendar` UTC en el punto de uso)

La tarea me pide evaluar explícitamente si introducir una extracción específica en
`SesionRepositorySqlServerAdapter` usando `rs.getTimestamp(columnLabel, Calendar.getInstance(TimeZone.getTimeZone("UTC")))`
en vez de `rs.getObject(columnLabel)` + `JdbcValueMapper.toLocalDateTime(...)`, dejando el helper
genérico y su test intactos, evita el conflicto.

**No lo evita, por dos razones independientes, ambas verificadas por mí directamente en el código:**

**(a) No resuelve el problema de fondo por sí sola.** `rs.getTimestamp(col, calUTC)` (patrón JDBC
estándar para columnas sin zona, documentado en `java.sql.ResultSet`) hace que el driver construya el
`Timestamp` interpretando el valor crudo de la columna como si estuviera en la zona del `Calendar`
dado — es decir, corrige el **epoch-millis** resultante. Pero el objeto `Timestamp` que devuelve sigue
siendo un `Timestamp` ordinario sin marca de zona. Si después se le sigue llamando `.toLocalDateTime()`
(directamente o vía `JdbcValueMapper.toLocalDateTime`), esa llamada **vuelve a decodificar usando la
zona ambiental vigente en el momento de la lectura**, no la zona del `Calendar` usado para construir
el epoch — reintroduciendo exactamente el mismo defecto, solo que un paso más adelante. Para que esta
vía funcione de verdad hace falta el mismo cambio de comportamiento ya identificado por
`04-implementador` (`timestamp.toInstant().atZone(ZoneOffset.UTC).toLocalDateTime()`), aplicado en el
punto de uso en vez de en el helper — no es una alternativa al cambio de comportamiento, es el mismo
cambio de comportamiento relocalizado.

**(b) Reubicar el cambio no protege al segundo test congelado.** Leí
`SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` línea por
línea: el mock solo interpone `when(resultSet.getObject("fechaHoraInicio"))...` — **no** stubea
`ResultSet.getTimestamp(String, Calendar)`. Si el adaptador cambia su llamada de `rs.getObject(...)` a
`rs.getTimestamp(col, cal)`, el mock (`mock(ResultSet.class)`, creado sin `@ExtendWith(MockitoExtension.class)`
ni verificación estricta de stubs — confirmado leyendo el encabezado del archivo, líneas 1-40) no
intercepta esa llamada y Mockito retorna `null` por defecto para el tipo de retorno objeto. El resultado
sería `result.getFechaHoraInicio() == null`, y la aserción `assertEquals(start, result.getFechaHoraInicio())`
fallaría — un fallo nuevo y distinto (NPE de aserción por `null` en vez de desfase de 5 horas), pero
sigue siendo una ruptura del mismo test congelado.

Y aunque el mock se ajustara para stubear `getTimestamp(String, Calendar)` (lo cual ya sería, por sí
mismo, una modificación de un archivo del `RED_SNAPSHOT`, prohibida para `04-implementador` sin pasar
por `02-contratos`/`03-tester-red`), el fixture del test construye `Timestamp.valueOf(start)` bajo la
zona ambiental real de la máquina (sin fijar `TimeZone` explícitamente), no bajo UTC explícito. Por el
mismo razonamiento de la sección 2.2, ninguna decodificación fija-UTC puede recuperar `start` a partir
de ese fixture en una máquina cuya zona ambiental real no sea UTC. **El conflicto entre "decodificar
UTC fijo" y "decodificar con la zona ambiental de construcción" es inherente al fixture del test tal
como está escrito hoy, no al método ni al punto de extracción que se use para llegar a él.**

**Conclusión de este punto: la "tercera opción" es arquitectónicamente razonable como patrón JDBC
general (`getTimestamp(col, Calendar)` es la forma estándar de forzar interpretación de zona en
columnas sin zona), pero no es una vía que evite tocar tests congelados — solo desplaza el mismo
conflicto de "romper `JdbcValueMapperTest.toLocalDateTime_con_timestamp_lo_convierte`" a "romper
`SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`" (que de
todas formas ya está en la lista de tests afectados según `VALIDATION.md` §4, evidencia 2). No es una
salida no considerada por `04-implementador`: es la misma imposibilidad, con el mismo alcance real,
vista desde otro ángulo.**

### 2.4 Verificación de la afirmación "3 llamadores exclusivos de Sesion"

Confirmado por mí, leyendo el código (no solo repitiendo el Javadoc de 04-implementador):

- `SesionRepositorySqlServerAdapter.java` líneas 179-180, 209-210: `rs.getObject("fechaHoraInicio")`/
  `"fechaHoraFin")` sobre `uv_sesion`.
- `ReporteAsistenciaSqlServerAdapter.java` líneas 29-30 (`SELECT ... s.fechaHoraInicio, s.fechaHoraFin`)
  y 69-70 (`JdbcValueMapper.toLocalDateTime(rs.getObject("fechaHoraInicio"))`/`"fechaHoraFin"`) — el
  alias `s` corresponde a la vista de sesión en el `JOIN`, mismos dos campos.
  `SesionMateriaEstudianteSqlServerAdapter.java` líneas 25 y 43-44: mismo patrón, mismos dos campos.

No encontré ningún tercer campo (no-Sesion) que invoque `JdbcValueMapper.toLocalDateTime` en
`src/main/java`. La afirmación de `04-implementador` es correcta.

## 3. Dictamen

### 3.1 ¿Es un `TEST_CONTRACT_CONFLICT` real?

**Sí. CONFIRMADO, con alcance más amplio del que documenta `VALIDATION.md`.**

No es un error del implementador ni del tester. La prueba de imposibilidad es correcta y la extendí
independientemente: no solo el fix "obvio" evaluado por `04-implementador`
(`timestamp.toInstant().atZone(ZoneOffset.UTC).toLocalDateTime()` en el helper genérico) es
irreconciliable con los 2 tests congelados en una máquina de build cuya zona ambiental real no es UTC
— **cualquier** cambio de comportamiento equivalente, sin importar en qué punto del código se ubique
(helper genérico, método dedicado nuevo, o extracción `Calendar`-based en el adapter), es igualmente
irreconciliable con `SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`
tal como ese test está escrito hoy, porque el conflicto no vive en la implementación del helper sino en
cómo ese test construye su fixture (`Timestamp.valueOf(...)` bajo zona ambiental no controlada,
aseverado con round-trip simétrico). La "tercera opción" planteada por la tarea (§2.3 de este
documento) no es una salida no considerada: es la misma imposibilidad matemática, reubicada.

**Único camino que evita tocar cualquier archivo del `RED_SNAPSHOT.md`:** fijar `user.timezone=UTC`
como propiedad de sistema de la JVM (p. ej. `-Duser.timezone=UTC` vía `<argLine>` de Surefire/Failsafe
o `.mvn/jvm.config`) **combinado con** el cambio de comportamiento
(`toInstant().atZone(ZoneOffset.UTC)`) en el punto de decodificación. Verifiqué esto por separado
(sección 4.2): bajo esa combinación, los 2 tests preexistentes pasarían porque su construcción
`Timestamp.valueOf(...)` ocurriría bajo zona ambiental ya forzada a UTC (coincidiendo con la
decodificación fija UTC), y el test nuevo N seguiría pasando porque su decodificación ignora
explícitamente cualquier `TimeZone.setDefault` posterior. Esta vía no es "ningún cambio", es un cambio
de configuración de build (y, para ser real en producción y no solo cosmético en tests, también de
arranque del runtime) — se documenta en la recomendación (§4) con sus propios riesgos, no como algo ya
resuelto.

### 3.2 ¿El test preexistente documenta un contrato legítimo, o un comportamiento accidental?

**Ninguno de los 2 tests preexistentes (`toLocalDateTime_con_timestamp_lo_convierte` y
`queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`, en la porción que ejercita fechas) prueba
semántica UTC. Ambos son round-trips simétricos agnósticos de zona:** pasan bajo cualquier zona
ambiental estable, siempre que construcción y lectura ocurran bajo la misma zona sin cambios en medio.
Nunca han verificado — ni podían verificar, tal como están escritos — que el valor persistido se
interprete como UTC. Documentan la consistencia interna de `Timestamp.valueOf(ldt).toLocalDateTime() == ldt`,
una propiedad verdadera de la API de Java independientemente de cualquier decisión de negocio sobre
zonas horarias.

Esto significa que la asunción de `CONTRACT_FREEZE.md` §5 ("solo Javadoc + test, sin cambio de
comportamiento") **era objetivamente insuficiente para el requisito real** de `TASK_AUTORIZADA.md`
§20-21 ("La persistencia debe interpretar los DATETIME2 de Sesion como UTC... Nunca:
systemDefault"). No fue una asunción irrazonable en el momento en que se escribió (no exigía todavía
la prueba negativa de estabilidad frente a distintos `user.timezone`, que es precisamente lo que
`03-tester-red` añadió después como punto N) — pero quedó objetivamente refutada por la evidencia
empírica que `04-implementador` generó al intentar implementarla. Esto no es una falla de
`02-contratos`; es exactamente el flujo que `AGENTS.md` §4 prevé: un test revela que el contrato
congelado era insuficiente, y el caso vuelve a `02-contratos`/`03-tester-red` con dictamen del auditor.

No se trata de que el helper genérico esté "mal" en abstracto — `toLocalDateTime` sigue siendo
correcto para cualquier caller que NO tenga semántica UTC explícita (hoy no existe ninguno, pero el
helper es compartido por diseño y no hay evidencia de que deba dejar de serlo). El problema es
puntual: los **2 tests que lo ejercitan con fixtures de zona no controlada** nunca debieron
considerarse suficientes para congelar el caso Sesion, porque son estructuralmente incapaces de
distinguir "decodifica con zona ambiental" de "decodifica siempre UTC" — las dos semánticas
coinciden por accidente solo si la máquina de build tiene zona ambiental UTC, cosa que
`TASK_AUTORIZADA.md` no puede garantizar y que, de hecho, no se cumple en esta máquina real
(`America/Bogota`).

## 4. Recomendación para `02-contratos`

No corresponde a este rol implementar ni elegir definitivamente — el punto 21 de `TASK_AUTORIZADA.md`
asigna esa elección explícitamente a `02-contratos` ("El agente de contratos debe elegir el cambio
mínimo que garantice semántica UTC sin romper arquitectura"). Presento dos opciones viables,
verificadas por mí, con su alcance de touch exacto sobre `RED_SNAPSHOT.md`:

### Opción A — decodificación dedicada para Sesion (alcance mínimo, recomendada)

Introducir un método de decodificación **distinto** de `JdbcValueMapper.toLocalDateTime(Object)` —
p. ej. `JdbcValueMapper.toSesionUtcLocalDateTime(Object)` o una extracción equivalente inline en los 3
puntos de uso — que decodifique siempre como
`timestamp.toInstant().atZone(java.time.ZoneOffset.UTC).toLocalDateTime()`, usado exclusivamente por
`SesionRepositorySqlServerAdapter`, `ReporteAsistenciaSqlServerAdapter` y
`SesionMateriaEstudianteSqlServerAdapter` para `fechaHoraInicio`/`fechaHoraFin`.

- `JdbcValueMapper.toLocalDateTime(Object)` y su test
  `toLocalDateTime_con_timestamp_lo_convierte` **no se tocan en absoluto** (método distinto, cero
  intersección).
- `SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`
  **sí requiere modificación** — su fixture debe construir el `Timestamp` bajo `TimeZone=UTC`
  explícito (mismo patrón que el test N ya usa), no bajo zona ambiental. Esto es una modificación de
  un archivo del `RED_SNAPSHOT.md`: requiere que `03-tester-red` la derive formalmente (nuevo
  `TEST_PLAN`/RED para ese archivo puntual) con autorización de `02-contratos`, no que
  `04-implementador` la haga motu proprio.
- Sin impacto en `Horario` (TIME local) ni en ningún otro dominio temporal — cambio estrictamente
  scoped a los 3 llamadores ya confirmados exclusivos de Sesion (§2.4).
- Coherente con `TASK_AUTORIZADA.md` §21 ("no hacer migración indiscriminada de toda la aplicación")
  y con el principio de cambio mínimo.
- **Riesgo/pendiente no verificable por mí en este repo:** si el driver `mssql-jdbc` real, al leer una
  columna `DATETIME2` sin zona vía `rs.getObject(...)`, produce un `Timestamp` cuyo epoch-millis ya
  asume la zona ambiental del JVM (comportamiento típico de `getObject` para tipos temporales sin
  zona) o si hace falta específicamente `rs.getTimestamp(col, Calendar UTC)` para fijar la
  interpretación en el punto de lectura del driver — el patrón estándar JDBC dice que sí hace falta el
  `Calendar` explícito para columnas sin zona si no se quiere depender de la zona por defecto del
  driver/conexión, pero no pude confirmar el comportamiento concreto de `mssql-jdbc` para
  `DATETIME2`/`getObject` leyendo solo este repo (no tengo su código fuente disponible aquí). Esto
  debe verificarse en una IT real contra la instancia SQL Server congelada (`SqlStoredProcedureContractIT`
  o equivalente, conforme `TASK_AUTORIZADA.md` §30) antes de dar por cerrado el punto N — un test
  unitario con `ResultSet` mockeado, por diseño, no puede validar esto.

### Opción B — `user.timezone=UTC` a nivel de build/runtime + decodificación explícita UTC

Fijar `-Duser.timezone=UTC` (Surefire/Failsafe `argLine` y arranque del runtime de producción) y
cambiar `JdbcValueMapper.toLocalDateTime(Object)` para decodificar siempre vía
`toInstant().atZone(ZoneOffset.UTC)`.

- Verificado por mí (§2.2/3.1): bajo esta combinación, los 2 tests preexistentes pasarían sin
  modificar una sola línea de ningún archivo del `RED_SNAPSHOT.md` (su fixture pasaría a construirse
  bajo zona ambiental ya-UTC, coincidiendo con la decodificación fija), y el test N seguiría pasando
  (su decodificación es zona-agnóstica por diseño).
- **Riesgo real, no descartable sin auditoría adicional:** es un cambio de configuración de JVM de
  alcance global, no scoped a Sesion. `TASK_AUTORIZADA.md` §20 distingue explícitamente
  `Horario.TIME` como "hora académica **local**" (no UTC) — forzar `user.timezone=UTC` no cambia el
  valor almacenado de `LocalTime` (que no lleva zona), pero sí puede afectar cualquier otro punto del
  backend que dependa implícitamente de `ZoneId.systemDefault()`/`TimeZone.getDefault()` fuera del
  alcance de Sesion (logging con timestamps locales, serialización JSON de fechas sin zona explícita,
  expiración de tokens, jobs programados, auditoría) — no audité esos puntos en esta sesión (fuera del
  alcance de este dictamen puntual) y por tanto no puedo garantizar que el blast radius sea cero.
  Contradice más directamente el principio de `TASK_AUTORIZADA.md` §21 ("no hacer migración
  indiscriminada de toda la aplicación") que la Opción A.
- Requiere además aplicar el cambio de configuración al runtime de producción, no solo al build de
  test — de lo contrario los tests pasan en verde pero la producción real reproduce el mismo defecto
  en cualquier servidor cuya zona de sistema operativo no sea UTC.

### Recomendación

Prefiero la **Opción A** por menor alcance/blast-radius y mayor alineación con `TASK_AUTORIZADA.md`
§21, con la salvedad explícita de que su implementación real depende de confirmar el comportamiento de
`mssql-jdbc` con una IT contra la DB congelada — límite que declaro abiertamente, no una brecha que
pueda cerrar desde este rol ni en esta sesión. La decisión final, y la autorización para que
`03-tester-red` modifique `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` (bajo cualquiera de
las dos opciones salvo que se descubra una tercera vía), corresponde a `02-contratos`.

## 5. Estado de salida de este dictamen parcial

- `TEST_CONTRACT_CONFLICT` (punto N): **CONFIRMADO real**, devuelto a `02-contratos`/`03-tester-red`
  conforme a `AGENTS.md` §4.
- Puntos A, B, C, D, E, F, G, H, P de `TASK_AUTORIZADA.md` §27: no auditados en este pase (fuera del
  alcance puntual solicitado); `VALIDATION.md` §6 los reporta GREEN — pendiente de verificación propia
  en un pase de auditoría posterior o en la auditoría de cierre §32.
- Este work item permanece **NO cerrado**. No se emite veredicto `DB ↔ BACKEND: ALIGNED` /
  `LB-001B.3: DONE` en este documento — eso corresponde a la auditoría §32 después de que este
  conflicto y el Bloqueo 1 (mapeo de errores DB) tengan resolución.

---

# AUDITORÍA POST-GREEN (§32)

Pase realizado por el mismo agente de la pipeline (rol `05-auditor` invocado en esta sesión), **sin
independencia externa real** — se declara conforme a `AGENTS.md` §"Flujo y evidencia" punto 4 ("La
revisión es conceptualmente independiente y no corrige durante la auditoría") y a la norma ya aplicada
en la sección anterior de este documento.

**Alcance de esta auditoría:** revisión independiente post-GREEN del alcance efectivamente
implementado por `04-implementador` (`CONTRACT_FREEZE.md` §1-5, puntos A, B, C, D, E, F, G, H, N, P de
`TASK_AUTORIZADA.md` §27), conforme al checklist de `TASK_AUTORIZADA.md` §32. **No** es la auditoría de
cierre total del work item: el mapeo de errores DB (Bloqueo 1, `CONTRACT_FREEZE.md` §6,
`CONTRACT_MATRIX.md` fila M-19) sigue `CONTRACT_CONFLICT` sin resolver por decisión explícita del
usuario, fuera de alcance de esta sesión — no se audita como si debiera estar resuelto, y por tanto no
se emite veredicto `LB-001B.3: DONE` ni se completa `TASK_AUTORIZADA.md` §33-37 en este pase (`docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` no existe todavía — confirmado, `Glob` sin resultados —
consistente con que el work item no ha llegado a esa fase).

## 1. `mvn verify` reproducido de forma independiente

Comando ejecutado por mí mismo en esta sesión, desde cero, sin reutilizar ningún número reportado por
`04-implementador`: `.\mvnw.cmd -B -ntp verify` (Windows), HEAD confirmado `fa9aa901c73e55ae31071f4e74cfb2245189243a` (branch `sergio`, igual al `Base commit` declarado en `RED_SNAPSHOT.md`/`TEST_PLAN.md`).

**Resultado real, verificado por mí:**

| Métrica | Valor reproducido independientemente |
|---|---|
| Resultado build | **BUILD SUCCESS** |
| Tests | `Tests run: 936, Failures: 0, Errors: 0, Skipped: 0` |
| ArchUnit | 16 clases bajo `co.edu.uco.asistenciasuco.architecture.*` (`AdapterCompositionRootRulesTest`, `AdaptersShouldNotBeUsedByDomainTest`, `ApplicationMustNotUsePortalConceptsTest`, `ApplicationShouldNotCarryTechnicalCorrelationTest`, `ApplicationShouldNotDependOnInfrastructureTest`, `ApplicationShouldNotDependOnReactiveInfrastructureTest`, `ApplicationShouldNotUseInfrastructureTechnicalApisTest`, `CleanArchitectureRulesTest`, `ControllersMustDependOnlyOnInputPortsTest`, `DomainShouldNotDependOnSpringTest`, `IdentityProviderIsolationRulesTest`, `InfrastructureStructureRulesTest`, `InstitutionalRolePurityTest`, `SecurityProviderIsolationRulesTest`, `SourcePackageConsistencyTest`, `UseCasesShouldNotKnowSqlResultProtocolTest`) — **0 failures, 0 errors, PASS** |
| JaCoCo `jacoco:check` | Ejecutado dentro de este `verify` (llegó a la fase), salida `[INFO] All coverage checks have been met.` — **PASS real, gate ejecutado, no proyectado** |
| JaCoCo LINE/BRANCH (recalculado por mí desde `target/site/jacoco/jacoco.csv` generado por esta misma corrida) | `LINE: missed=4751, covered=28289 → 85.62%` (gate ≥80%: CUMPLE) · `BRANCH: missed=583, covered=1394 → 70.51%` (gate ≥70%: CUMPLE, margen ajustado) |

**Coincide exactamente** con lo reportado por `04-implementador` en `VALIDATION.md` §7.3-7.4 (936/936,
16 clases ArchUnit, LINE 85.62%/BRANCH 70.51%). No encontré discrepancia entre el número reportado y el
número reproducido — confirmo `MAVEN VERIFY: PASS`, `ARCHUNIT: PASS`, `JACOCO: PASS` de forma
independiente, no por confianza en el reporte ajeno.

**Nota sobre el margen `BRANCH`:** 70.51% sobre un gate de ≥70% es un margen de 0.51 puntos
porcentuales — ajustado, tal como ya advertía `CONTRACT_FREEZE.md` §9 (heredado de LB-001B.1). No es un
fallo, pero es un riesgo de regresión real para cualquier cambio futuro que reduzca cobertura de rama
sin compensarla; lo registro como riesgo operativo, no como hallazgo de esta fase.

## 2. Barrido global (`src/main/java`, backend vigente) — clasificado

Todas las búsquedas siguientes las ejecuté yo mismo con `grep`/ripgrep sobre `src/main/java` completo,
sin restringir a los archivos que `CONTRACT_FREEZE.md` declara tocados, para no heredar el sesgo de
alcance de fases anteriores.

### 2.1 `aula`

Coincidencias reales, todas clasificadas:

- **Dominio Grupo** (`GrupoRepositorySqlServerAdapter`, `CrearGrupoDomain`/`DTO`/`Mapper`,
  `ActualizarGrupoDomain`/`DTO`/`Mapper`, `GrupoHttpMapper`, `CrearGrupoRequest`,
  `ActualizarGrupoRequest`): **MATCH legítimo de otro dominio.** `Grupo.aula` es un campo real y
  vigente del contrato de Grupo (aula física asignada al grupo), sin relación con `Sesion.aula`
  (retirado). No es el ghost param que `TASK_AUTORIZADA.md` §8/§12 prohíbe.
- **`HorarioEstudianteSqlServerAdapter`/`HorarioEstudianteProjection`/`HorarioEstudianteDomain`/`HorarioEstudianteDTO`/`ConsultarHorariosEstudianteMapper`** (proyección `uv_horario_estudiante`): **hallazgo legítimo, fuera de este freeze.** `CONTRACT_FREEZE.md` §4 documenta explícitamente que esta cadena (M-06 en `CONTRACT_MATRIX.md`) es `NOT_APPLICABLE`/`OUT_OF_TARGET` y no se toca en este work item — no es un olvido, es una decisión de alcance ya registrada. No forma parte del Golden Path (`TASK_AUTORIZADA.md` §7 no lista ningún endpoint de horario-estudiante).
- **`Sesion`/`HorarioDocente`**: **0 coincidencias.** Confirmado — el pipeline `HorarioDocenteSqlServerAdapter → HorarioDocenteProjection → HorarioDocenteDomain → HorarioDocenteDTO` no contiene `aula` en ningún punto (verificado leyendo los 4 archivos completos, no solo grep).

**Veredicto `aula` en Sesion/HorarioDocente (alcance de este freeze): 0.**

### 2.2 `idDocente`

Clasificado uno por uno:

- **`SesionRepositorySqlServerAdapter.java`**: 1 coincidencia real, en `SQL_CERRAR_SESION` (l.52-58,
  `@idDocente = :idDocente`). Verificado leyendo el archivo completo: `SQL_CREAR_SESION` (l.42-50) y
  `SQL_ACTUALIZAR_SESION` (l.60-68) **no** contienen `@idDocente` — confirmado, coincide con
  `CONTRACT_FREEZE.md` §1-2. El único remanente está en `usp_cerrar_sesion`, retenido **por decisión
  explícita** de `CONTRACT_FREEZE.md` §3 (fuera de este freeze, SP legacy `OUT_OF_TARGET`/`LEGACY_NOT_SUPPORTED` sin firma documentada en el contrato DB congelado). **No es un ghost param sin
  clasificar — ya está clasificado y documentado.**
- **`AsistenciaRepositorySqlServerAdapter.java`** (l.47, 85, `SQL_RESOLVER_SOLICITUD_REVISION`,
  `usp_resolver_solicitud_revision_asistencia`): **MATCH legítimo, otro dominio/SP.** `idDocente` aquí
  es el docente que resuelve una solicitud de revisión de asistencia — un parámetro de negocio real de
  ese SP específico, no relacionado con `usp_crear_sesion`/`usp_actualizar_sesion`.
- **`GrupoRepositorySqlServerAdapter`, `CrearGrupoDomain`/`DTO`/`Mapper`,
  `ActualizarGrupoDomain`/`DTO`/`Mapper`, `GrupoEntity`, `GrupoDTO`, `CrearGrupoRequest`,
  `ActualizarGrupoRequest`, `GrupoRepositoryProjection`, `GrupoRepositoryRowMapper`**: **MATCH
  legítimo de otro dominio.** `Grupo.idDocente` es el docente titular del grupo, campo real y vigente
  de ese contrato, sin relación con Sesion.
- **`HorarioDocenteSqlServerAdapter`, `HorarioDocenteProjection`, `HorarioDocenteDomain`,
  `HorarioDocenteDTO`, `HorarioDocenteQueryPort`, `ConsultarHorariosDocenteUseCaseImpl`,
  `AsignaturaDocenteSqlServerAdapter`, `AsignaturaDocenteQueryPort`,
  `ConsultarAsignaturasDocenteUseCaseImpl`**: **MATCH legítimo de otro dominio.** `idDocente` es aquí
  el parámetro de consulta ("horario/asignaturas de este docente"), funcionalidad propia de esos
  endpoints, no un parámetro enviado a un SP de Sesion.
- **`InstitutionalScopeSqlServerAdapter.java`** (l.72, `AND idDocente = (...)`): **MATCH legítimo.**
  Cláusula `WHERE` de un query de resolución de scope institucional (`findDocenteIdByUsuario`), no un
  parámetro de SP de Sesion.

**Veredicto `idDocente` como ghost param de Sesion específicamente (crear/actualizar): 0.**
**Veredicto `idDocente` como parámetro SP de Sesion en general (incluyendo `usp_cerrar_sesion`, fuera
de este freeze por decisión explícita): 1, ya clasificado y documentado, no un hallazgo nuevo.**

### 2.3 `PROGRAMADA`, `EN_CURSO`, `CONCLUIDA` (estados legacy de sesión)

**0 coincidencias en `src/main/java`.** Búsqueda ejecutada sobre todo el árbol, sin resultados.

### 2.4 `"A"`, `"F"`, `"J"`, `"T"` como alias de negocio de asistencia

**0 coincidencias como alias legado de asistencia.** Verificado en el dominio canónico
(`RegistroAsistenciaSesionDomain.java`, l.18): `ESTADOS_VALIDOS = Set.of("AN", "SJC", "EX")` — solo el
contrato canónico. Ninguna ruta de `src/main/java` mapea `"A"→"AN"`/`"F"→"SJC"`/etc. La búsqueda amplia
de literales de un solo carácter `"A"`/`"F"`/`"J"`/`"T"` en los paquetes de sesión/asistencia no
produjo coincidencias — no hay literales de un solo carácter usados para otra cosa en esos paquetes que
requieran distinguirse.

**Veredicto: 0.**

### 2.5 `ZoneId.systemDefault()`

**0 coincidencias de código ejecutable.** La única aparición de la cadena `ZoneId.systemDefault()` en
todo `src/main/java` es dentro de un comentario Javadoc en `JdbcValueMapper.java` (l.75), que
**describe la prohibición**, no la implementa.

**Advertencia importante — la métrica literal no captura la dependencia real:** el grep textual da 0,
pero **existe una dependencia de zona horaria por defecto de la JVM funcionalmente equivalente**,
sin usar literalmente `ZoneId.systemDefault()`: `JdbcValueMapper.toLocalDateTime(Object)` (el helper
genérico, intacto) decodifica `java.sql.Timestamp` vía `timestamp.toLocalDateTime()`, que internamente
usa `TimeZone.getDefault()` en el momento de la lectura (demostrado empíricamente por
`JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`, GREEN hoy solo porque ejercita `toLocalDateTimeUtc`, no `toLocalDateTime`). Verifiqué que
**`SesionMateriaEstudianteSqlServerAdapter.java` (l.43-44) sigue invocando este helper genérico para
`Sesion.fechaHoraInicio`/`fechaHoraFin`** — confirmado por mí leyendo el archivo completo: sigue
llamando `JdbcValueMapper.toLocalDateTime(rs.getObject("fechaHoraInicio"))`/`"fechaHoraFin"`, no
`toLocalDateTimeUtc`. Los otros 2 llamadores confirmados (`SesionRepositorySqlServerAdapter.java`
l.179-180, 209-210; `ReporteAsistenciaSqlServerAdapter.java` l.69-70) sí usan `toLocalDateTimeUtc` —
verificado leyendo ambos archivos completos.

**Veredicto textual (`ZoneId.systemDefault()` literal): 0.**
**Veredicto sustantivo (dependencia real de zona horaria por defecto de la JVM para
`Sesion.fechaHoraInicio`/`fechaHoraFin`): 1 punto de uso activo en producción
(`SesionMateriaEstudianteSqlServerAdapter`), no 0.** Ver §3 para el análisis de si este punto de uso
está o no dentro del Golden Path.

### 2.6 `VAL_003`

**0 coincidencias en `src/main/java`.**

### 2.7 Hallazgo adicional no solicitado explícitamente por la lista de §32, pero dentro de su espíritu — `descripcion` en `SesionErrorCode`

Extendí el barrido a `descripcion`/`tipo`/`status` en los paquetes de Sesion (más allá de la lista
literal de §32) porque `TASK_AUTORIZADA.md` §8/§12 los nombra explícitamente junto a `aula`/`idDocente`
como parámetros DB obsoletos a eliminar. Encontré:

```
SesionErrorCode.java:13: ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA("ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA",
    "Cuando se indique una descripcion, debe tener entre 10 y 250 caracteres.", ErrorKind.VALIDATION),
```

Verifiqué que este valor del enum **no se referencia en ningún otro archivo de `src/main/java` ni
`src/test/java`** (`grep` de `ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` en todo `src/` devuelve
únicamente su propia declaración). Es un código de error **muerto**, remanente de cuando `Sesion` tenía
un campo `descripcion` (retirado en `LB-001B.1`, confirmado por `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/`). **No envía nada a la DB, no es un ghost param SP** (no aparece en ningún
`SQL_*`/`MapSqlParameterSource` de Sesion) — no viola `SESSION GHOST CONTRACT = 0` en el sentido
estricto que exige `TASK_AUTORIZADA.md` §32 (parámetros SP), pero es deuda técnica real y un residuo
textual del contrato retirado, no reportado por `VALIDATION.md` ni por el `AUDIT.md` previo. Lo reporto
como **hallazgo nuevo, no corregido** (fuera de mi rol arreglarlo): candidato a retirar en una limpieza
de deuda técnica posterior, conforme a `TASK_AUTORIZADA.md` §34.

## 3. Verificación independiente del hallazgo de `VALIDATION.md` §7 — `SesionMateriaEstudianteSqlServerAdapter` y `ReporteAsistenciaSqlServerAdapter`

Leí directamente ambos archivos de producción y ambos archivos de test (no solo el resumen de
`04-implementador`).

**Confirmado, preciso:**

- `SesionMateriaEstudianteSqlServerAdapter.java` (l.43-44): sigue usando
  `JdbcValueMapper.toLocalDateTime(...)` (AS-IS, dependiente de `TimeZone.getDefault()` en el momento
  de la lectura) para `Sesion.fechaHoraInicio`/`fechaHoraFin`. Su test,
  `SesionMateriaEstudianteSqlServerAdapterTest.consultarSesionesMateria_mapea_proyeccion_completa`
  (l.44, 53), construye `Timestamp.valueOf(LocalDateTime.of(2026,1,20,8,0))` bajo la zona ambiental
  real de la máquina (sin `TimeZone.setDefault` explícito) y asevera
  `assertEquals(LocalDateTime.of(2026,1,20,8,0), resultado.getFirst().fechaHoraInicio())` — el mismo
  patrón de round-trip simétrico agnóstico de zona ya dictaminado como insuficiente en la sección
  anterior de este mismo `AUDIT.md` (§3.2). Confirmo: este es el defecto **manifestado** — al intentar
  cambiar la llamada a `toLocalDateTimeUtc`, este test específico falló (`expected:
  <2026-01-20T08:00> but was: <2026-01-20T13:00>`, documentado en `VALIDATION.md` §7.2), y
  `04-implementador` revirtió el cambio de producción en vez de tocar el test — correcto conforme a su
  rol, no un error.
- `ReporteAsistenciaSqlServerAdapter.java` (l.69-70): **ya usa `JdbcValueMapper.toLocalDateTimeUtc(...)`** (corregido, no AS-IS). Su test,
  `ReporteAsistenciaSqlServerAdapterTest.consultarReporteAsistenciaGrupo_mapea_fila_completa`, también
  construye `Timestamp.valueOf(LocalDateTime.of(2026,1,20,8,0))` bajo zona ambiental no controlada
  (l.43-44), pero **no asevera el valor de `fechaHoraInicio`/`fechaHoraFin` en ningún assert** (solo
  asevera `codigoGrupo`, `numeroSesion`, `asistio`, `razonCausa`) — confirmado leyendo el archivo
  completo. Precisión respecto a `VALIDATION.md` §7.2: **no es un defecto de producción activo** (la
  producción ya decodifica correctamente como UTC fijo) — es una **brecha de cobertura de test**: si
  alguien revirtiera accidentalmente esta llamada a `toLocalDateTime`, este test no lo detectaría,
  porque no comprueba el campo. `VALIDATION.md` §7.2 lo describe como "mismo defecto latente, no
  manifestado" — confirmo la ausencia de aserción, pero preciso que a diferencia de
  `SesionMateriaEstudianteSqlServerAdapter` (defecto de producción real y activo), aquí la producción
  ya es correcta; lo que falta es la aserción de regresión.

**Verificación de pertenencia al Golden Path (`TASK_AUTORIZADA.md` §7):**

Verifiqué yo mismo, no asumí, buscando los controladores HTTP que exponen estos dos query ports:

- `SesionMateriaEstudianteQueryPort` → `ConsultarSesionesMateriaEstudianteUseCaseImpl` →
  `EstudiantePortalController` → `GET /api/v1/estudiante/materias/{materiaId}/sesiones`.
- `ReporteAsistenciaQueryPort` → `GenerarReporteAsistenciaUseCaseImpl` →
  `ReporteAsistenciaController` → `GET /api/v1/grupos/{grupoId}/reportes/asistencia-excel`.

Ninguno de los dos endpoints aparece en la lista exacta de `TASK_AUTORIZADA.md` §7 (`GET
/api/v1/docente/horarios`, `GET /api/v1/sesiones/grupo/{grupoId}`, `GET
/api/v1/grupos/{grupoId}/estudiantes`, `GET /api/v1/grupos/{grupoId}/asistencias?sesionId=...`, `POST
/api/v1/asistencias/lote`, `GET /api/v1/realtime/stream?grupoId=...`, más create/update Sesion).
**Confirmado: ninguno de los dos adaptadores forma parte del Golden Path.** El "probablemente NO" de
`VALIDATION.md` §7.2 es correcto, verificado de forma independiente, no asumido.

**Consecuencia para el veredicto §32:** dado que ninguno de los dos está en el Golden Path, la
dependencia real de `TimeZone.getDefault()` en `SesionMateriaEstudianteSqlServerAdapter` **no** impide
declarar `SYSTEM DEFAULT TIMEZONE DEPENDENCY = 0` **dentro del Golden Path** — pero sí impide declararlo
`0` a nivel de "todo el backend vigente que lee `Sesion.fechaHoraInicio`/`fechaHoraFin`", que es la
redacción literal de `TASK_AUTORIZADA.md` §20 ("El backend NO puede aplicar `ZoneId.systemDefault()`
para interpretar Sesion" — sin calificar "solo en el Golden Path"). Reporto ambos números por
separado para que `02-contratos`/`06-cierre` decidan cuál aplica al criterio de salida.

## 4. Integridad — trabajo de LB-001B.1 y archivos autorizados por CONTRACT_FREEZE.md

Recalculé yo mismo SHA-256 de los 18 archivos listados en `GOLDEN_PATH_DIRTY_FILE_HASHES.txt`
(snapshot de `LB-001B.1`) contra el working tree actual:

- **17 de 18 archivos: hash idéntico**, byte a byte, al snapshot de `LB-001B.1` — confirmado, ningún
  byte modificado por esta sesión ni por ninguna posterior.
- **1 archivo con hash distinto:** `SesionRepositorySqlServerAdapter.java` (snapshot
  `3c7af5c0...`, actual `7754aed3...`). **No es una reversión ni una violación** — es precisamente el
  archivo que `CONTRACT_FREEZE.md` §1, §2 y §5.2 de **este mismo work item (LB-001B.3)** autorizan
  explícitamente a modificar (retiro de `@idDocente` de `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION`,
  cambio de `toLocalDateTime`→`toLocalDateTimeUtc` en los 2 métodos de lectura). El cambio de hash es
  el resultado esperado de una fase posterior autorizada sobre el mismo archivo, no una regresión del
  trabajo de `LB-001B.1`.

**Verificación de archivos tocados fuera de la lista `CONTRACT_FREEZE.md` §7:** listé todo
`git status --porcelain` sobre `src/main/java` y `src/test/java`. Todos los archivos de producción
modificados (`git status` `M`) corresponden exactamente a: (a) los 17 archivos de `LB-001B.1` sin tocar
(confirmado por hash), o (b) los archivos explícitamente autorizados por `CONTRACT_FREEZE.md` §7/§5.6
(`HorarioDocenteDTO.java`, `ConsultarHorariosDocenteMapper.java`, `HorarioDocenteDomain.java`,
`ConsultarHorariosDocenteRepositoryMapper.java`, `HorarioDocenteProjection.java`,
`HorarioDocenteSqlServerAdapter.java`, `SesionRepositorySqlServerAdapter.java`,
`ReporteAsistenciaSqlServerAdapter.java`, `JdbcValueMapper.java`). **Ningún archivo de producción fuera
de esta lista fue modificado.**

Para los archivos de test modificados que no aparecen en `RED_SNAPSHOT.md` (5 archivos) ni en la lista
de ajustes mecánicos de `VALIDATION.md` §3 (2 archivos adicionales: `ConsultarHorariosDocenteUseCaseImplTest.java`, `DocentePortalControllerTest.java`) — verifiqué que **todos** los demás test
files modificados (`ActualizarSesionMapperTest.java`, `CrearSesionDomainTest.java`,
`AsistenciaControllerContractTest.java`, `SesionControllerContractTest.java`,
`RbacSecurityFilterChainTest.java`, `SecurityConfigTest.java`, `AsistenciaRepositorySqlServerIT.java`,
`SesionRepositoryMockAdapterTest.java`, entre otros) están documentados como alcance de
**`LB-001B.1-db-source-of-truth-cleanup`** (confirmado buscando cada nombre de archivo en los documentos
de ese work item — 6 coincidencias en `CLOSURE.md`/`VALIDATION.md`/`AUDIT.md`/`TEST_PLAN.md`/`CONTRACT_FREEZE.md`/`PLAN.md` de `LB-001B.1`), no de esta sesión — son parte del mismo estado
`dirty` sin commitear heredado, no una modificación nueva de `LB-001B.3`.

Encontré además archivos **no rastreados (`??`)** sin relación con `LB-001B.3`:
`application/features/catalogo/**`, `infrastructure/config/wiring/CatalogoWiringConfiguration.java` y
sus tests — corresponden al commit `HEAD` más reciente ("feat(cloud): integrate Azure Key Vault, App
Configuration parameter & message catalogs") y no interfieren con el alcance de Sesion/Horario/temporal
de este work item. No los clasifico como violación de este freeze — están fuera de su dominio, pero los
registro para que `06-cierre` los tenga en cuenta al describir el estado real del árbol de trabajo.

**Veredicto: integridad confirmada.** Ningún archivo de `LB-001B.1` fue revertido. Ningún archivo de
producción fuera de lo autorizado por `CONTRACT_FREEZE.md` fue tocado.

## 5. Veredicto por punto del checklist §32

| Requisito §32 | Veredicto | Evidencia |
|---|---|---|
| `aula` — clasificado, ninguna coincidencia ilegítima | PASS | §2.1 |
| `descripcion`/`tipo`/`status` de Sesion — clasificado | PASS con hallazgo nuevo no bloqueante | §2.7 (`SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA`, código muerto) |
| `idDocente` — clasificado, ghost param de Sesion crear/actualizar | PASS | §2.2 |
| `PROGRAMADA`/`EN_CURSO`/`CONCLUIDA` | PASS (0) | §2.3 |
| `"A"`/`"F"`/`"J"`/`"T"` alias asistencia | PASS (0) | §2.4 |
| `ZoneId.systemDefault()` literal | PASS (0) | §2.5 |
| `VAL_003` | PASS (0) | §2.6 |
| `SESSION GHOST CONTRACT = 0` | **CONFIRMADO = 0** (dentro del alcance: crear/actualizar Sesion) | §2.1, §2.2 |
| `LEGACY ATTENDANCE STATE = 0` | **CONFIRMADO = 0** | §2.4 |
| `SYSTEM DEFAULT TIMEZONE DEPENDENCY = 0` | **NO CONFIRMADO a nivel de todo el backend** — literal = 0, sustantivo = 1 (`SesionMateriaEstudianteSqlServerAdapter`, fuera del Golden Path) | §2.5, §3 |
| `SESSION idDocente SP PARAM = 0` | **NO ES 0** — 1 remanente en `usp_cerrar_sesion`, **ya clasificado y retenido por decisión explícita** de `CONTRACT_FREEZE.md` §3, no un hallazgo sin resolver | §2.2 |
| `mvn verify` reproducido | BUILD SUCCESS, 936/936, confirmado independientemente | §1 |
| ArchUnit | PASS, 16 clases, confirmado independientemente | §1 |
| JaCoCo | PASS real (gate ejecutado), LINE 85.62%/BRANCH 70.51%, confirmado independientemente | §1 |
| Hallazgo `VALIDATION.md` §7 (`SesionMateriaEstudianteSqlServerAdapter`/`ReporteAsistenciaSqlServerAdapter`) | Confirmado preciso, con matiz: solo el primero tiene defecto de producción activo; el segundo es brecha de cobertura de test, no defecto de producción | §3 |
| Integridad LB-001B.1 / archivos autorizados | Confirmada, sin violaciones | §4 |

## 6. Conclusión de esta auditoría post-GREEN

**No se emite `DB ↔ BACKEND: ALIGNED` / `LB-001B.3: DONE`** — no corresponde a este pase (el work item
declara explícitamente, y esta sesión confirma, que el Bloqueo 1 de mapeo de errores DB permanece
`CONTRACT_CONFLICT` sin resolver, fuera de alcance de esta auditoría por decisión del usuario).

**Dentro del alcance efectivamente implementado (`CONTRACT_FREEZE.md` §1-5):**

- `SESSION DB SIGNATURES` (crear/actualizar sin `idDocente`): **MATCH, confirmado independientemente.**
- `SESSION READ PROJECTION` (`uv_sesion` sin campos retirados): **MATCH, confirmado.**
- `HORARIO DOCENTE` sin `aula` (pipeline completo): **MATCH, confirmado.**
- `ATTENDANCE STATES` (`AN`/`SJC`/`EX`, sin alias legado): **MATCH, confirmado.**
- `UTC PERSISTENCE` para Sesion: **PARCIAL, no MATCH completo.** 2 de 3 llamadores confirmados
  (`SesionRepositorySqlServerAdapter`, `ReporteAsistenciaSqlServerAdapter`) decodifican
  `Sesion.fechaHoraInicio`/`fechaHoraFin` con semántica UTC fija, verificado por mí. El tercero
  (`SesionMateriaEstudianteSqlServerAdapter`, fuera del Golden Path pero dentro del alcance textual de
  `TASK_AUTORIZADA.md` §20) permanece con la dependencia de `TimeZone.getDefault()` no resuelta, por un
  `TEST_CONTRACT_CONFLICT` nuevo (`VALIDATION.md` §7.2) que aún no tiene resolución de
  `02-contratos`/`03-tester-red`.
- `MAVEN VERIFY`/`ARCHUNIT`/`JACOCO`: **PASS, confirmado independientemente por mí, no heredado.**

**Bloqueantes reales para cierre de LB-001B.3 (no corregidos por mí, conforme a mi rol):**

1. Bloqueo 1 — mapeo de errores DB (`CONTRACT_CONFLICT`, `CONTRACT_FREEZE.md` §6), decisión explícita
   del usuario de dejarlo abierto, fuera de esta sesión.
2. `TEST_CONTRACT_CONFLICT` nuevo de `VALIDATION.md` §7.2 (`SesionMateriaEstudianteSqlServerAdapterTest`), pendiente de que `02-contratos`/`03-tester-red` autoricen la misma corrección de fixture ya
   aplicada a `SesionRepositorySqlServerAdapterTest` (`CONTRACT_FREEZE.md` §5.4).
3. Hallazgo nuevo no bloqueante: `SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA`, código de
   error muerto remanente del campo `descripcion` retirado — candidato a deuda técnica (`TASK_AUTORIZADA.md` §34), no bloquea `mvn verify` ni el Golden Path.
4. Brecha de cobertura no bloqueante: `ReporteAsistenciaSqlServerAdapterTest` no asevera
   `fechaHoraInicio`/`fechaHoraFin`, por lo que no detectaría una regresión futura de `toLocalDateTimeUtc` a `toLocalDateTime` en ese adaptador.

**READY FOR FRONTEND VERIFICATION / READY FOR LB-001C OPENAPI:** no evaluado en este pase (depende de
la resolución de los bloqueantes 1 y 2 arriba, y de la fase §33-37 de `TASK_AUTORIZADA.md`, que este
work item no ha alcanzado — `docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` no existe todavía).
