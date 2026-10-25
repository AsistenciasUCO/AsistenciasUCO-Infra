---
status: draft
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-21
---

# TEST_PLAN — HU062 / HU089 / HU063 / HU090 / HU091: Vinculación de docentes al programa

**Estado:** `RED_PLANNED` (borrador). Las pruebas se escriben en la fase 03, en orden DB → Backend → Frontend, en ramas `feature/HU091-vinculacion-docente` creadas desde `develop` después del merge de HU035/036 y del cierre del grupo A.

## Fuentes
- [PLAN](PLAN.md) (CA-01…CA-09, D1–D9) y [CONTRACT](CONTRACT.md) (`DRAFT`).
- Skills: `uco-testing`, `uco-persistencia`, `uco-seguridad`, `uco-contratos`.
- Patrones:
  - `test/test_usp_crear_coordinador.sql` y `test/test_transaction_ownership.sql`
  - `CrearCoordinadorUseCaseImplTest`, `CoordinadorPortalControllerTest`, `CoordinadorJpaCommandPatternTest`
  - `KeycloakIdentityProviderAdapterTest` (`FakeKeycloakAdminServer`), `RbacSecurityFilterChainTest`
  - `coordinator-docentes.component.spec.ts`

## 1. Matriz de comportamiento

| ID | Requisito | Acción | Resultado esperado | Nivel |
|---|---|---|---|---|
| T-091-01 | CA-05: alta nueva | Modo nuevo con datos válidos | Se crean `Usuario`, `Docente` y `DocentePrograma` (`estado=1`); `GEN_004`; HTTP 201; `crearCuenta(..., DOCENTE)` con la contraseña en claro y el hash en DB | DB, UseCase, Controller, IT, E2E |
| T-091-02 | CA-06: docente existente de otro programa | `idDocente` + tipo de vinculación | Solo una fila nueva en `DocentePrograma`; `crearCuenta` con contraseña null; no se duplica el usuario | DB, UseCase |
| T-091-03 | R6: usuario que aún no es docente | `idUsuario` | Se crean `Docente` y el vínculo; se asegura el rol `DOCENTE` | DB, UseCase |
| T-091-04 | Vínculo duplicado | Vincular dos veces | `DOC_006`, 409, sin cambios | DB, Controller |
| T-091-05 | Persona existente en modo nuevo | Documento o correo ya registrados | `DOC_003`, 409, 0 filas nuevas | DB |
| T-091-06 | Modo inválido | Ninguno o ambos modos | DB `DOC_005`; HTTP 400 desde el validator | DB, Validator |
| T-091-07 | Tipo de vinculación inválido | Inexistente o inactivo | `DOC_004`, 400 | DB |
| T-091-08 | Programa ajeno | El ejecutor no coordina `@idPrograma` | `SEC_002`, sin cambios | DB |
| T-091-09 | RBAC | Ejecutor DOCENTE o DECANO | `SEC_001` | DB |
| T-091-10 | Docente de otra institución | `idDocente` externo | `SEC_002` o `DOC_001` | DB |
| T-091-11 | CA-08: atomicidad | Falla forzada después de crear el usuario | Rollback total, `@@TRANCOUNT=0` | DB |
| T-091-12 | Transacción externa | `BEGIN TRAN` del llamador | Rollback al savepoint | DB |
| T-091-13 | R7: concurrencia | Dos vínculos simultáneos del mismo par | Uno OK y el otro `DOC_006` | DB (script con 2 conexiones) |
| T-091-14 | DA-5: contraseña | Modo nuevo sin contraseña o débil | 400; no se llama al use case | Validator |
| T-091-15 | R5: rango del documento | Documento > `INT` | 400 | Validator |
| T-091-16 | R4: Keycloak caído | `FakeKeycloakAdminServer` devuelve 500 | `InternalApplicationException` → 500 controlado; el vínculo en DB persiste; log ERROR sin PII | UseCase, IT |
| T-091-17 | Reintento idempotente después de R4 | Repetir con modo existente | 201 o 409 controlado; la cuenta se crea | UseCase |
| T-062-01 | CA-01: directorio paginado | 12 vínculos, página 2 de tamaño 5 | 5 filas, `total=12`, orden por nombre | DB, IT, Controller |
| T-062-02 | CA-02: docente sin grupos | Recién vinculado | Aparece con `totalGruposPrograma=0` | DB |
| T-062-03 | Ámbito fail-closed | Vínculos en P1 y P2 | El coordinador de P1 solo ve P1; sin contexto → 0 filas | DB |
| T-063-01 | CA-03: búsqueda | `busqueda=1017` / `busqueda=ros` | Prefijo de documento / contiene en el nombre | DB, Front |
| T-089-01 | Filtros | `estaActivo`, `idTipoVinculacion` | Filtran combinados | DB |
| T-091-18 | Candidatos | `busqueda` de 3 o más caracteres | Solo la misma institución, excluye a los ya vinculados, sin correo, tope por parámetro | DB, Controller |
| T-091-19 | Candidatos: búsqueda corta | 2 caracteres | `DOC_007`, 400 | DB, Validator |
| T-090-01 | CA-04: catálogo | `GET /tipos-vinculacion` | Solo los activos | UseCase, Controller |
| T-MIG-01 | Migración idempotente | Ejecutarla 2 veces | Sin errores ni duplicados | DB |
| T-MIG-02 | R2: backfill | Docente con grupos en P1 antes de migrar | Queda con un vínculo en P1 con el tipo por defecto (resuelto por código) | DB |
| T-MIG-03 | D7: retiro del SP | Después de migrar | `OBJECT_ID('dbo.usp_registrar_docente_en_grupo_autonomo') IS NULL` | DB |
| T-DOC-02 | Mensaje corregido | `usp_sincronizar_docente_interno` con un usuario que ya es docente | `DOC_002` (no `VAL_006`) | DB |
| T-SEC-01 | D8: admin | JWT ADMINISTRADOR en `/coordinador/docentes` | 403 desde el use case | Controller |
| T-SEC-02 | Roles ajenos o sin token | DOCENTE, ESTUDIANTE o anónimo | 403 / 401 | `RbacSecurityFilterChainTest` |
| T-D6-01 | Retiro legacy | `POST /docentes`, `POST /docentes/asignaciones/grupo` | 404; los `GET /docentes/**` siguen respondiendo 200 | Controller slice |
| T-ERR-01 | Mapeo de códigos | `DOC_001…007` | HTTP según CONTRACT §2.7 | `DbFailureClassifierTest` |
| T-WIR-01 | Wiring | Contexto | Beans nuevos en `CoordinadorWiringConfiguration` y `TipoVinculacionWiringConfiguration` | `CoordinadorWiringConfigurationTest` (se amplía), `TipoVinculacionWiringConfigurationTest` (nuevo) |
| T-ARCH-01 | Arquitectura | ArchUnit | Sin excepciones nuevas | ArchUnit existentes |
| T-FE-01 | Servicio | 200/400/401/403/409/500 | Actualiza los signals; los errores se propagan | Jasmine (`coordinator-management.service.spec.ts`) |
| T-FE-02 | Directorio | Vacío, con datos, paginación, búsqueda con debounce (`fakeAsync` + `tick(300)`) | Una sola llamada HTTP por término; sin `setInterval` | Jasmine (componente) |
| T-FE-03 | Formulario nuevo | Sin GUID quemado; contraseña obligatoria; sin especialidad | Emite `guardar` con el payload tipado | Jasmine (modal nuevo) |
| T-FE-04 | Modo existente | El picker carga candidatos y se elige uno | Envía `{ idDocente, idTipoVinculacion }` | Jasmine |
| T-FE-05 | Toggle deshabilitado | — | El botón de estado está deshabilitado y no llama a `toggleDocenteStatus` | Jasmine |
| T-FE-06 | Errores | 409 `DOC_006` | El toast muestra `error.error.message` tal cual | Jasmine |
| T-FE-07 | Selector en el formulario de grupo | Docente recién vinculado | Disponible como titular en el alta o edición de grupo (HU076B) | Jasmine / E2E |

## 2. Pruebas RED por capa

**DB (`GestioAsistenciaDB/test/`):**
- `test_usp_vincular_docente_programa.sql`: T-091-01…12, T-DOC-02.
- `test_usp_consultar_docentes_programa.sql`: T-062-*, T-063-01, T-089-01.
- `test_usp_consultar_candidatos_docente_programa.sql`: T-091-18, 19.
- `test_migracion_docente_programa.sql`: T-MIG-*.
- `scripts/database/tests/test_docente_programa_concurrencia.ps1`: T-091-13.

Cada archivo es transaccional, con fixtures propios (sin los GUIDs del seed) y con `@@TRANCOUNT = 0` al final. Se agregan los `:r` en `test_suite.sql` ⚠️ y la excepción de `READ_QUERY_RESULTSET` en `test_contract_closure.sql` ⚠️. El `:r` del test autónomo se retira junto con el SP (D7).

**Backend:**
- `application/features/coordinador/vinculardocenteprograma/**Test` (use case al 100 % de ramas: 3 modos, Keycloak OK o falla, sin ámbito).
- `consultardocentesprograma/**Test` y `consultarcandidatosdocente/**Test`.
- `tipovinculacion/**Test`.
- `CoordinadorPortalControllerTest` (se amplía) y `VincularDocenteProgramaRequestValidatorTest`.
- `DocenteProgramaJpaCommandPatternTest`.
- `DocenteProgramaSqlServerIT` (Failsafe, con SQL Server real).
- `DbFailureClassifierTest`.
- `RbacSecurityFilterChainTest` ⚠️.
- `DocenteControllerTest` (T-D6-01).

**Frontend:**
- `coordinator-management.service.spec.ts`
- `coordinator-docentes.component.spec.ts`
- `components/coordinator-docente-form-modal.component.spec.ts` (nuevo)

**E2E** (`scratch/test_hu091.ps1`):
1. Token de `coordinador.sistemas`.
2. `GET /tipos-vinculacion`.
3. `POST` en modo nuevo: espera 201.
4. Login en Keycloak del docente nuevo: obtiene un token con el rol `DOCENTE`.
5. Repetir: espera 409.
6. `GET candidatos?busqueda=ros` y luego `POST` en modo existente: espera 201.
7. `GET` paginado con búsqueda.
8. `sqlcmd` sobre `uv_docente_programa`.
9. Token de `decano.ingenieria` en `/coordinador/docentes`: espera 403.

**Comandos:**
- `test_suite.sql` en `sql_server_asistencias` (AGENTS.md §4.1)
- `.\mvnw.cmd test` y `.\mvnw.cmd verify -Pintegration`
- `npm run test:ci` y `npm run verify`

**Cobertura:** use cases y validator nuevos al 100 %. Gate JaCoCo LINE ≥ 80 % y BRANCH ≥ 70 %.

## 3. Efectos secundarios y rollback

- Las pruebas DB hacen rollback.
- El E2E crea un usuario real en DB y Keycloak; se documenta en `VALIDATION.md`. Desactivarlo depende del grupo E, así que se usa un documento de prueba reservado.
- La migración se prueba sobre un esquema limpio y sobre uno existente con datos.

## 4. RED_SNAPSHOT (fase 03)

| Repo | Commit base | Archivos | SHA-256 / commit RED | Comando | Exit | Falla esperada |
|---|---|---|---|---|---|---|
| GestioAsistenciaDB | — | §2 DB | — | `test_suite.sql` | — | No existen la tabla, las vistas ni los SP |
| GestioAsistenciaBackend | — | §2 Backend | — | `mvnw test` | — | Faltan las features; los endpoints responden 501 |
| GestioAsistenciaFrontend | — | §2 Frontend | — | `npm run test:ci` | — | Faltan los métodos y el modal; hay un GUID quemado |

## 5. Congelamiento y falsos positivos

- Después del RED las pruebas no se modifican sin un registro `TEST_CONTRACT_CONFLICT` aprobado. Prohibido relajarlas.
- Hay que evitar:
  - fixtures con GUIDs del seed (colisión `E1F2…006`);
  - probar el ámbito solo en el use case (también se prueba en DB: T-062-03, T-091-08);
  - specs que solo prueben el *mock mode*;
  - un test de concurrencia que corra en serie;
  - verificar Keycloak solo con mocks de Mockito (T-091-16 usa `FakeKeycloakAdminServer`).
