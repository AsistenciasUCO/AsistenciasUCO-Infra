# 📐 Plan Técnico de Arquitectura e Implementación: [Nombre de la Funcionalidad]

> **Documento:** `docs/specs/_template/plan.md`  
> **Especificación:** [`spec.md`](spec.md) | **Tareas:** [`tasks.md`](tasks.md)  
> **Estado:** `[PROPUESTO]` | `[EN EJECUCIÓN]` | `[IMPLEMENTADO]`

---

## Índice de Contenidos
1. [Decisiones de Arquitectura y Enfoque Técnico](#1-decisiones-de-arquitectura-y-enfoque-tcnico)
2. [Diseño de Capa de Base de Datos (GestioAsistenciaDB)](#2-diseo-de-capa-de-base-de-datos-gestioasistenciadb)
3. [Diseño de Capa Backend (GestioAsistenciaBackend)](#3-diseo-de-capa-backend-gestioasistenciabackend)
4. [Diseño de Capa Frontend (GestioAsistenciaFrontend)](#4-diseo-de-capa-frontend-gestioasistenciafrontend)
5. [Estrategia de Pruebas y Validación Técnica](#5-estrategia-de-pruebas-y-validacin-tcnica)
6. [Documentos Relacionados](#6-documentos-relacionados)

---

## 1. Decisiones de Arquitectura y Enfoque Técnico

A partir de los requisitos y reglas de negocio formalizadas en [`spec.md`](spec.md), se diseña la solución técnica cumpliendo los siguientes pilares innegociables:
- **Clean Architecture & Puertos/Adaptadores:** Desacoplamiento total entre lógica de negocio y persistencia.
- **Persistencia Transaccional (Smart Database):** La lógica ACID reside en Stored Procedures T-SQL en SQL Server.
- **Reactividad Real-Time Push:** La sincronización con la UI se realiza vía Server-Sent Events (SSE) sin polling.
- **Seguridad por Ámbito (Scope Security):** Verificación obligatoria con `UserScopeService`.

---

## 2. Diseño de Capa de Base de Datos (`GestioAsistenciaDB`)

### 2.1 Tablas Físicas y Modificaciones DDL
- **Tabla Principal:** `dbo.[NombreTabla]`
  - Columnas afectadas: `[columna1]` (`TIPO`), `[columna2]` (`TIPO`).
  - Restricciones: `PK_[Tabla]`, `FK_[Tabla]_[Referencia]`, `CHECK (...)`.

### 2.2 Procedimiento Almacenado: `dbo.usp_[accion]_[entidad]` y Modularidad
- **Ubicación:** `GestioAsistenciaDB/schema/stored-procedures/usp_[accion]_[entidad].sql`
- **Reglas de Modularidad y Transaccionalidad:**
  - El SP público es fachada de orquestación transaccional: valida parámetros y gestiona la transacción global.
  - Lógicas atómicas o complejas (validar conflicto, calcular porcentaje de inasistencia, auditar) se delegan en funciones (`ufn_*`) o procedimientos internos (`usp_internal_*`). **Prohibidos SPs monolíticos**.
  - Cero datos quemados: todos los estados y códigos deben consultarse en tablas de catálogo (`cat_*`) o recibirse como parámetros.
- **Firma Canónica:**
  ```sql
  CREATE OR ALTER PROCEDURE [dbo].[usp_[accion]_[entidad]]
  (
      @idEntidad               UNIQUEIDENTIFIER = NULL,
      @parametroNegocio        NVARCHAR(255),
      @idCorrelacion           UNIQUEIDENTIFIER = NULL,
      @mensajeUsuarioResultado NVARCHAR(4000) = NULL OUTPUT,
      @mensajeTecnicoResultado NVARCHAR(4000) = NULL OUTPUT,
      @estadoResultado         BIT = 1 OUTPUT
  )
  AS
  BEGIN
      SET NOCOUNT ON;
      SET XACT_ABORT ON;
      
      -- Control transaccional explícito con rollback automático
      BEGIN TRY
          BEGIN TRANSACTION;

          -- 1. Validaciones y consultas a tablas de catálogo (cero datos quemados)
          -- 2. Concurrencia con WITH (UPDLOCK, HOLDLOCK) si aplica
          -- 3. Invocación de ufn_* o usp_internal_*
          -- 4. Mutación atómica

          COMMIT TRANSACTION;
      END TRY
      BEGIN CATCH
          IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
          SET @estadoResultado = 0;
          SET @mensajeUsuarioResultado = 'Error al procesar la operación.';
          SET @mensajeTecnicoResultado = ERROR_MESSAGE();
      END CATCH;

      -- Resultset estándar
      SELECT 
          ISNULL(@idEntidad, NEWID()) AS idResultado,
          @estadoResultado            AS exitoso,
          @mensajeUsuarioResultado    AS mensajeUsuario,
          @mensajeTecnicoResultado    AS mensajeTecnico;
  END;
  ```

### 2.3 Consultas Paginadas y Filtradas (Si aplica a la HU)
- Implementar parámetros `@numeroPagina INT = 1`, `@tamanoPagina INT = 20` y filtros opcionales `@filtroParam TIPO = NULL`.
- Cláusula T-SQL canónica:
  ```sql
  SELECT 
      ...,
      COUNT(*) OVER() AS totalRegistros
  FROM dbo.[Tabla]
  WHERE (@filtroParam IS NULL OR [Columna] = @filtroParam)
  ORDER BY [ColumnaOrden] DESC
  OFFSET (@numeroPagina - 1) * @tamanoPagina ROWS
  FETCH NEXT @tamanoPagina ROWS ONLY;
  ```

---

## 3. Diseño de Capa Backend (`GestioAsistenciaBackend`)

### 3.1 Flujo Hexagonal (Ports & Adapters)
```text
[HTTP Client]
     │
     ▼
[EntidadController] (@RestController - infrastructure/adapter/primary/controller)
     │ Valida request DTO, invoca UserScopeService
     ▼
[AccionInputPort] (Primary Port - application/primaryports)
     │
     ▼
[AccionUseCaseImpl] (Interactor - application/usecase)
     │ Orquesta reglas de aplicación y llama al puerto secundario
     ▼
[EntidadRepositoryPort] (Secondary Port - application/secondaryports)
     │
     ▼
[EntidadRepositorySqlServerAdapter] (Secondary Adapter - infrastructure/adapter/secondary/repository)
     │ Ejecuta jdbcTemplate.queryForMap("EXEC dbo.usp_...")
     ▼
[SQL Server 2022+]
```

### 3.2 Paquetes y Clases
1. **Controlador REST y Documentación OpenAPI 3.0:**
   - Ubicación: `infrastructure/adapter/primary/controller/[modulo]/[Entidad]Controller.java`
   - Endpoint: `[POST|GET] /api/v1/[recurso]`
   - Documentación Swagger: Anotaciones OpenAPI (`@Operation`, `@ApiResponse`, `@Parameter`) visibles en `/swagger-ui.html`.
   - **Regla Inviolable:** Cero sentencias SQL o inyección de `JdbcTemplate` en el controlador.
2. **DTOs UI-Ready y Contratos Canónicos:**
   - DTOs preparados para la vista (nombres legibles, estados institucionales).
   - Para listados masivos: encapsular en `ApiPageResponse<T>` (`elementos`, `numeroPagina`, `tamanoPagina`, `totalElementos`, `totalPaginas`).
3. **Puertos y Casos de Uso:**
   - Puerto Primario: `application/primaryports/[modulo]/[Accion]InputPort.java`
   - Interactor: `application/usecase/[modulo]/[Accion]UseCaseImpl.java`
   - Puerto Secundario: `application/secondaryports/repository/[Entidad]RepositoryPort.java`
4. **Adaptador de Persistencia:**
   - Clase: `infrastructure/adapter/secondary/repository/adapter/[Entidad]RepositorySqlServerAdapter.java`
   - Inyección exclusiva de `JdbcTemplate` para ejecutar el SP.
5. **Seguridad y Observabilidad:**
   - Inyección de `UserScopeService` para validar pertenencia de rol/ámbito.
   - Propagación de `CorrelationIdContext.get()` hacia logs y llamadas a SP.
6. **Evento en Tiempo Real (SSE):**
   - Publicación vía `RealtimePublisherPort` (`ReactorRealtimeAdapter`).

---

## 4. Diseño de Capa Frontend (`GestioAsistenciaFrontend`)

### 4.1 Componente e Interfaz de Usuario
- **Ruta:** `/app/[rol]/[vista]`
- **Componente:** `src/app/features/[rol]/[vista]/[nombre].component.ts` (Standalone Component).
- **Estándar Angular 19:**
  - `changeDetection: ChangeDetectionStrategy.OnPush`.
  - Signals `input<T>()`, `output<T>()` y `model<T>()` (PROHIBIDO `@Input()` y `@Output()`).
  - Cero uso de `bypassSecurityTrustHtml` (iconos con componentes tipados).
- **Diseño Visual:** Aurora Education System (Tailwind CSS v4).

### 4.2 Servicio, Seguridad y Reactividad por Signals
- **Servicio:** `src/app/core/services/[modulo].service.ts` consumiendo `${environment.apiUrl}` (sin mocks en producción).
- **Seguridad:** Cero JWT en `localStorage`. Configuración `withCredentials: true`, soporte anti-CSRF (`X-XSRF-TOKEN`), rutas protegidas con guards y redirección en 401/403.
- **Gestión de Estado:** `signal`, `computed`, `effect`.
- **Sincronización SSE:** Suscripción a `/api/v1/realtime/stream` con `@microsoft/fetch-event-source` (PROHIBIDO polling / `setInterval`).

---

## 5. Estrategia de Pruebas y Validación Técnica

1. **Base de Datos:** Suite T-SQL `test_suite.sql` (`exitoso = 1`, `@@TRANCOUNT = 0`).
2. **Backend:** Pruebas unitarias y ArchUnit (`mvnw test`), compilación limpia (`mvnw compile -DskipTests`).
3. **Frontend:** Pruebas CI (`npm run test:ci`), Quality Gate Realtime (`npm run coverage:realtime:check`), build (`npm run build`).
4. **E2E:** `scripts/general/tests/test_all_hus.ps1` con Bearer token de Keycloak.

---

## 6. Documentos Relacionados
- [Especificación Funcional (spec.md)](spec.md)
- [Desglose de Tareas (tasks.md)](tasks.md)
- [Arquitectura Integral del Sistema](file:///c:/Proyectos/GestioAsistencia/docs/arquitectura-integral.md)
- [Arquitectura Realtime SSE](file:///c:/Proyectos/GestioAsistencia/docs/realtime-sse-architecture.md)
- [Catálogo Maestro de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
