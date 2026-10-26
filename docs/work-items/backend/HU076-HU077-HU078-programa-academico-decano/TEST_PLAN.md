---
status: frozen-implemented
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# TEST_PLAN — HU076 / HU077 / HU078: Programa Académico (Rol Decano)

**Estado:** `RED_PLANNED` (borrador). Las pruebas se escriben en la fase 03, en orden **DB → Backend → Frontend**, sobre ramas `feature/HU076-HU077-HU078-programa-academico` creadas desde `develop` en worktrees propios (D10).

## Fuentes

- [PLAN](PLAN.md) (criterios CA-01…CA-08, decisiones D1–D9)
- [CONTRACT](CONTRACT.md) (`DRAFT`; las pruebas se derivan de él y se congelan junto con él)
- Skills: `uco-testing`, `uco-persistencia`, `uco-contratos`, `uco-seguridad`, `uco-backend-pagination-utc`
- Patrones existentes:
  - `GestioAsistenciaDB/test/test_usp_crear_coordinador.sql`
  - `test/test_transaction_ownership.sql`
  - `test/test_titularidad_jerarquica.sql`
  - `src/test/java/.../application/features/decano/crearcoordinador/**`
  - `DecanoPortalControllerTest`
  - `CoordinadorJpaCommandPatternTest`
  - `SqlStoredProcedureContractIT`
  - `RbacSecurityFilterChainTest`
  - `features/dean/dean-coordinadores/dean-coordinadores.component.spec.ts`

---

## 1. Matriz de comportamiento

| ID | Requisito | Precondición | Acción / entrada | Resultado esperado | Nivel |
|---|---|---|---|---|---|
| T-076-01 | CA-01: alta feliz | Decano D1 de la facultad F1; coordinador C1 disponible en F1; tipo `PRE` activo | `usp_crear_programa_academico` / `POST /decano/programas` | `estadoResultado=1`, `GEN_004`; fila en `uv_programa` con `estado=1`, `idCoordinador=C1`; HTTP 201 con el programa | DB, UseCase, Controller, IT, E2E |
| T-076-02 | CA-02: el coordinador queda vinculado | Después de T-076-01 | `GET /decano/coordinadores` | C1 aparece con `idPrograma` = el programa nuevo y ya no como disponible | DB (vista), E2E |
| T-076-03 | CA-03: nombre duplicado en la facultad | Programa "Sistemas" en F1 | Alta de "sistemas " (mayúsculas y espacios distintos) en F1 | `PROG_003`; sin filas nuevas; **el programa existente no se modifica** (regresión del upsert) | DB, UseCase (traducción de error), Controller 409 |
| T-076-04 | El nombre duplicado en **otra** facultad está permitido | "Sistemas" en F2 | Alta de "Sistemas" en F1 | Éxito; el programa de F2 queda intacto | DB |
| T-076-05 | CA-03: coordinador de otra facultad | C2 disponible en F2 | Alta en F1 con C2 | `PROG_005`, sin cambios | DB, Controller 409 |
| T-076-06 | CA-03 / D2: coordinador ocupado | C1 ya tiene programa | Alta con C1 | `PROG_005` | DB |
| T-076-07 | D2: concurrencia sobre el mismo coordinador | C3 disponible | Dos altas simultáneas con C3 (dos sesiones `sqlcmd`, o un test con `WAITFOR` y dos conexiones) | Exactamente una tiene éxito y la otra devuelve `PROG_005`; `@@TRANCOUNT=0` en ambas | DB (script de concurrencia en `scripts/database/tests/`) |
| T-076-08 | CA-03: tipo inexistente o inactivo | — | `@idTipoPrograma` aleatorio o inactivo | `PROG_004` | DB, Controller 400 |
| T-076-09 | CA-03: facultad ajena | D1 ejecuta sobre F2 | Alta con `@idFacultad=F2` | Falla la titularidad, sin cambios | DB |
| T-076-10 | RBAC en DB | Ejecutor con perfil COORDINADOR | Alta | Falla RBAC (`usp_validar_permiso_rbac_usuario_interno`) | DB |
| T-076-11 | Ejecutor NULL | — | `@idUsuarioEjecutor=NULL` | `GEN_002`; no se sustituye por un GUID por defecto | DB |
| T-076-12 | Validación de forma | — | Nombre vacío, > 50 caracteres o solo espacios; UUID inválido | DB `GEN_002`; HTTP 400 (validator) sin llamar al use case | DB, Validator, Controller |
| T-076-13 | Id explícito existente | Programa P1 | Alta con `@idPrograma=P1` | `PROG_002`; P1 intacto | DB |
| T-076-14 | CA-08: atomicidad | Se fuerza un error después de la validación (p. ej. violación de FK con un tipo borrado dentro de la transacción del test) | Alta | Rollback completo: 0 filas nuevas, `@@TRANCOUNT=0`, `estadoResultado=0` con `SYS_001` | DB |
| T-076-16 | Coordinador con usuario inactivo | Coordinador `estaActivoUsuario=0` | Alta con ese coordinador | `PROG_005` | DB |
| T-078-06 | D12: coordinador tras desactivar | P1 con C1; se desactiva P1 | Consulta `uv_coordinador` | C1 sigue con `idPrograma=P1` y `estaActivoCoordinador=0`, no figura como disponible; al reactivar P1 vuelve a 1 | DB |
| T-076-15 | CA-08: transacción externa del llamador | `BEGIN TRAN` externo + alta con error | — | Rollback solo hasta el savepoint; la transacción externa sigue viva (igual que en `test_transaction_ownership.sql`) | DB |
| T-077-01 | CA-04: editar nombre, tipo, modalidad y jornada | P1 en F1 | `usp_actualizar_programa_academico` / `PUT` | `GEN_005`; la vista refleja los valores nuevos; HTTP 200 | DB, UseCase, Controller, IT |
| T-077-02 | CA-04: reasignar el coordinador | P1 con C1; C4 disponible en F1 | `PUT` con C4 | P1→C4; C1 vuelve a figurar como disponible en `uv_coordinador` | DB, E2E |
| T-077-03 | R6: el ámbito del coordinador cambia tras reasignar | T-077-02 | `findProgramaIdByCoordinadorUsuario(C1)` / `(C4)` | C1 → vacío; C4 → P1 | IT (`InstitutionalScopeJpaRepository`) |
| T-077-04 | Modalidad o jornada inválida | — | Id inexistente o inactivo | `PROG_006` | DB, Controller 400 |
| T-077-05 | La unicidad excluye al propio programa | P1 "Sistemas" | `PUT` P1 con el mismo nombre | Éxito | DB |
| T-077-06 | Programa de otra facultad | P2 en F2 | D1 edita P2 | DB: falla la titularidad; HTTP **404** (no revela que existe) | DB, Controller |
| T-078-01 | CA-05: desactivar sin grupos activos | P1 sin grupos en el período vigente | `PATCH …/estado {estaActivo:false}` | `estado=0`; HTTP 200 | DB, UseCase, Controller |
| T-078-02 | D4: desactivar con grupos activos | P1 con un grupo activo en el período vigente | Desactivar | `PROG_007`; HTTP 409; estado intacto | DB, Controller |
| T-078-03 | Idempotencia | P1 inactivo | Desactivar otra vez | Éxito sin cambios | DB |
| T-078-04 | Reactivar con la facultad inactiva | F1 inactiva | Activar P1 | `PROG_008`, HTTP 409 | DB |
| T-078-05 | Un programa inactivo no aparece en los selectores | P1 inactivo | `GET /decano/programas?estaActivo=true` | P1 no aparece | DB, Front |
| T-108-01 | CA-06: paginación | 12 programas en F1 | Página 2, tamaño 5 | 5 filas, `totalRegistros=12`, orden por nombre | DB, IT, Controller |
| T-108-02 | CA-06: ámbito fail-closed | Programas en F1 y F2 | D1 consulta | Solo F1. Sin contexto de ejecutor → 0 filas | DB |
| T-108-03 | Filtros | — | `nombre`, `estaActivo`, `idTipoPrograma` | Filtran combinados | DB |
| T-108-04 | Paginación inválida | — | `pagina=0` o `tamano` > máximo | DB `PAG_001`; HTTP 400 | DB, Validator |
| T-108-05 | El contexto de sesión se restaura | Hay contexto previo | Consulta (con éxito y con error) | `SESSION_CONTEXT` previo restaurado | DB (igual que `usp_consultar_grupos_paginado`) |
| T-023-01 | Catálogo de tipos de programa | `PRE` y `POS` activos | `GET /api/v1/tipos-programa` | Lista con `id`, `codigo` y `nombre`, solo activos | UseCase, Controller |
| T-SEC-01 | D9: admin sin ámbito de decano | JWT `ADMINISTRADOR` | `GET` / `POST /decano/programas` | Pasa la cadena de filtros (comodín) y el use case responde **403** | Security slice + Controller |
| T-SEC-02 | Roles ajenos | JWT `COORDINADOR`, `DOCENTE` o `ESTUDIANTE` | Rutas `/decano/programas/**` | 403 en `SecurityFilterChain` | `RbacSecurityFilterChainTest` |
| T-SEC-03 | Sin token | — | Cualquier ruta nueva | 401 | `RbacSecurityFilterChainTest` |
| T-OBS-01 | Correlación | `X-Correlation-Id` presente | Alta | El mismo id llega a `@idCorrelacion` (verificado en el command port) | UseCase / adapter |
| T-ERR-01 | Mapeo de los códigos nuevos | — | `PROG_002…008`, `PAG_001` | HTTP según CONTRACT §2.8 | `DbFailureClassifierTest` (nuevo) |
| T-FE-01 | CA-07: sin programas quemados | — | `CatalogService.getProgramasAcademicos()` | Llama a `GET /decano/programas`; no hay ids `PROG-0x` | Jasmine (`catalog.service.spec.ts`) |
| T-FE-02 | Servicio | Respuestas 200/400/401/403/409/500 | `DeanProgramasService.*` | Actualiza los signals en el éxito; propaga el error sin convertirlo en éxito | Jasmine |
| T-FE-03 | Pantalla de programas | Lista vacía / con datos / cargando / error | `DeanProgramasComponent` | Estado vacío, tabla, `PaginationComponent` emite la página y llama a `consultar`, y el toast muestra `error.error.message` tal cual | Jasmine |
| T-FE-04 | Modal de alta y edición | — | Alta: el selector solo muestra coordinadores con `idPrograma===null`. Edición: incluye al actual | Emite `guardar` con el payload tipado; campos obligatorios bloquean el envío | Jasmine |
| T-FE-05 | Modal de estado | — | Confirmar o cancelar | Emite `confirmar(true/false)` | Jasmine |
| T-FE-06 | Selector de `dean-coordinadores` | — | Abrir el formulario de coordinador | Programas reales (mock HTTP) | Jasmine (`dean-coordinadores.component.spec.ts`) |
| T-ARCH-01 | Clean Architecture | — | ArchUnit | Las features nuevas no dependen de `infrastructure`; los controllers solo de input ports; `ProgramaAcademicoJpaRepository` solo en `secondary/persistence` | `CleanArchitectureRulesTest`, `JpaRepositoryArchitectureRulesTest`, `ControllersMustDependOnlyOnInputPortsTest` (sin excepciones nuevas) |
| T-WIR-01 | Wiring | — | Contexto con `DecanoWiringConfiguration` | Se crean los beans de los 4 use cases y sus interactors con sus puertos | `DecanoWiringConfigurationTest` (nuevo; hoy no existe) |

---

## 2. Pruebas RED a crear por capa

### 2.1 Base de datos (`GestioAsistenciaDB/test/`)

Cada archivo es transaccional (`BEGIN TRAN … ROLLBACK` al final), con fixtures propios (facultad, decano y coordinadores creados dentro del test, **sin depender de los GUIDs del seed**) y verificación final de `@@TRANCOUNT = 0`.

| Archivo | Casos |
|---|---|
| `test_usp_crear_programa_academico.sql` | T-076-01, 03–06, 08–15 |
| `test_usp_actualizar_programa_academico.sql` | T-077-01, 02, 04–06 |
| `test_usp_cambiar_estado_programa_academico.sql` | T-078-01…04 |
| `test_usp_consultar_programas_academicos.sql` | T-108-01…05, T-078-05 |
| `scripts/database/tests/test_programa_concurrencia.ps1` | T-076-07 (dos conexiones) |

- Los `:r` en `test_suite.sql` ⚠️ se agregan **solo en el commit final aparte**; mientras tanto cada archivo se ejecuta suelto con `sqlcmd`.
- Se agrega `usp_consultar_programas_academicos` a la lista de excepciones `READ_QUERY_RESULTSET` en `test/test_contract_closure.sql` ⚠️.
- `test_reactive_academic.sql`: **solo** se adapta la llamada a la firma nueva (sin `@codigo`), según R2 del PLAN; sus aserciones no cambian.

**Comando:**
```powershell
Get-Content -Path .\GestioAsistenciaDB\test_suite.sql -Raw | docker exec -i sql_server_asistencias /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "TuPasswordSeguro123" -C -y 35 -Y 35
```

### 2.2 Backend (`GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`)

| Clase de prueba | Casos | Tipo |
|---|---|---|
| `application/features/decano/crearprograma/usecase/impl/CrearProgramaUseCaseImplTest` | T-076-01, 03, 05, 12, T-SEC-01 (sin ámbito → `ForbiddenException`), T-OBS-01 | Unit (Mockito) |
| `…/crearprograma/usecase/domain/CrearProgramaDomainTest` y `…/primaryports/mapper/CrearProgramaMapperTest` | Reglas puras y mapeos | Unit |
| `…/actualizarprograma/usecase/impl/ActualizarProgramaUseCaseImplTest` | T-077-01, 02, 06 | Unit |
| `…/cambiarestadoprograma/usecase/impl/CambiarEstadoProgramaUseCaseImplTest` | T-078-01…03 | Unit |
| `…/consultarprogramas/usecase/impl/ConsultarProgramasUseCaseImplTest` | T-108-01, 04, T-SEC-01 | Unit |
| `application/features/tipoprograma/consultartiposprograma/**Test` | T-023-01 | Unit |
| `infrastructure/adapter/primary/controller/decano/DecanoPortalControllerTest` (se amplía) y `…/validation/ProgramaAcademicoRequestValidatorTest` | Status HTTP, envelope `ApiListResponse` / `ApiDataResponse`, 400 sin llamar al use case, 404 / 409 | Slice (MockMvc) |
| `infrastructure/adapter/primary/controller/tipoprograma/TipoProgramaControllerTest` | T-023-01 | Slice |
| `infrastructure/adapter/primary/security/RbacSecurityFilterChainTest` ⚠️ | T-SEC-01…03 | Security slice |
| `infrastructure/adapter/secondary/persistence/sqlserver/jpa/ProgramaAcademicoJpaCommandPatternTest` | Llamadas `EXEC` con los parámetros correctos, mapeo de la tupla y propagación del `idCorrelacion` | Unit (patrón de `CoordinadorJpaCommandPatternTest`) |
| `infrastructure/adapter/secondary/persistence/sqlserver/ProgramaAcademicoSqlServerIT` | T-076-01, 03, T-077-02, 03, T-108-01 contra SQL Server real | IT (Failsafe, `-Pintegration`) |
| `infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifierTest` (nuevo) | T-ERR-01 | Unit |
| `infrastructure/config/wiring/DecanoWiringConfigurationTest` (nuevo) | T-WIR-01 | Unit |
| ArchUnit existentes | T-ARCH-01 | Arquitectura |

**Cobertura:** use cases, validator y mappers nuevos al 100 % de líneas y ramas. El bundle mantiene JaCoCo LINE ≥ 80 % y BRANCH ≥ 70 %.

**Comandos:**
```powershell
cd GestioAsistenciaBackend; .\mvnw.cmd test
```
```powershell
cd GestioAsistenciaBackend; .\mvnw.cmd verify -Pintegration
```

### 2.3 Frontend (`GestioAsistenciaFrontend/src/app/`)

| Spec | Casos |
|---|---|
| `core/services/dean-programas.service.spec.ts` (nuevo) | T-FE-02 (`HttpTestingController`: 200/400/401/403/409/500) |
| `core/services/catalog.service.spec.ts` (se amplía) | T-FE-01 |
| `features/dean/dean-programas/dean-programas.component.spec.ts` (se amplía) | T-FE-03, T-078-05 |
| `features/dean/dean-programas/components/dean-programa-form-modal.component.spec.ts` (nuevo) | T-FE-04 |
| `features/dean/dean-programas/components/dean-programa-estado-modal.component.spec.ts` (nuevo) | T-FE-05 |
| `features/dean/dean-coordinadores/dean-coordinadores.component.spec.ts` (se amplía) | T-FE-06 |

**Comandos:**
```powershell
cd GestioAsistenciaFrontend; npm run test:ci
```
```powershell
cd GestioAsistenciaFrontend; npm run verify
```

### 2.4 E2E (capa 4)

`scratch/test_hu076.ps1`:
1. Token Keycloak de `decano.ingenieria`.
2. Crea un coordinador disponible (`POST /decano/coordinadores`).
3. `POST /decano/programas`: espera 201.
4. Repite el mismo nombre: espera 409.
5. `PUT` con modalidad y jornada: espera 200.
6. `PATCH estado false`: espera 200 (o 409 si hay grupos activos).
7. `GET` paginado: espera 200.
8. Consulta `sqlcmd` a `uv_programa` y `uv_coordinador` para corroborar el vínculo.
9. Token de `coordinador.sistemas` contra `/decano/programas`: espera 403.

Al cerrar, el caso se agrega a `scripts/general/tests/test_all_hus.ps1`.

---

## 3. Efectos secundarios y rollback

- Las pruebas DB no dejan datos (rollback). El E2E crea datos reales: al final los desactiva y lo documenta en `VALIDATION.md`. No hay `DELETE` físico salvo los fixtures propios.
- La migración D3 se prueba desde un esquema limpio (`deploy_schema.ps1`) y sobre un esquema existente (idempotencia: se ejecuta dos veces).

---

## 4. RED_SNAPSHOT (se completa en la fase 03)

| Repo | Commit base | Archivos de prueba | SHA-256 / commit RED | Comando | Exit code | Falla esperada |
|---|---|---|---|---|---|---|
| GestioAsistenciaDB | — | §2.1 | — | `test_suite.sql` | — | Los SP nuevos no existen; el alta actual hace upsert (T-076-03) |
| GestioAsistenciaBackend | — | §2.2 | — | `mvnw test` | — | Faltan las clases y los puertos; el controller no tiene las rutas |
| GestioAsistenciaFrontend | — | §2.3 | — | `npm run test:ci` | — | Falta el servicio; `catalog.service` devuelve datos quemados |

## 5. Reglas de congelamiento

- Después del RED, **las pruebas no se modifican**. Cualquier cambio exige un registro `TEST_CONTRACT_CONFLICT` en `VALIDATION.md` con su justificación (error genuino del test o cambio formal del contrato) y aprobación del owner.
- Prohibido relajar aserciones, borrar casos, silenciar validaciones o *mockear* para evitar un fallo real.

## 6. Falsos positivos a evitar

- Cobertura Sonar: el código nuevo (use cases, mappers, validator, adapter, servicio y modales del front) se mide con JaCoCo y `ng test --code-coverage` y debe alcanzar ≥ 80 % (objetivo 100 % en use cases y validadores).
- Fixtures que reutilizan los GUIDs del seed (la colisión `E1F2…006`, REG-000 §6): cada test crea sus propias entidades.
- Probar el ámbito solo en el use case: el ámbito **también** se prueba en DB (T-076-09, T-108-02).
- Que el test de concurrencia T-076-07 "pase" porque las dos llamadas se ejecutan en serie: hay que verificar que ambas conexiones se solapan (log de tiempos).
- Specs de front que solo prueban el *mock mode* (`useFrontendMocks`): las specs usan `HttpTestingController` con la ruta real.
