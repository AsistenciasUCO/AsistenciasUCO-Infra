# 📐 Plan Técnico de Arquitectura e Implementación: Registro de Asistencia

> **Documento:** `docs/specs/001-registro-asistencia-estudiante/plan.md`  
> **HU Asociada:** [HU027](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md) — Registro en vivo de asistencia por sesión  
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

- **Smart Database (SQL Server 2022+):** Control transaccional atómico con `SET XACT_ABORT ON;` y bloqueo `UPDLOCK, HOLDLOCK` para evitar duplicidad de registros en tomas concurrentes.
- **Backend Hexagonal (Clean Architecture):** `AsistenciaController` desacoplado de la persistencia vía puerto primario `RegistrarAsistenciaInputPort`. La persistencia reside en `AsistenciaRepositorySqlServerAdapter` con `JdbcTemplate`.
- **Seguridad por Ámbito:** Validación de titularidad de grupo vía `UserScopeService` antes de persistir.
- **Reactividad Push (SSE):** Emisión del evento `ASISTENCIA_REGISTRADA` vía `RealtimePublisherPort` (`/api/v1/realtime/stream`), consumido por Angular Signals sin polling ni `setInterval`.

---

## 2. Capa de Base de Datos (`GestioAsistenciaDB`)

### 2.1 Tablas Involucradas
- `dbo.RegistroAsistencia`: `id` (PK, UUID), `estudianteGrupo` (FK), `sesionClase` (FK), `estadoAsistencia` (FK), `fechaCreacion`, `fechaModificacion`.
- `dbo.EstudianteGrupo`: Validación de matrícula activa.
- `dbo.SesionClase`: Validación de existencia de sesión.
- `dbo.EstadoAsistencia`: Catálogo maestro institucional.

### 2.2 Procedimiento Almacenado: `dbo.usp_registrar_asistencia_estudiante`
- **Ubicación:** `GestioAsistenciaDB/schema/stored-procedures/usp_registrar_asistencia_estudiante.sql`
- **Firma:**
  ```sql
  CREATE OR ALTER PROCEDURE [dbo].[usp_registrar_asistencia_estudiante]
  (
      @idEstudianteGrupo  UNIQUEIDENTIFIER,
      @idGrupoSesion      UNIQUEIDENTIFIER,
      @idEstadoAsistencia UNIQUEIDENTIFIER,
      @idCorrelacion      UNIQUEIDENTIFIER
  )
  ```
- **Lógica Transaccional:**
  - Validación de presencia de `@idCorrelacion`.
  - Validación de matrícula y sesión activa mediante SPs internos.
  - `BEGIN TRANSACTION` con `SELECT id FROM dbo.RegistroAsistencia WITH (UPDLOCK, HOLDLOCK)`.
  - Upsert atómico: `UPDATE` si ya existe; `INSERT` si es nuevo registro.
  - `COMMIT TRANSACTION` o `ROLLBACK TRANSACTION` en bloque `CATCH`.
  - Resultset estándar: `{ idResultado, exitoso, mensajeUsuario, mensajeTecnico }`.

---

## 3. Capa de Backend (`GestioAsistenciaBackend`)

### 3.1 Flujo Hexagonal
```text
AsistenciaController (@RestController)
     │
     ▼
RegistrarAsistenciaInputPort (Primary Port)
{{ ... }}
     ▼
AsistenciaRepositorySqlServerAdapter (Secondary Adapter con JdbcTemplate)
```

### 3.2 Componentes Concretos
- **Controlador:** `AsistenciaController` (`POST /api/v1/asistencias`).
  - Valida payload con `RegistrarAsistenciaRequestValidator`.
  - Verifica titularidad docente con `UserScopeService.validateTeacherOwnershipOfSession()`.
- **Puertos y Casos de Uso:**
  - Puerto Primario: `RegistrarAsistenciaInputPort`.
  - Interactor: `RegistrarAsistenciaUseCaseImpl`.
  - Puerto Secundario: `AsistenciaRepositoryPort`.
- **Adaptador JDBC:** `AsistenciaRepositorySqlServerAdapter` invocando `dbo.usp_registrar_asistencia_estudiante`.
- **Observabilidad y Real-Time:**
  - Propaga `CorrelationIdContext.get()` en logs estructurados (`Logstash JSONL`).
  - Difunde evento reactivo vía `RealtimePublisherPort` (`ReactorRealtimeAdapter`).

---

## 4. Capa de Frontend (`GestioAsistenciaFrontend`)

### 4.1 Componente e Interfaz
- **Ruta:** `/app/asistencia`
- **Componente:** `AttendanceControlComponent` (`src/app/features/attendance/attendance-control/`).
- **Diseño:** Aurora Education System con Tailwind CSS v4, badges de estado y `ChangeDetectionStrategy.OnPush`.

### 4.2 Reactividad con Signals y SSE
- **Servicio:** `attendance-realtime-sync.service.ts` conectado a `/api/v1/realtime/stream` con Bearer JWT.
- **Prohibición de Polling:** Sin `setInterval` ni peticiones HTTP recurrentes.
- **Señales:** `sessionStudents = signal<StudentAttendanceItem[]>([])`, `isLoading = signal<boolean>(false)`, `summary = computed(...)`.

---

## 5. Pruebas y Validación Técnica

- **Base de Datos:** Suite T-SQL `test_suite.sql` (`exitoso = 1`, `@@TRANCOUNT = 0`).
- **Backend:** Pruebas unitarias y ArchUnit (`.\mvnw.cmd test`).
- **Frontend:** Pruebas CI (`npm run test:ci`), Quality Gate Realtime (`npm run coverage:realtime:check`), build (`npm run build`).
- **E2E:** `scripts/general/tests/test_all_hus.ps1` con usuario `docente1`.

---

## 6. Documentos Relacionados
- [Especificación Funcional (spec.md)](spec.md)
- [Desglose de Tareas (tasks.md)](tasks.md)
- [Arquitectura Integral del Sistema](file:///c:/Proyectos/GestioAsistencia/docs/arquitectura-integral.md)
- [Arquitectura Realtime SSE](file:///c:/Proyectos/GestioAsistencia/docs/realtime-sse-architecture.md)
- [Catálogo de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
