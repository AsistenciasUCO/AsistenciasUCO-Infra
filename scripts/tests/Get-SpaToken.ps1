# Obtiene un access_token del cliente publico PKCE `asistencias-uco-spa` (realm security-baseline)
# reproduciendo el flujo Authorization Code + PKCE (S256) del navegador. Los tokens de `admin-cli`
# (password grant) no traen audiencia `asistencias-api` y el backend los rechaza (CULM-001, DEC-008).
# Compatible con Windows PowerShell 5.1. Nunca imprime la clave ni el token.

function Get-HttpRedirect {
    param([string]$Uri, [string]$Body, $Session)
    # POST de formulario sin seguir redirecciones (en PS 5.1 Invoke-WebRequest -MaximumRedirection 0
    # no expone el 302); devuelve @{ Status; Location } leyendo la cabecera Location.
    $req = [System.Net.HttpWebRequest]::Create($Uri)
    $req.Method = "POST"
    $req.AllowAutoRedirect = $false
    $req.Timeout = 15000
    $req.CookieContainer = $Session.Cookies
    $req.ContentType = "application/x-www-form-urlencoded"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $req.ContentLength = $bytes.Length
    $stream = $req.GetRequestStream()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Close()
    try {
        $resp = $req.GetResponse()
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($null -eq $resp) { throw }
    }
    try {
        return @{ Status = [int]$resp.StatusCode; Location = $resp.Headers['Location'] }
    } finally {
        $resp.Close()
    }
}

function Get-SpaToken {
    param(
        [Parameter(Mandatory = $true)][string]$Username,
        [Parameter(Mandatory = $true)][string]$Password,
        [string]$Issuer = "http://keycloak.localhost:19090/realms/security-baseline",
        [string]$ClientId = "asistencias-uco-spa",
        [string]$RedirectUri = "http://localhost:4200/"
    )
    $oidc = $Issuer.TrimEnd('/') + "/protocol/openid-connect"

    # PKCE: verifier aleatorio de 64 caracteres [A-Za-z0-9] y challenge S256 en base64url.
    $alfabeto = [char[]]([char]'A'..[char]'Z' + [char]'a'..[char]'z' + [char]'0'..[char]'9')
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[] 64
    $rng.GetBytes($bytes)
    $verifier = -join ($bytes | ForEach-Object { $alfabeto[$_ % $alfabeto.Length] })
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($verifier))
    $challenge = [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_')

    $q = @{
        client_id = $ClientId; response_type = "code"; scope = "openid email profile"
        redirect_uri = $RedirectUri; code_challenge = $challenge; code_challenge_method = "S256"; state = "e2e"
    }
    $qs = ($q.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, [uri]::EscapeDataString($_.Value) }) -join "&"

    # 1) Pagina de login. Keycloak emite cookies Secure aun sobre http local y el CookieContainer de
    #    .NET no las reenvia, asi que se reinyectan a mano en una sesion con Secure desactivado.
    $page = Invoke-WebRequest -Uri "$oidc/auth?$qs" -UseBasicParsing -SessionVariable kcSession -TimeoutSec 15
    $setCookie = $page.Headers['Set-Cookie']
    if ($setCookie -is [array]) { $setCookie = $setCookie -join ',' }
    $sesion = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $uriAuth = [uri]$page.BaseResponse.ResponseUri
    foreach ($c in [regex]::Split([string]$setCookie, ',(?=\s*[A-Za-z0-9_]+=)')) {
        $par = ($c.Trim() -split ';')[0]
        $i = $par.IndexOf('=')
        if ($i -lt 1) { continue }
        $ck = New-Object System.Net.Cookie($par.Substring(0, $i), $par.Substring($i + 1), "/realms/", $uriAuth.Host)
        $ck.Path = "/realms/"
        $sesion.Cookies.Add($ck)
    }
    $m = [regex]::Match($page.Content, 'action="([^"]*)"')
    if (-not $m.Success) { throw "Get-SpaToken: no se encontro el formulario de login de Keycloak" }
    $action = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)

    # 2) Envio de credenciales sin seguir redirecciones; el 302 trae code=.
    $form = "username={0}&password={1}" -f [uri]::EscapeDataString($Username), [uri]::EscapeDataString($Password)
    $login = Get-HttpRedirect -Uri $action -Method "POST" -Body $form -Session $sesion
    $loc = [string]$login.Location
    if ($loc -notmatch '[?&]code=([^&]+)') { throw "Get-SpaToken: login rechazado para '$Username'" }
    $code = [uri]::UnescapeDataString($Matches[1])

    # 3) Canje del code por el token (con code_verifier).
    $tokenBody = @{ grant_type = "authorization_code"; client_id = $ClientId; code = $code; redirect_uri = $RedirectUri; code_verifier = $verifier }
    $res = Invoke-RestMethod -Uri "$oidc/token" -Method POST -Body $tokenBody -ContentType "application/x-www-form-urlencoded" -TimeoutSec 15
    if (-not $res.access_token) { throw "Get-SpaToken: respuesta sin access_token para '$Username'" }
    return $res.access_token
}
