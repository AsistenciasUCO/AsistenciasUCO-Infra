# 🏛️ AsistenciasUCO-Infra — 4ª Capa: Gobernanza, Infraestructura y Flujo de Desarrollo

> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Ámbito:** Repositorio Unificado `GestioAsistencia` (Base de Datos, Backend API, Frontend Web e Infraestructura)  
> **Rol:** Cuarta Capa Transversal — Única Fuente de Verdad (SSOT) para Gobernanza, Hardening, Contratos WORM, Orquestación de Contenedores y Automatización DevSecOps.  
> **Versión:** 2.0.0  
> **Fecha de Actualización:** Octubre 2026  

---

## 1. Visión y Arquitectura de la 4ª Capa

El ecosistema Asistencias UCO está diseñado en 3 capas de ejecución desacopladas gobernadas y soportadas por 1 capa transversal de infraestructura y ley técnica:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       4. AsistenciasUCO-Infra                               │
│     (Gobernanza SSOT, Contratos WORM, Hardening, Contenedores & Scripts)    │
│  • Constitución Técnica Única (CONSTITUTION.md)                             │
│  • Contratos Inmutables SHA-256 (OpenAPI 3.0, T-SQL SPs/Vistas, Eventos SSE)│
│  • Orquestador Docker Compose modular por Perfiles (core, full)             │
│  • Hardening Least Privilege (app_asistencias_user, 127.0.0.1, Security Headers)│
│  • Suite de Automatización PowerShell (Orquestación, Cloud Sync, Calidad)   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Rige, despliega y monitorea:
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│ 1. Base de Datos │          │    2. Backend    │          │   3. Frontend    │
│  (SQL Server)    │          │  (Spring Boot)   │          │   (Angular 19)   │
│  • Smart Database│          │  • Clean Arch    │          │  • Standalone    │
│  • Transaccional │          │  • Puertos & Adp │          │  • Signals       │
│  • Vistas/SPs    │          │  • REST & OTel   │          │  • Tailwind CSS  │
└──────────────────┘          └──────────────────┘          └──────────────────┘
```

---

## 2. Estructura de Directorios

```text
AsistenciasUCO-Infra/
├── .env.example               # SSOT Canónico de variables de entorno y límites
├── .gitignore                 # Blindaje contra fugas de .env, certificados y .bak
├── docker-compose.yml         # Orquestador Docker maestro gobernado por perfiles
│
├── components/                # Definiciones modulares de contenedores e inicialización
│   ├── sqlserver/             # SQL Server 2022 (Collation Modern_Spanish_CI_AS, RAM 2GB)
│   │   ├── init/              # 01-hardening-least-privilege.sql (Rol db_app_executor)
│   │   └── scripts/           # deploy-schema.ps1, seed-clean-data.ps1, test-summary.ps1
│   ├── keycloak/              # Keycloak 26.7.1 + PostgreSQL 17 dedicado
│   │   ├── realm-import/      # asistencias-uco-realm.json (Roles, clients, idUsuario)
│   │   └── scripts/           # bootstrap.ps1, seed-users.ps1, get-token.ps1, etc.
│   ├── observability/         # OTel Collector Contrib + Prometheus v3 + Grafana
│   │   ├── otel-collector/    # config.yaml (OTLP gRPC/HTTP pipelines)
│   │   ├── prometheus/        # prometheus.yml (Scrape de OTel, Actuator, Keycloak)
│   │   └── grafana/           # Provisioning automático de Prometheus datasource
│   └── proxy/                 # Traefik v3 Reverse Proxy
│       ├── traefik.yml        # Configuración estática y dashboard
│       └── dynamic/           # middlewares.yml (HSTS, CSP, X-Frame-Options DENY)
│
├── scripts/                   # Suite de automatización centralizada (21 scripts)
│   ├── orchestration/         # start-dev.ps1, stop-dev.ps1, status-dev.ps1, start-apps.ps1, load-env.ps1
│   ├── cloud-sync/            # sync-appconfig.ps1, export-catalogs.ps1
│   ├── security/              # check-secrets.ps1 (Escaneo estático DevSecOps)
│   └── quality/               # verify-contracts.ps1, test-backend.ps1, test-e2e-hus.ps1
│
├── docs/                      # Biblioteca de conocimiento, contratos y gobernanza
│   ├── governance/            # CONSTITUTION.md, SOURCE_OF_TRUTH.md, API_DESIGN_RULES.md, DoR, DoD
│   ├── contracts/             # Contratos públicos inmutables WORM y firmas .sha256
│   │   ├── openapi/           # openapi-golden-path.yaml, BACKEND_GOLDEN_PATH_CONTRACT.md
│   │   ├── db/                # DB_BASELINE_CONTRACT.md, DB_DEVELOP_FREEZE_ADDENDUM.md
│   │   └── events/            # REALTIME_EVENT_CONTRACT.md (SSE Events)
│   ├── baseline/              # LINEA_BASE.md, TECHNICAL_DEBT.md (TD-001 a TD-054)
│   ├── hardening/             # SECURITY_AND_HARDENING.md
│   ├── runbooks/              # LOCAL_ENVIRONMENT_SETUP.md, MIGRATION_GUIDE.md
│   └── user-stories/          # Catálogo maestro de Historias de Usuario (HU001 - HU174)
└── README.md                  # Este documento
```

---

## 3. Perfiles de Contenedores Docker (Ahorro de RAM)

Para evitar saturar la memoria RAM en el equipo de desarrollo, el orquestador maestro gestiona los servicios mediante **perfiles (`profiles`)**:

| Perfil | Servicios Incluidos | RAM Máxima | Caso de Uso |
| :--- | :--- | :---: | :--- |
| **`core`** *(Default)* | SQL Server 2022 + Keycloak 26 + Postgres DB | ~3.5 GB | Desarrollo diario de Backend y Frontend. |
| **`observability`** | OpenTelemetry Collector + Prometheus + Grafana | ~1.0 GB | Monitoreo de trazas OTLP, logs JSONL y métricas. |
| **`azure`** | Azurite (Emulación de Storage Blobs/Queues) | ~512 MB | Pruebas de almacenamiento offline. |
| **`proxy`** | Traefik v3 con Hardened Headers | ~128 MB | Terminación de cabeceras de seguridad y proxy. |
| **`full`** | Todos los 8 contenedores simultáneos | ~5.2 GB | Pruebas de integración total antes de release. |

---

## 4. Comandos Rápidos del Flujo de Desarrollo

Todos los comandos se ejecutan desde PowerShell:

```powershell
# 1. Iniciar entorno de desarrollo local (Perfil core por defecto: BD + IAM + Apps)
cd AsistenciasUCO-Infra\scripts\orchestration
.\start-dev.ps1

# 2. Levantar solo los contenedores de BD e IAM (sin lanzar Backend ni Frontend en host)
.\start-dev.ps1 -ContainersOnly

# 3. Levantar con suite completa de observabilidad
.\start-dev.ps1 -Profile observability

# 4. Diagnosticar estado de contenedores, puertos y endpoints HTTP
.\status-dev.ps1

# 5. Detener limpiamente aplicaciones (8080, 4200) y apagar contenedores
.\stop-dev.ps1

# 6. Detener aplicaciones pero mantener contenedores activos en background
.\stop-dev.ps1 -KeepContainers
```

---

## 5. Quality Gates y Seguridad DevSecOps

```powershell
# Verificar integridad criptográfica de contratos WORM (OpenAPI, DB, SSE)
cd AsistenciasUCO-Infra\scripts
.\quality\verify-contracts.ps1

# Escanear código buscando credenciales quemadas o archivos .env expuestos
.\security\check-secrets.ps1

# Ejecutar suite de pruebas de Backend (Java 25)
.\quality\test-backend.ps1 -Profile Unit
.\quality\test-backend.ps1 -Profile Integration

# Ejecutar suite de pruebas E2E de Historias de Usuario (HU001 a HU174)
.\quality\test-e2e-hus.ps1 -Module All
```

---

## 6. Enlaces a la Documentación Normativa

* **Constitución Técnica Suprema:** [`docs/governance/CONSTITUTION.md`](docs/governance/CONSTITUTION.md)
* **Fuentes de Verdad (SSOT):** [`docs/governance/SOURCE_OF_TRUTH.md`](docs/governance/SOURCE_OF_TRUTH.md)
* **Reglas de Diseño de API:** [`docs/governance/API_DESIGN_RULES.md`](docs/governance/API_DESIGN_RULES.md)
* **Definition of Ready (DoR):** [`docs/governance/DEFINITION_OF_READY.md`](docs/governance/DEFINITION_OF_READY.md)
* **Definition of Done (DoD):** [`docs/governance/DEFINITION_OF_DONE.md`](docs/governance/DEFINITION_OF_DONE.md)
* **Guía de Hardening y Mínimo Privilegio:** [`docs/hardening/SECURITY_AND_HARDENING.md`](docs/hardening/SECURITY_AND_HARDENING.md)
* **Runbook de Puesta en Marcha:** [`docs/runbooks/LOCAL_ENVIRONMENT_SETUP.md`](docs/runbooks/LOCAL_ENVIRONMENT_SETUP.md)
* **Guía de Migración y Rollback:** [`docs/runbooks/MIGRATION_GUIDE.md`](docs/runbooks/MIGRATION_GUIDE.md)
* **Catálogo de Deuda Técnica:** [`docs/baseline/TECHNICAL_DEBT.md`](docs/baseline/TECHNICAL_DEBT.md)
