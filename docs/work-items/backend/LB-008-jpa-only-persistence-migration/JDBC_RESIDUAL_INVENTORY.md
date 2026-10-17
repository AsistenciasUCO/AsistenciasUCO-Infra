# JDBC RESIDUAL INVENTORY — LB-008

## Snapshot vigente (2026-10-06, tras JPA-07 limpieza de soporte)

- `CURRENT_DIRECT_JDBC_GLOBAL = 0` archivos reales en `src/main/java`. Búsqueda por `JdbcTemplate`,
  `NamedParameterJdbc*`, `RowMapper`, `ResultSet`, `java.sql`, `CanonicalStoredProcedureExecutor`, `JdbcValueMapper`,
  `CanonicalProcedureResultMapper` y `SqlServerProcedureSupportConfiguration`: 0 coincidencias en `src/main`.
- `CURRENT_AFTER = JPA-07 FINAL JDBC ERADICATION`. Auditoría JPA-06B (OPCIÓN A, TD-010 RESOLVED) y catálogos JPA-06 cerrados.
- Retirados en JPA-07 (de `src/main` a `src/test`, solo como oráculo de baseline):
  - `#36` `CanonicalStoredProcedureExecutor` → `src/test/.../support/procedure/CanonicalJdbcBaselineExecutor`
    (sin consumidores productivos; ver `PRODUCTIVE_CONSUMERS = 0`).
  - `#35` `CanonicalProcedureResultMapper` → `CanonicalJdbcBaselineResultMapper` (solo test).
  - `JdbcValueMapper` → `JdbcBaselineValueMapper` (solo test; oráculos baseline y `SqlServerTestDiagnostics`).
  - `#42` `SqlServerProcedureSupportConfiguration` eliminado; su bean de test vive en `JdbcBaselineTestConfiguration`
    importado solo por los ITs de paridad que lo necesitan.
- Producción de SP: `ProcedureResult`, `CanonicalProcedureResult`, `ProcedureResultMapper`, `ProcedureResultValidator`
  (desde `EntityManager`). Sin ejecutor JDBC ni fallback.
- Javadocs de mappers JPA reescritas sin nombrar clases JDBC retiradas.

## Snapshot previo (HISTORICAL SNAPSHOT, 2026-10-05, tras JPA-06 catálogos)

Sustituido por el snapshot de JPA-07 arriba. Se conserva para trazabilidad.

- `CURRENT_DIRECT_JDBC_GLOBAL = 6` archivos reales en `src/main/java` (7 coincidencias brutas;
  falso positivo Javadoc `UvDetalleAsistenciaEntity` descontado).
- `CURRENT_AFTER = JPA-06 CATALOGS` (auditoría `BLOCKED_BY_TD010_DECISION`, sin cambios de código).
- Residual vigente: auditoría (#4, #5; TD-010) y soporte de procedimientos (#6–#9, JPA-07). Detalle en la sección
  "Actualización JPA-06".
- `JDBC_VALUE_MAPPER_PRODUCTIVE_CONSUMERS = 1` (solo `CanonicalProcedureResultMapper`; los consumidores de
  `AcademicViewJpaProjectionMapper` son comentarios Javadoc).
- `CANONICAL_EXECUTOR_PRODUCTIVE_CONSUMERS = 0`.
- `StoredProcedureQuery` / `ParameterMode` en `src/main` = 0.

### Snapshot previo (histórico, tras JPA-05): `CURRENT_DIRECT_JDBC_GLOBAL = 9`, `CURRENT_AFTER = JPA-05`

HISTORICAL SNAPSHOT. Sustituido por el snapshot de JPA-06 arriba. Se conserva para trazabilidad.

- `CURRENT_DIRECT_JDBC_GLOBAL = 9` archivos reales (10 coincidencias brutas; falso positivo descontado).
- `CURRENT_AFTER = JPA-05`.

### Snapshot previo (histórico, tras JPA-04): `CURRENT_DIRECT_JDBC_GLOBAL = 29`, `CURRENT_AFTER = JPA-04`

HISTORICAL SNAPSHOT.

- `CURRENT_DIRECT_JDBC_GLOBAL = 29` archivos reales en `src/main/java` (30 coincidencias brutas;
  falso positivo `UvDetalleAsistenciaEntity` descontado).
- `CURRENT_AFTER = JPA-04`.
- `CORE_QUERY_DIRECT_JDBC = 0`: ninguno de los seis adapters core ni sus query persistence usa
  JDBC, `RowMapper`, `ResultSet` o `java.sql`.
- `JPA04_REMOVED_ROW_MAPPERS = 7`: todos quedaron sin consumidores; `JdbcValueMapper` se conserva
  porque JPA-05 aún lo usa en academic/reporting.
- `ACADEMIC_USER_COMMAND_DIRECT_JDBC = 0`: ningún command de academic ni de usuario usa JDBC;
  las queries core de usuario ya son JPA y solo permanecen queries académicas de JPA-05.
- `CANONICAL_EXECUTOR_PRODUCTIVE_CONSUMERS = 0` (`CanonicalStoredProcedureExecutor`; solo su bean de configuración y su propia clase). Retención como oraculo de test bajo JPA-07.
- `DIRECT_JDBC_ASISTENCIA = 0`, `DIRECT_JDBC_IN_SRC_MAIN` del delta JPA-03: 44 → 43 (sale `CierrePeriodoSqlServerAdapter`).
- La tabla de 44 más abajo es **BASELINE INVENTORY** (asignación histórica de JPA-02A). No describe el estado vigente. La fuente del delta es la sección JPA-03 de VALIDATION.md.

**HISTORICAL SNAPSHOT JPA-02A.** Inventario exacto del JDBC directo que quedaba en `src/main/java`
tras JPA-02A. Se generó el 2026-10-05 y sigue siendo la fuente histórica de asignación de
microfase. En ese corte JPA-02A no cambió el conteo: bootstrap estándar PASS,
`DIRECT_JDBC_GLOBAL = 44`. El estado vigente está en el snapshot superior (`29`, después de
JPA-04).

## Búsqueda y conteo

- Búsqueda: `JdbcTemplate|NamedParameterJdbc*|RowMapper|ResultSet|PreparedStatement|CallableStatement|MapSqlParameterSource|org.springframework.jdbc|java.sql.|StoredProcedureQuery` sobre `src/main/java`.
- Coincidencias brutas: 45 archivos.
- Falso positivo revisado a mano: `infrastructure/adapter/secondary/persistence/sqlserver/jpa/entity/UvDetalleAsistenciaEntity.java` (aparece `ResultSet` solo en un comentario Javadoc).
- **`DIRECT_JDBC_ASISTENCIA = 0`**. Ningún archivo de `..sqlserver.jpa..` ni de Asistencia aparece.
- **`DIRECT_JDBC_GLOBAL_BASELINE = 44`** archivos reales, todos fuera de Asistencia. Este inventario cubre los 44.
- `StoredProcedureQuery` en `src/main`: 0 (verificado en JPA-01).

## Leyenda de campos

- **ACCESS_TYPE:** `STORED_PROCEDURE_COMMAND`, `VIEW_QUERY`, `DIRECT_TABLE_READ`, `DIRECT_TABLE_WRITE`, `CATALOG_READ`, `AUDIT`, `REPORT`, `OTHER`.
- **TARGET_JPA_PATTERN:**
  - **A.** SP: `EntityManager` → `createNativeQuery("EXEC dbo.usp_xxx …")` → parámetros nombrados → `getResultList()` → `ProcedureResultMapper` → `ProcedureResultValidator`.
  - **B.** Vista: `@Entity @Immutable` solo en Infrastructure, consulta JPQL tipada con `EntityManager`.
  - **C.** Retirada: el archivo no tiene patrón propio; desaparece cuando su consumidor migra.
- **TRANSACTION_BOUNDARY:** tal como está hoy. Para SP, la frontera la posee el SP y está certificada solo para Asistencia en `CONTRACT_MATRIX.md`. Para el resto, se verifica en su microfase.
- **BLOCKER:** `NONE` si no hay bloqueo conocido. Un bloqueo DB se marca como `MISSING_DB_PROVIDER` o `DB_OWNER_DECISION_REQUIRED` y no detiene el resto del archivo.
- **Estado de código vs provider DB:** `BLOCKER` separa el estado de código (`JPA_READY` tras migrar) del estado del provider DB. Un SP ausente no impide migrar el código de esa capacidad; impide solo su ejecución real hasta que el owner DB lo publique.

## BASELINE INVENTORY — Inventario (44) de JPA-02A (histórico, no vigente)

Rutas bajo `src/main/java/co/edu/uco/asistenciasuco/`.

| # | MODULE | CLASS | PURPOSE | ACCESS_TYPE | DB_OBJECT | CURRENT_TECHNOLOGY | TARGET_JPA_PATTERN | TRANSACTION_BOUNDARY | BLOCKER | TARGET_MICROPHASE |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | CATALOG | `catalog/sqlserver/SqlServerMessageCatalogAdapter` | Mensaje de usuario y técnico por código | CATALOG_READ | `dbo.CatalogoMensajeUsuario`, `dbo.CatalogoMensajeTecnico` (AS-IS); destino `dbo.uv_mensaje_usuario`, `dbo.uv_mensaje_tecnico` | `NamedParameterJdbcOperations` | B (`@Immutable` sobre las vistas) | Lectura, autocommit | NONE | JPA-06 |
| 2 | CATALOG | `catalog/sqlserver/SqlServerParameterCatalogAdapter` | Parámetro por grupo y clave | CATALOG_READ | `dbo.CatalogoParametro` (AS-IS); destino `dbo.uv_parametro` | `NamedParameterJdbcOperations` | B | Lectura, autocommit | NONE | JPA-06 |
| 3 | ACADEMIC | `persistence/sqlserver/academic/AreaSqlServerAdapter` | Consulta de áreas | VIEW_QUERY | `uv_area` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 4 | ACADEMIC | `academic/AsignaturaDocenteSqlServerAdapter` | Asignación asignatura–docente | VIEW_QUERY | `uv_docente` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 5 | ACADEMIC | `academic/AsignaturaSqlServerAdapter` | CRUD de asignaturas | STORED_PROCEDURE_COMMAND + VIEW_QUERY | `usp_crear_asignatura`, `usp_actualizar_asignatura`, `usp_toggle_estado_asignatura`; `uv_asignatura`, `uv_semestre_plan_estudio` | `NamedParameterJdbcOperations` + `CanonicalStoredProcedureExecutor` | A (comandos) + B (lecturas) | SP-owned (verificar por SP) | NONE | JPA-03 (comandos) + JPA-05 (lecturas) |
| 6 | ACADEMIC | `academic/CierrePeriodoSqlServerAdapter` | Cierre masivo de período | STORED_PROCEDURE_COMMAND | `usp_ejecutar_cierre_masivo_periodo` | `CanonicalStoredProcedureExecutor` | A | SP-owned (verificar) | NONE | JPA-03 |
| 7 | ACADEMIC | `academic/CoordinadorSqlServerAdapter` | Alta de coordinador y lectura | STORED_PROCEDURE_COMMAND + VIEW_QUERY | `usp_crear_coordinador`; `uv_coordinador` | `CanonicalStoredProcedureExecutor` + `JdbcTemplate` | A + B | SP-owned (verificar) | NONE | JPA-03 (comando) + JPA-05 (lectura) |
| 8 | ACADEMIC | `academic/DecanoSqlServerAdapter` | Alta de decano y lectura | STORED_PROCEDURE_COMMAND + VIEW_QUERY | `usp_crear_decano`; `uv_decano` | `CanonicalStoredProcedureExecutor` + `JdbcTemplate` | A + B | SP-owned (verificar) | NONE | JPA-03 (comando) + JPA-05 (lectura) |
| 9 | ACADEMIC | `academic/EstudianteProgramaSqlServerAdapter` | Programa del estudiante | VIEW_QUERY | `uv_estudiante_programa`, `uv_estudiante_identidad`, `uv_usuario` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 10 | ACADEMIC | `academic/FacultadSqlServerAdapter` | Consulta de facultades | VIEW_QUERY | `uv_facultad` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 11 | ACADEMIC | `academic/HorarioDocenteSqlServerAdapter` | Horario del docente | VIEW_QUERY | `uv_horario_docente` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 12 | ACADEMIC | `academic/HorarioEstudianteSqlServerAdapter` | Horario del estudiante | VIEW_QUERY | `uv_horario_estudiante` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 13 | ACADEMIC | `academic/InstitucionSqlServerAdapter` | Consulta de instituciones | VIEW_QUERY | `uv_institucion` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 14 | ACADEMIC | `academic/MateriaEstudianteSqlServerAdapter` | Materias del estudiante | VIEW_QUERY | `uv_asignatura`, `uv_estudiante_grupo`, `uv_grupo` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 15 | ACADEMIC | `academic/ParametroSqlServerAdapter` | Parámetros académicos | VIEW_QUERY | `uv_parametro` (misma vista que catálogo #2) | `JdbcTemplate` | B | Lectura | NONE | JPA-06 (junto al catálogo) |
| 16 | ACADEMIC | `academic/PeriodoAcademicoSqlServerAdapter` | Periodos académicos | VIEW_QUERY | `uv_periodo_academico` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 17 | ACADEMIC | `academic/PlanEstudioSqlServerAdapter` | Plan de estudio: escritura y lectura | STORED_PROCEDURE_COMMAND + VIEW_QUERY | `usp_registrar_o_actualizar_plan_estudio` (escritura); `uv_plan_estudio` | `CanonicalStoredProcedureExecutor` + `JdbcTemplate` | A (comando) + B (lectura) | SP-owned | **MISSING_DB_PROVIDER** para el comando (TD-043) | JPA-03 (comando, bloqueado por DB) + JPA-05 (lectura) |
| 18 | ACADEMIC | `academic/SesionMateriaEstudianteSqlServerAdapter` | Sesiones de materia del estudiante | VIEW_QUERY | `uv_estudiante_grupo`, `uv_grupo`, `uv_sesion` | `JdbcTemplate` | B | Lectura | NONE | JPA-05 |
| 19 | AUTHORIZATION | `persistence/sqlserver/authorization/InstitutionalScopeSqlServerAdapter` | Alcance institucional (lectura de titularidad) | VIEW_QUERY | `uv_coordinador`, `uv_coordinador_identidad`, `uv_decano`, `uv_decano_identidad`, `uv_docente_identidad`, `uv_estudiante_grupo`, `uv_estudiante_identidad`, `uv_grupo`, `uv_usuario` | `JdbcTemplate` | B | Lectura | NONE (la regla de autorización sigue en Application/SP) | JPA-05 |
| 20 | CORE | `persistence/sqlserver/core/DocenteRepositorySqlServerAdapter` | Lectura de docentes | VIEW_QUERY | `uv_docente`, `uv_docente_identidad` | `JdbcTemplate` | B | Lectura | NONE | JPA-04 |
| 21 | CORE | `core/EstudianteRepositorySqlServerAdapter` | Lectura de estudiantes | VIEW_QUERY | `uv_estudiante`, `uv_estudiante_identidad`, `uv_usuario` | `JdbcTemplate` | B | Lectura | NONE | JPA-04 |
| 22 | CORE | `core/GrupoRepositorySqlServerAdapter` | Grupos: comandos y lectura | STORED_PROCEDURE_COMMAND + VIEW_QUERY | `usp_crear_grupo`, `usp_actualizar_grupo`, `usp_registrar_estudiante_en_grupo_usuario_no_existente`; `uv_grupo`, `uv_estudiante_grupo`, `uv_estudiante_identidad`, `uv_usuario` | `CanonicalStoredProcedureExecutor` + `NamedParameterJdbcOperations` + `TransactionOperations` | A + B | `TransactionOperations.execute` ×3 (crear, actualizar, registrar estudiante). Migra con la `TRANSACTION_MATRIX` de JPA-02B | `MISSING_DB_PROVIDER` solo para registrar estudiante (TD-043). Crear y actualizar no bloqueados | JPA-02B (comandos) + JPA-04 (lecturas) |
| 23 | CORE | `core/SesionRepositorySqlServerAdapter` | Sesiones: comandos y lectura | STORED_PROCEDURE_COMMAND + VIEW_QUERY | `usp_crear_sesion`, `usp_actualizar_sesion`, `usp_cerrar_sesion`, `usp_generar_sesiones_grupo`; `uv_sesion` | `CanonicalStoredProcedureExecutor` + `NamedParameterJdbcOperations` | A + B | Verificado por SP en JPA-02B: crear condicional, generar propia, actualizar/cerrar sin transacción propia; outer tx actual NO | NONE (`usp_cerrar_sesion` con firma documentada por TD-039) | JPA-02B (comandos) + JPA-04 (lectura) |
| 24 | CORE | `core/TipoIdentificacionRepositorySqlServerAdapter` | Catálogo de tipos de identificación | VIEW_QUERY | `uv_tipo_identificacion` | `JdbcTemplate` | B | Lectura | NONE | JPA-04 |
| 25 | CORE | `core/UsuarioRepositorySqlServerAdapter` | Usuarios: sincronización y lectura | STORED_PROCEDURE_COMMAND + VIEW_QUERY | `usp_sincronizar_usuario` (escritura); `uv_usuario` | `CanonicalStoredProcedureExecutor` + `NamedParameterJdbcOperations` | A (comando) + B (lectura) | SP-owned | **MISSING_DB_PROVIDER** para el comando (TD-043). Sin equivalente aprobado (`usp_sincronizar_usuario_interno` no es equivalente) | JPA-03 (comando, bloqueado por DB) + JPA-04 (lectura) |
| 26 | REPORTING | `persistence/sqlserver/reporting/ReporteAsistenciaSqlServerAdapter` | Reporte de asistencia | REPORT | `uv_asistencia`, `uv_detalle_asistencia`, `uv_estudiante_grupo`, `uv_estudiante_identidad`, `uv_sesion`, `uv_usuario` | `JdbcTemplate` | B (reutiliza `UvAsistenciaEntity` y `UvDetalleAsistenciaEntity`) | Lectura | NONE | JPA-05 |
| 27 | SUPPORT | `support/mapping/DocenteAsignacionAcademicaRepositoryRowMapper` | Mapeo de asignación académica del docente | OTHER | (mapea `uv_docente`) | `RowMapper` | C | n/a | NONE | JPA-05 |
| 28 | SUPPORT | `support/mapping/DocenteIdentidadRepositoryRowMapper` | Mapeo de identidad del docente | OTHER | (mapea `uv_docente_identidad`) | `RowMapper` | C | n/a | NONE | JPA-04 |
| 29 | SUPPORT | `support/mapping/EstudianteContextoAcademicoRepositoryRowMapper` | Mapeo de contexto académico del estudiante | OTHER | (mapea vistas de estudiante) | `RowMapper` | C | n/a | NONE | JPA-05 |
| 30 | SUPPORT | `support/mapping/EstudianteResumenRepositoryRowMapper` | Mapeo de resumen del estudiante | OTHER | (mapea `uv_estudiante`) | `RowMapper` | C | n/a | NONE | JPA-04 |
| 31 | SUPPORT | `support/mapping/GrupoRepositoryRowMapper` | Mapeo de grupo | OTHER | (mapea `uv_grupo`) | `RowMapper` | C | n/a | NONE | JPA-04 |
| 32 | SUPPORT | `support/mapping/JdbcValueMapper` | Conversión de `java.sql.Date/Timestamp/Time` a UTC. Contrato TD-037 / LB-001B.3 | OTHER | (`uv_sesion`, fechas UTC) | `java.sql.*` | C (reemplazo: mapeo JPA de `Instant`/`LocalDateTime` UTC) | n/a | NONE. Regla UTC contractual debe preservarse con prueba | JPA-04 |
| 33 | SUPPORT | `support/mapping/TipoIdentificacionRepositoryRowMapper` | Mapeo de tipo de identificación | OTHER | (`uv_tipo_identificacion`) | `RowMapper` | C | n/a | NONE | JPA-04 |
| 34 | SUPPORT | `support/mapping/UsuarioIdentidadRepositoryRowMapper` | Mapeo de identidad de usuario | OTHER | (`uv_usuario`) | `RowMapper` | C | n/a | NONE | JPA-04 |
| 35 | SUPPORT | `support/procedure/CanonicalProcedureResultMapper` | Mapeo de la fila canónica de SP | OTHER | (resultado canónico de SP) | `RowMapper` | Reemplazar por `ProcedureResultMapper` (ya existente en Asistencia) | n/a | NONE | JPA-02B (migrar consumidores de SP) |
| 36 | SUPPORT | `support/procedure/CanonicalStoredProcedureExecutor` | Ejecutor genérico de SP con `NamedParameterJdbcOperations` | STORED_PROCEDURE_COMMAND | Todos los SP de comando no-Asistencia | `NamedParameterJdbcOperations` | A (patrón común, sin executor propio) | SP-owned | NONE (se retira al quedar sin consumidores) | JPA-07 (tras migrar #5–8, #17, #22, #23, #25) |
| 37 | AUDIT | `infrastructure/audit/adapter/sqlserver/AuditEventJdbcRepository` | Persistencia de auditoría | AUDIT | `dbo.AuditoriaEvento` (`INSERT` y `SELECT TOP 1`) | `JdbcTemplate` | **BLOCKED_BY_DB_DECISION**: si hay DML directo aprobado → `AuditEventEntity` + `EntityManager.persist`; si hay SP público → A | autocommit (sin transacción propia) | **DB_OWNER_DECISION_REQUIRED** (TD-010, D-LB008-04) | JPA-06 (bloqueado por DB) |
| 38 | CONFIG | `config/adapters/persistence/sqlserver/SqlServerAcademicAdapterConfiguration` | Wiring de adapters académicos JDBC | OTHER | n/a | `JdbcTemplate` / `NamedParameterJdbcOperations` | C | n/a | NONE | JPA-06 (retirar cuando el último adapter académico migre) |
| 39 | CONFIG | `config/adapters/persistence/sqlserver/SqlServerAuditSupportConfiguration` | Wiring de auditoría JDBC | OTHER | n/a | `JdbcTemplate` | C | n/a | depende de #37 | JPA-06 |
| 40 | CONFIG | `config/adapters/persistence/sqlserver/SqlServerCatalogAdapterConfiguration` | Wiring de catálogos JDBC | OTHER | n/a | `NamedParameterJdbcOperations` | C | n/a | NONE | JPA-06 |
| 41 | CONFIG | `config/adapters/persistence/sqlserver/SqlServerCoreRepositoryAdapterConfiguration` | Wiring de repositorios core. Ya registra el bean JPA de Asistencia | OTHER | n/a | `JdbcTemplate` / `NamedParameterJdbcOperations` / `TransactionOperations` | C | n/a | NONE | JPA-04 (retirar cuando todos los beans core migren) |
| 42 | CONFIG | `config/adapters/persistence/sqlserver/SqlServerProcedureSupportConfiguration` | Wiring de `CanonicalStoredProcedureExecutor` | OTHER | n/a | `NamedParameterJdbcOperations` | C | n/a | NONE | JPA-07 |
| 43 | CONFIG | `config/adapters/persistence/sqlserver/SqlServerReportAdapterConfiguration` | Wiring del reporte de asistencia | OTHER | n/a | `JdbcTemplate` | C | n/a | NONE | JPA-05 |
| 44 | CONFIG | `config/adapters/persistence/sqlserver/SqlServerSecurityScopeAdapterConfiguration` | Wiring del alcance institucional | OTHER | n/a | `JdbcTemplate` | C | n/a | NONE | JPA-05 |

## Resumen por microfase

| Microfase | Archivos | Contenido |
|---|---|---|
| **JPA-02A** (PASS) | 0 migrados | Bootstrap JPA estándar; asignación completa de los 44 |
| **JPA-02B** (`READY_WITH_SCOPED_DB_BLOCKER`) | #22 (comandos), #23 (comandos), #35 | 7 commands core: 4 Sesión + 3 Grupo, y mapeo canónico de SP; 1 command Grupo bloqueado por TD-043 |
| **JPA-03** | #5, #6, #7, #8, #17 (comando), #25 (comando) | Comandos academic/user. #17 y #25 bloqueados por TD-043 |
| **JPA-04** | #20, #21, #22 (lectura), #23 (lectura), #24, #25 (lectura), #28, #30, #31, #32, #33, #34, #41 | Lecturas core y vistas de identidad |
| **JPA-05** | #3, #4, #5 (lectura), #7 (lectura), #8 (lectura), #9–#14, #16, #17 (lectura), #18, #19, #26, #27, #29, #43, #44 | Lecturas academic, autorización y reporting |
| **JPA-06** (catálogos: `PASS`; auditoría: `BLOCKED_BY_TD010_DECISION`) | Catálogos #1, #2, #40 (cerrados en JPA-06). Auditoría #37, #39 (bloqueados por TD-010). #15 ya era JPA desde JPA-05 | Catálogos y auditoría |
| **JPA-07** | #6, #7, #8, #9 (`JdbcValueMapper`, `CanonicalProcedureResultMapper`, `CanonicalStoredProcedureExecutor`, `SqlServerProcedureSupportConfiguration`) y retiro de `spring-boot-starter-jdbc` | Soporte de procedimientos, limpieza de código muerto y validación final |

Nota (JPA-06): la fila #15 del inventario base se conserva por trazabilidad; `academic/ParametroSqlServerAdapter` ya usa
`ParametroJpaQueryPersistence` desde JPA-05 y no aparece en el grep de `src/main`.

## Bloqueos DB (no bloquean el resto)

- **TD-043 (`MISSING_DB_PROVIDER`):** `usp_registrar_estudiante_en_grupo_usuario_no_existente` (#22), `usp_registrar_o_actualizar_plan_estudio` (#17), `usp_sincronizar_usuario` (#25). El código de cada capacidad migra a JPA como `JPA_READY` cuando su microfase lo permita; la ejecución real queda bloqueada hasta que el owner DB publique un contrato. No se sustituyen por SP equivalentes.
- **TD-010 (`DB_OWNER_DECISION_REQUIRED`):** #37 `AuditEventJdbcRepository` y sus configuraciones (#39).

## Verificación del inventario

- El conteo de 44 se obtuvo con la búsqueda de arriba. La separación en MÓDULO y ACCESS_TYPE es por nombre de clase y por el objeto SQL que cada archivo referencia.
- Los objetos SQL se extrajeron con `usp_[a-z_]+`, `uv_[a-z_]+` y `dbo.<Tabla>`. Para los SP de comando no-Asistencia, la firma y la transacción interna no se verificaron aquí. Se verificarán en su microfase con `CONTRACT_MATRIX`.
- Las clases `RowMapper` y de configuración no contienen SQL propio. Su destino depende del consumidor que las usa, por eso figuran como `C` (retirada).

## Actualización JPA-02B (2026-10-05, evidencia real)

Los commands de Sesión y Grupo ya no usan JDBC. Las lecturas siguen en JDBC hasta JPA-04.

| # | Clase | Estado tras JPA-02B | Qué queda |
|---|---|---|---|
| 22 | `core/GrupoRepositorySqlServerAdapter` | Commands `crearGrupo`, `actualizarGrupo`, `registrarEstudianteEnGrupo` delegan en `GrupoJpaCommandPersistence` dentro de `TransactionOperations` (frontera conservada). `CODE_MIGRATION_STATUS = JPA` para los tres. | Lecturas `consultarGrupos`, `consultarEstudiantesGrupo` (JDBC → JPA-04). `registrarEstudianteEnGrupo` queda con `DB_PROVIDER_STATUS = MISSING` (TD-043). |
| 23 | `core/SesionRepositorySqlServerAdapter` | Commands `crearSesion`, `actualizarSesion`, `cerrarSesion`, `generarSesionesGrupo` delegan en `SesionJpaCommandPersistence`. Sin transacción exterior. | Lecturas `consultarSesion`, `consultarSesionesPorGrupo` (JDBC → JPA-04). |
| 35 | `support/procedure/CanonicalProcedureResultMapper` | Ya no lo usan los commands de Sesión ni de Grupo. Los commands JPA usan `ProcedureResultMapper`. | Sigue existiendo para `CanonicalStoredProcedureExecutor`, que aún usan `UsuarioRepositorySqlServerAdapter` y los verticales académicos. Se retira en JPA-07. |
| 36 | `support/procedure/CanonicalStoredProcedureExecutor` | Sin cambio de consumidores en esta microfase: lo usan Usuario y los verticales académicos. Se retira en JPA-07. | Consumidores JPA-03, JPA-07. |

Conteos recalculados después de implementar:

- `DIRECT_JDBC_GLOBAL_FILES` = 44 (sin cambio). Ver CONTRACT_MATRIX, sección "Resultado JPA-02B".
- `JDBC_COMMAND_PATHS_SESION` = 0 y `JDBC_COMMAND_PATHS_GRUPO` = 0.
- `JPA_COMMAND_PATHS_SESION` = 4 y `JPA_COMMAND_PATHS_GRUPO` = 3.
- `JDBC_FALLBACK` y selectores nuevos = 0.

## Actualización JPA-03 (2026-10-05, evidencia real)

Commands académicos y de usuario sobre JPA. Las queries siguen en JDBC (JPA-04 / JPA-05).

| # | Clase | Estado tras JPA-03 | Qué queda |
|---|---|---|---|
| 5 | `academic/AsignaturaSqlServerAdapter` | Commands `crear`, `actualizar`, `toggleEstado` delegan en `AsignaturaJpaCommandPersistence`. `CODE_MIGRATION_STATUS = JPA`. | Queries `consultarAsignaturasPorPrograma` y `consultarAsignaturasPorPlan` (JDBC → JPA-05). |
| 6 | `academic/CierrePeriodoSqlServerAdapter` | Command delega en `CierrePeriodoJpaCommandPersistence`. **Sin JDBC: sale de la lista de 44.** | Nada. Se mantiene como adapter por coherencia con la cadena Port → Adapter → JpaCommandPersistence. |
| 7 | `academic/CoordinadorSqlServerAdapter` | Command `crearCoordinador` delega en `CoordinadorJpaCommandPersistence`. | Query `consultarCoordinadoresPorFacultad` (JDBC → JPA-05). |
| 8 | `academic/DecanoSqlServerAdapter` | Command `crearDecano` delega en `DecanoJpaCommandPersistence`. | Query `consultarDecanos` (JDBC → JPA-05). |
| 17 | `academic/PlanEstudioSqlServerAdapter` | Command delega en `PlanEstudioJpaCommandPersistence`. TD-043: SP ausente. | Query `consultarPlanesPorPrograma` (JDBC → JPA-05). |
| 25 | `core/UsuarioRepositorySqlServerAdapter` | `crearUsuario` delega en `UsuarioJpaCommandPersistence`. TD-043: SP ausente. | Consultas `uv_usuario` (JDBC → JPA-04). |
| 36 | `support/procedure/CanonicalStoredProcedureExecutor` | **0 consumidores productivos.** Solo lo referencia su bean (#42). | Retiro en JPA-07 o inmediato. |
| 42 | `config/.../SqlServerProcedureSupportConfiguration` | Bean sin consumidores. | Retiro en JPA-07. |

Conteos recalculados:

- `DIRECT_JDBC_GLOBAL_FILES`: **44 → 43** (sale #6). El conteo bruto por regex es 44 porque incluye el falso positivo `UvDetalleAsistenciaEntity` (Javadoc), ya descontado en la baseline.
- `ACADEMIC/USER_COMMAND_JDBC_PATHS`: **0** en los 6 `*JpaCommandPersistence` (ArchUnit `JpaAcademicUserCommandRulesTest`). Los adapters conservan JDBC solo para queries.
- `StoredProcedureQuery` / `ParameterMode` en `src/main`: 0.

## Actualización JPA-04 (2026-10-05, evidencia real)

Las queries core de Sesión, Grupo, Usuario, Docente, Estudiante y TipoIdentificación ya son
JPA-only. El SQL JDBC baseline se conserva únicamente en `CoreViewQueriesJpaParityIT` bajo
`src/test`.

| Elemento histórico | Estado tras JPA-04 |
|---|---|
| #20 `DocenteRepositorySqlServerAdapter` | consultas delegan en `DocenteJpaQueryPersistence`; sin JDBC |
| #21 `EstudianteRepositorySqlServerAdapter` | consultas delegan en `EstudianteJpaQueryPersistence`; sin JDBC |
| #22 `GrupoRepositorySqlServerAdapter` (lecturas) | consultas delegan en `GrupoJpaQueryPersistence`; commands JPA-02B intactos |
| #23 `SesionRepositorySqlServerAdapter` (lecturas) | consultas delegan en `SesionJpaQueryPersistence`; commands JPA-02B intactos |
| #24 `TipoIdentificacionRepositorySqlServerAdapter` | consulta delega en `TipoIdentificacionJpaQueryPersistence`; sin JDBC |
| #25 `UsuarioRepositorySqlServerAdapter` (lecturas) | consultas delegan en `UsuarioJpaQueryPersistence`; command JPA-03 intacto |
| #28, #30, #31, #33, #34 | RowMapper retirados por cero consumidores |
| #27 y #29 | también retirados: eran usados únicamente por las consultas core Docente/Estudiante, no por JPA-05 |
| #32 `JdbcValueMapper` | se conserva por consumidores academic/reporting JPA-05; cero uso desde core |
| #41 `SqlServerCoreRepositoryAdapterConfiguration` | wiring core por `EntityManager`; sin JDBC |

Conteos finales de la microfase:

- `DIRECT_JDBC_GLOBAL_FILES`: **43 → 29** reales (30 bruto, un falso positivo Javadoc).
- `CORE_QUERY_DIRECT_JDBC_FILES`: **13 asignados → 0**.
- `JPA04_ROW_MAPPERS_REMOVED`: **7**.
- `JDBC_FALLBACK_RUNTIME = 0`; `StoredProcedureQuery = 0`.
- Paridad: `CoreViewQueriesJpaParityIT` **6/6 PASS**, 0 skips.

El inventario histórico de 44 se conserva para trazabilidad; el snapshot normativo vigente es el
encabezado de este documento. Los 29 residuales pertenecen a JPA-05/JPA-06/JPA-07.

## Actualización JPA-05 (2026-10-05, evidencia real)

- `DIRECT_JDBC_GLOBAL_BEFORE = 29`; `DIRECT_JDBC_GLOBAL_AFTER = 11` archivos reales (sin el falso positivo Javadoc `UvDetalleAsistenciaEntity`).
- Salen del JDBC: 14 adaptadores académicos, `InstitutionalScopeSqlServerAdapter`, `ReporteAsistenciaSqlServerAdapter` y las configuraciones de seguridad y reporte.
- Queda en JDBC dentro del scope: `EstudianteProgramaSqlServerAdapter` y su bean en `SqlServerAcademicAdapterConfiguration`. Motivo: `BLOCKED_BY_VIEW_IDENTITY` (ver CONTRACT_MATRIX, JPA-05).
- `JdbcValueMapper` sigue con consumidores fuera de scope (catálogo, auditoría, `CanonicalStoredProcedureExecutor`); no se retira en JPA-05.
- JPA-05 = NOT CLOSED hasta resolver la identidad de `uv_estudiante_programa`.

## Cierre JPA-05 (2026-10-05, evidencia real recalculada desde `src/main/java`)

Recalculado con el regex de la sección "Búsqueda y conteo" (no reutiliza el 11 de la ejecución JPA-05 previa).

- Coincidencias brutas: **10**. Falso positivo Javadoc descontado: `UvDetalleAsistenciaEntity` (aparece `ResultSet` en un comentario).
- `DIRECT_JDBC_GLOBAL = 9` archivos reales. Antes de esta microfase: 11 (ejecución JPA-05 previa, con `EstudianteProgramaSqlServerAdapter` bloqueado).
- `DIRECT_JDBC_JPA05_SCOPE = 0`: ningún archivo de `academic/`, `authorization/` ni `reporting/` depende de JDBC.
- Cambio de esta microfase: `EstudianteProgramaSqlServerAdapter` migra a `EstudianteProgramaJpaQueryPersistence` (JPA-only) y su bean residual de `SqlServerAcademicAdapterConfiguration` pasa a `EntityManager`. Sale el último adaptador JDBC del scope.

Residual asignado tras JPA-05 (HISTÓRICO, 9 archivos; ver "Actualización JPA-06" para el estado vigente):

| # | Clase | Clasificación | Microfase |
|---|---|---|---|
| 1 | `catalog/sqlserver/SqlServerMessageCatalogAdapter` | CATALOG_READ | JPA-06 (**cerrado**) |
| 2 | `catalog/sqlserver/SqlServerParameterCatalogAdapter` | CATALOG_READ | JPA-06 (**cerrado**) |
| 3 | `config/.../SqlServerCatalogAdapterConfiguration` | wiring catálogos | JPA-06 (**cerrado**) |
| 4 | `infrastructure/audit/adapter/sqlserver/AuditEventJdbcRepository` | AUDIT; `BLOCKED_BY_TD010_DECISION` | JPA-06 (**bloqueado**) |
| 5 | `config/.../SqlServerAuditSupportConfiguration` | wiring auditoría; depende de #4 | JPA-06 (**bloqueado**) |
| 6 | `support/mapping/JdbcValueMapper` | conversión `java.sql.*` → UTC; consumidor productivo restante: #7 | JPA-07 |
| 7 | `support/procedure/CanonicalProcedureResultMapper` | RowMapper del ejecutor canónico | JPA-07 |
| 8 | `support/procedure/CanonicalStoredProcedureExecutor` | `PRODUCTIVE_CONSUMERS = 0` (solo su bean) | JPA-07 |
| 9 | `config/.../SqlServerProcedureSupportConfiguration` | bean sin consumidores | JPA-07 |

## Actualización JPA-06 (2026-10-05, evidencia real)

- **Estado de JPA-06:** `NOT_CLOSED / BLOCKED_BY_TD010`. Catálogos `PASS`; auditoría `BLOCKED_BY_TD010_DECISION`.
- **Conteo:** `DIRECT_JDBC_GLOBAL_BEFORE = 9`; `DIRECT_JDBC_GLOBAL_AFTER = 6` archivos reales (7 coincidencias brutas
  menos el falso positivo Javadoc `UvDetalleAsistenciaEntity`).
- **Salen del JDBC:** #1 `SqlServerMessageCatalogAdapter`, #2 `SqlServerParameterCatalogAdapter`, #3
  `SqlServerCatalogAdapterConfiguration`. Catálogos usan `CatalogJpaQueryPersistence` (`EntityManager` + JPQL) sobre
  `UvMensajeUsuarioEntity`, `UvMensajeTecnicoEntity` (nuevas, `@Entity @Immutable`) y `UvParametroEntity` (reutilizada).
- **JDBC_CATALOG_BEFORE = 3 → JDBC_CATALOG_AFTER = 0** (en `src/main`).
- **Permanece en JDBC (auditoría, `BLOCKED_BY_TD010`):** #4 `AuditEventJdbcRepository`, #5 `SqlServerAuditSupportConfiguration`.
  No se implementó auditoría: el DML directo y el SP público no están decididos por el owner DB.
- **Consumidores productivos restantes (verificados por grep en `src/main`):**
  - `JdbcValueMapper`: `CanonicalProcedureResultMapper` (único código; `AcademicViewJpaProjectionMapper` solo lo cita en Javadoc).
  - `CanonicalProcedureResultMapper`: `CanonicalStoredProcedureExecutor`.
  - `CanonicalStoredProcedureExecutor`: solo su bean (#9). `PRODUCTIVE_CONSUMERS = 0`.
- **Clasificación del soporte de procedimientos:** #6, #7, #8, #9 son JPA-07 dead/support cleanup. No se borran en
  JPA-06: `CanonicalStoredProcedureExecutorTest` y `JdbcValueMapperTest` son oráculos de test que siguen vivos, y el
  retiro pertenece a JPA-07.
- **Baselines JDBC de paridad** (solo `src/test`): `CatalogJdbcBaseline` (nuevo, JPA-06), y los baselines previos.
- **Hallazgo para JPA-07 (importante):** `CanonicalStoredProcedureExecutor` tiene `PRODUCTIVE_CONSUMERS = 0` en `src/main`,
  pero **lo inyectan o instancian 9 clases de test**: `AcademicUserCommandsSuccessParityIT`, `AsistenciaCommandConcurrencyIT`,
  `AsistenciaCommandJpaParityIT`, `AsistenciaCommandsSpParityIT`, `AsistenciaQueryJpaParityIT`,
  `JpaAttendanceStoredProcedureFeasibilityIT` (campo `@Autowired`), los oráculos `AcademicUserJdbcBaselineOracle` y
  `AsistenciaJdbcBaselineOracle` (constructor), y `CanonicalStoredProcedureExecutorTest` (instancia directa).
  `AsistenciaRepositorySqlServerIT` y las reglas ArchUnit (`JpaAcademicUserCommandRulesTest`, `JpaCoreCommandRulesTest`) solo lo nombran.
  Retirar el bean en JPA-07 exige migrar esos oráculos/ITs (no basta borrar la clase). No se borra en JPA-06.

Notas:
- `CANONICAL_EXECUTOR_PRODUCTIVE_CONSUMERS = 0`: no se reintrodujo ningún consumidor productivo. Su retiro queda para JPA-07.
- Baselines JDBC (oráculos de paridad) viven solo en `src/test` (`EstudianteProgramaJdbcBaseline`, `InstitutionalScopeJdbcBaseline`, etc.). No cuentan en `src/main`.


## Verificación JPA-06A (2026-10-06)

- DIRECT_JDBC_GLOBAL_BEFORE: 6. DIRECT_JDBC_GLOBAL_AFTER: 6. Sin aumento.
- Archivos: JdbcValueMapper, CanonicalProcedureResultMapper, CanonicalStoredProcedureExecutor, AuditEventJdbcRepository, SqlServerAuditSupportConfiguration, SqlServerProcedureSupportConfiguration.
- Los repositories JPA de la capacidad migrada no contienen JDBC (ArchUnit JpaRepositoryArchitectureRulesTest).
- TD-043 (3 SP ausentes) sigue activo; TD-010 bloquea la auditoría (JPA-06B).

## ADDENDUM FINAL — barrido (2026-10-07)

- **Estado vigente:** `TD-043 = CLOSED`, `TD-047 = CLOSED`; `DIRECT_JDBC_IN_SRC_MAIN = 0`; `BACKEND_DIRECT_INTERNAL_SP = 0`;
  providers DB de matricula (`usp_registrar_estudiante_en_grupo`), sincronizacion de usuario (`usp_sincronizar_usuario`) y
  PlanEstudio (`usp_registrar_o_actualizar_plan_estudio`) = `PRESENT`; commands JPA de SP = `JpaProcedureExecutor`;
  manejo tecnico generico de queries JPA = `JpaQueryExecutor`.

Barrido sobre `src/main` (resultado real):

- `JdbcTemplate`, `NamedParameterJdbcTemplate`, `java.sql.`, `PreparedStatement`, `CallableStatement`, `ResultSet`: **0** → `DIRECT_JDBC_IN_SRC_MAIN = 0`.
- `_interno` y `usp_registrar_estudiante_en_grupo_usuario_no_existente`: **0** → `BACKEND_DIRECT_INTERNAL_SP = 0`, `LEGACY_STUDENT_PROVIDER_IN_SRC_MAIN = 0`.
- Escritura de PlanEstudio sin `codigo`/`nombre` → `PLAN_ESTUDIO_LEGACY_WRITE_FIELDS = 0` (`nombrePrograma` de la lectura no cuenta).
- Boilerplate de queries JPA: 24 repositories / 34 queries usan `support.query.JpaQueryExecutor`; sin `LOGGER` ni `try/catch` generico de persistencia (`REPOSITORY_GENERIC_LOGGERS = 0`, `REPOSITORY_GENERIC_QUERY_TRY_CATCH = 0`). Se conservan, por semantica propia: `MessageCatalogJpaRepository`, `ParameterCatalogJpaRepository`, `AuditEventJpaRepository` y la serializacion (`CrosscuttingException`) de `AsistenciaJpaRepository`.
- Los oraculos JDBC permanecen solo en `src/test` (p. ej. `PlanEstudioJdbcBaseline`).
