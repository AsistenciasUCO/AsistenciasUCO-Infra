# CULM-001 · Paquete D — CONTRACT (HUs pendientes de la sección 3.6 y hallazgos medios)

> **Estado:** v1, para la revisión 9.2. No se congela ni se firma (`.sha256`) antes de "sin objeciones". El RED empieza después de la revisión.
> **Fecha:** 2026-11-07. **Fase SDD:** 02 CONTRACT.
> **Fuentes:** `docs/PROMPT_FABLE_CULMINACION.md` §3.6 (líneas 66-72); `DECISIONES.md` DEC-040 (alcance, no se reabre), DEC-022 §4 y §8, DEC-028 (numeración), DEC-031, DEC-036, DEC-037/DEC-038 (rutas nuevas y PDP); `FINDINGS.md` (35 filas `paquete-D`, más F-COO-007 y R-8 de A, que A y B difirieron a D); `RESEARCH-MODELO-ACTUAL.md` §2.5, §4.3 y §6; `HU-CATALOG.md` (HU014, HU015, HU026B, HU027, HU061, HU091, HU103, HU117-B, HU120, HU134, HU139, HU156, HU168, HU169, HU170, HU171, HU172, HU177); `TECHNICAL_DEBT.md` de Infra (TD-009) y de Backend (TD-059, TD-060, TD-061); `GestioAsistenciaDB/docs/work-items/HU005-HU016-categorias-justificacion/DISENO_CAMBIO_COORDINADO.md` (LB-004D); CONTRACT de A y de B (diferidos a D: [SUPUESTO-B-18], [SUPUESTO-B-19], [SUPUESTO-B-23], R-8 de A); `AGENTS.md` §3.3 y §4.
> **Rutas:** `DB:` = `GestioAsistenciaDB/`, `BE:` = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, `BE-T:` = `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`, `FE:` = `GestioAsistenciaFrontend/src/app/`, `INFRA:` = `AsistenciasUCO-Infra/`. Todo bajo `C:\Proyectos\GestionAsistencia-CULM001\`.
> **Base:** `integracion/CULM-001` con A y B.1 mezclados. D.7 y D.8 exigen además B.2 mezclado; D.9-c exige C mezclado (§13).
> **Numeración (DEC-028):** migración del subpaquete D.x = `19 + x` (D.1 = `20` … D.9 = `28`); semilla de D.x = `40 + x` (D.1 = `41` … D.9 = `49`); prefijo `culm001_d<x>` en pruebas, permisos y manifiestos. Así cada D.x se puede mezclar en cualquier orden sin renumerar.

---

## 0. Supuestos y precisiones de diseño

Cada `[SUPUESTO-D-nn]` necesita la aceptación del orquestador en la revisión 9.2. Los marcados **(desvío de DEC-040)** cambian la letra de DEC-040, no su intención.

| ID | Supuesto | Motivo |
| :--- | :--- | :--- |
| [SUPUESTO-D-01] | **Plazo de HU026B (DEC-040: "días calendario desde el fin de la sesión"):** la radicación se admite mientras `SYSUTCDATETIME() < límite`. El límite es la medianoche local (`TIEMPO/ZONA_HORARIA_SQLSERVER`) del día `fecha local de fin de la sesión + N + 1`, con `N = ASISTENCIA/DIAS_LIMITE_JUSTIFICACION`. Ejemplo: con N = 5, una sesión que termina el miércoles 2026-11-04 a las 08:00 de Bogotá se puede justificar hasta el lunes 2026-11-09 a las 23:59:59 de Bogotá | "Días calendario" entendidos como días completos del calendario local. Una sesión que termina a las 23:30 no pierde un día. `DISENO_CAMBIO_COORDINADO.md` decía "desde la fecha de la sesión"; prevalece DEC-040 |
| [SUPUESTO-D-02] | **(desvío de DEC-040)** "`SoporteReclamo` 1:N" se realiza sobre la FK que ya existe, `ArchivoSoporte.solicitudRevisionAsistencia`: el índice único filtrado `UX_ArchivoSoporte_Solicitud` se reemplaza por el índice no único `IX_ArchivoSoporte_Solicitud`, y se publica la vista `uv_soporte_reclamo`. **No se crea una tabla `SoporteReclamo`** | Una tabla puente duplicaría el vínculo que ya guarda `ArchivoSoporte`, cuyo `CK_ArchivoSoporte_EstadoVinculo` exige `solicitudRevisionAsistencia` NOT NULL en `ATTACHED`; con la puente también habría que tocar `ArchivoSoporte`, que está en el manifiesto LB-004D. Quitar el índice filtrado es además la hipótesis de cierre de TD-059 (Msg 8624 por FK + índice filtrado) |
| [SUPUESTO-D-03] | **(desvío de DEC-040)** La lista blanca, el rango y la presentación de los parámetros van en una tabla satélite `CatalogoParametroEdicion` (1:1 con `CatalogoParametro`), no en columnas nuevas de `CatalogoParametro` | `DB_BASELINE_CONTRACT.md` §"Catalog Deploy" y el guard de `CatalogoParametro.sql` fijan su forma en 9 columnas (`SCHEMA_CONTRACT_CONFLICT`): añadir columnas reabriría un contrato WORM de línea base. Los nombres `esEditable`, `valorMinimo` y `valorMaximo` de DEC-040 se conservan en la tabla satélite |
| [SUPUESTO-D-04] | La auditoría de un cambio de parámetro es **doble**: (1) transaccional en BD (`CambioParametro`, en la misma transacción que el `UPDATE`) y (2) el evento HTTP de `AuditoriaEvento` (D.6), con `valorAnterior`/`valorNuevo` en `metadata` | El interceptor HTTP es de mejor esfuerzo (`afterCompletion`); un cambio de umbral institucional no puede quedar sin rastro si falla el publicador |
| [SUPUESTO-D-05] | El cambio de parámetro exige `motivo` (10–500 caracteres) y concurrencia optimista con `fechaModificacionEsperada` (F-ADM-003) | Igual que la corrección de identidad (HU159): motivo obligatorio y auditado |
| [SUPUESTO-D-06] | Con el catálogo de parámetros del backend en `azure` (no `sqlserver`), `PUT /admin/parametros/{id}` responde 409 `PRM_010`: la BD cambiaría y el backend seguiría leyendo Azure App Configuration | Evita dos verdades. En el laboratorio rige DEC-018 (`sqlserver`). Queda como deuda la propagación BD → Azure |
| [SUPUESTO-D-07] | HU156: la admisión exige un programa de la institución del administrador y crea el vínculo `EstudiantePrograma` (sin matrícula en grupos) | Sin programa, el coordinador no lo vería (DEC-020) y la matrícula manual tendría que crear el vínculo después |
| [SUPUESTO-D-08] | HU171: la plantilla CSV lleva una columna `clave_inicial` (obligatoria solo para personas nuevas), validada con la misma `PasswordRegistroRule` del alta individual. El archivo se procesa solo en memoria, nunca se guarda, no se registra en logs y la clave nunca vuelve en la respuesta | Es el mismo dato que hoy se teclea en el alta individual. La alternativa (clave temporal generada y enviada por correo, o enlace "establecer contraseña") depende de HU177, que está en espera del equipo de seguridad |
| [SUPUESTO-D-09] | HU171: el CSV es transitorio (no se guarda en MinIO ni en disco), así que no pasa por ClamAV. Se valida como texto UTF-8 con tamaño y filas limitados por parámetro | La regla de ClamAV de `AGENTS.md` §3.3.5 se aplica a los adjuntos que se persisten |
| [SUPUESTO-D-10] | HU171: la creación procesa fila por fila, sin transacción global. Cada fila usa el caso de uso individual con su propia transacción. Volver a cargar el mismo archivo es idempotente: las filas ya creadas salen como `YA_EXISTE` | Resultado por fila (DEC-040). Una transacción global no puede abarcar el proveedor de identidad |
| [SUPUESTO-D-11] | Una fila es `YA_EXISTE` cuando la persona (mismo documento y mismo correo) ya tiene el rol destino en ese ámbito (docente activo en el programa, coordinador del programa, decano activo). Si el documento y el correo apuntan a personas distintas, la fila es `ERROR` (`CMA_008`), igual que en el alta individual | Idempotencia por documento y correo sin ocultar conflictos de identidad |
| [SUPUESTO-D-12] | F-ADM-024 (decano duplicado): cuando el decano ya existe, el alta individual consulta la cuenta en el proveedor de identidad (`buscarCuentaPorIdUsuario`). Si la cuenta existe, responde 409 `DEC_020`. Si falta, la crea y responde 201 con `cuentaReparada = true`. Si el proveedor no ofrece esa consulta, responde 409 | El 201 silencioso de hoy es también la única vía para reintentar un aprovisionamiento fallido; un 409 sin más rompería esa reparación |
| [SUPUESTO-D-13] | Lo que se muestra como "por horas" en D.8 conserva los nombres de columna (como DEC-024). Se añaden `horasDictadas`, `horasFalta`, `porcentajeExcusa` y `porcentajeSinRegistro` | Los consumidores no cambian de contrato posicional; F-COO-007 se cierra con `porcentajeSinRegistro` explícito |
| [SUPUESTO-D-14] | Un id inexistente y un id fuera de ámbito responden igual, 403 (regla de DEC-025), en los listados por id de F-TRX-021 y en `GET /decano/grupos/{id}` | Evita enumerar ids; es la regla que A y B2 ya aplican en `/grupos/{id}/*` |
| [SUPUESTO-D-15] | La jerarquía de la carga masiva vive en una tabla de catálogo `JerarquiaAltaUsuario (perfilEjecutor, perfilDestino)` con 3 filas: COORDINADOR→DOCENTE, DECANO→COORDINADOR, ADMINISTRADOR→DECANO | Cero datos quemados en el SP de validación |

---

## 1. Alcance

### 1.1 Subpaquetes, prioridad y dependencias

| D.x | Contenido | HU / hallazgos | Prioridad (si falta tiempo) | Depende de |
| :--- | :--- | :--- | :--- | :--- |
| **D.1** | Plazo de excusas `ASISTENCIA/DIAS_LIMITE_JUSTIFICACION` en `usp_radicar_solicitud_revision_asistencia(_v2)` y en el formulario (fecha límite visible); fecha de radicación en hora local | HU026B; F-EST-008, F-EST-S16 | 1 (no diferible) | A |
| **D.2** | Varios soportes por reclamo; FK de categoría (TD-060); soporte obligatorio por categoría (HU014); literales de LB-004D (TD-061); verificación de TD-059 | HU015, HU014; LB-004D, TD-060, TD-061 | 2 | D.1 (mismo SP y mismo manifiesto) |
| **D.3** | `PUT /admin/parametros/{id}` con lista blanca, tipo, rango, reglas cruzadas, concurrencia, auditoría e invalidación (`PARAMETER_UPDATED`); consulta paginada y legible | HU168; F-ADM-003, F-ADM-012, parte de F-ADM-008 | 1 (no diferible) | A |
| **D.4** | `POST /admin/estudiantes/admision`, corrección de identidad del estudiante por el administrador, `GET /admin/programas`, servicio común `AsegurarCuentaIdentidadService` | HU156; F-ADM-004 | 1 (no diferible) | A |
| **D.5** | Carga masiva CSV de roles no estudiantes: plantilla, validación previa fila por fila, confirmación y creación idempotente | HU171 | 3 | D.4 (servicio de cuenta) y D.6 (metadatos de auditoría) |
| **D.6** | Auditoría de todas las mutaciones `/api/v1/admin/**` con actor, recurso, valores y `correlationId` expuesto; prueba de arquitectura que lo exige | HU172 (DEC-022 §4); F-ADM-022, F-ADM-S13 | 1 (no diferible) | A |
| **D.7** | Retiro de `POST /api/v1/asistencias` y `REVOKE`/`DROP` de `usp_registrar_asistencia_estudiante_autonomo` | HU027 (TD-009); F-DOC-022; [SUPUESTO-B-18], [SUPUESTO-B-19] | 1 (no diferible; bloqueado hasta B.2) | **B.2** (backend y BD mezclados) |
| **D.8** | Comparativas HU103/HU139, tendencia HU134 y consolidado HU061 por horas | HU061, HU103, HU134, HU139; F-COO-007 ([SUPUESTO-B-23]) | 2 | **B.2** (BD: `uv_resumen_*` por horas) |
| **D.9** | Hallazgos medios y bajos asignados a D (tabla §11) | 27 hallazgos propios (los otros 8 de `paquete-D` van a D.1, D.3, D.4, D.6 y D.7) más R-8 de A | 4 | D.6 (D.9-a); C (D.9-c) |

**Fuera de D:** HU169 (catálogo de mensajes), HU170 (sincronización Keycloak → BD) y HU177 (recuperar contraseña) quedan `[PENDIENTE]` con la nota "En espera de <equipo>" (§12). HU026C es de C. HU047 ya entró en B.1. Los fallos de línea base de `mvnw verify -Pintegration` (ESTADO) son de la Fase 3, salvo los que D toque.

### 1.2 Partes diferibles (declaración explícita)

Orden de corte si no hay tiempo antes del 2026-11-13: **D.1, D.3, D.4, D.6, D.7 > D.2, D.8 > D.5 > D.9**. Dentro de cada D.x, lo que se puede diferir sin dejar el subpaquete roto:

| Parte | Diferible | Qué queda si se difiere |
| :--- | :--- | :--- |
| D.2 entero | Sí | D.1 ya aplica el plazo; TD-060 y TD-061 siguen abiertas y HU015/HU014 quedan `[PARCIAL]`/bloqueadas |
| D.3: historial `GET /admin/parametros/{id}/cambios` y su pestaña | Sí | `CambioParametro` se escribe igual; solo falta la lectura |
| D.3: evento `PARAMETER_UPDATED` en el contrato de tiempo real | Sí | La caché se invalida igual; la pantalla se refresca con la respuesta del `PUT` |
| D.4: `PUT /admin/estudiantes/{id}/identidad` | Sí | La corrección sigue disponible para el coordinador |
| D.5 entero | Sí | HU171 queda `[PENDIENTE]` con la nota "diferida (CULM-001 D.5)" |
| D.5: plantillas y cargas de decano y administrador | Sí (se entrega primero la de coordinador → docentes) | Cargas de coordinadores y decanos en una iteración posterior |
| D.6: filtro "solo administración" y columna de correlación en la pantalla | Sí | El registro de eventos (lo esencial) no se difiere |
| D.8 entero | Sí | Comparativas, tendencia y consolidado siguen en unidades de sesión (nota "diferido" en el catálogo) |
| D.9 | Por grupos: D.9-a (seguridad y 4xx) > D.9-b (frontend) > D.9-d (docs/infra) > D.9-c (SSE, tras C) | Los no hechos vuelven a `abierto` en `FINDINGS.md` con la nota "diferido" |

### 1.3 HUs cubiertas

| HU | Antes | Después de D |
| :--- | :--- | :--- |
| HU026B | `[PENDIENTE]` | Implementada (D.1), a certificar en la Fase 3 |
| HU015 | `[PARCIAL]` | Implementada (D.2) |
| HU014 | Fase 3, bloqueada por LB-004D | Implementada como categoría MED con soporte obligatorio en el mismo formulario (D.2) |
| HU168 | `[PARCIAL]` (PUT 501) | Implementada (D.3) |
| HU156 | `[PENDIENTE]` | Implementada (D.4); la fila pasa a `POST /admin/estudiantes/admision` y a la pantalla `/app/admin/estudiantes` |
| HU171 | `[PENDIENTE]` (texto "secretaría") | Implementada con la regla de DEC-040 (roles no estudiantes, jerarquía) (D.5) |
| HU172 | `[CERTIFICADA]` | Ampliada: mutaciones del administrador auditadas y `correlationId` visible (D.6) |
| HU027 | `[CERTIFICADA]` con `POST /api/v1/asistencias` | La fila pasa a `POST /asistencias/lote` y al registro por toma (B.2); se quita la ruta retirada (D.7) |
| HU061, HU103, HU134, HU139 | Nota "diferido a D: deben pasar a horas" | Por horas (D.8) |

### 1.4 Reglas comunes

**BD** (como en B §2.0): `SET NOCOUNT ON; SET XACT_ABORT ON;`; transacción propia si `@@TRANCOUNT = 0`, si no `SAVE TRANSACTION`; `CATCH` con `IF @@TRANCOUNT > 0 ROLLBACK` o rollback al savepoint; `XACT_STATE() = -1` → `THROW`. Paso 1 `usp_validar_id_correlacion_esta_presente_interno`; RBAC con `usp_validar_permiso_rbac_usuario_interno`; mensajes con `usp_obtener_mensaje_catalogo`; `SYS_001` + `ufn_obtener_detalle_error` en errores inesperados. `@x IS NULL` explícito, sin GUID cero. Consultas como `usp_consultar_*` sobre `uv_*` con `OFFSET/FETCH` y `COUNT(1) OVER()`, con `@tamanoPagina` entre 1 y `GENERAL/TAMANO_PAGINA_MAXIMO` (D.9 lo siembra con 100 si no existe). Ámbito siempre dentro del SP. Sin literales de estado, tipo ni rol: catálogo o parámetro. SP de comando: una fila con la tupla canónica `idCorrelacion, mensajeUsuarioResultado, mensajeTecnicoResultado, estadoResultado` y, detrás, las columnas de datos. Los `*_interno`/`usp_internal_*` nunca reciben `GRANT`.

**Backend:** `Controller → PrimaryPort → UseCaseImpl → SecondaryPort → adaptador` (JPA nativo/`CanonicalStoredProcedureExecutor`; nada de JDBC nuevo). Los mensajes al cliente salen del catálogo (`mensajeUsuario` / `message`); los `*ErrorCode` Java son solo respaldo. Listados en `ApiPageResponse<T>`. Las rutas nuevas entran en `SecurityConfig` y en `infra/security-baseline/access-catalog.json` (§12). Cobertura de JaCoCo sin bajar del gate; los casos de uso nuevos, al 100 % de líneas y ramas.

**Frontend:** componentes standalone con `ChangeDetectionStrategy.OnPush`; solo `input()`/`output()`/`model()`; estado en signals; sin `setInterval` ni polling; sin `bypassSecurityTrust*`; sin calcular identificadores ni reglas de negocio en el cliente (el plazo, la lista blanca y las validaciones vienen del backend); tokens de `styles.css` (`lint:tokens`); móvil 375 × 812 sin scroll horizontal; `PaginationComponent` en listados.

**Pruebas:** RED antes del código, cada prueba falla por la causa esperada. Una prueba existente solo cambia si un cambio de contrato de este documento la invalida; el commit cita la sección.

---

## 2. D.1 — Plazo de excusas (HU026B)

### 2.1 Alcance

La radicación de una solicitud de revisión (excusa) fuera del plazo se rechaza **en el SP**, que es la única regla. El backend solo mapea el error y el frontend muestra la fecha límite que le entrega el backend. También se corrige la fecha de radicación en UTC (F-EST-S16).

### 2.2 BD

| Objeto | Cambio |
| :--- | :--- |
| `DB:schema/functions/ufn_calcular_fecha_limite_justificacion.sql` (**nueva**) | `(@fechaHoraFinSesionUtc DATETIME2(7)) RETURNS DATETIME2(7)`. Lee `N = ufn_obtener_parametro_int(NULL,'ASISTENCIA','DIAS_LIMITE_JUSTIFICACION')` y `@tz = ufn_obtener_parametro_texto(NULL,'TIEMPO','ZONA_HORARIA_SQLSERVER')`. Calcula `fechaLocal = CAST((@fin AT TIME ZONE 'UTC') AT TIME ZONE @tz AS DATE)`; `limiteLocal = DATEADD(DAY, N + 1, fechaLocal)` a las 00:00; devuelve `limiteLocal AT TIME ZONE @tz AT TIME ZONE 'UTC'` como `DATETIME2` (límite **exclusivo**). Devuelve `NULL` si `N` o `@tz` faltan, si `N < 0` o si `@fin IS NULL` |
| `DB:schema/stored-procedures/usp_internal_validar_plazo_justificacion.sql` (**nuevo**) | `(@idSesion UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @fechaLimiteUtc DATETIME2(7) OUTPUT, @mensajeUsuarioResultado NVARCHAR(4000) OUTPUT, @mensajeTecnicoResultado NVARCHAR(4000) OUTPUT, @estadoResultado BIT OUTPUT)`. Lee `Sesion.fechaHoraFin`. Función `NULL` → `REV_025` (configuración ausente). `SYSUTCDATETIME() >= @fechaLimiteUtc` → `REV_020`, con la fecha límite local formateada como parámetro del mensaje. Sin escrituras |
| `usp_radicar_solicitud_revision_asistencia_v2` (LB-004D, **modificado**) | Llama al interno **después** de las validaciones de propiedad y de existencia de la asistencia (una sesión ajena no revela su plazo) y **antes** de cualquier escritura. `SolicitudRevisionAsistencia.fecha` pasa a la fecha local (`CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE)`) en lugar de la fecha UTC (F-EST-S16). Firma y resultset sin cambio |
| `usp_radicar_solicitud_revision_asistencia` (v1, sin consumidor en el backend, **modificado**) | El mismo paso y la misma fecha local (DEC-040 nombra las dos versiones) |
| Lectura de sesiones del estudiante (el SP o la vista que alimenta `GET /estudiante/materias/{materiaId}/sesiones`; el RED lo localiza por nombre y lo cita) | Columnas nuevas al final: `fechaLimiteJustificacionUtc` (de la función) y `plazoJustificacionVigente BIT` (`SYSUTCDATETIME() < fechaLimiteJustificacionUtc`) |
| Mensajes (semilla `41_culm001_d1_mensajes.sql`, MERGE) | `REV_020` usuario: "El plazo para justificar esta inasistencia venció el {}." · técnico: "HU026B: instante {} >= límite {} (ASISTENCIA/DIAS_LIMITE_JUSTIFICACION={})." `REV_025` usuario: "No es posible validar el plazo de justificación en este momento." · técnico: "HU026B: falta ASISTENCIA/DIAS_LIMITE_JUSTIFICACION o TIEMPO/ZONA_HORARIA_SQLSERVER." |
| Parámetros | Ninguno nuevo: `ASISTENCIA/DIAS_LIMITE_JUSTIFICACION = 5` ya existe (`03_parametro.sql`). D.3 lo hace editable en [1, 30] |
| Permisos | Ninguno nuevo (los SP públicos ya tienen `GRANT`; la función la usan SP y vistas) |
| Migración `DB:migrations/20_culm001_d1_plazo_justificacion_up.sql` / `_down.sql` | `up`: `CREATE OR ALTER` de la función, el interno, v1, v2 y la lectura de sesiones; MERGE de los mensajes. `down`: restaura el texto anterior de v1, v2 y la lectura (copiado literal), hace `DROP` del interno y de la función y borra `REV_020`/`REV_025`. `@@TRANCOUNT = 0` al final |
| Manifiesto | `DB_LB004D_SUPPORT_BINDING_MANIFEST.sha256`: se regenera la línea de v2 (precedente DEC-036; decisión del orquestador registrada en `DECISIONES.md`) |

**Pruebas RED** `DB:test/test_culm001_d1_plazo_justificacion.sql`. Las sesiones se construyen relativas a `SYSUTCDATETIME()` en hora local, porque la hora del servidor no se puede simular.

| ID | Caso | Esperado |
| :--- | :--- | :--- |
| D1-01 | Falta en una sesión que terminó hace 2 días | `estadoResultado = 1`; solicitud creada |
| D1-02 | Sesión cuyo día local `+N` es hoy | Se admite (último día completo) |
| D1-03 | Sesión cuyo día local `+N+1` ya empezó | `REV_020`; 0 filas nuevas en `SolicitudRevisionAsistencia`; ningún `ArchivoSoporte` pasa a `ATTACHED`; `@@TRANCOUNT = 0` |
| D1-04 | Con el parámetro en 1 dentro de la transacción de prueba | El límite cambia en consecuencia (sin caché en la BD) |
| D1-05 | v1 con una sesión vencida | `REV_020` |
| D1-06 | Sesión de otro estudiante y vencida | Error de propiedad existente, **no** `REV_020` |
| D1-07 | Función con fin a las 23:30 locales y N = 5 | Límite = medianoche local del día +6 |
| D1-08 | Parámetro ausente (borrado en la transacción de prueba) | `REV_025`, sin escritura |
| D1-09 | Fecha de radicación | `fecha` = fecha local de Bogotá |
| D1-10 | Lectura de sesiones del estudiante | Expone las dos columnas con los valores de la función |
| D1-11 | `up → down → up` de la migración 20 | Idempotente, sin error |

### 2.3 Backend

- `REV_020` → 409 `ERR_PLAZO_JUSTIFICACION_VENCIDO`; `REV_025` → 500 `ERR_CONFIGURACION_PLAZO_JUSTIFICACION` (se mapean en el clasificador de errores del adaptador). **Java no recalcula el plazo**: la fila del catálogo que decía "regla en `SolicitarRevisionAsistenciaUseCase`" se corrige.
- `GET /api/v1/estudiante/materias/{materiaId}/sesiones` (ESTUDIANTE): cada sesión añade `fechaLimiteJustificacionUtc` (ISO-8601 UTC, puede ser `null`) y `plazoJustificacionVigente` (boolean). Proyección, mapper y DTO.
- Pruebas RED: `SolicitarRevisionAsistenciaUseCaseImplTest` (el `REV_020` del puerto llega como `ConflictException` con el mensaje del catálogo), `AsistenciaControllerTest` (`POST /asistencias/revisiones` → 409 con `code` y `message`), prueba del mapper de sesiones del estudiante (campos nuevos y `null`), prueba de contrato SP (columnas nuevas al final).

### 2.4 Frontend

- `FE:features/student/student-courses/components/student-claim-form.component.ts`: muestra "Puedes justificar hasta el <fecha y hora local>" (formateado con `core/time`) a partir de `fechaLimiteJustificacionUtc`. Si llega un 409, muestra el `message` del backend y desactiva "Enviar".
- En la lista de sesiones del detalle de la materia, la acción "Justificar" se desactiva si `plazoJustificacionVigente === false` y muestra el texto "Plazo vencido" con la fecha. El cliente no calcula nada.
- Specs RED: `student-claim-form.component.spec.ts` (fecha visible, 409 con el mensaje del backend, sin cálculo local); spec del detalle (acción desactivada); móvil 375 px: fecha en una línea propia sin desbordar.

### 2.5 Docs y riesgos

- `HU-CATALOG.md`: HU026B pasa a implementada, a certificar en la Fase 3. `FINDINGS.md`: F-EST-008 y F-EST-S16 → `corregido`.
- **Riesgos:** (1) un reclamo radicado justo en el límite: la comparación `<` con `SYSUTCDATETIME()` es determinista, y el SP es la única fuente. (2) Las filas antiguas conservan `fecha` en UTC (sin migración de datos): se documenta en el addendum. (3) Un cambio del parámetro aplica de inmediato a radicaciones nuevas, no a las ya radicadas.

---

## 3. D.2 — Varios soportes por reclamo, categoría persistida y soporte obligatorio (HU015, HU014, LB-004D/TD-060)

### 3.1 Alcance

Un reclamo admite de 0 a `ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO` soportes. La subida sigue siendo una por archivo por `POST /api/v1/archivos/subir` (ClamAV `INSTREAM` → MinIO → `usp_registrar_archivo_soporte`, estado `DRAFT`), y la descarga sigue siendo por `GET /api/v1/archivos/{fileId}` con `usp_consultar_archivo_soporte_autorizado`. La categoría elegida se guarda con FK (TD-060). Las categorías MED, ACA y LAB exigen al menos un soporte (mapeo aprobado por John el 2026-11-05). HU014 se cubre con MED en el mismo formulario.

### 3.2 BD

**DDL** (scripts idempotentes; las FK en `zz_foreign_keys.sql`):

```sql
-- SolicitudRevisionAsistencia.sql (no está en ningún manifiesto)
IF COL_LENGTH('dbo.SolicitudRevisionAsistencia','categoriaJustificacion') IS NULL
    ALTER TABLE dbo.SolicitudRevisionAsistencia ADD [categoriaJustificacion] uniqueidentifier NULL;   -- sin backfill: el texto no se guardó
-- zz_foreign_keys.sql
FK_SolicitudRevisionAsistencia_CategoriaJustificacion (categoriaJustificacion) → CategoriaJustificacion(id)
IX_SolicitudRevisionAsistencia_Categoria (categoriaJustificacion)
-- CategoriaJustificacion.sql
IF COL_LENGTH('dbo.CategoriaJustificacion','requiereSoporte') IS NULL
    ALTER TABLE dbo.CategoriaJustificacion ADD [requiereSoporte] bit NOT NULL
        CONSTRAINT DF_CategoriaJustificacion_requiereSoporte DEFAULT 0;
-- ArchivoSoporte.sql (LB-004D) — [SUPUESTO-D-02]
DROP INDEX IF EXISTS UX_ArchivoSoporte_Solicitud ON dbo.ArchivoSoporte;
CREATE NONCLUSTERED INDEX IX_ArchivoSoporte_Solicitud ON dbo.ArchivoSoporte (solicitudRevisionAsistencia)
    INCLUDE (estado, nombreOriginal, tipoContenido, tamanioBytes, fechaAdjuncionUtc);   -- no filtrado (TD-059)
```

**Vistas:** `uv_soporte_reclamo` (`idSolicitud, idArchivo, nombreOriginal, tipoContenido, tamanioBytes, fechaAdjuncionUtc, orden = ROW_NUMBER() OVER (PARTITION BY solicitud ORDER BY fechaAdjuncionUtc, id)`; solo estado = `ARCHIVO/ESTADO_ADJUNTO`). `uv_categoria_justificacion` añade `requiereSoporte`. `uv_solicitud_revision_asistencia` añade `idCategoriaJustificacion, codigoCategoria, nombreCategoria, totalSoportes`.

**SP:**

| SP | Firma / regla |
| :--- | :--- |
| `usp_radicar_solicitud_revision_asistencia_v3` (**nuevo**, comando) | `(@idEstudiante, @idSesion, @categoria NVARCHAR(50), @justificacion NVARCHAR(MAX), @idsArchivoSoporte NVARCHAR(MAX) = NULL /* JSON ["guid",...] */, @idCorrelacion, @idUsuarioEjecutor)`. Orden: correlación → RBAC ESTUDIANTE → propiedad y asistencia (como v2) → `usp_internal_validar_plazo_justificacion` (D.1) → categoría por `codigo` o por `nombre` (transición; inexistente → `REV_021`) → JSON válido, GUIDs distintos (`REV_024`), cantidad ≤ `ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO` (`REV_023`) → `requiereSoporte = 1` sin soportes → `REV_022` → cada archivo bloqueado `WITH (UPDLOCK, HOLDLOCK)` **en orden de `id`** (sin ciclos): dueño = ejecutor y estado = `ARCHIVO/ESTADO_BORRADOR` (parámetro nuevo `DRAFT`), si no, `ARC_001`/`ARC_00x` existentes → `INSERT SolicitudRevisionAsistencia` (con `categoriaJustificacion` y la `fecha` local de D.1) → `UPDATE ArchivoSoporte SET estado = ARCHIVO/ESTADO_ADJUNTO, solicitudRevisionAsistencia, fechaAdjuncionUtc, idCorrelacionAdjuncion` para todos → verificación de que se adjuntaron N. Salida: tupla + `idSolicitudRevision, totalSoportes` |
| `usp_radicar_solicitud_revision_asistencia_v2` (LB-004D, **modificado**) | Envoltorio: arma `["@idArchivoSoporte"]` (o `NULL`) y delega en v3. Firma y resultset sin cambio. Ahora guarda la categoría y exige soporte según la categoría |
| `usp_consultar_solicitudes_revision_docente` (R2, LB-004D, **modificado**) | Columnas al final: `codigoCategoria, nombreCategoria, totalSoportes`; el literal `'ATTACHED'` pasa a parámetro (TD-061) |
| `usp_consultar_detalle_solicitud_revision_docente` y `usp_consultar_solicitudes_revision_estudiante` (**modificados**) | Columnas al final: `codigoCategoria, nombreCategoria, soportesJson` (`FOR JSON PATH` sobre `uv_soporte_reclamo`: `idArchivo, nombreOriginal, tipoContenido, tamanioBytes, orden`). El campo de soporte único actual se conserva (primer soporte) por compatibilidad posicional |
| `usp_consultar_archivo_soporte_autorizado` (LB-004D, **modificado**) | Solo TD-061: literales `'ATTACHED'`/`'DRAFT'` → parámetros. La autorización por archivo ya funciona con N (resuelve la solicitud del archivo) |
| `usp_consultar_configuracion_reclamos` (**nuevo**, consulta) | Sin paginación, una fila: `maximoSoportes, tamanioMaximoBytes, tiposPermitidos, diasLimiteJustificacion`; RBAC ESTUDIANTE o DOCENTE |

**Parámetros** (semilla `42_culm001_d2_parametros.sql`, patrón `29_*`, sin pisar `valor`): `ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO = 3 (INT)`, `ARCHIVO/ESTADO_BORRADOR = DRAFT (STRING)`. Si existe `CatalogoParametroEdicion` (D.3), la misma semilla inserta la fila de edición de `MAXIMO_SOPORTES_POR_RECLAMO` (editable, [1, 10]).
**Semilla de categorías** `42_culm001_d2_categoria_soporte.sql`: `requiereSoporte = 1` para MED, ACA y LAB (por `codigo`).
**Mensajes** (`42_culm001_d2_mensajes.sql`): `REV_021` "La categoría de justificación no es válida." · `REV_022` "La categoría «{}» exige adjuntar al menos un soporte." · `REV_023` "Puedes adjuntar como máximo {} soportes." · `REV_024` "Un mismo soporte no se puede adjuntar dos veces." (con sus técnicos).
**Permisos** `DB:schema/security/rol_asistencias_runtime_culm001_d2.sql`: `GRANT EXECUTE` a `usp_radicar_solicitud_revision_asistencia_v3` y `usp_consultar_configuracion_reclamos`; `GRANT SELECT` a `uv_soporte_reclamo` si el bucle de `rol_asistencias_runtime.sql` no la cubre (se verifica en `test_public_objects.sql`).
**Migración** `21_culm001_d2_soportes_categoria_up/down.sql`. `up`: columnas, FK, índice nuevo, `DROP` del filtrado, vistas, SP, semillas. `down`: aborta (`THROW 50021`) si alguna solicitud tiene más de un `ATTACHED` y no se pasó `:setvar CONFIRMAR_COLAPSO_SOPORTES 1`; con confirmación deja `ATTACHED` el soporte de menor `fechaAdjuncionUtc` y pasa los demás a `ORPHAN` (cumple `CK_ArchivoSoporte_EstadoVinculo`); recrea `UX_ArchivoSoporte_Solicitud`, quita FK/columna/índice de categoría y `requiereSoporte`, restaura el texto anterior de los SP y vistas (literal) y hace `DROP` de v3, de la configuración y de la vista.
**Manifiesto LB-004D:** se regenera una sola vez en el commit de contrato de D.2 (`ArchivoSoporte.sql`, v2, `usp_consultar_archivo_soporte_autorizado`, R2, `test_lb004d_support_binding.sql`, `test_lb004d_concurrency.ps1`). Exige una decisión del orquestador en `DECISIONES.md` (el dueño de LB-004D es José Alejandro; precedente DEC-036).

**Pruebas RED** `DB:test/test_culm001_d2_soportes_categoria.sql` (+ `test_lb004d_concurrency.ps1` ampliado):

| ID | Caso | Esperado |
| :--- | :--- | :--- |
| D2-01 | v3 con 3 soportes `DRAFT` propios, categoría CAL | 3 `ATTACHED` con la misma solicitud; `totalSoportes = 3` |
| D2-02 | 4 soportes con máximo 3 | `REV_023`; 0 escrituras |
| D2-03 | GUID repetido | `REV_024` |
| D2-04 | Soporte de otro usuario / ya `ATTACHED` | `ARC_00x` existente / `ARC_001`; 0 escrituras |
| D2-05 | MED, ACA o LAB sin soportes | `REV_022`; CAL, FMA y OTR sin soportes → éxito |
| D2-06 | Categoría por `codigo` y por `nombre` | Persistida con la misma FK |
| D2-07 | Categoría inexistente | `REV_021` |
| D2-08 | v2 (envoltorio) con un soporte y categoría MED | Igual que v3 con un soporte; categoría guardada |
| D2-09 | Descarga autorizada de cada uno de los N | Estudiante dueño y docente titular sí; otro docente y otro estudiante no |
| D2-10 | R2, detalle y lista del estudiante | Categoría, `totalSoportes` y `soportesJson` correctos; sin literales `ATTACHED`/`DRAFT` en los 3 SP de TD-061 (búsqueda en `sys.sql_modules`) |
| D2-11 | Dos radicaciones concurrentes con el mismo `fileId` | Una adjunta, la otra `ARC_001`; sin deadlock |
| D2-12 | Plazo vencido con soportes | `REV_020`; los soportes siguen en `DRAFT` |
| D2-13 | `up → down (con confirmación) → up` | Idempotente; el `down` sin confirmación aborta con 2 soportes |

**Comprobación de TD-059 (no es prueba del gate):** con el índice filtrado retirado, `BEGIN TRAN; DELETE FROM dbo.SolicitudRevisionAsistencia WHERE id = @x; ROLLBACK;` con la FK habilitada. Si funciona, entra como prueba `D2-14` y TD-059 se cierra; si no, TD-059 sigue abierta con la evidencia.

**Pruebas existentes que cambian por contrato:** `test_lb004d_support_binding.sql` (la aserción "a lo sumo un soporte por solicitud" pasa a "a lo sumo `MAXIMO_SOPORTES_POR_RECLAMO`"; [SUPUESTO-D-02]); las pruebas de BD, backend y E2E que radican sin archivo con MED pasan a CAL (lo prevé `DISENO_CAMBIO_COORDINADO.md` §3).

### 3.3 Backend

| Endpoint | Cambio |
| :--- | :--- |
| `POST /api/v1/asistencias/revisiones` (ESTUDIANTE) | Cuerpo: `categoria` (código o nombre), `justificacion`, `soporteArchivoIds: UUID[]` (nuevo, 0..N). `soporteArchivoId` (legado) sigue aceptándose como lista de uno; los dos a la vez → 400 `FIELD_INVALID`. Respuesta 202 sin cambio. Errores: 400 (`REV_021`, `REV_022`, `REV_023`, `REV_024`), 409 (`REV_020`, `ARC_001`) |
| `GET /api/v1/configuracion/reclamos` (**nuevo**; ESTUDIANTE, DOCENTE) | `ApiDataResponse<ConfiguracionReclamosDTO>{maximoSoportes, tamanioMaximoBytes, tiposPermitidos[], diasLimiteJustificacion}` |
| `GET /api/v1/categorias-justificacion` | Cada categoría añade `requiereSoporte` |
| Detalle del reclamo del docente (HU036) y `GET /api/v1/estudiante/reclamos` | Añaden `categoria {codigo, nombre}` y `soportes[{fileId, nombre, tipoContenido, tamanioBytes}]`; el campo de soporte único queda como `@Deprecated` (primer soporte) durante una versión |

Capas: `SolicitarRevisionAsistenciaDTO`/`RepositoryDTO` pasan a `List<UUID> soportes`; el adaptador llama a v3 con el JSON (`ObjectMapper`, nunca concatenación); `ConsultarConfiguracionReclamosInputPort` + caso de uso + puerto `ConfiguracionReclamosQueryPort` + adaptador JPA nativo.
Pruebas RED: validador de la petición (legado y lista; los dos a la vez → 400), caso de uso (lista vacía, N, mapeo de los 6 códigos), adaptador (JSON con N GUID, contrato posicional de v3), mappers del docente y del estudiante (`soportesJson` vacío o con N), controlador de configuración (200 y 403 para COORDINADOR), `SqlStoredProcedureContractIT` (v3 y configuración).

### 3.4 Frontend

- `student-claim-form`: varios adjuntos (`archivos = input<SoporteAdjuntoItem[]>()`, salidas `adjuntar`/`quitar`); límite y tipos desde `GET /configuracion/reclamos`; marca "Soporte obligatorio" cuando la categoría elegida tiene `requiereSoporte`; la ayuda de MED sale de la `descripcion` de la categoría (HU014, sin formulario aparte); "Enviar" desactivado mientras haya subidas en curso o falte un soporte obligatorio. La regla definitiva la aplica el backend (el 400 se muestra con su `message`).
- El contenedor (`student-courses`) sube cada archivo por el servicio actual y envía `soporteArchivoIds`.
- Docente (`teacher-claims`, detalle): categoría y lista de soportes, cada uno con su descarga por la API.
- Specs RED: varios adjuntos, quitar, límite, obligatorio por categoría, envío con la lista, 400 del backend visible, detalle del docente con N soportes; móvil 375 px (lista de adjuntos en columna, botones de 44 px).

### 3.5 Docs y riesgos

- `HU-CATALOG.md`: HU015 y HU014 implementadas. `TECHNICAL_DEBT.md` de Backend: TD-060 y TD-061 → CERRADAS; TD-059 según la comprobación. DB: `DB_DEVELOP_FREEZE_ADDENDUM.md` sin cambio; documentos derivados de LB-004D actualizados.
- **Riesgos:** (1) regenerar el manifiesto LB-004D sin el dueño → decisión del orquestador registrada antes del GREEN. (2) Archivos `DRAFT` huérfanos si el estudiante abandona el formulario: ya existe el estado `ORPHAN`; su limpieza no entra en D. (3) Contrato posicional de R2: columnas solo al final y prueba de contrato.

---

## 4. D.3 — Parámetros editables (HU168)

### 4.1 Alcance

El administrador ve los parámetros de negocio con etiqueta, descripción, unidad y rango, agrupados y filtrables, y edita solo los de la lista blanca, con validación de tipo, rango y reglas cruzadas, motivo, concurrencia optimista, auditoría e invalidación de la caché. `RED/*` y `TIEMPO/*` nunca son editables.

### 4.2 BD

**Tablas nuevas** (DDL con `IF OBJECT_ID … IS NULL`; FK en `zz_foreign_keys.sql`):

```sql
CREATE TABLE dbo.CatalogoParametroEdicion (            -- [SUPUESTO-D-03], 1:1 con CatalogoParametro
    parametro                 uniqueidentifier NOT NULL CONSTRAINT PK_CatalogoParametroEdicion PRIMARY KEY,  -- FK → CatalogoParametro(id)
    esEditable                bit              NOT NULL CONSTRAINT DF_CPE_esEditable DEFAULT 0,
    valorMinimo               decimal(19,4)    NULL,
    valorMaximo               decimal(19,4)    NULL,
    valoresPermitidos         nvarchar(500)    NULL,    -- lista separada por comas (BOOLEAN/STRING enumerados)
    parametroDebeSerMenorQue  uniqueidentifier NULL,    -- FK → CatalogoParametro(id): regla cruzada estricta
    etiqueta                  nvarchar(120)    NOT NULL,
    descripcion               nvarchar(500)    NOT NULL,
    unidad                    nvarchar(30)     NULL,
    categoriaVisual           nvarchar(60)     NOT NULL,
    orden                     smallint         NOT NULL CONSTRAINT DF_CPE_orden DEFAULT 0,
    CONSTRAINT CK_CPE_Rango CHECK (valorMinimo IS NULL OR valorMaximo IS NULL OR valorMinimo <= valorMaximo),
    CONSTRAINT CK_CPE_NoAutoReferencia CHECK (parametroDebeSerMenorQue IS NULL OR parametroDebeSerMenorQue <> parametro)
);
CREATE TABLE dbo.CambioParametro (                     -- [SUPUESTO-D-04]
    id uniqueidentifier NOT NULL CONSTRAINT PK_CambioParametro PRIMARY KEY,
    parametro uniqueidentifier NOT NULL,                -- FK → CatalogoParametro(id)
    valorAnterior nvarchar(4000) NOT NULL, valorNuevo nvarchar(4000) NOT NULL,
    motivo nvarchar(500) NOT NULL, idUsuarioEjecutor uniqueidentifier NOT NULL,
    idCorrelacion uniqueidentifier NOT NULL, fechaCambioUtc datetime2(7) NOT NULL
);
CREATE INDEX IX_CambioParametro_Parametro_Fecha ON dbo.CambioParametro (parametro, fechaCambioUtc DESC);
```

**Funciones / SP / vistas:**

| Objeto | Definición |
| :--- | :--- |
| `ufn_validar_valor_parametro(@tipoDato VARCHAR(20), @valor NVARCHAR(4000), @min DECIMAL(19,4), @max DECIMAL(19,4), @permitidos NVARCHAR(500)) RETURNS VARCHAR(20)` | Devuelve el código de mensaje del primer incumplimiento o `NULL`. `INT`: `TRY_CONVERT(INT)` no nulo y sin parte decimal → si no, `PRM_004`. `DECIMAL`: `TRY_CONVERT(DECIMAL(19,4))` → `PRM_004`. `BOOLEAN`: está en `valoresPermitidos` (`true,false`) → `PRM_006`. `STRING`/`NVARCHAR`: longitud 1–4000 y, si hay `valoresPermitidos`, pertenencia exacta → `PRM_006`. Numéricos fuera de `[min, max]` → `PRM_005`. Los nombres de tipo se comparan contra los valores que ya usa `CatalogoParametro.tipoDato`, leídos del parámetro `PARAMETROS/TIPOS_NUMERICOS` (`INT,DECIMAL`), no quemados |
| `uv_parametro_edicion` | `uv_parametro` LEFT JOIN `CatalogoParametroEdicion` + último cambio (`OUTER APPLY TOP 1` de `CambioParametro` + `uv_usuario.nombreCompleto`): `id, grupo, clave, valor, valorDefecto, tipoDato, esEditable (0 si no hay fila), valorMinimo, valorMaximo, valoresPermitidos, etiqueta (clave si no hay fila), descripcion, unidad, categoriaVisual, orden, fechaModificacion, fechaUltimoCambioUtc, nombreUltimoActor, esGrupoProtegido` (`esGrupoProtegido` = el grupo está en `PARAMETROS/GRUPOS_NO_EDITABLES`) |
| `usp_consultar_parametros_paginado` (consulta) | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @grupo VARCHAR(100) = NULL, @texto NVARCHAR(100) = NULL, @soloEditables BIT = 1)`; RBAC ADMINISTRADOR; filtro de texto por `clave`, `etiqueta` y `descripcion`; orden `categoriaVisual, orden, clave`. Con `@soloEditables = 1` no aparecen las constantes técnicas (F-ADM-012) |
| `usp_actualizar_parametro` (comando) | `(@idParametro UNIQUEIDENTIFIER, @valor NVARCHAR(4000), @fechaModificacionEsperada DATETIME, @motivo NVARCHAR(500), @idCorrelacion, @idUsuarioEjecutor)`. Pasos: correlación → RBAC ADMINISTRADOR → motivo con 10–500 caracteres tras `TRIM` (`PRM_009`) → `CatalogoParametro WITH (UPDLOCK, HOLDLOCK)` por id, activo (`PRM_002`) → grupo protegido o sin fila editable (`PRM_003`; doble defensa: la bandera nunca basta para `RED/*`/`TIEMPO/*`) → `fechaModificacion <> @fechaModificacionEsperada` (`PRM_008`) → `ufn_validar_valor_parametro` → reglas cruzadas: si tiene `parametroDebeSerMenorQue`, `valorNuevo < valor del otro`; y para toda fila que lo apunte, `valor de esa fila < valorNuevo` (`PRM_007`, con las dos claves en el mensaje) → valor igual al actual: `PRM_011` (éxito sin escritura) → `UPDATE valor, fechaModificacion = SYSUTCDATETIME()` + `INSERT CambioParametro`. Salida: tupla + `idParametro, grupo, clave, valorAnterior, valorNuevo, fechaModificacion` |
| `usp_consultar_cambios_parametro_paginado` (consulta, diferible) | `(@idUsuarioEjecutor, @idCorrelacion, @idParametro, @numeroPagina, @tamanoPagina)`: `fechaCambioUtc, valorAnterior, valorNuevo, motivo, nombreActor, idCorrelacion` |

**Lista blanca inicial** (semilla `43_culm001_d3_parametro_edicion.sql`, MERGE por `(grupo, clave)` contra `CatalogoParametro`; solo inserta filas de parámetros que existen, para no depender del orden de mezcla de B.2, D.2 o D.5). Columnas: clave · tipo · editable · rango o valores · unidad · regla cruzada.

| Grupo / clave | Tipo | Editable | Rango / valores | Unidad | Nota |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ASISTENCIA/TOLERANCIA_MINUTOS | INT | sí | [0, 60] | minutos | Ventana de toma (DEC-014) |
| ASISTENCIA/MARGEN_RETARDO_MINUTOS | INT | sí | [0, 120] | minutos | |
| ASISTENCIA/DIAS_LIMITE_JUSTIFICACION | INT | sí | [1, 30] | días | D.1 |
| ASISTENCIA/UMBRAL_ALERTA_ADVERTENCIA | DECIMAL | sí | [1, 99] | % | `< UMBRAL_ALERTA_PERDIDA` |
| ASISTENCIA/UMBRAL_ALERTA_PERDIDA | DECIMAL | sí | [1, 100] | % | |
| ASISTENCIA/CODIGO_RAZON_* (B.2) | STRING | **no** | — | — | Constantes técnicas |
| MATRICULA_QR/ROTACION_SEGUNDOS | INT | sí | [15, 300] | segundos | |
| MATRICULA_QR/TOLERANCIA_SEGUNDOS | INT | sí | [0, 300] | segundos | |
| MATRICULA_QR/DURACION_MAXIMA_MINUTOS | INT | sí | [5, 240] | minutos | |
| MATRICULA_QR/HABILITADA | BOOLEAN | sí | true,false | — | |
| MATRICULA_QR/LIMITE_IP_POR_MINUTO | INT | sí | [5, 1000] | intentos/min | |
| MATRICULA_QR/LIMITE_REGISTROS_TOKEN_POR_MINUTO | INT | sí | [1, 200] | registros/min | |
| MATRICULA_QR/ESTADO_*, LOTE_ROTACION | — | **no** | — | — | Constantes técnicas |
| MATRICULA_QR/URL_BASE_FRONTEND, ASISTENCIA_QR/URL_BASE_FRONTEND | STRING | **no** | — | — | Configuración de despliegue (evita redirecciones a otro dominio) |
| ASISTENCIA_QR/HABILITADA | BOOLEAN | sí | true,false | — | |
| ASISTENCIA_QR/ROTACION_SEGUNDOS | INT | sí | [15, 300] | segundos | |
| ASISTENCIA_QR/TOLERANCIA_SEGUNDOS | INT | sí | [0, 300] | segundos | |
| ASISTENCIA_QR/LIMITE_IP_POR_MINUTO (A) | INT | sí | [5, 1000] | intentos/min | |
| ASISTENCIA_QR/LIMITE_FALLIDOS_IP_POR_MINUTO (B.2) | INT | sí | [50, 5000] | intentos/min | |
| ASISTENCIA_QR/LIMITE_TOKEN_POR_MINUTO (B.2) | INT | sí | [10, 2000] | registros/min | |
| ASISTENCIA_QR/LIMITE_ESTUDIANTE_POR_MINUTO | INT | sí | [1, 60] | intentos/min | |
| ASISTENCIA_QR/LOTE_ROTACION | INT | **no** | — | — | Técnico |
| FESTIVOS/HABILITADO | BOOLEAN | sí | true,false | — | |
| FESTIVOS/PROVEEDOR_PRINCIPAL | STRING | sí | CALENDARIOS_NACIONALES,FERIADOS_IO,CALCULO_LOCAL | — | |
| FESTIVOS/TIMEOUT_SEGUNDOS | INT | sí | [1, 60] | segundos | |
| FESTIVOS/ANIOS_ADELANTE | INT | sí | [0, 3] | años | |
| FESTIVOS/MINIMO_POR_ANIO | INT | sí | [10, 30] | festivos | `< MAXIMO_POR_ANIO` |
| FESTIVOS/MAXIMO_POR_ANIO | INT | sí | [10, 40] | festivos | |
| FESTIVOS/URL_*, NOMBRE_SECRETO_*, FUENTES_VALIDAS, ORDEN_RESPALDO, ANIO_MINIMO, ANIO_MAXIMO, PREFIJO_MOTIVO_CANCELACION, ATRIBUCION_* | — | **no** | — | — | URLs y secretos (riesgo de SSRF), constantes, atribución legal |
| ARCHIVO/TAMANIO_MAXIMO_BYTES | INT | sí | [262144, 5242880] | bytes | El máximo no supera el límite multipart actual del backend |
| ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO | INT | sí | [1, 60] | subidas/min | |
| ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO (D.2) | INT | sí | [1, 10] | soportes | Lo inserta la semilla 42 |
| ARCHIVO/ESTADO_* | — | **no** | — | — | Técnico |
| CARGA_MASIVA/MAXIMO_FILAS, LIMITE_POR_MINUTO, TAMANIO_MAXIMO_BYTES (D.5) | INT | sí | [1, 500] · [1, 20] · [10240, 2097152] | filas · cargas/min · bytes | Ampliación pedida por D.5 ("límite de filas por parámetro"); los inserta la semilla 45 |
| `RED/*`, `TIEMPO/*`, `GENERAL/*`, `REGISTRO/*`, `IDENTIDAD/*`, `RECLAMO/*`, `TOMA_ASISTENCIA/*`, `PARAMETROS/*`, `AUDITORIA/*` | — | **nunca** | — | — | `PARAMETROS/GRUPOS_NO_EDITABLES = RED,TIEMPO,GENERAL,PARAMETROS` |

**Parámetros** (`43_culm001_d3_parametros.sql`): `PARAMETROS/GRUPOS_NO_EDITABLES` (STRING), `PARAMETROS/TIPOS_NUMERICOS = INT,DECIMAL` (STRING), `PARAMETROS/LONGITUD_MINIMA_MOTIVO = 10` (INT). Ninguno es editable.
**Mensajes** (`43_culm001_d3_mensajes.sql`): `PRM_001` "Parámetro actualizado." · `PRM_002` "El parámetro no existe." (404) · `PRM_003` "Este parámetro no se puede editar." (403) · `PRM_004` "El valor debe ser de tipo {}." (400) · `PRM_005` "El valor debe estar entre {} y {}." (400) · `PRM_006` "El valor debe ser uno de: {}." (400) · `PRM_007` "«{}» debe ser menor que «{}»." (400) · `PRM_008` "Otro usuario modificó el parámetro. Recarga y vuelve a intentarlo." (409) · `PRM_009` "Indica un motivo de al menos {} caracteres." (400) · `PRM_010` "La edición de parámetros no está disponible con el catálogo de configuración activo." (409, backend) · `PRM_011` "El valor no cambió." (200).
**Permisos** `rol_asistencias_runtime_culm001_d3.sql`: `usp_consultar_parametros_paginado`, `usp_actualizar_parametro`, `usp_consultar_cambios_parametro_paginado`.
**Migración** `22_culm001_d3_parametros_editables_up/down.sql`: tablas, FK, vista, función, SP y semillas / `DROP` en orden inverso (los valores de `CatalogoParametro` cambiados por el administrador se conservan; `CambioParametro` se exporta a `zz_archivo_CambioParametro_culm001_d3` antes del `DROP`, patrón DEC-010).

**Pruebas RED** `DB:test/test_culm001_d3_parametros.sql`:

| ID | Caso | Esperado |
| :--- | :--- | :--- |
| D3-01 | Cambio válido de `DIAS_LIMITE_JUSTIFICACION` a 7 | `PRM_001`; `valor = 7`; 1 fila en `CambioParametro` con anterior y nuevo; `fechaModificacion` avanza |
| D3-02 | `RED/CIDRS_CAMPUS`, aunque se fuerce `esEditable = 1` en la prueba | `PRM_003`; sin escritura |
| D3-03 | `TIEMPO/*` y un parámetro sin fila de edición | `PRM_003` |
| D3-04 | `"abc"` en INT, `"7.5"` en INT, `"x"` en DECIMAL | `PRM_004` |
| D3-05 | 0 y 31 en `DIAS_LIMITE_JUSTIFICACION` | `PRM_005` con los límites |
| D3-06 | `"si"` en BOOLEAN, proveedor inexistente | `PRM_006` |
| D3-07 | Advertencia 20 con pérdida 20; pérdida 14 con advertencia 15 | `PRM_007` en las dos direcciones |
| D3-08 | `fechaModificacionEsperada` antigua | `PRM_008`; sin escritura |
| D3-09 | Dos `UPDATE` concurrentes con la misma versión (`test_culm001_d3_concurrencia.ps1`) | Uno `PRM_001` y otro `PRM_008`; 1 fila de historial |
| D3-10 | Motivo vacío o de 5 caracteres | `PRM_009` |
| D3-11 | Valor igual al actual | `PRM_011`; sin historial |
| D3-12 | Perfil COORDINADOR | Error de RBAC; sin escritura |
| D3-13 | Consulta con `@soloEditables = 1` | Sin constantes técnicas (`GENERAL/*`, `*/ESTADO_*`) y sin `RED/*`/`TIEMPO/*`; `@tamanoPagina` 0 o mayor que el máximo → error |
| D3-14 | Efecto inmediato en un SP | Tras cambiar `DIAS_LIMITE_JUSTIFICACION`, `ufn_calcular_fecha_limite_justificacion` usa el valor nuevo |
| D3-15 | Lista blanca sembrada | Ninguna fila `esEditable = 1` cuyo grupo esté en `GRUPOS_NO_EDITABLES`; todas las editables numéricas con rango |
| D3-16 | `up → down → up` | Idempotente |

### 4.3 Backend

| Endpoint | Rol | Petición / respuesta |
| :--- | :--- | :--- |
| `GET /api/v1/admin/parametros?grupo&texto&soloEditables=true&pagina=1&tamano=20` (cambia de `ApiListResponse` a `ApiPageResponse`) | ADMINISTRADOR | `ApiPageResponse<ParametroAdminDTO>{id, grupo, clave, valor, valorDefecto, tipoDato, esEditable, valorMinimo, valorMaximo, valoresPermitidos[], etiqueta, descripcion, unidad, categoriaVisual, orden, fechaModificacion, fechaUltimoCambioUtc, nombreUltimoActor}` |
| `PUT /api/v1/admin/parametros/{id}` (hoy 501) | ADMINISTRADOR | `{valor: string, fechaModificacionEsperada: string ISO-8601, motivo: string}` → 200 `ApiDataResponse<ParametroActualizadoDTO>{id, grupo, clave, valorAnterior, valorNuevo, fechaModificacion, sinCambios}`. 400 (`PRM_004/5/6/7/9`, cuerpo inválido), 403 (`PRM_003`, otro rol), 404 (`PRM_002`), 409 (`PRM_008`, `PRM_010`) |
| `GET /api/v1/admin/parametros/{id}/cambios?pagina&tamano` (nuevo, diferible) | ADMINISTRADOR | `ApiPageResponse<CambioParametroDTO>` |

- **Caso de uso** `ActualizarParametroUseCaseImpl`: valida la forma (no vacío, fecha parseable) → `ParametroEdicionCapacidadPort.admiteEdicion()` (adaptador de infraestructura: `true` solo si `app.adapters.parameter-catalog.provider=sqlserver`; si no, 409 `PRM_010`; [SUPUESTO-D-06]) → `ParametroCommandPort.actualizar(...)` (adaptador JPA nativo que ejecuta `usp_actualizar_parametro`) → si cambió: `CatalogInvalidationPort.invalidateParameter(grupo, clave)` y `RealtimePublisherPort.publish(RealtimeEvent.of("PARAMETER_UPDATED", {grupo, clave}))` con audiencia ADMINISTRADOR (política de audiencia de C; si C no se mezcló, solo se invalida). Un fallo de la publicación no revierte el cambio (se registra con `correlationId`).
- `GET` con `ConsultarParametrosAdminUseCase` sobre `usp_consultar_parametros_paginado`; desaparece la HQL directa sobre `uv_parametro` de `ParametroJpaRepository` (la única lectura administrativa pasa por el SP; `ParameterCatalogJpaRepository` de `provider=sqlserver` no cambia).
- Controlador: `@AuditableOperation(action = "ACTUALIZAR_PARAMETRO", resourceType = "PARAMETRO", resourceIdPathVariable = "id", metadataResponseFields = {"grupo", "clave", "valorAnterior", "valorNuevo"}, metadataRequestFields = {"motivo"})` (D.6).
- Pruebas RED: validador (cuerpo vacío, fecha inválida), caso de uso (proveedor `azure` → `PRM_010` sin llamar al puerto; `sinCambios` → sin invalidar ni publicar; éxito → invalida y publica una vez; publicación que falla → 200), adaptador (mapeo de los 11 códigos a 400/403/404/409), controlador (200, 403 para COORDINADOR, 404, 409), prueba de contrato SP, prueba de auditoría (metadatos con anterior y nuevo).

### 4.4 Frontend

`FE:features/admin/admin-system` (pestaña "Parámetros"): lista paginada agrupada por `categoriaVisual`, buscador y filtro de grupo; cada fila muestra etiqueta, descripción, valor con unidad, rango y "último cambio por <actor> el <fecha>"; sin claves repetidas ni descripción fija (F-ADM-012); interruptor "Mostrar parámetros técnicos (solo lectura)" (`soloEditables=false`). Modal de edición: control según `tipoDato` (número con `min`/`max`, interruptor para BOOLEAN, selector para `valoresPermitidos`), motivo obligatorio y error del backend tal cual; un 409 `PRM_008` recarga el parámetro y avisa. Componente `parametro-edicion-modal` nuevo. Specs RED: agrupación, búsqueda, paginación, control por tipo, envío con `fechaModificacionEsperada`, 400/403/409 visibles, ningún `setInterval`; móvil: tarjetas en una columna y modal a pantalla completa.

### 4.5 Docs y riesgos

- `HU-CATALOG.md`: HU168 implementada. `REALTIME_EVENT_CONTRACT.md` (Infra) y `REALTIME_EVENT_STANDARD.md` (Backend): evento `PARAMETER_UPDATED` (`{grupo, clave}`, audiencia ADMINISTRADOR; es el mismo que ya emite el procesador de eventos de Azure); se regeneran los `.sha256` (diferible, §1.2). `TECHNICAL_DEBT.md`: deuda nueva "la edición en BD no se propaga a Azure App Configuration" ([SUPUESTO-D-06]).
- **Riesgos:** (1) Bajar un umbral no crea ni borra alertas de C de forma retroactiva: C evalúa en el siguiente registro. Se documenta en la ayuda del parámetro. (2) Un límite de QR mal elegido bloquea un salón: los rangos lo acotan y el cambio queda auditado. (3) La caché de otras instancias del backend: hoy hay una sola; con varias, el evento SSE no basta (deuda).

---

## 5. D.4 — Admisión de estudiantes por el administrador (HU156)

### 5.1 Alcance

El administrador crea o corrige estudiantes que no pueden usar el QR, sin matricularlos en grupos ([SUPUESTO-D-07]); después el docente los matricula a mano. La cuenta de identidad se aprovisiona como en HU091/HU117-B/HU120.

### 5.2 BD

| Objeto | Definición |
| :--- | :--- |
| `usp_admitir_estudiante` (**nuevo**, comando) | `(@idTipoIdIdentificacion UNIQUEIDENTIFIER, @numeroIdentificacion INT, @primerNombre NVARCHAR(50), @segundoNombre NVARCHAR(50) = NULL, @primerApellido NVARCHAR(50), @segundoApellido NVARCHAR(50) = NULL, @correo NVARCHAR(100), @password NVARCHAR(500) = NULL /* hash; NULL si la persona ya existe */, @idPrograma UNIQUEIDENTIFIER, @idCorrelacion, @idUsuarioEjecutor)`. Pasos: correlación → RBAC ADMINISTRADOR → programa activo de la institución del administrador (`ADS_003`, sin revelar si existe) → identidad: `usp_validar_unicidad_usuario_interno` (documento y correo de personas distintas → `ADS_004`) → correo institucional para un alta nueva (`ufn_correo_cumple_dominio_institucional`, `REGISTRO/DOMINIO_CORREO_ESTUDIANTE` → `ADS_005`) → `usp_sincronizar_usuario_interno` (si no existe; contraseña obligatoria → `ADS_006`) → `usp_sincronizar_estudiante_interno` (perfil ES + `Estudiante`, idempotente) → `usp_registrar_estudiante_en_programa_interno` (hoy sin consumidor; vínculo `EstudiantePrograma`). Si ya tenía `EstudiantePrograma` activo en ese programa → `ADS_002` (`estadoResultado = 0`; el backend decide 409 o reparación, [SUPUESTO-D-12]). Bloqueos: `Usuario` por documento/correo `UPDLOCK, HOLDLOCK` antes de insertar. Salida: tupla + `idUsuario, idEstudiante, esUsuarioNuevo, esEstudianteNuevo` |
| `usp_corregir_identidad_usuario` (**modificado**) | Para `@tipoUsuario = 'ESTUDIANTE'` admite también el perfil ADMINISTRADOR, con ámbito "estudiante con `EstudiantePrograma` en un programa de la institución del administrador". El perfil requerido por tipo sale de una tabla de reglas o de un parámetro (el `CASE` con literales de perfil se mantiene solo si ya existía; se reemplaza por el parámetro `IDENTIDAD/PERFILES_CORRECCION_ESTUDIANTE = COORDINADOR,ADMINISTRADOR`) |
| `usp_consultar_programas_institucion_paginado` (**nuevo**, consulta) | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @texto = NULL, @idFacultad = NULL)`; RBAC ADMINISTRADOR; programas activos de la institución con su facultad |
| Mensajes (`44_culm001_d4_mensajes.sql`) | `ADS_001` "Estudiante admitido." · `ADS_002` "El estudiante ya está admitido en este programa." · `ADS_003` "El programa no existe o no pertenece a tu institución." · `ADS_004` "El documento y el correo corresponden a personas distintas." · `ADS_005` "El correo debe ser institucional ({})." · `ADS_006` "Indica una contraseña inicial para el estudiante nuevo." |
| Parámetros (`44_culm001_d4_parametros.sql`) | `IDENTIDAD/PERFILES_CORRECCION_ESTUDIANTE` |
| Permisos `rol_asistencias_runtime_culm001_d4.sql` | `usp_admitir_estudiante`, `usp_consultar_programas_institucion_paginado` |
| Migración `23_culm001_d4_admision_estudiantes_up/down.sql` | SP nuevos, SP modificado y semillas / `DROP` y restauración literal de `usp_corregir_identidad_usuario` |

**Pruebas RED** `DB:test/test_culm001_d4_admision.sql`: D4-01 alta nueva (Usuario, perfil ES, Estudiante, EstudiantePrograma; 0 `EstudianteGrupo`) · D4-02 persona existente (docente) con el mismo documento y correo → se le añade el perfil ES sin duplicar el Usuario · D4-03 repetición → `ADS_002` sin filas nuevas · D4-04 documento de una persona y correo de otra → `ADS_004` · D4-05 programa de otra institución → `ADS_003` · D4-06 correo no institucional en un alta nueva → `ADS_005` · D4-07 alta nueva sin contraseña → `ADS_006` · D4-08 COORDINADOR → error de RBAC · D4-09 fallo provocado tras crear el Usuario → sin filas parciales y `@@TRANCOUNT = 0` · D4-10 corrección de identidad por ADMINISTRADOR dentro de su institución → sí, fuera → no · D4-11 consulta de programas: solo los de la institución, paginación · D4-12 `up → down → up`.

### 5.3 Backend

| Endpoint | Rol | Petición / respuesta |
| :--- | :--- | :--- |
| `POST /api/v1/admin/estudiantes/admision` | ADMINISTRADOR | `{idTipoIdentificacion, numeroIdentificacion, primerNombre, segundoNombre?, primerApellido, segundoApellido?, correo, password?, idPrograma}` → 201 `ApiDataResponse<AdmisionEstudianteDTO>{idEstudiante, idUsuario, esUsuarioNuevo, estadoCuenta: ACTIVA \| PENDIENTE_VERIFICACION \| PENDIENTE_SINCRONIZACION, cuentaReparada}`; 400 (validación de campos con `details`, `ADS_005`, `ADS_006`, política de clave), 403 (`ADS_003`, otro rol), 409 (`ADS_002` con cuenta existente, `ADS_004`) |
| `PUT /api/v1/admin/estudiantes/{idEstudiante}/identidad` (diferible) | ADMINISTRADOR | El mismo cuerpo y la misma respuesta que `PUT /coordinador/estudiantes/{id}/identidad` (`CorreccionIdentidadController`, tipo ESTUDIANTE) |
| `GET /api/v1/admin/programas?texto&idFacultad&pagina&tamano` | ADMINISTRADOR | `ApiPageResponse<ProgramaInstitucionDTO>{id, codigo, nombre, idFacultad, nombreFacultad}` |

- **`AdmitirEstudianteUseCaseImpl`** (`BE:application/features/admin/admitirestudiante/`): mismo patrón que `RegistrarEstudianteUseCaseImpl` (conflicto de identidad, IDENT-001 para altas nuevas, `PasswordRegistroRule.resolverCredencialNueva` solo si la persona es nueva, `PasswordEncoderPort`) → `AdmisionEstudianteCommandPort.admitir(...)` → `AsegurarCuentaIdentidadService.asegurar(usuario, InstitutionalRole.ESTUDIANTE)` → aviso IDENT-001 de verificación de correo (mejor esfuerzo, como el alta del docente).
- **`AsegurarCuentaIdentidadService`** (application, POJO cableado con `@Bean`; lo reutilizan D.5 y D.9 F-ADM-024): `crearCuenta` (idempotente según el puerto). Si `IdentityProviderException` → registra el desfase con `UsuarioSincronizacionIdentidadPort` (el mismo de `AccesoCuentaService`) y devuelve `PENDIENTE_SINCRONIZACION`; no lanza 500 (la BD ya confirmó). Con `ADS_002`: `buscarCuentaPorIdUsuario`: si existe → 409; si falta → `crearCuenta` y `cuentaReparada = true` (201); si la capacidad no existe → 409.
- Pruebas RED: caso de uso (nuevo, existente, `ADS_002` con y sin cuenta, IdP caído → `PENDIENTE_SINCRONIZACION` sin excepción, contraseña de una persona existente ignorada), servicio de cuenta (las 4 ramas), validador (campos y `details`), controlador (201/400/403/409), contrato SP, ArchUnit (el caso de uso no importa infraestructura).

### 5.4 Frontend

`FE:features/admin/admin-estudiantes`: botón "Admitir estudiante" y modal `admision-estudiante-modal` (tipo de documento del catálogo, sin GUID quemado; selector de programa con búsqueda en servidor `GET /admin/programas`; contraseña inicial solo si el backend responde que la persona es nueva, es decir, primero se envía sin clave y un 400 `ADS_006` la pide; mensaje del backend tal cual; aviso cuando `estadoCuenta` no es `ACTIVA`). En la ficha del estudiante, la acción "Corregir identidad" reutiliza `shared/components/correccion-identidad-modal`. Specs RED: formulario válido, 400 con `details` por campo, 409, `ADS_006` pide clave, estado de cuenta pendiente visible; móvil: modal a pantalla completa. Se quita la mención "Formulario de admisión en `CoordinatorStudents`" del catálogo.

### 5.5 Docs y riesgos

- `HU-CATALOG.md` HU156 → implementada (SP `usp_admitir_estudiante`, endpoint y pantalla `/app/admin/estudiantes`). `FINDINGS.md` F-ADM-004 → corregido.
- **Riesgos:** (1) Aprovisionamiento parcial (BD sí, IdP no): queda `PENDIENTE_SINCRONIZACION` con el desfase registrado y se repara repitiendo la admisión. (2) `buscarCuentaPorIdUsuario` puede no estar implementada en el adaptador baseline: el RED lo verifica y, si falta, rige la rama "409 sin reparación".

---

## 6. D.5 — Carga masiva CSV de roles no estudiantes (HU171)

### 6.1 Alcance

Cada rol carga cuentas en su ámbito, con la misma jerarquía del alta individual ([SUPUESTO-D-15]): **coordinador → docentes de su programa (HU091), decano → coordinadores de su facultad (HU120), administrador → decanos (HU117-B)**. La matrícula de estudiantes en grupos **no** entra (sigue siendo solo por QR o manual del docente). Flujo: plantilla → validación previa sin crear nada → confirmación → creación fila por fila con el caso de uso individual.

### 6.2 Formato CSV

- **Codificación** UTF-8 (BOM opcional). **Separador** `,` o `;`, detectado en la cabecera (Excel en español usa `;`). Comillas RFC 4180. Fin de línea CRLF o LF. Líneas vacías ignoradas.
- **Cabecera obligatoria** en la primera línea, con los nombres exactos (sin distinguir mayúsculas, sin tildes) y en cualquier orden; columna desconocida o faltante → error de archivo `CMA_004`.
- **Límites (parámetros):** `CARGA_MASIVA/TAMANIO_MAXIMO_BYTES = 1048576`, `CARGA_MASIVA/MAXIMO_FILAS = 100` (editable en [1, 500]); se superan → 400 `CMA_002`/`CMA_001` sin procesar filas. `CARGA_MASIVA/LIMITE_POR_MINUTO = 3` por actor (validaciones y cargas; `SlidingWindowRateLimiter` de B en `infrastructure/ratelimit/`) → 429 `CMA_014`.
- **Número de fila** = número de línea del archivo (la cabecera es la 1), para ubicarla en Excel.
- **Inyección de fórmulas:** una celda que empieza por `=`, `+`, `-`, `@`, tabulador o retorno de carro → `CMA_011` en esa fila. La plantilla no lleva filas de ejemplo.

| Columna | Docentes (coordinador) | Coordinadores (decano) | Decanos (administrador) | Regla |
| :--- | :--- | :--- | :--- | :--- |
| `tipo_documento` | obligatoria | obligatoria | obligatoria | Código de `TipoIdentificacion` (p. ej. `CC`), resuelto en BD (`CMA_006`) |
| `numero_documento` | obligatoria | obligatoria | obligatoria | Entero positivo en el rango `INT` (`CMA_005`) |
| `primer_nombre`, `primer_apellido` | obligatorias | obligatorias | obligatorias | Mismas reglas de los validadores del alta individual |
| `segundo_nombre`, `segundo_apellido` | opcionales | opcionales | opcionales | Ídem |
| `correo` | obligatoria | obligatoria | obligatoria | Formato y dominio que exija el alta individual |
| `clave_inicial` | si es persona nueva | si es persona nueva | si es persona nueva | `PasswordRegistroRule`; se ignora si la persona existe ([SUPUESTO-D-08]) |
| `codigo_tipo_vinculacion` | obligatoria | — | — | Código de `TipoVinculacion` |
| `codigo_programa` | obligatoria solo si el coordinador tiene más de un programa (DEC-021 S4); si tiene uno, vacía o igual | obligatoria (programa de su facultad) | — | Código de programa en el ámbito (`CMA_007`) |
| `codigo_facultad` | — | — | opcional (facultad de su institución) | `CMA_007` |

Plantillas: `plantilla-carga-docentes.csv`, `plantilla-carga-coordinadores.csv`, `plantilla-carga-decanos.csv` (solo la cabecera, separador `;`, con BOM para Excel).

### 6.3 BD

| Objeto | Definición |
| :--- | :--- |
| `JerarquiaAltaUsuario` (**tabla nueva**, catálogo) | `id, perfilEjecutor (FK Perfil), perfilDestino (FK Perfil), UNIQUE (perfilEjecutor, perfilDestino)`; semilla con 3 filas por código de perfil ([SUPUESTO-D-15]); vista `uv_jerarquia_alta_usuario` |
| `usp_validar_carga_masiva_usuarios` (**nuevo**, solo lectura, clasificación `READ_QUERY_RESULTSET`) | `(@idUsuarioEjecutor, @idCorrelacion, @codigoPerfilDestino VARCHAR(20), @filasJson NVARCHAR(MAX))`. `@filasJson` = `[{numeroFila, tipoDocumento, numeroDocumento, correo, codigoTipoVinculacion, codigoPrograma, codigoFacultad}]` (sin nombres ni clave: la forma la valida Java; la BD valida catálogos, ámbito e identidad). Comprueba que `(perfil del ejecutor, destino)` está en `JerarquiaAltaUsuario` (si no, `THROW` con `CMA_009`), con un límite de filas igual al parámetro. Devuelve **una fila por fila de entrada**: `numeroFila, esValida BIT, yaExiste BIT, codigoMensaje (CMA_0xx o NULL), mensajeUsuario, idTipoIdentificacion, idTipoVinculacion, idPrograma, idFacultad, idUsuarioExistente`. Reglas: catálogos (`CMA_006`), ámbito del ejecutor con los internos existentes (`usp_validar_programa_en_facultad_interno`, programas del coordinador, institución del administrador) (`CMA_007`), conflicto documento/correo (`CMA_008`), duplicado dentro del archivo por documento o por correo (`CMA_010`, la segunda aparición), y `yaExiste` según [SUPUESTO-D-11]. No escribe nada (se verifica con conteos antes y después) |
| `usp_crear_coordinador` y `usp_crear_decano` (**modificados**) | Parámetro nuevo `@idTipoIdIdentificacion UNIQUEIDENTIFIER = NULL`. Si es `NULL`, se usa `IDENTIDAD/TIPO_IDENTIFICACION_DEFECTO` (código `CC` sembrado) en lugar del literal `'CC'` actual (líneas 165 y 109): cero datos quemados y paridad con el CSV (también corrige la parte de BD de F-ADM-011) |
| Parámetros (`45_culm001_d5_parametros.sql`) | `CARGA_MASIVA/MAXIMO_FILAS = 100`, `CARGA_MASIVA/TAMANIO_MAXIMO_BYTES = 1048576`, `CARGA_MASIVA/LIMITE_POR_MINUTO = 3`, `IDENTIDAD/TIPO_IDENTIFICACION_DEFECTO = CC`; filas de edición de los tres primeros si existe `CatalogoParametroEdicion` |
| Mensajes (`45_culm001_d5_mensajes.sql`) | `CMA_001` "El archivo supera {} filas." · `CMA_002` "El archivo supera el tamaño permitido." · `CMA_003` "El archivo cambió desde la validación. Valídalo de nuevo." · `CMA_004` "La cabecera no coincide con la plantilla: {}." · `CMA_005` "Número de documento inválido." · `CMA_006` "Código de {} desconocido: {}." · `CMA_007` "«{}» no está en tu ámbito." · `CMA_008` "El documento y el correo corresponden a personas distintas." · `CMA_009` "Tu rol no puede cargar este tipo de cuentas." · `CMA_010` "Fila repetida en el archivo (línea {})." · `CMA_011` "Valor no permitido en la columna {}." · `CMA_012` "Falta la clave inicial para una persona nueva." · `CMA_013` "El archivo no es un CSV UTF-8 válido." · `CMA_014` "Has superado el número de cargas por minuto." · `CMA_015` "Carga procesada: {} creadas, {} ya existentes, {} con error." |
| Permisos `rol_asistencias_runtime_culm001_d5.sql` | `usp_validar_carga_masiva_usuarios` |
| Migración `24_culm001_d5_carga_masiva_up/down.sql` | Tabla, semillas, SP nuevo, firma nueva de los dos SP (el `down` restaura el texto anterior) |

**Pruebas RED** `DB:test/test_culm001_d5_carga_masiva.sql`: D5-01 coordinador con 3 filas válidas → 3 `esValida` y 0 escrituras · D5-02 decano con un programa de otra facultad → `CMA_007` · D5-03 administrador → destino DOCENTE no permitido (`CMA_009`) · D5-04 duplicado por documento y por correo dentro del archivo → `CMA_010` en la segunda aparición · D5-05 persona que ya tiene el rol en el ámbito → `yaExiste = 1` · D5-06 documento y correo de personas distintas → `CMA_008` · D5-07 códigos de catálogo desconocidos → `CMA_006` · D5-08 coordinador de 2 programas sin `codigoPrograma` → `CMA_007` · D5-09 más filas que el parámetro → `THROW` `CMA_001` · D5-10 `usp_crear_coordinador` con `@idTipoIdIdentificacion` → tipo guardado; `NULL` → parámetro (sin literal: búsqueda en `sys.sql_modules`) · D5-11 `up → down → up`.

### 6.4 Backend

| Endpoint | Rol | Petición / respuesta |
| :--- | :--- | :--- |
| `GET /api/v1/{coordinador\|decano\|admin}/cargas/plantilla` | COORDINADOR / DECANO / ADMINISTRADOR | `text/csv; charset=UTF-8`, `Content-Disposition: attachment; filename=plantilla-carga-<destino>.csv` |
| `POST /api/v1/{rol}/cargas/validacion` | Ídem | `multipart/form-data` con `archivo` → 200 `ApiDataResponse<ResultadoValidacionCargaDTO>{huella (SHA-256 hex del contenido), perfilDestino, totalFilas, filasValidas, filasYaExistentes, filasConError, filas[{numeroFila, documento, correo, estado: VALIDA \| YA_EXISTE \| ERROR, errores[{campo, codigo, mensaje}]}]}`. **No crea nada.** 400 (`CMA_001/002/004/013`), 403 (otro rol), 429 (`CMA_014`) |
| `POST /api/v1/{rol}/cargas` | Ídem | `multipart` con `archivo` y `huella` → 200 `ApiDataResponse<ResultadoCargaDTO>{totalFilas, creadas, yaExistentes, conError, cuentasPendientes, filas[{numeroFila, documento, correo, estado: CREADA \| CREADA_CUENTA_PENDIENTE \| YA_EXISTE \| YA_EXISTE_CUENTA_REPARADA \| ERROR, idUsuario?, errores[]}], mensaje (CMA_015)}`. 409 `CMA_003` si la huella no coincide. Idempotente por documento y correo ([SUPUESTO-D-10]) |

`{rol}` ∈ `coordinador` (destino DOCENTE), `decano` (destino COORDINADOR), `admin` (destino DECANO). La respuesta nunca incluye `clave_inicial` ni nombres. Las filas van en una sola lista (como mucho `MAXIMO_FILAS` ≤ 500; excepción justificada a `ApiPageResponse`).

**Capas:**
- Primario (infraestructura): `CargaMasivaUsuariosController` por rol (3 controladores pequeños, o uno con tres rutas fijas, sin parámetro de ruta para el rol) y `CsvCargaUsuariosParser` (`infrastructure/adapter/primary/controller/cargas/`, sin librerías nuevas; si se añade una, con versión fija y revisión de licencia) → `List<FilaCargaUsuarioDTO>`.
- Application `features/cargamasiva/`: `ValidarCargaUsuariosUseCaseImpl` (forma por fila con los validadores existentes del alta individual y `PasswordRegistroRule`; luego `CargaUsuariosValidacionPort.validar(...)` → SP; une los errores de forma y de BD por fila) y `EjecutarCargaUsuariosUseCaseImpl` (recalcula la huella, revalida y, por cada fila `VALIDA`, llama al **caso de uso individual** existente: `VincularDocenteProgramaInputPort`, `CrearCoordinadorInputPort` o `CrearDecanoInputPort`, con los ids resueltos; captura las excepciones de negocio por fila y las convierte en el `mensajeUsuario` del catálogo; para `YA_EXISTE` llama a `AsegurarCuentaIdentidadService` (D.4) para reparar la cuenta si falta). Sin transacción global. Procesamiento secuencial (el IdP no se llama en paralelo).
- `CrearCoordinadorDTO`/request y el adaptador de `usp_crear_decano` pasan el tipo de documento (hoy el SP lo ignora).
- Auditoría (D.6): `@AuditableOperation(action = "CARGA_MASIVA_<DESTINO>", resourceType = "CARGA_MASIVA", metadataResponseFields = {"totalFilas", "creadas", "yaExistentes", "conError"})`; la validación no se audita (solo lectura). Los logs llevan solo conteos y `correlationId`, nunca contenido de filas.
- Pruebas RED: parser (BOM, `;` y `,`, comillas, cabecera desordenada o incompleta, línea vacía, fórmula, no UTF-8, tamaño), caso de uso de validación (une errores, no llama a ningún comando), caso de uso de ejecución (huella distinta → 409 sin llamadas; fila válida → 1 llamada al caso de uso individual; excepción en la fila 2 → fila 3 se procesa; `YA_EXISTE` con cuenta faltante → reparada; IdP caído → `CREADA_CUENTA_PENDIENTE`; repetir el mismo archivo → todo `YA_EXISTE`), controladores (plantilla con cabecera exacta por rol, 403 cruzado entre roles, 429), seguridad (la clave no aparece en logs ni en la respuesta: captura del appender), prueba de rendimiento con 100 filas e IdP simulado con 200 ms (registra el p95; si pasa de 60 s, el orquestador baja `MAXIMO_FILAS`).

### 6.5 Frontend

Componente compartido `shared/components/carga-masiva-usuarios` (entrada `destino = input.required<'DOCENTE' | 'COORDINADOR' | 'DECANO'>()`, servicio `carga-masiva.service.ts`) en tres pantallas: coordinador → Docentes (`coordinator-docentes`), decano → Coordinadores (`dean-coordinadores`), administrador → Decanos (`admin-decanos`). Pasos: (1) "Descargar plantilla"; (2) seleccionar archivo → "Validar" → tabla por fila (número, documento, correo, estado con `badge`, errores) paginada en el cliente sobre la lista acotada, y resumen; (3) "Crear N cuentas" (desactivado si N = 0; diálogo de confirmación que dice cuántas se omitirán); (4) resultado por fila y botón "Descargar resultado" (CSV generado en el cliente solo con número de fila, estado y mensajes, sin datos de entrada). Mensajes del backend tal cual. Specs RED: flujo completo con respuestas simuladas, confirmación obligatoria, 409 de huella (vuelve al paso 2), 429, la clave nunca se muestra, `OnPush`/signals; móvil: tabla convertida en tarjetas y botones apilados.

### 6.6 Docs y riesgos

- `HU-CATALOG.md` HU171: texto nuevo ("Carga masiva CSV de docentes, coordinadores y decanos por jerarquía; estudiantes solo por QR o matrícula manual") y SP `usp_validar_carga_masiva_usuarios`; se quita `usp_registrar_estudiante_en_programa_interno` de esa fila (ahora lo usa HU156).
- **Riesgos:** (1) Tiempo de respuesta síncrono con el IdP: límite por parámetro y p95 medido. (2) Contraseñas en un archivo del operador ([SUPUESTO-D-08]): se aceptan en memoria y nunca se devuelven ni registran; se recomienda en la pantalla borrar el archivo después de la carga. (3) Éxito parcial por diseño: el resumen y el resultado por fila lo hacen visible, y repetir el archivo es seguro.

---

## 7. D.6 — Auditoría de las mutaciones `/api/v1/admin/**` (DEC-022 §4)

### 7.1 Alcance

Toda petición `POST`/`PUT`/`PATCH`/`DELETE` bajo `/api/v1/admin/**` (y `PUT /api/v1/admin/decanos/{id}/identidad`, que vive en `CorreccionIdentidadController`) deja un `AuditoriaEvento` con actor, acción, recurso, resultado, `correlationId` y, cuando aplica, valores. `AuditoriaEvento` **no cambia** (contrato inmutable de `DB_BASELINE_CONTRACT.md`): los valores van en `metadata` (JSON).

### 7.2 Backend

- **`@AuditableOperation`** añade `String[] metadataRequestFields() default {}` y `String[] metadataResponseFields() default {}`. `AuditInterceptor.metadata()` arma `{handlerType, <campo>: <valor saneado>}` con `SensitiveDataSanitizer` (240 caracteres por valor; metadatos de 4 KB como máximo) y una **lista de denegación por nombre exacto** (`password`, `clave_inicial`, `claveInicial`, `token`, `pin`, `secret`) que gana aunque el campo esté en la lista blanca. `clave` (clave del parámetro) **no** es sensible: el RED comprueba que el saneador no la oculta y, si lo hace, se ajusta la regla del saneador sin relajar las demás.
- **Anotaciones nuevas** (acción · recurso · id): `POST /admin/decanos` `CREAR_DECANO`·`DECANO`·respuesta/correo · `PUT /admin/decanos/{id}/identidad` `CORREGIR_IDENTIDAD_DECANO`·`DECANO`·`id` · `PUT /admin/parametros/{id}` (D.3) · `POST /admin/cierre-masivo` `CIERRE_MASIVO_PERIODO`·`PERIODO_ACADEMICO`·`idPeriodoAcademico` · `POST /admin/facultades` `CREAR_FACULTAD` · `PUT /admin/facultades/{id}` `ACTUALIZAR_FACULTAD` · `PATCH /admin/facultades/{id}/estado` `CAMBIAR_ESTADO_FACULTAD` (metadatos `activa`) · `POST /admin/periodos-academicos` `CREAR_PERIODO_ACADEMICO` · `PUT /admin/periodos-academicos/{id}` `ACTUALIZAR_PERIODO_ACADEMICO` · `DELETE /admin/periodos-academicos/{id}` `ELIMINAR_PERIODO_ACADEMICO` · `POST /admin/notificaciones/plantillas/{tipo}/versiones` `CREAR_VERSION_PLANTILLA` · `PATCH …/versiones/{version}/activar` `ACTIVAR_VERSION_PLANTILLA` · `POST /admin/notificaciones/cola/{id}/reintentar` `REINTENTAR_NOTIFICACION` · `POST /admin/notificaciones/prueba` `ENVIAR_NOTIFICACION_PRUEBA` · `POST /admin/estudiantes/admision` (D.4) `ADMITIR_ESTUDIANTE` · `PUT /admin/estudiantes/{id}/identidad` (D.4) · `POST /admin/cargas` (D.5). Ya están: `PATCH /admin/decanos/{id}/toggle`, `POST /admin/festivos/{anio}/recarga`.
- **Excepciones explícitas** (sin efecto de escritura): `POST /admin/notificaciones/plantillas/{tipo}/vista-previa` y `POST /admin/cargas/validacion`.
- **Prueba de arquitectura RED** `BE-T:…/architecture/AdminMutacionesAuditadasTest`: recorre `RequestMappingHandlerMapping` (contexto `@WebMvcTest` de los controladores) y falla si algún handler `POST|PUT|PATCH|DELETE` con ruta `/api/v1/admin/**` no tiene `@AuditableOperation` y no está en la lista de excepciones (que el propio test fija). Así una ruta nueva sin auditoría rompe el build.
- **Lectura (F-ADM-022):** `EventoAuditoriaDTO` añade `idCorrelacion` (desde `correlationId`; `idTraza` se conserva). `GET /api/v1/admin/auditoria` admite `idCorrelacion` (UUID) y `soloAdministracion` (boolean) como filtros nuevos opcionales.
- Pruebas RED: interceptor (metadatos de petición y de respuesta, denegación aunque esté en la lista blanca, truncado, fallo del publicador sin romper la respuesta), cada controlador administrativo (el evento se publica con la acción esperada en éxito y en fallo 400/403), DTO y mapper con `idCorrelacion`, controlador de auditoría con los filtros nuevos.

### 7.3 BD

- `usp_consultar_auditoria_eventos_paginado` (**modificado**): parámetros nuevos al final `@idCorrelacionEvento UNIQUEIDENTIFIER = NULL`, `@soloAdministracion BIT = 0`. `@soloAdministracion = 1` filtra `path LIKE ufn_obtener_parametro_texto(NULL,'AUDITORIA','PREFIJO_RUTA_ADMINISTRACION') + '%'` (parámetro nuevo `'/api/v1/admin/'`, sin literal en el SP). Si llegan `@soloAsistencia = 1` y `@soloAdministracion = 1` a la vez, error de validación. Columnas de salida sin cambio (`correlationId` ya viaja).
- Semilla `46_culm001_d6_parametros.sql`: `AUDITORIA/PREFIJO_RUTA_ADMINISTRACION`. Migración `25_culm001_d6_auditoria_admin_up/down.sql` (SP y parámetro / texto anterior).
- Pruebas RED `DB:test/test_culm001_d6_auditoria.sql`: D6-01 filtro por correlación · D6-02 `soloAdministracion` devuelve solo rutas administrativas · D6-03 los dos filtros a la vez → error · D6-04 sin filtros nuevos, el resultado es igual al anterior (regresión).

### 7.4 Frontend

`FE:features/admin/admin-system` (pestaña "Trazabilidad y Auditoría"): columna "Correlación" (copiable), filtro por correlación y opción "Solo acciones administrativas" junto a "Solo acciones de asistencia" (excluyentes); el detalle muestra los metadatos (valor anterior y nuevo). Specs RED: filtros, columna, detalle; móvil: tarjetas.

### 7.5 Docs y riesgos

- `HU-CATALOG.md` HU172: "incluye mutaciones del administrador". `FINDINGS.md` F-ADM-022 y F-ADM-S13 → corregido.
- **Riesgos:** (1) Fuga de datos en `metadata`: lista blanca por anotación y denegación por nombre exacto, con prueba. (2) Volumen: solo mutaciones administrativas, pocas. (3) El evento HTTP es de mejor esfuerzo; para parámetros hay además `CambioParametro` ([SUPUESTO-D-04]).

---

## 8. D.7 — Retiro de `POST /api/v1/asistencias` y del SP autónomo (TD-009, B-5)

### 8.1 Alcance

El registro individual (501, TD-009) queda cubierto por el lote (`POST /asistencias/lote`, golden path) y por el registro por toma de B.2. Se retira la ruta y su cadena de clases, y en BD se revoca y se borra `usp_registrar_asistencia_estudiante_autonomo` (código estático `Sesion.codigo`, sin consumidor después de B.2). **Precondición:** B.2 mezclado; si el backend de B.2 no retiró `AsistenciaJpaRepository:44` ni la feature `registrarasistenciaautonoma`, D.7 los retira.

### 8.2 BD

- Migración `26_culm001_d7_retiro_registro_autonomo_up.sql`: `IF OBJECT_ID(N'dbo.usp_registrar_asistencia_estudiante_autonomo', N'P') IS NOT NULL` → `REVOKE EXECUTE … FROM [rol_asistencias_runtime]` (si el rol existe) y `DROP PROCEDURE`. `_down.sql`: recrea el SP con su texto literal (copiado en el `down`) y el `GRANT`.
- Se borra `DB:schema/stored-procedures/usp_registrar_asistencia_estudiante_autonomo.sql`.
- `DB:schema/security/rol_asistencias_runtime.sql` (línea `WORK_ITEM` del manifiesto post-freeze UTC-D06): se quita `(N'usp_registrar_asistencia_estudiante_autonomo')` de la lista (línea 54) y se regenera **solo esa línea** del manifiesto (precedente DEC-036; decisión del orquestador en `DECISIONES.md`).
- `DB:test/verify_runtime_role_login.ps1:31`: se quita el SP de la lista esperada y se añade la aserción negativa (el rol no puede ejecutarlo: objeto inexistente).
- Pruebas que cambian por contrato (objeto retirado): `test_attendance_commands.sql:437-460` y `test_ses01_ventana_asistencia.sql` bloque J (196-225) se sustituyen por `D7-01 OBJECT_ID(...) IS NULL` y `D7-02 sin permiso en sys.database_permissions`. La garantía de SES-01 "ninguna ruta alternativa escribe fuera de la ventana" la siguen cubriendo las pruebas de B.2 del registro por token y por toma (se cita el ID de B en el commit).
- Documentos derivados: `DB:docs/arquitectura/DOCUMENTACION_PROCEDIMIENTOS_*.md` y `especificacion_sp_endpoints.md` sin el SP.
- Prueba RED `DB:test/test_culm001_d7_retiro.sql`: D7-01, D7-02, D7-03 (`up → down → up`; tras el `down` el SP existe y tiene `GRANT`).

### 8.3 Backend

- Se retiran: el handler `POST /api/v1/asistencias` de `AsistenciaController`, `RegistrarAsistenciaInputPort`, su caso de uso, DTO, dominio, request, validador y la parte del mapper; el método de puerto/adaptador que lanzaba `FeatureUnavailableException`; el matcher de `SecurityConfig`; la entrada de `access-catalog.json`.
- Pruebas que cambian por contrato: las de `AsistenciaControllerTest` sobre `POST /asistencias` pasan a **una** prueba "`POST /api/v1/asistencias` → 404 `RESOURCE_NOT_FOUND`" (MockMvc); `SqlStoredProcedureContractIT`, `AsistenciaCommandsSpParityIT`, `AsistenciaJdbcBaselineOracle` y `AsistenciaJpaCommandNativeQueryPatternTest` dejan de referirse al SP autónomo; la prueba de consistencia del catálogo de acceso pasa sin la entrada.
- Golden path: **sin cambio** (`POST /asistencias` no está en `openapi-golden-path.yaml`; `BACKEND_GOLDEN_PATH_CONTRACT.md:27` ya lo deja fuera).

### 8.4 Frontend

Se borra cualquier método de servicio que llame a `POST …/asistencias` exacto (el RED lo localiza con una búsqueda y una prueba que lo fija). Sin pantallas nuevas.

### 8.5 Docs y riesgos

- `TECHNICAL_DEBT.md` (Infra) TD-009 → **CERRADA** (retiro; el registro individual es un lote de uno o una toma de B.2). La deuda de B "autónomo sin consumidor" → cerrada. `HU-CATALOG.md` HU027: endpoint `POST /api/v1/asistencias/lote` y registro por toma (B.2). `test_all_hus.ps1`: `POST /asistencias` pasa de esperar 501 a esperar 404. Con el PDP sin `--prune`, el PEP deja pasar y Spring responde 404; tras `--prune` la respuesta sería 403 `NO_APPLICABLE_POLICY`, salvo que D.9 F-EST-024 esté hecho (404 siempre). Se documenta en `PRS.md`. F-DOC-022 → corregido.
- **Riesgos:** (1) Algún cliente externo del endpoint: no hay (B.2 retiró el último); la búsqueda en los 4 repos lo confirma en RED. (2) Que se mezcle antes que B.2: se impide por la precondición del PLAN.

---

## 9. D.8 — Comparativas, tendencia y consolidado por horas (HU103, HU139, HU134, HU061; F-COO-007)

### 9.1 Alcance

Los cuatro SP diferidos por B ([SUPUESTO-B-23]) pasan de unidades de sesión a horas (DEC-012/DEC-024), sobre las columnas que B.2 añadió a `uv_resumen_asistencia_estudiante_grupo` y `uv_asistencia_sesion_horas`. Se conservan los nombres de columna ([SUPUESTO-D-13]). **Precondición:** BD de B.2 mezclada.

### 9.2 BD

| SP | Fórmula nueva (misma población que hoy) | Columnas añadidas al final |
| :--- | :--- | :--- |
| `usp_consultar_comparativa_facultades` (HU139) y `usp_consultar_comparativa_programas_facultad` (HU103) | `porcentajeAusentismo = 100 · Σ horasFalta / Σ horasDictadas` sobre las matrículas del ámbito (`NULL` si Σ `horasDictadas` = 0); `sesionesEjecutadas` y `faltasSinJustaCausa` se conservan en sesiones (trazabilidad) | `horasDictadas DECIMAL(12,2), horasFalta DECIMAL(12,2)` |
| `usp_consultar_tendencia_ausentismo` (HU134) | Por intervalo (semana o mes local del inicio de la sesión): `100 · Σ horasFalta / Σ (horasSesion × matrículas activas de la sesión)`; las sesiones canceladas no cuentan (B.1) | `horasDictadasEstudiante DECIMAL(14,2), horasFalta DECIMAL(14,2)` |
| `usp_consultar_consolidado_asistencia_grupos_paginado` (HU061) | Por grupo, con `D = horasDictadas × activos`: `porcentajeAsistencia = 100 · Σ horasAsistidas / D`, `porcentajeInasistencia = 100 · Σ horasFalta / D`, `porcentajeExcusa = 100 · Σ horasExcusa / D`, `porcentajeSinRegistro = 100 · Σ horasSinRegistro / D` (los cuatro suman 100 ± 0,01; 0 si D = 0). El literal `N'A'` del estado de matrícula pasa a `ufn_obtener_estado_estudiante_grupo`/catálogo (cero datos quemados) | `horasDictadas DECIMAL(12,2), porcentajeExcusa DECIMAL(5,2), porcentajeSinRegistro DECIMAL(5,2)` |

- Migración `27_culm001_d8_kpis_horas_up/down.sql` (`CREATE OR ALTER` / texto de B.2 literal). Sin semillas ni permisos nuevos. `DB_DEVELOP_FREEZE_ADDENDUM.md` (BD e Infra): sección "CULM-001 D.8" con la unidad de cada columna de los cuatro SP; se regenera su `.sha256` tras la revisión 9.2.
- Pruebas RED `DB:test/test_culm001_d8_kpis_horas.sql` con un fixture de 2 sesiones de duraciones distintas (2 h y 1 h), una de ellas con 2 tomas, una sesión cancelada y una cabecera sin detalle: D8-01 comparativas = cálculo manual por horas · D8-02 tendencia por semana y por mes = cálculo manual · D8-03 consolidado: los cuatro porcentajes suman 100 y el caso de F-COO-007 (10 activos, 2 sesiones, sin faltas) da `porcentajeSinRegistro` > 0 y `porcentajeAsistencia + porcentajeSinRegistro = 100` · D8-04 con una toma y sesiones de igual duración, el resultado coincide con la fórmula por sesiones (regresión) · D8-05 sin literal `'A'` en el consolidado (`sys.sql_modules`) · D8-06 la cancelada no suma · D8-07 `up → down → up`.

### 9.3 Backend

DTOs de `GET /api/v1/admin/comparativa-facultades`, `GET /api/v1/decano/comparativa-programas`, `GET /api/v1/admin/tendencia-ausentismo`, `GET /api/v1/{coordinador|decano}/consolidado-asistencia` con los campos nuevos (proyecciones, mappers, contrato posicional). Pruebas RED: mappers y contrato SP con las columnas nuevas.

### 9.4 Frontend

Indicadores del administrador y del decano: texto de ayuda "calculado por horas" y horas en el tooltip. `ConsolidadoAsistenciaComponent`: columnas "Excusa" y "Sin registro" y barra apilada de 4 segmentos que suma 100 % (F-COO-007). Specs RED: columnas, suma, textos; móvil: barra a ancho completo y leyenda debajo.

### 9.5 Docs y riesgos

`HU-CATALOG.md`: HU061, HU103, HU134 y HU139 sin la nota "diferido a D" y con "porcentaje por horas (CULM-001 D.8)". `FINDINGS.md`: F-COO-007 y F-COO-S02 → corregido. **Riesgo:** los números de las pantallas cambian cuando las sesiones tienen duraciones distintas; se comunica en el PR con el ejemplo del fixture.

---

## 10. Catálogo de accesos (rutas nuevas, cambiadas y retiradas; DEC-037/DEC-038)

Cada fila entra en `SecurityConfig` y en `GestioAsistenciaBackend/infra/security-baseline/access-catalog.json`. **Bloqueo B-01:** hasta que el responsable ejecute `python -X utf8 -I infra\security-baseline\scripts\provision_asistencias.py pdp` (y `verify`, `verify-decisions`), las rutas **nuevas** responden 403 en el laboratorio. Los gates de código no dependen de esto. La prueba en pantalla de esas rutas queda pendiente de B-01 y se anota en `PRS.md`.

| D.x | Método y ruta | Roles | Ámbito (texto `ownership`) | Tipo |
| :--- | :--- | :--- | :--- | :--- |
| D.2 | `GET /api/v1/configuracion/reclamos` | ESTUDIANTE, DOCENTE | Configuración institucional de reclamos; solo lectura | nueva |
| D.3 | `GET /api/v1/admin/parametros` | ADMINISTRADOR | Paginada; el SP exige ADMINISTRADOR | cambia la respuesta |
| D.3 | `PUT /api/v1/admin/parametros/{id}` | ADMINISTRADOR | Lista blanca, tipo, rango y concurrencia en el SP; auditada | ya registrada (501 → implementada) |
| D.3 | `GET /api/v1/admin/parametros/{id}/cambios` | ADMINISTRADOR | Historial de cambios; solo lectura | nueva |
| D.4 | `POST /api/v1/admin/estudiantes/admision` | ADMINISTRADOR | Programa de la institución del administrador (SP); sin matrícula en grupos | nueva |
| D.4 | `PUT /api/v1/admin/estudiantes/{idEstudiante}/identidad` | ADMINISTRADOR | Estudiante de la institución del administrador (SP); motivo obligatorio | nueva |
| D.4 | `GET /api/v1/admin/programas` | ADMINISTRADOR | Programas de la institución del administrador (SP) | nueva |
| D.5 | `GET /api/v1/coordinador/cargas/plantilla`, `POST /api/v1/coordinador/cargas/validacion`, `POST /api/v1/coordinador/cargas` | COORDINADOR | Docentes de sus programas (SP, `JerarquiaAltaUsuario`) | nuevas |
| D.5 | `GET /api/v1/decano/cargas/plantilla`, `POST /api/v1/decano/cargas/validacion`, `POST /api/v1/decano/cargas` | DECANO | Coordinadores de programas de su facultad (SP) | nuevas |
| D.5 | `GET /api/v1/admin/cargas/plantilla`, `POST /api/v1/admin/cargas/validacion`, `POST /api/v1/admin/cargas` | ADMINISTRADOR | Decanos de su institución (SP) | nuevas |
| D.6 | `GET /api/v1/admin/auditoria` | ADMINISTRADOR | Filtros nuevos opcionales | cambia los parámetros |
| D.7 | `POST /api/v1/asistencias` | — | — | **retirada** (entrada eliminada; `--prune` a cargo del responsable, TD-062) |
| D.9 | `GET /api/v1/admin/periodos-academicos` | ADMINISTRADOR | Períodos de la institución del administrador (SP) | nueva |
| D.9 | `GET /api/v1/decano/grupos/{grupoId}` | DECANO | Grupo de su facultad; ajeno o inexistente → 403 ([SUPUESTO-D-14]) | nueva |
| D.9 | `GET /api/v1/decano/sesiones` | DECANO | Parámetro nuevo `idGrupo` filtrado en el SP | cambia los parámetros |
| D.9 | `GET /api/v1/realtime/status` | ADMINISTRADOR | Antes, cualquier autenticado | cambian los roles |
| D.9 | `POST /api/v1/realtime/emit` | — | — | **retirada** (o solo ADMINISTRADOR con tipo de evento del contrato, si el orquestador lo prefiere; §11) |

---

## 11. D.9 — Hallazgos medios y bajos asignados a D

Cada fila de `FINDINGS.md` con Estado `paquete-D` (35) queda asignada aquí o a otro D.x, o justificada como "no en D". Grupos de D.9: **a** (BD/backend: seguridad y 4xx/404), **b** (frontend), **c** (SSE, después de C), **d** (docs/infra). Migración `28_culm001_d9_hallazgos_up/down.sql`, semilla `49_culm001_d9_*`, pruebas `test_culm001_d9_*.sql`.

| Hallazgo | Corrección concreta | Capa | Prueba RED | Grupo |
| :--- | :--- | :--- | :--- | :--- |
| F-ADM-003 | → D.3 | — | — | D.3 |
| F-ADM-004 | → D.4 | — | — | D.4 |
| F-EST-008, F-EST-S16 | → D.1 | — | — | D.1 |
| F-ADM-022, F-ADM-S13 | → D.6 | — | — | D.6 |
| F-ADM-012 | → D.3 (vista legible, solo editables por defecto) | — | — | D.3 |
| F-DOC-022 | → D.7 (ruta retirada) | — | — | D.7 |
| F-ADM-008 | `/admin/parametros` → D.3 (`ApiPageResponse`). `decanos`, `facultades`, `areas` e `instituciones` son **catálogos acotados por institución** (decenas de filas): se mantienen en `ApiListResponse` como excepción documentada en `AGENTS.md` §2.3 ("listados masivos") y en el catálogo de HUs; **no en D** el cambio de sobre | Docs | — | d |
| F-ADM-023 | Los listados ya paginados por SP pasan a `ApiPageResponse` (`elementos, numeroPagina, tamanoPagina, totalElementos, totalPaginas`): `GET /admin/estudiantes`, `/admin/docentes`, `/admin/asignaturas`, `/admin/auditoria`, `/decano/programas-creditos`, `/decano/docentes`, `/decano/asignaturas`, `/decano/estudiantes`, `/decano/sesiones` (los helpers `lista(PaginaDTO)` pasan a `pagina(PaginaDTO, numero, tamano)`) y sus servicios del frontend. Validación común `PaginacionRequestValidator` (`pagina ≥ 1`, `1 ≤ tamano ≤ GENERAL/TAMANO_PAGINA_MAXIMO`) → 400 `FIELD_INVALID` en esos endpoints y en `/docente/reclamos` y `/estudiante/reclamos` (F-EST-022). **No en D:** `GET /api/v1/estudiantes` (`items/page/size`) es golden path WORM, y `/tipos-identificacion` es catálogo plano | BE + FE | Controladores: sobre paginado y 400 con `pagina=0`, `tamano=100000`, `pagina=-1`; servicios FE | a + b |
| F-EST-022 | Incluido en F-ADM-023 (validador común) | BE | `GET /estudiante/reclamos?pagina=0` → 400; `tamano=100000` → 400 | a |
| F-ADM-024 | [SUPUESTO-D-12]: `usp_crear_decano` devuelve `DEC_020` (`estadoResultado = 0`) si la persona ya es decano activo; `CrearDecanoUseCaseImpl` usa `AsegurarCuentaIdentidadService` (D.4): cuenta existente → 409 `DEC_020`; cuenta faltante → creada, 201 con `cuentaReparada` | BD + BE | D9-DEC-01 (SP), caso de uso con las 3 ramas, controlador 409 | a |
| F-ADM-025 | `GlobalExceptionHandler`: las `ValidationException` de `RequestValidationGuard` llenan `details[{campo, codigo, mensaje}]` en `ApiErrorResponse` (hoy genérico); los validadores de decano y facultad informan campo y regla (nombre con caracteres no permitidos, longitud). La política de clave la dice solo el backend (8 caracteres): el frontend quita su regla de 12 (F-ADM-011) | BE + FE | `POST /admin/decanos` con `primerNombre=CULM1-Decano` → 400 con `details[0].campo = primerNombre`; ídem facultades | a |
| F-ADM-011 | `admin-decanos`: sin GUID quemado ni `CC` de respaldo (tipo del catálogo; si no carga, se desactiva el formulario con el mensaje de error); se quita la etiqueta `DEC-{{numeroIdentificacion}}` construida en el cliente (se muestra el documento tal cual); se quita la política de 12 caracteres. El backend honra `tipoIdentificacionId` (D.5 cambia `usp_crear_decano`; si D.5 se difiere, ese cambio de SP se hace aquí) | FE (+BD) | Specs: sin GUID literal (búsqueda en el spec), sin `DEC-`, error de catálogo visible | b |
| F-ADM-026 | `CierreMasivoRequest` validado: `idPeriodoAcademico` obligatorio → 400 `FIELD_REQUIRED` | BE | `POST /admin/cierre-masivo {}` → 400 | a |
| F-ADM-027 | `POST /admin/notificaciones/cola/{id}/reintentar` con id inexistente: el SP devuelve `NTF_020` → 404 (hoy 500 `ERR_DB_UNCLASSIFIED`); `vista-previa` con tipo inexistente → 404 `NTF_021` (validado contra el catálogo de plantillas, no 200 vacío) | BD + BE | D9-NTF-01/02; controlador 404 | a |
| F-ADM-029 | `GET /admin/notificaciones/estado-canal`: deja de exponer host, puerto y usuario; devuelve `{canalActivo, ultimoEnvioUtc, ultimoError (código)}` | BE + FE | Respuesta sin `host`/`puerto`/`usuario` (aserción de JSON) | a |
| F-ADM-030 | `POST /admin/periodos-academicos` → 201 con el período creado (`id`, `codigo`, fechas) en `ApiDataResponse`; nuevo `GET /admin/periodos-academicos` (ámbito institución; reutiliza la consulta del coordinador y su SP, añadiendo el perfil ADMINISTRADOR con ámbito institución en el SP si falta) | BD + BE | 201 con id; GET 200 paginado y 403 para DOCENTE | a |
| F-ADM-005 | `admin-system` (cierre masivo): período inicial = el vigente según `GET /admin/periodos-academicos` (campo `esVigente` del SP); siempre envía el UUID; lista vacía → estado vacío con mensaje; sin `2026-2` quemado ni `periodoCodigo` | FE | Specs: valor inicial del backend, nunca un código en `idPeriodoAcademico`, lista vacía | b |
| F-ADM-009 | Pantalla de solo lectura `/app/admin/instituciones` (HU163) con tabla de `GET /admin/instituciones`, ítem de menú y `PaginationComponent` en el cliente (catálogo acotado) | FE | Spec de ruta, menú y tabla | b |
| F-ADM-016 | `environment.ts`: `USE_MOCKS` y `USER_PROFILE_ENDPOINT_ENABLED` dejan de leerse de `localStorage`; los mocks solo por configuración de build (`fileReplacements`); se borran las banderas sin consumidores (`teacherClaimsEnabled`) y las fijas en `true` (`sessionsEnabled`, `attendanceEnabled`); `auth.service` no restaura un rol mock desde el almacenamiento | FE | Spec: con `localStorage.USE_MOCKS='true'` la app usa el backend real; búsqueda de las banderas retiradas | b |
| F-DOC-006 | `attendance-enrollment-modal`: solo un 404 o un resultado vacío abren el alta de estudiante nuevo; 403, 500 o error de red muestran el `message` del backend y no continúan | FE | Specs 404 → alta; 403/500/red → error sin alta | b |
| F-EST-012 | `/matricula/qr?t=…` → "Ya tengo cuenta": el token `t` se conserva a través del login (estado de navegación, no `localStorage`) y el modal envía `{token}` a `POST /estudiante/matricular-grupo` (el backend ya acepta token o PIN) | FE | Spec: tras el login el modal envía `token`; el PIN sigue como alternativa | b |
| F-EST-006 | **Parcial:** `materia.creditos` se llena desde la asignatura en `GET /estudiante/materias` (hoy `null`); filtro de texto de materias en el cliente (lista propia y acotada). **No en D (propuesta para CLOSURE):** "buscar compañeros" (choca con la privacidad: el 403 de `/grupos/{id}/estudiantes` al estudiante es correcto) y el acordeón por semestre (necesita el semestre del plan, B2). `HU-CATALOG.md`: HU003, HU007, HU018 y HU019 dejan de figurar como certificadas donde no existe la función (estado real y nota) | BE + FE + docs | Mapper con créditos; spec del filtro | a + b + d |
| F-EST-S06, F-DOC-021 | El horario del estudiante y del docente se alimenta de las franjas del grupo (`HorarioGrupo`, F1), no de las sesiones: es correcto. La causa es de datos: ningún grupo sembrado tiene franjas. Corrección: el fixture de datos limpios (`restablecer-datos-limpios.ps1` y `culm1_segundo_ambito.sql`) siembra franjas coherentes con las sesiones de cada grupo; las pantallas de horario muestran un estado vacío explicado ("Este grupo no tiene franjas registradas") en lugar de una grilla vacía | Datos + FE | D9-HOR-01 (`uv_horario_estudiante` > 0 tras el fixture); specs del estado vacío | a + b |
| F-DEC-003 | Nuevo `GET /api/v1/decano/grupos/{grupoId}` (SP `usp_consultar_grupo_facultad_detalle`, ámbito facultad; ajeno o inexistente → 403); `dean-grupo-detalle` deja de descargar todos los grupos y de recorrer 50 páginas: usa el detalle y `GET /decano/sesiones?idGrupo=` paginado con `PaginationComponent` | BD + BE + FE | D9-DEC-02/03; controlador 200/403; spec sin bucle de páginas | a + b |
| F-DEC-014 | `usp_consultar_sesiones_facultad_paginado` añade `@idGrupo = NULL` (filtrado en el SP; grupo fuera de la facultad → error de ámbito, 403) y el controlador lo acepta | BD + BE | D9-DEC-04: GUID aleatorio → 403; grupo propio → solo sus sesiones | a |
| F-TRX-021 | [SUPUESTO-D-14]: `GET /grupos/{id}/reportes/asistencia-excel`, `/coordinador/planes-estudio/{id}/asignaturas` y `/decano/planes-estudio/{id}/asignaturas` con id inexistente o ajeno → 403 (validación de ámbito en el SP antes de leer), en lugar de 200 con un `.xlsx` o una lista vacíos. `/grupos/{id}/estudiantes|asistencias` ya lo hacen desde A/B2 | BD + BE | D9-TRX-01..03; controladores 403 | a |
| F-EST-024 | Filtro `UnmappedRouteFilter` antes del PEP: si no hay handler de Spring para (método, ruta), responde 404 `RESOURCE_NOT_FOUND` sin consultar el PDP (no expone datos: las rutas ya son públicas en OpenAPI). Así una ruta retirada da 404 y no 403 (también D.7) | BE | `GET /estudiante/materias/{id}/prerrequisitos` → 404; una ruta existente sin permiso sigue en 403 | a |
| F-TRX-020 | `management.server.port` aparte (`MANAGEMENT_SERVER_PORT`, por defecto 8090, comprobando que no choque con los puertos de §ESTADO) enlazado a `127.0.0.1`; `SecurityPublicEndpoints.ACTUATOR` se reduce a `/actuator/health/**` en el puerto de la API; la configuración de recolección de Prometheus en Infra apunta al puerto nuevo | BE + Infra | `GET :8080/actuator/prometheus` → 404/401; `:8090` desde loopback → 200 | a + d |
| F-TRX-011 | `docker-compose.yml:51`: `${MSSQL_SA_PASSWORD:?…}` sin valor por defecto; el perfil `proxy` publica Traefik en `127.0.0.1` y desactiva el dashboard (o lo deja solo en loopback). **No en D:** las claves de laboratorio de los documentos (las fija `AGENTS.md` §7 como credenciales de desarrollo) | Infra | `docker compose config` falla sin la variable; puertos en loopback | d |
| F-TRX-016 | `GET /realtime/status` solo ADMINISTRADOR; `POST /realtime/emit` se retira (sin consumidores en el frontend; el RED lo confirma). Si el orquestador prefiere conservarlo: solo ADMINISTRADOR, tipo de evento del contrato, audiencia obligatoria y 400 sin tipo | BE | 403 para DOCENTE en `status`; `emit` 404 o 400 | c |
| F-TRX-019 | `GET /realtime/stream` con un `Accept` incompatible → 406 (no 500); al abrir, el stream envía de inmediato un comentario SSE (`: conectado`) para entregar las cabeceras (no es un evento del contrato); el filtro por `grupo` compara los GUID sin distinguir mayúsculas | BE | 406; primera respuesta en menos de 1 s; GUID en mayúscula entregado | c |
| F-ADM-020 | `INFRA:docs/architecture/rutas-por-rol.md` generado desde `access-catalog.json` por un script `INFRA:scripts/docs/generar-rutas-por-rol.ps1` (con `-Check` en `infra.ps1 verify`); el `docs/rutas-por-rol.md` del workspace raíz se marca como obsoleto con un enlace | Docs | `-Check` falla si el documento no coincide con el catálogo | d |
| R-8 de A | `usp_validar_cruce_horario_estudiante_interno` cuenta solo matrículas activas (estado `A` resuelto por catálogo), no las `I` de otros grupos | BD | D9-CRU-01: una matrícula `I` en un grupo con el mismo horario no bloquea | a |

Mensajes de D.9 (`49_culm001_d9_mensajes.sql`): `DEC_020` "La persona ya está registrada como decano." · `NTF_020` "La notificación no existe." · `NTF_021` "El tipo de plantilla no existe." (con técnicos). Parámetro: `GENERAL/TAMANO_PAGINA_MAXIMO = 100` (MERGE, no pisa un valor existente). **Frontend de D.9**: todo con OnPush/signals y specs; móvil revisado en cada pantalla tocada.
**Docs:** `FINDINGS.md` con el estado final de cada fila (`corregido`, `no-se-corrige (propuesta)` o `abierto (diferido)`).

---

## 12. Documentación común

| Documento | Cambio |
| :--- | :--- |
| `INFRA:docs/user-stories/HU-CATALOG.md` | Filas de §1.3; HU169: `[PENDIENTE]` "En espera del equipo de mensajes (notificación de cambios del catálogo para actualizar la tabla de mensajes en BD)"; HU170 y HU177: `[PENDIENTE]` "En espera del equipo de seguridad (mejora del componente de identidad)"; HU003/HU007/HU018/HU019 con su estado real (F-EST-006); HU044 sin cambios (DEC-022 §7 ya la corrigió) |
| `INFRA:docs/baseline/TECHNICAL_DEBT.md` | TD-009 cerrada (D.7); deudas nuevas: propagación BD → Azure de parámetros (D.3), caché de parámetros con varias instancias (D.3), limpieza de soportes `DRAFT`/`ORPHAN` (D.2) |
| `GestioAsistenciaBackend/docs/baseline/TECHNICAL_DEBT.md` | TD-060 y TD-061 cerradas (D.2); TD-059 según la comprobación de D.2 |
| `INFRA:docs/contracts/events/REALTIME_EVENT_CONTRACT.md` + `.sha256` (y la copia del backend) | `PARAMETER_UPDATED` (D.3, diferible) |
| `INFRA:docs/contracts/db/DB_DEVELOP_FREEZE_ADDENDUM.md` + `.sha256` (y el de BD) | Sección CULM-001 D.8 (unidades) y D.1 (fecha local de radicación desde D) |
| `DB:docs/contracts/DB_LB004D_SUPPORT_BINDING_MANIFEST.sha256` | Regenerado (D.1, D.2) con decisión del orquestador |
| `DB:docs/contracts/DB_UTC_D06_POST_FREEZE_MANIFEST.sha256` | Solo la línea `WORK_ITEM` de `rol_asistencias_runtime.sql` (D.7) |
| `DB:docs/contracts/DB_CULM001_D_POST_FREEZE_MANIFEST.sha256` (**nuevo**, patrón de B) | Solo líneas `WORK_ITEM` de lo que D define como contrato: tablas `CatalogoParametroEdicion`, `CambioParametro`, `JerarquiaAltaUsuario`; vistas `uv_parametro_edicion`, `uv_soporte_reclamo`; SP `usp_radicar_solicitud_revision_asistencia_v3`, `usp_actualizar_parametro`, `usp_admitir_estudiante`, `usp_validar_carga_masiva_usuarios`; función `ufn_calcular_fecha_limite_justificacion`; migraciones `20`–`28`; permisos `rol_asistencias_runtime_culm001_d*.sql`. Se genera tras la aprobación 9.2 con `freeze-manifest.ps1 -Mode GeneratePostFreeze -Manifest …` |
| `openapi-golden-path.yaml` / `BACKEND_GOLDEN_PATH_CONTRACT.md` | **Sin cambio** (ninguna ruta de D es golden path) |
| `AsistenciasUCO-Infra/scripts/tests/test_all_hus.ps1` | Casos: HU026B (409 fuera de plazo), HU015 (radicar con 2 soportes 202), HU168 (PUT 200, 400 de rango, 403 de `RED/*`, 409 de versión), HU156 (201, 409), HU171 (validación 200 sin crear, carga 200, repetición todo `YA_EXISTE`), HU172 (evento con `idCorrelacion` tras un `PUT`), `POST /asistencias` 404 |
| `PRS.md` / `ESTADO.md` | PRs por D.x y estado de B-01 para las rutas de §10 |

---

## 13. Orden de integración, ramas y commits

### 13.1 Orden y paralelismo

| Ola | Subpaquetes (en paralelo dentro de la ola) | Condición de entrada |
| :--- | :--- | :--- |
| 1 | **D.1**, **D.3 + D.6** (comparten `AdminPortalController`, `@AuditableOperation` y `admin-system`), **D.4** | A y B.1 en integración (hoy) |
| 2 | **D.7** y **D.8** | B.2 mezclado (D.7: backend y BD; D.8: BD) |
| 2 | **D.2** | D.1 mezclado (mismo SP v2 y mismo manifiesto LB-004D) |
| 3 | **D.5** | D.4 (`AsegurarCuentaIdentidadService`) y D.6 (metadatos de auditoría) mezclados |
| 3 | **D.9-a, b, d** | D.6 mezclado (`AdminPortalController`, auditoría) |
| 4 | **D.9-c** (SSE) | C mezclado (mismo controlador y gateway SSE) |

La BD local es compartida: cada D.x despliega solo sus objetos y repite `infra.ps1 db-test` tras cada mezcla (como DEC-034).

### 13.2 Ramas

Una rama por D.x y por repo tocado, desde `integracion/CULM-001`, en worktrees propios `C:\Proyectos\GestionAsistencia-CULM001-D<x>\<repo>` cuando hay paralelismo: `feature/CULM-001-D1-plazo-excusas`, `feature/CULM-001-D2-soportes-categoria`, `feature/CULM-001-D36-parametros-auditoria`, `feature/CULM-001-D4-admision-estudiantes`, `feature/CULM-001-D5-carga-masiva`, `feature/CULM-001-D7-retiro-registro-individual`, `feature/CULM-001-D8-kpis-horas`, `feature/CULM-001-D9-hallazgos-medios`. Solo comparten archivos de lista (`access-catalog.json`, `SecurityConfig`, `test_all_hus.ps1`, `HU-CATALOG.md`, `TECHNICAL_DEBT.md`, `FINDINGS.md`); los conflictos se resuelven al mezclar, añadiendo entradas, y se repiten los gates. Los PRs de Backend y BD van a los remotos de DEC-002.

### 13.3 Commits (Conventional Commits, en español, atómicos por capa, con `Refs:`)

- **D.1** · DB: `feat(db/functions): calcular la fecha limite de justificacion` · `feat(db/sp): validar el plazo de excusas al radicar` · `fix(db/sp): guardar la fecha local de radicacion` · `test(db): cubrir el plazo de HU026B` · `docs(db/contracts): regenerar el manifiesto lb004d por HU026B` — BE: `feat(backend/adapter): mapear el plazo vencido de justificacion` · `feat(backend/controller): exponer la fecha limite en sesiones del estudiante` — FE: `feat(frontend/estudiante): mostrar la fecha limite para justificar` — `Refs: HU026B`.
- **D.2** · DB: `feat(db/tables): persistir la categoria del reclamo` · `refactor(db/tables): permitir varios soportes por reclamo` · `feat(db/sp): radicar reclamos con varios soportes` · `fix(db/sp): leer estados de soporte desde parametros` · `test(db): cubrir soportes multiples y categoria` — BE: `feat(backend/usecase): radicar con lista de soportes` · `feat(backend/controller): exponer la configuracion de reclamos` — FE: `feat(frontend/estudiante): adjuntar varios soportes al reclamo` · `feat(frontend/docente): listar soportes y categoria del reclamo` — `Refs: HU015, HU014`.
- **D.3 + D.6** · DB: `feat(db/tables): agregar metadatos de edicion e historial de parametros` · `feat(db/sp): actualizar parametros con lista blanca y rango` · `feat(db/sp): filtrar auditoria por correlacion y administracion` · `test(db): cubrir edicion de parametros` — BE: `feat(backend/usecase): actualizar parametros e invalidar cache` · `feat(backend/observability): auditar mutaciones del administrador con valores` · `test(backend): exigir auditoria en rutas admin` — FE: `feat(frontend/admin): editar parametros con tipo y rango` · `feat(frontend/admin): filtrar auditoria por correlacion` — Infra: `docs(contracts): agregar parameter_updated al contrato realtime` — `Refs: HU168, HU172`.
- **D.4** · DB: `feat(db/sp): admitir estudiantes sin matricula` · BE: `feat(backend/usecase): admitir estudiantes y asegurar su cuenta` · FE: `feat(frontend/admin): agregar admision de estudiantes` — `Refs: HU156`.
- **D.5** · DB: `feat(db/sp): validar cargas masivas por jerarquia` · `fix(db/sp): recibir el tipo de documento en coordinador y decano` · BE: `feat(backend/controller): cargar cuentas por csv con validacion previa` · FE: `feat(frontend/ui): agregar carga masiva de cuentas` — `Refs: HU171`.
- **D.7** · DB: `refactor(db/sp): retirar el registro autonomo por codigo estatico` · `test(db): reemplazar pruebas del registro autonomo retirado` · BE: `refactor(backend/controller): retirar el registro individual de asistencia` · Infra: `docs(baseline): cerrar TD-009` — `Refs: HU027`.
- **D.8** · DB: `refactor(db/sp): pasar comparativas, tendencia y consolidado a horas` · BE: `feat(backend/adapter): exponer horas en comparativas y consolidado` · FE: `feat(frontend/coordinador): mostrar excusa y sin registro en el consolidado` — `Refs: HU061, HU103, HU134, HU139`.
- **D.9**: un commit por hallazgo o por grupo de hallazgos de la misma capa, con `Refs: F-xxx-nnn` en el pie.

Cuerpo obligatorio (qué, por qué, cómo) en los commits de contrato y de manifiesto. Pie `Co-Authored-By` según la configuración de la sesión.

---

## 14. Riesgos globales, rollback y puntos para la revisión

| ID | Riesgo | Mitigación |
| :--- | :--- | :--- |
| RD-1 | Regenerar manifiestos ajenos (LB-004D en D.1/D.2; línea de `rol_asistencias_runtime.sql` en D.7) | Decisión del orquestador en `DECISIONES.md` antes del GREEN (precedente DEC-036); los demás objetos de esos manifiestos no se tocan |
| RD-2 | B.2 se retrasa y bloquea D.7 y D.8 | Ola 1 independiente de B.2; D.7/D.8 quedan listos en RED; D.8 es diferible |
| RD-3 | Choque con C en el gateway SSE (F-TRX-016/019) y en `ASISTENCIA/UMBRAL_*` | D.9-c después de C; la regla cruzada de umbrales vive en BD y C solo los lee |
| RD-4 | B-01 (PDP) impide probar en pantalla las rutas nuevas | Gates de código independientes; instrucción exacta al responsable en `PRS.md`; la AUDIT en pantalla de esas rutas queda condicionada |
| RD-5 | Aprovisionamiento parcial BD/IdP en D.4/D.5 | `AsegurarCuentaIdentidadService`: estado pendiente con el desfase registrado y reparación al repetir |
| RD-6 | Datos sensibles (contraseñas del CSV, valores en auditoría) | Solo en memoria; denegación por nombre exacto; pruebas de log y de respuesta |
| RD-7 | Cambios de sobre de respuesta (F-ADM-023, D.3) rompen pantallas | Backend y frontend del mismo D.x se mezclan juntos; specs de los servicios con el sobre nuevo |
| RD-8 | Tiempo hasta el 2026-11-13 | Orden y diferibles de §1.2 |

**Rollback:** cada migración `20`–`28` tiene su `down` probado `up → down → up`; el `down` de D.2 exige confirmación si hay más de un soporte por reclamo. Revertir el PR del backend o del frontend de un D.x no requiere el `down` salvo en D.7 (el SP debe volver si vuelve el consumidor, que no existe) y en D.2 (v3).

**Puntos que la revisión 9.2 debe decidir:** [SUPUESTO-D-02] (sin tabla `SoporteReclamo`), [SUPUESTO-D-03] (tabla satélite en vez de columnas en `CatalogoParametro`), [SUPUESTO-D-08] (`clave_inicial` en el CSV), [SUPUESTO-D-12] (409 con reparación en F-ADM-024), retirar o restringir `POST /realtime/emit` (F-TRX-016), y la regeneración de los manifiestos LB-004D y UTC-D06 (RD-1).
