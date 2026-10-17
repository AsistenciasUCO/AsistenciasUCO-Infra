# TEST_PLAN — LB-008

Sigue REQUIREMENT → CONTRACT → TEST_PLAN → RED → GREEN → VALIDATE ([estándar](../../testing/TESTING_STANDARD.md)). Un mock de `EntityManager` o un repositorio no certifica SQL Server ni JPA; la paridad real exige `-Pintegration` contra SQL Server con el freeze DB.

## Requisito y contrato

- REQUIREMENT: la migración cambia solo la tecnología de persistencia. El comportamiento observable (mismos inputs, misma salida funcional, misma correlación, mismo mensaje usuario, misma clasificación de error, misma atomicidad, mismo rollback, mismos efectos DB) debe ser idéntico al baseline JDBC.
- CONTRACT: [CONTRACT_MATRIX](CONTRACT_MATRIX.md) (SP consumidos MATCH/MISSING; resultado canónico de 4 columnas; `SET NOCOUNT ON`).

## Behavioral Matrix

Para cada comportamiento: observable, implementación equivocada que debe detectar, y nivel de prueba.

| ID | Comportamiento observable | Implementación equivocada detectada | Nivel | Estado |
|---|---|---|---|---|
| BM-01 | Una fila de 4 columnas se mapea en idCorrelacion, mensajes y estado en el orden correcto | Mapeo de columnas desplazado o invertido | Unit | RED → GREEN (`ProcedureResultMapperTest.mapea_una_unica_fila…`) |
| BM-02 | UUID en texto y BIT numérico (0/1) se aceptan | Solo acepta tipos exactos del driver | Unit | RED → GREEN (`acepta_uuid_en_texto…`) |
| BM-03 | Mensajes nulos se conservan (no se sustituyen por "") | Sustitución silenciosa de null | Unit | RED → GREEN (`conserva_mensajes_nulos…`) |
| BM-04 | `estadoResultado = false` NO es fallo técnico en el mapper; se devuelve y la evaluación la hace el validador común | Traducir funcional a excepción técnica dentro del mapper | Unit | RED → GREEN (`estado_false_no_se_traduce_aqui…`) |
| BM-05 | Lista nula, vacía o con >1 fila → `ERR_DB_CANONICAL_CONTRACT` | Tomar la primera fila o devolver null | Unit (negativo) | RED → GREEN (`lista_nula_o_vacia…`, `dos_filas…`) |
| BM-06 | Fila con ≠4 columnas o que no es `Object[]` → `ERR_DB_CANONICAL_CONTRACT` | Mapear columnas parciales | Unit (negativo, límite) | RED → GREEN (`fila_con_columnas_distintas…`, `elemento_que_no_es_fila…`) |
| BM-07 | idCorrelacion nulo o no UUID → `ERR_DB_CANONICAL_CONTRACT` | Generar UUID de sustitución | Unit (negativo) | RED → GREEN (`idCorrelacion_nulo…`) |
| BM-08 | estadoResultado null, texto o fuera de {0,1} → `ERR_DB_CANONICAL_CONTRACT` | Coerción truthy (`2` → true) | Unit (negativo, límite) | RED → GREEN (`estadoResultado_nulo…`) |
| BM-09 | `CanonicalProcedureResult` implementa `ProcedureResult` sin romper `isEstadoResultado()` | Romper llamadores existentes | Unit | RED → GREEN (`el_resultado_mapeado…`) + pilot/validator/executor tests |
| BM-10 | `ProcedureResultValidator` recibe un único `ProcedureResult`; valida null, correlación, estado y delega la traducción a `DbExceptionTranslator` | Acoplar el validator a `List<CanonicalProcedureResult>`, duplicar cardinalidad o clasificación | Unit | RED causal → GREEN (`ProcedureResultValidatorTest`) |
| BM-11 | Paridad JDBC vs JPA del command piloto `registrarAsistenciasSesion` (mismo fixture, misma salida y efectos) | Divergencia de serialización o binding posicional | **Integración SQL Server** (`AsistenciaCommandJpaParityIT`) | PASS del piloto heredado: 21/21 |
| BM-12 | Rollback del lote ante fallo funcional y técnico | Commit parcial | **Integración SQL Server** (`AsistenciaCommandTransactionBoundaryIT`) | PASS del piloto heredado: 3/3 |
| BM-13 | Concurrencia del command (sin corrupción de estado) | Pérdida de actualizaciones | **Integración SQL Server** (`AsistenciaCommandConcurrencyIT`) | PASS del piloto heredado: 3/3 |
| BM-14 | Migración de los cuatro SP (`registrarAsistenciasSesion`, `registrarAsistenciaAutonoma`, `solicitarRevision`, `resolverSolicitud`) al patrón `createNativeQuery` con paridad | Dejar el piloto `StoredProcedureQuery`, cambiar `SP_MANAGES_TRANSACTION` o parámetros | **Integración SQL Server** (`AsistenciaCommandJpaParityIT` 21/21 batch; `AsistenciaCommandsSpParityIT` 10/10 autónomo, radicar, resolver) | **PASS** (2026-10-05) |
| BM-16 | Autónomo, radicar y resolver: rechazo funcional con paridad de excepción y cero escrituras | Efectos parciales o excepción traducida distinta | **Integración SQL Server** (`AsistenciaCommandsSpParityIT` AUT_02/03/04, RAD_02/03, RES_02/03) | PASS. Limitación: fallo técnico intermedio no forzado (ver VALIDATION) |
| BM-17 | Ningún command ni query de Asistencia usa JDBC, `StoredProcedureQuery` ni adapter híbrido en `src/main` | Reintroducir selector, híbrido o JDBC productivo | ArchUnit (`JpaCommandIsolationRulesTest`: SPQ/ParameterMode y JDBC prohibidos en `..sqlserver.jpa..`) | PASS |
| BM-15 | Arquitectura: JPA/JDBC fuera de Application/Domain; ningún nuevo `java.sql` en el mapper | Dependencia accidental en Application | ArchUnit (existentes, 91 tests de arquitectura) | Pasa en `clean verify` |

## Tests RED creados

| Archivo | Tests | Fallo RED causal |
|---|---|---|
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/ProcedureResultMapperTest.java` | 11 | Compilación: `cannot find symbol` sobre `ProcedureResult` y `ProcedureResultMapper` (salida de compilación del RED; primeras líneas verificadas). |
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/procedure/ProcedureResultValidatorTest.java` | 19 | Compilación: `cannot find symbol` sobre `ProcedureResultValidator`; EXIT=1 antes de crear la implementación. |
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/jpa/AsistenciaJpaCommandNativeQueryPatternTest.java` | 9 | JPA-01 COMMANDS. `test-compile` EXIT=1: `EntityManager` no convertible a `EntityManagerFactory` y `cannot find symbol` sobre los cuatro métodos. GREEN 9/9 tras implementar. |
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/jpa/AsistenciaCommandsSpParityIT.java` | 10 | JPA-01 COMMANDS (IT, paridad real). Mismo `test-compile` RED. GREEN 10/10 contra SQL Server. Caracterización de estado (TD-057) corregida tras la primera ejecución. |

Corrección declarada en el RED de fila: `List.of(new Object[]{...})` se resolvía como varargs; se sustituyó por `Collections.singletonList(...)`. No cambió ninguna aserción de comportamiento.

## Ejecución final JPA-01 COMMANDS (2026-10-05)

- Unitarios de patrón y ArchUnit: `AsistenciaJpaCommandNativeQueryPatternTest` 9/9, `JpaCommandIsolationRulesTest` 10/10, `JpaIsolationRulesTest` 6/6, `ProcedureResultMapperTest` 11/11, `ProcedureResultValidatorTest` 19/19.
- Integración SQL Server dirigida: 83/83 PASS (incluye los 10 de paridad de autónomo, radicar y resolver).
- `clean verify`: 1358 tests PASS. `clean verify -Pintegration`: 125 IT, 6 fallos TD-043, 2 skips TD-044 (`NOT_GREEN_TD043`, sin fallos nuevos).
- Detalle y limitaciones en [VALIDATION § Ejecución JPA-01 COMMANDS](VALIDATION.md#ejecución-jpa-01-commands-2026-10-04--2026-10-05).

Estado causal cerrado:

```text
JPA-00 = PASS
JPA-01 FOUNDATION = PASS
JPA-01 COMMANDS = PASS
ASISTENCIA COMMANDS = JPA_ONLY
ASISTENCIA QUERIES = JPA_ONLY
GLOBAL INTEGRATION = NOT_GREEN_TD043
JPA-01 FINAL TARGETED GATE = 83/83 PASS
```

Los cuatro commands cerrados son:

- `dbo.usp_registrar_asistencias_sesion`;
- `dbo.usp_registrar_asistencia_estudiante_autonomo`;
- `dbo.usp_radicar_solicitud_revision_asistencia`;
- `dbo.usp_resolver_solicitud_revision_asistencia`.

El patrón final de los cuatro es `EntityManager` → `createNativeQuery(EXEC)` → parámetros nombrados
→ `getResultList` → `ProcedureResultMapper` → `ProcedureResultValidator`. `StoredProcedureQuery`
queda únicamente como historia de LB-002, no como TARGET.

RED_SNAPSHOT (hashes del test aprobado y de la implementación resultante):

| Archivo | SHA-256 |
|---|---|
| `ProcedureResultMapperTest.java` | `8a7be52ccfed7e1dcb3512ad0379acde7b08cf51925708544c4bf105aedb7173` |
| `ProcedureResultValidatorTest.java` | `a4ad6346fe1a10751cd047c7f6481bc609c25b838d67e3d4c8be19f70228457a` |
| `ProcedureResultMapper.java` (GREEN) | `c64d41ba5a2ac02095f500b48ef4428b3a783d0eb0ff81e5d481a8533c5ded35` |
| `ProcedureResultValidator.java` (GREEN) | `631a2b95fc555494c3bdb9a164a748ac9599a7bf3458fea032295c5d65e63042` |
| `ProcedureResult.java` (GREEN) | `9b0dd9975eedb3508915f6b393cc491784b29f8cd03daab6bf556eb690bb5999` |

**Corrección de test declarada:** tras el RED de compilación, el helper de construcción de listas (`List.of(fila(...))`) aplanaba la fila en 4 elementos por resolución varargs de `List.of(E...)`, lo que provocó 7 errores sin relación con el mapper. Se sustituyó por `Collections.singletonList(...)` en las construcciones de **una** fila. **No cambió ninguna aserción ni la cobertura de comportamiento.** El hash de arriba corresponde a la versión corregida; la versión original no se conservó.

## Negativos, límites y side effects

- Negativos: BM-05 a BM-08.
- Límites: 0/1 del BIT, cardinalidad 0/1/2, 3 y 5 columnas, UUID inválido.
- Side effects: ninguno en JPA-01 foundation (el mapper es puro, sin I/O).
- Rollback: batch certificado por BM-12; autónomo/radicar/resolver certifican rechazos funcionales
  con cero escrituras. El fallo técnico intermedio de esos tres SP no fue forzado y permanece como
  limitación explícita; TD-056 conserva la no atomicidad preexistente del autónomo.
- Auth/scope: sin cambios; RBAC y titularidad siguen en SP y Application.

## Responsabilidades congeladas de foundation

- `ProcedureResultMapper`: cardinalidad exacta, cuatro columnas exactas, UUID, strings/nulls, BIT y construcción de `CanonicalProcedureResult`.
- `ProcedureResultValidator`: resultado no nulo, correlación esperada, `estadoResultado` y delegación a `DbExceptionTranslator`.
- El validator no recibe colecciones ni conoce `CanonicalProcedureResult`; el mapper no traduce fallos funcionales.

## Integración requerida y ambiente

- Requerida para certificar paridad (BM-11 a BM-14): SQL Server `gestionasistenciadb` con el freeze DB desplegado (`test_summary.ps1` PASS), perfil `-Pintegration`, fixtures controlados.
- Ambiente disponible en esta ejecución: **SÍ**. Docker `sql_server_asistencias`, `localhost:1433`, DB `gestionasistenciadb`; gate oficial del repo DB PASS.
- **PRE-SWITCH / BASELINE TARGETED (2026-10-04): 73/73 PASS.** Esta cifra es evidencia histórica
  anterior al cierre de los tres commands adicionales; no es el gate final.
- **JPA-01 FINAL TARGETED GATE (2026-10-05): 83/83 PASS**, 0 fallos, 0 skips. Incluye
  `AsistenciaCommandsSpParityIT` 10/10 para autónomo, radicar y resolver, además de la baseline
  dirigida anterior.
- `clean verify -Pintegration` global final: 125 IT, 6 fallos TD-043 y 2 skips TD-044.
  Resultado: `NOT_GREEN_TD043`, no PASS. El cierre causal de JPA-01 está autorizado por la excepción
  versionada y no oculta el gate global.

## Gates

- `clean verify` (JDK 25): PASS, 1358 tests, 0 fallos/errores/skips.
- Integración dirigida Asistencia: **83/83 PASS**, 0 fallos, 0 skips.
- `clean verify -Pintegration`: `NOT_GREEN_TD043`, 125 IT / 6 fallos TD-043 / 2 skips TD-044;
  sin fallos causales nuevos de JPA-01.
- LINE 91.52 % (≥80 %) / BRANCH 80.58 % (≥70 %): PASS.
- ArchUnit: 92 tests de arquitectura PASS.
- OpenAPI: 12/12 PASS (`9 + 2 + 1`).

## JPA-02A — tests y gates (ejecutado 2026-10-05)

Tests creados o actualizados por JPA-02A (evidencia completa en VALIDATION, sección JPA-02A):

- RED: `SqlServerJpaBootstrapConfigurationTest` (dialecto, metadatos JDBC, naming strategies y arranque
  sin conexión con entity scanning, 3 tests) y `JpaBootstrapStandardRulesTest` (3 reglas ArchUnit).
- Integración nueva: `PersistenceTransactionParityIT` (3 tests): PASS en BEFORE y en AFTER.
- Actualizados por cambio de composición (no debilitados): `AsistenciaJpaQueryPersistenceTest`,
  `SqlServerPersistenceCompositionRootTest`, `AsistenciaCommandJpaParityIT`, `AsistenciaCommandsSpParityIT`.
- Retirado por sustitución: `SqlServerJpaAsistenciaQueryConfigurationTest` (cubierto por
  `SqlServerJpaBootstrapConfigurationTest`).

Resultado: `TRANSACTION_MANAGER_PARITY` PASS; startup sin conexión PASS; entity scanning PASS;
Asistencia 37/37 PASS en targeted; `clean verify` PASS (1362); integración global `NOT_GREEN_TD043` idéntica
al BEFORE. El gate original pedía demostrar:

- `TRANSACTION_MANAGER_BEFORE` vs `TRANSACTION_MANAGER_AFTER` (bean/tipo efectivo y semántica de
  `TransactionOperations`);
- startup sin conexión DB regresiva;
- lifecycle de `EntityManager`, entity scanning y bootstrap estándar de Spring Boot;
- Asistencia continúa JPA_ONLY;
- comportamiento preservado de los módulos JDBC fuera de alcance, en especial
  `GrupoRepositorySqlServerAdapter`;
- `clean verify`, targeted integration Asistencia, ArchUnit, OpenAPI y coverage gates PASS.

TD-043/TD-044 pueden permanecer abiertos bajo su excepción vigente. TD-056/TD-057 no bloquean el
bootstrap; siguen abiertos y no se reinterpretan como defectos introducidos por JPA.

## JPA-02B — TEST PLAN congelado (IMPLEMENTATION_NOT_STARTED)

Estado de entrada: `READY_WITH_SCOPED_DB_BLOCKER`. Esta actualización es `DOCUMENTATION_ONLY`:
no crea ni ejecuta RED Java y no presenta resultados de JPA-02B como PASS.

### Commands cubiertos

- Sesión: `usp_crear_sesion`, `usp_actualizar_sesion`, `usp_cerrar_sesion`,
  `usp_generar_sesiones_grupo`.
- Grupo: `usp_crear_grupo`, `usp_actualizar_grupo`,
  `usp_registrar_estudiante_en_grupo_usuario_no_existente`.

### Behavioral Matrix prevista

| ID | Comportamiento observable | Implementación equivocada detectada | Nivel / gate | Estado |
|---|---|---|---|---|
| BM-02B-01 | Cada command disponible produce el mismo resultado canónico, mensajes, correlación y efectos DB que el baseline JDBC | Parámetros, orden o mapeo divergentes | Integración SQL Server, paridad JDBC↔JPA field-by-field | PLANNED_RED |
| BM-02B-02 | Fallos funcionales conservan clasificación y cero efectos no permitidos | Traducir todo a error técnico o dejar escrituras parciales | Integración SQL Server negativa | PLANNED_RED |
| BM-02B-03 | `ProcedureResultMapper` y `ProcedureResultValidator` son el único contrato de resultado | Duplicar mapper/validator o usar `StoredProcedureQuery` | Unit + ArchUnit/pattern | PLANNED_RED |
| BM-02B-04 | Los commands migrados no usan JDBC, fallback ni selector | Mantener `CanonicalStoredProcedureExecutor` en el path migrado | ArchUnit/pattern | PLANNED_RED |
| BM-02B-05 | La frontera transaccional de cada command coincide con la matriz aprobada | Retirar o añadir `TransactionOperations` sin demostrar paridad | Integración SQL Server, commit/rollback y recurso ligado | PLANNED_RED |
| BM-02B-06 | Los seis providers disponibles completan paridad; el séptimo se reporta bloqueado sin sustituto inventado | Declarar PASS con SP ausente o redirigir a un SP parecido | Contract test + validación documental | PLANNED_RED / BLOCKED_TD043 para el command ausente |
| BM-02B-07 | Las queries `uv_sesion` y `uv_grupo` conservan su comportamiento JDBC en esta microfase | Migrarlas incidentalmente o retirar sus mappers/wiring | Regression/component | PLANNED_RED |

### Secuencia y subverticales

Cada subvertical sigue `REQUIREMENT → CONTRACT → TEST_PLAN → RED → GREEN → VALIDATE`:

1. `JPA-02B.1 — SESIÓN COMMANDS`: cuatro providers disponibles; paridad, errores, efectos y
   transacciones command por command.
2. `JPA-02B.2 — GRUPO COMMANDS`: `crear`/`actualizar` con provider disponible; registro de
   estudiante con `CODE_MIGRATION_STATUS = JPA_REQUIRED` y
   `DB_PROVIDER_STATUS = MISSING / BLOCKED_TD043`.

El RED deberá congelarse con hash y fallo causal antes de implementar. El implementador no puede
modificarlo para acomodar la solución. Los mocks de `EntityManager` pueden probar binding/patrón,
pero no certifican SQL Server, transacciones ni paridad.

### Gates de JPA-02B

- targeted SQL Server de Sesión y Grupo para los providers disponibles;
- matriz `SP_MANAGES_TRANSACTION / CURRENT_OUTER_TX / TARGET_OUTER_TX / PARITY` actualizada con
  evidencia real;
- `clean verify`, ArchUnit, OpenAPI y coverage LINE ≥80 % / BRANCH ≥70 %;
- global `-Pintegration` reportado honestamente; mientras TD-043 permanezca, no se declara PASS;
- queries de Sesión/Grupo fuera del cambio y aún asignadas a JPA-04;
- conteo JDBC recalculado solo después de implementar.

## JPA-02B — Ejecución RED / GREEN (2026-10-05)

### RED creado antes de producción

| Archivo | Tests | RED_OBSERVED (causal) |
|---|---|---|
| `architecture/JpaCoreCommandRulesTest.java` | 5 | Ejecutado sobre código previo: **5/5 FAIL**. Causas: `classes that have simple name 'SesionRepositorySqlServerAdapter' should depend on 'SesionJpaCommandPersistence'` (violado); `… 'GrupoRepositorySqlServerAdapter' should depend on 'GrupoJpaCommandPersistence'` (violado, MapSqlParameterSource en command); `… must not depend on CanonicalStoredProcedureExecutor` (11 violaciones); `commands … failed to check any classes` (clases JPA inexistentes). |
| `jpa/SesionJpaCommandPatternTest.java` | 6 | `test-compile`: `cannot find symbol class SesionJpaCommandPersistence` (2 errores de símbolo por archivo). |
| `jpa/GrupoJpaCommandPatternTest.java` | 4 | `test-compile`: `cannot find symbol class GrupoJpaCommandPersistence`. |
| `jpa/SesionGrupoCommandsSpParityIT.java` | 11 | Escrito contra puertos y ejecutado **sobre el código JDBC previo** (BEFORE): 11/11 PASS, oráculo exacto. No es RED: fija la línea base certificada contra SQL Server. |

### Línea base JDBC certificada contra SQL Server (BEFORE)

- `SesionGrupoCommandsSpParityIT`: 11/11 PASS (log `parity_before2`).
- `GoldenPathSqlStoredProcedureContractIT` 16/16 PASS; `AsistenciaRepositorySqlServerIT` 6/6; `AuditHttpIT` 2/2.
- Fallos conocidos de la integración global, idénticos a la documentación: `SqlStoredProcedureContractIT` ×3, `GrupoRepositorySqlServerIT` ×2, `UsuarioPasswordHashSqlServerIT` ×1.

### GREEN (AFTER)

- Unitario y ArchUnit dirigido: `JpaCoreCommandRulesTest` 5/5; `SesionJpaCommandPatternTest` 6/6; `GrupoJpaCommandPatternTest` 4/4; `SesionRepositorySqlServerAdapterTest` 6/6; `GrupoRepositorySqlServerAdapterTest` 8/8; `AsistenciaJpaCommandNativeQueryPatternTest` 9/9; `FeaturesBeansConfigTest` 6/6; `JpaCommandIsolationRulesTest` 10/10; `SqlServerPersistenceCompositionRootTest` 2/2.
- SQL Server real: `SesionGrupoCommandsSpParityIT` 11/11 PASS; líneas `PARITY_OUTCOME` idénticas a BEFORE.
- Regresión Asistencia y transacciones: `AsistenciaCommandJpaParityIT` 21/21; `AsistenciaCommandsSpParityIT` 10/10; `AsistenciaCommandTransactionBoundaryIT` 3/3; `PersistenceTransactionParityIT` 3/3; `AsistenciaRepositorySqlServerIT` 6/6; `GoldenPathSqlStoredProcedureContractIT` 16/16; `AuditHttpIT` 2/2.
- Fallos globales: los mismos 6 de BEFORE (ver arriba), mismas causas (`No fue posible ejecutar el procedimiento almacenado`, SP ausente TD-043). Ningún fallo nuevo.

### Adaptación declarada de tests existentes

No es modificación de RED para acomodar la solución. Son tests unitarios que fijaban el path JDBC que JPA-02B retira:

- `SesionRepositorySqlServerAdapterTest`: `createPassesConfirmedProcedureAndParameters` y `updateCloseAndGeneratePassThePublicProcedures` afirmaban SQL y mapas de parámetros del `CanonicalStoredProcedureExecutor`. Se sustituyeron por `comandos_de_sesion_delegan_en_el_command_jpa_con_el_dto_original`. Esas aserciones de SQL y parámetros ahora viven en `SesionJpaCommandPatternTest` (SES_PAT_001..004) y en la paridad de la IT.
- `GrupoRepositorySqlServerAdapterTest`: se retiraron los seis tests de registrar, crear y actualizar que afirmaban el ejecutor JDBC (`registrarEstudiante_*`, `crearGrupo_ejecuta_*`, `actualizarGrupo_ejecuta_*`). Se añadió `comandos_de_grupo_delegan_en_el_command_jpa_dentro_de_la_frontera_transaccional`, que verifica la delegación y las tres llamadas a `TransactionOperations`. Los tests de consultas, DTO nulo y mapeo de filas se conservan.
- `FeaturesBeansConfigTest.grupoRepositoryPort_usa_sqlserver`: la firma del bean cambió a `EntityManager`.

## JPA-03 — ACADEMIC / USER COMMANDS

Alcance: 8 command paths. Seis providers disponibles (`usp_crear_asignatura`, `usp_actualizar_asignatura`, `usp_toggle_estado_asignatura`, `usp_ejecutar_cierre_masivo_periodo`, `usp_crear_coordinador`, `usp_crear_decano`) con **paridad de exito**. Dos providers ausentes (`usp_registrar_o_actualizar_plan_estudio`, `usp_sincronizar_usuario`, TD-043) solo con **caracterizacion**. Las secciones JPA-01 y JPA-02B anteriores se conservan como evidencia historica.

### RED / GREEN

- RED: patron por capability y reglas ArchUnit antes de la migracion (`*JpaCommandPatternTest`, `JpaAcademicUserCommandRulesTest`); la compilacion fallo por clases `*JpaCommandPersistence` inexistentes.
- GREEN: `EntityManager` → `createNativeQuery("EXEC ...")` → `setParameter` → `getResultList` → `ProcedureResultMapper` → `ProcedureResultValidator`. Sin `StoredProcedureQuery`, `JdbcTemplate`, `NamedParameterJdbcOperations` ni `CanonicalStoredProcedureExecutor` en runtime de estos commands.

### Error parity y characterization de providers ausentes (`AcademicUserCommandsSpParityIT`)

| Escenario | Camino | Requisito |
|---|---|---|
| ASG_01 / ASG_02 / ASG_03 | error funcional (ids inexistentes) | BEFORE JDBC = AFTER JPA |
| CIE_01 | error funcional (periodo inexistente) | BEFORE JDBC = AFTER JPA |
| COO_01 / DEC_01 | error funcional (facultad inexistente) | BEFORE JDBC = AFTER JPA |
| PLA_01 | `SP_NOT_IN_DB` (TD-043) | characterization: provider MISSING, clasificacion equivalente |
| USU_01 | `SP_NOT_IN_DB` (TD-043) | characterization: provider MISSING, clasificacion equivalente |

### Success parity (`AcademicUserCommandsSuccessParityIT`, JPA-03 cierre)

Oraculo JDBC: `AcademicUserJdbcBaselineOracle` (solo `src/test`), replica exacta del SQL y de los parametros de los adapters JDBC historicos de HEAD, ejecutado por el `CanonicalStoredProcedureExecutor` historico. Candidato: `*JpaCommandPersistence`. Ambos sobre fixtures equivalentes; la comparacion usa resultado canonico normalizado y efectos DB normalizados (no IDs).

| Escenario | Fixture | Verificado |
|---|---|---|
| ASG_SUCCESS_01 crear | plan/semestre de la semilla, codigo unico `IT-LB008-JPA03-*` | estadoResultado, mensaje, correlacion, fila (codigo, nombre, creditos, area/componente no nulos, SPE de la semilla, estado 1), delta de conteos |
| ASG_SUCCESS_02 actualizar | dos asignaturas equivalentes | cambios persistidos iguales (codigo, nombre, creditos); area, componente y SPE sin cambio |
| ASG_SUCCESS_03 toggle | dos asignaturas con estado 1 | estado BEFORE 1, AFTER 0, misma transicion y resultado canonico |
| CIE_SUCCESS cierre | periodo propio con grupo, 2 estudiantes activos, 3 inasistencias del estudiante 1 en 3 sesiones | estados finales (`CI` y `F`), contadores del grupo, auditoria `CIERRE_MASIVO_PERIODO` (metadata `procesados`/`reprobadosPorFallas`), delta de conteos; periodo de la semilla sin cambio |
| COO_SUCCESS coordinador | ejecutor decano titular de la facultad, programa de la semilla | usuario (nombres, numero, correo confirmado, estado, tipo CC, password presente), coordinador vinculado, `Programa.coordinador` apunta al nuevo, delta de conteos |
| DEC_SUCCESS decano | ejecutor administrador, facultad de la semilla | usuario, decano vinculado, `Facultad.decano` apunta al nuevo, delta de conteos |

Limitaciones de la evidencia de exito:

- La unicidad de un detalle por asistencia (`UX_DetalleAsistencia_Asistencia`) obliga a construir las tres inasistencias en tres sesiones distintas.
- El `nombreArea` y `nombreComponente` se pasan vacios: el SP resuelve el primer registro de `uv_area`/`uv_componente`. Ambos runs usan la misma consulta, por lo que el id coincide; no se prueba resolucion por nombre.
- Los SP de coordinador y decano actualizan una referencia de la semilla (`Programa.coordinador`, `Facultad.decano`); el test la restaura en `finally` y verifica en `@AfterEach` que quedo igual.

### Side effects

Delta de conteos por tabla (`Asignatura`, `SemestrePlanEstudio`, `Usuario`, `Coordinador`, `Decano`, `Programa`, `Facultad`, `PeriodoAcademico`, `Grupo`, `EstudianteGrupo`, `Sesion`, `Asistencia`, `DetalleAsistencia`, `AuditoriaEvento`) alrededor de cada ejecucion, comparado entre JDBC y JPA. Cualquier tabla tocada inesperadamente cambia el delta y falla la paridad.

### Transaction matrix (evidencia de exito)

Ver [CONTRACT_MATRIX](CONTRACT_MATRIX.md#jpa-03--evidencia-de-exito-y-matriz-transaccional-cerrada-2026-10-05). Resumen: los tres SP con transaccion propia ejecutan su camino de exito sin transaccion exterior (`TARGET_OUTER_TX = NO`). El camino de `SAVEPOINT` de coordinador y decano (solo con transaccion exterior) no es alcanzable desde el runtime JPA-only y no se certifica como rollback intermedio.

### Negative scenarios

- Errores funcionales y SP ausentes: cubiertos por la paridad de error.
- Ejecutor sin perfil RBAC, facultad inconsistente con el programa y periodo inexistente: no ejecutados en esta microfase. Su clasificacion depende de los mismos SP y la paridad de error ya cubre el patron de salida.
- Rollback intermedio (savepoint) y falla a mitad de cierre: NO probado. No se inventa.

### Cleanup strategy

- Prefijo obligatorio `IT-LB008-JPA03-` en codigos, nombres de periodo/grupo/sesion y correos `@example.test` en minusculas.
- Filas registradas en el fixture antes de las assertions; limpieza en `@AfterEach` en orden de FK, aunque falle una assertion.
- Restauracion de `Programa.coordinador` y `Facultad.decano` antes de borrar coordinadores y decanos.
- Barrido por prefijo y verificacion `residuos() == residuos antes`.
- Sin `@Transactional` sobre los calls: se ejercita la frontera de produccion; la limpieza ocurre despues.

### Gates

Ver [VALIDATION](VALIDATION.md#ejecución-jpa-03--cierre-de-jpa-03-2026-10-05). Gates: targeted JPA-03 unit, `AcademicUserCommandsSpParityIT`, `AcademicUserCommandsSuccessParityIT`, `clean verify`, `clean verify -Pintegration`, ArchUnit, OpenAPI via `clean verify`, cobertura JaCoCo y `git diff --check`.

### Limitations

- TD-043: `usp_registrar_o_actualizar_plan_estudio` y `usp_sincronizar_usuario` no existen en la DB; su camino de exito no es certificable.
- TD-058: `usp_ejecutar_cierre_masivo_periodo` cae al periodo mas reciente de la tabla cuando el codigo no coincide. Los tests evitan la ruta con guardas; no se corrige en la DB desde backend.
- Concurrencia y carga: no probadas.

## JPA-04 — CORE VIEW QUERIES (TEST PLAN congelado antes de implementación)

### Behavioral Matrix

| ID | Requirement | Scenario | Observable esperado | Implementación equivocada detectada | Nivel |
|---|---|---|---|---|---|
| BM-04-01 | Runtime core JPA-only | Cada adapter core delega sus lecturas en su `*JpaQueryPersistence` | Cero dependencia JDBC/RowMapper en adapters y query persistence del slice | Dejar JDBC escondido o fallback | ArchUnit/component |
| BM-04-02 | Contrato de vistas | Entidades planas sobre las nueve vistas, `@Entity @Immutable`, identidad congelada | Managed types y anotaciones correctas; `uv_estudiante` usa clave compuesta | `@Id` inventado o entidad writable | Architecture/integration |
| BM-04-03 | Sesión | ID existente/inexistente y lista por grupo | Proyección exacta, `null` not-found, orden `fechaHoraInicio, numero, id` | `NoResultException`, orden implícito o mapping incompleto | Unit + parity SQL Server |
| BM-04-04 | UTC TD-037 | `datetime2` de sesión | Mismo `LocalDateTime` UTC del baseline JDBC, independiente de zona JVM | Shift por zona local/DST | SQL Server parity |
| BM-04-05 | Grupo | Listado y estudiantes del grupo | Row count, campos, join correo/identidad y orden idénticos | N+1, join incorrecto o BIT/int alterado | Unit + parity SQL Server |
| BM-04-06 | Usuario | Buscar por correo trim/case-insensitive, ID e identificación | Primer resultado ordenado, `Optional.empty`, nulls preservados | comparación case-sensitive o excepción not-found | Unit + parity SQL Server |
| BM-04-07 | Docente | Identidad y asignaciones | orden y proyecciones completos; ID de fila estable | usar `docente.id` como ID de vista multirregistro | Unit + parity SQL Server |
| BM-04-08 | Estudiante | paginación/filtros/detalle | count, páginas, filtros opcionales, contextos `distinct` y orden idénticos | perder filtro académico, paginar en memoria o duplicar filas | Unit + parity SQL Server |
| BM-04-09 | Tipo identificación | listado | orden por tipo y mapping exacto | orden natural DB o columnas intercambiadas | Unit + parity SQL Server |
| BM-04-10 | Null semantics | `cuposDisponibles` nullable y cualquier nullable observable | DB null → Java null; no default silencioso | null→0/false/cadena vacía | SQL Server parity |
| BM-04-11 | Error semantics | error JPA del provider | `DatabaseOperationException`, log con operation/correlation | fuga de `PersistenceException` | Unit |
| BM-04-12 | Cleanup | RowMapper/helper sin consumidores | solo se eliminan consumidores cero; helper se conserva si JPA-05 lo usa | borrar soporte aún usado por academic/reporting | Static inventory |

### RED y snapshot requerido

Antes de producción se crean reglas `JpaCoreQueryRulesTest` y tests de patrón/delegación para las
seis capabilities. El RED esperado es compilación fallida por `*JpaQueryPersistence`/entities aún
inexistentes y/o reglas que detectan JDBC en los paths core. Se registran SHA-256, comando, exit
code y causa. Tras congelarlo, el implementador no modifica esos archivos.

### Integración y gates

`CoreViewQueriesJpaParityIT` conserva SQL JDBC baseline únicamente en `src/test` y compara
field-by-field contra los puertos JPA en el mismo SQL Server/fixture: row count, orden, IDs,
strings, booleanos, fechas UTC, nulls, paginación/filtros y not-found. Se ejecutan además los IT core
existentes. Gates: `clean verify`, targeted `-Pintegration`, integración global distinguida de la
causal, ArchUnit, OpenAPI, LINE ≥80 %, BRANCH ≥70 %, skips revisados y `git diff --check`.

### Ejecución RED / GREEN JPA-04

- RED congelado: `JpaCoreQueryRulesTest.java`, SHA-256
  `01EC344632FB654C1BBAFB34FD8839E0B1BBB061BF5D392441B8DEA89FBFAC81`.
- Comando RED: `mvnw -Dtest=JpaCoreQueryRulesTest test`; exit 1, 3/3 fallos causales: query
  persistence y entidades inexistentes, y adapters core todavía dependientes de JDBC.
- El test RED no fue modificado tras el freeze. En GREEN pasa 3/3.
- Suite dirigida final: 24/24 PASS (`JpaCoreQueryRulesTest`, adapters core, composition root y
  `CoreViewJpaQueryErrorSemanticsTest`).
- Paridad SQL Server final: `CoreViewQueriesJpaParityIT` 6/6 PASS, 0 skips. Cubre BM-04-03..10 y
  not-found. La primera ejecución detectó causalmente un shift UTC de 5 horas y cierre prematuro de
  `ResultSet` con `getResultStream().findFirst()`; ambos defectos se corrigieron antes del cierre.
- Error semantics: las seis query persistence traducen `PersistenceException` a
  `DatabaseOperationException` (un test con 6 assertions); otro test confirma la proyección UTC
  independiente del timezone por defecto.
- Gates completos: `clean verify` 1375/1375 PASS; integración 159 tests, únicamente los 6 fallos
  TD-043 preexistentes y 2 skips TD-044; LINE 87.24 %, BRANCH 78.18 %; `git diff --check` exit 0
  con un warning EOL preexistente de `.env.example`.

`JPA04_TEST_STATUS = PASS`. JPA-05 permanece fuera de alcance y no iniciada.

## JPA-05 — PLAN DE PRUEBAS (cierre 2026-10-05)

| Clase de prueba | Tipo | Qué certifica | Resultado |
|---|---|---|---|
| `JpaAcademicQueryRulesTest` | ArchUnit | Scope JPA-05 sin JDBC en producción; query persistence JPA; `UvEstudianteProgramaEntity` `@Entity @Immutable` con identidad | 5/5 PASS |
| `EstudianteProgramaJpaQueryPersistenceTest` | Unit (patrón) | JPQL con constructor projection; `numeroIdentificacion` int→String; una consulta; `PersistenceException` → `DatabaseOperationException` con causa | 4/4 PASS |
| `InstitutionalScopeSingleStatementPatternTest` | Unit (patrón) | `canDocenteAccessGrupo` y `canEstudianteAccessGrupo` ejecutan exactamente una `createNativeQuery`, sin `createQuery`; `TOP 1` original; conteo 0 denegado; error técnico con causa | 5/5 PASS |
| `EstudianteProgramaJpaParityIT` | Integración SQL Server | Fixture autocontenido: JDBC baseline vs JPA (filas, campos, orden); una `EstudiantePrograma` → una proyección; cleanup en `finally` | 1/1 PASS |
| `AcademicQueryJpaParityIT` | Integración SQL Server | Paridad académica | 8/8 PASS |
| `AuthorizationReportJpaParityIT` | Integración SQL Server | Paridad de alcance institucional y reporte (usuarios vivos y desconocidos, grupo, cross-scope) | 4/4 PASS |
| `CoreViewQueriesJpaParityIT` | Integración SQL Server | Regresión de consultas core | 6/6 PASS |
| `CoreViewJpaQueryErrorSemanticsTest` | Unit | Semántica de error de lecturas JPA | 2/2 PASS |
| `GlobalExceptionHandlerTest` / `ApiErrorCatalogTest` | Unit (existentes) | `DATABASE_OPERATION_ERROR` en el contrato HTTP 500 | incluidos en 1364/0 |
| DB: `test_uv_estudiante_programa_identity.sql` | DB gate | SHAPE, IDENTITY, CARDINALITY, DEPENDENCY | 4/4 PASS |

Regla de cierre aplicada: `mvnw clean verify` sin ArchUnit rojo; `-Pintegration` solo con los seis fallos TD-043 de siempre.


## JPA-06 — CATALOGS (TEST PLAN, 2026-10-05)

Alcance: catálogos de mensaje y parámetro. La auditoría no tiene RED hasta resolver TD-010.

### Behavioral Matrix

| Caso | Oráculo | Ubicación | Resultado |
|---|---|---|---|
| Mensaje de usuario activo: BEFORE JDBC = AFTER JPA | `CatalogJdbcBaseline` vs `CatalogJpaQueryPersistence` | `CatalogJpaParityIT` | PASS |
| Mensaje de usuario inactivo: vacío en ambos lados | idem | `CatalogJpaParityIT` | PASS |
| Mensaje de usuario inexistente: vacío en ambos lados | idem | `CatalogJpaParityIT` | PASS |
| Mensaje de usuario vivo (dato real de la DB): BEFORE = AFTER | idem | `CatalogJpaParityIT` | PASS |
| Mensaje técnico activo / inactivo | idem | `CatalogJpaParityIT` | PASS (2 casos) |
| Parámetro activo: BEFORE = AFTER | idem | `CatalogJpaParityIT` | PASS |
| Parámetro inactivo o inexistente: vacío en ambos lados | idem | `CatalogJpaParityIT` | PASS |
| Parámetro vivo (dato real de la DB): BEFORE = AFTER | idem | `CatalogJpaParityIT` | PASS |
| Cache de mensajes: hit tras cambio en DB, miss tras `clearCache()` | adapter AFTER | `CatalogJpaParityIT` | PASS |
| Cache de parámetros: inexistente no cacheado; aparece al insertarse | adapter AFTER | `CatalogJpaParityIT` | PASS |
| Normalización trim y codigo/grupo/clave en blanco o nulos sin consultar | unitario | `SqlServer*CatalogAdapterTest` | PASS |
| Formato `MessageFormat`, fallback al código, plantilla inválida | unitario | `SqlServerMessageCatalogAdapterTest` | PASS |
| Error de persistencia traducido con causa original | unitario | `SqlServer*CatalogAdapterTest` | PASS |
| `getRequiredParameter` lanza `ParameterNotFoundException` | unitario | `SqlServerParameterCatalogAdapterTest` | PASS |
| `getParameterAs` conversiones y tipo no soportado | unitario | `SqlServerParameterCatalogAdapterTest` | PASS |

### RED (creado antes de implementar)

Archivo: `src/test/java/co/edu/uco/asistenciasuco/architecture/JpaCatalogRulesTest.java` (4 reglas).

- `RED_EXPECTED`: 4 de 4 fallan.
- `RED_OBSERVED` (ejecución `-Dtest=JpaCatalogRulesTest`): **4 failures, 0 errors**.
  - `adapters_de_catalogo_no_dependen_de_jdbc`: 12 violaciones (`org.springframework.jdbc`, `java.sql`).
  - `configuracion_de_catalogos_no_depende_de_jdbc`: 2 violaciones.
  - `existe_catalog_jpa_query_persistence_en_la_capa_jpa`: falso (clase inexistente).
  - `existen_entidades_inmutables_de_mensajes_usuario_y_tecnico`: falso (entidades inexistentes).
- `GREEN`: `JpaCatalogRulesTest` **4/4 PASS**. El RED no se modificó durante GREEN.

### Adaptación declarada de tests existentes (D-JPA06-05)

`SqlServerMessageCatalogAdapterTest` (18 tests) y `SqlServerParameterCatalogAdapterTest` (16 tests) mockeaban
`NamedParameterJdbcTemplate`. Ahora mockean `CatalogJpaQueryPersistence`. Se conservan todas las aserciones de comportamiento.
No se elimina ningún caso de comportamiento.

### Integración y ambiente

- SQL Server real `gestionasistenciadb` (`localhost:1433`). Ejecución `-Pintegration` dirigida: `CatalogJpaParityIT` 11/11, 0 skips.
- Fixtures con prefijo `IT-LB008-JPA06-`, eliminados en `finally`. Los datos vivos se usan en los casos `vivo`.
- Mocks no certifican SQL Server: la paridad usa BD real.

### Gates

Targeted unit, RED/GREEN, catalog parity SQL Server, `clean verify`, `clean verify -Pintegration`, ArchUnit, OpenAPI, cobertura y `git diff --check`.
Resultados en [VALIDATION](VALIDATION.md#jpa-06--ejecución-2026-10-05).

## JPA-06A — REPOSITORY ARCHITECTURE SIMPLIFICATION

### Behavioral Matrix

| ID | Requirement | Observable | Wrong implementation caught | Level |
|---|---|---|---|---|
| BM-06A-01 | Port directo a repository | cada implementación concreta vive en `..jpa.repository..`, implementa el port y lleva `@Repository` | conservar adapter delegador o repository sin stereotype | ArchUnit |
| BM-06A-02 | JPA-only | repositories no dependen de Spring JDBC ni `java.sql` | JDBC reintroducido dentro del repository | ArchUnit |
| BM-06A-03 | Capas | Application/Domain no dependen del paquete repository JPA | fuga de Infrastructure hacia capas internas | ArchUnit |
| BM-06A-04 | Sin wrappers | no existen `*JpaCommandPersistence`, `*JpaQueryPersistence` ni adapters SQL de persistencia migrada | renombrar solo la fachada dejando la cadena | ArchUnit/static |
| BM-06A-05 | Wiring único | component scanning produce exactamente un bean por port | bean manual residual o doble implementación | Spring context |
| BM-06A-06 | Transacción Grupo | los tres commands siguen ejecutándose con `TransactionOperations` | añadir/quitar frontera | unit + SQL Server parity |
| BM-06A-07 | Contrato SP/view | SQL `EXEC`, parámetros, JPQL, mapeo y errores permanecen | SP/query alterada durante el move | tests de patrón + paridad existente |
| BM-06A-08 | QueryRow | solo resultados compuestos conservan QueryRow | wrapper 1:1 de una entity | architecture/static |
| BM-06A-09 | Semánticas críticas | UTC, authorization single-statement, reporte y catálogo/cache sin cambio | shift temporal, TOCTOU, mapping o cache divergente | suites existentes + SQL Server parity |

### RED_SNAPSHOT requerido

Test nuevo: `JpaRepositoryArchitectureRulesTest`. Debe crearse antes de producción y fallar porque el paquete
`..jpa.repository..` y los repositories anotados todavía no existen y porque permanecen las cadenas delegadoras.
El archivo se congela por SHA-256; el implementador no modifica el RED durante GREEN.

`RED_SNAPSHOT` ejecutado el 2026-10-05: base `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d` con el worktree
acumulado; SHA-256 `348CD5C4BB82F8F162F10F5B057B1C27422212D599E04C2A0CABCF24D4B8406B`; comando
`.\mvnw.cmd -Dtest=JpaRepositoryArchitectureRulesTest test`; exit 1; 3/3 fallos causales: paquete repository
vacío, 41 wrappers detectados y primer `XxxJpaRepository` ausente. El intento sandbox previo no fue RED válido
(resolución Maven bloqueada); la ejecución registrada sí alcanzó Surefire.

Los tests existentes funcionales y de paridad no se relajan. Solo se adaptan referencias a clases eliminadas,
wiring/component scanning y reglas estructurales supersedidas por ADR-004.

### Secuencia de validación

1. Bloque core; compile/tests dirigidos.
2. Bloque academic; compile/tests dirigidos.
3. Bloque auth/report/catalog; compile/tests dirigidos.
4. `clean verify`, paridades SQL Server existentes, integración global, cobertura, ArchUnit/OpenAPI y diff check.

## Resultado de pruebas JPA-06A (2026-10-06)

| Behavioral ID | Resultado | Evidencia |
|---|---|---|
| BM-06A-01 (port directo + `@Repository`) | PASS | `JpaRepositoryArchitectureRulesTest` 3/3 |
| BM-06A-02 (sin JDBC en repositories) | PASS | `JpaRepositoryArchitectureRulesTest` |
| BM-06A-03 (Application/Domain no dependen de repositories) | PASS | `JpaRepositoryArchitectureRulesTest` |
| BM-06A-04 (sin wrappers) | PASS | `JpaRepositoryArchitectureRulesTest` (wrappers y QueryRow 1:1) |
| BM-06A-05 (wiring único, un bean por Port) | PASS | `JpaRepositoryBeanUniquenessTest` 3/3 (incluye proxies CGLIB) |
| BM-06A-06 (frontera transaccional de Grupo) | PASS | `GrupoJpaRepository` conserva `TransactionOperations`; paridad SQL Server 86/86 |
| BM-06A-07 (SP/JPQL/mapeo/errores) | PASS | `*ParityIT` (86 tests) y patrones SP existentes en verde |
| BM-06A-08 (QueryRow solo compuestos) | PASS | 8 QueryRow revisados; ver VALIDATION |
| BM-06A-09 (UTC, autorización, reporte, catálogo) | PASS | `AuthorizationReportJpaParityIT`, `CatalogJpaParityIT`, paridad SQL Server |

RED adicional (2026-10-06): `repositories_jpa_son_proxiables_con_traduccion_de_excepciones_de_persistencia_y_cglib`
falló por `Cannot subclass final class` antes de quitar `final`; GREEN después. Las aserciones funcionales no se relajaron.

## ADDENDUM FINAL — pruebas del cierre de alineacion (2026-10-07)

- **Estado vigente:** `TD-043 = CLOSED`, `TD-047 = CLOSED`; `DIRECT_JDBC_IN_SRC_MAIN = 0`; `BACKEND_DIRECT_INTERNAL_SP = 0`;
  providers DB de matricula (`usp_registrar_estudiante_en_grupo`), sincronizacion de usuario (`usp_sincronizar_usuario`) y
  PlanEstudio (`usp_registrar_o_actualizar_plan_estudio`) = `PRESENT`; commands JPA de SP = `JpaProcedureExecutor`;
  manejo tecnico generico de queries JPA = `JpaQueryExecutor`.

Pruebas anadidas/alineadas (comportamiento observable, sin `@Disabled` ni skips nuevos):

- `GestionarPlanEstudioUseCaseImplTest`, `CoordinadorPortalControllerTest` (PlanEstudio por `inp`), `PlanEstudioJdbcBaseline` (oraculo de test-side con la firma nueva).
- `RegistrarEstudianteUseCaseImplTest`: ambos ausentes / ambos mismo UUID / UUID distintos / **solo correo** / **solo documento** (sin SP, sin encoder, sin Identity); el escenario post-command parte de correo+documento del mismo usuario.
- `DbExceptionTranslatorTest`: DBCODE formales (`USU_001`, `USU_002`, `IDN_001`, `ERR_UNICIDAD_DOCUMENTO`, `EST_001`, `PLA_001`, `PROG_001`, `PER_001`, `HOR_001`, `VAL_001..006`, `CAT_001`, `SYS_001`), regresion `GEN_001` → `ERR_DB_UNCLASSIFIED` y `VAL_007` por operacion (3 + desconocida).
- `JpaQueryExecutorTest`: exito, `PersistenceException`, `IllegalStateException`, `IllegalArgumentException`, `ArithmeticException` (causa preservada) y excepcion funcional no capturada.
- `GrupoRepositorySqlServerIT`: grupo inexistente con ejecutor real DOCENTE/COORDINADOR → `ERR_GRUPO_NO_EXISTE` sin residuos; exito con grupo habilitado + cupo + docente titular como ejecutor.
- `SesionGrupoCommandsSpParityIT`: GRP_03 → `ValidationException` (VAL_002 formal); GRP_04 repetible (correo unico + limpieza de sus filas).
- `AsistenciaCommandsSpParityIT`: RAD_01 → `P`, RES_01 → `A`, RES_02 envia el `idDocente` del docente ajeno y espera rechazo sin cambio de estado.
- `JpaRepositoryBeanUniquenessTest`: el contexto de scan registra `JpaProcedureExecutor`.
- Guard existente `CleanArchitectureRulesTest.codigo_productivo_no_referencia_procedimientos_internos`: PASS.
