# Matriz de Rutas y Permisos por Rol (Access Catalog)

> **Documento autogenerado.** No editar manualmente.
> **Fuente SSOT:** `access-catalog.json` (Security Baseline)
> **Generador:** `scripts/docs/generar-rutas-por-rol.ps1` (F-ADM-020)

Este documento detalla todas las rutas expuestas por la API REST de Asistencias UCO,
sus mÃ©todos HTTP permitidos, roles con acceso y polÃ­ticas de propiedad o Ã¡mbito (*ownership*).

## Resumen General

- **Total de Endpoints Protegidos:** 201
- **Total de Endpoints Exentos (PÃºblicos / Webhook):** 4
- **Roles Definidos:** ADMINISTRADOR, DECANO, COORDINADOR, DOCENTE, ESTUDIANTE

## Perfiles Funcionales

| Perfil | Roles Asociados | DescripciÃ³n |
| :--- | :--- | :--- |
| **Administración institucional** | `ADMINISTRADOR` | Gestión institucional: facultades, decanos, parámetros, períodos, auditoría y cierre masivo. |
| **Decanatura** | `DECANO` | Consulta y gestión de la facultad: coordinadores, programas, estructura, estudiantes, cronograma y plan de estudio. |
| **Coordinación de programa** | `COORDINADOR` | Gestión académica del programa: planes, semestres, grupos, docentes, sesiones y asistencias. |
| **Docencia** | `DOCENTE` | Grupos y horarios propios, sesiones (UTC v1/v2), registro de asistencia y atención de reclamos. |
| **Estudiantes** | `ESTUDIANTE` | Materias, sesiones y asistencias propias, solicitudes de revisión y soportes. |

## CatÃ¡logo de Rutas por Rol

### Rol: ADMINISTRADOR (76)

| MÃ©todo | Ruta | Tipo de Acceso | Ãmbito / Ownership |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/admin/areas` | ROLES | â€” |
| `GET` | `/api/v1/admin/asignaturas` | ROLES | HU143: asignaturas de la institucion del administrador; el ambito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/admin/auditoria` | ROLES | HU172: rastro de auditoria de la institucion; solo lectura, rango maximo de 90 dias; el procedimiento almacenado exige el perfil ADMINISTRADOR. |
| `POST` | `/api/v1/admin/cargas` | ROLES | HU171: Carga masiva de decanos por el administrador institucional; auditado. |
| `GET` | `/api/v1/admin/cargas/plantilla` | ROLES | HU171: Descarga de plantilla CSV de decanos para carga masiva. |
| `POST` | `/api/v1/admin/cargas/validacion` | ROLES | HU171: Validacion previa sin escrituras de carga masiva de decanos. |
| `POST` | `/api/v1/admin/cierre-masivo` | ROLES | â€” |
| `GET` | `/api/v1/admin/cierre-masivo/historial` | ROLES | â€” |
| `GET` | `/api/v1/admin/comparativa-facultades` | ROLES | â€” |
| `GET` | `/api/v1/admin/decanos` | ROLES | â€” |
| `POST` | `/api/v1/admin/decanos` | ROLES | â€” |
| `PUT` | `/api/v1/admin/decanos/{id}/identidad` | ROLES | HU159: el administrador corrige documento, nombres y apellidos del decano (motivo obligatorio, auditado); la jerarquia la fuerza el SP. |
| `PATCH` | `/api/v1/admin/decanos/{id}/toggle` | ROLES | â€” |
| `GET` | `/api/v1/admin/docentes` | ROLES | HU136: docentes con vinculo activo en las facultades de la institucion del administrador (el ambito lo fuerza el procedimiento almacenado); solo consulta. |
| `GET` | `/api/v1/admin/estados` | ROLES | HU155: estados de solicitudes y del estudiante en el grupo; catalogos base de solo consulta (regla de John 2026-11-04). |
| `GET` | `/api/v1/admin/estudiantes` | ROLES | HU157: estudiantes de la institucion del administrador; el ambito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/admin/estudiantes/{estudianteId}/historial` | ROLES | HU157: estudiantes de la institucion del administrador; el ambito lo fuerza el procedimiento almacenado. |
| `PUT` | `/api/v1/admin/estudiantes/{idEstudiante}/identidad` | ROLES | CULM-001 D.4 (HU156, OBS-6): el administrador corrige la identidad del estudiante de un programa de su institucion (motivo obligatorio, auditado); la jerarquia la fuerza usp_corregir_identidad_usuario. |
| `POST` | `/api/v1/admin/estudiantes/admision` | ROLES | CULM-001 D.4 (HU156): el administrador admite estudiantes en un programa de su institucion sin matricularlos; usp_admitir_estudiante valida RBAC, ambito, unicidad, correo institucional y clave inicial. |
| `GET` | `/api/v1/admin/facultades` | ROLES | â€” |
| `POST` | `/api/v1/admin/facultades` | ROLES | â€” |
| `PUT` | `/api/v1/admin/facultades/{id}` | ROLES | â€” |
| `PATCH` | `/api/v1/admin/facultades/{id}/estado` | ROLES | â€” |
| `GET` | `/api/v1/admin/festivos` | ROLES | CULM-001 B.1: catalogo nacional de dias festivos de solo consulta; el procedimiento almacenado exige el perfil ADMINISTRADOR. |
| `POST` | `/api/v1/admin/festivos/{anio}/recarga` | ROLES | CULM-001 B.1: recarga nacional de festivos; la aplicacion a sesiones se limita a los grupos de la institucion del administrador (SP). |
| `GET` | `/api/v1/admin/festivos/{anio}/sesiones-con-asistencia` | ROLES | CULM-001 B.1: solo grupos de la institucion del administrador (SP). |
| `GET` | `/api/v1/admin/indicadores` | ROLES | â€” |
| `GET` | `/api/v1/admin/instituciones` | ROLES | â€” |
| `GET` | `/api/v1/admin/notificaciones/cola` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `POST` | `/api/v1/admin/notificaciones/cola/{id}/reintentar` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `GET` | `/api/v1/admin/notificaciones/estado-canal` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `GET` | `/api/v1/admin/notificaciones/plantillas` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `POST` | `/api/v1/admin/notificaciones/plantillas/{tipo}/versiones` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `PATCH` | `/api/v1/admin/notificaciones/plantillas/{tipo}/versiones/{version}/activar` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `POST` | `/api/v1/admin/notificaciones/plantillas/{tipo}/vista-previa` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `POST` | `/api/v1/admin/notificaciones/prueba` | ROLES | NOTIF-002B/TD-069: gestion de correos institucionales; el SP exige el perfil ADMINISTRADOR y el cuerpo no expone direcciones de destinatarios. |
| `GET` | `/api/v1/admin/parametros` | ROLES | â€” |
| `PUT` | `/api/v1/admin/parametros/{id}` | ROLES | â€” |
| `GET` | `/api/v1/admin/parametros/{id}/cambios` | ROLES | â€” |
| `GET` | `/api/v1/admin/periodos-academicos` | ROLES | CULM-001 D.9-a: periodos de la institucion del administrador; el perfil y la institucion los fuerza usp_consultar_periodos_academicos_paginado. |
| `POST` | `/api/v1/admin/periodos-academicos` | ROLES | â€” |
| `DELETE` | `/api/v1/admin/periodos-academicos/{id}` | ROLES | â€” |
| `PUT` | `/api/v1/admin/periodos-academicos/{id}` | ROLES | â€” |
| `GET` | `/api/v1/admin/programas` | ROLES | CULM-001 D.4: programas activos de la institucion del administrador (usp_consultar_programas_institucion_paginado, paginado). |
| `GET` | `/api/v1/admin/tendencia-ausentismo` | ROLES | â€” |
| `GET` | `/api/v1/admin/tipos-programa` | ROLES | â€” |
| `GET` | `/api/v1/archivos/{fileId}` | AUTHENTICATED | Propietario del soporte: un no propietario recibe 404 (resuelto en Application). |
| `POST` | `/api/v1/asistencias/consultas/grupo` | ROLES | Docente titular del grupo de la sesion; el estudiante solo sus propias asistencias/revisiones. |
| `GET` | `/api/v1/auth/me` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/categorias-justificacion` | AUTHENTICATED | HU005/HU016: catalogo base de solo consulta (motivos para justificar una inasistencia); sin datos personales. |
| `GET` | `/api/v1/configuracion/identidad` | AUTHENTICATED | HU159: indica si la correccion del documento esta habilitada (parametro IDENTIDAD.PERMITIR_CORREGIR_DOCUMENTO); sin datos personales. |
| `GET` | `/api/v1/coordinador/periodos-academicos` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/docentes` | ROLES | Alcance del programa del coordinador. |
| `GET` | `/api/v1/docentes/{docenteId}` | ROLES | Alcance del programa del coordinador. |
| `GET` | `/api/v1/docentes/{docenteId}/asignaciones` | ROLES | Alcance del programa del coordinador. |
| `POST` | `/api/v1/docentes/consultas/asignaciones` | ROLES | Alcance del programa del coordinador. |
| `POST` | `/api/v1/docentes/consultas/id` | ROLES | Alcance del programa del coordinador. |
| `GET` | `/api/v1/estudiantes` | ROLES | Ambito en el SP usp_consultar_directorio_estudiantes_paginado (ADMINISTRADOR institucion, COORDINADOR programas, DOCENTE grupos propios). |
| `GET` | `/api/v1/estudiantes/{estudianteId}` | ROLES | Ambito en el SP usp_consultar_directorio_estudiantes_paginado (ADMINISTRADOR institucion, COORDINADOR programas, DOCENTE grupos propios). |
| `GET` | `/api/v1/grupos` | ROLES | DOCENTE solo grupos propios, COORDINADOR solo de su programa (Application + SP). |
| `GET` | `/api/v1/grupos/{grupoId}/asistencias` | ROLES | CULM-001 A.2-2: ambito en el SP (DOCENTE titular, COORDINADOR del programa del grupo, ADMINISTRADOR de la institucion); grupo ajeno o inexistente 403. |
| `GET` | `/api/v1/grupos/{grupoId}/estudiantes` | ROLES | CULM-001 A.2-2: ambito en el SP (DOCENTE titular, COORDINADOR del programa del grupo, ADMINISTRADOR de la institucion); grupo ajeno o inexistente 403. |
| `GET` | `/api/v1/grupos/{grupoId}/reportes/asistencia-excel` | ROLES | DOCENTE solo grupos propios, COORDINADOR solo de su programa (Application + SP). |
| `PUT` | `/api/v1/grupos/{id}` | ROLES | DOCENTE solo grupos propios, COORDINADOR solo de su programa (Application + SP). |
| `POST` | `/api/v1/identidad/cuentas/acceso/consultas` | ROLES | Alcance en Application (AccesoCuentaService): administrador cualquiera; decano coordinadores, docentes y estudiantes de su facultad; coordinador docentes y estudiantes de su programa. Nunca asigna DECANO ni ADMINISTRADOR. |
| `POST` | `/api/v1/identidad/cuentas/acceso/reconciliaciones` | ROLES | Alcance en Application (AccesoCuentaService): administrador cualquiera; decano coordinadores, docentes y estudiantes de su facultad; coordinador docentes y estudiantes de su programa. Nunca asigna DECANO ni ADMINISTRADOR. |
| `GET` | `/api/v1/jornadas-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/modalidades-programa` | AUTHENTICATED | â€” |
| `POST` | `/api/v1/realtime/emit` | ROLES | Diagnostico: emite un tipo del catalogo con audiencia de la politica y payload JSON validados (CULM-001 D.9-c, F-TRX-016). |
| `GET` | `/api/v1/realtime/status` | ROLES | Diagnostico del canal; solo ADMINISTRADOR (CULM-001 D.9-c, F-TRX-016). |
| `GET` | `/api/v1/realtime/stream` | AUTHENTICATED | Ambito al suscribirse (SP): docente titular, estudiante con matricula activa, coordinador o decano con ambito sobre el grupo, administrador de la institucion; entrega por tipo segun RealtimeAudienciaPolicy. |
| `GET` | `/api/v1/sesiones/{sesionId}` | AUTHENTICATED | Docente titular, estudiante matriculado, coordinador del programa o decano de la facultad del grupo de la sesion (Application, InstitutionalScopePort); cualquier otro solicitante recibe 403. |
| `GET` | `/api/v1/tipos-identificacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-vinculacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/usuarios/perfil` | AUTHENTICATED | Solo el perfil del usuario autenticado; el procedimiento almacenado lee el ejecutor. |

### Rol: DECANO (48)

| MÃ©todo | Ruta | Tipo de Acceso | Ãmbito / Ownership |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/admin/areas` | ROLES | â€” |
| `GET` | `/api/v1/archivos/{fileId}` | AUTHENTICATED | Propietario del soporte: un no propietario recibe 404 (resuelto en Application). |
| `GET` | `/api/v1/auth/me` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/categorias-justificacion` | AUTHENTICATED | HU005/HU016: catalogo base de solo consulta (motivos para justificar una inasistencia); sin datos personales. |
| `GET` | `/api/v1/configuracion/identidad` | AUTHENTICATED | HU159: indica si la correccion del documento esta habilitada (parametro IDENTIDAD.PERMITIR_CORREGIR_DOCUMENTO); sin datos personales. |
| `GET` | `/api/v1/coordinador/asignaturas` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/periodos-academicos` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/planes-estudio` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/decano/aforo-grupos` | ROLES | Alcance de la facultad del decano autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/decano/asignaturas` | ROLES | HU143: el decano busca en su facultad y el administrador en su institucion; el ambito lo fuerza el procedimiento almacenado. |
| `POST` | `/api/v1/decano/cargas` | ROLES | HU171: Carga masiva de coordinadores por el decano; auditado. |
| `GET` | `/api/v1/decano/cargas/plantilla` | ROLES | HU171: Descarga de plantilla CSV de coordinadores para carga masiva. |
| `POST` | `/api/v1/decano/cargas/validacion` | ROLES | HU171: Validacion previa sin escrituras de carga masiva de coordinadores. |
| `GET` | `/api/v1/decano/comparativa-programas` | ROLES | Alcance de la facultad del decano autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/decano/consolidado-asistencia` | ROLES | HU061: grupos de la facultad del decano (administrador: su institucion); el ambito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/decano/coordinadores` | ROLES | Alcance de la facultad del decano autenticado. |
| `POST` | `/api/v1/decano/coordinadores` | ROLES | Alcance de la facultad del decano autenticado. |
| `PUT` | `/api/v1/decano/coordinadores/{id}` | ROLES | Alcance de la facultad del decano autenticado. |
| `PATCH` | `/api/v1/decano/coordinadores/{id}/estado` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/decano/docentes` | ROLES | HU128: docentes de la facultad del decano autenticado; el procedimiento almacenado exige el perfil DECANO. |
| `GET` | `/api/v1/decano/estructura` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/decano/estudiantes` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/decano/estudiantes/{estudianteId}` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/decano/estudiantes/{estudianteId}/historial` | ROLES | HU157: matriculas de la facultad del decano (o de la institucion del administrador); el ambito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/decano/grupos` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/decano/grupos/{grupoId}` | ROLES | CULM-001 D.9-a: grupo de la facultad del decano; inexistente o ajeno es 403 (usp_consultar_grupo_facultad_detalle). |
| `GET` | `/api/v1/decano/indicadores` | ROLES | Alcance de la facultad del decano autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/decano/planes-estudio/{planId}/asignaturas` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/decano/programas` | ROLES | Alcance de la facultad del decano autenticado. |
| `POST` | `/api/v1/decano/programas` | ROLES | Alcance de la facultad del decano autenticado. |
| `PUT` | `/api/v1/decano/programas/{id}` | ROLES | Alcance de la facultad del decano autenticado. |
| `PATCH` | `/api/v1/decano/programas/{id}/estado` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/decano/programas-creditos` | ROLES | HU112: programas de la facultad del decano autenticado; el procedimiento almacenado exige el perfil DECANO. |
| `GET` | `/api/v1/decano/revisiones-cancelacion` | ROLES | Consulta de todas las revisiones de los grupos de su facultad; no resuelve (SP, DEC-065). |
| `PATCH` | `/api/v1/decano/revisiones-cancelacion/{revisionId}` | ROLES | No resuelve: la decision final es del coordinador del programa; la DB responde RCN_016 (403) (DEC-065). |
| `GET` | `/api/v1/decano/sesiones` | ROLES | Alcance de la facultad del decano autenticado. |
| `GET` | `/api/v1/grupos/{grupoId}/programas` | ROLES | CULM-001 B2NM: titular del grupo o coordinador/decano con ambito sobre algun programa del grupo; lo fuerza usp_consultar_programas_grupo. |
| `POST` | `/api/v1/identidad/cuentas/acceso/consultas` | ROLES | Alcance en Application (AccesoCuentaService): administrador cualquiera; decano coordinadores, docentes y estudiantes de su facultad; coordinador docentes y estudiantes de su programa. Nunca asigna DECANO ni ADMINISTRADOR. |
| `POST` | `/api/v1/identidad/cuentas/acceso/reconciliaciones` | ROLES | Alcance en Application (AccesoCuentaService): administrador cualquiera; decano coordinadores, docentes y estudiantes de su facultad; coordinador docentes y estudiantes de su programa. Nunca asigna DECANO ni ADMINISTRADOR. |
| `GET` | `/api/v1/jornadas-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/modalidades-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/realtime/stream` | AUTHENTICATED | Ambito al suscribirse (SP): docente titular, estudiante con matricula activa, coordinador o decano con ambito sobre el grupo, administrador de la institucion; entrega por tipo segun RealtimeAudienciaPolicy. |
| `GET` | `/api/v1/sesiones/{sesionId}` | AUTHENTICATED | Docente titular, estudiante matriculado, coordinador del programa o decano de la facultad del grupo de la sesion (Application, InstitutionalScopePort); cualquier otro solicitante recibe 403. |
| `GET` | `/api/v1/tipos-identificacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-vinculacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/usuarios/perfil` | AUTHENTICATED | Solo el perfil del usuario autenticado; el procedimiento almacenado lee el ejecutor. |

### Rol: COORDINADOR (76)

| MÃ©todo | Ruta | Tipo de Acceso | Ãmbito / Ownership |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/admin/areas` | ROLES | â€” |
| `GET` | `/api/v1/archivos/{fileId}` | AUTHENTICATED | Propietario del soporte: un no propietario recibe 404 (resuelto en Application). |
| `POST` | `/api/v1/asistencias/consultas/grupo` | ROLES | Docente titular del grupo de la sesion; el estudiante solo sus propias asistencias/revisiones. |
| `GET` | `/api/v1/auth/me` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/categorias-justificacion` | AUTHENTICATED | HU005/HU016: catalogo base de solo consulta (motivos para justificar una inasistencia); sin datos personales. |
| `GET` | `/api/v1/configuracion/identidad` | AUTHENTICATED | HU159: indica si la correccion del documento esta habilitada (parametro IDENTIDAD.PERMITIR_CORREGIR_DOCUMENTO); sin datos personales. |
| `GET` | `/api/v1/configuracion/registro-estudiante` | ROLES | Configuracion publica del registro manual (dominio institucional vigente); sin datos personales. |
| `GET` | `/api/v1/coordinador/alertas-tempranas` | ROLES | Alcance del programa del coordinador autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/coordinador/asignaturas` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `PATCH` | `/api/v1/coordinador/asignaturas/{id}/estado` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/caracteres-asignatura` | ROLES | Catalogo de solo consulta sin ambito. |
| `POST` | `/api/v1/coordinador/cargas` | ROLES | HU171: Carga masiva de docentes por el coordinador de programa; auditado. |
| `GET` | `/api/v1/coordinador/cargas/plantilla` | ROLES | HU171: Descarga de plantilla CSV de docentes para carga masiva. |
| `POST` | `/api/v1/coordinador/cargas/validacion` | ROLES | HU171: Validacion previa sin escrituras de carga masiva de docentes. |
| `GET` | `/api/v1/coordinador/componentes-formacion` | ROLES | HU147: catalogo de componentes de formacion (BAS, INS, ESP); solo lectura. |
| `GET` | `/api/v1/coordinador/consolidado-asistencia` | ROLES | HU061: grupos del programa del coordinador (administrador: su institucion); el ambito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/coordinador/docentes` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `POST` | `/api/v1/coordinador/docentes` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `PUT` | `/api/v1/coordinador/docentes/{idDocente}` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `PATCH` | `/api/v1/coordinador/docentes/{idDocente}/estado` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/docentes/{idDocente}/ficha` | ROLES | Alcance del programa del coordinador autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/coordinador/docentes/candidatos` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/docentes/resumen` | ROLES | Alcance del programa del coordinador autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/coordinador/estudiantes` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/estudiantes/{idEstudiante}/bitacora` | ROLES | Alcance del programa del coordinador autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/coordinador/estudiantes/{idEstudiante}/ficha` | ROLES | Alcance del programa del coordinador autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `PUT` | `/api/v1/coordinador/estudiantes/{idEstudiante}/identidad` | ROLES | HU159: solo el COORDINADOR de un programa del estudiante (EstudiantePrograma) corrige documento, nombres y apellidos; el SP rechaza otro perfil o un estudiante fuera del programa. |
| `GET` | `/api/v1/coordinador/grupos` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/grupos/{grupoId}/sesiones` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/indicadores` | ROLES | Alcance del programa del coordinador autenticado; el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/coordinador/periodos-academicos` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/planes-estudio` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `POST` | `/api/v1/coordinador/planes-estudio` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `PUT` | `/api/v1/coordinador/planes-estudio/{id}` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `POST` | `/api/v1/coordinador/planes-estudio/{id}/asignaturas` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `POST` | `/api/v1/coordinador/planes-estudio/{id}/semestres` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `DELETE` | `/api/v1/coordinador/planes-estudio/{id}/semestres/{numero}` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `PATCH` | `/api/v1/coordinador/planes-estudio/{id}/toggle-estado` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `DELETE` | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | ROLES | CULM-001 B2NM: el plan debe ser de un programa del coordinador; lo fuerza usp_desvincular_asignatura_plan. |
| `PUT` | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `GET` | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas-asociables` | ROLES | CULM-001 B2NM: el plan debe ser de un programa del coordinador; lo fuerza el procedimiento almacenado. |
| `POST` | `/api/v1/coordinador/planes-estudio/{planId}/asignaturas-asociadas` | ROLES | CULM-001 B2NM: el plan debe ser de un programa del coordinador; lo fuerza usp_asociar_asignatura_plan. |
| `GET` | `/api/v1/coordinador/revisiones-cancelacion` | ROLES | Solo estudiantes con EstudiantePrograma en un programa del coordinador y del grupo (SP, DEC-020). |
| `PATCH` | `/api/v1/coordinador/revisiones-cancelacion/{revisionId}` | ROLES | Resolutor competente del programa del estudiante (SP; ajena = 404; no resuelve su propia propuesta). |
| `POST` | `/api/v1/coordinador/sesiones/{sesionId}/aprobacion` | ROLES | DEC-065 (2): coordinador de al menos uno de los programas del grupo de la sesion (SP; fuera de ambito = 403 SEC_002; sin solicitud = 409 SES_025; ya resuelta = 409 SES_024). |
| `GET` | `/api/v1/coordinador/sesiones/{sesionId}/asistencias` | ROLES | Alcance del programa del coordinador autenticado (InstitutionalScopePort / titularidad en SP). |
| `POST` | `/api/v1/coordinador/sesiones/{sesionId}/cancelacion` | ROLES | DEC-064: coordinador de al menos uno de los programas del grupo de la sesion y sesion creada manualmente por el docente (SP; fuera de ambito = 403 SEC_002; no manual = 409 SES_018). |
| `POST` | `/api/v1/coordinador/sesiones/{sesionId}/rechazo` | ROLES | DEC-065 (2): coordinador de al menos uno de los programas del grupo de la sesion (SP; fuera de ambito = 403 SEC_002; motivo fuera del catalogo = 400 SES_019; sin solicitud = 409 SES_025; ya resuelta = 409 SES_024). |
| `GET` | `/api/v1/coordinador/sesiones/motivos-cancelacion` | ROLES | DEC-064: catalogo de motivos de cancelacion de sesiones manuales; solo lectura, sin datos personales. |
| `GET` | `/api/v1/coordinador/sesiones/solicitudes` | ROLES | DEC-065 (2): solicitudes de sesion extraordinaria de los programas adscritos al coordinador autenticado; el ambito lo fuerza usp_consultar_solicitudes_sesion_coordinador_paginado. |
| `GET` | `/api/v1/docentes` | ROLES | Alcance del programa del coordinador. |
| `GET` | `/api/v1/docentes/{docenteId}` | ROLES | Alcance del programa del coordinador. |
| `GET` | `/api/v1/docentes/{docenteId}/asignaciones` | ROLES | Alcance del programa del coordinador. |
| `POST` | `/api/v1/docentes/consultas/asignaciones` | ROLES | Alcance del programa del coordinador. |
| `POST` | `/api/v1/docentes/consultas/id` | ROLES | Alcance del programa del coordinador. |
| `GET` | `/api/v1/estudiantes` | ROLES | Ambito en el SP usp_consultar_directorio_estudiantes_paginado (ADMINISTRADOR institucion, COORDINADOR programas, DOCENTE grupos propios). |
| `GET` | `/api/v1/estudiantes/{estudianteId}` | ROLES | Ambito en el SP usp_consultar_directorio_estudiantes_paginado (ADMINISTRADOR institucion, COORDINADOR programas, DOCENTE grupos propios). |
| `GET` | `/api/v1/grupos` | ROLES | DOCENTE solo grupos propios, COORDINADOR solo de su programa (Application + SP). |
| `POST` | `/api/v1/grupos` | ROLES | DEC-065 (4): solo el COORDINADOR crea grupos y solo de los programas de su coordinacion (Application + usp_crear_grupo, que exige el perfil COORDINADOR); DOCENTE y ADMINISTRADOR reciben 403. |
| `GET` | `/api/v1/grupos/{grupoId}/asistencias` | ROLES | CULM-001 A.2-2: ambito en el SP (DOCENTE titular, COORDINADOR del programa del grupo, ADMINISTRADOR de la institucion); grupo ajeno o inexistente 403. |
| `GET` | `/api/v1/grupos/{grupoId}/estudiantes` | ROLES | CULM-001 A.2-2: ambito en el SP (DOCENTE titular, COORDINADOR del programa del grupo, ADMINISTRADOR de la institucion); grupo ajeno o inexistente 403. |
| `POST` | `/api/v1/grupos/{grupoId}/estudiantes/{estudianteId}/reenviar-verificacion` | ROLES | Docente titular del grupo o coordinador de su programa (usp_consultar_reenvio_verificacion_correo); un estudiante ajeno recibe 404. |
| `GET` | `/api/v1/grupos/{grupoId}/programas` | ROLES | CULM-001 B2NM: titular del grupo o coordinador/decano con ambito sobre algun programa del grupo; lo fuerza usp_consultar_programas_grupo. |
| `GET` | `/api/v1/grupos/{grupoId}/reportes/asistencia-excel` | ROLES | DOCENTE solo grupos propios, COORDINADOR solo de su programa (Application + SP). |
| `PUT` | `/api/v1/grupos/{id}` | ROLES | DOCENTE solo grupos propios, COORDINADOR solo de su programa (Application + SP). |
| `POST` | `/api/v1/identidad/cuentas/acceso/consultas` | ROLES | Alcance en Application (AccesoCuentaService): administrador cualquiera; decano coordinadores, docentes y estudiantes de su facultad; coordinador docentes y estudiantes de su programa. Nunca asigna DECANO ni ADMINISTRADOR. |
| `POST` | `/api/v1/identidad/cuentas/acceso/reconciliaciones` | ROLES | Alcance en Application (AccesoCuentaService): administrador cualquiera; decano coordinadores, docentes y estudiantes de su facultad; coordinador docentes y estudiantes de su programa. Nunca asigna DECANO ni ADMINISTRADOR. |
| `GET` | `/api/v1/jornadas-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/modalidades-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/realtime/stream` | AUTHENTICATED | Ambito al suscribirse (SP): docente titular, estudiante con matricula activa, coordinador o decano con ambito sobre el grupo, administrador de la institucion; entrega por tipo segun RealtimeAudienciaPolicy. |
| `GET` | `/api/v1/sesiones/{sesionId}` | AUTHENTICATED | Docente titular, estudiante matriculado, coordinador del programa o decano de la facultad del grupo de la sesion (Application, InstitutionalScopePort); cualquier otro solicitante recibe 403. |
| `GET` | `/api/v1/tipos-identificacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-vinculacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/usuarios/perfil` | AUTHENTICATED | Solo el perfil del usuario autenticado; el procedimiento almacenado lee el ejecutor. |

### Rol: DOCENTE (59)

| MÃ©todo | Ruta | Tipo de Acceso | Ãmbito / Ownership |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/archivos/{fileId}` | AUTHENTICATED | Propietario del soporte: un no propietario recibe 404 (resuelto en Application). |
| `POST` | `/api/v1/asistencias/consultas/grupo` | ROLES | Docente titular del grupo de la sesion; el estudiante solo sus propias asistencias/revisiones. |
| `POST` | `/api/v1/asistencias/lote` | ROLES | Docente titular del grupo de la sesion; el estudiante solo sus propias asistencias/revisiones. |
| `GET` | `/api/v1/auth/me` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/categorias-justificacion` | AUTHENTICATED | HU005/HU016: catalogo base de solo consulta (motivos para justificar una inasistencia); sin datos personales. |
| `GET` | `/api/v1/configuracion/identidad` | AUTHENTICATED | HU159: indica si la correccion del documento esta habilitada (parametro IDENTIDAD.PERMITIR_CORREGIR_DOCUMENTO); sin datos personales. |
| `GET` | `/api/v1/configuracion/reclamos` | ROLES | CULM-001 D.2 (HU015): configuración institucional del formulario de reclamos (tope de soportes, tamaño y tipos de archivo, límite de subidas, días del plazo); sin datos personales, el procedimiento almacenado valida el rol. |
| `GET` | `/api/v1/configuracion/registro-estudiante` | ROLES | Configuracion publica del registro manual (dominio institucional vigente); sin datos personales. |
| `GET` | `/api/v1/docente/asignaturas` | ROLES | Titularidad del docente autenticado (Usuario->Docente del token): solo sus grupos, sesiones y reclamos; la DB y Application validan el grupo. |
| `POST` | `/api/v1/docente/grupos/{grupoId}/estudiantes/{estudianteId}/retiro` | ROLES | Titularidad del docente autenticado (Usuario->Docente del token): solo sus grupos, sesiones y reclamos; la DB y Application validan el grupo. |
| `GET` | `/api/v1/docente/grupos/{grupoId}/resumen-asistencia` | ROLES | CULM-001 B.2: docente titular del grupo (Application + SP). |
| `GET` | `/api/v1/docente/horarios` | ROLES | Titularidad del docente autenticado (Usuario->Docente del token): solo sus grupos, sesiones y reclamos; la DB y Application validan el grupo. |
| `GET` | `/api/v1/docente/reclamos` | ROLES | Titularidad del docente autenticado (Usuario->Docente del token): solo sus grupos, sesiones y reclamos; la DB y Application validan el grupo. |
| `GET` | `/api/v1/docente/reclamos/{id}` | ROLES | Titularidad del docente autenticado (Usuario->Docente del token): solo sus grupos, sesiones y reclamos; la DB y Application validan el grupo. |
| `PATCH` | `/api/v1/docente/reclamos/{id}` | ROLES | Titularidad del docente autenticado (Usuario->Docente del token): solo sus grupos, sesiones y reclamos; la DB y Application validan el grupo. |
| `GET` | `/api/v1/docente/revisiones-cancelacion` | ROLES | Solo grupos donde es titular (SP usp_consultar_revisiones_cancelacion_docente_paginado; grupo ajeno = SEC_002; DEC-065). |
| `PATCH` | `/api/v1/docente/revisiones-cancelacion/{revisionId}` | ROLES | Docente titular del grupo de la revision (SP; ajena = 404). |
| `PATCH` | `/api/v1/docente/sesiones/{sesionId}/cancelar` | ROLES | Titularidad del docente autenticado (Usuario->Docente del token): solo sus grupos, sesiones y reclamos; la DB y Application validan el grupo. |
| `GET` | `/api/v1/estudiantes` | ROLES | Ambito en el SP usp_consultar_directorio_estudiantes_paginado (ADMINISTRADOR institucion, COORDINADOR programas, DOCENTE grupos propios). |
| `GET` | `/api/v1/estudiantes/{estudianteId}` | ROLES | Ambito en el SP usp_consultar_directorio_estudiantes_paginado (ADMINISTRADOR institucion, COORDINADOR programas, DOCENTE grupos propios). |
| `GET` | `/api/v1/grupos/{grupoId}/asistencias` | ROLES | CULM-001 A.2-2: ambito en el SP (DOCENTE titular, COORDINADOR del programa del grupo, ADMINISTRADOR de la institucion); grupo ajeno o inexistente 403. |
| `GET` | `/api/v1/grupos/{grupoId}/estudiantes` | ROLES | CULM-001 A.2-2: ambito en el SP (DOCENTE titular, COORDINADOR del programa del grupo, ADMINISTRADOR de la institucion); grupo ajeno o inexistente 403. |
| `POST` | `/api/v1/grupos/{grupoId}/estudiantes` | ROLES | Solo el DOCENTE titular del grupo (SP: perfil DOCENTE y titularidad GRUPO, SEC_002). F-COO-004: el coordinador no matricula. |
| `POST` | `/api/v1/grupos/{grupoId}/estudiantes/{estudianteId}/reenviar-verificacion` | ROLES | Docente titular del grupo o coordinador de su programa (usp_consultar_reenvio_verificacion_correo); un estudiante ajeno recibe 404. |
| `GET` | `/api/v1/grupos/{grupoId}/estudiantes/busqueda` | ROLES | DEC-027: solo el docente titular del grupo; documento exacto y datos mínimos (usp_buscar_estudiante_por_documento_grupo). |
| `DELETE` | `/api/v1/grupos/{grupoId}/matricula-qr` | ROLES | Docente titular del grupo (Application + SP: RBAC DOCENTE y titularidad); el token solo viaja en la respuesta y en el SSE del titular. |
| `POST` | `/api/v1/grupos/{grupoId}/matricula-qr` | ROLES | Docente titular del grupo (Application + SP: RBAC DOCENTE y titularidad); el token solo viaja en la respuesta y en el SSE del titular. |
| `POST` | `/api/v1/grupos/{grupoId}/matricula-qr/rotacion` | ROLES | Docente titular del grupo (Application + SP: RBAC DOCENTE y titularidad); el token solo viaja en la respuesta y en el SSE del titular. |
| `GET` | `/api/v1/grupos/{grupoId}/programas` | ROLES | CULM-001 B2NM: titular del grupo o coordinador/decano con ambito sobre algun programa del grupo; lo fuerza usp_consultar_programas_grupo. |
| `GET` | `/api/v1/grupos/{grupoId}/reportes/asistencia-excel` | ROLES | DOCENTE solo grupos propios, COORDINADOR solo de su programa (Application + SP). |
| `GET` | `/api/v1/jornadas-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/modalidades-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/realtime/stream` | AUTHENTICATED | Ambito al suscribirse (SP): docente titular, estudiante con matricula activa, coordinador o decano con ambito sobre el grupo, administrador de la institucion; entrega por tipo segun RealtimeAudienciaPolicy. |
| `POST` | `/api/v1/sesiones` | ROLES | â€” |
| `GET` | `/api/v1/sesiones/{sesionId}` | AUTHENTICATED | Docente titular, estudiante matriculado, coordinador del programa o decano de la facultad del grupo de la sesion (Application, InstitutionalScopePort); cualquier otro solicitante recibe 403. |
| `PATCH` | `/api/v1/sesiones/{sesionId}` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort). |
| `PUT` | `/api/v1/sesiones/{sesionId}` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort). |
| `GET` | `/api/v1/sesiones/{sesionId}/tomas` | ROLES | CULM-001 B.2: docente titular de la sesion (Application + SP: RBAC DOCENTE y titularidad). |
| `POST` | `/api/v1/sesiones/{sesionId}/tomas` | ROLES | CULM-001 B.2: docente titular de la sesion (Application + SP: RBAC DOCENTE y titularidad). |
| `GET` | `/api/v1/sesiones/{sesionId}/tomas/resumen` | ROLES | Puntos de control: docente titular de la sesion (Application + SP: RBAC DOCENTE y titularidad). |
| `POST` | `/api/v1/sesiones/cierres` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort). |
| `POST` | `/api/v1/sesiones/consultas` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort). |
| `GET` | `/api/v1/sesiones/grupo/{grupoId}` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort). |
| `POST` | `/api/v1/sesiones/grupo/{grupoId}/generacion` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort). |
| `GET` | `/api/v1/tipos-identificacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-vinculacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tomas/{tomaId}/asistencias` | ROLES | CULM-001 B.2: docente titular de la sesion de la toma (Application + SP). |
| `POST` | `/api/v1/tomas/{tomaId}/asistencias` | ROLES | CULM-001 B.2: docente titular de la sesion de la toma (Application + SP). |
| `POST` | `/api/v1/tomas/{tomaId}/cierre` | ROLES | CULM-001 B.2: docente titular de la sesion de la toma (Application + SP). |
| `GET` | `/api/v1/tomas/{tomaId}/faltantes` | ROLES | CULM-001 B.2: docente titular de la sesion de la toma (Application + SP). |
| `DELETE` | `/api/v1/tomas/{tomaId}/qr` | ROLES | CULM-001 B.2: docente titular de la sesion de la toma (Application + SP). |
| `POST` | `/api/v1/tomas/{tomaId}/qr` | ROLES | CULM-001 B.2: docente titular de la sesion de la toma; el token solo viaja en la respuesta y en el SSE del titular. |
| `POST` | `/api/v1/tomas/{tomaId}/qr/rotacion` | ROLES | CULM-001 B.2: docente titular de la sesion de la toma; el token solo viaja en la respuesta y en el SSE del titular. |
| `GET` | `/api/v1/usuarios/perfil` | AUTHENTICATED | Solo el perfil del usuario autenticado; el procedimiento almacenado lee el ejecutor. |
| `POST` | `/api/v2/sesiones` | ROLES | â€” |
| `GET` | `/api/v2/sesiones/{sesionId}` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort) y en usp_*_sesion_v2. |
| `PATCH` | `/api/v2/sesiones/{sesionId}` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort) y en usp_*_sesion_v2. |
| `GET` | `/api/v2/sesiones/grupo/{grupoId}` | ROLES | Docente titular del grupo/sesion: validado en Application (InstitutionalScopePort) y en usp_*_sesion_v2. |

### Rol: ESTUDIANTE (25)

| MÃ©todo | Ruta | Tipo de Acceso | Ãmbito / Ownership |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/archivos/{fileId}` | AUTHENTICATED | Propietario del soporte: un no propietario recibe 404 (resuelto en Application). |
| `POST` | `/api/v1/archivos/subir` | ROLES | Propietario del soporte: un no propietario recibe 404 (resuelto en Application). |
| `POST` | `/api/v1/asistencias/revisiones` | ROLES | Docente titular del grupo de la sesion; el estudiante solo sus propias asistencias/revisiones. |
| `GET` | `/api/v1/auth/me` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/categorias-justificacion` | AUTHENTICATED | HU005/HU016: catalogo base de solo consulta (motivos para justificar una inasistencia); sin datos personales. |
| `GET` | `/api/v1/configuracion/identidad` | AUTHENTICATED | HU159: indica si la correccion del documento esta habilitada (parametro IDENTIDAD.PERMITIR_CORREGIR_DOCUMENTO); sin datos personales. |
| `GET` | `/api/v1/configuracion/reclamos` | ROLES | CULM-001 D.2 (HU015): configuración institucional del formulario de reclamos (tope de soportes, tamaño y tipos de archivo, límite de subidas, días del plazo); sin datos personales, el procedimiento almacenado valida el rol. |
| `GET` | `/api/v1/estudiante/alertas` | ROLES | Solo las alertas de las matriculas del estudiante autenticado (SP). |
| `POST` | `/api/v1/estudiante/asistencia-qr` | ROLES | CULM-001 B.2: solo el estudiante autenticado; exige red del campus, interruptor y limites por IP (solo intentos rechazados), por token y por estudiante; matricula activa en el grupo de la toma (SP). |
| `GET` | `/api/v1/estudiante/horarios` | ROLES | Solo datos del estudiante autenticado (Usuario->Estudiante del token). |
| `GET` | `/api/v1/estudiante/materias` | ROLES | Solo datos del estudiante autenticado (Usuario->Estudiante del token). |
| `GET` | `/api/v1/estudiante/materias/{materiaId}/sesiones` | ROLES | Solo la matricula inscrita del estudiante autenticado: el SP usp_consultar_sesiones_materia_estudiante resuelve el ambito, pagina (pagina y tamano opcionales) y entrega la fecha limite de justificacion (CULM-001 D.1). |
| `POST` | `/api/v1/estudiante/matricular-grupo` | ROLES | Solo datos del estudiante autenticado (Usuario->Estudiante del token). |
| `GET` | `/api/v1/estudiante/oferta-academica` | ROLES | Programas del estudiante autenticado (EstudiantePrograma); el ámbito lo fuerza el procedimiento almacenado. |
| `GET` | `/api/v1/estudiante/plan-estudio` | ROLES | HU018: solo los planes activos de los programas del estudiante autenticado (EstudiantePrograma); el ámbito lo fuerza usp_consultar_plan_estudio_estudiante. |
| `GET` | `/api/v1/estudiante/reclamos` | ROLES | Solo datos del estudiante autenticado (Usuario->Estudiante del token). |
| `DELETE` | `/api/v1/estudiante/reclamos/{id}` | ROLES | CULM-001 A.2-7: solo el reclamo propio y pendiente del estudiante autenticado (usp_retirar_solicitud_revision_asistencia: REV_006 404, REV_007 409). |
| `GET` | `/api/v1/jornadas-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/modalidades-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/realtime/stream` | AUTHENTICATED | Ambito al suscribirse (SP): docente titular, estudiante con matricula activa, coordinador o decano con ambito sobre el grupo, administrador de la institucion; entrega por tipo segun RealtimeAudienciaPolicy. |
| `GET` | `/api/v1/sesiones/{sesionId}` | AUTHENTICATED | Docente titular, estudiante matriculado, coordinador del programa o decano de la facultad del grupo de la sesion (Application, InstitutionalScopePort); cualquier otro solicitante recibe 403. |
| `GET` | `/api/v1/tipos-identificacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-programa` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/tipos-vinculacion` | AUTHENTICATED | â€” |
| `GET` | `/api/v1/usuarios/perfil` | AUTHENTICATED | Solo el perfil del usuario autenticado; el procedimiento almacenado lee el ejecutor. |

## Endpoints Exentos del PEP (PÃºblicos / IntegraciÃ³n)

| MÃ©todo | Ruta | Motivo / JustificaciÃ³n |
| :--- | :--- | :--- |
| `POST` | `/api/v1/internal/azure-events` | Webhook de Azure Event Grid: autenticado por AzureEventGridAuthFilter (aeg-sas-token), fuera del PEP. |
| `POST` | `/api/v1/public/matricula-qr/registro` | HU176B: alta publica y matricula por QR/PIN; la credencial es el token/PIN rotativo. Exige red del campus, interruptor, correo institucional y limite de intentos por IP. No devuelve token de sesion. |
| `POST` | `/api/v1/public/matricula-qr/validar` | HU176B: validacion publica de la matricula por QR/PIN; la credencial es el token/PIN rotativo (SHA-256 en BD, vigencia por parametros). Exige red del campus, interruptor y limite de intentos por IP (MatriculaQrRateLimitFilter); responde solo los datos minimos del curso y un error generico MQR_001 para cualquier token invalido. |
| `POST` | `/api/v1/public/verificar-correo` | IDENT-001: verificacion publica del correo; la credencial es el token de un solo uso del enlace (SHA-256 en BD, vigencia por parametro) y la ruta tiene limite de intentos por IP (VerificacionCorreoRateLimitFilter). Sin datos personales en la respuesta. |

