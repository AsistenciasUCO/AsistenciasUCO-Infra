---
status: active
type: authorized-task
scope: backend
owner: backend-team
last-reviewed: 2026-09-23
---

# Tarea autorizada — LB-001B.3 (texto verbatim del usuario, 2026-09-23)

Fuente: mensaje del usuario en la sesión que abrió este work item. Copiado verbatim para que todos los agentes de la pipeline (01-planificador → 06-cierre) trabajen sobre el mismo texto autorizado, sin depender de resúmenes de terceros. No editar este archivo salvo para corregir un error de transcripción confirmado contra el mensaje original.

---

Lee PRIMERO el AGENTS.md raíz.

TAREA AUTORIZADA:

LB-001B.3 — BACKEND ALIGNMENT AGAINST FROZEN DB BASELINE

Trabaja EXCLUSIVAMENTE en:

AsistenciasUCO

NO abrir:
puedes leer la documentación de la db, esta es la ruta de acceso:"C:\Users\josev\OneDrive\Documentos\AsisteciaUco_db\git\gestion-asistencia-db"
AsistenciasUCO-Frontend

NO buscar otros repositorios.

La DB ya fue congelada y es SOURCE OF TRUTH.

Su único input permitido es:

docs/contracts/external/db/DB_BASELINE_CONTRACT.md
docs/contracts/external/db/DB_BASELINE_CONTRACT.sha256

==================================================
0. USAR LA GOBERNANZA Y LOS AGENTES
==================================================

NO ejecutar esta tarea como un refactor improvisado.

Seguir obligatoriamente:

PLAN
→ CONTRACT
→ TEST RED
→ IMPLEMENT
→ VALIDATE
→ AUDIT
→ CLOSE

Usar los roles existentes del backend:

01-planificador
02-contratos
03-tester-red
04-implementador
05-auditor
06-cierre

Leer únicamente las skills que AGENTS.md indique como necesarias,
especialmente las relacionadas con:

arquitectura
contratos
persistencia
seguridad
testing
catálogos
observabilidad
realtime

No leer documentación irrelevante de forma masiva.

==================================================
1. PRECHECK DEL CONTRATO DB
==================================================

Antes de tocar código:

calcular SHA-256 de:

docs/contracts/external/db/DB_BASELINE_CONTRACT.md

compararlo con:

DB_BASELINE_CONTRACT.sha256

Si NO coincide:

BLOCKED_BY_MISSING_EVIDENCE
STOP.

No continuar con un contrato DB alterado.

==================================================
2. SNAPSHOT BACKEND
==================================================

Registrar:

branch
HEAD
git status
Java
Maven
Spring Boot

No revertir trabajo existente.

No trabajar sobre:

target/**
.workspace/**
.claude/worktrees/**
copias del proyecto
ZIPs extraídos antiguos

Registrar archivos relevantes del Golden Path con SHA-256 si el repo
está dirty.

==================================================
3. WORK ITEM
==================================================

Crear:

docs/work-items/LB-001B.3-backend-db-alignment/

PLAN.md
CONTRACT_MATRIX.md
TEST_PLAN.md
RED_SNAPSHOT.md
VALIDATION.md
AUDIT.md
CLOSURE.md

Mantenerlos concretos.

==================================================
4. OBJETIVO
==================================================

Alinear el BACKEND al contrato DB congelado sin modificar la DB.

Flujo objetivo:

Frozen DB Contract
        ↓
Persistence adapters
        ↓
Domain / Application
        ↓
HTTP adapters
        ↓
Golden Path backend estable

Al terminar:

DB ↔ Backend = MATCH

y backend debe quedar listo para una verificación frontend posterior y
después para:

LB-001C — OpenAPI Contract First.

==================================================
5. RESTRICCIONES
==================================================

NO:

modificar DB
modificar frontend
crear OpenAPI todavía
crear JPA entities
iniciar migración JDBC → JPA
implementar Redis
implementar infraestructura serverless
cambiar framework MVC → WebFlux
crear endpoints nuevos sin necesidad contractual
hacer refactor masivo
relajar ArchUnit
relajar cobertura
cambiar contratos DB congelados

Mantener:

Java 25
Spring Boot 4
Clean Architecture
Ports & Adapters
Composition Root
provider neutrality

==================================================
6. MATRIZ DB → BACKEND
==================================================

El agente 02-contratos debe construir una matriz exacta usando
EXCLUSIVAMENTE:

DB_BASELINE_CONTRACT.md
+
código backend actual.

Para cada elemento registrar:

DB target
backend AS-IS
status
acción

Estados permitidos:

MATCH
MISMATCH
MISSING_IN_BACKEND
NOT_APPLICABLE
BLOCKED_BY_MISSING_EVIDENCE

No inventar información ausente del contrato DB.

==================================================
7. GOLDEN PATH
==================================================

El alcance principal continúa siendo:

Registrar asistencias de una sesión en lote
+
consultar asistencias
+
actualización realtime.

Endpoints backend relevantes:

GET /api/v1/docente/horarios

GET /api/v1/sesiones/grupo/{grupoId}

GET /api/v1/grupos/{grupoId}/estudiantes

GET /api/v1/grupos/{grupoId}/asistencias?sesionId=...

POST /api/v1/asistencias/lote

GET /api/v1/realtime/stream?grupoId=...

Incluir además create/update Sesion solamente porque sus SP públicos
cambiaron y deben quedar alineados antes del freeze.

==================================================
8. SESION — FIRMA DB CONGELADA
==================================================

Alinear adaptadores JDBC con las firmas EXACTAS del contrato DB.

Eliminar cualquier uso backend de parámetros DB obsoletos de Sesion:

idDocente
aula
descripcion
tipo
status

No enviar parámetros que la DB ya no acepta.

No mantenerlos como compatibility shim.

No ocultarlos con null.

==================================================
9. CREAR SESION
==================================================

El backend debe ejecutar la firma DB congelada.

El contrato de aplicación/HTTP debe representar solamente datos reales
necesarios.

No reintroducir:

aula
descripcion
tipo
status
idDocente como identidad secundaria del caller.

La identidad para autorización proviene del usuario autenticado y termina
como:

idUsuarioEjecutor.

Mantener correlation id.

==================================================
10. ACTUALIZAR SESION
==================================================

Alinear actualización a:

sesion
nombre
fechaHoraInicio
fechaHoraFin
idCorrelacion
idUsuarioEjecutor

según el contrato congelado exacto.

No enviar campos ghost.

No enviar idDocente.

Si el backend actualmente implementa PATCH semántico pero el SP congelado
requiere valores completos:

alinear el application contract de forma coherente.

No usar null para decir "conservar valor" si DB ya no lo soporta.

==================================================
11. CIERRE DE SESION
==================================================

La DB congelada declara el cierre explícito como:

NOT_SUPPORTED / legacy

porque Sesion no tiene estado persistido.

Buscar si backend expone actualmente un caso de uso público para
"cerrar sesión".

Si NO tiene consumidores dentro del Golden Path:
no incluirlo en el target contractual de LB-001C.

No inventar un status.

No simular SUCCESS.

Si existe código legacy:
clasificarlo y documentarlo como OUT_OF_TARGET / LEGACY_NOT_SUPPORTED.

No hacer una eliminación amplia si pudiera afectar funcionalidad fuera
de alcance sin evidencia.

==================================================
12. READ PROJECTIONS
==================================================

Alinear los mappers JDBC exactamente con las proyecciones documentadas en
DB_BASELINE_CONTRACT.

No consultar ni esperar columnas no documentadas.

Especialmente Sesion:

NO:

aula
descripcion
tipo
status

y horarios:

NO aula si el contrato DB congelado no la expone.

No usar:

getString("aula")

ni fallbacks artificiales.

==================================================
13. ASISTENCIA — DOMINIO CANONICO
==================================================

Contrato DB Golden Path:

AN
SJC
EX

Backend público debe aceptar y producir únicamente esos estados en el
Golden Path.

Eliminar aliases legacy:

A
F
J
T

si todavía aparecen como equivalentes de negocio en esta vertical.

No:

A → AN
F → SJC

en la frontera backend.

Unknown:

fail closed.

Nunca:

unknown → AN.

==================================================
14. AUSENCIA DE REGISTRO
==================================================

Preservar la decisión ya aprobada:

fila inexistente
!= AN

La consulta devuelve solamente asistencias persistidas.

Backend NO debe fabricar:

AN
SJC
EX

para estudiantes sin DetalleAsistencia.

Frontend posteriormente representará esto como:

Sin registrar.

No añadir SIN_REGISTRAR al enum persistido/API de estado.

==================================================
15. BATCH
==================================================

Alinear request del backend al contrato congelado.

Golden Path:

sesionId
registros[]

registro:
estudianteId
estado

estado:
AN | SJC | EX.

Batch parcial permitido.

No exigir roster completo.

No completar estudiantes omitidos.

DB se encarga de invariantes definitivas:

JSON
duplicados
matrícula activa
RBAC
titularidad
atomicidad
idempotencia
concurrencia.

Backend puede validar estructura tempranamente, pero NO debe definir una
semántica distinta.

==================================================
16. EJECUTOR
==================================================

DB congelada exige ejecutor semánticamente obligatorio.

Todo command protegido debe pasar:

Usuario autenticado
→ idUsuarioEjecutor

No:

NULL
UUID inventado
Docente.id

como sustituto.

Verificar que la extracción desde el contexto de seguridad sea
provider-neutral.

Keycloak pertenece al adapter, no a Application/Domain.

==================================================
17. RBAC / OWNERSHIP
==================================================

DB congelada diferencia:

SEC_001
RBAC/perfil insuficiente

SEC_002
titularidad insuficiente

El backend debe traducir los resultados observables de esos casos de forma
determinista a su contrato semántico:

SecurityErrorCode.FORBIDDEN
o equivalente vigente aprobado.

HTTP esperado:

403

ApiErrorResponse.code:
FORBIDDEN

No devolver 400.

No devolver 500.

No filtrar códigos DB internos al frontend salvo que el contrato backend
actual explícitamente lo requiera.

==================================================
18. IMPORTANTE — RESULTSET DB
==================================================

El result set DB público sigue siendo exactamente:

idCorrelacion
mensajeUsuarioResultado
mensajeTecnicoResultado
estadoResultado

NO existe obligación de un quinto campo "codigo".

Por tanto:

NO modificar el contrato DB asumido.

Auditar cómo:

DbFailureClassifier
adaptadores JDBC
mapeadores de errores

distinguen SEC_001 / SEC_002 / ATT_* / SES_*.

Si con el contrato congelado NO existe señal determinista suficiente para
mapear un error:

CONTRACT_CONFLICT
STOP

No clasificar por una frase humana frágil sin test contractual.

Si el mensaje técnico/catalogado es la señal contractual vigente:
congelarlo mediante tests precisos.

==================================================
19. CÓDIGOS NUEVOS DB
==================================================

Revisar los códigos relevantes documentados en el contrato congelado,
incluyendo cuando correspondan:

SEC_001
SEC_002

ATT_001
ATT_002
ATT_003

SES_001
SES_003

RC_001

y otros del Golden Path.

No asumir esta lista como completa si DB_BASELINE_CONTRACT contiene otra.

Clasificar cada uno en backend como:

VALIDATION
NOT_FOUND
FORBIDDEN
CONFLICT
INTERNAL_INTEGRITY

según semántica real.

Documentar la tabla:

DB semantic
→ backend ErrorDefinition
→ HTTP status
→ ApiErrorResponse.code

==================================================
20. UTC — MUY IMPORTANTE
==================================================

La DB congelada ahora establece:

Horario TIME:
hora académica local.

Sesion.fechaHoraInicio / fechaHoraFin:
DATETIME2 con semántica UTC.

AuditoriaEvento.occurredAt:
UTC explícito.

El backend NO puede aplicar:

ZoneId.systemDefault()

para interpretar Sesion.

No puede asumir America/Bogota al leer Sesion.

La persistencia debe interpretar los DATETIME2 de Sesion como UTC.

==================================================
21. REPRESENTACION TEMPORAL BACKEND
==================================================

Auditar tipos actuales:

LocalDateTime
Instant
OffsetDateTime

No hacer migración indiscriminada de toda la aplicación.

Para la frontera JDBC de Sesion:

si JDBC retorna LocalDateTime proveniente de DATETIME2 UTC,
tratarlo explícitamente como UTC.

Cuando sea necesario convertir a instante:

localDateTime.toInstant(ZoneOffset.UTC)

Nunca:

systemDefault.

Para escritura:

si la capa superior usa Instant:
convertir a LocalDateTime UTC antes del SP.

Si actualmente la capa Application usa LocalDateTime:
documentar explícitamente que ese valor representa UTC y evitar cualquier
conversión implícita.

El agente de contratos debe elegir el cambio mínimo que garantice
semántica UTC sin romper arquitectura.

==================================================
22. HTTP TEMPORAL
==================================================

NO congelar todavía OpenAPI.

Pero crear tests de serialización reales del comportamiento backend target.

Objetivo técnico:

no perder que Sesion representa UTC.

Si el HTTP actual ya usa Instant / OffsetDateTime:
preservar ISO-8601 UTC.

Si sigue usando LocalDateTime:
documentar el AS-IS exacto como input para LB-001C.

NO cambiar arbitrariamente el wire format en esta fase sin necesidad.

Cualquier decisión pendiente de representación HTTP debe quedar marcada:

READY_FOR_OPENAPI_DECISION

y no como ambigüedad accidental.

==================================================
23. REALTIME TIME
==================================================

RealtimeEvent.occurredAt:

Instant
UTC.

Agregar o confirmar test de serialización:

ISO-8601 UTC
con Z.

No mezclar:

Sesion DATETIME2 UTC
con
Horario TIME local.

==================================================
24. CORRELATION / TRACEABILITY
==================================================

Preservar:

X-Correlation-Id
traceId
spanId
audit metadata.

Todo command JDBC debe propagar correlationId al SP cuando corresponda.

No generar uno nuevo en una capa secundaria si ya llegó uno válido.

Confirmar tests.

==================================================
25. CATALOGO Y CACHE FUTURA
==================================================

NO implementar Redis.

La DB congelada ya dejó contratos de catálogo preparados.

Verificar únicamente que el backend mantenga provider neutrality mediante
ports existentes:

MessageCatalogPort
Parameter/catalog ports si aplican.

No acoplar Application a:

SQL Server
Redis
Azure App Configuration
Keycloak.

Si existe adapter actual distinto a DB:
NO reemplazarlo en esta fase salvo que el Golden Path lo requiera.

Registrar el contrato de caché como FUTURE_PROVIDER_WORK.

==================================================
26. SERVERLESS READINESS — SOLO AUDITORIA
==================================================

NO implementar infraestructura serverless ahora.

Pero auditar el Golden Path backend por dependencias incompatibles con
scale-out:

estado mutable local como source of truth
filesystem local obligatorio
session affinity
locks JVM usados como consistencia distribuida
IDs de instancia
caches locales consideradas autoridad

No refactorizar todo.

Registrar hallazgos en deuda técnica.

SSE/realtime en memoria puede seguir funcionando para una instancia,
pero si existe un provider in-memory debe documentarse:

NOT_DISTRIBUTED
SERVERLESS_SCALE_OUT_BLOCKER

para una fase posterior.

HTTP/DB deben permanecer stateless.

==================================================
27. TEST-FIRST
==================================================

03-tester-red crea tests ANTES de producción.

Como mínimo cubrir:

A.
firma crear sesión sin idDocente/ghost params.

B.
firma actualizar sesión sin idDocente/ghost params.

C.
mapper de uv_sesion exacto.

D.
mapper horario sin aula.

E.
batch solo AN/SJC/EX.

F.
unknown attendance state fail-closed.

G.
ausencia de fila no produce AN.

H.
idUsuarioEjecutor obligatorio hacia DB.

I.
SEC_001 → 403/FORBIDDEN.

J.
SEC_002 → 403/FORBIDDEN.

K.
SES_001 → not found apropiado.

L.
SES_003 no produce fake success.

M.
ATT errors clasificación correcta.

N.
Sesion temporal nunca usa systemDefault.

O.
Realtime occurredAt serializa UTC.

P.
correlation propagada al SP.

Congelar RED_SNAPSHOT con SHA-256.

No cambiar los RED para obtener GREEN.

==================================================
28. PERSISTENCE ADAPTERS
==================================================

Modificar solo los adapters necesarios.

Mantener RepositoryPorts.

No introducir:

JdbcTemplate
SimpleJdbcCall
ResultSet
SQL Server

en Application/Domain si hoy están correctamente aislados.

Preservar Composition Root.

No usar @Transactional en Application como solución rápida.

==================================================
29. NO JPA
==================================================

Aunque se detecten mejoras posibles:

NO crear:

@Entity
JpaRepository
Hibernate mappings

LB-002 sigue posterior a LB-001C.

JDBC queda como provider actual válido.

==================================================
30. INTEGRATION TESTS
==================================================

Usar una instancia CLEAN de la DB congelada.

NO usar:

sql_server_asistencias

si continúa marcada como:

DEV_INSTANCE_REBUILD_REQUIRED.

Preferir la instancia limpia construida desde el baseline DB congelado.

No abrir el repo DB.

Ejecutar las IT existentes relevantes, especialmente:

SqlStoredProcedureContractIT
AsistenciaRepositorySqlServerIT

y cualquier IT de Sesion afectada.

Si las IT necesitan configuración externa:
usar env/config existente, no secretos hardcodeados.

==================================================
31. QUALITY GATE
==================================================

JDK 25.

Ejecutar:

mvn -B -ntp verify

Obligatorio:

BUILD SUCCESS
0 failures
0 errors
ArchUnit PASS
JaCoCo gates PASS

Gates históricos:

LINE >= 80 %
BRANCH >= 70 %

No relajar.

Registrar números reales finales.

==================================================
32. AUDITOR INDEPENDIENTE
==================================================

05-auditor debe revisar DESPUÉS de GREEN.

Buscar globalmente dentro del BACKEND VIGENTE:

aula
descripcion
tipo
status
idDocente
PROGRAMADA
EN_CURSO
CONCLUIDA
"A"
"F"
"J"
"T"
ZoneId.systemDefault
VAL_003

Pero clasificar cada match.

NO eliminar coincidencias legítimas de otros dominios.

Resultado requerido en Golden Path:

SESSION GHOST CONTRACT = 0
LEGACY ATTENDANCE STATE = 0
SYSTEM DEFAULT TIMEZONE DEPENDENCY = 0
SESSION idDocente SP PARAM = 0

==================================================
33. CONTRATO COMPACTO PARA LA SIGUIENTE FASE
==================================================

Crear:

docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md

Este será el input para frontend/OpenAPI sin tener que reanalizar todo el
backend.

Mantenerlo compacto.

Debe incluir:

A. Endpoints Golden Path.

B. Roles por endpoint.

C. Request exacto de batch.

D. Response DTOs exactos.

E. Sesion read/create/update target.

F. Attendance enum AN/SJC/EX.

G. Ausencia de asistencia = sin fila.

H. Error envelope.

I. Error semantic codes HTTP.

J. Temporal semantics.

K. Correlation header.

L. Realtime endpoint.

M. Realtime envelope/payload.

N. HTTP source of truth; SSE como invalidation/update signal.

O. Pending serverless distributed realtime note.

NO crear OpenAPI todavía.

Calcular SHA-256 del documento.

==================================================
34. DOCUMENTACION
==================================================

Actualizar:

docs/baseline/LINEA_BASE.md
docs/baseline/TECHNICAL_DEBT.md

Cerrar únicamente deudas realmente demostradas.

Reconciliar los antiguos:

DR-006
DR-009
TD-030
TD-005

con la nueva DB congelada.

No cerrar algo solo porque "debería estar resuelto".

Si queda una decisión HTTP para OpenAPI:
registrarla claramente como decisión pendiente de LB-001C.

==================================================
35. CRITERIO DE SALIDA
==================================================

Cerrar solo si:

DB CONTRACT SHA:
VERIFIED

SESSION DB SIGNATURES:
MATCH

SESSION READ PROJECTION:
MATCH

ATTENDANCE DB CONTRACT:
MATCH

AN/SJC/EX:
GUARANTEED

MISSING ATTENDANCE:
NO SYNTHESIS

EXECUTOR:
MATCH

SEC_001:
MAPPED

SEC_002:
MAPPED

ATT_*:
MAPPED

SES_*:
MAPPED

UTC PERSISTENCE:
MATCH

REALTIME UTC:
MATCH

CORRELATION:
MATCH

ARCHUNIT:
PASS

MAVEN VERIFY:
PASS

DB INTEGRATION TESTS:
PASS

No unresolved backend↔DB contract mismatch.

==================================================
36. ESTADO FINAL
==================================================

Si todo pasa:

DB ↔ BACKEND:
ALIGNED

LB-001B.3:
DONE

BACKEND READY FOR FRONTEND VERIFICATION:
YES

BACKEND READY FOR OPENAPI INPUT:
YES

Pero:

OPENAPI STARTED:
NO

JPA STARTED:
NO

SERVERLESS INFRA STARTED:
NO

REDIS STARTED:
NO

==================================================
37. INFORME FINAL
==================================================

Entregar:

LB-001B.3 BACKEND ALIGNMENT REPORT

DB CONTRACT SHA:
PASS/FAIL

DB → BACKEND CONTRACT MATRIX:
MATCH count
MISMATCH count
BLOCKED count

SESSION CREATE:
MATCH/FAIL

SESSION UPDATE:
MATCH/FAIL

SESSION READ:
MATCH/FAIL

SESSION GHOST FIELDS:
count

SESSION idDocente PARAM:
count

ATTENDANCE STATES:
...

MISSING ATTENDANCE SYNTHESIS:
count

SEC_001:
mapping

SEC_002:
mapping

ATT_*:
mapping summary

SES_*:
mapping summary

UTC SESSION PERSISTENCE:
PASS/FAIL

REALTIME UTC:
PASS/FAIL

SYSTEM DEFAULT TIMEZONE USAGE IN GOLDEN PATH:
count

CORRELATION:
PASS/FAIL

INTEGRATION TESTS:
results

MAVEN VERIFY:
tests
failures
errors
skipped

JACOCO:
lines
branches

ARCHUNIT:
PASS/FAIL

SERVERLESS READINESS FINDINGS:
brief

BACKEND_GOLDEN_PATH_CONTRACT:
path
SHA-256

REMAINING BACKEND BLOCKERS:
...

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
YES/NO

READY FOR LB-001C OPENAPI:
YES/NO

STOP.

No iniciar frontend.
No iniciar OpenAPI automáticamente.
