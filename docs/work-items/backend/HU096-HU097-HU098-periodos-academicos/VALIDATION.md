---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# VALIDATION — HU096 / HU097 / HU098

Rama `feature/HU096-HU097-HU098-periodos-academicos` en DB, Backend y Frontend, apilada sobre `feature/HU081-HU082-HU083-plan-estudio-estado-semestres` (rebasada sobre `develop` del 2026-10-25). Validación local del 2026-10-25 (Windows 10, Java 25.0.5, Node 24.19, Docker 28.4).

## DB

| Comando | Resultado |
|---|---|
| `scripts/freeze-manifest.ps1 -Mode Verify` | exit 0 |
| `deploy_schema.ps1` + `test/prepare_lb004d_fixture.ps1` + `test_summary.ps1` sobre contenedor SQL Server 2022 limpio y desechable (réplica del job `DB Quality Gate CI/CD`) | `FAILED=0`, `DB GATE PASS`, exit 0 |
| `test_usp_periodo_academico_gestion.sql` | `TEST_PASS` T-096-01, T-096-02, T-096-03, T-097-01, T-097-02, T-098-01 |

## Backend

| Comando | Resultado |
|---|---|
| `mvnw -B -ntp clean verify` | `Tests run: 2088, Failures: 0, Errors: 0, Skipped: 0`; `All coverage checks have been met`; `BUILD SUCCESS` |

No se ejecutaron localmente el build de la imagen Docker, Sonar ni CodeQL (los corre GitHub Actions en el PR).

## Frontend

| Comando | Resultado |
|---|---|
| `npm run test:ci` | `TOTAL: 1056 SUCCESS` (líneas 90.63 %, ramas 73.37 %) |
| `npm run coverage:realtime:check` | líneas 95.06 % (≥ 90 %), ramas 84.52 % (≥ 80 %) |
| `npm run build -- --configuration=production` | exit 0 |

Una primera corrida simultánea de las tres validaciones falló por carga de la máquina (Karma desconectado y timeout de login de SQL); repetidas en secuencia, todas en verde.

## Limitaciones

- Prueba manual en la UI con el administrador pendiente (usuario de prueba local disponible).
- `PATCH /coordinador/periodos-academicos/{id}/estado` sigue 501 (la tabla no tiene estado).
- `JpaRepositoryBeanUniquenessTest`: conteo de repositories +1 por `PeriodoAcademicoCommandJpaRepository`.
