# MSG-001 — Validación

> **Fechas:** 2026-11-02 / 2026-11-03 · **Java 25** · Windows (`JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\jtmp`)  
> Un test con mock **no certifica** el componente real. Lo no ejecutado figura como `NOT_RUN`.  
> Componente probado: MessageUcoLab (imagen `jciro17/messageucolab:0.1.0`, modo ligero sin Ollama) + starter `0.1.1`,
> sobre Security Baseline `0.1.9`.

## 1. Resultados

| # | Verificación | Comando / método | Resultado |
| :-- | :-- | :-- | :--- |
| V-01 | El starter `0.1.1` se descarga de GitHub Packages con el token existente | `curl` + resolución Maven | **PASS** |
| V-02 | Mapeo de códigos (sin `_`, prefijo, alias, límite 10, nulos) | `MessageUcoLabCodeMapperTest` | **PASS** — 8 pruebas |
| V-03 | Adaptador: acierto, `{}`/`{0}`, ausencia, 409, transporte, timeout, sin fallback, técnico, caché, invariantes | `MessageUcoLabMessageCatalogAdapterTest` | **PASS** — 25 pruebas |
| V-04 | Switch de arranque (`messageucolab` registra el adaptador, `azure` no; el starter no impide arrancar con ids vacíos) | `MessageUcoLabMessageCatalogWiringTest` | **PASS** — 4 pruebas |
| V-05 | Invalidación compuesta incluye al adaptador MessageUcoLab | `CompositeCatalogInvalidationAdapterTest` | **PASS** — 10 pruebas |
| V-06 | Properties (provider `MESSAGEUCOLAB`, defaults, timeout/ttl inválidos) | `ProviderAndAdapterPropertiesTest` | **PASS** |
| V-07 | Suite completa + ArchUnit (con el `develop` actualizado) | `.\mvnw.cmd test` | **PASS** — 3038 pruebas, 0 fallos |
| V-08 | Pre-flight de Infra (secretos + contratos WORM, 18 comprobaciones) | `infra.ps1 verify` | **PASS** (tras regenerar con autorización el hash de `usp_generar_sesiones_grupo.sql`) |
| V-09 | Sintaxis de `infra.ps1`, `start-messages.ps1`, `start-security.ps1`, `start-dev.ps1`, `switch-message-catalog.ps1` | `Parser::ParseFile` | **PASS** (0 errores) |
| V-10 | `messages-switch` (estado y activación con ids) | `infra.ps1 messages-switch` | **PASS** |
| V-11 | Gate JaCoCo global y cobertura de clases nuevas (antes del último cambio) | `.\mvnw.cmd verify` | **PASS** — adaptador 62/62 líneas y 43/44 ramas; mapeador 11/11 y 12/12; config 13/13 y 2/2 |
| V-12 | **MessageUcoLab real:** pantalla, org `UCO`, app `Asistencias UCO`, funcionalidad y 6 mensajes en Develop | UI `:5174` | **PASS** |
| V-13 | **Ruta pública real** `GET /messageucolab/v1/public/messages/{code}`: 6 mensajes → 200 con `title`/`content`; `MSG_VAL005` (inexistente) → 404 | `curl` vía Kong | **PASS** |
| V-14 | **Marcador `{}` en MessageUcoLab real:** se acepta al crear y se devuelve intacto (también dos `{}` en un mensaje) | UI + `curl` | **PASS** |
| V-15 | **Adaptador contra el componente real** (starter + HTTP real): resuelve con `{}`, aplica argumentos posicionales, código inexistente y ambiente inexistente degradan sin excepción, código largo sin alias no se consulta | `MessageUcoLabLiveIT` | **PASS** — 5/5, 0 omitidas |
| V-16 | **Backend real arrancado con el switch:** log `Catalogo de mensajes activo: MessageUcoLab (timeout=PT3S, cacheTtl=PT5M, contingencia=AZURE, alias=0)` y `health=200` | `start-backend-baseline.ps1` | **PASS** |
| V-17 | Seguridad: rutas protegidas de MessageUcoLab sin token → 401; rol "Gestor de mensajes" con **28/28** recursos (inicialmente 26/28: ver H-28) | `curl` + API del PDP | **PASS** |
| V-18 | `verify` completo con el código final (suite + gate de cobertura) | `.\mvnw.cmd verify` | **PASS** — 3039 pruebas, 0 fallos, `All coverage checks have been met`. Adaptador 62/62 líneas y 43/44 ramas; mapeador 12/12 y 12/12; configuración 16/16 y 2/2; properties 11/11 y 15/16. `MessageUcoLabLiveIT` no entra en este comando (es opt-in) |
| V-19 | **Importación masiva desde Excel (plantilla oficial):** 42 mensajes migrables validados en Develop con 0 errores y confirmados (`count=42`). Excluidos: `GEN001/GEN003/VAL001/GEN004/VAL002/VAL006` (ya existían, la validación los rechazó con "Ya existe un mensaje con el mismo código") y `VAL005` (la prueba viva exige que no exista). Títulos provisionales `Mensaje <CODIGO>` | UI-API `/messages/imports/{validate,confirm}` | **PASS** |
| V-20 | Prueba viva ampliada con mensajes importados (`VAL_003`, `CORR_001`) | `MessageUcoLabLiveIT` | **PASS** — 6/6, 0 omitidas |
| V-21 | **Error HTTP real del Backend con texto de MessageUcoLab (cierra N-D):** `PUT /api/v1/admin/areas/{id inexistente}` con token PKCE real de `uco-administrador` → `404`, `code=ARE_001`, `message="El área de conocimiento especificada no existe en el sistema."` (con tilde: el texto por defecto del código Java va sin tilde, así que proviene del catálogo). Kong registra `GET /public/messages/MSG_ARE001 → 200` desde `ReactorNetty` en el mismo instante. Un primer intento dio `503 ACCESS_DECISION_UNAVAILABLE` (intermitencia PEP→PDP, H-31) y el reintento respondió | `err_real.py` (scratchpad) + log de Kong | **PASS** |

## 2. Defectos propios hallados y corregidos durante la validación

| # | Defecto | Efecto | Corrección |
| :-- | :-- | :-- | :-- |
| D-1 | El mapeador conservaba el `_` en el código remoto (`MSG_VAL_001`) | MessageUcoLab **rechaza** `_`; ninguno de los 78 códigos era consultable | Se quitan los no alfanuméricos (`MSG_VAL001`); tests actualizados porque su suposición era errónea |
| D-2 | Cifras de H-01/H-02 inflaladas (150 códigos / 54 largos) | Contaba la tabla técnica y duplicados | Recalculado sobre los **78** códigos de usuario únicos |
| D-3 | 2 de 28 concesiones del rol no se registraron y yo había informado "25 de 25" | `403` al crear mensajes | Concedidas y verificadas contra el PDP (28/28) |
| D-4 | `infra.ps1` no declaraba `-ApplicationId`/`-EnvironmentId` | `messages-switch` documentado no funcionaba | Parámetros agregados |
| D-5 | `start-messages.ps1` tomaba un aviso de Compose por stderr como error fatal | El arranque abortaba | `$ErrorActionPreference='Continue'` y validación por código de salida |

## 3. Cobertura funcional de lo que NO se probó (NOT_RUN)

| # | Pendiente | Motivo |
| :-- | :-- | :-- |
| N-A | Traducción por IA (`?language=en`) y conservación de `{}` al traducir | Se levantó en **modo ligero** (sin Ollama) |
| N-B | Respuesta del servicio ante `409` por ids cruzados de aplicación/ambiente | Requiere una segunda aplicación; el cliente degrada ante cualquier error (probado con ambiente inexistente) |
| N-C | Límite de 120 peticiones/min del gateway | No se saturó; la caché local (TTL 5 min) lo mitiga |
| N-D | ~~Un `mensajeUsuario` de MessageUcoLab visto dentro de una respuesta HTTP de error del Backend~~ **Resuelto: ver V-21** | Los códigos de error del Backend son largos (`ERR_DOCENTE_NO_EXISTE`) y requieren alias o un cambio de límites (H-01); el adaptador y el proveedor activo sí están verificados (V-15, V-16) |
| N-E | Contingencia a Azure App Configuration real | Sin credencial de Azure en la sesión; se prueba con dobles |
| N-F | Frontend Angular en navegador contra el Backend en `baseline` | Solo se verificó por API (login PKCE por rol, 15/15 decisiones) |

## 4. Limitaciones

* La pantalla `:5174` y el Backend corren en ventanas de PowerShell minimizadas de esta sesión.
* Los `lab.env` y credenciales viven fuera de Git (`%USERPROFILE%\.asistencias-security-lab`, `.asistencias-messageucolab`).
