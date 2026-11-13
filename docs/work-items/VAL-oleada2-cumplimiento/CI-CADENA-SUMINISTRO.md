# VAL-oleada2-cumplimiento: cadena de suministro y CI de Infra (agente T)

Fecha: 2026-11-12. Rama `fix/VAL-oleada2-cumplimiento`. Ítems de `informes/LISTA_CHEQUEO_VALIDACION_2026-11-12.md`: TRI-05, TRI-06, TRI-07, SEC-05, SEC-08, EST-09 y EST-14, más la petición del agente I (rutas nuevas, promtool, compose con `.env.example`).

## Plan y cambios (`.github/workflows/infra-validation.yml`)

| Ítem | Cambio |
| :--- | :--- |
| TRI-05 | Trivy 0.74.0 fijado (`version`) y acción fijada por SHA (v0.36.0). Inventario SARIF (`exit-code 0`) subido a Code Scanning y como artifact, y compuerta `exit-code 1` con `HIGH,CRITICAL`, `ignore-unfixed: true`, escáneres `vuln,misconfig,secret`. `.trivyignore` creado (sin excepciones) |
| EST-14 | La compuerta Trivy misconfig bloquea; además `promtool check rules` y `promtool check config` (imagen `prom/prometheus:v3.0.1`, la misma del compose) y `amtool check-config` (`prom/alertmanager:v0.35.0`) |
| Agente I | `required_paths` suma `prometheus/alert-rules.yml`, `alertmanager/alertmanager.yml`, `tempo/tempo.yaml` y `proxy/dynamic/routers.yml`. `docker compose --env-file .env.example config --quiet` se conserva y antes comprueba que `.env.example` declare `GRAFANA_ADMIN_PASSWORD` |
| SEC-05 / SEC-08 | Job `Gitleaks Secret Scan` (binario 8.30.1 con SHA-256 fijado, solo commits del PR/push) y `.github/gitleaks.toml` |
| EST-09 | `.github/dependabot.yml`: docker-compose (`/`, `components/keycloak`, `components/sqlserver`) y github-actions, semanal, hacia `develop` |
| Fijado | checkout v7.0.1, upload-artifact v7.0.2, codeql-action/upload-sarif v4.39.3 por SHA; `runs-on: ubuntu-24.04`; permisos mínimos por job |

## Validación

| Prueba | Resultado |
| :--- | :--- |
| `rhysd/actionlint:1.7.12` (incluye shellcheck) | 0 hallazgos |
| Parseo YAML (js-yaml) del workflow y de `dependabot.yml` | OK |
| `promtool check rules` y `check config` locales con `prom/prometheus:v3.0.1` | SUCCESS, 6 reglas |
| `amtool check-config` local con `prom/alertmanager:v0.35.0` | SUCCESS (1 receptor) |
| `docker compose --env-file .env.example -f docker-compose.yml config --quiet` | rc 0 |
| Trivy local `aquasec/trivy:0.74.0 fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --ignore-unfixed` sobre el árbol rastreado, con los cambios del agente I | 0 hallazgos |
| gitleaks 8.30.1 `dir` sin configuración / con `.github/gitleaks.toml` | 10 falsos positivos (digests SHA-256 del OpenAPI en `docs/work-items/backend/...`) / 0 |
| gitleaks con configuración en modo `git`: rango `HEAD~5..HEAD` / historial completo (218 commits) | rc 0 / 0 hallazgos |
| Workflow en GitHub | No ejecutado; la primera corrida del PR es la evidencia |

## Pendiente externo

- El repo es público: Code Scanning recibe el SARIF sin licencia adicional. Revisar las alertas en Security > Code scanning tras la primera corrida.
- Marcar `Validate official Infra contents` y `Gitleaks Secret Scan` como required checks (admin).
