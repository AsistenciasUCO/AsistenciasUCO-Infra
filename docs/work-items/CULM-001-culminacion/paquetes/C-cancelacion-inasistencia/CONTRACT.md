# CULM-001 · Paquete C — CONTRACT (cancelación por inasistencia HU026C y apertura del SSE por ámbito)

> **Estado:** v1 para la revisión independiente de la sección 9.2 del prompt. Nada se congela ni se firma (`.sha256`) antes de "sin objeciones".
> **Fecha:** 2026-11-07. **Fase SDD:** 02 CONTRACT. El RED empieza solo después de la revisión y con B.2 y B2 mezclados en `integracion/CULM-001` ([SUPUESTO-C-02]).
> **Fuentes:** `PROMPT_FABLE_CULMINACION.md` §3.5, §3.8, §3.9, §3.10; `DECISIONES.md` DEC-011/012/013/024 (horas), DEC-020/021/031 (ámbito por `EstudiantePrograma`), DEC-022 §1 (SSE), DEC-028 (numeración), DEC-032 (versiones del golden path), DEC-037/038 (PDP), **DEC-039 (diseño cerrado de C)**; `RESEARCH-MODELO-ACTUAL.md` §0, §1.5, §2.1, §2.2, §4.3, §5.3; contratos congelados `paquetes/B-tomas-qr-sesiones/CONTRACT.md` (§2.5, §2.6, §2.9, §3.8) y `paquetes/B2-asignaturas-nm/CONTRACT.md` (§2.5, §2.6); `FINDINGS.md` (filas `paquete-C`); `AGENTS.md` §3.3.
> **Base de código leída:** `integracion/CULM-001` (A y B.1 mezclados) y la BD de B.2 en `C:\Proyectos\GestionAsistencia-CULM001-B\GestioAsistenciaDB` (`feature/CULM-001-B2-tomas-qr`, `uv_resumen_asistencia_estudiante_grupo`, `uv_asistencia_sesion_horas`, `usp_consultar_resumen_asistencia_grupo_docente_paginado`, `usp_ejecutar_cierre_masivo_periodo`).
> **Convenciones de ruta:** `DB:` = `GestioAsistenciaDB/`, `BE:` = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, `BE-T:` = `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`, `FE:` = `GestioAsistenciaFrontend/src/app/`, `INFRA:` = `AsistenciasUCO-Infra/`. Todos bajo `C:\Proyectos\GestionAsistencia-CULM001\`.

---

## 0. Supuestos aplicados y precisiones de diseño

DEC-039 se aplica tal cual. Lo siguiente son detalles que DEC-039 no fija o que hubo que precisar al leer el código; cada uno es la opción más conservadora y queda marcado para el revisor. Los marcados con **(confirmar)** se apartan de la letra de una decisión y el orquestador debe aceptarlos o rechazarlos antes de congelar.

| ID | Supuesto / precisión | Motivo |
| :--- | :--- | :--- |
| [SUPUESTO-C-01] | **Numeración (DEC-028):** migración `19_culm001_c_cancelacion_inasistencia_up|down.sql`; semillas `40_culm001_c_catalogos.sql`, `40_culm001_c_parametros.sql`, `40_culm001_c_mensajes.sql`, `41_culm001_c_plantillas_notificacion.sql`; permisos `rol_asistencias_runtime_culm001_c.sql`; pruebas y fixtures `test_culm001_c_*`. Mensajes con prefijos nuevos `ALR_` y `RCN_`; el rango `SES_030`+ queda **reservado sin uso** (C no crea mensajes de sesión). Golden path **1.5.0** (§3.8). | DEC-028, DEC-031, DEC-032 |
| [SUPUESTO-C-02] | **Dependencias duras.** C se construye sobre B.2 (horas: `uv_resumen_asistencia_estudiante_grupo` con `porcentajeInasistencia` por horas, `uv_asistencia_sesion_horas`, `TomaAsistencia`, `uv_faltantes_toma`, `usp_consultar_resumen_asistencia_grupo_docente_paginado`, casos de uso de tomas) y sobre B2 (versión de `uv_resumen_*` **sin** `idPrograma`, `ufn_programas_grupo`, `ufn_programas_coordinador`, `ufn_estudiantes_grupo_visibles`, fixture de grupo mixto `_ambito_grupo_mixto.sql`). Ningún objeto de C lee `uv_resumen_*.idPrograma` ni `uv_grupo_programa` con `TOP 1`. El RED de BD de C empieza cuando B.2 y B2 estén en `integracion/CULM-001`. | PLAN del work item: "C depende de B, B2"; B2 §1.1 entrega `ufn_programas_grupo` y R6 "que C usa" |
| [SUPUESTO-C-03] | **El cruce también ocurre por el paso del tiempo.** `uv_resumen_*` solo cuenta sesiones **vencidas** (`fechaHoraFin <= SYSUTCDATETIME()`); una falta registrada durante la clase sube el porcentaje cuando la sesión vence, no cuando se escribe. Por eso, además de la invocación tras cada escritura (DEC-039 §1), un job del backend (`EvaluacionAlertasInasistenciaScheduler`) evalúa los grupos con sesiones vencidas después de su última evaluación (marca de agua en `EvaluacionAlertaGrupo`), solo de periodos no terminados. | Sin el job, un cruce producido al vencer la sesión no se detectaría nunca |
| [SUPUESTO-C-04] | **Cuándo se invoca el motor tras una escritura:** lote legado (`POST /asistencias/lote`), lote por toma, cierre de toma (manual y job de B.2) y resolución **aprobada** de un reclamo (SJC→EX). **No** tras el registro por token/PIN: escribir `AN` nunca sube `porcentajeInasistencia = horasFalta / horasDictadas` y evitarlo quita contención en la prueba 5 × 40 de B.2. Se aparta de la lista literal de DEC-039 §1 ("token") **(confirmar)**. | Un registro `AN` no puede producir un cruce |
| [SUPUESTO-C-05] | **Estados de la alerta:** `VIGENTE` / `SUPERADA` (catálogo `EstadoAlertaInasistencia`). Una sola fila y una sola notificación por `(matrícula, tipo)`: si el porcentaje baja del umbral pasa a `SUPERADA`; si vuelve a cruzar pasa a `VIGENTE` **sin** nueva fila, notificación ni evento. Un salto directo (p. ej. de 10 % a 25 %) crea las dos alertas, pero el estudiante recibe **una** notificación (la de mayor `nivel`); las dos quedan en su lista. | "una sola vez por tipo y matrícula" (DEC-039 §1) |
| [SUPUESTO-C-06] | **Pérdida: también se avisa al estudiante.** HU026C es "notificaciones proactivas de ausentismo (15 % y 20 %)" y la plantilla existente `ALERTA_PERDIDA_INASISTENCIA` está redactada para el estudiante ("Estimado(a) {estudiante}…"). Por eso, al cruzar la pérdida: `ALERTA_PERDIDA_INASISTENCIA` + SSE al **estudiante**, y al **docente titular** una plantilla nueva `REVISION_CANCELACION_PENDIENTE` (redactada para el docente). DEC-039 §3 dice "notificación `ALERTA_PERDIDA_INASISTENCIA` al docente titular" **(confirmar)**. | La plantilla existente no sirve para el docente sin reescribirla; HU026C pide el aviso del 20 % al estudiante |
| [SUPUESTO-C-07] | **Transiciones como datos.** Las decisiones válidas por estado y rol viven en `TransicionRevisionCancelacion` (origen, decisión, perfil, destino, si exige umbral, mensaje de éxito, plantilla). Además de lo que fija DEC-039, desde `RECHAZADA` el docente puede volver a `PROPONER` (con motivo nuevo) **(confirmar)**: el estudiante "sigue activo" y puede seguir faltando; mismo criterio que "si mantiene, puede proponer después". | Cero datos quemados; mismo trato a MANTENIDA y RECHAZADA |
| [SUPUESTO-C-08] | `PROPONER` y `APROBAR` exigen que el porcentaje **actual** (recalculado bajo bloqueo) siga `>=` umbral de pérdida (`RCN_006`). Si una excusa aprobada después bajó el porcentaje, no se cancela a un estudiante que ya no está en pérdida; `MANTENER` y `RECHAZAR` no lo exigen. | Protege al estudiante ante datos que cambiaron |
| [SUPUESTO-C-09] | **Coordinador competente** = coordinador activo de un programa que está a la vez en `EstudiantePrograma` del estudiante y en `ufn_programas_grupo(grupo)` (DEC-020; nueva `ufn_coordinadores_revision_cancelacion`). Si no hay ninguno, `PROPONER` se rechaza con `RCN_013` (nadie podría resolverla). Si un estudiante pertenece a dos programas del grupo, cualquiera de sus coordinadores resuelve; gana el primero (bloqueo). Un coordinador que además es el docente titular **no** puede resolver una propuesta que él mismo hizo (`RCN_014`, segregación de funciones). | Regla 3.9: "la revisión la resuelve el coordinador del programa del estudiante" |
| [SUPUESTO-C-10] | **Cierre masivo (DEC-039 §7).** Deja la regla quemada `COUNT(DISTINCT a.sesion) >= 3` y usa el umbral por horas así: (1) el caso de uso del backend ejecuta el motor en todos los grupos del periodo; (2) el SP **bloquea** el cierre (`RCN_012`, sin escrituras) si queda alguna matrícula `A` del periodo con revisión que requiere acción (docente o coordinador) o con `codigoPermanencia = PERDIDA` por horas y sin revisión; (3) si no, todas las matrículas `A` pasan a `F` (incluidas `MANTENIDA` y `RECHAZADA`, que son decisiones humanas de conservar). El cierre **ya no escribe `CI`**: `CI` solo nace de una revisión aprobada. **(confirmar)**: la lectura literal "CI por umbral en el cierre" saltaría la decisión del docente y del coordinador que exige 3.5. | 3.5 exige decisión humana para cancelar |
| [SUPUESTO-C-11] | **SSE en dos canales.** (a) El canal existente `GET /api/v1/realtime/stream?grupoId=` se abre a todos los roles con ámbito resuelto **una vez** por SP al suscribirse (DEC-022 §1, DEC-039 §5) y entrega por tipo según la política de audiencia de B.1 ampliada. (b) Canal **personal** nuevo `GET /api/v1/realtime/stream/personal` (sin `grupoId`): solo eventos cuyo destinatario explícito es el usuario autenticado. Sin (b), la campana del estudiante y las bandejas del docente y el coordinador exigirían una conexión por grupo (límite de 6 conexiones HTTP/1.1 por origen). Los destinatarios viajan como **metadato de enrutamiento no serializado** de `RealtimeEvent` (nunca en el `payload`). | Ruta nueva → PDP (B-01) y cambio del invariante "`grupoId` obligatorio" del contrato de eventos (§3.8) |
| [SUPUESTO-C-12] | Ámbito por **id de revisión o alerta** ajena → `404` indistinguible de inexistente (`RCN_001`, patrón `RET_001`/`REV_006`); **filtro** de grupo o programa fuera de ámbito en un listado → `403` (`SEC_002` / `COO_003`, B2). | Coherente con A y B2 |
| [SUPUESTO-C-13] | La lectura de alertas se marca con una lista de ids (`PATCH /estudiante/alertas/lectura`), idempotente; los ids ajenos se ignoran sin error. El contador de la campana es `totalElementos` de `GET /estudiante/alertas?soloNoLeidas=true&tamano=1` (sin ruta extra). | Menos rutas nuevas bloqueadas por el PDP |
| [SUPUESTO-C-14] | El coordinador ve en su bandeja las revisiones de **sus** estudiantes en todos los estados (solo lectura salvo `PROPUESTA`); el decano no tiene bandeja en C (diferido, §6.3). El estudiante **no** ve el estado de la revisión: ve sus alertas y, si se aprueba, la notificación y el estado `CI` de la matrícula. | Mínimo privilegio; el docente decide en privado |
| [SUPUESTO-C-15] | La migración 19 **no** evalúa alertas (no puede notificar). El primer pase del job tras el despliegue evalúa todos los grupos de periodos vigentes (marca de agua `NULL`) y notifica: es el "backfill" controlado, que se puede posponer con `ALERTA_INASISTENCIA/HABILITADA = false`. | Una alerta sin aviso no se volvería a avisar nunca ([SUPUESTO-C-05]) |
| [SUPUESTO-C-16] | Las plantillas existentes `ALERTA_RIESGO_INASISTENCIA` y `ALERTA_PERDIDA_INASISTENCIA` tienen el "20 %" escrito en el cuerpo. La semilla 41 cambia el cuerpo para usar `{umbral}`/`{limite}` **solo si** coincide con el texto por defecto anterior (no pisa una plantilla administrada). | Cero datos quemados en textos |
| [SUPUESTO-C-17] | El `down` de la migración 19 **no** reactiva matrículas `CI` creadas por revisiones aprobadas (fueron decisiones humanas): archiva alertas, revisiones e historial en tablas `zz_archivo_*_culm001_c` (patrón DEC-010) y lo reporta. | Sin pérdida ni reversión silenciosa de decisiones |
| [SUPUESTO-C-18] | En el frontend, el canal personal se abre para los 5 roles tras el login (lo usan estudiante, docente y coordinador; decano y administrador no reciben eventos personales en C pero el canal no les cuesta nada y queda listo para D). Los eventos se deduplican por `eventId` (un mismo evento puede llegar por el canal personal y por el de grupo). | Una sola conexión permanente por pestaña |
| [SUPUESTO-C-19] | La longitud del motivo (10–500) solo la valida el backend/BD (`REVISION_CANCELACION/MOTIVO_LONGITUD_*`); el cliente exige "no vacío" y muestra el mensaje del backend (`RCN_003`). Sin números quemados en el cliente. | AGENTS.md: mensajes y reglas desde el backend |

---

## 1. Alcance, decisiones aplicadas, HUs y hallazgos

### 1.1 Alcance

| Incluido | Excluido (va a otro paquete o se difiere) |
| :--- | :--- |
| Motor de alertas en BD (`usp_evaluar_alertas_inasistencia_grupo`) sobre el porcentaje por horas de B.2; tablas `AlertaInasistencia`, `RevisionCancelacion`, `RevisionCancelacionHistorial`, `EvaluacionAlertaGrupo`; catálogos `TipoAlertaInasistencia`, `EstadoAlertaInasistencia`, `EstadoRevisionCancelacion`, `TransicionRevisionCancelacion` | Comparativas, tendencia y consolidado por horas (D, [SUPUESTO-B-23]) |
| Decisión del docente (`MANTENER`/`PROPONER` con motivo) y resolución del coordinador del programa del estudiante (`APROBAR` ⇒ `CI` / `RECHAZAR`), auditadas | Bandeja del decano y vista de revisiones del administrador (diferido, §6.3) |
| Notificaciones (plantillas existentes `ALERTA_*` + nuevas `REVISION_CANCELACION_PENDIENTE`, `PROPUESTA_CANCELACION`, `CANCELACION_APROBADA`, `CANCELACION_RECHAZADA`) | Reintento de notificaciones fallidas antes del outbox (deuda, §5.1) |
| Job de evaluación por tiempo ([SUPUESTO-C-03]) e invocación tras las escrituras ([SUPUESTO-C-04]) | Edición de asistencias por el coordinador (prohibida por 3.5; sigue de solo lectura) |
| Apertura del SSE por grupo a todos los roles con ámbito en SP; canal personal; política de audiencia ampliada; SSE de resolución de reclamo (HU042, F-TRX-005) y de sesión cancelada al estudiante (HU047) | WebSocket, réplica multi-instancia o replay del SSE |
| Cierre masivo por horas sin la regla `>= 3` ([SUPUESTO-C-10]) | — |
| Pantallas: marcas en la planilla del docente, bandeja de revisiones del docente, bandeja del coordinador, alertas del estudiante (móvil primero) y campana; suscripción SSE del estudiante, del coordinador y del decano en sus vistas de grupo | Pulido visual general (E) |

### 1.2 Decisiones aplicadas

| Decisión | Cómo se aplica en C |
| :--- | :--- |
| DEC-039 | Diseño completo (§2–§4). Precisiones en [SUPUESTO-C-03..C-10] |
| DEC-012 / DEC-024 | El motor usa `porcentajeInasistencia` de `uv_resumen_asistencia_estudiante_grupo` (horas, `horasFalta / horasDictadas`; EX no cuenta como falta; sesiones canceladas excluidas); C no recalcula horas |
| DEC-011 / DEC-013 | Las faltas nacen en `DetalleAsistencia` por toma (lote legado → toma vigente; cierre de toma QR → SJC); C solo lee |
| DEC-020 / DEC-021 / DEC-031 | Coordinador competente por `EstudiantePrograma` ∩ programas del grupo; coordinador multi-programa: listado = unión, `programaId` opcional (`COO_003` si es ajeno) |
| DEC-022 §1 | SSE abierto a todos los roles con ámbito en el gateway (§3.6) |
| DEC-028 / DEC-031 | Migración 19, semillas 40/41, prefijo `culm001_c`, `ALR_`/`RCN_`, `SES_030`+ reservado |
| DEC-032 | Golden path 1.5.0 después de la 1.4.0 de B2 (§3.8) |
| DEC-037 / DEC-038 | Rutas nuevas listadas en §3.7.2 ("Catálogo de accesos"); quedan en 403 `NO_APPLICABLE_POLICY` hasta que el responsable ejecute `provision_asistencias.py pdp` (bloqueo B-01) |
| DEC-018 | Parámetros nuevos sembrados en BD con valor por defecto igual en código; proveedor `sqlserver` en local |

### 1.3 HUs

| HU | Efecto en C |
| :--- | :--- |
| **HU026C** Notificaciones proactivas de ausentismo (15 % y 20 %) | Implementada: motor, alertas, notificación, SSE, campana y panel del estudiante. La fila del catálogo deja de nombrar el SP inexistente `usp_consultar_estudiantes_en_riesgo` |
| HU041 Resaltado de alumnos en riesgo (planilla) | La planilla muestra además la marca de alerta y el estado de la revisión (riesgo, pérdida pendiente, mantenido, propuesto, rechazado, cancelado) |
| HU042 Notificación de resolución de reclamo | Se agrega el evento SSE `SOLICITUD_REVISION_RESUELTA` al estudiante (hoy solo correo; F-TRX-005) |
| HU047 Cancelar sesión | El estudiante y el ámbito de lectura reciben `SESION_CANCELADA` (B.1 lo dejó solo para el titular) |
| HU059 Estados de grupo/sesión/matrícula | La matrícula `CI` se muestra como "Cancelado por inasistencia" en las listas del docente, del coordinador y del estudiante |
| HU066 / HU070 Alerta temprana y permanencia | Sin cambio de fórmula (ya por horas en B.2); la revisión se apoya en la misma clasificación |
| HU174 Cierre masivo | Regla por horas y bloqueo por casos sin resolver ([SUPUESTO-C-10]) |
| HU013 Alerta visual del estudiante | Se complementa con la campana y el panel de alertas |

### 1.4 Hallazgos de la Fase 1 que cierra C

| Hallazgo | Resolución |
| :--- | :--- |
| **F-EST-S05** (alta) sin conexión SSE en las vistas del estudiante | Canal personal tras el login + canal de grupo en el detalle de la materia (§4.3) |
| **F-TRX-005** (alta) HU042 sin evento SSE de resolución | `SOLICITUD_REVISION_RESUELTA` publicado tras el éxito, destinatario el estudiante (§3.6.4) |
| **F-TRX-006** (media; dup F-DEC-012) 403 del stream para estudiante, coordinador, decano y administrador | Gateway por ámbito (§3.6.1) y suscripción en las vistas de grupo del coordinador y del decano (§4.6) |
| **F-EST-007** (media; dup F-EST-S08, F-TRX-007) sin campana, sin alertas 15/20 %, sin aviso de sesión cancelada | Motor + campana + panel + `SESION_CANCELADA` al estudiante |

### 1.5 Fuera de alcance

Comparativas/tendencia/consolidado por horas (D); bandeja del decano; edición de la regla institucional del 20 % (es un parámetro existente); reactivar una matrícula `CI` (no hay "des-cancelar": la corrección es por el conducto regular externo, igual que la resolución definitiva de excusas en AGENTS.md §3.3-2).

---

## 2. Base de datos (`GestioAsistenciaDB`)

### 2.0 Reglas comunes

Las de B §2.0 sin cambio: `SET NOCOUNT ON; SET XACT_ABORT ON;`; ownership transaccional (`@@TRANCOUNT = 0` → transacción propia; si no, `SAVE TRANSACTION <nombre>`); `CATCH` que revierte lo propio, propaga `XACT_STATE() = -1` con `THROW` y si no responde `SYS_001` + `ufn_obtener_detalle_error`; `@parametro IS NULL` explícito; paso 1 `usp_validar_id_correlacion_esta_presente_interno`; RBAC `usp_validar_permiso_rbac_usuario_interno`; titularidad `usp_validar_titularidad_jerarquica_interno`; mensajes por `usp_obtener_mensaje_catalogo`; tupla canónica `idCorrelacion, mensajeUsuarioResultado, mensajeTecnicoResultado, estadoResultado`.

- **Consultas** (`usp_consultar_*`, `READ_QUERY_RESULTSET`): validación → `THROW 51000` con el mensaje técnico si falla; `SELECT … FROM uv_* … ORDER BY … OFFSET … FETCH NEXT …` con `COUNT(1) OVER() AS totalRegistros`; `@numeroPagina >= 1`, `1 <= @tamanoPagina <= PAGINACION/TAMANO_MAXIMO` (`PAG_001`), igual que `usp_consultar_resumen_asistencia_grupo_docente_paginado`.
- **Cero datos quemados:** estados, tipos y decisiones por columnas bandera o por la tabla de transiciones; códigos de estado de matrícula por parámetro (`MATRICULA/ESTADO_INSCRITA` = `A`, existente de A; `MATRICULA/ESTADO_CANCELADA_INASISTENCIA` = `CI`, nuevo); umbrales por la clave de parámetro que guarda cada tipo de alerta. Los únicos literales son los códigos de perfil del RBAC (`'DOCENTE'`, `'COORDINADOR'`, `'ESTUDIANTE'`), como en todos los SP actuales.
- **Ámbito dentro del SP:** estudiante → sus matrículas; docente → grupos donde es titular; coordinador → `ufn_coordinadores_revision_cancelacion` / `ufn_programas_coordinador` (B2); administrador → institución del grupo.
- **Orden de bloqueos** (sin ciclos con B y A): motor `EvaluacionAlertaGrupo → AlertaInasistencia → RevisionCancelacion`; decisión del docente `RevisionCancelacion`; resolución `RevisionCancelacion → EstudianteGrupo`. Ninguno toma `Grupo`, `Sesion` ni `TomaAsistencia` con bloqueo de actualización (el retiro HU051 toma `Grupo → EstudianteGrupo`; el registro de B toma `Sesion → … → EstudianteGrupo → Asistencia`): no hay espera circular posible.
- **Auditoría:** cada mutación inserta en `dbo.AuditoriaEvento` (patrón `usp_retirar_estudiante_grupo`): `actorType = USER` con el usuario o `SYSTEM` para el motor, `action`, `resourceType`, `resourceId`, `result = SUCCESS`, `correlationId`, `httpMethod`/`path` del endpoint (o `JOB`/`/jobs/alertas-inasistencia` para el motor), `httpStatus`, `metadata` JSON con estado anterior/nuevo, decisión, motivo y porcentaje. Además, `RevisionCancelacionHistorial` guarda cada transición para la interfaz.

### 2.1 Catálogos (tablas + semilla `40_culm001_c_catalogos.sql`, MERGE por id)

```sql
-- DB:schema/tables/TipoAlertaInasistencia.sql
CREATE TABLE dbo.TipoAlertaInasistencia (
    id                       UNIQUEIDENTIFIER NOT NULL,
    codigo                   NVARCHAR(20)     NOT NULL,   -- ADVERTENCIA | PERDIDA (valor que entrega la API)
    nombre                   NVARCHAR(50)     NOT NULL,
    nivel                    TINYINT          NOT NULL,   -- 1, 2: en un salto se notifica el de mayor nivel ([SUPUESTO-C-05])
    grupoParametroUmbral     VARCHAR(100)     NOT NULL,   -- ASISTENCIA
    claveParametroUmbral     VARCHAR(100)     NOT NULL,   -- UMBRAL_ALERTA_ADVERTENCIA | UMBRAL_ALERTA_PERDIDA
    tipoPlantillaEstudiante  VARCHAR(60)      NOT NULL,   -- ALERTA_RIESGO_INASISTENCIA | ALERTA_PERDIDA_INASISTENCIA
    codigoMensajeUsuario     VARCHAR(100)     NOT NULL,   -- ALR_010 | ALR_011 (texto de la tarjeta del estudiante)
    creaRevisionCancelacion  BIT              NOT NULL,
    CONSTRAINT PK_TipoAlertaInasistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_TipoAlertaInasistencia_codigo UNIQUE (codigo),
    CONSTRAINT UQ_TipoAlertaInasistencia_nivel UNIQUE (nivel)
);
CREATE UNIQUE INDEX UX_TipoAlertaInasistencia_creaRevision ON dbo.TipoAlertaInasistencia (creaRevisionCancelacion)
    WHERE creaRevisionCancelacion = 1;                    -- exactamente un tipo crea revisión
--   ('7C1E0C10-5E51-4C0A-9A01-000000000001', N'ADVERTENCIA', N'Riesgo de pérdida por inasistencia', 1, 'ASISTENCIA', 'UMBRAL_ALERTA_ADVERTENCIA', 'ALERTA_RIESGO_INASISTENCIA',  'ALR_010', 0)
--   ('7C1E0C10-5E51-4C0A-9A01-000000000002', N'PERDIDA',     N'Pérdida por inasistencia',           2, 'ASISTENCIA', 'UMBRAL_ALERTA_PERDIDA',     'ALERTA_PERDIDA_INASISTENCIA', 'ALR_011', 1)

-- DB:schema/tables/EstadoAlertaInasistencia.sql
CREATE TABLE dbo.EstadoAlertaInasistencia (
    id           UNIQUEIDENTIFIER NOT NULL,
    codigo       NVARCHAR(20)     NOT NULL,   -- VIGENTE | SUPERADA
    nombre       NVARCHAR(50)     NOT NULL,
    estaVigente  BIT              NOT NULL,
    CONSTRAINT PK_EstadoAlertaInasistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_EstadoAlertaInasistencia_codigo UNIQUE (codigo),
    CONSTRAINT UQ_EstadoAlertaInasistencia_estaVigente UNIQUE (estaVigente)
);
--   ('7C1E0C20-5E51-4C0A-9A01-000000000001', N'VIGENTE',  N'Vigente',  1)
--   ('7C1E0C20-5E51-4C0A-9A01-000000000002', N'SUPERADA', N'Superada', 0)

-- DB:schema/tables/EstadoRevisionCancelacion.sql
CREATE TABLE dbo.EstadoRevisionCancelacion (
    id                         UNIQUEIDENTIFIER NOT NULL,
    codigo                     NVARCHAR(20)     NOT NULL,
    nombre                     NVARCHAR(60)     NOT NULL,
    orden                      TINYINT          NOT NULL,
    esInicial                  BIT              NOT NULL,
    requiereAccionDocente      BIT              NOT NULL,
    requiereAccionCoordinador  BIT              NOT NULL,
    conservaMatricula          BIT              NOT NULL,   -- decisión humana de mantener al estudiante (cierre masivo → F)
    cancelaMatricula           BIT              NOT NULL,   -- la matrícula pasa a MATRICULA/ESTADO_CANCELADA_INASISTENCIA
    esFinal                    BIT              NOT NULL,
    CONSTRAINT PK_EstadoRevisionCancelacion PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_EstadoRevisionCancelacion_codigo UNIQUE (codigo),
    CONSTRAINT CK_EstadoRevisionCancelacion_accion CHECK (NOT (requiereAccionDocente = 1 AND requiereAccionCoordinador = 1))
);
CREATE UNIQUE INDEX UX_EstadoRevisionCancelacion_esInicial ON dbo.EstadoRevisionCancelacion (esInicial) WHERE esInicial = 1;
CREATE UNIQUE INDEX UX_EstadoRevisionCancelacion_cancela   ON dbo.EstadoRevisionCancelacion (cancelaMatricula) WHERE cancelaMatricula = 1;
--   id                                       codigo               nombre                                    orden ini doc coo cons canc fin
--   ('7C1E0C30-5E51-4C0A-9A01-000000000001', N'PENDIENTE_DOCENTE', N'Pendiente de decisión del docente',     1,   1,  1,  0,  0,   0,   0)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000002', N'MANTENIDA',         N'Estudiante mantenido por el docente',   2,   0,  0,  0,  1,   0,   0)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000003', N'PROPUESTA',         N'Cancelación propuesta a coordinación',  3,   0,  0,  1,  0,   0,   0)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000004', N'APROBADA',          N'Cancelación aprobada',                  4,   0,  0,  0,  0,   1,   1)
--   ('7C1E0C30-5E51-4C0A-9A01-000000000005', N'RECHAZADA',         N'Cancelación rechazada por coordinación',5,   0,  0,  0,  1,   0,   0)

-- DB:schema/tables/TransicionRevisionCancelacion.sql  ([SUPUESTO-C-07])
CREATE TABLE dbo.TransicionRevisionCancelacion (
    id                          UNIQUEIDENTIFIER NOT NULL,
    estadoOrigen                UNIQUEIDENTIFIER NOT NULL,   -- FK EstadoRevisionCancelacion
    codigoDecision              NVARCHAR(20)     NOT NULL,   -- MANTENER | PROPONER | APROBAR | RECHAZAR (valor de la API)
    codigoPerfilActor           NVARCHAR(20)     NOT NULL,   -- DOCENTE | COORDINADOR (mismo código que el RBAC)
    estadoDestino               UNIQUEIDENTIFIER NOT NULL,   -- FK EstadoRevisionCancelacion
    exigeUmbralPerdida          BIT              NOT NULL,   -- [SUPUESTO-C-08]
    exigeCoordinadorDisponible  BIT              NOT NULL,   -- RCN_013
    codigoMensajeExito          VARCHAR(100)     NOT NULL,
    tipoPlantillaNotificacion   VARCHAR(60)      NULL,       -- NULL = sin notificación (MANTENER)
    CONSTRAINT PK_TransicionRevisionCancelacion PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_TransicionRevisionCancelacion_origen_decision UNIQUE (estadoOrigen, codigoDecision)
);
--   ('7C1E0C40-…-000000000001', PENDIENTE_DOCENTE, N'MANTENER', N'DOCENTE',     MANTENIDA, 0, 0, 'RCN_007', NULL)
--   ('7C1E0C40-…-000000000002', PENDIENTE_DOCENTE, N'PROPONER', N'DOCENTE',     PROPUESTA, 1, 1, 'RCN_008', 'PROPUESTA_CANCELACION')
--   ('7C1E0C40-…-000000000003', MANTENIDA,         N'PROPONER', N'DOCENTE',     PROPUESTA, 1, 1, 'RCN_008', 'PROPUESTA_CANCELACION')
--   ('7C1E0C40-…-000000000004', RECHAZADA,         N'PROPONER', N'DOCENTE',     PROPUESTA, 1, 1, 'RCN_008', 'PROPUESTA_CANCELACION')
--   ('7C1E0C40-…-000000000005', PROPUESTA,         N'APROBAR',  N'COORDINADOR', APROBADA,  1, 0, 'RCN_009', 'CANCELACION_APROBADA')
--   ('7C1E0C40-…-000000000006', PROPUESTA,         N'RECHAZAR', N'COORDINADOR', RECHAZADA, 0, 0, 'RCN_010', 'CANCELACION_RECHAZADA')
```

Vistas de catálogo (solo consulta, patrón CAT-01): `uv_tipo_alerta_inasistencia`, `uv_estado_alerta_inasistencia`, `uv_estado_revision_cancelacion`, `uv_transicion_revision_cancelacion` (con `codigoEstadoOrigen` y `codigoEstadoDestino`). FKs en `DB:schema/tables/zz_foreign_keys.sql`.

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
    fechaCruceUtc               DATETIME2(0)     NOT NULL,
    idCorrelacionCruce          UNIQUEIDENTIFIER NOT NULL,
    porcentajeUltimaEvaluacion  DECIMAL(5,2)     NOT NULL,
    fechaUltimaEvaluacionUtc    DATETIME2(0)     NOT NULL,
    fechaLecturaUtc             DATETIME2(0)     NULL,       -- lectura del estudiante (campana)
    CONSTRAINT PK_AlertaInasistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT CK_AlertaInasistencia_porcentajes CHECK (porcentajeCruce BETWEEN 0 AND 100 AND porcentajeUltimaEvaluacion BETWEEN 0 AND 100)
);
CREATE UNIQUE INDEX UX_AlertaInasistencia_EstudianteGrupo_Tipo ON dbo.AlertaInasistencia (estudianteGrupo, tipo);  -- una vez por tipo y matrícula
CREATE INDEX IX_AlertaInasistencia_noLeidas ON dbo.AlertaInasistencia (estudianteGrupo) INCLUDE (fechaLecturaUtc, fechaCruceUtc);

-- DB:schema/tables/RevisionCancelacion.sql
CREATE TABLE dbo.RevisionCancelacion (
    id                             UNIQUEIDENTIFIER NOT NULL,
    estudianteGrupo                UNIQUEIDENTIFIER NOT NULL,   -- FK EstudianteGrupo
    estado                         UNIQUEIDENTIFIER NOT NULL,   -- FK EstadoRevisionCancelacion
    alertaOrigen                   UNIQUEIDENTIFIER NOT NULL,   -- FK AlertaInasistencia (tipo con creaRevisionCancelacion = 1)
    porcentajeCreacion             DECIMAL(5,2)     NOT NULL,
    horasFaltaCreacion             DECIMAL(12,6)    NOT NULL,
    horasDictadasCreacion          DECIMAL(12,6)    NOT NULL,
    fechaCreacionUtc               DATETIME2(0)     NOT NULL,
    idCorrelacionCreacion          UNIQUEIDENTIFIER NOT NULL,
    codigoDecisionDocente          NVARCHAR(20)     NULL,
    motivoDocente                  NVARCHAR(1000)   NULL,
    usuarioDecisionDocente         UNIQUEIDENTIFIER NULL,       -- FK Usuario
    porcentajeDecisionDocente      DECIMAL(5,2)     NULL,
    fechaDecisionDocenteUtc        DATETIME2(0)     NULL,
    codigoDecisionCoordinador      NVARCHAR(20)     NULL,
    motivoCoordinador              NVARCHAR(1000)   NULL,
    usuarioResolucionCoordinador   UNIQUEIDENTIFIER NULL,       -- FK Usuario
    programaResolucion             UNIQUEIDENTIFIER NULL,       -- FK Programa (programa por el que resolvió)
    porcentajeResolucion           DECIMAL(5,2)     NULL,
    fechaResolucionUtc             DATETIME2(0)     NULL,
    estadoMatriculaAnterior        UNIQUEIDENTIFIER NULL,       -- FK EstadoEstudianteGrupo (para auditoría y archivo)
    fechaActualizacionUtc          DATETIME2(0)     NOT NULL,
    CONSTRAINT PK_RevisionCancelacion PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_RevisionCancelacion_EstudianteGrupo UNIQUE (estudianteGrupo)                 -- idempotente: una por matrícula
);
CREATE INDEX IX_RevisionCancelacion_estado ON dbo.RevisionCancelacion (estado) INCLUDE (estudianteGrupo, fechaCreacionUtc);

-- DB:schema/tables/RevisionCancelacionHistorial.sql
CREATE TABLE dbo.RevisionCancelacionHistorial (
    id                      UNIQUEIDENTIFIER NOT NULL,
    revision                UNIQUEIDENTIFIER NOT NULL,   -- FK RevisionCancelacion
    estadoAnterior          UNIQUEIDENTIFIER NULL,       -- NULL en la creación
    estadoNuevo             UNIQUEIDENTIFIER NOT NULL,
    codigoDecision          NVARCHAR(20)     NULL,       -- NULL en la creación por el sistema
    motivo                  NVARCHAR(1000)   NULL,
    usuarioActor            UNIQUEIDENTIFIER NULL,       -- NULL = sistema (motor)
    codigoPerfilActor       NVARCHAR(20)     NULL,
    porcentajeInasistencia  DECIMAL(5,2)     NOT NULL,
    fechaUtc                DATETIME2(0)     NOT NULL,
    idCorrelacion           UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_RevisionCancelacionHistorial PRIMARY KEY CLUSTERED (id)
);
CREATE INDEX IX_RevisionCancelacionHistorial_revision ON dbo.RevisionCancelacionHistorial (revision, fechaUtc);

-- DB:schema/tables/EvaluacionAlertaGrupo.sql  ([SUPUESTO-C-03]: marca de agua y cerrojo por grupo)
CREATE TABLE dbo.EvaluacionAlertaGrupo (
    grupo                     UNIQUEIDENTIFIER NOT NULL,   -- PK y FK Grupo
    fechaUltimaEvaluacionUtc  DATETIME2(0)     NOT NULL,
    idCorrelacionUltima       UNIQUEIDENTIFIER NOT NULL,
    totalEvaluaciones         INT              NOT NULL CONSTRAINT DF_EvaluacionAlertaGrupo_total DEFAULT (0),
    CONSTRAINT PK_EvaluacionAlertaGrupo PRIMARY KEY CLUSTERED (grupo)
);
```

Cada archivo de tabla sigue el patrón idempotente del repo (`IF OBJECT_ID(...) IS NULL CREATE`, guard de columnas esperadas como `AuditoriaEvento.sql`). La longitud de los motivos la acota el parámetro `REVISION_CANCELACION/MOTIVO_LONGITUD_MAXIMA` (500); el SP usa `MIN(parámetro, 1000)` para no exceder la columna.

### 2.3 Funciones nuevas

| Función | Firma | Regla |
| :--- | :--- | :--- |
| `ufn_umbral_alerta_inasistencia` | `(@idTipoAlerta UNIQUEIDENTIFIER) RETURNS DECIMAL(5,2)` | `TRY_CAST` del parámetro `grupoParametroUmbral/claveParametroUmbral` del tipo; `NULL` si falta o no es numérico (el llamador responde `ALR_002`). Misma lectura que `ufn_clasificar_permanencia`, así que el umbral es el mismo (`>=`; 20.00 ya es pérdida) |
| `ufn_coordinadores_revision_cancelacion` | `(@idEstudianteGrupo UNIQUEIDENTIFIER) RETURNS TABLE (idUsuario, idCoordinador, idPrograma)` (inline) | Programas = `EstudiantePrograma` del estudiante **∩** `ufn_programas_grupo(grupo)` (B2); coordinadores activos de esos programas (`uv_coordinador.estaActivoCoordinador = 1` y usuario activo). Única fuente de "coordinador del programa del estudiante" para listar, resolver, notificar y `RCN_013` ([SUPUESTO-C-09]) |

### 2.4 Vistas nuevas

| Vista | Columnas | Grano |
| :--- | :--- | :--- |
| `uv_alerta_inasistencia` | `id, idEstudianteGrupo, idEstudiante, idUsuarioEstudiante, nombreCompletoEstudiante, idGrupo, codigoGrupo, nombreGrupo, idAsignatura, nombreAsignatura, idPeriodoAcademico, idDocenteTitular, idUsuarioDocenteTitular, codigoEstadoMatricula, idTipo, codigoTipo, nombreTipo, nivel, codigoMensajeUsuario, idEstado, codigoEstado, estaVigente, porcentajeCruce, umbralCruce, horasFaltaCruce, horasDictadasCruce, fechaCruceUtc, porcentajeUltimaEvaluacion, fechaUltimaEvaluacionUtc, fechaLecturaUtc, estaLeida` | 1 por alerta |
| `uv_revision_cancelacion` | `id, idEstudianteGrupo, idEstudiante, idUsuarioEstudiante, nombreCompletoEstudiante, idGrupo, codigoGrupo, nombreGrupo, idAsignatura, nombreAsignatura, idPeriodoAcademico, idDocenteTitular, idUsuarioDocenteTitular, nombreCompletoDocente, codigoEstadoMatricula, idEstado, codigoEstado, nombreEstado, ordenEstado, requiereAccionDocente, requiereAccionCoordinador, conservaMatricula, cancelaMatricula, esFinal, porcentajeCreacion, horasFaltaCreacion, horasDictadasCreacion, fechaCreacionUtc, codigoDecisionDocente, motivoDocente, idUsuarioDecisionDocente, porcentajeDecisionDocente, fechaDecisionDocenteUtc, codigoDecisionCoordinador, motivoCoordinador, idUsuarioResolucionCoordinador, nombreCompletoCoordinadorResolucion, idProgramaResolucion, nombreProgramaResolucion, porcentajeResolucion, fechaResolucionUtc, fechaActualizacionUtc` | 1 por revisión |
| `uv_revision_cancelacion_historial` | `id, idRevision, codigoEstadoAnterior, codigoEstadoNuevo, nombreEstadoNuevo, codigoDecision, motivo, idUsuarioActor, nombreCompletoActor, codigoPerfilActor, porcentajeInasistencia, fechaUtc, idCorrelacion` | 1 por transición |
| `uv_marca_inasistencia_estudiante_grupo` | `idEstudianteGrupo, tieneAdvertenciaVigente, fechaAdvertenciaUtc, tienePerdidaVigente, fechaPerdidaUtc, idRevisionCancelacion, codigoEstadoRevision, nombreEstadoRevision, requiereAccionDocente, requiereAccionCoordinador, conservaMatricula, esFinalRevision` (agregado por matrícula sobre `AlertaInasistencia` + `RevisionCancelacion` + catálogos; sin joins a `uv_resumen_*`) | 1 por matrícula con alerta o revisión |

Las vistas nuevas no leen `uv_grupo_programa` (B2 la vuelve 1:N): la asignatura sale de `uv_grupo`, el docente de `Grupo.docente`. Prueba de cardinalidad `COUNT(*) = COUNT(DISTINCT id)` con el fixture de grupo mixto de B2 (C-DB-30).

### 2.5 Procedimientos almacenados nuevos

#### 2.5.1 `usp_evaluar_alertas_inasistencia_grupo` (motor; DEC-039 §1)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_evaluar_alertas_inasistencia_grupo
(
    @idGrupo            UNIQUEIDENTIFIER,
    @idCorrelacion      UNIQUEIDENTIFIER,
    @idEstudianteGrupo  UNIQUEIDENTIFIER = NULL   -- NULL = todas las matrículas activas del grupo
)
-- Salida (1 fila): tupla canónica + alertasCreadas INT, alertasSuperadas INT, alertasReactivadas INT,
--                  revisionesCreadas INT, novedadesJSON NVARCHAR(MAX)   (NULL si estadoResultado = 0)
```

Clasificación `NON_GOLDEN_PATH_EXTENSION`, comando de sistema **sin usuario** (patrón `usp_aplicar_festivos_automatico`): lo invocan solo el backend tras una escritura confirmada, el job y el cierre masivo. No devuelve nada al cliente HTTP.

1. Correlación; `@idGrupo IS NULL` → `GEN_002`; grupo inexistente → mensaje de `usp_validar_grupo_exista_por_id_interno`; `@idEstudianteGrupo` no nulo y de otro grupo → `ALR_006`.
2. `ALERTA_INASISTENCIA/HABILITADA <> 'true'` → `estadoResultado = 1`, `ALR_001`, contadores en 0, `novedadesJSON = '[]'`, **sin escrituras** (interruptor).
3. Umbral de cada tipo con `ufn_umbral_alerta_inasistencia`; si alguno es `NULL` → `ALR_002`, `estadoResultado = 0`, sin escrituras.
4. Transacción propia o `SAVE TRANSACTION sp_evaluar_alertas_grupo`. `MERGE dbo.EvaluacionAlertaGrupo WITH (UPDLOCK, HOLDLOCK)` sobre el grupo (crea la fila si no existe): **serializa las evaluaciones del mismo grupo** (job + escrituras concurrentes) sin bloquear otros grupos.
5. `#candidatos` = `SELECT idEstudianteGrupo, porcentajeInasistencia, horasFalta, horasDictadas FROM dbo.uv_resumen_asistencia_estudiante_grupo WHERE idGrupo = @idGrupo AND codigoEstadoEstudiante = MATRICULA/ESTADO_INSCRITA AND (@idEstudianteGrupo IS NULL OR idEstudianteGrupo = @idEstudianteGrupo)`. Solo matrículas `A` (las `CI`, `I`, `F`, `CVP` no se evalúan). EX no cuenta como falta porque el porcentaje de la vista es `horasFalta / horasDictadas` (DEC-024); las sesiones canceladas y las no vencidas no cuentan (vista de B.2).
6. Por cada tipo (orden por `nivel`):
   - **Cruce nuevo:** `INSERT AlertaInasistencia` (estado `estaVigente = 1`) para los candidatos con `porcentajeInasistencia >= umbral` y sin fila `(estudianteGrupo, tipo)` (`NOT EXISTS … WITH (UPDLOCK, HOLDLOCK)` + `UX_AlertaInasistencia_EstudianteGrupo_Tipo`).
   - **Superada:** `UPDATE` a `estaVigente = 0` las vigentes con porcentaje `< umbral`.
   - **Reactivada:** `UPDATE` a `estaVigente = 1` las superadas con porcentaje `>= umbral` (sin novedad, [SUPUESTO-C-05]).
   - Toda alerta evaluada actualiza `porcentajeUltimaEvaluacion` y `fechaUltimaEvaluacionUtc`.
7. **Revisión:** por cada alerta **recién creada** de un tipo con `creaRevisionCancelacion = 1`, `INSERT RevisionCancelacion` en el estado `esInicial = 1` (`PENDIENTE_DOCENTE`) si no existe una para la matrícula (`UQ_RevisionCancelacion_EstudianteGrupo`) + `RevisionCancelacionHistorial` (actor `NULL`, sistema). Si la matrícula ya tiene revisión (en cualquier estado) no se crea otra.
8. `AuditoriaEvento` (`actorType = SYSTEM`): una fila `ALERTA_INASISTENCIA_REGISTRADA` por alerta creada y `REVISION_CANCELACION_CREADA` por revisión creada (metadata: tipo, porcentaje, umbral, horas).
9. `UPDATE EvaluacionAlertaGrupo SET fechaUltimaEvaluacionUtc = SYSUTCDATETIME(), idCorrelacionUltima = @idCorrelacion, totalEvaluaciones += 1`.
10. `COMMIT` (si es propia); `ALR_003` con los contadores.

`novedadesJSON` (`FOR JSON PATH`): un elemento por **alerta creada**, con lo que necesita el backend para avisar sin otra consulta:

```json
[{ "idAlerta": "…", "codigoTipo": "PERDIDA", "nivel": 2, "esPrincipal": true,
   "porcentajeInasistencia": 21.43, "umbral": 20.00, "horasFalta": 6.000000, "horasDictadas": 28.000000,
   "idEstudianteGrupo": "…", "idGrupo": "…", "codigoGrupo": 1, "nombreGrupo": "G01", "nombreAsignatura": "Bases de datos",
   "tipoPlantillaEstudiante": "ALERTA_PERDIDA_INASISTENCIA",
   "estudiante": { "idEstudiante": "…", "idUsuario": "…", "nombreCompleto": "…", "correo": "…" },
   "docente":    { "idDocente": "…",    "idUsuario": "…", "nombreCompleto": "…", "correo": "…" },
   "idRevisionCreada": "…" }]
```

`esPrincipal = 1` solo para la alerta de mayor `nivel` creada en esta evaluación para esa matrícula ([SUPUESTO-C-05]). El correo es de uso interno del `NotificacionPort`; el backend no lo expone por HTTP ni lo escribe en logs (igual que los SP de destinatarios existentes).

#### 2.5.2 `usp_consultar_grupos_pendientes_evaluacion_alertas` (job y cierre)

```sql
(@idCorrelacion UNIQUEIDENTIFIER, @tamanoLote INT = NULL, @idPeriodoAcademico UNIQUEIDENTIFIER = NULL)
-- Filas: idGrupo, fechaUltimaEvaluacionUtc (NULL si nunca), fechaFinSesionVencidaMasReciente
```

`READ_QUERY_RESULTSET` de sistema. Sin `@idPeriodoAcademico` (job): grupos de periodos no terminados (`PeriodoAcademico.fechaFin >=` fecha local de `TIEMPO/ZONA_HORARIA_SQLSERVER`) con al menos una matrícula `A` y alguna sesión de `uv_cumplimiento_sesion_grupo` con `estaVencida = 1 AND tieneRegistroAsistencia = 1 AND fechaHoraFin > ISNULL(fechaUltimaEvaluacionUtc, '19000101')`; orden `fechaUltimaEvaluacionUtc` ascendente (nulos primero); `TOP (@tamanoLote)` con defecto `ALERTA_INASISTENCIA/LOTE_EVALUACION_AUTOMATICA`. Con `@idPeriodoAcademico` (cierre masivo): todos los grupos del periodo con matrículas `A`, sin marca de agua ni lote. `@tamanoLote < 1` → `PAG_001`.

#### 2.5.3 `usp_consultar_alertas_estudiante` (HU026C)

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = 20,
 @soloNoLeidas BIT = 0, @idGrupo UNIQUEIDENTIFIER = NULL)
-- Filas: columnas de uv_alerta_inasistencia (sin idUsuario/idDocente) + porcentajeActual, umbralActual (de uv_resumen_* de la matrícula),
--        totalRegistros
```

RBAC `ESTUDIANTE`; el estudiante se resuelve desde el usuario y **solo** ve sus alertas (todas sus matrículas, también `CI`, para conservar el historial); `@idGrupo` sin matrícula propia → `SEC_002`. Orden `estaLeida ASC, fechaCruceUtc DESC`. Nunca expone el estado de la revisión ([SUPUESTO-C-14]).

#### 2.5.4 `usp_marcar_alertas_inasistencia_leidas`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @alertasJSON NVARCHAR(MAX))
-- Salida: tupla + marcadas INT
```

RBAC `ESTUDIANTE`; `@alertasJSON` = arreglo de UUID en texto, no vacío, sin duplicados, máximo `ALERTA_INASISTENCIA/MAXIMO_LECTURA_POR_SOLICITUD` (100), si no `ALR_004`. `UPDATE … SET fechaLecturaUtc = SYSUTCDATETIME() WHERE id IN (…) AND fechaLecturaUtc IS NULL AND` la alerta es del ejecutor; ids ajenos o ya leídos no cuentan ni fallan (idempotente). `ALR_005` con `marcadas`. Sin auditoría (no es una mutación de negocio).

#### 2.5.5 `usp_consultar_revisiones_cancelacion_docente_paginado`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = 20,
 @soloPendientes BIT = 0, @codigoEstado NVARCHAR(20) = NULL, @idGrupo UNIQUEIDENTIFIER = NULL)
-- Filas: uv_revision_cancelacion (sin columnas de coordinador salvo nombre, decisión, motivo y fecha) + porcentajeActual,
--        horasFaltaActual, horasDictadasActual, umbralPerdida, accionesPermitidas NVARCHAR(100), totalRegistros
```

RBAC `DOCENTE`; solo grupos donde es titular (`Grupo.docente` del ejecutor); `@idGrupo` ajeno → `SEC_002` (403); `@codigoEstado` inexistente → `RCN_002`. `@soloPendientes = 1` → `requiereAccionDocente = 1`. `accionesPermitidas` = `STRING_AGG(codigoDecision, ',')` de `TransicionRevisionCancelacion` con `codigoPerfilActor = 'DOCENTE'` y origen = estado actual (vacío si la matrícula ya no es `A`). Orden `requiereAccionDocente DESC, fechaCreacionUtc ASC`.

#### 2.5.6 `usp_decidir_revision_cancelacion` (docente; DEC-039 §3)

```sql
(@idRevision UNIQUEIDENTIFIER, @codigoDecision NVARCHAR(20), @motivo NVARCHAR(MAX),
 @idCorrelacion UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL)
-- Salida: tupla + idRevision, codigoEstadoAnterior, codigoEstadoNuevo, codigoDecision, sinCambios BIT, idGrupo,
--         idEstudianteGrupo, idEstudiante, porcentajeActual DECIMAL(5,2), tipoPlantillaNotificacion VARCHAR(60)
```

1. Correlación; `@idUsuarioEjecutor IS NULL` → `GEN_002`; RBAC `DOCENTE`.
2. `@codigoDecision` normalizado (`UPPER(TRIM)`) debe existir en `TransicionRevisionCancelacion` con `codigoPerfilActor = 'DOCENTE'` → si no, `RCN_002` (400).
3. Motivo `TRIM` obligatorio con longitud entre `REVISION_CANCELACION/MOTIVO_LONGITUD_MINIMA` y `MIN(MAXIMA, 1000)` → `RCN_003` (400).
4. Transacción. `SELECT … FROM dbo.RevisionCancelacion WITH (UPDLOCK, HOLDLOCK)` unida a `EstudianteGrupo` y `Grupo` con `Grupo.docente` = docente del ejecutor; si no hay fila → `RCN_001` (404, ajena indistinguible de inexistente).
5. Matrícula distinta de `A` → `RCN_005` (409).
6. **Idempotencia:** si existe una transición con esa decisión cuyo **destino** es el estado actual y la última decisión del docente es la misma (`MANTENIDA`+`MANTENER`, `PROPUESTA`+`PROPONER`) → `RCN_011`, `sinCambios = 1`, sin escrituras.
7. Transición `(estado actual, decisión)` inexistente → `RCN_004` (409, "la revisión está en estado {nombre} y no admite esa decisión").
8. `exigeUmbralPerdida = 1`: porcentaje actual de `uv_resumen_*` de la matrícula `< ufn_umbral_alerta_inasistencia(tipo de pérdida)` → `RCN_006` (409).
9. `exigeCoordinadorDisponible = 1`: `NOT EXISTS ufn_coordinadores_revision_cancelacion(@idEstudianteGrupo)` → `RCN_013` (409).
10. `UPDATE RevisionCancelacion` (estado destino, `codigoDecisionDocente`, `motivoDocente`, `usuarioDecisionDocente`, `porcentajeDecisionDocente`, `fechaDecisionDocenteUtc`, `fechaActualizacionUtc`); al pasar de `RECHAZADA` a `PROPUESTA` se limpian las columnas del coordinador (la resolución anterior queda en el historial). `RevisionCancelacionHistorial` + `AuditoriaEvento` (`DECIDIR_REVISION_CANCELACION`, `PATCH /api/v1/docente/revisiones-cancelacion/{revisionId}`).
11. `COMMIT`; mensaje = `codigoMensajeExito` de la transición (`RCN_007`/`RCN_008`).

Con `MANTENER` no se crea nueva alerta ni revisión aunque el porcentaje siga subiendo (la alerta es única por tipo y la revisión por matrícula): el estudiante queda marcado (`MANTENIDA`) y el docente puede `PROPONER` después (transición 3).

#### 2.5.7 `usp_consultar_revisiones_cancelacion_coordinador_paginado`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = 20,
 @soloPendientes BIT = 0, @codigoEstado NVARCHAR(20) = NULL, @idPrograma UNIQUEIDENTIFIER = NULL, @idGrupo UNIQUEIDENTIFIER = NULL)
-- Filas: uv_revision_cancelacion + idPrograma, nombrePrograma (programa del coordinador por el que la ve), porcentajeActual,
--        horasFaltaActual, horasDictadasActual, umbralPerdida, accionesPermitidas, totalRegistros
```

RBAC `COORDINADOR`. Filas: revisiones cuya matrícula tiene al ejecutor en `ufn_coordinadores_revision_cancelacion` (**ámbito por el programa del estudiante**, no por el grupo; en un grupo mixto el coordinador del programa A no ve a los estudiantes del programa B). `@idPrograma` fuera de `ufn_programas_coordinador(ejecutor)` → `COO_003` (403); sin `@idPrograma` → unión de sus programas (S4 de B2), con una fila por revisión (si el estudiante está en dos programas del mismo coordinador, `idPrograma` = el de menor nombre; prueba de cardinalidad). `@idGrupo` sin ningún programa en común → `SEC_002`. `@soloPendientes = 1` → `requiereAccionCoordinador = 1`. `accionesPermitidas` con `codigoPerfilActor = 'COORDINADOR'`; vacío si el ejecutor fue quien propuso como docente ([SUPUESTO-C-09]). Orden `requiereAccionCoordinador DESC, fechaDecisionDocenteUtc ASC`.

#### 2.5.8 `usp_resolver_revision_cancelacion` (coordinador; DEC-039 §4)

```sql
(@idRevision UNIQUEIDENTIFIER, @codigoDecision NVARCHAR(20), @motivo NVARCHAR(MAX),
 @idCorrelacion UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL)
-- Salida: tupla + idRevision, codigoEstadoAnterior, codigoEstadoNuevo, codigoDecision, sinCambios BIT, cambioMatricula BIT,
--         idGrupo, idEstudianteGrupo, idEstudiante, idPrograma, porcentajeActual, tipoPlantillaNotificacion
```

Mismos pasos 1–3 con `codigoPerfilActor = 'COORDINADOR'` y RBAC `COORDINADOR`. Después:
4. Transacción. `RevisionCancelacion WITH (UPDLOCK, HOLDLOCK)`; el ejecutor debe estar en `ufn_coordinadores_revision_cancelacion(estudianteGrupo)` → si no, `RCN_001` (404). `idPrograma` = programa común (menor nombre si hay varios).
5. `usuarioDecisionDocente = @idUsuarioEjecutor` → `RCN_014` (409, segregación).
6. Idempotencia (`APROBADA`+`APROBAR`, `RECHAZADA`+`RECHAZAR` con la misma última decisión del coordinador) → `RCN_011`, `sinCambios = 1`.
7. Transición inexistente → `RCN_004`; matrícula distinta de `A` → `RCN_005`; `exigeUmbralPerdida` incumplido → `RCN_006`.
8. Si el estado destino tiene `cancelaMatricula = 1`: `SELECT … FROM dbo.EstudianteGrupo WITH (UPDLOCK, HOLDLOCK)`; guarda `estadoMatriculaAnterior`; `UPDATE EstudianteGrupo SET estado = (id de MATRICULA/ESTADO_CANCELADA_INASISTENCIA)`; `cambioMatricula = 1`. Desde ese momento la matrícula queda fuera de todo registro: `usp_sincronizar_asistencia_estudiante_interno` y el lote exigen `A` (`EST_004`), `usp_registrar_asistencia_por_token` responde `AQR_004`, `uv_faltantes_toma` filtra `A`, y el frontend del docente filtra `codigoEstado === 'A'` (`attendance-control.component.ts:717/966/1065`). No se tocan los contadores de `Grupo` (los recalcula el cierre masivo; `uv_estadistica_grupo` cuenta en vivo).
9. `UPDATE RevisionCancelacion` (estado, decisión, motivo, usuario, programa, porcentaje, fecha) + historial + `AuditoriaEvento` (`RESOLVER_REVISION_CANCELACION`, metadata con estado de matrícula anterior/nuevo).
10. `COMMIT`; mensaje de la transición (`RCN_009`/`RCN_010`).

#### 2.5.9 `usp_consultar_destinatarios_revision_cancelacion`

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @idRevision UNIQUEIDENTIFIER)
-- Filas: rolDestinatario (ESTUDIANTE | DOCENTE | COORDINADOR), idUsuario, nombreCompleto, correo, idPrograma (solo COORDINADOR),
--        + contexto repetido: idGrupo, codigoGrupo, nombreGrupo, nombreAsignatura, nombreCompletoEstudiante, nombreCompletoDocente,
--        codigoEstado, porcentajeActual, umbralPerdida, motivoDocente, motivoCoordinador, nombreCompletoCoordinadorResolucion
```

`READ_QUERY_RESULTSET` sin paginación (≤ 2 + coordinadores). El ejecutor debe ser el docente titular del grupo o un coordinador de `ufn_coordinadores_revision_cancelacion` (si no, `THROW 51000` con `RCN_001`). Devuelve siempre los tres roles; el caso de uso elige según el evento (§3.5). Mismo formato y reglas de privacidad que `usp_consultar_destinatarios_sesion_cancelada`.

#### 2.5.10 `usp_consultar_audiencias_realtime_grupo` (SSE; DEC-039 §5)

```sql
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @idGrupo UNIQUEIDENTIFIER)
-- 1 fila: esDocenteTitular BIT, esEstudianteActivo BIT, esAmbitoLectura BIT
```

Sin RBAC por perfil (cualquier usuario autenticado; el resultado es el ámbito). `GEN_002` si falta un id. Reglas: `esDocenteTitular` = `Grupo.docente` del ejecutor; `esEstudianteActivo` = matrícula `MATRICULA/ESTADO_INSCRITA` del ejecutor en el grupo; `esAmbitoLectura` = coordinador activo con algún programa en `ufn_programas_grupo(grupo) ∩ ufn_programas_coordinador(ejecutor)`, **o** decano activo de la facultad de alguno de esos programas, **o** administrador activo de la institución del periodo del grupo. Grupo inexistente o ajeno → fila con los tres en 0 (el backend responde 403 sin distinguir).

### 2.6 Objetos existentes que cambian (ninguno está en un manifiesto congelado)

| Objeto | Cambio |
| :--- | :--- |
| `usp_consultar_resumen_asistencia_grupo_docente_paginado` (B.2, HU040/HU041) | `LEFT JOIN uv_marca_inasistencia_estudiante_grupo` y columnas nuevas al final: `tieneAdvertenciaVigente, fechaAdvertenciaUtc, tienePerdidaVigente, fechaPerdidaUtc, idRevisionCancelacion, codigoEstadoRevision, nombreEstadoRevision, requiereAccionDocente, accionesPermitidasRevision` (mismo cálculo que §2.5.5). Columnas existentes sin cambio de nombre, tipo ni orden |
| `usp_ejecutar_cierre_masivo_periodo` (HU174; versión B.2 con `COUNT(DISTINCT a.sesion)`) | [SUPUESTO-C-10]: se retira la CTE `InasistenciasPorEstudiante` y el `HAVING … >= 3`. Antes de abrir la transacción: si existe matrícula `A` del periodo con revisión `requiereAccionDocente = 1 OR requiereAccionCoordinador = 1`, **o** con `uv_resumen_*.codigoPermanencia` de pérdida (mismo `ufn_clasificar_permanencia`) y sin revisión → `RCN_012` con el total, `estadoResultado = 0`, sin escrituras. Si no, todas las `A` → `F` (las `MANTENIDA`/`RECHAZADA` también), recálculo de contadores (sin cambio) y `AuditoriaEvento` con `metadata` `{procesados, finalizados, canceladosPorInasistencia (conteo de CI existentes), bloqueados: 0}`. Los literales `'F'`, `'CI'`, `'A'` del SP pasan a parámetros (`MATRICULA/ESTADO_FINALIZADA` nuevo = `F`, `ESTADO_CANCELADA_INASISTENCIA`, `ESTADO_INSCRITA`) |
| `usp_consultar_destinatarios_reclamo_asistencia` | Columna nueva `idGrupo` al final (para el motor tras aprobar un reclamo y para el evento `SOLICITUD_REVISION_RESUELTA`, §3.6.4). Sin otro cambio |

### 2.7 Mensajes nuevos (semilla `40_culm001_c_mensajes.sql`, MERGE en `CatalogoMensajeUsuario` y `CatalogoMensajeTecnico`)

Tipo y severidad con el patrón de `04_mensaje.sql`; `DB:scripts/generar-catalogo-mensajes.ps1 -Check` debe pasar y el catálogo de MessageUcoLab se regenera con `INFRA:components/messages/build-message-catalog.py`.

| Código | Tipo / severidad | Mensaje de usuario | Mensaje técnico (plantilla) | HTTP |
| :--- | :--- | :--- | :--- | :--- |
| `ALR_001` | SUCCESS / BAJO | Las alertas de inasistencia están deshabilitadas. | ALERTA_INASISTENCIA/HABILITADA != true; evaluación de [{}] sin escrituras. | — (interno) |
| `ALR_002` | TECHNICAL_ERROR / CRITICO | No fue posible evaluar las alertas de inasistencia. | Falta o no es numérico el umbral [{}] del tipo [{}]. | 500 (interno) |
| `ALR_003` | SUCCESS / BAJO | Evaluación de alertas completada. | Grupo [{}]: {} alertas nuevas, {} superadas, {} reactivadas, {} revisiones. | — |
| `ALR_004` | VALIDATION_ERROR / BAJO | La lista de alertas no es válida. | @alertasJSON vacío, inválido, con duplicados o con más de {} elementos. | 400 |
| `ALR_005` | SUCCESS / BAJO | Se marcaron {} alertas como leídas. | Lectura de alertas del estudiante [{}]. | 200 |
| `ALR_006` | VALIDATION_ERROR / BAJO | La matrícula indicada no pertenece al grupo. | EstudianteGrupo [{}] no es del grupo [{}]. | — (interno) |
| `ALR_010` | INFO / BAJO | Llevas {}% de inasistencia en {}. Si llegas al {}% podrías perder la asignatura. | Texto de la alerta ADVERTENCIA (porcentaje, asignatura, umbral de pérdida). | — (lo resuelve el backend por fila) |
| `ALR_011` | INFO / MEDIO | Alcanzaste {}% de inasistencia en {} (límite {}%). Tu docente revisará tu caso. | Texto de la alerta PERDIDA. | — |
| `RCN_001` | BUSINESS_ERROR / BAJO | La revisión de cancelación no existe. | Revisión [{}] inexistente o fuera del ámbito del ejecutor [{}]. | 404 |
| `RCN_002` | VALIDATION_ERROR / BAJO | La decisión no es válida. | @codigoDecision/@codigoEstado [{}] no existe para el perfil [{}]. | 400 |
| `RCN_003` | VALIDATION_ERROR / BAJO | El motivo debe tener entre {} y {} caracteres. | Longitud de @motivo fuera de REVISION_CANCELACION/MOTIVO_LONGITUD_*. | 400 |
| `RCN_004` | BUSINESS_ERROR / MEDIO | La revisión está en estado «{}» y no admite esa decisión. | Sin TransicionRevisionCancelacion para ({}, {}). | 409 |
| `RCN_005` | BUSINESS_ERROR / MEDIO | La matrícula del estudiante ya no está activa en el grupo. | EstudianteGrupo [{}] con estado [{}]. | 409 |
| `RCN_006` | BUSINESS_ERROR / MEDIO | El estudiante ya no supera el límite de inasistencia ({}% de {}%); no se puede proponer ni aprobar la cancelación. | Porcentaje actual [{}] < umbral [{}]. | 409 |
| `RCN_007` | SUCCESS / BAJO | Decisión registrada: el estudiante se mantiene en el grupo. | Revisión [{}] → MANTENIDA. | 200 |
| `RCN_008` | SUCCESS / BAJO | Se envió la propuesta de cancelación a la coordinación del programa. | Revisión [{}] → PROPUESTA. | 200 |
| `RCN_009` | SUCCESS / BAJO | Cancelación aprobada: el estudiante quedó cancelado por inasistencia. | Revisión [{}] → APROBADA; EstudianteGrupo [{}] → CI. | 200 |
| `RCN_010` | SUCCESS / BAJO | Cancelación rechazada: el estudiante sigue activo en el grupo. | Revisión [{}] → RECHAZADA. | 200 |
| `RCN_011` | SUCCESS / BAJO | La decisión ya estaba registrada. | Revisión [{}] ya en [{}]; sin escrituras. | 200 |
| `RCN_012` | BUSINESS_ERROR / ALTO | Hay {} casos de pérdida por inasistencia sin resolver en el periodo; resuélvelos antes del cierre. | Cierre masivo de [{}] bloqueado por revisiones pendientes o pérdidas sin revisión. | 409 |
| `RCN_013` | BUSINESS_ERROR / MEDIO | El programa del estudiante no tiene un coordinador activo que pueda resolver la propuesta. | ufn_coordinadores_revision_cancelacion vacío para [{}]. | 409 |
| `RCN_014` | BUSINESS_ERROR / MEDIO | No puedes resolver una propuesta de cancelación que hiciste como docente. | Ejecutor [{}] = usuarioDecisionDocente de [{}]. | 409 |

Reutilizados: `GEN_002`, `SEC_002`, `PAG_001`, `COO_002`, `COO_003` (B2), `EST_004`, `AQR_004`, `SYS_001`. `SES_030`+ reservado sin uso.

### 2.8 Parámetros nuevos (semilla `40_culm001_c_parametros.sql`, MERGE que no pisa `valor` administrado)

| Grupo | Clave | Valor = defecto | Tipo |
| :--- | :--- | :--- | :--- |
| `ALERTA_INASISTENCIA` | `HABILITADA` | `true` | BOOLEAN |
| `ALERTA_INASISTENCIA` | `LOTE_EVALUACION_AUTOMATICA` | `50` | INT |
| `ALERTA_INASISTENCIA` | `MAXIMO_LECTURA_POR_SOLICITUD` | `100` | INT |
| `REVISION_CANCELACION` | `MOTIVO_LONGITUD_MINIMA` / `MOTIVO_LONGITUD_MAXIMA` | `10` / `500` | INT |
| `MATRICULA` | `ESTADO_CANCELADA_INASISTENCIA` | `CI` | STRING |
| `MATRICULA` | `ESTADO_FINALIZADA` | `F` | STRING |

Reutilizados sin cambio de valor: `ASISTENCIA/UMBRAL_ALERTA_ADVERTENCIA` (15), `ASISTENCIA/UMBRAL_ALERTA_PERDIDA` (20), `MATRICULA/ESTADO_INSCRITA` (A, de A), `PAGINACION/TAMANO_MAXIMO`, `TIEMPO/ZONA_HORARIA_SQLSERVER`. DEC-018: los que lee el backend (`ALERTA_INASISTENCIA/HABILITADA`) tienen en código un defecto igual a la semilla.

### 2.9 Plantillas de notificación (semilla `41_culm001_c_plantillas_notificacion.sql`, patrón `26_plantillas_notificacion.sql`)

| Tipo | Destinatario | Asunto | Marcadores |
| :--- | :--- | :--- | :--- |
| `ALERTA_RIESGO_INASISTENCIA` (existente) | Estudiante | sin cambio | existentes; cuerpo actualizado a `{umbral}` solo si coincide con el texto por defecto anterior ([SUPUESTO-C-16]) |
| `ALERTA_PERDIDA_INASISTENCIA` (existente) | Estudiante ([SUPUESTO-C-06]) | sin cambio | existentes; cuerpo actualizado a `{limite}` con la misma regla |
| `REVISION_CANCELACION_PENDIENTE` (nueva) | Docente titular | `Revisión de cancelación pendiente: {estudiante} en {grupo}` | `docente, estudiante, grupo, porcentaje, limite` (todos obligatorios) |
| `PROPUESTA_CANCELACION` (nueva) | Coordinadores competentes | `Propuesta de cancelación por inasistencia: {estudiante} en {grupo}` | `coordinador, estudiante, grupo, docente, porcentaje, limite, motivo` |
| `CANCELACION_APROBADA` (nueva) | Estudiante y docente | `Cancelación por inasistencia en {grupo}` | `destinatario, estudiante, grupo, porcentaje, motivo, coordinador` |
| `CANCELACION_RECHAZADA` (nueva) | Docente | `Propuesta de cancelación rechazada: {estudiante} en {grupo}` | `docente, estudiante, grupo, motivo, coordinador` |

Mismo texto por defecto en `BE:…/notification/template/PlantillaPorDefectoCatalogo` (los casos de uso no componen asuntos ni cuerpos en Java). Los cuerpos no incluyen enlaces ni datos de otros estudiantes.

### 2.10 Permisos

`DB:schema/security/rol_asistencias_runtime_culm001_c.sql` (`GRANT EXECUTE` con guard `IF OBJECT_ID(...,'P') IS NOT NULL`): `usp_evaluar_alertas_inasistencia_grupo`, `usp_consultar_grupos_pendientes_evaluacion_alertas`, `usp_consultar_alertas_estudiante`, `usp_marcar_alertas_inasistencia_leidas`, `usp_consultar_revisiones_cancelacion_docente_paginado`, `usp_decidir_revision_cancelacion`, `usp_consultar_revisiones_cancelacion_coordinador_paginado`, `usp_resolver_revision_cancelacion`, `usp_consultar_destinatarios_revision_cancelacion`, `usp_consultar_audiencias_realtime_grupo`. `GRANT SELECT` explícito a las vistas nuevas (el bucle `uv_*` de `rol_asistencias_runtime.sql` está congelado y no se toca; mismo criterio que B §2.13). Las funciones no se conceden. `DB:test/test_public_objects.sql` se amplía con la lista.

### 2.11 Migración `19_culm001_c_cancelacion_inasistencia_up|down.sql`

**`up`** (idempotente, `SET XACT_ABORT ON`, `@@TRANCOUNT = 0` al terminar): crea los 4 catálogos con sus filas (MERGE por id) y las 4 tablas con índices y FKs (`IF OBJECT_ID … IS NULL`); `CREATE OR ALTER` de funciones y vistas; `GRANT` condicionados. **No evalúa alertas** ([SUPUESTO-C-15]). Resultset de control: `catalogosCreados`, `transiciones` (= 6), `matriculasEnPerdidaSinRevision` (solo reporte, para dimensionar el primer pase del job).
Los SP, las semillas y los cambios de §2.6 se despliegan con `deploy_schema.ps1` (CREATE OR ALTER / MERGE), igual que en B.

**`down`**: (1) si hay filas en `AlertaInasistencia`, `RevisionCancelacion` o `RevisionCancelacionHistorial`, las copia a `zz_archivo_AlertaInasistencia_culm001_c`, `zz_archivo_RevisionCancelacion_culm001_c`, `zz_archivo_RevisionCancelacionHistorial_culm001_c` (sin FKs; patrón DEC-010) y reporta cuántas matrículas quedaron en `CI` por revisión aprobada (**no se revierten**, [SUPUESTO-C-17]); (2) `DROP` de los 10 SP nuevos, vistas y funciones de C; (3) restaura el texto de B.2 de `usp_consultar_resumen_asistencia_grupo_docente_paginado` y `usp_ejecutar_cierre_masivo_periodo`, y el anterior de `usp_consultar_destinatarios_reclamo_asistencia` (copiados literal en el `down`); (4) `DROP TABLE RevisionCancelacionHistorial, RevisionCancelacion, AlertaInasistencia, EvaluacionAlertaGrupo, TransicionRevisionCancelacion, EstadoRevisionCancelacion, EstadoAlertaInasistencia, TipoAlertaInasistencia` en ese orden; (5) borra parámetros, mensajes y plantillas nuevas de C **solo si** `valor = valorDefecto` / texto por defecto, restaura el cuerpo anterior de las dos plantillas `ALERTA_*` con la misma regla y marca como canceladas en `NotificacionSaliente` las pendientes de los 4 tipos nuevos (patrón DEC-010).

### 2.12 Manifiestos y contratos de BD

- C **no modifica ningún objeto congelado** (`DB_DEVELOP_FREEZE_MANIFEST`, `DB_UTC_D06_POST_FREEZE_MANIFEST`, `DB_LB004D_SUPPORT_BINDING_MANIFEST`, `DB_CULM001_B_POST_FREEZE_MANIFEST`): `usp_ejecutar_cierre_masivo_periodo`, `usp_consultar_resumen_asistencia_grupo_docente_paginado` y `usp_consultar_destinatarios_reclamo_asistencia` no están en ninguno (B §2.15 los dejó fuera a propósito).
- **Manifiesto post-freeze de C:** `DB:docs/contracts/DB_CULM001_C_POST_FREEZE_MANIFEST.sha256`, solo líneas `<sha256>  <ruta>  WORK_ITEM`, generado con `freeze-manifest.ps1 -Mode GeneratePostFreeze -Manifest … -Files …` (extensión de B) **después** de la aprobación 9.2: las 8 tablas, `uv_alerta_inasistencia.sql`, `uv_revision_cancelacion.sql`, `usp_evaluar_alertas_inasistencia_grupo.sql`, `usp_decidir_revision_cancelacion.sql`, `usp_resolver_revision_cancelacion.sql`, `usp_consultar_audiencias_realtime_grupo.sql`, la migración 19 `up|down` y `rol_asistencias_runtime_culm001_c.sql`. Quedan fuera las consultas, semillas y los objetos de §2.6 (D puede tocarlos).
- `DB:docs/contracts/DB_DEVELOP_FREEZE_ADDENDUM.md` (y su copia en Infra): sección "CULM-001 C" con (1) el estado `CI` solo nace de una revisión aprobada; (2) la regla nueva del cierre masivo; (3) la unicidad de alertas y revisiones. Cambio de texto WORM: se regenera su `.sha256` tras la revisión 9.2.

### 2.13 Pruebas T-SQL RED

Archivos `DB:test/test_culm001_c_alertas.sql`, `test_culm001_c_revisiones.sql`, `test_culm001_c_cierre_masivo.sql`, `test_culm001_c_realtime_audiencias.sql`, `test_culm001_c_migraciones.sql`, `test_culm001_c_concurrencia.ps1` y el fixture `test_culm001_c_fixture.sql`. El fixture parte del de segundo ámbito de A y del grupo mixto de B2 (`_ambito_grupo_mixto.sql`: grupo G con programas PA y PB; estudiantes EA ∈ PA, EB ∈ PB, E0 sin vínculo; coordinadores CA, CB; decano D; docente titular T; administrador AD) y crea sesiones **vencidas** de 2 h con tomas y detalles insertados directamente con la columna `toma` (patrón [SUPUESTO-B-20]). Cada prueba termina con `@@TRANCOUNT = 0`, limpia lo que crea y falla con `THROW` y un mensaje `TEST FAILED: C-DB-xx …`.

| ID | Regla probada | Criterio |
| :--- | :--- | :--- |
| C-DB-01 | **Cruce de advertencia una sola vez** | EA con 16 % por horas: 1 alerta ADVERTENCIA `VIGENTE`, `alertasCreadas = 1`, 1 elemento en `novedadesJSON` con `esPrincipal = 1`; 2.ª y 3.ª evaluación: 0 novedades, 1 sola fila |
| C-DB-02 | Bajo el umbral no hay alerta | EA con 14,9 %: 0 filas |
| C-DB-03 | **EX no cuenta** | EB con 6 h de EX y 2 h de SJC sobre 20 h dictadas (10 %): 0 alertas; al pasar 2 h de EX a SJC (20 %): ADVERTENCIA y PERDIDA |
| C-DB-04 | Por horas, no por sesiones | Sesión de 4 h con 2 tomas; falta en 1 toma = 2 h de falta; el porcentaje coincide con `uv_resumen_*` |
| C-DB-05 | Sesiones no vencidas y canceladas no cuentan | SJC en una sesión futura: sin alerta hasta que vence (se simula moviendo `fechaHoraFin` al pasado con `procedenciaTemporal` en el mismo `SET`); sesión con `SesionCancelacion`: no suma |
| C-DB-06 | Salto directo | De 10 % a 25 %: 2 alertas, 1 revisión `PENDIENTE_DOCENTE`, `esPrincipal = 1` solo en PERDIDA |
| C-DB-07 | Superada y reactivada sin novedad | Bajar a 12 % → `SUPERADA` (`alertasSuperadas = 1`); subir a 16 % → `VIGENTE`, 0 novedades, misma fila |
| C-DB-08 | Solo matrículas `A` | Matrículas `CI`, `I`, `F` con 30 %: 0 alertas |
| C-DB-09 | Interruptor y umbral faltante | `HABILITADA = false` → `ALR_001`, 0 escrituras; umbral borrado → `ALR_002`, `estadoResultado = 0`, 0 escrituras; se restauran |
| C-DB-10 | `@idEstudianteGrupo` | Evalúa solo esa matrícula; de otro grupo → `ALR_006` |
| C-DB-11 | Marca de agua y pendientes | Tras evaluar, el grupo no sale en `usp_consultar_grupos_pendientes_evaluacion_alertas`; al vencer otra sesión, vuelve a salir; un grupo de periodo terminado nunca sale |
| C-DB-12 | Auditoría del motor | 1 `ALERTA_INASISTENCIA_REGISTRADA` por alerta y 1 `REVISION_CANCELACION_CREADA` por revisión, `actorType = SYSTEM`, `correlationId` del llamado |
| C-DB-13 | Transacción externa | Con `BEGIN TRAN` externo: usa savepoint y no confirma; error forzado con transacción condenada → `THROW` al llamador |
| C-DB-14 | Lectura de alertas | Marca solo las propias; ids ajenos ignorados; repetir no cambia `fechaLecturaUtc`; lista vacía o 101 ids → `ALR_004` |
| C-DB-15 | Consulta del estudiante | Solo sus alertas; `soloNoLeidas`; `@idGrupo` ajeno → `THROW` con `SEC_002`; nunca columnas de revisión |
| C-DB-20 | **Cruce de pérdida crea una sola revisión** | 3 evaluaciones y 2 llamadas concurrentes simuladas (dos sesiones en el `.ps1`, C-DB-50): 1 revisión, 1 historial de creación |
| C-DB-21 | **Mantener: sin nueva alerta y proponer después** | T `MANTENER` (`RCN_007`, `MANTENIDA`); EA sube a 35 % y se evalúa: 0 novedades, 0 revisiones nuevas, sigue `MANTENIDA`; T `PROPONER` → `PROPUESTA` (`RCN_008`) |
| C-DB-22 | Motivo y decisión | Motivo vacío, de 9 o de 501 caracteres → `RCN_003`; decisión `APROBAR` por el docente → `RCN_002`; sin escrituras |
| C-DB-23 | Ámbito del docente | Otro docente → `RCN_001`; revisión inexistente → `RCN_001` (mismo mensaje); listado del docente solo con sus grupos; `@idGrupo` ajeno → `SEC_002` |
| C-DB-24 | Transición e idempotencia | `PROPUESTA` + `MANTENER` → `RCN_004`; `MANTENIDA` + `MANTENER` → `RCN_011`, `sinCambios = 1`, 0 historial nuevo |
| C-DB-25 | Umbral al proponer y aprobar | Con EA bajado a 18 % (excusa aprobada): `PROPONER` → `RCN_006`; `MANTENER` permitido |
| C-DB-26 | **Aprobar ⇒ `CI` y desaparece del registro** | CA aprueba la propuesta de EA: `APROBADA`, `EstudianteGrupo` = `CI`, `estadoMatriculaAnterior` = `A`, historial y auditoría; luego EA no está en `uv_faltantes_toma` de una toma abierta, `usp_registrar_asistencias_toma`/lote con EA → `EST_004`, `usp_registrar_asistencia_por_token` de EA → `AQR_004`; EA ya no se evalúa (C-DB-08) |
| C-DB-27 | **Rechazar ⇒ sigue activo** | CA rechaza: `RECHAZADA`, matrícula `A`, EA sigue en faltantes y se puede registrar; T vuelve a `PROPONER` → `PROPUESTA` con columnas del coordinador limpias e historial completo |
| C-DB-28 | **Ámbito del coordinador por programa del estudiante (grupo mixto)** | Listado de CA: revisión de EA sí, de EB no; CB al revés; CA resuelve EB → `RCN_001`; E0 (sin `EstudiantePrograma`): ningún coordinador la ve y `PROPONER` → `RCN_013`; D (decano) y T no pueden resolver (RBAC); `@idPrograma` ajeno → `COO_003` |
| C-DB-29 | Segregación | Usuario que es T y coordinador de PA propone y luego intenta aprobar → `RCN_014` |
| C-DB-30 | Cardinalidad | Las 4 vistas nuevas y los 2 listados con G en dos programas: `COUNT(*) = COUNT(DISTINCT id)`; estudiante en PA y PB con el mismo coordinador → 1 fila |
| C-DB-31 | Destinatarios | Por revisión: 1 estudiante, 1 docente, coordinadores = `ufn_coordinadores_revision_cancelacion`; ejecutor ajeno → `RCN_001` |
| C-DB-32 | Resumen del docente con marcas | `usp_consultar_resumen_asistencia_grupo_docente_paginado` trae las columnas nuevas y las existentes sin cambio (orden y tipos) |
| C-DB-40 | Cierre masivo bloqueado | Con una revisión `PENDIENTE_DOCENTE` o una pérdida sin revisión → `RCN_012`, 0 cambios en `EstudianteGrupo`, `Grupo` y `AuditoriaEvento` |
| C-DB-41 | Cierre masivo sin la regla `>= 3` | Estudiante con 3 sesiones SJC y 10 % por horas → `F`; con 3 EX → `F`; `MANTENIDA` con 30 % → `F`; `APROBADA` sigue `CI`; contadores correctos |
| C-DB-42 | Reclamo aprobado | `usp_consultar_destinatarios_reclamo_asistencia` trae `idGrupo` |
| C-DB-45 | Audiencias SSE | T: titular 1; EA (`A`): estudiante 1; EA tras `CI`: 0; CA: ámbito 1; coordinador de otro programa: 0; D de la facultad: 1; AD de la institución: 1; AD de otra institución (fixture de A): 0 |
| C-DB-50 | Concurrencia (`.ps1`) | 2 sesiones `sqlcmd` evaluando el mismo grupo a la vez y otras 5 sobre 5 grupos distintos: 1 alerta por (matrícula, tipo), 1 revisión por matrícula, sin deadlocks ni errores; resolución de CA concurrente con `usp_retirar_estudiante_grupo` del mismo estudiante: uno gana, el otro responde `RCN_005`/`RET_002`, sin deadlock |
| C-DB-60 | Migración | `up → up` (idempotente), `up → down → up`; `down` con datos: archivos `zz_*` con las mismas filas y matrículas `CI` intactas; `@@TRANCOUNT = 0` |
| C-DB-61 | Objetos públicos | `test_public_objects.sql`: los 10 SP concedidos, funciones no concedidas |

Gate: `infra.ps1 db-test` sin fallos nuevos frente a la línea base (F-000) y `freeze-manifest.ps1 -Mode Verify` verde.

---

## 3. Backend (`GestioAsistenciaBackend`)

### 3.1 Reglas comunes

Flujo `Controller → InputPort → UseCaseImpl → SecondaryPort → *JpaRepository` (adaptador JPA que ejecuta el SP; nunca SQL en controladores ni en `application`). Mensajes por `MessageCatalogPort` (los `*ErrorCode` Java son solo respaldo). Respuestas `ApiDataResponse<T>` / `ApiPageResponse<T>`. `CorrelationIdContext` hasta el SP. Eventos SSE y notificaciones **después** del commit, de mejor esfuerzo (`RuntimeException` capturada y registrada con `correlationId`, sin datos personales en el log); nunca rompen la respuesta ni provocan rollback.

### 3.2 Endpoints

| Método y ruta | Rol | Petición | Respuesta |
| :--- | :--- | :--- | :--- |
| `GET /api/v1/estudiante/alertas?soloNoLeidas=false&grupoId=&pagina=1&tamano=20` | ESTUDIANTE | — | 200 `ApiPageResponse<AlertaInasistenciaResponse>`; 400 (`PAG_001`); 403 (`SEC_002`) |
| `PATCH /api/v1/estudiante/alertas/lectura` | ESTUDIANTE | `{ "alertas": ["uuid", …] }` (1..100) | 200 `ApiDataResponse<{ "marcadas": 2 }>` + `mensajeUsuario` (`ALR_005`); 400 (`ALR_004`, cuerpo inválido) |
| `GET /api/v1/docente/revisiones-cancelacion?soloPendientes=false&estado=&grupoId=&pagina=1&tamano=20` | DOCENTE | — | 200 `ApiPageResponse<RevisionCancelacionResponse>`; 400; 403 (`SEC_002`) |
| `PATCH /api/v1/docente/revisiones-cancelacion/{revisionId}` | DOCENTE | `{ "decision": "MANTENER" \| "PROPONER", "motivo": "…" }` | 200 `ApiDataResponse<RevisionCancelacionResponse>` + `mensajeUsuario` (`RCN_007`/`RCN_008`/`RCN_011`); 400 (`RCN_002`, `RCN_003`, cuerpo); 404 (`RCN_001`); 409 (`RCN_004`, `RCN_005`, `RCN_006`, `RCN_013`) |
| `GET /api/v1/coordinador/revisiones-cancelacion?soloPendientes=false&estado=&programaId=&grupoId=&pagina=1&tamano=20` | COORDINADOR | — | 200 `ApiPageResponse<RevisionCancelacionResponse>`; 400; 403 (`COO_003`, `SEC_002`) |
| `PATCH /api/v1/coordinador/revisiones-cancelacion/{revisionId}` | COORDINADOR | `{ "decision": "APROBAR" \| "RECHAZAR", "motivo": "…" }` | 200 + `mensajeUsuario` (`RCN_009`/`RCN_010`/`RCN_011`); 400; 404; 409 (`RCN_004`, `RCN_005`, `RCN_006`, `RCN_014`) |
| `GET /api/v1/realtime/stream/personal` (NUEVO) | Autenticado (5 roles) | — | 200 `text/event-stream` (§3.6.2) |
| `GET /api/v1/realtime/stream?grupoId=` (MODIFICADO, golden path) | Autenticado | — | 200 según ámbito; 403 si el usuario no tiene ninguna audiencia en el grupo (antes: 403 a todo no titular) |
| `GET /api/v1/docente/grupos/{grupoId}/resumen-asistencia` (B.2, MODIFICADO) | DOCENTE titular | — | Cada elemento añade `marca` (abajo) |
| `POST /api/v1/admin/cierre-masivo` (MODIFICADO, HU174) | ADMINISTRADOR | sin cambio | Nuevo 409 con `RCN_012`; antes del SP el caso de uso evalúa los grupos del periodo (§3.4) |

`decision` y `motivo` se validan en el controlador (Bean Validation: `decision` no vacía, `motivo` no nulo) y la regla de valores y longitudes queda en el SP (`RCN_002`/`RCN_003`); un cuerpo con campos extra o sin JSON → 400 `VALIDATION_ERROR`.

```json
// AlertaInasistenciaResponse
{ "id": "uuid", "tipo": "ADVERTENCIA", "nombreTipo": "Riesgo de pérdida por inasistencia", "estado": "VIGENTE",
  "mensaje": "Llevas 16.00% de inasistencia en Bases de datos. Si llegas al 20.00% podrías perder la asignatura.",
  "porcentajeCruce": 16.00, "porcentajeActual": 16.00, "umbral": 15.00, "umbralPerdida": 20.00,
  "horasFalta": 4.00, "horasDictadas": 25.00, "fechaCruceUtc": "2026-11-10T15:00:00Z",
  "leida": false, "fechaLecturaUtc": null,
  "grupo": { "id": "uuid", "codigo": 1, "nombre": "G01" }, "asignatura": { "id": "uuid", "nombre": "Bases de datos" },
  "estadoMatricula": "A" }

// RevisionCancelacionResponse (docente y coordinador; los campos de coordinador/programa son null para el docente si no aplica)
{ "id": "uuid", "estado": "PENDIENTE_DOCENTE", "nombreEstado": "Pendiente de decisión del docente",
  "requiereAccionDocente": true, "requiereAccionCoordinador": false, "accionesPermitidas": ["MANTENER", "PROPONER"],
  "estudiante": { "id": "uuid", "nombreCompleto": "…" }, "estadoMatricula": "A",
  "grupo": { "id": "uuid", "codigo": 1, "nombre": "G01" }, "asignatura": { "id": "uuid", "nombre": "…" },
  "docente": { "id": "uuid", "nombreCompleto": "…" }, "programa": { "id": "uuid", "nombre": "…" } | null,
  "porcentajeCreacion": 21.43, "porcentajeActual": 22.50, "umbralPerdida": 20.00, "horasFalta": 9.00, "horasDictadas": 40.00,
  "fechaCreacionUtc": "…Z",
  "decisionDocente": "PROPONER" | null, "motivoDocente": "…" | null, "fechaDecisionDocenteUtc": "…Z" | null,
  "decisionCoordinador": "RECHAZAR" | null, "motivoCoordinador": "…" | null, "coordinador": { "nombreCompleto": "…" } | null,
  "fechaResolucionUtc": "…Z" | null }

// marca (en ResumenAsistenciaEstudianteResponse de B.2; null si la matrícula no tiene alerta ni revisión)
{ "advertenciaVigente": true, "fechaAdvertenciaUtc": "…Z", "perdidaVigente": true, "fechaPerdidaUtc": "…Z",
  "revision": { "id": "uuid", "estado": "PENDIENTE_DOCENTE", "nombreEstado": "…", "requiereAccionDocente": true,
                "accionesPermitidas": ["MANTENER", "PROPONER"] } | null }
```

`mensaje` de la alerta lo resuelve el backend con `MessageCatalogPort` y el `codigoMensajeUsuario` del tipo (`ALR_010`/`ALR_011`) con `porcentajeActual`, `nombreAsignatura` y el umbral; el cliente no compone textos. Instantes UTC con `Z` (regla del golden path).

### 3.3 Paquetes y clases por capa

```text
BE:application/features/
├── alertainasistencia/
│   ├── consultaralertasestudiante/{primaryports/{ConsultarAlertasEstudianteInputPort, dto, interactor, mapper}, usecase/{…, impl}}
│   ├── marcaralertasleidas/        (MarcarAlertasLeidasInputPort)
│   ├── evaluaralertasautomatico/   (EvaluarAlertasInasistenciaAutomaticoInputPort: lo usa el scheduler)
│   ├── common/{AvisoAlertasInasistenciaService,          -- evaluarYAvisar(grupoId, estudianteGrupoId|null): motor + notificaciones + SSE
│   │          NovedadAlertaInasistencia, ResultadoEvaluacionAlertas}
│   └── exception/AlertaInasistenciaErrorCode
├── revisioncancelacion/
│   ├── consultarrevisionesdocente/ decidirrevision/ consultarrevisionescoordinador/ resolverrevision/
│   ├── common/{AvisoRevisionCancelacionService,           -- notificaciones + SSE por evento (§3.5, §3.6.4)
│   │          ResultadoTransicionRevision, DecisionRevisionCancelacion}
│   └── exception/RevisionCancelacionErrorCode
└── realtime/resolveraudiencia/{ResolverAudienciaRealtimeInputPort, AudienciaRealtimeGrupo(boolean docenteTitular, boolean estudianteActivo, boolean ambitoLectura)}

BE:application/secondaryports/
├── repository/{AlertaInasistenciaRepositoryPort   -- evaluarGrupo, consultarGruposPendientes, consultarAlertasEstudiante, marcarLeidas
│               RevisionCancelacionRepositoryPort} -- consultarDocente, decidir, consultarCoordinador, resolver, consultarDestinatarios
└── realtime/{RealtimeEvent (+ destinatariosUsuario), RealtimeAudienciaQueryPort}

BE:infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/
    {AlertaInasistenciaJpaRepository, RevisionCancelacionJpaRepository, RealtimeAudienciaJpaRepository}
    (lectura de novedadesJSON con el ObjectMapper de infraestructura; entidades de resultado de SP en jpa/entity)

BE:infrastructure/adapter/primary/
├── controller/estudiante/EstudianteAlertasController          (/api/v1/estudiante/alertas/**)
├── controller/docente/DocenteRevisionCancelacionController    (/api/v1/docente/revisiones-cancelacion/**)
├── controller/coordinador/CoordinadorRevisionCancelacionController (/api/v1/coordinador/revisiones-cancelacion/**)
├── realtime/sse/{RealtimeAudienciaPolicy (ampliada), localsse/LocalSseRealtimeStreamGateway (ámbito + canal personal),
│                 controller/RealtimeEventsController (+ /stream/personal), contract/RealtimeStreamGateway (+ subscribePersonal)}
└── scheduler/EvaluacionAlertasInasistenciaScheduler

BE:infrastructure/config/wiring/{AlertaInasistenciaWiringConfiguration, RevisionCancelacionWiringConfiguration}
    + cambios en AsistenciaWiringConfiguration, TomaAsistenciaWiringConfiguration (B.2), EjecutarCierreMasivo y LocalSseRealtimeAdapterConfiguration
```

`RealtimeEvent` (record de `application`) gana el componente final `Set<UUID> destinatariosUsuario` (nunca `null`; vacío por defecto), un constructor secundario con los 7 componentes actuales (todo `new RealtimeEvent(...)` existente sigue compilando), la fábrica `paraDestinatarios(String type, Map<String,Object> payload, Collection<UUID> destinatarios)` y `withObservabilityContext` que lo conserva. `RealtimeEventResponse.from` **no** lo copia: nunca se serializa ([SUPUESTO-C-11]).

Errores DB → HTTP en `DbFailureClassifier`/`DbExceptionTranslator`: `RCN_001` → 404 `RESOURCE_NOT_FOUND`; `RCN_002`, `RCN_003`, `ALR_004` → 400 `VALIDATION_ERROR`; `RCN_004`, `RCN_005`, `RCN_006`, `RCN_012`, `RCN_013`, `RCN_014` → 409 `CONFLICT`; `SEC_002`, `COO_003` → 403; `COO_002`, `PAG_001` → 400; `ALR_002` → 500 (solo en el job, nunca por HTTP).

### 3.4 Motor de alertas: invocación y scheduler

- **`AvisoAlertasInasistenciaService.evaluarYAvisar(UUID grupoId, UUID estudianteGrupoId)`**: llama `AlertaInasistenciaRepositoryPort.evaluarGrupo` y, por cada novedad, avisa (§3.5) y publica (§3.6.4). Captura cualquier `RuntimeException` (incluido un `estadoResultado = 0`), registra `warn` con `correlationId` y el grupo, y no la propaga.
- **Invocación tras escrituras confirmadas** ([SUPUESTO-C-04]): `RegistrarAsistenciasSesionUseCaseImpl` (lote legado; después de publicar `ASISTENCIAS_SESION_ACTUALIZADAS`), `RegistrarAsistenciasTomaUseCaseImpl`, `CerrarTomaAsistenciaUseCaseImpl`, `CerrarTomasVencidasUseCaseImpl` (B.2, por cada toma cerrada) con `estudianteGrupoId = null`; `ResolverSolicitudRevisionAsistenciaUseCaseImpl` solo con acción aprobada, con el `idGrupo` nuevo de la proyección de destinatarios. Se inyecta por constructor adicional (los constructores actuales siguen existiendo con un servicio nulo, patrón de `ResolverSolicitudRevisionAsistenciaUseCaseImpl`). **No** se invoca en `RegistrarAsistenciaPorTokenUseCaseImpl`.
- **`EvaluacionAlertasInasistenciaScheduler`** ([SUPUESTO-C-03]): mismo patrón que `RotacionTokenMatriculaScheduler` (`SmartLifecycle`, hilo daemon `evaluacion-alertas-inasistencia`, `scheduleWithFixedDelay`, `CorrelationIdContext` propio por pasada, nunca `@Scheduled`); `app.alertas-inasistencia.evaluacion.tick` = `PT1M`, `app.alertas-inasistencia.evaluacion.enabled` = `true`. Cada pasada: `consultarGruposPendientes(lote)` → `evaluarYAvisar(grupo, null)` por grupo; un grupo que falla no detiene a los demás. Multi-instancia segura: el cerrojo por grupo y la unicidad están en la BD.
- **Cierre masivo** (`EjecutarCierreMasivoUseCaseImpl`): antes del SP, `consultarGruposPendientes(idPeriodoAcademico)` y `evaluarYAvisar` por grupo (así toda pérdida tiene revisión y aviso); luego el SP, que bloquea con `RCN_012` si queda algo sin resolver ([SUPUESTO-C-10]).

### 3.5 Notificaciones (`NotificacionPort`, outbox)

| Momento | Tipo | Destinatarios | Datos |
| :--- | :--- | :--- | :--- |
| Alerta principal creada ([SUPUESTO-C-05]) | `ALERTA_RIESGO_INASISTENCIA` o `ALERTA_PERDIDA_INASISTENCIA` (`tipoPlantillaEstudiante`) | Estudiante (de `novedadesJSON`) | `estudiante, grupo` ("{nombreGrupo} de {asignatura}"), `porcentaje`, `umbral`/`limite` |
| Revisión creada | `REVISION_CANCELACION_PENDIENTE` | Docente titular (de `novedadesJSON`) | `docente, estudiante, grupo, porcentaje, limite` |
| `PROPONER` | `PROPUESTA_CANCELACION` | Coordinadores competentes | `coordinador, estudiante, grupo, docente, porcentaje, limite, motivo` |
| `APROBAR` | `CANCELACION_APROBADA` | Estudiante y docente | `destinatario, estudiante, grupo, porcentaje, motivo, coordinador` |
| `RECHAZAR` | `CANCELACION_RECHAZADA` | Docente | `docente, estudiante, grupo, motivo, coordinador` |
| `MANTENER` | — (sin notificación; marca en la planilla) | — | — |

Constantes nuevas en `Notificacion` (`TIPO_REVISION_CANCELACION_PENDIENTE`, `TIPO_PROPUESTA_CANCELACION`, `TIPO_CANCELACION_APROBADA`, `TIPO_CANCELACION_RECHAZADA`) y entradas en `PlantillaPorDefectoCatalogo`. El tipo a usar en `PROPONER`/`APROBAR`/`RECHAZAR` lo devuelve el SP (`tipoPlantillaNotificacion` de la transición), no un `switch` en Java. Destinatarios de decisión y resolución: `usp_consultar_destinatarios_revision_cancelacion`. Con el proveedor `log` (defecto) solo se registra; para la demo, `outbox`/`composite` (riesgo R7).

### 3.6 SSE: apertura por ámbito, canal personal y eventos

#### 3.6.1 Canal de grupo `GET /api/v1/realtime/stream?grupoId=` (golden path, comportamiento ampliado)

`LocalSseRealtimeStreamGateway.subscribe(usuarioId, grupoId)` deja de usar `InstitutionalScopePort.canDocenteAccessGrupo` y llama una vez `ResolverAudienciaRealtimeInputPort.resolver(usuarioId, grupoId)` (→ `RealtimeAudienciaQueryPort` → `usp_consultar_audiencias_realtime_grupo`). Audiencias del suscriptor: `DOCENTE_TITULAR` (titular), `ESTUDIANTE_GRUPO` (matrícula `A`), `AMBITO_GRUPO` (coordinador o decano con ámbito sobre el grupo, administrador de la institución). Ninguna → `ForbiddenException` (403, mismo mensaje genérico para inexistente y ajeno). El conjunto se calcula **al suscribirse** (instantánea): un cambio posterior (p. ej. matrícula que pasa a `CI`) aplica al reconectar; los eventos de grupo para `ESTUDIANTE_GRUPO`/`AMBITO_GRUPO` no llevan datos personales, así que la instantánea no filtra datos de otros. Filtro por evento: `payload.grupo == grupoId` **y** `RealtimeAudienciaPolicy.entrega(tipo, audienciasDelSuscriptor, usuarioId, evento.destinatariosUsuario())`.

#### 3.6.2 Canal personal `GET /api/v1/realtime/stream/personal` (nuevo)

`RealtimeStreamGateway.subscribePersonal(usuarioId)`: sin consulta a la BD; entrega solo los eventos cuyo tipo admite la audiencia `DESTINATARIO` **y** cuyo `destinatariosUsuario` contiene al usuario autenticado. Mismo heartbeat (25 s), mismo envelope (`RealtimeEventResponse`), mismo Bearer en cabecera (nunca en la query). Un evento emitido por `POST /realtime/emit` no tiene destinatarios: nunca llega por este canal.

#### 3.6.3 Política de audiencia (extiende la de B.1, igualdad exacta de tipo)

`RealtimeAudienciaPolicy.Audiencia` = `DOCENTE_TITULAR`, `ESTUDIANTE_GRUPO`, `AMBITO_GRUPO`, `DESTINATARIO`. `entrega(tipo, delSuscriptor, usuarioId, destinatarios)` = (`audienciasDe(tipo) ∩ delSuscriptor ≠ ∅`) **o** (`audienciasDe(tipo)` contiene `DESTINATARIO` y `destinatarios` contiene `usuarioId`). Un tipo no listado se sigue entregando solo al titular (regla de B.1).

| Tipo | Audiencias en C | Cambio |
| :--- | :--- | :--- |
| `ASISTENCIAS_SESION_ACTUALIZADAS`, `ASISTENCIAS_TOMA_ACTUALIZADAS` (B.2) | `DOCENTE_TITULAR`, `ESTUDIANTE_GRUPO`, `AMBITO_GRUPO` | + estudiante y ámbito (payload sin datos personales: `grupo, sesion, [toma], totalRegistros`) |
| `SESION_CANCELADA` (B.1) | `DOCENTE_TITULAR`, `ESTUDIANTE_GRUPO`, `AMBITO_GRUPO` | + estudiante y ámbito (F-EST-007; payload sin motivo) |
| `ALERTA_INASISTENCIA` (nuevo) | `DOCENTE_TITULAR`, `DESTINATARIO` | — |
| `REVISION_CANCELACION_CREADA` (nuevo) | `DOCENTE_TITULAR`, `DESTINATARIO` | — |
| `REVISION_CANCELACION_DECIDIDA` (nuevo) | `DOCENTE_TITULAR`, `DESTINATARIO` | — |
| `REVISION_CANCELACION_RESUELTA` (nuevo) | `DOCENTE_TITULAR`, `DESTINATARIO` | — |
| `SOLICITUD_REVISION_RESUELTA` (nuevo, HU042) | `DESTINATARIO` | — |
| `ASISTENCIA_REGISTRADA`, `MATRICULA_QR_ROTADO`, `ESTUDIANTE_MATRICULADO`, `TOMA_ABIERTA`, `TOMA_CERRADA`, `ASISTENCIA_QR_ROTADO`, `ASISTENCIA_QR_REGISTRADA` | `DOCENTE_TITULAR` | sin cambio (los dos `*_QR_ROTADO` llevan token: siguen solo para el titular) |

#### 3.6.4 Eventos nuevos (publicados tras el commit, nunca ante error; `payload.grupo` siempre presente)

| Tipo | Publica | Payload | Destinatarios (`destinatariosUsuario`) |
| :--- | :--- | :--- | :--- |
| `ALERTA_INASISTENCIA` | `AvisoAlertasInasistenciaService` (cada alerta creada, también las no principales) | `grupo, alerta, estudianteGrupo, tipo, porcentajeInasistencia, umbral` | usuario del estudiante |
| `REVISION_CANCELACION_CREADA` | ídem (revisión creada) | `grupo, revision, estudianteGrupo, estado` | usuario del docente titular |
| `REVISION_CANCELACION_DECIDIDA` | `DecidirRevisionCancelacionUseCaseImpl` (si `sinCambios = false`) | `grupo, revision, estudianteGrupo, decision, estado` | docente; + coordinadores competentes si `PROPONER` |
| `REVISION_CANCELACION_RESUELTA` | `ResolverRevisionCancelacionUseCaseImpl` (si `sinCambios = false`) | `grupo, revision, estudianteGrupo, decision, estado, cambioMatricula` | docente y coordinadores competentes; + estudiante si `APROBAR` |
| `SOLICITUD_REVISION_RESUELTA` | `ResolverSolicitudRevisionAsistenciaUseCaseImpl` (F-TRX-005) | `grupo, solicitud, estado` | usuario del estudiante del reclamo |

Ningún payload lleva nombres, correos, motivos ni documentos: el cliente vuelve a consultar por HTTP (el SSE es señal, la API es la verdad, invariante del contrato de eventos).

### 3.7 Seguridad

#### 3.7.1 `SecurityConfig`

`/api/v1/estudiante/alertas/**` → `hasRole(ESTUDIANTE)`; `/api/v1/docente/revisiones-cancelacion/**` → `hasRole(DOCENTE)`; `/api/v1/coordinador/revisiones-cancelacion/**` → `hasRole(COORDINADOR)`; `/api/v1/realtime/**` sigue `authenticated()` (cubre `/stream/personal`); `POST /api/v1/realtime/emit` sigue solo `ADMINISTRADOR`. El administrador **no** entra en las rutas `coordinador/*` (DEC-022 §2).

#### 3.7.2 Catálogo de accesos (`GestioAsistenciaBackend/infra/security-baseline/access-catalog.json`) — rutas nuevas (DEC-037/038)

```json
{"method": "GET",   "path": "/api/v1/estudiante/alertas", "roles": ["ESTUDIANTE"], "access": "ROLES", "ownership": "Solo las alertas de las matriculas del estudiante autenticado (SP usp_consultar_alertas_estudiante)."},
{"method": "PATCH", "path": "/api/v1/estudiante/alertas/lectura", "roles": ["ESTUDIANTE"], "access": "ROLES", "ownership": "Solo marca alertas propias; ids ajenos se ignoran (SP)."},
{"method": "GET",   "path": "/api/v1/docente/revisiones-cancelacion", "roles": ["DOCENTE"], "access": "ROLES", "ownership": "Solo revisiones de grupos donde el docente es titular (SP)."},
{"method": "PATCH", "path": "/api/v1/docente/revisiones-cancelacion/{revisionId}", "roles": ["DOCENTE"], "access": "ROLES", "ownership": "Docente titular del grupo de la revision (SP; ajena = 404)."},
{"method": "GET",   "path": "/api/v1/coordinador/revisiones-cancelacion", "roles": ["COORDINADOR"], "access": "ROLES", "ownership": "Solo estudiantes con EstudiantePrograma en un programa del coordinador y del grupo (SP, DEC-020)."},
{"method": "PATCH", "path": "/api/v1/coordinador/revisiones-cancelacion/{revisionId}", "roles": ["COORDINADOR"], "access": "ROLES", "ownership": "Coordinador activo del programa del estudiante (SP; ajena = 404; no resuelve su propia propuesta)."},
{"method": "GET",   "path": "/api/v1/realtime/stream/personal", "roles": ["ADMINISTRADOR", "DECANO", "COORDINADOR", "DOCENTE", "ESTUDIANTE"], "access": "AUTHENTICATED", "ownership": "Solo eventos con el usuario autenticado como destinatario explicito."}
```

**Modificada** (solo el texto de `ownership`, la ruta ya está registrada para los 5 roles): `GET /api/v1/realtime/stream` → "Ambito al suscribirse (SP): docente titular, estudiante con matricula activa, coordinador o decano con ambito sobre el grupo, administrador de la institucion; entrega por tipo de evento segun RealtimeAudienciaPolicy." Sin cambios: `GET /api/v1/docente/grupos/{grupoId}/resumen-asistencia` (B.2) y `POST /api/v1/admin/cierre-masivo`.

Tras mezclar, el responsable debe ejecutar desde `GestioAsistenciaBackend` (Python de Windows): `python -X utf8 -I infra\security-baseline\scripts\provision_asistencias.py pdp`, luego `… verify` y `… verify-decisions` (bloqueo **B-01**). Hasta entonces las 7 rutas nuevas responden 403 `NO_APPLICABLE_POLICY` en pantalla; los gates de código no dependen de esto. La apertura del canal de grupo **sí** funciona sin el PDP (ruta ya registrada para los 5 roles).

### 3.8 OpenAPI y contratos WORM

- **`openapi-golden-path.yaml` 1.5.0** (sobre la 1.4.0 de B2, DEC-032; si B2 aún no publicó, C espera): solo cambia la `description` de `GET /api/v1/realtime/stream` ("el gateway resuelve el ámbito del rol al suscribirse —titular, estudiante con matrícula activa, coordinador/decano del grupo, administrador de la institución— y entrega cada tipo según su audiencia; sin ámbito, 403") y una línea en `info.description`. `x-roles: [AUTHENTICATED]`, `GrupoIdQuery` (sigue obligatorio en esta ruta) y `RealtimeEventResponse` no cambian. Las rutas nuevas no entran al golden path (springdoc y `HTTP_AS_IS_MATRIX.md`).
- **`BACKEND_GOLDEN_PATH_CONTRACT.md`** fila 6: "el gateway exige titularidad docente sobre `grupoId`" → "el gateway resuelve el ámbito por rol (SP `usp_consultar_audiencias_realtime_grupo`) y filtra por tipo con `RealtimeAudienciaPolicy`". Nada más.
- **`REALTIME_EVENT_CONTRACT.md`** (Infra, WORM) y `REALTIME_EVENT_STANDARD.md` (backend): tabla AS-IS con los 5 tipos nuevos y la tabla de audiencias de §3.6.3; el invariante "`grupoId` obligatorio" pasa a "`grupoId` obligatorio en el canal de grupo; el canal personal no recibe `grupoId` y solo entrega eventos con destinatario explícito; los destinatarios son metadato de enrutamiento y nunca se serializan".
- Se regeneran los `.sha256` de los tres en Infra y backend en el commit de contrato, después de la aprobación 9.2. Pruebas que cambian por este cambio formal (sin relajar): `OpenApiGoldenPathConformanceTest` (versión), las de `LocalSseRealtimeStreamGatewayTest`/`RealtimeEventsController*Test` que hoy esperan 403 para el estudiante o el coordinador **con ámbito** (pasan a esperar 200 y se añaden los 403 de los usuarios **sin** ámbito), y `RealtimeAudienciaPolicyTest`.

### 3.9 Pruebas RED del backend

| Grupo | Pruebas | Criterio |
| :--- | :--- | :--- |
| Unitarias de casos de uso (100 % líneas y ramas en `alertainasistencia`, `revisioncancelacion`, `realtime/resolveraudiencia`) | `AvisoAlertasInasistenciaServiceTest`: sin novedades no avisa; alerta principal → plantilla del tipo al estudiante; no principal → sin correo pero con evento; revisión → `REVISION_CANCELACION_PENDIENTE` al docente + `REVISION_CANCELACION_CREADA`; fallo del repositorio, de la notificación o del publicador no propaga; destinatarios en el metadato y no en el payload. `Decidir…`/`Resolver…UseCaseImplTest`: cada código traducido, `sinCambios` sin eventos ni correos, `PROPONER` → coordinadores, `APROBAR` → estudiante y docente + `cambioMatricula`, `RECHAZAR` → docente, `MANTENER` sin correo. Casos de uso de tomas, lote, reclamo y cierre: llaman al servicio solo tras éxito y con los argumentos de [SUPUESTO-C-04]; el registro por token **no** lo llama | JaCoCo del bundle ≥ 80/70; 100 % en los paquetes nuevos |
| Scheduler | `EvaluacionAlertasInasistenciaSchedulerTest`: arranque y parada, una pasada con 3 grupos (uno falla y los otros siguen), `CorrelationIdContext` por pasada, deshabilitado no programa | — |
| SSE | `RealtimeAudienciaPolicyTest` (tabla §3.6.3, igualdad exacta, no listado → titular, `DESTINATARIO` requiere pertenencia); `LocalSseRealtimeStreamGatewayTest`: los 5 roles con ámbito se suscriben, sin ámbito → 403, el estudiante recibe `ASISTENCIAS_SESION_ACTUALIZADAS` y `SESION_CANCELADA` pero **no** `ALERTA_INASISTENCIA` de otro estudiante ni `ASISTENCIA_QR_ROTADO`, el coordinador recibe eventos de grupo pero no `ALERTA_INASISTENCIA`; canal personal: solo eventos con el usuario como destinatario, nunca los de `/emit`; `RealtimeEventResponse` serializado **no** contiene `destinatariosUsuario`; heartbeat intacto | — |
| Controladores (`@WebMvcTest` + seguridad) | Forma exacta de cada respuesta; 400/401/403 (rol equivocado)/404/409; `PATCH` con cuerpo extra → 400; matriz `SecurityConfig` ↔ `access-catalog.json` (prueba de consistencia existente) | — |
| ArchUnit | `application` sin `infrastructure`/JPA/JDBC; controladores solo dependen de `InputPort`; el gateway usa `ResolverAudienciaRealtimeInputPort`, no repositorios; scheduler solo llama `InputPort` | Reglas existentes + nuevas |
| Contrato SP (`-Pintegration`) | `SqlStoredProcedureContractIT`: nombre, parámetros y columnas de los 10 SP nuevos y de los 3 modificados; lectura de `novedadesJSON`; `GoldenPathSqlStoredProcedureContractIT` verde | — |
| E2E por API (`INFRA:scripts/tests/test_culm001_c.ps1`, tokens PKCE DEC-008) | Lote con faltas sobre sesión vencida del fixture → alerta del estudiante → decisión del docente → resolución del coordinador → matrícula `CI` → lote con ese estudiante rechazado; stream del estudiante y del coordinador abre (200) y el de un usuario sin ámbito da 403 | Integrado en `test_all_hus.ps1`; las rutas nuevas fallan con 403 mientras siga B-01 (documentado, no se relaja la aserción) |

---

## 4. Frontend (`GestioAsistenciaFrontend`)

### 4.1 Reglas comunes

Standalone + `changeDetection: ChangeDetectionStrategy.OnPush`; `input()`/`output()`/`model()`; estado con `signal`/`computed`/`effect` (`onCleanup`). **Sin `setInterval`, `setTimeout` recursivo, `interval()` ni `debounceTime`** en lo nuevo o tocado: la reactividad viene del SSE y de las respuestas HTTP (`switchMap` cancela recargas solapadas). Textos de negocio, errores y éxitos: `mensaje`/`message`/`mensajeUsuario` del backend. Solo tokens de `styles.css` (`lint:tokens`); estados de alerta y revisión por un único `InasistenciaMarcaBadgeComponent` (`shared/components/inasistencia-marca-badge/`) para que E lo ajuste en un sitio. Móvil primero en todo lo del estudiante (360–414 px, sin scroll horizontal, objetivos ≥ 44 × 44 px, tarjetas en `< md`); bandejas del docente y del coordinador responsive (tabla en `md+`, tarjetas en `< md`). Interruptor `features.cancelacionInasistenciaEnabled` (`environment.ts`, `true`): oculta menús, campana y marcas si se retira la funcionalidad.

### 4.2 Modelos, servicios y tiempo real

| Archivo | Contenido |
| :--- | :--- |
| `FE:core/models/alerta-inasistencia.model.ts` (nuevo) | `TipoAlerta = 'ADVERTENCIA' \| 'PERDIDA'`, `EstadoAlerta = 'VIGENTE' \| 'SUPERADA'`, `AlertaInasistencia` (forma exacta de §3.2), `MarcarLecturaResponse` |
| `FE:core/models/revision-cancelacion.model.ts` (nuevo) | `DecisionDocente = 'MANTENER' \| 'PROPONER'`, `DecisionCoordinador = 'APROBAR' \| 'RECHAZAR'`, `RevisionCancelacion`, `MarcaInasistencia`, filtros |
| `FE:core/services/alerta-inasistencia.service.ts` (nuevo) | `consultar(filtro)`, `contarNoLeidas()` (`soloNoLeidas=true&tamano=1` → `totalElementos`), `marcarLeidas(ids)` |
| `FE:core/services/revision-cancelacion.service.ts` (nuevo) | `consultarDocente(filtro)`, `decidir(id, decision, motivo)`, `consultarCoordinador(filtro)`, `resolver(id, decision, motivo)`, `contarPendientesDocente()`, `contarPendientesCoordinador()` |
| Servicio de resumen del docente (B.2) | Mapea `marca` |
| `FE:core/realtime/contract/realtime-transport.ts` | `RealtimeSubscriptionScope = { tipo: 'GRUPO'; grupoId: string } \| { tipo: 'PERSONAL' }`; `REALTIME_TRANSPORT_FACTORY` (crea instancias independientes) |
| `FE:core/realtime/adapter/sse/fetch-sse-realtime-transport.ts` | URL por alcance: `/realtime/stream?grupoId=` o `/realtime/stream/personal`; misma política de reconexión, Bearer en cabecera, nunca token en la URL |
| `FE:core/realtime/realtime.service.ts` | Sin cambio de API (`startForGroup`, `listenType`, `stop`) |
| `FE:core/realtime/personal-realtime.service.ts` (nuevo) | Segunda instancia de transporte con alcance `PERSONAL`: `start()`, `stop()`, `listenType()`; se inicia en `DashboardLayoutComponent` al haber sesión y se detiene al cerrar sesión o destruir el layout |
| `FE:core/realtime/avisos/avisos-realtime.store.ts` (nuevo) | Signals `alertasNoLeidas`, `revisionesPendientes`; escucha el canal personal (`ALERTA_INASISTENCIA`, `REVISION_CANCELACION_*`, `SOLICITUD_REVISION_RESUELTA`), **deduplica por `eventId`** ([SUPUESTO-C-18]), recuenta por HTTP y muestra un toast con el `mensaje` de la alerta más reciente (`consultar` página 1) |
| `FE:core/realtime/model/realtime-event.model.ts` | Tipos nuevos de §3.6.4 con payloads tipados (sin `any`) |
| `FE:core/interceptors/mock-backend.interceptor.ts` | Si hay modo mock, respuestas con la forma exacta de §3.2 |

### 4.3 Estudiante (móvil primero; cierra F-EST-S05 y F-EST-007)

- **Campana** (`shared/components/avisos-campana/avisos-campana.component.ts`): en la cabecera móvil y en la barra lateral de escritorio del `DashboardLayoutComponent`; contador `alertasNoLeidas` (badge con `aria-label` que incluye el número), botón ≥ 44 px; abre una hoja inferior en móvil y un panel en escritorio con las 5 alertas más recientes y "Ver todas".
- **Página `/app/estudiante/alertas`** (`features/student/student-alerts/student-alerts.component.ts`, nueva): lista de tarjetas (icono y badge por tipo, `mensaje` del backend, asignatura y grupo, `porcentajeActual` de `umbralPerdida`, fecha local, "Ver materia" → detalle de la materia); filtro "No leídas / Todas"; `PaginationComponent`; al mostrar alertas no leídas llama `marcarLeidas` con sus ids y actualiza el contador. Vacío y error con el mensaje del backend.
- **Detalle de la materia** (`student-course-detail`): `effect` con `RealtimeService.startForGroup(grupoId)`; ante `ASISTENCIAS_SESION_ACTUALIZADAS`, `ASISTENCIAS_TOMA_ACTUALIZADAS` o `SESION_CANCELADA` recarga sesiones e indicadores; `stop` al salir. Muestra la matrícula `CI` como "Cancelado por inasistencia" (HU059) sin acciones de reclamo.
- **Reclamos** (`student-claims`): ante `SOLICITUD_REVISION_RESUELTA` (canal personal) recarga la lista (HU042, F-TRX-005).

### 4.4 Docente

- **Planilla** (`teacher-grupo-sabana.component.ts`, ya alimentada por el resumen de B.2): columna "Seguimiento" con `InasistenciaMarcaBadgeComponent` (Riesgo / Pérdida: decide / Mantenido / Propuesto a coordinación / Rechazado por coordinación / Cancelado por inasistencia); si `marca.revision.accionesPermitidas` no está vacío, botón "Decidir" que abre `RevisionDecisionModalComponent`. En el canal de grupo, ante `ALERTA_INASISTENCIA` o `REVISION_CANCELACION_*` recarga el resumen. Las marcas de advertencia no generan notificación al docente (solo marca, 3.5 [SUPUESTO]).
- **Bandeja `/app/docente/revisiones-cancelacion`** (`features/teacher/teacher-revisiones-cancelacion/`, nueva): filtro "Pendientes de mi decisión / Todas" (`soloPendientes`) y grupo; tarjetas en móvil, tabla en escritorio con estudiante, asignatura y grupo, porcentaje actual y de creación, estado y decisiones previas (motivos visibles). `RevisionDecisionModalComponent` (`components/`): dos opciones según `accionesPermitidas` ("Mantener al estudiante" / "Proponer cancelación"), `textarea` de motivo obligatorio con contador de caracteres (sin límites numéricos en el cliente, [SUPUESTO-C-19]), confirmación explícita al proponer; muestra el `mensajeUsuario` o el error del backend (`RCN_003`, `RCN_006`, `RCN_013`) y cierra. Recarga ante `REVISION_CANCELACION_*` del canal personal.
- **Menú** con badge `revisionesPendientes`.

### 4.5 Coordinador

- **Bandeja `/app/coordinador/revisiones-cancelacion`** (`features/coordinator/coordinator-revisiones-cancelacion/`, nueva): filtros "Pendientes de resolver / Todas", programa (selector con sus programas; obligatorio solo si el backend responde `COO_002`) y grupo; cada fila con estudiante, programa, docente, asignatura y grupo, porcentaje actual, motivo del docente. `RevisionResolucionModalComponent`: "Aprobar cancelación" / "Rechazar", motivo obligatorio, confirmación explícita al aprobar ("el estudiante quedará cancelado por inasistencia"); mensajes del backend (`RCN_006`, `RCN_014`, `RCN_004` si otro coordinador ya resolvió). Sin acceso a editar asistencias. Recarga ante `REVISION_CANCELACION_DECIDIDA`/`RESUELTA` del canal personal. Menú con badge.

### 4.6 Coordinador, decano y administrador: SSE en las vistas de grupo (cierra F-TRX-006 / F-DEC-012)

- `coordinador/asistencias` (grupo seleccionado) y `decano/grupos/:grupoId`: `startForGroup(grupoId)` y recarga ante `ASISTENCIAS_SESION_ACTUALIZADAS`, `ASISTENCIAS_TOMA_ACTUALIZADAS` y `SESION_CANCELADA`; `stop` al salir. Los KPIs agregados no se suscriben (no hay evento institucional en C; se recargan al navegar).

### 4.7 Rutas y menú (`app.routes.ts`, `dashboard-layout.component.ts`)

`estudiante/alertas` (rol ESTUDIANTE), `docente/revisiones-cancelacion` (DOCENTE), `coordinador/revisiones-cancelacion` (COORDINADOR), con `authGuard` + `roleGuard` como las existentes; entradas de menú detrás de `features.cancelacionInasistenciaEnabled`.

### 4.8 Pruebas RED del frontend (`npm run test:ci`, `npm run verify`)

- Servicios: URL, método, parámetros y cuerpo exactos (`{ alertas }`, `{ decision, motivo }`), mapeo de respuestas, paso del `message` del backend en 400/403/404/409.
- Transporte: alcance `PERSONAL` usa `/realtime/stream/personal` sin query; `GRUPO` sin cambio; nunca token en la URL; dos instancias independientes (iniciar la personal no corta la de grupo).
- `AvisosRealtimeStore`: deduplicación por `eventId`; recuento solo por evento o acción (spy: ninguna llamada HTTP sin evento); toast con el texto del backend.
- `avisos-campana`, `student-alerts`: OnPush, badge con número accesible, marcar leídas al mostrar, vacío/error, tarjetas a 375 px sin scroll horizontal (spec de clases responsive), objetivo táctil ≥ 44 px.
- Planilla: badges por cada estado de `marca`; "Decidir" solo con `accionesPermitidas`; recarga por `ALERTA_INASISTENCIA`/`REVISION_CANCELACION_*` del canal de grupo.
- Modales de decisión y resolución: motivo obligatorio, opciones según `accionesPermitidas`, confirmación al proponer/aprobar, mensajes del backend, sin límites numéricos quemados.
- Suscripción de estudiante, coordinador y decano en sus vistas de grupo: `startForGroup` al entrar, `stop` al salir, recarga por los 3 tipos.
- Anti-polling: `spyOn(window, 'setInterval')`/`setTimeout` sin llamadas en los componentes y servicios nuevos (el transporte conserva su temporizador de reconexión existente, que no es sondeo).
- `npm run coverage:realtime:check` ≥ 90 % líneas / 80 % ramas con los cambios de `core/realtime/**`.

---

## 5. Documentación, orden de integración, ramas y commits

### 5.1 Documentación

- `INFRA:docs/user-stories/HU-CATALOG.md`: HU026C con los objetos reales (motor, SP de alertas, endpoints, campana) y estado tras AUDIT; HU042 (evento SSE añadido); HU041 (marcas); HU047 (aviso SSE al estudiante); HU174 (regla nueva del cierre).
- `INFRA:docs/baseline/TECHNICAL_DEBT.md`: (a) notificaciones de alertas de mejor esfuerzo sin reintento previo al outbox (la alerta queda visible en la campana); (b) SSE `local-sse` de una JVM y audiencias por instantánea al suscribirse; (c) bandeja del decano y vista del administrador diferidas; (d) evaluación periódica por marca de agua (si el motor falla tras una corrección de una sesión antigua, el cruce espera a la siguiente sesión vencida).
- Contratos WORM de §3.8 y addendum de BD de §2.12 (con `.sha256` regenerados tras 9.2).
- `GestioAsistenciaBackend/docs/contracts/HTTP_AS_IS_MATRIX.md` (rutas nuevas), `docs/realtime-sse-architecture.md` y `docs/rutas-por-rol.md` del workspace (canales y rutas nuevas).
- Work item: `RED.md`, `AUDIT-PANTALLA.md` (recorrido en escritorio y en `resize_window` móvil 375 × 812 para el estudiante), `CLOSURE.md`; `PRS.md` y `ESTADO.md` del work item.

### 5.2 Orden de integración

Rama `feature/CULM-001-C-cancelacion-inasistencia` en los 4 repos, desde `integracion/CULM-001` **con A, B.1, B.2 y B2 mezclados** ([SUPUESTO-C-02]). Orden por capa:

1. **DB**: catálogos y tablas + FKs → funciones → vistas → motor y consultas → decisión y resolución → audiencias → cambios de §2.6 → semillas y permisos → migración 19 → pruebas (§2.13) → manifiesto post-freeze (tras 9.2). Gate: `infra.ps1 db-test` sin fallos nuevos y `freeze-manifest.ps1 -Mode Verify`.
2. **Backend**: `RealtimeEvent` + política + gateway + canal personal → puertos y adaptadores → casos de uso y servicios de aviso → invocación desde lote/tomas/reclamo/cierre → scheduler → controladores, `SecurityConfig`, `access-catalog.json` → contratos. Gate: `mvnw verify` (con `JAVA_TOOL_OPTIONS` de `ESTADO.md`) e IT de C con `-Pintegration`.
3. **Frontend**: transporte y servicio personal → store y campana → alertas del estudiante → planilla y bandeja del docente → bandeja del coordinador → suscripciones de grupo de estudiante/coordinador/decano. Gate: `npm run verify`.
4. **Infra**: contratos (golden path 1.5.0, eventos, addendum) con `.sha256`, `test_culm001_c.ps1` y `test_all_hus.ps1`, catálogo de HUs y deuda. Gate: `infra.ps1 verify` y `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001`.
5. **PDP**: instrucción al responsable (§3.7.2, B-01). **AUDIT** en pantalla con los 5 roles cuando el PDP esté provisionado.

PRs hacia `integracion/CULM-001`: Backend en `alejovh12/AsistenciasUCO`, DB en `johnjduque/gestion-asistencia-db` (DEC-002), Frontend en `shesho22/AsistenciasUCO-Frontend`, Infra en `AsistenciasUCO/AsistenciasUCO-Infra`; cada PR enlaza este CONTRACT y sus revisiones.

### 5.3 Commits (Conventional Commits en español, imperativo, ≤ 72 caracteres, atómicos por capa; pie `Refs: HU026C` + `Refs: CULM-001`)

- **DB:** `feat(db/tables): agregar alertas y revisiones de cancelacion por inasistencia` · `feat(db/views): exponer alertas, revisiones y marcas de inasistencia` · `feat(db/sp): evaluar alertas de inasistencia por horas en el grupo` · `feat(db/sp): consultar y marcar alertas del estudiante` · `feat(db/sp): decidir revision de cancelacion por el docente titular` · `feat(db/sp): resolver revision de cancelacion por el coordinador` · `feat(db/sp): resolver audiencias realtime por ambito del usuario` · `refactor(db/sp): aplicar umbral por horas y bloqueo al cierre masivo` · `feat(db/sp): agregar marcas de inasistencia al resumen del docente` · `feat(db/seed): sembrar catalogos, parametros, mensajes y plantillas de C` · `feat(db/migrations): agregar migracion 19 de cancelacion por inasistencia` · `test(db): cubrir alertas, revisiones, ambito mixto y cierre masivo` · `docs(db/contracts): registrar manifiesto post-freeze de CULM-001 C`
- **Backend:** `test(backend): agregar pruebas RED de alertas y revisiones de cancelacion` · `feat(backend/realtime): abrir el stream por ambito y agregar canal personal` · `feat(backend/ports): agregar puertos de alertas y revisiones` · `feat(backend/adapter): ejecutar los SP de alertas, revisiones y audiencias` · `feat(backend/usecase): evaluar alertas y avisar tras registrar asistencia` · `feat(backend/usecase): decidir y resolver revisiones de cancelacion` · `feat(backend/usecase): publicar SSE al resolver reclamos HU042` · `feat(backend/scheduler): evaluar alertas al vencer las sesiones` · `feat(backend/controller): exponer alertas y bandejas de revisiones` · `feat(backend/security): registrar rutas de C en el catalogo de acceso` · `docs(backend): publicar golden path 1.5.0 y contrato de eventos de C`
- **Frontend:** `test(frontend): agregar specs RED de alertas y revisiones` · `feat(frontend/realtime): agregar canal personal y avisos en tiempo real` · `feat(frontend/estudiante): mostrar campana y alertas de inasistencia` · `feat(frontend/docente): marcar riesgo y decidir revisiones en la planilla` · `feat(frontend/docente): agregar bandeja de revisiones de cancelacion` · `feat(frontend/coordinador): resolver propuestas de cancelacion` · `feat(frontend/realtime): suscribir vistas de grupo de estudiante y decano`
- **Infra:** `docs(contracts): publicar golden path 1.5.0 y eventos de cancelacion` · `test(scripts): agregar flujo de cancelacion a test_all_hus` · `docs(hus): actualizar HU026C, HU042 y HU174 en el catalogo` · `docs(baseline): registrar deudas del paquete C`

---

## 6. Riesgos, rollback y puntos abiertos

### 6.1 Riesgos

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| R1 | C depende de que B.2 y B2 estén mezclados (horas, `ufn_programas_grupo`, `uv_resumen_*` sin `idPrograma`) y B.2 aún no tiene backend ni frontend | [SUPUESTO-C-02]: el RED de C espera la integración; el contrato no usa nada que B/B2 no hayan congelado |
| R2 | Bloqueo B-01: las 7 rutas nuevas dan 403 en pantalla hasta provisionar el PDP | Instrucción exacta en §3.7.2; el canal de grupo funciona sin PDP; los gates de código no dependen |
| R3 | El primer pase del job tras el despliegue notifica de golpe a todos los estudiantes ya por encima del umbral | Interruptor `ALERTA_INASISTENCIA/HABILITADA`; el resultset de la migración dimensiona el volumen; lote de 50 grupos por minuto |
| R4 | El cierre masivo queda bloqueado si un docente o coordinador no decide | Mensaje con el total (`RCN_012`); el administrador ve qué falta por los listados; decisión a confirmar ([SUPUESTO-C-10]) |
| R5 | Concurrencia: motor desde el job y desde una escritura sobre el mismo grupo; resolución concurrente con retiro HU051 | Cerrojo por grupo en `EvaluacionAlertaGrupo`, índices únicos, orden de bloqueos de §2.0; prueba C-DB-50 |
| R6 | Fuga de datos por SSE (estudiante que recibe la alerta de otro, coordinador que ve un estudiante de otro programa) | Eventos personales solo por destinatario explícito calculado en la BD; eventos de grupo sin datos personales; pruebas de gateway y política; destinatarios no serializados |
| R7 | Con el proveedor de notificaciones `log` (defecto) no llegan correos | En la demo, `outbox`/`composite`; la campana y las bandejas leen de la BD |
| R8 | Cambio del record `RealtimeEvent` (application) | Constructor secundario compatible; pruebas existentes sin cambio salvo las de §3.8 |
| R9 | Coste del motor tras cada lote (lee `uv_resumen_*` del grupo) | Un grupo por llamada (≤ cupo), fuera de la transacción del lote; se mide en el IT y se registra p95 |
| R10 | Plantillas `ALERTA_*` editadas por un administrador no se actualizan | Regla de §2.9: solo si coinciden con el texto por defecto; queda en el log de la semilla |

### 6.2 Rollback

- **Sin despliegue:** `ALERTA_INASISTENCIA/HABILITADA = false` (el motor no escribe; bandejas y alertas existentes siguen consultables), `app.alertas-inasistencia.evaluacion.enabled = false` (job detenido), `features.cancelacionInasistenciaEnabled = false` (oculta menús, campana y marcas). La apertura del SSE se revierte con el PR del backend (vuelve la regla "solo titular").
- **Por capas:** revertir los PRs en orden Frontend → Backend → DB y ejecutar `19_culm001_c_cancelacion_inasistencia_down.sql` (archiva alertas, revisiones e historial; no reactiva matrículas `CI`, [SUPUESTO-C-17]; restaura el cierre masivo de B.2). Backup `COPY_ONLY` antes de cada `up` en el entorno compartido (patrón de `ESTADO.md`). Los `.sha256` de los contratos se restauran con el revert del commit de Infra.

### 6.3 Diferido (post 2026-11-13)

Bandeja del decano (solo lectura) y vista institucional del administrador; reintento de notificaciones de alertas; evento institucional para refrescar KPIs; reactivación administrada de una matrícula `CI` (hoy por el conducto regular externo).

### 6.4 Puntos que el orquestador debe confirmar antes de congelar

[SUPUESTO-C-04] (sin motor tras el token), [SUPUESTO-C-06] (aviso de pérdida al estudiante y plantilla nueva para el docente), [SUPUESTO-C-07] (re-proponer tras `RECHAZADA`), [SUPUESTO-C-10] (cierre masivo que bloquea en lugar de cancelar por umbral) y [SUPUESTO-C-11] (ruta nueva del canal personal y cambio del invariante del contrato de eventos).
