# 📝 Desglose de Tareas: Registro de Asistencia de Estudiante a Clase

> **Documento:** `docs/specs/001-registro-asistencia-estudiante/tasks.md`  
> **HU Asociada:** [HU027](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md) — Registro en vivo de asistencia por sesión  
> **Especificación:** [`spec.md`](spec.md) | **Plan Técnico:** [`plan.md`](plan.md)  
> **Estado:** `[COMPLETADA]`

---

## Índice de Contenidos
1. [Fase 1: Capa de Base de Datos (GestioAsistenciaDB)](#fase-1-capa-de-base-de-datos-gestioasistenciadb)
2. [Fase 2: Capa de Backend (GestioAsistenciaBackend)](#fase-2-capa-de-backend-gestioasistenciabackend)
3. [Fase 3: Capa de Frontend (GestioAsistenciaFrontend)](#fase-3-capa-de-frontend-gestioasistenciafrontend)
4. [Fase 4: Pruebas y Quality Gates](#fase-4-pruebas-y-quality-gates)
5. [Fase 5: Trazabilidad y Cierre](#fase-5-trazabilidad-y-cierre)
6. [Documentos Relacionados](#documentos-relacionados)

---

## Fase 1: Capa de Base de Datos (`GestioAsistenciaDB`)
- [x] **T-1.01:** Verificar existencia de tabla `dbo.RegistroAsistencia` y claves foráneas en `schema/tables/RegistroAsistencia.sql`.
- [x] **T-1.02:** Crear procedimiento almacenado `dbo.usp_registrar_asistencia_estudiante.sql`:
  - [x] Cabecera con `SET ANSI_NULLS ON;` y `SET QUOTED_IDENTIFIER ON;`.
  - [x] `SET NOCOUNT ON;` y `SET XACT_ABORT ON;`.
  - [x] Invocar validaciones internas de correlación, matrícula y sesión activa.
  - [x] Transacción atómica con `SELECT ... WITH (UPDLOCK, HOLDLOCK)` para upsert seguro.
  - [x] Manejar bloque `CATCH` con `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;`.
  - [x] Retornar resultset estándar `{ idResultado, exitoso, mensajeUsuario, mensajeTecnico }`.
- [x] **T-1.03:** Desplegar cambios en SQL Server mediante `deploy_schema.ps1`.
- [x] **T-1.04:** Validar ejecución del SP en `test_suite.sql` asegurando `exitoso = 1` y `@@TRANCOUNT = 0`.

---

## Fase 2: Capa de Backend (`GestioAsistenciaBackend`)
- [x] **T-2.01:** Crear DTOs `RegistrarAsistenciaRequest` y `RegistrarAsistenciaDTO` con validaciones de campos obligatorios.
- [x] **T-2.02:** Definir interfaz de puerto secundario `AsistenciaRepositoryPort` en `application/secondaryports/`.
- [x] **T-2.03:** Implementar adaptador `AsistenciaRepositorySqlServerAdapter`:
  - [x] Invocar Stored Procedure mediante `jdbcTemplate.queryForMap(...)`.
  - [x] Mapear salida y propagar `CorrelationIdContext.get()`.
  - [x] Gestionar excepciones de negocio tipadas (`ResourceNotFoundException`, `ValidationException`).
- [x] **T-2.04:** Definir interfaz de puerto primario `RegistrarAsistenciaInputPort`.
- [x] **T-2.05:** Implementar caso de uso `RegistrarAsistenciaUseCaseImpl` orquestando la persistencia.
- [x] **T-2.06:** Implementar endpoint `POST /api/v1/asistencias` en `AsistenciaController`:
  - [x] Validar titularidad docente de grupo mediante `UserScopeService`.
  - [x] Delegar ejecución exclusivamente al puerto primario (cero `JdbcTemplate` en el controlador).
- [x] **T-2.07:** Emitir evento en tiempo real `ASISTENCIA_REGISTRADA` a través de `RealtimePublisherPort` (`ReactorRealtimeAdapter`).
- [x] **T-2.08:** Verificar compilación de backend con `.\mvnw.cmd compile -DskipTests` (`BUILD SUCCESS`).

---

## Fase 3: Capa de Frontend (`GestioAsistenciaFrontend`)
- [x] **T-3.01:** Definir modelo tipado `StudentAttendanceItem` e interfaces de respuesta en TypeScript (cero `any`).
- [x] **T-3.02:** Crear componente Standalone `AttendanceControlComponent` en `/app/asistencia`.
- [x] **T-3.03:** Implementar servicio de sincronización reactiva `attendance-realtime-sync.service.ts`:
  - [x] Conectar al flujo SSE `/api/v1/realtime/stream` con `@microsoft/fetch-event-source` y Bearer JWT.
  - [x] Prohibir formalmente el uso de timers de polling (`setInterval`).
- [x] **T-3.04:** Gestionar el estado con Angular Signals (`sessionStudents`, `summary`, `isLoading`).
- [x] **T-3.05:** Aplicar sistema de diseño Aurora Education System con Tailwind CSS v4, `ChangeDetectionStrategy.OnPush` y toasts.
- [x] **T-3.06:** Validar compilación de frontend con `npm run build` (**0 errores**).

---

## Fase 4: Pruebas y Quality Gates
- [x] **T-4.01:** Ejecutar pruebas unitarias y de arquitectura: `.\mvnw.cmd test`.
- [x] **T-4.02:** Ejecutar pruebas unitarias de frontend en CI: `npm run test:ci`.
- [x] **T-4.03:** Validar Quality Gate de cobertura en tiempo real: `npm run coverage:realtime:check`.
- [x] **T-4.04:** Validar prueba E2E automatizada con `scripts/general/tests/test_all_hus.ps1`.

---

## Fase 5: Trazabilidad y Cierre
- [x] **T-5.01:** Verificar commits atómicos bajo Conventional Commits (`Refs: HU027`).
- [x] **T-5.02:** Validar registro de HU027 como `[IMPLEMENTADA]` en `docs/historias-de-usuario.md`.
- [x] **T-5.03:** Registrar especificación técnica completa en `docs/specs/README.md`.

---

## Documentos Relacionados
- [Especificación Funcional (spec.md)](spec.md)
- [Plan Técnico de Arquitectura (plan.md)](plan.md)
- [Catálogo de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
- [Arquitectura Integral](file:///c:/Proyectos/GestioAsistencia/docs/arquitectura-integral.md)
