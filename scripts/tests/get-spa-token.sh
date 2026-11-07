#!/bin/bash
# Obtiene un access_token del cliente público PKCE `asistencias-uco-spa` (realm security-baseline)
# reproduciendo el flujo Authorization Code + PKCE del navegador. Los tokens de `admin-cli` no traen
# audiencia `asistencias-api` y el backend los rechaza (CULM-001, DEC-008).
# Uso: E2E_PASSWORD=<clave> ./get-spa-token.sh <usuario>   (p. ej. uco-docente)
# Variables opcionales: KC_ISSUER (issuer OIDC), SPA_REDIRECT (redirect_uri registrada), SPA_CLIENT.
set -euo pipefail
U="${1:?uso: get-spa-token.sh <usuario>}"
PW="${E2E_PASSWORD:?Defina E2E_PASSWORD (clave de prueba documentada en docs/CREDENCIALES_PRUEBAS_LOCAL.md)}"
ISS="${KC_ISSUER:-http://keycloak.localhost:19090/realms/security-baseline}/protocol/openid-connect"
RED="${SPA_REDIRECT:-http://localhost:4200/}"
CID="${SPA_CLIENT:-asistencias-uco-spa}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
V=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 64)
C=$(printf %s "$V" | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
curl -s -D "$TMP/h" -o "$TMP/b" -G "$ISS/auth" --data-urlencode "client_id=$CID" --data-urlencode response_type=code \
  --data-urlencode "scope=openid email profile" --data-urlencode "redirect_uri=$RED" \
  --data-urlencode "code_challenge=$C" --data-urlencode code_challenge_method=S256 --data-urlencode state=e2e
CK=$(grep -i '^set-cookie:' "$TMP/h" | tr -d '\r' | sed -E 's/^[Ss]et-[Cc]ookie: ([^;]*);.*/\1/' | paste -sd';' | sed 's/;/; /g')
A=$(grep -o 'action="[^"]*"' "$TMP/b" | head -1 | sed 's/action="//;s/"$//;s/&amp;/\&/g')
[ -z "$A" ] && { echo "get-spa-token: no se encontró el formulario de login de Keycloak" >&2; exit 1; }
L=$(curl -s -D - -o /dev/null -X POST "$A" -H "Cookie: $CK" --data-urlencode "username=$U" --data-urlencode "password=$PW" | grep -i '^location:' | tr -d '\r' | cut -d' ' -f2)
case "$L" in *code=*) ;; *) echo "get-spa-token: login rechazado para $U" >&2; exit 1;; esac
CODE=$(echo "$L" | sed -E 's/.*[?&]code=([^&]*).*/\1/')
curl -s -X POST "$ISS/token" -d grant_type=authorization_code -d "client_id=$CID" --data-urlencode "code=$CODE" \
  --data-urlencode "redirect_uri=$RED" --data-urlencode "code_verifier=$V" | sed -E 's/.*"access_token":"([^"]*)".*/\1/'
