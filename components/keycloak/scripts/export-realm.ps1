<#
.SYNOPSIS
    Exporta la configuración viva del realm Keycloak a un archivo JSON local.

.DESCRIPTION
    Utiliza el endpoint partial-export de la Admin REST API (realm, clients, roles y scopes,
    SIN usuarios ni secretos). El resultado se guarda en generated/ para inspección o auditoría.

.PARAMETER EnvFile
    Ruta al archivo .env.

.PARAMETER OutputDirectory
    Directorio de salida (Default: 'generated/').

.EXAMPLE
    .\export-realm.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvFile,
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $parentEnv = Join-Path (Join-Path (Join-Path $PSScriptRoot '..') '..') '.env'
    $localEnv = Join-Path (Join-Path $PSScriptRoot '..') '.env'
    $EnvFile = if (Test-Path $parentEnv) { $parentEnv } elseif (Test-Path $localEnv) { $localEnv } else { $parentEnv }
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Join-Path $PSScriptRoot '..') 'generated'
}

Import-Module (Join-Path (Join-Path $PSScriptRoot 'lib') 'KeycloakAdmin.psm1') -Force

$envMap = Import-KcDotEnv -Path $EnvFile

$serverUrl = Get-KcEnvValue -EnvMap $envMap -Key 'KEYCLOAK_SERVER_URL' -Default 'http://127.0.0.1:8081'
$realmName = Get-KcEnvValue -EnvMap $envMap -Key 'KC_REALM' -Default 'asistencias-uco'

$bootstrapAdminUser = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_USERNAME'
$bootstrapAdminPass = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_PASSWORD'

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$adminToken = Get-KcAdminToken -ServerUrl $serverUrl -Username $bootstrapAdminUser -Password $bootstrapAdminPass

$exportPath = "/admin/realms/$realmName/partial-export?exportClients=true&exportGroupsAndRoles=true"
$result = Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path $exportPath -Token $adminToken

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputFile = Join-Path $OutputDirectory "$realmName-$timestamp.json"
$result.Body | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $outputFile -Encoding utf8

Write-KcResult -Status 'OK' -Message "Export guardado en $outputFile"
Write-Host 'Nota: Este export no incluye credenciales de usuarios ni secretos sensibles.' -ForegroundColor Yellow

