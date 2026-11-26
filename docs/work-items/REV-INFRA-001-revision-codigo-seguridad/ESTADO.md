# REV-INFRA-001: correcciones de la revisión de código y de seguridad de `develop` (Infra)

Rama `fix/revision-codigo-seguridad-infra`, desde `develop` f6133ba (2026-11-26). Pedido de John: corregir los hallazgos
del `/code-review` y los casi-hallazgos del `/security-review` de `develop` de Infra, en una sola rama y un solo PR.

## Hallazgos corregidos

| # | Hallazgo | Corrección |
| :--- | :--- | :--- |
| 1 | `stack up completo` siempre se rechaza: con el Pulsar del Catálogo 0.1.17 suma 10 550 MB y el límite es 9 700 MB | Nuevo switch `-ForzarMemoria` en `stack.ps1` (también llega desde `infra.ps1 stack`). Sin él se mantiene la protección, con un mensaje que explica las salidas. `stack/README.md` y `DEMO_DOCKER.md` documentan el valor real (10,55 GB) y recomiendan 12 GB de VM para `completo` |
| 2 | `infra.ps1` ponía `MSSQL_SA_PASSWORD` fija cuando no la encontraba y no miraba `stack/.env`; el valor falso le ganaba a la clave real (login 18456) | Se busca en `.env` de Infra, `stack/.env` y `.env` de BD (`MSSQL_SA_PASSWORD`, `SA_PASSWORD`, `SQL_CONTAINER_PASSWORD`). Sin valor fijo: si no está, cada script da su propio error |
| 3 | `infra.ps1 init-env -Profile docker|ci` no se podía ejecutar (dos `ValidateSet` incompatibles) | `-Profile` de `infra.ps1` ya no tiene `ValidateSet`: lo valida cada script (`start-dev.ps1` o `init-env.ps1`). `down -Profile` ya no se reenvía a `stop-dev.ps1`, que no lo acepta |
| 4 | `Invoke-PdpProvision` daba éxito aunque `verify` se cayera | Éxito solo si no hay `FALTA` y `verify` produjo su informe JSON (`"clean"`). `verify` sale con 1 también por `SOBRA` (no bloquea): ese caso sigue en verde. Si no hay informe se avisa en rojo sin imprimir la salida |
| 5 | Redes y volúmenes `external: true` que `stack up` nunca creaba (PC nuevo) | Se agregaron a `redesExternas` (`asistencias-security-lab-net`) y `volumenesExternos` (17 volúmenes de seguridad, antivirus, contingencia, observabilidad, mensajes y parámetros) de `secciones.json`. `Initialize-Recursos` los crea vacíos si faltan; los existentes no se tocan |
| 6 | La prueba de eventos de `test_catalogo_parametros.ps1` restauraba en el Catálogo el valor de la BD | Se guarda el `ANTES=` del primer cambio (valor previo del Catálogo) y se restaura ese |
| 7 | Clave SA en la línea de comandos (`sqlcmd -P`, `docker exec -e CLAVE=valor`, `deploy_schema.ps1 -Password`, healthcheck) | `SQLCMDPASSWORD` en el entorno del proceso y `docker exec -e SQLCMDPASSWORD` sin valor en `deploy-schema.ps1`, `test-summary.ps1`, `seed-clean-data.ps1`, `start-dev.ps1`, `reset-datos-prueba.ps1`, `cargar-datos-variados.ps1` y `test_catalogo_parametros.ps1`. `cargar-datos-variados.ps1` pasa la clave a `deploy_schema.ps1` por `SQL_CONTAINER_PASSWORD`. El healthcheck de `docker-compose.yml` usa `CMD-SHELL` con `$$MSSQL_SA_PASSWORD`, igual que `asis-datos.yml` |
| 8 | El perfil `cache` (Redis) no se podía pedir con `-Profile` | `cache` agregado a `start-dev.ps1` (ValidateSet y arranque por perfil) y a la ayuda de `infra.ps1` |
| 9 | `db-cupos` apuntaba a un `aumentar-cupos.ps1` que no existe en ningún repo ni en el workspace | Se retiró el comando, su línea de ayuda y la fila de `docs/sitio/operacion.html` |
| 10 | `.pyc` versionado | Se quitó del índice y `.gitignore` ignora `__pycache__/` y `*.py[cod]` |

## Contraseñas fijas retiradas (security review)

| Archivo | Antes | Ahora |
| :--- | :--- | :--- |
| `components/sqlserver/init/01-hardening-least-privilege.sql` | `app_asistencias_user` con contraseña fija | Variable de sqlcmd `$(APP_DB_PASSWORD_TSQL)`, que `deploy-schema.ps1` toma de `APP_DB_PASSWORD` y pasa por el entorno (comillas simples duplicadas). Si el login existe se sincroniza su contraseña. Sin `APP_DB_PASSWORD` no se crea el login (solo rol y permisos) |
| `scripts/orchestration/init-env.ps1` | Claves fijas para SA, `APP_DB_PASSWORD`, MinIO y el secreto del cliente de Keycloak | Se conserva el valor existente (también con `-Force`, para no dejar contenedores con una clave distinta a la de sus volúmenes) buscándolo en los `.env` que genera; si falta o es `CHANGE_ME`, se genera al azar (24 caracteres, cumple SQL Server y la política del realm). Ahora también escribe `E2E_DOCENTE_*` y `E2E_ADMIN_*` |
| `infra.ps1`, `load-env.ps1`, `start-dev.ps1`, `test-summary.ps1`, `seed-clean-data.ps1` | Respaldo fijo de la clave SA | Sin respaldo: error claro si falta |
| `components/keycloak/scripts/seed-users.ps1` | Claves por defecto de `docente.prueba` y `admin.prueba` | `E2E_DOCENTE_PASSWORD` y `E2E_ADMIN_PASSWORD` obligatorias (rechaza la plantilla) |
| `get-token.ps1`, `diagnose-token.ps1` | Las mismas claves fijas | `get-token`: `.env`, `TEST_*_PASSWORD` o se pide por consola. `diagnose-token`: `.env`; si falta, avisa y omite la prueba de token |

`.env.example` declara `E2E_DOCENTE_PASSWORD` y `E2E_ADMIN_PASSWORD` como plantilla.

## Impacto para el equipo

- Quien ya tiene sus `.env` no nota cambios: `init-env` (con o sin `-Force`) conserva las claves existentes.
- `kc-seed` (Keycloak propio, modo legacy) ahora exige `E2E_DOCENTE_PASSWORD` y `E2E_ADMIN_PASSWORD` en el `.env`.
  Si las cuentas ya existían con la clave anterior, defina esa clave en el `.env` o use `KC_RESET_EXISTING_E2E_PASSWORDS=true`.
- El primer `db-deploy` con `APP_DB_PASSWORD` definida deja el login `app_asistencias_user` con esa clave (antes tenía la
  fija del script, que no coincidía con el `.env`). El Backend local sigue entrando como `sa` (TD conocida), así que no cambia.
- `stack up completo` exige `-ForzarMemoria`.

## Validación

Ver la sección de validación del PR. Sin daemon de Docker en el entorno de la revisión: los cambios de sqlcmd
(`SQLCMDPASSWORD`, variable `$(APP_DB_PASSWORD_TSQL)`) quedan por probar en el PC con `.\infra.ps1 db-deploy`.
