<#
.SYNOPSIS
    Cargador unificado de variables de entorno para la sesión de PowerShell.

.DESCRIPTION
    Lee de forma segura el archivo .env de AsistenciasUCO-Infra (o realiza fallback a .env.example
    en entornos nuevos de desarrollo) y exporta cada variable como variable de entorno de proceso
    ($env:KEY = VALUE). Redacta en consola cualquier valor clasificado como secreto o contraseña.

.PARAMETER EnvPath
    Ruta opcional al archivo .env (Default: 'AsistenciasUCO-Infra/.env' o '../.env').

.EXAMPLE
    . .\load-env.ps1
#>

[CmdletBinding()]
param(
    [Alias('Path')]
    [string]$EnvPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Función para localizar el directorio de AsistenciasUCO-Infra de forma robusta (compatible con dot-sourcing)
function Find-InfraDirectory {
    param([string]$StartPath)
    
    $checkPaths = @(
        $StartPath,
        $PSScriptRoot,
        (Get-Location).Path,
        "C:\Proyectos\GestioAsistencia\AsistenciasUCO-Infra",
        "C:\Proyectos\GestioAsistencia"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($base in $checkPaths) {
        $curr = $base
        while ($curr -and (Test-Path -LiteralPath $curr)) {
            if ((Split-Path -Leaf $curr) -eq "AsistenciasUCO-Infra") {
                return (Resolve-Path $curr).Path
            }
            $target = Join-Path $curr "AsistenciasUCO-Infra"
            if (Test-Path -LiteralPath $target) {
                return (Resolve-Path $target).Path
            }
            $parent = Split-Path -Parent $curr
            if ($parent -eq $curr -or [string]::IsNullOrWhiteSpace($parent)) { break }
            $curr = $parent
        }
    }
    return $null
}

$infraDir = Find-InfraDirectory -StartPath $PSScriptRoot
$repoRoot = if ($infraDir) { Split-Path -Parent $infraDir } else { (Get-Location).Path }

# Resolver ruta de .env si no fue provista
if ([string]::IsNullOrWhiteSpace($EnvPath)) {
    $candidates = @()
    if ($infraDir) {
        $candidates += Join-Path $infraDir ".env"
    }
    if ($PSScriptRoot) {
        $candidates += Join-Path $PSScriptRoot ".env"
    }
    if ($infraDir) {
        $candidates += Join-Path $infraDir ".env.example"
    }

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            $EnvPath = (Resolve-Path $c).Path
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($EnvPath) -or -not (Test-Path -LiteralPath $EnvPath)) {
    throw "No se encontró ningún archivo .env o .env.example en las rutas esperadas."
}

$isExample = $EnvPath.EndsWith(".example")
if ($isExample) {
    Write-Host "[AVISO] Usando plantilla .env.example como fallback. Crea tu '.env' local personalizado." -ForegroundColor Yellow
}

$loadedCount = 0

function Import-EnvLines {
    param([string]$FilePath)
    $count = 0
    Get-Content -LiteralPath $FilePath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $sep = $line.IndexOf('=')
            $key = $line.Substring(0, $sep).Trim()
            $val = $line.Substring($sep + 1).Trim()

            # Quitar comillas si existen
            if ($val.Length -ge 2 -and (
                ($val.StartsWith('"') -and $val.EndsWith('"')) -or
                ($val.StartsWith("'") -and $val.EndsWith("'"))
            )) {
                $val = $val.Substring(1, $val.Length - 2)
            }

            # Exportar al proceso
            [System.Environment]::SetEnvironmentVariable($key, $val, [System.EnvironmentVariableTarget]::Process)
            $count++
        }
    }
    return $count
}

$loadedCount += Import-EnvLines -FilePath $EnvPath

# Compatibilidad Backend: Cargar GestioAsistenciaBackend\.env si existe para inyectar SPRING_DATASOURCE_*
$backendEnvPath = if ($repoRoot) { Join-Path $repoRoot "GestioAsistenciaBackend\.env" } else { $null }
if ($backendEnvPath -and (Test-Path -LiteralPath $backendEnvPath)) {
    $loadedCount += Import-EnvLines -FilePath $backendEnvPath
}

# Compatibilidad Base de Datos: Cargar GestioAsistenciaDB\.env si existe
$dbEnvPath = if ($repoRoot) { Join-Path $repoRoot "GestioAsistenciaDB\.env" } else { $null }
if ($dbEnvPath -and (Test-Path -LiteralPath $dbEnvPath)) {
    $loadedCount += Import-EnvLines -FilePath $dbEnvPath
}

# Compatibilidad Storage / Files: Cargar GestioAsistenciaBackend\infra\files\.env si existe
$filesEnvPath = if ($repoRoot) { Join-Path $repoRoot "GestioAsistenciaBackend\infra\files\.env" } else { $null }
if ($filesEnvPath -and (Test-Path -LiteralPath $filesEnvPath)) {
    $loadedCount += Import-EnvLines -FilePath $filesEnvPath
}

# Resolver contraseña sa con fallback seguro para desarrollo local
if ([string]::IsNullOrWhiteSpace($env:MSSQL_SA_PASSWORD) -or $env:MSSQL_SA_PASSWORD -eq "CHANGE_ME_MSSQL_PASSWORD") {
    if ($env:SQL_CONTAINER_PASSWORD) {
        [System.Environment]::SetEnvironmentVariable("MSSQL_SA_PASSWORD", $env:SQL_CONTAINER_PASSWORD, [System.EnvironmentVariableTarget]::Process)
    } else {
        [System.Environment]::SetEnvironmentVariable("MSSQL_SA_PASSWORD", "TuPasswordSeguro123", [System.EnvironmentVariableTarget]::Process)
    }
}

# Autocompletar variables de Spring Boot si faltan y se definieron variables estándar
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("SPRING_DATASOURCE_URL", "Process"))) {
    $dbHost = if ($env:HOST_BIND_IP) { $env:HOST_BIND_IP } else { "127.0.0.1" }
    $dbPort = if ($env:SQL_HOST_PORT) { $env:SQL_HOST_PORT } else { "1433" }
    $dbName = if ($env:SQL_DATABASE_NAME) { $env:SQL_DATABASE_NAME } else { "gestionasistenciadb" }
    [System.Environment]::SetEnvironmentVariable("SPRING_DATASOURCE_URL", "jdbc:sqlserver://${dbHost}:${dbPort};databaseName=${dbName};encrypt=false;trustServerCertificate=true", [System.EnvironmentVariableTarget]::Process)
}
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("SPRING_DATASOURCE_USERNAME", "Process")) -and $env:APP_DB_USERNAME) {
    [System.Environment]::SetEnvironmentVariable("SPRING_DATASOURCE_USERNAME", $env:APP_DB_USERNAME, [System.EnvironmentVariableTarget]::Process)
}
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("SPRING_DATASOURCE_PASSWORD", "Process")) -and $env:APP_DB_PASSWORD) {
    [System.Environment]::SetEnvironmentVariable("SPRING_DATASOURCE_PASSWORD", $env:APP_DB_PASSWORD, [System.EnvironmentVariableTarget]::Process)
}
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("APP_DATABASE_EXPECTED_NAME", "Process")) -and $env:SQL_DATABASE_NAME) {
    [System.Environment]::SetEnvironmentVariable("APP_DATABASE_EXPECTED_NAME", $env:SQL_DATABASE_NAME, [System.EnvironmentVariableTarget]::Process)
}

# Autocompletar variables de MinIO y ClamAV si faltan
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("MINIO_ENDPOINT", "Process"))) {
    $minioHost = if ($env:HOST_BIND_IP) { $env:HOST_BIND_IP } else { "127.0.0.1" }
    $minioPort = if ($env:MINIO_HOST_PORT) { $env:MINIO_HOST_PORT } else { "9000" }
    [System.Environment]::SetEnvironmentVariable("MINIO_ENDPOINT", "http://${minioHost}:${minioPort}", [System.EnvironmentVariableTarget]::Process)
}
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("MINIO_BUCKET", "Process"))) {
    [System.Environment]::SetEnvironmentVariable("MINIO_BUCKET", "asistencias-soportes", [System.EnvironmentVariableTarget]::Process)
}
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("CLAMAV_HOST", "Process"))) {
    $clamavHost = if ($env:HOST_BIND_IP) { $env:HOST_BIND_IP } else { "127.0.0.1" }
    [System.Environment]::SetEnvironmentVariable("CLAMAV_HOST", $clamavHost, [System.EnvironmentVariableTarget]::Process)
}
if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable("CLAMAV_PORT", "Process"))) {
    $clamavPort = if ($env:CLAMAV_HOST_PORT) { $env:CLAMAV_HOST_PORT } else { "3310" }
    [System.Environment]::SetEnvironmentVariable("CLAMAV_PORT", $clamavPort, [System.EnvironmentVariableTarget]::Process)
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "[INFO] ASISTENCIAS UCO - VARIABLES DE ENTORNO CARGADAS" -ForegroundColor Cyan
Write-Host "Archivo : $EnvPath ($loadedCount variables exportadas)" -ForegroundColor Gray
Write-Host "Binding : $env:HOST_BIND_IP | Perfil por defecto: $env:COMPOSE_PROFILES" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan
