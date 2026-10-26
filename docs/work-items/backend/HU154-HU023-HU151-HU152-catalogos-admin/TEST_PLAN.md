---
status: frozen
type: test-plan
scope: fullstack-database-backend-frontend
last-reviewed: 2026-10-22
---

# TEST_PLAN — HU154 + HU023 + HU151 + HU152

Todas las pruebas se escriben en rojo antes de implementar. No se relajan aserciones para hacerlas pasar. La matriz aplica por igual a `tipo_programa` y `area` salvo donde se indique; los IDs llevan sufijo `-T` (tipo de programa) o `-A` (área).

## 1. Base de datos (`GestioAsistenciaDB/test/`)

Archivos: `test_usp_{crear,actualizar,cambiar_estado}_tipo_programa.sql` y `..._area.sql`, con fixtures transaccionales que se revierten.

| ID | SP | Escenario | Resultado esperado |
| :-: | :--- | :--- | :--- |
| DB-01 | `usp_crear_*` | Alta con `codigo` y `nombre` válidos | `estadoResultado = 1`, fila con `estado = 1`, `codigo` en mayúsculas, `@@TRANCOUNT = 0` |
| DB-02 | `usp_crear_*` | `codigo` en minúscula con espacios (`" pr1 "`) | se normaliza a `PR1` |
| DB-03 | `usp_crear_*` | `codigo` de 2 o 4 caracteres, o con símbolos | `estadoResultado = 0`, `GEN_002`, sin fila |
| DB-04 | `usp_crear_*` | `nombre` de 2 o 51 caracteres, o vacío | `estadoResultado = 0`, `GEN_002` |
| DB-05 | `usp_crear_*` | `codigo` duplicado | `GEN_003`, sin fila nueva |
| DB-06 | `usp_crear_*` | `nombre` duplicado con otra capitalización | `GEN_003` |
| DB-07 | `usp_actualizar_*` | Renombrar con nombre válido | `nombre` actualizado, `codigo` intacto |
| DB-08 | `usp_actualizar_*` | Mismo nombre propio | éxito sin conflicto contra sí mismo |
| DB-09 | `usp_actualizar_*` | Nombre de otro registro | `GEN_003`, sin cambios |
| DB-10 | `usp_actualizar_*` | `nombre` fuera de 3–50 o `NULL` | `GEN_002` |
| DB-11 | `usp_actualizar_*` | `id` inexistente | `TPR_001` / `ARE_001` |
| DB-12 | `usp_cambiar_estado_*` | Inactivar registro activo | `estado = 0` |
| DB-13 | `usp_cambiar_estado_*` | Activar registro inactivo | `estado = 1` |
| DB-14 | `usp_cambiar_estado_*` | Repetir el mismo estado | éxito idempotente |
| DB-15 | `usp_cambiar_estado_*` | `id` inexistente / `@estaActivo` nulo | `TPR_001` / `ARE_001` / `GEN_002` |
| DB-16 | los tres | Ejecutor sin perfil `ADMINISTRADOR` (docente, coordinador, decano) | `estadoResultado = 0`, `SEC_001`, sin cambios |
| DB-17 | los tres | Ejecutor nulo / correlación nula | `GEN_002` / `CORR_001` |
| DB-18 | los tres | Falla forzada dentro del `*_interno` | rollback, `@@TRANCOUNT = 0` |
| DB-19 | vistas | `uv_tipo_programa` expone `codigo`; `uv_area` expone `codigo` y `estaActivaArea` | columnas presentes, valores del seed correctos |
| DB-20 | migración | Re-ejecutar `05_catalogos_area_estado_unicidad.sql` | idempotente; filas previas de `Area` quedan con `estado = 1` |
| DB-21 | índices | Insertar directo un `codigo` duplicado | la restricción única lo rechaza |
| DB-22 | regresión | `usp_crear_asignatura` y `usp_crear_programa_academico` con el seed | siguen funcionando con las vistas ampliadas |

## 2. Backend (`src/test/java`)

| ID | Clase | Escenarios |
| :-: | :--- | :--- |
| BE-01 | `CrearTipoProgramaUseCaseImplTest`, `CrearAreaUseCaseImplTest` | Delegación al puerto con actor y correlación; normalización/validación de `codigo` y `nombre`; propagación de `ConflictException`. |
| BE-02 | `ActualizarTipoProgramaUseCaseImplTest`, `ActualizarAreaUseCaseImplTest` | Delegación; `nombre` vacío rechazado; `NotFound`/`Conflict` propagados. |
| BE-03 | `CambiarEstado*UseCaseImplTest` | Delegación con `true`/`false`; estado nulo rechazado; errores propagados. |
| BE-04 | `ConsultarTiposProgramaUseCaseImplTest`, `ConsultarAreasUseCaseImplTest` | Lectura pública solo devuelve activos; lectura admin devuelve todos; mapeo de `codigo`/`activo`/`activa`. |
| BE-05 | `TipoProgramaJpaRepositoryTest`, `AreaJpaRepositoryTest` | Ejecutan el `EXEC` con todos los parámetros y la correlación; mapean fallos de DB; relectura por `codigo`. |
| BE-06 | `DbExceptionTranslatorTest` / `DbFailureClassifierTest` | `TPR_001` y `ARE_001` → `ResourceNotFoundException` (404); `GEN_003` → 409; `GEN_002` → 400; `SEC_001` → 403. |
| BE-07 | `AdminPortalControllerTest` | `POST/PUT/PATCH /admin/areas` ya no devuelven 501 (se retiran de la lista de stubs por cambio formal de contrato): 201/200, 400, 404, 409. |
| BE-08 | `AdminTipoProgramaControllerTest`, `TipoProgramaControllerTest` | Cada endpoint: éxito, 400 por Bean Validation (`codigo` de 2 o 4 caracteres, `activo` ausente), 404, 409; el actor sale de `AuthenticatedUserResolver`. |
| BE-09 | Seguridad (test propio, sin editar `RbacSecurityFilterChainTest`) | `DOCENTE`, `COORDINADOR`, `DECANO` reciben 403 en `/admin/tipos-programa` y `/admin/areas` (escritura y lectura); cualquier autenticado accede a `GET /tipos-programa`; sin token → 401. |
| BE-10 | `ArchUnit` | Casos de uso sin dependencias de infraestructura; controllers sin persistencia. |
| BE-11 | Wiring | El contexto arranca con los `@Bean` nuevos. |

Meta: 100 % de líneas y ramas en casos de uso; **≥ 80 % de cobertura sobre el código nuevo (Sonar), medido antes del PR**; gate global de JaCoCo (LINE ≥ 80 %, BRANCH ≥ 70 %) sin bajar.

## 3. Frontend (`*.spec.ts`)

| ID | Archivo | Escenarios |
| :-: | :--- | :--- |
| FE-01 | `admin-management.service.spec.ts` (áreas) | `crearArea` hace `POST` con `{codigo,nombre}`; `actualizarArea` hace `PUT {nombre}`; `cambiarEstadoArea(id, activa)` hace `PATCH {activa}`. La señal `areas` cambia solo si `exitoso`; un error HTTP no la modifica y se propaga. |
| FE-02 | `admin-management.service.spec.ts` (tipos) | Las cuatro operaciones de tipos de programa con la misma regla de éxito/error. |
| FE-03 | `admin-areas.component.spec.ts` | Crear, editar y alternar estado muestran éxito solo tras la respuesta; en 409/404/403 muestran `mensajeUsuario`; botones deshabilitados en curso; sin campos de facultad/coordinador/total. Se actualizan los tests que dependían de `facultadId` por cambio formal de contrato (D3). |
| FE-04 | `admin-catalogs.component.spec.ts` | Ya no redirige; lista tipos de programa; alta, edición (código de solo lectura) y switch de estado; errores del backend visibles. |
| FE-05 | `mock-backend.interceptor.spec.ts` | Solo si el interceptor simula estos endpoints: alinear al contrato. |
| FE-06 | Accesibilidad y reactividad | `OnPush`, `ChangeDetectionStrategy`, ausencia de `setInterval` y de `@Input/@Output`. |

## 4. Integración y E2E

- Script temporal `scratch/test_catalogos_admin.ps1`: JWT real de `ADMINISTRADOR` en Keycloak; ciclo crear → renombrar → inactivar → reactivar para tipo de programa y área; casos inválidos (400/404/409); tokens de `DOCENTE`, `COORDINADOR` y `DECANO` → 403; `GET /tipos-programa` como estudiante → 200 solo activos; consulta directa a SQL Server para comprobar persistencia.
- Puertos distintos de 8080/4200 (backend y frontend de esta pista); no se tocan las apps en ejecución.
- Gates: `.\mvnw.cmd test`, `npm run test:ci`, `ng build` (`npm run build`), `test_suite.sql`, `.\AsistenciasUCO-Infra\infra.ps1 verify` en `[PASS]` antes del cierre.

## 5. Estado RED

Pendiente: se genera tras la aprobación de `PLAN.md` y `CONTRACT.md` (esta fase no incluye código ni tests ejecutables).
