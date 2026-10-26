---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# PLAN — HU104 / HU105 / HU109 / HU119 / HU145: Consultas del decano sobre su facultad

## 1. Identidad y objetivo

- **Historias de usuario:**
  - **HU104**: Directorio consolidado de estudiantes de la facultad.
  - **HU105**: Búsqueda de un estudiante (nombre o documento) y su ficha con matrículas.
  - **HU109**: Organigrama de la facultad.
  - **HU119**: Árbol Facultad → Programa → Plan de estudio.
  - **HU145**: Cronograma de sesiones programadas en la facultad.
- **Work Item ID:** `HU104-HU105-HU109-HU119-HU145-lecturas-decano`
- **Fecha:** 2026-10-25
- **Base Git:** rama `feature/HU104-HU105-HU109-HU119-HU145-lecturas-decano` creada sobre `feature/HU064-HU060-HU061-consultas-coordinador`.
- **Actor:** `DECANO`. Solo lectura.
- **AS-IS comprobado:** no existían SP ni endpoints para estas lecturas; `usp_consultar_estudiantes_paginado` no filtra por ámbito. Las vistas `uv_auth_estudiante`, `uv_auth_facultad`, `uv_auth_programa`, `uv_auth_grupo` y `uv_auth_sesion` ya contemplan al decano.

### Criterios de aceptación

1. El decano ve el directorio de estudiantes de su facultad (una fila por estudiante, con sus programas y número de grupos), lo busca por nombre o documento, lo filtra por estado y pagina.
2. Abre la ficha de un estudiante con sus matrículas (programa, plan, asignatura, grupo); un estudiante de otra facultad responde 404.
3. Ve la estructura de su facultad: programas (tipo, modalidad, jornada, coordinador, estado) y sus planes (INP, semestres, vigencia).
4. Ve el cronograma de sesiones de su facultad por rango de fechas, paginado.
5. Un decano de otra facultad o un usuario sin ámbito no ven nada; sin facultad de decano ⇒ 403.

## 2. Alcance

| Capa | Cambio |
|---|---|
| DB | SP `usp_consultar_estudiantes_facultad_paginado`, `usp_consultar_estudiante_facultad_detalle`, `usp_consultar_estructura_facultad`, `usp_consultar_sesiones_facultad_paginado` (READ_QUERY_RESULTSET sobre `uv_auth_*` restringidas a la facultad del decano ejecutor; `PAG_001` en paginación); permisos aditivos `rol_asistencias_runtime_hu104_hu145.sql`; exclusiones de lectura en `test_contract_closure.sql`; prueba `test_consultas_decano_facultad.sql`. |
| Backend | Feature `decano/consultarfacultad`, `FacultadDecanoQueryPort` + `FacultadDecanoJpaRepository`, `DecanoFacultadConsultaController` (`GET /estudiantes`, `/estudiantes/{id}`, `/estructura`, `/sesiones` bajo `/api/v1/decano`, cubierto por la regla existente `/api/v1/decano/**`), wiring propio. `SecurityConfig` y controladores del decano existentes sin cambios. |
| Frontend | Pantallas nuevas `decano/estudiantes`, `decano/estructura` y `decano/cronograma` (entradas nuevas en el menú del decano), `DeanFacultadService` propio y simulación en el interceptor mock. Las pantallas del decano existentes no se tocan. |

**Fuera de alcance:** sede/espacio de la sesión (la sesión no guarda sede en el modelo actual), exportes.

## 3. Decisiones

- **D1:** HU109 y HU119 comparten la misma consulta y pantalla (el organigrama es el árbol Facultad → Programa → Plan).
- **D2:** El ámbito lo garantiza el SP (facultades cuyo `decano` es el ejecutor, sobre vistas `uv_auth_*`); el caso de uso además exige facultad de decano (403 temprano).
- **D3:** La estructura devuelve filas planas con `clave` única (facultad|programa|plan); el interactor arma el árbol.
- **D4:** Archivos nuevos (controlador, servicio, pantallas) para no chocar con el portal del decano que mantiene otro integrante.

## 4. Riesgos y rollback

- Sin cambios en `SecurityConfig` ni en archivos compartidos de permisos.
- Rollback: revertir los commits de la rama; los SP son nuevos.
