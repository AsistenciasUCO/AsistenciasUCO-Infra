---
status: draft
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# PLAN — HU062 / HU089 / HU063 / HU090 / HU091 / HU092 / HU093: Directorio, vinculación y gestión de docentes del programa (Rol Coordinador)

Fase 01: Planificación y Definition of Ready (DoR), según `GUIA_METODICA_IMPLEMENTACION_HU.md`, `HOJA_DE_RUTA_JERARQUIA_ROLES.md`, `docs/governance/DEFINITION_OF_READY.md` y `AGENTS.md`.
Programa padre: `REG-000` (grupo **B**, pista B; las pistas A programas y C catálogos corren en paralelo en otras sesiones). Este PLAN **reemplaza** el borrador `HU062-HU089-HU063-HU090-HU091-vinculacion-docente` de la rama `docs/plan-registro-roles` e incorpora HU092 y HU093 (antes grupo I). Verificado contra `develop` @ `4ff37ff` el 2026-10-22.

> **Estado:** `AWAITING_OWNER_APPROVAL`. No se escribe código hasta que el usuario apruebe PLAN + CONTRACT y resuelva D1–D13 (§8).

---

## 1. Identidad y objetivo

- **Historias de usuario:**
  - **HU062**: directorio de profesores adscritos al programa.
  - **HU089**: listado de docentes del programa, con su estado de vinculación.
  - **HU063**: búsqueda predictiva por cédula o nombre.
  - **HU090**: selector controlado de tipo de vinculación.
  - **HU091**: vincular un docente al programa y sincronizar su cuenta en IAM.
  - **HU092**: modificar datos del docente (datos profesionales) — *se implementa después de HU091*.
  - **HU093**: activar/inactivar la vinculación del docente con el programa — *se implementa después de HU092*.
- **Work Item ID:** `HU062-HU093-docentes-coordinacion`
- **Fecha:** 2026-10-22
- **Base Git:** `develop` @ `4ff37ff`; rama `feature/HU062-HU093-docentes-coordinacion` en worktrees `.worktrees/<repo>-docentes`
- **Actor:** Coordinador de Programa (`COORDINADOR`).
- **Jerarquía:** Nivel 3, Coordinador ➔ Docente (adscrito al programa) ➔ Grupo. Asignar el docente titular a un grupo ya funciona con HU076B (`POST/PUT /api/v1/grupos`, `idDocente`).

### Criterios de aceptación

| ID | Criterio |
|---|---|
| CA-01 | El coordinador ve el directorio **paginado** de los docentes adscritos a **su** programa, con documento, nombre, correo, tipo de vinculación, estado de la vinculación y número de grupos asignados en el programa (HU062/HU089). |
| CA-02 | Un docente adscrito **aparece en el directorio aunque todavía no tenga grupos** (hoy `uv_docente` lo oculta). |
| CA-03 | El coordinador busca por prefijo de cédula o por parte del nombre, con *debounce* en el cliente y filtrado en el servidor (HU063). |
| CA-04 | El selector de tipo de vinculación sale de un catálogo de DB, sin valores quemados en el front (HU090). |
| CA-05 | **Alta nueva (HU091):** con tipo y número de documento, nombres, correo, contraseña inicial (DA-5) y tipo de vinculación, se crea el usuario, el rol docente y la vinculación al programa en una sola transacción. Después se aprovisiona la cuenta en Keycloak con el rol `DOCENTE`. |
| CA-06 | **Vincular un docente existente (HU091):** el coordinador elige de un selector a un docente de **su institución** que no esté adscrito a su programa (p. ej. uno que dicta en otro programa). Se crea solo la vinculación; no se duplican el usuario ni la cuenta. |
| CA-07 | Se rechazan con un mensaje de catálogo: documento o correo que ya pertenecen a otra persona, docente ya adscrito al programa, tipo de vinculación inexistente o inactivo, programa ajeno, docente de otra institución y contraseña que no cumple `PasswordRegistroRule`. |
| CA-08 | Si falla cualquier paso en DB, no queda nada a medias (`SET XACT_ABORT ON` + transacción). Si Keycloak falla después del commit, el use case responde un error controlado y el caso queda registrado como TD-015, igual que en HU120. |
| CA-09 | La pantalla `coordinador/docentes` deja de usar el GUID quemado `A1B2C3D4-…0001` y los textos fijos de departamento, y pide la contraseña inicial. |
| CA-10 | **HU092:** el coordinador edita, para un docente **vinculado a su programa**, el tipo de vinculación (de ese vínculo) y los nombres/apellidos de la persona (alcance exacto: D11). Correo y documento **no** se editan en este WI. Validación de ámbito dentro del SP. |
| CA-11 | **HU093:** el coordinador activa o inactiva **la vinculación del docente con su programa** (`DocentePrograma.estado`), no a la persona. Idempotente. Un docente inactivado deja de aparecer como opción de titular de grupos nuevos de ese programa (D12) y su cuenta Keycloak **no** se deshabilita (D12, puede tener otros roles/programas). |
| CA-12 | El `PATCH /coordinador/docentes/{id}/estado` y el `PUT /coordinador/docentes/{id}` dejan de responder 501. Sin actualización optimista en la UI: se refresca desde el servidor tras la respuesta. |

---

## 2. AS-IS (evidencia) vs. TARGET

| Dimensión | AS-IS (evidencia) | TARGET |
|---|---|---|
| **Modelo `Docente`** | `GestioAsistenciaDB/schema/tables/Docente.sql`: solo `id` y `usuario`. FKs: `Docente→Usuario` y `Grupo→Docente` (`zz_foreign_keys.sql` §8 y §21). **No hay relación con el programa** ni tipo de vinculación (búsqueda de `vinculaci`, `TipoContrato` y `DocentePrograma` en `schema/` y `migrations/`: sin resultados de modelo). | Nueva tabla `dbo.DocentePrograma` (`id`, `docente`, `programa`, `tipoVinculacion`, `estado BIT`, `fechaVinculacionUtc DATETIME2`) con `UNIQUE (docente, programa)` + catálogo `dbo.TipoVinculacion` (`id`, `codigo NVARCHAR(3) UNIQUE`, `nombre`, `estado`), con migración idempotente y seed (decisiones **D1/D2**). |
| **Vistas de docente** | `uv_docente_identidad` (`id`, `idUsuario`, `numeroIdentificacion`, `nombreCompleto`, `estaActivoUsuario`; sin correo ni nombres separados). `uv_docente` hace **`INNER JOIN uv_grupo`**, así que un docente sin grupos no tiene programa ni se ve. `uv_auth_docente` filtra al coordinador por `pr.id = d.idPrograma`, es decir, **solo a través de grupos**. | Nueva `uv_docente_programa` (identidad + correo + tipo de documento + programa, facultad e institución + tipo de vinculación + estado + `totalGruposPrograma`) basada en `DocentePrograma` (no depende de los grupos), y su versión con ámbito `uv_auth_docente_programa` (fail-closed: coordinador del programa, decano de la facultad, admin de la institución). `uv_docente` y `uv_auth_docente` **no cambian** (los usan las asignaciones académicas y la asistencia). |
| **SP de alta y vínculo** | `usp_registrar_docente_en_grupo` (RBAC `COORDINADOR`; **exige un grupo**; crea el usuario con `usp_sincronizar_usuario_interno` + `usp_sincronizar_docente_interno` + `usp_registrar_docente_en_grupo_interno`; **sin transacción ni `XACT_ABORT`**; `@numeroIdentificacion INT`). `usp_registrar_docente_en_grupo_autonomo`: **sin RBAC**, crea un usuario inactivo. `usp_sincronizar_docente_interno` responde **`VAL_006` ("correo ya registrado")** cuando el usuario ya es docente, que no es el mensaje correcto. Ningún backend invoca estos SP. | Nuevo SP público `usp_vincular_docente_programa` (transaccional, RBAC `COORDINADOR` + titularidad `PROGRAMA`) con dos modos: **existente** (`@idDocente`) o **nuevo** (datos personales + hash). Delega en `usp_sincronizar_usuario_interno` (si es nuevo), `usp_sincronizar_docente_interno` (solo si el usuario aún no es docente; se cambia `VAL_006` por un código propio, `DOC_002`) y el nuevo `usp_internal_vincular_docente_programa`. El destino de `…_autonomo` lo decide **D7**. |
| **Consultas** | No existe `usp_consultar_*` de docentes. El backend lee `UvDocenteIdentidadEntity` con HQL **sin ámbito** (`DocenteJpaRepository.consultarDocentes()`, expuesto en `GET /api/v1/docentes` para `COORDINADOR` y `ADMINISTRADOR`): devuelve todos los docentes de todas las facultades. | `usp_consultar_docentes_programa` (paginado sobre `uv_auth_docente_programa`; filtros `@busqueda`, `@estaActivo`, `@idTipoVinculacion`) y `usp_consultar_candidatos_docente_programa` (docentes de la **institución** del ejecutor que **no** están en su programa; `@busqueda` de mínimo 3 caracteres; tope de filas por parámetro). El `GET /api/v1/docentes` sin ámbito se registra como deuda (§13) y no se usa en las pantallas nuevas. |
| **Backend: coordinador** | `CoordinadorPortalController.java` (verificado en `develop`): `GET /coordinador/docentes`, `POST /coordinador/docentes` y `PATCH /coordinador/docentes/{id}/estado` lanzan `unavailable()` → 501. **No existe** `PUT /coordinador/docentes/{id}` (el catálogo HU lo anuncia). | Fase HU091: `GET`/`POST /api/v1/coordinador/docentes` + `GET …/candidatos`. Fase HU092: `PUT …/{idDocente}`. Fase HU093: `PATCH …/{idDocente}/estado` con body `{ "estaActivo": bool }`. |
| **Backend: `/api/v1/docentes`** | `DocenteController.java:151` (`POST /docentes`, `RegistrarDocenteDesdeUsuarioUseCaseImpl`) y `:168` (`POST /docentes/asignaciones/grupo`, `AsignarDocenteAGrupoUseCaseImpl`) llegan a `DocenteJpaRepository.java:93-105`, que lanza `FeatureUnavailableException` → 501. Sin Keycloak (TD-013). Wiring en `DocenteWiringConfiguration` ⚠️ archivo caliente. | **D6:** se retiran los dos endpoints duplicados (los sustituyen `POST /coordinador/docentes` y `PUT /grupos/{id}`, ya certificado) junto con sus features, puertos y beans. Es un commit separado, **al final del WI**. |
| **Backend: ámbito** | `InstitutionalScopePort.findProgramaIdByCoordinadorUsuario(UUID)` ya existe. `SecurityConfig.java:135`: `/api/v1/coordinador/**` → `COORDINADOR`, `ADMINISTRADOR`. | Sin regla nueva en `SecurityConfig`: el use case exige el programa del coordinador (si no lo tiene → 403; también aplica a un ADMINISTRADOR, D8) y el SP revalida RBAC y titularidad. |
| **Backend: identidad** | Patrón HU120 en `CrearCoordinadorUseCaseImpl`: el hash va a DB, se relee el usuario por correo y luego `IdentityProviderPort.crearCuenta(... InstitutionalRole.COORDINADOR)`. Si la cuenta ya existe se respeta la contraseña y se asegura el rol (`docs/security/keycloak-identity-provider.md` l.154-188). **Contraseña por defecto** `UcoCoord_<doc>!` si viene vacía. | Mismo patrón con `InstitutionalRole.DOCENTE`, también en el modo existente (asegura el rol sin tocar la contraseña). **Sin contraseña por defecto:** si es una persona nueva y falta la contraseña → 400 (DA-5 / `PasswordRegistroRule`). |
| **Frontend** | `features/coordinator/coordinator-docentes/coordinator-docentes.component.ts` (OnPush, con spec) usa `CoordinatorManagementService.getDocentes()`, `createDocente()` y `toggleDocenteStatus()` (`core/services/coordinator-management.service.ts:56-65`), que responden 501. El formulario tiene `tipoIdentificacionId: 'A1B2C3D4-0000-0000-0000-000000000001'` **quemado** (l.523), `departamento` fijo, `especialidad` obligatoria (**no existe en DB**), **no pide contraseña** y no tiene selector de vinculación. Usa `UserPickerModalComponent` para "vincular un docente ya registrado". El toggle llama a `…/{id}/toggle` (la ruta del backend es `…/estado`). Filtrado **en el cliente** sobre la lista completa. | Servicio tipado y paginado (`getDocentesPrograma(filtro)`, `getCandidatos(busqueda)`, `vincularDocente(payload)`, `getTiposVinculacion()`). Búsqueda por el servidor con *debounce* sobre un signal (sin `setInterval`). Formulario con tipo de documento del catálogo, contraseña inicial, tipo de vinculación y modo "existente" con el picker alimentado por `…/candidatos`. Se quitan `especialidad` y `departamento` (D5). El botón de estado se habilita en la tanda HU093 (antes: deshabilitado). |
| **Realtime** | Nada. | Sin SSE en este WI (D9). |

---

## 3. Clase de cambio y perímetro de rutas

- **Change class:** `BEHAVIOR_CHANGE` + `CONTRACT_CHANGE` aditivo (HTTP y DB) + **DDL** (tabla de vínculo y catálogo, con D1/D2) + retiro de endpoints legacy en 501 (D6).
- **PRIMARY_VARIABLE:** adscripción del docente al programa (alta o vínculo) y su directorio, administrados por el coordinador.
- **ALLOWED_PATHS:**
  - `GestioAsistenciaBackend/docs/work-items/HU062-HU093-docentes-coordinacion/**`
  - `GestioAsistenciaDB/migrations/<nn>_hu091_docente_programa_tipo_vinculacion.sql` (nuevo) y `schema/tables/{DocentePrograma,TipoVinculacion}.sql` (nuevos), además de `schema/tables/zz_foreign_keys.sql` (solo para agregar FKs; requiere D1)
  - `GestioAsistenciaDB/schema/seed/<nn>_tipo_vinculacion.sql` (nuevo), `schema/seed/04_mensaje.sql` (códigos `DOC_*`), `schema/seed/03_parametro.sql` (tope de candidatos; `PAGINACION / TAMANO_MAXIMO`: verificar si ya existe en `develop` o si lo agrega la pista A; no duplicar)
  - `GestioAsistenciaDB/schema/views/{uv_docente_programa, uv_auth_docente_programa, uv_tipo_vinculacion}.sql` (nuevas)
  - `GestioAsistenciaDB/schema/stored-procedures/{usp_vincular_docente_programa, usp_internal_vincular_docente_programa, usp_consultar_docentes_programa, usp_consultar_candidatos_docente_programa}.sql` (nuevos); fase HU092/HU093: `usp_actualizar_docente_programa.sql`, `usp_cambiar_estado_docente_programa.sql` (+ `usp_internal_*` si aplica)
  - `GestioAsistenciaDB/schema/stored-procedures/usp_sincronizar_docente_interno.sql` (solo el cambio de `VAL_006` por `DOC_002`)
  - `GestioAsistenciaDB/schema/stored-procedures/usp_registrar_docente_en_grupo_autonomo.sql` y `test/test_usp_registrar_docente_en_grupo_autonomo.sql` (retiro, solo si D7 = retirar)
  - `GestioAsistenciaDB/test/test_usp_vincular_docente_programa.sql`, `test_usp_consultar_docentes_programa.sql`, `test_usp_consultar_candidatos_docente_programa.sql` (nuevos); `test_usp_registrar_docente_en_grupo_usuario_no_existente.sql` (solo si cambia el código de error que asierta, ver R3)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/features/coordinador/{consultardocentesprograma, consultarcandidatosdocente, vinculardocenteprograma, actualizardocenteprograma, cambiarestadodocenteprograma}/**` (nuevos)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/features/tipovinculacion/consultartiposvinculacion/**` (nuevo)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/academic/{DocenteProgramaCommandPort, DocenteProgramaQueryPort, TipoVinculacionQueryPort}.java` y `projection/{DocenteProgramaProjection, DocenteCandidatoProjection, TipoVinculacionProjection}.java`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/jpa/{repository/DocenteProgramaJpaRepository.java, repository/TipoVinculacionJpaRepository.java, entity/SpDocenteProgramaPaginadoEntity.java, entity/SpDocenteCandidatoEntity.java, entity/UvTipoVinculacionEntity.java}`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/coordinador/{CoordinadorPortalController.java, request/VincularDocenteProgramaRequest.java, response/DocenteProgramaResponse.java, response/DocenteCandidatoResponse.java, mapper/DocenteProgramaHttpMapper.java, validation/VincularDocenteProgramaRequestValidator.java}`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/tipovinculacion/TipoVinculacionController.java` (nuevo)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/wiring/CoordinadorWiringConfiguration.java` y `TipoVinculacionWiringConfiguration.java` (nuevo, patrón de `TipoIdentificacionWiringConfiguration`)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` (códigos `DOC_*`)
  - **Solo con D6, como último commit:** `DocenteController.java`, `DocenteWiringConfiguration.java` ⚠️, `application/features/docente/{registrardocentedesdeusuario, asignardocenteagrupo}/**` (retiro), `DocenteRepositoryPort.java` y `DocenteJpaRepository.java` (quitar los dos métodos en 501), además de sus tests
  - `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/**` (tests del perímetro y `RbacSecurityFilterChainTest` ⚠️)
  - `GestioAsistenciaBackend/docs/contracts/HTTP_AS_IS_MATRIX.md` ⚠️ (fase 06)
  - `GestioAsistenciaFrontend/src/app/core/services/coordinator-management.service{,.spec}.ts` (solo la sección DOCENTES)
  - `GestioAsistenciaFrontend/src/app/core/models/docente-programa.model.ts` (nuevo); `core/models/role-management.model.ts` (`DocenteItem`, si se reemplaza)
  - `GestioAsistenciaFrontend/src/app/features/coordinator/coordinator-docentes/**`
- **FORBIDDEN_PATHS:**
  - Contratos WORM (`docs/contracts/openapi/**`, `BACKEND_GOLDEN_PATH_CONTRACT.*`, `docs/contracts/external/db/**`)
  - `schema/tables/Docente.sql`, `Usuario.sql` y `Grupo.sql` (no se alteran)
  - `uv_docente.sql` y `uv_auth_docente.sql` (las usan las asignaciones y la asistencia)
  - `SecurityConfig.java` (no se necesita: comodines de las líneas 135 y 198)
  - `DocentePortalController.java` (archivo caliente, sin relación con este WI)
  - Archivos de HU035/036 (otra rama) y de las pistas A/C
  - `AsistenciasUCO-Infra/**` hasta la fase 06
- **CONTRACTS:** DB y HTTP aditivos. Retiro de 2 rutas que hoy responden 501 (D6), registrado en `HTTP_AS_IS_MATRIX.md`.
- **PROVIDERS:** SQL Server (JPA), Keycloak (`IdentityProviderPort`), App Configuration (mensajes `DOC_*`).
- **EXTERNAL_ENVIRONMENT:** `sql_server_asistencias`; Keycloak `:8081` para el E2E y `FakeKeycloakAdminServer` en las pruebas.
- **SECURITY_IMPACT:** crea cuentas `DOCENTE` en Keycloak (cierra TD-013 para docentes). El candidato expone solo los datos mínimos de docentes de **la misma institución** (sin correo; D4). Ámbito en dos capas: use case y SP / `uv_auth_*`.
- **OBSERVABILITY_IMPACT:** `correlationId` hasta los SP y en los logs del use case, sin PII. El fallo de Keycloak se loguea en `ERROR` con `idUsuario` (no con el documento).
- **TEST_LEVEL_REQUIRED:** T-SQL transaccional + JUnit unit/slice/wiring/ArchUnit + IT contra SQL Server + `FakeKeycloakAdminServer` + Jasmine + E2E.
- **ROLLBACK:** revertir los PRs en orden Front → Back → DB. La migración tiene un `down` que borra `DocentePrograma` y `TipoVinculacion` (no hay datos previos que perder). El retiro de D6 es reversible con `git revert` del commit aislado.
- **CONSUMERS:** portal Coordinador (`coordinador/docentes`; selector de docente al crear o editar grupo). Los reportes por docente (HU094/HU095).
- **STOP_CONDITIONS:**
  - D1–D13 sin resolver.
  - Un programa con coordinador es necesario para probar el ámbito: ya existe en el seed canónico (`coordinador.sistemas`); no se espera a la pista A.
  - Archivos calientes (§7) solo se tocan en el commit final aparte, coordinado con las otras pistas.
  - Una prueba existente (`test_usp_registrar_docente_en_grupo_*`) que solo pase relajándola → `TEST_CONTRACT_CONFLICT`.

Lo que no está en ALLOWED_PATHS no se modifica. Ampliar el alcance exige actualizar este PLAN con aprobación.

---

## 4. Alcance y no alcance

### Alcance
1. **DB:**
   - Modelo de adscripción `DocentePrograma` y catálogo `TipoVinculacion` (migración + `schema/tables` + seed).
   - Vistas `uv_docente_programa`, `uv_auth_docente_programa` y `uv_tipo_vinculacion`.
   - SP de vinculación (alta nueva o docente existente).
   - Consultas paginadas del directorio y de candidatos.
   - Corrección del mensaje en `usp_sincronizar_docente_interno`.
   - Mensajes `DOC_*` y pruebas T-SQL.
2. **Backend:**
   - Features del coordinador: directorio, candidatos y vinculación, con Keycloak.
   - Catálogo de tipos de vinculación.
   - Endpoints reales en `CoordinadorPortalController`.
   - Wiring en `CoordinadorWiringConfiguration` / `TipoVinculacionWiringConfiguration`.
   - Mapeo de errores.
   - Retiro de los endpoints legacy en 501 (D6).
   - Pruebas.
3. **Frontend:** directorio paginado con búsqueda en el servidor, formulario de alta y vínculo, selector de vinculación, picker de candidatos, limpieza de valores quemados, specs.

### No alcance
1. Deshabilitar/habilitar la cuenta Keycloak, cambiar correo en Keycloak o recuperar contraseña (requiere IAM-001, grupo E; D12/D11). Carga masiva de docentes (D13).
2. Ficha y historial del docente (HU094) y directorio consolidado de la facultad (HU095).
3. Asignar el docente a un grupo: ya existe en HU076B (`PUT /grupos/{id}` con `idDocente`). Solo se verifica que el selector de docentes del formulario de grupo pueda usar el directorio nuevo (T-FE-07).
4. Corregir `GET /api/v1/docentes` sin ámbito (deuda §13, fuera de este WI).
5. Especialidad o departamento del docente (D5).
6. Ampliar `Usuario.numeroIdentificacion INT` (riesgo R5).

---

## 5. Archivos afectados

### Existentes (ruta comprobada)
- DB:
  - `schema/tables/Docente.sql`, `Usuario.sql` (lectura)
  - `schema/tables/zz_foreign_keys.sql`
  - `schema/views/uv_docente.sql`, `uv_docente_identidad.sql`, `uv_auth_docente.sql`, `uv_usuario.sql` (lectura)
  - `schema/stored-procedures/usp_registrar_docente_en_grupo.sql` (patrón y lectura), `usp_registrar_docente_en_grupo_autonomo.sql`, `usp_sincronizar_docente_interno.sql`, `usp_sincronizar_usuario_interno.sql` (reutilizado), `usp_validar_titularidad_jerarquica_interno.sql`, `usp_validar_permiso_rbac_usuario_interno.sql`
  - `schema/seed/04_mensaje.sql`
  - `test/test_usp_registrar_docente_en_grupo_usuario_no_existente.sql`, `test/test_usp_registrar_docente_en_grupo_autonomo.sql`
  - `test_suite.sql` ⚠️, `test/test_contract_closure.sql` ⚠️
- Backend:
  - `infrastructure/adapter/primary/controller/coordinador/CoordinadorPortalController.java`
  - `infrastructure/adapter/primary/controller/docente/DocenteController.java`
  - `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/DocenteJpaRepository.java`
  - `application/features/docente/{registrardocentedesdeusuario, asignardocenteagrupo}/**`
  - `infrastructure/config/wiring/{CoordinadorWiringConfiguration, TipoIdentificacionWiringConfiguration (patrón), DocenteWiringConfiguration ⚠️}.java`
  - `application/secondaryports/security/InstitutionalScopePort.java`
  - `application/secondaryports/identity/IdentityProviderPort.java`
  - `application/secondaryports/security/PasswordEncoderPort.java`
  - `application/features/usuario/domain/rules/PasswordRegistroRule.java`
  - Patrón: `application/features/decano/crearcoordinador/usecase/impl/CrearCoordinadorUseCaseImpl.java`, `controller/tipoidentificacion/TipoIdentificacionController.java`
- Frontend:
  - `core/services/coordinator-management.service{,.spec}.ts`
  - `core/models/role-management.model.ts`
  - `features/coordinator/coordinator-docentes/coordinator-docentes.component{,.spec}.ts`
  - `shared/components/user-picker-modal/**` (reutilizado)
  - `shared/components/pagination/**` (reutilizado)

### Nuevos (propuesta)
Los listados en §3 (ALLOWED_PATHS) más los tests de [TEST_PLAN.md](TEST_PLAN.md). En el front: `features/coordinator/coordinator-docentes/components/coordinator-docente-form-modal.component{,.spec}.ts`.

### Retirar (D6, último commit)
- `POST /api/v1/docentes` y `POST /api/v1/docentes/asignaciones/grupo`, con sus features `registrardocentedesdeusuario` y `asignardocenteagrupo`, los métodos `registrarDocenteDesdeUsuario` / `asignarDocenteAGrupo` de `DocenteRepositoryPort` y `DocenteJpaRepository`, los beans de `DocenteWiringConfiguration` y sus tests.
- **Condición previa:** Grep sin consumidores en el front (`/docentes/asignaciones`, `POST …/docentes` fuera de `coordinador/`) ni en los scripts E2E.

---

## 6. Contratos y consumidores afectados

| Tipo | Contrato | Compatibilidad | Consumidor |
|---|---|---|---|
| PERSISTENCE | `DocentePrograma`, `TipoVinculacion`, vistas y SP nuevos | Aditivo | Backend nuevo |
| PERSISTENCE | `usp_sincronizar_docente_interno`: `VAL_006` → `DOC_002` cuando el usuario ya es docente | Cambia el código de error de un SP **interno** (no lo invoca el backend). Se revisa su test (R3) | `usp_registrar_docente_en_grupo[_autonomo]` |
| HTTP | `GET/POST /coordinador/docentes`, `GET /coordinador/docentes/candidatos`, `GET /tipos-vinculacion` | Aditivo (2 de ellas hoy responden 501) | Front Coordinador |
| HTTP | Retiro de `POST /docentes` y `POST /docentes/asignaciones/grupo` | Hoy siempre responden 501, así que ningún consumidor funcional se rompe | — |
| SECURITY / IAM | Cuentas `DOCENTE` en Keycloak | Aditivo | Login del docente |

---

## 7. Archivos calientes (coordinación con las otras pistas)

- `RbacSecurityFilterChainTest.java`, `HTTP_AS_IS_MATRIX.md`, `GestioAsistenciaDB/test_suite.sql`, `test/test_contract_closure.sql`, `schema/seed/04_mensaje.sql`, `HU-CATALOG.md`: este WI **agrega** casos y entradas → un **commit aparte al final** por repo, para minimizar conflictos con las pistas A y C. Los tests nuevos viven en archivos propios y se invocan por su archivo hasta ese commit.
- `DocenteWiringConfiguration.java`: **solo** lo toca el retiro de D6, que va como **último commit** del backend.
- Para no tocarlo en el resto del WI, todos los beans nuevos van en `CoordinadorWiringConfiguration` y en el nuevo `TipoVinculacionWiringConfiguration`.
- `DocentePortalController.java`: no se toca.

---

## 8. Decisiones requeridas (bloquean READY)

| ID | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| **D1** | ¿Cómo se adscribe un docente a un programa? Hoy solo se infiere por los grupos. | (a) Tabla `DocentePrograma` (DDL con migración). (b) Sin DDL: "adscrito" = tiene grupos en el programa. | **(a)**: sin ella no se cumplen CA-02 ni HU091 ("vincular al programa" antes de asignar grupos), y no hay dónde guardar el tipo de vinculación (HU090) ni el estado de la vinculación (HU093). |
| **D2** | Catálogo de tipos de vinculación: ¿qué valores? | Propuesta: `PLA` Planta / tiempo completo, `MTI` Medio tiempo, `CAT` Cátedra, `OCA` Ocasional. | Que el owner los valide con la normativa UCO. El catálogo se administra por seed (sin CRUD en este WI). |
| **D3** | ¿Un docente puede estar adscrito a varios programas? | (a) Sí: N programas, un vínculo por programa y un tipo de vinculación por vínculo. (b) No: un solo programa. | **(a)**: es la realidad institucional (docentes de ciencias básicas que dictan en varios programas). HU125 (interdepartamentales) lo da por hecho. |
| **D4** | ¿Qué datos ve el coordinador de los candidatos de otros programas? | (a) Mínimos: id, tipo y número de documento, nombre completo. Sin correo. (b) Todos. | **(a)**: minimización de datos personales; el correo se ve solo cuando ya está vinculado. |
| **D5** | `especialidad` y `departamento` aparecen como obligatorios en la UI pero no existen en DB. | (a) Quitarlos de la UI en este WI; HU092 (D11) se limita a campos existentes. (b) Agregar columnas ahora. | **(a)**: no se persiste nada que no tenga contrato, y HU092 es la HU que habla de datos profesionales. |
| **D6** | Endpoints legacy `POST /docentes` y `POST /docentes/asignaciones/grupo` (siempre 501, sin Keycloak). | (a) Retirarlos en este WI, en un commit aparte y después del merge de HU035/036. (b) Dejarlos en 501 y registrar deuda. | **(a)**: evita dos caminos de alta (uno sin IAM) y cierra parte de TD-013. |
| **D7** | `usp_registrar_docente_en_grupo_autonomo` (sin RBAC; crea un usuario inactivo). | (a) Retirarlo de DB. (b) Dejarlo y registrar deuda de seguridad. | **(a)**. Grep del 2026-10-21: solo lo referencian su propio archivo, `test/test_usp_registrar_docente_en_grupo_autonomo.sql` y `test_suite.sql`; ni el backend, ni el front, ni los scripts. El test y su `:r` se retiran **junto** con el SP (cambio formal de contrato, no relajación), y se agrega un `DROP PROCEDURE IF EXISTS` en la migración. |
| **D8** | `SecurityConfig` deja pasar al `ADMINISTRADOR` en `/coordinador/**`. | (a) El use case lo rechaza con 403 (no tiene programa). (b) El admin puede consultar con `?idPrograma=`. | **(a)**: misma regla que la pista A. |
| **D9** | ¿Evento SSE al vincular? | (a) `DOCENTE_VINCULADO_PROGRAMA` (`UPPER_SNAKE`, sin PII; el SSE actual no filtra por destinatario). (b) No. | **(b)**: solo el coordinador del programa consulta su directorio. |
| **D10** | **Compensación si Keycloak falla tras el commit en DB** (HU091). | (a) Patrón HU117-B/HU120 (hoy): error controlado 500 (`InternalApplicationException`), la fila queda en DB sin cuenta, log ERROR; el reintento es idempotente (modo existente). `crearCuenta` ya borra la cuenta que ella misma creó si falla `establecerPassword`/`ensureClientRole`. (b) Compensar en DB: llamar a un SP que deshaga vínculo/usuario. (c) Outbox/tabla de desfase (IAM-001 D3). | **(a)** en este WI, más un mensaje claro al coordinador ("el docente quedó registrado, pero la cuenta de acceso no se pudo crear; reintente"). (b) es peligroso: el usuario puede existir ya por otros roles y se pierde la trazabilidad; (c) pertenece a IAM-001. La alta nueva fallida se reintenta como *vincular existente* (el docente aparece en candidatos solo si tiene vínculo en otro programa: ver R4 y D14). |
| **D11** | **Alcance de HU092 "datos profesionales"**: hoy no existen especialidad/departamento (D5) ni columnas editables salvo nombres, correo y tipo de vinculación. | (a) Editar **tipo de vinculación** (del vínculo) + **nombres y apellidos** de la persona. (b) Solo tipo de vinculación. (c) Agregar columnas profesionales (DDL). | **(a)** si se acepta que el cambio de nombres afecta a la persona en todos sus programas; si el owner prefiere no tocar `Usuario` desde un rol de programa, **(b)**. Correo y documento quedan fuera (el correo exige actualizar Keycloak: IAM-001). Los nombres no se sincronizan con Keycloak en este WI (queda en TD; el login no depende de ellos). |
| **D12** | **Semántica de HU093** (activar/inactivar). | (a) Cambia `DocentePrograma.estado` (vínculo con **este** programa). Inactivo ⇒ no elegible como titular para grupos nuevos/editados del programa; **grupos ya asignados se conservan** y se informa el conteo; Keycloak **sin cambios**. (b) Además inactiva `Usuario.estado` y deshabilita Keycloak. (c) Impedir inactivar con grupos activos. | **(a)**. Es consistente con IAM-001 D2 (desactivar rol en su ámbito ≠ desactivar persona) y no requiere IAM-001. Impacto a validar en RED: `usp_crear_grupo`/`usp_actualizar_grupo` deben rechazar un titular sin vínculo activo al programa (cambio pequeño, compatible con HU076B). Si el owner quiere (c), se agrega validación y mensaje `DOC_008`. |
| **D13** | Contraseña inicial y carga masiva. | (a) La contraseña la asigna el coordinador al crear (validada con `PasswordRegistroRule`, hash en DB, texto plano solo hacia Keycloak); **sin flujos de cambio/recuperación/correo de activación** (DA-5); **sin carga masiva** (sin CSV/Excel). (b) Contraseña por defecto derivada del documento. | **(a)**. El patrón HU120 tiene una contraseña por defecto `UcoCoord_<doc>!` — **no se replica** (predecible). |
| **D14** | Docente creado (nuevo) cuya cuenta Keycloak falló (D10) y que el coordinador necesita reintentar. | (a) El reintento del mismo `POST` en modo nuevo devuelve `DOC_003` (persona existe) → el coordinador debe usar "vincular existente"; pero el candidato solo lista docentes de otros programas. (b) Hacer que el modo nuevo con documento+correo coincidentes con un docente **ya vinculado a este programa** y **sin cuenta** reintente solo el aprovisionamiento (idempotente). (c) Incluir en candidatos al docente de este programa con flag `sinCuenta`. | **(b)**: el use case, ante `DOC_006`/`DOC_003` con la misma persona vinculada a este programa, reintenta `crearCuenta` (idempotente por `idUsuario`) y responde 200 con el mensaje de catálogo. Se prueba en T-091-17. Pendiente de confirmación del owner. |

---

## 9. Riesgos y dependencias

| ID | Riesgo | Mitigación |
|---|---|---|
| R1 | Archivos calientes compartidos con otras pistas | §7: beans en otros wirings; calientes en commit final aparte; D6 al final |
| R2 | Datos actuales: hay docentes con grupos pero sin `DocentePrograma` y desaparecerían del directorio nuevo | La migración **rellena** `DocentePrograma` con los pares (docente, programa) que hoy existen vía grupos, con el tipo de vinculación por defecto que defina el owner (D2) y `estado = 1`. Es idempotente y tiene prueba (T-MIG-02) |
| R3 | El cambio `VAL_006` → `DOC_002` podría romper una prueba que asierte el código | Verificado el 2026-10-21: ninguna prueba de `test/` asierta `VAL_006` para docentes (el único uso es `test_usp_sincronizar_usuario.sql:175`, que es de correo y no cambia). Riesgo bajo; se reconfirma en el RED |
| R4 | Keycloak cae después del commit en DB: la vinculación queda sin cuenta | Error controlado (`InternalApplicationException`) + log `ERROR`. TD-015 cubre la reconciliación (IAM-001); ver D10. Reintentar la misma alta es idempotente: el usuario ya existe y `crearCuenta` lo encuentra por `idUsuario` |
| R5 | `Usuario.numeroIdentificacion INT` (máximo 2.147.483.647) no admite todos los documentos | Se valida el rango en el validator (400 con mensaje) y se registra como deuda transversal en REG-000 §6. No se altera `Usuario` |
| R6 | Persona que ya existe como usuario con otro rol (p. ej. un coordinador que también dicta clases) | El modo nuevo detecta el documento o correo existente → `DOC_003` ("La persona ya está registrada; use la opción de vincular docente existente"). Para un usuario que no es docente, el modo existente también acepta `@idUsuario`: crea el `Docente` y asegura el rol `DOCENTE` en Keycloak (CONTRACT §2.3) |
| R7 | Concurrencia: dos coordinadores vinculan al mismo docente nuevo a la vez | `UNIQUE (docente, programa)` + `usp_sincronizar_usuario_interno`, que ya serializa la unicidad con `UPDLOCK, HOLDLOCK`. Hay prueba de concurrencia |

**Dependencias:** HU022 ✔ (tipos de identificación), HU076B ✔ (asignación a grupo `idDocente`), HU120 ✔ (patrón de aprovisionamiento IAM). No depende de la pista A (el seed ya trae programa con coordinador) ni de IAM-001/E (`crearCuenta` y `asignarRol` ya existen). **HU092 (correo) y la deshabilitación de cuenta en HU093 sí dependerían de IAM-001**; por eso quedan fuera (D11, D12).

---

## 10. Test plan

Ver [TEST_PLAN.md](TEST_PLAN.md). Secuencia RED → GREEN → VALIDATE por repo y en orden DB → Backend → Frontend.

---

## 11. Secuencia de ejecución (TDD DB → Backend → Frontend, por tandas)

Ramas `feature/HU062-HU093-docentes-coordinacion` en `.worktrees/{db,backend,frontend}-docentes`. Se implementa en **tres tandas**; cada una cierra RED → GREEN → AUDIT en los tres repos antes de la siguiente.

| Tanda | HU | Contenido | Orden de commits atómicos (`Refs:` + trailer Co-Authored-By) |
|---|---|---|---|
| 1 | HU062/HU089/HU063/HU090/HU091 | DDL + seed + backfill, vistas, `usp_vincular_docente_programa`, consultas, `GET/POST /coordinador/docentes`, `GET …/candidatos`, `GET /tipos-vinculacion`, UI | DB: `test(db/sp)` RED → `feat(db/tables)` → `feat(db/seed)` → `feat(db/views)` → `feat(db/sp)` ×2 → `fix(db/sp)` (DOC_002) → (D7) `refactor(db/sp)`. Back: `test(backend/usecase)` RED → `feat(backend/ports)` → `feat(backend/adapter)` → `feat(backend/usecase)` → `feat(backend/controller)`. Front: `test(frontend/coordinador)` RED → `feat(frontend/coordinador)` → `refactor(frontend/coordinador)` |
| 2 | HU092 | `usp_actualizar_docente_programa`, `PUT /coordinador/docentes/{idDocente}`, modal de edición | mismo orden por repo |
| 3 | HU093 | `usp_cambiar_estado_docente_programa`, `PATCH …/{idDocente}/estado`, switch con confirmación; validación del titular activo en grupos (D12) | mismo orden por repo |
| Final | Todas | Calientes en commit aparte por repo: `RbacSecurityFilterChainTest`, `test_suite.sql`, `test_contract_closure.sql`, `04_mensaje.sql` (si no se pudo antes), `HTTP_AS_IS_MATRIX.md`, `HU-CATALOG.md`; (D6) retiro de endpoints legacy en 501; `VALIDATION.md` y `CLOSURE.md`; `infra.ps1 verify` | `docs(...)`, `test(...)`, `refactor(backend/controller)` |

Gates por tanda: `test_suite.sql` en contenedor propio, `.\mvnw.cmd test` (+ `verify -Pintegration` para ITs), `ng test` / `npm run test:ci`, `ng build`, E2E con JWT real (`scratch/test_hu091.ps1`, `test_hu092.ps1`, `test_hu093.ps1`, Keycloak/Backend/Front en **puertos distintos de 8080/4200**), `infra.ps1 verify`. Cobertura del código nuevo ≥ 80 % (Sonar); use cases/validators al 100 % de ramas.

---

## 12. Rollback y stop conditions

- **Rollback:** revertir los PRs Front → Back → DB. Migración `down`. El retiro de D6 y D7 son commits aislados y reversibles.
- **CONTRACT_CONFLICT:** aparece un consumidor real de `POST /docentes`, `/docentes/asignaciones/grupo` o del SP autónomo.
- **TEST_CONTRACT_CONFLICT:** R3 u otra prueba existente que cambie de expectativa (p. ej. validación de titular activo en grupos, D12): se documenta y lo aprueba el owner.
- **BLOCKED_BY_MISSING_EVIDENCE:** Keycloak local no permite el E2E (queda `VALIDATION_BLOCKED_BY_ENVIRONMENT` solo para el E2E).

---

## 13. Deuda conocida y validación manual

- **Cierra:** TD-013 para docentes, endpoints 501 de alta/estado/edición de docente, GUID quemado en el front, mensaje `VAL_006` incorrecto, SP autónomo sin RBAC (D7).
- **Registra:**
  - **TD nueva:** `GET /api/v1/docentes` y `GET /api/v1/docentes/{id}` sin ámbito institucional (`DocenteJpaRepository.consultarDocentes()`).
  - **TD nueva:** `Usuario.numeroIdentificacion INT` (R5), transversal.
  - **TD nueva (D11):** nombres editados en DB no se propagan a Keycloak hasta IAM-001.
  - TD-015 (Keycloak después del commit) sigue abierta → IAM-001 D3 / D10 aquí.
- **Validación manual (MV):** con `coordinador.sistemas`:
  1. Directorio con los docentes migrados (R2).
  2. Alta de un docente nuevo con contraseña → login del docente.
  3. Vincular a `maria.rostagno` desde otro programa con el picker.
  4. Vincularla dos veces (409).
  5. Buscar por prefijo de cédula y por nombre.
  6. Asignar el docente nuevo a un grupo (HU076B).
  7. HU092: cambiar tipo de vinculación y nombres.
  8. HU093: inactivar → deja de aparecer como titular elegible; reactivar.

---

## 14. Definition of Ready (DoR)

| Criterio DoR | Estado | Evidencia / pendiente |
|---|---|---|
| 1. Objetivo y alcance delimitados | ✅ | §1, §4 |
| 2. AS-IS con evidencia | ✅ | §2, verificado 2026-10-22 sobre `develop` @ `4ff37ff` |
| 3. Contratos identificados | ✅ (borrador) | [CONTRACT.md](CONTRACT.md) `DRAFT` |
| 4. Matriz de pruebas TDD inicial | ✅ | [TEST_PLAN.md](TEST_PLAN.md) |
| 5. Sin conflictos con contratos WORM | ✅ | No toca el golden path ni el baseline DB |
| 6. Decisiones del owner resueltas | ❌ | D1–D14 (D1/D2 implican DDL; D10/D12/D14 definen comportamiento) |
| 7. Dependencias cerradas | ✅ | Sin dependencia de A ni de IAM-001 |
| 8. Archivos calientes | ✅ (diferidos) | Commit final aparte |
| 9. Plan de rollback viable | ✅ | §12 |

**Dictamen DoR:** 👉 **`NOT_READY`**: pendiente solo de la aprobación del owner sobre D1–D14.
