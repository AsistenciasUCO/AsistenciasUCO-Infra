# MATRIZ-AMBITO · rol × endpoint (CULM-001 Fase 1, transversal)

Corrida del 2026-11-06 22:37, backend en modo baseline, tokens PKCE de `uco-administrador`, `uco-decano`, `uco-coordinador`, `uco-docente` y `uco-estudiante`. Universo: 169 endpoints de `GestioAsistenciaBackend/infra/security-baseline/access-catalog.json` (coincide con `SecurityConfig.java`, 0 discrepancias). Cada celda es el código HTTP de una llamada con IDs de ruta aleatorios (inexistentes) y cuerpo `{}`.

**Resumen:** 1003 celdas probadas (169 sin token + 834 con token; 1 omitida: `POST /realtime/emit` con administrador). 958 conformes, 45 con rol permitido que recibió 403 (revisión abajo), **0 fugas de ámbito**, 0 respuestas 2xx a rol no permitido, 169/169 con 401 sin token, `X-Correlation-Id` presente en 1003/1003. No ejecutados por ser destructivos (solo prueba sin token, 401): `POST /admin/cierre-masivo` y `POST /admin/notificaciones/prueba`.

**Leyenda:** `✓` conforme (sin token 401; rol no permitido 403; rol permitido distinto de 401/403). `✗` fuera de lo esperado. `(ámbito/PEP?)` rol permitido que recibió 403: con IDs aleatorios es el rechazo esperado de ámbito/titularidad para docente y coordinador sobre grupos o recursos ajenos; para administrador sobre `coordinador/*` y `decano/*` es el SP exigiendo perfil propio (hallazgo F-TRX-018, no es fuga).

**Límite de la prueba:** la BD sembrada solo tiene 1 facultad, 1 programa, 1 coordinador, 1 decano y 1 docente (F-TRX-008). No hay GUID "ajenos" reales, por lo que el aislamiento entre programas, facultades y docentes solo se probó con IDs inexistentes y con la inyección de parámetros de ámbito (`idFacultad`, `idPrograma`, `grupoId`, `docenteId`, `estudianteId`, `idUsuario`) en todos los GET de lista de decano, coordinador, docente y estudiante: ningún parámetro alteró el resultado. Pendiente tras sembrar un segundo ámbito.

Notas de resultado (más allá del 403): 500 en 17 celdas (`configuracion/identidad`, `configuracion/registro-estudiante`, `matricula-qr`, `matricular-grupo`, dos de notificaciones admin; ver F-TRX-017) y 25 respuestas 501 (F-TRX-004). `GET /realtime/stream` figura con 500 por la cabecera `Accept: application/json` de la matriz (F-TRX-019); la prueba SSE real está en `FINDINGS-transversal.md`.
| Método | Ruta | Roles permitidos | ANON | ADM | DEC | COO | DOC | EST |
|---|---|---|---|---|---|---|---|---|
| GET | `/api/v1/admin/areas` | ADM, DEC, COO | 401✓ | 200✓ | 200✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/asignaturas` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/auditoria` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/cierre-masivo` | ADM | 401✓ | no probado (destructivo) | no probado (destructivo) | no probado (destructivo) | no probado (destructivo) | no probado (destructivo) |
| GET | `/api/v1/admin/comparativa-facultades` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/decanos` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| PUT | `/api/v1/admin/decanos/{id}/identidad` | ADM | 401✓ | 400✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/docentes` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/decanos` | ADM | 401✓ | 400✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/admin/decanos/{id}/toggle` | ADM | 401✓ | 501✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/estados` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/estudiantes` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/estudiantes/{estudianteId}/historial` | ADM | 401✓ | 404✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/facultades` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/facultades` | ADM | 401✓ | 400✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| PUT | `/api/v1/admin/facultades/{id}` | ADM | 401✓ | 400✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/admin/facultades/{id}/estado` | ADM | 401✓ | 400✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/indicadores` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/instituciones` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/notificaciones/cola` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/notificaciones/cola/{id}/reintentar` | ADM | 401✓ | 500✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/notificaciones/estado-canal` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/notificaciones/plantillas` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/notificaciones/plantillas/{tipo}/versiones` | ADM | 401✓ | 500✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/admin/notificaciones/plantillas/{tipo}/versiones/{version}/activar` | ADM | 401✓ | 404✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/notificaciones/plantillas/{tipo}/vista-previa` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/notificaciones/prueba` | ADM | 401✓ | no probado (destructivo) | no probado (destructivo) | no probado (destructivo) | no probado (destructivo) | no probado (destructivo) |
| GET | `/api/v1/admin/parametros` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| PUT | `/api/v1/admin/parametros/{id}` | ADM | 401✓ | 501✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/admin/periodos-academicos` | ADM | 401✓ | 400✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| DELETE | `/api/v1/admin/periodos-academicos/{id}` | ADM | 401✓ | 404✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| PUT | `/api/v1/admin/periodos-academicos/{id}` | ADM | 401✓ | 400✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/tendencia-ausentismo` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/admin/tipos-programa` | ADM | 401✓ | 200✓ | 403✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/archivos/subir` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 415✓ |
| GET | `/api/v1/archivos/{fileId}` | cualquiera | 401✓ | 404✓ | 404✓ | 404✓ | 404✓ | 404✓ |
| POST | `/api/v1/asistencias` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| POST | `/api/v1/asistencias/consultas/grupo` | ADM, COO, DOC | 401✓ | 400✓ | 403✓ | 400✓ | 400✓ | 403✓ |
| POST | `/api/v1/asistencias/lote` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| POST | `/api/v1/asistencias/revisiones` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 400✓ |
| GET | `/api/v1/auth/me` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| GET | `/api/v1/categorias-justificacion` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| GET | `/api/v1/coordinador/alertas-tempranas` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/asignaturas` | ADM, DEC, COO | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 200✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/coordinador/asignaturas/{id}/estado` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 403✗ (ámbito/PEP?) | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/componentes-formacion` | ADM, COO | 401✓ | 200✓ | 403✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/consolidado-asistencia` | ADM, COO | 401✓ | 200✓ | 403✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/docentes` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| POST | `/api/v1/coordinador/docentes` | ADM, COO | 401✓ | 400✓ | 403✓ | 400✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/docentes/candidatos` | ADM, COO | 401✓ | 400✓ | 403✓ | 400✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/docentes/resumen` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| PUT | `/api/v1/coordinador/docentes/{idDocente}` | ADM, COO | 401✓ | 400✓ | 403✓ | 400✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/coordinador/docentes/{idDocente}/estado` | ADM, COO | 401✓ | 400✓ | 403✓ | 400✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/docentes/{idDocente}/ficha` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 404✓ | 403✓ | 403✓ |
| GET | `/api/v1/configuracion/registro-estudiante` | COO, DOC | 401✓ | 403✓ | 403✓ | 500✓ | 500✓ | 403✓ |
| GET | `/api/v1/configuracion/identidad` | cualquiera | 401✓ | 500✓ | 500✓ | 500✓ | 500✓ | 500✓ |
| GET | `/api/v1/coordinador/estudiantes` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/estudiantes/{idEstudiante}/bitacora` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 404✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/estudiantes/{idEstudiante}/ficha` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 404✓ | 403✓ | 403✓ |
| PUT | `/api/v1/coordinador/estudiantes/{idEstudiante}/identidad` | ADM, COO | 401✓ | 400✓ | 403✓ | 400✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/grupos` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| POST | `/api/v1/grupos/{grupoId}/estudiantes/{estudianteId}/reenviar-verificacion` | COO, DOC | 401✓ | 403✓ | 403✓ | 404✓ | 404✓ | 403✓ |
| POST | `/api/v1/coordinador/grupos/{grupoId}/estudiantes` | ADM, COO | 401✓ | 501✓ | 403✓ | 501✓ | 403✓ | 403✓ |
| DELETE | `/api/v1/coordinador/grupos/{grupoId}/estudiantes/{estudianteId}` | ADM, COO | 401✓ | 501✓ | 403✓ | 501✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/grupos/{grupoId}/sesiones` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/indicadores` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/periodos-academicos` | ADM, DEC, COO | 401✓ | 200✓ | 200✓ | 200✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/coordinador/periodos-academicos/{id}/estado` | ADM, COO | 401✓ | 501✓ | 403✓ | 501✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/planes-estudio` | ADM, DEC, COO | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 200✓ | 403✓ | 403✓ |
| POST | `/api/v1/coordinador/planes-estudio` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 400✓ | 403✓ | 403✓ |
| PUT | `/api/v1/coordinador/planes-estudio/{id}` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 400✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/planes-estudio/{id}/asignaturas` | ADM, DEC, COO | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 200✓ | 403✓ | 403✓ |
| POST | `/api/v1/coordinador/planes-estudio/{id}/asignaturas` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 403✗ (ámbito/PEP?) | 403✓ | 403✓ |
| POST | `/api/v1/coordinador/planes-estudio/{id}/semestres` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 404✓ | 403✓ | 403✓ |
| DELETE | `/api/v1/coordinador/planes-estudio/{id}/semestres/{numero}` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 404✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/coordinador/planes-estudio/{id}/toggle-estado` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 404✓ | 403✓ | 403✓ |
| DELETE | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | ADM, COO | 401✓ | 501✓ | 403✓ | 501✓ | 403✓ | 403✓ |
| PUT | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 403✗ (ámbito/PEP?) | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/sesiones/{sesionId}/asistencias` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 200✓ | 403✓ | 403✓ |
| GET | `/api/v1/coordinador/solicitudes-matricula` | ADM, COO | 401✓ | 501✓ | 403✓ | 501✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/coordinador/solicitudes-matricula/{id}` | ADM, COO | 401✓ | 501✓ | 403✓ | 501✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/aforo-grupos` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/asignaturas` | ADM, DEC | 401✓ | 200✓ | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/comparativa-programas` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/consolidado-asistencia` | ADM, DEC | 401✓ | 200✓ | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/coordinadores` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/decano/coordinadores` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 400✓ | 403✓ | 403✓ | 403✓ |
| PUT | `/api/v1/decano/coordinadores/{id}` | ADM, DEC | 401✓ | 400✓ | 400✓ | 403✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/decano/coordinadores/{id}/estado` | ADM, DEC | 401✓ | 400✓ | 400✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/docentes` | ADM, DEC | 401✓ | 200✓ | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/estructura` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/estudiantes` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/estudiantes/{estudianteId}` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 404✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/estudiantes/{estudianteId}/historial` | ADM, DEC | 401✓ | 404✓ | 404✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/grupos` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/indicadores` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/planes-estudio/{planId}/asignaturas` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/programas-creditos` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/programas` | ADM, DEC | 401✓ | 200✓ | 200✓ | 403✓ | 403✓ | 403✓ |
| POST | `/api/v1/decano/programas` | ADM, DEC | 401✓ | 400✓ | 400✓ | 403✓ | 403✓ | 403✓ |
| PUT | `/api/v1/decano/programas/{id}` | ADM, DEC | 401✓ | 400✓ | 400✓ | 403✓ | 403✓ | 403✓ |
| PATCH | `/api/v1/decano/programas/{id}/estado` | ADM, DEC | 401✓ | 400✓ | 400✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/decano/sesiones` | ADM, DEC | 401✓ | 403✗ (ámbito/PEP?) | 200✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/docente/asignaturas` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 200✓ | 403✓ |
| POST | `/api/v1/docente/grupos/{grupoId}/estudiantes/{estudianteId}/retiro` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| GET | `/api/v1/docente/grupos/{grupoId}/solicitudes-ingreso` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 200✓ | 403✓ |
| GET | `/api/v1/docente/oferta-creacion-grupos` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 200✓ | 403✓ |
| GET | `/api/v1/docente/horarios` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 200✓ | 403✓ |
| GET | `/api/v1/docente/reclamos` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 200✓ | 403✓ |
| GET | `/api/v1/docente/reclamos/{id}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 404✓ | 403✓ |
| PATCH | `/api/v1/docente/reclamos/{id}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| PATCH | `/api/v1/docente/sesiones/{sesionId}/cancelar` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 501✓ | 403✓ |
| PATCH | `/api/v1/docente/solicitudes-ingreso/{id}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| GET | `/api/v1/docentes` | ADM, COO | 401✓ | 200✓ | 403✓ | 200✓ | 403✓ | 403✓ |
| POST | `/api/v1/docentes/consultas/asignaciones` | ADM, COO | 401✓ | 400✓ | 403✓ | 400✓ | 403✓ | 403✓ |
| POST | `/api/v1/docentes/consultas/id` | ADM, COO | 401✓ | 400✓ | 403✓ | 400✓ | 403✓ | 403✓ |
| GET | `/api/v1/docentes/{docenteId}` | ADM, COO | 401✓ | 404✓ | 403✓ | 404✓ | 403✓ | 403✓ |
| GET | `/api/v1/docentes/{docenteId}/asignaciones` | ADM, COO | 401✓ | 200✓ | 403✓ | 200✓ | 403✓ | 403✓ |
| POST | `/api/v1/estudiante/asistencia-qr` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 400✓ |
| GET | `/api/v1/estudiante/horarios` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 200✓ |
| GET | `/api/v1/estudiante/materias` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 200✓ |
| GET | `/api/v1/estudiante/oferta-academica` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 200✓ |
| GET | `/api/v1/estudiante/materias/{materiaId}/sesiones` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 200✓ |
| POST | `/api/v1/estudiante/matricular-grupo` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 500✓ |
| GET | `/api/v1/estudiante/reclamos` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 200✓ |
| POST | `/api/v1/estudiante/reclamos` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 501✓ |
| DELETE | `/api/v1/estudiante/reclamos/{id}` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 501✓ |
| GET | `/api/v1/estudiante/solicitudes-matricula` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 200✓ |
| POST | `/api/v1/estudiante/solicitudes-matricula` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 400✓ |
| POST | `/api/v1/estudiante/solicitudes-matricula/{id}/retiro` | EST | 401✓ | 403✓ | 403✓ | 403✓ | 403✓ | 404✓ |
| GET | `/api/v1/estudiantes` | ADM, COO, DOC | 401✓ | 200✓ | 403✓ | 200✓ | 200✓ | 403✓ |
| GET | `/api/v1/estudiantes/{estudianteId}` | ADM, COO, DOC | 401✓ | 404✓ | 403✓ | 404✓ | 404✓ | 403✓ |
| GET | `/api/v1/grupos` | ADM, COO | 401✓ | 200✓ | 403✓ | 200✓ | 403✓ | 403✓ |
| POST | `/api/v1/grupos` | ADM, COO, DOC | 401✓ | 400✓ | 403✓ | 400✓ | 400✓ | 403✓ |
| GET | `/api/v1/grupos/{grupoId}/asistencias` | ADM, COO, DOC | 401✓ | 200✓ | 403✓ | 200✓ | 403✗ (ámbito/PEP?) | 403✓ |
| GET | `/api/v1/grupos/{grupoId}/estudiantes` | ADM, COO, DOC | 401✓ | 200✓ | 403✓ | 200✓ | 403✗ (ámbito/PEP?) | 403✓ |
| POST | `/api/v1/grupos/{grupoId}/estudiantes` | COO, DOC | 401✓ | 403✓ | 403✓ | 400✓ | 400✓ | 403✓ |
| POST | `/api/v1/grupos/{grupoId}/matricula-qr` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 500✓ | 403✓ |
| POST | `/api/v1/grupos/{grupoId}/matricula-qr/rotacion` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 500✓ | 403✓ |
| DELETE | `/api/v1/grupos/{grupoId}/matricula-qr` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 403✗ (ámbito/PEP?) | 403✓ |
| DELETE | `/api/v1/grupos/{grupoId}/estudiantes/{estudianteId}` | ADM, COO | 401✓ | 501✓ | 403✓ | 501✓ | 403✓ | 403✓ |
| GET | `/api/v1/grupos/{grupoId}/reportes/asistencia-excel` | ADM, COO, DOC | 401✓ | 200✓ | 403✓ | 403✗ (ámbito/PEP?) | 403✗ (ámbito/PEP?) | 403✓ |
| PUT | `/api/v1/grupos/{id}` | ADM, COO | 401✓ | 403✗ (ámbito/PEP?) | 403✓ | 400✓ | 403✓ | 403✓ |
| POST | `/api/v1/identidad/cuentas/acceso/consultas` | ADM, DEC, COO | 401✓ | 400✓ | 400✓ | 400✓ | 403✓ | 403✓ |
| POST | `/api/v1/identidad/cuentas/acceso/reconciliaciones` | ADM, DEC, COO | 401✓ | 400✓ | 400✓ | 400✓ | 403✓ | 403✓ |
| GET | `/api/v1/jornadas-programa` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| GET | `/api/v1/modalidades-programa` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| POST | `/api/v1/realtime/emit` | ADM | 401✓ | omitido | 403✓ | 403✓ | 403✓ | 403✓ |
| GET | `/api/v1/realtime/status` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| GET | `/api/v1/realtime/stream` | cualquiera | 401✓ | 500✓ | 500✓ | 500✓ | 500✓ | 500✓ |
| POST | `/api/v1/sesiones` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| POST | `/api/v1/sesiones/cierres` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| POST | `/api/v1/sesiones/consultas` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| GET | `/api/v1/sesiones/grupo/{grupoId}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 403✗ (ámbito/PEP?) | 403✓ |
| POST | `/api/v1/sesiones/grupo/{grupoId}/generacion` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 404✓ | 403✓ |
| GET | `/api/v1/sesiones/{sesionId}` | cualquiera | 401✓ | 404✓ | 404✓ | 404✓ | 404✓ | 404✓ |
| PATCH | `/api/v1/sesiones/{sesionId}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| PUT | `/api/v1/sesiones/{sesionId}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| GET | `/api/v1/sesiones/{sesionId}/qr-token` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 501✓ | 403✓ |
| GET | `/api/v1/tipos-identificacion` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| GET | `/api/v1/tipos-programa` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| GET | `/api/v1/tipos-vinculacion` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| POST | `/api/v1/usuarios` | cualquiera | 401✓ | 400✓ | 400✓ | 400✓ | 400✓ | 400✓ |
| GET | `/api/v1/usuarios/perfil` | cualquiera | 401✓ | 200✓ | 200✓ | 200✓ | 200✓ | 200✓ |
| PUT | `/api/v1/usuarios/perfil` | cualquiera | 401✓ | 501✓ | 501✓ | 501✓ | 501✓ | 501✓ |
| POST | `/api/v2/sesiones` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |
| GET | `/api/v2/sesiones/grupo/{grupoId}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 403✗ (ámbito/PEP?) | 403✓ |
| GET | `/api/v2/sesiones/{sesionId}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 404✓ | 403✓ |
| PATCH | `/api/v2/sesiones/{sesionId}` | DOC | 401✓ | 403✓ | 403✓ | 403✓ | 400✓ | 403✓ |

