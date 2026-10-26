---
status: contract-frozen
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# PLAN — HU121 / HU122: Editar y alternar el estado del Coordinador (Rol Decano)

Fase 01: Planificación y Definition of Ready (DoR), según `GUIA_METODICA_IMPLEMENTACION_HU.md`, `HOJA_DE_RUTA_JERARQUIA_ROLES.md`, `docs/governance/DEFINITION_OF_READY.md` y `AGENTS.md`.
Programa padre: [`REG-000`](../REG-000-programa-registro-vinculacion-roles/PLAN.md), grupo **H**.

---

## 1. Identidad y objetivo

- **Historias de usuario:**
  - **HU121**: Actualizar la información del Coordinador (nombres, apellidos y correo).
  - **HU122**: Alternar el estado activo/inactivo del Coordinador.
- **Work Item ID:** `HU121-HU122-gestion-coordinador`
- **Fecha:** 2026-10-21
- **Base Git:** `develop` @ `4ff37ff`
- **Actor:** Decano de Facultad (`DECANO`) sobre los coordinadores **de su facultad**.
- **Jerarquía:** Nivel 2, Decano ➔ Coordinador. Cierra el ciclo de vida del Coordinador (HU120 lo crea, HU123/HU124 lo consultan; este WI lo edita y lo activa o desactiva). El estado de la cuenta se sincroniza con Keycloak.

### Criterios de aceptación

| ID | Criterio |
|---|---|
| CA-01 | El decano edita nombres, apellidos y correo de un coordinador de su facultad. El documento y el tipo de documento no se editan. La vista y la cuenta de Keycloak reflejan los datos nuevos. |
| CA-02 | El correo nuevo no puede pertenecer a otro usuario. Un duplicado devuelve 409 con mensaje de catálogo y no cambia nada. |
| CA-03 | El decano desactiva un coordinador de su facultad (HU122). Queda inactivo en `uv_coordinador`, pierde el acceso al rol y su cuenta de Keycloak se deshabilita si no le queda ningún otro rol activo. |
| CA-04 | El decano reactiva un coordinador inactivo. Recupera el rol y la cuenta se habilita. |
| CA-05 | No se puede desactivar un coordinador que coordina un programa activo (D3): devuelve 409 con el mensaje `COO_001`. Hay que reasignar el programa antes (HU077, WI-A). |
| CA-06 | Un decano no puede ver, editar ni cambiar el estado de coordinadores de otra facultad, incluidos los coordinadores aún sin programa (D2). Un id ajeno responde 404, sin revelar que existe. |
| CA-07 | Toda mutación es atómica (`SET XACT_ABORT ON`, transacción, rollback). Si Keycloak falla **después** del commit en DB, la operación queda como éxito con advertencia (`IAM_002`) y un registro de desfase (WI-E). |
| CA-08 | La ruta del front coincide con la del backend (`PATCH /decano/coordinadores/{id}/estado`) y el front muestra `mensajeUsuario` tal cual llega. |
| CA-09 | La contraseña del coordinador se exige siempre en la creación (DA-5): desaparece la contraseña por defecto `UcoCoord_<doc>!` (D5). |

---

## 2. AS-IS (evidencia) vs. TARGET

| Dimensión | AS-IS (evidencia, 2026-10-21) | TARGET |
|---|---|---|
| **Tabla `dbo.Coordinador`** | `GestioAsistenciaDB/schema/tables/Coordinador.sql`: solo `id` y `usuario`. **No tiene `estado` ni `facultad`.** | Migración idempotente (D1, D2): `estado BIT NOT NULL DEFAULT 1` y `facultad UNIQUEIDENTIFIER NULL` con FK a `Facultad`, con relleno de `facultad` desde `Programa`. |
| **Estado del coordinador** | `uv_coordinador.estaActivoCoordinador = Usuario.estado AND (programa nulo OR programa activo)`. No existe estado propio del rol: desactivar hoy sería apagar a toda la persona. | Estado propio del rol (`Coordinador.estado`). `Usuario.estado` pasa a 0 **solo** si no le queda ningún rol activo (regla D2 de IAM-001). |
| **Ámbito de un coordinador sin programa** | `uv_coordinador.idFacultad` sale del programa, así que un coordinador sin programa no tiene facultad. `CoordinadorJpaRepository.consultarCoordinadoresSinPrograma()` (HQL `where c.idPrograma is null`) **no filtra por facultad** y `ConsultarCoordinadoresUseCaseImpl` lo mezcla en el listado de cualquier decano. | Con `Coordinador.facultad` el coordinador sin programa pertenece a una facultad. El listado y las mutaciones se filtran por ella. Corrige además la fuga actual de coordinadores ajenos en `GET /decano/coordinadores`. |
| **Datos editables en la vista** | `uv_coordinador` (archivo del repo DB) expone `nombreCompleto` pero **no** `primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido` ni `correo`, aunque `HU120/CONTRACT.md` §2.1 dice que sí. Se verifica contra la DB real en la fase 03. | La vista expone los cinco campos desde `uv_usuario`, más `estaActivoRolCoordinador`. |
| **SP de edición / estado** | No existen. Solo `usp_crear_coordinador.sql` (transaccional, con savepoint). | `usp_actualizar_coordinador` y `usp_cambiar_estado_coordinador`, fachadas transaccionales que delegan en internos (`usp_internal_validar_coordinador_de_facultad`, `usp_internal_actualizar_datos_usuario` y `usp_internal_cambiar_estado_usuario` de IAM-001). |
| **Backend: HTTP** | `DecanoPortalController`: `PATCH /api/v1/decano/coordinadores/{id}/estado` lanza `FeatureUnavailableException` (501). No existe `PUT /coordinadores/{id}`. | `PUT /api/v1/decano/coordinadores/{id}` y `PATCH /api/v1/decano/coordinadores/{id}/estado` con cuerpo `{ "estaActivo": boolean }`. |
| **Backend: puertos** | `CoordinadorCommandPort` solo tiene `crearCoordinador`. `IdentityProviderPort` solo tiene `crearCuenta`, `eliminarCuenta` y `asignarRol`. | Métodos nuevos en `CoordinadorCommandPort` (aditivos). Las operaciones de IdP salen de **IAM-001**: `deshabilitarCuenta`, `habilitarCuenta`, `actualizarDatosCuenta`, `retirarRol` y `SincronizarCuentaInstitucionalService`. |
| **Backend: creación** | `CrearCoordinadorUseCaseImpl.resolverCredencialInicial` usa `"UcoCoord_" + documento + "!"` cuando la contraseña viene vacía. | La contraseña es obligatoria (validator + use case). Se elimina la contraseña por defecto (D5). |
| **Seguridad HTTP** | `SecurityConfig.java:134`: `/api/v1/decano/**` → `hasAnyRole("DECANO","ADMINISTRADOR")`. | **No hace falta una regla nueva.** El use case rechaza con 403 a quien no tenga facultad de decano (`findFacultadIdByDecanoUsuario` vacío, p. ej. un ADMINISTRADOR; D8). |
| **Frontend** | `DeanManagementService.toggleCoordinadorStatus` llama a `PATCH …/{id}/toggle` (la ruta del backend es `…/estado`, así que **nunca coincide**). `DeanCoordinadoresComponent` tiene el botón Activar/Desactivar (`toggleEstado`) y no tiene edición. | Servicio con `updateCoordinador` y `setCoordinadorEstado`. Modal de edición standalone OnPush. El toggle usa la ruta correcta y un modal de confirmación. Los mocks (`mock-backend.interceptor.ts`, `role-management.mock.ts`) se alinean. |
| **Realtime** | Nada. | Sin evento (D9). |

---

## 3. Clase de cambio y perímetro de rutas

- **Change class:** `BEHAVIOR_CHANGE` (+ `CONTRACT_CHANGE` aditivo en HTTP y DB; + DDL por D1/D2).
- **PRIMARY_VARIABLE:** ciclo de vida del Coordinador (datos y estado) gestionado por el Decano, con su cuenta de identidad sincronizada.
- **ALLOWED_PATHS:**
  - `GestioAsistenciaBackend/docs/work-items/HU121-HU122-gestion-coordinador/**`
  - `GestioAsistenciaDB/migrations/<nn>_hu121_hu122_coordinador_estado_facultad.sql` (nuevo, con su `down`)
  - `GestioAsistenciaDB/schema/tables/Coordinador.sql` (definición para despliegues nuevos, alineada con la migración)
  - `GestioAsistenciaDB/schema/stored-procedures/usp_actualizar_coordinador.sql`, `usp_cambiar_estado_coordinador.sql`, `usp_internal_validar_coordinador_de_facultad.sql` (nuevos)
  - `GestioAsistenciaDB/schema/stored-procedures/usp_crear_coordinador.sql` (solo para fijar `Coordinador.facultad`)
  - `GestioAsistenciaDB/schema/views/uv_coordinador.sql`, `uv_coordinador_identidad.sql`, `uv_auth_coordinador.sql`
  - `GestioAsistenciaDB/schema/seed/04_mensaje.sql` (códigos `COO_*`)
  - `GestioAsistenciaDB/test/test_usp_actualizar_coordinador.sql`, `test_usp_cambiar_estado_coordinador.sql` (nuevos); `test_usp_crear_coordinador.sql` (se amplía para `facultad`)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/features/decano/{actualizarcoordinador,cambiarestadocoordinador}/**` (nuevos)
  - `.../application/features/decano/crearcoordinador/usecase/impl/CrearCoordinadorUseCaseImpl.java` (solo D5)
  - `.../application/features/decano/consultarcoordinadores/usecase/impl/ConsultarCoordinadoresUseCaseImpl.java` (filtro por facultad)
  - `.../application/secondaryports/academic/CoordinadorCommandPort.java`, `CoordinadorQueryPort.java`, `projection/CoordinadorProjection.java`
  - `.../infrastructure/adapter/secondary/persistence/sqlserver/jpa/{repository/CoordinadorJpaRepository.java, entity/UvCoordinadorEntity.java, entity/UvCoordinadorIdentidadEntity.java, mapper/AcademicViewJpaProjectionMapper.java}`
  - `.../infrastructure/adapter/primary/controller/decano/DecanoCoordinadorGestionController.java`, `request/{ActualizarCoordinadorRequest,CambiarEstadoCoordinadorRequest}.java`, `response/ResultadoGestionCoordinadorResponse.java`, `validation/*Coordinador*Validator.java` (nuevos, D10)
  - `.../infrastructure/adapter/primary/controller/decano/DecanoPortalController.java` (**solo** retirar el stub 501 de `PATCH …/estado`)
  - `.../infrastructure/config/wiring/CoordinadorGestionWiringConfiguration.java` (nuevo, D10)
  - `.../infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` (códigos `COO_*`)
  - `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/**` (tests nuevos del perímetro y `RbacSecurityFilterChainTest` ⚠️)
  - `GestioAsistenciaBackend/docs/contracts/HTTP_AS_IS_MATRIX.md` ⚠️ (fase 06)
  - `GestioAsistenciaFrontend/src/app/core/services/dean-management.service{,.spec}.ts`
  - `GestioAsistenciaFrontend/src/app/core/models/role-management.model.ts`
  - `GestioAsistenciaFrontend/src/app/core/{interceptors/mock-backend.interceptor.ts, mocks/role-management.mock.ts}` (solo la ruta y los datos del toggle)
  - `GestioAsistenciaFrontend/src/app/features/dean/dean-coordinadores/**` (incluye `components/` nuevos)
- **FORBIDDEN_PATHS:**
  - `GestioAsistenciaBackend/docs/contracts/openapi/**`, `BACKEND_GOLDEN_PATH_CONTRACT.*`, `docs/contracts/external/db/**` (WORM: esta HU no entra al golden path)
  - `SecurityConfig.java` (archivo caliente; el comodín `/decano/**` ya cubre las rutas)
  - `DecanoWiringConfiguration.java` (lo modifica WI-A; D10)
  - `GestioAsistenciaDB/test_suite.sql`, `test/test_contract_closure.sql` (archivos calientes; las pruebas van en archivos nuevos)
  - `GestioAsistenciaFrontend/src/app/features/dean/dean-faculty/**`, `dean-infraestructura/**`, `dean-programas/**` (archivos calientes / de WI-A)
  - IAM: los métodos del puerto y el servicio de sincronización **no se crean aquí** (son de IAM-001)
  - Cualquier archivo de HU035/HU036 (reclamos)
  - `AsistenciasUCO-Infra/**` hasta la fase 06
- **CONTRACTS:** HTTP aditivo (rutas nuevas fuera del golden path); DB con SPs y columnas nuevas y vistas ampliadas (aditivo); `CoordinadorCommandPort` aditivo.
- **PROVIDERS:** SQL Server (JPA), Keycloak (vía `IdentityProviderPort`, de IAM-001), App Configuration (mensajes `messages:user:COO_*` con fallback en catálogo).
- **EXTERNAL_ENVIRONMENT:** contenedor `sql_server_asistencias`, Keycloak `:8081` (E2E con el token del decano y verificación de `enabled` en el IdP).
- **SECURITY_IMPACT:** rutas nuevas bajo `/api/v1/decano/**`, que hoy admite `DECANO` y `ADMINISTRADOR`. Ámbito en dos capas: `InstitutionalScopePort.findFacultadIdByDecanoUsuario` en el use case y `usp_internal_validar_coordinador_de_facultad` + `usp_validar_titularidad_jerarquica_interno` en DB. Desactivar la cuenta en el IdP tiene efecto inmediato sobre nuevos logins; los tokens ya emitidos expiran según D5 de IAM-001. Corrige la visibilidad cruzada de coordinadores sin programa.
- **OBSERVABILITY_IMPACT:** `CorrelationIdContext.get()` como `@idCorrelacion` en los SPs; logs JSONL con `correlationId`; la métrica `identity_drift_total{operation}` la aporta IAM-001.
- **TEST_LEVEL_REQUIRED:** T-SQL transaccional + JUnit unit/slice/wiring/ArchUnit + IT contra SQL Server + Jasmine + E2E script + comprobación contra Keycloak local.
- **ROLLBACK:** revertir los PRs en orden Front → Back → DB. La migración tiene un `down` idempotente (`DROP COLUMN` de las dos columnas nuevas). Ningún paso borra datos.
- **CONSUMERS:** portal Decano (`dean-coordinadores`); a futuro WI-A (reasignación del coordinador) y WI-I (patrón gemelo para docentes).
- **STOP_CONDITIONS:** D1–D10 sin resolver; IAM-001 sin merge (bloquea las llamadas al IdP); HU035/036 sin merge al tocar archivos calientes; cualquier prueba existente que solo pase relajándola → `TEST_CONTRACT_CONFLICT`.

Lo que no está en ALLOWED_PATHS no se modifica. Ampliar el alcance exige actualizar este PLAN con aprobación.

---

## 4. Alcance y no alcance

### Alcance
1. **DB:** migración de `Coordinador.estado` y `Coordinador.facultad`; SPs de edición y estado con su validador interno; ajustes en `usp_crear_coordinador` y en las vistas; códigos de mensaje `COO_*`; pruebas T-SQL por SP.
2. **Backend:** 2 features del decano; ampliación de puertos y adapter JPA; filtro por facultad en el listado; 2 endpoints; quitar la contraseña por defecto; sincronización de identidad con el servicio de IAM-001; pruebas.
3. **Frontend:** servicio con rutas correctas; modal de edición y de confirmación de estado; mensajes del backend sin heurísticas; specs.

### No alcance
1. Reasignar el coordinador a otro programa (HU077, WI-A). Aquí solo se **rechaza** desactivar a quien tiene un programa activo.
2. Implementar los métodos del puerto de identidad y el servicio de sincronización (IAM-001).
3. Alta de coordinador (HU120 ✔), salvo la contraseña por defecto (D5) y fijar `facultad`.
4. Cambio o recuperación de contraseña (DA-5).
5. Borrado físico de coordinadores.
6. Ver el coordinador desde el rol Administrador.

---

## 5. Archivos afectados

### Existentes (ruta comprobada el 2026-10-21)
- `GestioAsistenciaDB/schema/tables/Coordinador.sql`
- `GestioAsistenciaDB/schema/stored-procedures/usp_crear_coordinador.sql`
- `GestioAsistenciaDB/schema/views/uv_coordinador.sql`, `uv_coordinador_identidad.sql`, `uv_auth_coordinador.sql`, `uv_programa.sql` (lectura)
- `GestioAsistenciaDB/test/test_usp_crear_coordinador.sql`
- Backend (bajo `src/main/java/co/edu/uco/asistenciasuco/`): `infrastructure/adapter/primary/controller/decano/DecanoPortalController.java`, `application/secondaryports/academic/{CoordinadorCommandPort,CoordinadorQueryPort}.java`, `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/CoordinadorJpaRepository.java`, `application/features/decano/{crearcoordinador,consultarcoordinadores}/**`, `application/secondaryports/security/InstitutionalScopePort.java` (lectura)
- Frontend: `core/services/dean-management.service.ts`, `features/dean/dean-coordinadores/dean-coordinadores.component{,.spec}.ts`
- Patrones de referencia: `usp_crear_coordinador.sql` (transacción y savepoint); `docs/work-items/HU120-crear-coordinador/**`; WI-A (`HU076-…/CONTRACT.md`) para el estilo de SP de estado.

### Nuevos
- DB: la migración, 3 SPs y 2 pruebas `test_usp_*` (ver §3).
- Backend: features `decano/actualizarcoordinador/**` y `decano/cambiarestadocoordinador/**` (estructura de `crearcoordinador`); controlador, requests, response, validators y wiring de D10. Tests: ver [TEST_PLAN.md](TEST_PLAN.md).
- Frontend: `features/dean/dean-coordinadores/components/{dean-coordinador-edit-modal, dean-coordinador-estado-modal}.component{,.spec}.ts`.

---

## 6. Contratos y consumidores afectados

| Tipo | Contrato | Compatibilidad | Consumidor |
|---|---|---|---|
| PERSISTENCE | `Coordinador.estado` y `Coordinador.facultad` (columnas nuevas) | Aditivo: `estado` con `DEFAULT 1`, `facultad` nullable | Vistas, SPs |
| PERSISTENCE | `uv_coordinador`: columnas nuevas (`primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido`, `correo`, `estaActivoRolCoordinador`) y `idFacultad` con respaldo en `Coordinador.facultad` | Aditivo, pero **cambia el valor de `idFacultad` para coordinadores sin programa** (antes nulo) | `CoordinadorJpaRepository`, `InstitutionalScopeJpaRepository` (se revisa con Grep) |
| PERSISTENCE | `usp_crear_coordinador` fija `Coordinador.facultad` | Sin cambio de firma | Backend `CrearCoordinador` |
| PERSISTENCE | SPs nuevos de edición y estado | Aditivo | Backend nuevo |
| HTTP | `PUT /decano/coordinadores/{id}` (nuevo); `PATCH /decano/coordinadores/{id}/estado` pasa de 501 a 200 con cuerpo `{estaActivo}` | Aditivo / el 501 deja de existir | Front Decano |
| HTTP | El front deja de llamar a `…/toggle` | Rompe solo al front de este repo, que se corrige aquí | `dean-management.service.ts`, mocks |
| IDENTITY | Usa `IdentityProviderPort` ampliado y `SincronizarCuentaInstitucionalService` (IAM-001) | Dependencia dura de IAM-001 | `Actualizar*`, `CambiarEstado*` |
| SECURITY | Sin regla nueva (comodín `/api/v1/decano/**`) | Sin cambio | — |

---

## 7. Archivos calientes (coordinación con HU035/HU036 y entre grupos)

- **Con HU035/036:** `RbacSecurityFilterChainTest.java`, `HTTP_AS_IS_MATRIX.md` y `GestioAsistenciaDB/test_suite.sql` (y `SecurityConfig.java`, que este WI no necesita) están modificados sin commit por ese trabajo. **Las fases 03–06 de este WI empiezan después de que HU035/036 esté en `develop`.** Las ramas `feature/HU121-HU122-gestion-coordinador` de cada repo se crean desde ese `develop` actualizado.
- **Con WI-A (programa académico):** WI-A modifica `DecanoPortalController.java` y `DecanoWiringConfiguration.java` (agrega rutas y beans de programas). Para no pisarse, este WI pone sus rutas y beans en archivos propios (D10) y solo borra de `DecanoPortalController` el método `toggleCoordinador` (un hunk de 4 líneas).
- **Con WI-E (IAM-001):** este WI **consume** el puerto y el servicio de identidad. Si IAM-001 no está mergeado, solo se pueden completar DB, use cases con puertos *fake* y front; las pruebas contra Keycloak quedan pendientes.
- **Con WI-B (docentes):** B también agrega la tabla de estado por rol (`DocentePrograma.estado`) y debe **extender** `ufn_usuario_tiene_roles_activos`. Este WI la extiende para `Coordinador.estado`; el que llegue segundo rebasa la función.

---

## 8. Decisiones (resueltas el 2026-10-22)

El owner aprobó **todas las recomendaciones D1–D10** de la columna «Recomendación». Quedan fijadas: D1(a), D2(a), D3(a), D4(a), D5(a), D6(a), D7(a), D8(a), D9(b), D10(a).

| ID | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| **D1** | `Coordinador` no tiene estado propio. ¿Cómo se desactiva? | (a) DDL: `Coordinador.estado BIT NOT NULL DEFAULT 1`; `Usuario.estado` pasa a 0 solo si la persona no tiene otro rol activo. (b) Apagar `Usuario.estado` directamente (afecta a todos los roles de la persona). | **(a)**: es la regla D2(a) de IAM-001 y no bloquea el acceso legítimo por otro rol. Es retrocompatible por el `DEFAULT 1`. |
| **D2** | Un coordinador **sin programa** no tiene facultad, así que hoy cualquier decano lo ve y no se puede validar su ámbito. | (a) DDL: `Coordinador.facultad` (FK, nullable) rellenada desde `Programa` y fijada por `usp_crear_coordinador`; los huérfanos que no se puedan rellenar se reportan y el owner los asigna. (b) Sin DDL: solo se pueden editar coordinadores que ya tienen programa. (c) Solo el decano creador (requiere auditoría que no existe). | **(a)**: cierra la fuga de visibilidad y permite validar el ámbito en DB. Los coordinadores huérfanos deben revisarse en la fase 03 con una consulta previa. |
| **D3** | ¿Se puede desactivar a un coordinador que coordina un programa activo? (`Programa.coordinador` es `NOT NULL`.) | (a) No: 409 `COO_001`; hay que reasignar primero (HU077). (b) Sí, y el programa queda con un coordinador inactivo. (c) Sí, con desactivación en cascada del programa. | **(a)**: evita programas sin coordinador operativo y no toca otras entidades. Depende de WI-A para la reasignación; mientras tanto el decano desactiva primero el programa (HU078). |
| **D4** | ¿Qué se edita en HU121? | (a) Nombres, apellidos y correo; no el documento ni el tipo (el documento es el `username` del IdP). (b) También el programa asignado. | **(a)**: la reasignación es HU077 (WI-A). |
| **D5** | La contraseña por defecto `UcoCoord_<doc>!` de `CrearCoordinadorUseCaseImpl` choca con DA-5. | (a) Quitarla: la contraseña es obligatoria en la creación (validator + use case + front ya la exige). (b) Dejarla. | **(a)**: es un cambio de comportamiento de HU120 certificada, pero una contraseña predecible derivada del documento es un riesgo. Se cubre con una prueba de regresión. |
| **D6** | Contrato del cambio de estado. | (a) Explícito: `PATCH …/estado` con `{ "estaActivo": true\|false }`, idempotente. (b) *Toggle* sin cuerpo. | **(a)**: evita dobles clics que inviertan el estado y deja claro el efecto en el IdP. El front se ajusta (hoy llama a `…/toggle`). |
| **D7** | Si Keycloak falla después del commit en DB. | (a) Éxito con advertencia (`IAM_002`) + registro de desfase de IAM-001. (b) Error. | **(a)**, igual que en IAM-001 §3: el cambio en DB ya protege vía RBAC y el desfase se reconcilia después. |
| **D8** | `SecurityConfig` ya deja pasar al `ADMINISTRADOR` en `/api/v1/decano/**`. | (a) El use case lo rechaza con 403 porque no tiene facultad de decano. (b) Se le permite con `?idFacultad=`. | **(a)**, igual que WI-A D9. Se revisa en WI-F/G. |
| **D9** | ¿Evento SSE al mutar un coordinador? | (a) Sí. (b) No. | **(b)**: `ReactorRealtimeAdapter` no filtra por destinatario; el decano refresca tras su propia acción. Si el owner quiere cerrar la sesión del coordinador afectado, se evalúa con WI-E. |
| **D10** | `DecanoPortalController` y `DecanoWiringConfiguration` los toca también WI-A. | (a) Controlador y wiring propios para H (`DecanoCoordinadorGestionController`, `CoordinadorGestionWiringConfiguration`). (b) Agregar a los archivos existentes. | **(a)**: evita conflictos de merge entre equipos. Rutas y base path son los mismos. |

---

## 9. Riesgos y dependencias

| ID | Riesgo | Mitigación |
|---|---|---|
| R1 | Archivos calientes compartidos con HU035/036 y con WI-A | §7: archivos propios, rebase sobre `develop` y ramas desde el `develop` actualizado |
| R2 | IAM-001 no está listo cuando se implemente H | Orden del programa: **E antes que H**. Si no se cumple, los puertos *fake* permiten cerrar DB, use cases y front; la pieza del IdP queda como `BLOCKED_BY_MISSING_EVIDENCE` |
| R3 | Coordinadores huérfanos (sin programa y sin facultad deducible) al rellenar `Coordinador.facultad` | Consulta previa en el contenedor (fase 03). Si existen, el script de relleno los lista y un saneamiento aprobado aparte los asigna; la columna queda nullable hasta entonces |
| R4 | `uv_coordinador.idFacultad` pasa a tener valor para los sin programa: puede afectar a consumidores que usan `idFacultad is null` como "sin programa" | Grep de consumidores en la fase 03 (`CoordinadorJpaRepository.HQL_SIN_PROGRAMA` usa `idPrograma is null`, no `idFacultad`) y prueba de regresión |
| R5 | Una persona con dos roles (coordinador y docente) | T-122-06: desactivar el rol de coordinador no apaga la cuenta ni el otro rol. Depende de que `ufn_usuario_tiene_roles_activos` conozca el estado del otro rol (WI-B) |
| R6 | Concurrencia: dos decanos o dos pestañas cambian el estado a la vez | El SP lee con `UPDLOCK, HOLDLOCK`; el cambio es idempotente por el contrato explícito (D6) |
| R7 | La vista de la DB real difiere del archivo del repo (campos de nombre y correo) | Se verifica en la fase 03 con `sp_help`/`INFORMATION_SCHEMA` antes de escribir las pruebas RED |

**Dependencias:** HU120 ✔, HU117-B ✔ (decano con facultad), **IAM-001** (puerto de identidad, `usp_internal_*` y función de roles activos). WI-A es deseable (reasignación) pero no bloquea por D3(a).

---

## 10. Test plan

Ver [TEST_PLAN.md](TEST_PLAN.md). Secuencia RED → GREEN → VALIDATE **por repo y en orden DB → Backend → Frontend**; no se escribe código de producción antes de registrar el `RED_SNAPSHOT` del repo.

---

## 11. Secuencia de ejecución (fases 02–06)

| Fase | Repo | Rama | Commits atómicos (Conventional Commits, `Refs: HU121` o `HU122`) |
|---|---|---|---|
| 02 CONTRACT | Backend (docs) | `docs/plan-registro-roles` → PR propio | `docs(hus): congelar contrato HU121-HU122 gestion de coordinador` |
| 03 RED (DB) | GestioAsistenciaDB | `feature/HU121-HU122-gestion-coordinador` | `test(db/sp): agregar pruebas red de gestion de coordinador` |
| 04 GREEN (DB) | GestioAsistenciaDB | idem | `feat(db/tables): agregar estado y facultad a coordinador`; `feat(db/views): exponer datos editables en uv_coordinador`; `feat(db/sp): agregar actualizacion y estado de coordinador`; `fix(db/sp): fijar facultad en usp_crear_coordinador` |
| 03 RED (Back) | GestioAsistenciaBackend | idem | `test(backend/usecase): agregar pruebas red de gestion de coordinador` |
| 04 GREEN (Back) | idem | idem | `feat(backend/ports): …`, `feat(backend/adapter): …`, `feat(backend/usecase): …`, `feat(backend/controller): …`, `fix(backend/usecase): exigir password en alta de coordinador`, `fix(backend/usecase): filtrar coordinadores sin programa por facultad` |
| 03 RED (Front) | GestioAsistenciaFrontend | idem | `test(frontend/decano): agregar specs red de gestion de coordinador` |
| 04 GREEN (Front) | idem | idem | `feat(frontend/decano): …`, `fix(frontend/decano): alinear ruta de estado de coordinador` |
| 05 AUDIT | los 3 | — | `VALIDATION.md` |
| 06 CLOSURE | Backend (docs) + Infra | — | `docs(hus): cerrar HU121-HU122`, actualizar `HTTP_AS_IS_MATRIX.md`, `HU-CATALOG.md` y el espejo |

Un PR por repo, aprobado por el owner antes del merge.

---

## 12. Rollback y stop conditions

- **Rollback:** revertir los PRs en orden Front → Back → DB. El `down` de la migración quita las dos columnas nuevas. Los cambios de estado ya aplicados a cuentas del IdP se revierten con la operación inversa (reactivar), no con borrado.
- **CONTRACT_CONFLICT:** si aparece un consumidor no detectado de `uv_coordinador.idFacultad` o de `usp_crear_coordinador` con otra firma.
- **TEST_CONTRACT_CONFLICT:** si alguna prueba existente falla por el cambio (p. ej. de HU120). Se documenta; nunca se relaja.
- **BLOCKED_BY_MISSING_EVIDENCE:** si IAM-001 no está en `develop`, o no hay una facultad con ≥ 2 coordinadores para probar el aislamiento; se agrega un fixture en `test/fixtures/dev/`.

---

## 13. Deuda conocida y validación manual

- **Deuda que este WI cierra:** ruta `toggle` vs `estado` (REG-000 §6); contraseña por defecto de coordinador (REG-000 §6); fuga de coordinadores sin programa entre facultades; HU121/HU122 en 501 o sin endpoint.
- **Deuda que no toca:** TD-013 (política de aprovisionamiento) y TD-015 (reconciliación), que son de IAM-001; TD-014 (`emailVerified=true`).
- **Validación manual (MV):** con el decano canónico (`decano.ingenieria`), crear un coordinador (HU120), editar nombre y correo, comprobar el cambio en la vista y en Keycloak, desactivarlo (debe fallar si tiene programa activo y pasar si no), intentar iniciar sesión con la cuenta desactivada, reactivarlo y volver a entrar. Con el decano de otra facultad, comprobar que no ve ni modifica ese coordinador.

---

## 14. Definition of Ready (DoR)

| Criterio DoR | Estado | Evidencia / pendiente |
|---|---|---|
| 1. Objetivo y alcance delimitados | ✅ | §1, §4 |
| 2. AS-IS con evidencia | ✅ | §2 (rutas comprobadas el 2026-10-21) |
| 3. Contratos identificados | ✅ (borrador) | [CONTRACT.md](CONTRACT.md) `DRAFT` |
| 4. Matriz de pruebas TDD inicial | ✅ | [TEST_PLAN.md](TEST_PLAN.md) |
| 5. Sin conflictos con contratos WORM | ✅ | No toca golden path ni el baseline DB (verificar con Grep en la fase 02 que `uv_coordinador` no figure en `docs/contracts/**`) |
| 6. Decisiones del owner resueltas | ✅ | D1–D10 aprobadas el 2026-10-22 |
| 7. Archivos calientes liberados | ❌ | HU035/036 sin merge a `develop` |
| 8. Dependencia IAM-001 disponible | ❌ | WI-E en `draft` |
| 9. Plan de rollback viable | ✅ | §12 |

**Dictamen DoR:** 👉 **`NOT_READY`**: contrato congelado (2026-10-22) y decisiones resueltas; faltan el merge de HU035/036 (criterio 7) e IAM-001 (criterio 8) para pasar a `READY` e iniciar la fase 03.
