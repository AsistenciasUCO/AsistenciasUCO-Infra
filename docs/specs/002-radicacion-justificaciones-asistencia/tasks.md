# 📝 Desglose de Tareas: Radicación de Justificaciones de Asistencia

> **Documento:** `docs/specs/002-radicacion-justificaciones-asistencia/tasks.md`  
> **HU Asociadas:** [HU010](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md) y [HU014](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)  
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
- [x] **T-1.01:** Verificar existencia de tabla `dbo.SolicitudRevisionAsistencia` y catálogo `dbo.MotivoJustificacion`.
- [x] **T-1.02:** Crear procedimiento almacenado `dbo.usp_radicar_solicitud_revision_asistencia.sql`:
  - [x] Cabecera con `SET ANSI_NULLS ON;` y `SET QUOTED_IDENTIFIER ON;`.
  - [x] `SET NOCOUNT ON;` y `SET XACT_ABORT ON;`.
  - [x] Validar que el registro de asistencia previo exista y no esté en estado `PRESENTE`.
  - [x] Validar que no exista otra solicitud en estado `PENDIENTE` para la misma sesión.
  - [x] Transacción atómica con `BEGIN TRANSACTION ... COMMIT TRANSACTION`.
  - [x] Manejar bloque `CATCH` con `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;`.
  - [x] Retornar resultset estándar `{ idResultado, exitoso, mensajeUsuario, mensajeTecnico }`.
- [x] **T-1.03:** Desplegar cambios en SQL Server mediante `deploy_schema.ps1`.
- [x] **T-1.04:** Validar ejecución del SP en `test_suite.sql` confirmando `exitoso = 1` y `@@TRANCOUNT = 0`.

---

## Fase 2: Capa de Backend (`GestioAsistenciaBackend`)
- [x] **T-2.01:** Crear DTO `RadicarSolicitudRevisionRequest` con validaciones de campos obligatorios.
- [x] **T-2.02:** Definir interfaz de puerto secundario `SolicitudRevisionRepositoryPort`.
- [x] **T-2.03:** Implementar adaptador `SolicitudRevisionRepositorySqlServerAdapter`:
  - [x] Invocar Stored Procedure mediante `jdbcTemplate.queryForMap(...)`.
  - [x] Propagar `CorrelationIdContext.get()` en la llamada.
  - [x] Lanzar excepciones tipadas (`ConflictException`, `ValidationException`).
- [x] **T-2.04:** Definir interfaz de puerto primario `RadicarSolicitudRevisionInputPort`.
- [x] **T-2.05:** Implementar caso de uso `RadicarSolicitudRevisionUseCaseImpl`.
- [x] **T-2.06:** Implementar endpoint `POST /api/v1/estudiante/reclamos` en `EstudiantePortalController`:
  - [x] Validar pertenencia del estudiante a la inasistencia mediante `UserScopeService`.
  - [x] Delegar exclusivamente al puerto primario (cero `JdbcTemplate` en el controlador).
- [x] **T-2.07:** Emitir evento push `RECLAMO_RADICADO` vía `RealtimePublisherPort` (`ReactorRealtimeAdapter`).
- [x] **T-2.08:** Verificar compilación de backend con `.\mvnw.cmd compile -DskipTests` (`BUILD SUCCESS`).

---

## Fase 3: Capa de Frontend (`GestioAsistenciaFrontend`)
- [x] **T-3.01:** Definir interfaces TypeScript tipadas en `attendance-claim.models.ts`.
- [x] **T-3.02:** Crear modal de radicación en `StudentCoursesComponent` (`/app/estudiante/materias`).
- [x] **T-3.03:** Implementar llamadas HTTP en `attendance-claim.service.ts` consumiendo `${environment.apiUrl}` (sin mocks).
- [x] **T-3.04:** Manejar estado reactivo con Angular Signals (`pendingClaims`, `isSubmitting`).
- [x] **T-3.05:** Escuchar eventos SSE del canal `/api/v1/realtime/stream` para actualizar el badge de estado en vivo sin polling.
- [x] **T-3.06:** Validar compilación de frontend con `npm run build` (**0 errores**).

---

## Fase 4: Pruebas y Quality Gates
- [x] **T-4.01:** Ejecutar pruebas unitarias de backend: `.\mvnw.cmd test`.
- [x] **T-4.02:** Ejecutar pruebas de frontend en CI: `npm run test:ci`.
- [x] **T-4.03:** Validar Quality Gate de cobertura en tiempo real: `npm run coverage:realtime:check`.
- [x] **T-4.04:** Validar prueba E2E de historias de estudiante: `scripts/general/tests/test_all_hus.ps1`.

---

## Fase 5: Trazabilidad y Cierre
- [x] **T-5.01:** Registrar commits atómicos con Conventional Commits (`Refs: HU010`, `Refs: HU014`).
- [x] **T-5.02:** Validar registro de HU010 y HU014 como `[IMPLEMENTADA]` en `docs/historias-de-usuario.md`.
- [x] **T-5.03:** Actualizar índice maestro en `docs/specs/README.md`.

---

## Documentos Relacionados
- [Especificación Funcional (spec.md)](spec.md)
- [Plan Técnico de Arquitectura (plan.md)](plan.md)
- [Catálogo de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
- [Arquitectura Integral](file:///c:/Proyectos/GestioAsistencia/docs/arquitectura-integral.md)
