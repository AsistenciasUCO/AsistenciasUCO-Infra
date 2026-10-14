# TEST_PLAN — LB-001B: pruebas FUTURAS derivadas de los hallazgos

**Alcance:** este documento **solo registra pruebas futuras**. LB-001B es `CONTRACT_ANALYSIS`: no se escribió ningún test, no hay RED/GREEN y ninguna de estas pruebas debe implementarse hasta que exista un contrato **aprobado** (LB-001C) y la [DoR](../../governance/DEFINITION_OF_READY.md) de implementación sea READY. Cada prueba depende de la decisión `DR-*` indicada; si la decisión cambia, la prueba se reescribe desde el contrato, no desde este borrador.

## Fuentes

Requisito: Golden Path ([GOLDEN_PATH_ASISTENCIA](../../baseline/GOLDEN_PATH_ASISTENCIA.md)); PLAN de [LB-001B](PLAN.md); [CONTRACT_MATRIX](CONTRACT_MATRIX.md) (DRAFT, no aprobado); [TESTING_STANDARD](../../testing/TESTING_STANDARD.md).

## Comportamiento esperado (candidatas)

Nivel: **P** = test de contrato del provider (backend); **C** = test del consumer (frontend); **X** = E2E backend+frontend con `USE_MOCKS=false`. «Bloqueada por» indica qué decisión/evidencia debe existir antes de escribirla.

| ID | Criterio / fuente | Escenario | Nivel | Precondición | Acción | Assert observable | Bloqueada por |
|---|---|---|---|---|---|---|---|
| TP-001 | C-001e / B-03 | Serialización JSON de `LocalTime` en `GET /docente/horarios` | P | Contexto MVC con `HorarioDocenteDTO` de prueba | `GET` con rol DOCENTE | `jsonPath("$.datos[0].horaInicio")` tiene el formato aprobado (`HH:mm:ss` o `HH:mm`) | B-03 |
| TP-002 | C-010c / B-03 | JSON del evento SSE | P | `RealtimeEventsController` con evento conocido | Suscribir y leer el `data` serializado | `occurredAt` es cadena ISO-8601 UTC; `payload.totalRegistros` es número; no aparecen `traceId`/`spanId` | B-03 |
| TP-003 | C-004c / DR-006 | `estado` fuera de AN/SJC/EX en lectura | P (+IT SQL Server) | Fixture con un `RazonCausa` histórico | `GET …/asistencias` | según decisión: el provider no lo devuelve/mapea, o el contrato admite `String` abierto | DR-006 |
| TP-004 | C-004c / DR-006 | El consumer ante un estado desconocido | C | `AttendanceMapper` con `estado: 'LEGACY'` | cargar lista | según decisión: no rompe la lista completa / muestra el estudiante como «desconocido» y avisa | DR-006 |
| TP-005 | C-012a / DR-002 | Estudiante sin fila de asistencia | P + C + X | Sesión sin registros previos | cargar pantalla y guardar sin marcar | según decisión: la UI distingue «sin registrar» y el batch **no** persiste `AN` no capturado (opción A) o lo hace por regla explícita (opción B) | DR-002 |
| TP-006 | C-013 / DR-001 | Estado de sesión | P + C | Sesión cerrada/cancelada | `GET` sesiones y `POST /lote` | según decisión: el DTO expone estado y la UI bloquea, o el `POST` responde el error de negocio acordado | DR-001, B-01 |
| TP-007 | C-005h / B-01 | Re-guardado del mismo lote | P (IT) / X | Sesión ya registrada | `POST /lote` dos veces con estados distintos | el segundo lote actualiza (o se rechaza) según el contrato DB; lectura posterior coherente | B-01 |
| TP-008 | C-014 / DR-003 | Mapeo fecha/hora de sesión | C | `fechaHoraInicio: '2026-09-14T08:00:00'` | `SessionService.getSessionsByGroup` | `date`, `startTime`, `endTime` cumplen el formato acordado (no el datetime completo) | DR-003 |
| TP-009 | C-002e/f/g, C-001g / DR-004 | Campos sintetizados | C | Respuesta real sin `topic`/`room`/`tipo`/`docenteName` | mapear | ningún valor fabricado por el consumer para campos que el contrato no provee | DR-004 |
| TP-010 | C-007b / DR-008 | Acceso por rol a la ruta de asistencia | C + P | usuario DECANO / ADMINISTRADOR | navegar a `/app/asistencia` y llamar E-01/E-02/E-05 | según decisión: la ruta se restringe, o el backend autoriza; en ambos casos 401/403 coherentes | DR-008 |
| TP-011 | C-007d / TD-031 / B-05 | 401 del backend con refresh válido | C | `HttpTestingController`: 1.ª respuesta 401, refresh OK | petición HTTP protegida | se reintenta con el token nuevo y no se llama `notifySessionExpired` | B-05 |
| TP-012 | C-009d | Heartbeat SSE | C | `fetchEventSource` real sobre un stream simulado con `:heartbeat\n\n` | consumir | no se emite evento de negocio; el estado no cambia | — (ya cubierto parcialmente por el spec existente; añadir la variante con el parser real) |
| TP-013 | C-009e / C-007g / B-04 | Expiración de JWT con el stream abierto | X (MV-001) | token de corta vida | mantener el stream y dejar expirar | comportamiento documentado (cierre/renovación) y recuperación por HTTP | B-04 |
| TP-014 | C-009g / TD-033 | Feedback de estado realtime y de error al cargar sesiones | C | 403 en `GET /sesiones/grupo` y estado `ERROR` del transporte | cargar pantalla | el usuario ve el error y el estado de conexión | — |
| TP-015 | C-006g / DR-009 | Códigos de autorización/titularidad | P | rol/docente ajeno | `POST /lote`, `GET /realtime/stream` | `status` 403 y `code` según el catálogo aprobado (sin `VAL_003`) | DR-009 (TD-030) |
| TP-016 | C-006e/f | `code` y `correlationId` visibles | C | error 4xx con `ApiErrorResponse` | mostrar error | el consumer expone el código de seguimiento al usuario/soporte | — |
| TP-017 | C-016 / DR-010 | Orden de listas | P | datos desordenados | `GET` E-01…E-04 | el orden coincide con el contrato congelado (incluido «sin orden garantizado» en asistencias) | DR-010 |
| TP-018 | C-015 | Evidencia sin mocks | X | `localStorage['USE_MOCKS']` ausente/`false` | ejecutar el Golden Path completo | el flujo horarios → lote → SSE → refresh funciona contra el backend real | B-04 |

## Pruebas RED requeridas

**NO APLICA.** No se escribe código ni tests en LB-001B (`CONTRACT_ANALYSIS`). Un RED futuro deberá derivarse del contrato aprobado en LB-001C, no de este borrador.

## RED_SNAPSHOT

**NO APLICA** (sin RED en un análisis documental).

## Congelación

Sin contrato aprobado no hay congelación de tests. Revisor/aprobación pendientes: responsable de contratos en LB-001C.

## Integración y E2E

TP-007 y TP-013/TP-018 requieren SQL Server con fixtures controlados y un E2E con `USE_MOCKS=false` (MV-001, [MANUAL_VALIDATION_LEDGER](../../baseline/MANUAL_VALIDATION_LEDGER.md)); autorización del ambiente, cleanup y control de skips deben definirse en su PLAN. Un test que aborte por `assumption` no cuenta como PASS.

## Falsos positivos que deben evitarse

- No probar contra mocks del consumer (`useMocks=true`) ni mockear el SUT (C-015).
- No copiar expectativas del consumer actual como si fueran contrato (p. ej. `estado ?? 'AN'`, TC-02).
- No afirmar formato de `LocalTime`/`Instant` sin serializar realmente el DTO (B-03).
- No dar por válido un 403 solo porque Angular oculte la ruta; el backend es la autoridad.
