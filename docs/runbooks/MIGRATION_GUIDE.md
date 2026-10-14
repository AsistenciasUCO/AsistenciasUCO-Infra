---
status: active
type: runbook
scope: developer-workflow-and-migration
owner: architecture-and-devops-team
last-reviewed: 2026-10-13
---

# 🔄 Guía de Migración y Transición hacia AsistenciasUCO-Infra

Este manual establece la correspondencia exacta entre los scripts y comandos heredados (*legacy*) y las nuevas utilidades centralizadas en la 4ª capa (**`AsistenciasUCO-Infra`**), junto con el procedimiento oficial de Rollback.

---

## 1. Tabla Maestra de Equivalencia de Comandos

| Operación / Flujo | Comando Heredado (Legacy) | Nuevo Comando Centralizado (`AsistenciasUCO-Infra`) | Perfil / Comportamiento |
| :--- | :--- | :--- | :---: |
| **Arranque Completo (Dev)** | `.\scripts\iniciar-todo.ps1` | `.\AsistenciasUCO-Infra\scripts\orchestration\start-dev.ps1` | `core` (Por defecto: SQL Server + Keycloak + Apps) |
| **Arranque con Observabilidad** | `.\scripts\start-dev.ps1 -Full` | `.\AsistenciasUCO-Infra\scripts\orchestration\start-dev.ps1 -Profile full` | `full` (Incluye OTel, Prometheus, Grafana, Traefik) |
| **Arranque Solo Contenedores** | N/A (Antes levantaba todo) | `.\AsistenciasUCO-Infra\scripts\orchestration\start-dev.ps1 -ContainersOnly` | `core` (Solo contenedores, sin lanzar Java ni Node) |
| **Detener Todo** | `.\scripts\detener-todo.ps1` | `.\AsistenciasUCO-Infra\scripts\orchestration\stop-dev.ps1` | Mata puertos `8080`, `4200` y apaga contenedores |
| **Detener Solo Aplicaciones** | N/A | `.\AsistenciasUCO-Infra\scripts\orchestration\stop-dev.ps1 -KeepContainers` | Mata puertos `8080`, `4200`, mantiene BD y Keycloak |
| **Diagnóstico del Entorno** | N/A (Scripts ad-hoc) | `.\AsistenciasUCO-Infra\scripts\orchestration\status-dev.ps1` | Diagnóstico visual de contenedores, puertos y URLs |
| **Compilar Esquema BD** | `.\GestioAsistenciaDB\deploy_schema.ps1` | `.\AsistenciasUCO-Infra\components\sqlserver\scripts\deploy-schema.ps1` | Compilación con resolución de dependencias + Hardening |
| **Sembrado Canónico BD** | `.\scripts\restablecer-datos-limpios.ps1` | `.\AsistenciasUCO-Infra\components\sqlserver\scripts\seed-clean-data.ps1` | 11 usuarios canónicos + recálculo de aforos |
| **Test Suite T-SQL** | `.\GestioAsistenciaDB\test_summary.ps1` | `.\AsistenciasUCO-Infra\components\sqlserver\scripts\test-summary.ps1` | Valida 8 aserciones maestras y cobertura de SPs/Vistas |
| **Bootstrap Keycloak** | `.\GestioAsistenciaBackend\infra\keycloak\scripts\bootstrap-keycloak.ps1` | `.\AsistenciasUCO-Infra\components\keycloak\scripts\bootstrap.ps1` | Idempotente: reconcilia realm, clientes y roles |
| **Sembrar Usuarios IAM** | `.\GestioAsistenciaBackend\infra\keycloak\scripts\seed-users.ps1` | `.\AsistenciasUCO-Infra\components\keycloak\scripts\seed-users.ps1` | Mapeo de `idUsuario` exacto con `dbo.Usuario.id` |
| **Obtener Token JWT** | `.\GestioAsistenciaBackend\infra\keycloak\scripts\get-test-token.ps1` | `.\AsistenciasUCO-Infra\components\keycloak\scripts\get-token.ps1` | Emite y decodifica claims del token |
| **Diagnosticar Token JWT** | `.\GestioAsistenciaBackend\infra\keycloak\scripts\diagnose-idusuario-claim.ps1` | `.\AsistenciasUCO-Infra\components\keycloak\scripts\diagnose-token.ps1` | Valida consistencia de `idUsuario` en BD, Token y UserInfo |
| **Sincronizar Azure AppConfig**| `.\scripts\azure\sync-appconfig-catalog.ps1` | `.\AsistenciasUCO-Infra\scripts\cloud-sync\sync-appconfig.ps1` | Elimina llaves `0,1,2` y sincroniza con UTF-8 exacto |
| **Exportar Catálogos JSON** | `.\scripts\azure\export_json_utf8.ps1` | `.\AsistenciasUCO-Infra\scripts\cloud-sync\export-catalogs.ps1` | Genera JSON limpios desde los seeds SQL |
| **Verificar Contratos WORM** | `.\GestioAsistenciaDB\scripts\freeze-manifest.ps1` | `.\AsistenciasUCO-Infra\scripts\quality\verify-contracts.ps1` | Valida OpenAPI, Backend, DB y SSE con normalización SHA-256 |
| **Escaneo de Secretos** | `.\GestioAsistenciaDB\scripts\secret-hygiene.ps1` | `.\AsistenciasUCO-Infra\scripts\security\check-secrets.ps1` | Escaneo estático en todo el ecosistema (DevSecOps) |
| **Pruebas de Backend** | `.\GestioAsistenciaBackend\mvnw.cmd test` | `.\AsistenciasUCO-Infra\scripts\quality\test-backend.ps1` | Soporta `-Profile Unit`, `Integration`, `Verify` |
| **Pruebas E2E de HUs** | `.\scripts\general\tests\test_all_hus.ps1` | `.\AsistenciasUCO-Infra\scripts\quality\test-e2e-hus.ps1` | Soporta `-Module <Rol>` y `-HU <código>` |

---

## 2. Fase de Transición y Coexistencia (Fase 1 y 2)

Durante la transición activa:
1. **No se eliminan ni modifican archivos en los módulos originales:** Los scripts en `scripts/`, `GestioAsistenciaBackend/`, `GestioAsistenciaDB/` y `GestioAsistenciaFrontend/` se preservan intactos para garantizar la estabilidad de cualquier flujo local existente.
2. **Uso Recomendado:** Se recomienda a todo el equipo comenzar a invocar las utilidades desde `AsistenciasUCO-Infra/` para disfrutar del ahorro de memoria por perfiles (`core` vs `full`) y de la validación automática de contratos.
3. **Deprecación y Wrappers (Fase 3):** Una vez concluida y aprobada la Fase 2, los scripts en la raíz y en los módulos serán reemplazados por *wrappers* delgados de una sola línea que redirigirán automáticamente hacia `AsistenciasUCO-Infra/`.

---

## 3. Procedimiento de Rollback (Plan de Contingencia)

Si durante el uso de los nuevos scripts centralizados se experimenta algún comportamiento inesperado o bloqueo del entorno local, sigue este procedimiento de Rollback:

1. **Detener Contenedores de Infraestructura:**
   ```powershell
   cd AsistenciasUCO-Infra\scripts\orchestration
   .\stop-dev.ps1
   ```
2. **Levantar Entorno Anterior:**
   ```powershell
   cd ..\..\scripts
   .\iniciar-todo.ps1
   ```
   *Nota:* Dado que los scripts y esquemas originales nunca fueron alterados ni eliminados, el flujo legacy continuará funcionando exactamente igual que antes.
3. **Reportar la Incidencia:** Registra el hallazgo en el work item activo especificando el comando ejecutado y la salida del error para su corrección sin afectar la productividad del equipo.
