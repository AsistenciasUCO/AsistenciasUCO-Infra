# MV-001 — Golden Path E2E real (reporte)

Estado: **PENDIENTE DE REPETICIÓN MANUAL** — MV-001 **no** se marca PASS. MV-001A corrige los dos defectos frontend que reveló la primera corrida real; hasta repetir el E2E manual (§4) **READY FOR LB-001C = NO**.

Contrato: `docs/contracts/FRONTEND_GOLDEN_PATH_CONTRACT.md` (§8.1 AUTH RELOAD, §10 REALTIME RECOVERY). Checklist original: `docs/work-items/LB-001B.5-frontend-final-verification/MV-001-CHECKLIST.md`. RED congelado: `MV-001A-RED_SNAPSHOT.md`.

## 1. Evidencia E2E ya demostrada (no se reabre)

Corrida real local (frontend + backend + Keycloak + SQL Server), fixture de horario ya existente y sin modificar:

- login Keycloak con Bearer real; `GET /docente/horarios` → 200; grupo, sesiones, estudiantes y asistencias;
- `POST /asistencias/lote` → 201 y persistencia;
- SSE entre dos navegadores: un cambio guardado en A se refleja en B sin F5 (HTTP sigue siendo la fuente de verdad).

## 2. Defectos y corrección (MV-001A)

| Id | Repro real | Causa raíz | Corrección | Estado |
|---|---|---|---|---|
| **MV001-R01** | A y B en el mismo grupo/sesión. B pasa a offline, A guarda, B vuelve a online: B no recupera el cambio perdido sin F5. | `onOnline()` reinicia `reconnectAttempt = 0` y el siguiente intento se anunciaba `CONNECTING`, así que el transporte emitía `RECONNECTING → CONNECTING → CONNECTED`. El sync solo refrescaba con el par consecutivo `RECONNECTING → CONNECTED` (`pairwise`). | `AttendanceRealtimeSyncService`: máquina de estado (`scan`) — tras `RECONNECTING`, el primer `CONNECTED` emite exactamente un refresh y limpia la marca, aunque haya `CONNECTING`/`RECONNECTING` intermedios. `FetchSseRealtimeTransport`: `backoffAttempt` (temporización) separado de `isReconnecting` (semántica) para que `online` reinicie el backoff sin convertir la reconexión en conexión inicial. Sin replay SSE ni `Last-Event-ID`. | **FIXED_BY_MV001A** (validado por tests automáticos; manual pendiente) |
| **MV001-A01** | Login real → `/app/asistencia` → F5 / Ctrl+R: redirige a `/login`. | Access y refresh token solo en signals; tras F5 ambos quedan `null`, `initKeycloak()` devolvía `false` y `authGuard` redirigía. No es backend, Keycloak ni 401. | `AuthService`: refresh token en memoria **+** `sessionStorage['gestio_session_refresh_token']`; `initKeycloak()` restaura con `refreshAccessToken`; rotación persistida; limpieza en `logout`/`clearSession`/`notifySessionExpired`/`BroadcastChannel`. Access token solo en memoria; nada en `localStorage`. | **FIXED_BY_MV001A** (validado por tests automáticos; manual pendiente) |

### MV001-R02 — STALE_SSE_RECOVERY (MV-001B)

| Id | Repro real | Causa raíz | Corrección | Estado |
|---|---|---|---|---|
| **MV001-R02** | Offline → online **real** desde Chrome DevTools: B no recupera el cambio perdido sin F5 (HTTP y DB correctos). | MV001-R01 corrigió la secuencia cuando el transporte detecta `RECONNECTING`. Con un stream zombie el fetch largo no abandona `CONNECTED`; `onOnline` solo hacía `wake?.()`, que es `null` fuera de `waitBeforeReconnect`, así que no había nueva conexión ni refresh HTTP. | `FetchSseRealtimeTransport`: `online` → `forceReconnectCurrentScope` (nueva generation, aborta la anterior, guard anti-duplicado); `markStreamActivity()` en open/cualquier `onmessage` (heartbeat incluido)/evento; watchdog `SSE_STALE_TIMEOUT_MS = 40 s` (heartbeat backend 25 s). Sync: sin cambios de lógica (un refresh HTTP por recovery), solo `console.debug` en dev. | **FIXED_BY_MV001B** · **PENDING_MANUAL_E2E** |

Tests nuevos: A (online con stream bloqueado), B (watchdog), C (heartbeat rearma y no llega a `events$`), D (evento de negocio rearma), E (generation tardía), F (online doble), limpieza en `stop`/`offline`, e integración transporte real → `RealtimeService` → `AttendanceRealtimeSyncService` (`realtime-recovery.integration.spec.ts`, exactamente 1 refresh). Validación MV-001B: `test:ci` 314/314, `coverage:realtime:check` PASSED (líneas 95.38 %, ramas 83.95 %), build producción PASS.

Deuda registrada (no se implementa): **AUTH-PKCE/BFF HARDENING** (`sessionStorage` es un compromiso local de SPA; migrar a Authorization Code + PKCE o BFF con cookie `httpOnly` si entra al alcance productivo) y **TD-049** `USER_PROFILE_VERTICAL_NOT_IMPLEMENTED` (`GET /usuarios/perfil` → 501; `OUT_OF_GOLDEN_PATH`, `NON_BLOCKING`; el comportamiento ya era no bloqueante y no se modificó, solo se añadieron tests).

## 3. Validación automática (2026-09-24)

| Comando | Resultado |
|---|---|
| `npm run test:ci` | **303 / 303 SUCCESS** (línea base 256; +47 tests: 32 RED → GREEN + 15 guardias). Cobertura global stmts 63.42 % (antes 62.66), branches 45.92 % (44.93), functions 49.92 % (49.49), lines 64.51 % (63.76): sin descenso. |
| `npm run coverage:realtime:check` | **PASSED** — líneas 94.79 % (182/192; antes 94.48), ramas 83.10 % (59/71; antes 81.69). Umbrales 90 / 80 sin tocar. |
| `npm run build -- --configuration=production` | **PASS** |

Contrato: SHA-256 de `FRONTEND_GOLDEN_PATH_CONTRACT.md` = `6c25e1f9bcf4db433e37f4e1aa6a5f6c305e30ebd3ae9c907758d96d839cb6db` (`.sha256` regenerado y verificado con `sha256sum -c`). El contrato backend externo no se tocó (`02a17456…db121`, verificado).

Archivos de producción modificados: `attendance-realtime-sync.service.ts`, `fetch-sse-realtime-transport.ts`, `auth.service.ts`. Specs: `attendance-realtime-sync.service.spec.ts`, `fetch-sse-realtime-transport.spec.ts`, `auth.service.spec.ts`.

### Auditoría

| Punto | Resultado |
|---|---|
| OFFLINE→ONLINE REFRESH | PASS (tests A, B, D, E) |
| INITIAL CONNECT NO EXTRA REFRESH | PASS (C + guardia de varios `CONNECTING`) |
| SSE EVENT REFRESH | PASS (D y tests previos) |
| SESSION REFRESH TOKEN | `sessionStorage` únicamente |
| ACCESS TOKEN STORAGE | solo memoria |
| JWT en `localStorage` | 0 |
| F5 RESTORE | PASS (tests B, C, rotación) |
| LOGOUT CLEANUP | PASS (E, F, G, G2, `BroadcastChannel`) |
| BUILD | PASS |

## 4. Repetición manual pendiente (requerida antes de marcar PASS)

Entorno real con dos navegadores A y B (mismo docente titular, mismo grupo y sesión), `USE_MOCKS=false`:

| # | Paso | Esperado |
|---|---|---|
| 1 | Login real, ir a `/app/asistencia`, seleccionar grupo/sesión | Carga normal |
| 2 | A guarda un lote | B se actualiza solo (SSE → HTTP) |
| 3 | B offline (DevTools → Offline) | Estado `RECONNECTING`; sin sondeo |
| 4 | A modifica y guarda | B sigue sin verlo (offline) |
| 5 | B online | Nuevo `GET /realtime/stream` inmediato, luego **un** `GET .../asistencias`; B muestra el cambio **sin F5** (MV001-R01) |
| 6 | En B, F5 / Ctrl+R en `/app/asistencia` | Sigue autenticado en la misma ruta, sin ir a `/login` (MV001-A01); un `POST .../token` con `grant_type=refresh_token` |
| 7 | En DevTools → Application | `localStorage` sin `gestio_access_token` / `gestio_refresh_token`; `sessionStorage` solo con `gestio_session_refresh_token` |
| 8 | Logout | `sessionStorage` sin `gestio_session_refresh_token`; F5 en `/login` no restaura nada |
| 9 | Con sesión abierta en dos pestañas, logout en una | La otra pasa a `/login` y queda sin refresh token persistido |
| 10 | Observar `GET /usuarios/perfil` (501) | No cierra sesión ni bloquea la navegación (TD-049) |

## 5. Límites

Backend modificado: NO. DB modificada: NO. Keycloak modificado: NO. OpenAPI / JPA / Redis / serverless iniciados: NO. Commits: NO. Push: NO. No se ejecutó el E2E real como parte de MV-001A (la repetición manual de §4 es un paso posterior): la validación de MV-001A es automática.
