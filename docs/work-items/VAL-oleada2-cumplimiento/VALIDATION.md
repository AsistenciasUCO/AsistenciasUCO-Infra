# VAL-oleada2-cumplimiento (Infra y borde) - VALIDATION

Fecha: 2026-11-12. No se levantó ni detuvo ningún contenedor (hay una compuerta de BD y el laboratorio de seguridad corriendo).

## Pruebas corridas

| Prueba | Resultado |
| :--- | :--- |
| `docker compose --env-file .env.example -f docker-compose.yml --profile full --profile legacy config -q` | OK |
| `docker compose --env-file .env.example -f components/keycloak/docker-compose.yml --profile legacy config -q` | OK |
| `docker compose --env-file .env.example -f components/sqlserver/docker-compose.yml config -q` | OK |
| `docker compose --env-file /dev/null -f docker-compose.yml config -q` (sin variables) | Falla con el mensaje de variable obligatoria, como se espera |
| Generación de la CSP: `40-env-js.sh` ejecutado con rutas temporales y `API_URL`/`KEYCLOAK_URL` ficticias | Produce `connect-src 'self'` más los orígenes, y HSTS solo con `ENABLE_HSTS=true` |
| `sh -n` sobre `40-env-js.sh` | OK |

No se probó: construcción de la imagen del FE, `nginx -t`, `promtool check rules`, arranque de Traefik, Tempo y Alertmanager (implican contenedores nuevos). Hágase en la validación final.

## Aviso para el `.env` local

El `.env` local no define `GRAFANA_ADMIN_PASSWORD`. Mientras falte, `docker compose` sobre `docker-compose.yml` falla en cualquier perfil. Agregue la variable (ver `.env.example`) antes del próximo uso.

## Cómo probar (con contenedores, en la validación final)

FE (desde `FE/`):

```
docker build -t asistencias-fe:test .
docker run --rm -p 8080:8080 -e API_URL=http://localhost:8080/api/v1 asistencias-fe:test
curl -sI http://localhost:8080/ | findstr /i "content-security x-frame x-content referrer permissions server"
docker inspect --format "{{.Config.User}} {{.State.Health.Status}}" <contenedor>
```

Esperado: usuario `101`, salud `healthy`, encabezados presentes (también en `/assets/env.js`) y `Server: nginx` sin versión. Con `-e ENABLE_HSTS=true` aparece `Strict-Transport-Security`. En el navegador, la consola no debe mostrar violaciones de CSP al iniciar sesión y navegar; si el IdP o el API usan otro origen, agréguelo con `CSP_EXTRA_CONNECT_SRC="https://otro.host"`.

Traefik (`docker compose --profile proxy up -d proxy`):

```
curl -sI http://app.localhost/                         # 301/308 a https
curl -skI https://app.localhost/                       # encabezados sec-headers-web (certificado por defecto autofirmado, -k)
curl -skI https://api.localhost/api/v1/health          # sec-headers con CSP default-src 'none'
for i in $(seq 1 200); do curl -sk -o /dev/null -w "%{http_code}\n" https://api.localhost/; done | sort | uniq -c   # aparecen 429
```

Para un certificado local confiable use `mkcert app.localhost api.localhost`, monte la carpeta fuera del repositorio y declare `tls.certificates` en un archivo dinámico aparte; no commitee la clave.

Monitoreo (`docker compose --profile observability up -d`):

1. Backend en el host con `MANAGEMENT_SERVER_ADDRESS=0.0.0.0` (solo desarrollo; no exponer el 8090 fuera del equipo).
2. Prometheus `http://127.0.0.1:9090/targets`: `asistencias-backend` debe estar UP; `alertmanager` UP.
3. `http://127.0.0.1:9090/rules`: seis reglas cargadas. `promtool check rules` (dentro del contenedor de Prometheus) debe devolver SUCCESS.
4. Detener el backend 2 minutos: `BackendCaido` pasa a firing y aparece en `http://127.0.0.1:9093`. El receptor es local: no se envía nada.
5. Trazas: con el backend enviando OTLP a `localhost:4318`, Grafana (`http://127.0.0.1:3000`, datasource Tempo) las muestra; Tempo guarda en memoria (se pierden al reiniciar).

## Estado propuesto

| Ítem | Estado |
| :--- | :--- |
| TRI-08 | CUMPLE al construir y verificar la imagen (usuario 101, versión y digest fijos, `HEALTHCHECK`) |
| CF-04 | CUMPLE al verificar encabezados y ausencia de violaciones CSP en navegador. La CSP lleva `script-src-attr 'unsafe-inline'` por el `onload` que Angular inyecta en el CSS crítico y `style-src 'unsafe-inline'` por los estilos de componentes; quitarlos exige `inlineCritical: false` en `angular.json` y nonce |
| CF-03 | CUMPLE: routers con middlewares y TLS; certificado autofirmado de Traefik (el confiable es opcional) |
| OBS-08 | CUMPLE con el backend en `MANAGEMENT_SERVER_ADDRESS=0.0.0.0`; el valor por defecto (loopback) sigue siendo el seguro |
| OBS-09 | CUMPLE en el borde de Infra (colector a Tempo y Grafana); el muestreo de producción es del backend |
| OBS-12 | CUMPLE para backend caído, 5xx, latencia, Hikari y heap; fallos del outbox y del SMTP dependen de métricas que debe exponer el backend |
| SEC-10 | La parte de Infra (sin credenciales por defecto) cumple; falta el runbook de rotación y el Key Vault (SEC-02, SEC-07) |
| F12-10 | SQL Server fijado; el resto de F12-10 (entorno de producción documentado, prueba de outbox con SMTP) sigue pendiente |

## Cadena de suministro y CI (agente T)

actionlint 0; YAML OK; promtool y amtool SUCCESS; compose config rc 0; Trivy local 0 hallazgos; gitleaks con configuración 0. Detalle en [CI-CADENA-SUMINISTRO.md](CI-CADENA-SUMINISTRO.md).
