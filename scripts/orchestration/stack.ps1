<#
.SYNOPSIS
    Levanta, detiene y muestra los contenedores de Asistencias UCO por secciones o por escenarios de prueba.

.DESCRIPTION
    Lee AsistenciasUCO-Infra/stack/secciones.json (secciones, memoria estimada, dependencias, conflictos y escenarios).

      list                      Secciones y escenarios disponibles.
      plan   <objetivos...>     Que se levantaria, en que orden y cuanta memoria (no cambia nada).
      up     <objetivos...>     Detiene lo que el objetivo no usa (salvo -Conservar), levanta en orden y espera la salud.
                                Con asis-app genera stack/generado/{backend,frontend}.env segun las secciones activas.
      down   [secciones...]     Detiene secciones (sin argumentos: todo menos asis-datos). Nunca borra volumenes.
      status                    Estado y memoria por seccion.
      build  [backend|frontend] Construye las imagenes asistencias-backend:develop / asistencias-frontend:develop.

    Un objetivo es una seccion (asis-datos, ext-seguridad, ext-mensajes, ext-parametros, asis-antivirus, asis-obs,
    asis-contingencia, asis-app) o un escenario (minimo, basico, mensajes, parametros, completo, soportes, observabilidad,
    contingencia). asis-datos se incluye siempre.

.EXAMPLE
    .\infra.ps1 stack up basico
    .\infra.ps1 stack up mensajes
    .\infra.ps1 stack plan completo
    .\infra.ps1 stack down
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'plan', 'up', 'down', 'status', 'build')]
    [string]$Accion = 'status',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Objetivo = @(),

    # up: no detiene las secciones que el objetivo no usa.
    [switch]$Conservar,
    # up: no espera la salud de los contenedores.
    [switch]$SinEsperar,
    # down: tambien detiene asis-datos.
    [switch]$IncluirDatos
)

Set-StrictMode -Version Latest
# Continue: en PowerShell 5.1 el stderr de docker (p. ej. "network not found" con 2>$null) seria un error terminante con
# Stop. Los fallos reales se detectan con $LASTEXITCODE y throw explicitos.
$ErrorActionPreference = 'Continue'

# Desde infra.ps1 los argumentos llegan reenviados como texto: '-Conservar' cae en $Objetivo en vez de enlazar el switch.
$restantes = @()
foreach ($o in $Objetivo) {
    switch -Regex ($o) {
        '^-(?i:Conservar)$' { $Conservar = [switch]::Present; continue }
        '^-(?i:SinEsperar)$' { $SinEsperar = [switch]::Present; continue }
        '^-(?i:IncluirDatos)$' { $IncluirDatos = [switch]::Present; continue }
        default { $restantes += $o }
    }
}
$Objetivo = $restantes

$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspace = (Resolve-Path (Join-Path $infraRoot '..')).Path
$stackDir = Join-Path $infraRoot 'stack'
$manifiesto = Get-Content (Join-Path $stackDir 'secciones.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$nombresSecciones = @($manifiesto.secciones.PSObject.Properties.Name)
$nombresEscenarios = @($manifiesto.escenarios.PSObject.Properties.Name)

function Get-Seccion([string]$nombre) { return $manifiesto.secciones.$nombre }

function Get-Prop($obj, [string]$nombre) {
    if ($null -ne $obj -and $obj.PSObject.Properties.Name -contains $nombre) { return $obj.$nombre }
    return $null
}

function Resolve-Ruta([string]$ruta, [string]$directorio) {
    if ($ruta.StartsWith('@stack/')) { return Join-Path $stackDir ($ruta.Substring(7)) }
    if ($ruta.StartsWith('~/')) { return Join-Path $env:USERPROFILE ($ruta.Substring(2)) }
    return Join-Path $directorio $ruta
}

function Resolve-Objetivo([string[]]$objetivos) {
    $lista = New-Object System.Collections.Generic.List[string]
    $lista.Add('asis-datos')
    foreach ($o in $objetivos) {
        if ($nombresEscenarios -contains $o) { foreach ($s in $manifiesto.escenarios.$o.secciones) { if (-not $lista.Contains($s)) { $lista.Add($s) } } }
        elseif ($nombresSecciones -contains $o) { if (-not $lista.Contains($o)) { $lista.Add($o) } }
        else { throw "'$o' no es una seccion ni un escenario. Use: .\infra.ps1 stack list" }
    }
    # Dependencias (requiere) antes de quien las pide; asis-app siempre al final.
    $cambio = $true
    while ($cambio) {
        $cambio = $false
        foreach ($s in @($lista)) {
            $req = Get-Prop (Get-Seccion $s) 'requiere'
            if ($req) { foreach ($r in $req) { if (-not $lista.Contains($r)) { $lista.Insert($lista.IndexOf($s), $r); $cambio = $true } } }
        }
    }
    if ($lista.Contains('asis-app')) { [void]$lista.Remove('asis-app'); $lista.Add('asis-app') }
    foreach ($s in $lista) {
        $conf = Get-Prop (Get-Seccion $s) 'conflictos'
        if ($conf) { foreach ($c in $conf) { if ($lista.Contains($c)) { throw "Las secciones '$s' y '$c' no pueden estar arriba a la vez (mismo puerto del PC)." } } }
    }
    return , $lista.ToArray()
}

function Get-ContenedoresSeccion([string]$nombre, [switch]$Anteriores) {
    $proyectos = @($nombre)
    if ($Anteriores) { $ant = Get-Prop (Get-Seccion $nombre) 'proyectosAnteriores'; if ($ant) { $proyectos = @($ant) } }
    $ids = @()
    foreach ($p in $proyectos) {
        $ids += @(docker ps -aq --filter "label=com.docker.compose.project=$p" 2>$null | Where-Object { $_ })
    }
    if (-not $Anteriores) { $ids += @(docker ps -aq --filter "label=asistencias.seccion=$nombre" 2>$null | Where-Object { $_ }) }
    return @($ids | Select-Object -Unique)
}

function Stop-Seccion([string]$nombre) {
    $todos = @(Get-ContenedoresSeccion $nombre) + @(Get-ContenedoresSeccion $nombre -Anteriores)
    $activos = @($todos | Where-Object { $_ } | Select-Object -Unique | Where-Object { (docker inspect -f '{{.State.Running}}' $_ 2>$null) -eq 'true' })
    if ($activos.Count -gt 0) {
        Write-Host "  - Deteniendo $nombre ($($activos.Count) contenedores)" -ForegroundColor DarkYellow
        docker stop -t 60 $activos | Out-Null
    }
}

# Secciones con las que se genera la configuracion de asis-app: las pedidas mas, con -Conservar, las que ya estan arriba.
# Sin esto `stack up asis-app -Conservar` (recrear solo la app tras un `stack build`) generaba backend.env como si
# Seguridad, Mensajes y Parametros no existieran: el Backend quedaba en modo legado contra un Keycloak apagado.
function Get-SeccionesConfiguracion([string[]]$secciones) {
    $efectivas = @($secciones)
    if ($Conservar) {
        foreach ($n in $nombresSecciones) {
            if ($efectivas -contains $n) { continue }
            $arriba = @(Get-ContenedoresSeccion $n | Where-Object { (docker inspect -f '{{.State.Running}}' $_ 2>$null) -eq 'true' })
            if ($arriba.Count -gt 0) { $efectivas += $n }
        }
    }
    return $efectivas
}

# El Backend no arranca en un estado util sin proveedor de identidad: se rechaza antes de detener o recrear nada.
function Assert-ProveedorIdentidad([string[]]$seccionesConfiguracion) {
    if (($seccionesConfiguracion -contains 'ext-seguridad') -or ($seccionesConfiguracion -contains 'asis-contingencia')) { return }
    throw ("asis-app necesita un proveedor de identidad y no hay ninguno entre las secciones ($($seccionesConfiguracion -join ', ')). " +
        "Use un escenario (.\infra.ps1 stack up basico) o, si Seguridad ya esta arriba, agregue -Conservar.")
}

function Initialize-Recursos {
    foreach ($red in $manifiesto.redesExternas) {
        docker network inspect $red 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { docker network create $red | Out-Null; Write-Host "  + Red $red creada" -ForegroundColor Gray }
    }
    foreach ($vol in $manifiesto.volumenesExternos) {
        docker volume inspect $vol 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { docker volume create --label "asistencias.stack=true" $vol | Out-Null; Write-Host "  + Volumen $vol creado (vacio)" -ForegroundColor Gray }
    }
}

function Read-EnvFile([string]$ruta) {
    $valores = [ordered]@{}
    if (-not (Test-Path $ruta)) { return $valores }
    foreach ($linea in Get-Content -LiteralPath $ruta -Encoding UTF8) {
        $t = $linea.Trim().TrimStart([char]0xFEFF)
        if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { continue }
        $valores[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim()
    }
    return $valores
}

function Read-EnvJs([string]$ruta) {
    $valores = @{}
    if (-not (Test-Path $ruta)) { return $valores }
    foreach ($m in [regex]::Matches((Get-Content -LiteralPath $ruta -Raw -Encoding UTF8), "window\.env\['([A-Z_]+)'\]\s*=\s*'([^']*)'")) {
        $valores[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    return $valores
}

function Write-EnvGenerado([string]$ruta, $valores, [string]$titulo) {
    $lineas = @("# $titulo", "# Generado por infra.ps1 stack $(Get-Date -Format s). No editar: se regenera en cada 'stack up' con asis-app.")
    foreach ($k in $valores.Keys) { $lineas += "$k=$($valores[$k])" }
    [System.IO.File]::WriteAllText($ruta, (($lineas -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

function New-ConfiguracionApp([string[]]$secciones) {
    $gen = Join-Path $stackDir 'generado'
    New-Item -ItemType Directory -Force -Path $gen | Out-Null

    # ---- Backend: el .env del checkout + direcciones dentro de asis-red + proveedores segun lo que este arriba ----
    $b = Read-EnvFile (Join-Path $workspace 'GestioAsistenciaBackend\.env')
    if ($b.Count -eq 0) { throw 'Falta GestioAsistenciaBackend\.env' }
    $b['SERVER_PORT'] = '8080'
    if (-not $b['SPRING_PROFILES_ACTIVE']) { $b['SPRING_PROFILES_ACTIVE'] = 'local' }
    $b['SPRING_DATASOURCE_URL'] = ($b['SPRING_DATASOURCE_URL'] -replace '//(localhost|127\.0\.0\.1)(:1433)?', '//sql_server_asistencias:1433')
    $b['MINIO_ENDPOINT'] = 'http://minio:9000'
    $b['CLAMAV_HOST'] = 'clamav'
    # Logs JSONL en la carpeta montada que lee Alloy (un archivo propio para distinguirlo del Backend local).
    $b['ASISTENCIAS_UCO_LOG_FILE'] = 'infra/observability/logs/backend-contenedor.jsonl'
    $b['ASISTENCIAS_UCO_LOG_FILE_PATTERN'] = 'infra/observability/logs/backend-contenedor.%d{yyyy-MM-dd}.%i.jsonl'
    if ($secciones -contains 'asis-obs') {
        $b['MANAGEMENT_OPENTELEMETRY_TRACING_EXPORT_OTLP_ENDPOINT'] = 'http://asis-obs-alloy:4318/v1/traces'
        $b['MANAGEMENT_TRACING_EXPORT_OTLP_ENABLED'] = 'true'
        # Prometheus recolecta por host.docker.internal:8090 (publicado solo en 127.0.0.1 del PC).
        $b['MANAGEMENT_SERVER_ADDRESS'] = '0.0.0.0'
    } else {
        # Sin asis-obs no hay recolector de trazas: el exportador OTLP fallaba cada pocos segundos ("Failed to export N spans",
        # ERROR con traza completa) y tapaba los logs utiles. Las trazas siguen activas (traceId/spanId en los logs JSONL).
        $b['MANAGEMENT_TRACING_EXPORT_OTLP_ENABLED'] = 'false'
        $b['MANAGEMENT_SERVER_ADDRESS'] = '127.0.0.1'
    }
    if ($b.Contains('APP_ADAPTERS_IDENTITY_PROVIDER')) { $b.Remove('APP_ADAPTERS_IDENTITY_PROVIDER') }

    # Emisor publico de los tokens (el que ve el navegador; en asis-red keycloak.localhost es alias del Keycloak de Seguridad).
    $kc = 'http://keycloak.localhost:19090'
    # Lo que el Backend exige en loopback lo reenvia el contenedor asis-app-enlaces (ver asis-app.compose.yml).
    $kcLoopback = 'http://localhost:19090'
    if ($secciones -contains 'ext-seguridad') {
        $lab = Read-EnvFile (Join-Path $env:USERPROFILE '.asistencias-security-lab\lab.env')
        foreach ($k in 'SECURITY_BASELINE_PEP_APPLICATION_CREDENTIAL_ASISTENCIAS', 'SECURITY_BASELINE_IDENTITY_ADMIN_CLIENT_SECRET') {
            if (-not $lab[$k]) { throw "lab.env no define $k (ejecute provision_asistencias.py)." }
        }
        $b['APP_ADAPTERS_SECURITY_PROVIDER'] = 'baseline'
        $b['SECURITY_BASELINE_PEP_URL'] = 'http://localhost:18081'
        $b['PEP_URL'] = 'http://localhost:18081'
        $b['SECURITY_BASELINE_PEP_APPLICATION_NAME'] = 'asistencias-uco'
        $b['SECURITY_BASELINE_PEP_ENVIRONMENT'] = 'dev'
        $b['SECURITY_BASELINE_PEP_APPLICATION_CREDENTIAL'] = $lab['SECURITY_BASELINE_PEP_APPLICATION_CREDENTIAL_ASISTENCIAS']
        $b['SECURITY_BASELINE_IDENTITY_ADMIN_CLIENT_SECRET'] = $lab['SECURITY_BASELINE_IDENTITY_ADMIN_CLIENT_SECRET']
        $b['SECURITY_BASELINE_PDP_URL'] = 'http://localhost:18080'
        $b['SECURITY_BASELINE_IDENTITY_SERVER_URL'] = $kcLoopback
        $b['SECURITY_BASELINE_ISSUER_URI'] = "$kc/realms/security-baseline"
        $b['SECURITY_BASELINE_JWK_SET_URI'] = "$kcLoopback/realms/security-baseline/protocol/openid-connect/certs"
        $b['KEYCLOAK_ISSUER_URI'] = "$kc/realms/security-baseline"
        # SEC-BASELINE-020 (0.1.14): consumidor de eventos de asignacion del PDP por RabbitMQ (asis-app-enlaces reenvia
        # 127.0.0.1:25672 al broker). Sin credenciales o sin applicationId en lab.env queda apagado (Seguridad 0.1.13).
        if ($lab['RABBITMQ_USERNAME'] -and $lab['RABBITMQ_PASSWORD'] -and $lab['ASISTENCIAS_PDP_APPLICATION_ID']) {
            $b['APP_ADAPTERS_ASSIGNMENT_EVENTS_ENABLED'] = 'true'
            $b['RABBITMQ_HOST'] = 'localhost'
            $b['RABBITMQ_PORT'] = '25672'
            $b['RABBITMQ_VIRTUAL_HOST'] = '/security'
            $b['RABBITMQ_USERNAME'] = $lab['RABBITMQ_USERNAME']
            $b['RABBITMQ_PASSWORD'] = $lab['RABBITMQ_PASSWORD']
            $b['SECURITY_BASELINE_ASSIGNMENT_EVENTS_APPLICATION_ID'] = $lab['ASISTENCIAS_PDP_APPLICATION_ID']
        } else {
            $b['APP_ADAPTERS_ASSIGNMENT_EVENTS_ENABLED'] = 'false'
            Write-Host '  * Eventos de asignacion (RabbitMQ) apagados: lab.env sin RABBITMQ_USERNAME/RABBITMQ_PASSWORD o ASISTENCIAS_PDP_APPLICATION_ID.' -ForegroundColor DarkYellow
        }
    } elseif ($secciones -contains 'asis-contingencia') {
        # El Keycloak propio emite tokens con http://localhost:8081 (lo que ve el navegador); asis-app-enlaces lo reenvia.
        $b['APP_ADAPTERS_SECURITY_PROVIDER'] = 'legacy'
        $b['KEYCLOAK_SERVER_URL'] = 'http://localhost:8081'
        $b['KEYCLOAK_ISSUER_URI'] = 'http://localhost:8081/realms/asistencias-uco'
    }

    if ($secciones -contains 'ext-mensajes') {
        $b['APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER'] = 'messageucolab'
        $b['MESSAGEUCOLAB_URL'] = 'http://ext-mensajes-kong:8000'
        $b['MESSAGEUCOLAB_TOKEN_URI'] = "$kcLoopback/realms/security-baseline/protocol/openid-connect/token"
        $b['MESSAGEUCOLAB_PULSAR_URL'] = 'pulsar://pulsar:6650'
    } else {
        $b['APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER'] = 'sqlserver'
        $b['MESSAGEUCOLAB_EVENTS_ENABLED'] = 'false'
    }
    if ($secciones -contains 'ext-parametros') {
        $b['APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER'] = 'catalogoparametros'
        $b['CATALOGO_PARAMETROS_BASE_URL'] = 'http://ext-parametros-app:8080/catalogo-parametros/api/v1'
    } else {
        $b['APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER'] = 'sqlserver'
    }
    Write-EnvGenerado (Join-Path $gen 'backend.env') $b 'Backend de Asistencias UCO en contenedor (asis-app)'

    # ---- Frontend: ids del laboratorio (no secretos) desde los env.js locales; direcciones vistas por el navegador ----
    $fe = Join-Path $workspace 'GestioAsistenciaFrontend'
    $js = Read-EnvJs (Join-Path $fe 'public\assets\env.js')
    foreach ($kv in (Read-EnvJs (Join-Path $fe 'src\assets\env.js')).GetEnumerator()) { $js[$kv.Key] = $kv.Value }
    $f = [ordered]@{}
    $f['API_URL'] = 'http://localhost:8080/api/v1'
    $f['USE_MOCKS'] = 'false'
    if ($secciones -contains 'asis-contingencia' -and -not ($secciones -contains 'ext-seguridad')) {
        $f['SECURITY_PROVIDER'] = 'legacy'
        $f['KEYCLOAK_URL'] = 'http://localhost:8081'
        $f['KEYCLOAK_REALM'] = 'asistencias-uco'
        $f['KEYCLOAK_CLIENT_ID'] = 'asistencias-uco-frontend'
    } else {
        $f['SECURITY_PROVIDER'] = 'baseline'
        $f['SECURITY_BASELINE_URL'] = 'http://localhost:18080'
        $f['SECURITY_BASELINE_UI_URL'] = 'http://localhost:5175'
        $f['SECURITY_BASELINE_APPLICATION_ID'] = $js['SECURITY_BASELINE_APPLICATION_ID']
        $f['SECURITY_BASELINE_ISSUER_URL'] = "$kc/realms/security-baseline"
        $f['SECURITY_BASELINE_CLIENT_ID'] = 'asistencias-uco-spa'
    }
    if ($js.ContainsKey('CATALOGO_PARAMETROS_APPLICATION_ID')) { $f['CATALOGO_PARAMETROS_APPLICATION_ID'] = $js['CATALOGO_PARAMETROS_APPLICATION_ID'] }
    $f['MENSAJES_UI_DESDE_CATALOGO'] = $(if ($secciones -contains 'ext-mensajes') { 'true' } else { 'false' })
    Write-EnvGenerado (Join-Path $gen 'frontend.env') $f 'Frontend de Asistencias UCO en contenedor (asis-app)'

    $eventosAsignacion = $(if ($b['APP_ADAPTERS_ASSIGNMENT_EVENTS_ENABLED'] -eq 'true') { 'rabbitmq' } else { 'apagados' })
    Write-Host ("  * Configuracion de asis-app: seguridad={0}, mensajes={1}, parametros={2}, eventos-asignacion={3}" -f `
        $b['APP_ADAPTERS_SECURITY_PROVIDER'], $b['APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER'], $b['APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER'], $eventosAsignacion) -ForegroundColor Gray
}

function Invoke-Compose([string]$nombre, [string[]]$argumentos) {
    $s = Get-Seccion $nombre
    $dir = Join-Path $workspace $s.directorio
    $base = @('compose', '-p', $nombre, '--project-directory', $dir)
    foreach ($c in $s.compose) { $base += @('-f', (Resolve-Ruta $c $dir)) }
    foreach ($e in $s.envFiles) { $base += @('--env-file', (Resolve-Ruta $e $dir)) }
    $doppler = Get-Prop $s 'doppler'
    if ($doppler) {
        Push-Location $dir
        try { & doppler run --project $doppler.proyecto --config $doppler.config -- docker @base @argumentos }
        finally { Pop-Location }
    } else {
        & docker @base @argumentos
    }
    if ($LASTEXITCODE -ne 0) { throw "docker compose fallo en la seccion $nombre" }
}

function Wait-Salud([string]$nombre, [int]$segundos = 300) {
    $s = Get-Seccion $nombre
    $limite = (Get-Date).AddSeconds($segundos)
    foreach ($chequeo in $s.salud) {
        $tipo, $valor = $chequeo -split ':', 2
        $ok = $false
        while ((Get-Date) -lt $limite) {
            if ($tipo -eq 'contenedor') {
                $estado = docker inspect -f '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}sin-healthcheck{{end}}' $valor 2>$null
                if ($estado -eq 'running|healthy' -or $estado -eq 'running|sin-healthcheck') { $ok = $true; break }
                if ($estado -like 'exited*') { break }
            } elseif ($tipo -eq 'exec') {
                # exec:<contenedor>|<comando sh>: sano cuando el comando termina con 0 (p. ej. la salud real de Pulsar).
                $contenedor, $comando = $valor -split '\|', 2
                docker exec $contenedor sh -c $comando 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { $ok = $true; break }
            } else {
                try { if ((Invoke-WebRequest -UseBasicParsing $valor -TimeoutSec 5).StatusCode -eq 200) { $ok = $true; break } } catch { }
            }
            Start-Sleep -Seconds 5
        }
        if ($ok) { Write-Host "    ok  $chequeo" -ForegroundColor Green }
        else { Write-Host "    !!  $chequeo no quedo sano (ver: docker logs $valor)" -ForegroundColor Red }
    }
}

function Show-Plan([string[]]$secciones) {
    $total = 0
    foreach ($n in $secciones) {
        $s = Get-Seccion $n
        $total += [int]$s.memoriaMb
        Write-Host ("  {0,-18} {1,5} MB  {2}" -f $n, $s.memoriaMb, $s.descripcion)
    }
    $color = $(if ($total -gt $manifiesto.limiteMemoriaMb) { 'Red' } else { 'Green' })
    Write-Host ("  Memoria estimada: {0} MB de {1} MB" -f $total, $manifiesto.limiteMemoriaMb) -ForegroundColor $color
    return $total
}

switch ($Accion) {
    'list' {
        Write-Host "`nSecciones:" -ForegroundColor Cyan
        foreach ($n in $nombresSecciones) { $s = Get-Seccion $n; Write-Host ("  {0,-18} {1,5} MB  {2}" -f $n, $s.memoriaMb, $s.descripcion) }
        Write-Host "`nEscenarios:" -ForegroundColor Cyan
        foreach ($n in $nombresEscenarios) { $e = $manifiesto.escenarios.$n; Write-Host ("  {0,-15} {1}" -f $n, ($e.secciones -join ', ')); Write-Host ("  {0,-15} -> {1}" -f '', $e.pruebas) -ForegroundColor DarkGray }
    }
    'plan' {
        $secciones = Resolve-Objetivo $Objetivo
        Write-Host "`nPlan para: $($Objetivo -join ' ')" -ForegroundColor Cyan
        [void](Show-Plan $secciones)
        $sobran = @($nombresSecciones | Where-Object { $secciones -notcontains $_ })
        if (-not $Conservar) { Write-Host "  Se detendrian (si estan arriba): $($sobran -join ', ')" -ForegroundColor DarkGray }
    }
    'up' {
        if ($Objetivo.Count -eq 0) { throw 'Indique una seccion o un escenario. Use: .\infra.ps1 stack list' }
        $secciones = Resolve-Objetivo $Objetivo
        Write-Host "`n==> stack up $($Objetivo -join ' ')" -ForegroundColor Cyan
        $total = Show-Plan $secciones
        if ($total -gt $manifiesto.limiteMemoriaMb) { throw "La memoria estimada ($total MB) supera el limite ($($manifiesto.limiteMemoriaMb) MB). Levante menos secciones." }
        if ($secciones -contains 'asis-app') {
            foreach ($img in (Get-Seccion 'asis-app').requiereImagenes) {
                docker image inspect $img 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Falta la imagen $img. Construyala con: .\infra.ps1 stack build" }
            }
        }
        $seccionesConfiguracion = Get-SeccionesConfiguracion $secciones
        if ($secciones -contains 'asis-app') { Assert-ProveedorIdentidad $seccionesConfiguracion }
        Initialize-Recursos
        if (-not $Conservar) { foreach ($n in $nombresSecciones) { if ($secciones -notcontains $n) { Stop-Seccion $n } } }
        foreach ($n in $secciones) {
            $s = Get-Seccion $n
            Write-Host "  > $n" -ForegroundColor Cyan
            # Contenedores de los proyectos anteriores (antes de la reorganizacion) usan los mismos puertos: se detienen.
            $ant = @(Get-ContenedoresSeccion $n -Anteriores | Where-Object { (docker inspect -f '{{.State.Running}}' $_ 2>$null) -eq 'true' })
            if ($ant.Count -gt 0) { docker stop -t 60 $ant | Out-Null; Write-Host "    (detenidos $($ant.Count) contenedores del proyecto anterior)" -ForegroundColor DarkYellow }
            if ($n -eq 'asis-app') {
                $extra = @($seccionesConfiguracion | Where-Object { $secciones -notcontains $_ })
                if ($extra.Count -gt 0) { Write-Host "  * Configuracion con las secciones que ya estan arriba: $($extra -join ', ')" -ForegroundColor Gray }
                New-ConfiguracionApp $seccionesConfiguracion
            }
            Invoke-Compose $n (@('up', '-d', '--no-build', '--remove-orphans') + @($s.servicios))
            if (-not $SinEsperar) { Wait-Salud $n }
            if ($n -eq 'ext-seguridad' -and -not $SinEsperar) {
                # El realm del laboratorio no debe permitir auto-registro (cuentas solo por el flujo de la app).
                try { & (Join-Path $infraRoot 'scripts\security\Disable-KeycloakSelfRegistration.ps1') }
                catch { Write-Host "    !!  no se pudo desactivar el auto-registro de Keycloak: $($_.Exception.Message)" -ForegroundColor Red }
            }
        }
        Write-Host "`nListo. Direcciones:" -ForegroundColor Cyan
        foreach ($n in $secciones) { foreach ($u in (Get-Seccion $n).urls) { Write-Host "  [$n] $u" } }
        foreach ($o in $Objetivo) { if ($nombresEscenarios -contains $o) { Write-Host "`nPruebas del escenario '$o': $($manifiesto.escenarios.$o.pruebas)" -ForegroundColor Cyan } }
    }
    'down' {
        $objetivos = $(if ($Objetivo.Count -gt 0) { $Objetivo } else { @($nombresSecciones | Where-Object { $IncluirDatos -or $_ -ne 'asis-datos' }) })
        foreach ($n in $objetivos) {
            if ($nombresSecciones -notcontains $n) { throw "'$n' no es una seccion." }
            if ($n -eq 'asis-datos' -and -not $IncluirDatos -and $Objetivo.Count -eq 0) { continue }
            Stop-Seccion $n
        }
        Write-Host 'Listo (los volumenes no se tocan).' -ForegroundColor Green
    }
    'status' {
        $memoria = @{}
        foreach ($l in (docker stats --no-stream --format '{{.Name}}|{{.MemUsage}}' 2>$null)) { $p = $l -split '\|'; $memoria[$p[0]] = ($p[1] -split '/')[0].Trim() }
        Write-Host "`nSeccion            Arriba  Contenedores" -ForegroundColor Cyan
        foreach ($n in $nombresSecciones) {
            $ids = @(Get-ContenedoresSeccion $n)
            $arriba = @($ids | Where-Object { (docker inspect -f '{{.State.Running}}' $_ 2>$null) -eq 'true' })
            $detalle = @($arriba | ForEach-Object { $c = (docker inspect -f '{{.Name}}' $_).TrimStart('/'); "$c ($($memoria[$c]))" }) -join ', '
            Write-Host ("  {0,-18} {1,2}/{2,-3} {3}" -f $n, $arriba.Count, $ids.Count, $detalle)
            $ant = @(Get-ContenedoresSeccion $n -Anteriores | Where-Object { (docker inspect -f '{{.State.Running}}' $_ 2>$null) -eq 'true' })
            if ($ant.Count -gt 0) { Write-Host ("  {0,-18} ({1} contenedores del proyecto anterior siguen arriba)" -f '', $ant.Count) -ForegroundColor DarkYellow }
        }
        $total = docker info --format '{{.MemTotal}}' 2>$null
        if ($total) { Write-Host ("`nMemoria de la VM de Docker: {0:N1} GB" -f ([double]$total / 1GB)) -ForegroundColor DarkGray }
    }
    'build' {
        $cuales = $(if ($Objetivo.Count -gt 0) { $Objetivo } else { @('backend', 'frontend') })
        foreach ($c in $cuales) {
            switch ($c) {
                'backend' {
                    $repo = Join-Path $workspace 'GestioAsistenciaBackend'
                    $sha = (git -C $repo rev-parse --short HEAD); $rama = (git -C $repo rev-parse --abbrev-ref HEAD)
                    $settings = Join-Path $env:USERPROFILE '.m2\settings.xml'
                    if (-not (Test-Path $settings)) { throw "Falta $settings (credenciales de GitHub Packages para el starter de MessageUcoLab)." }
                    Write-Host "==> asistencias-backend:develop desde $rama@$sha (corre mvnw verify dentro del build)" -ForegroundColor Cyan
                    $env:DOCKER_BUILDKIT = '1'
                    & docker build --secret "id=m2settings,src=$settings" --label "org.opencontainers.image.revision=$sha" -t asistencias-backend:develop -t "asistencias-backend:$sha" $repo
                    if ($LASTEXITCODE -ne 0) { throw 'Fallo el build del Backend.' }
                }
                'frontend' {
                    $repo = Join-Path $workspace 'GestioAsistenciaFrontend'
                    $sha = (git -C $repo rev-parse --short HEAD); $rama = (git -C $repo rev-parse --abbrev-ref HEAD)
                    Write-Host "==> asistencias-frontend:develop desde $rama@$sha" -ForegroundColor Cyan
                    & docker build --label "org.opencontainers.image.revision=$sha" -t asistencias-frontend:develop -t "asistencias-frontend:$sha" $repo
                    if ($LASTEXITCODE -ne 0) { throw 'Fallo el build del Frontend.' }
                }
                default { throw "build acepta backend o frontend, no '$c'." }
            }
        }
    }
}
