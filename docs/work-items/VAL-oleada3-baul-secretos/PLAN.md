# VAL-oleada3-baul-secretos (Infra) - PLAN

Fecha: 2026-11-13. Rama local `fix/VAL-oleada3-baul-secretos` desde `origin/develop`.
Ítems de `informes/LISTA_CHEQUEO_VALIDACION_2026-11-12.md`: SEC-07 (verificación), SEC-12 (acompañamiento del backend).
El trabajo principal (SEC-02, SEC-10, SEC-12) está en `Repositorio_GestionAsistenciaBackend/docs/work-items/VAL-oleada3-baul-secretos/`.

## Cambios

| Ítem | Qué cambia | Archivos |
|---|---|---|
| SEC-07 | Sin cambios: los compose de Infra ya exigen las contraseñas con `${VAR:?mensaje}` desde VAL-oleada2. Solo se vuelve a verificar con `docker compose config`. | — |
| SEC-12 | El backend ya no trae los endpoints de Key Vault y App Configuration por defecto, y los perfiles `local`/`dev` usan `local_env` y catálogos SQL Server si no se definen variables. `init-env.ps1` escribe en el `.env` del backend los selectores Azure (`APP_ADAPTERS_VAULT_PROVIDER`, `APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER`, `APP_ADAPTERS_MESSAGE_CATALOG_PROVIDER`), los dos endpoints de desarrollo y `APP_SECRETS_RUNTIME_FROM_VAULT_ENABLED=false` (en local los secretos siguen en el `.env`), para que un `.env` regenerado se comporte como antes. | `scripts/orchestration/init-env.ps1` |
| SEC-12 | Nota en la sección 5 de `.env.example` con el nuevo comportamiento y enlaces al inventario y runbook del backend. | `.env.example` |

## Fuera de alcance

No se arranca ni se detiene el stack. No se tocan `.env` reales. Inventario y runbook de rotación viven en
`Repositorio_GestionAsistenciaBackend/docs/security/` (`SECRETS_INVENTORY.md`, `SECRETS_ROTATION_RUNBOOK.md`).

## Rollback

Revertir el commit. Un `.env` del backend ya generado no cambia: si no tiene los endpoints, el backend en perfil `dev`
arranca con `local_env` y catálogos SQL Server; para seguir con Azure, agregar las líneas de arriba a mano o regenerar con
`init-env.ps1 -Force`.
