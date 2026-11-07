# CULM-001 · Paquete B — PLAN

> Alcance y diseño: [`CONTRACT.md`](CONTRACT.md) (BORRADOR hasta la revisión 9.2). Decisiones: DEC-011..DEC-018. Fecha: 2026-11-06.
> Fases SDD por subpaquete: PLAN → CONTRACT (revisión 9.2 y congelación) → RED → GREEN → AUDIT → CLOSURE.

## Orden

| # | Subpaquete | Ramas (4 repos) | Depende de | Contenido |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **B.1** sesión cancelada + festivos + HU047 + ventana con tolerancia | `feature/CULM-001-B1-sesiones-festivos` | Paquete A integrado en `integracion/CULM-001` | `SesionCancelacion`, `TipoCancelacionSesion`, `DiaFestivo`, `CargaDiaFestivo`, `uv_sesion_estado`; SES-01 con `@toleranciaMinutos/@margenMinutos` y rechazo de canceladas; `usp_cancelar_sesion`; carga y aplicación de festivos; `usp_generar_sesiones_grupo_v2` y precarga; `CalendarioFestivosPort` + 3 adaptadores + job; DTOs de sesión con `estado`/`cancelacion`; SSE con audiencia; pantallas de cancelar y de festivos |
| 2 | **B.2** tomas por horas + QR de asistencia + faltantes | `feature/CULM-001-B2-tomas-qr` | B.1 integrado; causa raíz de F-DOC-015 conocida antes del GREEN de QR | `TomaAsistencia` + catálogos, `DetalleAsistencia.toma` con backfill, toma vigente en la sincronización, lote por toma, cierre con faltantes, cálculo por horas y KPIs, `TokenAsistenciaToma` + SPs + scheduler + límites + CIDR, registro por token/PIN, pantallas del docente y del estudiante |

## Pasos por subpaquete (mismo orden en B.1 y B.2)

1. **Revisión 9.2** del CONTRACT por un Opus independiente → correcciones → "sin objeciones" → registrar en `DECISIONES.md`.
2. **RED** (sin código de producción): DB `test_culm001_b1_*` / `test_culm001_b2_*` (§2.16); backend unitarias, ArchUnit, contrato SP, controladores, SSE y concurrencia (§3.11); frontend specs (§4.8); `test_all_hus.ps1` (§5). Todas fallan por la causa esperada.
3. **GREEN DB** → `infra.ps1 db-deploy` + `db-test` (solo F-000 como fallo previo) + `freeze-manifest.ps1`.
4. **GREEN Backend** → `mvnw verify` y `-Pintegration` (IT de B, incluida la concurrencia 5 × 40 en B.2).
5. **GREEN Frontend** → `npm run verify` (incluye `coverage:realtime:check`).
6. **Infra** → contratos (golden path, eventos, manifiestos sincronizados y post-freeze), catálogo, deuda; `infra.ps1 verify` y `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001` en verde.
7. **AUDIT** (revisor distinto del implementador) y recorrido en pantalla escritorio + móvil 375 × 812 de los flujos del subpaquete.
8. **CLOSURE** por repo y PRs hacia `integracion/CULM-001` (Backend/DB en los remotos de DEC-002).

## Gates de salida

- B.1: HU047 funcional; sesión en festivo creada cancelada; canceladas fuera de KPIs y visibles en los 5 roles; festivos 2026/2027 = tabla §3.4.1; SES-01 sin tolerancia intacto.
- B.2: una toma = comportamiento actual; horas con 2 tomas y con sesión cancelada correctas; QR/PIN rotativo con SSE y sin timers; faltantes y marcación a mano; 5 × 40 sin duplicados ni deadlocks; `sessionQrEnabled`/`sessionCancelEnabled` en `true`; `qr-token` y `POST /asistencias` retirados; TD-009 cerrada.

## Si falta tiempo

B.1 completo → B.2 tomas + QR + `uv_resumen_*` por horas → indicadores del estudiante y sábana → resto de KPIs (comparativas, tendencia, consolidado).
