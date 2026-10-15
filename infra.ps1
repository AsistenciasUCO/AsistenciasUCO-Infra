<#
.SYNOPSIS
    CLI Helper Maestro de Infraestructura y Hardening - Asistencias UCO.

.DESCRIPTION
    Punto de entrada unico y fachada operativa para el ecosistema de Asistencias UCO.
    Permite orquestar contenedores, desplegar base de datos, gestionar identidades Keycloak,
    validar contratos WORM y ejecutar pre-flight checks de seguridad.

.PARAMETER Command
    Comando a ejecutar. Si se omite o es 'help', muestra el panel interactivo.

.EXAMPLE
    .\infra.ps1
    .\infra.ps1 all
    .\infra.ps1 apps
    .\infra.ps1 backend
    .\infra.ps1 frontend
    .\infra.ps1 up
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

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Mandatory = $false)]
    [ValidateSet('core', 'storage', 'observability', 'proxy', 'azure', 'full')]
    [string]$Profile,

    [Parameter(Mandatory = $false)]
    [switch]$SkipSeed,

    [Parameter(Mandatory = $false)]
    [switch]$ContainersOnly,

    [Parameter(Mandatory = $false)]
    [switch]$SkipBackend,

    [Parameter(Mandatory = $false)]
    [switch]$SkipFrontend,

    [Parameter(Mandatory = $false)]
    [string]$Role,

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$Password,

    [Parameter(Mandatory = $false)]
    [switch]$Fix,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPolicyTest,

    [Parameter(Mandatory = $false)]
    [switch]$Volumes,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'

$infraRoot = $PSScriptRoot

function Show-Help {
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host " ASISTENCIAS UCO - INFRAESTRUCTURA & HARDENING CLI (v2.1)" -ForegroundColor Cyan
    Write-Host " Single Source of Truth (SSOT) para DevOps, DevSecOps y Gobernanza Local" -ForegroundColor Gray
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USO:" -ForegroundColor Yellow
    Write-Host "  .\infra.ps1 <comando> [opciones...]" -ForegroundColor White
    Write-Host ""
    Write-Host "1. ORQUESTACION Y ENTORNO LOCAL:" -ForegroundColor Yellow
    Write-Host "  all | dev        Arranca TODO: Contenedores + Despliegue BD + Backend + Frontend." -ForegroundColor White
    Write-Host "                   Opciones: -Profile core|observability|full, -SkipSeed, -ContainersOnly" -ForegroundColor Gray
    Write-Host "  apps             Inicia Backend (Spring Boot) y Frontend (Angular) juntos en consolas." -ForegroundColor White
    Write-Host "  backend          Inicia unicamente la API Backend (Spring Boot en puerto 8080)." -ForegroundColor White
    Write-Host "  frontend         Inicia unicamente la SPA Frontend (Angular en puerto 4200)." -ForegroundColor White
    Write-Host "  up | start       Alias de 'all' (o solo contenedores pasando -ContainersOnly)." -ForegroundColor White
    Write-Host "  down | stop      Detiene limpiamente contenedores y libera puertos 8080/4200." -ForegroundColor White
    Write-Host "                   Opciones: -Volumes (elimina volumenes locales)" -ForegroundColor Gray
    Write-Host "  status           Diagnostico en vivo de puertos TCP 127.0.0.1 y contenedores Docker." -ForegroundColor White
    Write-Host ""
    Write-Host "2. BASE DE DATOS (SQL Server 2022+):" -ForegroundColor Yellow
    Write-Host "  db-deploy        Compila el esquema DDL relacional (tablas, funciones, vistas, SPs)." -ForegroundColor White
    Write-Host "  db-seed          Restablece la semilla limpia institucional (11 usuarios canonicos)." -ForegroundColor White
    Write-Host "  db-test          Ejecuta la suite transaccional de pruebas de BD (test_suite.sql)." -ForegroundColor White
    Write-Host ""
    Write-Host "3. IDENTIDAD Y KEYCLOAK (OIDC / OAuth2):" -ForegroundColor Yellow
    Write-Host "  kc-token         Obtiene un JWT Bearer valido para un rol especifico." -ForegroundColor White
    Write-Host "                   Opciones: -Role Estudiante|Docente|Coordinador|Decano|Administrador" -ForegroundColor Gray
    Write-Host "  kc-diagnose      Audita el endpoint OIDC y la firma de tokens de Keycloak." -ForegroundColor White
    Write-Host "  kc-bootstrap     Reconcilia realm, roles y clientes OAuth2 en Keycloak." -ForegroundColor White
    Write-Host "  kc-seed          Siembra/reestablece los 11 usuarios canonicos en Keycloak." -ForegroundColor White
    Write-Host ""
    Write-Host "4. ALMACENAMIENTO DE OBJETOS (MINIO & CLAMAV):" -ForegroundColor Yellow
    Write-Host "  storage-up       Levanta los servicios de almacenamiento (MinIO S3 API y ClamAV)." -ForegroundColor White
    Write-Host "  storage-down     Detiene los contenedores de almacenamiento (MinIO y ClamAV)." -ForegroundColor White
    Write-Host "  storage-test     Valida la salud de MinIO S3 (port 9000) y politicas de menor privilegio." -ForegroundColor White
    Write-Host ""
    Write-Host "5. CALIDAD, GOBERNANZA Y SEGURIDAD (DEVSECOPS):" -ForegroundColor Yellow
    Write-Host "  verify           Pre-Flight Check integral: Auditoria de Secretos + Contratos WORM." -ForegroundColor White
    Write-Host "  check-secrets    Escanea el repositorio en busca de credenciales o secretos expuestos." -ForegroundColor White
    Write-Host "  verify-contracts Valida firmas SHA-256 de contratos WORM y paridad cross-repo." -ForegroundColor White
    Write-Host "  sync-hus         Sincroniza y cataloga Work Items hacia docs/work-items/INDEX.md." -ForegroundColor White
    Write-Host "  test-backend     Ejecuta el gate de pruebas del Backend (ArchUnit, unitarios)." -ForegroundColor White
    Write-Host "  test-e2e         Ejecuta la suite de pruebas E2E automatizadas para las HUs." -ForegroundColor White
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor DarkGray
    Write-Host " PILARES DEL HARDENING INSTITUCIONAL UCO:" -ForegroundColor Cyan
    Write-Host "  * BD Least-Privilege : Backend conecta como app_asistencias_user (EXEC en SPs, SELECT en Vistas; DENY tablas)." -ForegroundColor Gray
    Write-Host "  * Red Aislada        : Binds forzados exclusivamente a 127.0.0.1 (sin exposicion a redes publicas)." -ForegroundColor Gray
    Write-Host "  * MinIO S3 Stateless : Almacenamiento S3 en loopback (127.0.0.1:9000); MINIO_BROWSER=off; acceso directo Angular PROHIBIDO; escaneo ClamAV obligatorio." -ForegroundColor Gray
    Write-Host "  * Contratos WORM     : Contratos inmutables con hashes SHA-256 adyacentes (cero contract drift)." -ForegroundColor Gray
    Write-Host "  * Higiene Secretos   : Prohibido quemar credenciales; usar .env local y Azure Key Vault / App Config." -ForegroundColor Gray
    Write-Host "  * Reactividad SSE    : Comunicacion en tiempo real via SSE (/api/v1/realtime/stream); PROHIBIDO polling." -ForegroundColor Gray
    Write-Host "==============================================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Invoke-TargetScript {
    param([string]$ScriptPath)
    if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
        & $ScriptPath @RemainingArgs
    } else {
        & $ScriptPath
    }
    exit $LASTEXITCODE
}

# Enrutamiento de subcomandos
switch ($Command.ToLowerInvariant()) {
    { $_ -in "help", "-help", "--help", "-h", "/?" } {
        Show-Help
        exit 0
    }

    { $_ -in "all", "dev", "start-all", "iniciar-todo", "up", "start" } {
        $startDev = Join-Path $infraRoot "scripts\orchestration\start-dev.ps1"
        $splat = @{}
        if ($PSBoundParameters.ContainsKey('Profile') -and -not [string]::IsNullOrWhiteSpace($Profile)) { $splat['Profile'] = $Profile }
        if ($PSBoundParameters.ContainsKey('SkipSeed')) { $splat['SkipSeed'] = $SkipSeed }
        if ($PSBoundParameters.ContainsKey('ContainersOnly')) { $splat['ContainersOnly'] = $ContainersOnly }
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $startDev @splat @RemainingArgs
        } else {
            & $startDev @splat
        }
        exit $LASTEXITCODE
    }

    { $_ -in "down", "stop" } {
        $stopDev = Join-Path $infraRoot "scripts\orchestration\stop-dev.ps1"
        $splat = @{}
        if ($PSBoundParameters.ContainsKey('Profile') -and -not [string]::IsNullOrWhiteSpace($Profile)) { $splat['Profile'] = $Profile }
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $stopDev @splat @RemainingArgs
        } else {
            & $stopDev @splat
        }
        exit $LASTEXITCODE
    }

    "status" {
        Invoke-TargetScript (Join-Path $infraRoot "scripts\orchestration\status-dev.ps1")
    }

    "apps" {
        $startApps = Join-Path $infraRoot "scripts\orchestration\start-apps.ps1"
        $splat = @{}
        if ($PSBoundParameters.ContainsKey('SkipBackend')) { $splat['SkipBackend'] = $SkipBackend }
        if ($PSBoundParameters.ContainsKey('SkipFrontend')) { $splat['SkipFrontend'] = $SkipFrontend }
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $startApps @splat @RemainingArgs
        } else {
            & $startApps @splat
        }
        exit $LASTEXITCODE
    }

    "backend" {
        $startApps = Join-Path $infraRoot "scripts\orchestration\start-apps.ps1"
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $startApps -SkipFrontend @RemainingArgs
        } else {
            & $startApps -SkipFrontend
        }
        exit $LASTEXITCODE
    }

    "frontend" {
        $startApps = Join-Path $infraRoot "scripts\orchestration\start-apps.ps1"
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $startApps -SkipBackend @RemainingArgs
        } else {
            & $startApps -SkipBackend
        }
        exit $LASTEXITCODE
    }

    "db-deploy" {
        Invoke-TargetScript (Join-Path $infraRoot "components\sqlserver\scripts\deploy-schema.ps1")
    }

    "db-seed" {
        Invoke-TargetScript (Join-Path $infraRoot "components\sqlserver\scripts\seed-clean-data.ps1")
    }

    "db-test" {
        Invoke-TargetScript (Join-Path $infraRoot "components\sqlserver\scripts\test-summary.ps1")
    }

    "kc-token" {
        $getToken = Join-Path $infraRoot "components\keycloak\scripts\get-token.ps1"
        $splat = @{}
        $resolvedUser = $Username
        if ([string]::IsNullOrWhiteSpace($resolvedUser) -and -not [string]::IsNullOrWhiteSpace($Role)) {
            $roleLower = $Role.ToLowerInvariant()
            switch -Wildcard ($roleLower) {
                "*docente*"   { $resolvedUser = "docente.prueba" }
                "*admin*"     { $resolvedUser = "admin.prueba" }
                "*estudiant*" { $resolvedUser = "estudiante.prueba" }
                "*coord*"     { $resolvedUser = "coordinador.prueba" }
                "*decan*"     { $resolvedUser = "decano.prueba" }
                default       { $resolvedUser = "$roleLower.prueba" }
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($resolvedUser)) {
            $splat['Username'] = $resolvedUser
        }
        if ($PSBoundParameters.ContainsKey('Password') -and -not [string]::IsNullOrWhiteSpace($Password)) {
            $splat['Password'] = $Password
        }
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $getToken @splat @RemainingArgs
        } else {
            & $getToken @splat
        }
        exit $LASTEXITCODE
    }

    "kc-diagnose" {
        $diag = Join-Path $infraRoot "components\keycloak\scripts\diagnose-token.ps1"
        $splat = @{}
        if ($PSBoundParameters.ContainsKey('Fix')) { $splat['Fix'] = $Fix }
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $diag @splat @RemainingArgs
        } else {
            & $diag @splat
        }
        exit $LASTEXITCODE
    }

    "kc-bootstrap" {
        Invoke-TargetScript (Join-Path $infraRoot "components\keycloak\scripts\bootstrap.ps1")
    }

    "kc-seed" {
        Invoke-TargetScript (Join-Path $infraRoot "components\keycloak\scripts\seed-users.ps1")
    }

    { $_ -in "storage-up", "storage-start", "minio-up" } {
        $startDev = Join-Path $infraRoot "scripts\orchestration\start-dev.ps1"
        & $startDev -Profile storage -ContainersOnly
        exit $LASTEXITCODE
    }

    { $_ -in "storage-down", "storage-stop", "minio-down" } {
        $stopDev = Join-Path $infraRoot "scripts\orchestration\stop-dev.ps1"
        & $stopDev -Profile storage
        exit $LASTEXITCODE
    }

    { $_ -in "storage-test", "minio-test", "test-storage" } {
        $storageTest = Join-Path $infraRoot "scripts\orchestration\test-storage.ps1"
        $splat = @{}
        if ($PSBoundParameters.ContainsKey('SkipPolicyTest')) { $splat['SkipPolicyTest'] = $SkipPolicyTest }
        if ($RemainingArgs -and $RemainingArgs.Length -gt 0) {
            & $storageTest @splat @RemainingArgs
        } else {
            & $storageTest @splat
        }
        exit $LASTEXITCODE
    }

    "verify" {
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host " PRE-FLIGHT CHECK: VERIFICACION INTEGRAL DE HARDENING Y CONTRATOS" -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor Cyan

        Write-Host "`n[1/2] Auditoria de Higiene y Secretos..." -ForegroundColor Yellow
        $secScript = Join-Path $infraRoot "scripts\security\check-secrets.ps1"
        & $secScript -InfraOnly
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Fallo en la verificacion de secretos."
            exit 1
        }

        Write-Host "`n[2/2] Verificacion de Contratos WORM y Paridad Cross-Repo..." -ForegroundColor Yellow
        $contrScript = Join-Path $infraRoot "scripts\quality\verify-contracts.ps1"
        & $contrScript
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Fallo en la verificacion de contratos WORM."
            exit 1
        }

        Write-Host ""
        Write-Host "==============================================================================" -ForegroundColor Green
        Write-Host " [PASS] PRE-FLIGHT CHECK EXITOSO - Ecosistema conforme a estandares UCO!     " -ForegroundColor Green
        Write-Host "==============================================================================" -ForegroundColor Green
        exit 0
    }

    "check-secrets" {
        Invoke-TargetScript (Join-Path $infraRoot "scripts\security\check-secrets.ps1")
    }

    "verify-contracts" {
        Invoke-TargetScript (Join-Path $infraRoot "scripts\quality\verify-contracts.ps1")
    }

    "sync-hus" {
        Invoke-TargetScript (Join-Path $infraRoot "scripts\quality\sync-work-items.ps1")
    }

    "test-backend" {
        Invoke-TargetScript (Join-Path $infraRoot "scripts\quality\test-backend.ps1")
    }

    "test-e2e" {
        Invoke-TargetScript (Join-Path $infraRoot "scripts\quality\test-e2e-hus.ps1")
    }

    default {
        Write-Error "Comando desconocido: '$Command'. Ejecuta '.\infra.ps1 help' para ver los comandos validos."
        exit 1
    }
}
