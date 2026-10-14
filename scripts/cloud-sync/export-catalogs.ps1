<#
.SYNOPSIS
    Exporta catálogos de mensajes y parámetros desde SQL Server seeds hacia JSON en UTF-8 estándar.

.DESCRIPTION
    Extrae las definiciones de CatalogoMensajeUsuario, CatalogoMensajeTecnico y CatalogoParametro
    de los scripts seed de base de datos y genera archivos JSON UTF-8 sin BOM listos para ser
    sincronizados con Azure App Configuration o consumidos offline.

.PARAMETER DbSeedDir
    Ruta a la carpeta con los archivos seed SQL (04_mensaje.sql, 03_parametro.sql).
    Por defecto: ../../../GestioAsistenciaDB/schema/seed

.PARAMETER OutputDir
    Directorio de salida para los archivos JSON generados.
    Por defecto: ./output en el directorio del script.

.EXAMPLE
    .\export-catalogs.ps1
#>

[CmdletBinding()]
param(
    [string]$DbSeedDir = "$PSScriptRoot/../../../GestioAsistenciaDB/schema/seed",
    [string]$OutputDir = "$PSScriptRoot/output"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  EXPORTADOR DE CATALOGOS A JSON (SSOT DB -> AZURE/APP)  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$resolvedSeedDir = Resolve-Path $DbSeedDir -ErrorAction SilentlyContinue
if (-not $resolvedSeedDir -or -not (Test-Path $resolvedSeedDir)) {
    throw "No se encontró el directorio de seeds en: $DbSeedDir"
}

$seedMensajePath = Join-Path $resolvedSeedDir "04_mensaje.sql"
$seedParamPath   = Join-Path $resolvedSeedDir "03_parametro.sql"

if (-not (Test-Path $seedMensajePath)) {
    throw "No se encontró el archivo de mensajes en: $seedMensajePath"
}
if (-not (Test-Path $seedParamPath)) {
    throw "No se encontró el archivo de parámetros en: $seedParamPath"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$resolvedOutputDir = (Resolve-Path $OutputDir).Path

Write-Host "Directorio Seed:   $resolvedSeedDir" -ForegroundColor DarkGray
Write-Host "Directorio Salida: $resolvedOutputDir" -ForegroundColor DarkGray

$mensajeContent = Get-Content -Path $seedMensajePath -Raw -Encoding UTF8
$paramContent   = Get-Content -Path $seedParamPath   -Raw -Encoding UTF8

function Parse-MensajesMap($block) {
    $map = [ordered]@{}
    $lines = $block -split "\r?\n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\(''([^'']+)'',\s*''([^'']+)'',\s*''([^'']+)'',\s*''([^'']+)''\)') {
            $codigo = $matches[1]
            $tipo = $matches[2]
            $severidad = $matches[3]
            $contenido = $matches[4]
            $map[$codigo] = [PSCustomObject]@{
                Codigo = $codigo
                Tipo = $tipo
                Severidad = $severidad
                Contenido = $contenido
            }
        }
    }
    return $map
}

# 1. Parsear Mensajes de Usuario y Técnicos
$userBlockRegex = '(?ms)MERGE INTO \[dbo\]\.\[CatalogoMensajeUsuario\].*?USING \(VALUES\s*(.*?)\)\s*AS Source'
$techBlockRegex = '(?ms)MERGE INTO \[dbo\]\.\[CatalogoMensajeTecnico\].*?USING \(VALUES\s*(.*?)\)\s*AS Source'

$userMap = [ordered]@{}
$techMap = [ordered]@{}

if ($mensajeContent -match $userBlockRegex) {
    $userMap = Parse-MensajesMap $matches[1]
}
if ($mensajeContent -match $techBlockRegex) {
    $techMap = Parse-MensajesMap $matches[1]
}

# Generar Key-Value para Azure App Configuration
$userKv = [ordered]@{}
foreach ($k in $userMap.Keys) {
    $userKv["messages:user:$k"] = $userMap[$k].Contenido
}

$techKv = [ordered]@{}
foreach ($k in $techMap.Keys) {
    $techKv["messages:technical:$k"] = $techMap[$k].Contenido
}

# 2. Parsear Parámetros
$paramBlockRegex = '(?ms)MERGE INTO \[dbo\]\.\[CatalogoParametro\].*?USING \(VALUES\s*(.*?)\)\s*AS Source'
$paramKv = [ordered]@{}

if ($paramContent -match $paramBlockRegex) {
    $lines = $matches[1] -split "\r?\n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\(''([^'']+)'',\s*''([^'']+)'',\s*''([^'']*)'',\s*''([^'']+)'',\s*''([^'']*)''\)') {
            $grupo = $matches[1]
            $clave = $matches[2]
            $valor = $matches[3]
            $tipo  = $matches[4]
            
            # Formato directo: Grupo:Clave
            $paramKv["${grupo}:${clave}"] = $valor
            # Formato jerárquico: asistencias:grupo:clave-con-guiones
            $hierarchicalKey = "asistencias:" + $grupo.ToLowerInvariant() + ":" + $clave.ToLowerInvariant().Replace('_', '-')
            if (-not $paramKv.Contains($hierarchicalKey)) {
                $paramKv[$hierarchicalKey] = $valor
            }
        }
    }
}

# Escribir archivos JSON en UTF-8 sin BOM (estándar para REST / JSON)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

$userJsonPath = Join-Path $resolvedOutputDir "user_messages.json"
$techJsonPath = Join-Path $resolvedOutputDir "tech_messages.json"
$paramJsonPath = Join-Path $resolvedOutputDir "parameters.json"

[System.IO.File]::WriteAllText($userJsonPath, ($userKv | ConvertTo-Json -Depth 5), $utf8NoBom)
[System.IO.File]::WriteAllText($techJsonPath, ($techKv | ConvertTo-Json -Depth 5), $utf8NoBom)
[System.IO.File]::WriteAllText($paramJsonPath, ($paramKv | ConvertTo-Json -Depth 5), $utf8NoBom)

Write-Host "  [OK] Mensajes de Usuario exportados: $($userKv.Count) en $userJsonPath" -ForegroundColor Green
Write-Host "  [OK] Mensajes Técnicos exportados:   $($techKv.Count) en $techJsonPath" -ForegroundColor Green
Write-Host "  [OK] Parámetros exportados:          $($paramKv.Count) en $paramJsonPath" -ForegroundColor Green
Write-Host ""
Write-Host "Exportación completada con éxito." -ForegroundColor Cyan
