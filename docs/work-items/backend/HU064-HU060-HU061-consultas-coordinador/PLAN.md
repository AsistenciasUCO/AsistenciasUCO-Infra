---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# PLAN — HU064 / HU060 / HU061: Consultas del coordinador sobre su programa

## 1. Identidad y objetivo

- **Historias de usuario:**
  - **HU064**: Consultar los grupos del programa (asignatura, docente, período y cupo).
  - **HU060**: Consultar los registros de asistencia del programa (sesiones del grupo, con rango de fechas).
  - **HU061**: Consultar el detalle de un registro de asistencia (cada estudiante de la sesión, si asistió y la razón).
- **Work Item ID:** `HU064-HU060-HU061-consultas-coordinador`
- **Fecha:** 2026-10-25
- **Base Git:** rama `feature/HU064-HU060-HU061-consultas-coordinador` creada sobre `feature/HU096-HU097-HU098-periodos-academicos` (comparte `coordinator-management.service.ts`, el interceptor mock y el menú). Se integra después de los PR de HU081-HU083 y HU096-HU098.
- **Actor:** `COORDINADOR` de programa. Solo lectura.
- **AS-IS comprobado:** los SP `usp_consultar_grupos_paginado`, `usp_consultar_sesiones_grupo_paginado` y `usp_consultar_asistencias_sesion_paginado` ya existían y filtran por el usuario ejecutor (vistas `uv_auth_grupo` / `uv_auth_sesion`: el coordinador ve su programa), pero ningún endpoint los consumía y no tenían prueba de aislamiento por programa ni permiso explícito en el rol runtime.

### Criterios de aceptación

1. El coordinador lista los grupos de su programa, filtra por período y texto, y pagina.
2. Al elegir un grupo ve sus sesiones (con filtro de rango de fechas) y pagina.
3. Al elegir una sesión ve cada estudiante con documento, si asistió y la razón/causa; puede filtrar por asistió/no asistió.
4. Un coordinador nunca ve grupos, sesiones ni asistencias de otro programa.
5. Un usuario sin programa de coordinador recibe 403; paginación fuera de rango o rango de fechas invertido, 400.

## 2. Alcance

| Capa | Cambio |
|---|---|
| DB | Sin cambios en los SP. Permisos aditivos `rol_asistencias_runtime_hu060_hu064.sql` (EXECUTE de los 3 SP) y prueba `test_consultas_coordinador_programa.sql` (titular ve; coordinador de otro programa no ve) registrada en `test_suite.sql`. |
| Backend | Feature `coordinador/consultarasistenciaprograma` (input port, interactor, caso de uso), `AsistenciaProgramaQueryPort` + `AsistenciaProgramaJpaRepository` (native `EXEC` con entidades `Sp*PaginadoEntity`), `CoordinadorAsistenciaProgramaController` (`GET /grupos`, `GET /grupos/{id}/sesiones`, `GET /sesiones/{id}/asistencias` bajo `/api/v1/coordinador`, protegido por la regla existente `/api/v1/coordinador/**`), wiring propio `AsistenciaProgramaWiringConfiguration`. `SecurityConfig` sin cambios. |
| Frontend | Nueva pantalla `coordinador/asistencias` ("Asistencias del Programa" en el menú del coordinador): grupos → sesiones → detalle; métodos del servicio y simulación en el interceptor mock. |

**Fuera de alcance:** edición de asistencias (la hace el docente) y exportes.

## 3. Decisiones

- **D1:** El aislamiento por programa lo garantiza el provider DB (filtro por ejecutor); el caso de uso además exige que el usuario tenga programa de coordinador (403 temprano).
- **D2:** HU060 se presenta como "sesiones del grupo con su registro de asistencia" y HU061 como el detalle de la sesión; reutiliza los SP existentes sin crear nuevos.
- **D3:** Paginación por defecto 1/10 (detalle 20 en la UI), máximo 100; `PAG_001` del SP se traduce a 400.

## 4. Riesgos y rollback

- Sin cambios en `SecurityConfig` ni en archivos compartidos de permisos.
- Rollback: revertir los commits de la rama; los SP no cambian.
