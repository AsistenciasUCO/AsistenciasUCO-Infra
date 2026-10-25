---
status: frozen
type: contract
scope: fullstack-database-backend-frontend
last-reviewed: 2026-10-22
---

# CONTRACT — HU154 + HU023 + HU151 + HU152

Estado: **`FROZEN`** (2026-10-22). El owner aprobó D1–D8 con las recomendaciones del plan.

## 1. Reglas comunes

- Salida de mutación en DB: tupla estándar (`idCorrelacion`, `mensajeUsuarioResultado`, `mensajeTecnicoResultado`, `estadoResultado`), igual que `usp_crear_facultad` y `usp_actualizar_facultad`.
- Cada SP público valida correlación (`CORR_001` si es nula), ejecutor y RBAC (`usp_validar_permiso_rbac_usuario_interno`, perfil `ADMINISTRADOR`) y delega la mutación a un `*_interno` con `SET XACT_ABORT ON`, transacción propia o `SAVE TRANSACTION`, y rollback en `CATCH` (`@@TRANCOUNT = 0` al salir).
- Sin GUIDs ni textos quemados; mensajes por `usp_obtener_mensaje_catalogo`. Validaciones de lectura contra vistas (`uv_*`), nunca tablas.
- Un parámetro `NULL` en actualizar significa «no modificar»; nunca se asigna `NULL` a una columna.
- Normalización: `nombre = TRIM(@nombre)`, `codigo = UPPER(TRIM(@codigo))`.
- Los mensajes de usuario provienen de la DB (SSOT); el backend solo clasifica el código a HTTP.

## 2. Base de datos

### 2.1 Cambios de esquema

| Objeto | Cambio |
| :--- | :--- |
| `dbo.Area` | `ADD estado BIT NOT NULL CONSTRAINT DF_Area_estado DEFAULT 1` (migración idempotente `migrations/05_catalogos_area_estado_unicidad.sql` + `schema/tables/Area.sql`). |
| Índices únicos | `UX_Area_codigo`, `UX_Area_nombre` (nombre con colación insensible) y `UX_TipoPrograma_codigo`, `UX_TipoPrograma_nombre`. La migración verifica duplicados previos y aborta con mensaje si los hay. |
| `uv_tipo_programa` | Agrega `codigo`. Se conservan `id`, `nombre`, `estaActivoTipoPrograma`, `estaActivoTextoTipoPrograma`. |
| `uv_area` | Agrega `codigo`, `estaActivaArea` (bit) y `estaActivaTextoArea`. Se conservan `id`, `nombre`. |

### 2.2 Procedimientos (por entidad, `X` ∈ {`tipo_programa`, `area`})

#### `dbo.usp_crear_X` (HU154 / HU151)

| Parámetro | Tipo | Requerido | Notas |
| :--- | :--- | :---: | :--- |
| `@codigo` | `NVARCHAR(3)` | Sí | 3 caracteres `A–Z0–9` tras normalizar. |
| `@nombre` | `NVARCHAR(50)` | Sí | 3–50 caracteres. |
| `@idCorrelacion` | `UNIQUEIDENTIFIER` | Sí | `CORR_001` si es nulo. |
| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | Sí | `ADMINISTRADOR`. |

Reglas: `codigo` y `nombre` obligatorios y con formato válido (`GEN_002`); `codigo` único (`GEN_003`, propiedad «código»); `nombre` único sin distinguir mayúsculas (`GEN_003`, propiedad «nombre»). Se inserta con `id = NEWID()` y `estado = 1`. Éxito `GEN_004`. El backend relee la vista por `codigo` (único).

#### `dbo.usp_actualizar_X` (HU154 / HU152)

| Parámetro | Tipo | Requerido | Notas |
| :--- | :--- | :---: | :--- |
| `@id` | `UNIQUEIDENTIFIER` | Sí | Debe existir (`TPR_001` / `ARE_001`). |
| `@nombre` | `NVARCHAR(50)` | Sí | 3–50, único entre los demás registros; mismo nombre propio es éxito sin escritura. `NULL` → `GEN_002`. |
| `@idCorrelacion`, `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | Sí | Igual que arriba. |

`codigo` **no es modificable** (D4). Éxito `GEN_005`.

#### `dbo.usp_cambiar_estado_X` (HU154 / HU152)

| Parámetro | Tipo | Requerido | Notas |
| :--- | :--- | :---: | :--- |
| `@id` | `UNIQUEIDENTIFIER` | Sí | Debe existir. |
| `@estaActivo` | `BIT` | Sí | Estado deseado; `NULL` → `GEN_002`. Idempotente. |
| `@idCorrelacion`, `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | Sí | |

Solo cambia `estado`; sin cascada (D5). Éxito `GEN_005`.

### 2.3 Códigos de error

| Código | Cuándo | HTTP vía `DbFailureClassifier` |
| :--- | :--- | :---: |
| `TPR_001` (**nuevo**) | El tipo de programa no existe. Usuario: «El tipo de programa especificado no existe en el sistema.» | 404 |
| `ARE_001` (**nuevo**) | El área de conocimiento no existe. Usuario: «El área de conocimiento especificada no existe en el sistema.» | 404 |
| `GEN_002` | Campo obligatorio ausente o con formato/longitud inválidos; ejecutor nulo; estado deseado nulo. | 400 |
| `GEN_003` | `codigo` o `nombre` duplicado. | 409 |
| `SEC_001` | Ejecutor sin perfil `ADMINISTRADOR`. | 403 |
| `CORR_001` | Correlación nula. | 400 |
| `GEN_004` / `GEN_005` | Éxito de creación / actualización o cambio de estado. | 201 / 200 |

`TPR_001` y `ARE_001` se registran en `04_mensaje.sql` (mensaje de usuario y técnico) y en `DbFailureClassifier` como `RESOURCE_NOT_FOUND` (commit final aparte, archivos calientes).

## 3. Backend HTTP

Todo bajo `/api/v1`. Reglas de seguridad existentes: `/api/v1/admin/**` → `ADMINISTRADOR`; `/api/v1/**` → `authenticated()`. Sin cambios en `SecurityConfig`.

### 3.1 DTOs

```json
// TipoProgramaAdminDTO (admin)        // TipoProgramaDTO (público)
{ "id": "uuid", "codigo": "PRE",       { "id": "uuid", "codigo": "PRE", "nombre": "pregrado" }
  "nombre": "pregrado", "activo": true }

// AreaDTO (admin; reemplaza AreaDTO(id, nombre))
{ "id": "uuid", "codigo": "ISW", "nombre": "Ingenieria de Software", "activa": true }
```

### 3.2 Tipos de programa

| Método y ruta | HU | Rol | Cuerpo | Respuestas |
| :--- | :-: | :--- | :--- | :--- |
| `GET /api/v1/tipos-programa` | HU023 | Cualquier autenticado | — | `200` `ApiListResponse<TipoProgramaDTO>`, solo activos, orden por `nombre`. |
| `GET /api/v1/admin/tipos-programa` | HU154 | `ADMINISTRADOR` | — | `200` `ApiListResponse<TipoProgramaAdminDTO>` con inactivos. |
| `POST /api/v1/admin/tipos-programa` | HU154 | `ADMINISTRADOR` | `{ "codigo", "nombre" }` | `201` `ApiDataResponse<TipoProgramaAdminDTO>`; `400`, `409`, `403`. |
| `PUT /api/v1/admin/tipos-programa/{id}` | HU154 | `ADMINISTRADOR` | `{ "nombre" }` | `200` `ApiDataResponse<TipoProgramaAdminDTO>`; `400`, `404`, `409`, `403`. |
| `PATCH /api/v1/admin/tipos-programa/{id}/estado` | HU154 | `ADMINISTRADOR` | `{ "activo": bool }` | `200` `ApiDataResponse<TipoProgramaAdminDTO>`; `400` (falta `activo`), `404`, `403`. |

### 3.3 Áreas

| Método y ruta | HU | Rol | Cuerpo | Respuestas |
| :--- | :-: | :--- | :--- | :--- |
| `GET /api/v1/admin/areas` | HU150 | `ADMINISTRADOR` | — | `200` `ApiListResponse<AreaDTO>` (ahora con `codigo` y `activa`). |
| `POST /api/v1/admin/areas` | HU151 | `ADMINISTRADOR` | `{ "codigo", "nombre" }` | `201` `ApiDataResponse<AreaDTO>`; `400`, `409`, `403`. Deja de responder 501. |
| `PUT /api/v1/admin/areas/{id}` | HU152 | `ADMINISTRADOR` | `{ "nombre" }` | `200`; `400`, `404`, `409`, `403`. Deja de responder 501. |
| `PATCH /api/v1/admin/areas/{id}/estado` | HU152 | `ADMINISTRADOR` | `{ "activa": bool }` | `200`; `400`, `404`, `403`. Deja de responder 501. |

Validación de borde (Bean Validation) espejo de la DB: `codigo` 3 caracteres `[A-Za-z0-9]`, `nombre` 3–50, booleano obligatorio. Los errores del SP se clasifican con `DbFailureClassifier`/`GlobalExceptionHandler`; el controller no interpreta textos. Si la relectura de la vista tras una mutación exitosa no encuentra el registro, responde 404.

### 3.4 Capas

`Controller` → `InputPort` → `*UseCaseImpl` (POJO; `@Bean` en el wiring) → `TipoProgramaCommandPort` / `TipoProgramaQueryPort` / `AreaCommandPort` / `AreaQueryPort` (existente, ampliado) → adaptadores JPA con `JpaProcedureExecutor` (mutación) y entidades de solo lectura `UvTipoProgramaEntity`, `UvAreaEntity` (lectura). Las listas son catálogos acotados y se mantienen como `ApiListResponse` sobre la vista, igual que `GET /admin/areas` y `GET /tipos-identificacion` hoy; no se pagina.

## 4. Frontend

- `core/models/role-management.model.ts`: `AreaConocimientoItem { id, codigo, nombre, activa }` (se eliminan `facultadId`, `facultadNombre`, `coordinadorArea`, `estado` string y `totalAsignaturas`); nuevo `TipoProgramaItem { id, codigo, nombre, activo }`.
- `AdminManagementService`:
  - Áreas: `crearArea({codigo,nombre})`, `actualizarArea(id,{nombre})`, `cambiarEstadoArea(id, activa)` devuelven `Observable<ApiResponse<AreaConocimientoItem>>`; la señal `areas` cambia **solo** con la respuesta exitosa; el error se propaga al componente.
  - Tipos de programa: `cargarTiposPrograma()`, `crearTipoPrograma`, `actualizarTipoPrograma`, `cambiarEstadoTipoPrograma(id, activo)` con la misma regla. La lectura pública (`GET /tipos-programa`) queda disponible para el selector de la pista A.
- `AdminCatalogsComponent`: deja de redirigir; pantalla «Tipos de programa» (tabla, alta/edición en modal, switch de estado). El código se muestra solo lectura al editar.
- `AdminAreasComponent`: formulario `codigo` + `nombre`; switch de estado con el estado deseado; en error muestra `mensajeUsuario` del backend sin parsear texto; botones deshabilitados mientras la petición está en curso; `OnPush`, Signals, sin `setInterval`.
- Sin identificadores de negocio autogenerados en el cliente.

## 5. Compatibilidad

- `GET /admin/areas` cambia de `{id, nombre}` a `{id, codigo, nombre, activa}`: aditivo.
- `POST/PUT/PATCH /admin/areas` hoy responden 501: sin consumidores válidos.
- Los endpoints de tipos de programa son nuevos.
- Se verifica en la fase CONTRACT si `openapi-golden-path.yaml` cubre estos paths (hoy no menciona áreas ni tipos de programa); de no cubrirlos, no se toca el contrato WORM ni su `.sha256`.
