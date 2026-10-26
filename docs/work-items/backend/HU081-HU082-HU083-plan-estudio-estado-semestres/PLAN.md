---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-24
---

# PLAN — HU081 / HU082 / HU083: Estado y semestres del plan de estudios (Rol Coordinador)

## 1. Identidad y objetivo

- **Historias de usuario:**
  - **HU081**: Marcar un plan de estudios como activo o inactivo.
  - **HU082**: Añadir un semestre a un plan de estudios.
  - **HU083**: Quitar un semestre de un plan de estudios.
- **Work Item ID:** `HU081-HU082-HU083-plan-estudio-estado-semestres`
- **Fecha:** 2026-10-24
- **Base Git:** `develop` de DB, Backend y Frontend; rama `feature/HU081-HU082-HU083-plan-estudio-estado-semestres` en los tres repositorios.
- **Actor:** Coordinador de programa (`COORDINADOR`), solo sobre planes de su programa.
- **AS-IS comprobado:** el backend exponía `PATCH /coordinador/planes-estudio/{id}/toggle-estado`,
  `POST .../{id}/semestres` y `DELETE .../{id}/semestres/{numero}` respondiendo `501 FEATURE_UNAVAILABLE`
  porque la DB no publicaba SP para esas operaciones. El frontend llamaba `PATCH .../{id}/toggle` (ruta inexistente)
  y la malla simulaba agregar/quitar semestres con `PUT` del plan, que el backend ignoraba.

### Criterios de aceptación

1. El coordinador activa o inactiva un plan de su programa; la operación es idempotente y la lista refleja el estado.
2. Agregar semestre añade el siguiente número consecutivo (máximo el catálogo `dbo.Semestre`, hoy 10).
3. Quitar semestre solo quita el último semestre del plan y solo si no tiene asignaturas (activas o inactivas).
4. Un coordinador no puede operar planes de otro programa (la DB revalida RBAC y titularidad).
5. Los rechazos de negocio llegan al frontend como 404/409 con el mensaje del catálogo.

## 2. Alcance

| Capa | Cambio |
|---|---|
| DB | `usp_cambiar_estado_plan_estudio`, `usp_agregar_semestre_plan_estudio`, `usp_quitar_semestre_plan_estudio`; mensajes `PLA_002`..`PLA_006`; `uv_plan_estudio` considera `PlanEstudio.estado`; permisos aditivos `rol_asistencias_runtime_hu081_hu083.sql`; prueba `test_usp_plan_estudio_estado_semestres.sql`. |
| Backend | `PlanEstudioCommandPort` + `PlanEstudioJpaRepository` (3 comandos EXEC); `GestionarPlanEstudio*` (cambiarEstado, agregarSemestre, quitarSemestre); controlador sin 501; `DbFailureClassifier` (PLA_*); `totalSemestres` aditivo en la consulta de planes. |
| Frontend | URL `toggle-estado`; adaptación de la respuesta del backend a `PlanEstudioItem` (`normalizarPlanEstudio`); malla con `POST/DELETE .../semestres`; mock interceptor alineado. |

**Fuera de alcance:** eliminar asignaturas del plan (sigue 501), periodos académicos (Paquete 2), cambios de diseño de la pantalla.

## 3. Decisiones

- **D1:** "Quitar semestre" solo permite el último para que la malla siga consecutiva (`PLA_005`).
- **D2:** Un semestre con asignaturas inactivas tampoco se puede quitar: `dbo.Asignatura` referencia `SemestrePlanEstudio` (`PLA_006`).
- **D3:** `totalSemestres` es el mayor número de semestre del plan (no el conteo), porque `usp_crear_asignatura` puede crear semestres no consecutivos; la malla dibuja del 1 a ese número.
- **D4:** `uv_plan_estudio.estaActivoPlanEstudio` pasa a ser `programa activo AND PlanEstudio.estado = 1`; sin esto HU081 no sería visible. Ningún otro objeto DB ni consumidor backend depende de la semántica anterior.
- **D5:** El toggle del backend lee el estado actual desde los planes del programa del coordinador; un plan ajeno responde 404 sin revelar su existencia.
- **D6:** Contrato previo `unavailableEndpointsRemainExplicitlyUnavailable` se actualiza: los tres endpoints dejan de ser 501 por este work item.

## 4. Riesgos y rollback

- Riesgo bajo: los SP son nuevos; la vista solo agrega una condición. Rollback: revertir los commits de la rama en los tres repos (los SP nuevos quedan sin consumidor y la vista vuelve a la definición anterior).
- Conflictos con el equipo: permisos en archivo aditivo nuevo (no se toca `rol_asistencias_runtime.sql`).
