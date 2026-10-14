<#
.SYNOPSIS
    CLI Helper Maestro de Infraestructura y Hardening - Asistencias UCO.

.DESCRIPTION
    Punto de entrada único y fachada operativa para el ecosistema de Asistencias UCO.
    Permite orquestar contenedores, desplegar base de datos, gestionar identidades Keycloak,
    validar contratos WORM y ejecutar pre-flight checks de seguridad.

.PARAMETER Command
    Comando a ejecutar. Si se omite o es 'help', muestra el panel interactivo.

.EXAMPLE
    .\infra.ps1
    .\infra.ps1 help
    .\infra.ps1 up -Profile core
    .\infra.ps1 down
    .\infra.ps1 status
    .\infra.ps1 db-deploy
    .\infra.ps1 db-seed
    .\infra.ps1 db-test
    .\infra.ps1 kc-token -Role Docente
    .\infra.ps1 kc-diagnose
    .\infra.ps1 verify
    .\infra.ps1 sync-hus
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infraRoot = $PSScriptRoot

function Show-Help {
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "🏛️ ASISTENCIAS UCO - INFRAESTRUCTURA & HARDENING CLI (v2.1)" -ForegroundColor Cyan
    Write-Host "   Single Source of Truth (SSOT) para DevOps, DevSecOps y Gobernanza Local" -ForegroundColor Gray
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USO:" -ForegroundColor Yellow
    Write-Host "  .\infra.ps1 <comando> [opciones...]" -ForegroundColor White
    Write-Host ""
    Write-Host "1. ORQUESTACIÓN Y ENTORNO LOCAL:" -ForegroundColor Yellow
    Write-Host "  up | start       Inicia contenedores con Docker Compose y healthchecks." -ForegroundColor White
    Write-Host "                   Opciones: -Profile core|observability|proxy|azure|full, -ContainersOnly, -SkipSeed" -ForegroundColor Gray
    Write-Host "  down | stop      Detiene limpiamente contenedores y libera puertos 8080/4200." -ForegroundColor White
    Write-Host "                   Opciones: -Volumes (elimina volúmenes locales)" -ForegroundColor Gray
    Write-Host "  status           Diagnóstico en vivo de puertos TCP 127.0.0.1 y contenedores Docker." -ForegroundColor White
    Write-Host "  apps             Inicia Backend (Spring Boot) y Frontend (Angular) en consolas." -ForegroundColor White
    Write-Host ""
    Write-Host "2. BASE DE DATOS (SQL Server 2022+):" -ForegroundColor Yellow
    Write-Host "  db-deploy        Compila el esquema DDL relacional (tablas, funciones, vistas, SPs)." -ForegroundColor White
    Write-Host "  db-seed          Restablece la semilla limpia institucional (11 usuarios canónicos)." -ForegroundColor White
    Write-Host "  db-test          Ejecuta la suite transaccional de pruebas de BD (test_suite.sql)." -ForegroundColor White
    Write-Host ""
    Write-Host "3. IDENTIDAD Y KEYCLOAK (OIDC / OAuth2):" -ForegroundColor Yellow
    Write-Host "  kc-token         Obtiene un JWT Bearer válido para un rol específico." -ForegroundColor White
    Write-Host "                   Opciones: -Role Estudiante|Docente|Coordinador|Decano|Administrador" -ForegroundColor Gray
    Write-Host "  kc-diagnose      Audita el endpoint OIDC y la firma de tokens de Keycloak." -ForegroundColor White
    Write-Host "  kc-bootstrap     Reconcilia realm, roles y clientes OAuth2 en Keycloak." -ForegroundColor White
    Write-Host "  kc-seed          Siembra/reestablece los 11 usuarios canónicos en Keycloak." -ForegroundColor White
    Write-Host ""
    Write-Host "4. CALIDAD, GOBERNANZA Y SEGURIDAD (DEVSECOPS):" -ForegroundColor Yellow
    Write-Host "  verify           Pre-Flight Check integral: Auditoría de Secretos + Contratos WORM." -ForegroundColor White
    Write-Host "  check-secrets    Escanea el repositorio en busca de credenciales o secretos expuestos." -ForegroundColor White
    Write-Host "  verify-contracts Valida firmas SHA-256 de contratos WORM y paridad cross-repo." -ForegroundColor White
    Write-Host "  sync-hus         Sincroniza y cataloga Work Items hacia docs/work-items/INDEX.md." -ForegroundColor White
    Write-Host "  test-backend     Ejecuta el gate de pruebas del Backend (ArchUnit, unitarios)." -ForegroundColor White
    Write-Host "  test-e2e         Ejecuta la suite de pruebas E2E automatizadas para las HUs." -ForegroundColor White
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor DarkGray
    Write-Host "🛡️ PILARES DEL HARDENING INSTITUCIONAL UCO:" -ForegroundColor Cyan
    Write-Host "  • BD Least-Privilege : Backend conecta como 'app_asistencias_user' (EXEC en SPs, SELECT en Vistas; DENY tablas)." -ForegroundColor Gray
    Write-Host "  • Red Aislada        : Binds forzados exclusivamente a 127.0.0.1 (sin exposición a redes Wi-Fi abiertas)." -ForegroundColor Gray
    Write-Host "  • Contratos WORM     : Contratos inmutables con hashes SHA-256 adyacentes (prohibido contract drift)." -ForegroundColor Gray
    Write-Host "  • Higiene Secretos   : Prohibido hardcodear credenciales; usar .env local y Azure Key Vault / App Config." -ForegroundColor Gray
    Write-Host "  • Reactividad SSE    : Comunicación en tiempo real vía SSE (/api/v1/realtime/stream); PROHIBIDO polling." -ForegroundColor Gray
    Write-Host "==============================================================================" -ForegroundColor DarkGray
    Write-Host ""
}

# Enrutamiento de subcomandos
switch ($Command.ToLowerInvariant()) {
    { $_ -in "help", "-help", "--help", "-h", "/?" } {
        Show-Help
        exit 0
    }

    { $_ -in "up", "start" } {
        $target = Join-Path $infraRoot "scripts\orchestration\start-dev.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    { $_ -in "down", "stop" } {
        $target = Join-Path $infraRoot "scripts\orchestration\stop-dev.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "status" {
        $target = Join-Path $infraRoot "scripts\orchestration\status-dev.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "apps" {
        $target = Join-Path $infraRoot "scripts\orchestration\start-apps.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "db-deploy" {
        $target = Join-Path $infraRoot "components\sqlserver\scripts\deploy-schema.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "db-seed" {
        $target = Join-Path $infraRoot "components\sqlserver\scripts\seed-clean-data.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "db-test" {
        $target = Join-Path $infraRoot "components\sqlserver\scripts\test-summary.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "kc-token" {
        $target = Join-Path $infraRoot "components\keycloak\scripts\get-token.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "kc-diagnose" {
        $target = Join-Path $infraRoot "components\keycloak\scripts\diagnose-token.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "kc-bootstrap" {
        $target = Join-Path $infraRoot "components\keycloak\scripts\bootstrap.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "kc-seed" {
        $target = Join-Path $infraRoot "components\keycloak\scripts\seed-users.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "verify" {
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "🛡️ PRE-FLIGHT CHECK: VERIFICACIÓN INTEGRAL DE HARDENING Y CONTRATOS" -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor Cyan

        Write-Host "`n[1/2] Auditoría de Higiene y Secretos..." -ForegroundColor Yellow
        $secScript = Join-Path $infraRoot "scripts\security\check-secrets.ps1"
        & $secScript -InfraOnly
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Fallo en la verificación de secretos."
            exit 1
        }

        Write-Host "`n[2/2] Verificación de Contratos WORM y Paridad Cross-Repo..." -ForegroundColor Yellow
        $contrScript = Join-Path $infraRoot "scripts\quality\verify-contracts.ps1"
        & $contrScript
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Fallo en la verificación de contratos WORM."
            exit 1
        }

        Write-Host ""
        Write-Host "==============================================================================" -ForegroundColor Green
        Write-Host " [PASS] PRE-FLIGHT CHECK EXITOSO - Ecosistema conforme a estándares UCO!     " -ForegroundColor Green
        Write-Host "==============================================================================" -ForegroundColor Green
        exit 0
    }

    "check-secrets" {
        $target = Join-Path $infraRoot "scripts\security\check-secrets.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "verify-contracts" {
        $target = Join-Path $infraRoot "scripts\quality\verify-contracts.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "sync-hus" {
        $target = Join-Path $infraRoot "scripts\quality\sync-work-items.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "test-backend" {
        $target = Join-Path $infraRoot "scripts\quality\test-backend.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    "test-e2e" {
        $target = Join-Path $infraRoot "scripts\quality\test-e2e-hus.ps1"
        & $target @RemainingArgs
        exit $LASTEXITCODE
    }

    default {
        Write-Error "Comando desconocido: '$Command'. Ejecuta '.\infra.ps1 help' para ver los comandos válidos."
        exit 1
    }
}
