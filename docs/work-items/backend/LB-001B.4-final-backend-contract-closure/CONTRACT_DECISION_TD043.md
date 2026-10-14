# CONTRACT_DECISION_TD043 — SP consumidos por el backend inexistentes en DB oficial

Fecha: 2026-09-23. Clase: `CONTRACT_ANALYSIS` (solo lectura DB, sin cambios de código/tests/DB).

## Evidencia (sin secretos)

Consulta de solo lectura en contenedor `sql_server_asistencias`, database `gestionasistenciadb`:
`SELECT name, parámetros FROM sys.objects o / sys.parameters p WHERE schema=dbo AND type IN ('P','PC')`.
Resultado: 50 SP públicos `dbo`. Ninguno se llama `usp_sincronizar_usuario`,
`usp_registrar_o_actualizar_plan_estudio` ni `usp_registrar_estudiante_en_grupo_usuario_no_existente`.

## Casos

| Adapter (OWNER DB / CONSUMER backend) | SP esperado | Existe | Candidatos cercanos revisados | Equivalente inequívoco |
|---|---|---|---|---|
| `UsuarioRepositorySqlServerAdapter` | `usp_sincronizar_usuario` | NO | `usp_sincronizar_usuario_interno` (params `@idTipoIdIdentificacion,@numeroIdentificacion,nombres,@correo,@password,@idCorrelacion` + OUT `@mensajeUsuarioResultado,@mensajeTecnicoResultado,@estadoResultado`; sufijo `_interno`, contrato de SP interno) | NO |
| `PlanEstudioSqlServerAdapter` | `usp_registrar_o_actualizar_plan_estudio` | NO | ninguno con semántica de plan de estudio (`usp_crear_asignatura`/`usp_actualizar_asignatura` solo referencian `@idPlanEstudio`) | NO |
| `GrupoRepositorySqlServerAdapter` | `usp_registrar_estudiante_en_grupo_usuario_no_existente` | NO | `usp_registrar_estudiante_en_grupo` (`@idGrupo,@numeroIdentificacion,nombres,@correo,@password,@idCorrelacion,@idUsuarioEjecutor`; no recibe `@idTipoIdIdentificacion`, semántica de alta/matrícula no verificada) | NO |

Los parámetros del adapter no coinciden inequívocamente con ninguna firma existente y no hay documentación DB de semántica.
No se mapea por parecido de nombre.

## Decisión

- Sin evidencia suficiente: se registra [TD-043](../../baseline/TECHNICAL_DEBT.md#td-043) `NON_GOLDEN_DB_CONTRACT_DRIFT`, estado ABIERTA.
- Las tres features están fuera del Golden Path LB-001; no se toca código, tests ni DB.
- Cada feature requiere work item contractual propio (decidir OWNER: crear SP en DB o adaptar backend) antes de liberarse.

FULL_BACKEND_INTEGRATION_PROFILE: NOT_GREEN — TD-043 NON-GOLDEN ONLY
