# TEST PLAN — LB-001B.4

## Trazabilidad

| Requisito | Prueba observable |
|---|---|
| DBCODE formal, independiente del detalle | `DbExceptionTranslatorTest`: todos los códigos, dos detalles totalmente distintos para `SEC_001` |
| Fail-closed | unknown/malformed DBCODE terminan en `ERR_DB_UNCLASSIFIED`; no activan heurística legacy |
| Compatibilidad legacy | mensaje sin DBCODE conserva clasificación textual existente |
| HTTP semántico y no exposición | `GlobalExceptionHandlerTest`: `SEC_001/SEC_002 → 403/FORBIDDEN`, sin DBCODE/código DB en mensaje |
| Grupo sin `aula` | `FrozenDbGhostFieldContractTest`, mapper y adapter tests; SQL/params sin `@aula` |
| HorarioEstudiante sin `aula` | ghost-field test y SQL capturado sin columna `aula` |
| UTC SesionMateriaEstudiante | mismo `Timestamp` bajo timezone host distinto produce `LocalDateTime` UTC esperado |
| TD-038 | Reporte test asevera ambas fechas con fixture UTC no dependiente del host |
| Realtime UTC | JSON de `RealtimeEventResponse.occurredAt` es ISO-8601 con `Z` |
| TD-040 | adapter mapping + response existentes; metadata runtime oficial confirma columnas consumidas |
| Dominio de estado en lectura (DR-006) | `AsistenciaConsultadaEntityTest`: solo `AN/SJC/EX`; legacy, desconocido y ausente fallan cerrados |

## Escenarios DBCODE

- `SEC_001`, `SEC_002`, `EST_004 → ForbiddenException/FORBIDDEN`.
- `ATT_001`, `ATT_002`, `ATT_003`, `GEN_002`, `RC_001`, `SES_004 → ValidationException/VALIDATION_ERROR`.
- `SES_001 → ResourceNotFoundException/RESOURCE_NOT_FOUND`.
- `SES_003 → FeatureUnavailableException/FEATURE_UNAVAILABLE`; nunca éxito falso.
- código desconocido, código malformado y ausencia total de DBCODE.
- el texto humano y el detalle posterior a `|` no determinan el resultado formal.

## Integración y validación

- Unit/contract selectivo GREEN.
- `mvn -B -ntp verify` con Java 25.
- `mvn -B -ntp -Pintegration verify` contra `sql_server_asistencias / gestionasistenciadb`; revisar Failsafe/skips.
- IT relevantes: `SqlStoredProcedureContractIT`, `AsistenciaRepositorySqlServerIT` y los de Sesion si existen.
- ArchUnit y JaCoCo LINE ≥80 %, BRANCH ≥70 %.

La primera ejecución de `scripts/test-local.ps1` no alcanzó SQL: 37/37 IT terminaron con error de
creación de contexto porque el perfil de integración heredó los providers Azure de catálogo/vault
sin configuración. El arnés `application-integration.yml` se corrigió para usar `sqlserver` como
provider de catálogos y `local_env` como vault durante IT, manteniendo producción sin cambios. La
ejecución debe repetirse completa contra el mismo contenedor oficial.

## RED_SNAPSHOT

- Base commit: `fa9aa901c73e55ae31071f4e74cfb2245189243a` (worktree ya sucio por LB-001B.3).
- Contrato DB SHA: `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec`.
- Evidencia RED conductual: comando selectivo con 74 tests; exit code 1; 21 failures, 0 errors, 0 skipped. Fallos causales en DBCODE, ghost fields y UTC. `RealtimeEventResponseTest` pasó porque el runtime ya serializaba correctamente; congela la regresión faltante M-22.
- Evidencia RED final: `mvnw -B -ntp -DskipTests test-compile`; exit code 1; 11 errores de compilación porque los tests target ya usan firmas sin `aula` mientras producción aún conserva el ghost field.
- Hashes completos: `RED_SNAPSHOT.md`.
- Regla: `04-implementador` no modifica ninguno de los archivos congelados.

## TEST_CONTRACT_CONFLICT y devolución a tester

La primera corrida GREEN ejecutó 116 pruebas y obtuvo 2 fallos (0 errores, 0 omitidas). El
auditor documentó en `AUDIT.md` que ambas expectativas eran incompatibles con el contrato:

- la tercera validación obligatoria de creación de Grupo todavía representaba `aula`;
- el fixture de SesionMateriaEstudiante creaba un instante dependiente del timezone del host.

Por dictamen del auditor se devolvieron exclusivamente esos dos archivos al rol
`03-tester-red`: Grupo ahora demuestra que `aula` no es requerida y el fixture temporal expresa
un `Instant` UTC. No se cambió producción para satisfacer pruebas obsoletas.
