# MV-001A — RED snapshot (congelado antes de tocar código de producción)

Fecha: 2026-09-24. Comando: `npm run test:ci` (Karma/Jasmine, ChromeHeadless 153).

| Corrida | Resultado |
|---|---|
| Línea base (antes de escribir tests) | 256 / 256 SUCCESS. Cobertura global: stmts 62.66 %, branches 44.93 %, functions 49.49 %, lines 63.76 %. `coverage:realtime:check`: líneas 94.48 % (171/181), ramas 81.69 % (58/71) — PASSED. |
| RED (tests nuevos, producción sin cambios) | 303 tests: **32 FAILED, 271 SUCCESS**. Los 256 originales siguen en verde; los 47 tests nuevos = 32 RED + 15 guardias que ya pasan (regresión). |

Solo se modificaron specs (`attendance-realtime-sync.service.spec.ts`, `fetch-sse-realtime-transport.spec.ts`, `auth.service.spec.ts`). Ningún archivo de producción tocado hasta este punto.

## Firma del defecto MV001-R01 (realtime)

Secuencia real emitida por el transporte tras `offline → online` (test E):

```
Expected [ 'RECONNECTING', 'RECONNECTING', 'CONNECTING', 'CONNECTED' ] not to contain 'CONNECTING'.
```

`onOnline()` pone `reconnectAttempt = 0` y el siguiente intento se anuncia `CONNECTING` (`setState(reconnectAttempt > 0 ? 'RECONNECTING' : 'CONNECTING')`). El sync solo refresca con el par exacto `RECONNECTING → CONNECTED` (`pairwise`), por lo que no refresca:

```
A. CONNECTED → RECONNECTING → CONNECTING → CONNECTED   Expected 0 to be 1.
```

## Tests RED — realtime (11)

Sync (`AttendanceRealtimeSyncService › recuperación tras reconexión (MV001-R01)`):

- A. `CONNECTED → RECONNECTING → CONNECTING → CONNECTED` produce 1 refresh — FAILED (0)
- B. `… RECONNECTING → CONNECTING → RECONNECTING → CONNECTING → CONNECTED` produce 1 refresh — FAILED (0)
- D. tras el refresh de reconexión, un evento `ASISTENCIAS_SESION_ACTUALIZADAS` sigue refrescando — FAILED (1 en vez de 2)
- cada reconexión distinta produce exactamente un refresh — FAILED (1 en vez de 2)
- no duplica el refresh si `CONNECTED` se repite dentro de la misma reconexión — FAILED
- el refresh de reconexión emite aunque no haya grupo/sesión — FAILED

Guardias que ya pasan (no son RED, protegen regresión): C. `DISCONNECTED → CONNECTING → CONNECTED` = 0 refresh; conexión inicial con varios `CONNECTING` = 0 refresh. (El test previo `RECONNECTING → CONNECTED` directo = 1 refresh sigue en verde.)

Transporte (`FetchSseRealtimeTransport › semántica de reconexión (MV001-R01)`):

- E. `offline → online` reconecta como `RECONNECTING`, sin `CONNECTING`/`DISCONNECTED` intermedios — FAILED
- con el reintento tras `online` en vuelo el estado sigue siendo `RECONNECTING` — FAILED (`CONNECTING`)
- `online` reinicia el backoff sin marcar la reconexión como conexión inicial — FAILED
- un 401 durante el reintento de una reconexión conserva `RECONNECTING` — FAILED
- un fallo inicial de red seguido de éxito no vuelve a emitir `CONNECTING` — FAILED (2 en vez de 1)

Guardias que ya pasan: tras `stop()`+`start()` la conexión vuelve a ser inicial; fallo posterior a reconexión exitosa vuelve a `RECONNECTING`; conexión inicial `[DISCONNECTED, CONNECTING, CONNECTED]`.

## Tests RED — auth (21) — MV001-A01

`AuthService › sesión restaurable tras F5 (MV001-A01)`:

- login A: refresh token → `sessionStorage` (`Expected null to be 'refresh-login'`); login sin refresh token descarta el residual de otra sesión.
- initKeycloak tras F5: B. restaura con el refresh de `sessionStorage` (`Expected false to be true`); C. refresh inválido limpia `sessionStorage` (`Expected 'refresh-revocado' to be null`); fallo de red al restaurar limpia; JWT sin rol válido limpia.
- Rotación D: el refresh rotado sustituye al anterior; el siguiente refresh usa el rotado; sin rotación conserva el vigente; la restauración persiste el rotado; refresh explícito persiste; refresh fallido no altera lo persistido.
- Limpieza: E. `logout`, F. `notifySessionExpired`, G/G2. `clearSession` (con/sin broadcast), pestaña receptora de `LOGOUT` y de `SESSION_EXPIRED`, mensaje de broadcast ajeno no cierra la sesión.
- TD-049: login con `GET /usuarios/perfil` = 501 no interrumpe (identidad por claims JWT); la restauración tras F5 no depende del perfil.

Guardias de auth que ya pasan (10; 15 en total con las de realtime): no persistir access token/password/usuario en ningún storage (A2), H. JWT fuera de `localStorage`, `initKeycloak` sin tokens = false sin llamar a Keycloak, nunca restaurar access token desde `sessionStorage`, `sessionStorage` no disponible no rompe el arranque, purga de claves legacy.
