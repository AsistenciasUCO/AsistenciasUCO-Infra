# HU108-malla-plan-decano — Planes y malla del plan para el decano

## Objetivo

Que "Programas y Planes" y la malla del decano carguen datos reales sin usar rutas del coordinador (`SecurityConfig` no admite DECANO en `/coordinador/**`).

## Alcance y límites

- Contrato HTTP, decisiones y validación de las 3 capas: work item homónimo del backend (`docs/work-items/HU108-malla-plan-decano/`).
- Sin cambios en `SecurityConfig` ni en contratos existentes; rutas y entradas de menú nuevas son aditivas.

## Pantallas, servicios y simulación

- `DeanProgramasComponent`: planes desde `GET /api/v1/decano/estructura` (`planesDeLaEstructura`).
- `DeanPlanMallaComponent`: ficha desde la estructura y malla desde `GET /api/v1/decano/planes-estudio/{id}/asignaturas`; créditos calculados y mensaje del backend en caso de error.
- `DeanFacultadService.getAsignaturasPlan`; simulación en el interceptor mock.

## Rollback

Revertir los commits del work item; no hay migraciones de datos en el frontend.
