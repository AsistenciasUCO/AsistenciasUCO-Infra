# CULM-001 · Paquete C — CONTRACT (cancelación por inasistencia HU026C y apertura del SSE por ámbito)

> **Estado:** v3. Atiende las 14 objeciones de `REVIEW-1.md` (respuesta en §7, decisiones O-1..O-6 de DEC-043) y las 4 de `REVIEW-2.md` (N-1..N-4; cambios respecto a v2 en §0.1). Nada se congela ni se firma (`.sha256`) antes de "sin objeciones".
> **Fecha:** 2026-11-07 (v1, v2 y v3). **Fase SDD:** 02 CONTRACT. El RED empieza con B.2 y B2 mezclados en `integracion/CULM-001` ([SUPUESTO-C-02]).
> **Partición (DEC-043):** **C.1** (imprescindible: motor, decisión y resolución con escalamiento, bandejas del coordinador y del decano, decisión del docente desde la planilla, alertas del estudiante, cierre masivo, apertura del canal de grupo a los 5 roles) y **C.2** (diferible: canal personal, campana, marcar leídas, bandeja propia del docente, HU042 por SSE). Cada elemento lleva su etiqueta **[C.1]** o **[C.2]**; lo no etiquetado es C.1.
> **Fuentes:** `PROMPT_FABLE_CULMINACION.md` §3.5, §3.8, §3.9, §3.10; `DECISIONES.md` DEC-011/012/013/024, DEC-020/021/031, DEC-022 §1, DEC-028, DEC-032, DEC-037/038, **DEC-039**, **DEC-041**, **DEC-043**; `RESEARCH-MODELO-ACTUAL.md` §0, §1.5, §2.1, §2.2, §4.3, §5.3; contratos congelados `paquetes/B-tomas-qr-sesiones/CONTRACT.md` (§2.5, §2.6, §2.9, §3.8) y `paquetes/B2-asignaturas-nm/CONTRACT.md` (§2.5, §2.6); `FINDINGS.md` (filas `paquete-C`); `AGENTS.md` §3.3 y §4; `REVIEW-1.md`.
> **Base de código leída:** `integracion/CULM-001` (A y B.1) y la BD de B.2 en `C:\Proyectos\GestionAsistencia-CULM001-B\GestioAsistenciaDB` (`feature/CULM-001-B2-tomas-qr`).
> **Convenciones de ruta:** `DB:` = `GestioAsistenciaDB/`, `BE:` = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, `BE-T:` = `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`, `FE:` = `GestioAsistenciaFrontend/src/app/`, `INFRA:` = `AsistenciasUCO-Infra/`. Todos bajo `C:\Proyectos\GestionAsistencia-CULM001\`.

---

## 0. Supuestos aplicados y precisiones de diseño

DEC-039 se aplica con las precisiones aceptadas en DEC-041 y DEC-043.

| ID | Supuesto / precisión | Estado |
| :--- | :--- | :--- |
| [SUPUESTO-C-01] | **Numeración (DEC-028):** migración `19_culm001_c_cancelacion_inasistencia_up|down.sql` (solo C.1; C.2 no tiene migración); semillas `40_culm001_c_catalogos.sql`, `40_culm001_c_parametros.sql`, `40_culm001_c_mensajes.sql`, `41_culm001_c_plantillas_notificacion.sql`; permisos `rol_asistencias_runtime_culm001_c.sql` (C.2 añade dos líneas); pruebas y fixtures `test_culm001_c_*`. Mensajes `ALR_`/`RCN_`; `SES_030`+ reservado sin uso. Golden path **1.5.0** en C.1 (§3.8) | — |
| [SUPUESTO-C-02] | **Dependencias duras.** C se construye sobre B.2 (horas, tomas, `uv_faltantes_toma`, `usp_consultar_resumen_asistencia_grupo_docente_paginado`, casos de uso de tomas) y B2 (`uv_resumen_*` **sin** `idPrograma`, `ufn_programas_grupo`, `ufn_programas_coordinador`, `ufn_programas_ambito_ejecutor`, fixture `_ambito_grupo_mixto.sql`). La migración 19 lo **verifica** y aborta si falta (§2.11, O-12) | — |
| [SUPUESTO-C-03] | El cruce también ocurre al **vencer** la sesión: además de la invocación tras cada escritura, un job evalúa por **marca de agua** los grupos con sesiones vencidas después de la última evaluación, solo periodos vigentes. La marca es `DATETIME2(3)` = instante de corte capturado al **inicio** de la evaluación, y la consulta de pendientes aplica un **solape** `ALERTA_INASISTENCIA/SOLAPE_MARCA_SEGUNDOS` (120): re-evaluar es idempotente y nunca se salta una sesión (O-8) | DEC-041 |
| [SUPUESTO-C-04] | Motor tras: lote legado, lote por toma, cierre de toma (manual y job), resolución **aprobada** de reclamo. **No** tras token/PIN (un `AN` no sube el porcentaje) | DEC-041 |
| [SUPUESTO-C-05] | Alerta `VIGENTE`/`SUPERADA`; una fila y una notificación por `(matrícula, tipo)`; reactivar no notifica; en un salto se notifica solo la de mayor `nivel`. Cada cambio de estado de alerta se audita (O-14) | — |
| [SUPUESTO-C-06] | Pérdida: `ALERTA_PERDIDA_INASISTENCIA` al estudiante; al docente la plantilla nueva `REVISION_CANCELACION_PENDIENTE` | DEC-041 |
| [SUPUESTO-C-07] | Transiciones en `TransicionRevisionCancelacion`; desde `RECHAZADA` el docente puede volver a `PROPONER` | DEC-041 |
| [SUPUESTO-C-08] | `PROPONER` y `APROBAR` exigen porcentaje actual `>=` umbral de pérdida (`RCN_006`) | DEC-041 |
| [SUPUESTO-C-09] | **Resolutor competente y escalamiento (O-2, DEC-043).** Resolutores = coordinadores activos de los programas que están a la vez en `EstudiantePrograma` del estudiante y entre los programas vigentes del grupo, **excluido quien propuso**; si no queda ninguno, **escala** a los decanos activos de las facultades de esos programas (jerarquía 3.8: el decano gestiona a los coordinadores), también excluido el proponente. Se calcula siempre en vivo con `ufn_revision_cancelacion_resolutores` (solo tablas base, O-1); si el coordinador se desactiva o cambia después de la propuesta, la revisión pasa a quien ocupe el cargo o al decano por la misma regla, y el job deja constancia (historial + auditoría + aviso) con `usp_actualizar_resolutores_revisiones_cancelacion`. `RCN_013` solo si no hay ni coordinador ni decano (o el estudiante no tiene programa en el grupo). Nadie resuelve su propia propuesta (`RCN_014`) | DEC-043 |
| [SUPUESTO-C-10] | **Cierre masivo (O-3, O-7).** Ya no escribe `CI` por conteo. Con el motor **habilitado y umbrales válidos**: el caso de uso del backend evalúa antes (con avisos) los grupos del periodo; el SP **no** evalúa (N-1) y, **dentro de su transacción y con bloqueos**, se bloquea (`RCN_012`) si hay revisiones que requieren acción (docente o resolutor) o pérdidas por horas sin revisión ya existentes, sin crear revisiones; si no, `A → F`. El SP devuelve siempre una sola fila. Con el motor **deshabilitado o umbrales inválidos** no se bloquea: `A → F` y `AuditoriaEvento` registra `motorHabilitado`, `umbralesValidos`, `perdidasSinRevision` y `revisionesPendientes` | DEC-041, DEC-043 |
| [SUPUESTO-C-11] | **SSE.** [C.1] Canal de grupo abierto a los 5 roles con ámbito por SP al suscribirse; política de audiencia ampliada; destinatarios como metadato **no serializado** de `RealtimeEvent` (la audiencia `DESTINATARIO` ya funciona por el canal de grupo). [C.2] Canal personal `GET /api/v1/realtime/stream/personal` | DEC-041 |
| [SUPUESTO-C-12] | Id de revisión/alerta ajeno → 404 indistinguible (`RCN_001`); filtro de grupo/programa fuera de ámbito → 403 (`SEC_002`/`COO_003`) | — |
| [SUPUESTO-C-13] | [C.1] Contador del menú del estudiante = alertas **vigentes** (`totalElementos` de `GET /estudiante/alertas?soloVigentes=true&tamano=1`): baja cuando la alerta pasa a `SUPERADA` (N-3). [C.2] Lectura por lista de ids, idempotente; la campana cuenta **no leídas** (`soloNoLeidas=true&tamano=1`) | — |
| [SUPUESTO-C-14] | Coordinador: ve las revisiones de **sus** estudiantes en todos los estados (actúa solo si es resolutor). Decano: ve las revisiones escaladas a él o que resolvió. El estudiante no ve el estado de la revisión | DEC-043 |
| [SUPUESTO-C-15] | La migración no evalúa; el primer pase del job evalúa y notifica (controlado por `ALERTA_INASISTENCIA/HABILITADA`) | DEC-041 |
| [SUPUESTO-C-16] | Las plantillas `ALERTA_*` pasan a `{umbral}`/`{limite}` solo si conservan el texto por defecto anterior | — |
| [SUPUESTO-C-17] | El `down` de la 19 no reactiva matrículas `CI` (archiva) y restaura el estado **inmediatamente anterior a C** (versión de B2, O-6) | DEC-043 |
| [SUPUESTO-C-18] | **Carga de contadores y listas (O-5).** Toda vista con datos que el SSE puede cambiar (campana, contadores, planilla, bandejas, vistas de grupo) carga por HTTP **al entrar** y recarga en cada **reconexión** del transporte (`CONNECTED` que sigue a `RECONNECTING` o `ERROR`; el primer `CONNECTED` no recarga porque la carga de entrada ya se hizo; §L del golden path) y por evento (N-2). Las vistas no suscritas al SSE cargan al entrar y tras cada acción propia. Nunca por temporizador. Eventos deduplicados por `eventId` | DEC-043 |
| [SUPUESTO-C-19] | La longitud del motivo (10–500) la valida solo la BD (`RCN_003`); el cliente exige "no vacío" | — |
| [SUPUESTO-C-20] | `Grupo.cantidadEstudiantesCancelaronAutomaticamente` pasa a significar "matrículas en `CI` al cierre" (ya no hay cancelación automática); se registra en el addendum de BD (O-14) | — |

---

### 0.1 Cambios respecto a v2 (REVIEW-2)

| Objeción | Cambio | Secciones |
| :--- | :--- | :--- |
| **N-1** (bloqueante; opción (a) del revisor, decisión del orquestador) | `usp_ejecutar_cierre_masivo_periodo` **ya no invoca** `usp_evaluar_alertas_inasistencia_grupo`. Dentro de su transacción cuenta como causa de `RCN_012` las revisiones pendientes y las **pérdidas sin revisión ya existentes** (no crea revisiones) y devuelve **una sola fila** de resultado. La evaluación con avisos queda solo en el motor (job y caso de uso del backend antes de llamar al cierre). Prueba C-DB-47 ("una sola fila", también con `INSERT … EXEC`) e IT de backend de que `RCN_012` llega como 409. Ajustadas C-DB-40, MASS_CLOSE, HOR_10 y TX-03 | [SUPUESTO-C-10], §2.5.1, §2.5.2, §2.6, §2.13, §3.4, §3.9 |
| **N-2** | Regla única de recarga: **carga al entrar**, recarga en cada **reconexión** (`CONNECTED` que sigue a `RECONNECTING` o `ERROR`; el primer `CONNECTED` no recarga) y por evento. Secuencia del spec `CONNECTING → CONNECTED → RECONNECTING → CONNECTED` + 1 evento = **exactamente 3 cargas**. Las vistas que en C.1 no se suscriben al SSE (página de alertas, bandejas de coordinador y decano, contadores del menú) solo cargan al entrar y tras cada acción propia, sin `connectionState$` | [SUPUESTO-C-18], §4.1–§4.8 |
| **N-3** | En C.1 el contador del menú del estudiante cuenta alertas **vigentes** (`estaVigente = 1`, de matrículas activas), que baja cuando una alerta pasa a `SUPERADA`; el contador de **no leídas** es de C.2 (campana). Nuevo parámetro `@soloVigentes` / `soloVigentes`. Si C.2 se difiere, se registra en `CLOSURE.md` | [SUPUESTO-C-13], §2.5.3, §3.2, §4.2, §4.3 |
| **N-4** | Orden de bloqueos y modo de lo que lee el cierre dentro de su transacción, coherente con el motor, la resolución y el lote; cubierto en C-DB-50 | §2.0, C-DB-50 |

Nada más cambia respecto a v2.

## 1. Alcance, decisiones aplicadas, HUs y hallazgos

### 1.1 Partición C.1 / C.2 (DEC-043)

| Subpaquete | Contenido | Rama |
| :--- | :--- | :--- |
| **C.1** (imprescindible para 3.5 y DEC-022 §1) | BD completa (catálogos, tablas, motor, decisión, resolución con escalamiento, resolutores, consultas, audiencias, cierre masivo, marcas del resumen del docente, migración 19); backend: motor + job + invocación tras escrituras, decisión del docente, resolución del coordinador y del decano, notificaciones, `RealtimeEvent.destinatariosUsuario`, apertura del canal de grupo por ámbito con la política ampliada, `GET /estudiante/alertas`; frontend: marcas y modal de decisión en la planilla, bandejas del coordinador y del decano, página de alertas del estudiante (móvil primero), suscripción al canal de grupo en el detalle de la materia (estudiante) y en las vistas de grupo del coordinador y del decano; contratos: golden path 1.5.0 y contrato de eventos (tipos y audiencias) | `feature/CULM-001-C1-cancelacion-inasistencia` |
| **C.2** (diferible si falta tiempo; no incumple 3.5) | `usp_marcar_alertas_inasistencia_leidas` + `PATCH /estudiante/alertas/lectura`; canal personal `GET /realtime/stream/personal` + `PersonalRealtimeService` + `AvisosRealtimeStore` + campana; bandeja propia del docente (`usp_consultar_revisiones_cancelacion_docente_paginado` + `GET /docente/revisiones-cancelacion` + página); `SOLICITUD_REVISION_RESUELTA` (HU042); segundo cambio del contrato de eventos (invariante "`grupoId` obligatorio") | `feature/CULM-001-C2-avisos-personales` (desde integración con C.1) |

Si C.2 no entra antes del 2026-11-13: el estudiante recibe sus alertas por correo, en la página de alertas y por el canal de grupo cuando está en el detalle de la materia; el docente decide desde la planilla; F-TRX-005 queda abierto (registrado en `CLOSURE.md`).

### 1.2 Alcance y exclusiones

| Incluido | Excluido |
| :--- | :--- |
| Lo de §1.1 | Comparativas/tendencia/consolidado por horas (D); reintento de notificaciones previo al outbox (deuda); edición de asistencias por coordinador o decano (prohibida); "des-cancelar" una matrícula `CI` (conducto externo); WebSocket, réplica o replay del SSE; vista de revisiones del administrador (diferido) |

### 1.3 Decisiones aplicadas

| Decisión | Aplicación |
| :--- | :--- |
| DEC-039 / DEC-041 | Diseño (§2–§4) con [SUPUESTO-C-03..C-11] |
| DEC-043 | Escalamiento al decano ([SUPUESTO-C-09]); cierre masivo con el motor apagado ([SUPUESTO-C-10]); partición C.1/C.2 |
| DEC-012 / DEC-024 | El motor lee `porcentajeInasistencia` por horas de `uv_resumen_*` (EX no cuenta; canceladas y no vencidas fuera) |
| DEC-020 / DEC-021 / DEC-031 | Resolutor por `EstudiantePrograma` ∩ programas del grupo; coordinador multi-programa: unión, `programaId` opcional |
| DEC-022 §1 | Canal de grupo abierto a los 5 roles con ámbito |
| DEC-028 / DEC-032 | Migración 19, semillas 40/41, golden path 1.5.0 después del 1.4.0 de B2 |
| DEC-037 / DEC-038 | Rutas nuevas en §3.7.2; 403 `NO_APPLICABLE_POLICY` hasta provisionar el PDP (B-01) |
| DEC-018 | Parámetros sembrados en BD con defecto igual en código |

### 1.4 HUs

| HU | Efecto | Sub |
| :--- | :--- | :--- |
| **HU026C** Notificaciones proactivas (15 % y 20 %) | Motor, alertas, notificación, SSE de grupo, página de alertas; campana en C.2 | C.1/C.2 |
| HU041 Resaltado en la planilla | Marca de alerta y estado de la revisión | C.1 |
| HU042 Notificación de resolución de reclamo | `SOLICITUD_REVISION_RESUELTA` (F-TRX-005) | C.2 |
| HU047 Cancelar sesión | `SESION_CANCELADA` al estudiante y al ámbito | C.1 |
| HU059 Estados | Matrícula `CI` visible como "Cancelado por inasistencia" | C.1 |
| HU066 / HU070 | Sin cambio de fórmula | — |
| HU174 Cierre masivo | Regla por horas y bloqueo condicionado ([SUPUESTO-C-10]) | C.1 |
| HU013 Alerta visual del estudiante | Complementada con la página de alertas (y campana en C.2) | C.1/C.2 |

### 1.5 Hallazgos que cierra C

| Hallazgo | Resolución | Sub |
| :--- | :--- | :--- |
| **F-EST-S05** sin SSE en vistas del estudiante | Canal de grupo en el detalle de la materia (C.1); canal personal tras el login (C.2) | C.1 |
| **F-TRX-005** HU042 sin evento SSE | `SOLICITUD_REVISION_RESUELTA` | C.2 |
| **F-TRX-006** (dup F-DEC-012) 403 del stream a otros roles | Gateway por ámbito + suscripción en vistas de grupo de coordinador y decano | C.1 |
| **F-EST-007** (dup F-EST-S08, F-TRX-007) sin alertas ni aviso de cancelación | Motor, página de alertas, `SESION_CANCELADA` al estudiante (C.1); campana (C.2) | C.1 |

---

## 2. Base de datos (`GestioAsistenciaDB`)

### 2.0 Reglas comunes

Las de B §2.0: `SET NOCOUNT ON; SET XACT_ABORT ON;`; ownership transaccional (propia o `SAVE TRANSACTION`); `CATCH` que revierte lo propio, propaga `XACT_STATE() = -1` con `THROW` y si no responde `SYS_001`; `@parametro IS NULL` explícito; correlación, RBAC (`usp_validar_permiso_rbac_usuario_interno`), titularidad, mensajes de catálogo y tupla canónica. Consultas `usp_consultar_*` con `THROW 51000` si la validación falla, `OFFSET/FETCH`, `COUNT(1) OVER()`, `PAG_001`.

- **Cero datos quemados:** estados, tipos y decisiones por banderas y por la tabla de transiciones; estados de matrícula por parámetro (`MATRICULA/ESTADO_INSCRITA` existente; `MATRICULA/ESTADO_CANCELADA_INASISTENCIA`, `MATRICULA/ESTADO_FINALIZADA` nuevos); umbrales por la clave de parámetro de cada tipo. Únicos literales: los códigos de perfil del RBAC (`'DOCENTE'`, `'COORDINADOR'`, `'DECANO'`, `'ESTUDIANTE'`), como en todos los SP actuales.
- **Funciones:** toda función nueva lee **solo tablas base** (regla de B2 §2.6: `deploy_schema.ps1` despliega `functions/` en una pasada antes que `views/`, y una TVF inline no admite resolución diferida). Los SP sí pueden usar vistas y las funciones de B2.
- **Orden de bloqueos** (sin ciclos con A y B): motor `EvaluacionAlertaGrupo → AlertaInasistencia → RevisionCancelacion` (lee `uv_resumen_*` con bloqueos compartidos de corta duración, sin pistas); decisión del docente `RevisionCancelacion`; resolución `RevisionCancelacion → EstudianteGrupo`; actualización de resolutores `RevisionCancelacion`.
- **Cierre masivo dentro de su transacción (N-4)**, en este orden y modo: (1) `RevisionCancelacion` de las matrículas del periodo `WITH (UPDLOCK, HOLDLOCK)`; (2) `EstudianteGrupo` del periodo `WITH (UPDLOCK, HOLDLOCK)`; (3) lectura de `uv_resumen_asistencia_estudiante_grupo` (por debajo `Asistencia`, `DetalleAsistencia`, `TomaAsistencia`, `Sesion`, `SesionCancelacion`) en `READ COMMITTED` sin pistas: bloqueos compartidos que se liberan al leer cada fila y no se retienen; (4) `UPDATE` de `EstudianteGrupo` (ya bloqueado) y de `Grupo` del periodo (exclusivo) para los contadores; (5) `INSERT` en `AuditoriaEvento`. **Coherencia con el motor:** el motor toma `RevisionCancelacion` solo después de `EvaluacionAlertaGrupo` y `AlertaInasistencia`, que el cierre no toca, y nunca bloquea `EstudianteGrupo` ni `Grupo`; si choca con el cierre espera en `RevisionCancelacion` sin retener nada que el cierre necesite (sus lecturas de `uv_resumen_*` son compartidas y ya terminaron). **Con el lote de B** (`Sesion → TomaAsistencia → … → EstudianteGrupo → Asistencia → DetalleAsistencia`): el lote toma `EstudianteGrupo` **antes** que `Asistencia`; si el cierre ya tiene `EstudianteGrupo`, el lote espera ahí sin haber tocado `Asistencia`; si el lote llegó antes, el cierre espera en `EstudianteGrupo` sin retener nada que el lote necesite. Además, el cierre corre sobre un periodo terminado, cuya ventana SES-01 ya no admite lotes. **Con la resolución:** mismo orden (`RevisionCancelacion → EstudianteGrupo`). El retiro HU051 toma `Grupo → EstudianteGrupo` y el registro de B `Sesion → … → EstudianteGrupo → Asistencia`: la resolución no toma `Grupo` y el cierre solo lo toma al final con todas sus matrículas ya bloqueadas; el retiro en un periodo terminado ya no aplica (`RET_003`), así que no hay espera circular posible.
- **Auditoría:** toda mutación inserta en `dbo.AuditoriaEvento` (patrón `usp_retirar_estudiante_grupo`; `actorType = USER` con usuario, `SYSTEM` para motor y job; `httpMethod`/`path` del endpoint o `JOB`/`/jobs/alertas-inasistencia`; `metadata` JSON con estado anterior/nuevo, decisión, motivo, porcentaje y perfil del actor) y cada transición de revisión en `RevisionCancelacionHistorial`.

### 2.1 Catálogos (tablas + semilla `40_culm001_c_catalogos.sql`, MERGE por id)

```sql
-- DB:schema/tables/TipoAlertaInasistencia.sql
CREATE TABLE dbo.TipoAlertaInasistencia (
    id                       UNIQUEIDENTIFIER NOT NULL,
    codigo                   NVARCHAR(20)     NOT NULL,   -- ADVERTENCIA | PERDIDA
    nombre                   NVARCHAR(50)     NOT NULL,
    nivel                    TINYINT          NOT NULL,
    grupoParametroUmbral     VARCHAR(100)     NOT NULL,   -- ASISTENCIA
    claveParametroUmbral     VARCHAR(100)     NOT NULL,   -- UMBRAL_ALERTA_ADVERTENCIA | UMBRAL_ALERTA_PERDIDA
    tipoPlantillaEstudiante  VARCHAR(60)      NOT NULL,   -- ALERTA_RIESGO_INASISTENCIA | ALERTA_PERDIDA_INASISTENCIA
    codigoMensajeUsuario     VARCHAR(100)     NOT NULL,   -- ALR_010 | ALR_011
    creaRevisionCancelacion  BIT              NOT NULL,
    CONSTRAINT PK_TipoAlertaInasistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_TipoAlertaInasistencia_codigo UNIQUE (codigo),
    CONSTRAINT UQ_TipoAlertaInasistencia_nivel UNIQUE (nivel)
);
CREATE UNIQUE INDEX UX_TipoAlertaInasistencia_creaRevision ON dbo.TipoAlertaInasistencia (creaRevisionCancelacion)
    WHERE creaRevisionCancelacion = 1;
--   ('7C1E0C10-5E51-4C0A-9A01-000000000001', N'ADVERTENCIA', N'Riesgo de pérdida por inasistencia', 1, 'ASISTENCIA', 'UMBRAL_ALERTA_ADVERTENCIA', 'ALERTA_RIESGO_INASISTENCIA',  'ALR_010', 0)
--   ('7C1E0C10-5E51-4C0A-9A01-000000000002', N'PERDIDA',     N'Pérdida por inasistencia',           2, 'ASISTENCIA', 'UMBRAL_ALERTA_PERDIDA',     'ALERTA_PERDIDA_INASISTENCIA', 'ALR_011', 1)

-- DB:schema/tables/EstadoAlertaInasistencia.sql
CREATE TABLE dbo.EstadoAlertaInasistencia (
    id UNIQUEIDENTIFIER NOT NULL, codigo NVARCHAR(20) NOT NULL, nombre NVARCHAR(50) NOT NULL, estaVigente BIT NOT NULL,
    CONSTRAINT PK_EstadoAlertaInasistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_EstadoAlertaInasistencia_codigo UNIQUE (codigo),
    CONSTRAINT UQ_EstadoAlertaInasistencia_estaVigente UNIQUE (estaVigente)
);
--   ('7C1E0C20-5E51-4C0A-9A01-000000000001', N'VIGENTE',  N'Vigente',  1)
--   ('7C1E0C20-5E51-4C0A-9A01-000000000002', N'SUPERADA', N'Superada', 0)

-- DB:schema/tables/EstadoRevisionCancelacion.sql
CREATE TABLE dbo.EstadoRevisionCancelacion (
    id                       UNIQUEIDENTIFIER NOT NULL,
    codigo                   NVARCHAR(20)     NOT NULL,
    nombre                   NVARCHAR(60)     NOT NULL,
    orden                    TINYINT          NOT NULL,
    esInicial                BIT              NOT NULL,
    requiereAccionDocente    BIT              NOT NULL,
    requiereAccionResolutor  BIT              NOT NULL,   -- coordinador o, por escalamiento, decano
    conservaMatricula        BIT              NOT NULL,
    cancelaMatricula         BIT              NOT NULL,
    esFinal                  BIT              NOT NULL,
    CONSTRAINT PK_EstadoRevisionCancelacion PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_EstadoRevisionCancelacion_codigo UNIQUE (codigo),
    CONSTRAINT CK_EstadoRevisionCancelacion_accion CHECK (NOT (requiereAccionDocente = 1 AND requiereAccionResolutor = 1))
);
CREATE UNIQUE INDEX UX_EstadoRevisionCancelacion_esInicial ON dbo.EstadoRevisionCancelacion (esInicial) WHERE esInicial = 1;
CREATE UNIQUE INDEX UX_EstadoRevisionCancelacion_cancela   ON dbo.EstadoRevisionCancelacion (cancelaMatricula) WHERE cancelaMatricula = 1;
--   id                                       codigo               nombre                                   ord ini doc res cons canc fin
--   ('7C1E0C30-5E51-4C0A-9A01-000000000001', N'PENDIENTE_DOCENTE', N'Pendiente de decisión del docente',     1,  1,  1,  0,  0,   0,   0)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000002', N'MANTENIDA',         N'Estudiante mantenido por el docente',   2,  0,  0,  0,  1,   0,   0)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000003', N'PROPUESTA',         N'Cancelación propuesta',                 3,  0,  0,  1,  0,   0,   0)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000004', N'APROBADA',          N'Cancelación aprobada',                  4,  0,  0,  0,  0,   1,   1)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000005', N'RECHAZADA',         N'Cancelación rechazada',                 5,  0,  0,  0,  1,   0,   0)

-- DB:schema/tables/TransicionRevisionCancelacion.sql  ([SUPUESTO-C-07])
CREATE TABLE dbo.TransicionRevisionCancelacion (
    id                          UNIQUEIDENTIFIER NOT NULL,
    estadoOrigen                UNIQUEIDENTIFIER NOT NULL,   -- FK EstadoRevisionCancelacion
    codigoDecision              NVARCHAR(20)     NOT NULL,   -- MANTENER | PROPONER | APROBAR | RECHAZAR (valor de la API)
    esDecisionResolutor         BIT              NOT NULL,   -- 0 = docente titular; 1 = resolutor (coordinador o decano escalado)
    estadoDestino               UNIQUEIDENTIFIER NOT NULL,
    exigeUmbralPerdida          BIT              NOT NULL,   -- RCN_006
    exigeResolutorDisponible    BIT              NOT NULL,   -- RCN_013
    codigoMensajeExito          VARCHAR(100)     NOT NULL,   -- con escalamiento el SP usa RCN_015
    tipoPlantillaNotificacion   VARCHAR(60)      NULL,
    CONSTRAINT PK_TransicionRevisionCancelacion PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_TransicionRevisionCancelacion_origen_decision UNIQUE (estadoOrigen, codigoDecision)
);
--   ('7C1E0C40-…-000000000001', PENDIENTE_DOCENTE, N'MANTENER', 0, MANTENIDA, 0, 0, 'RCN_007', NULL)
--   ('7C1E0C40-…-000000000002', PENDIENTE_DOCENTE, N'PROPONER', 0, PROPUESTA, 1, 1, 'RCN_008', 'PROPUESTA_CANCELACION')
--   ('7C1E0C40-…-000000000003', MANTENIDA,         N'PROPONER', 0, PROPUESTA, 1, 1, 'RCN_008', 'PROPUESTA_CANCELACION')
--   ('7C1E0C40-…-000000000004', RECHAZADA,         N'PROPONER', 0, PROPUESTA, 1, 1, 'RCN_008', 'PROPUESTA_CANCELACION')
--   ('7C1E0C40-…-000000000005', PROPUESTA,         N'APROBAR',  1, APROBADA,  1, 0, 'RCN_009', 'CANCELACION_APROBADA')
--   ('7C1E0C40-…-000000000006', PROPUESTA,         N'RECHAZAR', 1, RECHAZADA, 0, 0, 'RCN_010', 'CANCELACION_RECHAZADA')
```

Vistas de catálogo (solo consulta, patrón CAT-01): `uv_tipo_alerta_inasistencia`, `uv_estado_alerta_inasistencia`, `uv_estado_revision_cancelacion`, `uv_transicion_revision_cancelacion` (con `codigoEstadoOrigen`, `codigoEstadoDestino`). FKs en `zz_foreign_keys.sql`.

### 2.2 Tablas nuevas

```sql
-- DB:schema/tables/AlertaInasistencia.sql
CREATE TABLE dbo.AlertaInasistencia (
    id                          UNIQUEIDENTIFIER NOT NULL,
    estudianteGrupo             UNIQUEIDENTIFIER NOT NULL,   -- FK EstudianteGrupo
    tipo                        UNIQUEIDENTIFIER NOT NULL,   -- FK TipoAlertaInasistencia
    estado                      UNIQUEIDENTIFIER NOT NULL,   -- FK EstadoAlertaInasistencia
    porcentajeCruce             DECIMAL(5,2)     NOT NULL,
    umbralCruce                 DECIMAL(5,2)     NOT NULL,
    horasFaltaCruce             DECIMAL(12,6)    NOT NULL,
    horasDictadasCruce          DECIMAL(12,6)    NOT NULL,
    fechaCruceUtc               DATETIME2(3)     NOT NULL,
    idCorrelacionCruce          UNIQUEIDENTIFIER NOT NULL,
    porcentajeUltimaEvaluacion  DECIMAL(5,2)     NOT NULL,
    fechaUltimaEvaluacionUtc    DATETIME2(3)     NOT NULL,
    fechaLecturaUtc             DATETIME2(3)     NULL,       -- [C.2] lectura del estudiante (la columna existe desde C.1)
    CONSTRAINT PK_AlertaInasistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT CK_AlertaInasistencia_porcentajes CHECK (porcentajeCruce BETWEEN 0 AND 100 AND porcentajeUltimaEvaluacion BETWEEN 0 AND 100)
);
CREATE UNIQUE INDEX UX_AlertaInasistencia_EstudianteGrupo_Tipo ON dbo.AlertaInasistencia (estudianteGrupo, tipo);
CREATE INDEX IX_AlertaInasistencia_noLeidas ON dbo.AlertaInasistencia (estudianteGrupo) INCLUDE (fechaLecturaUtc, fechaCruceUtc);

-- DB:schema/tables/RevisionCancelacion.sql
CREATE TABLE dbo.RevisionCancelacion (
    id                           UNIQUEIDENTIFIER NOT NULL,
    estudianteGrupo              UNIQUEIDENTIFIER NOT NULL,   -- FK EstudianteGrupo
    estado                       UNIQUEIDENTIFIER NOT NULL,   -- FK EstadoRevisionCancelacion
    alertaOrigen                 UNIQUEIDENTIFIER NOT NULL,   -- FK AlertaInasistencia
    porcentajeCreacion           DECIMAL(5,2)     NOT NULL,
    horasFaltaCreacion           DECIMAL(12,6)    NOT NULL,
    horasDictadasCreacion        DECIMAL(12,6)    NOT NULL,
    fechaCreacionUtc             DATETIME2(3)     NOT NULL,
    idCorrelacionCreacion        UNIQUEIDENTIFIER NOT NULL,
    codigoDecisionDocente        NVARCHAR(20)     NULL,
    motivoDocente                NVARCHAR(1000)   NULL,
    usuarioDecisionDocente       UNIQUEIDENTIFIER NULL,       -- FK Usuario (quien propone queda excluido como resolutor)
    porcentajeDecisionDocente    DECIMAL(5,2)     NULL,
    fechaDecisionDocenteUtc      DATETIME2(3)     NULL,
    codigoPerfilResolutorActual  NVARCHAR(20)     NULL,       -- COORDINADOR | DECANO | NULL (sin resolutor); se fija al proponer y lo actualiza el job
    huellaResolutoresActual      VARBINARY(32)    NULL,       -- SHA-256 de los idUsuario resolutores ordenados (detecta reasignaciones)
    fechaEscalamientoUtc         DATETIME2(3)     NULL,       -- última vez que pasó a DECANO
    codigoDecisionResolucion     NVARCHAR(20)     NULL,
    motivoResolucion             NVARCHAR(1000)   NULL,
    usuarioResolucion            UNIQUEIDENTIFIER NULL,       -- FK Usuario
    codigoPerfilResolucion       NVARCHAR(20)     NULL,       -- COORDINADOR | DECANO
    programaResolucion           UNIQUEIDENTIFIER NULL,       -- FK Programa
    porcentajeResolucion         DECIMAL(5,2)     NULL,
    fechaResolucionUtc           DATETIME2(3)     NULL,
    estadoMatriculaAnterior      UNIQUEIDENTIFIER NULL,       -- FK EstadoEstudianteGrupo
    fechaActualizacionUtc        DATETIME2(3)     NOT NULL,
    CONSTRAINT PK_RevisionCancelacion PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_RevisionCancelacion_EstudianteGrupo UNIQUE (estudianteGrupo)
);
CREATE INDEX IX_RevisionCancelacion_estado ON dbo.RevisionCancelacion (estado) INCLUDE (estudianteGrupo, fechaCreacionUtc);

-- DB:schema/tables/RevisionCancelacionHistorial.sql  (trazabilidad; sin vista de consulta en C, O-14)
CREATE TABLE dbo.RevisionCancelacionHistorial (
    id                      UNIQUEIDENTIFIER NOT NULL,
    revision                UNIQUEIDENTIFIER NOT NULL,   -- FK RevisionCancelacion
    estadoAnterior          UNIQUEIDENTIFIER NULL,
    estadoNuevo             UNIQUEIDENTIFIER NOT NULL,
    codigoEvento            NVARCHAR(20)     NOT NULL,   -- CREAR | MANTENER | PROPONER | APROBAR | RECHAZAR | ESCALAR | REASIGNAR
    motivo                  NVARCHAR(1000)   NULL,
    usuarioActor            UNIQUEIDENTIFIER NULL,       -- NULL = sistema
    codigoPerfilActor       NVARCHAR(20)     NULL,
    codigoPerfilResolutor   NVARCHAR(20)     NULL,       -- resolutor vigente tras el evento
    porcentajeInasistencia  DECIMAL(5,2)     NOT NULL,
    fechaUtc                DATETIME2(3)     NOT NULL,
    idCorrelacion           UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_RevisionCancelacionHistorial PRIMARY KEY CLUSTERED (id)
);
CREATE INDEX IX_RevisionCancelacionHistorial_revision ON dbo.RevisionCancelacionHistorial (revision, fechaUtc);

-- DB:schema/tables/EvaluacionAlertaGrupo.sql  ([SUPUESTO-C-03], O-8)
CREATE TABLE dbo.EvaluacionAlertaGrupo (
    grupo                UNIQUEIDENTIFIER NOT NULL,   -- PK y FK Grupo
    fechaCorteUtc        DATETIME2(3)     NOT NULL,   -- instante capturado al INICIO de la última evaluación
    idCorrelacionUltima  UNIQUEIDENTIFIER NOT NULL,
    totalEvaluaciones    INT              NOT NULL CONSTRAINT DF_EvaluacionAlertaGrupo_total DEFAULT (0),
    CONSTRAINT PK_EvaluacionAlertaGrupo PRIMARY KEY CLUSTERED (grupo)
);
```

Patrón idempotente del repo (`IF OBJECT_ID … IS NULL`, guard de columnas como `AuditoriaEvento.sql`). La longitud del motivo la acota `REVISION_CANCELACION/MOTIVO_LONGITUD_MAXIMA` (500); el SP usa `MIN(parámetro, 1000)`.

### 2.3 Funciones nuevas (solo tablas base, O-1)

| Función | Firma | Regla |
| :--- | :--- | :--- |
| `ufn_umbral_alerta_inasistencia` | `(@idTipoAlerta UNIQUEIDENTIFIER) RETURNS DECIMAL(5,2)` (escalar) | Lee `TipoAlertaInasistencia` y `CatalogoParametro` (tablas base) con la misma regla que `ufn_obtener_parametro` (`valor`, si no `valorDefecto`) y `TRY_CAST`; `NULL` si falta o no es numérico |
| `ufn_revision_cancelacion_resolutores` | `(@idEstudianteGrupo UNIQUEIDENTIFIER, @idUsuarioExcluido UNIQUEIDENTIFIER) RETURNS TABLE (idUsuario, codigoPerfil, idPrograma, idFacultad, esEscalamiento)` (inline) | **Programas competentes** = programas activos del `EstudiantePrograma` del estudiante que además son programas vigentes del grupo, con la **misma regla S1 de B2** (`AsignaturaPlanEstudio` vigente en el periodo del grupo → `SemestrePlanEstudio` → `PlanEstudio` → `Programa`; fecha local con `TIEMPO/ZONA_HORARIA_SQLSERVER` de `CatalogoParametro`). **Coordinadores** = `Programa.coordinador → Coordinador (estado = 1) → Usuario (estado = 1)` con `Programa.estado = 1` (regla de actividad de `uv_coordinador` l.29), `usuario <> @idUsuarioExcluido`, `esEscalamiento = 0`. **Decanos** (solo si la rama anterior queda vacía) = `Programa.facultad → Facultad (estado = 1) → Facultad.decano → Decano (estado = 1) → Usuario (estado = 1)`, `usuario <> @idUsuarioExcluido`, `esEscalamiento = 1`. `DISTINCT` por `(idUsuario, idPrograma)`. Tablas leídas: `EstudianteGrupo`, `Grupo`, `PeriodoAcademico`, `EstudiantePrograma`, `AsignaturaPlanEstudio`, `SemestrePlanEstudio`, `PlanEstudio`, `Programa`, `Facultad`, `Coordinador`, `Decano`, `Usuario`, `CatalogoParametro`. No llama a ninguna función de usuario |

**Paridad (O-1):** la regla de "programas vigentes del grupo" se replica respecto a `ufn_programas_grupo` (B2) para no depender de vistas ni del orden de despliegue; la prueba C-DB-63 compara, para todas las matrículas de los fixtures de A, B2 y C, los programas competentes con `EstudiantePrograma ∩ ufn_programas_grupo` y falla ante cualquier diferencia. La C-DB-62 despliega en una BD vacía.

### 2.4 Vistas nuevas

| Vista | Columnas | Grano |
| :--- | :--- | :--- |
| `uv_alerta_inasistencia` | `id, idEstudianteGrupo, idEstudiante, idUsuarioEstudiante, nombreCompletoEstudiante, idGrupo, codigoGrupo, nombreGrupo, idAsignatura, nombreAsignatura, idPeriodoAcademico, idDocenteTitular, idUsuarioDocenteTitular, codigoEstadoMatricula, idTipo, codigoTipo, nombreTipo, nivel, codigoMensajeUsuario, idEstado, codigoEstado, estaVigente, porcentajeCruce, umbralCruce, horasFaltaCruce, horasDictadasCruce, fechaCruceUtc, porcentajeUltimaEvaluacion, fechaUltimaEvaluacionUtc, fechaLecturaUtc, estaLeida` | 1 por alerta |
| `uv_revision_cancelacion` | `id, idEstudianteGrupo, idEstudiante, idUsuarioEstudiante, nombreCompletoEstudiante, idGrupo, codigoGrupo, nombreGrupo, idAsignatura, nombreAsignatura, idPeriodoAcademico, idDocenteTitular, idUsuarioDocenteTitular, nombreCompletoDocente, codigoEstadoMatricula, idEstado, codigoEstado, nombreEstado, ordenEstado, requiereAccionDocente, requiereAccionResolutor, conservaMatricula, cancelaMatricula, esFinal, porcentajeCreacion, horasFaltaCreacion, horasDictadasCreacion, fechaCreacionUtc, codigoDecisionDocente, motivoDocente, idUsuarioDecisionDocente, porcentajeDecisionDocente, fechaDecisionDocenteUtc, codigoPerfilResolutorActual, fechaEscalamientoUtc, codigoDecisionResolucion, motivoResolucion, idUsuarioResolucion, nombreCompletoResolucion, codigoPerfilResolucion, idProgramaResolucion, nombreProgramaResolucion, porcentajeResolucion, fechaResolucionUtc, fechaActualizacionUtc` | 1 por revisión |
| `uv_marca_inasistencia_estudiante_grupo` | `idEstudianteGrupo, tieneAdvertenciaVigente, fechaAdvertenciaUtc, tienePerdidaVigente, fechaPerdidaUtc, idRevisionCancelacion, codigoEstadoRevision, nombreEstadoRevision, requiereAccionDocente, requiereAccionResolutor, conservaMatricula, esFinalRevision, codigoPerfilResolutorActual` | 1 por matrícula con alerta o revisión |

Ninguna lee `uv_grupo_programa` ni `uv_resumen_*`. La vista de historial de la v1 se retira (sin consumidor, O-14); la tabla queda para trazabilidad y auditoría.

### 2.5 Procedimientos almacenados nuevos

#### 2.5.1 `usp_evaluar_alertas_inasistencia_grupo` (motor)

```sql
(@idGrupo UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @idEstudianteGrupo UNIQUEIDENTIFIER = NULL)
-- Salida (1 fila): tupla + alertasCreadas, alertasSuperadas, alertasReactivadas, revisionesCreadas INT, novedadesJSON NVARCHAR(MAX)
```

Comando de sistema sin usuario (patrón `usp_aplicar_festivos_automatico`), invocado solo por el backend (tras escrituras y antes del cierre masivo) y por el job; **ningún SP lo invoca** (N-1).

1. Correlación; `@idGrupo IS NULL` → `GEN_002`; grupo inexistente → `usp_validar_grupo_exista_por_id_interno`; `@idEstudianteGrupo` de otro grupo → `ALR_006`.
2. `ALERTA_INASISTENCIA/HABILITADA <> 'true'` → `estadoResultado = 1`, `ALR_001`, contadores 0, `novedadesJSON = '[]'`, sin escrituras.
3. Umbral de cada tipo (`ufn_umbral_alerta_inasistencia`); alguno `NULL` → `ALR_002`, `estadoResultado = 0`, sin escrituras.
4. `@corte = CAST(SYSUTCDATETIME() AS DATETIME2(3))` **al inicio** (O-8). Transacción propia o `SAVE TRANSACTION sp_evaluar_alertas_grupo`. `MERGE dbo.EvaluacionAlertaGrupo WITH (UPDLOCK, HOLDLOCK)` sobre el grupo: serializa las evaluaciones del mismo grupo.
5. `#candidatos` = `uv_resumen_asistencia_estudiante_grupo` del grupo con `codigoEstadoEstudiante = MATRICULA/ESTADO_INSCRITA` (y `@idEstudianteGrupo` si viene). EX no cuenta (porcentaje por horas de B.2).
6. Por cada tipo (orden por `nivel`): **cruce nuevo** → `INSERT AlertaInasistencia` (`VIGENTE`) si `porcentaje >= umbral` y no existe `(matrícula, tipo)` (`NOT EXISTS … WITH (UPDLOCK, HOLDLOCK)` + índice único); **superada** (`< umbral`) y **reactivada** (`>= umbral` desde `SUPERADA`) por `UPDATE`; todas actualizan `porcentajeUltimaEvaluacion`/`fechaUltimaEvaluacionUtc`.
7. Por cada alerta **recién creada** de un tipo con `creaRevisionCancelacion = 1`: `INSERT RevisionCancelacion` en el estado inicial si la matrícula no tiene revisión + historial `CREAR` (actor `NULL`).
8. `AuditoriaEvento` (`SYSTEM`): `ALERTA_INASISTENCIA_REGISTRADA` por alerta creada, `ALERTA_INASISTENCIA_ACTUALIZADA` por cada paso a `SUPERADA` o reactivación (O-14), `REVISION_CANCELACION_CREADA` por revisión.
9. `UPDATE EvaluacionAlertaGrupo SET fechaCorteUtc = @corte, idCorrelacionUltima, totalEvaluaciones += 1`; `COMMIT` si es propia; `ALR_003`.

`novedadesJSON`: un elemento por alerta creada con `idAlerta, codigoTipo, nivel, esPrincipal, porcentajeInasistencia, umbral, horasFalta, horasDictadas, idEstudianteGrupo, idGrupo, codigoGrupo, nombreGrupo, nombreAsignatura, tipoPlantillaEstudiante, estudiante {idEstudiante, idUsuario, nombreCompleto, correo}, docente {idDocente, idUsuario, nombreCompleto, correo}, idRevisionCreada`. `esPrincipal = 1` solo en la de mayor `nivel` creada para la matrícula en esta evaluación. El correo es de uso interno del `NotificacionPort`.

#### 2.5.2 `usp_consultar_grupos_pendientes_evaluacion_alertas`

```sql
(@idCorrelacion UNIQUEIDENTIFIER, @tamanoLote INT = NULL, @idPeriodoAcademico UNIQUEIDENTIFIER = NULL)
-- Filas: idGrupo, fechaCorteUtc (NULL si nunca), fechaFinSesionVencidaMasReciente
```

Sin `@idPeriodoAcademico` (job): grupos de periodos no terminados (fecha local) con matrículas `A` y alguna sesión de `uv_cumplimiento_sesion_grupo` con `estaVencida = 1 AND tieneRegistroAsistencia = 1 AND fechaHoraFin > DATEADD(SECOND, -ALERTA_INASISTENCIA/SOLAPE_MARCA_SEGUNDOS, ISNULL(fechaCorteUtc, '19000101'))`; orden por `fechaCorteUtc` (nulos primero); `TOP (@tamanoLote)` con defecto `ALERTA_INASISTENCIA/LOTE_EVALUACION_AUTOMATICA`. Con el solape, una sesión que vence entre el corte y la lectura, o cuyo fin cae en el mismo milisegundo redondeado, se vuelve a considerar en el pase siguiente (como máximo `solape / tick` re-evaluaciones idempotentes). Con `@idPeriodoAcademico` (lo usa el caso de uso del cierre en el backend, nunca el SP del cierre): todos los grupos del periodo con matrículas `A`. `@tamanoLote < 1` → `PAG_001`.

#### 2.5.3 `usp_consultar_alertas_estudiante`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = 20,
 @soloNoLeidas BIT = 0, @soloVigentes BIT = 0, @idGrupo UNIQUEIDENTIFIER = NULL)
-- Filas: uv_alerta_inasistencia (sin ids de usuario ni de docente) + porcentajeActual, umbralPerdidaActual, totalRegistros
```

RBAC `ESTUDIANTE`; solo sus alertas (todas sus matrículas, también `CI`); `@idGrupo` sin matrícula propia → `SEC_002`. Orden `estaLeida ASC, fechaCruceUtc DESC`. Nunca columnas de revisión. `@soloVigentes = 1` → `estaVigente = 1` y matrícula `A` (contador del menú en C.1, N-3). `@soloNoLeidas` existe desde C.1 (la columna es de C.1), pero solo tiene sentido con el comando de marcar de C.2 (campana).

#### 2.5.4 [C.2] `usp_marcar_alertas_inasistencia_leidas`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @alertasJSON NVARCHAR(MAX))   -- tupla + marcadas INT
```

RBAC `ESTUDIANTE`; arreglo de UUID no vacío, sin duplicados, máximo `ALERTA_INASISTENCIA/MAXIMO_LECTURA_POR_SOLICITUD` (si no `ALR_004`); solo marca alertas propias con `fechaLecturaUtc IS NULL`; ids ajenos o ya leídos se ignoran (idempotente); `ALR_005`.

#### 2.5.5 [C.2] `usp_consultar_revisiones_cancelacion_docente_paginado`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = 20,
 @soloPendientes BIT = 0, @codigoEstado NVARCHAR(20) = NULL, @idGrupo UNIQUEIDENTIFIER = NULL)
-- Filas: uv_revision_cancelacion + porcentajeActual, horasFaltaActual, horasDictadasActual, umbralPerdida, accionesPermitidas, totalRegistros
```

RBAC `DOCENTE`; grupos donde es titular; `@idGrupo` ajeno → `SEC_002`; `@codigoEstado` inexistente → `RCN_002`; `@soloPendientes` → `requiereAccionDocente = 1`; `accionesPermitidas` = `STRING_AGG(codigoDecision, ',')` de las transiciones con `esDecisionResolutor = 0` desde el estado actual (vacío si la matrícula no es `A`). Orden `requiereAccionDocente DESC, fechaCreacionUtc ASC`.

#### 2.5.6 `usp_decidir_revision_cancelacion` (docente)

```sql
(@idRevision UNIQUEIDENTIFIER, @codigoDecision NVARCHAR(20), @motivo NVARCHAR(MAX), @idCorrelacion UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL)
-- Salida: tupla + idRevision, codigoEstadoAnterior, codigoEstadoNuevo, codigoDecision, sinCambios BIT, idGrupo, idEstudianteGrupo,
--         idEstudiante, porcentajeActual, tipoPlantillaNotificacion, codigoPerfilResolutor, esEscalamiento BIT
```

1. Correlación; `GEN_002`; RBAC `DOCENTE`.
2. `@codigoDecision` (`UPPER(TRIM)`) con transición `esDecisionResolutor = 0` → si no, `RCN_002`.
3. Motivo `TRIM` entre `MOTIVO_LONGITUD_MINIMA` y `MIN(MAXIMA, 1000)` → `RCN_003`.
4. Transacción; `RevisionCancelacion WITH (UPDLOCK, HOLDLOCK)` con `Grupo.docente` = docente del ejecutor → si no hay fila, `RCN_001`.
5. Matrícula distinta de `A` → `RCN_005`.
6. Idempotencia (`MANTENIDA`+`MANTENER`, `PROPUESTA`+`PROPONER` con la misma última decisión del docente) → `RCN_011`, `sinCambios = 1`.
7. Sin transición desde el estado actual → `RCN_004`.
8. `exigeUmbralPerdida` incumplido → `RCN_006`.
9. `exigeResolutorDisponible = 1`: `#resolutores = ufn_revision_cancelacion_resolutores(@idEstudianteGrupo, @idUsuarioEjecutor)` (excluye a quien propone, O-2); vacío → `RCN_013`. Si todos tienen `esEscalamiento = 1`: `codigoPerfilResolutorActual = 'DECANO'`, `fechaEscalamientoUtc`, historial `ESCALAR` (además del de `PROPONER`) y `AuditoriaEvento` `ESCALAR_REVISION_CANCELACION` con `metadata {motivoEscalamiento: SIN_COORDINADOR_DISPONIBLE, programas, decanos}`; si no, `'COORDINADOR'`. `huellaResolutoresActual` = `HASHBYTES('SHA2_256', ids ordenados)`.
10. `UPDATE` (estado, decisión, motivo, usuario, porcentaje, fecha; al pasar de `RECHAZADA` a `PROPUESTA` se limpian las columnas de resolución, que quedan en el historial) + historial + `AuditoriaEvento` `DECIDIR_REVISION_CANCELACION`.
11. `COMMIT`; mensaje = `codigoMensajeExito` de la transición, salvo escalamiento → `RCN_015`.

#### 2.5.7 `usp_consultar_revisiones_cancelacion_coordinador_paginado` y `usp_consultar_revisiones_cancelacion_decano_paginado`

```sql
-- coordinador
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = 20,
 @soloPendientes BIT = 0, @codigoEstado NVARCHAR(20) = NULL, @idPrograma UNIQUEIDENTIFIER = NULL, @idGrupo UNIQUEIDENTIFIER = NULL)
-- decano
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = 20,
 @soloPendientes BIT = 0, @codigoEstado NVARCHAR(20) = NULL, @idPrograma UNIQUEIDENTIFIER = NULL)
-- Filas: uv_revision_cancelacion + idPrograma, nombrePrograma, porcentajeActual, horasFaltaActual, horasDictadasActual,
--        umbralPerdida, esResolutorActual BIT, accionesPermitidas, totalRegistros
```

- **Coordinador** (RBAC `COORDINADOR`): revisiones de estudiantes con `EstudiantePrograma` en un programa vigente del grupo que esté en `ufn_programas_coordinador(ejecutor)` (B2): en un grupo mixto, el coordinador de PA no ve a los de PB. `@idPrograma` ajeno → `COO_003`; sin él, unión de sus programas con una fila por revisión (programa de menor nombre). `@idGrupo` sin programa común → `SEC_002`.
- **Decano** (RBAC `DECANO`): revisiones con `codigoPerfilResolutorActual = 'DECANO'` y el ejecutor en `ufn_revision_cancelacion_resolutores(…, usuarioDecisionDocente)`, más las que resolvió él (`usuarioResolucion`). `@idPrograma` fuera de su facultad → `COO_003`.
- En ambos: `esResolutorActual` = ejecutor ∈ `ufn_revision_cancelacion_resolutores(idEstudianteGrupo, usuarioDecisionDocente)`; `accionesPermitidas` = transiciones `esDecisionResolutor = 1` desde el estado actual **solo si** `esResolutorActual = 1` y la matrícula es `A`; `@soloPendientes` → `requiereAccionResolutor = 1 AND esResolutorActual = 1`. Orden `esResolutorActual DESC, requiereAccionResolutor DESC, fechaDecisionDocenteUtc ASC`.

#### 2.5.8 `usp_resolver_revision_cancelacion` (coordinador o decano escalado)

```sql
(@idRevision UNIQUEIDENTIFIER, @codigoDecision NVARCHAR(20), @motivo NVARCHAR(MAX), @idCorrelacion UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL)
-- Salida: tupla + idRevision, codigoEstadoAnterior, codigoEstadoNuevo, codigoDecision, sinCambios BIT, cambioMatricula BIT,
--         idGrupo, idEstudianteGrupo, idEstudiante, idPrograma, codigoPerfilResolucion, porcentajeActual, tipoPlantillaNotificacion
```

1. Correlación; `GEN_002`; decisión con `esDecisionResolutor = 1` (`RCN_002`); motivo (`RCN_003`).
2. Transacción; `RevisionCancelacion WITH (UPDLOCK, HOLDLOCK)`; inexistente → `RCN_001`.
3. `@idUsuarioEjecutor = usuarioDecisionDocente` → `RCN_014`.
4. `#r = ufn_revision_cancelacion_resolutores(estudianteGrupo, usuarioDecisionDocente)`; ejecutor ausente → `RCN_001` (ajena indistinguible). RBAC con el `codigoPerfil` de su fila (`COORDINADOR` o `DECANO`).
5. Idempotencia (`APROBADA`+`APROBAR`, `RECHAZADA`+`RECHAZAR`) → `RCN_011`, `sinCambios = 1`, **sea quien sea el que resolvió antes** (O-13: un segundo resolutor que pide lo mismo recibe "ya registrada"; si pide lo contrario, `RCN_004`).
6. Sin transición → `RCN_004`; matrícula distinta de `A` → `RCN_005`; `exigeUmbralPerdida` incumplido → `RCN_006`.
7. `cancelaMatricula = 1`: `EstudianteGrupo WITH (UPDLOCK, HOLDLOCK)`, guarda `estadoMatriculaAnterior`, `UPDATE` a `MATRICULA/ESTADO_CANCELADA_INASISTENCIA`, `cambioMatricula = 1`. Desde ahí queda fuera de todo registro: `usp_registrar_asistencias_toma` y el lote (`EST_004`), `usp_registrar_asistencia_por_token` (`AQR_004`), `usp_internal_marcar_ausentes_toma` y `uv_faltantes_toma` (filtran `A`) y el frontend del docente (`codigoEstado === 'A'`). No toca `Grupo`.
8. `UPDATE` de la revisión (estado, `*Resolucion`, `codigoPerfilResolucion`, `programaResolucion` = programa de su fila, menor nombre si hay varios) + historial + `AuditoriaEvento` `RESOLVER_REVISION_CANCELACION` (metadata con perfil, si fue escalada y estados de matrícula).
9. `COMMIT`; `RCN_009`/`RCN_010`.

#### 2.5.9 `usp_consultar_destinatarios_revision_cancelacion`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @idRevision UNIQUEIDENTIFIER)
-- Filas: rolDestinatario (ESTUDIANTE | DOCENTE | RESOLUTOR), codigoPerfil, idUsuario, nombreCompleto, correo, idPrograma, esEscalamiento,
--        + contexto: idGrupo, codigoGrupo, nombreGrupo, nombreAsignatura, nombreCompletoEstudiante, nombreCompletoDocente, codigoEstado,
--          porcentajeActual, umbralPerdida, motivoDocente, motivoResolucion, nombreCompletoResolucion
```

Ejecutor = docente titular o resolutor (actual o quien resolvió); si no, `THROW 51000` con `RCN_001`. Los `RESOLUTOR` son `ufn_revision_cancelacion_resolutores(…, usuarioDecisionDocente)`: **nunca** incluye al proponente (O-2). Mismas reglas de privacidad que `usp_consultar_destinatarios_sesion_cancelada`.

#### 2.5.10 `usp_consultar_audiencias_realtime_grupo` (SSE)

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @idGrupo UNIQUEIDENTIFIER)   -- 1 fila: esDocenteTitular, esEstudianteActivo, esAmbitoLectura
```

Sin RBAC por perfil. `esDocenteTitular` = `Grupo.docente` del ejecutor; `esEstudianteActivo` = matrícula `MATRICULA/ESTADO_INSCRITA`; `esAmbitoLectura` = `EXISTS (ufn_programas_grupo(@idGrupo) ∩ ufn_programas_ambito_ejecutor(@idUsuarioEjecutor))` (B2: coordinador → sus programas, decano → programas de su facultad; una sola definición del ámbito, O-11) **o** administrador activo de la institución del periodo del grupo. Grupo inexistente o ajeno → los tres en 0.

#### 2.5.11 `usp_actualizar_resolutores_revisiones_cancelacion` (job; O-2, DEC-043)

```sql
(@idCorrelacion UNIQUEIDENTIFIER, @tamanoLote INT = NULL)
-- Salida (1 fila): tupla + revisionesReasignadas INT, revisionesEscaladas INT, revisionesSinResolutor INT, novedadesJSON NVARCHAR(MAX)
```

Comando de sistema. Recorre (lote `ALERTA_INASISTENCIA/LOTE_EVALUACION_AUTOMATICA`) las revisiones con `requiereAccionResolutor = 1` y matrícula `A`; por cada una, en su propia transacción con `UPDLOCK` sobre la revisión, calcula `ufn_revision_cancelacion_resolutores(…, usuarioDecisionDocente)` y su huella. Si la huella cambió: actualiza `codigoPerfilResolutorActual`, `huellaResolutoresActual` (y `fechaEscalamientoUtc` si pasa a `DECANO`), historial `ESCALAR` (→ DECANO) o `REASIGNAR` (otro coordinador, o de DECANO a COORDINADOR), `AuditoriaEvento` `ESCALAR_REVISION_CANCELACION` / `REASIGNAR_REVISION_CANCELACION` (`SYSTEM`, metadata con la causa: coordinador inactivo, programa reasignado, etc.). Si el conjunto queda vacío: `codigoPerfilResolutorActual = NULL`, historial `REASIGNAR` sin resolutor y auditoría `REVISION_CANCELACION_SIN_RESOLUTOR` (una vez por cambio de huella). `novedadesJSON` lista las revisiones cambiadas con sus nuevos resolutores (para `PROPUESTA_CANCELACION` y `REVISION_CANCELACION_REASIGNADA`). `ALR_007`.

### 2.6 Objetos existentes que cambian (ninguno congelado)

| Objeto | Cambio |
| :--- | :--- |
| `usp_consultar_resumen_asistencia_grupo_docente_paginado` (B.2, en su versión de B2 sin `idPrograma`) | `LEFT JOIN uv_marca_inasistencia_estudiante_grupo` y columnas nuevas al final: `tieneAdvertenciaVigente, fechaAdvertenciaUtc, tienePerdidaVigente, fechaPerdidaUtc, idRevisionCancelacion, codigoEstadoRevision, nombreEstadoRevision, requiereAccionDocente, codigoPerfilResolutorActual, accionesPermitidasRevision`. Columnas existentes sin cambio |
| `usp_ejecutar_cierre_masivo_periodo` (HU174, versión B.2) | [SUPUESTO-C-10]. Se retiran la CTE `InasistenciasPorEstudiante` y el `HAVING … >= 3`; los literales `'F'`, `'CI'`, `'A'` pasan a parámetros. Flujo tras resolver el periodo: (1) `@motorActivo` = `HABILITADA = true` **y** los dos umbrales válidos (`ufn_umbral_alerta_inasistencia`). (2) El SP **no** ejecuta el motor ni ningún otro SP que devuelva resultsets (N-1): la evaluación con avisos la hace antes el caso de uso del backend (§3.4) y, por tiempo, el job. (3) Transacción propia (o savepoint si hay transacción externa, como hoy); bloqueos en el orden de §2.0 (O-7, N-4). (4) Si `@motorActivo` y (revisiones con `requiereAccionDocente = 1 OR requiereAccionResolutor = 1` de matrículas `A` del periodo, **más** matrículas `A` con pérdida por horas en `uv_resumen_*` sin fila en `RevisionCancelacion`) > 0 → revierte lo propio, `RCN_012` con los dos totales, `estadoResultado = 0`; **no** crea revisiones (las crea el job o la siguiente evaluación, con sus avisos). (5) Si no: `A → F` (incluye `MANTENIDA`/`RECHAZADA` y, con el motor apagado, cualquier pérdida), contadores de `Grupo` (fórmula sin cambio; [SUPUESTO-C-20]) y `AuditoriaEvento` `CIERRE_MASIVO_PERIODO` con `metadata {procesados, finalizados, canceladosPorInasistencia, motorHabilitado, umbralesValidos, perdidasSinRevision, revisionesPendientes}`. Con el motor apagado, las revisiones que quedaran pendientes conservan su estado y su matrícula pasa a `F` (`accionesPermitidas` vacías; `RCN_005`). **Salida:** exactamente un resultset de una fila con la tupla canónica (como hoy), en los casos bloqueado, exitoso y de error; `INSERT INTO #t EXEC` sigue funcionando (C-DB-47) |

La v1 añadía `idGrupo` a `usp_consultar_destinatarios_reclamo_asistencia`: **se retira** (ya lo devuelve, O-9); el backend usa `DestinatarioReclamoProjection.idGrupo`.

### 2.7 Mensajes nuevos (`40_culm001_c_mensajes.sql`; `generar-catalogo-mensajes.ps1 -Check`; catálogo de MessageUcoLab regenerado)

| Código | Tipo / severidad | Mensaje de usuario | Técnico (plantilla) | HTTP |
| :--- | :--- | :--- | :--- | :--- |
| `ALR_001` | SUCCESS / BAJO | Las alertas de inasistencia están deshabilitadas. | ALERTA_INASISTENCIA/HABILITADA != true; grupo [{}] sin escrituras. | interno |
| `ALR_002` | TECHNICAL_ERROR / CRITICO | No fue posible evaluar las alertas de inasistencia. | Umbral [{}] del tipo [{}] ausente o no numérico. | interno |
| `ALR_003` | SUCCESS / BAJO | Evaluación de alertas completada. | Grupo [{}]: {} nuevas, {} superadas, {} reactivadas, {} revisiones. | interno |
| `ALR_004` | VALIDATION_ERROR / BAJO | La lista de alertas no es válida. | @alertasJSON vacío, inválido, con duplicados o con más de {}. | 400 [C.2] |
| `ALR_005` | SUCCESS / BAJO | Se marcaron {} alertas como leídas. | Lectura de alertas del estudiante [{}]. | 200 [C.2] |
| `ALR_006` | VALIDATION_ERROR / BAJO | La matrícula indicada no pertenece al grupo. | EstudianteGrupo [{}] no es del grupo [{}]. | interno |
| `ALR_007` | SUCCESS / BAJO | Actualización de resolutores completada. | {} reasignadas, {} escaladas, {} sin resolutor. | interno |
| `ALR_010` | INFO / BAJO | Llevas {}% de inasistencia en {}. Si llegas al {}% podrías perder la asignatura. | Texto ADVERTENCIA. | por fila |
| `ALR_011` | INFO / MEDIO | Alcanzaste {}% de inasistencia en {} (límite {}%). Tu docente revisará tu caso. | Texto PERDIDA. | por fila |
| `RCN_001` | BUSINESS_ERROR / BAJO | La revisión de cancelación no existe. | Revisión [{}] inexistente o fuera del ámbito de [{}]. | 404 |
| `RCN_002` | VALIDATION_ERROR / BAJO | La decisión no es válida. | @codigoDecision/@codigoEstado [{}] no existe para este actor. | 400 |
| `RCN_003` | VALIDATION_ERROR / BAJO | El motivo debe tener entre {} y {} caracteres. | @motivo fuera de REVISION_CANCELACION/MOTIVO_LONGITUD_*. | 400 |
| `RCN_004` | BUSINESS_ERROR / MEDIO | La revisión está en estado «{}» y no admite esa decisión. | Sin transición para ({}, {}). | 409 |
| `RCN_005` | BUSINESS_ERROR / MEDIO | La matrícula del estudiante ya no está activa en el grupo. | EstudianteGrupo [{}] con estado [{}]. | 409 |
| `RCN_006` | BUSINESS_ERROR / MEDIO | El estudiante ya no supera el límite de inasistencia ({}% de {}%); no se puede proponer ni aprobar la cancelación. | Porcentaje [{}] < umbral [{}]. | 409 |
| `RCN_007` | SUCCESS / BAJO | Decisión registrada: el estudiante se mantiene en el grupo. | Revisión [{}] → MANTENIDA. | 200 |
| `RCN_008` | SUCCESS / BAJO | Se envió la propuesta de cancelación a la coordinación del programa. | Revisión [{}] → PROPUESTA (COORDINADOR). | 200 |
| `RCN_009` | SUCCESS / BAJO | Cancelación aprobada: el estudiante quedó cancelado por inasistencia. | Revisión [{}] → APROBADA; matrícula [{}] → CI. | 200 |
| `RCN_010` | SUCCESS / BAJO | Cancelación rechazada: el estudiante sigue activo en el grupo. | Revisión [{}] → RECHAZADA. | 200 |
| `RCN_011` | SUCCESS / BAJO | La decisión ya estaba registrada. | Revisión [{}] ya en [{}]; sin escrituras. | 200 |
| `RCN_012` | BUSINESS_ERROR / ALTO | Hay {} casos de pérdida por inasistencia pendientes de decisión del docente o de resolución en el periodo; resuélvelos antes del cierre. | Cierre de [{}] bloqueado: {} revisiones pendientes (incluye las de pérdida ya superada que esperan decisión), {} pérdidas sin revisión. | 409 |
| `RCN_013` | BUSINESS_ERROR / MEDIO | No hay un coordinador ni un decano activo que pueda resolver la propuesta para el programa del estudiante. | ufn_revision_cancelacion_resolutores vacío para [{}]. | 409 |
| `RCN_014` | BUSINESS_ERROR / MEDIO | No puedes resolver una propuesta de cancelación que hiciste como docente. | Ejecutor [{}] = proponente de [{}]. | 409 |
| `RCN_015` | SUCCESS / BAJO | El programa no tiene un coordinador disponible: la propuesta se envió a la decanatura de la facultad. | Revisión [{}] → PROPUESTA escalada a DECANO. | 200 |

Reutilizados: `GEN_002`, `GEN_004`, `SEC_002`, `PAG_001`, `COO_002`, `COO_003`, `EST_004`, `AQR_004`, `SYS_001`.

### 2.8 Parámetros nuevos (`40_culm001_c_parametros.sql`, MERGE que no pisa `valor`)

| Grupo | Clave | Valor = defecto | Tipo |
| :--- | :--- | :--- | :--- |
| `ALERTA_INASISTENCIA` | `HABILITADA` | `true` | BOOLEAN |
| `ALERTA_INASISTENCIA` | `LOTE_EVALUACION_AUTOMATICA` | `50` | INT |
| `ALERTA_INASISTENCIA` | `SOLAPE_MARCA_SEGUNDOS` | `120` | INT |
| `ALERTA_INASISTENCIA` | `MAXIMO_LECTURA_POR_SOLICITUD` | `100` | INT (C.2) |
| `REVISION_CANCELACION` | `MOTIVO_LONGITUD_MINIMA` / `MOTIVO_LONGITUD_MAXIMA` | `10` / `500` | INT |
| `MATRICULA` | `ESTADO_CANCELADA_INASISTENCIA` / `ESTADO_FINALIZADA` | `CI` / `F` | STRING |

Reutilizados: `ASISTENCIA/UMBRAL_ALERTA_ADVERTENCIA` (15), `ASISTENCIA/UMBRAL_ALERTA_PERDIDA` (20), `MATRICULA/ESTADO_INSCRITA`, `PAGINACION/TAMANO_MAXIMO`, `TIEMPO/ZONA_HORARIA_SQLSERVER`.

### 2.9 Plantillas de notificación (`41_culm001_c_plantillas_notificacion.sql`)

| Tipo | Destinatario | Asunto | Marcadores |
| :--- | :--- | :--- | :--- |
| `ALERTA_RIESGO_INASISTENCIA` (existente) | Estudiante | sin cambio | cuerpo a `{umbral}` si conserva el texto por defecto ([SUPUESTO-C-16]) |
| `ALERTA_PERDIDA_INASISTENCIA` (existente) | Estudiante | sin cambio | cuerpo a `{limite}` con la misma regla |
| `REVISION_CANCELACION_PENDIENTE` | Docente titular | `Revisión de cancelación pendiente: {estudiante} en {grupo}` | `docente, estudiante, grupo, porcentaje, limite` |
| `PROPUESTA_CANCELACION` | Resolutores (coordinador o decano escalado) | `Propuesta de cancelación por inasistencia: {estudiante} en {grupo}` | `resolutor, estudiante, grupo, docente, porcentaje, limite, motivo, escalamiento` (`escalamiento` vacío o "Se le asigna porque el programa no tiene coordinador disponible", texto de la plantilla) |
| `CANCELACION_APROBADA` | Estudiante y docente | `Cancelación por inasistencia en {grupo}` | `destinatario, estudiante, grupo, porcentaje, motivo, resolutor` |
| `CANCELACION_RECHAZADA` | Docente | `Propuesta de cancelación rechazada: {estudiante} en {grupo}` | `docente, estudiante, grupo, motivo, resolutor` |

Mismo texto por defecto en `PlantillaPorDefectoCatalogo`.

### 2.10 Permisos

`rol_asistencias_runtime_culm001_c.sql` (`GRANT EXECUTE` con guard): `usp_evaluar_alertas_inasistencia_grupo`, `usp_consultar_grupos_pendientes_evaluacion_alertas`, `usp_consultar_alertas_estudiante`, `usp_decidir_revision_cancelacion`, `usp_consultar_revisiones_cancelacion_coordinador_paginado`, `usp_consultar_revisiones_cancelacion_decano_paginado`, `usp_resolver_revision_cancelacion`, `usp_consultar_destinatarios_revision_cancelacion`, `usp_consultar_audiencias_realtime_grupo`, `usp_actualizar_resolutores_revisiones_cancelacion`; [C.2] `usp_marcar_alertas_inasistencia_leidas`, `usp_consultar_revisiones_cancelacion_docente_paginado`. `GRANT SELECT` explícito a las vistas nuevas (el bucle de `rol_asistencias_runtime.sql` está congelado). Funciones sin `GRANT`. `test_public_objects.sql` ampliado.

### 2.11 Migración `19_culm001_c_cancelacion_inasistencia_up|down.sql` (C.1)

**`up`** (idempotente, `SET XACT_ABORT ON`, `@@TRANCOUNT = 0` al final):
0. **Precondiciones (O-12):** `THROW 50019` con mensaje claro si falta `dbo.TomaAsistencia`, `dbo.uv_asistencia_sesion_horas`, `dbo.AsignaturaPlanEstudio`, `dbo.ufn_programas_grupo` o `dbo.ufn_programas_ambito_ejecutor`, o si `COL_LENGTH('dbo.uv_resumen_asistencia_estudiante_grupo', 'idPrograma') IS NOT NULL` (B2 sin aplicar).
1. Catálogos con sus filas (MERGE por id), tablas con índices y FKs; `CREATE OR ALTER` de funciones y vistas; `GRANT` condicionados. No evalúa ([SUPUESTO-C-15]). Resultset: `catalogosCreados`, `transiciones` (= 6), `matriculasEnPerdidaSinRevision` (solo reporte).

Los SP, semillas y cambios de §2.6 se despliegan con `deploy_schema.ps1`.

**`down`** (O-6): restaura el estado **inmediatamente anterior a C**, es decir, el de `integracion/CULM-001` con B2 aplicado:
1. Archiva `AlertaInasistencia`, `RevisionCancelacion`, `RevisionCancelacionHistorial` en `zz_archivo_*_culm001_c` (sin FKs) y reporta las matrículas en `CI` por revisión aprobada (no se revierten, [SUPUESTO-C-17]).
2. `DROP` de los SP, vistas y funciones de C.
3. Restaura literalmente (texto copiado en el `down` al iniciar el GREEN, desde `integracion/CULM-001` después de B2): `usp_consultar_resumen_asistencia_grupo_docente_paginado` (versión B2, **sin** `idPrograma`) y `usp_ejecutar_cierre_masivo_periodo` (versión B.2, que B2 no toca).
4. `DROP TABLE` en orden `RevisionCancelacionHistorial, RevisionCancelacion, AlertaInasistencia, EvaluacionAlertaGrupo, TransicionRevisionCancelacion, EstadoRevisionCancelacion, EstadoAlertaInasistencia, TipoAlertaInasistencia`.
5. Borra parámetros, mensajes y plantillas nuevas solo si `valor = valorDefecto` / texto por defecto; restaura el cuerpo anterior de las dos `ALERTA_*` con la misma regla; cancela en `NotificacionSaliente` las pendientes de los 4 tipos nuevos (DEC-010).

**Orden de `down` entre paquetes:** C (19) → B2 (18, 17) → B.2 (16) → B.1 (15). Ejecutar el `down` de un paquete anterior con C aplicado no está soportado (las pruebas de migración de B.2 corren en una transacción que se revierte, §2.13.2).

### 2.12 Manifiestos y contratos de BD

- C no modifica objetos congelados (`DB_DEVELOP_FREEZE_MANIFEST`, `DB_UTC_D06_POST_FREEZE_MANIFEST`, `DB_LB004D_SUPPORT_BINDING_MANIFEST`, `DB_CULM001_B_POST_FREEZE_MANIFEST`): los dos SP de §2.6 no están en ninguno.
- `DB:docs/contracts/DB_CULM001_C_POST_FREEZE_MANIFEST.sha256` (líneas `WORK_ITEM`, generado tras la aprobación 9.2 con `freeze-manifest.ps1 -Mode GeneratePostFreeze`): las 8 tablas, `ufn_revision_cancelacion_resolutores.sql`, `uv_alerta_inasistencia.sql`, `uv_revision_cancelacion.sql`, `usp_evaluar_alertas_inasistencia_grupo.sql`, `usp_decidir_revision_cancelacion.sql`, `usp_resolver_revision_cancelacion.sql`, `usp_actualizar_resolutores_revisiones_cancelacion.sql`, `usp_consultar_audiencias_realtime_grupo.sql`, migración 19 `up|down`, `rol_asistencias_runtime_culm001_c.sql`.
- `DB_DEVELOP_FREEZE_ADDENDUM.md` (DB e Infra) sección "CULM-001 C": `CI` solo nace de una revisión aprobada; regla del cierre masivo con y sin motor; unicidad de alertas y revisiones; escalamiento al decano; nuevo significado de `Grupo.cantidadEstudiantesCancelaronAutomaticamente` ([SUPUESTO-C-20]). `.sha256` regenerado tras 9.2.

### 2.13 Pruebas T-SQL

#### 2.13.1 Nuevas (RED)

Archivos `test_culm001_c_alertas.sql`, `test_culm001_c_revisiones.sql`, `test_culm001_c_cierre_masivo.sql`, `test_culm001_c_realtime_audiencias.sql`, `test_culm001_c_migraciones.sql`, `test_culm001_c_despliegue_limpio.ps1`, `test_culm001_c_concurrencia.ps1` y el fixture `test_culm001_c_fixture.sql` (sobre el de segundo ámbito de A y el grupo mixto de B2: G con PA y PB; EA ∈ PA, EB ∈ PB, E0 sin vínculo; coordinadores CA, CB; decano D de la facultad; docente T; administrador AD; sesiones **vencidas** de 2 h con tomas y detalles con `toma`). Todas terminan con `@@TRANCOUNT = 0`, limpian lo que crean (incluidas `EvaluacionAlertaGrupo`, alertas, revisiones e historial) y fallan con `TEST FAILED: C-DB-xx …`.

| ID | Regla | Criterio |
| :--- | :--- | :--- |
| C-DB-01 | **Cruce de advertencia una vez** | EA 16 %: 1 alerta `VIGENTE`, 1 novedad `esPrincipal = 1`; 2.ª y 3.ª evaluación: 0 novedades, 1 fila |
| C-DB-02 | Bajo el umbral | EA 14,9 %: 0 filas |
| C-DB-03 | **EX no cuenta** | EB 6 h EX + 2 h SJC de 20 h (10 %): 0 alertas; 2 h EX → SJC (20 %): ADVERTENCIA y PERDIDA |
| C-DB-04 | Por horas | Sesión de 4 h con 2 tomas, falta en una = 2 h; porcentaje = `uv_resumen_*` |
| C-DB-05 | No vencidas y canceladas | SJC en sesión futura: sin alerta hasta vencer; sesión cancelada: no suma |
| C-DB-06 | Salto directo | 10 % → 25 %: 2 alertas, 1 revisión, `esPrincipal` solo en PERDIDA |
| C-DB-07 | Superada/reactivada | 12 % → `SUPERADA`; 16 % → `VIGENTE` sin novedad; ambas con `ALERTA_INASISTENCIA_ACTUALIZADA` en auditoría |
| C-DB-08 | Solo `A` | `CI`, `I`, `F` con 30 %: 0 alertas |
| C-DB-09 | Interruptor y umbral | `HABILITADA = false` → `ALR_001`, 0 escrituras; umbral borrado → `ALR_002`, 0 escrituras |
| C-DB-10 | `@idEstudianteGrupo` | Solo esa matrícula; de otro grupo → `ALR_006` |
| C-DB-11 | Marca de agua (O-8) | Tras evaluar, el grupo no sale como pendiente; al vencer otra sesión, sale; **caso límite:** sesión con `fechaHoraFin` = corte + 0,4 ms y otra que vence durante la evaluación (simulada con el corte capturado antes): ambas se evalúan en el pase siguiente; con el solape, a lo sumo `solape / tick` re-evaluaciones idempotentes (0 novedades); periodo terminado nunca sale |
| C-DB-12 | Auditoría del motor | `ALERTA_INASISTENCIA_REGISTRADA`, `REVISION_CANCELACION_CREADA`, `SYSTEM`, `correlationId` |
| C-DB-13 | Transacción externa | Savepoint sin commit; transacción condenada → `THROW` |
| C-DB-15 | Consulta del estudiante | Solo propias; `soloNoLeidas`; `soloVigentes` (una alerta que pasa a `SUPERADA` deja de contar; la de una matrícula `CI` no cuenta); `@idGrupo` ajeno → `SEC_002`; sin columnas de revisión |
| C-DB-16 | [C.2] Lectura | Solo propias; ajenas ignoradas; idempotente; vacía o 101 → `ALR_004` |
| C-DB-20 | **Una sola revisión por pérdida** | 3 evaluaciones (+ C-DB-50 concurrente): 1 revisión, 1 historial `CREAR` |
| C-DB-21 | **Mantener sin nueva alerta y proponer después** | `MANTENER` → `MANTENIDA` (`RCN_007`); EA sube a 35 %: 0 novedades, 0 revisiones; `PROPONER` → `PROPUESTA` (`RCN_008`) |
| C-DB-22 | Motivo y decisión | Vacío, 9 o 501 caracteres → `RCN_003`; `APROBAR` por el docente → `RCN_002` |
| C-DB-23 | Ámbito del docente | Otro docente → `RCN_001`; inexistente → `RCN_001` |
| C-DB-24 | Transición e idempotencia | `PROPUESTA`+`MANTENER` → `RCN_004`; `MANTENIDA`+`MANTENER` → `RCN_011` sin historial nuevo |
| C-DB-25 | Umbral | EA bajado a 18 %: `PROPONER` → `RCN_006`; `MANTENER` permitido |
| C-DB-26 | **Aprobar ⇒ `CI` y fuera del registro** | CA aprueba: `APROBADA`, matrícula `CI`, `estadoMatriculaAnterior = A`; EA no está en `uv_faltantes_toma`; lote/toma con EA → `EST_004`; token → `AQR_004`; EA ya no se evalúa |
| C-DB-27 | **Rechazar ⇒ sigue activo** | CA rechaza: `RECHAZADA`, matrícula `A`, EA en faltantes y registrable; T re-propone → columnas de resolución limpias, historial completo |
| C-DB-28 | **Ámbito del coordinador por programa del estudiante (grupo mixto)** | Listado de CA: EA sí, EB no; CB al revés; CA resuelve EB → `RCN_001`; E0: ningún coordinador la ve y `PROPONER` → `RCN_013`; T y AD no resuelven; `@idPrograma` ajeno → `COO_003` |
| C-DB-29 | **Proponente excluido y escalamiento (O-2)** | T es además el único coordinador de PA: `PROPONER` sobre EA → `PROPUESTA` escalada (`RCN_015`, `codigoPerfilResolutorActual = DECANO`, historial `ESCALAR`, auditoría `ESCALAR_REVISION_CANCELACION`); destinatarios `RESOLUTOR` = D (sin T); T intenta aprobar → `RCN_014`; D aprueba → `APROBADA` con `codigoPerfilResolucion = DECANO`; sin decano activo además → `RCN_013` |
| C-DB-30 | Cardinalidad | Vistas nuevas y listados con G en dos programas: `COUNT(*) = COUNT(DISTINCT id)`; estudiante en PA y PB del mismo coordinador → 1 fila |
| C-DB-31 | Destinatarios | 1 estudiante, 1 docente, resolutores sin el proponente; ejecutor ajeno → `RCN_001` |
| C-DB-32 | Resumen del docente | Columnas nuevas al final; existentes (versión B2) sin cambio de nombre, tipo ni orden |
| C-DB-33 | Listado del decano | D ve solo las escaladas a él o resueltas por él; `@idPrograma` de otra facultad → `COO_003` |
| C-DB-34 | **Reasignación por el job (O-2)** | Propuesta con CA; se desactiva CA: `usp_actualizar_resolutores_…` → escalada a D (historial, auditoría, novedad); se asigna CA2 a PA → `REASIGNAR` a CA2; huella sin cambio en el pase siguiente → 0 novedades; sin coordinador ni decano → `REVISION_CANCELACION_SIN_RESOLUTOR` una sola vez |
| C-DB-40 | **Cierre bloqueado con motor activo** | Revisión `PENDIENTE_DOCENTE`, revisión `PROPUESTA` y revisión `PENDIENTE_DOCENTE` cuya alerta de pérdida ya está `SUPERADA` (O-13): `RCN_012` con el total, 0 cambios en `EstudianteGrupo`/`Grupo`; matrícula en pérdida sin revisión: `RCN_012` **sin crear la revisión** ni escribir en `AlertaInasistencia`, `RevisionCancelacion` o `EvaluacionAlertaGrupo` (N-1) |
| C-DB-41 | Cierre sin la regla `>= 3` | 3 sesiones SJC con 10 % por horas → `F`; 3 EX → `F`; `MANTENIDA` 30 % → `F`; `RECHAZADA` → `F`; `APROBADA` sigue `CI`; contadores; auditoría con `motorHabilitado = true` |
| C-DB-47 | **Una sola fila (N-1)** | En los casos bloqueado (`RCN_012`), exitoso (`GEN_004`), motor apagado y error forzado, el cierre devuelve exactamente 1 resultset de 1 fila con las 4 columnas de la tupla; `INSERT INTO #t (4 columnas) EXEC usp_ejecutar_cierre_masivo_periodo` funciona sin error 8164 ni de número de columnas; `sys.sql_expression_dependencies` del cierre no referencia `usp_evaluar_alertas_inasistencia_grupo` |
| C-DB-43 | **Cierre con el motor apagado (O-3)** | `HABILITADA = false`, pérdida sin revisión y una revisión `PENDIENTE_DOCENTE`: no bloquea, todas las `A` → `F`, auditoría con `motorHabilitado = false`, `perdidasSinRevision = 1`, `revisionesPendientes = 1` |
| C-DB-44 | **Cierre con umbral inválido (O-3)** | Umbral de pérdida = `'x'`: no bloquea, `A → F`, `umbralesValidos = false` en auditoría; se restaura el parámetro |
| C-DB-45 | Audiencias SSE (O-11) | T titular 1; EA `A` estudiante 1; EA tras `CI` 0; CA ámbito 1; coordinador de otro programa 0; D 1; AD de la institución 1; AD de otra institución 0 |
| C-DB-46 | **Dos resolutores concurrentes (O-13)** | Estudiante en PA y PB, propuesta resoluble por CA y CB: ambos `APROBAR` a la vez → uno `RCN_009`, otro `RCN_011`; `APROBAR` y `RECHAZAR` a la vez → uno gana, el otro `RCN_004`; 1 sola fila de historial de resolución |
| C-DB-50 | Concurrencia (`.ps1`) | 2 evaluaciones del mismo grupo + 5 de grupos distintos: 1 alerta por (matrícula, tipo), 1 revisión, sin deadlocks; resolución vs `usp_retirar_estudiante_grupo` del mismo estudiante: uno gana (`RCN_005`/`RET_002`); cierre masivo y lote del mismo periodo a la vez (N-4; el fixture desactiva la ventana SES-01 para poder forzar el lote): sin error 1205 en 20 repeticiones; el cierre bloquea con `RCN_012` o el lote espera, nunca `F` con una pérdida sin revisión y el motor activo; cierre y motor del mismo grupo a la vez: sin 1205 |
| C-DB-60 | **Migración sobre la base B2 (O-6)** | `up → up`; `up → down → up`; tras el `down`, `sys.sql_modules` del resumen del docente y del cierre masivo es idéntico (normalizado) al texto de `integracion/CULM-001` antes de C, y el resumen ejecuta sin error (sin `idPrograma`); archivos `zz_*` con las mismas filas; matrículas `CI` intactas; sobre una BD sin B2 el `up` aborta con `50019` sin crear nada |
| C-DB-61 | Objetos públicos | 10 SP de C.1 concedidos (12 con C.2), funciones no |
| C-DB-62 | **Despliegue limpio (O-1)** | `test_culm001_c_despliegue_limpio.ps1`: BD vacía → `deploy_schema.ps1` completo sin errores en `functions/`; `ufn_revision_cancelacion_resolutores` y `ufn_umbral_alerta_inasistencia` existen y no dependen de vistas ni de otras funciones de usuario (`sys.sql_expression_dependencies`) |
| C-DB-63 | Paridad de programas (O-1) | Para todas las matrículas de los fixtures de A, B2 y C: programas competentes de la función = `EstudiantePrograma ∩ ufn_programas_grupo` |

Gate: `infra.ps1 db-test` sin fallos nuevos frente a la línea base (F-000) y `freeze-manifest.ps1 -Mode Verify`.

#### 2.13.2 Pruebas existentes que cambian (O-4; cambio formal por DEC-041 C-10 / DEC-043; ninguna aserción se elimina sin reemplazo)

| Archivo / caso | Aserción actual | Aserción nueva | Justificación |
| :--- | :--- | :--- | :--- |
| `test/test_mass_period_close.sql` `MASS_CLOSE_SUCCESS` (l.76-77, 52012; l.84, 52014) | La matrícula con 3 SJC pasa a `CI`; contadores `F = 1`, `CI = 1` | **Fase 1:** con el motor activo, la matrícula con 3 SJC (100 % por horas) y sin revisión hace que el cierre responda `RCN_012` (`estadoResultado = 0`), sin crear la revisión y sin cambios en `EstudianteGrupo` ni contadores. **Fase 2:** el fixture ejecuta `usp_evaluar_alertas_inasistencia_grupo` (crea la revisión), la aprueba por los SP (`PROPONER` del titular del fixture y `APROBAR` del coordinador del programa) y el cierre responde `GEN_004`: esa matrícula sigue `CI`, la otra `F`, contadores `F = 1`, `CI = 1`, auditoría `CIERRE_MASIVO_PERIODO` (52011, 52013 y 52015 sin cambio) | El cierre ya no escribe `CI` por conteo (DEC-041 C-10); `CI` solo por revisión aprobada |
| `test/test_mass_period_close.sql` `CULM001_B2_HOR_10` (l.155-158, 52022-52023) | 3 sesiones con una falta → `CI`; 3 tomas ausentes en una sesión → `F` | Ambas matrículas quedan en 33 % por horas: el cierre responde `RCN_012` con 2 pérdidas sin revisión, sin crear revisiones ni cambiar estados; el fixture ejecuta el motor (2 revisiones), las pasa a `MANTENIDA` (SP del docente) y el cierre responde `GEN_004` con ambas en `F`. Se renombra `CULM001_C_HOR_10_CIERRE_POR_HORAS`; la regla de B-7 (`COUNT(DISTINCT a.sesion)`) queda sustituida | DEC-041 C-10 reemplaza la regla de B-7 |
| `test/test_mass_period_close.sql` limpieza | Borra `DetalleAsistencia → … → Grupo` | Además borra, antes de `EstudianteGrupo`/`Grupo`: `RevisionCancelacionHistorial`, `RevisionCancelacion`, `AlertaInasistencia`, `EvaluacionAlertaGrupo` del grupo | La fase 2 de cada caso ejecuta el motor (FKs nuevas); el cierre por sí solo no escribe en esas tablas |
| `test/test_rec3_falla_intermedia_transaccion.sql` TX-03 (l.152-190) | La falla de contadores revierte la finalización | **Sin cambio de aserción ni de limpieza.** El `INSERT INTO #preTX03 EXEC` de la precondición sigue funcionando porque el cierre devuelve una sola fila (N-1, C-DB-47). Se fija explícitamente la precondición "sin pérdidas" (el fixture no tiene sesiones ni asistencias: 0 %) comprobando que la fila de `#preTX03` no es `RCN_012`, para que la falla siga siendo la de contadores | Regla nueva del cierre (`RCN_012`) |
| `test/test_culm001_b2_migraciones.sql` l.57 | Tras el `down` de 16 el cierre contiene `COUNT(da.id)` | **Sin cambio.** La prueba corre en una transacción revertida y el `down` de 16 restaura la versión anterior a B.2 aunque C esté aplicado. Se documenta el orden de `down` C → B2 → B.2 (§2.11) | — |
| `test/test_public_objects.sql` | Lista de objetos públicos | + SP y vistas de C | Objetos nuevos |

### 2.14 Rendimiento del motor (O-14)

Criterio de aceptación: `usp_evaluar_alertas_inasistencia_grupo` con un grupo de 40 matrículas y 32 sesiones vencidas, **p95 ≤ 300 ms** (IT de backend, §3.9). Si se supera, el backend lo ejecuta después de responder, en un ejecutor de hilos virtuales con `CorrelationIdContext` propagado (alternativa aprobada de antemano, sin cambio de BD).

---

## 3. Backend (`GestioAsistenciaBackend`)

### 3.1 Reglas comunes

`Controller → InputPort → UseCaseImpl → SecondaryPort → *JpaRepository` (ejecuta el SP). Mensajes por `MessageCatalogPort`. `ApiDataResponse<T>` / `ApiPageResponse<T>`. `CorrelationIdContext` hasta el SP. Eventos y notificaciones después del commit, de mejor esfuerzo, sin datos personales en el log.

### 3.2 Endpoints

| Método y ruta | Rol | Petición | Respuesta | Sub |
| :--- | :--- | :--- | :--- | :--- |
| `GET /api/v1/estudiante/alertas?soloVigentes=false&soloNoLeidas=false&grupoId=&pagina=1&tamano=20` | ESTUDIANTE | — | 200 `ApiPageResponse<AlertaInasistenciaResponse>`; 400; 403 | C.1 |
| `PATCH /api/v1/estudiante/alertas/lectura` | ESTUDIANTE | `{ "alertas": ["uuid", …] }` | 200 `{ "marcadas": n }` (`ALR_005`); 400 (`ALR_004`) | C.2 |
| `PATCH /api/v1/docente/revisiones-cancelacion/{revisionId}` | DOCENTE | `{ "decision": "MANTENER" \| "PROPONER", "motivo": "…" }` | 200 `ApiDataResponse<RevisionCancelacionResponse>` + `mensajeUsuario` (`RCN_007`/`008`/`011`/`015`); 400 (`RCN_002`, `RCN_003`); 404 (`RCN_001`); 409 (`RCN_004`, `005`, `006`, `013`) | C.1 |
| `GET /api/v1/docente/revisiones-cancelacion?soloPendientes=&estado=&grupoId=&pagina=&tamano=` | DOCENTE | — | 200 `ApiPageResponse<RevisionCancelacionResponse>`; 400; 403 | C.2 |
| `GET /api/v1/coordinador/revisiones-cancelacion?soloPendientes=&estado=&programaId=&grupoId=&pagina=&tamano=` | COORDINADOR | — | 200 `ApiPageResponse<RevisionCancelacionResponse>`; 400; 403 (`COO_003`, `SEC_002`) | C.1 |
| `PATCH /api/v1/coordinador/revisiones-cancelacion/{revisionId}` | COORDINADOR | `{ "decision": "APROBAR" \| "RECHAZAR", "motivo": "…" }` | 200 (`RCN_009`/`010`/`011`); 400; 404; 409 (`RCN_004`, `005`, `006`, `014`) | C.1 |
| `GET /api/v1/decano/revisiones-cancelacion?soloPendientes=&estado=&programaId=&pagina=&tamano=` | DECANO | — | igual que el coordinador | C.1 |
| `PATCH /api/v1/decano/revisiones-cancelacion/{revisionId}` | DECANO | igual que el coordinador | igual que el coordinador | C.1 |
| `GET /api/v1/realtime/stream?grupoId=` (golden path, comportamiento ampliado) | Autenticado | — | 200 según ámbito; 403 sin audiencia | C.1 |
| `GET /api/v1/realtime/stream/personal` | Autenticado | — | 200 `text/event-stream` | C.2 |
| `GET /api/v1/docente/grupos/{grupoId}/resumen-asistencia` (B.2) | DOCENTE titular | — | cada elemento añade `marca` | C.1 |
| `POST /api/v1/admin/cierre-masivo` (HU174) | ADMINISTRADOR | sin cambio | nuevo 409 `RCN_012`; el caso de uso evalúa antes los grupos del periodo | C.1 |

Bean Validation: `decision` no vacía, `motivo` no nulo; valores y longitudes en el SP; campos extra → 400.

```json
// AlertaInasistenciaResponse
{ "id": "uuid", "tipo": "ADVERTENCIA", "nombreTipo": "…", "estado": "VIGENTE",
  "mensaje": "Llevas 16.00% de inasistencia en Bases de datos. Si llegas al 20.00% podrías perder la asignatura.",
  "porcentajeCruce": 16.00, "porcentajeActual": 16.00, "umbral": 15.00, "umbralPerdida": 20.00,
  "horasFalta": 4.00, "horasDictadas": 25.00, "fechaCruceUtc": "…Z", "leida": false, "fechaLecturaUtc": null,
  "grupo": { "id": "uuid", "codigo": 1, "nombre": "G01" }, "asignatura": { "id": "uuid", "nombre": "…" }, "estadoMatricula": "A" }

// RevisionCancelacionResponse (docente, coordinador y decano)
{ "id": "uuid", "estado": "PROPUESTA", "nombreEstado": "…", "requiereAccionDocente": false, "requiereAccionResolutor": true,
  "esResolutorActual": true, "accionesPermitidas": ["APROBAR", "RECHAZAR"],
  "perfilResolutorActual": "COORDINADOR" | "DECANO" | null, "fechaEscalamientoUtc": "…Z" | null,
  "estudiante": { "id": "uuid", "nombreCompleto": "…" }, "estadoMatricula": "A",
  "grupo": { "id": "uuid", "codigo": 1, "nombre": "G01" }, "asignatura": { "id": "uuid", "nombre": "…" },
  "docente": { "id": "uuid", "nombreCompleto": "…" }, "programa": { "id": "uuid", "nombre": "…" } | null,
  "porcentajeCreacion": 21.43, "porcentajeActual": 22.50, "umbralPerdida": 20.00, "horasFalta": 9.00, "horasDictadas": 40.00,
  "fechaCreacionUtc": "…Z", "decisionDocente": "PROPONER", "motivoDocente": "…", "fechaDecisionDocenteUtc": "…Z",
  "decisionResolucion": null, "motivoResolucion": null, "resolutor": { "nombreCompleto": "…", "perfil": "DECANO" } | null,
  "fechaResolucionUtc": null }

// marca (en ResumenAsistenciaEstudianteResponse de B.2; null si no hay alerta ni revisión)
{ "advertenciaVigente": true, "fechaAdvertenciaUtc": "…Z", "perdidaVigente": true, "fechaPerdidaUtc": "…Z",
  "revision": { "id": "uuid", "estado": "PENDIENTE_DOCENTE", "nombreEstado": "…", "requiereAccionDocente": true,
                "perfilResolutorActual": null, "accionesPermitidas": ["MANTENER", "PROPONER"] } | null }
```

`mensaje` de la alerta lo resuelve el backend con `MessageCatalogPort` (`ALR_010`/`ALR_011`). Instantes UTC con `Z`.

### 3.3 Paquetes y clases

```text
BE:application/features/
├── alertainasistencia/
│   ├── consultaralertasestudiante/                 [C.1]
│   ├── marcaralertasleidas/                        [C.2]
│   ├── evaluaralertasautomatico/                   [C.1] (EvaluarAlertasInasistenciaAutomaticoInputPort: job; incluye la actualización de resolutores)
│   ├── common/{AvisoAlertasInasistenciaService, NovedadAlertaInasistencia, ResultadoEvaluacionAlertas}
│   └── exception/AlertaInasistenciaErrorCode
├── revisioncancelacion/
│   ├── decidirrevision/ resolverrevision/ consultarrevisionescoordinador/ consultarrevisionesdecano/   [C.1]
│   ├── consultarrevisionesdocente/                                                                   [C.2]
│   ├── common/{AvisoRevisionCancelacionService, ResultadoTransicionRevision, NovedadResolutoresRevision}
│   └── exception/RevisionCancelacionErrorCode
└── realtime/resolveraudiencia/{ResolverAudienciaRealtimeInputPort, AudienciaRealtimeGrupo}               [C.1]

BE:application/secondaryports/
├── repository/{AlertaInasistenciaRepositoryPort, RevisionCancelacionRepositoryPort (+ actualizarResolutores)}
└── realtime/{RealtimeEvent (+ destinatariosUsuario), RealtimeAudienciaQueryPort}

BE:infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/{AlertaInasistenciaJpaRepository, RevisionCancelacionJpaRepository, RealtimeAudienciaJpaRepository}

BE:infrastructure/adapter/primary/
├── controller/estudiante/EstudianteAlertasController
├── controller/docente/DocenteRevisionCancelacionController       (PATCH en C.1; GET en C.2)
├── controller/coordinador/CoordinadorRevisionCancelacionController
├── controller/decano/DecanoRevisionCancelacionController
├── realtime/sse/{RealtimeAudienciaPolicy, localsse/LocalSseRealtimeStreamGateway, controller/RealtimeEventsController, contract/RealtimeStreamGateway}
└── scheduler/EvaluacionAlertasInasistenciaScheduler

BE:infrastructure/config/wiring/{AlertaInasistenciaWiringConfiguration, RevisionCancelacionWiringConfiguration}
    + AsistenciaWiringConfiguration, TomaAsistenciaWiringConfiguration (B.2), cierre masivo, LocalSseRealtimeAdapterConfiguration
```

`RealtimeEvent` gana el componente final `Set<UUID> destinatariosUsuario` (vacío por defecto), un constructor secundario con los 7 componentes actuales, la fábrica `paraDestinatarios(type, payload, destinatarios)` y `withObservabilityContext` que lo conserva; `RealtimeEventResponse.from` no lo copia. `LocalSseRealtimeStreamGateway` recibe `ResolverAudienciaRealtimeInputPort` en lugar de `InstitutionalScopePort`.

Errores DB → HTTP: `RCN_001` → 404; `RCN_002`, `RCN_003`, `ALR_004`, `COO_002`, `PAG_001` → 400; `RCN_004`, `005`, `006`, `012`, `013`, `014` → 409; `SEC_002`, `COO_003` → 403; `ALR_002` solo en el job.

### 3.4 Motor: invocación y scheduler

- `AvisoAlertasInasistenciaService.evaluarYAvisar(grupoId, estudianteGrupoId)`: motor + avisos (§3.5) + eventos (§3.6.4); captura y registra cualquier fallo.
- **Tras escrituras confirmadas** ([SUPUESTO-C-04]): `RegistrarAsistenciasSesionUseCaseImpl`, `RegistrarAsistenciasTomaUseCaseImpl`, `CerrarTomaAsistenciaUseCaseImpl`, `CerrarTomasVencidasUseCaseImpl` (grupo completo); `ResolverSolicitudRevisionAsistenciaUseCaseImpl` solo con aprobación, con `DestinatarioReclamoProjection.idGrupo` (O-9). Constructores actuales conservados (servicio nulo = sin evaluación). Síncrono con el criterio de §2.14.
- **`EvaluacionAlertasInasistenciaScheduler`** (patrón `RotacionTokenMatriculaScheduler`; `app.alertas-inasistencia.evaluacion.tick = PT1M`, `…enabled = true`): cada pasada (1) grupos pendientes → `evaluarYAvisar`; (2) `actualizarResolutores` → por cada novedad, `PROPUESTA_CANCELACION` a los nuevos resolutores y `REVISION_CANCELACION_REASIGNADA`. Un grupo o revisión que falla no detiene a los demás.
- **Cierre masivo:** el caso de uso evalúa con aviso los grupos del periodo (`consultarGruposPendientes(idPeriodo)`) y luego llama al SP, que **no** evalúa (N-1) y aplica [SUPUESTO-C-10]; si el motor falló para algún grupo, la pérdida sin revisión hace que el SP responda `RCN_012`; como el job solo recorre periodos no terminados, esa pérdida se corrige reintentando el cierre, cuyo caso de uso vuelve a evaluar (con aviso) todos los grupos del periodo (REVIEW-3). El constructor actual de 3 argumentos se conserva (sin servicio = sin evaluación previa en el backend).

### 3.5 Notificaciones

| Momento | Tipo | Destinatarios |
| :--- | :--- | :--- |
| Alerta principal creada | `ALERTA_RIESGO_INASISTENCIA` / `ALERTA_PERDIDA_INASISTENCIA` | Estudiante |
| Revisión creada | `REVISION_CANCELACION_PENDIENTE` | Docente titular |
| `PROPONER` (también con escalamiento) y reasignación por el job | `PROPUESTA_CANCELACION` (`escalamiento` informado si aplica) | Resolutores actuales (**nunca** el proponente, O-2) |
| `APROBAR` | `CANCELACION_APROBADA` | Estudiante y docente |
| `RECHAZAR` | `CANCELACION_RECHAZADA` | Docente |
| `MANTENER` | — | — |

Constantes nuevas en `Notificacion` y entradas en `PlantillaPorDefectoCatalogo`. El tipo lo devuelve el SP. Con el proveedor `log` solo se registra (R8).

### 3.6 SSE

#### 3.6.1 [C.1] Canal de grupo por ámbito

`subscribe(usuarioId, grupoId)` llama una vez `ResolverAudienciaRealtimeInputPort` (→ `usp_consultar_audiencias_realtime_grupo`): `DOCENTE_TITULAR`, `ESTUDIANTE_GRUPO`, `AMBITO_GRUPO`; ninguna → 403 genérico. Instantánea al suscribirse. Entrega si `payload.grupo == grupoId` **y** `RealtimeAudienciaPolicy.entrega(tipo, audiencias, usuarioId, destinatariosUsuario)`.

#### 3.6.2 [C.2] Canal personal

`subscribePersonal(usuarioId)`: sin consulta a la BD; solo tipos con audiencia `DESTINATARIO` cuyo `destinatariosUsuario` contiene al usuario. Mismo heartbeat, envelope y Bearer. `/emit` nunca llega por aquí.

#### 3.6.3 Política de audiencia (igualdad exacta de tipo; tipo no listado → solo titular)

`entrega` = (`audienciasDe(tipo) ∩ delSuscriptor ≠ ∅`) **o** (`DESTINATARIO ∈ audienciasDe(tipo)` y `usuarioId ∈ destinatarios`).

| Tipo | Audiencias | Nota |
| :--- | :--- | :--- |
| `ASISTENCIAS_SESION_ACTUALIZADAS`, `ASISTENCIAS_TOMA_ACTUALIZADAS` | `DOCENTE_TITULAR`, `ESTUDIANTE_GRUPO`, `AMBITO_GRUPO` | Payload sin identidad. En un grupo mixto, el `totalRegistros` que recibe el coordinador de PA incluye registros de PB: es un conteo sin identidad, aceptado y documentado (O-14); el coordinador vuelve a consultar por HTTP, filtrado por su ámbito |
| `SESION_CANCELADA` | `DOCENTE_TITULAR`, `ESTUDIANTE_GRUPO`, `AMBITO_GRUPO` | Sin motivo |
| `ALERTA_INASISTENCIA` | `DOCENTE_TITULAR`, `DESTINATARIO` | — |
| `REVISION_CANCELACION_CREADA`, `REVISION_CANCELACION_DECIDIDA`, `REVISION_CANCELACION_RESUELTA`, `REVISION_CANCELACION_REASIGNADA` | `DOCENTE_TITULAR`, `DESTINATARIO` | — |
| [C.2] `SOLICITUD_REVISION_RESUELTA` | `DESTINATARIO` | — |
| `ASISTENCIA_REGISTRADA`, `MATRICULA_QR_ROTADO`, `ESTUDIANTE_MATRICULADO`, `TOMA_ABIERTA`, `TOMA_CERRADA`, `ASISTENCIA_QR_ROTADO`, `ASISTENCIA_QR_REGISTRADA` | `DOCENTE_TITULAR` | Sin cambio |

#### 3.6.4 Eventos nuevos (tras el commit; `payload.grupo` siempre; sin nombres, correos ni motivos)

| Tipo | Publica | Payload | Destinatarios | Sub |
| :--- | :--- | :--- | :--- | :--- |
| `ALERTA_INASISTENCIA` | `AvisoAlertasInasistenciaService` | `grupo, alerta, estudianteGrupo, tipo, porcentajeInasistencia, umbral` | estudiante | C.1 |
| `REVISION_CANCELACION_CREADA` | ídem | `grupo, revision, estudianteGrupo, estado` | docente | C.1 |
| `REVISION_CANCELACION_DECIDIDA` | `DecidirRevisionCancelacionUseCaseImpl` (`sinCambios = false`) | `grupo, revision, estudianteGrupo, decision, estado, perfilResolutor` | docente; + resolutores si `PROPONER` | C.1 |
| `REVISION_CANCELACION_RESUELTA` | `ResolverRevisionCancelacionUseCaseImpl` (`sinCambios = false`) | `grupo, revision, estudianteGrupo, decision, estado, cambioMatricula` | docente y resolutores; + estudiante si `APROBAR` | C.1 |
| `REVISION_CANCELACION_REASIGNADA` | job (`actualizarResolutores`) | `grupo, revision, estudianteGrupo, perfilResolutor` | docente, resolutores anteriores y nuevos | C.1 |
| `SOLICITUD_REVISION_RESUELTA` | `ResolverSolicitudRevisionAsistenciaUseCaseImpl` | `grupo, solicitud, estado` | estudiante | C.2 |

### 3.7 Seguridad

#### 3.7.1 `SecurityConfig`

`/api/v1/estudiante/alertas/**` → ESTUDIANTE; `/api/v1/docente/revisiones-cancelacion/**` → DOCENTE; `/api/v1/coordinador/revisiones-cancelacion/**` → COORDINADOR; `/api/v1/decano/revisiones-cancelacion/**` → DECANO; `/api/v1/realtime/**` sigue `authenticated()`; `POST /realtime/emit` solo ADMINISTRADOR. El administrador no entra en rutas de coordinador ni de decano (DEC-022 §2).

#### 3.7.2 Catálogo de accesos (`infra/security-baseline/access-catalog.json`) — rutas nuevas (DEC-037/038)

[C.1]:

```json
{"method": "GET",   "path": "/api/v1/estudiante/alertas", "roles": ["ESTUDIANTE"], "access": "ROLES", "ownership": "Solo las alertas de las matriculas del estudiante autenticado (SP)."},
{"method": "PATCH", "path": "/api/v1/docente/revisiones-cancelacion/{revisionId}", "roles": ["DOCENTE"], "access": "ROLES", "ownership": "Docente titular del grupo de la revision (SP; ajena = 404)."},
{"method": "GET",   "path": "/api/v1/coordinador/revisiones-cancelacion", "roles": ["COORDINADOR"], "access": "ROLES", "ownership": "Solo estudiantes con EstudiantePrograma en un programa del coordinador y del grupo (SP, DEC-020)."},
{"method": "PATCH", "path": "/api/v1/coordinador/revisiones-cancelacion/{revisionId}", "roles": ["COORDINADOR"], "access": "ROLES", "ownership": "Resolutor competente del programa del estudiante (SP; ajena = 404; no resuelve su propia propuesta)."},
{"method": "GET",   "path": "/api/v1/decano/revisiones-cancelacion", "roles": ["DECANO"], "access": "ROLES", "ownership": "Solo revisiones escaladas al decano de la facultad del programa o resueltas por el (SP, DEC-043)."},
{"method": "PATCH", "path": "/api/v1/decano/revisiones-cancelacion/{revisionId}", "roles": ["DECANO"], "access": "ROLES", "ownership": "Decano resolutor por escalamiento (sin coordinador competente disponible) (SP; ajena = 404)."}
```

[C.2]:

```json
{"method": "PATCH", "path": "/api/v1/estudiante/alertas/lectura", "roles": ["ESTUDIANTE"], "access": "ROLES", "ownership": "Solo marca alertas propias; ids ajenos se ignoran (SP)."},
{"method": "GET",   "path": "/api/v1/docente/revisiones-cancelacion", "roles": ["DOCENTE"], "access": "ROLES", "ownership": "Solo revisiones de grupos donde el docente es titular (SP)."},
{"method": "GET",   "path": "/api/v1/realtime/stream/personal", "roles": ["ADMINISTRADOR", "DECANO", "COORDINADOR", "DOCENTE", "ESTUDIANTE"], "access": "AUTHENTICATED", "ownership": "Solo eventos con el usuario autenticado como destinatario explicito."}
```

Modificada (solo `ownership`): `GET /api/v1/realtime/stream` → "Ambito al suscribirse (SP): docente titular, estudiante con matricula activa, coordinador o decano con ambito sobre el grupo, administrador de la institucion; entrega por tipo segun RealtimeAudienciaPolicy."

Tras mezclar cada subpaquete, el responsable ejecuta desde `GestioAsistenciaBackend` (Python de Windows) `python -X utf8 -I infra\security-baseline\scripts\provision_asistencias.py pdp`, luego `verify` y `verify-decisions` (B-01). Hasta entonces las rutas nuevas responden 403 `NO_APPLICABLE_POLICY`; el canal de grupo funciona sin el PDP.

### 3.8 OpenAPI y contratos WORM (O-10)

**C.1:**
- `openapi-golden-path.yaml` **1.5.0** (sobre la 1.4.0 de B2; si no está, C espera): solo la `description` de `GET /api/v1/realtime/stream` (ámbito por rol; 403 sin ámbito) y una línea en `info.description`. `x-roles`, `GrupoIdQuery` y `RealtimeEventResponse` sin cambio. Copias: Infra y backend, idénticas.
- `BACKEND_GOLDEN_PATH_CONTRACT.md` fila 6: "el gateway resuelve el ámbito por rol (SP `usp_consultar_audiencias_realtime_grupo`) y filtra por tipo con `RealtimeAudienciaPolicy`". Copias: Infra, backend y **frontend** (`GestioAsistenciaFrontend/docs/contracts/external/backend/BACKEND_GOLDEN_PATH_CONTRACT.md` + su `.sha256` + `PROVENANCE.md` con commit y fecha de origen). C deja las tres idénticas; la del frontend ya estaba desfasada: se sincroniza desde la del backend y se anota en `PROVENANCE.md`.
- Contrato de eventos: **primero** se sincroniza `INFRA:docs/contracts/events/REALTIME_EVENT_CONTRACT.md` con `GestioAsistenciaBackend/docs/contracts/REALTIME_EVENT_STANDARD.md` (hoy `e016…` frente a `2263…`: la copia del backend ya tiene las filas de B.1, deriva previa a C); luego ambos reciben los tipos nuevos de C.1, la tabla de audiencias de §3.6.3 y, en la fila "Evento neutral", `destinatariosUsuario` como metadato interno no serializado. Quedan idénticos.
- Hashes regenerados en el commit de contrato tras la aprobación 9.2: **Infra 3** (`openapi-golden-path.sha256`, `BACKEND_GOLDEN_PATH_CONTRACT.sha256`, `REALTIME_EVENT_CONTRACT.sha256`), **backend 2** (`openapi-golden-path.sha256`, `BACKEND_GOLDEN_PATH_CONTRACT.sha256`; `REALTIME_EVENT_STANDARD.md` no tiene `.sha256`), **frontend 1** (`BACKEND_GOLDEN_PATH_CONTRACT.sha256`). `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001` sin `CROSS_REPO_DRIFT`.

**C.2:** segundo cambio del contrato de eventos (Infra y backend): el invariante "`grupoId` obligatorio" pasa a "obligatorio en el canal de grupo; el canal personal no recibe `grupoId` y solo entrega eventos con destinatario explícito"; tipo `SOLICITUD_REVISION_RESUELTA`. Regenera `REALTIME_EVENT_CONTRACT.sha256`. El golden path no cambia en C.2.

### 3.9 Pruebas del backend

#### 3.9.1 Nuevas (RED)

| Grupo | Pruebas | Sub |
| :--- | :--- | :--- |
| Casos de uso (100 % en paquetes nuevos; bundle ≥ 80/70) | `AvisoAlertasInasistenciaServiceTest` (sin novedades no avisa; principal → plantilla al estudiante; no principal → solo evento; revisión → docente + `REVISION_CANCELACION_CREADA`; fallos no propagan; destinatarios en metadato, no en payload); `Decidir…`/`Resolver…UseCaseImplTest` (cada código; `sinCambios` sin efectos; `PROPONER` → resolutores sin el proponente; escalamiento → `RCN_015` y aviso al decano; `APROBAR` → estudiante y docente; `RECHAZAR` → docente; `MANTENER` sin correo); consultas de coordinador y decano; los casos de uso de tomas, lote, reclamo y cierre llaman al servicio solo tras éxito; el token no | C.1 |
| Scheduler | Arranque/parada, pasada con evaluación y actualización de resolutores, un fallo no detiene el resto, `CorrelationIdContext` por pasada | C.1 |
| SSE | `RealtimeAudienciaPolicyTest` (tabla §3.6.3, igualdad exacta, no listado → titular, `DESTINATARIO` exige pertenencia); `LocalSseRealtimeStreamGatewayTest` (5 roles con ámbito, sin ámbito 403, el estudiante recibe `ASISTENCIAS_*`/`SESION_CANCELADA` y no la alerta de otro ni `ASISTENCIA_QR_ROTADO`, el coordinador no recibe `ALERTA_INASISTENCIA`); JSON serializado sin `destinatariosUsuario`; [C.2] canal personal | C.1/C.2 |
| Controladores | Forma exacta, 400/401/403/404/409, cuerpo extra → 400, consistencia `SecurityConfig` ↔ `access-catalog.json` | C.1/C.2 |
| ArchUnit | Reglas existentes + el gateway usa `ResolverAudienciaRealtimeInputPort`; el scheduler solo usa `InputPort` | C.1 |
| Contrato SP (`-Pintegration`) | Nombre, parámetros y columnas de los SP nuevos y de los 2 modificados; lectura de `novedadesJSON`; p95 del motor ≤ 300 ms (§2.14); **`CierreMasivoRcn012IT`** (N-1): con una pérdida sin revisión en un periodo del fixture, `POST /api/v1/admin/cierre-masivo` (por `CierrePeriodoJpaRepository` y `JpaProcedureExecutor`) responde **409** con el `message` de `RCN_012`, sin cambios en `EstudianteGrupo`; con el periodo resuelto responde 200 | C.1 |
| E2E (`INFRA:scripts/tests/test_culm001_c.ps1`, PKCE) | Faltas → alerta → decisión → resolución → `CI` → lote rechazado; stream del estudiante y del coordinador 200, sin ámbito 403; rutas nuevas 403 mientras siga B-01 (documentado) | C.1 |

#### 3.9.2 Pruebas existentes que cambian (O-4)

| Archivo / caso | Aserción actual | Aserción nueva | Justificación |
| :--- | :--- | :--- | :--- |
| `BE-T:…/realtime/sse/localsse/LocalSseRealtimeStreamGatewayTest` (6 casos con `when(institutionalScopePort.canDocenteAccessGrupo(...))`) | Titularidad por `InstitutionalScopePort` | El colaborador pasa a `ResolverAudienciaRealtimeInputPort` (mock que devuelve `docenteTitular = true` o sin audiencias); **las aserciones de cada caso no cambian** (autoriza una vez, 403 en grupo ajeno, filtra otros grupos, descarta sin `grupo`, conteo, `emit`) | DEC-039 §5 / DEC-022 §1: el ámbito sale del SP |
| `BE-T:…/realtime/sse/controller/RealtimeStreamErrorHttpTest` (`setUp` l.48-56) | Gateway construido con `InstitutionalScopePort` | Construido con el nuevo puerto; los 4 casos (403 JSON en grupo ajeno, 400 sin `grupoId`, 400 no UUID, stream en grupo propio) sin cambio de aserción | Ídem |
| `BE-T:…/realtime/sse/RealtimeAudienciaPolicyTest` `el_gateway_entrega_sesion_cancelada_al_titular…` | Gateway con `scope.canDocenteAccessGrupo` | Con el nuevo puerto; aserción igual. `los_tipos_de_negocio_se_entregan_al_titular…` y `un_tipo_sin_audiencias…` sin cambio | Ídem |
| `BE-T:…/ejecutarcierremasivo/EjecutarCierreMasivoUseCaseImplTest` y `EjecutarCierreMasivoAvisoTest` | Constructor de 3 argumentos | **Sin cambio** (constructor conservado); se añaden casos con el servicio de alertas (evalúa antes del SP; `RCN_012` se traduce a 409) | — |
| `BE-T:…/RbacSecurityFilterChainTest` l.702-722 (`/realtime/stream`) | Cualquier rol autenticado 200 en la capa HTTP | **Sin cambio**; se añaden casos para las rutas nuevas (C.1) y `/realtime/stream/personal` (C.2) | — |
| `OpenApiGoldenPathConformanceTest` | Versión 1.4.0 | 1.5.0 | DEC-032 |

---

## 4. Frontend (`GestioAsistenciaFrontend`)

### 4.1 Reglas comunes

Standalone + `OnPush`; `input()`/`output()`/`model()`; `signal`/`computed`/`effect` con `onCleanup`. Sin `setInterval`, `setTimeout` recursivo, `interval()` ni `debounceTime`; `switchMap` para cancelar recargas solapadas. Textos de negocio del backend. Solo tokens (`lint:tokens`); estados por `InasistenciaMarcaBadgeComponent`. Móvil primero en lo del estudiante (360–414 px, sin scroll horizontal, objetivos ≥ 44 × 44 px); bandejas responsive (tarjetas en `< md`). Interruptor `features.cancelacionInasistenciaEnabled`.

**Carga y reconexión ([SUPUESTO-C-18], O-5, N-2):** cada vista o almacén **suscrito al SSE** carga por HTTP **al entrar**, recarga en cada **reconexión** (transición a `CONNECTED` desde `RECONNECTING` o `ERROR`; el primer `CONNECTED` tras `CONNECTING` no recarga) y recarga por evento (§L del golden path). Así, `CONNECTING → CONNECTED → RECONNECTING → CONNECTED` + 1 evento = **3 cargas** (entrada, reconexión, evento). Si el transporte nunca conecta (`UNAUTHORIZED`/`ERROR`), la carga de entrada ya mostró los datos. Las vistas **no suscritas** en C.1 (página de alertas, bandejas de coordinador y decano, contadores del menú) cargan al entrar y tras cada acción propia, sin `connectionState$`. Nunca por temporizador.

### 4.2 Modelos, servicios y tiempo real

| Archivo | Contenido | Sub |
| :--- | :--- | :--- |
| `FE:core/models/alerta-inasistencia.model.ts` | `TipoAlerta`, `EstadoAlerta`, `AlertaInasistencia`, `MarcarLecturaResponse` | C.1 |
| `FE:core/models/revision-cancelacion.model.ts` | `DecisionDocente`, `DecisionResolutor`, `PerfilResolutor = 'COORDINADOR' \| 'DECANO'`, `RevisionCancelacion`, `MarcaInasistencia`, filtros | C.1 |
| `FE:core/services/alerta-inasistencia.service.ts` | `consultar(filtro)`, `contarVigentes()` (`soloVigentes=true&tamano=1`) (C.1); `contarNoLeidas()`, `marcarLeidas(ids)` (C.2) | C.1/C.2 |
| `FE:core/services/revision-cancelacion.service.ts` | `decidir`, `consultarCoordinador`, `resolverCoordinador`, `consultarDecano`, `resolverDecano`, `contarPendientes(rol)` (C.1); `consultarDocente` (C.2) | C.1/C.2 |
| Servicio de resumen del docente (B.2) | Mapea `marca` | C.1 |
| `FE:core/realtime/model/realtime-event.model.ts` | Tipos nuevos con payloads tipados | C.1/C.2 |
| `FE:core/realtime/contract/realtime-transport.ts` + `adapter/sse/fetch-sse-realtime-transport.ts` | `RealtimeSubscriptionScope = { tipo: 'GRUPO'; grupoId } \| { tipo: 'PERSONAL' }`, `REALTIME_TRANSPORT_FACTORY`, URL por alcance | C.2 |
| `FE:core/realtime/personal-realtime.service.ts` | Segunda instancia `PERSONAL`; inicia con la sesión y se detiene al cerrarla | C.2 |
| `FE:core/realtime/avisos/avisos-realtime.store.ts` | Signals `alertasNoLeidas`, `revisionesPendientes`; carga HTTP al iniciar sesión, en cada reconexión del canal personal y por evento (dedupe por `eventId`); toast con el `mensaje` de la alerta más reciente | C.2 |
| `FE:core/interceptors/mock-backend.interceptor.ts` | Formas exactas de §3.2 si hay modo mock | C.1 |

### 4.3 Estudiante (móvil primero)

- **[C.1] Página `/app/estudiante/alertas`** (`features/student/student-alerts/`): tarjetas (badge por tipo, `mensaje` del backend, asignatura, `porcentajeActual` de `umbralPerdida`, fecha local, "Ver materia"); filtro por grupo; `PaginationComponent`; carga al entrar. La entrada de menú muestra el número de alertas **vigentes** (`contarVigentes()`, N-3), cargado al iniciar el layout y al volver de la página (en C.1 el menú no se suscribe al SSE); baja cuando la alerta pasa a `SUPERADA`. El contador de no leídas llega con la campana de C.2; si C.2 se difiere, se anota en `CLOSURE.md`.
- **[C.1] Detalle de la materia** (`student-course-detail`): si `estadoMatricula === 'A'`, `startForGroup(grupoId)` (si no, no se suscribe: el gateway respondería 403); carga al entrar y en cada reconexión; recarga sesiones e indicadores ante `ASISTENCIAS_SESION_ACTUALIZADAS`, `ASISTENCIAS_TOMA_ACTUALIZADAS` y `SESION_CANCELADA`; ante `ALERTA_INASISTENCIA` (destinatario) muestra un toast con el `mensaje` obtenido por HTTP; `stop` al salir. `CI` → "Cancelado por inasistencia" sin acciones de reclamo (HU059).
- **[C.2] Campana** (`shared/components/avisos-campana/`): cabecera móvil y barra lateral; contador de `AvisosRealtimeStore`; hoja inferior en móvil con las 5 más recientes; al mostrar alertas no leídas, `marcarLeidas`.
- **[C.2] Reclamos:** ante `SOLICITUD_REVISION_RESUELTA` recarga la lista.

### 4.4 Docente

- **[C.1] Planilla** (`teacher-grupo-sabana.component.ts`): columna "Seguimiento" con `InasistenciaMarcaBadgeComponent` (Riesgo / Pérdida: decide / Mantenido / Propuesto a coordinación / Propuesto a decanatura / Rechazado / Cancelado por inasistencia) y botón "Decidir" si `marca.revision.accionesPermitidas` no está vacío, que abre `RevisionDecisionModalComponent` (`features/teacher/revision-cancelacion/`): opciones según `accionesPermitidas`, motivo obligatorio con contador de caracteres (sin límites numéricos, [SUPUESTO-C-19]), confirmación al proponer, `mensajeUsuario` del backend (incluido `RCN_015` del escalamiento) o el error (`RCN_003`, `RCN_006`, `RCN_013`). Canal de grupo: carga al entrar y en cada reconexión; recarga ante `ALERTA_INASISTENCIA` y `REVISION_CANCELACION_*`. La advertencia no notifica al docente (solo marca).
- **[C.2] Bandeja `/app/docente/revisiones-cancelacion`**: filtros "Pendientes de mi decisión / Todas" y grupo; reutiliza el modal; menú con badge de `AvisosRealtimeStore`.

### 4.5 [C.1] Coordinador y decano (resolución)

`RevisionesResolucionComponent` (`features/shared/revisiones-resolucion/`, con `input<'COORDINADOR' | 'DECANO'>()`), montado en `/app/coordinador/revisiones-cancelacion` y `/app/decano/revisiones-cancelacion`: filtros "Pendientes de resolver / Todas", programa (selector; obligatorio solo si el backend responde `COO_002`) y grupo (coordinador); cada fila con estudiante, programa, docente, asignatura y grupo, porcentaje actual, motivo del docente, perfil resolutor y, si fue escalada, la etiqueta "Escalada a decanatura". `RevisionResolucionModalComponent`: "Aprobar cancelación" / "Rechazar", motivo obligatorio, confirmación explícita al aprobar; muestra el mensaje del backend: `RCN_011` ("ya estaba registrada") cuando otro resolutor tomó la misma decisión, `RCN_004` cuando tomó la contraria, además de `RCN_006` y `RCN_014` (O-13). Carga al entrar; en C.1 recarga tras cada acción propia; en C.2 también por `REVISION_CANCELACION_*` del canal personal y en cada reconexión de ese canal. Sin edición de asistencias. El menú muestra `contarPendientes(rol)`, cargado por HTTP al iniciar el layout.

### 4.6 [C.1] Vistas de grupo de coordinador y decano (F-TRX-006 / F-DEC-012)

`coordinador/asistencias` (grupo seleccionado) y `decano/grupos/:grupoId`: `startForGroup(grupoId)`; carga al entrar y en cada reconexión; recarga ante `ASISTENCIAS_SESION_ACTUALIZADAS`, `ASISTENCIAS_TOMA_ACTUALIZADAS` y `SESION_CANCELADA`; `stop` al salir.

### 4.7 Rutas y menú

[C.1] `estudiante/alertas`, `coordinador/revisiones-cancelacion`, `decano/revisiones-cancelacion`; [C.2] `docente/revisiones-cancelacion`. `authGuard` + `roleGuard`; menús detrás de `features.cancelacionInasistenciaEnabled`.

### 4.8 Pruebas del frontend

- Servicios: URL, método, parámetros y cuerpo exactos; `message` del backend en 400/403/404/409.
- **Carga y reconexión (O-5, N-2):** para las vistas suscritas (planilla, detalle de la materia, vistas de grupo de coordinador y decano y, en C.2, `AvisosRealtimeStore` y las bandejas con canal personal), el spec emite `connectionState$` `CONNECTING → CONNECTED → RECONNECTING → CONNECTED` y un evento, y exige **exactamente 3** cargas HTTP (entrada, reconexión, evento) y ninguna otra; un segundo caso emite `CONNECTING → ERROR` y exige 1 carga (la de entrada). Para las no suscritas en C.1 (página de alertas, bandejas de coordinador y decano, contadores del menú), el spec exige 1 carga al entrar y 1 tras cada acción propia, y que no se suscriban a `connectionState$`; `spyOn(window, 'setInterval')`/`setTimeout` sin llamadas en lo nuevo.
- Detalle de la materia: con `estadoMatricula = 'CI'` no llama `startForGroup`.
- Planilla: badges por estado (incluido "Propuesto a decanatura"); "Decidir" solo con `accionesPermitidas`.
- Modales: motivo obligatorio, opciones según `accionesPermitidas`, confirmación, mensajes del backend (`RCN_011` y `RCN_004` se muestran con el texto del backend, sin lógica del cliente), sin límites numéricos.
- `RevisionesResolucionComponent` con ambos roles; etiqueta de escalamiento.
- Página de alertas a 375 px: tarjetas sin scroll horizontal, objetivos ≥ 44 px.
- [C.2] Transporte `PERSONAL` (`/realtime/stream/personal`, sin query, sin token en la URL, independiente del de grupo); store con dedupe por `eventId`; campana accesible.
- `npm run coverage:realtime:check` ≥ 90/80.

---

## 5. Documentación, orden de integración, ramas y commits

### 5.1 Documentación

`HU-CATALOG.md` (HU026C, HU041, HU047, HU174 en C.1; HU042 en C.2); `TECHNICAL_DEBT.md` (notificaciones de alertas sin reintento previo al outbox; SSE `local-sse` de una JVM con audiencias por instantánea; vista del administrador diferida; marca de agua con solape; revisión sin resolutor posible si una facultad no tiene decano activo); contratos WORM (§3.8) y addendum (§2.12); `HTTP_AS_IS_MATRIX.md`; `docs/realtime-sse-architecture.md` y `docs/rutas-por-rol.md` del workspace; `RED.md`, `AUDIT-PANTALLA.md` (escritorio y 375 × 812), `CLOSURE.md`, `PRS.md`, `ESTADO.md`.

### 5.2 Orden de integración

**C.1** — rama `feature/CULM-001-C1-cancelacion-inasistencia` en los 4 repos desde `integracion/CULM-001` con A, B.1, B.2 y B2:
1. **DB:** catálogos/tablas/FKs → funciones (despliegue limpio C-DB-62) → vistas → motor, consultas, decisión, resolución, resolutores, audiencias → §2.6 → semillas/permisos → migración 19 (con el texto post-B2 copiado en el `down`) → pruebas (§2.13, incluidas las existentes de §2.13.2) → manifiesto tras 9.2. Gate: `db-test` sin fallos nuevos, `freeze-manifest.ps1 -Mode Verify`.
2. **Backend:** `RealtimeEvent` + política + gateway → puertos/adaptadores → casos de uso y avisos → invocación tras escrituras, scheduler y cierre → controladores, seguridad, catálogo → contratos. Gate: `mvnw verify` (con `JAVA_TOOL_OPTIONS` de `ESTADO.md`) e IT `-Pintegration`.
3. **Frontend:** modelos/servicios → planilla y modal → bandejas de coordinador y decano → alertas del estudiante → suscripciones de grupo. Gate: `npm run verify`.
4. **Infra:** sincronización previa de `REALTIME_EVENT_CONTRACT.md`, golden path 1.5.0 en las 3 copias, contrato de eventos, `.sha256`, `test_culm001_c.ps1` y `test_all_hus.ps1`, catálogo, deuda. Gate: `infra.ps1 verify`, `verify-contracts.ps1 -Root …`.
5. **PDP** (B-01) y **AUDIT** en pantalla con los 5 roles y el grupo mixto.

**C.2** — rama `feature/CULM-001-C2-avisos-personales` desde integración con C.1: DB (SP de lectura y bandeja del docente + grants) → backend (canal personal, lectura, bandeja del docente, HU042) → frontend (transporte, store, campana, bandeja) → Infra (contrato de eventos). Mismos gates; PDP para sus 3 rutas.

PRs hacia `integracion/CULM-001`: Backend `alejovh12/AsistenciasUCO`, DB `johnjduque/gestion-asistencia-db` (DEC-002), Frontend `shesho22/AsistenciasUCO-Frontend`, Infra `AsistenciasUCO/AsistenciasUCO-Infra`.

### 5.3 Commits (Conventional Commits en español, imperativo, ≤ 72 caracteres, atómicos por capa; `Refs: HU026C` + `Refs: CULM-001`)

**C.1**
- DB: `feat(db/tables): agregar alertas y revisiones de cancelacion por inasistencia` · `feat(db/functions): resolver resolutores de cancelacion sobre tablas base` · `feat(db/views): exponer alertas, revisiones y marcas de inasistencia` · `feat(db/sp): evaluar alertas de inasistencia por horas en el grupo` · `feat(db/sp): decidir revision de cancelacion por el docente titular` · `feat(db/sp): resolver revision por coordinador o decano escalado` · `feat(db/sp): reasignar resolutores de revisiones pendientes` · `feat(db/sp): resolver audiencias realtime por ambito del usuario` · `refactor(db/sp): aplicar umbral por horas y bloqueo al cierre masivo` · `feat(db/sp): agregar marcas de inasistencia al resumen del docente` · `feat(db/seed): sembrar catalogos, parametros, mensajes y plantillas de C` · `feat(db/migrations): agregar migracion 19 de cancelacion por inasistencia` · `test(db): adaptar cierre masivo a la regla por horas de C` · `test(db): cubrir alertas, revisiones, escalamiento y despliegue limpio` · `docs(db/contracts): registrar manifiesto post-freeze de CULM-001 C`
- Backend: `test(backend): agregar pruebas RED de alertas y revisiones` · `feat(backend/realtime): abrir el stream de grupo por ambito del rol` · `feat(backend/ports): agregar puertos de alertas, revisiones y audiencias` · `feat(backend/adapter): ejecutar los SP de alertas y revisiones` · `feat(backend/usecase): evaluar alertas y avisar tras registrar asistencia` · `feat(backend/usecase): decidir, resolver y escalar revisiones` · `feat(backend/scheduler): evaluar alertas y reasignar resolutores` · `feat(backend/controller): exponer alertas y bandejas de revisiones` · `feat(backend/security): registrar rutas de C.1 en el catalogo de acceso` · `docs(backend): publicar golden path 1.5.0 y eventos de C.1`
- Frontend: `test(frontend): agregar specs RED de alertas y revisiones` · `feat(frontend/docente): marcar riesgo y decidir revisiones en la planilla` · `feat(frontend/coordinador): resolver propuestas de cancelacion` · `feat(frontend/decano): resolver propuestas escaladas` · `feat(frontend/estudiante): mostrar alertas de inasistencia en movil` · `feat(frontend/realtime): suscribir vistas de grupo por ambito` · `docs(frontend): sincronizar golden path 1.5.0 del backend`
- Infra: `docs(contracts): sincronizar contrato de eventos con el backend` · `docs(contracts): publicar golden path 1.5.0 y eventos de C.1` · `test(scripts): agregar flujo de cancelacion a test_all_hus` · `docs(hus): actualizar HU026C, HU041 y HU174 en el catalogo` · `docs(baseline): registrar deudas del paquete C`

**C.2**
- DB: `feat(db/sp): marcar alertas leidas y listar revisiones del docente`
- Backend: `feat(backend/realtime): agregar canal personal de avisos` · `feat(backend/controller): marcar alertas leidas y bandeja del docente` · `feat(backend/usecase): publicar SSE al resolver reclamos HU042`
- Frontend: `feat(frontend/realtime): agregar canal personal y almacen de avisos` · `feat(frontend/estudiante): agregar campana de alertas` · `feat(frontend/docente): agregar bandeja de revisiones de cancelacion`
- Infra: `docs(contracts): registrar canal personal en el contrato de eventos` · `docs(hus): actualizar HU042 en el catalogo`

---

## 6. Riesgos, rollback y diferidos

### 6.1 Riesgos

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| R1 | Dependencia de B.2 y B2 | Precondición en la migración 19 (O-12); el RED espera la integración |
| R2 | B-01: rutas nuevas en 403 hasta provisionar el PDP | §3.7.2; el canal de grupo no depende del PDP |
| R3 | El primer pase del job notifica de golpe | Interruptor; lote de 50 grupos por minuto; reporte en la migración |
| R4 | Cierre masivo bloqueado por casos sin decidir | Solo con el motor activo (O-3); mensaje con el total; con el motor apagado no bloquea y queda auditado |
| R5 | Revisión sin resolutor (programa sin coordinador y facultad sin decano activo) | Escalamiento automático; `RCN_013` al proponer; el job audita `REVISION_CANCELACION_SIN_RESOLUTOR`; el administrador activa al decano (deuda registrada) |
| R6 | Concurrencia (motor, resolución, cierre, retiro) | Cerrojo por grupo, índices únicos, comprobación del cierre dentro de su transacción, orden de bloqueos (§2.0); C-DB-46 y C-DB-50 |
| R7 | Fuga por SSE | Eventos personales solo por destinatario calculado en BD; eventos de grupo sin identidad; destinatarios no serializados |
| R8 | Proveedor de notificaciones `log` | `outbox`/`composite` en la demo; la información está en la BD |
| R9 | Cambio del record `RealtimeEvent` | Constructor secundario compatible |
| R10 | Latencia del motor | p95 ≤ 300 ms o ejecución tras responder (§2.14) |
| R11 | Regla de programas del grupo duplicada en la función (O-1) | Prueba de paridad C-DB-63 en cada `db-test` |

### 6.2 Rollback

- **Sin despliegue:** `ALERTA_INASISTENCIA/HABILITADA = false` (el motor no escribe y el cierre masivo no se bloquea), `app.alertas-inasistencia.evaluacion.enabled = false`, `features.cancelacionInasistenciaEnabled = false`.
- **Por capas:** revertir los PRs (C.2 antes que C.1; en cada uno Frontend → Backend → DB) y ejecutar `19_…_down.sql`, que deja la BD como estaba **después de B2** (O-6) y archiva lo de C sin reactivar matrículas `CI`. Backup `COPY_ONLY` antes de cada `up` compartido. Los `.sha256` se restauran con el revert de los commits de contrato (Infra, backend y frontend).

### 6.3 Diferido (post 2026-11-13)

Vista institucional de revisiones del administrador; reintento de notificaciones de alertas; evento institucional para refrescar KPIs; reactivación administrada de una matrícula `CI`; C.2 completo si no entra.

---

## 7. Respuesta a REVIEW-1

| Objeción | Tipo | Respuesta (sección) |
| :--- | :--- | :--- |
| O-1 función de coordinadores con vistas y orden de despliegue | Bloqueante | Reemplazada por `ufn_revision_cancelacion_resolutores`: solo tablas base, sin llamar a otras funciones de usuario, regla S1 replicada con prueba de paridad C-DB-63 y despliegue limpio C-DB-62 (§2.3, §2.13.1). DEC-043 O-1 |
| O-2 revisión atascada si el único coordinador es el proponente | Bloqueante | El proponente queda excluido; sin coordinador, escala al decano con historial y auditoría `ESCALAR`; reasignación en vivo y por job si el coordinador se desactiva o cambia (`usp_actualizar_resolutores_revisiones_cancelacion`); `RCN_013` solo sin coordinador ni decano; bandeja y endpoints del decano; C-DB-29, C-DB-33, C-DB-34 (§0 C-09, §2.5.6–§2.5.8, §2.5.11, §3.2, §4.5). DEC-043 O-2 |
| O-3 cierre bloqueado con el motor apagado o umbral inválido | Bloqueante | `RCN_012` solo con el motor habilitado y umbrales válidos; en otro caso `A → F` con auditoría detallada; C-DB-43 y C-DB-44 (§0 C-10, §2.6). DEC-043 O-3 |
| O-4 pruebas existentes que cambian | Bloqueante | Tablas §2.13.2 (BD) y §3.9.2 (backend) con aserción actual, nueva y justificación; ninguna se elimina sin reemplazo |
| O-5 contadores sin carga inicial ni tras reconexión | Bloqueante | [SUPUESTO-C-18]: HTTP al entrar, en cada reconexión y por evento (precisado por N-2 en v3); spec que exige exactamente esas cargas; el detalle de la materia no se suscribe si la matrícula no es `A` (§4.1, §4.3–§4.6, §4.8) |
| O-6 `down` incompatible con B2 | Bloqueante | El `down` restaura el estado inmediatamente anterior a C (texto post-B2 sin `idPrograma`); C-DB-60 compara `sys.sql_modules` sobre esa base; orden de `down` entre paquetes documentado (§2.11) |
| O-7 comprobación del cierre fuera de la transacción | No bloqueante | Dentro de la transacción, con `UPDLOCK, HOLDLOCK` en `RevisionCancelacion → EstudianteGrupo`; caso en C-DB-50 (§2.6) |
| O-8 marca de agua | No bloqueante | Corte capturado al inicio, `DATETIME2(3)` y solape `ALERTA_INASISTENCIA/SOLAPE_MARCA_SEGUNDOS`; caso límite en C-DB-11 (§2.2, §2.5.1–§2.5.2) |
| O-9 `idGrupo` ya existe en destinatarios de reclamo | No bloqueante | Cambio retirado; se usa `DestinatarioReclamoProjection.idGrupo` (§2.6, §3.4) |
| O-10 inventario WORM | No bloqueante | Sincronización previa del contrato de eventos de Infra con el del backend; copia del golden path del frontend con `PROVENANCE.md`; hashes 3 + 2 + 1; `destinatariosUsuario` en la fila "Evento neutral" (§3.8) |
| O-11 ámbito SSE duplicado | No bloqueante | `esAmbitoLectura` con `ufn_programas_grupo ∩ ufn_programas_ambito_ejecutor` de B2 (§2.5.10) |
| O-12 precondiciones de la 19 | No bloqueante | `THROW 50019` si falta B.2 o B2; caso en C-DB-60 (§2.11) |
| O-13 huecos de prueba | No bloqueante | C-DB-46 (dos resolutores concurrentes); textos `RCN_011`/`RCN_004` alineados en el cliente; revisión con pérdida ya superada en C-DB-40 y en el texto de `RCN_012` (§2.7, §2.13.1, §4.5) |
| O-14 detalles menores | No bloqueante | Vista de historial retirada; auditoría `ALERTA_INASISTENCIA_ACTUALIZADA`; significado del contador de `Grupo` en el addendum ([SUPUESTO-C-20]); `totalRegistros` en grupos mixtos documentado (§3.6.3); p95 ≤ 300 ms o ejecución tras responder (§2.14) |
| §3 alcance frente al plazo | Recomendación | Adoptada como C.1/C.2 por DEC-043 (§1.1). A diferencia de la sugerencia, C.1 conserva la bandeja del decano (necesaria para el escalamiento) y las suscripciones de grupo de coordinador y decano (cierran F-TRX-006) |

---

## Adenda DEC-065 (2026-11-09)

Segunda ronda de hallazgos del responsable (DEC-065 (1)): la decisión final de la cancelación de matrícula por inasistencia es del **coordinador del programa**; se retira el escalamiento al decano. Esta adenda **supersede** [SUPUESTO-C-09] (en lo relativo al escalamiento y a la resolución por el decano) y las pruebas **C-DB-29**, **C-DB-33** y **C-DB-34** de §2.13.1; el resto del contrato sigue vigente. Implementación en la migración `31_mrm_coordinador_decide_cancelacion` de `GestioAsistenciaDB` (rama `feat/mejoras-revision-manual`).

### A.1 Regla de negocio (sustituye a [SUPUESTO-C-09])

| Aspecto | Comportamiento vigente |
| :--- | :--- |
| Resolutores | Coordinadores activos titulares (`Programa.coordinador`) de los programas que están a la vez en `EstudiantePrograma` del estudiante y entre los programas vigentes del grupo, **excluido el proponente**. `ufn_revision_cancelacion_resolutores` ya no devuelve decanos; `esEscalamiento` se conserva por compatibilidad y es siempre `0`. |
| Proponer sin coordinador disponible | `usp_decidir_revision_cancelacion` responde `RCN_013` (409) sin cambios de estado ni historial: «El programa no tiene coordinador activo para resolver la revisión; solicite su asignación al decano.». Ya no hay `RCN_015`, ni evento `ESCALAR`, ni auditoría `ESCALAR_REVISION_CANCELACION`; `codigoPerfilResolutorActual` es siempre `COORDINADOR` y `fechaEscalamientoUtc` siempre `NULL`. La salida conserva `codigoPerfilResolutor` y `esEscalamiento` (`0`). |
| Decano resuelve | `usp_resolver_revision_cancelacion` responde `RCN_016` (el código HTTP lo fija el clasificador del backend): «La resolución de la revisión corresponde al coordinador del programa.», sin cambios de estado. La ruta de auditoría `/api/v1/decano/revisiones-cancelacion/{revisionId}` desaparece (solo `/coordinador/`). El decano conserva solo lectura y auditoría. |
| Job de resolutores | `usp_actualizar_resolutores_revisiones_cancelacion` solo `REASIGNAR` (a otro coordinador) o deja la revisión sin resolutor (`REVISION_CANCELACION_SIN_RESOLUTOR`, una vez por cambio de huella); `revisionesEscaladas` es siempre `0`. Las revisiones escaladas antes de la migración se reasignan al coordinador en la primera corrida (huella distinta). |
| Mensajes | `RCN_013` con el texto nuevo; `RCN_015` queda **en desuso** (no se emite); `RCN_016` nuevo (`BUSINESS_ERROR`, `MEDIO`). |

### A.2 Consultas (§2.5.7)

| SP | Cambio |
| :--- | :--- |
| `usp_consultar_revisiones_cancelacion_decano_paginado` | Solo consulta: **todas** las revisiones (cualquier estado) de los grupos que tienen algún programa de la facultad del decano (`ufn_programas_ambito_ejecutor`, rol `DECANO`). Filtros y resultset sin cambios (`@soloPendientes` = las que esperan al coordinador, `@codigoEstado`, `@idPrograma` → `COO_003` si es de otra facultad); `esResolutorActual` siempre `0` y `accionesPermitidas` siempre vacío. |
| `usp_consultar_revisiones_cancelacion_docente_paginado` (nuevo) | `(@idUsuario, @idCorrelacion, @soloPendientes BIT = 1, @idGrupo = NULL, @estado = NULL, @numeroPagina = 1, @tamanoPagina = 20)`. RBAC `DOCENTE`; revisiones de los grupos donde es titular, mismas columnas que el SP del coordinador (`uv_revision_cancelacion` + `idPrograma`, `nombrePrograma`, `porcentajeActual`, `horasFaltaActual`, `horasDictadasActual`, `umbralPerdida`, `esResolutorActual` = 0, `accionesPermitidas` = vacío, `totalRegistros`). «Pendiente» = estado con `requiereAccionDocente` (`PENDIENTE_DOCENTE`). Orden: fecha de cruce (creación) descendente. `@idGrupo` que no es suyo → `SEC_002`; `@estado` inexistente → `RCN_002`. `EXECUTE` para `rol_asistencias_runtime`. |

### A.3 Pruebas que se superseden

| ID | Nuevo comportamiento esperado |
| :--- | :--- |
| C-DB-29 | T es además el único coordinador de PA: `PROPONER` sobre EA → `RCN_013` (mensaje de usuario con «solicite su asignación al decano»), `estadoResultado = 0`, estado y historial sin cambios, sin `ESCALAR` ni auditoría de escalamiento; la función no devuelve decanos ni `esEscalamiento = 1`. |
| C-DB-33 | El decano lista **todas** las revisiones de su facultad (EA, EB y E0), con `esResolutorActual = 0` y sin acciones; filtros `soloPendientes`, `estado` y `programa`; `@idPrograma` de otra facultad → `COO_003`; si intenta resolver una propuesta recibe `RCN_016` sin cambios de estado ni auditoría `/decano/`. |
| C-DB-34 | El job, al desactivar al coordinador, deja la propuesta sin resolutor (`revisionesEscaladas = 0`, `revisionesSinResolutor ≥ 1`, perfil `NULL`, nunca `ESCALAR`/`DECANO`); sin cambios de huella no genera novedades; al volver el coordinador `REASIGNAR` a `COORDINADOR`. |
| C-DB-35 (nuevo) | SP del docente: mismas columnas que el del coordinador; el titular ve todas las revisiones de su grupo con `totalRegistros`; `soloPendientes` deja solo `PENDIENTE_DOCENTE`; filtro de estado; paginación; un docente sin grupos no ve revisiones ajenas; `@idGrupo` ajeno → `SEC_002`. |
| MRC_MIG | Migración 31 up → down → up componible y `MRC_SEG_01` (permiso del SP del docente). |
