# WORK ITEM: HU129, HU141 - Reporte de Carga Académica Docente y Escalafón Institucional

## 1. Identificación y Alcance
- **ID del Paquete:** P11 (Analítica de Planta Docente, Carga Horaria y Escalafón)
- **Historias de Usuario:**
  - **HU129:** Reporte tabular y analítico de horas contratadas y asignadas por docente en la facultad/carrera.
  - **HU141:** Censo institucional de docentes clasificado por escalafón académico y tipo de vinculación.
- **Rol Primario:** Administrador Institucional (`ROLE_ADMINISTRADOR`) y Decanatura (`ROLE_DECANO`).
- **Ruta de Trabajo:** `GestioAsistenciaBackend/docs/work-items/HU129-HU141-analitica-docente-carga-escalafon/`

## 2. Objetivos
- Exponer endpoint unificado `GET /api/v1/admin/docentes/analitica-carga-escalafon` que retorne:
  - `distribucionEscalafon`: Censo de docentes clasificados por categorías institucionales (Titular, Asociado, Asistente, Auxiliar, Cátedra).
  - `distribucionVinculacion`: Clasificación por tipo de contrato (Tiempo Completo, Medio Tiempo, Cátedra/Horas).
  - `promedioHorasSemanales`: Media de horas lectivas asignadas.
  - `docentesCarga`: Listado tabular detallado con docente, escalafón, vinculación, grupos asignados y total de horas semanales contratadas/dictadas.
- Integrar la visualización en el Frontend en `DeanFacultyComponent` y `AdminSystemComponent` mediante Bento Cards y tabla de distribución con reactividad gobernada por Signals.

## 3. Arquitectura y Puertos
- **Clean Architecture & Puertos:**
  - DTOs: `AnaliticaDocenteCargaDTO`, `DocenteCargaItemDTO`, `EscalafonDocenteItemDTO`.
  - Puerto Primario: `ConsultarAnaliticaDocenteInputPort`.
  - Caso de Uso: `ConsultarAnaliticaDocenteUseCaseImpl`.
  - Puerto Secundario: `AnaliticaDocenteQueryPort`.
  - Adaptador Secundario: `AnaliticaDocenteJpaRepository`.
  - Adaptador Primario: `AdminAnaliticaDocenteController` expuesto en `/api/v1/admin/docentes/analitica-carga-escalafon`.
- **Frontend:**
  - Modelo `TeacherLoadAndRankAnalytics` en `teacher-load-rank-analytics.model.ts`.
  - Servicio `AdminManagementService.getAnaliticaDocenteCargaEscalafon()`.
  - Sección visual analítica interactiva.

## 4. Criterios de Aceptación
1. `GET /api/v1/admin/docentes/analitica-carga-escalafon` retorna `200 OK` con `ApiDataResponse<AnaliticaDocenteCargaDTO>`.
2. Las sumas y porcentajes por categoría de escalafón son consistentes y libres de divisiones por cero.
3. El frontend consume la respuesta con Signals reactivos y cero sondeos/polling periódico.
