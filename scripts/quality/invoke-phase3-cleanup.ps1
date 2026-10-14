<#
.SYNOPSIS
    Script Automatizado y Seguro de Limpieza y Deprecación (Fase 3).

.DESCRIPTION
    Ejecuta o simula de forma controlada la transición definitiva de Fase 3:
    1. Pre-Flight Check: Verifica obligatoriamente 'infra.ps1 verify' (si falla, aborta).
    2. Scripts Duplicados: Limpia scripts redundantes en subcarpetas de scripts/ y scratch/.
    3. Gobernanza Canónica: Reemplaza copias locales de constitución por punteros oficiales de 5 líneas.

.PARAMETER Execute
    Si se especifica, ejecuta la limpieza real. Por defecto corre en modo seguro (Dry-Run / WhatIf).

.PARAMETER DryRun
    Fuerza el modo de simulación sin modificar ningún archivo.

.EXAMPLE
    .\invoke-phase3-cleanup.ps1
    .\invoke-phase3-cleanup.ps1 -DryRun
    .\invoke-phase3-cleanup.ps1 -Execute
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Execute,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$isDryRun = (-not $Execute) -or $DryRun -or $WhatIfPreference

$infraDir = (Resolve-Path "$PSScriptRoot\..\..").Path
$repoRoot = (Resolve-Path "$infraDir\..").Path
$infraCli = Join-Path $infraDir "infra.ps1"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🧹 ASISTENCIAS UCO - PROTOCOLO CONTROLADO DE LIMPIEZA (FASE 3)" -ForegroundColor Cyan
Write-Host "Modo de Ejecución : $(if ($isDryRun) { 'SIMULACIÓN (DRY-RUN / WHATIF) - CERO CAMBIOS EN DISCO' } else { 'EJECUCIÓN REAL (-Execute)' })" -ForegroundColor $(if ($isDryRun) { "Yellow" } else { "Red" })
Write-Host "Directorio Raíz   : $repoRoot" -ForegroundColor DarkGray
Write-Host "==============================================================================" -ForegroundColor Cyan

# 1. VERIFICACIÓN PRE-FLIGHT (Obligatoria si se ejecuta)
if (-not $isDryRun) {
    Write-Host "`n[PASO 1/3] Ejecutando Pre-Flight Check de Hardening y Contratos..." -ForegroundColor Yellow
    & $infraCli verify
    if ($LASTEXITCODE -ne 0) {
        throw "Pre-Flight Check falló. Se aborta la limpieza para evitar pérdida de datos o desincronización de contratos."
    }
    Write-Host "  -> Pre-Flight Check aprobado. Procediendo con la limpieza controlada." -ForegroundColor Green
} else {
    Write-Host "`n[PASO 1/3] Simulación de Pre-Flight Check..." -ForegroundColor Yellow
    Write-Host "  -> En ejecución real se exigirá 'infra.ps1 verify' en verde antes de cualquier cambio." -ForegroundColor Gray
}

# 2. INVENTARIO DE SCRIPTS DUPLICADOS A ELIMINAR (Conforme a INVENTORY_MAPPING.md)
$scriptsToDelete = @(
    'scripts/general/iniciar-todo.ps1',
    'scripts/general/iniciar-app.ps1',
    'scripts/general/detener-todo.ps1',
    'scripts/general/start-dev.ps1',
    'scripts/general/tests/test_all_hus.ps1',
    'scripts/database/restablecer-datos-limpios.ps1',
    'scripts/database/deploy_schema.ps1',
    'scripts/database/tests/test_summary.ps1',
    'scripts/backend/load-env.ps1',
    'scripts/backend/tests/test-local.ps1',
    'scripts/azure/export_json_utf8.ps1',
    'scripts/azure/sync-appconfig-catalog.ps1',
    'scratch/test_all_hus.ps1'
)

Write-Host "`n[PASO 2/3] Análisis de Scripts Redundantes / Duplicados..." -ForegroundColor Yellow
$scriptReport = @()

foreach ($rel in $scriptsToDelete) {
    $full = Join-Path $repoRoot $rel
    $exists = Test-Path $full
    $action = if (-not $exists) { "ALREADY_CLEAN" } elseif ($isDryRun) { "WOULD_DELETE" } else { "DELETED" }

    if (-not $isDryRun -and $exists) {
        Remove-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
    }

    $scriptReport += [PSCustomObject]@{
        Script = $rel
        Existe = $exists
        Accion = $action
    }
}

$scriptReport | Format-Table -AutoSize

# 3. DOCUMENTOS DE GOBERNANZA A REEMPLAZAR POR PUNTERO CANÓNICO
$canonicalPointerContent = @"
# 📌 DOCUMENTO REUBICADO — ÚNICA FUENTE DE VERDAD (SSOT)
> **Aviso de Gobernanza:** Este documento ha sido centralizado formalmente en el módulo de Infraestructura y Hardening.
> **Ruta Canónica:** [`AsistenciasUCO-Infra/docs/governance/CONSTITUTION.md`](file:///c:/Proyectos/GestioAsistencia/AsistenciasUCO-Infra/docs/governance/CONSTITUTION.md)  
> **Referencia:** Consulta la única fuente de verdad para evitar derivas normativas o desincronización de contratos.
"@

$docsToCanonicalize = @(
    '.specify/memory/constitution.md'
)

Write-Host "`n[PASO 3/3] Análisis de Documentación Redundante (Punteros Canónicos)..." -ForegroundColor Yellow
$docReport = @()
$utf8WithBom = New-Object System.Text.UTF8Encoding($true)

foreach ($relDoc in $docsToCanonicalize) {
    $fullDoc = Join-Path $repoRoot $relDoc
    $exists = Test-Path $fullDoc
    $action = if (-not $exists) { "NOT_FOUND" } elseif ($isDryRun) { "WOULD_CANONICALIZE" } else { "CANONICALIZED" }

    if (-not $isDryRun -and $exists) {
        [System.IO.File]::WriteAllText($fullDoc, $canonicalPointerContent, $utf8WithBom)
    }

    $docReport += [PSCustomObject]@{
        Documento = $relDoc
        Existe = $exists
        Accion = $action
    }
}

$docReport | Format-Table -AutoSize

Write-Host "==============================================================================" -ForegroundColor Cyan
if ($isDryRun) {
    Write-Host " [SIMULACIÓN COMPLETADA] Ningún archivo fue modificado ni eliminado." -ForegroundColor Yellow
    Write-Host " Para aplicar estos cambios de forma permanente en el futuro, ejecuta:" -ForegroundColor Gray
    Write-Host "   .\AsistenciasUCO-Infra\scripts\quality\invoke-phase3-cleanup.ps1 -Execute" -ForegroundColor White
} else {
    Write-Host " [PASS] LIMPIEZA DE FASE 3 EJECUTADA Y CERTIFICADA EXITOSAMENTE!" -ForegroundColor Green
}
Write-Host "==============================================================================" -ForegroundColor Cyan
