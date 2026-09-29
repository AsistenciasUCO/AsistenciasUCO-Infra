# 📊 Matriz Integral de Historias de Usuario por Capas y Fases SDD — GestioAsistencia UCO
> **Ecosistema:** Plataforma Institucional de Gestión y Control de Asistencia UCO  
> **Versión de Matriz:** 3.1.0 (Aislamiento Jerárquico en SPs, Consultas Paginadas vía SP ➔ Vista, Wi-Fi Campus y Matrícula QR)  
> **Ámbito:** Matriz de trazabilidad técnica por capas y estado de ciclo de vida del pipeline SDD.  
> **Fecha de Actualización:** Septiembre 2026

---

## Índice de Módulos
1. [Reglas Técnicas y Convenciones del Pipeline SDD](#reglas-técnicas-y-convenciones-del-pipeline-sdd)
2. [1. Módulo Estudiante (HU001 – HU026, HU026B, HU026C)](#1-módulo-estudiante)
3. [2. Módulo Docente (HU027 – HU059)](#2-módulo-docente)
4. [3. Módulo Coordinación de Programa (HU060 – HU098)](#3-módulo-coordinación-de-programa)
5. [4. Módulo Decanatura y Gobierno Institucional (HU076-HU078, HU099 – HU146)](#4-módulo-decanatura-y-gobierno-institucional)
6. [5. Módulo Administración del Sistema y Catálogos Transversales (HU147 – HU174)](#5-módulo-administración-del-sistema-y-catálogos-transversales)
7. [6. Módulo Especial: Auto-Asistencia, Matrícula QR y Métodos Autónomos (HU175 – HU176B)](#6-módulo-especial-auto-asistencia-matrícula-qr-y-métodos-autónomos)
8. [Documentos Relacionados](#documentos-relacionados)

---

## Reglas Técnicas y Convenciones del Pipeline SDD

### 🛑 Reglas Inviolables de Dominio y Persistencia:
1. **Consultas Obligatorias vía SP ➔ Vista (Paginadas y Filtradas):** Queda prohibido que el Backend ejecute `SELECT` directo contra vistas o tablas. Toda consulta de lectura se encapsula en un **Procedimiento Almacenado de Consulta (`usp_consultar_*`) que internamente invoca a la vista (`uv_*`)**, recibiendo `@numeroPagina`, `@tamanoPagina`, filtros tipados, y retornando `OFFSET ... ROWS FETCH NEXT ... ROWS ONLY` junto con `COUNT(*) OVER() AS totalRegistros`.
2. **Aislamiento Jerárquico en Procedimientos Almacenados (Seguridad en BD):**
   * **Docente:** Solo puede visualizar y operar grupos donde es titular formal. No puede ver grupos ajenos.
   * **Coordinador:** Solo puede visualizar grupos, docentes y alumnos de su programa académico adscrito.
   * **Decano:** Solo puede visualizar entidades de su facultad.
   * *Esta validación de titularidad y ámbito debe forzarse obligatoriamente DENTRO de los procedimientos almacenados.*
3. **Asistencia Exclusiva del Docente:** El registro y modificación de asistencia es potestad **exclusiva del docente titular**. Ni el Coordinador ni el Decano pueden alterar o registrar asistencias (su acceso es 100% de solo lectura y auditoría).
4. **Matrícula vía QR o Manual por Docente (Cero Sincronización Externa):** La matrícula de alumnos no depende de sincronizaciones automáticas externas; se realiza mediante: a) **Código QR de matrícula** generado por el profesor en clase (crea la cuenta de usuario y matricula al alumno en el grupo), o b) **Registro manual** ejecutado por el docente en su grupo.
5. **Validación de Red Wi-Fi Institucional en Auto-Registro:** La marcación autónoma por QR o PIN valida obligatoriamente que el estudiante esté conectado a la **red Wi-Fi del campus UCO**.
6. **Resolución Definitiva de Excusas (Trámite Externo de Apelaciones):** La decisión del docente al aprobar o rechazar una justificación es definitiva dentro de la plataforma. Si se rechaza, cualquier controversia o apelación se gestiona de forma **externa al sistema** mediante el conducto regular universitario.

### Convenciones de Fases:
* **`[CERTIFICADA]`**: Verificada y aprobada en las 4 capas de pruebas por el Gatekeeper.
* **`Fase 3 (FRONTEND)`**: SP probado en DB y API REST en Backend listos; en construcción de vista Standalone OnPush con Signals.
* **`Fase 2 (BACKEND)`**: SP probado en Docker (SQL Server); en desarrollo de puertos, adaptadores y controladores. *(Nota: Si el SP no existe en DB, la historia no puede estar en Fase 2 y debe permanecer en `[PENDIENTE]` o `Fase 1 (DB)`)*.
* **`Fase 1 (DB)`**: Contratos WORM congelados; en codificación de SPs atómicos con `SET XACT_ABORT ON;`.
* **`[PARCIAL]`**: Soporte preliminar en refinamiento técnico con persistencia base.
* **`[PENDIENTE]`**: Catalogada lista para inicio en pipeline (pendiente diseño o creación de SP).

---

## 1. Módulo Estudiante

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU001** | Ver detalles de asistencias por materia | SP `usp_consultar_asistencias_estudiante` (usa `uv_asistencias`) | `GET /estudiante/materias` | `StudentCoursesComponent` (`/app/estudiante/materias`) | `[CERTIFICADA]` |
| **HU002** | Consultar registros históricos de asistencia | SP `usp_consultar_historial_sesiones_estudiante` | `GET /estudiante/materias/{id}/sesiones` | `StudentCoursesComponent` (`/app/estudiante/materias`) | `[CERTIFICADA]` |
| **HU003** | Ver lista de compañeros matriculados en grupo | SP `usp_consultar_estudiantes_grupo` (paginado) | `GET /grupos/{grupoId}/estudiantes` | Modal en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU004** | Consultar estado de permanencia (Regla 20%) | Función `ufn_calcular_porcentaje_inasistencia` | Cálculo umbral 20% en `EstudiantePortalController` | Badge dinámico en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU005** | Consultar causales normativas de justificación | SP `usp_consultar_motivos_justificacion` | `GET /catalogo/motivos-justificacion` | Modal de reclamos en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU006** | Consultar perfil y ficha de información personal | SP `usp_consultar_perfil_usuario` | `GET /usuarios/perfil` | `ProfileComponent` (`/app/perfil`) | `[CERTIFICADA]` |
| **HU007** | Búsqueda y filtrado de materias matriculadas | SP `usp_consultar_materias_estudiante` (filtros) | `GET /estudiante/materias` con query params | Filtros con Signals en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU008** | Consultar información de grupos y cupos | SP `usp_consultar_oferta_grupos` (paginado) | `GET /grupos/oferta-academica` | Selector de cursos en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU009** | Barra consolidada de porcentaje de inasistencia | Función agregada de horas inasistidas | DTO consolidado con tasa de faltas | `ProgressBarComponent` reactivo con Signals | `[CERTIFICADA]` |
| **HU010** | Radicar solicitud de revisión / reclamo | SP `usp_radicar_solicitud_revision_asistencia` | `POST /api/v1/asistencias/revisiones` | Formulario reactivo en `StudentCoursesComponent` | `Fase 3 (FRONTEND)` |
| **HU011** | Adjuntar soporte individual a solicitud | Campo `soporteUrl` en tabla `SolicitudRevision` | Servicio de subida de archivos `/archivos/subir` | Carga de archivo en modal de reclamo | `Fase 3 (FRONTEND)` |
| **HU012** | Consultar historial de reclamos radicados | SP `usp_consultar_solicitudes_estudiante` (pendiente SP) | `GET /api/v1/estudiante/reclamos` (bloqueado por DB) | Tabla de estados de reclamo con Signals | `[PENDIENTE]` |
| **HU013** | Alerta visual de riesgo de pérdida (15% - 20%) | Cálculo analítico de porcentaje acumulado | DTO con flag de alerta temprana | Resaltado semafórico en tarjetas de materia | `[CERTIFICADA]` |
| **HU014** | Formulario especializado para justificación médica | Validación de tipo causal médica en SP | Validación de DTO médico en Backend | Formulario específico de justificación médica | `Fase 3 (FRONTEND)` |
| **HU015** | Carga y almacenamiento seguro de múltiples soportes | Tabla relacional `SolicitudRevisionSoporte` | Servicio de almacenamiento con SAS Tokens | Drag-and-drop múltiple en `StudentCoursesComponent` | `[PARCIAL]` |
| **HU016** | Visualización de causales y reglamento estudiantil | SP `usp_consultar_parametros_generales` | `GET /admin/parametros/reglamento` | Tooltip y modal informativo de causales UCO | `[CERTIFICADA]` |
| **HU017** | Consultar sesiones de clase programadas | SP `usp_consultar_sesiones_estudiante` | `GET /estudiante/horarios` | `StudentScheduleComponent` (`/app/estudiante/horarios`)| `[CERTIFICADA]` |
| **HU018** | Consultar estructura curricular de semestres | SP `usp_consultar_malla_curricular` | `GET /estudiante/materias` (malla) | Vista en acordeón de semestres cursados | `[CERTIFICADA]` |
| **HU019** | Consultar créditos y plan de estudios | SP `usp_consultar_creditos_estudiante` | Endpoint de créditos y avance académico | Barra de créditos aprobados vs totales | `[CERTIFICADA]` |
| **HU020** | Consultar sede, aula y bloque por sesión | SP `usp_consultar_horarios_aulas` | DTO con ubicación física de sesión | Tarjeta de sesión con geolocalización de aula | `[CERTIFICADA]` |
| **HU021** | Filtro de horario semanal por días lectivos | SP con parámetro `@diaSemana` filtrado | `GET /estudiante/horarios?dia=...` | Selector reactivo de días (Lunes a Sábado) | `[CERTIFICADA]` |
| **HU022** | Consumo transversal de tipos de identificación | SP `usp_consultar_tipos_identificacion` | `GET /api/v1/tipos-identificacion` | `FormFieldComponent` en perfil | `[CERTIFICADA]` |
| **HU023** | Consumo transversal de tipos de programa | SP `usp_consultar_tipos_programa` | `GET /api/v1/tipos-programa` | Badges de pregrado/posgrado en materias | `[CERTIFICADA]` |
| **HU024** | Consumo transversal de estados de asistencia | SP `usp_consultar_estados_asistencia` | `GET /api/v1/estados-asistencia` | Leyenda de estados (Presente, Falta, Justificada) | `[CERTIFICADA]` |
| **HU025** | Consultar prerrequisitos y correquisitos | SP `usp_consultar_prerrequisitos_asignatura` (no modelado) | `GET /estudiante/materias/{id}/prerrequisitos` (bloqueado DB) | Grafo/Lista de prerrequisitos de asignatura | `[PENDIENTE]` |
| **HU026** | Solicitud de inscripción o matrícula por QR | SP `usp_matricular_estudiante_qr_autonomo` (pendiente SP) | `POST /estudiante/solicitudes-matricula` | Escaneo de QR de curso compartido por profesor | `[PENDIENTE]` |
| **HU026B**| Validación de plazo perentorio (5 días) para excusas | SP `usp_radicar_solicitud_revision_asistencia` | Regla de negocio en `RadicarReclamoUseCase` | Bloqueo automático de formulario extemporáneo | `[PENDIENTE]` |
| **HU026C**| Notificaciones proactivas de ausentismo (15% y 20%) | SP `usp_consultar_estudiantes_en_riesgo` | Job batch + SSE (`SseRealtimeAdapter`) + Email | Toast de notificación y panel de alertas en vivo | `[PENDIENTE]` |

---

## 2. Módulo Docente

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU027** | Registrar asistencia individual de estudiante | SP `usp_registrar_asistencia_estudiante` (exclusivo docente)| `POST /api/v1/asistencias` (hexagonal) | `AttendanceControlComponent` (`/app/asistencia`) | `[CERTIFICADA]` |
| **HU028** | Abrir/iniciar sesión de clase | SP `usp_crear_sesion` (valida titularidad en SP) | `POST /api/v1/sesiones` | Botón "Iniciar Clase" en `AttendanceControlComponent` | `[CERTIFICADA]` |
| **HU029** | Consultar planilla completa de asistencia | SP `usp_consultar_planilla_sesion` (llama `uv_planilla`) | `GET /grupos/{id}/asistencias` | Tabla de planilla en `AttendanceControlComponent` | `[CERTIFICADA]` |
| **HU030** | Programar sesión ordinaria o extraordinaria | SP `usp_crear_sesion` con tipo de clase | `POST /api/v1/sesiones` | Modal de nueva sesión en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU031** | Consultar grupos asignados (Aislamiento de titularidad)| SP `usp_consultar_grupos_docente` (SOLO sus grupos)| `GET /grupos/docente` | `TeacherGruposComponent` (`/app/docente/grupos`) | `[CERTIFICADA]` |
| **HU032** | Consultar padrón de estudiantes de su grupo | SP `usp_consultar_estudiantes_matriculados` | `GET /grupos/{id}/estudiantes` | Pestaña "Padrón" en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU033** | Modificar estado de asistencia registrada | SP `usp_registrar_asistencia_estudiante` (exclusivo docente)| `POST /api/v1/asistencias` (actualización) | Selector interactivo de estado por estudiante | `[CERTIFICADA]` |
| **HU034** | Validación preventiva de solapamiento de horarios | SP `usp_validar_cruce_horario_docente_interno` | Validación en `SesionUseCase` | Mensaje de advertencia ante conflicto horario | `[CERTIFICADA]` |
| **HU035** | Consultar solicitudes de revisión pendientes | SP `usp_consultar_reclamos_docente` (pendiente SP) | `GET /api/v1/docente/reclamos` (bloqueado por DB) | `TeacherClaimsComponent` (`/app/docente/reclamos`) | `[PENDIENTE]` |
| **HU036** | Consultar detalle y causal de una solicitud | SP `usp_consultar_detalle_reclamo` (pendiente SP) | DTO con detalle completo de causal | Modal de detalle en `TeacherClaimsComponent` | `[PENDIENTE]` |
| **HU037** | Resolver justificación de inasistencia (Definitiva en app)| SP `usp_resolver_solicitud_revision_asistencia` | `PATCH /api/v1/docente/reclamos/{id}` | Botones Aprobar/Rechazar (rechazo escala externamente)| `Fase 3 (FRONTEND)` |
| **HU038** | Ingresar observación o retroalimentación obligatoria | Parámetro `@respuestaDocente` en SP | Campo `respuestaDocente` en DTO de resolución | Área de texto para observaciones al estudiante | `Fase 3 (FRONTEND)` |
| **HU039** | Visualizar y descargar soporte médico adjunto | URL de soporte registrada en la solicitud | Servicio de proxy/descarga de soporte seguro | Visor de documentos en `TeacherClaimsComponent` | `Fase 3 (FRONTEND)` |
| **HU040** | Consultar tasa acumulada de ausentismo por grupo | SP `usp_consultar_tasa_ausentismo_grupo` | DTO con tasas agregadas de asistencia | Métricas superiores en `AttendanceControlComponent` | `[CERTIFICADA]` |
| **HU041** | Resaltado visual semafórico de alumnos en riesgo | SP de consulta proyecta campo `enRiesgo` | Campo booleano `enRiesgo` en DTO de planilla | Fila resaltada en rojo/amarillo en la planilla | `[CERTIFICADA]` |
| **HU042** | Auditoría y notificación de resolución de reclamo | Registro en `AuditoriaEvento` en base de datos | Emisión de evento SSE de resolución | Notificación reactiva al estudiante en tiempo real | `[CERTIFICADA]` |
| **HU043** | Consultar políticas de asistencia y aforo de grupo | SP `usp_consultar_configuracion_grupo` | DTO de configuración del grupo | Pestaña de configuración en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU044** | Editar aforo y observaciones operativas | SP `usp_actualizar_grupo` | `PUT /api/v1/grupos/{id}` | Formulario de edición en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU045** | Programar nueva sesión de clase en cronograma | SP `usp_crear_sesion` | `POST /api/v1/sesiones` | Calendario de sesiones en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU046** | Reprogramar fecha y hora de sesión | SP `usp_actualizar_sesion` | `PUT /api/v1/sesiones/{id}` | Modal de reprogramación en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU047** | Cancelar sesión de clase con justificación | SP de cancelación con motivo registrado (pendiente SP) | `PATCH /docente/sesiones/{id}/cancelar` (bloqueado por DB) | Diálogo de confirmación con campo de causal | `[PENDIENTE]` |
| **HU048** | Configurar horarios semanales de clase | SP `usp_actualizar_sesion` | `PUT /api/v1/sesiones/{id}` | Selector horario semanal en grupo | `[CERTIFICADA]` |
| **HU049** | Modificar horario y aula de sesión programada | SP `usp_actualizar_sesion` | `PUT /api/v1/sesiones/{id}` | Edición rápida de aula y hora de inicio/fin | `[CERTIFICADA]` |
| **HU050** | Matrícula o registro manual del estudiante por docente | SP usp_registrar_estudiante_en_grupo | POST /api/v1/grupos/{id}/estudiantes | AttendanceEnrollmentModalComponent (Signals + autocompletado) | [CERTIFICADA] |
| **HU051** | Notificar baja o deserción de estudiante | Registro de novedad de cursada en DB (pendiente SP) | `POST /docente/grupos/{id}/novedades` (bloqueado por DB) | Notificación directa a Coordinación de Programa | `[PENDIENTE]` |
| **HU052** | Consultar padrón con filtros predictivos | SP `usp_consultar_padron_docente` (paginado) | DTO paginado con metadatos de total registros | Buscador predictivo en padrón docente | `[CERTIFICADA]` |
| **HU053** | Consultar postulaciones de ingreso al curso | SP `usp_consultar_solicitudes_matricula_grupo` (pendiente SP)| `GET /docente/grupos/{id}/solicitudes` (bloqueado por DB) | Lista de solicitudes de unión al grupo | `[PENDIENTE]` |
| **HU054** | Emitir concepto docente sobre postulación | SP de actualización de estado de postulación (pendiente SP)| `PATCH /docente/solicitudes/{id}/concepto` (bloqueado por DB)| Acciones de visto bueno / rechazo académico | `[PENDIENTE]` |
| **HU055** | Control de cupo máximo al aceptar postulaciones | Bloqueo protector `WITH (UPDLOCK, HOLDLOCK)` (pendiente SP)| Validación de aforo en `MatriculaUseCase` (bloqueado por DB)| Bloqueo preventivo de sobrecupo en interfaz | `[PENDIENTE]` |
| **HU056** | Registrar marcación masiva ("Todos Presentes") | SP `usp_registrar_asistencias_sesion` (exclusivo) | `POST /api/v1/asistencias/lote` + SSE | Botón de marcación batch en `AttendanceControl` | `[CERTIFICADA]` |
| **HU057** | Consumo transversal de tipos de identificación | SP `usp_consultar_tipos_identificacion` | `GET /api/v1/tipos-identificacion` | Selector en modales de alta docente | `[CERTIFICADA]` |
| **HU058** | Consumo transversal de tipos de programa | SP `usp_consultar_tipos_programa` | `GET /api/v1/tipos-programa` | Filtros por nivel formativo en cursos | `[CERTIFICADA]` |
| **HU059** | Consumo transversal de estados de grupo y sesión | SP `usp_consultar_estados_asistencia` | `GET /api/v1/estados-asistencia` | Badges de estado (Abierto, En Curso, Cerrado) | `[CERTIFICADA]` |

---

## 3. Módulo Coordinación de Programa

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU060** | Consultar registros globales de asistencia del programa | SP `usp_consultar_asistencias_programa` (SOLO su prog) | `GET /coordinador/estudiantes` | `CoordinatorStudentsComponent` (solo lectura) | `[CERTIFICADA]` |
| **HU061** | Ver consolidado por cohorte, materia y docente | SP `usp_consultar_consolidado_cohorte` | DTO consolidado con filtros de cohorte | Vista de resumen agregado en tabla Angular | `[CERTIFICADA]` |
| **HU062** | Directorio de profesores adscritos al programa | SP `usp_consultar_docentes_programa` (pendiente SP)| `GET /coordinador/docentes` (bloqueado por DB)| `CoordinatorDocentesComponent` (`/app/coordinador/docentes`)| `[PENDIENTE]` |
| **HU063** | Búsqueda predictiva de docentes por cédula o nombre | SP con filtros de búsqueda (pendiente SP) | `GET /coordinador/docentes?query=...` (bloqueado por DB) | Barra de búsqueda reactiva con Signals | `[PENDIENTE]` |
| **HU064** | Consultar grupos académicos adscritos al programa | SP `usp_consultar_grupos_programa` (SOLO su prog)| `GET /coordinador/grupos` | Selector de grupos por período del programa | `[CERTIFICADA]` |
| **HU065** | Cronograma de sesiones ejecutadas vs programadas | SP `usp_consultar_cumplimiento_sesiones` | DTO de avance porcentual de clases dictadas | Barra de progreso de cumplimiento de calendario | `[CERTIFICADA]` |
| **HU066** | Semáforo de alerta temprana de deserción (>15%) | SP `usp_consultar_estudiantes_en_riesgo_programa` | Endpoint de reporte de permanencia | Filtro semafórico de ausentismo institucional | `[CERTIFICADA]` |
| **HU067** | Bitácora cronológica de asistencias por estudiante | SP `usp_consultar_bitacora_asistencias_estudiante` | DTO con trazabilidad detallada por alumno | Historial cronológico con timeline visual | `[CERTIFICADA]` |
| **HU068** | Censo de estudiantes matriculados en el programa | SP `usp_consultar_censo_estudiantes_programa` (paginado)| `GET /coordinador/estudiantes` paginado | Tabla unificada con `PaginationComponent` | `[CERTIFICADA]` |
| **HU069** | Ficha integral del estudiante (contacto y faltas) | SP `usp_consultar_ficha_estudiante_programa` | `GET /coordinador/estudiantes/{id}/ficha` | Modal de expediente académico integral | `[CERTIFICADA]` |
| **HU070** | Cálculo de permanencia (Regular, Riesgo, Pérdida)| Regla institucional del 20% en SP de consulta | Indicador de permanencia en DTO de alumno | Badge de estado de permanencia estudiantil | `[CERTIFICADA]` |
| **HU071** | Catálogo de asignaturas adscritas al programa | SP `usp_consultar_asignaturas_programa` | `GET /coordinador/asignaturas` | `CoordinatorStudyPlansComponent` | `[CERTIFICADA]` |
| **HU072** | Resolución de programa académico vía UserScopeService | Validación de titularidad en SP y UserScope | `UserScopeService.resolveProgramaId()` | Control de ámbito de usuario en frontend | `[CERTIFICADA]` |
| **HU073** | Consultar intensidad horaria y créditos | SP `usp_consultar_malla_programa` | DTO curricular de asignatura | Tabla de malla curricular con horas y créditos | `[CERTIFICADA]` |
| **HU074** | Activar o inactivar asignaturas en catálogo | SP `usp_toggle_estado_asignatura` | `PATCH /coordinador/asignaturas/{id}/estado` | Switch de activación con confirmación | `[CERTIFICADA]` |
| **HU075** | Estructurar malla curricular por semestres (1-10) | SP `usp_consultar_estructura_semestres` | DTO estructurado por niveles formativos | Malla visual de semestres en cuadrícula | `[CERTIFICADA]` |
| **HU076B**| Creación y apertura oficial de grupos académicos | SP `usp_crear_grupo` (valida aforo y programa) | `POST /api/v1/grupos` | Formulario de alta de grupo en Coordinación | `[CERTIFICADA]` |
| **HU079** | Crear nuevo plan de estudios para el programa | SP `usp_crear_plan_estudio` (pendiente SP) | `POST /coordinador/planes-estudio` | Formulario de nuevo plan curricular | `[PENDIENTE]` |
| **HU080** | Modificar información curricular de plan | SP `usp_actualizar_plan_estudio` (pendiente SP) | `PUT /coordinador/planes-estudio/{id}` | Formulario de edición de plan de estudios | `[PENDIENTE]` |
| **HU081** | Alternar estado activo/inactivo de plan | SP de cambio de estado en `PlanEstudio` (pendiente SP) | `PATCH /coordinador/planes-estudio/{id}/toggle-estado` (bloqueado DB)| Control de estado de vigencia curricular | `[PENDIENTE]` |
| **HU082** | Añadir nivel/semestre a la estructura del plan | SP de asignación de semestre a plan (pendiente SP) | `POST /planes-estudio/{id}/semestres` (bloqueado DB)| Acción rápida "Añadir Semestre" en malla | `[PENDIENTE]` |
| **HU083** | Remover nivel/semestre sin asignaturas | Validación de integridad en SP (pendiente SP) | `DELETE /planes-estudio/{id}/semestres/{num}` (bloqueado DB)| Acción de remoción controlada con guardas | `[PENDIENTE]` |
| **HU084** | Consultar distribución de materias por semestres | SP `usp_consultar_asignaturas_plan_semestre` | `GET /coordinador/planes-estudio/{id}/asignaturas`| Visualizador jerárquico de plan de estudios | `[CERTIFICADA]` |
| **HU085** | Crear nueva asignatura en el plan de estudios | SP `usp_crear_asignatura` | `POST /coordinador/planes-estudio/{id}/asignaturas` | Modal de alta de materia con créditos y código | `[CERTIFICADA]` |
| **HU086** | Filtros de materias por área y componente | SP de consulta con filtros relacionales | Query params en endpoint de asignaturas | Filtros combinados de búsqueda en frontend | `[CERTIFICADA]` |
| **HU087** | Actualizar créditos y horas de asignatura | SP `usp_actualizar_asignatura` | `PUT /coordinador/planes/{pId}/asignaturas/{aId}` | Formulario de modificación de asignatura | `[CERTIFICADA]` |
| **HU089** | Consultar listado de docentes adscritos al programa| SP `usp_consultar_docentes_programa` (pendiente SP)| `GET /coordinador/docentes` (bloqueado por DB) | Tabla de cuerpo docente con estado de contrato | `[PENDIENTE]` |
| **HU090** | Selector controlado de tipo de vinculación | SP `usp_consultar_tipos_vinculacion` | `GET /catalogo/tipos-vinculacion` | Desplegable controlado por tipo de contrato | `[CERTIFICADA]` |
| **HU091** | Vincular docente al programa y sincronizar IAM | SP de vinculación de docente a programa (pendiente SP)| `POST /coordinador/docentes` (bloqueado por DB) | Modal de vinculación docente con IAM sync | `[PENDIENTE]` |
| **HU092** | Modificar datos profesionales de docente | SP `usp_actualizar_docente` (pendiente SP) | `PUT /coordinador/docentes/{id}` (bloqueado por DB) | Formulario de edición docente | `[PENDIENTE]` |
| **HU093** | Inactivar o reactivar vinculación docente | SP de toggle de estado de contrato (pendiente SP) | `PATCH /coordinador/docentes/{id}/estado` (bloqueado por DB)| Switch de estado con confirmación modal | `[PENDIENTE]` |
| **HU094** | Ficha docente con historial de grupos dictados | SP `usp_consultar_historial_docente` (pendiente SP) | `GET /coordinador/docentes/{id}/historial` (bloqueado por DB) | Ficha con tarjeta resumen de carga académica | `[PENDIENTE]` |
| **HU095** | Directorio consolidado con estado de vinculación | SP `usp_consultar_directorio_docente_programa` (pendiente SP) | DTO con tarjetas de estado de vinculación | Directorio en cuadrícula con tarjetas tipadas | `[PENDIENTE]` |
| **HU096** | Crear nuevo período académico | SP `usp_crear_periodo_academico` | `POST /coordinador/periodos-academicos` (unavailable)| Formulario de creación de semestre lectivo | `Fase 2 (BACKEND)` |
| **HU097** | Modificar fechas de inicio y cierre de período | SP `usp_actualizar_periodo_academico` (pendiente SP)| `PUT /coordinador/periodos-academicos/{id}` (bloqueado por DB)| Selector de fechas con validación de traslape | `[PENDIENTE]` |
| **HU098** | Cierre de período académico y consolidación | SP `usp_ejecutar_cierre_masivo_periodo` | `PATCH /coordinador/periodos-academicos/{id}/estado`| Botón de cierre de período con auditoría | `Fase 2 (BACKEND)` |

---

## 4. Módulo Decanatura y Gobierno Institucional

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU076** | Agregar nuevo programa académico a la facultad | SP `usp_crear_programa_academico` (valida facultad)| `POST /decano/programas` | `DeanFacultyComponent` (`/app/decano/facultad`) | `[PARCIAL]` |
| **HU077** | Modificar modalidad y jornada de programa | SP `usp_actualizar_programa_academico` (pendiente SP)| `PUT /decano/programas/{id}` (bloqueado por DB) | Formulario de edición en `DeanFacultyComponent` | `[PENDIENTE]` |
| **HU078** | Alternar estado activo/inactivo de programa | SP de cambio de estado en `ProgramaAcademico` (pendiente SP) | `PATCH /decano/programas/{id}/estado` (bloqueado DB)| Control de estado de programa en facultad | `[PENDIENTE]` |
| **HU102** | Tablero analítico de ausentismo por facultad | SP `usp_consultar_ausentismo_facultad` (SOLO su fac)| `GET /decano/metricas/ausentismo` | Tablero de control de ausentismo en `Overview` (solo lectura)| `[CERTIFICADA]` |
| **HU103** | Comparativa gráfica de inasistencias entre programas | SP `usp_consultar_comparativa_programas_facultad` | DTO analítico comparativo multidimensional | Gráfica comparativa de barras en dashboard | `[CERTIFICADA]` |
| **HU104** | Directorio consolidado de estudiantes de facultad | SP `usp_consultar_estudiantes_facultad` (paginado) | `GET /decano/estudiantes` | `DeanCoordinadoresComponent` | `[CERTIFICADA]` |
| **HU105** | Búsqueda transversal de estudiantes en facultad | SP con índice non-clustered por facultad y cédula| `GET /decano/estudiantes?search=...` | Buscador transversal con debounce reactivo | `[CERTIFICADA]` |
| **HU106** | Indicador macro de retención estudiantil | SP `usp_consultar_kpi_retencion_facultad` | KPI de retención y reprobación acumulada | Tarjeta KPI con variación porcentual | `[CERTIFICADA]` |
| **HU107** | Consultar estructura institucional de facultades | SP `usp_consultar_facultades` | `GET /admin/facultades` | Estructura de facultades en `DeanFaculty` | `[CERTIFICADA]` |
| **HU108** | Consultar programas vigentes y planes de estudio | SP `usp_consultar_programas_facultad` | `GET /decano/facultad/programas` | Lista de programas con modal de plan curricular | `[CERTIFICADA]` |
| **HU109** | Organigrama jerárquico de dependencias | SP `usp_consultar_arbol_dependencias_facultad` | Endpoint de árbol organizacional | Componente en árbol de jerarquía institucional | `[CERTIFICADA]` |
| **HU110** | Modificar denominación y atributos de la facultad | SP `usp_actualizar_facultad` (pendiente SP) | `PUT /admin/facultades/{id}` (bloqueado por DB) | Formulario de modificación en `DeanFaculty` | `[PENDIENTE]` |
| **HU111** | Alternar estado operativo de la facultad | SP de toggle de estado de facultad (pendiente SP)| `PATCH /admin/facultades/{id}/estado` (bloqueado DB)| Switch de activación con modal de seguridad | `[PENDIENTE]` |
| **HU112** | Consultar tabla unificada de programas y créditos | SP `usp_consultar_programas_creditos_facultad` | `GET /decano/programas/consolidados` | Tabla unificada de programas formativos | `[CERTIFICADA]` |
| **HU113** | Modificar datos de registro calificado | SP `usp_actualizar_programa_academico` (pendiente SP)| `PUT /decano/programas/{id}` | Edición de registro calificado y resolución | `[PENDIENTE]` |
| **HU114** | Suspender o reactivar oferta de programa | SP de cambio de estado en oferta (pendiente SP) | `PATCH /decano/programas/{id}/estado` | Switch de estado de oferta académica | `[PENDIENTE]` |
| **HU115** | Validación de coherencia en ofertas académicas | Procedimiento de validación de planes activos | Verificación en `OfertaAcademicaUseCase` | Validación de reglas al publicar calendario | `[CERTIFICADA]` |
| **HU116** | Alta institucional de nueva facultad | SP `usp_crear_facultad` | `POST /admin/facultades` | Formulario de creación de facultad en UCO | `[CERTIFICADA]` |
| **HU117** | Modificar sede y decano responsable | SP `usp_actualizar_facultad` con decanoId (pendiente SP)| `PUT /admin/facultades/{id}` (bloqueado por DB)| Asignación de decano en formulario | `[PENDIENTE]` |
| **HU118** | Bloqueo temporal de operaciones de facultad | SP de suspensión operativa (pendiente SP) | `PATCH /admin/facultades/{id}/estado` (bloqueado DB)| Confirmación con credencial de administrador | `[PENDIENTE]` |
| **HU119** | Árbol departamental (Facultad ➔ Programa ➔ Plan)| SP `usp_consultar_estructura_multinivel` | Endpoint de estructura departamental | Visualizador jerárquico multinivel en UI | `[CERTIFICADA]` |
| **HU120** | Crear y asignar Coordinador a Programa | SP `usp_crear_coordinador` | `POST /decano/coordinadores` | Modal de alta y asignación de coordinación | `[CERTIFICADA]` |
| **HU121** | Actualizar información del Coordinador | SP `usp_actualizar_coordinador` (pendiente SP)| `PUT /decano/coordinadores/{id}` | Formulario de edición en `DeanCoordinadores` | `[PENDIENTE]` |
| **HU122** | Alternar estado activo/inactivo de Coordinador | SP de toggle de estado de coordinador (pendiente SP)| `PATCH /decano/coordinadores/{id}/estado` (bloqueado DB)| Switch de activación/suspensión de usuario | `[PENDIENTE]` |
| **HU123** | Búsqueda predictiva de coordinadores de facultad | SP de búsqueda con filtros por facultad | `GET /decano/coordinadores?q=...` | Buscador predictivo en cabecera de tabla | `[PENDIENTE]` |
| **HU124** | Directorio consolidado de coordinadores | SP `usp_consultar_coordinadores_facultad` | `GET /decano/coordinadores` | Tabla con estado y programa adscrito | `[CERTIFICADA]` |
| **HU125** | Alta de docentes interdepartamentales | SP de registro con múltiples programas | `POST /decano/docentes/interdepartamental`| Formulario de asignación de doble programa | `[PENDIENTE]` |
| **HU126** | Reasignación de adscripción departamental docente | SP de actualización de adscripción | `PUT /decano/docentes/{id}/departamento` | Modal de transferencia entre programas | `[PENDIENTE]` |
| **HU127** | Gestión de estado y contratos en facultad | SP de suspensión de vinculación académica | `PATCH /decano/docentes/{id}/contrato` | Gestión de altas/bajas contractuales | `[PENDIENTE]` |
| **HU128** | Filtro de profesores por programa asignado | SP de consulta con filtro de programa | Query param `programaId` en docentes | Filtro selector por programa en interfaz | `[CERTIFICADA]` |
| **HU129** | Reporte tabular de horas contratadas por docente | SP `usp_consultar_horas_docente_facultad` | DTO con desglose de horas clase asignadas | Tabla de seguimiento de carga académica | `[CERTIFICADA]` |
| **HU133** | Indicador KPI global de asistencia en la universidad| SP `usp_consultar_kpi_global_asistencia` | `GET /admin/kpi/asistencia-global` | Tarjeta KPI global en `OverviewComponent` | `[CERTIFICADA]` |
| **HU134** | Tendencias temporales de ausentismo en reportería | SP `usp_consultar_tendencias_temporales` | DTO de series temporales de asistencia | Gráfica de líneas con tendencias en dashboard | `[CERTIFICADA]` |
| **HU135** | Contador en tiempo real de censo estudiantil | SP `usp_consultar_censo_estudiantil_vivo` | Endpoint de métricas demográficas en vivo | Contador en vivo con animación numérica | `[CERTIFICADA]` |
| **HU136** | Contador en tiempo real de censo docente | SP `usp_consultar_censo_docente_vivo` | Endpoint de métricas de personal académico | Contador en vivo de docentes activos | `[CERTIFICADA]` |
| **HU137** | Directorio administrativo institucional | SP `usp_consultar_personal_administrativo` | `GET /admin/personal` | Directorio con tarjetas de contacto | `[CERTIFICADA]` |
| **HU138** | Ratio de sesiones dictadas con asistencia registrada| SP `usp_consultar_ratio_cumplimiento_asistencia`| DTO de efectividad de toma de asistencia | Indicador de cumplimiento docente en vivo | `[CERTIFICADA]` |
| **HU139** | Tarjetas comparativas de inasistencia por facultad | SP `usp_consultar_comparativa_facultades` | DTO con porcentaje de ausentismo por facultad| Tarjetas comparativas en cuadrícula | `[CERTIFICADA]` |
| **HU140** | Censo de estudiantes agrupado por sedes | SP `usp_consultar_censo_por_sedes` | DTO demográfico por sede | Gráfico circular de distribución por campus | `[CERTIFICADA]` |
| **HU141** | Censo de docentes clasificado por escalafón | SP `usp_consultar_censo_por_escalafon` | DTO de clasificación docente | Gráfica de barras de escalafón académico | `[CERTIFICADA]` |
| **HU142** | Consulta histórica de períodos académicos | SP `usp_consultar_periodos_historicos` | `GET /coordinador/periodos-academicos` | Selector de períodos anteriores en reportes | `[CERTIFICADA]` |
| **HU143** | Búsqueda transversal de asignaturas en toda la UCO| SP `usp_consultar_asignaturas_global` (paginado) | `GET /admin/asignaturas/global` | Buscador transversal de asignaturas | `[CERTIFICADA]` |
| **HU144** | Censo de grupos activos y tasa de aforo de facultad | SP `usp_consultar_aforo_grupos_facultad` (SOLO fac)| DTO con porcentaje de ocupación de cupos | Barras de ocupación de aforo por grupo | `[PARCIAL]` |
| **HU145** | Cronograma de sesiones en sedes de la facultad | SP `usp_consultar_cronograma_sesiones_facultad`| `GET /admin/sesiones/cronograma-facultad` | Calendario institucional de sesiones de facultad| `[PARCIAL]` |
| **HU146** | Notificación de controversias en justificaciones (Trámite externo)| Registro de estado `RECHAZADA_DEFINITIVA` en DB| Notificación informativa de rechazo docente | Aviso informativo de trámite de apelación fuera del sistema| `[CERTIFICADA]` |

---

## 5. Módulo Administración del Sistema y Catálogos Transversales

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU147** | Consultar componentes de formación académica | SP `usp_consultar_componentes_formacion` | `GET /admin/componentes-formacion` | `DeanFacultyComponent` (`/app/decano/facultad`) | `[CERTIFICADA]` |
| **HU148** | Crear nuevo componente de formación académica | SP de alta de componente (pendiente SP) | `POST /admin/componentes-formacion` (bloqueado DB) | Formulario de alta en `DeanFacultyComponent` | `[PENDIENTE]` |
| **HU149** | Actualizar competencias asociadas a un componente | SP de actualización de competencias (pendiente SP) | `PUT /admin/componentes-formacion/{id}` (bloqueado DB) | Edición de competencias curriculares | `[PENDIENTE]` |
| **HU150** | Consultar catálogo de áreas de conocimiento UCO | SP `usp_consultar_areas_conocimiento` | `GET /admin/areas` | Tabla de áreas en `DeanFacultyComponent` | `[CERTIFICADA]` |
| **HU151** | Crear nueva área de conocimiento institucional | SP `usp_crear_area_conocimiento` (pendiente SP) | `POST /admin/areas` (bloqueado por DB) | Modal de creación de área de conocimiento | `[PENDIENTE]` |
| **HU152** | Modificar datos y estado de un área de conocimiento| SP `usp_actualizar_area_conocimiento` (pendiente SP)| `PUT /admin/areas/{id}` & `PATCH .../estado` (bloqueado DB) | Edición y switch de activación en UI | `[PENDIENTE]` |
| **HU153** | Administración de Catálogo: Tipos de Documento | SP `usp_consultar_tipos_identificacion_admin` | `GET`, `POST`, `PUT /admin/tipos-documento` | Mantenimiento de catálogo en `AdminCatalogs` | `[CERTIFICADA]` |
| **HU154** | Administración de Catálogo: Tipos de Programa | SP `usp_consultar_tipos_programa_admin` | `GET`, `POST`, `PUT /admin/tipos-programa` | Mantenimiento de modalidades formativas | `[CERTIFICADA]` |
| **HU155** | Administración de Catálogo: Estados del Sistema | SP `usp_consultar_estados_sistema_admin` | `GET`, `PUT /admin/estados-sistema` | Configuración de estados de flujo de trabajo | `[CERTIFICADA]` |
| **HU156** | Admisión demográfica y creación de usuario estudiante| SP `usp_sincronizar_estudiante_interno` + IAM | `POST /admin/estudiantes/admision` | Formulario de admisión en `CoordinatorStudents` | `[CERTIFICADA]` |
| **HU157** | Ficha unificada del estudiante con historial completo| SP `usp_consultar_ficha_unificada_estudiante` | `GET /admin/estudiantes/{id}/ficha-unificada` | Ficha unificada con datos personales | `[CERTIFICADA]` |
| **HU158** | Consultar padrón unificado de estudiantes de la UCO | SP `usp_consultar_padron_general_estudiantes` | `GET /coordinador/estudiantes` (admin) | Tabla con filtros y paginación en `Coordinator` | `[CERTIFICADA]` |
| **HU159** | Actualizar datos personales y contacto de estudiante | SP `usp_actualizar_datos_estudiante` (pendiente SP) | `PUT /coordinador/estudiantes/{id}/contacto` (bloqueado DB)| Modal de edición de contacto | `[PENDIENTE]` |
| **HU160** | Modificar estado institucional (Matriculado, Retiro)| SP de transición de estado (pendiente SP) | `PATCH /coordinador/estudiantes/{id}/estado` (bloqueado DB)| Selector de estado institucional con auditoría | `[PENDIENTE]` |
| **HU161** | Registrar nueva institución de convenio o práctica | SP de alta en `InstitucionConvenio` (pendiente SP) | `POST /admin/instituciones` (bloqueado por DB) | `AdminCatalogsComponent` (`/app/admin/catalogos`)| `[PENDIENTE]` |
| **HU162** | Modificar datos de institución colaboradora | SP de actualización de institución (pendiente SP) | `PUT /admin/instituciones/{id}` (bloqueado por DB) | Formulario de modificación de convenio | `[PENDIENTE]` |
| **HU163** | Consultar listado de instituciones de convenio | SP `usp_consultar_instituciones_convenio` | `GET /admin/instituciones` | Tabla de entidades externas en convenio | `[CERTIFICADA]` |
| **HU164** | Alternar estado activo/inactivo de institución | SP de toggle de estado de institución (pendiente SP)| `PATCH /admin/instituciones/{id}/toggle` (bloqueado DB) | Switch de activación de convenios | `[PENDIENTE]` |
| **HU168** | Configurar parámetros generales (Límite 20%, Días) | SP `usp_consultar_parametros_generales` | `GET`, `PUT /admin/parametros` (bloqueado por DB) | `AdminSystemComponent` (`/app/admin/sistema`) | `[PENDIENTE]` |
| **HU169** | Configurar catálogo centralizado de mensajes | SP `usp_obtener_mensaje_catalogo` | `PUT /admin/parametros/{id}` (bloqueado por DB) | Consola de configuración de mensajes técnicos | `[PENDIENTE]` |
| **HU170** | Sincronización batch de usuarios Keycloak a BD | SP `usp_sincronizar_usuario_interno` | `POST /admin/sincronizacion/usuarios` | Consola batch con conteo de sincronizados | `[CERTIFICADA]` |
| **HU171** | Registro e inscripción manual masiva por secretaría | SP `usp_registrar_estudiante_en_programa_interno`| `POST /admin/matricula/batch` | Consola batch de enrolamiento interno | `[CERTIFICADA]` |
| **HU172** | Registro de auditoría forense de cambios de asistencia | SP `usp_consultar_auditoria_eventos` (paginado) | `GET /admin/auditoria` con filtros | Tabla de auditoría con IP, usuario y timestamps | `[CERTIFICADA]` |
| **HU173** | Validación algorítmica preventiva de solapamientos | SP `usp_validar_horarios_grupo_interno` | Algoritmo de chequeo en `HorarioUseCase` | Alerta visual en interfaz de horarios | `[CERTIFICADA]` |
| **HU174** | Cierre masivo automático de período y actas de faltas| SP `usp_ejecutar_cierre_masivo_periodo` | `POST /admin/cierre-masivo` | Consola de cierre semestral con confirmación | `[CERTIFICADA]` |

---

## 6. Módulo Especial: Auto-Asistencia, Matrícula QR y Métodos Autónomos

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU175** | Proyección en pantalla de QR dinámico y PIN (TTL 60s)| SP `usp_generar_token_sesion_asistencia` (pendiente SP)| `GET /sesiones/{id}/qr-token` (bloqueado por DB)| Modal de proyección en pantalla gigante en clase | `[PENDIENTE]` |
| **HU176** | Auto-registro de asistencia con validación WI-FI CAMPUS| SP `usp_registrar_asistencia_estudiante_autonomo`| `POST /estudiante/asistencia-qr` (valida IP Wi-Fi UCO)| Lector QR móvil con verificación de red campus | `Fase 3 (FRONTEND)` |
| **HU176B**| Matrícula autónoma por QR de curso proyectado por docente| SP `usp_matricular_estudiante_qr_autonomo` (pendiente SP)| `POST /estudiante/matricula-qr` (bloqueado por DB) | Escaneo móvil de QR de matrícula del curso | `[PENDIENTE]` |

---

## Documentos Relacionados
* [Guía Rápida de Flujo de Trabajo](./guia-flujo-trabajo-sdd.md) - Inducción para nuevos chats y agentes.
* [Especificaciones de Historias de Usuario (SDD)](file:///c:/Proyectos/GestioAsistencia/.specify/specs/) - Especificaciones funcionales y contratos WORM.
* [Arquitectura Integral](./arquitectura-integral.md) - Modelo de referencia por capas.
* [Guía Operativa y Reglas de Construcción](../AGENTS.md) - Principios innegociables UCO y concisión del 70%.
