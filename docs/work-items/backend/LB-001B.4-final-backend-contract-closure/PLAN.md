# PLAN — LB-001B.4: Final Backend Contract Closure

## Identidad y objetivo

- Fecha: 2026-09-23.
- Roles: `01-planificador` → `02-contratos` → `03-tester-red` → `04-implementador` → `05-auditor` → `06-cierre`.
- Base Git: rama `sergio`, HEAD `fa9aa901c73e55ae31071f4e74cfb2245189243a`.
- Objetivo: cerrar la alineación DB ↔ backend del Golden Path sin iniciar OpenAPI, JPA, Redis ni infraestructura serverless.
- Variable principal: alineación del contrato backend con el baseline DB congelado y su canal formal `DBCODE`.
- Aprobación: instrucción explícita del usuario `LB-001B.4 — FINAL BACKEND CONTRACT CLOSURE`, 2026-09-23.
- Skills: `uco-baseline`, `uco-contratos`, `uco-testing`, `uco-persistencia`, `uco-realtime`, `uco-arquitectura`.

## AS-IS y evidencia

| Hecho | Fuente | Evidencia y límite |
|---|---|---|
| Snapshot backend anterior internamente íntegro | `docs/contracts/external/db/DB_BASELINE_CONTRACT.*` | SHA-256 `1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103`; no contiene todavía el canal DBCODE. |
| Contrato DB final formaliza DBCODE | repo DB `feat/db-golden-path-baseline-freeze`, HEAD `99190f07436bc64299b7d3a35c8e4486f49f9cd6`, `docs/contracts/DB_BASELINE_CONTRACT.md` | SHA-256 `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec`; worktree DB no limpio y contrato declara `GENERATED_FROM_COMMIT: UNCOMMITTED_WORKTREE`. Solo se importa el snapshot documental aprobado; DB no se modifica. |
| Clasificación DB dependiente de texto | `DbFailureClassifier` | Concatena mensaje humano/técnico, normaliza español y busca frases. No reconoce DBCODE. |
| Grupo envía campo inexistente | vertical crear/actualizar Grupo y `GrupoRepositorySqlServerAdapter` | `aula` atraviesa HTTP, Application y JDBC; los SP congelados no aceptan `@aula`. |
| HorarioEstudiante proyecta `aula` | `HorarioEstudianteSqlServerAdapter` y cadena de DTO/domain/projection | La evidencia final debe venir del runtime DB oficial o quedar bloqueada; no se fabrica valor. |
| Sesión create/update ya corregida | LB-001B.3 y código/tests actuales | Sin `idDocente` ni ghost fields en create/update; `usp_cerrar_sesion` legacy se conserva fuera del target. |
| Tercer lector de sesión depende del timezone host | `SesionMateriaEstudianteSqlServerAdapter` | Usa `toLocalDateTime`; patrón UTC aprobado ya existe en `JdbcValueMapper.toLocalDateTimeUtc`. |
| Realtime usa `Instant` sin test de wire format | `RealtimeEvent` / `RealtimeEventResponse` | Falta congelar serialización ISO-8601 UTC con `Z`. |
| GET estudiantes de grupo usa vistas secundarias | `GrupoRepositorySqlServerAdapter` | `uv_estudiante_identidad`/`uv_usuario` no figuran en el snapshot compacto; se validará response/mapping e integración sin inventar columnas. |

## TARGET

- Parser central y estricto `^DBCODE=([A-Z0-9_]+)\|(.*)$`, clasificación solo por código para Golden Path y fallback legacy únicamente cuando no existe marcador DBCODE.
- DBCODE desconocido o malformado: error interno controlado (fail-closed).
- Códigos DB no salen en `ApiErrorResponse`; se exponen códigos semánticos backend.
- `SEC_001/SEC_002 → 403/FORBIDDEN`; `ATT_001-003`, `GEN_002`, `RC_001`, `SES_004 → 400/VALIDATION_ERROR`; `SES_001 → 404/RESOURCE_NOT_FOUND`; `SES_003 → 501/FEATURE_UNAVAILABLE`; `EST_004 → 403/FORBIDDEN`.
- Ghost fields de Grupo/HorarioEstudiante/Sesión en contratos DB afectados: cero.
- Lectura temporal de SesionMateriaEstudiante UTC fija y realtime `occurredAt` serializado con `Z`.
- Documento `BACKEND_GOLDEN_PATH_CONTRACT.md` como input de frontend/LB-001C, sin iniciar OpenAPI.

## Clase de cambio y alcance de rutas

- Change class: `CONTRACT_CHANGE + BEHAVIOR_CHANGE`.
- Allowed:
  - `docs/contracts/external/db/DB_BASELINE_CONTRACT.*`, `docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` y este work item;
  - `docs/baseline/LINEA_BASE.md`, `docs/baseline/TECHNICAL_DEBT.md`, `docs/baseline/MANUAL_VALIDATION_LEDGER.md` si la evidencia lo exige;
  - soporte SQL Server de error/procedure/mapping estrictamente afectado;
  - verticales backend Grupo, HorarioEstudiante y lectores de Sesión afectados, con sus tests;
  - contrato/test de serialización realtime afectado;
  - IT SQL Server existentes estrictamente necesarios para comprobar el baseline.
- Forbidden:
  - repositorio DB y frontend (solo lectura documental DB autorizada);
  - `contracts/openapi/**`, `pom.xml`, schema/SQL DB, JPA, Redis, provider realtime distribuido, IaC/workflows;
  - cambios funcionales ajenos, relajación de gates o edición de tests RED por el implementador.

## Contratos y consumidores afectados

- PERSISTENCE: DB owner; backend consumer. Snapshot final identificado por SHA-256.
- HTTP: backend owner; frontend consumer. Se preserva envelope y se congelan códigos semánticos, sin exponer DBCODE.
- SECURITY: SEC_001/SEC_002 y EST_004 son rechazo de autorización/titularidad.
- REALTIME: `occurredAt` sigue siendo `Instant`; se congela únicamente el wire format UTC `Z`.
- LEGACY: clasificadores textuales existentes continúan para contratos antiguos fuera del Golden Path.

## Riesgos y dependencias

- Árbol backend ya está sucio por LB-001B.3; no revertir ni sobrescribir cambios ajenos.
- El repo DB externo está sucio: su hash documental se registra como snapshot, no como commit liberado.
- Riesgo de compatibilidad HTTP al retirar `aula` de Grupo/HorarioEstudiante; autorizado por la tarea y contrato DB, frontend no se modifica.
- La integración requiere el contenedor oficial `sql_server_asistencias`; skips no certifican integración.
- Margen JaCoCo BRANCH previo reducido (~70,51 %).

## Test plan

Ver `TEST_PLAN.md`. Secuencia obligatoria: contrato aprobado → tests RED → snapshot criptográfico → producción → GREEN → verify/integration/auditoría.

## Rollback

Revertir únicamente archivos de LB-001B.4 a su estado previo preservando los cambios preexistentes de LB-001B.3. No tocar DB ni frontend. El fallback legacy se conserva, por lo que la reversión del canal formal no requiere migración de datos.

## Stop conditions

- Hash del snapshot importado no coincide con `.sha256`.
- `CONTRACT_CONFLICT` o `TEST_CONTRACT_CONFLICT` nuevo.
- Falta de evidencia runtime para columnas de vistas secundarias: `BLOCKED_BY_MISSING_EVIDENCE` solo para el subalcance afectado y para el cierre final.
- Tests de integración omitidos, build/gates rojos o DBCODE expuesto al cliente impiden `DONE`.

## Deuda conocida y validación manual

- TD-036..TD-040, TD-042; TD-003 (SSE in-memory); TD-005 (contrato temporal HTTP pendiente de LB-001C).
- MV-001 permanece pendiente salvo ejecución E2E real; no se presume.

## Definition of Ready

**READY** para los cambios delimitados.

- Objetivo, alcance, no alcance, consumidores, riesgos, rollback y ambiente están definidos.
- Contrato aprobado por instrucción explícita del usuario y evidencia DB final con hash coincidente.
- El build base de LB-001B.3 fue verde (936/936, ArchUnit y JaCoCo PASS); se volverá a ejecutar.
- TEST_PLAN y RED se crearán antes de producción.
- No hay conflicto contractual abierto para DBCODE: el canal formal resuelve TD-036. TD-040 permanece gate de evidencia para cierre, no autorización para inventar columnas.
