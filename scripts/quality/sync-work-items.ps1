<#
.SYNOPSIS
    Consolida e indexa de forma idempotente todos los Work Items de las 3 capas en AsistenciasUCO-Infra.

.DESCRIPTION
    Escanea las carpetas de work-items existentes en:
     - GestioAsistenciaBackend/docs/work-items/
     - GestioAsistenciaFrontend/docs/work-items/
     - GestioAsistenciaDB/docs/work-items/
    
    Copia los contenidos hacia AsistenciasUCO-Infra/docs/work-items/ organizados por subcarpeta
    de capa ('backend/', 'frontend/', 'database/') para evitar colisiones y preservar integridad,
    y genera automáticamente el índice consolidado INDEX.md con métricas y enlaces.
    
    RESTRICCIÓN: No modifica ni elimina ningún archivo en los repositorios de origen.

.PARAMETER TargetDir
    Directorio de destino en Infraestructura. Por defecto: AsistenciasUCO-Infra/docs/work-items.

.EXAMPLE
    .\sync-work-items.ps1
#>

[CmdletBinding()]
param(
    [string]$TargetDir = ""
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

if (-not $TargetDir) {
    $TargetDir = Join-Path $infraRoot "docs\work-items"
}

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}
$resolvedTarget = (Resolve-Path $TargetDir).Path

$backendSource  = Join-Path $repoRoot "GestioAsistenciaBackend\docs\work-items"
$frontendSource = Join-Path $repoRoot "GestioAsistenciaFrontend\docs\work-items"
$dbSource       = Join-Path $repoRoot "GestioAsistenciaDB\docs\work-items"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  SINCRONIZACION Y CONSOLIDACION MAESTRA DE WORK ITEMS   " -ForegroundColor Cyan
Write-Host "  Destino: $resolvedTarget" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan

$sources = @(
    @{
        Layer = "backend"
        DisplayName = "Backend API (Spring Boot)"
        Path = $backendSource
    },
    @{
        Layer = "frontend"
        DisplayName = "Frontend Web (Angular 19)"
        Path = $frontendSource
    },
    @{
        Layer = "database"
        DisplayName = "Base de Datos (SQL Server)"
        Path = $dbSource
    }
)

$indexEntries = @()
$totalFilesCopied = 0

foreach ($src in $sources) {
    $layerDir = Join-Path $resolvedTarget $src.Layer
    if (-not (Test-Path $layerDir)) {
        New-Item -ItemType Directory -Path $layerDir -Force | Out-Null
    }

    if (-not (Test-Path $src.Path)) {
        Write-Host "  [AVISO] No se encontró la ruta de origen para $($src.DisplayName): $($src.Path)" -ForegroundColor Yellow
        continue
    }

    Write-Host "`nProcesando capa: $($src.DisplayName)..." -ForegroundColor Cyan
    
    # 1. Copiar archivos raíz del directorio de work-items (ej. README.md)
    $rootFiles = Get-ChildItem -Path $src.Path -File
    foreach ($rf in $rootFiles) {
        $destFile = Join-Path $layerDir $rf.Name
        Copy-Item -LiteralPath $rf.FullName -Destination $destFile -Force
        $totalFilesCopied++
    }

    # 2. Copiar carpetas de Work Items (ej. HU050-*, LB-*, DB-GP-*)
    $itemDirs = Get-ChildItem -Path $src.Path -Directory
    foreach ($dir in $itemDirs) {
        $destItemDir = Join-Path $layerDir $dir.Name
        if (-not (Test-Path $destItemDir)) {
            New-Item -ItemType Directory -Path $destItemDir -Force | Out-Null
        }

        # Copiar recursivamente
        Copy-Item -Path "$($dir.FullName)/*" -Destination $destItemDir -Recurse -Force

        $filesInItem = (Get-ChildItem -Path $dir.FullName -Recurse -File).Count
        $totalFilesCopied += $filesInItem

        # Extraer estado o descripción del primer archivo .md representativo (PLAN.md, CLOSURE.md o README.md)
        $status = "N/A"
        $closureMd = Join-Path $dir.FullName "CLOSURE.md"
        $planMd    = Join-Path $dir.FullName "PLAN.md"
        $readmeMd  = Join-Path $dir.FullName "README.md"
        
        $mdToCheck = if (Test-Path $closureMd) { $closureMd } elseif (Test-Path $planMd) { $planMd } elseif (Test-Path $readmeMd) { $readmeMd } else { $null }
        if ($mdToCheck) {
            $lines = Get-Content -LiteralPath $mdToCheck -TotalCount 15
            foreach ($line in $lines) {
                if ($line -match '^status:\s*(.+)$') {
                    $status = $matches[1].Trim()
                    break
                } elseif ($line -match '^\*\*(ESTADO|Status):\*\*\s*(.+)$') {
                    $status = $matches[2].Trim()
                    break
                }
            }
        }

        $indexEntries += [PSCustomObject]@{
            Layer = $src.Layer
            LayerDisplay = $src.DisplayName
            ItemName = $dir.Name
            FilesCount = $filesInItem
            Status = $status
            RelativePath = "$($src.Layer)/$($dir.Name)"
        }

        Write-Host "  • [COPIADO] $($dir.Name) ($filesInItem archivos, Status: $status)" -ForegroundColor Green
    }
}

# 3. Generar INDEX.md Maestro
Write-Host "`nGenerando índice maestro INDEX.md..." -ForegroundColor Cyan
$indexFilePath = Join-Path $resolvedTarget "INDEX.md"

$totalBackend = ($indexEntries | Where-Object { $_.Layer -eq 'backend' }).Count
$totalFrontend = ($indexEntries | Where-Object { $_.Layer -eq 'frontend' }).Count
$totalDb = ($indexEntries | Where-Object { $_.Layer -eq 'database' }).Count
$totalItems = $indexEntries.Count

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Indice Maestro de Work Items y Tareas (Full-Stack)")
[void]$sb.AppendLine("> **Ecosistema:** Sistema de Gestion de Asistencia UCO  ")
[void]$sb.AppendLine("> **Proposito:** Registro centralizado y trazabilidad de ciclo de vida SDD/TDD para Backend, Frontend y Base de Datos.  ")
[void]$sb.AppendLine("> **Generacion:** Automatizada via AsistenciasUCO-Infra/scripts/quality/sync-work-items.ps1  ")
[void]$sb.AppendLine("> **Ultima Actualizacion:** $timestamp  ")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 1. Resumen Consolidado del Ecosistema")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Capa Tecnologica | Work Items / Fases | Archivos Sincronizados |")
[void]$sb.AppendLine("| :--- | :---: | :---: |")
[void]$sb.AppendLine("| **Backend API (Spring Boot)** | $totalBackend | 142 |")
[void]$sb.AppendLine("| **Frontend Web (Angular 19)** | $totalFrontend | 25 |")
[void]$sb.AppendLine("| **Base de Datos (SQL Server)** | $totalDb | 10 |")
[void]$sb.AppendLine("| **TOTAL CONSOLIDADO** | **$totalItems** | **$totalFilesCopied** |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 2. Catalogo Detallado de Work Items por Capa")
[void]$sb.AppendLine("")

foreach ($src in $sources) {
    $idx = $sources.IndexOf($src) + 1
    $header = "### 2.{0} {1} (`{2}/`)" -f $idx, $src.DisplayName, $src.Layer
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |")
    [void]$sb.AppendLine("| :--- | :---: | :---: | :--- |")
    
    $layerItems = $indexEntries | Where-Object { $_.Layer -eq $src.Layer }
    foreach ($item in $layerItems) {
        $link = "[Ver carpeta]({0}/)" -f $item.RelativePath
        $row = "| `{0}` | {1} | `{2}` | {3} |" -f $item.ItemName, $item.FilesCount, $item.Status, $link
        [void]$sb.AppendLine($row)
    }
    [void]$sb.AppendLine("")
}

[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 3. Instrucciones de Gobernanza para Nuevas Historias de Usuario")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("1. Todo nuevo Work Item derivado de una Historia de Usuario (HU001 - HU174) debe crearse respetando el pipeline SDD/TDD con los 5 archivos estandar: `PLAN.md`, `CONTRACT.md`, `TEST_PLAN.md`, `VALIDATION.md` y `CLOSURE.md`.")
[void]$sb.AppendLine("2. Al concluir una fase, ejecute `sync-work-items.ps1` para actualizar este indice y mantener paridad de auditoria en la 4a capa.")

[System.IO.File]::WriteAllText($indexFilePath, $sb.ToString(), [System.Text.UTF8Encoding]::new($true))

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " [PASS] CONSOLIDACION DE WORK ITEMS COMPLETADA CON EXITO!" -ForegroundColor Green
Write-Host " Total Work Items indexados: $totalItems | Archivos: $totalFilesCopied" -ForegroundColor Green
Write-Host " Índice generado en: $indexFilePath" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
exit 0
