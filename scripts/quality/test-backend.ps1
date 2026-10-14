<#
.SYNOPSIS
    Ejecutor centralizado de pruebas y Quality Gates para Backend (Spring Boot 4 / Java 25).

.DESCRIPTION
    Ejecuta las pruebas unitarias, de arquitectura (ArchUnit), de integración o verificación
    completa con JaCoCo en GestioAsistenciaBackend, cargando previamente las variables de entorno.

.PARAMETER Profile
    'Unit' (por defecto): Ejecuta pruebas unitarias y reglas ArchUnit (.\mvnw.cmd test).
    'Integration': Ejecuta pruebas de integración contra la base de datos (.\mvnw.cmd verify -Pintegration).
    'Verify': Ejecuta ciclo completo de compilación, tests y Quality Gates JaCoCo (.\mvnw.cmd verify).

.PARAMETER BackendDir
    Ruta a la carpeta de GestioAsistenciaBackend.

.EXAMPLE
    .\test-backend.ps1
    .\test-backend.ps1 -Profile Integration
    .\test-backend.ps1 -Profile Verify
#>

[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Verify')]
    [string]$Profile = 'Unit',

    [string]$BackendDir = "$PSScriptRoot/../../../GestioAsistenciaBackend"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Cargar variables de entorno
$loadEnvScript = Join-Path $PSScriptRoot "..\orchestration\load-env.ps1"
if (Test-Path $loadEnvScript) {
    . $loadEnvScript
}

$resolvedBackendDir = Resolve-Path $BackendDir -ErrorAction SilentlyContinue
if (-not $resolvedBackendDir -or -not (Test-Path $resolvedBackendDir)) {
    throw "No se encontró el directorio de Backend en: $BackendDir"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  EJECUTOR DE PRUEBAS BACKEND (SPRING BOOT / JAVA 25)    " -ForegroundColor Cyan
Write-Host "  Perfil: $Profile | Directorio: $resolvedBackendDir" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan

$mvnw = Join-Path $resolvedBackendDir "mvnw.cmd"
if (-not (Test-Path $mvnw)) {
    $mvnw = "mvn"
}

# 2. Validar variables mínimas si es integración
if ($Profile -eq 'Integration') {
    $requiredVars = @("SPRING_DATASOURCE_URL", "SPRING_DATASOURCE_USERNAME", "SPRING_DATASOURCE_PASSWORD")
    foreach ($v in $requiredVars) {
        $val = [Environment]::GetEnvironmentVariable($v, "Process")
        if ([string]::IsNullOrWhiteSpace($val)) {
            Write-Host "[ADVERTENCIA] La variable '$v' no está definida. Se usarán valores por defecto o del application.yml." -ForegroundColor Yellow
        }
    }
}

# 3. Determinar argumentos Maven
$mvnArgs = @()
switch ($Profile) {
    'Unit' {
        $mvnArgs = @("test")
    }
    'Integration' {
        $mvnArgs = @("verify", "-Pintegration")
    }
    'Verify' {
        $mvnArgs = @("verify")
    }
}

Write-Host "Ejecutando: $mvnw $($mvnArgs -join ' ')...`n" -ForegroundColor DarkGray

$originalLocation = Get-Location
try {
    Set-Location $resolvedBackendDir
    & $mvnw @mvnArgs
    $exitCode = $LASTEXITCODE

    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "==========================================================" -ForegroundColor Green
        Write-Host " [PASS] PRUEBAS DE BACKEND COMPLETADAS CON EXITO ($Profile)" -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "==========================================================" -ForegroundColor Red
        Write-Host " [FAIL] PRUEBAS DE BACKEND FALLARON (Exit Code: $exitCode)" -ForegroundColor Red
        Write-Host "==========================================================" -ForegroundColor Red
        exit $exitCode
    }
} finally {
    Set-Location $originalLocation
}
