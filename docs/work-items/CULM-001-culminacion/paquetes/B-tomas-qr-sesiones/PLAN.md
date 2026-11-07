# CULM-001 · Paquete B — PLAN

> Alcance y diseño en [`CONTRACT.md`](CONTRACT.md) (v4 final, tras REVIEW-1, REVIEW-2 y REVIEW-3). Decisiones: DEC-011..DEC-018, DEC-024 (propuesta en [`DEC-024-propuesta.md`](DEC-024-propuesta.md)) , DEC-028 (numeración) y DEC-032 (golden path: A 1.2.0, B 1.3.0, B2 1.4.0). Fecha: 2026-11-07.
> Fases SDD por subpaquete: PLAN → CONTRACT (revisión 9.2 y congelación) → RED → GREEN → AUDIT → CLOSURE.

## Orden (confirmado: B.1 → B.2)

| # | Subpaquete | Ramas (4 repos) | Migración / prefijo | Depende de | Contenido |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **B.1** sesión cancelada + festivos + HU047 + ventana con tolerancia | `feature/CULM-001-B1-sesiones-festivos` | `15_culm001_b1_*` / `culm001_b1` | Paquete A integrado en `integracion/CULM-001` | `SesionCancelacion`, `TipoCancelacionSesion`, `DiaFestivo`, `CargaDiaFestivo`, `uv_sesion_estado`; SES-01 con `@toleranciaMinutos/@margenMinutos` y rechazo de canceladas; `usp_cancelar_sesion` (`SES_012`/`SES_016`); carga y aplicación de festivos (con fusión de fechas repetidas); `usp_generar_sesiones_grupo_v2` (3915 → `SYS_001`) y precarga; `CalendarioFestivosPort` + 3 adaptadores (feriados.io mínimo) + job; DTOs de sesión con `estado`/`cancelacion` (golden path 1.3.0 sobre la 1.2.0 de A, DEC-032); política de audiencia SSE solo para el titular; pantallas de cancelar y de festivos |
| 2 | **B.2** tomas por horas + QR de asistencia + faltantes | `feature/CULM-001-B2-tomas-qr` | `16_culm001_b2_*` / `culm001_b2` | B.1 integrado; causa raíz de F-DOC-015 conocida antes del GREEN del QR (tomas y horas pueden empezar antes) | `TomaAsistencia` + catálogos, `DetalleAsistencia.toma` (backfill → borrar dependientes → NOT NULL → recrear), toma vigente, lote por toma, cierre con faltantes, horas en `uv_resumen_*` y KPIs de 3.3, cierre masivo por sesiones distintas, `TokenAsistenciaToma` + SPs + scheduler, límite por IP solo de rechazos + token + estudiante, CIDR, registro por token/PIN, pantallas del docente y del estudiante |

Diferido a D: comparativas HU103/HU139, tendencia HU134 y consolidado HU061 (deben pasar a horas), retiro de `POST /asistencias` (TD-009) y `REVOKE`/`DROP` del SP autónomo. Diferido a C: SSE para estudiantes y demás roles.

## Pasos por subpaquete

1. **Revisión 9.2** (segunda pasada sobre la v2) → "sin objeciones" → el orquestador registra DEC-024 y las notas de B-2/NB-7/NB-10/NB-11 en `DECISIONES.md`.
2. **RED** sin código de producción:
   - DB: `test_culm001_b1_*` / `test_culm001_b2_*` (§2.16), registrados por nombre exacto.
   - Backend: unitarias, ArchUnit, contrato SP, controladores, SSE y concurrencia 5×40 y 20×40 (§3.11).
   - Frontend: specs (§4.8).
   - `test_all_hus.ps1` (§5).
   - Todas deben fallar por la causa esperada.
3. **GREEN DB** → `infra.ps1 db-deploy` dos veces + `db-test` (solo F-000 como fallo previo) + `freeze-manifest.ps1`.
4. **GREEN Backend** → `mvnw verify` y `-Pintegration`.
5. **GREEN Frontend** → `npm run verify` (incluye `coverage:realtime:check`).
6. **Infra**:
   - Manifiesto de Infra con los hashes efectivos de UTC-D06, golden path 1.3.0 (DEC-032), contrato de eventos, catálogo y deuda.
   - Verificar con `infra.ps1 verify` y `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001`.
   - `-Mode Generate` y `GeneratePostFreeze -Manifest` se ejecutan solo después de la aprobación 9.2.
7. **AUDIT** (revisor distinto del implementador) y recorrido en pantalla en escritorio y en móvil 375 × 812.
8. **CLOSURE** por repo y PRs hacia `integracion/CULM-001` (Backend y DB en los remotos de DEC-002).

## Gates de salida

- **B.1:**
  - HU047 funcional; una sesión con asistencia no se cancela (`SES_012`/`SES_016`).
  - Las sesiones en festivo nacen canceladas y los festivos de 2026/2027 coinciden con la tabla §3.4.1.
  - Las canceladas quedan fuera de los KPIs y se ven en los 5 roles.
  - SES-01 sin tolerancia intacto y doble despliegue sin errores.
- **B.2:**
  - Una sola toma conserva el comportamiento actual.
  - Las horas salen bien con 2 tomas, con sesión cancelada y con una cabecera sin detalle.
  - QR/PIN rotativo con SSE y sin timers; faltantes con marcación a mano.
  - 5×40 sin duplicados ni deadlocks, con p95 medido; 20×40 sin 429.
  - `sessionQrEnabled`/`sessionCancelEnabled` en `true` y `qr-token` retirado.

## Si falta tiempo

B.1 completo → B.2: tomas + QR + `uv_resumen_*` por horas → indicadores del estudiante y sábana → KPIs de coordinador, decano e institución.
