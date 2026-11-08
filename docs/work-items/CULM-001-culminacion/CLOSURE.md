# CULM-001 — CLOSURE (borrador de la Fase 3)

> **Estado:** borrador preparado el 2026-11-08 a partir de `PLAN.md`, `ESTADO.md` (sección "Estado al 2026-11-08 ~13:00"), `DECISIONES.md` (DEC-001..DEC-060), `PRS.md`, `FINDINGS.md` y los `CONTRACT.md` de cada paquete. Lo que no consta en esas fuentes figura como "pendiente de verificar en Fase 3".
> **Siglas de PR:** BD = `johnjduque/gestion-asistencia-db`, BE = `alejovh12/AsistenciasUCO`, FE = `shesho22/AsistenciasUCO-Frontend`, Infra = `AsistenciasUCO/AsistenciasUCO-Infra`. Todas las PR van hacia `integracion/CULM-001`, salvo que se indique otra base.

## 1. Resumen por paquete

### Fase 1 — Auditoría
113 hallazgos (3 críticos, 24 altos, 52 medios, 34 bajos) con pruebas por API (token PKCE), revisión estática y matriz de ámbito de 1003 celdas (0 fugas con los datos disponibles; faltan datos de segundo ámbito). Triage en DEC-022. Recorridos en pantalla con Haiku: estudiante completo, otros roles parciales (se repiten completos en la Fase 3).

### A — Retiro de solicitudes de ingreso y correcciones de la Fase 1
- **Entregado:** retiro de `SolicitudIngresoGrupo` y de HU026/HU053/HU054/HU055 (descartadas); matrícula solo por QR/PIN o manual del docente titular; búsqueda por documento; ámbito en SP de directorio y grupos; retiro de reclamo pendiente; solape de sesiones `SES_017`; estado propio del decano.
- **PRs:** BD #93, BE #97, FE #56, Infra #23 (OpenAPI 1.2.0).
- **Gates:** `mvnw verify` 3349 pruebas; `npm run verify` verde; suite T-SQL verde en A; contratos en paridad. AUDIT en pantalla: `paquetes/A-retiro-solicitudes/AUDIT-PANTALLA.md`.

### B — Tomas por horas, QR rotativo, ventana de sesión, sesión cancelada y festivos
- **B.1:** cancelar sesión (HU047), estado cancelado por rol, festivos (19/2026 y 19/2027 cargados por el job). PRs BD #94, BE #98, FE #57.
- **B.2:** tomas por horas, QR/PIN por toma (HU175), auto-registro (HU176), indicadores por horas. PRs BD #95, BE #99, FE #59; golden path 1.3.0 en BE #100 e Infra #24.
- **Gates:** `mvnw clean verify` 3579 pruebas (95,8 % línea / 86,8 % rama); concurrencia QR 5×40 y 20×40 sin duplicados ni 429 (p95 en caliente ≤ 0,31 s; en frío 2,4–4,4 s atribuido al pool); `npm run verify` 1831 specs, realtime 95,18 % / 85,23 %; BD con datos canónicos 715 TEST_PASS, 0 fallos. AUDIT: `AUDIT-PANTALLA-B1.md`, `AUDIT-PANTALLA-B2.md` (proyección QR/PIN en vivo queda para la Fase 3).

### B2 — Asignaturas en varios planes/programas y ámbito por relación
- **Entregado:** vínculo asignatura-plan N:M con semestre y carácter, ámbito por relación en grupos mixtos, oferta del estudiante por vínculo.
- **PRs:** BD #102 y #103, BE #107, FE #67; sincronización del PDP en BE #108; golden path 1.4.0 en BE #109 e Infra #28.
- **Gates (sobre integración con A, B y D.1–D.7):** suite T-SQL 795 TEST_PASS, 0 fallos; `mvnw clean verify` 3805 pruebas; `npm run verify` verde (realtime 95,2 % / 85,2 %). AUDIT en pantalla: pendiente de verificar en Fase 3.

### C — Cancelación por inasistencia (HU026C)
- **C.1 entregado:** motor de alertas 15 %/20 %, revisión de cancelación, matrícula `CI`, cierre masivo por horas con bloqueo condicionado, SSE por ámbito. PRs BD #109, BE #114, FE #68 (equipo/Antigravity), Infra #30 (golden path 1.5.0).
- **Complemento en curso:** `marca` del resumen del docente y F-ADM-026 (rama `feature/CULM-001-C1-marca-planilla`), en curso.
- **C.2 diferido** (campana y HU042 por SSE; DEC-043).

### D — HUs pendientes y hallazgos medios
- **D.1** plazo de excusas HU026B: BD #96, BE #101, FE #61. **D.2** varios soportes y categoría (HU015, HU014, TD-059/060/061): BD #101, BE #106, FE #66. **D.3+D.6** parámetros editables y auditoría (HU168, HU172): BD #99, BE #104, FE #64. **D.4** admisión de estudiantes (HU156): BD #98, BE #103, FE #63. **D.5** carga masiva CSV (HU171): BD #104/#108/#110, BE #110, FE #70. **D.7** retiro de `POST /asistencias` (HU027, TD-009): BD #100, BE #105, FE #65. **D.8** KPIs por horas (HU061/103/134/139): BD #106, BE #112, FE #69. **D.9-a/b** hallazgos medios: BD #107, BE #111 y #113, FE #71. Infra: suite E2E #26 y docs #27; golden path 1.4.0 (#28).
- **D.9-c** (SSE `status`/`emit` validado, 406, golden path 1.6.0): en curso.

### E — Identidad visual y pulido UX/UI
- **E.1** tokenización: FE #54 (806 clases y 15 hex migrados, `lint:tokens` en `npm run verify`).
- **E.2** pulido por rol: FE #58 (coordinador, decano, administrador; 31/32 hallazgos) y FE #60 (docente y estudiante; 16 corregidos, 2 ya resueltos). Quedan F-EST-S14, F-EST-S19, F-DOC-S07 y partes de F-ADM-S05/S07/006/DEC-004 (requieren backend o navegador; D.9).

### Gate del lote (2026-11-08 ~12:45)
BD con datos canónicos: restore, migraciones 13–28 y luego `deploy_schema`: **816 TEST_PASS, 0 fallos**; `freeze-manifest`/`lb004d` OK; catálogo de mensajes 275 códigos. Backend `mvnw clean verify`: **3926 pruebas, 0 fallos**. Frontend `npm run verify` tras la mezcla de D.5: 2124 specs verde (D.9-b: 2142). PDP resincronizado (18 recursos, 18 concesiones, 0 faltantes).

### Sincronización anticipada a `develop` (DEC-048)
Infra #25, BD #97, BE #102, FE #62 (A, B, E, D.1) mezclados a `develop`.

## 2. Decisiones clave
DEC-002 (partir de `repo-antiguo/develop` en Backend y BD); DEC-008 (token PKCE, `admin-cli` sin `aud`); DEC-009 (reactivar matrícula retirada respetando cupo); DEC-011/012/024 (tomas y cálculo por horas); DEC-014 (ventana `[inicio, fin)`); DEC-016/017 (sesión cancelada y festivos); DEC-019/020 (N:M y ámbito por relación); DEC-022 (triage); DEC-039/041/043 (diseño de C, escalada al decano, cierre masivo condicionado); DEC-040/042/044 (alcance y supuestos de D); DEC-046 (PDP autorizado, `--prune` no); DEC-048 (sincronización anticipada); DEC-049/053/054 (equipo y Antigravity); DEC-055..DEC-060 (cierres de B2, D.8, D.9-a, D.5, C.1 y orden del gate).

## 3. Desviaciones del contrato por paquete
- **A:** `x-roles` de `/estudiantes` admite DOCENTE (DEC-027, DEC-032); choques entre contratos (DEC-031); `usp_crear_sesion_interno`/`usp_actualizar_sesion_interno` modificados (DEC-036).
- **B:** errata en B §2.11, límite QR por minuto = 5 (DEC-045); gate con datos canónicos por datos E2E acumulados.
- **B2:** `PLA_006` también con vínculos inactivos, `ASI_003` hacia semestre con vínculo inactivo, MERGE repetido del catálogo OBL/OPT; rechazada la unión simplificada en vez de la vigencia S1 (DEC-046). Semilla fechada al inicio del periodo (DEC-055); PR #102 mezclada sola por auto-merge (corregida en #103). Clave `(id, idPrograma)` del consolidado (DEC-056).
- **C:** `PATCH` de revisión devuelve `DecisionRevisionCancelacionResponse`; `ALR_003` con 3 placeholders; `REVISION_CANCELACION_REASIGNADA`; el motor valida solo el grupo (`VAL_001`); `decidir`/`resolver`/cierre masivo liberan con COMMIT en rutas de error; pruebas actualizadas por cambio formal (DEC-059).
- **D.1–D.4:** plazo en v1/v2 del SP (DEC-047); vínculo de programa dentro de `usp_admitir_estudiante`, `ADS_004` en el SP, `codigo` null en `GET /admin/programas`, `ADS_005` como `VCE_001`; `AUD_002`, `AdminParametroController` propio, retiro de `ConsultarParametros*`; `PARAMETER_UPDATED` diferido (DEC-051); `ARC_001` sigue 404 y `FIELD_INVALID_VALUE` en campos excluyentes (DEC-052).
- **D.5:** código no compilaba; resolución por nombre en vez de `codigo` (DEC-058).
- **D.8:** columnas nuevas al final, `horasDictadas` sin multiplicar por activos, bloque '2 tomas = 1 toma' diferido (DEC-056).
- **D.9-a:** `details[]` en inglés (golden path WORM), `NTF_021` solo con `@validarExistencia = 1`, `UnmappedRouteFilter` solo con PEP activo; 4 fallos de `verify` de #111 corregidos y `AdminPortalController` con `@Autowired` (DEC-057).
- **Gate:** migraciones antes de `deploy_schema` y exclusión de `usp_validar_carga_masiva_usuarios` del cierre canónico (DEC-060, DEC-055).

## 4. Diferido
- **C.2:** campana de notificaciones y HU042 por SSE (DEC-043).
- **D.9-c:** en curso (SSE `status`/`emit`, 406, golden path 1.6.0).
- Complemento de C.1 (`marca`, F-ADM-026): en curso.
- HU169, HU170 y HU177: fuera del mandato (equipos de mensajes y seguridad).
- Deudas: TD-062..TD-084 en `docs/baseline/TECHNICAL_DEBT.md`.

## 5. Para revisar
1. **DEC-002 — remotos de la organización:** Antigravity (T5) dejó resuelto el desfase de `origin` de Backend y BD (502 y 130 commits atrás); confirmar el estado final de los remotos.
2. **Migración 19 sin comparación byte a byte** del SP restaurado (TD-066).
3. **C-DB-50 y C-DB-46** sin ejecución en paralelo real (TD-067); **C-DB-62** cubierta solo por el gate (TD-068).
4. **`CierreMasivoRcn012IT`** (TD-069) y **E2E PKCE `test_culm001_c.ps1`** (TD-070).
5. **Manifiesto post-freeze de C** sin modo en `freeze-manifest.ps1` (`DB_UTC_D06`); PR #105 (BD) y #29 (Infra) pendientes, con conflicto y excepción del propietario por confirmar (TD-071).
6. **PDP:** `--prune` pendiente de autorización (concesiones sobrantes) y 32 recursos huérfanos (TD-072, TD-073).
7. **Drift de `usp_generar_sesiones_grupo` y `usp_registrar_asistencias_sesion`** (`DB_OBJ_MISMATCH` conocido, TD-074).
8. **Presupuesto del bundle frontend** +7,6 kB (TD-075).
9. **`horasDictadas`** del consolidado sin multiplicar por activos (DEC-056, TD-076); **`codigoPrograma`/`codigo_facultad` por nombre** (DEC-058, TD-077); **`details[]` en inglés** (DEC-057, TD-078).
10. **HU044:** la fila del catálogo se corrigió a "edición de aforo por coordinador/administrador" (DEC-022 §7); confirmar la regla con el responsable.
11. **F-TRX-015:** `AGENTS.md` 3.3.4 (cookies HttpOnly/CSRF) frente al Bearer en memoria; sin CSP (TD-084).
12. **`esParcial`:** detalle por toma en la sábana sin endpoint (TD-082).
13. Caso 'tomas equivalentes' diferido (TD-079), tres SP fuera del cierre canónico (TD-080) y orden migraciones → deploy (TD-081).
14. HU018 sigue `[PENDIENTE]` "Diferida a B2 / Fase 3" aunque B2 ya está mezclado, y HU003 "No-se-corrige (propuesta)": revisar el estado final.
15. Descartes de la Fase 1 (3 "no se corrige", 2 "en espera") y bloqueo B-01 (PDP): repetir tras la última mezcla.

## 6. Fase 3 — verificación final

### 6.1 Recorridos de los 5 roles
| Rol | Escritorio | Móvil 375×812 | Observaciones |
| :--- | :---: | :---: | :--- |
| Estudiante (incluye QR en vivo) | [ ] | [ ] | |
| Docente (proyección QR/PIN en vivo, tomas) | [ ] | [ ] | |
| Coordinador | [ ] | [ ] | |
| Decano | [ ] | [ ] | |
| Administrador | [ ] | [ ] | |

- [ ] Concurrencia del QR en vivo repetida sobre datos canónicos.
- [ ] Comprobación en pantalla del cambio de `primary` (E.1) en escritorio y móvil.
- [ ] Hallazgos de la Fase 1 repetidos y registrados en `FINDINGS.md`.

### 6.2 Suite E2E
- [ ] `scripts/tests/test_all_hus.ps1` (ampliada del equipo) — resultado: pendiente de verificar en Fase 3 (línea base: 21 PASS / 52 FAIL).

### 6.3 Gates finales en 4 repos
- [ ] Infra: `.\AsistenciasUCO-Infra\infra.ps1 verify`
- [ ] Backend: `.\mvnw.cmd verify` (y `-Pintegration`; línea base 13 fallos / 33 errores)
- [ ] Frontend: `npm run verify`
- [ ] BD: `.\AsistenciasUCO-Infra\infra.ps1 db-test` (línea base: fallo de `LB004D_R2_TEACHER_SCOPE_AND_SUPPORT`)
- [ ] `verify-contracts.ps1`: paridad de contratos y manifiestos, con el drift de TD-074 resuelto o justificado.

### 6.4 PDP
- [ ] `provision_asistencias.py pdp`, `verify` y `verify-decisions` tras la última mezcla; `--prune` según decisión del responsable.

### 6.5 Cierre de integración
- [ ] PR `integracion/CULM-001` → `develop` en Infra.
- [ ] PR `integracion/CULM-001` → `develop` en Backend.
- [ ] PR `integracion/CULM-001` → `develop` en Frontend.
- [ ] PR `integracion/CULM-001` → `develop` en BD.
- [ ] `HU-CATALOG.md` recertificado y `CLOSURE.md` firmado.
