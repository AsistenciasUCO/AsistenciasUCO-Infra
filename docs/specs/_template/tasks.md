# 📝 Desglose de Tareas de Implementación: [Nombre de la Funcionalidad]

> **Documento:** `docs/specs/_template/tasks.md`  
> **Especificación:** [`spec.md`](spec.md) | **Plan Técnico:** [`plan.md`](plan.md)  
> **Estado:** `[PENDIENTE]` | `[EN PROGRESO]` | `[COMPLETADA]`

---

## Índice de Contenidos
1. [Flujo de Ejecución por Fases](#flujo-de-ejecucin-por-fases-dependencias-secuenciales)
2. [Fase 1: Capa de Base de Datos (GestioAsistenciaDB)](#fase-1-capa-de-base-de-datos-gestioasistenciadb)
3. [Fase 2: Capa de Backend (GestioAsistenciaBackend)](#fase-2-capa-de-backend-gestioasistenciabackend)
4. [Fase 3: Capa de Frontend (GestioAsistenciaFrontend)](#fase-3-capa-de-frontend-gestioasistenciafrontend)
5. [Fase 4: Pruebas y Quality Gates](#fase-4-pruebas-y-quality-gates-anti-malas-prcticas)
6. [Fase 5: Trazabilidad, Catálogo y Cierre](#fase-5-trazabilidad-catlogo-y-cierre)
7. [Documentos Relacionados](#documentos-relacionados)

---

## Flujo de Ejecución por Fases (Dependencias Secuenciales)

```text
Fase 1: Base de Datos ──► Fase 2: Backend ──► Fase 3: Frontend ──► Fase 4: Pruebas ──► Fase 5: Cierre
```

---

## Fase 1: Capa de Base de Datos (`GestioAsistenciaDB`)
*Prerrequisito: Revisar esquema DDL y restricciones en `GestioAsistenciaDB/schema/`.*

- [ ] **T-1.01 [DDL]:** Verificar o crear tablas y llaves foráneas requeridas en `schema/tables/`.
- [ ] **T-1.02 [SP y Modularidad]:** Crear o actualizar el Stored Procedure `usp_[accion]_[entidad].sql` en `schema/stored-procedures/`:
  - [ ] Cabecera con `SET XACT_ABORT ON;` y `SET NOCOUNT ON;`.
  - [ ] Control transaccional explícito `BEGIN TRANSACTION ... COMMIT TRANSACTION`.
  - [ ] Captura en `BEGIN CATCH` con `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;`.
  - [ ] **Modularidad:** Si existen cálculos complejos o verificaciones atómicas, delegar en `ufn_*` o `usp_internal_*` (cero SPs monolíticos "Dios").
  - [ ] **Cero Hardcoding:** Resolver estados contra tablas `cat_*` y evaluar `@parametro IS NULL` (cero GUIDs quemados).
  - [ ] **Paginación y Filtros (si aplica):** Incluir `@numeroPagina`, `@tamanoPagina`, `OFFSET ... ROWS FETCH NEXT ... ROWS ONLY` y `COUNT(*) OVER() AS totalRegistros`.
  - [ ] Retornar resultset estándar: `{ idResultado, exitoso, mensajeUsuario, mensajeTecnico }`.
- [ ] **T-1.03 [Deploy DB]:** Compilar esquema ejecutando `deploy_schema.ps1`.
- [ ] **T-1.04 [Unit Test DB]:** Probar ejecución manual `EXEC dbo.usp_...` confirmando `exitoso = 1` y `@@TRANCOUNT = 0`.

---

## Fase 2: Capa de Backend (`GestioAsistenciaBackend`)
*Prerrequisito: Fase 1 completada exitosamente.*

- [ ] **T-2.01 [DTOs UI-Ready]:** Crear DTOs de solicitud (`Request`) y respuesta (`Response`) preparados para la vista (validaciones `@NotNull`, `@NotBlank`, o `ApiPageResponse<T>` para listados).
- [ ] **T-2.02 [Puerto Secundario]:** Definir la interfaz `[Entidad]RepositoryPort` en `application/secondaryports/`.
- [ ] **T-2.03 [Adaptador Secundario]:** Implementar `[Entidad]RepositorySqlServerAdapter` en `infrastructure/adapter/secondary/repository/`:
  - [ ] Inyectar `JdbcTemplate` para ejecutar el Stored Procedure.
  - [ ] Mapear el resultado y lanzar excepciones tipadas (`ResourceNotFoundException`, `ConflictException`, `ValidationException`).
  - [ ] Propagar `CorrelationIdContext.get()` en la llamada al SP.
- [ ] **T-2.04 [Puerto Primario]:** Definir la interfaz `[Accion]InputPort` en `application/primaryports/`.
- [ ] **T-2.05 [Interactor / UseCase]:** Implementar `[Accion]UseCaseImpl` orquestando la llamada al puerto secundario.
- [ ] **T-2.06 [Controlador REST y OpenAPI]:** Crear o actualizar `@RestController` en `infrastructure/adapter/primary/controller/`:
  - [ ] **Regla Inviolable:** Prohibido inyectar `JdbcTemplate` o ejecutar SQL en el controlador (respetar flujo Controller -> Port -> UseCase -> Adapter).
  - [ ] Inyectar `UserScopeService` y validar jurisdicción del usuario autenticado.
  - [ ] Anotar con OpenAPI 3.0 (`@Operation`, `@ApiResponse`, `@Parameter`) para documentación viva en `/swagger-ui.html`.
  - [ ] Retornar `ResponseEntity<ApiDataResponse<T>>` o `ResponseEntity<ApiPageResponse<T>>`.
- [ ] **T-2.07 [Evento Real-Time]:** Disparar evento reactivo vía `RealtimePublisherPort` (`ReactorRealtimeAdapter`) tras persistir con éxito.
- [ ] **T-2.08 [Compilación Backend]:** Compilar backend con `.\mvnw.cmd compile -DskipTests` (verificar `BUILD SUCCESS`).

---

## Fase 3: Capa de Frontend (`GestioAsistenciaFrontend`)
*Prerrequisito: Fase 2 completada exitosamente.*

- [ ] **T-3.01 [Modelos]:** Definir interfaces TypeScript tipadas en `[modulo].models.ts` (cero uso de `any`, coincidiendo con los DTOs UI-Ready / paginados).
- [ ] **T-3.02 [Servicio API y Seguridad]:** Implementar llamadas HTTP en `[modulo].service.ts` consumiendo `${environment.apiUrl}`:
  - [ ] **Regla de Seguridad:** Cero almacenamiento de JWT en `localStorage`.
  - [ ] Configurar con `withCredentials: true` y soporte para token anti-CSRF (`X-XSRF-TOKEN`).
- [ ] **T-3.03 [Suscripción SSE]:** Integrar escucha reactiva del evento SSE vía `RealtimeService` sin usar polling (`setInterval`).
- [ ] **T-3.04 [Componente UI Moderno]:** Desarrollar o actualizar vista Standalone en `src/app/features/[rol]/`:
  - [ ] Declarar obligatoriamente `changeDetection: ChangeDetectionStrategy.OnPush`.
  - [ ] Utilizar Signals `input<T>()`, `output<T>()` y `model<T>()` (PROHIBIDO `@Input()` y `@Output()`).
  - [ ] En tablas/listados: integrar paginación con Signals reactivos y enlazar `PaginationComponent`.
  - [ ] Cero uso de `bypassSecurityTrustHtml` (usar componentes tipados para iconos SVG).
  - [ ] Administrar estado local con Angular Signals (`signal`, `computed`).
  - [ ] Implementar diseño institucional Aurora Education System con Tailwind CSS v4.
  - [ ] Mostrar estados de carga (`loading`), estados vacíos y feedback visual con Toasts.
- [ ] **T-3.05 [Compilación Frontend]:** Compilar frontend con `npm run build` (verificar **0 errores** de compilación).

---

## Fase 4: Pruebas y Quality Gates Anti-Malas Prácticas
*Prerrequisito: Fases 1, 2 y 3 completadas.*

- [ ] **T-4.01 [Checklist Anti-Malas Prácticas]:**
  - [ ] Base de Datos: SP con `SET XACT_ABORT ON;`, transaccionalidad atómica, sin SPs monolíticos y cero datos quemados.
  - [ ] Backend: Controlador desacoplado de JDBC/persistencia, DTOs UI-Ready y validación de `UserScopeService`.
  - [ ] Frontend: Componentes con `OnPush`, señales `input()`/`output()`, cero `localStorage` para tokens y cero `bypassSecurityTrustHtml`.
- [ ] **T-4.02 [Tests Backend]:** Ejecutar pruebas unitarias y de arquitectura: `.\mvnw.cmd test`.
- [ ] **T-4.03 [Tests Frontend]:** Ejecutar suite Karma CI: `npm run test:ci`.
- [ ] **T-4.04 [Quality Gate Real-Time]:** Verificar umbral de cobertura realtime: `npm run coverage:realtime:check`.
- [ ] **T-4.05 [Prueba E2E HU]:** Ejecutar suite E2E de Historias de Usuario: `.\scripts\general\tests\test_all_hus.ps1`.

---

## Fase 5: Trazabilidad, Catálogo y Cierre
*Prerrequisito: Fase 4 aprobada con 100% de éxito.*

- [ ] **T-5.01 [Commits Atómicos]:** Realizar commits independientes por capa siguiendo **Conventional Commits**:
  - `feat(db/sp): ... Refs: HUXXX`
  - `feat(backend/adapter): ... Refs: HUXXX`
  - `feat(frontend/[rol]): ... Refs: HUXXX`
- [ ] **T-5.02 [Actualizar Catálogo]:** Marcar la HU como `[IMPLEMENTADA]` en [docs/historias-de-usuario.md](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md).
- [ ] **T-5.03 [Actualizar Spec]:** Cambiar estado de `spec.md`, `plan.md` y `tasks.md` a `[COMPLETADA]`.

---

## Documentos Relacionados
- [Especificación Funcional (spec.md)](spec.md)
- [Plan Técnico de Arquitectura (plan.md)](plan.md)
- [Catálogo Maestro de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
- [Arquitectura Integral](file:///c:/Proyectos/GestioAsistencia/docs/arquitectura-integral.md)
