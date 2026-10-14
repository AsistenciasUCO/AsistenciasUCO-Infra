# CONTRACT MATRIX — LB-001B (backend ↔ frontend, Golden Path de asistencia)

Formulario del [protocolo de alineación contractual](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md). `CONTRACT_ANALYSIS`: sin implementación, sin OpenAPI, sin JPA. Sin secretos (no se leyó `.env`).

**Roles en esta fase (instrucción del responsable):** backend AS-IS = PROVIDER; frontend AS-IS = CONSUMER. Una interface TypeScript no redefine el contrato y Angular no es evidencia de autorización; el backend es la autoridad de autorización. `MISMATCH`/`DECISION_REQUIRED` no autorizan a este análisis a elegir quién cambia.

**Estado del contrato: DRAFT — HTTP/FRONTEND CONTRACT NOT FROZEN.** Actualización 2026-09-22: el contrato frontend de `Sesion` quedó alineado por el work item hermano `AsistenciasUCO-Frontend/docs/work-items/LB-001B.1C-final-contract-cleanup/CLOSURE.md`; LB-001C sigue NOT STARTED. **Actualización 2026-09-23 (06-cierre, LB-001B.4):** DR-006 y DR-009 quedaron RESOLVED ([CLOSURE](../LB-001B.4-final-backend-contract-closure/CLOSURE.md)); DR-010 quedó RESOLVED (Opción A, 2026-09-24, LB-001B.4A) y la representación HTTP temporal depende de TD-005/LB-001C.

## 1. Evidencia y snapshots

| Campo | Backend (PROVIDER) | Frontend (CONSUMER) |
|---|---|---|
| Repo | AsistenciasUCO | AsistenciasUCO-Frontend |
| Ruta | `C:\Users\josev\AsistenciasUCO\AsistenciasUCO` | `C:\Users\josev\OneDrive\Documentos\Front_Asistecias\AsistenciasUCO-Frontend` |
| Branch | `sergio` | `develop` |
| HEAD | `fa9aa901c73e55ae31071f4e74cfb2245189243a` | `71ee6d32bfe1c6c58c04d0e986e525850ff6eb52` |
| `git status --short` | **59 entradas** (M/D/`??`: docs gobernanza sin trackear, `.claude/`, `contracts/`, `AGENTS.md`, catálogo, tests; `GlobalExceptionHandler.java` y `SesionControllerContractTest.java` modificados) | vacío |
| Dirty/clean | **DIRTY** — `HEAD` no identifica el snapshot; ver hashes | clean |
| Fecha de captura | 2026-09-20T19:33-05:00 | 2026-09-20T19:33-05:00 |
| Archivos requeridos | `pom.xml`, `src/main/java/`, `AGENTS.md`: presentes | `package.json`, `angular.json`, `src/app/`, `src/environments/`: presentes |
| Versiones | Spring Boot 4.0.6 (`pom.xml`), Java 25 | Angular 18.2.14 (`@angular/core`), CLI 18.2.21, `@microsoft/fetch-event-source` 2.0.1, Node 22.20.0 |

Limitaciones: (a) el backend sucio incluye trabajo TECH-001 sin commit; (b) no hay ejecución runtime backend+frontend; (c) `node_modules` del frontend es el instalado localmente (no `npm ci`), usado solo para leer el parser de `fetch-event-source` y ejecutar la suite; (d) el esquema DB no está versionado aquí (LB-001A cubre DB ↔ backend por certificación externa).

### 1.1 SHA-256 de archivos de evidencia — backend (estado respecto a `HEAD`)

| Ruta (relativa al backend) | SHA-256 | git |
|---|---|---|
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/docente/DocentePortalController.java` | `e00d1207c3cfdfb886bebb2f73b883c69eab21d87f9919ed0c2ffed4096098e7` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/SesionController.java` | `097c4207fb9326a541bba6de60bf90ffd2b501cfe5408f7ffb8ccfc6fa22031f` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/grupo/GrupoController.java` | `4dcfe5bd3f966eeadfd39465c72149a0e8b599ed088736ba523a9b963adf4a76` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/asistencia/AsistenciaController.java` | `bc6a3558f031a3ea73b7c056fb00fe3ec132b56e7daad21cfc51832eaa6ae448` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/asistencia/AsistenciaQueryController.java` | `2e01257119a426a9890aa486e374090939de949009fd56ef1a4911529fafdb00` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/asistencia/request/RegistrarAsistenciasSesionRequest.java` | `e7440fd2c2c98ecaaeba1549a54a30938449a94d5c918b5792076cd46092dd5e` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/asistencia/request/RegistroAsistenciaRequest.java` | `d31e5d72ff123dabfeabaf35c26c99f9108c7f9b29b464f2604dfb2578263d99` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/asistencia/mapper/AsistenciaHttpMapper.java` | `02db154a343eea36fa2e28d5b4979a1e2a6f6bf9dd9666592c6537e15b28acc5` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/docente/consultarhorarios/primaryports/dto/HorarioDocenteDTO.java` | `8e7f523579b4129051bb6e01da5d9c0ea1feae7a35006ceac1760eb626f476d4` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/sesion/consultarsesion/primaryports/dto/SesionConsultadaDTO.java` | `12641577caa7575ff55a831f9454a6ae25fc39c432951be73053cce2ae05359a` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/grupo/consultarestudiantesgrupo/primaryports/dto/EstudianteGrupoDTO.java` | `5e4b0c8ed7fc879427906d01499ea947ff42eb6d92cb2a738bbe21f2ae0696c9` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/asistencia/consultarasistenciasporgrupo/primaryports/dto/AsistenciaConsultadaDTO.java` | `707ac88d7a09695161d01a96dcbc66175acc9c7ab20530918a1fafe448c11ea0` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/response/ApiListResponse.java` | `d2a5be44632b241aa07b26b5fedc77cb676935133b03123e7421f89a8cd4f409` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/response/ApiMessageResponse.java` | `bb8b2e6782a2019e1fab21ce00c8d4f7db602f2287e38131f7aaad6f4bae2cf0` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/response/ApiDataResponse.java` | `780f3d128cb549e522fc58f3bb0a0f5d1bb7f1d581fae8339810dcd0f8e6647e` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/error/ApiErrorResponse.java` | `42f359eae21c9f2ef964404bd12c67497e5c07a5d84fc0e358b6e0743ba51a26` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/error/ApiFieldError.java` | `414c9fb8cb0d297d3bbe9dda36fda4c19e38e89890e28784366b187cfeb696d5` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/error/ApiErrorCatalog.java` | `04aa4d58b8a1b6cb914fcfa43c0c95f44d673137daa63a23ea1ad5a38c2bf9f0` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/error/GlobalExceptionHandler.java` | `205559cddc65b21700bb6aab2b1b6619822a9081cc4f55465164cbe66745bfa9` |  M |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/security/handler/SecurityErrorResponseWriter.java` | `7f5e306979f2144a3641e17b2570da6a05a7578123dad72f83f4adf0f028ea04` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/security/SecurityConfig.java` | `4e922d8a834908733f1a20deed7807a4b8006c6a8851f446713e8b24056a8b54` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/filter/CorrelationIdFilter.java` | `11efc1c3e18e9443e38f28b6e9a81e3edd138564f78d026e146bcae9c23d18ac` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/asistencia/registrarasistenciassesion/usecase/impl/RegistrarAsistenciasSesionUseCaseImpl.java` | `f244344082b904779224978f93d1fa6d9950f78fbc6de3e403ca294267ffa564` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/asistencia/registrarasistenciassesion/usecase/domain/RegistroAsistenciaSesionDomain.java` | `077ad82fe0c29134c00127e65327676879a6909d36a25eb20b61ff24881a05b9` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/asistencia/consultarasistenciasporgrupo/usecase/impl/ConsultarAsistenciasPorGrupoUseCaseImpl.java` | `2479050b0f89095253c51da329f220c2c687243de88ceab619aad43b7020af45` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/grupo/consultarestudiantesgrupo/usecase/impl/ConsultarEstudiantesGrupoUseCaseImpl.java` | `7f22ef3052506b803262d4962aa38087dc4cc48f036b54b741a8f80ca63e15d8` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/sesion/consultarsesionesporgrupo/usecase/impl/ConsultarSesionesPorGrupoUseCaseImpl.java` | `5b39c51ce71335e42a1d848bde8c5270eae6fcf44f7f28c6c270ff75bd1e2a2b` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/features/docente/consultarhorarios/usecase/impl/ConsultarHorariosDocenteUseCaseImpl.java` | `6c6c5710a7e466d666e86c62f0f0b6295df5b2847fc9094c8bed87a7f1a12881` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/realtime/RealtimeEvent.java` | `9282a5c11726406ae69ec2937e12f6cf3aa4eb4f1b9ba7daeff98e9c2c0823c5` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/realtime/sse/response/RealtimeEventResponse.java` | `9ce2a49f620ff4ecbf1aedf7f3aba7a999e279c402aa43b2286c94bb314eed8e` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/realtime/sse/controller/RealtimeEventsController.java` | `1ff4711c26e1598c507a27cdb5a4b17ee2d1640a6769c740e6d091aa82c644d2` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/realtime/sse/localsse/LocalSseRealtimeStreamGateway.java` | `8cb64068edfd928156d6e23eef88529b710ef20f5c2b66eba9306d56f837194e` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/realtime/localsse/ReactorRealtimeAdapter.java` | `690ee7e80cb0a2a069f1e5028347314b90d60b069c4ea5acd3cf43fb912ae1ea` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/jackson/JacksonInputConfig.java` | `5ba1ca89a9d482c69c9af903206890df3ffe7a933d910dc61768ade000584792` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/AsistenciaRepositorySqlServerAdapter.java` | `3bd0964b7ee3078af3b42537d19f08339e869b2b1ffb8de1cde4da5f8463873d` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` | `40ae367299fa67e8e3fa0be20976fee0e8b7980656155ec120b02e6e6e6de1f8` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/GrupoRepositorySqlServerAdapter.java` | `64b5ca104903a4381a50c2cda233d1a01d698654293d1b84f5e17dd1299a2c4c` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapter.java` | `2ec3178584c1a4668a5cbb5e085c96bd04b175241e4852de14168499db828892` | clean |
| `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbExceptionTranslator.java` | `d61b6f7aa6cb1db6bef85b817e2bb5fc626199cbe7350654fd594a5865899df7` | clean |
| `src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/SesionControllerContractTest.java` | `0f21400420ca4a3336861fe11291f1d6b0f59e6445e0bd377ccbfb24a7bd64cb` |  M |
| `src/main/resources/application.yml` | `0ea41c28e799d1ca7f772fb5975494f8a268b63e0744dca356f799e86bf8faca` | clean |

### 1.2 SHA-256 de archivos de evidencia — frontend (repo limpio en `develop@71ee6d3`; `node_modules` es local, no versionado)

| Ruta (relativa al frontend) | SHA-256 |
|---|---|
| `package.json` | `da636509702818a2f593dbe59b866a44f8448bd41dddf0e76a5bdd1d755745b2` |
| `angular.json` | `c31aa632d5d775cb0573fb475aebb11891a8859a9b0584674a792b75ebbc2675` |
| `package-lock.json` | `4ccf31a486a508541e34cfcc7060749269b17026e9fd419e3068222aacbe6ec0` |
| `src/environments/environment.ts` | `b8f3cc7c091afca063893d9b339f68b5ed58505407d812182bdad64603cc0196` |
| `src/app/app.config.ts` | `23a9592b993fdb8e37a4edb19e27422f95505d7cc7118448dd87297fad426aaf` |
| `src/app/app.routes.ts` | `e0b83fe29a4776c1520c00a41250a0e97168fa16a7c64507b85d572194b395b4` |
| `src/app/core/api/models/api-data-response.model.ts` | `5872243f96cd98e6c9ce611bdaea691892f1da39081dbfb84f7d3e0460e8dda0` |
| `src/app/core/api/models/api-error-response.model.ts` | `d4b0942d0d9549543831633adb6569612a1ae5c2fc6943393c358815ae35041c` |
| `src/app/core/api/models/api-field-error.model.ts` | `0aef973af600cb46683be597fb886fa938947fdc74eece79b3b4d27f0b4633d2` |
| `src/app/core/api/models/api-list-response.model.ts` | `5b106587ddec0b49f41dbe5bed41c6c9f91bfe8aae0157c42a99924f34749f34` |
| `src/app/core/api/models/api-message-response.model.ts` | `fc4d86e46c83e0f7a7a029d1310bbd55c130a6f18d041955884e7f5a212b6a69` |
| `src/app/core/api/models/asistencia-consultada-api-dto.model.ts` | `4084f3847d6156e9e0f0c5aade1f1699319649f79223a398a6972ba4b063f016` |
| `src/app/core/api/models/estudiante-grupo-api-dto.model.ts` | `d51694230db5ec45a41286020ee787996add820a613e0264b9bc808d6c59b49e` |
| `src/app/core/api/models/horario-docente-api-dto.model.ts` | `64dbd70e91a0d065405e8ba95b36eb2407c35005afdace192413f220b6dd8e80` |
| `src/app/core/api/models/registrar-asistencias-sesion-request.model.ts` | `f4b087cc5c8a6588d6a036d233fb1b5f252666c3e29f20e0065949d10ae277ba` |
| `src/app/core/api/models/sesion-consultada-api-dto.model.ts` | `e9755c04faa3b29535a515df6aa5a2538785c98a3ceee076397de88930925dcd` |
| `src/app/core/api/errors/api-error.util.ts` | `67a008d71d881c171629d1fa3f93d1ed6a2e8a829afb859cf8480957e83ff76d` |
| `src/app/core/models/attendance.model.ts` | `cba7b1d2a86df69ff877a9a149a986ef548a03ba63bf6ac49384aee0783b6af3` |
| `src/app/core/models/course.model.ts` | `e989bacbabcc24dd69353c3a82600c5d3f28c2588a898ddc1c47bc6876a83e34` |
| `src/app/core/models/api-response.model.ts` | `436e127df6b5f64293b7a085585175342bb68e94c5107e384d8bcf4629c4051a` |
| `src/app/core/mappers/attendance.mapper.ts` | `b10162348d95fd3d1d786febba1b839719fbb0fd12d3456cfff348d91aa08999` |
| `src/app/core/mappers/attendance.mapper.spec.ts` | `0b892b8d92ecb08cce861d6b258ed613578f044e7c1bd6977d1d5263424a6a9d` |
| `src/app/core/services/course.service.ts` | `3a6b247a288b9d27383bdf5e7f3436e0b28479009c0c0abb15acb0a0038b1cda` |
| `src/app/core/services/course.service.spec.ts` | `cf2eaadc8c3d78123bd60b6e770b5c6b9f48dfe6e107c10dba5fcc6abc7698f6` |
| `src/app/core/services/session.service.ts` | `8789777701eae17741030576ffcd0e712e3b035912c2beac219cd0569687a417` |
| `src/app/core/services/session.service.spec.ts` | `48e5e90f31f196a049bd78920443c86fb1128457a20c011ebec7da14b0c53941` |
| `src/app/core/services/group.service.ts` | `1af47ba84c7973483ac5591480c40f3b4a4884f208eb080377ac9f8d8adc85bc` |
| `src/app/core/services/group.service.spec.ts` | `4fb2228f30f2806541554a73b690e96387f3e487b7a754d79f6658d1949a631c` |
| `src/app/core/services/attendance.service.ts` | `18052637d7f0d1d67b081b6e2176dc246391a4073c596e4f412276043d592e6b` |
| `src/app/core/services/attendance.service.spec.ts` | `a34ffa36a1927dedd38b8b70fa07cc33fe73a08a83814c4974ef855157dcf8f1` |
| `src/app/core/services/auth.service.ts` | `a0d1cb3d0eb57570238bc02fdc50e1647d341cce46231b9071134ce4c09def5d` |
| `src/app/core/interceptors/auth.interceptor.ts` | `201ce2a122d9b4bc7f7b81ecad69c1a284a55c5186dd4a6bdaabe1af68513d43` |
| `src/app/core/interceptors/correlation.interceptor.ts` | `49c24faccb6663d6e945025bb066cb2989742e3b8c09e21b5b83e4f0a4f94502` |
| `src/app/core/interceptors/error.interceptor.ts` | `aa010dfdc5c066feeebe1e301bf17cd4601a2a4c76681a43e3d2838d44363aaa` |
| `src/app/core/guards/role.guard.ts` | `da1bd0f3e67c3e07d6ec4f71bce9268851b6679e346fce9e94371becd4263923` |
| `src/app/core/guards/auth.guard.ts` | `970dcd448d5388b260c1731a67fbc348db2355e41a87b819536a3128b99b3a8e` |
| `src/app/core/realtime/model/realtime-event.model.ts` | `af0047335366522138799943f6b84d6f72b5d1f16595e93f52aadc9301f0afcc` |
| `src/app/core/realtime/adapter/sse/fetch-sse-realtime-transport.ts` | `f68a4790c2848551307530e2d9bb86cdf58bdeec4e0ae8fd93bbcfae59c524a5` |
| `src/app/core/realtime/adapter/sse/fetch-sse-realtime-transport.spec.ts` | `bb93c6bd533bf22d34dc51305143f03f908136b6792102b23106f0fd68afdf17` |
| `src/app/core/realtime/realtime.service.ts` | `de50893d833502972f86288e1d4e026d4163610a181de887312f928cbecfbf9e` |
| `src/app/core/realtime/realtime.service.spec.ts` | `3bccb99e973dd198720277a06ebff1a0dd2fe65efa61e02510c7b4263a7dbfba` |
| `src/app/features/attendance/attendance-control/attendance-control.component.ts` | `8625734dbe93e0e87aba56b1ddf953176b47a8061d7a61b7b846984bb31bc0dc` |
| `src/app/features/attendance/attendance-control/attendance-realtime-sync.service.ts` | `03aa490993644e290eb276bc9a590ba0ad33b44c6468b5e53417443a16d77954` |
| `src/app/features/attendance/attendance-control/attendance-realtime-sync.service.spec.ts` | `79981aa304c8c0d21e71a312cc3f92e9912125ddffc8e323ba5c44374056e4d3` |
| `node_modules/@microsoft/fetch-event-source/lib/esm/parse.js` | `8e136b9d47df94b18490bdd347b3029f0ecffe96bd052dd0263143df8aac5e0b` |
| `node_modules/@microsoft/fetch-event-source/package.json` | `8a0893f441f5485aee558385118f480764e07bb5e83ff9b5a0a8354a8d9bf684` |

### 1.3 Convención de referencias

`BE:` = raíz del backend; `FE:` = raíz del frontend. Abreviaturas de rutas Java: `J` = `src/main/java/co/edu/uco/asistenciasuco`. Frontend: `A` = `src/app`. Los números de línea corresponden a los archivos con el SHA-256 de §1.1/§1.2.

## 2. Golden Path HTTP graph (código real)

```text
AttendanceControlComponent (FE:A/features/attendance/attendance-control/attendance-control.component.ts)
 ├─ constructor ─► CourseService.getCurrentTeacherCourses()      GET  /api/v1/docente/horarios                      [E-01]
 ├─ onCourseSelect ─► AttendanceRealtimeSyncService.connectGroup ► GET  /api/v1/realtime/stream?grupoId={UUID}       [E-06]
 ├─ onCourseSelect ─► SessionService.getSessionsByGroup()         GET  /api/v1/sesiones/grupo/{grupoId}              [E-02]
 ├─ cargarEstudiantesYSesion ─► forkJoin
 │     ├─ GroupService.getStudentsByGroup()                       GET  /api/v1/grupos/{grupoId}/estudiantes          [E-03]
 │     └─ AttendanceService.getAttendancesByGroup()               GET  /api/v1/grupos/{grupoId}/asistencias?sesionId [E-04]
 │        └─ AttendanceMapper.fromGroupStudentsAndAttendances()   (une ambas listas; ausencia ⇒ 'AN')
 ├─ saveAttendance() ─► AttendanceService.saveBatchAttendance()   POST /api/v1/asistencias/lote                      [E-05]
 │        └─ éxito ⇒ vuelve a llamar cargarEstudiantesYSesion() (E-03 + E-04)
 └─ AttendanceRealtimeSyncService.watch() ⇒ evento ASISTENCIAS_SESION_ACTUALIZADAS (grupo+sesión visibles, auditTime 250 ms)
          o transición RECONNECTING→CONNECTED ⇒ cargarEstudiantesYSesion() (HTTP = source of truth; SSE = trigger)
Backend: POST lote ─► UseCase ─► persiste (SP) ─► RealtimePublisherPort.publish ─► ReactorRealtimeAdapter ─► LocalSseRealtimeStreamGateway ─► SSE
```

Endpoints adyacentes usados por la misma pantalla y **fuera** del Golden Path (no analizados en profundidad): `GET /api/v1/tipos-identificacion` (catálogo), `POST /api/v1/sesiones` (crear sesión), `POST /api/v1/grupos/{id}/estudiantes` (matrícula; ver DR-008).

## 3. Matriz de endpoints (una fila por contrato)

| ID | Endpoint | Consumer (símbolo, FE:A/…) | Provider (símbolo) | Auth backend (`SecurityConfig`) | Ownership backend | Resumen |
|---|---|---|---|---|---|---|
| E-01 | `GET /api/v1/docente/horarios` | `core/services/course.service.ts` `getCurrentTeacherCourses()` (l.29) | `DocentePortalController.consultarHorarios` (l.64) → `ApiListResponse<HorarioDocenteDTO>` | `/api/v1/docente/**` `hasRole("DOCENTE")` (l.73) | docente resuelto por usuario autenticado (`ConsultarHorariosDocenteUseCaseImpl`), 403 si no resuelve | C-001 |
| E-02 | `GET /api/v1/sesiones/grupo/{grupoId}` | `core/services/session.service.ts` `getSessionsByGroup()` (l.139) | `SesionController.consultarSesionesPorGrupo` (l.95) → `ApiListResponse<SesionConsultadaDTO>` | `GET /sesiones/grupo/*` `DOCENTE` (l.96) | `canDocenteAccessGrupo` (`ConsultarSesionesPorGrupoUseCaseImpl` l.44) | C-002, C-013, C-014 |
| E-03 | `GET /api/v1/grupos/{grupoId}/estudiantes` | `core/services/group.service.ts` `getStudentsByGroup()` | `GrupoController.listarEstudiantesGrupo` (l.103) → `ApiListResponse<EstudianteGrupoDTO>` | `GET /grupos/**` `DOCENTE, COORDINADOR, ADMINISTRADOR` (l.113) | `canDocenteAccessGrupo` si el actor es docente (`ConsultarEstudiantesGrupoUseCaseImpl` l.36) | C-003 |
| E-04 | `GET /api/v1/grupos/{grupoId}/asistencias?sesionId={UUID}` | `core/services/attendance.service.ts` `getAttendancesByGroup()` | `AsistenciaQueryController.consultarAsistenciasPorGrupo` (l.45) → `ApiListResponse<AsistenciaConsultadaDTO>` | `GET /grupos/**` (l.113) | `canDocenteAccessGrupo` (`ConsultarAsistenciasPorGrupoUseCaseImpl` l.44) | C-004, C-012 |
| E-05 | `POST /api/v1/asistencias/lote` | `attendance.service.ts` `saveBatchAttendance()` | `AsistenciaController.registrarAsistenciasLote` (l.88) → 201 `ApiMessageResponse` | `POST /asistencias/lote` `DOCENTE` (l.97) | `canDocenteAccessGrupo` sobre el grupo de la sesión (`RegistrarAsistenciasSesionUseCaseImpl` l.83) | C-005 |
| E-06 | `GET /api/v1/realtime/stream?grupoId={UUID}` | `core/realtime/adapter/sse/fetch-sse-realtime-transport.ts` `runLoop()` (l.105) | `RealtimeEventsController.subscribe` (l.70) → `text/event-stream` | `/realtime/**` `authenticated()` (l.122) | `LocalSseRealtimeStreamGateway.subscribe` (l.45): 403 `ForbiddenException` si no es titular docente | C-009…C-011 |

Comparación por dimensión de cada endpoint (método, path, path/query params, body, response, status, auth, content-type, error, correlation) en §4.

## 4. Matriz contractual (una fila = un estado)

Estados permitidos: MATCH, MISMATCH, MISSING_IN_PROVIDER, MISSING_IN_CONSUMER, DECISION_REQUIRED, BLOCKED_BY_MISSING_EVIDENCE, NOT_APPLICABLE. `PROVIDER`/`CONSUMER` en la columna Owner action indican de qué lado está la diferencia; **no** se decide quién corrige.

### C-001 Grupos / horarios docente (E-01)

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-001a | Método/path/auth/status 200/content-type JSON | `GET /api/v1/docente/horarios`, `DOCENTE`, 200, `application/json` | `http.get(`${apiUrl}/docente/horarios`)` | MATCH | `DocentePortalController` l.64-67; `SecurityConfig` l.73; `course.service.ts` l.40-43; `course.service.spec.ts` l.31-32 | — | — |
| C-001b | Wrapper de lista | `ApiListResponse{exitoso:boolean, datos:List, total:int}` | `ApiListResponse<T>{exitoso, datos:T[], total:number}` | MATCH | `ApiListResponse.java`; `api-list-response.model.ts` | — | — |
| C-001c | Campos `id,idDocente,idGrupo,codigoMateria,nombreMateria,seccion,dia,horaInicio,horaFin,aula,totalEstudiantes` (nombre y tipo JSON) | `HorarioDocenteDTO(UUID×3, String×6, LocalTime×2, Integer)` | `HorarioDocenteApiDto` (string×9 + `number`) | MATCH | `HorarioDocenteDTO.java`; `horario-docente-api-dto.model.ts` | — | — |
| C-001d | Nullability y consistencia intra-grupo (todos los campos TS son no-nulos; `horaInicio.slice` lanza `TypeError` si es `null`; `enrolledStudentsCount` se toma de la 1.ª fila del grupo suponiendo `totalEstudiantes` idéntico entre bloques) | Java sin anotaciones de nulabilidad; DB (`uv_horario_docente`) no consta en este repo | No-nulos + supuesto de igualdad | BLOCKED_BY_MISSING_EVIDENCE | `HorarioDocenteSqlServerAdapter` l.24-27,35-39; `course.service.ts` l.51-56,74-86 | Medio: `TypeError` en el consumer o total inconsistente | Aportar nulabilidad de `uv_horario_docente` (B-02) |
| C-001e | Formato `LocalTime` en JSON | Sin test backend que aserte el JSON de `LocalTime` | Espera cadena; `slice(0,5)` tolera `HH:mm` y `HH:mm:ss`; spec usa `'08:00:00'` | BLOCKED_BY_MISSING_EVIDENCE | `HorarioDocenteSqlServerAdapterTest` (solo mapeo a `LocalTime`); `course.service.ts` l.52-56; `course.service.spec.ts` l.45,58 | Bajo (consumer tolerante) | Aserción de contrato/serialización (B-03) |
| C-001f | Agrupación: el provider devuelve **una fila por bloque horario** (`idGrupo` repetido); el consumer agrupa por `idGrupo`, concatena bloques en `schedule` y recalcula `total` = nº de grupos | `total` = nº de filas (bloques) | `total: courses.length` (no consume el `total` del provider) | MATCH | `course.service.ts` l.40-91; `course.service.spec.ts` l.25-68 | Bajo: `total` del provider no usado | — |
| C-001g | `Course.docenteName` | **No existe** en `HorarioDocenteDTO` | `docenteName: 'Docente UCO'` (constante). **FIELD_SYNTHESIZED_BY_FRONTEND** | MISSING_IN_PROVIDER | `course.service.ts` l.83; `course.model.ts` (`docenteName: string` obligatorio) | Medio: la UI puede mostrar un docente inexistente | DR-004 |
| C-001h | `Course.colorCategory` | No existe | Asignación cíclica emerald/amber/blue/purple. **FIELD_SYNTHESIZED_BY_FRONTEND** (solo presentación) | NOT_APPLICABLE | `course.service.ts` l.68-72,85 | Ninguno: no es dato de dominio | — |
| C-001i | `Course.schedule`, `Course.id`(=`idGrupo`), `room`(=`aula`), `docenteId`(=`idDocente`), `code`, `name`, `section` | Todos provienen de campos del provider | Derivación local | MATCH | `course.service.ts` l.74-86 | — | — |
| C-001j | Campo del provider no usado | `id` (id de horario) | No referenciado | MISSING_IN_CONSUMER | `course.service.ts` (sin uso de `horario.id`) | Ninguno | — |

### C-002 Sesiones del grupo (E-02)

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-002a | Método/path/auth/wrapper | `GET /api/v1/sesiones/grupo/{grupoId}` `DOCENTE`, `ApiListResponse<SesionConsultadaDTO>` | `GET ${apiUrl}/sesiones/grupo/${grupoId}` | MATCH | `SesionController` l.95-102; `SecurityConfig` l.96; `session.service.ts` l.139-142; `session.service.spec.ts` l.24-32 | — | — |
| C-002b | DTO `sesion,grupo,nombre,numero,codigo,numeroSemana,codigoGrupo,nombreGrupo,fechaHoraInicio,fechaHoraFin` (nombre/tipo JSON) | `SesionConsultadaDTO` (`UUID×2, String×4, Integer×2, LocalDateTime×2`) | `SesionConsultadaApiDto` (string/number) | MATCH | `SesionConsultadaDTO.java`; `sesion-consultada-api-dto.model.ts`; `SesionControllerContractTest` l.84-92 | — | — |
| C-002c | Nullability del DTO (TS los declara no-nulos) | Sin anotaciones; DB (`uv_sesion`) no consta | No-nulos | BLOCKED_BY_MISSING_EVIDENCE | `SesionRepositorySqlServerAdapter` l.104-117 | Bajo | B-02 |
| C-002d | Mapeo directo: `id`←`sesion`, `courseId`←`grupo`, `sessionNumber`←`numero`, `title`←`nombre` | Campos existentes | Mapeo 1:1 | MATCH | `session.service.ts` l.146-149 | — | — |
| C-002e | `ClassSession.topic` | **No existe** (`nombre` es el único texto). El backend **acepta** `tema`/`descripcion` al escribir (`CrearSesionRequest`, `ActualizarSesionRequest`) pero **no los devuelve** | `topic: session.nombre` (duplica el título). **FIELD_SYNTHESIZED_BY_FRONTEND** | MISSING_IN_PROVIDER | `session.service.ts` l.150; `SesionConsultadaDTO.java`; `CrearSesionRequest.java` l.8-10 | Bajo-Medio: el tema mostrado es el nombre | DR-004 |
| C-002f | `ClassSession.room` (`aula`) | No existe en la lectura (sí se acepta `aula` al crear) | No se asigna (queda `undefined`) | MISSING_IN_PROVIDER | `session.service.ts` l.145-156; `CrearSesionRequest.java` l.13 | Bajo (campo opcional) | DR-004 |
| C-002g | `ClassSession.tipo` (`REGULAR|EXTRAORDINARIA|REPOSICION`) | No existe en la lectura (sí se acepta `tipo` al crear) | No se asigna | MISSING_IN_PROVIDER | `session.service.ts` l.145-156; `CrearSesionRequest.java` l.14 | Bajo (campo opcional) | DR-004 |
| C-002h | `ClassSession.status` | **No existe** (ver C-013) | `status: 'PROGRAMADA'` constante. **FIELD_SYNTHESIZED_BY_FRONTEND** | MISSING_IN_PROVIDER | `session.service.ts` l.154 | Alto | DR-001 |
| C-002i | `ClassSession.date`, `startTime`, `endTime` | `LocalDateTime` completo | Almacena el datetime completo (ver C-014) | MISMATCH | `session.service.ts` l.151-153 | Medio | DR-003 |
| C-002j | Campos del provider no usados | `codigo, numeroSemana, codigoGrupo, nombreGrupo` | Declarados en el DTO TS pero no mapeados a `ClassSession` | MISSING_IN_CONSUMER | `session.service.ts` l.145-156 | Ninguno | — |
| C-002k | `records` inicial | — | `records: []`, se completa con E-03+E-04 | NOT_APPLICABLE | `session.service.ts` l.155 | — | — |

### C-003 Estudiantes del grupo (E-03)

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-003a | Método/path/auth/wrapper | `GET /api/v1/grupos/{grupoId}/estudiantes`, `ApiListResponse<EstudianteGrupoDTO>` | `GET ${apiUrl}/grupos/${grupoId}/estudiantes` | MATCH | `GrupoController` l.103-110; `group.service.ts`; `group.service.spec.ts` l.24 | — | — |
| C-003b | Campos `id,idEstudiante,documento,nombreCompleto,correo,codigoEstado,nombreEstado` | `EstudianteGrupoDTO(UUID×2, String×5)` | `EstudianteGrupoApiDto` (string×7) | MATCH | `EstudianteGrupoDTO.java`; `estudiante-grupo-api-dto.model.ts` | — | — |
| C-003c | Nullability (`correo`, `codigoEstado`, `nombreEstado`; `documento` proviene de `CAST(numeroIdentificacion AS VARCHAR(20))`, [TD-006](../../baseline/TECHNICAL_DEBT.md#td-006)) | Sin anotaciones; DB no consta | No-nulos | BLOCKED_BY_MISSING_EVIDENCE | `GrupoRepositorySqlServerAdapter` (query estudiantes) | Bajo | B-02 |
| C-003d | Campos usados por el consumer | `idEstudiante, documento, nombreCompleto` | `studentId, studentCode, studentName` | MATCH | `attendance.mapper.ts` l.89-91; `attendance.mapper.spec.ts` l.31 | — | — |
| C-003e | Campos no usados | `id` (matrícula), `correo`, `codigoEstado`, `nombreEstado` | No referenciados | MISSING_IN_CONSUMER | `attendance.mapper.ts` l.68-93 | Ver DR-007 (`codigoEstado`) | — |
| C-003f | Lista vacía | 200 con `datos: []`, `total: 0` | `[]` ⇒ tabla vacía; `saveAttendance()` retorna sin llamar ni avisar si no hay registros | MATCH | `GrupoController` l.110; `attendance-control.component.ts` l.547 | Bajo (UX silenciosa) | — |
| C-003g | Elegibilidad: la query devuelve **todos** los `uv_estudiante_grupo` del grupo sin filtrar `codigoEstado`; el consumer envía **todos** en el batch | Sin filtro por estado de matrícula | Los envía todos con su estado | DECISION_REQUIRED | `GrupoRepositorySqlServerAdapter` (`WHERE eg.idGrupo = :idGrupo`); `attendance-control.component.ts` l.550-556 | Medio: estudiantes retirados/inactivos podrían recibir asistencia | DR-007 |

### C-004 Consulta de asistencia (E-04)

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-004a | Método/path/query/auth/wrapper | `GET /api/v1/grupos/{grupoId}/asistencias`, `sesionId` opcional (`required=false`), `ApiListResponse<AsistenciaConsultadaDTO>` | `GET …/grupos/${grupoId}/asistencias` con `params:{sesionId}` solo si está definido; siempre lo envía desde la pantalla | MATCH | `AsistenciaQueryController` l.45-58; `attendance.service.ts` (`getAttendancesByGroup`) | — | — |
| C-004b | Campos `asistencia,estudiante,grupo,sesion` (UUID→string), `presente` | `UUID×4`, `Boolean presente` (`rs.getBoolean`: nunca `null` en runtime) | `string×4`, `presente: boolean|null` (consumer más amplio) | MATCH | `AsistenciaConsultadaDTO.java`; `AsistenciaRepositorySqlServerAdapter` l.184; `asistencia-consultada-api-dto.model.ts` | — | — |
| C-004c | `estado`: **dominio de valores** | `String` sin restricción; SQL lee `da.codigoRazonCausa` **sin mapear ni filtrar**. `ESTADOS_VALIDOS={AN,SJC,EX}` solo se aplica en la **escritura** (`RegistroAsistenciaSesionDomain` l.18). El propio código admite que la DB puede conservar códigos históricos (A, F, J, T…) ([TD-009](../../baseline/TECHNICAL_DEBT.md#td-009)); LB-001A M-01..M-03 verifica columna y escritura, no un filtro de lectura | TS `'AN'|'SJC'|'EX'` (más restringido que Java); el mapper **lanza** ante otro valor | DECISION_REQUIRED | `AsistenciaRepositorySqlServerAdapter` l.99; `RegistroAsistenciaSesionDomain.java` l.13-18; `asistencia-consultada-api-dto.model.ts`; `attendance.mapper.ts` l.80-86,97-99; [LB-001A CONTRACT_MATRIX](../LB-001A-db-backend-asistencia/CONTRACT_MATRIX.md) M-01..M-03 | Alto: un código histórico rompe la carga de toda la lista (error genérico) | DR-006 |
| C-004d | `observacion` | Siempre `''` (literal SQL `'' AS observacion`); `String` | `string|null`; no se usa | MISSING_IN_CONSUMER | `AsistenciaRepositorySqlServerAdapter` l.100 | Ninguno hoy; semántica engañosa (¿vacío o no capturado?) | — |
| C-004e | Otros campos no usados | `asistencia, grupo, sesion, presente` | Solo se usa `estudiante` (clave) y `estado` | MISSING_IN_CONSUMER | `attendance.mapper.ts` l.72-79 | Ninguno | — |
| C-004f | Orden y unicidad | Sin `ORDER BY`; unicidad (estudiante, sesión) no demostrada | Indexa por `estudiante` con `Map` (la última fila gana en silencio) | BLOCKED_BY_MISSING_EVIDENCE | `AsistenciaRepositorySqlServerAdapter` l.93-108; `attendance.mapper.ts` l.72-74 | Bajo-Medio si hubiera duplicados | B-01 |

### C-005 Registro batch (E-05)

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-005a | Método/path/auth/status/content-type | `POST /api/v1/asistencias/lote`, `DOCENTE`, **201**, `application/json` | `http.post(…/asistencias/lote, payload)`; 2xx ⇒ `next` | MATCH | `AsistenciaController` l.88-99; `SecurityConfig` l.97; `attendance.service.ts` (`saveBatchAttendance`) | — | — |
| C-005b | Body `sesionId`, `registros[].estudianteId`, `registros[].estado` | `RegistrarAsistenciasSesionRequest{UUID sesionId, List<RegistroAsistenciaRequest{UUID estudianteId, String estado}>}` | `RegistrarAsistenciasSesionRequest{sesionId, registros[{estudianteId, estado:'AN'|'SJC'|'EX'}]}` | MATCH | `RegistrarAsistenciasSesionRequest.java`; `RegistroAsistenciaRequest.java`; `registrar-asistencias-sesion-request.model.ts` | — | — |
| C-005c | Valores de `estado` | Acepta `AN`,`SJC`,`EX` (normaliza trim+mayúsculas); otro ⇒ 400 `ERR_ESTADO_ASISTENCIA_INVALIDO` | Emite exactamente `AN|SJC|EX` | MATCH | `RegistroAsistenciaSesionDomain.java` l.18-30; `attendance-control.component.ts` l.549-556 | — | — |
| C-005d | Rigidez del JSON (propiedades desconocidas) | `FAIL_ON_UNKNOWN_PROPERTIES` activo ⇒ cualquier campo extra ⇒ 400 | Envía solo los 3 campos (spec verifica ausencia de `grupoId`, `status`, `notes`, `observaciones`) | MATCH | `JacksonInputConfig.java` l.18; `attendance.service.spec.ts` l.29-44 | — | — |
| C-005e | Respuesta | `ApiMessageResponse{exitoso:boolean, mensaje:String}` | `ApiMessageResponse{exitoso, mensaje}`; usa `exitoso` y `mensaje` | MATCH | `ApiMessageResponse.java`; `api-message-response.model.ts`; `attendance-control.component.ts` l.562-575 | — | — |
| C-005f | Causa/observación de excusa capturadas en la UI | El request **no** admite esos campos (y rechazaría propiedades extra) | `confirmarExcusaConDatos({causa, observacion})` marca `EX` y **descarta** causa/observación (solo toast) | MISSING_IN_PROVIDER | `attendance-control.component.ts` l.257-268 (`confirmarExcusaConDatos`); `RegistroAsistenciaRequest.java` | Medio: el docente cree registrar una causa que no se persiste | DR-005 |
| C-005g | `registros` vacío | 400 `ERR_REGISTROS_ASISTENCIA_REQUERIDOS` | Retorna sin llamar y sin mensaje | MATCH | `RegistrarAsistenciasSesionDomain.java`; `attendance-control.component.ts` l.547 | Bajo (UX silenciosa) | — |
| C-005h | Re-guardado de una sesión ya registrada (idempotencia/upsert) | Comportamiento del SP ante segundo POST no consta en este repo | El flujo normal de edición reenvía el lote completo | BLOCKED_BY_MISSING_EVIDENCE | `RegistrarAsistenciasSesionUseCaseImpl` l.62-69; LB-001A (no cubre re-guardado) | Alto si el SP duplica o rechaza | B-01 |
| C-005i | Atomicidad del lote | Cubierta por LB-001A (IT `lote_mixto…atómico`, reportado externamente) | Sin expectativa distinta | NOT_APPLICABLE | Contrato DB↔backend cerrado en [LB-001A](../LB-001A-db-backend-asistencia/CLOSURE.md); no reproducido aquí | — | — |
| C-005j | Sesión concluida/cancelada | El use case **no** valida estado de sesión (solo existencia y titularidad); SP: sin evidencia | `isSessionConcluded()` bloquea guardado en la UI pero **nunca es verdadero** (ver C-013) | BLOCKED_BY_MISSING_EVIDENCE | `RegistrarAsistenciasSesionUseCaseImpl` l.62-69,72-93 | Alto | B-01, DR-001 |

### C-006 Error envelope

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-006a | Estructura `timestamp,status,error,code,message,path,correlationId,details` | `ApiErrorResponse(OffsetDateTime, int, String, String, String, String, String, List<ApiFieldError>)`; `details` omitido si vacío (`NON_EMPTY`); `ApiFieldError{field,code,message}` | `ApiErrorResponse{timestamp:string,status:number,error,code,message,path,correlationId:string|null,details?:ApiFieldError[]}` | MATCH | `ApiErrorResponse.java`; `ApiFieldError.java`; `api-error-response.model.ts`; `api-field-error.model.ts`; `api-error.util.ts` l.21-46 | — | — |
| C-006b | Errores de la capa de seguridad (401/403) | JSON escrito a mano por `SecurityErrorResponseWriter` (sin `details`); mismos campos | Tipo lo tolera (`details` opcional) | MATCH | `SecurityErrorResponseWriter.java`; [TD-021](../../baseline/TECHNICAL_DEBT.md#td-021) | Bajo | — |
| C-006c | Campos legacy que el consumer consulta | No existen `mensajeUsuario` ni `idTransaccion`/`mensajeTecnico`/`token` en ningún wrapper | `ApiResponse<T>` los declara; `getApiErrorMessage` intenta `errBody.mensajeUsuario` antes que `message` | MISSING_IN_PROVIDER | `api-response.model.ts`; `api-error.util.ts` l.76-79; `course.service.ts` l.20-25 | Bajo: rama muerta | — |
| C-006d | Status HTTP posibles del provider | 400, 401, 403, 404, 409, 422 (`UNPROCESSABLE_CONTENT`), 500, 501 | Ramas explícitas: 0, 400, 401 (interceptores), 403 (toast global), 404, 409, ≥500; 422 y 501 caen a `message` del body o al mensaje genérico | MISSING_IN_CONSUMER | `ApiErrorCatalog.java` l.55-92; `api-error.util.ts` l.92-116; `error.interceptor.ts` | Bajo: el `message` del body se muestra si existe | — |
| C-006e | Uso de `code` | Devuelve `code` estable por error | El consumer **nunca ramifica por `code`**; solo muestra `message` | MISSING_IN_CONSUMER | `api-error.util.ts` (sin uso de `.code` en decisiones); `attendance-control.component.ts` l.577-581 | Bajo hoy; relevante al congelar catálogo | — |
| C-006f | `correlationId` del error | Presente en todos los errores del provider | `getApiCorrelationId` existe, pero **no se usa en ninguna pantalla** (el usuario no ve el código de seguimiento) | MISSING_IN_CONSUMER | `api-error.util.ts` l.129-131; grep `getApiCorrelationId` en `FE:A` (solo definición y specs) | Medio para soporte | — |
| C-006g | Semántica de códigos para autorización/titularidad | [TD-030](../../baseline/TECHNICAL_DEBT.md#td-030): SPs internos usan `VAL_003` (semántica de nombres/apellidos) para fallos de autorización/titularidad; no verificable en este repo. Además `ERR_ESTUDIANTE_NO_PERTENECE_SESION` se traduce a **403** (`DbExceptionTranslator` l.30-32) aunque describe pertenencia | El consumer trata 403 como «sin permisos» (toast global) | DECISION_REQUIRED | `DbExceptionTranslator.java` l.30-32; TD-030 | Alto para freeze de errores | DR-009 (**TD-030 sigue ABIERTA; bloquea el freeze completo del contrato de errores en LB-001C**) |

### C-007 Autenticación y autorización

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-007a | Esquema | Resource server JWT Bearer (`Authorization: Bearer`), stateless; sin tokens por query | `authInterceptor` adjunta `Authorization: Bearer` a peticiones de `apiUrl`; SSE lo envía por header | MATCH | `SecurityConfig` l.62-63,126-136; `auth.interceptor.ts` l.15-50; `fetch-sse-realtime-transport.ts` l.132-138 | — | — |
| C-007b | Rol requerido en E-01, E-02, E-05 | Solo `DOCENTE` | Ruta `/app/asistencia` permite `DOCENTE, DECANO, ADMINISTRADOR, ADMIN`; el guard solo oculta la ruta | MISMATCH | `SecurityConfig` l.73,96,97,113; `app.routes.ts` l.59-66; `role.guard.ts`; `RbacSecurityFilterChainTest` l.199-215 | Alto: DECANO/ADMIN cargan la pantalla y reciben 403 (+2 toasts) al pedir sus datos | DR-008 |
| C-007c | Titularidad (ownership) | Aplicada en backend (4 use cases + gateway realtime); el backend es la autoridad | El consumer no implementa titularidad; solo lista lo que devuelve E-01 | MATCH | ver §3; `LocalSseRealtimeStreamGateway` l.45 | — | — |
| C-007d | 401 | JSON 401 (`ApiAuthenticationEntryPoint`, `UNAUTHORIZED`) | HTTP: `errorInterceptor` (**el más interno**) llama `notifySessionExpired()` —limpia token **y refresh token en memoria** y redirige— antes de que `authInterceptor.catchError → handle401` intente renovar. **Inferido por lectura del orden de interceptores `[correlation, auth, error]`; no ejecutado.** SSE renueva por su cuenta (`refreshAccessToken`) | MISMATCH | `app.config.ts` l.21; `error.interceptor.ts` l.14-24; `auth.interceptor.ts` l.47-54,66-107; `auth.service.ts` l.439-454; `fetch-sse-realtime-transport.ts` l.179-203 | Medio: el refresco silencioso tras un 401 del backend queda anulado; la renovación preventiva (`getValidAccessToken(30)`) sí opera. Diferencia **consumer↔intención documentada del consumer** (commit `7d21f28`), no contra el provider | CONSUMER — ver TD-031 |
| C-007e | 403 | JSON 403 (`FORBIDDEN` o código de negocio) | Toast global (`errorInterceptor`) **y** mensaje del componente | MATCH | `error.interceptor.ts` l.24-26; `attendance-control.component.ts` l.577-581 | Bajo (duplicado visual) | — |
| C-007f | CORS/credenciales | `allowCredentials=true`; headers permitidos `Authorization, Content-Type, X-Correlation-Id, Accept`; expone `X-Correlation-Id` | HTTP `withCredentials:true`; SSE `credentials:'omit'` con solo esos headers; API en otro origen (nginx no hace proxy) | MATCH | `SecurityConfig` l.158-166; `fetch-sse-realtime-transport.ts` l.132-139; `FE:nginx/default.conf` | — | — |
| C-007g | Expiración del JWT con el stream abierto | JWT validado solo al abrir la conexión; sin evidencia de cierre/renovación durante el stream | Renueva el token solo al (re)conectar; no reconecta por expiración | BLOCKED_BY_MISSING_EVIDENCE | `RealtimeEventsController.subscribe` l.70-82; `fetch-sse-realtime-transport.ts` l.111-123 | Medio (runtime) | B-04 (MV-001) |

### C-008 Correlation ID

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-008a | Nombre del header | `X-Correlation-Id` (entrada, respuesta y CORS `exposed`) | `X-Correlation-Id` | MATCH | `CorrelationIdFilter` l.20; `correlation.interceptor.ts` l.5,11 | — | — |
| C-008b | Formato/preservación | Acepta solo UUID canónico (≠ nulo); otro valor ⇒ genera uno nuevo en silencio | Genera `crypto.randomUUID()` (canónico); **no sobreescribe** un header existente | MATCH | `CorrelationIdFilter` l.43-70; `correlation.interceptor.ts` | — | — |
| C-008c | Header de respuesta | Siempre lo fija | No lo lee (ni en éxito ni en error) | MISSING_IN_CONSUMER | `CorrelationIdFilter` l.35; grep `FE:A` (sin lectura de `headers.get('X-Correlation-Id')`) | Bajo | — |
| C-008d | `correlationId` en el body de error | Presente | Tipado, no mostrado (ver C-006f) | MISSING_IN_CONSUMER | ver C-006f | Medio | — |
| C-008e | SSE | El header de la conexión se acepta; cada evento lleva el `correlationId` **de la petición que lo publicó** (contexto del POST lote), no el de la conexión SSE | Envía uno propio por conexión/reintento y conserva `event.correlationId` (nullable) sin usarlo | MATCH | `ReactorRealtimeAdapter` l.74; `RealtimeEventResponse.java`; `fetch-sse-realtime-transport.ts` l.136; `realtime-event.model.ts` | Semántica a documentar en LB-001C | — |

### C-009 Transporte SSE (E-06)

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-009a | Endpoint/método/query | `GET /api/v1/realtime/stream?grupoId={UUID}` (obligatorio) | `GET ${apiUrl}/realtime/stream?grupoId=${encodeURIComponent(id)}` con `id = Course.id = idGrupo` | MATCH | `RealtimeEventsController` l.69-71; `fetch-sse-realtime-transport.ts` l.128-131 | — | — |
| C-009b | Accept / content-type | `produces = text/event-stream` | `Accept: text/event-stream`; valida `content-type` con `startsWith('text/event-stream')` | MATCH | `RealtimeEventsController` l.69; `fetch-sse-realtime-transport.ts` l.134,143-147 | — | — |
| C-009c | Campos SSE | `id = eventId`, `event = type`, `data = RealtimeEventResponse` (JSON) | Lee `event` y `data`; descarta si `event ≠ data.type`; ignora `id` | MATCH | `RealtimeEventsController` l.140-146; `fetch-sse-realtime-transport.ts` l.225-255 | — | — |
| C-009d | Heartbeat | Comentario SSE `:heartbeat` cada 25 s (no es evento de negocio) | `@microsoft/fetch-event-source` 2.0.1 **sí** invoca `onmessage` al llegar la línea en blanco tras el comentario, con `{data:'', event:'', id:''}` (`parse.js` l.66-69); el consumer lo descarta con `if (!msg.data) return` | MATCH | `RealtimeEventsController` l.41,74-81; `FE:node_modules/@microsoft/fetch-event-source/lib/esm/parse.js`; `fetch-sse-realtime-transport.ts` l.229; spec l.204-217 | Ninguno (comportamiento correcto). **El comentario del código dice que nunca llega a `onmessage`: inexacto** (ver TC-01) | — |
| C-009e | Fallos al abrir | 401 (JSON) sin/ con token inválido; 403 `ForbiddenException` **antes** de crear el `Flux` (respuesta JSON normal) si no es titular docente | 401 ⇒ `refreshAccessToken()` y reintenta, si falla ⇒ `UNAUTHORIZED` terminal; 403 ⇒ `ERROR` terminal; otro ⇒ reconexión con backoff 1-30 s + jitter | MATCH | `RealtimeEventsController` l.70-72; `LocalSseRealtimeStreamGateway` l.45-47; `fetch-sse-realtime-transport.ts` l.141-203 | — | — |
| C-009f | Entrega y recuperación | `directBestEffort`: efímero, sin replay ni durabilidad, una JVM ([TD-003](../../baseline/TECHNICAL_DEBT.md#td-003)) | Tras `RECONNECTING → CONNECTED` recarga por HTTP; eventos perdidos no se reconstruyen desde SSE | MATCH | `ReactorRealtimeAdapter` l.26-39; `attendance-realtime-sync.service.ts` l.55-62 | — | — |
| C-009g | Feedback de estado al usuario | — | `UNAUTHORIZED`/`ERROR`/`DISCONNECTED` no se muestran: ningún componente (salvo el sync interno) se suscribe a `connectionState$` | MISSING_IN_CONSUMER | `attendance-realtime-sync.service.ts`; grep `connectionState` en `FE:A` | Medio: el docente no sabe que dejó de recibir actualizaciones | — |

### C-010 Envelope del evento realtime

| ID | Campo | Provider (Java → JSON) | Consumer (TS) | Nullability | Status | Evidence |
|---|---|---|---|---|---|---|
| C-010a | `eventId` | `UUID` → string (obligatorio, `requireNonNull`) | `string` | no nulo | MATCH | `RealtimeEvent.java`; `RealtimeEventResponse.java`; `realtime-event.model.ts` |
| C-010b | `type` | `String` (obligatorio) | `string` | no nulo | MATCH | idem |
| C-010c | `occurredAt` | `Instant` (obligatorio). El JSON de `Instant` **no está asertado** por ningún test del provider | `string` (`typeof === 'string'`; si llegara numérico, el evento se **descarta** con `console.warn`) | no nulo | BLOCKED_BY_MISSING_EVIDENCE (B-03) | `RealtimeEventsControllerTest` (objetos Java, no JSON); `isValidRealtimeEvent` |
| C-010d | `correlationId` | `String` nullable (se completa con el contexto del publicador) | `string \| null` | nullable | MATCH | `ReactorRealtimeAdapter` l.74; `realtime-event.model.ts` |
| C-010e | `payload` | `Map<String,Object>` (`Map.copyOf`, nunca `null`) | `TPayload`; exige la propiedad `payload` | no nulo | MATCH | `RealtimeEvent.java` |
| C-010f | `traceId`, `spanId` | **No** se serializan (solo internos) | No los espera | — | MATCH | `RealtimeEventResponse.java` |
| C-010g | `version` | No existe | No existe | — | NOT_APPLICABLE | [REALTIME_EVENT_STANDARD](../../contracts/REALTIME_EVENT_STANDARD.md) |

### C-011 Payload `ASISTENCIAS_SESION_ACTUALIZADAS`

| ID | Campo | Provider | Consumer | Status | Evidence |
|---|---|---|---|---|---|
| C-011a | `type` | `"ASISTENCIAS_SESION_ACTUALIZADAS"` | `REALTIME_EVENT_TYPE.ASISTENCIAS_SESION_ACTUALIZADAS` (igual) | MATCH | `RegistrarAsistenciasSesionUseCaseImpl` l.37,88-92; `realtime-event.model.ts` |
| C-011b | `payload.grupo` | `UUID.toString()` (minúsculas) | `string`; filtra `payload.grupo === selectedCourseId` | MATCH | use case l.88-92; `attendance-realtime-sync.service.ts` l.42-52 |
| C-011c | `payload.sesion` | `UUID.toString()` | `string`; filtra `payload.sesion === selectedSessionId` | MATCH | idem |
| C-011d | `payload.totalRegistros` | `Integer` (`registros.size()`) → número | `number`; **no usado** | MISSING_IN_CONSUMER | use case l.92; `AttendanceSessionUpdatedRealtimePayload` |
| C-011e | Publicación | Solo tras persistencia exitosa; sin evento en error; sin atomicidad SQL/SSE ([TD-011](../../baseline/TECHNICAL_DEBT.md#td-011)) | Trata el evento como **trigger** y relee por HTTP (HTTP/DB = source of truth) | MATCH | use case l.62-69; `attendance-control.component.ts` l.211-223 |
| C-011f | Alcance del canal | Filtra en gateway por `payload.grupo`; los eventos sin `grupo` (p. ej. `/realtime/emit`) no se entregan por este canal | Filtra otra vez por grupo y sesión | MATCH | `LocalSseRealtimeStreamGateway` l.49-52 |

### C-012 Ausencia de registro de asistencia

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-012a | Un estudiante del grupo **sin fila** en E-04 | La query es `INNER JOIN` desde `uv_detalle_asistencia`: **solo devuelve asistencias persistidas**; **no** devuelve una fila por estudiante. Ninguna fuente del provider declara qué significa la ausencia ni define un estado «sin registrar» (AN = «asistencia normal», solo en comentario de dominio) | `attendance?.estado ?? 'AN'` ⇒ ausencia = `AN`; `markAll…` y el guardado envían **todos** los registros; el spec fija ese comportamiento como expectativa del consumer | DECISION_REQUIRED | `AsistenciaRepositorySqlServerAdapter` l.93-108; `attendance.mapper.ts` l.76-79; `attendance.mapper.spec.ts` l.60-66; `attendance-control.component.ts` l.549-556; `RegistroAsistenciaSesionDomain.java` l.13-17 | **Alto**: sesión sin registros ⇒ la UI muestra a todos como `AN` y el primer «Guardar» persiste `AN` para todos, incluso los que el docente nunca marcó. La UI no distingue «sin registrar» de «AN registrado» | DR-002 |
| C-012b | Acción masiva «marcar ausentes» | `SJC` = «sin justa causa» | `bulkSetStatus('SJC')` | MATCH | `attendance-control.component.ts` l.526-529 | — | — |

### C-013 Estado de la sesión

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-013a | ¿El backend expone estado de sesión? | **No**: `SesionConsultadaDTO` y `uv_sesion` (10 columnas seleccionadas) no incluyen estado. Sí existen operaciones de ciclo de vida (`POST /sesiones/cierres`, `PATCH /docente/sesiones/{id}/cancelar`) cuyo efecto no se refleja en la lectura | `ClassSession.status: 'PROGRAMADA'|'EN_CURSO'|'CONCLUIDA'` | MISSING_IN_PROVIDER | `SesionConsultadaDTO.java`; `SesionRepositorySqlServerAdapter` l.104-117; `SesionController` l.130-137; `attendance.model.ts` | Alto | DR-001 |
| C-013b | ¿Puede el frontend conocer si está concluida? | — | **No**: `SessionService` fuerza `'PROGRAMADA'` (**FIELD_SYNTHESIZED_BY_FRONTEND**); `isSessionConcluded()` (`status==='CONCLUIDA'`) es siempre falso con el provider real; ningún spec cubre `status` | DECISION_REQUIRED | `session.service.ts` l.154; `attendance-control.component.ts` l.243,505,522,527,547 | Alto: las protecciones de UI (`setStatus`, `markAll*`, `saveAttendance`) nunca actúan; la sesión por defecto es `sessions[0]` (la más antigua por `fechaHoraInicio ASC`), no la «actual» | DR-001 |
| C-013c | ¿El backend protege igualmente guardar en sesión concluida? | El use case solo valida existencia + titularidad; el SP no consta | — | BLOCKED_BY_MISSING_EVIDENCE | `RegistrarAsistenciasSesionUseCaseImpl` l.62-69 | Alto | B-01 |

### C-014 Fechas y horas

| ID | Capacidad | Provider contract | Consumer expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-014a | `fechaHoraInicio`/`fechaHoraFin` | `LocalDateTime` ⇒ `"2026-09-14T08:00:00"` (ISO sin offset ni zona; **asertado** por test) | `string` | MATCH | `SesionControllerContractTest` l.91-92 (archivo modificado respecto a HEAD, ver §1.1); `sesion-consultada-api-dto.model.ts` | — | — |
| C-014b | `ClassSession.date` | — | Conceptualmente `YYYY-MM-DD` (comentario del modelo, mocks); recibe el **datetime completo** | MISMATCH | `session.service.ts` l.151; `attendance.model.ts` (`date: string; // ISO format (YYYY-MM-DD)`); mocks `'2026-08-25'` | Medio: etiqueta `Sesión #n (2026-09-14T08:00:00)`; comparaciones por fecha (p. ej. `s.date === data.date` al crear sesión) no coinciden | DR-003 |
| C-014c | `ClassSession.startTime` / `endTime` | — | Conceptualmente `HH:mm`; reciben el datetime completo | MISMATCH | `session.service.ts` l.152-153; mocks `'08:00'` | Medio | DR-003 |
| C-014d | Política temporal | `LocalDateTime` (sin zona) en sesiones vs `Instant` (UTC) en eventos; sin decisión UTC end-to-end ([TD-005](../../baseline/TECHNICAL_DEBT.md#td-005), ME-005) | Trata cadenas sin zona; **no** se resuelve aquí | DECISION_REQUIRED | `RealtimeEvent.java`; `SesionConsultadaDTO.java`; TD-005 | Medio | DR-003 |

### C-015 Mocks y fallbacks

Ver §7 (inventario). Estado de la fila: **NOT_APPLICABLE** como contrato entre sistemas (es riesgo de evidencia); **LB-001B contract evidence must use USE_MOCKS=false.**

### C-016 Listado / filtro / paginación

Ver §8. Estado: **NOT_APPLICABLE** (FEATURE_NOT_YET_REQUIRED, evidenciado) + DR-010 para el freeze.

## 5. Tipos y campos (wrappers y DTOs)

Serialización Java → JSON: `UUID` → string; `Integer`/`int` → number; `boolean`/`Boolean` → boolean; `LocalDateTime` → `"yyyy-MM-ddTHH:mm:ss"` (asertado en `SesionControllerContractTest` l.91); `LocalTime` → cadena (formato no asertado, B-03); `Instant` → cadena ISO-8601 en UTC (no asertado en SSE, B-03); `OffsetDateTime` → cadena ISO-8601 con offset. La nullability de los records/DTO Java **no está declarada** (sin anotaciones); la de DB no consta en este repo (B-02). «Obligatorio TS» = campo no opcional en la interface.

### 5.1 Wrappers

| Wrapper | Campo | Java | JSON | TS | Nullability provider | Obligatorio TS | Semántica | Status |
|---|---|---|---|---|---|---|---|---|
| `ApiListResponse` | `exitoso` | `boolean` | boolean | `boolean` | no nulo | sí | siempre `true` en éxito | MATCH |
| `ApiListResponse` | `datos` | `List<T>` (`List.copyOf`, `requireNonNull`) | array | `T[]` | no nulo (vacío = `[]`) | sí | elementos de la lista | MATCH |
| `ApiListResponse` | `total` | `int` | number | `number` | no nulo | sí | `datos.size()` (no es total paginado; no hay paginación) | MATCH |
| `ApiMessageResponse` | `exitoso` | `boolean` | boolean | `boolean` | no nulo | sí | `true` en éxito | MATCH |
| `ApiMessageResponse` | `mensaje` | `String` | string | `string` | no declarado | sí | texto fijo del backend (p. ej. «Asistencias de sesion registradas correctamente.») | MATCH |
| `ApiDataResponse` | `exitoso` | `boolean` | boolean | `boolean` | no nulo | sí | — | MATCH |
| `ApiDataResponse` | `datos` | `T` (puede ser `null`, p. ej. `Void`) | any/null | `T` | nullable | sí | **No** usado por ningún endpoint del Golden Path; el consumer lo tiene tipado (`api-data-response.model.ts`) | MATCH (no ejercitado en el Golden Path) |
| `ApiErrorResponse` | `timestamp` | `OffsetDateTime` | string | `string` | no nulo | sí | instante del error | MATCH |
| `ApiErrorResponse` | `status` | `int` | number | `number` | no nulo | sí | código HTTP | MATCH |
| `ApiErrorResponse` | `error` | `String` | string | `string` | no nulo | sí | *reason phrase* HTTP en inglés (p. ej. «Forbidden») | MATCH |
| `ApiErrorResponse` | `code` | `String` | string | `string` | no nulo | sí | código de error estable (catálogo) | MATCH |
| `ApiErrorResponse` | `message` | `String` | string | `string` | no nulo | sí | mensaje para el usuario (catálogo) | MATCH |
| `ApiErrorResponse` | `path` | `String` | string | `string` | no nulo | sí | URI sanitizada | MATCH |
| `ApiErrorResponse` | `correlationId` | `String` | string \| null | `string \| null` | nullable | sí | contexto de correlación de la petición | MATCH |
| `ApiErrorResponse` | `details` | `List<ApiFieldError>` (`NON_EMPTY`) | array \| ausente | `ApiFieldError[]?` | ausente si vacío | no | errores por campo | MATCH |
| `ApiFieldError` | `field`, `code`, `message` | `String`×3 | string×3 | `string`×3 | no declarado | sí | — | MATCH |

### 5.2 DTOs del Golden Path

Resumen por DTO; el detalle de mapeo y diferencias está en §4.

| DTO | Campos (Java → TS) | Diferencias de tipo/nullability | Campos consumidos | Campos no consumidos |
|---|---|---|---|---|
| `HorarioDocenteDTO` → `HorarioDocenteApiDto` | `id, idDocente, idGrupo`: UUID→string · `codigoMateria, nombreMateria, seccion, dia, aula`: String→string · `horaInicio, horaFin`: LocalTime→string · `totalEstudiantes`: Integer→number | TS todo no nulo; Java/DB sin declarar (B-02); formato `LocalTime` (B-03) | todos menos `id` | `id` |
| `SesionConsultadaDTO` → `SesionConsultadaApiDto` | `sesion, grupo`: UUID→string · `nombre, codigo, codigoGrupo, nombreGrupo`: String→string · `numero, numeroSemana`: Integer→number · `fechaHoraInicio/Fin`: LocalDateTime→string | ídem (B-02) | `sesion, grupo, numero, nombre, fechaHoraInicio, fechaHoraFin` | `codigo, numeroSemana, codigoGrupo, nombreGrupo` |
| `EstudianteGrupoDTO` → `EstudianteGrupoApiDto` | `id, idEstudiante`: UUID→string · `documento, nombreCompleto, correo, codigoEstado, nombreEstado`: String→string | ídem (B-02); `documento` viene de `CAST(numeroIdentificacion AS VARCHAR(20))` (TD-006) | `idEstudiante, documento, nombreCompleto` | `id, correo, codigoEstado, nombreEstado` |
| `AsistenciaConsultadaDTO` → `AsistenciaConsultadaApiDto` | `asistencia, estudiante, grupo, sesion`: UUID→string · `presente`: Boolean→`boolean\|null` · `estado`: String→`'AN'\|'SJC'\|'EX'` · `observacion`: String→`string\|null` | **`estado`: TS más estricto que Java (C-004c)**; `presente` TS más amplio; `observacion` siempre `''` | `estudiante, estado` | `asistencia, grupo, sesion, presente, observacion` |
| `RegistrarAsistenciasSesionRequest` (ambos) | `sesionId`: UUID/string · `registros[]{estudianteId: UUID/string, estado: String/'AN'\|'SJC'\|'EX'}` | Java `String` valida `AN\|SJC\|EX`; TS lo restringe en compilación (equivalente) | todos | — |
| `RealtimeEventResponse` → `RealtimeEvent` | `eventId`: UUID→string · `type`: String→string · `occurredAt`: Instant→string · `correlationId`: String→`string\|null` · `payload`: Map→`TPayload` | `occurredAt` (B-03) | todos (`correlationId` sin uso) | — |
| Payload `ASISTENCIAS_SESION_ACTUALIZADAS` | `grupo`, `sesion`: String (UUID) · `totalRegistros`: Integer | — | `grupo`, `sesion` | `totalRegistros` |

## 6. Códigos y enums

| Dominio | Provider | Consumer | Status |
|---|---|---|---|
| Estado de asistencia (escritura) | `AN`, `SJC`, `EX` (`ESTADOS_VALIDOS`); normaliza `trim`+mayúsculas | `'AN' \| 'SJC' \| 'EX'` | MATCH |
| Estado de asistencia (lectura) | `String` de `codigoRazonCausa`, sin filtro/mapeo | `'AN' \| 'SJC' \| 'EX'` o lanza | DECISION_REQUIRED (DR-006) |
| Estado de sesión | no expuesto | `PROGRAMADA \| EN_CURSO \| CONCLUIDA` | MISSING_IN_PROVIDER (DR-001) |
| Tipo de sesión | no expuesto en lectura (`tipo` se acepta al crear) | `REGULAR \| EXTRAORDINARIA \| REPOSICION` | MISSING_IN_PROVIDER (DR-004) |
| `codigoEstado` de matrícula | `String` (DB) | no usado | MISSING_IN_CONSUMER (DR-007) |
| Tipo de evento | `ASISTENCIAS_SESION_ACTUALIZADAS` (Golden Path); `ASISTENCIA_REGISTRADA` (registro individual, no productivo: `FeatureUnavailableException`); `{topic}.{action}` (`/realtime/emit`, solo ADMIN) | Solo consume `ASISTENCIAS_SESION_ACTUALIZADAS` (filtra por `type` exacto) | MATCH |
| Estados de conexión realtime | — (concepto del consumer) | `DISCONNECTED, CONNECTING, CONNECTED, RECONNECTING, UNAUTHORIZED, ERROR` | NOT_APPLICABLE |

## 7. Inventario de mocks y fallbacks (C-015)

**LB-001B contract evidence must use USE_MOCKS=false.** No se aceptará evidencia E2E con mocks activados. No se eliminó ni modificó ningún mock.

### 7.1 Interruptor de mocks

`environment.useMocks` (`FE:src/environments/environment.ts`) lee **primero** `localStorage['USE_MOCKS']` (persiste entre sesiones del navegador) y, si no existe, `window.env.USE_MOCKS` (inyectado por `docker-entrypoint.d/40-env-js.sh`); por defecto `false`. Un `USE_MOCKS=true` olvidado en `localStorage` hace que la pantalla funcione sin backend.

### 7.2 Servicios del Golden Path

| Servicio / símbolo | Rama mock | Clasificación | Consecuencia con `USE_MOCKS=true` |
|---|---|---|---|
| `CourseService.getCurrentTeacherCourses` | `useMocks` ⇒ `MOCK_COURSES` (ids `crs-1`, …) | **MOCKABLE** | Lista de grupos ficticia |
| `SessionService.getSessionsByGroup` | `useMocks` ⇒ `initialSessions` (con `status` `CONCLUIDA/PROGRAMADA`, `date`, `room`, `tipo`) | **MOCKABLE** | Las sesiones simuladas sí tienen `status`, `HH:mm`, `room`, `tipo`: **el mock oculta los mismatches C-002/C-013/C-014** |
| `GroupService.getStudentsByGroup` | `useMocks` ⇒ `MOCK_ESTUDIANTES_DIRECTORIO` | **MOCKABLE** | Estudiantes ficticios |
| `AttendanceService.getAttendancesByGroup` / `saveBatchAttendance` | **sin rama mock** (siempre HTTP) | **REAL** | Con mocks activos consulta/guarda contra el backend real usando ids ficticios |
| `FetchSseRealtimeTransport.runLoop` | `useMocks` ⇒ `DISCONNECTED` y termina | **MOCKABLE** | Sin stream |
| `AuthService` (`isMockMode`, `loginAsMockUser`, tokens `mock-jwt-token-*`) | sí | **MOCKABLE** | Sin Bearer real; `authInterceptor` limpia tokens `mock-` si no está en modo mock |

**Veredicto del Golden Path: MIXED.** Con mocks activos la pantalla parece funcional, pero mezcla datos simulados (grupos/sesiones/estudiantes) con llamadas reales de asistencia; sin mocks depende por completo del backend.

### 7.3 Fallbacks que pueden ocultar errores o inventar semántica

Clasificación: **LEGÍTIMO** (fallback de UI aceptable) · **OCULTA** (oculta un fallo de contrato/red) · **INVENTA** (fabrica semántica que el provider no da).

| ID | Ubicación | Comportamiento | Clase | Relación |
|---|---|---|---|---|
| F-01 | `course.service.ts` l.83 | `docenteName: 'Docente UCO'` | INVENTA | C-001g / DR-004 |
| F-02 | `course.service.ts` l.68-72,85 | `colorCategory` cíclico | LEGÍTIMO | C-001h |
| F-03 | `course.service.ts` l.20-25 | `idTransaccion: 'tx-courses-teacher'` (legacy `ApiResponse`) | INVENTA (sin efecto funcional) | C-006c |
| F-04 | `session.service.ts` l.154 | `status: 'PROGRAMADA'` | INVENTA | C-002h, C-013 / DR-001 |
| F-05 | `session.service.ts` l.150-153 | `topic ← nombre`; `date/startTime/endTime ← fechaHora*` completo | INVENTA / mapeo incorrecto | C-002e, C-014 / DR-003, DR-004 |
| F-06 | `attendance.mapper.ts` l.78 | `attendance?.estado ?? 'AN'` | INVENTA | C-012 / DR-002 |
| F-07 | `attendance.mapper.ts` l.80-86 | estado desconocido ⇒ `throw Error` ⇒ el error no es `HttpErrorResponse` ⇒ `getApiErrorMessage` devuelve el mensaje genérico | LEGÍTIMO (falla cerrado) pero **OCULTA la causa** al usuario | C-004c / DR-006 |
| F-08 | `attendance-control.component.ts` l.460-462 | error al cargar sesiones ⇒ `sessions.set([])` **sin aviso** | OCULTA (un 403/500 se ve como «sin sesiones») | C-007b |
| F-09 | `attendance-control.component.ts` l.547 | `saveAttendance()` retorna en silencio si no hay registros/sesión | LEGÍTIMO (UX silenciosa) | C-005g |
| F-10 | `attendance-control.component.ts` l.205-223 | recarga por HTTP ante evento o reconexión | LEGÍTIMO | C-011e |
| F-11 | `session.service.ts` (`cancelarSesion`) | `catchError → of({exitoso:false…})` | OCULTA (adyacente, fuera del Golden Path) | — |
| F-12 | `session.service.ts` (`closeSession`, `updateSession`) | `idTransaccion \|\| 'tx-…'`, `mensajeUsuario \|\| '…'` | INVENTA (adyacente) | C-006c |
| F-13 | `auth.interceptor.ts` l.40-42 | sin sesión ⇒ envía la petición sin `Authorization` (el backend responde 401) | LEGÍTIMO | C-007 |
| F-14 | `fetch-sse-realtime-transport.ts` l.107-110,118-121 | `useMocks` o sin token ⇒ `DISCONNECTED` sin error visible | OCULTA (sin feedback) | C-009g |
| F-15 | Identificadores/credenciales embebidos | Ids ficticios (`crs-1`, `ses-101`, …) en mocks. **SECURITY_FINDING**: `FE:src/app/features/attendance/attendance-control/attendance-control.component.ts` embebe una **contraseña por defecto** en el flujo de matrícula (tipo: credencial por defecto en código cliente; **valor no reproducido**). Adyacente al Golden Path | — | TD-032 |

## 8. Listado, filtro y paginación AS-IS (C-016)

| Lista | Endpoint | Filtro (provider) | Orden (provider) | Paginación | `total` | Límite | Búsqueda | Consumer |
|---|---|---|---|---|---|---|---|---|
| Grupos del docente | E-01 | implícito: docente autenticado | `ORDER BY dia, horaInicio, nombreMateria` (`dia` es texto: orden alfabético, no de semana) | no | nº de filas (bloques horarios) | no | no | agrupa por `idGrupo`; conserva orden de aparición; auto-selecciona el primero |
| Sesiones | E-02 | `grupoId` (path) | `ORDER BY fechaHoraInicio, numero, id` | no | `datos.size()` | no | no | no reordena; por defecto usa `sessions[0]` (ver C-013) |
| Estudiantes | E-03 | `grupoId` (path); **sin** filtro por `codigoEstado` | `ORDER BY nombreCompleto, id` | no | `datos.size()` | no | no | no reordena |
| Asistencias | E-04 | `grupoId` (path) + `sesionId` (query, opcional) | **sin `ORDER BY`** | no | `datos.size()` | no | no | indexa por estudiante; el orden no importa |

Evidencia de que es **FEATURE_NOT_YET_REQUIRED** y no `MISSING_IN_PROVIDER`: el consumer no envía `page/size/sort/q` en ninguna de las cuatro llamadas ni espera metadatos de página (`total` se recalcula localmente en E-01/E-02); `ERR_PAGE_INVALIDA`/`ERR_SIZE_INVALIDO` existen en `CommonErrorCode` pero ningún endpoint del Golden Path acepta `page`/`size` (`AsistenciaQueryController` solo `sesionId`). Estado: NOT_APPLICABLE; **DR-010** fija qué se congela en LB-001C.

## 9. Tests del consumer como evidencia (contradicciones)

Los specs expresan la **expectativa del consumer**; no sustituyen el contrato del provider.

| ID | Spec / código | Observación | Clasificación |
|---|---|---|---|
| TC-01 | `fetch-sse-realtime-transport.ts` l.226-229 (comentario) vs `fetch-sse-realtime-transport.spec.ts` l.204-217 y `parse.js` l.66-69 | El comentario afirma que los `:heartbeat` nunca llegan a `onmessage`; la librería 2.0.1 **sí** los entrega como mensaje vacío y el spec lo simula así. El código es correcto; el comentario es inexacto | Contradicción interna del consumer (sin impacto funcional) |
| TC-02 | `attendance.mapper.spec.ts` l.60-66 | «usa AN solo cuando no existe asistencia» fija la semántica de C-012 como expectativa del consumer; **no** proviene de ningún contrato del provider | Expectativa no respaldada (DR-002) |
| TC-03 | `attendance.mapper.spec.ts` l.68-78 | Exige lanzar ante un estado fuera de `AN/SJC/EX` («LEGACY»); consistente con TS pero el provider no garantiza ese dominio en lectura | Expectativa más estricta que el provider (DR-006) |
| TC-04 | `session.service.spec.ts` l.24-54 | Solo aserta `id`; usa `fechaHoraInicio: '2026-09-16T08:00:00'` (coherente con el provider). **Ningún test** cubre `status`, `date`, `startTime`, `topic` | Hueco de cobertura (no contradicción) |
| TC-05 | `course.service.spec.ts` l.45,58,66-68 | Fixtures con `horaInicio: '08:00:00'`; aserta agrupación y `schedule` | Expectativa del formato `HH:mm:ss` (B-03) |
| TC-06 | `attendance.service.spec.ts` l.29-44 | Aserta el body canónico y la ausencia de campos extra; coherente con `FAIL_ON_UNKNOWN_PROPERTIES` | Consistente |
| TC-07 | `RbacSecurityFilterChainTest` l.199-215 (provider) vs `app.routes.ts` l.59-66 (consumer) | El provider prueba `POST /asistencias/lote` como solo `DOCENTE`; la ruta del consumer admite además `DECANO/ADMINISTRADOR/ADMIN` | Contradicción provider↔consumer (DR-008) |
| TC-08 | Ningún spec de interceptores (`auth.interceptor`, `error.interceptor`) | No hay prueba del orden de interceptores ni del refresco tras 401 | Hueco de cobertura (C-007d) |

## 10. Decisiones requeridas

Salvo indicación en contrario, `status = PENDING`. Las recomendaciones técnicas **no son aprobaciones**. Ninguna se implementa en esta fase.

**Nota de gobernanza (06-cierre, LB-001B.1, 2026-09-22):** este CONTRACT_MATRIX estaba formalmente cerrado (LB-001B ANALYSIS COMPLETE). 06-cierre reabre este documento únicamente para las filas DR-001 y DR-004 (tabla de abajo y sus secciones de detalle §DR-001/§DR-004), con autoridad de cierre expresa en el work item [LB-001B.1](../LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md), y registra su resolución conforme a la decisión humana pegada verbatim en esa sesión (2026-09-22, secciones 0 y 12-16 de la tarea autorizada, Opción B para ambos DR). Ninguna otra fila ni sección de este documento fue tocada en esta reapertura.

| ID | Tema | Filas | Aprobador sugerido | Status |
|---|---|---|---|---|
| DR-001 | Estado de sesión | C-002h, C-013a/b, C-005j | Responsable de contrato backend + producto | **RESOLVED — Opción B** (decisión humana 2026-09-22; ver [LB-001B.1 CLOSURE](../LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md)) |
| DR-002 | Semántica de «sin registro de asistencia» | C-012a | Producto/negocio + backend | **RESOLVED / IMPLEMENTED** (frontend: ausencia ⇒ `null`, `Sin registrar`; ver LB-001B.1C) |
| DR-003 | Representación temporal de sesión (fecha/hora/zona) | C-002i, C-014b/c/d | Backend + DB + frontend (TD-005) | **MAPPING RESOLVED** (dependencia temporal: la representación HTTP final se congela en TD-005/LB-001C; TD-005 `CLOSED_FOR_GOLDEN_PATH`) |
| DR-004 | Campos de presentación sin provider (`topic`, `room`, `tipo`, `docenteName`) | C-001g, C-002e/f/g | Backend + frontend | **RESOLVED — Opción B** (decisión humana 2026-09-22; ver [LB-001B.1 CLOSURE](../LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md)) |
| DR-005 | Causa/observación de excusa no persisten | C-005f | Producto + backend + DB | **RESOLVED / IMPLEMENTED** (UI no promete persistencia fuera de contrato; ver LB-001B.1C) |
| DR-006 | Dominio de `estado` en lectura | C-004c | Backend + DB | **RESOLVED — Opción A, fail-closed** (2026-09-23, LB-001B.4; riesgo histórico `CPI`/`CPVP` en TD-045) |
| DR-007 | Elegibilidad de estudiantes por `codigoEstado` | C-003e/g | Producto + backend | **RESOLVED / IMPLEMENTED** (frontend filtra activos; ver LB-001B.1C validation) |
| DR-008 | Roles de la ruta `/app/asistencia` vs RBAC del backend | C-007b | Backend (seguridad) + frontend | **RESOLVED / IMPLEMENTED** (frontend RBAC/Golden Path tests verdes; ver LB-001B.1C) |
| DR-009 | Códigos de error de autorización/titularidad (TD-030) | C-006g | Backend + DB (LB-001C) | **RESOLVED** (2026-09-23, LB-001B.4; TD-030 `RESOLVED BY FROZEN DB BASELINE`, `SEC_001/SEC_002/EST_004 -> 403/FORBIDDEN`) |
| DR-010 | Alcance de listado/orden/paginación a congelar | C-016 | Backend + frontend | **RESOLVED — Opción A** (2026-09-24, LB-001B.4A): listas completas AS-IS, sin `page/size/sort/q`; asistencias sin orden público garantizado; paginación = future feature |

### DR-001 — Estado de sesión

- **Pregunta exacta:** ¿el contrato de `GET /api/v1/sesiones/grupo/{grupoId}` debe exponer el estado de la sesión (programada/en curso/concluida/cancelada) para que el frontend habilite o bloquee el registro de asistencia?
- **Provider evidence:** `SesionConsultadaDTO` no tiene estado; `uv_sesion` se lee con 10 columnas sin estado; existen `POST /sesiones/cierres` y `PATCH /docente/sesiones/{id}/cancelar`; el use case de lote no valida estado (`SesionRepositorySqlServerAdapter` l.104-117; `RegistrarAsistenciasSesionUseCaseImpl` l.62-69).
- **Consumer evidence:** `status` forzado a `'PROGRAMADA'` (`session.service.ts` l.154); `isSessionConcluded()` nunca verdadero (`attendance-control.component.ts` l.243).
- **Opción A:** el provider agrega un campo de estado al DTO (con dominio definido) y el frontend deja de sintetizarlo.
- **Opción B:** el estado no forma parte del contrato de la pantalla; el frontend elimina `status` y las protecciones de UI, y el backend/SP es la única autoridad (rechazo con error de negocio).
- **Impacto A:** cambio de contrato aditivo en HTTP/OpenAPI; requiere que DB/vista exponga el estado (verificar contrato DB); frontend ajusta mapper.
- **Impacto B:** el usuario solo descubre la restricción al guardar; requiere confirmar que el SP realmente rechaza (B-01).
- **Recomendación técnica:** A (el consumer necesita el dato para una regla de UX y hoy lo inventa); condicionada a confirmar con el equipo DB la fuente del estado y el rechazo defensivo en el SP.
- **Status:** **RESOLVED — Opción B** (traslado formal por 06-cierre, 2026-09-22). Decisión humana pegada verbatim en la sesión de [LB-001B.1](../LB-001B.1-db-source-of-truth-cleanup/PLAN.md) (secciones 0 y 12-16 de la tarea autorizada): el estado de sesión **no** forma parte del contrato de la pantalla; el frontend retira `status`/`isSessionConcluded()` sin sintetizar una regla sustituta, y el backend/SP sigue siendo la única autoridad para rechazar operaciones sobre una sesión ya cerrada (vía error de negocio existente, no vía un `status` de UI). Implementado en el backend por [LB-001B.1](../LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md) (retiro de campos no persistidos del contrato de creación/actualización de `Sesion`; `SesionConsultadaDTO` sin cambios, ya no exponía `status`). El lado frontend (retiro de `status`/`isSessionConcluded()` en `ClassSession`/`SessionService`/UI) se ejecuta en el work item hermano del repo frontend `LB-001B.1B-db-source-of-truth-cleanup`, fuera de la autoridad de escritura de esta sesión backend.

### DR-002 — Semántica de «sin registro de asistencia»

- **Pregunta exacta:** cuando un estudiante del grupo no aparece en `GET …/asistencias?sesionId=…`, ¿qué significa (sin registrar, presente, otro) y qué debe mostrar/enviar el consumer?
- **Provider evidence:** la query solo devuelve filas persistidas (`INNER JOIN`); no existe estado «sin registrar»; AN = «asistencia normal» solo en comentario de dominio (`AsistenciaRepositorySqlServerAdapter` l.93-108; `RegistroAsistenciaSesionDomain` l.13-17).
- **Consumer evidence:** ausencia ⇒ `'AN'` y el guardado envía todos (`attendance.mapper.ts` l.78; `attendance-control.component.ts` l.549-556; `attendance.mapper.spec.ts` l.60-66).
- **Opción A:** el provider expone la ausencia de forma explícita (p. ej. una fila por estudiante con estado «sin registrar»/`null`, o un campo/estado adicional) y el consumer muestra «sin registrar» y solo envía lo marcado.
- **Opción B:** se acuerda que ausencia ≡ `AN` (asistencia normal por defecto) y se documenta en el contrato como regla de negocio explícita.
- **Impacto A:** cambia el dominio de `estado` (extiende AN/SJC/EX), afecta SP/vista/OpenAPI y el registro batch (¿permite «no registrar»?).
- **Impacto B:** sin cambio de provider; el docente que guarda persiste `AN` para quien no marcó; requiere aval de negocio y test de contrato que lo fije.
- **Recomendación técnica:** decidir con negocio; sin una regla explícita, A es más segura (no persiste datos no capturados por el docente). B solo si negocio lo aprueba por escrito.
- **Status:** **RESOLVED / IMPLEMENTED** (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`): ausencia de fila de asistencia se mantiene como `null` y se presenta como `Sin registrar`; `AN` solo se envía cuando usuario/provider lo establece explícitamente. `DEFAULT_AN_BUSINESS_FALLBACK_COUNT = 0`.

### DR-003 — Representación temporal de sesión

- **Pregunta exacta:** ¿quién deriva `date` (YYYY-MM-DD) y `startTime`/`endTime` (HH:mm) a partir de `fechaHoraInicio/Fin` y con qué zona horaria?
- **Provider evidence:** `LocalDateTime` sin zona, `"2026-09-14T08:00:00"` (`SesionControllerContractTest` l.91); eventos `Instant`; sin UTC end-to-end (TD-005, ME-005).
- **Consumer evidence:** asigna el datetime completo a `date/startTime/endTime` (`session.service.ts` l.151-153); la etiqueta muestra el datetime completo (`attendance-control.component.ts` l.231).
- **Opción A:** el consumer deriva fecha/hora con un parseo definido del valor local sin zona (contrato: hora local institucional).
- **Opción B:** el provider expone campos separados o instantes con offset/UTC y el consumer los formatea.
- **Impacto A:** sin cambio de provider; el contrato debe declarar que es hora local sin zona; riesgo de desfases si hay usuarios en otras zonas.
- **Impacto B:** cambio de contrato y posible ajuste DB (TD-005); resuelve zona explícitamente.
- **Recomendación técnica:** cerrar primero la política temporal (TD-005) y luego elegir; A es viable a corto plazo si se declara «hora local institucional».
- **Status:** **MAPPING RESOLVED; timezone TD-005 OPEN**. Frontend deriva `date/startTime/endTime` de `LocalDateTime` sin conversión de zona y prueba el body create/update exacto; la política temporal DB/API permanece abierta en [TD-005](../../baseline/TECHNICAL_DEBT.md#td-005).

### DR-004 — Campos de presentación sin provider

- **Pregunta exacta:** ¿`topic`, `room`, `tipo` (sesión) y `docenteName` (grupo) forman parte del contrato de lectura del Golden Path?
- **Provider evidence:** `SesionConsultadaDTO` y `HorarioDocenteDTO` no los incluyen; `CrearSesionRequest` sí acepta `tema`, `descripcion`, `aula`, `tipo` (`CrearSesionRequest.java` l.8-14).
- **Consumer evidence:** `topic ← nombre`; `room`/`tipo` ausentes; `docenteName = 'Docente UCO'` (`session.service.ts` l.150; `course.service.ts` l.83).
- **Opción A:** el provider los agrega a los DTO de lectura (los que existan en DB) y el consumer deja de sintetizar.
- **Opción B:** se declaran no necesarios: el consumer elimina esos campos y su visualización.
- **Impacto A:** cambios aditivos de contrato; depende de que la DB los persista/exponga (`usp_crear_grupo` no persiste aula, TD-019).
- **Impacto B:** cambio en UI; sin cambio de provider.
- **Recomendación técnica:** A solo para los campos que la UI realmente muestra y la DB persiste; B para el resto (p. ej. `docenteName` debe ser el docente autenticado o eliminarse).
- **Status:** **RESOLVED — Opción B** (traslado formal por 06-cierre, 2026-09-22). Decisión humana pegada verbatim en la sesión de [LB-001B.1](../LB-001B.1-db-source-of-truth-cleanup/PLAN.md) (secciones 0 y 12-16 de la tarea autorizada): `topic`, `room`, `tipo` y `docenteName` **no** se agregan a DB/backend; se retiran del contrato de aplicación. Backend: `CrearSesionRequest`/`ActualizarSesionRequest`/DTOs retiran `descripcion/aula/tipo`; `SesionConsultadaDTO` permanece sin cambios (ya no los exponía). Implementado y verificado en [LB-001B.1](../LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md). El lado frontend (retiro de `topic/room/tipo/status` de `ClassSession` y del literal `docenteName` hardcodeado, con alcance ampliado a las pantallas fuera de `attendance-control` que también lo usan) se ejecuta en el work item hermano del repo frontend `LB-001B.1B-db-source-of-truth-cleanup`, fuera de la autoridad de escritura de esta sesión backend.

### DR-005 — Causa/observación de excusa

- **Pregunta exacta:** ¿la causa y observación de una excusa (`EX`) capturadas en la UI deben persistirse?
- **Provider evidence:** `RegistroAsistenciaRequest` solo tiene `estudianteId` y `estado`; propiedades extra ⇒ 400; la lectura devuelve `observacion` siempre `''`.
- **Consumer evidence:** `confirmarExcusaConDatos` descarta `causa`/`observacion` (solo toast).
- **Opción A:** ampliar contrato de escritura/lectura (y DB) con causa/observación.
- **Opción B:** retirar la captura en la UI (no prometer persistencia).
- **Impacto A:** cambio de contrato + SP/DB (LB-001A no lo cubre); nuevos tests.
- **Impacto B:** cambio de UI; pierde información que el docente cree registrar.
- **Recomendación técnica:** definir con negocio si la causa es requisito; hasta entonces evitar mostrar «Excusa aplicada: {causa}» como si se guardara.
- **Status:** **RESOLVED / IMPLEMENTED** (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`): la UI no conserva campos de excusa/observación fuera del contrato de batch; cualquier ampliación futura requiere contrato nuevo.

### DR-006 — Dominio de `estado` en lectura

- **Pregunta exacta:** ¿el contrato garantiza que `estado` en `GET …/asistencias` ∈ {AN, SJC, EX}, y cómo se tratan códigos históricos de `RazonCausa`?
- **Provider evidence:** `estado` = `codigoRazonCausa` sin mapear ni filtrar; comentarios y TD-009 admiten códigos históricos; LB-001A cubre la escritura.
- **Consumer evidence:** TS restringe a los 3 valores y el mapper lanza ante otro.
- **Opción A:** el provider garantiza el dominio (filtra/mapea o la DB lo asegura) y se documenta.
- **Opción B:** el contrato admite `String` abierto y el consumer tolera valores desconocidos (p. ej. mostrar «desconocido» sin romper la lista).
- **Impacto A:** cambio en adapter/vista o garantía DB; contrato estricto.
- **Impacto B:** cambio en consumer/UX; contrato laxo.
- **Recomendación técnica:** A (contrato cerrado, coherente con LB-001A M-03) verificando con DB si existen filas históricas; B como defensa adicional en el consumer.
- **Status:** **RESOLVED — Opción A, fail-closed** (2026-09-23, 06-cierre; ver [LB-001B.4 AUDIT](../LB-001B.4-final-backend-contract-closure/AUDIT.md) y [contrato](../../contracts/BACKEND_GOLDEN_PATH_CONTRACT.md) §D). Escritura: `ESTADOS_VALIDOS` + `RC_001`; lectura: `AsistenciaConsultadaEntity` falla cerrado ante legacy/desconocido/ausente. Riesgo residual (`CPI`/`CPVP` históricos) en [TD-045](../../baseline/TECHNICAL_DEBT.md#td-045).

### DR-007 — Elegibilidad de estudiantes

- **Pregunta exacta:** ¿el listado del grupo (y el batch) debe incluir estudiantes con `codigoEstado` no activo (retirados/inactivos)?
- **Provider evidence:** la query no filtra por estado de matrícula; devuelve `codigoEstado/nombreEstado` (`GrupoRepositorySqlServerAdapter`, `WHERE eg.idGrupo = :idGrupo`).
- **Consumer evidence:** ignora `codigoEstado` y envía a todos en el batch.
- **Opción A:** el provider filtra (o marca elegibilidad) y el consumer solo lista/envía elegibles.
- **Opción B:** el consumer filtra por `codigoEstado` usando un dominio de códigos definido.
- **Impacto A:** cambio de contrato/consulta; **Impacto B:** el consumer necesita un dominio de códigos que hoy no está documentado.
- **Recomendación técnica:** A, tras conocer el dominio de `codigoEstado` (DB).
- **Status:** **RESOLVED / IMPLEMENTED** (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`): el consumer filtra estudiantes activos antes de proyectar asistencia; no bloquea LB-001C.

### DR-008 — Roles de la pantalla de asistencia

- **Pregunta exacta:** ¿qué roles deben acceder a `/app/asistencia`?
- **Provider evidence:** E-01, E-02 y E-05 exigen `DOCENTE`; E-03/E-04 admiten COORDINADOR/ADMINISTRADOR; el stream exige titularidad docente (`SecurityConfig` l.73,96,97,113; `LocalSseRealtimeStreamGateway` l.45). DECANO no tiene acceso a estos recursos.
- **Consumer evidence:** la ruta permite `DOCENTE, DECANO, ADMINISTRADOR, ADMIN` (`app.routes.ts` l.61).
- **Opción A:** el consumer restringe la ruta a `DOCENTE` (alineado con el backend, que es la autoridad).
- **Opción B:** el backend amplía RBAC/alcance para otros roles (requiere política de negocio y ownership institucional).
- **Impacto A:** cambio solo en UI; **Impacto B:** cambio de seguridad con nuevas pruebas 401/403/ownership (`uco-seguridad`).
- **Recomendación técnica:** A, salvo requisito de negocio explícito.
- **Status:** **RESOLVED / IMPLEMENTED** (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`): las pruebas frontend del Golden Path quedan verdes con el contrato RBAC vigente; no se amplía backend.

### DR-009 — Códigos de error de autorización/titularidad (TD-030)

- **Pregunta exacta:** ¿qué códigos estables representan «sin permiso» y «sin titularidad» y cómo se mapean a HTTP?
- **Provider evidence:** TD-030 (`VAL_003` con semántica de nombres/apellidos usado por SPs internos; no verificable en este repo); `ERR_ESTUDIANTE_NO_PERTENECE_SESION` ⇒ 403 (`DbExceptionTranslator` l.30-32); `ERR_DOCENTE_SIN_TITULARIDAD_SESION` ⇒ 403.
- **Consumer evidence:** no ramifica por `code`; trata 403 como «sin permisos».
- **Opción A:** definir códigos propios de autorización/titularidad en DB y backend antes del freeze.
- **Opción B:** congelar el contrato de errores solo con `status`+`message` y postergar la semántica de `code`.
- **Impacto A:** cambios DB/backend (fuera de LB-001B); **Impacto B:** contrato de errores parcial.
- **Recomendación técnica:** A (TD-030 bloquea el freeze completo del contrato de errores en LB-001C). **(Histórico LB-001B: TD-030 no se resolvía en esa fase.)**
- **Status:** **RESOLVED** (2026-09-23, 06-cierre, LB-001B.4). El contrato DB congelado formaliza el canal `DBCODE`; `SEC_001/SEC_002/EST_004 -> 403/FORBIDDEN` verificado con IT real; TD-030 `RESOLVED BY FROZEN DB BASELINE`. Ver [LB-001B.4 AUDIT](../LB-001B.4-final-backend-contract-closure/AUDIT.md) y [contrato](../../contracts/BACKEND_GOLDEN_PATH_CONTRACT.md) §G.

### DR-010 — Alcance de listado/orden/paginación

- **Pregunta exacta:** ¿LB-001C congela «lista completa sin paginación, con el orden AS-IS» para E-01…E-04, o define page/size/orden?
- **Provider evidence:** ver §8 (sin paginación; órdenes distintos; asistencias sin `ORDER BY`).
- **Consumer evidence:** no usa paginación/orden/búsqueda.
- **Opción A:** congelar AS-IS (sin paginación), documentando el orden y «sin orden garantizado» en asistencias.
- **Opción B:** introducir paginación/orden explícitos desde ahora.
- **Impacto A:** sin cambio de código; riesgo si crece el volumen; **Impacto B:** cambio breaking o versión aditiva + cambios en el consumer.
- **Recomendación técnica:** A para el Golden Path (no hay necesidad medida), con orden documentado.
- **Status:** **RESOLVED — Opción A** (2026-09-24, 06-cierre, LB-001B.4A). E-01…E-04 se congelan como listas completas AS-IS: sin `page/size/sort/q`; asistencias sin orden público garantizado (no hay `ORDER BY` contractual); la paginación es una future feature con contrato propio. Ver [contrato](../../contracts/BACKEND_GOLDEN_PATH_CONTRACT.md).

## 11. Bloqueos (BLOCKED_BY_MISSING_EVIDENCE)

| ID | Qué falta | Dónde se buscó | Qué bloquea | Quién debe aportarla |
|---|---|---|---|---|
| B-01 | Semántica del SP/vistas: re-guardado del lote, unicidad (estudiante, sesión) en `uv_detalle_asistencia`, validación del estado de sesión | Backend (use case, adapter, ITs), LB-001A | C-004f, C-005h, C-005j, C-013c | Equipo DB / certificación externa |
| B-02 | Nulabilidad de columnas de `uv_horario_docente`, `uv_sesion`, `uv_estudiante_grupo` | Backend (sin anotaciones), LB-001A | C-001d, C-002c, C-003c | Equipo DB |
| B-03 | Serialización JSON observada de `LocalTime` (E-01) e `Instant` (SSE `occurredAt`) | Tests backend (asertan `LocalDateTime`, no `LocalTime` ni el JSON del evento) | C-001e, C-010c | Backend (test de contrato) o corrida runtime |
| B-04 | Comportamiento runtime del stream: expiración de JWT con el canal abierto, reconexión real, entrega end-to-end | No hay E2E backend+frontend con `USE_MOCKS=false` (MV-001 pendiente) | C-007g y confirmación runtime de C-009/C-010/C-011 | Responsable de MV-001 |
| B-05 | Confirmación runtime del orden de interceptores en 401 (C-007d) | Inferido por lectura estática; sin spec | C-007d | Frontend (prueba/ejecución) |

## 12. Resumen de estados

| Estado | Filas |
|---|---|
| MATCH | C-001a/b/c/f/i, C-002a/b/d, C-003a/b/d/f, C-004a/b, C-005a/b/c/d/e/g, C-006a/b, C-007a/c/e/f, C-008a/b/e, C-009a…f, C-010a/b/d/e/f, C-011a/b/c/e/f, C-012b, C-014a |
| MISMATCH | C-002i, C-007b, C-007d, C-014b, C-014c |
| MISSING_IN_PROVIDER | C-001g, C-002e/f/g/h, C-005f, C-006c, C-013a |
| MISSING_IN_CONSUMER | C-001j, C-002j, C-003e, C-004d/e, C-006d/e/f, C-008c/d, C-009g, C-011d |
| DECISION_REQUIRED | C-003g, C-004c, C-006g, C-012a, C-013b, C-014d |
| BLOCKED_BY_MISSING_EVIDENCE | C-001d/e, C-002c, C-003c, C-004f, C-005h/j, C-007g, C-010c, C-013c |
| NOT_APPLICABLE | C-001h, C-002k, C-005i, C-010g, C-015, C-016 |

## 13. Contrato congelado

**DRAFT** — HTTP/FRONTEND CONTRACT NOT FROZEN.

Evidence of approval: ninguna para este documento de análisis. Actualización 2026-09-23: DR-001, 002, 004, 005, 006, 007, 008, 009 RESOLVED y DR-003 mapping RESOLVED; DR-010 permanecía PENDING; **actualización 2026-09-24 (LB-001B.4A): DR-010 RESOLVED, Opción A** (listas completas AS-IS, sin paginación). El freeze corresponde a LB-001C. Nota histórica: C-002e/DR-004 describen el estado AS-IS previo (el backend aceptaba `tema`); desde LB-001B.4A `tema` fue eliminado del contrato de `Sesion` (400 `FIELD_UNKNOWN`).
