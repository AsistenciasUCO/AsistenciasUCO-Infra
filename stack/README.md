# Contenedores por secciones (`infra.ps1 stack`)

El laboratorio completo no cabe en la VM de Docker (10 GB, `%USERPROFILE%\.wslconfig`), así que se levanta **por
secciones** o por **escenarios de prueba**. Todo está descrito en [`secciones.json`](secciones.json); el comando es
[`scripts/orchestration/stack.ps1`](../scripts/orchestration/stack.ps1).

```powershell
.\AsistenciasUCO-Infra\infra.ps1 stack list              # secciones y escenarios
.\AsistenciasUCO-Infra\infra.ps1 stack plan mensajes     # qué levantaría y cuánta memoria (no cambia nada)
.\AsistenciasUCO-Infra\infra.ps1 stack up basico         # levanta el escenario y apaga lo que no usa
.\AsistenciasUCO-Infra\infra.ps1 stack up ext-mensajes -Conservar   # agrega una sección sin apagar las demás
.\AsistenciasUCO-Infra\infra.ps1 stack status            # estado y memoria por sección
.\AsistenciasUCO-Infra\infra.ps1 stack down              # todo menos asis-datos (nunca borra volúmenes)
.\AsistenciasUCO-Infra\infra.ps1 stack build             # imágenes asistencias-backend/frontend:develop
.\AsistenciasUCO-Infra\infra.ps1 stack build notificaciones   # imagen notificaciones-uco:0.1.1 (componente propio)
.\AsistenciasUCO-Infra\infra.ps1 stack up asis-app -Conservar       # recrea solo la app tras un build; se configura con lo que ya está arriba
```

## Secciones

Docker Desktop agrupa los contenedores por proyecto: `asis-*` es de Asistencias UCO y `ext-*` son componentes de los
otros equipos.

| Sección | Qué tiene | Memoria | Cuándo |
| :--- | :--- | ---: | :--- |
| `asis-datos` | SQL Server (`sql_server_asistencias`) y MinIO | 2,5 GB | Siempre (único con reinicio automático) |
| `ext-seguridad` | Seguridad 0.1.13 del equipo (Keycloak, PDP, PEP, OPA) y su consola de administración en `5175` | 1,6 GB | Casi siempre |
| `ext-mensajes` | MessageUcoLab 0.3.0 (Kong, Pulsar, app; sin observabilidad ni Ollama) | 3,3 GB | Pruebas de mensajes |
| `ext-parametros` | Catálogo de Parámetros 0.1.17 y su microfrontend 0.1.16, con su Pulsar propio (`pulsar-parametros`: consulta M2M y eventos de cambios) | 1,5 GB | Pruebas de parámetros |
| `ext-notificaciones` | Servicio de Notificaciones UCO 0.1.1 (componente propio, `GestioAsistenciaBackend/servicios/notificaciones`): correos con plantillas y cola en `notificacionesdb` | 0,45 GB | Con `asis-app` (en todos los escenarios salvo `minimo`) |
| `asis-antivirus` | ClamAV | 1,3 GB | Pruebas de soportes |
| `asis-cache` | Redis 7.4 (REDIS-001): caché de consultas compartida, límite del QR y tiempo real entre réplicas. Sin persistencia, tope 128 MB | 0,16 GB | Pruebas de caché y de réplicas |
| `asis-obs` | Grafana, Prometheus, Loki, Tempo, Alloy | 0,9 GB | Diagnóstico |
| `asis-contingencia` | Keycloak propio (realm `asistencias-uco`) | 0,9 GB | **Solo emergencias**, si falla la Seguridad del equipo |
| `asis-app` | Backend y Frontend (imágenes de `develop`) | 1,2 GB | Pruebas funcionales |

`ext-mensajes` y `ext-parametros` requieren `ext-seguridad` y `ext-notificaciones` requiere `asis-datos` (se agregan solos). `asis-contingencia` y `ext-parametros` no
pueden convivir (ambos usan el puerto 8081 del PC).

## Escenarios

| Escenario | Secciones | Pruebas |
| :--- | :--- | :--- |
| `minimo` | datos | Gate de BD |
| `basico` | datos, seguridad, notificaciones, app | HU de los 5 roles (mensajes y parámetros desde la BD) |
| `mensajes` | `basico` + mensajes | Catálogo de mensajes, avisos → BD, textos `UI###` |
| `parametros` | `basico` + parámetros | Catálogo de Parámetros |
| `completo` | `basico` + mensajes + parámetros | Flujos completos. Con el Pulsar propio del Catálogo 0.1.17 estima 10,55 GB y supera el límite de 9,7 GB: requiere `-ForzarMemoria` (ver abajo) |
| `soportes` | `basico` + antivirus | Adjuntos |
| `cache` | `basico` + caché | Caché Redis (portal, indicadores, catálogos), límite del QR y tiempo real entre réplicas |
| `observabilidad` | `basico` + obs | Trazas y logs por `correlationId` |
| `contingencia` | datos, contingencia, app | Arranque sin la Seguridad del equipo |

**Límite de memoria.** `stack up` se niega a levantar un objetivo cuya memoria estimada supere `limiteMemoriaMb`
(9700 MB en [`secciones.json`](secciones.json), pensado para la VM de 10 GB). Desde que `ext-parametros` trae su Pulsar
(1,5 GB), `completo` estima 10 550 MB. Para usarlo: suba la VM (`[wsl2] memory=12GB` en `%USERPROFILE%\.wslconfig`, si el PC
tiene la RAM) y levante con `.\infra.ps1 stack up completo -ForzarMemoria`. Sin más memoria, Docker puede matar contenedores;
en ese caso use `mensajes` y `parametros` por separado.

Para dejar la base con los datos de prueba variados (73 usuarios, todos los roles y casos preparados) después de
levantar un escenario: `.\infra.ps1 datos-prueba cargar -Yes`. Guía completa: [docs/runbooks/PRUEBAS_LOCALES.md](../docs/runbooks/PRUEBAS_LOCALES.md).

## Configuración automática de `asis-app`

Con `asis-app`, `stack up` genera `stack/generado/backend.env` y `frontend.env` (fuera de Git: llevan secretos) a partir
del `.env` del Backend, de `lab.env` y de los `env.js` locales del Frontend, según lo que esté arriba:

| Si está arriba… | El Backend usa… |
| :--- | :--- |
| `ext-seguridad` | proveedor `baseline` (PEP/PDP/Keycloak dentro de `asis-red`) |
| `asis-contingencia` (sin `ext-seguridad`) | proveedor `legacy` |
| `ext-mensajes` | catálogo de mensajes `messageucolab` (Kong y Pulsar por `asis-red`); si no, `sqlserver` y sin avisos |
| `ext-parametros` | catálogo de parámetros `catalogoparametros`; si no, `sqlserver` |
| `asis-obs` | exporta trazas a Alloy |
| `asis-cache` | `APP_ADAPTERS_CACHE_PROVIDER=redis`, `APP_ADAPTERS_REALTIME_PROVIDER=redis-sse` y `REDIS_HOST=redis`; si no, caché en memoria (`local`) y SSE local (`local-sse`) |
| `ext-notificaciones` | recibe `NOTIFICACIONES_SERVICE_URL=http://ext-notificaciones-servicio:8080` y `NOTIFICACIONES_API_KEY` (el Backend los usa desde la fase F4; hasta entonces sigue con su SMTP propio) |

El Frontend activa los textos del catálogo (`MENSAJES_UI_DESDE_CATALOGO`) solo con `ext-mensajes`.

## Validación de los escenarios (2026-11-15)

| Escenario | Resultado |
| :--- | :--- |
| `basico` | API 200 para los 5 roles y 401 sin token; login real en la SPA del contenedor |
| `mensajes` | Suscripción a Pulsar, reconciliación de 482 mensajes (0 fallidos), cambio en MessageUcoLab → BD en 2,8 s, textos `UI###` y alertas con texto |
| `parametros` | El Backend lee el Catálogo (un valor distinto solo en `dbo.CatalogoParametro` no se usa); microfrontend y API por el proxy de la SPA |
| `soportes` | Subida → ClamAV (`CLEAN`) → MinIO → descarga idéntica; ClamAV detecta EICAR |
| `observabilidad` | Trazas en Tempo, logs en Loki por `correlationId`, métricas en Prometheus (`up`) |
| `contingencia` | Token del Keycloak propio (`iss` `localhost:8081`) aceptado por el Backend en contenedor; SPA en modo `legacy` |

Ajustes que salieron de estas pruebas:

* `ext-mensajes` usa su propio volumen de Pulsar (`ext-mensajes-pulsar-data`): el anterior quedó con ledgers que el bookie ya no
  podía escribir (`Not enough non-faulty bookies available`, caso descrito en el README del kit). El volumen viejo se conserva.
* La salud de `ext-mensajes` incluye `brokers/health` de Pulsar y la de `ext-parametros` el `actuator/health` del Catálogo: la app
  no arranca hasta que estén listos (antes el Backend se suscribía o consultaba demasiado pronto).
* `asis-app` monta `GestioAsistenciaBackend/infra/observability/logs` (Alloy → Loki, archivo `backend-contenedor.jsonl`) y publica
  el puerto de gestión `8090` solo en `127.0.0.1`; el Backend lo abre (`MANAGEMENT_SERVER_ADDRESS=0.0.0.0`) solo con `asis-obs`.
* El Backend reintenta la suscripción a Pulsar si falla (PR del Backend `fix/int003-reintento-suscripcion-pulsar`).

## Catálogo de Parámetros 0.1.17: M2M y eventos (INT-004)

`ext-parametros` levanta además el broker propio del Catálogo (`ext-parametros-pulsar`, alias `pulsar-parametros` en `asis-red`).

| Qué | Dirección |
| :--- | :--- |
| API del Catálogo desde el Backend en contenedor | `http://ext-parametros-app:8080/catalogo-parametros/api/v1` |
| Consulta M2M | `GET …/parametros/consulta/m2m[?nombre=]` con `client_credentials` de la identidad `asistencias-uco → Catálogo` |
| Pulsar desde el Backend en contenedor | `pulsar://pulsar-parametros:6650` (listener `internal`; `localhost:6652` no sirve dentro del contenedor porque el broker se anuncia con ese nombre) |
| Pulsar desde el PC (Backend fuera de Docker) | `pulsar://localhost:6652`; administración `http://localhost:8082` |
| Topic y suscripción | `persistent://public/default/catalogo-parametros-events-<client_id>` y `asistencias-uco-backend` |

`stack up` pasa al Backend `CATALOGO_PARAMETROS_M2M_TOKEN_URI`, `CATALOGO_PARAMETROS_PULSAR_URL`, `CATALOGO_PARAMETROS_EVENTS_TOPIC` y
`CATALOGO_PARAMETROS_EVENTS_SUBSCRIPTION`; `CATALOGO_PARAMETROS_M2M_CLIENT_ID` y `…_CLIENT_SECRET` salen del `.env` del Backend
(se crean una vez en Seguridad: ver [INT-004](../docs/work-items/INT-004-parametros-m2m-eventos/ESTADO.md)).
El kit trae `PULSAR_ENABLED=false` (consumo de los eventos de MessageUcoLab) mientras `ext-mensajes` no esté arriba (necesita `doppler login`);
la publicación de eventos del Catálogo sigue activa. Consumo de memoria medido de la sección: ~1,45 GB.

## Cómo está armado

* Cada sección aplica un archivo propio de [`secciones/`](secciones/) **sobre el compose original** (el del Backend o el kit
  del otro equipo, que no se modifica): renombra contenedores, conecta a la red compartida `asis-red` solo los puntos de
  entrada (SQL, MinIO, ClamAV, Keycloak como `keycloak.localhost`, PDP, PEP, Kong, Pulsar, Catálogo, Alloy) y declara los
  **volúmenes existentes como externos** (no se pierden datos y `down -v` no los borra). Toda red o volumen
  `external: true` de `secciones/` debe estar en `redesExternas` o `volumenesExternos` de `secciones.json`: `stack up` los crea
  vacíos si faltan (PC nuevo); si no está en la lista, `docker compose up` falla con «declared as external, but could not be found».
* `asis-app` vive en [`asis-app.compose.yml`](asis-app.compose.yml).
* Al levantar una sección se detienen los contenedores de su proyecto anterior (`asistencias-security-lab`, `messageucolab`,
  `catalogo-parametros`, …), que usan los mismos puertos. Esos contenedores viejos no se borran; quedan sin reinicio automático.
* `ext-seguridad` incluye la **consola de seguridad** (`ext-seguridad-consola`, nginx en `127.0.0.1:5175`): sirve en solo
  lectura el `dist` ya construido de `Complementos/Seguridad/security-ui` con CORS abierto, como `vite preview`. Es lo que
  la SPA carga en «Seguridad UCO» (asignación de roles); ya no hace falta `npm run preview`. Si hay un `vite preview` manual
  en el 5175, detenerlo antes del `stack up` (el puerto quedaría ocupado). Si el equipo de Seguridad publica una versión
  nueva del micro frontend, basta con actualizar ese `dist` (`npm run build` en el componente) y recargar la página.
* `stack/.env` (fuera de Git) lleva `MSSQL_SA_PASSWORD`; plantilla en [`.env.example`](.env.example). `stack up` agrega ahí, una sola
  vez, `NOTIFICACIONES_API_KEY` y `NOTIFICACIONES_DB_PASSWORD` (generadas al azar; nunca se imprimen).

## `ext-notificaciones` (Servicio de Notificaciones UCO)

Componente propio versionado en el repo del Backend, `GestioAsistenciaBackend/servicios/notificaciones` (hasta el mono repo;
el checkout del Backend debe estar en `develop`). Un solo contenedor,
`ext-notificaciones-servicio`, en `asis-red` (`http://ext-notificaciones-servicio:8080`; en el PC `http://localhost:18090`).

```powershell
.\AsistenciasUCO-Infra\infra.ps1 stack build notificaciones     # una vez (o al cambiar el código): notificaciones-uco:0.1.1
.\AsistenciasUCO-Infra\infra.ps1 stack up basico                # o cualquier escenario con asis-app
```

Antes de levantar el contenedor, `stack up` (función `Initialize-Notificaciones` de `stack.ps1`):

1. Genera `NOTIFICACIONES_API_KEY` y `NOTIFICACIONES_DB_PASSWORD` en `stack/.env` si no existen.
2. Escribe `GestioAsistenciaBackend/servicios/notificaciones/notificaciones-local/.env` (fuera de Git: `.env` está ignorado
   en `servicios/notificaciones/.gitignore`) desde su `.env.example`, con esos secretos y los `SMTP_NOTIFICATION_*` del `.env` del checkout del Backend
   (mismos nombres, incluido el modo de pruebas que redirige todo al buzón de prueba). Canal `smtp`. Esas variables SMTP
   llegan **solo** a este `.env`: el Backend ya no las lee y `stack/generado/backend.env` las omite (recibe
   `OUTBOX_NOTIFICATION_SENDER=servicio`, `NOTIFICACIONES_PLATFORM_URL` y `NOTIFICACIONES_REQUIRE_CONFIRMED_EMAIL`, tomadas de
   `SMTP_NOTIFICATION_PLATFORM_URL`/`SMTP_NOTIFICATION_REQUIRE_CONFIRMED_EMAIL` del `.env` fuente si aún usa los nombres viejos).
3. Crea de forma idempotente la base `notificacionesdb` y su login en `sql_server_asistencias` (`scripts/crear-bd.ps1` del
   componente; las claves viajan por el entorno del proceso, no por argumentos).

La salud es el contenedor (`readiness`) y `GET http://localhost:18090/actuator/health`. El Backend recibe
`NOTIFICACIONES_SERVICE_URL` y `NOTIFICACIONES_API_KEY` en `stack/generado/backend.env`. Contrato: [docs/contracts/notificaciones](../docs/contracts/notificaciones/NOTIFICACIONES_CONTRACT.md);
`infra.ps1 verify` comprueba su hash y que la copia de Infra sea idéntica a la del componente. Deuda: TD-124 (`X-Api-Key` → OAuth2).
