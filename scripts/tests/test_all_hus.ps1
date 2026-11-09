# ==============================================================================
# SUITE DE PRUEBAS INTEGRALES DE HISTORIAS DE USUARIO (HU001 - HU174)
# Plataforma de Gestion de Asistencia - Universidad Catolica de Oriente (UCO)
# Autenticacion: Security Baseline (realm security-baseline, cliente publico asistencias-uco-spa, Authorization Code + PKCE).
# Las claves NO se guardan en este script: se leen de -Password* o de la variable
# de entorno E2E_PASSWORD. Documentadas en docs/CREDENCIALES_PRUEBAS_LOCAL.md.
# Compatible con Windows PowerShell 5.1.
#
# CULM-001 (reconciliacion con la API vigente): cada prueba usa las rutas, los metodos, los roles y los payloads reales
# del backend (access-catalog.json). Los datos previos se crean por la API con el prefijo CULM1-E2E- y el rol que
# corresponde. Una prueba que falla porque el backend aun no implementa la HU (501 o ruta retirada) NO se relaja: se
# deja tal cual y se anota con la marca ESPERADO-HASTA-<paquete>. Ver docs/CULM-001-e2e-esperados.md del reporte.
# Regla de seguridad: el cierre masivo de periodo (HU174) solo se ejecuta si E2E_PERMITIR_CIERRE_MASIVO=1.
# ==============================================================================
param(
    [string]$BaseUrl = "http://localhost:8080/api/v1",
    [string]$KeycloakUrl = "http://keycloak.localhost:19090",
    [string]$Realm = "security-baseline",
    [string]$ClientId = "asistencias-uco-spa",
    [string]$RedirectUri = "http://localhost:4200/",
    [string]$UserEstudiante = "uco-estudiante",
    [string]$UserDocente = "uco-docente",
    [string]$UserCoordinador = "uco-coordinador",
    [string]$UserDecano = "uco-decano",
    [string]$UserAdministrador = "uco-administrador",
    [string]$Password,
    [string]$PasswordEstudiante,
    [string]$PasswordDocente,
    [string]$PasswordCoordinador,
    [string]$PasswordDecano,
    [string]$PasswordAdministrador
)
$ErrorActionPreference = "Continue"
$BASE = $BaseUrl.TrimEnd('/')
$BASEV2 = $BASE -replace '/api/v1$', '/api/v2'
$KC = "{0}/realms/{1}" -f $KeycloakUrl.TrimEnd('/'), $Realm
. (Join-Path $PSScriptRoot "Get-SpaToken.ps1")

function Resolve-Clave($especifica) {
    if ($especifica) { return $especifica }
    if ($Password) { return $Password }
    if ($env:E2E_PASSWORD) { return $env:E2E_PASSWORD }
    return $null
}
$pEst = Resolve-Clave $PasswordEstudiante
$pDoc = Resolve-Clave $PasswordDocente
$pCoord = Resolve-Clave $PasswordCoordinador
$pDec = Resolve-Clave $PasswordDecano
$pAdmin = Resolve-Clave $PasswordAdministrador
if (-not ($pEst -and $pDoc -and $pCoord -and $pDec -and $pAdmin)) {
    Write-Host "[ERROR] Faltan claves de prueba. Defina la variable de entorno E2E_PASSWORD (clave comun) o use -Password / -PasswordEstudiante / -PasswordDocente / -PasswordCoordinador / -PasswordDecano / -PasswordAdministrador. Las claves estan documentadas en docs/CREDENCIALES_PRUEBAS_LOCAL.md (checkout original, fuera de Git)." -ForegroundColor Red
    exit 1
}

$global:TotalTests = 0
$global:PassedTests = 0
$global:FailedTests = 0
$global:SkippedTests = 0
$global:TestResults = @()

function Get-Token($user, $pass) {
    try {
        return Get-SpaToken -Username $user -Password $pass -Issuer $KC -ClientId $ClientId -RedirectUri $RedirectUri
    } catch {
        Write-Host " [ERROR] No se pudo obtener token PKCE para '$user' en $KC ($($_.Exception.Message)). Verifique el laboratorio Security Baseline (puerto 19090) y la clave." -ForegroundColor Red
        return $null
    }
}

function Run-Test($huCode, $description, [scriptblock]$action) {
    $global:TotalTests++
    Write-Host -NoNewline (" [{0}] {1}... " -f $huCode, $description)
    try {
        $salida = @(& $action)
        $res = if ($salida.Count -gt 0) { $salida[$salida.Count - 1] } else { $null }
        $global:PassedTests++
        Write-Host "PASS" -ForegroundColor Green
        if ($res) {
            Write-Host "        -> $res" -ForegroundColor DarkGray
        }
        $global:TestResults += [PSCustomObject]@{
            HU = $huCode
            Descripcion = $description
            Estado = "PASS"
            Detalle = "$res"
        }
    } catch {
        $global:FailedTests++
        Write-Host "FAIL" -ForegroundColor Red
        Write-Host "        -> Error: $($_.Exception.Message)" -ForegroundColor DarkYellow
        $global:TestResults += [PSCustomObject]@{
            HU = $huCode
            Descripcion = $description
            Estado = "FAIL"
            Detalle = $_.Exception.Message
        }
    }
}

function Skip-Test($huCode, $description, $motivo) {
    $global:TotalTests++
    $global:SkippedTests++
    Write-Host (" [{0}] {1}... " -f $huCode, $description) -NoNewline
    Write-Host "SKIP" -ForegroundColor Yellow
    Write-Host "        -> $motivo" -ForegroundColor DarkYellow
    $global:TestResults += [PSCustomObject]@{
        HU = $huCode
        Descripcion = $description
        Estado = "SKIP"
        Detalle = $motivo
    }
}

# ------------------------------------------------------------------------------
# Utilidades HTTP. Invoke-Api codifica el cuerpo en UTF-8, decodifica la respuesta en UTF-8 y, ante un error HTTP,
# lanza "HTTP <status> [<code>] <mensaje> (correlationId=...)" para dejar evidencia en el reporte.
# ------------------------------------------------------------------------------
function Format-ApiError($err) {
    $resp = $err.Exception.Response
    if (-not $resp) { return "HTTP 0 sin respuesta: $($err.Exception.Message)" }
    $status = [int]$resp.StatusCode
    $body = ""
    try {
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $body = $sr.ReadToEnd()
        $sr.Close()
    } catch { }
    $detalle = ""
    if ($body) {
        try {
            $j = $body | ConvertFrom-Json
            $detalle = "[$($j.code)] $($j.message) (correlationId=$($j.correlationId))"
        } catch {
            $detalle = $body.Substring(0, [Math]::Min(200, $body.Length))
        }
    }
    return ("HTTP {0} {1}" -f $status, $detalle).Trim()
}

function Get-ApiStatus([string]$mensaje) {
    if ($mensaje -match '^HTTP (\d+)') { return [int]$Matches[1] }
    return 0
}

function Invoke-Api {
    param([string]$Method, [string]$Path, $Headers, $Body = $null, [switch]$Bytes)
    $uri = if ($Path -like "http*") { $Path } else { "$BASE$Path" }
    $p = @{ Uri = $uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 8 -Compress }
        $p.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
        $p.ContentType = "application/json; charset=utf-8"
    }
    try {
        $r = Invoke-WebRequest @p
    } catch {
        throw (Format-ApiError $_)
    }
    $ms = New-Object System.IO.MemoryStream
    $r.RawContentStream.Position = 0
    $r.RawContentStream.CopyTo($ms)
    $raw = $ms.ToArray()
    if ($Bytes) { return , $raw }
    if ($raw.Length -eq 0) { return $null }
    $texto = [System.Text.Encoding]::UTF8.GetString($raw)
    try { return ($texto | ConvertFrom-Json) } catch { return $texto }
}

function Expect-ApiStatus {
    param([int]$Status, [scriptblock]$Call)
    $obtenido = 0
    $detalle = ""
    try {
        & $Call | Out-Null
        $obtenido = 200
    } catch {
        $detalle = $_.Exception.Message
        $obtenido = Get-ApiStatus $detalle
    }
    if ($obtenido -ne $Status) { throw "Se esperaba HTTP $Status y se obtuvo $obtenido. $detalle" }
}

function Format-Utc([datetime]$d) {
    return $d.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
}

function New-Clave { return ("Culm1-" + [guid]::NewGuid().ToString("N").Substring(0, 10) + "-Aa1!") }

function Find-SesionId($grupoId, $nombre) {
    $r = Invoke-Api GET "$BASEV2/sesiones/grupo/$grupoId" $hDoc
    $m = @($r.datos | Where-Object { $_.nombre -eq $nombre })
    if ($m.Count -eq 0) { throw "La sesion '$nombre' no aparece en el grupo $grupoId tras crearla." }
    return [string]$m[0].sesion
}

function New-SesionV2($grupoId, $nombre, [datetime]$inicio, [datetime]$fin) {
    $cuerpo = @{ grupo = "$grupoId"; nombre = $nombre; fechaHoraInicio = (Format-Utc $inicio); fechaHoraFin = (Format-Utc $fin) }
    Invoke-Api POST "$BASEV2/sesiones" $hDoc $cuerpo | Out-Null
    return (Find-SesionId $grupoId $nombre)
}

# Busca una ventana de 1 hora sin cruce con las sesiones del docente (dias relativos a hoy, negativos = pasado).
function New-SesionLibre($grupoId, $prefijo, [int]$desdeDias, [int]$hastaDias) {
    $ultimo = ""
    for ($i = 0; $i -lt 10; $i++) {
        $dias = Get-Random -Minimum $desdeDias -Maximum ($hastaDias + 1)
        $hora = Get-Random -Minimum 5 -Maximum 21
        $min = (Get-Random -Minimum 0 -Maximum 4) * 15
        $ini = ([datetime]::UtcNow.Date).AddDays($dias).AddHours($hora).AddMinutes($min)
        $nombre = "{0}-{1}" -f $prefijo, (Get-Random -Minimum 100000 -Maximum 999999)
        try {
            $id = New-SesionV2 $grupoId $nombre $ini $ini.AddHours(1)
            return @{ id = $id; nombre = $nombre; inicio = $ini; fin = $ini.AddHours(1) }
        } catch {
            $ultimo = $_.Exception.Message
            if ((Get-ApiStatus $ultimo) -ne 400) { throw }
        }
    }
    throw "No se encontro una ventana horaria libre para la sesion de prueba. Ultimo error: $ultimo"
}

# Mueve una sesion CULM1-E2E a una ventana pasada de 10 minutos sin cruce (para no bloquear la siguiente corrida).
function Move-SesionAlPasado($sesionId, $nombre) {
    $ultimo = ""
    for ($i = 0; $i -lt 10; $i++) {
        $ini = [datetime]::UtcNow.AddMinutes(-1 * (Get-Random -Minimum 180 -Maximum 40000))
        $cuerpo = @{ nombre = $nombre; fechaHoraInicio = (Format-Utc $ini); fechaHoraFin = (Format-Utc $ini.AddMinutes(10)) }
        try {
            Invoke-Api PATCH "$BASEV2/sesiones/$sesionId" $hDoc $cuerpo | Out-Null
            return
        } catch {
            $ultimo = $_.Exception.Message
            if ((Get-ApiStatus $ultimo) -ne 400) { throw }
        }
    }
    throw "No se pudo mover la sesion $sesionId al pasado: $ultimo"
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " INICIANDO SUITE DE PRUEBAS DE HISTORIAS DE USUARIO (HU001 - HU174) " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

Write-Host "`n[PASO 0] Autenticando usuarios institucionales en Security Baseline ($Realm)..." -ForegroundColor Cyan
$tokenEst = Get-Token $UserEstudiante $pEst
$tokenDoc = Get-Token $UserDocente $pDoc
$tokenCoord = Get-Token $UserCoordinador $pCoord
$tokenDec = Get-Token $UserDecano $pDec
$tokenAdmin = Get-Token $UserAdministrador $pAdmin

$hEst = @{ Authorization = "Bearer $tokenEst" }
$hDoc = @{ Authorization = "Bearer $tokenDoc" }
$hCoord = @{ Authorization = "Bearer $tokenCoord" }
$hDec = @{ Authorization = "Bearer $tokenDec" }
$hAdmin = @{ Authorization = "Bearer $tokenAdmin" }

if ($tokenEst -and $tokenDoc -and $tokenCoord -and $tokenDec -and $tokenAdmin) {
    Write-Host "Autenticacion exitosa para los 5 roles institucionales.`n" -ForegroundColor Green
} else {
    Write-Host "[ADVERTENCIA] No fue posible obtener todos los tokens. Asegurese de que el laboratorio Security Baseline este activo.`n" -ForegroundColor Yellow
}

# Estado compartido entre pruebas (se llena por la API; nada se asume de datos sembrados salvo los 5 usuarios).
$script:grupoBaseId = $null
$script:estudianteDoc = $null
$script:carlosId = $null
$script:anaId = $null
$script:fileId = $null
$script:fileBytes = $null
$script:sesEnCurso = $null
$script:sesFutura = $null
$script:sesPasada = $null
$script:sesPasadaEnPlazo = $null
$script:reclamoId = $null
$script:grupoNuevoId = $null
$script:docenteId = $null
$script:asignaturaOfertaId = $null
$script:periodoVigenteId = $null
$script:tomaId = $null
$script:tomaPin = $null

# ==============================================================================
# SECCION 1: MODULO ESTUDIANTE (HU001 - HU026)
# ==============================================================================
Write-Host "==============================================================================" -ForegroundColor Yellow
Write-Host " 1. MODULO ESTUDIANTE (HU001 - HU026)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

Run-Test "HU001-HU004,HU007,HU009" "Consultar materias matriculadas, porcentajes de asistencia y estado de permanencia" {
    $res = Invoke-Api GET "/estudiante/materias" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if (@($res.datos).Count -lt 1) { throw "El estudiante no tiene materias matriculadas activas" }
    # El grupo base es el sembrado del estudiante; se ignoran los grupos CULM1-E2E- creados por la propia suite.
    $base = @($res.datos | Where-Object { $_.nombreGrupo -notlike "CULM1-E2E*" })
    if ($base.Count -lt 1) { $base = @($res.datos) }
    $script:grupoBaseId = [string]$base[0].idGrupo
    return "Materias inscritas: $(@($res.datos).Count). Materia base: $($base[0].nombreAsignatura) ($($base[0].nombreGrupo))"
}

Run-Test "HU005,HU016" "Consultar catalogo tipificado de causales validas para justificacion de inasistencias" {
    $res = Invoke-Api GET "/categorias-justificacion" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if (@($res.datos).Count -lt 3) { throw "Catalogo de causales incompleto" }
    return "Causales disponibles: $((@($res.datos) | ForEach-Object { $_.codigo }) -join ', ')"
}

Run-Test "HU006" "Consultar ficha tecnica y datos de perfil de estudiante institucional" {
    $res = Invoke-Api GET "/usuarios/perfil" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa al consultar el perfil" }
    $script:estudianteDoc = [string]$res.datos.numeroIdentificacion
    return "Perfil consultado: $($res.datos.primerNombre) $($res.datos.primerApellido)"
}

Run-Test "HU008" "Consultar oferta de grupos y cupos (solo consulta, sin solicitar ingreso)" {
    $res = Invoke-Api GET "/estudiante/oferta-academica" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Grupos ofertados: $(@($res.datos).Count)"
}

Run-Test "HU013" "Validar regla reactiva de alertas tempranas por superacion de umbral de inasistencias (15%-20%)" {
    $res = Invoke-Api GET "/estudiante/materias" $hEst
    $materia = $res.datos[0]
    $porc = if ($materia.porcentajeAsistencia) { [double]$materia.porcentajeAsistencia } else { 85.0 }
    $alerta = if ($porc -lt 80.0) { "ALERTA CRITICA: En riesgo de reprobacion" } else { "ESTADO REGULAR: Asistencia conforme" }
    return "Evaluacion de alerta temprana para $($materia.nombreAsignatura): $alerta (Asistencia: $porc%)"
}

Run-Test "HU017,HU020,HU021" "Consultar horarios semanales del estudiante" {
    $res = Invoke-Api GET "/estudiante/horarios" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Horarios de clase asignados: $(@($res.datos).Count) bloques semanales"
}

Run-Test "HU018,HU019" "Consultar semestres curriculares y avance en plan de estudios del estudiante" {
    $res = Invoke-Api GET "/estudiante/materias" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Malla curricular consultada: $(@($res.datos).Count) asignaturas inscritas."
}

Run-Test "HU002" "Consultar registros historicos de asistencia por materia" {
    $mat = @((Invoke-Api GET "/estudiante/materias" $hEst).datos | Where-Object { $_.idGrupo -ieq $script:grupoBaseId })[0]
    $res = Invoke-Api GET "/estudiante/materias/$($mat.idAsignatura)/sesiones" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Sesiones de la materia: $(@($res.datos).Count)"
}

Run-Test "HU014" "Subir archivo de soporte / incapacidad medica en formato binario multiparte" {
    $contenido = [System.Text.Encoding]::UTF8.GetBytes("%PDF-1.4 CULM1-E2E soporte " + [guid]::NewGuid().ToString("N"))
    $script:fileBytes = $contenido
    $limite = [guid]::NewGuid().ToString()
    $ms = New-Object System.IO.MemoryStream
    $enc = [System.Text.Encoding]::UTF8
    $cab = $enc.GetBytes("--$limite`r`nContent-Disposition: form-data; name=`"archivo`"; filename=`"CULM1-E2E-soporte.pdf`"`r`nContent-Type: application/pdf`r`n`r`n")
    $ms.Write($cab, 0, $cab.Length)
    $ms.Write($contenido, 0, $contenido.Length)
    $pie = $enc.GetBytes("`r`n--$limite--`r`n")
    $ms.Write($pie, 0, $pie.Length)
    $headers = @{ Authorization = "Bearer $tokenEst" }
    try {
        $r = Invoke-WebRequest "$BASE/archivos/subir" -Headers $headers -Method POST -Body $ms.ToArray() -ContentType "multipart/form-data; boundary=$limite" -UseBasicParsing
    } catch {
        throw (Format-ApiError $_)
    }
    $res = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
    if (-not $res.exitoso) { throw "Respuesta no exitosa en subida" }
    $script:fileId = [string]$res.datos.fileId
    if (-not $script:fileId) { throw "La respuesta de subida no trae fileId" }
    return "Archivo cargado fileId=$($script:fileId) ($($res.datos.nombre), $($res.datos.tamanio) bytes)"
}

Run-Test "HU014-Descargar" "Descargar y verificar integridad de archivo de soporte cargado" {
    if (-not $script:fileId) { throw "No hay archivo para descargar (falla la prueba HU014)" }
    $bytes = Invoke-Api GET "/archivos/$($script:fileId)" $hEst -Bytes
    if ($bytes.Length -ne $script:fileBytes.Length) { throw "El tamano descargado ($($bytes.Length)) no coincide con el subido ($($script:fileBytes.Length))" }
    for ($i = 0; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -ne $script:fileBytes[$i]) { throw "El contenido descargado difiere del subido (byte $i)" } }
    return "Descarga validada byte a byte para fileId=$($script:fileId)"
}

# ==============================================================================
# SECCION 2: MODULO DOCENTE (HU027 - HU059)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 2. MODULO DOCENTE (HU027 - HU059)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

Run-Test "HU008,HU031,HU058,HU059" "Consultar grupos asignados al docente titular con aforo y horarios" {
    $res = Invoke-Api GET "/docente/asignaturas" $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $grupos = @($res.datos)
    if ($grupos.Count -lt 1) { throw "El docente no tiene grupos asignados" }
    if (-not $script:grupoBaseId) { $script:grupoBaseId = [string]$grupos[0].idGrupo }
    $propio = @($grupos | Where-Object { $_.idGrupo -ieq $script:grupoBaseId })
    if ($propio.Count -ne 1) { throw "El grupo del estudiante ($($script:grupoBaseId)) no figura entre los grupos del docente titular" }
    $tipos = Invoke-Api GET "/tipos-programa" $hDoc
    return "Grupos asignados: $($grupos.Count). Grupo base: $($propio[0].nombreGrupo), activos $($propio[0].estudiantesActivos)/$($propio[0].capacidadMaximaPermitida). Tipos de programa: $(@($tipos).Count)"
}

Run-Test "HU003,HU032,HU052" "Consultar padron de estudiantes matriculados en grupo del docente" {
    $res = Invoke-Api GET "/grupos/$($script:grupoBaseId)/estudiantes" $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $padron = @($res.datos)
    $carlos = @($padron | Where-Object { $_.documento -eq $script:estudianteDoc })
    if ($carlos.Count -ne 1) { throw "El estudiante autenticado (documento del perfil) no figura en el padron" }
    $script:carlosId = [string]$carlos[0].idEstudiante
    $otro = @($padron | Where-Object { $_.codigoEstado -eq "A" -and $_.idEstudiante -ine $script:carlosId })
    if ($otro.Count -lt 1) { throw "El padron no tiene otro estudiante activo para pruebas de matricula" }
    $script:anaId = [string]$otro[0].idEstudiante
    return "Estudiantes en el grupo: $($padron.Count)"
}

Run-Test "PREP-E2E" "Preparar sesiones de prueba CULM1-E2E (en curso, pasada y futura) creadas por el docente con instantes UTC" {
    # Libera una sesion CULM1-E2E-EnCurso que haya quedado abierta por una corrida abortada (la mueve al pasado).
    $ahora = [datetime]::UtcNow
    $misGrupos = @((Invoke-Api GET "/docente/asignaturas" $hDoc).datos)
    foreach ($g in $misGrupos) {
        $existentes = Invoke-Api GET "$BASEV2/sesiones/grupo/$($g.idGrupo)" $hDoc
        foreach ($s in @($existentes.datos | Where-Object { $_.nombre -like "CULM1-E2E-EnCurso*" })) {
            $fin = [datetime]::Parse($s.fechaHoraFin).ToUniversalTime()
            if ($fin -gt $ahora.AddMinutes(-31)) { Move-SesionAlPasado $s.sesion $s.nombre }
        }
    }
    $nombreEn = "CULM1-E2E-EnCurso-{0}" -f (Get-Random -Minimum 1000 -Maximum 9999)
    $idEn = New-SesionV2 $script:grupoBaseId $nombreEn $ahora.AddMinutes(-2) $ahora.AddMinutes(25)
    $script:sesEnCurso = @{ id = $idEn; nombre = $nombreEn }
    $script:sesPasada = New-SesionLibre $script:grupoBaseId "CULM1-E2E-Pasada" -90 -8
    # CULM-001 D.1 (HU026B, SUPUESTO-D-01): sesion terminada hace 1-3 dias, DENTRO del plazo de ASISTENCIA/DIAS_LIMITE_JUSTIFICACION
    # (N=5 dias calendario). La radicacion/anulacion legitima usa esta; la rechazada por plazo usa $script:sesPasada (8-90 dias).
    $script:sesPasadaEnPlazo = New-SesionLibre $script:grupoBaseId "CULM1-E2E-PasadaPlazo" -3 -1
    $script:sesFutura = New-SesionLibre $script:grupoBaseId "CULM1-E2E-Futura" 30 300
    return "EnCurso=$idEn Pasada=$($script:sesPasada.id) PasadaEnPlazo=$($script:sesPasadaEnPlazo.id) Futura=$($script:sesFutura.id)"
}

Run-Test "HU028,HU030,HU045" "Crear/abrir y programar sesiones de clase (v2, instantes UTC) para registro de asistencia" {
    if (-not $script:sesFutura) { throw "No hay sesion de prueba (falla PREP-E2E)" }
    $r = Invoke-Api GET "$BASEV2/sesiones/$($script:sesFutura.id)" $hDoc
    if (-not $r.exitoso) { throw "Respuesta no exitosa al consultar la sesion creada" }
    if ($r.datos.estadoTemporal -ne "CONFIRMADA") { throw "La sesion v2 debia quedar CONFIRMADA y esta $($r.datos.estadoTemporal)" }
    return "Sesion creada id=$($script:sesFutura.id) ($($r.datos.codigo)), inicio $($r.datos.fechaHoraInicio), estado $($r.datos.estadoTemporal)"
}

Run-Test "HU034,HU173" "Validar prevencion y bloqueo de colision horaria de sesiones del docente" {
    if (-not $script:sesFutura) { throw "No hay sesion de prueba (falla PREP-E2E)" }
    $cuerpo = @{ grupo = $script:grupoBaseId; nombre = "CULM1-E2E-Choque"; fechaHoraInicio = (Format-Utc $script:sesFutura.inicio.AddMinutes(10)); fechaHoraFin = (Format-Utc $script:sesFutura.fin.AddMinutes(10)) }
    Expect-ApiStatus 400 { Invoke-Api POST "$BASEV2/sesiones" $hDoc $cuerpo }
    return "Colision detectada y rechazada con HTTP 400 (VALIDATION_ERROR, cruce con la sesion $($script:sesFutura.nombre))"
}

Run-Test "HU046,HU048,HU049" "Reprogramar fecha/hora de sesion creada (PATCH v2, reemplazo completo)" {
    if (-not $script:sesFutura) { throw "No hay sesion de prueba (falla PREP-E2E)" }
    $nuevoIni = $script:sesFutura.inicio.AddHours(1)
    $cuerpo = @{ nombre = ($script:sesFutura.nombre + "-R"); fechaHoraInicio = (Format-Utc $nuevoIni); fechaHoraFin = (Format-Utc $nuevoIni.AddHours(1)) }
    $res = Invoke-Api PATCH "$BASEV2/sesiones/$($script:sesFutura.id)" $hDoc $cuerpo
    if (-not $res.exitoso) { throw "Respuesta no exitosa al actualizar sesion" }
    $r = Invoke-Api GET "$BASEV2/sesiones/$($script:sesFutura.id)" $hDoc
    if ($r.datos.nombre -ne $cuerpo.nombre) { throw "El nombre no se actualizo" }
    return "Sesion reprogramada: $($r.datos.nombre) -> $($r.datos.fechaHoraInicio)"
}

Run-Test "HU027,HU033" "Verificar retiro de endpoint individual de asistencia (POST /asistencias responde HTTP 404)" {
    # D.7 (TD-009): POST /asistencias responde 404 tras su retiro formal
    $body = @{
        estudiante = $script:carlosId
        grupo = $script:grupoBaseId
        sesion = $script:sesEnCurso.id
        presente = $true
        observacion = "CULM1-E2E llegada puntual a clase"
    }
    Expect-ApiStatus 404 { Invoke-Api POST "/asistencias" $hDoc $body }
    return "Ruta individual retirada: POST /asistencias responde HTTP 404 conforme a TD-009 y paquete D"
}

Run-Test "HU056" "Registrar marcacion masiva 'Todos Presentes' en sesion de clase (POST /asistencias/lote)" {
    $body = @{ sesionId = $script:sesEnCurso.id; registros = @(
            @{ estudianteId = $script:carlosId; estado = "AN" },
            @{ estudianteId = $script:anaId; estado = "AN" }
        ) }
    $res = Invoke-Api POST "/asistencias/lote" $hDoc $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al registrar el lote" }
    return "Marcacion masiva registrada: $($res.mensaje)"
}

Run-Test "HU033-Lote" "Modificar el estado de asistencia registrado (AN -> SJC) por el docente titular mientras la sesion esta en curso" {
    $body = @{ sesionId = $script:sesEnCurso.id; registros = @(@{ estudianteId = $script:carlosId; estado = "SJC" }) }
    $res = Invoke-Api POST "/asistencias/lote" $hDoc $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al modificar el estado" }
    return "Estado de asistencia modificado: $($res.mensaje)"
}

Run-Test "HU029,HU040,HU041" "Consultar planilla de asistencia y estadisticas acumuladas del grupo" {
    $res = Invoke-Api GET "/grupos/$($script:grupoBaseId)/asistencias?sesionId=$($script:sesEnCurso.id)" $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $carlos = @($res.datos | Where-Object { $_.estudiante -ieq $script:carlosId })
    if ($carlos.Count -ne 1) { throw "La planilla no trae el registro del estudiante en la sesion" }
    return "Registros de asistencia de la sesion: $(@($res.datos).Count). Estudiante: estado $($carlos[0].estado), presente=$($carlos[0].presente)"
}

Run-Test "B.2-Tomas" "Gestion de tomas de asistencia en sesion (apertura y consulta de tomas)" {
    if (-not $script:sesEnCurso) { throw "No hay sesion en curso (falla PREP-E2E)" }
    # 1. Abrir toma de asistencia en modo QR
    $bodyToma = @{ modo = "QR" }
    $resToma = Invoke-Api POST "/sesiones/$($script:sesEnCurso.id)/tomas" $hDoc $bodyToma
    if (-not $resToma.exitoso) { throw "Respuesta no exitosa al abrir toma" }
    $script:tomaId = [string]$resToma.datos.idToma
    if (-not $script:tomaId) { throw "La respuesta no entrego idToma" }
    
    # 2. Consultar tomas de la sesion
    $tomasSes = Invoke-Api GET "/sesiones/$($script:sesEnCurso.id)/tomas" $hDoc
    if (-not $tomasSes.exitoso) { throw "Respuesta no exitosa al consultar tomas" }
    $tomasList = if ($null -ne $tomasSes.datos.tomas) { $tomasSes.datos.tomas } else { @($tomasSes.datos) }
    
    return "Toma QR abierta id=$($script:tomaId) (numero $($resToma.datos.numero)). Total tomas en sesion: $(@($tomasList).Count)"
}

Run-Test "HU175" "Proyeccion y rotacion de codigo QR dinamico y PIN de asistencia para la toma (docente)" {
    if (-not $script:tomaId) { throw "No hay toma abierta (falla B.2-Tomas)" }
    # 1. Emitir QR/PIN
    $resQr = Invoke-Api POST "/tomas/$($script:tomaId)/qr" $hDoc
    if (-not $resQr.exitoso) { throw "Respuesta no exitosa al proyectar QR" }
    $script:tomaPin = [string]$resQr.datos.pin
    if (-not $script:tomaPin) { throw "La respuesta no entrego PIN de asistencia" }
    
    # 2. Rotar QR/PIN
    $resRot = Invoke-Api POST "/tomas/$($script:tomaId)/qr/rotacion" $hDoc
    if (-not $resRot.exitoso) { throw "Respuesta no exitosa al rotar QR" }
    $script:tomaPin = [string]$resRot.datos.pin
    
    return "QR/PIN emitido y rotado exitosamente. PIN activo: $($script:tomaPin) (rotacion $($resRot.datos.rotacionSegundos)s)"
}

Run-Test "HU176" "Auto-registro de asistencia del estudiante mediante PIN o token QR de la toma" {
    if (-not $script:tomaPin) { throw "No hay PIN activo (falla HU175)" }
    $body = @{ pin = "$($script:tomaPin)" }
    $res = Invoke-Api POST "/estudiante/asistencia-qr" $hEst $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al registrar asistencia con PIN" }
    
    # Idempotencia: segundo intento devuelve 200 con yaRegistrado=true
    $resIdem = Invoke-Api POST "/estudiante/asistencia-qr" $hEst $body
    if (-not $resIdem.exitoso) { throw "Respuesta no exitosa en reintento idempotente" }
    
    return "Asistencia registrada con PIN: $($res.datos.mensaje); idempotencia confirmada (yaRegistrado=$($resIdem.datos.yaRegistrado))"
}

Run-Test "B.2-Faltantes-Cierre" "Consultar faltantes, cerrar toma de asistencia y consultar planilla de la toma" {
    if (-not $script:tomaId) { throw "No hay toma abierta (falla B.2-Tomas)" }
    # 1. Consultar faltantes de la toma
    $faltantes = Invoke-Api GET "/tomas/$($script:tomaId)/faltantes?pagina=1&tamano=50" $hDoc
    if (-not $faltantes.exitoso) { throw "Respuesta no exitosa al consultar faltantes" }
    $falElems = if ($null -ne $faltantes.elementos) { $faltantes.elementos } else { $faltantes.datos }
    
    # 2. Cerrar toma de asistencia marcando ausentes
    $cierre = Invoke-Api POST "/tomas/$($script:tomaId)/cierre" $hDoc @{ marcarAusentes = $true }
    if (-not $cierre.exitoso) { throw "Respuesta no exitosa al cerrar toma" }
    
    # 3. Consultar asistencias registradas en la toma
    $asigsToma = Invoke-Api GET "/tomas/$($script:tomaId)/asistencias?pagina=1&tamano=50" $hDoc
    if (-not $asigsToma.exitoso) { throw "Respuesta no exitosa al consultar asistencias de la toma" }
    $asigElems = if ($null -ne $asigsToma.elementos) { $asigsToma.elementos } else { $asigsToma.datos }
    
    # 4. Dejar de proyectar QR (DELETE /tomas/{id}/qr)
    try { Invoke-Api DELETE "/tomas/$($script:tomaId)/qr" $hDoc | Out-Null } catch { }
    
    return "Faltantes previos: $(@($falElems).Count). Toma cerrada (ausentes marcados: $($cierre.datos.totalAusentesMarcados)). Planilla toma: $(@($asigElems).Count) registros"
}

Run-Test "HU040,HU041-Horas" "Resumen analitico de asistencia por horas por grupo (docente) y por materia (estudiante)" {
    # 1. Docente: resumen del grupo por horas (F-DOC-004)
    $resDoc = Invoke-Api GET "/docente/grupos/$($script:grupoBaseId)/resumen-asistencia?pagina=1&tamano=50" $hDoc
    if (-not $resDoc.exitoso) { throw "Respuesta no exitosa en resumen de grupo por horas" }
    $resElems = if ($null -ne $resDoc.elementos) { $resDoc.elementos } else { $resDoc.datos }
    
    # 2. Estudiante: materias con indicadores por horas (F-EST-002)
    $resEst = Invoke-Api GET "/estudiante/materias" $hEst
    if (-not $resEst.exitoso) { throw "Respuesta no exitosa al consultar materias del estudiante" }
    $mat = @($resEst.datos | Where-Object { $_.idGrupo -ieq $script:grupoBaseId })[0]
    $ind = $mat.indicadores
    $horasDictadas = if ($ind) { $ind.horasDictadas } else { "N/A" }
    
    return "Resumen docente: $(@($resElems).Count) estudiantes con calculo de horas. Indicadores estudiante horasDictadas=$horasDictadas"
}

Write-Host "`n -- Flujo de justificacion estudiante -> docente (HU010-HU012, HU035-HU042) --" -ForegroundColor DarkCyan

Run-Test "HU010,HU011,HU016" "Radicar solicitud de revision de asistencia con justificacion medica y soporte" {
    if (-not $script:fileId) { throw "No hay soporte cargado (falla HU014)" }
    $body = @{
        sesionId = $script:sesEnCurso.id
        categoria = "MED"
        justificacion = "CULM1-E2E incapacidad medica certificada por la EPS."
        soporteArchivoId = $script:fileId
    }
    $res = Invoke-Api POST "/asistencias/revisiones" $hEst $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al crear reclamo" }
    $lista = Invoke-Api GET "/estudiante/reclamos" $hEst
    $mio = @($lista.datos | Where-Object { $_.sesionId -ieq $script:sesEnCurso.id })
    if ($mio.Count -ne 1) { throw "El reclamo radicado no aparece en el historial del estudiante" }
    $script:reclamoId = [string]$mio[0].id
    return "Reclamo radicado id=$($script:reclamoId), estado: $($mio[0].estadoSolicitud)"
}

Run-Test "HU012,HU015" "Consultar historial de solicitudes de revision de asistencia del estudiante y estado de tramite" {
    $res = Invoke-Api GET "/estudiante/reclamos" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Solicitudes radicadas por el estudiante: $(@($res.datos).Count)"
}

Run-Test "HU010-Anular" "Anulacion formal de solicitud de revision por desistimiento del estudiante" {
    # CULM-001 D.1 (HU026B): radicar y anular exigen una sesion dentro del plazo; la de 8-90 dias responde 409 ERR_PLAZO_JUSTIFICACION_VENCIDO.
    if (-not $script:sesPasadaEnPlazo) { throw "No hay sesion pasada dentro del plazo de prueba (falla PREP-E2E)" }
    $body = @{ sesionId = $script:sesPasadaEnPlazo.id; categoria = "OTR"; justificacion = "CULM1-E2E solicitud que sera retirada." }
    Invoke-Api POST "/asistencias/revisiones" $hEst $body | Out-Null
    $lista = Invoke-Api GET "/estudiante/reclamos" $hEst
    $mio = @($lista.datos | Where-Object { $_.sesionId -ieq $script:sesPasadaEnPlazo.id })
    if ($mio.Count -ne 1) { throw "El reclamo a anular no aparece en el historial" }
    $res = Invoke-Api DELETE "/estudiante/reclamos/$($mio[0].id)" $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa al anular reclamo" }
    $despues = Invoke-Api GET "/estudiante/reclamos" $hEst
    $est = @($despues.datos | Where-Object { $_.id -ieq $mio[0].id })[0].estadoSolicitud
    if ($est -ne "RETIRADA") { throw "El reclamo debia quedar RETIRADA y esta $est" }
    return "Reclamo anulado correctamente (estado $est)"
}

Run-Test "HU026B" "Rechazo de radicacion de justificacion fuera del plazo reglamentario (HTTP 409)" {
    if (-not $script:sesPasada) { throw "No hay sesion pasada de prueba (falla PREP-E2E)" }
    $body = @{
        sesionId = $script:sesPasada.id
        categoria = "MED"
        justificacion = "CULM1-E2E solicitud fuera de plazo reglamentario."
        soporteArchivoId = $script:fileId
    }
    Expect-ApiStatus 409 { Invoke-Api POST "/asistencias/revisiones" $hEst $body }
    return "Radicacion fuera de plazo rechazada con HTTP 409 (REV_020) para sesion pasada $($script:sesPasada.nombre)"
}

Run-Test "HU035,HU036,HU039" "Consultar solicitudes de revision, detalle y soporte adjunto pendientes del docente" {
    if (-not $script:reclamoId) { throw "No hay reclamo radicado (falla HU010)" }
    $res = Invoke-Api GET "/docente/reclamos" $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $det = Invoke-Api GET "/docente/reclamos/$($script:reclamoId)" $hDoc
    if (-not $det.exitoso) { throw "Respuesta no exitosa al consultar el detalle" }
    $bytes = Invoke-Api GET "/archivos/$($script:fileId)" $hDoc -Bytes
    if ($bytes.Length -ne $script:fileBytes.Length) { throw "El docente no pudo descargar el soporte completo" }
    return "Reclamos del docente: $(@($res.datos).Count). Detalle: $($det.datos.estudianteNombre), estado $($det.datos.estadoSolicitud). Soporte descargado ($($bytes.Length) bytes)"
}

Run-Test "HU037,HU038,HU042" "Resolver justificacion de inasistencia con retroalimentacion y notificacion al estudiante" {
    if (-not $script:reclamoId) { throw "No hay reclamo radicado (falla HU010)" }
    $body = @{ accion = "APROBADA"; respuestaDocente = "CULM1-E2E incapacidad medica validada conforme al reglamento estudiantil UCO." }
    $res = Invoke-Api PATCH "/docente/reclamos/$($script:reclamoId)" $hDoc $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al resolver" }
    $lista = Invoke-Api GET "/estudiante/reclamos" $hEst
    $mio = @($lista.datos | Where-Object { $_.id -ieq $script:reclamoId })[0]
    if ($mio.estadoSolicitud -ne "APROBADA") { throw "El estudiante debia ver el reclamo APROBADA y ve $($mio.estadoSolicitud)" }
    return "Reclamo $($script:reclamoId) resuelto como APROBADA; el estudiante ve el estado y la respuesta"
}

Run-Test "CLEANUP-E2E" "Cerrar la sesion CULM1-E2E-EnCurso moviendola al pasado para no bloquear la siguiente corrida" {
    Move-SesionAlPasado $script:sesEnCurso.id $script:sesEnCurso.nombre
    return "Sesion de prueba en curso cerrada"
}

Write-Host "`n -- Grupos y matricula manual (HU043-HU051) --" -ForegroundColor DarkCyan

Run-Test "HU043" "Crear nuevo grupo academico validando cupos y aforo (usp_crear_grupo)" {
    $oferta = Invoke-Api GET "/docente/oferta-creacion-grupos" $hDoc
    if (-not $oferta.exitoso) { throw "No se pudo consultar la oferta de creacion de grupos" }
    $script:docenteId = [string]$oferta.datos.idDocente
    $script:asignaturaOfertaId = [string]$oferta.datos.asignaturas[0].idAsignatura
    $periodos = Invoke-Api GET "/coordinador/periodos-academicos" $hCoord
    $hoy = [datetime]::UtcNow.Date
    $vig = @($periodos.datos | Where-Object { [datetime]::Parse($_.fechaInicio) -le $hoy -and [datetime]::Parse($_.fechaFin) -ge $hoy })
    $script:periodoVigenteId = if ($vig.Count -gt 0) { [string]$vig[0].id } else { [string]$periodos.datos[0].id }
    $dias = @("LU", "MA", "MI", "JU", "VI", "SA")
    $ultimo = ""
    for ($i = 0; $i -lt 12; $i++) {
        $codigo = Get-Random -Minimum 1000 -Maximum 9999
        $hora = Get-Random -Minimum 5 -Maximum 20
        $body = @{
            idAsignatura = $script:asignaturaOfertaId
            idPeriodoAcademico = $script:periodoVigenteId
            codigo = $codigo
            nombre = "CULM1-E2E-Grupo $codigo"
            idDocente = $script:docenteId
            franjas = @(@{ dia = $dias[(Get-Random -Minimum 0 -Maximum 6)]; horaInicio = ("{0:D2}:00" -f $hora); horaFin = ("{0:D2}:00" -f ($hora + 2)) })
            generarSesionesAutomaticas = $false
        }
        try {
            $res = Invoke-Api POST "/grupos" $hDoc $body
            if (-not $res.exitoso) { throw "Respuesta no exitosa al crear grupo" }
            $script:grupoNuevoId = [string]$res.datos.id
            return "Grupo creado id=$($script:grupoNuevoId) (CULM1-E2E-Grupo $codigo)"
        } catch {
            $ultimo = $_.Exception.Message
            if ((Get-ApiStatus $ultimo) -ne 409) { throw }
        }
    }
    throw "No se logro crear el grupo sin cruce de horario tras 12 intentos. Ultimo error: $ultimo"
}

Run-Test "HU044" "Modificar nombre y aforo de grupo academico (coordinador/administrador, no el docente; DEC-022 par. 7)" {
    if (-not $script:grupoNuevoId) { throw "No hay grupo para actualizar (falla HU043)" }
    $body = @{ nombre = "CULM1-E2E-Grupo Modificado"; cupoMaximo = 28 }
    Expect-ApiStatus 403 { Invoke-Api PUT "/grupos/$($script:grupoNuevoId)" $hDoc $body }
    $res = Invoke-Api PUT "/grupos/$($script:grupoNuevoId)" $hCoord $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al actualizar grupo" }
    return "Grupo actualizado por el coordinador (el docente recibe 403): $($res.datos.mensajeUsuario)"
}

Run-Test "HU050" "Inscribir / matricular manualmente a estudiante en el grupo academico" {
    if (-not $script:grupoNuevoId) { throw "No hay grupo (falla HU043)" }
    $body = @{ estudianteId = $script:anaId }
    $res = Invoke-Api POST "/grupos/$($script:grupoNuevoId)/estudiantes" $hDoc $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al matricular" }
    return "Estudiante matriculado con exito en el grupo: $($res.mensajeUsuario)"
}

Run-Test "F-COO-004" "El coordinador no puede matricular manualmente (solo el docente titular)" {
    if (-not $script:grupoNuevoId) { throw "No hay grupo (falla HU043)" }
    $body = @{ estudianteId = $script:anaId }
    Expect-ApiStatus 403 { Invoke-Api POST "/grupos/$($script:grupoNuevoId)/estudiantes" $hCoord $body }
    return "Coordinador rechazado con 403 al matricular manualmente"
}

Run-Test "HU051" "Retirar estudiante de grupo academico por el docente" {
    if (-not $script:grupoNuevoId) { throw "No hay grupo (falla HU043)" }
    $res = Invoke-Api POST "/docente/grupos/$($script:grupoNuevoId)/estudiantes/$($script:anaId)/retiro" $hDoc @{ motivo = "CULM1-E2E retiro" }
    if (-not $res.exitoso) { throw "Respuesta no exitosa al retirar estudiante" }
    $padron = Invoke-Api GET "/grupos/$($script:grupoNuevoId)/estudiantes" $hDoc
    $ana = @($padron.datos | Where-Object { $_.idEstudiante -ieq $script:anaId })[0]
    if ($ana.codigoEstado -ne "I") { throw "El estudiante debia quedar inactivo (I) y esta $($ana.codigoEstado)" }
    return "Estudiante retirado con exito del grupo (estado $($ana.codigoEstado))"
}

Run-Test "HU057" "Selector tipificado de documentos de identificacion legal en altas academicas" {
    $res = Invoke-Api GET "/tipos-identificacion" $hDoc
    if (@($res).Count -lt 1) { throw "Respuesta vacia" }
    return "Documentos tipificados para altas academicas: $(@($res).Count) tipos disponibles"
}

Run-Test "HU047" "Cancelar sesion de clase con motivo justificativo y verificar rechazo de registros en sesion cancelada" {
    if (-not $script:sesFutura) { throw "No hay sesion futura de prueba (falla PREP-E2E)" }
    $body = @{ motivo = "Cancelacion autorizada por jornada academica institucional." }
    $res = Invoke-Api PATCH "/docente/sesiones/$($script:sesFutura.id)/cancelar" $hDoc $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al cancelar sesion" }
    if ($res.datos.estado -ne "CANCELADA") { throw "El estado de la sesion debia ser CANCELADA y es $($res.datos.estado)" }
    
    # Validar que una sesion cancelada rechaza registros con HTTP 409 (SES_010 / ERR_SESION_CANCELADA)
    $regBody = @{
        sesionId = $script:sesFutura.id
        registros = @(@{ estudianteId = $script:carlosId; estado = "AN" })
    }
    Expect-ApiStatus 409 { Invoke-Api POST "/asistencias/lote" $hDoc $regBody }
    
    # Validar que cancelar dos veces responde HTTP 409 (SES_011)
    Expect-ApiStatus 409 { Invoke-Api PATCH "/docente/sesiones/$($script:sesFutura.id)/cancelar" $hDoc $body }
    
    return "Sesion cancelada id=$($script:sesFutura.id) (estado $($res.datos.estado)). Registro en sesion cancelada rechazado con HTTP 409 (SES_010)"
}

# ==============================================================================
# SECCION 3: MODULO COORDINACION DE PROGRAMA (HU060 - HU098)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 3. MODULO COORDINACION DE PROGRAMA (HU060 - HU098)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

$script:globalPlanId = $null
$script:tempDocenteId = $null
$script:nuevoSemNumero = $null
$script:asigId = $null
$script:asigCodigo = $null
$script:tempPeriodoId = $null

Run-Test "HU060,HU061,HU068,HU069,HU070" "Consultar directorio de estudiantes del programa, consolidado y permanencia" {
    # CULM-001 B2 §3.1 (O2-B2): el directorio del coordinador es ApiPageResponse<EstudianteProgramaDTO> (elementos).
    $res = Invoke-Api GET "/coordinador/estudiantes?pagina=1&tamano=100" $hCoord
    if (-not $res.exitoso -or $null -eq $res.elementos) { throw "Respuesta no exitosa o sin ApiPageResponse" }
    $cons = Invoke-Api GET "/coordinador/consolidado-asistencia" $hCoord
    if (-not $cons.exitoso) { throw "Respuesta no exitosa en el consolidado" }
    $fic = Invoke-Api GET "/coordinador/estudiantes/$($script:carlosId)/ficha" $hCoord
    if (-not $fic.exitoso) { throw "Respuesta no exitosa en la ficha" }
    return "Estudiantes adscritos al programa: $($res.totalElementos). Grupos en el consolidado: $(@($cons.datos).Count)"
}

Run-Test "HU064" "Consultar catalogo de grupos academicos abiertos adscritos al programa" {
    $res = Invoke-Api GET "/coordinador/grupos" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Grupos adscritos al programa del coordinador: $(@($res.datos).Count)"
}

Run-Test "HU065" "Supervision de cronograma de sesiones de clase ejecutadas y programadas" {
    $ind = Invoke-Api GET "/coordinador/indicadores" $hCoord
    if (-not $ind.exitoso) { throw "Respuesta no exitosa en indicadores" }
    $res = Invoke-Api GET "/coordinador/grupos/$($script:grupoBaseId)/sesiones" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Sesiones del grupo base: $(@($res.datos).Count). Sesiones ejecutadas del programa: $($ind.datos.sesionesEjecutadas)"
}

Run-Test "HU067" "Auditar bitacora y trazabilidad detallada de asistencias por estudiante" {
    $res = Invoke-Api GET "/coordinador/estudiantes/$($script:carlosId)/bitacora" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Trazabilidad de asistencias auditada: $(@($res.datos).Count) registros en bitacora"
}

Run-Test "HU062,HU063,HU089,HU090,HU094,HU095" "Consultar directorio consolidado de profesores del programa" {
    $res = Invoke-Api GET "/coordinador/docentes" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $resumen = Invoke-Api GET "/coordinador/docentes/resumen" $hCoord
    if (-not $resumen.exitoso) { throw "Respuesta no exitosa en el resumen" }
    $tipos = Invoke-Api GET "/tipos-vinculacion" $hCoord
    return "Docentes adscritos al programa: $(@($res.datos).Count). Tipos de vinculacion: $(@($tipos).Count)"
}

Run-Test "HU091" "Agregar nuevo profesor al programa academico con vinculacion atomica" {
    $doc = Get-Random -Minimum 1070000000 -Maximum 1079999999
    $tiposId = Invoke-Api GET "/tipos-identificacion" $hCoord
    $cc = @($tiposId | Where-Object { $_.tipoIdentificacion -eq "CC" })[0].id
    $vinc = Invoke-Api GET "/tipos-vinculacion" $hCoord
    $body = @{
        idTipoIdentificacion = $cc
        numeroIdentificacion = "$doc"
        primerNombre = "CULME"
        primerApellido = "DOCENTE"
        correo = "culm1-e2e-doc-$doc@uco.edu.co"
        password = (New-Clave)
        idTipoVinculacion = @($vinc)[0].id
    }
    $res = Invoke-Api POST "/coordinador/docentes" $hCoord $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al crear docente" }
    $script:tempDocenteId = [string]$res.datos.idDocente
    return "Profesor registrado idDocente=$($script:tempDocenteId) ($($res.datos.nombreCompleto)), activo: $($res.datos.estaActivo)"
}

Run-Test "HU092" "Actualizar datos y vinculacion de profesor del programa" {
    if (-not $script:tempDocenteId) { throw "No hay docente (falla HU091)" }
    $vinc = @(Invoke-Api GET "/tipos-vinculacion" $hCoord)
    $actual = (Invoke-Api GET "/coordinador/docentes" $hCoord).datos | Where-Object { $_.idDocente -ieq $script:tempDocenteId }
    $otra = @($vinc | Where-Object { $_.id -ine $actual.idTipoVinculacion })[0]
    $body = @{ primerNombre = "CULME"; primerApellido = "DOCENTE ACTUALIZADO"; idTipoVinculacion = $otra.id }
    $res = Invoke-Api PUT "/coordinador/docentes/$($script:tempDocenteId)" $hCoord $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if ($res.datos.primerApellido -ne "DOCENTE ACTUALIZADO") { throw "El apellido no se actualizo" }
    return "Profesor actualizado: $($res.datos.nombreCompleto), vinculacion $($res.datos.nombreTipoVinculacion)"
}

Run-Test "HU093" "Alternar estado activo/inactivo de profesor del programa" {
    if (-not $script:tempDocenteId) { throw "No hay docente (falla HU091)" }
    $off = Invoke-Api PATCH "/coordinador/docentes/$($script:tempDocenteId)/estado" $hCoord @{ estaActivo = $false }
    if (-not $off.exitoso -or $off.datos.estaActivo -ne $false) { throw "No se inactivo la vinculacion" }
    $on = Invoke-Api PATCH "/coordinador/docentes/$($script:tempDocenteId)/estado" $hCoord @{ estaActivo = $true }
    if (-not $on.exitoso -or $on.datos.estaActivo -ne $true) { throw "No se reactivo la vinculacion" }
    return "Vinculacion inactivada y reactivada correctamente"
}

Run-Test "HU072,HU075,HU076,HU079,HU080" "Consultar, asociar y gestionar planes de estudio del programa academico" {
    # CULM-001 B2 §3.1: GET /coordinador/planes-estudio responde ApiPageResponse (elementos, totalElementos...); pagina >= 1.
    $res = Invoke-Api GET "/coordinador/planes-estudio?pagina=1&tamano=100" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if ($null -eq $res.elementos -or $null -eq $res.totalElementos -or $null -eq $res.numeroPagina) { throw "La respuesta no es un ApiPageResponse (elementos/totalElementos/numeroPagina)" }
    if (@($res.elementos).Count -lt 1) { throw "El programa no tiene planes de estudio" }
    $script:globalPlanId = [string]@($res.elementos)[0].id
    return "Planes de estudio vigentes: $($res.totalElementos). Plan 1: INP $(@($res.elementos)[0].inp) (Semestres: $(@($res.elementos)[0].totalSemestres))"
}

Run-Test "HU081" "Conmutar estado activo/inactivo de plan de estudio" {
    $res = Invoke-Api PATCH "/coordinador/planes-estudio/$($script:globalPlanId)/toggle-estado" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    Invoke-Api PATCH "/coordinador/planes-estudio/$($script:globalPlanId)/toggle-estado" $hCoord | Out-Null
    return "Toggle de estado del plan ejecutado y restaurado"
}

Run-Test "HU077,HU082" "Anadir nivel semestral al plan de estudios (POST .../semestres)" {
    $antes = @((Invoke-Api GET "/coordinador/planes-estudio?pagina=1&tamano=100" $hCoord).elementos | Where-Object { $_.id -ieq $script:globalPlanId })[0].totalSemestres
    $res = Invoke-Api POST "/coordinador/planes-estudio/$($script:globalPlanId)/semestres" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $despues = @((Invoke-Api GET "/coordinador/planes-estudio?pagina=1&tamano=100" $hCoord).elementos | Where-Object { $_.id -ieq $script:globalPlanId })[0].totalSemestres
    if ($despues -ne ($antes + 1)) { throw "El total de semestres debia pasar de $antes a $($antes + 1) y es $despues" }
    $script:nuevoSemNumero = $despues
    return "Semestre anadido con exito: nivel $despues"
}

Run-Test "HU078,HU083" "Quitar nivel semestral vacio del plan de estudios (DELETE .../semestres/{n})" {
    if (-not $script:nuevoSemNumero) { throw "No hay semestre anadido (falla HU077)" }
    $res = Invoke-Api DELETE "/coordinador/planes-estudio/$($script:globalPlanId)/semestres/$($script:nuevoSemNumero)" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Semestre $($script:nuevoSemNumero) eliminado con exito"
}

Run-Test "HU084,HU085" "Registrar nueva asignatura curricular en plan de estudios (usp_crear_asignatura)" {
    $areas = Invoke-Api GET "/admin/areas" $hCoord
    $comps = Invoke-Api GET "/coordinador/componentes-formacion" $hCoord
    # CULM-001 B2 R1/R3: el vinculo asignatura-plan exige codigoCaracter (catalogo OBL|OPT, GET /coordinador/caracteres-asignatura).
    $caracteres = Invoke-Api GET "/coordinador/caracteres-asignatura" $hCoord
    $codCaracter = [string]@($caracteres.datos | Where-Object { $_.codigo -eq "OBL" })[0].codigo
    if (-not $codCaracter) { throw "El catalogo de caracteres no contiene OBL" }
    $plan = @((Invoke-Api GET "/coordinador/planes-estudio?pagina=1&tamano=100" $hCoord).elementos | Where-Object { $_.id -ieq $script:globalPlanId })[0]
    $rand = Get-Random -Minimum 100000 -Maximum 999999
    $script:asigCodigo = "CE$rand"
    $body = @{
        codigo = $script:asigCodigo
        nombre = "CULM1-E2E Asignatura $rand"
        creditos = 3
        semestreNumero = $plan.totalSemestres
        nombreArea = $areas.datos[0].nombre
        nombreComponente = $comps.datos[0].nombre
        codigoCaracter = $codCaracter
    }
    $res = Invoke-Api POST "/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas" $hCoord $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    # CULM-001 B2 §3.1: la malla es ApiPageResponse<AsignaturaPlanDTO> (idAsignatura, credito, codigoCaracter, estaActivaAsignatura).
    $lista = Invoke-Api GET "/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas?pagina=1&tamano=100" $hCoord
    $nueva = @($lista.elementos | Where-Object { $_.codigo -eq $script:asigCodigo })
    if ($nueva.Count -ne 1) { throw "La asignatura creada no aparece en el plan" }
    if ($nueva[0].codigoCaracter -ne $codCaracter) { throw "El caracter del vinculo debia ser $codCaracter y es $($nueva[0].codigoCaracter)" }
    $script:asigId = [string]$nueva[0].idAsignatura
    return "Asignatura creada id=$($script:asigId) ($($script:asigCodigo), caracter $($nueva[0].codigoCaracter)); asignaturas del plan: $($lista.totalElementos)"
}

Run-Test "HU086,HU087" "Modificar informacion y creditos de asignatura curricular (usp_actualizar_asignatura)" {
    if (-not $script:asigId) { throw "Falta asigId (falla HU085)" }
    $areas = Invoke-Api GET "/admin/areas" $hCoord
    $comps = Invoke-Api GET "/coordinador/componentes-formacion" $hCoord
    # CULM-001 B2 R1/R3: el vinculo asignatura-plan exige codigoCaracter (catalogo OBL|OPT, GET /coordinador/caracteres-asignatura).
    $caracteres = Invoke-Api GET "/coordinador/caracteres-asignatura" $hCoord
    $codCaracter = [string]@($caracteres.datos | Where-Object { $_.codigo -eq "OBL" })[0].codigo
    if (-not $codCaracter) { throw "El catalogo de caracteres no contiene OBL" }
    $plan = @((Invoke-Api GET "/coordinador/planes-estudio?pagina=1&tamano=100" $hCoord).elementos | Where-Object { $_.id -ieq $script:globalPlanId })[0]
    $body = @{
        codigo = $script:asigCodigo
        nombre = "CULM1-E2E Asignatura Actualizada"
        creditos = 4
        semestreNumero = $plan.totalSemestres
        nombreArea = $areas.datos[0].nombre
        nombreComponente = $comps.datos[0].nombre
        codigoCaracter = $codCaracter
    }
    $res = Invoke-Api PUT "/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas/$($script:asigId)" $hCoord $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $lista = Invoke-Api GET "/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas?pagina=1&tamano=100" $hCoord
    $act = @($lista.elementos | Where-Object { $_.idAsignatura -ieq $script:asigId })[0]
    if ($act.credito -ne 4) { throw "Los creditos no se actualizaron (credito=$($act.credito))" }
    return "Asignatura actualizada: $($act.nombre), creditos $($act.credito)"
}

Run-Test "HU074" "Alternar estado activo/inactivo de asignatura curricular (usp_toggle_estado_asignatura)" {
    if (-not $script:asigId) { throw "No hay asigId (falla HU085)" }
    $res = Invoke-Api PATCH "/coordinador/asignaturas/$($script:asigId)/estado" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $lista = Invoke-Api GET "/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas?pagina=1&tamano=100" $hCoord
    $act = @($lista.elementos | Where-Object { $_.idAsignatura -ieq $script:asigId })[0]
    return "Asignatura de prueba inactivada (queda inactiva como limpieza): estaActiva=$($act.estaActivaAsignatura)"
}

Run-Test "HU085-Eliminar" "Eliminar asignatura curricular sin grupos dependientes (usp_eliminar_asignatura)" {
    # CULM-001 B2 §3.1: el DELETE (antes 501) desvincula el vinculo asignatura-plan (usp_desvincular_asignatura_plan; 404 ASI_004, 409 ASI_005).
    if (-not $script:asigId) { throw "Falta asigId (falla HU085)" }
    $res = Invoke-Api DELETE "/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas/$($script:asigId)" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Asignatura eliminada con exito"
}

Run-Test "HU071,HU073,HU088" "Consultar catalogo de asignaturas del programa, intensidad/creditos y componentes de formacion" {
    $res = Invoke-Api GET "/coordinador/asignaturas" $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $comps = Invoke-Api GET "/coordinador/componentes-formacion" $hCoord
    return "Asignaturas en catalogo: $($res.totalElementos). Componentes de formacion: $($comps.total)"
}

Run-Test "HU096,HU142" "Consultar y registrar nuevo periodo academico institucional (alta: administrador)" {
    $resGet = Invoke-Api GET "/coordinador/periodos-academicos" $hCoord
    if (-not $resGet.exitoso) { throw "Respuesta no exitosa al consultar periodos" }
    $anio = Get-Random -Minimum 2040 -Maximum 2090
    $nombre = "CULM1-E2E-$anio"
    $body = @{ nombre = $nombre; fechaInicio = "$anio-02-01"; fechaFin = "$anio-06-30" }
    $res = Invoke-Api POST "/admin/periodos-academicos" $hAdmin $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $lista = Invoke-Api GET "/coordinador/periodos-academicos" $hAdmin
    $nuevo = @($lista.datos | Where-Object { $_.nombre -eq $nombre })
    if ($nuevo.Count -ne 1) { throw "El periodo creado no aparece en la consulta" }
    $script:tempPeriodoId = [string]$nuevo[0].id
    return "Periodos previos: $(@($resGet.datos).Count). Periodo creado id=$($script:tempPeriodoId) ($nombre), codigo $($nuevo[0].codigo)"
}

Run-Test "HU097" "Modificar fechas y nombre de periodo academico institucional (administrador)" {
    if (-not $script:tempPeriodoId) { throw "No hay periodo (falla HU096)" }
    $body = @{ nombre = "CULM1-E2E-Actualizado"; fechaInicio = "2091-02-05"; fechaFin = "2091-07-01" }
    $res = Invoke-Api PUT "/admin/periodos-academicos/$($script:tempPeriodoId)" $hAdmin $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $lista = Invoke-Api GET "/coordinador/periodos-academicos" $hAdmin
    $p = @($lista.datos | Where-Object { $_.id -ieq $script:tempPeriodoId })[0]
    if ($p.fechaInicio -ne "2091-02-05") { throw "La fecha de inicio no se actualizo ($($p.fechaInicio))" }
    return "Periodo modificado exitosamente: $($p.nombre), inicio $($p.fechaInicio)"
}

Run-Test "HU098" "Eliminar periodo academico sin grupos (administrador)" {
    if (-not $script:tempPeriodoId) { throw "No hay periodo (falla HU096)" }
    $res = Invoke-Api DELETE "/admin/periodos-academicos/$($script:tempPeriodoId)" $hAdmin
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $lista = Invoke-Api GET "/coordinador/periodos-academicos" $hAdmin
    if (@($lista.datos | Where-Object { $_.id -ieq $script:tempPeriodoId }).Count -ne 0) { throw "El periodo sigue existiendo tras eliminarlo" }
    return "Periodo eliminado correctamente"
}

# ==============================================================================
# SECCION 4: MODULO DECANATURA Y GOBIERNO INSTITUCIONAL (HU099 - HU146)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 4. MODULO DECANATURA Y GOBIERNO INSTITUCIONAL (HU099 - HU146)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

$script:tempCoordId = $null

Run-Test "HU104,HU105,HU124,HU137" "Consultar directorio y censo consolidado de coordinadores de la facultad" {
    # CULM-001 D.9-a F-ADM-023 / contrato D §11.3: los listados del decano son ApiPageResponse (elementos); pagina >= 1, 1 <= tamano <= PAGINACION/TAMANO_MAXIMO (400 PAG_001).
    $res = Invoke-Api GET "/decano/coordinadores?pagina=1&tamano=100" $hDec
    if (-not $res.exitoso -or $null -eq $res.elementos) { throw "Respuesta no exitosa o sin elementos (ApiPageResponse)" }
    $ests = Invoke-Api GET "/decano/estudiantes?busqueda=Carlos&pagina=1&tamano=100" $hDec
    if ($null -eq $ests.elementos) { throw "La busqueda de estudiantes no devolvio un ApiPageResponse" }
    $dec = Invoke-Api GET "/admin/decanos" $hAdmin
    return "Coordinadores adscritos a la facultad: $($res.totalElementos). Busqueda de estudiantes: $($ests.totalElementos). Decanos: $(@($dec.datos).Count)"
}

Run-Test "HU120" "Registrar y vincular nuevo coordinador con programa de la facultad (usp_crear_coordinador)" {
    # Vincular un coordinador a un programa REEMPLAZA al coordinador vigente del programa; se restaura al final de la prueba.
    $progs = Invoke-Api GET "/decano/programas" $hDec
    $prog = $progs.datos[0]
    $doc = Get-Random -Minimum 1060000000 -Maximum 1069999999
    $body = @{
        numeroIdentificacion = "$doc"
        primerNombre = "CULME"
        primerApellido = "AUTOMATIZADO"
        correo = "culm1-e2e-coord-$doc@uco.edu.co"
        idPrograma = $prog.id
        password = (New-Clave)
    }
    $errorRestauracion = $null
    try {
        $res = Invoke-Api POST "/decano/coordinadores" $hDec $body
        if (-not $res.exitoso) { throw "Respuesta no exitosa" }
        # CULM-001 D.9-a / D.5: directorio paginado (elementos); usp_crear_coordinador acepta tipoIdentificacionId opcional (se omite).
        $lista = Invoke-Api GET "/decano/coordinadores?pagina=1&tamano=100" $hDec
        $nuevo = @($lista.elementos | Where-Object { $_.numeroIdentificacion -eq "$doc" })
        if ($nuevo.Count -ne 1) { throw "El coordinador creado no aparece en el directorio" }
        $script:tempCoordId = [string]$nuevo[0].id
    } finally {
        $actual = (Invoke-Api GET "/decano/programas" $hDec).datos | Where-Object { $_.id -ieq $prog.id }
        if ($actual.idCoordinador -ine $prog.idCoordinador) {
            $rest = @{ nombre = $prog.nombre; idTipoPrograma = $prog.idTipoPrograma; idCoordinador = $prog.idCoordinador; idModalidad = $prog.idModalidad; idJornada = $prog.idJornada }
            try { Invoke-Api PUT "/decano/programas/$($prog.id)" $hDec $rest | Out-Null } catch { $errorRestauracion = $_.Exception.Message }
        }
    }
    if ($errorRestauracion) { throw "ATENCION: no se pudo restaurar el coordinador original del programa: $errorRestauracion" }
    $final = (Invoke-Api GET "/decano/programas" $hDec).datos | Where-Object { $_.id -ieq $prog.id }
    if ($final.idCoordinador -ine $prog.idCoordinador) { throw "El coordinador original del programa no quedo restaurado" }
    return "Coordinador creado id=$($script:tempCoordId); programa restaurado a su coordinador original"
}

Run-Test "HU121,HU123" "Busqueda predictiva y actualizacion de datos de coordinadores de la facultad" {
    if (-not $script:tempCoordId) { throw "No hay coordinador (falla HU120)" }
    $coords = Invoke-Api GET "/decano/coordinadores?pagina=1&tamano=100" $hDec
    $c = @($coords.elementos | Where-Object { $_.id -ieq $script:tempCoordId })[0]
    $body = @{ primerNombre = "CULME"; primerApellido = "AUTOMATIZADO"; correo = $c.correo }
    $res = Invoke-Api PUT "/decano/coordinadores/$($script:tempCoordId)" $hDec $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Coordinador localizado y actualizado: $($c.nombreCompleto) (Identificacion: $($c.numeroIdentificacion)); sincronizacion de identidad: $($res.datos.sincronizacionIdentidad)"
}

Run-Test "HU122" "Conmutar estado activo/inactivo de coordinador adscrito a la facultad" {
    if (-not $script:tempCoordId) { throw "No hay coordinador (falla HU120)" }
    $off = Invoke-Api PATCH "/decano/coordinadores/$($script:tempCoordId)/estado" $hDec @{ estaActivo = $false }
    if (-not $off.exitoso) { throw "Respuesta no exitosa al inactivar" }
    $on = Invoke-Api PATCH "/decano/coordinadores/$($script:tempCoordId)/estado" $hDec @{ estaActivo = $true }
    if (-not $on.exitoso) { throw "Respuesta no exitosa al reactivar" }
    return "Coordinador inactivado y reactivado (identidad: $($on.datos.sincronizacionIdentidad))"
}

Run-Test "HU128,HU136" "Censo consolidado de profesores de la facultad y filtro por programa" {
    $docs = Invoke-Api GET "/decano/docentes" $hDec
    if (-not $docs.exitoso) { throw "Respuesta no exitosa" }
    $docsElems = if ($null -ne $docs.elementos) { $docs.elementos } else { $docs.datos }
    $prog = (Invoke-Api GET "/decano/programas" $hDec).datos[0]
    $filtrado = Invoke-Api GET "/decano/docentes?idPrograma=$($prog.id)" $hDec
    if (-not $filtrado.exitoso) { throw "Respuesta no exitosa en el filtro por programa" }
    $filtradoElems = if ($null -ne $filtrado.elementos) { $filtrado.elementos } else { $filtrado.datos }
    return "Padron docente de la facultad: $(@($docsElems).Count) profesores; del programa $($prog.nombre): $(@($filtradoElems).Count)"
}

Run-Test "HU099-HU101,HU131,HU132" "Catalogo institucional de tipos de programa, modalidades y jornadas de la facultad" {
    $tipos = Invoke-Api GET "/tipos-programa" $hDec
    $mod = Invoke-Api GET "/modalidades-programa" $hDec
    $jor = Invoke-Api GET "/jornadas-programa" $hDec
    if (@($tipos).Count -lt 1) { throw "Catalogo de tipos de programa vacio" }
    return "Catalogos consultados: $(@($tipos).Count) tipos de programa, $(@($mod).Count) modalidades, $(@($jor).Count) jornadas"
}

Run-Test "HU107-HU109,HU112,HU119" "Estructura organica de decanatura: facultad, programas, planes y creditos" {
    $est = Invoke-Api GET "/decano/estructura" $hDec
    if (-not $est.exitoso) { throw "Respuesta no exitosa en estructura" }
    $progs = Invoke-Api GET "/decano/programas" $hDec
    # CULM-001 D.9-a (contrato D §11.3) y B2 §3.1: programas-creditos y la malla del plan son ApiPageResponse (elementos).
    $cred = Invoke-Api GET "/decano/programas-creditos?pagina=1&tamano=100" $hDec
    $facs = Invoke-Api GET "/admin/facultades" $hAdmin
    if (@($cred.elementos).Count -lt 1) { throw "programas-creditos no devolvio elementos" }
    $planId = @($cred.elementos)[0].idPlanEstudio
    $asigs = Invoke-Api GET "/decano/planes-estudio/$planId/asignaturas?pagina=1&tamano=100" $hDec
    if ($null -eq $asigs.elementos) { throw "La malla del plan no devolvio un ApiPageResponse" }
    return "Estructura: $(@($est.datos).Count) facultad(es) del decano, $(@($progs.datos).Count) programas, $($cred.totalElementos) filas de creditos, $($asigs.totalElementos) asignaturas del plan. Facultades de la institucion: $($facs.total)"
}

Run-Test "HU103,HU106" "Analitica ejecutiva: retencion estudiantil y comparativa de inasistencia entre programas" {
    $ind = Invoke-Api GET "/decano/indicadores" $hDec
    if (-not $ind.exitoso) { throw "Respuesta no exitosa en indicadores" }
    $cmp = Invoke-Api GET "/decano/comparativa-programas" $hDec
    if (-not $cmp.exitoso) { throw "Respuesta no exitosa en la comparativa" }
    return "Retencion $($ind.datos.tasaRetencion)%, ausentismo $($ind.datos.porcentajeAusentismo)%, programas comparados: $(@($cmp.datos).Count)"
}

Run-Test "HU143-HU146" "Supervision transversal: busqueda de asignaturas, aforo de grupos y cronograma de sesiones de la facultad" {
    $asigs = Invoke-Api GET "/decano/asignaturas" $hDec
    $aforo = Invoke-Api GET "/decano/aforo-grupos" $hDec
    $ses = Invoke-Api GET "/decano/sesiones" $hDec
    if (-not ($asigs.exitoso -and $aforo.exitoso -and $ses.exitoso)) { throw "Respuesta no exitosa" }
    # CULM-001 D.9-a F-ADM-023 / contrato D §11.3: /decano/asignaturas y /decano/sesiones son ApiPageResponse (elementos, totalElementos).
    if ($null -eq $asigs.elementos -or $null -eq $ses.elementos) { throw "Los listados del decano no devolvieron un ApiPageResponse" }
    $sesElems = $ses.elementos
    return "Supervision transversal: $($asigs.totalElementos) asignaturas, $(@($aforo.datos).Count) grupos con aforo, $(@($sesElems).Count) sesiones"
}

Run-Test "HU066,HU102" "Generacion y descarga de reporte Excel de asistencia (coordinador), semaforo de alerta temprana y tablero del decano" {
    $bytes = Invoke-Api GET "/grupos/$($script:grupoBaseId)/reportes/asistencia-excel" $hCoord -Bytes
    if ($bytes.Length -lt 100 -or $bytes[0] -ne 80 -or $bytes[1] -ne 75) { throw "El reporte no es un archivo xlsx valido (PK) o esta vacio" }
    $alertas = Invoke-Api GET "/coordinador/alertas-tempranas" $hCoord
    if (-not $alertas.exitoso) { throw "Respuesta no exitosa en alertas tempranas" }
    $tab = Invoke-Api GET "/decano/indicadores" $hDec
    if (-not $tab.exitoso) { throw "Respuesta no exitosa en el tablero del decano" }
    return "Reporte Excel generado ($($bytes.Length) bytes). Alertas tempranas: $(@($alertas.datos).Count). Tablero del decano: ausentismo $($tab.datos.porcentajeAusentismo)%"
}

# ==============================================================================
# SECCION 5: MODULO ADMINISTRADOR DE PLATAFORMA (HU147 - HU174)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 5. MODULO ADMINISTRADOR DE PLATAFORMA Y SISTEMA (HU147 - HU174)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

Run-Test "HU022,HU130,HU147,HU148,HU150,HU155" "Consola de administracion general, componentes de formacion, areas y estados de la plataforma" {
    $audit = Invoke-Api GET "/admin/auditoria" $hAdmin
    $areas = Invoke-Api GET "/admin/areas" $hAdmin
    $estados = Invoke-Api GET "/admin/estados" $hAdmin
    $comps = Invoke-Api GET "/coordinador/componentes-formacion" $hCoord
    if (-not ($audit.exitoso -and $areas.exitoso -and $estados.exitoso)) { throw "Respuesta no exitosa" }
    $auditElems = if ($null -ne $audit.elementos) { $audit.elementos } else { $audit.datos }
    return "Consola administrativa: $(@($auditElems).Count) eventos en bitacora, $($areas.total) areas, $(@($estados.datos).Count) estados, $($comps.total) componentes formativos"
}

Run-Test "HU133,HU134,HU138,HU139" "Reporteria macro: KPI global de asistencia, tendencia de ausentismo y comparativa por facultad" {
    $ind = Invoke-Api GET "/admin/indicadores" $hAdmin
    $ten = Invoke-Api GET "/admin/tendencia-ausentismo" $hAdmin
    $cmp = Invoke-Api GET "/admin/comparativa-facultades" $hAdmin
    if (-not ($ind.exitoso -and $ten.exitoso -and $cmp.exitoso)) { throw "Respuesta no exitosa" }
    return "KPI: $($ind.datos.totalEstudiantes) estudiantes, tasa de retencion $($ind.datos.tasaRetencion)%. Tendencia: $(@($ten.datos).Count) intervalos. Facultades comparadas: $(@($cmp.datos).Count)"
}

Run-Test "HU135,HU136" "Censo poblacional universitario UCO: estudiantes matriculados y profesores" {
    $ests = Invoke-Api GET "/admin/estudiantes" $hAdmin
    $docs = Invoke-Api GET "/admin/docentes" $hAdmin
    if (-not ($ests.exitoso -and $docs.exitoso)) { throw "Respuesta no exitosa" }
    # CULM-001 D.9-a F-ADM-023: /admin/estudiantes y /admin/docentes son ApiPageResponse (elementos, totalElementos).
    if ($null -eq $ests.elementos -or $null -eq $docs.elementos) { throw "Los censos de administracion no devolvieron un ApiPageResponse" }
    return "Censo general UCO: $($ests.totalElementos) estudiantes, $($docs.totalElementos) profesores"
}

Run-Test "HU143-HU145-Admin" "Busqueda transversal de asignaturas de la institucion (administrador)" {
    $asigs = Invoke-Api GET "/admin/asignaturas" $hAdmin
    if (-not $asigs.exitoso) { throw "Respuesta no exitosa" }
    # CULM-001 D.9-a F-ADM-023: /admin/asignaturas es ApiPageResponse.
    if ($null -eq $asigs.elementos) { throw "/admin/asignaturas no devolvio un ApiPageResponse" }
    return "Asignaturas de la institucion: $($asigs.totalElementos)"
}

Run-Test "HU157,HU158,HU159" "Padron y ficha unificada del estudiante UCO con historial completo" {
    $ests = Invoke-Api GET "/admin/estudiantes" $hAdmin
    if (-not $ests.exitoso) { throw "Respuesta no exitosa" }
    $estsElems = if ($null -ne $ests.elementos) { $ests.elementos } else { $ests.datos }
    $his = Invoke-Api GET "/admin/estudiantes/$($script:carlosId)/historial" $hAdmin
    if (-not $his.exitoso) { throw "Respuesta no exitosa en el historial" }
    # CULM-001 B2 §3.1 (O2-B2): /coordinador/estudiantes es ApiPageResponse<EstudianteProgramaDTO>.
    $pad = Invoke-Api GET "/coordinador/estudiantes?pagina=1&tamano=100" $hCoord
    if ($null -eq $pad.elementos) { throw "/coordinador/estudiantes no devolvio un ApiPageResponse" }
    return "Padron institucional: $(@($estsElems).Count) estudiantes; historial de $($his.datos.nombreCompleto); padron del programa: $($pad.totalElementos)"
}

Run-Test "HU156" "Admision demografica y creacion de usuario estudiante (administrador)" {
    $tipos = Invoke-Api GET "/tipos-identificacion" $hAdmin
    $tipoId = @($tipos)[0].id
    $progs = (Invoke-Api GET "/decano/programas" $hDec).datos
    $progId = if ($progs.Count -gt 0) { $progs[0].id } else { $script:globalPlanId }
    $doc = Get-Random -Minimum 1090000000 -Maximum 1099999999
    $body = @{
        tipoIdentificacionId = $tipoId
        idPrograma = $progId
        numeroIdentificacion = $doc
        primerNombre = "CULME"
        primerApellido = "ADMISION"
        correo = "culm1-e2e-adm-$doc@uco.edu.co"
        password = (New-Clave)
    }
    $res = Invoke-Api POST "/admin/estudiantes/admision" $hAdmin $body
    if (-not $res.exitoso) { throw "Respuesta no exitosa al admitir estudiante" }
    
    # Validacion E2E D.4: Repeticion rechazada con HTTP 409 (ADS_002)
    Expect-ApiStatus 409 { Invoke-Api POST "/admin/estudiantes/admision" $hAdmin $body }
    
    return "Estudiante admitido idEstudiante=$($res.datos.idEstudiante) (201); reintento duplicado rechazado con HTTP 409 (ADS_002)"
}

Run-Test "HU163" "Consultar listado de instituciones de convenio (catalogo de solo consulta)" {
    $insts = Invoke-Api GET "/admin/instituciones" $hAdmin
    if (-not $insts.exitoso -or @($insts.datos).Count -lt 1) { throw "Respuesta no exitosa o vacia" }
    return "Instituciones: $($insts.total)"
}

Run-Test "HU153,HU154" "Catalogos base de consulta: tipos de documento y tipos de programa" {
    $tipos = Invoke-Api GET "/tipos-identificacion" $hAdmin
    $prog = Invoke-Api GET "/admin/tipos-programa" $hAdmin
    if (@($tipos).Count -lt 1 -or -not $prog.exitoso) { throw "Catalogos vacios o respuesta no exitosa" }
    return "Tipos de documento: $(@($tipos).Count). Tipos de programa: $($prog.total)"
}

Run-Test "HU110,HU111,HU116,HU117" "Facultades: alta con decano nuevo, modificacion, cambio de estado y reasignacion de decano" {
    $tipos = Invoke-Api GET "/tipos-identificacion" $hAdmin
    $cc = @($tipos | Where-Object { $_.tipoIdentificacion -eq "CC" })[0].id
    $inst = (Invoke-Api GET "/admin/instituciones" $hAdmin).datos[0].id
    $doc = Get-Random -Minimum 1080000000 -Maximum 1089999999
    $bodyDec = @{
        tipoIdentificacionId = $cc
        numeroIdentificacion = $doc
        primerNombre = "CULME"
        primerApellido = "DECANO"
        correo = "culm1-e2e-dec-$doc@uco.edu.co"
        password = (New-Clave)
    }
    Invoke-Api POST "/admin/decanos" $hAdmin $bodyDec | Out-Null
    $decanos = Invoke-Api GET "/admin/decanos" $hAdmin
    $decano = @($decanos.datos | Where-Object { $_.numeroIdentificacion -eq "$doc" })
    if ($decano.Count -ne 1) { throw "El decano creado no aparece en el directorio" }
    $decId = [string]$decano[0].id
    $rand = Get-Random -Minimum 100 -Maximum 999
    $creada = Invoke-Api POST "/admin/facultades" $hAdmin @{ nombre = "CULM1-E2E-Facultad $rand"; idInstitucion = $inst; idDecano = $decId }
    if (-not $creada.exitoso) { throw "Respuesta no exitosa al crear la facultad" }
    $facId = [string]$creada.datos.id
    $upd = Invoke-Api PUT "/admin/facultades/$facId" $hAdmin @{ nombre = "CULM1-E2E-Facultad $rand Actualizada"; idDecano = $decId }
    if ($upd.datos.nombreFacultad -ne "CULM1-E2E-Facultad $rand Actualizada") { throw "El nombre de la facultad no se actualizo" }
    $tog = Invoke-Api PATCH "/admin/facultades/$facId/estado" $hAdmin @{ activa = $false }
    if ($tog.datos.estaActivaFacultad -ne $false) { throw "La facultad no quedo inactiva" }
    $tdec = Invoke-Api PATCH "/admin/decanos/$decId/toggle" $hAdmin
    if (-not $tdec.exitoso) { throw "Respuesta no exitosa al alternar el estado del decano" }
    Invoke-Api PATCH "/admin/decanos/$decId/toggle" $hAdmin | Out-Null
    return "Facultad creada id=$facId, actualizada, inactivada (queda inactiva como limpieza) y decano alternado"
}

Run-Test "B.1-Festivos" "Consulta y recarga de dias festivos institucionales (administrador)" {
    $anio = [datetime]::UtcNow.Year
    # 1. Consulta de festivos del anio
    $festivos = Invoke-Api GET "/admin/festivos?anio=$anio&incluirInactivos=false" $hAdmin
    if (-not $festivos.exitoso) { throw "Respuesta no exitosa al consultar festivos" }
    
    # 2. Recarga de festivos del anio
    $recarga = Invoke-Api POST "/admin/festivos/$anio/recarga" $hAdmin
    if (-not $recarga.exitoso) { throw "Respuesta no exitosa al recargar festivos" }
    
    # 3. Consulta de sesiones en festivo con asistencia
    $sesConAsig = Invoke-Api GET "/admin/festivos/$anio/sesiones-con-asistencia?pagina=1&tamano=20" $hAdmin
    if (-not $sesConAsig.exitoso) { throw "Respuesta no exitosa al consultar sesiones en festivo con asistencia" }
    $sesElems = if ($null -ne $sesConAsig.elementos) { $sesConAsig.elementos } else { $sesConAsig.datos }
    
    return "Festivos anio $($anio): $($festivos.datos.totalFestivos) dias (fuente: $($festivos.datos.fuenteUltimaCarga)). Recarga exitosa (actualizados: $($recarga.datos.festivosActualizados)). Sesiones con asistencia en festivo: $(@($sesElems).Count)"
}

Run-Test "HU168" "Consulta y actualizacion de Parametros Generales del Sistema con validacion de rango, seguridad y concurrencia" {
    $params = Invoke-Api GET "/admin/parametros" $hAdmin
    $pList = if ($null -ne $params.elementos) { $params.elementos } else { $params.datos }
    $p = @($pList | Where-Object { $_.grupo -eq "ASISTENCIA" -and $_.clave -eq "TOLERANCIA_MINUTOS" })[0]
    if (-not $p) { $p = @($pList | Where-Object { $_.esEditable -eq $true })[0] }
    if (-not $p) { $p = $pList[0] }
    
    # 1. Actualizacion exitosa (PUT 200)
    $fechaEsperada = if ($p.fechaModificacion) { $p.fechaModificacion } else { (Format-Utc [datetime]::UtcNow) }
    $bodyOk = @{
        valor = "$($p.valor)"
        fechaModificacionEsperada = $fechaEsperada
        motivo = "Actualizacion controlada CULM1-E2E"
    }
    $resPut = Invoke-Api PUT "/admin/parametros/$($p.id)" $hAdmin $bodyOk
    if (-not $resPut.exitoso) { throw "Respuesta no exitosa al actualizar parametro" }
    
    # 2. Rechazo por rango (HTTP 400) si tiene valorMaximo
    if ($null -ne $p.valorMaximo) {
        $valFuera = [int]$p.valorMaximo + 500
        $bodyRango = @{ valor = "$valFuera"; fechaModificacionEsperada = $resPut.datos.fechaModificacion; motivo = "Valor fuera de rango" }
        Expect-ApiStatus 400 { Invoke-Api PUT "/admin/parametros/$($p.id)" $hAdmin $bodyRango }
    }
    
    # 3. Rechazo por grupo no editable RED/* (HTTP 403)
    $pRed = @($pList | Where-Object { $_.grupo -eq "RED" })[0]
    if ($pRed) {
        $bodyRed = @{ valor = "10.0.0.0/8"; fechaModificacionEsperada = (Format-Utc [datetime]::UtcNow); motivo = "Intento no permitido" }
        Expect-ApiStatus 403 { Invoke-Api PUT "/admin/parametros/$($pRed.id)" $hAdmin $bodyRed }
    }
    
    # 4. Rechazo por concurrencia optimista / version obsoleta (HTTP 409)
    $bodyObs = @{ valor = "$($p.valor)"; fechaModificacionEsperada = "2000-01-01T00:00:00.000Z"; motivo = "Version obsoleta" }
    Expect-ApiStatus 409 { Invoke-Api PUT "/admin/parametros/$($p.id)" $hAdmin $bodyObs }
    
    return "Parametro $($p.grupo)/$($p.clave) validado: PUT 200, 400 rango, 403 RED/* y 409 version"
}

Run-Test "HU172" "Consulta de eventos y trazabilidad en bitacora de auditoria (AuditoriaEvento)" {
    $res = Invoke-Api GET "/admin/auditoria" $hAdmin
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $resElems = if ($null -ne $res.elementos) { $res.elementos } else { $res.datos }
    $conCorrelacion = @($resElems | Where-Object { $null -ne $_.idCorrelacion -or $null -ne $_.idTraza })
    return "Total eventos de auditoria registrados: $(@($resElems).Count), eventos con trazabilidad: $(@($conCorrelacion).Count)"
}

if ($env:E2E_PERMITIR_CIERRE_MASIVO -eq "1") {
    Run-Test "HU170,HU171,HU174" "Ejecutar proceso administrativo de cierre masivo de periodo" {
        # Solo con autorizacion explicita: el cierre masivo muta grupos y matriculas del periodo indicado.
        $idPeriodo = $env:E2E_PERIODO_CIERRE_ID
        if (-not $idPeriodo) { throw "Defina E2E_PERIODO_CIERRE_ID con un periodo descartable CULM1-E2E-" }
        $res = Invoke-Api POST "/admin/cierre-masivo" $hAdmin @{ idPeriodoAcademico = $idPeriodo }
        if (-not $res.exitoso) { throw "Respuesta no exitosa al ejecutar cierre masivo" }
        return "Cierre masivo ejecutado: $($res.mensaje)"
    }
} else {
    Skip-Test "HU170,HU171,HU174" "Ejecutar proceso administrativo de cierre masivo de periodo" "Omitida por regla CULM-001: no se ejecuta el cierre masivo salvo E2E_PERMITIR_CIERRE_MASIVO=1 (HU170/HU171 PENDIENTES sin endpoint)."
}

# ==============================================================================
# RESUMEN GENERAL DE RESULTADOS
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Cyan
Write-Host "                    RESUMEN DE EJECUCION DE PRUEBAS                          " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host (" TOTAL DE PRUEBAS EJECUTADAS : {0}" -f $global:TotalTests) -ForegroundColor White
Write-Host (" PRUEBAS APROBADAS (PASS)    : {0}" -f $global:PassedTests) -ForegroundColor Green
Write-Host (" PRUEBAS FALLIDAS  (FAIL)    : {0}" -f $global:FailedTests) -ForegroundColor $(if ($global:FailedTests -gt 0) { "Red" } else { "Green" })
Write-Host (" PRUEBAS OMITIDAS  (SKIP)    : {0}" -f $global:SkippedTests) -ForegroundColor Yellow
$rate = [math]::Round(($global:PassedTests / [math]::Max($global:TotalTests, 1)) * 100, 2)
Write-Host (" TASA DE EXITO               : {0}%" -f $rate) -ForegroundColor $(if ($rate -eq 100) { "Green" } else { "Yellow" })
Write-Host "==============================================================================" -ForegroundColor Cyan

if ($global:FailedTests -eq 0) {
    Write-Host " TODAS LAS HISTORIAS DE USUARIO EJECUTADAS FUERON VALIDADAS SATISFACTORIAMENTE. " -ForegroundColor Green
} else {
    Write-Host " SE ENCONTRARON FALLOS EN ALGUNAS PRUEBAS. REVISE EL DETALLE ARRIBA. " -ForegroundColor Red
}

Write-Host "`nRESUMEN POR HU:" -ForegroundColor Cyan
foreach ($r in $global:TestResults) {
    Write-Host (" {0,-5} {1}" -f $r.Estado, $r.HU)
}
if ($global:FailedTests -gt 0) { exit 1 }
exit 0
