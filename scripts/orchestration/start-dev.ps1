<#
.SYNOPSIS
    Orquestador maestro del ecosistema de desarrollo de Asistencias UCO.

.DESCRIPTION
    1. Carga variables de entorno unificadas via load-env.ps1.
    2. Levanta los contenedores Docker segun el perfil seleccionado (-Profile core por defecto).
    3. Espera activamente los healthchecks de SQL Server y Keycloak.
    4. Compila el esquema relacional en SQL Server (deploy-schema.ps1).
    5. Restablece la semilla canonica limpia (seed-clean-data.ps1) a menos que se use -SkipSeed.
    6. Reconcilia el realm de Keycloak (bootstrap.ps1) y siembra usuarios (seed-users.ps1).
    7. Inicia Backend y Frontend en consolas independientes salvo si se pasa -ContainersOnly.

.PARAMETER Profile
    Perfil de Docker Compose a levantar: 'core' (default: solo SQL Server + Keycloak),
    'observability' (OTel + Prometheus + Grafana), 'azure', 'proxy', o 'full'.

.PARAMETER SkipSeed
    Omitir el restablecimiento de datos de prueba en BD y Keycloak.

.PARAMETER ContainersOnly
    Levantar unicamente los contenedores de infraestructura sin lanzar Backend ni Frontend.

.EXAMPLE
    .\start-dev.ps1
    .\start-dev.ps1 -Profile full
    .\start-dev.ps1 -ContainersOnly
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet('core', 'storage', 'observability', 'proxy', 'azure', 'security', 'full')]
    [string]$Profile = 'core',

    [Parameter(Mandatory = $false)]
    [switch]$SkipSeed,

    [Parameter(Mandatory = $false)]
    [switch]$ContainersOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infraDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$composeFile = Join-Path $infraDir "docker-compose.yml"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " ASISTENCIAS UCO - ORQUESTADOR MAESTRO DE DESARROLLO" -ForegroundColor Cyan
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
        throw "Docker Desktop no esta corriendo. Inicialo antes de continuar."
    }
} catch {
    throw "Docker no esta disponible o no responde. Verifica que el servicio este activo."
}
Write-Host "  -> Docker Engine activo y respondiendo." -ForegroundColor Green

# 2.1 Verificar colision previa en puerto 1433
$sqlContainer = if ($env:SQL_CONTAINER_NAME) { $env:SQL_CONTAINER_NAME } else { "sql_server_asistencias" }
try {
    $conn1433 = Get-NetTCPConnection -LocalPort 1433 -State Listen -ErrorAction SilentlyContinue
    if ($conn1433) {
        $runningContainers = docker ps --filter "name=$sqlContainer" --format "{{.Names}}" 2>$null
        if ($runningContainers -notcontains $sqlContainer) {
            $pids = ($conn1433.OwningProcess | Select-Object -Unique) -join ', '
            Write-Warning "[COLISION EN PUERTO 1433] El puerto 1433 ya esta en uso por PID(s): $pids, pero el contenedor '$sqlContainer' no esta activo."
            Write-Warning "   Si tienes una instancia local de SQL Server de Windows o un contenedor previo, detenlo para evitar fallos de enlace."
        }
    }
} catch {
    # Continuar si Get-NetTCPConnection no tiene permisos suficientes
}

# 3. Levantar Contenedores Docker con el Perfil seleccionado
Write-Host "`n[PASO 3/5] Verificando y levantando contenedores (Perfil: $Profile)..." -ForegroundColor Yellow

$sqlContainer = if ($env:SQL_CONTAINER_NAME) { $env:SQL_CONTAINER_NAME } else { "sql_server_asistencias" }
$sqlExisting = (docker ps -a --filter "name=^/${sqlContainer}$" --format "{{.Status}}" 2>$null)

if ($sqlExisting) {
    if ($sqlExisting -match "^Up") {
        Write-Host "  -> Contenedor SQL Server '$sqlContainer' ya esta en ejecucion." -ForegroundColor Green
    } else {
        Write-Host "  -> Iniciando contenedor existente SQL Server '$sqlContainer'..." -ForegroundColor Yellow
        docker start $sqlContainer > $null 2>&1
        Write-Host "  -> [OK] Contenedor '$sqlContainer' iniciado." -ForegroundColor Green
    }
} else {
    Write-Host "  -> Creando contenedor SQL Server con Docker Compose..." -ForegroundColor Yellow
    docker compose -f "$composeFile" up -d sqlserver
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo al crear el contenedor SQL Server con Docker Compose."
    }
}

# Comprobar y levantar contenedor Keycloak si ya existe
$kcCandidateContainers = @("keycloak_asistencias", "asistencias-uco-security-keycloak-1")
$kcFound = $false
foreach ($kcName in $kcCandidateContainers) {
    $kcStatus = (docker ps -a --filter "name=^/${kcName}$" --format "{{.Status}}" 2>$null)
    if ($kcStatus) {
        $kcFound = $true
        # Si tiene un postgres asociado, levantarlo tambien
        $dbCandidates = @("${kcName}-db-1", "${kcName}_db", "asistencias-uco-security-keycloak-db-1", "keycloak_db_asistencias")
        foreach ($dbName in $dbCandidates) {
            $dbStatus = (docker ps -a --filter "name=^/${dbName}$" --format "{{.Status}}" 2>$null)
            if ($dbStatus -and $dbStatus -notmatch "^Up") {
                docker start $dbName > $null 2>&1
            }
        }

        if ($kcStatus -match "^Up") {
            Write-Host "  -> Contenedor Keycloak '$kcName' ya esta en ejecucion." -ForegroundColor Green
        } else {
            Write-Host "  -> Iniciando contenedor Keycloak existente '$kcName'..." -ForegroundColor Yellow
            docker start $kcName > $null 2>&1
            Write-Host "  -> [OK] Contenedor Keycloak '$kcName' iniciado." -ForegroundColor Green
        }
        $env:KEYCLOAK_CONTAINER_NAME = $kcName
        break
    }
}

if (-not $kcFound -and ($Profile -eq 'core' -or $Profile -eq 'full')) {
    Write-Host "  -> Levantando Keycloak con Docker Compose..." -ForegroundColor Gray
    docker compose -f "$composeFile" up -d keycloak 2>$null
}

# Comprobar y levantar contenedor MinIO si existe
$minioCandidateContainers = @("asistencias-files-minio-1", "minio_asistencias", "minio")
foreach ($mName in $minioCandidateContainers) {
    $mStatus = (docker ps -a --filter "name=^/${mName}$" --format "{{.Status}}" 2>$null)
    if ($mStatus) {
        if ($mStatus -match "^Up") {
            Write-Host "  -> Contenedor MinIO '$mName' ya esta en ejecucion." -ForegroundColor Green
        } else {
            Write-Host "  -> Iniciando contenedor MinIO existente '$mName'..." -ForegroundColor Yellow
            docker start $mName > $null 2>&1
            Write-Host "  -> [OK] Contenedor MinIO '$mName' iniciado." -ForegroundColor Green
        }
        break
    }
}

# Comprobar y levantar contenedor ClamAV si existe
$clamavCandidateContainers = @("asistencias-files-clamav-1", "clamav_asistencias", "clamav")
foreach ($cName in $clamavCandidateContainers) {
    $cStatus = (docker ps -a --filter "name=^/${cName}$" --format "{{.Status}}" 2>$null)
    if ($cStatus -and $cStatus -notmatch "^Up") {
        Write-Host "  -> Iniciando contenedor ClamAV existente '$cName'..." -ForegroundColor Yellow
        docker start $cName > $null 2>&1
        Write-Host "  -> [OK] Contenedor ClamAV '$cName' iniciado." -ForegroundColor Green
        break
    }
}

# Levantar otros servicios del perfil si aplica (ej. storage, observability)
if ($Profile -eq 'storage' -or $Profile -eq 'observability' -or $Profile -eq 'full') {
    docker compose -f "$composeFile" --profile "$Profile" up -d 2>$null
}

# Levantar plataforma de seguridad si se especifica el perfil 'security' o 'full'
if ($Profile -eq 'security' -or $Profile -eq 'full') {
    $secScript = Join-Path $infraDir "components\security\start-security.ps1"
    if (Test-Path $secScript) {
        Write-Host "`n  -> [PERFIL SEGURIDAD] Iniciando plataforma de seguridad (PDP, PEP, SurrealDB, OPA)..." -ForegroundColor Yellow
        & $secScript
    }
}

# 4. Esperar Healthcheck real de SQL Server
$sqlPassword = if ($env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD } else { "TuPasswordSeguro123" }

Write-Host "  -> Esperando conexion a SQL Server ($sqlContainer)..." -NoNewline -ForegroundColor Gray
$maxTries = 25
$tries = 0
$sqlReady = $false
while (-not $sqlReady -and $tries -lt $maxTries) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    cmd /c "docker exec $sqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P ""$sqlPassword"" -C -Q ""SELECT 1"" >nul 2>&1"
    $code = $LASTEXITCODE
    $ErrorActionPreference = $eap
    if ($code -eq 0) {
        $sqlReady = $true
        Write-Host " [CONECTADO]" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 2
        $tries++
    }
}
if (-not $sqlReady) {
    throw "SQL Server no respondio a tiempo. Revisa los logs con: docker logs $sqlContainer"
}

# 5. Esperar Healthcheck de Keycloak
$kcContainer = if ($env:KEYCLOAK_CONTAINER_NAME) { $env:KEYCLOAK_CONTAINER_NAME } else { "keycloak_asistencias" }
Write-Host "  -> Esperando que Keycloak ($kcContainer) este listo..." -NoNewline -ForegroundColor Gray
$tries = 0
$kcReady = $false
while (-not $kcReady -and $tries -lt 20) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $health = (docker inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" $kcContainer 2>$null)
    $hasHealthCheck = (docker inspect --format "{{if .State.Health}}yes{{else}}no{{end}}" $kcContainer 2>$null)
    $ErrorActionPreference = $eap

    if ($health -eq "healthy" -or ($health -eq "running" -and $hasHealthCheck -eq "no")) {
        $kcReady = $true
        Write-Host " [CONECTADO]" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 2
        $tries++
    }
}
if (-not $kcReady) {
    Write-Host "`n  -> [AVISO] Keycloak listo o continuando aprovisionamiento..." -ForegroundColor DarkYellow
}

# 5.1 Verificar disponibilidad de MinIO S3
Write-Host "  -> Verificando servicio MinIO (127.0.0.1:9000)..." -NoNewline -ForegroundColor Gray
$minioReady = $false
try {
    $mResp = Invoke-WebRequest -Uri "http://127.0.0.1:9000/minio/health/live" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($mResp -and $mResp.StatusCode -eq 200) {
        $minioReady = $true
        Write-Host " [CONECTADO - BROWSER OFF]" -ForegroundColor Green
    }
} catch {}
if (-not $minioReady) {
    Write-Host " [NO DISPONIBLE]" -ForegroundColor DarkGray
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
Write-Host "[OK] ECOSISTEMA ASISTENCIAS UCO INICIADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "  * SQL Server 2022  : 127.0.0.1:1433 (sa / app_asistencias_user)" -ForegroundColor Cyan
Write-Host "  * Keycloak IAM     : http://127.0.0.1:8081 (Consola: /admin)" -ForegroundColor Cyan
if ($minioReady) {
    Write-Host "  * MinIO S3 Storage : http://127.0.0.1:9000 (Bucket: asistencias-soportes | Console: OFF)" -ForegroundColor Cyan
    Write-Host "  * ClamAV Antivirus : 127.0.0.1:3310 (clamd daemon)" -ForegroundColor Cyan
}
if ($Profile -eq 'observability' -or $Profile -eq 'full') {
    Write-Host "  * Grafana Metrics  : http://127.0.0.1:3000 (admin / admin123)" -ForegroundColor Cyan
    Write-Host "  * Prometheus Scrape: http://127.0.0.1:9090" -ForegroundColor Cyan
}
Write-Host "==============================================================================" -ForegroundColor Green
