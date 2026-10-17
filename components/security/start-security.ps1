<#
.SYNOPSIS
    Orquestador de arranque para la Plataforma de Seguridad y Autorización Fina (PDP/PEP/SurrealDB/Redis/OPA).

.DESCRIPTION
    Inicia los contenedores definidos en Complementos/Seguridad/security-baseline-local/compose.yaml
    y opcionalmente la consola web de administración (Security UI en Vue 3).
    Garantiza que las variables de entorno estén cargadas y comprueba la disponibilidad de los endpoints.

.PARAMETER WithUi
    Inicia la interfaz de usuario Security UI (Vue 3 / Vite) en una ventana de consola independiente.

.PARAMETER Down
    Detiene los contenedores de la plataforma de seguridad.

.EXAMPLE
    .\start-security.ps1
    .\start-security.ps1 -WithUi
    .\start-security.ps1 -Down
#>

[CmdletBinding()]
param(
    [switch]$WithUi,
    [switch]$Down
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$infraRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

$securityDir = Join-Path $repoRoot "Complementos\Seguridad"
$securityLocalDir = Join-Path $securityDir "security-baseline-local"
$securityComposeFile = Join-Path $securityLocalDir "compose.yaml"
$securityEnvFile = Join-Path $securityLocalDir ".env"
$securityUiDir = Join-Path $securityDir "security-ui"
if (-not (Test-Path $securityUiDir)) {
    $securityUiDir = Join-Path $securityDir "securityBaseline-vue"
}

if (-not (Test-Path $securityComposeFile)) {
    throw "No se encontró el archivo compose.yaml de seguridad en: $securityComposeFile"
}

# 1. Modo Detención
if ($Down) {
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host " ASISTENCIAS UCO - DETENCION DE PLATAFORMA DE SEGURIDAD" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "`nDeteniendo contenedores de seguridad (PDP, PEP, SurrealDB, Redis, OPA)..." -ForegroundColor Yellow
    try {
        docker compose -f "$securityComposeFile" --env-file "$securityEnvFile" down
        Write-Host "  -> [OK] Contenedores de seguridad detenidos." -ForegroundColor Green
    } catch {
        Write-Host "  -> Aviso al detener contenedores: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
    exit 0
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " ASISTENCIAS UCO - INICIO DE PLATAFORMA DE SEGURIDAD (PDP / PEP)" -ForegroundColor Cyan
Write-Host " Directorio : $securityLocalDir" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# 2. Cargar variables de entorno del componente de seguridad
if (Test-Path $securityEnvFile) {
    Get-Content $securityEnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split('=', 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim()
            [System.Environment]::SetEnvironmentVariable($k, $v, [System.EnvironmentVariableTarget]::Process)
        }
    }
}

# 3. Comprobar Docker Engine
try {
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Desktop no está activo. Inícialo antes de continuar."
    }
} catch {
    throw "Docker no responde. Verifica que el servicio esté en ejecución."
}

# 4. Levantar servicios con Docker Compose
Write-Host "`n[1/2] Levantando servicios de seguridad..." -ForegroundColor Yellow
docker compose -f "$securityComposeFile" --env-file "$securityEnvFile" up -d
if ($LASTEXITCODE -ne 0) {
    throw "Error al levantar la plataforma de seguridad con Docker Compose."
}

# 5. Esperar disponibilidad de PDP y PEP
Write-Host "  -> Esperando inicialización de servicios..." -ForegroundColor Gray
Start-Sleep -Seconds 3

$pdpPort = if ($env:PDP_PORT) { $env:PDP_PORT } else { "18080" }
$pepPort = if ($env:PEP_PORT) { $env:PEP_PORT } else { "18081" }

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host " [OK] PLATAFORMA DE SEGURIDAD INICIADA EXITOSAMENTE" -ForegroundColor Green
Write-Host "  * PDP Engine (Spring Boot) : http://127.0.0.1:$pdpPort" -ForegroundColor Cyan
Write-Host "  * PEP Gateway Proxy       : http://127.0.0.1:$pepPort" -ForegroundColor Cyan
Write-Host "  * SurrealDB Engine        : 127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "  * Redis Cache             : 127.0.0.1:6379" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Green

# 6. Lanzar Security UI en consola independiente si se solicitó
if ($WithUi) {
    if (Test-Path $securityUiDir) {
        Write-Host "`nLanzando Security UI (Vue 3) en nueva ventana..." -ForegroundColor Yellow
        $uiCmd = "Set-Location '$securityUiDir'; npm run dev"
        Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $uiCmd -WorkingDirectory $securityUiDir
        Write-Host "  -> Security UI iniciándose en puerto de desarrollo Vite." -ForegroundColor Green
    } else {
        Write-Warning "No se encontró el directorio de la UI de Seguridad en $securityUiDir"
    }
}
