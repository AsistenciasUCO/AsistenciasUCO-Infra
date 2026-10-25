---
status: draft
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# CONTRACT — HU062 / HU089 / HU063 / HU090 / HU091 / HU092 / HU093: Gestión de docentes del programa (Rol Coordinador)

> **Work Item:** `HU062-HU093-docentes-coordinacion`
> **Estado:** `DRAFT`: sin congelar y sin `.sha256`. Pasa a `CONTRACT_FROZEN` (con `.sha256` adyacente) cuando el owner apruebe D1–D14 del [PLAN](PLAN.md).
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
> - D10(a) error controlado sin compensación en DB; D11(a) HU092 edita tipo de vinculación + nombres; D12(a) HU093 cambia solo el vínculo; D13(a) contraseña asignada, sin carga masiva; D14(b) reintento idempotente del aprovisionamiento.
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
| `PUT /api/v1/coordinador/docentes/{idDocente}` (HU092) | No existe | Nuevo (§3.5) | Aditivo |
| `PATCH /api/v1/coordinador/docentes/{idDocente}/estado` (HU093) | 501 (`{id}`) | Implementado (§3.6) | Hoy 501 → 200 |
| `dbo.usp_actualizar_docente_programa`, `dbo.usp_cambiar_estado_docente_programa` | No existen | Nuevos (§2.8, §2.9) | Aditivo |
| `dbo.usp_crear_grupo` / `usp_actualizar_grupo` | Aceptan cualquier docente | Rechazan titular sin vínculo activo al programa (D12, `DOC_009`) | Cambio de comportamiento, a validar en RED (§2.9) |
| `POST /api/v1/docentes`, `POST /api/v1/docentes/asignaciones/grupo` | 501 | Se retiran (D6) | Siempre respondían 501 |

---

## 2. Contrato de Base de Datos (SQL Server 2022+)

### 2.1 Reglas comunes

Mismas reglas que HU120 (`docs/work-items/HU120-crear-coordinador/CONTRACT.md`) y `usp_crear_coordinador.sql` en `develop`:
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
| `@numeroPagina`, `@tamanoPagina` | `INT` | Sí | `PAG_001`; máximo `PAGINACION / TAMANO_MAXIMO` (parámetro; verificar si ya existe en `develop`) |
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

### 2.8 `dbo.usp_actualizar_docente_programa` (HU092, D11-a)

Fachada transaccional (mismo patrón de ownership que `usp_crear_coordinador`). Parámetros: `@idDocente`, `@idPrograma`, `@idTipoVinculacion = NULL`, `@primerNombre/@segundoNombre/@primerApellido/@segundoApellido = NULL` (solo se actualizan los no nulos; ≥ 1 campo, si no `GEN_002`), `@idCorrelacion`, `@idUsuarioEjecutor`.
- RBAC `COORDINADOR` + titularidad `PROGRAMA` sobre `@idPrograma`; el vínculo (docente, programa) debe existir (`DOC_008`).
- Tipo de vinculación → `usp_internal_*` valida catálogo activo (`DOC_004`) y actualiza `DocentePrograma.tipoVinculacion` **solo de ese vínculo**.
- Nombres → delega en un `usp_internal_actualizar_nombres_usuario` (nuevo, sin tocar correo ni documento). Afecta a la persona en todos sus programas (advertido en la UI).
- Respuesta: tupla canónica; mensaje `GEN_005` (actualización) si existe en catálogo.

### 2.9 `dbo.usp_cambiar_estado_docente_programa` (HU093, D12-a)

Parámetros: `@idDocente`, `@idPrograma`, `@estaActivo BIT`, `@idCorrelacion`, `@idUsuarioEjecutor`. RBAC + titularidad; vínculo inexistente → `DOC_008`; **idempotente** (mismo estado → éxito sin cambios). Solo actualiza `DocentePrograma.estado`. No toca `Usuario.estado` ni Keycloak. Los grupos ya asignados se conservan.
- **Validación en grupos (D12):** `usp_crear_grupo` y `usp_actualizar_grupo` (HU076B) rechazan un `idDocente` sin vínculo **activo** con el programa del grupo (`DOC_009`). *Condición:* si una prueba existente de grupos asume docentes sin vínculo, se evalúa como `TEST_CONTRACT_CONFLICT` (el backfill R2 crea vínculos para todo docente con grupos, por lo que los datos canónicos no se rompen).
- El directorio (`§2.5`) devuelve `estaActivo` del vínculo; el filtro `@estaActivo` lo usa.

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
| `DOC_008` | 404 | El docente no está vinculado a este programa. |
| `DOC_009` | 409 | El docente no tiene una vinculación activa con el programa. |

Se agregan a `DbFailureClassifier` (`DOC_001` → `RESOURCE_NOT_FOUND`; `DOC_002`, `DOC_003`, `DOC_006` → conflicto; `DOC_004`, `DOC_005`, `DOC_007` → validación; `DOC_008` → `RESOURCE_NOT_FOUND`; `DOC_009` → conflicto). `SEC_002` ya existe y se mapea como hoy.

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
  7. **D10:** si `crearCuenta` lanza `IdentityProviderException`, lanza `InternalApplicationException` (500 controlado, mensaje de catálogo `IAM_001`: el docente quedó registrado pero la cuenta de acceso no pudo crearse). **No** hay compensación en DB.
  8. **D14:** si el SP responde `DOC_003`/`DOC_006` y la persona (mismo documento+correo) ya está vinculada a este programa, el use case omite el comando y reintenta solo `crearCuenta` (idempotente por `idUsuario`; la contraseña de una cuenta existente no se toca). Responde 200 con `mensajeUsuario` de catálogo.
- **201:** `ApiDataResponse<DocenteProgramaResponse>`.
- **Errores:**
  - 400: validator, `DOC_004`, `DOC_005`.
  - 401.
  - 403: sin ámbito o `SEC_001` / `SEC_002`.
  - 404: `DOC_001`.
  - 409: `DOC_002`, `DOC_003`, `DOC_006`.
  - 500 controlado: falla de Keycloak después del commit, con `IAM_001` (se agrega al seed si no existe; TD-015).

### 3.5 `PUT /api/v1/coordinador/docentes/{idDocente}` (HU092)
- **Request:** `{ "idTipoVinculacion"?: uuid, "primerNombre"?: string, "segundoNombre"?: string, "primerApellido"?: string, "segundoApellido"?: string }` (al menos un campo; longitudes ≤ 50; correo y documento **no** admitidos → 400). `idPrograma` sale del ámbito.
- **200:** `ApiDataResponse<DocenteProgramaResponse>` (relee la fila con el query port). **Errores:** 400, 401, 403, 404 (`DOC_008`), 409 no aplica.

### 3.6 `PATCH /api/v1/coordinador/docentes/{idDocente}/estado` (HU093)
- **Request:** `{ "estaActivo": true|false }` (obligatorio). **200:** `ApiDataResponse<DocenteProgramaResponse>`. Idempotente. **Errores:** 400, 401, 403, 404 (`DOC_008`).
- La ruta cambia de `{id}` a `{idDocente}` (mismo segmento; compatible).

### 3.4 `GET /api/v1/tipos-vinculacion` (HU090)
- Cualquier usuario autenticado (`/api/v1/**`).
- **200:** `List<TipoVinculacionDTO>` = `[{ id, codigo, nombre }]`, solo activos. Mismo patrón que `TipoIdentificacionController`.

### 3.7 Retiro (D6)
- Se eliminan `POST /api/v1/docentes` y `POST /api/v1/docentes/asignaciones/grupo`. Después del retiro responden **404** (ruta inexistente). Queda registrado en `HTTP_AS_IS_MATRIX.md` como `RETIRED (HU091)`.
- Los `GET` de `/api/v1/docentes/**` **se mantienen** (se usan en las asignaciones académicas). Su falta de ámbito queda como TD (PLAN §13).

### 3.8 Capas

`CoordinadorPortalController` → `ConsultarDocentesProgramaInputPort` / `ConsultarCandidatosDocenteInputPort` / `VincularDocenteProgramaInputPort` / `ActualizarDocenteProgramaInputPort` / `CambiarEstadoDocenteProgramaInputPort` → `*Interactor` → `*UseCaseImpl` → `DocenteProgramaCommandPort` / `DocenteProgramaQueryPort` (+ `UsuarioRepositoryPort`, `PasswordEncoderPort`, `IdentityProviderPort`) → `DocenteProgramaJpaRepository`:
- el comando va por `JpaProcedureExecutor`;
- las consultas usan native `EXEC` con `SpDocenteProgramaPaginadoEntity` y `SpDocenteCandidatoEntity`.

Los beans `@Bean` explícitos van en `CoordinadorWiringConfiguration`; los del catálogo, en `TipoVinculacionWiringConfiguration`.

---

## 4. Contrato Frontend (Angular 19)

| Elemento | Contrato |
|---|---|
| `core/models/docente-programa.model.ts` | Tipos: `DocentePrograma` (espejo de `DocenteProgramaResponse`, sin `any`), `DocenteCandidato`, `TipoVinculacionItem`, `VincularDocenteExistentePayload`, `VincularDocenteNuevoPayload`, `DocentesProgramaFiltro { pagina, tamano, busqueda?, estaActivo?, idTipoVinculacion? }` |
| `core/services/coordinator-management.service.ts` (sección DOCENTES) | `docentes = signal<DocentePrograma[]>([])`, `totalDocentes = signal(0)`. Métodos: `getDocentesPrograma(filtro)`, `getCandidatosDocente(busqueda)`, `vincularDocente(payload)`, `getTiposVinculacion()`. Se elimina `createDocente(Omit<DocenteItem…>)`. `toggleDocenteStatus` → `cambiarEstadoDocente(idDocente, estaActivo)`; `actualizarDocente(idDocente, payload)` (HU092). Ambos **sin actualización optimista**: tras 200 se recarga la página desde el servidor |
| `features/coordinator/coordinator-docentes/coordinator-docentes.component.ts` | Tabla paginada (`PaginationComponent`) con columnas documento, nombre, correo, vinculación, grupos y estado. La búsqueda es un `signal<string>` con *debounce* (`toObservable` + `debounceTime(300)` + `switchMap`); **sin `setInterval`**; el filtro deja de ser en el cliente. Switch de estado con modal de confirmación (HU093) y modal de edición (HU092; tipo de vinculación + nombres, sin correo/documento). OnPush |
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

## 8. Enmiendas de implementación (tanda 1, 2026-10-22)

Desviaciones verificadas durante RED/GREEN; reemplazan lo anterior donde discrepan:

| Tema | Contrato original | Implementado |
|---|---|---|
| Nombre de SP internos | `usp_internal_*` | Sufijo `_interno`: `usp_vincular_docente_programa_interno` (convención vigente del repo y exclusión de `test_contract_closure`) |
| Paginación | `PAG_001` y `PAGINACION/TAMANO_MAXIMO` | No existen en el catálogo. Se normaliza (`pagina` ≥ 1, `tamano` 1..100) como `usp_consultar_grupos_paginado`; el controller además responde 400 fuera de rango |
| Filtros del directorio | `@busqueda`, `@estaActivo`, `@idTipoVinculacion` | Se agregan `@idDocente` e `@idUsuario` opcionales para releer el vínculo recién creado antes del aprovisionamiento IAM |
| Consultas y `XACT_ABORT` | `SET XACT_ABORT ON` en todo SP | Los SP de **solo lectura** no lo declaran (un error no debe condenar la transacción del llamador); el comando sí |
| Orden de validaciones | Dentro de la transacción | Las validaciones de lectura (DOC_001/003/006, institución) se hacen **antes** de abrir la transacción; el interno revalida tipo y unicidad con `UPDLOCK, HOLDLOCK` |
| Transacción externa | Rollback al savepoint | Con `XACT_ABORT ON` un fallo condena la transacción: el SP no es propietario y propaga el error al llamador (patrón de ownership) |
| Wiring | `CoordinadorWiringConfiguration` | `DocenteProgramaWiringConfiguration` y `TipoVinculacionWiringConfiguration` (archivos propios) |
| Controller | `CoordinadorPortalController` | `CoordinadorDocentesController` (nuevo); se retiran los GET/POST en 501 del portal |
| Mensajes DOC_* / IAM_001 | `04_mensaje.sql` | `schema/seed/17_mensaje_docente_programa.sql` (evita conflicto con otras pistas) |
| Candidatos | Excluye vinculados al programa, misma institución, sin correo | Igual; el SP lee `uv_docente_programa` sin contexto porque la autorización es explícita (RBAC + titularidad) |

## 9. Enmiendas de implementación (tandas 2 y 3, 2026-10-22)

| Tema | Contrato original | Implementado |
|---|---|---|
| HU092 `PUT /coordinador/docentes/{idDocente}` | Body con tipo de vinculación y nombres | Igual. `""` en segundo nombre/apellido los limpia; primer nombre/apellido no pueden quedar en blanco. Correo y documento no son editables. Nombres no se sincronizan con Keycloak (D11, deuda hasta IAM-001) |
| HU093 `PATCH …/{idDocente}/estado` | Body `{ "estaActivo": bool }` | Igual; responde 200 con la fila releída. Idempotente. No toca `Usuario.estado`, el rol Docente, los grupos ni la cuenta de identidad (D12) |
| Regla D12 en grupos | `usp_crear_grupo`/`usp_actualizar_grupo` rechazan titular **sin vínculo activo** (`DOC_009`) | **Acotada:** rechazan solo un vínculo **explícitamente inactivo** con el programa de la asignatura. Un docente sin ningún vínculo no se bloquea (no rompe flujos previos a la adscripción) y editar un grupo sin cambiar el titular sigue permitido. Implementado en `usp_validar_docente_vinculo_activo_programa_interno` |
| Códigos de error | `DOC_*` con kinds genéricos | Códigos de feature en `DocenteErrorCode` (`ERR_DOCENTE_YA_VINCULADO_PROGRAMA`, `ERR_PERSONA_YA_REGISTRADA`, `ERR_TIPO_VINCULACION_INVALIDO`, `ERR_MODO_VINCULACION_INVALIDO`, `ERR_BUSQUEDA_CANDIDATOS_CORTA`, `ERR_DOCENTE_NO_VINCULADO_PROGRAMA`, `ERR_DOCENTE_SIN_VINCULO_ACTIVO`), porque el cliente solo muestra el mensaje del backend para códigos de feature; el kind HTTP no cambia (404/409/400) |
| Nombre de savepoint | `usp_cambiar_estado_docente_programa` | `sp_cambiar_estado_docprog` (SQL Server limita los nombres de savepoint a 32 caracteres) |
| Frontend | `UserPickerModalComponent` para el modo existente | Picker propio dentro del modal de vinculación (el genérico está atado a datos mock) |
