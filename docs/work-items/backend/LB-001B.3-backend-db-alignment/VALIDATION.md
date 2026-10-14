---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# VALIDATION — LB-001B.3: Backend alignment against frozen DB baseline

Fase `04-implementador`. Alcance ejecutado: exclusivamente `CONTRACT_FREEZE.md` §1-5 (puntos A, B, D
de `TASK_AUTORIZADA.md` §27 completos; punto N con `TEST_CONTRACT_CONFLICT` documentado, no
implementado). Ningún test RED de los 5 archivos congelados en `RED_SNAPSHOT.md` fue modificado —
verificado por SHA-256 antes y después de esta sesión (ver §"Integridad de los tests RED").

## 1. Integridad de los tests RED (verificación previa y posterior)

SHA-256 de los 5 archivos congelados, verificado idéntico a `RED_SNAPSHOT.md` **antes** de tocar
producción y **después** de completar la implementación:

```
df3cdbcdbf7e68a8c513694ec9b135c8cd533e481cf4cb94c37a9866ceba22ae  SesionRepositorySqlServerAdapterTest.java
8e11f9084a5941260c6f37d6d4312e895c1148364a24ac10c4326b0494a44304  HorarioDocenteSqlServerAdapterTest.java
7e039a96293c52961f775345db6166ed549969ea9ff106829e975900dcd1a7ec  ConsultarHorariosDocenteRepositoryMapperTest.java
a6b06a3862d0bee9d75dfd8fdbd893a01164dbb21924a2c45b5bd48f712d73f0  ConsultarHorariosDocenteMapperTest.java
5ab16c3cd7c5b0a838b2948734bf5d2d6d19760a4d1e174556d407f0d64f3f10  JdbcValueMapperTest.java
```

Ningún byte de estos 5 archivos fue modificado en esta sesión.

## 2. Archivos de producción modificados (autorizados por CONTRACT_FREEZE.md §7)

| # | Archivo | Cambio |
|---|---|---|
| 1 | `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` | Retirado `@idDocente`/`PARAM_ID_DOCENTE` de `SQL_CREAR_SESION` y de la construcción de `MapSqlParameterSource` en `crearSesion(...)`; retirado `@idDocente`/`PARAM_ID_DOCENTE` de `SQL_ACTUALIZAR_SESION` y de `actualizarSesion(...)`. `SQL_CERRAR_SESION`/`cerrarSesion(...)` NO tocados (conservan `@idDocente`, conforme CONTRACT_FREEZE.md §3). `SQL_CONSULTAR_*`/`consultarSesion*` NO tocados (ya MATCH). |
| 2 | `infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapter.java` | Retirada columna `aula` del `SELECT` de `uv_horario_docente` y del constructor de `HorarioDocenteProjection` (11→10 args). |
| 3 | `application/secondaryports/academic/projection/HorarioDocenteProjection.java` | Retirado componente `aula` del record (11→10 componentes). |
| 4 | `application/features/docente/consultarhorarios/usecase/domain/HorarioDocenteDomain.java` | Retirado componente `aula` (11→10). |
| 5 | `application/features/docente/consultarhorarios/primaryports/dto/HorarioDocenteDTO.java` | Retirado componente `aula` (11→10) — cambia el JSON de `GET /api/v1/docente/horarios` (riesgo de breaking change frontend ya registrado en CONTRACT_FREEZE.md §4, no resuelto aquí por prohibición de abrir el repo frontend). |
| 6 | `application/features/docente/consultarhorarios/usecase/mapper/ConsultarHorariosDocenteRepositoryMapper.java` | Ajustada construcción de `HorarioDocenteDomain` (11→10 args). |
| 7 | `application/features/docente/consultarhorarios/primaryports/mapper/ConsultarHorariosDocenteMapper.java` | Ajustada construcción de `HorarioDocenteDTO` (11→10 args). |
| 8 | `infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/JdbcValueMapper.java` | Solo Javadoc agregado a `toLocalDateTime(Object)` documentando semántica UTC para `Sesion.fechaHoraInicio`/`fechaHoraFin` y el `TEST_CONTRACT_CONFLICT` no resuelto (ver §4). **Sin cambio de comportamiento/código ejecutable.** |

## 3. Archivos de test ajustados mecánicamente (no forman parte del congelamiento RED)

Ambos son consecuencia mecánica directa del cambio de firma de records ya aprobado en
`CONTRACT_FREEZE.md` §4 (11→10 componentes); ninguno altera la intención de su test ni sus
aserciones de comportamiento — solo se retira el literal `"Aula 1"` del constructor stub.

| Archivo | Justificación |
|---|---|
| `src/test/java/.../application/features/docente/consultarhorarios/usecase/impl/ConsultarHorariosDocenteUseCaseImplTest.java` | Reportado explícitamente por 03-tester-red en TEST_PLAN.md como "hallazgo fuera de alcance" a ajustar por 04-implementador; no asertaba el valor de `aula`, solo lo pasaba al stub. |
| `src/test/java/.../infrastructure/adapter/primary/controller/docente/DocentePortalControllerTest.java` | Encontrado en esta sesión (no reportado previamente por 03-tester-red): construye `HorarioDocenteDTO` con 11 args (`"Aula 1"`) en el stub del mock; no asertaba `aula` en el JSON de respuesta HTTP. Mismo patrón mecánico. |

## 4. TEST_CONTRACT_CONFLICT — punto N / punto 8 (temporal UTC, `JdbcValueMapper.toLocalDateTime`)

**No implementado.** Se identificó y verificó empíricamente un conflicto irresoluble entre dos tests
congelados que ejercitan el mismo método estático `JdbcValueMapper.toLocalDateTime(Object)`.

### Evidencia

Entorno de build real de esta sesión: `TimeZone.getDefault()` = `America/Bogota` (UTC-05:00,
confirmado con `java -XshowSettings:properties` y `[System.TimeZoneInfo]::Local` en PowerShell — no
es un artefacto de shell, es la zona horaria real de Windows en esta máquina). No hay ninguna
configuración de build (`pom.xml`, `.mvn/jvm.config`, `MAVEN_OPTS`, `JAVA_TOOL_OPTIONS`) que fuerce
`user.timezone=UTC`.

**Intento de fix "obvio"** (probado y revertido en esta sesión, no permanece en el código entregado):

```java
if (value instanceof java.sql.Timestamp timestamp) {
    return timestamp.toInstant().atZone(java.time.ZoneOffset.UTC).toLocalDateTime();
}
```

Resultado al ejecutar `JdbcValueMapperTest` + `SesionRepositorySqlServerAdapterTest` con este cambio:

```
[ERROR] SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent
  expected: <2026-09-14T08:00> but was: <2026-09-14T13:00>
[ERROR] JdbcValueMapperTest.toLocalDateTime_con_timestamp_lo_convierte
  expected: <2026-01-20T08:00> but was: <2026-01-20T13:00>
```

El test nuevo (`toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`)
pasa a GREEN con este cambio, pero rompe **dos** tests congelados/confirmados adicionales:

1. `JdbcValueMapperTest.toLocalDateTime_con_timestamp_lo_convierte` — test preexistente del mismo
   archivo congelado (`JdbcValueMapperTest.java`, no modificable), round-trip genérico
   `Timestamp.valueOf(ldt).toLocalDateTime() == ldt` sin manipulación de `TimeZone`.
2. `SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent` — es
   precisamente la cobertura confirmada del **punto C** de `TASK_AUTORIZADA.md` §27
   ("ya MATCH", TEST_PLAN.md: "Ya cubierto, sin cambio"), que lee `Sesion.fechaHoraInicio` real vía
   este mismo helper. Romperlo viola directamente `CONTRACT_FREEZE.md` §7 ("No tocar ... `SQL_CONSULTAR_*`/`consultarSesion*` (ya MATCH)").

### Prueba de imposibilidad

Para cualquier función pura `f(Timestamp)`:
- El test nuevo (N) construye `Timestamp.valueOf(ldt)` bajo `TimeZone.default = UTC` (forzado) y lo
  lee bajo `TimeZone.default = America/Bogota`. Para que `f` retorne `ldt`, `f` debe decodificar
  usando UTC fijo, **ignorando** el `TimeZone.default` vigente en el momento de la lectura.
- El test preexistente (`toLocalDateTime_con_timestamp_lo_convierte` y, por el mismo patrón,
  `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`) construye `Timestamp.valueOf(ldt)` bajo el
  `TimeZone.default` ambiental real de la máquina de build (`America/Bogota`, sin ningún
  `TimeZone.setDefault` explícito) y lo lee inmediatamente después, sin cambio de zona. Para que `f`
  retorne `ldt` aquí, `f` debe decodificar usando la MISMA zona que estaba activa al construir
  (`America/Bogota` en esta máquina), no UTC fijo.
- `f` no puede simultáneamente decodificar "siempre UTC fijo" y "la zona activa al construir" —
  información que el objeto `Timestamp` no retiene (solo persiste epoch-millis + nanos; los campos
  año/mes/día/hora se recalculan en cada llamada a los accesores deprecados de `java.util.Date` según
  `TimeZone.getDefault()` **en el momento de la lectura**, no en el de la escritura). Es matemáticamente
  imposible satisfacer ambos contratos de prueba a la vez cuando el `TimeZone.default` ambiental de la
  máquina de build no es UTC (el caso real, confirmado, de esta sesión).

### Acción tomada

Conforme a `AGENTS.md` §4 y a las reglas de este rol ("NO modifica tests RED ni contrato... Si
discrepa: `TEST_CONTRACT_CONFLICT`, detiene el cambio dependiente y devuelve a contratos/tester; el
auditor dictamina sin corregir"):

- **No se modificó** el comportamiento de `JdbcValueMapper.toLocalDateTime(Object)`. El código de
  producción permanece AS-IS para esa rama (`timestamp.toLocalDateTime()`).
- **Se agregó únicamente Javadoc** (sin cambio ejecutable) documentando: (a) la semántica UTC target
  exigida por `DB_BASELINE_CONTRACT.md` para `Sesion.fechaHoraInicio`/`fechaHoraFin`, conforme al
  alcance originalmente congelado en `CONTRACT_FREEZE.md` §5 punto 1 (documentación, no código); y
  (b) este mismo `TEST_CONTRACT_CONFLICT` con referencia a esta sección de `VALIDATION.md`.
- El test `JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`
  **permanece RED** — es el único fallo del build completo (ver §5).
- Los 3 llamadores en producción de `JdbcValueMapper.toLocalDateTime` (`SesionRepositorySqlServerAdapter`,
  `ReporteAsistenciaSqlServerAdapter`, `SesionMateriaEstudianteSqlServerAdapter`) quedan confirmados
  como exclusivos de `Sesion.fechaHoraInicio`/`fechaHoraFin` (ningún campo no-Sesion comparte el
  método), documentado en el nuevo Javadoc para apoyar una resolución futura con un método específico
  para Sesion si `02-contratos`/`03-tester-red` deciden revisar la prueba round-trip (p. ej. forzando
  `user.timezone=UTC` en la configuración de build, o ajustando esa prueba preexistente para construir
  explícitamente bajo UTC).

**Este conflicto bloquea únicamente el punto N (`TASK_AUTORIZADA.md` §27) y el sub-alcance
comportamental de `CONTRACT_FREEZE.md` §5 punto 2.** No bloquea ningún otro punto de este work item.

## 5. Resultado real del build

### Comando ejecutado

```
.\mvnw.cmd -B -ntp verify
```

Se ejecutó `verify` completo (no solo `test`) conforme a `AGENTS.md`/`TASK_AUTORIZADA.md` §31. No se
ejecutó `-Pintegration` (sin evidencia de instancia SQL Server controlada disponible en esta sesión,
mismo `VALIDATION_BLOCKED_BY_ENVIRONMENT` ya documentado por 03-tester-red en TEST_PLAN.md — no
resuelto ni evaluado por 04-implementador, fuera de su alcance sin la instancia CLEAN exigida por
`TASK_AUTORIZADA.md` §30).

### Resultado

**BUILD FAILURE** — falla en la fase `test` (Surefire), antes de llegar a `jacoco:check` (Maven
detiene el reactor al primer fallo de test).

```
Tests run: 936, Failures: 1, Errors: 0, Skipped: 0

Failures:
  JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion:174
  Sesion.fechaHoraInicio/fechaHoraFin debe leerse igual sin importar user.timezone de la JVM
  ==> expected: <2026-06-15T08:30> but was: <2026-06-15T03:30>
```

Es el único failure de las 936 pruebas ejecutadas (todas las demás, incluyendo las 20 clases
`co.edu.uco.asistenciasuco.architecture.*` de ArchUnit, GREEN — 0 failures/errors en ArchUnit).

### ArchUnit

**PASS** — 20 clases de test bajo `co.edu.uco.asistenciasuco.architecture.*`, 0 failures, 0 errors
(confirmado en la salida completa de `verify`, incluye `CleanArchitectureRulesTest`,
`AdapterCompositionRootRulesTest`, `ApplicationShouldNotDependOnInfrastructureTest`,
`IdentityProviderIsolationRulesTest`, `SecurityProviderIsolationRulesTest`, entre otras).

### JaCoCo

`jacoco:check` **no se ejecutó** dentro de este `verify` (el reactor se detuvo en Surefire antes de
llegar a la fase `verify` del plugin JaCoCo, que corre `report`+`check` ahí). Como evidencia
suplementaria (no como ejecución oficial del gate), se generó el reporte manualmente con
`jacoco:report` sobre el mismo `target/jacoco.exec` producido por esa misma corrida de `verify`
(sin re-ejecutar tests):

```
LINE:   missed=1086, covered=6924  → 6924/8010 = 86.44%  (gate ≥80%:  CUMPLE)
BRANCH: missed=581,  covered=1390  → 1390/1971 = 70.52%  (gate ≥70%:  CUMPLE, margen ajustado —
                                                            consistente con lo advertido en
                                                            CONTRACT_FREEZE.md §9, heredado de
                                                            LB-001B.1, ~70.53%)
```

Estos números reflejan la ejecución real de los 936 tests (935 GREEN + 1 RED conocido); no son una
proyección. El gate JaCoCo formal (`jacoco:check` vía `mvn verify`) **no puede considerarse PASS
oficialmente** porque no llegó a ejecutarse — es una consecuencia directa de que `verify` se detiene
en el primer fallo de Surefire, no de un problema de cobertura. Cuando el `TEST_CONTRACT_CONFLICT` de
§4 se resuelva (con GREEN en el punto N), `mvn verify` completo debería llegar a `jacoco:check` con
estos mismos márgenes.

## 6. Resumen para 05-auditor

| Ítem | Estado |
|---|---|
| SESSION DB SIGNATURES (crear/actualizar sin `idDocente`) | MATCH — GREEN |
| SESSION READ PROJECTION (`consultarSesion*`) | MATCH — GREEN, sin cambios (ya MATCH) |
| HORARIO DOCENTE sin `aula` (pipeline completo) | MATCH — GREEN |
| UTC PERSISTENCE (Sesion temporal) | **NO RESUELTO — `TEST_CONTRACT_CONFLICT`**, ver §4 |
| ARCHUNIT | PASS |
| MAVEN VERIFY | **FAILURE** (1 failure conocido y explicado, 0 errors, 935/936 GREEN) |
| JACOCO (evidencia suplementaria, gate no ejecutado formalmente) | LINE 86.44% / BRANCH 70.52%, ambos sobre el mínimo si se hubiera ejecutado |
| Integridad tests RED | Verificada, SHA-256 idéntico antes/después |
| Archivos fuera de la lista de CONTRACT_FREEZE.md §7 tocados | 2, ambos ajustes mecánicos de test (§3), justificados |
| Trabajo LB-001B.1 sin commit | No revertido, confirmado por diff (§ previa a este documento) |

**Recomendación para el flujo:** este work item NO puede cerrarse con `DB ↔ BACKEND: ALIGNED` /
`LB-001B.3: DONE` mientras el `TEST_CONTRACT_CONFLICT` de §4 no reciba dictamen de `05-auditor` y
resolución de `02-contratos`/`03-tester-red`. Los puntos A, B, D (y C/E/F/G/H/P, confirmados sin
cambio) están completos y verificados GREEN.

## 7. Implementación de `CONTRACT_FREEZE.md` §5 (revisión) — punto N / M-20, TARGET REVISADO

Fase `04-implementador`, sesión posterior a §1-6 (el `TEST_CONTRACT_CONFLICT` de §4 fue dictaminado
por `05-auditor` en `AUDIT.md` y resuelto con la Opción A: método dedicado
`toLocalDateTimeUtc`, ver `CONTRACT_FREEZE.md` §5.0-5.6). Esta sección documenta la implementación de
esa revisión y un **segundo** `TEST_CONTRACT_CONFLICT`, de la misma naturaleza que el de §4, descubierto
durante esta implementación en un archivo de test que ni `CONTRACT_FREEZE.md` §5.4 ni `AUDIT.md` §2.4
identificaron como necesitando corrección de fixture.

### 7.1 Archivos de producción tocados en esta sesión (4, autorizados por CONTRACT_FREEZE.md §5.1/§5.2/§5.6)

| # | Archivo | Cambio |
|---|---|---|
| 1 | `infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/JdbcValueMapper.java` | Agregado import `java.time.ZoneOffset` y método nuevo `public static LocalDateTime toLocalDateTimeUtc(final Object value)` (inmediatamente después de `toLocalDateTime(Object)`), decodificando `java.sql.Timestamp` vía `.toInstant().atZone(ZoneOffset.UTC).toLocalDateTime()`. `toLocalDateTime(Object)` existente **no se tocó ni una línea** (verificado por diff). |
| 2 | `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` | 4 ocurrencias cambiadas de `JdbcValueMapper.toLocalDateTime(...)` a `JdbcValueMapper.toLocalDateTimeUtc(...)`: `consultarSesion(...)` (fechaHoraInicio/fechaHoraFin) y `consultarSesionesPorGrupo(...)` (fechaHoraInicio/fechaHoraFin). Campo confirmado leyendo el archivo: ambos provienen de `uv_sesion` (`SesionRepositoryProjection`), es decir `Sesion.fechaHoraInicio`/`fechaHoraFin`. Ninguna otra línea tocada. |
| 3 | `infrastructure/adapter/secondary/persistence/sqlserver/reporting/ReporteAsistenciaSqlServerAdapter.java` | 2 ocurrencias cambiadas (`fechaHoraInicio`/`fechaHoraFin`). Campo confirmado: `SELECT ... s.fechaHoraInicio, s.fechaHoraFin FROM dbo.uv_sesion s` (alias `s` = sesión), construido en `ReporteAsistenciaRow`. Es `Sesion.fechaHoraInicio`/`fechaHoraFin`. |
| 4 | `infrastructure/adapter/secondary/persistence/sqlserver/academic/SesionMateriaEstudianteSqlServerAdapter.java` | **Cambiado y luego revertido en la misma sesión** — ver §7.2. Estado final: **sigue usando `JdbcValueMapper.toLocalDateTime(...)` (AS-IS, sin cambio neto)**, no `toLocalDateTimeUtc`. Campo confirmado (antes de revertir): `SELECT s.fechaHoraInicio, s.fechaHoraFin FROM dbo.uv_sesion s ...`, también `Sesion.fechaHoraInicio`/`fechaHoraFin` — **sí es un campo de Sesion**, el punto de uso no se descartó por ser ajeno a Sesion, sino por el conflicto de test descrito en §7.2. |

Los 3 puntos de uso confirmados por `CONTRACT_FREEZE.md` §5.2/AUDIT.md §2.4 son, en efecto, campos de
`Sesion.fechaHoraInicio`/`fechaHoraFin`. Ninguno resultó ser un campo no-Sesion.

### 7.2 Segundo `TEST_CONTRACT_CONFLICT` descubierto — `SesionMateriaEstudianteSqlServerAdapterTest`

Al aplicar el cambio de llamada en `SesionMateriaEstudianteSqlServerAdapter.java` (punto 4 de §7.1) y
ejecutar `mvn verify`, falló:

```
[ERROR] SesionMateriaEstudianteSqlServerAdapterTest.consultarSesionesMateria_mapea_proyeccion_completa:53
  expected: <2026-01-20T08:00> but was: <2026-01-20T13:00>
```

**Causa raíz — idéntica a la ya dictaminada en `AUDIT.md` §3.2 para `SesionRepositorySqlServerAdapterTest`,
pero en un archivo distinto que ni `CONTRACT_FREEZE.md` §5.4 ni `AUDIT.md` §2.4 cubrieron:**
`SesionMateriaEstudianteSqlServerAdapterTest.java` l.44-45 construye
`Timestamp.valueOf(LocalDateTime.of(2026, 1, 20, 8, 0))` bajo la zona ambiental real de esta máquina
(`America/Bogota`, UTC-05:00, sin ningún `TimeZone.setDefault` explícito) y la aserción l.53 espera el
mismo `LocalDateTime` de vuelta — el mismo round-trip simétrico agnóstico de zona que `AUDIT.md` §3.2
identificó como "prueba nunca verificó semántica UTC, pasa por accidente si la máquina de build tiene
zona ambiental UTC". Con `toLocalDateTimeUtc` decodificando siempre como UTC fijo, el round-trip deja
de ser simétrico en esta máquina (offset de 5 horas, igual que el conflicto de §4).

`CONTRACT_FREEZE.md` §5.4 autorizó explícitamente la corrección de fixture **solo** para
`SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`. No
menciona `SesionMateriaEstudianteSqlServerAdapterTest` en ningún punto (confirmado por búsqueda en todo
`CONTRACT_FREEZE.md` y `AUDIT.md`: ambos citan ese archivo solo como "3er llamador confirmado exclusivo
de Sesion", nunca evalúan si su test tiene el mismo defecto de fixture). `ReporteAsistenciaSqlServerAdapterTest`
tiene el mismo patrón de construcción de `Timestamp` bajo zona ambiental (l.43-44), pero no falla porque
no asegura el valor de `fechaHoraInicio`/`fechaHoraFin` en ninguna aserción — mismo defecto latente, no
manifestado como fallo por ausencia de aserción, no reportado aquí como bloqueante pero dejado
registrado para que `02-contratos`/`03-tester-red` lo revisen junto con el punto siguiente.

**Acción tomada (conforme a la responsabilidad de este rol: "NO modifica tests RED ni contrato para
hacer pasar implementación. Si discrepa: TEST_CONTRACT_CONFLICT, detiene el cambio dependiente..."):**
no se tocó `SesionMateriaEstudianteSqlServerAdapterTest.java`. Se **revirtió** únicamente el cambio de
llamada en `SesionMateriaEstudianteSqlServerAdapter.java` (punto 4 de §7.1), dejándolo exactamente
AS-IS (`JdbcValueMapper.toLocalDateTime(...)`, sin `Utc`). Esto detiene el cambio dependiente
puntual sin revertir el resto de la implementación (los otros 2 llamadores sí quedan corregidos y
verificados GREEN) y sin modificar ningún test.

**Consecuencia real no resuelta:** `SesionMateriaEstudianteSqlServerAdapter` (consulta de sesiones de
materia para estudiante) **sigue leyendo `fechaHoraInicio`/`fechaHoraFin` con semántica dependiente de
`TimeZone.getDefault()` en el momento de la lectura**, no UTC fijo — el mismo defecto que este work item
buscaba corregir para los 3 llamadores confirmados, ahora corregido en 2 de 3. Requiere: (a)
`03-tester-red` corrija el fixture de `SesionMateriaEstudianteSqlServerAdapterTest` (mismo patrón ya
usado en `SesionRepositorySqlServerAdapterTest`, §5.4: `TimeZone.setDefault(UTC)` antes de construir el
`Timestamp`, restaurar en `finally`) con autorización de `02-contratos`; y opcionalmente revisar
`ReporteAsistenciaSqlServerAdapterTest` para que asegure el valor y no oculte el mismo defecto; (b)
`04-implementador` reaplica entonces el cambio de llamada en `SesionMateriaEstudianteSqlServerAdapter.java`
(revertir la reversión de esta sesión).

### 7.3 Resultado real del build (esta sesión)

```
.\mvnw.cmd -B -ntp verify
```

**BUILD SUCCESS.**

```
Tests run: 936, Failures: 0, Errors: 0, Skipped: 0
```

ArchUnit: 16 clases de test bajo `co.edu.uco.asistenciasuco.architecture.*` ejecutadas, 0 failures, 0
errors — PASS.

`jacoco:check`: ejecutado dentro de este `verify` (el reactor llegó a la fase, a diferencia de la
sesión de §4-6 donde Surefire detuvo el reactor antes). Sin `[ERROR] Rule violated` en la salida — PASS.
Totales calculados desde `target/site/jacoco/jacoco.csv` (mismo `target/jacoco.exec` de esta corrida):

```
LINE:   missed=4751, covered=28289 → 28289/33040 = 85.62%  (gate ≥80%: CUMPLE)
BRANCH: missed=583,  covered=1394  → 1394/1977  = 70.51%  (gate ≥70%: CUMPLE, margen ajustado,
                                                             consistente con lo ya advertido en
                                                             CONTRACT_FREEZE.md §9)
```

(Los totales absolutos de LINE difieren de los de §5 porque `jacoco.csv` reporta el agregado de todo el
proyecto por paquete/clase sumado aquí completo, no una proyección parcial — la sesión de §5 usó un
cálculo equivalente sobre el mismo `jacoco.exec`; el % es comparable y consistente.)

### 7.4 Resumen para 05-auditor (esta sesión)

| Ítem | Estado |
|---|---|
| `JdbcValueMapper.toLocalDateTimeUtc` nuevo | Implementado conforme a CONTRACT_FREEZE.md §5.1, `toLocalDateTime` intacto |
| `SesionRepositorySqlServerAdapter` (2 puntos) | Cambiado a `toLocalDateTimeUtc` — GREEN |
| `ReporteAsistenciaSqlServerAdapter` (1 punto) | Cambiado a `toLocalDateTimeUtc` — GREEN (test no asegura valor, defecto latente registrado en §7.2) |
| `SesionMateriaEstudianteSqlServerAdapter` (1 punto) | **NO cambiado — revertido a `toLocalDateTime` AS-IS** por `TEST_CONTRACT_CONFLICT` nuevo (§7.2), pendiente de corrección de fixture por `03-tester-red` |
| MAVEN VERIFY | **BUILD SUCCESS** — 936/936 GREEN |
| ARCHUNIT | PASS — 16 clases, 0 failures/errors |
| JACOCO | `jacoco:check` PASS real (ejecutado) — LINE 85.62% / BRANCH 70.51% |
| Ningún test modificado en esta sesión | Confirmado — solo se revirtió un cambio de producción propio de esta misma sesión |

**Recomendación para el flujo:** el punto N/M-20 queda **parcialmente resuelto**: 2 de 3 llamadores
confirmados ya decodifican `Sesion.fechaHoraInicio`/`fechaHoraFin` con semántica UTC fija; el tercero
(`SesionMateriaEstudianteSqlServerAdapter`) permanece con el defecto original hasta que
`02-contratos`/`03-tester-red` autoricen y apliquen la misma corrección de fixture ya usada en
`SesionRepositorySqlServerAdapterTest` (§5.4) sobre `SesionMateriaEstudianteSqlServerAdapterTest`. Este
work item **puede** avanzar con `mvn verify` en GREEN real, pero **no debe cerrarse como "UTC PERSISTENCE:
100% resuelto"** — el estado real es "2/3 llamadores corregidos, 1 pendiente por `TEST_CONTRACT_CONFLICT`
no resuelto, mismo patrón que §4".
