# TEST_PLAN — FIX-002
Spec: `overview.component.spec.ts` (DOCENTE).
1. Invoca con `{ estado: 'P', pagina: 1, tamano: 1 }` y el contador es el `total` del servidor (7).
2. `total: 42` con `datos: []` => 42 (no la longitud de la página).
3. Sin `total` => cae a `datos.length`.
4. Error 501 => `pendingClaimsCount()` es `null` y `isLoading()` false.
Rojo inicial: error TS (la firma esperaba 0 argumentos) / contador 1 en vez de 7.
