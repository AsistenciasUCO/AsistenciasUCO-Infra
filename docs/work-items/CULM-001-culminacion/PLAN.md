# CULM-001 — Culminación y certificación de AsistenciasUCO

> **Fuente de las instrucciones:** `docs/PROMPT_FABLE_CULMINACION.md` (workspace raíz, fuera de Git), redactado el 2026-11-06.
> **Orquestador:** Claude Fable 5.1. **Fecha de inicio:** 2026-11-06. **Fecha objetivo:** 2026-11-13.
> **Ramas:** `integracion/CULM-001` en los 4 repos (desde `origin/develop`); una rama `feature/CULM-001-<paquete>-<tema>` por paquete y repo con PR hacia la rama de integración.

## Objetivo

1. Validar las vistas y flujos de los 5 roles (Estudiante, Docente, Coordinador, Decano, Administrador), incluidas notificaciones, alertas y SSE.
2. Corregir lo que falle con TDD, sin relajar pruebas.
3. Implementar las decisiones de producto del 2026-11-06 (secciones 3.1–3.11 del prompt).
4. Pulir UX/UI de todos los roles (móvil primero para el estudiante).
5. Certificar: gates verdes, `HU-CATALOG.md` al día y `CLOSURE.md`.

## Fases

| Fase | Contenido | Responsable |
| :--- | :--- | :--- |
| 0 | Worktrees, entorno en modo Security Baseline, logins, gates de línea base, work item | Orquestador |
| 1 | Auditoría por rol (5 líderes Sonnet + líder transversal; probadores Haiku) → `FINDINGS.md` | Subagentes |
| 2 | Paquetes A → B → B2 → C → D → E con SDD/TDD (PLAN → CONTRACT → RED → GREEN → AUDIT → CLOSURE) | Subagentes Opus/Sonnet; contratos revisados por un Opus independiente |
| 3 | Certificación: recorrido de Fase 1 repetido, concurrencia QR, gates, catálogo, `CLOSURE.md`, PRs finales hacia `develop` | Orquestador |

## Paquetes de la Fase 2

| Paquete | Alcance | Depende de |
| :--- | :--- | :--- |
| A | Retiro de solicitudes de ingreso a grupos (3.1) + hallazgos críticos/altos de la Fase 1 | Fase 1 |
| B | Tomas por horas, QR de asistencia rotativo, ventana de sesión, estado de sesión cancelada y festivos (3.2–3.4, 3.7, HU175, HU176, HU047) | A |
| B2 | Asignaturas en varios planes/programas y ámbitos por relación (3.8, 3.9) | B |
| C | Flujo de cancelación por inasistencia (3.5, HU026C) | B, B2 |
| D | HUs pendientes (3.6): HU026B, HU047 (si no entró en B), HU015/LB-004D, HU168, HU156, HU171; hallazgos medios | — |
| E | Tokenización de la identidad visual (3.11) y luego pulido UX/UI y responsive por rol (3.10) | — (puede ir en paralelo con A) |

## Orden de prioridad si falta tiempo

Fase 1 → A → B → B2 → C → críticos/altos → D → pulido UX/UI.

## Documentos del work item

- `ESTADO.md`: fuente de verdad del avance (leer primero al retomar).
- `DECISIONES.md`: decisiones registradas (ID, contexto, opciones, elegida, motivo, reversibilidad, paquete).
- `FINDINGS.md`: hallazgos de la Fase 1 y la Fase 3.
- `PRS.md`: PRs abiertos o pendientes de abrir, con URL de comparación y cuerpo.
- `CLOSURE.md`: reporte de cierre (Fase 3).
