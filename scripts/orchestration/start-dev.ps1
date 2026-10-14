<#
.SYNOPSIS
    Orquestador maestro del ecosistema de desarrollo de Asistencias UCO.

.DESCRIPTION
    1. Carga variables de entorno unificadas vía load-env.ps1.
    2. Levanta los contenedores Docker según el perfil seleccionado (-Profile core por defecto).
    3. Espera activamente los healthchecks de SQL Server y Keycloak.
    4. Compila el esquema relacional en SQL Server (deploy-schema.ps1).
    5. Restablece la semilla canónica limpia (seed-clean-data.ps1) a menos que se use -SkipSeed.
    6. Reconcilia el realm de Keycloak (bootstrap.ps1) y siembra usuarios (seed-users.ps1).
    7. Inicia Backend y Frontend en consolas independientes salvo si se pasa -ContainersOnly.

.PARAMETER Profile
    Perfil de Docker Compose a levantar: 'core' (default: solo SQL Server + Keycloak),
    'observability' (OTel + Prometheus + Grafana), 'azure', 'proxy', o 'full'.

.PARAMETER SkipSeed
    Omitir el restablecimiento de datos de prueba en BD y Keycloak.

.PARAMETER ContainersOnly
    Levantar únicamente los contenedores de infraestructura sin lanzar Backend ni Frontend.

.EXAMPLE
    .\start-dev.ps1
    .\start-dev.ps1 -Profile full
    .\start-dev.ps1 -ContainersOnly
#>

[CmdletBinding()]
param(
    [ValidateSet('core', 'observability', 'proxy', 'azure', 'full')][string]$Profile = 'core',
    [switch]$SkipSeed,
    [switch]$ContainersOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infraDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$composeFile = Join-Path $infraDir "docker-compose.yml"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - ORQUESTADOR MAESTRO DE DESARROLLO" -ForegroundColor Cyan
Write-Host "Perfil Seleccionado : $Profile" -ForegroundColor Yellow
Write-Host "Modo Contenedores   : $(if ($ContainersOnly) { 'Solo Infraestructura' } else { 'Stack Completo (Infra + Apps)' })" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# 1. Cargar variables de entorno
Write-Host "`n[PASO 1/5] Cargando variables de entorno..." -ForegroundColor Yellow
$loadEnvScript = Join-Path $PSScriptRoot "load-env.ps1"
if (Test-Path $loadEnvScript) {
    . $loadEnvScript
}

# 2. Verificar disponibilidad de Docker Desktop
Write-Host "`n[PASO 2/5] Verificando Docker Engine..." -ForegroundColor Yellow
try {
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Desktop no está corriendo. Inícialo antes de continuar."
    }
} catch {
    throw "Docker no está disponible o no responde. Verifica que el servicio esté activo."
}
Write-Host "  -> Docker Engine activo y respondiendo." -ForegroundColor Green

# 2.1 Verificar colisión previa en puerto 1433
$sqlContainer = if ($env:SQL_CONTAINER_NAME) { $env:SQL_CONTAINER_NAME } else { "sql_server_asistencias" }
try {
    $conn1433 = Get-NetTCPConnection -LocalPort 1433 -State Listen -ErrorAction SilentlyContinue
    if ($conn1433) {
        $runningContainers = docker ps --filter "name=$sqlContainer" --format "{{.Names}}" 2>$null
        if ($runningContainers -notcontains $sqlContainer) {
            $pids = ($conn1433.OwningProcess | Select-Object -Unique) -join ', '
            Write-Warning "⚠️ [COLISIÓN EN PUERTO 1433] El puerto 1433 ya está en uso por PID(s): $pids, pero el contenedor '$sqlContainer' no está activo."
            Write-Warning "   Si tienes una instancia local de SQL Server de Windows o un contenedor previo, deténlo para evitar fallos de enlace."
        }
    }
} catch {
    # Continuar si Get-NetTCPConnection no tiene permisos suficientes
}

# 3. Levantar Contenedores Docker con el Perfil seleccionado
Write-Host "`n[PASO 3/5] Levantando contenedores (Perfil: $Profile)..." -ForegroundColor Yellow
docker compose -f "$composeFile" --profile "$Profile" up -d
if ($LASTEXITCODE -ne 0) {
    throw "Fallo al ejecutar 'docker compose up' para el perfil $Profile."
}

# 4. Esperar Healthcheck real de SQL Server
$sqlContainer = if ($env:SQL_CONTAINER_NAME) { $env:SQL_CONTAINER_NAME } else { "sql_server_asistencias" }
$sqlPassword  = if ($env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD } else { "TuPasswordSeguro123" }

Write-Host "  -> Esperando conexión a SQL Server ($sqlContainer)..." -NoNewline -ForegroundColor Gray
$maxTries = 25
$tries = 0
$sqlReady = $false
while (-not $sqlReady -and $tries -lt $maxTries) {
    docker exec $sqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$sqlPassword" -C -Q "SELECT 1" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        $sqlReady = $true
        Write-Host " [CONECTADO]" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 2
        $tries++
    }
}
if (-not $sqlReady) {
    throw "SQL Server no respondió a tiempo. Revisa los logs con: docker logs $sqlContainer"
}

# 5. Esperar Healthcheck de Keycloak
$kcContainer = if ($env:KEYCLOAK_CONTAINER_NAME) { $env:KEYCLOAK_CONTAINER_NAME } else { "keycloak_asistencias" }
Write-Host "  -> Esperando que Keycloak ($kcContainer) esté listo..." -NoNewline -ForegroundColor Gray
$tries = 0
$kcReady = $false
while (-not $kcReady -and $tries -lt $maxTries) {
    docker exec $kcContainer bash -c "exec 3<>/dev/tcp/127.0.0.1/9000" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        $kcReady = $true
        Write-Host " [CONECTADO]" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 3
        $tries++
    }
}
if (-not $kcReady) {
    Write-Host "`n  -> [AVISO] Keycloak está tardando en responder. Continuando con el aprovisionamiento..." -ForegroundColor DarkYellow
}

# 6. Despliegue de Esquema y Siembra en SQL Server
Write-Host "`n[PASO 4/5] Aprovisionando Base de Datos e IAM..." -ForegroundColor Yellow
$deploySchemaScript = Join-Path $infraDir "components\sqlserver\scripts\deploy-schema.ps1"
if (Test-Path $deploySchemaScript) {
    Write-Host "  -> Ejecutando deploy-schema.ps1..." -ForegroundColor Gray
    & $deploySchemaScript
}

if (-not $SkipSeed) {
    $seedDbScript = Join-Path $infraDir "components\sqlserver\scripts\seed-clean-data.ps1"
    if (Test-Path $seedDbScript) {
        Write-Host "  -> Ejecutando seed-clean-data.ps1..." -ForegroundColor Gray
        & $seedDbScript
    }
}

# 7. Bootstrap y Siembra en Keycloak
$bootstrapKcScript = Join-Path $infraDir "components\keycloak\scripts\bootstrap.ps1"
if (Test-Path $bootstrapKcScript) {
    Write-Host "  -> Ejecutando bootstrap de Keycloak..." -ForegroundColor Gray
    try {
        & $bootstrapKcScript
    } catch {
        Write-Host "  -> Aviso en bootstrap de Keycloak: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $SkipSeed) {
    $seedKcScript = Join-Path $infraDir "components\keycloak\scripts\seed-users.ps1"
    if (Test-Path $seedKcScript) {
        Write-Host "  -> Sembrando usuarios institucionales en Keycloak..." -ForegroundColor Gray
        try {
            & $seedKcScript
        } catch {
            Write-Host "  -> Aviso en seed de Keycloak: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# 8. Iniciar Aplicaciones Backend y Frontend si corresponde
if (-not $ContainersOnly) {
    Write-Host "`n[PASO 5/5] Iniciando Backend y Frontend..." -ForegroundColor Yellow
    $startAppsScript = Join-Path $PSScriptRoot "start-apps.ps1"
    if (Test-Path $startAppsScript) {
        & $startAppsScript
    }
} else {
    Write-Host "`n[PASO 5/5] Omitiendo inicio de aplicaciones (-ContainersOnly activo)." -ForegroundColor Gray
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host "✅ ECOSISTEMA ASISTENCIAS UCO INICIADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "  • SQL Server 2022  : 127.0.0.1:1433 (sa / app_asistencias_user)" -ForegroundColor Cyan
Write-Host "  • Keycloak IAM     : http://127.0.0.1:8081 (Consola: /admin)" -ForegroundColor Cyan
if ($Profile -eq 'observability' -or $Profile -eq 'full') {
    Write-Host "  • Grafana Metrics  : http://127.0.0.1:3000 (admin / admin123)" -ForegroundColor Cyan
    Write-Host "  • Prometheus Scrape: http://127.0.0.1:9090" -ForegroundColor Cyan
}
Write-Host "==============================================================================" -ForegroundColor Green
