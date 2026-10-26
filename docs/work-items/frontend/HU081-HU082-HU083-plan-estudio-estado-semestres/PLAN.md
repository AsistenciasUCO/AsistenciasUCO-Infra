# HU081-HU082-HU083-plan-estudio-estado-semestres — Estado y semestres del plan de estudio

## Objetivo

Que el coordinador active/inactive un plan y añada o quite semestres desde la malla, con avisos visibles.

## Alcance y límites

- Contrato HTTP, decisiones y validación de las 3 capas: work item homónimo del backend (`docs/work-items/HU081-HU082-HU083-plan-estudio-estado-semestres/`).
- Sin cambios en `SecurityConfig` ni en contratos existentes; rutas y entradas de menú nuevas son aditivas.

## Pantallas, servicios y simulación

- `CoordinatorStudyPlansComponent` y `CoordinatorStudyPlanMeshPageComponent`: toggle de estado, añadir/quitar semestre (`MAX_SEMESTRES = 10`), aviso con el mensaje del backend y recarga de planes.
- `coordinator-management.service.ts`: URL `toggle-estado`, `normalizarPlanEstudio` y `normalizarAsignaturaPlan`.

## Rollback

Revertir los commits del work item; no hay migraciones de datos en el frontend.
