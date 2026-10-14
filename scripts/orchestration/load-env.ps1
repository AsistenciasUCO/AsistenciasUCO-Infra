<#
.SYNOPSIS
    Cargador unificado de variables de entorno para la sesión de PowerShell.

.DESCRIPTION
    Lee de forma segura el archivo .env de AsistenciasUCO-Infra (o realiza fallback a .env.example
    en entornos nuevos de desarrollo) y exporta cada variable como variable de entorno de proceso
    ($env:KEY = VALUE). Redacta en consola cualquier valor clasificado como secreto o contraseña.

.PARAMETER EnvPath
    Ruta opcional al archivo .env (Default: 'AsistenciasUCO-Infra/.env' o '../.env').

.EXAMPLE
    . .\load-env.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolver ruta de .env
if ([string]::IsNullOrWhiteSpace($EnvPath)) {
    $candidates = @(
        (Join-Path (Join-Path $PSScriptRoot "..") "..") + "\.env",
        (Join-Path $PSScriptRoot ".env"),
        (Join-Path (Join-Path $PSScriptRoot "..") "..") + "\.env.example"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $EnvPath = (Resolve-Path $c).Path
            break
        }
    }
}

if (-not (Test-Path $EnvPath)) {
    throw "No se encontró ningún archivo .env o .env.example en las rutas esperadas."
}

$isExample = $EnvPath.EndsWith(".example")
if ($isExample) {
    Write-Host "[AVISO] Usando plantilla .env.example como fallback. Crea tu '.env' local personalizado." -ForegroundColor Yellow
}

$secretPattern = '(?i)(PASSWORD|SECRET|KEY|TOKEN|CREDENTIAL|PRIVATE)'
$loadedCount = 0

Get-Content -LiteralPath $EnvPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $sep = $line.IndexOf('=')
        $key = $line.Substring(0, $sep).Trim()
        $val = $line.Substring($sep + 1).Trim()

        # Quitar comillas si existen
        if ($val.Length -ge 2 -and (
            ($val.StartsWith('"') -and $val.EndsWith('"')) -or
            ($val.StartsWith("'") -and $val.EndsWith("'"))
        )) {
            $val = $val.Substring(1, $val.Length - 2)
        }

        # Exportar al proceso
        [System.Environment]::SetEnvironmentVariable($key, $val, [System.EnvironmentVariableTarget]::Process)
        $loadedCount++
    }
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - VARIABLES DE ENTORNO CARGADAS" -ForegroundColor Cyan
Write-Host "Archivo : $EnvPath ($loadedCount variables exportadas)" -ForegroundColor Gray
Write-Host "Binding : $env:HOST_BIND_IP | Perfil por defecto: $env:COMPOSE_PROFILES" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan
