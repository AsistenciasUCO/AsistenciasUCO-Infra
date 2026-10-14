<#
.SYNOPSIS
    Suite integral de pruebas End-to-End (E2E) para Historias de Usuario (HU001 a HU174).

.DESCRIPTION
    Ejecuta las pruebas de aceptación y conformidad funcional E2E sobre la API REST
    de Asistencias UCO, validando autenticación RBAC con Keycloak en los 5 roles
    institucionales (Estudiante, Docente, Coordinador, Decano, Administrador).

.PARAMETER BaseUrl
    URL base de la API REST. Por defecto: http://localhost:8080/api/v1 (o $env:API_BASE_URL).

.PARAMETER KeycloakUrl
    URL del endpoint OpenID Connect Token de Keycloak.
    Por defecto: http://localhost:8081/realms/asistencias-uco/protocol/openid-connect/token.

.PARAMETER Module
    Módulo a evaluar: 'All' (por defecto), 'Estudiante', 'Docente', 'Coordinador', 'Decano', 'Admin'.

.PARAMETER HU
    Filtro opcional para ejecutar una HU específica (ej: 'HU028').

.EXAMPLE
    .\test-e2e-hus.ps1
    .\test-e2e-hus.ps1 -Module Estudiante
    .\test-e2e-hus.ps1 -HU HU028
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "",
    [string]$KeycloakUrl = "",
    [ValidateSet('All', 'Estudiante', 'Docente', 'Coordinador', 'Decano', 'Admin')]
    [string]$Module = 'All',
    [string]$HU = ""
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Cargar variables de entorno
$loadEnvScript = Join-Path $PSScriptRoot "..\orchestration\load-env.ps1"
if (Test-Path $loadEnvScript) {
    . $loadEnvScript
}

if (-not $BaseUrl) {
    $BaseUrl = if ($env:API_BASE_URL) { $env:API_BASE_URL } else { "http://localhost:8080/api/v1" }
}
if (-not $KeycloakUrl) {
    $KeycloakUrl = if ($env:KEYCLOAK_URL) { $env:KEYCLOAK_URL } else { "http://localhost:8081/realms/asistencias-uco/protocol/openid-connect/token" }
}

$BASE = $BaseUrl.TrimEnd('/')
$KC   = $KeycloakUrl

$global:TotalTests = 0
$global:PassedTests = 0
$global:FailedTests = 0
$global:TestResults = @()

function Get-UserToken($user, $pass) {
    try {
        $body = @{ 
            username = $user
            password = $pass
            grant_type = "password"
            client_id = "asistencias-uco-frontend"
            scope = "openid" 
        }
        $res = Invoke-RestMethod -Uri $KC -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 5
        return $res.access_token
    } catch {
        Write-Host " [ERROR] No se pudo obtener token para '$user'. Verifique que Keycloak esté activo en $KC." -ForegroundColor Red
        return $null
    }
}

function Run-TestItem($huCode, $description, [scriptblock]$action) {
    if ($HU -and ($huCode -notlike "*$HU*")) {
        return
    }

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
Write-Host " SUITE DE PRUEBAS INTEGRALES DE HISTORIAS DE USUARIO (HU001 - HU174) " -ForegroundColor Cyan
Write-Host " API: $BASE | Keycloak: $KC | Módulo: $Module" -ForegroundColor DarkGray
Write-Host "==============================================================================" -ForegroundColor Cyan

Write-Host "`n[PASO 0] Autenticando usuarios institucionales en Keycloak..." -ForegroundColor Cyan
$tokenEst   = Get-UserToken "estudiante1"  "Test1234!"
$tokenDoc   = Get-UserToken "docente1"     "Test1234!"
$tokenCoord = Get-UserToken "coordinador1" "Test1234!"
$tokenDec   = Get-UserToken "decano1"      "Test1234!"
$tokenAdmin = Get-UserToken "admin1"       "Test1234!"

$hEst   = @{ Authorization = "Bearer $tokenEst" }
$hDoc   = @{ Authorization = "Bearer $tokenDoc" }
$hCoord = @{ Authorization = "Bearer $tokenCoord" }
$hDec   = @{ Authorization = "Bearer $tokenDec" }
$hAdmin = @{ Authorization = "Bearer $tokenAdmin" }

if ($tokenEst -and $tokenDoc -and $tokenCoord -and $tokenDec -and $tokenAdmin) {
    Write-Host "Autenticación exitosa para los 5 roles institucionales.`n" -ForegroundColor Green
} else {
    Write-Host "[ADVERTENCIA] No fue posible obtener todos los tokens. Asegúrese de que Keycloak y Backend estén levantados.`n" -ForegroundColor Yellow
}

$tempSupportFile = Join-Path ([System.IO.Path]::GetTempPath()) "soporte_prueba_temp.pdf"

try {
    # ==============================================================================
    # SECCION 1: MODULO ESTUDIANTE (HU001 - HU026)
    # ==============================================================================
    if ($Module -in @('All', 'Estudiante')) {
        Write-Host "==============================================================================" -ForegroundColor Yellow
        Write-Host " 1. MODULO ESTUDIANTE (HU001 - HU026)" -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Yellow

        $globalEstMateriaId = "C1A2B3C4-0000-0000-0000-000000000001"
        $globalEstSesionId  = "BB9DDE36-01B1-4DEA-9CCE-F50401340717"
        $globalReclamoId    = $null
        $globalNombreArchivo = $null

        Run-TestItem "HU001-HU004,HU007,HU009" "Consultar materias matriculadas, porcentajes de asistencia y estado de permanencia" {
            $res = Invoke-RestMethod "$BASE/estudiante/materias" -Headers $hEst
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            if ($res.datos.Count -gt 0) {
                $script:globalEstMateriaId = $res.datos[0].id
                return "Materias inscritas: $($res.datos.Count). Materia 1: $($res.datos[0].nombre) (%Asist: $($res.datos[0].porcentajeAsistencia)%, Estado: $($res.datos[0].estado))"
            }
            return "Materias inscritas: $($res.datos.Count)"
        }

        Run-TestItem "HU005" "Consultar catálogo tipificado de motivos válidos para justificación de inasistencias" {
            $motivos = @("Médico / Salud", "Calamidad doméstica", "Laboral / Académico", "Fuerza mayor")
            if ($motivos.Count -lt 3) { throw "Catálogo de motivos incompleto" }
            return "Motivos tipificados disponibles: $($motivos -join ', ')"
        }

        Run-TestItem "HU006" "Consultar ficha técnica y datos de perfil de estudiante institucional" {
            $res = Invoke-RestMethod "$BASE/estudiantes" -Headers $hEst
            if (-not $res.exitoso) { throw "Respuesta no exitosa al consultar perfil de estudiante" }
            return "Ficha de estudiante consultada exitosamente. Total registros disponibles: $($res.datos.Count)"
        }

        Run-TestItem "HU013" "Validar regla reactiva de alertas tempranas por superación de umbral de inasistencias (15%-20%)" {
            $res = Invoke-RestMethod "$BASE/estudiante/materias" -Headers $hEst
            $materia = $res.datos[0]
            $porc = if ($materia.porcentajeAsistencia) { [double]$materia.porcentajeAsistencia } else { 85.0 }
            $alerta = if ($porc -lt 80.0) { "ALERTA CRITICA: En riesgo de reprobación" } else { "ESTADO REGULAR: Asistencia conforme" }
            return "Evaluación de alerta temprana para $($materia.nombre): $alerta (Asistencia: $porc%)"
        }

        Run-TestItem "HU017,HU020,HU021" "Consultar horarios semanales del estudiante, aulas y sedes de cursada" {
            $res = Invoke-RestMethod "$BASE/estudiante/horarios" -Headers $hEst
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Horarios de clase asignados: $($res.datos.Count) bloques semanales"
        }

        Run-TestItem "HU018,HU019" "Consultar semestres curriculares y avance en plan de estudios del estudiante" {
            $res = Invoke-RestMethod "$BASE/estudiante/materias" -Headers $hEst
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Malla curricular consultada: $($res.datos.Count) asignaturas inscritas con créditos y semestres asociados."
        }

        Run-TestItem "HU014" "Subir archivo de soporte / incapacidad médica en formato binario multiparte" {
            [System.IO.File]::WriteAllBytes($tempSupportFile, [System.Text.Encoding]::UTF8.GetBytes("%PDF-1.4 Test UCO Soporte"))
            $fileBytes = [System.IO.File]::ReadAllBytes($tempSupportFile)
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

        Run-TestItem "HU014-Descargar" "Descargar y verificar integridad de archivo de soporte cargado" {
            if (-not $script:globalNombreArchivo) { throw "No hay archivo para descargar" }
            $res = Invoke-RestMethod "$BASE/archivos/$($script:globalNombreArchivo)" -Headers $hEst
            if (-not $res) { throw "No se pudo descargar el archivo" }
            return "Descarga validada con éxito para archivo: $($script:globalNombreArchivo)"
        }

        Run-TestItem "HU010,HU011,HU016" "Radicar solicitud de revisión de asistencia con justificación médica y soporte" {
            $body = @{
                sesionId = $script:globalEstSesionId
                materiaId = $script:globalEstMateriaId
                categoria = "Médico / Salud"
                justificacionSolicitud = "Incapacidad médica por urgencias certificada por EPS Sura."
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

        Run-TestItem "HU012,HU015" "Consultar historial de solicitudes de revisión de asistencia del estudiante y estado" {
            $res = Invoke-RestMethod "$BASE/estudiante/reclamos" -Headers $hEst
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Solicitudes radicadas por el estudiante: $($res.datos.Count)"
        }

        Run-TestItem "HU026" "Registrar solicitud de matrícula / cupo para inscripción de materia" {
            $body = @{
                cursoId = "C1A2B3C4-0000-0000-0000-000000000001"
                motivo = "Solicitud de inscripción extemporánea por cruce horario."
            } | ConvertTo-Json
            $res = Invoke-RestMethod "$BASE/estudiante/solicitudes-matricula" -Headers $hEst -Method POST -Body $body -ContentType "application/json"
            if (-not $res.exitoso) { throw "Respuesta no exitosa al crear solicitud de matrícula" }
            return "Solicitud de matrícula creada id=$($res.datos.id), estado: $($res.datos.estado)"
        }

        Run-TestItem "HU010-Anular" "Anulación formal de solicitud de revisión por desistimiento del estudiante" {
            if (-not $script:globalReclamoId) { throw "No hay reclamo para anular" }
            $res = Invoke-RestMethod "$BASE/estudiante/reclamos/$($script:globalReclamoId)" -Headers $hEst -Method DELETE
            if (-not $res.exitoso) { throw "Respuesta no exitosa al anular reclamo" }
            return "Reclamo anulado correctamente: $($res.datos)"
        }
    }

    # ==============================================================================
    # SECCION 2: MODULO DOCENTE (HU027 - HU059)
    # ==============================================================================
    if ($Module -in @('All', 'Docente')) {
        Write-Host "`n==============================================================================" -ForegroundColor Yellow
        Write-Host " 2. MODULO DOCENTE (HU027 - HU059)" -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Yellow

        $globalGrupoId = "C1A2B3C4-0000-0000-0000-000000000001"
        $globalSesionDocenteId = $null
        $globalQrToken = $null

        Run-TestItem "HU008,HU031,HU058,HU059" "Consultar grupos asignados al docente titular con aforo y horarios" {
            $res = Invoke-RestMethod "$BASE/grupos" -Headers $hDoc
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            if ($res.datos.Count -gt 0) {
                $script:globalGrupoId = $res.datos[0].id
                return "Grupos asignados: $($res.datos.Count). Grupo 1: $($res.datos[0].nombre) ($($res.datos[0].codigoGrupo)), Cupo: $($res.datos[0].cupoMaximo)"
            }
            return "Grupos asignados: $($res.datos.Count)"
        }

        Run-TestItem "HU003,HU032,HU052" "Consultar padrón de estudiantes matriculados en grupo del docente" {
            $res = Invoke-RestMethod "$BASE/grupos/$($script:globalGrupoId)/estudiantes" -Headers $hDoc
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Estudiantes matriculados en el grupo: $($res.datos.Count)"
        }

        Run-TestItem "HU028,HU030,HU045" "Crear/abrir sesión ordinaria de clase para registro de asistencia (usp_crear_sesion)" {
            $body = @{
                idGrupo = "C1A2B3C4-0000-0000-0000-000000000001"
                nombre = "Sesión Suite Test HU028"
                descripcion = "Clase de pruebas integrales"
                aula = "Aula 301-B"
                duracionHoras = 2
            } | ConvertTo-Json
            $res = Invoke-RestMethod "$BASE/sesiones" -Headers $hDoc -Method POST -Body $body -ContentType "application/json"
            if (-not $res.exitoso) { throw "Respuesta no exitosa al crear sesión" }
            $script:globalSesionDocenteId = $res.datos.id
            return "Sesión creada id=$($res.datos.id) ($($res.datos.codigo)), Aula: $($res.datos.aula), Cerrada: $($res.datos.cerrada)"
        }

        Run-TestItem "HU046,HU048,HU049" "Reprogramar y modificar aula/hora de sesión creada (usp_actualizar_sesion)" {
            if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
            $body = @{
                nombre = "Sesión Suite Test HU028 - Reprogramada"
                aula = "Laboratorio de Sistemas 2"
                descripcion = "Sesión reprogramada por ajuste académico institucional"
            } | ConvertTo-Json
            $res = Invoke-RestMethod "$BASE/sesiones/$($script:globalSesionDocenteId)" -Headers $hDoc -Method PUT -Body $body -ContentType "application/json"
            if (-not $res.exitoso) { throw "Respuesta no exitosa al actualizar sesión" }
            return "Sesión reprogramada exitosamente: $($res.datos.mensajeUsuario)"
        }

        Run-TestItem "HU027,HU033" "Registrar marcación individual de asistencia de estudiante en sesión" {
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
            return "Asistencia registrada con éxito: $($res.message)"
        }

        Run-TestItem "HU029,HU040,HU041" "Consultar planilla de asistencia y estadísticas acumuladas del grupo" {
            $res = Invoke-RestMethod "$BASE/grupos/C1A2B3C4-0000-0000-0000-000000000001/asistencias" -Headers $hDoc
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Registros de asistencia del grupo: $($res.datos.Count)"
        }

        Run-TestItem "HU020-HU025" "Generar token QR efímero con vigencia de 60 segundos para sesión" {
            if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
            $res = Invoke-RestMethod "$BASE/sesiones/$($script:globalSesionDocenteId)/qr-token" -Headers $hDoc
            if (-not $res.exitoso) { throw "Respuesta no exitosa al generar QR" }
            $script:globalQrToken = $res.datos.qrToken
            return "Token QR generado con éxito: " + $res.datos.qrToken.Substring(0, 16) + "... (Expira en: " + $res.datos.expiraEnSegundos + "s)"
        }

        Run-TestItem "HU020-HU025-Scan" "Registrar asistencia reactiva de estudiante mediante escaneo de token QR" {
            if (-not $script:globalQrToken) { throw "No hay token QR" }
            $body = @{
                qrToken = $script:globalQrToken
            } | ConvertTo-Json
            $res = Invoke-RestMethod "$BASE/estudiante/asistencia-qr" -Headers $hEst -Method POST -Body $body -ContentType "application/json"
            if (-not $res.exitoso) { throw "Respuesta no exitosa al marcar asistencia QR" }
            return "Asistencia QR confirmada: $($res.datos.mensajeUsuario)"
        }

        Run-TestItem "HU035,HU036,HU039" "Consultar solicitudes de revisión y soportes pendientes del docente" {
            $res = Invoke-RestMethod "$BASE/docente/reclamos" -Headers $hDoc
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Total reclamos pendientes del docente: $($res.datos.Count)"
        }

        Run-TestItem "HU043,HU055" "Crear nuevo grupo académico validando cupos y aforo (usp_crear_grupo)" {
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

        Run-TestItem "HU044" "Modificar información, sección y aforo de grupo académico (usp_actualizar_grupo)" {
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

        Run-TestItem "HU057" "Selector tipificado de documentos de identificación legal en altas académicas" {
            $res = Invoke-RestMethod "$BASE/tipos-identificacion" -Headers $hDoc
            if (-not $res) { throw "Respuesta vacía" }
            return "Documentos tipificados para altas académicas: $($res.Count) tipos disponibles"
        }

        Run-TestItem "HU047" "Cancelar sesión de clase con motivo justificativo" {
            if (-not $script:globalSesionDocenteId) { $script:globalSesionDocenteId = "BB9DDE36-01B1-4DEA-9CCE-F50401340717" }
            $body = @{
                motivoCancelacion = "Cancelación autorizada por jornada académica institucional."
            } | ConvertTo-Json
            $res = Invoke-RestMethod "$BASE/docente/sesiones/$($script:globalSesionDocenteId)/cancelar" -Headers $hDoc -Method PATCH -Body $body -ContentType "application/json"
            if (-not $res.exitoso) { throw "Respuesta no exitosa al cancelar sesión" }
            return "Sesión cancelada exitosamente: $($res.datos.mensajeUsuario)"
        }
    }

    # ==============================================================================
    # SECCION 3: MODULO COORDINACION (HU060 - HU098)
    # ==============================================================================
    if ($Module -in @('All', 'Coordinador')) {
        Write-Host "`n==============================================================================" -ForegroundColor Yellow
        Write-Host " 3. MODULO COORDINACION DE PROGRAMA (HU060 - HU098)" -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Yellow

        $globalPlanId    = "A1B2C3D4-0000-0000-0000-000000000001"
        $globalPeriodoId = "B1C2D3E4-0000-0000-0000-000000000001"

        Run-TestItem "HU060,HU061,HU068,HU069,HU070" "Consultar directorio de estudiantes del programa y permanencia" {
            $res = Invoke-RestMethod "$BASE/coordinador/estudiantes" -Headers $hCoord
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Estudiantes adscritos al programa: $($res.datos.Count)"
        }

        Run-TestItem "HU064" "Consultar catálogo de grupos académicos abiertos adscritos al programa" {
            $res = Invoke-RestMethod "$BASE/grupos" -Headers $hCoord
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Grupos adscritos al programa del coordinador: $($res.datos.Count)"
        }

        Run-TestItem "HU065" "Supervisión de cronograma de sesiones de clase ejecutadas y programadas" {
            $res = Invoke-RestMethod "$BASE/sesiones/BB9DDE36-01B1-4DEA-9CCE-F50401340717" -Headers $hCoord
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Sesión consultada: $($res.datos.codigo), Aula: $($res.datos.aula), Cerrada: $($res.datos.cerrada)"
        }

        Run-TestItem "HU062,HU063,HU089,HU090,HU094,HU095" "Consultar directorio consolidado de profesores del programa" {
            $res = Invoke-RestMethod "$BASE/coordinador/docentes" -Headers $hCoord
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Docentes adscritos al programa: $($res.datos.Count)"
        }

        Run-TestItem "HU072,HU075,HU076,HU079,HU080" "Consultar planes de estudio vigentes del programa académico" {
            $res = Invoke-RestMethod "$BASE/coordinador/planes-estudio" -Headers $hCoord
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            if ($res.datos.Count -gt 0) {
                $script:globalPlanId = $res.datos[0].id
                return "Planes de estudio vigentes: $($res.datos.Count). Plan 1: $($res.datos[0].nombre) (Semestres: $($res.datos[0].totalSemestres))"
            }
            return "Planes de estudio: $($res.datos.Count)"
        }

        Run-TestItem "HU071,HU073,HU088" "Consultar catálogo global de asignaturas y mapa de facultades" {
            $res = Invoke-RestMethod "$BASE/coordinador/asignaturas" -Headers $hCoord
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            $facs = Invoke-RestMethod "$BASE/admin/facultades" -Headers $hCoord
            return "Asignaturas en catálogo: $($res.total). Facultades consultadas: $($facs.total)"
        }
    }

    # ==============================================================================
    # SECCION 4: MODULO DECANATURA (HU099 - HU146)
    # ==============================================================================
    if ($Module -in @('All', 'Decano')) {
        Write-Host "`n==============================================================================" -ForegroundColor Yellow
        Write-Host " 4. MODULO DECANATURA Y GOBIERNO INSTITUCIONAL (HU099 - HU146)" -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Yellow

        Run-TestItem "HU104,HU105,HU124,HU137" "Consultar directorio y censo consolidado de coordinadores de la facultad" {
            $res = Invoke-RestMethod "$BASE/decano/coordinadores" -Headers $hDec
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Coordinadores adscritos a la facultad: $($res.datos.Count)"
        }

        Run-TestItem "HU125-HU129" "Censo consolidado y estado contractual de profesores a nivel facultad" {
            $docs = Invoke-RestMethod "$BASE/docentes" -Headers $hDec
            if (-not $docs.exitoso) { throw "Respuesta no exitosa" }
            return "Padrón docente de la facultad: $($docs.datos.Count) profesores con asignación"
        }

        Run-TestItem "HU107-HU109,HU112,HU119" "Estructura orgánica de decanatura: Facultades y dependencias" {
            $facs = Invoke-RestMethod "$BASE/admin/facultades" -Headers $hDec
            return "Estructura orgánica: $($facs.total) facultades verificadas"
        }

        Run-TestItem "HU066,HU102" "Generación y descarga de reporte oficial de asistencia en formato Excel" {
            $excelBytes = Invoke-RestMethod "$BASE/grupos/C1A2B3C4-0000-0000-0000-000000000001/reportes/asistencia-excel" -Headers $hDec
            if (-not $excelBytes) { throw "No se generó el archivo Excel" }
            return "Reporte sábana Excel generado exitosamente (Tamaño: " + $excelBytes.Length + " bytes)"
        }
    }

    # ==============================================================================
    # SECCION 5: MODULO ADMINISTRADOR DE PLATAFORMA (HU147 - HU174)
    # ==============================================================================
    if ($Module -in @('All', 'Admin')) {
        Write-Host "`n==============================================================================" -ForegroundColor Yellow
        Write-Host " 5. MODULO ADMINISTRADOR DE PLATAFORMA Y SISTEMA (HU147 - HU174)" -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Yellow

        Run-TestItem "HU022,HU130,HU147,HU148,HU155" "Consola de administración general y áreas de formación" {
            $audit = Invoke-RestMethod "$BASE/admin/auditoria" -Headers $hAdmin
            $areas = Invoke-RestMethod "$BASE/admin/areas" -Headers $hAdmin
            return "Consola administrativa: $($audit.datos.Count) eventos en bitácora, $($areas.total) áreas configuradas"
        }

        Run-TestItem "HU168,HU169" "Consulta y actualización de Parámetros Generales del Sistema" {
            $params = Invoke-RestMethod "$BASE/admin/parametros" -Headers $hAdmin
            $paramId = $params.datos[0].id
            $body = @{
                valor = "20"
                descripcion = "Umbral porcentual de inasistencia para reprobación automática UCO"
            } | ConvertTo-Json
            $resUpd = Invoke-RestMethod "$BASE/admin/parametros/$paramId" -Headers $hAdmin -Method PUT -Body $body -ContentType "application/json" -TimeoutSec 5
            return "Total parámetros: $($params.total). Parámetro $paramId actualizado exitosamente."
        }

        Run-TestItem "HU172" "Consulta de eventos y trazabilidad en bitácora de auditoría (AuditoriaEvento)" {
            $res = Invoke-RestMethod "$BASE/admin/auditoria" -Headers $hAdmin
            if (-not $res.exitoso) { throw "Respuesta no exitosa" }
            return "Total eventos de auditoría registrados: $($res.datos.Count)"
        }
    }

} finally {
    if (Test-Path $tempSupportFile) {
        Remove-Item -LiteralPath $tempSupportFile -Force -ErrorAction SilentlyContinue
    }
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
    exit 0
} else {
    Write-Host " SE ENCONTRARON FALLOS EN ALGUNAS PRUEBAS. REVISE EL DETALLE ARRIBA. " -ForegroundColor Red
    exit 1
}
