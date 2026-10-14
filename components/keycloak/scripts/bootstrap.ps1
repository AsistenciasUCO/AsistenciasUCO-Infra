<#
.SYNOPSIS
    Bootstrap idempotente del realm Keycloak de AsistenciasUCO (asistencias-uco).

.DESCRIPTION
    Reconcilia, vía Admin REST API, el realm, clients (asistencias-api, asistencias-uco-frontend,
    asistencias-backend-admin), roles institucionales (ADMINISTRADOR, DECANO, COORDINADOR, DOCENTE,
    ESTUDIANTE), scopes de cliente, mappers (idUsuario y audience) y permisos de service accounts.
    Idempotente: su ejecución repetida no duplica objetos ni produce efectos colaterales.

.PARAMETER EnvFile
    Ruta al archivo .env (Default: '../../.env' en AsistenciasUCO-Infra o local).

.EXAMPLE
    .\bootstrap.ps1
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

# 1. Cargar configuración
$envMap = Import-KcDotEnv -Path $EnvFile

$serverUrl          = Get-KcEnvValue -EnvMap $envMap -Key 'KEYCLOAK_SERVER_URL' -Default 'http://127.0.0.1:8081'
$managementPort     = Get-KcEnvValue -EnvMap $envMap -Key 'KEYCLOAK_MANAGEMENT_HOST_PORT' -Default '9001'
$managementUrl      = "http://127.0.0.1:$managementPort"

$bootstrapAdminUser = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_USERNAME'
$bootstrapAdminPass = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_PASSWORD'

$realmName          = Get-KcEnvValue -EnvMap $envMap -Key 'KC_REALM' -Default 'asistencias-uco'
$apiClientId        = Get-KcEnvValue -EnvMap $envMap -Key 'KC_API_CLIENT_ID' -Default 'asistencias-api'
$frontendClientId   = Get-KcEnvValue -EnvMap $envMap -Key 'KC_FRONTEND_CLIENT_ID' -Default 'asistencias-uco-frontend'
$legacyFrontendClientId = 'asistencias-frontend'
$backendAdminClientId = Get-KcEnvValue -EnvMap $envMap -Key 'KC_BACKEND_ADMIN_CLIENT_ID' -Default 'asistencias-backend-admin'
$backendAdminSecret   = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KEYCLOAK_ADMIN_CLIENT_SECRET'

$passwordMinLength = Get-KcEnvValue -EnvMap $envMap -Key 'KC_PASSWORD_MIN_LENGTH' -Default '12'
$removeLegacyRoles = (Get-KcEnvValue -EnvMap $envMap -Key 'KC_REMOVE_LEGACY_ROLES' -Default 'false') -eq 'true'
$removeLegacyFrontendClient = (Get-KcEnvValue -EnvMap $envMap -Key 'KC_REMOVE_LEGACY_FRONTEND_CLIENT' -Default 'false') -eq 'true'

$clientScopeName = 'asistencias-api-scope'
$userIdAttribute = 'idUsuario'

$institutionalRoles = [ordered]@{
    ADMINISTRADOR = 'Administrador institucional. Acceso administrativo completo a AsistenciasUCO.'
    DECANO        = 'Decano de facultad. Gestiona coordinadores, docentes y reportes de su facultad.'
    COORDINADOR   = 'Coordinador de programa. Gestiona docentes, grupos y asistencias de su programa.'
    DOCENTE       = 'Docente. Registra y consulta asistencias de sus grupos asignados.'
    ESTUDIANTE    = 'Estudiante. Consulta su propia asistencia y participa en registro autonomo.'
}

$legacyRoleMap = [ordered]@{
    AD = 'ADMINISTRADOR'
    DE = 'DECANO'
    CD = 'COORDINADOR'
    DO = 'DOCENTE'
    ES = 'ESTUDIANTE'
}

$requiredRealmManagementRoles = @('view-users', 'manage-users', 'view-clients')

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - BOOTSTRAP DE REALM KEYCLOAK ($realmName)" -ForegroundColor Cyan
Write-Host "Servidor: $serverUrl | Gestión: $managementUrl" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

# 2. Verificar disponibilidad de Keycloak
$ready = $false
for ($attempt = 1; $attempt -le 15; $attempt++) {
    if (Test-KcServerReady -ManagementUrl $managementUrl) { $ready = $true; break }
    Start-Sleep -Seconds 3
}
if (-not $ready) {
    Write-KcResult -Status 'ERROR' -Message "Keycloak no respondió 'ready' en $managementUrl/health/ready tras varios intentos. Verifica 'docker compose up -d'."
    exit 1
}
Write-KcResult -Status 'OK' -Message "Keycloak accesible ($serverUrl)"

# 3. Autenticación como admin de bootstrap
$adminToken = Get-KcAdminToken -ServerUrl $serverUrl -Username $bootstrapAdminUser -Password $bootstrapAdminPass
Write-KcResult -Status 'OK' -Message 'Autenticado como admin de bootstrap (realm master)'

# 4. Realm
$realm = Find-KcRealm -ServerUrl $serverUrl -Token $adminToken -RealmName $realmName
if ($null -eq $realm) {
    Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path '/admin/realms' -Token $adminToken -Body @{ realm = $realmName; enabled = $true } | Out-Null
    Write-KcResult -Status 'CREATED' -Message "Realm $realmName"
} else {
    Write-KcResult -Status 'OK' -Message "Realm $realmName"
}

# 5. Política de contraseñas institucional (mínimo 12 caracteres, Argon2)
$desiredPolicy = "length($passwordMinLength) and digits(1) and lowerCase(1) and upperCase(1) and specialChars(1) and notUsername and notEmail and passwordHistory(5) and hashAlgorithm(argon2)"
$realm = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName" -Token $adminToken).Body
if ($realm.passwordPolicy -ne $desiredPolicy) {
    $realm.passwordPolicy = $desiredPolicy
    Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName" -Token $adminToken -Body $realm | Out-Null
    Write-KcResult -Status 'UPDATED' -Message "Password policy (min length $passwordMinLength, argon2, history 5)"
} else {
    Write-KcResult -Status 'OK' -Message 'Password policy'
}

# Helper local: reconciliar estado de un client
function Set-DesiredClientState {
    param(
        [Parameter(Mandatory = $true)][string]$ClientId,
        [Parameter(Mandatory = $true)][hashtable]$Desired
    )

    $existing = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId $ClientId
    if ($null -eq $existing) {
        $payload = $Desired.Clone()
        $payload['clientId'] = $ClientId
        $created = Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients" -Token $adminToken -Body $payload
        $newId = ($created.Location -split '/')[-1]
        Write-KcResult -Status 'CREATED' -Message "Client $ClientId"
        return $newId
    }

    $changed = $false
    foreach ($key in $Desired.Keys) {
        $desiredValue = $Desired[$key]
        $currentValue = $existing.$key
        $isDifferent =
            if ($desiredValue -is [array]) { ((@($currentValue) | Sort-Object) -join '|') -ne ((@($desiredValue) | Sort-Object) -join '|') }
            else { $currentValue -ne $desiredValue }
        if ($isDifferent) {
            $existing | Add-Member -NotePropertyName $key -NotePropertyValue $desiredValue -Force
            $changed = $true
        }
    }

    if ($changed) {
        Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$($existing.id)" -Token $adminToken -Body $existing | Out-Null
        Write-KcResult -Status 'UPDATED' -Message "Client $ClientId"
    } else {
        Write-KcResult -Status 'OK' -Message "Client $ClientId"
    }
    return $existing.id
}

# 6. Client asistencias-api (Resource/API namespace)
$apiClientDesired = @{
    enabled                   = $true
    protocol                  = 'openid-connect'
    publicClient              = $false
    standardFlowEnabled       = $false
    directAccessGrantsEnabled = $false
    implicitFlowEnabled       = $false
    serviceAccountsEnabled    = $false
    description               = 'Resource/API client y namespace de roles institucionales de AsistenciasUCO.'
}
$apiClientUuid = Set-DesiredClientState -ClientId $apiClientId -Desired $apiClientDesired

# 7. Roles institucionales
foreach ($roleName in $institutionalRoles.Keys) {
    $description = $institutionalRoles[$roleName]
    $existingRole = Find-KcClientRole -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientUuid $apiClientUuid -RoleName $roleName
    if ($null -eq $existingRole) {
        Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$apiClientUuid/roles" -Token $adminToken -Body @{ name = $roleName; description = $description } | Out-Null
        Write-KcResult -Status 'CREATED' -Message "Role $roleName"
    } elseif ($existingRole.description -ne $description) {
        Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$apiClientUuid/roles/$roleName" -Token $adminToken -Body @{ name = $roleName; description = $description } | Out-Null
        Write-KcResult -Status 'UPDATED' -Message "Role $roleName (descripcion)"
    } else {
        Write-KcResult -Status 'OK' -Message "Role $roleName"
    }
}

# 8. Migración de roles legacy (AD, DE, CD, DO, ES)
foreach ($legacyCode in $legacyRoleMap.Keys) {
    $longRoleName = $legacyRoleMap[$legacyCode]
    $legacyRole = Find-KcClientRole -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientUuid $apiClientUuid -RoleName $legacyCode
    if ($null -eq $legacyRole) { continue }

    $longRole = Find-KcClientRole -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientUuid $apiClientUuid -RoleName $longRoleName
    $usersWithLegacy = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$apiClientUuid/roles/$legacyCode/users" -Token $adminToken).Body
    $migratedCount = 0

    foreach ($user in @($usersWithLegacy)) {
        if ($null -eq $user) { continue }
        $currentMappings = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$($user.id)/role-mappings/clients/$apiClientUuid" -Token $adminToken).Body
        $alreadyHasLong = @($currentMappings) | Where-Object { $_.name -eq $longRoleName }
        if (-not $alreadyHasLong) {
            Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$($user.id)/role-mappings/clients/$apiClientUuid" -Token $adminToken -Body @($longRole) | Out-Null
            $migratedCount++
        }
        if ($removeLegacyRoles) {
            Invoke-KcAdminApi -Method Delete -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$($user.id)/role-mappings/clients/$apiClientUuid" -Token $adminToken -Body @($legacyRole) | Out-Null
        }
    }

    if ($migratedCount -gt 0) {
        Write-KcResult -Status 'MIGRATED' -Message "$legacyCode -> ${longRoleName}: $migratedCount user(s)"
    } else {
        Write-KcResult -Status 'OK' -Message "$legacyCode -> $longRoleName (sin pendientes)"
    }
    if ($removeLegacyRoles) {
        Invoke-KcAdminApi -Method Delete -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$apiClientUuid/roles/$legacyCode" -Token $adminToken | Out-Null
        Write-KcResult -Status 'UPDATED' -Message "Role legacy $legacyCode eliminado"
    }
}

# 9. Client frontend canónico (asistencias-uco-frontend)
$canonicalFrontend = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId $frontendClientId
$legacyFrontend = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId $legacyFrontendClientId

if ($null -eq $canonicalFrontend -and $null -ne $legacyFrontend) {
    $legacyFrontend | Add-Member -NotePropertyName clientId -NotePropertyValue $frontendClientId -Force
    Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$($legacyFrontend.id)" -Token $adminToken -Body $legacyFrontend | Out-Null
    Write-KcResult -Status 'MIGRATED' -Message "Client legacy $legacyFrontendClientId renombrado a $frontendClientId"
}

$frontendDesired = @{
    enabled                   = $true
    protocol                  = 'openid-connect'
    publicClient              = $true
    standardFlowEnabled       = $true
    directAccessGrantsEnabled = $true
    implicitFlowEnabled       = $false
    serviceAccountsEnabled    = $false
    rootUrl                   = 'http://localhost:4200'
    baseUrl                   = 'http://localhost:4200'
    redirectUris              = @('http://localhost:4200/*', 'http://127.0.0.1:4200/*')
    webOrigins                = @('http://localhost:4200', 'http://127.0.0.1:4200')
    description               = 'SPA Angular de AsistenciasUCO.'
}
$frontendClientUuid = Set-DesiredClientState -ClientId $frontendClientId -Desired $frontendDesired

# 10. Client Scope asistencias-api-scope + Mappers (idUsuario, audience)
$clientScope = Find-KcClientScopeByName -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -Name $clientScopeName
if ($null -eq $clientScope) {
    $created = Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/client-scopes" -Token $adminToken -Body @{
        name       = $clientScopeName
        protocol   = 'openid-connect'
        attributes = @{ 'include.in.token.scope' = 'true'; 'display.on.consent.screen' = 'false' }
    }
    $clientScopeUuid = ($created.Location -split '/')[-1]
    Write-KcResult -Status 'CREATED' -Message "Client scope $clientScopeName"
} else {
    $clientScopeUuid = $clientScope.id
    Write-KcResult -Status 'OK' -Message "Client scope $clientScopeName"
}

# Limpiar restricciones heredadas en scope-mappings
$scopeMappings = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/client-scopes/$clientScopeUuid/scope-mappings" -Token $adminToken).Body
if ($scopeMappings.PSObject.Properties['realmMappings'] -and $scopeMappings.realmMappings) {
    Invoke-KcAdminApi -Method Delete -ServerUrl $serverUrl -Path "/admin/realms/$realmName/client-scopes/$clientScopeUuid/scope-mappings/realm" -Token $adminToken -Body @($scopeMappings.realmMappings) | Out-Null
}

function Set-DesiredMapper {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ProtocolMapper,
        [Parameter(Mandatory = $true)][hashtable]$Config
    )

    $existingMappers = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/client-scopes/$clientScopeUuid/protocol-mappers/models" -Token $adminToken).Body
    $existing = @(@($existingMappers) | Where-Object { $_.name -eq $Name })

    $desiredBody = @{
        name           = $Name
        protocol       = 'openid-connect'
        protocolMapper = $ProtocolMapper
        config         = $Config
    }

    if ($existing.Count -eq 0) {
        Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/client-scopes/$clientScopeUuid/protocol-mappers/models" -Token $adminToken -Body $desiredBody | Out-Null
        Write-KcResult -Status 'CREATED' -Message "Mapper $Name"
        return
    }

    $current = $existing[0]
    $needsUpdate = $current.protocol -ne 'openid-connect' -or $current.protocolMapper -ne $ProtocolMapper
    foreach ($key in $Config.Keys) {
        $prop = $current.config.PSObject.Properties[$key]
        if ($null -eq $prop -or [string]$prop.Value -ne [string]$Config[$key]) { $needsUpdate = $true }
    }
    if ($needsUpdate) {
        $desiredBody['id'] = $current.id
        Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/client-scopes/$clientScopeUuid/protocol-mappers/models/$($current.id)" -Token $adminToken -Body $desiredBody | Out-Null
        Write-KcResult -Status 'UPDATED' -Message "Mapper $Name"
    } else {
        Write-KcResult -Status 'OK' -Message "Mapper $Name"
    }
}

Set-DesiredMapper -Name $userIdAttribute -ProtocolMapper 'oidc-usermodel-attribute-mapper' -Config @{
    'user.attribute'           = $userIdAttribute
    'claim.name'               = $userIdAttribute
    'jsonType.label'           = 'String'
    'id.token.claim'           = 'true'
    'access.token.claim'       = 'true'
    'userinfo.token.claim'     = 'true'
    'introspection.token.claim'= 'true'
    'multivalued'              = 'false'
}

Set-DesiredMapper -Name "audience-$apiClientId" -ProtocolMapper 'oidc-audience-mapper' -Config @{
    'included.client.audience' = $apiClientId
    'id.token.claim'           = 'false'
    'access.token.claim'       = 'true'
    'introspection.token.claim'= 'true'
    'userinfo.token.claim'     = 'false'
}

# Asignar el scope como DEFAULT en frontend
Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$frontendClientUuid/default-client-scopes/$clientScopeUuid" -Token $adminToken | Out-Null
Write-KcResult -Status 'OK' -Message "Scope $clientScopeName asignado como default a $frontendClientId"

# 11. Client asistencias-backend-admin (service account confidencial)
$backendAdminDesired = @{
    enabled                    = $true
    protocol                   = 'openid-connect'
    publicClient               = $false
    clientAuthenticatorType    = 'client-secret'
    standardFlowEnabled        = $false
    directAccessGrantsEnabled  = $false
    implicitFlowEnabled        = $false
    serviceAccountsEnabled     = $true
    description                = 'Service account confidencial para Backend Admin REST API.'
}
$backendAdminUuid = Set-DesiredClientState -ClientId $backendAdminClientId -Desired $backendAdminDesired

$currentSecret = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$backendAdminUuid/client-secret" -Token $adminToken -AllowNotFound).Body
if ($null -eq $currentSecret -or $currentSecret.value -ne $backendAdminSecret) {
    $backendAdminRep = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$backendAdminUuid" -Token $adminToken).Body
    $backendAdminRep | Add-Member -NotePropertyName secret -NotePropertyValue $backendAdminSecret -Force
    Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$backendAdminUuid" -Token $adminToken -Body $backendAdminRep | Out-Null
    Write-KcResult -Status 'UPDATED' -Message "Client ${backendAdminClientId}: secret sincronizado"
} else {
    Write-KcResult -Status 'OK' -Message "Client ${backendAdminClientId}: secret"
}

# 12. Permisos mínimos del service account (realm-management)
$serviceAccountUser = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/clients/$backendAdminUuid/service-account-user" -Token $adminToken).Body
$realmManagementClient = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId 'realm-management'
$currentServiceAccountRoles = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$($serviceAccountUser.id)/role-mappings/clients/$($realmManagementClient.id)" -Token $adminToken).Body
$currentRoleNames = @($currentServiceAccountRoles) | ForEach-Object { $_.name }

$rolesToAssign = @()
foreach ($roleName in $requiredRealmManagementRoles) {
    if ($currentRoleNames -contains $roleName) { continue }
    $role = Find-KcClientRole -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientUuid $realmManagementClient.id -RoleName $roleName
    if ($role) { $rolesToAssign += $role }
}

if ($rolesToAssign.Count -gt 0) {
    Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$($serviceAccountUser.id)/role-mappings/clients/$($realmManagementClient.id)" -Token $adminToken -Body $rolesToAssign | Out-Null
    Write-KcResult -Status 'UPDATED' -Message "Backend service account: roles asignados"
} else {
    Write-KcResult -Status 'OK' -Message 'Minimum realm-management roles'
}

# 13. User Profile: idUsuario
$userProfile = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/profile" -Token $adminToken).Body
$attributes = @($userProfile.attributes)
$uuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$desiredProfileAttribute = [pscustomobject]@{
    name        = $userIdAttribute
    displayName = 'ID Usuario'
    validations = [pscustomobject]@{ pattern = [pscustomobject]@{ pattern = $uuidPattern; 'error-message' = 'El idUsuario debe tener formato UUID.' } }
    annotations = [pscustomobject]@{}
    permissions = [pscustomobject]@{ view = @('user', 'admin'); edit = @('admin') }
    multivalued = $false
}

$reconciledAttributes = New-Object System.Collections.Generic.List[object]
$inserted = $false
foreach ($attr in $attributes) {
    if ($attr.name -eq $userIdAttribute) {
        $reconciledAttributes.Add($desiredProfileAttribute) | Out-Null
        $inserted = $true
        continue
    }
    $reconciledAttributes.Add($attr) | Out-Null
}
if (-not $inserted) { $reconciledAttributes.Add($desiredProfileAttribute) | Out-Null }
$userProfile.attributes = @($reconciledAttributes)
Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/profile" -Token $adminToken -Body $userProfile | Out-Null
Write-KcResult -Status 'OK' -Message "User Profile: $userIdAttribute reconciliado"

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "✅ Bootstrap de Keycloak completado exitosamente para realm $realmName" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green

