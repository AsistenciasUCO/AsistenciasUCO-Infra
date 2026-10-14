---
status: active
type: normative
scope: transversal-all-layers
owner: architecture-and-devops-team
last-reviewed: 2026-10-13
---

# 📈 Línea Base Técnica Activa y Evolución de Fases

Este documento define la secuencia normativa activa, el estado de las fases del ecosistema y la línea base transversal que articula Base de Datos, Backend, Frontend e Infraestructura.

---

## 1. Estado Consolidado de Fases del Ecosistema

| Fase | Ámbito y Alcance | Estado | Evidencia y Cierre |
| :---: | :--- | :---: | :--- |
| **LB-000** | Gobernanza unificada, SDD y documentación técnica | **CLOSED** | Gobernanza transversal ratificada en `CONSTITUTION.md`. |
| **LB-001** | Golden Path + Contract-First OpenAPI y DDL | **CLOSED / FROZEN** | Contratos congelados bajo WORM con firmas `.sha256` adyacentes. |
| **LB-001D** | Hardening de Gobernanza e Integración Cloud | **CLOSED / FROZEN** | Paridad de catálogos y aislamiento en Azure App Config / Key Vault. |
| **LB-002** | Migración progresiva JDBC Legacy $\to$ Spring Data JPA | **CLOSED / FROZEN** | Piloto de persistencia JPA operativo con fallback JDBC preservado. |
| **LB-003** | Quality Gates del Golden Path | **CLOSED / PASS** | 1426 pruebas unitarias, ArchUnit 85/85, JaCoCo LINE 91.5% / BRANCH 81.2%. |
| **INFRA-01** | Infraestructura Centralizada, Hardening y Orquestación | **IN_PROGRESS (Bloque 3)** | Suite de contenedores por perfiles (`core`, `full`), Least Privilege y 21 scripts PS. |
| **LB-004** | Preparación Stateless / Serverless | **NEXT_PHASE / NOT_STARTED** | Desacoplamiento de almacenamiento efímero local (`TD-004`). |
| **LB-005** | Realtime SSE Distribuido | NOT_STARTED | Extensión de eventos multi-instancia (`TD-003`, `TD-011`). |
| **LB-006** | Integración Continua CD / Cloud IaC | NOT_STARTED | Automatización de infraestructura con Terraform / Bicep (`TD-022`, `TD-027`). |
| **LB-007** | Replicación del Patrón a Verticales Restantes | NOT_STARTED | Expansión del Golden Path a todos los módulos funcionales. |

---

## 2. Flujo del Golden Path de Asistencia

```text
POST /api/v1/asistencias/lote
  └─► AsistenciaController (Primary Adapter)
        └─► RegistrarAsistenciasSesionInputPort / UseCase (Application)
              ├─► AsistenciaRepositoryPort (Secondary Port)
              │     └─► AsistenciaRepositoryHybridSqlServerAdapter (Persistence Adapter)
              │           ├─► Comando JPA: app_asistencias_user vía EXEC usp_registrar_asistencias_sesion
              │           └─► Fallback JDBC: Disponible ante contingencia
              └─► RealtimePublisherPort (Secondary Port)
                    └─► LocalSseRealtimeStreamGateway (Realtime Adapter)
                          └─► Server-Sent Events (SSE) hacia Angular SPA (/api/v1/realtime/stream)

GET /api/v1/grupos/{grupoId}/asistencias
  └─► AsistenciaController
        └─► AsistenciaRepositoryPort
              └─► SELECT sobre uv_asistencia / uv_detalle_asistencia (JPA en local/dev)
```

---

## 3. Providers AS-IS y Modos de Ejecución

| Perfil / Entorno | Base de Datos (Persistencia) | Identidad (IAM) | Realtime | Observabilidad |
| :--- | :--- | :--- | :--- | :--- |
| **`core` (Local Dev)** | SQL Server 2022 en Docker (`127.0.0.1:1433`) | Keycloak 26 en Docker (`127.0.0.1:8081`) | Local SSE en memoria | Logs locales JSONL |
| **`observability`** | SQL Server 2022 | Keycloak 26 | Local SSE | OTel Collector + Prometheus + Grafana |
| **`proxy`** | SQL Server 2022 | Keycloak 26 | Local SSE | Traefik Reverse Proxy con Hardened Headers |
| **`azure`** | SQL Server 2022 | Keycloak 26 | Local SSE | Azurite (Blobs, Queues, Tables) |
| **`full`** | SQL Server 2022 | Keycloak 26 | Local SSE | Suite completa levantada |

---

## 4. Gobernanza y Deuda Técnica

El inventario de deudas técnicas del sistema se encuentra auditado y preservado en [`TECHNICAL_DEBT.md`](TECHNICAL_DEBT.md) (registros **TD-001 a TD-054**).
Ninguna fase técnica se inicia automáticamente sin la aprobación de su correspondiente **Definition of Ready** y su plan de trabajo formal.
