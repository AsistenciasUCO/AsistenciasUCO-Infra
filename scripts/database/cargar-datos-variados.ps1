<#
.SYNOPSIS
    Carga el conjunto de datos de prueba variado (73 usuarios, 7 programas, 40 grupos, historial y flujos) de punta a punta.

.DESCRIPTION
    Compatible con Windows PowerShell 5.1. Usa GestioAsistenciaDB/scripts/datos-prueba (scripts SQL y usuarios) y el
    aprovisionamiento de Seguridad del Backend (provision_asistencias.py dataset-users). Acciones:
      Cargar     DESTRUCTIVO (exige -Yes). Respalda la base actual en /var/opt/mssql/backup, detiene el backend
                 (contenedor asis-app-backend, o el java.exe del puerto 8080 con -StopBackend), borra la base, despliega el
                 esquema (deploy_schema.ps1), ejecuta 01..04 y vuelve a arrancar el backend en contenedor. Luego hace
                 Seguridad y Verificar salvo -SinSeguridad / -SinVerificar.
      Seguridad  Cuentas de Keycloak, contraseña común, roles, identidad y perfiles del PDP para los 73 usuarios (idempotente).
      Verificar  Solo lectura: inicia sesión con un usuario de cada caso y comprueba lo que cada rol puede ver.
      Catalogo   Con el Catálogo de Parámetros arriba (escenario parametros), empuja al Catálogo los valores que los datos de
                 prueba fijan solo en la BD (hoy RED.CIDRS_CAMPUS con los rangos de Docker); si no, el Backend, que toma el
                 Catálogo como fuente de verdad, los revertiría al arrancar. Cargar lo hace solo al final (se omite si el
                 Catálogo no está arriba).
    La contraseña común de laboratorio se toma de ASISTENCIAS_DATASET_PASSWORD o de AGENTS.md (sección 7); nunca se imprime.
    La clave de SQL Server sale de -Password, GestioAsistenciaDB/.env, MSSQL_SA_PASSWORD o AsistenciasUCO-Infra/stack/.env.
    Requiere el laboratorio de Seguridad aprovisionado (%USERPROFILE%\.asistencias-security-lab\lab.env) y Python 3 de
    Windows (-Python, ASISTENCIAS_PYTHON o el lanzador py; el python de MSYS no sirve).

.EXAMPLE
    .\infra.ps1 datos-prueba cargar -Yes
    .\infra.ps1 datos-prueba seguridad
    .\infra.ps1 datos-prueba verificar
    .\infra.ps1 datos-prueba catalogo
#>
[CmdletBinding()]
param(
    [ValidateSet('Cargar', 'Seguridad', 'Verificar', 'Catalogo')]
    [string]$Accion = 'Verificar',
    [switch]$Yes,
    [switch]$StopBackend,
    [switch]$SinSeguridad,
    [switch]$SinVerificar,
    [switch]$SinPdp,
    [string]$Python,
    [string]$Password,
    [string]$ContainerName = 'sql_server_asistencias',
    [string]$BackendContainer = 'asis-app-backend',
    [string]$DbRepo,
    [string]$BackendRepo
)

$ErrorActionPreference = 'Stop'
$Database = 'gestionasistenciadb'
. (Join-Path $PSScriptRoot '..\orchestration\pdp-lib.ps1')
$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspace = (Resolve-Path (Join-Path $infraRoot '..')).Path
if (-not $DbRepo) { $DbRepo = Join-Path $workspace 'GestioAsistenciaDB' }
if (-not $BackendRepo) { $BackendRepo = Join-Path $workspace 'GestioAsistenciaBackend' }
$datosDir = Join-Path $DbRepo 'scripts\datos-prueba'
$usuariosJson = Join-Path $datosDir 'usuarios_datos_prueba.json'
$provision = Join-Path $BackendRepo 'infra\security-baseline\scripts\provision_asistencias.py'
$verificador = Join-Path $infraRoot 'scripts\tests\verificar_datos_prueba.py'

function Write-Step([string]$Text) { Write-Host "[datos-prueba] $Text" -ForegroundColor Cyan }

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

# docker sin que el stderr de un ejecutable nativo aborte el script en PS 5.1
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& $Exe @Arguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $code; Lines = $lines; Text = ($lines -join "`n") }
}

function Invoke-Sql {
    param([string]$Query, [string]$File, [string]$Db = 'master')
    $a = @('exec', '-e', "SQLCMDPASSWORD=$script:SqlPassword", $ContainerName, '/opt/mssql-tools18/bin/sqlcmd',
           '-S', 'localhost', '-U', 'sa', '-C', '-b', '-I', '-f', '65001', '-d', $Db, '-W', '-s', '|', '-t', '3600')
    if ($File) { $a += @('-i', $File) } else { $a += @('-Q', $Query) }
    return Invoke-Native -Exe 'docker' -Arguments $a
}

function Assert-Ok($Result, [string]$What) {
    if ($Result.ExitCode -ne 0) {
        throw "Fallo: $What (codigo $($Result.ExitCode)).`n" + (($Result.Lines | Select-Object -Last 15) -join "`n")
    }
}

function Resolve-Python { return Resolve-PythonWindows $Python }

function Set-DatasetPassword {
    if ($env:ASISTENCIAS_DATASET_PASSWORD) { return }
    $agents = Join-Path $workspace 'AGENTS.md'
    if (Test-Path $agents) {
        $m = [regex]::Match((Get-Content -LiteralPath $agents -Raw -Encoding UTF8), 'Usuarios de Prueba \(Todos los Roles\):\*\*\s*Contrase\S*\s*`([^`]+)`')
        if ($m.Success) { $env:ASISTENCIAS_DATASET_PASSWORD = $m.Groups[1].Value; return }
    }
    throw 'Defina ASISTENCIAS_DATASET_PASSWORD con la contraseña común de laboratorio (AGENTS.md, sección 7).'
}

function Invoke-Seguridad {
    if (-not (Test-Path $provision)) { throw "No se encontro $provision" }
    Set-DatasetPassword
    $py = Resolve-Python
    Write-Step 'Seguridad: cuentas, roles y perfiles de los usuarios de prueba (tarda unos minutos).'
    Push-Location $BackendRepo
    try { & $py -X utf8 $provision dataset-users $usuariosJson; $code = $LASTEXITCODE } finally { Pop-Location }
    if ($code -ne 0) { throw "El aprovisionamiento de Seguridad termino con codigo $code." }
    if (-not $SinPdp) {
        if (-not (Invoke-PdpProvision -BackendRepo $BackendRepo -PythonExe $py)) {
            Write-Host '    !!  PDP con diferencias (use -SinPdp para omitir este paso).' -ForegroundColor Yellow
        }
    }
}

function Invoke-Verificar {
    Set-DatasetPassword
    $py = Resolve-Python
    Write-Step 'Verificacion de acceso y visibilidad por rol (solo lectura).'
    & $py -X utf8 $verificador --backend-repo $BackendRepo
    if ($LASTEXITCODE -ne 0) { throw 'La verificacion por rol encontro diferencias (ver las lineas XX).' }
}

function Invoke-Catalogo {
    # Alinea el Catalogo con los datos de prueba (solo si ext-parametros-app corre). Nunca imprime claves ni tokens.
    $corre = (Invoke-Native -Exe 'docker' -Arguments @('inspect', '-f', '{{.State.Running}}', 'ext-parametros-app')).Text.Trim() -eq 'true'
    if (-not $corre) {
        Write-Step 'Catalogo de Parametros no esta arriba (escenario parametros): se omite el empuje de valores de prueba.'
        return
    }
    $script = Join-Path $PSScriptRoot 'sincronizar_catalogo_parametros.py'
    $py = Resolve-Python
    Write-Step 'Catalogo de Parametros: empujando los valores de los datos de prueba (evento -> el Backend los aplica a la BD).'
    & $py -X utf8 -I $script --backend-repo $BackendRepo --db-repo $DbRepo
    if ($LASTEXITCODE -eq 1) { Write-Host '    !!  El empuje al Catalogo fallo; el Backend podria revertir RED.CIDRS_CAMPUS.' -ForegroundColor Yellow }
}

function Wait-Healthy([string]$Name, [int]$Seconds = 240) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $state = (Invoke-Native -Exe 'docker' -Arguments @('inspect', '-f', '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}', $Name)).Text.Trim()
        if ($state -eq 'healthy' -or $state -eq 'running') { return $state }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    throw "El contenedor $Name no quedo saludable en $Seconds s (estado: $state)."
}

function Invoke-Cargar {
    if (-not $Yes) { throw 'Cargar reemplaza la base gestionasistenciadb: repita con -Yes.' }
    foreach ($f in @('01_estructura.sql', '02_sesiones.sql', '03_asistencia.sql', '04_flujos.sql')) {
        if (-not (Test-Path (Join-Path $datosDir $f))) { throw "Falta $f en $datosDir (genere con generar_datos_prueba.py)." }
    }
    $dbEnv = Read-EnvFile (Join-Path $DbRepo '.env')
    $stackEnv = Read-EnvFile (Join-Path $infraRoot 'stack\.env')
    $script:SqlPassword = $Password
    if (-not $script:SqlPassword) { $script:SqlPassword = $dbEnv['SQL_CONTAINER_PASSWORD'] }
    if (-not $script:SqlPassword) { $script:SqlPassword = $env:MSSQL_SA_PASSWORD }
    if (-not $script:SqlPassword) { $script:SqlPassword = $stackEnv['MSSQL_SA_PASSWORD'] }
    if (-not $script:SqlPassword -or $script:SqlPassword -ceq 'CHANGE_ME') { throw 'No hay clave de SQL Server (-Password, GestioAsistenciaDB/.env o stack/.env).' }
    $running = Invoke-Native -Exe 'docker' -Arguments @('inspect', '-f', '{{.State.Running}}', $ContainerName)
    if ($running.Text.Trim() -ne 'true') { throw "El contenedor '$ContainerName' no esta en ejecucion (.\infra.ps1 stack up minimo)." }

    $existe = Invoke-Sql -Query "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = '$Database';"
    Assert-Ok $existe 'consultar la base'
    if (($existe.Lines | Where-Object { $_ -match '^\s*1\s*$' }).Count -gt 0) {
        $bak = "/var/opt/mssql/backup/${Database}_antes_datos_variados_$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        Write-Step "Respaldando la base actual en $bak"
        Assert-Ok (Invoke-Native -Exe 'docker' -Arguments @('exec', $ContainerName, 'mkdir', '-p', '/var/opt/mssql/backup')) 'crear el directorio de respaldos'
        Assert-Ok (Invoke-Sql -Query "BACKUP DATABASE [$Database] TO DISK = N'$bak' WITH COPY_ONLY, COMPRESSION, INIT, CHECKSUM;") 'respaldar la base'
    }

    $backendEnContenedor = (Invoke-Native -Exe 'docker' -Arguments @('inspect', '-f', '{{.State.Running}}', $BackendContainer)).Text.Trim() -eq 'true'
    if ($backendEnContenedor) {
        Write-Step "Deteniendo el backend en contenedor ($BackendContainer)."
        Assert-Ok (Invoke-Native -Exe 'docker' -Arguments @('stop', $BackendContainer)) 'detener el backend'
    }
    else {
        $listeners = @(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)
        if ($listeners.Count -gt 0) {
            if (-not $StopBackend) { throw 'Hay un backend local en el puerto 8080: detengalo o use -StopBackend.' }
            foreach ($id in ($listeners | Select-Object -ExpandProperty OwningProcess -Unique)) {
                $proc = Get-Process -Id $id -ErrorAction SilentlyContinue
                if (-not $proc -or $proc.ProcessName -ine 'java') { throw "El puerto 8080 lo usa PID $id, que no es java.exe." }
                Write-Step "Deteniendo el backend local (java.exe, PID $id)."
                Stop-Process -Id $id -Force
            }
        }
    }

    try {
        Write-Step 'Borrando la base y desplegando el esquema desde cero (unos 3 minutos).'
        Assert-Ok (Invoke-Sql -Query "IF DB_ID('$Database') IS NOT NULL BEGIN ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Database]; END") 'borrar la base'
        $deploy = Invoke-Native -Exe 'powershell.exe' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $DbRepo 'deploy_schema.ps1'),
                                                               '-ContainerName', $ContainerName, '-Password', $script:SqlPassword)
        if ($deploy.ExitCode -ne 0 -or ($deploy.Lines -match '\[ERROR\]')) {
            throw ("deploy_schema.ps1 fallo (codigo $($deploy.ExitCode)).`n" + (($deploy.Lines | Select-Object -Last 15) -join "`n"))
        }

        # docker cp deja los archivos como root: la copia anterior solo se puede borrar como root.
        Assert-Ok (Invoke-Native -Exe 'docker' -Arguments @('exec', '-u', 'root', $ContainerName, 'rm', '-rf', '/tmp/datos-prueba')) 'limpiar /tmp/datos-prueba'
        Assert-Ok (Invoke-Native -Exe 'docker' -Arguments @('cp', $datosDir, "${ContainerName}:/tmp/datos-prueba")) 'copiar los scripts al contenedor'
        foreach ($f in @('01_estructura.sql', '02_sesiones.sql', '03_asistencia.sql', '04_flujos.sql')) {
            Write-Step "Ejecutando $f"
            $r = Invoke-Sql -File "/tmp/datos-prueba/$f" -Db $Database
            Assert-Ok $r $f
            $fallos = @($r.Lines | Where-Object { $_ -match '^Msg \d+' })
            if ($fallos.Count -gt 0) { throw "$f reporto errores:`n" + ($fallos -join "`n") }
            $r.Lines | Where-Object { $_ -match '^(periodo|tomas|alertas|01_estructura)' -or $_ -match '^\d{4}-\d\|' -or $_ -match '^\d+\|\d+\|\d+\|\d+$' } |
                ForEach-Object { Write-Host "    $_" }
        }
    }
    finally {
        if ($backendEnContenedor) {
            Write-Step "Arrancando el backend ($BackendContainer)."
            Assert-Ok (Invoke-Native -Exe 'docker' -Arguments @('start', $BackendContainer)) 'arrancar el backend'
            Write-Step "Backend: $(Wait-Healthy $BackendContainer)"
        }
        else {
            Write-Step 'Arranque de nuevo el backend local para usar la base nueva.'
        }
    }
}

switch ($Accion) {
    'Cargar' {
        # Falla rapido (antes de tocar la base) si no hay Python utilizable para Seguridad.
        if (-not $SinSeguridad) { [void](Resolve-Python) }
        Invoke-Cargar
        if (-not $SinSeguridad) { Invoke-Seguridad }
        Invoke-Catalogo
        if (-not $SinSeguridad -and -not $SinVerificar) { Invoke-Verificar }
    }
    'Seguridad' { Invoke-Seguridad }
    'Verificar' { Invoke-Verificar }
    'Catalogo' { Invoke-Catalogo }
}
Write-Step 'Listo. Usuarios por rol: GestioAsistenciaDB/scripts/datos-prueba/USUARIOS.md'
