---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-22
---

# CONTRACT_FREEZE — LB-001B.1 (backend): retiro de `descripcion/aula/tipo` en crear/actualizar Sesion

Fase 02-contratos. Ningún archivo de `src/main/**`, `src/test/**`, SQL, `pom.xml` ni el repo frontend fue modificado en esta sesión. Este documento congela el contrato TARGET para que 03-tester-red derive RED y 04-implementador lo ejecute, conforme al PLAN.md de este work item (sub-alcance BACKEND, `READY`).

## 1. HTTP contract AS-IS (confirmado leyendo el controller real)

Fuente: `src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/sesion/SesionController.java`.

| Operación | Verbo + ruta | Request body | Response (AS-IS, sin cambio) |
|---|---|---|---|
| Crear sesión | `POST /api/v1/sesiones` (l.84-93) | `CrearSesionRequest` | `201 CREATED`, `ApiMessageResponse` |
| Actualizar sesión | `PUT /api/v1/sesiones/{sesionId}` (l.140-152) | `ActualizarSesionRequest` | `200 OK`, `ApiDataResponse<Void>` (`datos: null`) |

No hay `RequestValidationGuard` invocado en `actualizarSesion` (l.140-152): a diferencia de crear (`CREATE_SESSION_VALIDATOR`, l.87), actualizar **no tiene validador HTTP propio registrado** hoy. No existe `ActualizarSesionRequestValidator.java` en el árbol (`src/main/java/.../sesion/validation/` solo contiene `CrearSesionRequestValidator`, `CerrarSesionRequestValidator`, `ConsultarSesionRequestValidator`). Esto es AS-IS, no se decide aquí si debe agregarse; el PLAN.md no lo pide.

Ninguna de las dos rutas tiene OpenAPI publicado (TD-002, citado en PLAN.md); esta sección es la única autoridad de contrato HTTP disponible.

## 2. Comportamiento Jackson ante campos retirados (confirmado, no supuesto)

Fuente: `src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/jackson/JacksonInputConfig.java` l.16-20.

```java
builder.enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
builder.enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);
builder.enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION);
```

**`FAIL_ON_UNKNOWN_PROPERTIES` está activo globalmente** (bean `strictJsonInputCoercionCustomizer`, sin excepción por controller/DTO visible en este archivo).

**Consecuencia contractual directa:** una vez retirados `descripcion`/`aula`/`tipo` de `CrearSesionRequest`/`ActualizarSesionRequest`, un cliente que hoy los envíe **no será ignorado silenciosamente — la petición completa será rechazada con `400`** (`UnrecognizedPropertyException` vía Jackson, mapeado por `GlobalExceptionHandler`). Esto es un `BEHAVIOR_CHANGE` real, no cosmético, y coincide con la clasificación que el PLAN.md ya declaró (`CONTRACT_CHANGE + BEHAVIOR_CHANGE`).

**Hallazgo adicional no anticipado explícitamente en el PLAN.md:** `CrearSesionRequest` y `ActualizarSesionRequest` tienen un setter alias `setRoom(String room) { this.aula = room; }` (`CrearSesionRequest.java` l.68-70; `ActualizarSesionRequest.java` l.56-58). Jackson descubre propiedades por setter, así que hoy el JSON key `"room"` deserializa igual que `"aula"` — es un shim de compatibilidad con el nombre de campo que usa el frontend (`ClassSession.room`, ver sección 5). Al retirar `aula`, este alias `room` también deja de existir como propiedad reconocida y debe retirarse junto con `aula` (mismo campo, mismo ciclo de vida).

## 3. Contrato TARGET congelado — campo por campo (ANTES → DESPUÉS)

Ninguna clase de dominio (`CrearSesionDomain`/`ActualizarSesionDomain`) tiene un getter/campo que no se liste aquí; se listan también sus validaciones de negocio porque desaparecen junto con el campo.

### 3.1 `CrearSesionRequest.java` (HTTP)

| Campo AS-IS | DESPUÉS | Nota |
|---|---|---|
| `grupo: UUID` | se mantiene | — |
| `tema: String` (con fallback a `nombre`) | se mantiene | — |
| `nombre: String` (solo setter, alias de `tema`) | se mantiene | — |
| `descripcion: String` | **RETIRAR** (campo + getter + setter) | — |
| `fechaHoraInicio: String` | se mantiene | — |
| `fechaHoraFin: String` | se mantiene | — |
| `aula: String` | **RETIRAR** (campo + getter + setter) | — |
| `setRoom(String)` (alias de `aula`) | **RETIRAR** | Consecuencia directa de retirar `aula`; ver sección 2 |
| `tipo: String` | **RETIRAR** (campo + getter + setter) | — |

### 3.2 `CrearSesionDTO.java` (aplicación, primary port)

| Campo AS-IS | DESPUÉS |
|---|---|
| `grupo, tema, fechaHoraInicio, fechaHoraFin, docente, usuarioEjecutor` | se mantienen |
| `descripcion` | **RETIRAR** (campo, getter, setter, parámetro de ambos constructores) |
| `aula` | **RETIRAR** |
| `tipo` | **RETIRAR** |

Constructor `CrearSesionDTO(UUID,String,String,LocalDateTime,LocalDateTime,String,String,UUID,UUID)` (9 parámetros) → nuevo constructor de 6 parámetros: `(UUID grupo, String tema, LocalDateTime fechaHoraInicio, LocalDateTime fechaHoraFin, UUID docente, UUID usuarioEjecutor)`.

### 3.3 `CrearSesionRepositoryDTO.java` (puerto secundario)

Idéntico patrón que 3.2: retira `descripcion`, `aula`, `tipo`; constructor pasa de 9 a 6 parámetros con el mismo orden relativo (`grupo, tema, fechaHoraInicio, fechaHoraFin, docente, usuarioEjecutor`).

### 3.4 `CrearSesionDomain.java` (dominio del caso de uso)

| Campo/lógica AS-IS | DESPUÉS |
|---|---|
| `grupo, tema, fechaHoraInicio, fechaHoraFin, docente, usuarioEjecutor` + validaciones existentes | se mantienen sin cambio |
| `descripcion` + `validarDescripcion(String)` (l.95-107: normaliza, `null` si vacío, longitud 10-250 o `ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA`) | **RETIRAR** campo, getter y método de validación completos |
| `aula` (`TextHelper.trim(aula)`, sin validación de longitud) | **RETIRAR** |
| `tipo` (`TextHelper.trim(tipo)`, sin validación) | **RETIRAR** |

`SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` (`SesionErrorCode.java` l.13) queda sin ningún lanzador en producción tras este cambio (confirmado por grep: solo se usa en `CrearSesionDomain.java`, `ActualizarSesionDomain.java` y su test `ActualizarSesionDomainTest.java`). **Decisión fuera de esta fase:** el PLAN.md no pide retirar entradas de `SesionErrorCode`; 04-implementador no debe borrar la constante sin que 02-contratos/03-tester-red lo autorice explícitamente (podría quedar como código muerto documentado, o retirarse — es una decisión de alcance menor que corresponde a 03-tester-red al fijar el RED, no algo que se resuelva por omisión).

### 3.5 `CrearSesionMapper.java` / `CrearSesionRepositoryMapper.java`

Dejan de pasar `descripcion/aula/tipo` en las llamadas a `new CrearSesionDomain(...)` / `new CrearSesionRepositoryDTO(...)` respectivamente (mismo archivo, solo ajuste de argumentos a los constructores reducidos de 3.2-3.4).

### 3.6 `CrearSesionUseCaseImpl.java`

L.34-37 reconstruye `CrearSesionDomain` con `docenteId` resuelto por scope; el nuevo constructor de 6 parámetros retira los 3 argumentos correspondientes. Sin otro cambio de lógica.

### 3.7 `ActualizarSesionRequest.java` (HTTP)

| Campo AS-IS | DESPUÉS |
|---|---|
| `nombre` (con fallback a `tema`), `tema` (solo setter), `fechaHoraInicio`, `fechaHoraFin` | se mantienen |
| `descripcion` | **RETIRAR** |
| `aula` | **RETIRAR** |
| `setRoom(String)` (alias de `aula`) | **RETIRAR** |

Nota: `ActualizarSesionRequest` no tenía `tipo` en AS-IS (confirmado leyendo el archivo — el SP `usp_actualizar_sesion` tampoco lo acepta en su firma, según PLAN.md AS-IS #4/#6), por eso no aparece en esta tabla.

### 3.8 `ActualizarSesionDTO.java`

| Campo AS-IS | DESPUÉS |
|---|---|
| `sesion, nombre, fechaHoraInicio, fechaHoraFin, docente, usuarioEjecutor` | se mantienen |
| `aula` | **RETIRAR** |
| `descripcion` | **RETIRAR** |

Constructor pasa de 8 a 6 parámetros: `(UUID sesion, String nombre, LocalDateTime fechaHoraInicio, LocalDateTime fechaHoraFin, UUID docente, UUID usuarioEjecutor)`.

### 3.9 `ActualizarSesionRepositoryDTO.java` (record)

AS-IS: `record ActualizarSesionRepositoryDTO(UUID sesion, String nombre, LocalDateTime fechaHoraInicio, LocalDateTime fechaHoraFin, String aula, String descripcion, UUID docente, UUID usuarioEjecutor)`.

DESPUÉS: `record ActualizarSesionRepositoryDTO(UUID sesion, String nombre, LocalDateTime fechaHoraInicio, LocalDateTime fechaHoraFin, UUID docente, UUID usuarioEjecutor)` — retira `aula` y `descripcion`; todos los accesos posicionales (`dto.aula()`, `dto.descripcion()`) en `SesionRepositorySqlServerAdapter.actualizarSesion` deben retirarse (ver sección 6).

### 3.10 `ActualizarSesionDomain.java`

Mismo patrón que 3.4: retira `aula` (campo, `TextHelper.trim`) y `descripcion` (campo + `validarDescripcion(String)`, l.82-91, idéntica lógica 10-250/`ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` que en crear). Constructor pasa de 8 a 6 parámetros.

### 3.11 `ActualizarSesionMapper.java` / `ActualizarSesionRepositoryMapper.java` / `ActualizarSesionUseCaseImpl.java`

Mismo ajuste mecánico que 3.5/3.6, adaptado a los 6 parámetros de `ActualizarSesionDomain`/`ActualizarSesionRepositoryDTO`.

### 3.12 `CrearSesionRequestValidator.java`

L.27: `validateOptionalMaxLength(builder, "descripcion", request.getDescripcion(), 250, ...)` — **RETIRAR** esta línea completa (el getter `request.getDescripcion()` deja de existir tras 3.1). El resto del validador (grupo, tema) no cambia.

No existe `ActualizarSesionRequestValidator.java` (ver sección 1) — nada que tocar ahí.

### 3.13 `SesionHttpMapper.java`

Ver sección 4 — sí mapea los tres campos y debe actualizarse.

### 3.14 `SesionConsultadaDTO.java` — sin cambios (confirmado)

No forma parte de este contrato TARGET. Ya expone exactamente `sesion, grupo, nombre, numero, codigo, numeroSemana, codigoGrupo, nombreGrupo, fechaHoraInicio, fechaHoraFin`, igual que `uv_sesion`. No se lee ni se toca en esta fase más allá de esta confirmación.

## 4. `SesionHttpMapper.java` — confirmación del PLAN.md ("a confirmar")

**Confirmado: SÍ mapea `descripcion`, `aula` y `tipo`.** Evidencia exacta:

```java
// l.21-34 — toApplicationDTO(CrearSesionRequest, UUID)
return new CrearSesionDTO(
        request.getGrupo(),
        request.getTema(),
        request.getDescripcion(),   // ← retirar
        HttpTemporalParser.parseLocalDateTime(request.getFechaHoraInicio(), "fechaHoraInicio"),
        HttpTemporalParser.parseLocalDateTime(request.getFechaHoraFin(), "fechaHoraFin"),
        request.getAula(),          // ← retirar
        request.getTipo(),          // ← retirar
        usuarioEjecutor,
        usuarioEjecutor
);

// l.46-62 — toApplicationDTO(UUID, ActualizarSesionRequest, UUID)
return new ActualizarSesionDTO(
        sesionId,
        request.getNombre(),
        HttpTemporalParser.parseLocalDateTime(request.getFechaHoraInicio(), "fechaHoraInicio"),
        HttpTemporalParser.parseLocalDateTime(request.getFechaHoraFin(), "fechaHoraFin"),
        request.getAula(),          // ← retirar
        request.getDescripcion(),   // ← retirar
        usuarioEjecutor,
        usuarioEjecutor
);
```

`SesionHttpMapper.java` **sí está dentro del alcance** de 04-implementador (el PLAN.md lo listaba condicionalmente — la condición se cumple).

## 5. Evidencia de consumidor confirmado (solo lectura del repo frontend — sin escritura)

Repo inspeccionado: `C:\Users\josev\OneDrive\Documentos\Front_Asistecias\AsistenciasUCO-Frontend` (branch `develop`, solo lectura, ningún archivo modificado). Responde a la pregunta abierta en PLAN.md §"Consumidor confirmado" / stop condition (a).

**`session.service.ts` (camino real, `useMocks=false`):**

- `createSession()` l.224-232: el `POST /sesiones` **hoy envía** `descripcion` (= `data.topic`), `aula` (= `data.room`), `tipo` (= `data.tipo`) además de `grupo/nombre/fechaHoraInicio/fechaHoraFin`.
- `updateSession()` l.262-263: hace `PUT /sesiones/{id}` con el objeto `cambios: Partial<ClassSession>` **tal cual**, sin normalizar nombres de campo — es decir, si el llamador pasa `{ room: 'X' }`, el body HTTP literal es `{"room":"X"}` (no se traduce a `aula` en el frontend; depende del alias `setRoom` del backend, ver sección 2).

**Confirmado por spec de contrato del propio frontend** (`session.service.contract.spec.ts`, l.45-70 y l.72-84 — no editado, solo leído):
- `createSession(...)` espera que el body enviado sea exactamente `{grupo, nombre, descripcion, fechaHoraInicio, fechaHoraFin, aula, tipo}` — este test **asertará FAIL** tan pronto el backend rechace `descripcion/aula/tipo`, y ya hoy documenta que el frontend real los envía.
- `updateSession('grupo-1','ses-1',{room:'B-202'})` espera que el body PUT sea `{room:'B-202'}` — coincide con el alias `setRoom` del backend (sección 2).

**Formularios que llaman a estos métodos** (grep dirigido, sin edición):
- `attendance-control.component.ts` l.260-274 (`onCreateSessionSubmit`): construye el payload de creación con `topic`, `room`, `tipo` siempre poblados (incluso con defaults `'Aula A-101'`/`'Desarrollo curricular...'` si el formulario no los trae).
- `teacher-grupos.component.ts` l.479-499 (crear) y l.500-520 (actualizar): ambos formularios envían `topic`, `room`, `tipo` explícitamente desde `this.sesionForm`.

**Conclusión de evidencia:** el frontend **sí** envía hoy `descripcion/aula/tipo` en creación y (indirectamente, vía el alias `room`) `aula` en actualización, en el camino real (no solo mocks) y en los dos formularios de producción encontrados. Esto es evidencia dura de que el retiro backend, si se despliega antes que el frontend correspondiente (`LB-001B.1B`), causará `400` en creación/actualización real de sesión para todo usuario. **No es un `CONTRACT_CONFLICT`** (el PLAN.md ya anticipa y secuencia esto vía `LB-001B.1B`), pero se registra aquí como hallazgo de severidad alta para que 04-implementador/05-auditor no lo trate como sorpresa, y para que el rollout backend↔frontend se coordine (fuera del alcance de escritura de esta sesión).

## 6. SQL final (sin tocar DB; solo referencia de lo que el adapter deja de enviar)

Fuente: `SesionRepositorySqlServerAdapter.java`. Los SP conservan su firma completa en DB_ROOT (no se toca DB); el adapter deja de enviar los parámetros retirados porque son opcionales (`= NULL`) en ambos SP (confirmado en PLAN.md AS-IS #3/#4).

**`SQL_CREAR_SESION` (DESPUÉS, retira `@descripcion`/`@aula`/`@tipo`):**
```sql
EXEC dbo.usp_crear_sesion
     @idGrupo = :idGrupo,
     @idDocente = :idDocente,
     @nombre = :nombre,
     @fechaHoraInicio = :fechaHoraInicio,
     @fechaHoraFin = :fechaHoraFin,
     @idCorrelacion = :idCorrelacion,
     @idUsuarioEjecutor = :idUsuarioEjecutor
```

**`SQL_ACTUALIZAR_SESION` (DESPUÉS, retira `@aula`/`@descripcion`):**
```sql
EXEC dbo.usp_actualizar_sesion
     @idSesion = :idSesion,
     @nombre = :nombre,
     @fechaHoraInicio = :fechaHoraInicio,
     @fechaHoraFin = :fechaHoraFin,
     @idDocente = :idDocente,
     @idCorrelacion = :idCorrelacion,
     @idUsuarioEjecutor = :idUsuarioEjecutor
```

En `crearSesion(...)` (l.131-152) y `actualizarSesion(...)` (l.154-174): retirar las líneas `.addValue(PARAM_AULA, ...)`, `.addValue(PARAM_DESCRIPCION, ...)` (crear y actualizar) y `.addValue(PARAM_TIPO, dto.getTipo())` (solo crear); retirar las constantes `PARAM_DESCRIPCION`, `PARAM_AULA`, `PARAM_TIPO` (l.36,39,40) si quedan sin otro uso en el archivo (confirmar en 04-implementador que ningún otro método del mismo adapter las reutiliza antes de borrarlas). `SQL_CONSULTAR_POR_ID`/`SQL_CONSULTAR_POR_GRUPO` **no se tocan** (fuera de alcance, ya sin `descripcion/aula/tipo`).

## 7. Lista exacta de archivos + símbolos para 04-implementador

**Producción (`src/main/java`):**
1. `infrastructure/adapter/primary/controller/sesion/request/CrearSesionRequest.java` — retirar `descripcion`, `aula`, `tipo`, `setRoom`
2. `infrastructure/adapter/primary/controller/sesion/request/ActualizarSesionRequest.java` — retirar `descripcion`, `aula`, `setRoom`
3. `infrastructure/adapter/primary/controller/sesion/validation/CrearSesionRequestValidator.java` — retirar la validación de `descripcion` (l.27)
4. `infrastructure/adapter/primary/controller/sesion/mapper/SesionHttpMapper.java` — actualizar ambas construcciones de DTO (l.21-34, l.46-62)
5. `application/features/sesion/crearsesion/primaryports/dto/CrearSesionDTO.java` — retirar `descripcion`/`aula`/`tipo`, constructor 9→6 parámetros
6. `application/features/sesion/crearsesion/primaryports/mapper/CrearSesionMapper.java` — ajustar `toDomain(...)`
7. `application/features/sesion/crearsesion/usecase/domain/CrearSesionDomain.java` — retirar campos, getters y `validarDescripcion(...)`
8. `application/features/sesion/crearsesion/usecase/mapper/CrearSesionRepositoryMapper.java` — ajustar `toRepositoryDTO(...)`
9. `application/features/sesion/crearsesion/usecase/impl/CrearSesionUseCaseImpl.java` — ajustar reconstrucción de `CrearSesionDomain` (l.34-37)
10. `application/secondaryports/repository/dto/CrearSesionRepositoryDTO.java` — retirar `descripcion`/`aula`/`tipo`, constructor 9→6 parámetros
11. `application/features/sesion/actualizarsesion/primaryports/dto/ActualizarSesionDTO.java` — retirar `aula`/`descripcion`, constructor 8→6 parámetros
12. `application/features/sesion/actualizarsesion/primaryports/mapper/ActualizarSesionMapper.java` — ajustar `toDomain(...)`
13. `application/features/sesion/actualizarsesion/usecase/domain/ActualizarSesionDomain.java` — retirar campos, getters y `validarDescripcion(...)`
14. `application/features/sesion/actualizarsesion/usecase/mapper/ActualizarSesionRepositoryMapper.java` — ajustar `toRepositoryDTO(...)`
15. `application/features/sesion/actualizarsesion/usecase/impl/ActualizarSesionUseCaseImpl.java` — ajustar reconstrucción de `ActualizarSesionDomain` (l.35-44)
16. `application/secondaryports/repository/dto/ActualizarSesionRepositoryDTO.java` — retirar `aula`/`descripcion` del record (8→6 componentes)
17. `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapter.java` — `SQL_CREAR_SESION` (l.45-57), `SQL_ACTUALIZAR_SESION` (l.67-78), `crearSesion(...)` (l.131-152), `actualizarSesion(...)` (l.154-174); no tocar `SQL_CONSULTAR_*` ni `consultarSesion(...)`

**Decisión pendiente de 03-tester-red (no resolver por omisión, ver sección 3.4):** si `SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` se retira o queda como código muerto documentado.

**Tests (`src/test/java`, ajustar — no reescribir para forzar GREEN sin justificación, ver AGENTS.md §4):**
- `application/features/sesion/crearsesion/usecase/mapper/CrearSesionRepositoryMapperTest.java`
- `application/features/sesion/crearsesion/usecase/domain/CrearSesionDomainTest.java`
- `application/features/sesion/crearsesion/usecase/impl/CrearSesionUseCaseImplTest.java`
- `application/features/sesion/crearsesion/primaryports/mapper/CrearSesionMapperTest.java`
- `application/features/sesion/actualizarsesion/usecase/mapper/ActualizarSesionRepositoryMapperTest.java`
- `application/features/sesion/actualizarsesion/usecase/domain/ActualizarSesionDomainTest.java`
- `application/features/sesion/actualizarsesion/usecase/impl/ActualizarSesionUseCaseImplTest.java`
- `application/features/sesion/actualizarsesion/primaryports/mapper/ActualizarSesionMapperTest.java`
- `infrastructure/adapter/primary/controller/sesion/SesionControllerContractTest.java` — **hallazgo concreto:** `createAcceptsLegacyNameAndRoomAndPassesParsedDatesAndActor` (l.54-74) y `updateCloseAndGeneratePassPathBodyAndActor` (l.101-133) afirman explícitamente el comportamiento AS-IS (`descripcion/room→aula/tipo` presentes y mapeados: l.58-60,68,72,106,114). Bajo el TARGET, estas aserciones y sus bodies JSON deben cambiar; 03-tester-red decide la forma del RED (p. ej. añadir un caso que verifique `400` si el cliente envía `aula`/`descripcion`/`tipo`, dado `FAIL_ON_UNKNOWN_PROPERTIES`, sección 2). No es un `TEST_CONTRACT_CONFLICT` bloqueante: el test encierra el contrato viejo por diseño y el propio PLAN.md ya lo lista como archivo a tocar.
- `infrastructure/adapter/secondary/persistence/sqlserver/core/SesionRepositorySqlServerAdapterTest.java`
- `infrastructure/adapter/primary/controller/admin/AdminPortalControllerTest.java` / otros controllers listados como `M` en git status — **no inspeccionados en esta sesión** (fuera del alcance de `Sesion`; no se listan aquí salvo evidencia directa)

**No tocar (confirmado):** `SesionConsultadaDTO.java`, su mapper/consulta de lectura, `SQL_CONSULTAR_POR_ID`, `SQL_CONSULTAR_POR_GRUPO`.

**Frontend:** ningún archivo se edita desde esta sesión backend. La evidencia de la sección 5 queda disponible para `LB-001B.1B-db-source-of-truth-cleanup` (repo frontend), que deberá: retirar `descripcion/aula/tipo` de los payloads de `session.service.ts` (`createSession`, y el uso de `room` en `updateSession`), actualizar `session.service.contract.spec.ts` y los dos formularios identificados (`attendance-control.component.ts`, `teacher-grupos.component.ts`).

## 8. DR-001 y DR-004 — registro de resolución (Opción B)

**No se edita** `docs/work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md` (confirmado cerrado por el PLAN.md de este work item; su pie de página actual dice literalmente `**DRAFT** — HTTP/FRONTEND CONTRACT NOT FROZEN. Evidence of approval: ninguna.` — leído, no alterado). Se registra aquí la resolución trazable:

| ID | Texto original (CONTRACT_MATRIX LB-001B) | Status original | Status nuevo | Decisión | Aprobador/referencia |
|---|---|---|---|---|---|
| DR-001 | "¿el contrato de `GET /api/v1/sesiones/grupo/{grupoId}` debe exponer el estado de la sesión...?" (l.470-472 del CONTRACT_MATRIX citado) | PENDING | **RESOLVED — Opción B** | No se agrega `status` a `SesionConsultadaDTO`/DB. El frontend retira la síntesis de `status` (`ClassSession.status`) sin sustituirla por una regla de UI inventada; la autoridad de "sesión cerrada" sigue siendo el error de negocio existente en backend/SP, no un campo de estado en el contrato de lectura. | Decisión humana pegada verbatim en la sesión de 01-planificador, 2026-09-22 (secciones 0 y 12-16 de la tarea autorizada), citada en `PLAN.md` §"Identidad y objetivo" y §TARGET de este work item |
| DR-004 | "¿`topic`, `room`, `tipo` (sesión) y `docenteName` (grupo) forman parte del contrato de lectura del Golden Path?" (l.506-508 del CONTRACT_MATRIX citado) | PENDING | **RESOLVED — Opción B** | No se agregan `topic/room/tipo/docenteName` a `SesionConsultadaDTO`/`HorarioDocenteDTO`/DB. Se retiran del contrato de **escritura** (`CrearSesionRequest`/`ActualizarSesionRequest`, este documento §3) y de los modelos de presentación del frontend (`ClassSession`, `Course.docenteName` — ejecución en `LB-001B.1B`). | Misma referencia que DR-001 |

**Advertencia explícita (obligatoria por instrucción de la tarea):** la actualización formal de `docs/work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md` (mover DR-001/DR-004 de `PENDING` a `RESOLVED` en el documento original, y su tabla de "Contrato congelado") **requiere aprobación separada de reapertura de ese work item cerrado**. Esta sesión (02-contratos, LB-001B.1) no la ejecuta ni la autoriza por sí misma — solo dejar esta referencia trazable para quien la ejecute (probablemente 06-cierre de LB-001B.1, con aprobación explícita).

## 9. Stop conditions evaluadas en esta fase

- **`CONTRACT_CONFLICT`:** ninguno. El AS-IS de código (controller, DTOs, adapter, Jackson) coincide exactamente con lo que el PLAN.md de 01-planificador ya había documentado; no se encontró contradicción entre fuentes autoritativas.
- **`TEST_CONTRACT_CONFLICT`:** ninguno bloqueante. `SesionControllerContractTest.java` afirma hoy el comportamiento AS-IS (sección 7) — es el resultado esperado de un contrato que aún no se ha retirado, y el propio PLAN.md ya lo anticipa como archivo a tocar por 03-tester-red/04-implementador, no algo que 02-contratos deba resolver por adivinanza.
- **`BLOCKED_BY_MISSING_EVIDENCE`:** la única pendiente que el PLAN.md dejaba abierta para esta fase — "confirmación del payload exacto que el frontend envía hoy" — queda **resuelta** por la sección 5 de este documento (lectura confirmada de `session.service.ts`, su spec de contrato y los dos formularios que lo invocan).
- Los demás `BLOCKED_BY_MISSING_EVIDENCE`/`NOT_READY` del PLAN.md (secuencia de cierre de `LB-001B.1A`, ejecución de `LB-001B.1B`, `mvn verify` no re-ejecutado) **no se resuelven aquí** — no son responsabilidad de 02-contratos backend y siguen abiertos tal como el PLAN.md los dejó.

## 10. Validación pendiente (no ejecutada en esta fase)

Sin cambios de código, no aplica ejecutar `mvnw verify` en esta sesión. Referencia para 04-implementador/05-auditor: `.\mvnw.cmd verify` (Windows) con gates JaCoCo LINE ≥80% / BRANCH ≥70% del `pom.xml`, conforme a AGENTS.md §"Validación mínima".
