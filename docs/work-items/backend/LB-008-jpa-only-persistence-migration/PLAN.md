# PLAN — LB-008: Migración de persistencia JPA-only

## Identidad y objetivo

- Fecha: 2026-10-03 / autor: agente principal de ingeniería backend (sesión del profesor) / base Git: rama `jose-valencia/lb-004-stateless-serverless-readiness`, HEAD `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d`.
- Objetivo: JPA/Hibernate como única API de persistencia usada directamente por el código productivo. Eliminar JDBC directo, selectores `jdbc|jpa`, hybrid adapters y fallback JDBC, sin cambiar Domain, Application, HTTP, OpenAPI, seguridad, realtime, semántica de SP, ownership ni schema DB.
- Criterios de aceptación del programa: `DIRECT_JDBC_IN_SRC_MAIN = 0`, `HYBRID_JDBC_JPA_RUNTIME = 0`, `JDBC_FALLBACK_RUNTIME = 0`, `JDBC_PROVIDER_SELECTOR = 0`, paridad certificada en SQL Server real, `clean verify` y `-Pintegration` en PASS.
- Skills y fuentes: uco-persistencia, uco-baseline, uco-arquitectura, uco-testing; [AGENTS](../../../AGENTS.md); [SOURCE_OF_TRUTH](../../governance/SOURCE_OF_TRUTH.md); [ADR-003](../../adr/ADR-003-jpa-only-persistence.md) (TARGET); [ADR-002](../../adr/ADR-002-jpa-incremental.md) (histórico); [JDBC_TO_JPA](../../persistence/JDBC_TO_JPA.md) §0; [DoR](../../governance/DEFINITION_OF_READY.md).

## AS-IS y evidencia

| Hecho | Archivo + símbolo / contrato + versión | Evidencia y límites |
|---|---|---|
| Línea base de build | `./mvnw.cmd clean verify` con JDK 25.0.2, commit base + cambios LB-004 sin consolidar | BUILD SUCCESS, 1464 tests, 0 fallos/errores/skips; LINE 88.63 % (≥80), BRANCH 79.08 % (≥70). Ver [VALIDATION](VALIDATION.md). |
| Archivos `src/main` con tokens JDBC | Búsqueda certificada en JPA-00/JPA-01 de `JdbcTemplate`, `NamedParameterJdbc*`, `RowMapper`, `ResultSet`, `MapSqlParameterSource`, `org.springframework.jdbc`, `java.sql.` | **Baseline JPA-00: 45 archivos reales**. **Estado tras JPA-01: 44**, todos fuera de Asistencia; `DIRECT_JDBC_ASISTENCIA = 0`. Lista y clasificación en [CONTRACT_MATRIX](CONTRACT_MATRIX.md#inventario-jdbc-baseline). |
| Dependencias | `pom.xml`: `spring-boot-starter-jdbc` (l.66) y `spring-boot-starter-data-jpa` (l.77) | Ambas presentes. JDBC no se retira hasta JPA-07. |
| Bootstrap JPA de piloto | `AsistenciasUcoApplication` excluye `HibernateJpaAutoConfiguration`, `HibernateMetricsAutoConfiguration` y `DataJpaRepositoriesAutoConfiguration`; `SqlServerJpaAsistenciaQueryAdapterConfiguration` construye manualmente el `EntityManagerFactory` y registra las tres entities de Asistencia; `application.yml` conserva `open-in-view=false` y `ddl-auto=none` | AS-IS comprobado tras JPA-01. `JpaCapabilityRequiredCondition` ya fue retirado. Se normaliza en JPA-02A antes de migrar masivamente views/entities fuera de Asistencia. |
| Selectores/híbrido de Asistencia | Los selectores `asistencia-query-provider` / `asistencia-command-provider`, `AsistenciaRepositoryHybridSqlServerAdapter` y el fallback JDBC fueron retirados en JPA-01 | `ASISTENCIA_PERSISTENCE_PROVIDER = JPA_ONLY`; no se restauran en JPA-02A. |
| Patrón JPA command vigente | `AsistenciaJpaCommandPersistence`: `EntityManager` + `createNativeQuery("EXEC …")` + parámetros nombrados + `getResultList()` + `ProcedureResultMapper` + `ProcedureResultValidator` | Cuatro commands certificados; `StoredProcedureQuery = 0` en `src/main` de Asistencia. |
| Patrón JPA query existente | `AsistenciaJpaQueryPersistence`, `UvAsistenciaEntity`, `UvDetalleAsistenciaEntity`, `UvEstudianteGrupoEntity` (`@Entity`/`@Immutable` en Infrastructure) | Piloto LB-002.1. |
| Ejecutor canónico JDBC | `CanonicalStoredProcedureExecutor` (`NamedParameterJdbcOperations`) | Usado por commands JDBC de Asistencia y otros módulos. No se borra mientras tenga consumidores. |
| Auditoría | `infrastructure/audit/adapter/sqlserver/AuditEventJdbcRepository` (`JdbcTemplate`: `INSERT` y `SELECT TOP 1` sobre `dbo.AuditoriaEvento`) | DB: existe `schema/tables/AuditoriaEvento.sql`; no hay SP público de auditoría. `DB_BASELINE_CONTRACT.md` describe el shape como inmutable pero no autoriza el `INSERT` directo del backend. Ver TD-010 y [CONTRACT_MATRIX](CONTRACT_MATRIX.md). |
| Consumidores DB | 19 nombres de SP distintos referenciados por Java; 26 vistas `uv_*` distintas (el literal `uv_auth_` es un prefijo, no un objeto) | Ver [CONTRACT_MATRIX](CONTRACT_MATRIX.md). |
| Repositorio DB | `C:\Users\josev\OneDrive\Documentos\AsisteciaUco_db\git\gestion-asistencia-db`, rama `develop`, HEAD `f2871a9564d6c4cc5abc3745854414243bfda238`, `git status` limpio | Coincide con el HEAD recibido. Snapshot DB esperado/actual `acccb378…` **MATCH / VERIFICADO**. El snapshot backend `2fc9be69…` se conserva como BASE_SNAPSHOT. |
| SQL Server | Docker `sql_server_asistencias`, SQL Server 2022 Developer, `localhost:1433`, DB `gestionasistenciadb` | **Disponible.** Gate oficial DB `test_summary.ps1`: PASS (157 ejecutadas, 156 PASS, 0 FAIL, 1 skip permitido). Integración global backend: `NOT_GREEN_TD043`; gate causal final de JPA-01: **83/83 IT PASS**. Ver VALIDATION. |

## TARGET

- JPA/Hibernate como única API productiva: `EntityManager`, `createNativeQuery`, typed queries y `@Entity @Immutable` para vistas, todo en `infrastructure/adapter/secondary/persistence/sqlserver/jpa/`.
- Commands de SP: `EntityManager` + `createNativeQuery("EXEC …")` + binding nombrado + `getResultList()` + `ProcedureResultMapper` + `ProcedureResultValidator`. `StoredProcedureQuery` queda histórico en LB-002 y no es un patrón regular nuevo.
- Resultado canónico: `ProcedureResult` (interfaz), `CanonicalProcedureResult` (implementación), `ProcedureResultMapper` (forma/cardinalidad/tipos) y `ProcedureResultValidator` (correlación/estado/traducción), reutilizando `DbExceptionTranslator`, `DbFailureClassifier`, `DatabaseOperationException`, `DatabaseErrorCode` y `CorrelationIdContext`.
- Queries de vistas: entidades `@Immutable` planas, `EntityManager` + JPQL tipado, sin `EAGER` ni asociaciones innecesarias.
- Configuración JPA estándar Spring Boot; `open-in-view=false`; `ddl-auto` `none` o `validate` (sin `update`/`create`/`create-drop`).
- Sin selectores, sin hybrid, sin fallback JDBC productivo.
- `mssql-jdbc` permanece como driver interno de Hibernate. `spring.datasource.*` se conserva.

## Clase de cambio y alcance de rutas

- Change class: `PERSISTENCE_MIGRATION`
- PRIMARY_VARIABLE: `PERSISTENCE_PROVIDER = JPA_ONLY`
- ALLOWED_PATHS (programa LB-008; la ejecución vigente JPA-04 se concreta en su sección):
  - `.claude/skills/uco-persistencia/SKILL.md`
  - `docs/work-items/LB-008-jpa-only-persistence-migration/**`
  - `docs/adr/ADR-003-jpa-only-persistence.md`
  - `docs/persistence/JDBC_TO_JPA.md`
  - `docs/testing/TESTING_STANDARD.md`
  - `docs/architecture/adapter-composition-standard.md`
  - `docs/baseline/LINEA_BASE.md`, `docs/baseline/TECHNICAL_DEBT.md` (solo registro de deuda y evidencia)
  - `docs/work-items/LB-004-stateless-serverless-readiness/PAUSE.md` (nuevo)
  - `src/main/java/**/infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/` (ProcedureResult, CanonicalProcedureResult, ProcedureResultMapper, ProcedureResultValidator)
  - `src/test/java/**/infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/` (mapper/validator)
  - `src/main/java/**/infrastructure/adapter/secondary/persistence/sqlserver/{jpa,core,support/mapping}/` y tests homólogos, únicamente para la microfase activa con DoR READY
  - `src/main/java/**/infrastructure/config/adapters/persistence/sqlserver/`, `src/main/resources/application*.yml` y tests homólogos, únicamente para retirar el runtime híbrido de Asistencia después de paridad certificada
- FORBIDDEN_PATHS: `schema/`, `migrations/`, SP, views, tables, functions, seeds del repo DB (READ ONLY); `src/main/java/**/application/**`, `**/domain/**`; controllers, DTO HTTP, OpenAPI, roles, Keycloak, SSE/realtime, MinIO, ClamAV, Azure, storage contracts; `src/main/resources/**` de runtime en JPA-00/01; `pom.xml` salvo que la microfase lo exija explícitamente; ArchUnit rules (no relajar).
- CONTRACTS: DB (SP/vistas, ver CONTRACT_MATRIX). HTTP/OpenAPI sin cambios.
- PROVIDERS: SQL Server (provider real), JPA/Hibernate como capacidad.
- EXTERNAL_ENVIRONMENT: SQL Server `gestionasistenciadb` con el freeze DB desplegado y gate DB PASS; baseline backend `-Pintegration` disponible pero **no verde** (ver VALIDATION).
- SECURITY_IMPACT: ninguno en JPA-00/01. RBAC y titularidad siguen en SP y Application.
- OBSERVABILITY_IMPACT: ninguno; el log de error conserva `operation` y `correlationId`.
- TEST_LEVEL_REQUIRED: unit (RED/GREEN), ArchUnit, OpenAPI conformance; **integración SQL Server obligatoria para certificar paridad antes de cualquier switch o retiro**.
- ROLLBACK: las correcciones de foundation no cambian el provider. Para JPA-01 commands, el baseline JDBC permanece solo durante la comparación controlada; si la paridad no certifica, no se activa ni se retira nada. Tras certificar cada command, el runtime de Asistencia queda JPA-only sin crear selectores/fallback nuevos.
- CONSUMERS: AsistenciaController / UseCases de asistencia (vía puerto `AsistenciaRepositoryPort`, sin cambios); frontend (sin cambios HTTP).
- STOP_CONDITIONS:
  - cualquier cambio de DB o de contrato;
  - `CONTRACT_CONFLICT` o `TEST_CONTRACT_CONFLICT` abierto en la parte migrada;
  - build base en rojo (TD-029 o nuevo);
  - intento de cambiar provider en runtime sin paridad SQL Server certificada;
  - necesidad de tocar Domain/Application para hacer pasar un test.

### Ejecución documental de cierre JPA-02A / preparación JPA-02B (2026-10-05)

- Change class: `DOCUMENTATION_ONLY`.
- ALLOWED_PATHS: `docs/**`; únicamente comentarios no funcionales de `pom.xml` y
  `src/main/resources/application.yml` cuando describan falsamente el bootstrap vigente.
- FORBIDDEN_PATHS: `src/main/java/**`, `src/test/java/**`, propiedades funcionales de
  `application*.yml`, dependencias/plugins/valores de `pom.xml`, `docker-compose*`, `infra/**`,
  repositorio DB y frontend.
- Alcance: cerrar documentalmente JPA-02A, posicionar LB-008 en JPA-02B, congelar sus siete
  commands, DoR/DoD, matriz transaccional y bloqueo DB acotado.
- No alcance: implementar JPA-02B, modificar adapters, tests, `EntityManager`,
  `TransactionOperations`, stored procedures, queries o runtime.

## Alcance

- Programa completo: JPA-00 a JPA-07 (ver microfases).
- Ejecuciones técnicas anteriores: cerraron **JPA-00**, **JPA-01 foundation**, **JPA-01 commands**,
  **JPA-02A**, **JPA-02B** y **JPA-03**. La ejecución vigente implementa exclusivamente
  **JPA-04 — CORE VIEW QUERIES**.

## No alcance

- Cambios en DB, schema, SP, vistas, seeds.
- Queries academic/authorization/reporting de JPA-05, catálogos/auditoría de JPA-06 y limpieza
  global de JPA-07.
- Retiro de `spring-boot-starter-jdbc` o de `CanonicalStoredProcedureExecutor` (JPA-07).
- `usp_consultar_grupos_paginado`, `SESSION_CONTEXT`, paginación (DR-010).
- Reescritura de LB-002 o LB-004 (LB-004 queda en PAUSE).
- Serverless/realtime/cloud.

## Microfases

| ID | Contenido | Estado |
|---|---|---|
| JPA-00 | Freeze LB-004, gobernanza, ADR-003, inventario JDBC, contract matrix, PLAN/TEST_PLAN/VALIDATION | **Completada en esta ejecución** (documental + baseline verde). |
| JPA-01 | Foundation común y los **cuatro** commands Asistencia: `usp_registrar_asistencias_sesion` (normalizar piloto LB-002), `usp_registrar_asistencia_estudiante_autonomo`, `usp_radicar_solicitud_revision_asistencia`, `usp_resolver_solicitud_revision_asistencia`. Excluye `registrarAsistencia(...)` (TD-009). | **PASS** (2026-10-05). Foundation PASS; commands PASS bajo `READY_WITH_APPROVED_BASELINE_EXCEPTION`; Asistencia `COMMANDS = JPA_ONLY`, `QUERIES = JPA_ONLY`. Evidencia en [VALIDATION](VALIDATION.md#ejecución-jpa-01-commands-2026-10-04--2026-10-05). |
| JPA-02A | **NORMALIZE JPA BOOTSTRAP**: bootstrap JPA estándar de Spring Boot (un solo EMF, `EntityManager` administrado, entity scanning), sin migrar nuevas verticales. | **PASS (causal, 2026-10-05).** `GLOBAL = NOT_GREEN_TD043` sin cambio. TM: `JdbcTransactionManager` → `JpaTransactionManager`, paridad `PersistenceTransactionParityIT` 3/3 en BEFORE y AFTER. Evidencia en VALIDATION. |
| JPA-02B | **CORE COMMANDS**: 4 commands de Sesión + 3 de Grupo sobre `EntityManager` + `createNativeQuery` + `ProcedureResultMapper` + `ProcedureResultValidator`. Inventario: #22, #23, #35 (parcial: los commands ya no usan `CanonicalStoredProcedureExecutor`). | **PASS_WITH_SCOPED_DB_BLOCKER (2026-10-05)**. Commands en JPA: Sesión 4/4, Grupo 3/3. Seis providers con paridad BEFORE = AFTER en SQL Server (11/11 líneas idénticas). `usp_registrar_estudiante_en_grupo_usuario_no_existente` en JPA con `DB_PROVIDER_STATUS = MISSING` (TD-043 OPEN). Global `NOT_GREEN_TD043`. Evidencia: [VALIDATION](VALIDATION.md#ejecución-jpa-02b--core-commands-2026-10-05). |
| JPA-03 | **ACADEMIC / USER COMMANDS**: comandos de asignaturas, periodos, cierre de periodo, coordinador, decano, plan de estudio y usuario. Inventario: #5, #6, #7, #8, #17 (comando), #25 (comando). | **PASS_WITH_SCOPED_DB_BLOCKER (2026-10-05)**. Código 8/8 JPA. Paridad de error 8/8 idéntica y paridad de éxito 6/6 con efectos DB idénticos (fixtures aislados, oráculo JDBC solo en test). `usp_registrar_o_actualizar_plan_estudio` y `usp_sincronizar_usuario` → `MISSING_DB_PROVIDER` (TD-043, caracterizados). Evidencia: [VALIDATION](VALIDATION.md#ejecución-jpa-03--cierre-de-jpa-03-2026-10-05) y [TEST_PLAN](TEST_PLAN.md#jpa-03--academic--user-commands). |
| JPA-04 | **CORE VIEW QUERIES**: lecturas de sesión, grupo, usuario, estudiante, docente, tipo de identificación, identidades y mappers asociados. Inventario: #20, #21, #22/#23/#25 (lectura), #24, #28, #30, #31, #32, #33, #34, #41. | **PASS / CLOSED (2026-10-05)**. Seis capabilities JPA-only; paridad SQL Server 6/6; JDBC core 0; global 43 → 29. |
| JPA-05 | **ACADEMIC / AUTHORIZATION / REPORTING QUERIES**: lecturas académicas, alcance institucional y reporte de asistencia. Inventario: #3, #4, #9–#14, #16, #18, #19, #26, #27, #29, #43, #44 y las lecturas de #5, #7, #8, #17. | **PASS / CLOSED (2026-10-05).** Academic 15/15 JPA, authorization JPA (una sentencia por decision docente/estudiante), reporting JPA, `DIRECT_JDBC_JPA05_SCOPE = 0`. `uv_estudiante_programa` alineada por DB (`EstudiantePrograma.id`). Evidencia en VALIDATION §JPA-05 CIERRE. `uv_auth_*` sigue fuera de alcance de LB-002.1. |
| JPA-06 | **CATALOGS + AUDIT + AUXILIARY PERSISTENCE**: catálogos de mensaje y parámetro (`uv_mensaje_usuario`, `uv_mensaje_tecnico`, `uv_parametro`) y configuración de catálogos (#1, #2, #40). Auditoría (#37, #39) y su decisión TD-010. `ParametroSqlServerAdapter` (#15) ya era JPA desde JPA-05. | **PASS / CLOSED (2026-10-06)** (auditoría OPCIÓN A, TD-010 RESOLVED). Catálogos: **PASS** (JPA, `CatalogJpaParityIT` 11/11 contra SQL Server). Auditoría: JPA (`AuditEventJpaRepository`, JPA-06B, OPCIÓN A). Ver [sección JPA-06](#jpa-06--catalogs--audit--auxiliary-persistence). |
| JPA-07 | **GLOBAL JDBC ERADICATION + FINAL VALIDATION**: soporte de procedimientos (#6–#9: `JdbcValueMapper`, `CanonicalProcedureResultMapper`, `CanonicalStoredProcedureExecutor`, `SqlServerProcedureSupportConfiguration`), retiro de `spring-boot-starter-jdbc` si ninguna necesidad real lo exige, y gates globales `DIRECT_JDBC_IN_SRC_MAIN = 0`. | **PASS / CLOSED (2026-10-06)**. `DIRECT_JDBC_IN_SRC_MAIN = 0`; soporte JDBC de procedimientos movido a `src/test` como baseline. Ver [sección JPA-07](VALIDATION.md). |

Asignación completa de los 44 archivos residuales y su patrón destino: [JDBC_RESIDUAL_INVENTORY](JDBC_RESIDUAL_INVENTORY.md). Ningún archivo queda sin microfase.

**Regla de alcance (decisión humana 2026-10-05):** `OUTSIDE_GOLDEN_PATH != OUTSIDE_JPA_MIGRATION`. La distinción Golden Path / no-Golden sirve para priorizar y para evidencia; no excluye ninguna clase de la migración. Toda persistencia productiva converge a JPA. Un acceso JDBC directo no migrado es `NO_MIGRADO_TODAVIA` con microfase asignada, nunca una excepción permanente.

Cada microfase: RED → GREEN → VALIDATE. Los commands y queries pueden migrar por separado. Ninguna microfase arrastra a otra.

## Archivos afectados por JPA-01 (estado cerrado)

EXISTENTES (comprobados):
- `infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/CanonicalProcedureResult.java` — modificado: implementa `ProcedureResult` y añade `getEstadoResultado()`; `isEstadoResultado()` se conserva para los llamadores actuales.
- `infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/CanonicalProcedureResultValidator.java` — retirado y sustituido por `ProcedureResultValidator`, desacoplado de la clase concreta y de cardinalidad.
- `infrastructure/adapter/secondary/persistence/sqlserver/jpa/AsistenciaJpaCommandPersistence.java` — patrón final `createNativeQuery` para los cuatro commands.
- `infrastructure/adapter/secondary/persistence/sqlserver/jpa/AsistenciaRepositoryJpaSqlServerAdapter.java` — único adapter runtime de Asistencia.
- `infrastructure/adapter/secondary/persistence/sqlserver/core/AsistenciaRepositorySqlServerAdapter.java` — retirado de `src/main`; el baseline vive únicamente como oráculo de test.
- `infrastructure/adapter/secondary/persistence/sqlserver/core/AsistenciaRepositoryHybridSqlServerAdapter.java` — retirado.
- `docs/baseline/LINEA_BASE.md`, `docs/baseline/TECHNICAL_DEBT.md`, `docs/persistence/JDBC_TO_JPA.md`, `docs/adr/ADR-002-jpa-incremental.md` (no modificado).

NUEVOS:
- `docs/adr/ADR-003-jpa-only-persistence.md`
- `docs/work-items/LB-004-stateless-serverless-readiness/PAUSE.md`
- `docs/work-items/LB-008-jpa-only-persistence-migration/{PLAN,TEST_PLAN,CONTRACT_MATRIX,VALIDATION}.md`
- `infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/ProcedureResult.java`
- `infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/ProcedureResultMapper.java`
- `infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/ProcedureResultValidator.java`
- `src/test/.../support/procedure/ProcedureResultMapperTest.java`
- `src/test/.../support/procedure/ProcedureResultValidatorTest.java`

RETIRADO EN JPA-01: `AsistenciaRepositoryHybridSqlServerAdapter`, selectores de Asistencia,
fallback JDBC de Asistencia y `JpaCapabilityRequiredCondition`.

PENDIENTE DE FASES POSTERIORES: `JdbcValueMapper`, `CanonicalStoredProcedureExecutor`, `*RowMapper`,
`AuditEventJdbcRepository` y demás JDBC residual — **cada uno solo cuando JPA-0x certifique su
reemplazo y no tenga consumidores.** Como evidencia histórica del corte JPA-01,
`SqlServerJpaAsistenciaQueryAdapterConfiguration` seguía pendiente; JPA-02A ya lo retiró y sustituyó
por el bootstrap estándar.

## Contratos y consumidores afectados

- DOMAIN / APPLICATION: sin cambios.
- HTTP / OPENAPI / SECURITY / REALTIME: sin cambios.
- PERSISTENCE: contratos de SP y vistas sin cambios. Mismatches documentados en [CONTRACT_MATRIX](CONTRACT_MATRIX.md) (TD-043).

## Riesgos y dependencias

| Riesgo | Mitigación |
|---|---|
| Integración global no verde por TD-043/TD-044 | Mantener `GLOBAL_GATE = NOT_GREEN_TD043`; JPA-02A ya cerró por su gate causal. En JPA-02B, TD-043 bloquea solo el command cuyo provider falta; no se declara el global como PASS. |
| `EXEC` con binding por nombre en SQL Server | La decisión humana fija `createNativeQuery` como TARGET. La baseline y paridad real certifican su comportamiento antes de retirar el piloto `StoredProcedureQuery`; si falla, se registra el bloqueo y se requiere una nueva decisión, no se abre un segundo patrón regular. |
| Atomicidad y ownership transaccional de los cuatro SP | Conservar la matriz command por command: batch `CONDITIONAL`, autónomo `NO`, radicar/resolver `YES`; `CURRENT_OUTER_TX = TARGET_OUTER_TX = NO`. TD-056 conserva la no atomicidad preexistente del autónomo. |
| Mismatches de SP (TD-043) | No se reemplazan por equivalencias inventadas. Cada capacidad queda bloqueada por su propio SP. |
| Auditoría con DML directo | `DECISION_REQUIRED` al equipo DB antes de JPA-06. |
| Dependencia del driver `mssql-jdbc` | Se conserva; es transporte de Hibernate. |
| **TRANSACTION MANAGER SEMANTICS** al activar el bootstrap estándar | JPA-02A certificó `JdbcTransactionManager` → `JpaTransactionManager` sobre el mismo DataSource. `PersistenceTransactionParityIT`: 3/3 BEFORE, 3/3 AFTER. JPA-02B debe preservar las fronteras transaccionales ya observadas, especialmente `TransactionOperations` de Grupo (`GrupoRepositorySqlServerAdapter`). No reabrir JPA-02A. |

### Matriz transaccional cerrada de JPA-01

| SP | SP_MANAGES_TRANSACTION | CURRENT_OUTER_TX | TARGET_OUTER_TX | PARITY |
|---|---|---|---|---|
| `dbo.usp_registrar_asistencias_sesion` | CONDITIONAL | NO | NO | YES |
| `dbo.usp_registrar_asistencia_estudiante_autonomo` | NO | NO | NO | YES |
| `dbo.usp_radicar_solicitud_revision_asistencia` | YES | NO | NO | YES |
| `dbo.usp_resolver_solicitud_revision_asistencia` | YES | NO | NO | YES |

## Test plan

Ver [TEST_PLAN](TEST_PLAN.md). JPA-01 cerró con **83/83 IT dirigidos PASS**. La cifra **73/73**
corresponde a la baseline histórica pre-switch; no es el gate final. La corrección del validator
agregó un RED específico que exige `ProcedureResult` (no `List<CanonicalProcedureResult>`) y la
implementación no modificó ese RED.

## Rollback y stop conditions

- JPA-01 está cerrado y su evidencia se conserva; esta ejecución documental no cambia runtime.
- Rollback de esta actualización: revertir únicamente los documentos y comentarios no funcionales
  modificados por esta ejecución, sin tocar el trabajo técnico previo ni restaurar
  selectores/fallback JDBC de Asistencia.
- `CONTRACT_CONFLICT` / `TEST_CONTRACT_CONFLICT` / `BLOCKED_BY_MISSING_EVIDENCE` relevantes: ver lista de bloqueos en VALIDATION y CONTRACT_MATRIX.

## Deuda conocida y validación manual

- TD-043 (3 SP inexistentes): OPEN / DEFERRED / PREEXISTING / SCOPED_BLOCKER. En JPA-02B bloquea
  solo la ejecución/certificación de un command de Grupo, no los otros seis commands.
- TD-044 (2 skips): OPEN / NON_BLOCKING; no bloquea JPA-02A.
- TD-010 (auditoría DML directo): ABIERTA, evidencia actualizada.
- TD-055 (JDBC directo residual en `src/main` durante LB-008): ABIERTA, registrada.
- TD-056: OPEN / PREEXISTING / NON_BLOCKING / DB CONTRACT-BEHAVIOR.
- TD-057: OPEN / HIGH / DB_OWNER / PREEXISTING / NON_CAUSAL_TO_JPA; JDBC y JPA presentan el mismo comportamiento.
- TD-004 (LB-004): PARTIAL, sin cambios.
- TD-029: CERRADA, verificada por el build de esta ejecución.
- Validación manual: ninguna nueva en JPA-00/01.

## Definition of Ready

- **JPA-00 (documental, `CONTRACT_ANALYSIS` + `DOCUMENTATION_ONLY`): READY.** Repositorios identificados y hashes/HEAD registrados; owner y consumidor identificados; sin secretos; capacidad de inspeccionar provider y consumer.
- **JPA-01 foundation (implementación no conectada): READY.** Build base verde (`clean verify` PASS antes del cambio); contrato de los 4 SP de Asistencia en estado MATCH (firma y SELECT canónico); TEST_PLAN con RED causal; sin `CONTRACT_CONFLICT` abierto en el alcance.
- **JPA-01 commands de Asistencia (switch a JPA): READY_WITH_APPROVED_BASELINE_EXCEPTION** (reemplaza `BLOCKED_BY_BASELINE_FAILURE` del 2026-10-04 primera ejecución; decisión de esta ejecución 2026-10-04).
  - `GLOBAL_BASELINE_GATE`: `clean verify -Pintegration` = **FAIL / NOT_GREEN_TD043**. No se oculta ni se declara PASS. Fallos: 6 (`SqlStoredProcedureContractIT`×3, `GrupoRepositorySqlServerIT`×2, `UsuarioPasswordHashSqlServerIT`×1) y 2 skips (`DocenteRepositorySqlServerIT`).
  - `PRE_SWITCH_BASELINE_TARGETED`: **73/73 PASS** en SQL Server real: `GoldenPathSqlStoredProcedureContractIT` 16/16, `AsistenciaRepositorySqlServerIT` 6/6, `AsistenciaCommandJpaParityIT` 21/21, `AsistenciaCommandTransactionBoundaryIT` 3/3, `AsistenciaCommandConcurrencyIT` 3/3, `AsistenciaCommandRealtimeIT` 3/3, `AsistenciaQueryJpaParityIT` 7/7, `JpaAttendanceStoredProcedureFeasibilityIT` 14/14 (`mvnw -Pintegration verify -Dit.test=…`, EXIT=0, 2026-10-04). Es evidencia histórica pre-switch, no el gate final.
  - `JPA01_CAUSAL_GATE`: **83/83 PASS** final, al añadir `AsistenciaCommandsSpParityIT` 10/10 para autónomo, radicar y resolver (2026-10-05).
  - `EXCEPCION_BASELINE_APROBADA` (requisito DoR "excepción aprobada y versionada en el work item"):
    - `TD-043`: `OPEN / DEFERRED`, clasificación `NON_GOLDEN_DB_CONTRACT_DRIFT`, `CAUSALITY: PREEXISTING` (demostrado en LB-002.1 sobre `HEAD` limpio `df66a67` sin cambios JPA: mismos 3+2+1 fallos), `GOLDEN_PATH_CONTINUITY: AUTHORIZED` por decisión humana registrada en [TD-043 §LB-002.1C](../../baseline/TECHNICAL_DEBT.md#td-043) (`NON-GOLDEN TD-043 REMEDIATION: DEFERRED · GOLDEN PATH ENGINEERING: AUTHORIZED TO CONTINUE`).
    - `TD-044`: skips conocidos, `NON_BLOCKING` (fuera del Golden Path; ninguno pertenece a las pruebas de la lista anterior).
    - `TD-043` no afecta a los cuatro commands de Asistencia: los tres SP ausentes (`usp_sincronizar_usuario`, `usp_registrar_o_actualizar_plan_estudio`, `usp_registrar_estudiante_en_grupo_usuario_no_existente`) no son invocados por ninguno de los cuatro SP de Asistencia (verificado por `grep` sobre `schema/stored-procedures/usp_registrar_asistencia*` y `usp_radicar/usp_resolver*`).
    - Aprobación: decisión humana del profesor en la sesión 2026-10-04 (instrucción "ejecutar JPA-01 COMMANDS si el DoR queda READY_WITH_APPROVED_BASELINE_EXCEPTION"). Sin ocultar: `GLOBAL_GATE: FAIL / TD-043`.
  - Alcance de esa excepción en el corte JPA-01: solo commands de Asistencia; no autorizó por sí
    misma fases posteriores ni cerró TD-043/TD-010. La readiness vigente de JPA-02B se decide por
    separado abajo y acota TD-043 al command afectado.
- **Resultado JPA-01:** **PASS**. Cuatro commands migrados; queries y commands de Asistencia
  `JPA_ONLY`; `StoredProcedureQuery`, JDBC directo y runtime híbrido de Asistencia = 0 en `src/main`;
  gate dirigido final **83/83 IT PASS**. `GLOBAL_GATE = NOT_GREEN_TD043` permanece visible.

## JPA-02A — NORMALIZE JPA BOOTSTRAP (PASS / HISTÓRICO)

### Objetivo y scope en el corte previo a implementar

Reemplazar el bootstrap manual/piloto JPA por el bootstrap estándar de Spring Boot JPA, sin migrar
todavía nuevas verticales. La implementación futura podrá afectar únicamente, con justificación:

- `AsistenciasUcoApplication`;
- `SqlServerJpaAsistenciaQueryAdapterConfiguration`;
- `SqlServerCoreRepositoryAdapterConfiguration`;
- cualquier residuo de `JpaCapabilityRequiredCondition`, si reapareciera o se comprobara existente;
- `application.yml` y `pom.xml` solo si son estrictamente requeridos;
- composición del transaction manager, lifecycle de `EntityManager` y entity scanning.

No abre JPA-02B ni commands de Sesión/Grupo/core. No exige `DIRECT_JDBC_GLOBAL = 0`.

### AS-IS previo a JPA-02A (histórico)

- `AsistenciasUcoApplication` excluye `HibernateJpaAutoConfiguration`,
  `HibernateMetricsAutoConfiguration` y `DataJpaRepositoriesAutoConfiguration`.
- `SqlServerJpaAsistenciaQueryAdapterConfiguration` construye manualmente un
  `LocalContainerEntityManagerFactoryBean`, registra tres entidades y fija propiedades Hibernate.
- Commands usan un shared `EntityManager`; queries abren/cierran un `EntityManager` desde el EMF.
- No existe bean explícito `PlatformTransactionManager` ni `JpaTransactionManager` en código
  productivo. `spring-boot-starter-jdbc` permanece y Boot suministra `TransactionOperations`;
  `GrupoRepositorySqlServerAdapter` es el consumidor productivo directo localizado.
- JDBC directo residual certificado: 44 archivos fuera de Asistencia.

### TARGET certificado

- Spring Boot standard JPA bootstrap.
- `EntityManagerFactory` administrado por Spring Boot.
- `EntityManager` como proxy administrado por Spring.
- `spring.jpa.open-in-view=false`.
- `spring.jpa.hibernate.ddl-auto=none`.
- dialecto SQL Server explícito si sigue siendo necesario.
- `hibernate.boot.allow_jdbc_metadata_access=false` si sigue siendo necesario para preservar el
  comportamiento de no conectar a DB al arranque.

El dialecto explícito, la desactivación de metadata JDBC y las naming strategies quedaron
verificados en la ejecución JPA-02A; ver VALIDATION.

### JPA-02A DEFINITION OF READY

**Estado (2026-10-05): PASS en gate causal.** Bootstrap JPA estándar implementado; `GLOBAL_INTEGRATION = NOT_GREEN_TD043`, idéntico al baseline previo. Evidencia completa en [VALIDATION](VALIDATION.md#ejecución-jpa-02a--normalize-jpa-bootstrap-2026-10-05).

- JPA-01 = PASS y Asistencia = JPA_ONLY.
- `clean verify` = PASS: 1358 tests, 0 fallos/errores/skips.
- targeted Asistencia = PASS: 83/83 IT.
- ArchUnit = PASS: 92 tests de arquitectura.
- OpenAPI = PASS: 12/12 (`9 + 2 + 1`).
- coverage = PASS: LINE 91.52 % y BRANCH 80.58 %, sobre los gates 80 % / 70 %.
- bootstrap AS-IS inventariado en esta sección.
- transaction manager AS-IS inventariado a nivel de wiring/consumidores; la implementación debe
  capturar el bean/tipo efectivo como `TRANSACTION_MANAGER_BEFORE` antes de cambiarlo.
- consumidores JDBC residuales inventariados: 44 archivos fuera de Asistencia; consumidor directo
  de `TransactionOperations` localizado: `GrupoRepositorySqlServerAdapter`.
- no existe regresión causal abierta de JPA-01.
- TD-043/TD-044 permanecen abiertos bajo la excepción versionada; TD-056/TD-057 son no bloqueantes
  para el bootstrap.

### Gates obligatorios de JPA-02A

- Comparación explícita `TRANSACTION_MANAGER_BEFORE` vs `TRANSACTION_MANAGER_AFTER`, incluyendo
  nombre/tipo de bean y efecto sobre `TransactionOperations`.
- Arranque sin regresión de conexión DB; validar si dialecto explícito y
  `hibernate.boot.allow_jdbc_metadata_access=false` siguen siendo necesarios.
- Lifecycle de `EntityManager`, entity scanning y composición de beans certificados.
- Asistencia continúa JPA_ONLY y los módulos JDBC fuera de alcance conservan comportamiento,
  especialmente `GrupoRepositorySqlServerAdapter`.
- `clean verify`, targeted integration Asistencia, ArchUnit, OpenAPI y coverage gates PASS.

### JPA-02A DEFINITION OF DONE

- bootstrap JPA estándar de Spring Boot activo;
- EMF manual del piloto retirado;
- shared `EntityManager` manual retirado;
- exclusiones de auto-configuración JPA retiradas donde sea seguro;
- sin regresión de conexión a DB en startup;
- Asistencia permanece JPA_ONLY;
- módulos JDBC fuera de alcance preservan comportamiento;
- semántica transaccional certificada con `TRANSACTION_MANAGER_BEFORE` vs
  `TRANSACTION_MANAGER_AFTER`;
- `clean verify`, integración dirigida, ArchUnit, OpenAPI y gates de coverage PASS.

`DIRECT_JDBC_GLOBAL = 0` no forma parte del DoD de JPA-02A; corresponde al cierre de LB-008.

- **JPA-02B:** `READY_WITH_SCOPED_DB_BLOCKER`; TD-043 se aplica solo al command de Grupo cuyo
  provider falta.
- **JPA-03:** los commands con `MISSING_IN_PROVIDER` conservan bloqueo acotado por capacidad.
- **JPA-06 auditoría: NOT_READY.** Motivo: `DECISION_REQUIRED` (owner: equipo DB).
- Aprobaciones: decisión humana del profesor registrada en la sesión 2026-10-03 (migración JPA-only; pausa LB-004). Pendiente: aprobación explícita del equipo DB para los puntos de TD-043 y auditoría.

## JPA-02B — CORE COMMANDS

### Estado y alcance autorizado

```text
JPA-02B STATUS: PASS_WITH_SCOPED_DB_BLOCKER (2026-10-05)
IMPLEMENTATION: DONE (commands 7/7 en JPA; 6 providers certificados; 1 bloqueado por TD-043)
PRIMARY_VARIABLE: PERSISTENCE_PROVIDER = JPA_ONLY
COMMANDS_TOTAL: 7
```

Puede ejecutarse como dos subverticales independientes para facilitar RED, GREEN, paridad,
rollback y cleanup, sin crear work items separados salvo que la gobernanza lo requiera:

- **JPA-02B.1 — SESIÓN COMMANDS:** `dbo.usp_crear_sesion`, `dbo.usp_actualizar_sesion`,
  `dbo.usp_cerrar_sesion`, `dbo.usp_generar_sesiones_grupo` (4/4 providers disponibles).
- **JPA-02B.2 — GRUPO COMMANDS:** `dbo.usp_crear_grupo` y `dbo.usp_actualizar_grupo`
  (providers disponibles); `dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente`
  (`MISSING / BLOCKED_TD043`).

Las queries sobre `dbo.uv_sesion` y `dbo.uv_grupo` no se migran en JPA-02B. Permanecen
temporalmente en JDBC y asignadas a JPA-04; no son una excepción permanente al TARGET JPA-only.

### Estado de código y provider DB

| Capability | CODE_MIGRATION_STATUS | DB_PROVIDER_STATUS | Regla |
|---|---|---|---|
| 4 commands de Sesión | `JPA_REQUIRED` | `AVAILABLE` | RED → GREEN → paridad SQL Server → retiro JDBC del command |
| `usp_crear_grupo` | `JPA_REQUIRED` | `AVAILABLE` | igual |
| `usp_actualizar_grupo` | `JPA_REQUIRED` | `AVAILABLE` | igual |
| `usp_registrar_estudiante_en_grupo_usuario_no_existente` | `JPA_REQUIRED` | `MISSING / BLOCKED_TD043` | no conservar JDBC como excepción, no inventar provider ni sustituir por `usp_registrar_estudiante_en_grupo`; documentar la ejecución real bloqueada hasta resolución DB |

TD-043 es un bloqueo por capacidad. No bloquea toda JPA-02B ni cambia la política
`OUTSIDE_GOLDEN_PATH != OUTSIDE_JPA_MIGRATION`: el Golden Path define prioridad, evidencia y orden;
todo acceso JDBC productivo sigue dentro de la migración obligatoria.

### Patrón obligatorio

Cada command converge, sin crear otro framework, a:

```text
Repository adapter de Infrastructure (`@Repository` role; bean registrado por Composition Root,
sin auto-registro por annotation)
→ EntityManager
→ createNativeQuery("EXEC dbo.usp_xxx …")
→ setParameter(...)
→ getResultList()
→ ProcedureResultMapper
→ ProcedureResultValidator
```

Se reutilizan `ProcedureResult`, `CanonicalProcedureResult`, `ProcedureResultMapper`,
`ProcedureResultValidator` y `DbExceptionTranslator`. Se prohíben `StoredProcedureQuery`, fallback
JDBC y selectores tecnológicos nuevos.

### TRANSACTION_MATRIX de entrada

Fuente: adapters actuales y scripts DB en `gestion-asistencia-db` `develop@f2871a9…`. `PARITY`
describe el estado antes de implementar JPA-02B; no es evidencia nueva de runtime.

| Command | SP_MANAGES_TRANSACTION | CURRENT_OUTER_TX | TARGET_OUTER_TX | PARITY |
|---|---|---|---|---|
| `usp_crear_sesion` | CONDITIONAL: propia sin outer tx; savepoint si existe | NO | NO, salvo evidencia RED/paridad que exija conservar otra frontera | NOT_RUN |
| `usp_actualizar_sesion` | NO | NO | NO, sujeto a paridad | NOT_RUN |
| `usp_cerrar_sesion` | NO | NO | NO, sujeto a paridad | NOT_RUN |
| `usp_generar_sesiones_grupo` | YES: `BEGIN/COMMIT/ROLLBACK` propio | NO | NO, sujeto a paridad | NOT_RUN |
| `usp_crear_grupo` | NO | YES (`TransactionOperations.execute`) | YES hasta demostrar si la frontera exterior es necesaria o accidental | NOT_RUN |
| `usp_actualizar_grupo` | NO | YES (`TransactionOperations.execute`) | YES hasta demostrar si la frontera exterior es necesaria o accidental | NOT_RUN |
| `usp_registrar_estudiante_en_grupo_usuario_no_existente` | UNKNOWN: provider ausente | YES (`TransactionOperations.execute`) | YES; no retirar automáticamente | BLOCKED_TD043 |

La implementación no elimina automáticamente la frontera Spring de
`GrupoRepositorySqlServerAdapter`. Debe demostrar command por command si la transacción exterior
es necesaria o accidental con el `JpaTransactionManager` vigente y registrar la decisión antes del
cleanup.

### Definition of Ready JPA-02B

**Resultado: `READY_WITH_SCOPED_DB_BLOCKER`.**

- JPA-02A PASS; bootstrap estándar Spring Boot PASS.
- `JpaTransactionManager` activo y `TRANSACTION_MANAGER_PARITY = PASS` (3/3 BEFORE, 3/3 AFTER).
- Asistencia commands + queries = JPA_ONLY.
- Último `clean verify` certificado = PASS; targeted JPA-02A = 37/37 PASS.
- ArchUnit, OpenAPI y coverage gates = PASS en la evidencia certificada de JPA-02A.
- 44 archivos JDBC residuales inventariados y asignados a microfase.
- siete commands JPA-02B identificados; seis providers disponibles y un bloqueo TD-043 acotado.
- `TEST_PLAN` define el RED y la paridad requeridos; ninguna implementación se inicia en esta
  ejecución documental.

### Definition of Done JPA-02B

- todos los commands elegibles de Sesión y Grupo usan JPA;
- los siete paths tienen `CODE_MIGRATION_STATUS = JPA_REQUIRED`; el command TD-043 queda sin
  fallback JDBC y con su ejecución/certificación real marcada `BLOCKED_TD043` mientras falte el SP;
- JDBC directo retirado de los command paths migrados, sin migrar todavía las queries de
  `uv_sesion`/`uv_grupo`;
- paridad funcional, de errores, efectos y transacciones certificada contra SQL Server para cada
  provider disponible;
- frontera exterior de los tres commands de Grupo decidida con evidencia y paridad;
- contrato común `ProcedureResult` reutilizado;
- `StoredProcedureQuery = 0` y `JDBC_FALLBACK = 0` en el alcance;
- `clean verify`, integración SQL Server dirigida, ArchUnit, OpenAPI y coverage gates PASS;
- integración global reportada honestamente, sin convertir `NOT_GREEN_TD043` en PASS;
- TD-043 documentado como bloqueo acotado del command afectado;
- conteo `DIRECT_JDBC_GLOBAL` recalculado después de implementar, sin estimarlo por adelantado.

## JPA-04 — CORE VIEW QUERIES

### Estado, alcance y rutas autorizadas

```text
JPA-04 STATUS: PASS / CLOSED (2026-10-05)
PRIMARY_VARIABLE: CORE_QUERY_PERSISTENCE_PROVIDER = JPA
DIRECT_JDBC_GLOBAL_BEFORE: 43
DIRECT_JDBC_GLOBAL_AFTER: 29
```

Capabilities: Sesión, Grupo, Usuario, Docente, Estudiante y TipoIdentificación. Incluye las vistas
`uv_sesion`, `uv_grupo`, `uv_estudiante_grupo`, `uv_usuario`, `uv_docente`,
`uv_docente_identidad`, `uv_estudiante`, `uv_estudiante_identidad` y
`uv_tipo_identificacion`. Incluye retirar los RowMapper sin consumidores del slice. No incluye
ninguna query academic/authorization/reporting de JPA-05.

Rutas permitidas de esta microfase:

- `src/main/java/**/infrastructure/adapter/secondary/persistence/sqlserver/core/**`;
- `src/main/java/**/infrastructure/adapter/secondary/persistence/sqlserver/jpa/**`;
- `src/main/java/**/infrastructure/adapter/secondary/persistence/sqlserver/support/mapping/**`,
  solo para retirar clases sin consumidores;
- `src/main/java/**/infrastructure/config/adapters/persistence/sqlserver/SqlServerCoreRepositoryAdapterConfiguration.java`;
- tests homólogos, `src/test/**/architecture/**` y oráculos JDBC solo en `src/test`;
- documentación activa de LB-008 y baseline/deuda.

Rutas prohibidas: Domain/Application, HTTP/OpenAPI, seguridad, realtime, storage, schema/SQL DB,
queries de JPA-05/06, `pom.xml` y configuración runtime. JPA-05 se prepara documentalmente, no se
implementa.

### Contrato e identidad de vistas

Fuente owner: `gestion-asistencia-db develop@f2871a9564d6c4cc5abc3745854414243bfda238`;
contraste live DB `gestionasistenciadb` del 2026-10-05 mediante `sys.columns`, `sys.types` y conteos
de duplicados. La matriz completa está en `CONTRACT_MATRIX.md`.

- ID simple `id`: sesión, grupo, estudiante-grupo, usuario, docente-identidad,
  estudiante-identidad y tipo-identificación; respaldado por PK de tabla base y sin duplicados live.
- `uv_docente`: `idGrupo` como identidad de fila proyectada; `Grupo.id` es PK y la vista produce una
  fila por grupo/docente en el contrato versionado; sin duplicados live.
- `uv_estudiante`: `@IdClass(id,idGrupo)`; sin duplicados live. El schema no declara una unique
  constraint estudiante–grupo, por lo que un duplicado futuro es stop condition
  `BLOCKED_BY_VIEW_IDENTITY`, no autorización para fabricar un ID.
- todas las entidades son `@Entity @Immutable`, planas y exclusivas de Infrastructure.

### Definition of Ready JPA-04

**Resultado: `READY`.**

- JPA-03 cerrado `PASS_WITH_SCOPED_DB_BLOCKER`; sus commands no se reabren.
- contrato DB versionado y DB viva disponibles; columnas, tipos, nulabilidad e identidad revisados;
- build/gates de entrada certificados en el cierre JPA-03 (`clean verify` PASS, coverage y ArchUnit
  PASS); la integración global conserva únicamente TD-043 preexistente;
- inventario exacto de adapters, métodos, vistas, RowMapper y helper realizado;
- TEST_PLAN JPA-04 congelado antes de implementación, con RED, paridad SQL Server, UTC, null,
  ordering y not-found;
- cero `CONTRACT_CONFLICT` o `TEST_CONTRACT_CONFLICT` abiertos en las queries migradas;
- rollback: no retirar JDBC productivo del slice hasta capturar baseline/paridad; el oráculo JDBC
  permanece solo en `src/test`.

### Stop conditions y DoD JPA-04

Stop conditions: identidad no estable, divergencia UTC/null/orden/not-found, necesidad de cambiar
Application/Domain/DB, o paridad SQL Server no certificable. El DoD exige las seis capabilities en
JPA, JDBC/RowMapper productivo del slice en cero, entities `@Immutable`, paridad dirigida PASS,
`clean verify`, ArchUnit, OpenAPI, coverage y `git diff --check` PASS. TD-043 y TD-058 permanecen
abiertas y no se reinterpretan.

### Cierre JPA-04

- Las seis capabilities core de lectura usan `EntityManager` y JPQL tipado; no existe fallback ni
  selector JDBC/JPA.
- Las nueve vistas están representadas por entidades planas `@Entity @Immutable`; la identidad
  compuesta de `uv_estudiante` permanece `(id,idGrupo)` y su stop condition sigue vigente.
- `CoreViewQueriesJpaParityIT`: 6/6 PASS contra SQL Server real, comparando JDBC BEFORE y JPA AFTER
  campo a campo, incluidos UTC, null, orden, paginación y not-found.
- Los siete `RowMapper` sin consumidores fueron retirados. `JdbcValueMapper` se conserva porque
  JPA-05 aún tiene lectores academic/reporting; no es consumidor del path core.
- `CORE_QUERY_DIRECT_JDBC = 0`; `DIRECT_JDBC_GLOBAL` baja de 43 a 29 archivos reales.
- `clean verify`: 1375/1375 PASS. Integración global: 159 tests, 6 fallos TD-043 preexistentes,
  2 skips TD-044; cero fallo causal JPA-04.
- JPA-03 queda congelada en su cierre anterior y no fue reabierta.
- Siguiente microfase recomendada: **JPA-05 — ACADEMIC / AUTHORIZATION / REPORTING QUERIES**,
  todavía `NOT_STARTED`; no se inicia automáticamente.

## JPA-06 — CATALOGS + AUDIT + AUXILIARY PERSISTENCE

### Estado inicial y resultado

- **Estado de apertura (2026-10-05):** `READY_WITH_SCOPED_DB_DECISION`. Catálogos listos; auditoría requiere TD-010.
- **Estado final de esta ejecución:** `NOT_CLOSED / BLOCKED_BY_TD010`.
  - Catálogos (#1, #2, #3 de `JDBC_RESIDUAL_INVENTORY`): **PASS**, JPA-only.
  - Auditoría (#4, #5): **`BLOCKED_BY_TD010_DECISION`**. No se implementa.
- **Regla:** JPA-06 solo cierra cuando la auditoría migre o TD-010 se resuelva. Catálogos PASS no cierra la microfase.

### Alcance autorizado y no alcance

- **Dentro:** `SqlServerMessageCatalogAdapter`, `SqlServerParameterCatalogAdapter`, `SqlServerCatalogAdapterConfiguration`,
  entidades `UvMensajeUsuarioEntity` y `UvMensajeTecnicoEntity` (nuevas), `CatalogJpaQueryPersistence` (nueva), `UvParametroEntity` (reutilizada).
- **Fuera:** auditoría (`AuditEventJdbcRepository`, `SqlServerAuditSupportConfiguration`) por TD-010; soporte de procedimientos
  (`JdbcValueMapper`, `CanonicalProcedureResultMapper`, `CanonicalStoredProcedureExecutor`, `SqlServerProcedureSupportConfiguration`)
  por JPA-07 (no migrar soporte muerto solo por número); `ParametroSqlServerAdapter` (ya JPA desde JPA-05).
- **DB:** sin cambios de schema, vistas ni SP. El repositorio DB no se modifica.

### Clasificación de los residuales de la lista esperada

| # | Clase | Clasificación | Decisión |
|---|---|---|---|
| 1 | `SqlServerMessageCatalogAdapter` | Catálogo, lectura | JPA-06 (migrado) |
| 2 | `SqlServerParameterCatalogAdapter` | Catálogo, lectura | JPA-06 (migrado) |
| 3 | `SqlServerCatalogAdapterConfiguration` | Wiring catálogo | JPA-06 (migrado) |
| 4 | `AuditEventJdbcRepository` | Auditoría (DML directo `INSERT`/`SELECT`) | JPA-06 bloqueado por TD-010 |
| 5 | `SqlServerAuditSupportConfiguration` | Wiring auditoría | JPA-06 bloqueado por TD-010 |
| 6 | `JdbcValueMapper` | Conversión `java.sql.*` → UTC; consumidor productivo: #7 | **JPA-07** (soporte, no JPA-06) |
| 7 | `CanonicalProcedureResultMapper` | RowMapper del ejecutor canónico | **JPA-07** |
| 8 | `CanonicalStoredProcedureExecutor` | `PRODUCTIVE_CONSUMERS = 0` | **JPA-07** (oráculo de test vivo: `CanonicalStoredProcedureExecutorTest`) |
| 9 | `SqlServerProcedureSupportConfiguration` | Bean sin consumidores | **JPA-07** |

Verificado con grep en `src/main`: `JdbcValueMapper` tiene un consumidor productivo (#7); `AcademicViewJpaProjectionMapper`
solo lo cita en Javadoc. `CanonicalStoredProcedureExecutor` solo lo instancia su bean (#9).

### Decisiones de planificación (requieren confirmación humana registrada)

- **D-JPA06-01 — Lectura sobre vistas, sin NOLOCK.** El AS-IS lee tablas base con `WITH (NOLOCK)`. El TARGET lee
  `uv_mensaje_usuario`, `uv_mensaje_tecnico` y `uv_parametro` sin hint. Efecto: lectura en `READ COMMITTED`, sin
  lecturas sucias. Riesgo: nulo en la práctica, porque los catálogos se escriben solo por seed o administración.
  **Pendiente de confirmación humana** antes de declarar la capacidad como `PASS` definitivo.
- **D-JPA06-02 — Reutilizar `UvParametroEntity`.** Su contrato (`id`, `grupo`, `clave`, `valor`, más columnas que el catálogo ignora)
  coincide con `uv_parametro`. No se crea `UvParametroCatalogEntity` (sería duplicada).
- **D-JPA06-03 — Cache sin cambio.** `ConcurrentHashMap` sin TTL ni límite; solo positivos; `clearCache()`. JPA no sustituye cache.
- **D-JPA06-04 — Auditoría bloqueada.** Ver TD-010 y [CONTRACT_MATRIX](CONTRACT_MATRIX.md#análisis-de-gobernanza-para-td-010-jpa-06-2026-10-05).
- **D-JPA06-05 — Tests unitarios de catálogo adaptados.** Los tests que mockeaban `NamedParameterJdbcTemplate` se reescribieron
  para mockear `CatalogJpaQueryPersistence`. Se conservan todas las aserciones de comportamiento (normalización, cache,
  not-found, null, traducción de errores, formato, `clearCache`). Es el mismo criterio de "adaptación declarada" de JPA-02B.

### Definition of Ready (JPA-06, catálogos)

| Criterio | Resultado |
|---|---|
| Clase de cambio | `PERSISTENCE_MIGRATION` |
| Rutas permitidas | `infrastructure/adapter/secondary/catalog/sqlserver/`, `infrastructure/adapter/secondary/persistence/sqlserver/jpa/`, `infrastructure/config/adapters/persistence/sqlserver/SqlServerCatalogAdapterConfiguration.java`, tests asociados |
| Build base verde | Sí. JPA-05 cerró con `clean verify` PASS; `TECHNICAL_BUILD_GATE` verde |
| Contrato DB | Vistas existentes en la DB viva (`sys.views`), columnas y nulabilidad iguales al repositorio. `codigo` y `(grupo, clave)` UNIQUE en tablas base |
| Conflictos contractuales | Ninguno. El AS-IS lee tablas; la vista añade solo `estaActivo = 1`, que el adapter ya aplicaba |
| Identidad | `id` (PK de la tabla base, expuesta por la vista) |
| Semántica NOLOCK | Cambio declarado: D-JPA06-01 (requiere confirmación humana) |
| Cache | Documentada y sin cambio: D-JPA06-03 |
| RED | Creado antes de implementar: `JpaCatalogRulesTest` (4 reglas). Ver VALIDATION |
| Provider real | SQL Server disponible (`localhost:1433`); paridad ejecutada, no `NOT_RUN` |
| Consumidores | `ResolverMensajeUsuarioUseCaseImpl` y wiring de catálogos (`CatalogoWiringConfiguration`); sin cambio de puerto |
| **Resultado catálogos** | **READY** (con D-JPA06-01 pendiente de confirmación humana) |

### Definition of Ready (JPA-06, auditoría)

| Criterio | Resultado |
|---|---|
| Cero `DECISION_REQUIRED` relevante | **NO**: TD-010 `DECISION_REQUIRED` |
| Autoridad que decida A o B | No existe en la gobernanza ni en la DB (ver CONTRACT_MATRIX) |
| **Resultado auditoría** | **NOT_READY → `BLOCKED_BY_TD010_DECISION`** |

### Stop conditions

- Si D-JPA06-01 se rechaza, mantener NOLOCK requiere `createNativeQuery` sobre tablas base. Eso contradice el patrón JPQL
  de catálogos; se devuelve a decisión humana antes de continuar.
- Un error causal nuevo en la integración (fuera de los 6 TD-043 conocidos) detiene el cierre.
- TD-010 resuelta sin decisión A/B explícita del owner DB: no se implementa auditoría.

### Rollback

Revertir `CatalogJpaQueryPersistence`, las dos entidades nuevas y los dos adapters a su versión JDBC (commit previo de
JPA-05, `0b7905c` más cambios de trabajo). No hay selector ni fallback que retirar: el cambio no introduce config nueva.

## JPA-06A — JPA Repository Architecture Simplification

### Identidad y decisión

- Fecha: 2026-10-05.
- Change class: `REFACTOR`.
- PRIMARY_VARIABLE: `JPA_REPOSITORY_ARCHITECTURE = DIRECT_ANNOTATED_REPOSITORY`.
- Decisión: `D-JPA06A-01`, versionada en [ADR-004](../../adr/ADR-004-jpa-repository-architecture.md).
- Objetivo: comportamiento y DB sin cambio; sustituir `Port -> delegating adapter -> command/query persistence -> EntityManager`
  por `Port -> @Repository XxxJpaRepository -> EntityManager`.

### AS-IS medido

| Métrica | BEFORE |
|---|---:|
| Clases relacionadas (adapters + command/query persistence + cinco configs) | 66 |
| LOC de esas clases | 4393 |
| Adapters delegadores | 27 |
| `*JpaCommandPersistence` | 9 |
| `*JpaQueryPersistence` | 25 |
| Beans manuales de repository | 27 |
| `*QueryRow` | 26 |

### Alcance autorizado

- Repositories JPA de Asistencia, Grupo, Sesión, Usuario, Docente, Estudiante, TipoIdentificación.
- Repositories académicos de Area, Asignatura, AsignaturaDocente, CierrePeriodo, Coordinador, Decano,
  EstudiantePrograma, Facultad, HorarioDocente, HorarioEstudiante, Institución, MateriaEstudiante, Parámetro,
  PeriodoAcadémico, PlanEstudio y SesionMateriaEstudiante.
- InstitutionalScope, ReporteAsistencia y catálogos SQL Server.
- Configuraciones manuales equivalentes, tests de wiring/nombres/arquitectura y documentación activa.
- Revisión de los 26 QueryRow; solo se conservan resultados compuestos reales.

ALLOWED_PATHS: `docs/adr/**`, los documentos normativos de arquitectura/persistencia afectados,
`docs/work-items/LB-008-jpa-only-persistence-migration/**`, `docs/baseline/{LINEA_BASE,TECHNICAL_DEBT}.md`,
`src/main/java/**/infrastructure/adapter/secondary/{persistence,catalog}/**`,
`src/main/java/**/infrastructure/config/adapters/persistence/sqlserver/**`, tests homólogos y `architecture/**`.

FORBIDDEN_PATHS: Domain/Application, controllers, DTO HTTP, OpenAPI, seguridad, realtime, DB/schema/SP/views,
transacciones funcionales, timezone, null semantics y ordering. Auditoría/TD-010 y JPA-07 quedan fuera.

### Matriz de capacidades

| CAPABILITY | APPLICATION_PORT | CURRENT_CHAIN | TARGET_REPOSITORY | TRANSACTION_REQUIREMENTS |
|---|---|---|---|---|
| Asistencia | `AsistenciaRepositoryPort` | adapter + command/query | `AsistenciaJpaRepository` | sin outer tx |
| Grupo | `GrupoRepositoryPort` | adapter + command/query | `GrupoJpaRepository` | conservar `TransactionOperations` en 3 commands |
| Sesión | `SesionRepositoryPort` | adapter + command/query | `SesionJpaRepository` | sin outer tx |
| Usuario | `UsuarioRepositoryPort` | adapter + command/query | `UsuarioJpaRepository` | sin outer tx; TD-043 intacta |
| Docente | `DocenteRepositoryPort` | adapter + query | `DocenteJpaRepository` | lectura |
| Estudiante | `EstudianteRepositoryPort` | adapter + query | `EstudianteJpaRepository` | lectura |
| TipoIdentificación | `TipoIdentificacionRepositoryPort` | adapter + query | `TipoIdentificacionJpaRepository` | lectura |
| Asignatura | command + query ports | adapter + command/query | `AsignaturaJpaRepository` | sin outer tx |
| Coordinador | command + query ports | adapter + command/query | `CoordinadorJpaRepository` | sin outer tx |
| Decano | command + query ports | adapter + command/query | `DecanoJpaRepository` | sin outer tx |
| PlanEstudio | command + query ports | adapter + command/query | `PlanEstudioJpaRepository` | sin outer tx; TD-043 intacta |
| Resto académico | port por capability | adapter + query/command | `XxxJpaRepository` | lectura o frontera existente |
| InstitutionalScope | `InstitutionalScopePort` | adapter + query | `InstitutionalScopeJpaRepository` | una sentencia en decisiones docente/estudiante |
| ReporteAsistencia | `ReporteAsistenciaQueryPort` | adapter + query | `ReporteAsistenciaJpaRepository` | lectura |
| Catálogos | message/parameter ports | 2 adapters + query | repositories separados por selector independiente | cache y semántica JPA-06 intactas |

### DoR JPA-06A

**Resultado: READY.** La decisión humana resuelve la contradicción normativa previa y queda versionada como
ADR-004/D-JPA06A-01. JPA-06 catálogos está certificada; auditoría queda explícitamente fuera. El build de entrada
es el `clean verify` JPA-06 (1368/1368 PASS) y no existe conflicto contractual funcional. TEST_PLAN/RED estructural
se congela antes de producción. SQL Server real está disponible para reejecutar paridad; TD-043/TD-044 son bloqueos
preexistentes acotados y no se presentan como PASS global.

### Riesgos, rollback y stop conditions

- Riesgo: beans duplicados; gate obligatorio de exactamente una implementación por port.
- Riesgo: perder frontera de Grupo; se conserva `TransactionOperations`, sin sustituirlo por `@Transactional`.
- Riesgo: mover SQL/JPQL altera strings; se copian sin cambio y las paridades existentes son oráculo.
- Rollback: revertir únicamente el delta JPA-06A; DB no cambia.
- Stop: cambio de contrato, necesidad de tocar Application/Domain, divergencia de paridad o fallo causal nuevo.

### DoD JPA-06A

Todos los repositories productivos del alcance llevan `@Repository`, implementan ports directamente, contienen
`EntityManager`, no usan JDBC/java.sql, no exponen entities; adapters/wrappers/beans manuales redundantes quedan en
cero; QueryRow 1:1 se retiran; comportamiento, transacciones, UTC, autorización, reporte y catálogo conservan paridad;
`clean verify`, SQL Server dirigido, ArchUnit, OpenAPI, cobertura y `git diff --check` deben pasar. JPA-06A no cierra
JPA-06 ni inicia JPA-06B/JPA-07.

### Cierre JPA-06A (2026-10-06)

Resultado: **PASS / CLOSED**. Evidencia: [VALIDATION](VALIDATION.md#jpa-06a--ejecución-y-cierre-2026-10-06).

- Gates: clean verify PASS (1269 tests, 0 fallos/errores/skips); paridad SQL Server 86/86 PASS; ArchUnit PASS;
  OpenAPI PASS; cobertura LINE 81.96 % / BRANCH 74.53 % PASS; `git diff --check` PASS.
- Integración global `NOT_GREEN_TD043`: 6 fallos, todos de los 3 SP de TD-043; 0 fallos causales de JPA-06A.
- Enmienda técnica: repositories `public class` (no `final`) por proxy CGLIB de `@Repository`; ver
  [ADR-004](../../adr/ADR-004-jpa-repository-architecture.md#enmienda-de-implementación-2026-10-06-repositories-no-final).
- JPA-06 sigue `NOT_CLOSED / BLOCKED_BY_TD010`. JPA-06B no iniciado.
