---
status: draft
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-21
---

# CONTRACT — HU062 / HU089 / HU063 / HU090 / HU091: Vinculación de docentes al programa (Rol Coordinador)

> **Work Item:** `HU062-HU089-HU063-HU090-HU091-vinculacion-docente`
> **Estado:** `DRAFT`: sin congelar y sin `.sha256`. Pasa a `CONTRACT_FROZEN` cuando el owner apruebe D1–D9 del [PLAN](PLAN.md).
> **Supuestos del borrador** (recomendaciones del PLAN):
> - D1(a) tabla `DocentePrograma`.
> - D2: valores propuestos de `TipoVinculacion`.
> - D3(a) un docente puede tener N programas.
> - D4(a) los candidatos se devuelven con datos mínimos.
> - D5(a) sin especialidad ni departamento.
> - D6(a) se retiran los endpoints legacy.
> - D7(a) se retira el SP autónomo.
> - D8(a) el admin recibe 403.
> - D9(b) sin SSE.
>
> **Conformidad:** `constitution.md`, `AGENTS.md` §3.3, `GUIA_METODICA_IMPLEMENTACION_HU.md` §118 (identidad después de que la DB confirma).

---

## 1. Matriz AS-IS / TARGET del contrato

| Elemento | AS-IS | TARGET | Compatibilidad |
|---|---|---|---|
| `dbo.DocentePrograma`, `dbo.TipoVinculacion` | No existen | Nuevas (§2.2) | Aditivo (con *backfill* desde los grupos) |
| `dbo.uv_docente_programa`, `dbo.uv_auth_docente_programa`, `dbo.uv_tipo_vinculacion` | No existen | Nuevas (§2.3) | Aditivo |
| `dbo.usp_vincular_docente_programa` (+ `usp_internal_vincular_docente_programa`) | No existen | Nuevos (§2.4) | Aditivo |
| `dbo.usp_consultar_docentes_programa`, `dbo.usp_consultar_candidatos_docente_programa` | No existen | Nuevos (§2.5, §2.6) | Aditivo |
| `dbo.usp_sincronizar_docente_interno` | Responde `VAL_006` si el usuario ya es docente | `DOC_002` | Cambia el código de un SP interno |
| `dbo.usp_registrar_docente_en_grupo_autonomo` | Existe, sin RBAC | Se retira (D7) | Sin consumidores |
| `GET /api/v1/coordinador/docentes`, `POST /api/v1/coordinador/docentes` | 501 | Implementados (§3.1, §3.3) | Aditivo |
| `GET /api/v1/coordinador/docentes/candidatos`, `GET /api/v1/tipos-vinculacion` | No existen | Nuevos (§3.2, §3.4) | Aditivo |
| `PATCH /api/v1/coordinador/docentes/{id}/estado` | 501 | **Sigue en 501** (grupo I) | Sin cambio |
| `POST /api/v1/docentes`, `POST /api/v1/docentes/asignaciones/grupo` | 501 | Se retiran (D6) | Siempre respondían 501 |

---

## 2. Contrato de Base de Datos (SQL Server 2022+)

### 2.1 Reglas comunes

Son las mismas del contrato del grupo A (§2.1 de `HU076-HU077-HU078-programa-academico-decano/CONTRACT.md`):
- `SET NOCOUNT ON; SET XACT_ABORT ON;` y el patrón transaccional con `@@TRANCOUNT` / `SAVE TRANSACTION` de `usp_crear_coordinador.sql`.
- Evaluación de `@x IS NULL` sin sustituir por un GUID por defecto.
- RBAC (`usp_validar_permiso_rbac_usuario_interno @codigoPerfilRequerido='COORDINADOR'`) + titularidad (`usp_validar_titularidad_jerarquica_interno @tipoEntidadPadre='PROGRAMA'`) **dentro del SP**.
- Lecturas sobre `uv_*` y escrituras en `usp_internal_*`.
- Mensajes por código y tupla canónica de 4 columnas en los comandos.
- `READ_QUERY_RESULTSET` en las consultas, con aplicación y restauración del contexto de ejecutor.

### 2.2 DDL: `migrations/<nn>_hu091_docente_programa_tipo_vinculacion.sql` (+ `schema/tables/`)

```sql
-- TipoVinculacion (catálogo)
id UNIQUEIDENTIFIER PK, codigo NVARCHAR(3) NOT NULL UNIQUE, nombre NVARCHAR(50) NOT NULL, estado BIT NOT NULL

-- DocentePrograma (adscripción)
id UNIQUEIDENTIFIER PK,
docente UNIQUEIDENTIFIER NOT NULL  -> FK Docente(id),
programa UNIQUEIDENTIFIER NOT NULL -> FK Programa(id),
tipoVinculacion UNIQUEIDENTIFIER NOT NULL -> FK TipoVinculacion(id),
estado BIT NOT NULL,
fechaVinculacionUtc DATETIME2(0) NOT NULL,
CONSTRAINT UQ_DocentePrograma_docente_programa UNIQUE (docente, programa)
```

- Idempotente: `IF OBJECT_ID(...) IS NULL` / `IF NOT EXISTS (sys.foreign_keys ...)`.
- **Seed** `schema/seed/<nn>_tipo_vinculacion.sql` (`MERGE`, mismo patrón que `05_tipo_programa.sql`): `PLA` Planta, `MTI` Medio tiempo, `CAT` Cátedra, `OCA` Ocasional (sujeto a D2).
- **Backfill (R2):**
  - `INSERT` en `DocentePrograma` de los pares distintos (docente, programa) que hoy salen de `uv_docente`, siempre que el par no exista ya.
  - El tipo de vinculación es el que el owner defina como predeterminado (propuesta `CAT`), resuelto **por código** desde `TipoVinculacion`, sin GUID quemado.
  - `estado = 1`, `fechaVinculacionUtc = SYSUTCDATETIME()`.
- **D7:** `DROP PROCEDURE IF EXISTS dbo.usp_registrar_docente_en_grupo_autonomo`.
- **`down`:** `DROP` de las FKs y de `DocentePrograma` y `TipoVinculacion`. Se documenta en `VALIDATION.md`.

### 2.3 Vistas

**`dbo.uv_tipo_vinculacion`:** `id`, `codigo`, `nombre`, `estaActivoTipoVinculacion`, `estaActivoTextoTipoVinculacion`.

**`dbo.uv_docente_programa`:** una fila por vínculo (docente, programa):

| Columna | Origen |
|---|---|
| `idDocentePrograma` | `DocentePrograma.id` |
| `idDocente`, `idUsuario` | `uv_docente_identidad` |
| `idTipoIdentificacion`, `codigoTipoIdentificacion`, `numeroIdentificacion` | `uv_usuario` |
| `primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido`, `nombreCompleto`, `correo` | `uv_usuario` |
| `idPrograma`, `nombrePrograma`, `idFacultad`, `nombreFacultad`, `idInstitucion` | `uv_programa` |
| `idTipoVinculacion`, `codigoTipoVinculacion`, `nombreTipoVinculacion` | `uv_tipo_vinculacion` |
| `fechaVinculacionUtc` | `DocentePrograma` |
| `estaActivoVinculacion` | `DocentePrograma.estado` |
| `estaActivoUsuario` | `uv_usuario` |
| `estaActivoDocentePrograma` | `IIF(vínculo activo AND usuario activo AND programa activo, 1, 0)` |
| `totalGruposPrograma` | Número de grupos del docente cuyo plan pertenece al programa (subconsulta sobre `uv_grupo` / `uv_asignatura` / `uv_semestre_plan_estudio` / `uv_plan_estudio`) |

**`dbo.uv_auth_docente_programa`:** proyecta `uv_docente_programa` con el filtro fail-closed de `uv_auth_docente`:
- admin de la institución;
- decano de la facultad;
- coordinador **del programa de la fila**;
- el propio docente.

### 2.4 `dbo.usp_vincular_docente_programa` (HU091)

| Parámetro | Tipo | Req. | Regla |
|---|---|:-:|---|
| `@idDocente` | `UNIQUEIDENTIFIER = NULL` | Condicional | **Modo existente.** Debe ser un docente de la **misma institución** que el programa (`DOC_001` / `SEC_002`) |
| `@idUsuario` | `UNIQUEIDENTIFIER = NULL` | Condicional | **Modo existente para un usuario que aún no es docente** (R6). Si el usuario existe y no tiene fila en `Docente`, se crea con `usp_sincronizar_docente_interno` |
| `@idTipoIdentificacion` | `UNIQUEIDENTIFIER = NULL` | Modo nuevo | Existe y está activo en el catálogo |
| `@numeroIdentificacion` | `INT = NULL` | Modo nuevo | Mismo tipo que `Usuario` (R5) |
| `@primerNombre`, `@segundoNombre`, `@primerApellido`, `@segundoApellido` | `NVARCHAR(50)` | Modo nuevo (primero y apellido) | Reglas de `usp_sincronizar_usuario_interno` |
| `@correo` | `NVARCHAR(100) = NULL` | Modo nuevo | Idem |
| `@password` | `NVARCHAR(500) = NULL` | Modo nuevo | **Hash** (nunca en claro), no vacío |
| `@idTipoVinculacion` | `UNIQUEIDENTIFIER` | Sí | Existe y está activo (`DOC_004`) |
| `@idPrograma` | `UNIQUEIDENTIFIER` | Sí | Lo envía el backend desde el ámbito del coordinador; el SP revalida la titularidad (`SEC_002`) y que el programa esté activo (`PROG_001`) |
| `@idCorrelacion` | `UNIQUEIDENTIFIER` | Sí | |
| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | Sí | RBAC `COORDINADOR` (`GEN_002` si viene NULL) |

**Reglas de modo:**
- Exactamente uno de estos tres: `@idDocente`, `@idUsuario` o el bloque de datos nuevos. Si no → `DOC_005`.
- En modo nuevo, si el documento o el correo ya existen en `uv_usuario` → `DOC_003`, con la indicación de usar el modo existente. No se hace *find-or-create* silencioso, para no vincular a la persona equivocada.

**Flujo** (una sola transacción):
1. Valida el correlativo, RBAC, titularidad y modo.
2. Modo nuevo: `usp_sincronizar_usuario_interno` (activo, `correoConfirmado = 0`) → `usp_sincronizar_docente_interno`.
   Modo `@idUsuario`: `usp_sincronizar_docente_interno` solo si no es docente todavía.
3. `usp_internal_vincular_docente_programa`:
   - valida el tipo de vinculación;
   - valida que no exista un vínculo (docente, programa); si existe → `DOC_006`, se lee con `UPDLOCK, HOLDLOCK`;
   - `INSERT` con `estado = 1` y `fechaVinculacionUtc = SYSUTCDATETIME()`.
4. Éxito: `GEN_004` ("Vinculacion docente").

**Resultado:** la tupla canónica. El backend relee el docente y el usuario por correo (modo nuevo) o por id (modos existentes) para aprovisionar la identidad.

### 2.5 `dbo.usp_consultar_docentes_programa` (HU062 / HU089 / HU063)

| Parámetro | Tipo | Req. | Regla |
|---|---|:-:|---|
| `@idUsuarioEjecutor`, `@idCorrelacion` | | Sí | Contexto de ejecutor; filas de `uv_auth_docente_programa` |
| `@idPrograma` | `UNIQUEIDENTIFIER` | Sí | Titularidad del coordinador (`SEC_002`) |
| `@numeroPagina`, `@tamanoPagina` | `INT` | Sí | `PAG_001`; máximo `PAGINACION / TAMANO_MAXIMO` (lo define el grupo A) |
| `@busqueda` | `NVARCHAR(50) = NULL` | No | Si es solo dígitos: `CAST(numeroIdentificacion AS NVARCHAR) LIKE @busqueda + '%'`. Si no: `nombreCompleto LIKE '%' + @busqueda + '%'` |
| `@estaActivo` | `BIT = NULL` | No | Sobre `estaActivoDocentePrograma` |
| `@idTipoVinculacion` | `UNIQUEIDENTIFIER = NULL` | No | |

Resultset: las columnas de `uv_docente_programa` + `totalRegistros = COUNT(*) OVER()`, con `ORDER BY nombreCompleto, idDocente` y `OFFSET/FETCH`.

### 2.6 `dbo.usp_consultar_candidatos_docente_programa` (HU091, picker)

| Parámetro | Tipo | Req. | Regla |
|---|---|:-:|---|
| `@idUsuarioEjecutor`, `@idCorrelacion`, `@idPrograma` | | Sí | Igual que en §2.5 |
| `@busqueda` | `NVARCHAR(50)` | Sí | Al menos 3 caracteres (`DOC_007`) |

- **Resultado:** `TOP (@max)` filas, con el parámetro nuevo `DOCENTE / MAX_CANDIDATOS_BUSQUEDA` (propuesta 20).
- **Columnas (D4, datos mínimos):** `idDocente`, `idUsuario`, `codigoTipoIdentificacion`, `numeroIdentificacion`, `nombreCompleto`.
- **Filtro:**
  - docentes con usuario activo de la **institución** del programa, en cualquier programa de la institución (vía `DocentePrograma`); incluye a los docentes recién creados que todavía no tienen grupos;
  - **más** usuarios de la institución que no son docentes, solo si D3/R6 lo habilitan (en el borrador: **no**; el modo `@idUsuario` queda para un caso explícito);
  - excluye a los que ya están vinculados a `@idPrograma`.

### 2.7 Códigos de mensaje nuevos (`04_mensaje.sql` + App Configuration)

| Código | HTTP | Mensaje al usuario (propuesta) |
|---|:-:|---|
| `DOC_001` (ya existe) | 404 | El docente especificado no existe o se encuentra inactivo. |
| `DOC_002` | 409 | El usuario ya se encuentra registrado como docente. |
| `DOC_003` | 409 | Ya existe una persona registrada con ese documento o correo. Use la opción "Vincular docente existente". |
| `DOC_004` | 400 | El tipo de vinculación indicado no existe o está inactivo. |
| `DOC_005` | 400 | Debe indicar un docente existente o los datos de un docente nuevo, pero no ambos. |
| `DOC_006` | 409 | El docente ya está vinculado a este programa. |
| `DOC_007` | 400 | La búsqueda de candidatos requiere al menos 3 caracteres. |

Se agregan a `DbFailureClassifier` (`DOC_001` → `RESOURCE_NOT_FOUND`; `DOC_002`, `DOC_003`, `DOC_006` → conflicto; `DOC_004`, `DOC_005`, `DOC_007` → validación). `SEC_002` ya existe y se mapea como hoy.

---

## 3. Contrato HTTP REST (Backend)

Comunes:
- Base `/api/v1`. Autorización por el comodín `/api/v1/coordinador/**` → `COORDINADOR | ADMINISTRADOR` (`SecurityConfig.java:135`).
- **Ámbito en el use case:** `InstitutionalScopePort.findProgramaIdByCoordinadorUsuario(actor)`; si viene vacío → 403 (D8).
- `X-Correlation-Id` propagado. Errores con `ApiErrorResponse.message` = mensaje de catálogo.

### 3.1 `GET /api/v1/coordinador/docentes` (HU062 / HU089 / HU063)
- **Query:** `pagina` (≥ 1, por defecto 1), `tamano` (por defecto 10), `busqueda?` (máximo 50), `estaActivo?`, `idTipoVinculacion?`.
- **200:** `ApiListResponse<DocenteProgramaResponse>` (`exitoso`, `datos`, `total`).
- **DocenteProgramaResponse:**
  ```json
  {
    "idDocente": "uuid", "idUsuario": "uuid",
    "codigoTipoIdentificacion": "CC", "numeroIdentificacion": "1017555444",
    "primerNombre": "María", "segundoNombre": null, "primerApellido": "Rostagno", "segundoApellido": null,
    "nombreCompleto": "María Rostagno", "correo": "maria.rostagno@uco.edu.co",
    "idTipoVinculacion": "uuid", "codigoTipoVinculacion": "CAT", "nombreTipoVinculacion": "Cátedra",
    "fechaVinculacionUtc": "2026-10-21T15:04:05Z",
    "totalGruposPrograma": 2,
    "estaActivo": true
  }
  ```
- **Errores:** 400 (paginación o búsqueda inválida), 401, 403.

### 3.2 `GET /api/v1/coordinador/docentes/candidatos?busqueda=` (HU091, picker)
- **200:** `ApiListResponse<DocenteCandidatoResponse>`, con `{ idDocente, idUsuario, codigoTipoIdentificacion, numeroIdentificacion, nombreCompleto }`. **Sin correo** (D4).
- **Errores:** 400 (`DOC_007`), 401, 403.

### 3.3 `POST /api/v1/coordinador/docentes` (HU091)
- **Request (`VincularDocenteProgramaRequest`).** Modo existente:
  ```json
  { "idDocente": "uuid", "idTipoVinculacion": "uuid" }
  ```
  Modo nuevo:
  ```json
  {
    "idTipoIdentificacion": "uuid", "numeroIdentificacion": "1017555444",
    "primerNombre": "Jorge", "segundoNombre": null, "primerApellido": "Henao", "segundoApellido": null,
    "correo": "jorge.henao@uco.edu.co", "password": "<inicial>",
    "idTipoVinculacion": "uuid"
  }
  ```
  `idPrograma` **no** viene en el request: sale del ámbito.
- **Validator (400 sin llamar al use case):**
  - exactamente un modo;
  - UUIDs válidos;
  - documento numérico y dentro del rango `INT` (R5);
  - correo con formato válido;
  - longitudes ≤ 50 / 100;
  - en modo nuevo, contraseña obligatoria y conforme a `PasswordRegistroRule` (DA-5: **no hay contraseña por defecto**).
- **Use case** (`VincularDocenteProgramaUseCaseImpl`):
  1. Resuelve el programa por el ámbito.
  2. En modo nuevo, codifica la contraseña con `PasswordEncoderPort`.
  3. Llama a `DocenteProgramaCommandPort.vincular(...)` con un `idCorrelacion` tomado de `CorrelationIdContext`.
  4. Relee la identidad: por correo con `UsuarioRepositoryPort.consultarUsuarioPorCorreo` en modo nuevo, o por `idDocente` en modo existente.
  5. Llama a `IdentityProviderPort.crearCuenta(new CrearCuentaIdentidadDTO(String.valueOf(numeroIdentificacion), idUsuario, correo, primerNombre, primerApellido, passwordInicialOrNull, InstitutionalRole.DOCENTE))`. En modo existente la contraseña es `null`. Verificado en `KeycloakIdentityProviderAdapter.crearCuenta`: solo llama a `establecerPassword` si `resolution.newlyCreated()`, y siempre hace `ensureClientRole`. El RED con `FakeKeycloakAdminServer` lo confirma.
  6. Lee la fila resultante con el query port.
- **201:** `ApiDataResponse<DocenteProgramaResponse>`.
- **Errores:**
  - 400: validator, `DOC_004`, `DOC_005`.
  - 401.
  - 403: sin ámbito o `SEC_001` / `SEC_002`.
  - 404: `DOC_001`.
  - 409: `DOC_002`, `DOC_003`, `DOC_006`.
  - 500 controlado: falla de Keycloak después del commit, con el mensaje de catálogo `IAM_001` si existe; si no, se agrega (TD-015).

### 3.4 `GET /api/v1/tipos-vinculacion` (HU090)
- Cualquier usuario autenticado (`/api/v1/**`).
- **200:** `List<TipoVinculacionDTO>` = `[{ id, codigo, nombre }]`, solo activos. Mismo patrón que `TipoIdentificacionController`.

### 3.5 Retiro (D6)
- Se eliminan `POST /api/v1/docentes` y `POST /api/v1/docentes/asignaciones/grupo`. Después del retiro responden **404** (ruta inexistente). Queda registrado en `HTTP_AS_IS_MATRIX.md` como `RETIRED (HU091)`.
- Los `GET` de `/api/v1/docentes/**` **se mantienen** (se usan en las asignaciones académicas). Su falta de ámbito queda como TD (PLAN §13).

### 3.6 Capas

`CoordinadorPortalController` → `ConsultarDocentesProgramaInputPort` / `ConsultarCandidatosDocenteInputPort` / `VincularDocenteProgramaInputPort` → `*Interactor` → `*UseCaseImpl` → `DocenteProgramaCommandPort` / `DocenteProgramaQueryPort` (+ `UsuarioRepositoryPort`, `PasswordEncoderPort`, `IdentityProviderPort`) → `DocenteProgramaJpaRepository`:
- el comando va por `JpaProcedureExecutor`;
- las consultas usan native `EXEC` con `SpDocenteProgramaPaginadoEntity` y `SpDocenteCandidatoEntity`.

Los beans `@Bean` explícitos van en `CoordinadorWiringConfiguration`; los del catálogo, en `TipoVinculacionWiringConfiguration`.

---

## 4. Contrato Frontend (Angular 19)

| Elemento | Contrato |
|---|---|
| `core/models/docente-programa.model.ts` | Tipos: `DocentePrograma` (espejo de `DocenteProgramaResponse`, sin `any`), `DocenteCandidato`, `TipoVinculacionItem`, `VincularDocenteExistentePayload`, `VincularDocenteNuevoPayload`, `DocentesProgramaFiltro { pagina, tamano, busqueda?, estaActivo?, idTipoVinculacion? }` |
| `core/services/coordinator-management.service.ts` (sección DOCENTES) | `docentes = signal<DocentePrograma[]>([])`, `totalDocentes = signal(0)`. Métodos: `getDocentesPrograma(filtro)`, `getCandidatosDocente(busqueda)`, `vincularDocente(payload)`, `getTiposVinculacion()`. Se elimina `createDocente(Omit<DocenteItem…>)`. `toggleDocenteStatus` se conserva hasta el grupo I, pero **no se invoca** |
| `features/coordinator/coordinator-docentes/coordinator-docentes.component.ts` | Tabla paginada (`PaginationComponent`) con columnas documento, nombre, correo, vinculación, grupos y estado. La búsqueda es un `signal<string>` con *debounce* (`toObservable` + `debounceTime(300)` + `switchMap`); **sin `setInterval`**; el filtro deja de ser en el cliente. El botón de estado se muestra deshabilitado con el texto "Disponible próximamente (HU093)". OnPush |
| `features/coordinator/coordinator-docentes/components/coordinator-docente-form-modal.component.ts` (nuevo) | Standalone, OnPush. `tiposIdentificacion = input.required<TipoIdentificacionItem[]>()`, `tiposVinculacion = input.required<TipoVinculacionItem[]>()`, `guardar = output<VincularDocenteNuevoPayload>()`, `cerrar = output<void>()`. Campos: tipo de documento (sin un GUID por defecto quemado; se selecciona el primero del catálogo), documento, nombres, correo, **contraseña inicial**, tipo de vinculación. **Sin `especialidad` ni `departamento`** (D5) |
| Modo existente | `UserPickerModalComponent` alimentado por `getCandidatosDocente()`. Al elegir, se pide el tipo de vinculación y se envía `VincularDocenteExistentePayload` |
| Errores | `toast.error(err.error?.message)`, tal cual; el front no reinterpreta los códigos |
| Reglas | `input()` / `output()`, Signals, sin `bypassSecurityTrust*`, sin ids de negocio generados en el cliente |

---

## 5. Realtime

D9(b): sin eventos.

## 6. Observabilidad

- `correlationId` desde `CorrelationIdContext` hasta `@idCorrelacion`.
- Log `INFO` con `{correlationId, idPrograma, modo}` en el éxito.
- Log `ERROR` con `{correlationId, idUsuario}` si falla Keycloak.
- Nunca se loguea la contraseña, el documento ni el correo.

## 7. Aprobación

| Rol | Estado | Fecha |
|---|---|---|
| Owner del producto | ⏳ Pendiente (D1–D9) | — |
| Congelamiento (`CONTRACT_FROZEN`) | ⏳ | — |
