---
status: active
type: work-item
scope: backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# PLAN — HU108 (parte de planes): Malla del plan de estudio para el decano

## 1. Identidad y objetivo

- **Historia de usuario:** **HU108** "Consultar programas vigentes y planes de estudio" (Decano).
- **Work Item ID:** `HU108-malla-plan-decano`
- **Fecha:** 2026-10-26
- **Base Git:** rama `feature/HU108-malla-plan-decano` creada sobre `develop` (después de integrar HU081-HU083, HU096-HU098, HU064/HU060/HU061 y HU104-HU145).
- **AS-IS comprobado:**
  - El listado de programas (HU108, parte 1) se entregó en el WI `HU076-HU077-HU078-programa-academico-decano`, que dejó HU108 **parcial**: los planes quedaron fuera de alcance.
  - El listado de planes por programa quedó disponible con `GET /api/v1/decano/estructura` (HU109/HU119).
  - Las pantallas `decano/programas` (lista de planes) y `decano/programas/:planId` (malla) llamaban a `/api/v1/coordinador/planes-estudio` y `/api/v1/coordinador/planes-estudio/{id}/asignaturas`. `SecurityConfig` no admite al rol DECANO en `/api/v1/coordinador/**`, así que con backend real no cargaban (solo funcionaban con mocks).
  - El caso de uso `ConsultarAsignaturasPlanUseCaseImpl` ya contempla al decano: exige facultad y valida con `canDecanoAccessPrograma` que el programa del plan sea de su facultad (403 si no). Tiene pruebas para ese caso.

### Criterios de aceptación

1. El decano ve los planes de los programas de su facultad en "Programas y Planes".
2. Al abrir un plan ve su ficha (programa, INP, semestres, vigencia, créditos y número de asignaturas) y la malla (asignaturas por semestre, área, componente y créditos), con filtros por semestre y texto.
3. Un plan de un programa de otra facultad responde 403 y la pantalla muestra el mensaje.

## 2. Alcance

| Capa | Cambio |
|---|---|
| DB | Sin cambios: la consulta de asignaturas del plan ya existe y la estructura de la facultad (`usp_consultar_estructura_facultad`) ya expone los planes. |
| Backend | `DecanoPlanEstudioController` con `GET /api/v1/decano/planes-estudio/{planId}/asignaturas`, que reutiliza `ConsultarAsignaturasPlanInputPort` (cubierto por la regla existente `/api/v1/decano/**`). `SecurityConfig` sin cambios. |
| Frontend | `DeanFacultadService.getAsignaturasPlan` y `planesDeLaEstructura`; `dean-programas` y `dean-plan-malla` dejan de usar las rutas del coordinador; simulación en el interceptor mock. |

## 3. Decisiones

- **D1:** No se crea un SP nuevo. El acceso a datos de la malla ya existe y su ámbito por facultad ya está implementado y probado en el caso de uso; duplicarlo en un SP no agregaría control.
- **D2:** La ficha del plan se arma con la estructura de la facultad (una sola consulta, ya limitada al decano); créditos y número de asignaturas se calculan con la malla.
- **D3:** Se modifican dos pantallas del portal del decano (`dean-programas`, `dean-plan-malla`) solo en la carga de datos; el diseño no cambia.

## 4. Riesgos y rollback

- Rollback: revertir los commits de la rama; no hay cambios de BD.
