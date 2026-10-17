---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# STORAGE LIFECYCLE — LB-004B.2H

## Contrato congelado

```text
PURGE_CAPABILITY: REQUIRED
DELETE_PUBLIC_ENDPOINT: NO
PURGE_AUTHORITY: BACKEND / BUSINESS_LIFECYCLE
NUMERIC_RETENTION: DECISION_REQUIRED
COLD_STORAGE_STRATEGY: REQUIRED_TO_DESIGN / NOT_IMPLEMENTED_YET
LOCAL_JVM_SCHEDULER: FORBIDDEN_IN_THIS_MICROPHASE
```

`FileStoragePort.delete` permanece como capability interna para compensación y futura purga. No se
expone `DELETE /api/v1/archivos/**` ni se entrega control de borrado al frontend.

## Autoridad de purga

MinIO no decide por sí mismo cuándo un objeto deja de ser necesario. La decisión final depende del
estado durable del proceso/artefacto en SQL Server:

```text
proceso activo
  -> conservar

artefacto/proceso cerrado + entrega final consolidada
  -> candidato a purga según una política futura aprobada
```

La fecha/edad del objeto MinIO puede ser un insumo operativo, nunca la única autoridad. No se
inventan 30/90/365 días: el plazo permanece `DECISION_REQUIRED`.

## Estrategia posterior

Una microfase futura debe diseñar un worker durable e idempotente con claim/lease o coordinación
equivalente, retry controlado, auditoría y reconciliación entre SQL Server y storage. No se introduce
`@Scheduled`: un scheduler local podría ejecutarse duplicado al escalar réplicas.

Cold storage también requiere diseño posterior: criterios de elegibilidad derivados del lifecycle,
provider/tier soportado, recuperación, costo/SLO, integridad y rollback. No está implementado ni se
presenta como PASS en LB-004B.2H.
