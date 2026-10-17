<#
.SYNOPSIS
    Mecanismo Switch para alternar de forma segura entre el Keycloak Institucional Propio
    y el stack delegado de Security Baseline (v0.1.6).

.DESCRIPTION
    Actualiza sincrónicamente las configuraciones de entorno de Backend y Frontend:
    - Modo 'own': Keycloak propio (puerto 8081, realm 'asistencias-uco'), PEP deshabilitado.
    - Modo 'baseline': Security Baseline (puerto 19090, realm 'security-baseline'), PEP habilitado (puerto 18081).
    - Modo 'status': Consulta el estado actual de los archivos de configuración sin modificarlos.

.PARAMETER Mode
    Modo objetivo: 'own' (propio/institucional), 'baseline' (delegado/nuevo), o 'status'.

.EXAMPLE
    .\switch-security-mode.ps1 -Mode own
    .\switch-security-mode.ps1 -Mode baseline
    .\switch-security-mode.ps1 -Mode status
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet('own', 'baseline', 'status', 'asistencias', 'delegated')]
    [string]$Mode = 'status'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$infraRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

$backendEnv     = Join-Path $repoRoot "GestioAsistenciaBackend\.env"
$frontendEnvJs  = Join-Path $repoRoot "GestioAsistenciaFrontend\public\assets\env.js"
$frontendEnv    = Join-Path $repoRoot "GestioAsistenciaFrontend\.env"

function Get-CurrentStatus {
    Write-Host "`n==============================================================================" -ForegroundColor Cyan
    Write-Host " ESTADO ACTUAL DEL SWITCH DE SEGURIDAD" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan

    $backendMode = "DESCONOCIDO"
    $frontendMode = "DESCONOCIDO"

    if (Test-Path $backendEnv) {
        $backendContent = Get-Content $backendEnv -Raw
        if ($backendContent -match '(?m)^\s*SECURITY_PEP_ENFORCEMENT_ENABLED\s*=\s*true') {
            $backendMode = "SECURITY BASELINE (Delegado: PEP activo, Keycloak 19090)"
        } elseif ($backendContent -match '(?m)^\s*SECURITY_PEP_ENFORCEMENT_ENABLED\s*=\s*false') {
            $backendMode = "KEYCLOAK PROPIO (Institucional: PEP inactivo, Keycloak 8081)"
        }
    }

    if (Test-Path $frontendEnvJs) {
        $frontendContent = Get-Content $frontendEnvJs -Raw
        if ($frontendContent -match "KEYCLOAK_REALM'\s*\]\s*=\s*'security-baseline'") {
            $frontendMode = "SECURITY BASELINE (Keycloak 19090, realm security-baseline)"
        } elseif ($frontendContent -match "KEYCLOAK_REALM'\s*\]\s*=\s*'asistencias-uco'") {
            $frontendMode = "KEYCLOAK PROPIO (Keycloak 8081, realm asistencias-uco)"
        }
    }

    Write-Host "  * Backend  : $backendMode" -ForegroundColor Yellow
    Write-Host "  * Frontend : $frontendMode" -ForegroundColor Yellow
    Write-Host "==============================================================================`n" -ForegroundColor Cyan
}

if ($Mode -eq 'status') {
    Get-CurrentStatus
    exit 0
}

# Normalizar alias
$targetMode = if ($Mode -in 'own', 'asistencias') { 'own' } else { 'baseline' }

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " APLICANDO SWITCH DE SEGURIDAD -> MODO: $($targetMode.ToUpper())" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

if ($targetMode -eq 'own') {
    Write-Host "`n[1/3] Configurando Backend para Keycloak propio (8081 / asistencias-uco)..." -ForegroundColor Yellow
    if (Test-Path $backendEnv) {
        $content = Get-Content $backendEnv -Raw
        # Reemplazar o asegurar flags
        $content = [System.Text.RegularExpressions.Regex]::Replace($content, 'SECURITY_PEP_ENFORCEMENT_ENABLED\s*=\s*true', 'SECURITY_PEP_ENFORCEMENT_ENABLED=false')
        $content = [System.Text.RegularExpressions.Regex]::Replace($content, 'KEYCLOAK_ISSUER_URI\s*=\s*http://keycloak\.localhost:19090/realms/security-baseline', 'KEYCLOAK_ISSUER_URI=http://localhost:8081/realms/asistencias-uco')
        
        # En caso de que no existiera el flag
        if ($content -notmatch 'SECURITY_PEP_ENFORCEMENT_ENABLED\s*=') {
            $content += "`nSECURITY_PEP_ENFORCEMENT_ENABLED=false"
        }
        if ($content -notmatch 'KEYCLOAK_ISSUER_URI\s*=') {
            $content += "`nKEYCLOAK_ISSUER_URI=http://localhost:8081/realms/asistencias-uco"
        }
        Set-Content -Path $backendEnv -Value $content.Trim() -Encoding utf8
        Write-Host "  -> Backend .env actualizado." -ForegroundColor Green
    }

    Write-Host "`n[2/3] Configurando Frontend env.js para Keycloak propio (8081)..." -ForegroundColor Yellow
    if (Test-Path $frontendEnvJs) {
        $envJsContent = @"
(function (window) {
  window.env = window.env || {};
  window.env['API_URL'] = 'http://localhost:8080/api/v1';
  // Switch de Seguridad: Modo Propio (8081 / asistencias-uco)
  window.env['KEYCLOAK_URL'] = 'http://127.0.0.1:8081';
  window.env['KEYCLOAK_REALM'] = 'asistencias-uco';
  window.env['KEYCLOAK_CLIENT_ID'] = 'asistencias-uco-frontend';
  window.env['USE_MOCKS'] = 'false';
  window.env['SECURITY_BASELINE_ENABLED'] = 'false';
})(this);
"@
        Set-Content -Path $frontendEnvJs -Value $envJsContent.Trim() -Encoding utf8
        Write-Host "  -> Frontend env.js actualizado." -ForegroundColor Green
    }

    Write-Host "`n[3/3] Configurando Frontend .env para Keycloak propio (8081)..." -ForegroundColor Yellow
    if (Test-Path $frontendEnv) {
        $frontEnvContent = @"
API_URL=http://localhost:8080/api/v1
# --- SWITCH DE SEGURIDAD ---
# Modo Activo: Keycloak Propio (Puerto 8081, Realm asistencias-uco)
KEYCLOAK_URL=http://127.0.0.1:8081
KEYCLOAK_REALM=asistencias-uco
KEYCLOAK_CLIENT_ID=asistencias-uco-frontend
SECURITY_BASELINE_ENABLED=false

# Modo Alternativo (Security Baseline v0.1.6 en Standby):
# KEYCLOAK_URL=http://127.0.0.1:19090
# KEYCLOAK_REALM=security-baseline
# SECURITY_BASELINE_ENABLED=true

USE_MOCKS=false
"@
        Set-Content -Path $frontendEnv -Value $frontEnvContent.Trim() -Encoding utf8
        Write-Host "  -> Frontend .env actualizado." -ForegroundColor Green
    }

    Write-Host "`n==============================================================================" -ForegroundColor Green
    Write-Host " [OK] SISTEMA CONFIGURADO EN MODO KEYCLOAK PROPIO" -ForegroundColor Green
    Write-Host "  * Issuer Backend  : http://localhost:8081/realms/asistencias-uco" -ForegroundColor Cyan
    Write-Host "  * PEP Enforcement : DESACTIVADO (false)" -ForegroundColor Cyan
    Write-Host "  * URL Frontend    : http://127.0.0.1:8081" -ForegroundColor Cyan
    Write-Host "  * Realm Frontend  : asistencias-uco" -ForegroundColor Cyan
    Write-Host "  * Clave Unificada : Test1234!" -ForegroundColor Cyan
    Write-Host "  * Nota: Asegurate de tener activo el contenedor Keycloak propio en puerto 8081." -ForegroundColor Yellow
    Write-Host "==============================================================================" -ForegroundColor Green

} else {
    Write-Host "`n[1/3] Configurando Backend para Security Baseline (19090 / 18081)..." -ForegroundColor Yellow
    if (Test-Path $backendEnv) {
        $content = Get-Content $backendEnv -Raw
        $content = [System.Text.RegularExpressions.Regex]::Replace($content, 'SECURITY_PEP_ENFORCEMENT_ENABLED\s*=\s*false', 'SECURITY_PEP_ENFORCEMENT_ENABLED=true')
        $content = [System.Text.RegularExpressions.Regex]::Replace($content, 'KEYCLOAK_ISSUER_URI\s*=\s*http://localhost:8081/realms/asistencias-uco', 'KEYCLOAK_ISSUER_URI=http://keycloak.localhost:19090/realms/security-baseline')
        Set-Content -Path $backendEnv -Value $content.Trim() -Encoding utf8
        Write-Host "  -> Backend .env actualizado." -ForegroundColor Green
    }

    Write-Host "`n[2/3] Configurando Frontend env.js para Security Baseline (19090)..." -ForegroundColor Yellow
    if (Test-Path $frontendEnvJs) {
        $envJsContent = @"
(function (window) {
  window.env = window.env || {};
  window.env['API_URL'] = 'http://localhost:8080/api/v1';
  // Switch de Seguridad: Modo Security Baseline (19090 / security-baseline)
  window.env['KEYCLOAK_URL'] = 'http://127.0.0.1:19090';
  window.env['KEYCLOAK_REALM'] = 'security-baseline';
  window.env['KEYCLOAK_CLIENT_ID'] = 'asistencias-uco-frontend';
  window.env['USE_MOCKS'] = 'false';
  window.env['SECURITY_BASELINE_ENABLED'] = 'true';
})(this);
"@
        Set-Content -Path $frontendEnvJs -Value $envJsContent.Trim() -Encoding utf8
        Write-Host "  -> Frontend env.js actualizado." -ForegroundColor Green
    }

    Write-Host "`n[3/3] Configurando Frontend .env para Security Baseline (19090)..." -ForegroundColor Yellow
    if (Test-Path $frontendEnv) {
        $frontEnvContent = @"
API_URL=http://localhost:8080/api/v1
# --- SWITCH DE SEGURIDAD ---
# Modo Activo: Security Baseline (Keycloak 19090, PEP 18081, Realm security-baseline)
KEYCLOAK_URL=http://127.0.0.1:19090
KEYCLOAK_REALM=security-baseline
KEYCLOAK_CLIENT_ID=asistencias-uco-frontend
SECURITY_BASELINE_ENABLED=true

# Modo Alternativo (Keycloak Propio en Standby):
# KEYCLOAK_URL=http://127.0.0.1:8081
# KEYCLOAK_REALM=asistencias-uco
# SECURITY_BASELINE_ENABLED=false

USE_MOCKS=false
"@
        Set-Content -Path $frontendEnv -Value $frontEnvContent.Trim() -Encoding utf8
        Write-Host "  -> Frontend .env actualizado." -ForegroundColor Green
    }

    Write-Host "`n==============================================================================" -ForegroundColor Green
    Write-Host " [OK] SISTEMA CONFIGURADO EN MODO SECURITY BASELINE" -ForegroundColor Green
    Write-Host "  * Issuer Backend  : http://keycloak.localhost:19090/realms/security-baseline" -ForegroundColor Cyan
    Write-Host "  * PEP Enforcement : ACTIVADO (true en puerto 18081)" -ForegroundColor Cyan
    Write-Host "  * URL Frontend    : http://127.0.0.1:19090" -ForegroundColor Cyan
    Write-Host "  * Realm Frontend  : security-baseline" -ForegroundColor Cyan
    Write-Host "  * Nota: Asegurate de tener activo el stack con '.\infra.ps1 security-up'." -ForegroundColor Yellow
    Write-Host "==============================================================================" -ForegroundColor Green
}
