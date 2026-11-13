<#
.SYNOPSIS
  Prueba E2E del Catalogo de Parametros y su integracion con el backend (INT-002).
.DESCRIPTION
  Lee CATALOGO_PARAMETROS_TOKEN_ID y CATALOGO_PARAMETROS_SECRETO del .env del backend sin mostrarlos.
  Las secciones 8 y 9 comprueban de donde sale el valor que usa el backend: no del valor por defecto en codigo (log
  por correlationId) ni de dbo.CatalogoParametro (dominio temporal solo en la BD, restaurado en un finally; usa
  MSSQL_SA_PASSWORD del .env de Infra). Requiere el backend con APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=catalogoparametros.
  Salida [OK]/[FALLO]; termina con exit 1 si alguna comprobacion falla.
#>
param(
    [string]$BackendEnvPath = 'C:\Proyectos\GestionAsistencia-CULM001\GestioAsistenciaBackend\.env',
    [string]$CatalogoBaseUrl = 'http://localhost:8081/catalogo-parametros/api/v1',
    [string]$BackendUrl = 'http://localhost:8080/api/v1',
    [string]$BackendHealthUrl = 'http://localhost:8090/actuator/health',
    [string]$KongUrl = 'http://localhost:8000',
    [string]$BackendLogPath = 'C:\Proyectos\GestionAsistencia-CULM001\GestioAsistenciaBackend\infra\observability\logs\backend-baseline.jsonl',
    [string]$InfraEnvPath = (Join-Path $PSScriptRoot '..\..\.env'),
    [string]$SqlContainer = 'sql_server_asistencias',
    # Omite la seccion 9, que escribe (y restaura) un valor temporal en dbo.CatalogoParametro.
    [switch]$OmitirPruebaOrigenBd
)

$ErrorActionPreference = 'Stop'
$script:Fallos = 0

function Resultado([bool]$ok, [string]$descripcion) {
    if ($ok) { Write-Host "[OK] $descripcion" } else { Write-Host "[FALLO] $descripcion"; $script:Fallos++ }
}

# Devuelve @{ Codigo; Cuerpo; Ms }; Codigo 0 = sin respuesta (timeout o conexion rechazada).
function Invocar([string]$metodo, [string]$url, [hashtable]$cabeceras = @{}, [string]$cuerpo = $null, [int]$timeoutSeg = 40) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $codigo = 0; $texto = ''; $script:UltimoError = $null
    try {
        $p = @{ Uri = $url; Method = $metodo; Headers = $cabeceras; UseBasicParsing = $true; TimeoutSec = $timeoutSeg }
        if (-not [string]::IsNullOrEmpty($cuerpo)) { $p.Body = [Text.Encoding]::UTF8.GetBytes($cuerpo); $p.ContentType = 'application/json; charset=utf-8' }
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

Write-Host '== Prueba E2E Catalogo de Parametros =='

if (-not (Test-Path $BackendEnvPath)) { Resultado $false "No existe el .env del backend: $BackendEnvPath"; exit 1 }
$tokenId = LeerEnv $BackendEnvPath 'CATALOGO_PARAMETROS_TOKEN_ID'
$secreto = LeerEnv $BackendEnvPath 'CATALOGO_PARAMETROS_SECRETO'
Resultado (-not [string]::IsNullOrWhiteSpace($tokenId) -and -not [string]::IsNullOrWhiteSpace($secreto)) 'El .env del backend define CATALOGO_PARAMETROS_TOKEN_ID y CATALOGO_PARAMETROS_SECRETO'
if ([string]::IsNullOrWhiteSpace($tokenId) -or [string]::IsNullOrWhiteSpace($secreto)) { exit 1 }

# 1. Salud del Catalogo
$origen = ([Uri]$CatalogoBaseUrl).GetLeftPart([UriPartial]::Authority)
$r = Invocar 'GET' "$origen/actuator/health" @{} $null 15
$up = ($r.Codigo -eq 200) -and ($r.Cuerpo -match '"status"\s*:\s*"UP"')
Resultado $up "Catalogo: /actuator/health responde 200 y UP (HTTP $($r.Codigo))"

# 2. Frontend del Catalogo
$r = Invocar 'GET' 'http://localhost:4201/' @{} $null 15
Resultado ($r.Codigo -eq 200) "Frontend del Catalogo (4201) responde 200 (HTTP $($r.Codigo))"

# 3. Lectura del token
$urlToken = "$CatalogoBaseUrl/tokens/$tokenId/parametros"
$r = Invocar 'GET' $urlToken @{ Authorization = "Bearer $secreto" } $null 40
Resultado ($r.Codigo -eq 200) "Catalogo: GET tokens/{id}/parametros con secreto valido -> 200 (HTTP $($r.Codigo))"
if ($r.Codigo -eq 200) {
    $json = $null
    try { $json = $r.Cuerpo | ConvertFrom-Json } catch { }
    $ambiente = $null; if ($null -ne $json -and $null -ne $json.ambiente) { $ambiente = $json.ambiente.nombre }
    Resultado (-not [string]::IsNullOrWhiteSpace($ambiente)) "La respuesta trae ambiente.nombre ($ambiente)"
    $params = @(); if ($null -ne $json -and $null -ne $json.parametros) { $params = @($json.parametros) }
    Resultado ($params.Count -ge 20) "La respuesta trae al menos 20 parametros (hay $($params.Count))"
    $dom = $params | Where-Object { $_.parametro.nombre -eq 'REGISTRO.DOMINIO_CORREO_ESTUDIANTE' } | Select-Object -First 1
    $valor = $null
    if ($null -ne $dom -and $null -ne $dom.metadatos) {
        foreach ($m in @($dom.metadatos)) { if ($null -ne $m.metadato -and "$($m.metadato.valor)".StartsWith('@')) { $valor = $m.metadato.valor; break } }
    }
    Resultado ($null -ne $valor) 'REGISTRO.DOMINIO_CORREO_ESTUDIANTE existe con un valor que empieza por @'
}
Resultado (($r.Codigo -eq 200) -and ($r.Ms -le 10000)) "Duracion de la lectura del token: $($r.Ms) ms (limite 10000 ms, el timeout del backend)"

$r = Invocar 'GET' $urlToken @{ Authorization = 'Bearer secreto-invalido' } $null 40
Resultado ($r.Codigo -eq 401) "Catalogo: secreto invalido -> 401 (HTTP $($r.Codigo))"
$r = Invocar 'GET' $urlToken @{} $null 40
Resultado ($r.Codigo -eq 401) "Catalogo: sin cabecera Authorization -> 401 (HTTP $($r.Codigo))"

# 4. API administrativa protegida por el PEP
$r = Invocar 'GET' "$CatalogoBaseUrl/organizaciones" @{} $null 20
Resultado ($r.Codigo -eq 401) "Catalogo: GET /organizaciones sin sesion -> 401 (HTTP $($r.Codigo))"

# 5. Kong
$r = Invocar 'GET' "$KongUrl/messageucolab/v1/public/messages/MSG_143" @{} $null 5
if ($r.Codigo -eq 0) {
    Resultado $false 'Kong degradado: sin respuesta en 5 s; ejecute: docker restart api-gateway-kong'
} else {
    Resultado ($r.Codigo -eq 422 -or $r.Codigo -eq 404) "Kong responde en $($r.Ms) ms con 422/404 (HTTP $($r.Codigo))"
}

# 6. Backend
$r = Invocar 'GET' $BackendHealthUrl @{} $null 15
$up = ($r.Codigo -eq 200) -and ($r.Cuerpo -match '"status"\s*:\s*"UP"')
Resultado $up "Backend: $BackendHealthUrl responde 200 y UP (HTTP $($r.Codigo))"

# 7. Registro QR con correo no institucional (publico; el correo se valida antes de consultar el token). El dominio
#    esperado es el que publica el Catalogo (seccion 3), no un literal: asi la comprobacion sigue al Catalogo.
function RegistroQrNoInstitucional {
    $cuerpo = @{
        token = ('A' * 43); pin = $null
        idTipoIdentificacion = [guid]::NewGuid().ToString()
        numeroIdentificacion = 1234567890
        primerNombre = 'Prueba'; segundoNombre = $null; primerApellido = 'Catalogo'; segundoApellido = $null
        correo = 'prueba.catalogo@gmail.com'; password = ('Pr' + [guid]::NewGuid().ToString('N') + '!')
    } | ConvertTo-Json -Compress
    return Invocar 'POST' "$BackendUrl/public/matricula-qr/registro" @{} $cuerpo 30
}

function MostrarRespuesta([string]$texto) {
    if ($texto.Length -gt 0) {
        $corto = $texto; if ($corto.Length -gt 300) { $corto = $corto.Substring(0, 300) }
        Write-Host "      Respuesta: $corto"
    }
}

function CorrelationId([string]$texto) {
    try { return ($texto | ConvertFrom-Json).correlationId } catch { return $null }
}

$dominioCatalogo = $valor
if ([string]::IsNullOrWhiteSpace($dominioCatalogo)) { $dominioCatalogo = '@uco.edu.co' }
$r = RegistroQrNoInstitucional
$textoResp = $r.Cuerpo
$esperado = ($r.Codigo -eq 400) -and ($textoResp -match 'VCE_001') -and ($textoResp.Contains($dominioCatalogo))
Resultado $esperado "Backend: registro QR con correo no institucional -> 400 VCE_001 con el dominio del Catalogo $dominioCatalogo (HTTP $($r.Codigo))"
if (-not $esperado) { MostrarRespuesta $textoResp }

# 8. Origen del valor (I): el dominio no salio del valor por defecto en codigo. El decorador DEC-018 registra un WARN
#    'Parametro resuelto con el valor por defecto' con el correlationId de la peticion cuando el Catalogo falla.
$correlacion = CorrelationId $textoResp
if ([string]::IsNullOrWhiteSpace($correlacion) -or -not (Test-Path $BackendLogPath)) {
    Resultado $false "Log del backend con el correlationId de la peticion ($BackendLogPath)"
} else {
    Start-Sleep -Milliseconds 500
    $porDefecto = @(Select-String -Path $BackendLogPath -SimpleMatch $correlacion |
        Where-Object { $_.Line -match 'valor por defecto' -and $_.Line -match 'DOMINIO_CORREO_ESTUDIANTE' })
    Resultado ($porDefecto.Count -eq 0) "Backend: REGISTRO.DOMINIO_CORREO_ESTUDIANTE no se resolvio con el valor por defecto en codigo (correlationId $correlacion)"
}

# 9. Origen del valor (II): el dominio no sale de dbo.CatalogoParametro. Se pone otro dominio solo en la BD local, se
#    repite el registro (debe seguir citando el del Catalogo) y se restauran valor y fechaModificacion en un finally.
#    Con APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=sqlserver esta comprobacion falla a proposito.
if ($OmitirPruebaOrigenBd) {
    Write-Host '[OMITIDO] Origen del valor frente a dbo.CatalogoParametro (-OmitirPruebaOrigenBd)'
} else {
    $saPassword = LeerEnv $InfraEnvPath 'MSSQL_SA_PASSWORD'
    if ([string]::IsNullOrWhiteSpace($saPassword)) {
        Resultado $false "MSSQL_SA_PASSWORD definido en $InfraEnvPath"
    } else {
        function Sql([string]$consulta) {
            $salida = docker exec -e "SQLCMDPASSWORD=$saPassword" $SqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C `
                -d gestionasistenciadb -h -1 -W -s '|' -b -Q "SET NOCOUNT ON; $consulta" 2>&1
            if ($LASTEXITCODE -ne 0) { throw "sqlcmd fallo: $salida" }
            return @($salida | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        $filtro = "grupo = 'REGISTRO' AND clave = 'DOMINIO_CORREO_ESTUDIANTE'"
        $original = $null
        try {
            $fila = @(Sql "SELECT CONVERT(NVARCHAR(400), valor) + '|' + CONVERT(VARCHAR(30), fechaModificacion, 121) FROM dbo.CatalogoParametro WHERE $filtro")
            if ($fila.Count -ne 1) { throw 'No existe REGISTRO.DOMINIO_CORREO_ESTUDIANTE en dbo.CatalogoParametro.' }
            $partes = $fila[0].Trim() -split '\|', 2
            $original = @{ Valor = $partes[0]; Fecha = $partes[1] }
            $dominioBd = '@origen-bd.invalid'
            [void](Sql "UPDATE dbo.CatalogoParametro SET valor = N'$dominioBd' WHERE $filtro")
            $r = RegistroQrNoInstitucional
            $ok = ($r.Codigo -eq 400) -and $r.Cuerpo.Contains($dominioCatalogo) -and -not $r.Cuerpo.Contains($dominioBd)
            Resultado $ok "Backend: con otro dominio solo en la BD ($dominioBd) sigue citando el del Catalogo $dominioCatalogo (HTTP $($r.Codigo))"
            if (-not $ok) { MostrarRespuesta $r.Cuerpo }
        } catch {
            Resultado $false "Prueba de origen frente a la BD: $($_.Exception.Message)"
        } finally {
            if ($null -ne $original) {
                $valorSql = $original.Valor.Replace("'", "''")
                try {
                    [void](Sql "UPDATE dbo.CatalogoParametro SET valor = N'$valorSql', fechaModificacion = CONVERT(DATETIME, '$($original.Fecha)', 121) WHERE $filtro")
                    $restaurado = @(Sql "SELECT CONVERT(NVARCHAR(400), valor) FROM dbo.CatalogoParametro WHERE $filtro")
                    Resultado ($restaurado[0].Trim() -eq $original.Valor) "BD restaurada: REGISTRO.DOMINIO_CORREO_ESTUDIANTE = $($original.Valor)"
                } catch {
                    Resultado $false "No se pudo restaurar REGISTRO.DOMINIO_CORREO_ESTUDIANTE (valor original: $($original.Valor), fecha: $($original.Fecha)): $($_.Exception.Message)"
                }
            }
        }
    }
}

Write-Host ''
if ($script:Fallos -gt 0) { Write-Host "Resultado: $($script:Fallos) comprobacion(es) fallida(s)"; exit 1 }
Write-Host 'Resultado: todas las comprobaciones pasaron'
exit 0
