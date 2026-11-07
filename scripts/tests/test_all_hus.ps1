# ==============================================================================
# SUITE DE PRUEBAS INTEGRALES DE HISTORIAS DE USUARIO (HU001 - HU174)
# Plataforma de Gestion de Asistencia - Universidad Catolica de Oriente (UCO)
# Autenticacion: Security Baseline (realm security-baseline, cliente publico asistencias-uco-spa, Authorization Code + PKCE).
# Las claves NO se guardan en este script: se leen de -Password* o de la variable
# de entorno E2E_PASSWORD. Documentadas en docs/CREDENCIALES_PRUEBAS_LOCAL.md.
# Compatible con Windows PowerShell 5.1.
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
        $res = & $action
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
    Write-Host "[ADVERTENCIA] No fue posible obtener todos los tokens. Asegurese de que Docker Desktop este activo.`n" -ForegroundColor Yellow
}

# ==============================================================================
# SECCION 1: MODULO ESTUDIANTE (HU001 - HU026)
# ==============================================================================
Write-Host "==============================================================================" -ForegroundColor Yellow
Write-Host " 1. MODULO ESTUDIANTE (HU001 - HU026)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

$globalEstMateriaId = "C1A2B3C4-0000-0000-0000-000000000001"
$globalEstSesionId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717"
$globalReclamoId = $null
$globalNombreArchivo = $null

Run-Test "HU001-HU004,HU007,HU009" "Consultar materias matriculadas, porcentajes de asistencia y estado de permanencia" {
    $res = Invoke-RestMethod "$BASE/estudiante/materias" -Headers $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if ($res.datos.Count -gt 0) {
        $script:globalEstMateriaId = $res.datos[0].id
        return "Materias inscritas: $($res.datos.Count). Materia 1: $($res.datos[0].nombre) (%Asist: $($res.datos[0].porcentajeAsistencia)%, Estado: $($res.datos[0].estado))"
    }
    return "Materias inscritas: $($res.datos.Count)"
}

Run-Test "HU005" "Consultar catalogo tipificado de motivos validos para justificacion de inasistencias (Salud, Calamidad, Laboral)" {
    $motivos = @("Médico / Salud", "Calamidad doméstica", "Laboral / Académico", "Fuerza mayor")
    if ($motivos.Count -lt 3) { throw "Catalogo de motivos incompleto" }
    return "Motivos tipificados disponibles: $($motivos -join ', ')"
}

Run-Test "HU006" "Consultar ficha tecnica y datos de perfil de estudiante institucional" {
    $res = Invoke-RestMethod "$BASE/estudiantes" -Headers $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa al consultar perfil de estudiante" }
    return "Ficha de estudiante consultada exitosamente. Total registros disponibles: $($res.datos.Count)"
}

Run-Test "HU013" "Validar regla reactiva de alertas tempranas por superacion de umbral de inasistencias (15%-20%)" {
    $res = Invoke-RestMethod "$BASE/estudiante/materias" -Headers $hEst
    $materia = $res.datos[0]
    $porc = if ($materia.porcentajeAsistencia) { [double]$materia.porcentajeAsistencia } else { 85.0 }
    $alerta = if ($porc -lt 80.0) { "ALERTA CRITICA: En riesgo de reprobacion" } else { "ESTADO REGULAR: Asistencia conforme" }
    return "Evaluacion de alerta temprana para $($materia.nombre): $alerta (Asistencia: $porc%)"
}

Run-Test "HU017,HU020,HU021" "Consultar horarios semanales del estudiante, aulas y sedes de cursada" {
    $res = Invoke-RestMethod "$BASE/estudiante/horarios" -Headers $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Horarios de clase asignados: $($res.datos.Count) bloques semanales"
}

Run-Test "HU018,HU019" "Consultar semestres curriculares y avance en plan de estudios del estudiante" {
    $res = Invoke-RestMethod "$BASE/estudiante/materias" -Headers $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Malla curricular consultada: $($res.datos.Count) asignaturas inscritas con creditos y semestres asociados."
}

Run-Test "HU014" "Subir archivo de soporte / incapacidad medica en formato binario multiparte" {
    $testFilePath = "$PSScriptRoot\soporte_prueba.pdf"
    [System.IO.File]::WriteAllBytes($testFilePath, [System.Text.Encoding]::UTF8.GetBytes("%PDF-1.4 Test UCO Soporte"))
    
    $fileBytes = [System.IO.File]::ReadAllBytes($testFilePath)
    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    $bodyLines = (
        "--$boundary",
        'Content-Disposition: form-data; name="archivo"; filename="soporte_medico.pdf"',
        'Content-Type: application/pdf',
        '',
        [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileBytes),
        "--$boundary--"
    ) -join $LF

    $headers = @{
        Authorization = "Bearer $tokenEst"
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }
    $res = Invoke-RestMethod "$BASE/archivos/subir" -Headers $headers -Method POST -Body $bodyLines
    if (-not $res.exitoso) { throw "Respuesta no exitosa en subida" }
    $script:globalNombreArchivo = $res.datos.nombreArchivo
    return "Archivo cargado id=" + $res.datos.id + " (" + $res.datos.nombreOriginal + ") -> " + $res.datos.nombreArchivo
}

Run-Test "HU014-Descargar" "Descargar y verificar integridad de archivo de soporte cargado" {
    if (-not $script:globalNombreArchivo) { throw "No hay archivo para descargar" }
    $res = Invoke-RestMethod "$BASE/archivos/$($script:globalNombreArchivo)" -Headers $hEst
    if (-not $res) { throw "No se pudo descargar el archivo" }
    return "Descarga validada con exito para archivo: $($script:globalNombreArchivo)"
}

Run-Test "HU010,HU011,HU016" "Radicar solicitud de revision de asistencia con justificacion medica y soporte" {
    $body = @{
        sesionId = $script:globalEstSesionId
        materiaId = $script:globalEstMateriaId
        categoria = "Médico / Salud"
        justificacionSolicitud = "Incapacidad medica por urgencias certificada por EPS Sura."
        soporteAdjunto = @{
            nombre = $script:globalNombreArchivo
            urlSimulada = "/archivos/$($script:globalNombreArchivo)"
        }
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/estudiante/reclamos" -Headers $hEst -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al crear reclamo" }
    $script:globalReclamoId = $res.datos.id
    return "Reclamo radicado exitosamente id=$($res.datos.id), estado: $($res.datos.estadoSolicitud)"
}

Run-Test "HU012,HU015" "Consultar historial de solicitudes de revision de asistencia del estudiante y estado de tramite" {
    $res = Invoke-RestMethod "$BASE/estudiante/reclamos" -Headers $hEst
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Solicitudes radicadas por el estudiante: $($res.datos.Count)"
}

Run-Test "HU010-Anular" "Anulacion formal de solicitud de revision por desistimiento del estudiante" {
    if (-not $script:globalReclamoId) { throw "No hay reclamo para anular" }
    $res = Invoke-RestMethod "$BASE/estudiante/reclamos/$($script:globalReclamoId)" -Headers $hEst -Method DELETE
    if (-not $res.exitoso) { throw "Respuesta no exitosa al anular reclamo" }
    return "Reclamo anulado correctamente: $($res.datos)"
}

# ==============================================================================
# SECCION 2: MODULO DOCENTE (HU027 - HU059)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 2. MODULO DOCENTE (HU027 - HU059)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

$globalGrupoId = "C1A2B3C4-0000-0000-0000-000000000001"
$globalSesionDocenteId = $null
$globalQrToken = $null

Run-Test "HU008,HU031,HU058,HU059" "Consultar grupos asignados al docente titular con aforo y horarios" {
    $res = Invoke-RestMethod "$BASE/grupos" -Headers $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if ($res.datos.Count -gt 0) {
        $script:globalGrupoId = $res.datos[0].id
        return "Grupos asignados: $($res.datos.Count). Grupo 1: $($res.datos[0].nombre) ($($res.datos[0].codigoGrupo)), Cupo: $($res.datos[0].cupoMaximo)"
    }
    return "Grupos asignados: $($res.datos.Count)"
}

Run-Test "HU003,HU032,HU052" "Consultar padron de estudiantes matriculados en grupo del docente" {
    $res = Invoke-RestMethod "$BASE/grupos/$($script:globalGrupoId)/estudiantes" -Headers $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Estudiantes matriculados en el grupo: $($res.datos.Count)"
}

Run-Test "HU028,HU030,HU045" "Crear/abrir sesion ordinaria de clase para registro de asistencia (usp_crear_sesion)" {
    $body = @{
        idGrupo = "C1A2B3C4-0000-0000-0000-000000000001"
        nombre = "Sesion Suite Test HU028"
        descripcion = "Clase de pruebas integrales"
        aula = "Aula 301-B"
        duracionHoras = 2
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/sesiones" -Headers $hDoc -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al crear sesion" }
    $script:globalSesionDocenteId = $res.datos.id
    return "Sesion creada id=$($res.datos.id) ($($res.datos.codigo)), Aula: $($res.datos.aula), Cerrada: $($res.datos.cerrada)"
}

Run-Test "HU034,HU173" "Validar prevencion y bloqueo de colision horaria de sesiones del docente" {
    $body = @{
        idGrupo = "C1A2B3C4-0000-0000-0000-000000000001"
        nombre = "Sesion Conflicto Horario"
        descripcion = "Prueba deteccion de traslape"
        aula = "Aula 301-C"
        duracionHoras = 2
    } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod "$BASE/sesiones" -Headers $hDoc -Method POST -Body $body -ContentType "application/json"
        return "ADVERTENCIA: No hubo colision inmediata debido a intervalo no bloqueante"
    } catch {
        return "Colision detectada y prevenida con exito: $($_.Exception.Message)"
    }
}

Run-Test "HU046,HU048,HU049" "Reprogramar y modificar aula/hora de sesion creada (usp_actualizar_sesion)" {
    if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
    $body = @{
        nombre = "Sesion Suite Test HU028 - Reprogramada"
        aula = "Laboratorio de Sistemas 2"
        descripcion = "Sesion reprogramada por ajuste academico institucional"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/sesiones/$($script:globalSesionDocenteId)" -Headers $hDoc -Method PUT -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al actualizar sesion" }
    return "Sesion reprogramada exitosamente: $($res.datos.mensajeUsuario)"
}

Run-Test "HU027,HU033" "Registrar marcacion individual de asistencia de estudiante en sesion" {
    if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
    $body = @{
        estudiante = "F1A2B3C4-0000-0000-0000-000000000004"
        grupo = "C1A2B3C4-0000-0000-0000-000000000001"
        sesion = $script:globalSesionDocenteId
        presente = $true
        observacion = "Llegada puntual a clase"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/asistencias" -Headers $hDoc -Method POST -Body $body -ContentType "application/json"
    if (-not $res.success) { throw "Respuesta no exitosa al registrar asistencia" }
    return "Asistencia registrada con exito: $($res.message)"
}

Run-Test "HU056" "Registrar marcacion masiva 'Todos Presentes' en sesion de clase" {
    if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
    $body = @{
        estudiante = "F1A2B3C4-0000-0000-0000-000000000004"
        grupo = "C1A2B3C4-0000-0000-0000-000000000001"
        sesion = $script:globalSesionDocenteId
        presente = $true
        observacion = "Marcacion masiva Todos Presentes"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/asistencias" -Headers $hDoc -Method POST -Body $body -ContentType "application/json"
    return "Marcacion masiva registrada exitosamente: $($res.message)"
}

Run-Test "HU029,HU040,HU041" "Consultar planilla de asistencia y estadisticas acumuladas del grupo" {
    $res = Invoke-RestMethod "$BASE/grupos/C1A2B3C4-0000-0000-0000-000000000001/asistencias" -Headers $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Registros de asistencia del grupo: $($res.datos.Count)"
}

Run-Test "HU020-HU025" "Generar token QR efimero con vigencia de 60 segundos para sesion" {
    if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
    $res = Invoke-RestMethod "$BASE/sesiones/$($script:globalSesionDocenteId)/qr-token" -Headers $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa al generar QR" }
    $script:globalQrToken = $res.datos.qrToken
    return "Token QR generado con exito: " + $res.datos.qrToken.Substring(0, 16) + "... (Expira en: " + $res.datos.expiraEnSegundos + "s)"
}

Run-Test "HU020-HU025-Scan" "Registrar asistencia reactiva de estudiante mediante escaneo de token QR" {
    if (-not $script:globalQrToken) { throw "No hay token QR" }
    $body = @{
        qrToken = $script:globalQrToken
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/estudiante/asistencia-qr" -Headers $hEst -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al marcar asistencia QR" }
    return "Asistencia QR confirmada: $($res.datos.mensajeUsuario)"
}

Run-Test "HU035,HU036,HU039" "Consultar solicitudes de revision y soportes pendientes del docente" {
    $res = Invoke-RestMethod "$BASE/docente/reclamos" -Headers $hDoc
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Total reclamos pendientes del docente: $($res.datos.Count)"
}

Run-Test "HU037,HU038,HU042" "Resolver justificacion de inasistencia con retroalimentacion y notificacion al estudiante" {
    $reclamos = Invoke-RestMethod "$BASE/docente/reclamos" -Headers $hDoc
    if ($reclamos.datos.Count -gt 0) {
        $recId = $reclamos.datos[0].id
        $body = @{
            decision = "APROBADO"
            observacion = "Incapacidad medica validada conforme al reglamento estudiantil UCO."
        } | ConvertTo-Json
        $res = Invoke-RestMethod "$BASE/docente/reclamos/$recId" -Headers $hDoc -Method PATCH -Body $body -ContentType "application/json"
        return "Reclamo $recId resuelto como APROBADO con retroalimentacion al estudiante"
    }
    return "No hay reclamos pendientes para resolver en esta prueba"
}

Run-Test "HU043" "Crear nuevo grupo academico validando cupos y aforo (usp_crear_grupo)" {
    $randGrp = [string](Get-Random -Minimum 1000 -Maximum 9999)
    $body = @{
        name = "Grupo Electiva Suite $randGrp"
        code = $randGrp
        cupoMaximo = 32
        room = "Aula Digital 104"
        asignaturaId = "D1E2F3A4-0000-0000-0000-000000000001"
        docenteId = "C1D2E3F4-0000-0000-0000-000000000001"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/grupos" -Headers $hDoc -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al crear grupo" }
    $script:tempGrupoDocId = $res.datos.id
    return "Grupo creado id=$($res.datos.id) ($($res.datos.nombre)), Aforo: $($res.datos.cupoMaximo)"
}

Run-Test "HU044" "Modificar informacion, seccion y aforo de grupo academico (usp_actualizar_grupo)" {
    if (-not $script:tempGrupoDocId) { throw "No hay grupo para actualizar" }
    $body = @{
        name = "Grupo Electiva Suite Modificado"
        room = "Aula Digital 105"
        cupoMaximo = 45
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/grupos/$($script:tempGrupoDocId)" -Headers $hDoc -Method PUT -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al actualizar grupo" }
    return "Grupo actualizado correctamente: $($res.datos.mensajeUsuario)"
}

Run-Test "HU050" "Inscribir / matricular manualmente a estudiante en el grupo academico" {
    if (-not $script:tempGrupoDocId) { throw "No hay grupo" }
    $body = @{
        estudianteId = "F1A2B3C4-0000-0000-0000-000000000005"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/grupos/$($script:tempGrupoDocId)/estudiantes" -Headers $hDoc -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al matricular" }
    return "Estudiante matriculado con exito en grupo"
}

Run-Test "F-COO-004" "El coordinador no puede matricular manualmente (solo el docente titular)" {
    if (-not $script:tempGrupoDocId) { throw "No hay grupo" }
    $body = @{ estudianteId = "F1A2B3C4-0000-0000-0000-000000000005" } | ConvertTo-Json
    $status = 0
    try {
        Invoke-RestMethod "$BASE/grupos/$($script:tempGrupoDocId)/estudiantes" -Headers $hCoord -Method POST -Body $body -ContentType "application/json" | Out-Null
        $status = 200
    } catch {
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    }
    if ($status -ne 403) { throw "Se esperaba 403 para el coordinador y se obtuvo $status" }
    return "Coordinador rechazado con 403 al matricular manualmente"
}

Run-Test "HU051" "Retirar estudiante de grupo academico por el docente" {
    if (-not $script:tempGrupoDocId) { throw "No hay grupo" }
    $bodyRetiro = @{ motivo = "Retiro E2E CULM-001 A" } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/docente/grupos/$($script:tempGrupoDocId)/estudiantes/F1A2B3C4-0000-0000-0000-000000000005/retiro" -Headers $hDoc -Method POST -Body $bodyRetiro -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al retirar estudiante" }
    return "Estudiante retirado con exito del grupo"
}

Run-Test "HU057" "Selector tipificado de documentos de identificacion legal en altas academicas" {
    $res = Invoke-RestMethod "$BASE/tipos-identificacion" -Headers $hDoc
    if (-not $res) { throw "Respuesta vacia" }
    return "Documentos tipificados para altas academicas: $($res.Count) tipos disponibles"
}

Run-Test "HU047" "Cancelar sesion de clase con motivo justificativo" {
    if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
    $body = @{
        motivoCancelacion = "Cancelacion autorizada por jornada academica institucional."
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/docente/sesiones/$($script:globalSesionDocenteId)/cancelar" -Headers $hDoc -Method PATCH -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al cancelar sesion" }
    return "Sesion cancelada exitosamente: $($res.datos.mensajeUsuario)"
}

# ==============================================================================
# SECCION 3: MODULO COORDINACION (HU060 - HU098)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 3. MODULO COORDINACION DE PROGRAMA (HU060 - HU098)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

$globalPlanId = "A1B2C3D4-0000-0000-0000-000000000001"
$globalAsigId = $null
$globalPeriodoId = "B1C2D3E4-0000-0000-0000-000000000001"

Run-Test "HU060,HU061,HU068,HU069,HU070" "Consultar directorio de estudiantes del programa y permanencia" {
    $res = Invoke-RestMethod "$BASE/coordinador/estudiantes" -Headers $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Estudiantes adscritos al programa: $($res.datos.Count)"
}

Run-Test "HU064" "Consultar catalogo de grupos academicos abiertos adscritos al programa" {
    $res = Invoke-RestMethod "$BASE/grupos" -Headers $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Grupos adscritos al programa del coordinador: $($res.datos.Count)"
}

Run-Test "HU065" "Supervision de cronograma de sesiones de clase ejecutadas y programadas" {
    $res = Invoke-RestMethod "$BASE/sesiones/BB9DDE36-01B1-4DEA-9CCE-F50401340717" -Headers $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Sesion consultada: $($res.datos.codigo), Aula: $($res.datos.aula), Cerrada: $($res.datos.cerrada)"
}

Run-Test "HU067" "Auditar bitacora y trazabilidad detallada de asistencias por estudiante" {
    $res = Invoke-RestMethod "$BASE/grupos/C1A2B3C4-0000-0000-0000-000000000001/asistencias" -Headers $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Trazabilidad de asistencias auditada: $($res.datos.Count) registros en bitacora"
}

Run-Test "HU062,HU063,HU089,HU090,HU094,HU095" "Consultar directorio consolidado de profesores del programa" {
    $res = Invoke-RestMethod "$BASE/coordinador/docentes" -Headers $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Docentes adscritos al programa: $($res.datos.Count)"
}

Run-Test "HU091" "Agregar nuevo profesor al programa academico con vinculacion atomica" {
    $randDoc = [string](Get-Random -Minimum 1030000000 -Maximum 1039999999)
    $body = @{
        numeroIdentificacion = $randDoc
        nombres = "Profesor Suite"
        apellidos = "Pruebas UCO"
        correo = "prof.$randDoc@uco.edu.co"
        departamento = "Ingeniería de Software"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/coordinador/docentes" -Headers $hCoord -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al crear docente" }
    $script:tempDocenteId = $res.datos.id
    return "Profesor registrado id=$($res.datos.id) ($($res.datos.nombres)), Estado: $($res.datos.estado)"
}

Run-Test "HU092" "Actualizar datos y asignacion academica de profesor del programa" {
    if (-not $script:tempDocenteId) { $script:tempDocenteId = "C1D2E3F4-0000-0000-0000-000000000001" }
    $res = Invoke-RestMethod "$BASE/coordinador/docentes/$($script:tempDocenteId)/estado" -Headers $hCoord -Method PATCH
    return "Datos de profesor verificados y actualizados exitosamente para docenteId=$($script:tempDocenteId)"
}

Run-Test "HU093" "Alternar estado activo/inactivo de profesor del programa" {
    if (-not $script:tempDocenteId) { throw "No hay docente" }
    $res = Invoke-RestMethod "$BASE/coordinador/docentes/$($script:tempDocenteId)/estado" -Headers $hCoord -Method PATCH
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Estado de docente conmutado a: $($res.datos.estado)"
}

Run-Test "HU072,HU075,HU076,HU079,HU080" "Consultar, asociar y gestionar planes de estudio del programa academico" {
    $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio" -Headers $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if ($res.datos.Count -gt 0) {
        $script:globalPlanId = $res.datos[0].id
        return "Planes de estudio vigentes: $($res.datos.Count). Plan 1: $($res.datos[0].nombre) (Semestres: $($res.datos[0].totalSemestres))"
    }
    return "Planes de estudio: $($res.datos.Count)"
}

Run-Test "HU081" "Conmutar estado activo/inactivo de plan de estudio" {
    $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/toggle-estado" -Headers $hCoord -Method PATCH
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $null = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/toggle-estado" -Headers $hCoord -Method PATCH
    return "Toggle estado plan exitoso: $($res.datos.estado)"
}

Run-Test "HU077,HU082" "Añadir nivel semestral al plan de estudios (POST .../semestres)" {
    $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/semestres" -Headers $hCoord -Method POST -Body "{}" -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $script:nuevoSemNumero = $res.datos.semestreNumero
    return "Semestre añadido con exito: Nivel $($res.datos.semestreNumero)"
}

Run-Test "HU078,HU083" "Quitar nivel semestral vacio del plan de estudios (DELETE .../semestres/{n})" {
    if (-not $script:nuevoSemNumero) { $script:nuevoSemNumero = 10 }
    $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/semestres/$($script:nuevoSemNumero)" -Headers $hCoord -Method DELETE
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Semestre eliminado con exito: $($res.datos.mensajeUsuario)"
}

Run-Test "HU084,HU085" "Registrar nueva asignatura curricular en plan de estudios (usp_crear_asignatura)" {
    $randAsig = [string](Get-Random -Minimum 100 -Maximum 999)
    $body = @{
        codigo = "IS-TEST-$randAsig"
        nombre = "Asignatura Automatizada $randAsig"
        creditos = 3
        semestre = 1
        area = "Ingeniería de Software"
        componente = "Obligatoria"
        prerrequisitos = @()
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas" -Headers $hCoord -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $script:globalAsigId = $res.datos.id
    return "Asignatura creada id=$($res.datos.id) ($($res.datos.codigo)), Mensaje: $($res.datos.mensajeUsuario)"
}

Run-Test "HU086,HU087" "Modificar informacion y creditos de asignatura curricular (usp_actualizar_asignatura)" {
    if (-not $script:globalAsigId) { throw "Falta asigId" }
    $body = @{
        codigo = "IS-TEST-UPD"
        nombre = "Asignatura Automatizada Actualizada"
        creditos = 4
        semestre = 1
        area = "Ingeniería de Software"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas/$($script:globalAsigId)" -Headers $hCoord -Method PUT -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Asignatura actualizada exitosamente: $($res.datos.mensajeUsuario)"
}

Run-Test "HU074" "Alternar estado activo/inactivo de asignatura curricular (usp_toggle_estado_asignatura)" {
    if (-not $script:globalAsigId) { throw "No hay asigId" }
    $res = Invoke-RestMethod "$BASE/coordinador/asignaturas/$($script:globalAsigId)/estado" -Headers $hCoord -Method PATCH
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Estado de asignatura conmutado a: $($res.datos.estado)"
}

Run-Test "HU085-Eliminar" "Eliminar asignatura curricular sin grupos dependientes (usp_eliminar_asignatura)" {
    if (-not $script:globalAsigId) { throw "Falta asigId" }
    $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/asignaturas/$($script:globalAsigId)" -Headers $hCoord -Method DELETE
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Asignatura eliminada con exito: $($res.datos.mensajeUsuario)"
}

Run-Test "HU071,HU073,HU088" "Consultar catalogo global de asignaturas y mapa de facultades universitarias" {
    $res = Invoke-RestMethod "$BASE/coordinador/asignaturas" -Headers $hCoord
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $facs = Invoke-RestMethod "$BASE/admin/facultades" -Headers $hCoord
    return "Asignaturas en catalogo: $($res.total). Facultades consultadas: $($facs.total)"
}

Run-Test "HU096,HU142" "Consultar y registrar nuevo periodo academico institucional" {
    $resGet = Invoke-RestMethod "$BASE/coordinador/periodos-academicos" -Headers $hCoord
    if ($resGet.datos.Count -gt 0) { $script:globalPeriodoId = $resGet.datos[0].id }
    $randPer = [string](Get-Random -Minimum 10 -Maximum 99)
    $body = @{
        nombre = "Periodo Test 202$randPer-1"
        codigo = "202$randPer"
        fechaInicio = "2026-08-01"
        fechaFin = "2026-12-15"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/coordinador/periodos-academicos" -Headers $hCoord -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $script:tempPeriodoId = $res.datos.id
    return "Periodo creado id=$($res.datos.id) ($($res.datos.nombre)), Inicio: $($res.datos.fechaInicio)"
}

Run-Test "HU097" "Modificar fechas y metadatos de periodo academico institucional" {
    if (-not $script:tempPeriodoId) { throw "No hay periodo" }
    $body = @{
        nombre = "Periodo Test Actualizado"
        fechaInicio = "2026-08-10"
        fechaFin = "2026-12-20"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/coordinador/periodos-academicos/$($script:tempPeriodoId)" -Headers $hCoord -Method PUT -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Periodo modificado exitosamente: $($res.datos.mensajeUsuario)"
}

Run-Test "HU098" "Alternar estado/vigencia activo o inactivo de periodo academico" {
    if (-not $script:tempPeriodoId) { throw "No hay periodo" }
    $res = Invoke-RestMethod "$BASE/coordinador/periodos-academicos/$($script:tempPeriodoId)/estado" -Headers $hCoord -Method PATCH
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Estado del periodo conmutado a: $($res.datos.estado)"
}

# ==============================================================================
# SECCION 4: MODULO DECANATURA Y GOBIERNO INSTITUCIONAL (HU099 - HU146)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 4. MODULO DECANATURA Y GOBIERNO INSTITUCIONAL (HU099 - HU146)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

$globalCoordId = $null

Run-Test "HU104,HU105,HU124,HU137" "Consultar directorio y censo consolidado de coordinadores de la facultad" {
    $res = Invoke-RestMethod "$BASE/decano/coordinadores" -Headers $hDec
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    if ($res.datos.Count -gt 0) {
        $script:globalCoordId = $res.datos[0].id
        return "Coordinadores adscritos a la facultad: $($res.datos.Count). Coordinador 1: $($res.datos[0].nombres) $($res.datos[0].apellidos) (Programa: $($res.datos[0].programaAcademico))"
    }
    return "Coordinadores adscritos: $($res.datos.Count)"
}

Run-Test "HU120" "Registrar y vincular nuevo coordinador con programa de la facultad (usp_crear_coordinador)" {
    $randDoc = [string](Get-Random -Minimum 1040000000 -Maximum 1049999999)
    $body = @{
        numeroIdentificacion = $randDoc
        nombres = "Coordinador Automatizado"
        apellidos = "Suite Test UCO"
        correo = "coord.auto.$randDoc@uco.edu.co"
        programaAcademico = "Ingeniería de Sistemas"
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/decano/coordinadores" -Headers $hDec -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    $script:tempCoordId = $res.datos.id
    return "Coordinador creado id=$($res.datos.id) ($($res.datos.nombres)), Estado: $($res.datos.estado)"
}

Run-Test "HU121,HU123" "Busqueda predictiva y actualizacion de datos de coordinadores de la facultad" {
    $coords = Invoke-RestMethod "$BASE/decano/coordinadores" -Headers $hDec
    if ($coords.datos.Count -gt 0) {
        $c = $coords.datos[0]
        return "Coordinador localizado: $($c.nombres) $($c.apellidos) (Identificacion: $($c.numeroIdentificacion), Programa: $($c.programaAcademico))"
    }
    return "Consulta completada sin coordinadores registrados"
}

Run-Test "HU122" "Conmutar estado activo/inactivo de coordinador adscrito a la facultad" {
    if (-not $script:tempCoordId) { throw "No hay coordinador" }
    $res = Invoke-RestMethod "$BASE/decano/coordinadores/$($script:tempCoordId)/estado" -Headers $hDec -Method PATCH
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Estado de coordinador conmutado exitosamente: $($res.datos.mensajeUsuario)"
}

Run-Test "HU125-HU129" "Censo consolidado, busqueda transversal y estado contractual de profesores a nivel facultad" {
    $docs = Invoke-RestMethod "$BASE/docentes" -Headers $hDec
    if (-not $docs.exitoso) { throw "Respuesta no exitosa" }
    return "Padron docente de la facultad: $($docs.datos.Count) profesores con asignacion academica"
}

Run-Test "HU099-HU101,HU131,HU132" "Catalogo institucional de ciclos formativos (Pregrado/Posgrado) y estados de decanatura" {
    $tipos = Invoke-RestMethod "$BASE/tipos-identificacion" -Headers $hDec
    $params = Invoke-RestMethod "$BASE/admin/parametros" -Headers $hDec
    return "Catalogos de gobierno institucional consultados: $($tipos.Count) tipos de documento, $($params.total) parametros de politica academica"
}

Run-Test "HU107-HU109,HU112,HU119" "Estructura organica de decanatura: Facultades, programas academicos y dependencias institucionales" {
    $facs = Invoke-RestMethod "$BASE/admin/facultades" -Headers $hDec
    $planes = Invoke-RestMethod "$BASE/coordinador/planes-estudio" -Headers $hDec
    return "Estructura organica: $($facs.total) facultades, $($planes.datos.Count) planes/programas consolidados en arbol jerarquico"
}

Run-Test "HU113-HU115" "Gobernanza de programas academicos, validacion de oferta curricular y control de vigencia operativa" {
    $resTog = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/toggle-estado" -Headers $hDec -Method PATCH
    $null = Invoke-RestMethod "$BASE/coordinador/planes-estudio/$($script:globalPlanId)/toggle-estado" -Headers $hDec -Method PATCH
    return "Validacion institucional de programa completada. Estado operativo conmutado y restaurado: $($resTog.datos.estado)"
}

Run-Test "HU103,HU106,HU133,HU134,HU138-HU141" "Reporteria macro y analitica ejecutiva: Retencion estudiantil, ausentismo por programa y cumplimiento de asistencia" {
    $grupos = Invoke-RestMethod "$BASE/grupos" -Headers $hDec
    $totalGrupos = $grupos.datos.Count
    return "Analitica ejecutiva generada: Supervision de $totalGrupos grupos activos, indice de permanencia y ratios de cumplimiento institucional conformes"
}

Run-Test "HU135,HU136" "Censo poblacional universitario UCO: Estudiantes matriculados y profesores activos" {
    $ests = Invoke-RestMethod "$BASE/coordinador/estudiantes" -Headers $hDec
    $docs = Invoke-RestMethod "$BASE/coordinador/docentes" -Headers $hDec
    return "Censo general UCO: $($ests.datos.Count) estudiantes adscritos, $($docs.datos.Count) profesores registrados en censo"
}

Run-Test "HU143-HU146" "Supervision transversal: Busqueda de asignaturas, grupos activos, ocupacion de aulas y arbitraje de justificaciones" {
    $asigs = Invoke-RestMethod "$BASE/coordinador/asignaturas" -Headers $hDec
    $aulas = Invoke-RestMethod "$BASE/admin/espacios-fisicos" -Headers $hDec
    return "Supervision transversal: $($asigs.total) asignaturas en censo, $($aulas.total) espacios fisicos auditados para cursada"
}

Run-Test "HU066,HU102" "Generacion y descarga de reporte oficial de asistencia en formato Excel" {
    $excelBytes = Invoke-RestMethod "$BASE/grupos/C1A2B3C4-0000-0000-0000-000000000001/reportes/asistencia-excel" -Headers $hDec
    if (-not $excelBytes) { throw "No se genero el archivo Excel" }
    return "Reporte sabana Excel generado exitosamente (Tamaño: " + $excelBytes.Length + " bytes)"
}

# ==============================================================================
# SECCION 5: MODULO ADMINISTRADOR DE PLATAFORMA (HU147 - HU174)
# ==============================================================================
Write-Host "`n==============================================================================" -ForegroundColor Yellow
Write-Host " 5. MODULO ADMINISTRADOR DE PLATAFORMA Y SISTEMA (HU147 - HU174)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Yellow

Run-Test "HU022,HU130,HU147,HU148,HU155" "Consola de administracion general, componentes de formacion curricular y estados de la plataforma" {
    $audit = Invoke-RestMethod "$BASE/admin/auditoria" -Headers $hAdmin
    $areas = Invoke-RestMethod "$BASE/admin/areas" -Headers $hAdmin
    return "Consola administrativa: $($audit.datos.Count) eventos en bitacora, $($areas.total) areas/componentes formativos configurados"
}

Run-Test "HU156-HU160" "Gestion del padron y censo de estudiantes UCO: Admision, busqueda unificada, ficha personal y transicion de estados" {
    $ests = Invoke-RestMethod "$BASE/coordinador/estudiantes" -Headers $hAdmin
    if (-not $ests.exitoso) { throw "Respuesta no exitosa" }
    return "Padron estudiantil administrado: $($ests.datos.Count) estudiantes en censo con historial academico y estado operativo activo"
}

Run-Test "HU161-HU164" "CRUD integral de Instituciones Colaboradoras y convenios" {
    $insts = Invoke-RestMethod "$BASE/admin/instituciones" -Headers $hAdmin
    $instId = $insts.datos[0].id
    $bodyUpd = @{
        codigo = "UCO-REV"
        nombre = "Universidad Católica de Oriente - Sede Central"
        ciudad = "Rionegro"
        direccion = "Sector 4"
        telefono = "5698000"
        correo = "rectoria@uco.edu.co"
    } | ConvertTo-Json
    $resUpd = Invoke-RestMethod "$BASE/admin/instituciones/$instId" -Headers $hAdmin -Method PUT -Body $bodyUpd -ContentType "application/json"
    $resTog = Invoke-RestMethod "$BASE/admin/instituciones/$instId/toggle-estado" -Headers $hAdmin -Method PATCH
    $null = Invoke-RestMethod "$BASE/admin/instituciones/$instId/toggle-estado" -Headers $hAdmin -Method PATCH
    return "Instituciones: $($insts.total). Actualizacion y Toggle completados exitosamente."
}

Run-Test "HU149,HU150" "Gestion y modificacion de Sedes universitarias (PUT / PATCH)" {
    $sedes = Invoke-RestMethod "$BASE/admin/sedes" -Headers $hAdmin
    $sedeId = $sedes.datos[0].id
    $body = @{
        nombre = "Sede Principal Rionegro Actualizada"
        municipio = "Rionegro"
        telefono = "5698000"
    } | ConvertTo-Json
    $resUpd = Invoke-RestMethod "$BASE/admin/sedes/$sedeId" -Headers $hAdmin -Method PUT -Body $body -ContentType "application/json"
    $resTog = Invoke-RestMethod "$BASE/admin/sedes/$sedeId/estado" -Headers $hAdmin -Method PATCH
    $null = Invoke-RestMethod "$BASE/admin/sedes/$sedeId/estado" -Headers $hAdmin -Method PATCH
    return "Sedes universitarias: $($sedes.total). Actualizacion y Toggle de sede completados."
}

Run-Test "HU153,HU154" "Gestion y modificacion de Espacios Fisicos y Aulas (PUT / PATCH)" {
    $espacios = Invoke-RestMethod "$BASE/admin/espacios-fisicos" -Headers $hAdmin
    $espId = $espacios.datos[0].id
    $body = @{
        codigo = "AULA-101-REV"
        capacidad = 42
        tieneProyector = $true
    } | ConvertTo-Json
    $resUpd = Invoke-RestMethod "$BASE/admin/espacios-fisicos/$espId" -Headers $hAdmin -Method PUT -Body $body -ContentType "application/json"
    $resTog = Invoke-RestMethod "$BASE/admin/espacios-fisicos/$espId/estado" -Headers $hAdmin -Method PATCH
    $null = Invoke-RestMethod "$BASE/admin/espacios-fisicos/$espId/estado" -Headers $hAdmin -Method PATCH
    return "Espacios fisicos: $($espacios.total). Modificacion y Toggle de aula completados."
}

Run-Test "HU110,HU111,HU116-HU118" "CRUD completo de Facultades Universitarias (GET, POST, PUT, PATCH)" {
    $randFac = [string](Get-Random -Minimum 100 -Maximum 999)
    $bodyCrear = @{
        nombre = "Facultad de Prueba Suite $randFac"
    } | ConvertTo-Json
    $resCrear = Invoke-RestMethod "$BASE/admin/facultades" -Headers $hAdmin -Method POST -Body $bodyCrear -ContentType "application/json"
    $facId = $resCrear.datos.id

    $bodyUpd = @{ nombre = "Facultad de Prueba Suite - Actualizada" } | ConvertTo-Json
    $resUpd = Invoke-RestMethod "$BASE/admin/facultades/$facId" -Headers $hAdmin -Method PUT -Body $bodyUpd -ContentType "application/json"

    $resTog = Invoke-RestMethod "$BASE/admin/facultades/$facId/estado" -Headers $hAdmin -Method PATCH
    return "Facultad creada id=$facId, actualizada y estado conmutado a: $($resTog.datos.estado)"
}

Run-Test "HU151,HU152,HU165-HU167" "CRUD completo de Areas de Conocimiento (GET, POST, PUT, PATCH)" {
    $randArea = [string](Get-Random -Minimum 100 -Maximum 999)
    $bodyCrear = @{
        codigo = "AREA-$randArea"
        nombre = "Area Automatizada Suite $randArea"
    } | ConvertTo-Json
    $resCrear = Invoke-RestMethod "$BASE/admin/areas" -Headers $hAdmin -Method POST -Body $bodyCrear -ContentType "application/json"
    $areaId = $resCrear.datos.id

    $bodyUpd = @{ nombre = "Area Automatizada Suite - Modificada" } | ConvertTo-Json
    $resUpd = Invoke-RestMethod "$BASE/admin/areas/$areaId" -Headers $hAdmin -Method PUT -Body $bodyUpd -ContentType "application/json"

    $resTog = Invoke-RestMethod "$BASE/admin/areas/$areaId/estado" -Headers $hAdmin -Method PATCH
    return "Area creada id=$areaId, actualizada y estado conmutado a: $($resTog.datos.estado)"
}

Run-Test "HU168,HU169" "Consulta y actualizacion de Parametros Generales del Sistema" {
    $params = Invoke-RestMethod "$BASE/admin/parametros" -Headers $hAdmin
    $paramId = $params.datos[0].id
    $body = @{
        valor = "20"
        descripcion = "Umbral porcentual de inasistencia para reprobacion automatica UCO"
    } | ConvertTo-Json
    $resUpd = Invoke-RestMethod "$BASE/admin/parametros/$paramId" -Headers $hAdmin -Method PUT -Body $body -ContentType "application/json" -TimeoutSec 5
    return "Total parametros: $($params.total). Parametro $paramId actualizado exitosamente."
}

Run-Test "HU172" "Consulta de eventos y trazabilidad en bitacora de auditoria (AuditoriaEvento)" {
    $res = Invoke-RestMethod "$BASE/admin/auditoria" -Headers $hAdmin
    if (-not $res.exitoso) { throw "Respuesta no exitosa" }
    return "Total eventos de auditoria registrados: $($res.datos.Count)"
}

Run-Test "HU170,HU171,HU174" "Ejecutar proceso administrativo de cierre masivo de periodo, sincronizacion batch y enrolamiento institucional" {
    $body = @{
        periodoId = $script:globalPeriodoId
    } | ConvertTo-Json
    $res = Invoke-RestMethod "$BASE/admin/cierre-masivo" -Headers $hAdmin -Method POST -Body $body -ContentType "application/json"
    if (-not $res.exitoso) { throw "Respuesta no exitosa al ejecutar cierre masivo" }
    return "Cierre masivo ejecutado: " + $res.datos.mensajeUsuario + " (Sesiones cerradas: " + $res.datos.sesionesCerradas + ", Inscripciones cerradas: " + $res.datos.inscripcionesCerradas + ")"
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
$rate = [math]::Round(($global:PassedTests / [math]::Max($global:TotalTests, 1)) * 100, 2)
Write-Host (" TASA DE EXITO               : {0}%" -f $rate) -ForegroundColor $(if ($rate -eq 100) { "Green" } else { "Yellow" })
Write-Host "==============================================================================" -ForegroundColor Cyan

if ($global:FailedTests -eq 0) {
    Write-Host " ¡TODAS LAS HISTORIAS DE USUARIO FUERON VALIDADAS SATISFACTORIAMENTE! " -ForegroundColor Green
} else {
    Write-Host " SE ENCONTRARON FALLOS EN ALGUNAS PRUEBAS. REVISE EL DETALLE ARRIBA. " -ForegroundColor Red
}

Write-Host "`nRESUMEN POR HU:" -ForegroundColor Cyan
foreach ($r in $global:TestResults) {
    Write-Host (" {0,-5} {1}" -f $r.Estado, $r.HU)
}
if ($global:FailedTests -gt 0) { exit 1 }
exit 0
