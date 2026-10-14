<#
.SYNOPSIS
    Siembra y restablecimiento de datos limpios canónicos para el Sistema de Asistencias UCO.

.DESCRIPTION
    Restaura la integridad de los 11 usuarios institucionales (estudiantes, docentes,
    coordinador, decano, admin), purga grupos y usuarios de prueba volátiles, reasigna
    al coordinador titular al programa institucional, enrola alumnos al Grupo 02 y
    recalcula los cupos de estudiantes de forma atómica.

.PARAMETER Server
    Host o IP del servidor SQL Server (Default: 127.0.0.1).

.PARAMETER Port
    Puerto TCP de SQL Server (Default: 1433).

.PARAMETER DatabaseName
    Nombre de la base de datos (Default: gestionasistenciadb).

.PARAMETER Password
    Contraseña de conexión (sa).

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
Write-Host "🏛️ ASISTENCIAS UCO - RESTABLECIMIENTO DE DATOS LIMPIOS CANÓNICOS" -ForegroundColor Cyan
Write-Host "Servidor: ${Server}:${Port} | Base de Datos: $DatabaseName" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

$seedTsql = @"
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- 1. Asegurar que el Programa apunte al Coordinador Real Institucional (Andrés López)
UPDATE dbo.Programa
SET coordinador = 'f1a2b3c4-0000-0000-0000-000000000002'
WHERE id = 'b2c3d4e5-0000-0000-0000-000000000001';

-- 2. Eliminar horarios de grupos de prueba
DELETE FROM dbo.Horario 
WHERE grupo IN (SELECT id FROM dbo.Grupo WHERE nombre LIKE '%Test%');

-- 3. Eliminar grupos de prueba
DELETE FROM dbo.Grupo 
WHERE nombre LIKE '%Test%';

-- 4. Eliminar coordinadores de prueba
DELETE FROM dbo.Coordinador 
WHERE usuario IN (SELECT id FROM dbo.Usuario WHERE correo LIKE 'coord.10%');

DELETE FROM dbo.Usuario 
WHERE correo LIKE 'coord.10%';

-- 5. Eliminar docentes de prueba
DELETE FROM dbo.Docente 
WHERE usuario IN (SELECT id FROM dbo.Usuario WHERE correo LIKE 'docente.test%');

DELETE FROM dbo.Usuario 
WHERE correo LIKE 'docente.test%';

-- 6. Eliminar facultades de prueba
DELETE FROM dbo.Facultad 
WHERE id <> 'a2b3c4d5-0000-0000-0000-000000000001';

-- 7. Enrolar estudiantes institucionales en Grupo 02 si existen
DECLARE @idGrupo2 UNIQUEIDENTIFIER = 'de8a9d2d-65fc-4415-8b9e-47fab30a9091';
DECLARE @estadoA UNIQUEIDENTIFIER = (SELECT TOP 1 id FROM dbo.EstadoEstudianteGrupo WHERE codigo = 'A');

IF EXISTS (SELECT 1 FROM dbo.Grupo WHERE id = @idGrupo2) AND @estadoA IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Estudiante WHERE id = 'F1A2B3C4-0000-0000-0000-000000000004')
       AND NOT EXISTS (SELECT 1 FROM dbo.EstudianteGrupo WHERE grupo = @idGrupo2 AND estudiante = 'F1A2B3C4-0000-0000-0000-000000000004')
        INSERT INTO dbo.EstudianteGrupo (id, estudiante, grupo, estado)
        VALUES (NEWID(), 'F1A2B3C4-0000-0000-0000-000000000004', @idGrupo2, @estadoA);

    IF EXISTS (SELECT 1 FROM dbo.Estudiante WHERE id = 'F1A2B3C4-0000-0000-0000-000000000007')
       AND NOT EXISTS (SELECT 1 FROM dbo.EstudianteGrupo WHERE grupo = @idGrupo2 AND estudiante = 'F1A2B3C4-0000-0000-0000-000000000007')
        INSERT INTO dbo.EstudianteGrupo (id, estudiante, grupo, estado)
        VALUES (NEWID(), 'F1A2B3C4-0000-0000-0000-000000000007', @idGrupo2, @estadoA);

    IF EXISTS (SELECT 1 FROM dbo.Estudiante WHERE id = 'F1A2B3C4-0000-0000-0000-000000000008')
       AND NOT EXISTS (SELECT 1 FROM dbo.EstudianteGrupo WHERE grupo = @idGrupo2 AND estudiante = 'F1A2B3C4-0000-0000-0000-000000000008')
        INSERT INTO dbo.EstudianteGrupo (id, estudiante, grupo, estado)
        VALUES (NEWID(), 'F1A2B3C4-0000-0000-0000-000000000008', @idGrupo2, @estadoA);
END;

-- 8. Actualizar cupos y contadores en Grupo
UPDATE g
SET g.cantidadEstudiantes = (SELECT COUNT(1) FROM dbo.EstudianteGrupo eg WHERE eg.grupo = g.id)
FROM dbo.Grupo g;

-- 9. Resumen de Verificación
SELECT 'Usuarios Institucionales' AS Entidad, COUNT(1) AS TotalRegistros FROM dbo.Usuario
UNION ALL
SELECT 'Grupos Oficiales', COUNT(1) FROM dbo.Grupo
UNION ALL
SELECT 'Facultades Oficiales', COUNT(1) FROM dbo.Facultad
UNION ALL
SELECT 'Franjas de Horarios', COUNT(1) FROM dbo.Horario
UNION ALL
SELECT 'Estudiantes en Grupos', COUNT(1) FROM dbo.EstudianteGrupo;

COMMIT TRANSACTION;
"@

# Ejecutar prioritariamente via docker exec sqlcmd si el contenedor esta disponible
$dockerRunning = $false
try {
    $inspect = docker inspect --format="{{.State.Running}}" $ContainerName 2>$null
    if ($inspect -eq "true") { $dockerRunning = $true }
} catch { $dockerRunning = $false }

if ($dockerRunning) {
    Write-Host "Ejecutando siembra mediante Docker exec sqlcmd en $ContainerName..." -ForegroundColor Gray
    $tempFile = "/tmp/seed-clean.sql"
    $encodedSql = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($seedTsql))
    docker exec $ContainerName bash -c "echo '$encodedSql' | base64 -d > $tempFile"
    $result = docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -d "$DatabaseName" -U sa -P "$Password" -C -b -i "$tempFile"
    Write-Host $result
} else {
    Write-Host "Ejecutando siembra mediante conexión directa a $Server,$Port..." -ForegroundColor Gray
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
Write-Host "✅ Datos limpios canónicos restablecidos con éxito." -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green

