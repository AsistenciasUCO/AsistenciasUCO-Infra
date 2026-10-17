# VALIDATION — LB-008 (JPA-00, JPA-01, JPA-02A y preparación documental JPA-02B)

Fecha de actualización: 2026-10-05. Entorno: Windows 11, PowerShell, JDK 25.0.2. Sin commit ni push.

## Identidad del estado

| Campo | Valor |
|---|---|
| BRANCH | `jose-valencia/lb-004-stateless-serverless-readiness` |
| HEAD | `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d` |
| WORKTREE_DIRTY_BEFORE | 33 entradas. Incluían trabajo válido de LB-004/LB-008, storage, seguridad y documentación; no se descartó, limpió, stasheó ni reordenó. |
| WORKTREE_DIRTY_AFTER | 50 entradas. Incluye las 33 iniciales y los cambios/nuevos archivos de governance y foundation; conserva íntegro el trabajo previo. |
| Repo DB | `gestion-asistencia-db`, rama `develop`, HEAD `f2871a9564d6c4cc5abc3745854414243bfda238`, limpio |
| Snapshot backend ZIP | `2fc9be69…191289`: BASE_SNAPSHOT verificado y no reemplazado |
| DB_SNAPSHOT_EXPECTED | `acccb378a92b7fbda2024e7cd639055ae498fa48ea7261f6b8db1e941ad735a6` |
| DB_SNAPSHOT_ACTUAL | `acccb378a92b7fbda2024e7cd639055ae498fa48ea7261f6b8db1e941ad735a6` |
| DB_SNAPSHOT_HASH | **MATCH / VERIFICADO** |

## Preflight y governance

- Leídos: AGENTS, CLAUDE, skills uco-persistencia/uco-baseline/uco-arquitectura/uco-testing,
  SOURCE_OF_TRUTH, DoR, ADR-002/003, JDBC_TO_JPA, LINEA_BASE, TECHNICAL_DEBT, TESTING_STANDARD,
  adapter-composition-standard, PLAN/TEST_PLAN/CONTRACT_MATRIX/VALIDATION y runbooks aplicables.
- ADR-003 queda como TARGET; ADR-002 se conserva como historia del piloto LB-002.
- El `java` por defecto es 17; todos los comandos Maven válidos se ejecutaron con
  `JAVA_HOME=C:\Users\josev\.jdks\jbr-25.0.2`.
- No se inspeccionaron ni imprimieron secretos de `.env`.

## Foundation RED → GREEN

### Mapper

```text
.\mvnw.cmd -q test "-Dtest=ProcedureResultMapperTest"
RED: EXIT=1, cannot find symbol sobre ProcedureResult / ProcedureResultMapper
```

### Validator desacoplado

```text
.\mvnw.cmd test "-Dtest=ProcedureResultValidatorTest"
RED: EXIT=1, cannot find symbol sobre ProcedureResultValidator
SHA-256 del RED aprobado:
a4ad6346fe1a10751cd047c7f6481bc609c25b838d67e3d4c8be19f70228457a
```

El test usa únicamente la interfaz `ProcedureResult`; no instancia ni referencia
`CanonicalProcedureResult`. La implementación reemplaza al validator histórico que recibía
`List<CanonicalProcedureResult>`.

### GREEN dirigido

```text
.\mvnw.cmd test "-Dtest=ProcedureResultMapperTest,ProcedureResultValidatorTest,CanonicalStoredProcedureExecutorTest,AsistenciaJpaCommandPersistenceTest"
BUILD SUCCESS
Tests run: 75, Failures: 0, Errors: 0, Skipped: 0
  ProcedureResultMapperTest: 11
  ProcedureResultValidatorTest: 19
  CanonicalStoredProcedureExecutorTest: 6
  AsistenciaJpaCommandPersistenceTest: 39
```

Durante el GREEN se detectó `TEST_CONTRACT_CONFLICT` en expectativas históricas del piloto: dos
casos aceptaban BIT como texto y un UUID inválido se esperaba como fallo técnico. Se resolvió contra
el contrato explícito vigente (BIT `Boolean`/`Number` 0/1; UUID inválido =
`ERR_DB_CANONICAL_CONTRACT`) sin modificar el RED de foundation.

## SQL Server y freeze DB

SQL Server estuvo disponible; no fue necesario resetear ni recrear la DB:

```text
Container: sql_server_asistencias
Image: mcr.microsoft.com/mssql/server:2022-latest
Port: localhost:1433
Database: gestionasistenciadb
Edition/version observada por Hibernate: SQL Server 16.0 / Developer
```

Gate oficial del repositorio DB:

```text
.\test_summary.ps1 -ContainerName sql_server_asistencias
EXIT=0 / DB GATE PASS
Public SP: 28/28
Views: 55/55
Expected: 154; executed: 157; passed: 156; failed: 0
Skipped: 1 permitido; unauthorized skips: 0; critical missing: 0
SQLCMD exit: 0; SQL errors: 0; @@TRANCOUNT final: 0
```

## Baseline backend SQL Server (histórico pre-switch)

El script oficial `scripts/test-local.ps1` carga los selectores del `.env` y produjo 13 fallos de
unitarias de composition root por contaminación de configuración. No se utilizó ese resultado como
dictamen del código.

La medición válida cargó el entorno local, eliminó **solo del proceso** los dos overrides de selector
y ejecutó el comando requerido:

```text
. .\scripts\load-env.ps1
Remove-Item Env:APP_ADAPTERS_PERSISTENCE_ASISTENCIA_QUERY_PROVIDER
Remove-Item Env:APP_ADAPTERS_PERSISTENCE_ASISTENCIA_COMMAND_PROVIDER
.\mvnw.cmd clean verify -Pintegration

EXIT=1 / BUILD FAILURE (Failsafe)
Unit: 1472 tests, 0 failures, 0 errors, 0 skipped
Integration: 118 tests, 6 failures, 0 errors, 2 skipped
Coverage check: PASS
LINE: 91.71 % (7959/8678)
BRANCH: 81.10 % (1837/2265)
```

Fallos de baseline, todos anteriores a la implementación de los cuatro commands TARGET:

1. `SqlStoredProcedureContractIT`: 3 fallos por SP inexistentes ya inventariados en TD-043:
   `usp_sincronizar_usuario`, `usp_registrar_o_actualizar_plan_estudio` y
   `usp_registrar_estudiante_en_grupo_usuario_no_existente`.
2. `GrupoRepositorySqlServerIT`: 2 fallos en registro de estudiante/rollback por el SP ausente.
3. `UsuarioPasswordHashSqlServerIT`: 1 fallo en creación de usuario.
4. `DocenteRepositorySqlServerIT`: 2 skips.

Evidencia independiente que sí quedó verde dentro de ese run:

- `GoldenPathSqlStoredProcedureContractIT`: 16/16.
- `AsistenciaRepositorySqlServerIT`: 6/6.
- piloto `AsistenciaCommandJpaParityIT`: 21/21.
- piloto `AsistenciaCommandTransactionBoundaryIT`: 3/3.
- piloto `AsistenciaCommandConcurrencyIT`: 3/3.
- `AsistenciaCommandRealtimeIT`: 3/3.
- `AsistenciaQueryJpaParityIT`: 7/7.
- `JpaAttendanceStoredProcedureFeasibilityIT`: 14/14.

Estos PASS parciales no sustituyen el gate global: la instrucción exige baseline completa verde antes
de iniciar runtime JPA-01. Dictamen: **`BLOCKED_BY_BASELINE_FAILURE`**.

## Gates finales de foundation (histórico pre-switch)

| Gate | Resultado |
|---|---|
| Unit dirigido foundation | PASS, 75/75, 0 skips |
| SQL Server / DB freeze | AVAILABLE / DB GATE PASS |
| `clean verify -Pintegration` | FAIL, 1472 unit PASS; 118 IT con 6 fallos y 2 skips |
| `clean verify` sin integración | PASS: 1472 tests, 0 fallos/errores/skips; LINE 88.64 %, BRANCH 79.21 % |
| JaCoCo del run integración | LINE 91.71 %, BRANCH 81.10 %, umbrales satisfechos |
| ArchUnit | 91/91 PASS |
| OpenAPI/Swagger runtime | 16/16 PASS |
| `git diff --check` | PASS, exit 0, sin salida |

## Dictamen (primera ejecución 2026-10-04 — HISTÓRICO, reemplazado por la sección final)

| Microfase | Dictamen |
|---|---|
| JPA-00 | **PASS**: governance y documentación alineadas con ADR-003; snapshot DB MATCH. |
| JPA-01 foundation | **PASS**: contrato común, mapper y validator desacoplado con RED→GREEN. El piloto existente consume la foundation sin cambiar de provider. |
| JPA-01 commands Asistencia a patrón final | **OBSERVACIÓN INICIAL SUPERADA.** La primera corrida pausó el switch por el gate global; la excepción versionada posterior autorizó continuar y la sección final certifica JPA-01 PASS. |
| JPA-02B/03 | **DICTAMEN HISTÓRICO DEL PRIMER CORTE:** faltaba resolver/acotar TD-043. Para JPA-02B queda reemplazado por `READY_WITH_SCOPED_DB_BLOCKER` en la sección vigente final. |
| JPA-06 auditoría | **DECISION_REQUIRED** (TD-010). |
| LB-008 global | **NO cerrada**. JDBC/híbrido/selectores heredados permanecen. |

## Métricas de runtime sin cambio (histórico pre-switch, reemplazado por JPA-01 COMMANDS)

| Gate | Valor |
|---|---|
| DIRECT_JDBC_IN_SRC_MAIN | 45 archivos reales (baseline) |
| HYBRID_JDBC_JPA_RUNTIME | 1 (`AsistenciaRepositoryHybridSqlServerAdapter`) |
| JDBC_FALLBACK_RUNTIME | 1 (heredado de LB-002) |
| JDBC_PROVIDER_SELECTOR | 2 (heredados de LB-002) |
| ASISTENCIA_STORED_PROCEDURE_QUERY_PILOT | 1 (no se retira sin DoR/paridad del patrón final) |

## Limitaciones y siguiente desbloqueo

1. Corregir o resolver contractualmente los 6 fallos y revisar los 2 skips de la baseline de
   integración; repetir `clean verify -Pintegration` hasta PASS.
2. Solo entonces crear RED de los cuatro commands, implementar `createNativeQuery`, certificar
   paridad command por command y retirar JDBC/híbrido/selectores de Asistencia.
3. En ese corte histórico no se inició la siguiente microfase. La recomendación entonces era
   **JPA-02A — NORMALIZE JPA BOOTSTRAP**; la ejecución posterior documentada abajo la cerró en PASS.

---

## Ejecución JPA-01 COMMANDS (2026-10-04 → 2026-10-05)

Sin commit ni push. Sin cambios en DB, SP, vistas, schema, OpenAPI, HTTP, frontend, SSE, Keycloak ni Azure.

### Identidad

```text
BRANCH:          jose-valencia/lb-004-stateless-serverless-readiness
HEAD:            0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d
WORKTREE_BEFORE: 50 entradas (git status --short al inicio de esta ejecución)
WORKTREE_AFTER:  88 entradas. Unas 38 corresponden a archivos tocados en esta ejecución (ver FILES_*);
                 el resto es trabajo previo de LB-004/LB-008/storage/ClamAV, preservado sin cambios.
```

### DoR

```text
DOR_PREVIOUS:           BLOCKED_BY_BASELINE_FAILURE (primera ejecución 2026-10-04)
DOR_UPDATED:            READY_WITH_APPROVED_BASELINE_EXCEPTION
DOR_EXCEPTION_SOURCE:   PLAN.md, sección "Definition of Ready" (JPA-01 commands). Fuente de la excepción:
                        TECHNICAL_DEBT.md TD-043 §LB-002.1C (GOLDEN PATH ENGINEERING: AUTHORIZED TO CONTINUE)
                        y TD-044 (NON_BLOCKING). Aprobación: decisión humana del profesor en la sesión 2026-10-04.
TD043_STATUS:           OPEN / DEFERRED (no cerrada). CAUSALITY: PREEXISTING. GOLDEN_PATH_CONTINUITY: AUTHORIZED.
TD044_STATUS:           ABIERTA, skips conocidos, NON_BLOCKING (DocenteRepositorySqlServerIT, 2 skips).
```

### Baselines

```text
GLOBAL_INTEGRATION_BASELINE: NOT_GREEN_TD043
  clean verify -Pintegration (2026-10-05): 125 IT, 6 fallos, 2 skips.
  Fallos (idénticos al conjunto de TD-043; ningún fallo nuevo):
    SqlStoredProcedureContractIT x3 (usp_sincronizar_usuario, usp_registrar_o_actualizar_plan_estudio,
                                     usp_registrar_estudiante_en_grupo_usuario_no_existente)
    GrupoRepositorySqlServerIT x2 · UsuarioPasswordHashSqlServerIT x1
  Skips (TD-044): DocenteRepositorySqlServerIT x2.
GLOBAL_GATE:                 FAIL / TD-043 (no se declara PASS)
JPA01_CAUSAL_GATE:           PASS
JPA01_TARGETED_BASELINE:     PASS: 83/83 ITs, 0 fallos, 0 skips, sobre SQL Server real:
  GoldenPathSqlStoredProcedureContractIT 16/16 · AsistenciaRepositorySqlServerIT 6/6 ·
  AsistenciaCommandJpaParityIT 21/21 · AsistenciaCommandsSpParityIT 10/10 (nuevo) ·
  AsistenciaCommandTransactionBoundaryIT 3/3 · AsistenciaCommandConcurrencyIT 3/3 ·
  AsistenciaCommandRealtimeIT 3/3 · AsistenciaQueryJpaParityIT 7/7 · JpaAttendanceStoredProcedureFeasibilityIT 14/14
```

### Transacciones

Matriz completa en [CONTRACT_MATRIX, sección Transacciones](CONTRACT_MATRIX.md#transacciones), verificada contra los scripts reales del repo DB:

```text
usp_registrar_asistencias_sesion              SP_MANAGES_TRANSACTION = CONDICIONAL (propia si no hay externa)  CURRENT=NO TARGET=NO PARITY=YES
usp_registrar_asistencia_estudiante_autonomo  SP_MANAGES_TRANSACTION = NO                                       CURRENT=NO TARGET=NO PARITY=YES
usp_radicar_solicitud_revision_asistencia     SP_MANAGES_TRANSACTION = YES (BEGIN/COMMIT/ROLLBACK propios)      CURRENT=NO TARGET=NO PARITY=YES
usp_resolver_solicitud_revision_asistencia    SP_MANAGES_TRANSACTION = YES (BEGIN/COMMIT/ROLLBACK propios)      CURRENT=NO TARGET=NO PARITY=YES
```

Ningún command recibe `@Transactional` ni `EntityTransaction`. La afirmación de atomicidad del autónomo queda como **TD-056** (no bloquea).

### RED → GREEN

```text
RED_EXPECTED:  tests que fijan el patrón final (EntityManager + createNativeQuery("EXEC ...") + binding nombrado
               + getResultList + ProcedureResultMapper + ProcedureResultValidator, sin StoredProcedureQuery ni JDBC):
               AsistenciaJpaCommandNativeQueryPatternTest (9) y AsistenciaCommandsSpParityIT (10).
RED_OBSERVED:  test-compile → EXIT=1. Errores "cannot find symbol" e "incompatible types: EntityManager cannot be
               converted to EntityManagerFactory" sobre AsistenciaJpaCommandPersistence (constructor y los cuatro
               métodos). Fallo causal: la clase aún era el candidato con StoredProcedureQuery.
GREEN:         AsistenciaJpaCommandNativeQueryPatternTest 9/9 · ProcedureResultMapperTest 11/11 ·
               ProcedureResultValidatorTest 19/19 · JpaCommandIsolationRulesTest 10/10 · JpaIsolationRulesTest 6/6 ·
               AsistenciaCommandsSpParityIT 10/10 contra SQL Server real.
```

Correcciones de test declaradas (ninguna aserción de comportamiento se debilitó):

1. **Helper de fila del RED** (`AsistenciaJpaCommandNativeQueryPatternTest`): `List.of(new Object[]{...})` se resuelve como varargs y aplana la fila en 4 elementos. Se sustituyó por `Collections.singletonList(...)`. Es el mismo error de helper ya documentado en la foundation.
2. **Caracterización de estado** (`AsistenciaCommandsSpParityIT`: RAD_01, RES_01, RES_02): la primera ejecución demostró que el catálogo `dbo.Estado` desplegado solo tiene `A` y `R`. Los SP caen a `TOP 1 ORDER BY id` y toda solicitud queda en `A`. JDBC y JPA coinciden (paridad OK); la aserción absoluta `APRO` era incorrecta. Se fijó como **caracterización explícita** que cita **TD-057**, no como contrato.

### Runtime y composición (estado final)

```text
COMMANDS = JPA_ONLY   (4 de 4 en AsistenciaJpaCommandPersistence, createNativeQuery "EXEC")
QUERIES  = JPA_ONLY   (AsistenciaJpaQueryPersistence; el JDBC de consulta se retiró)
PERSISTENCE_PROVIDER ASISTENCIA = JPA_ONLY
```

```text
PROCEDURE_RESULT_INTERFACE:   ProcedureResult (contrato sin cambios; la implementa CanonicalProcedureResult)
PROCEDURE_RESULT_MAPPER:      ProcedureResultMapper.mapSingle(List<?>): cardinalidad, 4 columnas, UUID, String, BIT
PROCEDURE_RESULT_VALIDATOR:   ProcedureResultValidator.validate(ProcedureResult, UUID, operation): recibe el resultado único
MIGRATED_COMMANDS:            registrarAsistenciasSesion, registrarAsistenciaAutonoma,
                              solicitarRevisionAsistencia, resolverSolicitudRevisionAsistencia
STORED_PROCEDURE_QUERY_REMAINING_IN_ASISTENCIA: 0 en src/main (0 en runtime).
                              En src/test quedan 3 archivos con referencias: JpaAttendanceStoredProcedureFeasibilityIT
                              (evidencia histórica LB-002), JpaCommandIsolationRulesTest (regla que lo prohíbe) y
                              AsistenciaJpaCommandNativeQueryPatternTest (verify never()).
DIRECT_JDBC_REMAINING_IN_ASISTENCIA: 0 en src/main (paquete jpa de Asistencia y adapters de Asistencia).
                              En src/test existe 1 oráculo: AsistenciaJdbcBaselineOracle (decisión D-3).
HYBRID_RUNTIME_REMAINING_IN_ASISTENCIA: 0 (AsistenciaRepositoryHybridSqlServerAdapter retirado).
SELECTORS_REMAINING:          0 (asistencia-query-provider / asistencia-command-provider retirados de application*.yml
                              y de .env.example; el .env local no se modificó).
```

### Paridad (SQL Server real)

```text
PARITY:             10/10 (3 commands no batch, JDBC oracle vs JPA, mismos inputs y mismos efectos DB) + 21/21 batch
TRANSACTION_PARITY: batch: AsistenciaCommandTransactionBoundaryIT 3/3 (rollback del lote).
                    autónomo/radicar/resolver: rechazos funcionales (código inválido, estudiante ajeno,
                    docente no titular, solicitud inexistente, usuario ejecutor nulo) con paridad de excepción y
                    CERO escrituras.
                    LIMITACIÓN: no se forzó un fallo técnico intermedio en los tres SP. El rollback técnico de
                    radicar y resolver no queda certificado por IT en esta ejecución.
CONCURRENCY:        AsistenciaCommandConcurrencyIT 3/3 (batch)
REALTIME:           AsistenciaCommandRealtimeIT 3/3 (batch)
```

### Gates finales

```text
MVN_CLEAN_VERIFY:  clean verify → EXIT=0 · tests 1358 · fallos 0 · errores 0 · skips 0
TESTS:             unitarios 1358 PASS (incluye ArchUnit y OpenAPI)
SKIPS:             unitarios 0 · integración 2 (TD-044, existentes). Ningún skip nuevo.
LINE_COVERAGE:     91.52 % (7871/8600) · umbral >= 80 % → PASS (JaCoCo del run -Pintegration)
BRANCH_COVERAGE:   80.58 % (1797/2230) · umbral >= 70 % → PASS
ARCHUNIT:          92 tests de arquitectura PASS (JpaCommandIsolationRulesTest 10/10, JpaIsolationRulesTest 6/6)
OPENAPI:           OpenApiGoldenPathConformanceTest 9/9 · OpenApiGoldenPathValidationTest 2/2 · SwaggerUi 1/1 PASS
GIT_DIFF_CHECK:    exit 0 (único aviso: fin de línea CRLF de .env.example; no es error de espacios)
```

Comparación con la primera ejecución: `clean verify` sin integración pasó de 1472 a 1358 tests. La diferencia se explica por 12 clases de test retiradas que probaban selectores, híbrido, JDBC del command y el patrón `StoredProcedureQuery` del piloto (ver FILES_DELETED). Se añadieron 9 tests de patrón y 10 de paridad en integración.

### Decisiones de esta ejecución (revisar)

- **D-1: `JpaCapabilityRequiredCondition` retirada.** Su única función era activar el EMF según los selectores `jdbc|jpa`. Sin selectores queda sin consumidor. El bootstrap global (exclusiones de Boot, entity scanning) **no** se tocó.
- **D-2: EMF de Asistencia siempre activo.** Sin condición. Se añadieron `hibernate.boot.allow_jdbc_metadata_access=false` y `hibernate.dialect=SQLServerDialect` para que el arranque no conecte a la DB. El comentario de `AsistenciasUcoApplication` lo prometía.
- **D-3: oráculo JDBC congelado solo en test.** `AsistenciaRepositorySqlServerAdapter` pasó a `src/test/.../jpa/AsistenciaJdbcBaselineOracle.java` para que la paridad siga comparando contra el baseline real. Si se prefiere cero JDBC en todo el repo, la alternativa es reemplazar la comparación por verdades absolutas de DB.
- **D-4: la query de Asistencia pasó a JPA en todos los perfiles.** Antes, el default de `asistencia-query-provider` era `jdbc`. Requisito de la instrucción (`QUERIES = JPA_ONLY`). Paridad certificada con `AsistenciaQueryJpaParityIT` 7/7.
- **D-5: `ReporteAsistenciaSqlServerAdapter` sigue en JDBC.** Pertenece a la capacidad de reportes (JPA-05), no a commands/queries de Asistencia.
- **D-6: clasificación del batch.** `usp_registrar_asistencias_sesion` no es `SP_MANAGES_TRANSACTION = YES` puro: es condicional. Equivale a YES cuando no hay transacción externa, que es el caso de ambos lados.

### Tests retirados y reemplazados (no debilitados)

- `AsistenciaJpaCommandPersistenceTest` (piloto, mocks de `StoredProcedureQuery`, tolerancia a update counts): reemplazado por `AsistenciaJpaCommandNativeQueryPatternTest`. El contrato JSON del lote se certifica contra SQL Server en `AsistenciaCommandJpaParityIT`. Se pierde la cobertura unitaria de esos detalles de serialización; queda cubierta por la paridad real.
- Pruebas de selectores, fallback y composición: `AsistenciaCommandProvider{AcceptanceRed,Characterization,CompositionRoot}Test`, `AsistenciaQueryProvider{Activation,CompositionRoot}Test`, `JpaCapabilityRequiredConditionTest`, `EntityManagerFactoryDefinitionProbe`, `AsistenciaQueryProviderContextIT`.
- Pruebas del híbrido y del adapter JDBC como producto: `AsistenciaRepositoryHybridCommandRoutingTest`, `AsistenciaRepositoryHybridSqlServerAdapterTest`, `AsistenciaRepositorySqlServerAdapterTest`.
- `SqlServerJpaAsistenciaQueryConfigurationTest`: reducido a propiedades de Hibernate y arranque sin metadatos JDBC.

### Archivos

```text
FILES_CREATED:
  src/main/java/.../sqlserver/jpa/AsistenciaRepositoryJpaSqlServerAdapter.java
  src/test/java/.../sqlserver/jpa/AsistenciaJdbcBaselineOracle.java           (movido y renombrado; solo test)
  src/test/java/.../sqlserver/jpa/AsistenciaJpaCommandNativeQueryPatternTest.java
  src/test/java/.../sqlserver/jpa/AsistenciaCommandsSpParityIT.java

FILES_MODIFIED (de esta ejecución):
  src/main/java/.../sqlserver/jpa/AsistenciaJpaCommandPersistence.java          (reescrito: EntityManager, 4 commands)
  src/main/java/.../sqlserver/jpa/AsistenciaJpaQueryPersistence.java            (sin interfaz interna)
  src/main/java/.../config/.../SqlServerCoreRepositoryAdapterConfiguration.java (bean de Asistencia JPA-only)
  src/main/java/.../config/.../SqlServerJpaAsistenciaQueryAdapterConfiguration.java (sin @Conditional; Hibernate seguro)
  src/main/java/.../AsistenciasUcoApplication.java                              (comentario)
  src/main/resources/application.yml, application-local.yml, application-dev.yml (selectores retirados)
  .env.example                                                                  (líneas de selector retiradas)
  src/test/.../architecture/JpaCommandIsolationRulesTest.java                  (nombres vigentes + prohibiciones SPQ/JDBC)
  src/test/.../sqlserver/contract/GoldenPathSqlStoredProcedureContractIT.java  (javadoc)
  src/test/.../sqlserver/jpa/{AsistenciaCommandConcurrencyIT, AsistenciaCommandJpaParityIT, AsistenciaCommandRealtimeIT,
                              AsistenciaCommandTransactionBoundaryIT, AsistenciaQueryJpaParityIT,
                              JpaAttendanceStoredProcedureFeasibilityIT}.java  (sin selectores; oráculo)
  src/test/.../config/.../{SqlServerJpaAsistenciaQueryConfigurationTest, SqlServerPersistenceCompositionRootTest}.java
  docs: PLAN, CONTRACT_MATRIX, VALIDATION, TEST_PLAN (este work item) · baseline/TECHNICAL_DEBT (TD-009/055/056/057),
        baseline/LINEA_BASE, baseline/GOLDEN_PATH_ASISTENCIA · architecture/{infrastructure-structure, adapter-composition-standard}
        · integration/repository-mock-inventory

FILES_DELETED:
  src/main/.../sqlserver/core/AsistenciaCommandPersistence.java
  src/main/.../sqlserver/core/AsistenciaQueryPersistence.java
  src/main/.../sqlserver/core/AsistenciaRepositoryHybridSqlServerAdapter.java
  src/main/.../sqlserver/core/AsistenciaRepositorySqlServerAdapter.java          (movido a test como oráculo)
  src/main/.../config/.../JpaCapabilityRequiredCondition.java
  src/test/.../sqlserver/core/{AsistenciaRepositoryHybridCommandRoutingTest, AsistenciaRepositoryHybridSqlServerAdapterTest,
                               AsistenciaRepositorySqlServerAdapterTest}.java
  src/test/.../sqlserver/jpa/{AsistenciaJpaCommandPersistenceTest, AsistenciaQueryProviderContextIT}.java
  src/test/.../config/.../{AsistenciaCommandProviderAcceptanceRedTest, AsistenciaCommandProviderCharacterizationTest,
                           AsistenciaCommandProviderCompositionRootTest, AsistenciaQueryProviderActivationTest,
                           AsistenciaQueryProviderCompositionRootTest, JpaCapabilityRequiredConditionTest,
                           EntityManagerFactoryDefinitionProbe}.java
```

### Riesgos residuales y deuda

```text
BLOCKERS:              ninguno para JPA-01 COMMANDS.
TECHNICAL_DEBT_UPDATED:
  TD-043  OPEN / DEFERRED (sin cambios; no cerrada)
  TD-044  ABIERTA, NON_BLOCKING (sin cambios)
  TD-055  actualizada con conteo real: 44 archivos JDBC en src/main (antes 45), 0 en Asistencia
  TD-056  NUEVA: autónomo sin frontera transaccional (heredada del SP)
  TD-057  NUEVA, ALTA (DB owner): catálogo dbo.Estado sin códigos de solicitud; toda solicitud queda en 'A'
  TD-009  enlace de evidencia actualizado a AsistenciaRepositoryJpaSqlServerAdapter
  TD-010  DECISION_REQUIRED (sin cambios; JPA-06)

JPA00:                           PASS
JPA01_FOUNDATION:                PASS
JPA01_COMMANDS:                  PASS
ASISTENCIA_PERSISTENCE_PROVIDER: JPA_ONLY (commands y queries)

NEXT_RECOMMENDED_MICROPHASE EN ESE CORTE HISTÓRICO: JPA-02A — NORMALIZE JPA BOOTSTRAP
                             (entonces no iniciada; la ejecución posterior la cerró en PASS).
```

---

## Consolidación documental JPA-01 / preparación JPA-02A (HISTÓRICO, 2026-10-05)

Ejecución exclusivamente documental. No se modificaron código productivo, tests, `pom.xml`,
configuración runtime, DB, frontend ni `infra/**`; no se inició la implementación de JPA-02A.

### Preflight

```text
BRANCH:          jose-valencia/lb-004-stateless-serverless-readiness
HEAD:            0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d
WORKTREE_BEFORE: 88 entradas en git status --short. Incluían trabajo previo de LB-004/LB-008,
                 código, tests, runtime config, infra y documentación. Todo fue preservado.
```

No se ejecutó `git reset --hard`, `git clean`, stash automático ni checkout destructivo.

### Estado canónico consolidado

```text
LB-008 STATUS:                 IN_PROGRESS — JPA-02A
JPA-00:                        PASS
JPA-01 FOUNDATION:             PASS
JPA-01 COMMANDS:               PASS
ASISTENCIA COMMANDS:           JPA_ONLY
ASISTENCIA QUERIES:            JPA_ONLY
GLOBAL INTEGRATION:            NOT_GREEN_TD043
JPA-01 FINAL TARGETED GATE:    83/83 PASS
PRE-SWITCH BASELINE TARGETED:  73/73 PASS (histórico)
DIRECT_JDBC_ASISTENCIA:        0
DIRECT_JDBC_GLOBAL_BASELINE:   44 (residual fuera de Asistencia)
```

JPA-01 cerró los cuatro commands `dbo.usp_registrar_asistencias_sesion`,
`dbo.usp_registrar_asistencia_estudiante_autonomo`,
`dbo.usp_radicar_solicitud_revision_asistencia` y
`dbo.usp_resolver_solicitud_revision_asistencia` con el patrón
`EntityManager → createNativeQuery(EXEC) → named parameters → getResultList →
ProcedureResultMapper → ProcedureResultValidator`. No queda `StoredProcedureQuery`, JDBC directo ni
runtime híbrido de Asistencia en `src/main`.

### Gates y deuda preservados

```text
GLOBAL_GATE:       NOT_GREEN_TD043
JPA01_CAUSAL_GATE: PASS
CONTINUITY:        AUTHORIZED BY VERSIONED TD-043 EXCEPTION

TD-043: OPEN / DEFERRED / PREEXISTING
TD-044: OPEN / NON_BLOCKING
TD-056: OPEN / PREEXISTING / DB CONTRACT-BEHAVIOR / NON_BLOCKING_FOR_JPA02A
TD-057: OPEN / HIGH / DB_OWNER / PREEXISTING / NON_CAUSAL_TO_JPA
```

TD-043/TD-044 no invalidan el cierre causal de JPA-01. TD-056 conserva la no atomicidad heredada
del flujo autónomo y no se corrige desde backend. TD-057 conserva el drift entre `dbo.Estado`
(`A`/`R`) y los códigos buscados por los SP (`P`/`PEND`, `APRO`, `RECH`): el fallback
`TOP 1 ORDER BY id` puede dejar una solicitud rechazada en `A`. JDBC y JPA presentan el mismo
comportamiento; no es regresión JPA. Ninguna de estas dos deudas bloquea JPA-02A.

### Readiness de JPA-02A

El AS-IS de bootstrap quedó inventariado: exclusiones JPA de Boot, EMF manual, shared
`EntityManager`, tres entidades registradas explícitamente, `open-in-view=false`, `ddl-auto=none` y
sin `JpaTransactionManager` explícito. El único consumidor productivo directo localizado de
`TransactionOperations` es `GrupoRepositorySqlServerAdapter`; persisten 44 archivos JDBC fuera de
Asistencia.

```text
ESTADO EN ESE CORTE (SUPERADO): READY para JPA-02A; implementación aún no iniciada
RIESGO EN ESE CORTE:            TRANSACTION MANAGER SEMANTICS
GATE EN ESE CORTE:              TRANSACTION_MANAGER_BEFORE vs TRANSACTION_MANAGER_AFTER
```

El TARGET propuesto usa bootstrap estándar Spring Boot, EMF administrado por Boot, proxy
`EntityManager`, `open-in-view=false` y `ddl-auto=none`. El dialecto SQL Server explícito y
`hibernate.boot.allow_jdbc_metadata_access=false` se conservan solo si la implementación demuestra
que siguen siendo necesarios para evitar conexión al arranque; todavía no se declaran definitivos.

### Validación de esta ejecución

- Tests/build/integración: **NOT_RUN / NO APLICA** para esta ejecución `DOCUMENTATION_ONLY`; se
  reutiliza la evidencia técnica certificada de JPA-01 y no se inventa evidencia runtime nueva.
- ArchUnit/OpenAPI/coverage: no reejecutados; último estado certificado de JPA-01: PASS según la
  sección técnica anterior.
- Archivos modificados por esta ejecución: `LINEA_BASE.md`, `TECHNICAL_DEBT.md`, `PLAN.md`,
  `TEST_PLAN.md`, `CONTRACT_MATRIX.md`, `VALIDATION.md`.
- Archivos no documentales modificados por esta ejecución: ninguno.
- `git diff --check`: **PASS**, exit 0. Único warning informativo preexistente: futura
  normalización LF→CRLF de `.env.example`; no es error de whitespace.
- Verificación adicional de trailing whitespace sobre los seis Markdown de esta ejecución: **PASS**,
  ninguno encontrado (incluye los cuatro archivos nuevos/no trackeados del work item, que
  `git diff --check` no enumera).
- `WORKTREE_AFTER`: 88 entradas en `git status --short`. El conjunto ya incluía cambios no
  documentales previos; esta ejecución no añadió ni modificó ninguno. Los seis archivos tocados por
  esta ejecución son exclusivamente Markdown.

## Ejecución JPA-02A — NORMALIZE JPA BOOTSTRAP (2026-10-05)

### Identidad

- BRANCH: `jose-valencia/lb-004-stateless-serverless-readiness`.
- HEAD: `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d`. Sin commit ni push; el cambio queda en el working tree.
- WORKTREE_BEFORE: 88 entradas en `git status --short` (trabajo LB-004 y LB-008 JPA-00/JPA-01 sin consolidar). No se revirtió nada.
- WORKTREE_AFTER: 93 entradas. JPA-02A añade 4 archivos sin rastrear: `SqlServerJpaBootstrapConfiguration`, `SqlServerJpaBootstrapConfigurationTest`, `JpaBootstrapStandardRulesTest` y `PersistenceTransactionParityIT`. La diferencia restante respecto de 88 no se atribuyó con certeza a una entrada concreta; no se revirtió nada para cuadrarla.
- Baseline BEFORE: copia del árbol previo a JPA-02A en el scratchpad de la sesión, mismo HEAD y mismo contenido de trabajo. Se ejecutó sin tocar el árbol principal.

### Entorno y carga de `.env`

- `.env` no puede cargarse con `source` en bash: el `;` de `SPRING_DATASOURCE_URL` se interpreta como separador y la URL queda truncada a `jdbc:sqlserver://host:1433`. Una primera corrida BEFORE con esa carga dio 36 errores de TLS (`trustServerCertificate=false`). Esa corrida se invalidó y no es evidencia.
- Carga válida: un lector `KEY=VALUE` que exporta cada línea completa. Verificado: la URL conserva `encrypt=true;trustServerCertificate=true`. Los valores no se registran aquí.

### DoR JPA-02A

- JPA-01 = PASS; Asistencia = `JPA_ONLY`; el baseline de integración coincide con el documentado (`NOT_GREEN_TD043`).

### TRANSACTION_MANAGER_BEFORE (medido en runtime con un probe temporal fuera del repo)

- Bean `transactionManager`: `org.springframework.jdbc.support.JdbcTransactionManager` (tipo de Spring Boot 4 / Spring 7), sobre el `DataSource` de Boot.
- `TransactionOperations`: `TransactionTemplate` sobre ese TM.
- EMF: solo `entityManagerFactory` (manual del piloto). No hay EntityManager compartido de Spring Data.
- Consumidor productivo directo de `TransactionOperations`: `GrupoRepositorySqlServerAdapter` (3 `transactionOperations.execute`).

### TRANSACTION_MANAGER_AFTER (medido en runtime)

- Bean `transactionManager`: `org.springframework.orm.jpa.JpaTransactionManager`, sobre el mismo `DataSource`.
- `TransactionOperations`: `TransactionTemplate` sobre `JpaTransactionManager`.
- EMF: `entityManagerFactory` (Boot, único). EntityManager compartido: `jpaSharedEM_entityManagerFactory` (Spring Data), inyectable por constructor.

### TRANSACTION_MANAGER_PARITY

- `PersistenceTransactionParityIT` (3 tests, sin cambios entre BEFORE y AFTER): PASS en BEFORE (3/3) y en AFTER (3/3).
- Afirma sobre el recurso ligado por Spring: dentro de la frontera hay transacción activa; JDBC usa la misma conexión ligada (`DataSourceUtils`) con `autocommit=false`; las fronteras anidadas reutilizan la conexión externa; una excepción libera el recurso y restaura `autocommit`.
- Descartado como evidencia: `@@TRANCOUNT`. En este patrón del driver mssql-jdbc devolvió 0 dentro de la frontera también en BEFORE (2 de 3 fallos en la primera versión del test). Se corrigió el test para usar el recurso ligado. El código no cambió.
- Cambio observable: el tipo del TM pasa de `JdbcTransactionManager` a `JpaTransactionManager`, de forma intencional (bootstrap estándar). El JDBC legacy sigue en la misma conexión y el mismo DataSource. No hay `@Transactional` en producción. `JpaCommandIsolationRulesTest` sigue en PASS. Los commands de Asistencia mantienen `CURRENT_OUTER_TX = TARGET_OUTER_TX = NO`.

### NO_CONNECT_ON_STARTUP y ENTITY_SCANNING

- `SqlServerJpaBootstrapConfigurationTest.bootstrap_estandar_crea_un_unico_emf_sin_conectar_y_descubre_las_entities_de_asistencia`: PASS. El `DataSource` de prueba lanza en `getConnection`; el contexto arranca; `verify(never).getConnection()`; el metamodelo contiene `UvAsistenciaEntity`, `UvDetalleAsistenciaEntity` y `UvEstudianteGrupoEntity` sin lista manual.
- `hibernate.boot.allow_jdbc_metadata_access=false` y `hibernate.dialect=SQLServerDialect` verificados contra las fuentes de Hibernate 7.2.12 (`JdbcSettings.ALLOW_METADATA_ON_BOOT`).

### Hallazgo causal y corrección

- Primera ejecución AFTER (bootstrap estándar con el naming por defecto de Boot): 13 errores causales en ITs de Asistencia (`AsistenciaQueryJpaParityIT` 6, `AsistenciaRepositorySqlServerIT` 6, `AsistenciaCommandJpaParityIT` 1), con `Invalid column name 'id_asistencia'`.
- Causa: Boot aplica `CamelCaseToUnderscoresNamingStrategy` por defecto. Las entities de Asistencia usan `@Column(name = "idAsistencia")`, `codigoRazonCausa`, `idSesion` e `idEstudianteGrupo`, que corresponden a columnas camelCase de la DB. El piloto usaba los defaults de Hibernate.
- Corrección: `hibernate.physical_naming_strategy = PhysicalNamingStrategyStandardImpl` e `hibernate.implicit_naming_strategy = ImplicitNamingStrategyJpaCompliantImpl` en `SqlServerJpaBootstrapConfiguration`. Restauran el comportamiento AS-IS del piloto.
- Evidencia: el test de naming falló antes del fix (`expected <PhysicalNamingStrategyStandardImpl> but was <null>`) y pasó después. Targeted tras el fix: 37/37 PASS (`AsistenciaRepositorySqlServerIT` 6, `AsistenciaCommandJpaParityIT` 21, `AsistenciaQueryJpaParityIT` 7, `PersistenceTransactionParityIT` 3).

### RED → GREEN

- RED escritos antes de la implementación: `SqlServerJpaBootstrapConfigurationTest` (la clase `SqlServerJpaBootstrapConfiguration` no existía, RED de compilación) y `JpaBootstrapStandardRulesTest` (3 reglas ArchUnit: sin `LocalContainerEntityManagerFactoryBean`, sin `SharedEntityManagerCreator`, sin `EntityManagerFactory` en adapters JPA).
- Limitación: las reglas ArchUnit no se ejecutaron contra el código antiguo antes de implementar. Sí se observó RED en el test de naming, que falló antes del fix.
- Tests actualizados por cambio de composición (no debilitados): `AsistenciaJpaQueryPersistenceTest` (EntityManager en lugar de factory; `close()` pasa a `never`), `SqlServerPersistenceCompositionRootTest` (bean `EntityManager`), `AsistenciaCommandJpaParityIT` y `AsistenciaCommandsSpParityIT` (EntityManager administrado en lugar de `SharedEntityManagerCreator`).
- Test retirado: `SqlServerJpaAsistenciaQueryConfigurationTest` (2 tests de propiedades del EMF manual), sustituido por `SqlServerJpaBootstrapConfigurationTest`, que cubre dialecto, metadatos JDBC y naming.

### Gates (medidos)

- `clean verify` (default, AFTER final): BUILD SUCCESS. 1362 tests, 0 fallos, 0 errores, 0 skips. `All coverage checks have been met`. Incluye ArchUnit (95 tests en `architecture`, de ellos 3 de `JpaBootstrapStandardRulesTest`) y OpenAPI (17 tests: conformidad Golden Path y Swagger UI).
- Cobertura de ese run (solo unit, `jacoco.xml`): LINE 7590/8589 = 88.37 % (gate 80 %); BRANCH 1754/2230 = 78.65 % (gate 70 %). PASS.
- `clean verify -Pintegration` (AFTER final): BUILD FAILURE en `failsafe:verify`, igual que el BEFORE. 128 IT ejecutados, 6 fallos, 0 errores, 2 skips. Conjunto de fallos idéntico por nombre al BEFORE: `SqlStoredProcedureContractIT` ×3, `GrupoRepositorySqlServerIT` ×2, `UsuarioPasswordHashSqlServerIT` ×1; mismos 2 skips de `DocenteRepositorySqlServerIT`. Las 3 de `SqlStoredProcedureContractIT` son "Contrato SQL incompatible" por SPs ausentes (TD-043). Las 2 de `GrupoRepositorySqlServerIT` registran estudiante, con un SP ausente (TD-043). La de `UsuarioPasswordHashSqlServerIT` depende de `usp_sincronizar_usuario` (TD-043). Resultado: `GLOBAL_GATE = NOT_GREEN_TD043`, sin nuevas regresiones.
- Cobertura integrada (`jacoco.xml` del run de integración): LINE 91.51 %, BRANCH 80.58 %. El check de JaCoCo no se ejecutó en ese run por el fallo de failsafe; el gate válido es el del `clean verify` default.
- Targeted de integración (Asistencia + parity + transacción): 37/37 PASS tras el fix de naming.
- `git diff --check`: sin errores de espacios. Solo aparece la advertencia de fin de línea CRLF de `.env.example`, preexistente en el worktree.

### Gate causal vs global

- `CAUSAL_JPA02A_INTEGRATION`: PASS (37/37). Asistencia `JPA_ONLY` sin regresión. `PersistenceTransactionParityIT` PASS en BEFORE y en AFTER.
- `GLOBAL_INTEGRATION`: NOT_GREEN_TD043, idéntico al BEFORE. No se declara PASS.

### DoD JPA-02A

| Criterio | Resultado |
|---|---|
| `BOOTSTRAP_JPA_STANDARD` | YES |
| `MANUAL_PILOT_EMF` en `src/main` | 0 |
| `MANUAL_SHARED_ENTITY_MANAGER` en `src/main` | 0 |
| `JPA_BOOTSTRAP_EXCLUSIONS` (`excludeName` / `exclude`) en `src/main` | 0 |
| `JPA_CAPABILITY_CONDITION` | 0 (`JpaCapabilityRequiredCondition` ya no existe) |
| `createEntityManager` en `src/main` | 0 |
| `ASISTENCIA_JPA_ONLY` | PRESERVED |
| `NO_CONNECT_ON_STARTUP` | PRESERVED (contractual según el test del piloto; verificado por unit) |
| `TRANSACTION_MANAGER_PARITY` | PASS (`PersistenceTransactionParityIT` 3/3 en BEFORE y AFTER) |
| `LEGACY_JDBC_MODULES` | BEHAVIOR_PRESERVED (mismo conjunto de fallos y skips que BEFORE) |
| `clean verify` | PASS (1362 tests, gates de cobertura cumplidos) |
| targeted integration | PASS (37/37) |
| ArchUnit | PASS (95 tests del paquete) |
| OpenAPI | PASS (17 tests) |
| coverage gates | PASS en unit (LINE 88.37 %, BRANCH 78.65 %) |
| `git diff --check` | PASS |
| `-Pintegration verify` global | NOT_GREEN_TD043 (idéntico al BEFORE) |

`DIRECT_JDBC_GLOBAL` no forma parte del DoD de JPA-02A.

### Conteos JDBC

- `DIRECT_JDBC_ASISTENCIA = 0`.
- `DIRECT_JDBC_GLOBAL_BEFORE = 44`; `DIRECT_JDBC_GLOBAL_AFTER = 44`. JPA-02A no migra archivos JDBC; el bootstrap no migra verticales.
- `StoredProcedureQuery` = 0 en `src/main`.
- Inventario de los 44 con microfase asignada: [JDBC_RESIDUAL_INVENTORY](JDBC_RESIDUAL_INVENTORY.md). Ningún archivo queda sin microfase.

### Decisiones registradas

- Único TM: el `JpaTransactionManager` estándar de Boot. Se evaluó conservar `DataSourceTransactionManager` para mantener el TM legacy exacto y se descartó: obligaría a un segundo TM mientras existe un único bootstrap. La paridad se demuestra con `PersistenceTransactionParityIT`, no por el tipo del bean.
- Naming de Hibernate del piloto: se fijan los strategies de Hibernate en lugar del camel-case de Boot, porque los `@Column` reflejan columnas camelCase de la DB.
- `SqlServerJpaAsistenciaQueryAdapterConfiguration` se elimina. Sus propiedades pasan a `SqlServerJpaBootstrapConfiguration` como `HibernatePropertiesCustomizer`. Se usa un customizer y no `application.yml` porque el perfil de integración (`application-integration.yml`) no hereda `application.yml`, mientras que el perfil unitario sí lo sombrea.

### Archivos (JPA-02A)

- Creados: `infrastructure/config/adapters/persistence/sqlserver/SqlServerJpaBootstrapConfiguration.java`; `src/test/.../config/.../SqlServerJpaBootstrapConfigurationTest.java`; `src/test/.../architecture/JpaBootstrapStandardRulesTest.java`; `src/test/.../sqlserver/jpa/PersistenceTransactionParityIT.java`; `docs/work-items/LB-008-jpa-only-persistence-migration/JDBC_RESIDUAL_INVENTORY.md`.
- Modificados: `AsistenciasUcoApplication.java` (sin exclusiones); `AsistenciaJpaQueryPersistence.java` (EntityManager); `SqlServerCoreRepositoryAdapterConfiguration.java` (EntityManager); tests `AsistenciaJpaQueryPersistenceTest`, `SqlServerPersistenceCompositionRootTest`, `AsistenciaCommandJpaParityIT`, `AsistenciaCommandsSpParityIT`; documentación LB-008 y `docs/persistence/JDBC_TO_JPA.md`.
- Eliminados: `SqlServerJpaAsistenciaQueryAdapterConfiguration.java`, `SqlServerJpaAsistenciaQueryConfigurationTest.java`.
- Sin cambios: DB, schema, SP, vistas, `application*.yml`, `pom.xml`, Domain, Application, HTTP, OpenAPI, seguridad, realtime, MinIO, ClamAV, storage.

### Riesgos residuales

- La cobertura integrada no se recalculó con el check de JaCoCo por el fallo global de TD-043.
- La paridad de transacciones se certifica sobre el recurso ligado. No prueba el rollback de un DML real, porque la DB es de solo lectura para esta migración. Debe cubrirse en la microfase que migre el primer DML.
- TD-043, TD-044, TD-010, TD-056 y TD-057 siguen abiertos, sin cambios.

---

## Cierre documental JPA-02A / preparación JPA-02B (2026-10-05)

Ejecución exclusivamente documental. No se modificaron Java, tests, beans, queries, stored
procedures, propiedades funcionales, dependencias, DB ni frontend. Los cambios en `application.yml`
y `pom.xml` son únicamente comentarios que corrigen la descripción obsoleta del piloto.

### Preflight

```text
BRANCH:          jose-valencia/lb-004-stateless-serverless-readiness
HEAD:            0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d
WORKTREE_BEFORE: 93 entradas en git status --short; incluían trabajo previo de LB-004/LB-008,
                 código, tests, runtime config, infra y documentación. Todo fue preservado.
```

No se ejecutó `git reset --hard`, `git clean`, stash automático ni checkout destructivo.

### Estado canónico vigente

```text
LB-008 STATUS:                 IN_PROGRESS — JPA-02B
JPA-00:                        PASS
JPA-01 FOUNDATION:             PASS
JPA-01 COMMANDS:               PASS
JPA-02A:                       PASS
ASISTENCIA COMMANDS:           JPA_ONLY
ASISTENCIA QUERIES:            JPA_ONLY
BOOTSTRAP:                     SPRING_BOOT_JPA_STANDARD
TRANSACTION_MANAGER:           JpaTransactionManager
TRANSACTION_MANAGER_PARITY:    PASS (3/3 BEFORE; 3/3 AFTER)
DIRECT_JDBC_ASISTENCIA:        0
DIRECT_JDBC_GLOBAL:            44
GLOBAL INTEGRATION:            NOT_GREEN_TD043
NEXT:                          JPA-02B — CORE COMMANDS (SESIÓN + GRUPO)
```

### Evidencia técnica reutilizada, no reejecutada

| Gate certificado por JPA-02A | Resultado |
|---|---|
| `clean verify` | PASS: 1362 tests, 0 fallos/errores/skips |
| targeted JPA-02A / Asistencia | PASS: 37/37 |
| transaction parity | PASS: 3/3 BEFORE y 3/3 AFTER |
| ArchUnit | PASS: 95 tests del paquete de arquitectura |
| OpenAPI | PASS: 17 tests |
| Coverage | PASS: LINE 88.37 %, BRANCH 78.65 % |
| `git diff --check` de la ejecución técnica JPA-02A | PASS |
| global `clean verify -Pintegration` | NOT_GREEN_TD043: 128 IT, 6 fallos, 2 skips; no se convierte en PASS |

Esta ejecución documental no crea evidencia runtime nueva. Tests/build/integración =
`NOT_RUN / NO APLICA` para el cambio documental; la tabla anterior referencia la evidencia ya
certificada en la sección JPA-02A.

### Readiness de JPA-02B

```text
JPA-02B STATUS: READY_WITH_SCOPED_DB_BLOCKER
IMPLEMENTATION: NOT_STARTED
COMMANDS TOTAL: 7
SESSION:        4/4 PROVIDER AVAILABLE
GRUPO:          2/3 PROVIDER AVAILABLE
TD-043:         usp_registrar_estudiante_en_grupo_usuario_no_existente = MISSING / BLOCKED_TD043
```

TD-043 permanece `OPEN / DEFERRED / PREEXISTING / SCOPED_BLOCKER`. No bloquea globalmente JPA-02B;
bloquea la ejecución/certificación real del command afectado. Su código conserva
`CODE_MIGRATION_STATUS = JPA_REQUIRED`; no se sustituye por
`usp_registrar_estudiante_en_grupo` ni se deja un fallback JDBC definitivo.

La `TRANSACTION_MATRIX` de entrada quedó registrada en PLAN y CONTRACT_MATRIX. Los cuatro commands
de Sesión no tienen outer tx vigente; `usp_crear_sesion` maneja transacción condicional y
`usp_generar_sesiones_grupo` transacción propia. Los tres commands de Grupo están envueltos por
`TransactionOperations.execute`; esa frontera se conserva hasta que JPA-02B demuestre si es
necesaria o accidental. `PARITY` permanece `NOT_RUN`/`BLOCKED_TD043`, nunca PASS documental.

### Validación documental

- Integridad y búsquedas de estados obsoletos: pendientes de la validación final de esta ejecución.
- `git diff --check`: pendiente de la validación final de esta ejecución.
- `git diff --name-only`: pendiente de la validación final de esta ejecución.
- Archivos no documentales modificados por esta ejecución: solo comentarios en
  `src/main/resources/application.yml` y `pom.xml`; cero valores/configuración/dependencias.
- JPA-02B DoR: `READY_WITH_SCOPED_DB_BLOCKER`.
- JPA-02B DoD: definido en PLAN; no evaluado porque `IMPLEMENTATION_NOT_STARTED`.

## Ejecución JPA-02B — CORE COMMANDS (2026-10-05)

Entorno: JDK 25 (`JAVA_HOME`), SQL Server 2022 Developer (contenedor `sql_server_asistencias`, DB `gestionasistenciadb`), repositorio DB `develop@f2871a9`. Variables de conexión cargadas desde `.env` del proceso; ningún valor se registra aquí. Logs en el scratchpad de la sesión, no versionados.

### Gates

| Gate | Comando | Resultado |
|---|---|---|
| Unitario y build | `./mvnw clean verify` | **BUILD SUCCESS**. Tests **1371**, fallos 0, errores 0, skips 0 |
| ArchUnit | incluido en `clean verify` | **100/100 PASS** (incluye `JpaCoreCommandRulesTest` 5/5) |
| OpenAPI | incluido en `clean verify` | **16/16 PASS** (9 + 2 + 1 + 4) |
| Cobertura JaCoCo | `jacoco:check` | **All coverage checks have been met.** LINE **88.43 %** (7637/8636), BRANCH **78.65 %** (1754/2230). Umbrales 80 % / 70 % |
| Integración global | `./mvnw clean -Pintegration verify` | **BUILD FAILURE** por la integración: unitarios **1371/0**; ITs **139 run, 6 failures, 0 errors, 2 skipped** |
| Diferencias | `git diff --check` | limpio (aviso CRLF preexistente de `.env.example`) |

### Integración global: fallos y comparación BEFORE/AFTER

Los 6 fallos son **idénticos por nombre** a la línea base documentada antes de JPA-02B y a la corrida BEFORE de este work item. Causa común: SP inexistente en la DB (TD-043).

| Test | Causa observada AFTER | Causa observada BEFORE |
|---|---|---|
| `SqlStoredProcedureContractIT.stored_procedure_publico_coincide_con_el_contrato_real_de_la_db` [1], [7], [12] | `esperaba procedimiento almacenado existente`: `usp_registrar_estudiante_en_grupo_usuario_no_existente`, `usp_sincronizar_usuario`, `usp_registrar_o_actualizar_plan_estudio` | igual |
| `GrupoRepositorySqlServerIT.registrar_estudiante_success_path_con_sp_real_y_rollback_del_test` | `Could not find stored procedure 'dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente'` | igual |
| `GrupoRepositorySqlServerIT.registrar_estudiante_con_grupo_inexistente_hace_rollback_sin_registros_parciales` | `DatabaseOperationException` donde se esperaba `ApplicationException` (mismo SP ausente) | igual |
| `UsuarioPasswordHashSqlServerIT.crear_usuario_persiste_hash_verificable_y_no_password_plano` | `Could not find stored procedure 'dbo.usp_sincronizar_usuario'` (JPA-03/TD-043, fuera de JPA-02B) | igual |

No hay fallo nuevo causal de JPA-02B. Skips: `DocenteRepositorySqlServerIT` 2 (TD-044, no bloqueante).

Nota de alcance: la corrida BEFORE fue el subconjunto de ITs relevantes (6 clases) sobre el código JDBC. La corrida AFTER es global. La comparación de nombres fallidos es válida porque la corrida BEFORE incluye todas las clases que fallan.

### Paridad Sesión y Grupo (SQL Server real)

- `SesionGrupoCommandsSpParityIT` (11 escenarios sobre puertos): **BEFORE 11/11 PASS** (JDBC) y **AFTER 11/11 PASS** (JPA).
- Las 11 líneas `PARITY_OUTCOME` son idénticas entre BEFORE y AFTER (`diff` vacío). El detalle por escenario está en CONTRACT_MATRIX, sección "Resultado JPA-02B".

### Regresión de Asistencia, transacciones y queries (AFTER)

| Suite | Resultado |
|---|---|
| `AsistenciaCommandJpaParityIT` | 21/21 |
| `AsistenciaCommandsSpParityIT` | 10/10 |
| `AsistenciaCommandTransactionBoundaryIT` | 3/3 |
| `PersistenceTransactionParityIT` | 3/3 |
| `AsistenciaRepositorySqlServerIT` | 6/6 |
| `GoldenPathSqlStoredProcedureContractIT` | 16/16 |
| `AuditHttpIT` | 2/2 |

Las queries `uv_sesion` y `uv_grupo` no cambiaron: `consultarSesion`, `consultarSesionesPorGrupo`, `consultarGrupos` y `consultarEstudiantesGrupo` siguen en JDBC temporal (JPA-04). Sus tests unitarios (`SesionRepositorySqlServerAdapterTest`, `GrupoRepositorySqlServerAdapterTest`) pasan.

### Veredicto

- `JPA02B_CAUSAL_GATE`: **PASS**. Sin fallo nuevo causal. Frontera transaccional de Grupo conservada. Paridad Sesión/Grupo BEFORE = AFTER.
- `GLOBAL_INTEGRATION`: **NOT_GREEN_TD043**, sin cambio. No se declara PASS.
- `DB_PROVIDER` de `usp_registrar_estudiante_en_grupo_usuario_no_existente`: **MISSING** (TD-043 OPEN). Su command ya está en JPA y su fallo se clasifica como `DATABASE_OPERATION_ERROR`.

## Ejecución JPA-03 — ACADEMIC / USER COMMANDS (2026-10-05) — HISTÓRICO

> Estado histórico de esta pasada: éxito `NOT_RUN` y JPA-03 `NO CERRADO`. Conclusión superada por la sección "Ejecución JPA-03 — cierre de JPA-03" al final de este documento. Se conserva como evidencia.

Alcance: 8 command paths (Asignatura x3, CierrePeriodo x1, Coordinador x1, Decano x1, PlanEstudio x1 [TD-043], Usuario x1 [TD-043]) sobre `EntityManager + createNativeQuery("EXEC ...")`. Las queries siguen en JDBC (JPA-04 / JPA-05). Sin commit ni push.

```
BRANCH:            jose-valencia/lb-004-stateless-serverless-readiness
HEAD:              0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d
WORKTREE_BEFORE:   105 entradas (git status --short)
WORKTREE_AFTER:    133 entradas (incluye el trabajo previo LB-004/LB-008, sin revertir)
```

### RED (observado)

- `RED_EXPECTED`: tests de patron por capability, regla ArchUnit y paridad BEFORE contra SQL Server real.
- `RED_OBSERVED`: `mvnw test-compile` falla con `cannot find symbol` en las 6 clases `*JpaCommandPersistence` (24 lineas de error, todas por clases inexistentes). Compilacion fallida = RED observable antes de GREEN.
- `PARITY_BEFORE`: `AcademicUserCommandsSpParityIT` ejecutado contra el baseline JDBC (codigo previo a JPA-03): 8/8 `PARITY_OUTCOME`, `BUILD SUCCESS`.

### GREEN

- Clases nuevas en `infrastructure/adapter/secondary/persistence/sqlserver/jpa/`: `AsignaturaJpaCommandPersistence`, `CierrePeriodoJpaCommandPersistence`, `CoordinadorJpaCommandPersistence`, `DecanoJpaCommandPersistence`, `PlanEstudioJpaCommandPersistence`, `UsuarioJpaCommandPersistence`. Mismo patron que Grupo y Sesion: `createNativeQuery`, `setParameter` nombrado, `getResultList`, `ProcedureResultMapper.mapSingle`, `ProcedureResultValidator.validate`. Sin `StoredProcedureQuery`, sin `ParameterMode`, sin JDBC.
- Adapters: los 6 command adapters delegan en su `*JpaCommandPersistence`; sus queries JDBC se conservan sin cambio. `CierrePeriodoSqlServerAdapter` queda sin JDBC.
- Composition Root: `SqlServerAcademicAdapterConfiguration` y `SqlServerCoreRepositoryAdapterConfiguration` inyectan `EntityManager`. Sin `@Repository`, sin scanning, sin selectores ni fallback.
- Tests unitarios: `*JpaCommandPatternTest` (6 clases, 20 tests) y `JpaAcademicUserCommandRulesTest` (4 reglas ArchUnit). Los tests de adapter de command pasan a verificar la delegacion; los de queries no cambian. `UsuarioRepositorySqlServerAdapterTest` ejercita el command JPA real sobre un `EntityManager` simulado.
- Incidencia corregida durante GREEN: un Javadoc de `UsuarioJpaCommandPersistence` citaba literalmente un SP `*_interno`, y `CleanArchitectureRulesTest.codigo_productivo_no_referencia_procedimientos_internos` lo detecto. Se reformulo la nota sin el nombre; la decision no cambia.

### Verificacion de parametros contra la DB viva

Firmas leidas con `sys.parameters` sobre `gestionasistenciadb` (solo lectura) y comparadas con los `@param = :param` de cada SQL JPA:

| SP | Parametros Java | Parametros DB | Resultado |
|---|---|---|---|
| `usp_crear_asignatura` | 10 | 10 | MATCH |
| `usp_actualizar_asignatura` | 9 | 9 | MATCH |
| `usp_toggle_estado_asignatura` | 2 | 2 | MATCH |
| `usp_ejecutar_cierre_masivo_periodo` | 4 | 4 | MATCH |
| `usp_crear_coordinador` | 12 | 12 | MATCH |
| `usp_crear_decano` | 12 | 12 | MATCH |
| `usp_registrar_o_actualizar_plan_estudio` | 5 | — | `SP_NOT_IN_DB` (TD-043; `sys.procedures` sin filas) |
| `usp_sincronizar_usuario` | 9 | — | `SP_NOT_IN_DB` (TD-043; `sys.procedures` sin filas) |

### Paridad SQL Server (BEFORE JDBC vs AFTER JPA)

`AcademicUserCommandsSpParityIT` ejercita los 8 commands solo a traves de puertos de Application. Diff de las lineas `PARITY_OUTCOME` (ordenadas): **vacio, identico linea a linea (8/8)**.

| Escenario | Camino | BEFORE = AFTER |
|---|---|---|
| ASG_01 crear asignatura, plan inexistente | error funcional | identico |
| ASG_02 actualizar asignatura inexistente | error funcional | identico |
| ASG_03 toggle inexistente | error funcional | identico |
| CIE_01 cierre de periodo inexistente | error funcional | identico |
| COO_01 crear coordinador, facultad inexistente | error funcional | identico |
| DEC_01 crear decano, facultad inexistente | error funcional | identico |
| PLA_01 registrar plan, SP ausente | provider MISSING (TD-043) | identico |
| USU_01 sincronizar usuario, SP ausente | provider MISSING (TD-043) | identico |

Limitacion explicita: el IT no muta datos de referencia. **El camino de exito con efectos DB NO fue ejecutado (`NOT_RUN`)**: creacion, actualizacion y toggle exitosos, y el `BEGIN TRANSACTION` de cierre masivo (solo se alcanza con `estadoResultado = 1`). La paridad certificada es de camino de error y de clasificacion, no de efectos DB. Los 6 providers disponibles **no** quedan certificados en camino de exito.

Nota: los escenarios de error devuelven un mensaje generico (`DATABASE_OPERATION_ERROR`), por lo que la igualdad de mensajes no prueba por si sola los nombres de parametro. Esa prueba la aporta la verificacion `sys.parameters` anterior.

### Clean verify y gates

| Gate | Resultado |
|---|---|
| `mvnw clean verify` (unitario, ArchUnit, JaCoCo) | BUILD SUCCESS. Tests **1395**, fallos 0, errores 0, skips 0. "All coverage checks have been met." |
| Targeted unit (127 tests: patrones, ArchUnit JPA, adapters, configs, Grupo/Sesion) | 127/127 PASS |
| `mvnw clean -Pintegration verify` (global) | BUILD FAILURE por integracion: IT **147**, fallos **6**, errores 0, skips 2. Mismo conjunto de fallos por nombre que el baseline JPA-02B. `GLOBAL_INTEGRATION = NOT_GREEN_TD043` (sin cambio). |
| Causa de los 6 fallos | TD-043, verificada en el mensaje: `Contrato SQL incompatible` para `usp_sincronizar_usuario`, `usp_registrar_o_actualizar_plan_estudio` y `usp_registrar_estudiante_en_grupo_usuario_no_existente` (3 en `SqlStoredProcedureContractIT`), mas `Could not find stored procedure` en `GrupoRepositorySqlServerIT` (2) y `UsuarioPasswordHashSqlServerIT` (1). |
| Skips | 2, `DocenteRepositorySqlServerIT` (TD-044), igual que baseline. |
| `JPA03_CAUSAL_INTEGRATION` | `AcademicUserCommandsSpParityIT` 8/8 PASS. Sin fallo causal nuevo. Los 147 - 139 = 8 IT adicionales son los de este IT. |
| ArchUnit | PASS (incluye `JpaAcademicUserCommandRulesTest` y `CleanArchitectureRulesTest`). |
| OpenAPI | Sin cambio de contrato HTTP (no se tocaron controllers ni DTOs publicos). No se ejecuto un gate OpenAPI dedicado; el contrato no cambia. |
| `git diff --check` | exit 0. Unico aviso: EOL de `.env.example` (preexistente, no tocado). |

### Estado de JPA-03

- `JPA03_STATUS`: **NO CERRADO**. Codigo JPA 8/8 (`CODE_MIGRATION_STATUS = JPA`). Paridad certificada solo en camino de error y clasificacion. El DoD exige `6/6 available providers parity PASS` con efectos DB; eso queda `NOT_RUN`.
- `TD043_STATUS`: OPEN sin cambio para `usp_registrar_o_actualizar_plan_estudio` y `usp_sincronizar_usuario`. Su codigo migra a JPA; el provider DB sigue ausente.

### Residual JDBC

- Archivos con JDBC real en `src/main` (mismo criterio de la baseline, descontando el falso positivo `UvDetalleAsistenciaEntity` por Javadoc): **44 → 43**. Sale `CierrePeriodoSqlServerAdapter` (#6).
- `ACADEMIC/USER COMMAND DIRECT JDBC`: 0 en los 6 `*JpaCommandPersistence` (verificado por ArchUnit). En los adapters, JDBC permanece solo en las queries (Asignatura, Coordinador, Decano, PlanEstudio, Usuario), permitido hasta JPA-04/05.
- `CanonicalStoredProcedureExecutor`: **0 consumidores productivos** tras JPA-03. Solo queda su bean en `SqlServerProcedureSupportConfiguration` (#42). Candidato a retiro inmediato o JPA-07 segun el inventario.
- `StoredProcedureQuery` / `ParameterMode` / `createStoredProcedureQuery` en `src/main`: 0.

## Ejecución JPA-03 — cierre de JPA-03 (2026-10-05)

Alcance: completar la evidencia de éxito de los seis providers disponibles, certificar efectos DB JDBC BEFORE vs JPA AFTER y cerrar JPA-03 solo si todos los gates pasan. No se implementó JPA-04. Sin commit ni push.

```
BRANCH:          jose-valencia/lb-004-stateless-serverless-readiness
HEAD:            0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d
WORKTREE_BEFORE: 133 entradas (git status --short), con trabajo previo LB-004/LB-008 sin revertir
WORKTREE_AFTER:  136 entradas (+3 tests nuevos de paridad de éxito y oráculo; sin revertir nada)
```

### Entorno y carga de `.env`

- SQL Server local `gestionasistenciadb` (localhost:1433). Lectura para inspección y los ITs sobre la misma DB.
- `.env` cargado línea a línea, no con `source`: el `;` de `SPRING_DATASOURCE_URL` rompe un `source` de bash. Sin imprimir valores; ninguna credencial aparece en este documento.

### Preflight DB (solo lectura)

- `OBJECT_DEFINITION` de los seis SP de éxito y de sus dependencias (`usp_validar_permiso_rbac_usuario_interno`, `usp_validar_titularidad_jerarquica_interno`, `usp_sincronizar_usuario_interno`).
- Semilla: 1 período (`2026-2`), 1 facultad con decano titular, 1 programa, 2 estudiantes activos en `Grupo 001 - Arq Software`, ejecutores RBAC `DE` (decano), `CD` (coordinador) y `AD` (administrador). `uv_usuario_perfil` cubre los tres roles.
- Hallazgo: el cierre masivo resuelve el período con fallback al más reciente cuando el código no coincide. Registrado en TD-058. No se ejecutó con código inexistente.

### Oráculo JDBC y fixtures (solo `src/test`)

- `AcademicUserJdbcBaselineOracle`: SQL y parámetros replicados de los adapters JDBC históricos de HEAD (`AsignaturaSqlServerAdapter`, `CierrePeriodoSqlServerAdapter`, `CoordinadorSqlServerAdapter`, `DecanoSqlServerAdapter`), ejecutados por el `CanonicalStoredProcedureExecutor` histórico. No es código de producción y no se conecta a `src/main`.
- `AcademicUserParityFixture`: fixtures autocontenidos con prefijo `IT-LB008-JPA03-`, correos `@example.test` y códigos únicos; semilla leída por correo/relación; restauración de `Programa.coordinador` y `Facultad.decano`; limpieza en orden de FK con barrido por prefijo; verificación de residuos = 0.
- Restricción descubierta: `UX_DetalleAsistencia_Asistencia` admite un detalle por asistencia; el fixture de cierre usa tres sesiones.

### Iteraciones de fixture (no de producción)

- `LEN(password) > 0` no es válido en SELECT: corregido con `CASE`.
- Detalle duplicado por asistencia: corregido con tres sesiones.
- El snapshot de usuario incluía `numeroIdentificacion` aleatorio: corregido a presencia.
- Ningún cambio de código JPA ni de SP fue necesario: el código JPA-03 ya migrado no tuvo defecto causal.
- Primera ejecución fallida por `trustServerCertificate` mal cargado desde `.env` (artefacto de carga). Corregido.

### Paridad de éxito (SQL Server real, BEFORE JDBC oráculo vs AFTER JPA)

| Escenario | JDBC_SUCCESS_OUTCOME | JPA_SUCCESS_OUTCOME | DB_EFFECTS_EQUAL |
|---|---|---|---|
| ASG_SUCCESS_01 crear | estado=true; correlación=OK | estado=true; correlación=OK | true |
| ASG_SUCCESS_02 actualizar | estado=true; correlación=OK | estado=true; correlación=OK | true |
| ASG_SUCCESS_03 toggle | estado=true; correlación=OK | estado=true; correlación=OK | true |
| CIE_SUCCESS cierre masivo | estado=true; correlación=OK | estado=true; correlación=OK | true |
| COO_SUCCESS crear coordinador | estado=true; correlación=OK | estado=true; correlación=OK | true |
| DEC_SUCCESS crear decano | estado=true; correlación=OK | estado=true; correlación=OK | true |

`AcademicUserCommandsSuccessParityIT`: **6/6 PASS** (`Tests run: 6, Failures: 0, Errors: 0`), también dentro de `-Pintegration`.

Verificación adicional por escenario:

- CIE_SUCCESS: el fixture ejercita `CI` y `F`; la auditoría contiene `procesados`/`reprobadosPorFallas`; el período compartido de la semilla no cambia.
- COO/DEC: usuario con tipo CC, password presente, correo sin confirmar, estado activo; coordinador o decano vinculado; programa o facultad apuntan al nuevo registro antes de la restauración.
- Guarda: `COUNT(nombre = token) = 1` antes del cierre.

### Error parity y characterization (`AcademicUserCommandsSpParityIT`)

- `Tests run: 8, Failures: 0, Errors: 0` en la ejecución dirigida y en la integración global.
- 6 escenarios de error (ASG_01/02/03, CIE_01, COO_01, DEC_01) idénticos BEFORE = AFTER.
- 2 providers ausentes (PLA_01, USU_01) con characterization `SP_NOT_IN_DB` equivalente. TD-043 OPEN.

### Matriz transaccional

Certificada para la frontera de producción (`TARGET_OUTER_TX = NO`, sin `@Transactional` en los calls). Detalle en [CONTRACT_MATRIX](CONTRACT_MATRIX.md#jpa-03--evidencia-de-exito-y-matriz-transaccional-cerrada-2026-10-05).

- `usp_crear_asignatura`, `usp_actualizar_asignatura`, `usp_toggle_estado_asignatura`: `SP_TX = NO`; éxito ejecutado; sin rollback.
- `usp_ejecutar_cierre_masivo_periodo`: `SP_TX = YES` en éxito (BEGIN/COMMIT); éxito ejecutado; camino CATCH con rollback NO probado.
- `usp_crear_coordinador`, `usp_crear_decano`: `SP_TX = CONDITIONAL`; éxito ejecutado con transacción propia; rama de savepoint (solo con transacción exterior) NO probada y NO certificada como rollback intermedio.

### Gates

| Gate | Resultado |
|---|---|
| Targeted JPA-03 unit (`*JpaCommandPatternTest` x6, `JpaAcademicUserCommandRulesTest`, `JpaCommandIsolationRulesTest`, `ProcedureResultMapperTest`, `ProcedureResultValidatorTest`) | 64/64 PASS |
| `AcademicUserCommandsSpParityIT` | 8/8 PASS |
| `AcademicUserCommandsSuccessParityIT` (nuevo) | 6/6 PASS |
| `mvnw clean verify` | **BUILD SUCCESS**. Tests **1395**, fallos 0, errores 0, skips 0. "All coverage checks have been met." |
| `mvnw clean -Pintegration verify` | BUILD FAILURE por integración (TD-043). Tests **153**, fallos **6**, errores 0, skips 2 |
| ArchUnit | PASS. Incluye `JpaAcademicUserCommandRulesTest` 4/4 |
| OpenAPI / Swagger (dentro de `clean verify`) | `OpenApiGoldenPathConformanceTest` 9/9, `OpenApiGoldenPathValidationTest` 2/2, `SwaggerUiDisabledRuntimeTest` 1/1, `SwaggerUiEnabledRuntimeTest` 4/4 = **16/16 PASS** |
| Cobertura JaCoCo (reporte de la ejecución `-Pintegration`) | LINE **91.65 %** (7999/8728), BRANCH **80.58 %** (1797/2230). Umbrales LINE ≥ 80 % y BRANCH ≥ 70 %: cumplidos |
| `git diff --check` | exit 0. Único aviso: EOL de `.env.example`, preexistente y no tocado |

### Causa de los 6 fallos de integración (no causales)

Verificado en el log: `Could not find stored procedure 'dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente'` (2 en `GrupoRepositorySqlServerIT`), `Could not find stored procedure 'dbo.usp_sincronizar_usuario'` (1 en `UsuarioPasswordHashSqlServerIT`), y `Contrato SQL incompatible` en 3 casos de `SqlStoredProcedureContractIT` (los mismos 3 SP ausentes). Mismo conjunto por nombre que el baseline previo. Los 2 skips son `DocenteRepositorySqlServerIT` (TD-044), sin cambio.

Conteo: 147 (integración previa) + 6 nuevos del IT de éxito = 153. Sin fallo nuevo.

- `GLOBAL_INTEGRATION`: **NOT_GREEN_TD043** (6 fallos conocidos).
- `JPA03_CAUSAL_INTEGRATION`: **PASS**. `AcademicUserCommandsSpParityIT` 8/8, `AcademicUserCommandsSuccessParityIT` 6/6, `JpaAcademicUserCommandRulesTest` 4/4. Sin fallo causal nuevo.

### Residual JDBC (patrón documentado en JDBC_RESIDUAL_INVENTORY)

- `DIRECT_JDBC_GLOBAL = 43` (falso positivo `UvDetalleAsistenciaEntity` descontado).
- `ACADEMIC_USER_COMMAND_DIRECT_JDBC = 0`.
- `DIRECT_JDBC_ASISTENCIA = 0`.
- `CANONICAL_EXECUTOR_PRODUCTIVE_CONSUMERS = 0`. Se mantiene como oráculo de test bajo JPA-07.

### Decisiones y riesgos

- Oráculo y fixtures solo en `src/test`. No se reconectó `CanonicalStoredProcedureExecutor` a runtime.
- La única ruta de cierre ejecutada usa período fixture. El fallback de TD-058 no se ejercita a propósito.
- Riesgo abierto: TD-058 (fallback de resolución de período en el cierre masivo). Preexistente y no causal a JPA. No bloquea JPA-03; requiere decisión del owner DB.

### Estado de JPA-03

- `JPA03_STATUS`: **PASS_WITH_SCOPED_DB_BLOCKER**. Criterios cumplidos: 8/8 code migration JPA; 6/6 providers disponibles con error, éxito y efectos DB; 2/2 providers ausentes con characterization; `ACADEMIC_USER_COMMAND_DIRECT_JDBC = 0`; matriz transaccional certificada para `TARGET_OUTER_TX = NO`; `clean verify` PASS; OpenAPI PASS; ArchUnit PASS; cobertura PASS; sin fallo causal nuevo.
- Bloqueos acotados por DB: TD-043 (`usp_registrar_o_actualizar_plan_estudio`, `usp_sincronizar_usuario`).
- `TD043_STATUS`: OPEN.
- `NEXT_RECOMMENDED_MICROPHASE`: **JPA-04 — CORE VIEW QUERIES**. `JPA-04 STATUS = READY / IMPLEMENTATION_NOT_STARTED`. No implementado.

## Ejecución JPA-04 — CORE VIEW QUERIES (2026-10-05)

### Estado y alcance

`JPA04_STATUS = PASS / CLOSED`. JPA-03 se congela como
`PASS_WITH_SCOPED_DB_BLOCKER`; no se modificaron sus commands, oráculos ni fixtures. Se migraron
solo las lecturas core de Sesión, Grupo, Usuario, Docente, Estudiante y TipoIdentificación.
Application, Domain, HTTP/OpenAPI y el repositorio DB quedaron sin cambios.

Implementación:

- nueve vistas mapeadas como entidades planas `@Entity @Immutable`;
- query persistence por capability con `EntityManager` y JPQL tipado;
- adapters core conservados como puertos neutrales y delegando queries a JPA;
- command persistence JPA-02B/JPA-03 y frontera `TransactionOperations` de Grupo preservados;
- siete `RowMapper` productivos sin consumidores retirados;
- `JdbcValueMapper` retenido por lectores JPA-05, pero eliminado del path core.

### RED congelado

| Evidencia | Resultado |
|---|---|
| Archivo | `src/test/java/co/edu/uco/asistenciasuco/architecture/JpaCoreQueryRulesTest.java` |
| SHA-256 | `01EC344632FB654C1BBAFB34FD8839E0B1BBB061BF5D392441B8DEA89FBFAC81` |
| Comando | `mvnw -Dtest=JpaCoreQueryRulesTest test` |
| Resultado BEFORE | exit 1; 3/3 fallos causales: faltaban seis `*JpaQueryPersistence`, faltaban las entidades requeridas y los adapters core seguían dependiendo de JDBC |
| Freeze | el archivo no se modificó para alcanzar GREEN |

### Paridad SQL Server BEFORE / AFTER

`CoreViewQueriesJpaParityIT` usa JDBC exclusivamente como oráculo en `src/test` y compara contra
las query persistence JPA en la misma DB. Resultado final: **6/6 PASS, 0 fallos, 0 errores, 0 skips**.

Cobertura observable: todas las columnas consumidas de las nueve vistas, row count, orden, null,
booleanos, IDs, búsqueda de usuario por correo/id/identificación, paginación y count de estudiantes,
contextos `distinct`, y not-found de Sesión/Usuario/Docente/Estudiante.

La primera ejecución de paridad falló y produjo dos hallazgos causales:

1. `LocalDateTime` directo en `UvSesionEntity` devolvía `18:00` donde el JDBC congelado devolvía
   `23:00` UTC. La solución JPA final usa el tipo básico JPA `java.util.Date` en la entidad read-only
   y proyecta su instante con `ZoneOffset.UTC`; la paridad real confirma cero shift. No usa
   `java.sql`, `JdbcValueMapper` ni timezone global.
2. `getResultStream().findFirst()` con `setMaxResults(1)` cerraba prematuramente el `ResultSet` de
   mssql-jdbc en Usuario y Docente. Se cambió a `getResultList().stream().findFirst()`, preservando
   `Optional.empty`/`null` y eliminando el error del provider.

### Comandos y resultados

| Comando | Fecha | Resultado |
|---|---|---|
| `mvnw -DskipTests compile` | 2026-10-05 | PASS; 852 fuentes en el corte previo al cleanup |
| `mvnw -DskipTests test-compile` | 2026-10-05 | PASS |
| suite dirigida JPA-04 | 2026-10-05 | 24/24 PASS, 0 skips |
| `mvnw -Pintegration test-compile failsafe:integration-test failsafe:verify -Dit.test=CoreViewQueriesJpaParityIT` | 2026-10-05 | 6/6 PASS, 0 skips |
| `mvnw clean verify` | 2026-10-05 | **BUILD SUCCESS**; 1375 tests, 0 fallos, 0 errores, 0 skips; coverage gates PASS |
| `mvnw clean -Pintegration verify` | 2026-10-05 | **BUILD FAILURE esperado por TD-043**; 159 IT, 6 fallos, 0 errores, 2 skips; `CoreViewQueriesJpaParityIT` 6/6 PASS |
| `git diff --check` | 2026-10-05 | exit 0; warning EOL de `.env.example` preexistente y fuera del delta JPA-04 |

Los seis fallos globales son exactamente los preexistentes: tres contratos de SP ausentes,
dos casos de `GrupoRepositorySqlServerIT` por
`usp_registrar_estudiante_en_grupo_usuario_no_existente`, y uno de
`UsuarioPasswordHashSqlServerIT` por `usp_sincronizar_usuario`. Los dos skips siguen en
`DocenteRepositorySqlServerIT` (TD-044). `JPA04_CAUSAL_INTEGRATION = PASS`.

### Gates y métricas

| Gate | Resultado |
|---|---|
| ArchUnit | PASS; `JpaCoreQueryRulesTest` 3/3 y `JpaCommandIsolationRulesTest` 10/10 |
| OpenAPI/Swagger | 16/16 PASS dentro de `clean verify` |
| JaCoCo (`clean verify` final) | LINE **87.24 %** (7505/8603), BRANCH **78.18 %** (1723/2204) |
| JDBC core | BEFORE 13 archivos asignados por inventario; AFTER **0** archivos con patrón JDBC |
| JDBC global real | **43 → 29**; búsqueda bruta final 30, menos `UvDetalleAsistenciaEntity` (Javadoc) |
| RowMapper productivos | solo 1 residual global; los 7 RowMapper del slice core fueron retirados |

### Limitaciones y siguiente fase

- La DB live no contiene filas con `uv_grupo.cuposDisponibles = NULL`; la preservación de null está
  en el tipo nullable y la comparación cubre las filas disponibles. No se inventó fixture DB.
- La unicidad de `uv_estudiante(id,idGrupo)` no tiene constraint propia en schema; sigue activa la
  stop condition `BLOCKED_BY_VIEW_IDENTITY` si aparece un duplicado futuro.
- TD-043, TD-044 y TD-058 permanecen abiertas y no son causales de JPA-04.
- `NEXT_RECOMMENDED_MICROPHASE = JPA-05 — ACADEMIC / AUTHORIZATION / REPORTING QUERIES`.
  `JPA-05 STATUS = NOT_STARTED`; no se inicia automáticamente.

## JPA-05 — EVIDENCIA EJECUTADA (2026-10-05)

Alcance: academic (14 adaptadores migrados, `EstudiantePrograma` bloqueado), autorización (`InstitutionalScopeSqlServerAdapter`) y reporte (`ReporteAsistenciaSqlServerAdapter`). Sin commit ni push. HEAD `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d`.

### Correcciones JPA-04 (sección 2)
- JPA04_CLEANUP: Javadocs de `SqlServerCoreRepositoryAdapterConfiguration` actualizados (sin selector ni fallback JDBC). Wiring sin cambio.
- CORE_CONFIG_JAVADOC: PASS.
- UTC_JAVADOC: `JdbcValueMapper` apunta al helper real. Nota: `CoreViewJpaProjectionMapper.toUtcLocalDateTime` era `private`; se hizo `public static` (misma semántica) para que reporte y sesión materia reutilicen la conversión certificada.
- CONTRACT_MATRIX_CORE_STATUS: sección "Estado por consumidor" con 9 vistas, separando CORE de OTHER. Tabla histórica conservada.

### RED / GREEN
- RED_EXPECTED: `JpaAcademicQueryRulesTest` falla por JDBC en adaptadores, `AreaJpaQueryPersistence` ausente, `UvAreaEntity` ausente.
- RED_OBSERVED: 4 de 5 pruebas fallan (la quinta, de ausencia de duplicados, pasa).
- GREEN: 14 de 16 adaptadores del scope ya no importan JDBC. Las 3 pruebas que pasaban en el scope (`no_usan_rowmapper`, `query_persistence_requerida`, `vistas_nuevas`) pasan.
- Pendiente: la regla de JDBC sigue fallando solo por `EstudianteProgramaSqlServerAdapter` (bloqueado). El RED no se modificó.

### Paridad contra SQL Server real (`gestionasistenciadb`)
- `AcademicQueryJpaParityIT`: 8/8 PASS, 0 skips.
- `AuthorizationReportJpaParityIT`: 4/4 PASS, 0 skips (tras corregir un cast UUID en el helper de test; el defecto era del test, no de producción).
- `CoreViewQueriesJpaParityIT` (regresión JPA-04): 6/6 PASS.
- Matriz de seguridad: se verificó al menos un caso permitido y uno denegado observados; usuario, grupo, programa y facultad desconocidos; email exacto y en mayúsculas; sin email inexistente.
- Paridad de orden, nulos (`asistio`, `razonCausa`, `idDecano`, horas), UTC (sesiones y reporte) y Optional/not-found: cubiertas por igualdad de listas y de Optional contra el oráculo JDBC copiado.

### Gate global
- `mvnw clean verify` (sin perfil integración): Tests run 1355, Failures 2, Errors 0, Skipped 0, BUILD FAILURE.
- Los 2 fallos son `JpaAcademicQueryRulesTest` (RED), causados por `EstudianteProgramaSqlServerAdapter`. Ninguno es regresión.
- Cobertura JaCoCo, OpenAPI y `clean verify -Pintegration` completo: NO EJECUTADOS como gate PASS. JaCoCo no corre porque surefire falla antes. Pendiente tras resolver el bloqueo.
- `git diff --check`: exit 0 (solo aviso CRLF preexistente de `.env.example`).

### Bloqueo
- `BLOCKED_BY_VIEW_IDENTITY` — `EstudiantePrograma` / `uv_estudiante_programa`. Ver CONTRACT_MATRIX, sección BLOCKED. La vista hace join con `uv_estudiante` (una fila por estudiante y grupo) y no existe clave que distinga filas duplicadas. La tabla viva tiene 0 filas.
- Consecuencia: JPA-05 **no puede cerrar** según su DoD (`direct JDBC in JPA-05 query paths = 0` y `clean verify PASS`). Requiere decisión del owner de DB o del equipo sobre una clave de identidad para esa vista.

### Conteos
- ROWMAPPERS_BEFORE: 0 productivos en scope (ya retirados en JPA-04). ROWMAPPERS_AFTER: 0.
- JDBC_VALUE_MAPPER_CONSUMERS: siguen existiendo consumidores fuera de scope (catálogo, auditoría, SP executor). Ver JDBC_RESIDUAL_INVENTORY.
- DIRECT_JDBC_JPA05_BEFORE: 16 adaptadores/config de scope con JDBC. DIRECT_JDBC_JPA05_AFTER: 1 adaptador (`EstudianteProgramaSqlServerAdapter`) + su bean en `SqlServerAcademicAdapterConfiguration`.
- DIRECT_JDBC_GLOBAL_BEFORE: 29 archivos reales. DIRECT_JDBC_GLOBAL_AFTER: 11 archivos reales (excluyendo el falso positivo Javadoc `UvDetalleAsistenciaEntity`). Gate `< 29`: CUMPLIDO.

### Identidad de vistas (IDENTITY_EVIDENCE)
- Nuevas, `id` simple: `uv_area`, `uv_asignatura`, `uv_coordinador_identidad`, `uv_decano_identidad`, `uv_facultad`, `uv_horario_docente`, `uv_institucion`, `uv_parametro`, `uv_periodo_academico`, `uv_plan_estudio`, `uv_semestre_plan_estudio`.
- `@IdClass(id, idPrograma)`: `uv_coordinador` (1:N estructural).
- `@IdClass(id, idFacultad)`: `uv_decano` (1:N estructural).
- `@IdClass(id, idEstudiante)`: `uv_horario_estudiante`. Evidencia viva 2/2; sin unicidad en la base `EstudianteGrupo`. Si aparece un duplicado: BLOCKED para esa capacidad.
- BLOCKED: `uv_estudiante_programa`.
- Sin entidades duplicadas para autorización: se reutilizan `UvUsuarioEntity`, `UvGrupoEntity`, `UvEstudianteGrupoEntity`, `UvEstudianteIdentidadEntity`, `UvDocenteIdentidadEntity`.

### Archivos
- Creados (entidades): `UvAreaEntity`, `UvInstitucionEntity`, `UvParametroEntity`, `UvPeriodoAcademicoEntity`, `UvFacultadEntity`, `UvPlanEstudioEntity`, `UvSemestrePlanEstudioEntity`, `UvAsignaturaEntity`, `UvCoordinadorEntity`, `UvCoordinadorIdentidadEntity`, `UvDecanoEntity`, `UvDecanoIdentidadEntity`, `UvHorarioDocenteEntity`, `UvHorarioEstudianteEntity`, más 3 `*EntityId` de `IdClass`.
- Creados (projection): 15 `*QueryRow`.
- Creados (query persistence): 16 `*JpaQueryPersistence` (incluye `InstitutionalScopeJpaQueryPersistence` y `ReporteAsistenciaJpaQueryPersistence`).
- Creados (mapper): `AcademicViewJpaProjectionMapper`.
- Modificados: `UvDetalleAsistenciaEntity` (+`nombreRazonCausa`), `CoreViewJpaProjectionMapper.toUtcLocalDateTime` (privado a público), 14 adaptadores académicos + `InstitutionalScope` + `Reporte` (query → JPA), `SqlServerAcademicAdapterConfiguration`, `SqlServerSecurityScopeAdapterConfiguration`, `SqlServerReportAdapterConfiguration`, `JdbcValueMapper` (Javadoc).
- Modificados (tests): 4 tests de comandos (constructor `(queries, commands)`).
- Creados (tests): `JpaAcademicQueryRulesTest` (RED), `AcademicViewJpaProjectionMapperTest`, `AcademicQueryJpaParityIT`, `AuthorizationReportJpaParityIT`, oráculo `jpa/baseline/*JdbcBaseline` (17 copias literales del JDBC previo).
- Eliminados (tests): 7 tests unitarios que solo validaban JDBC con mocks (`FacultadSqlServerAdapterTest`, `HorarioDocenteSqlServerAdapterTest`, `HorarioEstudianteSqlServerAdapterTest`, `PeriodoAcademicoSqlServerAdapterTest`, `SesionMateriaEstudianteSqlServerAdapterTest`, `InstitutionalScopeSqlServerAdapterTest`, `ReporteAsistenciaSqlServerAdapterTest`). Su cobertura pasa a las ITs de paridad contra SQL Server real.
- Actualizados: CONTRACT_MATRIX (sección JPA-05 y estado por consumidor).

### Estado de fase (HISTORICAL SNAPSHOT — superado por "JPA-05 — CIERRE")
- JPA04 = PASS / CLOSED (sin cambios de código salvo las correcciones documentales y la visibilidad del helper UTC).
- JPA05 = NOT CLOSED en ese corte. **Superado:** la identidad de `uv_estudiante_programa` se alineó en la DB y JPA-05 cerró (ver la sección siguiente).
- NEXT_RECOMMENDED_MICROPHASE de ese corte: no aplica. Vigente: JPA-06 (ver "JPA-06 — EJECUCIÓN").

## JPA-05 — CIERRE (2026-10-05)

Alcance: academic (15/15 consultas JPA incl. `EstudiantePrograma`), autorización (`InstitutionalScope`) y reporting (`ReporteAsistencia`).
DB: `LB-008 JPA-05 DB view identity alignment` (`docs/work-items/LB-008-JPA05-db-view-identity-alignment/` en el repo DB).
HEAD backend de la ejecución: `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d` (rama `jose-valencia/lb-004-stateless-serverless-readiness`, sin commit de esta microfase).

### Cambios de esta microfase
- `UvEstudianteProgramaEntity` (`@Entity @Immutable`, `@Id` = `id`, sin `@IdClass`, sin relaciones, sin escritura).
- `EstudianteProgramaProjection` ← `EstudianteProgramaQueryRow` (JPQL constructor projection) ← `EstudianteProgramaJpaQueryPersistence` (`EntityManager`). Mismo filtro y orden que el SQL JDBC: `ORDER BY ei.nombreCompleto, ep.id`.
- `EstudianteProgramaSqlServerAdapter` queda como delegador fino. `SqlServerAcademicAdapterConfiguration`: bean residual JDBC sustituido por wiring `EntityManager`; import `NamedParameterJdbcOperations` eliminado.
- `InstitutionalScopeJpaQueryPersistence`: `canDocenteAccessGrupo` y `canEstudianteAccessGrupo` ejecutan una sola sentencia nativa (`createNativeQuery`) con el SQL original (`SELECT TOP 1`, parámetros nombrados). Se elimina la ventana TOCTOU de dos lecturas. Javadoc actualizado.
- `JpaAcademicQueryRulesTest`: solo se agregaron a las listas requeridas `EstudianteProgramaJpaQueryPersistence` y `UvEstudianteProgramaEntity`. No se relajó ninguna regla.

### Evidencia

```text
DB:
  deploy_schema.ps1 -ContainerName sql_server_asistencias                 -> exit 0
  test_summary.ps1 -ContainerName sql_server_asistencias                  -> DB GATE PASS
  línea base previa: TOTAL_EXPECTED=154 FAILED=0 SKIPPED=1 (allowed)
  tras el cambio:    TOTAL_EXPECTED=158 TOTAL_EXECUTED=161 PASSED=160 FAILED=0 SKIPPED=1 (allowed) CRITICAL_MISSING=0 UNAUTHORIZED_SKIPS=0 @@TRANCOUNT=0

Backend targeted (unit):
  JpaAcademicQueryRulesTest 5/5, EstudianteProgramaJpaQueryPersistenceTest 4/4,
  InstitutionalScopeSingleStatementPatternTest 5/5, CoreViewJpaQueryErrorSemanticsTest 2/2

Backend targeted (IT, SQL Server real):
  EstudianteProgramaJpaParityIT 1/1, AcademicQueryJpaParityIT 8/8,
  AuthorizationReportJpaParityIT 4/4, CoreViewQueriesJpaParityIT 6/6  -> 19/19 PASS

mvnw clean verify (unit + ArchUnit + OpenAPI + JaCoCo):
  Tests run: 1364, Failures: 0, Errors: 0, Skipped: 0 -> BUILD SUCCESS
  All coverage checks have been met (LINE 84.20% >= 80%, BRANCH 77.18% >= 70%)

mvnw clean verify -Pintegration (SQL Server real, APP_DATABASE_EXPECTED_NAME=gestionasistenciadb):
  Tests run: 172, Failures: 6, Errors: 0, Skipped: 2 -> BUILD FAILURE (GLOBAL_INTEGRATION = NOT_GREEN_TD043)
```

### Fallos de integración: análisis causal
Los 6 fallos tienen una única causa, TD-043 (SP ausentes en la DB oficial). No hay fallo causal JPA-05:
- `SqlStoredProcedureContractIT` [1] `usp_sincronizar_usuario`, [7] `usp_registrar_o_actualizar_plan_estudio`, [12] `usp_registrar_estudiante_en_grupo_usuario_no_existente`: `esperaba procedimiento almacenado existente`.
- `GrupoRepositorySqlServerIT` (2): `Could not find stored procedure 'dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente'`.
- `UsuarioPasswordHashSqlServerIT` (1): `Could not find stored procedure 'dbo.usp_sincronizar_usuario'`.
- Skips (2): `DocenteRepositorySqlServerIT`, caso TD-044 (`assumeTrue` por datos).
- Primera corrida: 1 error adicional en `SqlServerConnectionIT` por `APP_DATABASE_EXPECTED_NAME` no definida en el entorno de ejecución. No es código. Se resolvió definiendo la variable en la segunda corrida; el error desaparece y quedan solo los 6 TD-043.
- La comparación se hace por causa: los nombres exactos de los casos TD-043 no están listados en el baseline documental. Cada fallo cita el SP ausente.

### Criterio final JPA-05

```text
DB_VIEW_ALIGNMENT:              PASS
uv_estudiante_programa:         una fila por EstudiantePrograma.id
EstudiantePrograma backend:     JPA_ONLY
JPA05_QUERY_PATHS (JDBC):       0
AUTHORIZATION (single-stmt):    PASS
ACADEMIC PARITY:                PASS (8/8)
AUTHORIZATION PARITY:           PASS (4/4)
REPORTING PARITY:               PASS (dentro de AuthorizationReportJpaParityIT)
ERROR SEMANTICS:                DATABASE_OPERATION_ERROR certificado (unit + GlobalExceptionHandlerTest)
clean verify:                   PASS (1364/0)
full integration:               NOT_GREEN_TD043, sin fallo causal JPA-05
JPA-05:                         PASS
```

### Estado de la deuda
- TD-043 OPEN (3 SP ausentes). TD-044 OPEN (2 skips). TD-058 OPEN / HIGH / DB_OWNER. Este cambio no los corrige.
- TD-055: JDBC residual en `src/main` = 9 archivos reales (ver JDBC_RESIDUAL_INVENTORY §Cierre JPA-05). Sigue ABIERTA hasta JPA-07.

### Canonical executor
`CANONICAL_EXECUTOR_PRODUCTIVE_CONSUMERS = 0`. Solo lo instancia su bean (`SqlServerProcedureSupportConfiguration`). No se reintrodujo consumidor. Retiro en JPA-07.

NEXT_RECOMMENDED_MICROPHASE: **JPA-06 — CATALOGS + AUDIT + AUXILIARY PERSISTENCE** (no implementada en esta ejecución).


## JPA-05 — CIERRE CONSOLIDADO (congelado, 2026-10-05)

Esta sección consolida el cierre de JPA-05 sin reabrir su código. No cambia `uv_estudiante_programa`, `EstudiantePrograma`, `DB_BASELINE_CONTRACT` ni el Golden Path manifest.

| Gate | Resultado |
|---|---|
| Academic parity | PASS |
| Authorization parity | PASS |
| Reporting parity | PASS |
| EstudiantePrograma parity (`EstudianteProgramaJpaParityIT`) | PASS |
| Clean verify (unit) | PASS (ver JPA-06) |
| OpenAPI | PASS (clases de conformidad del verify: 9 + 2 + 1 tests, 0 fallos) |
| ArchUnit | PASS |
| Coverage | PASS (`jacoco:check` cumplido) |
| `GLOBAL_INTEGRATION` | `NOT_GREEN_TD043` |
| `JPA05_CAUSAL` | PASS |

**Estado:** JPA-05 = **PASS / CLOSED**. TD-043, TD-044 y TD-058 permanecen OPEN (sin cambio).
**Identidad temporal de `uv_estudiante_programa`:** no existe deuda abierta registrada en `TECHNICAL_DEBT.md` con ese
nombre (búsqueda por texto). El bloqueo `BLOCKED_BY_VIEW_IDENTITY` quedó resuelto por la alineación DB y se documenta como `RESOLVED`.

## JPA-06 — EJECUCIÓN (2026-10-05)

### Estado

- **Catálogos:** PASS (JPA-only).
- **Auditoría:** `BLOCKED_BY_TD010_DECISION`. No se implementó.
- **JPA-06 global:** `NOT_CLOSED / BLOCKED_BY_TD010`.
- **Siguiente:** no iniciar JPA-07 automáticamente.

### Cambios de código

- Nuevas: `CatalogJpaQueryPersistence`, `UvMensajeUsuarioEntity`, `UvMensajeTecnicoEntity` (`@Entity @Immutable`),
  `CatalogJpaParityIT`, `CatalogJdbcBaseline` (solo `src/test`), `JpaCatalogRulesTest` (RED).
- Modificadas: `SqlServerMessageCatalogAdapter`, `SqlServerParameterCatalogAdapter`, `SqlServerCatalogAdapterConfiguration`,
  `SqlServerMessageCatalogAdapterTest`, `SqlServerParameterCatalogAdapterTest`, `CatalogAdapterConfigurationTest` (wiring:
  mock de `EntityManager` en lugar de `NamedParameterJdbcTemplate`).
- Reutilizada: `UvParametroEntity`.
- Sin cambios en DB, schema, vistas, SP ni contratos HTTP.

### RED / GREEN

- RED: `JpaCatalogRulesTest` 4/4 fallos, 0 errores (12 + 2 violaciones JDBC; clase y entidades inexistentes).
- GREEN: `JpaCatalogRulesTest` 4/4 PASS. Unitarios de catálogo 34/34 PASS (18 + 16).
- Paridad: `CatalogJpaParityIT` 11/11 PASS contra SQL Server real, 0 skips.

### Conteos

- `CATALOG_JDBC_BEFORE = 3` archivos (#1, #2, #3) → `CATALOG_JDBC_AFTER = 0`.
- `AUDIT_JDBC_BEFORE = 2` (#4, #5) → `AUDIT_JDBC_AFTER = 2` (bloqueado).
- `DIRECT_JDBC_GLOBAL_BEFORE = 9` → `DIRECT_JDBC_GLOBAL_AFTER = 6` (grep real en `src/main`, Javadoc de `UvDetalleAsistenciaEntity` descontado).
- `JDBC_VALUE_MAPPER_PRODUCTIVE_CONSUMERS = 1` (`CanonicalProcedureResultMapper`).
- `CANONICAL_RESULT_MAPPER_CONSUMERS = 1` (`CanonicalStoredProcedureExecutor`).
- `CANONICAL_EXECUTOR_PRODUCTIVE_CONSUMERS = 0` en `src/main`; 9 clases de test lo inyectan o instancian (ver JDBC_RESIDUAL_INVENTORY).
- `StoredProcedureQuery` / `ParameterMode` en `src/main` = 0.

### Gates (última ejecución: `clean verify` y `clean verify -Pintegration`)

- `clean verify` (unit): **1368 tests, 0 failures, 0 errors, 0 skips**. Cobertura **cumplida** (jacoco:check).
  ArchUnit PASS. OpenAPI PASS. `BUILD SUCCESS`.
- `clean verify -Pintegration`: **183 tests, 6 failures, 0 errors, 2 skips**. `BUILD FAILURE`.
  - Los 6 fallos son `DatabaseOperationException: No fue posible ejecutar el procedimiento almacenado`, causados por SP ausentes en la DB (TD-043):
    `SqlStoredProcedureContractIT` ×3, `GrupoRepositorySqlServerIT` ×2 (`usp_registrar_estudiante_en_grupo_usuario_no_existente`),
    `UsuarioPasswordHashSqlServerIT` ×1 (`usp_sincronizar_usuario`).
  - Los 2 skips son TD-044 (`DocenteRepositorySqlServerIT`).
  - **Fallo causal nuevo de JPA-06: ninguno.** Catálogos y el resto de ITs de Asistencia pasan.
  - `GLOBAL_INTEGRATION = NOT_GREEN_TD043`. No se declara PASS global.
- `JPA06_CAUSAL_INTEGRATION = PASS` (sin fallo causal nuevo).
- `git diff --check`: sin errores de espacios en blanco (solo aviso de fin de línea CRLF/LF pre-existente en `.env.example`).

### Pendiente

- **D-JPA06-01** (lectura sobre vistas sin `NOLOCK`): confirmación humana requerida.
- **TD-010**: decisión A o B del owner DB. Sin ella, JPA-06 no cierra.
- **JPA-07**: `JdbcValueMapper`, `CanonicalProcedureResultMapper`, `CanonicalStoredProcedureExecutor` y su configuración; migrar oráculos/ITs que lo inyectan.

## JPA-06A — EJECUCIÓN Y CIERRE (2026-10-06)

Ejecución de limpieza y cierre de la arquitectura `Port -> @Repository XxxJpaRepository -> EntityManager -> SQL Server`
([ADR-004](../../adr/ADR-004-jpa-repository-architecture.md)). Sin cambios de DB, SP, views, contratos HTTP, transacciones,
UTC, null, ordering ni autorización. Sin commit ni push. Sin `reset --hard`, `clean`, `stash` ni checkout destructivo.
JPA-06B/TD-010 y JPA-07 no se implementan.

### Git y entorno

```text
BRANCH:          jose-valencia/lb-004-stateless-serverless-readiness
HEAD:            0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d
WORKTREE_BEFORE: 455 entradas (git status --short, al inicio de la ejecución)
WORKTREE_AFTER:  227 entradas (99 ??, 87 D, 41 M)
JAVA_VERSION:    25 (Maven con JAVA_HOME=C:\Program Files\Java\jdk-25; ArchUnit registra "Detected Java version 25").
                 El `java -version` del PATH es 17 y no se usó para certificar.
```

La reducción 455 → 227 corresponde a 229 archivos cuyo único cambio era de fin de línea (CRLF/LF) y que git dejó de
considerar modificados. No es pérdida de trabajo: `git diff --ignore-cr-at-eol --stat` mantiene 128 archivos con
cambio de contenido (verificado sobre `pom.xml`, `SKILL.md` y `LINEA_BASE.md`).

### Cambios de esta ejecución

1. **Organización interna de 8 repositorios con doble logger** (Asignatura, Asistencia, Coordinador, Decano, Grupo,
   PlanEstudio, Sesion, Usuario): orden de plantilla (`@Repository`, LOGGER único, SQL/HQL, campos, constructor,
   COMMANDS, QUERIES, PRIVATE HELPERS, ERROR HELPERS). Verificación: multiconjunto de líneas no vacías idéntico al
   respaldo previo salvo nombres de logger y marcadores de sección. Se conservan `TransactionOperations` de Grupo, los
   named parameters y la visibilidad de los helpers usados por tests.
2. **Defecto de runtime corregido: repositories `final`.** La paridad SQL Server falló al arrancar el contexto:
   `Cannot subclass final class ...DecanoJpaRepository`. `@Repository` activa la traducción de excepciones, que proxea
   el bean; Spring Boot usa CGLIB por defecto. Se quitó `final` a los 27 repositories (`public class`). Evidencia:
   test RED `JpaRepositoryBeanUniquenessTest#repositories_jpa_son_proxiables_con_traduccion_de_excepciones_de_persistencia_y_cglib`
   (fallo por clase final) y GREEN tras el cambio. Enmienda en ADR-004. Se descartó `proxy-target-class=false` global
   porque cambiaría el proxying de toda la aplicación.
3. **Nuevo test de unicidad de beans** `JpaRepositoryBeanUniquenessTest`: contexto Spring con component scanning del
   paquete de repositories, `EntityManager` y `TransactionOperations` simulados, sin SQL. Verifica 27 repositories,
   una sola implementación por Port y ninguna implementación JPA compitiendo con los providers de catálogo alternativos
   (`AZURE`, `AZURE_APPCONFIG`). Cubre BM-06A-05.
4. **Javadoc stale actualizada** sin tocar comportamiento: `JdbcValueMapper` (clases JDBC retiradas) y
   `AcademicUserCommandsSuccessParityIT` (`*JpaCommandPersistence` → repository JPA directo).
5. **Helper de test renombrado:** `CatalogJpaRepository` → `CatalogJpaParityHarness` (solo `src/test`). Su Javadoc
   declara que no es un `@Repository` productivo.
6. **Restos documentales:** eliminadas las carpetas vacías `sqlserver/{core,academic,reporting,authorization}` en `src/main`.
7. **Documentación activa corregida:** `backend-package-structure.md`, `infrastructure-structure.md`,
   `repository-mock-inventory.md`, `GOLDEN_PATH_ASISTENCIA.md`, `LINEA_BASE.md` (golden path actual y catálogos) y
   ADR-004 (enmienda y selector documentado).
8. **Whitespace:** `git diff --check` marcaba 244 archivos con líneas vacías al final; se recortaron (solo espacios en
   blanco, sin cambio funcional).

### QueryRow — revisión individual

`QUERY_ROWS_BEFORE = 8`, `QUERY_ROWS_AFTER = 8`, todos retenidos. Cada uno resulta de una consulta JPQL multi-entidad;
ninguno duplica 1:1 una entity.

| QueryRow | QUERY_ROWS_RETAINED | REASON |
|---|---|---|
| `AsignaturaQueryRow` | sí | JOIN `UvAsignaturaEntity` × `UvSemestrePlanEstudioEntity`; `idPlanEstudio`/`idPrograma` vienen del semestre |
| `AsistenciaQueryRow` | sí | JOIN de detalle × asistencia × estudiante-grupo (3 vistas) |
| `EstudianteGrupoQueryRow` | sí | JOIN estudiante-grupo × identidad × usuario |
| `EstudianteProgramaQueryRow` | sí | FROM multi-entidad: estudiante-programa × identidad × usuario |
| `EstudianteResumenQueryRow` | sí | JOIN identidad × usuario (`BASE_FROM`) |
| `MateriaEstudianteQueryRow` | sí | FROM estudiante-grupo × grupo × asignatura, `distinct` |
| `ReporteAsistenciaQueryRow` | sí | JOIN múltiple del reporte por grupo, con LEFT JOIN al detalle de asistencia |
| `SesionMateriaQueryRow` | sí | FROM sesión × estudiante-grupo × grupo |

Mappers: `CoreViewJpaProjectionMapper`, `AcademicViewJpaProjectionMapper` y `AsistenciaJpaProjectionMapper` se conservan:
contienen conversiones reales (UTC, booleanos, horas) compartidas por varios repositories. No se fusionaron ni se dividieron.

### Métricas BEFORE / AFTER

| Métrica | BEFORE | AFTER |
|---|---:|---:|
| Repositories `@Repository` directos | 27 | 27 |
| Adapters delegadores de persistencia | 27 (cifra del PLAN, JPA-06A BEFORE) | 0 |
| `*JpaCommandPersistence` / `*JpaQueryPersistence` | 9 / 25 (cifra del PLAN) | 0 / 0 |
| Beans manuales de repositories | 27 (cifra del PLAN) | 0 |
| `QueryRow` | 26 (cifra del PLAN) → 8 (estado de entrada de esta ejecución) | 8 retenidos |
| LOC del paquete repository | 3174 | 3197 (+23 por secciones y Javadoc; sin minimizar) |
| LOC JPA-relacionado (`sqlserver/**`, configs de persistencia, `catalog/sqlserver`; 85 archivos) | no reproducible desde HEAD | 6387 |
| JDBC directo en `src/main` (archivos) | 6 | 6 |

Nota de medición: las cifras BEFORE del PLAN (66 clases / 4393 LOC) usan un alcance que no se puede reconstruir desde
`HEAD` (`0b7905c`), porque el estado previo a JPA-06A es trabajo sin commit. El delta se reporta contra el estado de
entrada de esta ejecución. El JDBC directo no aumenta: son los 6 archivos esperados (`JdbcValueMapper`,
`CanonicalProcedureResultMapper`, `CanonicalStoredProcedureExecutor`, `AuditEventJdbcRepository`,
`SqlServerAuditSupportConfiguration`, `SqlServerProcedureSupportConfiguration`).

### Criterios estructurales

| Criterio | Resultado | Evidencia |
|---|---|---|
| 27 repositories directos | PASS | 27 `@Repository`; ArchUnit `JpaRepositoryArchitectureRulesTest` 3/3 |
| `@Repository` en lugar de `@Component` | PASS | 0 `@Component` en repositories |
| `EntityManager` directo por constructor | PASS | 27/27 con campo `EntityManager` y constructor por inyección |
| Implementa Port directamente | PASS | 27/27 `implements ...Port`; sin wrappers (ArchUnit) |
| Un logger por repository | PASS | 25 con `LOGGER`; 2 de catálogo sin logger; 0 `COMMAND_LOGGER`/`QUERY_LOGGER` |
| SP visibles en el repository | PASS | 9 repositories de comandos con `EXEC dbo.usp_*` textual |
| Sin JDBC en repositories | PASS | 0 `java.sql`/`jdbc` en `jpa/repository` (ArchUnit) |
| Sin beans manuales ni `new XxxJpaRepository` | PASS | 0 coincidencias fuera del paquete |
| Única implementación por Port | PASS | `JpaRepositoryBeanUniquenessTest` 3/3 |
| Documentación activa limpia | PASS con excepción | ver "Alcance de documentación" |

### Alcance de documentación

- **Limpio:** documentación normativa y de arquitectura activa, golden path, inventario de mocks y ADR-004.
- **Conservado como registro histórico** (no describe la arquitectura vigente): evidencia de deuda en
  `TECHNICAL_DEBT.md` (TD con los nombres del momento), bitácora de `LINEA_BASE.md`, contexto de ADR-004 y work items
  históricos (LB-000, LB-001*, LB-002, LB-003).
- Requiere confirmación humana si también los registros históricos deben reescribirse.

### Gates ejecutados (estado final)

| Gate | Comando | Resultado |
|---|---|---|
| Targeted | `-Dtest=JpaRepositoryArchitectureRulesTest,JpaRepositoryBeanUniquenessTest,AsignaturaJpaCommandPatternTest,InstitutionalScopeSingleStatementPatternTest,AsistenciaJpaQueryPersistenceTest,CierrePeriodoJpaCommandPatternTest test` | PASS (EXIT 0) |
| CLEAN_VERIFY | `.\mvnw.cmd clean verify` (Java 25) | PASS: EXIT 0; TESTS 1269; FAILURES 0; ERRORS 0; SKIPS 0 |
| SQLSERVER_PARITY | `-Pintegration` con las 11 clases de paridad sobre `gestionasistenciadb` | PASS: 86 tests; FAILURES 0; ERRORS 0; SKIPS 0 |
| FULL_INTEGRATION | `.\mvnw.cmd clean verify -Pintegration` | EXIT 1: 183 tests; FAILURES 6; ERRORS 0; SKIPS 2. Ver clasificación |
| ARCHUNIT | dentro de `clean verify` | PASS (`JpaRepositoryArchitectureRulesTest` 3/3; suite de arquitectura en verde) |
| OPENAPI | `OpenApiGoldenPathConformanceTest` 9/9; `OpenApiGoldenPathValidationTest` 2/2 | PASS |
| LINE_COVERAGE | JaCoCo `check` (≥ 80 %) | 81.96 % — PASS ("All coverage checks have been met") |
| BRANCH_COVERAGE | JaCoCo `check` (≥ 70 %) | 74.53 % — PASS |
| GIT_DIFF_CHECK | `git diff --check` | PASS (exit 0) |

Las 11 clases de paridad son: `AsistenciaCommandJpaParityIT`, `AsistenciaQueryJpaParityIT`,
`SesionGrupoCommandsSpParityIT`, `CoreViewQueriesJpaParityIT`, `AcademicQueryJpaParityIT`,
`AcademicUserCommandsSpParityIT`, `AcademicUserCommandsSuccessParityIT`, `AuthorizationReportJpaParityIT`,
`EstudianteProgramaJpaParityIT`, `CatalogJpaParityIT` y `PersistenceTransactionParityIT`.

### Clasificación de integración global

`GLOBAL_INTEGRATION = NOT_GREEN_TD043` (esperado). Ningún fallo es causal de JPA-06A:

| Fallo | Causa observada | Clasificación |
|---|---|---|
| `SqlStoredProcedureContractIT` [1] | `usp_sincronizar_usuario` no existe en la DB | TD-043 |
| `SqlStoredProcedureContractIT` [7] | `usp_registrar_o_actualizar_plan_estudio` no existe en la DB | TD-043 |
| `SqlStoredProcedureContractIT` [12] | `usp_registrar_estudiante_en_grupo_usuario_no_existente` no existe en la DB | TD-043 |
| `GrupoRepositorySqlServerIT` (2 casos) | SQL Server 2812 "Could not find stored procedure" sobre el mismo SP | TD-043 |
| `UsuarioPasswordHashSqlServerIT` | SQL Server 2812 "Could not find stored procedure" sobre `usp_sincronizar_usuario` | TD-043 |
| Skips (2) en `DocenteRepositorySqlServerIT` | `assumeTrue`: no hay datos de docente con las condiciones de la base local | TD-044 |

`JPA06A_CAUSAL_INTEGRATION = 0` fallos nuevos. Los tres SP son exactamente los de TD-043 en `JDBC_RESIDUAL_INVENTORY.md`.

### Deudas

- **TD-010** — `OPEN / DECISION_REQUIRED (owner DB)`: auditoría con DML directo. Bloquea JPA-06B.
- **TD-043** — `OPEN / SCOPED_BLOCKER`: 3 SP ausentes en la DB; origina los 6 fallos de integración global.
- **TD-044** — `OPEN / NON_BLOCKING`: 2 skips de `DocenteRepositorySqlServerIT`.
- **TD-058** — `OPEN` (cierre masivo de periodo con fallback). No relacionada con JPA-06A; sin cambios.
- **TD-055** — JDBC residual: 6 archivos. Se mantiene hasta JPA-06B (auditoría) y JPA-07 (soporte de procedimientos).

### Estado de fase

```text
JPA-06A = PASS / CLOSED
JPA-06  = NOT_CLOSED / BLOCKED_BY_TD010 (catálogos PASS; auditoría BLOCKED_BY_TD010_DECISION)
JPA-07  = NOT_STARTED
```

Los criterios técnicos están en PASS. La única salvedad es la documentación histórica descrita arriba; si el equipo
exige reescribir también los registros históricos, JPA-06A pasa a `PASS_PENDING_DOC_HISTORY`.

### Siguiente microfase

`NEXT_RECOMMENDED_MICROPHASE = JPA-06B — AUDIT PERSISTENCE / TD-010`. Listo para planificar; no implementado. Requiere la
decisión DB de TD-010. `AuditEventJdbcRepository` y `SqlServerAuditSupportConfiguration` se retiran solo cuando esa
decisión esté tomada.

## JPA-06 FINAL + JPA-07 — EJECUCIÓN Y CIERRE (2026-10-06)

### Retoques JPA-06 (clean code)

- `AuditEventJpaRepository.metadataFromJson` → `private`. Su test reconstruye metadata por `findLatestByCorrelationId` (sin reflection).
- `MessageCatalogJpaRepository.findTechnicalMessage` → `private`. `CatalogJpaParityHarness` compara el contrato público `getTechnicalMessage` (fallback = código ⇒ `Optional.empty()`); caché y fallback no cambian.
- `JpaIsolationRulesTest`: `Uv*Entity` → `@Immutable` por convención (`haveSimpleNameStartingWith("Uv")`); entidades no-`Uv` sin `@Immutable`; toda `@Entity` bajo Infrastructure JPA. Sin lista de excepciones.
- `AuditAdapterConfiguration` Javadoc: solo crea `AuditEventPublisher`; `AuditEventJpaRepository` se descubre por `@Repository`.
- Decisiones confirmadas: repositories `@Repository` NO final; 28 repositories (27 Port + `AuditEventJpaRepository`); `AuditEventEntity` `@Entity` sin `@Immutable`; TD-010 OPCIÓN A RESOLVED.

### JPA-07 — DoR y estado

- Entrada verificada: `DIRECT_JDBC_IN_SRC_MAIN = 6` (snapshot JPA-06) → 4 archivos productivos de soporte (`JdbcValueMapper`, `CanonicalProcedureResultMapper`, `CanonicalStoredProcedureExecutor`, `SqlServerProcedureSupportConfiguration`).
- Consumidores productivos del ejecutor JDBC: 0 (solo su propio bean de configuración). Recalculado antes de borrar.
- Migración a test: `CanonicalJdbcBaselineExecutor`, `CanonicalJdbcBaselineResultMapper`, `JdbcBaselineValueMapper` (+ sus tests) en `src/test`; `JdbcBaselineTestConfiguration` expone el ejecutor a los 6 ITs de paridad (`@Import`). Ninguna clase JDBC nueva en `src/main`.
- `SqlServerProcedureSupportConfiguration` eliminada.
- Selector `app.adapters.persistence.provider` retirado: `PersistenceAdapterProperties` eliminada, 26 `@ConditionalOnProperty(prefix="app.adapters.persistence")` retirados, entrada de `application.yml` y de `.env.example` eliminada. Conservados `message-catalog`, `parameter-catalog` y `audit` (alternativas reales).
- `spring-boot-starter-jdbc` retirado como dependencia explícita: `./mvnw dependency:tree` confirma que llega transitivo desde `spring-boot-starter-data-jpa` (4.0.6). `mssql-jdbc` runtime se mantiene.
- Comentario de `pom.xml`: "Spring MVC + JPA/Hibernate bloqueante".

### Gates ejecutados

| Gate | Comando | Resultado |
|---|---|---|
| Targeted | `./mvnw -B test -Dtest=JpaIsolationRulesTest,JpaRepositoryArchitectureRulesTest,JpaBootstrapStandardRulesTest,JpaRepositoryBeanUniquenessTest,AuditEventJpaRepositoryTest,AdapterPropertiesBindingTest,CanonicalJdbcBaselineExecutorTest,JdbcBaselineValueMapperTest,ProcedureResultMapperTest,ProcedureResultValidatorTest,AcademicViewJpaProjectionMapperTest,SqlServerJpaBootstrapConfigurationTest` | 106 tests, 0 fallos, 0 errores |
| Clean verify | `./mvnw -B clean verify` | **BUILD SUCCESS**, 1273 tests, 0 fallos, 0 errores, 0 skips; JaCoCo `check` "All coverage checks have been met"; ArchUnit y OpenAPI en verde |
| Integración | `./mvnw -B clean verify -Pintegration` con `.env` cargado | 1273 unit/arch ok; integración 187 tests: **6 fallos, 0 errores, 2 skips** |

Notas de la ejecución de integración:
- Primer intento sin `.env` cargado: 176 errores por `SPRING_DATASOURCE_URL` sin resolver (problema de entorno, no de código). Descartado; se relanzó cargando `.env` línea a línea.
- Los 6 fallos son exactamente los permitidos por el encargo, todos con causa `Could not find stored procedure`:
  - 3 en `SqlStoredProcedureContractIT` (`stored_procedure_publico_coincide_con_el_contrato_real_de_la_db`, SP ausentes: `usp_registrar_estudiante_en_grupo_usuario_no_existente`, `usp_registrar_o_actualizar_plan_estudio`, `usp_sincronizar_usuario`).
  - 2 en `GrupoRepositorySqlServerIT` (`registrar_estudiante_*`, SP `usp_registrar_estudiante_en_grupo_usuario_no_existente`).
  - 1 en `UsuarioPasswordHashSqlServerIT` (`usp_sincronizar_usuario`).
- 2 skips de `DocenteRepositorySqlServerIT` (TD-044).
- Fallo causal nuevo: **0**.

### Métricas JPA-07

- `DIRECT_JDBC_IN_SRC_MAIN = 0` (grep de `JdbcTemplate`, `NamedParameterJdbc*`, `RowMapper`, `ResultSet`, `java.sql`, `CanonicalStoredProcedureExecutor`, `JdbcValueMapper`, `CanonicalProcedureResultMapper`, `SqlServerProcedureSupportConfiguration` sobre `src/main`: 0).
- `REPOSITORIES`: 28 (`@Repository` + `EntityManager`; sin selector de persistencia).
- `ENTITIES`: `Uv*Entity` `@Immutable`; `AuditEventEntity` escribible; todas bajo Infrastructure JPA.
- `SP_PATTERN`: `@Repository → EntityManager → createNativeQuery("EXEC …") → ProcedureResultMapper → ProcedureResultValidator`.

### Deudas

- **TD-010 = RESOLVED** (OPCIÓN A, JPA-06B). "AuditoriaEvento immutable" interpretado como shape no auto-migrado, no como tabla sin INSERT (ver [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md#td-010)).
- **TD-055 = RESOLVED** (JPA-07, `DIRECT_JDBC_IN_SRC_MAIN = 0`).
- **TD-043 = OPEN / SCOPED DB BLOCKER** (3 SP ausentes en la DB; sin cambio DB ni SP creados).
- **TD-044 = OPEN / NON_BLOCKING** (2 skips).
- **TD-058 = OPEN / DB_OWNER** (cierre masivo con fallback; no relacionada).

### Estado

```text
JPA-06  = PASS / CLOSED
JPA-07  = PASS / CLOSED
LB-008  = PASS_WITH_SCOPED_DB_BLOCKER
GLOBAL_INTEGRATION = NOT_GREEN_TD043 (6 fallos, todos TD-043)
```

No se declara integración global en verde. Sin commit ni push.

## ADDENDUM FINAL — validacion de cierre (2026-10-07)

- **Estado vigente:** `TD-039 = CLOSED`, `TD-043 = CLOSED`, `TD-046 = CLOSED`, `TD-047 = CLOSED`, `TD-056 = CLOSED`, `TD-057 = CLOSED`, `TD-058 = CLOSED` (TD-039 / TD-046 / TD-056 / TD-057 / TD-058 cerradas mediante la alineación/corrección final de la DB; el Backend ahora consume ese contrato final); `DIRECT_JDBC_IN_SRC_MAIN = 0`; `BACKEND_DIRECT_INTERNAL_SP = 0`;
  providers DB de matricula (`usp_registrar_estudiante_en_grupo`), sincronizacion de usuario (`usp_sincronizar_usuario`) y
  PlanEstudio (`usp_registrar_o_actualizar_plan_estudio`) = `PRESENT`; commands JPA de SP = `JpaProcedureExecutor`;
  manejo tecnico generico de queries JPA = `JpaQueryExecutor`.

| Comando | Resultado |
|---|---|
| `.\mvnw.cmd -B -DskipTests test-compile` | PASS |
| `.\mvnw.cmd -B clean verify` | BUILD SUCCESS; 1308 tests, 0 fallos, 0 skips; ArchUnit y OpenAPI incluidos; JaCoCo "All coverage checks have been met" |
| `.\mvnw.cmd -B -Pintegration clean verify` (DB SQL Server real, `.env` cargado) | BUILD SUCCESS; 1308 unitarios + 188 ITs, 0 fallos; 1 skip preexistente (`DocenteRepositorySqlServerIT`, TD-044, `assumeTrue` por datos); JaCoCo cumplido |

Hallazgos corregidos durante la validacion (todos de tests, no de contrato productivo): wiring de `JpaRepositoryBeanUniquenessTest`, expectativas TD-057 de las ITs de asistencia (la DB final ya trae `P`/`A`/`R`), GRP_03 (VAL_002 formal) y repetibilidad de GRP_04. Se retiro el residuo que una corrida previa dejo en la DB (usuario `it-lb0022d-ana@example.test` y sus filas de estudiante/matricula).

Limites: los ITs escriben datos de prueba en la DB real y los limpian con su propio fixture; el CI remoto no se ejecuto desde esta sesion.

### Addendum de cierre final (2026-10-07) — DBCODE restantes, deudas DB y corrida final

Las referencias previas de este documento a TD-056 / TD-057 / TD-058 / TD-039 / TD-046 como `OPEN` son historia por fecha; el estado vigente es `CLOSED`.

Cambios de esta pasada (únicamente cierre):

- `DbFailureClassifier`: `ERR_CUPO_INFERIOR_OCUPACION` → `CommonErrorCode.CONFLICT` (`ConflictException`, HTTP 409: la capacidad del grupo no puede quedar por debajo de su ocupación actual); `ERR_PROGRAMA_FACULTAD_INCONSISTENTE` → `CommonErrorCode.VALIDATION_ERROR` (`ValidationException`, HTTP 400: combinación Programa/Facultad inválida). Sin nuevos enums ni `ErrorCode`; sin parseo de mensajes; mappings previos intactos.
- `DbExceptionTranslatorTest`: dos tests de regresión (uno por DBCODE). La clase pasa con 79 tests, 0 fallos.
- `AsistenciaCommandsSpParityIT`: solo Javadoc (la DB final garantiza atomicidad de `Asistencia` + `DetalleAsistencia`; TD-056 cerrada). Sin cambios de lógica.

Corrida final (resultados reales):

| Comando | Resultado |
|---|---|
| `DbExceptionTranslatorTest` | 79 tests, 0 fallos, 0 skips |
| `.\mvnw.cmd -B clean verify` | BUILD SUCCESS; 1310 tests, 0 fallos, 0 errores, 0 skips; `CleanArchitectureRulesTest` 20/20 y `JpaRepositoryArchitectureRulesTest` 3/3 (ArchUnit); `OpenApiGoldenPathConformanceTest` 9/9 y `OpenApiGoldenPathValidationTest` 2/2; JaCoCo "All coverage checks have been met" |
| `.\mvnw.cmd -B clean verify -Pintegration` (DB SQL Server real, `.env` cargado) | BUILD SUCCESS; 1310 unitarios + 188 ITs, 0 fallos, 0 errores; 1 skip preexistente (`DocenteRepositorySqlServerIT`, 3 tests / 1 skipped, TD-044); `JpaQueryExecutorTest` 6/6; `SqlStoredProcedureContractIT` 20/20 y `GoldenPathSqlStoredProcedureContractIT` 16/16; JaCoCo cumplido |

Métricas estructurales (búsqueda sobre `src/main/java` en esta corrida):

```text
DIRECT_JDBC_IN_SRC_MAIN = 0
BACKEND_DIRECT_INTERNAL_SP = 0
BACKEND_MISSING_PROVIDER = 0
BACKEND_SIGNATURE_MISMATCH = 0   (SqlStoredProcedureContractIT 20/20)

TD-043 = CLOSED
TD-047 = CLOSED

JPA_PROCEDURE_EXECUTOR = PASS
JPA_QUERY_EXECUTOR = PASS

REPOSITORY_GENERIC_LOGGERS = 0
REPOSITORY_GENERIC_QUERY_TRY_CATCH = 0

BACKEND_DB_ALIGNMENT = CLOSED
```

Nota sobre `try/catch` en repositories: los cinco `catch` restantes en `*JpaRepository` son traducciones puntuales (serialización JSON en `AsistenciaJpaRepository`; excepciones de puerto `MessageCatalogException` / `ParameterCatalogException` en los repositories de catálogo), no envoltorios genéricos de queries con logger. No se tocaron en esta pasada.
