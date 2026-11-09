<#
.SYNOPSIS
    Genera o valida la matriz documental de rutas por rol desde access-catalog.json.

.DESCRIPTION
    Lee el catálogo formal de accesos y seguridad (access-catalog.json) del Backend
    y genera la especificación markdown en 'docs/architecture/rutas-por-rol.md'.
    Con el parámetro -Check, verifica que el archivo generado no presente drift
    respecto al catálogo JSON (útil para Quality Gates y Pre-Flight checks).

.PARAMETER Check
    Modo verificación. Sale con código 0 si el archivo está sincronizado, o 1 si hay drift.

.PARAMETER CatalogPath
    Ruta explícita al archivo access-catalog.json.

.PARAMETER OutputPath
    Ruta destino para el archivo markdown generado.

.EXAMPLE
    .\scripts\docs\generar-rutas-por-rol.ps1
    .\scripts\docs\generar-rutas-por-rol.ps1 -Check
#>

[CmdletBinding()]
param (
    [switch]$Check,
    [string]$CatalogPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$infraRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

# 1. Resolver ruta de access-catalog.json
if (-not $CatalogPath) {
    $candidates = @(
        $env:ACCESS_CATALOG_PATH,
        (Join-Path $infraRoot "..\GestioAsistenciaBackend\infra\security-baseline\access-catalog.json"),
        (Join-Path $infraRoot "..\..\GestioAsistenciaBackend\infra\security-baseline\access-catalog.json"),
        "C:\Proyectos\GestionAsistencia-CULM001\GestioAsistenciaBackend\infra\security-baseline\access-catalog.json",
        "C:\Proyectos\GestionAsistencia\GestioAsistenciaBackend\infra\security-baseline\access-catalog.json"
    )

    foreach ($cand in $candidates) {
        if ($cand -and (Test-Path -LiteralPath $cand)) {
            $CatalogPath = (Resolve-Path -LiteralPath $cand).Path
            break
        }
    }
}

if (-not $CatalogPath -or -not (Test-Path -LiteralPath $CatalogPath)) {
    Write-Error "No se encontró access-catalog.json. Especifica -CatalogPath o define la variable ACCESS_CATALOG_PATH."
    exit 1
}

# 2. Resolver ruta de salida
if (-not $OutputPath) {
    $OutputPath = Join-Path $infraRoot "docs\architecture\rutas-por-rol.md"
}

# 3. Leer y parsear access-catalog.json
$jsonRaw = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8
$catalog = $jsonRaw | ConvertFrom-Json

$rolesList = @("ADMINISTRADOR", "DECANO", "COORDINADOR", "DOCENTE", "ESTUDIANTE")
if ($catalog.roles) {
    $rolesList = @($catalog.roles)
}

$sb = [System.Text.StringBuilder]::new()

# Cabecera
[void]$sb.AppendLine('# Matriz de Rutas y Permisos por Rol (Access Catalog)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> **Documento autogenerado.** No editar manualmente.')
[void]$sb.AppendLine('> **Fuente SSOT:** `access-catalog.json` (Security Baseline)')
[void]$sb.AppendLine('> **Generador:** `scripts/docs/generar-rutas-por-rol.ps1` (F-ADM-020)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Este documento detalla todas las rutas expuestas por la API REST de Asistencias UCO,')
[void]$sb.AppendLine('sus métodos HTTP permitidos, roles con acceso y políticas de propiedad o ámbito (*ownership*).')
[void]$sb.AppendLine('')

# Resumen
$totalEndpoints = if ($catalog.endpoints) { $catalog.endpoints.Count } else { 0 }
$totalExempt = if ($catalog.exempt) { $catalog.exempt.Count } else { 0 }
$rolesStr = $rolesList -join ', '

[void]$sb.AppendLine('## Resumen General')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("- **Total de Endpoints Protegidos:** $totalEndpoints")
[void]$sb.AppendLine("- **Total de Endpoints Exentos (Públicos / Webhook):** $totalExempt")
[void]$sb.AppendLine("- **Roles Definidos:** $rolesStr")
[void]$sb.AppendLine('')

# Perfiles
if ($catalog.profiles -and $catalog.profiles.Count -gt 0) {
    [void]$sb.AppendLine('## Perfiles Funcionales')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Perfil | Roles Asociados | Descripción |')
    [void]$sb.AppendLine('| :--- | :--- | :--- |')
    foreach ($prof in $catalog.profiles) {
        $pName = $prof.name
        $pRoles = ($prof.roles -join ', ')
        $pDesc = $prof.description
        [void]$sb.AppendLine("| **$pName** | ``$pRoles`` | $pDesc |")
    }
    [void]$sb.AppendLine('')
}

# Rutas por cada Rol
[void]$sb.AppendLine('## Catálogo de Rutas por Rol')
[void]$sb.AppendLine('')

foreach ($rol in $rolesList) {
    $endpointsForRole = @($catalog.endpoints | Where-Object {
        $_.roles -and ($_.roles -contains $rol)
    } | Sort-Object { $_.path }, { $_.method })

    $count = $endpointsForRole.Count
    [void]$sb.AppendLine("### Rol: $rol ($count)")
    [void]$sb.AppendLine('')
    if ($count -eq 0) {
        [void]$sb.AppendLine('*No hay endpoints asignados a este rol.*')
        [void]$sb.AppendLine('')
        continue
    }

    [void]$sb.AppendLine('| Método | Ruta | Tipo de Acceso | Ámbito / Ownership |')
    [void]$sb.AppendLine('| :--- | :--- | :--- | :--- |')
    foreach ($ep in $endpointsForRole) {
        $m = $ep.method
        $p = $ep.path
        $a = $ep.access
        $o = if ($ep.ownership) { $ep.ownership -replace '\|', '\|' } else { '—' }
        [void]$sb.AppendLine("| ``$m`` | ``$p`` | $a | $o |")
    }
    [void]$sb.AppendLine('')
}

# Rutas Exentas / Públicas
if ($catalog.exempt -and $catalog.exempt.Count -gt 0) {
    [void]$sb.AppendLine('## Endpoints Exentos del PEP (Públicos / Integración)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Método | Ruta | Motivo / Justificación |')
    [void]$sb.AppendLine('| :--- | :--- | :--- |')
    foreach ($ex in ($catalog.exempt | Sort-Object { $_.path }, { $_.method })) {
        $em = $ex.method
        $ep = $ex.path
        $er = if ($ex.reason) { $ex.reason -replace '\|', '\|' } else { '—' }
        [void]$sb.AppendLine("| ``$em`` | ``$ep`` | $er |")
    }
    [void]$sb.AppendLine('')
}

$generatedText = $sb.ToString().Replace([string][char]13 + [string][char]10, [string][char]10)

if ($Check) {
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        Write-Error "[DRIFT] El archivo $OutputPath no existe. Ejecuta el script sin -Check para generarlo."
        exit 1
    }

    $existingRaw = Get-Content -LiteralPath $OutputPath -Raw -Encoding UTF8
    $existingText = $existingRaw.Replace([string][char]13 + [string][char]10, [string][char]10)
    if ($existingText.Trim() -ne $generatedText.Trim()) {
        Write-Error "[DRIFT] $OutputPath difiere de $CatalogPath. Ejecuta '.\scripts\docs\generar-rutas-por-rol.ps1' para sincronizarlo."
        exit 1
    }

    Write-Host "[OK] $OutputPath está sincronizado con access-catalog.json." -ForegroundColor Green
    exit 0
} else {
    $parentDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($OutputPath, $generatedText, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[OK] Matriz de rutas generada exitosamente en $OutputPath" -ForegroundColor Green
    exit 0
}
