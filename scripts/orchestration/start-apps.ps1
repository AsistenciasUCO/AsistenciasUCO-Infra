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
    [switch]$SkipFrontend
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

$backendDir  = Join-Path $repoRoot "GestioAsistenciaBackend"
$frontendDir = Join-Path $repoRoot "GestioAsistenciaFrontend"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - INICIO DE APLICACIONES LOCALES" -ForegroundColor Cyan
Write-Host "Backend  : $backendDir (Puerto 8080)" -ForegroundColor Gray
Write-Host "Frontend : $frontendDir (Puerto 4200)" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# Función para verificar si un puerto TCP está ocupado
function Test-PortInUse {
    param([int]$Port)
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return ($null -ne $conns -and $conns.Count -gt 0)
}

# 1. Iniciar Backend (Spring Boot en 8080)
if (-not $SkipBackend) {
    Write-Host "`n[1/2] Verificando Backend en puerto 8080..." -ForegroundColor Yellow
    if (Test-PortInUse -Port 8080) {
        Write-Host "  -> El puerto 8080 ya tiene un proceso escuchando. Omitiendo arranque de Backend." -ForegroundColor DarkYellow
    } else {
        $mvnwCmd = Join-Path $backendDir "mvnw.cmd"
        if (-not (Test-Path $mvnwCmd)) {
            Write-Host "  -> ERROR: No se encontró mvnw.cmd en $backendDir" -ForegroundColor Red
        } else {
            Write-Host "  -> Lanzando Spring Boot en nueva consola de PowerShell..." -ForegroundColor Green
            $backendCommand = "Set-Location '$backendDir'; .\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=dev"
            Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $backendCommand -WorkingDirectory $backendDir
        }
    }
}

# 2. Iniciar Frontend (Angular en 4200)
if (-not $SkipFrontend) {
    Write-Host "`n[2/2] Verificando Frontend en puerto 4200..." -ForegroundColor Yellow
    if (Test-PortInUse -Port 4200) {
        Write-Host "  -> El puerto 4200 ya tiene un proceso escuchando. Omitiendo arranque de Frontend." -ForegroundColor DarkYellow
    } else {
        $packageJson = Join-Path $frontendDir "package.json"
        if (-not (Test-Path $packageJson)) {
            Write-Host "  -> ERROR: No se encontró package.json en $frontendDir" -ForegroundColor Red
        } else {
            Write-Host "  -> Lanzando Angular SPA (npm start) en nueva consola de PowerShell..." -ForegroundColor Green
            $frontendCommand = "Set-Location '$frontendDir'; npm start"
            Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $frontendCommand -WorkingDirectory $frontendDir
        }
    }
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host "✅ Aplicaciones lanzadas exitosamente." -ForegroundColor Green
Write-Host "  • Backend API  : http://localhost:8080/swagger-ui.html" -ForegroundColor Cyan
Write-Host "  • Frontend Web : http://localhost:4200" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Green
