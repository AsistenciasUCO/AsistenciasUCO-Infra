---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# VALIDATION — HU104 / HU105 / HU109 / HU119 / HU145

Rama `feature/HU104-HU105-HU109-HU119-HU145-lecturas-decano` en DB, Backend y Frontend, apilada sobre `feature/HU064-HU060-HU061-consultas-coordinador`. Validación local del 2026-10-25 (Windows 10, Java 25.0.5, Node 24.19, Docker 28.4), ejecutada en secuencia.

## DB

| Comando | Resultado |
|---|---|
| `scripts/freeze-manifest.ps1 -Mode Verify` | exit 0 |
| `deploy_schema.ps1` + `test/prepare_lb004d_fixture.ps1` + `test_summary.ps1` sobre contenedor SQL Server 2022 limpio y desechable (réplica del job `DB Quality Gate CI/CD`) | `FAILED=0`, `DB GATE PASS`, exit 0 |
| `test_consultas_decano_facultad.sql` | `TEST_PASS` T-104-01, T-105-01, T-119-01, T-145-01, T-PAG-01 |

## Backend

| Comando | Resultado |
|---|---|
| `mvnw -B -ntp clean verify` | `Tests run: 2139, Failures: 0, Errors: 0, Skipped: 0`; `All coverage checks have been met`; `BUILD SUCCESS` |

No se ejecutaron localmente el build de la imagen Docker, Sonar ni CodeQL (los corre GitHub Actions en el PR).

## Frontend

| Comando | Resultado |
|---|---|
| `npm run test:ci` | `TOTAL: 1081 SUCCESS` (líneas 90.98 %, ramas 73.58 %) |
| `npm run coverage:realtime:check` | líneas 95.06 % (≥ 90 %), ramas 84.52 % (≥ 80 %) |
| `ng build --configuration=production` | exit 0 |

## Limitaciones

- Prueba manual en la UI con un decano pendiente.
- La sesión no guarda sede/espacio en el modelo actual; el cronograma no la muestra.
- `JpaRepositoryBeanUniquenessTest`: conteo de repositories +1 por `FacultadDecanoJpaRepository`.
- Sin push: pendiente de confirmación del dueño del paquete.
