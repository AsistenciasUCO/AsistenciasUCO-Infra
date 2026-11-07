# CULM-001 · Paquete D — PLAN

> Alcance y diseño en [`CONTRACT.md`](CONTRACT.md) (v1, pendiente de la revisión 9.2). Decisiones: DEC-040 (alcance), DEC-022 §4/§8, DEC-028 (numeración), DEC-036 (precedente de manifiestos), DEC-037/DEC-038 (PDP, bloqueo B-01). Fecha: 2026-11-07.
> Fases SDD por subpaquete: PLAN → CONTRACT (revisión 9.2 y congelación) → RED → GREEN → AUDIT → CLOSURE.
> Numeración: migración `19 + x`, semilla `40 + x`, prefijo `culm001_d<x>` (D.1 = `20`/`41` … D.9 = `28`/`49`).

## Orden y paralelismo

| Ola | Subpaquete (rama `feature/CULM-001-…`) | En paralelo con | Entra cuando | Contenido |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **D.1** `D1-plazo-excusas` | D.3+D.6, D.4 | ya (A y B.1 en integración) | Plazo HU026B en el SP (v1/v2), fecha límite visible, fecha local de radicación |
| 1 | **D.3 + D.6** `D36-parametros-auditoria` | D.1, D.4 | ya | Parámetros editables (lista blanca, rango, motivo, concurrencia, historial, invalidación) + auditoría de `/admin/**` con metadatos y prueba de arquitectura |
| 1 | **D.4** `D4-admision-estudiantes` | D.1, D.3+D.6 | ya | Admisión HU156, `GET /admin/programas`, `AsegurarCuentaIdentidadService` |
| 2 | **D.7** `D7-retiro-registro-individual` | D.2, D.8 | B.2 mezclado (backend y BD) | Retiro de `POST /asistencias`, `REVOKE`/`DROP` del SP autónomo, TD-009 |
| 2 | **D.8** `D8-kpis-horas` | D.2, D.7 | B.2 (BD) mezclado | Comparativas, tendencia y consolidado por horas (F-COO-007) |
| 2 | **D.2** `D2-soportes-categoria` | D.7, D.8 | D.1 mezclado | Varios soportes, FK de categoría, soporte obligatorio, TD-060/061, comprobación de TD-059 |
| 3 | **D.5** `D5-carga-masiva` | D.9-a/b/d | D.4 y D.6 mezclados | Carga CSV por jerarquía: plantilla, validación previa, creación idempotente |
| 3 | **D.9-a/b/d** `D9-hallazgos-medios` | D.5 | D.6 mezclado | Hallazgos de BD/backend (4xx, 404, seguridad), frontend y docs/infra |
| 4 | **D.9-c** (misma rama, segundo PR) | — | C mezclado | SSE: `status`/`emit`, 406, confirmación al abrir |

Worktrees propios `C:\Proyectos\GestionAsistencia-CULM001-D<x>\<repo>` para las ramas de una misma ola; la BD local es compartida y cada D.x repite `infra.ps1 db-test` tras mezclar.

## Pasos por subpaquete

1. Revisión 9.2 del CONTRACT → "sin objeciones" → decisiones del orquestador en `DECISIONES.md`: [SUPUESTO-D-02], [SUPUESTO-D-03], [SUPUESTO-D-08], [SUPUESTO-D-12], `emit` (F-TRX-016) y regeneración de los manifiestos LB-004D y UTC-D06.
2. **RED** sin código de producción: pruebas T-SQL `test_culm001_d<x>_*.sql`, backend (unitarias, ArchUnit/arquitectura, controladores, contrato SP) y specs del frontend. Todas fallan por la causa esperada.
3. **GREEN DB** → `infra.ps1 db-deploy` dos veces + `db-test`; manifiestos tras la aprobación.
4. **GREEN Backend** → `mvnw verify` (y `-Pintegration` en lo que toque D).
5. **GREEN Frontend** → `npm run verify`.
6. **Infra**: `access-catalog.json` (B-01 al responsable), `test_all_hus.ps1`, catálogo de HUs, deuda técnica, `infra.ps1 verify` y `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001`.
7. **AUDIT** (revisor distinto) y recorrido en pantalla en escritorio y en móvil 375 × 812 (las rutas nuevas, condicionadas a B-01).
8. **CLOSURE** y PRs hacia `integracion/CULM-001`.

## Gates de salida

- **D.1:** fuera de plazo → 409 con el mensaje del catálogo y sin escrituras; fecha límite visible; fecha de radicación local.
- **D.2:** N soportes adjuntos y descargables por API; categoría persistida; MED/ACA/LAB sin soporte → 400; manifiesto LB-004D verde.
- **D.3:** solo la lista blanca es editable; `RED/*`/`TIEMPO/*` nunca; tipo, rango, regla cruzada y versión validados en el SP; historial y evento de auditoría con anterior y nuevo; caché invalidada.
- **D.4:** admisión sin matrícula, con vínculo al programa y cuenta aprovisionada o pendiente reparable.
- **D.5:** la validación no crea nada; la creación es idempotente y da resultado por fila; la clave nunca aparece en logs ni en respuestas.
- **D.6:** la prueba de arquitectura falla con cualquier mutación `/admin/**` sin auditar; `idCorrelacion` visible.
- **D.7:** `POST /asistencias` → 404; el SP autónomo no existe y no tiene permisos; TD-009 cerrada.
- **D.8:** los cuatro SP por horas, el consolidado suma 100 %; con una toma y sesiones de igual duración coincide con la fórmula anterior.
- **D.9:** cada hallazgo con estado final en `FINDINGS.md`.

## Si falta tiempo

**D.1, D.3, D.4, D.6, D.7 > D.2, D.8 > D.5 > D.9** (dentro de D.9: a > b > d > c). Las partes diferibles de cada D.x están en CONTRACT §1.2.
