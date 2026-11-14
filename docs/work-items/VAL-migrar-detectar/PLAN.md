---
status: active
type: work-item
scope: infra
owner: infra-team
last-reviewed: 2026-11-13
---

# VAL-migrar-detectar (Infra) - PLAN

Fecha: 2026-11-13. Rama `fix/VAL-migrar-detectar` desde `origin/develop` (18480ba). Va junto con la rama del mismo nombre del
repositorio de BD, que agrega `scripts/migrar.ps1 -Modo Detectar` y `-Modo Baseline -SoloDetectadas`
(ver `docs/work-items/VAL-migrar-detectar/PLAN.md` y `docs/runbooks/ACTUALIZAR_BD_LOCAL_EXISTENTE.md` en ese repositorio).

## Cambio

`scripts/database/reset-datos-prueba.ps1 -Mode Base` aplicaba un rango fijo de migraciones (`-MigrationFrom 13 -MigrationTo 28`)
con `sqlcmd` y sin registro, así que la base quedaba atrás de develop (sin 29..42) y `migrar.ps1 -Modo Estado` la veía toda
pendiente. Ahora, después de restaurar el respaldo:

1. `migrar.ps1 -Modo Baseline -SoloDetectadas -ReaplicarParciales`: registra como `BASELINE` las migraciones cuyo efecto ya trae
   el respaldo (tramo contiguo); las `PARCIAL` (típicas de una base mantenida con `deploy_schema.ps1`, que no borra lo retirado) y
   todo lo posterior quedan pendientes.
2. `migrar.ps1 -Modo Aplicar`: ejecuta en orden todas las pendientes hasta la última.
3. `migrar.ps1 -Modo Estado`: exige `pendientes=0 deriva=0`.

Luego sigue igual: `deploy_schema.ps1`, fixture y su prueba. Se quitan `-MigrationFrom` y `-MigrationTo`. Si el repositorio de BD no
tiene `migrar.ps1` con `-SoloDetectadas`, el modo Base se detiene pidiendo `git pull`. `docs/hardening/HARDENING_QUICK_GUIDE.md`
(2.7) actualizado.

## Validación (2026-11-13)

Contenedor desechable SQL Server 2022 (`SQL_Latin1_General_CP1_CI_AS`, clave aleatoria no impresa), base `gestionasistenciadb_qa`,
con un respaldo real de desarrollo del 2026-11-09 (`gestionasistenciadb_pre_culm001_20261109.bak`, copiado sin modificar
`sql_server_asistencias`):

- Detección: `detectadas=10 ausentes=29 parciales=3` (05 hu091, 13 y 14 `PARCIAL`), `MIGRAR_PARCIALES_PENDIENTES`.
- `Aplicar`: 42 aplicadas; `Estado`: `pendientes=0 deriva=0`.
- `deploy_schema.ps1`, fixture y `test_datos_prueba_ampliados.sql`: 11 `TEST_PASS:QA_DATOS_*`; `rc=0` (8 min).

Pendiente: no se probó con el respaldo canónico `gestionasistenciadb_CULM001_base_20261106-215201.bak`, que no está en este equipo.
Antes de mezclar, quien lo tenga debe correr una vez `infra.ps1 db-reset-qa -Mode Base -Database gestionasistenciadb_qa -Yes` (base
de ensayo, no toca la del backend).
