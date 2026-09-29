---
status: closed
type: work-item
scope: full-stack
owner: team-asistencias
last-reviewed: 2026-09-29
---

# WORK ITEM — HU050: Matrícula Manual de Estudiantes por Docente

## 1. Identidad y Alcance
- **Historia de Usuario:** HU050 — Matrícula o registro manual del estudiante por docente
- **Fecha de Cierre:** 2026-09-29
- **Estado:** [CERTIFICADA]

## 2. Implementación por Capas

### A. Base de Datos (GestioAsistenciaDB)
- **Procedimiento Almacenado:** dbo.usp_registrar_estudiante_en_grupo
- **Reglas Validadas:**
  - Control de cupo disponible (usp_validar_cupo_disponible_grupo_interno).
  - Detección y reutilización de identidades de usuario existentes en dbo.Usuario (sin sobreescritura de contraseñas).
  - Prevención de doble matrícula en el mismo grupo (usp_validar_registro_estudiante_en_grupo_interno).
  - Validación de cruces de horario (usp_validar_cruce_horario_estudiante_interno).
  - Autorización RBAC institucional: Exclusivo para DOCENTE, COORDINADOR y ESTUDIANTE (auto-matrícula). El rol ADMINISTRADOR queda explícitamente excluido.

### B. Backend (GestioAsistenciaBackend)
- **Endpoints:**
  - POST /api/v1/grupos/{grupoId}/estudiantes: Matrícula y vinculación de alumnos (autoriza DOCENTE y COORDINADOR, deniega con 403 a ADMINISTRADOR y ESTUDIANTE).
  - GET /api/v1/estudiantes/**: Habilitado para DOCENTE, COORDINADOR y ADMINISTRADOR para posibilitar la consulta previa por documento/correo.
- **Pruebas Automatizadas:** RbacSecurityFilterChainTest (37 de 37 tests PASS en verde).

### C. Frontend (GestioAsistenciaFrontend)
- **Servicio:** student.service.ts (searchStudentByIdentification).
- **Modal Reactivo:** AttendanceEnrollmentModalComponent
  - Búsqueda en tiempo real de alumno por tipo y número de documento.
  - Autocompletado reactivo con Signals de nombres, apellidos y correo.
  - Bloqueo en solo lectura de campos para identidades preexistentes y omisión de campo de contraseña.
- **Validación:** 322 de 322 tests unitarios Karma PASS, compilación de producción con 0 errores.
