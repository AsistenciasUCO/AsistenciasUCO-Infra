<#
.SYNOPSIS
    Siembra y verificación de usuarios institucionales en Keycloak.

.DESCRIPTION
    Registra de forma idempotente los usuarios para pruebas (Docente, Admin, etc.) con sus
    atributos institucionales (idUsuario vinculado a dbo.Usuario.id de SQL Server) y
    asigna los roles de asistencias-api correspondientes sin romper usuarios existentes.

.PARAMETER EnvFile
    Ruta al archivo .env.

.EXAMPLE
    .\seed-users.ps1
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

$envMap = Import-KcDotEnv -Path $EnvFile

$serverUrl   = Get-KcEnvValue -EnvMap $envMap -Key 'KEYCLOAK_SERVER_URL' -Default 'http://127.0.0.1:8081'
$realmName   = Get-KcEnvValue -EnvMap $envMap -Key 'KC_REALM' -Default 'asistencias-uco'
$apiClientId = Get-KcEnvValue -EnvMap $envMap -Key 'KC_API_CLIENT_ID' -Default 'asistencias-api'
$passwordMinLength = [int](Get-KcEnvValue -EnvMap $envMap -Key 'KC_PASSWORD_MIN_LENGTH' -Default '12')

$bootstrapAdminUser = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_USERNAME'
$bootstrapAdminPass = Get-KcRequiredEnvValue -EnvMap $envMap -Key 'KC_BOOTSTRAP_ADMIN_PASSWORD'

$resetExistingPasswords = (Get-KcEnvValue -EnvMap $envMap -Key 'KC_RESET_EXISTING_E2E_PASSWORDS' -Default 'false') -eq 'true'
$userIdAttribute = 'idUsuario'

$adminToken = Get-KcAdminToken -ServerUrl $serverUrl -Username $bootstrapAdminUser -Password $bootstrapAdminPass
$apiClient = Find-KcClientByClientId -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientId $apiClientId
if ($null -eq $apiClient) {
    throw "Client $apiClientId no existe. Ejecuta .\bootstrap.ps1 primero."
}

# Especificación de usuarios institucionales de prueba
$userSpecs = @(
    @{
        Key        = 'DOCENTE'
        Username   = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_DOCENTE_USERNAME' -Default 'docente.prueba')
        Password   = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_DOCENTE_PASSWORD' -Default 'Docente123456!')
        IdUsuario  = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_DOCENTE_ID_USUARIO' -Default 'f1a2b3c4-0000-0000-0000-000000000003')
        Email      = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_DOCENTE_EMAIL' -Default 'docente.prueba@uco.edu.co')
        FirstName  = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_DOCENTE_FIRST_NAME' -Default 'Docente')
        LastName   = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_DOCENTE_LAST_NAME' -Default 'Prueba')
        Role       = 'DOCENTE'
    },
    @{
        Key        = 'ADMIN'
        Username   = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_ADMIN_USERNAME' -Default 'admin.prueba')
        Password   = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_ADMIN_PASSWORD' -Default 'Admin1234567!')
        IdUsuario  = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_ADMIN_ID_USUARIO' -Default 'E1F2A3B4-0000-0000-0000-000000000000')
        Email      = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_ADMIN_EMAIL' -Default 'admin.prueba@uco.edu.co')
        FirstName  = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_ADMIN_FIRST_NAME' -Default 'Admin')
        LastName   = (Get-KcEnvValue -EnvMap $envMap -Key 'E2E_ADMIN_LAST_NAME' -Default 'Prueba')
        Role       = 'ADMINISTRADOR'
    }
)

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "🏛️ ASISTENCIAS UCO - SIEMBRA DE USUARIOS INSTITUCIONALES EN KEYCLOAK" -ForegroundColor Cyan
Write-Host "Realm: $realmName | Servidor: $serverUrl" -ForegroundColor Gray
Write-Host "==============================================================================" -ForegroundColor Cyan

foreach ($spec in $userSpecs) {
    $username = $spec.Username
    $roleName = $spec.Role
    $idUsuario = $spec.IdUsuario

    $existingUser = Find-KcUserByUsername -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -Username $username

    if ($null -eq $existingUser) {
        # Crear usuario
        $createUserPayload = @{
            username      = $username
            email         = $spec.Email
            firstName     = $spec.FirstName
            lastName      = $spec.LastName
            enabled       = $true
            emailVerified = $true
            attributes    = @{
                $userIdAttribute = @($idUsuario)
            }
        }
        $created = Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users" -Token $adminToken -Body $createUserPayload
        $userId = ($created.Location -split '/')[-1]
        Write-KcResult -Status 'CREATED' -Message "Usuario $username (UUID Keycloak: $userId, idUsuario: $idUsuario)"

        # Establecer credencial
        $credPayload = @{
            type      = 'password'
            value     = $spec.Password
            temporary = $false
        }
        Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$userId/reset-password" -Token $adminToken -Body $credPayload | Out-Null
        Write-KcResult -Status 'OK' -Message "Password configurada para $username"
    } else {
        $userId = $existingUser.id
        Write-KcResult -Status 'OK' -Message "Usuario $username ya existe"

        # Reconciliar idUsuario
        $currentAttrs = $existingUser.attributes
        $currentId = if ($currentAttrs -and $currentAttrs.PSObject.Properties[$userIdAttribute]) { $currentAttrs.$userIdAttribute[0] } else { $null }
        if ($currentId -ne $idUsuario) {
            $existingUser | Add-Member -NotePropertyName attributes -NotePropertyValue @{ $userIdAttribute = @($idUsuario) } -Force
            Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$userId" -Token $adminToken -Body $existingUser | Out-Null
            Write-KcResult -Status 'UPDATED' -Message "idUsuario actualizado a $idUsuario para $username"
        }

        # Resetear password si flag activo
        if ($resetExistingPasswords) {
            $credPayload = @{ type = 'password'; value = $spec.Password; temporary = $false }
            Invoke-KcAdminApi -Method Put -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$userId/reset-password" -Token $adminToken -Body $credPayload | Out-Null
            Write-KcResult -Status 'UPDATED' -Message "Password reseteada para $username"
        }
    }

    # Asignar rol institucional
    $role = Find-KcClientRole -ServerUrl $serverUrl -Realm $realmName -Token $adminToken -ClientUuid $apiClient.id -RoleName $roleName
    if ($null -ne $role) {
        $currentRoles = (Invoke-KcAdminApi -Method Get -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$userId/role-mappings/clients/$($apiClient.id)" -Token $adminToken).Body
        $hasRole = @($currentRoles) | Where-Object { $_.name -eq $roleName }
        if (-not $hasRole) {
            Invoke-KcAdminApi -Method Post -ServerUrl $serverUrl -Path "/admin/realms/$realmName/users/$userId/role-mappings/clients/$($apiClient.id)" -Token $adminToken -Body @($role) | Out-Null
            Write-KcResult -Status 'UPDATED' -Message "Rol $roleName asignado a $username"
        } else {
            Write-KcResult -Status 'OK' -Message "Rol $roleName ya presente en $username"
        }
    }
}

Write-Host ''
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "✅ Siembra de usuarios en Keycloak completada exitosamente." -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green

