# Módulo de Catálogo de Mensajes — MessageUcoLab (equipo de mensajería)

> **Ámbito:** Infraestructura Transversal, Backend y operación local  
> **Proveedor:** equipo de mensajería (NosGraduamos-FC) · guía v4.0 (octubre 2026)  
> **Versiones:** starter `messageucolab-spring-boot-starter:0.1.1` · imagen `jciro17/messageucolab:0.1.0`  
> **Fecha de integración:** Noviembre 2026  
> **Regla de propiedad:** `Complementos/CatalogoMensajes` es de otro equipo y **no se modifica**. Los problemas se documentan en
> [`FINDINGS_FOR_MESSAGES_TEAM.md`](../work-items/backend/MSG-001-messageucolab-catalog-switch/FINDINGS_FOR_MESSAGES_TEAM.md).

---

## 1. Qué se integró

| Pieza | Dónde | Estado |
| :--- | :--- | :--- |
| Switch de provider `azure` ⇄ `messageucolab` | Backend: `app.adapters.message-catalog.provider` | ✅ Implementado y probado (unit + wiring) |
| Adaptador `MessageUcoLabMessageCatalogAdapter` (+ mapeo de códigos, caché, contingencia Azure) | Backend `infrastructure/adapter/secondary/catalog/messageucolab` | ✅ |
| Composition Root condicionado (`@ConditionalOnProperty`) | Backend `infrastructure/config/adapters/catalog/messageucolab` | ✅ |
| Dependencia Maven + repositorio GitHub Packages | `GestioAsistenciaBackend/pom.xml` | ✅ |
| Orquestación (`messages-up/down/status/ui/switch`) | `AsistenciasUCO-Infra/infra.ps1`, `components/messages/`, `scripts/orchestration/` | ✅ |
| Levantar el stack y validar extremo a extremo | Docker + Doppler + Seguridad | ⏳ Requiere acciones manuales (§3) |

No cambia Domain, Application, contratos HTTP ni el catálogo de mensajes desplegado. El flujo canónico se conserva:
`UseCase → MessageCatalogPort → MessageUcoLabMessageCatalogAdapter → MessageReader (starter) → Kong → MessageUcoLab`.

```text
┌──────────────┐      ┌──────────────────────────┐   public route    ┌──────────────┐   ┌────────────┐
│ Backend :8080│─────▶│ MessageUcoLab Adapter    │──────────────────▶│ Kong :8000   │──▶│ App :8085  │
│ (UseCases)   │ port │  caché 5 min · block 3 s │ X-Application-Id  │ rate 120/min │   │ SurrealDB  │
└──────────────┘      │  └─ fallback → Azure App │ X-Environment-Id  └──────────────┘   │ Redis/Pulsar
                      │     Configuration        │                                       │ Ollama (IA)│
                      └──────────────────────────┘                                       └─────┬──────┘
   Administración de mensajes (pantalla :5174) ──── sesión Keycloak ── PDP/PEP (:18080/:18081) ┘
```

La lectura es **pública** (guía 0.2: "por indicación del profesor"); la administración exige sesión y permisos en el
componente de seguridad, por lo que **MessageUcoLab depende del Security Baseline**.

---

## 2. Reglas de mapeo Asistencias ⇄ MessageUcoLab

| Concepto | Asistencias | MessageUcoLab | Decisión |
| :--- | :--- | :--- | :--- |
| Código | `VAL_001`, `ERR_..._INVALIDA` (hasta 39 car.) | `MSG_` + máx. 10 car. de `[A-Za-z0-9 ]` (**sin `_`**) | Se quitan los no alfanuméricos (`VAL_001` → `MSG_VAL001`) y se antepone `MSG_`; >10 sin alias ⇒ **no se consulta** (no se trunca). Alias en `app.providers.messageucolab.code-aliases` |
| Texto | Una cadena | `title` (10–50) + `content` (10–100) | Se entrega `content` |
| Marcadores | `{}` posicional y `{0}` | `{nombre}` nombrado | El adaptador aplica `{}`/`{0}` con el mismo algoritmo de Azure/SQL |
| Mensaje técnico | `getTechnicalMessage` | Tipo Funcional/Técnico, código único | Se delega a Azure (H-04) |
| Idioma | `es` | Idioma base + traducción IA bajo `?language=` | Solo idioma base |
| Estado | — | Solo mensajes `Activo` se entregan | Crear siempre `Activo` |

**Brecha medida (78 códigos únicos de usuario de `04_mensaje.sql`):** los 78 usan `_` (inválido en MessageUcoLab; se normaliza), 27 exceden 10 caracteres y 2 contenidos exceden 100; **49 son migrables tal cual** y 12 usan `{}`. Mientras el equipo de mensajes no amplíe límites (H-01/H-02), los restantes saldrán de Azure aunque el provider sea `messageucolab` (la contingencia lo cubre).

---

## 3. Puesta en marcha local (pasos manuales + automatizados)

Orden recomendado. Los pasos 1–4 usan la UI de seguridad/Doppler y **no los puede hacer un agente por ti** (credenciales).

1. **Seguridad arriba, siempre primero:** `.\AsistenciasUCO-Infra\infra.ps1 security-up` (Security Baseline 0.1.9 del Backend: PDP 18080, PEP 18081, Keycloak 19090) y `security-ui`. Levantarla antes evita el choque de redes `172.31.x` (H-24).
2. **Permitir la pantalla de mensajes en seguridad** (guía paso 1): ya resuelto. El compose del Backend parametriza los orígenes y `lab.env` incluye `http://localhost:5174`; la guía original (editar el `.env` de `Complementos`) no funciona con el compose 0.1.7 (hallazgo H-23). Ver [`SECURITY_BASELINE_UPGRADE_GUIDE.md`](../hardening/SECURITY_BASELINE_UPGRADE_GUIDE.md).
3. **Registrar MessageUcoLab en seguridad** (guía paso 2): app `MessageUcoLab` (URL base `http://localhost:8000`), carga masiva de las 28 rutas con
   `Complementos/CatalogoMensajes/plantilla-recursos.xlsx` (la guía lo llama `recursos-messageucolab.xlsx`, H-16), rol "Gestor de mensajes" con los 28 recursos y
   asignación a tu usuario (+ `ADMIN`). Guarda la **credencial técnica** (se muestra una vez).
4. **Doppler** (guía paso 3): `winget install Doppler.doppler` → `doppler login` → proyecto `messageucolab-local`, config `dev`, con los 5 secretos
   `SURREALDBUSER`, `SURREALDBPASSWORD`, `REDISPASSWORD`, `GF_SECURITY_ADMIN_PASSWORD` (inventadas, ≥16 car.) y `PEP_REGISTRATION_TOKEN` (la credencial del paso 3).
   Luego, una vez, dentro de `Complementos/CatalogoMensajes/messageucolab-local`: `doppler setup --project messageucolab-local --config dev`
   *(`doppler setup` crea `doppler.yaml`/configuración local; si no quieres escribir en esa carpeta usa `DOPPLER_PROJECT`/`DOPPLER_CONFIG` como variables de entorno.)*
5. **Levantar:** `.\AsistenciasUCO-Infra\infra.ps1 messages-up` (primera vez 5–15 min; descarga imágenes y el modelo llama3.2). Con poca RAM o sin traducción: `messages-up-light` (sin Ollama ni observabilidad; solo falla `?language=`).
   Comprobar: `.\AsistenciasUCO-Infra\infra.ps1 messages-status` → `{"status":"UP"}`.
6. **Pantalla:** `.\AsistenciasUCO-Infra\infra.ps1 messages-ui` → `http://localhost:5174` → crear organización **UCO**, aplicación **Asistencias UCO**,
   una funcionalidad y los mensajes (a mano, o por Excel en "Importación masiva"). Códigos sin `MSG_`, ≤10 caracteres.
7. **Copiar identificadores** (botón del ambiente *Develop*) y activar el switch:
   `.\AsistenciasUCO-Infra\infra.ps1 messages-switch -Mode messageucolab -ApplicationId <uuid> -EnvironmentId <uuid>`
8. **Reiniciar el Backend** y verificar que un mensaje `mensajeUsuario` proviene de MessageUcoLab (el log registra `WARN` solo cuando degrada).

Volver a lo anterior en cualquier momento: `messages-switch -Mode azure` + reinicio.

---

## 4. Seguridad y hardening

* Cero secretos en el repositorio: Doppler inyecta en el proceso; `switch-message-catalog.ps1` solo escribe URL y UUID (no secretos).
* El Backend nunca entrega a Angular una URL del componente: el frontend recibe `mensajeUsuario` desde la API (regla SRP/no-polling).
* La ruta pública no pasa por el PEP (guía FAQ): el Backend no envía sesión de usuario, solo `X-Application-Id` y `X-Environment-Id`.
* El compose del equipo de mensajes **no cumple** el hardening de red del proyecto (puertos en `0.0.0.0`, Kong Admin sin autenticación,
  imágenes `:latest`): ver H-05…H-09. Se usa solo en desarrollo local y se reubica el puerto 8080 de Pulsar (`PULSAR_GENERALPORT=18082`).
* Nunca `docker compose -p messageucolab down -v` (borra todos los mensajes).

---

## 5. Validación y pruebas

Pruebas de la integración (Backend): `MessageUcoLabCodeMapperTest`, `MessageUcoLabMessageCatalogAdapterTest`,
`MessageUcoLabMessageCatalogWiringTest`, `CompositeCatalogInvalidationAdapterTest`, `ProviderAndAdapterPropertiesTest`.
El resultado y las limitaciones (qué sigue `NOT_RUN` hasta levantar el stack real) están en
[`VALIDATION.md`](../work-items/backend/MSG-001-messageucolab-catalog-switch/VALIDATION.md).
Un mock de `MessageReader` **no certifica** el componente real; la evidencia operacional queda pendiente hasta el paso 8 de §3.
