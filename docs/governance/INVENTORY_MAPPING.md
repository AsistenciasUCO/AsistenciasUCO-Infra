# 🗺️ INVENTORY_MAPPING.md — Mapa de Inventario y Clasificación de Activos (Fase 0)

> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Ámbito:** Auditoría y Mapeo Transversal para Centralización en `AsistenciasUCO-Infra`  
> **Rol:** Arquitectura de Software & DevOps / DevSecOps  
> **Fecha de Barrido:** Octubre 2026  
> **Estado:** BASELINE CONGELADO (Fase 0 — Solo Lectura y Mapeo)

---

## 1. Resumen Ejecutivo del Barrido de Activos

Durante la ejecución de la **Fase 0**, se realizó una auditoría no invasiva y de solo lectura sobre la totalidad del repositorio del Sistema de Gestión de Asistencias UCO. Se identificaron y clasificaron:

* **Total de Archivos Markdown (`.md`):** `349`
* **Total de Scripts de Automatización (`.ps1`, `.sh`, `.bat`, `.cmd`, `.py`):** `52`

### 1.1 Distribución General de Archivos Markdown (`.md`)

| Módulo / Ubicación | Cantidad de `.md` | Descripción del Contenido | Destino en `AsistenciasUCO-Infra` / Tratamiento |
| :--- | :---: | :--- | :--- |
| **`GestioAsistenciaBackend/docs/`** | 192 | Work Items SDD/TDD (141), Baseline (5), Contratos (6), Gobernanza (6), Arquitectura (8), ADR (2), Testing (3), Seguridad (3), Persistencia (1), Archivo (10). | Centralizar Work Items, Contratos y Gobernanza en `Infra`. Mantener docs internas de arquitectura Java en Backend. |
| **`GestioAsistenciaDB/docs/`** | 38 | Arquitectura de datos (9), Work Items DB (10), Contratos DB (2), Modelos (3), Reportes (4), Datos (5), Catálogos (3), Stored Procedures (1). | Centralizar Work Items y Contratos en `Infra`. Mantener diccionario de datos y modelos en DB. |
| **`GestioAsistenciaFrontend/docs/`** | 33 | Work Items UI (25), Contratos Frontend (3), Guías de diseño y arquitectura. | Centralizar Work Items y Contratos en `Infra`. Mantener guías de componentes Aurora en Frontend. |
| **`GestioAsistenciaBackend/.claude/`** | 23 | Agentes de rol (01 al 06), Skills técnicos backend y plantillas SDD. | Mantener configuración de agentes; alinear plantillas con `Infra`. |
| **`docs/` (Raíz del proyecto)** | 21 | Arquitectura integral, Historias de Usuario (HU001–HU174), autenticación y roles, diseño, specs. | Centralizar en `docs/governance/`, `docs/user-stories/` y `docs/runbooks/`. |
| **`.agents/` (Raíz)** | 11 | Skills de auditoría, implementación de HUs y roles transversales. | Mantener en raíz como herramientas operativas de agentes. |
| **`.specify/` (Raíz)** | 7 | Constitución técnica original y especificaciones SDD. | Unificar como SSOT en `AsistenciasUCO-Infra/docs/governance/CONSTITUTION.md`. |
| **`AsistenciasUCO-Infra/docs/`** | 4 | Constitución naciente, catálogo de HUs, README de work-items y contrato HU050. | Base receptora activa de la consolidación. |
| **Archivos sueltos en Raíz y Módulos** | 13 | `AGENTS.md`, `README.md`, `CONFIGURACION_NUEVO_EQUIPO.md`, etc. | Mantener en sus ubicaciones originales; actualizar referencias en Fase 3. |
| **TOTAL** | **349** | | |

---

## 2. Ajustes de Diseño Aprobados para Infraestructura

Antes de la Fase 1, se incorporan formalmente las dos decisiones arquitectónicas de optimización de recursos y flujo de desarrollo:

### 2.1 Ajuste 1: Docker Compose con Perfiles (`profiles`) para Ahorro de Recursos
Para evitar sobrecargar la memoria RAM y CPU de las estaciones de trabajo de los desarrolladores:
* **Perfil por Defecto (`core`):** Solo levanta los servicios estrictamente necesarios para el flujo transaccional y de autenticación:
  - **SQL Server 2022:** `sql_server_asistencias` (con límite de memoria configurado a 2 GB).
  - **Keycloak 26.0.0:** `keycloak_asistencias` (con realm institucional pre-configurado).
* **Perfiles Opcionales Bajo Demanda:**
  - `--profile observability`: Levanta OpenTelemetry Collector, Prometheus y Grafana solo cuando se requiera depurar métricas o trazas distribuidas.
  - `--profile proxy`: Levanta Traefik / Nginx con terminación SSL y cabeceras seguras para pruebas integradas de red.
  - `--profile azure`: Levanta Azurite / emuladores para pruebas desconectadas de almacenamiento y colas.
  - `--profile full`: Levanta la suite completa de contenedores.

### 2.2 Ajuste 2: Acceso Directo desde Host/IDE en Modo Local (No Proxy-Forced)
* En el entorno de desarrollo local (`dev`), todos los contenedores publican sus puertos enlazados a la interfaz de bucle invertido (`127.0.0.1`):
  - **SQL Server:** `127.0.0.1:1433` (accesible directamente desde DBeaver, Azure Data Studio, Visual Studio Code o `sqlcmd`).
  - **Keycloak:** `127.0.0.1:8443` / `127.0.0.1:8081` (accesible directamente por el Backend y navegador).
  - **Backend API:** `127.0.0.1:8080` (ejecutado en host desde IntelliJ/VSCode o contenedor).
  - **Frontend Angular:** `127.0.0.1:4200` (ejecutado en host vía `ng serve`).
* El uso del proxy inverso queda reservado para emulación de producción, pruebas de certificados TLS y validación de seguridad de cabeceras, sin interferir en la depuración paso a paso en el IDE.

---

## 3. Desglose Detallado de los 52 Scripts de Automatización Detectados

A continuación se presenta el desglose exhaustivo de los 52 scripts identificados en el repositorio, agrupados por dominio operativo, describiendo qué hace cada uno, su condición de duplicidad o dispersión, el nuevo script centralizado al que se unificará en `AsistenciasUCO-Infra` y la estrategia de transición.

### 3.1 Grupo 1: Orquestación de Entornos Locales y Arranque (12 Scripts)

| # | Ruta Actual | Lenguaje | ¿Qué hace exactamente? | Diagnóstico de Duplicidad / Dispersión | Script Unificado en `AsistenciasUCO-Infra` | Estrategia de Transición |
| :-: | :--- | :---: | :--- | :--- | :--- | :--- |
| **1** | `scripts/iniciar-todo.ps1` | `.ps1` | Arranca Docker Compose, compila esquema DDL (`deploy_schema.ps1`), siembra datos canónicos (`restablecer-datos-limpios.ps1`) y lanza Backend y Frontend en consolas separadas. | **Duplicado:** Es una copia funcional de `scripts/general/iniciar-todo.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/start-dev.ps1` | En Fase 2 se convierte en wrapper delegador de 3 líneas hacia `start-dev.ps1`. Se depreca en Fase 3. |
| **2** | `scripts/general/iniciar-todo.ps1` | `.ps1` | Misma lógica de arranque completo que el anterior pero con formateo de colores adicional y verificación de puertos. | **Duplicado:** Redundancia directa con la raíz de `scripts/`. | `AsistenciasUCO-Infra/scripts/orchestration/start-dev.ps1` | Sustituir por wrapper hacia Infra en Fase 2; eliminar en Fase 3. |
| **3** | `scripts/iniciar-app.ps1` | `.ps1` | Inicia únicamente la aplicación web: Backend en puerto 8080 (`mvn spring-boot:run`) y Frontend en puerto 4200 (`ng serve`), asumiendo que la BD ya está arriba. | **Duplicado:** Copia idéntica de `scripts/general/iniciar-app.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/start-apps.ps1` | Wrapper hacia Infra en Fase 2. |
| **4** | `scripts/general/iniciar-app.ps1` | `.ps1` | Inicia Backend y Frontend en consolas hijas independientes con verificación de procesos existentes. | **Duplicado:** Redundante con `scripts/iniciar-app.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/start-apps.ps1` | Wrapper hacia Infra en Fase 2; eliminar en Fase 3. |
| **5** | `scripts/detener-todo.ps1` | `.ps1` | Mata los procesos Java y Node que ocupan los puertos 8080 y 4200 vía `Get-NetTCPConnection` y ejecuta `docker compose down`. | **Duplicado:** Idéntico a `scripts/general/detener-todo.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/stop-dev.ps1` | Wrapper hacia Infra en Fase 2. |
| **6** | `scripts/general/detener-todo.ps1` | `.ps1` | Rutina idéntica de liberación de puertos y detención de contenedores con reporte en consola. | **Duplicado:** Redundante con `scripts/detener-todo.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/stop-dev.ps1` | Sustituir por wrapper hacia Infra en Fase 2; eliminar en Fase 3. |
| **7** | `scripts/start-dev.ps1` | `.ps1` | Menú interactivo de selección de arranque (Todo, Solo BD, Solo Apps). | **Duplicado:** Idéntico a `scripts/general/start-dev.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/start-dev.ps1` | Unificar con soporte de perfiles (`-Profile core`, `-Profile full`). |
| **8** | `scripts/general/start-dev.ps1` | `.ps1` | Menú interactivo de arranque idéntico al de la raíz. | **Duplicado:** Redundancia directa. | `AsistenciasUCO-Infra/scripts/orchestration/start-dev.ps1` | Wrapper hacia Infra en Fase 2; eliminar en Fase 3. |
| **9** | `GestioAsistenciaBackend/scripts/run-local.ps1` | `.ps1` | Lanza Spring Boot con el perfil local dev: `.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=dev`. | **Duplicado:** Copia en `scripts/backend/run-local.ps1`. | Mantener local / Unificar en `AsistenciasUCO-Infra/scripts/orchestration/start-backend.ps1` | Mantener como atajo interno en Backend delegando a mvnw wrapper. |
| **10** | `scripts/backend/run-local.ps1` | `.ps1` | Ejecuta el Backend desde la carpeta global de scripts. | **Duplicado:** Redundancia con el script interno de Backend. | `AsistenciasUCO-Infra/scripts/orchestration/start-backend.ps1` | Wrapper hacia Infra en Fase 2; eliminar en Fase 3. |
| **11** | `GestioAsistenciaFrontend/scripts/run-local.ps1` | `.ps1` | Lanza la aplicación Angular en local ejecutando `npm start` en el puerto 4200. | **Duplicado:** Copia en `scripts/frontend/run-local.ps1`. | Mantener local / Unificar en `AsistenciasUCO-Infra/scripts/orchestration/start-frontend.ps1` | Mantener como atajo interno en Frontend delegando a npm. |
| **12** | `scripts/frontend/run-local.ps1` | `.ps1` | Ejecuta el Frontend desde la carpeta global de scripts. | **Duplicado:** Redundancia con el script interno de Frontend. | `AsistenciasUCO-Infra/scripts/orchestration/start-frontend.ps1` | Wrapper hacia Infra en Fase 2; eliminar en Fase 3. |

---

### 3.2 Grupo 2: Variables de Entorno y Configuración (2 Scripts)

| # | Ruta Actual | Lenguaje | ¿Qué hace exactamente? | Diagnóstico de Duplicidad / Dispersión | Script Unificado en `AsistenciasUCO-Infra` | Estrategia de Transición |
| :-: | :--- | :---: | :--- | :--- | :--- | :--- |
| **13** | `GestioAsistenciaBackend/scripts/load-env.ps1` | `.ps1` | Parsea el archivo `.env` línea por línea y exporta las variables de entorno de proceso a la sesión de PowerShell (`$env:DB_URL`, etc.). | **Duplicado:** Copia idéntica en `scripts/backend/load-env.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/load-env.ps1` | Centralizar como SSOT de carga de entorno en Infra; wrapper en Backend. |
| **14** | `scripts/backend/load-env.ps1` | `.ps1` | Lee variables del archivo `.env` para la sesión de PowerShell. | **Duplicado:** Redundante con `GestioAsistenciaBackend/scripts/load-env.ps1`. | `AsistenciasUCO-Infra/scripts/orchestration/load-env.ps1` | Wrapper en Fase 2; eliminar en Fase 3. |

---

### 3.3 Grupo 3: Base de Datos, DDL y Pruebas Transaccionales (16 Scripts)

| # | Ruta Actual | Lenguaje | ¿Qué hace exactamente? | Diagnóstico de Duplicidad / Dispersión | Script Unificado en `AsistenciasUCO-Infra` | Estrategia de Transición |
| :-: | :--- | :---: | :--- | :--- | :--- | :--- |
| **15** | `GestioAsistenciaDB/deploy_schema.ps1` | `.ps1` | Compila en orden relacional estricto tablas, funciones, vistas, SPs y tipos de `GestioAsistenciaDB/schema/` contra SQL Server usando `sqlcmd`. | **Duplicado:** Copia idéntica en `scripts/database/deploy_schema.ps1`. | `AsistenciasUCO-Infra/components/sqlserver/scripts/deploy-schema.ps1` | Centralizar en el componente de SQL Server en Infra; wrapper en DB. |
| **16** | `scripts/database/deploy_schema.ps1` | `.ps1` | Compilador DDL de base de datos desde la carpeta global de scripts. | **Duplicado:** Redundante con `GestioAsistenciaDB/deploy_schema.ps1`. | `AsistenciasUCO-Infra/components/sqlserver/scripts/deploy-schema.ps1` | Wrapper en Fase 2; eliminar en Fase 3. |
| **17** | `scripts/restablecer-datos-limpios.ps1` | `.ps1` | Ejecuta la siembra SQL de 11 usuarios canónicos (estudiante, docente, coordinador, decano, admin) garantizando IDs determinísticos. | **Duplicado:** Copia de `scripts/database/restablecer-datos-limpios.ps1`. | `AsistenciasUCO-Infra/components/sqlserver/scripts/seed-clean-data.ps1` | Centralizar en el componente de BD; wrapper en raíz. |
| **18** | `scripts/database/restablecer-datos-limpios.ps1` | `.ps1` | Siembra de datos limpia institucional. | **Duplicado:** Redundante con la raíz de scripts. | `AsistenciasUCO-Infra/components/sqlserver/scripts/seed-clean-data.ps1` | Wrapper en Fase 2; eliminar en Fase 3. |
| **19** | `scripts/database/apply_proc.ps1` | `.ps1` | Permite aplicar un único procedimiento almacenado o vista pasando la ruta relativa por argumento, evitando compilar toda la base. | **Disperso:** Aislado en `scripts/database/`. | `AsistenciasUCO-Infra/components/sqlserver/scripts/apply-single-object.ps1` | Mover a las utilidades de desarrollo rápido de SQL Server en Infra. |
| **20** | `scripts/database/fix_user_types.ps1` | `.ps1` | Script transaccional correctivo para migrar o reparar tipos de usuario en bases existentes. | **Disperso:** Script correctivo puntual. | `AsistenciasUCO-Infra/components/sqlserver/scripts/migrations/fix-user-types.ps1` | Preservar en carpeta de migraciones históricas de BD. |
| **21** | `scripts/database/seed_realtime_test_group.sql` | `.sql` | Datos de prueba para simular asistencia en tiempo real y flujo SSE en un grupo específico. | **Disperso:** Script SQL suelto en scripts. | `AsistenciasUCO-Infra/components/sqlserver/init/seed-realtime.sql` | Integrar a la carpeta de fixtures/init de SQL Server. |
| **22** | `GestioAsistenciaDB/test_summary.ps1` | `.ps1` | Ejecuta la suite `test_suite.sql` y formatea la salida T-SQL en una tabla resumen de pruebas pasadas y fallidas. | **Duplicado:** Copia en `scripts/database/tests/test_summary.ps1`. | `AsistenciasUCO-Infra/components/sqlserver/scripts/test-summary.ps1` | Centralizar como runner oficial de pruebas T-SQL en Infra; wrapper en DB. |
| **23** | `scripts/database/tests/test_summary.ps1` | `.ps1` | Ejecutor de reporte de pruebas de base de datos. | **Duplicado:** Redundante con `GestioAsistenciaDB/test_summary.ps1`. | `AsistenciasUCO-Infra/components/sqlserver/scripts/test-summary.ps1` | Wrapper en Fase 2; eliminar en Fase 3. |
| **24** | `GestioAsistenciaDB/scripts/freeze-manifest.ps1` | `.ps1` | Calcula y congela los hashes criptográficos SHA-256 de los objetos DDL de base de datos para cumplimiento WORM. | **Disperso:** Aislado en la carpeta scripts de DB. | `AsistenciasUCO-Infra/scripts/quality/verify-contracts.ps1` | Integrar en el script maestro de verificación de contratos WORM. |
| **25** | `GestioAsistenciaDB/scripts/secret-hygiene.ps1` | `.ps1` | Realiza un escaneo estático de scripts T-SQL para detectar contraseñas quemadas (`sa`, credenciales de prueba). | **Disperso:** Aislado en DB. | `AsistenciasUCO-Infra/scripts/security/check-secrets.ps1` | Integrar en la suite de DevSecOps centralizada. |
| **26** | `scripts/database/tests/reset_carlos.ps1` | `.ps1` | Restablece las asistencias y matrículas del usuario de prueba "Carlos" para pruebas manuales repetibles. | **Disperso:** Script de testing manual ad-hoc. | `AsistenciasUCO-Infra/components/sqlserver/scripts/fixtures/reset-carlos.ps1` | Mover a suite de fixtures de pruebas en Infra. |
| **27** | `scripts/database/tests/test_carlos.ps1` | `.ps1` | Ejecuta la marcación de asistencia de Carlos directamente invocando el SP respectivo. | **Disperso:** Script de testing manual. | `AsistenciasUCO-Infra/components/sqlserver/scripts/fixtures/test-carlos.ps1` | Mover a fixtures de pruebas. |
| **28** | `scripts/database/tests/test_carlos_enroll.ps1` | `.ps1` | Prueba la matrícula de Carlos en un grupo académico específico vía SP. | **Disperso:** Script de testing manual. | `AsistenciasUCO-Infra/components/sqlserver/scripts/fixtures/test-enroll.ps1` | Mover a fixtures de pruebas. |
| **29** | `scripts/database/tests/test_carlos_grupo2.ps1` | `.ps1` | Prueba la matrícula de Carlos en un grupo secundario. | **Disperso:** Script de testing manual. | `AsistenciasUCO-Infra/components/sqlserver/scripts/fixtures/test-enroll.ps1` | Mover a fixtures de pruebas. |
| **30** | `scripts/database/tests/test_enroll.ps1` | `.ps1` | Ejecuta pruebas del flujo de matrícula manual en base de datos. | **Disperso:** Script de testing manual. | `AsistenciasUCO-Infra/components/sqlserver/scripts/fixtures/test-enroll.ps1` | Integrar en `test_suite.sql` o suite E2E. |

---

### 3.4 Grupo 4: Identidad e IAM — Keycloak (6 Scripts)

| # | Ruta Actual | Lenguaje | ¿Qué hace exactamente? | Diagnóstico de Duplicidad / Dispersión | Script Unificado en `AsistenciasUCO-Infra` | Estrategia de Transición |
| :-: | :--- | :---: | :--- | :--- | :--- | :--- |
| **31** | `GestioAsistenciaBackend/infra/keycloak/scripts/bootstrap-keycloak.ps1` | `.ps1` | Espera el arranque del contenedor de Keycloak, crea el realm `asistencias-uco`, configura los clientes OIDC institucionales y roles. | **Acoplamiento indebido:** Reside dentro del backend en lugar de infraestructura IAM. | `AsistenciasUCO-Infra/components/keycloak/scripts/bootstrap.ps1` | Mover al componente autónomo de Keycloak en Infra. Wrapper temporal en Backend. |
| **32** | `GestioAsistenciaBackend/infra/keycloak/scripts/export-realm.ps1` | `.ps1` | Exporta la configuración viva del realm de Keycloak a un archivo JSON canónico (`realm-export.json`). | **Disperso:** Reside en Backend. | `AsistenciasUCO-Infra/components/keycloak/scripts/export-realm.ps1` | Mover a `components/keycloak/scripts/`. |
| **33** | `GestioAsistenciaBackend/infra/keycloak/scripts/validate-keycloak.ps1` | `.ps1` | Ejecuta verificaciones de salud OIDC (`/.well-known/openid-configuration`) y valida que los endpoints emitan tokens válidos. | **Disperso:** Reside en Backend. | `AsistenciasUCO-Infra/components/keycloak/scripts/validate.ps1` | Mover a `components/keycloak/scripts/`. |
| **34** | `GestioAsistenciaBackend/infra/keycloak/scripts/seed-e2e-users.ps1` | `.ps1` | Crea los 11 usuarios institucionales en Keycloak asignando los roles correspondientes (Estudiante, Docente, Coordinador, etc.). | **Disperso:** Reside en Backend. | `AsistenciasUCO-Infra/components/keycloak/scripts/seed-users.ps1` | Mover a `components/keycloak/scripts/`. |
| **35** | `GestioAsistenciaBackend/infra/keycloak/scripts/get-test-token.ps1` | `.ps1` | Solicita un token JWT Bearer a Keycloak mediante Password Grant para pruebas locales en Swagger, Postman o cURL. | **Disperso:** Reside en Backend. | `AsistenciasUCO-Infra/components/keycloak/scripts/get-token.ps1` | Mover a `components/keycloak/scripts/` para uso de todo el equipo. |
| **36** | `GestioAsistenciaBackend/infra/keycloak/scripts/diagnose-idusuario.ps1` | `.ps1` | Decodifica el token JWT y valida que el claim institucional `idUsuario` y los roles de realm estén presentes y mapeados correctamente. | **Disperso:** Reside en Backend. | `AsistenciasUCO-Infra/components/keycloak/scripts/diagnose-token.ps1` | Mover a `components/keycloak/scripts/`. |

---

### 3.5 Grupo 5: Sincronización Cloud y Catálogos en Azure (4 Scripts)

| # | Ruta Actual | Lenguaje | ¿Qué hace exactamente? | Diagnóstico de Duplicidad / Dispersión | Script Unificado en `AsistenciasUCO-Infra` | Estrategia de Transición |
| :-: | :--- | :---: | :--- | :--- | :--- | :--- |
| **37** | `scripts/azure/export_json_utf8.ps1` | `.ps1` | Exporta los catálogos y mensajes de negocio a formato JSON UTF-8 sin BOM para su posterior ingestión en Azure. | **Disperso:** Aislado en `scripts/azure/`. | `AsistenciasUCO-Infra/scripts/cloud-sync/export-catalogs.ps1` | Centralizar en la suite de sincronización cloud de Infra. |
| **38** | `scripts/azure/sync-appconfig-catalog.ps1` | `.ps1` | Sincroniza los mensajes y parámetros con Azure App Configuration (`appcs-asist-dev-29183`) vía REST/CLI. | **Disperso:** Aislado en `scripts/azure/`. | `AsistenciasUCO-Infra/scripts/cloud-sync/sync-appconfig.ps1` | Centralizar en `scripts/cloud-sync/`. |
| **39** | `scripts/azure/upload_rest_utf8.ps1` | `.ps1` | Realiza peticiones REST directas a la API de Azure App Configuration para cargar pares clave-valor. | **Duplicidad tecnológica:** Solapamiento con `sync-appconfig-catalog.ps1`. | `AsistenciasUCO-Infra/scripts/cloud-sync/sync-appconfig.ps1` | Consolidar dentro del script principal de sincronización. |
| **40** | `scripts/azure/upload_rest_utf8.py` | `.py` | Implementación en Python de la carga REST a Azure App Configuration. | **Duplicidad tecnológica:** Alternativa Python innecesaria en un entorno estandarizado en PowerShell. | `AsistenciasUCO-Infra/scripts/cloud-sync/sync-appconfig.ps1` | Deprecar en Fase 3 en favor de la versión estándar en PowerShell. |

---

### 3.6 Grupo 6: Pruebas Unitarias, de Integración y E2E (6 Scripts)

| # | Ruta Actual | Lenguaje | ¿Qué hace exactamente? | Diagnóstico de Duplicidad / Dispersión | Script Unificado en `AsistenciasUCO-Infra` | Estrategia de Transición |
| :-: | :--- | :---: | :--- | :--- | :--- | :--- |
| **41** | `GestioAsistenciaBackend/scripts/test-local.ps1` | `.ps1` | Ejecuta la suite de pruebas Maven de Backend (`.\mvnw.cmd test`) con reporte de resultados en consola. | **Duplicado:** Copia en `scripts/backend/tests/test-local.ps1`. | `AsistenciasUCO-Infra/scripts/quality/test-backend.ps1` | Mantener atajo interno en Backend; centralizar versión global en Infra. |
| **42** | `scripts/backend/tests/test-local.ps1` | `.ps1` | Ejecuta las pruebas de backend desde la carpeta global de scripts. | **Duplicado:** Redundante con `GestioAsistenciaBackend/scripts/test-local.ps1`. | `AsistenciasUCO-Infra/scripts/quality/test-backend.ps1` | Wrapper hacia Infra en Fase 2; eliminar en Fase 3. |
| **43** | `scripts/backend/tests/test_sesion.ps1` | `.ps1` | Realiza una petición HTTP POST al endpoint de sesiones (`/api/v1/sesiones`) para validar la creación en caliente. | **Disperso:** Script de prueba de integración ad-hoc. | `AsistenciasUCO-Infra/scripts/quality/integration/test-session-http.ps1` | Integrar a suite de smoke tests de Infra. |
| **44** | `scripts/backend/tests/test_tipos.ps1` | `.ps1` | Realiza peticiones GET para validar que los catálogos de tipos respondan correctamente desde la API. | **Disperso:** Script de prueba ad-hoc. | `AsistenciasUCO-Infra/scripts/quality/integration/test-catalogs-http.ps1` | Integrar a suite de smoke tests de Infra. |
| **45** | `scripts/general/tests/test_all_hus.ps1` | `.ps1` | Master Test Runner automatizado que ejecuta las pruebas E2E de todas las Historias de Usuario (HU001–HU174). | **Duplicado:** Existe una copia de trabajo idéntica en `scratch/test_all_hus.ps1`. | `AsistenciasUCO-Infra/scripts/quality/test-e2e-hus.ps1` | Convertir en el validador oficial del Quality Gate en Infra. |
| **46** | `scratch/test_all_hus.ps1` | `.ps1` | Copia de trabajo de la suite E2E utilizada para depuración temporal. | **Duplicado:** Redundante con `scripts/general/tests/test_all_hus.ps1`. | `AsistenciasUCO-Infra/scripts/quality/test-e2e-hus.ps1` | Eliminar en Fase 3 tras verificar la versión unificada. |
| **47** | `scripts/database/tests/test_enroll_new.ps1` | `.ps1` | Variante de prueba de matrícula con nuevos parámetros para casos extremos. | **Disperso:** Script ad-hoc. | `AsistenciasUCO-Infra/components/sqlserver/scripts/fixtures/test-enroll.ps1` | Consolidar con el fixture de matrícula. |

---

### 3.7 Grupo 7: Wrappers de Plataforma, Build Systems y Agentes (5 Scripts)

| # | Ruta Actual | Lenguaje | ¿Qué hace exactamente? | Diagnóstico de Duplicidad / Dispersión | Script Unificado en `AsistenciasUCO-Infra` | Estrategia de Transición |
| :-: | :--- | :---: | :--- | :--- | :--- | :--- |
| **48** | `GestioAsistenciaBackend/mvnw.cmd` | `.cmd` | Wrapper oficial de Apache Maven para compilar y probar Backend en Windows sin instalar Maven global. | **Componente esencial:** Estándar oficial de construcción de Backend. | **Se mantiene en su ubicación original** (`GestioAsistenciaBackend/mvnw.cmd`). | No se mueve ni se modifica. Infraestructura lo invoca para compilar la imagen. |
| **49** | `GestioAsistenciaFrontend/docker-entrypoint.d/40-env-js.sh` | `.sh` | Script de inicialización de Nginx que inyecta dinámicamente variables de entorno (`window.__env`) al contenedor web. | **Componente esencial:** Exclusivo del contenedor de frontend. | **Se mantiene en su ubicación original** (`GestioAsistenciaFrontend/...`). | No se mueve; el compose de Infraestructura lo monta como volumen. |
| **50** | `.agents/scripts/pre_invocation_reminder.ps1` | `.ps1` | Hook de auditoría ejecutado antes de las tareas de IA para recordar la constitución y reglas de Clean Architecture. | **Componente de gobierno:** Específico del entorno de desarrollo asistido por IA. | **Se mantiene en su ubicación original** (`.agents/scripts/`). | No se mueve; se actualiza para apuntar a la constitución unificada en Infra. |
| **51** | `.agents/scripts/pre_tool_safety_gate.ps1` | `.ps1` | Validador de seguridad previo al uso de herramientas de edición para evitar modificaciones destructivas. | **Componente de gobierno:** Específico de agentes. | **Se mantiene en su ubicación original** (`.agents/scripts/`). | No se mueve. |
| **52** | `.github/modernize/java-upgrade/hooks/scripts/recordToolUse.ps1` / `.sh` | `.ps1`/`.sh` | Scripts de telemetría interna para auditar el uso de herramientas en la modernización a Java 25. | **Componente de CI/CD histórico:** Específico del pipeline de modernización. | **Se mantiene en su ubicación original** (`.github/...`). | No se mueve. |

---

## 4. Matriz de Mapeo Resumida: Origen vs. Destino Unificado

A continuación se resume la tabla de equivalencias de comandos para la futura transición de los desarrolladores:

| Comando / Operación Actual | Nueva Ubicación en `AsistenciasUCO-Infra` | Perfil Requerido |
| :--- | :--- | :---: |
| `.\scripts\iniciar-todo.ps1` | `.\AsistenciasUCO-Infra\scripts\orchestration\start-dev.ps1` | `core` (por defecto) |
| `.\scripts\start-dev.ps1 -Full` | `.\AsistenciasUCO-Infra\scripts\orchestration\start-dev.ps1 -Profile full` | `full` |
| `.\scripts\detener-todo.ps1` | `.\AsistenciasUCO-Infra\scripts\orchestration\stop-dev.ps1` | N/A |
| `.\GestioAsistenciaDB\deploy_schema.ps1` | `.\AsistenciasUCO-Infra\components\sqlserver\scripts\deploy-schema.ps1` | `core` |
| `.\scripts\restablecer-datos-limpios.ps1` | `.\AsistenciasUCO-Infra\components\sqlserver\scripts\seed-clean-data.ps1` | `core` |
| `.\GestioAsistenciaDB\test_summary.ps1` | `.\AsistenciasUCO-Infra\components\sqlserver\scripts\test-summary.ps1` | `core` |
| `.\GestioAsistenciaBackend\infra\keycloak\scripts\bootstrap-keycloak.ps1` | `.\AsistenciasUCO-Infra\components\keycloak\scripts\bootstrap.ps1` | `core` |
| `.\GestioAsistenciaBackend\infra\keycloak\scripts\get-test-token.ps1` | `.\AsistenciasUCO-Infra\components\keycloak\scripts\get-token.ps1` | `core` |
| `.\scripts\general\tests\test_all_hus.ps1` | `.\AsistenciasUCO-Infra\scripts\quality\test-e2e-hus.ps1` | `core` |
| `.\scripts\azure\sync-appconfig-catalog.ps1` | `.\AsistenciasUCO-Infra\scripts\cloud-sync\sync-appconfig.ps1` | Bajo demanda |

---

## 5. Clasificación Detallada de Documentación Markdown (349 Archivos)

### 5.1 Categoría A: Gobernanza, Constitución y Ley Técnica (SSOT)
* **Archivos Identificados:**
  - `.specify/memory/constitution.md` (Constitución técnica suprema original).
  - `AsistenciasUCO-Infra/docs/governance/CONSTITUTION.md` (Constitución en 4ª capa).
  - `GestioAsistenciaBackend/docs/governance/SOURCE_OF_TRUTH.md`
  - `GestioAsistenciaBackend/docs/governance/API_DESIGN_RULES.md`
  - `GestioAsistenciaBackend/docs/governance/DEFINITION_OF_READY.md`
  - `GestioAsistenciaBackend/docs/baseline/DEFINITION_OF_DONE.md`
  - `AGENTS.md` (Raíz del proyecto) y `GestioAsistenciaBackend/AGENTS.md`.
* **Tratamiento en Fase 1:** Unificar en `AsistenciasUCO-Infra/docs/governance/` como Única Fuente de Verdad Inviolable. Los módulos contendrán un enlace canónico hacia este directorio.

### 5.2 Categoría B: Contratos Públicos WORM (Write Once, Read Many)
* **Archivos Identificados:**
  - `GestioAsistenciaBackend/docs/contracts/openapi/openapi-golden-path.yaml` (+ `.sha256`).
  - `GestioAsistenciaBackend/docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` (+ `.sha256`).
  - `GestioAsistenciaBackend/docs/contracts/external/db/DB_BASELINE_CONTRACT.md` (+ `.sha256`).
  - `GestioAsistenciaDB/docs/contracts/DB_DEVELOP_FREEZE_ADDENDUM.md`.
  - `GestioAsistenciaFrontend/docs/contracts/` (Contratos locales de integración UI).
* **Tratamiento en Fase 1:** Congelar bajo `AsistenciasUCO-Infra/docs/contracts/` organizados en `/openapi`, `/db` y `/events` (SSE), con validación automatizada de checksums criptográficos.

### 5.3 Categoría C: Catálogo de Historias de Usuario y Work Items SDD/TDD
* **Archivos Identificados:**
  - Catálogo Maestro: `docs/historias-de-usuario.md` (174 HUs) y `AsistenciasUCO-Infra/docs/user-stories/HU-CATALOG.md`.
  - Work Items en Backend: 141 archivos `.md` en `GestioAsistenciaBackend/docs/work-items/` correspondientes al pipeline SDD (`PLAN.md`, `CONTRACT.md`, `TEST_PLAN.md`, `VALIDATION.md`, `CLOSURE.md`).
  - Work Items en DB: 10 archivos en `GestioAsistenciaDB/docs/work-items/`.
  - Work Items en Frontend: 25 archivos en `GestioAsistenciaFrontend/docs/work-items/`.
* **Tratamiento en Fase 1:** Centralizar el pipeline unificado de trabajo por HU en `AsistenciasUCO-Infra/docs/work-items/HUxxx-nombre/`, evitando la dispersión del ciclo de vida de una misma HU entre tres carpetas distintas.

### 5.4 Categoría D: Baseline, Línea Base y Deuda Técnica
* **Archivos Identificados:**
  - `GestioAsistenciaBackend/docs/baseline/LINEA_BASE.md`
  - `GestioAsistenciaBackend/docs/baseline/TECHNICAL_DEBT.md` (Catálogo de deudas TD-001 a TD-054).
  - `GestioAsistenciaBackend/docs/baseline/MANUAL_VALIDATION_LEDGER.md`
* **Tratamiento en Fase 1:** Consolidar como métricas del sistema en `AsistenciasUCO-Infra/docs/baseline/`.

### 5.5 Categoría E: Guías de Arquitectura y Persistencia
* **Archivos Identificados:**
  - `docs/arquitectura-integral.md` (Visión global del sistema).
  - `docs/autenticacion-usuarios-y-roles.md` (Directorio de roles y Keycloak).
  - `docs/sistema-diseno.md` (Aurora Design System).
  - `GestioAsistenciaBackend/docs/architecture/` (Estructura de paquetes Java, ADRs).
  - `GestioAsistenciaBackend/docs/persistence/JDBC_TO_JPA.md` (Estrategia de migración JPA).
  - `GestioAsistenciaDB/docs/arquitectura/` (Estándares de transaccionalidad, SPs y Vistas).
* **Tratamiento en Fase 1:** La arquitectura integral y de IAM se centraliza en `AsistenciasUCO-Infra/docs/runbooks/` y `governance/`. Las especificaciones internas de cada lenguaje (ej. estructura de paquetes Spring o componentes Angular) se preservan dentro de sus respectivos módulos.

---

## 6. Próximo Paso: Cierre Formal de Fase 0 y Transición a Fase 1

Con el inventario de los 52 scripts y 349 archivos Markdown formalizado y congelado en este documento:
1. **Fase 0 queda formalmente cerrada.**
2. **Autorización para Fase 1:** Proceder con la creación de la estructura modular en `AsistenciasUCO-Infra/components/` (SQL Server, Keycloak, Observabilidad, Proxy) y los orquestadores maestros con perfiles (`core`, `full`) sin alterar ni borrar archivos en las rutas actuales.
