---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# Hallazgos y evidencia pendiente — LB-000

## Conflictos abiertos

| ID | Estado | Fuentes | Alcance bloqueado / resolución requerida |
|---|---|---|---|
| CF-001 | CONTRACT_CONFLICT | [Guía command/query](../../architecture/http-command-query-guidelines.md) prescribe POST para commands; [matriz](../../contracts/HTTP_AS_IS_MATRIX.md) y SecurityConfig contienen PUT/PATCH/DELETE | Equipo de contratos debe decidir alcance de la regla antes de normalizar métodos/nuevos contratos. No se cambió ningún endpoint; TD-028 |
| CF-002 | CONTRACT_CONFLICT / gate FAIL preexistente | [ControllersMustDependOnlyOnInputPortsTest](../../../src/test/java/co/edu/uco/asistenciasuco/architecture/ControllersMustDependOnlyOnInputPortsTest.java) y [GlobalExceptionHandler](../../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/error/GlobalExceptionHandler.java): dependencia de MessageCatalogPort | Auditoría arquitectónica y corrección en tarea separada autorizada. No relajar test para hacerlo pasar. Bloquea DoD integral de LB-000; TD-029 |

## BLOCKED_BY_MISSING_EVIDENCE

| ID | Evidencia faltante y búsqueda | Afirmación/trabajo bloqueado | Responsable por rol |
|---|---|---|---|
| ME-001 | No hay schema/DDL/SP liberados en archivos versionados; se inspeccionaron adapters y ocho IT SQL/audit | Confirmar firmas, constraints/tipos/estados/tiempo y versión DB del Golden Path, no su existencia en Java | Equipo DB + backend |
| ME-002 | Sin frontend/package.json/consumidor Angular en este repo; la comparación anterior es histórica | Compatibilidad del cliente, uso de SSE/reconexión y E2E de UI | Equipo frontend |
| ME-003 | Sin evidencia remota de Rulesets, configuración Sonar o corrida GitHub en esta tarea | Afirmar protección/umbrales Sonar o CI remoto PASS | Mantenedor CI |
| ME-004 | Config y adapters Azure/OTel/Keycloak existen; no se aportó corrida de ambiente vinculada a las afirmaciones E2E antiguas | Certificar IdP, vault/catálogos y observabilidad operacional | Identidad/operaciones |
| ME-005 | LocalDateTime de sesiones, Instant de eventos; no contrato temporal DB/frontend aprobado | Declarar UTC end-to-end o convertir campos existentes | Dueños de contrato DB/API/frontend |

Estos bloqueos no impidieron reorganizar documentación. Deben resolverse antes de implementar los alcances dependientes en fases posteriores.

## Discrepancias documentales corregidas con evidencia

| Hallazgo anterior | Tratamiento / evidencia |
|---|---|
| Bean Validation en guía frente a validadores propios | Guía de validación corregida según RequestValidationGuard, validators y [input-validation](../../architecture/input-validation.md); no se introdujo Jakarta |
| CorrelationIdContext en infrastructure/correlation y getOrCreate | Ruta actual infrastructure/observability/correlation y método require; evidentes en la clase/IT |
| CORS solo GET/POST/OPTIONS | SecurityConfig permite también PUT/PATCH/DELETE; corregido AS-IS, manteniendo CF-001 |
| SSE `/events` o stream sin grupo/titularidad | Controller/gateway usan `/stream?grupoId`, scope por grupo; RBAC HTTP y gate contextual se distinguen |
| Evento individual presentado como flujo operativo | Adapter SQL individual lanza FeatureUnavailableException; Golden Path usa lote y ASISTENCIAS_SESION_ACTUALIZADAS |
| SP interno en inventario de Usuario / SPs internos Docente | Usuario consume usp_sincronizar_usuario público; Docente queries reales y commands no disponibles según adapter |
| Mover mocks desde main todavía pendiente | Test doubles ya están en src/test; se eliminó la tarea obsoleta |
| Runtime Security todavía acoplado a antiguo converter | JwtClaimsExtractor/KeycloakJwtClaimsExtractor y SecurityConfig actuales; external-services corregido |
| GrupoBeansConfig y referencia a sección 19 inexistente | GrupoWiringConfiguration y enlaces a runtime-security/infra Keycloak |
| Keycloak User Profile view/edit solo admin | Bootstrap y realm documentan view user/admin, edit admin; runbook alineado |
| Sesiones por grupo sin Layer 2 | UseCase ya llama canDocenteAccessGrupo; se conserva pendiente de validación runtime |
| Logs siempre stdout | Config actual escribe JSONL y Alloy lee archivos; cloud stdout/OTLP queda como objetivo |
| RabbitMQ obligatorio / Redis como paso automático | Menciones históricas conservadas como propuestas; solicitud LB-000 exige neutralidad y ADR de tecnología futura |
| E2E Azure verificado / Sonar 80 % como gate local | Implementación existente separada de evidencia operacional; umbral Sonar remoto no comprobado; Maven sí fija 80/70 |
| Asistencia/revisión frontend descritas con formas antiguas | Guía nueva enlaza requests actuales; comparación histórica archivada sin inferir cliente externo |
| .workspace como salida oficial / fases JPA mezcladas | Solicitud actual fija work-items versionables y fases LB-001 contrato / LB-002 piloto; prompts viejos superseded |

## SECURITY_FINDINGS

No se confirmó un secreto real versionado durante la inspección limitada de archivos actuales. `.env` no está en el índice y no se imprimió. Placeholders/config de test no se presentan como credenciales reales. No se auditó historial Git ni se hicieron rotaciones. Hallazgos de política/validación existentes (credenciales, ownership, Actuator) permanecen en TD-004/013/014/020/022; no se confunden con secretos filtrados.

## Build previo

Primer intento restringido: `VALIDATION_BLOCKED_BY_ENVIRONMENT`, Maven Central devuelve `Permission denied: getsockopt` al resolver el POM padre Spring Boot 4.0.6. Reintento autorizado: compila, ejecuta 920 tests, 1 failure ArchUnit, 0 errors, 0 skipped. El fallo es real/preexistente, no ambiental. Detalle y comparación final en [VALIDATION](VALIDATION.md).
