# Desactiva el auto-registro (registrationAllowed) del realm security-baseline del laboratorio.
# Idempotente: si ya esta en false no escribe. Usa el Admin REST de Keycloak con las credenciales de
# %USERPROFILE%\.asistencias-security-lab\lab.env (nunca se imprimen). Solo hosts locales.
# Las cuentas se crean unicamente por el flujo de la app (QR / registro por docente) y el aprovisionamiento.
param(
    [string]$Realm = 'security-baseline',
    [string]$LabEnv = (Join-Path $env:USERPROFILE '.asistencias-security-lab\lab.env')
)
$ErrorActionPreference = 'Stop'
$v = @{}
foreach ($l in Get-Content $LabEnv) { if ($l -match '^\s*([A-Za-z0-9_]+)=(.*)$') { $v[$Matches[1]] = $Matches[2].Trim('"') } }
foreach ($k in 'SECURITY_KC_ADMIN_USERNAME', 'SECURITY_KC_ADMIN_PASSWORD') { if (-not $v[$k]) { throw "lab.env no define $k" } }
$puerto = $(if ($v['KEYCLOAK_PORT']) { $v['KEYCLOAK_PORT'] } else { '19090' })
$base = "http://127.0.0.1:$puerto"
$tokenResp = Invoke-RestMethod -Method Post -Uri "$base/realms/master/protocol/openid-connect/token" `
    -ContentType 'application/x-www-form-urlencoded' -Headers @{ Host = "keycloak.localhost:$puerto" } `
    -Body @{ grant_type = 'password'; client_id = 'admin-cli'; username = $v['SECURITY_KC_ADMIN_USERNAME']; password = $v['SECURITY_KC_ADMIN_PASSWORD'] }
$h = @{ Authorization = "Bearer $($tokenResp.access_token)"; Host = "keycloak.localhost:$puerto" }
$realmRep = Invoke-RestMethod -Uri "$base/admin/realms/$Realm" -Headers $h
if ($realmRep.registrationAllowed -eq $false) { Write-Host "    ok  registrationAllowed ya es false en '$Realm'" -ForegroundColor Green; return }
Invoke-RestMethod -Method Put -Uri "$base/admin/realms/$Realm" -Headers $h -ContentType 'application/json' -Body '{"registrationAllowed":false}' | Out-Null
$ahora = (Invoke-RestMethod -Uri "$base/admin/realms/$Realm" -Headers $h).registrationAllowed
Write-Host "    ok  registrationAllowed=$ahora en '$Realm' (auto-registro desactivado)" -ForegroundColor Green
