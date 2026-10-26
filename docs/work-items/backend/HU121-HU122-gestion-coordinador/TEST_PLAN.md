---
status: contract-frozen
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# TEST_PLAN — HU121 / HU122: Gestión del Coordinador (Rol Decano)

**Estado:** `RED_PLANNED` (contrato congelado el 2026-10-22). Las pruebas se escriben en la fase 03, en orden **DB → Backend → Frontend**, sobre ramas `feature/HU121-HU122-gestion-coordinador` creadas desde `develop` **después del merge de HU035/036** y con IAM-001 disponible.

## Fuentes

- [PLAN](PLAN.md) (criterios CA-01…CA-09, decisiones D1–D10)
- [CONTRACT](CONTRACT.md) (`CONTRACT_FROZEN`; las pruebas se derivan de él)
- Skills: `uco-testing`, `uco-persistencia`, `uco-contratos`, `uco-seguridad`
- Patrones existentes:
  - `GestioAsistenciaDB/test/test_usp_crear_coordinador.sql`, `test_titularidad_jerarquica.sql`, `test_transaction_ownership.sql`
  - `src/test/java/.../application/features/decano/crearcoordinador/**`, `consultarcoordinadores/**`
  - `DecanoPortalControllerTest`, `CoordinadorJpaCommandPatternTest`, `SqlStoredProcedureContractIT`, `RbacSecurityFilterChainTest`
  - `FakeKeycloakAdminServer` (IAM-001) para el adapter de identidad
  - `features/dean/dean-coordinadores/dean-coordinadores.component.spec.ts`

> Convención de datos: facultades F1 y F2; decanos D1 (F1) y D2 (F2); coordinadores C1 (F1, con programa activo P1), C2 (F1, sin programa), C3 (F2, sin programa), C4 (F1, con programa inactivo).

---

## 1. Matriz de comportamiento

| ID | Requisito | Precondición | Acción / entrada | Resultado esperado | Nivel |
|---|---|---|---|---|---|
| T-121-01 | CA-01: edición feliz | C2 en F1 | `usp_actualizar_coordinador` / `PUT /decano/coordinadores/{C2}` con nombre y correo nuevos | `GEN_005`; `uv_coordinador` refleja los valores; documento y tipo intactos; HTTP 200 con `sincronizacionIdentidad="OK"`; el IdP recibe correo y nombres nuevos | DB, UseCase, Controller, IT, E2E |
| T-121-02 | CA-02: correo ya usado por otro usuario | Correo de otro usuario | Editar C2 con ese correo | `VAL_006`; HTTP 409; sin cambios; `@@TRANCOUNT=0` | DB, UseCase, Controller |
| T-121-03 | El correo propio no cuenta como duplicado | C2 con correo X | Editar C2 con X (otros campos distintos) | Éxito | DB |
| T-121-04 | CA-06: coordinador de otra facultad | C3 en F2 | D1 edita C3 | `GEN_001`; HTTP **404**; C3 intacto | DB, Controller |
| T-121-05 | CA-06: coordinador sin programa de otra facultad ya no se lista | C2 (F1) y C3 (F2) sin programa | `GET /decano/coordinadores` como D1 y como D2 | D1 ve C2 y no C3; D2 ve C3 y no C2 (regresión de la fuga de `consultarCoordinadoresSinPrograma`) | UseCase, IT, E2E |
| T-121-06 | RBAC en DB | Ejecutor con perfil COORDINADOR | Editar | Falla RBAC; sin cambios | DB |
| T-121-07 | Ejecutor NULL | — | `@idUsuarioEjecutor = NULL` | `GEN_002`; no se sustituye por un GUID por defecto | DB |
| T-121-08 | Validación de forma | — | Nombre vacío o solo espacios; > 50 caracteres; correo sin formato; `id` no UUID | DB `GEN_002`/`VAL_*`; HTTP 400 por el validator sin llamar al use case | DB, Validator, Controller |
| T-121-09 | El administrador no opera aquí (D8) | Token de `ADMINISTRADOR` | `PUT /decano/coordinadores/{id}` | 403 (`findFacultadIdByDecanoUsuario` vacío); sin llamada al puerto de DB | UseCase, Controller, `RbacSecurityFilterChainTest` |
| T-121-10 | CA-07: atomicidad | Falla forzada después de la validación | Editar | Rollback completo, `estadoResultado=0`, `SYS_001`, `@@TRANCOUNT=0` | DB |
| T-121-11 | CA-07: transacción externa del llamador | `BEGIN TRAN` externo + edición con error | — | Rollback solo hasta el savepoint; la externa sigue viva | DB |
| T-121-12 | D7: falla del IdP después del commit | `FakeKeycloakAdminServer` responde 500 | Editar C2 | DB queda actualizada; HTTP 200 con `mensajeUsuario=IAM_002` y `sincronizacionIdentidad="PENDIENTE"`; `UsuarioSincronizacionPort.registrar` invocado una vez | UseCase, IT |
| T-121-13 | El IdP no se invoca si la DB falla | `VAL_006` o 404 | Editar | `IdentityProviderPort` y el servicio de sincronización sin interacciones (`verifyNoInteractions`) | UseCase |
| T-122-01 | CA-03: desactivar sin programa | C2 activo, sin programa | `usp_cambiar_estado_coordinador` / `PATCH …/{C2}/estado {estaActivo:false}` | `Coordinador.estado=0`; `uv_coordinador.estaActivoCoordinador=0`; `Usuario.estado=0` (no tiene otro rol); HTTP 200; el servicio recibe `desactivar(..., personaSinRolesActivos=true)`; la cuenta del IdP queda `enabled=false` y sin el rol | DB, UseCase, Controller, IT, E2E |
| T-122-02 | CA-05 / D3: desactivar con programa activo | C1 coordina P1 activo | Desactivar C1 | `COO_001`; HTTP 409; estado intacto; IdP sin interacciones | DB, UseCase, Controller |
| T-122-03 | D3: desactivar con programa inactivo | C4 coordina un programa inactivo | Desactivar C4 | Éxito | DB |
| T-122-04 | CA-04: reactivar | C2 inactivo | `{estaActivo:true}` | `estado=1`, `Usuario.estado=1`; `reactivar(...)`: `habilitarCuenta` + `asignarRol(COORDINADOR)` | DB, UseCase, IT |
| T-122-05 | D6: idempotencia | C2 inactivo | Desactivar otra vez | Éxito sin cambios; no se llama dos veces al IdP con efecto distinto | DB, UseCase |
| T-122-06 | R5 / D1: persona con dos roles | Persona con COORDINADOR y DOCENTE activos | Desactivar el rol de coordinador | `Coordinador.estado=0`; `Usuario.estado` sigue en 1; `personaSinRolesActivos=false`; el servicio solo hace `retirarRol(COORDINADOR)`, la cuenta sigue habilitada | DB, UseCase, IT |
| T-122-07 | CA-06: coordinador de otra facultad | C3 en F2 | D1 desactiva C3 | `GEN_001`; HTTP 404; C3 intacto | DB, Controller |
| T-122-08 | RBAC y ejecutor NULL | Perfil distinto de DECANO / `NULL` | Cambiar estado | Falla RBAC / `GEN_002` | DB |
| T-122-09 | `estaActivo` ausente | Cuerpo vacío o `{}` | `PATCH …/estado` | HTTP 400 (validator); no se asume toggle | Validator, Controller |
| T-122-10 | R6: concurrencia | C2 activo | Dos desactivaciones y una reactivación simultáneas (dos conexiones `sqlcmd`) | Estado final consistente con la última confirmada; sin interbloqueos; `@@TRANCOUNT=0` | DB (script en `scripts/database/tests/`) |
| T-122-11 | CA-07: falla del IdP al desactivar | `FakeKeycloakAdminServer` 500 | Desactivar C2 | DB desactivada; HTTP 200 con `IAM_002`; desfase registrado; `identity_drift_total{operation}` incrementada | UseCase, IT |
| T-122-12 | Efecto sobre el acceso | C2 desactivado | `POST` al token de Keycloak local con sus credenciales | Rechazado (`invalid_grant`); tras reactivarlo, aceptado | E2E (`scratch/test_hu122.ps1`) |
| T-122-13 | Aislamiento de rol en la sesión | C2 desactivado con un token vigente | Llamada a `/api/v1/coordinador/**` | Rechazada por RBAC en DB (no se espera al vencimiento del token) | E2E, DB |
| T-120R-01 | CA-09 / D5: contraseña obligatoria | — | `POST /decano/coordinadores` sin `password` o vacío | HTTP 400 con mensaje de catálogo; no se crea usuario ni cuenta; ya no existe `UcoCoord_<doc>!` | UseCase, Validator, Controller |
| T-120R-02 | `usp_crear_coordinador` fija la facultad | Decano D1 | Crear coordinador sin programa | `Coordinador.facultad = F1`; aparece en `uv_coordinador` con `idFacultad = F1` | DB (amplía `test_usp_crear_coordinador.sql`) |
| T-DDL-01 | Migración idempotente | DB con y sin las columnas | Ejecutar `up` dos veces | Sin error; datos conservados; `estado=1` en las filas existentes | DB |
| T-DDL-02 | Relleno de `facultad` | Coordinadores con programa | `up` | `Coordinador.facultad = Programa.facultad`; huérfanos listados en el reporte | DB |
| T-DDL-03 | `down` | Con columnas | Ejecutar `down` | Columnas, `DEFAULT` y FK eliminados; segundo `down` sin error | DB |
| T-VIEW-01 | Vista ampliada | — | `SELECT` sobre `uv_coordinador` | Expone `primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido`, `correo`, `estaActivoRolCoordinador` | DB |
| T-VIEW-02 | R4: consumidores de `idFacultad` | — | `CoordinadorJpaRepository`, `InstitutionalScopeJpaRepository` | Ningún resultado cambia salvo el esperado en T-121-05 | IT |
| T-FRONT-01 | Servicio: ruta de edición | — | `updateCoordinador(id, payload)` | `PUT /decano/coordinadores/{id}` con el cuerpo tipado | Jasmine (`HttpTestingController`) |
| T-FRONT-02 | Servicio: ruta de estado | — | `setCoordinadorEstado(id, false)` | `PATCH /decano/coordinadores/{id}/estado` con `{estaActivo:false}`; **no** se llama a `/toggle` | Jasmine |
| T-FRONT-03 | Modal de edición | Coordinador con datos | Abrir, cambiar un campo y guardar | Valida al escribir; no envía documento ni tipo; emite el payload | Jasmine (componente) |
| T-FRONT-04 | Confirmación de estado | Coordinador activo | Pulsar Desactivar y confirmar | Llama a `setCoordinadorEstado(id, false)`; en éxito muestra `mensajeUsuario` | Jasmine |
| T-FRONT-05 | Advertencia de sincronización | Respuesta con `sincronizacionIdentidad='PENDIENTE'` | Guardar | Toast de advertencia con el `mensajeUsuario` del backend | Jasmine |
| T-FRONT-06 | Errores 404/409 | Respuestas 404 y 409 con `message` | Guardar o cambiar estado | Muestra el `message` tal cual; sin comparar textos ni parsear errores | Jasmine |
| T-FRONT-07 | Reglas de UI del proyecto | — | Revisión estática y `npm run build` | `OnPush`, `input()`/`output()`, sin `@Input`/`@Output`, sin `any` nuevos, sin `setInterval`, sin JWT en `localStorage` | Jasmine, lint, build |
| T-ARCH-01 | Arquitectura | — | ArchUnit existente | `application` sin `infrastructure`; controlador sin JPA; los use cases son POJOs cableados en `CoordinadorGestionWiringConfiguration` | ArchUnit |
| T-WIRE-01 | Wiring | — | Test de contexto / `*WiringConfigurationTest` | Los beans nuevos existen; `DecanoWiringConfiguration` no cambia | Slice |
| T-SEC-01 | Reglas HTTP | Tokens de los 5 roles | `PUT` y `PATCH` | DECANO pasa a use case; COORDINADOR, DOCENTE y ESTUDIANTE → 403; sin token → 401; ADMINISTRADOR llega al use case y recibe 403 (T-121-09) | `RbacSecurityFilterChainTest` ⚠️ |
| T-CONTRACT-01 | Contrato del SP | — | `SqlStoredProcedureContractIT` | Los dos SPs devuelven las columnas declaradas (`idUsuario`, `personaSinRolesActivos`) | IT |

---

## 2. Pruebas por repositorio y orden de ejecución

### 2.1 Base de Datos (fase 03 RED → 04 GREEN)
- Archivos nuevos: `test/test_usp_actualizar_coordinador.sql` y `test/test_usp_cambiar_estado_coordinador.sql`. Se amplía `test/test_usp_crear_coordinador.sql` (T-120R-02). **No** se edita `test_suite.sql` (archivo caliente); se agrega al final de la fase 05, después del merge de HU035/036.
- Cada prueba corre en transacción con rollback y cierra con `@@TRANCOUNT = 0`.
- Concurrencia: `scripts/database/tests/test_hu122_concurrencia.ps1`.
- RED esperado: los SPs y las columnas no existen → fallan por ausencia.
- Comando de verificación:
  ```powershell
  Get-Content -Path .\GestioAsistenciaDB\test\test_usp_cambiar_estado_coordinador.sql -Raw | docker exec -i sql_server_asistencias /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "TuPasswordSeguro123" -C -b
  ```

### 2.2 Backend (fase 03 RED → 04 GREEN)
- Unit: `ActualizarCoordinadorUseCaseImplTest`, `CambiarEstadoCoordinadorUseCaseImplTest` (todas las ramas: facultad vacía, PENDIENTE, `personaSinRolesActivos` true/false), `CrearCoordinadorUseCaseImplTest` (T-120R-01), `ConsultarCoordinadoresUseCaseImplTest` (T-121-05).
- Adapter: `CoordinadorJpaCommandPatternTest` ampliado (SQL de los dos SPs y parámetros); `CoordinadorJpaRepositoryIT` contra SQL Server.
- Controller: `DecanoCoordinadorGestionControllerTest` (MockMvc: 200/400/401/403/404/409), validators y mapeo de excepciones (`DbFailureClassifier`).
- Seguridad: `RbacSecurityFilterChainTest` ⚠️ (después del merge de HU035/036).
- Identidad: con `FakeKeycloakAdminServer` (de IAM-001). Si IAM-001 no está, se usan puertos *fake* y estas pruebas quedan en `BLOCKED_BY_MISSING_EVIDENCE`, sin relajarlas.
- Comando: `cmd /c ".\mvnw.cmd test"` y luego `.\mvnw.cmd verify` (JaCoCo LINE ≥ 80 %, BRANCH ≥ 70 %; meta 100 % en los use cases nuevos).

### 2.3 Frontend (fase 03 RED → 04 GREEN)
- Specs nuevos y ampliados: `dean-management.service.spec.ts`, `dean-coordinadores.component.spec.ts`, `dean-coordinador-edit-modal.component.spec.ts`, `dean-coordinador-estado-modal.component.spec.ts`.
- Cobertura de ramas: éxito, `PENDIENTE`, errores 400/401/403/404/409/500, datos nulos o vacíos.
- Comandos: `npm run test:ci`, `npm run build -- --configuration=development`, `npm run verify`.

### 2.4 E2E
- `scratch/test_hu121.ps1` y `scratch/test_hu122.ps1` (temporales, no se versionan): token del decano en Keycloak, `PUT` y `PATCH` con carga válida (200) e inválida (400/404/409), consulta directa a SQL Server y comprobación de `enabled` en el IdP. Se agregan los casos a `scripts/general/tests/test_all_hus.ps1` en la fase 06.

---

## 3. Registro de RED/GREEN (se completa en las fases 03–05)

| Repo | `RED_SNAPSHOT` (commit, rama, base, comando, resultado) | `GREEN` (commit, comando, exit code) | Estado |
|---|---|---|---|
| GestioAsistenciaDB | `f6ddb5a` en `feature/HU121-HU122-gestion-coordinador` (base `develop` `585f7f0`). Se ejecutaron los 3 archivos con `sqlcmd` contra `sql_server_asistencias`: **exit 1** en los tres (`Msg 207: Invalid column name 'estado'` / `'primerNombre'`, es decir, columnas y SPs inexistentes). Sintaxis verificada con `SET PARSEONLY ON` y fixtures verificados aparte (3 y 2 coordinadores creados y revertidos, `@@TRANCOUNT=0`, sin datos residuales) | **GREEN 2026-10-22**: ramas `feature/HU121-HU122-gestion-coordinador`, commits `e5879e4`, `2b65e4d`, `aa53f6f`, `e8bcd69`. Los 3 archivos de HU121/122 y `test_usp_crear_coordinador.sql` pasan con **exit 0** (`sqlcmd` contra `sql_server_asistencias`, sin tocar las pruebas). Regresion: 13 pruebas T-SQL existentes que usan coordinador, perfil, RBAC o titularidad, exit 0 | **GREEN** |
| GestioAsistenciaBackend | `002158a` + identidad `5c391fb` en `feature/HU121-HU122-gestion-coordinador` (base `develop` `4ff37ff`). `cmd /c ".\mvnw.cmd -q test-compile"`: **exit 1**, 206 errores, **todos** `cannot find symbol` / `package … does not exist` / firma de `consultarCoordinadoresSinPrograma` / constructor de `CoordinadorProjection`, únicamente en los 5 archivos de prueba del perímetro | — | RED confirmado (por compilación). **GREEN 2026-10-22**: commits `51b89c3`, `bd0b32a`, `77d036b`, `18e20e6`, `8ad2395`, `9f4f296`, `4e9c7dd`. `mvnw test` completo: **1729 pruebas, 0 fallos, BUILD SUCCESS** (incluye ArchUnit). No se corrió `verify -Pintegration` ni los IT contra SQL Server |
| GestioAsistenciaFrontend | `959ae84` en `feature/HU121-HU122-gestion-coordinador` (base `develop` `ea1e537`). `npx tsc -p tsconfig.spec.json --noEmit`: **exit 2**, 28 errores TS (`setCoordinadorEstado`, `updateCoordinador`, `coordinadorParaCambioEstado`, `abrirEdicion`, módulos de los dos modales, tipos `ActualizarCoordinadorPayload`…) | **GREEN 2026-10-22**: commits `2cedf54` y `d3b7dbd`. `npm run test:ci`: **845/845 SUCCESS** (exit 0); `npm run build -- --configuration=development`: exit 0; `tsc -p tsconfig.spec.json`: 0 errores | **GREEN** |

Regla: ninguna prueba se modifica para pasar. Un cambio de prueba exige un registro `TEST_CONTRACT_CONFLICT` con la razón y la aprobación del owner.

---

## 5. Notas de la fase 03 (2026-10-22)

### 5.1 Pruebas existentes que se actualizaron por el cambio **formal** del contrato (no relajan aserciones)

| Prueba | Cambio | Contrato que lo exige |
|---|---|---|
| `ConsultarCoordinadoresUseCaseImplTest` (3.er caso) | El stub pasa a `consultarCoordinadoresSinPrograma(facultad)` | CONTRACT §3.1 y D2 |
| `CoordinadorJpaCommandPatternTest.COO_PAT_004` | Llama con `FACULTAD`, el `Object[]` trae las 6 columnas nuevas y verifica `setParameter("idFacultad", …)`. Se conservan todas las aserciones previas | CONTRACT §3.1 y D2 |
| `CrearCoordinadorUseCaseImplTest.execute_con_idPrograma_nulo_y_puertos_iam…` | El dominio trae contraseña explícita en vez de `null` (ya no hay contraseña por defecto). Resto idéntico | D5 |
| `dean-management.service.spec.ts` (`toggleCoordinadorStatus…`) | Se reemplaza por las pruebas de `setCoordinadorEstado` (ruta `…/estado`) | D6 y CONTRACT §4 |
| `dean-coordinadores.component.spec.ts` (`toggleEstado envía PATCH…`) | `toggleEstado` abre confirmación; el PATCH sale al confirmar con `…/estado` | D6 y CONTRACT §4 |

### 5.2 Pruebas del TEST_PLAN que **no** se escribieron todavía

| ID | Motivo | Cuándo |
|---|---|---|
| T-122-06 (persona con dos roles, parte DB) | `ufn_usuario_tiene_roles_activos` es de IAM-001 y el estado del rol de docente es de WI-B. La parte del use case sí está cubierta (`personaSinRolesActivos` true/false) | Cuando IAM-001/WI-B estén en `develop` |
| T-121-10 (atomicidad con falla inyectada) | El SP no expone un punto de inyección; T-121-11 (la transacción externa sobrevive al rechazo) cubre el rollback hasta el savepoint | IT de backend en la fase 04 |
| T-121-12/T-122-11 contra Keycloak, T-122-12/13, T-DDL-01/03, T-122-10 (concurrencia), ITs `CoordinadorJpaRepositoryIT`, T-VIEW-02 | Necesitan IAM-001 (`FakeKeycloakAdminServer`) o scripts de integración; se escriben en la fase 04 junto con su implementación | Fase 04 |
| T-SEC-01 (`RbacSecurityFilterChainTest`), T-WIRE-01, T-ARCH-01 | Archivo caliente (HU035/036) y wiring que aún no existe | Después del merge de HU035/036 |
| Specs de `catalog`/`mock-backend.interceptor` | Se ajustan al alinear los mocks en la fase 04 | Fase 04 |

### 5.3 Nombres que fijaron las pruebas (el contrato no los definía)

- Dominio y DTO de resultado: `ResultadoGestionCoordinadorDomain(UUID idCoordinador, boolean sincronizacionPendiente, String mensajeUsuario)` y `ResultadoGestionCoordinadorDTO(UUID idCoordinador, String sincronizacionIdentidad, String mensajeUsuario)` en `application/features/decano/common/{domain,dto}`.
- Casos de uso reciben `(CoordinadorCommandPort, InstitutionalScopePort, SincronizarCuentaInstitucionalService, MessageCatalogPort)`. El mensaje `IAM_002` lo resuelve el caso de uso con `MessageCatalogPort`.
- Frontend: señales `coordinadorParaCambioEstado` y `coordinadorEnEdicion`; métodos `toggleEstado`, `confirmarCambioEstado`, `cancelarCambioEstado`, `abrirEdicion`, `cerrarEdicion`, `guardarEdicion`; componentes `app-dean-coordinador-edit-modal` y `app-dean-coordinador-estado-modal` (`input.required<CoordinadorItem>()`, `guardar`/`confirmar`/`cancelar` como `output()`; botones `type="submit"` y `data-accion="cancelar|confirmar"`).
- De IAM-001 se **asumieron** estos nombres a partir de su CONTRACT: `application/features/identidad/sincronizarcuenta/{SincronizarCuentaInstitucionalService, ResultadoSincronizacion(OK, PENDIENTE)}` y `application/secondaryports/identity/dto/ActualizarCuentaIdentidadDTO(correo, primerNombre, primerApellido)`. Si IAM-001 usa otros paquetes, solo cambian los `import` de las pruebas (se registra como alineación, no como relajación).

### 5.4 Aclaraciones al CONTRACT descubiertas al escribir las pruebas (pendientes de visto bueno del owner)

1. **`ApiDataResponse<T>` no tiene `mensajeUsuario`** (`record ApiDataResponse(boolean exitoso, T datos)`). El contrato §3.3 lo suponía en el envelope. Las pruebas ubican `mensajeUsuario` **dentro de `datos`** (`ResultadoGestionCoordinadorResponse { idCoordinador, sincronizacionIdentidad, mensajeUsuario }`), con valor solo cuando la sincronización queda pendiente (`IAM_002`).
2. **`GEN_001` no se clasifica hoy como "no encontrado"** (`DbFailureClassifier` lo deja como error técnico por ser genérico). El contrato §3.2 asumía 404. Las pruebas exigen que `GEN_001` sea `RESOURCE_NOT_FOUND` **solo** para las operaciones `actualizarCoordinador` y `cambiarEstadoCoordinador` (mismo mecanismo que ya usa `VAL_007`). No cambia el contrato de DB.
3. **`ProcedureResult` solo expone las 4 columnas canónicas.** Las columnas extra (`idUsuario`, `personaSinRolesActivos`) exigen extender el mapeo del adapter (`COO_PAT_006/007`). Además, `CorrelationIdContext` vive en infraestructura: de dónde sale el `idCorrelacion` que el caso de uso pasa al servicio de IAM-001 queda a decidir en la fase 04 (las pruebas aceptan cualquier valor).
4. **`uv_coordinador` real no expone nombres ni correo**, pese a lo que dice `HU120/CONTRACT.md` §2.1 (verificado con `sys.columns` en `sql_server_asistencias`). Es una discrepancia del contrato de HU120, no de este WI; este WI la corrige al ampliar la vista.
5. **Convención de nombres de SP internos:** el repo usa el sufijo `_interno` (`usp_validar_titularidad_jerarquica_interno`), mientras IAM-001 y este contrato escriben `usp_internal_*`. Se decide al implementar; las pruebas solo invocan los SP públicos.

---

## 4. Cobertura de criterios

| Criterio | Pruebas |
|---|---|
| CA-01 | T-121-01, T-121-03, T-FRONT-01, T-FRONT-03 |
| CA-02 | T-121-02, T-FRONT-06 |
| CA-03 | T-122-01, T-122-11, T-122-12, T-122-13 |
| CA-04 | T-122-04, T-122-12 |
| CA-05 | T-122-02, T-122-03 |
| CA-06 | T-121-04, T-121-05, T-122-07 |
| CA-07 | T-121-10, T-121-11, T-121-12, T-122-11 |
| CA-08 | T-FRONT-02, T-FRONT-04, T-FRONT-06 |
| CA-09 | T-120R-01 |

---

## 6. Notas de la fase 04 (2026-10-22)

### 6.1 DB

- **Despliegue selectivo.** El contenedor `sql_server_asistencias` lo comparte otro work item (gestion de facultad), asi que no se corrio `deploy_schema.ps1` completo (habria pisado SPs que esa rama modifico). Se aplicaron solo los archivos de este WI y se inserto `COO_001` con un `INSERT ... IF NOT EXISTS`.
- **Nombres de los SP internos:** se uso la convencion real del repo, sufijo `_interno`: `usp_validar_coordinador_de_facultad_interno`, `usp_cambiar_estado_usuario_interno`, `usp_actualizar_datos_usuario_interno`. IAM-001 los llama `usp_internal_*`: **hay que alinear ese documento** (o renombrar) antes de implementarlo para no duplicar objetos. Tambien se creo `ufn_usuario_tiene_roles_activos` (el nombre coincide con IAM-001).
- **Cambio no previsto en el contrato:** `uv_usuario_perfil` omite el perfil de un coordinador con `Coordinador.estado = 0`. Sin eso, RBAC (`usp_validar_permiso_rbac_usuario_interno`) seguia aceptando el rol desactivado mientras la persona tuviera otro rol activo (CA-03, T-122-13).
- **Hallazgo tecnico:** SQL Server prohibe `ROLLBACK` dentro de `INSERT ... EXEC` (error 3915), que es como las pruebas consumen el SP. Los dos SP nuevos solo hacen `ROLLBACK` cuando ya hubo una escritura; un rechazo de negocio antes de escribir cierra sin rollback. `usp_crear_coordinador` tiene el mismo patron pero sus pruebas nunca ejercitan un fallo despues de abrir la transaccion.
- **Pendiente de DB:** T-122-06 (parte DB) y la concurrencia T-122-10 (necesitan IAM-001/WI-B y un script de dos conexiones); `scripts/database/tests/`.

### 6.2 Frontend

- Angular 18: escribir un `signal` dentro de un `effect` exige `{ allowSignalWrites: true }`; el modal de edicion lo usa para precargar los datos.
- Se actualizo el spec existente `mock-backend.interceptor.spec.ts` (ruta `/estado` con `estaActivo` en vez de `/toggle`) por D6; la aserción no cambio.

### 6.3 Backend

- **Se desbloqueó sin esperar a IAM-001** (decisión del owner: mínimo en este WI, el resto de IAM-001 sigue aparte). Se implementó solo lo que HU121/HU122 consume:
  - `IdentityProviderPort` suma `buscarCuentaPorIdUsuario`, `deshabilitarCuenta`, `habilitarCuenta`, `actualizarDatosCuenta` y `retirarRol` como **métodos `default` que lanzan `IdentityProviderException("Operacion no soportada…")`**. Un proveedor que no los implemente (p. ej. el componente de seguridad de otro equipo) no rompe la compilación; la sincronización lo trata como desfase pendiente.
  - `KeycloakIdentityProviderAdapter` los implementa (idempotentes). El switch `app.adapters.identity.provider` no cambia; no hay otro adapter en esta rama.
  - `SincronizarCuentaInstitucionalService`, `ResultadoSincronizacion`, `UsuarioSincronizacionIdentidadPort` y `MetricsUsuarioSincronizacionIdentidadAdapter` (log + `identity_drift_total{operation}`). **No** hay tabla de desfases ni reconciliación: siguen siendo de IAM-001.
- **Desviaciones del borrador de IAM-001 que ese documento debe recoger:**
  1. El servicio y `registrar(...)` **no llevan `idCorrelacion`**: las reglas ArchUnit `ApplicationShouldNotCarryTechnicalCorrelationTest` y `ApplicationShouldNotUseInfrastructureTechnicalApisTest` lo prohíben en Application. El adapter de desfases lee `CorrelationIdContext`.
  2. Las operaciones del puerto son `default` (capacidad opcional), no abstractas.
  3. Los SP internos se llaman `usp_*_interno` (ver §6.1), no `usp_internal_*`.
- **Pruebas existentes tocadas:** `DecanoPortalControllerTest` (se retira la del stub 501, la ruta pasó al controlador nuevo) y `CoordinadorJdbcBaseline` (helper de pruebas que implementa `CoordinadorCommandPort`: delega los dos comandos nuevos en el JPA). Mis propias pruebas de la ruta `/toggle` y del servicio se corrigieron por errores técnicos (ArchUnit y `standaloneSetup`), sin relajar aserciones.
### 6.4 E2E contra Keycloak local y DB (2026-10-22)

- **Montaje:** backend de la rama en `:8091` (el `:8080` del checkout principal no se tocó) con la DB local y el Keycloak propio en `:8081` (`app.adapters.identity.provider=keycloak`). Script temporal `test_hu121_hu122.ps1` (no se versiona; vive en el scratchpad de la sesión).
- **Resultado:** **29 de 29 verificaciones OK** (`exit 0`): token del decano; alta de coordinador de prueba; alta sin contraseña → 400 (D5); listado con datos editables; `PUT` 200 con identidad OK y DB/Keycloak reflejando correo y nombres con el documento intacto; correo ajeno → 409; datos inválidos → 400; coordinador inexistente → 404; sin token → 401; un coordinador → 403; `PATCH` sin `estaActivo` → 400; desactivar → DB `0|0`, Keycloak `enabled=false` sin rol `COORDINADOR` y sin token; idempotencia; reactivar → DB `1|1`, Keycloak habilitado con el rol y token de nuevo; coordinador con programa activo → 409 (`COO_001`) y sigue activo; limpieza sin residuos en DB ni en Keycloak.
- **Bugs que solo el E2E destapó** (corregidos en `96c1d6a`, con pruebas de regresión `COO_PAT_010`, `COO_PAT_011` y `COO_PAT_012`):
  1. `GET /decano/coordinadores` respondía 500 (NPE): con `Coordinador.facultad`, `uv_coordinador` devuelve filas con `idPrograma` nulo (parte de la identidad compuesta de la entidad) y Hibernate las entrega como `null`. Es el riesgo R4 del PLAN. El listado por facultad ahora excluye las filas sin programa, que se leen por la consulta de columnas.
  2. Los SP devuelven `idUsuario` como **texto** (`uniqueidentifier` en consulta nativa) y el adapter solo aceptaba `UUID`: toda edición o cambio de estado respondía 500 `ERR_DB_CANONICAL_CONTRACT` aunque la DB ya hubiera aplicado el cambio.
- **Nota de entorno:** el `.env` de Infra y el del backend traen valores distintos de `KEYCLOAK_ADMIN_CLIENT_SECRET`; para el backend vale el de `GestioAsistenciaBackend/.env`. Cargar primero Infra y después el del backend.
- **No cubierto por el E2E:** coordinador de **otra facultad** (el entorno canónico tiene una sola; está cubierto en DB, T-121-04/T-122-07), falla del IdP con respuesta `IAM_002` (cubierta con el servidor falso del adapter y los unit tests), concurrencia y la UI.

### 6.5 Validación de la pantalla en el navegador integrado (2026-10-22)

- **Montaje:** frontend de la rama en `:4200` (Keycloak solo admite ese origen; el frontend original se detuvo y se restauró con `infra.ps1 restart-frontend`) apuntando a un backend de la rama en `:8091` (`env.js` temporal, revertido). Login real como `decano.ingenieria@uco.edu.co`.
- **Verificado en `/app/decano/coordinadores`:**
  - La lista muestra los botones **Editar** y **Desactivar** y, por primera vez, el coordinador **sin programa** de la facultad (tarjeta "Sin Programa Asignado").
  - **Editar:** el modal abre precargado, muestra el documento como no editable, un correo inválido deshabilita **Guardar cambios** y muestra "Ingresa un correo electrónico válido."; con datos válidos guarda, cierra el modal y la tarjeta se actualiza (nombre y correo nuevos); DB y Keycloak coinciden.
  - **Desactivar / Reactivar:** el modal de confirmación nombra a la persona; tras confirmar la tarjeta pasa a INACTIVO / ACTIVO; DB `0|0` y Keycloak `enabled=false` al desactivar, y al revés al reactivar.
  - **Regla D3:** desactivar al coordinador con programa activo devuelve 409, el modal se cierra, el coordinador sigue ACTIVO y se muestra el aviso institucional *"No se puede desactivar al coordinador mientras tenga un programa activo a cargo. Reasigne o desactive el programa primero."*
- **Bug que solo apareció en la UI** (corregido en `a5ade63`): el 409 llegaba como el mensaje genérico *"La operacion genera un conflicto con el estado actual."* porque `COO_001` se clasificaba como `CommonErrorCode.CONFLICT`. Ahora tiene su propio `CoordinadorErrorCode.COO_001` (clasificador **y** conjunto `CONFLICT_CODES` del `DbExceptionTranslator`; con solo el clasificador habría dado un 500, lo atrapó `COO_PAT_008`). Se ajustó mi prueba del clasificador, que fijaba el código genérico.
- **Ruido preexistente, no de este WI:** la página dispara `GET /docentes` y `GET /coordinador/docentes` (selector de directorio) y ambos responden 403 para el decano.
- **Limpieza:** el coordinador de prueba se borró de DB y Keycloak; mis procesos (`:8091` y el frontend de la rama) quedaron detenidos y el `:4200` original restaurado.
- **No validado en UI:** el aviso de identidad pendiente (`IAM_002`) y la pantalla en móvil; el estado de carga y los errores de red se cubren con specs.

- **Pendiente de backend:** `RbacSecurityFilterChainTest` (T-SEC-01, archivo caliente de HU035/036), ITs contra SQL Server (`CoordinadorJpaRepositoryIT`, T-VIEW-02), `verify -Pintegration`, JaCoCo y la prueba de wiring (T-WIRE-01).
