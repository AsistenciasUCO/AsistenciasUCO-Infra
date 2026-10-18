# 📐 Plan Técnico de Arquitectura e Implementación: Radicación de Justificaciones

> **Documento:** `docs/specs/002-radicacion-justificaciones-asistencia/plan.md`  
> **HU Asociadas:** [HU010](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md) y [HU014](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)  
> **Especificación:** [`spec.md`](spec.md) | **Tareas:** [`tasks.md`](tasks.md)  
> **Estado:** `[IMPLEMENTADO]`

---

## Índice de Contenidos
1. [Decisiones de Arquitectura y Enfoque Técnico](#1-decisiones-de-arquitectura-y-enfoque-tcnico)
2. [Capa de Base de Datos (GestioAsistenciaDB)](#2-capa-de-base-de-datos-gestioasistenciadb)
3. [Capa de Backend (GestioAsistenciaBackend)](#3-capa-de-backend-gestioasistenciabackend)
4. [Capa de Frontend (GestioAsistenciaFrontend)](#4-capa-de-frontend-gestioasistenciafrontend)
5. [Pruebas y Validación Técnica](#5-pruebas-y-validacin-tcnica)
6. [Documentos Relacionados](#6-documentos-relacionados)

---

## 1. Decisiones de Arquitectura y Enfoque Técnico

- **Smart Database (SQL Server 2022+):** Control transaccional atómico (`SET XACT_ABORT ON;`) con verificación de estado previo de inasistencia e inserción en `dbo.SolicitudRevisionAsistencia`.
- **Backend Hexagonal (Clean Architecture):** Los controladores delegan al puerto primario `RadicarSolicitudRevisionInputPort`. La persistencia pertenece exclusivamente al adaptador secundario `SolicitudRevisionRepositorySqlServerAdapter` con `JdbcTemplate`.
- **Seguridad por Ámbito (Scope Security):** Verificación con `UserScopeService` para comprobar que el estudiante autenticado sea el titular del registro de inasistencia antes de proceder.
- **Notificación Reactiva Push (SSE):** Publicación del evento `RECLAMO_RADICADO` vía `RealtimePublisherPort` (`/api/v1/realtime/stream`) para sincronizar el panel docente en vivo sin polling.

---

## 2. Capa de Base de Datos (`GestioAsistenciaDB`)

### 2.1 Tablas Involucradas
- `dbo.SolicitudRevisionAsistencia`: `id` (PK, UUID), `estudiante` (FK), `registroAsistencia` (FK), `motivoJustificacion` (FK), `descripcion`, `soporteUrl`, `estado` (DEFAULT `'PENDIENTE'`), `fechaRadicacion`.
- `dbo.MotivoJustificacion`: Catálogo maestro de causales normativas.
- `dbo.RegistroAsistencia`: Validación del estado de la inasistencia previa.

### 2.2 Procedimiento Almacenado: `dbo.usp_radicar_solicitud_revision_asistencia`
- **Ubicación:** `GestioAsistenciaDB/schema/stored-procedures/usp_radicar_solicitud_revision_asistencia.sql`
- **Firma Canónica:**
  ```sql
  CREATE OR ALTER PROCEDURE [dbo].[usp_radicar_solicitud_revision_asistencia]
  (
      @idEstudiante          UNIQUEIDENTIFIER,
      @idRegistroAsistencia  UNIQUEIDENTIFIER,
      @idMotivoJustificacion UNIQUEIDENTIFIER,
      @descripcion           NVARCHAR(1000),
      @soporteUrl            NVARCHAR(500) = NULL,
      @idCorrelacion         UNIQUEIDENTIFIER
  )
  ```
- **Lógica Transaccional:**
  - `SET NOCOUNT ON; SET XACT_ABORT ON;`.
  - Validación de existencia de inasistencia previa con estado diferente de `PRESENTE`.
  - Verificación de ausencia de solicitudes duplicadas en estado `PENDIENTE`.
  - `BEGIN TRANSACTION` con inserción del registro en `dbo.SolicitudRevisionAsistencia`.
  - `COMMIT TRANSACTION` o `ROLLBACK TRANSACTION` en bloque `CATCH`.
  - Resultset estándar: `{ idResultado, exitoso, mensajeUsuario, mensajeTecnico }`.

---

## 3. Capa de Backend (`GestioAsistenciaBackend`)

### 3.1 Flujo Hexagonal
```text
EstudiantePortalController (@RestController)
     │
     ▼
RadicarSolicitudRevisionInputPort (Primary Port)
     │
     ▼
RadicarSolicitudRevisionUseCaseImpl (Interactor)
     │
     ▼
SolicitudRevisionRepositoryPort (Secondary Port)
     │
     ▼
SolicitudRevisionRepositorySqlServerAdapter (Secondary Adapter con JdbcTemplate)
```

### 3.2 Componentes Concretos
- **Controlador:** `EstudiantePortalController` (`POST /api/v1/estudiante/reclamos`).
  - Valida el request con Bean Validation (`@Valid`).
  - Invoca `userScopeService.validateStudentOwnershipOfAttendance(request.getIdRegistroAsistencia())`.
- **Puertos y Casos de Uso:**
  - Puerto Primario: `RadicarSolicitudRevisionInputPort`.
  - Interactor: `RadicarSolicitudRevisionUseCaseImpl`.
  - Puerto Secundario: `SolicitudRevisionRepositoryPort`.
- **Adaptador de Persistencia:**
  - `SolicitudRevisionRepositorySqlServerAdapter` invocando Stored Procedure mediante `jdbcTemplate.queryForMap(...)`.
  - Propaga `CorrelationIdContext.get()` y maneja excepciones tipadas (`ConflictException`, `ValidationException`).
- **Evento Real-Time:**
  - Emisión push vía `RealtimePublisherPort` (`ReactorRealtimeAdapter`).

---

## 4. Capa de Frontend (`GestioAsistenciaFrontend`)

### 4.1 Componente e Interfaz
- **Ruta:** `/app/estudiante/materias` (Modal "Radicar Justificación").
- **Componente:** `StudentCoursesComponent` (`src/app/features/student/student-courses/`).
- **Estilos:** Aurora Education System con Tailwind CSS v4 y `ChangeDetectionStrategy.OnPush`.

### 4.2 Servicio y Reactividad con Signals
- **Servicio:** `attendance-claim.service.ts`
- **Señales:** `pendingClaims = signal<AttendanceClaimItem[]>([])`, `isSubmitting = signal<boolean>(false)`.
- **Sincronización Real-Time (SSE):**
  - Conexión a `/api/v1/realtime/stream` (cero polling / `setInterval`).
  - Al recibir `RECLAMO_RESUELTO`, actualiza automáticamente el estado de la falta en pantalla.

---

## 5. Pruebas y Validación Técnica

- **Base de Datos:** Verificación de rollback y persistencia en `test_suite.sql`.
- **Backend:** Pruebas unitarias de casos de uso y compilación con `mvnw compile -DskipTests`.
- **Frontend:** Pruebas unitarias Karma en CI (`npm run test:ci`) y compilación con `npm run build`.
- **E2E:** Suite integral de HUs `scripts/general/tests/test_all_hus.ps1` autenticando `estudiante1`.

---

## 6. Documentos Relacionados
- [Especificación Funcional (spec.md)](spec.md)
- [Desglose de Tareas (tasks.md)](tasks.md)
- [Arquitectura Integral](file:///c:/Proyectos/GestioAsistencia/docs/arquitectura-integral.md)
- [Arquitectura Realtime SSE](file:///c:/Proyectos/GestioAsistencia/docs/realtime-sse-architecture.md)
- [Catálogo de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
