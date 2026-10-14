# LB-001B.1C final contract cleanup - RED SNAPSHOT

Base frontend:

- Branch: `develop`
- HEAD: `71ee6d32bfe1c6c58c04d0e986e525850ff6eb52`

Backend snapshot:

- Branch: `sergio`
- HEAD: `fa9aa901c73e55ae31071f4e74cfb2245189243a`

## RED files / hashes

- `src/app/core/services/session.service.contract.spec.ts` SHA-256 `EC974E5D2F7079F5D73DAC3165E6C8670B3DEDDA2CBB096B1377C2430DDE72CB`
- `src/app/core/models/attendance.model.contract.spec.ts` SHA-256 `6AAEC27ECF88583BCF9DC95CF2FE848274CC9F731F6623754DF027CCE66B1F83`
- `src/app/features/teacher/teacher-grupos/components/teacher-sesion-form.component.spec.ts` SHA-256 `06010EF4FF09D921A5638510A3760BA93D4A27E3267EE451233C2F4C1AAB78AE`
- `src/app/features/attendance/attendance-control/components/attendance-new-session-modal.component.spec.ts` SHA-256 `EE75CA1FC8EAF076686DCD0653AA81D0B4146F96B723E48D57C45665BDB28910`

## RED command

```powershell
.\node_modules\.bin\ng.cmd test --watch=false --browsers=ChromeHeadless --include=src/app/core/services/session.service.contract.spec.ts --include=src/app/core/models/attendance.model.contract.spec.ts --include=src/app/features/teacher/teacher-grupos/components/teacher-sesion-form.component.spec.ts --include=src/app/features/attendance/attendance-control/components/attendance-new-session-modal.component.spec.ts
```

Exit code: `1`.

Fallo causal esperado:

- `ClassSession` exigía `topic` y `status`.
- `@ts-expect-error` en `updateSession(... { room/topic/status })` quedaba sin usar porque el método aceptaba `Partial<ClassSession>`.

Se clasifica como `TEST_CONTRACT_CONFLICT` resuelto en esta fase: el test anterior esperaba `PUT` con `{ room: 'B-202' }`, contradiciendo el contrato backend actual.
