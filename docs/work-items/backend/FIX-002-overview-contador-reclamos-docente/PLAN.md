# FIX-002 — Contador de reclamos pendientes del overview docente

Relacionado: HU035 (AC-04).

## Problema
`overview.component.ts` (rol DOCENTE) llamaba `getReclamosDocente()` sin argumentos y contaba `PENDIENTE` sobre la primera página (10 filas): el contador quedaba truncado. El `subscribe` no manejaba error, y el servicio ya propaga 404/501.

## Cambios (frontend)
- `overview.component.ts`: `getReclamosDocente({ estado: 'P', pagina: 1, tamano: 1 })` y `pendingClaimsCount = res.total ?? res.datos.length`. En error: `pendingClaimsCount = null`.
- `pendingClaimsCount`: `signal<number | null>`; inputs de `overview-teacher` y `overview-hero` aceptan `null`.
- `overview-teacher`: con `null` muestra `—` y oculta el texto de estado (sin mensajes inventados). `overview-hero` oculta la insignia.

## Sobrecarga sin argumentos
Se **conserva** `getReclamosDocente()`: aún la usan `attendance-control.component.ts` y `teacher-grupos.component.ts`. Retirarla exige migrar esos consumidores (fuera de alcance).
