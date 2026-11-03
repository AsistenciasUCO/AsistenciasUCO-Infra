<#
.SYNOPSIS
    Switch del catalogo de mensajes del Backend: Azure App Configuration (actual) <-> MessageUcoLab (equipo de mensajeria).

.DESCRIPTION
    Actualiza GestioAsistenciaBackend\.env:
    - Modo 'azure'         : APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER=azure (predeterminado del backend).
    - Modo 'messageucolab' : APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER=messageucolab + MESSAGEUCOLAB_URL / _APPLICATION_ID /
                             _ENVIRONMENT_ID (no son secretos; se copian con el boton "Copiar identificadores" de la
                             pantalla de MessageUcoLab, guia paso 7). Azure queda como contingencia (MESSAGEUCOLAB_FALLBACK).
    - Modo 'status'        : Informa el modo activo sin modificar nada.
    El switch es estructural (arranque): reinicia el Backend despues de cambiarlo.

.PARAMETER Mode
    azure | messageucolab | status

.PARAMETER ApplicationId
    UUID de la aplicacion en MessageUcoLab (solo modo messageucolab; obligatorio la primera vez).

.PARAMETER EnvironmentId
    UUID del ambiente (Develop/Testing/Produccion) de esa aplicacion.

.PARAMETER Url
    URL base de MessageUcoLab (gateway Kong). Predeterminado http://localhost:8000.

.PARAMETER Fallback
    azure (predeterminado) | none.

.EXAMPLE
    .\switch-message-catalog.ps1 -Mode status
    .\switch-message-catalog.ps1 -Mode messageucolab -ApplicationId <uuid> -EnvironmentId <uuid>
    .\switch-message-catalog.ps1 -Mode azure
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('azure', 'messageucolab', 'status')]
    [string]$Mode = 'status',

    [string]$ApplicationId,
    [string]$EnvironmentId,
    [string]$Url = 'http://localhost:8000',

    [ValidateSet('azure', 'none')]
    [string]$Fallback = 'azure'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infraRoot  = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repoRoot   = (Resolve-Path (Join-Path $infraRoot "..")).Path
$backendEnv = Join-Path $repoRoot "GestioAsistenciaBackend\.env"

if (-not (Test-Path $backendEnv)) { throw "No existe $backendEnv" }

function Get-EnvValue([string]$content, [string]$name) {
    $m = [regex]::Match($content, "(?m)^\s*$name\s*=\s*(.*)$")
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

function Set-EnvValue([string]$content, [string]$name, [string]$value) {
    $pattern = "(?m)^\s*$name\s*=.*$"
    if ([regex]::IsMatch($content, $pattern)) {
        return [regex]::Replace($content, $pattern, { param($m) "$name=$value" })
    }
    return $content.TrimEnd() + "`r`n$name=$value`r`n"
}

$content = Get-Content $backendEnv -Raw
$current = Get-EnvValue $content 'APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER'
if ([string]::IsNullOrWhiteSpace($current)) { $current = 'azure (predeterminado)' }

if ($Mode -eq 'status') {
    Write-Host "`n==============================================================================" -ForegroundColor Cyan
    Write-Host " ESTADO ACTUAL DEL SWITCH DEL CATALOGO DE MENSAJES" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "  * Provider activo : $current" -ForegroundColor Yellow
    if ($current -like 'messageucolab*') {
        Write-Host "  * URL             : $(Get-EnvValue $content 'MESSAGEUCOLAB_URL')" -ForegroundColor Yellow
        Write-Host "  * applicationId   : $(Get-EnvValue $content 'MESSAGEUCOLAB_APPLICATION_ID')" -ForegroundColor Yellow
        Write-Host "  * environmentId   : $(Get-EnvValue $content 'MESSAGEUCOLAB_ENVIRONMENT_ID')" -ForegroundColor Yellow
        Write-Host "  * Contingencia    : $(Get-EnvValue $content 'MESSAGEUCOLAB_FALLBACK')" -ForegroundColor Yellow
    }
    Write-Host "==============================================================================`n" -ForegroundColor Cyan
    exit 0
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " APLICANDO SWITCH DEL CATALOGO DE MENSAJES -> MODO: $($Mode.ToUpper())" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

if ($Mode -eq 'azure') {
    $content = Set-EnvValue $content 'APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER' 'azure'
    Set-Content -Path $backendEnv -Value $content.TrimEnd() -Encoding utf8
    Write-Host "  -> Backend .env: provider=azure. Las variables MESSAGEUCOLAB_* se conservan sin efecto." -ForegroundColor Green
} else {
    $guid = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    $appId = if ($ApplicationId) { $ApplicationId } else { Get-EnvValue $content 'MESSAGEUCOLAB_APPLICATION_ID' }
    $envId = if ($EnvironmentId) { $EnvironmentId } else { Get-EnvValue $content 'MESSAGEUCOLAB_ENVIRONMENT_ID' }
    if ($appId -notmatch $guid -or $envId -notmatch $guid) {
        throw "Faltan MESSAGEUCOLAB_APPLICATION_ID / MESSAGEUCOLAB_ENVIRONMENT_ID (UUID). Copialos en la pantalla de MessageUcoLab (http://localhost:5174, 'Copiar identificadores') y pasalos con -ApplicationId / -EnvironmentId."
    }
    # Los dos identificadores deben ser del MISMO boton: si no, MessageUcoLab responde 409 (guia, paso 7).
    $content = Set-EnvValue $content 'APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER' 'messageucolab'
    $content = Set-EnvValue $content 'MESSAGEUCOLAB_URL' $Url
    $content = Set-EnvValue $content 'MESSAGEUCOLAB_APPLICATION_ID' $appId
    $content = Set-EnvValue $content 'MESSAGEUCOLAB_ENVIRONMENT_ID' $envId
    $content = Set-EnvValue $content 'MESSAGEUCOLAB_FALLBACK' $Fallback
    Set-Content -Path $backendEnv -Value $content.TrimEnd() -Encoding utf8
    Write-Host "  -> Backend .env: provider=messageucolab, url=$Url, contingencia=$Fallback." -ForegroundColor Green
    Write-Host "  -> Recuerda levantar el componente: .\infra.ps1 messages-up" -ForegroundColor Gray
}

Write-Host "`n[!] Reinicia el Backend para aplicar el cambio (el provider se elige al arrancar)." -ForegroundColor Yellow
