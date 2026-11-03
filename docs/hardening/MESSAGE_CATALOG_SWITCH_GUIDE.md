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
    -ApplicationId <uuid> -EnvironmentId <uuid>                    # ids del botón "Copiar identificadores"
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
| `MESSAGEUCOLAB_APPLICATION_ID` | *(vacío)* | UUID de la aplicación en MessageUcoLab (no es secreto) |
| `MESSAGEUCOLAB_ENVIRONMENT_ID` | *(vacío)* | UUID del ambiente (Develop/Testing/Produccion). Debe ser del **mismo botón** que el anterior o responde `409` |
| `MESSAGEUCOLAB_TIMEOUT` | `3s` | Espera máxima por mensaje (el puerto es síncrono) |
| `MESSAGEUCOLAB_CACHE_TTL` | `5m` | Caché local de aciertos; `0` la desactiva. El gateway limita a 120 peticiones/min por IP |
| `MESSAGEUCOLAB_FALLBACK` | `azure` | Contingencia si MessageUcoLab falla o no tiene el código: `azure` \| `none` |
| `MESSAGEUCOLAB_CODE_PREFIX` | `MSG_` | Prefijo que MessageUcoLab antepone a todo código |
| `app.providers.messageucolab.code-aliases.<CODIGO>` | *(vacío)* | Alias corto (≤10) para códigos canónicos más largos (solo `application.yml`/propiedades) |

Ninguna de estas variables es un secreto. Los secretos del componente (`SURREALDBPASSWORD`, `REDISPASSWORD`,
`GF_SECURITY_ADMIN_PASSWORD`, `SURREALDBUSER`, `PEP_REGISTRATION_TOKEN`) viven **solo en Doppler**.

---

## 4. Semántica del adaptador (`MessageUcoLabMessageCatalogAdapter`)

```text
findUserMessage("VAL_001")
   │ caché local (5 min, solo aciertos)
   ▼
MessageUcoLabCodeMapper:  VAL_001 → MSG_VAL_001     (código >10 sin alias → no se consulta)
   ▼
MessageReader.getDetails("MSG_VAL_001").block(3s)  → GET /messageucolab/v1/public/messages/{code}
   │  200 con content           → se entrega el content (el title no tiene equivalente en el puerto)
   │  404 / vacío / 4xx / 5xx / timeout / transporte
   ▼
Contingencia (Azure App Configuration) → si tampoco existe → Optional.empty() / código crudo
```

* `getTechnicalMessage` siempre se delega a la contingencia (ver hallazgo H-04).
* Formato de argumentos idéntico al de Azure/SQL: `{}` posicional y `{0}`/`{1}` indexado.
* Cada degradación se registra con `WARN` (`codigo`, `causa`), sin volcar contenido.
* `CompositeCatalogInvalidationAdapter` limpia la caché local y la de Azure ante eventos de invalidación.

---

## 5. Garantías de arranque

* El starter de MessageUcoLab **se autoconfigura siempre** que está en el classpath (no tiene condición). Por eso
  `application.yml` declara `messageucolab.url/application-id/environment-id` con valores por defecto inocuos y el
  Backend sigue arrancando en modo `azure` sin configurar nada (probado en `MessageUcoLabMessageCatalogWiringTest`).
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
