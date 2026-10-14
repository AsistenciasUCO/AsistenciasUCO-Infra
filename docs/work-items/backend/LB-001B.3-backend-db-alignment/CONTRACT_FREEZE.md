---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# CONTRACT_FREEZE — LB-001B.3: porciones congeladas del alineamiento backend↔DB

Fase `02-contratos`. Ningún archivo de `src/main/**`, `src/test/**`, SQL, `pom.xml` ni el repo frontend fue modificado en esta sesión. Este documento congela **solo** las porciones del `CONTRACT_MATRIX.md` que quedaron `MATCH`/`MISMATCH` con TARGET claro y sin `CONTRACT_CONFLICT`. La porción de mapeo de errores DB (`CONTRACT_MATRIX.md` filas M-19 y tabla "Códigos/enums") **NO se congela aquí** — queda `CONTRACT_CONFLICT`/`NOT_READY`, ver §6.

Referencia de formato: `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/CONTRACT_FREEZE.md` (trabajo hermano ya cerrado sobre el mismo dominio Sesion). Este documento no repite ese contenido; construye sobre él.

## 1. `idDocente` — retiro como parámetro SP en `usp_crear_sesion` (M-01)

**Alcance del cambio: exclusivamente `SesionRepositorySqlServerAdapter.java`.** No se toca `CrearSesionDTO`, `CrearSesionRepositoryDTO`, `CrearSesionDomain`, `CrearSesionMapper`, `CrearSesionRepositoryMapper` ni `CrearSesionUseCaseImpl` — el campo `docente`/`getDocente()` de esas clases **no es un ghost param HTTP** (no existe en `CrearSesionRequest`, confirmado en `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/CONTRACT_FREEZE.md` §3.1: los únicos campos de `CrearSesionRequest` son `grupo`, `tema`/`nombre`, `fechaHoraInicio`, `fechaHoraFin`); `SesionHttpMapper` siempre lo llena con `usuarioEjecutor`, y `CrearSesionUseCaseImpl.execute()` lo resuelve server-side a `Docente.id` real vía `InstitutionalScopePort.findDocenteIdByUsuario(...)` **antes** de invocar el repositorio (l.32-38). Esa resolución es un pre-check de autorización en Application (falla con `ForbiddenException` si el usuario no resuelve a un Docente), independiente de lo que se envíe al SP.

Evidencia exacta (`SesionRepositorySqlServerAdapter.java`):

```java
// ANTES (l.42-51)
static final String SQL_CREAR_SESION = """
        EXEC dbo.usp_crear_sesion
             @idGrupo = :idGrupo,
             @idDocente = :idDocente,
             @nombre = :nombre,
             @fechaHoraInicio = :fechaHoraInicio,
             @fechaHoraFin = :fechaHoraFin,
             @idCorrelacion = :idCorrelacion,
             @idUsuarioEjecutor = :idUsuarioEjecutor
        """;

// DESPUES
static final String SQL_CREAR_SESION = """
        EXEC dbo.usp_crear_sesion
             @idGrupo = :idGrupo,
             @nombre = :nombre,
             @fechaHoraInicio = :fechaHoraInicio,
             @fechaHoraFin = :fechaHoraFin,
             @idCorrelacion = :idCorrelacion,
             @idUsuarioEjecutor = :idUsuarioEjecutor
        """;
```

```java
// ANTES (l.129-140), método crearSesion(CrearSesionRepositoryDTO dto)
procedureExecutor.execute(
        "crearSesion",
        SQL_CREAR_SESION,
        new MapSqlParameterSource()
                .addValue(PARAM_ID_GRUPO, dto.getGrupo())
                .addValue(PARAM_ID_DOCENTE, dto.getDocente())   // ← retirar esta línea
                .addValue(PARAM_NOMBRE, dto.getTema())
                .addValue(PARAM_FECHA_HORA_INICIO, dto.getFechaHoraInicio())
                .addValue(PARAM_FECHA_HORA_FIN, dto.getFechaHoraFin())
                .addValue(PARAM_ID_CORRELACION, CorrelationIdContext.require())
                .addValue(PARAM_ID_USUARIO_EJECUTOR, dto.getUsuarioEjecutor())
);
```

`dto.getDocente()` deja de leerse en `crearSesion(...)`; el DTO conserva el campo/getter sin cambio (sigue usándose únicamente como valor de entrada al pre-check de `InstitutionalScopePort` en la capa `usecase`, no como parámetro JDBC).

## 2. `idDocente` — retiro como parámetro SP en `usp_actualizar_sesion` (M-02)

Mismo patrón que §1, exclusivamente en `SesionRepositorySqlServerAdapter.java`:

```java
// ANTES (l.61-70)
static final String SQL_ACTUALIZAR_SESION = """
        EXEC dbo.usp_actualizar_sesion
             @idSesion = :idSesion,
             @nombre = :nombre,
             @fechaHoraInicio = :fechaHoraInicio,
             @fechaHoraFin = :fechaHoraFin,
             @idDocente = :idDocente,
             @idCorrelacion = :idCorrelacion,
             @idUsuarioEjecutor = :idUsuarioEjecutor
        """;

// DESPUES
static final String SQL_ACTUALIZAR_SESION = """
        EXEC dbo.usp_actualizar_sesion
             @idSesion = :idSesion,
             @nombre = :nombre,
             @fechaHoraInicio = :fechaHoraInicio,
             @fechaHoraFin = :fechaHoraFin,
             @idCorrelacion = :idCorrelacion,
             @idUsuarioEjecutor = :idUsuarioEjecutor
        """;
```

```java
// ANTES (l.144-161), método actualizarSesion(ActualizarSesionRepositoryDTO dto)
procedureExecutor.execute(
        "actualizarSesion",
        SQL_ACTUALIZAR_SESION,
        new MapSqlParameterSource()
                .addValue(PARAM_ID_SESION, dto.sesion())
                .addValue(PARAM_NOMBRE, dto.nombre())
                .addValue(PARAM_FECHA_HORA_INICIO, dto.fechaHoraInicio())
                .addValue(PARAM_FECHA_HORA_FIN, dto.fechaHoraFin())
                .addValue(PARAM_ID_DOCENTE, dto.docente())      // ← retirar esta línea
                .addValue(PARAM_ID_CORRELACION, CorrelationIdContext.require())
                .addValue(PARAM_ID_USUARIO_EJECUTOR, dto.usuarioEjecutor())
);
```

No se toca `ActualizarSesionDTO`, `ActualizarSesionRepositoryDTO` (record), `ActualizarSesionDomain`, `ActualizarSesionMapper`, `ActualizarSesionRepositoryMapper` ni `ActualizarSesionUseCaseImpl` — mismo razonamiento que §1 (`dto.docente()` sigue existiendo como valor resuelto por `InstitutionalScopePort`, solo deja de viajar al SP).

**Nota — decisión NO tomada aquí (fuera de este freeze):** si el pre-check `institutionalScopePort.findDocenteIdByUsuario(...)` en `CrearSesionUseCaseImpl`/`ActualizarSesionUseCaseImpl` debe conservarse como defensa en profundidad (falla rápido con `ForbiddenException` antes de tocar DB) o si debe retirarse porque la DB ya resuelve `Usuario.id -> Docente.id -> Grupo/Sesion` internamente (`DB_BASELINE_CONTRACT.md` §Sesion, regla de titularidad) es una decisión de diseño de autorización, no una limpieza mecánica de ghost param. **`DECISION_REQUIRED`, no resuelta en esta sesión** — mantenerlo tal como está no viola ningún `MUST` explícito de `TASK_AUTORIZADA.md` (no se envía a DB, no se usa como "identidad secundaria del caller" frente al SP — solo como pre-check interno), así que el TARGET mínimo de esta fase es dejarlo intacto.

## 3. `usp_cerrar_sesion` — `idDocente` NO se retira en esta fase (M-03)

`SQL_CERRAR_SESION` también envía `@idDocente`, pero `usp_cerrar_sesion` es `OUT_OF_TARGET`/`LEGACY_NOT_SUPPORTED` (ver `CONTRACT_MATRIX.md` M-03): el contrato DB congelado NO documenta su firma de parámetros, solo su comportamiento (`SES_003`, sin escrituras). No hay evidencia suficiente para decidir si `@idDocente` ahí es un ghost param real o si el SP legacy todavía lo requiere. **No se congela ningún cambio para `cerrarSesion(...)`/`SQL_CERRAR_SESION` en este documento.** Permanece AS-IS.

## 4. `aula` — retiro de la proyección `uv_horario_docente` (M-05)

**Alcance: pipeline completo `adapter → projection → domain → DTO → HTTP`**, porque `HorarioDocenteDTO` (aplicación) es la forma de respuesta HTTP directa de `GET /api/v1/docente/horarios` (`DocentePortalController.consultarHorarios()` retorna `ApiListResponse<HorarioDocenteDTO>` — sin wrapper HTTP intermedio, confirmado en `DocentePortalController.java` l.65). Retirar `aula` es `CONTRACT_CHANGE` real de la respuesta HTTP de ese endpoint del Golden Path, no solo una limpieza interna.

| Archivo | AS-IS | DESPUÉS |
|---|---|---|
| `infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapter.java` (l.23-40) | `SELECT id, idDocente, idGrupo, codigoMateria, nombreMateria, seccion, dia, horaInicio, horaFin, aula, totalEstudiantes FROM dbo.uv_horario_docente` + construcción de `HorarioDocenteProjection` con `JdbcValueMapper.toString(rs.getObject("aula"))` | Retirar `aula` del `SELECT` y del constructor de `HorarioDocenteProjection` (9 argumentos → 8, mismo orden relativo) |
| `application/secondaryports/academic/projection/HorarioDocenteProjection.java` (record, 11 componentes) | `record HorarioDocenteProjection(UUID id, UUID idDocente, UUID idGrupo, String codigoMateria, String nombreMateria, String seccion, String dia, LocalTime horaInicio, LocalTime horaFin, String aula, Integer totalEstudiantes)` | Retirar componente `aula` (11 → 10 componentes) |
| `application/features/docente/consultarhorarios/usecase/domain/HorarioDocenteDomain.java` (record, 11 componentes) | Idéntica forma que la projection | Retirar `aula` (11 → 10 componentes) |
| `application/features/docente/consultarhorarios/primaryports/dto/HorarioDocenteDTO.java` (record, 11 componentes) | Idéntica forma — **es la respuesta HTTP** | Retirar `aula` (11 → 10 componentes) — cambia el JSON de `GET /api/v1/docente/horarios` |
| `application/features/docente/consultarhorarios/usecase/mapper/ConsultarHorariosDocenteRepositoryMapper.java` | Construye `HorarioDocenteDomain` desde `HorarioDocenteProjection`, 11 argumentos posicionales | Ajustar a 10 argumentos, mismo orden relativo |
| `application/features/docente/consultarhorarios/primaryports/mapper/ConsultarHorariosDocenteMapper.java` | Construye `HorarioDocenteDTO` desde `HorarioDocenteDomain`, 11 argumentos posicionales | Ajustar a 10 argumentos |

No se toca `HorarioEstudianteSqlServerAdapter.java`/`HorarioEstudianteProjection.java`/`HorarioEstudianteDomain.java`/`HorarioEstudianteDTO.java` (M-06, `NOT_APPLICABLE`/`OUT_OF_TARGET` — fuera de este freeze, ver `CONTRACT_MATRIX.md`).

**Consumidor HTTP:** no se verificó el repo frontend en esta sesión (prohibido por `TASK_AUTORIZADA.md`). Si el frontend real consume `aula` de `GET /api/v1/docente/horarios` hoy, este cambio es `BREAKING` para ese consumidor — mismo patrón de riesgo que `LB-001B.1`/`LB-001B.1B` (secuenciar despliegue backend↔frontend). Se registra como riesgo, no se resuelve aquí (fuera de alcance abrir el frontend).

## 5. Temporal — decisión UTC para `Sesion.fechaHoraInicio`/`fechaHoraFin` (M-20) — TARGET REVISADO

> **Revisión de contrato, no la versión original.** La redacción original de esta sección (congelada
> antes de que `04-implementador` intentara implementarla) asumía "solo Javadoc, sin cambio de
> comportamiento". Esa asunción quedó **objetivamente refutada** por evidencia empírica
> (`VALIDATION.md` §4: `TEST_CONTRACT_CONFLICT`, punto N) y el conflicto fue dictaminado por
> `05-auditor` como real y de alcance más amplio de lo reportado (`AUDIT.md` §3.1-3.2, íntegro). Esta
> sección reemplaza la anterior conforme al dictamen del auditor, siguiendo el flujo previsto en
> `AGENTS.md` §4 (un test revela que el contrato congelado era insuficiente → vuelve a
> `02-contratos`/`03-tester-red` con dictamen del auditor). Nada de §1-4 ni §6-9 de este documento se
> reabre por esta revisión.

### 5.0 Decisión

Se adopta la **Opción A** recomendada por `AUDIT.md` §4 ("decodificación dedicada para Sesion, alcance
mínimo"): un método de decodificación **distinto** del helper genérico
`JdbcValueMapper.toLocalDateTime(Object)`, usado exclusivamente por los 3 llamadores ya confirmados
exclusivos de `Sesion.fechaHoraInicio`/`fechaHoraFin` (`AUDIT.md` §2.4).

Se **rechaza explícitamente la Opción B** (`user.timezone=UTC` global a nivel de build/runtime): blast
radius no scoped a Sesion — afectaría potencialmente logging, serialización JSON de fechas sin zona
explícita, expiración de tokens, jobs programados y auditoría en todo el backend (`AUDIT.md` §4,
Opción B), sin auditoría de esos puntos disponible en este work item, y contradice
`TASK_AUTORIZADA.md` §21 ("no hacer migración indiscriminada de toda la aplicación") de forma más
directa que la Opción A.

### 5.1 Ubicación del método dedicado: `JdbcValueMapper.toLocalDateTimeUtc(Object)`

**Decisión de ubicación:** vive en `JdbcValueMapper.java` (mismo archivo que el helper genérico), como
método público estático nuevo y separado — **no** como método privado del adapter. Justificación: el
comportamiento UTC-fijo lo necesitan **3 clases en 3 paquetes distintos**
(`infrastructure...sqlserver.core.SesionRepositorySqlServerAdapter`,
`infrastructure...sqlserver.reporting.ReporteAsistenciaSqlServerAdapter`,
`infrastructure...sqlserver.academic.SesionMateriaEstudianteSqlServerAdapter`, confirmadas exclusivas
por `AUDIT.md` §2.4). Un método privado estático en un solo adapter obligaría a duplicar la misma
lógica 3 veces o a exponerlo como `package-private`/`public` fuera de su paquete natural, violando
encapsulamiento sin necesidad. `JdbcValueMapper` ya es el punto de conversión JDBC compartido de estas
3 clases (todas lo importan hoy) — añadir el método ahí no cruza ninguna capa nueva y es coherente con
`uco-arquitectura` (helper de infraestructura, sin lógica de dominio).

**Archivo:** `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/JdbcValueMapper.java`

```java
// Nuevo import (no existe hoy en el archivo)
import java.time.ZoneOffset;

// Nuevo método, ubicado inmediatamente despues de toLocalDateTime(Object) (l.100-111 AS-IS);
// toLocalDateTime(Object) NO se modifica (ver 5.3).
/**
 * Convierte un valor JDBC a {@link LocalDateTime} interpretando siempre el instante como UTC,
 * ignorando el {@code TimeZone.getDefault()}/{@code user.timezone} vigente en el momento de la
 * lectura. Uso exclusivo de {@code Sesion.fechaHoraInicio}/{@code fechaHoraFin}
 * ({@code DATETIME2} UTC target, DB_BASELINE_CONTRACT.md secc. Temporal) desde sus 3 llamadores
 * confirmados: {@code SesionRepositorySqlServerAdapter}, {@code ReporteAsistenciaSqlServerAdapter},
 * {@code SesionMateriaEstudianteSqlServerAdapter}. No usar para ningun otro campo temporal
 * (p. ej. {@code Horario.horaInicio/horaFin}, que es hora academica LOCAL, no UTC).
 */
public static LocalDateTime toLocalDateTimeUtc(final Object value) {
    if (value == null) {
        return null;
    }
    if (value instanceof LocalDateTime localDateTime) {
        return localDateTime;
    }
    if (value instanceof java.sql.Timestamp timestamp) {
        return timestamp.toInstant().atZone(ZoneOffset.UTC).toLocalDateTime();
    }
    return LocalDateTime.parse(String.valueOf(value));
}
```

Firma: `public static LocalDateTime toLocalDateTimeUtc(final Object value)`. Mismo contrato de entrada
(`null`/`LocalDateTime`/`java.sql.Timestamp`/`String` parseable) que `toLocalDateTime(Object)`, difiere
únicamente en la rama `Timestamp`: usa `timestamp.toInstant().atZone(ZoneOffset.UTC).toLocalDateTime()`
en vez de `timestamp.toLocalDateTime()`.

### 5.2 Puntos de uso — reemplazar la llamada, no el helper genérico

Los 3 llamadores cambian su invocación de `JdbcValueMapper.toLocalDateTime(...)` a
`JdbcValueMapper.toLocalDateTimeUtc(...)` **únicamente** para `fechaHoraInicio`/`fechaHoraFin`. Ninguna
otra línea de estos 3 archivos cambia.

| Archivo | Líneas AS-IS (verificadas) | Cambio |
|---|---|---|
| `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` | l.179-180 (`consultarSesion`) y l.209-210 (`consultarSesionesPorGrupo`): `JdbcValueMapper.toLocalDateTime(rs.getObject("fechaHoraInicio"))` / `"fechaHoraFin"` | Reemplazar por `JdbcValueMapper.toLocalDateTimeUtc(rs.getObject("fechaHoraInicio"))` / `"fechaHoraFin"` en ambos métodos (4 ocurrencias en total). Import de `JdbcValueMapper` ya existe (l.13), sin cambio. |
| `infrastructure/adapter/secondary/persistence/sqlserver/reporting/ReporteAsistenciaSqlServerAdapter.java` | l.69-70: `JdbcValueMapper.toLocalDateTime(rs.getObject("fechaHoraInicio"))` / `"fechaHoraFin"` | Reemplazar por `JdbcValueMapper.toLocalDateTimeUtc(...)` en ambas líneas. |
| `infrastructure/adapter/secondary/persistence/sqlserver/academic/SesionMateriaEstudianteSqlServerAdapter.java` | l.43-44: `JdbcValueMapper.toLocalDateTime(rs.getObject("fechaHoraInicio"))` / `"fechaHoraFin"` | Reemplazar por `JdbcValueMapper.toLocalDateTimeUtc(...)` en ambas líneas. |

No se toca el `SELECT`/SQL de ninguno de los 3 archivos (siguen leyendo `fechaHoraInicio`/`fechaHoraFin`
vía `rs.getObject(...)`, no `rs.getTimestamp(col, Calendar)` — `AUDIT.md` §2.3(a) descarta esa vía como
alternativa real, no como cambio adicional necesario).

**Riesgo no verificable desde este repo (heredado de `AUDIT.md` §4, Opción A, sin resolver aquí):**
el comportamiento exacto de `mssql-jdbc` al leer `DATETIME2` sin zona vía `rs.getObject(...)` (si el
epoch-millis del `Timestamp` devuelto ya asume alguna zona del driver/conexión) no está verificado con
una IT real contra la instancia SQL Server congelada. Los tests unitarios de este punto (con
`ResultSet` mockeado) validan la función de decodificación en Java, no el comportamiento del driver —
esa verificación queda pendiente de `SqlStoredProcedureContractIT`/equivalente conforme
`TASK_AUTORIZADA.md` §30, fuera del alcance de este freeze.

### 5.3 Qué NO cambia: helper genérico y su test

`JdbcValueMapper.toLocalDateTime(Object)` (l.100-111 AS-IS) **permanece exactamente igual, sin tocar
una sola línea de código ejecutable** — sigue usando `timestamp.toLocalDateTime()` (decodificación
dependiente de `TimeZone.getDefault()` en el momento de la lectura), para cualquier caller futuro
sin semántica UTC explícita. Su Javadoc actual (agregado por `04-implementador`, documentando el
`TEST_CONTRACT_CONFLICT` ya resuelto por esta sección) puede simplificarse o eliminarse por
`04-implementador` al aplicar este TARGET, pero no es obligatorio — no afecta comportamiento.

`JdbcValueMapperTest.toLocalDateTime_con_timestamp_lo_convierte` (l.124-128 AS-IS) **queda intacto, sin
ninguna modificación** — sigue ejercitando `JdbcValueMapper.toLocalDateTime(Object)` (el helper
genérico, no el nuevo `toLocalDateTimeUtc`), cero intersección con el cambio de esta sección.

`JdbcValueMapperTest.toLocalDateTime_no_depende_del_systemDefault_de_la_jvm_para_datetime2_utc_de_sesion`
(l.163-182 AS-IS, el test N ya creado por `03-tester-red`) debe re-apuntarse a ejercitar
`JdbcValueMapper.toLocalDateTimeUtc(Object)` en vez de `JdbcValueMapper.toLocalDateTime(Object)` (única
línea a cambiar: l.172, la llamada al método bajo prueba). Con ese único cambio pasa a GREEN de forma
directa: el nuevo método ignora por diseño el `TimeZone.getDefault()` vigente en la lectura. Esto
también es responsabilidad de `03-tester-red`, no de `04-implementador` motu proprio (mismo archivo
`JdbcValueMapperTest.java` del `RED_SNAPSHOT.md`).

### 5.4 Fixture a corregir: `SesionRepositorySqlServerAdapterTest.queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`

**Este test SÍ requiere modificación puntual de su fixture** — es una revisión de contrato autorizada
por el dictamen de `05-auditor` (`AUDIT.md` §3.1, §4 Opción A), **no** "modificar un test para forzar
GREEN sin justificación". Distinción explícita para que `03-tester-red` la ejecute sin ambigüedad:

- **Qué NO cambia (por qué no es "forzar GREEN"):** la intención del test — verificar que
  `consultarSesion(...)` mapea `fechaHoraInicio`/`fechaHoraFin` de `uv_sesion` correctamente vía
  `SesionRepositoryProjection` — se preserva exactamente. Ninguna aserción cambia:
  `assertEquals(start, result.getFechaHoraInicio())` (l.185) sigue comparando el mismo valor de
  dominio esperado contra el mismo campo resultado. El `SELECT`, el mock de `jdbc.query(...)`, y todas
  las demás columnas mockeadas (l.164-177) no cambian.
- **Qué SÍ cambia y por qué es una revisión de contrato legítima:** el fixture construye hoy
  `Timestamp.valueOf(start)` / `Timestamp.valueOf(start.plusHours(1))` (l.173-174) bajo la zona
  ambiental real de la máquina de build (no controlada, ej. `America/Bogota`), lo cual — según
  `AUDIT.md` §2.2/§3.2 — nunca verificó semántica UTC: es un round-trip simétrico agnóstico de zona
  que "pasaba por accidente" porque construcción y lectura ocurrían bajo la misma zona ambiental. Con
  la producción ahora decodificando siempre como UTC fijo (`toLocalDateTimeUtc`, §5.1), el fixture debe
  construir esos dos `Timestamp` bajo `TimeZone.getDefault() = UTC` explícito para que el round-trip sea
  correcto y el test siga verificando lo que dice verificar (mapeo correcto de columnas), en vez de
  seguir dependiendo — sin saberlo — de que la máquina de build tenga zona ambiental UTC.
- **Mecanismo exacto exigido (mismo patrón ya usado en `JdbcValueMapperTest`, l.135-143 y l.164-182,
  para no introducir un patrón nuevo):** antes de construir `Timestamp.valueOf(start)` /
  `Timestamp.valueOf(start.plusHours(1))` (l.173-174), capturar `TimeZone.getDefault()` en una
  variable, fijar `TimeZone.setDefault(TimeZone.getTimeZone("UTC"))`, construir ambos `Timestamp`, y
  restaurar el `TimeZone` original capturado en un bloque `finally` (o equivalente `@AfterEach`) antes
  de que el test termine — para no dejar el `TimeZone.default` de la JVM alterado para el resto de la
  suite. No hace falta fijar ningún `TimeZone` durante la llamada a `adapter.consultarSesion(...)` en
  sí: `toLocalDateTimeUtc` no depende del `TimeZone.getDefault()` vigente en el momento de la lectura
  (por diseño, §5.1), solo importa la zona activa en el momento de **construir** el `Timestamp` del
  fixture.
- **Alcance del cambio:** únicamente las líneas 173-174 de
  `SesionRepositorySqlServerAdapterTest.java` (construcción del fixture) más el andamiaje mínimo de
  captura/restauración de `TimeZone` alrededor de ellas. Ninguna otra línea del archivo (incluidas
  `createPassesConfirmedProcedureAndParameters` y `updateCloseAndGeneratePassThePublicProcedures`,
  l.67-157) se toca.

### 5.5 No se toca en esta revisión

Sin cambio respecto a la versión anterior de esta sección: no se cambia tipo Java ni wire format HTTP.
`HttpTemporalParser.parseLocalDateTime(String, String)` y el wire format de
`CrearSesionRequest`/`ActualizarSesionRequest` (`String` ISO local sin offset) permanecen intactos. No
hay impacto en `Horario.horaInicio/horaFin` (`LocalTime`, hora académica local, sin relación con este
punto — `toLocalDateTimeUtc` no se usa ni se debe usar ahí).

**HTTP (representación temporal para OpenAPI):** sin cambio — sigue `READY_FOR_OPENAPI_DECISION`
conforme a `TASK_AUTORIZADA.md` §22. AS-IS exacto para LB-001C: `fechaHoraInicio`/`fechaHoraFin` viajan
como `String` ISO local sin offset (`"yyyy-MM-dd'T'HH:mm[:ss]"`), parseados a `LocalDateTime`. La
decisión de si LB-001C debe migrar a `Instant`/`OffsetDateTime` con `Z`/offset explícito en el wire
format queda pendiente de esa fase, no de esta.

### 5.6 Nota de coherencia con §7 (no se edita §7 en esta revisión)

`§7 "Lista exacta de archivos para 04-implementador"`, punto 8, y la lista de tests de `§7`, describen
todavía el alcance de la versión **anterior** de esta sección ("solo Javadoc"). Para el punto N/M-20
específicamente, ese punto 8 y esa lista de tests quedan **ampliados** por lo que especifica este §5
revisado: autorizan además `infrastructure...sqlserver.support.mapping/JdbcValueMapper.java` (nuevo
método `toLocalDateTimeUtc`, §5.1), `infrastructure...sqlserver.reporting/ReporteAsistenciaSqlServerAdapter.java`
y `infrastructure...sqlserver.academic/SesionMateriaEstudianteSqlServerAdapter.java` (cambio de llamada,
§5.2) como producción; y `JdbcValueMapperTest.java` (re-apuntar el test N, §5.3) y
`SesionRepositorySqlServerAdapterTest.java` (fixture de `queryMapsConfirmedViewColumnsAndReturnsNullWhenAbsent`,
§5.4) como tests a ajustar por `03-tester-red`. El resto de §6-9 y del resto de §7 (Bloqueo 1 y todo lo
no relacionado con el punto N) no se reabre ni se modifica por esta revisión.

## 6. Bloqueo 1 — mapeo de errores DB: explícitamente NO congelado

Conforme a `CONTRACT_MATRIX.md` (fila M-19, tabla "Códigos/enums", sección "Bloqueos" ítem 1): el mapeo determinista `DB semantic → backend ErrorDefinition → HTTP status → ApiErrorResponse.code` para `SEC_001, SEC_002, ATT_001, ATT_002, ATT_003, SES_003, SES_004, RC_001, GEN_002, EST_004` (y la validez contractual de `SES_001` como caso ya "funcionando") es **`CONTRACT_CONFLICT`**, no `CONTRACT_FREEZE`. Ningún archivo relacionado con `DbFailureClassifier.java`/`DbExceptionTranslator.java` tiene TARGET congelado en este documento.

**Consecuencia explícita para 03-tester-red:** `NOT_READY` para derivar RED de los puntos **I** (`SEC_001 → 403/FORBIDDEN`), **J** (`SEC_002 → 403/FORBIDDEN`), **K** (`SES_001 → not found apropiado` — el comportamiento actual funciona mas no está congelado por contrato, por lo que un RED que lo fije como contractual sería prematuro) y **M** (`ATT errors clasificación correcta`) de `TASK_AUTORIZADA.md` §27, hasta que exista una decisión humana sobre Bloqueo 1 (ver `CONTRACT_MATRIX.md` §"Decisiones requeridas", fila M-19). Los puntos **A, B, C, D, E, F, G, H, N, P** (firma crear/actualizar sin `idDocente`, mapper `uv_sesion`, mapper horario sin `aula`, batch `AN/SJC/EX`, unknown fail-closed, ausencia de fila, `idUsuarioEjecutor` obligatorio, temporal sin `systemDefault`, correlación) **sí** pueden derivarse ya, con base en §1-5 de este documento y las filas `MATCH` de `CONTRACT_MATRIX.md`. El punto **O** (realtime UTC) requiere el test nuevo de M-22 (`CONTRACT_MATRIX.md`), no bloqueado pero tampoco existente hoy.

## 7. Lista exacta de archivos para 04-implementador (alcance de este freeze únicamente)

**Producción (`src/main/java`) — únicamente estas rutas quedan autorizadas por este freeze:**

1. `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` — `SQL_CREAR_SESION` (retirar `@idDocente`), `crearSesion(...)` (retirar `.addValue(PARAM_ID_DOCENTE, dto.getDocente())`), `SQL_ACTUALIZAR_SESION` (retirar `@idDocente`), `actualizarSesion(...)` (retirar `.addValue(PARAM_ID_DOCENTE, dto.docente())`). **No tocar** `SQL_CERRAR_SESION`/`cerrarSesion(...)` (§3), ni `SQL_CONSULTAR_*`/`consultarSesion*` (ya `MATCH`).
2. `infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapter.java` — retirar `aula` del `SELECT` y del constructor de `HorarioDocenteProjection`.
3. `application/secondaryports/academic/projection/HorarioDocenteProjection.java` — retirar componente `aula`.
4. `application/features/docente/consultarhorarios/usecase/domain/HorarioDocenteDomain.java` — retirar componente `aula`.
5. `application/features/docente/consultarhorarios/primaryports/dto/HorarioDocenteDTO.java` — retirar componente `aula`.
6. `application/features/docente/consultarhorarios/usecase/mapper/ConsultarHorariosDocenteRepositoryMapper.java` — ajustar construcción de `HorarioDocenteDomain` (11→10 args).
7. `application/features/docente/consultarhorarios/primaryports/mapper/ConsultarHorariosDocenteMapper.java` — ajustar construcción de `HorarioDocenteDTO` (11→10 args).
8. (Documentación, no código productivo con lógica) Javadoc de `JdbcValueMapper.toLocalDateTime` o punto de uso equivalente en la cadena de Sesion — decisión de ubicación exacta la toma 04-implementador siguiendo §5.

**No incluidos en este freeze (fuera de alcance, tocar solo con nueva decisión):** cualquier archivo de `DbFailureClassifier.java`/`DbExceptionTranslator.java` (Bloqueo 1), `HorarioEstudianteSqlServerAdapter.java` y su cadena (M-06), `GrupoRepositorySqlServerAdapter.java` en la porción `SQL_CONSULTAR_ESTUDIANTES_GRUPO` (M-08, `BLOCKED_BY_MISSING_EVIDENCE`), `SQL_CERRAR_SESION`/`cerrarSesion(...)` (§3), `CrearSesionDTO`/`CrearSesionRepositoryDTO`/`CrearSesionDomain`/`ActualizarSesionDTO`/`ActualizarSesionRepositoryDTO`/`ActualizarSesionDomain` y sus casos de uso (el campo `docente` se mantiene sin cambio, ver §1-2).

**Tests (`src/test/java`) — a crear/ajustar por 03-tester-red, no reescribir para forzar GREEN:**
- `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapterTest.java` — asertar que `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION` y los `MapSqlParameterSource` resultantes NO contienen `idDocente`.
- `infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapterTest.java` (si existe; si no, crear) — asertar `SELECT` sin `aula` y `HorarioDocenteProjection` de 10 campos.
- Tests unitarios de `ConsultarHorariosDocenteRepositoryMapperTest`/`ConsultarHorariosDocenteMapperTest` — ajustar a los records de 10 componentes.
- Nuevo test de estabilidad temporal (§5, punto 2) — ubicación sugerida junto a `JdbcValueMapper`/`SesionRepositorySqlServerAdapterTest`, a decidir por 03-tester-red.
- **NO crear** RED para los puntos I/J/K/M de `TASK_AUTORIZADA.md` §27 (Bloqueo 1, §6 de este documento).

## 8. Stop conditions evaluadas en esta fase

- **`CONTRACT_CONFLICT` declarado:** mapeo determinista de errores DB (§6). No resuelto en esta sesión; requiere decisión humana.
- **`BLOCKED_BY_MISSING_EVIDENCE` puntual:** firma exacta de `usp_cerrar_sesion` (§3) y shape de `uv_estudiante_identidad`/`uv_usuario` (`CONTRACT_MATRIX.md` M-08). Ninguno bloquea las porciones congeladas de §1-5.
- **`NOT_APPLICABLE`/`OUT_OF_TARGET` declarado:** `uv_horario_estudiante` (M-06) y el endpoint `POST /api/v1/sesiones/cierres`/`usp_cerrar_sesion` para el contrato objetivo de LB-001C (M-03) — ninguno se toca ni se incluye en `BACKEND_GOLDEN_PATH_CONTRACT.md` como parte activa del Golden Path.

## 9. Validación pendiente (no ejecutada en esta fase)

Sin cambios de código en esta sesión (`CONTRACT_ANALYSIS` puro), no aplica ejecutar `mvnw verify` aquí. Referencia para 04-implementador/05-auditor: `.\mvnw.cmd verify` (Windows), gates JaCoCo `LINE ≥80% / BRANCH ≥70%` del `pom.xml`, ArchUnit `PASS`, conforme a `AGENTS.md` §"Validación mínima". El margen de cobertura `BRANCH` ya es ajustado (heredado de `LB-001B.1`, ~70,53%) — vigilar activamente al retirar las 2 líneas de `SesionRepositorySqlServerAdapter.java` y el componente `aula` de los 3 records de horario docente (riesgo ya registrado en `PLAN.md`, riesgo 5).
