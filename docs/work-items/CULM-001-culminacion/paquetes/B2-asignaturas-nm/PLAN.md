# CULM-001 · Paquete B2 — PLAN (asignaturas N:M y ámbito por relación)

> Fecha: 2026-11-06. Fuentes: prompt de culminación §3.8–§3.9, `DECISIONES.md` (DEC-019, DEC-020), `RESEARCH-ASIGNATURA-PLAN.md`, `FINDINGS-{coordinador,docente,decano}.md`.
> Contrato detallado: [`CONTRACT.md`](CONTRACT.md) (versión 2, responde a REVIEW-1). Depende de A (matrícula y los tres SP de ámbito de A.2) y B (horas, sesiones canceladas). Alcance del GREEN: mínimo imprescindible; diferibles en CONTRACT §7. Prefijo de artefactos `culm001_b2nm`.

## Objetivo

1. Una asignatura puede pertenecer a varios planes de estudio (y, por ello, a varios programas) con semestre y carácter (obligatoria/optativa) propios en cada plan.
2. En un grupo con estudiantes de varios programas, cada coordinador ve solo a los estudiantes con `EstudiantePrograma` en su(s) programa(s): listas, asistencias, alertas, fichas, KPIs.
3. Cerrar F-COO-005, F-COO-006, F-COO-008, F-DEC-002, F-DEC-013, F-DEC-014 y F-DEC-015, y rediseñar sobre la relación N:M lo que A corrige de forma inmediata (F-COO-001, F-COO-002, F-COO-003, F-DOC-013).

## Fases SDD

| Fase | Entregable | Gate de salida |
| :--- | :--- | :--- |
| 01 PLAN | este archivo | aprobado por el orquestador |
| 02 CONTRACT | `CONTRACT.md` | revisado por un Opus independiente y congelado (§9.2 del prompt) antes del RED |
| 03 RED | pruebas T-SQL, backend y frontend de `CONTRACT.md` §2.9, §3.7, §4.5 fallando por la razón correcta | evidencia de fallo en `RED.md` |
| 04 GREEN | migración, vistas, SPs, backend, frontend | `db-test`, `mvnw verify`, `npm run verify`, `infra.ps1 verify` en verde |
| 05 AUDIT | revisión independiente + matriz de fugas de ámbito repetida con 2 programas | sin fugas; hallazgos cerrados |
| 06 CLOSURE | `CLOSURE.md` del paquete, HU-CATALOG y PRS.md al día | PRs abiertos hacia `integracion/CULM-001` |

## Orden de trabajo

1. BD: catálogo de carácter, tabla puente, migración `up`/`down` con backfill y reporte, vistas, SPs, permisos, semilla de un segundo programa, pruebas.
2. Backend: entidades/proyecciones de SP, repositorios, casos de uso (JPQL directo → SP), endpoints, clasificador de errores, OpenAPI 1.2.0.
3. Frontend: modelos, servicios, malla con carácter y asociación, listados paginados, selector de programa en matrícula, specs.
4. Docs: HU-CATALOG, deuda técnica, contrato OpenAPI y su `.sha256` en Infra y Backend.

## Riesgos principales

Duplicación de filas por joins 1:N, rebase sobre las vistas que también cambia B, migración destructiva de `Asignatura.semestrePlanEstudio`, y estudiantes sin vínculo de programa que quedarían invisibles. Detalle y mitigación en `CONTRACT.md` §6.
