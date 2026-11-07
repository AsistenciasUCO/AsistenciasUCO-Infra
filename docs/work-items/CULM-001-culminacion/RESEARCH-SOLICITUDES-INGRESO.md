---
status: active
type: research
scope: db-backend-frontend-docs
owner: fullstack-team
last-reviewed: 2026-11-06
---

# RESEARCH — Retiro de solicitudes de ingreso a grupos (CULM-001, paquete A)

Investigación de solo lectura sobre los worktrees `C:\Proyectos\GestionAsistencia-CULM001\` (`GestioAsistenciaDB`, `GestioAsistenciaBackend`, `GestioAsistenciaFrontend`, `AsistenciasUCO-Infra`). Decisión del responsable (2026-11-06): la matrícula es solo por QR (HU176B) o manual del docente (HU050). HU026, HU053, HU054 y HU055 se descartan. HU008 se conserva como consulta de oferta, sin el botón "Solicitar ingreso". Las rutas son relativas a la raíz de cada repo, salvo que se indique otra cosa.

## 0. Hallazgos que cambian el alcance

1. **No existe `usp_resolver_solicitud_matricula` ni tabla `SolicitudMatricula` en el esquema.** `GestioAsistenciaDB/migrations/08_eliminar_codigo_sin_uso_up.sql:30` ya hizo `DROP` del SP. De ese flujo "viejo" solo quedan los stubs 501 del coordinador y el mensaje `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`.
2. **`/estudiante/solicitudes-matricula` ya no es un stub.** Lo sirve `EstudianteSolicitudIngresoController` (HU053-HU055 implementados). Solo `/coordinador/solicitudes-matricula` es 501.
3. **El contrato WORM no menciona nada de esto.** `AsistenciasUCO-Infra/docs/contracts/openapi/openapi-golden-path.yaml`, `DB_BASELINE_CONTRACT.md`, `DB_DEVELOP_FREEZE_ADDENDUM.md` y los manifiestos `.sha256` de BD no contienen rutas, SP ni tabla de solicitudes de ingreso. Los manifiestos solo listan SP de reclamos (`usp_radicar_solicitud_revision_asistencia_v2`, `usp_consultar_solicitudes_revision_docente`), que no se tocan. El retiro no exige re-congelar hashes; confirmar con `infra.ps1 verify`. El único punto de contrato "vivo" es el JSON de `GET /estudiante/oferta-academica` (HU008), que pierde 2 campos (ver sección 5), y `docs/contracts/HTTP_AS_IS_MATRIX.md` del backend (no WORM).
4. **Homónimos que se conservan:** `SolicitudRevisionAsistencia` (reclamos HU010-HU015: `usp_*solicitud_revision*`, `uv_*solicitud_revision*`, `estadoSolicitud` de reclamos). No usar grep ciego por "solicitud".
5. **Hueco funcional que abre el retiro:** la reactivación de matrícula retirada (`I -> A`, decisión INT-HU-01) vive solo dentro de `usp_resolver_solicitud_ingreso_grupo` (líneas ~174-189). `usp_registrar_estudiante_en_grupo_interno` (manual HU050) y `usp_internal_matricular_por_token` (QR) no la tienen. Ver riesgo 1.

## 1. Base de datos (`GestioAsistenciaDB/`)

### 1.1 Objetos a retirar (borrar de `schema/` y `DROP` en migración)

| Objeto | Archivo |
|---|---|
| Tabla `dbo.SolicitudIngresoGrupo` (PK, `UX_SolicitudIngresoGrupo_Abierta` filtrado por estados P y E, `IX_SolicitudIngresoGrupo_Grupo_Estado_Fecha`, default de `fechaSolicitudUtc`) | `schema/tables/SolicitudIngresoGrupo.sql` |
| 5 FK desde la tabla (`_Estudiante`, `_Grupo`, `_Estado`, `_Docente`, `_EstudianteGrupo`). Ninguna tabla externa la referencia | `schema/tables/zz_foreign_keys.sql:352-377` (bloque "42-46") |
| SP `usp_registrar_solicitud_ingreso_grupo` (171 líneas) | `schema/stored-procedures/usp_registrar_solicitud_ingreso_grupo.sql` |
| SP `usp_resolver_solicitud_ingreso_grupo` (311) | `schema/stored-procedures/usp_resolver_solicitud_ingreso_grupo.sql` |
| SP `usp_retirar_solicitud_ingreso_grupo` (159) | `schema/stored-procedures/usp_retirar_solicitud_ingreso_grupo.sql` |
| SP `usp_consultar_solicitudes_ingreso_grupo_docente` (113) | `schema/stored-procedures/usp_consultar_solicitudes_ingreso_grupo_docente.sql` |
| SP `usp_consultar_solicitudes_ingreso_estudiante` (95) | `schema/stored-procedures/usp_consultar_solicitudes_ingreso_estudiante.sql` |
| SP `usp_consultar_destinatarios_solicitud_ingreso_grupo` (87) | `schema/stored-procedures/usp_consultar_destinatarios_solicitud_ingreso_grupo.sql` |
| Grants de los 6 SP (el archivo hace `THROW 52183..52188` si algún SP falta, así que debe borrarse con ellos) | `schema/security/rol_asistencias_runtime_hu053_hu055.sql` (`deploy_schema.ps1` carga `schema/security/*.sql` por glob) |
| Seed de estados `E` en espera (`C5D1E2F3-4A5B-4C6D-8E7F-901A2B3C4D5E`) y `X` retirada (`D6E2F3A4-5B6C-4D7E-9F80-A12B3C4D5E6F`) en `dbo.Estado` | `schema/seed/22_estados_solicitud_ingreso_grupo.sql` |
| Seed de mensajes `SIG_001..SIG_015` (usuario, y los técnicos en un segundo `MERGE`) | `schema/seed/23_mensajes_solicitud_ingreso_grupo.sql` (60 líneas) |

No hay funciones `ufn_*` ni vistas `uv_*` propias de la solicitud de ingreso. Los parámetros que usan los SP son genéricos (`GENERAL.GUID_DEFECTO_CORRELACION`, `GENERAL.CADENA_VACIA`, `TIEMPO.ZONA_HORARIA_SQLSERVER`); no hay filas de `CatalogoParametro` propias.

### 1.2 Referencias dentro de archivos que se conservan (editar)

| Archivo | Línea | Qué hacer |
|---|---|---|
| `schema/stored-procedures/usp_consultar_oferta_grupos_estudiante.sql` | 135-136 (columnas `idSolicitudAbierta`, `codigoEstadoSolicitud`) y 151-157 (`OUTER APPLY` sobre `dbo.SolicitudIngresoGrupo`) | Obligatorio: quitar el `OUTER APPLY` y las 2 columnas, o el SP no compila sin la tabla. Cambia el resultset y su orden posicional (ver sección 5) |
| `schema/seed/04_mensaje.sql` | 118 y 254 | Quitar `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA` (usuario y técnico) |
| `schema/seed/26_plantillas_notificacion.sql` | 17-22 (marcadores) y 71-73 (plantillas) | Quitar los 3 tipos `SOLICITUD_INGRESO_REGISTRADA`, `_RESUELTA`, `_RETIRADA` |
| `test/test_notif002a_plantillas_contacto.sql` | 36, 49-83, 94-104, 328-330 | Quitar asserts de los 3 tipos y recalcular los conteos esperados |
| `test/test_contract_closure.sql` | 201-206, y las listas `NOT IN` de 252, 271, 292 | Quitar los 4 SP de las excepciones (`usp_resolver_...`, `usp_consultar_solicitudes_ingreso_grupo_docente`, `usp_consultar_solicitudes_ingreso_estudiante`, `usp_consultar_destinatarios_solicitud_ingreso_grupo`) |
| `test_suite.sql` | 34 | Quitar `:r /tmp/test/test_solicitud_ingreso_grupo.sql` |
| `test/test_usp_consultar_oferta_grupos_estudiante.sql` | 96 (INSERT fixture en `SolicitudIngresoGrupo`) y asserts de las 2 columnas | Quitar el caso "solicitud abierta" y las columnas |
| `migrations/08_notif002a_plantillas_notificacion_up.sql` | 64-69, 85-87 | No editar (migración histórica). La migración nueva borra esos datos |
| `migrations/02_datos_semilla_representativos.sql` | 187-191 | Sin acción: inserta en `SolicitudMatricula` solo si la tabla existe (no existe) |

### 1.3 Pruebas T-SQL

| Archivo | Acción |
|---|---|
| `test/test_solicitud_ingreso_grupo.sql` (309 líneas, S-01..S-12) | Borrar |
| `test/test_hu008_regla_inscripcion_programa.sql` (líneas 62-85) | Reescribir, no borrar. Prueba la regla ESP vs transversal de `usp_registrar_estudiante_en_grupo_interno` usando registrar+resolver solicitud como vía. Redirigir a `usp_registrar_estudiante_en_grupo` (HU050). Es la única cobertura de esa regla de John (2026-10-27) |
| `test/test_int_hu01_reactivar_matricula_retirada.sql` (líneas 49-80) | Reescribir o borrar según la decisión del riesgo 1: prueba la reactivación `I -> A`, que hoy solo existe en el resolver |

`test_runtime_grants_backend_inventory.sql`, los otros `rol_asistencias_runtime*.sql` y `scripts/lb004d-manifest.ps1` no mencionan estos SP (sus coincidencias son de reclamos).

### 1.4 Docs de BD

- Borrar `docs/work-items/HU053-HU054-HU055-solicitudes-ingreso-grupo/` (PLAN, TEST_PLAN, VALIDATION).
- Editar fichas, inventario y conteos: `docs/arquitectura/DOCUMENTACION_PROCEDIMIENTOS_PUBLICOS.md` (8 menciones), `docs/arquitectura/especificacion_sp_endpoints.md` (8), `docs/arquitectura/transaccion-procedimiento.md` (1), `docs/catalogos/catalogo-mensajes.md` (15 filas `SIG_`), `docs/work-items/HU008-oferta-grupos-estudiante/PLAN.md`.
- Históricas, solo anotar "retirado en CULM-001": `docs/work-items/{HU051-retirar-estudiante-grupo,INT-HU-01-reactivar-matricula-retirada,CERT-F3-CORRECCIONES,BD-eliminar-codigo-sin-uso,REC4-*}/PLAN.md`, `docs/reportes/*`.
- `GestioAsistenciaBackend/docs/work-items/INTEGRACION-DEVELOP-20261027/live-db/{01_fk_solicitud_ingreso_grupo.sql,aplicar-paquete-a.ps1,00_inventario_solo_lectura.sql}`: scripts de una integración ya ejecutada; no tocar.

### 1.5 Patrón de migración `up`/`down` a copiar

Carpeta `GestioAsistenciaDB/migrations/`. Último número en uso: `12_categoria_justificacion_*`. Nombres propuestos: `13_retiro_solicitudes_ingreso_grupo_up.sql` y `_down.sql`.

- **RETIRO-SEDES (HU020/HU140) no tuvo cambios de BD** (`GestioAsistenciaBackend/docs/work-items/RETIRO-SEDES-HU020-HU140/VALIDATION.md`: "BD: Sin cambios"). El modelo real con `up`/`down` de retiro es CAT-01 (`docs/work-items/CAT-01-catalogos-solo-consulta/PLAN.md` en BD), más `08_eliminar_codigo_sin_uso_*` y `09_eliminar_validar_grupo_docente_*`.
- `11_catalogos_solo_consulta_up.sql` (52 líneas): `USE [gestionasistenciadb]; GO; SET NOCOUNT ON;`, comentario con la decisión de John y el porqué ("`deploy_schema.ps1` no borra objetos. Idempotente"), y por cada objeto `IF OBJECT_ID(N'dbo.usp_x', N'P') IS NOT NULL DROP PROCEDURE [dbo].[usp_x]; GO`. Los `GRANT` caen con el `DROP`.
- `11_catalogos_solo_consulta_down.sql` (1548 líneas): cabecera "Rollback de ...: restaura los SP tal como estaban en develop (<sha>)", `USE; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;` y por SP un `CREATE OR ALTER PROCEDURE` con el cuerpo completo más sus `GRANT EXECUTE ... TO [rol_asistencias_runtime]`. Variante corta: `09_eliminar_validar_grupo_docente_up.sql` (11 líneas) y `_down.sql` (141).
- Para tablas: `07_notif001_notificacion_saliente_*` y `08_notif002a_plantillas_notificacion_*` (up con `IF OBJECT_ID(...) IS NULL`; down con `IF OBJECT_ID('dbo.X','U') IS NOT NULL DROP TABLE dbo.X`).
- Plan de la `up` nueva, en orden: (1) `DROP PROCEDURE` de los 6 SP; (2) `DROP TABLE dbo.SolicitudIngresoGrupo` (arrastra FK e índices); (3) `DELETE` en `CatalogoMensajeUsuario` y `CatalogoMensajeTecnico` de `SIG_001..SIG_015` y `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`; (4) `DELETE` de `PlantillaNotificacionMarcador` y `PlantillaNotificacion` para los 3 tipos (no hay FK desde `NotificacionSaliente.tipo`); (5) estados `E` y `X`: decisión pendiente. `Estado` es catálogo de solo consulta (regla CAT-01) y nada más en el repo usa `E`/`X`, pero la pantalla `admin-estados` los muestra. Recomendación: borrarlos con `DELETE ... WHERE id IN (...) AND NOT EXISTS (referencias)`.
- Plan de la `down`: recrear tabla, índices y 5 FK, los 6 SP con cuerpo completo (sacarlos de `git show <sha-develop>`), grants (contenido de `rol_asistencias_runtime_hu053_hu055.sql`), estados, mensajes y plantillas. No restaura datos.
- Además de la migración hay que borrar los `.sql` de `schema/` (como hizo CAT-01), porque `deploy_schema.ps1` recrea lo que encuentre en `schema/{tables,stored-procedures,security,seed}`.

## 2. Backend (`GestioAsistenciaBackend/`)

### 2.1 Endpoints

| Método y ruta | Clase | Estado |
|---|---|---|
| `POST /api/v1/estudiante/solicitudes-matricula` | `EstudianteSolicitudIngresoController` | real (HU053) |
| `GET /api/v1/estudiante/solicitudes-matricula` | idem | real (HU053/HU055) |
| `POST /api/v1/estudiante/solicitudes-matricula/{id}/retiro` | idem | real (HU055) |
| `GET /api/v1/docente/grupos/{grupoId}/solicitudes-ingreso` | `DocenteSolicitudIngresoController` | real |
| `PATCH /api/v1/docente/solicitudes-ingreso/{id}` | idem | real |
| `GET /api/v1/coordinador/solicitudes-matricula` | `CoordinadorPortalController:165` | stub 501 |
| `PATCH /api/v1/coordinador/solicitudes-matricula/{id}` | `CoordinadorPortalController:167-168` | stub 501 |

Mismo archivo, fuera de alcance directo pero a decidir: `POST /coordinador/grupos/{grupoId}/estudiantes` (`matricularEstudianteEnGrupo`, línea 169-170) es otro stub 501 de matrícula.

### 2.2 Archivos de producción (`src/main/java/co/edu/uco/asistenciasuco/`)

**A borrar (52):**
- `application/features/docente/consultarsolicitudesingreso/**` (10 archivos: InputPort, 3 DTO, Interactor, UseCase, 3 Domain, UseCaseImpl)
- `application/features/docente/resolversolicitudingreso/**` (7)
- `application/features/estudiante/consultarsolicitudesingreso/**` (10)
- `application/features/estudiante/retirarsolicitudingreso/**` (5)
- `application/features/estudiante/solicitaringresogrupo/**` (5)
- `application/secondaryports/academic/SolicitudIngresoGrupoPort.java`
- `application/secondaryports/academic/projection/{DestinatarioSolicitudIngresoProjection,SolicitudIngresoDocenteProjection,SolicitudIngresoEstudianteProjection}.java`
- `infrastructure/adapter/primary/controller/docente/{DocenteSolicitudIngresoController.java,request/ResolverSolicitudIngresoRequest.java,response/SolicitudIngresoDocenteResponse.java}`
- `infrastructure/adapter/primary/controller/estudiante/{EstudianteSolicitudIngresoController.java,request/SolicitarIngresoGrupoRequest.java,response/SolicitudIngresoCreadaResponse.java,response/SolicitudIngresoEstudianteResponse.java}`
- `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/SolicitudIngresoGrupoJpaRepository.java` (225 líneas). No hay entidad JPA ni mapper: es un `@Repository` nativo que implementa el puerto y llama a los SP.
- `src/main/resources/notification/templates/{SOLICITUD_INGRESO_REGISTRADA,SOLICITUD_INGRESO_RESUELTA,SOLICITUD_INGRESO_RETIRADA}.es.properties` (3)

**A editar (12 .java + 2 recursos):**

| Archivo | Referencia | Cambio |
|---|---|---|
| `infrastructure/config/wiring/EstudianteWiringConfiguration.java` | imports 35, 42-53; beans 137-163 (4 casos de uso con sus interactors) | quitar imports y beans |
| `infrastructure/config/wiring/DocenteWiringConfiguration.java` | imports 41-49; beans 179-195 (2 casos de uso) | idem |
| `infrastructure/adapter/primary/controller/coordinador/CoordinadorPortalController.java` | 165-168 | quitar los 2 stubs y lo que quede sin uso |
| `application/secondaryports/notification/Notificacion.java` | 23, 25, 27 | quitar 3 constantes `TIPO_SOLICITUD_INGRESO_*` |
| `infrastructure/adapter/secondary/notification/template/PlantillaPorDefectoCatalogo.java` | 24-26 (`TIPOS_CONOCIDOS`) | quitar 3 tipos |
| `infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` | 110-115 (`SIG_001..SIG_013` a HTTP) | quitar el bloque |
| `application/secondaryports/academic/projection/GrupoOfertaEstudianteProjection.java` | 7 (Javadoc), 29-30 | quitar `idSolicitudAbierta`, `codigoEstadoSolicitud` |
| `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/OfertaGruposEstudianteJpaRepository.java` | 63 (total en `[20]`), 71-74 (mapeo posicional: `[17]` idSolicitud, `[18]` estado, `[19]` componente) | reindexar: componente a `[17]`, total a `[18]` |
| `application/features/estudiante/consultarofertagrupos/usecase/domain/GrupoOfertaDomain.java` | 28 | quitar campos |
| `.../consultarofertagrupos/primaryports/dto/GrupoOfertaDTO.java` | 24 y `estadoSolicitud` | idem. Es el cuerpo de `GET /estudiante/oferta-academica` |
| `.../consultarofertagrupos/primaryports/interactor/ConsultarOfertaGruposInteractor.java` | 29 | ajustar mapeo |
| `.../consultarofertagrupos/usecase/impl/ConsultarOfertaGruposUseCaseImpl.java` | 28 (`Map ESTADO_SOLICITUD`), 66-71 | quitar |
| `src/main/resources/application.yml` | 178 (`ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA` a `ERR021`) | quitar; revisar si `ERR021` queda libre |
| `infra/security-baseline/access-catalog.json` | 98, 99 (coordinador), 124, 131 (docente), 146, 147, 148 (estudiante) | quitar las 7 entradas |

`SecurityConfig` no tiene reglas propias de estas rutas (solo el catálogo). Tras editar `access-catalog.json`, correr `python -m unittest test_e2e_safety` en `infra/security-baseline/scripts` (RETIRO-SEDES dejó un `--prune` del PDP pendiente de aprobación de John; mismo caso aquí para las 7 rutas).

Eventos SSE: no hay eventos de solicitudes en el backend. Outbox: solo las 3 plantillas. Códigos de error: solo `SIG_*` y `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`. ArchUnit (`src/test/java/.../architecture`): ningún test nombra estas clases.

### 2.3 Pruebas backend (`src/test/`)

**A borrar (9)**, bajo `java/co/edu/uco/asistenciasuco/`:
- `application/features/docente/consultarsolicitudesingreso/usecase/impl/ConsultarSolicitudesIngresoDocenteUseCaseImplTest.java`
- `application/features/docente/resolversolicitudingreso/usecase/impl/ResolverSolicitudIngresoUseCaseImplTest.java`
- `application/features/estudiante/consultarsolicitudesingreso/usecase/impl/ConsultarSolicitudesIngresoEstudianteUseCaseImplTest.java`
- `application/features/estudiante/retirarsolicitudingreso/usecase/impl/RetirarSolicitudIngresoUseCaseImplTest.java`
- `application/features/estudiante/solicitaringresogrupo/usecase/impl/SolicitarIngresoGrupoUseCaseImplTest.java`
- `infrastructure/adapter/primary/controller/docente/DocenteSolicitudIngresoControllerTest.java`
- `infrastructure/adapter/primary/controller/estudiante/EstudianteSolicitudIngresoControllerTest.java`
- `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/SolicitudIngresoGrupoJpaRepositoryTest.java`
- `infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifierSolicitudIngresoTest.java`

**A editar (10):**

| Archivo | Cambio |
|---|---|
| `application/secondaryports/notification/CasosDeUsoEmisoresNotif002aDatosTest.java` | Tiene 3 casos con `ResolverSolicitudIngresoUseCaseImpl`, `RetirarSolicitudIngresoUseCaseImpl` y el puerto (líneas ~78-186). Quitar esos 3 y conservar los de retiro HU051 |
| `infrastructure/adapter/primary/controller/coordinador/CoordinadorPortalControllerTest.java` | línea ~172: `consultarSolicitudesMatricula` en la lista de 501 |
| `infrastructure/adapter/secondary/notification/template/PlantillaRendererTest.java`, `PlantillaNotificacionJpaRepositoryTest.java`, `channel/smtp/SmtpNotificacionChannelSenderTest.java`, `channel/smtp/NotificacionSmtpGreenMailIT.java` | Usan los tipos `SOLICITUD_INGRESO_*` como datos de ejemplo (6, 3, 2 y 5 usos). Cambiarlos a `RETIRO_ESTUDIANTE_GRUPO` u otro tipo vivo, sin relajar aserciones |
| `infrastructure/adapter/secondary/persistence/sqlserver/jpa/JpaRepositoryBeanUniquenessTest.java` | línea 32-35: verificar si lista `SolicitudIngresoGrupoJpaRepository` y quitarlo |
| `application/features/estudiante/consultarofertagrupos/ConsultarOfertaGruposUseCaseImplTest.java`, `infrastructure/.../jpa/repository/OfertaGruposEstudianteJpaRepositoryTest.java` (líneas 93-94, 147, 164), `infrastructure/adapter/primary/controller/estudiante/EstudianteOfertaAcademicaControllerTest.java` | Quitar aserciones de los 2 campos y reindexar las filas simuladas |
| `src/test/resources/messageucolab/catalogo-mensajes-usuario.psv` | líneas 75 y 124-138 (16 filas) |

RETIRO-SEDES cerró con 3128 tests y gate JaCoCo cumplido; este retiro quita tests. Reportar la cifra nueva y verificar el gate (LINE >= 80, BRANCH >= 70); no tocar umbrales.

### 2.4 Docs de backend

- Borrar `docs/work-items/HU053-HU054-HU055-solicitudes-ingreso-grupo/` (CLOSURE, CONTRACT, CONTRACT_MATRIX, PLAN, TEST_PLAN, VALIDATION).
- Editar: `docs/contracts/HTTP_AS_IS_MATRIX.md` (líneas 94-98 y 200-205), `docs/baseline/LINEA_BASE.md:325`, `docs/work-items/README.md:65`, `docs/baseline/TECHNICAL_DEBT.md:948` (aviso HU051/HU053-HU055), `docs/work-items/HU008-oferta-grupos-estudiante/{PLAN,CONTRACT}.md`.
- Históricas, solo anotar: `NOTIF-002A-plantillas-correo/*`, `HU051-retirar-estudiante-grupo/CLOSURE.md`, `INTEGRACION-*/**`, `SEC-BASELINE-018/019`, `LB-002-jpa-incremental/LB-002.1C-B2-DECISION.md`, `REG-000-programa-registro-vinculacion-roles/PLAN.md`.

## 3. Frontend (`GestioAsistenciaFrontend/src/app/`)

### 3.1 A borrar (7 archivos)

| Archivo |
|---|
| `features/student/student-enrollment-requests/student-enrollment-requests.component.ts` (234 líneas) y `.spec.ts` (125) |
| `features/teacher/teacher-grupos/components/teacher-grupo-solicitudes.component.ts` (250) y `.spec.ts` (122) |
| `core/services/solicitud-ingreso.service.ts` (112; exporta `EstadoSolicitudIngreso`, `SolicitudIngresoEstudiante`, `SolicitudIngresoDocente`, `FiltroSolicitudesIngreso`, `ResultadoSolicitudIngreso`) y `.spec.ts` (71) |
| `features/student/student-courses/components/student-course-enroll-form.component.ts` (106). Huérfano: ningún template lo usa. Sin spec |

### 3.2 A editar

| Archivo | Línea | Cambio |
|---|---|---|
| `app.routes.ts` | 525-531 (`estudiante/solicitudes`) | quitar la ruta; dejar `estudiante/oferta` |
| `layouts/dashboard-layout/dashboard-layout.component.ts` | 478-483 (menú "Solicitudes de Ingreso", ESTUDIANTE) | quitar |
| `features/student/student-group-offer/student-group-offer.component.ts` | 91-92 (badge solicitud pendiente/en espera), 93-104 (botón `data-accion="solicitar-ingreso"`), 122 (`inject(SolicitudIngresoService)`), método `solicitar(g)` y señal `enviando` | quitar; conservar tarjeta, cupos, badge Vigente/Próximo, "Ya estás matriculado", búsqueda y paginación |
| `features/student/student-group-offer/student-group-offer.component.spec.ts` | 9, 75, 91+ (OF-03 solicitar) | quitar solo los casos de solicitar |
| `core/services/oferta-academica.service.ts` y `.spec.ts` | 27-28 (`idSolicitudAbierta`, `estadoSolicitud`) | quitar de `GrupoOferta` |
| `features/teacher/teacher-grupos/components/teacher-grupo-hub.component.ts` | 9, 24 (import), 154-162 (pestaña "Solicitudes de Ingreso"), 227-228 (`<app-teacher-grupo-solicitudes>`), 263 (union `'SOLICITUDES'`), 274 (`matriculaCambiada` / `padronCambiado`) | quitar pestaña, componente y miembro del union; revisar si el output `padronCambiado` solo lo emitía la bandeja |
| `features/teacher/teacher-grupos/teacher-grupos.component.ts` | 192 (union), 270-271 (Javadoc) | quitar `'SOLICITUDES'` y corregir el comentario |
| `features/attendance/attendance-control/components/group-sessions-overview.component.ts` | 194-202, 333 (botón "Padrón y solicitudes" y title) | renombrar a "Padrón"; HU051 sigue |
| `features/attendance/attendance-control/attendance-control.component.ts` | 64-65 (`MENSAJE_MATRICULA_DUPLICADA_DOCENTE`: "su reingreso se hace por solicitud de ingreso ... Padrón y solicitudes"), 885-891 | reescribir según la decisión del riesgo 1 |
| `features/attendance/attendance-control/attendance-control.component.spec.ts` | 363 (`toContain('solicitud de ingreso')`) | ajustar al texto nuevo (cambio legítimo por decisión de producto) |
| `features/student/student-courses/student-courses.component.ts` | 36 (`'SOLICITAR_MATRICULA'`), 124 y 147, 146, 237-275 (`abrirSolicitudMatricula`, `enviarSolicitudMatricula`, `cursosDisponibles`) | quitar código muerto |
| `features/student/student-courses/components/student-courses-list.component.ts` | 211 (`openEnrollmentRequest`) | quitar output sin uso |
| `features/student/student-courses/student-courses.component.spec.ts` | 279 (spy con `crearSolicitudMatricula`) | quitar spy e inyección |
| `core/services/coordinator-management.service.ts` y `.spec.ts` | ts 22, 136-137, 536-570 (`getSolicitudesMatricula`, `crearSolicitudMatricula` a `POST /estudiante/solicitudes-matricula`, `resolverSolicitudMatricula` a `PATCH /coordinador/solicitudes-matricula/{id}`); spec 21, 561-600, 649-670 | quitar métodos, señal y casos |
| `features/coordinator/coordinator-students/coordinator-students.component.ts` y `.spec.ts` | ts 19 y 203 (`'SOLICITUDES'` en `PestanaModulo`, solo tipo); spec 36 y 46 | quitar del tipo y del spy |
| `core/models/role-management.model.ts` | 298-313 (`SolicitudMatriculaItem`) | quitar |
| `core/mocks/role-management.mock.ts` | 11, 902 (`MOCK_SOLICITUDES_MATRICULA`) | quitar |
| `core/mocks/mock-data-store.ts` | 11, 34, 61 | quitar |
| `core/mocks/mock-notificaciones.ts` | 41-65 (3 plantillas) | quitar |
| `core/interceptors/mock-backend.interceptor.ts` | 14, 18-38 (`SolicitudIngresoMock`), 234-248 (`SOL-MAT-*`), 559-577 (oferta mock con solicitudes), 580-625 (5 endpoints mock), 756-757 | quitar; la oferta mock queda sin los 2 campos |
| `core/interceptors/mock-backend.interceptor.spec.ts` | 289-346 (MK-01 y caso de oferta con solicitud) | quitar |
| `features/admin/admin-email-management/admin-email-management.component.ts` | 56-70 (3 entradas) | quitar; ajustar spec si cuenta entradas |
| `features/admin/admin-estados/admin-estados.component.ts` | 18, 35-38, 56 | solo texto: "Reclamos de asistencia". Si la migración borra `E` y `X`, el panel muestra P/A/R |

Sin cambios: `core/realtime/**` (no hay eventos de solicitudes), `src/environments/environment.ts` (sin flags propios; los mocks se activan por `USE_MOCKS` general), guards (no hay uno específico), dashboards (no hay contador de "solicitudes de ingreso pendientes"; lo que dicen `overview-*`, `teacher-claims` y `teacher-grupo-reclamos` es de reclamos), `core/golden-path-real-mode.spec.ts` y `core/api/models/estudiante-portal-api-dto.model.ts` (`estadoSolicitud` de reclamos).

### 3.3 Docs de frontend

Borrar `docs/work-items/HU053-HU054-HU055-solicitudes-ingreso-grupo/` (PLAN, TEST_PLAN, VALIDATION). Editar `docs/MAPA_COMPONENTES_FRONTEND.md` (57, 88-89), `docs/frontend-backend-contract.md` (93-94, 101), `docs/work-items/HU008-oferta-grupos-estudiante/{PLAN,TEST_PLAN}.md`. Histórica: `docs/work-items/CERT-F3-CORRECCIONES/PLAN.md`.

## 4. Docs e Infra

| Archivo | Línea | Acción |
|---|---|---|
| `AsistenciasUCO-Infra/docs/user-stories/HU-CATALOG.md` | 59 (HU008 "con Solicitar ingreso"), 77 (HU026), 113-115 (HU053-HU055), índice en 11 | marcar HU026, HU053, HU054, HU055 como descartadas; HU008 como consulta de oferta; actualizar totales (174 HUs) |
| `AsistenciasUCO-Infra/docs/user-stories/HOJA_DE_RUTA_JERARQUIA_ROLES.md` | 35 | quitar "solicita el ingreso a grupos de la oferta (HU008/HU053)" |
| `AsistenciasUCO-Infra/scripts/tests/test_all_hus.ps1` | 224-231 (`Run-Test "HU026"` a `POST /estudiante/solicitudes-matricula`) y 629-640 (`Run-Test "HU053,HU054"` a `GET/PATCH /coordinador/solicitudes-matricula`) | quitar ambos bloques |
| `AsistenciasUCO-Infra/scripts/quality/test-e2e-hus.ps1` | 248-256 (`Run-TestItem "HU026"`) | quitar |
| `AsistenciasUCO-Infra/docs/baseline/TECHNICAL_DEBT.md` | sin TD propia de estas HUs | nada. (La del backend, línea 948, ver 2.4) |
| `AsistenciasUCO-Infra/docs/work-items/CULM-001-culminacion/SCREEN-TESTS-estudiante.md` | 45-47 (sección 5) | actualizar tras el retiro |
| `AsistenciasUCO-Infra/docs/work-items/backend/REG-000-programa-registro-vinculacion-roles/PLAN.md` | 62, 77 (paquete D) | anotar descartado |
| `AsistenciasUCO-Infra/docs/work-items/INDEX.md` | no lista HU053-055 | registrar el work item nuevo |
| `C:\Proyectos\GestionAsistencia\docs\rutas-por-rol.md:144` | `POST /api/v1/estudiante/solicitudes-matricula | EstudiantePortalController` | fuera de los worktrees (workspace raíz); corregir aparte. La fila ya estaba mal (la clase real es `EstudianteSolicitudIngresoController`) |
| `C:\Proyectos\GestionAsistencia\docs\historias-de-usuario.md` | sin menciones de HU026/053/054/055 | nada |

## 5. Dependencias peligrosas (qué debe conservarse)

1. **HU008 (oferta):** `usp_consultar_oferta_grupos_estudiante` depende de la tabla (líneas 151-157). Editarlo en la misma migración y commit de BD que borra la tabla. El `OfertaGruposEstudianteJpaRepository` lee por posición (`f[17]` a `f[20]`): quitar 2 columnas sin reindexar deja `codigoComponente` y el total mal, sin error de compilación. Los tests `OfertaGruposEstudianteJpaRepositoryTest` y `JpaQueryAdapterContractTest` deben cazarlo; verificarlo. El JSON de `GET /estudiante/oferta-academica` pierde `idSolicitudAbierta` y `estadoSolicitud`.
2. **HU050 (matrícula manual):** conservar `usp_registrar_estudiante_en_grupo` y `usp_registrar_estudiante_en_grupo_interno`. Hoy solo el resolver (a borrar) y `usp_registrar_estudiante_en_grupo` llaman al interno. La regla HU008 de inscripción al programa (ESP inscribe en `EstudiantePrograma`; BAS e INS no) está probada solo vía el resolver (`test_hu008_regla_inscripcion_programa.sql`): reescribir la prueba, no perder la cobertura.
3. **HU176B (QR):** `usp_matricular_estudiante_por_token`, `usp_internal_matricular_por_token`, `usp_internal_resolver_token_matricula`, `usp_internal_rotar_token_matricula`, `usp_registrar_estudiante_por_token_publico` no referencian `SolicitudIngresoGrupo` (verificado en `schema/` y `test/`). Retiro limpio.
4. **Reactivación `I -> A`:** solo existe en el resolver. Ver riesgo 1.
5. **Notificaciones:** `RETIRO_ESTUDIANTE_GRUPO` (HU051) comparte `Notificacion`, `PlantillaPorDefectoCatalogo`, `PlantillaNotificacion*` y `CasosDeUsoEmisoresNotif002aDatosTest`. Solo se quitan los 3 tipos de solicitud.
6. **Reclamos (`SolicitudRevisionAsistencia`):** comparten nombres (`estadoSolicitud`, `uv_solicitud_revision_*`), la tabla `Estado` (`P/A/R`) y paneles del front. No tocar.
7. **`ERR_MATRICULA_DUPLICADA`:** el mensaje al docente en `attendance-control` depende de cómo se resuelva el reingreso.

### Recuento por capa

| Capa | A borrar | A editar |
|---|---|---|
| BD | 11 (tabla, 6 SP, grants, seeds 22 y 23, `test_solicitud_ingreso_grupo.sql`) + 3 docs de work-item | 9 de código y tests (`zz_foreign_keys`, SP de oferta, `04_mensaje`, `26_plantillas`, `test_suite`, `test_notif002a`, `test_contract_closure`, `test_usp_consultar_oferta`, y reescritura de `test_hu008` y `test_int_hu01`) + ~6 docs; 2 archivos nuevos (`13_*_up/down.sql`) |
| Backend main | 52 (49 .java + 3 .properties) | 14 (12 .java + `application.yml` + `access-catalog.json`) |
| Backend test | 9 | 10 |
| Backend docs | 6 | ~6 |
| Frontend | 7 + 3 docs de work-item | 24 .ts y .spec.ts + 2 docs |
| Infra y raíz | 0 | 6 archivos + `rutas-por-rol.md` fuera de worktree |

Totales aproximados: ~91 archivos a borrar (12 son docs de work-items), ~75 a editar, 2 a crear.

## 6. Riesgos

1. **Hueco de reingreso de retirados.** Al borrar el resolver desaparece la única reactivación de matrícula `I -> A`. Manual (HU050) y QR (HU176B) rechazan a un estudiante retirado por HU051 como ya matriculado. Hace falta una decisión de producto antes de ejecutar: (a) mover la reactivación a `usp_registrar_estudiante_en_grupo_interno` y a la ruta por token, con su prueba; o (b) aceptar que un retirado no vuelve. Los textos del front en `attendance-control` dependen de esto.
2. **Mapeo posicional de la oferta.** Quitar 2 columnas de `usp_consultar_oferta_grupos_estudiante` desplaza los índices del `OfertaGruposEstudianteJpaRepository`. Si BD y backend no se despliegan juntos, la oferta falla en runtime sin romper la compilación. Mismo despliegue y tests de contrato JPA como compuerta.
3. **Pérdida de datos y rollback parcial.** `DROP TABLE dbo.SolicitudIngresoGrupo` borra el historial (incluidas pendientes en vivo y aceptadas que enlazan `estudianteGrupo`). La `down` recrea estructura, no datos. Respaldar antes en cualquier entorno con datos. Filas de `NotificacionSaliente` pendientes de los 3 tipos quedarían sin plantilla tras el `DELETE`: dejar que el worker las envíe o purgarlas antes de aplicar la migración.
