# 📊 Matriz Integral de Historias de Usuario por Capas y Fases SDD — GestioAsistencia UCO
> **Ecosistema:** Plataforma Institucional de Gestión y Control de Asistencia UCO  
> **Versión de Matriz:** 4.0.0 (Sinceramiento de Línea Base, Auditoría de Extremo a Extremo y Detección de Stubs HTTP 501)  
> **Ámbito:** Matriz de trazabilidad técnica por capas y estado verídico de ciclo de vida del pipeline SDD.  
> **Fecha de Actualización:** Octubre 2026

---

## Índice de Módulos
1. [Reglas Técnicas y Convenciones del Pipeline SDD](#reglas-técnicas-y-convenciones-del-pipeline-sdd)
2. [1. Módulo Estudiante (HU001 – HU026, HU026B, HU026C)](#1-módulo-estudiante)
3. [2. Módulo Docente (HU027 – HU059)](#2-módulo-docente)
4. [3. Módulo Coordinación de Programa (HU060 – HU098)](#3-módulo-coordinación-de-programa)
5. [4. Módulo Decanatura y Gobierno Institucional (HU076-HU078, HU099 – HU146)](#4-módulo-decanatura-y-gobierno-institucional)
6. [5. Módulo Administración del Sistema y Catálogos Transversales (HU147 – HU174)](#5-módulo-administración-del-sistema-y-catálogos-transversales)
7. [6. Módulo Especial: Auto-Asistencia, Matrícula QR y Métodos Autónomos (HU175 – HU176B)](#6-módulo-especial-auto-asistencia-matrícula-qr-y-métodos-autónomos)
8. [Resumen Cuantitativo del Estado Real del Catálogo](#resumen-cuantitativo-del-estado-real-del-catálogo)
9. [Documentos Relacionados](#documentos-relacionados)

---

## Reglas Técnicas y Convenciones del Pipeline SDD

### 🛑 Reglas Inviolables de Dominio y Persistencia:
1. **Consultas Obligatorias vía SP ➔ Vista (Paginadas y Filtradas):** Queda prohibido que el Backend ejecute `SELECT` directo contra vistas o tablas. Toda consulta de lectura se encapsula en un **Procedimiento Almacenado de Consulta (`usp_consultar_*`) que internamente invoca a la vista (`uv_*`)**, recibiendo `@numeroPagina`, `@tamanoPagina`, filtros tipados, y retornando `OFFSET ... ROWS FETCH NEXT ... ROWS ONLY` junto con `COUNT(*) OVER() AS totalRegistros` (o repositorios Spring Data JPA sobre vistas públicas `uv_*` conforme a la estrategia incremental autorizada en LB-008).
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
* **`[CERTIFICADA]`**: Verificada y funcional de extremo a extremo en las 4 capas (DB, Backend, Frontend y E2E).
* **`Fase 3 (FRONTEND)`**: Backend y DB listos con contrato real; en construcción, ajuste o conexión final en Angular.
* **`Fase 2 (BACKEND)`**: SP probado en DB; en desarrollo de puertos, adaptadores y controladores.
* **`Fase 1 (DB)`**: Contratos WORM congelados; en codificación de SPs atómicos con `SET XACT_ABORT ON;`.
* **`[BLOQUEADO 501]`**: Acción o pantalla implementada en el Frontend, pero el endpoint en Backend es un *stub* que lanza `FeatureUnavailableException` (HTTP 501) por falta de SP mutacional o contrato DB público.
* **`[PARCIAL]`**: Soporte preliminar en refinamiento técnico con persistencia base o funcionalidad solo de lectura.
* **`[PENDIENTE]`**: Catalogada lista para inicio en pipeline (pendiente diseño o creación de SP y Controller).
* **`[DESCARTADA]`**: Historia retirada del alcance por decisión del responsable; no se implementa y su código asociado se eliminó.

---

## 1. Módulo Estudiante

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU001** | Ver detalles de asistencias por materia | Vistas `uv_estudiante_grupo` y `uv_asignatura` (JPA) | `GET /api/v1/estudiante/materias` | `StudentCoursesComponent` (`/app/estudiante/materias`) | `[CERTIFICADA]` |
| **HU002** | Consultar registros históricos de asistencia | Vistas `uv_sesion` y `uv_asistencia` (JPA) | `GET /api/v1/estudiante/materias/{id}/sesiones` | `StudentCoursesComponent` (`/app/estudiante/materias`) | `[CERTIFICADA]` |
| **HU003** | Ver lista de compañeros matriculados en grupo | Vista `uv_estudiante_grupo` / Port | `GET /api/v1/grupos/{grupoId}/estudiantes` | Modal en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU004** | Consultar estado de permanencia (Regla 20%) | Cálculo reactivo de inasistencias en dominio | Cálculo en Signals sobre sesiones y fallas | Badge dinámico en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU005** | Consultar causales normativas de justificación | Catálogo de razones en dominio/enums | Sin endpoint REST dedicado (en memoria/cliente) | Modal de reclamos en `StudentCoursesComponent` | `[PARCIAL]` |
| **HU006** | Consultar perfil y ficha de información personal | SP pendiente en DB | `GET /api/v1/usuarios/perfil` (arroja 501) | `ProfileComponent` (`/app/perfil`) (datos Keycloak) | `[BLOQUEADO 501]` |
| **HU007** | Búsqueda y filtrado de materias matriculadas | Filtro reactivo en Signals de materias cargadas | `GET /api/v1/estudiante/materias` | Filtros con Signals en `StudentCoursesComponent` | `[CERTIFICADA]` |
| **HU008** | Consultar información de grupos y cupos | SP de oferta no modelado | Endpoint `/grupos/oferta-academica` no existe | Selector de cursos en `StudentCoursesComponent` | `[PENDIENTE]` |
| **HU009** | Barra consolidada de porcentaje de inasistencia | Agregación reactiva de asistencias | Cálculo en Signals derivado de sesiones | `ProgressBarComponent` reactivo con Signals | `[CERTIFICADA]` |
| **HU010** | Radicar solicitud de revisión / reclamo | SP `usp_radicar_solicitud_revision_asistencia` | `POST /api/v1/asistencias/revisiones` | Formulario reactivo en `StudentCoursesComponent` | `Fase 3 (FRONTEND)` |
| **HU011** | Adjuntar soporte individual a solicitud | Almacenamiento en S3 / MinIO | `POST /api/v1/archivos/subir` (ArchivoController) | Carga de archivo en modal de reclamo | `Fase 3 (FRONTEND)` |
| **HU012** | Consultar historial de reclamos radicados | SP de consulta pendiente | `GET /api/v1/estudiante/reclamos` (arroja 501) | Tabla de estados de reclamo con Signals | `[BLOQUEADO 501]` |
| **HU013** | Alerta visual de riesgo de pérdida (15% - 20%) | Cálculo reactivo de porcentaje acumulado | Cálculo en Signals sobre sesiones cursadas | Resaltado semafórico en tarjetas de materia | `[CERTIFICADA]` |
| **HU014** | Formulario especializado para justificación médica | Validación de causal médica en SP | Validación en `SolicitarRevisionAsistenciaInputPort` | Formulario específico de justificación médica | `Fase 3 (FRONTEND)` |
| **HU015** | Carga y almacenamiento seguro de múltiples soportes | Tabla `SolicitudRevisionSoporte` | `POST /api/v1/archivos/subir` | Drag-and-drop en `StudentCoursesComponent` | `[PARCIAL]` |
| **HU016** | Visualización de causales y reglamento estudiantil | Parámetros UCO | Sin endpoint REST específico | Tooltip y modal informativo de causales UCO | `[PARCIAL]` |
| **HU017** | Consultar sesiones de clase programadas | Vistas de horario estudiante | `GET /api/v1/estudiante/horarios` | `StudentScheduleComponent` (`/app/estudiante/horarios`)| `[CERTIFICADA]` |
| **HU018** | Consultar estructura curricular de semestres | Agrupación curricular por nivel | `GET /api/v1/estudiante/materias` | Vista en acordeón de semestres cursados | `[CERTIFICADA]` |
| **HU019** | Consultar créditos y plan de estudios | Sumatoria de créditos de asignaturas | Derivado de materias matriculadas | Barra de créditos aprobados vs totales | `[CERTIFICADA]` |
| **HU020** | Consultar sede, aula y bloque por sesión | Sin campo de aula en contrato Golden Path | DTO sin aula (`HorarioEstudianteDTO`) | Tarjeta de sesión con datos horarios | `[PARCIAL]` |
| **HU021** | Filtro de horario semanal por días lectivos | Filtro por día en cliente/horario | `GET /api/v1/estudiante/horarios` | Selector reactivo de días (Lunes a Sábado) | `[CERTIFICADA]` |
| **HU022** | Consumo transversal de tipos de identificación | Vista `uv_tipo_identificacion` | `GET /api/v1/tipos-identificacion` | `FormFieldComponent` en perfil | `[CERTIFICADA]` |
| **HU023** | Consumo transversal de tipos de programa | Vista `uv_tipo_programa` (solo activos) | `GET /api/v1/tipos-programa` (`CatalogoProgramaController`, HU076-HU078) | Selector de tipo en formulario de programa | `[CERTIFICADA]` |
| **HU024** | Consumo transversal de estados de asistencia | Dominio de asistencia (`AN`, `SJC`, `EX`) | Mapeo en DTOs de asistencia | Leyenda de estados (Presente, Falta, Justificada) | `[CERTIFICADA]` |
| **HU025** | ~~Consultar prerrequisitos y correquisitos~~ | Descartada (decisión de John, 2026-10-29): los prerrequisitos y correquisitos no existen en la aplicación | Endpoint `GET .../materias/{id}/prerrequisitos` eliminado | Modal de prerrequisitos eliminado | `[DESCARTADA]` |
| **HU026** | Solicitud de inscripción o matrícula por QR | SP no modelado en DB | `POST .../solicitudes-matricula` (arroja 501) | Escaneo de QR / PIN de curso | `[BLOQUEADO 501]` |
| **HU026B**| Validación de plazo perentorio (5 días) para excusas | SP `usp_radicar_solicitud_revision_asistencia` | Regla en `SolicitarRevisionAsistenciaUseCase` | Bloqueo automático de formulario extemporáneo | `[PENDIENTE]` |
| **HU026C**| Notificaciones proactivas de ausentismo (15% y 20%) | SP `usp_consultar_estudiantes_en_riesgo` | Job batch + SSE (`SseRealtimeAdapter`) + Email | Toast de notificación y panel de alertas en vivo | `[PENDIENTE]` |

---

## 2. Módulo Docente

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU027** | Registrar asistencia individual de estudiante | SP `usp_registrar_asistencia_estudiante` (exclusivo docente)| `POST /api/v1/asistencias` (Golden Path) | `AttendanceControlComponent` (`/app/asistencia`) | `[CERTIFICADA]` |
| **HU028** | Abrir/iniciar sesión de clase | SP `usp_crear_sesion` (valida titularidad en SP) | `POST /api/v1/sesiones` (Golden Path) | Botón "Iniciar Clase" en `AttendanceControlComponent` | `[CERTIFICADA]` |
| **HU029** | Consultar planilla completa de asistencia | Vista `uv_detalle_asistencia` / SP | `GET /api/v1/grupos/{id}/asistencias` (Golden Path) | Tabla de planilla en `AttendanceControlComponent` | `[CERTIFICADA]` |
| **HU030** | Programar sesión ordinaria o extraordinaria | SP `usp_crear_sesion` con tipo de clase | `POST /api/v1/sesiones` (Golden Path) | Modal de nueva sesión en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU031** | Consultar grupos asignados (Aislamiento de titularidad)| Scope docente y asignaciones académicas | `GET /api/v1/grupos` o `GET .../asignaciones` | `TeacherGruposComponent` (`/app/docente/grupos`) | `[CERTIFICADA]` |
| **HU032** | Consultar padrón de estudiantes de su grupo | Vista `uv_estudiante_grupo` | `GET /api/v1/grupos/{id}/estudiantes` (Golden Path) | Pestaña "Padrón" en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU033** | Modificar estado de asistencia registrada | SP `usp_registrar_asistencia_estudiante` | `POST /api/v1/asistencias` (Golden Path) | Selector interactivo de estado por estudiante | `[CERTIFICADA]` |
| **HU034** | Validación preventiva de solapamiento de horarios | SP `usp_validar_cruce_horario_docente_interno` | Validación en `CrearSesionUseCase` | Mensaje de advertencia ante conflicto horario | `[CERTIFICADA]` |
| **HU035** | Consultar solicitudes de revisión pendientes | SP `usp_consultar_solicitudes_revision_docente` (paginado, titularidad en SP; LB-004D) | `GET /api/v1/docente/reclamos?estado&pagina&tamano` | `TeacherClaimsComponent` con `PaginationComponent`, filtro y contador desde servidor (Signals) | `[CERTIFICADA]` |
| **HU036** | Consultar detalle y causal de una solicitud | SP `usp_consultar_detalle_solicitud_revision_docente` (causal `RazonCausa` + `asistio`, titularidad en SP) | `GET /api/v1/docente/reclamos/{id}` | Vista de resolución con detalle y causal desde backend en `TeacherClaimsComponent` | `[CERTIFICADA]` |
| **HU037** | Resolver justificación de inasistencia (Definitiva en app)| SP `usp_resolver_solicitud_revision_asistencia` | `PATCH /api/v1/docente/reclamos/{id}` (Implementado) | Botones Aprobar/Rechazar en UI | `Fase 3 (FRONTEND)` |
| **HU038** | Ingresar observación o retroalimentación obligatoria | Parámetro `@respuestaDocente` en SP | Campo `respuestaDocente` en DTO de resolución | Área de texto para observaciones al estudiante | `Fase 3 (FRONTEND)` |
| **HU039** | Visualizar y descargar soporte médico adjunto | Almacenamiento MinIO S3 | `GET /api/v1/archivos/{fileId}` | Visor de documentos en `TeacherClaimsComponent` | `Fase 3 (FRONTEND)` |
| **HU040** | Consultar tasa acumulada de ausentismo por grupo | Vista `uv_detalle_asistencia` | Calculada sobre DTO de asistencias | Métricas superiores en `AttendanceControlComponent` | `[CERTIFICADA]` |
| **HU041** | Resaltado visual semafórico de alumnos en riesgo | Cálculo analítico reactivo en UI | Campo proyectado en frontend | Fila resaltada en rojo/amarillo en la planilla | `[CERTIFICADA]` |
| **HU042** | Auditoría y notificación de resolución de reclamo | Evento en DB / EventGrid | Emisión de evento SSE de resolución | Notificación reactiva al estudiante en tiempo real | `[CERTIFICADA]` |
| **HU043** | Consultar políticas de asistencia y aforo de grupo | Vista `uv_grupo` | DTO de configuración del grupo | Pestaña de configuración en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU044** | Editar aforo y observaciones operativas | SP `usp_actualizar_grupo` | `PUT /api/v1/grupos/{id}` | Formulario de edición en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU045** | Programar nueva sesión de clase en cronograma | SP `usp_crear_sesion` | `POST /api/v1/sesiones` (Golden Path) | Calendario de sesiones en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU046** | Reprogramar fecha y hora de sesión | SP `usp_actualizar_sesion` | `PUT` / `PATCH /api/v1/sesiones/{id}` (Golden Path) | Modal de reprogramación en `TeacherGruposComponent` | `[CERTIFICADA]` |
| **HU047** | Cancelar sesión de clase con justificación | SP de cancelación pendiente en DB | `PATCH .../docente/sesiones/{id}/cancelar` (arroja 501)| Flag `sessionCancelEnabled: false` en frontend | `[BLOQUEADO 501]` |
| **HU048** | Configurar horarios semanales de clase | SP `usp_actualizar_sesion` | `PUT /api/v1/sesiones/{id}` (Golden Path) | Selector horario semanal en grupo | `[CERTIFICADA]` |
| **HU049** | Modificar horario y aula de sesión programada | SP `usp_actualizar_sesion` | `PUT /api/v1/sesiones/{id}` (Golden Path) | Edición rápida de aula y hora de inicio/fin | `[CERTIFICADA]` |
| **HU050** | Matrícula o registro manual del estudiante por docente| `dbo.usp_registrar_estudiante_en_grupo` (JPA) | `POST /api/v1/grupos/{id}/estudiantes` | Modal de enrolamiento manual (`AttendanceControlComponent`) | `[CERTIFICADA]` |
| **HU051** | Notificar baja o deserción de estudiante | Registro de novedad pendiente en DB | Endpoint no existe en backend | Notificación directa a Coordinación de Programa | `[PENDIENTE]` |
| **HU052** | Consultar padrón con filtros predictivos | Vista `uv_estudiante_grupo` | `GET /api/v1/grupos/{id}/estudiantes` | Buscador predictivo en padrón docente | `[CERTIFICADA]` |
| **HU053** | Consultar postulaciones de ingreso al curso | SP pendiente en DB | Endpoint no existe en backend | Lista de solicitudes de unión al grupo | `[PENDIENTE]` |
| **HU054** | Emitir concepto docente sobre postulación | SP pendiente en DB | Endpoint no existe en backend | Acciones de visto bueno / rechazo académico | `[PENDIENTE]` |
| **HU055** | Control de cupo máximo al aceptar postulaciones | Bloqueo protector `WITH (UPDLOCK, HOLDLOCK)` | Validación en `GrupoUseCase` | Bloqueo preventivo de sobrecupo en interfaz | `[PENDIENTE]` |
| **HU056** | Registrar marcación masiva ("Todos Presentes") | SP `usp_registrar_asistencias_sesion` | `POST /api/v1/asistencias/lote` + SSE (Golden Path) | Botón de marcación batch en `AttendanceControl` | `[CERTIFICADA]` |
| **HU057** | Consumo transversal de tipos de identificación | Vista `uv_tipo_identificacion` | `GET /api/v1/tipos-identificacion` | Selector en modales de alta docente | `[CERTIFICADA]` |
| **HU058** | Consumo transversal de tipos de programa | Vista `uv_tipo_programa` | Mapeo en frontend | Filtros por nivel formativo en cursos | `[PARCIAL]` |
| **HU059** | Consumo transversal de estados de grupo y sesión | Catálogo de estados de sesión | Estados tipados en DTOs de sesión | Badges de estado (Abierto, En Curso, Cerrado) | `[CERTIFICADA]` |

---

## 3. Módulo Coordinación de Programa

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU060** | Consultar registros globales de asistencia del programa | SP `usp_consultar_grupos_paginado` y `usp_consultar_sesiones_grupo_paginado` (ámbito por programa vía `uv_auth_*`) | `GET /api/v1/coordinador/grupos`, `/grupos/{id}/sesiones` | `CoordinatorAttendanceComponent` (`/app/coordinador/asistencias`) · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU061** | Ver consolidado por cohorte, materia y docente | SP `usp_consultar_asistencias_sesion_paginado` (detalle por sesión); consolidado agregado no modelado | `GET /api/v1/coordinador/sesiones/{id}/asistencias` | Detalle por estudiante en `CoordinatorAttendanceComponent`; sin vista consolidada por cohorte | `[PARCIAL]` |
| **HU062** | Directorio de profesores adscritos al programa | SP `usp_consultar_docentes_programa` (paginado, incluye docentes sin grupos) | `GET /api/v1/coordinador/docentes` | `CoordinatorDocentesComponent` (`/app/coordinador/docentes`) | `[CERTIFICADA]` |
| **HU063** | Búsqueda predictiva de docentes por cédula o nombre | SP `usp_consultar_docentes_programa` y `usp_consultar_candidatos_docente_programa` (prefijo de cédula o nombre, en servidor) | `GET /api/v1/coordinador/docentes` y `GET /api/v1/coordinador/docentes/candidatos` | Barra de búsqueda reactiva con Signals y debounce | `[CERTIFICADA]` |
| **HU064** | Consultar grupos académicos adscritos al programa | SP `usp_consultar_grupos_paginado` (ámbito por programa) | `GET /api/v1/coordinador/grupos` | `CoordinatorAttendanceComponent` (filtro por período y búsqueda) · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU065** | Cronograma de sesiones ejecutadas vs programadas | SP `usp_consultar_kpis_coordinador` | `GET /api/v1/coordinador/indicadores` | `CoordinatorIndicatorsComponent` (`/app/coordinador/indicadores`), cumplimiento y progreso del calendario | `[CERTIFICADA]` |
| **HU066** | Semáforo de alerta temprana de deserción (>15%) | SP `usp_consultar_alerta_temprana_programa` | `GET /api/v1/coordinador/alertas-tempranas` | Tabla paginada con filtro semafórico en `/app/coordinador/indicadores` | `[CERTIFICADA]` |
| **HU067** | Bitácora cronológica de asistencias por estudiante | SP `usp_consultar_bitacora_estudiante_programa` | `GET /api/v1/coordinador/estudiantes/{id}/bitacora` | Bitácora paginada dentro del modal de ficha | `[CERTIFICADA]`
| **HU068** | Censo de estudiantes matriculados en el programa | Vista `uv_auth_estudiante` | `GET /api/v1/coordinador/estudiantes` (paginado) | Tabla unificada con `PaginationComponent` | `[CERTIFICADA]` |
| **HU069** | Ficha integral del estudiante (contacto y faltas) | SP `usp_consultar_ficha_estudiante_programa` y `usp_consultar_resumen_asistencia_estudiante_programa` | `GET /api/v1/coordinador/estudiantes/{id}/ficha` | Modal de ficha con resumen por asignatura (abierto desde alertas) | `[CERTIFICADA]` |
| **HU070** | Cálculo de permanencia (Regular, Riesgo, Pérdida)| `ufn_clasificar_permanencia` y `uv_resumen_asistencia_estudiante_grupo` | Incluida en indicadores, alertas y ficha | Estado de permanencia en alertas y ficha | `[CERTIFICADA]` |
| **HU071** | Catálogo de asignaturas adscritas al programa | Vista `uv_asignatura` | `GET /api/v1/coordinador/asignaturas` | `CoordinatorStudyPlansComponent` | `[CERTIFICADA]` |
| **HU072** | Resolución de programa académico vía UserScopeService | Validación de titularidad en DB / UserScope | `UserScopeService.resolveProgramaId()` | Control de ámbito de usuario en frontend | `[CERTIFICADA]` |
| **HU073** | Consultar intensidad horaria y créditos | Vista `uv_asignatura` | DTO curricular en `GET /api/v1/coordinador/asignaturas` | Tabla de malla curricular con horas y créditos | `[CERTIFICADA]` |
| **HU074** | Activar o inactivar asignaturas en catálogo | SP `usp_toggle_estado_asignatura` | `PATCH /api/v1/coordinador/asignaturas/{id}/estado` | Switch de activación con confirmación | `[CERTIFICADA]` |
| **HU075** | Estructurar malla curricular por semestres (1-10) | Asignaturas por plan de estudio | `GET .../planes-estudio/{id}/asignaturas` | Malla visual de semestres en cuadrícula | `[CERTIFICADA]` |
| **HU076B**| Creación y apertura oficial de grupos académicos | SP `usp_crear_grupo` (valida aforo y programa) | `POST /api/v1/grupos` | Formulario de alta de grupo en Coordinación | `[CERTIFICADA]` |
| **HU079** | Crear nuevo plan de estudios para el programa | SP `usp_registrar_o_actualizar_plan_estudio` | `POST /api/v1/coordinador/planes-estudio` | Formulario de nuevo plan curricular | `[CERTIFICADA]` |
| **HU080** | Modificar información curricular de plan | SP `usp_registrar_o_actualizar_plan_estudio` | `PUT /api/v1/coordinador/planes-estudio/{id}` | Formulario de edición de plan de estudios | `[CERTIFICADA]` |
| **HU081** | Alternar estado activo/inactivo de plan | SP `usp_cambiar_estado_plan_estudio` | `PATCH /api/v1/coordinador/planes-estudio/{id}/toggle-estado` | Control de vigencia en `CoordinatorStudyPlansComponent` (validado en pantalla) | `[CERTIFICADA]` |
| **HU082** | Añadir nivel/semestre a la estructura del plan | SP `usp_agregar_semestre_plan_estudio` (máx. 10) | `POST /api/v1/coordinador/planes-estudio/{id}/semestres` | "Añadir Semestre" en la malla del coordinador (validado en pantalla) | `[CERTIFICADA]` |
| **HU083** | Remover nivel/semestre sin asignaturas | SP `usp_quitar_semestre_plan_estudio` | `DELETE /api/v1/coordinador/planes-estudio/{id}/semestres/{num}` | Remoción controlada en la malla del coordinador (validado en pantalla) | `[CERTIFICADA]` |
| **HU084** | Consultar distribución de materias por semestres | Vista `uv_asignatura` | `GET /api/v1/coordinador/planes-estudio/{id}/asignaturas`| Visualizador jerárquico de plan de estudios | `[CERTIFICADA]` |
| **HU085** | Crear nueva asignatura en el plan de estudios | SP `usp_crear_asignatura` | `POST /api/v1/coordinador/planes-estudio/{id}/asignaturas` | Modal de alta de materia con créditos y código | `[CERTIFICADA]` |
| **HU086** | Filtros de materias por área y componente | Filtro en frontend con Signals | Query params en endpoint de asignaturas | Filtros combinados de búsqueda en frontend | `[CERTIFICADA]` |
| **HU087** | Actualizar créditos y horas de asignatura | SP `usp_actualizar_asignatura` | `PUT /api/v1/coordinador/planes-estudio/{pId}/asignaturas/{aId}` | Formulario de modificación de asignatura | `[CERTIFICADA]` |
| **HU089** | Consultar listado de docentes adscritos al programa| SP `usp_consultar_docentes_programa` | `GET /api/v1/coordinador/docentes` | Tabla de cuerpo docente con estado de vinculación | `[CERTIFICADA]` |
| **HU090** | Selector controlado de tipo de vinculación | Catálogo `TipoVinculacion` (PLA/MTI/CAT/OCA) y vista `uv_tipo_vinculacion` | `GET /api/v1/coordinador/tipos-vinculacion` | Desplegable controlado por tipo de vinculación | `[CERTIFICADA]` |
| **HU091** | Vincular docente al programa y sincronizar IAM | SP `usp_vincular_docente_programa` (fachada + `_interno`) | `POST /api/v1/coordinador/docentes` (aprovisiona Keycloak tras el commit en DB) | Modal de vinculación docente (persona nueva o existente) | `[CERTIFICADA]` |
| **HU092** | Modificar datos profesionales de docente | SP `usp_actualizar_docente_programa` | `PUT /api/v1/coordinador/docentes/{id}` | Formulario de edición docente | `[CERTIFICADA]` |
| **HU093** | Inactivar o reactivar vinculación docente | SP `usp_cambiar_estado_docente_programa` | `PATCH /api/v1/coordinador/docentes/{id}/estado` | Switch de estado con confirmación modal | `[CERTIFICADA]` |
| **HU094** | Ficha docente con historial de grupos dictados | SP pendiente en DB | Endpoint no existe en backend | Ficha con tarjeta resumen de carga académica | `[PENDIENTE]` |
| **HU095** | Directorio consolidado con estado de vinculación | SP pendiente en DB | Endpoint no existe en backend | Directorio en cuadrícula con tarjetas tipadas | `[PENDIENTE]` |
| **HU096** | Crear nuevo período académico (solo Administrador institucional) | SP `usp_crear_periodo_academico` (reescrito) | `POST /api/v1/admin/periodos-academicos` | `AdminPeriodosComponent` (`/app/admin/periodos`) · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU097** | Modificar fechas de inicio y cierre de período (solo Administrador) | SP `usp_actualizar_periodo_academico` | `PUT /api/v1/admin/periodos-academicos/{id}` | `AdminPeriodosComponent` · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU098** | Eliminar período académico sin grupos (decisión de producto 2026-10-25; el cierre masivo queda aparte) | SP `usp_eliminar_periodo_academico` | `DELETE /api/v1/admin/periodos-academicos/{id}` | `AdminPeriodosComponent` · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |

---

## 4. Módulo Decanatura y Gobierno Institucional

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU076** | Agregar nuevo programa académico a la facultad | SP `usp_crear_programa_academico` (fachada + `_interno`) | `POST /api/v1/decano/programas` | `DeanProgramasComponent` (`/app/decano/programas`) | `[CERTIFICADA]` |
| **HU077** | Modificar modalidad y jornada de programa | SP `usp_actualizar_programa_academico` | `PUT /api/v1/decano/programas/{id}` | Modal de edición en `DeanProgramasComponent` | `[CERTIFICADA]` |
| **HU078** | Alternar estado activo/inactivo de programa | SP `usp_cambiar_estado_programa_academico` | `PATCH /api/v1/decano/programas/{id}/estado` | Modal de estado en `DeanProgramasComponent` | `[CERTIFICADA]` |
| **HU102** | Tablero analítico de ausentismo por facultad | SP `usp_consultar_kpis_decano` | `GET /api/v1/decano/indicadores` | `DeanIndicatorsComponent` (`/app/decano/indicadores`) y tarjeta de `overview-dean` sin el 94% quemado | `[CERTIFICADA]` |
| **HU103** | Comparativa gráfica de inasistencias entre programas | SP `usp_consultar_comparativa_programas_facultad` | `GET /api/v1/decano/comparativa-programas` | Barras de ausentismo por programa en `/app/decano/indicadores` | `[CERTIFICADA]` |
| **HU104** | Directorio consolidado de estudiantes de facultad | SP `usp_consultar_estudiantes_facultad_paginado` (ámbito por facultad) | `GET /api/v1/decano/estudiantes` | `DeanEstudiantesComponent` (`/app/decano/estudiantes`) · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU105** | Búsqueda transversal de estudiantes en facultad | SP `usp_consultar_estudiantes_facultad_paginado` (@busqueda) y `usp_consultar_estudiante_facultad_detalle` | `GET /api/v1/decano/estudiantes?busqueda=`, `/decano/estudiantes/{id}` | Buscador y ficha en `DeanEstudiantesComponent` · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU106** | Indicador macro de retención estudiantil | `usp_consultar_kpis_decano` (`tasaRetencion`) | `GET /api/v1/decano/indicadores` | Tarjeta «Retención por asistencia (período vigente)» | `[CERTIFICADA]`
| **HU107** | Consultar estructura institucional de facultades | Vista `uv_facultad` | `GET /api/v1/admin/facultades` | Estructura de facultades en `DeanFaculty` | `[CERTIFICADA]` |
| **HU108** | Consultar programas vigentes y planes de estudio | SP `usp_consultar_programas_academicos` + `usp_consultar_estructura_facultad`; malla con la consulta existente de asignaturas del plan | `GET /api/v1/decano/programas`, `/decano/estructura`, `/decano/planes-estudio/{id}/asignaturas` (rama `feature/HU108-malla-plan-decano`, PR por integrar) | `DeanProgramasComponent` y `DeanPlanMallaComponent` · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU109** | Organigrama jerárquico de dependencias | SP `usp_consultar_estructura_facultad` | `GET /api/v1/decano/estructura` | `DeanEstructuraComponent` (`/app/decano/estructura`) · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU110** | Modificar denominación y atributos de la facultad | SP `usp_actualizar_facultad` (nombre único 3–50) | `PUT /api/v1/admin/facultades/{id}` | Edición en `AdminFacultadesComponent` (`/app/admin/facultades`) | `[CERTIFICADA]` |
| **HU111** | Alternar estado operativo de la facultad | SP `usp_cambiar_estado_facultad` (estado deseado, idempotente, sin cascada) | `PATCH /api/v1/admin/facultades/{id}/estado` | Switch de estado en `AdminFacultadesComponent` | `[CERTIFICADA]` |
| **HU112** | Consultar tabla unificada de programas y créditos | SP no existe en DB | Endpoint no existe en backend | Tabla no implementada | `[PENDIENTE]` |
| **HU113** | Modificar datos de registro calificado | SP no existe en DB | Endpoint no existe en backend | Edición de registro calificado | `[PENDIENTE]` |
| **HU114** | Suspender o reactivar oferta de programa | SP no existe en DB | Endpoint no existe en backend | Switch de estado de oferta académica | `[PENDIENTE]` |
| **HU115** | Validación de coherencia en ofertas académicas | Procedimiento no existe en DB | Endpoint no existe en backend | Validación de reglas al publicar calendario | `[PENDIENTE]` |
| **HU116** | Alta institucional de nueva facultad | SP `usp_crear_facultad` | `POST /api/v1/admin/facultades` | Formulario de creación de facultad en UCO | `[CERTIFICADA]` |
| **HU117** | Reasignar decano responsable de la facultad (la sede no existe en el modelo; deuda técnica) | SP `usp_actualizar_facultad` (decano único por facultad activa) | `PUT /api/v1/admin/facultades/{id}` | Modal "Cambiar Decano(a)" en `AdminFacultadesComponent` | `[CERTIFICADA]` |
| **HU117-B** | Registrar Decano titular y sincronizar cuenta IAM | SP `usp_crear_decano` | `POST /api/v1/admin/decanos` | Formulario de alta institucional en `/app/admin/decanos` | `[CERTIFICADA]` |
| **HU118** | Bloqueo temporal de operaciones de facultad | SP pendiente en DB | Endpoint arroja 501 | Confirmación con credencial de administrador | `[BLOQUEADO 501]` |
| **HU119** | Árbol departamental (Facultad ➔ Programa ➔ Plan) | SP `usp_consultar_estructura_facultad` | `GET /api/v1/decano/estructura` | Árbol plegable en `DeanEstructuraComponent` · E2E en pantalla pendiente | `Fase 3 (FRONTEND)` |
| **HU120** | Crear y asignar Coordinador a Programa | SP `usp_crear_coordinador` | `POST /api/v1/decano/coordinadores` | Modal de alta y asignación de coordinación | `[CERTIFICADA]` |
| **HU121** | Actualizar información del Coordinador | SP `usp_actualizar_coordinador` (fachada + `_interno`) | `PUT /api/v1/decano/coordinadores/{id}` (sincroniza correo y nombres con Keycloak) | Modal de edición en `DeanCoordinadores` | `[CERTIFICADA]` |
| **HU122** | Alternar estado activo/inactivo de Coordinador | SP `usp_cambiar_estado_coordinador` (fachada + `_interno`; rechaza con `COO_001` si tiene programa activo) | `PATCH /api/v1/decano/coordinadores/{id}/estado` (deshabilita o habilita la cuenta en Keycloak) | Switch de activación/suspensión con confirmación modal | `[CERTIFICADA]` |
| **HU123** | Búsqueda predictiva de coordinadores de facultad | Búsqueda reactiva en cliente | Búsqueda sobre `GET /api/v1/decano/coordinadores` | Buscador predictivo en cabecera de tabla | `[CERTIFICADA]` |
| **HU124** | Directorio consolidado de coordinadores | Vista `uv_coordinador` | `GET /api/v1/decano/coordinadores` | Tabla con estado y programa adscrito | `[CERTIFICADA]` |
| **HU125** | Alta de docentes interdepartamentales | SP no existe en DB | Endpoint no existe en backend | Formulario de asignación de doble programa | `[PENDIENTE]` |
| **HU126** | Reasignación de adscripción departamental docente | SP no existe en DB | Endpoint no existe en backend | Modal de transferencia entre programas | `[PENDIENTE]` |
| **HU127** | Gestión de estado y contratos en facultad | SP no existe en DB | Endpoint no existe en backend | Gestión de altas/bajas contractuales | `[PENDIENTE]` |
| **HU128** | Filtro de profesores por programa asignado | SP no existe en DB | Endpoint no existe en backend | Filtro selector por programa en interfaz | `[PENDIENTE]` |
| **HU129** | Reporte tabular de horas contratadas por docente | SP no existe en DB | Endpoint no existe en backend | Tabla de seguimiento de carga académica | `[PENDIENTE]` |
| **HU133** | Indicador KPI global de asistencia en la universidad| SP `usp_consultar_kpis_institucion` | `GET /api/v1/admin/indicadores` | `AdminIndicatorsComponent` (`/app/admin/indicadores`) | `[CERTIFICADA]` |
| **HU134** | Tendencias temporales de ausentismo en reportería | SP `usp_consultar_tendencia_ausentismo` | `GET /api/v1/admin/tendencia-ausentismo` | Gráfica de línea SVG con selector semana/mes | `[CERTIFICADA]` |
| **HU135** | Contador en tiempo real de censo estudiantil | `usp_consultar_kpis_institucion` (censo) | `GET /api/v1/admin/indicadores` | Contador de estudiantes con matrícula activa y registrados; sin actualización push (no hay canal SSE institucional ni eventos de matrícula) | `[PARCIAL]` |
| **HU136** | Contador en tiempo real de censo docente | `usp_consultar_kpis_institucion` (censo) | `GET /api/v1/admin/indicadores` | Contador de docentes con grupo activo y registrados; sin actualización push (no hay canal SSE institucional ni eventos de alta) | `[PARCIAL]` |
| **HU137** | Directorio administrativo institucional (Decanos) | Vista `uv_decano` | `GET /api/v1/admin/decanos` | Directorio de decanos en `/app/admin/decanos` | `[CERTIFICADA]` |
| **HU138** | Ratio de sesiones dictadas con asistencia registrada| `usp_consultar_kpis_institucion` (cumplimiento) | `GET /api/v1/admin/indicadores` | Tarjeta de cumplimiento con sus conteos | `[CERTIFICADA]` |
| **HU139** | Tarjetas comparativas de inasistencia por facultad | SP `usp_consultar_comparativa_facultades` | `GET /api/v1/admin/comparativa-facultades` | Tarjetas por facultad en `/app/admin/indicadores` | `[CERTIFICADA]` |
| **HU140** | Censo de estudiantes agrupado por sedes | Sin tabla de sedes en DB (`/admin/sedes` responde 501) | Endpoint no existe en backend | Gráfico de distribución no implementado | `[BLOQUEADO 501]` |
| **HU141** | Censo de docentes clasificado por escalafón | SP no existe en DB | Endpoint no existe en backend | Gráfica de escalafón no implementada | `[PENDIENTE]` |
| **HU142** | Consulta histórica de períodos académicos | Vista `uv_periodo_academico` | `GET /api/v1/coordinador/periodos-academicos` | Selector de períodos anteriores en reportes | `[CERTIFICADA]` |
| **HU143** | Búsqueda transversal de asignaturas en toda la UCO| SP no existe en DB | Endpoint no existe en backend | Buscador transversal no implementado | `[PENDIENTE]` |
| **HU144** | Censo de grupos activos y tasa de aforo de facultad | SP `usp_consultar_aforo_grupos_facultad` y aforo en `usp_consultar_kpis_decano` | `GET /api/v1/decano/aforo-grupos` | Tabla paginada de aforo con filtro por programa | `[CERTIFICADA]` |
| **HU145** | Cronograma de sesiones en sedes de la facultad | SP `usp_consultar_sesiones_facultad_paginado` (la sesión no modela sede) | `GET /api/v1/decano/sesiones` | `DeanCronogramaComponent` (`/app/decano/cronograma`), sin sede · E2E en pantalla pendiente | `Fase 3 (FRONTEND)`
| **HU146** | Notificación de controversias en justificaciones (Trámite externo)| Trámite externo universitario | Notificación informativa de rechazo docente | Aviso informativo de trámite fuera del sistema | `[CERTIFICADA]` |

---

## 5. Módulo Administración del Sistema y Catálogos Transversales

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU147** | Consultar componentes de formación académica | Vista `uv_componente` | Endpoint no expuesto en backend | Tabla en `DeanFacultyComponent` | `[PENDIENTE]` |
| **HU148** | Crear nuevo componente de formación académica | SP pendiente en DB | Endpoint no existe en backend | Formulario de alta en `DeanFacultyComponent` | `[PENDIENTE]` |
| **HU149** | Actualizar competencias asociadas a un componente | SP pendiente en DB | Endpoint no existe en backend | Edición de competencias curriculares | `[PENDIENTE]` |
| **HU150** | Consultar catálogo de áreas de conocimiento UCO | Vista `uv_area` | `GET /api/v1/admin/areas` | Tabla de áreas en `DeanFacultyComponent` | `[CERTIFICADA]` |
| **HU151** | Crear nueva área de conocimiento institucional | SP `usp_crear_area` (código 3 caracteres inmutable, nombre único) | `POST /api/v1/admin/areas` | Formulario de alta en `AdminAreasComponent` | `[CERTIFICADA]` |
| **HU152** | Modificar datos y estado de un área de conocimiento| SP `usp_actualizar_area`, `usp_cambiar_estado_area` (columna `Area.estado`) | `PUT /api/v1/admin/areas/{id}`, `PATCH /api/v1/admin/areas/{id}/estado` | Edición y switch de estado en `AdminAreasComponent` | `[CERTIFICADA]` |
| **HU153** | Administración de Catálogo: Tipos de Documento | Vista `uv_tipo_identificacion` | `GET /api/v1/tipos-identificacion` (solo lectura) | Mantenimiento de catálogo en `AdminCatalogs` | `[PARCIAL]` |
| **HU154** | Administración de Catálogo: Tipos de Programa | SP `usp_crear_tipo_programa`, `usp_actualizar_tipo_programa`, `usp_cambiar_estado_tipo_programa` | `GET/POST /api/v1/admin/tipos-programa`, `PUT /{id}`, `PATCH /{id}/estado` | `AdminCatalogsComponent` (`/app/admin/catalogs`) | `[CERTIFICADA]` |
| **HU155** | Administración de Catálogo: Estados del Sistema | Vista `uv_estado` | Sin endpoint REST de administración | Configuración en UI | `[PARCIAL]` |
| **HU156** | Admisión demográfica y creación de usuario estudiante| SP `usp_sincronizar_estudiante_interno` | Endpoint `/admin/estudiantes/admision` no existe | Formulario de admisión en `CoordinatorStudents` | `[PENDIENTE]` |
| **HU157** | Ficha unificada del estudiante con historial completo| SP no existe en DB | Endpoint no existe en backend | Ficha unificada no implementada | `[PENDIENTE]` |
| **HU158** | Consultar padrón unificado de estudiantes de la UCO | Vista `uv_auth_estudiante` | `GET /api/v1/coordinador/estudiantes` | Tabla con filtros y paginación en `Coordinator` | `[CERTIFICADA]` |
| **HU159** | Actualizar datos personales y contacto de estudiante | SP pendiente en DB | Endpoint no existe en backend | Modal de edición de contacto | `[PENDIENTE]` |
| **HU160** | Modificar estado institucional (Matriculado, Retiro)| SP pendiente en DB | Endpoint no existe en backend | Selector de estado institucional con auditoría | `[PENDIENTE]` |
| **HU161** | Registrar nueva institución de convenio o práctica | SP pendiente en DB | `POST /api/v1/admin/instituciones` (arroja 501) | `AdminCatalogsComponent` (`/app/admin/catalogos`)| `[BLOQUEADO 501]` |
| **HU162** | Modificar datos de institución colaboradora | SP pendiente en DB | `PUT /api/v1/admin/instituciones/{id}` (arroja 501) | Formulario de modificación de convenio | `[BLOQUEADO 501]` |
| **HU163** | Consultar listado de instituciones de convenio | Vista `uv_institucion` | `GET /api/v1/admin/instituciones` | Tabla de entidades externas en convenio | `[CERTIFICADA]` |
| **HU164** | Alternar estado activo/inactivo de institución | SP pendiente en DB | `PATCH .../instituciones/{id}/toggle-estado` (501) | Switch de activación de convenios | `[BLOQUEADO 501]` |
| **HU168** | Configurar parámetros generales (Límite 20%, Días) | Vista `uv_parametro` | `GET /api/v1/admin/parametros` (Lectura OK; PUT 501)| `AdminSystemComponent` (`/app/admin/sistema`) | `[PARCIAL]` |
| **HU169** | Configurar catálogo centralizado de mensajes | SP `usp_obtener_mensaje_catalogo` | Endpoint de modificación no expuesto | Consola de mensajes técnicos | `[PENDIENTE]` |
| **HU170** | Sincronización batch de usuarios Keycloak a BD | SP `usp_sincronizar_usuario_interno` | Endpoint no expuesto en backend | Consola batch en UI | `[PENDIENTE]` |
| **HU171** | Registro e inscripción manual masiva por secretaría | SP `usp_registrar_estudiante_en_programa_interno`| Endpoint no expuesto en backend | Consola batch en UI | `[PENDIENTE]` |
| **HU172** | Registro de auditoría forense de cambios de asistencia | SP pendiente en DB | `GET /api/v1/admin/auditoria` (arroja 501) | Tabla de auditoría en `AdminSystemComponent` | `[BLOQUEADO 501]` |
| **HU173** | Validación algorítmica preventiva de solapamientos | SP `usp_validar_horarios_grupo_interno` | Algoritmo en `CrearSesionUseCase` | Alerta visual en interfaz de horarios | `[CERTIFICADA]` |
| **HU174** | Cierre masivo automático de período y actas de faltas| SP `usp_ejecutar_cierre_masivo_periodo` | `POST /api/v1/admin/cierre-masivo` | Consola de cierre semestral con confirmación | `[CERTIFICADA]` |

---

## 6. Módulo Especial: Auto-Asistencia, Matrícula QR y Métodos Autónomos

| Código | Historia de Usuario (Requerimiento) | Base de Datos (SQL Server 2022+) | Backend API (Spring Boot / Hexagonal) | Frontend Web (Angular 19 OnPush) | Fase SDD / Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **HU175** | Proyección en pantalla de QR dinámico y PIN (TTL 60s)| SP pendiente en DB | `GET /api/v1/sesiones/{sesionId}/qr-token` (arroja 501)| Modal de proyección (flag `sessionQrEnabled: false`)| `[BLOQUEADO 501]` |
| **HU176** | Auto-registro de asistencia con validación WI-FI CAMPUS| SP `usp_registrar_asistencia_estudiante_autonomo`| `POST /api/v1/estudiante/asistencia-qr` | Lector QR móvil con verificación de IP Wi-Fi UCO| `Fase 3 (FRONTEND)` |
| **HU176B**| Matrícula autónoma por QR de curso proyectado por docente| SP pendiente en DB | `POST /api/v1/estudiante/matricular-grupo` (arroja 501)| Escaneo móvil de QR de matrícula del curso | `[BLOQUEADO 501]` |

---

## Resumen Cuantitativo del Estado Real del Catálogo

| Estado Técnico | Cantidad | % Catálogo | Descripción |
| :--- | :---: | :---: | :--- |
| **`[CERTIFICADA]`** | **99** | **57.9%** | Totalmente funcional y verificada en DB, Backend y Frontend sin errores ni mocks. |
| **`Fase 3 (FRONTEND)`** | **18** | **10.5%** | DB y Backend con endpoints reales listos; interfaz en proceso de ajuste o conexión. |
| **`[BLOQUEADO 501]`** | **12** | **7.0%** | Interfaz presente en Angular, pero el Backend lanza `FeatureUnavailableException` (HTTP 501). |
| **`[PARCIAL]`** | **11** | **6.4%** | Soporte parcial en refinamiento técnico o funcionalidad exclusiva de lectura/catálogo. |
| **`[PENDIENTE]`** | **30** | **17.5%** | Catalogadas en pipeline, pendientes de diseño DDL/SP en SQL Server y endpoints en Spring Boot. |
| **`[DESCARTADA]`** | **1** | **0.6%** | Retirada del alcance por decisión del responsable (HU025, 2026-10-29). |
| **TOTAL** | **171** | **100%** | **Catálogo maestro sincronizado con la realidad del código.** |

---

## Documentos Relacionados
* [Guía Rápida de Flujo de Trabajo](./guia-flujo-trabajo-sdd.md) - Inducción para nuevos chats y agentes.
* [Especificaciones de Historias de Usuario (SDD)](file:///c:/Proyectos/GestioAsistencia/.specify/specs/) - Especificaciones funcionales y contratos WORM.
* [Arquitectura Integral](./arquitectura-integral.md) - Modelo de referencia por capas.
* [Guía Operativa y Reglas de Construcción](../AGENTS.md) - Principios innegociables UCO y concisión del 70%.
