<#
.SYNOPSIS
    Ejecutor oficial del banco de pruebas transaccionales T-SQL en SQL Server (Docker).

.DESCRIPTION
    Ejecuta test_suite.sql y la suite de pruebas unitarias T-SQL en el contenedor de SQL Server,
    valida los bloques canónicos de resultados (STUDENT_DUPLICATE, MASS_CLOSE_SUCCESS, etc.) y
    compara la lista de Stored Procedures y Vistas desplegados contra los archivos del repositorio.

.PARAMETER ContainerName
    Nombre del contenedor de SQL Server (Default: $env:SQL_CONTAINER_NAME o 'sql_server_asistencias').

.PARAMETER Password
    Contraseña de sa de SQL Server.

.PARAMETER TestSuitePath
    Ruta a test_suite.sql. Por defecto resuelve '../../../../GestioAsistenciaDB/test_suite.sql'.

.EXAMPLE
    .\test-summary.ps1
#>

[CmdletBinding()]
param (
    [string]$ContainerName,
    [string]$Password,
    [string]$TestSuitePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Cargar variables de entorno desde .env de Infraestructura
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

if (-not $ContainerName) {
    $ContainerName = if ($env:SQL_CONTAINER_NAME) { $env:SQL_CONTAINER_NAME } else { "sql_server_asistencias" }
}
if (-not $Password) {
    $Password = if ($env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD } else { "TuPasswordSeguro123" }
}

$dbRepoPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../../../GestioAsistenciaDB"))

if (-not $TestSuitePath) {
    $TestSuitePath = Join-Path $dbRepoPath "test_suite.sql"
}
if (-not (Test-Path $TestSuitePath)) {
    throw "No se encontró test_suite.sql en $TestSuitePath."
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - BANCO DE PRUEBAS T-SQL EN INFRAESTRUCTURA" -ForegroundColor Cyan
Write-Host "Contenedor: $ContainerName" -ForegroundColor Gray
Write-Host "Suite SQL : $TestSuitePath" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# 1. Precheck de seguridad en el contenedor
$precheck = docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d gestionasistenciadb -U sa -P "$Password" -C -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CONCAT(DB_NAME(), '|', @@SERVERNAME, '|', CONVERT(varchar(80), SERVERPROPERTY('Edition')));" 2>&1
if ($LASTEXITCODE -ne 0 -or ($precheck -join '').Trim() -notmatch '^gestionasistenciadb\|[^|]+\|Developer Edition') {
    throw "BLOCKED - Destino de base de datos no seguro o precheck de Developer Edition fallido: $precheck"
}

# 2. Copiar archivos de prueba al contenedor
docker exec -u 0 $ContainerName rm -rf /tmp/test | Out-Null
docker cp "$TestSuitePath" "${ContainerName}:/tmp/test_suite.sql" | Out-Null

$testDir = Join-Path $dbRepoPath "test"
if (Test-Path $testDir) {
    docker cp "$testDir" "${ContainerName}:/tmp/test" | Out-Null
}
docker exec -u 0 $ContainerName chmod -R a+rX /tmp/test /tmp/test_suite.sql 2>$null | Out-Null

# 3. Ejecutar test_suite.sql
Write-Host "`nEjecutando test_suite.sql..." -ForegroundColor Yellow
$output = docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d gestionasistenciadb -U sa -P "$Password" -C -b -h -1 -s '|' -w 65535 -y 1024 -Y 1024 -i /tmp/test_suite.sql 2>&1
$sqlExitCode = $LASTEXITCODE
$outputStr = ($output | ForEach-Object { "$_" }) -join [System.Environment]::NewLine

foreach ($line in ($outputStr -split '\r?\n')) {
    if ($line -match '^[0-9a-fA-F-]{36}\|') {
        Write-Host ((@($line -split '\|', 4) | ForEach-Object { $_.Trim() }) -join '|')
    } else {
        Write-Host $line
    }
}

# 4. Validar resultados canónicos obligatorios
$resultIds = @(
    'STUDENT_DUPLICATE',
    'STUDENT_GROUP_NOT_FOUND',
    'STUDENT_GROUP_DISABLED',
    'STUDENT_CAPACITY_EXCEEDED',
    'TEACHER_GROUP_NOT_FOUND',
    'MASS_CLOSE_SUCCESS',
    'ATTENDANCE_BULK_STUDENT_NOT_IN_GROUP',
    'ATTENDANCE_BULK_ATOMIC'
)

$resultFailures = @()
$clientPassed = @()

foreach ($id in $resultIds) {
    $escaped = [regex]::Escape($id)
    $block = [regex]::Match($outputStr, "(?ms)^TEST_RESULT_BEGIN:$escaped\r?\n(.*?)^TEST_RESULT_END:$escaped\s*$")
    $user = [regex]::Match($outputStr, "(?m)^TEST_EXPECTED_USER:$escaped\|(.*)$")
    $tech = [regex]::Match($outputStr, "(?m)^TEST_EXPECTED_TECH:$escaped\|(.*)$")
    $statePassed = $outputStr -match "(?m)^TEST_STATE_PASS:$escaped\s*$"

    if (-not $block.Success -or -not $user.Success -or -not $tech.Success -or -not $statePassed) {
        $resultFailures += "$id falta resultado, mensaje de catálogo o aserción de estado"
        continue
    }

    $rows = @([regex]::Matches($block.Groups[1].Value, '(?m)^([0-9a-fA-F-]{36})\|([^|]*)\|(.*)\|\s*([01])\s*$'))
    if ($rows.Count -ne 1) {
        $resultFailures += "$id esperaba 1 fila canónica; encontradas $($rows.Count)"
        continue
    }

    $row = $rows[0]
    $expectedState = if ($id -eq 'MASS_CLOSE_SUCCESS') { '1' } else { '0' }
    if ($row.Groups[4].Value -ne $expectedState -or
        $row.Groups[2].Value.Trim() -cne $user.Groups[1].Value.Trim() -or
        $row.Groups[3].Value.Trim() -cne $tech.Groups[1].Value.Trim()) {
        $resultFailures += "$id resultado difiere de state=$expectedState/mensaje de catálogo"
        continue
    }

    $clientPassed += $id
    Write-Host "TEST_PASS:$id" -ForegroundColor Green
}

# 5. Verificación de cobertura de objetos de base de datos
$schemaDir = Join-Path $dbRepoPath "schema"
$repoProcedures = @(Get-ChildItem (Join-Path $schemaDir 'stored-procedures') -Filter 'usp_*.sql' -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -notmatch '_interno$' } | ForEach-Object { $_.BaseName })
$repoViews = @(Get-ChildItem (Join-Path $schemaDir 'views') -Filter 'uv_*.sql' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.BaseName })

$instanceProcedures = @(docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d gestionasistenciadb -U sa -P "$Password" -C -b -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.procedures WHERE schema_id=SCHEMA_ID('dbo') AND name LIKE 'usp[_]%' AND name NOT LIKE '%[_]interno' ORDER BY name;" 2>&1 |
    ForEach-Object { "$_".Trim() } | Where-Object { $_ })
$instanceViews = @(docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d gestionasistenciadb -U sa -P "$Password" -C -b -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.views WHERE schema_id=SCHEMA_ID('dbo') AND name LIKE 'uv[_]%' ORDER BY name;" 2>&1 |
    ForEach-Object { "$_".Trim() } | Where-Object { $_ })

$missingProcedures = @($repoProcedures | Where-Object { $_ -notin $instanceProcedures })
$missingViews = @($repoViews | Where-Object { $_ -notin $instanceViews })

Write-Host "`n--- RESUMEN DE COBERTURA DE OBJETOS ---" -ForegroundColor Cyan
Write-Host "Procedimientos desplegados : $($instanceProcedures.Count) (Faltantes del repo: $($missingProcedures.Count))" -ForegroundColor Gray
Write-Host "Vistas desplegadas         : $($instanceViews.Count) (Faltantes del repo: $($missingViews.Count))" -ForegroundColor Gray

if ($missingProcedures.Count -gt 0) {
    Write-Host "Faltan los siguientes procedimientos en la BD:" -ForegroundColor Red
    $missingProcedures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}
if ($missingViews.Count -gt 0) {
    Write-Host "Faltan las siguientes vistas en la BD:" -ForegroundColor Red
    $missingViews | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

if ($resultFailures.Count -eq 0 -and $missingProcedures.Count -eq 0 -and $missingViews.Count -eq 0) {
    Write-Host "`n==============================================================================" -ForegroundColor Green
    Write-Host "✅ TODAS LAS PRUEBAS T-SQL PASARON CON ÉXITO (0 Fallos)" -ForegroundColor Green
    Write-Host "==============================================================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n==============================================================================" -ForegroundColor Red
    Write-Host "❌ FALLARON PRUEBAS T-SQL O FALTAN OBJETOS POR COMPILAR:" -ForegroundColor Red
    $resultFailures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "==============================================================================" -ForegroundColor Red
    exit 1
}

