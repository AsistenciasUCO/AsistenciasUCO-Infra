---
status: draft
type: plan
work-item: CULM-001
paquete: A
last-reviewed: 2026-11-06
---

# PLAN — CULM-001 paquete A: retiro de las solicitudes de ingreso a grupos

**Objetivo.** Retirar de punta a punta (BD, backend, frontend, docs y E2E) el flujo de solicitudes de ingreso a grupos (HU026, HU053, HU054 y HU055 pasan a `[DESCARTADA]`), por la decisión del responsable del 2026-11-06 (prompt 3.1): la matrícula es solo por QR/PIN (HU176B) o manual del docente titular (HU050). HU008 se conserva como consulta de oferta y cupos.

**Decisiones aplicadas.** DEC-009 (la reactivación `I`→`A` pasa a la matrícula manual y a la de QR, con control de cupo), DEC-010 (archivo `zz_archivo_SolicitudIngresoGrupo` y cancelación del outbox antes de borrar las plantillas) y F-COO-004 (el coordinador no matricula). Las concreciones A-C1..A-C5 están en `CONTRACT.md` §1.2 y las revisa el Opus independiente.

**Contratos WORM.** Sin cambios (verificado con grep, `CONTRACT.md` §1.4).

## Fases SDD

| Fase | Entregable | Compuerta |
| :--- | :--- | :--- |
| 01 PLAN | Este archivo | — |
| 02 CONTRACT | `CONTRACT.md` | Revisión por un Opus independiente; sin reabrir las decisiones fijas |
| 03 TEST RED | T-01..T-13 (BD), B-RED-01..08 (backend), F-RED-01..08 (frontend) y la prueba E2E F-COO-004, en un commit `test(...)` por repo | Cada prueba nueva falla por la razón esperada (no por compilación ajena) |
| 04 GREEN | Migración 13 `up`/`down`, limpieza de `schema/`, backend, frontend y docs; commits atómicos de `CONTRACT.md` §6.3 | `db-test` sin fallos nuevos frente a F-000; `test_migracion_13_up_down.ps1`; `mvnw verify` (JaCoCo ≥ 80/70); `npm run verify`; `infra.ps1 verify` sin fallos nuevos frente a la línea base |
| 05 AUDIT | Grep de residuos (`SolicitudIngreso`, `solicitudes-matricula`, `solicitudes-ingreso`, `SOLICITUD_INGRESO_`, `idSolicitudAbierta`) en los 4 repos, sin tocar reclamos; recorrido en pantalla de estudiante, docente y coordinador; `curl` de las 10 rutas retiradas → 404 | Cero residuos fuera de las notas históricas |
| 06 CLOSURE | `CLOSURE.md` con cifras antes y después (BD, backend, frontend, E2E), rutas de `rutas-por-rol.md` pendientes (fuera de Git), `--prune` del PDP pendiente de aprobación y deudas R-8 y R-9 | `HU-CATALOG.md` al día |

## Orden

DB → Backend → Frontend → Infra, una rama `feature/CULM-001-A-retiro-solicitudes` por repo desde `integracion/CULM-001`. BD y backend se despliegan juntos (riesgo R-2). Antes del `up`: backup COPY_ONLY nuevo y backend detenido (U-0).

## Riesgos principales

R-1 (historial y outbox), R-2 (mapeo posicional de la oferta), R-3 (concurrencia de la reactivación) y R-5 (cambio de una regla certificada por F-COO-004). Detalle y rollback: `CONTRACT.md` §7.
