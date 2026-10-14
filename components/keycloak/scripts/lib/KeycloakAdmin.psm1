# ==============================================================================
# 🏛️ ASISTENCIAS UCO - MÓDULO ADMINISTRATIVO DE KEYCLOAK (KeycloakAdmin.psm1)
# ==============================================================================
# Capa reutilizable para los scripts de bootstrap, export, validate, seed y tokens.
#
# Principios de Seguridad:
#  - NUNCA imprime: contraseñas de admin, client secrets, tokens de acceso o contraseñas.
#  - Compatible tanto con Windows PowerShell 5.1 como con PowerShell Core 7.x.
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-KcDotEnv {
    <#
        Carga un archivo .env estilo KEY=VALUE en un hashtable ordenado.
        Ignora líneas vacías y comentarios (#).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    $result = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $result
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        $separatorIndex = $trimmed.IndexOf('=')
        if ($separatorIndex -lt 1) {
            continue
        }
        $key = $trimmed.Substring(0, $separatorIndex).Trim()
        $value = $trimmed.Substring($separatorIndex + 1).Trim()
        if ($value.Length -ge 2 -and (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        )) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $result[$key] = $value
    }

    return $result
}

function Get-KcEnvValue {
    <#
        Resuelve una variable con prioridad: entorno del proceso > .env cargado > default.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$EnvMap,
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Default = $null
    )

    $fromProcess = [System.Environment]::GetEnvironmentVariable($Key)
    if (-not [string]::IsNullOrWhiteSpace($fromProcess)) {
        return $fromProcess
    }
    if ($EnvMap.Contains($Key) -and -not [string]::IsNullOrWhiteSpace($EnvMap[$Key])) {
        return $EnvMap[$Key]
    }
    return $Default
}

function Get-KcRequiredEnvValue {
    <#
        Resuelve una variable obligatoria y lanza excepción si está vacía.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$EnvMap,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $value = Get-KcEnvValue -EnvMap $EnvMap -Key $Key
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Falta la variable requerida '$Key'. Defínela en .env antes de ejecutar este script."
    }
    return $value
}

function ConvertTo-KcUrlEncoded {
    param([Parameter(Mandatory = $true)][string]$Value)
    return [System.Uri]::EscapeDataString($Value)
}

function Get-KcAdminToken {
    <#
        Obtiene un access token del realm master via password grant + admin-cli.
        El token solo se usa en memoria durante la ejecución; nunca se persiste.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Username,
        [Parameter(Mandatory = $true)][string]$Password
    )

    $tokenUrl = "$ServerUrl/realms/master/protocol/openid-connect/token"
    $bodyPairs = @(
        "grant_type=password",
        "client_id=admin-cli",
        "username=$(ConvertTo-KcUrlEncoded $Username)",
        "password=$(ConvertTo-KcUrlEncoded $Password)"
    )
    $body = [string]::Join('&', $bodyPairs)

    try {
        $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -ContentType 'application/x-www-form-urlencoded' -Body $body
    } catch {
        throw "No fue posible autenticar contra Keycloak ($ServerUrl) como admin de bootstrap. Verifica que el contenedor esté arriba y que las credenciales sean correctas. Detalle: $($_.Exception.Message)"
    }

    if (-not $response.access_token) {
        throw "Keycloak respondió sin 'access_token' al autenticar el admin de bootstrap."
    }

    return $response.access_token
}

function Test-KcServerReady {
    param([Parameter(Mandatory = $true)][string]$ManagementUrl)

    try {
        $response = Invoke-WebRequest -Method Get -Uri "$ManagementUrl/health/ready" -UseBasicParsing -TimeoutSec 5
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Invoke-KcAdminApi {
    <#
        Wrapper genérico para llamar a la Admin REST API (/admin/realms/...).
        Compatible con Windows PowerShell 5.1 y PS Core 7.x.
    #>
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Get', 'Post', 'Put', 'Delete')][string]$Method,
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Token,
        $Body = $null,
        [switch]$AllowNotFound
    )

    $uri = "$ServerUrl$Path"
    $headers = @{ Authorization = "Bearer $Token" }

    $requestArgs = @{
        Method          = $Method
        Uri             = $uri
        Headers         = $headers
        ContentType     = 'application/json; charset=utf-8'
        UseBasicParsing = $true
    }
    if ($null -ne $Body) {
        $requestArgs['Body'] = (ConvertTo-Json -InputObject $Body -Depth 20 -Compress)
    }

    $statusCode = $null
    try {
        $response = Invoke-WebRequest @requestArgs
        $statusCode = [int]$response.StatusCode
    } catch {
        $errorResponse = $_.Exception.Response
        if ($errorResponse) {
            try { $statusCode = [int]$errorResponse.StatusCode } catch { $statusCode = $null }
        }
        if ($statusCode -eq 404 -and $AllowNotFound) {
            return $null
        }
        $detail = $_.ErrorDetails.Message
        if ([string]::IsNullOrWhiteSpace($detail)) { $detail = $_.Exception.Message }
        throw "Keycloak Admin API respondió $statusCode en $Method $Path. Detalle: $detail"
    }

    $parsedBody = $null
    if ($response.Content -and $response.Content.Trim().Length -gt 0) {
        $parsedBody = $response.Content | ConvertFrom-Json
    }

    $location = $null
    if ($response.Headers -and $response.Headers.ContainsKey('Location')) {
        $rawLocation = $response.Headers['Location']
        $location = if ($rawLocation -is [array]) { $rawLocation[0] } else { $rawLocation }
    }

    return [pscustomobject]@{
        StatusCode = $statusCode
        Body       = $parsedBody
        Location   = $location
    }
}

function Find-KcRealm {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$RealmName
    )

    $result = Invoke-KcAdminApi -Method Get -ServerUrl $ServerUrl -Path "/admin/realms/$(ConvertTo-KcUrlEncoded $RealmName)" -Token $Token -AllowNotFound
    if ($null -eq $result) { return $null }
    return $result.Body
}

function Find-KcClientByClientId {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Realm,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$ClientId
    )

    $result = Invoke-KcAdminApi -Method Get -ServerUrl $ServerUrl -Path "/admin/realms/$Realm/clients?clientId=$(ConvertTo-KcUrlEncoded $ClientId)" -Token $Token
    $matches = @($result.Body | Where-Object { $_.clientId -eq $ClientId })
    if ($matches.Count -eq 0) { return $null }
    if ($matches.Count -gt 1) { throw "Se encontró más de un client con clientId '$ClientId'." }
    return $matches[0]
}

function Find-KcClientRole {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Realm,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$ClientUuid,
        [Parameter(Mandatory = $true)][string]$RoleName
    )

    $result = Invoke-KcAdminApi -Method Get -ServerUrl $ServerUrl -Path "/admin/realms/$Realm/clients/$ClientUuid/roles/$(ConvertTo-KcUrlEncoded $RoleName)" -Token $Token -AllowNotFound
    if ($null -eq $result) { return $null }
    return $result.Body
}

function Find-KcClientScopeByName {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Realm,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $result = Invoke-KcAdminApi -Method Get -ServerUrl $ServerUrl -Path "/admin/realms/$Realm/client-scopes" -Token $Token
    $matches = @($result.Body | Where-Object { $_.name -eq $Name })
    if ($matches.Count -eq 0) { return $null }
    return $matches[0]
}

function Find-KcUserByUsername {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Realm,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$Username
    )

    $result = Invoke-KcAdminApi -Method Get -ServerUrl $ServerUrl -Path "/admin/realms/$Realm/users?username=$(ConvertTo-KcUrlEncoded $Username)&exact=true" -Token $Token
    $matches = @($result.Body | Where-Object { $_.username -eq $Username })
    if ($matches.Count -eq 0) { return $null }
    return $matches[0]
}

function Write-KcResult {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $color = switch ($Status) {
        'OK' { 'Green' }
        'CREATED' { 'Cyan' }
        'UPDATED' { 'Cyan' }
        'MIGRATED' { 'Cyan' }
        'SKIPPED' { 'DarkYellow' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

Export-ModuleMember -Function @(
    'Import-KcDotEnv',
    'Get-KcEnvValue',
    'Get-KcRequiredEnvValue',
    'ConvertTo-KcUrlEncoded',
    'Get-KcAdminToken',
    'Test-KcServerReady',
    'Invoke-KcAdminApi',
    'Find-KcRealm',
    'Find-KcClientByClientId',
    'Find-KcClientRole',
    'Find-KcClientScopeByName',
    'Find-KcUserByUsername',
    'Write-KcResult'
)

