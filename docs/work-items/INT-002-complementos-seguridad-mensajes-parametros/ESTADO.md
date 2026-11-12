# INT-002 — Integración de las nuevas versiones de los complementos (Seguridad, Mensajes y Parámetros)

> **Fecha:** 2026-11-11 · **Responsable técnico:** agente (Claude Fable 5.1) bajo dirección del responsable del proyecto
> **Ramas:** `feat/complementos-seguridad-mensajes-parametros` en Infra, Backend y Frontend (desde `develop`)
> **Entradas:** `Complementos/Seguridad` (mensaje del equipo de seguridad: PDP v0.1.11, librería v0.1.4), `Complementos/CatalogoMensajes/Nuveo` (MessageUcoLab 0.2.0 y su guía de actualización), `Complementos/CatalogoParametros/Catalogo-Parametros` (compose, `.env`, `GUIA-LIBERACION.md`, plantillas)

## 1. Resultado

| Componente | Antes | Ahora | Evidencia |
| :--- | :--- | :--- | :--- |
| Security Baseline (PDP, PEP, OPA, Keycloak) | 0.1.9 | **0.1.13** (última publicada, 2026-11-09) | `docker compose ps` sano; docente → `GET /docente/asignaturas` 200, docente → `GET /admin/asignaturas` 403, sin token 401; `Migración: cliente security-pdp-provisioner creado` en el log de Keycloak |
| Pantallas de seguridad (`securityBaseline-vue` :5173, `security-ui` :5175) | detrás de `main` | `main` (3973d34 y c969a82), dependencias instaladas, bundle `security-administration.js` reconstruido | `npm run build` exit 0; 200 en ambos puertos |
| Librería `security-pep-integration-spring-boot-starter` 0.1.4 | — | **No aplica**: el backend es Spring MVC y usa su propio cliente PEP (`SecurityBaselinePepClient`); el starter es solo WebFlux | `pom.xml` sin esa dependencia |
| MessageUcoLab | 0.1.0 | **0.2.0** (códigos hasta 50 caracteres, título 200, contenido 500) | pasos 1–7 de la guía ejecutados; `Catálogo de límites de mensajes actualizado.`; app `healthy`; consulta pública responde |
| `minifront-mensajes` (frontend) | 1d0d745 | **14a122d** (último `main`, 0.4.0) | `package-lock.json`, dev server sin errores |
| Pantalla de MessageUcoLab (:5174) | atrás | último `develop` del repositorio del equipo de mensajes | 200 |
| Catálogo de Parámetros | sin instalar | **instalado y registrado** (imágenes `simon4219/catalogo-parametros:0.1.7` y `-frontend:0.1.6`) | API 8081 `UP`, frontend 4201 200; token de consulta responde 200 con 20 parámetros y 401 con secreto incorrecto |
| Backend AsistenciasUCO | parámetros en `sqlserver` | nuevo proveedor **`catalogoparametros`** (`ParameterCatalogPort` sobre `GET /tokens/{id}/parametros`) | 28 pruebas nuevas, ArchUnit en verde, JaCoCo del código nuevo: 115/116 líneas, 85/86 ramas |

## 2. Qué se hizo, en orden

### 2.1 Seguridad (0.1.9 → 0.1.11 → 0.1.13)

1. Respaldo de los volúmenes `asistencias-security-lab_*-data` (keycloak, redis, surrealdb) en `C:\jtmp\backups\security-lab-0.1.9-<fecha>\` antes de tocar nada.
2. `SECURITY_VERSION=0.1.11` en `%USERPROFILE%\.asistencias-security-lab\lab.env`; `compose.yaml` oficial 0.1.9 y 0.1.11 son idénticos, así que solo cambió la versión. Permitida/denegada/sin token en verde.
3. **Hallazgo:** con 0.1.11 la creación de identidades de servicio (`POST /applications/{id}/service-identities`) responde 500: el PDP recibe 401 de Keycloak porque el realm persistido no tiene el cliente técnico `security-pdp-provisioner`. La 0.1.13 lo resuelve: su imagen de Keycloak migra el realm al arrancar y el compose pasa `PDP_KEYCLOAK_PROVISIONER_CLIENT_SECRET` a Keycloak y al PDP y `PDP_KEYCLOAK_ADMIN_URL`.
4. Paso a **0.1.13**, portando al compose endurecido del backend (`infra/security-baseline/compose.yaml`) exactamente esas tres variables (sin valor por defecto `change-me`: llegan de `lab.env`) y la nueva comprobación de salud con el marcador de migración.
5. **Segundo hallazgo:** el entrypoint de la imagen 0.1.13 espera el Admin API en `127.0.0.1:8080` (puerto fijo); nuestro Keycloak escuchaba en `KC_HTTP_PORT=19090`, así que la migración abortaba con `Keycloak no abrió el puerto de administración a tiempo`. Solución sin perder el endurecimiento: Keycloak vuelve al 8080 interno y un servicio `keycloak-relay` (`alpine/socat:1.8.0.3`, `network_mode: service:keycloak`) expone 19090 → 8080 dentro del mismo contenedor, de modo que PDP/PEP (`keycloak.localhost:19090` por `extra_hosts`) y el host (`127.0.0.1:19090`) siguen usando el puerto oficial.
6. Orígenes del PDP (`PDP_CORS_ALLOWED_ORIGINS`, `PDP_LOGIN_ALLOWED_RETURN_ORIGINS`, `PDP_SECURITY_LOGIN_ALLOWED_RETURN_ORIGINS`) ampliados con `http://localhost:4201` (frontend del Catálogo).
7. `lab.env.example`, `README.md` del laboratorio y `MESSAGEUCOLAB_INTEGRATION.md` actualizados a 0.1.13.

### 2.2 Mensajes (MessageUcoLab 0.1.0 → 0.2.0)

Guía del equipo de mensajes al pie de la letra: copiar el kit nuevo sobre `messageucolab-local` sin tocar `.env` (solo cambió `scripts/redis/CatalogMessageInit.sh` y el `README.md`), `MESSAGEUCOLAB_VERSION=0.2.0`, `pull messageucolab`, `up -d redis`, `run --rm --no-deps redis-init --message-limits-only`, y `up -d --no-deps` de los servicios con `PULSAR_GENERALPORT=18082` (el 8080 es del backend). Secretos vía Doppler (`DOPPLER_PROJECT=messageucolab-local`, `DOPPLER_CONFIG=dev`). Frontend: `npm install github:Jciro17/minifront-mensajes`; pantalla del equipo: `git pull origin develop` + `npm install`.

### 2.3 Parámetros (Catálogo de Parámetros)

El `.env` entregado traía valores del equipo de parámetros (su PDP, su MessageUcoLab, su identidad M2M), que no existen en nuestro laboratorio. Se registró todo de nuevo contra nuestra instalación (el `.env` original quedó como `.env.bak-equipo-parametros`):

1. **PDP:** aplicación `Catalogo` (`http://localhost:8081`, ambientes `dev`/`lab`) → `PEP_REGISTRATION_TOKEN`. La `plantilla-resources.xlsx` entregada venía **vacía** (solo encabezados), así que los recursos se registraron por API: los 7 de la guía más todas las rutas del OpenAPI del Catálogo (104 recursos), rol `ADMINISTRADOR_PARAMETROS`, perfil `Administracion de parametros`, asignado a `lab-pdp-admin`, `security-demo` y `uco-administrador`.
2. **Identidad de servicio Catálogo → MessageUcoLab:** `svc-…-catalogo-parametros-a-messageucolab-dev-v2` (la primera, `…-dev`, quedó creada sin secreto conocido por un fallo del script y el PDP no permite rotarla ni borrarla: ignorarla), recurso `GET /messageucolab/v1/public/messages/{codigo}` y rol técnico `MESSAGEUCOLAB_MESSAGES_READ` en la aplicación `MessageUcoLab`, solicitud aprobada. `client_credentials` responde 200 y el PEP deja pasar la consulta pública (422 por falta de `X-Environment-Id`, es decir, ya dentro de la aplicación).
3. **MessageUcoLab:** aplicación `Catalogo` en la organización `UCO` (ambientes Develop/Testing/Produccion), 7 funcionalidades de la plantilla e importación de `plantilla-mensajes.xlsx` (144 mensajes, 0 errores) para Develop. La plantilla trae en su hoja oculta el `applicationId` del equipo de parámetros; se reemplazó por el nuestro antes de importar.
4. **Catálogo:** organización `UCO`, aplicación `AsistenciasUCO`, ambiente `Develop`, módulo `Asistencias`, funcionalidad `Parametros de negocio`, 21 parámetros con nombre `GRUPO.CLAVE` (los de `ParametrosPorDefecto`) y sus metadatos para Develop (`RED.PROXIES_CONFIABLES` sin metadato: el Catálogo rechaza el valor vacío y aplica el valor por defecto del backend), y un **Token** de consulta.
5. **Backend:** proveedor `catalogoparametros` (`CatalogoParametrosHttpParameterCatalogAdapter`, `CatalogoParametrosProviderProperties`, `CatalogoParametrosAdapterConfiguration`), una sola llamada `GET /tokens/{id}/parametros` con caché por TTL (5 min; con la caché vencida se sirven los valores anteriores y se refresca en segundo plano con una sola petición en vuelo; si el refresco falla se conservan los valores, se escribe WARN y no se reintenta durante una gracia de hasta 30 s acotada por el TTL; timeout HTTP por defecto 10 s, antes 3 s), selección por `parametro.nombre` = `GRUPO<separador>CLAVE`, valor en `metadatos[].metadato.valor`; 401/403/5xx y fallos de red → `ParameterCatalogException` (el decorador DEC-018 aplica el valor por defecto). Variables `CATALOGO_PARAMETROS_*` documentadas en `.env.example` y `.env.template`.

6. **Verificación 2026-11-12:**
   - **PDP:** aplicación `Catalogo` con 104 recursos, rol `ADMINISTRADOR_PARAMETROS` con 100 recursos, perfil `Administracion de parametros` asignado a `lab-pdp-admin`, `security-demo` y `uco-administrador`.
   - **PEP:** `security-demo` -> 200 en `/parametros`, `/organizaciones` y `/tipos-metadato`; `uco-docente` -> 403 `ACCESS_DENIED`; sin sesión -> 401 `TOKEN_INVALID`.
   - **Script E2E:** `scripts/tests/test_catalogo_parametros.ps1` (salud del Catálogo y su frontend, lectura del token con secreto válido/inválido/ausente, API administrativa sin sesión, Kong, salud del backend y registro QR con correo no institucional -> 400 `VCE_001` con `@uco.edu.co` tomado del Catálogo). Resultado con el laboratorio levantado: todas las comprobaciones pasaron (lectura del token en ~1 s con el Catálogo caliente, 20 parámetros).

## 3. Cómo levantar el laboratorio ahora (orden y conjunto ligero)

La VM de Docker (7,65 GiB) **no soporta** los tres stacks completos: al arrancar el compose del Catálogo con su observabilidad (grafana, loki, promtail, jaeger, otel, prometheus) sobre MessageUcoLab completo (ollama, pulsar, grafana, loki, prometheus, otel) el motor dejó de responder (API 500) y hubo que relanzar Docker Desktop. Conjunto que sí cabe:

1. `infra.ps1 security-up` (o `docker compose --env-file lab.env -f GestioAsistenciaBackend/infra/security-baseline/compose.yaml up -d`), `docker start sql_server_asistencias`, MinIO y ClamAV.
2. MessageUcoLab mínimo: `docker start redis surrealdb pulsar api-gateway-kong messageucolab-app` (sin ollama ni observabilidad).
3. Catálogo mínimo: `docker start catalogo-parametros-redis catalogo-parametros-surrealdb catalogo-parametros-app catalogo-parametros-frontend` (sus contenedores de observabilidad quedan detenidos; el app registra `UnknownHostException: otel-collector` inofensivo).
4. Backend (`start-backend-baseline.ps1`) y frontend (`npm start`); pantallas: `security-ui` (`npm run preview`, 5175), `securityBaseline-vue` (`npm run dev`, 5173), `MessageUcolab--Frontend` (`npm run dev`, 5174).

Variables del backend (`.env` local, fuera de Git): `APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=catalogoparametros`, `APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER=messageucolab`, `CATALOGO_PARAMETROS_BASE_URL=http://localhost:8081/catalogo-parametros/api/v1`, `CATALOGO_PARAMETROS_TOKEN_ID`, `CATALOGO_PARAMETROS_SECRETO`, `CATALOGO_PARAMETROS_APPLICATION_ID`, `CATALOGO_PARAMETROS_ENVIRONMENT_ID`.

## 4. Hallazgos para los otros equipos (ver TECHNICAL_DEBT TD-086 a TD-089)

- **Seguridad:** la 0.1.11 anunciada no puede crear identidades de servicio sobre un realm persistido (falta el cliente aprovisionador); la 0.1.13 lo migra pero su entrypoint fija el puerto 8080. Nuestro compose lo resuelve con el relevo `keycloak-relay`.
- **Parámetros:** `plantilla-resources.xlsx` vacía; la imagen 0.1.7 no siembra `tipos-parametro` (lista vacía y solo lectura) y `POST /parametros` acepta un `idTipoParametro` inexistente; el valor vacío de un metadato se rechaza; el `GET /parametros` pagina a 10 por defecto.
- **Mensajes:** sin novedades; la plantilla de importación del Catálogo lleva el `applicationId` embebido (hay que generarla, o adaptarla, por aplicación).

- **Kong degradado (TD-089):** tras ~4 h de uso (contenedor con 1,6 GiB) `api-gateway-kong` dejó de aceptar conexiones nuevas desde otros contenedores; `docker restart api-gateway-kong` lo recuperó.
- **Dependencia del Catálogo con MessageUcoLab (TD-088):** el endpoint `GET /tokens/{id}/parametros` consulta mensajes en MessageUcoLab (vía Kong) antes de responder; si Kong no responde se cuelga más de 30 s en vez de devolver los parámetros sin mensajes.
- **Lectura fría del token (TD-088):** la primera lectura tarda entre 1 y 13 s; por eso el timeout del backend pasó de 3 s a 10 s y la caché sirve valores vencidos mientras refresca.

## 5. Pendiente / para revisar en pantalla

- Pantalla del Catálogo (`http://localhost:4201`) con `security-demo` o `lab-pdp-admin`: comprobar que el microfrontend administrativo cargue con el perfil asignado (validado por API, no en pantalla).
- ~~Montar el microfrontend de Parámetros en la administración de AsistenciasUCO~~ **Hecho el 2026-11-12** en el frontend,
  rama `feat/INT-002-microfrontend-parametros` (desde `origin/develop`, worktree
  `C:\Proyectos\GestionAsistencia-INT002-PRM\GestioAsistenciaFrontend`, commit `317669f`, sin push). Decisión del responsable: la
  administración de parámetros de la UI es **solo** `parametros-administration.js` del equipo de parámetros.
  - `ParametrosAdministrationComponent` (`src/app/features/parametros/parametros-administration/`, standalone, OnPush,
    signals) descarga el módulo con `import()` de URL de runtime, monta en `ngAfterViewInit`, espera `handle.ready` y
    desmonta al destruirse; estados cargando / listo / error (reintento) / sesión vencida / sin permiso / sin configurar.
  - Vive en la pestaña **Parámetros** de `AdminSystemComponent`: `/app/admin/sistema` (Sistema & Auditoría) y
    `/app/admin/configuracion/parametros` (mismo componente en modo `parametros`), ambas con `roleGuard` ADMINISTRADOR.
    Se retiraron la lista propia y `parametro-edicion-modal.component.ts`; endpoints y SP del backend siguen (TD-090).
  - Configuración por `env.js` (no quemada en código): `CATALOGO_PARAMETROS_APPLICATION_ID` (`0d24a3a4-…`, el mismo del
    `.env` del backend; sin valor por defecto, la pantalla avisa si falta), `CATALOGO_PARAMETROS_UI_URL`
    (`/parametros-ui/parametros-administration.js`) y `CATALOGO_PARAMETROS_API_BASE_URL` (`/catalogo-parametros/api/v1`).
    También en `env.template.js`, `docker-entrypoint.d/40-env-js.sh` y `.env.example`.
  - `refreshIntervalMs: 0`: leído en el bundle 1.0.0, `0` desactiva el `setInterval` (el valor por defecto es 60000, es
    decir, sondeo). Las actualizaciones llegan por SSE (`…/administracion/events`). Hallazgo para el equipo: TD-091.
  - Proxy de `ng serve`: `/catalogo-parametros` → `localhost:8081` y `/parametros-ui` → `localhost:4201`. El PDP ya
    admite `http://localhost:4200` (`PDP_CORS_ALLOWED_ORIGINS` y orígenes de retorno de `lab.env`), pero la API del
    Catálogo solo admite `FRONTEND_ALLOWED_ORIGINS=http://localhost:4201` y responde 403 de CORS al Origin 4200: el proxy
    quita `Origin`, igual que en `/messageucolab` (TD-091). El nginx de producción aún no publica estas rutas (TD-091).
  - 401 → `onAuthenticationRequired` → estado "sesión vencida", desmontaje y botón de login de Seguridad que vuelve a
    la ruta actual (mismo comportamiento que mensajes; sin redirección automática para no entrar en bucle).
  - Pruebas: `parametros-administration.component.spec.ts` (montaje ok, fallo del import, `mount` que lanza,
    `handle.ready` rechazado, 401 en carga y después, login, unmount, carreras de reintento y destrucción);
    `npm run verify` en verde (2745 pruebas, cobertura realtime 95,26 % / 86,81 %, build de producción).
  - **Validado en pantalla (2026-11-12)** con `uco-administrador` en `http://localhost:4200/app/admin/sistema` (`ng serve`
    del worktree): el micro frontend muestra «Cambios en tiempo real conectados», el módulo `Asistencias` y los 21
    parámetros de AsistenciasUCO; `GET …/administracion` 200 y SSE `…/administracion/events` abierto por el proxy. Solo
    lectura: no se editó ningún parámetro. Antes de eso, con `catalogo-parametros-app` detenido, la pantalla mostró el
    estado de error con «Reintentar» (500 del proxy), como se esperaba.
- `provision_asistencias.py verify` falla en `develop` por una ruta constante en `RecuperacionClaveController` (HU177): TD-087.
- Azure (App Configuration / Key Vault) sigue sin suscripción activa (hallazgo 9 de CULM-001); el laboratorio opera con `catalogoparametros` y `messageucolab` (contingencia Azure → código → texto del enum).
