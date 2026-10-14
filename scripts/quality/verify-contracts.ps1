<#
.SYNOPSIS
    Verificador y congelador de integridad criptográfica (SHA-256) para contratos WORM.

.DESCRIPTION
    Inspecciona y valida la integridad de los contratos canónicos del ecosistema en AsistenciasUCO-Infra
    y comprueba paridad (cero drift) contra los repositorios Backend y DB durante la transición:
     1. OpenAPI Golden Path (openapi-golden-path.yaml).
     2. Backend Golden Path Contract (BACKEND_GOLDEN_PATH_CONTRACT.md).
     3. DB Baseline Contract (DB_BASELINE_CONTRACT.md).
     4. Realtime Event Contract (REALTIME_EVENT_CONTRACT.md).
     5. DB Develop Freeze Manifest (DB_DEVELOP_FREEZE_MANIFEST.sha256 y sus 10 objetos congelados).
     6. Paridad cruzada (cero drift) Infraestructura <-> Backend / DB.
    
    Aplica normalización CRLF -> LF previa al cómputo SHA-256, garantizando resultados
    idénticos e interoperables entre Windows (core.autocrlf) y Linux/CI.

.PARAMETER Mode
    'Verify' (por defecto): Comprueba que los hashes coincidan con los manifiestos congelados.
    'Generate': Recalcula y escribe los hashes tras una decisión formal de evolución contractual.

.PARAMETER Root
    Directorio raíz del repositorio de Asistencias UCO.

.EXAMPLE
    .\verify-contracts.ps1 -Mode Verify
    .\verify-contracts.ps1 -Mode Generate
#>

[CmdletBinding()]
param(
    [ValidateSet('Verify', 'Generate')]
    [string]$Mode = 'Verify',

    [string]$Root = ""
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $Root) {
    $Root = (Resolve-Path "$PSScriptRoot/../../..").Path
} else {
    $Root = (Resolve-Path $Root).Path
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  VERIFICADOR DE CONTRATOS INMUTABLES WORM (SHA-256)     " -ForegroundColor Cyan
Write-Host "  Modo: $Mode | Raíz: $Root" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan

function Get-NormalizedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "El archivo para calcular hash no existe: $Path"
    }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $ms = [System.IO.MemoryStream]::new()
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        # Normalizar omitiendo byte 13 (\r) si precede a byte 10 (\n)
        if ($bytes[$i] -eq 13 -and ($i + 1) -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { 
            continue 
        }
        $ms.WriteByte($bytes[$i])
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($ms.ToArray())
    return ([System.BitConverter]::ToString($hashBytes).Replace('-', '')).ToLowerInvariant()
}

# Lista de contratos canónicos en Infraestructura
$canonicalContracts = @(
    @{
        Name = "OpenAPI Golden Path (Infra)"
        ContractFile = "AsistenciasUCO-Infra/docs/contracts/openapi/openapi-golden-path.yaml"
        ShaFile      = "AsistenciasUCO-Infra/docs/contracts/openapi/openapi-golden-path.sha256"
        RelativeRef  = "openapi-golden-path.yaml"
        PeerFile     = "GestioAsistenciaBackend/docs/contracts/openapi/openapi-golden-path.yaml"
    },
    @{
        Name = "Backend Golden Path Contract (Infra)"
        ContractFile = "AsistenciasUCO-Infra/docs/contracts/openapi/BACKEND_GOLDEN_PATH_CONTRACT.md"
        ShaFile      = "AsistenciasUCO-Infra/docs/contracts/openapi/BACKEND_GOLDEN_PATH_CONTRACT.sha256"
        RelativeRef  = "BACKEND_GOLDEN_PATH_CONTRACT.md"
        PeerFile     = "GestioAsistenciaBackend/docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md"
    },
    @{
        Name = "DB Baseline Contract (Infra)"
        ContractFile = "AsistenciasUCO-Infra/docs/contracts/db/DB_BASELINE_CONTRACT.md"
        ShaFile      = "AsistenciasUCO-Infra/docs/contracts/db/DB_BASELINE_CONTRACT.sha256"
        RelativeRef  = "DB_BASELINE_CONTRACT.md"
        PeerFile     = "GestioAsistenciaBackend/docs/contracts/external/db/DB_BASELINE_CONTRACT.md"
    },
    @{
        Name = "Realtime Event Contract (Infra)"
        ContractFile = "AsistenciasUCO-Infra/docs/contracts/events/REALTIME_EVENT_CONTRACT.md"
        ShaFile      = "AsistenciasUCO-Infra/docs/contracts/events/REALTIME_EVENT_CONTRACT.sha256"
        RelativeRef  = "REALTIME_EVENT_CONTRACT.md"
        PeerFile     = "GestioAsistenciaBackend/docs/contracts/REALTIME_EVENT_STANDARD.md"
    }
)

# Manifiesto consolidado de base de datos
$dbManifestRel = "AsistenciasUCO-Infra/docs/contracts/db/DB_DEVELOP_FREEZE_MANIFEST.sha256"
$dbBaseDir     = Join-Path $Root "GestioAsistenciaDB"

# -------------------------------------------------------------
# MODO GENERATE: Recalcula y congela hashes
# -------------------------------------------------------------
if ($Mode -eq 'Generate') {
    Write-Host "[MODO GENERATE] Recalculando hashes normalizados..." -ForegroundColor Yellow
    
    foreach ($sc in $canonicalContracts) {
        $cPath = Join-Path $Root $sc.ContractFile
        $sPath = Join-Path $Root $sc.ShaFile
        $hash = Get-NormalizedSha256 -Path $cPath
        $line = "$hash  $($sc.RelativeRef)`n"
        [System.IO.File]::WriteAllText($sPath, $line, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  [ACTUALIZADO] $($sc.Name) -> $hash" -ForegroundColor Green
    }

    Write-Host "`nGeneración de hashes completada." -ForegroundColor Cyan
    exit 0
}

# -------------------------------------------------------------
# MODO VERIFY: Valida integridad y paridad cruzada
# -------------------------------------------------------------
$failures = @()
$verifiedCount = 0

Write-Host "`n1. Verificando Contratos Canónicos en Infraestructura..." -ForegroundColor Cyan
foreach ($sc in $canonicalContracts) {
    $cPath = Join-Path $Root $sc.ContractFile
    $sPath = Join-Path $Root $sc.ShaFile

    if (-not (Test-Path $cPath)) {
        $failures += "CONTRATO_FALTANTE: $($sc.ContractFile)"
        continue
    }
    if (-not (Test-Path $sPath)) {
        $failures += "HASH_FALTANTE: $($sc.ShaFile)"
        continue
    }

    $expectedHash = ""
    $firstLine = (Get-Content -Path $sPath -First 1).Trim()
    if ($firstLine -match '^([0-9a-f]{64})') {
        $expectedHash = $matches[1]
    } else {
        $failures += "FORMATO_HASH_INVALIDO: $($sc.ShaFile)"
        continue
    }

    $actualHash = Get-NormalizedSha256 -Path $cPath
    if ($actualHash -ieq $expectedHash) {
        Write-Host "  [OK] $($sc.Name) ($actualHash)" -ForegroundColor Green
        $verifiedCount++
    } else {
        $failures += "HASH_MISMATCH: $($sc.ContractFile) (Esperado: $expectedHash, Calculado: $actualHash)"
        Write-Host "  [FAIL] $($sc.Name)" -ForegroundColor Red
        Write-Host "         Esperado:  $expectedHash" -ForegroundColor DarkRed
        Write-Host "         Calculado: $actualHash" -ForegroundColor DarkYellow
    }

    # Verificación de Paridad Cruzada (Cero Drift con Backend/DB)
    if ($sc.PeerFile) {
        $peerPath = Join-Path $Root $sc.PeerFile
        if (Test-Path $peerPath) {
            $peerHash = Get-NormalizedSha256 -Path $peerPath
            if ($peerHash -ieq $actualHash) {
                Write-Host "       -> [PARIDAD CERO DRIFT] Par idéntico en $($sc.PeerFile)" -ForegroundColor DarkGray
                $verifiedCount++
            } else {
                $failures += "CROSS_REPO_DRIFT: $($sc.ContractFile) diverge de $($sc.PeerFile)"
                Write-Host "       -> [DRIFT DETECTADO] Divergencia entre Infra y $($sc.PeerFile)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n2. Verificando Manifiesto DB Freeze (10 Objetos Consolidados en DB)..." -ForegroundColor Cyan
$fullDbManifestPath = Join-Path $Root $dbManifestRel
if (-not (Test-Path $fullDbManifestPath)) {
    $failures += "MANIFIESTO_DB_FALTANTE: $dbManifestRel"
} else {
    $manifestLines = [System.IO.File]::ReadAllLines($fullDbManifestPath)
    foreach ($mLine in $manifestLines) {
        $trimmed = $mLine.Trim()
        if (-not $trimmed) { continue }
        if ($trimmed -match '^([0-9a-f]{64})\s+(.+)$') {
            $expectedObjHash = $matches[1]
            $objRelPath      = $matches[2]
            $objFullPath     = Join-Path $dbBaseDir $objRelPath

            if (-not (Test-Path $objFullPath)) {
                $failures += "OBJETO_DB_FALTANTE: $objRelPath"
                Write-Host "  [FALTA] $objRelPath" -ForegroundColor Red
                continue
            }

            $actualObjHash = Get-NormalizedSha256 -Path $objFullPath
            if ($actualObjHash -ieq $expectedObjHash) {
                Write-Host "  [OK] $objRelPath" -ForegroundColor Green
                $verifiedCount++
            } else {
                $failures += "DB_OBJ_MISMATCH: $objRelPath (Esperado: $expectedObjHash, Calculado: $actualObjHash)"
                Write-Host "  [FAIL] $objRelPath" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " [PASS] INTEGRIDAD DE CONTRATOS Y PARIDAD VERIFICADAS!    " -ForegroundColor Green
    Write-Host " Total de comprobaciones WORM y paridad exitosas: $verifiedCount" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " [FAIL] SE DETECTARON VIOLACIONES DE CONTRATO O DRIFT:    " -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  • $f" -ForegroundColor Yellow
    }
    Write-Host "`nRegla Constitucional: Los contratos congelados son WORM (Write Once, Read Many)." -ForegroundColor DarkYellow
    Write-Host "Si el cambio fue aprobado intencionalmente, ejecute 'verify-contracts.ps1 -Mode Generate'." -ForegroundColor DarkYellow
    exit 1
}
