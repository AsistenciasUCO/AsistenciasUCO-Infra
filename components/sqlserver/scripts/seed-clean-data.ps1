<#
.SYNOPSIS
    Siembra y restablecimiento de datos limpios canonicos para el Sistema de Asistencias UCO.

.DESCRIPTION
    Restaura la integridad de los 11 usuarios institucionales (estudiantes, docentes,
    coordinador, decano, admin), purga grupos y usuarios de prueba volatiles, reasigna
    al coordinador titular al programa institucional, enrola alumnos al Grupo 02 y
    recalcula los cupos de estudiantes de forma atomica.

.PARAMETER Server
    Host o IP del servidor SQL Server (Default: 127.0.0.1).

.PARAMETER Port
    Puerto TCP de SQL Server (Default: 1433).

.PARAMETER DatabaseName
    Nombre de la base de datos (Default: gestionasistenciadb).

.PARAMETER Password
    Contrasena de conexion (sa).

.PARAMETER ContainerName
    Nombre del contenedor Docker si se desea ejecutar internamente (Default: sql_server_asistencias).

.EXAMPLE
    .\seed-clean-data.ps1
#>

[CmdletBinding()]
param (
    [string]$Server = "127.0.0.1",
    [int]$Port = 1433,
    [string]$DatabaseName = "gestionasistenciadb",
    [string]$Username = "sa",
    [string]$Password,
    [string]$ContainerName = "sql_server_asistencias"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Cargar variables de entorno desde AsistenciasUCO-Infra/.env si existe
$infraEnv = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") ".env"
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

if (-not $Password) {
    $Password = if ($env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD } else { "TuPasswordSeguro123" }
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " ASISTENCIAS UCO - RESTABLECIMIENTO DE DATOS LIMPIOS CANONICOS" -ForegroundColor Cyan
Write-Host "Servidor: $Server : $Port | Base de Datos: $DatabaseName" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

$sqlFile = Join-Path $PSScriptRoot "seed-clean-data.sql"
if (-not (Test-Path $sqlFile)) {
    throw "No se encontro el script SQL de siembra en: $sqlFile"
}
$seedTsql = Get-Content -Path $sqlFile -Raw -Encoding utf8

# Ejecutar prioritariamente via docker exec sqlcmd si el contenedor esta disponible
$dockerRunning = $false
try {
    $inspect = docker inspect --format="{{.State.Running}}" $ContainerName 2>$null
    if ($inspect -eq "true") { $dockerRunning = $true }
} catch { $dockerRunning = $false }

if ($dockerRunning) {
    Write-Host "Ejecutando siembra mediante Docker exec sqlcmd en $ContainerName..." -ForegroundColor Gray
    $tempFile = "/tmp/seed-clean.sql"
    docker cp $sqlFile "${ContainerName}:${tempFile}"
    $result = docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d "$DatabaseName" -U sa -P "$Password" -C -b -i "$tempFile"
    Write-Host $result
} else {
    Write-Host "Ejecutando siembra mediante conexion directa a $Server , $Port..." -ForegroundColor Gray
    $connStr = "Server=$Server,$Port;Database=$DatabaseName;User Id=$Username;Password=$Password;TrustServerCertificate=True;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $seedTsql
        $dt = New-Object System.Data.DataTable
        (New-Object System.Data.SqlClient.SqlDataAdapter($cmd)).Fill($dt) | Out-Null
        $dt | Format-Table -AutoSize | Out-String | Write-Host
    } finally {
        $conn.Close()
    }
}

Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "[OK] Datos limpios canonicos restablecidos con exito." -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
