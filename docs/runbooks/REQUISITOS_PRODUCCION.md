---
status: active
type: runbook
scope: production-readiness
owner: devops-team
last-reviewed: 2026-11-16
---

# Requisitos para un despliegue real en producción

> **Alcance (2026-11-16).** La entrega actual es una demostración con imágenes Docker. El despliegue en servidores de la universidad es futuro. Esta es una lista de comprobación de lo que la universidad debe resolver antes de ese despliegue, no un diseño: nada de esto está implementado ahora. Cada punto remite a su deuda en [TECHNICAL_DEBT.md](../baseline/TECHNICAL_DEBT.md).

## 1. Red y transporte

- [ ] **TLS y dominios.** Terminación TLS para la SPA, la API y el IdP; hoy todo va por HTTP en el laboratorio (TD-108).
- [ ] **HSTS.** Activar `ENABLE_HSTS=true` en el contenedor del frontend solo detrás de TLS (`docker-entrypoint.d/40-env-js.sh`) (TD-108).
- [ ] **Puerto de gestión del backend.** `/actuator/health` y `/actuator/prometheus` salen por `MANAGEMENT_SERVER_PORT` (8090) en `127.0.0.1`; no publicarlo fuera de la máquina o la red interna y no usar `MANAGEMENT_SERVER_ADDRESS=0.0.0.0` (TD-022, cerrada con esta condición).
- [ ] **Caché de nginx.** `no-cache` para `index.html` y caché larga e inmutable para los assets con hash; hoy solo `assets/env.js` tiene `Cache-Control` (TD-109).

## 2. Identidad y sesión

- [ ] **Keycloak en modo `start`, no `start-dev`.** El compose de Infra usa `start-dev` (`docker-compose.yml`, `components/keycloak/docker-compose.yml`); confirmar con el equipo de Security Baseline el modo del Keycloak que se desplegará (TD-108).
- [ ] **`SECURITY_BASELINE_PEP_ENVIRONMENT=prod`.** El valor por defecto del backend es `dev` (`application.yml`) (TD-108).
- [ ] **`SECURITY_PROVIDER=legacy` prohibido** (frontend, y `APP_ADAPTERS_SECURITY_PROVIDER` en el backend): el modo `legacy` guarda un refresh token en `sessionStorage`; solo `baseline` (Authorization Code + PKCE, access token en memoria) (TD-110, TD-106).
- [ ] **`USE_MOCKS` prohibido.** La imagen de entrega no debe arrancar con `USE_MOCKS=true`; hoy el entrypoint no lo impide (TD-102).
- [ ] **`environment.production` verdadero** en el build de producción del frontend (TD-103).
- [ ] **Sesión por cookie `HttpOnly` / BFF**, si la universidad lo exige: exige cliente confidencial y revisar tres contratos congelados que fijan Bearer (TD-110).
- [ ] **Depurar permisos sobrantes del PDP** con `provision_asistencias.py pdp --prune` y recursos huérfanos, seguido de `verify` y `verify-decisions` (TD-072, TD-073).

## 3. Base de datos

- [ ] **Usuario SQL de mínimo privilegio y un solo rol.** El generador de entorno conecta como `sa`; unificar `db_app_executor` (Infra) y `rol_asistencias_runtime` (BD) en uno (TD-099).
- [ ] **Sin cuentas semilla.** `deploy_schema.ps1` siembra cuentas con credenciales fijas; no sembrarlas en producción (TD-101).
- [ ] **Vistas sin la columna `password`** y sin `SELECT` general sobre `uv_%` para el rol de aplicación (TD-100).
- [ ] **Orden de despliegue:** migraciones antes de `deploy_schema`, y `migrar.ps1 -Modo Estado` antes de cualquier `-Modo Aplicar` (TD-081; véase [PRUEBAS_LOCALES](PRUEBAS_LOCALES.md)).
- [ ] **Índices únicos** de correo, tipo y número de documento, y de `usuario` en las tablas de rol, antes de abrir altas masivas (TD-093).
- [ ] **Copias de seguridad y rollback.** Definir respaldo, restauración y retorno a la versión anterior de BD y de imágenes; no existe runbook de despliegue ni de rollback de release (TD-108).

## 4. Backend y configuración

- [ ] **Perfiles `dev` y `local` de Spring prohibidos** (`application-dev.yml`, `application-local.yml`) (TD-108).
- [ ] **Secretos en Key Vault** (`SecretVaultPort`) sin valores por defecto ni `.env` con credenciales; las credenciales de laboratorio de `AGENTS.md` no se usan (TD-027).
- [ ] **Azure App Configuration y Key Vault reales** certificados con evidencia sanitizada; en el laboratorio no se usan (TD-027, TD-092).
- [ ] **`MESSAGEUCOLAB_FALLBACK`** definido a propósito (`none` o `azure`) y una sola aplicación "Asistencias UCO" por ambiente en MessageUcoLab (TD-092).
- [ ] **Rotación de credenciales** de SQL, MinIO, identidades de servicio y secretos del PDP, con procedimiento y responsable (TD-099, TD-101).
- [ ] **Gates remotos de CI** (ruleset y checks requeridos) con evidencia (TD-023).

## 5. Tiempo real y escala

- [ ] **Límites del SSE:** máximo de conexiones por usuario y revalidación del ámbito tras suscribir (TD-104).
- [ ] **Varias réplicas:** el canal SSE es en memoria de una JVM; decidir ADR de distribución y, si se exige durabilidad, outbox (TD-003, TD-011, TD-063).

## 6. Verificación previa al despliegue

- [ ] `infra.ps1 verify` (secretos y contratos) y `scripts/tests/test_all_hus.ps1` contra el stack real en modo `baseline`.
- [ ] Un conjunto de E2E de interfaz contra el backend real, no contra el simulador (TD-106).
