---
status: active
type: work-item
scope: backend+infra
owner: backend-team
last-reviewed: 2026-11-02
---

# MSG-001 — Switch del catálogo de mensajes (Azure ⇄ MessageUcoLab)

## Clase de cambio
Integración de componente externo con *provider switch* de runtime (mismo patrón que Security Baseline 0.1.7).
No cambia Domain, Application, contratos HTTP/OpenAPI, base de datos ni catálogos desplegados.

## Autorización
Solicitada explícitamente por el responsable del proyecto (2026-11-02): integrar el componente de mensajes con un switch en el
Backend, validar su funcionamiento, reportar inconsistencias **sin modificar `Complementos/`** y documentar en Infraestructura.

## Variable principal
`app.adapters.message-catalog.provider = azure | messageucolab | sqlserver` (predeterminado `azure`).

## Alcance
* Backend: dependencia `messageucolab-spring-boot-starter:0.1.1`, `MessageUcoLabMessageCatalogAdapter`, `MessageUcoLabCodeMapper`,
  `MessageUcoLabProviderProperties`, `MessageUcoLabMessageCatalogAdapterConfiguration`, ajuste de `CompositeCatalogInvalidationAdapter`,
  valor `MESSAGEUCOLAB` en `MessageCatalogAdapterProperties`, bloque `messageucolab` en `application.yml`.
* Infra: `components/messages/start-messages.ps1`, `scripts/orchestration/switch-message-catalog.ps1`, comandos `messages-*` en `infra.ps1`,
  documentación (`MESSAGE_CATALOG_SWITCH_GUIDE.md`, `MESSAGEUCOLAB_INTEGRATION.md`, este work item).

## No alcance
* Modificar cualquier archivo de `Complementos/`.
* Cargar los 150 mensajes de Asistencias en MessageUcoLab (bloqueado por los límites H-01/H-02 hasta que el equipo de mensajes responda).
* Consumo del minifront de MessageUcoLab desde Angular (guía §9) — decisión pendiente; el frontend ya recibe `mensajeUsuario` del Backend.
* Cambiar el default de producción de `azure`.

## Rutas permitidas / prohibidas
Permitidas: `GestioAsistenciaBackend/{pom.xml,src/**}`, `AsistenciasUCO-Infra/**`. Prohibidas: `Complementos/**`, DB, Frontend.

## Riesgos y rollback
| Riesgo | Mitigación |
| :--- | :--- |
| El starter se autoconfigura aunque no se use | Defaults inocuos en `application.yml`; probado con `ApplicationContextRunner` |
| Caída/lentitud de MessageUcoLab degrada la API | `block(3s)` + contingencia Azure + caché; sin propagar excepciones |
| Límite 120/min por IP del gateway | Caché local de aciertos (TTL 5 min) |
| Códigos/contenido fuera de los límites de MessageUcoLab | Mapeo con alias; sin alias ⇒ contingencia (H-01/H-02) |
| Token GitHub Packages ausente en CI | Documentado; el `<id>` coincide con el de seguridad |

Rollback: `messages-switch -Mode azure` (sin redeploy); o quitar la dependencia y el paquete `messageucolab` (aislado en Infrastructure).

## Evidencia / consumidores
Consumidores del puerto: `ResolverMensajeUsuarioUseCaseImpl`, casos de coordinador/decano, verificación de correo, grupo.
Fuentes AS-IS: `MessageCatalogPort`, `AzureAppConfigMessageCatalogAdapter`, guía `Guia-integracion-MessageUcoLab.pdf`,
bytecode del starter `0.1.1` (`DefaultMessageReader`, `MessageUcoLabHttpAdapter`, `MessageUcoLabAutoConfiguration`).
