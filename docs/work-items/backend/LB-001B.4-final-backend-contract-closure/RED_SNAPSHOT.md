# RED SNAPSHOT — LB-001B.4

## Ejecuciones

1. `mvnw -B -ntp -Dtest=DbExceptionTranslatorTest,FrozenDbGhostFieldContractTest,GrupoRepositorySqlServerAdapterTest,HorarioEstudianteSqlServerAdapterTest,SesionMateriaEstudianteSqlServerAdapterTest,ReporteAsistenciaSqlServerAdapterTest,RealtimeEventResponseTest test`
   - Java: 25
   - Exit code: 1
   - Tests: 74; failures: 21; errors: 0; skipped: 0.
   - Causa: comportamiento AS-IS no reconoce DBCODE, mantiene ghost fields y usa mapper temporal no UTC en `SesionMateriaEstudiante`.
2. `mvnw -B -ntp -DskipTests test-compile`
   - Java: 25
   - Exit code: 1
   - Errores: 11.
   - Causa: tests TARGET usan constructores sin `aula`; producción AS-IS aún exige el componente.

## SHA-256 de tests congelados

```text
d2056275059617cb8b605bd7b844dfe8cba61cd0e4a96884e2ad5609b2ecdb83  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbExceptionTranslatorTest.java
113fe6a6acd23e00f2395d7eda1b68e6ba73355650b137e7859c6f5fa24aa0ac  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/error/GlobalExceptionHandlerTest.java
5fcdc16ed73e4b9b9aa935aec27d2e95f91dc0491fc3b9d6a103b8f0da708573  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/GrupoRepositorySqlServerAdapterTest.java
a46eefdc697f147c5b89803464afd9db635bc01d82b0c390e5d5cef119ea3fed  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/testdouble/GrupoRepositoryMockAdapterTest.java
832f656398d3e94222c6524293bdb8ee6b9b6a8df9c91d9c780df12c7799eb66  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/grupo/mapper/GrupoHttpMapperContractTest.java
07818d007dc5c3b6dc2f8e30c7f284bc199ce74f2758001ec1c96371e410eb1d  src/test/java/co/edu/uco/asistenciasuco/application/features/grupo/creargrupo/primaryports/mapper/CrearGrupoMapperTest.java
2191066bf8bded2c154b6c5b5526a08759192369327b595f71adff51ae997378  src/test/java/co/edu/uco/asistenciasuco/application/features/grupo/creargrupo/usecase/mapper/CrearGrupoRepositoryMapperTest.java
13713db6f4aa1169b50888abbc3a3295c5b9574804b25b9850c57bf9aea7b379  src/test/java/co/edu/uco/asistenciasuco/application/features/grupo/actualizargrupo/primaryports/mapper/ActualizarGrupoMapperTest.java
a147fd5098eee5b5236be1a77f20717839867fd3b6e50deacf3cb018060fbfc3  src/test/java/co/edu/uco/asistenciasuco/application/features/grupo/actualizargrupo/usecase/mapper/ActualizarGrupoRepositoryMapperTest.java
fd43236fd70792d7c117a8b97f76ab0ae226ff55180029c102fe506535e27ab2  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioEstudianteSqlServerAdapterTest.java
3293de1d972268e02d0f4888266e81b30996242ee6719ad7dc21a2e864b52d45  src/test/java/co/edu/uco/asistenciasuco/application/features/estudiante/consultarhorarios/usecase/impl/ConsultarHorariosEstudianteUseCaseImplTest.java
7af2c9cbea09fe1331e94d9e8036bcc8853aae3fa9e6097c172c70fb67b66fcb  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/estudiante/EstudiantePortalControllerTest.java
d8f8e40617fd4012f391508c8f50585159c2eb84e3ad3edd5c57a0ef862ed33a  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/academic/SesionMateriaEstudianteSqlServerAdapterTest.java
06850e3b5a06ae6a55cac2ddf7098ef62d39791e7bf28bb9ed15018f12ab063c  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/reporting/ReporteAsistenciaSqlServerAdapterTest.java
b3aba5b4d8d89a13c2ed8b2b20ebaf6e9be1a1ef34a615c2c0436b2df6368499  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/contract/FrozenDbGhostFieldContractTest.java
7ac6e23517b5d1b0122e1999442fdec58219958cd6867d9a2fc1befc2ab0de6e  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/realtime/sse/response/RealtimeEventResponseTest.java
b844712e241c8c720e0bc0ddf15be4ceaffd7bfdfe94d45c0f929b21db4463cf  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/contract/SqlStoredProcedureContractIT.java
```

## Revisión controlada del snapshot por TEST_CONTRACT_CONFLICT

El dictamen de `AUDIT.md` autorizó al rol tester a corregir únicamente
`GrupoHttpMapperContractTest` y `SesionMateriaEstudianteSqlServerAdapterTest`. Los hashes
anteriores se preservan como evidencia RED original; los nuevos hashes se registran debajo
después de aplicar el dictamen. Los restantes archivos continuaron congelados.

```text
d295849c4ebe961c9f28bf0614792c1139d08896382b7f3a882a1892161565ed  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/grupo/mapper/GrupoHttpMapperContractTest.java
6f9f2d80fbce628ae9aaff63eadb541964123ba824fd756c4c159b40ff1abd6e  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/academic/SesionMateriaEstudianteSqlServerAdapterTest.java
```

## RED adicional — dominio canónico en lectura

`mvnw -B -ntp -Dtest=AsistenciaConsultadaEntityTest test` con Java 25 terminó con exit code 1:
10 pruebas, 2 fallos, 0 errores, 0 omitidas. Los dos fallos demostraron que la lectura aceptaba
un estado legacy/desconocido y un estado ausente. Snapshot del test previo a producción:

```text
f96f32e2f8b18028c88c21505bd6e9d9a50c35577ef18233edb3932c3753d8aa  src/test/java/co/edu/uco/asistenciasuco/application/features/asistencia/consultarasistenciasporgrupo/usecase/entity/AsistenciaConsultadaEntityTest.java
```


## TEST_CONTRACT_CONFLICT resuelto por alineación al contrato — AsistenciaRepositorySqlServerIT

- Conflicto: el IT previo esperaba `AsistenciaErrorCode.ERR_ESTADO_ASISTENCIA_INVALIDO` para el estado
  `ABC`; el contrato congelado LB-001B.4 fija `RC_001 → ValidationException / VALIDATION_ERROR / HTTP 400`.
- Resolución: el IT se alinea al contrato congelado (no se toca producción). `ABC` y el lote mixto afirman
  `ValidationException` con `getCode() == "VALIDATION_ERROR"`; el docente ajeno afirma `ForbiddenException`
  con `getCode() == "FORBIDDEN"` (sin depender del texto tras `|`). Todos verifican cero escrituras y que
  `RazonCausa` no cambia.
- Fixture autocontenido (sin `assumeTrue`): reutiliza grupo/docente/estudiantes seed y crea solo lo faltante
  (tercer estudiante y docente ajeno, prefijo `IT-LB001B4-`), con INSERT validado por metadata runtime y
  cleanup FK-safe en `@AfterEach`. Sin DDL.
- Nuevo gate: `GoldenPathSqlStoredProcedureContractIT` (SP/vistas del Golden Path). `SqlStoredProcedureContractIT`
  global queda intacto (mismo hash) y sigue evidenciando los SP ausentes.
- Ejecución: `mvnw -B -ntp verify -Pintegration -Dit.test=AsistenciaRepositorySqlServerIT,GoldenPathSqlStoredProcedureContractIT`
  (Java 25, `sql_server_asistencias / gestionasistenciadb`): exit 0; Asistencia IT 6/6 pass, 0 skipped;
  GoldenPath 16/16 pass. Sin filas `IT-LB001B4-` residuales; conteos de tablas iguales a los previos.

```text
b12aa9587aabcc1176e431b62ef0411b934d9576d63e41819dc615a521c687ee  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/AsistenciaRepositorySqlServerIT.java
0e17c4ed86c4aceb9dd286d2307f56662aba8a994d36c4a9bdfe92e42b20fc83  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/contract/GoldenPathSqlStoredProcedureContractIT.java
b844712e241c8c720e0bc0ddf15be4ceaffd7bfdfe94d45c0f929b21db4463cf  src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/contract/SqlStoredProcedureContractIT.java
```

## LB-001B.4A — SESSION CONTRACT POLISH (RED, tester)

Fecha: 2026-09-24. Base commit: `fa9aa901c73e55ae31071f4e74cfb2245189243a` (working tree con cambios previos sin commit de LB-001B.4).
Decision contractual: DB congelada tiene `Sesion.nombre`, NO `tema`.
`POST /api/v1/sesiones` = `{grupo, nombre, fechaHoraInicio, fechaHoraFin}`; `PUT /api/v1/sesiones/{id}` = `{nombre, fechaHoraInicio, fechaHoraFin}`.
`tema/topic/descripcion/aula/tipo/status/room` -> 400 `FIELD_UNKNOWN`. Codigos `ERR_TEMA_SESION_*` -> `ERR_NOMBRE_SESION_*`.
`CrearSesion*/ActualizarSesion*` (DTO, Domain, RepositoryDTO, mappers) sin `tema` ni `docente`; solo `usuarioEjecutor` (Usuario.id).
Use case: solo chequeo de rol via `institutionalScopePort.findDocenteIdByUsuario(usuarioEjecutor)`; no propaga docente.
Adapter: `usp_crear_sesion(@idGrupo,@nombre,@fechaHoraInicio,@fechaHoraFin,@idCorrelacion,@idUsuarioEjecutor)` y
`usp_actualizar_sesion(@idSesion,@nombre,@fechaHoraInicio,@fechaHoraFin,@idCorrelacion,@idUsuarioEjecutor)`, sin `@idDocente`.

Consumidores de `ERR_TEMA_SESION_*`: `grep` sobre `src`, `docs`, `.github`, `infra` -> solo `SesionErrorCode`,
`CrearSesionDomain`, `ActualizarSesionDomain`, `SesionConsultadaEntity` y `ActualizarSesionDomainTest`. Sin catalogo de mensajes,
docs/contracts ni contrato frontend que los cite. **No hay CONTRACT_CONFLICT por el rename.**
Nota para implementador: `SesionConsultadaEntity` (lectura) tambien lanza `ERR_TEMA_*`; el rename debe cubrirla
(test `SesionConsultadaEntityTest.usa_codigos_de_nombre_de_sesion`). El mensaje AS-IS "entre 5 y 100" de
`ERR_TEMA_SESION_LONGITUD_INVALIDA` contradice los limites reales (Actualizar/Entity 1..150); los tests solo fijan blanco -> REQUERIDO y 151 -> LONGITUD_INVALIDA
(no fijan minimo 5 ni maximo 100 de Crear; decision abierta del contrato, no inventada).

### Comando y resultado RED

`JAVA_HOME=jdk-25 ./mvnw.cmd -B -ntp -DskipTests test-compile` -> exit 1, `COMPILATION ERROR`, 28 errores en 12 archivos de test
(constructores de 5 parametros y `getNombre()` inexistentes en `CrearSesionDTO/Domain/RepositoryDTO`, `ActualizarSesionDTO/Domain/RepositoryDTO`).
Causa esperada: la produccion AS-IS aun expone `tema`/`docente` (6 parametros). El RED por compilacion bloquea `-Dtest=` del subset
(controller, adapter, use case, domain, mapper), que quedan RED hasta que exista la API nueva.

RED de comportamiento demostrado en copia aislada (sin tocar el repo; tests de sesion que no compilan retirados de la copia):
`-Dtest=SesionConsultadaEntityTest,RealtimeEventResponseSpringJsonTest,RealtimeEventResponseTest` -> `SesionConsultadaEntityTest.usa_codigos_de_nombre_de_sesion`
FALLA (`expected ERR_NOMBRE_SESION_REQUERIDO but was ERR_TEMA_SESION_REQUERIDO`).

TD-042: `RealtimeEventResponseSpringJsonTest` (2 tests, `@SpringBootTest` con `JacksonAutoConfiguration` + `JacksonInputConfig`, sin DB/Redis/servidor)
pasa hoy (2/2, GREEN): el mapper real de Spring ya emite `"occurredAt":"2026-09-23T18:52:28.123Z"`. Es guard de regresion, no RED.

### SHA-256 de tests LB-001B.4A (congelados)

```text
68a87566173b05c063631264175117f5d5dd0c491ac171a5e19466edd2ddb28e src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/primaryports/mapper/CrearSesionMapperTest.java
c0beb105d7190926b6a230d05f45bca0dcddcd97bc2c5851d304919a0d7937c4 src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/usecase/domain/CrearSesionDomainTest.java
431e733f40d4fc3da3ccdaf5a57f87abafc5cdcd386d83e4cf834f5c3e660c4e src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/usecase/impl/CrearSesionUseCaseImplTest.java
04d73f6362e39dd887ac36f09b319f99777846f2d4325a80485613489268f5a6 src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/usecase/mapper/CrearSesionRepositoryMapperTest.java
99b5f337c63ba7486b808eafd4f374df70a6ac747133717081d1ffd98c3243e2 src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/primaryports/mapper/ActualizarSesionMapperTest.java
9cba8cce59075c3d9537199ba3098b75287d520cf0b0d708ee8b24b4d35ba7f4 src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/usecase/domain/ActualizarSesionDomainTest.java
9aca583ecadbf717f4c0275b9864aa0bb3f42dda0a57a9e70241783768c73fc4 src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/usecase/impl/ActualizarSesionUseCaseImplTest.java
8ed81c010e4dfde6cba159e9a003847d2844888bb8e040598d89d185be057b10 src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/usecase/mapper/ActualizarSesionRepositoryMapperTest.java
87e9829c154301409f32b1e7c1ff106875aef9ed395bf69e8d4b6a731de45e00 src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/consultarsesion/usecase/entity/SesionConsultadaEntityTest.java
0bd5c11f20f7955ee21367a91ce0b9c1bcc8589790ad396e9e35c11a6fe30f0a src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/SesionControllerContractTest.java
b2ed8d3526606a28cb822b7cddf42ec302aa4492fdde3bd9e0292624e70a5232 src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapterTest.java
406a65191dec75bf4a2be6680d1187029098dfce8ec0ab34cf93d16599f4a746 src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/testdouble/SesionRepositoryMockAdapterTest.java
f41c3026c76e67305f096b4abb7779ec14fd7545f19218707d33db129b9d5c70 src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/AsistenciaRepositorySqlServerIT.java
571541f03b14ccb2f8e3c145d91eb3040161b523db2d5a7950dd74e14703e8dc src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/realtime/sse/response/RealtimeEventResponseSpringJsonTest.java
```

## LB-001B.4B — SESSION NAME LENGTH ALIGNMENT (RED, tester; cierra TD-048)

Fecha: 2026-09-24. Base commit: `fa9aa901c73e55ae31071f4e74cfb2245189243a` (working tree sin commit).
Decision humana: `dbo.Sesion.nombre = NVARCHAR(50)` (DB fuente de verdad) -> backend acepta 1..50 y rechaza 51+ (hoy 1..150).
Mensaje esperado de `ERR_NOMBRE_SESION_LONGITUD_INVALIDA`: "El nombre de la sesion debe tener entre 1 y 50 caracteres."
Cobertura: CrearSesionDomain (1 OK, 50 OK, 51 -> LONGITUD_INVALIDA + mensaje), ActualizarSesionDomain (idem),
SesionConsultadaEntity (50 OK, 51 -> LONGITUD_INVALIDA), POST /api/v1/sesiones nombre 51 -> 400 field=nombre code=FIELD_INVALID_LENGTH (tipo de validacion INVALID_LENGTH; corregido por TEST_CONTRACT_CONFLICT, ver ApiFieldErrorMapper).
PUT: no existe validador HTTP equivalente (solo CrearSesionRequestValidator), se cubre solo en Domain.
Ajustados 150/151 -> 50/51 en tests existentes. Produccion no tocada.

Comando: `JAVA_HOME=jdk-25 mvn -B -ntp -Dtest='*Sesion*' test` -> exit 1.
Fallos (razon correcta: la produccion aun acepta 51 chars, "nothing was thrown" / 201 en vez de 400):
- CrearSesionDomainTest.nombre_excesivo_usa_codigo_de_longitud_de_nombre, .nombre_acepta_limites_1_y_50_y_rechaza_51_con_mensaje_50
- ActualizarSesionDomainTest.rejectsInvalidNameLengthsWithNombreCodes, .nameAcceptsBounds1And50AndRejects51WithMessage50
- SesionConsultadaEntityTest.rechaza_identificadores_y_textos_invalidos, .usa_codigos_de_nombre_de_sesion, .nombre_acepta_50_y_rechaza_51
- SesionControllerContractTest.createMissingOrTooLongNombreReportsFieldNombreNeverTema (Status expected 400 but was 201)
Resto del subset Sesion PASS (sin regresiones); limites 1 y 50 pasan hoy, solo 51 falla.

### SHA-256 de tests LB-001B.4B (congelados)

```text
aa7fa05fd75c9685aef4cd5aa9ba84dbc26999846681c8e7e2880bc06aa6006d *src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/crearsesion/usecase/domain/CrearSesionDomainTest.java
488be9da35abaa6ee90c7e8ea6f1b78655717e6df64688b55eb554d746c2bf10 *src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/actualizarsesion/usecase/domain/ActualizarSesionDomainTest.java
94ee073f55e0321a0df0752af9cac88c01440996ad3fecc18b94f0840344d4fc *src/test/java/co/edu/uco/asistenciasuco/application/features/sesion/consultarsesion/usecase/entity/SesionConsultadaEntityTest.java
3830e23501e4d60032d61f160dc08e85eaed538dfb9a3a4a5e89535268c57931 *src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/SesionControllerContractTest.java
```
