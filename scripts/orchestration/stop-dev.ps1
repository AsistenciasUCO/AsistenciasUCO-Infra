<#
.SYNOPSIS
    Detiene de forma limpia los procesos de aplicación y los contenedores de desarrollo.

.DESCRIPTION
    1. Localiza y termina de forma segura los procesos que ocupan los puertos 8080 (Backend)
       y 4200 (Frontend) mediante Stop-Process.
    2. Detiene todos los contenedores gestionados por AsistenciasUCO-Infra (docker compose down).

.PARAMETER KeepContainers
    Detener únicamente Backend y Frontend, manteniendo los contenedores (BD y Keycloak) activos.

.EXAMPLE
    .\stop-dev.ps1
    .\stop-dev.ps1 -KeepContainers
#>

[CmdletBinding()]
param(
    [switch]$KeepContainers
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$infraDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$composeFile = Join-Path $infraDir "docker-compose.yml"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " ASISTENCIAS UCO - DETENCION DE SERVICIOS Y CONTENEDORES" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

function Stop-PortProcess {
    param(
        [int]$Port,
        [string]$ServiceName
    )
    Write-Host "`nVerificando procesos en puerto $Port ($ServiceName)..." -ForegroundColor Yellow
    try {
        $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($null -ne $conns -and $conns.Count -gt 0) {
            foreach ($conn in $conns) {
                $pidToKill = $conn.OwningProcess
                if ($pidToKill -gt 0) {
                    Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue
                    Write-Host "  -> [OK] Proceso $ServiceName (PID: $pidToKill) detenido." -ForegroundColor Green
                }
            }
        } else {
            Write-Host "  -> No hay procesos escuchando en el puerto $Port." -ForegroundColor Gray
        }
    } catch {
        Write-Host "  -> Aviso al verificar puerto ${Port}: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# 1. Detener Backend (8080) y Frontend (4200)
Stop-PortProcess -Port 8080 -ServiceName "Backend API"
Stop-PortProcess -Port 4200 -ServiceName "Frontend SPA"

# 2. Detener Contenedores Docker
if (-not $KeepContainers) {
    Write-Host "`nDeteniendo contenedores Docker de infraestructura..." -ForegroundColor Yellow
    try {
        docker compose -f "$composeFile" --profile full down
        # Detener contenedores de almacenamiento y antivirus si existen
        $storageContainers = @("asistencias-files-minio-1", "asistencias-files-clamav-1", "minio_asistencias", "clamav_asistencias")
        foreach ($sc in $storageContainers) {
            $st = docker ps -q --filter "name=^/${sc}$" 2>$null
            if ($st) {
                docker stop $sc > $null 2>&1
            }
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  -> [OK] Contenedores detenidos y redes liberadas." -ForegroundColor Green
        } else {
            Write-Host "  -> Aviso en docker compose down." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  -> Error al invocar docker compose: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n[AVISO] Contenedores Docker preservados (-KeepContainers activo)." -ForegroundColor DarkYellow
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host " [OK] Servicios detenidos correctamente." -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
