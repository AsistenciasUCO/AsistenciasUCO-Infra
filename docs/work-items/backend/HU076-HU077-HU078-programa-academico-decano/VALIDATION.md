---
status: validated-pending-pr
type: validation
scope: fullstack-database-backend-frontend
last-reviewed: 2026-10-22
---

# VALIDATION — HU076 / HU077 / HU078 (+ HU108 listado, HU023 catálogos): Programa Académico del Decano

Ramas `feature/HU076-HU077-HU078-programa-academico` en DB, Backend, Frontend e Infra (worktrees `.worktrees/<repo>-hu076-hu077-hu078`), sin push ni PR. Decisiones D1–D12 aprobadas con las recomendaciones del PLAN.

## 1. Resumen

| Capa | Evidencia | Resultado |
|---|---|---|
| DB | `test_usp_crear_programa_academico`, `_actualizar_`, `_cambiar_estado_`, `_consultar_programas_academicos` (SQL Server local) | PASS |
| DB | `scripts/database/tests/test_programa_concurrencia.ps1` (T-076-07, B bloqueada ~2,5 s por A) | PASS: 1 éxito + 1 `PROG_005`, `@@TRANCOUNT=0` |
| DB | `test_reactive_academic`, `test_public_objects`, `test_transaction_ownership`, `test_titularidad_jerarquica`, `test_authorized_views_rbac`, `test_usp_crear_facultad` | PASS |
| Backend | `mvnw -o test` (incluye ArchUnit) | 1732 tests, 0 fallos |
| Backend | JaCoCo sobre el código nuevo de programa/catálogos | líneas 85,2 % y ramas 94,8 % de las 60 clases afectadas; lo no cubierto son accesores de entidades JPA de vista (sin lógica); casos de uso, validador, adapters, controllers e interactores cubiertos |
| Frontend | `ng test` (ChromeHeadless) | 854 SUCCESS; global 89,2 % líneas |
| Frontend | `ng build --configuration=development` | sin errores |
| E2E | `scratch/test_hu076_hu077_hu078.ps1` con JWT reales (backend de la rama en `:8090`) | 22/22 |
| Infra | `infra.ps1 verify` (checkouts principales) | PASS (18 comprobaciones WORM, 0 secretos). Desde un worktree falla por la ruta raíz esperada, no por esta HU |

## 2. Hallazgos y cambios respecto al CONTRACT

- **Convención de SP**: `usp_*_interno` (no `usp_internal_*`). Fachada valida; el interno abre la transacción (`SET XACT_ABORT ON`, savepoint ≤ 32 caracteres).
- **Coordinador sin facultad en DB**: `Coordinador` solo tiene `usuario`; un coordinador libre no pertenece a ninguna facultad. La regla efectiva es: existe, usuario activo y sin programa (`PROG_005`). "Coordinador de otra facultad" queda cubierto cuando ya coordina un programa (T-076-05). Si se quiere aislar coordinadores libres por facultad hace falta DDL (no aprobado).
- **`@nombre NVARCHAR(100)`** en los SP públicos para poder validar el límite de 50 (con 50 SQL Server trunca en silencio).
- **Mensajes**: `PROG_002…008` y `PAG_001` van en `schema/seed/17_mensajes_programa_academico.sql` (no en `04_mensaje.sql`, para no colisionar con otras pistas); el parámetro `PAGINACION/TAMANO_MAXIMO` en `16_modalidad_jornada_programa.sql`.
- **Controladores y wiring nuevos y separados**: `DecanoProgramaController`, `CatalogoProgramaController` y `ProgramaWiringConfiguration` (no se tocó `DecanoPortalController` ni `DecanoWiringConfiguration`). Catálogos: `/tipos-programa`, `/modalidades-programa`, `/jornadas-programa`.
- **`uv_tipo_programa`** ganó la columna `codigo` (aditivo) y se creó `uv_grupo_programa` para la regla D4.
- **PAG_001**: el SP lo lanza con `THROW`; el adapter lo traduce a `ValidationException` (400). Detectado en el E2E (antes 500).
- Archivos calientes tocados al final y en commit aparte: `DbFailureClassifier`, `JpaRepositoryBeanUniquenessTest` (inventario 32→34), `HTTP_AS_IS_MATRIX.md`, `test_suite.sql`, `test_contract_closure.sql`. `SecurityConfig` no se modificó.

## 3. TEST_CONTRACT_CONFLICT (cambios justificados a pruebas existentes o propias)

| Prueba | Cambio | Justificación |
|---|---|---|
| `test_reactive_academic.sql` | Quita `@codigo`, crea un coordinador libre dentro de la transacción y espera `PROG_002` al repetir el id | Cambio formal de contrato (el SP deja de ser UPSERT y exige coordinador libre 1↔1); las demás aserciones no cambian |
| `test_usp_crear_programa_academico.sql` T-076-14/15 | Tras un error de ejecución se espera la transacción externa no confirmable (`XACT_STATE() = -1`) y se verifica que no quedan filas | Error técnico de la expectativa original: `SET XACT_ABORT ON` impide el rollback a savepoint (mismo caso que `TEST_SKIP:XACT_STATE_MINUS_ONE_RUNTIME` de `test_transaction_ownership.sql`) |
| `test_usp_crear/actualizar_programa_academico.sql` | `@nm` pasa de `NVARCHAR(50)` a `(100)` | La variable truncaba el nombre de 51 caracteres del caso de prueba |
| `catalog.service.spec.ts` | El caso "retorna el catálogo por defecto" se reemplaza por el de datos reales | CA-07: se retiran los programas quemados |
| `dean-programas`, `dean-coordinadores` specs | Atienden los endpoints nuevos | El componente ahora los consulta |
| `JpaRepositoryBeanUniquenessTest` | `EXPECTED_REPOSITORIES` 32 → 34 | Dos repositories nuevos con su Port |
| `DbFailureClassifierProgramaTest`, `ProgramaAcademicoRequestValidatorTest` | Imports y cast corregidos | Errores de compilación de las propias pruebas RED |

## 4. Pendientes y riesgos

- `test_contract_closure.sql` completo no se pudo cerrar en la BD compartida: falla por `usp_actualizar_coordinador` (5 columnas, objeto de otra pista, ajeno a esta rama). Los 8 SP de esta rama cumplen: 4 columnas canónicas los comandos y excepción `READ_QUERY_RESULTSET` para la consulta.
- Despliegue en BD existente: ejecutar `Modalidad.sql`, `Jornada.sql`, `Programa.sql`, `zz_foreign_keys.sql`, seeds 16 y 17, las 5 vistas y los 8 SP (solo estos objetos se aplicaron a la BD local compartida).
- Espejo en `AsistenciasUCO-Infra/docs/work-items`: no se regeneró (`sync-work-items.ps1` lee los checkouts principales, no los worktrees); queda para tras el merge.
- Cierre de HU-CATALOG: filas HU076/HU077/HU078 a `[CERTIFICADA]` con `DeanProgramasComponent` (rama Infra). HU108 y HU023 siguen parciales (planes y administración de catálogos fuera de alcance).
- D12: al desactivar un programa su coordinador queda vinculado con `estaActivoCoordinador=0`.
