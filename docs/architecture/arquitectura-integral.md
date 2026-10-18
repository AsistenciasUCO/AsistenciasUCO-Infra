# Arquitectura Integral del Sistema: GestioAsistencia UCO
> **Versión:** 2.0.0 | **Ámbito:** Repositorio Unificado (3 Capas)  
> **Constitución Suprema:** [`.specify/memory/constitution.md`](file:///.specify/memory/constitution.md)

---

## Índice
* [1. Visión General y Paradigma Arquitectónico](#1-visión-general-y-paradigma-arquitectónico)
  * [Alcance y Límites del Sistema (Qué Hace y Qué No Hace)](#alcance-y-límites-del-sistema-qué-hace-y-qué-no-hace)
* [2. Topología por Capas y Estructura Modular](#2-topología-por-capas-y-estructura-modular)
  * [Frontend (Angular 18/19)](#frontend-angular-1819)
  * [Backend (Spring Boot 4 / Java 25)](#backend-spring-boot-4--java-25)
  * [Base de Datos (SQL Server 2022+)](#base-de-datos-sql-server-2022)
* [3. Contratos de Comunicación y Enfoque API-First](#3-contratos-de-comunicación-y-enfoque-api-first)
  * [Estrategia Híbrida de Diseño de APIs (Business Actions over CRUD)](#estrategia-híbrida-de-diseño-de-apis-business-actions-over-crud)
  * [Tupla Canónica en SQL Server](#tupla-canónica-en-sql-server)
  * [Contratos REST de Salida](#contratos-rest-de-salida)
  * [Paginación Estandarizada](#paginación-estandarizada)
* [4. Servicios Externos: Secretos, Parámetros y Mensajes](#4-servicios-externos-secretos-parámetros-y-mensajes)
* [5. Arquitectura del Frontend (Signals & OnPush)](#5-arquitectura-del-frontend-signals--onpush)
* [6. Flujo de Autenticación y Seguridad JWT](#6-flujo-de-autenticación-y-seguridad-jwt)
* [7. Integridad Innegociable de Pruebas](#7-integridad-innegociable-de-pruebas)
* [8. Estándar Universal de Zona Horaria (Timezone Policy)](#8-estándar-universal-de-zona-horaria-timezone-policy)
* [9. Arquitectura Cloud-Native y Principios 12-Factor App](#9-arquitectura-cloud-native-y-principios-12-factor-app)
* [10. Cobertura de Calidad (>= 80%) e Infraestructura como Código (IaC)](#10-cobertura-de-calidad--80-e-infraestructura-como-código-iac)
* [Documentos Relacionados](#documentos-relacionados)

---

## 1. Visión General y Paradigma Arquitectónico

El sistema combina **Database-Centric Architecture (Thick/Smart Database)** en SQL Server 2022+, **Arquitectura Hexagonal (Puertos y Adaptadores)** en Backend y una SPA reactiva gobernada por **Angular Signals** y **Tailwind CSS v4** en Frontend:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. FRONTEND: Angular 18/19 (Standalone Components, Signals & OnPush)       │
│    • Cliente reactivo, delgado y desacoplado de la persistencia.            │
│    • Consumo Server-Sent Events (SSE) en tiempo real (/realtime/stream).    │
│    • Cero Polling: PROHIBIDO setInterval o sondeos periódicos.             │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ HTTP / REST / SSE (Bearer JWT)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. BACKEND: Spring Boot 4.0.6 & Java 25 (Arquitectura Hexagonal Delgada)    │
│    • API Gateway, Orquestación de casos de uso y seguridad OAuth2.          │
│    • Desacoplamiento total: Application no importa infraestructura ni DB.   │
│    • Adaptadores de persistencia JPA / JDBC legacy ejecutan T-SQL/consultas.│
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ T-SQL (EXEC usp_* / SELECT uv_*)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. BASE DE DATOS: SQL Server 2022+ (Motor de Reglas y Núcleo ACID)          │
│    • Stored Procedures transaccionales obligatorios: SET XACT_ABORT ON;.    │
│    • Reglas de negocio institucionales, cupos, cálculo de inasistencia (20%).│
│    • Salida uniforme: idResultado, exitoso, mensajeUsuario, mensajeTecnico. │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Alcance y Límites del Sistema (Qué Hace y Qué No Hace)

Para evitar la dispersión de responsabilidades y delimitar el contexto acotado (Bounded Context) de la solución:

| Dimensión | ✅ Qué SÍ Hace el Sistema | ❌ Qué NO Hace el Sistema (Fuera de Alcance) |
| :--- | :--- | :--- |
| **Asistencia & Ausentismo** | • Registro en vivo por el docente titular.<br>• Auto-registro de estudiante con QR dinámico / PIN temporal.<br>• Cálculo automático de pérdida por inasistencia (**regla institucional del 20%**).<br>• Alertas tempranas al 10% y 15% de faltas. | • No gestiona control de acceso físico a edificios ni torniquetes biométricos del campus. |
| **Infraestructura y Espacios** | • Asocia la sesión al grupo pedagógico y horario temporal. | • 🛑 **NO gestiona salones físicos, aulas ni infraestructura:** No administra reservas de espacios, disponibilidad de aulas, inventario de recursos físicos (videoproyectores, silletería, laboratorios) ni traslados físicos de salón (responsabilidad de la Dirección de Planta Física). |
| **Gestión Académica** | • Matrícula técnica de estudiantes a grupos (`EstudianteGrupo`).<br>• Validación de titularidad docente y jurisdicción de coordinadores. | • **NO es un LMS (Moodle):** No gestiona calificaciones numéricas, parciales, rúbricas ni tareas.<br>• No emite títulos oficiales ni actas de grado. |
| **Justificaciones & Reclamos** | • Radicación digital con soporte documental adjunto.<br>• Flujo de resolución: revisión docente ➔ dictamen coordinador ➔ ajuste reactivo de la inasistencia. | • No sustituye trámites médicos externos ante EPS o secretarías de salud. |
| **Financiera & Nómina** | • Cero impacto financiero. | • **NO gestiona pagos ni facturación:** No procesa cobros de matrícula ni créditos.<br>• **NO gestiona nómina docente:** No liquida sueldos ni horas trabajadas. |

---

## 2. Topología por Capas y Estructura Modular

### Frontend (`GestioAsistenciaFrontend/`)
* **Tecnología:** Angular 18/19, TypeScript 5.5+, Tailwind CSS v4, Lucide Icons.
* **Paradigma:** Role-Based Feature Slices, Standalone Components, `ChangeDetectionStrategy.OnPush` y Signals (`input()`, `output()`, `computed()`). Prohibido `@Input()`/`@Output()`.

### Backend (`GestioAsistenciaBackend/`)
* **Tecnología:** Java 25, Spring Boot 4.0.6, Apache Maven.
* **Paradigma:** **Arquitectura Hexagonal (Puertos y Adaptadores) como materialización táctica de Clean Architecture**:
  - **Clean Architecture (Principio Rector):** Define la regla de dependencia hacia el núcleo. La lógica de aplicación y los casos de uso (`application`) no dependen de agentes externos, frameworks (Spring Web), persistencia (Spring Data JPA, Hibernate, JDBC) ni proveedores de identidad (Keycloak).
  - **Arquitectura Hexagonal (Estructura Táctica):** Materializa la separación mediante contratos públicos:
    - **Hexágono Interno (Núcleo):** Puertos primarios (`primaryports`) como interfaces de entrada, puertos secundarios (`secondaryports`) como interfaces de salida y casos de uso (`usecase`) como interactors orquestadores.
    - **Hexágono Externo (Infraestructura):** Adaptadores primarios (`adapter/primary/controller`) que exponen la API REST, y adaptadores secundarios (`adapter/secondary/repository` o `adapter/secondary/persistence`, `realtime`) que implementan los puertos de persistencia y mensajería.
  - **Estándar de Persistencia:** **Spring Data JPA** es el estándar target del proyecto. Los adaptadores que actualmente emplean Spring JDBC (`JdbcTemplate`) operan como **JDBC legacy en coexistencia transitoria** y se encuentran pendientes de migración incremental progresiva (documentada en `docs/persistence/JDBC_TO_JPA.md` y `ADR-002`).
* **Organización Hexagonal de Paquetes:**
  ```text
  co.edu.uco.asistenciasuco/
  ├── application/             # Hexágono Interno / Lógica de Aplicación (Clean)
  │   ├── primaryports/        # Puertos Primarios (Entradas invocadas por controladores)
  │   ├── secondaryports/      # Puertos Secundarios (Salidas implementadas por adaptadores)
  │   └── usecase/             # Interactors y orquestación pura (Sin JPA, JDBC ni Spring Web)
  ├── infrastructure/          # Hexágono Externo / Adaptadores e Infraestructura
  │   ├── adapter/primary/     # Adaptadores Primarios: Controladores REST (@RestController)
  │   ├── adapter/secondary/   # Adaptadores Secundarios: Persistencia JPA / JDBC legacy (*RepositorySqlServer*Adapter)
  │   ├── config/              # Seguridad JWT (Keycloak), CORS, OpenTelemetry
  │   └── observability/       # CorrelationIdContext, trazabilidad distribuida W3C
  └── crosscutting/            # Aspectos transversales, excepciones de negocio y validación
  ```

* **Flujo Canónico Obligatorio (Verificado con ArchUnit):**
  ```text
  [HTTP Request]
        │
        ▼
  @RestController (Adaptador Primario)
        │ Valida DTO y verifica ámbito (UserScopeService). PROHIBIDO inyectar repositorios/JPA/JDBC.
        ▼
  PrimaryPort (Puerto de Entrada - Interfaz)
        │
        ▼
  UseCaseImpl (Interactor de Aplicación)
        │ Orquesta la operación sin conocer la base de datos subyacente.
        ▼
  SecondaryPort (Puerto de Salida - Interfaz)
        │
        ▼
  *RepositorySqlServer*Adapter (Adaptador Secundario)
        │ Implementa con Spring Data JPA (o JDBC legacy pendiente de migración) y ejecuta en SQL Server.
        ▼
  [SQL Server 2022+]
  ```

### Base de Datos (`GestioAsistenciaDB/`)
* **Tecnología:** SQL Server 2022+ (Nivel 160).
* **Estructura Modular:** `/schema/tables`, `/schema/stored-procedures`, `/schema/functions`, `/schema/views`, `/schema/types`.
* **Despliegue y Pruebas:** [`deploy_schema.ps1`](../GestioAsistenciaDB/deploy_schema.ps1) y suite transaccional [`test_suite.sql`](../GestioAsistenciaDB/test_suite.sql).

---

## 3. Contratos de Comunicación y Enfoque API-First

### Estrategia Híbrida de Diseño de APIs (Business Actions over CRUD)

Alineado con las mejores prácticas de la industria en sistemas transaccionales reales, el sistema adopta una **estrategia híbrida** que prioriza las intenciones y acciones del negocio sobre mutaciones CRUD genéricas:

```text
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                      ESTRATEGIA HÍBRIDA DE APIS (BUSINESS-DRIVEN)                       │
├──────────────────────────┬──────────────────────────┬───────────────────────────────────┤
│ Tipo de Operación        │ Método HTTP / Patrón     │ Ejemplo Institucional             │
├──────────────────────────┼──────────────────────────┼───────────────────────────────────┤
│ Recursos Estándar        │ GET / POST               │ GET /api/v1/grupos/{id}           │
│ Acciones de Negocio      │ POST /{recurso}/{id}/{acc} POST /api/v1/sesiones/{id}/cerrar   │
│ Actualizaciones Parciales│ PATCH                    │ PATCH /api/v1/usuarios/{id}       │
│ Operaciones en Lote      │ POST /{recurso}/batch-*  │ POST /api/v1/asistencias/batch    │
│ Eliminación Lógica       │ POST /.../inactivar      │ POST /api/v1/grupos/{id}/inactivar│
└──────────────────────────┴──────────────────────────┴───────────────────────────────────┘
```

1. **Acciones de Negocio (`POST` con Verbos de Dominio):**
   - Las operaciones con reglas de negocio complejas (auditoría, cambio de estado, validación de titularidad, emisión de alertas) se modelan como acciones semánticas explícitas:
     - `POST /api/v1/sesiones/{id}/abrir` (en lugar de `PUT /sesiones/{id}`)
     - `POST /api/v1/sesiones/{id}/cerrar`
     - `POST /api/v1/reclamos/{id}/aprobar`
     - `POST /api/v1/reclamos/{id}/rechazar`
2. **Soft Delete Obligatorio (Prohibición de `DELETE` Físico):**
   - **Queda estrictamente prohibido el borrado destructivo físico de registros** en base de datos (`DELETE FROM`). 
   - Toda eliminación es una **inactivación lógica** (`estado = 'INACTIVO'`, `vigente = 0`, `fechaInactivacion = UTC`) para preservar la trazabilidad de auditoría requerida para acreditación institucional.
3. **PATCH sobre PUT para Modificaciones Parciales:**
   - Prohibido el uso de `PUT` que requiera enviar el objeto completo (evitando la sobreescritura o borrado accidental de atributos omitidos). Las actualizaciones parciales se realizan mediante `PATCH`.
4. **Operaciones por Lotes (Batch Operations con TVP):**
   - Procesos masivos (como la toma de asistencia a 40 estudiantes o matrícula en bloque) se envían vía `POST` encapsulando colecciones procesadas mediante Table-Valued Parameters (TVPs) en SQL Server en una única transacción atómica.

### Tupla Canónica en SQL Server
Toda operación transaccional (`INSERT`, `UPDATE`, `SOFT DELETE`) retorna determinísticamente:
```sql
SELECT 
    @idResultado             AS idResultado,
    @estadoResultado         AS exitoso,
    @mensajeUsuarioResultado AS mensajeUsuario,
    @mensajeTecnicoResultado AS mensajeTecnico;
```
* `idResultado` (`UNIQUEIDENTIFIER`): GUID del registro afectado.
* `exitoso` (`BIT`): `1` en éxito, `0` en error o rechazo de validación.
* `mensajeUsuario` (`NVARCHAR`): Mensaje amigable seguro para la interfaz.
* `mensajeTecnico` (`NVARCHAR`): Detalle técnico interno (`ERROR_MESSAGE()`) para auditoría; nunca expuesto al usuario.

### Contratos REST de Salida
* **Operación Simple (`ApiDataResponse<T>`):**
  ```json
  {
    "exitoso": true,
    "mensajeUsuario": "Asistencia registrada correctamente.",
    "datos": {
      "idAsistencia": "d3b07384-d113-4f36-980b-226e4e0b5c1e",
      "fechaRegistro": "2026-09-18T08:30:00Z"
    }
  }
  ```

* **Consulta Paginada (`ApiPageResponse<T>`):**
  ```json
  {
    "exitoso": true,
    "mensajeUsuario": "Listado de asistencias obtenido correctamente.",
    "datos": {
      "elementos": [ ... ],
      "numeroPagina": 1,
      "tamanoPagina": 20,
      "totalElementos": 85,
      "totalPaginas": 5
    }
  }
  ```

### Paginación Estandarizada
Consultas sobre entidades masivas reciben `@numeroPagina` y `@tamanoPagina`:
```sql
OFFSET (@numeroPagina - 1) * @tamanoPagina ROWS
FETCH NEXT @tamanoPagina ROWS ONLY;
```
Acompañada de `COUNT(*) OVER() AS totalRegistros` y guardas de filtro `(@filtro IS NULL OR columna = @filtro)`.

---

## 4. Servicios Externos: Secretos, Parámetros y Mensajes

```text
               ┌───────────────────────────────┐
               │    CAPA DE APLICACIÓN         │
               │   (Puertos Secundarios)       │
               └───────┬───────────────┬───────┘
                       │               │
        ┌──────────────┴────┐    ┌─────┴────────────────┐
        ▼                   ▼    ▼                      ▼
  SecretVaultPort   ParameterCatalogPort      MessageCatalogPort
        │                   │                           │
        ▼                   ▼                           ▼
 ┌──────────────┐   ┌───────────────────────────────────────────┐
 │ Azure Key    │   │         Azure App Configuration           │
 │    Vault     │   │   (Almacén: 'appcs-asist-dev-29183')      │
 │  (Secretos)  │   │  • Parámetros: 'asistencias:<mod>:<param>'│
 └──────────────┘   │  • Mensajes:   'messages:user:<code>'     │
                    └───────────────────────────────────────────┘
```

* **Secretos (`SecretVaultPort`):** Credenciales seguras administradas en Azure Key Vault (`kv-asist-dev-21245`) con fallback a variables de entorno.
* **Parámetros (`ParameterCatalogPort`):** Claves dinámicas de negocio (`asistencias:<modulo>:<parametro>`) con caché en memoria `ConcurrentHashMap`.
* **Mensajes (`MessageCatalogPort`):** Única fuente de verdad bajo `messages:user:<CODIGO>` (label `es`) y `messages:technical:<CODIGO>`. Enums Java son estrictamente fallbacks.

---

## 5. Arquitectura del Frontend (Signals & OnPush)

```text
src/app/
├── core/         # Singleton: Auth (Keycloak OIDC), Realtime SSE, Guards, Interceptores
├── shared/       # Aurora Design System, componentes dumb, pipes puros y modelos
├── layouts/      # DashboardLayout y PublicLayout
└── features/     # Módulos aislados por rol: admin, dean, coordinator, teacher, student
```

* **Componentes Dumb:** Declaran `changeDetection: ChangeDetectionStrategy.OnPush`, reciben datos vía `input<T>()` y emiten vía `output<T>()`. Cero peticiones HTTP directas.
* **Manejo de Estado:** Signals (`signal`, `computed`, `asReadonly()`) locales en servicios de feature; sin librerías globales pesadas (cero NgRx).
* **Rol Estricto de Presentación (Separación de Preocupaciones):** La SPA no traduce ni clasifica errores forenses; los mensajes informativos y de error son gestionados centralizadamente por el Backend (`mensajeUsuario` en `ApiResponse<T>` y `message` en `ApiErrorResponse`). El Frontend consume directamente estos mensajes listos para el usuario.
* **Seguridad Web:** Prohibido guardar tokens en `localStorage` en entornos productivos; uso de cookies `HttpOnly`, `withCredentials: true` y sanitización estricta (prohibido `bypassSecurityTrustHtml`).

---

## 6. Flujo de Autenticación y Seguridad JWT

```text
[ CLIENTE ANGULAR ]                  [ BACKEND API ]                     [ KEYCLOAK / DB ]
        │                                   │                                    │
        │ 1. POST /login (Credenciales)     │                                    │
        │ ────────────────────────────────> │ 2. Direct Access Grant (OIDC)      │
        │                                   │ ─────────────────────────────────> │
        │                                   │ 3. Retorna Token JWT Bearer        │
        │                                   │ <───────────────────────────────── │
        │ 4. Guarda sesión en memoria       │                                    │
        │ <──────────────────────────────── │                                    │
        │                                                                        │
        │ 5. GET /recurso (Header Authorization: Bearer <token>)                 │
        │ ────────────────────────────────> │ 6. Valida firma y claim sub/roles │
        │                                   │ 7. Invoca SP con Scope/Rol         │
        │                                   │ ─────────────────────────────────> │
```

---

## 7. Integridad Innegociable de Pruebas

> [!CAUTION]
> ### 🛑 REGLA FUNDAMENTAL DE CALIDAD
> **Queda estrictamente prohibido alterar, rebajar o relajar los tests automatizados para forzarlos a pasar cuando fallan.**
> - Ante un fallo, se debe investigar y corregir la causa raíz real en el software (Base de Datos, Backend o Frontend).
> - **Solo se permite modificar un test si:** contiene un defecto técnico manifiesto o responde a un cambio contractual formal aprobado.
> - Prohibido alterar mocks, suprimir aserciones o desactivar validaciones.

---

## 8. Estándar Universal de Zona Horaria (Timezone Policy)

Para prevenir inconsistencias horarias entre servidores, clientes web y auditorías:

```text
┌───────────────────────────┐      ISO-8601 (UTC-0)       ┌───────────────────────────┐
│     SQL Server 2022+      │ ◄─────────────────────────► │  Backend (Spring Boot 4)  │
│  SYSUTCDATETIME() / UTC   │                             │ Instant / OffsetDateTime  │
└───────────────────────────┘                             └─────────────┬─────────────┘
                                                                        │ ISO-8601 (UTC)
                                                                        ▼
                                                          ┌───────────────────────────┐
                                                          │     Frontend Angular      │
                                                          │   Transformación a Local  │
                                                          │   ('America/Bogota' UTC-5)│
                                                          └───────────────────────────┘
```

1. **Persistencia y Backend (UTC-0 Estricto):**
   - Base de Datos almacena marcas temporales (`fechaCreacion`, `fechaModificacion`, `fechaSesion`) en **UTC** mediante tipos `DATETIME2` o `DATETIMEOFFSET` empleando `SYSUTCDATETIME()`.
   - Backend serializa todas las fechas en formato ISO-8601 con sufijo `Z` (ej. `2026-09-18T13:30:00Z`).
2. **Presentación en Frontend (Hora Local del Usuario):**
   - El cliente Angular es el único responsable de convertir de UTC a la hora local (`America/Bogota` / UTC-5) al momento de renderizar, utilizando pipes puros (`{{ fecha | date:'shortTime' }}`) o formateadores de internacionalización (`Intl.DateTimeFormat`).

---

## 9. Arquitectura Cloud-Native y Principios 12-Factor App

El ecosistema adopta los principios rectores de aplicaciones nativas en la nube:

1. **Servicios 100% Stateless (Sin Estado de Sesión en Servidor):**
   - El backend Spring Boot no almacena sesiones HTTP en memoria (`SessionCreationPolicy.STATELESS`).
   - La identidad y permisos viajan en cada solicitud mediante el token JWT firmado por Keycloak.
   - Cualquier réplica o contenedor puede atender cualquier petición sin necesidad de balanceo con afinidad (*sticky sessions*), permitiendo escalabilidad elástica inmediata.
2. **Configuración y Secretos Externa (Factor III):**
   - Separación estricta entre código y configuración. Variables inyectadas por entorno, Azure App Configuration y Azure Key Vault.
3. **Logs como Streams de Eventos (Factor XI):**
   - Los servicios escriben sus trazas estructuradas a `stdout` en formato `Logstash JSONL`, recolectadas sin bloqueo por OpenTelemetry OTLP hacia la capa de observabilidad.
4. **Paridad Desarrollo/Producción (Factor X):**
   - Uso idéntico de contenedores Docker para SQL Server 2022 y Keycloak 26 en ambientes locales y productivos.

---

## 10. Cobertura de Calidad (>= 80%) e Infraestructura como Código (IaC)

1. **Quality Gate de Pruebas Unitarias y Cobertura:**
   - Cobertura mínima obligatoria en pruebas de interactores y validadores del Backend: **>= 80%**.
   - Cobertura estricta en el subsistema de tiempo real Frontend: **LINE >= 90%** y **BRANCH >= 80%** (`npm run coverage:realtime:check`).
   - Pruebas E2E automatizadas para los 5 roles jerárquicos ejecutadas vía `scripts/general/tests/test_all_hus.ps1`.
2. **Infraestructura como Código (IaC):**
   - Aprovisionamiento declarativo y versionado de contenedores mediante `docker-compose.yml`.
   - Compilación e inicialización determinística del esquema relacional y datos limpios con scripts de automatización idempotentes (`scripts/database/deploy_schema.ps1`, `scripts/iniciar-todo.ps1`).

---

## Documentos Relacionados
* [Centro Maestro de Documentación](./README.md) - Mapa general de navegación.
* [Stack Tecnológico](./stack-tecnologico.md) - Versiones y componentes de la plataforma.
* [Arquitectura SSE Real-Time](./realtime-sse-architecture.md) - Especificación del canal push reactivo.
* [Guía Operativa y Reglas de Construcción](../AGENTS.md) - Restricciones técnicas y pirámide de pruebas.
* [Directorio de Autenticación y Credenciales](./autenticacion-usuarios-y-roles.md) - Usuarios de prueba y roles.
