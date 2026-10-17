# 📘 Guía Metodológica Maestra: Implementación de Historias de Usuario
> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Ámbito:** Base de Datos (SQL Server 2022+), Backend (Spring Boot 4.0.6 / Java 25) y Frontend (Angular 19 / Signals)  
> **Versión:** 2.1.0 — Conforme a `CONSTITUTION.md` y `AGENTS.md`

---

## 🧭 1. Principios Rectores Inviolables

Todo agente de IA, desarrollador o equipo técnico debe someter su trabajo a estas 5 leyes fundamentales:

1. **Spec-Driven Development (SDD) & Contract-First:** Ninguna línea de código se escribe sin un contrato formal previo (OpenAPI, firma de SP T-SQL, DTOs de salida y eventos SSE) debidamente validado y congelado con su hash SHA-256.
2. **Clean Architecture & Puertos y Adaptadores:** El núcleo de negocio (Domain y Application) es agnóstico a frameworks, bases de datos y librerías externas. Los controladores HTTP consumen `PrimaryPorts`; la persistencia y servicios externos implementan `SecondaryPorts`.
3. **Inviolabilidad de las Pruebas (Zero Test Tampering):** **ESTRICTAMENTE PROHIBIDO** relajar, modificar o comentar tests para hacerlos pasar. El implementador corrige el código de producción, nunca las aserciones de prueba.
4. **Reactividad Nativa y Prohibición Estricta de Polling:** Se prohíbe simular reactividad con `setInterval` o peticiones HTTP periódicas. La reactividad se implementa mediante **Server-Sent Events (SSE)** en el backend y **Angular Signals** (`signal`, `computed`, `effect`) en el frontend.
5. **Pre-Flight Check Obligatorio:** Antes de cerrar cualquier tarea, es mandatorio ejecutar:
   ```powershell
   .\AsistenciasUCO-Infra\infra.ps1 verify
   ```
   *(Verifica escaneo de secretos y paridad estricta de contratos WORM con cero drift).*

---

## 🔄 2. El Ciclo de Vida TDD en 6 Fases Obligatorias

Toda Historia de Usuario sigue de forma secuencial e irreversible estas 6 etapas:

```text
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 01. PLAN     │ ──> │ 02. CONTRACT │ ──> │ 03. TEST RED │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
                                                 ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 06. CLOSURE  │ <── │ 05. AUDIT    │ <── │ 04. IMPL     │
└──────────────┘     └──────────────┘     │   (GREEN)    │
                                          └──────────────┘
```

### Fase 01: Planificación y Definition of Ready (DoR)
- **Actividades:**
  1. Extraer del catálogo (`docs/historias-de-usuario.md`) el rol de negocio, ruta del frontend y alcance.
  2. Verificar dependencias de dominio previas (ej. ¿Existe la Facultad antes de registrar el Decano?).
  3. Formular la clase de cambio, riesgos de concurrencia y estrategia de rollback.
  4. Si faltan datos de negocio, declarar `NOT_READY` y solicitar aclaración antes de tocar código.

### Fase 02: Congelamiento de Contratos
- **Actividades:**
  1. **Base de Datos:** Definir firma del Stored Procedure público (`usp_*`) con parámetros de entrada, salida y tipos SQL exactos.
  2. **Backend API:** Definir la ruta REST, método HTTP, DTOs de solicitud (`*Request`), DTOs de respuesta (`ApiDataResponse<T>` / `ApiPageResponse<T>`) y códigos de error en OpenAPI.
  3. **Eventos Realtime:** Si la HU notifica cambios en vivo, documentar el tipo de evento en el estándar SSE.
  4. Congelar y asegurar que no altere contratos WORM congelados preexistentes.

### Fase 03: Pruebas en Rojo (Test RED)
- **Actividades:**
  1. **SQL Server:** Redactar los escenarios de prueba en `test_suite.sql` o archivo específico en `test/` (Happy Path, Datos Nulos, Clave Duplicada, Permisos). Al ejecutarse, deben fallar por ausencia del SP.
  2. **Backend:** Escribir tests unitarios con JUnit 5 y Mockito para el Interactor / Use Case y el Controller. Deben fallar en rojo.
  3. **Frontend:** Escribir pruebas en Karma/Jasmine para el componente y servicio (`*.spec.ts`).

### Fase 04: Implementación en Verde (Implement GREEN)
- **Actividades en orden ascendente estricto:**
  1. **Capa DB:** Crear o modificar tablas (si aplica con script idempotente) y redactar el Stored Procedure en `schema/stored-procedures/`. Ejecutar `.\AsistenciasUCO-Infra\infra.ps1 db-deploy` y verificar `test-suite` en verde.
  2. **Capa Backend:** Implementar DTOs, Mappers, Primary Port, Use Case, Secondary Port, Repositorio SQL Server (`*RepositorySqlServerAdapter`), Controller REST y provisioning en Keycloak si la entidad crea un usuario institucional. Ejecutar `.\mvnw.cmd test`.
  3. **Capa Frontend:** Implementar la interfaz en Angular con Standalone Components, Signals, formularios reactivos con validación instantánea y tokens Aurora. Ejecutar `npm run test:ci` y `npm run build`.

### Fase 05: Auditoría y Quality Gates (Audit)
- **Actividades:**
  1. Verificar cumplimiento de Clean Architecture (ArchUnit tests pasando al 100%).
  2. Comprobar que no hay fuga de secretos en logs ni archivos temporales.
  3. Verificar que no exista código quemado (hardcoding) de GUIDs, textos fijos o estados.
  4. Revisar que los logs estructurados incluyan `correlationId`, `traceId` y `service`.

### Fase 06: Cierre y Actualización de Línea Base (Closure)
- **Actividades:**
  1. Actualizar el estado de la HU en `docs/historias-de-usuario.md` a `[CERTIFICADA]`.
  2. Ejecutar el Pre-Flight Check de infraestructura: `.\AsistenciasUCO-Infra\infra.ps1 verify`.
  3. Registrar deudas técnicas resueltas o pendientes.

---

## 🛠️ 3. Reglas Técnicas de Construcción por Capa

### 3.1 Base de Datos (SQL Server 2022+)
- **Transaccionalidad Atómica:** Obligatorio `SET XACT_ABORT ON;`, `SET NOCOUNT ON;`, y manejo explícito de transacciones:
  ```sql
  BEGIN TRY
      BEGIN TRANSACTION;
      -- Validaciones y mutaciones
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
      IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
      -- Mapeo de errores y salida
  END CATCH
  ```
- **Modularidad:** El SP público (`usp_<accion>_<entidad>`) es el orquestador transaccional. Cálculos complejos o validaciones atómicas se delegan a funciones (`ufn_*`) o SPs internos (`usp_*_interno`). **Prohibidos SPs monolíticos**.
- **Cero Datos Quemados (No Hardcoding):** Resolver siempre los estados contra `cat_*` o recibirlos como parámetro tipado.
- **Parámetros Nullable:** Evaluar siempre `@parametro IS NULL`, jamás comparar contra cadenas de ceros `'00000000-0000-0000-0000-000000000000'`.
- **Salida Estándar:** Todo SP de mutación retorna la tupla (`idResultado`, `exitoso`, `mensajeUsuario`, `mensajeTecnico`).

### 3.2 Backend (Spring Boot 4.0.6 / Java 25)
- **Estructura de Paquetes Hexagonal:**
  ```text
  co.edu.uco.asistenciasuco.
  ├── application/
  │   ├── features/<modulo>/<feature>/
  │   │   ├── primaryports/interactor/     # Interactor público
  │   │   ├── primaryports/dto/            # DTOs de entrada y salida del puerto
  │   │   ├── usecase/                     # Lógica de aplicación
  │   │   └── usecase/domain/              # Entidades y reglas de dominio
  │   └── secondaryports/
  │       ├── repository/                  # Interfaces de persistencia
  │       └── identity/                    # Interfaces de IAM (Keycloak)
  └── infrastructure/
      ├── adapter/primary/controller/      # Controladores REST (@RestController)
      └── adapter/secondary/repository/    # Implementación JPA/JDBC (*SqlServerAdapter)
  ```
- **Aprovisionamiento IAM (Keycloak):** Si la entidad representa un usuario (Decano, Coordinador, Docente, Estudiante), invocar obligatoriamente `identityProviderPort.crearCuenta(...)` tras la confirmación en DB para emitir credenciales y asignar el rol de cliente correspondiente (`DECANO`, `COORDINADOR`, `DOCENTE`, `ESTUDIANTE`).
- **Mapeo de Errores Tipados:** Usar las excepciones de negocio existentes (`ConflictException`, `NotFoundException`, `ValidationException`) para que `GlobalExceptionHandler` genere el código HTTP y mensaje catalogado correspondiente.

### 3.3 Frontend (Angular 19 / Signals / Tailwind v4)
- **Reactividad con Signals:**
  - El estado local y global se maneja con `signal<T>()`, `computed()` y `effect()`.
  - Configurar obligatoriamente `changeDetection: ChangeDetectionStrategy.OnPush` en todos los componentes.
  - Prohibido el uso de `setInterval` o timers de refresco recurrente.
- **Formularios y UX:**
  - Validación instantánea al escribir con retroalimentación visual clara.
  - Consumo tipado estricto de `ApiResponse<T>` y `ApiPageResponse<T>`. Cero uso de `any`.
  - Diseños basados en Bento Grids y Maestro-Detalle utilizando los tokens del Aurora Education Design System.

---

## 📋 4. Checklist Rápido de Verificación para el Agente

Antes de dar por finalizada la implementación de una HU, marca cada casilla:
- [ ] ¿El SP en SQL Server tiene control transaccional atómico y rollback seguro?
- [ ] ¿La prueba SQL transaccional pasa al 100% en `test_suite.sql`?
- [ ] ¿El Backend implementa la separación limpia de puertos y adaptadores?
- [ ] ¿Si registra un usuario, se sincronizó su identidad y rol en Keycloak?
- [ ] ¿Se ejecutan los tests de Backend con `.\mvnw.cmd test` sin errores?
- [ ] ¿El Frontend compila limpiamente (`npm run build`) con cero advertencias críticas?
- [ ] ¿Las pruebas de Frontend pasan con `npm run test:ci`?
- [ ] ¿Se ejecutó `.\AsistenciasUCO-Infra\infra.ps1 verify` con resultado `[PASS]`?
- [ ] ¿Se actualizó el estado en `docs/historias-de-usuario.md` a `[CERTIFICADA]`?
