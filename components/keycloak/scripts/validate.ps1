<#
.SYNOPSIS
    Validador de contrato del realm Keycloak de AsistenciasUCO (solo lectura).

.DESCRIPTION
    Inspección exhaustiva de solo lectura para certificar que el realm cumpla el contrato canónico:
    realm activo, clientes (asistencias-api, asistencias-uco-frontend, asistencias-backend-admin),
    5 roles institucionales (ADMINISTRADOR, DECANO, COORDINADOR, DOCENTE, ESTUDIANTE),
    client scope asistencias-api-scope con mappers (idUsuario y audience), y permisos
    del service account. Termina con exit code != 0 si falta alguna pieza del contrato.

.PARAMETER EnvFile
    Ruta al archivo .env.

.EXAMPLE
    .\validate.ps1
#>

[CmdletBinding()]
param(
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
$apiClientId      = Get-KcEnvValue -EnvMap $envMap -Key 'KC_API_CLIENT_ID' -Default 'asistencias-api'
$frontendClientId = Get-KcEnvValue -EnvMap $envMap -Key 'KC_FRONTEND_CLIENT_ID' -Default 'asistencias-uco-frontend'
$backendAdminClientId = Get-KcEnvValue -EnvMap $envMap -Key 'KC_BACKEND_ADMIN_CLIENT_ID' -Default 'asistencias-backend-admin'
$clientScopeName  = 'asistencias-api-scope'
$userIdAttribute  = 'idUsuario'

$bootstrapAdminUser = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_USERNAME'
$bootstrapAdminPass = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_PASSWORD'

$institutionalRoleNames = @('ADMINISTRADOR', 'DECANO', 'COORDINADOR', 'DOCENTE', 'ESTUDIANTE')
$requiredRealmManagementRoles = @('view-users', 'manage-users', 'view-clients')

$failures = New-Object System.Collections.Generic.List[string]

function Test-Check {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$OkMessage,
        [Parameter(Mandatory = $true)][string]$FailMessage
    )
    if ($Condition) {
        Write-KcResult -Status 'OK' -Message $OkMessage
    } else {
        Write-KcResult -Status 'ERROR' -Message $FailMessage
        $script:failures.Add($FailMessage) | Out-Null
    }
}

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - VALIDACIÓN DE CONTRATO KEYCLOAK ($realmName)" -ForegroundColor Cyan
Write-Host "Servidor: $serverUrl" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# 1. Autenticación
$adminToken = Get-KcAdminToken -ServerUrl $serverUrl -Username $bootstrapAdminUser -Password $bootstrapAdminPass

# 2. Realm
$realm = Find-KcRealm -ServerUrl $serverUrl -Token $adminToken -RealmName $realmName
Test-Check -Condition ($null -ne $realm -and $realm.enabled) -OkMessage "Realm $realmName activo" -FailMessage "El realm $realmName no existe o está deshabilitado."

# 3. Client asistencias-api
$apiClient = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId $apiClientId
Test-Check -Condition ($null -ne $apiClient -and $apiClient.enabled) -OkMessage "Client $apiClientId activo" -FailMessage "El client $apiClientId no existe o está deshabilitado."

# 4. Roles institucionales
if ($null -ne $apiClient) {
    $existingRoles = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$($apiClient.id)/roles" -Token $adminToken).Body
    $existingRoleNames = @($existingRoles | ForEach-Object { $_.name })
    foreach ($r in $institutionalRoleNames) {
        Test-Check -Condition ($existingRoleNames -contains $r) -OkMessage "Rol $r presente" -FailMessage "Falta el rol institucional $r en $apiClientId."
    }
}

# 5. Client frontend
$frontendClient = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId $frontendClientId
Test-Check -Condition ($null -ne $frontendClient -and $frontendClient.enabled) -OkMessage "Client $frontendClientId activo" -FailMessage "El client $frontendClientId no existe."

# 6. Client scope y mappers
$clientScope = Find-KcClientScopeByName -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -Name $clientScopeName
Test-Check -Condition ($null -ne $clientScope) -OkMessage "Client scope $clientScopeName presente" -FailMessage "El client scope $clientScopeName no existe."

if ($null -ne $clientScope) {
    $mappers = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/client-scopes/$($clientScope.id)/protocol-mappers/models" -Token $adminToken).Body
    $idMapper = @($mappers | Where-Object { $_.name -eq $userIdAttribute })
    $audMapper = @($mappers | Where-Object { $_.name -eq "audience-$apiClientId" })

    Test-Check -Condition ($idMapper.Count -eq 1) -OkMessage "Mapper $userIdAttribute configurado" -FailMessage "Falta el mapper $userIdAttribute en $clientScopeName."
    Test-Check -Condition ($audMapper.Count -eq 1) -OkMessage "Mapper audience-$apiClientId configurado" -FailMessage "Falta el mapper audience-$apiClientId en $clientScopeName."
}

# 7. Service account asistencias-backend-admin
$backendAdminClient = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId $backendAdminClientId
Test-Check -Condition ($null -ne $backendAdminClient -and $backendAdminClient.serviceAccountsEnabled) -OkMessage "Client $backendAdminClientId activo con serviceAccountsEnabled" -FailMessage "El client $backendAdminClientId no está habilitado como service account."

if ($null -ne $backendAdminClient) {
    $serviceAccountUser = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$($backendAdminClient.id)/service-account-user" -Token $adminToken).Body
    $realmManagementClient = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId 'realm-management'
    if ($null -ne $realmManagementClient -and $null -ne $serviceAccountUser) {
        $saRoles = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$($serviceAccountUser.id)/role-mappings/clients/$($realmManagementClient.id)" -Token $adminToken).Body
        $saRoleNames = @($saRoles | ForEach-Object { $_.name })
        foreach ($sr in $requiredRealmManagementRoles) {
            Test-Check -Condition ($saRoleNames -contains $sr) -OkMessage "Service account tiene rol $sr" -FailMessage "Al service account le falta el rol $sr de realm-management."
        }
    }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host "✅ CONTRATO DE KEYCLOAK VALIDADO CON ÉXITO (0 Fallos)" -ForegroundColor Green
    Write-Host "==============================================================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host "❌ FALLOS EN EL CONTRATO DE KEYCLOAK ($($failures.Count) detectados):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "==============================================================================" -ForegroundColor Red
    exit 1
}


