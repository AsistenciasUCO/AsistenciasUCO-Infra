<#
.SYNOPSIS
    Orquestador de arranque de Security Baseline (equipo de seguridad): Keycloak, PDP, PEP, OPA, SurrealDB y Redis.

.DESCRIPTION
    Usa la instalacion local UNICA y endurecida del Backend (GestioAsistenciaBackend/infra/security-baseline/compose.yaml,
    proyecto Compose `asistencias-security-lab`): puertos solo en 127.0.0.1, version fija de imagen y secretos fuera de
    Git en %USERPROFILE%\.asistencias-security-lab\lab.env. Ya no se usa el compose de Complementos/Seguridad
    (version 0.1.7, puertos en 0.0.0.0), que pertenece a otro equipo y no se modifica.

    La consola web de administracion (Security UI, Vue 3) sigue viniendo de Complementos/Seguridad y se lanza con
    -WithUi sin modificarla.

.PARAMETER WithUi
    Inicia la pantalla de seguridad (Vue 3 / Vite, puerto 5173) en una ventana independiente.

.PARAMETER Down
    Detiene los contenedores (conserva volumenes). Nunca usa `down -v`.

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

$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

$composeFile = Join-Path $repoRoot "GestioAsistenciaBackend\infra\security-baseline\compose.yaml"
$envFile     = Join-Path $env:USERPROFILE ".asistencias-security-lab\lab.env"

# La pantalla de seguridad es del equipo de seguridad (Complementos): solo se ejecuta, no se modifica.
$securityDir = Join-Path $repoRoot "Complementos\Seguridad"
$securityUiDir = Join-Path $securityDir "securityBaseline-vue"
if (-not (Test-Path $securityUiDir)) { $securityUiDir = Join-Path $securityDir "security-ui" }

if (-not (Test-Path $composeFile)) {
    throw "No se encontro el compose de Security Baseline del Backend: $composeFile (actualiza el repositorio Backend)."
}
if (-not (Test-Path $envFile)) {
    throw "Falta $envFile (secretos locales, fuera de Git). Plantilla: GestioAsistenciaBackend\infra\security-baseline\lab.env.example"
}

function Assert-Docker {
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker Desktop no esta activo. Inicialo antes de continuar." }
}

# Compose escribe progreso/avisos por stderr: se valida por $LASTEXITCODE, no por stderr.
$ErrorActionPreference = 'Continue'

if ($Down) {
    Assert-Docker
    Write-Host "Deteniendo Security Baseline (los volumenes se conservan)..." -ForegroundColor Yellow
    docker compose --env-file "$envFile" -f "$composeFile" stop
    if ($LASTEXITCODE -ne 0) { throw "Error al detener Security Baseline." }
    Write-Host "  -> [OK] Detenido. NUNCA ejecutes 'down -v': borra el realm, el catalogo y las asignaciones." -ForegroundColor Green
    exit 0
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " ASISTENCIAS UCO - INICIO DE SECURITY BASELINE (PDP / PEP / KEYCLOAK)" -ForegroundColor Cyan
Write-Host " Compose : $composeFile" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

Assert-Docker

Write-Host "`n[1/2] Levantando servicios de seguridad..." -ForegroundColor Yellow
docker compose --env-file "$envFile" -f "$composeFile" up -d
if ($LASTEXITCODE -ne 0) { throw "Error al levantar Security Baseline con Docker Compose." }

Write-Host "`n[2/2] Esperando al PDP..." -ForegroundColor Yellow
$pdpPort = "18080"; $pepPort = "18081"; $kcPort = "19090"
foreach ($line in Get-Content $envFile) {
    if ($line -match '^\s*PDP_PORT\s*=\s*(\d+)') { $pdpPort = $Matches[1] }
    if ($line -match '^\s*PEP_PORT\s*=\s*(\d+)') { $pepPort = $Matches[1] }
    if ($line -match '^\s*KEYCLOAK_PORT\s*=\s*(\d+)') { $kcPort = $Matches[1] }
}
$ready = $false
for ($i = 0; $i -lt 40 -and -not $ready; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$pdpPort/actuator/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $ready = $true }
    } catch { Start-Sleep -Seconds 3 }
}

if ($ready) {
    Write-Host "`n==============================================================================" -ForegroundColor Green
    Write-Host " [OK] SECURITY BASELINE ACTIVO" -ForegroundColor Green
    Write-Host "  * Keycloak (realm security-baseline) : http://keycloak.localhost:$kcPort" -ForegroundColor Cyan
    Write-Host "  * PDP / BFF                          : http://127.0.0.1:$pdpPort" -ForegroundColor Cyan
    Write-Host "  * PEP                                : http://127.0.0.1:$pepPort" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Green
} else {
    Write-Warning "El PDP no respondio en 2 minutos. Revisa: docker logs asistencias-security-lab-pdp-1"
}

if ($WithUi) {
    if (Test-Path $securityUiDir) {
        Write-Host "`nLanzando la pantalla de seguridad (Vue 3) en nueva ventana..." -ForegroundColor Yellow
        $uiCmd = "Set-Location '$securityUiDir'; npm run dev"
        Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $uiCmd -WorkingDirectory $securityUiDir
        Write-Host "  -> Pantalla de seguridad iniciandose en http://localhost:5173" -ForegroundColor Green
    } else {
        Write-Warning "No se encontro la pantalla de seguridad en $securityUiDir"
    }
}
