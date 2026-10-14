---
status: active
type: evidence
scope: backend
owner: backend-team
last-reviewed: 2026-09-24
---

# Evidencia de entrada — LB-001C.1

## Autorización

El responsable autorizó explícitamente en la solicitud del 2026-09-24 iniciar
`LB-001C — API CONTRACT FIRST + SWAGGER`, microfase `LB-001C.1 — API STYLE GOVERNANCE +
OPENAPI/SWAGGER GOLDEN PATH BASELINE`, exclusivamente en el backend y sin commit ni push.

Esta autorización sustituye para esta fase el estado histórico `LB-001C NOT STARTED` de la línea
base. No autoriza LB-001C.2, JPA, cambios de DB/Keycloak/frontend, Redis, RabbitMQ, serverless ni
generación de cliente Angular.

## Estado reportado por el responsable

- DB ↔ backend: `ALIGNED`.
- Backend ↔ frontend: `ALIGNED`.
- MV-001 Golden Path E2E: `PASS`.
- Comprobado: Bearer, restauración tras F5, horarios, grupos, sesiones, estudiantes, consulta y
  lote de asistencias, `AN/SJC/EX`, SSE entre navegadores, offline→online, reconciliación HTTP y
  HTTP como fuente de verdad.
- Fixture temporal MV-001: retirado.
- TD-049 (`/usuarios/perfil` 501) y TD-050 (latencia de reconciliación realtime): abiertas,
  `NON_BLOCKING`.

## Límite de la evidencia

El resultado MV-001 es una certificación externa reportada por el responsable en la orden de
trabajo. El checkout backend no contiene logs, capturas ni enlace a una corrida externa y esta
microfase no reejecuta el frontend/Keycloak/DB. El ledger conserva esa limitación; no se inventan
versiones, registros, timestamps de ejecución ni resultados adicionales.
