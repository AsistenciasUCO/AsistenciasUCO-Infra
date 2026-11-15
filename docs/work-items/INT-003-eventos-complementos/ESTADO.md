# INT-003 — Eventos de los complementos y MessageUcoLab 0.3.0

> Fecha: 2026-11-15. Ramas: Backend `feat/int003-messageucolab-eventos`, BD `feat/int003-sincronizar-mensajes-messageucolab`,
> Infra `docs/int003-messageucolab-eventos`, Frontend `feat/int003-textos-interfaz-backend` (todas desde `develop`).
> Continúa [INT-002](../INT-002-complementos-seguridad-mensajes-parametros/ESTADO.md).

## 1. Objetivo

Los SP y funciones de la BD leen `dbo.CatalogoParametro` y `dbo.CatalogoMensajeUsuario`. Con los complementos externos
(Catálogo de Parámetros y MessageUcoLab) nada copiaba sus cambios a la BD. El responsable pidió (2026-11-14) revisar la
última entrega de cada componente, integrar los eventos de los que ya los publiquen y revisar en Seguridad el cambio de
contraseña y el rol al registrarse. Los componentes no son nuestros: fallos o faltantes se piden al equipo dueño.

## 2. Revisión de entregas (`Complementos/<componente>/Nuevo/<fecha>/`)

| Componente | Última entrega | Publicado (Docker Hub / GitHub) | Laboratorio | Eventos para consumidores |
| :--- | :--- | :--- | :--- | :--- |
| MessageUcoLab | 2026-11-12 (0.3.0) | `jciro17/messageucolab:0.3.0` (2026-11-14), cliente Java `messageucolab-client-v0.1.3` | **0.3.0** (antes 0.2.0) | **Sí**: Pulsar, topic `message-events-<clientId>` |
| Catálogo de Parámetros | 2026-11-10 | `simon4219/catalogo-parametros:0.1.7`, frontend `0.1.6` (las últimas) | 0.1.7 / 0.1.6 (al día; el zip es idéntico a lo instalado) | **No**: `/administracion/events` es solo el SSE de su microfrontend |
| Seguridad | 2026-11-04 (0.1.11) | Release `v0.1.13` (2026-11-09) = `develop`; `security-ui` y `securityBaseline-vue` `main` = local (tag `v0.1.8` ya incluido) | 0.1.13 (al día) | Rama `feature/evento-rabbitMQ` (asignación/revocación de roles) **sin mezclar ni publicar**: no se descarga |

Seguridad 0.1.13 **no** trae: cambio/recuperación de contraseña, correo de activación (el realm no tiene
`resetPasswordAllowed` ni SMTP) ni rol/perfil por defecto al autorregistrarse. La rama `main` de `securityBaseline` está
detenida en septiembre; las versiones oficiales salen de `develop` como releases.

## 3. MessageUcoLab 0.3.0 en el laboratorio (Parte A de la guía)

* Kit `messageucolab-local` reemplazado con el de la entrega 2026-11-12, conservando `PULSAR_GENERALPORT=18082` (el 8080 es
  del Backend). Revisado antes de aplicar: mismas imágenes oficiales, perfil `ollama` opcional, Kong cambia la ruta pública
  por `/messageucolab/v1/messages/consumer`, Pulsar anuncia `pulsar://localhost:6800` hacia el PC.
* Respaldo previo: `C:\jtmp\backups\messageucolab-0.2.0-20261115-000015` (kit, volúmenes de SurrealDB y Pulsar).
* Levantado con el conjunto ligero (`redis redis-init surrealdb surrealdb-init kong pulsar` y luego `messageucolab --no-deps`):
  inits `Exited (0)`, app `healthy` con `jciro17/messageucolab:0.3.0`, `actuator/health` `UP`.
* **Paso 5 (hecho, API del PDP):** de las 33 rutas del libro `recursos-messageucolab-0.3.0.xlsx` faltaban 5 (las otras
  28 venían de 0.2.0); se registraron y se concedieron al rol "Gestor de mensajes". La ruta pública retirada
  (`GET /messageucolab/v1/public/messages/{codigo}`) queda registrada sin uso.
* **Pasos 7 a 10 (hechos):** rol técnico `MESSAGE_CONSUMER` creado en MessageUcoLab (rutas `GET /messages/consumer` y
  `POST /messages/consumer/translations`; el kit no lo trae), identidad
  `svc-e4e258be-…-asistencias-uco-a-messageucolab-dev` de la aplicación `asistencias-uco` del PDP, solicitud aprobada y
  asociada al ambiente Develop de "Asistencias UCO" (`c05f384e…`/`9732b9aa…`) en MessageUcoLab con `uco-administrador`.
  El secreto se escribió solo en el `.env` del Backend (no se imprimió). Token `client_credentials` 200; ruta de consumo 200.
* Paso 6 (pantalla de MessageUcoLab): el minifront `main` (`14a122d`) es el que ya usa la SPA; los cambios de 0.3.0 del
  minifront están solo en su `develop` (no publicado en `main`), así que no se descargan.

## 4. Cambios

### BD (migración 45)

* `usp_sincronizar_mensaje_usuario(@codigo, @contenido, @idCorrelacion)`: actualiza solo `contenido`/`fechaModificacion`
  de un código que ya existe (bloqueo `UPDLOCK, HOLDLOCK`, transacción propia o `SAVE TRANSACTION`). Tupla canónica +
  `codigo`, `huboCambio`, `fechaModificacion`, `existeMensaje`. Código ausente: `GEN_001` con `existeMensaje = 0` y sin
  escritura. No cambia estado, tipo ni severidad. Sin RBAC: lo invoca un proceso del sistema.
* Permiso `EXECUTE` para `rol_asistencias_runtime` (`schema/security/rol_asistencias_runtime_int003.sql`).
* Prueba `test/test_int003_sincronizar_mensaje.sql` (7 casos), marcador en `scripts/migrar-marcadores.json` y hash del
  manifiesto CULM-001 D actualizado.

### Backend

* Starter `messageucolab-spring-boot-starter` 0.1.1 → **0.1.3** y `pulsar-client` (versión gestionada por Spring Boot).
* `MessageUcoLabServiceIdentityTokenProvider`: token `client_credentials` de la identidad de servicio. El starter 0.1.3
  espera el proveedor de `security-pep-integration-spring-boot-starter` (Spring Boot 4.1.1); como su bean es
  `@ConditionalOnMissingBean`, el Backend registra el suyo y **no** hace falta subir Spring Boot.
* Avisos: `MessageUcoLabEventListener` (adaptador primario Pulsar) → `SincronizarMensajesCatalogoUseCase` →
  `MessageCatalogSourcePort` (MessageUcoLab) + `MensajeCatalogoRepositoryPort` (`usp_sincronizar_mensaje_usuario`) +
  `CatalogInvalidationPort` + `RealtimePublisherPort` (`MESSAGE_UPDATED`). Reconciliación completa al arrancar y con
  `MessagesChanged`. `MessageDeleted` solo vence la caché.
* Secreto nuevo en el baúl: `asistencias-messageucolab-client-secret` (`SECRETS_INVENTORY.md`). Variables nuevas en
  `.env.example` y `application.yml`; se retiran `messageucolab.application-id/environment-id`.

* `pulsar-client` 4.1.x trae `opentelemetry-api-incubator` 1.56.0-alpha y el SDK es 1.62.0: el Backend no arrancaba
  (`DeclarativeConfigProperties.get`). Se alinea a `${opentelemetry.version}-alpha` en `dependencyManagement`;
  `OpenTelemetryClasspathAlignmentTest` lo vigila (las pruebas unitarias no construyen el SDK real).

### Textos de la interfaz (paso 12)

* Backend: `GET /api/v1/public/mensajes-interfaz/{codigo}` (pública, también en el login). `ConsultarMensajeInterfazUseCase`
  responde solo códigos `UI` + 3..8 dígitos (otro código o sin texto: 404 `GEN_001`, no revela qué existe) desde
  `MessageCatalogPort`. Declarada una por una en `SecurityConfig` (GET y su preflight), exenta del PEP en
  `SecurityPublicEndpoints` y `access-catalog.json`, con `MensajesInterfazRateLimitFilter` (240/min por IP). Contrato en
  `HTTP_AS_IS_MATRIX.md` (no entra al golden path, como las demás rutas públicas).
* Frontend: `CatalogoMensajesUiService` pide el texto al Backend con `HttpClient` (sin aviso global) en lugar de
  `createMessageClient`; se enciende con `MENSAJES_UI_DESDE_CATALOGO=true` (apagado por defecto) y se retiran
  `MESSAGEUCOLAB_APPLICATION_ID/ENVIRONMENT_ID` de `env.template.js`, el entrypoint, `docker-compose.yml` y `.env.example`.

### Infra

* `MESSAGE_CATALOG_SWITCH_GUIDE.md` actualizado a 0.3.0 (§3, §4.1, §5).
* `infra.ps1 messages-switch` y `switch-message-catalog.ps1`: `-ClientId` en lugar de `-ApplicationId/-EnvironmentId`;
  el `.env` se escribe sin BOM.

## 5. Decisiones

1. **Parámetros sin eventos:** no se integra nada nuevo; se pide al equipo un aviso por cambio de parámetro (§7).
2. **Sin subir Spring Boot:** el token lo da el Backend con su propio cliente (mismo patrón que `SecurityBaselinePdpProfileClient`).
3. **La BD solo refleja códigos propios:** un mensaje nuevo en MessageUcoLab no crea filas; los textos `UI_*` quedan fuera.
4. **Borrado sin borrar en la BD:** la BD es la contingencia del proveedor `sqlserver`; un borrado accidental no deja a los SP sin texto.
5. **Pulsar 4.1.x en el cliente:** el protocolo binario es compatible con el broker 3.2.2 del kit y evita una línea vieja.

## 6. Verificación (2026-11-15)

| Qué | Resultado |
| :--- | :--- |
| Gate de BD igual a la CI (contenedor temporal: deploy limpio, `test_summary.ps1`) | 813 ejecutadas, 812 PASS, 0 FAIL, 1 SKIPPED, `CRITICAL_MISSING=0`, `SQL_ERROR_COUNT=0`; INT003 (7) y VAL_MDET (8) en verde |
| Migración 45 en la BD del laboratorio | `migrar.ps1 -Modo Aplicar`: aplicada (380 ms), 45/45 registradas; respaldo `gestionasistenciadb_pre_migr45_20261115-104349.bak` |
| Backend `mvnw verify` | 4611 pruebas, 0 fallos, cobertura JaCoCo cumplida (se repite tras la alineación de OpenTelemetry) |
| Frontend `npm run verify` | 3020 pruebas en verde, cobertura realtime (95,26 % líneas, 86,81 % ramas), checks y build de producción OK |
| `infra.ps1 verify` | paso 1/3: falso positivo heredado de `develop` (`.github/workflows/infra-validation.yml:44`); 2/3 contratos WORM y paridad: PASS (18); 3/3 rutas por rol: PASS tras regenerar `rutas-por-rol.md` |
| Arranque del Backend (baseline, `provider=messageucolab`) | suscrito a `message-events-svc-…`; reconciliación: 139 revisados, 124 sin cambios, 15 sin código en la BD, 0 fallidos |
| E2E aviso → BD | `PUT` del texto de `MSG_GEN004` en MessageUcoLab → fila `GEN_004` actualizada en 1,4 s; `MESSAGE_UPDATED` publicado; texto restaurado |
| Ruta pública de textos | `UI012` 200 con el texto; `UI999`, `GEN004`, `ui012` 404 `GEN_001`; desde la SPA (4200 → 8080, con preflight) 200 |

### 6.1 Validación funcional en el laboratorio (2026-11-15, tarde)

| Caso | Resultado |
| :--- | :--- |
| Cambio en MessageUcoLab con el Backend **apagado** | La BD no cambia; al arrancar, la reconciliación lo copia (`actualizados=1`) y la suscripción durable entrega el aviso pendiente, que queda `sinCambios` (idempotente) |
| Alta de un mensaje nuevo (`INT003PRB`) | MessageUcoLab 0.3.0 avisa `MessageUpdated` (no `MessageCreated`); `noExisten=1`, sin filas nuevas |
| Borrado (`MessageDeleted`) | Solo vence la caché; la BD conserva sus 482 filas |
| Importación masiva (1 y 2 mensajes) | Llega un `MessageUpdated` por mensaje; **nunca llegó `MessagesChanged`** (esa rama solo la cubren las pruebas unitarias) |
| Edición desde la pantalla de mensajes de Asistencias (minifront `main`) | Lista y edita en Develop con 0.3.0; el cambio llegó a `GEN_004` en el mismo segundo; texto restaurado |
| SPA con sesión real (`uco-administrador`) | Al negar una ruta, la SPA pidió `UI094` al Backend: 200 |
| Rol `ADMIN` de MessageUcoLab en el PDP | Sin rutas ni perfiles: no concede nada (inocuo) |
| Mensajes de prueba creados | Borrados (`INT003PRB`, `INT003IMP`, `INT003IMPB`, `INT003IMPC`) |

**Hallazgos**

* **358 códigos de la BD no están en MessageUcoLab** (los agregados después de la carga del 2026-11-04: `ACC_APP_*`,
  `VAL_APP_*`, `NOF_APP_*`, `ALR_*`, `AQR_*`, `MQR_*`, …). Con `provider=messageucolab` y `MESSAGEUCOLAB_FALLBACK=none`,
  `MessageCatalogPort.getUserMessage` devuelve el **código crudo**: el estudiante ve sus alertas como `ALR_010` y `ALR_011`
  (`GET /estudiante/alertas`, comprobado). Los errores que pasan por `GlobalExceptionHandler` no se ven afectados (usan el
  texto de respaldo del enum). Viene de INT-002, no de INT-003.
* **16 mensajes de MessageUcoLab no existen en la BD:** `SIG_001`…`SIG_015` y `ERR021` (solicitudes de ingreso a grupo,
  retiradas en CULM-001 A.1). Son obsoletos.
* `MESSAGE_UPDATED` se descarta con `FAIL_ZERO_SUBSCRIBER` aun con la SPA abierta: la SPA no mantiene un SSE global.

### 6.2 Carga de los 358 mensajes que faltaban (2026-11-15)

* Excel generado con `build-message-catalog.py --previo <fixture del Backend> --solo <faltantes> --limite 2000` sobre la
  plantilla vigente de "Asistencias UCO" (el fixture y los 122 alias ya cubrían los 482 códigos: no hubo cambios en el
  Backend). Validación: 358 filas, 0 *issues*; confirmada en Develop (`count=358`).
* La carga disparó 358 avisos `MessageUpdated`. **Defecto encontrado y corregido:** el límite de Kong (120/min por IP)
  respondió 429 a 167 lecturas y `MessageUcoLabMessageSourceAdapter` las tomaba como "mensaje inexistente": el aviso se
  confirmaba sin copiar el texto (con un cambio real, la BD habría quedado desactualizada hasta el siguiente arranque).
  Ahora solo un 404 es "no existe"; 429, 5xx y fallos de red lanzan `FuenteNoDisponibleException` y el aviso vuelve a
  Pulsar; `listar()` tampoco devuelve una lista vacía ante un fallo (la reconciliación falla en vez de "terminar" sin datos).
* Tras reiniciar: reconciliación de **497** mensajes, 482 sin cambios (la BD ya tenía esos textos), 15 sin código en la BD,
  **0 fallidos**. Las alertas del estudiante (`GET /estudiante/alertas`) muestran el texto en lugar de `ALR_010`/`ALR_011`.

## 7. Pendiente

* La SPA pide cada texto `UI###` al usarlo; los que cambian en MessageUcoLab se ven tras recargar (el `MESSAGE_UPDATED` solo
  se publica para códigos de la BD). Si se quiere al instante, la SPA puede escuchar ese evento en el SSE autenticado.
* `infra.ps1 messages-switch` sigue escribiendo solo el `.env` del Backend; `MENSAJES_UI_DESDE_CATALOGO` del frontend se pone a mano.
* Opcional: agregar `sqlserver` como contingencia de `MessageUcoLabMessageCatalogAdapter` (la BD queda sincronizada por los
  avisos) para que un código nuevo que aún no se cargó en MessageUcoLab no salga crudo.
* Retirar de MessageUcoLab los 16 mensajes obsoletos (`SIG_*`, `ERR021`) (borrado: con confirmación del responsable).
* Cada laboratorio del equipo debe repetir la carga (§6.2) en su propio MessageUcoLab.

## 8. Solicitudes a otros equipos

* **Catálogo de Parámetros:** publicar un aviso por cambio de parámetro (como MessageUcoLab: topic o webhook por token,
  sin valor en el aviso) para sincronizar `dbo.CatalogoParametro`, que leen los SP.
* **Seguridad:** (a) rol/perfil por defecto al autorregistrarse, o una ruta para que la identidad de servicio del Backend
  asigne el perfil Estudiante; (b) recuperación/cambio de contraseña, SMTP y correo de activación al crear usuarios;
  (c) publicar como release la rama `feature/evento-rabbitMQ` si se va a consumir.
* **MessageUcoLab:** entrega confiable de avisos (outbox, su fase 3) y permisos por topic en Pulsar (su riesgo documentado);
  que el kit o la guía creen el rol técnico `MESSAGE_CONSUMER` (en un PDP limpio no existe); publicar en `main` la versión
  0.3.0 del minifront; y que el cliente Java declare un `opentelemetry-api-incubator` alineado o lo documente (con
  `pulsar-client` 4.1.x choca con el SDK 1.62.0 de Spring Boot 4).
