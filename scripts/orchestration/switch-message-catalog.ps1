<#
.SYNOPSIS
    Switch del catalogo de mensajes del Backend: Azure App Configuration (actual) <-> MessageUcoLab (equipo de mensajeria).

.DESCRIPTION
    Actualiza GestioAsistenciaBackend\.env:
    - Modo 'azure'         : APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER=azure (predeterminado del backend).
    - Modo 'messageucolab' : APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER=messageucolab + MESSAGEUCOLAB_URL y MESSAGEUCOLAB_CLIENT_ID
                             (INT-003, MessageUcoLab 0.3.0: identidad de servicio con rol MESSAGE_CONSUMER creada en la
                             consola de Seguridad y asociada al ambiente en MessageUcoLab). El secreto MESSAGEUCOLAB_CLIENT_SECRET
                             lo escribe la persona en el .env (se ve una sola vez); este script solo comprueba que exista.
                             La contingencia es MESSAGEUCOLAB_FALLBACK.
    - Modo 'status'        : Informa el modo activo sin modificar nada.
    El switch es estructural (arranque): reinicia el Backend despues de cambiarlo.

.PARAMETER Mode
    azure | messageucolab | status

.PARAMETER ClientId
    Client ID de la identidad de servicio (empieza por svc-; solo modo messageucolab; obligatorio la primera vez).

.PARAMETER Url
    URL base de MessageUcoLab (gateway Kong). Predeterminado http://localhost:8000.

.PARAMETER Fallback
    azure (predeterminado) | none.

.EXAMPLE
    .\switch-message-catalog.ps1 -Mode status
    .\switch-message-catalog.ps1 -Mode messageucolab -ClientId svc-...-asistencias-dev
    .\switch-message-catalog.ps1 -Mode azure
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('azure', 'messageucolab', 'status')]
    [string]$Mode = 'status',

    [string]$ClientId,
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

function Write-EnvFile([string]$path, [string]$content) {
    # UTF-8 sin BOM: Set-Content -Encoding utf8 de PowerShell 5.1 antepone un BOM que rompe la primera variable del .env.
    [System.IO.File]::WriteAllText($path, $content.TrimEnd() + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
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
        Write-Host "  * Client ID       : $(Get-EnvValue $content 'MESSAGEUCOLAB_CLIENT_ID')" -ForegroundColor Yellow
        $secreto = Get-EnvValue $content 'MESSAGEUCOLAB_CLIENT_SECRET'
        Write-Host "  * Secreto         : $(if ([string]::IsNullOrWhiteSpace($secreto)) { 'FALTA' } else { 'presente' })" -ForegroundColor Yellow
        Write-Host "  * Avisos (Pulsar) : $(Get-EnvValue $content 'MESSAGEUCOLAB_PULSAR_URL')" -ForegroundColor Yellow
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
    Write-EnvFile $backendEnv $content
    Write-Host "  -> Backend .env: provider=azure. Las variables MESSAGEUCOLAB_* se conservan sin efecto." -ForegroundColor Green
} else {
    $cliente = if ($ClientId) { $ClientId.Trim() } else { Get-EnvValue $content 'MESSAGEUCOLAB_CLIENT_ID' }
    if ($cliente -notmatch '^svc-[A-Za-z0-9_-]+$') {
        throw "Falta MESSAGEUCOLAB_CLIENT_ID (empieza por svc-). Crea la identidad en la consola de Seguridad (http://localhost:5173, Identidades de servicio), pide y aprueba MESSAGE_CONSUMER, asociala al ambiente en MessageUcoLab (http://localhost:5174) y pasala con -ClientId."
    }
    if ([string]::IsNullOrWhiteSpace((Get-EnvValue $content 'MESSAGEUCOLAB_CLIENT_SECRET'))) {
        Write-Host "  [!] Falta MESSAGEUCOLAB_CLIENT_SECRET en el .env: escribelo a mano (el Backend no arranca sin el)." -ForegroundColor Yellow
    }
    $content = Set-EnvValue $content 'APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER' 'messageucolab'
    $content = Set-EnvValue $content 'MESSAGEUCOLAB_URL' $Url
    $content = Set-EnvValue $content 'MESSAGEUCOLAB_CLIENT_ID' $cliente
    $content = Set-EnvValue $content 'MESSAGEUCOLAB_FALLBACK' $Fallback
    Write-EnvFile $backendEnv $content
    Write-Host "  -> Backend .env: provider=messageucolab, url=$Url, contingencia=$Fallback." -ForegroundColor Green
    Write-Host "  -> Recuerda levantar el componente: .\infra.ps1 messages-up" -ForegroundColor Gray
}

Write-Host "`n[!] Reinicia el Backend para aplicar el cambio (el provider se elige al arrancar)." -ForegroundColor Yellow
