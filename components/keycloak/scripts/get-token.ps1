<#
.SYNOPSIS
    Emite un token JWT Bearer de prueba desde Keycloak y decodifica sus claims.

.DESCRIPTION
    Obtiene un token de acceso mediante Password Grant utilizando el client asistencias-uco-frontend.
    Decodifica de forma segura y muestra en consola los claims institucionales esenciales:
    issuer, audience (asistencias-api), idUsuario, roles institucionales y expiración.
    El access token crudo solo se imprime si se pasa el flag -ShowToken.

.PARAMETER Username
    Nombre de usuario a autenticar (ej. docente.prueba, admin.prueba).

.PARAMETER Password
    Contraseña en texto claro (si se omite, se busca en .env o se solicita interactivamente).

.PARAMETER ShowToken
    Switch para imprimir el access token completo para copiar y pegar en Postman/cURL/Swagger.

.PARAMETER EnvFile
    Ruta al archivo .env.

.EXAMPLE
    .\get-token.ps1 -Username docente.prueba -ShowToken
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Username,
    [string]$Password,
    [switch]$ShowToken,
    [string]$EnvFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $parentEnv = Join-Path (Join-Path (Join-Path $PSScriptRoot '..') '..') '.env'
    $localEnv = Join-Path (Join-Path $PSScriptRoot '..') '.env'
    $EnvFile = if (Test-Path $parentEnv) { $parentEnv } elseif (Test-Path $localEnv) { $localEnv } else { $parentEnv }
}

Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'KeycloakAdmin.psm1') -Force

$envMap = Import-KcDotEnv -Path $EnvFile

$serverUrl        = Get-KcEnvValue -EnvMap $envMap -Key 'KEYCLOAK_SERVER_URL' -Default 'http://127.0.0.1:8081'
$realmName        = Get-KcEnvValue -EnvMap $envMap -Key 'KC_REALM' -Default 'asistencias-uco'
$frontendClientId = Get-KcEnvValue -EnvMap $envMap -Key 'KC_FRONTEND_CLIENT_ID' -Default 'asistencias-uco-frontend'
$apiClientId      = Get-KcEnvValue -EnvMap $envMap -Key 'KC_API_CLIENT_ID' -Default 'asistencias-api'

if ([string]::IsNullOrWhiteSpace($Password)) {
    foreach ($prefix in @('E2E_DOCENTE_', 'E2E_ADMIN_')) {
        if ((Get-KcEnvValue -EnvMap $envMap -Key "${prefix}USERNAME") -eq $Username) {
            $Password = Get-KcEnvValue -EnvMap $envMap -Key "${prefix}PASSWORD"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Password)) {
    if ($Username -eq 'docente.prueba' -and $env:TEST_DOCENTE_PASSWORD) { $Password = $env:TEST_DOCENTE_PASSWORD }
    elseif ($Username -eq 'admin.prueba' -and $env:TEST_ADMIN_PASSWORD) { $Password = $env:TEST_ADMIN_PASSWORD }
    else {
        $securePass = Read-Host -Prompt "Introduce la contraseña para $Username" -AsSecureString
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
        try {
            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        } finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

# Solicitar token
$tokenEndpoint = "$serverUrl/realms/$realmName/protocol/openid-connect/token"
$bodyPairs = @(
    "grant_type=password",
    "client_id=$(ConvertTo-KcUrlEncoded $frontendClientId)",
    "username=$(ConvertTo-KcUrlEncoded $Username)",
    "password=$(ConvertTo-KcUrlEncoded $Password)",
    "scope=$(ConvertTo-KcUrlEncoded 'openid')"
)
$body = [string]::Join('&', $bodyPairs)

try {
    $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body $body
} catch {
    Write-Host "Error al solicitar token: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
    exit 1
}

$accessToken = $response.access_token

# Decodificar payload JWT
function Decode-JwtPayload {
    param([string]$Jwt)
    $parts = $Jwt.Split('.')
    if ($parts.Length -lt 2) { return $null }
    $base64 = $parts[1].Replace('-', '+').Replace('_', '/')
    switch ($base64.Length % 4) {
        2 { $base64 += '==' }
        3 { $base64 += '=' }
    }
    $bytes = [System.Convert]::FromBase64String($base64)
    $json = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $json | ConvertFrom-Json
}

$claims = Decode-JwtPayload -Jwt $accessToken

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - TOKEN JWT BEARER EMITIDO ($Username)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Issuer (iss)     : $($claims.iss)" -ForegroundColor Gray
Write-Host "Subject (sub)    : $($claims.sub)" -ForegroundColor Gray
Write-Host "Usuario          : $($claims.preferred_username)" -ForegroundColor Gray
Write-Host "Email            : $($claims.email)" -ForegroundColor Gray
Write-Host "Audience (aud)   : $(@($claims.aud) -join ', ')" -ForegroundColor Gray
Write-Host "idUsuario Claim  : $($claims.idUsuario)" -ForegroundColor Yellow

$apiRoles = if ($claims.resource_access -and $claims.resource_access.$apiClientId) {
    @($claims.resource_access.$apiClientId.roles)
} else { @() }

Write-Host "Roles en API     : $(@($apiRoles) -join ', ')" -ForegroundColor Green

if ($claims.exp) {
    $expDate = [DateTimeOffset]::FromUnixTimeSeconds([long]$claims.exp).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
    Write-Host "Expiración (exp) : $expDate" -ForegroundColor Gray
}

if ($ShowToken) {
    Write-Host ''
    Write-Host "--- ACCESS TOKEN (BEARER) ---" -ForegroundColor Cyan
    Write-Host $accessToken -ForegroundColor White
    Write-Host "-----------------------------" -ForegroundColor Cyan
}

Write-Host ''

