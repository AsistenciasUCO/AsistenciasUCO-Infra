---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# PLAN — LB-001B.3: BACKEND ALIGNMENT AGAINST FROZEN DB BASELINE

## Identidad y objetivo

- Fecha: 2026-09-23. Rol: 01-planificador. Branch `sergio`, HEAD `fa9aa901c73e55ae31071f4e74cfb2245189243a` (dirty, 87 entradas `git status --porcelain=v1`).
- Objetivo: alinear el backend AsistenciasUCO al [DB_BASELINE_CONTRACT.md](../../contracts/external/db/DB_BASELINE_CONTRACT.md) congelado (Golden Path: horarios docente, sesiones por grupo, estudiantes de grupo, asistencias batch + lectura, realtime, crear/actualizar Sesion) sin modificar DB ni frontend, sin crear OpenAPI/JPA/Redis/serverless/WebFlux, dejando el backend `READY FOR FRONTEND VERIFICATION` y `READY FOR LB-001C OPENAPI`. Criterios de aceptación: los de [TASK_AUTORIZADA.md](TASK_AUTORIZADA.md) §35 ("Criterio de salida") y §36 ("Estado final"), verbatim, sin reinterpretarlos.
- Skills consultadas: `uco-arquitectura`, `uco-contratos`, `uco-persistencia`, `uco-seguridad`, `uco-testing`, `uco-catalogos`, `uco-observabilidad`, `uco-realtime`, `uco-baseline` (indicadas por `AGENTS.md` para esta tarea). No se leyó documentación masiva fuera de esa lista.
- Fuentes autoritativas: `AGENTS.md` (raíz), `TASK_AUTORIZADA.md` (texto verbatim del usuario, 37 secciones — única fuente de alcance), `PRECHECK_SNAPSHOT.md` (precheck SHA-256 + snapshot ya ejecutados, no repetidos), `DB_BASELINE_CONTRACT.md` + `PROVENANCE.md`, `LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md` (trabajo previo cerrado, sin commit, no se revierte), `docs/governance/DEFINITION_OF_READY.md`, código backend real (leído en esta sesión, ver tabla AS-IS).

## AS-IS y evidencia

| Hecho | Archivo + símbolo / contrato + versión | Evidencia y límites |
|---|---|---|
| DB contract SHA verificado | `docs/contracts/external/db/DB_BASELINE_CONTRACT.sha256` vs `.md` | `PRECHECK_SNAPSHOT.md` §1 — ambos hash `1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103`. **VERIFIED**. |
| Rama DB origen NO fusionada | `docs/contracts/external/db/PROVENANCE.md` | `gestion-asistencia-db`, rama `feat/db-golden-path-baseline-freeze`, commit `99190f0...`, no ancestro de `main`. Advertencia explícita, no oculta. |
| Java 25 / Spring Boot 4.0.6 / JDK 25 enforced | `pom.xml` líneas 8, 30, 155-167 | `<parent>spring-boot-starter-parent 4.0.6</parent>`, `<java.version>25</java.version>`, `maven-enforcer-plugin` exige `[25,26)`. Dato real, no supuesto (contradice el "Spring Boot 4" genérico de la tarea solo en que ya está confirmada la versión exacta 4.0.6). |
| Gates JaCoCo | `pom.xml` líneas 194-211 | `LINE COVEREDRATIO >= 0.80`, `BRANCH COVEREDRATIO >= 0.70`, regla `BUNDLE`. Coincide con lo exigido en `TASK_AUTORIZADA.md` §31. |
| Stack HTTP/realtime | `pom.xml` líneas 47-61 | `spring-boot-starter-webmvc` (no WebFlux) + `reactor-core` puro para SSE (`Flux<ServerSentEvent<T>>` sobre MVC). Confirma restricción §5 ya respetada. |
| **MISMATCH crítico — `idDocente` sigue viajando a Sesion SP** | `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` líneas 42-70, 129-161, 226-241 | `SQL_CREAR_SESION` y `SQL_ACTUALIZAR_SESION` incluyen `@idDocente = :idDocente`; `crearSesion()`/`actualizarSesion()` lo envían desde `dto.getDocente()`/`dto.docente()`. `SQL_CERRAR_SESION` también lo envía. El contrato congelado declara las firmas SIN `idDocente`: `usp_crear_sesion(@idGrupo, @nombre, @fechaHoraInicio, @fechaHoraFin, @idCorrelacion, @idUsuarioEjecutor = NULL)` / `usp_actualizar_sesion(@idSesion, @nombre, @fechaHoraInicio, @fechaHoraFin, @idCorrelacion, @idUsuarioEjecutor = NULL)` (`DB_BASELINE_CONTRACT.md` §Sesion). **LB-001B.1 NO resolvió esto** — solo retiró `descripcion/aula/tipo` (confirmado en `CLOSURE.md` §"Alcance entregado"). `idDocente` como SP param sigue pendiente para esta fase; contradice `TASK_AUTORIZADA.md` §8-9 ("no reintroducir idDocente como identidad secundaria del caller") y el veredicto final exige `SESSION idDocente SP PARAM = 0`. |
| Sesion read projection | `SesionRepositorySqlServerAdapter.java` líneas 79-110, 163-224 | `SQL_CONSULTAR_POR_ID`/`SQL_CONSULTAR_POR_GRUPO` seleccionan por nombre exactamente las columnas de `uv_sesion` del contrato (`id, nombre, numero, codigo, numeroSemana, idGrupo, codigoGrupo, nombreGrupo, fechaHoraInicio, fechaHoraFin`); ningún `aula/descripcion/tipo/status`. **MATCH.** |
| **MISMATCH — `uv_horario_docente` expone `aula` en backend, contrato dice NO `aula`** | `infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapter.java` línea 24, 38; `HorarioDocenteProjection.java` línea 16; `HorarioDocenteDomain.java`/`HorarioDocenteDTO.java` línea 8-11 | El `SELECT` incluye `aula` y se propaga hasta el DTO de aplicación. `DB_BASELINE_CONTRACT.md` §"Golden Path Read Projections" declara `uv_horario_docente` explícitamente **sin** `aula`. Endpoint `GET /api/v1/docente/horarios` está en el Golden Path (`TASK_AUTORIZADA.md` §7) — este es MISMATCH real dentro de alcance. |
| Horario estudiante (`uv_horario_estudiante`) — vista no documentada en el contrato | `HorarioEstudianteSqlServerAdapter.java` línea 24, 38 (también selecciona `aula`) | `DB_BASELINE_CONTRACT.md` no incluye `uv_horario_estudiante` ni en "Golden Path Object Inventory" ni en "Golden Path Read Projections". El endpoint de horarios estudiante tampoco está en la lista de endpoints Golden Path de `TASK_AUTORIZADA.md` §7. **BLOCKED_BY_MISSING_EVIDENCE puntual** (no bloquea el resto): 02-contratos debe registrar esta vista como fuera del contrato congelado documentado y decidir si queda `NOT_APPLICABLE`/`OUT_OF_TARGET` para esta fase, sin inventar su shape. |
| Batch de asistencia — shape HTTP ya alineado | `infrastructure/adapter/primary/controller/asistencia/request/RegistrarAsistenciasSesionRequest.java` | Campos `sesionId` + `registros[]` ya coinciden con `TASK_AUTORIZADA.md` §15 y con el SP `usp_registrar_asistencias_sesion` (`idSesion, asistenciaJSON` en el contrato, mapeo esperado). `RegistroAsistenciaRequest` no se abrió en detalle en este PLAN (nivel de detalle campo-por-campo es de 02-contratos); confirmar `estudianteId`/`estado` exactos en CONTRACT_MATRIX. |
| **Gap estructural — clasificación de errores DB es 100% heurística de texto libre, no usa códigos formales** | `infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` (164 líneas) + `DbExceptionTranslator.java` | `DbFailureClassifier.classify()` normaliza `mensajeUsuarioResultado + mensajeTecnicoResultado` y hace *pattern matching* de frases en español (`"no existe"`, `"cupo"`, `"cruce"`, etc.) para dominios `Usuario/Estudiante/Docente/Grupo/TipoIdentificacion`. **Ningún** literal `SEC_001`, `SEC_002`, `ATT_001`, `ATT_002`, `ATT_003`, `SES_003`, `SES_004`, `RC_001`, `GEN_002`, `EST_004` aparece como señal de clasificación (la única mención de `RC_001` es un comentario explicativo, no lógica). `DbExceptionTranslator` solo tiene 4 sets (`FORBIDDEN_CODES`, `NOT_FOUND_CODES`, `CONFLICT_CODES`, `VALIDATION_CODES`) construidos sobre `ErrorDefinition` de dominios no-Sesion/no-Asistencia (excepción parcial: `SesionErrorCode.ERR_SESION_NO_EXISTE` y `AsistenciaErrorCode.ERR_ESTUDIANTE_NO_PERTENECE_SESION`/`ERR_ESTADO_ASISTENCIA_INVALIDO`, pero alcanzados solo por texto libre, no por código). Esto es exactamente el escenario que `TASK_AUTORIZADA.md` §18 anticipa: "si con el contrato congelado NO existe señal determinista suficiente para mapear un error: `CONTRACT_CONFLICT` STOP". **Candidato fuerte a `CONTRACT_CONFLICT` o `BLOCKED_BY_MISSING_EVIDENCE`** que 02-contratos debe resolver explícitamente (¿el `codigo` de `uv_mensaje_tecnico` se embebe de forma estable en `mensajeTecnicoResultado`? El contrato DB no lo garantiza literalmente — el result set público solo tiene 4 columnas, sin "código" quinto, confirmado en `DB_BASELINE_CONTRACT.md` §"IMPORTANTE — RESULTSET DB" / §18 de la tarea). No se decide en este PLAN. |
| Ejecutor (`idUsuarioEjecutor`) ya se propaga hasta el SP | `SesionRepositorySqlServerAdapter.java` líneas 139, 159, 239, 255 | `dto.getUsuarioEjecutor()`/`dto.usuarioEjecutor()` se envían en los 4 SP de Sesion. **No se localizó en esta sesión** la clase exacta de extracción provider-neutral desde el contexto de seguridad (búsquedas por `*Security*`/`*Keycloak*`/`ExecutorContext` en `src/main/java` no dieron coincidencias con ese naming). 02-contratos debe verificar el punto de extracción real (probablemente bajo `infrastructure/adapter/primary/security/**` con otro nombre) antes de dar por cerrada la sección 16 de la tarea. |
| Correlation propagada al SP (Sesion) | `SesionRepositorySqlServerAdapter.java` líneas 138, 158, 238, 254 | `CorrelationIdContext.require()` se usa en los 4 métodos de escritura del adapter de Sesion. Patrón consistente; no se verificó exhaustivamente en el adapter de Asistencia en esta sesión (queda para 02-contratos, pero el patrón `CorrelationIdContext` es transversal en `infrastructure.observability.correlation`). |
| `ZoneId.systemDefault()` — cero coincidencias en `src/main/java` | grep exhaustivo | Buena señal AS-IS: no hay dependencia explícita de timezone del sistema detectada. No confirma por sí solo que la interpretación de `Sesion.fechaHoraInicio/fechaHoraFin` como UTC ya sea explícita (falta auditar `JdbcValueMapper.toLocalDateTime` y la cadena `CrearSesionDomain`/`ActualizarSesionDomain`/HTTP mapper) — tarea de 02-contratos (`TASK_AUTORIZADA.md` §20-22). |
| Realtime `occurredAt` ya es `Instant` | `application/secondaryports/realtime/RealtimeEvent.java` líneas 3, 23, 43 | Tipo `Instant` en el record, `Instant.now()` como default factory. Cumple el requisito de §23 en cuanto al tipo; falta confirmar en 02-contratos/03-tester-red que la serialización HTTP/SSE efectivamente emite ISO-8601 con `Z` (test de serialización, no solo tipo Java). |
| Realtime — adapter local en memoria, no distribuido (auto-documentado) | `infrastructure/adapter/secondary/realtime/localsse/ReactorRealtimeAdapter.java` líneas 18-34 | `Sinks.many().multicast().directBestEffort()`, sin durabilidad/replay, Javadoc ya declara "best-effort... efímero". Confirma el hallazgo esperado por §26: candidato directo a `NOT_DISTRIBUTED` / `SERVERLESS_SCALE_OUT_BLOCKER` para registrar en deuda técnica, no para refactorizar ahora. |
| `MessageCatalogPort` existe como puerto neutral | `application/secondaryports/catalog/MessageCatalogPort.java` | Confirma que la abstracción exigida por §25 ya existe en Application; 02-contratos solo necesita auditar que ningún adapter nuevo la rompa, no crearla. |
| Working tree dirty, 87 entradas | `git status --porcelain=v1` (este PLAN) | Consistente con lo registrado en `PRECHECK_SNAPSHOT.md` §2 (87 entradas descritas cualitativamente ahí). Incluye el trabajo sin commit de LB-001B.1 (`src/main/java/.../sesion/**` crear/actualizar) — **no tocar, no revertir**. |

## TARGET

Alinear exactamente a `DB_BASELINE_CONTRACT.md` (Authority: `schema/**` del repo DB, snapshot congelado). En concreto, para que 02-contratos construya el `CONTRACT_MATRIX.md`:

- Sesion crear/actualizar: retirar `idDocente` como parámetro SP (los 3 usos: crear, actualizar, y — si aplica — cerrar); la identidad de autorización queda solo en `idUsuarioEjecutor`.
- Horario docente: retirar `aula` de la proyección `uv_horario_docente` en todo el pipeline backend (adapter → projection → domain → DTO → HTTP), salvo que 02-contratos encuentre evidencia contractual que hoy no está en `DB_BASELINE_CONTRACT.md`.
- Horario estudiante: decidir explícitamente el estado contractual (`OUT_OF_TARGET`/`NOT_APPLICABLE` para esta fase, dado que no está en el Golden Path de la tarea ni documentado en el contrato DB) sin tocar código a ciegas.
- Error mapping: construir la tabla exigida en `TASK_AUTORIZADA.md` §19 (DB semantic → backend `ErrorDefinition` → HTTP status → `ApiErrorResponse.code`) para `SEC_001/SEC_002/ATT_001-003/SES_001/SES_003/SES_004/RC_001/GEN_002/EST_004`, resolviendo primero cómo se obtiene una señal determinista del result set de 4 columnas — o declarar `CONTRACT_CONFLICT` si no existe.
- Attendance: confirmar dominio canónico `AN/SJC/EX` de punta a punta y ausencia de alias legado (`A/F/J/T`) en la vertical de asistencia — no se encontraron alias legado en el código inspeccionado hasta ahora, pero 02-contratos debe hacer el barrido completo exigido en §13 y por 05-auditor en §32.
- Temporal: decisión mínima de UTC explícito para `Sesion.fechaHoraInicio/fechaHoraFin` en la frontera JDBC (§20-21) y marca `READY_FOR_OPENAPI_DECISION` para la representación HTTP (§22), sin tocar wire format todavía.
- `BACKEND_GOLDEN_PATH_CONTRACT.md` (nuevo, responsabilidad de 02-contratos, no de este PLAN) con el contenido exigido en §33.

## Clase de cambio y alcance de rutas

- **Change class de este PLAN.md: `CONTRACT_ANALYSIS`.** No se modifica producción, tests ni contratos DB. El resultado habilita — no ejecuta — las clases de cambio posteriores del pipeline (`CONTRACT_CHANGE` + `BEHAVIOR_CHANGE` para 02-contratos/04-implementador, ya anticipables: retiro de `idDocente`/`aula` como ghost params, mapeo de errores, posible ajuste de representación temporal).
- Variable principal de esta fase (una sola): **alinear las firmas y proyecciones JDBC del Golden Path backend al `DB_BASELINE_CONTRACT.md` congelado, sin modificar DB ni ampliar el alcance HTTP/OpenAPI.**
- Allowed (rutas permitidas para este PLAN):
  - Lectura de `src/main/java/**`, `src/test/java/**`, `pom.xml` (sin escritura).
  - Lectura del repo DB únicamente en `C:\Users\josev\OneDrive\Documentos\AsisteciaUco_db\git\gestion-asistencia-db` (ya usada solo para el precheck previo; este PLAN no reabrió ese repo).
  - Escritura: únicamente `docs/work-items/LB-001B.3-backend-db-alignment/PLAN.md` (este archivo).
- Forbidden (rutas prohibidas):
  - `src/main/**`, `src/test/**`, `pom.xml` (ninguna escritura).
  - DB (`schema/**` u otro archivo del repo DB) y `AsistenciasUCO-Frontend` (no abrir).
  - `docs/contracts/openapi/**` (crear OpenAPI), cualquier `@Entity`/`JpaRepository`, Redis, infraestructura serverless, WebFlux.
  - Los demás archivos del work item (`CONTRACT_MATRIX.md`, `TEST_PLAN.md`, `RED_SNAPSHOT.md`, `VALIDATION.md`, `AUDIT.md`, `CLOSURE.md`) — responsabilidad de las fases 02-06, no de 01-planificador.

Lo no listado como Allowed no se modifica. Ampliar el alcance exige actualizar este PLAN con aprobación.

## Alcance

Golden Path completo definido en `TASK_AUTORIZADA.md` §7: `GET /api/v1/docente/horarios`, `GET /api/v1/sesiones/grupo/{grupoId}`, `GET /api/v1/grupos/{grupoId}/estudiantes`, `GET /api/v1/grupos/{grupoId}/asistencias?sesionId=...`, `POST /api/v1/asistencias/lote`, `GET /api/v1/realtime/stream?grupoId=...`, más crear/actualizar Sesion (por cambio de SP). Incluye: firmas SP de Sesion, proyecciones de lectura (`uv_sesion`, `uv_horario_docente`, `uv_estudiante_grupo`, `uv_asistencia`, `uv_detalle_asistencia`), dominio de asistencia `AN/SJC/EX`, ejecutor/RBAC, mapeo de errores `SEC_*/ATT_*/SES_*/RC_*/GEN_*/EST_*/GEN_*`, semántica temporal UTC, realtime (tipo + serialización + nota de escalabilidad), correlación, catálogos (verificación de neutralidad, no reemplazo), auditoría de "serverless readiness" (solo hallazgos, sin refactor).

## No alcance

DB (ningún cambio de esquema/SP), frontend, creación de OpenAPI, entidades JPA o inicio de migración JDBC→JPA, Redis, infraestructura serverless, cambio de framework MVC→WebFlux, endpoints nuevos sin necesidad contractual, refactor masivo fuera del Golden Path, relajar ArchUnit o los gates de cobertura (`LINE ≥80%`/`BRANCH ≥70%` de `pom.xml`), reabrir el alcance ya cerrado de LB-001B.1 (retiro de `descripcion/aula/tipo` de Sesion) más allá de auditar su vigencia contra el contrato recién importado.

## Archivos afectados

Ninguno de producción/test en esta fase (`CONTRACT_ANALYSIS` puro). Referencia para 02-contratos (EXISTENTES, ruta comprobada en esta sesión, pendientes de decisión contractual — no se tocan aquí):

- `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` (retiro `idDocente` de 3 SP).
- `src/main/java/co/edu/uco/asistenciasuco/application/secondaryports/repository/dto/CrearSesionRepositoryDTO.java` y `ActualizarSesionRepositoryDTO.java` (¿retirar `docente`/`getDocente()`?).
- `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/academic/HorarioDocenteSqlServerAdapter.java`, `HorarioDocenteProjection.java`, `HorarioDocenteDomain.java`, `HorarioDocenteDTO.java`, `ConsultarHorariosDocenteRepositoryMapper.java`, `ConsultarHorariosDocenteMapper.java` (retiro `aula`).
- `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` y `DbExceptionTranslator.java` (mapeo determinista de códigos DB — pendiente de decisión de diseño en 02-contratos, no de este PLAN).
- Cadena temporal de Sesion (`JdbcValueMapper`, `CrearSesionDomain`/`ActualizarSesionDomain`, mappers HTTP) — auditoría UTC.

NUEVOS (propuesta, no confirmados en este PLAN): ninguno de código. `docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` es NUEVO pero corresponde a 02-contratos (`TASK_AUTORIZADA.md` §33), no a esta fase.

RETIRAR: ninguno en esta fase (el retiro de `idDocente`/`aula` como parámetros/campos es TARGET de 02-contratos → 04-implementador, condicionado a contrato aprobado).

## Contratos y consumidores afectados

- **PERSISTENCE**: SP `usp_crear_sesion`, `usp_actualizar_sesion` (firma), vistas `uv_sesion` (ya MATCH), `uv_horario_docente` (MISMATCH `aula`). Consumidor: capas Application/HTTP internas del propio backend; no hay consumidor externo de la firma JDBC.
- **HTTP/DOMAIN**: `POST /sesiones` (crear), `PUT /sesiones/{id}` (actualizar), `GET /docente/horarios` — consumidor real: `AsistenciasUCO-Frontend` (no se abre en esta fase; compatibilidad se verifica por evidencia ya existente en `CLOSURE.md` de LB-001B.1 para el caso análogo `descripcion/aula/tipo`, referenciando el work item hermano `LB-001B.1B-db-source-of-truth-cleanup` del repo frontend, cuyo estado NO se re-verifica aquí — fuera de alcance leer ese repo).
- **SECURITY**: `SEC_001`/`SEC_002` → mapeo a `FORBIDDEN`/403 — pendiente de decisión determinista (ver AS-IS). Consumidor: frontend vía `ApiErrorResponse.code`.
- **REALTIME**: `RealtimeEvent.occurredAt` (`Instant`) — consumidor: canal SSE local, un solo proceso, sin distribución.
- Ningún contrato se aprueba ni se congela en este PLAN; aprobación formal es responsabilidad de 02-contratos con decisión/responsable/referencia versionada, tal como exige `DEFINITION_OF_READY.md`.

## Riesgos y dependencias

1. **Rama DB fuente no fusionada a `main`/`develop`** (`PROVENANCE.md`): si `feat/db-golden-path-baseline-freeze` recibe nuevos commits antes del cierre de LB-001B.3, el snapshot importado queda desactualizado y debe re-capturarse con nuevo SHA-256 antes de cerrar. Mitigación: cualquier fase posterior que dependa de un detalle no cubierto por este snapshot debe registrar `BLOCKED_BY_MISSING_EVIDENCE`, no asumir texto del repo DB no importado.
2. **Trabajo de LB-001B.1 sin commit** (`src/main/java/.../sesion/**` crear/actualizar, ~18 archivos + tests): cualquier `git checkout`/`git reset`/`git clean` sobre esas rutas destruye ese trabajo ya cerrado (`DONE`). Mitigación obligatoria para todas las fases siguientes: antes de cualquier operación destructiva de git, ejecutar `git status`/`git diff` y, si es necesario, `git stash push -u` o commit explícito de esos archivos primero; nunca `reset --hard`/`checkout --` sobre `src/main/java/co/edu/uco/asistenciasuco/**/sesion/**` sin verificar contra `GOLDEN_PATH_DIRTY_FILE_HASHES.txt`.
3. **87 entradas dirty en el working tree**, muchas ajenas a este work item (Azure Key Vault, catálogos, gobernanza `??`): riesgo de que un `mvn verify`/build capture ruido no relacionado o que un commit futuro mezcle cambios de alcances distintos. Mitigación: cada fase posterior debe listar explícitamente qué archivos toca y verificar que el resto del diff no cambió (patrón ya usado por 06-cierre de LB-001B.1).
4. **Gap de clasificación de errores DB** (ver AS-IS): riesgo de que 02-contratos no pueda completar el mapeo `SEC_*/ATT_*/SES_*` de forma determinista con el result set de 4 columnas documentado, forzando `CONTRACT_CONFLICT` y deteniendo esa porción del alcance (batch de asistencia, crear/actualizar sesión, RBAC). Es el riesgo de mayor impacto en el Golden Path porque toca casi todos los endpoints.
5. **Margen de cobertura BRANCH ajustado** (heredado, no verificado de nuevo en esta sesión): `CLOSURE.md` de LB-001B.1 reporta BRANCH 70,53% contra gate ≥70% — margen de ~0,53 puntos. Cualquier cambio de ramas no cubiertas (p. ej. retirar `idDocente`) puede hacer caer el gate; 03-tester-red/04-implementador deben vigilarlo activamente.
6. **`uv_horario_estudiante` sin contrato documentado**: si una fase posterior decide tocarlo sin evidencia DB, violaría "no inventar información ausente del contrato" (`TASK_AUTORIZADA.md` §6). Mitigación: mantenerlo fuera de alcance explícito hasta que exista evidencia contractual.
7. **Extracción de `idUsuarioEjecutor` no localizada por nombre de clase en esta sesión**: riesgo bajo (el dato sí llega al SP), pero 02-contratos debe confirmar el punto exacto de extracción y su neutralidad de proveedor antes de dar la sección 16 por cerrada.

## Test plan

No aplica en esta fase (`CONTRACT_ANALYSIS`, sin RED todavía). Referencia obligatoria para la fase siguiente: `TEST_PLAN.md` (03-tester-red), que debe cubrir como mínimo los 16 puntos A-P de `TASK_AUTORIZADA.md` §27 (firma crear/actualizar sesión sin `idDocente`/ghost params, mapper `uv_sesion` exacto, mapper horario sin `aula`, batch solo `AN/SJC/EX`, unknown fail-closed, ausencia de fila ≠ `AN`, `idUsuarioEjecutor` obligatorio, `SEC_001`/`SEC_002` → 403/FORBIDDEN, `SES_001` not found, `SES_003` sin fake success, `ATT_*` clasificación correcta, temporal sin `systemDefault`, realtime UTC, correlación propagada), secuencia RED → GREEN → VALIDATE, sin que el implementador modifique los RED para pasar.

## Rollback

Esta fase no modifica código, por lo que su rollback es trivial: descartar `docs/work-items/LB-001B.3-backend-db-alignment/PLAN.md` (único archivo escrito) no afecta `src/main/**`, `src/test/**` ni el trabajo sin commit de LB-001B.1. Para fases posteriores (02-06), el rollback recomendado es:

1. Nunca usar `git reset --hard`/`git clean -f` sobre el árbol completo mientras exista trabajo sin commit de LB-001B.1 y de gobernanza (`??`).
2. Si una fase de implementación necesita revertirse, hacerlo por archivo específico (`git checkout -- <archivo>` o revertir el diff puntual) verificando primero contra `GOLDEN_PATH_DIRTY_FILE_HASHES.txt` que el archivo no pertenece al alcance ya cerrado de LB-001B.1, o que su hash post-LB-001B.3 puede distinguirse del hash pre-LB-001B.3.
3. Preferir commits incrementales por sub-fase (02-contratos, 03-tester-red, 04-implementador) en vez de un único commit monolítico, para poder revertir LB-001B.3 sin tocar LB-001B.1 si ambos terminan comiteados en secuencia.

## Stop conditions

- **`CONTRACT_CONFLICT` candidato (sin decidir en este PLAN):** mapeo determinista de `SEC_001/SEC_002/ATT_001-003/SES_003/SES_004/RC_001/GEN_002/EST_004` contra un result set de solo 4 columnas (`idCorrelacion, mensajeUsuarioResultado, mensajeTecnicoResultado, estadoResultado`), sin campo `codigo` garantizado por el contrato. 02-contratos debe resolverlo o declarar `CONTRACT_CONFLICT`/STOP formal para esa porción exacta del alcance (no para todo el work item).
- **`BLOCKED_BY_MISSING_EVIDENCE` puntual:** `uv_horario_estudiante` no documentada en `DB_BASELINE_CONTRACT.md`. No bloquea el resto (el endpoint no está en el Golden Path de la tarea); se registra para que nadie la modifique sin evidencia.
- Ningún `CONTRACT_CONFLICT`/`TEST_CONTRACT_CONFLICT`/`BLOCKED_BY_MISSING_EVIDENCE` abierto bloquea el inicio de `CONTRACT_ANALYSIS` (02-contratos) — sí bloquearán, si no se resuelven, el cierre de las porciones afectadas (error mapping) antes de pasar a `IMPLEMENT`.

## Deuda conocida y validación manual

- Reconciliar en esta fase (por 02-contratos/06-cierre), no aquí: `DR-006` (dominio de `estado` en lectura), `DR-009`/`TD-030` (códigos de error de autorización/titularidad — directamente relacionado con el gap de clasificación de errores hallado en este PLAN), `TD-005` (política temporal DB/API).
- Candidatos NUEVOS a registrar formalmente por 02-contratos/06-cierre (no se abren TD aquí, solo se documentan como hallazgo de este PLAN): (a) `idDocente` como ghost param de Sesion SP, (b) `aula` como campo leído de `uv_horario_docente` contra el contrato, (c) `ReactorRealtimeAdapter` como `NOT_DISTRIBUTED`/`SERVERLESS_SCALE_OUT_BLOCKER` (ya auto-documentado en código), (d) ausencia de mapeo determinista de códigos DB formales en `DbFailureClassifier`/`DbExceptionTranslator`.
- MV-001 (E2E frontend + Keycloak + SQL Server + SSE) sigue pendiente, heredada de LB-001B.1; no se ejecuta en esta fase.

## Definition of Ready

**READY para `CONTRACT_ANALYSIS`** (02-contratos puede proceder a construir `CONTRACT_MATRIX.md`):

- Repositorio/snapshot DB identificado con hash verificado (`PRECHECK_SNAPSHOT.md` §1) — cumplido.
- Owner (`backend-team`) y consumidor (frontend, vía contrato HTTP existente) identificados — cumplido.
- Golden Path definido con endpoints exactos (`TASK_AUTORIZADA.md` §7) y alcance de objetos DB definido (`DB_BASELINE_CONTRACT.md` §"Golden Path Object Inventory") — cumplido.
- Ningún secreto en la evidencia recolectada — cumplido (solo nombres de columnas/parámetros y rutas de archivo).
- Capacidad de inspeccionar provider (repo DB, solo lectura, ya usado en precheck) y consumer (código backend real, leído en esta sesión) — cumplido.

**NOT_READY para implementación** (`CONTRACT_CHANGE`/`BEHAVIOR_CHANGE` en `src/main/**`): no procede iniciar 04-implementador todavía. Motivo: no existe todavía `CONTRACT_MATRIX.md` aprobado ni `TEST_PLAN.md` trazable, y quedan dos bloqueos explícitos sin resolver:

1. `CONTRACT_CONFLICT` candidato de mapeo de errores DB (ver "Stop conditions") — decisión de diseño pendiente en 02-contratos.
2. `BLOCKED_BY_MISSING_EVIDENCE` puntual de `uv_horario_estudiante` — no bloquea el Golden Path pero debe quedar registrado antes de tocar esos archivos.

Responsable de la siguiente decisión: 02-contratos, con base en este PLAN y en `DB_BASELINE_CONTRACT.md`. Ninguna fase se inicia automáticamente por la existencia de este documento.
