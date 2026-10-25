---
status: draft
type: work-item
scope: fullstack-database-backend-infra
owner: fullstack-team
last-reviewed: 2026-10-21
---

# CONTRACT — IAM-001: Ciclo de vida de la cuenta institucional

> **Work Item:** `IAM-001-ciclo-vida-cuenta-identidad`
> **Estado:** `DRAFT` (sin `.sha256`). Pasa a `CONTRACT_FROZEN` cuando el owner apruebe D1–D7 del [PLAN](PLAN.md).
> **Supuestos del borrador** (recomendaciones del PLAN):
> - D1(a): sin `idExterno` en DB.
> - D2(a): se desactiva el rol en su ámbito; la persona solo si no le queda ningún rol activo.
> - D3(a): tabla de desfases + reconciliación por admin.
> - D4(a): `POST /usuarios` solo para `ADMINISTRADOR`.
> - D5(a): token corto + logout.
> - D6(a), D7(a).

---

## 1. Contrato del puerto de aplicación

`application/secondaryports/identity/IdentityProviderPort.java` (aditivo; las firmas actuales no cambian):

```java
CuentaIdentidadDTO crearCuenta(CrearCuentaIdentidadDTO dto);                     // existente
void eliminarCuenta(String idExterno);                                            // existente
void asignarRol(String idExterno, InstitutionalRole rol);                         // existente

Optional<CuentaIdentidadDTO> buscarCuentaPorIdUsuario(UUID idUsuario);            // NUEVO
void deshabilitarCuenta(String idExterno);                                        // NUEVO: enabled=false + cierre de sesiones
void habilitarCuenta(String idExterno);                                           // NUEVO: enabled=true
void actualizarDatosCuenta(String idExterno, ActualizarCuentaIdentidadDTO dto);  // NUEVO
void retirarRol(String idExterno, InstitutionalRole rol);                         // NUEVO
```

- `ActualizarCuentaIdentidadDTO(String correo, String primerNombre, String primerApellido)`: todos son obligatorios. **No** incluye `username` (es el documento y no se edita) ni la contraseña (DA-5).
- Semántica:
  - Todas las operaciones son **idempotentes**: deshabilitar una cuenta ya deshabilitada, o retirar un rol que no tiene, no falla.
  - `buscarCuentaPorIdUsuario` devuelve `Optional.empty()` si no hay coincidencia exacta y lanza `IdentityProviderException` si hay más de una (identidad ambigua).
  - En la respuesta de búsqueda, `CuentaIdentidadDTO.newlyCreated` es `false`.
- Aislamiento: el puerto no expone tipos de Keycloak (`IdentityProviderIsolationRulesTest`). El rol sigue tipado con `InstitutionalRole` (`InstitutionalRolePurityTest`).

## 2. Contrato del adapter Keycloak (Admin REST API, realm `asistencias-uco`)

| Operación | Llamadas | Errores |
|---|---|---|
| `buscarCuentaPorIdUsuario` | `GET /admin/realms/{realm}/users?q=idUsuario:{uuid}&exact=true&briefRepresentation=false`, filtrando en el cliente por la coincidencia **exacta** del atributo (misma validación que `resolverUsuario`) | No-2xx → `IdentityProviderException`; >1 coincidencia → "identidad ambigua" |
| `deshabilitarCuenta` | `PUT /users/{id}` con `{"enabled": false}` y luego `POST /users/{id}/logout` | 404 → `IdentityProviderException("cuenta inexistente")`; si falla el logout después de deshabilitar → log `WARN`, sin revertir (la cuenta ya quedó deshabilitada) |
| `habilitarCuenta` | `PUT /users/{id}` con `{"enabled": true}` | Igual |
| `actualizarDatosCuenta` | `PUT /users/{id}` con `{"email", "firstName", "lastName", "emailVerified": true}` (D6) | 409 (correo en uso en el IdP) → `IdentityProviderException("conflicto de correo")` |
| `retirarRol` | `DELETE /users/{id}/role-mappings/clients/{apiClientUuid}` con la representación del rol (resuelta igual que en `ensureClientRole`) | El rol ya ausente → no-op |

- `idExterno` pasa por la misma validación de formato que ya aplica el adapter (l.276: sin `/` y sin espacios).
- Logs estructurados por operación (`operation`, `stage=START|OK|FAIL`, `correlationId`), sin PII.

## 3. Servicio de aplicación `SincronizarCuentaInstitucionalService`

Paquete `application/features/identidad/sincronizarcuenta/`. Es un POJO cableado con `@Bean` en `IdentidadWiringConfiguration`.

```java
ResultadoSincronizacion desactivar(UUID idUsuario, InstitutionalRole rol, boolean personaSinRolesActivos, UUID idCorrelacion);
ResultadoSincronizacion reactivar(UUID idUsuario, InstitutionalRole rol, UUID idCorrelacion);
ResultadoSincronizacion actualizarDatos(UUID idUsuario, ActualizarCuentaIdentidadDTO datos, UUID idCorrelacion);
```

Reglas:
1. **Se invoca después del commit en DB** (lo llama el use case del grupo una vez que la fachada SQL respondió `estadoResultado = 1`).
2. `desactivar` siempre hace `retirarRol(rol)`, y además `deshabilitarCuenta` si `personaSinRolesActivos` (D2).
3. `reactivar` hace `habilitarCuenta` + `asignarRol(rol)`.
4. Si `buscarCuentaPorIdUsuario` viene vacío, o el IdP lanza `IdentityProviderException`:
   - se registra el desfase con `UsuarioSincronizacionIdentidadPort.registrar(idUsuario, operacion, errorTecnico, idCorrelacion)`;
   - se incrementa `identity_drift_total{operation}`;
   - se devuelve `ResultadoSincronizacion.PENDIENTE`.
5. El use case que lo llama traduce `PENDIENTE` a una respuesta **exitosa con advertencia** (HTTP 200 con `mensajeUsuario` de `IAM_002`): el cambio en DB es la SSOT y ya ocurrió. La alternativa de devolver error (`IAM_001`) queda para las altas (el patrón actual). Esta diferencia es deliberada: un alta sin cuenta no sirve, pero una desactivación ya protege las mutaciones vía RBAC en DB.

## 4. Contrato de Base de Datos

### 4.1 `dbo.usp_internal_cambiar_estado_usuario`

| Parámetro | Tipo | Regla |
|---|---|---|
| `@idUsuario` | `UNIQUEIDENTIFIER` | Existe (`usp_validar_usuario_existe_por_id_interno`) |
| `@estaActivo` | `BIT` | Estado destino. Si ya lo tiene, no cambia nada y responde éxito |
| `@idCorrelacion` | `UNIQUEIDENTIFIER` | |
| `@mensajeUsuarioResultado`, `@mensajeTecnicoResultado`, `@estadoResultado` | OUTPUT | Tupla canónica |

- `UPDATE dbo.Usuario SET estado = @estaActivo WHERE id = @idUsuario`, **sin transacción propia**: corre dentro de la transacción de la fachada pública que lo llama, igual que los demás `_interno`.
- **Uso desde las fachadas (regla D2):** la fachada de cada grupo desactiva primero el rol en su ámbito y luego llama a `dbo.ufn_usuario_tiene_roles_activos(@idUsuario)` (función nueva sobre `uv_usuario_perfil` y los estados de rol que existan). Solo si devuelve 0 invoca este SP con `@estaActivo = 0`. La fachada devuelve en su resultset la columna adicional `personaSinRolesActivos BIT` (contrato de cada grupo), para que el backend sepa si debe deshabilitar la cuenta.

### 4.2 `dbo.usp_internal_actualizar_datos_usuario`

| Parámetro | Tipo | Regla |
|---|---|---|
| `@idUsuario` | `UNIQUEIDENTIFIER` | Existe |
| `@primerNombre`, `@segundoNombre`, `@primerApellido`, `@segundoApellido` | `NVARCHAR(50)` | Mismas reglas de texto que `usp_sincronizar_usuario_interno` |
| `@correo` | `NVARCHAR(100)` | Formato válido. Único en `uv_usuario` excluyendo al propio usuario; se lee con `UPDLOCK, HOLDLOCK` (`VAL_006`) |
| `@idCorrelacion` + OUTPUT | | |

El tipo y el número de documento **no** se editan (son el `username` del IdP).

### 4.3 `dbo.ufn_usuario_tiene_roles_activos(@idUsuario) RETURNS BIT`

Devuelve 1 si existe alguna fila en `uv_usuario_perfil` del usuario cuyo rol tenga **estado propio activo**. En este WI solo hay `Usuario.estado`; los grupos que agreguen estado de rol (B: `DocentePrograma.estado`) **extienden la función** en su perímetro. Es determinista sobre vistas.

### 4.4 RBAC exacto: `usp_validar_permiso_rbac_usuario_interno`

```sql
-- antes:  up.codigoPerfil = TRIM(s.value) OR UPPER(up.nombrePerfil) LIKE CONCAT('%', UPPER(TRIM(s.value)), '%')
-- después: up.codigoPerfil = TRIM(s.value) OR UPPER(up.nombrePerfil) = UPPER(TRIM(s.value))
```

La firma no cambia. Los valores válidos son los códigos (`AD`, `DE`, `CD`, `DO`, `ES`) y los nombres (`ADMINISTRADOR`, `DECANO`, `COORDINADOR`, `DOCENTE`, `ESTUDIANTE`), separados por coma.

### 4.5 `dbo.UsuarioSincronizacionIdentidad` (D3)

```sql
id UNIQUEIDENTIFIER PK, usuario UNIQUEIDENTIFIER NOT NULL FK Usuario(id),
operacion NVARCHAR(30) NOT NULL,          -- valores del catálogo de parámetros IDENTIDAD/OPERACION_* (CREAR, DESACTIVAR, REACTIVAR, ACTUALIZAR)
estado NVARCHAR(10) NOT NULL,             -- valores del catálogo IDENTIDAD/ESTADO_* (PENDIENTE, RESUELTO)
intentos INT NOT NULL, ultimoErrorTecnico NVARCHAR(1000) NULL,
idCorrelacion UNIQUEIDENTIFIER NOT NULL, fechaRegistroUtc DATETIME2(0) NOT NULL, fechaResolucionUtc DATETIME2(0) NULL
```

SP públicos (transaccionales, RBAC):
- `usp_registrar_desfase_identidad`: lo invoca el backend; RBAC = el ejecutor de la operación original.
- `usp_resolver_desfase_identidad`.
- `usp_consultar_desfases_identidad`: paginado, `ADMINISTRADOR` de la institución.

Mensajes nuevos en `04_mensaje.sql`:
- `IAM_001`: "No fue posible completar la cuenta de acceso. El registro quedó guardado y el administrador puede reintentar la sincronización."
- `IAM_002`: "El cambio se guardó. La cuenta de acceso se sincronizará en cuanto el servicio de identidad esté disponible."
- `IAM_003`: "No existen sincronizaciones pendientes para el usuario."

## 5. Contrato HTTP

| Método y ruta | Rol | Request | Respuesta | Errores |
|---|---|---|---|---|
| `POST /api/v1/usuarios` (existente) | **`ADMINISTRADOR`** (antes `authenticated()`; D4) | Sin cambio | Sin cambio | 403 para los demás roles |
| `GET /api/v1/admin/identidad/desfases?pagina&tamano&estado` | `ADMINISTRADOR` (comodín `/api/v1/admin/**`) | — | `ApiListResponse<DesfaseIdentidadResponse>` con `{ id, idUsuario, nombreCompleto, operacion, estado, intentos, fechaRegistroUtc }` | 400, 401, 403 |
| `POST /api/v1/admin/usuarios/{idUsuario}/identidad/reconciliar` | `ADMINISTRADOR` de la misma institución | — | `ApiDataResponse<ReconciliacionIdentidadResponse>` con `{ idUsuario, resultado: RESUELTO\|PENDIENTE, operacionesAplicadas[] }` | 404 (`GEN_001`), 409 (`IAM_003`), 403 |

**Reconciliación:** lee el estado de la DB (SSOT: usuario activo y roles activos) y lo **impone** en el IdP:
1. crea la cuenta si falta, sin contraseña. Una cuenta creada sin contraseña queda **deshabilitada** hasta que el admin la habilite con una contraseña nueva por un flujo fuera del alcance (DA-5); se informa en `operacionesAplicadas`.
2. habilita o deshabilita la cuenta.
3. asigna o retira roles.
4. actualiza correo y nombres.

Después marca `RESUELTO`. Es idempotente.

> Que la cuenta recreada quede sin contraseña es la consecuencia directa de DA-5 (sin flujos de clave). Se acepta y queda documentado; la alternativa de generar una clave rompería DA-5.

## 6. Infraestructura

- `infra/keycloak/scripts/seed-canonical-users.ps1`:
  - parámetros `-SqlContainer sql_server_asistencias -Realm asistencias-uco -Password 'Test1234!'` (**solo local**);
  - lee `uv_usuario` + `uv_usuario_perfil` de los usuarios del seed y, para cada uno, crea o actualiza la cuenta (`username` = documento, atributo `idUsuario` = `Usuario.id`), fija la contraseña solo si es nueva y asigna los client roles de `asistencias-api`;
  - es idempotente; con `-WhatIf`, solo muestra lo que haría;
  - falla si detecta un `idUsuario` asignado a dos cuentas.
- **Ids de seed:** en `scripts/database/seed_realtime_test_group.sql` y `migrations/02_datos_semilla_representativos.sql`, los estudiantes de prueba que usan `E1F2…006` pasan a `E1F2…00B` (o al siguiente libre comprobado). `E1F2…006` queda solo para `admin.sistema`.
- **Realm (D5):** `accessTokenLifespan` = 900 s (propuesta) en `infra/keycloak/realm-import/asistencias-uco-realm.json` y su copia de Infra. Aplica también al bootstrap de Infra (fuera de este repo; requiere aprobación de Infra).

## 7. Aprobación

| Rol | Estado | Fecha |
|---|---|---|
| Owner del producto | ⏳ Pendiente (D1–D7) | — |
| Owner de Infra (permisos del client admin, duración del token) | ⏳ | — |
| Congelamiento | ⏳ | — |
