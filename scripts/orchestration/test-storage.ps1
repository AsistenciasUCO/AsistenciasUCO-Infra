[CmdletBinding()]
param(
    [switch]$SkipPolicyTest
)

$ErrorActionPreference = 'Stop'

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " ASISTENCIAS UCO - VERIFICACION Y HARDENING DE ALMACENAMIENTO (MINIO + CLAMAV)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# 1. Check MinIO S3 API Health Endpoint
Write-Host "`n[1/3] Verificando endpoint de salud de MinIO (127.0.0.1:9000)..." -ForegroundColor Yellow
$minioLive = "http://127.0.0.1:9000/minio/health/live"
$minioPass = $false
try {
    $resp = Invoke-WebRequest -Uri $minioLive -Method Get -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if ($resp.StatusCode -eq 200) {
        Write-Host "  -> [OK] MinIO S3 API esta ONLINE y saludable (HTTP 200)." -ForegroundColor Green
        $minioPass = $true
    }
} catch {
    Write-Host "  -> [ALERTA] MinIO no responde en 127.0.0.1:9000 ($($_.Exception.Message))" -ForegroundColor Red
}

# 2. Check ClamAV Daemon Port 3310
Write-Host "`n[2/3] Verificando puerto de demonio ClamAV (127.0.0.1:3310)..." -ForegroundColor Yellow
$clamPass = $false
$clamConn = Test-NetConnection -ComputerName 127.0.0.1 -Port 3310 -WarningAction SilentlyContinue
if ($clamConn.TcpTestSucceeded) {
    Write-Host "  -> [OK] ClamAV antivirus daemon escuchando en puerto 3310." -ForegroundColor Green
    $clamPass = $true
} else {
    Write-Host "  -> [INFO] ClamAV daemon no esta activo o no escucha en puerto 3310 (opcional en DEV sin escaneo local)." -ForegroundColor Gray
}

# 3. MinIO Least-Privilege Policy Validation
if (-not $SkipPolicyTest) {
    Write-Host "`n[3/3] Ejecutando validacion de politicas de menor privilegio (minio-policy-test)..." -ForegroundColor Yellow
    $composeFile = Join-Path $PSScriptRoot "..\..\..\GestioAsistenciaBackend\infra\files\compose.yaml"
    $envFile = Join-Path $PSScriptRoot "..\..\..\GestioAsistenciaBackend\infra\files\.env"
    
    if ((Test-Path $composeFile) -and (Test-Path $envFile)) {
        Push-Location (Join-Path $PSScriptRoot "..\..\..\GestioAsistenciaBackend")
        try {
            docker compose --env-file infra/files/.env -f infra/files/compose.yaml --profile validation run --rm minio-policy-test
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  -> [OK] Validacion de politicas S3 superada exitosamente." -ForegroundColor Green
            } else {
                Write-Error "Fallo en la validacion de politicas MinIO."
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "  -> [SKIP] No se encontro compose.yaml o .env de infra/files." -ForegroundColor Gray
    }
} else {
    Write-Host "`n[3/3] Omitiendo prueba de politicas (-SkipPolicyTest)." -ForegroundColor Gray
}

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor $(if ($minioPass) { 'Green' } else { 'Yellow' })
Write-Host " RESULTADO STORAGE: MinIO=$($minioPass) | ClamAV=$($clamPass)" -ForegroundColor $(if ($minioPass) { 'Green' } else { 'Yellow' })
Write-Host "==============================================================================" -ForegroundColor $(if ($minioPass) { 'Green' } else { 'Yellow' })
