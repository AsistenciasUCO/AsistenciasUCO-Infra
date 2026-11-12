<#
.SYNOPSIS
  Prueba E2E del Catalogo de Parametros y su integracion con el backend (INT-002).
.DESCRIPTION
  Lee CATALOGO_PARAMETROS_TOKEN_ID y CATALOGO_PARAMETROS_SECRETO del .env del backend sin mostrarlos.
  Salida [OK]/[FALLO]; termina con exit 1 si alguna comprobacion falla.
#>
param(
    [string]$BackendEnvPath = 'C:\Proyectos\GestionAsistencia-CULM001\GestioAsistenciaBackend\.env',
    [string]$CatalogoBaseUrl = 'http://localhost:8081/catalogo-parametros/api/v1',
    [string]$BackendUrl = 'http://localhost:8080/api/v1',
    [string]$BackendHealthUrl = 'http://localhost:8090/actuator/health',
    [string]$KongUrl = 'http://localhost:8000'
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

# 7. Registro QR con correo no institucional (publico; el correo se valida antes de consultar el token)
$tokenFalso = 'A' * 43
$cuerpo = @{
    token = $tokenFalso; pin = $null
    idTipoIdentificacion = [guid]::NewGuid().ToString()
    numeroIdentificacion = 1234567890
    primerNombre = 'Prueba'; segundoNombre = $null; primerApellido = 'Catalogo'; segundoApellido = $null
    correo = 'prueba.catalogo@gmail.com'; password = ('Pr' + [guid]::NewGuid().ToString('N') + '!')
} | ConvertTo-Json -Compress
$r = Invocar 'POST' "$BackendUrl/public/matricula-qr/registro" @{} $cuerpo 30
$textoResp = $r.Cuerpo
$esperado = ($r.Codigo -eq 400) -and ($textoResp -match 'VCE_001') -and ($textoResp -match '@uco\.edu\.co')
Resultado $esperado "Backend: registro QR con correo no institucional -> 400 VCE_001 con dominio @uco.edu.co tomado del Catalogo (HTTP $($r.Codigo))"
if (-not $esperado -and $textoResp.Length -gt 0) {
    $corto = $textoResp; if ($corto.Length -gt 300) { $corto = $corto.Substring(0, 300) }
    Write-Host "      Respuesta: $corto"
}

Write-Host ''
if ($script:Fallos -gt 0) { Write-Host "Resultado: $($script:Fallos) comprobacion(es) fallida(s)"; exit 1 }
Write-Host 'Resultado: todas las comprobaciones pasaron'
exit 0
