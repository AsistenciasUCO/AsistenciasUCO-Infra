---
status: active
type: work-item
scope: infra
owner: infra-team
last-reviewed: 2026-11-16
---

# VAL-oleada7-pendientes-transversales - VALIDATION

Fecha: 2026-11-15, revalidado el 2026-11-16. Windows 11, PowerShell 5.1, Java 25, Python 3 de Windows. El trabajo original
se hizo en `chore/VAL-oleada7-pendientes` (Infra) y `fix/VAL-oleada7-backend` (backend), sin PR. El 2026-11-16 se pasó a
`chore/VAL-oleada7-transversales` sobre `origin/develop` 66064a3 y a `fix/VAL-oleada7-cache-pep` sobre el develop del
backend 8530bd54, sin conflictos. Sin cambios en la BD ni en el laboratorio compartido (solo lecturas del PDP).

## Resultado por paso

| Paso | Resultado | Evidencia |
| :--- | :--- | :--- |
| H2, H3, scripts e2e, ROL-12 | Verificados como corregidos en `develop` | `ManagementEndpointsSecurityConfiguration` (prometheus en gestión), `ArchivoErrorCode.ERR_ANTIVIRUS_NO_DISPONIBLE` (`SERVICE_UNAVAILABLE`), `e2e_provisioning.py` con alta de decano, PR del backend #149 |
| A. Escaneo de secretos | CUMPLE | `infra.ps1 verify` desde esta rama: los 3 pasos `[PASS]` (secretos, 18 de 18 contratos WORM, rutas por rol). En `develop` el paso 1 falla con `HARDCODED_PASSWORD_LITERAL` en `infra-validation.yml:44` (comprobado el 2026-11-16). El `grep` reescrito acepta `GRAFANA_ADMIN_PASSWORD=x` y rechaza `GRAFANA_ADMIN_PASSWORDX=x` |
| A2. Escaneo de secretos con el stack por secciones | CUMPLE | Hallazgo del 2026-11-16: quien corrió `infra.ps1 stack up` tiene `stack/generado/backend.env` (ignorado por git) y el paso 1 lo marcaba (2 hallazgos). `check-secrets.ps1` ahora omite un `*.env` que git ignora y no versiona, como ya hacía con `.env`; ante la duda (fuera de un repositorio) lo escanea. `-SelfCheck` cubre el caso ignorado (se omite) y el mismo nombre sin regla de ignorar (se escanea): `[OK]`. Sobre el checkout principal, que tiene ese archivo, solo queda el hallazgo del `.yml` que corrige el paso A |
| B. TD-093 | Registrado | `docs/baseline/TECHNICAL_DEBT.md` (fila y sección) |
| C. H4 | CUMPLE (backend) | Ver `VAL-oleada7-backend/VALIDATION.md` del backend |
| D. Cachés | CUMPLE (backend) | Ver `VAL-oleada7-backend/VALIDATION.md` del backend |
| E. H5 | CUMPLE en configuración; medición con carga pendiente | `docker compose -f docker-compose.replicas.yml config -q` rc 0 (también el 2026-11-16); la configuración dinámica se analiza bien (router con `middlewares: [reintento-red]`, `retry: {attempts: 2, initialInterval: 100ms}`). No se arrancó Traefik: la imagen fijada no está descargada en este equipo y el laboratorio está en uso |
| F. Segundo rol en el PDP | Pendiente de decisión | Sin cambios |
| G. Deriva del PDP | Medida, sin revocar | `provision_asistencias.py verify` (solo lectura): 0 recursos, concesiones o perfiles faltantes; 118 concesiones de más (ADMINISTRADOR 81, DECANO 7, COORDINADOR 14, DOCENTE 9, ESTUDIANTE 7) y 43 recursos huérfanos. `pdp --prune` espera autorización |

## Inventario de rutas del PDP (TD-087)

El 2026-11-15 `MensajesInterfazPublicaController` declaraba `@RequestMapping(RUTA_BASE)` y `extract_endpoints.py` solo
aceptaba literales: la suite offline `test_*.py` fallaba y `provision_asistencias.py catalog|verify|pdp` no corría. La rama
del backend lo resolvía con una ruta literal. Ese mismo día se unió el PR del backend #153, que hace que el extractor
resuelva constantes, así que el ajuste del controlador se retiró de la rama. Sobre develop 8530bd54: 66 de 66 pruebas OK y
`catalog` con 193 endpoints, 0 sin regla, 0 obsoletos. TD-087 queda cerrada en `TECHNICAL_DEBT.md`.
