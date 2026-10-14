# LB-001C.2B — RED SNAPSHOT

Comando: `ng test --watch=false --browsers=ChromeHeadless` (producción sin modificar; SessionService todavía usa `http.put`).

Resultado: `TOTAL: 3 FAILED, 312 SUCCESS` (315 tests). Los 3 fallos son causales (expected PATCH / actual PUT):

1. `session.service.contract.spec.ts:84` — `Expected 'PUT' to be 'PATCH'.`
2. `golden-path-real-mode.spec.ts` — `PATCH /sesiones/{id} consume ApiDataResponse<Void>...` → `Expected 'PUT' to be 'PATCH'.`
3. `session.service.contract.spec.ts` — `LB-001C.2B: PATCH /sesiones/{id} sin fallback PUT` → `Expected one matching request ... found none. Requests received are: PUT http://localhost:8080/api/v1/sesiones/ses-1.`

Sin otros fallos.
