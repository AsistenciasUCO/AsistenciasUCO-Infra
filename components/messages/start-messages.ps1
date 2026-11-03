<#
.SYNOPSIS
    Orquestador de arranque del componente de catalogo de mensajes MessageUcoLab (equipo de mensajeria).

.DESCRIPTION
    Levanta Complementos/CatalogoMensajes/messageucolab-local/compose.yaml (aplicacion, SurrealDB, Redis, Kong,
    Pulsar, Ollama y observabilidad) con el proyecto compose `messageucolab`. Los 5 secretos que exige la guia
    (SURREALDBUSER, SURREALDBPASSWORD, REDISPASSWORD, GF_SECURITY_ADMIN_PASSWORD, PEP_REGISTRATION_TOKEN)
    se inyectan con Doppler (`doppler run --`); este script NO los lee ni los escribe en archivos.

    El componente NO se modifica: solo se orquesta. Ver docs/hardening/MESSAGE_CATALOG_SWITCH_GUIDE.md.

.PARAMETER Down
    Detiene los contenedores (conserva volumenes y mensajes). Nunca usa `down -v`.

.PARAMETER Status
    Muestra contenedores y salud de http://localhost:8000/actuator/health.

.PARAMETER Light
    Modo ligero para equipos con poca memoria: NO levanta Ollama (ni descarga el modelo de ~2 GB), desactiva la
    traduccion con IA (TRANSLATION_AI_ENABLED=false) y omite Grafana, Prometheus y OTel Collector. El catalogo y la
    ruta publica de consumo funcionan igual; solo falla `?language=` (traduccion). Arranca por etapas porque la
    aplicacion declara depends_on de ollama-init y no se puede modificar su compose.

.PARAMETER WithUi
    Clona (si falta) y lanza el frontend de MessageUcoLab (npm run dev, puerto 5174).

.EXAMPLE
    .\start-messages.ps1
    .\start-messages.ps1 -Status
    .\start-messages.ps1 -Down
#>

[CmdletBinding()]
param(
    [switch]$Down,
    [switch]$Status,
    [switch]$WithUi,
    [switch]$Light
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$repoRoot  = (Resolve-Path (Join-Path $infraRoot "..")).Path

$messagesDir = Join-Path $repoRoot "Complementos\CatalogoMensajes"
$localDir    = Join-Path $messagesDir "messageucolab-local"
$composeFile = Join-Path $localDir "compose.yaml"
# Fuera de Complementos/: esa carpeta es de otro equipo y no se modifica (ni se le agregan archivos).
$uiRepoDir   = Join-Path $env:USERPROFILE ".asistencias-messageucolab\MessageUcolab--Frontend"
$projectName = "messageucolab"
$healthUrl   = "http://localhost:8000/actuator/health"

$requiredSecrets = @('SURREALDBUSER', 'SURREALDBPASSWORD', 'REDISPASSWORD', 'GF_SECURITY_ADMIN_PASSWORD', 'PEP_REGISTRATION_TOKEN')

if (-not (Test-Path $composeFile)) {
    throw "No se encontro compose.yaml de MessageUcoLab en: $composeFile (descomprime messageucolab-local.zip)."
}

function Assert-Docker {
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker Desktop no esta activo. Inicialo antes de continuar." }
}

function Get-HealthText {
    try {
        $r = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5
        return $r.Content
    } catch {
        return $null
    }
}

# Compose escribe progreso/avisos por stderr: se valida por $LASTEXITCODE, no por stderr.
$ErrorActionPreference = 'Continue'

if ($Status) {
    Assert-Docker
    Write-Host "`n--- Contenedores del proyecto '$projectName' ---" -ForegroundColor Cyan
    docker compose -p $projectName -f $composeFile ps
    $health = Get-HealthText
    if ($health) { Write-Host "`n[OK] $healthUrl -> $health" -ForegroundColor Green }
    else { Write-Host "`n[--] $healthUrl no responde." -ForegroundColor DarkYellow }
    exit 0
}

if ($Down) {
    Assert-Docker
    Write-Host "Deteniendo MessageUcoLab (sin borrar volumenes: los mensajes se conservan)..." -ForegroundColor Yellow
    # Las variables obligatorias del compose se necesitan solo para interpolar; valores ficticios no se persisten.
    $dummy = @{}
    foreach ($s in $requiredSecrets) { $dummy[$s] = 'x' }
    $backup = @{}
    foreach ($k in $dummy.Keys) { $backup[$k] = [Environment]::GetEnvironmentVariable($k, 'Process'); [Environment]::SetEnvironmentVariable($k, $dummy[$k], 'Process') }
    try {
        Push-Location $localDir
        docker compose -p $projectName down
    } finally {
        Pop-Location
        foreach ($k in $backup.Keys) { [Environment]::SetEnvironmentVariable($k, $backup[$k], 'Process') }
    }
    Write-Host "  -> [OK] MessageUcoLab detenido. NUNCA ejecutes 'down -v': borra todos los mensajes." -ForegroundColor Green
    exit 0
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " ASISTENCIAS UCO - INICIO DE MESSAGEUCOLAB (CATALOGO DE MENSAJES)" -ForegroundColor Cyan
Write-Host " Directorio : $localDir" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

Assert-Docker

if (-not (Get-Command doppler -ErrorAction SilentlyContinue)) {
    throw "Doppler CLI no esta instalado (winget install Doppler.doppler). Los secretos del componente viven en Doppler."
}

Push-Location $localDir
try {
    # Comprobar sesion y proyecto de Doppler sin imprimir valores.
    $namesJson = & doppler secrets --only-names --json 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Doppler sin sesion o sin proyecto vinculado. Ejecuta: doppler login ; luego `$env:DOPPLER_PROJECT='messageucolab-local'; `$env:DOPPLER_CONFIG='dev' (o doppler setup en '$localDir')"
    }
    $present = @(($namesJson | ConvertFrom-Json).PSObject.Properties.Name)
    $missing = $requiredSecrets | Where-Object { $present -notcontains $_ }
    if ($missing) { throw "Faltan secretos en Doppler (messageucolab-local/dev): $($missing -join ', ')" }

    # HALLAZGO H-07: el .env del componente publica Pulsar en el puerto 8080 del host, el mismo del Backend de Asistencias.
    # La variable del proceso tiene precedencia sobre el .env de Compose, asi que se reubica sin tocar sus archivos.
    # Pulsar solo se usa dentro de la red de Docker; ese puerto publicado no lo consume nadie.
    if (-not $env:PULSAR_GENERALPORT) { $env:PULSAR_GENERALPORT = '18082' }

    # Compose escribe avisos inocuos por stderr (p. ej. AZURE_CLIENT_ID sin definir): se valida por $LASTEXITCODE, no por stderr.
    $ErrorActionPreference = 'Continue'
    if ($Light) {
        Write-Host "`n[1/2] Levantando MessageUcoLab en MODO LIGERO (sin Ollama ni observabilidad pesada)..." -ForegroundColor Yellow
        $env:TRANSLATION_AI_ENABLED = 'false'
        # Etapa 1: infraestructura base (sin ollama, grafana, prometheus ni otel-collector).
        & doppler run -- docker compose -p $projectName up -d redis surrealdb loki pulsar kong
        if ($LASTEXITCODE -ne 0) { throw "Error al levantar la infraestructura base." }
        # Etapa 2: inicializacion de datos (tareas que terminan solas).
        & doppler run -- docker compose -p $projectName up -d redis-init surrealdb-init
        if ($LASTEXITCODE -ne 0) { throw "Error al lanzar las tareas de inicializacion." }
        foreach ($init in 'redis-message-catalog-init', 'surrealdb-message-structure-init') {
            $code = (& docker wait $init)
            if ($code -ne '0') { throw "La inicializacion '$init' termino con codigo $code. Revisa: docker logs $init" }
        }
        # Etapa 3: la aplicacion, sin arrastrar ollama-init (--no-deps).
        & doppler run -- docker compose -p $projectName up -d --no-deps messageucolab
        if ($LASTEXITCODE -ne 0) { throw "Error al levantar messageucolab-app." }
    } else {
        Write-Host "`n[1/2] Levantando MessageUcoLab (primera vez: 5-15 min por imagenes y modelo de traduccion)..." -ForegroundColor Yellow
        & doppler run -- docker compose -p $projectName up -d
        if ($LASTEXITCODE -ne 0) { throw "Error al levantar MessageUcoLab con Docker Compose." }
    }
} finally {
    Pop-Location
}

Write-Host "`n[2/2] Esperando salud del backend ($healthUrl)..." -ForegroundColor Yellow
$ok = $false
for ($i = 0; $i -lt 60 -and -not $ok; $i++) {
    $h = Get-HealthText
    if ($h -and $h -match '"status"\s*:\s*"UP"') { $ok = $true } else { Start-Sleep -Seconds 5 }
}

if ($ok) {
    Write-Host "`n==============================================================================" -ForegroundColor Green
    Write-Host " [OK] MESSAGEUCOLAB ACTIVO" -ForegroundColor Green
    Write-Host "  * Gateway Kong / API : http://localhost:8000" -ForegroundColor Cyan
    Write-Host "  * Consumo publico    : http://localhost:8000/messageucolab/v1/public/messages/{code}" -ForegroundColor Cyan
    Write-Host "  * Pantalla (opcional): http://localhost:5174  (infra.ps1 messages-ui)" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Green
} else {
    Write-Warning "El backend no reporto UP en 5 minutos. Revisa: docker logs messageucolab-app"
}

if ($WithUi) {
    if (-not (Test-Path $uiRepoDir)) {
        Write-Host "Clonando la pantalla de MessageUcoLab (rama develop)..." -ForegroundColor Yellow
        git clone -b develop https://github.com/migue8104/MessageUcolab--Frontend.git $uiRepoDir
        if ($LASTEXITCODE -ne 0) { throw "No se pudo clonar el frontend de MessageUcoLab." }
    }
    $uiCmd = "Set-Location '$uiRepoDir'; if (-not (Test-Path node_modules)) { npm install }; npm run dev"
    Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $uiCmd -WorkingDirectory $uiRepoDir
    Write-Host "  -> Pantalla de MessageUcoLab iniciandose en http://localhost:5174" -ForegroundColor Green
}
