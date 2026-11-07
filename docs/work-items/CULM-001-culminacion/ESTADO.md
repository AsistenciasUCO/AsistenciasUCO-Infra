# CULM-001 — ESTADO (fuente de verdad del avance)

> Actualizado: 2026-11-07 08:40 (hora local). Leer primero al retomar la tarea.

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
| A | **CONTRACT congelado** (v5, `84e2fca2…`, DEC-035). GREEN: BD 18 commits (migraciones 13/14 aplicadas en la BD local, fixture del 2.º ámbito aplicado, F-000 corregido), backend 19 commits (`mvnw verify` 3342 pruebas, LINE 93,1 %/BRANCH 85,1 %; `-Pintegration` en curso), frontend 14 commits (`npm run verify` verde, 1631 specs), Infra 5 commits (golden path 1.2.0 en paridad, catálogo 134 cert./24 desc.). Pendiente: AUDIT (jar de A en :8080 + recorrido), PRs y mezcla | |
| B | **CONTRACT congelado** (v4, `401c76b6…`, DEC-033). B.1 GREEN: BD 8 commits (47 pruebas nuevas; objetos desplegados en la BD local), backend 9 commits (`mvnw verify` 3449 pruebas, LINE 93,5 %/BRANCH 85,3 %; `OpenApiGoldenPathConformanceTest…DtoPropertyShapes` `@Disabled` hasta la 1.3.0), frontend en curso; B.2 (tomas/QR) BD arrancando en `feature/CULM-001-B2-tomas-qr` (desde B.1). Worktrees `C:\Proyectos\GestionAsistencia-CULM001-B` | |
| B2 | **CONTRACT congelado** (v5, `9b668c7d…`, DEC-029/DEC-032; 3 rondas). Implementación pendiente (después de B) | |
| C | pendiente | |
| D | pendiente | |
| E | **E.1 (tokenización) hecha y mezclada** a `integracion/CULM-001` del frontend (`ba02d89`, PR shesho22/AsistenciasUCO-Frontend#54, DEC-026): `lint:tokens` en `npm run verify`, 806 clases + 15 hex migrados, fuentes en `styles.css`, `docs/sistema-diseno-tokens.md`. Pendiente E.2: pulido UX/UI y responsive por rol (53 hallazgos `paquete-E`) y la comprobación en pantalla del cambio de `primary` (escritorio y móvil) | |
| Fase 3 | pendiente | |

## Bloqueos

- **B-01 (abierto, requiere al responsable):** el PDP del laboratorio deniega toda ruta nueva del backend (`NO_APPLICABLE_POLICY`). El procedimiento oficial es `provision_asistencias.py pdp` (incremental) tras actualizar `access-catalog.json`, pero el clasificador de permisos de esta sesión lo denegó (DEC-037/DEC-038). **Acción del responsable:** en `GestioAsistenciaBackend` (rama `integracion/CULM-001` una vez mezclados los paquetes, o cada rama `feature/CULM-001-*`), con Python de Windows: `python -X utf8 -I infra\security-baseline\scripts\provision_asistencias.py pdp` y después `... verify` y `... verify-decisions`. Hasta entonces, en pantalla fallan con 403: búsqueda por documento (A), festivos del administrador (B.1), tomas/QR (B.2) y lo nuevo de C/D. Los gates de código no dependen de esto.

- Ninguno todavía.
- Límite de uso de la API alcanzado el 2026-11-07 ~00:50 (5 h): los subagentes de contratos A/B/B2 y E.1 se interrumpieron y se reanudaron a la 01:00.
