---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# PLAN — LB-001A: alineación DB ↔ backend del Golden Path de asistencia

Formalización documental a posteriori de un trabajo ya ejecutado y validado. No repite la auditoría.

## Identidad y objetivo

- Fecha de formalización: 2026-09-20. Rol: backend-team.
- Objetivo: alinear el contrato de persistencia SQL Server (vistas/SPs) con las expectativas del backend para asistencia en lote + consulta, según el [protocolo](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md).
- Fuentes: [LINEA_BASE](../../baseline/LINEA_BASE.md), [GOLDEN_PATH_ASISTENCIA](../../baseline/GOLDEN_PATH_ASISTENCIA.md), [ADR-001](../../adr/ADR-001-golden-path-asistencia.md).

## AS-IS y evidencia

| Hecho | Fuente | Límites |
|---|---|---|
| Contrato DB alineado y validado en el repositorio DB | Cierre validado del repositorio DB | Evidencia externa, reportada por el responsable; no reproducida aquí |
| `SqlStoredProcedureContractIT` 20/20; `AsistenciaRepositorySqlServerIT` 6/6 | Integration tests backend | Ídem |

## TARGET

Contrato de persistencia del Golden Path alineado y listo para congelar (ver [CONTRACT_MATRIX](CONTRACT_MATRIX.md)).

## Clase de cambio y alcance de rutas

- Change class: CONTRACT_ANALYSIS (esta formalización: DOCUMENTATION_ONLY).
- Variable principal: alineación DB ↔ backend del contrato de persistencia.
- Allowed (formalización): `docs/work-items/LB-001A-db-backend-asistencia/**`, `docs/baseline/LINEA_BASE.md`.
- Forbidden: `src/**`, `pom.xml`, DB, frontend, `contracts/openapi/**`, `infra/**`.

## Alcance

Contrato de persistencia funcional: columnas expuestas por vistas, batch público, manejo de estado inválido, titularidad, atomicidad y result set del SP.

## No alcance

Contrato HTTP/OpenAPI (LB-001B/C), contrato de errores (TD-030), JPA (LB-002), realtime, frontend.

## Contratos y consumidores afectados

PERSISTENCE: adapters SQL Server del backend. HTTP/SECURITY/REALTIME: sin cambio.

## Riesgos y dependencias

- TD-030 (VAL_003) no invalida la alineación de persistencia pero bloquea el contrato de errores de LB-001C.
- La evidencia no se reproduce en este repositorio.

## Test plan

No aplica nueva ejecución: se registra evidencia ya aprobada ([VALIDATION](VALIDATION.md)).

## Rollback

Revertir el commit documental. No hay cambios de código ni de DB en este repositorio.

## Stop conditions

Ninguna activa. No iniciar LB-001B sin aprobación humana.

## Deuda conocida y validación manual

TD-030 (abierta). MV: ninguna nueva.

## Definition of Ready

READY para formalización documental (evidencia previa aprobada; sin cambio de código).
