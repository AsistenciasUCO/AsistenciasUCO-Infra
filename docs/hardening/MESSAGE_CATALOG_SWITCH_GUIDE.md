# Guía Operativa: Switch del Catálogo de Mensajes (Azure App Configuration vs MessageUcoLab)

> **Ámbito:** Infraestructura Transversal y Backend Spring Boot  
> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Versión:** 1.0.0  
> **Fecha:** Noviembre 2026  
> **Relacionado:** [`SECURITY_SWITCH_GUIDE.md`](SECURITY_SWITCH_GUIDE.md), [`MESSAGEUCOLAB_INTEGRATION.md`](../governance/MESSAGEUCOLAB_INTEGRATION.md)

---

## 1. Propósito

El Backend resuelve los mensajes institucionales (`mensajeUsuario`) a través del puerto neutral `MessageCatalogPort`.
Existen tres implementaciones seleccionables **al arrancar** con un solo selector, sin tocar Domain, Application ni
controladores (patrón *Composition Root* de [`adapter-composition-standard.md`](../../../GestioAsistenciaBackend/docs/architecture/adapter-composition-standard.md)):

| Provider (`app.adapters.message-catalog.provider`) | Qué es | Estado |
| :--- | :--- | :--- |
| `azure` | Azure App Configuration (`messages:user:<CODIGO>`, label `es`) con caché Caffeine 30 min | **Predeterminado / ACTIVO** |
| `messageucolab` | Componente MessageUcoLab del equipo de mensajería, vía `messageucolab-spring-boot-starter` | **Alterno (switch)** |
| `sqlserver` | `MessageCatalogJpaRepository` (tablas `CatalogoMensajeUsuario/Tecnico`) | Legacy / pruebas de integración |

> El componente MessageUcoLab es propiedad de otro equipo (`Complementos/CatalogoMensajes`). **No se modifica**:
> los hallazgos se documentan en [`FINDINGS_FOR_MESSAGES_TEAM.md`](../work-items/backend/MSG-001-messageucolab-catalog-switch/FINDINGS_FOR_MESSAGES_TEAM.md).

---

## 2. Uso mediante el CLI maestro (`infra.ps1`)

### A. Consultar el modo activo
```powershell
.\AsistenciasUCO-Infra\infra.ps1 messages-switch -Mode status
```

### B. Volver a Azure (predeterminado)
```powershell
.\AsistenciasUCO-Infra\infra.ps1 messages-switch -Mode azure
```

### C. Cambiar a MessageUcoLab
```powershell
.\AsistenciasUCO-Infra\infra.ps1 messages-up                       # levanta el componente (requiere Doppler)
.\AsistenciasUCO-Infra\infra.ps1 messages-switch -Mode messageucolab `
    -ClientId svc-...-asistencias-dev                              # identidad de servicio (INT-003, MessageUcoLab 0.3.0)
```

Después de cualquier cambio **reinicia el Backend** (el provider se elige al construir el contexto de Spring).

| Comando | Acción |
| :--- | :--- |
| `messages-up` | Levanta MessageUcoLab (`docker compose -p messageucolab`, secretos vía `doppler run --`) |
| `messages-down` | Detiene sin borrar volúmenes. **Nunca** `down -v`: borra todos los mensajes |
| `messages-status` | Contenedores + `http://localhost:8000/actuator/health` |
| `messages-ui` | Levanta y lanza la pantalla de MessageUcoLab (`http://localhost:5174`) |
| `messages-switch` | Cambia/consulta el provider en `GestioAsistenciaBackend/.env` |

---

## 3. Variables del Backend

| Variable (`.env` Backend) | Valor por defecto | Descripción |
| :--- | :--- | :--- |
| `APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER` | `azure` | Selector: `azure` \| `messageucolab` \| `sqlserver` |
| `MESSAGEUCOLAB_URL` | `http://localhost:8000` | Gateway Kong de MessageUcoLab |
| `MESSAGEUCOLAB_TOKEN_URI` | `http://localhost:19090/realms/security-baseline/protocol/openid-connect/token` | Token `client_credentials` de la identidad de servicio (Keycloak del componente de Seguridad) |
| `MESSAGEUCOLAB_CLIENT_ID` | *(vacío)* | Client ID de la identidad de servicio (`svc-...`); con 0.3.0 reemplaza a `MESSAGEUCOLAB_APPLICATION_ID`/`_ENVIRONMENT_ID`, que ya no existen |
| `MESSAGEUCOLAB_CLIENT_SECRET` | *(vacío)* | **Secreto** de la identidad. Baúl: `asistencias-messageucolab-client-secret`; en local, solo en el `.env` (nunca en Git). Sin él el Backend no arranca en modo `messageucolab` |
| `MESSAGEUCOLAB_EVENTS_ENABLED` | `true` | Suscripción a los avisos de cambio por Pulsar (INT-003) |
| `MESSAGEUCOLAB_PULSAR_URL` | `pulsar://localhost:6800` | Broker del kit (puerto externo publicado hacia el PC; desde Docker es `pulsar://pulsar:6650`) |
| `MESSAGEUCOLAB_RECONCILE_ON_STARTUP` | `true` | Al arrancar copia en la BD todos los textos vigentes (cubre avisos perdidos) |
| `MESSAGEUCOLAB_TIMEOUT` | `3s` | Espera máxima por mensaje (el puerto es síncrono) |
| `MESSAGEUCOLAB_CACHE_TTL` | `5m` | Caché local de aciertos; `0` la desactiva. El gateway limita a 120 peticiones/min por IP |
| `MESSAGEUCOLAB_FALLBACK` | `azure` | Contingencia si MessageUcoLab falla o no tiene el código: `azure` \| `none` |
| `MESSAGEUCOLAB_CODE_PREFIX` | `MSG_` | Prefijo que MessageUcoLab antepone a todo código |
| `app.providers.messageucolab.code-aliases."[<CODIGO>]"` | 27 alias `ERR###`/`SUC###` ya declarados en `application.yml` | Alias corto (≤10) para los códigos canónicos más largos; ver §7 |

Salvo `MESSAGEUCOLAB_CLIENT_SECRET`, ninguna de estas variables es un secreto. Los secretos del componente (`SURREALDBPASSWORD`, `REDISPASSWORD`,
`GF_SECURITY_ADMIN_PASSWORD`, `SURREALDBUSER`, `PEP_REGISTRATION_TOKEN`) viven **solo en Doppler**.

---

## 4. Semántica del adaptador (`MessageUcoLabMessageCatalogAdapter`)

```text
findUserMessage("VAL_001")
   │ caché local (5 min, solo aciertos)
   ▼
MessageUcoLabCodeMapper:  VAL_001 → MSG_VAL001      (sin "_"; ERR_CUPO_SUPERADO → alias ERR013 → MSG_ERR013;
   ▼                                                    código >10 sin alias → no se consulta)
MessageReader.getDetails("MSG_VAL001").block(3s)  → GET /messageucolab/v1/messages/consumer?code=…  (Bearer de la identidad)
   │  200 con content           → se entrega el content (el title no tiene equivalente en el puerto)
   │  404 / vacío / 4xx / 5xx / timeout / transporte
   ▼
Contingencia (Azure App Configuration) → si tampoco existe → Optional.empty() / código crudo
```

* `getTechnicalMessage` siempre se delega a la contingencia (ver hallazgo H-04).
* Formato de argumentos idéntico al de Azure/SQL: `{}` posicional y `{0}`/`{1}` indexado.
* Cada degradación se registra con `WARN` (`codigo`, `causa`), sin volcar contenido.
* `CompositeCatalogInvalidationAdapter` limpia la caché local y la de Azure ante eventos de invalidación.

### 4.1 Avisos de cambio y sincronización con la BD (INT-003, MessageUcoLab 0.3.0)

```text
MessageUcoLab ──Pulsar──> persistent://public/default/message-events-<clientId>
   (MessageCreated | MessageUpdated | MessageDeleted | MessagesChanged; el aviso no trae el texto)
        ▼
MessageUcoLabEventListener (adaptador primario, suscripción Failover, correlationId por aviso)
        ▼
SincronizarMensajesCatalogoUseCase
   Created/Updated → lee el texto con la identidad → vence la caché del código → usp_sincronizar_mensaje_usuario
                     → si cambió: evento realtime MESSAGE_UPDATED
   Deleted         → solo vence la caché (la BD conserva el texto como contingencia del proveedor sqlserver)
   MessagesChanged → reconciliación completa (también al arrancar)
```

* El SP solo actualiza `contenido` de códigos que ya existen en `dbo.CatalogoMensajeUsuario`; un código ajeno (p. ej. los
  textos `UI_*` de la SPA) no crea filas. El código canónico sale del título `"<CANONICO> - …"` y se acepta solo si su
  traducción con `MessageUcoLabCodeMapper` da el código del mensaje.
* Un aviso que falla (BD o MessageUcoLab caídos) se devuelve a Pulsar para reintento; uno ilegible se descarta.
* Si Pulsar no responde el Backend arranca igual (suscripción asíncrona) y sigue leyendo con su caché.

### 4.2 Textos de la interfaz de la SPA (INT-003, paso 12 de la guía 0.3.0)

MessageUcoLab 0.3.0 retiró su ruta pública y la identidad de servicio no puede vivir en el navegador, así que la SPA ya
no lee MessageUcoLab: pide cada texto `UI###` al Backend.

```text
SPA (mensajeUi) ──GET /api/v1/public/mensajes-interfaz/UI012 (sin sesión)──> Backend
   ConsultarMensajeInterfazUseCase: solo códigos UI + 3..8 dígitos (otro código o sin texto: 404 GEN_001)
      ▼
   MessageCatalogPort (proveedor configurado; con messageucolab: caché + identidad de servicio → MSG_UI012)
```

* La ruta es pública (también se usa en el login), solo `GET` de un segmento, exenta del PEP (`access-catalog.json`) y con
  límite por IP (`app.mensajes-interfaz.limite-por-minuto`, 240). No expone mensajes de negocio ni técnicos.
* En la SPA se enciende con `MENSAJES_UI_DESDE_CATALOGO=true` en `env.js` (o en el `.env` del contenedor del frontend);
  apagado por defecto. Encenderlo solo con el Backend en `messageucolab`: con otro proveedor los códigos `UI###` no existen
  y la SPA conserva sus textos locales. `MESSAGEUCOLAB_APPLICATION_ID`/`_ENVIRONMENT_ID` ya no se usan en el frontend.

---

## 5. Garantías de arranque

* El starter de MessageUcoLab (0.1.3) **se autoconfigura siempre** que está en el classpath (no tiene condición). Por eso
  `application.yml` declara `messageucolab.url` con un valor por defecto inocuo y el Backend sigue arrancando en modo
  `azure` sin configurar nada (probado en `MessageUcoLabMessageCatalogWiringTest`).
* El starter 0.1.3 pide el token al `ServiceAccessTokenProvider` de `security-pep-integration-spring-boot-starter`, que
  exige Spring Boot 4.1.1. El Backend (4.0.x) registra su propio `MessageUcoLabAccessTokenProvider`
  (`MessageUcoLabServiceIdentityTokenProvider`, `client_credentials` con caché hasta 30 s antes de vencer): el starter lo
  usa porque su bean es `@ConditionalOnMissingBean` (probado en `MessageUcoLabSincronizacionWiringTest`).
* La dependencia se descarga de GitHub Packages con el `<server id="github">` de `~/.m2/settings.xml`
  (token con `read:packages`, el mismo del componente de seguridad).
* **CI (GitHub Actions):** los workflows del Backend generan ese `settings.xml` con `actions/setup-java`
  (`server-id: github`) a partir de los secretos del repositorio `MESSAGEUCOLAB_PACKAGES_USER` y
  `MESSAGEUCOLAB_PACKAGES_TOKEN`. Sin ellos, la resolución del starter falla en el CI.

---

## 6. Troubleshooting

| Síntoma | Causa probable | Acción |
| :--- | :--- | :--- |
| `mvn` no resuelve `messageucolab-spring-boot-starter` (401/404) | Falta token `read:packages` o `<id>` distinto de `github` | Revisar `~/.m2/settings.xml` |
| Todos los mensajes salen de Azure estando en `messageucolab` | Componente caído, ids erróneos (409) o códigos >10 caracteres | `messages-status`; revisar `WARN` del adaptador; ver §4 |
| `409` en la consulta pública | `applicationId`/`environmentId` de botones distintos | Volver a copiar ambos del mismo botón |
| `Doppler sin sesión` al hacer `messages-up` | No se hizo `doppler login` / `doppler setup` | Ver [`MESSAGEUCOLAB_INTEGRATION.md`](../governance/MESSAGEUCOLAB_INTEGRATION.md) §3 |
| El Backend no arranca en el 8080 | Pulsar de MessageUcoLab publica el 8080 del host | `messages-up` ya lo reubica a 18082; si lo levantas a mano exporta `PULSAR_GENERALPORT=18082` |

---

## 7. Cargar el catálogo de mensajes de usuario en MessageUcoLab

El catálogo (482 mensajes de usuario al 2026-11-15) sale de **todos** los seeds de `GestioAsistenciaDB/schema/seed` (cada `MERGE` hacia
`CatalogoMensajeUsuario`) y se carga **una vez por
ambiente** con la importación masiva de MessageUcoLab (solo crea mensajes nuevos; los existentes se rechazan).

**Convención de códigos y títulos (límites vigentes: código 1–10 alfanumérico, título 10–50):**

* El código remoto es el canónico sin `_` (`VAL_001` → `VAL001`). Los 27 que no caben (`ERR_*`, `SUC_*`) usan
  `ERR001…ERR024` y `SUC001…SUC003`, en el orden del seed, declarados en `code-aliases` de `application.yml`.
* El **título** lleva el nombre canónico para buscarlo en la pantalla: `VAL_001 - El número de identificación es…`
  (si el canónico mide más de 30, el título es solo el canónico).
* El **contenido** es el del seed. MessageUcoLab 0.3.0 admite contenido de 5 a 2000 caracteres y título de 5 a 1000
  (pase `--limite 2000`); el más largo del seed tiene 136.
* **Solo lo que falta:** la importación rechaza códigos existentes. Para completar un catálogo ya cargado, pase
  `--solo <códigos remotos que faltan>` (la lista se obtiene cruzando el fixture
  `GestioAsistenciaBackend/src/test/resources/messageucolab/catalogo-mensajes-usuario.psv` con
  `GET /messageucolab/v1/messages/consumer`); así se hizo la carga de 358 del 2026-11-15 (INT-003, `ESTADO.md` §6.2).

**Pasos:**

1. En MessageUcoLab cree la organización y la aplicación "Asistencias UCO" **con la misma cuenta que administrará los mensajes desde la pantalla
   de Asistencias** (cada aplicación pertenece a quien la crea y no se comparte: H-36), cree en esa aplicación la funcionalidad
   **"Mensajes institucionales"** (el Excel la usa en todas las filas y la importación **no crea funcionalidades**) y
   descargue **su** plantilla de importación
   (la plantilla lleva el id de la aplicación y se rechaza con *"La plantilla corresponde a otra aplicación"* si es de otra).
2. Genere el Excel sobre su plantilla:

   ```powershell
   python AsistenciasUCO-Infra\components\messages\build-message-catalog.py `
     --seed GestioAsistenciaDB\schema\seed `
     --template <su-plantilla-descargada>.xlsx --xlsx mensajes-asistencias.xlsx
   ```

   (Si prefiere, copie las filas de `Complementos\CatalogoMensajes\plantilla-mensajes.xlsx` a su plantilla.)
3. En la pantalla de MessageUcoLab: **Importar** → seleccione los ambientes → validar → confirmar.
4. Configure el Backend (`MESSAGEUCOLAB_CLIENT_ID` y `MESSAGEUCOLAB_CLIENT_SECRET`, ver §3) y `messages-switch messageucolab`.

La coherencia seed ↔ alias ↔ límites la verifica `MessageUcoLabCatalogoTest`; la prueba viva `MessageUcoLabLiveIT`
comprueba contra el componente real, sin contingencia, que cada mensaje cargado devuelve el texto exacto del seed.
Si se añade un código largo al seed, regenere el fixture y los alias con el mismo script (`--psv`, `--yaml`).
Al regenerar pase siempre `--previo <catalogo-mensajes-usuario.psv vigente>` (VAL-oleada3 MSG-03): conserva el código remoto ya
importado de cada mensaje y numera los códigos largos nuevos después del último de su prefijo, sin renumerar los existentes
(por ejemplo `ERR021` quedó libre al retirar un mensaje y no se reutiliza). El catálogo del 2026-11-13 tiene 398 mensajes de usuario.
Para comprobar que el fixture del Backend sigue al seed: `build-message-catalog.py --seed GestioAsistenciaDB\schema\seed --check <catalogo-mensajes-usuario.psv>` (termina con error si hay desfase).
