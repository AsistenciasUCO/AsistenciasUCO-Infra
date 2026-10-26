---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# VALIDATION — HU064 / HU060 / HU061

Rama `feature/HU064-HU060-HU061-consultas-coordinador` en DB, Backend y Frontend, apilada sobre `feature/HU096-HU097-HU098-periodos-academicos`. Validación local del 2026-10-25 (Windows 10, Java 25.0.5, Node 24.19, Docker 28.4), ejecutada en secuencia.

## DB

| Comando | Resultado |
|---|---|
| `scripts/freeze-manifest.ps1 -Mode Verify` | exit 0 |
| `deploy_schema.ps1` + `test/prepare_lb004d_fixture.ps1` + `test_summary.ps1` sobre contenedor SQL Server 2022 limpio y desechable (réplica del job `DB Quality Gate CI/CD`) | `FAILED=0`, `DB GATE PASS`, exit 0 |
| `test_consultas_coordinador_programa.sql` | `TEST_PASS` T-064-01, T-060-01, T-061-01 |

## Backend

| Comando | Resultado |
|---|---|
| `mvnw -B -ntp clean verify` | `Tests run: 2113, Failures: 0, Errors: 0, Skipped: 0`; `All coverage checks have been met`; `BUILD SUCCESS` |

No se ejecutaron localmente el build de la imagen Docker, Sonar ni CodeQL (los corre GitHub Actions en el PR).

## Frontend

| Comando | Resultado |
|---|---|
| `npm run test:ci` | `1066 of 1066 SUCCESS` |
| `npm run coverage:realtime:check` | líneas 95.06 % (≥ 90 %), ramas 84.52 % (≥ 80 %) |
| `ng build --configuration=production` | exit 0 |

## Limitaciones

- Prueba manual en la UI con un coordinador pendiente.
- `JpaRepositoryBeanUniquenessTest`: conteo de repositories +1 por `AsistenciaProgramaJpaRepository`.
