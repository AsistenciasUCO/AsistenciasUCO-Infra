# PLAN — VAL-oleada3-carga (Infra)

Origen: `informes/LISTA_CHEQUEO_VALIDACION_2026-11-12.md` (REA-06, F12-08, REA-01). Rama `fix/VAL-oleada3-carga-replicas`.
El detalle (objetivos p95, escenarios, resultados, hallazgos de estado por instancia) vive en el backend:
`Repositorio_GestionAsistenciaBackend/docs/work-items/VAL-oleada3-carga/` (PLAN.md, VALIDATION.md, evidencias/).

## Qué aporta Infra

| Archivo | Qué hace |
|---|---|
| `docker-compose.replicas.yml` | Proyecto Compose independiente `asistencias-uco-replicas`: Traefik `v3.2` fijado por digest, `127.0.0.1:8088`, sin socket de Docker, límite 128 MB, sonda `traefik healthcheck --ping`. No modifica `docker-compose.yml` ni sus perfiles y no lee `.env`. |
| `components/proxy/replicas/traefik.yml` | Entrada `web :8088` (HTTP plano, solo loopback del host), `ping :8082` interno, proveedor de archivos, access log JSON (con `ServiceURL` para contar el reparto), sin chequeo de versión. |
| `components/proxy/replicas/dynamic/replicas.yml` | Servicio ponderado 1:1 entre `host.docker.internal:8080` y `:8082`; cada réplica con health check a `/actuator/health/readiness` de su puerto de gestión (8090/8092, cada 5 s, timeout 2 s); el ponderado propaga la salud. |

Decisiones:
- Sin el middleware `rate-limit` del proxy principal (100 req/min por IP): k6 sale de una sola IP.
- Sin `sec-headers`: este proxy solo existe para medir; el proxy principal (`components/proxy`, perfil `proxy`) no cambia.
- Las réplicas corren en el host (el launcher oficial del backend carga `.env` y `lab.env` sin imprimirlos); meterlas en
  contenedores obligaría a reescribir las URL de BD, PEP e issuer de Keycloak y a pasar secretos por `env_file`.

## Validación

- `docker compose -f docker-compose.replicas.yml config -q` → OK; `docker compose -f docker-compose.yml config -q` → OK
  (sin cambios en el orquestador maestro).
- Corridas reales del 2026-11-13: reparto 398/399 entre réplicas, caída de una réplica detectada en ≈5 s (21 respuestas 502
  en 4,5 s y luego 100 % a la réplica viva). Números y evidencias en el work item del backend.
- Recomendación pendiente: middleware `retry` (solo errores de red, antes de enviar respuesta) para absorber las 502 de
  la ventana de detección.
