---
status: draft
type: work-item
scope: fullstack-database-backend-infra
owner: fullstack-team
last-reviewed: 2026-10-21
---

# PLAN — IAM-001: Ciclo de vida de la cuenta institucional (habilitador transversal)

Fase 01: Planificación y Definition of Ready (DoR), según `GUIA_METODICA_IMPLEMENTACION_HU.md`, `docs/governance/DEFINITION_OF_READY.md`, `docs/security/keycloak-identity-provider.md` y `AGENTS.md`.
Programa padre: [`REG-000`](../REG-000-programa-registro-vinculacion-roles/PLAN.md), grupo **E**.
**Es requisito de** los grupos F, G, H, I y J (editar y activar/desactivar Facultad/Decano, Admin, Coordinador, Docente y Estudiante).

---

## 1. Identidad y objetivo

- **Work Item ID:** `IAM-001-ciclo-vida-cuenta-identidad`
- **Tipo:** habilitador técnico, sin HU de catálogo propia. Cierra o acota TD-013 y TD-015 y documenta TD-014.
- **Fecha:** 2026-10-21. **Base Git:** `develop` @ `4ff37ff`.
- **Objetivo:** que los grupos siguientes puedan **desactivar, reactivar y actualizar** un usuario de cualquier rol de forma coherente entre la DB (SSOT de estado) y Keycloak (autenticación), con reglas comunes y probadas una sola vez. También corrige la base que necesitan todas las pruebas E2E: usuarios canónicos en Keycloak y seeds sin colisiones.

### Criterios de aceptación

| ID | Criterio |
|---|---|
| CA-01 | `IdentityProviderPort` permite **buscar la cuenta por `idUsuario`**, **deshabilitarla** (con cierre de sesiones), **habilitarla** y **actualizar** correo y nombres, sin tocar la contraseña (DA-5). |
| CA-02 | `KeycloakIdentityProviderAdapter` implementa esas operaciones y las prueba contra `FakeKeycloakAdminServer`. Es idempotente: deshabilitar dos veces no falla, y una cuenta inexistente da un resultado tipado, no una excepción genérica. |
| CA-03 | La DB tiene procedimientos **internos** reutilizables para cambiar el estado de un usuario (`Usuario.estado`) y actualizar sus datos personales con validación de unicidad. Los usarán las fachadas públicas por rol de F–J. |
| CA-04 | Hay un componente de aplicación único, `SincronizarCuentaInstitucionalService`, que aplica la política **DB primero → IdP** con un error controlado y **registra el desfase** cuando el IdP falla después del commit (TD-015). |
| CA-05 | Existe una forma auditable de **reconciliar** un usuario desfasado (D3). |
| CA-06 | La validación RBAC en DB deja de depender de `LIKE '%valor%'` sobre el nombre del perfil (coincidencia exacta), sin romper a ninguno de los 23 SP que la invocan. |
| CA-07 | La política "quién aprovisiona qué rol" (REG-000 §4) queda documentada en `docs/security/` y `POST /api/v1/usuarios` deja de aprovisionar `ESTUDIANTE` a cualquier usuario autenticado (D4). |
| CA-08 | Un script versionado provisiona en Keycloak los **usuarios canónicos** del seed, con su `idUsuario` correcto, y se elimina la colisión del id `E1F2…006`. |

---

## 2. AS-IS (evidencia) vs. TARGET

| Dimensión | AS-IS (evidencia) | TARGET |
|---|---|---|
| **Puerto de identidad** | `application/secondaryports/identity/IdentityProviderPort.java`: solo `crearCuenta(CrearCuentaIdentidadDTO)`, `eliminarCuenta(String idExterno)` y `asignarRol(String idExterno, InstitutionalRole)`. `CuentaIdentidadDTO(idExterno, newlyCreated)`. **La DB no guarda el `idExterno`** (no hay columna en `Usuario`): la cuenta se resuelve por el atributo `idUsuario` dentro del adapter (`resolverUsuario`, privado). | Métodos nuevos: `Optional<CuentaIdentidadDTO> buscarCuentaPorIdUsuario(UUID)`, `void deshabilitarCuenta(String idExterno)` (incluye cerrar sesiones), `void habilitarCuenta(String idExterno)`, `void actualizarDatosCuenta(String idExterno, ActualizarCuentaIdentidadDTO)` y `void retirarRol(String idExterno, InstitutionalRole)`. Las firmas existentes no cambian. |
| **Adapter Keycloak** | `infrastructure/adapter/secondary/identity/keycloak/KeycloakIdentityProviderAdapter.java`: token admin `client_credentials`; `crearCuenta` busca por `idUsuario`, crea, fija la contraseña **solo si `newlyCreated`** (l.109-111) y asegura el *client role* (`ensureClientRole`). Es la única implementación del puerto (además de los stubs de test). Activado por `KeycloakIdentityAdapterConfiguration` (`app.adapters.identity.provider=keycloak`, `matchIfMissing=true`). | Implementa los métodos nuevos con la Admin REST API: `GET /users?q=idUsuario:<uuid>&exact=true`, `PUT /users/{id}` (`enabled`, `email`, `firstName`, `lastName`), `POST /users/{id}/logout` y `DELETE /users/{id}/role-mappings/clients/{clientUuid}`. Reutiliza la validación de `externalId` y el manejo de errores existentes. |
| **Estado del usuario en DB** | `Usuario.estado BIT`. Las tablas de rol (`Decano`, `Coordinador`, `Docente`, `Estudiante`, `Administrador`) **no tienen estado**. `uv_usuario_perfil` deriva `estado` de `Usuario.estado`. **Ningún SP hace `UPDATE` de `Usuario`** (Grep sobre `schema/`: 0 coincidencias). | Nuevos `usp_internal_cambiar_estado_usuario` (`@idUsuario`, `@estaActivo`, OUTPUT con la tupla; idempotente) y `usp_internal_actualizar_datos_usuario` (nombres y correo; unicidad del correo con `UPDLOCK, HOLDLOCK`; el documento **no** se edita). Son internos: los invocan las fachadas públicas de F–J, que aportan RBAC, titularidad y transacción. |
| **Estado de una vinculación por rol** | El estado de la vinculación docente (`DocentePrograma.estado`) llega con el grupo B. Coordinador, Decano y Admin solo tienen `Usuario.estado`. | Regla común (CONTRACT §4): **desactivar el rol en su ámbito** ≠ **desactivar la persona**. Las fachadas de F–J deciden cuál aplican; E solo provee las piezas. La cuenta de Keycloak se deshabilita **solo cuando la persona no conserva ningún rol activo** (D2). |
| **Validación RBAC en DB** | `usp_validar_permiso_rbac_usuario_interno.sql` l.57-60: `up.codigoPerfil = TRIM(s.value) OR UPPER(up.nombrePerfil) LIKE CONCAT('%', UPPER(TRIM(s.value)), '%')`. Los llamadores pasan **nombres** (`'DECANO'`, `'COORDINADOR'`…; 23 llamadas), pero los códigos son `AD`/`DE`/`CD`/`DO`/`ES` (`seed/09_perfil.sql`). **Hoy funciona gracias al `LIKE`.** | Coincidencia **exacta**: `up.codigoPerfil = v OR UPPER(up.nombrePerfil) = UPPER(v)`. Ningún llamador cambia; se agrega una prueba que recorre los 6 valores usados hoy y casos negativos (`'DOC'`, `'%'`, `'ADMIN'`). |
| **Política de aprovisionamiento (TD-013)** | `POST /api/v1/usuarios` → `ProvisionarUsuarioUseCaseImpl`, con `InstitutionalRole.ESTUDIANTE` **fijo** (deuda 2B.2-D). `SecurityConfig.java:146` lo deja en `authenticated()`. Su único consumidor en el front es `features/auth/register/register.component.ts:313`, vía `user.service.ts:14`, y **no se puede abrir** (`app.routes.ts:26` redirige `register` → `login`). Ningún script lo usa. | D4: se restringe a `ADMINISTRADOR` ya, y se retira cuando el grupo C entregue el autorregistro por QR. La política queda en `docs/security/identity-provisioning-policy.md` (matriz de REG-000 §4). |
| **Consistencia DB↔IdP (TD-015)** | Cada use case hace DB y luego `crearCuenta`; si Keycloak falla lanza `InternalApplicationException` y la fila en DB queda **sin cuenta**, sin rastro persistente. | `SincronizarCuentaInstitucionalService` captura `IdentityProviderException` después del commit, **registra el desfase** (tabla `UsuarioSincronizacionIdentidad`, D3) y devuelve un error controlado con código de catálogo `IAM_001`. Un endpoint de administración reintenta la sincronización de un usuario (D3). |
| **Usuario inactivo con token vigente** | `SecurityContextAuthenticatedUserResolver` no consulta la DB. Los SP de comando sí rechazan al inactivo (RBAC sobre `uv_usuario_perfil.estado`), pero **las lecturas HQL no**. La duración del token no está fijada en `infra/keycloak/realm-import/asistencias-uco-realm.json`, y `docs/autenticacion-usuarios-y-roles.md` menciona 24 h. | Al deshabilitar se cierran las sesiones (`POST /users/{id}/logout`), lo que invalida el *refresh*. El *access token* vigente sigue sirviendo hasta que expira. D5 decide entre acortar su duración o verificar el estado en cada request. |
| **Seeds y usuarios canónicos** | `schema/seed/12_usuarios_roles.sql` crea 7 usuarios (`E1F2…000` a `…006`). `scripts/database/seed_realtime_test_group.sql` y `migrations/02_datos_semilla_representativos.sql` **reutilizan `E1F2…006`** (admin.sistema) como estudiante. Los realm imports tienen `"users": []`. `AsistenciasUCO-Infra/components/keycloak/scripts/seed-users.ps1` usa por defecto `f1a2…003` (`Docente.id`) como `idUsuario`. `infra/keycloak/scripts/seed-e2e-users.ps1` solo crea usuarios E2E. | Los estudiantes extra pasan a ids libres (`E1F2…00B`+) en los dos scripts. Un script nuevo `infra/keycloak/scripts/seed-canonical-users.ps1` lee los usuarios canónicos desde la DB (`uv_usuario` + `uv_usuario_perfil`), con contraseña `Test1234!` solo en local y un rol por perfil, y es idempotente. Se corrige el `idUsuario` por defecto de `seed-users.ps1` (Infra). |
| **Correo verificado (TD-014)** | El adapter crea las cuentas con `emailVerified=true`. | Sin cambio de código. **D6** documenta la política. |

---

## 3. Clase de cambio y perímetro de rutas

- **Change class:** `BEHAVIOR_CHANGE` (puerto y adapter nuevos, endurecimiento de RBAC, restricción de `POST /usuarios`) + `PERSISTENCE` (SP internos, tabla de desfase con D3) + `INFRASTRUCTURE` (seeds y scripts Keycloak).
- **PRIMARY_VARIABLE:** ciclo de vida coherente de la cuenta institucional entre DB e IdP.
- **ALLOWED_PATHS:**
  - `GestioAsistenciaBackend/docs/work-items/IAM-001-ciclo-vida-cuenta-identidad/**`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/identity/{IdentityProviderPort.java, dto/ActualizarCuentaIdentidadDTO.java}`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/features/identidad/{sincronizarcuenta, reconciliarcuenta}/**` (nuevos)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/repository/UsuarioSincronizacionIdentidadPort.java` (nuevo, D3)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/identity/keycloak/**`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/UsuarioSincronizacionIdentidadJpaRepository.java` (nuevo, D3)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/admin/{AdminIdentidadController.java, response/*}` (nuevo, D3)
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/wiring/{UsuarioWiringConfiguration.java, IdentidadWiringConfiguration.java (nuevo)}`
  - `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/security/SecurityConfig.java` ⚠️ (solo la línea de `POST /api/v1/usuarios` y la ruta de reconciliación; después del merge de HU035/036)
  - `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/**` (tests del perímetro, `FakeKeycloakAdminServer`, `RbacSecurityFilterChainTest` ⚠️)
  - `GestioAsistenciaBackend/docs/security/{keycloak-identity-provider.md, identity-provisioning-policy.md (nuevo)}`, `docs/baseline/TECHNICAL_DEBT.md` (estado de TD-013/014/015)
  - `GestioAsistenciaBackend/infra/keycloak/scripts/seed-canonical-users.ps1` (nuevo), `infra/keycloak/realm-import/asistencias-uco-realm.json` (solo la duración del token, si D5 = a)
  - `GestioAsistenciaDB/schema/stored-procedures/{usp_internal_cambiar_estado_usuario, usp_internal_actualizar_datos_usuario}.sql` (nuevos), `usp_validar_permiso_rbac_usuario_interno.sql`
  - `GestioAsistenciaDB/schema/functions/ufn_usuario_tiene_roles_activos.sql` (nueva)
  - `GestioAsistenciaDB/schema/tables/UsuarioSincronizacionIdentidad.sql` + `migrations/<nn>_iam001_sincronizacion_identidad.sql` + `schema/stored-procedures/{usp_registrar_desfase_identidad, usp_resolver_desfase_identidad, usp_consultar_desfases_identidad}.sql` + parámetros `IDENTIDAD/*` en `schema/seed/03_parametro.sql` (D3)
  - `GestioAsistenciaDB/schema/seed/04_mensaje.sql` (`IAM_*`, `USR_*`)
  - `GestioAsistenciaDB/test/{test_usp_internal_cambiar_estado_usuario, test_usp_internal_actualizar_datos_usuario, test_ufn_usuario_tiene_roles_activos, test_rbac_coincidencia_exacta, test_desfase_identidad}.sql` (nuevos)
  - `scripts/database/seed_realtime_test_group.sql`, `GestioAsistenciaDB/migrations/02_datos_semilla_representativos.sql` (solo para cambiar el id que colisiona)
  - `AsistenciasUCO-Infra/components/keycloak/scripts/seed-users.ps1` (solo el `idUsuario` por defecto)
- **FORBIDDEN_PATHS:**
  - Contratos WORM (`docs/contracts/openapi/**`, `BACKEND_GOLDEN_PATH_CONTRACT.*`, `docs/contracts/external/db/**`)
  - `schema/tables/Usuario.sql` (no se agrega `idExterno`; D1)
  - Use cases de alta existentes (`CrearDecanoUseCaseImpl`, `CrearCoordinadorUseCaseImpl`, `RegistrarEstudianteUseCaseImpl`): **no se migran** a `SincronizarCuentaInstitucionalService` en este WI; cada grupo lo adopta en su perímetro (D7)
  - Archivos de HU035/036
  - `AsistenciasUCO-Infra/docs/**`
- **CONTRACTS:** puerto de aplicación (aditivo); HTTP (restricción de `POST /usuarios` + endpoint admin de reconciliación); DB (SP internos, tabla y RBAC exacto).
- **PROVIDERS:** Keycloak Admin REST API (realm `asistencias-uco`, client `asistencias-backend-admin`); SQL Server.
- **EXTERNAL_ENVIRONMENT:** Keycloak `:8081` local para el IT manual y el script de seed; `sql_server_asistencias`.
- **SECURITY_IMPACT:** **alto**. Deshabilitar cuentas y cerrar sesiones; restringir el aprovisionamiento; endurecer RBAC. El client admin necesita `manage-users` (ya lo usa `crearCuenta`) y se verifica que alcance para `logout` y `role-mappings` DELETE.
- **OBSERVABILITY_IMPACT:** logs estructurados `IDENTITY_DISABLE_ACCOUNT`, `IDENTITY_ENABLE_ACCOUNT`, `IDENTITY_UPDATE_ACCOUNT`, `IDENTITY_DRIFT_RECORDED` y `IDENTITY_RECONCILE`, con `correlationId` e `idUsuario` y sin PII. Contador Micrometer `identity_drift_total{operation}`.
- **TEST_LEVEL_REQUIRED:** T-SQL + JUnit unit/slice + adapter contra `FakeKeycloakAdminServer` + IT SQL Server + validación manual contra Keycloak real.
- **ROLLBACK:** los métodos del puerto son aditivos y sin consumidores hasta F–J, así que se revierte el PR. El cambio del RBAC exacto es un commit aislado que se puede revertir. La restricción de `POST /usuarios` es una línea de `SecurityConfig`.
- **CONSUMERS:** grupos F, G, H, I y J; administrador (reconciliación); pruebas E2E (seed canónico).
- **STOP_CONDITIONS:**
  - D1–D7 sin resolver.
  - El client admin de Keycloak no tiene permisos para `logout` o el borrado de role-mappings → `BLOCKED_BY_MISSING_EVIDENCE` y escalar al owner de Infra.
  - Cualquier SP con RBAC que falle con la coincidencia exacta → `CONTRACT_CONFLICT` (se corrige el llamador, no se vuelve al `LIKE`).

Lo que no está en ALLOWED_PATHS no se modifica. Ampliar el alcance exige actualizar este PLAN con aprobación.

---

## 4. Alcance y no alcance

### Alcance
1. Extender el puerto y el adapter de identidad (buscar, habilitar, deshabilitar con logout, actualizar datos, retirar rol).
2. `SincronizarCuentaInstitucionalService` (aplicación) con la política DB primero → IdP y el registro de desfases.
3. SP internos de estado y de datos de usuario.
4. RBAC exacto.
5. Política de aprovisionamiento y restricción de `POST /usuarios`.
6. Reconciliación administrativa (D3).
7. Seed Keycloak de los usuarios canónicos y corrección de la colisión de ids.
8. Documentación de TD-013/014/015.

### No alcance
1. Endpoints de editar o activar/desactivar por rol: son de los grupos F–J, que **consumen** este WI.
2. Cambio o recuperación de contraseña y correos de activación (DA-5).
3. Migrar los use cases de alta existentes al servicio nuevo (D7: lo hace cada grupo).
4. Sincronización masiva Keycloak → DB (HU170, fuera del programa).
5. Cambiar el proveedor de identidad.

---

## 5. Archivos afectados

### Existentes (ruta comprobada)
- Backend:
  - `application/secondaryports/identity/IdentityProviderPort.java`, `dto/CrearCuentaIdentidadDTO.java`, `dto/CuentaIdentidadDTO.java`
  - `application/security/InstitutionalRole.java` (lectura)
  - `infrastructure/adapter/secondary/identity/keycloak/KeycloakIdentityProviderAdapter.java`
  - `infrastructure/config/adapters/identity/keycloak/KeycloakIdentityAdapterConfiguration.java`
  - `application/features/usuario/provisionarusuario/usecase/impl/ProvisionarUsuarioUseCaseImpl.java` (lectura; el comportamiento cambia vía la seguridad)
  - `infrastructure/adapter/primary/controller/usuario/UsuarioController.java` (lectura)
  - `infrastructure/config/security/SecurityConfig.java` ⚠️
  - `infrastructure/adapter/primary/security/jwt/SecurityContextAuthenticatedUserResolver.java` (lectura, D5)
  - Tests: `KeycloakIdentityProviderAdapterTest`, `FakeKeycloakAdminServer`, `KeycloakIdentityAdapterConfigurationTest`, `IdentityProviderIsolationRulesTest`, `InstitutionalRolePurityTest`, `UsuarioControllerTest`, `RbacSecurityFilterChainTest` ⚠️
- DB:
  - `schema/tables/Usuario.sql`
  - `schema/views/uv_usuario.sql`, `uv_usuario_perfil.sql`
  - `schema/stored-procedures/usp_validar_permiso_rbac_usuario_interno.sql`, `usp_validar_unicidad_usuario_interno.sql` (reutilizado)
  - `schema/seed/09_perfil.sql`, `12_usuarios_roles.sql`, `04_mensaje.sql`
  - `migrations/02_datos_semilla_representativos.sql`
  - `test/test_authorized_views_rbac.sql`, `test_suite.sql` ⚠️
- Scripts e infra:
  - `scripts/database/seed_realtime_test_group.sql`
  - `GestioAsistenciaBackend/infra/keycloak/scripts/seed-e2e-users.ps1` (patrón), `infra/keycloak/realm-import/asistencias-uco-realm.json`
  - `AsistenciasUCO-Infra/components/keycloak/scripts/seed-users.ps1`
- Docs: `docs/security/keycloak-identity-provider.md`, `docs/baseline/TECHNICAL_DEBT.md` (TD-013 l.250, TD-014 l.260, TD-015 l.270)

### Nuevos
Los de §3 (ALLOWED_PATHS) más los tests de [TEST_PLAN.md](TEST_PLAN.md).

---

## 6. Contratos y consumidores afectados

| Tipo | Contrato | Compatibilidad | Consumidor |
|---|---|---|---|
| DOMAIN / PORT | `IdentityProviderPort` con 5 métodos nuevos | Aditivo. Los stubs de test que implementan el puerto (p. ej. en `RegistrarEstudianteUseCaseImplTest`) deben implementar los métodos nuevos, o el puerto los declara `default` y lanza `UnsupportedOperationException`. Recomendado: **sin `default`**, y se actualizan los stubs | F–J |
| PERSISTENCE | SP internos nuevos; RBAC exacto | El RBAC exacto es un cambio de comportamiento **sin cambio de firma**, protegido por la prueba de los 6 valores | 23 SP llamadores |
| HTTP | `POST /api/v1/usuarios` → solo `ADMINISTRADOR` (D4) | **Rompe** a un usuario autenticado no admin, pero no hay consumidores accesibles (verificado) | — |
| HTTP | `POST /api/v1/admin/usuarios/{idUsuario}/identidad/reconciliar` (D3) | Aditivo | Admin |
| INFRA | `seed-canonical-users.ps1`; ids de seeds de prueba | Aditivo. El cambio de id solo afecta a datos de prueba | E2E, desarrolladores |

---

## 7. Archivos calientes (coordinación con HU035/HU036)

`SecurityConfig.java` y `RbacSecurityFilterChainTest.java` (D4 y la ruta de reconciliación) y `test_suite.sql` (`:r` nuevos) → **después del merge**. El resto (puerto, adapter, SP internos, scripts) **no** es caliente y puede avanzar antes, en la rama `feature/IAM-001-ciclo-vida-identidad`.

---

## 8. Decisiones requeridas (bloquean READY)

| ID | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| **D1** | ¿Se guarda en DB el `idExterno` de Keycloak? | (a) No: se resuelve siempre por el atributo `idUsuario` (`buscarCuentaPorIdUsuario`). (b) Sí: columna `Usuario.idExternoIdentidad`. | **(a)**: mantiene la DB independiente del proveedor (constitución, sustituibilidad) y reutiliza la búsqueda exacta que el adapter ya valida. |
| **D2** | Una persona con dos roles (p. ej. coordinador que también es docente): ¿qué pasa al desactivar uno? | (a) Se desactiva el **rol en su ámbito**; la cuenta de Keycloak se deshabilita y `Usuario.estado` pasa a 0 **solo** si no le queda ningún rol activo, y se le retira el client role del rol desactivado. (b) Desactivar = deshabilitar a la persona siempre. | **(a)**: no se bloquea el acceso legítimo por otro rol. Requiere que cada grupo sepa si su rol tiene estado propio (Docente: `DocentePrograma.estado` con B; el resto: ver el grupo correspondiente). |
| **D3** | TD-015: ¿cómo se recupera un desfase DB↔IdP? | (a) Tabla `UsuarioSincronizacionIdentidad` (`id`, `usuario`, `operacion`, `estado PENDIENTE/RESUELTO`, `intentos`, `ultimoErrorTecnico`, `fechaUtc`) + endpoint admin `POST /admin/usuarios/{id}/identidad/reconciliar` que reintenta de forma idempotente. (b) Solo log y reintento manual del alta. (c) Outbox con un *job* programado en el backend. | **(a)** ahora: es trazable y no hace falta un scheduler. (c) queda como evolución. *(La prohibición de polling aplica al cliente; un job de backend sería válido, pero agrega infraestructura que no hace falta todavía.)* |
| **D4** | `POST /api/v1/usuarios` (cualquier autenticado → `ESTUDIANTE`). | (a) Restringirlo a `ADMINISTRADOR` ya, y retirarlo cuando el grupo C entregue el autorregistro QR. (b) Retirarlo ya. (c) Dejarlo. | **(a)**: cierra el hueco de inmediato sin adelantar el diseño del grupo C. |
| **D5** | Usuario desactivado con un access token vigente. | (a) Acortar `accessTokenLifespan` del realm (p. ej. 15 min) + logout de sesiones al deshabilitar. (b) Verificar `Usuario.estado` en cada request (filtro con caché corta). (c) Aceptar la ventana hasta que el token expire y documentarla. | **(a)**, que es la práctica estándar de OIDC y no consulta la DB por cada request. Que el owner de Infra confirme el valor. |
| **D6** | TD-014 (`emailVerified=true`). | (a) Mantenerlo y documentar que los correos los registra un actor institucional. (b) `false` + flujo de verificación. | **(a)** para este programa (DA-5: sin correos de activación). TD-014 queda abierta para producción. |
| **D7** | ¿Se migran los altas existentes (decano, coordinador, estudiante) al servicio nuevo? | (a) No en E: cada grupo lo adopta al tocar su rol (F/G decano, H coordinador, J estudiante). (b) Sí, ahora. | **(a)**: evita tocar flujos certificados fuera de su grupo. |

---

## 9. Riesgos y dependencias

| ID | Riesgo | Mitigación |
|---|---|---|
| R1 | El RBAC exacto rompe un llamador que dependía del `LIKE` con un valor distinto a los 6 conocidos | Grep del 2026-10-21: los valores son `ADMINISTRADOR`, `DECANO`, `COORDINADOR`, `DOCENTE`, `ESTUDIANTE` y `DOCENTE,COORDINADOR`; todos coinciden exactamente con `nombrePerfil` en mayúsculas. Hay una prueba que los recorre todos y se ejecuta `test_suite.sql` completo |
| R2 | El client `asistencias-backend-admin` no tiene permisos para `logout` o el borrado de role-mappings | Se verifica en la fase 03 con `validate-keycloak.ps1`; si faltan, se ajusta `bootstrap-keycloak.ps1` (Infra), con aprobación |
| R3 | Una búsqueda por atributo devuelve 0 o >1 cuentas | 0 → `Optional.empty()` (el llamador registra el desfase). >1 → `IdentityProviderException` "identidad ambigua", sin efecto. Las dos están probadas |
| R4 | Cambiar el id `E1F2…006` en los seeds de prueba rompe tests que lo usan | Grep del id en los 3 repos antes del cambio; se ajustan **solo** las referencias de datos de prueba (no aserciones de negocio) |
| R5 | Al agregar métodos al puerto, los stubs de test dejan de compilar | Es esperado; se actualizan en el mismo commit (cambio formal de contrato del puerto) |
| R6 | Actualizar el correo en Keycloak cuando ya existe otra cuenta con ese correo | El adapter traduce el 409 de Keycloak a `IdentityProviderException` y se registra el desfase. La DB ya habría validado la unicidad, así que solo puede ocurrir con cuentas fuera del sistema |

**Dependencias:** ninguna funcional (puede ir en paralelo a A y B). Para los pasos ⚠️, el merge de HU035/036.

---

## 10. Test plan

Ver [TEST_PLAN.md](TEST_PLAN.md).

---

## 11. Secuencia de ejecución (fases 02–06)

| Fase | Repo | Rama | Commits atómicos (`Refs: IAM-001`, `TD-013`/`TD-015`) |
|---|---|---|---|
| 02 | Backend (docs) | `docs/plan-registro-roles` | `docs(security): congelar contrato IAM-001 ciclo de vida de identidad` |
| 03/04 DB | GestioAsistenciaDB | `feature/IAM-001-ciclo-vida-identidad` | `test(db/sp): …`; `feat(db/sp): agregar procedimientos internos de estado y datos de usuario`; `fix(db/sp): exigir coincidencia exacta de perfil en validacion rbac`; (D3) `feat(db/tables): agregar registro de sincronizacion de identidad`; `fix(db/seed): eliminar colision de id en semillas de prueba` |
| 03/04 Back | GestioAsistenciaBackend | idem | `test(backend/adapter): …`; `feat(backend/ports): extender IdentityProviderPort con ciclo de vida`; `feat(backend/adapter): implementar habilitar deshabilitar y actualizar cuenta en keycloak`; `feat(backend/usecase): agregar servicio de sincronizacion de cuenta institucional`; (D3) `feat(backend/controller): agregar reconciliacion de identidad para administrador`; ⚠️ `fix(backend/security): restringir provisionamiento generico a administrador`; `ci(scripts): agregar seed de usuarios canonicos en keycloak` |
| 04 Infra | AsistenciasUCO-Infra | `fix/seed-users-idusuario` | `fix(scripts): usar idUsuario canonico en seed-users` |
| 05 | todos | — | `VALIDATION.md` (incluye la validación manual contra Keycloak real) |
| 06 | Backend (docs) | — | `identity-provisioning-policy.md`, `keycloak-identity-provider.md` (tabla de flujos actualizada y operaciones nuevas), `TECHNICAL_DEBT.md` (TD-013 → `PARCIAL`, cerrada por B + E + C; TD-015 → `MITIGADA` por la reconciliación; TD-014 documentada) |

No hay frontend en este WI: la reconciliación se opera por API. La pantalla, si se quiere, la hace el grupo G.

---

## 12. Rollback y stop conditions

- **Rollback:** revertir los PRs. El RBAC exacto, la restricción de `POST /usuarios` y el cambio de ids de seed van en commits aislados.
- **CONTRACT_CONFLICT:** un llamador RBAC con un valor no previsto; un consumidor real de `POST /usuarios`.
- **TEST_CONTRACT_CONFLICT:** tests que dependían del id `E1F2…006` como estudiante (R4).
- **BLOCKED_BY_MISSING_EVIDENCE:** faltan permisos del client admin (R2).

---

## 13. Deuda conocida y validación manual

- **Cierra o mitiga:**
  - TD-013, en parte: política documentada y `POST /usuarios` restringido. El docente lo cierra B y el retiro final, C.
  - TD-015: mitigada con el registro de desfases y la reconciliación.
  - RBAC con `LIKE`.
  - Colisión de seed.
  - Falta de seed Keycloak.
- **Deja abierta:** TD-014 (D6), y la ventana del access token según D5.
- **Validación manual (MV):**
  1. Correr `seed-canonical-users.ps1` y hacer login con los 5 roles.
  2. Deshabilitar `ana.gomez` desde un test de integración manual: el login falla y el *refresh* falla.
  3. Habilitarla: el login vuelve a funcionar.
  4. Simular Keycloak caído (detener el contenedor) durante un alta: queda la fila `PENDIENTE` y la reconciliación la resuelve al volver Keycloak.

---

## 14. Definition of Ready (DoR)

| Criterio DoR | Estado | Evidencia / pendiente |
|---|---|---|
| 1. Objetivo y alcance delimitados | ✅ | §1, §4 |
| 2. AS-IS con evidencia | ✅ | §2 (verificado el 2026-10-21) |
| 3. Contratos identificados | ✅ (borrador) | [CONTRACT.md](CONTRACT.md) `DRAFT` |
| 4. Matriz de pruebas | ✅ | [TEST_PLAN.md](TEST_PLAN.md) |
| 5. Sin conflictos WORM | ✅ | No toca el golden path |
| 6. Decisiones del owner | ❌ | D1–D7 |
| 7. Permisos del client admin de Keycloak verificados | ❌ | R2 (fase 03) |
| 8. Archivos calientes liberados | ❌ (solo para los pasos ⚠️) | HU035/036 |

**Dictamen DoR:** 👉 **`NOT_READY`**: pendiente de D1–D7. Los pasos no calientes pueden empezar en cuanto el owner apruebe las decisiones.
