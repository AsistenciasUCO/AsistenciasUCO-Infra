---
status: draft-r5
type: plan
work-item: CULM-001
paquete: A
last-reviewed: 2026-11-07
---

# PLAN — CULM-001 paquete A: retiro de solicitudes de ingreso (A.1) y correcciones de la Fase 1 (A.2)

**Objetivo A.1.** Retirar de punta a punta (BD, backend, frontend, docs y E2E) el flujo de solicitudes de ingreso a grupos, por la decisión del responsable del 2026-11-06 (prompt 3.1). HU026, HU053, HU054 y HU055 pasan a `[DESCARTADA]`. La matrícula queda solo por QR/PIN (HU176B) o manual del docente titular (HU050). HU008 se conserva como consulta de oferta y cupos. Aplica DEC-009 (reactivación `I`→`A` en las dos vías, con cupo), DEC-010 (archivo y outbox) y F-COO-004.

**Objetivo A.2.** Corregir los hallazgos críticos y altos asignados a A por el triage (DEC-022, `CORRECCIONES-A.md`):
- ámbito dentro del SP para el directorio de estudiantes y para los estudiantes y asistencias del grupo (`usp_consultar_directorio_estudiantes_paginado`, `usp_consultar_estudiantes_grupo_ambito_paginado`, `usp_consultar_asistencias_grupo_ambito_paginado`);
- salida del administrador de `coordinador/*` y `decano/*`;
- límite de intentos en subidas y asistencia por QR;
- rutas públicas de QR alcanzables sin token;
- ningún 500 (DEC-018 y traducción de errores de consulta);
- retiro del reclamo propio, estado del decano, solape de sesiones, solo la matrícula `A` como inscrita;
- `db-test` en verde (F-000), fixture del segundo ámbito y retiro de stubs 501;
- búsqueda del estudiante a matricular por documento exacto (DEC-027: `usp_buscar_estudiante_por_documento_grupo` y `GET /api/v1/grupos/{grupoId}/estudiantes/busqueda`).

**Revisión.** `REVIEW-1.md` (18 objeciones, 6 bloqueantes) se responde en `CONTRACT.md` §9 y `REVIEW-2.md` (15 objeciones, 4 bloqueantes) en la §10 y `REVIEW-3.md` (6 objeciones, 2 bloqueantes) en la §11; todas atendidas (v5, final). Decisiones aplicadas: DEC-027 (búsqueda por documento y DOCENTE con ámbito en `GET /estudiantes`), DEC-028 (A.1 = migración 13, A.2 = migración 14, semillas 33), DEC-032 (A publica el golden path 1.2.0 con DOCENTE en el `x-roles` de `/api/v1/estudiantes`; sustituye a DEC-030) y DEC-031 (`SES_017` en adelante; ámbito del administrador por institución; grupos mixtos).

**Contratos WORM.** A.1 no toca contratos congelados. A.2 publica el golden path 1.2.0 (DEC-032): solo `x-roles`, la descripción de `GET /api/v1/estudiantes` y la versión de `openapi-golden-path.yaml`, con los `.sha256` de Infra y Backend, las pruebas de conformidad e `infra.ps1 verify`. Commit: `docs(contracts): publicar golden path 1.2.0 con docente en estudiantes` (`CONTRACT.md` §1.4 y A2-C1).

## Orden (mismas ramas `feature/CULM-001-A-retiro-solicitudes` en los 4 repos, desde `integracion/CULM-001`)

1. **A.1, retiro de solicitudes:** DB → Backend → Frontend → Infra (`CONTRACT.md` §2-§6).
2. **A.2, correcciones de la Fase 1:** DB → Backend → Frontend → Infra (`CONTRACT.md` §8), sobre la misma rama, después de que A.1 esté en GREEN en cada capa.

BD y backend se despliegan juntos (R-2). Antes de cada `up`: backup COPY_ONLY nuevo y backend detenido (U-0).

## Fases SDD

| Fase | Entregable | Compuerta |
| :--- | :--- | :--- |
| 01 PLAN | Este archivo | — |
| 02 CONTRACT | `CONTRACT.md`, revisión 2 | Segunda revisión del Opus independiente; sin reabrir las decisiones fijas |
| 03 TEST RED | A.1: T-01..T-13, B-RED-01..09, F-RED-01..08 y la prueba E2E F-COO-004. A.2: A2-T-01..18 (más A2-T-06b), A2-B-01..19, A2-F-01..09. Un commit `test(...)` por repo y subpaquete | Cada prueba RED falla por la razón esperada; las CAR pasan y se etiquetan así. F-000: hipótesis H1 confirmada o descartada con evidencia |
| 04 GREEN | Migraciones `13_culm001_a_retiro_solicitudes_*` (A.1) y `14_culm001_a_correcciones_fase1_*` (A.2), limpieza de `schema/`, backend, frontend y docs; commits de `CONTRACT.md` §6.3 y §8.8 | `db-test` **en verde** (F-000 cerrado); `scripts/tests/test_migracion_13_culm001_a.ps1` sobre la base clonada (compuerta manual, con evidencia en `VALIDATION.md`); `mvnw verify` (JaCoCo ≥ 80/70, sin tocar umbrales); `npm run verify`; `infra.ps1 verify` sin fallos nuevos frente a la línea base |
| 05 AUDIT | Grep de residuos de solicitudes (sin tocar reclamos); `culm1_segundo_ambito.sql` aplicado y matriz de ámbito por API con 0 fugas; sin 500 en `/configuracion/*` ni en la matrícula QR; recorrido en pantalla de los 5 roles en lo que toca A; `curl` de las rutas retiradas → 404 | Cero residuos y cero fugas |
| 06 CLOSURE | `CLOSURE.md` con cifras antes y después (BD, backend, frontend, E2E) y lista de pendientes fuera de Git: `rutas-por-rol.md`, `--prune` del PDP, claves de Azure App Configuration, TD-CULM001-A-01, deuda del 409 local, `SES_017` en la tabla §G y el aviso de numeración a B (R-A2-8) | `HU-CATALOG.md` al día |

## Riesgos principales

A.1: R-1 (historial, outbox y plantillas), R-2 (mapeo posicional de la oferta), R-3 (concurrencia de la reactivación), R-5 (F-COO-004). A.2: R-A2-1 (pantallas que dejan de ver datos al mover el ámbito al SP), R-A2-2 (administrador sin acceso a una pantalla no detectada) y R-A2-3 (valores por defecto que ocultan una configuración rota) y R-A2-7 (la matrícula manual cambia de fuente por DEC-027). Detalle y rollback: `CONTRACT.md` §7 y §8.7.
