# CULM-001 · Paquete C — PLAN (cancelación por inasistencia HU026C y SSE por ámbito)

> Fecha: 2026-11-07. Fuentes: prompt de culminación §3.5 (y §3.8–§3.10), `DECISIONES.md` DEC-039 (diseño cerrado), DEC-012/024, DEC-020/031, DEC-022 §1, DEC-028, DEC-032, DEC-037/038; `RESEARCH-MODELO-ACTUAL.md`; contratos congelados de B y B2.
> Contrato detallado: [`CONTRACT.md`](CONTRACT.md) (v1, pendiente de la revisión 9.2). Depende de A, B.1, B.2 y B2 mezclados en `integracion/CULM-001`. Prefijo de artefactos `culm001_c`; migración 19; semillas 40/41.

## Objetivo

1. Avisar al estudiante (correo + SSE + campana) al cruzar la advertencia (15 %) y la pérdida (20 %), calculadas **por horas** y sin contar las excusas; mostrar la advertencia al docente en la planilla.
2. Al cruzar la pérdida, crear una sola revisión por matrícula que el docente titular decide (mantener o proponer, con motivo) y que el coordinador del programa del estudiante resuelve (aprobar ⇒ `CI` y fuera del registro; rechazar ⇒ sigue activo), todo auditado y con el ámbito dentro de los SP.
3. Abrir el SSE a los cinco roles con filtro de ámbito y política de audiencia por tipo, más un canal personal para avisos dirigidos.
4. Cerrar F-EST-S05, F-TRX-005, F-TRX-006 (F-DEC-012) y F-EST-007 (F-EST-S08, F-TRX-007).

## Fases SDD

| Fase | Entregable | Gate de salida |
| :--- | :--- | :--- |
| 01 PLAN | este archivo | aprobado por el orquestador |
| 02 CONTRACT | `CONTRACT.md` | revisión Opus independiente sin objeciones bloqueantes; puntos de §6.4 confirmados; congelado con `CONTRACT.sha256` |
| 03 RED | pruebas de §2.13, §3.9 y §4.8 fallando por la razón correcta | evidencia en `RED.md` |
| 04 GREEN | BD, backend, frontend, contratos | `db-test`, `mvnw verify` (+ IT `-Pintegration`), `npm run verify`, `infra.ps1 verify`, `verify-contracts.ps1` |
| 05 AUDIT | revisión independiente + recorrido en pantalla (escritorio y móvil 375 × 812) con los 5 roles y grupo mixto | sin fugas de ámbito; hallazgos cerrados (rutas nuevas sujetas a B-01) |
| 06 CLOSURE | `CLOSURE.md` del paquete, HU-CATALOG, deuda, `PRS.md`, `ESTADO.md` | PRs hacia `integracion/CULM-001` |

## Orden de trabajo

1. BD: catálogos y tablas → funciones y vistas → motor, consultas, decisión, resolución, audiencias → cierre masivo y resumen del docente → semillas, permisos, migración 19 → pruebas.
2. Backend: `RealtimeEvent` + política + gateway + canal personal → puertos/adaptadores → casos de uso y avisos → invocación tras escrituras y scheduler → controladores, seguridad, catálogo de acceso → contratos (golden path 1.5.0, eventos).
3. Frontend: transporte y canal personal → campana y alertas del estudiante → planilla y bandeja del docente → bandeja del coordinador → suscripciones de grupo.
4. Infra/docs y solicitud de provisión del PDP al responsable (B-01).

## Riesgos principales

Dependencia de B.2/B2, bloqueo B-01 del PDP, volumen del primer pase del job, cierre masivo bloqueado por casos sin decidir, concurrencia del motor y fugas por SSE. Detalle y mitigación en `CONTRACT.md` §6.
