<#
.SYNOPSIS
  Prueba E2E del Catalogo de Parametros 0.1.17 y su integracion con el backend (INT-004: consulta M2M y eventos Pulsar).
.DESCRIPTION
  Modelo M2M: el backend obtiene un token con client_credentials (identidad CATALOGO_PARAMETROS_M2M_* de
  GestioAsistenciaBackend/.env, que se lee sin mostrarse) y consulta GET /parametros/consulta/m2m; los cambios llegan por el
  evento MetadataUpdated del broker Pulsar del Catalogo y el backend los aplica a dbo.CatalogoParametro (auditados en
  dbo.SincronizacionParametroExterno). Requiere el escenario `parametros` arriba, el backend con
  APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=catalogoparametros y un Python 3 de Windows (ASISTENCIAS_PYTHON) para abrir la
  sesion web del administrador del laboratorio y cambiar el valor en el Catalogo (usa lab_pdp.py del Backend).
  Secciones: salud, contrato M2M (200/401, filtro por nombre), API administrativa protegida, backend, regla real de
  registro QR con el dominio del Catalogo, y flujo por eventos: cambio valido (APLICADO), mismo valor (SIN_CAMBIOS, sin
  nueva escritura) y valor invalido (RECHAZADO, la BD conserva el valor); el valor del Catalogo se restaura siempre.
  Salida [OK]/[FALLO]; termina con exit 1 si alguna comprobacion falla. Nunca imprime secretos ni tokens.
#>
param(
    [string]$BackendEnvPath = (Join-Path $PSScriptRoot '..\..\..\GestioAsistenciaBackend\.env'),
    [string]$BackendRepo = (Join-Path $PSScriptRoot '..\..\..\GestioAsistenciaBackend'),
    [string]$CatalogoBaseUrl = 'http://localhost:8081/catalogo-parametros/api/v1',
    [string]$BackendUrl = 'http://localhost:8080/api/v1',
    [string]$BackendHealthUrl = 'http://localhost:8090/actuator/health',
    [string]$InfraEnvPath = (Join-Path $PSScriptRoot '..\..\.env'),
    [string]$SqlContainer = 'sql_server_asistencias',
    [string]$BackendContainer = 'asis-app-backend',
    [string]$Python,
    # Parametro entero que se cambia (y restaura) para probar los eventos; debe existir en AsistenciasUCO/Desarrollo.
    [string]$ParametroEvento = 'ASISTENCIA_QR.LIMITE_IP_POR_MINUTO',
    [int]$EsperaEventoSeg = 40,
    # Omite la seccion de eventos (la unica que cambia valores en el Catalogo y necesita Python).
    [switch]$OmitirEventos
)

$ErrorActionPreference = 'Stop'
$script:Fallos = 0
. (Join-Path $PSScriptRoot '..\orchestration\pdp-lib.ps1')

function Resultado([bool]$ok, [string]$descripcion) {
    if ($ok) { Write-Host "[OK] $descripcion" } else { Write-Host "[FALLO] $descripcion"; $script:Fallos++ }
}

# Devuelve @{ Codigo; Cuerpo; Ms }; Codigo 0 = sin respuesta (timeout o conexion rechazada).
function Invocar([string]$metodo, [string]$url, [hashtable]$cabeceras = @{}, $cuerpo = $null, [int]$timeoutSeg = 40, [string]$tipo = 'application/json; charset=utf-8') {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $codigo = 0; $texto = ''; $script:UltimoError = $null
    try {
        $p = @{ Uri = $url; Method = $metodo; Headers = $cabeceras; UseBasicParsing = $true; TimeoutSec = $timeoutSeg }
        if ($null -ne $cuerpo -and "$cuerpo" -ne '') { $p.Body = [Text.Encoding]::UTF8.GetBytes("$cuerpo"); $p.ContentType = $tipo }
        $r = Invoke-WebRequest @p
        $codigo = [int]$r.StatusCode; $texto = $r.Content
        if ($texto -is [byte[]]) { $texto = [Text.Encoding]::UTF8.GetString($texto) }
    } catch {
        $script:UltimoError = $_.Exception.Message
        $resp = $_.Exception.Response
        if ($null -ne $resp) {
            $codigo = [int]$resp.StatusCode
            try {
                $sr = New-Object IO.StreamReader($resp.GetResponseStream())
                $texto = $sr.ReadToEnd(); $sr.Close()
            } catch { $texto = '' }
        }
    }
    $sw.Stop()
    if ($codigo -eq 0 -and $script:UltimoError) { Write-Host "      (sin respuesta: $($script:UltimoError))" }
    return @{ Codigo = $codigo; Cuerpo = $texto; Ms = [int]$sw.ElapsedMilliseconds }
}

function LeerEnv([string]$ruta, [string]$clave) {
    foreach ($linea in Get-Content -Path $ruta -Encoding UTF8) {
        if ($linea -match "^\s*$clave\s*=\s*(.*)$") { return $Matches[1].Trim().Trim('"').Trim("'") }
    }
    return $null
}

Write-Host '== Prueba E2E Catalogo de Parametros (M2M + eventos) =='

if (-not (Test-Path $BackendEnvPath)) { Resultado $false "No existe el .env del backend: $BackendEnvPath"; exit 1 }
$clientId = LeerEnv $BackendEnvPath 'CATALOGO_PARAMETROS_M2M_CLIENT_ID'
$clientSecret = LeerEnv $BackendEnvPath 'CATALOGO_PARAMETROS_M2M_CLIENT_SECRET'
$tokenUri = LeerEnv $BackendEnvPath 'CATALOGO_PARAMETROS_M2M_TOKEN_URI'
$definidas = -not [string]::IsNullOrWhiteSpace($clientId) -and -not [string]::IsNullOrWhiteSpace($clientSecret) -and -not [string]::IsNullOrWhiteSpace($tokenUri)
Resultado $definidas 'El .env del backend define CATALOGO_PARAMETROS_M2M_CLIENT_ID, _CLIENT_SECRET y _TOKEN_URI'
if (-not $definidas) { exit 1 }

# 1. Salud del Catalogo y de su frontend
$origen = ([Uri]$CatalogoBaseUrl).GetLeftPart([UriPartial]::Authority)
$r = Invocar 'GET' "$origen/actuator/health" @{} $null 15
Resultado (($r.Codigo -eq 200) -and ($r.Cuerpo -match '"status"\s*:\s*"UP"')) "Catalogo: /actuator/health responde 200 y UP (HTTP $($r.Codigo))"
$r = Invocar 'GET' 'http://localhost:4201/' @{} $null 15
Resultado ($r.Codigo -eq 200) "Frontend del Catalogo (4201) responde 200 (HTTP $($r.Codigo))"
$r = Invocar 'GET' 'http://localhost:4201/parametros-ui/parametros-administration.js' @{} $null 15
Resultado ($r.Codigo -eq 200) "Microfrontend de administracion (parametros-administration.js) responde 200 (HTTP $($r.Codigo))"

# 2. Token M2M (client_credentials contra el Keycloak de Seguridad)
$form = 'grant_type=client_credentials&client_id=' + [Uri]::EscapeDataString($clientId) + '&client_secret=' + [Uri]::EscapeDataString($clientSecret)
$r = Invocar 'POST' $tokenUri @{} $form 20 'application/x-www-form-urlencoded'
$token = $null
if ($r.Codigo -eq 200) { try { $token = ($r.Cuerpo | ConvertFrom-Json).access_token } catch { } }
Resultado (-not [string]::IsNullOrWhiteSpace($token)) "Token M2M por client_credentials -> 200 con access_token (HTTP $($r.Codigo))"
if ([string]::IsNullOrWhiteSpace($token)) { exit 1 }
$cab = @{ Authorization = "Bearer $token"; Accept = 'application/json' }

# 3. Contrato de consulta M2M
$m2m = "$CatalogoBaseUrl/parametros/consulta/m2m"
$r = Invocar 'GET' $m2m $cab $null 40
Resultado ($r.Codigo -eq 200) "Catalogo: GET parametros/consulta/m2m con token -> 200 (HTTP $($r.Codigo))"
$json = $null
if ($r.Codigo -eq 200) { try { $json = $r.Cuerpo | ConvertFrom-Json } catch { } }
$app = $null; if ($null -ne $json -and $null -ne $json.aplicacion) { $app = $json.aplicacion.nombre }
$amb = $null; if ($null -ne $json -and $null -ne $json.ambiente) { $amb = $json.ambiente.nombre }
Resultado (($app -eq 'AsistenciasUCO') -and ($amb -eq 'Desarrollo')) "La respuesta identifica la aplicacion ($app) y el ambiente ($amb) de la identidad"
$params = @(); if ($null -ne $json -and $null -ne $json.parametros) { $params = @($json.parametros) }
Resultado ($params.Count -ge 20) "La respuesta trae al menos 20 parametros (hay $($params.Count))"
Resultado (($r.Codigo -eq 200) -and ($r.Ms -le 10000)) "Duracion de la consulta M2M: $($r.Ms) ms (limite 10000 ms, el timeout del backend)"
$dominioCatalogo = $null
$dom = $params | Where-Object { $_.parametro.nombre -eq 'REGISTRO.DOMINIO_CORREO_ESTUDIANTE' } | Select-Object -First 1
if ($null -ne $dom -and $null -ne $dom.metadatos) {
    foreach ($m in @($dom.metadatos)) { if ($null -ne $m.metadato -and "$($m.metadato.valor)".StartsWith('@')) { $dominioCatalogo = $m.metadato.valor; break } }
}
Resultado ($null -ne $dominioCatalogo) 'REGISTRO.DOMINIO_CORREO_ESTUDIANTE existe con un valor que empieza por @'

$r = Invocar 'GET' "${m2m}?nombre=REGISTRO.DOMINIO_CORREO_ESTUDIANTE" $cab $null 40
$uno = 0; try { $uno = @(($r.Cuerpo | ConvertFrom-Json).parametros).Count } catch { }
Resultado (($r.Codigo -eq 200) -and ($uno -eq 1)) "Filtro ?nombre= devuelve 1 parametro (HTTP $($r.Codigo), $uno)"
$r = Invocar 'GET' "${m2m}?nombre=NO.EXISTE.INT004" $cab $null 40
$ninguno = -1; try { $ninguno = @(($r.Cuerpo | ConvertFrom-Json).parametros).Count } catch { }
Resultado (($r.Codigo -eq 200) -and ($ninguno -eq 0)) "Un nombre inexistente devuelve 200 con parametros vacio (HTTP $($r.Codigo))"
$r = Invocar 'GET' $m2m @{} $null 40
Resultado ($r.Codigo -eq 401) "Catalogo: consulta M2M sin token -> 401 (HTTP $($r.Codigo))"
$r = Invocar 'GET' $m2m @{ Authorization = 'Bearer token-invalido' } $null 40
Resultado ($r.Codigo -eq 401) "Catalogo: consulta M2M con token invalido -> 401 (HTTP $($r.Codigo))"

# 4. API administrativa protegida por el PEP
$r = Invocar 'GET' "$CatalogoBaseUrl/organizaciones" @{} $null 20
Resultado ($r.Codigo -eq 401) "Catalogo: GET /organizaciones sin sesion -> 401 (HTTP $($r.Codigo))"
$r = Invocar 'GET' "$CatalogoBaseUrl/organizaciones" $cab $null 20
Resultado ($r.Codigo -eq 403) "Catalogo: la identidad M2M solo consulta; GET /organizaciones con su token -> 403 (HTTP $($r.Codigo))"

# 5. Backend
# El actuator (8090) solo escucha en loopback dentro del contenedor salvo que asis-obs este arriba; si no es alcanzable desde
# el host, se consulta desde dentro del contenedor del backend.
$r = Invocar 'GET' $BackendHealthUrl @{} $null 15
$origenSalud = $BackendHealthUrl
if ($r.Codigo -eq 0) {
    $origenSalud = "docker exec $BackendContainer (127.0.0.1:8090)"
    $txt = (& docker exec $BackendContainer wget -qO- http://127.0.0.1:8090/actuator/health 2>$null) -join ''
    $r = @{ Codigo = $(if ($txt) { 200 } else { 0 }); Cuerpo = $txt; Ms = 0 }
}
Resultado (($r.Codigo -eq 200) -and ($r.Cuerpo -match '"status"\s*:\s*"UP"')) "Backend: salud en $origenSalud responde UP (HTTP $($r.Codigo))"

# 6. Regla real del backend con el dominio del Catalogo (registro QR con correo no institucional; publico)
$cuerpo = @{
    token = ('A' * 43); pin = $null
    idTipoIdentificacion = [guid]::NewGuid().ToString()
    numeroIdentificacion = 1234567890
    primerNombre = 'Prueba'; segundoNombre = $null; primerApellido = 'Catalogo'; segundoApellido = $null
    correo = 'prueba.catalogo@gmail.com'; password = ('Pr' + [guid]::NewGuid().ToString('N') + '!')
} | ConvertTo-Json -Compress
$r = Invocar 'POST' "$BackendUrl/public/matricula-qr/registro" @{} $cuerpo 30
$esperado = ($r.Codigo -eq 400) -and ($r.Cuerpo -match 'VCE_001') -and ($null -ne $dominioCatalogo) -and $r.Cuerpo.Contains($dominioCatalogo)
Resultado $esperado "Backend: registro QR con correo no institucional -> 400 VCE_001 con el dominio del Catalogo $dominioCatalogo (HTTP $($r.Codigo))"
if (-not $esperado -and $r.Cuerpo.Length -gt 0) { Write-Host "      Respuesta: $($r.Cuerpo.Substring(0, [Math]::Min(300, $r.Cuerpo.Length)))" }

# 7. Flujo por eventos: Catalogo (API administrativa) -> Pulsar -> backend -> dbo.CatalogoParametro / SincronizacionParametroExterno
if ($OmitirEventos) {
    Write-Host '[OMITIDO] Flujo por eventos (-OmitirEventos)'
} else {
    $saPassword = LeerEnv $InfraEnvPath 'MSSQL_SA_PASSWORD'
    $py = $null
    try { $py = Resolve-PythonWindows $Python } catch { Resultado $false "Python 3 de Windows para la seccion de eventos: $($_.Exception.Message)" }
    $ayudante = Join-Path $PSScriptRoot '..\database\sincronizar_catalogo_parametros.py'
    if ([string]::IsNullOrWhiteSpace($saPassword)) {
        Resultado $false "MSSQL_SA_PASSWORD definido en $InfraEnvPath"
    } elseif ($null -ne $py) {
        $partes = $ParametroEvento -split '\.', 2
        $grupo = $partes[0]; $clave = $partes[1]
        function Sql([string]$consulta) {
            # La clave viaja en el entorno (-e sin valor), no en los argumentos de docker (visibles en la lista de procesos).
            $env:SQLCMDPASSWORD = $saPassword
            try {
                $salida = docker exec -e SQLCMDPASSWORD $SqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C `
                    -d gestionasistenciadb -h -1 -W -s '|' -b -Q "SET NOCOUNT ON; $consulta" 2>&1
                $codigo = $LASTEXITCODE
            } finally { Remove-Item Env:\SQLCMDPASSWORD -ErrorAction SilentlyContinue }
            if ($codigo -ne 0) { throw "sqlcmd fallo: $salida" }
            return @($salida | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        function EstablecerEnCatalogo([string]$valor) {
            $out = @(& $py -X utf8 -I $ayudante --backend-repo $BackendRepo --establecer "$ParametroEvento=$valor" 2>&1 | ForEach-Object { "$_" })
            if ($LASTEXITCODE -ne 0) { throw "No se pudo cambiar $ParametroEvento en el Catalogo: $($out -join ' / ')" }
            $antes = ($out | Where-Object { $_ -like 'ANTES=*' } | Select-Object -First 1)
            if ($null -eq $antes) { throw "El ayudante no informo el valor previo: $($out -join ' / ')" }
            return $antes.Substring(6)
        }
        # Espera hasta que haya una fila de auditoria nueva para el parametro con el resultado indicado; devuelve el resultado.
        function EsperarAuditoria([string]$desdeUtc, [string]$resultadoEsperado) {
            $limite = (Get-Date).AddSeconds($EsperaEventoSeg)
            do {
                $fila = @(Sql "SELECT TOP 1 resultado FROM dbo.SincronizacionParametroExterno WHERE grupo = '$grupo' AND clave = '$clave' AND fechaRegistroUtc > '$desdeUtc' AND idEvento IS NOT NULL ORDER BY fechaRegistroUtc DESC")
                if ($fila.Count -eq 1 -and $fila[0].Trim() -eq $resultadoEsperado) { return $resultadoEsperado }
                Start-Sleep -Milliseconds 700
            } while ((Get-Date) -lt $limite)
            if ($fila.Count -eq 1) { return $fila[0].Trim() }
            return '(sin evento)'
        }
        function Ahora { return @(Sql "SELECT CONVERT(VARCHAR(30), SYSUTCDATETIME(), 121)")[0].Trim() }
        function ValorBd { return @(Sql "SELECT CONVERT(NVARCHAR(400), valor) FROM dbo.CatalogoParametro WHERE grupo = '$grupo' AND clave = '$clave'")[0].Trim() }

        # Se restaura el valor que tenia el Catalogo (la fuente de verdad), no el de la BD: si estaban desincronizados,
        # escribir el de la BD dejaria el Catalogo cambiado.
        $originalCatalogo = $null
        try {
            $original = ValorBd
            $nuevo = [string]([int]$original + 1)

            # 7a. Cambio valido: APLICADO y la BD queda con el valor nuevo
            $t0 = Ahora
            $originalCatalogo = EstablecerEnCatalogo $nuevo
            $res = EsperarAuditoria $t0 'APLICADO'
            Resultado (($res -eq 'APLICADO') -and ((ValorBd) -eq $nuevo)) "Evento: $ParametroEvento $original -> $nuevo en el Catalogo; el backend lo aplico a la BD (auditoria $res)"

            # 7b. Mismo valor otra vez (PUT que el Catalogo vuelve a publicar): SIN_CAMBIOS y ninguna escritura nueva en la BD
            $fecha1 = @(Sql "SELECT CONVERT(VARCHAR(30), fechaModificacion, 121) FROM dbo.CatalogoParametro WHERE grupo = '$grupo' AND clave = '$clave'")[0].Trim()
            $t1 = Ahora
            [void](EstablecerEnCatalogo $nuevo)
            $res = EsperarAuditoria $t1 'SIN_CAMBIOS'
            $fecha2 = @(Sql "SELECT CONVERT(VARCHAR(30), fechaModificacion, 121) FROM dbo.CatalogoParametro WHERE grupo = '$grupo' AND clave = '$clave'")[0].Trim()
            Resultado (($res -eq 'SIN_CAMBIOS') -and ($fecha1 -eq $fecha2)) "Evento repetido con el mismo valor: auditoria $res y sin nueva escritura en la BD (fechaModificacion intacta)"

            # 7c. Valor invalido (entero negativo): RECHAZADO y la BD conserva el valor valido anterior
            $t2 = Ahora
            [void](EstablecerEnCatalogo '-5')
            $res = EsperarAuditoria $t2 'RECHAZADO'
            Resultado (($res -eq 'RECHAZADO') -and ((ValorBd) -eq $nuevo)) "Evento con valor invalido (-5): auditoria $res y la BD conserva $nuevo"
        } catch {
            Resultado $false "Flujo por eventos: $($_.Exception.Message)"
        } finally {
            if ($null -ne $originalCatalogo) {
                try {
                    [void](EstablecerEnCatalogo $originalCatalogo)
                    $limite = (Get-Date).AddSeconds($EsperaEventoSeg)
                    do { $actual = ValorBd; if ($actual -eq $originalCatalogo) { break }; Start-Sleep -Milliseconds 700 } while ((Get-Date) -lt $limite)
                    Resultado ($actual -eq $originalCatalogo) "Catalogo y BD restaurados: $ParametroEvento = $originalCatalogo (valor previo del Catalogo)"
                } catch {
                    Resultado $false "No se pudo restaurar $ParametroEvento (valor previo del Catalogo: $originalCatalogo): $($_.Exception.Message)"
                }
            }
        }
    }
}

Write-Host ''
if ($script:Fallos -gt 0) { Write-Host "Resultado: $($script:Fallos) comprobacion(es) fallida(s)"; exit 1 }
Write-Host 'Resultado: todas las comprobaciones pasaron'
exit 0
