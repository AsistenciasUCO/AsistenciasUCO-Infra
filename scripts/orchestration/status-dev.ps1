<#
.SYNOPSIS
    Diagnóstico visual del estado de contenedores, puertos y servicios del ecosistema.

.DESCRIPTION
    Examina de forma no invasiva:
      1. Estado y healthcheck de los contenedores Docker del proyecto.
      2. Estado de escucha en puertos locales TCP clave (1433, 8081, 9001, 8080, 4200, 9090, 3000).
      3. Verificación de respuesta HTTP rápida contra los endpoints principales.

.EXAMPLE
    .\status-dev.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$infraDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$composeFile = Join-Path $infraDir "docker-compose.yml"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - ESTADO Y DIAGNÓSTICO DEL ECOSISTEMA LOCAL" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# 1. Diagnóstico de Contenedores Docker
Write-Host "`n1. ESTADO DE CONTENEDORES DOCKER" -ForegroundColor Yellow
try {
    $psOut = docker compose -f "$composeFile" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>&1
    if ($LASTEXITCODE -eq 0 -and $psOut) {
        $psOut | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "  -> No hay contenedores registrados o Docker no responde." -ForegroundColor DarkYellow
    }
} catch {
    Write-Host "  -> Error al consultar Docker: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Diagnóstico de Puertos TCP Locales
Write-Host "`n2. PUERTOS TCP LOCALES (127.0.0.1)" -ForegroundColor Yellow

$trackedPorts = @(
    @{ Port = 1433; Service = "SQL Server 2022" },
    @{ Port = 8081; Service = "Keycloak IAM (HTTP)" },
    @{ Port = 9001; Service = "Keycloak Management / Health" },
    @{ Port = 8080; Service = "Backend API REST (Spring Boot)" },
    @{ Port = 4200; Service = "Frontend SPA (Angular)" },
    @{ Port = 9090; Service = "Prometheus (Observabilidad)" },
    @{ Port = 3000; Service = "Grafana Dashboards" },
    @{ Port = 10000; Service = "Azurite (Azure Blob Emulation)" }
)

$portReport = @()
foreach ($p in $trackedPorts) {
    $conns = Get-NetTCPConnection -LocalPort $p.Port -State Listen -ErrorAction SilentlyContinue
    $status = if ($conns) { "LISTENING" } else { "CLOSED" }
    $pidInfo = if ($conns) { ($conns.OwningProcess | Select-Object -Unique) -join ', ' } else { "-" }

    $portReport += [PSCustomObject]@{
        Puerto   = $p.Port
        Servicio = $p.Service
        Estado   = $status
        PID      = $pidInfo
    }
}

$portReport | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# 3. Smoke Test Rápido de Endpoints HTTP
Write-Host "3. VERIFICACIÓN DE ENDPOINTS HTTP CLAVE" -ForegroundColor Yellow

function Test-HttpEndpoint {
    param([string]$Url, [string]$Name)
    try {
        $resp = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        Write-Host "  [ONLINE] $Name ($Url) -> $($resp.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "  [OFFLINE] $Name ($Url)" -ForegroundColor DarkGray
    }
}

Test-HttpEndpoint -Url "http://localhost:8080/actuator/health" -Name "Backend Actuator Health"
Test-HttpEndpoint -Url "http://localhost:8080/swagger-ui.html" -Name "Swagger OpenAPI Docs"
Test-HttpEndpoint -Url "http://localhost:8081/realms/asistencias-uco/.well-known/openid-configuration" -Name "Keycloak OIDC Discovery"
Test-HttpEndpoint -Url "http://localhost:4200" -Name "Frontend Web SPA"

Write-Host "`n==============================================================================" -ForegroundColor Cyan
Write-Host "Diagnóstico finalizado." -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
