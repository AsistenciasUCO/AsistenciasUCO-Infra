# 📜 Constitución del Proyecto: Sistema de Gestión de Asistencia UCO
> **Documento:** `CONSTITUTION.md`  
> **Metodología:** Spec-Driven Development (SDD) / Contract-First / GitHub Spec Kit  
> **Ámbito:** Repositorio Unificado `GestioAsistencia` (Base de Datos, Backend API, Frontend Web, Infraestructura Centralizada)  
> **Estado:** RATIFICADA Y CONGELADA (SSOT)  
> **Versión:** 2.2.0  
> **Fecha de Entrada en Vigor:** Septiembre 2026  

---

## Preámbulo

Nosotros, como equipo de ingeniería y agentes de desarrollo de software para la **Universidad Católica de Oriente (UCO)**, establecemos esta **Constitución Técnica** como la ley suprema, innegociable e inviolable que gobierna el diseño, especificación (`spec.md`), contratos formalizados, planificación (`plan.md`), pruebas TDD (`test.md`) e implementación de código en el **Sistema de Gestión de Asistencia UCO**.

Ninguna especificación funcional, solicitud de usuario, atajo de desarrollo o código generado por Inteligencia Artificial podrá contravenir los principios, restricciones y contratos estipulados en esta Constitución.

---

## Artículo I — Principios Arquitectónicos Fundamentales

### Sección 1.01: Clean Architecture (Arquitectura Limpia)
1. **Aislamiento del Negocio:** La lógica nuclear del negocio, entidades de dominio y casos de uso residen aislados e independientes de frameworks web (Spring, Angular), interfaces de usuario, SDKs cloud y motores de persistencia.
2. **Sustituibilidad Técnica:** Cualquier cambio de base de datos (SQL Server, JPA, JDBC), servicio de mensajería (SSE, Event Grid) o proveedor de identidad (Keycloak) debe realizarse sin alterar la lógica nuclear de la aplicación.

### Sección 1.02: Patrón de Puertos y Adaptadores (Arquitectura Hexagonal)
1. **Programación contra Puertos:** Todo módulo e integración se diseña contra contratos e interfaces públicas (**Puertos Primarios y Secundarios**). Ningún equipo espera a que otros componentes transversales finalicen su implementación; se programa y prueba contra el puerto definido.
2. **Desacoplamiento de Adaptadores:** Cada integración concreta (`SqlServerAdapter`, `KeycloakAdapter`, `SseRealtimeAdapter`, `AzureAppConfigAdapter`) se encapsula en la capa de infraestructura implementando su puerto correspondiente.

### Sección 1.03: Enfoque API First / Contract First y Especificación OpenAPI
1. **Definición Previa del Contrato:** Los módulos transversales y endpoints deben definir de antemano sus contratos e interfaces públicas antes de iniciar la codificación interna.
2. **Especificación OpenAPI 3.0 (Swagger):** 
   - La API REST se documenta y expone formalmente bajo el estándar **OpenAPI 3.0** (accesible en `/swagger-ui.html` y `/v3/api-docs`).
   - OpenAPI actúa como la especificación viva del contrato entre Backend y Frontend, asegurando tipado estricto, documentación de esquemas JSON y validación determinística.
3. **Contratos Canónicos Inmutables:**
   - **Mutaciones en BD (Backend ↔ SQL Server):** Toda operación transaccional (`INSERT`, `UPDATE`, `DELETE`, `MERGE`) devuelve obligatoriamente la tupla unificada:
     `{ idResultado, exitoso, mensajeUsuario, mensajeTecnico }`.
   - **Mutaciones y Consultas Simples (Backend ↔ Frontend):** Se encapsulan en `ApiDataResponse<T>` con firma `{ exitoso, mensajeUsuario, datos }`.
   - **Consultas de Listados Paginados (Full-Stack):** Se encapsulan en `ApiPageResponse<T>` conteniendo `{ elementos, numeroPagina, tamanoPagina, totalElementos, totalPaginas }`.

### Sección 1.04: Reactividad Nativa en Tiempo Real (Real-Time)
1. El sistema es nativamente reactivo. La sincronización en tiempo real se gobierna exclusivamente mediante **Server-Sent Events (SSE)** en `/api/v1/realtime/stream` y **Angular Signals** en el cliente.
2. > [!CAUTION]
   > ### 🛑 PROHIBICIÓN ESTRICTA DE POLLING (Sondeo Periódico)
   > Queda formalmente prohibido implementar sondeos periódicos en el cliente (como `setInterval` de JavaScript, llamadas recurrentes cada 3 o 5 segundos con polling HTTP o timers cíclicos) para simular tiempo real. La información es empujada por el servidor (SSE) o gobernada por cambios de estado reactivos en Signals.

### Sección 1.05: Principio de Única Fuente de Verdad (Single Source of Truth - SSOT)
1. **Cero Duplicación de Autoridad:** Cada dato, catálogo, regla de negocio y especificación debe residir en un único lugar canónico con autoridad absoluta dentro del sistema.
2. **SSOT en Base de Datos:** SQL Server es la única fuente de verdad para el estado de las entidades, folios de negocio (`SES-01`, `DEC-01`), secuencias y catálogos relacionales institucionales.
3. **SSOT en Parámetros y Mensajes (Azure App Configuration):** Los mensajes al usuario y parámetros dinámicos se gestionan centralizadamente en Azure App Configuration bajo `messages:user:<CODIGO>` (label `es`), `messages:technical:<CODIGO>` y `asistencias:<modulo>:<parametro>`. Los textos en enums Java o frontend son estrictamente *fallbacks* de contingencia.
4. **SSOT en Secretos (Azure Key Vault):** Los secretos sensibles se administran en Azure Key Vault. Queda prohibido quemar secretos en código, documentación o repositorios.
5. **SSOT en Documentación y Gobernanza:** [`AsistenciasUCO-Infra/docs/governance/CONSTITUTION.md`](file:///c:/Proyectos/GestioAsistencia/AsistenciasUCO-Infra/docs/governance/CONSTITUTION.md) es la única fuente de verdad de las normas de diseño y desarrollo. Queda prohibida la duplicación de constituciones divergentes.
6. **SSOT en Contratos (WORM con Hashes SHA-256):** Los contratos formalizados (`openapi-golden-path.yaml`, `BACKEND_GOLDEN_PATH_CONTRACT.md`, `DB_BASELINE_CONTRACT.md`) son inmutables bajo principio WORM (*Write Once, Read Many*), acompañados de su firma criptográfica `.sha256` adyacente validada en los Quality Gates.

---

## Artículo II — Núcleo de Base de Datos y Transaccionalidad (SQL Server)

### Sección 2.01: Paradigma Smart/Thick Database
1. SQL Server 2022+ (Nivel de compatibilidad 160) es el custodio de las reglas de integridad referencial, catálogos del sistema y cálculos transaccionales críticos (pérdidas de asignatura por inasistencia al 20%, control de cupos).

### Sección 2.02: Blindaje Transaccional Obligatorio
1. Todo Stored Procedure que mute datos (`INSERT`, `UPDATE`, `DELETE`, `MERGE`) debe iniciar obligatoriamente con:
   ```sql
   SET XACT_ABORT ON;
   SET NOCOUNT ON;
   ```
2. Las mutaciones deben estar protegidas dentro de un bloque explícito `BEGIN TRANSACTION ... COMMIT TRANSACTION`, y capturadas en `BEGIN CATCH` garantizando:
   ```sql
   IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
   ```
3. Ninguna transacción puede quedar abierta o huérfana en el motor (`@@TRANCOUNT = 0`).

### Sección 2.03: Concurrencia, Aislamiento y Magic Values
1. Se prohíbe el cálculo ingenuo de secuencias (`COUNT(*) + 1`, `MAX() + 1`) sin bloqueos de concurrencia explícitos (`WITH (UPDLOCK, HOLDLOCK)`) o secuencias formales.
2. Se prohíbe la comparación contra GUIDs vacíos (`'00000000-0000-0000-0000-000000000000'`). Se debe evaluar rigurosamente `@parametro IS NULL`.

### Sección 2.04: Modularidad y Procedimientos Atómicos
1. **Patrón Orquestador Público vs. Procedimientos Internos:**
   - El Stored Procedure público (`usp_<accion>_<entidad>`) actúa como fachada para la API: valida parámetros de entrada, administra la transacción global y devuelve el resultset estándar `{ idResultado, exitoso, mensajeUsuario, mensajeTecnico }`.
   - Las operaciones complejas o atómicas (cálculos de inasistencia, validación de cruces de horario, verificación de cupos, inserciones de bitácora) deben modularizarse en funciones (`ufn_*`) o procedimientos internos atómicos (`usp_internal_*`), garantizando pruebas aisladas y alta cohesión.
2. **Prohibición de Procedimientos Monolíticos:** Queda prohibido agrupar en un único procedimiento monolítico ("Dios") múltiples lógicas heterogéneas sin descomposición modular.

### Sección 2.05: Cero Datos Quemados (No Hardcoding)
1. Queda estrictamente prohibido quemar GUIDs, identificadores de programas/facultades o cadenas literales de catálogos en el código T-SQL.
2. Todo estado ('REGISTRADA', 'JUSTIFICADA', 'CANCELADA') debe obtenerse de las tablas de catálogo (`cat_estado_asistencia`, `cat_tipo_sesion`, etc.) o recibirse como parámetro tipado.

### Sección 2.06: Estándar de Consultas Paginadas y Filtradas
1. **Paginación Mandatoria:** Todo procedimiento almacenado de consulta sobre entidades con volumen de datos medio o alto (asistencias, sesiones de clase, reclamos/justificaciones, matrículas, auditoría) debe recibir parámetros `@numeroPagina INT = 1` y `@tamanoPagina INT = 20`.
2. **Implementación T-SQL Canónica:** La paginación en SQL Server debe realizarse mediante:
   ```sql
   OFFSET (@numeroPagina - 1) * @tamanoPagina ROWS
   FETCH NEXT @tamanoPagina ROWS ONLY;
   ```
   Acompañada de la función de ventana `COUNT(*) OVER() AS totalRegistros` para permitir al backend y frontend calcular el total de páginas.
3. **Filtrado Eficiente:** Las consultas deben incluir cláusulas de filtro opcionales indexadas con el patrón `(@filtro IS NULL OR columna = @filtro)`.
4. **Prohibición de Consultas Masivas:** Se prohíbe terminantemente ejecutar consultas sin límite de registros (`SELECT *` sin paginación) sobre tablas transaccionales en producción.

### Sección 2.07: Hardening y Principio de Mínimo Privilegio en Base de Datos
1. Las aplicaciones y microservicios nunca se conectan con el usuario administrador `sa`.
2. El usuario de aplicación (`app_asistencias_user`) pertenece al rol `db_app_executor` con permisos exclusivos de:
   - `GRANT EXECUTE` sobre procedimientos almacenados (`usp_*`).
   - `GRANT SELECT` sobre vistas de consulta (`uv_*`, `uv_auth_*`).
3. Queda explícitamente denegada la escritura directa sobre tablas (`DENY INSERT, UPDATE, DELETE`) y la modificación de esquemas DDL (`DENY ALTER`).

---

## Artículo III — Capa de Servicios Backend (Spring Boot / Java 25)

### Sección 3.01: Separación de Responsabilidades e Inversión de Dependencias
1. La capa `application/` define casos de uso (`interactors`), puertos primarios y puertos secundarios. Nunca importa paquetes de `infrastructure/`.
2. **Estándar de Persistencia:**
   - La tecnología estándar para acceso a datos en adaptadores secundarios es **Spring Data JPA**. Los componentes que aún utilizan Spring JDBC (`JdbcTemplate`) operan como **JDBC legacy en coexistencia temporal**, sujetos a migración progresiva según la estrategia incremental de persistencia.
   - Las entidades JPA (`@Entity`) son modelos exclusivos de persistencia en `infrastructure/` y jamás deben usarse como entidades de dominio ni importarse en `application/`.
3. Los controladores `@RestController`:
   - Se limitan a validar el request HTTP (`Validator`), llamar al `PrimaryPort` correspondiente y mapear la respuesta hacia `ResponseEntity<ApiDataResponse<T>>`.
   - > [!CAUTION]
     > ### 🛑 PROHIBICIÓN DE SQL EN CONTROLADORES Y CAPA DE APLICACIÓN
     > Se prohíbe terminantemente inyectar `JdbcTemplate`, `EntityManager` o interfaces de repositorios (`JpaRepository`), así como ejecutar sentencias SQL (`SELECT`, `INSERT`, `EXEC`, etc.) dentro de `@RestController` o en `application/`. Toda interacción con base de datos pertenece exclusivamente a la capa secundaria (`infrastructure/adapter/secondary/repository` o `infrastructure/adapter/secondary/persistence`).

### Sección 3.02: Seguridad Basada en Ámbitos (Scope Security)
1. Es obligatorio el uso de `UserScopeService` para validar que el usuario autenticado (extraído del token JWT emitido por Keycloak) posea jurisdicción estricta sobre la entidad consultada o modificada (restringiendo a programa, facultad, grupo o asignación académica).

### Sección 3.03: Manejo de Excepciones Semánticas
1. Queda prohibido silenciar errores con bloques `catch` vacíos o retornar objetos vacíos ante fallos de persistencia.
2. Se deben lanzar excepciones tipadas: `ResourceNotFoundException` (404), `ConflictException` (409), `ValidationException` (400) y `UnauthorizedException` (403).

### Sección 3.04: Modelos UI-Ready y Contratos Preparados
1. Los endpoints deben entregar DTOs completamente preparados para el consumo de la interfaz de usuario (`UI-Ready DTOs`), incluyendo nombres completos formateados, descripciones legibles de catálogos y métricas calculadas.
2. Queda prohibido obligar al frontend a implementar mappers pesados o complejos en el cliente para transformar entidades crudas del backend.

---

## Artículo IV — Capa de Cliente Frontend (Angular 18/19 / TypeScript)

### Sección 4.01: Standalone Components y Reactividad por Signals
1. El 100% de los componentes deben ser Standalone (`standalone: true`).
2. **Obligatoriedad de `ChangeDetectionStrategy.OnPush`:** Todos los componentes en el frontend deben declarar explícitamente `changeDetection: ChangeDetectionStrategy.OnPush` en su decorador `@Component`.
3. **Signals `input()` y `output()` Modernos:** Queda formalmente prohibido el uso de decoradores tradicionales `@Input()` y `@Output()`. Todo componente debe utilizar exclusivamente `input<T>()`, `output<T>()` y `model<T>()`.
4. El estado se administra a través de Angular Signals (`signal`, `computed`, `effect`), erradicando variables mutables huérfanas y suscripciones manuales descontroladas.

### Sección 4.02: Tipado Fuerte y Desacoplamiento de Mocks
1. Queda prohibido el uso del tipo `any` en modelos, interfaces y contratos de respuesta.
2. Los servicios del frontend deben consumir directamente los endpoints reales del backend; los mocks en memoria quedan restringidos a pruebas unitarias aisladas.

### Sección 4.03: Prohibición de Generación de Identidades en Cliente
1. El frontend jamás generará códigos de negocio, folios o identificadores secuenciales (`DEC-001`, `SES-01`). Las identidades son asignadas por la base de datos o el backend.

### Sección 4.04: Seguridad de Sesión y Comunicación HTTP
1. **Cero Almacenamiento de Tokens en Cliente (`localStorage` / `sessionStorage`):** Queda formalmente desaconsejado y prohibido almacenar tokens JWT en `localStorage` debido a riesgos de vulnerabilidad XSS. La sesión debe ser gobernada preferentemente mediante cookies `HttpOnly` / `SameSite` o almacenamiento protegido en memoria con refresh automático vía canal seguro.
2. **Credenciales y Protección CSRF:** Las llamadas HTTP mutables (`POST`, `PUT`, `DELETE`) deben incluir la cabecera anti-CSRF (`X-XSRF-TOKEN`) y el cliente HTTP debe incorporar soporte para cookies de sesión (`withCredentials: true`).
3. **Manejo Uniforme de 401 y 403:** El interceptor de errores debe redirigir a `/login` ante `401 Unauthorized` y a `/forbidden` ante `403 Forbidden`.

---

## Artículo V — Observabilidad, Trazabilidad y Métricas

### Sección 5.01: Estándar Global OpenTelemetry
1. OpenTelemetry es el estándar universal de instrumentación del sistema para la captura de trazas OTLP, logs distribuidos y métricas de salud.

### Sección 5.02: Trazabilidad y Logs Distribuidos
1. Cada petición debe inicializar y propagar un identificador de correlación mediante `CorrelationIdContext.get()` a través del header `X-Correlation-Id`, logs estructurados (`Logstash JSONL`) y parámetros de Stored Procedures en SQL Server.
2. Se prohíbe el uso de cadenas de correlación simuladas o quemadas (`'corr-manual'`, `'trace-manual'`).

### Sección 5.03: Métricas del Servicio
1. Los endpoints de métricas de Spring Boot Actuator (`/actuator/prometheus`) y Keycloak (`/metrics`) deben mantenerse activos y compatibles con Prometheus y tableros de Grafana para auditoría en tiempo real.

---

## Artículo VI — Calidad, Pruebas y Cero Regresiones

### Sección 6.01: Pirámide de Pruebas Obligatoria
Toda nueva funcionalidad o Historia de Usuario (HU) debe ser validada en sus 4 niveles antes de considerarse terminada:
1. **Capa 1 (Base de Datos):** Verificación con `test_suite.sql` y scripts transaccionales en SQL Server (cero transacciones abiertas, salidas unificadas correctas).
2. **Capa 2 (Backend):** Pruebas unitarias (`mvnw test`), pruebas de arquitectura con **ArchUnit** (aislamiento estricto de controladores) y pruebas de integración (`mvnw verify -Pintegration`). Meta obligatoria de cobertura exhaustiva hacia el **100% de ramas y líneas** (`LINE` y `BRANCH`) en lógica nuclear de casos de uso y adaptadores (mínimo JaCoCo en build: `LINE >= 80%`, `BRANCH >= 70%`).
3. **Capa 3 (Frontend):** Pruebas unitarias CI (`npm run test:ci`) con meta hacia el 100% de caminos en specs, Quality Gate de cobertura en tiempo real (`npm run coverage:realtime:check` con LINE >= 90% y BRANCH >= 80%) y compilación de producción con cero advertencias (`npm run verify`).
4. **Capa 4 (E2E / HUs):** Verificación automatizada con `AsistenciasUCO-Infra/scripts/quality/test-e2e-hus.ps1` autenticando los 5 roles contra Keycloak.

### Sección 6.02: Principio de Cero Regresiones (Non-Regression)
1. No se permite eliminar ni renombrar columnas de tablas activas ni alterar firmas de Stored Procedures existentes sin retrocompatibilidad (parámetros nuevos deben tener `= NULL`).

### Sección 6.03: Integridad de Pruebas y Prohibición de Modificaciones por Conveniencia
1. **Inviolabilidad de las Pruebas:** Queda estrictamente prohibido alterar, relajar o "acomodar" pruebas automatizadas por mera conveniencia para forzar que pasen ante un fallo.
2. **Búsqueda del Error Real:** Ante un fallo en una prueba, el deber del equipo o agente es investigar y corregir la causa raíz real en la implementación del software (Base de Datos, Backend o Frontend).
3. **Criterio Estricto de Corrección del Test:** Solo es legítimo modificar una prueba si se demuestra objetivamente que la prueba misma contiene un defecto de implementación, una aserción errada o si el contrato formal fue modificado válidamente. Queda vetado eliminar assertions, falsear mocks o silenciar validaciones con el único propósito de que la suite resulte verde.

### Sección 6.04: Contratos Inmutables WORM y Hashes SHA-256
1. Los contratos consolidados en `AsistenciasUCO-Infra/docs/contracts/` son inmutables bajo la regla WORM (*Write Once, Read Many*).
2. Cada contrato formal cuenta con su respectivo archivo `.sha256` verificado automáticamente en los Quality Gates mediante `verify-contracts.ps1`. Toda alteración de contrato exige un work item de alineación, consenso formal entre repositorios y regeneración controlada del hash.

---

## Artículo VII — Convenciones de Commits y Control de Versiones

### Sección 7.01: Estándar Conventional Commits 1.0.0
1. Todos los commits en los repositorios deben utilizar la estructura canónica:
   ```text
   <tipo>(<alcance>): <descripción concisa en imperativo y minúsculas (máx. 72 caracteres)>

   [cuerpo explicativo: ¿Qué cambió? ¿Por qué fue necesario? ¿Cómo se implementó?]

   [pie: Refs: HUxxx / Closes: HUxxx]
   ```
2. **Tipos admitidos:** `feat`, `fix`, `refactor`, `test`, `perf`, `docs`, `ci`, `chore`.
3. **Alcances estandarizados:** `db/sp`, `db/tables`, `db/views`, `backend/ports`, `backend/usecase`, `backend/adapter`, `frontend/realtime`, `frontend/auth`, `frontend/docente`, `frontend/estudiante`, `frontend/ui`, `infra/docker`, `infra/scripts`, `deps`, `auth`.
4. **Atomicidad:** Quedan prohibidos los commits masivos que junten cambios heterogéneos en un solo commit genérico.

---

## Artículo VIII — Ciclo de Vida y Entregables del Proyecto

### Sección 8.01: Hitos y Cronograma Institucional
1. **Línea Base Técnica:** Cumplimiento continuo e integral de los pilares de esta Constitución.
2. **Hito del 50%:** Avance demostrable con producto funcional y casos de negocio reales implementados sobre el catálogo de Historias de Usuario.
3. **Entrega Final (Noviembre):** Cierre y validación de la totalidad del sistema integrado y operativo para los 5 roles institucionales.

### Sección 8.02: Dinámica de Acompañamiento Técnico
1. Toda sesión de asesoría y revisión técnica debe fundamentarse en **incrementos de producto funcionando y avances tangibles**, priorizando demostraciones sobre discusiones teóricas.

---

## Ratificación

Esta Constitución entra en vigor de forma inmediata como la **Única Fuente de Verdad Técnica (SSOT)** para todos los módulos y repositorios del ecosistema Asistencias UCO.
