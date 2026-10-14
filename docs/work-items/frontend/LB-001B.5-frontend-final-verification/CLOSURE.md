# LB-001B.5 frontend final verification — CLOSURE

Estado: **DONE** (código, tests, build y contrato frontend). **MV-001: BLOCKED_BY_ENVIRONMENT.**

## Autoridad externa

- `docs/contracts/external/backend/BACKEND_GOLDEN_PATH_CONTRACT.md` — SHA-256 `02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121` (coincide con su `.sha256` y con la fuente; copia byte a byte, ver `PROVENANCE.md`).
- El precheck original se bloqueó porque el artefacto no estaba en el frontend; se materializó desde el repo backend (solo lectura).

## Cambios

| Área | Cambio |
|---|---|
| `nombre` 1..50 | `session-name.util.ts`; `maxlength=50`, mensaje y botón deshabilitado en ambos formularios; `SessionService.createSession/updateSession` rechazan localmente y envían `nombre` recortado. |
| Errores por `code` | `api-error.util.ts` (`getApiErrorCode`, `API_ERROR_CODE`); `getApiErrorMessage` deja de ramificar por status/texto (se eliminó la comparación con el mensaje español); `errorInterceptor` decide por `FORBIDDEN`. |
| SSE reconexión | `fetch-sse-realtime-transport.ts`: listeners `online`/`offline`, pausa interrumpible, fallo de token/refresh sin red ya no termina el bucle; 401 → refresh; 403 terminal. |
| Lote parcial | `AttendanceControlComponent` envía solo lo seleccionado/modificado (conjunto de pendientes); refresco por SSE conserva selecciones locales. |
| Horario sin `aula` | `HorarioDocenteApiDto` sin `aula`; `Course.room` = marcador `No disponible`. |
| Fixtures | Retirados `topic`/`status` sintéticos de los specs de asistencia. |

## Decisiones registradas

- **Lote parcial = solo seleccionados/modificados.** Antes se reenviaban también los estados ya persistidos. Test `incluye solo matrículas A y NO reenvía…` reemplaza al anterior, que esperaba el reenvío (conflicto con «solo registros seleccionados/modificados»).
- **Refresh que falla por red** en el transporte SSE: el bucle espera y reintenta mientras exista sesión (`token()`); si el refresh fue rechazado por el IdP, el siguiente 401 HTTP expira la sesión.
- **Temporal:** sin cambios; ambigüedad registrada como `READY_FOR_LB001C_TEMPORAL_DECISION`.
- **TD-031:** ya cerrado; reconfirmado con `auth.interceptor.spec.ts` (401 → refresh → reintento; refresh fallido → una sola expiración; 403 sin refresh).

## Validación

- Tests: 235 / 235 SUCCESS (línea base previa: 184). Lines 62.45 %, branches 43.86 %, functions 48.10 % (antes 61.22 / 42.58 / 46.48).
- `coverage:realtime:check`: PASSED (líneas 94.48 % ≥ 90, ramas 81.69 % ≥ 80; antes 95.62 / 87.50 — sigue sobre el umbral, los umbrales no se tocaron).
- `npm run build -- --configuration=production`: PASS.
- Nota de proceso: los specs nuevos y el código se escribieron en la misma pasada; no se ejecutó una corrida RED separada.

## MV-001

`BLOCKED_BY_ENVIRONMENT` — ver `MV-001-CHECKLIST.md`. Hasta ejecutarlo: **READY FOR LB-001C = NO (MV-001 pending).**

## Límites

DB modificada: NO. Backend modificado: NO. OpenAPI / JPA / Redis / serverless iniciados: NO. Commits: NO. Push: NO.

---

# LB-001B.5A — Frontend Golden Path contract polish

Estado: **DONE** (código, tests, build, contrato frontend). **MV-001 sigue pendiente** (`BLOCKED_BY_ENVIRONMENT`). Las secciones anteriores se conservan como evidencia histórica; donde 5A las contradice, **manda 5A** (p. ej. la fila «Horario sin `aula`» de la tabla de cambios ya no usa el marcador `No disponible`).

Autoridad: `docs/contracts/external/backend/BACKEND_GOLDEN_PATH_CONTRACT.md` (SHA-256 `02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121`, sin cambios).

## Cambios

| Área | Cambio |
|---|---|
| Sesion sin lifecycle | Eliminados el input `isSessionConcluded` (header y tabla), sus gates, las insignias «Clase Activa» / «Asistencia Consolidada», el banner «Sesión Finalizada y Consolidada» / «Registro Cerrado» y «Historial Inmutable» del detalle. Sin sustituto. Los controles dependen de `sessionsEnabled`, `attendanceEnabled`, `isSaving` (`controlsDisabled` en la tabla) y, en el marcado masivo del header, de que exista sesión (`bulkDisabled`). «Guardar y Consolidar Asistencia» → «Guardar Asistencia»; toast de respaldo «guardada». |
| Sin aula sintética | `CourseService` ya no asigna `room` (antes `'No disponible'`). `Course.room`, `HorarioDocenteItem.aula` y `ProximaClaseInfo.aula` pasan a opcionales. Retirada la aula de: tarjeta y búsqueda de grupos, hub, pestaña «Horario» (antes «Horario & Aula»), cronograma de sesiones, detalle de sesión (input `room` eliminado), `/app/docente/horarios` y dashboard docente (sin fallback `'Aula Principal'`). |
| `updateSession` | Ahora `Observable<ApiVoidDataResponse>` (`ApiDataResponse<null>`, alias nuevo en `api-data-response.model.ts`). Sin `idTransaccion`/`mensajeUsuario`/`ClassSession` fabricados; el mock devuelve `{ exitoso: true, datos: null }`. `TeacherGruposComponent` usa solo `exitoso` y recarga por HTTP. |
| Acciones fuera de contrato | `environment.features.sessionQrEnabled = false` y `sessionCancelEnabled = false` (decisión `OUT_OF_GOLDEN_PATH`). Ocultos: «QR / PIN» y «Cancelar» por sesión, «Proyectar Auto-Registro» (hub) y «QR Asistencia» (lista). Los manejadores de `TeacherGruposComponent` no invocan `getQrToken`/`cancelarSesion` con la feature apagada. Métodos legados marcados `@deprecated OUT_OF_GOLDEN_PATH`; `closeSession` no tiene UI. |

## Decisiones registradas

- **Feature flag en `environment.features`** (mismo mecanismo que `sessionsEnabled`/`attendanceEnabled`) en vez de borrar las acciones: deja constancia explícita, reactivable cuando exista contrato, y con test que prueba tanto «oculta» como «aparece solo con la feature».
- **`isSaving` bloquea también los controles de estado** (antes solo mostraba el spinner del botón de guardar): evita editar selecciones mientras el lote está en vuelo, que se limpian al terminar. Es el único cambio de comportamiento no puramente de retirada.
- **Verticales legado con `room`** (grupo crear/editar, decano, coordinador, estudiante, mapper de asignaciones, mocks, catálogo admin): no se tocan; documentados `OUT_OF_GOLDEN_PATH` en el contrato §4.1. Sin aula real muestran el campo vacío (son roles no `DOCENTE` que consumen un endpoint solo-`DOCENTE`).
- **«En curso» / «Programada» del widget «Próxima clase»** se dejan: se derivan del reloj y del horario semanal, no de la Sesion.
- **No se reabre** nombre 1..50, AN/SJC/EX, «Sin registrar», lote parcial, roles, `ApiErrorResponse.code`, refresh 401, correlación, reconexión SSE, HTTP como fuente de verdad ni `USE_MOCKS=false`.

## Tests

Añadidos/ajustados solo los necesarios: `attendance-control-header.component.spec.ts` (nuevo), `attendance-control-table.component.spec.ts`, `teacher-grupo-sesiones.component.spec.ts`, `teacher-grupo-hub.component.spec.ts`, `teacher-grupos-list.component.spec.ts`, `teacher-sesion-detalle-modal.component.spec.ts`, `teacher-grupos.component.spec.ts`, `course.service.spec.ts`, `session.service.contract.spec.ts`, `golden-path-real-mode.spec.ts` (la aserción anterior exigía un `room` definido; ahora exige `undefined`).

## Validación

- Nota de entorno: el checkout no tenía `node_modules`; se ejecutó `npm ci` (lockfile, sin cambios en `package.json`/`package-lock.json`).
- `npm run test:ci`: **256 / 256 SUCCESS** (antes 235). Statements 62.66 %, branches 44.93 %, functions 49.49 %, lines 63.76 %.
- `npm run coverage:realtime:check`: **PASSED** — líneas 94.48 % (≥ 90), ramas 81.69 % (≥ 80). Umbrales sin tocar.
- `npm run build -- --configuration=production`: **PASS** (AOT, plantillas verificadas).
- `SESSION_SYNTHETIC_LIFECYCLE_COUNT = 0` y `GOLDEN_PATH_SYNTHETIC_ROOM_COUNT = 0` con los `grep` reproducibles del contrato frontend §11.

## Deuda no bloqueante

Ver contrato frontend §12 (contrato backend de QR/cancelar/cerrar sesión; `cupoMaximo || 35`, «Grupo Activo» y «Horas / Semana» sintéticos ajenos a Sesion/aula; detalle de sesión sin registros).

## MV-001

Sin cambios: `BLOCKED_BY_ENVIRONMENT`. **READY FOR MV-001: YES. READY FOR LB-001C: NO — MV-001 todavía debe ejecutarse.**

## Límites 5A

DB modificada: NO. Backend modificado: NO. OpenAPI / JPA / Redis / serverless iniciados: NO. Commits: NO. Push: NO.
