# AUDIT — LB-001B.4

## Dictamen preliminar sobre GREEN selectivo

Fecha: 2026-09-23.

La primera ejecución GREEN posterior a la implementación ejecutó 116 pruebas y terminó con
2 fallos, 0 errores y 0 omitidas. Ambos fallos se clasifican como `TEST_CONTRACT_CONFLICT`:

1. `GrupoHttpMapperContractTest.rejectsMissingCreateFieldsAndMissingUpdateIdentity` mantenía
   una tercera expectativa `ERR_CAMPO_OBLIGATORIO` después de informar `codigo` y `nombre`.
   Esa expectativa correspondía exclusivamente al ghost field `aula`, retirado por el contrato
   DB final y por el alcance autorizado de LB-001B.4. Dictamen: el tester debe sustituir esa
   expectativa por éxito sin `aula`; producción no debe reintroducir el campo.
2. `SesionMateriaEstudianteSqlServerAdapterTest.consultarSesionesMateria_mapea_proyeccion_completa`
   construía el fixture mediante `Timestamp.valueOf(LocalDateTime)`. Ese valor depende del
   timezone del host y no representa el instante UTC que declara el contrato temporal.
   Dictamen: el tester debe construir el fixture con `Timestamp.from(Instant)`; la expectativa
   canónica `LocalDateTime` UTC se conserva.

El auditor no modifica producción ni pruebas. Se devuelve únicamente esos dos archivos al rol
`03-tester-red`; el resto del snapshot permanece congelado. Tras la corrección se registran los
nuevos hashes y se repite GREEN.

## Dictamen final — PASS técnico del alcance LB-001B.4 (Golden Path), con condiciones

Fecha: 2026-09-23. Pase del mismo agente/repositorio con revisión conceptualmente independiente; no es
verificación externa. No se modificó producción, tests, contratos ni DB (solo `SELECT` sobre
`sql_server_asistencias / gestionasistenciadb`; sin secretos impresos).

Perfil de integración completo: `FULL_BACKEND_INTEGRATION_PROFILE: NOT_GREEN — TD-043 NON-GOLDEN ONLY`.
El Golden Path queda verde; el cierre debe declarar esa limitación, no un verde global.

### Evidencia por punto

| Punto | Resultado | Evidencia verificada |
|---|---|---|
| Build unitario | PASS | `mvnw -B -ntp verify` re-ejecutado en la auditoría: 959 tests, 0F/0E/0S, "All coverage checks have been met", BUILD SUCCESS. |
| ArchUnit | PASS | 16 clases en `architecture/**` dentro de esa ejecución, 0 fallos (`CleanArchitectureRulesTest` 20/20). |
| Cobertura | PASS | `target/site/jacoco/jacoco.csv`: LINE 87,89 % (>=80), BRANCH 71,60 % (>=70). Margen BRANCH 1,6 pp: estrecho. Gate del `pom.xml` (BUNDLE) sin relajar. |
| Contrato DB SHA | PASS | `DB_BASELINE_CONTRACT.md` = `.sha256` = `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec` = PLAN/CONTRACT_MATRIX/PRECHECK. Limitación heredada: origen `UNCOMMITTED_WORKTREE` del repo DB. |
| RED intacto | PASS | Los hashes finales de `RED_SNAPSHOT.md` coinciden con los archivos actuales; las dos entradas superadas (Grupo mapper, SesionMateriaEstudiante) corresponden a la revisión controlada por TEST_CONTRACT_CONFLICT. `SqlStoredProcedureContractIT` intacto. |
| DBCODE formal | PASS | `DbTechnicalError` (`^DBCODE=([A-Z0-9_]+)\|(.*)$`) y `DbFailureClassifier`: código conocido por switch; DBCODE desconocido o malformado -> `ERR_DB_UNCLASSIFIED` (fail-closed, sin heurística); texto legacy solo sin marcador. La DB emite el canal de forma central (`usp_obtener_mensaje_catalogo` hace `CONCAT('DBCODE=',...)`). |
| Clasificación por texto en Golden Path = 0 | PASS | El SP del lote usa `SEC_002` (vía `usp_validar_titularidad_jerarquica_interno`) y `RC_001` con canal DBCODE; el mapping no depende del texto. La rama legacy solo aplica a verticales fuera del Golden Path. |
| SEC_002 / RC_001 en integración real | PASS | `AsistenciaRepositorySqlServerIT` 6/6: docente ajeno -> `ForbiddenException`/`FORBIDDEN`; estado `ABC` y lote mixto -> `ValidationException`/`VALIDATION_ERROR`; cero escrituras y `RazonCausa` intacto. Nota: el IT afirma la semántica de la excepción, no el DBCODE crudo; el crudo lo cubren `DbExceptionTranslatorTest` y la inspección de los SP. |
| AN/SJC/EX (DR-006) | PASS con riesgo | Escritura: `ESTADOS_VALIDOS` + `RC_001`. Lectura: `AsistenciaConsultadaEntity` falla cerrado ante legacy/desconocido/ausente (test RED). Riesgo: `RazonCausa` contiene `CPI` y `CPVP` históricos; hoy `uv_detalle_asistencia` tiene 0 filas, pero una fila histórica haría fallar todo el listado. Deuda no bloqueante propuesta. |
| Skips IT de asistencia = 0 | PASS | `AsistenciaRepositorySqlServerIT` 6 run, 0 skipped, sin `assumeTrue`. `GoldenPathSqlStoredProcedureContractIT` 16/16, 0 skipped. |
| Grupo aula = 0 / HorarioEstudiante aula = 0 | PASS | `grep -i aula` en `src/main` = 0 coincidencias; SQL de Grupo sin `@aula`; el Golden Path IT afirma ausencia de `aula` en `uv_horario_estudiante`, `uv_horario_docente`, `uv_sesion` y `uv_grupo` contra la DB real. |
| Sesion create/update | PASS | `usp_crear_sesion`/`usp_actualizar_sesion` sin `@idDocente`; `@idUsuarioEjecutor` = `authenticatedUserResolver.requireAuthenticatedUserId()` (Usuario.id); firmas verificadas en el Golden Path IT. El campo `docente` en DTO/domain no es muerto: alimenta `institutionalScopePort.findDocenteIdByUsuario` (ownership). `usp_cerrar_sesion` legacy se conserva (SES_003 -> 501), fuera del target. |
| UTC | PASS | Los 4 lectores usan `toLocalDateTimeUtc` (Sesion x2, SesionMateriaEstudiante, Reporte); `RealtimeEventResponseTest` afirma `occurredAt` ISO-8601 con `Z`. |
| X-Correlation-Id | PASS | `CorrelationIdFilter` (valida UUID, rechaza cero/CRLF, eco en respuesta) + `CorrelationIdFilterTest`; `AuditHttpIT` 2/2 verifica eco y auditoría; los adapters usan `CorrelationIdContext.require()` como `@idCorrelacion`. |
| Cleanup | PASS | `SELECT` dinámico sobre todas las columnas de texto de todas las tablas: 0 filas con `IT-LB001B4-`. |
| Tests de los 3 SP no ocultados | PASS | `SqlStoredProcedureContractIT` sin `@Disabled`/`assume`, hash idéntico al RED; sus 3 fallos ([1],[7],[12]) siguen visibles. |

### Los 6 fallos de integración pertenecen exactamente a TD-043 y están fuera del Golden Path

Failsafe: 53 run, 6 failures, 0 errors, 2 skipped.

- `SqlStoredProcedureContractIT` [1] `usp_sincronizar_usuario`, [7] `usp_registrar_o_actualizar_plan_estudio`, [12] `usp_registrar_estudiante_en_grupo_usuario_no_existente` (3).
- `GrupoRepositorySqlServerIT` x2 y `UsuarioPasswordHashSqlServerIT` x1: `DatabaseOperationException` al ejecutar `usp_registrar_estudiante_en_grupo_usuario_no_existente` / `usp_sincronizar_usuario` (3).
- Los 3 SP no existen en la DB oficial (CONTRACT_DECISION_TD043) y solo se invocan desde `UsuarioRepositorySqlServerAdapter.crearUsuario` (`CrearUsuarioUseCaseImpl`, `UsuarioController`), `GrupoRepositorySqlServerAdapter.registrarEstudianteEnGrupo` (`RegistrarEstudianteUseCaseImpl`, `GrupoController`) y `PlanEstudioSqlServerAdapter` (`GestionarPlanEstudioUseCaseImpl`, `CoordinadorPortalController`). Ningún use case de `asistencia`, `sesion`, `docente`, `estudiante` ni el realtime los referencia: el Golden Path (`POST /asistencias/lote`, `GET /grupos/{id}/asistencias`, SSE, `GET docente/horarios`) no los invoca.

### Los 2 skips de `DocenteRepositorySqlServerIT`

Prueban `consultarAsignacionesAcademicas` (`GET /api/v1/docentes/{docenteId}/asignaciones`), no `GET /docente/horarios`, que usa `HorarioDocenteSqlServerAdapter` sobre `uv_horario_docente` (verificada por el Golden Path IT). Fuera del Golden Path: deuda no bloqueante propuesta (fixture autocontenido con prefijo `IT-LB001B4-`, sin `assumeTrue`). No bloquea.

### Deuda y decisiones

| Ítem | Cierre | Fundamento / condición |
|---|---|---|
| TD-036 | Procedente | Mapping DBCODE completo con tests; la DB publica el canal. Sustituye el `CONTRACT_CONFLICT`. |
| TD-030 / DR-009 | Procedente | `SEC_001/SEC_002/EST_004 -> 403/FORBIDDEN` con IT real; ya no depende de `VAL_003`. DR-009 pasa de PENDING. |
| TD-037 | Procedente | `SesionMateriaEstudianteSqlServerAdapter` usa `toLocalDateTimeUtc`; fixture con `Timestamp.from(Instant)`. |
| TD-038 | Procedente | `ReporteAsistenciaSqlServerAdapterTest` incluido en el RED con fixture UTC estable; 959/959 verde. |
| TD-040 | Procedente con salvedad | Columnas de `uv_estudiante_grupo`, `uv_estudiante_identidad` y `uv_usuario` confirmadas en la DB real (Golden Path IT); el `SELECT` del adapter se ejecutó en solo lectura y conserva el conteo de `uv_estudiante_grupo` (2 = 2). Salvedad: `DB_BASELINE_CONTRACT.md` sigue sin documentar esas vistas; pedirlo al equipo DB como acción no bloqueante. |
| TD-042 | Mantener abierta (no bloqueante) | `RealtimeEventResponseTest` usa un `JsonMapper` construido a mano, que TD-042 declara insuficiente (exige contexto Spring o config de producción). No hay `spring.jackson.*` ni customizer en `src/main`, por lo que aplica el default, pero no se demostró con contexto real. Cerrar solo si el owner acepta esa equivalencia por escrito. |
| TD-005 | No cerrar | La política temporal HTTP (`LocalDateTime` sin zona) pertenece a LB-001C; aquí solo se fija UTC en persistencia y `Z` en realtime. |
| TD-043 | Abierta | Correcta; no bloquea el Golden Path; bloquea liberar las 3 features y deja el perfil completo NOT_GREEN. |
| DR-006 | Procedente (Opción A, fail-closed) | Con el riesgo CPI/CPVP. |
| DR-001, 002, 004, 005, 007, 008 | Sin cambio | Ya RESOLVED en LB-001B/B.1; este work item no aporta evidencia nueva. |
| DR-003 | No cerrar | Mapping resuelto; timezone depende de TD-005. |
| DR-010 | No cerrar | Listado/orden/paginación fuera de LB-001B.4, sin evidencia. |

### Bloqueantes

Ninguno técnico. Condiciones para `06-cierre`:

1. `docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` figura como entregable en PLAN y **no existe** en el repositorio. Debe crearse antes de declarar LB-001B.4 DONE o marcarse NO APLICA con justificación.
2. Registrar en `TECHNICAL_DEBT.md`: skips del Docente IT (fuera de Golden Path), riesgo CPI/CPVP en lectura de estado, documentación DB de vistas (TD-040) y estado de TD-042.
3. Documentar que `-Pintegration verify` termina en rojo por TD-043 hasta que el owner decida (crear SP o retirar/adaptar adapters); MV-001 (E2E manual) sigue pendiente y no se presume ejecutado.

Trazabilidad: la validación `-Pintegration` (53/6/2) es la corrida de `target/failsafe-reports` de las 16:00, no repetida aquí; la corrida unitaria sí se repitió en esta auditoría.

---

## LB-001B.4A — SESSION CONTRACT POLISH (auditoría independiente)

Fecha: 2026-09-24. Rol: 05-auditor. Pase del mismo sistema de agentes, conceptualmente separado del implementador; no es una revisión externa. No se modificó código, tests, contratos ni DB; no hubo commit ni push. Java 25 (`C:\Program Files\Java\jdk-25`).

### Dictamen: PASS técnico con 1 hallazgo contractual no bloqueante (longitud de `nombre`) y 1 hallazgo documental

| # | Punto | Veredicto | Evidencia propia |
|---|---|---|---|
| 1 | `tema` HTTP/DTO/Domain/RepositoryDTO/mappers/validators = 0 | PASS | `grep -rniw tema src/main` = 0 coincidencias. En `src/test` solo aparece como valor literal ("Tema") o como aserción negativa (`FIELD_UNKNOWN`, `isEmpty()` sobre `field=='tema'`). Diff de `CrearSesionRequest`/`ActualizarSesionRequest` retira `setTema` y el alias `getNombre()==null?tema`. `ERR_TEMA_*` no existe en `src/main`. |
| 2 | Transporte `docente` en create/update = 0; `@idDocente` en crear/actualizar = 0 | PASS | `CrearSesion*`/`ActualizarSesion*` (DTO, Domain, RepositoryDTO, mappers, request) sin `docente`. Único `docente` en use cases: `findDocenteIdByUsuario(usuarioEjecutor)` como chequeo de rol, sin propagarlo. En `SesionRepositorySqlServerAdapter`, `@idDocente` aparece solo en `SQL_CERRAR_SESION` (línea 55) y su `addValue` en `cerrarSesion` (fuera de alcance, legacy SES_003). |
| 3 | Params SP exactos | PASS | `SQL_CREAR_SESION`: `@idGrupo,@nombre,@fechaHoraInicio,@fechaHoraFin,@idCorrelacion,@idUsuarioEjecutor`. `SQL_ACTUALIZAR_SESION`: `@idSesion,@nombre,@fechaHoraInicio,@fechaHoraFin,@idCorrelacion,@idUsuarioEjecutor`. Coinciden con `DB_BASELINE_CONTRACT.md` líneas 91/93 (sha `45e48c5a…`). |
| 4 | create nombre OK / tema 400 FIELD_UNKNOWN; update nombre OK / tema 400; campo de validación = nombre | PASS | `SesionControllerContractTest` (verde): `createWithTemaInsteadOfNombreIsRejectedAsUnknownField` (400, `details[0].field=tema`, `code=FIELD_UNKNOWN`, sin invocar el input port); equivalente de update (líneas 255-265); `createMissingOrTooLongNombreReportsFieldNombreNeverTema` (field=`nombre`, ninguno `tema`); creación/actualización con `nombre` capturan `getNombre()`. Ausencia de validador de request en Update: la longitud la valida `ActualizarSesionDomain` (1..150). |
| 5 | Realtime usa config REAL de Spring; TD-042 cerrable | PASS | `RealtimeEventResponseSpringJsonTest` usa `@SpringBootTest(classes={JacksonAutoConfiguration, JacksonInputConfig}, NONE)` con `@Autowired JsonMapper` (no `JsonMapper.builder().build()`), y un segundo test con `JacksonJsonHttpMessageConverter`. Ambos afirman `"occurredAt":"2026-09-23T18:52:28.123Z"`. No hay `spring.jackson.*` en recursos, así que el auto-config real es el de producción. Cumple la "Resolución esperada" de TD-042. Salvedad menor: contexto Jackson mínimo, no la aplicación completa; suficiente para el criterio de TD-042. Acción para 06-cierre: marcar TD-042 cerrada en `TECHNICAL_DEBT.md` (sigue "abierta" allí; también corregir la fila de `AUDIT` previo que la mantenía abierta). |
| 6 | DBCODE y Golden Path asistencia sin cambios | PASS con limitación | Árbol de trabajo sin commits acumulativos, así que no se puede aislar el diff por fase con git. Los archivos de asistencia/DBCODE modificados (`AsistenciaConsultadaEntity`, `DbFailureClassifier`, `DbTechnicalError`, tests) corresponden al lote LB-001B.4 ya auditado arriba (DR-006/TD-036); ninguno pertenece al conjunto Sesion/realtime de 4A. Re-ejecución: `*Asistencia*Test`, `*Sesion*Test`, `RealtimeEventResponse*Test` verdes y `verify` completo 967/0/0/0. Los IT con DB no se re-ejecutaron (fuera de alcance: NO DB). |
| 7 | Longitud de `nombre` 5..100 -> 1..150 | HALLAZGO (F-4A-1), ver abajo | La evidencia DB congelada indica `nvarchar(50)`. |
| 8 | Subset Sesion + `verify` | PASS | Subset: 0 fallos. `mvn -B -ntp verify`: exit 0, `Tests run: 967, Failures: 0, Errors: 0, Skipped: 0`, "All coverage checks have been met", BUILD SUCCESS. ArchUnit: `CleanArchitectureRulesTest` 20/20 y 32 referencias `architecture` sin fallos. JaCoCo (jacoco.csv, suma): LINE 86,48 % (>=80), BRANCH 70,93 % (>=70). Margen BRANCH 0,93 pp: estrecho (antes 1,6 pp); gate del `pom.xml` sin relajar. |

### Hallazgos

**F-4A-1 (contractual, no bloqueante) — longitud de `Sesion.nombre` inconsistente con la DB congelada.**
- Evidencia: `docs/work-items/LB-001B.1-db-source-of-truth-cleanup/PLAN.md` (tabla "DB SESSION CONTRACT", leída del SQL de DB_ROOT `schema/tables/Sesion.sql`): `Sesion.nombre` = `nvarchar(50) NOT NULL`. `DB_BASELINE_CONTRACT.md` no documenta longitudes; RED_SNAPSHOT de LB-001B.4 declara "decisión abierta del contrato" y los tests solo fijan blanco -> `REQUERIDO` y 151 -> `LONGITUD_INVALIDA`.
- Estado actual: Crear y Actualizar aceptan 1..150 (HTTP y Domain); Entity de lectura 1..150; mensaje "entre 1 y 150 caracteres".
- Dictamen: el cambio 5..100 -> 1..150 **no es correcto** contra la DB, pero **restaurar 5..100 tampoco lo es** (el máximo 100 ya excedía 50 y el mínimo 5 no tiene respaldo en DB). El valor consistente con la evidencia es 1..50. Riesgo: un nombre de 51..150 caracteres pasa la validación del backend y falla en el `INSERT`/`UPDATE` (truncamiento) como error técnico de persistencia en vez de 400 `VALIDATION_ERROR` en `nombre`. Antes de 4A la ventana insegura era 51..100 en Crear (y 51..150 en Actualizar, ya existente); 4A la extiende a Crear. Se evalúa como alineación incompleta, no como regresión de otro orden.
- Recomendación: no restaurar. Devolver a 02-contratos para decidir el máximo (propuesta 50, salvo que el equipo DB confirme otra longitud vigente) y documentarlo en `BACKEND_GOLDEN_PATH_CONTRACT.md`; luego 03-tester-red actualiza los RED (151 -> 51) y 04-implementador ajusta Crear/Actualizar/Entity/validador y el mensaje. Si el cambio se aplaza, registrar deuda nueva. Pedir al equipo DB confirmar `nvarchar(50)` por versión actual del SQL (no se abrió DB).

**F-4A-2 (documental, no bloqueante) — `BACKEND_GOLDEN_PATH_CONTRACT.md` desactualizado.** Las filas 7 y 8 (líneas 40-41) siguen listando `"tema"` en el request de `POST /sesiones` y `PUT /sesiones/{id}`, contradiciendo el código y los tests de 4A (`tema` -> 400 FIELD_UNKNOWN). Debe corregirse a `{grupo, nombre, fechaHoraInicio, fechaHoraFin}` y `{nombre, fechaHoraInicio, fechaHoraFin}`. Dueño: 02-contratos. (Además, el archivo existe ahora como no versionado; la condición 1 del dictamen previo queda satisfecha en existencia, pendiente de esta corrección.)

**F-4A-3 (informativo).** Los tests de 4A son el RED de 4A; los IT contra DB de Sesion (firma real de los SP) no se re-ejecutaron aquí por instrucción (NO DB); su resultado sigue siendo el del Golden Path IT ya auditado.

### Bloqueantes de 4A

Ninguno.

**Resolución en 06-cierre (2026-09-24):** F-4A-1 registrado como hallazgo abierto y [TD-048](../../baseline/TECHNICAL_DEBT.md#td-048) (propuesta máx. 50 a confirmar con equipo DB; sin cambio de código); F-4A-2 corregido en `BACKEND_GOLDEN_PATH_CONTRACT.md` (+ `.sha256`); TD-042 marcada CLOSED en `TECHNICAL_DEBT.md`; DR-010 RESOLVED Opción A (decisión posterior de contratos). Las filas TD-042 "Mantener abierta" y DR-010 "No cerrar" de la tabla del dictamen final inicial de LB-001B.4 son evidencia histórica y no se alteran. Condiciones para 06-cierre: resolver o registrar como deuda F-4A-1; corregir F-4A-2; cerrar TD-042 en `TECHNICAL_DEBT.md`; actualizar la nota "Mantener abierta" de TD-042 en la tabla de decisiones de este AUDIT.

---

## LB-001B.4B — SESSION NAME LENGTH ALIGNMENT (auditoría independiente; cierra TD-048)

Fecha: 2026-09-24. Rol: 05-auditor. Pase del mismo sistema de agentes, conceptualmente separado del implementador; no es una revisión externa. No se modificó código, tests, contratos ni DB; sin commit ni push; sin DB ni frontend. Java 25 (`C:\Program Files\Java\jdk-25`).

### Dictamen: PASS (sin bloqueantes)

| # | Punto | Veredicto | Evidencia propia |
|---|---|---|---|
| 1 | Crear: 50 OK, 51 rechazado | PASS | `CrearSesionDomain` línea 69: `hasLengthBetween(normalizado, 1, 50)`; `CrearSesionRequestValidator` línea 26: 1..50 con `INVALID_LENGTH`. Tests `CrearSesionDomainTest` (1/50 OK, 51 -> `LONGITUD_INVALIDA`) verdes en `verify`. |
| 2 | Actualizar: 50 OK, 51 rechazado | PASS | `ActualizarSesionDomain` línea 60: 1..50. `ActualizarSesionDomainTest` (`nameAcceptsBounds1And50AndRejects51WithMessage50`) verde. No hay validador HTTP de Update (solo Domain), igual que en 4A. |
| 3 | `SesionConsultadaEntity` máx 50 | PASS | Línea 72: `hasLengthBetween(nombreNormalizado, 1, 50)`; `SesionConsultadaEntityTest.nombre_acepta_50_y_rechaza_51` verde. |
| 4 | Mensaje `ERR_NOMBRE_SESION_LONGITUD_INVALIDA` | PASS | `SesionErrorCode` línea 10: "El nombre de la sesion debe tener entre 1 y 50 caracteres." (exacto). Validador HTTP: "El nombre debe tener entre 1 y 50 caracteres." |
| 5 | HTTP POST nombre 51 -> 400 `field=nombre`, `FIELD_INVALID_LENGTH` | PASS | `SesionControllerContractTest.createMissingOrTooLongNombreReportsFieldNombreNeverTema` afirma 400, `details[0].field=nombre`, `details[0].code=FIELD_INVALID_LENGTH`, sin `tema`, sin invocar el input port. La aserción del tester es correcta: el validador emite `ValidationErrorType.INVALID_LENGTH` y `ApiFieldErrorMapper` (línea 19) lo mapea a `ApiFieldErrorCode.FIELD_INVALID_LENGTH`. La corrección tras `TEST_CONTRACT_CONFLICT` queda validada (la primera versión con otro código era la errónea, no el mapper). |
| 6 | ACTIVE MAX150 COUNT=0 | PASS | `grep 150` sobre `src/main` y `src/test` filtrado por sesion/session = 0 coincidencias (validators, domains, entity, mensajes). Los únicos rangos en Sesion son 1..50 (nombre), 10..250 (descripción/observación de cierre; ajenos). |
| 7 | `tema` activo = 0 | PASS | `grep -i tema` en `src/main` sin coincidencias en código de Sesion (solo falsos positivos por subcadenas de "...Mapper"/"Sistema"). |
| 8 | Transporte `docente` create/update = 0 | PASS | Sin `docente` en DTO/Domain/RepositoryDTO/mappers/request de Crear/Actualizar; `SQL_CREAR_SESION` y `SQL_ACTUALIZAR_SESION` sin `@idDocente` (solo `SQL_CERRAR_SESION`, legacy fuera de alcance). |
| 9 | `aula` en `src/main` = 0 | PASS | `grep -rni aula src/main` = 0. |
| 10 | DBCODE/persistence/SP sin cambios en 4B | PASS con limitación | Parámetros de `SesionRepositorySqlServerAdapter` idénticos a los validados en 4A (`@idGrupo,@nombre,@fechaHoraInicio,@fechaHoraFin,@idCorrelacion,@idUsuarioEjecutor`; actualizar con `@idSesion`). mtime del adapter (00:09) anterior a las ediciones 4B de dominio/tests (00:34-00:35); ningún archivo `.sql`/DBCODE/`resources` de persistence tocado por 4B. Limitación: el árbol no tiene commits por fase, el aislamiento se basa en contenido + mtimes, no en `git diff` por fase. |
| 11 | RED intacto | PASS | SHA-256 actuales de los 4 tests congelados (`CrearSesionDomainTest`, `ActualizarSesionDomainTest`, `SesionConsultadaEntityTest`, `SesionControllerContractTest`) idénticos a los del `RED_SNAPSHOT` LB-001B.4B (`aa7fa05f…`, `488be9da…`, `94ee073f…`, `3830e235…`). El implementador no alteró los tests. |
| 12 | Subset Sesion | PASS | Cubierto por el `verify` completo (todos los `*Sesion*Test` sin fallos). |
| 13 | `mvn -B -ntp verify` (una vez, sin `-Pintegration`) | PASS | Exit 0. `Tests run: 970, Failures: 0, Errors: 0, Skipped: 0`. "All coverage checks have been met." BUILD SUCCESS. JaCoCo (suma de `jacoco.csv`): LINE 86,48 %, BRANCH 70,93 % (gates 80/70; margen BRANCH 0,93 pp, sin relajar el `pom.xml`). Coincide con lo reportado por el implementador. |
| 14 | ArchUnit | PASS | `CleanArchitectureRulesTest`: `Tests run: 20, Failures: 0, Errors: 0, Skipped: 0`. |
| 15 | Contrato/deuda aún no actualizados (a cargo de 06-cierre) | PASS (estado esperado) | `docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` línea 43 sigue diciendo "hoy el backend valida 1..150 ... decisión contractual abierta (TD-048)"; `TECHNICAL_DEBT.md` TD-048 = ABIERTA. Esto es correcto antes del cierre; ahora es contradictorio con el código, por lo que 06-cierre debe: (a) reescribir la nota para declarar `nombre` `minLength 1` / `maxLength 50` (creación, actualización y lectura; 51+ -> 400 `FIELD_INVALID_LENGTH` en POST y `ERR_NOMBRE_SESION_LONGITUD_INVALIDA` en dominio), (b) regenerar el `.sha256` del contrato, (c) marcar TD-048 CLOSED con esta auditoría como evidencia, (d) actualizar filas 7/8 si se desea explicitar la longitud. |

### Hallazgos

- Ninguno bloqueante ni contractual de código. Observación informativa: PUT con nombre de 51 caracteres solo se rechaza en Domain (no hay validador HTTP de Update); el código de error observable es el de dominio, no `FIELD_INVALID_LENGTH`. Coherente con el estado previo y con lo cubierto por los RED; si el contrato exige 400 con `field=nombre` en PUT, sería un cambio nuevo (02-contratos).
- Los IT contra DB no se re-ejecutaron (NO DB por instrucción); que `nvarchar(50)` sea vigente se apoya en la decisión humana registrada en `RED_SNAPSHOT.md` y la evidencia de LB-001B.1.

### Bloqueantes de 4B

Ninguno. Condición para 06-cierre: puntos 15 (a)-(c).

**Resolución en 06-cierre (2026-09-24, LB-001B.4B):** punto 15 (a)-(c) atendidos: nota de `BACKEND_GOLDEN_PATH_CONTRACT.md` reescrita (`nombre` `minLength=1`/`maxLength=50`), `.sha256` regenerado (`02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121`, verificado con `Get-FileHash`) y [TD-048](../../baseline/TECHNICAL_DEBT.md#td-048) CLOSED. Este dictamen 4B no se altera.
