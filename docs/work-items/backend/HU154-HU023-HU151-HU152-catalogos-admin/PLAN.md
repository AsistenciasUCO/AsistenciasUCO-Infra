---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-22
---

# PLAN — HU154 + HU023 + HU151 + HU152: Catálogos administrativos (tipos de programa y áreas)

Fase 01 (Planificación y DoR) conforme a `GUIA_METODICA_IMPLEMENTACION_HU.md` y `AGENTS.md`.
**Dictamen DoR: `READY`** (D1–D8 aprobadas por el owner el 2026-10-22).

## 1. Identidad y objetivo

- **HUs:** HU154 (administrar catálogo de tipos de programa), HU023 (consumo transversal de tipos de programa), HU151 (crear área de conocimiento), HU152 (modificar datos y estado de un área).
- **Work item:** `HU154-HU023-HU151-HU152-catalogos-admin`. Rama por repo: `feature/HU154-HU151-catalogos-admin`. Worktrees: `C:\Proyectos\GestioAsistencia\.worktrees\<repo>-catalogos`.
- **Actor:** Administrador Institucional (escritura); cualquier usuario autenticado (lectura HU023).
- **Objetivo:** completar los catálogos que alimentan a otras pistas: la pista A (programas) necesita tipos de programa activos para el alta de programa; las asignaturas referencian un área.
- **Orden de entrega:** Tajada 1 = tipos de programa (DB → Backend → Frontend), porque la pista A depende de ella. Tajada 2 = áreas.

## 2. AS-IS verificado en código (2026-10-22, base `develop` 4ff37ff)

| Capa | Hallazgo |
| :--- | :--- |
| **DB – tipos** | `dbo.TipoPrograma(id, nombre nvarchar(50), estado bit, codigo nvarchar(3))`. Vista `uv_tipo_programa` expone `id, nombre, estaActivoTipoPrograma, estaActivoTextoTipoPrograma` (**sin `codigo`**). Seed `05_tipo_programa.sql`: `PRE` pregrado, `POS` postgrado (nombres en minúscula). Ningún SP de escritura. `usp_crear_programa_academico` recibe `@idTipoPrograma` y **no valida que exista ni que esté activo**. |
| **DB – áreas** | `dbo.Area(id, nombre nvarchar(50), codigo nvarchar(3))`: **no tiene `estado`** ni relación con facultad. Vista `uv_area` expone solo `id, nombre`. Seed: una área (`ISW`). Ningún SP de escritura. `usp_crear_asignatura` resuelve el área por `LIKE` sobre el nombre y, si no la halla, **toma `TOP 1` de `uv_area`** (asigna un área arbitraria en silencio). Sin índices únicos sobre `codigo` ni `nombre`. |
| **Backend** | No hay una sola referencia a `uv_tipo_programa` ni a tipo de programa en `src/main` (ni lectura). `AdminPortalController`: `GET /admin/areas` funciona (`ConsultarAreasUseCase` → `AreaJpaRepository` → `UvAreaEntity`, devuelve `AreaDTO(id, nombre)`); `POST /admin/areas`, `PUT /admin/areas/{id}` y `PATCH /admin/areas/{id}/estado` lanzan `unavailable(...)` (501). Referencia de lectura pública: `TipoIdentificacionController` en `/api/v1/tipos-identificacion`. `SecurityConfig` ya protege `/api/v1/admin/**` con `ADMINISTRADOR` y deja `/api/v1/**` en `authenticated()`: **no hay que tocar `SecurityConfig`**. `DbFailureClassifier`: `GEN_003` → `CONFLICT`, `GEN_002` → `VALIDATION_ERROR`, `SEC_001` → `FORBIDDEN`; `GEN_001` **no** está clasificado (cae a no clasificado), por eso HU117 añadió `FAC_001`/`DEC_001`. |
| **Frontend** | `admin-catalogs` es un stub que redirige a `/app/admin/facultades`. `admin-areas` existe (368 líneas) pero modela `AreaConocimientoItem{codigo, facultadId, facultadNombre, coordinadorArea, estado, totalAsignaturas}`: **tres de esos campos no existen en DB** (el área no pertenece a una facultad, no tiene coordinador y nadie calcula `totalAsignaturas`). Además `AdminManagementService.crearArea/actualizarArea/cambiarEstadoArea` hacen `subscribe()` sin manejo de error y devuelven `void`; `cambiarEstadoArea` hace `PATCH` con `{}` (toggle ciego). No existe UI de tipos de programa. |
| **Catálogo** | HU150 `[CERTIFICADA]`; HU151/HU152 `[BLOQUEADO 501]`; HU023 y HU154 `[PARCIAL]`. HU150 dice "tabla de áreas en `DeanFacultyComponent`": el catálogo está desactualizado (la pantalla real es `admin-areas`). |

## 3. TARGET

1. **DB (por entidad: tipo de programa y área):** tres SP públicos con fachada + `*_interno` atómico, `SET XACT_ABORT ON`, tupla estándar y RBAC `ADMINISTRADOR` dentro del SP: `usp_crear_*`, `usp_actualizar_*`, `usp_cambiar_estado_*` (12 archivos). Las vistas `uv_tipo_programa` y `uv_area` se amplían con `codigo` (y `estado` en área). DDL de `Area.estado` por migración (D2).
2. **Backend:** casos de uso POJO en `AdminWiringConfiguration`, puertos `TipoProgramaCommandPort`/`TipoProgramaQueryPort` y `AreaCommandPort`; controladores mínimos en `AdminPortalController` (stubs de áreas pasan a reales) y un `TipoProgramaController` nuevo para la lectura pública (D1).
3. **Frontend:** `admin-catalogs` deja de redirigir y pasa a gestionar tipos de programa; `admin-areas` se alinea al modelo real (`codigo`, `nombre`, `activa`), sin campos inventados; servicios devuelven `Observable` y la UI no actualiza de forma optimista ni oculta errores.

## 4. Alcance y no alcance

**En alcance:** HU154, HU023, HU151, HU152 (incluye el `PATCH /estado` de áreas, que HU152 pide como "switch de activación"), tests en las 3 capas, corrección de `AdminManagementService` para áreas, documentación.

**Fuera de alcance:**
- HU153 (tipos de documento) y HU155 (estados del sistema): otras HU del mismo grupo "Administración de Catálogo".
- Relación área–facultad, coordinador de área y conteo de asignaturas (no existen en el modelo; ver D3).
- Validación de tipo de programa activo en `usp_crear_programa_academico`: es archivo de la pista A (ver D6, se le avisa).
- Corregir el `TOP 1` de `usp_crear_asignatura` (deuda técnica, ver D7).
- Eliminación física de registros de catálogo (no hay `DELETE`; se inactiva).

## 5. Perímetro de rutas

- **Permitidas:** DB `schema/stored-procedures/usp_{crear,actualizar,cambiar_estado}_{tipo_programa,area}*.sql`, `schema/views/uv_tipo_programa.sql`, `schema/views/uv_area.sql`, `schema/tables/Area.sql` y `migrations/05_*` (D2), `test/test_usp_*_{tipo_programa,area}.sql`; backend `application/features/admin/{creartipoprograma,actualizartipoprograma,cambiarestadotipoprograma,consultartiposprograma,creararea,actualizararea,cambiarestadoarea}/**`, `application/features/admin/consultarareas/**` (se amplía el DTO), puertos secundarios de academic, adaptadores JPA de tipo programa y área, `TipoProgramaController`, sus tests; frontend `features/admin/admin-catalogs/**`, `features/admin/admin-areas/**`, `core/services/admin-management.service*.ts` (solo métodos de áreas y tipos), `core/models/role-management.model.ts` (solo `AreaConocimientoItem` y nuevo `TipoProgramaItem`).
- **Compartidos, cambios mínimos y localizados:** `AdminPortalController` y `AdminWiringConfiguration` (solo los métodos/beans de áreas; los tipos van en controlador y bloque de wiring propios para no colisionar con las pistas A y B).
- **Archivos calientes, solo al final y en commit aparte:** `schema/seed/04_mensaje.sql`, `DbFailureClassifier`, `test_suite.sql`, `HTTP_AS_IS_MATRIX.md`, `HU-CATALOG.md`, OpenAPI golden path si aplica. **No se toca `SecurityConfig`.**
- **Prohibidas:** `admin-facultades`, `usp_crear_programa_academico` y todo lo de programas/docentes (pistas A y B), contratos WORM sin proceso formal.

## 6. Riesgos y rollback

- **DDL sobre `Area`:** agregar `estado` y los índices únicos exige migración idempotente y que el seed siga cargando. Rollback: `DROP INDEX`/`DROP COLUMN` en migración inversa documentada; los SP son nuevos (`DROP PROCEDURE`).
- **Cambio de forma de `GET /admin/areas`:** pasa de `{id, nombre}` a `{id, codigo, nombre, activa}`; es aditivo y el único consumidor es `admin-areas`.
- **Colisión de archivos calientes** con A y B (`04_mensaje.sql`, `AdminPortalController`): se mitiga con merge frecuente y commit aparte al final; los códigos nuevos (`TPR_001`, `ARE_001`) son pocos y de prefijo propio.
- **Dependencia cruzada:** la pista A necesita `GET /api/v1/tipos-programa` y el estado `activo`. La Tajada 1 se entrega primero y se avisa a la sesión de la pista A.
- **Rollback de backend/frontend:** `git revert` de los commits del work item.

## 7. Decisiones abiertas para el owner

| # | Decisión | Recomendación |
| :-: | :--- | :--- |
| **D1** | ¿HU154/HU023 requieren endpoints de escritura nuevos o solo completar lectura y UI? | **Sí, nuevos.** Hoy no existe *ningún* endpoint de tipos de programa. HU023 = `GET /api/v1/tipos-programa` (lectura pública, solo activos, para selectores y badges; mismo patrón que tipos de identificación). HU154 = `/api/v1/admin/tipos-programa` con listado completo (incluye inactivos), `POST`, `PUT` y `PATCH /estado`. Si el owner prefiere un HU154 solo-lectura, se omiten `POST/PUT/PATCH` y SP de escritura. |
| **D2** | HU152 pide "estado" pero `Area` no tiene columna. ¿Se agrega `Area.estado`? | **Sí:** migración `ALTER TABLE Area ADD estado bit NOT NULL DEFAULT 1` (filas existentes quedan activas), actualizar `schema/tables/Area.sql` y `uv_area`. Alternativa sin DDL: dejar HU152 solo con renombrar y quitar el switch de la UI. |
| **D3** | La UI de áreas muestra `facultadId`, `coordinadorArea` y `totalAsignaturas`, que no existen en DB. | **Eliminarlos de la UI y del modelo TS** (el área es un catálogo institucional plano: `codigo`, `nombre`, `activa`). `totalAsignaturas` queda como mejora aparte (conteo en vista) y la relación área–facultad como HU nueva si negocio la necesita. No se inventan datos en el cliente. |
| **D4** | Unicidad. | **`codigo`**: único, 3 caracteres, `UPPER(TRIM)`, solo `A–Z` y `0–9`, **inmutable** tras crear (el seed y `13_academico_asignaturas.sql` lo usan como llave, p. ej. `PRE`). **`nombre`**: 3–50 caracteres, único sin distinguir mayúsculas dentro de su catálogo. Reforzar con índices únicos en la migración. Conflicto → `GEN_003`. |
| **D5** | Semántica de estado. | **Idempotente con estado deseado** (igual que HU111): `PATCH .../estado` recibe `{ "activo": bool }` (tipo de programa) o `{ "activa": bool }` (área). Sin cascada: inactivar no toca programas ni asignaturas existentes; solo impide *nuevas* asociaciones. Sin `DELETE`. |
| **D6** | Efecto de inactivar un tipo de programa en la creación de programas. | `usp_crear_programa_academico` debería rechazar tipos inexistentes o inactivos. Es archivo de la **pista A**: se le comunica el contrato (`uv_tipo_programa.estaActivoTipoPrograma`) y el código `TPR_001`; no se edita aquí. |
| **D7** | `usp_crear_asignatura` asigna `TOP 1` área si no resuelve el nombre; ignorará `estado`. | **Fuera de alcance, registrar como deuda técnica** (nuevo TD) y proponer luego un cambio que exija `idArea` activo. Aquí solo se documenta. |
| **D8** | Códigos de error y origen de los mensajes. | **Mensajes de usuario desde el catálogo de la DB (SSOT), no desde el catálogo genérico del backend.** El SP devuelve `mensajeUsuarioResultado`; `DbExceptionTranslator` lo envía dentro de `ConflictException`/`ResourceNotFoundException`, por lo que `CONFLICT`/`RESOURCE_NOT_FOUND` solo aportan la clase HTTP. Reutilizar `GEN_002` (400), `GEN_003` (409), `SEC_001` (403), `CORR_001`, `GEN_004`/`GEN_005` (éxito). **Nuevos:** `TPR_001` "El tipo de programa especificado no existe en el sistema." y `ARE_001` "El área de conocimiento especificada no existe en el sistema." (404), registrados en `04_mensaje.sql` (usuario y técnico) y en `DbFailureClassifier`. Razón: `GEN_001` no se puede clasificar a 404 sin saber la entidad (precedente HU117). |

## 8. Definition of Ready

| Criterio | Estado |
| :--- | :---: |
| Objetivo y alcance delimitados | ✅ |
| AS-IS verificado en las 3 capas | ✅ |
| Contratos identificados (`CONTRACT.md` en borrador) | ✅ |
| Matriz de pruebas inicial (`TEST_PLAN.md`) | ✅ |
| Decisiones D1–D8 resueltas por el owner | ⏳ |
| Worktree de backend creado | ✅ (`.worktrees/backend-catalogos`) |
| Worktrees de DB, Frontend e Infra | ⏳ (se crean al aprobar) |

**Dictamen: `NOT_READY`.** Pasa a `READY` al aprobar D1–D8 y el CONTRACT.
