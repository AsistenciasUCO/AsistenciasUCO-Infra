# MSG-001 — Hallazgos y sugerencias para el equipo de MessageUcoLab

> **Origen:** integración de MessageUcoLab (guía v4.0, octubre 2026; starter `0.1.1`; imagen `jciro17/messageucolab:0.1.0`)
> en Asistencias UCO.  
> **Regla:** `Complementos/` pertenece a otros equipos. **No se modificó nada ahí**; todo lo de abajo es para aclarar con ellos.  
> **Evidencia:** cada hallazgo indica cómo se comprobó. `[LEÍDO]` = revisión estática de archivos/guía; `[PROBADO]` = ejecutado;
> `[PENDIENTE]` = requiere el stack en vivo (ver `VALIDATION.md`).

## A. Bloqueantes de compatibilidad con Asistencias

| # | Hallazgo | Evidencia | Sugerencia |
| :-- | :-- | :-- | :-- |
| H-01 | **El código solo admite letras, números y espacios (`^[A-Za-z0-9 ]{1,10}$`, "sin guiones") y máx. 10 caracteres tras `MSG_`.** El catálogo de usuario de Asistencias tiene **78 códigos únicos**; **los 78 llevan `_`** (p. ej. `VAL_001`, `GEN_001`) y **27 exceden 10 caracteres** aun sin el guion (el mayor: `ERR_CRUCE_HORARIO_ESTUDIANTE`). Solo **49 son migrables** quitando el `_`. | `[PROBADO]` el formulario rechaza `GEN_001`; `[LEÍDO]` `CreateMessage.vue` y análisis de `04_mensaje.sql` | Aceptar `_` (y subir el límite, p. ej. 50) o un campo `externalCode`. Hoy cada app con códigos descriptivos debe inventar alias. Asistencias quita los no alfanuméricos y usa alias para los largos (sin truncar, para no crear colisiones). **Corrección:** una versión previa de este informe hablaba de 150 códigos / 54 largos; contaba también la tabla técnica y duplicados. |
| H-02 | **El contenido admite 10–100 caracteres y el título 10–50 y es obligatorio.** 2 de los 78 mensajes de usuario superan 100 (máx. 122) y el modelo de Asistencias no tiene título. | `[LEÍDO]` seed + guía 6.4 | Ampliar el contenido (p. ej. 500) y hacer el título opcional o derivable. |
| H-03 | **Marcadores:** la guía usa `{nombre}` (nombrados). Asistencias usa `{}` posicional (12 de 78) y `{0}`. | `[PROBADO]` el servicio **acepta `{}` al crear y lo devuelve intacto** por la ruta pública (`MSG_GEN001`, `MSG_VAL002` con dos `{}`) · `[PENDIENTE]` traducción por IA conservando `{}` | Documentar la sintaxis soportada. Un estándar de marcadores daría un contrato estable. |
| H-04 | **Tipos de mensaje:** existen `Funcional`/`Técnico`, pero el código es único por aplicación, así que no hay forma de tener un texto de usuario **y** uno técnico con el mismo código (Asistencias maneja ambos en `getUserMessage`/`getTechnicalMessage`). | `[LEÍDO]` `catalog-spanish.surql` + guía | Definir convención (p. ej. `TEC_`+código) o permitir par usuario/técnico por código. Mientras tanto Asistencias deja lo técnico en Azure. |

## B. Seguridad y operación del compose (`messageucolab-local`)

| # | Hallazgo | Evidencia | Sugerencia |
| :-- | :-- | :-- | :-- |
| H-05 | **Todos los puertos se publican en `0.0.0.0`** (SurrealDB 8005, Redis 6379, Kong 8000, **Kong Admin 8001 sin autenticación** con `KONG_ADMIN_LISTEN=0.0.0.0:8001`, Grafana 3000, Pulsar, Ollama 11434, Loki, Prometheus). | `[LEÍDO]` `compose.yaml` | Publicar a `127.0.0.1:` (como exige el hardening institucional) y no publicar el Admin de Kong ni Redis/Surreal. |
| H-06 | **Imágenes `:latest`** (grafana, loki, prometheus, redis, ollama, `kong-gateway:3.5` sí fija) y `otel-collector-contrib:0.40.0` (muy antigua). Builds no reproducibles. | `[LEÍDO]` | Fijar versiones/digests. |
| H-07 | **Conflicto de puertos con Asistencias:** `PULSAR_GENERALPORT=8080` publica Pulsar en el **8080 del host, el puerto del Backend de Asistencias**. También 3000/6379/9090 son puertos comunes. | `[LEÍDO]` `.env` + `compose.yaml` | No publicar Pulsar (solo red interna) o usar rangos propios. Asistencias lo evita exportando `PULSAR_GENERALPORT=18082` (la variable del proceso gana al `.env`). |
| H-08 | **Nombres de contenedor fijos y genéricos** (`redis`, `grafana`, `prometheus`, `loki`, `surrealdb`, `pulsar`): colisionan con otros stacks locales y no permiten dos instancias. | `[LEÍDO]` | Quitar `container_name` (Compose ya prefija con el proyecto). |
| H-09 | **Recursos:** Pulsar con `-Xms1g -Xmx1g -MaxDirectMemory=2g` + Ollama (llama3.2) + SurrealDB + Redis + Kong + observabilidad en una máquina de 8 GB de Docker. | `[LEÍDO]` | Perfiles de Compose (`core` sin Ollama/observabilidad) para desarrollo. |

## C. Contrato de consumo

| # | Hallazgo | Evidencia | Sugerencia |
| :-- | :-- | :-- | :-- |
| H-10 | **Rate limit 120/min por IP** en la ruta pública (`kong.yaml`). Un backend centralizado comparte una sola IP; sin caché, cada mensaje es una petición. | `[LEÍDO]` | Documentarlo en la guía; ofrecer ETag/`Cache-Control`/`If-None-Match`, o un *bulk* público (`getAll` existe pero es una descarga completa). Asistencias añadió caché local (TTL 5 min). |
| H-11 | **No hay invalidación push pública:** el feed de cambios (`GET /messageucolab/v1/messages/events`, ruta 20) es administrativo (requiere sesión/rol). Los consumidores solo ven cambios al expirar su caché. | `[LEÍDO]` Anexo B | Webhook o SSE público/técnico para invalidación por código. |
| H-12 | **Timeout por defecto del starter: 60 s** (`messageucolab.timeout`). En un API síncrono es excesivo y bloquea hilos. | `[LEÍDO]` metadata del starter | Bajar el valor por defecto (3–5 s). Asistencias acota con `block(3s)`. |
| H-13 | **El starter se autoconfigura sin condición** (`@ConditionalOnClass` + `@EnableConfigurationProperties`): por solo estar en el classpath registra `MessageReader`/`WebClient`, aunque la app use otro catálogo. Según la guía 8.3, si falta una propiedad la app no arranca (`Could not resolve placeholder`), lo que obliga a configurar el componente aunque no se use. | `[LEÍDO]` · `[PROBADO]` arranca con ids vacíos | Añadir `messageucolab.enabled` (`@ConditionalOnProperty`), que permita convivir con otros catálogos. |
| H-14 | **Errores 400/409 no pasan por `MessageFallbackPort`** (solo 404, ≥500 y transporte). Un `409` por ids cruzados rompe la respuesta de negocio en lugar de degradar. | `[LEÍDO]` bytecode de `DefaultMessageReader` | Documentarlo o permitir al fallback cubrir cualquier error. Asistencias captura toda excepción en el adaptador. |
| H-15 | El contrato público devuelve `title`+`content`; un `MessageCatalogPort` clásico solo necesita el texto. Se usa `content`. | `[LEÍDO]` | Informativo. |

## D. Entrega y documentación

| # | Hallazgo | Evidencia | Sugerencia |
| :-- | :-- | :-- | :-- |
| H-16 | **Archivos citados que no están en la carpeta entregada:** `empaquetar.ps1` (README), `recursos-messageucolab.xlsx` (la guía lo nombra así; en la carpeta está `plantilla-recursos.xlsx`) y `MessageUcoLab-ruta-publica.postman_collection.json` (paso 8.1). | `[LEÍDO]` | Entregarlos o corregir los nombres. |
| H-17 | **Versiones desalineadas:** la guía pide starter `0.1.1` pero la imagen del `.env` es `0.1.0`. La compatibilidad starter↔imagen no está declarada. | `[LEÍDO]` | Matriz de compatibilidad o versiones alineadas. |
| H-18 | **Anexo A de la guía con la tabla desalineada** (valores desplazados una fila desde `PULSARTOPICNAME`); el topic por defecto es `crossword-topic` (residuo de otro proyecto). | `[LEÍDO]` PDF p. 58–59 | Corregir tabla y renombrar el topic. |
| H-19 | **Alta de permisos manual y repetitiva:** hay que conceder 28 recursos de a uno (guía 2.5) en cada instalación. | `[LEÍDO]` | Concesión masiva a un rol o rol predefinido "Gestor de mensajes" en el Excel. |
| H-20 | **Doppler obligatorio con cuenta propia por persona:** los secretos locales no son compartibles entre el equipo y `PEP_REGISTRATION_TOKEN` es distinto por instalación. | `[LEÍDO]` | Documentar el flujo de equipo o ofrecer `.env.example` para laboratorio. |
| H-21 | Sesión de administración expira cada ~5 min sin renovación (FAQ de la guía; deuda del equipo de seguridad). | `[LEÍDO]` guía | Informativo. |
| H-22 | Dependencia de que el componente de seguridad corra en 18080/18081 (host.docker.internal); el entorno PEP debe ser `dev\|lab\|prod` (Asistencias ya lo requirió en Security Baseline 0.1.7). La guía lista ambientes "Desarrollo/Laboratorio/Producción" en seguridad y "Develop/Testing/Produccion" en mensajes. | `[LEÍDO]` | Unificar nomenclatura de ambientes. |

## F. Hallazgos de la puesta en marcha real (2026-11-02)

| # | Hallazgo | Evidencia | Sugerencia |
| :-- | :-- | :-- | :-- |
| H-23 | **El paso 1 de la guía no funciona con el compose de seguridad 0.1.7**: el servicio `pdp` no reenvía `PDP_CORS_ALLOWED_ORIGINS` ni `PDP_LOGIN_ALLOWED_RETURN_ORIGINS`, así que editar el `.env` no permite `:5174`. | `[LEÍDO]` compose + `[PROBADO]` | Corregir la guía o publicar un compose que reenvíe las variables (el compose endurecido del Backend ya las parametriza). |
| H-24 | **Redes Docker autoasignadas** (`pulsar-network` tomó `172.31.0.0/16`) pueden colisionar con otras redes de laboratorio. Provocó `Pool overlaps with other one on this address space` al levantar seguridad después. | `[PROBADO]` | Fijar subredes documentadas o rangos poco comunes; indicar el orden de arranque. |
| H-25 | **`depends_on` de `messageucolab` exige `ollama-init`** (`service_completed_successfully`): aunque `TRANSLATION_AI_ENABLED=false`, no se puede arrancar sin descargar Ollama y el modelo (~2 GB). | `[LEÍDO]` | Mover Ollama a un perfil opcional y quitar la dependencia dura. Asistencias lo evita con arranque por etapas (`--no-deps`). |
| H-26 | **La app tarda más de 5 minutos en pasar a `healthy`** en un equipo de 16 GB con otros stacks; la guía sugiere "esperar un minuto". | `[PROBADO]` | Documentar tiempos y requisitos de memoria (Pulsar hasta ~3 GB). |
| H-27 | **El Kong del compose no resuelve `host.docker.internal`** mientras `messageucolab-app` no está arriba y responde un error de DNS en lugar de 503 claro (`failed the initial dns/balancer resolve…`). | `[PROBADO]` | Healthcheck/`depends_on` de Kong sobre la app, o respuesta 503 controlada. |

## E. Hallazgos de la validación en vivo (2026-11-03)

| # | Hallazgo | Evidencia | Sugerencia |
| :-- | :-- | :-- | :-- |
| H-28 | **La concesión de 28 recursos al rol es manual y propensa a omisiones:** 2 de 28 (`POST /messages` y `PUT /messages/{messageCode}`) no se registraron y el síntoma fue un `403 "No tienes permiso para realizar esta operación"` al crear el primer mensaje, sin indicar qué recurso faltaba. | `[PROBADO]` | Concesión masiva por rol (H-19) y un mensaje de error que nombre el recurso denegado. |
| H-29 | **Ruta pública verificada:** `GET /messageucolab/v1/public/messages/{code}` con `X-Application-Id`/`X-Environment-Id` devuelve 200 y `title`/`content`; un código inexistente da 404 con cuerpo `{"data":[],"errors":[{"code":"NOT_FOUND",…}]}`; un ambiente inexistente degrada sin excepción en el cliente. | `[PROBADO]` `MessageUcoLabLiveIT` (5/5) | Informativo: el contrato se comporta como documenta la guía. |
| H-30 | **El selector "Idioma base" de "Crear aplicación" viene en "Inglés"** por defecto aunque el catálogo es español; una aplicación creada sin cambiarlo queda con idioma base inglés. | `[PROBADO]` | Preseleccionar el idioma de la organización o exigir elegirlo. |
| H-31 | **503 `PEP_UNAVAILABLE` / cuelgues intermitentes** en rutas administrativas (`/catalog/*`, `/environments`) con el PEP registrando `ReadTimeoutException` hacia el PDP; el PDP no registró errores y con reintentos respondió 200. | `[PROBADO]` (intermitente) | Para el equipo de seguridad: revisar el timeout PEP→PDP y la causa de las lecturas lentas. |
| H-32 | **La importación masiva exige que la UI/API tenga la sesión vigente (cookie HttpOnly):** una sesión vencida devuelve 401 `TOKEN_INVALID` sin indicar caducidad; no hay forma de cargar mensajes por un token técnico. | `[PROBADO]` | Credencial técnica de carga o aviso de caducidad de sesión. |
| H-33 | **La ruta pública no limita: se cuelga bajo ráfaga.** 150 peticiones concurrentes (20 hilos) a `GET /messageucolab/v1/public/messages/{code}` dieron 85 × `200` y 65 × timeout de 30 s, ningún `429`; una petición suelta después respondió en ~0,1 s. El límite documentado (120/min/IP) no se observó como `429` en esa ráfaga concurrente; **sí aparece como `429` con peticiones secuenciales** (140 mensajes en pocos segundos): ver V-31. | `[PROBADO]` | Devolver `429` con `Retry-After` en vez de retener la conexión, o publicar el comportamiento esperado. El Backend lo absorbe con timeout de 3 s y caché de 5 min. |
| H-35 | **La plantilla de importación lleva el id de la aplicación (hoja oculta) y se rechaza en otra instalación** con `422 "La plantilla corresponde a otra aplicación"`. Un Excel preparado una vez no se puede compartir entre equipos con instalaciones locales distintas. | `[PROBADO]` | Aceptar el nombre de la aplicación en lugar del id, o permitir importar sin el metadato oculto. Mientras tanto Asistencias genera el Excel sobre la plantilla de cada instalación. |
| H-36 | **Cada aplicación pertenece a quien la creó y no hay forma de compartirla:** `GET /session/applications` solo devuelve las del usuario de la sesión, así que otro usuario (p. ej. el administrador institucional) recibe "Tu usuario no administra una aplicación llamada ..." y no puede administrar los mensajes de una aplicación creada por otra cuenta. | `[PROBADO]` | Roles o miembros por organización/aplicación, o documentar que el dueño es quien administra. Mientras tanto Asistencias crea la aplicación con la cuenta del administrador que usará la pantalla. |
| H-34 | **El PDP quedó `unhealthy` tras ~21 h** (healthcheck con timeout de 3 s) y entonces casi todas las rutas protegidas del Backend devolvieron `503 ACCESS_DECISION_UNAVAILABLE`. Un `docker restart` del PDP lo normalizó y desapareció la intermitencia descrita en H-31. | `[PROBADO]` | Para el equipo de seguridad: subir el timeout del healthcheck del PDP o investigar la degradación con el tiempo. |

## F2. Pendiente de validar en vivo

Se completará en `VALIDATION.md` cuando el stack esté arriba: respuesta real de `GET /public/messages/{code}` (campos y
`Content-Type`), aceptación de `{}` en mensajes, comportamiento ante `409`, tiempos de la primera traducción por IA,
límite de 120/min y arranque del contenedor con un `PEP_REGISTRATION_TOKEN` válido.
