# HU064-HU060-HU061-consultas-coordinador — Asistencias del programa (coordinador)

## Objetivo

Pantalla de solo lectura: grupos del programa → sesiones del grupo → detalle de asistencia por estudiante.

## Alcance y límites

- Contrato HTTP, decisiones y validación de las 3 capas: work item homónimo del backend (`docs/work-items/HU064-HU060-HU061-consultas-coordinador/`).
- Sin cambios en `SecurityConfig` ni en contratos existentes; rutas y entradas de menú nuevas son aditivas.

## Pantallas, servicios y simulación

- `CoordinatorAttendanceComponent` (`/app/coordinador/asistencias`) y entrada de menú.
- `coordinator-management.service.ts`: `getGruposPrograma`, `getSesionesGrupo`, `getAsistenciasSesion`; modelo `asistencia-programa.model.ts`; simulación en el interceptor mock.

## Rollback

Revertir los commits del work item; no hay migraciones de datos en el frontend.
