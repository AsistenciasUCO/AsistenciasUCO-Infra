# HU096-HU097-HU098-periodos-academicos — Períodos académicos gestionados por el administrador

## Objetivo

Pantalla del administrador para crear, editar y eliminar períodos; coordinador y decano quedan en solo lectura.

## Alcance y límites

- Contrato HTTP, decisiones y validación de las 3 capas: work item homónimo del backend (`docs/work-items/HU096-HU097-HU098-periodos-academicos/`).
- Sin cambios en `SecurityConfig` ni en contratos existentes; rutas y entradas de menú nuevas son aditivas.

## Pantallas, servicios y simulación

- `AdminPeriodosComponent` (`/app/admin/periodos`) y entrada de menú del administrador.
- `AcademicPeriodsTabComponent`: entrada `soloLectura` y salida `deletePeriodo`; períodos del coordinador en solo lectura.
- Servicio: URLs `/admin/periodos-academicos`, `eliminarPeriodoAcademico`, `normalizarPeriodoAcademico`; simulación en el interceptor mock.

## Rollback

Revertir los commits del work item; no hay migraciones de datos en el frontend.
