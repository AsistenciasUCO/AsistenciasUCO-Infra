<#
.SYNOPSIS
    Escaneo estático de higiene de secretos en todo el repositorio de Asistencias UCO.

.DESCRIPTION
    Inspecciona archivos de código, configuración y scripts buscando credenciales o contraseñas
    quemadas (hardcoded), argumentos CLI inseguros (-P password) o archivos .env versionados.
    
    REGLA DE SEGURIDAD DEVSECOPS:
    Los reportes NUNCA exponen el valor del secreto encontrado; únicamente reportan
    el archivo, línea y el tipo de hallazgo (HARDCODED_PASSWORD_LITERAL, CLI_PASSWORD_ARGUMENT,
    TRACKED_ENV_FILE).

.PARAMETER Root
    Ruta raíz del workspace a escanear. Por defecto: raíz del repositorio.

.PARAMETER SelfCheck
    Ejecuta una prueba sintética interna para verificar la efectividad de detección del escáner.

.EXAMPLE
    .\check-secrets.ps1
    .\check-secrets.ps1 -Root "c:\Proyectos\GestioAsistencia"
    .\check-secrets.ps1 -SelfCheck
#>

[CmdletBinding()]
param(
    [string]$Root = "",
    [switch]$SelfCheck,
    [switch]$InfraOnly
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SecretNameRx = '(?i)(?<![A-Za-z0-9])(MSSQL_SA_PASSWORD|SQL_CONTAINER_PASSWORD|SA_PASSWORD|DB_PASSWORD|DATABASE_PASSWORD|KC_BOOTSTRAP_ADMIN_PASSWORD|KC_DB_PASSWORD|GF_SECURITY_ADMIN_PASSWORD|Password|Pass|Pwd)["'']?\s*[:=]\s*(?<value>.*)$'
$SecretCliRx  = '(?<![A-Za-z0-9])-P\s+(?<value>["'']?[^\s"''$][^\s"'']*)'
$SecretSafeValueRx = '^(?i:(CHANGE[-_]?ME.*|REPLACE[-_]?ME.*|YOUR[-_].*|PLACEHOLDER.*|TEST[-_]ONLY.*|<.*>|\*+|x{3,}|[a-zA-Z0-9_\-]+_SECRET_PLACEHOLDER|[a-zA-Z0-9_\-]+_PASSWORD))$'
$SecretEnvLikeRx   = '(?i)(^\.env(\..+)?$|\.env$|\.properties$|\.ini$|\.cfg$|\.conf$|\.ya?ml$|\.json$)'
$SecretScannableRx = '(?i)(^\.env(\..+)?$|\.env$|\.ps1$|\.psm1$|\.sh$|\.cmd$|\.ya?ml$|\.json$|\.properties$|\.ini$|\.cfg$|\.conf$|\.config$|\.sqlproj$|\.ts$|\.java$)'

function Test-SecretValueIsSafe {
    param([string]$Value, [bool]$WasQuoted)
    $v = $Value.Trim().TrimEnd(',', ';').Trim()
    if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) { 
        $v = $v.Substring(1, $v.Length - 2) 
    } elseif ($v.Length -ge 1 -and ($v[0] -eq '"' -or $v[0] -eq "'")) { 
        $v = $v.Substring(1) 
    }
    if ($v.Length -eq 0) { return $true }
    # Referencias de variables ($env:VAR, ${VAR}, %VAR%, @Value) son seguras
    if ($v[0] -eq '$' -or $v[0] -eq '%' -or $v.StartsWith("@{") -or $v.StartsWith("@Value")) { return $true }
    # Valores de ejemplo o placeholders son seguros
    if ($v -match $SecretSafeValueRx) { return $true }
    return $false
}

function Find-HardcodedSecretsInFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$DisplayName
    )
    if (-not $DisplayName) { $DisplayName = $Path }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    
    $leaf = Split-Path -Leaf $Path
    if ($leaf -eq "check-secrets.ps1") { return @() }

    $envLike = $leaf -match $SecretEnvLikeRx
    $findings = @()
    $lineNo = 0

    try {
        $lines = [System.IO.File]::ReadAllLines($Path)
    } catch {
        return @()
    }

    $inBlockComment = $false
    foreach ($line in $lines) {
        $lineNo++
        $trimmed = $line.Trim()
        
        # Ignorar comentarios de bloque <# ... #> o /* ... */
        if ($trimmed.StartsWith("<#") -or $trimmed.StartsWith("/*")) {
            $inBlockComment = $true
            if ($trimmed.EndsWith("#>") -or $trimmed.EndsWith("*/")) { $inBlockComment = $false }
            continue
        }
        if ($inBlockComment) {
            if ($trimmed.EndsWith("#>") -or $trimmed.EndsWith("*/") -or $trimmed.Contains("#>") -or $trimmed.Contains("*/")) {
                $inBlockComment = $false
            }
            continue
        }

        # Ignorar comentarios de línea
        if ($trimmed.StartsWith("#") -or $trimmed.StartsWith("//") -or $trimmed.StartsWith("--")) {
            continue
        }

        # Detección por nombre de variable/clave
        $m = [regex]::Match($line, $SecretNameRx)
        if ($m.Success) {
            $raw = $m.Groups['value'].Value.Trim()
            $quoted = $raw.StartsWith('"') -or $raw.StartsWith("'")
            if (($quoted -or $envLike) -and -not (Test-SecretValueIsSafe -Value $raw -WasQuoted $quoted)) {
                $findings += [pscustomobject]@{ 
                    File = $DisplayName 
                    Line = $lineNo 
                    Type = 'HARDCODED_PASSWORD_LITERAL' 
                }
                continue
            }
        }

        # Detección por argumento CLI -P <secret>
        $c = [regex]::Match($line, $SecretCliRx)
        if ($c.Success -and -not (Test-SecretValueIsSafe -Value $c.Groups['value'].Value -WasQuoted $false)) {
            $findings += [pscustomobject]@{ 
                File = $DisplayName 
                Line = $lineNo 
                Type = 'CLI_PASSWORD_ARGUMENT' 
            }
        }
    }
    return $findings
}

# --- Modo Self-Check ---
if ($SelfCheck) {
    Write-Host "Ejecutando Self-Check de validación del analizador de secretos..." -ForegroundColor Cyan
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "secret_scanner_selfcheck_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    try {
        $unsafeEnv = Join-Path $tempDir ".env.local"
        $safeEnv   = Join-Path $tempDir ".env.example"
        $unsafePs1 = Join-Path $tempDir "leak.ps1"
        $safePs1   = Join-Path $tempDir "safe.ps1"

        Set-Content -LiteralPath $unsafeEnv -Value "MSSQL_SA_PASSWORD=SuperSecretPass123!" -Encoding ascii
        Set-Content -LiteralPath $safeEnv   -Value "MSSQL_SA_PASSWORD=CHANGE_ME" -Encoding ascii
        Set-Content -LiteralPath $unsafePs1 -Value "`$Password = 'SuperSecretPass123!'" -Encoding ascii
        Set-Content -LiteralPath $safePs1   -Value "`$Password = `$env:MSSQL_SA_PASSWORD" -Encoding ascii

        $fUnsafeEnv = @(Find-HardcodedSecretsInFile -Path $unsafeEnv).Count
        $fSafeEnv   = @(Find-HardcodedSecretsInFile -Path $safeEnv).Count
        $fUnsafePs1 = @(Find-HardcodedSecretsInFile -Path $unsafePs1).Count
        $fSafePs1   = @(Find-HardcodedSecretsInFile -Path $safePs1).Count

        $ok = ($fUnsafeEnv -ge 1) -and ($fSafeEnv -eq 0) -and ($fUnsafePs1 -ge 1) -and ($fSafePs1 -eq 0)
        if ($ok) {
            Write-Host "  [OK] Self-Check superado: detecta secretos inseguros y respeta placeholders/variables." -ForegroundColor Green
            exit 0
        } else {
            Write-Host "  [FAIL] Self-Check fallido: UnsafeEnv=$fUnsafeEnv (esp >=1), SafeEnv=$fSafeEnv (esp 0), UnsafePs1=$fUnsafePs1 (esp >=1), SafePs1=$fSafePs1 (esp 0)" -ForegroundColor Red
            exit 1
        }
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Escaneo Normal ---
if ($InfraOnly) {
    $Root = (Resolve-Path "$PSScriptRoot/../..").Path
} elseif (-not $Root) {
    # Raíz del proyecto (dos niveles arriba de scripts/security)
    $Root = (Resolve-Path "$PSScriptRoot/../../..").Path
} else {
    $Root = (Resolve-Path $Root).Path
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  ESCANEO DE HIGIENE Y BLINDAJE DE SECRETOS (DEVSECOPS)   " -ForegroundColor Cyan
Write-Host "  Directorio Raíz: $Root" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan

$excludedDirs = @(
    "node_modules", ".git", ".angular", "target", "bin", "obj", 
    ".idea", ".vscode", "dist", "build", "coverage", ".claude"
)

$allFiles = @(Get-ChildItem -Path $Root -Recurse -File | Where-Object {
    $path = $_.FullName
    $rel = $path.Substring($Root.Length).TrimStart('\', '/')
    $parts = $rel -split '[\\/]'
    $excluded = $false
    foreach ($p in $parts) {
        if ($excludedDirs -contains $p) { $excluded = $true; break }
    }
    if ($excluded) { return $false }
    return ($_.Name -match $SecretScannableRx)
})

Write-Host "Archivos candidatos a inspección: $($allFiles.Count)" -ForegroundColor DarkGray

$allFindings = @()

foreach ($file in $allFiles) {
    $relPath = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
    
    # 1. Comprobar si hay un archivo .env real versionado o creado en ubicaciones prohibidas
    if ($file.Name -eq ".env") {
        # Si está trackeado en git
        $isGitTracked = $false
        try {
            $gitOut = git -C $Root ls-files -- $relPath 2>$null
            if ($gitOut) { $isGitTracked = $true }
        } catch { }
        
        if ($isGitTracked) {
            $allFindings += [PSCustomObject]@{
                File = $relPath
                Line = 0
                Type = "TRACKED_ENV_FILE"
            }
        } else {
            # Los archivos .env locales no versionados son el almacén legítimo de credenciales de desarrollo
            continue
        }
    }

    # 2. Escanear contenido
    $f = @(Find-HardcodedSecretsInFile -Path $file.FullName -DisplayName $relPath)
    if ($f.Count -gt 0) {
        $allFindings += $f
    }
}

Write-Host ""
if ($allFindings.Count -eq 0) {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " [PASS] ESCANEO LIMPIO: Cero secretos o credenciales expuestas." -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " [ALERTA DEVSECOPS] Se detectaron $($allFindings.Count) posibles fugas de secretos:" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    
    foreach ($finding in $allFindings) {
        Write-Host "  • [HALLAZGO: $($finding.Type)]" -ForegroundColor Yellow -NoNewline
        Write-Host " Archivo: $($finding.File)" -ForegroundColor White -NoNewline
        if ($finding.Line -gt 0) {
            Write-Host " (Línea: $($finding.Line))" -ForegroundColor DarkGray
        } else {
            Write-Host ""
        }
    }
    
    Write-Host ""
    Write-Host "Acción Requerida: Reemplaza las credenciales por referencias a variables de entorno o usa placeholders (ej. CHANGE_ME)." -ForegroundColor Yellow
    exit 1
}
