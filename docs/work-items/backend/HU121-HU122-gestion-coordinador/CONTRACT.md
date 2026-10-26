---
status: contract-frozen
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# CONTRACT — HU121 / HU122: Gestión del Coordinador (Rol Decano)

> **Work Item:** `HU121-HU122-gestion-coordinador`
> **Estado:** `CONTRACT_FROZEN` el 2026-10-22 (sin `.sha256`: no entra al golden path ni a los baselines WORM). El owner aprobó D1–D10 del [PLAN](PLAN.md). Cualquier cambio exige un registro `CONTRACT_CONFLICT` y nueva aprobación.
> **Decisiones aprobadas:** D1(a) `Coordinador.estado`; D2(a) `Coordinador.facultad`; D3(a) rechazo con programa activo; D4(a) solo datos personales; D5(a) contraseña obligatoria; D6(a) estado explícito; D7(a) éxito con advertencia; D8(a) 403 para el admin; D9(b) sin SSE; D10(a) controlador y wiring propios.
> **Depende de** [`IAM-001`](../IAM-001-ciclo-vida-cuenta-identidad/CONTRACT.md): `IdentityProviderPort` ampliado, `SincronizarCuentaInstitucionalService`, `usp_internal_cambiar_estado_usuario`, `usp_internal_actualizar_datos_usuario` y `ufn_usuario_tiene_roles_activos`. Este contrato no los redefine.
> Este work item **no** entra al golden path (`openapi-golden-path.yaml` y los baselines WORM no cambian); se registra en `HTTP_AS_IS_MATRIX.md` al cerrar.

---

## 1. Reglas inviolables

1. Tupla canónica de salida en todo SP de mutación: `idCorrelacion`, `mensajeUsuarioResultado`, `mensajeTecnicoResultado`, `estadoResultado`, más las columnas adicionales declaradas abajo.
2. `SET XACT_ABORT ON;`, `SET NOCOUNT ON;` y el patrón de propiedad de la transacción de `usp_crear_coordinador.sql` (`@@TRANCOUNT` inicial, `BEGIN TRAN` o `SAVE TRANSACTION`, rollback seguro en el `CATCH`).
3. Evaluar `@parametro IS NULL`. **No** se usa `ufn_obtener_parametro_guid(..., 'GUID_DEFECTO_CORRELACION')` para sustituir parámetros nulos (REG-000 §6).
4. Cero `SELECT` directo a tablas desde el backend; las lecturas pasan por vistas `uv_*`. Los SPs de mutación leen solo vistas, salvo el `UPDATE` de la tabla propia.
5. Ámbito forzado **dentro del SP** y también en el use case.
6. Orden en el backend: **DB primero, Keycloak después del commit**. Falla del IdP = éxito con advertencia (D7).

---

## 2. Contrato de Base de Datos

### 2.1 Migración `migrations/<nn>_hu121_hu122_coordinador_estado_facultad.sql` (idempotente, con `down`)

```sql
-- up
IF COL_LENGTH('dbo.Coordinador', 'estado') IS NULL
    ALTER TABLE dbo.Coordinador ADD estado BIT NOT NULL CONSTRAINT DF_Coordinador_estado DEFAULT 1;
IF COL_LENGTH('dbo.Coordinador', 'facultad') IS NULL
    ALTER TABLE dbo.Coordinador ADD facultad UNIQUEIDENTIFIER NULL;
-- relleno: facultad del programa que coordina (uv_programa.idCoordinador = Coordinador.id)
-- FK_Coordinador_Facultad → dbo.Facultad(id), creada solo si no existe
-- reporte: coordinadores que quedan con facultad NULL (huérfanos, R3 del PLAN)
```

- `schema/tables/Coordinador.sql` se actualiza con las mismas columnas para los despliegues nuevos y la FK se agrega en `schema/tables/zz_foreign_keys.sql` (mismo estilo que las FKs de `Programa`).
- `down`: quita la FK, el `DEFAULT` y las dos columnas, solo si existen.

### 2.2 Vistas

**`uv_coordinador_identidad`** (columnas nuevas, las existentes no cambian):

| Columna | Origen |
|---|---|
| `primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido`, `correo` | `uv_usuario` |
| `idTipoIdentificacion`, `codigoTipoIdentificacion` | `uv_usuario` (si la vista del usuario ya los expone; si no, se omiten y se declara en la fase 03) |
| `estaActivoRolCoordinador` | `Coordinador.estado` |
| `idFacultadCoordinador` | `Coordinador.facultad` |

**`uv_coordinador`** (aditivo):
- Pasa las columnas anteriores.
- `idFacultad = COALESCE(pr.idFacultad, ci.idFacultadCoordinador)`: un coordinador sin programa conserva su facultad. **Cambia el valor de `idFacultad` para los coordinadores sin programa** (antes `NULL`). Se revisa con Grep que ningún consumidor use `idFacultad IS NULL` como señal de "sin programa" (R4).
- `estaActivoCoordinador = IIF(ci.estaActivoUsuario = 1 AND ci.estaActivoRolCoordinador = 1 AND (pr.id IS NULL OR pr.estaActivoPrograma = 1), 1, 0)` y su texto `SI`/`NO`.

`uv_auth_coordinador` expone `idFacultad` con la misma regla.

### 2.3 `dbo.usp_internal_validar_coordinador_de_facultad`

| Parámetro | Tipo | Regla |
|---|---|---|
| `@idCoordinador` | `UNIQUEIDENTIFIER` | Debe existir en `uv_coordinador` |
| `@idFacultad` | `UNIQUEIDENTIFIER` | El coordinador pertenece a esa facultad (`uv_coordinador.idFacultad`) |
| `@idCorrelacion` + OUTPUT canónicos | | |

- Devuelve `GEN_001` ("Coordinador") **tanto si no existe como si es de otra facultad**, para no revelar su existencia (CA-06).
- No tiene transacción propia: corre dentro de la fachada.

### 2.4 `dbo.usp_actualizar_coordinador` (HU121)

| Parámetro | Tipo | Requerido | Regla |
|---|---|:---:|---|
| `@idCoordinador` | `UNIQUEIDENTIFIER` | Sí | Existe y es de la facultad del ejecutor |
| `@primerNombre`, `@primerApellido` | `NVARCHAR(50)` | Sí | No vacío ni solo espacios |
| `@segundoNombre`, `@segundoApellido` | `NVARCHAR(50)` | No | `NULL` = sin valor |
| `@correo` | `NVARCHAR(100)` | Sí | Formato válido; único excluyendo al propio usuario (`VAL_006`) |
| `@idFacultad` | `UNIQUEIDENTIFIER` | Sí | Facultad del decano (la resuelve el backend con `InstitutionalScopePort`; el SP la **vuelve a validar** con `usp_validar_titularidad_jerarquica_interno`) |
| `@idCorrelacion` | `UNIQUEIDENTIFIER` | Sí | |
| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | Sí | `NULL` → `GEN_002` |

Flujo: correlación → ejecutor no nulo → RBAC `DECANO` (`usp_validar_permiso_rbac_usuario_interno`, exacto según IAM-001 §4.4) → titularidad de la facultad → `usp_internal_validar_coordinador_de_facultad` → transacción → `usp_internal_actualizar_datos_usuario` → commit.

Éxito: `GEN_005` con el parámetro `Coordinador`. Resultset: `idCorrelacion`, `mensajeUsuarioResultado`, `mensajeTecnicoResultado`, `estadoResultado`, **`idUsuario`** (para que el backend sincronice el IdP sin otra consulta).

### 2.5 `dbo.usp_cambiar_estado_coordinador` (HU122)

| Parámetro | Tipo | Requerido | Regla |
|---|---|:---:|---|
| `@idCoordinador` | `UNIQUEIDENTIFIER` | Sí | Existe y es de la facultad del ejecutor |
| `@estaActivo` | `BIT` | Sí | Estado destino. Si ya lo tiene, éxito sin cambios (idempotente) |
| `@idFacultad`, `@idCorrelacion`, `@idUsuarioEjecutor` | | Sí | Igual que en §2.4 |

Flujo:
1. Validaciones de §2.4 (correlación, ejecutor, RBAC, titularidad, coordinador de la facultad).
2. Si `@estaActivo = 0` y el coordinador coordina un programa **activo** (`uv_programa.idCoordinador = @idCoordinador AND estaActivoPrograma = 1`, leída con `UPDLOCK, HOLDLOCK`) → `COO_001`, sin cambios (D3).
3. Transacción: `UPDATE dbo.Coordinador SET estado = @estaActivo WHERE id = @idCoordinador`.
4. Persona:
   - desactivar: `dbo.ufn_usuario_tiene_roles_activos(@idUsuario)`; si devuelve 0 → `usp_internal_cambiar_estado_usuario @estaActivo = 0`.
   - reactivar: `usp_internal_cambiar_estado_usuario @estaActivo = 1` (si el usuario estaba apagado).
5. Commit.

Éxito: `GEN_005`. Resultset: los cuatro estándar + **`idUsuario`** + **`personaSinRolesActivos`** (`BIT`; solo relevante al desactivar, para que el backend decida si deshabilita la cuenta, IAM-001 D2).

### 2.6 `dbo.usp_crear_coordinador` (cambio mínimo)

Sin cambio de firma. Al insertar el coordinador fija `Coordinador.facultad = @idFacultad` (y la completa si el coordinador ya existía con `facultad` nula). No se cambian el resto de reglas ni sus pruebas.

### 2.7 Mensajes nuevos en `schema/seed/04_mensaje.sql`

Se agregan en las dos secciones del archivo (mensaje de usuario y mensaje técnico):

| Código | Tipo | Usuario | Técnico |
|---|---|---|---|
| `COO_001` | `BUSINESS_ERROR` | "No se puede desactivar al coordinador mientras tenga un programa activo a cargo. Reasigne o desactive el programa primero." | "Regla de negocio: el coordinador {} coordina el programa activo {}." |

Se reutilizan: `GEN_001`, `GEN_002`, `GEN_005`, `VAL_006` y `SYS_001`. `IAM_002` viene de IAM-001.

### 2.8 `dbo.ufn_usuario_tiene_roles_activos` (extensión)

Se **extiende** (la crea IAM-001): considera activo el rol de coordinador cuando existe `Coordinador` con `estado = 1` del usuario. El orden entre este WI, WI-B y WI-E decide quién la crea primero; el segundo rebasa (PLAN §7).

---

## 3. Contrato del Backend

### 3.1 Puerto secundario (aditivo)

`CoordinadorCommandPort`:

```java
ResultadoGestionCoordinadorProjection actualizarCoordinador(UUID idCoordinador, String primerNombre, String segundoNombre,
        String primerApellido, String segundoApellido, String correo, UUID idFacultad, UUID usuarioEjecutor);

ResultadoGestionCoordinadorProjection cambiarEstadoCoordinador(UUID idCoordinador, boolean estaActivo, UUID idFacultad,
        UUID usuarioEjecutor);
```

- `ResultadoGestionCoordinadorProjection(UUID idUsuario, boolean personaSinRolesActivos)`; en `actualizarCoordinador` `personaSinRolesActivos` siempre es `false`.
- `CoordinadorQueryPort.consultarCoordinadoresSinPrograma(UUID idFacultad)`: **cambia la firma** (se agrega la facultad). Hoy no tiene otro consumidor que `ConsultarCoordinadoresUseCaseImpl` (se verifica con Grep). `CoordinadorProjection` agrega `primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido`, `correo` y `estaActivoRolCoordinador`.

### 3.2 Casos de uso (POJOs cableados en `CoordinadorGestionWiringConfiguration`)

| Feature | Entrada | Pasos |
|---|---|---|
| `decano/actualizarcoordinador` | `ActualizarCoordinadorDTO(idCoordinador, primerNombre, segundoNombre, primerApellido, segundoApellido, correo, usuarioEjecutor)` | 1) `scopePort.findFacultadIdByDecanoUsuario` (vacío → `ForbiddenException`); 2) `commandPort.actualizarCoordinador(...)`; 3) `SincronizarCuentaInstitucionalService.actualizarDatos(idUsuario, ActualizarCuentaIdentidadDTO(correo, primerNombre, primerApellido), idCorrelacion)` |
| `decano/cambiarestadocoordinador` | `CambiarEstadoCoordinadorDTO(idCoordinador, estaActivo, usuarioEjecutor)` | 1) facultad del decano; 2) `commandPort.cambiarEstadoCoordinador(...)`; 3) `desactivar(idUsuario, COORDINADOR, personaSinRolesActivos, idCorrelacion)` o `reactivar(idUsuario, COORDINADOR, idCorrelacion)` |

- `ResultadoSincronizacion.PENDIENTE` se traduce a respuesta exitosa con `mensajeUsuario = IAM_002` y `sincronizacionIdentidad = "PENDIENTE"` (D7).
- Errores de la DB se clasifican en `DbFailureClassifier`: `GEN_001` → `NotFoundException` (404); `VAL_006` → `ConflictException` (409); `COO_001` → `ConflictException` (409); RBAC/titularidad → `ForbiddenException` (403); `GEN_002` → `ValidationException` (400).
- `CrearCoordinadorUseCaseImpl`: se elimina `resolverCredencialInicial` con la contraseña por defecto; una contraseña vacía lanza `ValidationException` (D5).

### 3.3 Endpoints (controlador `DecanoCoordinadorGestionController`, base `/api/v1/decano/coordinadores`)

| Método y ruta | Rol (HTTP) | Request | Respuesta | Errores |
|---|---|---|---|---|
| `PUT /{id}` | `DECANO`, `ADMINISTRADOR`¹ | `ActualizarCoordinadorRequest { primerNombre, segundoNombre?, primerApellido, segundoApellido?, correo }` | `200` `ApiDataResponse<ResultadoGestionCoordinadorResponse>` con `{ idCoordinador, sincronizacionIdentidad: "OK"\|"PENDIENTE" }` y `mensajeUsuario` | 400 (validator), 401, 403, 404 (`GEN_001`), 409 (`VAL_006`) |
| `PATCH /{id}/estado` | `DECANO`, `ADMINISTRADOR`¹ | `CambiarEstadoCoordinadorRequest { estaActivo: boolean }` (obligatorio) | `200` `ApiDataResponse<ResultadoGestionCoordinadorResponse>` | 400, 401, 403, 404, 409 (`COO_001`) |

¹ `SecurityConfig.java:134` deja pasar al `ADMINISTRADOR`; el use case lo rechaza con 403 porque no tiene facultad de decano (D8). No se modifica `SecurityConfig`.

- `{id}` es el `id` del **coordinador** (`uv_coordinador.id`), no el del usuario.
- Los `GET` y `POST` existentes de `/coordinadores` **no cambian** (el `GET` solo deja de mostrar coordinadores sin programa de otras facultades, por D2).
- El stub `@PatchMapping("/coordinadores/{id}/estado")` de `DecanoPortalController` (501) se elimina; la ruta pasa al controlador nuevo.
- Validator (`400` antes del use case): nombres y apellidos no vacíos y ≤ 50 caracteres; `correo` con formato válido y ≤ 100; `estaActivo` presente; `id` UUID válido.
- Mensajes: el backend responde con `mensajeUsuario` de catálogo. El front no interpreta textos técnicos.

---

## 4. Contrato del Frontend

- `core/models/role-management.model.ts`: `CoordinadorItem` agrega `primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido`, `correo`, `idFacultad` y `estaActivoRolCoordinador`; se agregan `ActualizarCoordinadorPayload` y `ResultadoGestionCoordinador { idCoordinador: string; sincronizacionIdentidad: 'OK' | 'PENDIENTE' }`. Cero `any` en lo nuevo.
- `DeanManagementService`:
  - `updateCoordinador(id: string, payload: ActualizarCoordinadorPayload): Observable<ApiResponse<ResultadoGestionCoordinador>>` → `PUT /decano/coordinadores/{id}`.
  - `setCoordinadorEstado(id: string, estaActivo: boolean): Observable<ApiResponse<ResultadoGestionCoordinador>>` → `PATCH /decano/coordinadores/{id}/estado` con `{ estaActivo }`.
  - Se retira `toggleCoordinadorStatus` (ruta `…/toggle`) y se actualizan sus usos y los mocks.
- `DeanCoordinadoresComponent`:
  - Acción **Editar** abre `dean-coordinador-edit-modal` (standalone, `OnPush`, `input()`/`output()`), con validación instantánea.
  - Acción **Activar/Desactivar** abre `dean-coordinador-estado-modal` (confirmación) y llama a `setCoordinadorEstado`.
  - En éxito muestra `mensajeUsuario` del backend; con `sincronizacionIdentidad = 'PENDIENTE'` lo muestra como advertencia. En error muestra el `message` del backend tal cual, **sin** comparar textos.
  - Tras la mutación recarga la lista (estado en Signals; sin `setInterval`).
  - El estado y el contador salen de `estaActivoCoordinador` que entrega el backend.

---

## 5. Compatibilidad

| Cambio | Efecto | Mitigación |
|---|---|---|
| `uv_coordinador.idFacultad` ahora tiene valor en coordinadores sin programa | Cambia datos de una columna existente | Grep de consumidores y prueba de regresión (R4) |
| `CoordinadorQueryPort.consultarCoordinadoresSinPrograma(UUID)` | Rompe la firma interna | Un solo consumidor; se actualiza en el mismo PR |
| Contraseña obligatoria en el alta | Una petición sin contraseña antes funcionaba | El front ya la exige; prueba de regresión (T-120R-01) |
| Ruta `…/toggle` desaparece del front | Solo existía en el cliente | Se corrige en el mismo PR del front |
| Todo lo demás | Aditivo | — |

---

## 6. Aprobación

| Rol | Estado | Fecha |
|---|---|---|
| Owner del producto (D1–D10) | ✅ Aprobado | 2026-10-22 |
| Owner de IAM-001 (consumo del servicio y de la función de roles activos) | ⏳ | — |
| Congelamiento | ✅ `CONTRACT_FROZEN` | 2026-10-22 |
