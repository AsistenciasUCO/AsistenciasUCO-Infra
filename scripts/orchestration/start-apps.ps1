<#
.SYNOPSIS
    Lanzador de aplicaciones web de desarrollo (Backend Spring Boot y Frontend Angular).

.DESCRIPTION
    Verifica primero si los puertos 8080 (API) y 4200 (SPA) ya están ocupados. Si están libres,
    inicia en consolas de PowerShell independientes el Backend (usando mvnw.cmd) y el
    Frontend (usando npm start).

.PARAMETER SkipBackend
    Omitir el inicio de la API Backend.

.PARAMETER SkipFrontend
    Omitir el inicio de la SPA Frontend.

.EXAMPLE
    .\start-apps.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipBackend,
    [switch]$SkipFrontend,
    [switch]$Restart,
    [switch]$Fast = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

$backendDir  = Join-Path $repoRoot "GestioAsistenciaBackend"
$frontendDir = Join-Path $repoRoot "GestioAsistenciaFrontend"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "[INFO] ASISTENCIAS UCO - ORQUESTACION DE APLICACIONES LOCALES" -ForegroundColor Cyan
Write-Host "Backend  : $backendDir (Puerto 8080)" -ForegroundColor Gray
Write-Host "Frontend : $frontendDir (Puerto 4200)" -ForegroundColor Gray
Write-Host "Modo     : $(if ($Restart) { 'REINICIO FORZADO' } else { 'INICIO ESTANDAR' }) | Arranque Rápido: $(if ($Fast) { 'ACTIVO (-Dmaven.test.skip=true)' } else { 'INACTIVO' })" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# Función para verificar si un puerto TCP está ocupado
function Test-PortInUse {
    param([int]$Port)
    $conns = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    return ($conns.Count -gt 0)
}

# Función para matar proceso de un puerto de forma segura (árbol completo)
function Stop-PortProcess {
    param([int]$Port, [string]$Name)
    $conns = @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($conns -and $conns.Count -gt 0) {
        $pids = $conns.OwningProcess | Where-Object { $_ -gt 0 } | Select-Object -Unique
        foreach ($procId in $pids) {
            Write-Host "  -> Deteniendo proceso previo de $Name (PID: $procId)..." -ForegroundColor Yellow
            Start-Process "taskkill" -ArgumentList "/F", "/T", "/PID", $procId -NoNewWindow -Wait -ErrorAction SilentlyContinue 2>$null
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        }
        for ($i = 0; $i -lt 6; $i++) {
            $rem = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
            if ($rem.Count -eq 0) { break }
            Start-Sleep -Milliseconds 500
        }
    }
}

# 1. Iniciar Backend (Spring Boot en 8080)
if (-not $SkipBackend) {
    Write-Host "`n[1/2] Verificando Backend en puerto 8080..." -ForegroundColor Yellow
    if ($Restart) {
        Stop-PortProcess -Port 8080 -Name "Backend"
    }

    if (Test-PortInUse -Port 8080) {
        Write-Host "  -> El puerto 8080 ya tiene un proceso escuchando. (Usa -Restart para reiniciarlo)." -ForegroundColor DarkYellow
    } else {
        $backendScript = Join-Path $repoRoot "scripts\backend\run-local.ps1"
        if (-not (Test-Path $backendScript)) {
            Write-Host "  -> ERROR: No se encontró run-local.ps1 en scripts\backend" -ForegroundColor Red
        } else {
            Write-Host "  -> Lanzando Spring Boot en nueva consola de PowerShell..." -ForegroundColor Green
            Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $backendScript -WorkingDirectory $backendDir
        }
    }
}

# 2. Iniciar Frontend (Angular en 4200)
if (-not $SkipFrontend) {
    Write-Host "`n[2/2] Verificando Frontend en puerto 4200..." -ForegroundColor Yellow
    if ($Restart) {
        Stop-PortProcess -Port 4200 -Name "Frontend"
    }

    if (Test-PortInUse -Port 4200) {
        Write-Host "  -> El puerto 4200 ya tiene un proceso escuchando. (Usa -Restart para reiniciarlo)." -ForegroundColor DarkYellow
    } else {
        $frontendScript = Join-Path $repoRoot "scripts\frontend\run-local.ps1"
        if (-not (Test-Path $frontendScript)) {
            Write-Host "  -> ERROR: No se encontró run-local.ps1 en scripts\frontend" -ForegroundColor Red
        } else {
            Write-Host "  -> Lanzando Angular SPA en nueva consola de PowerShell..." -ForegroundColor Green
            Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $frontendScript -WorkingDirectory $frontendDir
        }
    }
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host "[OK] Proceso de arranque completado." -ForegroundColor Green
Write-Host "  * Backend API  : http://localhost:8080/swagger-ui.html" -ForegroundColor Cyan
Write-Host "  * Frontend Web : http://localhost:4200" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Green
