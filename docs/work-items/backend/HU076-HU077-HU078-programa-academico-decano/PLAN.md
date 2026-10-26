---
status: frozen-implemented
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# PLAN — HU076 / HU077 / HU078: Alta, modificación y estado del Programa Académico (Rol Decano)

Fase 01: Planificación y Definition of Ready (DoR), según `GUIA_METODICA_IMPLEMENTACION_HU.md`, `HOJA_DE_RUTA_JERARQUIA_ROLES.md`, `docs/governance/DEFINITION_OF_READY.md` y `AGENTS.md`.
Programa padre: [`REG-000`](../REG-000-programa-registro-vinculacion-roles/PLAN.md), grupo **A**.

---

## 1. Identidad y objetivo

- **Historias de usuario:**
  - **HU076**: Agregar un programa académico nuevo a la facultad.
  - **HU077**: Modificar la modalidad y la jornada de un programa.
  - **HU078**: Activar o desactivar un programa.
  - **HU108** (solo el listado de programas; la parte de planes queda fuera) y **HU023/HU154** (solo leer el catálogo de tipos de programa para el selector). Se incluyen porque sin ellas HU076 no tiene UI usable (decisión D6).
- **Work Item ID:** `HU076-HU077-HU078-programa-academico-decano`
- **Fecha:** 2026-10-21
- **Base Git:** `develop` @ `4ff37ff` (re-verificado el 2026-10-22). Worktrees propios `.worktrees/<repo>-hu076-hu077-hu078`, rama `feature/HU076-HU077-HU078-programa-academico` en DB, Backend y Frontend.
- **Actor:** Decano de Facultad (`DECANO`). El `ADMINISTRADOR` solo puede leer, si se aprueba en D9.
- **Jerarquía:** Nivel 2, Decano ➔ Programa Académico ➔ Coordinador. Cierra el vínculo **programa↔coordinador** que HU120 dejó preparado (coordinadores "disponibles" con `idPrograma = NULL`).

### Criterios de aceptación

| ID | Criterio |
|---|---|
| CA-01 | El decano crea un programa en **su** facultad con nombre, tipo de programa (catálogo `TipoPrograma`) y un coordinador **disponible** de su facultad. Queda activo y aparece en `GET /api/v1/decano/programas`. |
| CA-02 | Al crear el programa, el coordinador elegido queda vinculado a él y ya no se ofrece como "disponible" en `GET /api/v1/decano/coordinadores`. |
| CA-03 | No se puede crear un programa en una facultad ajena, con un coordinador de otra facultad, con un coordinador que ya tiene programa, con un tipo de programa inexistente o inactivo, ni con un nombre repetido dentro de la misma facultad. Cada caso devuelve un error con mensaje de catálogo (`exitoso=false`, HTTP 4xx). |
| CA-04 | El decano modifica nombre, modalidad y jornada (HU077) y, si quiere, reasigna el coordinador a otro disponible de su facultad. El coordinador anterior vuelve a quedar disponible. |
| CA-05 | El decano activa o desactiva un programa de su facultad (HU078). Un programa inactivo no se ofrece en los selectores operativos y se rechaza su desactivación si tiene grupos activos en el período vigente (D4). |
| CA-06 | El listado `GET /api/v1/decano/programas` es paginado, se puede filtrar por nombre, estado y tipo, y solo muestra programas de la facultad del decano. |
| CA-07 | En el front, `CatalogService.getProgramasAcademicos()` deja de devolver datos quemados y usa el endpoint real. El selector de programa de `dean-coordinadores` muestra los programas reales. |
| CA-08 | Toda mutación es atómica (`SET XACT_ABORT ON` + transacción + rollback): una falla no deja un programa a medias ni un coordinador mal vinculado. |

---

## 2. AS-IS (evidencia) vs. TARGET

| Dimensión | AS-IS (evidencia) | TARGET |
|---|---|---|
| **Tabla `dbo.Programa`** | `GestioAsistenciaDB/schema/tables/Programa.sql`: `id`, `facultad`, `tipoDePrograma`, `nombre NVARCHAR(50)`, `coordinador NOT NULL`, `estado BIT`. **No tiene `modalidad`, `jornada` ni `codigo`.** FKs a `Facultad`, `TipoPrograma` y `Coordinador` (`tables/zz_foreign_keys.sql` §10–12). | Sin cambio estructural para HU076/HU078. HU077 exige DDL (decisión **D3**): catálogos `Modalidad` y `Jornada` y columnas FK *nullable* en `Programa`, mediante un script de migración idempotente. |
| **SP `usp_crear_programa_academico`** | `schema/stored-procedures/usp_crear_programa_academico.sql`: (1) recibe `@codigo INT` y **no lo usa**; (2) `@nombre NVARCHAR(100)` para una columna de 50; (3) `ufn_obtener_parametro_guid(@x,'GENERAL','GUID_DEFECTO_CORRELACION')` sustituye `NULL` por un GUID por defecto; (4) **UPSERT por `id` O por nombre** (`LOWER(nombre)=LOWER(@nombre)`), así que un nombre repetido *pisa* un programa existente, incluso de otra facultad; (5) **no valida** que existan la facultad, el tipo ni el coordinador, ni que el coordinador sea de la facultad o esté libre; (6) la titularidad se salta si `@idFacultad` es NULL; (7) **sin `SET XACT_ABORT ON` ni transacción**; (8) con RBAC `DECANO` y la tupla canónica de 4 columnas. Prueba existente: `test/test_reactive_academic.sql` (líneas 35 y 55, uso como fixture). | Se reescribe como fachada **solo de alta** (sin upsert), con el patrón transaccional de `usp_crear_coordinador.sql` (`@@TRANCOUNT` inicial, `BEGIN TRAN` / `SAVE TRANSACTION`, rollback seguro en el `CATCH`) + `SET XACT_ABORT ON`. Delega en internos: `usp_validar_programa_academico_interno` (existencia y estado de facultad, tipo y coordinador; coordinador de la misma facultad y **libre** con `UPDLOCK, HOLDLOCK`; nombre único por facultad) e `usp_insertar_programa_academico_interno`. Se elimina `@codigo` (D7). |
| **SP de modificación / estado** | No existen. | `usp_actualizar_programa_academico` (HU077: nombre, modalidad, jornada, reasignación de coordinador) y `usp_cambiar_estado_programa_academico` (HU078). Ambos transaccionales, con RBAC `DECANO` + titularidad `FACULTAD` y la tupla canónica. |
| **Consulta paginada** | `uv_programa` (sin modalidad, jornada ni tipo) y `uv_auth_programa` (filtro por contexto del ejecutor). No existe `usp_consultar_*` de programas. | `usp_consultar_programas_academicos` sobre `uv_auth_programa` (ámbito forzado en DB) con `@numeroPagina`, `@tamanoPagina`, filtros `@nombre`, `@estaActivo`, `@idTipoPrograma` y `OFFSET/FETCH` + `COUNT(*) OVER() AS totalRegistros`, siguiendo `usp_consultar_grupos_paginado.sql`. `uv_programa` y `uv_auth_programa` exponen `idTipoPrograma`, `nombreTipoPrograma` y (con D3) modalidad y jornada. |
| **Catálogo tipo de programa** | `TipoPrograma` (`pregrado`/`PRE`, `postgrado`/`POS`; `seed/05_tipo_programa.sql`), vista `uv_tipo_programa`. Sin endpoint (HU023/HU154 `[PARCIAL]`). Patrón de catálogo existente: `controller/tipoidentificacion/TipoIdentificacionController.java` (`GET /api/v1/tipos-identificacion` → `List<TipoIdentificacionDTO>`). | Lectura `GET /api/v1/tipos-programa` (solo activos) con el mismo patrón (`controller/tipoprograma/TipoProgramaController`, feature `application/features/tipoprograma/consultartiposprograma`). La administración del catálogo (HU154) queda fuera. |
| **Seguridad HTTP** | `SecurityConfig.java:134`: `/api/v1/decano/**` → `hasAnyRole("DECANO","ADMINISTRADOR")`; `:198`: `/api/v1/**` → `authenticated()`. | **No hace falta una regla nueva** para `/decano/programas/**` ni para `/tipos-programa` (cubiertos por los comodines existentes). El ámbito se fuerza en el use case: si el actor no tiene facultad de decano (`findFacultadIdByDecanoUsuario` vacío, p. ej. un ADMINISTRADOR) → `403`. Solo se agregan casos a `RbacSecurityFilterChainTest`. |
| **Backend: puertos y casos de uso** | No existen `Programa*CommandPort`, `Programa*QueryPort` ni features `decano/*programa*`. `DecanoPortalController` (`infrastructure/adapter/primary/controller/decano/DecanoPortalController.java`) solo expone coordinadores. `InstitutionalScopePort.findFacultadIdByDecanoUsuario` ya existe. | Features `application/features/decano/{crearprograma, actualizarprograma, cambiarestadoprograma, consultarprogramas}` con la estructura de `decano/crearcoordinador` (primaryports/{dto, interactor, mapper}, usecase/{domain, impl, mapper}). Puertos `secondaryports/academic/ProgramaAcademicoCommandPort` y `ProgramaAcademicoQueryPort` (+ `projection/ProgramaAcademicoProjection`). Adapter `ProgramaAcademicoJpaRepository` (comandos con `JpaProcedureExecutor`; consulta paginada con native `EXEC` + `SpProgramaAcademicoPaginadoEntity`). Wiring explícito con `@Bean` en `DecanoWiringConfiguration`. |
| **Backend: HTTP** | No hay rutas de programa. | `GET/POST /api/v1/decano/programas`, `PUT /api/v1/decano/programas/{id}`, `PATCH /api/v1/decano/programas/{id}/estado`, `GET /api/v1/tipos-programa`. Detalle en [CONTRACT.md](CONTRACT.md). |
| **Frontend** | `core/services/catalog.service.ts`: `getProgramasAcademicos()` devuelve **4 programas quemados** con ids `PROG-01…04` (no son UUID). `dean-coordinadores.component.ts:443` los usa en el selector, así que asignar uno de ellos falla en el backend. `features/dean/dean-programas/dean-programas.component.ts` (ruta `decano/programas`, OnPush) solo lista planes con `CoordinatorManagementService.getPlanesEstudio()`. La fila HU076 del catálogo nombra `DeanFacultyComponent`, que hoy es un **archivo caliente** (archivo caliente). | Nuevo `core/services/dean-programas.service.ts` (Signals). `DeanProgramasComponent` muestra la tabla paginada de programas (`PaginationComponent`) con acciones Crear, Editar y Activar/Desactivar en modales standalone OnPush con `input()` / `output()`. `CatalogService.getProgramasAcademicos()` consume `GET /decano/programas` (o se reemplaza su uso). `DeanFacultyComponent` solo mantiene su enlace a `/app/decano/programas` (D5). |
| **Realtime** | Nada. | Según D8 (recomendado: sin evento). Si se aprueba, `PROGRAMA_ACADEMICO_ACTUALIZADO` por SSE (`/api/v1/realtime/stream`). |

---

## 2.1 Verificación AS-IS del 2026-10-22 (contra `develop` y la rama `feature/HU117-HU110-HU111-gestion-facultad`)

Resultado: el borrador **se confirma en lo esencial** (tabla `Programa`, SP de alta fuera de norma, sin SP de modificación/estado/consulta, sin endpoints, 4 programas quemados en el front, comodín `/api/v1/decano/**` ya existente). Correcciones aplicadas a estos documentos:

| # | Hallazgo | Corrección |
|---|---|---|
| V1 | El repo **no usa** el prefijo `usp_internal_*`; la convención real (HU116/HU110/HU111) es `usp_<accion>_<entidad>_interno` (`usp_cambiar_estado_facultad_interno`, `usp_crear_facultad_interno`). | Internos: `usp_validar_programa_academico_interno`, `usp_insertar_programa_academico_interno`, `usp_actualizar_programa_academico_interno`, `usp_cambiar_estado_programa_academico_interno`. |
| V2 | El patrón de referencia correcto es `usp_cambiar_estado_facultad.sql` / `_interno.sql` (HU110/111): la fachada valida (correlación, ejecutor, RBAC, existencia, reglas) y el interno abre la transacción con `SET XACT_ABORT ON`, `@@TRANCOUNT` inicial, `BEGIN TRAN`/`SAVE TRANSACTION`. `usp_crear_coordinador.sql` (develop) usa savepoint pero **no** declara `XACT_ABORT`. | Se sigue el patrón de facultad. **Savepoint ≤ 32 caracteres** (hallazgo de HU111): `sp_crear_programa_academico`, `sp_actualizar_programa`, `sp_cambiar_estado_programa`. |
| V3 | Los SP de facultad reciben todos los parámetros con `= NULL` y validan los obligatorios con `GEN_002`. | Igual aquí. La relectura del coordinador con `UPDLOCK, HOLDLOCK` va **dentro de la transacción** (en el interno de alta/edición), no en la fachada. |
| V4 | `FAC_001`, `DEC_001`, `FAC_002` y su mapeo en `DbFailureClassifier` existen **solo en la rama HU117-HU110-HU111**, no en `develop`. `PROG_001` sí está en `develop`. | `DbFailureClassifier` y `04_mensaje.sql` son calientes: se editan al final, en commit aparte (D10). |
| V5 | **No existe `ApiPageResponse<T>`** en el código (solo `ApiListResponse<T>{exitoso,datos,total}`, `ApiDataResponse<T>`, `ApiMessageResponse`), aunque AGENTS.md lo nombra. | Se mantiene `ApiListResponse` con `total = totalRegistros` (D11). |
| V6 | `Grupo` no referencia a `Programa`: el vínculo es `Grupo → Asignatura → SemestrePlanEstudio → PlanEstudio → Programa`. "Período vigente" ya está resuelto en `uv_grupo.grupoEstaHablitado`. | D4 se evalúa con `uv_grupo` + la cadena de planes, sin lógica de fechas propia. |
| V7 | `uv_coordinador` (HU120) hace `LEFT JOIN uv_programa`: "coordinador disponible" = `idPrograma IS NULL`; `estaActivoCoordinador` pasa a 0 si el programa está inactivo. `Coordinador` no tiene columna de programa: el vínculo vive solo en `Programa.coordinador` (NOT NULL). | D1(a)/D2(a) no requieren DDL. Al desactivar un programa el coordinador sigue vinculado (D12). |
| V8 | No hay runner de migraciones incrementales (`migrations/` solo tiene 4 scripts históricos); `deploy_schema.ps1` reproduce el esquema desde `schema/**`. No existen `Modalidad` ni `Jornada`. | Con D3(a): tablas nuevas en `schema/tables/` + seed; la columna nueva en `Programa.sql` con bloque `IF COL_LENGTH ... ADD` idempotente. Sin `migrations/<nn>_*.sql`. |
| V9 | No hay `unavailable(...)` para programas: `DecanoPortalController` solo tiene `unavailable("cambiar estado de coordinador")` (HU122) y `AdminPortalController` no expone programas. | Las rutas son nuevas; nada que reemplazar. |
| V10 | `InstitutionalScopePort.findFacultadIdByDecanoUsuario` y `ForbiddenException` existen. Front: `dean-programas` solo lista planes; `dean-coordinadores.component.ts:443` usa `catalogService.getProgramasAcademicos()` con ids `PROG-01…04`. | Sin cambios al TARGET. |
| V11 | HU110/111/117 (rama de facultad) aún no está en `develop`. | D10. |

---

## 3. Clase de cambio y perímetro de rutas

- **Change class:** `BEHAVIOR_CHANGE` (+ `CONTRACT_CHANGE` aditivo en HTTP y DB; + DDL si se aprueba D3).
- **PRIMARY_VARIABLE:** ciclo de vida del Programa Académico gestionado por el Decano y su vínculo con el Coordinador.
- **ALLOWED_PATHS:**
  - `GestioAsistenciaBackend/docs/work-items/HU076-HU077-HU078-programa-academico-decano/**`
  - `GestioAsistenciaDB/schema/stored-procedures/usp_crear_programa_academico.sql`
  - `GestioAsistenciaDB/schema/stored-procedures/usp_actualizar_programa_academico.sql` (nuevo)
  - `GestioAsistenciaDB/schema/stored-procedures/usp_cambiar_estado_programa_academico.sql` (nuevo)
  - `GestioAsistenciaDB/schema/stored-procedures/usp_consultar_programas_academicos.sql` (nuevo)
  - `GestioAsistenciaDB/schema/stored-procedures/usp_validar_programa_academico_interno.sql` y `usp_insertar_programa_academico_interno.sql` (nuevos)
  - `GestioAsistenciaDB/schema/views/uv_programa.sql`, `uv_auth_programa.sql`
  - `GestioAsistenciaDB/schema/seed/04_mensaje.sql` (códigos nuevos `PROG_*`) y, con D3, `schema/seed/<nn>_modalidad_jornada.sql`
  - `GestioAsistenciaDB/schema/tables/{Modalidad,Jornada,Programa}.sql` (solo con D3 aprobada; sin runner de migraciones, V8)
  - `GestioAsistenciaDB/test/test_usp_crear_programa_academico.sql`, `test_usp_actualizar_programa_academico.sql`, `test_usp_cambiar_estado_programa_academico.sql`, `test_usp_consultar_programas_academicos.sql` (nuevos); `test/test_reactive_academic.sql` (solo para adaptar la llamada si cambia la firma, ver riesgo R2)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/features/decano/{crearprograma,actualizarprograma,cambiarestadoprograma,consultarprogramas}/**`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/features/tipoprograma/consultartiposprograma/**` (nuevo)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/tipoprograma/TipoProgramaController.java` (nuevo)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/academic/ProgramaAcademico*Port.java` y `projection/ProgramaAcademico*Projection.java`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/jpa/{repository/ProgramaAcademicoJpaRepository.java, entity/SpProgramaAcademicoPaginadoEntity.java, entity/UvTipoProgramaEntity.java}`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/decano/{DecanoPortalController.java, request/*Programa*Request.java, response/*Programa*Response.java, mapper/*Programa*HttpMapper.java, validation/*Programa*Validator.java}`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/wiring/DecanoWiringConfiguration.java` y `TipoProgramaWiringConfiguration.java` (nuevo, patrón de `TipoIdentificacionWiringConfiguration`)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` (códigos `PROG_002…008`, `PAG_001`)
  - `GestioAsistenciaDB/schema/seed/03_parametro.sql` (parámetro `PAGINACION / TAMANO_MAXIMO`)
  - `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/**` (tests nuevos del perímetro y `RbacSecurityFilterChainTest` ⚠️)
  - `SecurityConfig.java` **no** está permitido: si el RED de seguridad demostrara que hace falta una regla, se amplía este PLAN con aprobación (archivo caliente §7)
  - `GestioAsistenciaBackend/docs/contracts/HTTP_AS_IS_MATRIX.md` ⚠️ (fase 06)
  - `GestioAsistenciaFrontend/src/app/core/services/dean-programas.service{,.spec}.ts` (nuevo), `core/services/catalog.service{,.spec}.ts`
  - `GestioAsistenciaFrontend/src/app/core/models/programa-academico.model.ts` (nuevo)
  - `GestioAsistenciaFrontend/src/app/features/dean/dean-programas/**` (incluye modales nuevos en `components/`)
  - `GestioAsistenciaFrontend/src/app/features/dean/dean-coordinadores/dean-coordinadores.component{,.spec}.ts` (solo el origen del selector de programa)
- **FORBIDDEN_PATHS:**
  - `GestioAsistenciaBackend/docs/contracts/openapi/**`, `BACKEND_GOLDEN_PATH_CONTRACT.*`, `docs/contracts/external/db/**` (WORM: esta HU no entra al golden path)
  - `GestioAsistenciaDB/schema/tables/**` (se excepciona **solo** con D3 aprobada y por migración)
  - `GestioAsistenciaFrontend/src/app/features/dean/dean-faculty/**`, `dean-infraestructura/**` (archivos calientes)
  - Cualquier archivo de HU035/HU036 (reclamos)
  - `AsistenciasUCO-Infra/**` hasta la fase 06
- **CONTRACTS:** HTTP aditivo (rutas nuevas fuera del golden path); DB con firma nueva de `usp_crear_programa_academico` (ver R2), SPs y vistas nuevos.
- **PROVIDERS:** SQL Server (JPA), App Configuration (mensajes `messages:user:PROG_*` con fallback en catálogo), SSE local.
- **EXTERNAL_ENVIRONMENT:** contenedor `sql_server_asistencias`, Keycloak `:8081` (solo para el E2E con el token del decano).
- **SECURITY_IMPACT:** rutas nuevas bajo `/api/v1/decano/**`, que hoy admite `DECANO` y `ADMINISTRADOR` (`SecurityConfig.java:134`). El use case rechaza con 403 a quien no tenga facultad de decano (D9). Ámbito en dos capas: `InstitutionalScopePort.findFacultadIdByDecanoUsuario` en el use case y `usp_validar_titularidad_jerarquica_interno` / `uv_auth_programa` en DB. No aplica IAM: no se crean cuentas.
- **OBSERVABILITY_IMPACT:** `CorrelationIdContext.get()` propagado como `@idCorrelacion` en todos los SP; logs JSONL de los use cases con `correlationId`; sin métricas nuevas.
- **TEST_LEVEL_REQUIRED:** T-SQL transaccional + JUnit unit/slice/wiring/ArchUnit + IT contra SQL Server + Jasmine + E2E script.
- **ROLLBACK:** revertir el PR de cada repo en orden inverso (Front → Back → DB). Para la migración D3, script `down` idempotente (`DROP COLUMN` de las columnas nullable nuevas y de los catálogos).
- **CONSUMERS:** portal Decano (`dean-programas`, `dean-coordinadores`); a futuro WI-B (el coordinador del programa vincula docentes) y WI-H (reasignación del coordinador).
- **STOP_CONDITIONS:** D1–D12 sin resolver; conflicto de rebase en un archivo caliente que no se resuelva de forma aditiva; cualquier prueba existente (p. ej. `test_reactive_academic.sql`) que solo pase relajándola → `TEST_CONTRACT_CONFLICT`.

Lo que no está en ALLOWED_PATHS no se modifica. Ampliar el alcance exige actualizar este PLAN con aprobación.

---

## 4. Alcance y no alcance

### Alcance
1. **DB:** reescribir `usp_crear_programa_academico` con la norma; crear los SPs de actualización, estado y consulta paginada y los internos de validación e inserción; ampliar `uv_programa` / `uv_auth_programa`; códigos de mensaje `PROG_*`; DDL de modalidad y jornada si se aprueba D3; pruebas T-SQL por SP.
2. **Backend:** 4 features del decano + 1 de catálogo; puertos y adapter JPA; endpoints en `DecanoPortalController` y un controlador de catálogo; reglas en `SecurityConfig`; evento SSE; pruebas.
3. **Frontend:** servicio y modelo nuevos; pantalla de programas en `dean-programas` con alta, edición, estado y paginación; reemplazo de los programas quemados en `CatalogService` y en el selector de `dean-coordinadores`; specs.

### No alcance
1. Planes de estudio (HU079–HU083, ya del coordinador), registro calificado y suspensión de oferta (HU112–HU114), árbol Facultad→Programa→Plan (HU119).
2. Administrar el catálogo de tipos de programa (HU154, escritura).
3. Alta de coordinador (HU120 ✔) y su edición o estado (HU121/HU122 → WI-H).
4. Borrado físico de programas.

---

## 5. Archivos afectados

### Existentes (ruta comprobada)
- `GestioAsistenciaDB/schema/tables/Programa.sql` (solo lectura, salvo D3)
- `GestioAsistenciaDB/schema/stored-procedures/usp_crear_programa_academico.sql`
- `GestioAsistenciaDB/schema/views/uv_programa.sql`, `uv_auth_programa.sql`, `uv_tipo_programa.sql`, `uv_coordinador.sql` (lectura)
- `GestioAsistenciaDB/schema/seed/04_mensaje.sql`, `05_tipo_programa.sql`
- `GestioAsistenciaDB/test/test_reactive_academic.sql`, `test_suite.sql` ⚠️
- Referencias de patrón: `schema/stored-procedures/usp_crear_coordinador.sql` (transacción y savepoint), `usp_consultar_grupos_paginado.sql` (paginación con contexto de ejecutor)
- `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/decano/DecanoPortalController.java`
- `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/wiring/DecanoWiringConfiguration.java`
- `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/security/InstitutionalScopePort.java` (lectura)
- Patrón de feature: `application/features/decano/crearcoordinador/**`; patrón de adapter: `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/CoordinadorJpaRepository.java`
- `GestioAsistenciaFrontend/src/app/core/services/catalog.service.ts`, `dean-management.service.ts` (lectura)
- `GestioAsistenciaFrontend/src/app/features/dean/dean-programas/dean-programas.component{,.spec}.ts`
- `GestioAsistenciaFrontend/src/app/features/dean/dean-coordinadores/dean-coordinadores.component{,.spec}.ts`

### Nuevos (propuesta)
- DB: los 5 SPs listados en §3, las 4 pruebas `test_usp_*` y, con D3, la migración y el seed de catálogos.
- Backend:
  - `application/features/decano/crearprograma/**`, `actualizarprograma/**`, `cambiarestadoprograma/**`, `consultarprogramas/**`
  - `application/features/catalogo/consultartiposprograma/**`
  - `application/secondaryports/academic/ProgramaAcademicoCommandPort.java`, `ProgramaAcademicoQueryPort.java`, `TipoProgramaQueryPort.java`, `projection/ProgramaAcademicoProjection.java`, `projection/TipoProgramaProjection.java`
  - `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/ProgramaAcademicoJpaRepository.java`, `TipoProgramaJpaRepository.java`, `entity/SpProgramaAcademicoPaginadoEntity.java`, `entity/UvTipoProgramaEntity.java`
  - `infrastructure/adapter/primary/controller/decano/request/{CrearProgramaRequest, ActualizarProgramaRequest, CambiarEstadoProgramaRequest}.java`, `response/ProgramaAcademicoResponse.java`, `mapper/ProgramaAcademicoHttpMapper.java`, `validation/ProgramaAcademicoRequestValidator.java`
  - `infrastructure/adapter/primary/controller/tipoprograma/TipoProgramaController.java` (patrón de `TipoIdentificacionController`)
  - Tests: ver [TEST_PLAN.md](TEST_PLAN.md)
- Frontend: `core/services/dean-programas.service{,.spec}.ts`, `core/models/programa-academico.model.ts`, `features/dean/dean-programas/components/{dean-programa-form-modal, dean-programa-estado-modal}.component{,.spec}.ts`

### Retirar
- El arreglo `defaultProgramas` quemado de `CatalogService.getProgramasAcademicos()`. Antes se comprueba con Grep que no queden otros consumidores que dependan de los ids `PROG-0x`.

---

## 6. Contratos y consumidores afectados

| Tipo | Contrato | Compatibilidad | Consumidor |
|---|---|---|---|
| PERSISTENCE | `usp_crear_programa_academico`: sale `@codigo`, se elimina el upsert y aparecen validaciones nuevas | **Rompe** a quien lo invoque con `@codigo` (solo `test_reactive_academic.sql`; ningún backend lo invoca hoy, se verifica con Grep) | Backend nuevo, tests DB |
| PERSISTENCE | SPs nuevos de actualización, estado y consulta; columnas nuevas en `uv_programa` y `uv_auth_programa` | Aditivo | Backend nuevo |
| HTTP | 5 rutas nuevas (ver CONTRACT §3) | Aditivo; fuera de `openapi-golden-path.yaml` (no es golden path); se registran en `HTTP_AS_IS_MATRIX.md` | Front Decano |
| SECURITY | Sin regla nueva (comodín `/api/v1/decano/**`); ámbito forzado en el use case y en DB | Sin cambio | — |
| REALTIME | Evento `programa-academico.actualizado` | Aditivo (D8) | Front Decano |

---

## 7. Archivos calientes (coordinación entre pistas A/B/C y otros WI)

Compartidos con otras pistas (B docentes, C catálogos) y WI en curso: `SecurityConfig`, `RbacSecurityFilterChainTest`, `AdminPortalController`, los `*WiringConfiguration`, `DbFailureClassifier`, `HTTP_AS_IS_MATRIX.md`, `GestioAsistenciaDB/test_suite.sql`, `test/test_contract_closure.sql`, `schema/seed/04_mensaje.sql`, `schema/seed/03_parametro.sql` y `HU-CATALOG.md`.

**Regla:** se editan **solo al final de cada repo y en un commit aparte**, después de rebasar sobre el `develop` vigente. Todo lo demás (SPs, features, controladores nuevos, specs) va en commits previos sin tocar esos archivos. `SecurityConfig` no se modifica (el comodín existente basta). `DecanoPortalController` y `DecanoWiringConfiguration` se amplían (no los usan las pistas B/C).

`dean-faculty` y `dean-infraestructura` (front) no se tocan (D5).

---

## 8. Decisiones requeridas (bloquean READY)

| ID | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| **D1** | ¿El programa debe nacer con coordinador? `Programa.coordinador` es `NOT NULL`. | (a) Obligatorio: se elige entre los coordinadores *disponibles* de la facultad (creados con HU120). (b) Volver la columna nullable (DDL) y permitir programas sin coordinador. | **(a)**: no requiere DDL y respeta el flujo HU120 → HU076 que ya se certificó. |
| **D2** | ¿Un coordinador puede tener más de un programa? | (a) No: relación 1↔1, validada en el SP con `UPDLOCK, HOLDLOCK` sobre la vista. (b) Sí. | **(a)**: lo pide el informe de auditoría de roles ("1 Coordinador por Programa") y lo supone `InstitutionalScopePort.findProgramaIdByCoordinadorUsuario` (devuelve un solo `Optional<UUID>`). |
| **D3** | HU077 pide modalidad y jornada, pero esas columnas no existen. | (a) DDL: catálogos `Modalidad` y `Jornada` (id, codigo, nombre, estado) + columnas `modalidad` y `jornada` FK *nullable* en `Programa`, por migración idempotente + seed. (b) Columnas `NVARCHAR` libres. (c) Reducir HU077 a nombre, tipo y coordinador y diferir modalidad y jornada. | **(a)**: cumple "cero datos quemados" (estados y valores desde catálogo) y es retrocompatible porque las columnas son nullable. Hay que aprobar los valores semilla (propuesta: modalidades `PRE` Presencial, `VIR` Virtual, `HIB` Híbrida; jornadas `DIU` Diurna, `NOC` Nocturna, `FDS` Fin de semana). |
| **D4** | ¿Qué pasa al desactivar un programa? | (a) Se rechaza con 409 (`PROG_00x`) si tiene grupos activos en el período vigente; si no, se desactiva sin cascada. (b) Se desactiva siempre, sin validar. (c) Cascada sobre planes y grupos. | **(a)**: evita dejar huérfana la asistencia en curso y no toca otras entidades. El coordinador sigue vinculado. |
| **D5** | ¿Dónde vive la UI? | (a) `DeanProgramasComponent` (`/app/decano/programas`), que ya existe y no es archivo caliente. (b) `DeanFacultyComponent`, como dice la fila del catálogo. | **(a)**, y al cerrar se corrige la columna Frontend de HU076–HU078 en `HU-CATALOG.md`. |
| **D6** | ¿Se incluyen en este WI el listado (HU108, solo programas) y la lectura de tipos (HU023)? | (a) Sí. (b) No, cada una en su WI. | **(a)**: sin listado y sin selector de tipo, HU076 no tiene UI usable. |
| **D7** | `@codigo INT` en el SP no tiene columna. | (a) Quitar el parámetro. (b) Agregar columna `codigo` (DDL) única por facultad. | **(a)**, salvo que exista un código institucional (SNIES) que se deba registrar; en ese caso (b) con `NVARCHAR(20)`. |
| **D8** | ¿Evento SSE al mutar un programa? | (a) Sí, `PROGRAMA_ACADEMICO_ACTUALIZADO` (convención `UPPER_SNAKE` de `RealtimeEvent`), sin PII. Ojo: `ReactorRealtimeAdapter` no filtra por destinatario, así que el evento llega a todos los clientes. (b) No; la pantalla se refresca tras su propia mutación. | **(b)** para este WI (solo el decano de la facultad edita sus programas), y se deja anotado; **(a)** si el owner quiere reflejar el cambio en sesiones abiertas del coordinador afectado. |
| **D9** | `SecurityConfig` ya deja pasar al `ADMINISTRADOR` en `/api/v1/decano/**`. ¿Qué hace el admin en estas rutas? | (a) Solo lectura en `GET /decano/programas` con `?idFacultad=` dentro de su institución. (b) El use case lo rechaza con 403 porque no tiene facultad de decano. | **(b)** en este WI (el admin no tiene pantalla de programas y la jerarquía dice que el programa es del decano). Se revisa en WI-F. |
| **D10** | `develop` (4ff37ff) no contiene aún HU110/111/117 (`FAC_*`, `DbFailureClassifier` ampliado). ¿Sobre qué base se implementa? | (a) Ramas desde `develop`, y rebase sobre el merge de HU117-HU110-HU111 antes del commit de archivos calientes. (b) Ramas apiladas sobre `feature/HU117-HU110-HU111-gestion-facultad`. | **(a)**: no hay dependencia funcional; solo conflictos aditivos en `DbFailureClassifier` y `04_mensaje.sql`, que se tocan al final. |
| **D11** | AGENTS.md pide `ApiPageResponse<T>`, pero no existe en el código. | (a) `ApiListResponse` con `total` (como `/docente/reclamos`). (b) Crear `ApiPageResponse` (cambio transversal). | **(a)**: el envelope nuevo es transversal y afecta a las otras pistas. |
| **D12** | Al desactivar un programa su coordinador queda `estaActivoCoordinador=0` pero vinculado (no disponible). ¿Se acepta? | (a) Sí; reactivar el programa lo restaura. (b) Liberarlo al desactivar (exige `Programa.coordinador` nullable). | **(a)**. |

---

## 9. Riesgos y dependencias

| ID | Riesgo | Mitigación |
|---|---|---|
| R1 | Archivos calientes compartidos con otras pistas | §7: solo al final, en commit aparte, tras rebasar sobre `develop` |
| R2 | Al quitar `@codigo` y el upsert se rompe `test_reactive_academic.sql`, que usa el SP como fixture | Se adapta **solo la llamada** del fixture a la firma nueva (cambio de contrato formal, documentado aquí). Las aserciones del test no cambian |
| R3 | Datos actuales con nombres duplicados en la misma facultad, que harían fallar la regla de unicidad | En la fase 03, consulta previa en el contenedor; si los hay, script de saneamiento aprobado aparte |
| R4 | `ufn_obtener_parametro_guid` usado en otros SPs: cambiarlo globalmente rompe otros contratos | Solo se deja de usar en los SPs de este WI; no se toca la función |
| R5 | La paridad JDBC/JPA no aplica (feature nueva sin baseline JDBC) | Se cubre con IT directa contra SQL Server (`ProgramaAcademicoSqlServerIT`) |
| R6 | La UI del coordinador depende de `findProgramaIdByCoordinadorUsuario`: con la reasignación de HU077 el coordinador cambia de ámbito | Prueba explícita: después de reasignar, el coordinador anterior no ve el programa y el nuevo sí |

**Dependencias:** HU120 ✔ (coordinadores disponibles), HU116 ✔ (facultad), HU117-B ✔ (decano con facultad). No depende de WI-E (no gestiona cuentas).

---

## 10. Test plan

Ver [TEST_PLAN.md](TEST_PLAN.md). Secuencia RED → GREEN → VALIDATE **por repo y en orden DB → Backend → Frontend**; no se escribe código de producción antes de registrar el `RED_SNAPSHOT` del repo.

---

## 11. Secuencia de ejecución (fases 02–06)

| Fase | Repo | Rama | Commits atómicos (Conventional Commits, `Refs: HU076`, `HU077` o `HU078`) |
|---|---|---|---|
| 02 CONTRACT | Backend (docs) | `docs/plan-registro-roles` → PR propio | `docs(hus): congelar contrato HU076-HU078 programa academico` |
| 03 RED (DB) | GestioAsistenciaDB | `feature/HU076-HU077-HU078-programa-academico` | `test(db/sp): agregar pruebas red de programa academico` |
| 04 GREEN (DB) | GestioAsistenciaDB | idem | `feat(db/tables): agregar catalogos modalidad y jornada` (si D3); `feat(db/sp): reescribir usp_crear_programa_academico transaccional`; `feat(db/sp): agregar actualizacion y estado de programa`; `feat(db/views): exponer tipo modalidad y jornada en uv_programa`; `feat(db/sp): agregar consulta paginada de programas` |
| 03 RED (Back) | GestioAsistenciaBackend | `feature/HU076-HU077-HU078-programa-academico` | `test(backend/usecase): agregar pruebas red de programa academico` |
| 04 GREEN (Back) | idem | idem | `feat(backend/ports): …`, `feat(backend/adapter): …`, `feat(backend/usecase): …`, `feat(backend/controller): …`, `feat(backend/security): …` |
| 03 RED (Front) | GestioAsistenciaFrontend | `feature/HU076-HU077-HU078-programa-academico` | `test(frontend/decano): agregar specs red de programas` |
| 04 GREEN (Front) | idem | idem | `feat(frontend/decano): …`, `refactor(frontend/ui): retirar programas quemados de catalog service` |
| 05 AUDIT | los 3 | — | `VALIDATION.md` |
| 06 CLOSURE | Backend (docs) + Infra | — | `docs(hus): cerrar HU076-HU078`, actualizar `HTTP_AS_IS_MATRIX.md`, `HU-CATALOG.md` y el espejo |

Un PR por repo, aprobado por el owner antes del merge.

---

## 12. Rollback y stop conditions

- **Rollback:** revertir los PRs en orden Front → Back → DB. La migración D3 tiene su `down`. Ningún paso borra datos de producción.
- **CONTRACT_CONFLICT:** si en la fase 02 aparece un consumidor no detectado de `usp_crear_programa_academico` con `@codigo`.
- **TEST_CONTRACT_CONFLICT:** si alguna prueba existente fuera del perímetro falla por el cambio. Se documenta; nunca se relaja.
- **BLOCKED_BY_MISSING_EVIDENCE:** si no hay datos de prueba de una facultad con ≥ 2 coordinadores disponibles; se agrega un fixture en `test/fixtures/dev/`.

---

## 13. Deuda conocida y validación manual

- **Deuda que este WI cierra:** programas quemados en el front (REG-000 §6); `usp_crear_programa_academico` fuera de norma (XACT_ABORT, upsert por nombre, `@codigo` sin uso, sustitución de NULL por GUID por defecto).
- **Deuda que no toca:** TD-013/014/015 (no crea cuentas); `ufn_obtener_parametro_guid` en otros SPs (R4).
- **Validación manual (MV):** con el decano canónico (`decano.ingenieria`), crear un coordinador disponible (HU120), crear un programa con él, verificar que deja de aparecer como disponible, editar modalidad y jornada, reasignar a otro coordinador, desactivar con y sin grupos activos, y comprobar que el selector de `dean-coordinadores` muestra los programas reales.

---

## 14. Definition of Ready (DoR)

| Criterio DoR | Estado | Evidencia / pendiente |
|---|---|---|
| 1. Objetivo y alcance delimitados | ✅ | §1, §4 |
| 2. AS-IS con evidencia | ✅ | §2 (rutas comprobadas el 2026-10-21) |
| 3. Contratos identificados | ✅ (borrador) | [CONTRACT.md](CONTRACT.md) `DRAFT` |
| 4. Matriz de pruebas TDD inicial | ✅ | [TEST_PLAN.md](TEST_PLAN.md) |
| 5. Sin conflictos con contratos WORM | ✅ | No toca golden path ni el baseline DB (grep: `uv_programa` y `usp_crear_programa_academico` no figuran en `docs/contracts/**`) |
| 6. Decisiones del owner resueltas | ❌ | D1–D12 (recomendaciones en §8) |
| 7. Archivos calientes | ✅ (con regla) | §7: solo al final, en commit aparte |
| 8. Plan de rollback viable | ✅ | §12 |

**Dictamen DoR:** 👉 **`NOT_READY`**: pendiente solo de la aprobación del owner sobre D1–D12.
