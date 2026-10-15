<#
.SYNOPSIS
    Diagnóstico profundo de claims institucionales (idUsuario y roles) en tokens de Keycloak.

.DESCRIPTION
    Inspecciona y compara para los usuarios institucionales (Docente y Admin):
      1. Atributo idUsuario visible vía Admin REST API.
      2. Claim idUsuario emitido en el Access Token JWT.
      3. Claim idUsuario retornado por el endpoint /userinfo.
      4. Roles institucionales asignados bajo el namespace de asistencias-api.
    No realiza modificaciones en el servidor ni expone secretos en la salida.

.PARAMETER EnvFile
    Ruta al archivo .env.

.EXAMPLE
    .\diagnose-token.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $candidates = @(
        (Join-Path $PSScriptRoot '..\..\..\.env'),
        (Join-Path $PSScriptRoot '..\..\.env'),
        (Join-Path $PSScriptRoot '..\.env')
    )
    foreach ($cand in $candidates) {
        if (Test-Path -LiteralPath $cand) {
            $EnvFile = (Resolve-Path $cand).Path
            break
        }
    }
}

Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'KeycloakAdmin.psm1') -Force

function ConvertFrom-Base64UrlSafe {
    param([Parameter(Mandatory = $true)][string]$Value)
    $padded = $Value.Replace('-', '+').Replace('_', '/')
    switch ($padded.Length % 4) {
        2 { $padded += '==' }
        3 { $padded += '=' }
    }
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($padded))
}

$envMap = Import-KcDotEnv -Path $EnvFile

$serverUrl        = Get-KcEnvValue -EnvMap $envMap -Key 'KEYCLOAK_SERVER_URL' -Default 'http://127.0.0.1:8081'
$realmName        = Get-KcEnvValue -EnvMap $envMap -Key 'KC_REALM' -Default 'asistencias-uco'
$frontendClientId = Get-KcEnvValue -EnvMap $envMap -Key 'KC_FRONTEND_CLIENT_ID' -Default 'asistencias-uco-frontend'
$apiClientId      = Get-KcEnvValue -EnvMap $envMap -Key 'KC_API_CLIENT_ID' -Default 'asistencias-api'

$bootstrapAdminUser = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_USERNAME'
$bootstrapAdminPass = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_PASSWORD'

$adminToken = Get-KcAdminToken -ServerUrl $serverUrl -Username $bootstrapAdminUser -Password $bootstrapAdminPass

$diagnostics = @(
    @{ Role = 'DOCENTE'; Username = 'docente.prueba'; DefaultPass = 'Docente123456!' },
    @{ Role = 'ADMIN';   Username = 'admin.prueba';   DefaultPass = 'Admin1234567!' }
)

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - DIAGNÓSTICO DE CLAIMS (idUsuario & Roles) EN KEYCLOAK" -ForegroundColor Cyan
Write-Host "Realm: $realmName | Servidor: $serverUrl" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

foreach ($diag in $diagnostics) {
    $username = $diag.Username
    $roleExpected = $diag.Role
    $password = $diag.DefaultPass

    Write-Host "`n--> Analizando usuario: $username ($roleExpected)" -ForegroundColor Yellow

    $userObj = Find-KcUserByUsername -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -Username $username
    if ($null -eq $userObj) {
        Write-KcResult -Status 'WARN' -Message "El usuario $username no existe en el realm. Ejecuta .\seed-users.ps1"
        continue
    }

    $adminIdAttr = if ($userObj.attributes -and $userObj.attributes.PSObject.Properties['idUsuario']) {
        $userObj.attributes.idUsuario[0]
    } else { 'NO_CONFIGURADO' }
    Write-Host "  1. Atributo en Admin REST   : $adminIdAttr" -ForegroundColor Gray

    # Solicitar token
    $tokenEndpoint = "$serverUrl/realms/$realmName/protocol/openid-connect/token"
    $bodyPairs = @(
        "grant_type=password",
        "client_id=$(ConvertTo-KcUrlEncoded $frontendClientId)",
        "username=$(ConvertTo-KcUrlEncoded $username)",
        "password=$(ConvertTo-KcUrlEncoded $password)",
        "scope=$(ConvertTo-KcUrlEncoded 'openid')"
    )
    $body = [string]::Join('&', $bodyPairs)

    try {
        $tokenResp = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body $body
        $rawToken = $tokenResp.access_token

        # Decodificar claims del token
        $payloadJson = ConvertFrom-Base64UrlSafe ($rawToken.Split('.')[1])
        $tokenClaims = $payloadJson | ConvertFrom-Json

        $tokenIdAttr = if ($tokenClaims.PSObject.Properties['idUsuario']) { $tokenClaims.idUsuario } else { 'MISSING_CLAIM' }
        Write-Host "  2. Claim en Access Token    : $tokenIdAttr" -ForegroundColor $(if ($tokenIdAttr -ne 'MISSING_CLAIM') { 'Green' } else { 'Red' })

        # Consultar endpoint /userinfo
        $userInfoEndpoint = "$serverUrl/realms/$realmName/protocol/openid-connect/userinfo"
        $userInfoResp = Invoke-RestMethod -Method Get -Uri $userInfoEndpoint -Headers @{ Authorization = "Bearer $rawToken" }
        $userInfoId = if ($userInfoResp.PSObject.Properties['idUsuario']) { $userInfoResp.idUsuario } else { 'MISSING_CLAIM' }
        Write-Host "  3. Claim en /userinfo       : $userInfoId" -ForegroundColor $(if ($userInfoId -ne 'MISSING_CLAIM') { 'Green' } else { 'Red' })

        # Roles
        $roles = if ($tokenClaims.resource_access -and $tokenClaims.resource_access.$apiClientId) {
            @($tokenClaims.resource_access.$apiClientId.roles)
        } else { @() }
        Write-Host "  4. Roles en Token ($apiClientId): $(@($roles) -join ', ')" -ForegroundColor Green

        if ($tokenIdAttr -eq $adminIdAttr -and $tokenIdAttr -ne 'MISSING_CLAIM') {
            Write-KcResult -Status 'OK' -Message "Mapeo de idUsuario consistente y verificado para $username"
        } else {
            Write-KcResult -Status 'ERROR' -Message "Discrepancia en claim idUsuario para $username"
        }

    } catch {
        Write-KcResult -Status 'ERROR' -Message "No fue posible autenticar con $username. Detalle: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Diagnóstico completado." -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

