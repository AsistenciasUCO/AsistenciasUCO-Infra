---
status: frozen-implemented
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# CONTRACT — HU076 / HU077 / HU078: Programa Académico (Rol Decano)

> **Work Item:** `HU076-HU077-HU078-programa-academico-decano`
> **Estado:** `DRAFT`: no está congelado y no tiene `.sha256`. Pasa a `CONTRACT_FROZEN` cuando el owner apruebe y resuelva D1–D12 del [PLAN](PLAN.md).
> **Supuestos del borrador:** se toman las recomendaciones del PLAN: D1(a) coordinador obligatorio, D2(a) relación 1↔1, D3(a) catálogos de modalidad y jornada, D4(a) bloqueo con grupos activos, D5(a) UI en `dean-programas`, D6(a), D7(a) sin `@codigo`, D8(b) sin SSE, D9(b) admin → 403, D10(a) ramas desde develop, D11(a) `ApiListResponse`, D12(a) coordinador queda vinculado. Si alguna decisión cambia, se marca en el lugar del contrato que corresponde.
> **Conformidad:** `constitution.md`, `AGENTS.md` §3.3, `GUIA_METODICA_IMPLEMENTACION_HU.md`.

---

## 1. Matriz AS-IS / TARGET del contrato

| Elemento | AS-IS | TARGET | Compatibilidad |
|---|---|---|---|
| `dbo.usp_crear_programa_academico` | UPSERT por id/nombre, `@codigo` sin uso, sin transacción | Solo alta, transaccional y con validaciones (§2.3) | **Rompe la firma** (sale `@codigo`; `@idPrograma` pasa a opcional). Único invocador: `test/test_reactive_academic.sql` |
| `dbo.usp_actualizar_programa_academico` | — | Nuevo (§2.4) | Aditivo |
| `dbo.usp_cambiar_estado_programa_academico` | — | Nuevo (§2.5) | Aditivo |
| `dbo.usp_consultar_programas_academicos` | — | Nuevo, paginado (§2.6) | Aditivo |
| `dbo.uv_programa` / `dbo.uv_auth_programa` | Sin tipo, modalidad ni jornada | Columnas nuevas al final (§2.2) | Aditivo (las columnas actuales no cambian) |
| `dbo.Modalidad`, `dbo.Jornada` + `Programa.modalidad/jornada` | — | Nuevos (D3) | Aditivo (FK nullable) |
| HTTP `/api/v1/decano/programas/**`, `/api/v1/tipos-programa` | — | Nuevos (§3) | Aditivo; fuera de `openapi-golden-path.yaml` |

---

## 2. Contrato de Base de Datos (SQL Server 2022+)

### 2.1 Reglas comunes a todos los SP de este WI

1. `SET NOCOUNT ON; SET XACT_ABORT ON;`
2. Patrón de `usp_cambiar_estado_facultad.sql` + `_interno.sql` (HU111): la **fachada** valida (correlación, ejecutor, RBAC, titularidad, existencia, reglas) y el **interno** abre la transacción con `SET XACT_ABORT ON`. Savepoints de ≤ 32 caracteres (`sp_crear_programa_academico`, `sp_actualizar_programa`, `sp_cambiar_estado_programa`). Detalle: guardar `@@TRANCOUNT` inicial; `BEGIN TRANSACTION` si es 0, o `SAVE TRANSACTION <sp>` si ya hay una transacción abierta; `COMMIT` solo si la transacción es propia; en el `CATCH`, `IF @@TRANCOUNT > 0` + `XACT_STATE()` → `ROLLBACK` total o al savepoint.
3. Los parámetros opcionales se evalúan con `@x IS NULL`. **No** se usa `ufn_obtener_parametro_guid(..., 'GUID_DEFECTO_CORRELACION')` para sustituir NULL (sí se puede usar para leer parámetros de negocio).
4. Validación de ámbito **dentro del SP**: `usp_validar_permiso_rbac_usuario_interno @codigoPerfilRequerido='DECANO'` + `usp_validar_titularidad_jerarquica_interno @tipoEntidadPadre='FACULTAD'`. `@idUsuarioEjecutor` es obligatorio (`GEN_002` si viene NULL).
5. Lecturas en los SP públicos **solo sobre vistas** (`uv_*`); escrituras delegadas en `usp_*_interno`.
6. Mensajes por código (`usp_obtener_mensaje_catalogo`). No hay textos ni GUIDs quemados; los estados salen del catálogo.
7. **Comandos:** resultset canónico de 4 columnas (`idCorrelacion`, `mensajeUsuarioResultado`, `mensajeTecnicoResultado`, `estadoResultado`), compatible con `ProcedureResultMapper` / `JpaProcedureExecutor`.
8. **Consulta:** `READ_QUERY_RESULTSET` (filas + `totalRegistros`), con el contexto de ejecutor aplicado y restaurado igual que en `usp_consultar_grupos_paginado.sql`. Queda excluido de la regla de 4 columnas en `test/test_contract_closure.sql`.

### 2.2 Vistas

**`dbo.uv_programa`** mantiene sus columnas actuales y agrega al final:

| Columna | Tipo | Origen |
|---|---|---|
| `idTipoPrograma` | `UNIQUEIDENTIFIER` | `Programa.tipoDePrograma` |
| `nombreTipoPrograma` | `NVARCHAR(50)` | `uv_tipo_programa.nombre` |
| `idModalidad` / `nombreModalidad` | `UNIQUEIDENTIFIER NULL` / `NVARCHAR(50) NULL` | `Modalidad` (LEFT JOIN, D3) |
| `idJornada` / `nombreJornada` | `UNIQUEIDENTIFIER NULL` / `NVARCHAR(50) NULL` | `Jornada` (LEFT JOIN, D3) |

**`dbo.uv_auth_programa`** proyecta las mismas columnas nuevas sin cambiar su filtro de autorización.

### 2.3 `dbo.usp_crear_programa_academico` (HU076)

| Parámetro | Tipo | Req. | Regla |
|---|---|:-:|---|
| `@idPrograma` | `UNIQUEIDENTIFIER = NULL` | No | Si es NULL se genera con `NEWID()`. Si viene y ya existe → `PROG_002` |
| `@nombre` | `NVARCHAR(50)` | Sí | `TRIM`, no vacío (`GEN_002`), ≤ 50 caracteres. Único por facultad, sin distinguir mayúsculas (`PROG_003`) |
| `@idTipoPrograma` | `UNIQUEIDENTIFIER` | Sí | Existe y está activo en `uv_tipo_programa` (`PROG_004`) |
| `@idCoordinador` | `UNIQUEIDENTIFIER` | Sí (D1) | Existe en `uv_coordinador`, pertenece a `@idFacultad` o está disponible sin programa en ella, está activo y **no tiene programa** (`PROG_005`). Se lee con `UPDLOCK, HOLDLOCK` para serializar dos altas con el mismo coordinador |
| `@idModalidad` / `@idJornada` | `UNIQUEIDENTIFIER = NULL` | No | Si vienen, existen y están activos en su catálogo (`PROG_006`) |
| `@idFacultad` | `UNIQUEIDENTIFIER` | Sí | Existe y está activa en `uv_facultad` (`GEN_001` con `'Facultad'`; no hay códigos `FAC_*` en `04_mensaje.sql`); titularidad del decano |
| `@idCorrelacion` | `UNIQUEIDENTIFIER` | Sí | `usp_validar_id_correlacion_esta_presente_interno` |
| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | Sí | RBAC `DECANO` + titularidad `FACULTAD` |

- **Delegación:** `usp_validar_programa_academico_interno` (todas las validaciones de negocio, OUTPUT con la tupla) → `usp_insertar_programa_academico_interno` (`INSERT` con `estado = 1`).
- **Éxito:** `estadoResultado = 1`, mensaje `GEN_004` ("Programa Academico").
- ⚠️ **Firma eliminada:** `@codigo INT` (D7).

### 2.4 `dbo.usp_actualizar_programa_academico` (HU077)

| Parámetro | Tipo | Req. | Regla |
|---|---|:-:|---|
| `@idPrograma` | `UNIQUEIDENTIFIER` | Sí | Existe en `uv_programa` y es de la facultad del ejecutor (`PROG_001`, titularidad) |
| `@nombre` | `NVARCHAR(50)` | Sí | Igual que en el alta; la unicidad excluye al propio `@idPrograma` |
| `@idTipoPrograma` | `UNIQUEIDENTIFIER` | Sí | `PROG_004` |
| `@idModalidad` / `@idJornada` | `UNIQUEIDENTIFIER = NULL` | No | `PROG_006`. NULL = se deja sin valor |
| `@idCoordinador` | `UNIQUEIDENTIFIER` | Sí | Si es distinto del actual: mismas reglas que `PROG_005`. Al reasignar, el coordinador anterior queda disponible (ningún programa lo referencia) |
| `@idCorrelacion`, `@idUsuarioEjecutor` | | Sí | Igual que en el alta |

- **Éxito:** `GEN_005` ("Programa Academico"; el código ya existe en `04_mensaje.sql`).

### 2.5 `dbo.usp_cambiar_estado_programa_academico` (HU078)

| Parámetro | Tipo | Req. | Regla |
|---|---|:-:|---|
| `@idPrograma` | `UNIQUEIDENTIFIER` | Sí | `PROG_001`, titularidad |
| `@estaActivo` | `BIT` | Sí | Estado destino explícito, idempotente. Pedir el mismo estado → éxito sin cambios |
| `@idCorrelacion`, `@idUsuarioEjecutor` | | Sí | |

- **Regla D4:** si `@estaActivo = 0` y existen grupos activos del programa en el período vigente (vía `uv_grupo` / `uv_plan_estudio`) → `PROG_007`, sin cambios.
- **Reactivación:** permitida si la facultad está activa (si no, `PROG_008`).

### 2.6 `dbo.usp_consultar_programas_academicos` (HU108, solo listado)

| Parámetro | Tipo | Req. | Regla |
|---|---|:-:|---|
| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | Sí | Aplica el contexto de ejecutor; las filas salen de `uv_auth_programa` (fail-closed) |
| `@idCorrelacion` | `UNIQUEIDENTIFIER` | Sí | |
| `@numeroPagina` | `INT` | Sí | ≥ 1 (`PAG_001`). No se reutiliza `VAL_001`, que significa "número de identificación obligatorio" |
| `@tamanoPagina` | `INT` | Sí | Entre 1 y el parámetro nuevo `PAGINACION / TAMANO_MAXIMO` (`schema/seed/03_parametro.sql`, propuesta 100) (`PAG_001`) |
| `@nombre` | `NVARCHAR(50) = NULL` | No | `LIKE` por contiene |
| `@estaActivo` | `BIT = NULL` | No | |
| `@idTipoPrograma` | `UNIQUEIDENTIFIER = NULL` | No | |

- **Resultset:** las columnas de `uv_programa` (§2.2) + `totalRegistros = COUNT(*) OVER()`, con `ORDER BY nombrePrograma` + `OFFSET (@numeroPagina-1)*@tamanoPagina ROWS FETCH NEXT @tamanoPagina ROWS ONLY`.
- **Ámbito:** el decano solo ve su facultad, por el filtro de `uv_auth_programa`.

### 2.7 DDL (solo con D3 aprobada): `schema/tables/` + seed (V8: no hay runner de migraciones)

- Despliegue en una BD existente: ejecutar `Modalidad.sql`, `Jornada.sql`, `Programa.sql` y el seed (todos idempotentes).
- Tablas `dbo.Modalidad` y `dbo.Jornada` (`id UNIQUEIDENTIFIER PK`, `codigo NVARCHAR(3) UNIQUE`, `nombre NVARCHAR(50)`, `estado BIT`), creadas con `IF OBJECT_ID(...) IS NULL`.
- `ALTER TABLE dbo.Programa ADD modalidad UNIQUEIDENTIFIER NULL, jornada UNIQUEIDENTIFIER NULL` + FKs, con `IF COL_LENGTH(...) IS NULL`.
- Seed idempotente (`MERGE`, igual que `05_tipo_programa.sql`): `PRE` Presencial, `VIR` Virtual, `HIB` Híbrida / `DIU` Diurna, `NOC` Nocturna, `FDS` Fin de semana (valores sujetos a aprobación).
- Script `down` documentado en `VALIDATION.md`.
- También se actualizan las tablas en `schema/tables/` (`Programa.sql` y los nuevos `Modalidad.sql` / `Jornada.sql`), para que `deploy_schema.ps1` reproduzca el esquema desde cero.

### 2.8 Códigos de mensaje nuevos (`schema/seed/04_mensaje.sql` + App Configuration `messages:user:<CODIGO>` / `messages:technical:<CODIGO>`)

| Código | Tipo | HTTP sugerido | Mensaje al usuario (propuesta) |
|---|---|:-:|---|
| `PROG_001` (ya existe) | BUSINESS_ERROR | 404 | El programa académico especificado no existe en el sistema. |
| `PROG_002` | BUSINESS_ERROR | 409 | Ya existe un programa académico con el identificador indicado. |
| `PROG_003` | BUSINESS_ERROR | 409 | Ya existe un programa académico con ese nombre en la facultad. |
| `PROG_004` | BUSINESS_ERROR | 400 | El tipo de programa indicado no existe o está inactivo. |
| `PROG_005` | BUSINESS_ERROR | 409 | El coordinador seleccionado no está disponible para esta facultad o ya tiene un programa asignado. |
| `PROG_006` | BUSINESS_ERROR | 400 | La modalidad o jornada indicada no existe o está inactiva. |
| `PROG_007` | BUSINESS_ERROR | 409 | No se puede desactivar el programa porque tiene grupos activos en el período vigente. |
| `PROG_008` | BUSINESS_ERROR | 409 | No se puede activar el programa porque su facultad está inactiva. |
| `PAG_001` | BUSINESS_ERROR | 400 | Los parámetros de paginación no son válidos. |

En este WI solo se agregan `PROG_002…008` y `PAG_001` (`FAC_*`/`DEC_*` viven en la rama HU117, D10). La correspondencia código → HTTP **es explícita por código** en `infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` (p. ej. línea 58: `"SES_001", "PROG_001", "PER_001" -> RESOURCE_NOT_FOUND`). Los códigos nuevos se agregan ahí (404 / 409 / 400 según la tabla), y su prueba va en `DbFailureClassifierTest`.

---

## 3. Contrato HTTP REST (Backend)

Comunes:
- Base `/api/v1`. Autorización por el comodín `/api/v1/decano/**` → `DECANO | ADMINISTRADOR` (`SecurityConfig.java:134`).
- **Ámbito en el use case:** `InstitutionalScopePort.findFacultadIdByDecanoUsuario(actor)`; si viene vacío → `403` (D9).
- `X-Correlation-Id` propagado.
- Errores con `ApiErrorResponse` (`message` = `mensajeUsuario` del catálogo).
- Validación de forma (UUID, longitudes, obligatorios) en `ProgramaAcademicoRequestValidator` → `400`.

### 3.1 `GET /api/v1/decano/programas` (HU108, listado)
- **Query:** `pagina` (int ≥ 1, por defecto 1), `tamano` (int, por defecto 10, máximo el del parámetro), `nombre?`, `estaActivo?` (bool), `idTipoPrograma?` (UUID). Los nombres de `pagina` y `tamano` siguen a `GET /api/v1/docente/reclamos`.
- **200:** `ApiListResponse<ProgramaAcademicoResponse>` (D11: `ApiPageResponse` no existe en el código) = `{ exitoso: true, datos: [...], total: <totalRegistros> }`.
- **ProgramaAcademicoResponse:**
  ```json
  {
    "id": "uuid",
    "nombre": "Ingeniería de Sistemas",
    "idTipoPrograma": "uuid", "nombreTipoPrograma": "pregrado",
    "idModalidad": "uuid|null", "nombreModalidad": "Presencial|null",
    "idJornada": "uuid|null", "nombreJornada": "Diurna|null",
    "idCoordinador": "uuid", "nombreCoordinador": "Nombre Apellido",
    "idFacultad": "uuid", "nombreFacultad": "Facultad de Ingeniería",
    "estaActivo": true
  }
  ```
- **Errores:** 400 (paginación inválida), 401, 403.

### 3.2 `POST /api/v1/decano/programas` (HU076)
- **Request (`CrearProgramaRequest`):**
  ```json
  {
    "nombre": "Ingeniería de Sistemas",
    "idTipoPrograma": "uuid",
    "idCoordinador": "uuid",
    "idModalidad": "uuid|null",
    "idJornada": "uuid|null"
  }
  ```
  `idFacultad` **no** viene en el request: se resuelve del ámbito del decano.
- **201:** `ApiDataResponse<ProgramaAcademicoResponse>` con el programa creado. El use case lo relee del query port por el id generado en el backend (`UUID.randomUUID()` se pasa como `@idPrograma`, de modo que el backend conoce el id sin leerlo de la DB).
- **Errores:** 400 (forma / `PROG_004` / `PROG_006`), 401, 403 (sin ámbito o RBAC de DB), 409 (`PROG_003` / `PROG_005`).

### 3.3 `PUT /api/v1/decano/programas/{id}` (HU077)
- **Request (`ActualizarProgramaRequest`):** los mismos campos que el alta (reemplazo completo).
- **200:** `ApiDataResponse<ProgramaAcademicoResponse>`.
- **Errores:** 400, 401, 403, 404 (`PROG_001`, o programa de otra facultad: se responde **404** para no revelar que existe), 409.

### 3.4 `PATCH /api/v1/decano/programas/{id}/estado` (HU078)
- **Request (`CambiarEstadoProgramaRequest`):** `{ "estaActivo": false }`. El estado destino es explícito, no un *toggle* ciego, para que la operación sea idempotente.
- **200:** `ApiDataResponse<ProgramaAcademicoResponse>`.
- **Errores:** 400, 401, 403, 404, 409 (`PROG_007`).

### 3.5 `GET /api/v1/tipos-programa` (HU023, lectura)
- Cualquier usuario autenticado (`/api/v1/**`).
- **200:** `List<TipoProgramaDTO>` = `[{ "id": "uuid", "codigo": "PRE", "nombre": "pregrado" }]`, solo los activos. Mismo patrón y envelope que `GET /api/v1/tipos-identificacion`.
- Si D3 se aprueba, la fase 02 decide si `modalidades` y `jornadas` se exponen igual (`GET /api/v1/modalidades-programa`, `GET /api/v1/jornadas-programa`) o dentro de un único catálogo. Recomendación: dos endpoints con el mismo patrón.

### 3.6 Capas (flujo canónico)

`DecanoPortalController` → `{Crear|Actualizar|CambiarEstado|Consultar}Programa*InputPort` → `*Interactor` → `*UseCaseImpl` (resuelve el ámbito, valida reglas de dominio puras y llama al puerto) → `ProgramaAcademicoCommandPort` / `ProgramaAcademicoQueryPort` → `ProgramaAcademicoJpaRepository`:
- Comandos con `JpaProcedureExecutor` + `ProcedureResultMapper` (`estadoResultado = 0` → excepción tipada a partir del código).
- Consulta con native `EXEC dbo.usp_consultar_programas_academicos` mapeado a `SpProgramaAcademicoPaginadoEntity` → `ProgramaAcademicoProjection`.

Wiring con `@Bean` explícitos en `DecanoWiringConfiguration` (POJOs, sin `@Service`).

---

## 4. Contrato Frontend (Angular 19)

| Elemento | Contrato |
|---|---|
| `core/models/programa-academico.model.ts` | `ProgramaAcademico` (espejo de `ProgramaAcademicoResponse`, sin `any`), `CrearProgramaPayload`, `ActualizarProgramaPayload`, `CambiarEstadoProgramaPayload`, `TipoProgramaItem`, `ProgramasFiltro { pagina, tamano, nombre?, estaActivo?, idTipoPrograma? }` |
| `core/services/dean-programas.service.ts` | `programas = signal<ProgramaAcademico[]>([])`, `total = signal(0)`, `cargando = signal(false)`. Métodos: `consultar(filtro)`, `crear(p)`, `actualizar(id, p)`, `cambiarEstado(id, estaActivo)`, `getTiposPrograma()` (y `getModalidades()` / `getJornadas()` con D3). Usa `HttpClient` con `withCredentials` (interceptor existente). **No usa `catchError(() => of(true))`**: los errores se propagan y la UI muestra `error.error.message`. |
| `features/dean/dean-programas/dean-programas.component.ts` | Mantiene la sección de planes actual y **agrega** la tabla de programas. Usa `PaginationComponent`, filtros con signals (`computed` para el estado vacío) y botones Crear, Editar y Activar/Desactivar. `ChangeDetectionStrategy.OnPush`. |
| `features/dean/dean-programas/components/dean-programa-form-modal.component.ts` | Standalone, OnPush. `programa = input<ProgramaAcademico \| null>()` (null = alta), `coordinadoresDisponibles = input<CoordinadorItem[]>()`, `tiposPrograma = input<TipoProgramaItem[]>()`, `guardar = output<CrearProgramaPayload>()`, `cerrar = output<void>()`. En edición, el selector de coordinador incluye al coordinador actual además de los disponibles |
| `features/dean/dean-programas/components/dean-programa-estado-modal.component.ts` | Confirmación de cambio de estado. `programa = input.required<ProgramaAcademico>()`, `confirmar = output<boolean>()` |
| Coordinadores disponibles | Salen de `DeanManagementService.getCoordinadores()` (HU120) filtrando `idPrograma === null`. No se agrega endpoint nuevo |
| `core/services/catalog.service.ts` | `getProgramasAcademicos()` deja de devolver `defaultProgramas` quemados y delega en `GET /decano/programas?estaActivo=true&tamano=<max>` (o `dean-coordinadores` pasa a usar `DeanProgramasService`; se decide en RED según los consumidores encontrados con Grep) |
| Reglas | `input()` / `output()` (sin `@Input` / `@Output`), Signals, sin `setInterval`, sin `bypassSecurityTrust*`, sin generar ids de negocio en el cliente, mensajes tal cual los devuelve el backend |

---

## 5. Realtime

D8(b): **sin evento SSE** en este WI. Si el owner elige D8(a), se agrega el evento `PROGRAMA_ACADEMICO_ACTUALIZADO` (payload `{ idPrograma, idFacultad, accion: 'CREADO'|'ACTUALIZADO'|'ESTADO' }`), publicado después del commit por el puerto de publicación existente (skill `uco-realtime`), y el consumo en `dean-programas` vía `RealtimeService`.

---

## 6. Observabilidad

- `CorrelationIdContext.get()` → `@idCorrelacion` en cada SP.
- Log `INFO` en el use case con `correlationId`, `idFacultad` y `accion`, **sin PII** (sin nombres de coordinador).
- `mensajeTecnico` solo va a los logs, nunca al cliente.

---

## 7. Aprobación

| Rol | Estado | Fecha |
|---|---|---|
| Owner del producto | ⏳ Pendiente (D1–D12) | — |
| Congelamiento (`CONTRACT_FROZEN`) | ⏳ | — |
