# HU104-HU105-HU109-HU119-HU145-lecturas-decano — Estudiantes, estructura y cronograma de la facultad (decano)

## Objetivo

Tres pantallas nuevas de solo lectura para el decano, sin tocar las pantallas existentes del portal del decano.

## Alcance y límites

- Contrato HTTP, decisiones y validación de las 3 capas: work item homónimo del backend (`docs/work-items/HU104-HU105-HU109-HU119-HU145-lecturas-decano/`).
- Sin cambios en `SecurityConfig` ni en contratos existentes; rutas y entradas de menú nuevas son aditivas.

## Pantallas, servicios y simulación

- `DeanEstudiantesComponent` (`/app/decano/estudiantes`), `DeanEstructuraComponent` (`/app/decano/estructura`) y `DeanCronogramaComponent` (`/app/decano/cronograma`) con sus entradas de menú.
- `DeanFacultadService` y modelo `facultad-decano.model.ts`; simulación en el interceptor mock.

## Rollback

Revertir los commits del work item; no hay migraciones de datos en el frontend.
