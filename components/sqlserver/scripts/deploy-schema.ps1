<#
.SYNOPSIS
    Compilador y desplegador del esquema relacional DDL en Microsoft SQL Server (Docker).

.DESCRIPTION
    Compila en orden relacional estricto tablas, funciones, vistas (con resolución dinámica de
    dependencias de hasta 15 pasadas), procedimientos almacenados y datos semilla.
    Apunta por defecto al esquema maestro ubicado en 'GestioAsistenciaDB/schema' sin duplicar
    ni mover los archivos SQL originales.

.PARAMETER ContainerName
    Nombre del contenedor Docker de SQL Server (Default: $env:SQL_CONTAINER_NAME o 'sql_server_asistencias').

.PARAMETER Password
    Contraseña del usuario administrador 'sa' de SQL Server.

.PARAMETER DatabaseName
    Nombre de la base de datos destino (Default: 'gestionasistenciadb').

.PARAMETER SchemaPath
    Ruta local al directorio 'schema'. Por defecto resuelve '../../../../GestioAsistenciaDB/schema'.

.EXAMPLE
    .\deploy-schema.ps1
#>

[CmdletBinding()]
param (
    [string]$ContainerName,
    [string]$Password,
    [string]$DatabaseName = "gestionasistenciadb",
    [string]$SchemaPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 1. Cargar variables de entorno desde .env de Infraestructura si existen
$infraEnv = Join-Path (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName ".env"
if (-not (Test-Path $infraEnv)) {
    $infraEnv = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") ".env"
}
if (Test-Path $infraEnv) {
    Get-Content $infraEnv | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim()
            if (-not [System.Environment]::GetEnvironmentVariable($k)) {
                [System.Environment]::SetEnvironmentVariable($k, $v)
            }
        }
    }
}

# 2. Resolver parámetros y valores por defecto
if (-not $ContainerName) {
    $ContainerName = if ($env:SQL_CONTAINER_NAME) { $env:SQL_CONTAINER_NAME } else { "sql_server_asistencias" }
}
if (-not $Password) {
    $Password = if ($env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD } elseif ($env:SQL_CONTAINER_PASSWORD) { $env:SQL_CONTAINER_PASSWORD } else { $null }
}
if (-not $Password) {
    throw "MSSQL_SA_PASSWORD no está definida. Configura AsistenciasUCO-Infra/.env o pasa el parámetro -Password."
}

# 3. Resolver la ruta canónica hacia GestioAsistenciaDB/schema
if (-not $SchemaPath) {
    $candidatePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../../../GestioAsistenciaDB/schema"))
    if (Test-Path $candidatePath) {
        $SchemaPath = $candidatePath
    } else {
        throw "No se encontró el directorio schema en: $candidatePath. Especifica -SchemaPath manualmente."
    }
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - DESPLIEGUE DDL POR OBJETO EN INFRAESTRUCTURA" -ForegroundColor Cyan
Write-Host "Contenedor : $ContainerName" -ForegroundColor Gray
Write-Host "Base Datos : $DatabaseName" -ForegroundColor Gray
Write-Host "Origen DDL : $SchemaPath" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# 4. Asegurar que la base de datos existe con el collation institucional
Write-Host "`n[1/6] Verificando base de datos '$DatabaseName'..." -ForegroundColor Yellow
$createDbSql = "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$DatabaseName') CREATE DATABASE [$DatabaseName] COLLATE Modern_Spanish_CI_AS;"
docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$Password" -C -Q "$createDbSql"
if ($LASTEXITCODE -ne 0) { throw "Fallo al verificar/crear la base de datos $DatabaseName." }

# 5. Copiar esquema al contenedor para prevenir problemas de codificación BOM y stdin de Windows
Write-Host "[2/6] Copiando archivos DDL al contenedor (/tmp/schema)..." -ForegroundColor Yellow
docker exec -u 0 $ContainerName rm -rf /tmp/schema | Out-Null
docker exec -u 0 $ContainerName mkdir -p /tmp/schema
if ($LASTEXITCODE -ne 0) { throw "No se pudo crear /tmp/schema en el contenedor." }
docker cp "$SchemaPath" "${ContainerName}:/tmp/"
if ($LASTEXITCODE -ne 0) { throw "Error al copiar $SchemaPath hacia ${ContainerName}:/tmp/" }

# Función auxiliar para ejecutar archivos SQL desde el contenedor
function Execute-Container-Sql {
    param (
        [string]$LocalFilePath
    )
    $relativePath = $LocalFilePath.Substring($SchemaPath.Length).Replace('\', '/')
    $containerPath = "/tmp/schema$relativePath"
    
    $out = docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d "$DatabaseName" -U sa -P "$Password" -C -b -i "$containerPath" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR en archivo: $LocalFilePath" -ForegroundColor Red
        Write-Host $out -ForegroundColor Red
        throw "Fallo la ejecución de $containerPath en $ContainerName"
    }
}

# 6. Aplicar Tablas
Write-Host "`n[3/6] Aplicando Tablas relacionales..." -ForegroundColor Yellow
$tables = Get-ChildItem -Path "$SchemaPath\tables" -Filter "*.sql" -Recurse | Sort-Object Name
foreach ($table in $tables) {
    Execute-Container-Sql -LocalFilePath $table.FullName
}
Write-Host "  -> $($tables.Count) tablas aplicadas." -ForegroundColor Green

# 7. Aplicar Funciones
Write-Host "`n[4/6] Aplicando Funciones (ufn_*)..." -ForegroundColor Yellow
$functions = Get-ChildItem -Path "$SchemaPath\functions" -Filter "*.sql" -Recurse | Sort-Object Name
foreach ($func in $functions) {
    Execute-Container-Sql -LocalFilePath $func.FullName
}
Write-Host "  -> $($functions.Count) funciones aplicadas." -ForegroundColor Green

# 8. Aplicar Vistas con Resolución Dinámica de Dependencias (Multi-pass)
Write-Host "`n[5/6] Aplicando Vistas (Resolviendo grafo de dependencias dinámicamente)..." -ForegroundColor Yellow
$views = Get-ChildItem -Path "$SchemaPath\views" -Filter "*.sql" -Recurse
$pendingViews = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($v in $views) { $pendingViews.Add($v) }

$maxPasses = 15
$pass = 1
$progressMade = $true

while ($pendingViews.Count -gt 0 -and $progressMade -and $pass -le $maxPasses) {
    $progressMade = $false
    $failedThisPass = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($viewFile in $pendingViews) {
        $relativePath = $viewFile.FullName.Substring($SchemaPath.Length).Replace('\', '/')
        $containerPath = "/tmp/schema$relativePath"
        $sqlResult = docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d "$DatabaseName" -U sa -P "$Password" -C -b -i "$containerPath" 2>&1
        if ($LASTEXITCODE -ne 0 -or $sqlResult -match "Msg \d+, Level \d+") {
            $failedThisPass.Add($viewFile)
        } else {
            $progressMade = $true
        }
    }
    $pendingViews = $failedThisPass
    $pass++
}

if ($pendingViews.Count -gt 0) {
    Write-Host "`n[ERROR] No se pudieron aplicar las siguientes vistas debido a dependencias circulares o errores de sintaxis:" -ForegroundColor Red
    foreach ($viewFile in $pendingViews) {
        Write-Host "  - $($viewFile.Name)" -ForegroundColor Red
        Execute-Container-Sql -LocalFilePath $viewFile.FullName
    }
    throw "Fallaron vistas en la compilación."
} else {
    Write-Host "  -> $($views.Count) vistas aplicadas exitosamente en $($pass - 1) pasadas." -ForegroundColor Green
}

# 9. Aplicar Procedimientos Almacenados
Write-Host "`n[6/6] Aplicando Procedimientos Almacenados (usp_*)..." -ForegroundColor Yellow
$procs = Get-ChildItem -Path "$SchemaPath\stored-procedures" -Filter "*.sql" -Recurse | Sort-Object Name
foreach ($proc in $procs) {
    Execute-Container-Sql -LocalFilePath $proc.FullName
}
Write-Host "  -> $($procs.Count) procedimientos almacenados aplicados." -ForegroundColor Green

# 10. Aplicar Semilla si existe en el esquema
if (Test-Path "$SchemaPath\seed") {
    Write-Host "`nAplicando Datos Semilla Maestros (/seed)..." -ForegroundColor Yellow
    $seeds = Get-ChildItem -Path "$SchemaPath\seed" -Filter "*.sql" -Recurse | Sort-Object Name
    foreach ($seed in $seeds) {
        Execute-Container-Sql -LocalFilePath $seed.FullName
    }
    Write-Host "  -> $($seeds.Count) semillas aplicadas." -ForegroundColor Green
}

# 11. Aplicar Hardening de Mínimo Privilegio (init script)
$hardeningScript = Join-Path (Join-Path $PSScriptRoot "..") "init/01-hardening-least-privilege.sql"
if (Test-Path $hardeningScript) {
    Write-Host "`nAplicando Hardening de Mínimo Privilegio (app_asistencias_user)..." -ForegroundColor Yellow
    docker cp "$hardeningScript" "${ContainerName}:/tmp/hardening.sql"
    docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$Password" -C -b -i "/tmp/hardening.sql"
    if ($LASTEXITCODE -ne 0) { throw "Error al aplicar hardening de mínimo privilegio." }
    Write-Host "  -> Hardening de seguridad aplicado exitosamente." -ForegroundColor Green
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host "✅ Despliegue de Base de Datos finalizado exitosamente en $ContainerName" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green

