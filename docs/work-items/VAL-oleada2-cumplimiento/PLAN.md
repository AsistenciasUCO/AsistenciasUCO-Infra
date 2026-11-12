# VAL-oleada2-cumplimiento (Infra y borde) - PLAN

Fecha: 2026-11-12. Rama: `fix/VAL-oleada2-cumplimiento` (desde develop). Agente I.
Ítems de `informes/LISTA_CHEQUEO_VALIDACION_2026-11-12.md`: TRI-08, CF-04, CF-03, OBS-08, OBS-09, OBS-12, SEC-10, F12-10, y las decisiones C, D, E, F y G.

## Cambios

| Ítem | Qué cambia | Archivos |
| :--- | :--- | :--- |
| TRI-08 | Imagen del frontend `nginxinc/nginx-unprivileged:1.30.6-alpine` con digest, usuario 101, puerto interno 8080, `HEALTHCHECK` sobre `/healthz` | `FE/Dockerfile` |
| CF-04 | `server_tokens off`, `X-Frame-Options DENY`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, COOP y CSP generada en el arranque a partir de `API_URL`, `KEYCLOAK_URL`, `SECURITY_BASELINE_URL`, `SECURITY_BASELINE_ISSUER_URL` y `CSP_EXTRA_CONNECT_SRC`; HSTS solo con `ENABLE_HSTS=true` | `FE/nginx/default.conf`, `FE/nginx/security-headers.conf`, `FE/docker-entrypoint.d/40-env-js.sh` |
| CF-03 | Routers `frontend` y `backend` que usan `sec-headers`/`sec-headers-web` y `rate-limit`/`rate-limit-web`; entrypoint `websecure` (443) con TLS, redirección 80 a 443; CSP del API sin `unsafe-inline`; sin `stsPreload` | `components/proxy/traefik.yml`, `components/proxy/dynamic/middlewares.yml`, `components/proxy/dynamic/routers.yml`, `docker-compose.yml` (puerto 443, `extra_hosts`) |
| OBS-08 | Prometheus raspa `host.docker.internal:8090` (actuator del backend); `extra_hosts` para Linux | `components/observability/prometheus/prometheus.yml`, `docker-compose.yml` |
| OBS-12 | `alert-rules.yml` (backend caído, 5xx, latencia p95 y media, pool Hikari, heap JVM) cargado por `rule_files`; servicio `alertmanager` con receptor local sin credenciales | `components/observability/prometheus/alert-rules.yml`, `components/observability/alertmanager/alertmanager.yml`, `docker-compose.yml` |
| OBS-09 | Servicio `tempo` (tmpfs, solo desarrollo), exportador `otlp/tempo` en el colector y datasource de Grafana | `components/observability/tempo/tempo.yaml`, `otel-collector/config.yaml`, `grafana/provisioning/datasources/tempo.yaml`, `docker-compose.yml` |
| SEC-10 | Sin valores por defecto de credenciales: `${VAR:?mensaje}` para `KC_DB_PASSWORD`, `KC_BOOTSTRAP_ADMIN_PASSWORD`, `GRAFANA_ADMIN_PASSWORD`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`; `.env.example` con marcadores y las variables nuevas | `docker-compose.yml`, `components/keycloak/docker-compose.yml`, `.env.example` |
| F12-10 | `mssql/server:2022-latest` pasa a `2022-CU20-GDR1-ubuntu-22.04` (la misma compilación 16.0.4215.2 de la imagen local, sin cambio de datos) | `docker-compose.yml`, `components/sqlserver/docker-compose.yml` |
| Decisiones | DEC-067 a DEC-071 (D, E, G, C, F) | `docs/work-items/CULM-001-culminacion/DECISIONES.md` |

## Lo que queda fuera

- Ningún compose de Infra levanta el frontend; el contenedor FE se construye con `FE/Dockerfile` y se publica con el puerto 8080. Si se agrega al compose, mapear `host:8080`.
- Las lista de rutas requeridas del CI (`.github/workflows/infra-validation.yml`, agente T) debe incluir los archivos nuevos si quiere verificarlos.
- El histograma de latencia (`percentiles-histogram` de `http.server.requests`) lo define el backend (agente B); sin él `LatenciaP95Alta` no dispara y `LatenciaMediaAlta` hace de respaldo.
- Subir de CU20 a una compilación más nueva de SQL Server es una decisión aparte (migración de datos irreversible).

## Cadena de suministro y CI (agente T)

TRI-05, TRI-06, TRI-07, SEC-05, SEC-08, EST-09, EST-14 y las rutas/promtool pedidas por el agente I: plan, cambios y validación en [CI-CADENA-SUMINISTRO.md](CI-CADENA-SUMINISTRO.md).
