---
status: draft
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-21
---

# PLAN — REG-000: Programa de registro y vinculación de todos los roles

Work item **índice** (`DOCUMENTATION_ONLY`). Descompone en grupos de HUs afines todo lo que falta para que la cadena jerárquica de alta, vínculo y ciclo de vida de usuarios (Administrador → Decano → Coordinador → Docente → Estudiante) quede completa en DB, Backend y Frontend. Detalla y aterriza la secuencia general de `HOJA_DE_RUTA_JERARQUIA_ROLES.md`.

Cada grupo es un work item propio (`PLAN.md` + `CONTRACT.md` + `TEST_PLAN.md`) que sigue `GUIA_METODICA_IMPLEMENTACION_HU.md` (fases 01→06), `constitution.md`, `AGENTS.md`, `docs/governance/DEFINITION_OF_READY.md` y `docs/baseline/DEFINITION_OF_DONE.md`.

---

## 1. Identidad y objetivo

- **Work Item ID:** `REG-000-programa-registro-vinculacion-roles`
- **Fecha:** 2026-10-21
- **Base Git:** `develop` @ `4ff37ff` (merge PR #34, HU120), en la rama de documentación `docs/plan-registro-roles`.
- **Fuentes autoritativas:** `AsistenciasUCO-Infra/docs/user-stories/HU-CATALOG.md` (v4.0.0, SSOT de estados), `HOJA_DE_RUTA_JERARQUIA_ROLES.md`, `GUIA_METODICA_IMPLEMENTACION_HU.md`, `docs/security/keycloak-identity-provider.md`, `docs/baseline/TECHNICAL_DEBT.md`.
- **Objetivo:** que cada rol pueda **darse de alta, vincularse a su entidad institucional y administrarse (editar / activar / desactivar)** por el actor jerárquico que le corresponde, con su identidad en Keycloak sincronizada.
- **Criterio de éxito del programa:** todos los work items A–J cerrados en estado `CERTIFICADA`, sin endpoints 501 en la cadena de alta/vínculo/ciclo de vida, y con la suite E2E `test_all_hus.ps1` cubriendo un alta por rol.

### Decisiones de alcance ya tomadas por el owner (2026-10-21)

| # | Decisión |
|---|---|
| DA-1 | Alcance = **alta + vínculo + ciclo de vida** (editar y alternar estado). Lo masivo (HU156, HU170, HU171) queda fuera. |
| DA-2 | Las capacidades sin HU se **proponen como HUs nuevas** (§5). Se adoptan en `HU-CATALOG.md` solo cuando el owner las apruebe. |
| DA-3 | Cada work item lleva **PLAN + CONTRACT (borrador) + TEST_PLAN**. Todo nace en `draft` con DoR `NOT_READY` hasta la aprobación. |
| DA-4 | Se planifica **grupo por grupo**: después de cada grupo se revisa antes de seguir. |
| DA-5 | **La contraseña se sigue asignando en la creación** (`passwordInicial` → Keycloak `reset-password temporary=false`, hash → DB). En este programa no se crean flujos de cambio o recuperación de clave ni de correo de activación. |

---

## 2. AS-IS consolidado (evidencia al 2026-10-21)

### 2.1 Qué funciona de punta a punta (DB + Backend + Keycloak + UI)

| Rol / vínculo | HU | Endpoint | SP | Keycloak |
|---|---|---|---|---|
| Decano + vínculo a Facultad | HU117-B, HU137 | `POST/GET /api/v1/admin/decanos` | `usp_crear_decano` | `DECANO` (`CrearDecanoUseCaseImpl`) |
| Facultad (exige decano) | HU116, HU107 | `POST/GET /api/v1/admin/facultades` | `usp_crear_facultad` | n/a |
| Coordinador (programa opcional) | HU120, HU123, HU124 | `POST/GET /api/v1/decano/coordinadores` | `usp_crear_coordinador` | `COORDINADOR` (`CrearCoordinadorUseCaseImpl`) |
| Grupo con docente titular | HU076B | `POST /api/v1/grupos`, `PUT /api/v1/grupos/{id}` (`idDocente`) | `usp_crear_grupo` / `usp_actualizar_grupo` | n/a |
| Estudiante + matrícula manual por docente | HU050 | `POST /api/v1/grupos/{grupoId}/estudiantes` | `usp_registrar_estudiante_en_grupo` | `ESTUDIANTE` (`RegistrarEstudianteUseCaseImpl`) |

### 2.2 Qué falta o está en 501

| Capacidad | DB | Backend | Front |
|---|---|---|---|
| Alta de Administrador | No existe (solo seed `schema/seed/12_usuarios_roles.sql`) | No existe | No existe |
| Editar / alternar Decano | Sin SP. Los roles no tienen columna `estado` (solo `Usuario.estado`) | `PATCH /admin/decanos/{id}/toggle` → 501 (`AdminPortalController`) | `admin-decanos` llama al toggle |
| Editar facultad, sede, decano; estado de facultad | Sin SP | `PUT /admin/facultades/{id}`, `PATCH …/estado` → 501 | `admin-management.service.ts` hace `catchError(() => of(true))` y oculta el error |
| Programa académico (alta / edición / estado) | `usp_crear_programa_academico` existe pero no cumple la norma (ver WI-A) | No hay endpoint ni puertos `Programa*` | `CatalogService.getProgramasAcademicos()` devuelve programas **quemados** (`PROG-01`…) |
| Editar / alternar Coordinador | Sin SP | `PATCH /decano/coordinadores/{id}/estado` → 501 | El front llama a `…/{id}/toggle`; **la ruta no coincide** con la del backend |
| Directorio / alta de Docente con Keycloak | `usp_registrar_docente_en_grupo[_autonomo]` sin transacción | `GET/POST /coordinador/docentes` → 501. `POST /docentes` y `POST /docentes/asignaciones/grupo` → 501 en el adapter (`DocenteJpaRepository`). Sin aprovisionamiento IAM (TD-013) | `coordinator-docentes` ya llama a endpoints reales (que responden 501) |
| Editar / alternar Docente | Sin SP | `PATCH /coordinador/docentes/{id}/estado` → 501 | — |
| Matrícula QR autónoma con creación de cuenta | `usp_registrar_estudiante_en_grupo_autonomo` (estado `'I'`, **sin RBAC ni transacción**) | `POST /estudiante/matricular-grupo` → 501. No hay token de matrícula | `teacher-matricula-modal` genera el QR en el cliente (PIN = id del grupo, imagen desde `api.qrserver.com`, sin TTL). El flujo solo sirve a estudiantes ya logueados |
| Solicitudes de matrícula | No hay tabla. `usp_resolver_solicitud_matricula` es stub | `/estudiante/solicitudes-matricula`, `/coordinador/solicitudes-matricula/**` → 501 | Pantallas que llaman a endpoints 501 |
| Retiro de estudiante del grupo | Sin SP | `DELETE /grupos/{id}/estudiantes/{id}` y la variante de coordinador → 501 | — |
| Editar / cambiar estado del estudiante | Sin SP | No existe | — |
| Ciclo de vida de la cuenta en Keycloak | n/a | `IdentityProviderPort` solo tiene `crearCuenta`, `eliminarCuenta` y `asignarRol`. No permite **habilitar, deshabilitar ni actualizar** | n/a |
| `POST /api/v1/usuarios` | `usp_sincronizar_usuario` | Lo puede usar cualquier usuario autenticado y siempre aprovisiona `ESTUDIANTE` (TD-013) | `register.component` no tiene ruta (`register` → `login`) |

---

## 3. Grupos de work items y orden de ejecución

| # | Work item (carpeta en `docs/work-items/`) | HUs | Actor | Qué resuelve | Depende de | Estado del plan |
|---|---|---|---|---|---|---|
| A | `HU076-HU077-HU078-programa-academico-decano` | HU076, HU077, HU078, HU108 (solo listado), HU023/HU154 (solo lectura del selector) | Decano | Alta, edición (modalidad/jornada) y estado del programa. Vínculo programa↔coordinador. Listado real que reemplaza el mock del front | HU120 ✔ | **Redactado (draft)** |
| B | `HU062-HU089-HU063-HU090-HU091-vinculacion-docente` | HU062, HU089, HU063, HU090, HU091 | Coordinador | Directorio y búsqueda de docentes del programa. Alta de docente con cuenta Keycloak `DOCENTE`. Tipo de vinculación. Sacar de 501 `POST /coordinador/docentes`, `POST /docentes` y `/docentes/asignaciones/grupo` | A | **Redactado (draft)**: requiere DDL `DocentePrograma` + `TipoVinculacion` (D1/D2) |
| C | `HU176B-matricula-qr-autonoma` | HU176B (HU175 sale del programa: es el QR de **asistencia**, ver D1 del WI) | Docente → Estudiante | Ventana de matrícula abierta por el docente, con token hasheado, PIN y QR generado en el backend. Autorregistro público que crea la cuenta y matricula. Validación de red del campus por CIDR. Rate limit. Evento SSE `ESTUDIANTE_MATRICULADO` sin PII. Elimina `api.qrserver.com` | HU050 ✔ (IAM-001 recomendado) | **Redactado (draft)**: primeros endpoints públicos de negocio; requiere aprobación de seguridad |
| D | `HU026-HU053-HU054-HU055-solicitudes-matricula` | HU026, HU053, HU054, HU055 | Estudiante → Docente / Coordinador | Modelo de solicitud de matrícula (tabla + SPs). Concepto del docente. Control de cupo | C | Pendiente |
| E | `IAM-001-ciclo-vida-cuenta-identidad` | Habilitador (TD-013, TD-015) | Transversal | `IdentityProviderPort.habilitar/deshabilitar/actualizarCuenta`. SP interno `usp_internal_cambiar_estado_usuario`. Seed Keycloak de los usuarios canónicos y corrección de la colisión del id `E1F2…006`. Política "quién aprovisiona qué rol" y restricción de `POST /usuarios` | — | **Redactado (draft)**: incluye RBAC exacto (sin `LIKE`) y reconciliación de desfases (TD-015) |
| F | `HU117-HU110-HU111-gestion-facultad-admin` | HU117, HU110, HU111 | Administrador | Editar facultad, reasignar sede y decano, alternar estado. Quitar el `catchError(() => of(true))` | E | Pendiente |
| G | `HUP-ADM01-HUP-DEC01-HUP-DEC02-cuentas-admin-decano` | HUP-ADM01, HUP-DEC01, HUP-DEC02 (propuestas) | Administrador | Alta formal de Administrador. Editar y alternar Decano (sale de 501 `PATCH /admin/decanos/{id}/toggle`) | E | Pendiente |
| H | `HU121-HU122-gestion-coordinador` | HU121, HU122 | Decano | Editar y alternar coordinador, sincronizado con Keycloak. Alinear la ruta `toggle`↔`estado`. Estado propio del rol y facultad del coordinador sin programa (cierra una fuga de visibilidad entre facultades) | E (y A para reasignar el programa) | **Contrato congelado (2026-10-22)**: requiere DDL `Coordinador.estado` + `Coordinador.facultad` (D1/D2) y quitar la contraseña por defecto (D5) |
| I | `HU092-HU093-gestion-docente` | HU092, HU093 | Coordinador | Editar y alternar docente, sincronizado con Keycloak | B, E | Pendiente |
| J | `HU159-HU160-HU051-HUP-EST01-gestion-estudiante` | HU159, HU160, HU051, HUP-EST01 (propuesta) | Docente / Coordinador | Editar estudiante, cambiar estado institucional, baja/deserción, retiro de grupo | E | Pendiente |

### 3.1 Grafo de dependencias

```text
HU120 ✔ ──► A (programa) ──► B (docente) ──► I (gestión docente)
                 │                 ▲
                 └────────► H (gestión coordinador)
                                   ▲
E (IAM ciclo de vida) ─────────────┼──► F (facultad) ──► G (admin/decano)
                                   └──► J (gestión estudiante)
HU050 ✔ ──► C (HU176B, QR autónomo) ──► D (solicitudes)
```

Orden recomendado: **A → B → E → C → H → I → F → G → J → D**. E puede ir en paralelo con A/B porque no comparte archivos con ellos. D va al final porque depende del modelo de token de C y es la HU con más decisiones abiertas.

### 3.2 Fuera de alcance de este programa

HU156, HU170, HU171 (admisión y cargas masivas); HU175/HU176 (QR dinámico y red del campus en la **asistencia**, que pueden reutilizar el mecanismo de C); HU006 (perfil propio); HU096–HU098 (períodos: falta decidir si son de Admin o Coordinador); HU118 (bloqueo temporal de facultad); HU125–HU128 (movilidad y contratos docentes); HU112–HU114 y HU119 (consultas analíticas y árbol de programas); flujos de cambio o recuperación de contraseña (DA-5).

---

## 4. Matriz de aprovisionamiento por rol (TARGET, cierra TD-013)

| Rol creado | Lo crea | Endpoint TARGET | SP TARGET | Rol Keycloak | Vínculo institucional | Work item |
|---|---|---|---|---|---|---|
| ADMINISTRADOR | Administrador de la misma institución (o bootstrap, decisión de G) | `POST /api/v1/admin/administradores` | `usp_crear_administrador` | `ADMINISTRADOR` | `Administrador.institucion` | G |
| DECANO | Administrador | `POST /api/v1/admin/decanos` ✔ | `usp_crear_decano` ✔ | `DECANO` ✔ | `Facultad.decano` | HU117-B ✔ / F, G |
| COORDINADOR | Decano | `POST /api/v1/decano/coordinadores` ✔ | `usp_crear_coordinador` ✔ | `COORDINADOR` ✔ | `Programa.coordinador` | HU120 ✔ / A, H |
| DOCENTE | Coordinador | `POST /api/v1/coordinador/docentes` | `usp_crear_docente` (nuevo, transaccional) | `DOCENTE` | Grupo (`Grupo.docente`) y programa (decisión de B) | B, I |
| ESTUDIANTE (manual) | Docente titular / Coordinador | `POST /api/v1/grupos/{id}/estudiantes` ✔ | `usp_registrar_estudiante_en_grupo` ✔ (llevar a norma) | `ESTUDIANTE` ✔ | `EstudianteGrupo` + `EstudiantePrograma` | HU050 ✔ / J |
| ESTUDIANTE (QR) | El propio estudiante con un token emitido por el docente | `POST /api/v1/public/matricula-qr` (nombre a definir en C) | `usp_registrar_estudiante_en_grupo_autonomo` (llevar a norma) | `ESTUDIANTE` | `EstudianteGrupo` | C |
| — | `POST /api/v1/usuarios` (genérico) | Se restringe o se retira cuando C esté listo | — | — | — | E |

Reglas transversales que todo work item debe cumplir (de `GUIA_METODICA_IMPLEMENTACION_HU.md` §118 y de la constitución):

1. Orden **DB primero → Keycloak**. El hash va a la DB y la contraseña en claro solo a Keycloak. La falla de Keycloak después del commit se registra como TD-015 hasta que E defina la compensación.
2. Desactivar un usuario = `Usuario.estado = 0` **y** `enabled=false` en Keycloak (lo implementa E). Ningún grupo hace `DELETE` físico de usuarios.
3. El ámbito jerárquico se valida **dentro del SP** (`usp_validar_permiso_rbac_usuario_interno` + `usp_validar_titularidad_jerarquica_interno`) **y** en el use case (`InstitutionalScopePort`).
4. Mensajes desde el catálogo (`MessageCatalogPort`, `messages:user:<CODIGO>`). El front muestra `mensajeUsuario` / `message` tal cual llega.

---

## 5. HUs propuestas (pendientes de adopción en `HU-CATALOG.md`)

Formato de fila del catálogo: `| ID | Título | DB | Backend | Frontend | Estado |`.

| ID propuesto | Título | DB | Backend | Frontend | Estado propuesto |
|---|---|---|---|---|---|
| **HUP-ADM01** | Registrar Administrador Institucional y sincronizar cuenta IAM | SP `usp_crear_administrador` (RBAC `ADMINISTRADOR` de la misma institución) | `POST /api/v1/admin/administradores` + Keycloak `ADMINISTRADOR` | `/app/admin/administradores` | `[PENDIENTE]` |
| **HUP-DEC01** | Actualizar datos del Decano | SP `usp_actualizar_decano` | `PUT /api/v1/admin/decanos/{id}` + `IdentityProviderPort.actualizarCuenta` | Edición en `admin-decanos` | `[PENDIENTE]` |
| **HUP-DEC02** | Alternar estado del Decano | SP `usp_cambiar_estado_decano` (delegando en `usp_internal_cambiar_estado_usuario`) | `PATCH /api/v1/admin/decanos/{id}/estado` (hoy `…/toggle` → 501) + deshabilitar en Keycloak | Toggle en `admin-decanos` | `[PENDIENTE]` |
| **HUP-EST01** | Retirar estudiante de un grupo | SP `usp_retirar_estudiante_de_grupo` (estado del catálogo `EstadoEstudianteGrupo`, sin `DELETE` físico) | `DELETE /api/v1/grupos/{grupoId}/estudiantes/{estudianteId}` (hoy 501) | Acción en el roster del docente | `[PENDIENTE]` |

> El ID definitivo lo asigna el owner al adoptarlas en el catálogo. Hasta entonces los work items F/G/J usan el prefijo `HUP-`.

---

## 6. Deuda transversal que cada grupo debe dejar en norma (regla del boy-scout dentro de su perímetro)

| Deuda | Evidencia | Grupo responsable |
|---|---|---|
| SPs sin `SET XACT_ABORT ON` ni transacción explícita | `usp_crear_programa_academico`, `usp_registrar_docente_en_grupo[_autonomo]`, `usp_registrar_estudiante_en_grupo[_autonomo]`, `usp_crear_facultad` (solo el `_interno` tiene XACT_ABORT) | A, B, C/J, F (cada uno el suyo) |
| `ufn_obtener_parametro_guid(@x, 'GENERAL', 'GUID_DEFECTO_CORRELACION')` reemplaza `NULL` por un GUID por defecto (va contra la regla "evaluar `@parametro IS NULL`") | `usp_crear_programa_academico` y otros | A (y quien toque cada SP) |
| `usp_crear_decano`: resuelve la facultad por nombre con `LIKE`, el tipo de documento siempre es `CC` y no valida que la facultad exista | `schema/stored-procedures/usp_crear_decano.sql` | F / G |
| RBAC por `nombrePerfil LIKE %valor%` | `usp_validar_permiso_rbac_usuario_interno` | E |
| Contraseña por defecto de coordinador `UcoCoord_<doc>!` cuando viene vacía | `CrearCoordinadorUseCaseImpl` | H (ver DA-5: la contraseña debe venir siempre en la creación) |
| TD-013 (aprovisionamiento incompleto y sin política), TD-014 (`emailVerified=true`), TD-015 (sin reconciliación DB↔Keycloak) | `docs/baseline/TECHNICAL_DEBT.md` | E (TD-013 docente → B) |
| Programas quemados en el front | `CatalogService.getProgramasAcademicos()` | A |
| Ruta del toggle de coordinador: front `…/toggle`, back `…/estado` | `dean-management.service.ts:79` vs `DecanoPortalController` | H |
| QR de matrícula generado en el cliente, con imagen de un tercero | `teacher-matricula-modal.component.ts` | C |
| Colisión de seed `E1F2…006` (admin.sistema vs estudiante de prueba) y falta de seed Keycloak de usuarios canónicos | `schema/seed/12_usuarios_roles.sql`, `scripts/database/seed_realtime_test_group.sql`, `migrations/02_datos_semilla_representativos.sql` | E |

---

## 7. Archivos calientes (coordinación con HU035/HU036 en curso)

El 2026-10-21 hay otro agente trabajando HU035/HU036 en la rama `feature/HU035-HU036-bandeja-detalle-reclamos-docente` (Backend y DB) con cambios sin commit. Estos archivos, que varios grupos tocarán, **no se modifican hasta que HU035/036 esté en `develop`**. Después, cada grupo rebasa su rama sobre `develop`:

| Archivo | Lo tocarán |
|---|---|
| `GestioAsistenciaBackend/src/main/java/.../infrastructure/config/security/SecurityConfig.java` | B, C, D, F, G, H, I, J (A no lo necesita: el comodín `/api/v1/decano/**` de la línea 134 ya cubre sus rutas) |
| `GestioAsistenciaBackend/src/test/java/.../adapter/primary/security/RbacSecurityFilterChainTest.java` | Todos |
| `GestioAsistenciaBackend/src/main/java/.../controller/docente/DocentePortalController.java` | B, I |
| `GestioAsistenciaBackend/src/main/java/.../config/wiring/DocenteWiringConfiguration.java` | B, I |
| `GestioAsistenciaBackend/docs/contracts/HTTP_AS_IS_MATRIX.md` | Todos |
| `GestioAsistenciaBackend/src/test/java/.../openapi/OpenApiGoldenPathConformanceTest.java` | Solo si algún grupo entra al golden path (no previsto) |
| `GestioAsistenciaDB/test_suite.sql`, `GestioAsistenciaDB/test/test_contract_closure.sql` | Todos los grupos con SPs |
| `GestioAsistenciaFrontend/src/app/features/dean/dean-faculty/dean-faculty.component.ts`, `dean-infraestructura.component.ts` | A (por eso WI-A ubica la UI en `dean-programas`) |
| `AsistenciasUCO-Infra/docs/user-stories/HU-CATALOG.md`, `AsistenciasUCO-Infra/docs/work-items/README.md` | Cierre de cada grupo y adopción de las HUs propuestas |

---

## 8. Inconsistencias documentales detectadas (no se corrigen aquí)

1. `docs/historias-de-usuario.md` (raíz, v3.1.0) marca HU156, HU170 y HU171 como certificadas; el SSOT v4.0.0 las tiene en `PENDIENTE`.
2. La tabla de flujos de `docs/security/keycloak-identity-provider.md` dice que el coordinador no se aprovisiona; desde HU120 sí se aprovisiona.
3. `docs/autenticacion-usuarios-y-roles.md` habla de *realm roles*; el adapter asigna *client roles* de `asistencias-api`.
4. `HOJA_DE_RUTA_JERARQUIA_ROLES.md` pone HU076 antes que HU120; HU120 se certificó primero porque el coordinador puede crearse sin programa.
5. La fila HU076 del catálogo ubica la UI en `DeanFacultyComponent`; WI-A propone `DeanProgramasComponent` (decisión D5 de WI-A).
6. `AsistenciasUCO-Infra/components/keycloak/scripts/seed-users.ps1` usa por defecto el `Docente.id` (`f1a2…003`) como `idUsuario`, en lugar del `Usuario.id` (`E1F2…003`).

Se proponen como tareas `docs(...)` en el cierre del grupo que corresponda (E para 2, 3 y 6; A para 4 y 5).

---

## 9. Clase de cambio y alcance de rutas (este índice)

- **Change class:** `DOCUMENTATION_ONLY`
- **PRIMARY_VARIABLE:** descomposición del programa de registro de roles en work items.
- **ALLOWED_PATHS:** `docs/work-items/REG-000-programa-registro-vinculacion-roles/**` y, por grupo, `docs/work-items/<grupo>/**`.
- **FORBIDDEN_PATHS:** código fuente de los 3 repos; contratos WORM (`docs/contracts/**/*.sha256` y los archivos que firman); los archivos calientes del §7; `AsistenciasUCO-Infra/**`.
- **CONTRACTS / PROVIDERS / EXTERNAL_ENVIRONMENT:** NO APLICA (documental).
- **SECURITY_IMPACT / OBSERVABILITY_IMPACT:** NO APLICA en este work item; cada grupo los declara.
- **TEST_LEVEL_REQUIRED:** revisión documental (rutas citadas existen, secciones completas).
- **ROLLBACK:** borrar la carpeta y la rama `docs/plan-registro-roles`.
- **CONSUMERS:** el owner y los agentes implementadores.
- **STOP_CONDITIONS:** si el owner cambia DA-1…DA-5, se reabre este índice antes de seguir con más grupos.

---

## 10. Protocolo de ejecución de cada grupo (igual para A–J)

1. **Fase 01 PLAN:** el owner resuelve las decisiones `D*` del PLAN del grupo y el DoR pasa a `READY`.
2. **Fase 02 CONTRACT:** el borrador pasa a `CONTRACT_FROZEN` con la fecha de aprobación. Si algún grupo toca un contrato WORM (no previsto), se recalcula el `.sha256` con consenso inter-repositorio.
3. **Fase 03 TEST RED:** por repo y en orden **DB → Backend → Frontend**, una rama `feature/HUxxx-<slug>`. Se escriben las pruebas del TEST_PLAN, se comprueba que fallan y se registra el `RED_SNAPSHOT` (commit + hash + comando + exit code).
4. **Fase 04 GREEN:** se implementa el código de producción hasta que las pruebas pasan **sin tocarlas**. Cambiar una prueba exige un registro `TEST_CONTRACT_CONFLICT`.
5. **Fase 05 AUDIT:** `.\mvnw.cmd verify` (JaCoCo LINE ≥ 80 %, BRANCH ≥ 70 %; meta 100 % en use cases), ArchUnit, `npm run verify`, `test_suite.sql` con `@@TRANCOUNT = 0` y el script E2E `scratch/test_huXXX.ps1`. Se documenta en `VALIDATION.md`.
6. **Fase 06 CLOSURE:** `CLOSURE.md` con el DoD, actualización de `HTTP_AS_IS_MATRIX.md`, estado de las HUs en `HU-CATALOG.md` y sincronización del espejo con `sync-work-items.ps1`. Commits atómicos por capa (Conventional Commits, `Refs: HUxxx`) y un PR por repo, aprobados por el owner.

---

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Conflictos con HU035/036 en los archivos calientes | §7: implementar después del merge y rebasar; la planificación (docs) no los toca |
| Faltan columnas en DB (p. ej. modalidad/jornada en `Programa`) y hace falta DDL | Se declara como decisión en el grupo (WI-A D3), con un script de migración idempotente y su test |
| Fallo de Keycloak después del commit en DB | E define compensación o reconciliación; mientras tanto se registra en TD-015 y se prueba con `FakeKeycloakAdminServer` |
| Las HUs propuestas no se adoptan | F, G y J quedan `NOT_READY` hasta la adopción, sin bloquear al resto |

---

## 12. Definition of Ready (índice)

| Criterio | Estado | Evidencia |
|---|---|---|
| Alcance del programa acordado | ✅ | DA-1…DA-5 (2026-10-21) |
| Grupos y dependencias definidos | ✅ | §3 |
| HUs faltantes propuestas | ⏳ | §5: pendiente de adopción en el catálogo |
| Archivos calientes identificados | ✅ | §7 |
| WI-A redactado | ✅ (draft) | `docs/work-items/HU076-HU077-HU078-programa-academico-decano/` |

**Dictamen DoR del índice:** `NOT_READY`, pendiente de que el owner revise el índice y la adopción de las HUs propuestas. Cada grupo tiene su propio DoR.
