<#
.SYNOPSIS
    Lleva la base de datos al estado base de pruebas ampliado, guarda una foto del estado actual o vuelve a una foto.

.DESCRIPTION
    Compatible con Windows PowerShell 5.1. Modos:
      Base      Restaura el respaldo canonico del contenedor, aplica las migraciones 13 a 28 (carpeta migrations/ del repositorio
                de BD), ejecuta deploy_schema.ps1, aplica el fixture test/fixtures/datos_prueba_ampliados.sql y corre
                test/test_datos_prueba_ampliados.sql. Es DESTRUCTIVO: reemplaza la base indicada.
      Snapshot  BACKUP DATABASE del estado actual a /var/opt/mssql/backup/<base>_QA_<fecha>.bak (o a -Backup).
      Restore   Restaura -Backup sobre la base indicada (destructivo).
    Antes de Base o Restore sobre la base por defecto hay que DETENER EL BACKEND (puerto 8080): sus conexiones y trabajos
    usan esa base. Con -StopBackend el script detiene el java.exe que escucha en 8080; sin el, aborta si el puerto esta ocupado.
    Los modos destructivos exigen -Yes. La clave de SQL Server se lee de GestioAsistenciaDB/.env (SQL_CONTAINER_PASSWORD),
    del entorno (MSSQL_SA_PASSWORD) o de AsistenciasUCO-Infra/.env; -Password es opcional y no se imprime nunca.
    Con -Database distinta de la base por defecto (p. ej. gestionasistenciadb_qa para ensayar) el script reescribe el nombre de la
    base en copias temporales de los .sql; el repositorio no se modifica.

.PARAMETER Mode
    Base | Snapshot | Restore.
.PARAMETER Backup
    Archivo .bak dentro del contenedor (ruta completa o solo el nombre; el directorio por defecto es /var/opt/mssql/backup).
    Base: por defecto el respaldo canonico CULM001. Restore: obligatorio. Snapshot: destino opcional.
.PARAMETER Database
    Base destino (por defecto gestionasistenciadb).
.PARAMETER DbRepo
    Ruta del repositorio GestioAsistenciaDB (por defecto, el hermano de AsistenciasUCO-Infra).
.PARAMETER StopBackend
    Detiene el java.exe del backend (puerto 8080) antes de restaurar.
.PARAMETER Yes
    Confirma los modos destructivos (Base y Restore).
.PARAMETER SkipFixture
    En Base, no aplica el fixture ni la prueba (deja la base canonica con migraciones y esquema).
.PARAMETER SkipTest
    En Base, no ejecuta test_datos_prueba_ampliados.sql.

.EXAMPLE
    .\infra.ps1 db-reset-qa -Mode Snapshot
    .\infra.ps1 db-reset-qa -Mode Base -StopBackend -Yes
    .\infra.ps1 db-reset-qa -Mode Restore -Backup gestionasistenciadb_QA_20261109-101500.bak -StopBackend -Yes
    .\AsistenciasUCO-Infra\scripts\database\reset-datos-prueba.ps1 -Mode Base -Database gestionasistenciadb_qa -Yes
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Base', 'Snapshot', 'Restore')]
    [string]$Mode,

    [string]$Backup,
    [string]$Database = 'gestionasistenciadb',
    [string]$ContainerName,
    [string]$DbRepo,
    [string]$Password,
    [int]$MigrationFrom = 13,
    [int]$MigrationTo = 28,
    [switch]$StopBackend,
    [switch]$Yes,
    [switch]$SkipFixture,
    [switch]$SkipTest
)

$ErrorActionPreference = 'Stop'
$DefaultDatabase = 'gestionasistenciadb'
$BackupDir = '/var/opt/mssql/backup'
$CanonicalBackup = 'gestionasistenciadb_CULM001_base_20261106-215201.bak'
$FixtureRel = 'test\fixtures\datos_prueba_ampliados.sql'
$TestRel = 'test\test_datos_prueba_ampliados.sql'
$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Write-Step([string]$Text) { Write-Host "[reset-datos-prueba] $Text" -ForegroundColor Cyan }

function Read-EnvFile([string]$Path) {
    $map = @{}
    if (Test-Path $Path) {
        foreach ($raw in (Get-Content -LiteralPath $Path)) {
            $line = $raw.Trim().TrimStart([char]0xFEFF)
            if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
                $parts = $line.Split('=', 2)
                $map[$parts[0].Trim()] = $parts[1].Trim()
            }
        }
    }
    return $map
}

# Ejecuta docker sin que el stderr de un ejecutable nativo aborte el script en PS 5.1; devuelve texto y codigo de salida.
function Invoke-Docker {
    param([string[]]$DockerArgs)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& docker @DockerArgs 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $code; Lines = $lines; Text = ($lines -join "`n") }
}

function Invoke-SqlInContainer {
    param([string]$Query, [string]$File, [string]$Db = 'master', [string[]]$Variables = @(), [switch]$Raw)
    $a = @('exec', $script:ContainerName, '/opt/mssql-tools18/bin/sqlcmd', '-S', 'localhost', '-U', 'sa', '-P', $script:SqlPassword, '-C', '-b', '-I',
           '-d', $Db, '-h', '-1', '-W', '-w', '4000', '-t', '1800')
    if ($Raw) { $a += @('-s', '|') }
    foreach ($v in $Variables) { $a += @('-v', $v) }
    if ($File) { $a += @('-i', $File) } else { $a += @('-Q', $Query) }
    return Invoke-Docker -DockerArgs $a
}

function Assert-Ok($Result, [string]$What) {
    if ($Result.ExitCode -ne 0) {
        $tail = ($Result.Lines | Select-Object -Last 15) -join "`n"
        throw "Fallo: $What (codigo $($Result.ExitCode)).`n$tail"
    }
}

# ---------------------------------------------------------------------------------------------------- resolucion de entorno
if (-not $DbRepo) { $DbRepo = Join-Path $infraRoot '..\GestioAsistenciaDB' }
if (Test-Path $DbRepo) { $DbRepo = (Resolve-Path $DbRepo).Path }
$dbEnv = Read-EnvFile (Join-Path $DbRepo '.env')
$infraEnv = Read-EnvFile (Join-Path $infraRoot '.env')

if (-not $ContainerName) {
    if ($env:SQL_CONTAINER_NAME) { $ContainerName = $env:SQL_CONTAINER_NAME }
    elseif ($dbEnv['SQL_CONTAINER_NAME']) { $ContainerName = $dbEnv['SQL_CONTAINER_NAME'] }
    else { $ContainerName = 'sql_server_asistencias' }
}
$SqlPassword = $Password
if (-not $SqlPassword) { $SqlPassword = $dbEnv['SQL_CONTAINER_PASSWORD'] }
if (-not $SqlPassword) { $SqlPassword = $env:MSSQL_SA_PASSWORD }
if (-not $SqlPassword) { $SqlPassword = $infraEnv['MSSQL_SA_PASSWORD'] }
if (-not $SqlPassword -or $SqlPassword -ceq 'CHANGE_ME') {
    throw 'No hay clave de SQL Server: defina SQL_CONTAINER_PASSWORD en GestioAsistenciaDB/.env (o MSSQL_SA_PASSWORD) o use -Password.'
}
if ($Database -notmatch '^[A-Za-z0-9_]+$') { throw "Nombre de base no valido: $Database" }
$isDefaultDb = ($Database -ieq $DefaultDatabase)

function Resolve-BackupPath([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    if ($Name.Contains('/')) { return $Name }
    return "$BackupDir/$Name"
}

$running = Invoke-Docker -DockerArgs @('inspect', '-f', '{{.State.Running}}', $ContainerName)
if ($running.ExitCode -ne 0 -or $running.Text.Trim() -ne 'true') { throw "El contenedor '$ContainerName' no esta en ejecucion." }

# ---------------------------------------------------------------------------------------------------- backend (puerto 8080)
function Assert-BackendStopped {
    if (-not $isDefaultDb) { Write-Step "Base '$Database' distinta de la del backend: no se revisa el puerto 8080."; return }
    $listeners = @(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0) { Write-Step 'Backend detenido (puerto 8080 libre).'; return }
    Write-Warning 'Hay un proceso escuchando en el puerto 8080: el backend usa esta base y debe estar detenido antes de restaurarla.'
    if (-not $StopBackend) {
        throw 'Detenga el backend (puerto 8080) y repita, o use -StopBackend para detener su java.exe.'
    }
    foreach ($pid8080 in ($listeners | Select-Object -ExpandProperty OwningProcess -Unique)) {
        $proc = Get-Process -Id $pid8080 -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -ieq 'java') {
            Write-Step "Deteniendo el backend (java.exe, PID $pid8080)."
            Stop-Process -Id $pid8080 -Force
        }
        else {
            throw "El puerto 8080 lo usa PID $pid8080 ($($proc.ProcessName)), que no es java.exe: detengalo a mano."
        }
    }
    Start-Sleep -Seconds 2
    if (@(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue).Count -gt 0) { throw 'El puerto 8080 sigue ocupado.' }
}

# ---------------------------------------------------------------------------------------------------- restaurar / respaldar
function Restore-Database([string]$BackupPath) {
    Write-Step "Verificando el respaldo $BackupPath"
    $exists = Invoke-Docker -DockerArgs @('exec', $ContainerName, 'test', '-f', $BackupPath)
    if ($exists.ExitCode -ne 0) { throw "No existe el respaldo $BackupPath en el contenedor $ContainerName." }

    $fl = Invoke-SqlInContainer -Query "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'$BackupPath';" -Raw
    Assert-Ok $fl 'RESTORE FILELISTONLY'
    $dataLogical = $null; $logLogical = $null
    foreach ($l in $fl.Lines) {
        $cols = $l.Split('|')
        if ($cols.Count -ge 3) {
            if ($cols[2].Trim() -eq 'D' -and -not $dataLogical) { $dataLogical = $cols[0].Trim() }
            if ($cols[2].Trim() -eq 'L' -and -not $logLogical) { $logLogical = $cols[0].Trim() }
        }
    }
    if (-not $dataLogical -or -not $logLogical) { throw 'No se pudieron leer los archivos logicos del respaldo.' }
    $dir = (Invoke-SqlInContainer -Query "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));").Lines |
        Where-Object { $_.Trim() -ne '' } | Select-Object -First 1
    if (-not $dir) { $dir = '/var/opt/mssql/data/' }
    $dir = $dir.Trim()
    if (-not $dir.EndsWith('/')) { $dir += '/' }

    Write-Step "Restaurando '$Database' (cierra las conexiones abiertas)."
    $sql = @"
SET NOCOUNT ON;
IF DB_ID(N'$Database') IS NOT NULL ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [$Database] FROM DISK = N'$BackupPath'
  WITH MOVE N'$dataLogical' TO N'$dir$Database.mdf', MOVE N'$logLogical' TO N'$dir${Database}_log.ldf', REPLACE, STATS = 25;
ALTER DATABASE [$Database] SET MULTI_USER;
"@
    $r = Invoke-SqlInContainer -Query $sql
    if ($r.ExitCode -ne 0) {
        $null = Invoke-SqlInContainer -Query "IF DB_ID(N'$Database') IS NOT NULL ALTER DATABASE [$Database] SET MULTI_USER;"
    }
    Assert-Ok $r 'RESTORE DATABASE'
}

# Copia temporal del repositorio de BD con el nombre de la base reescrito (solo si no es la base por defecto).
function New-WorkCopy {
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('reset-datos-prueba-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $work | Out-Null
    foreach ($rel in @('schema', 'migrations', 'deploy_schema.ps1', 'test\fixtures', 'test\test_datos_prueba_ampliados.sql')) {
        $src = Join-Path $DbRepo $rel
        if (-not (Test-Path $src)) { throw "Falta $src en el repositorio de BD ($DbRepo)." }
        $dst = Join-Path $work $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    }
    if (-not $isDefaultDb) {
        $latin1 = [System.Text.Encoding]::GetEncoding(28591)
        foreach ($f in (Get-ChildItem -LiteralPath $work -Recurse -File -Include '*.sql', 'deploy_schema.ps1')) {
            $text = $latin1.GetString([System.IO.File]::ReadAllBytes($f.FullName))
            $new = $text.Replace("[$DefaultDatabase]", "[$Database]")
            if ($f.Name -eq 'deploy_schema.ps1') { $new = [regex]::Replace($new, "(?<![A-Za-z0-9_])$DefaultDatabase(?![A-Za-z0-9_])", $Database) }
            if ($new -ne $text) { [System.IO.File]::WriteAllBytes($f.FullName, $latin1.GetBytes($new)) }
        }
    }
    return $work
}

function Invoke-BaseMode {
    $bak = Resolve-BackupPath $Backup
    if (-not $bak) { $bak = "$BackupDir/$CanonicalBackup" }
    $work = New-WorkCopy
    $remote = '/tmp/' + (Split-Path $work -Leaf)
    try {
        Restore-Database $bak

        Write-Step 'Copiando migraciones, esquema y fixture al contenedor.'
        $null = Invoke-Docker -DockerArgs @('exec', '-u', '0', $ContainerName, 'rm', '-rf', $remote)
        $null = Invoke-Docker -DockerArgs @('exec', '-u', '0', $ContainerName, 'mkdir', '-p', $remote)
        Assert-Ok (Invoke-Docker -DockerArgs @('cp', "$work\.", "${ContainerName}:$remote")) 'docker cp'
        $null = Invoke-Docker -DockerArgs @('exec', '-u', '0', $ContainerName, 'chmod', '-R', 'a+rX', $remote)

        $migs = @(Get-ChildItem -LiteralPath (Join-Path $work 'migrations') -Filter '*_up.sql' | ForEach-Object {
                if ($_.Name -match '^(\d+)_') { [pscustomobject]@{ N = [int]$Matches[1]; Name = $_.Name } }
            } | Where-Object { $_.N -ge $MigrationFrom -and $_.N -le $MigrationTo } | Sort-Object N)
        if ($migs.Count -eq 0) { throw "No hay migraciones $MigrationFrom a $MigrationTo en $DbRepo\migrations." }
        foreach ($m in $migs) {
            Write-Step "Migracion $($m.Name)"
            Assert-Ok (Invoke-SqlInContainer -Db $Database -File "$remote/migrations/$($m.Name)" -Variables @("MIGDIR=$remote/migrations")) "migracion $($m.Name)"
        }

        Write-Step 'Desplegando el esquema (deploy_schema.ps1).'
        $env:SQL_CONTAINER_NAME = $ContainerName
        $env:SQL_CONTAINER_PASSWORD = $SqlPassword
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $deployLog = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $work 'deploy_schema.ps1') 2>&1 | ForEach-Object { "$_" })
            $deployCode = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $previous }
        if ($deployCode -ne 0 -or ($deployLog -match '\[ERROR\]')) {
            throw ("deploy_schema.ps1 fallo (codigo $deployCode).`n" + (($deployLog | Select-Object -Last 15) -join "`n"))
        }

        if ($SkipFixture) { Write-Step 'Sin fixture (-SkipFixture): base canonica con migraciones y esquema.'; return }
        Write-Step 'Aplicando el fixture de datos de prueba ampliados.'
        $fx = Invoke-SqlInContainer -Db $Database -File ("$remote/" + $FixtureRel.Replace('\', '/'))
        Assert-Ok $fx 'fixture datos_prueba_ampliados.sql'
        $fx.Lines | Where-Object { $_ -match 'QA_DATOS' } | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

        if (-not $SkipTest) {
            Write-Step 'Verificando con test_datos_prueba_ampliados.sql.'
            $t = Invoke-SqlInContainer -Db $Database -File ("$remote/" + $TestRel.Replace('\', '/'))
            $passes = @($t.Lines | Where-Object { $_ -match '^TEST_PASS:QA_DATOS_' })
            $passes | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
            if ($t.ExitCode -ne 0 -or ($t.Lines -match 'TEST FAILED') -or $passes.Count -lt 11) {
                throw ("La verificacion del fixture fallo ($($passes.Count) casos aprobados).`n" + (($t.Lines | Where-Object { $_ -match 'TEST FAILED|Msg ' }) -join "`n"))
            }
        }
        Write-Step "Listo: '$Database' en estado base de pruebas ampliado."
        Write-Host '  Los usuarios QA existen solo en la BD; para ingresar hay que crearlos en el realm de Keycloak (ver docs/CREDENCIALES_PRUEBAS_LOCAL.md).' -ForegroundColor Yellow
    }
    finally {
        $null = Invoke-Docker -DockerArgs @('exec', '-u', '0', $ContainerName, 'rm', '-rf', $remote)
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\SQL_CONTAINER_PASSWORD -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------------------------------- despacho
try {
    switch ($Mode) {
        'Snapshot' {
            $target = Resolve-BackupPath $Backup
            if (-not $target) { $target = "$BackupDir/${Database}_QA_$(Get-Date -Format 'yyyyMMdd-HHmmss').bak" }
            Write-Step "Respaldando '$Database' en $target"
            $r = Invoke-SqlInContainer -Query "BACKUP DATABASE [$Database] TO DISK = N'$target' WITH INIT, COMPRESSION, CHECKSUM, STATS = 25;"
            Assert-Ok $r 'BACKUP DATABASE'
            Write-Host "Respaldo creado: $target" -ForegroundColor Green
            Write-Host "Para volver: infra.ps1 db-reset-qa -Mode Restore -Backup $(Split-Path $target -Leaf) -StopBackend -Yes"
        }
        'Restore' {
            if (-not $Backup) { throw '-Mode Restore requiere -Backup <archivo.bak>.' }
            if (-not $Yes) { throw "Restore reemplaza la base '$Database'. Detenga el backend (puerto 8080) y repita con -Yes (o -StopBackend -Yes)." }
            Assert-BackendStopped
            Restore-Database (Resolve-BackupPath $Backup)
            Write-Host "Base '$Database' restaurada desde $(Resolve-BackupPath $Backup). Reinicie el backend." -ForegroundColor Green
        }
        'Base' {
            if (-not $Yes) { throw "Base reemplaza la base '$Database' con el respaldo canonico y el fixture. Detenga el backend (puerto 8080) y repita con -Yes (o -StopBackend -Yes). Tome antes un -Mode Snapshot si quiere poder volver." }
            Assert-BackendStopped
            Invoke-BaseMode
        }
    }
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
exit 0
