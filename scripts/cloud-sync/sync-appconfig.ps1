<#
.SYNOPSIS
    Sincroniza los catálogos de mensajes y parámetros de Asistencias UCO hacia Azure App Configuration.

.DESCRIPTION
    1. Carga variables de entorno (AZURE_APP_CONFIGURATION_NAME).
    2. Elimina llaves residuales numéricas ('0', '1', '2') si existen.
    3. Exporta los catálogos desde los seeds SQL a JSON (CatalogoMensajeUsuario, CatalogoMensajeTecnico, CatalogoParametro).
    4. Sube las claves a Azure App Configuration respetando codificación UTF-8:
       - Mensajes de Usuario: 'messages:user:<CODIGO>' con label 'es'
       - Mensajes Técnicos:   'messages:technical:<CODIGO>' sin label
       - Parámetros:          '<GRUPO>:<CLAVE>' y 'asistencias:<grupo>:<clave>'

.PARAMETER AppConfigName
    Nombre del recurso de Azure App Configuration (por defecto: 'appcs-asist-dev-29183' o de variable de entorno).

.PARAMETER UseRest
    Usa la API REST directa con token OAuth2 de Azure CLI para garantizar transmisión UTF-8 exacta sin alteración por shell.

.PARAMETER SkipCleanResidual
    Omite la limpieza inicial de llaves numéricas ('0', '1', '2').

.EXAMPLE
    .\sync-appconfig.ps1
    .\sync-appconfig.ps1 -UseRest
#>

[CmdletBinding()]
param(
    [string]$AppConfigName = "",
    [switch]$UseRest,
    [switch]$SkipCleanResidual
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Cargar variables de entorno si están disponibles
$loadEnvScript = Join-Path $PSScriptRoot "..\orchestration\load-env.ps1"
if (Test-Path $loadEnvScript) {
    . $loadEnvScript
}

if (-not $AppConfigName) {
    if ($env:AZURE_APP_CONFIGURATION_NAME) {
        $AppConfigName = $env:AZURE_APP_CONFIGURATION_NAME
    } else {
        $AppConfigName = "appcs-asist-dev-29183"
    }
}

$endpoint = "https://${AppConfigName}.azconfig.io"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " SINCRONIZACION DE CATALOGOS HACIA AZURE APP CONFIGURATION" -ForegroundColor Cyan
Write-Host " Recurso:  $AppConfigName" -ForegroundColor Cyan
Write-Host " Endpoint: $endpoint" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 2. Verificar disponibilidad de Azure CLI
$azCli = Get-Command "az" -ErrorAction SilentlyContinue
if (-not $azCli) {
    throw "Azure CLI ('az') no está instalado o no se encuentra en el PATH. Instálelo para sincronizar con Azure."
}

try {
    $currentAccount = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $currentAccount) {
        throw "No hay una sesión activa en Azure CLI. Ejecute 'az login' antes de continuar."
    }
    Write-Host "Cuenta Azure activa: $($currentAccount.user.name) (Suscripción: $($currentAccount.name))" -ForegroundColor DarkGray
} catch {
    throw "Error al comprobar sesión de Azure CLI: $($_.Exception.Message). Ejecute 'az login'."
}

# 3. Limpieza de llaves residuales numéricas
if (-not $SkipCleanResidual) {
    Write-Host ""
    Write-Host "[PASO 1] Limpiando llaves residuales numéricas ('0', '1', '2')..." -ForegroundColor Yellow
    foreach ($k in @("0", "1", "2")) {
        try {
            az appconfig kv delete --name $AppConfigName --key $k --yes --output none 2>$null
            Write-Host "  Llave residual '$k' eliminada o no existente." -ForegroundColor DarkGray
        } catch {
            # Ignorar si no existe
        }
    }
}

# 4. Exportar catálogos a JSON en memoria/disco
Write-Host ""
Write-Host "[PASO 2] Extrayendo catálogos desde seeds de SQL Server..." -ForegroundColor Cyan
$exportScript = Join-Path $PSScriptRoot "export-catalogs.ps1"
$tempOutputDir = Join-Path $PSScriptRoot "output"

& $exportScript -OutputDir $tempOutputDir

$userJsonFile = Join-Path $tempOutputDir "user_messages.json"
$techJsonFile = Join-Path $tempOutputDir "tech_messages.json"
$paramJsonFile = Join-Path $tempOutputDir "parameters.json"

if (-not (Test-Path $userJsonFile) -or -not (Test-Path $techJsonFile) -or -not (Test-Path $paramJsonFile)) {
    throw "Error: No se generaron todos los archivos JSON esperados."
}

$userKv = Get-Content -Path $userJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
$techKv = Get-Content -Path $techJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
$paramKv = Get-Content -Path $paramJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json

# 5. Función de sincronización (REST o CLI)
if ($UseRest) {
    Write-Host ""
    Write-Host "[PASO 3] Obteniendo token de acceso para Azure App Configuration (Modo REST UTF-8)..." -ForegroundColor Cyan
    $token = az account get-access-token --resource $endpoint --query accessToken -o tsv 2>$null
    if (-not $token) {
        throw "No se pudo obtener el access token para el recurso $endpoint."
    }

    $headers = @{
        'Authorization' = "Bearer $token"
        'Content-Type'  = 'application/vnd.microsoft.appconfig.kv+json; charset=utf-8'
    }

    function Upload-KvRest($obj, $label) {
        foreach ($prop in $obj.PSObject.Properties) {
            $key = $prop.Name
            $val = $prop.Value
            $url = "${endpoint}/kv/${key}?api-version=1.0"
            if ($label) {
                $url += "&label=${label}"
            }
            $body = '{"value":' + ($val | ConvertTo-Json) + '}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $bytes | Out-Null
            Write-Host "  [OK REST] $key" -ForegroundColor Green
        }
    }

    Write-Host "Subiendo Mensajes de Usuario (label 'es')..." -ForegroundColor Cyan
    Upload-KvRest $userKv "es"

    Write-Host "Subiendo Mensajes Técnicos (sin label)..." -ForegroundColor Cyan
    Upload-KvRest $techKv $null

    Write-Host "Subiendo Parámetros de Configuración..." -ForegroundColor Cyan
    Upload-KvRest $paramKv $null

} else {
    Write-Host ""
    Write-Host "[PASO 3] Sincronizando mediante Azure CLI (az appconfig kv set)..." -ForegroundColor Cyan
    
    Write-Host "Subiendo Mensajes de Usuario (label 'es')..." -ForegroundColor Cyan
    foreach ($prop in $userKv.PSObject.Properties) {
        $k = $prop.Name
        $v = $prop.Value
        az appconfig kv set --name $AppConfigName --key $k --label "es" --value $v --yes --output none
        Write-Host "  [OK] $k" -ForegroundColor Green
    }

    Write-Host "Subiendo Mensajes Técnicos (sin label)..." -ForegroundColor Cyan
    foreach ($prop in $techKv.PSObject.Properties) {
        $k = $prop.Name
        $v = $prop.Value
        az appconfig kv set --name $AppConfigName --key $k --value $v --yes --output none
        Write-Host "  [OK] $k" -ForegroundColor Green
    }

    Write-Host "Subiendo Parámetros de Configuración..." -ForegroundColor Cyan
    foreach ($prop in $paramKv.PSObject.Properties) {
        $k = $prop.Name
        $v = $prop.Value
        az appconfig kv set --name $AppConfigName --key $k --value $v --yes --output none
        Write-Host "  [OK] $k" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " SINCRONIZACION HACIA AZURE COMPLETADA EXITOSAMENTE!       " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
