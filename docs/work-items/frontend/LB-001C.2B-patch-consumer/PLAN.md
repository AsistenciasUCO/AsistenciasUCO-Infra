# LB-001C.2B — PLAN
EXPAND (backend C.2A) → MIGRATE (frontend C.2B) → VERIFY (C.2C) → RETIRE PUT (futuro).
OpenAPI backend verificado: SHA 72a3097b…da54 (coincide).
1. Inventario (ver CONSUMER-INVENTORY). 2. RED: tests esperan PATCH. 3. `http.put`→`http.patch` en `SessionService.updateSession` (URL, body, tipo de retorno, validación, mocks intactos; sin fallback PUT). 4. Actualizar FRONTEND_GOLDEN_PATH_CONTRACT + sha. 5. `npm run verify`.
Fuera de alcance: auth, realtime, retirada de PUT backend, deudas backend (405→500, 403 CSRF sin Bearer).
