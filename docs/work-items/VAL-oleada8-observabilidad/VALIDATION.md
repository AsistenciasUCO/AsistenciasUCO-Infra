# VALIDATION — VAL-oleada8-observabilidad (Infra)

Validación local en Windows 11 (2026-11-15), sobre `origin/develop` 057aedc más los cambios de esta rama.

## Evidencia por ítem

| Ítem | Comando | Resultado |
|---|---|---|
| OBS-12 | `promtool check rules alert-rules.yml` (imagen `prom/prometheus:v3.2.1`) | `SUCCESS: 12 rules found` (6 anteriores + 6 de notificaciones) |
| OBS-12 | `promtool test rules alert-rules.test.yml` | `SUCCESS`. `BackendCaido` no dispara a los 3 min y dispara a los 5 min (2 min sin scrape); con `up = 1` no dispara. Cada regla de notificaciones dispara con su condición (1 notificación muerta, 60 % de reintentos, 2 publicaciones fallidas, 15 rechazos permanentes, 75 % de fallos SMTP, 4 envíos aplazados) y no con datos sanos (10 % de reintentos, solo envíos correctos). |
| OBS-12 | Nombres de las métricas | Comprobados contra el backend del laboratorio (`asis-app-backend`, `GET http://127.0.0.1:8090/actuator/prometheus` → 200): existen `notification_dispatch_total`, `notification_publish_total`, `notification_email_send_total` y `notification_email_throttled_total`. |
| OBS-11 | Grafana desechable `grafana/grafana:11.5.2` con `components/observability/grafana/provisioning` montado | `GET /api/dashboards/uid/asistencias-uco-metricas` → título "Asistencias UCO - Metricas del backend", 20 paneles (con el panel "Negocio" de OBS-07), carpeta "Asistencias UCO". Los únicos errores del log son las carpetas opcionales `plugins/` y `alerting/`, que no existen (igual que antes). |
| OBS-11 | Métricas del dashboard | Las 11 familias técnicas que consulta existen en el backend del laboratorio (`http_server_requests_seconds_bucket`, `hikaricp_connections_active`, `jvm_memory_used_bytes`, `jvm_threads_live_threads`, las 4 de notificaciones y `realtime_subscribers_active`, `realtime_events_published_total`, `realtime_events_dropped_total`). |
| OBS-11 | Comprobación de CI (`uid` y paneles) | Equivalente local con Python: `True` (esta PC no tiene `jq`; en el runner de GitHub sí está). |

## Pre-flight `infra.ps1 verify`

| Paso | Resultado |
|---|---|
| 1. Secretos | Falla por el falso positivo conocido en `.github/workflows/infra-validation.yml:44` (`grep -q '^GRAFANA_ADMIN_PASSWORD=' .env.example`). Ya existe en `develop` y lo corrige `chore/VAL-oleada7-pendientes` (paso A), aún sin unir. Esta rama no toca esa línea. |
| 2. Contratos WORM | `scripts/quality/verify-contracts.ps1`: `[PASS]`, 18 comprobaciones, cero drift. |
| 3. Rutas por rol | `[DRIFT]` contra el checkout principal del backend, que tiene sin confirmar una ruta nueva en `access-catalog.json` (`feat/activacion-cuentas`). Contra `repo-antiguo/develop` no hay cambio; esta rama no toca rutas. |

## Limitaciones

- No se levantó el stack de observabilidad completo (Prometheus raspando y Alertmanager notificando): las reglas se probaron
  con `promtool test rules`, que es la prueba unitaria oficial de Prometheus.
- CF-03 (Traefik, cabeceras y 429) sigue sin verificarse en ejecución.
