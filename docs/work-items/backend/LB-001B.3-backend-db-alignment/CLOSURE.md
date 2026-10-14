---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# CLOSURE — LB-001B.3: BACKEND ALIGNMENT AGAINST FROZEN DB BASELINE

> **Actualización 2026-09-23 (06-cierre, LB-001B.4): DONE / SUPERSEDED BY [LB-001B.4](../LB-001B.4-final-backend-contract-closure/CLOSURE.md).** El `CONTRACT_CONFLICT` de mapeo de errores DB y el tercer lector UTC pendientes aquí se resolvieron en LB-001B.4. El texto siguiente es el registro histórico del cierre parcial y no se reescribe.

Fase 06-cierre. Fecha: 2026-09-23 (America/Bogota). Branch `sergio`, HEAD `fa9aa901c73e55ae31071f4e74cfb2245189243a`
(sin commit nuevo creado por esta fase ni por ninguna fase previa de este work item; el working tree
permanece dirty, ~100 entradas `git status --porcelain=v1`, incluido el trabajo sin commit de
`LB-001B.1` y de `LB-001B.3` mismo — ninguno revertido, confirmado en `AUDIT.md` §4).

## Resultado

**PARTIAL — sub-alcance desbloqueado `DONE`, work item completo `NOT_READY`.**

No se cumple el criterio de salida íntegro de `TASK_AUTORIZADA.md` §35: el mapeo determinista de
errores DB (`SEC_001/SEC_002/ATT_001-003/SES_003/SES_004/GEN_002`, `CONTRACT_MATRIX.md` fila M-19)
permanece `CONTRACT_CONFLICT` sin resolver, por decisión explícita del usuario (2026-09-23) de
continuar solo con el alcance ya desbloqueado en `CONTRACT_FREEZE.md` §1-5. Conforme a `AGENTS.md`
("Cerrar solo si cumple la DoD única" / "No cerrar algo solo porque debería estar resuelto"), este
documento **no declara `LB-001B.3: DONE`** ni `DB ↔ BACKEND: ALIGNED` en el sentido íntegro de
`TASK_AUTORIZADA.md` §36. Declara `DONE` únicamente la porción efectivamente congelada, implementada,
verificada en RED→GREEN y auditada de forma independiente.

| Área DoD | Evidencia | Veredicto |
|---|---|---|
| Alcance y contrato | `CONTRACT_MATRIX.md` (24 filas: M-01 a M-24) + `CONTRACT_FREEZE.md` (porciones congeladas §1-5). Bloqueo 1 (M-19, mapeo de errores) declarado `CONTRACT_CONFLICT` explícito, no una omisión | **PARCIAL** — congelado y aprobado solo para Sesion SP signatures, horario docente, temporal Sesion (parcial) |
| RED → GREEN | `TEST_PLAN.md`/`RED_SNAPSHOT.md` (5 archivos de test, puntos A/B/C/D/E/F/G/H/N/P de §27); 2 `TEST_CONTRACT_CONFLICT` reales detectados y dictaminados por `05-auditor` (`AUDIT.md` §3.1-3.2, resuelto vía revisión de `CONTRACT_FREEZE.md` §5; y uno nuevo en `VALIDATION.md` §7.2, sin resolver — ver "Elementos pendientes") | **PARCIAL** — puntos A/B/D/C/E/F/G/H/P GREEN completo; punto N GREEN parcial (2/3 llamadores); puntos I/J/K/M explícitamente no derivados (fuera de alcance por `CONTRACT_CONFLICT`); punto O no alcanzado |
| Build | `.\mvnw.cmd -B -ntp verify` → **BUILD SUCCESS**, reproducido de forma independiente por `05-auditor` (`AUDIT.md` §1): `Tests run: 936, Failures: 0, Errors: 0, Skipped: 0` | **PASS** |
| Arquitectura | ArchUnit — 16 clases bajo `co.edu.uco.asistenciasuco.architecture.*`, 0 failures/errors, confirmado independientemente | **PASS** |
| Coverage | JaCoCo `jacoco:check` ejecutado dentro del `verify` reproducido, `[INFO] All coverage checks have been met.` — LINE 85,62 % (gate ≥80 %), BRANCH 70,51 % (gate ≥70 %, margen ajustado, ~0,51 puntos — mismo riesgo heredado de LB-001B.1, agravado en 0,02 puntos) | **PASS**, con margen BRANCH a vigilar |
| Persistencia | Sin cambio de esquema DB; SP `usp_crear_sesion`/`usp_actualizar_sesion` alineados a la firma congelada (retiro `@idDocente`); `uv_horario_docente` alineada (retiro `aula`); UTC de Sesion resuelto en 2 de 3 llamadores confirmados (`SesionRepositorySqlServerAdapter`, `ReporteAsistenciaSqlServerAdapter`); `SesionMateriaEstudianteSqlServerAdapter` **NO** resuelto (`TEST_CONTRACT_CONFLICT` pendiente) | **PARCIAL** |
| Seguridad | Sin cambios en 401/403/ownership existentes (AS-IS preservado); el mapeo formal `SEC_001/SEC_002 → 403/FORBIDDEN` exigido por §17 de la tarea **no se implementó** — sigue cayendo en `ERR_DB_UNCLASSIFIED`/500 tal como estaba antes de este work item; cero secretos nuevos; cero dependencias nuevas (`pom.xml` sin JPA/Hibernate/Redis/Lettuce/WebFlux, confirmado por grep en esta sesión) | **PARCIAL** — sin regresión, pero sin la mejora exigida por la tarea |
| Operación | Sin cambios en logs/metrics/traces/correlationId fuera de las rutas tocadas; correlación propagada confirmada (M-16/M-17 MATCH); `ReactorRealtimeAdapter` confirmado `NOT_DISTRIBUTED`/`SERVERLESS_SCALE_OUT_BLOCKER` (ya auto-documentado, M-24), registrado formalmente como deuda | **PASS** para lo tocado |
| CI | No se afirma resultado de CI remoto; solo `verify` local, reproducido de forma independiente dos veces (`04-implementador` §7.3 de `VALIDATION.md`, `05-auditor` §1 de `AUDIT.md`) | Documentado, sin inferir remoto |
| Documentación | Este `CLOSURE.md`; `TECHNICAL_DEBT.md` con 7 entradas nuevas (`TD-036`–`TD-042`) + refuerzo de `TD-003`/`TD-034` (sin IDs nuevos duplicados) + actualización de `TD-005`; `LINEA_BASE.md` actualizado a `IN_PROGRESS`/`PARTIAL` | **PASS** |
| Cierre | Este documento; ver "Elementos pendientes y bloqueos" | **PARCIAL, honesto** |

**No se declara `READY_FOR_LB001C`.** El criterio de salida de `TASK_AUTORIZADA.md` §35 exige
explícitamente `SEC_001: MAPPED`, `SEC_002: MAPPED`, `ATT_*: MAPPED`, `SES_*: MAPPED` — ninguno se
cumple. `TD-030`/`DR-009` (semántica de `VAL_003`) y el `CONTRACT_CONFLICT` de mapeo de errores de
este mismo work item son la misma familia de bloqueo no resuelta. `LB-001C` sigue `NOT STARTED`.

## Declaraciones explícitas (verificadas en esta sesión, no heredadas sin comprobar)

- **`DATABASE MODIFIED: NO`** — ningún archivo del repo DB fue abierto en escritura en ninguna fase de
  este work item (solo lectura de `DB_BASELINE_CONTRACT.md`/`.sha256`, conforme a `TASK_AUTORIZADA.md`
  "NO abrir"). El repo DB (`gestion-asistencia-db`) no fue tocado.
- **`FRONTEND MODIFIED: NO`** — `AsistenciasUCO-Frontend` no fue abierto en ninguna fase de este work
  item (prohibido explícitamente por la tarea). El riesgo de breaking change para el consumidor real de
  `GET /api/v1/docente/horarios` (retiro de `aula` del JSON) **no fue verificado contra el frontend
  real** — se registra como riesgo abierto, no como confirmado ni descartado.
- **`OPENAPI STARTED: NO`** — verificado en esta sesión: `docs/contracts/openapi/` no existe;
  `contracts/openapi/` (raíz del repo) permanece vacío/placeholder; `docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md`
  (exigido por `TASK_AUTORIZADA.md` §33) **no existe** — el work item no alcanzó esa fase.
- **`JPA STARTED: NO`** — verificado en esta sesión: `grep -i -E "jpa|hibernate|redis|lettuce|reactor-netty-webflux" pom.xml`
  sin coincidencias.
- **`REDIS STARTED: NO`** — mismo grep, sin coincidencias.
- **`SERVERLESS INFRA STARTED: NO`** — sin infraestructura serverless nueva; `TASK_AUTORIZADA.md` §26
  solo exigía auditoría, cumplida (M-24, `ReactorRealtimeAdapter` documentado, sin refactor).

## Alcance entregado y verificado (DONE dentro del sub-alcance)

Congelado en `CONTRACT_FREEZE.md` §1-5, implementado por `04-implementador`, verificado GREEN por
`mvn verify` reproducido de forma independiente y auditado post-GREEN por `05-auditor`
(`AUDIT.md`, sección "AUDITORÍA POST-GREEN §32"):

- **`idDocente` retirado como parámetro SP de `usp_crear_sesion`/`usp_actualizar_sesion`**
  (`SesionRepositorySqlServerAdapter.java`, `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION` y sus
  `MapSqlParameterSource`) — **MATCH, GREEN, confirmado independientemente** (`AUDIT.md` §2.2, §5:
  "Veredicto `idDocente` como ghost param de Sesion crear/actualizar: 0"). `usp_cerrar_sesion` conserva
  `@idDocente` **por decisión explícita** (fuera de este freeze, `CONTRACT_FREEZE.md` §3, `SP
  legacy OUT_OF_TARGET`) — no es un hallazgo sin clasificar.
- **`aula` retirada de la proyección `uv_horario_docente`** en todo el pipeline (`adapter → projection
  → domain → DTO → HTTP`) — **MATCH, GREEN, confirmado independientemente** (`AUDIT.md` §2.1, §5). Es
  un `CONTRACT_CHANGE` real de la respuesta HTTP de `GET /api/v1/docente/horarios` (11→10 campos JSON);
  no verificado contra el consumidor frontend real (ver "Declaraciones explícitas").
- **UTC de Sesion — resuelto parcialmente (2 de 3 llamadores confirmados):**
  `JdbcValueMapper.toLocalDateTimeUtc(Object)` (método nuevo, `CONTRACT_FREEZE.md` §5.1) decodifica
  `Sesion.fechaHoraInicio`/`fechaHoraFin` como UTC fijo, ignorando `TimeZone.getDefault()` en el momento
  de la lectura. Aplicado y verificado GREEN en `SesionRepositorySqlServerAdapter` (2 métodos,
  `consultarSesion`/`consultarSesionesPorGrupo`) y `ReporteAsistenciaSqlServerAdapter` (1 punto,
  aunque sin aserción de test que lo proteja de regresión — ver deuda `TD-038`). El tercer llamador
  confirmado, `SesionMateriaEstudianteSqlServerAdapter`, **NO fue corregido** — permanece con la
  dependencia de `TimeZone.getDefault()` por un `TEST_CONTRACT_CONFLICT` nuevo descubierto durante la
  implementación (`VALIDATION.md` §7.2), sin resolver. `JdbcValueMapper.toLocalDateTime(Object)` (el
  helper genérico) permanece intacto, sin cambio de comportamiento, tal como exigía `CONTRACT_FREEZE.md`
  §5.3.
- **Estados canónicos de asistencia `AN`/`SJC`/`EX`, fail-closed, sin alias legado** — **MATCH,
  GUARANTEED, confirmado independientemente** (`RegistroAsistenciaSesionDomain.ESTADOS_VALIDOS`;
  `AUDIT.md` §2.4: "0 coincidencias como alias legado"). Ausencia de fila ≠ `AN` (sin síntesis) también
  **MATCH confirmado** (M-13).
- **`idUsuarioEjecutor` obligatorio, provider-neutral** (`SecurityContextAuthenticatedUserResolver`) y
  **correlación propagada a los 7 SP de escritura de Sesion/Asistencia** — **MATCH confirmado**, sin
  cambio de código en esta fase (ya cumplía el contrato; solo se documentó formalmente en
  `CONTRACT_MATRIX.md` M-15/M-16/M-17).
- **Build/arquitectura/cobertura verdes**, reproducidos de forma independiente por `05-auditor`, no solo
  reportados por `04-implementador`: `mvn verify` `BUILD SUCCESS` (936/936), ArchUnit PASS (16 clases),
  JaCoCo PASS real (LINE 85,62 %/BRANCH 70,51 %, gate ejecutado, no proyectado).
- **Dos `TEST_CONTRACT_CONFLICT` reales gestionados conforme a `AGENTS.md` §4**, sin que el
  implementador alterara ningún test RED para forzar GREEN: el primero (helper genérico vs. test nuevo
  de estabilidad UTC) fue dictaminado por `05-auditor` y resuelto mediante una revisión de contrato
  (`CONTRACT_FREEZE.md` §5.0-5.6, método dedicado `toLocalDateTimeUtc`); el segundo (fixture de
  `SesionMateriaEstudianteSqlServerAdapterTest`) fue detectado, documentado y **dejado sin resolver**
  por decisión correcta del rol (`04-implementador` revirtió el cambio de producción dependiente en vez
  de tocar el test), pendiente de autorización de `02-contratos`/`03-tester-red`.

## Qué queda explícitamente abierto/bloqueado (NOT_READY)

1. **Bloqueo 1 — mapeo determinista de errores DB (`CONTRACT_MATRIX.md` fila M-19, `CONTRACT_FREEZE.md`
   §6): `CONTRACT_CONFLICT` sin resolver, por decisión explícita del usuario (2026-09-23) de continuar
   solo con el alcance desbloqueado.** `DbFailureClassifier`/`DbExceptionTranslator` siguen siendo 100 %
   *pattern matching* de texto libre; ningún literal `SEC_001/SEC_002/ATT_001/ATT_002/ATT_003/SES_003/
   SES_004/GEN_002` existe como señal de clasificación. 8 de 11 códigos relevantes del Golden Path caen
   hoy en `ERR_DB_UNCLASSIFIED` → HTTP 500 en vez de 403/400/409, violando `TASK_AUTORIZADA.md` §17
   ("No devolver 500") para RBAC/titularidad. `SES_001`/`RC_001`/`EST_004` funcionan hoy solo por
   coincidencia accidental de texto libre, sin garantía contractual. Ningún archivo de
   `DbFailureClassifier.java`/`DbExceptionTranslator.java` fue tocado en este work item. Esto bloquea
   `LB-001C` (criterio de salida §35: `SEC_001/SEC_002/ATT_*/SES_*: MAPPED`).
2. **`TEST_CONTRACT_CONFLICT` sin resolver — `SesionMateriaEstudianteSqlServerAdapterTest`**
   (`VALIDATION.md` §7.2, `AUDIT.md` §3): mismo defecto de fixture ya dictaminado para
   `SesionRepositorySqlServerAdapterTest` (round-trip simétrico agnóstico de zona,
   `CONTRACT_FREEZE.md` §5.4), pero en un archivo que ni `CONTRACT_FREEZE.md` ni el primer dictamen de
   `05-auditor` cubrieron. Requiere que `02-contratos` autorice y `03-tester-red` aplique la misma
   corrección de fixture antes de que `04-implementador` pueda re-aplicar el cambio de llamada en
   `SesionMateriaEstudianteSqlServerAdapter.java` (revertido en esta sesión, AS-IS con
   `toLocalDateTime`, dependiente de zona).
3. **`M-03` (`usp_cerrar_sesion`/`POST /api/v1/sesiones/cierres`) — `BLOCKED_BY_MISSING_EVIDENCE`**: la
   firma exacta de parámetros del SP legacy no está documentada en `DB_BASELINE_CONTRACT.md`, solo su
   comportamiento (`SES_003`, sin escrituras). Clasificado `OUT_OF_TARGET`/`LEGACY_NOT_SUPPORTED` para
   el contrato target de `LB-001C`, sin tocar código. El endpoint HTTP sigue vivo (no es código muerto),
   fuera del Golden Path de `TASK_AUTORIZADA.md` §7.
4. **`M-08` (`uv_estudiante_identidad`/`uv_usuario`) — `BLOCKED_BY_MISSING_EVIDENCE`, SÍ dentro del
   Golden Path** (`GET /api/v1/grupos/{grupoId}/estudiantes`): estas dos vistas, usadas activamente por
   `GrupoRepositorySqlServerAdapter.SQL_CONSULTAR_ESTUDIANTES_GRUPO` para derivar `documento`/`correo`/
   `nombreCompleto`, no están documentadas en `DB_BASELINE_CONTRACT.md` (ni en el inventario de objetos
   ni en las proyecciones de lectura). El comportamiento AS-IS no se tocó (sigue operando); no se puede
   confirmar `MATCH` ni `MISMATCH` sin evidencia DB adicional.
5. **`M-06` (`uv_horario_estudiante`) — `NOT_APPLICABLE`/`OUT_OF_TARGET`** para esta fase: vista no
   documentada en el contrato congelado, endpoint fuera del Golden Path de la tarea. No tocado.
6. **`M-22` (serialización realtime UTC) — `MISSING_IN_BACKEND`**: el tipo `Instant` de
   `RealtimeEvent.occurredAt` es correcto (`MATCH` de tipo), pero no existe ningún test que asegure que
   la serialización HTTP/SSE efectivamente emite ISO-8601 con `Z`. Punto **O** de `TASK_AUTORIZADA.md`
   §27, evaluado y explícitamente no alcanzado por `03-tester-red` (riesgo de RED fabricado por el
   arnés de prueba sin un `JacksonOutputConfig`/`ApplicationContext` real — ver `TEST_PLAN.md`, sección
   "Punto O").
7. **Integration tests (`-Pintegration`, `SqlStoredProcedureContractIT`/`AsistenciaRepositorySqlServerIT`)
   — no ejecutados en ningún momento de este work item.** `TASK_AUTORIZADA.md` §30 exige una instancia
   CLEAN construida desde el baseline DB congelado, no `sql_server_asistencias` si sigue
   `DEV_INSTANCE_REBUILD_REQUIRED`; sin evidencia de que dicha instancia esté disponible en esta sesión.
   Registrado como `VALIDATION_BLOCKED_BY_ENVIRONMENT`, no como PASS asumido — el riesgo específico no
   cubierto por unit tests es el comportamiento real de `mssql-jdbc` al leer `DATETIME2` vía
   `rs.getObject(...)` (`AUDIT.md` §"Opción A", último punto: "no pude confirmar el comportamiento
   concreto de `mssql-jdbc`... esto debe verificarse en una IT real").
8. **Rama DB origen (`feat/db-golden-path-baseline-freeze`) no fusionada a `main`/`develop`** del repo
   `gestion-asistencia-db` (`docs/contracts/external/db/PROVENANCE.md`): si esa rama recibe nuevos
   commits antes de que `LB-001C` congele el contrato, el snapshot importado (`DB_BASELINE_CONTRACT.md`,
   SHA-256 `1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103`) queda desactualizado.

## Deuda

### Reconciliación de deuda heredada (`TASK_AUTORIZADA.md` §34)

Conforme a la instrucción explícita de no cerrar deuda "solo porque debería estar resuelta": se revisó
cada uno de los cuatro ítems citados contra la evidencia real generada por este work item.

- **`DR-006` (dominio de `estado` en lectura) — NO se cierra. Evidencia insuficiente/ambigua, se declara
  explícitamente en vez de asumir.** Este work item confirmó (M-14, `CONTRACT_MATRIX.md`) que el
  dominio canónico `AN`/`SJC`/`EX` es `GUARANTEED` **en el lado de escritura** (constructor de
  `RegistroAsistenciaSesionDomain`, fail-closed) y confirmó (M-13) que la ausencia de fila no se
  sintetiza como `AN` en el lado de lectura. Sin embargo, **no se auditó ni se agregó ningún test que
  valide que el propio valor `codigoRazonCausa` leído de `uv_detalle_asistencia` esté restringido al
  dominio canónico en el camino de lectura** (`ConsultarAsistenciasPorGrupoUseCaseImpl` mapea 1:1 lo que
  la vista devuelve, sin validación de dominio) — si la vista DB pudiera devolver un valor fuera de
  `AN`/`SJC`/`EX` (histórico o de otro dominio), el backend lo propagaría sin fail-closed en lectura.
  Esto es precisamente el alcance original de DR-006 y **no quedó cubierto por el `TEST_PLAN.md` de
  esta fase** (puntos E/F/G solo cubren escritura y ausencia-de-síntesis, no dominio-en-lectura). Se
  declara explícitamente: la evidencia de este work item es insuficiente para cerrar DR-006; permanece
  **ABIERTA**.
- **`DR-009`/`TD-030` (códigos de error de autorización/titularidad, `VAL_003`) — NO se cierra.**
  Directamente relacionado con el Bloqueo 1 de este mismo work item (mapeo determinista de errores DB).
  El `CONTRACT_CONFLICT` de M-19 es, en efecto, la manifestación exacta de este defecto a nivel de
  contrato: sin código de catálogo estable, no se puede construir el mapeo `SEC_*`/`VAL_003` exigido por
  `DR-009`. **Sigue ABIERTA**, sin cambio de evidencia adicional respecto a `LB-001B.1`.
- **`TD-005` (política temporal DB/API) — NO se cierra; se registra avance parcial real, no ficticio.**
  Este work item aporta evidencia nueva y concreta: 2 de 3 llamadores confirmados de
  `Sesion.fechaHoraInicio`/`fechaHoraFin` ya decodifican con semántica UTC fija
  (`toLocalDateTimeUtc`), verificado con test real (no solo Javadoc). El tercer llamador
  (`SesionMateriaEstudianteSqlServerAdapter`) permanece con el defecto original. La representación HTTP
  (wire format) permanece `READY_FOR_OPENAPI_DECISION`, sin cambio, tal como exige `TASK_AUTORIZADA.md`
  §22 — la decisión de si `LB-001C` migra a `Instant`/`OffsetDateTime` con offset explícito en el wire
  format sigue pendiente. `TD-005` permanece **ABIERTA**, con referencia actualizada a este work item
  como evidencia de avance parcial de persistencia (no de contrato HTTP).

### Deuda NUEVA registrada en esta fase

Ver `docs/baseline/TECHNICAL_DEBT.md` — **7 entradas nuevas** (`TD-036` a `TD-042`), más **refuerzo sin
ID nuevo** de dos entradas ya existentes cuyo hallazgo coincide exactamente con deuda ya abierta:

| Hallazgo del prompt de cierre | Tratamiento | Motivo |
|---|---|---|
| Mapeo determinista de errores DB (`CONTRACT_CONFLICT`, M-19) | **`TD-036` (nueva)** | Sin ID previo — el gap estructural de `DbFailureClassifier`/`DbExceptionTranslator` frente a códigos DB formales no estaba registrado como entrada propia (relacionado con `TD-007`, pero de alcance más preciso y con decisión de usuario documentada) |
| `SesionMateriaEstudianteSqlServerAdapter` — defecto latente de zona horaria | **`TD-037` (nueva)** | Hallazgo puntual y nuevo de este work item (`VALIDATION.md` §7.2, `AUDIT.md` §3), no registrado antes |
| `ReporteAsistenciaSqlServerAdapterTest` — brecha de cobertura temporal | **`TD-038` (nueva)** | Hallazgo puntual y nuevo (`AUDIT.md` §3), no registrado antes |
| `SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` — código muerto | **Sin ID nuevo — ya es `TD-034`** (abierta desde `LB-001B.1`, 2026-09-22) | El hallazgo de `05-auditor` de esta fase (`AUDIT.md` §2.7) es **exactamente el mismo** código muerto ya registrado; crear un ID nuevo duplicaría deuda y violaría "No reciclar IDs" en sentido inverso (registrar dos veces lo mismo). Se añade una nota de re-confirmación a `TD-034`, sin abrir `TD-043` |
| `usp_cerrar_sesion`/`POST /sesiones/cierres` — `BLOCKED_BY_MISSING_EVIDENCE` (M-03) | **`TD-039` (nueva)** | Hallazgo nuevo, sin entrada previa que cubra la firma no documentada de este SP específico |
| `uv_estudiante_identidad`/`uv_usuario` no documentadas, Golden Path (M-08) | **`TD-040` (nueva)** | Hallazgo nuevo; `TD-019` es demasiado genérico ("contratos DB ausentes o limitados", histórico) y no cita estas dos vistas específicas ni su impacto en el Golden Path |
| `ReactorRealtimeAdapter` — `NOT_DISTRIBUTED`/`SERVERLESS_SCALE_OUT_BLOCKER` (M-24) | **Sin ID nuevo — ya es `TD-003`** ("Realtime local efímero y por JVM", evidencia ya cita `ReactorRealtimeAdapter`) | Mismo componente, mismo hallazgo. Se añade referencia cruzada a `CONTRACT_MATRIX.md` M-24 y `TASK_AUTORIZADA.md` §26 en `TD-003`, sin duplicar |
| Rama DB origen no fusionada a `main`/`develop` (`PROVENANCE.md`) | **`TD-041` (nueva)** | Hallazgo nuevo, riesgo de desactualización del snapshot congelado, sin entrada previa |
| Test de serialización realtime UTC no creado (M-22) | **`TD-042` (nueva)** | Hallazgo nuevo, distinto de `TD-003` (que trata durabilidad/distribución, no serialización de fecha) |

## Validación manual

- MV-001 (E2E frontend + Keycloak + SQL Server + SSE, `USE_MOCKS=false`) sigue pendiente, heredada de
  `LB-001B.1`; no se ejecutó en ninguna fase de este work item.
- Ninguna otra entrada nueva de `MANUAL_VALIDATION_LEDGER.md` generada por este work item; las IT
  reales (`SqlStoredProcedureContractIT`, `AsistenciaRepositorySqlServerIT`) tampoco se ejecutaron (ver
  "Qué queda explícitamente abierto/bloqueado", punto 7).

## ADR relacionados

Ninguno nuevo. La decisión de `CONTRACT_FREEZE.md` §5 (Opción A: decodificación dedicada
`toLocalDateTimeUtc` en vez de `user.timezone=UTC` global) es una decisión de diseño acotada al alcance
de este work item, documentada en el propio `CONTRACT_FREEZE.md`/`AUDIT.md`, no una decisión
arquitectónica duradera que por sí sola requiera ADR nuevo — si `02-contratos` decide extender esa
decisión a otros dominios temporales en el futuro, ese sería el momento de evaluar un ADR.

## Elementos pendientes y bloqueos

Resumen consolidado (detalle completo en "Qué queda explícitamente abierto/bloqueado" arriba):

1. Bloqueo 1 (mapeo de errores DB, M-19) — `CONTRACT_CONFLICT`, decisión de usuario de dejarlo en
   espera. Bloquea el cierre íntegro de `LB-001B.3` y el inicio de `LB-001C`.
2. `TEST_CONTRACT_CONFLICT` de `SesionMateriaEstudianteSqlServerAdapterTest` — pendiente de
   `02-contratos`/`03-tester-red`.
3. `M-03`/`M-08` `BLOCKED_BY_MISSING_EVIDENCE` — requieren evidencia DB adicional no disponible en esta
   sesión (`M-08` es la más urgente por estar en el Golden Path).
4. `M-22` — test de serialización realtime UTC no creado.
5. Integration tests no ejecutados (`VALIDATION_BLOCKED_BY_ENVIRONMENT`).
6. Riesgo de breaking change no verificado con frontend real: retiro de `aula` de
   `GET /api/v1/docente/horarios`.
7. Margen de cobertura `BRANCH` ajustado (70,51 % sobre gate ≥70 %, ~0,51 puntos) — riesgo operativo a
   vigilar en cambios futuros, no un fallo actual.

## Cambios fuera de alcance

Ninguno introducido por esta fase de cierre: no se tocó `src/main/**`, `src/test/**`, `pom.xml`, DB ni
el repo frontend. Solo se escribieron `CLOSURE.md` (este documento), `docs/baseline/TECHNICAL_DEBT.md`
y `docs/baseline/LINEA_BASE.md`, conforme al alcance autorizado para esta fase. Los demás documentos del
work item (`PLAN.md`, `CONTRACT_MATRIX.md`, `CONTRACT_FREEZE.md`, `TEST_PLAN.md`, `RED_SNAPSHOT.md`,
`VALIDATION.md`, `AUDIT.md`) no fueron modificados por esta fase.

---

## INFORME FINAL (`TASK_AUTORIZADA.md` §37) — LB-001B.3 BACKEND ALIGNMENT REPORT

```
LB-001B.3 BACKEND ALIGNMENT REPORT

DB CONTRACT SHA:
VERIFIED (PRECHECK_SNAPSHOT.md §1; SHA-256
1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103, coincide .md/.sha256)

DB → BACKEND CONTRACT MATRIX:
MATCH count: 14 (M-04,07,09,10,11,13,14,15,16,17,18,21,23,24)
MISMATCH count: 4 (M-01,02,05,20) — los 4 fueron TARGET de CONTRACT_FREEZE.md;
  M-01/M-02/M-05 pasaron a MATCH tras implementación (confirmado GREEN e independiente);
  M-20 quedó PARCIAL (2/3 llamadores resueltos, ver UTC SESSION PERSISTENCE abajo)
BLOCKED count: 2 (M-03, M-08, ambos BLOCKED_BY_MISSING_EVIDENCE)
Adicional (no contemplado en las 3 categorías anteriores del criterio de salida):
  CONTRACT_CONFLICT: 1 (M-19); NOT_APPLICABLE/OUT_OF_TARGET: 2 (M-06, M-12);
  MISSING_IN_BACKEND: 1 (M-22)

SESSION CREATE:
MATCH — GREEN, confirmado independientemente por 05-auditor (idDocente retirado de
usp_crear_sesion, sin ghost param, AUDIT.md §2.2/§5)

SESSION UPDATE:
MATCH — GREEN, confirmado independientemente (idDocente retirado de usp_actualizar_sesion)

SESSION READ:
MATCH — GREEN, sin cambios necesarios (ya MATCH en CONTRACT_MATRIX.md M-04 antes de esta fase)

SESSION GHOST FIELDS:
0 (dentro del alcance de crear/actualizar Sesion, confirmado por 05-auditor, AUDIT.md §5)

SESSION idDocente PARAM:
1 remanente — en usp_cerrar_sesion (SQL_CERRAR_SESION), retenido por decisión explícita
(CONTRACT_FREEZE.md §3, SP legacy OUT_OF_TARGET/BLOCKED_BY_MISSING_EVIDENCE de firma, M-03),
NO es un ghost param sin clasificar

ATTENDANCE STATES:
AN/SJC/EX — GUARANTEED, fail-closed confirmado (M-14 MATCH); alias legado A/F/J/T — 0
coincidencias como equivalentes de negocio (AUDIT.md §2.4)

MISSING ATTENDANCE SYNTHESIS:
0 — ausencia de fila no produce AN (M-13 MATCH, confirmado)

SEC_001:
NOT MAPPED — CONTRACT_CONFLICT (M-19). Sin señal de clasificación en DbFailureClassifier;
cae en ERR_DB_UNCLASSIFIED → HTTP 500 hoy

SEC_002:
NOT MAPPED — mismo CONTRACT_CONFLICT, mismo resultado (500 hoy)

ATT_*:
NOT MAPPED — ATT_001/ATT_002/ATT_003 sin ninguna rama de clasificación, caen en
ERR_DB_UNCLASSIFIED → 500

SES_*:
SES_001 funciona hoy (404 vía SesionErrorCode.ERR_SESION_NO_EXISTE) pero SOLO por coincidencia
de texto libre, sin garantía contractual (NOT MAPPED formalmente); SES_003/SES_004 sin
clasificación, caen en 500 (NOT MAPPED)

UTC SESSION PERSISTENCE:
PARCIAL — 2 de 3 llamadores confirmados (SesionRepositorySqlServerAdapter,
ReporteAsistenciaSqlServerAdapter) decodifican fechaHoraInicio/fechaHoraFin con semántica UTC
fija (toLocalDateTimeUtc), verificado con test real. El tercero (SesionMateriaEstudianteSqlServerAdapter,
fuera del Golden Path §7 pero dentro del alcance textual de TASK_AUTORIZADA.md §20) permanece
dependiente de TimeZone.getDefault() por TEST_CONTRACT_CONFLICT sin resolver
(VALIDATION.md §7.2). No se declara PASS íntegro.

REALTIME UTC:
PARCIAL — tipo Instant correcto (MATCH, M-21); test de serialización ISO-8601 con Z NO
creado (MISSING_IN_BACKEND, M-22, punto O de §27 no alcanzado)

SYSTEM DEFAULT TIMEZONE USAGE IN GOLDEN PATH:
0 dentro del Golden Path (TASK_AUTORIZADA.md §7); 1 fuera del Golden Path pero dentro del
alcance textual de §20 (SesionMateriaEstudianteSqlServerAdapter) — reportado explícitamente
como matiz, no oculto (AUDIT.md §2.5, §3)

CORRELATION:
PASS — CorrelationIdContext.require() propagado a los 7 SP de escritura de Sesion/Asistencia
(M-16/M-17 MATCH, confirmado independientemente)

INTEGRATION TESTS:
NOT EXECUTED — VALIDATION_BLOCKED_BY_ENVIRONMENT. Sin evidencia de instancia SQL Server CLEAN
disponible conforme a TASK_AUTORIZADA.md §30; SqlStoredProcedureContractIT/
AsistenciaRepositorySqlServerIT no se corrieron en ninguna fase de este work item

MAVEN VERIFY:
tests: 936
failures: 0
errors: 0
skipped: 0
(BUILD SUCCESS, reproducido de forma independiente por 05-auditor, AUDIT.md §1)

JACOCO:
lines: 85.62% (gate >= 80%: CUMPLE)
branches: 70.51% (gate >= 70%: CUMPLE, margen ajustado ~0.51 puntos porcentuales)

ARCHUNIT:
PASS — 16 clases bajo co.edu.uco.asistenciasuco.architecture.*, 0 failures, 0 errors,
confirmado independientemente

SERVERLESS READINESS FINDINGS:
ReactorRealtimeAdapter confirmado NOT_DISTRIBUTED/SERVERLESS_SCALE_OUT_BLOCKER (Sinks en
memoria de instancia, sin durabilidad/replay, ya auto-documentado en Javadoc propio, M-24
MATCH-como-hallazgo-esperado). Registrado formalmente como refuerzo de TD-003 (mismo
componente ya en el ledger), sin refactor. Sin otros hallazgos nuevos de scale-out en el
alcance revisado.

BACKEND_GOLDEN_PATH_CONTRACT:
path: N/A — NO CREADO. El work item no alcanzó la fase TASK_AUTORIZADA.md §33 (bloqueada por
el Bloqueo 1 de mapeo de errores, que ese documento debe reflejar como parte del "Error
envelope"/"Error semantic codes HTTP")
SHA-256: N/A

REMAINING BACKEND BLOCKERS:
1. Bloqueo 1 (CONTRACT_CONFLICT, M-19): mapeo determinista de errores DB SEC_001/SEC_002/
   ATT_001-003/SES_003/SES_004/GEN_002, sin resolver, decisión explícita del usuario
2. TEST_CONTRACT_CONFLICT sin resolver: SesionMateriaEstudianteSqlServerAdapterTest (fixture
   de zona horaria), pendiente de 02-contratos/03-tester-red
3. M-03 (usp_cerrar_sesion) y M-08 (uv_estudiante_identidad/uv_usuario, dentro del Golden
   Path): BLOCKED_BY_MISSING_EVIDENCE, requieren evidencia DB adicional
4. M-22: test de serialización realtime UTC (ISO-8601 con Z) no creado
5. Integration tests (-Pintegration) no ejecutados en ningún momento de este work item
6. Riesgo no verificado: retiro de `aula` de GET /api/v1/docente/horarios frente al consumidor
   frontend real (repo no abierto en este work item)
7. Margen BRANCH JaCoCo ajustado (~0.51 puntos) — riesgo operativo, no un fallo actual

DB MODIFIED:
NO

FRONTEND MODIFIED:
NO

OPENAPI STARTED:
NO

JPA STARTED:
NO

REDIS STARTED:
NO

SERVERLESS INFRA STARTED:
NO

READY FOR FRONTEND VERIFICATION:
PARTIAL. YES para los flujos "happy path" del Golden Path ya verificados en GREEN y auditados
de forma independiente: crear/actualizar Sesion (firma sin idDocente, invisible para el
frontend porque ese campo nunca viajó por HTTP), consulta de horario docente (10 campos, SIN
aula — CAMBIO DE CONTRATO HTTP real, requiere coordinación de despliegue con el frontend antes
de verificar, no confirmado contra el consumidor real), batch de asistencia con datos válidos,
lectura de asistencias, realtime (tipo correcto). NO para el alcance íntegro del Golden Path:
cualquier flujo frontend que ejercite las rutas de error RBAC/titularidad (SEC_001/SEC_002) o
de validación de lote inválido (ATT_001-003) o de sesión cerrada (SES_003/SES_004) recibirá HOY
un HTTP 500 genérico en vez del 403/400/409 esperado por el contrato — esto es un defecto
funcional real para cualquier prueba frontend que cubra esas rutas, no una limitación
documental. Recomendación: verificación frontend limitada a los flujos exitosos del Golden Path
ya alineados, con aviso explícito de que las rutas de error siguen sin contrato garantizado.

READY FOR LB-001C OPENAPI:
NO. El criterio de salida de TASK_AUTORIZADA.md §35 exige explícitamente SEC_001: MAPPED,
SEC_002: MAPPED, ATT_*: MAPPED, SES_*: MAPPED — ninguno se cumple (Bloqueo 1, CONTRACT_CONFLICT
sin resolver). TD-030/DR-009 (VAL_003) y DR-006 (dominio de estado en lectura) tampoco se
cierran en este work item (ver sección "Deuda" de CLOSURE.md). LINEA_BASE.md mantiene
LB-001C = NOT STARTED.

STOP.
No se inicia frontend.
No se inicia OpenAPI automáticamente.
```

## Condición de parada

**No se inicia LB-001C ni ninguna verificación frontend automática por la sola existencia de este
cierre.** El Bloqueo 1 (mapeo de errores DB), el `TEST_CONTRACT_CONFLICT` de
`SesionMateriaEstudianteSqlServerAdapterTest`, y los bloqueos puntuales `BLOCKED_BY_MISSING_EVIDENCE`
(M-03, M-08) siguen abiertos y requieren decisión humana y/o evidencia DB adicional antes de que una
fase futura pueda continuar el mapeo de errores o declarar el work item `DONE` íntegro. Este `CLOSURE.md`
documenta un cierre de fase parcial y honesto, no un cierre ficticio del work item completo.
