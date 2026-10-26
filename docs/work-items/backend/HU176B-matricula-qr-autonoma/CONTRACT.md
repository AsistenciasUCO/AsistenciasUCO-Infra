---
status: draft
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-21
---

# CONTRACT — HU176B: Matrícula autónoma por QR/PIN

> **Work Item:** `HU176B-matricula-qr-autonoma`
> **Estado:** `DRAFT` (sin `.sha256`). Pasa a `CONTRACT_FROZEN` cuando el owner apruebe D1–D9 del [PLAN](PLAN.md) y lo apruebe seguridad.
> **Supuestos del borrador:**
> - D1(a): HU175 queda fuera.
> - D2(a): ventana que el docente abre y cierra, con TTL por parámetro.
> - D3(a): la matrícula queda activa.
> - D4(a): QR generado en el backend con ZXing.
> - D5(a): solo se usan proxies confiables.
> - D6(a): se retira el SP autónomo.
> - D7(a): rate limit en memoria.
> - D8(b): se reutiliza el formulario de `register`.
> - D9(a): con interruptor.

---

## 1. Matriz AS-IS / TARGET

| Elemento | AS-IS | TARGET | Compatibilidad |
|---|---|---|---|
| `dbo.TokenMatriculaGrupo`, `dbo.uv_token_matricula_grupo` | — | Nuevos (§2.2) | Aditivo |
| `usp_abrir_ventana_matricula_grupo`, `usp_cerrar_ventana_matricula_grupo` | — | Nuevos (§2.3) | Aditivo |
| `usp_validar_token_matricula_publico` | — | Nuevo (§2.4) | Aditivo |
| `usp_matricular_estudiante_por_token` (+ `usp_internal_resolver_token_matricula`) | — | Nuevos (§2.5) | Aditivo |
| `usp_registrar_estudiante_en_grupo_autonomo` | Existe, sin RBAC | Se retira | Sin consumidores |
| `POST/DELETE /api/v1/grupos/{grupoId}/matricula-qr` | — | Nuevos (§3.1, §3.2) | Aditivo |
| `POST /api/v1/public/matricula-qr/validar`, `POST /api/v1/public/matricula-qr/registro` | — | Nuevos, **públicos** (§3.3, §3.4) | Aditivo |
| `POST /api/v1/estudiante/matricular-grupo` | 501 | Implementado (§3.5) | El body cambia (antes nadie lo recibía) |

---

## 2. Base de Datos

### 2.1 Reglas comunes

Son las reglas del contrato del grupo A, §2.1:
- `XACT_ABORT`, transacción y savepoint;
- evaluar `IS NULL`;
- lecturas sobre vistas y escrituras en `usp_internal_*`;
- mensajes por código y tupla canónica en los comandos.

**Excepción declarada:** `usp_validar_token_matricula_publico` y el modo público de `usp_matricular_estudiante_por_token` **no tienen ejecutor**. Su credencial es el **hash del token** (o el PIN) de una ventana activa. Las demás validaciones (grupo, cupo, cruce, prerrequisitos) se mantienen.

### 2.2 Tabla `dbo.TokenMatriculaGrupo` (migración + `schema/tables/`)

```sql
id UNIQUEIDENTIFIER PK,
grupo UNIQUEIDENTIFIER NOT NULL -> FK Grupo(id),
docenteEmisor UNIQUEIDENTIFIER NOT NULL -> FK Docente(id),
tokenHash VARBINARY(32) NOT NULL,           -- SHA-256 del token (el token en claro nunca se guarda)
pin NCHAR(6) NOT NULL,                       -- solo dígitos
estado NVARCHAR(10) NOT NULL,                -- ACTIVA / CERRADA / EXPIRADA, desde los parámetros MATRICULA_QR/ESTADO_*
fechaEmisionUtc DATETIME2(0) NOT NULL,
fechaExpiracionUtc DATETIME2(0) NOT NULL,
fechaCierreUtc DATETIME2(0) NULL,
totalMatriculas INT NOT NULL DEFAULT 0,
CONSTRAINT UQ_TokenMatriculaGrupo_tokenHash UNIQUE (tokenHash)
-- índice filtrado: UNIQUE (pin) WHERE estado = 'ACTIVA'  (el literal del índice es un valor del catálogo, documentado como la única excepción técnica)
-- índice filtrado: UNIQUE (grupo) WHERE estado = 'ACTIVA' (una ventana activa por grupo)
```

`uv_token_matricula_grupo` expone:
- todos los campos, salvo `tokenHash`;
- `estaVigente = IIF(estado = ACTIVA AND SYSUTCDATETIME() < fechaExpiracionUtc, 1, 0)`;
- los datos del grupo para mostrar: `nombreAsignatura`, `nombreGrupo`, `nombreDocente`, `cupoDisponible`.

> Si el owner no acepta el literal en los índices filtrados, la unicidad se garantiza solo en el SP, con `UPDLOCK, HOLDLOCK`, y se pierde la garantía física (decisión técnica que se documenta en la fase 02).

### 2.3 Ventana del docente

**`usp_abrir_ventana_matricula_grupo`**:
- Parámetros:
  - `@idGrupo`, `@tokenHash VARBINARY(32)`, `@pin NCHAR(6)`, `@idCorrelacion`, `@idUsuarioEjecutor`.
  - El token y el PIN los genera el backend con `SecureRandom`; la DB solo recibe el hash.
- Validaciones:
  - RBAC `DOCENTE` + titularidad `GRUPO` (el docente debe ser titular);
  - el grupo está activo y tiene cupo (`usp_validar_cupo_disponible_grupo_interno`).
- Efectos:
  - **cierra** cualquier ventana `ACTIVA` del grupo;
  - inserta la nueva con `fechaExpiracionUtc = DATEADD(MINUTE, <MATRICULA_QR/TTL_MINUTOS>, SYSUTCDATETIME())`.
- Errores: PIN repetido entre las ventanas activas → `MQR_006` (el backend reintenta con otro PIN).
- Resultset: la tupla canónica + `idVentana` + `fechaExpiracionUtc` (extensión documentada del resultset de comando).

**`usp_cerrar_ventana_matricula_grupo`**:
- Parámetros: `@idGrupo`, `@idCorrelacion`, `@idUsuarioEjecutor`.
- RBAC y titularidad iguales.
- Pasa la ventana activa a `CERRADA` y registra `fechaCierreUtc`.
- Es idempotente: sin ventana activa, responde éxito sin cambios.

### 2.4 `usp_validar_token_matricula_publico` (consulta, sin ejecutor)

- Parámetros: `@tokenHash VARBINARY(32) = NULL` | `@pin NCHAR(6) = NULL` (exactamente uno), `@idCorrelacion`.
- Delega en `usp_internal_resolver_token_matricula`, que expira de forma perezosa las vencidas: si `estado = ACTIVA` y ya pasó la expiración, la marca `EXPIRADA` dentro de su propia transacción corta.
- **Resultset de lectura:** `idGrupo`, `nombreAsignatura`, `nombreGrupo`, `nombreDocente`, `fechaExpiracionUtc`, `cupoDisponible`.
- Si el token o el PIN no existe, venció o está cerrado: `THROW` con `MQR_001`, el **mismo mensaje** en todos los casos (anti-enumeración).

### 2.5 `usp_matricular_estudiante_por_token`

| Parámetro | Tipo | Modo | Regla |
|---|---|---|---|
| `@tokenHash` / `@pin` | | ambos | Exactamente uno; debe resolver una ventana vigente (`MQR_001`) |
| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER = NULL` | **autenticado** si no es NULL | RBAC `ESTUDIANTE`. El estudiante es el del ejecutor |
| `@idTipoIdentificacion`, `@numeroIdentificacion INT`, nombres, `@correo`, `@password` (hash) | | **público** si `@idUsuarioEjecutor` es NULL | Reglas de `usp_sincronizar_usuario_interno`. Si el documento o el correo ya existen → `MQR_005` ("Ya tienes una cuenta: inicia sesión para matricularte"), sin cambios |
| `@idCorrelacion` | | ambos | |

Flujo (una transacción):
1. Resuelve la ventana con `UPDLOCK` (`usp_internal_resolver_token_matricula`).
2. Solo en modo público: `usp_sincronizar_usuario_interno` (**activo**, `correoConfirmado = 0`) y luego `usp_sincronizar_estudiante_interno`.
3. `usp_registrar_estudiante_en_grupo_interno` con `@codigoEstado` = valor del parámetro `MATRICULA_QR / ESTADO_MATRICULA` (D3). Valida cupo, cruce, duplicado (si ya está → `MQR_004`), prerrequisitos y `EstudiantePrograma`.
4. `UPDATE TokenMatriculaGrupo SET totalMatriculas += 1`.
5. Éxito: `GEN_004` ("Matricula").

**Resultset:** la tupla canónica + `idEstudiante`, `idUsuario` e `idGrupo` (extensión documentada) para aprovisionar la identidad y publicar el evento.

### 2.6 Parámetros (`03_parametro.sql` / App Configuration `asistencias:matricula-qr:*`) y mensajes (`04_mensaje.sql`)

**Parámetros:**
- `MATRICULA_QR/TTL_MINUTOS` = 15
- `MATRICULA_QR/ESTADO_MATRICULA` = `A`
- `MATRICULA_QR/ESTADO_ACTIVA` / `ESTADO_CERRADA` / `ESTADO_EXPIRADA`
- App Configuration (backend):
  - `asistencias:red:cidrs-campus` (lista CIDR)
  - `asistencias:red:proxies-confiables` (lista CIDR)
  - `asistencias:matricula-qr:habilitada` (bool)
  - `asistencias:matricula-qr:limite-ip-por-minuto` = 20
  - `asistencias:matricula-qr:limite-registros-token-por-minuto` = 5

**Mensajes:**

| Código | HTTP | Mensaje (propuesta) |
|---|:-:|---|
| `MQR_001` | 404 | El código de matrícula no es válido o ya no está disponible. Solicítale al docente uno nuevo. |
| `MQR_002` | 403 | La matrícula por código solo está disponible desde la red Wi-Fi del campus UCO. |
| `MQR_003` | 429 | Demasiados intentos. Espera un momento antes de volver a intentarlo. |
| `MQR_004` | 409 | Ya estás matriculado en este grupo. |
| `MQR_005` | 409 | Ya tienes una cuenta registrada. Inicia sesión para completar tu matrícula. |
| `MQR_006` | 409 | (técnico) PIN repetido entre ventanas activas; el backend reintenta. |
| `MQR_007` | 400 | Debes indicar el código QR o el PIN, pero no ambos. |

Los errores de cupo, cruce y prerrequisitos reutilizan los códigos actuales del interno de HU050.

---

## 3. HTTP

### 3.1 `POST /api/v1/grupos/{grupoId}/matricula-qr` (docente)

- **Rol:** `DOCENTE`. Necesita una regla nueva en `SecurityConfig`: `HttpMethod.POST, "/api/v1/grupos/*/matricula-qr"` → `DOCENTE`, **antes** del comodín `POST /api/v1/grupos/**` (COORDINADOR, ADMIN) de la línea 190.
- **Use case:** valida la titularidad con `InstitutionalScopePort.canDocenteAccessGrupo` (403) y genera:
  - un `token` de 32 bytes aleatorios en Base64URL;
  - un `pin` de 6 dígitos;
  - el `tokenHash` = SHA-256.

  Después llama a `TokenMatriculaCommandPort.abrir` (reintenta hasta 5 veces si recibe `MQR_006`) y genera el PNG con `CodigoQrGeneratorPort.generarPng(urlMatricula, 320)`.
- **URL del QR:** `urlMatricula = <asistencias:frontend:url-base>/matricula/qr?t=<token>`.
- **201** `ApiDataResponse<VentanaMatriculaResponse>`:
  ```json
  { "idVentana": "uuid", "pin": "482913", "urlMatricula": "https://…/matricula/qr?t=…", "qrPngBase64": "iVBORw0…", "fechaExpiracionUtc": "2026-10-21T15:19:00Z" }
  ```
  El token en claro **solo** sale en esta respuesta (dentro de la URL y del QR); no se puede consultar después. Regenerar = volver a abrir.
- **Errores:** 401, 403, 404 (grupo), 409 (sin cupo), 404 si el interruptor está apagado (D9).

### 3.2 `DELETE /api/v1/grupos/{grupoId}/matricula-qr` (docente)
- **200** `ApiDataResponse<Void>`. Errores: 401, 403.
- Regla en `SecurityConfig` para `DELETE` con `DOCENTE`, antes de la línea 192.

### 3.3 `POST /api/v1/public/matricula-qr/validar` (**público**)

- **Request:** `{ "token": "…" }` o `{ "pin": "482913" }`.
- **Orden de los filtros:**
  1. Interruptor (D9): si está apagado → 404.
  2. Rate limit por IP → 429 `MQR_003`.
  3. Red del campus (`RedInstitucionalPort.perteneceACampus(ip)`) → 403 `MQR_002`.
  4. Validator de forma → 400 `MQR_007`.
  5. Use case: hash SHA-256 del token y SP §2.4.
- **200** `ApiDataResponse<CursoMatriculaQrResponse>` = `{ nombreAsignatura, nombreGrupo, nombreDocente, fechaExpiracionUtc, cupoDisponible }`.
- **Errores:** 404 `MQR_001` (genérico), 403, 429, 400.

### 3.4 `POST /api/v1/public/matricula-qr/registro` (**público**, crea la cuenta)

- **Request:**
  ```json
  { "token": "…", "idTipoIdentificacion": "uuid", "numeroIdentificacion": "1017555444",
    "primerNombre": "Ana", "segundoNombre": null, "primerApellido": "Gómez", "segundoApellido": null,
    "correo": "ana.gomez@uco.edu.co", "password": "<inicial>" }
  ```
  Se acepta `pin` en lugar de `token`.
- **Filtros:** los mismos de §3.3, más el rate limit por token.
- **Validator:** documento en rango `INT` y contraseña según `PasswordRegistroRule`, sin contraseña por defecto.
- **Use case:**
  1. Codifica la contraseña.
  2. Llama a `usp_matricular_estudiante_por_token` en modo público.
  3. `crearCuenta(..., ESTUDIANTE)` con la contraseña en claro; si falla, aplica el desfase de IAM-001.
  4. Publica `ESTUDIANTE_MATRICULADO`.
- **201** `ApiDataResponse<MatriculaQrResultadoResponse>` = `{ nombreAsignatura, nombreGrupo, usuario: "<numeroIdentificacion>", mensajeUsuario }`. **No** devuelve un token de sesión: el front redirige a `/login` con el usuario precargado.
- **Errores:** 400, 403, 404 `MQR_001`, 409 (`MQR_004`, `MQR_005`, cupo, cruce, prerrequisitos), 429, 500 controlado (`IAM_001`).

### 3.5 `POST /api/v1/estudiante/matricular-grupo` (estudiante autenticado)

- **Rol:** `ESTUDIANTE` (ya cubierto por `/api/v1/estudiante/**`, línea 142).
- **Request:** `{ "token": "…" }` o `{ "pin": "…" }`.
- **Filtros:** red del campus (403 `MQR_002`) + validator. Sin rate limit público, porque ya hay JWT.
- **Use case:** SP §2.5 en modo autenticado (`@idUsuarioEjecutor` = actor) y luego el evento.
- **201** `ApiDataResponse<MatriculaQrResultadoResponse>`.
- **Errores:** 400, 401, 403, 404, 409.

### 3.6 Seguridad y filtros

- `SecurityConfig`: `.requestMatchers(HttpMethod.POST, "/api/v1/public/matricula-qr/validar", "/api/v1/public/matricula-qr/registro").permitAll()`. Es la **única** apertura pública de negocio; se declara **explícita**, sin comodín `/public/**`.
- CSRF: hoy los endpoints son stateless con Bearer. Los públicos no usan cookies de sesión, así que no aplica token CSRF. Se verifica en el RED que la configuración actual no lo exija.
- `PublicEndpointRateLimitFilter` (`OncePerRequestFilter`) solo actúa sobre `/api/v1/public/**`. Lleva un mapa de ventanas deslizantes con expiración, de tamaño acotado (protección de memoria). Las claves son el **hash** de la IP y el hash del token.
- `ClientIpResolver.resolveClientIp(request)` aplica D5. **El valor para el log sigue saneado**: el valor de red y el de log son métodos distintos.
- `RedInstitucionalPort.perteneceACampus(String ip)` (aplicación) → `CidrRedInstitucionalAdapter`:
  - soporta IPv4 e IPv6 y CIDR;
  - si no hay rangos configurados, **niega** (fail-closed);
  - recarga los rangos ante un cambio en App Configuration (patrón `uco-azure` / `uco-catalogos`).

### 3.7 Capas

- **Entrada:** `MatriculaQrPublicaController` / `GrupoMatriculaQrController` / `EstudiantePortalController` → `{AbrirVentana|CerrarVentana|ValidarToken|RegistrarPorMatriculaQr|MatricularEstudianteAutenticado}InputPort` → `*Interactor` → `*UseCaseImpl`.
- **Salida:**
  - `TokenMatriculaCommandPort` / `TokenMatriculaQueryPort` → `TokenMatriculaJpaRepository` (`JpaProcedureExecutor` / native `EXEC`);
  - `RedInstitucionalPort`, `CodigoQrGeneratorPort` (ZXing), `TokenGeneratorPort` (`SecureRandom` + SHA-256), `PasswordEncoderPort`, `IdentityProviderPort`, `RealtimePublisherPort`.
- **Wiring:** `MatriculaQrWiringConfiguration`.

---

## 4. Frontend

| Elemento | Contrato |
|---|---|
| `app.routes.ts` | Rutas **sin** `authGuard`: `matricula/qr` y `matricula/pin` → `MatriculaQrComponent` (lazy). Se elimina la ruta `register` (D8) |
| `core/models/matricula-qr.model.ts` | `VentanaMatricula`, `CursoMatriculaQr`, `RegistroMatriculaQrPayload`, `MatriculaQrResultado` |
| `core/services/matricula-qr.service.ts` | Métodos `abrirVentana(grupoId)`, `cerrarVentana(grupoId)`, `validar({token}\|{pin})`, `registrar(payload)` y `matricularAutenticado({token}\|{pin})`. Signals: `ventanaActiva = signal<VentanaMatricula \| null>(null)` |
| `features/public/matricula-qr/matricula-qr.component.ts` | Standalone y OnPush. Lee `t` de la query y luego borra el token de la URL (`history.replaceState`, R5). Tiene tres estados con signals (`validando`, `curso`, `error`) y dos acciones: **Crear cuenta y matricularme**, con el formulario reutilizado de `register` (D8) dentro de un subcomponente con `input()` / `output()`, y **Ya tengo cuenta**, que lleva a `/login?returnUrl=/app/estudiante/materias&matricula=<pin>` (se pasa el PIN, no el token). Muestra los errores tal cual (`message`) |
| `features/student/student-courses` | El query param `matricularGrupo` se reemplaza por `matricula` (PIN). Llama a `matricularAutenticado({pin})`. El modal de código acepta solo un PIN de 6 dígitos |
| `teacher-matricula-modal.component.ts` | `grupoId = input.required<string>()`. Al abrir llama a `abrirVentana`. Muestra `<img [src]="'data:image/png;base64,' + ventana().qrPngBase64">`, el PIN en grande, "Válido hasta HH:mm" (hora absoluta, **sin** contador con timers) y los botones **Cerrar** y **Generar nuevo código**. **Se retira** `api.qrserver.com` |
| `teacher-grupo-estudiantes.component.ts` | Se suscribe a `RealtimeService` y filtra `type === 'ESTUDIANTE_MATRICULADO' && payload.idGrupo === grupoId()`; luego vuelve a pedir el roster. Sin `setInterval` |
| Reglas | OnPush, `input()` / `output()`, sin `bypassSecurityTrust*`, sin generar ids en el cliente, sin parsear errores |

## 5. Realtime

```json
{ "type": "ESTUDIANTE_MATRICULADO", "payload": { "idGrupo": "uuid", "origen": "QR" } }
```

Se publica después del commit con `RealtimePublisherPort.publish`, que nunca lanza excepción (contrato actual). **Sin PII**, porque el adapter actual no filtra por destinatario (riesgo R6 del PLAN).

## 6. Observabilidad

Se trazan los eventos `MATRICULA_QR_*` y el contador `matricula_qr_total{resultado=ok|red_rechazada|rate_limit|token_invalido|conflicto}` (PLAN §3).

**Prohibido** loguear el token, el PIN, la contraseña, el documento o el correo.

## 7. Aprobación

| Rol | Estado | Fecha |
|---|---|---|
| Owner del producto (D1–D9) | ⏳ | — |
| Seguridad (endpoints públicos, rate limit, red) | ⏳ | — |
| Infra (rangos de red y proxies) | ⏳ | — |
| Congelamiento | ⏳ | — |
