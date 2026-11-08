# CULM-001 — ESTADO (fuente de verdad del avance)

> Actualizado: 2026-11-07 12:30 (hora local). Leer primero al retomar la tarea.

## Entorno de trabajo

- Worktrees en `C:\Proyectos\GestionAsistencia-CULM001\<repo>` (rama `integracion/CULM-001`), base por repo (ver DEC-002):
  - AsistenciasUCO-Infra `9d55f7c` (`origin/develop`, `AsistenciasUCO/AsistenciasUCO-Infra`) · GestioAsistenciaFrontend `886a01b` (`origin/develop`, `shesho22/AsistenciasUCO-Frontend`) · GestioAsistenciaBackend `72a1675e` (`repo-antiguo/develop`, `alejovh12/AsistenciasUCO`) · GestioAsistenciaDB `65a4998` (`repo-antiguo/develop`, `johnjduque/gestion-asistencia-db`).
  - Los PRs de Backend y DB se abren en `alejovh12/AsistenciasUCO` y `johnjduque/gestion-asistencia-db` (los `origin` de la organización están 502/130 commits atrás).
- Checkouts originales en `C:\Proyectos\GestionAsistencia\<repo>`: **no se tocan** (Infra en `feature/MSG-001-...` con cambios sin commit; frontend con `env.js` modificado).
- `.env` de los 4 repos copiados a los worktrees (no versionados). Backend del worktree fijado a Security Baseline (`KEYCLOAK_ISSUER_URI` → `keycloak.localhost:19090/realms/security-baseline`, `SECURITY_PEP_ENFORCEMENT_ENABLED=true`). `env.js` del frontend del worktree copiado del checkout original (proveedor `baseline`, `SECURITY_BASELINE_APPLICATION_ID` del laboratorio actual).
- Backup COPY_ONLY de la BD local antes de cualquier cambio: `/var/opt/mssql/backup/gestionasistenciadb_CULM001_base_20261106-215201.bak` (dentro del contenedor `sql_server_asistencias`).
- Subagentes anidados: **sí** pueden lanzar subagentes (comprobado 2026-11-06). Jerarquía líder → probadores se mantiene.
- `gh` no instalado; PRs por navegador integrado (sesión de GitHub por comprobar).

## Servicios (2026-11-06 22:00)

| Servicio | Estado |
| :--- | :--- |
| Keycloak baseline `:19090` / PDP `:18080` / PEP `:18081` | arriba |
| SQL Server `:1433` | arriba |
| MinIO `:9000` | arriba · ClamAV `:3310` contenedor `unhealthy` (por revisar) |
| MessageUcoLab `:8000` / `:5174` | arriba |
| Backend `:8080` | (DEC-018: el `.env` del worktree ya fija `APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=sqlserver`; aplica en el próximo reinicio) arriba desde el worktree en modo **baseline** con `infra/security-baseline/scripts/start-backend-baseline.ps1 -Provider baseline -LogDirectory C:\jtmp\culm-backend-logs` (jar `target/AsistenciasUCO-0.0.1-SNAPSHOT.jar`; `.env` del worktree con `SECURITY_BASELINE_JWK_SET_URI` por `localhost`, DEC-006/DEC-007). Para reiniciar: detener el `java.exe` que escucha en 8080, `mvnw -B -DskipTests package` si cambió el código, y volver a lanzar el script |
| Frontend `:4200` | arriba desde el worktree (`npm start`, log `C:\jtmp\culm-frontend-4200.log`); el `ng serve` del checkout original se detuvo (DEC-003) |

## Logins `uco-*` (realm `security-baseline`)

| Usuario | Token por API (`admin-cli`: se emite, pero el backend lo rechaza por falta de `aud`; usar PKCE, DEC-008) | Login en pantalla (2026-11-06 22:40) |
| :--- | :--- | :--- |
| `uco-administrador` | OK | OK (llega a `/app/admin/decanos`) |
| `uco-decano` | OK | OK (`/app/decano/coordinadores`) |
| `uco-coordinador` | OK | OK (`/app/coordinador/docentes`) |
| `uco-docente` | OK | OK (`/app/docente/grupos`) |
| `uco-estudiante` | OK | OK (`/app/estudiante/horarios`) |

## Gates de línea base (antes de cambios, sobre `origin/develop`)

| Gate | Resultado | Detalle |
| :--- | :--- | :--- |
| Backend `mvnw verify -Pintegration` | **FAIL (línea base)** | 13 fallos/33 errores en `72a1675e` (AsistenciaCommand*, AcademicQuery, SoporteArchivo, JpaAttendance…), detectados por B.1; sin regresión en B.1 (12F/33E). Pendiente de análisis en D/Fase 3 |
| Backend `mvnw verify` | PASS (base `72a1675e`) | 3309 pruebas, 0 fallos; JaCoCo "All coverage checks have been met". Requiere `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\jtmp -Djdk.net.hosts.file=C:\jtmp\hosts`. Log `C:\jtmp\culm-mvn-verify-base.log` |
| Frontend `npm run verify` | PASS | 1630/1630 specs; realtime LINE 95.06 % / BRANCH 84.52 %; build producción OK |
| `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001` | **FAIL (línea base, como anticipa el prompt §4)** | `DB_OBJ_MISMATCH` en `usp_generar_sesiones_grupo.sql` y `usp_registrar_asistencias_sesion.sql` (manifiesto `DB_DEVELOP_FREEZE_MANIFEST.sha256` vs `repo-antiguo/develop` de DB) y `CROSS_REPO_DRIFT` del `openapi-golden-path.yaml` entre Infra y Backend. Los 4 contratos canónicos de Infra coinciden con su `.sha256` |
| `infra.ps1 db-deploy` | OK | tras restaurar el backup COPY_ONLY (DEC-004), esquema de `repo-antiguo/develop` (`65a4998`) desplegado: 51 tablas, 16 funciones, 69 vistas, 194 SP, 41 semillas, hardening |
| `infra.ps1 db-test` | **FAIL (línea base)** | 1 fallo: `TEST FAILED: LB004D_R2_TEACHER_SCOPE_AND_SUPPORT` (y `TEACHER_GROUP_NOT_FOUND` sin resultado/aserción). El resto de la suite pasa. Log: `C:\jtmp\culm-db-test-base.log`. Hallazgo F-000 |
| `test_all_hus.ps1` (adaptado a PKCE, commit `afefe7a`) | **línea base 21 PASS / 52 FAIL** | log `C:\jtmp\culm-test-all-hus-base.log`. Fallos por 403 (rutas/roles de la suite desactualizados o scope real), 501 (stubs), 400 (payloads de la suite), 404/405 (rutas inexistentes) y dependencias en cascada. Se analiza en el triage; la suite se corrige solo donde la prueba esté mal (rutas obsoletas), nunca relajando aserciones |
| Sesión de GitHub en el navegador integrado | OK | `github.com/AsistenciasUCO/AsistenciasUCO-Infra/pulls` muestra la barra "Authored by me" |

## Cómo obtener un token para pruebas por API (DEC-008)

`AsistenciasUCO-Infra/scripts/tests/get-spa-token.sh <usuario>` (bash, Git Bash en Windows) con la variable de entorno `E2E_PASSWORD` (clave de prueba de `docs/CREDENCIALES_PRUEBAS_LOCAL.md`): reproduce el Authorization Code + PKCE del cliente `asistencias-uco-spa`. Verificado: `GET /api/v1/auth/me` → 200 con `idUsuario` y roles. Los tokens de `admin-cli` se emiten pero el backend responde 401 (sin `aud`). `test_all_hus.ps1` se está adaptando a este flujo.

## Avance por fase

| Fase / Paquete | Estado | Notas |
| :--- | :--- | :--- |
| Fase 0 | **completa** (2026-11-06 22:45) | worktrees desde la base correcta (DEC-002), BD restaurada y desplegada, backend/frontend arriba desde worktrees, 5 logins OK, gates de línea base registrados, work item creado, `test_all_hus.ps1` adaptado (commit `523456d`) y OpenAPI sincronizado (commit `704823c`) |
| Fase 1 | **completa** (2026-11-07 00:30) | 6 líderes (5 roles + transversal) con pruebas por API (token PKCE), revisión estática y matriz de ámbito de 1003 celdas (0 fugas con los datos actuales; faltan datos de 2.º ámbito); recorridos en pantalla con Haiku: estudiante completo, docente/coordinador/decano parciales, administrador en curso (se repiten completos en la Fase 3). Consolidado en `FINDINGS.md`: 113 hallazgos (3 críticos, 24 altos, 52 medios, 34 bajos). Triage del orquestador en DEC-022; asignación: A 22, B 11, B2 2, C 4, D 34, E 33, no-se-corrige 3, en espera 2, entorno/docs 2 |
| A | **MEZCLADO a `integracion/CULM-001`** (2026-11-07): PRs johnjduque/gestion-asistencia-db#93, alejovh12/AsistenciasUCO#97, shesho22/AsistenciasUCO-Frontend#56, AsistenciasUCO/AsistenciasUCO-Infra#23. Gates: `mvnw verify` 3349 pruebas verde; `npm run verify` verde; suite T-SQL verde en A (fallos cruzados con B.1 en la BD compartida hasta mezclar B.1); contratos en paridad (OpenAPI 1.2.0). AUDIT en pantalla hecha (`paquetes/A-retiro-solicitudes/AUDIT-PANTALLA.md`): F-A-S02/S03/S04 y el 500 de matrícula corregidos; F-A-S01 (403 de la búsqueda) pendiente del PDP (bloqueo B-01); F-A-S05 (503 PDP) y S06–S09 → E | |
| B | **B.1 MEZCLADO a `integracion/CULM-001`** (2026-11-07): PRs johnjduque/gestion-asistencia-db#94, alejovh12/AsistenciasUCO#98, shesho22/AsistenciasUCO-Frontend#57; gates tras la mezcla: `mvnw verify` 3490 pruebas (93,9 %/85,9 %), `npm run verify` 1729 specs verde, suite T-SQL con A y B.1 verdes (5 fallos por datos E2E acumulados y 2 pruebas frágiles de línea base; se repite tras restablecer datos). AUDIT en pantalla de B.1 hecha (`paquetes/B-tomas-qr-sesiones/AUDIT-PANTALLA-B1.md`): cancelar sesión, estado cancelado por rol y festivos (19/2026 y 19/2027 cargados por el job; 4 sesiones canceladas por festivo) correctos; `/admin/festivos` bloqueado solo por B-01; hallazgos menores F-B1-S02..S07 → E/B.2. Pendiente: golden path 1.3.0 al cerrar B. **B.2 MEZCLADO a `integracion/CULM-001`** (2026-11-07): PRs johnjduque/gestion-asistencia-db#95 (`f2f1010`), alejovh12/AsistenciasUCO#99 (`553e8e00`), shesho22/AsistenciasUCO-Frontend#59; gate de BD con datos canónicos (backup base + migraciones 13–16 + despliegue B.2): 715 TEST_PASS, 0 fallos, `FREEZE_MANIFEST_OK`; backend `mvnw clean verify` 3579 pruebas, 95,8 %/86,8 %, concurrencia QR 5×40 y 20×40 sin duplicados ni 429 (p95 en caliente ≤ 0,31 s; en frío 2,4–4,4 s, atribuido al pool); frontend `npm run verify` 1831 specs, realtime 95,18 %/85,23 %. **Golden path 1.3.0 publicado y mezclado** (PRs alejovh12/AsistenciasUCO#100, AsistenciasUCO/AsistenciasUCO-Infra#24; hash `6b0408e1…`; prueba de forma de DTOs reactivada). AUDIT en pantalla de B.2 hecha tras sincronizar el PDP (`paquetes/B-tomas-qr-sesiones/AUDIT-PANTALLA-B2.md`: tomas, indicadores por horas y KPIs OK; proyección QR/PIN en vivo queda para la Fase 3). Pendientes de B: detalle `esParcial` por toma en la sábana (sin endpoint; → CLOSURE), manifiesto post-freeze de B.2 (`freeze-manifest.ps1` sin modo de generación). **B2** (asignaturas N:M): BD y backend GREEN (suite 713/714 en BD propia `gestionasistenciadb_b2nm`, `mvnw clean verify` 3621 pruebas, ITs 14 fallos de línea base), cerrando suite final y push; frontend en curso (Sonnet, `-CULM001-B` frontend). Se mezclan los tres juntos con el gate de datos canónicos (migraciones 17/18) | |
| B2 | **MEZCLADO a `integracion/CULM-001`** (2026-11-08 03:30): PRs johnjduque/gestion-asistencia-db#102 (+ #103 con la corrección de la semilla), alejovh12/AsistenciasUCO#107, shesho22/AsistenciasUCO-Frontend#67. Gates sobre la rama con toda la integración (A, B, D.1–D.7, D.2): suite T-SQL con datos canónicos + migraciones 13–26 (17/18 de B2) 795 TEST_PASS, 0 fallos, `freeze-manifest`/`lb004d-manifest -Mode Verify` OK, catálogo de mensajes 233 códigos; `mvnw clean verify` 3805 pruebas, 0 fallos, JaCoCo OK; `npm run verify` verde (realtime 95,2 %/85,2 %). Hallazgo del gate corregido en la semilla (DEC-055). PDP resincronizado tras la mezcla (2026-11-08 04:10: 5 recursos y 12 concesiones nuevas, 0 faltantes; 32 huérfanos y concesiones sobrantes siguen a la espera de `--prune`; el script compara por plantilla de ruta, PR alejovh12/AsistenciasUCO#108). Pendiente: golden path 1.4.0 (DEC-032, agente en curso) | CONTRACT v5 (`9b668c7d…`); AUDIT-PANTALLA en Fase 3 |
| C | diseño DEC-039/DEC-041/DEC-043; **CONTRACT v3 CONGELADO** (`CONTRACT.sha256`) tras REVIEW-1/2/3 (N-1: el cierre masivo no invoca al motor y devuelve una sola fila); partición C.1/C.2 en PLAN.md. RED de C.1 tras mezclar B.2 y B2 | |
| D | **D.1 MEZCLADO** (PRs #96, #101, #61; DEC-047). **D.4 MEZCLADO** (BD #98, backend #103, frontend del equipo #63 con `npm run verify` verde) y **D.3+D.6 MEZCLADO** (BD #99, backend #104, frontend del equipo #64). Frontends de D.4 y D.3+D.6 hechos por el equipo (DEC-049), se mezclan tras sus backends. **D.2 MEZCLADO** (BD #101, backend #106, frontend del equipo #66). **D.7 MEZCLADO** (BD #100, backend #105, frontend #65). Pendientes: D.5 BD+backend (Antigravity, DEC-054; frontend del equipo verde), D.8 y D.9-a (tras B2; frontend D.9-b del equipo verde con conflictos a resolver). Gate de BD con datos canónicos sobre integración: pendiente de correr ahora que D.1/D.2/D.3+D.6/D.4/D.7 están mezclados. Alcance DEC-040/DEC-042/DEC-044; **CONTRACT v2 CONGELADO** (`CONTRACT.sha256`) tras REVIEW-1 (11 bloqueantes) y REVIEW-2 APROBADO con residuos R-1..R-4 aplicados; semillas 51–59, golden path 1.6.0; RED de D.1/D.3+D.6/D.4 puede empezar (D.7/D.8 tras B.2 y B2, D.9-c tras C) | |
| E | **E.2 parte 1 MEZCLADA** (PR shesho22/AsistenciasUCO-Frontend#58, 31/32 hallazgos COO/DEC/ADM/TRX; F-ADM-S12/S20/S16 y partes de S05/006/S07/DEC-004 requieren backend → D.9/CLOSURE). **E.2 parte 2 MEZCLADA** (PR shesho22/AsistenciasUCO-Frontend#60, 21 hallazgos DOC/EST: 16 corregidos, 2 ya resueltos, F-EST-S14/F-EST-S19/F-DOC-S07 requieren backend o navegador → D.9/CLOSURE). **E.1 (tokenización) hecha y mezclada** a `integracion/CULM-001` del frontend (`ba02d89`, PR shesho22/AsistenciasUCO-Frontend#54, DEC-026): `lint:tokens` en `npm run verify`, 806 clases + 15 hex migrados, fuentes en `styles.css`, `docs/sistema-diseno-tokens.md`. Pendiente E.2: pulido UX/UI y responsive por rol (53 hallazgos `paquete-E`) y la comprobación en pantalla del cambio de `primary` (escritorio y móvil) | |
| Fase 3 | pendiente | |

## Delegación al equipo humano (DEC-049, 2026-11-07)

- Hechos y empujados: frontend D.3+D.6, frontend D.4, suite E2E B/D (Infra). Pendientes de PR/mezcla cuando su backend esté en integración.
- En curso por el equipo: frontend D.2, D.5 y D.9-b. Worktree `-CULM001-E\GestioAsistenciaFrontend` reservado al equipo.
- Agentes: golden path 1.4.0 de B2 (Sonnet, brief cerrado); después C.1 BD+backend, D.8, D.9-a (agentes nuevos por paso, DEC-055). La CLI `gh` sustituye al navegador para PR y mezclas desde 2026-11-08.

## Arranque mínimo del laboratorio tras un apagado (2026-11-08)

Contenedores necesarios: `sql_server_asistencias`, `asistencias-files-minio-1`, `clamav_asistencias` y el laboratorio de seguridad 0.1.9 en orden `asistencias-security-lab-redis-1`, `-surrealdb-1`, `-opa-1`, `-keycloak-1`, `-pdp-1`, `-pep-1`. Se dejan apagados (ajenos o sin uso): `api-gateway-kong`, `keycloak_db_asistencias`/`asistencias-uco-security-keycloak-*` (Keycloak propio :8081), `messageucolab-app`, `redis`, `surrealdb`, `pulsar`, `loki`, `test_ci_clean`, `security-baseline-*` (0.1.7), observabilidad. Luego: `start-backend-baseline.ps1 -Provider baseline` sobre el jar de `integracion/CULM-001` y `npm start` en el frontend. `max server memory` = 2048 MB persiste (DEC-050). Si Docker Desktop falla con "Secrets Engine ... engine.sock", cerrar Docker, relanzarlo y no usar "Reset to factory defaults".

## Bloqueos

- **B-01 (RESUELTO 2026-11-07 ~17:45 por autorización del responsable, DEC-046; repetir tras B2/C/D; `--prune` pendiente de autorización):** (texto original:) el PDP del laboratorio deniega toda ruta nueva del backend (`NO_APPLICABLE_POLICY`). El procedimiento oficial es `provision_asistencias.py pdp` (incremental) tras actualizar `access-catalog.json`, pero el clasificador de permisos de esta sesión lo denegó (DEC-037/DEC-038). **Acción del responsable:** en `GestioAsistenciaBackend` (rama `integracion/CULM-001` una vez mezclados los paquetes, o cada rama `feature/CULM-001-*`), con Python de Windows: `python -X utf8 -I infra\security-baseline\scripts\provision_asistencias.py pdp` y después `... verify` y `... verify-decisions`. Hasta entonces, en pantalla fallan con 403: búsqueda por documento (A), festivos del administrador (B.1), tomas/QR (B.2) y lo nuevo de C/D. Los gates de código no dependen de esto.

- Ninguno todavía.
- Límite de uso de la API alcanzado el 2026-11-07 ~00:50 (5 h): los subagentes de contratos A/B/B2 y E.1 se interrumpieron y se reanudaron a la 01:00.

## Corte por límite de uso (2026-11-08 ~05:00) — retomar aquí

- **Mezclado hoy:** B2 (BD #102+#103, backend #107, frontend #67), script PDP por plantilla (#108, PDP resincronizado), golden path 1.4.0 (backend #109, Infra #28; `verify-contracts` en paridad, único fallo = drift conocido de 2 SP).
- **Agentes Sonnet en curso al cortar** (brief cerrado; empujan a `repo-antiguo`/`origin`, no abren PR): D.8 `feature/CULM-001-D8-kpis-horas` (worktrees `-CULM001-D` BD/backend, `-CULM001-D7` frontend); D.9-a `feature/CULM-001-D9-hallazgos-medios` (`-CULM001-D36` BD/backend); C.1 BD+backend `feature/CULM-001-C1-cancelacion-inasistencia` (`-CULM001-D36-db-merge`, `-CULM001-D36-be-merge`, Infra en `-CULM001-A` o `-CULM001-C`). Sus reportes quedan en los archivos `tasks/<id>.output` de la sesión; si no reportaron, revisar `git log` de esas ramas y relanzar un agente nuevo (no reanudar).
- **Entregas de Antigravity (DEC-054) con PR abierta, pendientes de mi gate:**
  - D.5 BD johnjduque/gestion-asistencia-db#104: re-integrada por mí (`94ea65a`: manifiesto D con `UpdateCulm001D` = 54 entradas, catálogo 248 códigos), MEZCLABLE; sus pruebas T-SQL aún no corridas en BD limpia (hacerlo en el gate del lote o pedir al agente D.9-a que las corra tras desplegar). Mezclar ANTES que D.9-a (migración 24 aborta si `usp_crear_decano` ya tiene `DEC_020`).
  - D.5 backend alejovh12/AsistenciasUCO#110: mezcla local con integración dejó `@AuditableOperation` duplicada en `AdminAdmisionEstudianteController` (corregida en el worktree `-CULM001-B` backend, commit local `039a900a` sin empujar); `mvnw clean verify` relanzado (log `C:\jtmp\culm-d5be-verify.log`). Si verde: `git push repo-antiguo HEAD:refs/heads/feature/CULM-001-D5-carga-masiva` y mezclar #110.
  - Hallazgos backend alejovh12/AsistenciasUCO#111: MEZCLABLE, 14 commits por detrás; falta `mvnw clean verify` sobre la mezcla (mismo procedimiento en `-CULM001-B`).
  - C.1 frontend shesho22/AsistenciasUCO-Frontend#68: mezclado localmente con integración en `-CULM001-V` + fix de spec (`6414531`, expectOne por `r.url` tras la paginación de B2); `npm run verify` relanzado (log `C:\jtmp\culm-c1fe-verify2.log`). Si verde: `git push origin HEAD:refs/heads/feature/CULM-001-C1-cancelacion-inasistencia` y mezclar #68 (después del backend de C.1 o al menos antes del recorrido de Fase 3).
  - Manifiesto post-freeze: BD #105 (CONFLICTO con integración; además cambia las dos entradas congeladas de `DB_DEVELOP_FREEZE_MANIFEST.sha256` para `usp_generar_sesiones_grupo` y `usp_registrar_asistencias_sesion` con adenda) e Infra #29 (mezclable). Revisar que la modificación del manifiesto base esté amparada por la excepción del propietario (`d2d951f`) antes de mezclar; re-integrar #105.
  - T5 remotos de la organización: hecho por Antigravity (develop e integración publicadas en `AsistenciasUCO/AsistenciasUCO-Backend` y `AsistenciasUCO/AsistenciasUCO-DB`); cerrar el punto DEC-002 en CLOSURE.
- **Después:** avisar al agente D.9-a (o a su sucesor) de que D.5 y #111 están mezclados y que re-integre; gate de BD con datos canónicos por lote (`scratchpad/clean-gate-B2nm.ps1` apuntando al worktree principal, migraciones 13-28); PDP `pdp`+`verify` tras cada lote; golden path 1.5.0 (C) y 1.6.0 (D, con D.9-c); D.9-b del equipo (conflictos); Fase 3.
- Regla aprendida: nunca pulsar el cuadro de mezcla de GitHub en una PR bloqueada (activa auto-merge); todo con `gh pr merge --merge`.
