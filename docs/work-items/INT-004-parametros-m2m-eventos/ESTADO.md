# INT-004 — Catálogo de Parámetros 0.1.17: consulta M2M y eventos Pulsar (fase Infra + laboratorio + Seguridad)

> Fecha: 2026-11-22. Rama de Infra: `feat/p2-revision-final` (solo commits locales). Plan general: `docs/PLAN_INT004_PARAMETROS_M2M_EVENTOS.md` (raíz del workspace).
> Continúa [INT-002](../INT-002-complementos-seguridad-mensajes-parametros/ESTADO.md) y [INT-003](../INT-003-eventos-complementos/ESTADO.md).
> Esta fase no toca código de Backend, BD ni Frontend (otra fase). La guía del equipo de Parámetros (`GUIA_PARA_IA.md`) se tomó como dato técnico.

## 1. Resultado

| Qué | Estado |
| :--- | :--- |
| Kit `Complementos/CatalogoParametros/Catalogo-Parametros` | Compose, `.env.example`, `plantilla-resources.xlsx` y `GUIA_PARA_IA.md` de la entrega 2026-11-22. Imágenes `simon4219/catalogo-parametros:0.1.17` y `…-frontend:0.1.16`; broker propio `pulsar-parametros` (`apachepulsar/pulsar:3.2.2`). Copia del kit anterior en `Catalogo-Parametros-0.1.7-respaldo`; el `.env` anterior quedó como `.env.bak-0.1.7` (no versionado, con secretos). |
| Sección `ext-parametros` | `stack/secciones.json` (memoria 600 → 1500 MB; se mide ~1,45 GB: Pulsar 845 MB, app 456 MB, SurrealDB 104 MB), `stack/secciones/ext-parametros.yml` y `stack.ps1`. El escenario `parametros` (datos, seguridad, parámetros, notificaciones, app) no levanta ClamAV ni observabilidad. |
| Laboratorio | Backend del Catálogo `UP`; frontend `4201` 200; `/parametros-ui/parametros-administration.js` 200; `brokers/health` `ok`; log `[CATALOGO-PULSAR] Publicador listo con prefijo persistent://public/default/catalogo-parametros-events`. |
| Seguridad (PDP) | Recursos de la plantilla registrados en `Catalogo`, rol técnico `PARAMETROS_CONSUMER` (solo `GET …/parametros/consulta/m2m`), identidad de servicio `asistencias-uco-a-catalogo-parametros-dev` aprobada. |
| Catálogo | Identidad asociada a `AsistenciasUCO` / ambiente **Desarrollo**. Contrato M2M y evento Pulsar probados (ver §5). |

## 2. Cambios en el kit y en la sección

* `.env` del kit generado con `int004/kit_env.py` (ver §7) desde `.env.example` + valores del laboratorio:
  `PEP_REGISTRATION_TOKEN`, `KEYCLOAK_TOKEN_URI` e identidad `ORIGIN_TO_DESTINATION_*` (Catálogo → MessageUcoLab) salen del `.env` anterior dentro del proceso; los `AZURE_*` quedan comentados (Key Vault apagado). No se copió el `.env` del equipo de Parámetros.
* **`PULSAR_ENABLED=false`** (consumo de MessageUcoLab): el escenario `mensajes` necesita `doppler login` (cuenta personal del responsable) y MessageUcoLab no está arriba. El Catálogo solo pierde la sincronización de sus propios mensajes. La **publicación** queda activa (`PULSAR_PUBLISH_ENABLED=true`). Con MessageUcoLab arriba: `kit_env.py --pulsar-mensajes` y `stack up completo` (`PULSAR_URL=pulsar://host.docker.internal:6800`).
* `ext-parametros.yml`:
  * `depends_on: !override` de `app`: el compose del equipo lo hace depender de `otel-collector` (y este de `jaeger`), con lo que `up app` arrancaría su observabilidad completa (TD-128). Solo se conservan `surrealdb`, `redis` y `pulsar-parametros`. El app registra un `UnknownHostException` de `otel-collector` (inofensivo, igual que con 0.1.7).
  * `pulsar-parametros` se renombra a `ext-parametros-pulsar` y se une a `asis-red` con el alias `pulsar-parametros` (ver §6); volúmenes `catalogo-parametros_pulsar-parametros-data/-conf` externos (también en `volumenesExternos` de `secciones.json`, igual que los de Redis y SurrealDB, para que un laboratorio nuevo los cree).
* Salud de la sección: `actuator/health` de `8081` y `brokers/health` de `8082`.

## 3. Seguridad (PDP del laboratorio)

Ejecutado con `int004_pdp.py --aplicar` (idempotente; usa la sesión de `lab-pdp-admin`, que administra `Catalogo` y `asistencias-uco`; `security-demo` ya no administra `Catalogo`: 403 `NOT_AUTHORIZED_TO_ADMINISTER`).

* Aplicación `Catalogo` en el PDP: `a0f088c5-c8bf-4a40-bda4-ec0a618776c4`. La plantilla tiene 71 filas; el PDP tenía 104 recursos y se registraron 7 nuevos (los del libro 0.1.7 que ya no están en la plantilla, como `tokens` y `estados-token`, se dejan).
  Los `…/events` y las rutas con `{idAplicacion}` no se pudieron registrar: el PDP responde 409 `PROTECTED_RESOURCE_ALREADY_EXISTS` porque una plantilla ya registrada (`…/aplicaciones/{id}`, `…/{id}/administracion`) las cubre. Se omiten, sin pérdida de cobertura.
* Rol `ADMINISTRADOR_PARAMETROS` (`20be8688…`): se le concedieron los recursos nuevos de administración (`identidades-servicio`, `avisos`, `mensajes/{codigo}`, `metadatos/todos-los-ambientes`, `GET /parametros`, `GET /tipos-metadato/{id}`). **No** se le dio `DELETE …/aplicaciones/{id}` (no lo tenía) ni la consulta M2M.
* Rol técnico `PARAMETROS_CONSUMER` (`6499b2dc-f5c2-44d4-adf3-00e005256e9d`) en `Catalogo`: solo `GET /catalogo-parametros/api/v1/parametros/consulta/m2m`.
* Identidad de servicio de la aplicación `asistencias-uco` (`e4e258be-5946-4ed2-b9ec-d7f8c6437ba2`):
  `client_id = svc-e4e258be-5946-4ed2-b9ec-d7f8c6437ba2-asistencias-uco-a-catalogo-parametros-dev`; solicitud de acceso al rol técnico `3eb73e4d-5bb3-4a6a-aadc-ce2823547673` **aprobada**. El secreto se escribió solo en `GestioAsistenciaBackend/.env` (`CATALOGO_PARAMETROS_M2M_CLIENT_ID`, `CATALOGO_PARAMETROS_M2M_CLIENT_SECRET`, `CATALOGO_PARAMETROS_M2M_TOKEN_URI`); nunca se imprimió.
* **Incidente (TD-129):** el primer intento de crear la identidad respondió 500 (`TimeoutException` de 3000 ms en el PDP al crear el cliente en Keycloak) y dejó el cliente en Keycloak sin fila en el PDP (mismo patrón que la identidad `…-dev` de INT-002). Aquí se pudo reintentar porque el cliente huérfano lo creó este mismo intento: se borró de Keycloak por el Admin REST (`int004_kc.py --borrar-huerfano`) y la segunda creación funcionó.

## 4. Catálogo: datos y asociación

* Las ids de aplicación se conservaron (el volumen de SurrealDB persistió): organización `UCO` `39501a2c-bdf6-4fe2-8588-2f6202f68d16`, aplicación `AsistenciasUCO` `0d24a3a4-8c9d-4ac3-9b1a-a97ef16ea186`, módulo `Asistencias`, funcionalidad `Parametros de negocio`, 21 parámetros.
* **El ambiente `Develop` (`36ddaf78-f683-4098-b602-92a46dd350ea`) ya no existe** (TD-127): en 0.1.17 los ambientes son un catálogo fijo (`…0010` Producción, **`00000000-0000-0000-0000-000000000011` Desarrollo**, `…0012` Pruebas) y los estados de metadato-ambiente también (`…0020` Activo, `…0021` Inactivo). Los 20 metadatos y 20 metadatos-ambiente sembrados en INT-002 apuntaban a ids viejos (`GET /ambientes/36ddaf78…` → 404). No se perdieron datos, pero la consulta M2M no habría devuelto nada. Se migraron con `int004_catalogo.py --aplicar` (PUT de `idAmbiente` → Desarrollo y estado → Activo, valores intactos).
* Identidad asociada: `POST /aplicaciones/{id}/identidades-servicio {clientId, idAmbiente}` → 201, id `a073aead-1558-4fb6-bdf9-2b006563f142`.
* `GestioAsistenciaBackend/.env`: `CATALOGO_PARAMETROS_ENVIRONMENT_ID` pasó a `…0011` (el adaptador M2M no lo envía; la variable la lee el adaptador anterior).

## 5. Contrato probado (`int004_contrato.py --evento`)

| Prueba | Resultado |
| :--- | :--- |
| `client_credentials` con la identidad | 200 |
| `GET /parametros/consulta/m2m` | 200: `aplicacion` (AsistenciasUCO), `ambiente` (`…0011` Desarrollo), `mensajes`, `parametros` (20; el 21.º, `RED.PROXIES_CONFIABLES`, no tiene metadato) |
| Forma de cada parámetro | `parametro`, `tipoParametro`, `modulo`, `funcionalidad`, `metadatos`, `configuracionAmbiente` |
| `?nombre=ARCHIVOS.LIMITE_SUBIDAS_POR_MINUTO` (y en minúsculas) | 200, 1 parámetro |
| `?nombre=NO.EXISTE.INT004` | 200, `parametros: []` |
| Sin token / token inválido | 401 |
| Evento (cambio de un metadato inocuo por la API del Catálogo y restauración) | Llegó al topic en ~1 s; `schemaVersion: 3`. Muestra: `int004/evento-ejemplo.json` (§7). El metadato se restauró (`valor` `X`). |

El evento de un cambio de **metadato** trae `eventType: MetadataUpdated`, `resourceName` = nombre del parámetro (`RECLAMO.ESTADO_RETIRADO`), `resourceValue` = nuevo valor, `resourceId` = id del metadato, `parentId` = id del parámetro, `applicationId` y `environmentId`.
Por cada `PUT` se publica un evento, también al restaurar (2 en total).

## 6. Pulsar para el Backend

* **Dirección desde el contenedor `asis-app-backend` (red `asis-red`): `pulsar://pulsar-parametros:6650`.** Se unió `ext-parametros-pulsar` a `asis-red` con el alias `pulsar-parametros`. No sirve `host.docker.internal:6652`: el puerto 6652 es el listener `external`, que anuncia el broker como `localhost:6652` (el cliente, dentro del contenedor, intentaría conectarse a sí mismo); el 6650 es el listener `internal`, que se anuncia como `pulsar-parametros:6650`, nombre que ahora resuelve en `asis-red`. Probado con `pulsar-client consume` desde un contenedor de `asis-red`.
* Un Backend fuera de Docker (checkout local) usa `pulsar://localhost:6652`; administración `http://localhost:8082`.
* Topic: `persistent://public/default/catalogo-parametros-events-<client_id>` (con el `client_id` de §3). Suscripción durable sugerida: `asistencias-uco-backend` (tipo Shared según la guía del equipo; el Backend debe confirmar tras procesar).
* Variables que `stack.ps1` escribe en `stack/generado/backend.env` con `ext-parametros` arriba: `CATALOGO_PARAMETROS_BASE_URL=http://ext-parametros-app:8080/catalogo-parametros/api/v1`, `CATALOGO_PARAMETROS_M2M_TOKEN_URI`, `CATALOGO_PARAMETROS_PULSAR_URL`, `CATALOGO_PARAMETROS_EVENTS_TOPIC`, `CATALOGO_PARAMETROS_EVENTS_SUBSCRIPTION`. `CATALOGO_PARAMETROS_M2M_CLIENT_ID` y `…_CLIENT_SECRET` pasan desde `GestioAsistenciaBackend/.env` (el secreto no está escrito en Git ni en `stack.ps1`).
* `stack up parametros` con el Backend actual (adaptador de token propio): arranca sano y usa los valores por defecto (`El Catalogo de Parametros respondio HTTP 401`: ya no existe `/tokens/{id}/parametros`). Es esperado hasta la fase de Backend.

## 7. Cómo repetirlo

Scripts de la sesión (Python de vcpkg con `-X utf8 -I`; carpeta `scratchpad\int004` de la sesión de Claude Code; no versionados porque llevan rutas locales y leen secretos del laboratorio): `kit_env.py`, `int004_pdp.py`, `int004_catalogo.py`, `int004_contrato.py`, `int004_cat.py` (sesión web contra el Catálogo), `int004_kc.py` (limpieza de clientes huérfanos), `evento-ejemplo.json` (evento capturado, sin secretos).

1. Kit: copiar compose, `.env.example`, `plantilla-resources.xlsx` y la guía a `Complementos/CatalogoParametros/Catalogo-Parametros`; `kit_env.py` genera el `.env` (requiere `.env.bak-0.1.7`).
2. `.\AsistenciasUCO-Infra\infra.ps1 stack up parametros` (con `$env:ASISTENCIAS_PYTHON`).
3. `int004_pdp.py --aplicar` (recursos, rol técnico, identidad, solicitud, aprobación, token), luego `int004_catalogo.py --aplicar` (ambiente Desarrollo y asociación), luego `int004_contrato.py --evento`.
4. `stack up parametros` otra vez para regenerar `backend.env` con el `client_id`.

## 8. Pendiente y hallazgos

* TD-127 (ambientes y estados reasignados sin migración), TD-128 (compose del Catálogo con observabilidad obligatoria) y TD-129 (Seguridad: timeout al crear identidades): los dos primeros son del equipo de Parámetros y el tercero del de Seguridad; se reportan, no se parchan.
* `scripts/tests/test_catalogo_parametros.ps1` sigue en el modelo de token propio y fallará hasta migrarlo a M2M (fase Backend/pruebas).
* `provision_asistencias.py verify` (paso del `stack up`) informa `SOBRA=141` con `FALTA=0`: concesiones del PDP que el catálogo de endpoints del Backend ya no declara; no es de esta fase.

## 9. Validación en vivo con el Backend (2026-11-23) y datos de prueba

Escenario `parametros`, Backend con proveedor `catalogoparametros` suscrito al topic, BD recargada con la migración 73.

* **Hallazgo y corrección (datos de prueba).** `01_estructura.sql` fija `RED.CIDRS_CAMPUS = '127.0.0.1/32,::1/128,172.16.0.0/12,192.168.0.0/16'` solo en la BD para que el PIN/QR funcione desde las redes de Docker. Con el Catálogo como fuente de verdad, la reconciliación del arranque lo sobrescribía con el valor del Catálogo (solo loopback) y el estudiante recibía 403 `AQR_002` ("Debes estar conectado a la red Wi-Fi del campus").
  Corrección: `scripts/database/sincronizar_catalogo_parametros.py` lee los `UPDATE dbo.CatalogoParametro` de los datos de prueba y los empuja al Catálogo (AsistenciasUCO / Desarrollo) por la API administrativa con la sesión de `lab-pdp-admin` (secretos de `lab.env`, nunca impresos). `infra.ps1 datos-prueba cargar` lo ejecuta al final si `ext-parametros-app` corre; suelto: `infra.ps1 datos-prueba catalogo`. Idempotente. El Catálogo del laboratorio ya quedó con el valor.
* **Flujo de eventos verificado de punta a punta** (Catálogo -> Pulsar -> Backend -> `dbo.CatalogoParametro` y `dbo.SincronizacionParametroExterno`): `APLICADO` en unos segundos; el mismo valor repetido da `SIN_CAMBIOS` sin tocar `fechaModificacion`; la repetición de eventos (`reset-cursor` de la suscripción) no reescribe nada (los `idEvento` ya vistos se omiten); un entero negativo y un booleano inválido dan `RECHAZADO` y la BD conserva el valor.
* **Resiliencia.** Con `ext-parametros-app` detenido el Backend sigue sano y atendiendo; pasado el TTL de 5 min conserva los valores vencidos (`se conservan los valores vencidos y no se reintenta durante 30 s`) y los parámetros sin caché usan el valor por defecto (DEC-018). Al arrancar de nuevo el Catálogo, el siguiente evento se aplica sin reiniciar el Backend. `docker restart ext-parametros-pulsar`: el consumidor se reengancha solo y el cambio posterior se entrega en ~5 s.
* **Microfrontend.** `/app/admin/configuracion/parametros` carga con el administrador de Asistencias sin otro inicio de sesión (`/parametros-ui/parametros-administration.js` y `GET /catalogo-parametros/api/v1/aplicaciones/{id}/administracion` responden 200 por el mismo origen).
* **Pruebas.** `scripts/tests/test_catalogo_parametros.ps1` migrada al modelo M2M (token `client_credentials` con las variables `CATALOGO_PARAMETROS_M2M_*` del `.env` del Backend, contrato `consulta/m2m`, 401/403, regla real de registro QR y flujo por eventos con restauración); 22 comprobaciones en verde. El actuator del Backend (8090) solo escucha en loopback dentro del contenedor sin `asis-obs`; la prueba lo consulta con `docker exec`.
* **Hallazgos para otros equipos (no se parchan aquí):** (Backend) un valor no válido de tipo CIDR (`RED.CIDRS_CAMPUS = 'no-es-un-cidr'`) se **aplica** a la BD (`APLICADO`): solo se validan enteros y booleanos; (Parámetros) el microfrontend muestra "Ambiente autorizado: Producción" aunque la aplicación opera en Desarrollo (cosmético a verificar) y un banner transitorio "Reconectando eventos" tras reiniciar su Pulsar.
