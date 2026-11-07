# SCREEN-RESULTS — Coordinador de programa (CULM-001, Fase 1)

Fecha: 2026-11-06. Usuario: `uco-coordinador`. Entorno: frontend `http://localhost:4200`, backend `http://localhost:8080`. Ejecución parcial: pasos de lectura y comprobación ejecutados; pasos de creación/edición/desactivación y móvil completo no ejecutados en esta pasada (ver tabla).

## 1. Pasos

| Paso | Vista | Resultado | Observación |
| :--- | :--- | :--- | :--- |
| 1 | Login y aterrizaje | OK | Aterriza en `/app/coordinador/docentes`. Login por Keycloak `security-baseline`. |
| 2 | Menú lateral | OK | Solo opciones de coordinador; sin sedes ni solicitudes. Colapsable [M] NO APLICA (no probado en móvil). |
| 3 | Docentes lista | OK | 1 docente (Maria Elena Rostagno Valencia), contadores 1/1/0, `GET /coordinador/docentes` y `/docentes/resumen` 200. Móvil: sin scroll horizontal (375/375). |
| 4 | Docentes búsqueda | NO EJECUTADO | Pendiente. |
| 5 | Ficha docente | NO EJECUTADO | Pendiente. |
| 6 | Alta docente | NO EJECUTADO | Pendiente (requiere crear `CULM1-Docente`). |
| 7 | Editar / activar docente | NO EJECUTADO | Pendiente. No se ha tocado al docente sembrado. |
| 8 | Planes de estudio | OK (parcial) | Lista con 1 plan (INP-2024, Plan 2024, VIGENTE). Crear/editar/activar no ejecutado. |
| 9 | Malla por semestres | NO EJECUTADO | Pendiente. |
| 10 | Asignatura CULM1-ASIG | NO EJECUTADO | Pendiente. |
| 11 | Quitar asignatura de malla (F-COO-005) | NO EJECUTADO | Pendiente; no se ha confirmado nada sobre datos sembrados. |
| 12 | Materias activar/inactivar | NO EJECUTADO | Vista `/app/coordinador/materias` cargada: 2 grupos, 1 asignatura ARQ-402, nómina visible. Activar/inactivar pendiente. |
| 13 | Períodos solo lectura | NO EJECUTADO | Ruta cargada sin verificar texto (la lectura de texto no llegó a renderizar). Pendiente de confirmar. |
| 14 | Grupos y horarios | OK (parcial) | 2 grupos listados sin paginación (F-COO-009 pendiente de juicio). `Editar` visible; crear grupo no ejecutado. |
| 15 | Asistencias (solo lectura) | OK (parcial) | Grupos y sesiones (5 sesiones en Grupo 001) y asistencia por sesión visibles. Sin checkboxes, botón guardar ni edición en la lista interactiva. Filtro fechas desde>hasta no probado. |
| 16 | Consolidado | OK (parcial) | Grupo 001: 10% asistencia / 0% inasistencia reproduce F-COO-007. |
| 17 | Estudiantes | FALLO | Total 22 (esperado 12). Reproduce F-COO-001. Incluye estudiantes con "Programa: No informado por el directorio". |
| 18 | Ficha de estudiante | NO EJECUTADO | Pendiente (F-COO-002). |
| 19 | Indicadores | FALLO (parcial) | KPI "Estudiantes" = 13; tabla de alertas muestra 13 filas, pero el listado de estudiantes tiene 22. Inconsistencia de conteo. Semáforo sin incidencias visibles. |
| 20 | Consistencia entre roles | NO EJECUTADO | Requiere registrar falta como docente. |
| 21 | Rutas ajenas | OK | `/app/admin/usuarios` redirige a `/login` (no muestra página 403). Comportamiento aceptable según guion ("redireccion"), sin datos. |
| 22 | Sin sesión | NO EJECUTADO | Pendiente. |
| 23 | Sesión expirada | NO EJECUTADO | Pendiente. |
| 24 | Estados carga/vacío/error | NO EJECUTADO | Pendiente. |
| 25 | Teclado y contraste | NO EJECUTADO | Pendiente. |
| 26 | Cerrar sesión | OK | "Cerrar sesión" del menú lateral lleva a `/login`. Volver atrás no comprobado. |
| [M] | Móvil (375x812) | OK (parcial) | Solo `/app/coordinador/docentes`: `scrollWidth` 375 = `innerWidth` 375. Resto de [M] NO EJECUTADO. Escritorio restaurado. |

Errores de consola observados en la carga de login y de cada vista: 401 (x5), 400 (x4), 500 (x1), `Uncaught TypeError: Cannot set properties of null (setting 'files')`, y CORS bloqueando `GET/POST http://localhost:8080/api/v1/public/matricula-qr/validar` desde `localhost:4200`. Estos errores aparecen también en la pantalla de login, antes de autenticarse.

## 2. Hallazgos

| ID | Rol | HU | Severidad | Tipo | Pasos | Esperado | Obtenido | Evidencia | Capa sospechosa | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| F-COO-S01 | COORDINADOR | HU065-HU070 | Alta | Aislamiento de datos | 17 | 12 estudiantes del programa | 22 estudiantes; "Programa: No informado por el directorio" en todos. Reproduce F-COO-001. | Pantalla `/app/coordinador/estudiantes`, "Mostrando 1 a 6 de 22" | SP de consulta de estudiantes (ámbito por programa no aplicado) | abierto |
| F-COO-S02 | COORDINADOR | HU061 | Media | Cálculo de métricas | 16 | Grupo 001 con 0% inasistencia y % asistencia coherente con sesiones | 10% asistencia, 0% inasistencia, 2 activos de 10 cupos. Reproduce F-COO-007. | Pantalla `/app/coordinador/consolidado-asistencia` | SP/vista de consolidado (`uv_*` de porcentajes) | abierto |
| F-COO-S03 | COORDINADOR | HU065 | Media | Consistencia de datos | 17, 19 | Total de estudiantes igual en listado e indicadores | Indicadores: 13. Listado: 22. Reproduce F-COO-006 (parcial). | Pantallas `/app/coordinador/indicadores` y `/app/coordinador/estudiantes` | SP de indicadores (`usp_*` KPIs) y consulta de estudiantes | abierto |
| F-COO-S04 | COORDINADOR | Global | Baja | Errores de consola y red | 1, todas | Consola sin errores ni CORS en login | 401/400/500 y CORS bloqueado en `/api/v1/public/matricula-qr/validar`; `TypeError` en `send` | Consola en `/login` y vistas del coordinador | Frontend (llamada pública en login) y backend (CORS/500 del endpoint QR) | abierto |

Observación (no es hallazgo formal): el historial de red de la pestaña mostró llamadas de `docente/asignaturas`, `docente/horarios`, `docente/reclamos` y `realtime/stream` de otra sesión (docente) en la misma pestaña durante el login. No se pudo confirmar causa; conviene revisar la separación de sesiones en el navegador de pruebas.

Observación: F-COO-005, F-COO-002, F-COO-009 y F-COO-010 no se reprodujeron en esta pasada (pasos no ejecutados). F-COO-003 no se evaluó.

## 3. Resumen

- Pasos OK: 1, 2, 3, 8 (parcial), 14 (parcial), 15 (parcial), 16 (parcial), 21, 26, móvil de docentes.
- Pasos FALLO: 17, 19 (parcial).
- Pasos NO EJECUTADOS: 4-7, 9-13, 18, 20, 22-25, móvil del resto.
- Hallazgos: Alta 1 (F-COO-S01), Media 2 (F-COO-S02, F-COO-S03), Baja 1 (F-COO-S04).
- Logout confirmado: sí, la app quedó en `/login`. Escritorio restaurado: sí.
