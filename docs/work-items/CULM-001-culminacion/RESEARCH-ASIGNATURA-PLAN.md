# CULM-001 B2 — Investigación: asignatura en varios planes/programas (N:M)

Fecha: 2026-11-06. Solo lectura sobre los worktrees `C:\Proyectos\GestionAsistencia-CULM001\*`. Rutas relativas a cada worktree
(DB = `GestioAsistenciaDB/`, BE = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, FE = `GestioAsistenciaFrontend/src/app/`).

Decisión del responsable: una asignatura puede pertenecer a varios planes/programas (optativas, transversales); en grupos con estudiantes de
varios programas cada coordinador ve solo a los de su programa.

## 1. Modelo actual en BD

DDL (`DB/schema/tables/*.sql`; FKs en `DB/schema/tables/zz_foreign_keys.sql`):

| Tabla | Columnas | FKs / únicas |
| :--- | :--- | :--- |
| `Asignatura` | id, codigo nvarchar(50), nombre nvarchar(50), credito int, area, componente, **semestrePlanEstudio** (NOT NULL), estado bit | FK_Asignatura_Area, FK_Asignatura_Componente, **FK_Asignatura_SemestrePlanEstudio (zz_foreign_keys.sql:140-144)**. Sin UNIQUE en `codigo` (la unicidad global la valida solo `usp_crear_asignatura.sql:141` y `usp_actualizar_asignatura.sql:75` vía `uv_asignatura`) |
| `SemestrePlanEstudio` | id, planEstudio, semestre | FK a PlanEstudio (l.108) y Semestre (l.116). **Sin UNIQUE (planEstudio, semestre)** (lo valida `usp_agregar_semestre_plan_estudio.sql:119`) |
| `PlanEstudio` | id, programa, inp int, estado bit | FK_PlanEstudio_Programa (l.100) |
| `Programa` | id, facultad, tipoDePrograma, nombre, **coordinador NOT NULL**, estado, modalidad?, jornada? | FK Facultad, TipoPrograma, Coordinador, Modalidad, Jornada |
| `Facultad` | id, nombre, institucion, **decano NOT NULL**, estado | FK Institucion, Decano |
| `Grupo` | id, asignatura, periodoAcademico, codigo, nombre, cantidadEstudiantes (+3 contadores), docente | FK_Grupo_Asignatura (l.148). **Grupo no guarda programa ni plan** |
| `EstudiantePrograma` | id, estudiante, programa | FK Estudiante/Programa. **Sin UNIQUE (estudiante, programa)** (lo evitan los SPs con NOT EXISTS) |
| `DocentePrograma` | id, docente, programa, tipoVinculacion, estado, fechaVinculacionUtc | UQ_DocentePrograma_docente_programa |
| `EstudianteGrupo` | id, estado, estudiante, grupo | FKs a EstadoEstudianteGrupo/Estudiante/Grupo. **No guarda con qué programa se matriculó** |

Tablas puente existentes: **ninguna** `AsignaturaPlan*`. **Prerrequisitos no existen**: HU025 descartada (decisión 2026-10-29;
`DB/migrations/07_hu025_descartar_prerrequisitos_up.sql` elimina el stub). No hay `Prerrequisito*` que migrar.

Cadenas de resolución actuales (1 asignatura -> 1 SemestrePlanEstudio -> 1 plan -> 1 programa):
- Programa de una asignatura: `Asignatura.semestrePlanEstudio -> SemestrePlanEstudio.planEstudio -> PlanEstudio.programa -> Programa.facultad/coordinador`.
  En vistas: `uv_asignatura` (`DB/schema/views/uv_asignatura.sql:18-35`, expone `idSemestrePlanEstudio`, `inp`, `nombrePrograma`, `codigoSemestre`) +
  `uv_semestre_plan_estudio` (idPlanEstudio, idPrograma, idSemestre, numeroSemestre) + `uv_plan_estudio`.
- Programa de un grupo: `Grupo.asignatura -> (cadena anterior)`. Vista canónica `uv_grupo_programa` (`DB/schema/views/uv_grupo_programa.sql:18-19`:
  idGrupo, idPrograma, idPeriodoAcademico, grupoEstaHablitado). Es **1:1 hoy**; con N:M pasa a **1:N** y duplica filas en todo consumidor.
- Programa de un estudiante: `EstudiantePrograma` (se llena por HU008 solo con asignaturas ESP, ver sección 5) y, en paralelo, "estudiante en grupo del programa" vía `uv_grupo_programa`.

## 2. Consumidores de `Asignatura.semestrePlanEstudio` / `SemestrePlanEstudio`

### 2.1 Tablas/constraints
`Asignatura.sql` (columna), `SemestrePlanEstudio.sql`, `zz_foreign_keys.sql:140-144` (FK 18). Permisos: `schema/security/rol_asistencias_runtime_hu081_hu083.sql:28` (DENY DML sobre SemestrePlanEstudio al rol runtime; la tabla nueva necesita igual tratamiento). `DB/migrations/01_gestionasistenciadb.sql` (baseline) contiene el DDL.

### 2.2 Vistas (joins directos a `Asignatura.semestrePlanEstudio`)
| Vista | Línea | Ámbito que filtra por esta cadena |
| :--- | :--- | :--- |
| `uv_asignatura` | 18, 30-35 | base de casi todo (expone idSemestrePlanEstudio) |
| `uv_grupo_programa` | 17-19 | grupo->programa (base de KPIs/resumen/cumplimiento/aforo/validar estudiante en programa) |
| `uv_auth_grupo` | 29-33 (WHERE 38-56) | **Coordinador** (`pr.coordinador`), **Decano** (`f.decano`), Admin (`f.institucion`) |
| `uv_auth_programa` | 43-45 (docente) | rama Docente (programas donde tiene grupos) |
| `uv_auth_facultad` | 36-38 (docente) | rama Docente |
| `uv_auth_institucion` | 35-37, 46-48 (docente y estudiante) | ramas Docente/Estudiante |

Indirectas (consumen `uv_asignatura`/`uv_semestre_plan_estudio`; con N:M duplican filas):
`uv_grupo` (join `uv_asignatura` l.40; **uv_estudiante_grupo está CONGELADA y depende de uv_grupo**), `uv_docente` (l.46-51), `uv_estudiante` (l.48-53),
`uv_auth_docente`/`uv_auth_estudiante` (filtran coordinador por `pr.id = e.idPrograma`, l.42), `uv_estudiante_programa` (DISTINCT sobre uv_estudiante),
`uv_auth_sesion` (-> uv_auth_grupo), `uv_cumplimiento_sesion_grupo` (l.22), `uv_resumen_asistencia_estudiante_grupo` (l.28), `uv_semestre_plan_estudio`/`uv_plan_estudio` (sin cambio de estructura).

### 2.3 Procedimientos almacenados (join a la cadena)
| SP | Líneas | Uso |
| :--- | :--- | :--- |
| `usp_crear_asignatura` | 24 (@idPlanEstudio), 175 (resuelve SPE por plan+semestre, PLA_004), 192 (INSERT semestrePlanEstudio), 141 (código único global) | HU076B/HU085 crear. **Insertaría fila puente en vez de columna** |
| `usp_actualizar_asignatura` | firma 14-15 (@idPlanEstudio,@semestreNumero); UPDATE 106 no cambia plan/semestre | hoy ignora mover de plan |
| `usp_toggle_estado_asignatura` | sin join a plan | estado global de la asignatura (decidir si pasa a por-plan) |
| `usp_buscar_asignaturas_paginado` | 85-86 (uv_asignatura + uv_semestre_plan_estudio, ámbito decano/admin vía `programasAmbito` 63-68) | decano `/asignaturas` HU084/HU108; 1 fila por asignatura -> pasaría a 1 por (asignatura, plan) |
| `usp_agregar_semestre_plan_estudio` | 119, 136 | alta de semestre (HU082) |
| `usp_quitar_semestre_plan_estudio` | 132-159 (PLA_006 si hay `Asignatura.semestrePlanEstudio` = SPE, l.145) | bloqueo de borrado: debe consultar la tabla puente |
| `usp_consultar_programas_creditos_facultad_paginado` | 64-70 (LEFT JOIN uv_asignatura por SPE; suma créditos por plan) | HU108/decano créditos por plan |
| `usp_consultar_estructura_facultad` | 88-98 (planes y totalSemestres; sin asignaturas) | decano estructura |
| `usp_consultar_oferta_creacion_grupo_docente` | 79 (`a.idSemestrePlanEstudio = spe.id`) | oferta de asignaturas al docente: duplicaría asignatura por plan/programa |
| `usp_consultar_oferta_grupos_estudiante` (HU008) | 93-94 (SPE/plan), 98-111 (ESP por `ep.programa = pe.programa`; BAS/INS por institución) | oferta estudiante: join N:M duplica grupos; necesita DISTINCT/EXISTS |
| `usp_crear_grupo` | 117-119 (docente: `uv_docente_programa.idPrograma = pe.idPrograma`, SEC_002) | HU085/HU087; con N:M basta que el docente tenga vínculo activo con **algún** programa de la asignatura |
| `usp_validar_gestion_asignatura_coordinador_interno` | 63-65 (`@idProgramaAsignatura`) y PASO 4 (titularidad) | coordinador debe coordinar **algún** programa de la asignatura; el `SELECT` de un único programa deja de ser válido |
| `usp_validar_gestion_grupo_coordinador_o_titular_interno` | 102-105 (`SELECT TOP 1 pe.idPrograma`) | `TOP 1` arbitrario con N:M -> debe ser EXISTS sobre programas del coordinador |
| `usp_validar_docente_vinculo_activo_programa_interno` | 34-37 (`TOP 1 idPrograma`; DOC_009 si vínculo inactivo) | idem |
| `usp_registrar_estudiante_en_grupo_interno` | 122-135 (`TOP 1 pe.programa`; inserta `EstudiantePrograma` si ESP) | programa del alumno ambiguo con N:M |
| `usp_resolver_solicitud_ingreso_grupo` | 192-200 (INSERT EstudiantePrograma desde pe.programa) | idem; ya inserta una fila por programa (sin elegir) |
| `usp_consultar_historial_grupos_docente_programa` | 94-97 (`pe.programa = @idPrograma`) | historial de docente por programa: EXISTS sobre puente |
| `usp_consultar_destinatarios_retiro_estudiante_grupo` | 64-67 (Programa -> Coordinador para notificar) | notificaría a **todos** los coordinadores de programas del alumno (hoy 1) |
| `usp_consultar_reenvio_verificacion_correo` | 79-83 (ámbito del coordinador) | idem |
| `usp_consultar_componentes_formacion` | 77 (`COUNT` uv_asignatura por componente) | cuenta por asignatura (sin duplicar) |

Vía `uv_grupo_programa` (heredan el efecto 1:N sin cambiar su texto): `usp_cambiar_estado_programa_academico_interno` (57, regla D4), `usp_consultar_aforo_grupos_facultad` (69),
`usp_consultar_consolidado_asistencia_grupos_paginado` (74), `usp_consultar_historial_estudiante` (115), `usp_consultar_kpis_decano` (61), `usp_consultar_kpis_institucion` (43, 83),
`usp_resolver_periodo_kpi_interno/_facultad_interno/_institucion_interno` (46/44/44), `usp_consultar_sesiones_facultad_paginado` (108), `usp_validar_estudiante_en_programa_interno` (37).

Ámbitos que pasan por la cadena (los que hay que reescribir): **coordinador por programa** = `uv_auth_grupo` (pr.coordinador), `uv_auth_docente`/`uv_auth_estudiante` (pr.id = idPrograma), `usp_resolver_programa_coordinador_interno` (resuelve `TOP 1` programa, l.51-55), `uv_grupo_programa.idPrograma`;
**decano por facultad** = `uv_auth_grupo` (f.decano), `usp_buscar_asignaturas_paginado` (programasAmbito), `usp_consultar_estructura_facultad`, `uv_auth_facultad`.

## 3. Backend

Entidades/vistas JPA (`BE/infrastructure/adapter/secondary/persistence/sqlserver/jpa/entity/`): `UvAsignaturaEntity` (campos idSemestrePlanEstudio, nombrePrograma, codigoSemestre),
`UvSemestrePlanEstudioEntity`, `UvPlanEstudioEntity`, `UvEstudianteProgramaEntity`, `UvEstudianteEntity`, `UvDocenteEntity`, `SpEstructuraFacultadEntity`, `SpComparativaProgramaEntity`, `SpAforoGrupoEntity`, `SpKpisCoordinadorEntity`, `SpFichaEstudianteEntity`.
No hay `@Entity` sobre la tabla `Asignatura`: todo es lectura por vista o EXEC de SP (la tabla puente solo requiere entidad/vista si se leen puentes).

Repositorios con HQL/EXEC afectados (`.../jpa/repository/`):
- `AsignaturaJpaRepository` (HQL_SELECT l.61-65 join `UvAsignatura` + `UvSemestrePlanEstudio`; HQL_POR_PROGRAMA/FACULTAD/PLAN l.67-73; EXEC crear/actualizar l.30-45 con `@idPlanEstudio,@semestreNumero`).
- `PlanEstudioJpaRepository` (HQL_TOTAL_SEMESTRES l.74-78; conteo/créditos por plan l.86-90 `count(a.id), sum(a.credito)` -> con N:M cuenta por plan vía puente; agregar/quitar semestre l.44-54).
- `GrupoJpaRepository` (HQL_GRUPOS_POR_FACULTAD l.86-91: join a asignatura+SPE; duplicaría grupos).
- `OfertaGruposEstudianteJpaRepository`, `OfertaCreacionGruposDocenteJpaRepository`, `DecanoIndicadoresJpaRepository`, `CoordinadorIndicadoresJpaRepository`, `ConsultasTransversalesJpaRepository`, `EstudianteJpaRepository` (HQL_CONTEXTOS sobre `UvEstudianteEntity`), `EstudianteProgramaJpaRepository` (l.25-31: ya parte de `EstudiantePrograma`), `InstitutionalScopeJpaRepository`, `FacultadDecanoJpaRepository`, `ProgramaAcademicoJpaRepository`, `AsignaturaDocenteJpaRepository`, `AsistenciaProgramaJpaRepository` (EXEC `usp_consultar_grupos_paginado`/`sesiones_grupo`/`asistencias_sesion`).
- Mapper `jpa/mapper/AcademicViewJpaProjectionMapper.java:144` (usa `row.idSemestrePlanEstudio()`), `jpa/projection/AsignaturaQueryRow.java`.

Aplicación (`BE/application/`):
- DTO/dominio/proyección con `idSemestrePlanEstudio, idPlanEstudio, idPrograma, nombrePrograma, codigoSemestre`: `features/coordinador/common/dto/AsignaturaDTO.java`, `secondaryports/academic/projection/AsignaturaProjection.java`,
  `consultarasignaturas/{primaryports/mapper/ConsultarAsignaturasMapper, usecase/domain/AsignaturaDomain, usecase/mapper/ConsultarAsignaturasRepositoryMapper}`,
  `consultarasignaturasplan/{primaryports/mapper/ConsultarAsignaturasPlanMapper, usecase/domain/AsignaturaDomain, usecase/mapper/ConsultarAsignaturasPlanRepositoryMapper}`.
- Escritura: `gestionarasignatura/primaryports/dto/GuardarAsignaturaDTO.java` (idPlanEstudio + **semestreNumero**; deberá añadir carácter y soportar asociar a más de un plan), `GestionarAsignaturaMapper`, `GestionarAsignaturaUseCaseImpl`, `AsignaturaCommandPort`/`AsignaturaQueryPort`.
- Planes: `gestionarplanestudio/usecase/impl/GestionarPlanEstudioUseCaseImpl.java`, `PlanEstudioCommandPort`/`QueryPort`, `PlanEstudioProjection`, `consultarplanesestudio/**` (totalSemestres, créditos).
- Docente/estudiante: `docente/consultarofertacreaciongrupos/**` (AsignaturaOfertaDocente DTO/Domain/Mapper), `docente/consultarasignaturas/**`, `docente/consultarasignacionesacademicas/**` (idPlanEstudio), `estudiante/consultarestudianteporid/**` (EstudianteContextoAcademico idPlanEstudio), `estudiante/consultarestudiantes/**`, `consultastransversales/**` (decano/admin).
- Coordinador, alcance por relación: `consultarestudiantesprograma/**`, `consultarfichaestudiante/**`, `consultarkpis/**`, `consultarasistenciaprograma/**`, `indicadores/rule/IndicadoresRules.java`.

Endpoints (`BE/infrastructure/adapter/primary/controller/`):
- Coordinador (`CoordinadorPortalController`, base `/api/v1/coordinador`): GET/POST/PUT `/planes-estudio`, PATCH `/planes-estudio/{id}/toggle-estado`, POST/DELETE `/planes-estudio/{id}/semestres[/{numero}]`,
  GET/POST `/planes-estudio/{id}/asignaturas` (l.111-120), PUT `/planes-estudio/{planId}/asignaturas/{asigId}` (l.126), **DELETE `.../asignaturas/{asigId}` hoy lanza `unavailable()` (l.136)** (candidato natural a "quitar de este plan"), GET `/asignaturas` (l.139), PATCH `/asignaturas/{id}/estado`, GET `/estudiantes`.
  Otros de coordinador: `CoordinadorAsistenciaProgramaController` (`/grupos`, `/grupos/{id}/sesiones`, `/sesiones/{id}/asistencias`), `CoordinadorFichaEstudianteController` (`/estudiantes/{id}/ficha|bitacora`), `CoordinadorIndicadoresController` (`/alertas-tempranas`, KPIs), `ConsolidadoAsistenciaController`.
- Decano: `DecanoPlanEstudioController` GET `/api/v1/decano/planes-estudio/{planId}/asignaturas` (l.35), `DecanoConsultasTransversalesController` GET `/asignaturas` (l.62; usp_buscar_asignaturas_paginado), `DecanoFacultadConsultaController`, `DecanoGrupoController`, `DecanoIndicadoresController` (`/aforo-grupos`).
- Docente: `DocenteOfertaCreacionGruposController` GET `/oferta-creacion-grupos`. Estudiante: `EstudianteOfertaAcademicaController` (`/api/v1/estudiante/oferta-academica`).
- Admin: `AdminConsultasTransversalesController`.

OpenAPI/WORM: `AsistenciasUCO-Infra/docs/contracts/openapi/openapi-golden-path.yaml` **no** incluye planes/asignaturas/coordinador/decano. Solo toca el parámetro `programaId` de `GET /api/v1/estudiantes`
(l.237-240: "Algún contexto académico del estudiante pertenece al programa"), cuya semántica sigue válida. `DB_BASELINE_CONTRACT.md` solo congela la firma de `usp_crear_grupo` (l.79: `@idAsignatura`, sin plan) -> no cambia. Los endpoints de coordinador/decano **no** están en el contrato WORM (springdoc vivo); el cambio no obliga a regenerar hashes salvo que se modifique `/api/v1/estudiantes`.

Prerrequisitos: no existen en backend (HU025 descartada).

## 4. Frontend (`FE/`)

- Modelos: `core/models/role-management.model.ts:272-283` (`AsignaturaPlanItem`: id, **planEstudioId**, codigo, nombre, creditos, **semestre**, area, componente), `core/api/models/{docente-api-dto,estudiante-api-dto}.model.ts` (idPlanEstudio, idPrograma l.30-35), `core/api/models/{asignatura-docente,oferta-creacion-grupos-docente}-api-dto.model.ts`, `core/models/consultas-transversales.model.ts`.
- Servicios: `core/services/coordinator-management.service.ts` (`normalizarAsignaturaPlan` l.78-88; `aSolicitudAsignatura` l.96-105 con `semestreNumero`; `agregarSemestrePlan`/`eliminarSemestrePlan` l.424-429), `core/services/dean-facultad.service.ts` (`planesDeLaEstructura`, idPrograma), `core/services/oferta-academica.service.ts` (ESPECIFICA/BASICA/INSTITUCIONAL), `core/services/course.service.ts`.
- Coordinador: `features/coordinator/coordinator-study-plans/` (`coordinator-study-plans.component.ts`, `components/subject-form.component.ts` [l.39-59 select de semestre del plan; l.159-160 `semestresPlan`], `components/study-plan-mesh.component.ts` [malla por semestre], `components/study-plan-form.component.ts`, `components/study-plans-list.component.ts`, `pages/{study-plan-form,study-plan-mesh,subject-form}-page.component.ts`), `features/coordinator/coordinator-subjects/coordinator-subjects.component.ts` (l.288 `irAMallaPlan(asig.planEstudioId)`: una asignatura -> un plan), `features/coordinator/coordinator-groups`, `coordinator-periods`.
- Decano: `features/dean/dean-plan-malla/dean-plan-malla.component.ts`, `features/dean/dean-asignaturas/dean-asignaturas.component.ts` (l.109 muestra "Plan {{ inpPlanEstudio }}"), `dean-programas/**` (créditos por plan), `dean-faculty`, `dean-cronograma`, `dean-grupo-detalle`.
- Estudiante: `features/student/student-group-offer/student-group-offer.component.ts` (oferta propias/transversales), `student-courses`. Admin: `admin-facultades`, `admin-periodos`.
- Rutas: `app.routes.ts` l.228 `decano/programas/:planId`, l.293 `decano/asignaturas`, l.311 `admin/asignaturas`, l.342-387 `coordinador/planes-estudio[/nuevo|/:planId/editar|/:planId/malla|/:planId/asignaturas/nueva|/:planId/asignaturas/:asignaturaId/editar]`.
- Mocks y specs (cambian con el contrato): `core/interceptors/mock-backend.interceptor(.spec).ts`, `core/mocks/{role-management.mock,mock-consultas-transversales}.ts`, 15 specs que citan planEstudioId/idPlanEstudio/semestre (p. ej. `subject-form.component.spec.ts`, `study-plan-mesh.component.spec.ts`, `coordinator-study-plans.component.spec.ts`, `coordinator-subjects.component.spec.ts`, `dean-asignaturas.component.spec.ts`, `dean-plan-malla.component.spec.ts`).
- No existen componentes de prerrequisitos.

## 5. Ámbito por relación en grupos mixtos

Cómo ve hoy el coordinador a los estudiantes de un grupo (todo por `uv_grupo_programa` = programa de la **asignatura**, no del estudiante):
- `usp_validar_estudiante_en_programa_interno.sql:37`: el estudiante "pertenece" al programa si está en **algún grupo cuya asignatura es del programa** (usado por `usp_consultar_ficha_estudiante_programa`, `usp_consultar_bitacora_estudiante_programa`, `usp_consultar_resumen_asistencia_estudiante_programa`).
- `uv_resumen_asistencia_estudiante_grupo` (l.18-28): `idPrograma = gp.idPrograma`; alimenta `usp_consultar_kpis_coordinador` (l.41-42), `usp_consultar_alerta_temprana_programa` (l.70-71), `usp_consultar_resumen_asistencia_estudiante_programa` (l.47-50). `uv_cumplimiento_sesion_grupo` (cumplimiento de sesiones, programa de la asignatura) alimenta KPIs y bitácora.
- `usp_resolver_periodo_kpi_interno` (l.46-48) elige periodo por `uv_grupo_programa`.
- `usp_consultar_asistencias_sesion_paginado` (l.121-126): `uv_auth_sesion -> uv_auth_grupo` + `uv_estudiante_grupo`, **sin filtro por estudiante**: el coordinador con acceso al grupo ve **todos** los estudiantes de la sesión (fuga en grupos mixtos). Mismo patrón en `usp_consultar_grupos_paginado` (conteos de `uv_auth_grupo`: estudiantesActivos, cuposDisponibles son del grupo completo) y `usp_consultar_sesiones_grupo_paginado`.
- `uv_auth_estudiante` / `usp_consultar_estudiantes_facultad_paginado`: filtra coordinador por `pr.id = e.idPrograma`, con `idPrograma` derivado de uv_estudiante (programa de la asignatura, no del estudiante).
- Listado `GET /coordinador/estudiantes` (`EstudianteProgramaJpaRepository` l.25-31) ya usa `EstudiantePrograma` (`uv_estudiante_programa`), pero la vista exige que el alumno tenga algún contexto en `uv_estudiante` (grupo).
- KPIs de decano/institución cuentan por `uv_grupo_programa` (aforo, consolidado, sesiones, comparativa): con N:M el mismo grupo/estudiante contaría varias veces por programa (comparativa por programa) o dos veces en total (KPIs de facultad/institución si el grupo cae en dos facultades).

Cómo filtrar por `EstudiantePrograma` del programa del coordinador (propuesta técnica):
1. Vista nueva `uv_estudiante_grupo_programa`: `eg JOIN uv_grupo_programa gp ON gp.idGrupo = eg.idGrupo JOIN EstudiantePrograma ep ON ep.estudiante = eg.idEstudiante AND ep.programa = gp.idPrograma`. Cada alumno cuenta una vez por programa suyo que comparte grupo.
2. `usp_validar_estudiante_en_programa_interno`: reemplazar el EXISTS por el join anterior (alumno con `EstudiantePrograma` en `@idPrograma` y en un grupo del programa).
3. `uv_resumen_asistencia_estudiante_grupo` + `usp_consultar_kpis_coordinador`/`alerta_temprana`: añadir `EXISTS EstudiantePrograma(ep.estudiante = eg.idEstudiante AND ep.programa = gp.idPrograma)`.
4. `usp_consultar_asistencias_sesion_paginado` y `usp_consultar_grupos_paginado`: para ejecutor coordinador, filtrar `eg.idEstudiante` por `EstudiantePrograma` de **su** programa y recalcular conteos con ese filtro.
5. **Caso abierto**: HU008 solo crea `EstudiantePrograma` para asignaturas ESP (`usp_registrar_estudiante_en_grupo_interno.sql:126`, `usp_resolver_solicitud_ingreso_grupo.sql:192`); un alumno que toma solo BAS/INS o una optativa de otro programa no tiene fila de programa para ese grupo y quedaría invisible para todos. Opciones: (a) añadir `EstudianteGrupo.programa` (programa bajo el cual se matricula; mejor trazabilidad y KPI sin ambigüedad), (b) mantener solo `EstudiantePrograma` y definir regla de visibilidad para transversales. Requiere decisión de producto.
6. Programa del coordinador: `usp_resolver_programa_coordinador_interno.sql:51-55` hace `TOP 1` (un coordinador = un programa efectivo). Si un coordinador puede coordinar varios programas, todos los SPs de coordinador pasan a lista.

KPI por programa hoy: `usp_consultar_kpis_coordinador` (resumen + cumplimiento por `idPrograma`), `usp_consultar_alerta_temprana_programa`, `usp_consultar_comparativa_programas_facultad`, `usp_consultar_programas_creditos_facultad_paginado`, `usp_consultar_kpis_decano` (por programa, l.61), `usp_consultar_aforo_grupos_facultad` (l.69); KPIs de institución (l.43, 83).

## 6. Datos sembrados

- `DB/schema/seed/13_academico_asignaturas.sql`: 1 `Programa` (B2C3D4E5-...01 "Ingenieria de Sistemas", coordinador F1A2B3C4-...02), 1 `PlanEstudio` (C2D3E4F5-...01, inp 2024), 1 `SemestrePlanEstudio` (D2E3F4A5-...01, semestre S8), 1 `Asignatura` (E2F3A4B5-...01 `ARQ-402` "Arquitectura de Software", 3 créditos, SPE D2E3F4A5-...01), 1 `PeriodoAcademico` 2026-2.
- `14_grupos_sesiones.sql`: 1 `Grupo` (A1B2C3D4-...), 2 `Sesion`, 2 `EstudianteGrupo`, `EstudiantePrograma` insertado desde la regla HU008 (solo componente ESP). `DB/migrations/02_datos_semilla_representativos.sql`: más `EstudianteGrupo`/`Sesion`/`Asistencia` sobre ese grupo.
- **No hay ninguna asignatura compartida de hecho**: un solo plan, un solo código (y `codigo` es único global por SP). La migración de datos es 1 fila -> 1 fila puente, sin conflictos. En bases de desarrollo existentes (creadas desde la UI) puede haber más; el script debe validar duplicados `UPPER(TRIM(codigo))` y avisar.
- `DB/scripts/maintenance/hu008_depurar_estudiante_programa_transversales.sql` ya limpia `EstudiantePrograma` de transversales.

Diseño de migración sugerido (idempotente, numerada tras `12_*`):
1. Crear `AsignaturaPlanEstudio(id, asignatura, semestrePlanEstudio, caracter FK a catálogo, estado)` con UNIQUE (asignatura, semestrePlanEstudio); considerar guardar también `planEstudio` + UNIQUE (asignatura, planEstudio) para impedir dos semestres del mismo plan. Catálogo de carácter (obligatoria/optativa) en vez de literales (regla "cero datos quemados"). FKs en `zz_foreign_keys.sql`, DENY DML al rol runtime como en `rol_asistencias_runtime_hu081_hu083.sql`.
2. `INSERT ... SELECT id, semestrePlanEstudio, obligatoria FROM Asignatura` (todas obligatorias por defecto).
3. Reescribir vistas/SPs (sección 2); `uv_asignatura` debe pasar a 1 fila por (asignatura, plan) **o** dividirse: `uv_asignatura` (catálogo, sin plan) + `uv_asignatura_plan` (con plan/semestre/carácter) para que `uv_grupo`, `uv_docente`, `uv_estudiante` y la vista congelada `uv_estudiante_grupo` no dupliquen.
4. Quitar `Asignatura.semestrePlanEstudio` y `FK_Asignatura_SemestrePlanEstudio` en una migración posterior (transición: columna nullable + doble escritura si hay despliegue por fases); incluir `_down.sql`.
5. Seed 13: añadir fila puente; opcional sembrar una optativa compartida entre dos planes para probar.

## 7. Riesgos y pruebas que fijan el modelo

Objetos del manifiesto congelado (`DB/scripts/freeze-manifest.ps1`): `uv_estudiante_grupo.sql` (congelada, **depende de `uv_grupo` -> `uv_asignatura`**; no se edita pero su resultado cambia si `uv_grupo` duplica filas), `uv_asistencia`, `uv_detalle_asistencia`, `uv_sesion`, `uv_horario_docente`, `usp_crear_sesion/actualizar_sesion/generar_sesiones_grupo/registrar_asistencias_sesion` (estos no unen a plan). `DB_BASELINE_CONTRACT.md` fija `usp_crear_grupo(@idAsignatura, ...)`: la firma debe conservarse; la lógica interna (PASO 2B) sí cambia. Ningún objeto congelado referencia `SemestrePlanEstudio` en texto, por lo que no se rompen hashes si no se tocan sus archivos; el riesgo es de comportamiento (duplicación).

Pruebas T-SQL que citan `SemestrePlanEstudio`/`semestrePlanEstudio` (30 de 109 archivos en `DB/test/`): `test_authorized_views_rbac`, `test_consultas_transversales_hu112_hu157`, `test_cruce_horario_docente`, `test_hu008_regla_inscripcion_programa`, `test_ident001_correo_verificacion`, `test_rec2_rbac_asignatura`, `test_ufn_clasificar_permanencia`, `test_usp_abrir_ventana_matricula_grupo`, `test_usp_cambiar_estado_docente_programa`, `test_usp_cambiar_estado_programa_academico`, `test_usp_consultar_{aforo_grupos_facultad,alerta_temprana_programa,bitacora_estudiante_programa,comparativa_facultades,comparativa_programas_facultad,ficha_estudiante_programa,historial_grupos_docente_programa,kpis_coordinador,kpis_decano,kpis_institucion,oferta_creacion_grupo_docente,oferta_grupos_estudiante,tendencia_ausentismo}`, `test_usp_guardar_horarios_grupo`, `test_usp_plan_estudio_estado_semestres`, `test_usp_precargar_sesiones_{concurrency.ps1,grupo}`, `test_usp_resolvers_{decano,institucion_admin}`, `test_usp_retirar_estudiante_grupo`, `test_uv_resumen_asistencia_estudiante_grupo`. Insertan directo `Asignatura(..., semestrePlanEstudio)`; al quitar la columna fallan en el arrange y deben actualizarse (cambio de fixture justificado por el cambio de modelo, no por conveniencia; AGENTS sección 4).

Backend (6 archivos con `SemestrePlanEstudio`/`semestrePlan` y ~25 con planEstudio): `GestionarPlanEstudioUseCaseImplTest`, `GestionarAsignaturaUseCaseImplTest`, `GestionarAsignaturaMapperTest`, `PlanEstudioJpaRepositoryTest`, `AsignaturaJpaCommandPatternTest`, `PlanEstudioJpaCommandPatternTest`, `AcademicUserParityFixture`/`AcademicUserJdbcBaselineOracle`/`baseline/AsignaturaJdbcBaseline`/`baseline/PlanEstudioJdbcBaseline` (oráculos de paridad JDBC vs JPA que fijan HQL y firmas), `AcademicQueryJpaParityIT`, `AcademicUserCommandsSpParityIT`/`SuccessParityIT`, `CoreViewQueriesJpaParityIT`, `SqlStoredProcedureContractIT`, `UsuarioPlanEstudioProvidersSqlServerIT`, `ViewEntityProjectionMappingTest`, `AcademicViewJpaProjectionBehaviorTest`, `DbFailureClassifierPlanEstudioTest`, `ConsultarPlanesEstudio*Test`, `CoordinadorPortalControllerTest`, `DecanoPlanEstudioControllerTest`, `DecanoConsultasTransversalesControllerTest`, `ConsultasTransversalesJpaRepositoryTest`, `FacultadDecanoJpaRepositoryTest`, `EstudianteJpaQueryContractTest`, `LecturaPorFacultadJpaPatternTest`, `JpaQueryAdapterContractTest`. ArchUnit (`src/test/.../architecture/*`): `JpaRepositoryArchitectureRulesTest` cita planEstudio; las reglas de Clean Architecture no fijan el modelo, pero cualquier repositorio/entidad nuevo debe respetar `JpaIsolationRulesTest` y `ControllersMustDependOnlyOnInputPortsTest`.
Frontend: 15 specs con planEstudioId/idPlanEstudio/semestre (sección 4) + `mock-backend.interceptor.spec.ts`.

## Recuento de objetos afectados por capa (aproximado)

- BD: 3 tablas tocadas (Asignatura, SemestrePlanEstudio, zz_foreign_keys) + 1 nueva + permisos; 6 vistas con join directo + ~9 indirectas; ~19 SPs con join directo + ~17 por `uv_grupo_programa`/vistas; seeds 13/14 y migración nueva; 30 tests T-SQL.
- Backend: ~12 repositorios JPA, ~11 entidades/proyecciones, ~45 clases de aplicación (DTO/Domain/Mapper/UseCase/Port), ~12 controladores/endpoints, ~30 tests.
- Frontend: ~15 componentes/páginas, ~5 servicios/modelos, 8 rutas, ~15 specs + mocks.
- Contratos WORM: 0 cambios obligatorios (solo semántica de `programaId` en `/api/v1/estudiantes`).

## Riesgos principales

1. **Duplicación de filas por join 1:N** en `uv_asignatura` -> `uv_grupo` -> `uv_estudiante_grupo` (congelada), `uv_docente`, `uv_estudiante`, `uv_grupo_programa` y todos los KPI/aforo/consolidado: conteos inflados y paginación (`COUNT(*) OVER()`) incorrecta. Mitigación: separar `uv_asignatura` (catálogo) de `uv_asignatura_plan`, y que `uv_grupo_programa` sea explícitamente 1:N con consumidores usando EXISTS/DISTINCT; ejecutar `test_uv_resumen_asistencia_estudiante_grupo` y los `test_usp_consultar_kpis_*`/aforo con una asignatura compartida.
2. **Ambigüedad de "el programa" del grupo/estudiante y fuga de datos entre coordinadores**: `TOP 1 pe.programa` en `usp_registrar_estudiante_en_grupo_interno`, `usp_validar_gestion_*`, `usp_validar_docente_vinculo_*`, `usp_resolver_programa_coordinador_interno`; `usp_consultar_asistencias_sesion_paginado` y `usp_consultar_grupos_paginado` exponen a todos los alumnos del grupo; alumnos de transversales (sin `EstudiantePrograma`) quedarían invisibles. Requiere decidir `EstudianteGrupo.programa` vs solo `EstudiantePrograma` antes de implementar.
3. **Migración y pruebas**: quitar `Asignatura.semestrePlanEstudio` rompe 30 tests T-SQL, oráculos de paridad JDBC/JPA y fixtures (actualizarlos por cambio de modelo, no relajarlos); SQL no tiene UNIQUE (plan, semestre) ni (código) y `usp_crear_asignatura` valida código único global, lo que choca con "misma asignatura en varios planes" (debe asociarse la existente en vez de crear otra); `usp_toggle_estado_asignatura` y `usp_quitar_semestre_plan_estudio` deben redefinir semántica (estado global vs por plan; bloqueo por puente). Orden recomendado: puente + backfill + doble lectura -> vistas/SPs -> backend/FE -> retirar columna.
