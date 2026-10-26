# VALIDATION — FIX-002
- `npm run test:ci`: 850 tests, 849 OK, 1 FALLO ajeno: `DeanInfraestructuraComponent carga áreas, sedes y espacios...` (`dean-infraestructura.component.spec.ts:58`, no tocado por este cambio; requiere revisión aparte). Los 4 casos del overview pasan.
- `npm run build`: OK (0 errores).
- Sin `any` nuevos, sin polling, OnPush intacto.
- Pendiente: commit/push sin realizar (requiere aprobación).
