# VAL-oleada7-pendientes-transversales - VALIDATION

Fecha: 2026-11-15. Windows 11, PowerShell 5.1, Java 25, Python 3 de Windows. Worktrees aparte para Infra
(`chore/VAL-oleada7-pendientes`) y backend (`fix/VAL-oleada7-backend`); los checkouts principales los usa otro agente.
Sin cambios en la BD ni en el laboratorio compartido (solo lecturas del PDP).

## Resultado por paso

| Paso | Resultado | Evidencia |
| :--- | :--- | :--- |
| H2, H3, scripts e2e, ROL-12 | Verificados como corregidos en `develop` | `ManagementEndpointsSecurityConfiguration` (prometheus en gestión), `ArchivoErrorCode.ERR_ANTIVIRUS_NO_DISPONIBLE` (`SERVICE_UNAVAILABLE`), `e2e_provisioning.py` con alta de decano, PR del backend #149 |
| A. Escaneo de secretos | CUMPLE | `infra.ps1 verify` paso 1: `[PASS] ESCANEO LIMPIO` (antes: `HARDCODED_PASSWORD_LITERAL` en `infra-validation.yml:44`). El `grep` reescrito acepta `GRAFANA_ADMIN_PASSWORD=x` y rechaza `GRAFANA_ADMIN_PASSWORDX=x`. Paso 2 (contratos WORM) desde el checkout principal: 18 de 18 `[OK]`; la rama no toca `docs/contracts`. Desde el worktree el paso 2 no encuentra la carpeta `AsistenciasUCO-Infra` (el verificador espera esa ruta), no es un fallo de contenido |
| B. TD-093 | Registrado | `docs/baseline/TECHNICAL_DEBT.md` (fila y sección) |
| C. H4 | CUMPLE (backend) | Ver `VAL-oleada7-backend/VALIDATION.md` del backend |
| D. Cachés | CUMPLE (backend) | Ver `VAL-oleada7-backend/VALIDATION.md` del backend |
| E. H5 | CUMPLE en configuración; medición con carga pendiente | `docker compose -f docker-compose.replicas.yml config -q` rc 0; la configuración dinámica se analiza bien (router con `middlewares: [reintento-red]`, `retry: {attempts: 2, initialInterval: 100ms}`). No se arrancó Traefik: la imagen fijada no está descargada en este equipo y el laboratorio está en uso |
| F. Segundo rol en el PDP | Pendiente de decisión | Sin cambios |
| G. Deriva del PDP | Medida, sin revocar | `provision_asistencias.py verify` (solo lectura): 0 recursos, concesiones o perfiles faltantes; 118 concesiones de más (ADMINISTRADOR 81, DECANO 7, COORDINADOR 14, DOCENTE 9, ESTUDIANTE 7) y 43 recursos huérfanos. `pdp --prune` espera autorización |

## Hallazgo nuevo: inventario de rutas roto en `develop` (TD-087 recurrente)

`MensajesInterfazPublicaController` (commit del backend `8902130c`) declaraba `@RequestMapping(RUTA_BASE)`.
`extract_endpoints.py` solo acepta literales, así que la suite offline `test_*.py` fallaba (61 pruebas, 3 errores) y
`provision_asistencias.py catalog|verify|pdp` no corría. Se corrige en la rama del backend: literal en la anotación y
prueba de que coincide con `RUTA_BASE`. Después: 61 de 61 OK y `catalog` con 192 endpoints, 0 sin regla, 0 obsoletos.
La causa original de TD-087 (`RecuperacionClaveController`) ya no existe; TD-087 puede cerrarse al unir la rama.
