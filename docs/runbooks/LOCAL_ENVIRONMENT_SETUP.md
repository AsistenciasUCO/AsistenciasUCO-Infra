---
status: active
type: runbook
scope: developer-workflow
owner: devops-team
last-reviewed: 2026-10-13
---

# 🚀 Runbook: Puesta en Marcha del Entorno Local (Local Setup)

Este manual operativo guía paso a paso a los desarrolladores y agentes de IA para configurar, levantar, diagnosticar y detener el entorno local completo de **Asistencias UCO** utilizando la infraestructura centralizada en `AsistenciasUCO-Infra`.

---

## 1. Requisitos Previos

Antes de iniciar, asegúrate de contar con las siguientes herramientas en tu estación de trabajo (Windows 10/11 o WSL2):
* **Docker Desktop:** Versión 4.30+ con soporte para Docker Compose v2.
* **PowerShell:** Windows PowerShell 5.1 o PowerShell Core 7.x.
* **Java Development Kit (JDK):** Versión 25 (o 21+ con soporte de compilación Java 25).
* **Node.js y npm:** Node.js v20 LTS o v22 y npm 10+.
* **Git:** Para control de versiones y hooks.
* *(Opcional)* **Azure CLI (`az`):** Requerido únicamente si sincronizas catálogos con la nube de Azure.

---

## 2. Configuración Inicial (Un Solo Paso)

1. Abre una consola de PowerShell en la raíz del proyecto o en `AsistenciasUCO-Infra/`.
2. Si no tienes un archivo `.env` configurado, copia el archivo canónico:
   ```powershell
   Copy-Item .\AsistenciasUCO-Infra\.env.example .\AsistenciasUCO-Infra\.env
   ```
   *Nota:* Los orquestadores de `AsistenciasUCO-Infra` cargan automáticamente `.env.example` como respaldo si `.env` no existe.

---

## 3. Inicio del Entorno de Desarrollo

### 3.1 Modo Rápido por Defecto (Perfil `core`)
El perfil `core` levanta **exclusivamente** los servicios imprescindibles (SQL Server 2022 y Keycloak 26) para consumir menos de 3.5 GB de RAM:

```powershell
cd AsistenciasUCO-Infra\scripts\orchestration
.\start-dev.ps1
```

**¿Qué hace este comando automáticamente?**
1. Carga las variables de entorno con `load-env.ps1`.
2. Levanta los contenedores `sql_server_asistencias` y `keycloak_asistencias`.
3. Espera activamente los `healthcheck` reales de SQL Server y Keycloak.
4. Compila y despliega el esquema DDL relacional (`deploy-schema.ps1`) y aplica el hardening de mínimo privilegio.
5. Siembra los 11 usuarios institucionales canónicos y grupos de prueba (`seed-clean-data.ps1`).
6. Reconcilia el realm de Keycloak e importa los usuarios con claim `idUsuario` (`bootstrap.ps1` y `seed-users.ps1`).
7. Lanza **Spring Boot Backend** (`http://localhost:8080`) y **Angular Frontend** (`http://localhost:4200`) en consolas independientes.

---

### 3.2 Modos Avanzados y Perfiles Bajo Demanda

Puedes personalizar el arranque mediante parámetros:

```powershell
# Levantar únicamente los contenedores (sin lanzar Backend ni Frontend en el host)
.\start-dev.ps1 -ContainersOnly

# Levantar con la suite de Observabilidad (OpenTelemetry + Prometheus + Grafana)
.\start-dev.ps1 -Profile observability

# Levantar con emulación de Azure Storage (Azurite offline)
.\start-dev.ps1 -Profile azure

# Levantar con Traefik Reverse Proxy y cabeceras de seguridad
.\start-dev.ps1 -Profile proxy

# Levantar el entorno COMPLETO (todos los contenedores simultáneos)
.\start-dev.ps1 -Profile full

# Omitir el sembrado de base de datos para preservar datos existentes
.\start-dev.ps1 -SkipSeed
```

---

## 4. Diagnóstico y Monitoreo del Estado

Para comprobar en cualquier momento la salud de los contenedores, puertos TCP y endpoints HTTP:

```powershell
.\status-dev.ps1
```

**Salida de Diagnóstico:**
* Estado de salud de contenedores (`healthy`, `running`, `exited`).
* Estado de puertos de red (`1433` DB, `8081` Keycloak, `8080` API, `4200` UI, `9090` Prometheus, `3000` Grafana).
* Respuesta HTTP de `Backend Actuator Health` y `Keycloak Health`.

---

## 5. Ejecución de Quality Gates y Pruebas

Desde `AsistenciasUCO-Infra/scripts/`:

```powershell
# 1. Verificar integridad de contratos WORM (OpenAPI, DB Baseline, SSE Events)
.\quality\verify-contracts.ps1

# 2. Escanear fugas de secretos o credenciales expuestas (DevSecOps)
.\security\check-secrets.ps1

# 3. Ejecutar pruebas de Backend (Unitarias o de Integración)
.\quality\test-backend.ps1 -Profile Unit
.\quality\test-backend.ps1 -Profile Integration

# 4. Ejecutar suite E2E de Historias de Usuario (HU001 a HU174)
.\quality\test-e2e-hus.ps1 -Module All
```

---

## 6. Detención Limpia del Entorno

Para liberar los puertos `8080` y `4200` y apagar todos los contenedores Docker:

```powershell
.\stop-dev.ps1
```

Si deseas detener la API y el Frontend pero **mantener los contenedores activos** en segundo plano (para no reiniciar SQL Server o Keycloak):
```powershell
.\stop-dev.ps1 -KeepContainers
```
