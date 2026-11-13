# VAL-oleada3-baul-secretos (Infra) - VALIDATION

Fecha: 2026-11-13. No se arrancó ni se detuvo ningún contenedor.

## SEC-07: `docker compose config`

Archivo de variables desechable fuera del repositorio con valores ficticios para las seis variables exigidas
(`GRAFANA_ADMIN_PASSWORD`, `KC_BOOTSTRAP_ADMIN_PASSWORD`, `KC_DB_PASSWORD`, `MINIO_ROOT_PASSWORD`, `MINIO_ROOT_USER`,
`MSSQL_SA_PASSWORD`), extraídas de los `${VAR:?}` de los compose.

| Compose | Con valores ficticios (`--env-file`, `--profile full`) | Con un archivo de variables vacío |
|---|---|---|
| `docker-compose.yml` | exit 0 | falla: `MSSQL_SA_PASSWORD` sin valor |
| `components/keycloak/docker-compose.yml` | exit 0 | falla: `KC_DB_PASSWORD` sin valor (con su mensaje) |
| `components/sqlserver/docker-compose.yml` | exit 0 | falla: `MSSQL_SA_PASSWORD` sin valor (con su mensaje) |

Búsqueda en los tres compose de `origin/develop`: ningún `${...PASSWORD|SECRET|KEY|TOKEN|CREDENTIAL...:-valor}` ni
credenciales literales; los únicos `:-` con "PASSWORD" son `KC_PASSWORD_MIN_LENGTH` (política, no secreto).
SEC-07 sigue en CUMPLE sin cambios de compose.

## `init-env.ps1` y `.env.example`

Revisión del diff: solo selectores de proveedor, los dos endpoints de desarrollo (no son secretos) y la bandera
`APP_SECRETS_RUNTIME_FROM_VAULT_ENABLED=false`. No se ejecutó el script (regeneraría `.env` reales).
Sin gitleaks local; revisión manual del diff sin valores secretos.
