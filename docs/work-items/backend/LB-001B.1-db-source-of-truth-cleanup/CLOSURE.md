---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-22
---

# CLOSURE — LB-001B.1 (backend): DB source of truth — limpieza contractual de Sesion

Fase 06-cierre. Fecha: 2026-09-22 (America/Bogota). Branch `sergio`, HEAD `fa9aa901c73e55ae31071f4e74cfb2245189243a`
(sin commit nuevo creado por esta fase; cierre puramente documental).

## Resultado

**DONE — sub-alcance backend.** Cumple la [Definition of Done](../../baseline/DEFINITION_OF_DONE.md) única
para las áreas aplicables a esta clase de cambio (`CONTRACT_CHANGE` + `BEHAVIOR_CHANGE`):

| Área DoD | Evidencia |
|---|---|
| Alcance y contrato | [CONTRACT_FREEZE.md](CONTRACT_FREEZE.md) implementado exactamente (17 archivos de producción + hallazgo #18, fixture IT), verificado independientemente por [05-auditor](AUDIT.md) sección 2 |
| RED → GREEN | [TEST_PLAN.md](TEST_PLAN.md) (`RED_SNAPSHOT` + sección "Resolución TEST_CONTRACT_CONFLICT"); los 11 archivos de test RED quedaron GREEN, incluido `SesionControllerContractTest` (7/7) tras corrección de arnés por 03-tester-red, sin tocar aserciones ni `src/main/**` |
| Build | `.\mvnw.cmd -B -ntp verify` → BUILD SUCCESS, re-ejecutado de forma independiente por 05-auditor (933/933 tests, 0 failures/errors) |
| Arquitectura | ArchUnit `CleanArchitectureRulesTest` 20/20 + 16 clases de `architecture.*` (67/67), 0 violaciones |
| Coverage | JaCoCo "All coverage checks have been met" — LINE 86,4 % (gate ≥80 %), BRANCH 70,53 % (gate ≥70 %, margen ajustado, ver "Elementos pendientes") |
| Persistencia | Sin cambio de contrato de persistencia (los SP conservan sus parámetros opcionales `= NULL`); DB_ROOT no tocado, confirmado por HEAD idéntico y ausencia de los 4 objetos de dominio `Sesion` en los archivos modificados de DB_ROOT (AUDIT.md sección 7) |
| Seguridad | Sin cambios en 401/403/ownership; cero secretos nuevos; cero dependencias nuevas (`pom.xml` diff vacío) |
| Operación | Sin cambios en logs/metrics/traces/correlationId (fuera de las rutas tocadas) |
| CI | No se afirma resultado de CI remoto; solo `verify` local reproducido de forma independiente (dos veces: 04-implementador y 05-auditor) |
| Documentación | Este `CLOSURE.md`, traslado de DR-001/DR-004 a `RESOLVED — Opción B` en [CONTRACT_MATRIX de LB-001B](../LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md), dos entradas nuevas en [TECHNICAL_DEBT.md](../../baseline/TECHNICAL_DEBT.md) (TD-034, TD-035), [LINEA_BASE.md](../../baseline/LINEA_BASE.md) actualizado |
| Cierre | Este documento; ver "Elementos pendientes y bloqueos" para lo que sigue abierto |

**No se declara `READY_FOR_LB001C`.** DR-006, DR-009/TD-030 y TD-005 (timezone) permanecen abiertos y
bloquean explícitamente el freeze de LB-001C, tal como exigía la sección 33 de la tarea autorizada de
01-planificador. `LB-001C` sigue `NOT STARTED`.

**Declaraciones explícitas:**

- `DATABASE MODIFIED: NO` — DB_ROOT es READ ONLY en todo este work item; HEAD `cb63f6f76335209f3b8666a01fb800fb91a423c3` sin cambios de origen en esta pipeline (recuento real: 15 `M` + 1 `??`, ninguno de dominio `Sesion`; ver corrección de cifra abajo).
- `BACKEND CONTRACT ALIGNED TO DB: YES` — el contrato de creación/actualización de `Sesion` ya no acepta `descripcion/aula/tipo`, campos que la tabla/vista/SP nunca persistían (ghost parameters). El contrato de lectura (`SesionConsultadaDTO`) ya coincidía 1:1 con `uv_sesion` y no fue tocado.
- `OPENAPI STARTED: NO` — sin especificación aprobada; `contracts/openapi/README.md` sigue siendo un placeholder (TD-002 sin cambio).
- `JPA STARTED: NO` — sin dependencias JPA/Hibernate en `pom.xml`; persistencia sigue siendo JDBC puro (TD-001 sin cambio).

## Verificación de vigencia del estado auditado (06-cierre)

Antes de cerrar, se confirmó que el estado descrito por [AUDIT.md](AUDIT.md) sigue vigente: `git status --short`
del repositorio backend en esta sesión de cierre muestra el mismo `HEAD` (`fa9aa90`) y el mismo conjunto de
archivos de producción/test tocados dentro de las rutas permitidas del [PLAN.md](PLAN.md) (17 archivos de
`CONTRACT_FREEZE.md` §7 + los 11 archivos de test RED + el hallazgo #18), sin cambios nuevos que contradigan
lo reportado por el auditor. Los demás archivos sueltos del `git status` (p. ej. `GlobalExceptionHandler.java`,
`GlobalExceptionHandlerTest.java`, controllers de otros dominios, el paquete `catalogo` sin trackear) son
trabajo previo no relacionado (integración Azure Key Vault / catálogos, commit `fa9aa90`), ya presentes antes
de que este work item empezara — no se tocaron ni se revirtieron en esta fase. No se re-ejecutó `mvn verify`
en esta sesión de cierre; se confirma sobre la evidencia ya re-derivada de forma independiente por 05-auditor
(AUDIT.md, comandos propios, hashes recalculados por el auditor).

## Alcance entregado y decisiones

- Backend: retirados `descripcion`, `aula`, `tipo` de `CrearSesionRequest`/`CrearSesionDTO`/`CrearSesionRepositoryDTO`
  y `aula`, `descripcion` de `ActualizarSesionRequest`/`ActualizarSesionDTO`/`ActualizarSesionRepositoryDTO`,
  en toda la cadena (request HTTP → DTO aplicación → DTO puerto secundario → llamada SP), incluido el alias
  `setRoom(String)` en ambos requests. `SesionRepositorySqlServerAdapter` deja de enviar `@descripcion/@aula/@tipo`
  a `SQL_CREAR_SESION`/`SQL_ACTUALIZAR_SESION` (los SP los conservan como parámetros opcionales `= NULL`, sin
  cambio de firma DB). `SesionHttpMapper` y `CrearSesionRequestValidator` ajustados en consecuencia.
- **DR-001 y DR-004** del [CONTRACT_MATRIX de LB-001B](../LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md)
  trasladados formalmente a `RESOLVED — Opción B` por esta fase (06-cierre), con referencia a la decisión
  humana pegada verbatim en la sesión de 01-planificador (2026-09-22, secciones 0 y 12-16 de la tarea
  autorizada) y a este work item. Ese CONTRACT_MATRIX estaba formalmente cerrado (LB-001B ANALYSIS COMPLETE);
  06-cierre tiene la autoridad de cierre para reabrirlo, y lo hizo **únicamente** para esas dos filas (tabla
  de la sección 10 + las dos secciones de detalle `### DR-001` y `### DR-004`), documentado explícitamente en
  la nota de gobernanza insertada al inicio de esa sección — ninguna otra fila, endpoint ni hallazgo de ese
  documento fue modificado.
- `SesionConsultadaDTO.java` (lado de lectura) **sin cambios**, confirmado por `git diff` vacío tanto por
  04-implementador como por 05-auditor — ya coincidía exactamente con `uv_sesion`.
- Fixture de test de integración `AsistenciaRepositorySqlServerIT.java` ajustado mecánicamente (constructor
  9→6 parámetros en `crearSesionDePrueba()`), sin cambio de aserciones.
- Resolución de un `TEST_CONTRACT_CONFLICT` real: los dos tests de `SesionControllerContractTest` que debían
  rechazar campos retirados con 400 fallaban por un defecto de arnés de prueba (el `MockMvc` standalone del
  test no aplicaba el `JsonMapperBuilderCustomizer` real que hace estricto el `ObjectMapper`, y Jackson 3
  cambió el default de `FAIL_ON_UNKNOWN_PROPERTIES` a `false`), no por un defecto de producción. 04-implementador
  diagnosticó la causa raíz sin corregirla (fuera de sus rutas permitidas); 03-tester-red corrigió únicamente
  el setup del test (sin tocar las 7 aserciones); 05-auditor verificó de forma independiente que el hash final
  coincide con lo documentado y que los 10 archivos de test hermanos permanecen byte-idénticos al RED original.
- **Frontend:** ningún archivo del repo `AsistenciasUCO-Frontend` fue tocado desde esta sesión backend (fuera
  de la autoridad de escritura de este work item). El trabajo equivalente en frontend vive en el work item
  hermano `LB-001B.1B-db-source-of-truth-cleanup` de ese repo — ver "Elementos pendientes y bloqueos".

## Corrección de cifra (hallazgo H2 de 05-auditor)

`PLAN.md` (01-planificador) declaró "16 entradas modificadas + 1 archivo sin trackear" como snapshot inicial
de DB_ROOT. La cifra real, verificada dos veces (por 05-auditor y de nuevo en esta fase de cierre), es **15
`M` + 1 `??`** (16 entradas totales, no 17). El `HEAD` coincide exactamente con lo declarado
(`cb63f6f76335209f3b8666a01fb800fb91a423c3`) y ninguno de los archivos modificados de DB_ROOT pertenece al
dominio `Sesion` (tabla, vista o los dos stored procedures relevantes). Se registra aquí como corrección del
registro, no como evidencia de alteración de DB_ROOT por esta pipeline.

## Deuda

- **TD-034 (nueva, esta fase):** `SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` queda sin ningún
  lanzador en producción tras este cambio (ya no existe `validarDescripcion(...)` en `CrearSesionDomain`/
  `ActualizarSesionDomain`). Candidato a retiro en una tarea futura de limpieza menor. Ver
  [TECHNICAL_DEBT.md#td-034](../../baseline/TECHNICAL_DEBT.md#td-034).
- **TD-035 (nueva, esta fase):** `attendance.mapper.ts` (repo frontend) mantiene un contrato paralelo
  (`studentFromDTO()`/`StudentAttendanceDTO`/`ClassSessionDTO`) con el residuo `estado_asistencia || 'AN'`
  sin corregir — referencia cruzada a `LB-001B.1A`/`LB-001B.1B` (frontend), donde se documentó primero y se
  excluyó explícitamente de alcance. Ver [TECHNICAL_DEBT.md#td-035](../../baseline/TECHNICAL_DEBT.md#td-035).
- **TD-005 (timezone, sin cambio de estado):** `LocalDateTime` sin zona explícita en `fechaHoraInicio`/
  `fechaHoraFin` de `Sesion`; UTC end-to-end no acordado con DB. No se toca en este work item.
- **TD-006, TD-009, TD-019 (citadas como contexto, sin cambio de estado):** identificación numérica, estados
  legacy de asistencia, contratos DB ausentes de Grupo/Horario.
- **TD-030 / DR-009 (sin cambio de estado):** `VAL_003` con semántica errónea para autorización/titularidad;
  sigue bloqueando el freeze de contrato de errores en LB-001C.

## Validación manual

- MV-001 (E2E frontend + Keycloak + SQL Server + SSE, `USE_MOCKS=false`) sigue pendiente; no se ejecutó en
  ninguna fase de este work item.
- Sin otras entradas nuevas de `MANUAL_VALIDATION_LEDGER.md` generadas por este cierre.

## ADR relacionados

Ninguno. La resolución de DR-001/DR-004 es una decisión de alcance de contrato documentada en el
CONTRACT_MATRIX y en este CLOSURE, no una decisión arquitectónica duradera que requiera ADR nuevo.

## Elementos pendientes y bloqueos

- **DR-006 (dominio de `estado` en lectura) y DR-009/TD-030 (códigos de error de autorización/titularidad)
  siguen abiertos** y bloquean explícitamente el freeze de LB-001C — no se resuelven en este work item, tal
  como exigía la tarea original en su sección 33.
- **TD-005 (política temporal DB/API)** sigue abierta; no se resuelve aquí.
- **Margen de cobertura BRANCH ajustado:** JaCoCo reporta BRANCH 70,53 % contra un gate `pom.xml` de ≥70 % —
  un margen de apenas ~0,53 puntos porcentuales. Señalado por 05-auditor como **riesgo a vigilar**, no como
  fallo: cualquier cambio futuro que toque ramas no cubiertas en el mismo módulo puede hacer caer el gate.
  Se registra aquí para que 06-cierre de trabajos futuros lo tenga presente; no se abre como TD nuevo porque
  no es un defecto, es un margen operativo.
- **Frontend (`LB-001B.1B-db-source-of-truth-cleanup`, repo `AsistenciasUCO-Frontend`):** verificado en esta
  fase de cierre (lectura del repo frontend, sin escritura). Estado real al momento de este cierre:
  - `LB-001B.1A-frontend-contract-corrections` tiene `CLOSURE.md` con estado **CERRADO — DoD cumplido**
    (DR-002, DR-003 parcial, DR-005, DR-007, DR-008, TD-031, TD-032, TD-033).
  - `LB-001B.1B-db-source-of-truth-cleanup` (el equivalente frontend de este work item backend, que cubre
    DR-001/DR-004 en el lado frontend) tiene `PLAN.md`, `RED_SNAPSHOT.md`, `VALIDATION.md` y `AUDIT.md`; el
    veredicto de su propia auditoría dice "LISTO PARA 06-cierre" (177/177 tests, `npm run verify` exit 0),
    pero **no tiene `CLOSURE.md`** — su cierre formal (06-cierre en ese repo) **no ha ocurrido todavía** al
    momento de escribir este documento. No se asume ni se declara cerrado desde esta sesión backend; su
    cierre corresponde al pipeline de gobernanza propio del repo frontend.
- **H3 de AUDIT.md (menor, no bloqueante):** `TEST_PLAN.md` no documentó explícitamente el cambio
  `new GlobalExceptionHandler()` → `new GlobalExceptionHandler(codigo -> java.util.Optional.empty())` en
  `SesionControllerContractTest.java`; 05-auditor confirmó que es preexistente (trabajo ajeno a este work
  item, necesario para compilar) y no afecta ninguna aserción. Queda anotado aquí para que el registro sea
  autocontenible; no requiere acción de código.

## Cambios fuera de alcance

Ninguno introducido por esta fase de cierre: no se tocó `src/main/**`, `src/test/**`, `pom.xml`, DB_ROOT ni
el repo frontend. Los cambios de producción/test descritos en "Alcance entregado" corresponden a fases
previas (02-contratos → 05-auditor) ya verificadas y no se repiten ni se amplían aquí.

## Condición de parada

**No se inicia LB-001C automáticamente.** DR-006, DR-009/TD-030 y TD-005 siguen bloqueando su freeze. Ninguna
fase posterior (incluida LB-001B.1B en el repo frontend) queda autorizada a iniciarse por la sola existencia
de este cierre; su ejecución y cierre corresponden a su propio pipeline de gobernanza.
