<#
.SYNOPSIS
    Constructor y Validador Canónico de Variables de Entorno - Asistencias UCO.
.DESCRIPTION
    Punto de entrada único (SSOT) para construir, sincronizar y validar atómicamente todos
    los archivos de configuración de entorno (.env y env.js) en las 3 capas del ecosistema:
    - Infraestructura & Docker: AsistenciasUCO-Infra/.env
    - Backend Spring Boot: GestioAsistenciaBackend/.env y infra/files/.env
    - Frontend Angular: GestioAsistenciaFrontend/.env, public/assets/env.js, src/assets/env.js
    - Base de Datos: GestioAsistenciaDB/.env

    Previene de forma definitiva la deriva de configuración (configuration drift),
    conflictos de puertos, URLs desalineadas y exposiciones accidentales de secretos.

.PARAMETER Profile
    Perfil de despliegue: 'local' (host 127.0.0.1, IDEs y Docker loopback),
    'docker' (nombres de servicio DNS de Docker), o 'ci' (entornos de integración continua).

.PARAMETER SecurityMode
    Modo de seguridad IAM: 'own' (Keycloak institucional propio en 8081, realm asistencias-uco)
    o 'baseline' (stack delegado Security Baseline en 19090, realm security-baseline).

.PARAMETER Force
    Sobrescribir los archivos existentes incluso si ya contienen configuraciones personalizadas.
    Las contraseñas y secretos del .env existente se conservan siempre (también con -Force); los que faltan o siguen
    con la plantilla CHANGE_ME se generan al azar. No hay contraseñas fijas en el código.

.PARAMETER CheckOnly
    Solo audita y verifica el estado de las variables de entorno sin modificar ningún archivo.

.EXAMPLE
    .\init-env.ps1
    .\init-env.ps1 -Profile local -SecurityMode own
    .\init-env.ps1 -Force
    .\init-env.ps1 -CheckOnly
#>

[CmdletBinding()]
param(
    [ValidateSet('local', 'docker', 'ci')]
    [string]$Profile = 'local',

    [ValidateSet('own', 'baseline')]
    [string]$SecurityMode = 'own',

    [switch]$Force,

    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$infraRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

# Rutas Canónicas del Ecosistema
$infraEnv          = Join-Path $infraRoot ".env"
$infraEnvExample   = Join-Path $infraRoot ".env.example"

$backendRoot       = Join-Path $repoRoot "GestioAsistenciaBackend"
$backendEnv        = Join-Path $backendRoot ".env"
$backendEnvExample = Join-Path $backendRoot ".env.example"
$backendFilesEnv   = Join-Path $backendRoot "infra\files\.env"

$frontendRoot      = Join-Path $repoRoot "GestioAsistenciaFrontend"
$frontendEnv       = Join-Path $frontendRoot ".env"
$frontendPublicJs  = Join-Path $frontendRoot "public\assets\env.js"
$frontendSrcJs     = Join-Path $frontendRoot "src\assets\env.js"
$frontendDistJs    = Join-Path $frontendRoot "dist\gestio-asistencia-frontend\browser\assets\env.js"

$dbRoot            = Join-Path $repoRoot "GestioAsistenciaDB"
$dbEnv             = Join-Path $dbRoot ".env"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " 🏛️ ASISTENCIAS UCO - CONSTRUCTOR CANONICO DE ENTORNO (ENVIRONMENT BUILDER)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " Perfil Objetivo   : $Profile" -ForegroundColor Gray
Write-Host " Modo de Seguridad : $SecurityMode ($(if ($SecurityMode -eq 'own') { 'Keycloak Propio 8081' } else { 'Security Baseline 19090' }))" -ForegroundColor Gray
Write-Host " Modo Operación    : $(if ($CheckOnly) { 'AUDITORIA (CheckOnly)' } elseif ($Force) { 'SOBRESCRITURA FORZADA (-Force)' } else { 'IDEMPOTENTE (Preserva existentes)' })" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# Función para parsear un archivo .env en Hashtable
function Import-EnvToHash {
    param([string]$FilePath)
    $hash = @{}
    if (Test-Path -LiteralPath $FilePath) {
        Get-Content -LiteralPath $FilePath | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $idx = $line.IndexOf("=")
                $key = $line.Substring(0, $idx).Trim()
                $val = $line.Substring($idx + 1).Trim()
                $hash[$key] = $val
            }
        }
    }
    return $hash
}

# --- AUDITORIA / CHECK-ONLY ---
if ($CheckOnly) {
    Write-Host "`n[AUDITORIA DE ARCHIVOS DE CONFIGURACION]" -ForegroundColor Yellow
    $targets = @(
        @{ Name = "Infraestructura (.env)"; Path = $infraEnv },
        @{ Name = "Backend (.env)"; Path = $backendEnv },
        @{ Name = "Backend Storage (.env)"; Path = $backendFilesEnv },
        @{ Name = "Frontend (.env)"; Path = $frontendEnv },
        @{ Name = "Frontend Assets (public/env.js)"; Path = $frontendPublicJs },
        @{ Name = "Frontend Assets (src/env.js)"; Path = $frontendSrcJs },
        @{ Name = "Base de Datos (.env)"; Path = $dbEnv }
    )

    $allOk = $true
    foreach ($t in $targets) {
        $exists = Test-Path -LiteralPath $t.Path
        $statusStr = if ($exists) { "[PRESENTE]" } else { "[FALTANTE]" }
        $color = if ($exists) { "Green" } else { "Red" }
        Write-Host ("  {0,-35} : {1}" -f $t.Name, $statusStr) -ForegroundColor $color
        if (-not $exists) { $allOk = $false }
    }

    if ($allOk) {
        Write-Host "`n[PASS] Todos los archivos de entorno están configurados y presentes." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n[WARN] Existen archivos de entorno faltantes. Ejecuta 'infra.ps1 init-env' para generarlos." -ForegroundColor Yellow
        exit 1
    }
}

# 1. Resolver Valores Maestros de Infraestructura
Write-Host "`n[1/5] Resolviendo Matriz Maestra de Configuración..." -ForegroundColor Yellow

$existingInfra = Import-EnvToHash -FilePath $infraEnv

$dbHost = if ($Profile -eq 'docker') { "sql_server_asistencias" } else { "127.0.0.1" }
$dbPort = 1433
$dbName = "gestionasistenciadb"

# Secretos locales: se conserva el valor del .env existente (tambien con -Force, para no dejar a SQL Server, Keycloak o
# MinIO con una clave distinta a la de sus volumenes) y, si falta o es la plantilla CHANGE_ME, se genera uno al azar.
# Ya no hay claves fijas en el codigo. Para rotar una clave: borre la linea del .env y vuelva a ejecutar init-env.
function New-ClaveLab {
    param([int]$Longitud = 24)
    # Letras y digitos mas '-', '_' y '.': cumple la complejidad de SQL Server y la politica del realm (mayuscula,
    # minuscula, digito y especial) sin caracteres que haya que escapar en .env, URL o T-SQL.
    $mayus = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; $minus = 'abcdefghijkmnopqrstuvwxyz'; $dig = '23456789'; $esp = '-_.'
    $todos = $mayus + $minus + $dig
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    try {
        $b = New-Object byte[] (2 * $Longitud)
        $rng.GetBytes($b)
        # Empieza por mayuscula; luego minuscula, digito y especial obligatorios y el resto al azar.
        $c = [char[]](@($mayus[$b[0] % $mayus.Length], $minus[$b[1] % $minus.Length], $dig[$b[2] % $dig.Length], $esp[$b[3] % $esp.Length]) +
                      @(for ($i = 4; $i -lt $Longitud; $i++) { $todos[$b[$i] % $todos.Length] }))
        # Mezcla (Fisher-Yates) de las posiciones 1..n-1 con los bytes restantes.
        for ($i = $Longitud - 1; $i -gt 1; $i--) {
            $j = 1 + ($b[$Longitud + $i] % $i)
            $t = $c[$i]; $c[$i] = $c[$j]; $c[$j] = $t
        }
        return (-join $c)
    } finally { $rng.Dispose() }
}

function Resolve-Secreto {
    # Devuelve el primer candidato con un valor real (ni vacio ni plantilla CHANGE_ME); si no hay, genera uno.
    param([string[]]$Candidatos)
    foreach ($v in $Candidatos) {
        if (-not [string]::IsNullOrWhiteSpace($v) -and $v -notmatch '^(?i)change[-_]?me') { return $v }
    }
    return (New-ClaveLab)
}

# Cada clave tambien se busca en los otros .env que init-env genera (stack/.env, BD, Backend, infra/files): si los
# contenedores ya existen, sus volumenes tienen esa clave y una nueva los dejaria inaccesibles.
$existingStack = Import-EnvToHash -FilePath (Join-Path (Join-Path $infraRoot "stack") ".env")
$existingDb = Import-EnvToHash -FilePath $dbEnv
$existingBackend = Import-EnvToHash -FilePath $backendEnv
$existingFiles = Import-EnvToHash -FilePath $backendFilesEnv
$saPassword = Resolve-Secreto @($existingInfra['MSSQL_SA_PASSWORD'], $existingStack['MSSQL_SA_PASSWORD'], $existingDb['SQL_CONTAINER_PASSWORD'])

$appDbUser = "app_asistencias_user"
$appDbPassword = Resolve-Secreto @($existingInfra['APP_DB_PASSWORD'])

$kcPort = if ($SecurityMode -eq 'own') { 8081 } else { 19090 }
$kcRealm = if ($SecurityMode -eq 'own') { "asistencias-uco" } else { "security-baseline" }
$kcHost = if ($Profile -eq 'docker') { "keycloak_asistencias" } else { "127.0.0.1" }
$kcClientSecret = Resolve-Secreto @($existingInfra['KEYCLOAK_ADMIN_CLIENT_SECRET'], $existingBackend['KEYCLOAK_ADMIN_CLIENT_SECRET'])
# Usuarios de prueba del Keycloak propio (seed-users.ps1, get-token.ps1, diagnose-token.ps1)
$e2eDocentePassword = Resolve-Secreto @($existingInfra['E2E_DOCENTE_PASSWORD'])
$e2eAdminPassword = Resolve-Secreto @($existingInfra['E2E_ADMIN_PASSWORD'])

$minioHost = if ($Profile -eq 'docker') { "asistencias-files-minio-1" } else { "127.0.0.1" }
$minioPort = 9000
$minioUser = "minio_admin"
$minioPass = Resolve-Secreto @($existingInfra['MINIO_ROOT_PASSWORD'], $existingFiles['MINIO_ROOT_PASSWORD'])
$minioAppKey = "asistencias_app"
$minioAppSecret = Resolve-Secreto @($existingInfra['MINIO_SECRET_KEY'], $existingFiles['MINIO_SECRET_KEY'], $existingBackend['MINIO_SECRET_KEY'])

$clamavHost = if ($Profile -eq 'docker') { "asistencias-files-clamav-1" } else { "127.0.0.1" }
$clamavPort = 3310

# 2. Generar AsistenciasUCO-Infra/.env
Write-Host "[2/5] Generando AsistenciasUCO-Infra\.env..." -ForegroundColor Yellow
if (-not (Test-Path $infraEnv) -or $Force) {
    $infraContent = @"
# ==============================================================================
# ASISTENCIAS UCO - CONFIGURACION MAESTRA DE INFRAESTRUCTURA (GENERADO AUTOMATICO)
# ==============================================================================
HOST_BIND_IP=127.0.0.1
SQL_HOST_PORT=$dbPort
KEYCLOAK_HOST_PORT=$kcPort
KEYCLOAK_MANAGEMENT_HOST_PORT=9001
BACKEND_HOST_PORT=8080
FRONTEND_HOST_PORT=4200
PROMETHEUS_HOST_PORT=9090
GRAFANA_HOST_PORT=3000
OTEL_GRPC_PORT=4317
OTEL_HTTP_PORT=4318

SQL_CONTAINER_NAME=sql_server_asistencias
MSSQL_PID=Developer
ACCEPT_EULA=Y
MSSQL_COLLATION=Modern_Spanish_CI_AS
SQL_MEM_LIMIT=2g
SQL_DATABASE_NAME=$dbName
MSSQL_SA_PASSWORD=$saPassword
APP_DB_USERNAME=$appDbUser
APP_DB_PASSWORD=$appDbPassword

KC_DB_CONTAINER_NAME=keycloak_db_asistencias
KC_DB_DATABASE=keycloak
KC_DB_USERNAME=keycloak
KC_DB_PASSWORD=$saPassword
KC_DB_MEM_LIMIT=512m

KEYCLOAK_CONTAINER_NAME=keycloak_asistencias
KEYCLOAK_VERSION=26.7.1
KEYCLOAK_MEM_LIMIT=1g
KC_BOOTSTRAP_ADMIN_USERNAME=kcadmin
KC_BOOTSTRAP_ADMIN_PASSWORD=$saPassword
KEYCLOAK_SERVER_URL=http://${kcHost}:${kcPort}
KEYCLOAK_ISSUER_URI=http://${kcHost}:${kcPort}/realms/$kcRealm
KC_REALM=$kcRealm
KC_API_CLIENT_ID=asistencias-api
KC_FRONTEND_CLIENT_ID=asistencias-uco-frontend
KC_BACKEND_ADMIN_CLIENT_ID=asistencias-backend-admin
KEYCLOAK_ADMIN_CLIENT_SECRET=$kcClientSecret
KC_PASSWORD_MIN_LENGTH=12
E2E_DOCENTE_USERNAME=docente.prueba
E2E_DOCENTE_PASSWORD=$e2eDocentePassword
E2E_ADMIN_USERNAME=admin.prueba
E2E_ADMIN_PASSWORD=$e2eAdminPassword

AZURE_APPCONFIG_ENDPOINT=https://appcs-asist-dev-29183.azconfig.io
AZURE_APPCONFIG_LABEL=es
AZURE_KEYVAULT_ENDPOINT=https://kv-asist-dev-21245.vault.azure.net/
AZURE_APPCONFIG_FALLBACK_LOCAL=true

MINIO_HOST_PORT=$minioPort
MINIO_ENDPOINT=http://${minioHost}:${minioPort}
MINIO_BROWSER=off
MINIO_ROOT_USER=$minioUser
MINIO_ROOT_PASSWORD=$minioPass
MINIO_ACCESS_KEY=$minioAppKey
MINIO_SECRET_KEY=$minioAppSecret
MINIO_BUCKET=asistencias-soportes

CLAMAV_HOST_PORT=$clamavPort
CLAMAV_HOST=$clamavHost
CLAMAV_PORT=$clamavPort

COMPOSE_PROFILES=core
"@
    Set-Content -LiteralPath $infraEnv -Value $infraContent -Encoding UTF8
    Write-Host "  -> AsistenciasUCO-Infra\.env creado/actualizado exitosamente." -ForegroundColor Green
} else {
    Write-Host "  -> AsistenciasUCO-Infra\.env ya existe. Preservado (usa -Force para regenerar)." -ForegroundColor Gray
}

# 3. Generar GestioAsistenciaBackend/.env y infra/files/.env
Write-Host "[3/5] Generando GestioAsistenciaBackend\.env..." -ForegroundColor Yellow
$datasourceUrl = if ($Profile -eq 'docker') {
    "jdbc:sqlserver://${dbHost}:${dbPort};databaseName=${dbName};encrypt=false"
} else {
    "jdbc:sqlserver://localhost:${dbPort};databaseName=${dbName};encrypt=true;trustServerCertificate=true"
}

$backendContent = @"
SPRING_DATASOURCE_URL=$datasourceUrl
SPRING_DATASOURCE_USERNAME=sa
SPRING_DATASOURCE_PASSWORD=$saPassword
SPRING_DATASOURCE_DRIVER_CLASS_NAME=com.microsoft.sqlserver.jdbc.SQLServerDriver
APP_DATABASE_EXPECTED_NAME=$dbName

KEYCLOAK_ISSUER_URI=http://${kcHost}:${kcPort}/realms/$kcRealm
KEYCLOAK_API_CLIENT_ID=asistencias-api
KEYCLOAK_EXPECTED_AUDIENCE=asistencias-api
KEYCLOAK_USER_ID_CLAIM=idUsuario

KEYCLOAK_SERVER_URL=http://${kcHost}:${kcPort}
KEYCLOAK_REALM=$kcRealm
KEYCLOAK_ADMIN_CLIENT_ID=asistencias-backend-admin
KEYCLOAK_ADMIN_CLIENT_SECRET=$kcClientSecret
KEYCLOAK_USER_ID_ATTRIBUTE=idUsuario

APP_ADAPTERS_IDENTITY_PROVIDER=keycloak
APP_ADAPTERS_SECURITY_PROVIDER=keycloak
APP_ADAPTERS_STORAGE_PROVIDER=minio
APP_ADAPTERS_REALTIME_PROVIDER=local-sse
APP_ADAPTERS_AUDIT_PROVIDER=logging

# SEC-12 (VAL-oleada3-baul-secretos): el backend ya no trae los recursos Azure por defecto. Estas lineas mantienen el
# uso de Key Vault y App Configuration de desarrollo; sin ellas, el perfil dev usa local_env y catalogos en SQL Server.
APP_ADAPTERS_VAULT_PROVIDER=azure_keyvault
APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=azure_appconfig
APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER=azure
AZURE_KEYVAULT_ENDPOINT=https://kv-asist-dev-21245.vault.azure.net/
AZURE_APPCONFIG_ENDPOINT=https://appcs-asist-dev-29183.azconfig.io
# En local los secretos de ejecucion siguen en este .env (no en el baul de desarrollo): true los leeria del baul al arrancar.
APP_SECRETS_RUNTIME_FROM_VAULT_ENABLED=false

MINIO_ENDPOINT=http://${minioHost}:${minioPort}
MINIO_ACCESS_KEY=$minioAppKey
MINIO_SECRET_KEY=$minioAppSecret
MINIO_BUCKET=asistencias-soportes

CLAMAV_HOST=$clamavHost
CLAMAV_PORT=$clamavPort

APP_SECURITY_CORS_ALLOWED_ORIGINS=http://localhost:4200

MANAGEMENT_TRACING_SAMPLING_PROBABILITY=1.0
MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT=http://localhost:4318/v1/traces

ASISTENCIAS_UCO_LOG_FILE=infra/observability/logs/asistencias-uco.jsonl
ASISTENCIAS_UCO_LOG_FILE_PATTERN=infra/observability/logs/asistencias-uco.%d{yyyy-MM-dd}.%i.jsonl
ASISTENCIAS_UCO_LOG_MAX_FILE_SIZE=10MB
ASISTENCIAS_UCO_LOG_MAX_HISTORY=7
ASISTENCIAS_UCO_LOG_TOTAL_SIZE_CAP=1GB
ASISTENCIAS_UCO_ENVIRONMENT=local

SPRING_PROFILES_ACTIVE=dev
ASISTENCIAS_SWAGGER_UI_ENABLED=true
"@
Set-Content -LiteralPath $backendEnv -Value $backendContent -Encoding UTF8
Write-Host "  -> GestioAsistenciaBackend\.env configurado." -ForegroundColor Green

# infra/files/.env
$backendFilesDir = Split-Path -Parent $backendFilesEnv
if (-not (Test-Path $backendFilesDir)) { New-Item -ItemType Directory -Path $backendFilesDir -Force | Out-Null }
$filesEnvContent = @"
MINIO_ROOT_USER=$minioUser
MINIO_ROOT_PASSWORD=$minioPass
MINIO_ACCESS_KEY=$minioAppKey
MINIO_SECRET_KEY=$minioAppSecret
MINIO_HOST_PORT=$minioPort
CLAMAV_HOST_PORT=$clamavPort
"@
Set-Content -LiteralPath $backendFilesEnv -Value $filesEnvContent -Encoding UTF8
Write-Host "  -> GestioAsistenciaBackend\infra\files\.env configurado." -ForegroundColor Green

# 4. Generar GestioAsistenciaFrontend (env.js sincronizado en public, src y dist)
Write-Host "[4/5] Generando Frontend env.js y .env..." -ForegroundColor Yellow

$frontendJsContent = @"
(function (window) {
  window.env = window.env || {};
  var host = window.location.hostname || 'localhost';
  window.env['API_URL'] = 'http://' + host + ':8080/api/v1';
  window.env['KEYCLOAK_URL'] = 'http://' + host + ':${kcPort}';
  window.env['KEYCLOAK_REALM'] = '${kcRealm}';
  window.env['KEYCLOAK_CLIENT_ID'] = 'asistencias-uco-frontend';
  window.env['USE_MOCKS'] = 'false';
  window.env['SECURITY_BASELINE_ENABLED'] = '$(if ($SecurityMode -eq "baseline") { "true" } else { "false" })';
})(this);
"@

$publicDir = Split-Path -Parent $frontendPublicJs
if (-not (Test-Path $publicDir)) { New-Item -ItemType Directory -Path $publicDir -Force | Out-Null }
Set-Content -LiteralPath $frontendPublicJs -Value $frontendJsContent -Encoding UTF8

$srcDir = Split-Path -Parent $frontendSrcJs
if (-not (Test-Path $srcDir)) { New-Item -ItemType Directory -Path $srcDir -Force | Out-Null }
Set-Content -LiteralPath $frontendSrcJs -Value $frontendJsContent -Encoding UTF8

if (Test-Path -LiteralPath (Split-Path -Parent $frontendDistJs)) {
    Set-Content -LiteralPath $frontendDistJs -Value $frontendJsContent -Encoding UTF8
}

$frontendDotEnv = @"
API_URL=http://localhost:8080/api/v1
KEYCLOAK_URL=http://127.0.0.1:${kcPort}
KEYCLOAK_REALM=${kcRealm}
KEYCLOAK_CLIENT_ID=asistencias-uco-frontend
USE_MOCKS=false
"@
Set-Content -LiteralPath $frontendEnv -Value $frontendDotEnv -Encoding UTF8
Write-Host "  -> Frontend env.js (public, src) y .env sincronizados con Keycloak en puerto $kcPort." -ForegroundColor Green

# 5. Generar GestioAsistenciaDB/.env
Write-Host "[5/5] Generando GestioAsistenciaDB\.env..." -ForegroundColor Yellow
$dbEnvContent = @"
SQL_CONTAINER_NAME=sql_server_asistencias
SQL_CONTAINER_PASSWORD=$saPassword
"@
Set-Content -LiteralPath $dbEnv -Value $dbEnvContent -Encoding UTF8
Write-Host "  -> GestioAsistenciaDB\.env configurado." -ForegroundColor Green

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host " [PASS] CONSTRUCCION Y SINCRONIZACION DE ENTORNO COMPLETADA EXITOSAMENTE!" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host " Resumen de configuración:" -ForegroundColor White
Write-Host "  * SQL Server   : localhost:$dbPort ($dbName, user: sa)" -ForegroundColor Gray
Write-Host "  * Keycloak IAM : http://${kcHost}:${kcPort} (Realm: $kcRealm)" -ForegroundColor Gray
Write-Host "  * MinIO S3     : http://${minioHost}:${minioPort} (Bucket: asistencias-soportes)" -ForegroundColor Gray
Write-Host "  * Backend API  : http://localhost:8080 (Swagger UI activado)" -ForegroundColor Gray
Write-Host "  * Frontend SPA : http://localhost:4200 (env.js sincronizado)" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Green
