---
status: draft
type: work-item
scope: fullstack-database-backend-infra
owner: fullstack-team
last-reviewed: 2026-10-21
---

# TEST_PLAN — IAM-001: Ciclo de vida de la cuenta institucional

**Estado:** `RED_PLANNED` (borrador). La rama de cada repo es `feature/IAM-001-ciclo-vida-identidad`. Los pasos ⚠️ van después del merge de HU035/036.

## Fuentes
- [PLAN](PLAN.md) (CA-01…CA-08, D1–D7) y [CONTRACT](CONTRACT.md).
- Skills: `uco-testing`, `uco-seguridad`, `uco-persistencia`, `uco-observabilidad`.
- Patrones:
  - `KeycloakIdentityProviderAdapterTest` + `FakeKeycloakAdminServer`
  - `KeycloakIdentityAdapterConfigurationTest`
  - `IdentityProviderIsolationRulesTest`
  - `test/test_authorized_views_rbac.sql`
  - `UsuarioControllerTest`
  - `RbacSecurityFilterChainTest`

## 1. Matriz de comportamiento

| ID | Requisito | Acción | Resultado esperado | Nivel |
|---|---|---|---|---|
| T-IDP-01 | CA-01: búsqueda exacta | El fake tiene una cuenta con `idUsuario=X` y otra con `X` como prefijo | Devuelve solo la exacta | Adapter (fake) |
| T-IDP-02 | Búsqueda sin coincidencias | — | `Optional.empty()` | Adapter |
| T-IDP-03 | Identidad ambigua | Dos cuentas con `idUsuario=X` | `IdentityProviderException`; sin efectos | Adapter |
| T-IDP-04 | Deshabilitar | Cuenta habilitada | `PUT enabled=false` y luego `POST logout`, en ese orden | Adapter |
| T-IDP-05 | Deshabilitar es idempotente | Ya deshabilitada | Sin error | Adapter |
| T-IDP-06 | El logout falla después de deshabilitar | El fake devuelve 500 en logout | Sin excepción; log `WARN`; la cuenta queda deshabilitada | Adapter |
| T-IDP-07 | Habilitar | Deshabilitada | `PUT enabled=true` | Adapter |
| T-IDP-08 | Actualizar datos | — | `PUT` con email y nombres; **nunca** llama a `reset-password` | Adapter |
| T-IDP-09 | Conflicto de correo en el IdP | El fake devuelve 409 | `IdentityProviderException("conflicto de correo")` | Adapter |
| T-IDP-10 | Retirar rol | Con rol / sin rol | `DELETE role-mappings` / no-op | Adapter |
| T-IDP-11 | Cuenta inexistente | 404 | `IdentityProviderException` tipada | Adapter |
| T-IDP-12 | `idExterno` inválido | Con `/` o con espacios | Se rechaza antes de llamar a HTTP | Adapter |
| T-IDP-13 | Token admin | Las operaciones nuevas | Reutilizan `obtenerAdminToken`; 401 del token → `IdentityProviderException` | Adapter |
| T-IDP-14 | Logs sin PII | Todas las operaciones | Los logs no contienen correo, documento ni nombres | Adapter (`ListAppender` / `OutputCaptureExtension`) |
| T-SVC-01 | D2: desactivar con otros roles activos | `personaSinRolesActivos=false` | Solo `retirarRol`; **no** se deshabilita | Unit |
| T-SVC-02 | D2: desactivar sin roles restantes | `true` | `retirarRol` + `deshabilitarCuenta` | Unit |
| T-SVC-03 | Reactivar | — | `habilitarCuenta` + `asignarRol` | Unit |
| T-SVC-04 | CA-04: falla del IdP | El puerto lanza la excepción | `registrar(desfase)`, contador +1, `PENDIENTE` | Unit |
| T-SVC-05 | Cuenta no encontrada | `Optional.empty()` | Se registra el desfase, `PENDIENTE` | Unit |
| T-SVC-06 | Correlación | — | El `idCorrelacion` se propaga al desfase | Unit |
| T-REC-01 | CA-05: reconciliar desactivación pendiente | DB: usuario inactivo; IdP: habilitado | Se deshabilita; `RESUELTO` | Unit + IT |
| T-REC-02 | Reconciliar una cuenta faltante | IdP sin cuenta | Se crea sin contraseña y **deshabilitada**; queda en `operacionesAplicadas` | Unit |
| T-REC-03 | Sin pendientes | — | `IAM_003`, 409 | Controller |
| T-REC-04 | Ámbito | Admin de otra institución | 403 | Controller + DB |
| T-REC-05 | Idempotencia | Reconciliar dos veces | La segunda: 409 `IAM_003` o `RESUELTO` sin cambios | IT |
| T-DB-01 | CA-03: cambiar estado | Usuario activo → 0 | `Usuario.estado=0`; `uv_usuario_perfil.estado=0` | DB |
| T-DB-02 | Cambiar estado es idempotente | Mismo estado | Éxito sin cambios | DB |
| T-DB-03 | Usuario inexistente | — | Error de catálogo (`GEN_001` / validación existente) | DB |
| T-DB-04 | Actualizar datos | Correo nuevo libre | Se actualiza; el documento no cambia | DB |
| T-DB-05 | Correo de otro usuario | — | `VAL_006`, sin cambios | DB |
| T-DB-06 | Reglas de texto | Vacío / > 50 caracteres | Errores de las reglas existentes | DB |
| T-DB-07 | Sin transacción propia | Dentro de un `BEGIN TRAN` + `ROLLBACK` del test | El cambio se revierte; `@@TRANCOUNT` vuelve al valor del test | DB |
| T-DB-08 | `ufn_usuario_tiene_roles_activos` | Usuario con 0, 1 y 2 roles; activo / inactivo | 0 / 1 según el caso | DB |
| T-RBAC-01 | CA-06: los 6 valores actuales | `ADMINISTRADOR`, `DECANO`, `COORDINADOR`, `DOCENTE`, `ESTUDIANTE`, `DOCENTE,COORDINADOR` y los códigos `AD`…`ES` | Se aceptan para el perfil correcto | DB (`test_rbac_coincidencia_exacta.sql`) |
| T-RBAC-02 | Coincidencias parciales | `DOC`, `ADMIN`, `%`, `DECAN`, `''` | **Se rechazan** (con `LIKE` se aceptaban) | DB |
| T-RBAC-03 | Regresión | `test_suite.sql` completo | Verde sin cambiar ningún llamador | DB |
| T-DES-01 | Registrar desfase | — | Fila `PENDIENTE`, `intentos=1`; un segundo registro del mismo usuario y operación incrementa `intentos` | DB |
| T-DES-02 | Consulta paginada de desfases | Admin | Solo los de su institución | DB |
| T-SEC-01 | CA-07 / D4 | `POST /usuarios` con JWT ESTUDIANTE / DOCENTE / COORDINADOR / DECANO | 403 | `RbacSecurityFilterChainTest` ⚠️ |
| T-SEC-02 | D4: admin | JWT ADMINISTRADOR | Llega al controller (200/400 según el payload) | `RbacSecurityFilterChainTest` ⚠️ |
| T-SEC-03 | Reconciliación | Roles ajenos o anónimo | 403 / 401 | idem |
| T-ARCH-01 | Aislamiento | ArchUnit | El puerto y el servicio no dependen de Keycloak ni de `infrastructure` | `IdentityProviderIsolationRulesTest`, `CleanArchitectureRulesTest` |
| T-WIR-01 | Wiring | Contexto | `SincronizarCuentaInstitucionalService` y la reconciliación se cablean | `IdentidadWiringConfigurationTest` (nuevo) |
| T-SEED-01 | CA-08: colisión | Después del cambio | `SELECT id FROM Usuario` sin duplicados de rol para `E1F2…006`; los 3 scripts de seed corren en cualquier orden sin errores | DB (script) |
| T-SEED-02 | Seed canónico en Keycloak | Correr el script 2 veces | 2.ª corrida sin cambios; login de los 5 roles con `get-test-token.ps1`; el atributo `idUsuario` = `Usuario.id` | Manual (MV) / script |
| T-SEED-03 | `idUsuario` ambiguo | Dos cuentas con el mismo `idUsuario` en el realm | El script aborta con un mensaje claro | Script |
| T-MV-01 | Deshabilitar contra Keycloak real | Usuario de prueba | Falla el login y falla el *refresh* | Manual |
| T-MV-02 | Ventana del access token (D5) | Token emitido antes de deshabilitar | Sigue sirviendo hasta `exp` (≤ 900 s), y las mutaciones fallan antes por el RBAC de la DB | Manual (documentado) |

## 2. Pruebas RED por capa

**DB (`GestioAsistenciaDB/test/`):**
- `test_usp_internal_cambiar_estado_usuario.sql`: T-DB-01…03, 07.
- `test_usp_internal_actualizar_datos_usuario.sql`: T-DB-04…06.
- `test_ufn_usuario_tiene_roles_activos.sql`: T-DB-08.
- `test_rbac_coincidencia_exacta.sql`: T-RBAC-01, 02.
- `test_desfase_identidad.sql`: T-DES-*.
- `:r` en `test_suite.sql` ⚠️.
- Fixtures propios, sin GUIDs del seed.

**Backend:**
- `KeycloakIdentityProviderAdapterTest` (se amplía): T-IDP-*. Para eso `FakeKeycloakAdminServer` gana *handlers* de `PUT /users/{id}`, `POST /users/{id}/logout`, `DELETE role-mappings` y búsqueda `q=`.
- `SincronizarCuentaInstitucionalServiceTest`: T-SVC-*.
- `ReconciliarCuentaUseCaseImplTest` y `AdminIdentidadControllerTest`: T-REC-*.
- `UsuarioSincronizacionIdentidadSqlServerIT`: T-REC-01, 05, T-DES-*.
- `RbacSecurityFilterChainTest` ⚠️: T-SEC-*.
- `IdentidadWiringConfigurationTest`.
- Los stubs que implementan `IdentityProviderPort` en los tests existentes se actualizan para compilar (R5 del PLAN; **sin** cambiar sus aserciones).

**Scripts e infra:**
- T-SEED-01 con `sqlcmd`.
- T-SEED-02/03 con `seed-canonical-users.ps1 -WhatIf` y una corrida real local, con la evidencia en `VALIDATION.md`.

**Comandos:**
```powershell
cd GestioAsistenciaBackend; .\mvnw.cmd test
```
```powershell
cd GestioAsistenciaBackend; .\mvnw.cmd verify -Pintegration
```
Y `test_suite.sql` en `sql_server_asistencias` (AGENTS.md §4.1).

**Cobertura:**
- Servicio y reconciliación: 100 % de ramas.
- Métodos nuevos del adapter: 100 % de líneas.
- Bundle: LINE ≥ 80 % y BRANCH ≥ 70 %.

## 3. RED_SNAPSHOT (fase 03)

| Repo | Commit base | Archivos | SHA-256 / commit RED | Comando | Exit | Falla esperada |
|---|---|---|---|---|---|---|
| GestioAsistenciaDB | — | §2 DB | — | `test_suite.sql` | — | No existen los SP internos ni la función; T-RBAC-02 acepta parciales (`LIKE`) |
| GestioAsistenciaBackend | — | §2 Backend | — | `mvnw test` | — | Faltan los métodos del puerto y el servicio; `POST /usuarios` responde 2xx a ESTUDIANTE |

## 4. Congelamiento y falsos positivos

- Después del RED no se modifican las pruebas sin un registro `TEST_CONTRACT_CONFLICT`.
- Hay que evitar:
  - probar el adapter con Mockito sobre `HttpClient`: se usa `FakeKeycloakAdminServer`, con HTTP real;
  - un T-RBAC que solo pruebe los valores felices: hacen falta los negativos de T-RBAC-02, porque son los que demuestran el cambio;
  - dar por buena la deshabilitación solo porque el login falla: también hay que comprobar que el *refresh* falla (logout);
  - seeds que "funcionan" porque se corrieron en un orden concreto (T-SEED-01 exige cualquier orden).
