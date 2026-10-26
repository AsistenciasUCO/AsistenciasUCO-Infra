---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-25
---

# VALIDATION — HU081 / HU082 / HU083

Rama `feature/HU081-HU082-HU083-plan-estudio-estado-semestres` en DB, Backend y Frontend, desde `develop`. Validación local del 2026-10-24 y 2026-10-25 (Windows 10, Java 25.0.5, Node 24.19, Docker 28.4).

## DB

| Comando | Resultado |
|---|---|
| `scripts/freeze-manifest.ps1 -Mode Verify` | exit 0 |
| `deploy_schema.ps1` + `test/prepare_lb004d_fixture.ps1` + `test_summary.ps1` sobre contenedor SQL Server 2022 limpio y desechable (réplica del job `DB Quality Gate CI/CD`) | `FAILED=0`, `DB GATE PASS`, exit 0 |
| `test_usp_plan_estudio_estado_semestres.sql` | `TEST_PASS` T-081-01, T-081-02, T-082-01, T-082-02, T-082-03, T-083-01, T-083-02 |

## Backend

| Comando | Resultado |
|---|---|
| `mvnw -B -ntp clean verify` | `Tests run: 2065, Failures: 0, Errors: 0, Skipped: 0`; `All coverage checks have been met`; `BUILD SUCCESS` |

No se ejecutaron localmente el build de la imagen Docker, Sonar ni CodeQL (los corre GitHub Actions en el PR).

## Frontend (tras las correcciones de la prueba manual)

| Comando | Resultado |
|---|---|
| `npm run test:ci` | `TOTAL: 1051 SUCCESS` (líneas 90.4 %, ramas 72.78 %) |
| `npm run coverage:realtime:check` | líneas 95.06 % (≥ 90 %), ramas 84.52 % (≥ 80 %) |
| `npm run build -- --configuration=production` | exit 0 |

## Prueba manual en la UI (2026-10-25, usuario de prueba `coordinador.sistemas@uco.edu.co`, entorno local)

| HU | Resultado |
|---|---|
| HU081 | Inactivar y activar un plan: la lista se recarga y el estado alterna VIGENTE/INACTIVO. **OK.** |
| HU082 | Agregar semestres hasta 10. Primera prueba: al superar 10 la DB respondía 409 (`PLA_003`) pero la malla no mostraba un aviso claro. Corregido: aviso fijo "El plan ya tiene el máximo de 10 semestres". **OK tras corrección.** |
| HU083 | Quitar el último semestre vacío. Primera prueba: al llegar al semestre 8 (tiene asignaturas) la DB respondía 409 (`PLA_006`) sin aviso visible; la malla no detectaba las asignaturas porque el backend envía `codigoSemestre` ("S8") y usaba una copia del plan en memoria (404 al quitar semestres que ya no existían). Corregido: adaptación de asignaturas, recarga del plan y aviso fijo. **OK tras corrección.** |

## Limitaciones

- `CoordinadorPortalControllerTest.unavailableEndpointsRemainExplicitlyUnavailable` se actualizó (decisión D6 del PLAN): los tres endpoints dejan de ser 501 por este work item.
- La tarjeta de asignatura de la malla ahora muestra semestre, área, componente y créditos reales; el total de créditos del plan sigue sin venir del backend (fuera de alcance).
