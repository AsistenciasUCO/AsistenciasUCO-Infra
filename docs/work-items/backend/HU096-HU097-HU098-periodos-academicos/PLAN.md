---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# PLAN — HU096 / HU097 / HU098: Gestión de períodos académicos (Administrador institucional)

## 1. Identidad y objetivo

- **Historias de usuario:**
  - **HU096**: Crear un nuevo período académico.
  - **HU097**: Modificar los datos de un período académico.
  - **HU098**: Eliminar un período académico.
- **Work Item ID:** `HU096-HU097-HU098-periodos-academicos`
- **Fecha:** 2026-10-25
- **Base Git:** rama `feature/HU096-HU097-HU098-periodos-academicos` creada sobre `feature/HU081-HU082-HU083-plan-estudio-estado-semestres` (comparten `CoordinadorPortalController` y `coordinator-management.service.ts`). Se integra después del PR de HU081-HU083.
- **Actor:** `ADMINISTRADOR` de la institución. El período académico es **único para toda la institución**; si lo gestionaran los muchos decanos y coordinadores, cualquiera cambiaría las fechas de todos. `DECANO` y `COORDINADOR` solo lo consultan. Decisión del dueño de producto (2026-10-25); el catálogo de HU nombra al "Coordinador de programa" como actor de HU096, por lo que esta desviación queda registrada aquí.
- **AS-IS comprobado:** `POST/PUT /coordinador/periodos-academicos` respondían 501; `usp_crear_periodo_academico` exigía `ADMINISTRADOR` pero su `INSERT` omitía columnas `NOT NULL` (`institucion`, `codigo`, `anio`), por lo que nunca podía crear; no existían SP de modificar ni eliminar. La pantalla del coordinador simulaba un "estado" que la tabla no tiene.

### Criterios de aceptación

1. El administrador crea un período con nombre único en su institución y `fechaInicio < fechaFin`.
2. Lo modifica (nombre y fechas) con las mismas reglas.
3. Eliminar solo se permite si el período no tiene grupos (las sesiones pertenecen a grupos, por lo que tampoco tiene sesiones).
4. Decano, coordinador, docente y estudiante reciben 403; decano y coordinador siguen consultando con `GET`.
5. `codigo` y `anio` se derivan de `fechaInicio` (2026-2 ⇒ 20262), igual que la semilla.

## 2. Alcance

| Capa | Cambio |
|---|---|
| DB | `usp_crear_periodo_academico` reescrito; `usp_actualizar_periodo_academico`, `usp_eliminar_periodo_academico`; núcleo `usp_resolver_institucion_gestor_periodo_interno` (RBAC `ADMINISTRADOR` + `dbo.Administrador.institucion` activa); mensajes `PER_001`..`PER_006`; permisos aditivos `rol_asistencias_runtime_hu096_hu098.sql`; prueba `test_usp_periodo_academico_gestion.sql`. |
| Backend | Feature `admin/gestionarperiodoacademico`, `PeriodoAcademicoCommandPort` + `PeriodoAcademicoCommandJpaRepository`, `AdminPeriodoAcademicoController` (`POST`, `PUT /{id}`, `DELETE /{id}` bajo `/api/v1/admin/periodos-academicos`, protegido por la regla existente `/api/v1/admin/**`), `PER_*` en `DbFailureClassifier`. `SecurityConfig` sin cambios. |
| Frontend | Nueva pantalla `admin/periodos` (menú del administrador) con crear/editar/eliminar; `normalizarPeriodoAcademico` (estado calculado por fechas); formulario sin "estado" manual; botón "Eliminar" con confirmación; las pantallas de períodos de coordinador y decano quedan de solo consulta (`soloLectura`). |

**Fuera de alcance:** `PATCH /coordinador/periodos-academicos/{id}/estado` (sigue 501: la tabla no tiene estado) y el cierre masivo del administrador.

## 3. Decisiones

- **D1:** Gestiona solo el `ADMINISTRADOR` de la institución (RBAC HTTP en `/api/v1/admin/**` y revalidación en DB).
- **D2:** HU098 elimina; no es el cierre masivo. Solo sin grupos (`PER_004`).
- **D3:** La institución sale de `dbo.Administrador.institucion` (activa); si no hay, `PER_005`.
- **D4:** El estado mostrado (planeación/activo/cerrado) se calcula con las fechas en el frontend; no se agrega columna.
- **D5:** Los comandos van en `AdminPeriodoAcademicoController`; la consulta sigue en `GET /api/v1/coordinador/periodos-academicos` (decano, coordinador y administrador).

## 4. Riesgos y rollback

- Sin cambios en `SecurityConfig` ni en el archivo compartido de permisos (no hay choque con el trabajo de RBAC del decano).
- Rollback: revertir los commits de la rama; `usp_crear_periodo_academico` vuelve a la versión anterior (que no era funcional).
