# PLAN — VAL-oleada8-observabilidad (Infra)

Fecha: 2026-11-15. Rama `fix/VAL-oleada8-observabilidad` desde `origin/develop` (057aedc). Origen:
`informes/LISTA_CHEQUEO_VALIDACION_2026-11-12` (estado al 2026-11-13), ítems OBS-11 y OBS-12 del dueño de Infra. El cambio
del backend de la misma oleada está en `Repositorio_GestionAsistenciaBackend/docs/work-items/VAL-oleada8-backend/`.
No se cruza con `chore/VAL-oleada7-pendientes` (proxy de réplicas y TD-093).

## Qué cambia

| Ítem | Archivo | Cambio |
|---|---|---|
| OBS-12 | `components/observability/prometheus/alert-rules.yml` | Grupo nuevo `asistencias-notificaciones` con 6 reglas sobre métricas que el backend ya expone: `OutboxNotificacionesMuertas`, `OutboxReintentosSostenidos`, `OutboxPublicacionFallida`, `SmtpRechazosPermanentes`, `SmtpFallosSostenidos` y `SmtpTopeDeEnviosAlcanzado`. |
| OBS-12 | `components/observability/prometheus/alert-rules.test.yml` | Pruebas de `promtool test rules`: `BackendCaido` dispara a los 2 minutos sin scrape y no antes; cada regla de notificaciones dispara con su condición y no con datos sanos. |
| OBS-12 | `.github/workflows/infra-validation.yml` | El paso de promtool también corre `test rules`. |
| OBS-11 | `components/observability/grafana/provisioning/dashboards/` | Proveedor `dashboards.yaml` y `asistencias-uco-metricas.json` (20 paneles: salud, tráfico, latencia, recursos, outbox, SMTP, SSE y hechos de negocio). Es el mismo JSON del stack `asis-obs` del backend. Variables `ds` y `job`. |
| OBS-11 | `.github/workflows/infra-validation.yml` | Comprueba que los archivos existan y que cada dashboard sea JSON con `uid` y paneles (`jq`). |

## Fuera de alcance

- CF-03 (Traefik con cabeceras y 429) y OBS-09 en ejecución (arrancar Tempo): necesitan levantar el stack; esta PC tiene poca
  memoria para Docker con el laboratorio arriba.
- F12-10 (entorno de producción documentado): sin definición del ambiente.
