# CULM-001 · Paquete B — CONTRACT (tomas por horas, QR de asistencia, ventana de sesión, sesión cancelada y festivos)

> **Estado:** BORRADOR v2, corregido tras `REVIEW-1.md` (20 objeciones, 9 bloqueantes; respuesta punto por punto en §8) y las decisiones del orquestador del 2026-11-07. Pendiente de la segunda pasada de la revisión 9.2. Nada se congela ni se firma (`.sha256`) antes de "sin objeciones" y del registro de DEC-024 (`DEC-024-propuesta.md`).
> **Fecha:** 2026-11-06 (v1) · 2026-11-07 (v2). **Fase SDD:** 02 CONTRACT (el RED empieza solo después de la revisión).
> **Fuentes:** `PROMPT_FABLE_CULMINACION.md` §3.2, §3.3, §3.4, §3.7 y §3.10; `DECISIONES.md` DEC-011 a DEC-018 (cerradas, no se reabren); `RESEARCH-MODELO-ACTUAL.md`; `FINDINGS-docente|estudiante|coordinador.md`; `AGENTS.md` §3.3.
> **Convenciones de ruta:** `DB:` = `GestioAsistenciaDB/`, `BE:` = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, `BE-T:` = `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`, `FE:` = `GestioAsistenciaFrontend/src/app/`, `INFRA:` = `AsistenciasUCO-Infra/`. Todos bajo `C:\Proyectos\GestionAsistencia-CULM001\`.

---

## 0. Supuestos aplicados y precisiones de diseño

Las decisiones DEC-011..DEC-018 se aplican tal cual. Lo que sigue son detalles que esas decisiones no fijan; cada uno es la opción más conservadora según §9.3 del prompt y queda marcado para el revisor.

| ID | Supuesto / precisión | Motivo |
| :--- | :--- | :--- |
| [SUPUESTO-B-01] | **Numeración definitiva (DEC-028):** migraciones B.1 = `15_culm001_b1_*` (sesión cancelada, festivos, ventana) y B.2 = `16_culm001_b2_*` (tomas, QR); semillas de B `34_*`, `35_*`, `36_*`. A usa las migraciones 13 y 14; B2 (asignaturas N:M) usa 17 y 18 con el prefijo `culm001_b2nm`. Prefijos de archivos, pruebas y fixtures: `culm001_b1` para B.1 y `culm001_b2` para B.2. **Ningún filtro, script ni registro de pruebas de B usa el comodín `culm001_b2*`** (capturaría `culm001_b2nm`): se listan los nombres exactos. | DEC-028 del orquestador |
| [SUPUESTO-B-02] | Los estados, modos y tipos se distinguen en los SP por **columnas bandera de catálogo** con índice único (`ModoTomaAsistencia.usaCodigoQr`, `EstadoTomaAsistencia.estaAbierta`, `TipoCancelacionSesion.esAutomatica`), nunca por literales de código. Los índices filtrados de "uno abierto/activo" usan `fechaCierreUtc IS NULL`, no un literal de estado. | Cero datos quemados sin la excepción técnica de HU176B |
| [SUPUESTO-B-03] | Los códigos de `RazonCausa` (`AN`, `SJC`, `EX`) se leen en los SP **nuevos** desde parámetros `ASISTENCIA/CODIGO_RAZON_*`. Las vistas reescritas (`uv_resumen_*`, `uv_asistencia_sesion_horas`) conservan los literales de `RazonCausa` que ya usan hoy (catálogo cerrado de ids fijos; leer parámetros por fila degrada el plan). | Comportamiento actual; se registra deuda TD nueva (§5) |
| [SUPUESTO-B-04] | Una toma implícita (creada por el lote legado `POST /asistencias/lote` o por el backfill) nace **CERRADA** (`esImplicita = 1`). Las siguientes escrituras del lote legado van a la toma ABIERTA si la hay o, si no, a la última toma (corrección del docente). | Evita tomas abiertas huérfanas y conserva "una toma = comportamiento actual" (DEC-013) |
| [SUPUESTO-B-05] | Precisión de DEC-012 (se registra como **DEC-024**, texto exacto en `DEC-024-propuesta.md`, antes de congelar): `horasDictadas` = Σ `horasSesion` de las sesiones vencidas, con registro (`Asistencia` o `TomaAsistencia`) y no canceladas, sin mirar el estado de la toma (una sesión con cabecera `Asistencia` y 0 tomas aporta sus `horasSesion` completas como `horasSinRegistro`). Una toma ABIERTA en una sesión vencida la cierra el job (§3.5); el cálculo no depende de que el job haya corrido. | El denominador no puede depender de un proceso asíncrono |
| [SUPUESTO-B-06] | `tieneRegistroAsistencia` (en `uv_cumplimiento_sesion_grupo`) pasa a ser "existe `Asistencia` **o** existe `TomaAsistencia`". Una toma QR abierta y cerrada sin lecturas ni marcación cuenta como sesión ejecutada. | El docente sí ejecutó la toma |
| [SUPUESTO-B-07] | Máximo de tomas por sesión: `TOMA_ASISTENCIA/MAXIMO_TOMAS_POR_SESION = 4`. Abrir una toma nueva exige que no haya otra ABIERTA en la sesión. | Acota el reparto de horas |
| [SUPUESTO-B-08] | Cerrar una toma: si `marcarAusentes` llega `NULL` se aplica el valor del modo (`ModoTomaAsistencia.marcaAusentesAlCerrar`: MANUAL = 0, QR = 1). Después de cerrar, el docente puede seguir marcando faltantes en esa toma mientras dure la ventana `[inicio − TOLERANCIA, fin + MARGEN)`; vencida la ventana, la única vía es el reclamo (HU010). | DEC-013 + §3.4 ("los que no se marquen quedan como ausentes") |
| [SUPUESTO-B-09] | El job de rotación QR también **cierra** las tomas cuya ventana venció (`usp_cerrar_tomas_vencidas`), aplicando `marcaAusentesAlCerrar` del modo. | "o vencer la ventana" (§3.4) |
| [SUPUESTO-B-10] | HU047 (decisión del orquestador sobre NB-7): se puede cancelar una sesión **futura** o una sesión **sin asistencia registrada** (sin `Asistencia` ni `TomaAsistencia`). Una sesión con asistencia no se cancela: si su ventana no ha terminado → `SES_012`; si ya terminó (`SYSUTCDATETIME() >= fin + MARGEN_RETARDO_MINUTOS`) → `SES_016` ("la corrección se hace por reclamo"). No hay "des-cancelar" en B. Una cancelación por un festivo que desaparece en una recarga **no se revierte**: la sesión se reporta. | Sin pérdida de datos; lo dictado con asistencia solo se corrige por reclamo |
| [SUPUESTO-B-11] | `usp_internal_aplicar_festivos_grupo` cancela por festivo solo sesiones **sin** `Asistencia` ni `TomaAsistencia`; con `@soloFuturas = 1` (mantenimiento de grupos ya creados) solo las de `fechaHoraInicio > SYSUTCDATETIME()`; la generación (`usp_generar_sesiones_grupo_v2`) y la precarga usan `@soloFuturas = 0` (toda sesión nueva en festivo nace cancelada). | §3.7 [SUPUESTO] del prompt + "sesión en festivo creada cancelada" |
| [SUPUESTO-B-12] | Límites de intentos del QR de asistencia (3.4 [SUPUESTO] del prompt; B-9 de REVIEW-1): la clave por IP cuenta **solo intentos rechazados** (respuestas ≥ 400 y ≠ 429: `AQR_001`, `AQR_005`, `AQR_007`, `VALIDATION_ERROR`, …), 600/min en `ASISTENCIA_QR/LIMITE_FALLIDOS_IP_POR_MINUTO`; los registros exitosos o idempotentes (200/201) no consumen cupo por IP, de modo que un campus entero detrás del mismo NAT no recibe 429 por registrar. Por token (120/min) y por estudiante (6/min) cuentan **todos** los intentos. | No bloquear salones completos detrás del NAT del campus |
| [SUPUESTO-B-13] | El contador de rotación del QR en el cliente **no usa ningún timer**: barra de progreso CSS (`animation-duration` calculada al recibir el evento y reiniciada por cada `ASISTENCIA_QR_ROTADO`) y texto fijo "Próxima rotación: HH:MM:SS" calculado de `fechaRotacionUtc + rotacionSegundos` que entrega el backend. | Regla anti-polling de AGENTS.md en su forma estricta |
| [SUPUESTO-B-14] | `DetalleAsistencia.codigo` pasa a obtenerse de la secuencia `dbo.seq_detalle_asistencia_codigo` (iniciada en `MAX(codigo) + 1`) en lugar de `MAX + 1` con `UPDLOCK, HOLDLOCK` sobre toda la tabla. Puede haber huecos tras un rollback. | El `MAX+1` serializa a todos los grupos del campus (prueba 5 × 40) y abre ciclos de bloqueo |
| [SUPUESTO-B-15] | Un estudiante con varias tomas en una sesión se muestra con un **estado consolidado** por sesión: `SJC` si alguna toma es `SJC`; si no, `EX` si alguna es `EX`; si no, `AN`. Si mezcla `AN` y `SJC` se marca `esParcial = 1` (estado `PARCIAL` en el DTO del estudiante). | Golden path de `GET /grupos/{id}/asistencias` sin cambio de esquema |
| [SUPUESTO-B-16] | El evento `ASISTENCIA_QR_ROTADO` lleva el token (dentro de `urlAsistencia` y `qrPngBase64`), igual que `MATRICULA_QR_ROTADO` (precedente HU176B): el texto en claro solo existe en memoria del backend al rotar. Se mitiga con la **política de audiencia por tipo de evento** (§3.8): ese tipo solo se entrega al docente titular. | Sin token en claro persistido; mismo mecanismo probado |
| [SUPUESTO-B-17] | (Alcance del orquestador; NB-11 y DEC-022) **El SSE para estudiantes queda en el paquete C.** B diseña la política de audiencia del gateway (`RealtimeAudienciaPolicy`, comparación de tipo por igualdad exacta) solo para eventos del **docente titular**; el canal sigue abierto únicamente al titular, como hoy. El estudiante se entera de la cancelación por la notificación y al recargar o navegar. | DEC-022 (1) asigna a C la apertura del SSE a los demás roles |
| [SUPUESTO-B-18] | `usp_registrar_asistencia_estudiante_autonomo` (código estático `Sesion.codigo`) deja de tener consumidor en el backend: se retiran `AsistenciaJpaRepository:44` y la feature `registrarasistenciaautonoma`. **B no revoca permisos ni borra el objeto**; el `REVOKE`/`DROP` pasa al paquete D, que debe sustituir `rol_asistencias_runtime.sql` (post-freeze `WORK_ITEM`) y actualizar `test/verify_runtime_role_login.ps1:31`. `Sesion.codigo` deja de ser una credencial porque ningún endpoint lo acepta. | B-5 de REVIEW-1: el `GRANT` vive en un archivo congelado |
| [SUPUESTO-B-19] | (Alcance del orquestador) El retiro del registro individual `POST /api/v1/asistencias` (501, TD-009) se **difiere al paquete D**, y TD-009 sigue abierta. B no toca ese endpoint. | Menos alcance en B frente a la fecha objetivo |
| [SUPUESTO-B-20] | Se actualizan las inserciones directas en `DetalleAsistencia` y las limpiezas que borran `Sesion` en pruebas y fixtures (lista completa en §2.16.3): las inserciones pasan la columna obligatoria `toma` y las limpiezas borran en el orden `DetalleAsistencia → TokenAsistenciaToma → TomaAsistencia → SesionCancelacion → Asistencia → Sesion`. Es un ajuste por cambio formal de contrato y **ninguna aserción se relaja**. La única aserción que cambia es el invariante global de `test_attendance_commands.sql:202` (`GROUP BY asistencia` → `GROUP BY asistencia, toma`), declarada como cambio formal por DEC-011. | AGENTS.md §4 permite el ajuste por cambio de contrato |
| [SUPUESTO-B-21] | La aplicación de festivos a grupos ya creados se dispara tras cada carga o recarga exitosa de un año (job o administrador). No se dispara desde la migración, porque la migración no puede llamar a internet: tras desplegar B.1, el job carga el año actual y el siguiente y los aplica. | La BD nunca llama a internet (§3.7) |
| [SUPUESTO-B-22] | Si dos festivos caen en la misma fecha (por ejemplo Sagrado Corazón y San Pedro el 5-jul-2038), `ObtenerFestivosConRespaldoService` los fusiona en una sola fila, con los nombres unidos por " / ", antes de llamar al SP. El cálculo local devuelve 19 festivos, o menos si coinciden. | NB-5 de REVIEW-1; se conserva `UQ_DiaFestivo_fecha` |
| [SUPUESTO-B-23] | (Alcance del orquestador) Se **difieren al paquete D**, con la marca "diferido a D: deben pasar a horas", las comparativas HU103/HU139 (`usp_consultar_comparativa_facultades`, `_programas_facultad`), la tendencia HU134 (`usp_consultar_tendencia_ausentismo`) y el consolidado HU061 (`usp_consultar_consolidado_asistencia_grupos_paginado`, F-COO-007). En B solo cambia lo mínimo para que no dupliquen filas con varias tomas (§2.9). | Fuera de la lista de 3.3; reduce el riesgo de plazo |

---

## 1. Alcance

### 1.1 Subpaquetes

| Subpaquete | Contenido | Decisiones |
| :--- | :--- | :--- |
| **B.1 — Sesión cancelada, festivos, HU047 y ventana con tolerancia** | `SesionCancelacion` + `TipoCancelacionSesion` + `uv_sesion_estado`; `DiaFestivo` + `CargaDiaFestivo` + carga por año; `usp_generar_sesiones_grupo_v2`, precarga con festivos y `usp_aplicar_festivos_*`; `usp_cancelar_sesion` (HU047) con notificación `SESION_CANCELADA` y evento SSE; `CalendarioFestivosPort` con 3 adaptadores + job + pantalla de festivos del administrador; ventana SES-01 con `@toleranciaMinutos`/`@margenMinutos` opcionales y rechazo de sesiones canceladas; `uv_cumplimiento_sesion_grupo` sin canceladas; estado cancelado visible en todos los roles; política de audiencia SSE para eventos del titular | DEC-014, DEC-016, DEC-017, DEC-018 |
| **B.2 — Tomas por horas, QR de asistencia y faltantes** | `TomaAsistencia` + catálogos; `DetalleAsistencia.toma` con migración y backfill; toma vigente en `usp_sincronizar_asistencia_estudiante_interno`; lote por toma; cierre con faltantes; cálculo por horas (`ufn_*`, `uv_resumen_*` y KPIs); `TokenAsistenciaToma` + SPs del QR + scheduler + rate limit + CIDR + SSE; nuevo `POST /estudiante/asistencia-qr` (token o PIN); pantallas del docente (modo, tomas, proyección, faltantes) y del estudiante (`/app/asistencia/qr`, PIN, indicadores por horas) | DEC-011, DEC-012, DEC-013, DEC-014, DEC-015, DEC-018 |

B.1 va primero porque B.2 necesita `uv_sesion_estado` (las tomas no se abren en sesiones canceladas y las horas excluyen canceladas).

### 1.2 HUs cubiertas

| HU | Efecto en B | Subpaquete |
| :--- | :--- | :--- |
| **HU047** Cancelar sesión con justificación | Implementada (501 → funcional), notificación al estudiante y SSE | B.1 |
| **HU175** Proyección de QR dinámico y PIN | Implementada sobre tomas QR (no sobre la sesión) | B.2 |
| **HU176** Auto-registro de asistencia con red del campus | Implementada: token o PIN, CIDR, límites, idempotente | B.2 |
| HU004, HU009, HU013 (estudiante: %, fallas, semáforo) | `GET /estudiante/materias` entrega indicadores **por horas** desde `uv_resumen_asistencia_estudiante_grupo` | B.2 |
| HU040, HU041 (docente: sábana y riesgo) | Endpoint de resumen por grupo; la sábana deja de calcular en el cliente | B.2 |
| HU065 (cumplimiento) | `uv_cumplimiento_sesion_grupo` excluye canceladas (B.1) y cuenta tomas (B.2) | B.1/B.2 |
| HU066, HU070 (alertas tempranas) | Vía `uv_resumen_*` por horas | B.2 |
| HU102, HU106 (decano) | `usp_consultar_kpis_decano` y comparativas por horas | B.2 |
| HU133, HU138 (institución) | `usp_consultar_kpis_institucion` por horas; cumplimiento sin canceladas | B.1/B.2 |
| HU067, HU069 | Bitácora e historial agregan por sesión/horas | B.2 |
| HU061, HU103, HU134, HU139 (consolidado, comparativas, tendencia) | **Diferido a D: deben pasar a horas** ([SUPUESTO-B-23]). En B solo se evita la duplicación de filas con varias tomas | D |
| HU002/HU010 (sesiones y reclamo del estudiante) | Estado consolidado por sesión, horas por sesión; una sesión cancelada no es reclamable | B.1/B.2 |
| HU144/HU145 (cronograma) | Las sesiones muestran `estado`/`cancelacion` | B.1 |

### 1.3 Hallazgos de la Fase 1

| Hallazgo | Resolución |
| :--- | :--- |
| F-DOC-002 (QR estático, PIN `392-817`) | **Cierra B.2**: se retira `attendance-projection-modal` y la proyección usa tokens reales |
| F-DOC-003 (`setInterval` + sondeo de `qr-token`) | **Cierra B.2**: contador sin timers ([SUPUESTO-B-13]); `getQrToken` retirado |
| F-DOC-004 (sábana con % local) | **Cierra B.2**: `GET /docente/grupos/{id}/resumen-asistencia` (§3.2.12) |
| F-DOC-012 (`asistio = 0` con `AN`) | **Parcial en B.2**: el cálculo por horas usa `codigoRazonCausa` (no `asistio`); la migración `16_up` **reporta** (no corrige) las filas incoherentes y la prueba de invariante falla si un SP nuevo las produce. La corrección de los datos queda para el paquete A (hallazgos críticos/altos) |
| F-DOC-015, F-DOC-016 (500 al abrir matrícula QR) | **Fuera de B** (HU176B, paquete A). **Dependencia:** B.2 reutiliza `TokenGeneratorPort`, `CodigoQrGeneratorPort` y el patrón del adaptador JPA; el GREEN de B.2 (QR) no empieza hasta conocer la causa raíz de F-DOC-015 |
| F-DOC-017 (sesiones solapadas) | **Fuera de B** (paquete D o hallazgos altos) |
| F-DOC-021 (horarios del docente vacíos) | **Fuera de B** (paquete D) |
| F-EST-002 (sin indicadores en materias) | **Cierra B.2** (§3.2.13) |
| F-EST-005 (sin campo token) | **Cierra B.2**: cuerpo `{token}` o `{pin}` |
| F-EST-009 (umbrales 85/75 en el cliente) | **Cierra B.2**: el cliente pinta `codigoPermanencia` y los umbrales que entrega el backend |
| F-EST-017 (exige `sesionId`) | **Cierra B.2**: el token/PIN resuelve la toma |
| F-EST-021 (Carlos sin registros) | **Fuera de B** (datos del recorrido; Fase 3). El flujo de faltantes de B evita que se repita |
| F-COO-007 (consolidado incoherente) | **Diferido a D** con el consolidado HU061 ([SUPUESTO-B-23]) |

### 1.4 Fuera de alcance

Cancelación por inasistencia (paquete C). B solo aplica a `usp_ejecutar_cierre_masivo_periodo` el cambio mínimo `COUNT(da.id)` → `COUNT(DISTINCT a.sesion)` para que varias tomas de una sesión no lleven a `CI` (B-7; C lo reescribe). También quedan fuera: SSE para estudiantes y demás roles (C, DEC-022); comparativas, tendencia y consolidado por horas, el retiro de `POST /asistencias` (TD-009) y el `REVOKE`/`DROP` del SP autónomo (D); asignaturas N:M (B2); cruce de horarios del docente, catálogo de mensajes del equipo externo, identidad visual (E; los componentes nuevos de B nacen con los tokens de `styles.css`).

---

## 2. Base de datos (`GestioAsistenciaDB`)

### 2.0 Reglas comunes de los objetos nuevos

- Todo SP público nuevo: `SET NOCOUNT ON; SET XACT_ABORT ON;`, ownership transaccional (`@@TRANCOUNT = 0` → `BEGIN TRANSACTION` propia; si no, `SAVE TRANSACTION <nombre>`), `IF @@TRANCOUNT > 0 ROLLBACK` / rollback al savepoint en el `CATCH`, propagación de transacción externa condenada (`XACT_STATE() = -1` → `THROW`), igual que `usp_registrar_asistencias_sesion` (líneas 282-291 y 366-382).
- Parámetros de entrada estandarizados con `ufn_obtener_parametro_guid/_texto/_int` (sin `ISNULL`); `@parametro IS NULL` se evalúa explícitamente; nunca se compara con `'00000000-…'`.
- Paso 1 siempre `usp_validar_id_correlacion_esta_presente_interno`; RBAC con `usp_validar_permiso_rbac_usuario_interno(@idUsuario, @codigoPerfilRequerido)`; titularidad con `usp_validar_titularidad_jerarquica_interno(@idUsuario, @idEntidadPadre, @tipoEntidadPadre IN ('SESION','GRUPO'))`; mensajes con `usp_obtener_mensaje_catalogo`; error inesperado `SYS_001` + `ufn_obtener_detalle_error`.
- **SP de comando**: una sola fila de salida con la tupla canónica `idCorrelacion, mensajeUsuarioResultado, mensajeTecnicoResultado, estadoResultado` seguida de las columnas de datos que se indican (NULL si `estadoResultado = 0`).
- **SP de consulta** (`usp_consultar_*`, clasificación `READ_QUERY_RESULTSET`): validación → `THROW 51000` con el mensaje técnico si falla; `usp_establecer_contexto_usuario_ejecutor`; `SELECT … FROM uv_* … ORDER BY … OFFSET (@numeroPagina − 1) * @tamanoPagina ROWS FETCH NEXT @tamanoPagina ROWS ONLY` con `COUNT(1) OVER() AS totalRegistros`; `@numeroPagina` ≥ 1, `@tamanoPagina` entre 1 y `GENERAL/TAMANO_PAGINA_MAXIMO` (o 100 si no existe; se verifica en el RED).
- Aislamiento jerárquico **dentro** del SP: docente solo sus grupos (titularidad), estudiante solo sus matrículas `A`, administrador solo su institución (`Grupo → PeriodoAcademico.institucion = Administrador.institucion`).
- Ningún literal de estado/modo/tipo ([SUPUESTO-B-02]); textos de usuario solo desde `CatalogoMensajeUsuario`.
- Bloqueos: toda escritura que dependa de la sesión toma primero `dbo.Sesion WITH (UPDLOCK, HOLDLOCK)` (vía `usp_validar_sesion_ventana_registro_interno` o lectura explícita) y luego las filas hijas, siempre en el orden **Sesion → TomaAsistencia → TokenAsistenciaToma → EstudianteGrupo → Asistencia → DetalleAsistencia** para que no haya ciclos.

### 2.1 Catálogos nuevos (tablas + semilla)

Archivos `DB:schema/tables/<Tabla>.sql` (idempotentes `IF OBJECT_ID(...) IS NULL CREATE`), FKs al final de `DB:schema/tables/zz_foreign_keys.sql`, filas en semilla con ids fijos (patrón `08_razon_causa.sql`).

```sql
-- B.1  DB:schema/tables/TipoCancelacionSesion.sql
CREATE TABLE dbo.TipoCancelacionSesion (
    id            UNIQUEIDENTIFIER NOT NULL,
    codigo        NVARCHAR(20)     NOT NULL,
    nombre        NVARCHAR(50)     NOT NULL,
    esAutomatica  BIT              NOT NULL,   -- 1 = la crea el sistema (festivo); 0 = la decide un usuario (docente)
    CONSTRAINT PK_TipoCancelacionSesion PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_TipoCancelacionSesion_codigo UNIQUE (codigo),
    CONSTRAINT UQ_TipoCancelacionSesion_esAutomatica UNIQUE (esAutomatica)   -- exactamente un tipo por bandera
);
-- semilla 34_catalogos_sesion_cancelada.sql (MERGE por id):
--   ('7C1E0B10-5E51-4C0A-9A01-000000000001', N'DOCENTE', N'Cancelada por el docente', 0)
--   ('7C1E0B10-5E51-4C0A-9A01-000000000002', N'FESTIVO', N'Día festivo',              1)

-- B.2  DB:schema/tables/ModoTomaAsistencia.sql
CREATE TABLE dbo.ModoTomaAsistencia (
    id                     UNIQUEIDENTIFIER NOT NULL,
    codigo                 NVARCHAR(20)     NOT NULL,   -- valor que recibe la API: MANUAL | QR
    nombre                 NVARCHAR(50)     NOT NULL,
    usaCodigoQr            BIT              NOT NULL,
    marcaAusentesAlCerrar  BIT              NOT NULL,   -- valor por defecto de @marcarAusentes al cerrar
    CONSTRAINT PK_ModoTomaAsistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_ModoTomaAsistencia_codigo UNIQUE (codigo),
    CONSTRAINT UQ_ModoTomaAsistencia_usaCodigoQr UNIQUE (usaCodigoQr)
);
-- semilla 35_catalogos_toma_asistencia.sql:
--   ('7C1E0B20-5E51-4C0A-9A01-000000000001', N'MANUAL', N'Registro manual del docente', 0, 0)
--   ('7C1E0B20-5E51-4C0A-9A01-000000000002', N'QR',     N'Código QR y PIN rotativos',  1, 1)

-- B.2  DB:schema/tables/EstadoTomaAsistencia.sql
CREATE TABLE dbo.EstadoTomaAsistencia (
    id           UNIQUEIDENTIFIER NOT NULL,
    codigo       NVARCHAR(20)     NOT NULL,   -- ABIERTA | CERRADA
    nombre       NVARCHAR(50)     NOT NULL,
    estaAbierta  BIT              NOT NULL,
    CONSTRAINT PK_EstadoTomaAsistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_EstadoTomaAsistencia_codigo UNIQUE (codigo),
    CONSTRAINT UQ_EstadoTomaAsistencia_estaAbierta UNIQUE (estaAbierta)
);
-- semilla 35_catalogos_toma_asistencia.sql:
--   ('7C1E0B30-5E51-4C0A-9A01-000000000001', N'ABIERTA', N'Abierta', 1)
--   ('7C1E0B30-5E51-4C0A-9A01-000000000002', N'CERRADA', N'Cerrada', 0)
```

Vistas de catálogo (solo consulta, patrón CAT-01): `uv_tipo_cancelacion_sesion (id, codigo, nombre, esAutomatica)`, `uv_modo_toma_asistencia (id, codigo, nombre, usaCodigoQr, marcaAusentesAlCerrar)`, `uv_estado_toma_asistencia (id, codigo, nombre, estaAbierta)`.

### 2.2 Tablas nuevas

```sql
-- B.1  DB:schema/tables/DiaFestivo.sql  (SSOT de festivos nacionales; la BD nunca llama a internet)
CREATE TABLE dbo.DiaFestivo (
    id                  UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_DiaFestivo_id DEFAULT NEWID(),
    fecha               DATE             NOT NULL,
    anio                AS CAST(YEAR(fecha) AS SMALLINT) PERSISTED,
    nombre              NVARCHAR(120)    NOT NULL,
    fuente              NVARCHAR(40)     NOT NULL,   -- valor de FESTIVOS/FUENTES_VALIDAS (validado en el SP)
    estaActivo          BIT              NOT NULL CONSTRAINT DF_DiaFestivo_estaActivo DEFAULT 1,
    fechaCargaUtc       DATETIME2(0)     NOT NULL,
    idCorrelacionCarga  UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_DiaFestivo PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_DiaFestivo_fecha UNIQUE (fecha),
    CONSTRAINT CK_DiaFestivo_nombre CHECK (LEN(LTRIM(RTRIM(nombre))) > 0)
);
CREATE NONCLUSTERED INDEX IX_DiaFestivo_anio ON dbo.DiaFestivo (anio, estaActivo) INCLUDE (fecha, nombre, fuente);

-- B.1  DB:schema/tables/CargaDiaFestivo.sql  (bitácora de cada carga anual: fuente, fecha y diferencias con el cálculo local)
CREATE TABLE dbo.CargaDiaFestivo (
    id                        UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_CargaDiaFestivo_id DEFAULT NEWID(),
    anio                      SMALLINT         NOT NULL,
    fuente                    NVARCHAR(40)     NOT NULL,
    totalFestivos             INT              NOT NULL,
    festivosInsertados        INT              NOT NULL,
    festivosActualizados      INT              NOT NULL,
    festivosDesactivados      INT              NOT NULL,
    diferenciasCalculoLocal   INT              NOT NULL,   -- fechas en la fuente y no en el cálculo local + viceversa (lo calcula el backend)
    usuarioEjecutor           UNIQUEIDENTIFIER NULL,       -- NULL = job
    fechaCargaUtc             DATETIME2(0)     NOT NULL,
    idCorrelacion             UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_CargaDiaFestivo PRIMARY KEY CLUSTERED (id),
    CONSTRAINT CK_CargaDiaFestivo_conteos CHECK (totalFestivos >= 0 AND festivosInsertados >= 0 AND festivosActualizados >= 0
                                                AND festivosDesactivados >= 0 AND diferenciasCalculoLocal >= 0)
);
CREATE NONCLUSTERED INDEX IX_CargaDiaFestivo_anio_fecha ON dbo.CargaDiaFestivo (anio, fechaCargaUtc DESC);
-- FK: FK_CargaDiaFestivo_Usuario (usuarioEjecutor -> Usuario.id)

-- B.1  DB:schema/tables/SesionCancelacion.sql  (1:0..1 con Sesion; no se toca Sesion.sql ni su guard 50004)
CREATE TABLE dbo.SesionCancelacion (
    sesion               UNIQUEIDENTIFIER NOT NULL,
    tipoCancelacion      UNIQUEIDENTIFIER NOT NULL,
    motivo               NVARCHAR(500)    NOT NULL,
    diaFestivo           UNIQUEIDENTIFIER NULL,
    usuarioEjecutor      UNIQUEIDENTIFIER NULL,       -- NULL solo en cancelaciones automáticas del job
    fechaCancelacionUtc  DATETIME2(0)     NOT NULL CONSTRAINT DF_SesionCancelacion_fecha DEFAULT SYSUTCDATETIME(),
    idCorrelacion        UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_SesionCancelacion PRIMARY KEY CLUSTERED (sesion),
    CONSTRAINT CK_SesionCancelacion_motivo CHECK (LEN(LTRIM(RTRIM(motivo))) > 0),
    CONSTRAINT CK_SesionCancelacion_origen CHECK (diaFestivo IS NOT NULL OR usuarioEjecutor IS NOT NULL)
);
CREATE NONCLUSTERED INDEX IX_SesionCancelacion_diaFestivo ON dbo.SesionCancelacion (diaFestivo) WHERE diaFestivo IS NOT NULL;
-- FKs: FK_SesionCancelacion_Sesion (sesion -> Sesion.id), FK_SesionCancelacion_TipoCancelacionSesion,
--      FK_SesionCancelacion_DiaFestivo (diaFestivo -> DiaFestivo.id), FK_SesionCancelacion_Usuario (usuarioEjecutor -> Usuario.id)
-- Coherencia tipo/diaFestivo (tipo automático <=> diaFestivo NOT NULL) la garantizan los SP (no hay CHECK entre tablas);
-- la prueba INV_SESION_CANCELACION_COHERENTE la verifica.

-- B.2  DB:schema/tables/TomaAsistencia.sql
CREATE TABLE dbo.TomaAsistencia (
    id                     UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_TomaAsistencia_id DEFAULT NEWID(),
    sesion                 UNIQUEIDENTIFIER NOT NULL,
    numero                 SMALLINT         NOT NULL,
    modo                   UNIQUEIDENTIFIER NOT NULL,
    estado                 UNIQUEIDENTIFIER NOT NULL,
    esImplicita            BIT              NOT NULL CONSTRAINT DF_TomaAsistencia_esImplicita DEFAULT 0,  -- lote legado o backfill
    docenteApertura        UNIQUEIDENTIFIER NULL,     -- NULL solo en el backfill
    fechaAperturaUtc       DATETIME2(0)     NOT NULL,
    fechaCierreUtc         DATETIME2(0)     NULL,
    totalAusentesMarcados  INT              NOT NULL CONSTRAINT DF_TomaAsistencia_ausentes DEFAULT 0,  -- SJC insertados al cerrar
    idCorrelacionApertura  UNIQUEIDENTIFIER NOT NULL,
    idCorrelacionCierre    UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_TomaAsistencia PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_TomaAsistencia_Sesion_Numero UNIQUE (sesion, numero),
    CONSTRAINT CK_TomaAsistencia_numero CHECK (numero >= 1),
    CONSTRAINT CK_TomaAsistencia_cierre CHECK (fechaCierreUtc IS NULL OR fechaCierreUtc >= fechaAperturaUtc),
    CONSTRAINT CK_TomaAsistencia_ausentes CHECK (totalAusentesMarcados >= 0)
);
-- Una sola toma abierta por sesión (filtro sin literal de estado, [SUPUESTO-B-02]):
CREATE UNIQUE NONCLUSTERED INDEX UX_TomaAsistencia_Sesion_Abierta ON dbo.TomaAsistencia (sesion) WHERE fechaCierreUtc IS NULL;
CREATE NONCLUSTERED INDEX IX_TomaAsistencia_abiertas ON dbo.TomaAsistencia (fechaAperturaUtc) INCLUDE (sesion, modo) WHERE fechaCierreUtc IS NULL;
-- FKs: FK_TomaAsistencia_Sesion, FK_TomaAsistencia_ModoTomaAsistencia, FK_TomaAsistencia_EstadoTomaAsistencia,
--      FK_TomaAsistencia_Docente (docenteApertura -> Docente.id)
-- Invariante (prueba INV_TOMA_ESTADO_CIERRE): estado.estaAbierta = 1  <=>  fechaCierreUtc IS NULL.

-- B.2  DB:schema/tables/TokenAsistenciaToma.sql  (análoga a TokenMatriculaGrupo; solo SHA-256, nunca el token en claro)
CREATE TABLE dbo.TokenAsistenciaToma (
    id                  UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_TokenAsistenciaToma_id DEFAULT NEWID(),
    toma                UNIQUEIDENTIFIER NOT NULL,
    docenteEmisor       UNIQUEIDENTIFIER NOT NULL,
    tokenHash           VARBINARY(32)    NOT NULL,
    pin                 NCHAR(6)         NOT NULL,
    tokenHashAnterior   VARBINARY(32)    NULL,
    pinAnterior         NCHAR(6)         NULL,
    fechaEmisionUtc     DATETIME2(0)     NOT NULL,
    fechaRotacionUtc    DATETIME2(0)     NOT NULL,
    fechaExpiracionUtc  DATETIME2(0)     NOT NULL,    -- = fin de la ventana de la sesión (fin + MARGEN_RETARDO_MINUTOS)
    fechaCierreUtc      DATETIME2(0)     NULL,        -- NULL = activo
    idCorrelacionEmision UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_TokenAsistenciaToma PRIMARY KEY CLUSTERED (id),
    CONSTRAINT UQ_TokenAsistenciaToma_tokenHash UNIQUE (tokenHash),
    CONSTRAINT CK_TokenAsistenciaToma_pin CHECK (pin NOT LIKE N'%[^0-9]%' AND LEN(pin) = 6),
    CONSTRAINT CK_TokenAsistenciaToma_pinAnterior CHECK (pinAnterior IS NULL OR (pinAnterior NOT LIKE N'%[^0-9]%' AND LEN(pinAnterior) = 6)),
    CONSTRAINT CK_TokenAsistenciaToma_fechas CHECK (fechaExpiracionUtc > fechaEmisionUtc AND fechaRotacionUtc >= fechaEmisionUtc)
);
CREATE UNIQUE NONCLUSTERED INDEX UX_TokenAsistenciaToma_toma_activo ON dbo.TokenAsistenciaToma (toma) WHERE fechaCierreUtc IS NULL;
CREATE UNIQUE NONCLUSTERED INDEX UX_TokenAsistenciaToma_pin_activo  ON dbo.TokenAsistenciaToma (pin)  WHERE fechaCierreUtc IS NULL;
CREATE UNIQUE NONCLUSTERED INDEX UX_TokenAsistenciaToma_tokenHashAnterior ON dbo.TokenAsistenciaToma (tokenHashAnterior) WHERE tokenHashAnterior IS NOT NULL;
CREATE NONCLUSTERED INDEX IX_TokenAsistenciaToma_pinAnterior ON dbo.TokenAsistenciaToma (pinAnterior) WHERE pinAnterior IS NOT NULL AND fechaCierreUtc IS NULL;
CREATE NONCLUSTERED INDEX IX_TokenAsistenciaToma_rotacion ON dbo.TokenAsistenciaToma (fechaRotacionUtc) INCLUDE (toma, docenteEmisor) WHERE fechaCierreUtc IS NULL;
-- FKs: FK_TokenAsistenciaToma_TomaAsistencia, FK_TokenAsistenciaToma_Docente
-- La unicidad del PIN nuevo frente a los pinAnterior vigentes la garantizan usp_abrir_qr_toma / usp_internal_rotar_token_asistencia
-- (UPDLOCK, HOLDLOCK) -> AQR_006 y reintento en el backend (hasta 5 veces, como HU176B).
-- Sin contador "totalRegistros" en la fila: 40 lecturas simultáneas no deben serializarse sobre el token; el total sale de la vista.
```

### 2.3 Cambio de `dbo.DetalleAsistencia` (B.2)

`DB:schema/tables/DetalleAsistencia.sql` (no está en ningún manifiesto) pasa a:

```sql
-- CREATE (instalación nueva): columnas actuales +
    [toma]                     uniqueidentifier NULL,      -- nace NULL también en instalación nueva: la semilla 36 (se ejecuta
                                                          -- siempre en deploy_schema.ps1, después de los catálogos 35) hace el
                                                          -- backfill y el ALTER COLUMN ... NOT NULL. Un solo camino para BD nueva y existente.
    [registradoPorEstudiante]  bit              NOT NULL CONSTRAINT DF_DetalleAsistencia_registradoPorEstudiante DEFAULT 0,
    [fechaRegistroUtc]         datetime2(0)     NULL,
-- BD existente (idempotente):
IF COL_LENGTH('dbo.DetalleAsistencia', 'toma') IS NULL
    ALTER TABLE dbo.DetalleAsistencia ADD [toma] uniqueidentifier NULL;          -- pasa a NOT NULL en la semilla 36 / migración 16
IF COL_LENGTH('dbo.DetalleAsistencia', 'registradoPorEstudiante') IS NULL
    ALTER TABLE dbo.DetalleAsistencia ADD [registradoPorEstudiante] bit NOT NULL
        CONSTRAINT DF_DetalleAsistencia_registradoPorEstudiante DEFAULT 0;
IF COL_LENGTH('dbo.DetalleAsistencia', 'fechaRegistroUtc') IS NULL
    ALTER TABLE dbo.DetalleAsistencia ADD [fechaRegistroUtc] datetime2(0) NULL;
-- (B-1 de REVIEW-1: un ALTER COLUMN ... NOT NULL falla con 4922 si un índice o FK ya usa la columna.)
-- (c) Mientras toma admita NULL (antes del backfill) se conservan el guard y el índice antiguos:
IF COLUMNPROPERTY(OBJECT_ID('dbo.DetalleAsistencia'), 'toma', 'AllowsNull') = 1
BEGIN
    -- guard THROW 50002 "duplicates by asistencia" (texto actual) y bloque que (re)crea UX_DetalleAsistencia_Asistencia (texto actual)
END
-- Cuando toma ya es NOT NULL, el guard pasa a "duplicates by (asistencia, toma)" (THROW 50002, mismo número) y
-- UX_DetalleAsistencia_Asistencia ya no se recrea.
-- (a) Los tres dependientes de toma se crean SOLO si la columna ya es NOT NULL (en tables/ y en zz_foreign_keys.sql):
IF COLUMNPROPERTY(OBJECT_ID('dbo.DetalleAsistencia'), 'toma', 'AllowsNull') = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_DetalleAsistencia_Asistencia_Toma' AND object_id = OBJECT_ID('dbo.DetalleAsistencia'))
        CREATE UNIQUE NONCLUSTERED INDEX UX_DetalleAsistencia_Asistencia_Toma ON dbo.DetalleAsistencia (asistencia, toma);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DetalleAsistencia_Toma' AND object_id = OBJECT_ID('dbo.DetalleAsistencia'))
        CREATE NONCLUSTERED INDEX IX_DetalleAsistencia_Toma ON dbo.DetalleAsistencia (toma) INCLUDE (asistencia, asistio, razonCausa);
END
-- zz_foreign_keys.sql: FK_DetalleAsistencia_TomaAsistencia (toma -> TomaAsistencia.id) con la misma condición AllowsNull = 0.
-- Secuencia ([SUPUESTO-B-14]), creada en este archivo y en 16_up si no existe:
IF OBJECT_ID('dbo.seq_detalle_asistencia_codigo', 'SO') IS NULL
    -- START WITH = ISNULL(MAX(codigo), 0) + 1 calculado con SQL dinámico (EXEC sp_executesql); INCREMENT BY 1; NO CYCLE; CACHE 50
```

**(b) Conversión a NOT NULL** — en la semilla `36_backfill_toma_asistencia.sql` y en `16_up`, idéntica, en **una** transacción con `SET XACT_ABORT ON`, solo si `AllowsNull = 1`:
1. backfill (toma 1 implícita por sesión con detalles sin toma; `UPDATE … SET toma`);
2. `DROP` de `FK_DetalleAsistencia_TomaAsistencia`, `UX_DetalleAsistencia_Asistencia_Toma` e `IX_DetalleAsistencia_Toma` si existen;
3. `ALTER TABLE dbo.DetalleAsistencia ALTER COLUMN toma uniqueidentifier NOT NULL`;
4. `DROP INDEX UX_DetalleAsistencia_Asistencia` si existe;
5. `CREATE` de los tres objetos del paso 2.
Con eso el camino es único para BD nueva y existente: en el primer `deploy_schema.ps1` `tables/` no crea los dependientes (columna NULL), la semilla 36 convierte y crea; en el segundo `deploy_schema.ps1` `tables/` ve `AllowsNull = 0`, crea lo que falte (nada) y la semilla 36 no hace nada. Lo prueba B2-MIG-05.

- `DB:scripts/precheck_unique_indexes.sql:16-22` se actualiza: el precheck de `DetalleAsistencia` pasa a `(asistencia, toma)`.
- `fechaHoraInicio/fechaHoraFin` del detalle siguen siendo la ventana de la **sesión** (no la de la toma): los lectores de `uv_detalle_asistencia` (congelada) no cambian de semántica horaria.
- Cardinalidad: `uv_detalle_asistencia` (congelada, texto intacto) pasa a devolver una fila **por toma** (DEC-011). Todos sus consumidores en BD y backend se adaptan en §2.9 y §3.6.

### 2.4 Funciones nuevas (B.2)

| Función | Firma | Regla |
| :--- | :--- | :--- |
| `ufn_horas_sesion` | `(@fechaHoraInicio DATETIME2, @fechaHoraFin DATETIME2) RETURNS DECIMAL(12,6)` | `CAST(DATEDIFF(MINUTE, @i, @f) AS DECIMAL(12,6)) / 60`; 0 si alguna fecha es NULL o `@f <= @i`. Determinista e inlineable (sin acceso a datos) |
| `ufn_horas_toma` | `(@idSesion UNIQUEIDENTIFIER) RETURNS DECIMAL(12,6)` | `ufn_horas_sesion(inicio, fin) / COUNT(tomas de la sesión)`; 0 si la sesión no tiene tomas o está cancelada. Solo para SP (las vistas usan la ventana `COUNT(*) OVER (PARTITION BY sesion)`) |
| `ufn_calcular_porcentaje_inasistencia_horas` | `(@horasFalta DECIMAL(12,6), @horasDictadas DECIMAL(12,6)) RETURNS DECIMAL(5,2)` | 0 si `@horasDictadas` es NULL o ≤ 0; si no, `CAST(100.0 * @horasFalta / @horasDictadas AS DECIMAL(5,2))`, acotado a [0, 100] |
| `ufn_clasificar_permanencia` | **sin cambio de firma ni de texto** | Recibe el porcentaje por horas (el llamador cambia, la función no) |

### 2.5 Vistas nuevas

**B.1**

| Vista | Columnas |
| :--- | :--- |
| `uv_dia_festivo` | `id, fecha, anio, nombre, fuente, estaActivo, fechaCargaUtc, idCorrelacionCarga` |
| `uv_carga_dia_festivo` | `id, anio, fuente, totalFestivos, festivosInsertados, festivosActualizados, festivosDesactivados, diferenciasCalculoLocal, idUsuarioEjecutor, fechaCargaUtc, idCorrelacion, esUltimaCargaAnio` (`ROW_NUMBER() OVER (PARTITION BY anio ORDER BY fechaCargaUtc DESC) = 1`) |
| `uv_sesion_estado` | Una fila por sesión, sobre `uv_sesion_v2` + `SesionCancelacion` (LEFT) + `uv_tipo_cancelacion_sesion` + `DiaFestivo`: `idSesion, idGrupo, numero, nombre, fechaHoraInicio, fechaHoraFin, procedenciaTemporal, estaCancelada BIT, idTipoCancelacion, codigoTipoCancelacion, nombreTipoCancelacion, esCancelacionAutomatica, motivoCancelacion, idDiaFestivo, nombreDiaFestivo, fechaCancelacionUtc, idUsuarioCancelacion, ventanaAperturaUtc (= DATEADD(MINUTE, −TOLERANCIA_MINUTOS, inicio); NULL si procedencia NULL), ventanaCierreUtc (= DATEADD(MINUTE, MARGEN_RETARDO_MINUTOS, fin)), ventanaAbierta BIT (no cancelada, procedencia confirmada y apertura ≤ SYSUTCDATETIME() < cierre), horasSesion`. Los dos parámetros se leen una vez con `CROSS APPLY (SELECT dbo.ufn_obtener_parametro_int(NULL,'ASISTENCIA','TOLERANCIA_MINUTOS'), …)`. B.2 añade `totalTomas, tieneTomaAbierta, idTomaAbierta` |

**B.2**

| Vista | Columnas |
| :--- | :--- |
| `uv_toma_asistencia` | `idToma, idSesion, idGrupo, numero, idModo, codigoModo, nombreModo, usaCodigoQr, marcaAusentesAlCerrar, idEstado, codigoEstado, nombreEstado, estaAbierta, esImplicita, idDocenteApertura, fechaAperturaUtc, fechaCierreUtc, totalAusentesMarcados, fechaHoraInicioSesion, fechaHoraFinSesion, estaSesionCancelada, horasSesion, totalTomasSesion (COUNT(*) OVER (PARTITION BY sesion)), horasToma (= horasSesion / totalTomasSesion; 0 si cancelada), totalRegistros, totalPresentes, totalAusentes, totalExcusas, tieneQrActivo` |
| `uv_token_asistencia_toma` | `id, idToma, idSesion, idGrupo, idDocenteEmisor, pin, pinAnterior, fechaEmisionUtc, fechaRotacionUtc, fechaExpiracionUtc, fechaCierreUtc, estaActivo (fechaCierreUtc IS NULL), estaVigente (activo y SYSUTCDATETIME() < fechaExpiracionUtc), debeRotar (vigente y SYSUTCDATETIME() >= DATEADD(SECOND, ASISTENCIA_QR/ROTACION_SEGUNDOS, fechaRotacionUtc)), anteriorVigente (pinAnterior NOT NULL y SYSUTCDATETIME() < DATEADD(SECOND, ASISTENCIA_QR/TOLERANCIA_SEGUNDOS, fechaRotacionUtc)), totalRegistrosQr (detalles de la toma con registradoPorEstudiante = 1), nombreAsignatura, nombreGrupo, numeroSesion, numeroToma`. Nunca expone `tokenHash` |
| `uv_detalle_asistencia_v2` | Columnas de `uv_detalle_asistencia` (`id, codigo, idAsistencia, asistio, idRazonCausa, nombreRazonCausa, codigoRazonCausa, fechaHoraInicio, fechaHoraFin`) + `idToma, numeroToma, idSesion, idEstudianteGrupo, idModoToma, codigoModoToma, horasToma, registradoPorEstudiante, fechaRegistroUtc, estaSesionCancelada` |
| `uv_asistencia_sesion_horas` | Una fila por `Asistencia` (cabecera): `idAsistencia, idEstudianteGrupo, idSesion, idGrupo, totalTomasSesion, tomasConRegistro, horasSesion, horasAsistidas (Σ horasToma con AN), horasFalta (Σ con asistio = 0 y SJC), horasExcusa (Σ con EX), horasSinRegistro (horasSesion − las tres anteriores), codigoRazonCausaConsolidado ([SUPUESTO-B-15]), esParcial BIT, tieneFaltaSinJustaCausa BIT` |
| `uv_faltantes_toma` | Una fila por matrícula **activa** (`codigoEstadoEstudiante = A`) del grupo de la toma sin presencia en ella: `idToma, idSesion, idGrupo, numeroToma, idEstudianteGrupo, idEstudiante, nombreCompletoEstudiante (de uv_estudiante_grupo), tieneRegistro BIT, idDetalleAsistencia (NULL si no hay registro), codigoRazonCausa (NULL o SJC), fueMarcadoAlCerrar BIT (SJC insertado por usp_cerrar_toma)`. Excluye a quien tiene `AN` o `EX` en la toma |

### 2.6 Vistas modificadas (no congeladas)

| Vista | Cambio |
| :--- | :--- |
| `uv_cumplimiento_sesion_grupo` (B.1) | `WHERE NOT EXISTS (SELECT 1 FROM dbo.SesionCancelacion sc WHERE sc.sesion = s.id)`: una sesión cancelada sale de `sesionesProgramadas`, `vencidas`, `ejecutadas`, cumplimiento, progreso de calendario y tendencia. Columnas sin cambio. **B.2:** `tieneRegistroAsistencia` = `EXISTS uv_asistencia OR EXISTS TomaAsistencia` ([SUPUESTO-B-06]); nuevas columnas `totalTomas INT`, `horasSesion DECIMAL(12,6)` |
| `uv_resumen_asistencia_estudiante_grupo` (B.2) | Columnas actuales con el mismo nombre y tipo: `idEstudianteGrupo, idEstudiante, idGrupo, idAsignatura, idPrograma, idPeriodoAcademico, codigoEstadoEstudiante, sesionesEjecutadas` (sesiones vencidas, con registro, no canceladas), `asistencias, faltasSinJustaCausa, excusas` (**pasan a contar tomas**; con una toma por sesión = sesiones, igual que hoy; NB-2: se documenta en el addendum de BD y en el catálogo de HUs, y todo SP que los expone junto a `sesionesEjecutadas` añade `tomasDictadas`, §2.9), `porcentajeInasistencia` (**pasa a horas**: `ufn_calcular_porcentaje_inasistencia_horas(horasFalta, horasDictadas)`), `codigoPermanencia` (sobre el porcentaje por horas). Columnas nuevas: `tomasDictadas INT, horasDictadas DECIMAL(12,6), horasAsistidas, horasFalta, horasExcusa, horasSinRegistro DECIMAL(12,6), porcentajeAsistenciaHoras DECIMAL(5,2), porcentajeExcusaHoras DECIMAL(5,2), porcentajeSinRegistroHoras DECIMAL(5,2), porcentajeInasistenciaSesiones DECIMAL(5,2)` (fórmula anterior, solo trazabilidad), `umbralAdvertencia DECIMAL(5,2), umbralPerdida DECIMAL(5,2)` (parámetros, para que el cliente no los queme). `horasDictadas` por grupo = Σ `horasSesion` de sesiones vencidas, con registro y no canceladas ([SUPUESTO-B-05]); las horas del estudiante se suman sobre `uv_detalle_asistencia_v2` de esas mismas sesiones |

### 2.7 Procedimientos almacenados — B.1

#### 2.7.1 `usp_validar_sesion_ventana_registro_interno` (MODIFICADO, no congelado)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_validar_sesion_ventana_registro_interno
(
    @idSesion                UNIQUEIDENTIFIER,
    @idCorrelacion           UNIQUEIDENTIFIER,
    @mensajeUsuarioResultado NVARCHAR(4000) OUTPUT,
    @mensajeTecnicoResultado NVARCHAR(4000) OUTPUT,
    @estadoResultado         BIT OUTPUT,
    @toleranciaMinutos       INT = NULL,   -- NUEVO: minutos antes del inicio. NULL o < 0 => 0 (regla SES-01 estricta)
    @margenMinutos           INT = NULL    -- NUEVO: minutos después del fin.  NULL o < 0 => 0
)
```

- Los llamadores actuales (el SP congelado `usp_registrar_asistencias_sesion`, el autónomo) no pasan los nuevos parámetros: siguen con `[inicio, fin)` y sus pruebas (`test_ses01_ventana_asistencia.sql`) no cambian.
- **Paso nuevo 2.5** (para todos los llamadores): si existe `SesionCancelacion` de la sesión → `SES_010`, `estadoResultado = 0`. La lectura de `SesionCancelacion` se hace después del `UPDLOCK, HOLDLOCK` sobre `Sesion` (la cancelación toma el mismo bloqueo, así que registro y cancelación se serializan).
- Paso 4: `@aperturaUtc = DATEADD(MINUTE, −@tol, fechaHoraInicio)`, `@cierreUtc = DATEADD(MINUTE, @margen, fechaHoraFin)`; `SYSUTCDATETIME() < @aperturaUtc` → `SES_007`; `>= @cierreUtc` → `SES_008` (el mensaje técnico incluye tolerancia y margen aplicados).
- Lo invocan con tolerancia (valores leídos de `ASISTENCIA/TOLERANCIA_MINUTOS` y `ASISTENCIA/MARGEN_RETARDO_MINUTOS` por el **llamador**): `usp_abrir_toma_asistencia`, `usp_registrar_asistencias_toma`, `usp_cerrar_toma_asistencia` (validación de marcación), `usp_abrir_qr_toma`, `usp_registrar_asistencia_por_token`. El lote legado sigue estricto (DEC-014).

#### 2.7.2 `usp_cancelar_sesion` (NUEVO, HU047)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_cancelar_sesion
(
    @idSesion          UNIQUEIDENTIFIER,
    @motivo            NVARCHAR(500),
    @idCorrelacion     UNIQUEIDENTIFIER,
    @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL
)
-- Salida: tupla + idSesion, idGrupo, fechaCancelacionUtc, totalEstudiantesActivos
```

1. Correlación (`GEN_00x`); `@idUsuarioEjecutor IS NULL` → `GEN_002`.
2. RBAC `DOCENTE`. 3. Sesión existe (`usp_validar_sesion_exista_por_id_interno` → `SES_001`). 4. Titularidad `'SESION'` (`SEC_002`).
5. `@motivo` recortado con longitud entre `SESION/MOTIVO_CANCELACION_LONGITUD_MINIMA` (10) y `…_MAXIMA` (500) → si no, `SES_013`.
6. Transacción propia o `SAVE TRANSACTION sp_cancelar_sesion`; `SELECT … FROM dbo.Sesion WITH (UPDLOCK, HOLDLOCK) WHERE id = @idSesion`.
7. Ya cancelada → `SES_011` (409, no idempotente: el motivo original se conserva).
8. Tiene `Asistencia` (B.1) **o** `TomaAsistencia` (lo añade B.2 con `CREATE OR ALTER`): si `SYSUTCDATETIME() >= DATEADD(MINUTE, ASISTENCIA/MARGEN_RETARDO_MINUTOS, fechaHoraFin)` → `SES_016` (la sesión terminó con asistencia: se corrige por reclamo); si no → `SES_012`.
9. `INSERT dbo.SesionCancelacion (sesion, tipoCancelacion = (SELECT id FROM TipoCancelacionSesion WHERE esAutomatica = 0), motivo, diaFestivo = NULL, usuarioEjecutor, idCorrelacion)`.
10. Commit; éxito `SES_014`. Se puede cancelar una sesión futura o cualquier sesión sin asistencia registrada, también una pasada ([SUPUESTO-B-10], decisión del orquestador sobre NB-7).

#### 2.7.3 `usp_consultar_destinatarios_sesion_cancelada` (NUEVO, consulta)

`(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER, @idSesion UNIQUEIDENTIFIER)` → `READ_QUERY_RESULTSET` sin paginación (≤ cupo del grupo): RBAC `DOCENTE` + titularidad `'SESION'`; solo si la sesión está cancelada; filas `idEstudiante, idUsuario, nombreCompleto, correo, nombreAsignatura, nombreGrupo, nombreDocente, fechaHoraInicio, fechaHoraFin, motivoCancelacion` de las matrículas `A`. Mismo formato que `usp_consultar_destinatarios_reclamo_asistencia`.

#### 2.7.4 Carga de festivos

```sql
-- Núcleo (no se concede EXECUTE)
CREATE OR ALTER PROCEDURE dbo.usp_internal_cargar_dias_festivos
(
    @anio                     INT,
    @festivosJSON             NVARCHAR(MAX),   -- [{"fecha":"YYYY-MM-DD","nombre":"..."}] exactamente esas 2 claves
    @fuente                   NVARCHAR(40),
    @diferenciasCalculoLocal  INT,
    @idCorrelacion            UNIQUEIDENTIFIER,
    @idUsuarioEjecutor        UNIQUEIDENTIFIER,  -- NULL = job
    @festivosInsertados       INT OUTPUT,
    @festivosActualizados     INT OUTPUT,
    @festivosDesactivados     INT OUTPUT,
    @mensajeUsuarioResultado  NVARCHAR(4000) OUTPUT,
    @mensajeTecnicoResultado  NVARCHAR(4000) OUTPUT,
    @estadoResultado          BIT OUTPUT
)
-- Público, administrador:   usp_cargar_dias_festivos(@anio, @festivosJSON, @fuente, @diferenciasCalculoLocal, @idCorrelacion, @idUsuarioEjecutor = NULL)
-- Público, job (sin usuario, como usp_rotar_token_matricula_automatico):
--                           usp_cargar_dias_festivos_automatico(@anio, @festivosJSON, @fuente, @diferenciasCalculoLocal, @idCorrelacion)
-- Salida de ambos: tupla + anio, totalFestivos, festivosInsertados, festivosActualizados, festivosDesactivados
```

Validaciones (`FES_001` año fuera de `[FESTIVOS/ANIO_MINIMO, FESTIVOS/ANIO_MAXIMO]`; `FES_002` JSON inválido, clave distinta de `fecha`/`nombre`, fecha fuera de `@anio`, fecha repetida o nombre vacío/> 120; `FES_003` total fuera de `[FESTIVOS/MINIMO_POR_ANIO, FESTIVOS/MAXIMO_POR_ANIO]`; `FES_004` fuente fuera de `FESTIVOS/FUENTES_VALIDAS`; `@diferenciasCalculoLocal < 0` → `FES_002`). RBAC `ADMINISTRADOR` en el público de administrador. Transacción propia o savepoint; `SELECT 1 FROM dbo.DiaFestivo WITH (UPDLOCK, HOLDLOCK) WHERE anio = @anio` (serializa job y administrador sobre el mismo año); `MERGE` limitado al año: `NOT MATCHED` → insert; `MATCHED` → `nombre, fuente, estaActivo = 1, fechaCargaUtc, idCorrelacionCarga`; `NOT MATCHED BY SOURCE AND anio = @anio AND estaActivo = 1` → `estaActivo = 0` (nunca `DELETE`: hay FK desde `SesionCancelacion`). Inserta `CargaDiaFestivo`. Éxito `FES_005`. **Idempotente**: dos cargas con el mismo JSON dejan el mismo conjunto activo (segunda carga: 0 insertados, N actualizados, 0 desactivados).

#### 2.7.5 Aplicación de festivos a sesiones

```sql
-- Núcleo (no se concede): marca como canceladas por FESTIVO las sesiones del grupo que caen en un DiaFestivo activo.
CREATE OR ALTER PROCEDURE dbo.usp_internal_aplicar_festivos_grupo
(
    @idGrupo                  UNIQUEIDENTIFIER,
    @soloFuturas              BIT,
    @idCorrelacion            UNIQUEIDENTIFIER,
    @idUsuarioEjecutor        UNIQUEIDENTIFIER,   -- NULL = job / generación automática
    @sesionesCanceladas       INT OUTPUT,
    @sesionesConAsistencia    INT OUTPUT,
    @mensajeUsuarioResultado  NVARCHAR(4000) OUTPUT,
    @mensajeTecnicoResultado  NVARCHAR(4000) OUTPUT,
    @estadoResultado          BIT OUTPUT
)
```

- Fecha local de la sesión: `CAST((s.fechaHoraInicio AT TIME ZONE 'UTC') AT TIME ZONE @zona AS DATE)` con `@zona = TIEMPO/ZONA_HORARIA_SQLSERVER` (`GEN_001` si falta). Solo sesiones con procedencia confirmada (`procedenciaTemporal IS NOT NULL`).
- Candidatas: `s.grupo = @idGrupo`, fecha local ∈ `DiaFestivo` activo, sin `SesionCancelacion`, y (`@soloFuturas = 0` o `fechaHoraInicio > SYSUTCDATETIME()`). Bloqueo `dbo.Sesion WITH (UPDLOCK, HOLDLOCK)` sobre las candidatas.
- Con `Asistencia` o `TomaAsistencia` (la condición sobre tomas la añade B.2) → **no se tocan**, se cuentan en `@sesionesConAsistencia` y, si existe la tabla temporal `#sesionesFestivoConAsistencia (idSesion, idGrupo, fecha, nombreFestivo)` creada por el llamador, se insertan ahí.
- Resto → `INSERT SesionCancelacion (tipo con esAutomatica = 1, motivo = FESTIVOS/PREFIJO_MOTIVO_CANCELACION + DiaFestivo.nombre, diaFestivo, usuarioEjecutor = @idUsuarioEjecutor)`. **Idempotente** (una sesión ya cancelada no es candidata).

Públicos:

| SP | Firma | Reglas |
| :--- | :--- | :--- |
| `usp_aplicar_festivos_grupo` | `(@idGrupo, @soloFuturas BIT = 1, @idCorrelacion, @idUsuarioEjecutor = NULL)` → tupla + `sesionesCanceladas, sesionesConAsistencia` | RBAC `ADMINISTRADOR` y grupo de su institución (`SEC_002` si no); transacción propia/savepoint; éxito `FES_008` |
| `usp_aplicar_festivos_periodo` | `(@idPeriodoAcademico UNIQUEIDENTIFIER = NULL, @anio INT = NULL, @idCorrelacion, @idUsuarioEjecutor = NULL)` → tupla + `gruposProcesados, sesionesCanceladas, sesionesConAsistencia` | Exactamente uno de los dos filtros (`FES_006`); periodo inexistente o de otra institución → `FES_007`/`SEC_002`; con `@anio` procesa los grupos de los periodos de su institución que se cruzan con el año; RBAC `ADMINISTRADOR`; `@soloFuturas = 1`; una transacción por grupo (un grupo con error no deshace los anteriores; el error se cuenta y el resultado es `estadoResultado = 0` con `FES_009` si hubo alguno) |
| `usp_aplicar_festivos_automatico` | `(@anio INT, @idCorrelacion)` → igual que el anterior | Sin usuario (job tras cada carga del año, [SUPUESTO-B-21]); todos los grupos con sesiones en el año |
| `usp_consultar_sesiones_festivo_con_asistencia_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @anio INT, @numeroPagina = 1, @tamanoPagina = 20)` | RBAC `ADMINISTRADOR`, su institución; filas `idSesion, idGrupo, nombreGrupo, nombreAsignatura, nombreDocente, fechaHoraInicio, fecha, nombreFestivo, totalTomas, totalRegistros` + `totalRegistros`: sesiones en festivo que no se cancelaron por tener asistencia ("se reportan", §3.7) |

#### 2.7.6 Generación y precarga

```sql
CREATE OR ALTER PROCEDURE dbo.usp_generar_sesiones_grupo_v2
(
    @idGrupo           UNIQUEIDENTIFIER,
    @idCorrelacion     UNIQUEIDENTIFIER,
    @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL
)
-- Salida: tupla + sesionesCanceladasPorFestivo, sesionesFestivoConAsistencia
```

1. **Fase 1:** `INSERT INTO @resultadoGeneracion EXEC dbo.usp_generar_sesiones_grupo @idGrupo, @idCorrelacion, @idUsuarioEjecutor;` (texto del SP congelado intacto; no usa `INSERT … EXEC` internamente, se verifica en el RED). **No** se exige `@@TRANCOUNT = 0` y no hay `SES_015` (B-6 de REVIEW-1: dentro de `INSERT … EXEC` `@@TRANCOUNT` vale 1 aunque fuera valga 0, así que el requisito no evita el 3915; la ruta feliz funciona dentro de una transacción externa, como ya prueba `test_rec3_falla_intermedia_transaccion.sql:223-224`). Los errores de negocio del SP congelado (RBAC, titularidad, horarios, fechas, zona) ocurren antes de su `BEGIN TRANSACTION` (línea 237) y no hacen `ROLLBACK`: su tupla llega intacta.
2. Si `estadoResultado = 0` → devuelve esa tupla tal cual (misma tupla que el v1).
3. **Fase 2:** transacción propia o `SAVE TRANSACTION sp_generar_sesiones_v2` (§2.0) → `usp_internal_aplicar_festivos_grupo @soloFuturas = 0, @idUsuarioEjecutor = NULL` → commit. Éxito: mensaje del SP congelado (`GEN_004`) + conteos.
4. **CATCH** del v2: `IF XACT_STATE() <> 0 ROLLBACK` (respetando ownership: si la transacción no es propia y está condenada, `THROW`), y el error 3915 (el `ROLLBACK` del `CATCH` del SP congelado dentro del `INSERT … EXEC`) o cualquier otro error de la fase 1 se devuelve como `SYS_001` con la tupla canónica y `ufn_obtener_detalle_error`. Las dos fases son idempotentes; si la segunda falla, repetir la llamada completa deja el estado correcto (R1).
5. El adaptador del backend no necesita `Propagation.NOT_SUPPORTED`.

`usp_precargar_sesiones_grupo_interno` (MODIFICADO, no congelado): al final del paso de inserción llama a `usp_internal_aplicar_festivos_grupo @soloFuturas = 0` dentro de la misma transacción del llamador (crear grupo + horarios + precarga, `GrupoJpaRepository`). El borrado de sesiones futuras que ya no encajan en el horario (`NOT EXISTS Asistencia`, línea 144) añade `NOT EXISTS TomaAsistencia` (B.2) y borra antes la `SesionCancelacion` de esas sesiones (una sesión que deja de existir pierde su cancelación). Las sesiones canceladas que siguen encajando no se borran ni se recrean (idempotencia por `(grupo, fechaHoraInicio, fechaHoraFin)`).

#### 2.7.7 Consultas de sesión que exponen el estado (B.1)

| SP / vista | Cambio |
| :--- | :--- |
| `usp_consultar_sesiones_grupo_paginado` (HU060) | Añade `estaCancelada, codigoTipoCancelacion, motivoCancelacion, nombreDiaFestivo, fechaCancelacionUtc` desde `uv_sesion_estado` |
| `usp_consultar_sesiones_facultad_paginado` (HU145) | Ídem |
| `usp_consultar_dias_festivos` (NUEVO) | `(@idUsuarioEjecutor, @idCorrelacion, @anio INT, @incluirInactivos BIT = 0, @numeroPagina = 1, @tamanoPagina = 50)`; RBAC `ADMINISTRADOR`; filas de `uv_dia_festivo` + `fuenteUltimaCarga, fechaUltimaCargaUtc, diferenciasCalculoLocal` (de `uv_carga_dia_festivo` con `esUltimaCargaAnio = 1`) + `totalRegistros` |
| `usp_consultar_carga_festivos_anio` (NUEVO, job) | `(@anio INT, @idCorrelacion)` sin usuario; una fila `anio, totalActivos, fuenteUltimaCarga, fechaUltimaCargaUtc` (0 si no hay carga) |

### 2.8 Procedimientos almacenados — B.2

#### 2.8.1 Toma vigente en `usp_sincronizar_asistencia_estudiante_interno` (MODIFICADO, no congelado; DEC-013)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_sincronizar_asistencia_estudiante_interno
(
    @idEstudiante            UNIQUEIDENTIFIER,
    @idSesion                UNIQUEIDENTIFIER,
    @codigoEstado            NVARCHAR(5),
    @idCorrelacion           UNIQUEIDENTIFIER,
    @mensajeUsuarioResultado NVARCHAR(4000) OUTPUT,
    @mensajeTecnicoResultado NVARCHAR(4000) OUTPUT,
    @estadoResultado         BIT OUTPUT,
    @idToma                  UNIQUEIDENTIFIER = NULL,  -- NUEVO: toma explícita (lote por toma / QR); NULL = toma vigente
    @registradoPorEstudiante BIT = 0,                  -- NUEVO
    @soloSiNoExiste          BIT = 0,                  -- NUEVO: 1 = no sobrescribe un detalle existente (QR idempotente y cierre)
    @idUsuarioEjecutor       UNIQUEIDENTIFIER = NULL,  -- NUEVO: para docenteApertura de la toma implícita
    @detalleCreado           BIT = NULL OUTPUT         -- NUEVO
)
```

- Pasos 1-4 sin cambio (sesión, matrícula `A` con `UPDLOCK, HOLDLOCK`, `RazonCausa` cerrado `AN/SJC/EX`).
- **Paso 4.5 (toma)**: si `@idToma` no es NULL, debe pertenecer a `@idSesion` (`TOM_001`). Si es NULL: `TomaAsistencia WITH (UPDLOCK, HOLDLOCK) WHERE sesion = @idSesion` → la ABIERTA si existe; si no, la de mayor `numero`; si no hay ninguna, crea la toma 1 (`modo` con `usaCodigoQr = 0`, `estado` con `estaAbierta = 0`, `esImplicita = 1`, `fechaCierreUtc = fechaAperturaUtc = SYSUTCDATETIME()`, `docenteApertura` = docente del ejecutor si lo hay) ([SUPUESTO-B-04]). El índice `UX_TomaAsistencia_Sesion_Numero` impide dos tomas 1 concurrentes (la segunda falla dentro de la misma transacción serializada por el bloqueo de la sesión).
- Paso 5: `Asistencia` igual que hoy (cabecera única por `(estudianteGrupo, sesion)`); `DetalleAsistencia` por `(asistencia, toma)` con `UPDLOCK, HOLDLOCK`; insert con `codigo = NEXT VALUE FOR dbo.seq_detalle_asistencia_codigo`, `toma`, `registradoPorEstudiante`, `fechaRegistroUtc = SYSUTCDATETIME()`; si existe y `@soloSiNoExiste = 0` → update (como hoy, más `fechaRegistroUtc`); si existe y `@soloSiNoExiste = 1` → no escribe, `@detalleCreado = 0`.
- El SP congelado lo sigue llamando con sus 7 parámetros nombrados: escribe en la toma vigente.

#### 2.8.2 Tomas

```sql
CREATE OR ALTER PROCEDURE dbo.usp_abrir_toma_asistencia
(
    @idSesion          UNIQUEIDENTIFIER,
    @codigoModo        NVARCHAR(20),          -- MANUAL | QR (se resuelve contra ModoTomaAsistencia.codigo)
    @idCorrelacion     UNIQUEIDENTIFIER,
    @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL
)
-- Salida: tupla + idToma, numero, codigoModo, usaCodigoQr, fechaAperturaUtc, ventanaCierreUtc, totalTomasSesion, horasToma
```

Pasos: correlación → RBAC `DOCENTE` → sesión existe → titularidad `'SESION'` → modo existe (`TOM_002`) → transacción propia/savepoint → `usp_validar_sesion_ventana_registro_interno` con tolerancia/margen (bloquea `Sesion`; `SES_007/008/009/010`) → `TomaAsistencia WITH (UPDLOCK, HOLDLOCK)` de la sesión: hay una abierta → `TOM_003`; total ≥ `TOMA_ASISTENCIA/MAXIMO_TOMAS_POR_SESION` → `TOM_004` → insert con `numero = MAX + 1`, `estado` con `estaAbierta = 1`, `docenteApertura` = docente del usuario → commit → `TOM_008`.

```sql
CREATE OR ALTER PROCEDURE dbo.usp_cerrar_toma_asistencia
(
    @idToma            UNIQUEIDENTIFIER,
    @marcarAusentes    BIT = NULL,            -- NULL => ModoTomaAsistencia.marcaAusentesAlCerrar
    @idCorrelacion     UNIQUEIDENTIFIER,
    @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL
)
-- Salida: tupla + idToma, idSesion, idGrupo, fechaCierreUtc, totalAusentesMarcados, totalFaltantes, yaEstabaCerrada
```

Pasos: correlación → RBAC `DOCENTE` → toma existe (`TOM_001`) → titularidad `'SESION'` de su sesión → transacción → bloqueo `Sesion` (lectura `UPDLOCK, HOLDLOCK`; **sin** exigir ventana para cerrar) → toma `UPDLOCK, HOLDLOCK` → si ya está cerrada: éxito idempotente `TOM_011`, `yaEstabaCerrada = 1`, nada se escribe → cierra el token activo de la toma (`fechaCierreUtc`) → si `@marcarAusentes = 1` y la ventana con margen sigue abierta: para cada matrícula `A` del grupo sin detalle en la toma, `usp_sincronizar_asistencia_estudiante_interno(@codigoEstado = ASISTENCIA/CODIGO_RAZON_SIN_JUSTA_CAUSA, @idToma, @soloSiNoExiste = 1)` (conjunto: un `INSERT … SELECT` en un `usp_internal_marcar_ausentes_toma` para no iterar 40 veces) → `totalAusentesMarcados`, `estado` cerrado, `fechaCierreUtc`, `idCorrelacionCierre` → commit → `TOM_009`. Si la ventana venció no marca ausentes (la toma se cierra igual).

```sql
-- Cierre por el job ([SUPUESTO-B-09]); sin usuario
CREATE OR ALTER PROCEDURE dbo.usp_cerrar_tomas_vencidas (@idCorrelacion UNIQUEIDENTIFIER)
-- Salida: una fila por toma cerrada: idToma, idSesion, idGrupo, totalAusentesMarcados (máx. TOMA_ASISTENCIA/LOTE_CIERRE_AUTOMATICO por pasada)
```

Toma abierta cuya sesión cumple `SYSUTCDATETIME() >= DATEADD(MINUTE, MARGEN_RETARDO_MINUTOS, fechaHoraFin)` o está cancelada: se cierra (una transacción por toma, `READPAST` en la selección para que dos instancias no tomen la misma) y, si su modo marca ausentes, inserta `SJC` a los activos sin registro **antes** de cerrar (se permite aunque la ventana ya venció: es el cierre automático de la toma, no una edición).

```sql
CREATE OR ALTER PROCEDURE dbo.usp_registrar_asistencias_toma
(
    @idToma            UNIQUEIDENTIFIER,
    @asistenciaJSON    NVARCHAR(MAX),        -- [{"idEstudiante":"uuid","estado":"AN|SJC|EX"}] (mismas reglas ATT_001/002/003/RC_001/EST_004 del lote)
    @idCorrelacion     UNIQUEIDENTIFIER,
    @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL
)
-- Salida: tupla + idToma, idSesion, idGrupo, totalRegistros
```

Pasos: correlación → RBAC `DOCENTE` → toma existe → titularidad `'SESION'` → JSON (exactamente 2 claves, no vacío, sin duplicados, matrícula `A`) → transacción → ventana con tolerancia/margen (bloquea `Sesion`) → toma `UPDLOCK, HOLDLOCK` (abierta **o** cerrada: la cerrada admite corrección dentro de la ventana, [SUPUESTO-B-08]) → por estudiante `usp_sincronizar_…(@idToma, @registradoPorEstudiante = 0)` → re-valida ventana al confirmar (igual que SES-01) → commit → `TOM_010`. Lote atómico.

#### 2.8.3 QR de asistencia (DEC-015)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_abrir_qr_toma
(
    @idToma            UNIQUEIDENTIFIER,
    @tokenHash         VARBINARY(32),
    @pin               NCHAR(6),
    @idCorrelacion     UNIQUEIDENTIFIER,
    @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL
)
-- Salida: tupla + idTokenAsistencia, idToma, idSesion, idGrupo, fechaRotacionUtc, fechaExpiracionUtc, rotacionSegundos
```

RBAC `DOCENTE` → toma existe → titularidad → modo con `usaCodigoQr = 1` (si no `AQR_003`) → transacción → ventana con tolerancia/margen (bloquea `Sesion`) → toma abierta (`AQR_005`) → `TokenAsistenciaToma WITH (UPDLOCK, HOLDLOCK)`: PIN igual a un `pin` activo o a un `pinAnterior` con `anteriorVigente` → `AQR_006` (el backend genera otro y reintenta) → cierra el token activo previo de la toma (re-proyección) → inserta el nuevo (`fechaEmisionUtc = fechaRotacionUtc = SYSUTCDATETIME()`, `fechaExpiracionUtc = DATEADD(MINUTE, MARGEN_RETARDO_MINUTOS, fechaHoraFin)`) → commit → `AQR_012`.

```sql
-- Núcleo de rotación (no se concede)
CREATE OR ALTER PROCEDURE dbo.usp_internal_rotar_token_asistencia
(
    @idCorrelacion UNIQUEIDENTIFIER, @idToma UNIQUEIDENTIFIER, @tokenHash VARBINARY(32), @pin NCHAR(6),
    @forzar BIT, @idUsuarioManual UNIQUEIDENTIFIER,
    @mensajeUsuarioResultado NVARCHAR(4000) OUTPUT, @mensajeTecnicoResultado NVARCHAR(4000) OUTPUT, @estadoResultado BIT OUTPUT,
    @idTokenAsistencia UNIQUEIDENTIFIER OUTPUT, @idDocenteEmisor UNIQUEIDENTIFIER OUTPUT, @idGrupo UNIQUEIDENTIFIER OUTPUT,
    @fechaRotacionUtc DATETIME2(0) OUTPUT, @fechaExpiracionUtc DATETIME2(0) OUTPUT, @rotado BIT OUTPUT
)
-- Mueve tokenHash/pin vigentes a *Anterior y guarda los nuevos; con @forzar = 0 solo rota si debeRotar (otra instancia
-- pudo rotar ya: @rotado = 0, sin error). Token cerrado/expirado -> AQR_005.
-- Públicos:
--   usp_rotar_token_asistencia_toma(@idToma, @tokenHash, @pin, @idCorrelacion, @idUsuarioEjecutor = NULL)  -- manual, DOCENTE titular, @forzar = 1
--   usp_rotar_token_asistencia_automatico(@idToma, @tokenHash, @pin, @forzar BIT = 0, @idCorrelacion)      -- job
--   Salida de ambos: tupla + idTokenAsistencia, idToma, idGrupo, idDocenteEmisor, fechaRotacionUtc, fechaExpiracionUtc, rotado
CREATE OR ALTER PROCEDURE dbo.usp_consultar_tomas_qr_por_rotar (@idCorrelacion UNIQUEIDENTIFIER)
-- TOP (ASISTENCIA_QR/LOTE_ROTACION) de uv_token_asistencia_toma WHERE debeRotar = 1: idToma, idGrupo, idDocenteEmisor
CREATE OR ALTER PROCEDURE dbo.usp_cerrar_qr_toma (@idToma, @idCorrelacion, @idUsuarioEjecutor = NULL)
-- DOCENTE titular; cierra el token activo (la toma sigue abierta). Sin token activo: éxito idempotente. AQR_013.
```

```sql
-- Núcleo de resolución (no se concede)
CREATE OR ALTER PROCEDURE dbo.usp_internal_resolver_token_asistencia
(
    @tokenHash VARBINARY(32) = NULL, @pin NCHAR(6) = NULL,
    @idTokenAsistencia UNIQUEIDENTIFIER OUTPUT, @idToma UNIQUEIDENTIFIER OUTPUT,
    @idSesion UNIQUEIDENTIFIER OUTPUT, @idGrupo UNIQUEIDENTIFIER OUTPUT, @codigoRechazo VARCHAR(20) OUTPUT
)
-- Exactamente uno de los dos (si no AQR_007). Busca en el vigente (activo, no expirado) y en el anterior con anteriorVigente.
-- Lectura SIN UPDLOCK sobre el token (READ COMMITTED): 40 lecturas concurrentes no se serializan sobre la fila del token.
-- Cualquier token/PIN desconocido, cerrado o expirado devuelve el mismo AQR_001 (no revela si existió).

CREATE OR ALTER PROCEDURE dbo.usp_registrar_asistencia_por_token
(
    @tokenHash         VARBINARY(32) = NULL,
    @pin               NCHAR(6) = NULL,
    @idCorrelacion     UNIQUEIDENTIFIER,
    @idUsuarioEjecutor UNIQUEIDENTIFIER = NULL     -- Usuario.id del estudiante autenticado
)
-- Salida: tupla + idToma, idSesion, idGrupo, nombreAsignatura, nombreGrupo, numeroSesion, numeroToma, yaRegistrado, fechaRegistroUtc
```

Pasos: correlación → `@idUsuarioEjecutor IS NULL` → `GEN_002` → RBAC `ESTUDIANTE` → estudiante del usuario → `usp_internal_resolver_token_asistencia` (`AQR_001`/`AQR_007`) → transacción propia/savepoint → ventana con tolerancia/margen (bloquea `Sesion`; cancelada `SES_010`) → toma abierta (`AQR_005`) → matrícula `A` del estudiante en el grupo de la toma (`AQR_004`; un estudiante de otro grupo nunca escribe) → `usp_sincronizar_…(@codigoEstado = ASISTENCIA/CODIGO_RAZON_PRESENTE, @idToma, @registradoPorEstudiante = 1, @soloSiNoExiste = 1)` → si ya había detalle: éxito con `yaRegistrado = 1` y `AQR_008` (idempotente, no cambia una marca previa del docente) → commit → `AQR_009`. La red (CIDR), el interruptor y los límites los aplica el backend antes de llamar (DEC-015).

Rendimiento (NB-4): la ventana toma `Sesion WITH (UPDLOCK, HOLDLOCK)`, así que los 40 registros de un grupo se serializan (≈ 10-15 ms cada uno). Se mantiene ese bloqueo y la prueba de concurrencia mide p50/p95/máximo por grupo. **Alternativa aprobada de antemano** si p95 ≥ 500 ms: solo en `usp_registrar_asistencia_por_token`, validar la ventana con una lectura `WITH (HOLDLOCK)` (compartida) en lugar de `UPDLOCK` (parámetro interno `@bloqueoCompartido BIT = 0` de `usp_validar_sesion_ventana_registro_interno`); la cancelación (U/X) sigue serializada contra los registros y el registro no actualiza `Sesion`, así que no hay conversión de bloqueo.

#### 2.8.4 Consultas de B.2 (`READ_QUERY_RESULTSET`)

| SP | Firma | RBAC / ámbito | Filas |
| :--- | :--- | :--- | :--- |
| `usp_consultar_tomas_sesion` | `(@idUsuarioEjecutor, @idCorrelacion, @idSesion)` | `DOCENTE` titular | `uv_toma_asistencia` de la sesión + `ventanaAperturaUtc, ventanaCierreUtc, ventanaAbierta, estaSesionCancelada, motivoCancelacion` (de `uv_sesion_estado`), orden `numero` |
| `usp_consultar_faltantes_toma_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @idToma, @numeroPagina = 1, @tamanoPagina = 50)` | `DOCENTE` titular | `uv_faltantes_toma`, orden `nombreCompletoEstudiante` |
| `usp_consultar_asistencias_toma_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @idToma, @numeroPagina = 1, @tamanoPagina = 50)` | `DOCENTE` titular | Matrículas `A` del grupo con su detalle en la toma (LEFT): `idEstudiante, nombreCompletoEstudiante, codigoRazonCausa, registradoPorEstudiante, fechaRegistroUtc` |
| `usp_consultar_resumen_asistencia_grupo_docente_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @idGrupo, @numeroPagina = 1, @tamanoPagina = 50)` | `DOCENTE` titular | Columnas de `uv_resumen_asistencia_estudiante_grupo` + `nombreCompletoEstudiante` (sábana, F-DOC-004) |
| `usp_consultar_resumen_asistencia_estudiante` | `(@idUsuarioEjecutor, @idCorrelacion)` | `ESTUDIANTE`, solo sus matrículas | `uv_resumen_asistencia_estudiante_grupo` del estudiante (F-EST-002); sin paginación (≤ materias del periodo) |

### 2.9 Consumidores modificados por las tomas y las horas (B.2)

Ninguno está en un manifiesto, salvo los marcados con (M), que **no se modifican**.

| Objeto | Cambio |
| :--- | :--- |
| `usp_resolver_solicitud_revision_asistencia` | Con varias tomas: aprobar exige al menos un detalle de la asistencia con `asistio = 0` y `SJC` (si no `REV_003/REV_004`, igual que hoy) y pasa a `EX` **todos** los detalles `SJC` de esa asistencia (el `TOP 1` de la línea 170 se reemplaza por un agregado) |
| `usp_consultar_detalle_solicitud_revision_docente` | El `LEFT JOIN DetalleAsistencia` (línea 123) se reemplaza por `OUTER APPLY` sobre `uv_asistencia_sesion_horas` (estado consolidado + horas): sin filas duplicadas |
| `usp_consultar_solicitudes_revision_docente` (M, LB-004D) | No lee detalle: sin cambio. Se prueba que no duplica |
| `usp_radicar_solicitud_revision_asistencia_v2` (M, LB-004D) | Solo crea la cabecera `Asistencia`: sin cambio |
| `usp_consultar_bitacora_estudiante_programa` (HU067) | El `OUTER APPLY TOP 1` del detalle pasa a `uv_asistencia_sesion_horas` (estado consolidado + `horasFalta`) |
| `usp_consultar_tendencia_ausentismo` (HU134) | **Diferido a D: debe pasar a horas.** Cambio mínimo en B para no duplicar: la lectura de `uv_detalle_asistencia` (línea 67) pasa a `uv_asistencia_sesion_horas` contando la sesión como falta si `codigoRazonCausaConsolidado = SJC` (con una toma por sesión, idéntico a hoy) |
| `usp_consultar_asistencias_sesion_paginado` (coordinador) | Una fila por estudiante y sesión con el estado consolidado; columnas `idDetalleAsistencia/codigoDetalleAsistencia` pasan a los de la **última** toma (compatibilidad) + `totalTomas, horasAsistidas, horasFalta, horasExcusa` |
| `usp_consultar_kpis_coordinador` (HU065/066) | Cumplimiento sin canceladas (vía la vista); semáforo sobre el porcentaje por horas (vía la vista) |
| `usp_consultar_kpis_decano` (HU102/106) | `porcentajeAusentismo = 100 · Σ horasFalta / Σ horasDictadas` de las matrículas `A` de la facultad (antes faltas/sesiones); `sesionesEjecutadas` sin cambio de nombre (F-DEC-013 queda fuera) |
| `usp_consultar_kpis_institucion` (HU133/138) | Ídem + cumplimiento sin canceladas |
| `usp_consultar_comparativa_facultades` / `_programas_facultad` (HU139/103) | **Diferido a D: deben pasar a horas.** Cambio mínimo en B: la fórmula `100 · faltas / sesiones` lee `sesionesConFaltaSinJustaCausa` (columna de sesión de `uv_resumen_*`) en lugar de `faltasSinJustaCausa` (que pasa a contar tomas), para no mezclar unidades; con una toma por sesión el resultado es idéntico |
| `usp_consultar_consolidado_asistencia_grupos_paginado` (HU061, F-COO-007) | **Diferido a D: debe pasar a horas** (y con ello F-COO-007: `porcentajeSinRegistro` explícito). Cambio mínimo en B: sus conteos leen las columnas de sesión `sesionesAsistidas`, `sesionesConFaltaSinJustaCausa`, `sesionesConExcusa` de `uv_resumen_*`; resultado idéntico al actual con una toma |
| `usp_consultar_historial_estudiante`, `usp_consultar_resumen_asistencia_estudiante_programa`, `usp_consultar_alerta_temprana_programa`, `usp_consultar_ficha_estudiante_programa` | Leen `uv_resumen_*`: heredan el porcentaje por horas; añaden `tomasDictadas, horasDictadas, horasFalta` a su salida (NB-2: `asistencias/faltasSinJustaCausa/excusas` cuentan tomas, `sesionesEjecutadas` cuenta sesiones) |
| `usp_cancelar_sesion`, `usp_internal_aplicar_festivos_grupo`, `usp_precargar_sesiones_grupo_interno` | Añaden la condición `NOT EXISTS TomaAsistencia` (§2.7) |
| `usp_ejecutar_cierre_masivo_periodo` | **Cambio mínimo (B-7):** `COUNT(da.id)` → `COUNT(DISTINCT a.sesion)` en el `SELECT` y en el `HAVING` (líneas 113-128), sin otro cambio de regla: varias tomas ausentes de una misma sesión cuentan como una sesión. C lo reescribe por horas |
| `usp_registrar_asistencia_estudiante_autonomo` | Sin cambio de texto ni de permisos en B; solo pierde su consumidor del backend ([SUPUESTO-B-18]) |

Columnas de sesión añadidas a `uv_resumen_asistencia_estudiante_grupo` para los consumidores diferidos: `sesionesAsistidas`, `sesionesConFaltaSinJustaCausa`, `sesionesConExcusa` (conteo de sesiones vencidas, no canceladas, por `codigoRazonCausaConsolidado` de `uv_asistencia_sesion_horas`).

### 2.10 Mensajes nuevos (semillas MERGE en `CatalogoMensajeUsuario` y `CatalogoMensajeTecnico`)

Archivos: `DB:schema/seed/34_mensajes_sesion_cancelada_festivos.sql` (B.1) y `DB:schema/seed/35_mensajes_toma_asistencia_qr.sql` (B.2). Tipo/severidad con el patrón de `04_mensaje.sql`. `DB:scripts/generar-catalogo-mensajes.ps1 -Check` debe pasar; el catálogo de MessageUcoLab se regenera con `INFRA:components/messages/build-message-catalog.py`.

| Código | Tipo / severidad | Mensaje de usuario | Mensaje técnico (plantilla) | HTTP |
| :--- | :--- | :--- | :--- | :--- |
| `SES_010` | BUSINESS_ERROR / MEDIO | La sesión fue cancelada; no admite registro de asistencia. | Sesión [{}] cancelada (SesionCancelacion existe); operación rechazada sin escrituras. | 409, `code = ERR_SESION_CANCELADA` (NB-1) |
| `SES_011` | BUSINESS_ERROR / BAJO | La sesión ya estaba cancelada. | Sesión [{}] con SesionCancelacion previa; se conserva el motivo original. | 409 |
| `SES_012` | BUSINESS_ERROR / MEDIO | No es posible cancelar una sesión que ya tiene asistencia registrada. | Sesión [{}] con Asistencia o TomaAsistencia; cancelación rechazada. | 409 |
| `SES_013` | VALIDATION_ERROR / BAJO | El motivo de cancelación debe tener entre {} y {} caracteres. | Longitud de @motivo fuera de SESION/MOTIVO_CANCELACION_LONGITUD_*. | 400 |
| `SES_014` | SUCCESS / BAJO | La sesión fue cancelada y se avisó a los estudiantes. | SesionCancelacion creada para [{}] tipo [{}]. | 200 |
| `SES_016` | BUSINESS_ERROR / MEDIO | La sesión ya terminó y tiene asistencia registrada; no se puede cancelar. Las correcciones se hacen por reclamo. | Sesión [{}] con Asistencia o TomaAsistencia y SYSUTCDATETIME() >= fin + MARGEN_RETARDO_MINUTOS; cancelación rechazada. | 409 |
| `FES_001` | VALIDATION_ERROR / BAJO | El año de festivos no es válido. | @anio [{}] fuera de FESTIVOS/ANIO_MINIMO..ANIO_MAXIMO. | 400 |
| `FES_002` | VALIDATION_ERROR / MEDIO | El listado de festivos recibido no es válido. | @festivosJSON inválido: {}. | 400 (502 si viene de un proveedor) |
| `FES_003` | VALIDATION_ERROR / MEDIO | El listado de festivos no tiene una cantidad válida de días. | Total [{}] fuera de FESTIVOS/MINIMO_POR_ANIO..MAXIMO_POR_ANIO. | 502 |
| `FES_004` | VALIDATION_ERROR / MEDIO | La fuente de festivos no es válida. | @fuente [{}] no está en FESTIVOS/FUENTES_VALIDAS. | 400 |
| `FES_005` | SUCCESS / BAJO | Se cargaron {} días festivos de {}. | Carga [{}]: insertados {}, actualizados {}, desactivados {}. | 200 |
| `FES_006` | VALIDATION_ERROR / BAJO | Indica el periodo académico o el año, no ambos. | @idPeriodoAcademico y @anio: exactamente uno. | 400 |
| `FES_007` | BUSINESS_ERROR / BAJO | El periodo académico no existe. | Periodo [{}] inexistente. | 404 |
| `FES_008` | SUCCESS / BAJO | Se cancelaron {} sesiones por festivo; {} sesiones con asistencia quedaron sin cambios. | Aplicación de festivos grupo/periodo [{}]. | 200 |
| `FES_009` | BUSINESS_ERROR / MEDIO | Algunos grupos no se pudieron actualizar con los festivos. | {} grupos con error; ver log con la correlación. | 500 |
| `FES_010` | TECHNICAL_ERROR / ALTO | No fue posible obtener los festivos del año; se usó el cálculo local. | Proveedores [{}] fallaron; respaldo CALCULO_LOCAL. (solo backend, informativo) | — |
| `TOM_001` | BUSINESS_ERROR / BAJO | La toma de asistencia no existe. | Toma [{}] inexistente o de otra sesión. | 404 |
| `TOM_002` | VALIDATION_ERROR / BAJO | El modo de la toma no es válido. | @codigoModo [{}] no existe en ModoTomaAsistencia. | 400 |
| `TOM_003` | BUSINESS_ERROR / BAJO | Ya hay una toma abierta en esta sesión; ciérrala antes de abrir otra. | Sesión [{}] con toma abierta [{}]. | 409 |
| `TOM_004` | BUSINESS_ERROR / BAJO | La sesión ya tiene el máximo de {} tomas. | TOMA_ASISTENCIA/MAXIMO_TOMAS_POR_SESION alcanzado en [{}]. | 409 |
| `TOM_008` | SUCCESS / BAJO | Toma {} abierta. | TomaAsistencia [{}] abierta modo [{}]. | 201 |
| `TOM_009` | SUCCESS / BAJO | Toma cerrada. {} estudiantes quedaron como ausentes. | TomaAsistencia [{}] cerrada; ausentes marcados {}. | 200 |
| `TOM_010` | SUCCESS / BAJO | Asistencia de la toma guardada. | Lote de toma [{}] con {} registros. | 200 |
| `TOM_011` | SUCCESS / BAJO | La toma ya estaba cerrada. | TomaAsistencia [{}] ya cerrada; sin escrituras. | 200 |
| `AQR_001` | BUSINESS_ERROR / BAJO | El código QR o el PIN no es válido o ya venció. Pide el PIN vigente al docente. | Token/PIN sin coincidencia vigente. | 404 |
| `AQR_002` | SECURITY_ERROR / MEDIO | Debes estar conectado a la red Wi-Fi del campus para registrar tu asistencia. | IP [{}] fuera de RED/CIDRS_CAMPUS. (backend) | 403 |
| `AQR_003` | BUSINESS_ERROR / BAJO | Esta toma es manual; no admite código QR. | Toma [{}] con usaCodigoQr = 0. | 409 |
| `AQR_004` | BUSINESS_ERROR / BAJO | No estás matriculado en el grupo de esta clase. | Estudiante [{}] sin matrícula A en grupo [{}]. | 403 |
| `AQR_005` | BUSINESS_ERROR / BAJO | La toma de asistencia ya se cerró. | Toma/token [{}] cerrado o expirado. | 409 |
| `AQR_006` | TECHNICAL_ERROR / BAJO | No fue posible generar el código. Intenta de nuevo. | PIN [{}] repetido entre activos/anteriores vigentes; reintentar. | 409 (el backend reintenta) |
| `AQR_007` | VALIDATION_ERROR / BAJO | Escanea el código QR o digita el PIN. | Se requiere exactamente uno de @tokenHash o @pin. | 400 |
| `AQR_008` | SUCCESS / BAJO | Tu asistencia a esta toma ya estaba registrada. | Detalle existente para estudiante [{}] toma [{}]; sin cambios. | 200 |
| `AQR_009` | SUCCESS / BAJO | ¡Listo! Tu asistencia quedó registrada. | Asistencia AN por token: estudiante [{}] toma [{}]. | 201 |
| `AQR_010` | BUSINESS_ERROR / BAJO | El registro de asistencia por QR no está disponible. | ASISTENCIA_QR/HABILITADA != true. (backend) | 404 |
| `AQR_011` | SECURITY_ERROR / BAJO | Hiciste demasiados intentos. Espera un minuto e intenta de nuevo. | Límite [{}] superado para clave [{}]. (backend; envuelve TOO_MANY_REQUESTS) | 429 |
| `AQR_012` | SUCCESS / BAJO | Código QR listo para proyectar. | Token de asistencia [{}] emitido para toma [{}]. | 201 |
| `AQR_013` | SUCCESS / BAJO | Se dejó de proyectar el código QR. | Token de la toma [{}] cerrado. | 200 |

Los códigos `TOM_005..TOM_007` y `SES_015` (retirado por B-6) quedan reservados (no se usan). Los mensajes "(backend)" se siembran igual en la BD porque el backend los resuelve por `MessageCatalogPort`.

### 2.11 Parámetros nuevos (semillas MERGE, patrón `29_parametros_matricula_qr.sql`: no pisan `valor` administrado)

`DB:schema/seed/34_parametros_sesion_festivos.sql` (B.1):

| Grupo | Clave | Valor = defecto | Tipo |
| :--- | :--- | :--- | :--- |
| `SESION` | `MOTIVO_CANCELACION_LONGITUD_MINIMA` | `10` | INT |
| `SESION` | `MOTIVO_CANCELACION_LONGITUD_MAXIMA` | `500` | INT |
| `FESTIVOS` | `HABILITADO` | `true` | BOOLEAN |
| `FESTIVOS` | `PROVEEDOR_PRINCIPAL` | `CALENDARIOS_NACIONALES` | STRING |
| `FESTIVOS` | `ORDEN_RESPALDO` | `FERIADOS_IO,CALCULO_LOCAL` | STRING |
| `FESTIVOS` | `FUENTES_VALIDAS` | `CALENDARIOS_NACIONALES,FERIADOS_IO,CALCULO_LOCAL` | STRING |
| `FESTIVOS` | `URL_CALENDARIOS_NACIONALES` | `https://calendariosnacionales.com/co/v1/{anio}/nacionales.json` | STRING |
| `FESTIVOS` | `URL_FERIADOS_IO` | `https://api.feriados.io/v1/CO/holidays/{anio}` | STRING |
| `FESTIVOS` | `NOMBRE_SECRETO_FERIADOS_IO` | `feriados-io-api-key` (nombre del secreto en Key Vault, **no** el secreto) | STRING |
| `FESTIVOS` | `TIMEOUT_SEGUNDOS` | `10` | INT |
| `FESTIVOS` | `ANIOS_ADELANTE` | `1` | INT |
| `FESTIVOS` | `ANIO_MINIMO` / `ANIO_MAXIMO` | `2000` / `2100` | INT |
| `FESTIVOS` | `MINIMO_POR_ANIO` / `MAXIMO_POR_ANIO` | `15` / `25` | INT |
| `FESTIVOS` | `PREFIJO_MOTIVO_CANCELACION` | `Día festivo: ` | STRING |
| `FESTIVOS` | `ATRIBUCION_TEXTO` | `Fuente: Calendarios Nacionales` | STRING |
| `FESTIVOS` | `ATRIBUCION_URL` | `https://calendariosnacionales.com` | STRING |

`DB:schema/seed/35_parametros_toma_asistencia_qr.sql` (B.2):

| Grupo | Clave | Valor = defecto | Tipo |
| :--- | :--- | :--- | :--- |
| `TOMA_ASISTENCIA` | `MAXIMO_TOMAS_POR_SESION` | `4` | INT |
| `TOMA_ASISTENCIA` | `LOTE_CIERRE_AUTOMATICO` | `200` | INT |
| `ASISTENCIA` | `CODIGO_RAZON_PRESENTE` / `CODIGO_RAZON_SIN_JUSTA_CAUSA` / `CODIGO_RAZON_EXCUSA` | `AN` / `SJC` / `EX` | STRING |
| `ASISTENCIA_QR` | `HABILITADA` | `true` | BOOLEAN |
| `ASISTENCIA_QR` | `ROTACION_SEGUNDOS` | `60` | INT |
| `ASISTENCIA_QR` | `TOLERANCIA_SEGUNDOS` | `60` | INT |
| `ASISTENCIA_QR` | `LOTE_ROTACION` | `200` | INT |
| `ASISTENCIA_QR` | `LIMITE_FALLIDOS_IP_POR_MINUTO` (cuenta solo intentos rechazados por IP, [SUPUESTO-B-12]) | `600` | INT |
| `ASISTENCIA_QR` | `LIMITE_TOKEN_POR_MINUTO` | `120` | INT |
| `ASISTENCIA_QR` | `LIMITE_ESTUDIANTE_POR_MINUTO` | `6` | INT |
| `ASISTENCIA_QR` | `URL_BASE_FRONTEND` | `http://localhost:4200` | STRING |

Reutilizados sin cambio de valor: `ASISTENCIA/TOLERANCIA_MINUTOS` (15) y `ASISTENCIA/MARGEN_RETARDO_MINUTOS` (30), que pasan a tener consumidor; `ASISTENCIA/UMBRAL_ALERTA_*`; `RED/CIDRS_CAMPUS`; `RED/PROXIES_CONFIABLES`; `TIEMPO/ZONA_HORARIA_SQLSERVER`. DEC-018: cada parámetro que lee el backend tiene en código un valor por defecto igual a la semilla, y el `.env` de los worktrees fija `APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=sqlserver`.

### 2.12 Plantilla de notificación `SESION_CANCELADA` (B.1)

Semilla `DB:schema/seed/34_plantilla_sesion_cancelada.sql` (patrón `26_plantillas_notificacion.sql`, MERGE en `PlantillaNotificacion` + `PlantillaNotificacionMarcador`): tipo `SESION_CANCELADA`, asunto `Clase cancelada: {asignatura} ({fecha})`, cuerpo con marcadores `estudiante, asignatura, grupo, fecha, horaInicio, horaFin, motivo, docente`. Mismo texto por defecto en `PlantillaPorDefectoCatalogo` (backend). El tipo de cancelación FESTIVO **no** notifica (se crea al generar el grupo, antes de que haya estudiantes).

### 2.13 Permisos (`GRANT`)

- `DB:schema/security/rol_asistencias_runtime_culm001_b1.sql`: `GRANT EXECUTE` (con guard `IF OBJECT_ID(...,'P') IS NOT NULL`) a `usp_cancelar_sesion`, `usp_consultar_destinatarios_sesion_cancelada`, `usp_cargar_dias_festivos`, `usp_cargar_dias_festivos_automatico`, `usp_aplicar_festivos_grupo`, `usp_aplicar_festivos_periodo`, `usp_aplicar_festivos_automatico`, `usp_consultar_sesiones_festivo_con_asistencia_paginado`, `usp_consultar_dias_festivos`, `usp_consultar_carga_festivos_anio`, `usp_generar_sesiones_grupo_v2`. Las vistas nuevas se conceden por el bucle `uv_*` existente de `rol_asistencias_runtime.sql` (archivo en manifiesto: **no se toca**); si el bucle no cubre vistas creadas después, el archivo de tema añade `GRANT SELECT` explícito (se verifica en el RED con `test_public_objects.sql`).
- `DB:schema/security/rol_asistencias_runtime_culm001_b2.sql`: `usp_abrir_toma_asistencia`, `usp_cerrar_toma_asistencia`, `usp_cerrar_tomas_vencidas`, `usp_registrar_asistencias_toma`, `usp_abrir_qr_toma`, `usp_rotar_token_asistencia_toma`, `usp_rotar_token_asistencia_automatico`, `usp_consultar_tomas_qr_por_rotar`, `usp_cerrar_qr_toma`, `usp_registrar_asistencia_por_token`, `usp_consultar_tomas_sesion`, `usp_consultar_faltantes_toma_paginado`, `usp_consultar_asistencias_toma_paginado`, `usp_consultar_resumen_asistencia_grupo_docente_paginado`, `usp_consultar_resumen_asistencia_estudiante`. **Sin `REVOKE`** sobre `usp_registrar_asistencia_estudiante_autonomo` (B-5: lo concede `rol_asistencias_runtime.sql`, congelado, y lo exige `test/verify_runtime_role_login.ps1:31`; pasa al paquete D, [SUPUESTO-B-18]).
- Nunca se conceden `usp_internal_*` ni `*_interno`. `test_public_objects.sql` se amplía con la lista.

### 2.14 Migraciones `up`/`down` (idempotentes, patrón `11_hu176b_*` y `12_categoria_justificacion_*`)

Los objetos programables (vistas, funciones, SP, semillas, permisos) se despliegan con `deploy_schema.ps1` (CREATE OR ALTER / MERGE). Las migraciones cubren el cambio de datos y estructura de una BD existente.

**`DB:migrations/15_culm001_b1_sesion_cancelada_festivos_up.sql`**: crea `TipoCancelacionSesion`, `DiaFestivo`, `CargaDiaFestivo`, `SesionCancelacion` con sus índices y FKs (`IF OBJECT_ID … IS NULL`); MERGE de las 2 filas de `TipoCancelacionSesion`; `CREATE OR ALTER` de las vistas de B.1; `GRANT SELECT` condicionado. No carga festivos (no hay red en la BD; [SUPUESTO-B-21]).
**`15_…_down.sql`**: `DROP` de los SP nuevos de B.1; restaura `usp_validar_sesion_ventana_registro_interno`, `usp_precargar_sesiones_grupo_interno`, `uv_cumplimiento_sesion_grupo` y las dos consultas de sesiones a su texto anterior (copiado literal en el `down`); `DROP VIEW` nuevas; `DROP TABLE SesionCancelacion, CargaDiaFestivo, DiaFestivo, TipoCancelacionSesion` (en ese orden). Las sesiones canceladas vuelven a ser sesiones normales (sin registros, porque nunca pudieron tenerlos). Borra los parámetros, mensajes y la plantilla de B.1 **solo si** `valor = valorDefecto` (no borra valores administrados) y marca como canceladas en `NotificacionSaliente` las pendientes de tipo `SESION_CANCELADA` (patrón DEC-010).

**`DB:migrations/16_culm001_b2_tomas_asistencia_qr_up.sql`**:
1. Crea `ModoTomaAsistencia`, `EstadoTomaAsistencia` (+ filas), `TomaAsistencia`, `TokenAsistenciaToma` con índices/FKs.
2. Añade `DetalleAsistencia.toma` (NULL), `registradoPorEstudiante`, `fechaRegistroUtc`; crea la secuencia `seq_detalle_asistencia_codigo` con `START WITH ISNULL(MAX(codigo), 0) + 1` dinámico (`sp_executesql`), igual que `DetalleAsistencia.sql`.
3. **Conversión en una transacción** (`SET XACT_ABORT ON`), solo si `COLUMNPROPERTY(…,'toma','AllowsNull') = 1`, en este orden exacto (B-1; decisión del orquestador):
   1. Aborta (`THROW 50010`) si hay más de un detalle por asistencia (no debería: hoy lo impide `UX_DetalleAsistencia_Asistencia`).
   2. **Backfill**: por cada sesión con al menos un `DetalleAsistencia` sin toma → `INSERT TomaAsistencia (numero = 1, modo MANUAL [usaCodigoQr = 0], estado CERRADA [estaAbierta = 0], esImplicita = 1, docenteApertura = Grupo.docente, fechaAperturaUtc = Sesion.fechaHoraInicio, fechaCierreUtc = Sesion.fechaHoraFin, idCorrelacionApertura = @idCorrelacionMigracion)`; `UPDATE DetalleAsistencia SET toma = <toma 1 de su sesión> WHERE toma IS NULL`. Las sesiones **sin ninguna** `Asistencia` no reciben toma, y las sesiones con cabecera `Asistencia` pero sin detalle (cabecera creada por un reclamo) tampoco (NB-9).
   3. **Borrar dependientes** si existen: `FK_DetalleAsistencia_TomaAsistencia`, `UX_DetalleAsistencia_Asistencia_Toma`, `IX_DetalleAsistencia_Toma`.
   4. `ALTER TABLE dbo.DetalleAsistencia ALTER COLUMN toma uniqueidentifier NOT NULL`.
   5. `DROP INDEX UX_DetalleAsistencia_Asistencia` si existe.
   6. **Recrear** `UX_DetalleAsistencia_Asistencia_Toma`, `IX_DetalleAsistencia_Toma` y `FK_DetalleAsistencia_TomaAsistencia`.
4. Resultset de control: `tomasCreadas, detallesAsignados, detallesSinToma (= 0), detallesIncoherentes` (filas con `asistio <> IIF(codigo = 'AN', 1, 0)`, F-DOC-012, solo reporte), `sesionesConCabeceraSinDetalle` (NB-9), `siguienteCodigoSecuencia` y `maxCodigoDetalle` (debe cumplirse siguiente > max).
5. `CREATE OR ALTER` de las vistas de B.2; `GRANT SELECT`.
La semilla `DB:schema/seed/36_backfill_toma_asistencia.sql` ejecuta el paso 3 completo con el mismo orden (no hace nada si `AllowsNull = 0`), para que `deploy_schema.ps1` deje una BD nueva o existente en el estado final aunque no se ejecute la migración a mano; un segundo `deploy_schema.ps1` no cambia nada (B2-MIG-05).

**`16_…_down.sql`** (colapsa a la toma 1, DEC-011):
1. Aborta (`THROW 50011`) si alguna asistencia tiene detalles en tomas con `numero > 1` **y** no se pasó la confirmación `:setvar CONFIRMAR_COLAPSO 1`; con confirmación, por cada asistencia conserva un solo detalle: el de la toma de menor número con `SJC` si existe (no se pierde una falta), si no el de la toma 1, y borra los demás (se exportan antes a `zz_archivo_DetalleAsistencia_culm001_b2` sin FKs, patrón DEC-010).
2. `DROP` de `TokenAsistenciaToma`; `DROP CONSTRAINT FK_DetalleAsistencia_TomaAsistencia`, `DROP INDEX UX_DetalleAsistencia_Asistencia_Toma`, `CREATE UNIQUE INDEX UX_DetalleAsistencia_Asistencia (asistencia)`; `DROP COLUMN toma, registradoPorEstudiante, fechaRegistroUtc`; `DROP SEQUENCE`; `DROP TABLE TomaAsistencia, EstadoTomaAsistencia, ModoTomaAsistencia`.
3. Restaura el texto anterior de `usp_sincronizar_asistencia_estudiante_interno`, `uv_resumen_asistencia_estudiante_grupo`, `uv_cumplimiento_sesion_grupo` (versión B.1), los consumidores de §2.9, `usp_cancelar_sesion`/`usp_internal_aplicar_festivos_grupo`/precarga (versión B.1) y `DetalleAsistencia.sql`; `DROP` de los SP, funciones y vistas de B.2; restaura el texto anterior de `usp_ejecutar_cierre_masivo_periodo` (`COUNT(da.id)`). No toca permisos de `usp_registrar_asistencia_estudiante_autonomo` (B no los cambia).
4. Borra parámetros y mensajes de B.2 con la misma regla de `15_down`.

`@@TRANCOUNT = 0` al terminar cada script; cada migración se prueba `up → down → up` en `DB:test/test_culm001_b2_migraciones.sql` (y la 14 en `test_culm001_b1_sesion_cancelada.sql`) (§2.16).

### 2.15 Manifiestos y contratos de BD

- **B no modifica ningún objeto congelado**: `uv_horario_docente`, `uv_sesion`, `uv_estudiante_grupo`, `uv_asistencia`, `uv_detalle_asistencia`, `usp_crear_sesion`, `usp_actualizar_sesion`, `usp_generar_sesiones_grupo`, `usp_registrar_asistencias_sesion` (`DB_DEVELOP_FREEZE_MANIFEST`), ni `Sesion.sql`, `tr_Sesion_procedencia_temporal`, `uv_sesion_v2`, `rol_asistencias_runtime.sql` ni los demás de `DB_UTC_D06_POST_FREEZE_MANIFEST`, ni los de `DB_LB004D_SUPPORT_BINDING_MANIFEST`. `test_golden_path_immutability.sql` y `freeze-manifest.ps1` deben seguir verdes sin regenerar esos manifiestos.
- **Drift previo de línea base (B-2; decisión del orquestador):** `INFRA:docs/contracts/db/DB_DEVELOP_FREEZE_MANIFEST.sha256` **no es una copia** del manifiesto del repo DB: `INFRA:scripts/quality/verify-contracts.ps1` (líneas 196-225) compara cada línea con el hash **actual** de los archivos de `GestioAsistenciaDB`. Se define como "hash **efectivo** = el `SUPERSEDES` de `DB:docs/contracts/DB_UTC_D06_POST_FREEZE_MANIFEST.sha256` si existe; si no, el hash base". Hoy `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001` falla en dos líneas, que pasan a los valores del post-freeze UTC-D06 (copiados de ese archivo, no recalculados a mano):
  - `schema/stored-procedures/usp_generar_sesiones_grupo.sql`: `099a5cf4…` → `ef9de7e924642d1a1bdbc4ad99f5404f71e194493e6547f67c26d3b3dfbe1af3`
  - `schema/stored-procedures/usp_registrar_asistencias_sesion.sql`: `a0372fd6…` → `7217604b12e60c96cc1a212f579ff14e9334581a3b5ddcaf5ad353912d927a44`
  - `usp_crear_sesion.sql` y `usp_actualizar_sesion.sql` ya coinciden con el archivo actual y no cambian.
  Se anota en `DECISIONES.md` que ese drift (UTC-D06 y SES-01 sin propagar a Infra) es **previo a B**. `verify-contracts.ps1 -Mode Generate` (que regenera también los cuatro `.sha256` canónicos) **no** se ejecuta hasta después de la aprobación 9.2, y entonces solo con un `git diff` revisado de los cuatro contratos. No se edita ningún objeto para que coincida con un hash.
- **Manifiesto post-freeze de B (B-3; decisión del orquestador):** `DB:docs/contracts/DB_CULM001_B_POST_FREEZE_MANIFEST.sha256`, **solo con líneas `<sha256>  <ruta>  WORK_ITEM`** (el formato que acepta `freeze-manifest.ps1`, líneas 106-113; B no reemplaza ningún congelado, así que no hay `SUPERSEDES`). Contiene **solo lo que B define como contrato**:
  - tablas: `TipoCancelacionSesion.sql`, `SesionCancelacion.sql`, `DiaFestivo.sql`, `CargaDiaFestivo.sql`, `ModoTomaAsistencia.sql`, `EstadoTomaAsistencia.sql`, `TomaAsistencia.sql`, `TokenAsistenciaToma.sql`, `DetalleAsistencia.sql`;
  - vistas: `uv_sesion_estado.sql`, `uv_toma_asistencia.sql`, `uv_detalle_asistencia_v2.sql`, `uv_asistencia_sesion_horas.sql`;
  - SP: `usp_generar_sesiones_grupo_v2.sql`, `usp_registrar_asistencia_por_token.sql`, `usp_abrir_toma_asistencia.sql`, `usp_cerrar_toma_asistencia.sql`, `usp_registrar_asistencias_toma.sql`;
  - migraciones `15_*_up|down.sql`, `16_*_up|down.sql`; permisos `rol_asistencias_runtime_culm001_b1.sql`, `rol_asistencias_runtime_culm001_b2.sql`.
  **No entran** (porque B2, C o D los modifican después): KPIs y consultas de §2.9, `uv_resumen_asistencia_estudiante_grupo`, `uv_cumplimiento_sesion_grupo`, `usp_sincronizar_asistencia_estudiante_interno`, `usp_validar_sesion_ventana_registro_interno`, `zz_foreign_keys.sql` y las semillas.
  `freeze-manifest.ps1` se amplía con `-Mode GeneratePostFreeze -Manifest <ruta> [-Files <lista>]` (hoy `GeneratePostFreeze` solo escribe el manifiesto UTC-D06) y `-Mode Verify` recorre todos los `docs/contracts/DB_*_POST_FREEZE_MANIFEST.sha256` con el mismo verificador (CRLF→LF). La generación se hace solo tras la aprobación 9.2. **Espejo en Infra:** solo si `verify-contracts.ps1` lo verifica; hoy no lo hace (tampoco existe espejo de `DB_UTC_D06_POST_FREEZE`), así que **no se crea**.
- `DB:docs/contracts/DB_DEVELOP_FREEZE_ADDENDUM.md` (y su copia en Infra) recibe una sección "CULM-001 B" con la cardinalidad nueva de `uv_detalle_asistencia` (una fila por toma), la toma vigente del lote congelado, la regla de horas (DEC-012 + DEC-024) y la unidad de cada conteo de `uv_resumen_*` (`asistencias/faltasSinJustaCausa/excusas` = tomas; `sesionesEjecutadas`, `sesionesAsistidas`, `sesionesConFaltaSinJustaCausa`, `sesionesConExcusa` = sesiones; NB-2). Es un cambio de texto de un contrato WORM: se regenera su `.sha256` tras la revisión 9.2.
- `DB:docs/stored-procedures/usp_registrar_asistencias_sesion.md`: nota "escribe en la toma vigente" (documento derivado, sin hash).

### 2.16 Pruebas T-SQL RED

Archivos nuevos en `DB:test/` (se registran en `test_suite.sql`/`test_summary.ps1` **por nombre exacto**, nunca con el comodín `culm001_b2*`, DEC-028). Cada caso termina con `ASSERT @@TRANCOUNT = 0` y deja los datos como estaban (transacción de prueba con rollback o fixtures propias con prefijo `CULMB_`).

#### 2.16.1 B.1 — `test_culm001_b1_ventana_tolerancia.sql`, `test_culm001_b1_sesion_cancelada.sql`, `test_culm001_b1_festivos.sql`

| Id | Regla | Resultado esperado |
| :--- | :--- | :--- |
| B1-VEN-01 | Ventana **sin** tolerancia (llamada con 5 parámetros) | `[inicio, fin)` exacto: un segundo antes del inicio `SES_007`, en `fin` `SES_008` (las pruebas `test_ses01_ventana_asistencia.sql` siguen intactas y verdes) |
| B1-VEN-02 | Ventana con tolerancia 15 / margen 30 | `inicio − 15 min` admite; `inicio − 15 min − 1 s` `SES_007`; `fin + 30 min − 1 s` admite; `fin + 30 min` `SES_008` |
| B1-VEN-03 | Tolerancia NULL o negativa | Igual a 0 |
| B1-VEN-04 | Sesión cancelada | `SES_010` con y sin tolerancia; el lote congelado `usp_registrar_asistencias_sesion` sobre una sesión cancelada devuelve `SES_010` y no escribe |
| B1-VEN-05 | Procedencia NULL | `SES_009` antes que la tolerancia |
| B1-CAN-01 | Docente titular cancela sesión sin registros, motivo válido | Fila en `SesionCancelacion` tipo `esAutomatica = 0`, `usuarioEjecutor` = docente; `uv_sesion_estado.estaCancelada = 1`; `SES_014` |
| B1-CAN-02 | Docente no titular / estudiante / coordinador | `SEC_002` o RBAC; sin fila |
| B1-CAN-03 | Motivo de 9 y de 501 caracteres; motivo solo espacios | `SES_013` |
| B1-CAN-04 | Sesión con `Asistencia` | `SES_012`; sin fila |
| B1-CAN-05 | Cancelar dos veces | `SES_011`; motivo original intacto |
| B1-CAN-06 | Sesión cancelada fuera de `uv_cumplimiento_sesion_grupo` | `usp_consultar_kpis_coordinador`: `sesionesProgramadas` baja en 1; `porcentajeCumplimiento` y `porcentajeProgresoCalendario` no la cuentan |
| B1-CAN-07 | Destinatarios | `usp_consultar_destinatarios_sesion_cancelada` devuelve solo matrículas `A`; sesión no cancelada → sin filas |
| B1-CAN-08 | Sesión con asistencia cuya ventana ya terminó (`fin + MARGEN` vencido) / sesión pasada sin asistencia / sesión futura | `SES_016`, sin fila / se cancela (decisión del orquestador) / se cancela |
| B1-FES-01 | Carga 2026 con los 19 festivos del cálculo local (tabla §3.4.1) | `FES_005`, 19 activos, `CargaDiaFestivo` con fuente y fecha |
| B1-FES-02 | Misma carga dos veces | Mismo conjunto activo, 0 insertados la segunda vez (idempotencia) |
| B1-FES-03 | Recarga sin un festivo | Ese festivo `estaActivo = 0`; sesiones ya canceladas por él no cambian ([SUPUESTO-B-10]) |
| B1-FES-04 | JSON con clave extra, fecha de otro año, fecha repetida, 5 festivos, fuente desconocida, año 1999 | `FES_002`, `FES_002`, `FES_002`, `FES_003`, `FES_004`, `FES_001`; sin escrituras |
| B1-FES-05 | Cargas concurrentes del mismo año (2 sesiones T-SQL) | Sin duplicados (único por fecha) ni error de clave: la segunda espera al bloqueo |
| B1-FES-06 | **Las 19 fechas de 2026 y las 19 de 2027 de la tabla §3.4.1** (NB-6), que cubren fijos, trasladados al lunes (también los que no se trasladan ese año, como San Pedro y Raza 2026), de Pascua y Chiquinquirá | Una sesión generada en cada una de las 38 fechas (franja del horario en ese día) nace cancelada con motivo `Día festivo: <nombre>`; una sesión el día anterior y el siguiente de cada una no se cancela |
| B1-FES-07 | `usp_generar_sesiones_grupo_v2` en un periodo con festivos | Las sesiones de días festivos quedan con `SesionCancelacion` tipo automático y `diaFestivo`; las demás sin cancelar; segunda ejecución: 0 sesiones nuevas, 0 cancelaciones nuevas |
| B1-FES-08 | (B-6) Falla inyectada en la fase 1 con el patrón `CK_REC3_TMP_SESION` de `test_rec3_falla_intermedia_transaccion.sql` (TX-04), con y sin transacción externa | `estadoResultado = 0` con `SYS_001` (el 3915 se traduce), 0 sesiones del grupo, `@@TRANCOUNT` igual al de entrada |
| B1-FES-08b | Paridad de la tupla de negocio: grupo sin horarios (y docente no titular) | `usp_generar_sesiones_grupo_v2` devuelve exactamente la misma tupla que `usp_generar_sesiones_grupo` |
| B1-FES-08c | Ruta feliz dentro de una transacción externa | Genera y aplica festivos; el llamador confirma o revierte todo |
| B1-FES-09 | Precarga (crear grupo + horario) en periodo con festivo | Sesiones del festivo creadas canceladas en la misma transacción; un cambio de horario que borra una sesión futura cancelada borra también su `SesionCancelacion` |
| B1-FES-10 | `usp_aplicar_festivos_grupo` sobre grupo ya creado | Cancela las sesiones futuras sin asistencia en festivo; **no toca** las que tienen asistencia y las cuenta en `sesionesConAsistencia`; segunda ejecución: 0 canceladas (idempotente); una sesión pasada sin asistencia no se toca con `@soloFuturas = 1` |
| B1-FES-11 | `usp_aplicar_festivos_periodo` con ambos filtros / ninguno; administrador de otra institución | `FES_006`; `SEC_002` |
| B1-FES-12 | `usp_consultar_sesiones_festivo_con_asistencia_paginado` | Lista exactamente las sesiones reportadas en B1-FES-10 |
| B1-FES-13 | Fecha local vs UTC | Una sesión de 19:00 a 21:00 hora de Bogotá del día anterior a un festivo (00:00-02:00 UTC del festivo) **no** se cancela; una de 06:00 del festivo sí |
| B1-SEG-01 | Permisos | `test_public_objects.sql`: los SP públicos de B.1 tienen `EXECUTE`; los `usp_internal_*` no |

#### 2.16.2 B.2 — `test_culm001_b2_tomas.sql`, `test_culm001_b2_horas.sql`, `test_culm001_b2_qr.sql`, `test_culm001_b2_migraciones.sql`, `test_culm001_b2_concurrencia.ps1`

| Id | Regla | Resultado esperado |
| :--- | :--- | :--- |
| B2-TOM-01 | **Toma única = comportamiento actual**: lote congelado sobre sesión sin tomas | Crea la toma 1 implícita cerrada; un detalle por estudiante; `uv_detalle_asistencia` devuelve las mismas filas y columnas que antes; `uv_resumen_*` da el mismo `porcentajeInasistencia` que la fórmula anterior con sesiones de igual duración (`porcentajeInasistencia = porcentajeInasistenciaSesiones`) |
| B2-TOM-02 | Lote congelado repetido | Actualiza el mismo detalle (sin segunda toma ni segundo detalle) |
| B2-TOM-03 | Abrir toma MANUAL y QR dentro de la ventana con tolerancia | `TOM_008`, `numero` 1, 2…; fuera de ventana `SES_007/008`; cancelada `SES_010` |
| B2-TOM-04 | Abrir con otra abierta / superar 4 tomas / modo `FOO` / no titular | `TOM_003` / `TOM_004` / `TOM_002` / `SEC_002` |
| B2-TOM-05 | Lote por toma | Escribe en esa toma; el lote congelado con una toma ABIERTA escribe en la abierta; con todas cerradas, en la última |
| B2-TOM-06 | Cerrar toma QR sin `marcarAusentes` | Los activos sin registro quedan `SJC` (`fueMarcadoAlCerrar = 1`), `totalAusentesMarcados` correcto; los que ya tenían `AN`/`EX` no cambian; un estudiante `CI`/`I` no recibe fila |
| B2-TOM-07 | Cerrar toma MANUAL sin `marcarAusentes` | No infiere faltas (regla actual); con `marcarAusentes = 1` sí |
| B2-TOM-08 | Cerrar dos veces / cierre concurrente docente + job | `TOM_011` idempotente; un solo cierre efectivo, sin SJC duplicados |
| B2-TOM-09 | **Faltantes y cierre QR marca SJC**: después del cierre, el docente marca `AN` a un faltante con el lote por toma dentro de la ventana | `uv_faltantes_toma` lo deja de listar; fuera de la ventana `SES_008` |
| B2-TOM-10 | `usp_cerrar_tomas_vencidas` | Cierra solo tomas abiertas con ventana vencida o sesión cancelada; QR marca SJC; dos ejecuciones concurrentes no cierran la misma toma dos veces |
| B2-TOM-11 | Invariante `estaAbierta <=> fechaCierreUtc IS NULL` y coherencia de `SesionCancelacion` | Ninguna fila la viola tras todas las pruebas |
| B2-HOR-01 | **Horas con 2 tomas**: sesión de 2 h con 2 tomas; estudiante AN en toma 1 y SJC en toma 2 | `horasToma = 1`; `horasFalta = 1`, `horasAsistidas = 1`; `esParcial = 1`, estado consolidado `SJC` |
| B2-HOR-02 | Sesiones de distinta duración (2 h y 4 h), 1 toma cada una, falta en la de 4 h | `porcentajeInasistencia = 66.67` (por horas) y `porcentajeInasistenciaSesiones = 50.00` |
| B2-HOR-03 | **Con sesión cancelada**: grupo con 3 sesiones vencidas, una cancelada | `horasDictadas` excluye la cancelada; `sesionesEjecutadas` también |
| B2-HOR-04 | **EX fuera de faltas y dentro del denominador** | Estudiante con 1 SJC y 1 EX en 4 tomas de 1 h: `horasFalta = 1`, `horasExcusa = 1`, `horasDictadas = 4`, `porcentajeInasistencia = 25.00` |
| B2-HOR-05 | Umbrales | `codigoPermanencia` con 15.00 → RIESGO, 20.00 → PERDIDA (de `ufn_clasificar_permanencia` sin cambio); `umbralAdvertencia/umbralPerdida` iguales a los parámetros |
| B2-HOR-06 | Sesión sin registro ni tomas | No entra en el denominador (regla actual) |
| B2-HOR-07 | KPIs | `usp_consultar_kpis_coordinador`, `_decano` e `_institucion` coinciden con el cálculo manual por horas del fixture; comparativas, tendencia y consolidado (diferidos a D) dan con 2 tomas el **mismo** resultado que con 1 toma del mismo estado consolidado (no duplican ni mezclan unidades) |
| B2-HOR-08 | Reclamo aprobado con varias tomas | Todas las SJC de la asistencia pasan a EX; `usp_consultar_detalle_solicitud_revision_docente` devuelve una fila |
| B2-HOR-09 | (NB-9) Sesión vencida con cabecera `Asistencia` (creada por un reclamo) y sin detalle ni tomas | `uv_asistencia_sesion_horas`: `totalTomasSesion = 0`, `horasSinRegistro = horasSesion`, sin división por cero; `uv_resumen_*` la incluye en `horasDictadas` (DEC-024) |
| B2-HOR-10 | (B-7) Cierre masivo: estudiante con 3 tomas ausentes en **una** sesión | Sigue `A`; con ausencias en 3 sesiones distintas pasa a `CI` (regla actual intacta) |
| B2-HOR-11 | (NB-2) Unidades | `tomasDictadas` junto a `sesionesEjecutadas` en los SP de §2.9 que exponen conteos |
| B2-QR-01 | Abrir QR en toma MANUAL / cerrada / fuera de ventana | `AQR_003` / `AQR_005` / `SES_008` |
| B2-QR-02 | PIN repetido con un activo o con un anterior vigente | `AQR_006`, sin escritura |
| B2-QR-03 | Registrar por token vigente y por PIN vigente | `AQR_009`, detalle `AN` con `registradoPorEstudiante = 1` |
| B2-QR-04 | **Idempotencia**: el mismo estudiante registra 3 veces (token, PIN, token) | Un solo detalle; 2.ª y 3.ª `AQR_008` (`yaRegistrado = 1`); si el docente ya lo había marcado `EX`, no cambia |
| B2-QR-05 | **Token/PIN anterior** tras una rotación | Vale hasta `TOLERANCIA_SEGUNDOS` después de `fechaRotacionUtc` (se simula moviendo `fechaRotacionUtc` en el fixture); después `AQR_001` |
| B2-QR-06 | **Estudiante de otro grupo** con token válido | `AQR_004`, sin cabecera ni detalle |
| B2-QR-07 | Estudiante con matrícula `CI` o `I` | `AQR_004` |
| B2-QR-08 | Token y PIN a la vez / ninguno / token desconocido / token cerrado | `AQR_007` / `AQR_007` / `AQR_001` / `AQR_001` (mismo mensaje) |
| B2-QR-09 | Rotación automática | `usp_consultar_tomas_qr_por_rotar` devuelve solo `debeRotar`; con `@forzar = 0` una segunda instancia no rota (`rotado = 0`) |
| B2-QR-10 | Sesión cancelada con token activo | Registro `SES_010` |
| B2-MIG-01 | `up` sobre copia de la BD con datos | Una toma 1 por sesión con detalles; `toma NOT NULL`; índices nuevos; detalles idénticos en `uv_detalle_asistencia` (checksum antes/después) |
| B2-MIG-02 | `up` dos veces | Sin cambios la segunda vez |
| B2-MIG-03 | **`down` restaura** | Con una sola toma: esquema y datos idénticos al original (checksum de `DetalleAsistencia` sin las columnas nuevas); con 2 tomas sin confirmación `THROW 50011`; con confirmación, queda la SJC y el archivo `zz_archivo_*` contiene los descartados |
| B2-MIG-04 | `up → down → up` de 15 y 16 | `@@TRANCOUNT = 0`, `freeze-manifest.ps1` verde |
| B2-MIG-05 | (B-1) `deploy_schema.ps1` **dos veces seguidas** sobre una BD nueva y sobre una copia con datos | Sin errores (ni 4922 ni 50002); tras la primera pasada `toma` es `NOT NULL` y existen `UX_DetalleAsistencia_Asistencia_Toma`, `IX_DetalleAsistencia_Toma`, `FK_DetalleAsistencia_TomaAsistencia` y no existe `UX_DetalleAsistencia_Asistencia`; la segunda pasada no cambia nada |
| B2-MIG-06 | Secuencia | Tras el despliegue y tras `16_up`, `NEXT VALUE FOR seq_detalle_asistencia_codigo` > `MAX(DetalleAsistencia.codigo)` |
| B2-CON-01 | `test_culm001_b2_concurrencia.ps1`: **5 grupos × 40 estudiantes** registrando por token a la vez (200 sesiones de conexión, `Start-Job`/`sqlcmd` en paralelo, ejecutado por `infra.ps1 db-test` solo con `-Concurrencia`) | 200 detalles `AN` exactos (uno por estudiante y toma), 0 duplicados, 0 errores 1205 (deadlock) y 0 timeouts; repetir la ronda completa: 0 detalles nuevos (`AQR_008`); duración total y **p50/p95/máximo por grupo** registrados en el log (NB-4) |
| B2-SEG-01 | Permisos | Lista de §2.13; `usp_registrar_asistencia_estudiante_autonomo` **conserva** su `EXECUTE` (B no lo toca; `verify_runtime_role_login.ps1` sin cambios) |
| B2-SEG-02 | (B-4) Fixtures repetibles | `maint_003g_attendance_fixture.sql` y `dev_pagination_fixture.sql` + `dev_pagination_cleanup.sql` se ejecutan dos veces seguidas sin errores de FK |

#### 2.16.3 Pruebas existentes que cambian por el contrato ([SUPUESTO-B-20])

Helper nuevo `test/fixtures/culm001_b2_toma_fixture.sql` con dos procedimientos de prueba: **creación** (toma 1 de una sesión de fixture, MANUAL/CERRADA/implícita) y **limpieza** (borra de un conjunto de sesiones, en orden, `DetalleAsistencia → TokenAsistenciaToma → TomaAsistencia → SesionCancelacion → Asistencia`, y deja al llamador el `DELETE Sesion`).

**(a) Única aserción que cambia (cambio formal por DEC-011, B-4a):** `test/test_attendance_commands.sql:202`, `THROW 51876 ATTENDANCE_NO_DUPLICATE_DETAIL`: `SELECT 1 FROM dbo.DetalleAsistencia GROUP BY asistencia HAVING COUNT(*) > 1` → `GROUP BY asistencia, toma`. Es un invariante global que con varias tomas es falso por diseño; su intención (no duplicar un detalle) se conserva por toma. Las aserciones de las líneas 182 y 195 (`COUNT(*) … = 1` por asistencia) **no** cambian: siguen siendo válidas porque esos casos usan una sola toma.

**(b) Limpiezas que borran `Sesion`** (fallarían por `FK_TomaAsistencia_Sesion`, porque el lote congelado crea la toma implícita, o por `FK_SesionCancelacion_Sesion`, en precargas con festivos): pasan a llamar al helper de limpieza antes del `DELETE Sesion`, sin otro cambio: `test/fixtures/maint_003g_attendance_fixture.sql:40-51` (alimenta también los IT Java vía `test/prepare_java_integration_fixture.ps1`), `test/fixtures/dev/dev_pagination_cleanup.sql:21-24`, `test/test_rec3_falla_intermedia_transaccion.sql:73,135-137,244`, `test/test_utc_d06_procedencia_temporal.sql:531`, `test/test_usp_precargar_sesiones_concurrency.ps1:172`.

**(c)** `test/verify_runtime_role_login.ps1:31` **no cambia** (B ya no hace `REVOKE`, B-5).

**(d)** Fixtures del backend de §3.6 (`AttendanceCommandFixture`, `AttendanceCommandParityFixture`, `AsistenciaJdbcBaselineOracle` y los IT que borran sesiones): su limpieza borra también `TokenAsistenciaToma`, `TomaAsistencia` y `SesionCancelacion` en el orden anterior.

**(e) Inserciones directas en `DetalleAsistencia`** (solo se añade la columna `toma`, creando antes la toma 1 con el helper de creación) en: `test_attendance_review.sql`, `test_mass_period_close.sql`, `test_rec3_falla_intermedia_transaccion.sql`, `test_ses04_reclamo_justificada.sql`, `test_ufn_clasificar_permanencia.sql`, `test_usp_consultar_aforo_grupos_facultad.sql`, `test_usp_consultar_alerta_temprana_programa.sql`, `test_usp_consultar_bitacora_estudiante_programa.sql`, `test_usp_consultar_comparativa_facultades.sql`, `test_usp_consultar_comparativa_programas_facultad.sql`, `test_usp_consultar_detalle_solicitud_revision_docente.sql`, `test_usp_consultar_ficha_estudiante_programa.sql`, `test_usp_consultar_kpis_coordinador.sql`, `test_usp_consultar_kpis_decano.sql`, `test_usp_consultar_kpis_institucion.sql`, `test_usp_consultar_tendencia_ausentismo.sql`, `test_usp_precargar_sesiones_grupo.sql`, `test_usp_resolvers_decano.sql`, `test_usp_resolvers_institucion_admin.sql`, `test_utc_d06_procedencia_temporal.sql`, `test_uv_resumen_asistencia_estudiante_grupo.sql`, `test/fixtures/dev/dev_pagination_fixture.sql`, `migrations/02_datos_semilla_representativos.sql` (este último crea explícitamente la toma 1 de cada sesión que siembra, porque se ejecuta a mano después del despliegue, cuando `toma` ya es `NOT NULL`). `test_mass_period_close.sql` está en la lista por la inserción y además recibe el caso nuevo B2-HOR-10 (B-7); sus aserciones actuales no cambian. Las aserciones de porcentaje no se tocan: si un fixture usa sesiones de distinta duración y su porcentaje cambia por la regla de horas, se **anota** en el PR como cambio formal de contrato (DEC-012/DEC-024) con el cálculo, no se ajusta en silencio. `precheck_unique_indexes.sql` y `test_public_objects.sql` se actualizan por el cambio de índice y por los SP públicos nuevos. Ninguna otra aserción cambia; el PR lista archivo por archivo qué línea cambió.

---

## 3. Backend (`GestioAsistenciaBackend`)

### 3.1 Reglas comunes

- Flujo obligatorio `Controller → InputPort (PrimaryPort) → UseCaseImpl → SecondaryPort → *JpaRepository` (adaptador JPA que ejecuta `EXEC` nativo, patrón `MatriculaQrJpaRepository`). Ningún controlador ni clase de `application` importa infraestructura, `EntityManager`, `JdbcTemplate` ni repositorios JPA.
- Respuestas: `ApiDataResponse<T>(exitoso, datos)`, `ApiListResponse<T>(exitoso, datos, total)` para listas cortas no paginadas, y el nuevo genérico `BE:infrastructure/adapter/primary/controller/response/ApiPageResponse<T>(boolean exitoso, List<T> elementos, int numeroPagina, int tamanoPagina, long totalElementos, int totalPaginas)` para listas paginadas (no existía; lo describe AGENTS.md §2.3). Errores: `ApiErrorResponse(timestamp, status, error, code, message, path, correlationId, details)` con `message` = mensaje de usuario del catálogo.
- Los códigos de BD nuevos se exponen tal cual en `ApiErrorResponse.code` (precedente `MQR_*`): `TOM_*`, `AQR_*`, `FES_*`, `SES_011..014` y `SES_016`. Los existentes `SES_007/008/009` mantienen su traducción actual (`ERR_SESION_NO_INICIADA`, `ERR_SESION_CERRADA`, `ERR_SESION_HORARIO_INDETERMINADO`) y `SES_010` se traduce a `ERR_SESION_CANCELADA` del mismo modo (NB-1). Traducción en `DbCodeTranslator` (un `case` por código) y enums de fallback `TomaAsistenciaErrorCode`, `AsistenciaQrErrorCode`, `FestivoErrorCode`, y nuevos valores en `SesionErrorCode`.
- Fechas: instantes UTC `String` ISO-8601 con `Z` (patrón `SesionV2Response`). Horas: `number` con 2 decimales (redondeo `HALF_UP` en el mapper de salida; la BD guarda 6).
- Correlación: `CorrelationIdContext.get()` en cada `EXEC` (`@idCorrelacion`) y en cada evento; los schedulers crean su propio contexto por pasada.
- Parámetros por `ParameterCatalogPort` con valor por defecto en código igual a la semilla (DEC-018). Mensajes por `MessageCatalogPort`.
- Auditoría: `@AuditableOperation` en todos los comandos nuevos: `CANCELAR_SESION`, `ABRIR_TOMA_ASISTENCIA`, `CERRAR_TOMA_ASISTENCIA`, `REGISTRAR_ASISTENCIAS_TOMA`, `ABRIR_QR_TOMA`, `ROTAR_QR_TOMA`, `CERRAR_QR_TOMA`, `REGISTRAR_ASISTENCIA_POR_TOKEN`, `RECARGAR_FESTIVOS_ANIO`.

### 3.2 Endpoints

#### 3.2.1 B.1 — `PATCH /api/v1/docente/sesiones/{sesionId}/cancelar` (HU047; hoy 501)

- Rol `DOCENTE` (titularidad en Application vía `InstitutionalScopePort` y en el SP). Controlador `DocentePortalController` (se reemplaza el `unavailable("cancelar sesion")`) → `CancelarSesionInputPort`.
- Request: `{ "motivo": "string (10..500, se recorta)" }` (`@NotBlank`, `@Size`; la longitud efectiva la valida la BD con los parámetros).
- 200 `ApiDataResponse<SesionCanceladaResponse>`:
```json
{ "exitoso": true, "datos": {
    "idSesion": "uuid", "idGrupo": "uuid", "estado": "CANCELADA",
    "cancelacion": { "tipo": "DOCENTE", "motivo": "string", "nombreFestivo": null, "fechaCancelacionUtc": "2026-11-10T14:00:00Z" },
    "estudiantesNotificados": 38 } }
```
- Errores: 400 `VALIDATION_ERROR`/`SES_013`; 401; 403 `SEC_002`; 404 `SES_001`; 409 `SES_011`, `SES_012`, `SES_016` (sesión terminada con asistencia: se corrige por reclamo).
- Efectos tras el commit: (1) notificación `SESION_CANCELADA` por `NotificacionPort` a cada estudiante activo (mejor esfuerzo: un fallo se registra y no cambia la respuesta; `estudiantesNotificados` = encolados); (2) evento SSE `SESION_CANCELADA` para el docente titular (los estudiantes lo recibirán por SSE cuando C abra el canal; en B se enteran por la notificación y al recargar).

#### 3.2.2 B.1 — Festivos (administrador)

| Método y ruta | Rol | Request | Respuesta | Errores |
| :--- | :--- | :--- | :--- | :--- |
| `GET /api/v1/admin/festivos?anio=2026&incluirInactivos=false` | `ADMINISTRADOR` | query `anio` obligatorio (int) | 200 `ApiDataResponse<FestivosAnioResponse>` | 400 `FES_001`/`VALIDATION_ERROR`; 401; 403 |
| `POST /api/v1/admin/festivos/{anio}/recarga` | `ADMINISTRADOR` | sin cuerpo | 200 `ApiDataResponse<RecargaFestivosResponse>` | 400 `FES_001`; 401; 403; 500 `FES_009` |
| `GET /api/v1/admin/festivos/{anio}/sesiones-con-asistencia?pagina=1&tamano=20` | `ADMINISTRADOR` | — | 200 `ApiPageResponse<SesionFestivoConAsistenciaResponse>` | 400; 401; 403 |

```json
// FestivosAnioResponse
{ "anio": 2026, "fuenteUltimaCarga": "CALENDARIOS_NACIONALES", "fechaUltimaCargaUtc": "2026-11-07T05:00:00Z",
  "diferenciasCalculoLocal": 0,
  "atribucion": { "texto": "Fuente: Calendarios Nacionales", "url": "https://calendariosnacionales.com" },
  "festivos": [ { "fecha": "2026-01-01", "nombre": "Año Nuevo", "fuente": "CALENDARIOS_NACIONALES", "estaActivo": true } ],
  "totalFestivos": 19 }
// RecargaFestivosResponse
{ "anio": 2026, "fuente": "CALENDARIOS_NACIONALES", "usoRespaldo": false, "totalFestivos": 19,
  "festivosInsertados": 0, "festivosActualizados": 19, "festivosDesactivados": 0, "diferenciasCalculoLocal": 0,
  "aplicacion": { "gruposProcesados": 12, "sesionesCanceladas": 3, "sesionesConAsistencia": 1 } }
// SesionFestivoConAsistenciaResponse
{ "idSesion": "uuid", "idGrupo": "uuid", "nombreGrupo": "string", "nombreAsignatura": "string", "nombreDocente": "string",
  "fechaHoraInicioUtc": "…Z", "fecha": "2026-03-23", "nombreFestivo": "San José", "totalTomas": 1, "totalRegistros": 30 }
```

La atribución sale de `FESTIVOS/ATRIBUCION_*` (el frontend no la escribe). La recarga es: obtener con respaldo (§3.4) → `usp_cargar_dias_festivos` → `usp_aplicar_festivos_periodo(@anio)`.

#### 3.2.3 B.1 — Generación de sesiones y creación de grupos

- `POST /api/v1/sesiones/grupo/{grupoId}/generacion` (sin cambio de ruta, rol ni request): el adaptador pasa de `usp_generar_sesiones_grupo` a `usp_generar_sesiones_grupo_v2` (con la misma transacción que usa hoy; no hace falta `Propagation.NOT_SUPPORTED`, B-6). Antes, `AsegurarFestivosPeriodoUseCase` carga los años del periodo que falten. La respuesta existente añade `sesionesCanceladasPorFestivo` y `sesionesFestivoConAsistencia` (endpoint fuera del golden path).
- `POST /api/v1/grupos` (crear grupo + horarios + precarga en una transacción, `GrupoJpaRepository`): **antes** de abrir esa transacción, `AsegurarFestivosPeriodoUseCase` (años de `PeriodoAcademico.fechaInicio..fechaFin`); si un proveedor falla se usa el respaldo y se registra en el log con correlationId (nunca bloquea la creación). La precarga aplica los festivos dentro de la transacción. Mismo paso en la actualización de horarios (`PUT /grupos/{id}`), que también precarga.

#### 3.2.4 B.1 — DTOs de sesión con estado

Campos nuevos en **todas** las respuestas de sesión: `estado` (`"PROGRAMADA" | "CANCELADA"`, enum Java `EstadoSesion`, derivado de `uv_sesion_estado.estaCancelada`) y `cancelacion` (`null` o `{ tipo: "DOCENTE" | "FESTIVO", motivo, nombreFestivo, fechaCancelacionUtc }`).

| DTO | Endpoint(s) | Cambio |
| :--- | :--- | :--- |
| `SesionConsultadaDTO` (v1) | `GET /sesiones/grupo/{id}`, `GET /sesiones/{id}`, `POST /sesiones/consultas` | + `estado`, `cancelacion`. `codigo` se conserva (docente; deja de ser credencial, [SUPUESTO-B-18]) |
| `SesionV2Response` | `/api/v2/sesiones/**` | + `estado`, `cancelacion` (`@JsonInclude(ALWAYS)`) |
| `SesionMateriaEstudianteResponse` | `GET /estudiante/materias/{id}/sesiones` | **− `codigo`**; + `estado`, `cancelacion`; B.2 añade `horasSesion, totalTomas, horasAsistidas, horasFalta, horasExcusa`, y `estadoAsistencia` admite `PARCIAL`; sesión cancelada → `estadoAsistencia = NO_DISPONIBLE`, `reclamable = false` |
| Sesiones del coordinador y del decano (`SpSesionGrupoPaginadoEntity`, `SpSesionFacultadPaginadoEntity` y sus responses) | `/coordinador/grupos/{id}/sesiones`, `/decano/sesiones` | + `estado`, `cancelacion` |

Lectura: los HQL sobre `UvSesionEntity`/`UvSesionV2Entity` se unen a la nueva entidad de vista `UvSesionEstadoEntity` (`@Table(name = "uv_sesion_estado")`, solo lectura).

#### 3.2.5 B.2 — Tomas

| Método y ruta | Rol | Request | 2xx | Errores |
| :--- | :--- | :--- | :--- | :--- |
| `POST /api/v1/sesiones/{sesionId}/tomas` | `DOCENTE` | `{ "modo": "MANUAL" \| "QR" }` | 201 `ApiDataResponse<TomaAsistenciaResponse>` + `Location: /api/v1/tomas/{id}` | 400 `TOM_002`/`VALIDATION_ERROR`; 403 `SEC_002`; 404 `SES_001`; 409 `ERR_SESION_NO_INICIADA`, `ERR_SESION_CERRADA`, `ERR_SESION_HORARIO_INDETERMINADO`, `ERR_SESION_CANCELADA`, `TOM_003`, `TOM_004` |
| `GET /api/v1/sesiones/{sesionId}/tomas` | `DOCENTE` | — | 200 `ApiDataResponse<TomasSesionResponse>` | 403; 404 |
| `POST /api/v1/tomas/{tomaId}/cierre` | `DOCENTE` | `{ "marcarAusentes": true \| false \| null }` | 200 `ApiDataResponse<CierreTomaResponse>` | 403; 404 `TOM_001` |
| `POST /api/v1/tomas/{tomaId}/asistencias` | `DOCENTE` | `{ "registros": [ { "estudianteId": "uuid", "estado": "AN" \| "SJC" \| "EX" } ] }` (1..200, sin duplicados) | 200 `ApiDataResponse<LoteTomaResponse>` | 400 `ATT_001..003`/`RC_001`/`VALIDATION_ERROR`; 403; 404 `TOM_001`; 409 `ERR_SESION_*`, `ERR_SESION_CANCELADA`; `EST_004` con el mismo estado HTTP que hoy devuelve `/asistencias/lote` (se fija en el RED copiando la traducción existente) |
| `GET /api/v1/tomas/{tomaId}/asistencias?pagina=1&tamano=50` | `DOCENTE` | — | 200 `ApiPageResponse<AsistenciaTomaResponse>` | 403; 404 |
| `GET /api/v1/tomas/{tomaId}/faltantes?pagina=1&tamano=50` | `DOCENTE` | — | 200 `ApiPageResponse<FaltanteTomaResponse>` | 403; 404 |

```json
// TomaAsistenciaResponse
{ "idToma": "uuid", "idSesion": "uuid", "idGrupo": "uuid", "numero": 2, "modo": "QR", "estado": "ABIERTA",
  "esImplicita": false, "fechaAperturaUtc": "…Z", "fechaCierreUtc": null, "horasToma": 1.00,
  "totalRegistros": 31, "totalPresentes": 30, "totalAusentes": 1, "totalExcusas": 0, "tieneQrActivo": true }
// TomasSesionResponse
{ "idSesion": "uuid", "estado": "PROGRAMADA", "cancelacion": null,
  "ventana": { "aperturaUtc": "…Z", "cierreUtc": "…Z", "abierta": true },
  "horasSesion": 2.00, "maximoTomas": 4, "tomas": [ TomaAsistenciaResponse ] }
// CierreTomaResponse
{ "toma": TomaAsistenciaResponse, "totalAusentesMarcados": 3, "totalFaltantes": 3, "yaEstabaCerrada": false }
// LoteTomaResponse
{ "idToma": "uuid", "idSesion": "uuid", "totalRegistros": 1 }
// AsistenciaTomaResponse
{ "estudianteId": "uuid", "nombreCompleto": "string", "estado": "AN" | "SJC" | "EX" | null,
  "registradoPorEstudiante": true, "fechaRegistroUtc": "…Z" }
// FaltanteTomaResponse
{ "estudianteId": "uuid", "nombreCompleto": "string", "tieneRegistro": true, "estado": "SJC" | null, "marcadoAlCerrar": true }
```

La ventana (`ventana.*`) la calcula la BD (`uv_sesion_estado`); el cliente la pinta y no la recalcula. `TomasSesionResponse.estado/cancelacion` permite al docente ver por qué no puede abrir tomas.

#### 3.2.6 B.2 — QR de la toma (HU175)

| Método y ruta | Rol | Request | 2xx | Errores |
| :--- | :--- | :--- | :--- | :--- |
| `POST /api/v1/tomas/{tomaId}/qr` | `DOCENTE` | — | 201 `ApiDataResponse<QrTomaResponse>` | 403; 404 `TOM_001`, `AQR_010` (deshabilitado); 409 `AQR_003`, `AQR_005`, `ERR_SESION_*`, `ERR_SESION_CANCELADA`; 500 si `AQR_006` persiste tras 5 reintentos |
| `POST /api/v1/tomas/{tomaId}/qr/rotacion` | `DOCENTE` | — | 200 `ApiDataResponse<QrTomaResponse>` | ídem |
| `DELETE /api/v1/tomas/{tomaId}/qr` | `DOCENTE` | — | 200 `ApiMessageResponse` (`AQR_013`) | 403; 404 |

```json
// QrTomaResponse
{ "idToma": "uuid", "idSesion": "uuid", "idGrupo": "uuid", "pin": "482913",
  "urlAsistencia": "https://<ASISTENCIA_QR/URL_BASE_FRONTEND>/app/asistencia/qr?t=<token base64url 32 bytes>",
  "qrPngBase64": "iVBORw0…", "fechaRotacionUtc": "…Z", "fechaExpiracionUtc": "…Z", "rotacionSegundos": 60 }
```

El token (32 bytes aleatorios de `TokenGeneratorPort.generarToken`, base64url sin relleno) y el PIN (`generarPin`, 6 dígitos) se generan en el backend; el adaptador calcula el SHA-256 y solo envía el hash a la BD. El QR (PNG 320 px, `CodigoQrGeneratorPort`/`ZxingCodigoQrGeneratorAdapter`) codifica `urlAsistencia`. El token en claro **solo** viaja en esta respuesta y en el evento `ASISTENCIA_QR_ROTADO` del titular.

#### 3.2.7 B.2 — Registro del estudiante (HU176): `POST /api/v1/estudiante/asistencia-qr` (cuerpo nuevo)

- Rol `ESTUDIANTE`. Request: **exactamente uno** de `{ "token": "string (43 caracteres base64url)" }` o `{ "pin": "string ^[0-9]{6}$" }`. Los campos antiguos (`sesion`, `sesionId`, `codigo`, `codigoAcceso`) se rechazan con 400 `VALIDATION_ERROR` (`@JsonIgnoreProperties(ignoreUnknown = false)` en el record).
- Orden real de controles (NB-3): **filtro de IP** `AsistenciaQrRateLimitFilter` (consulta el contador de rechazos de la IP; si supera `ASISTENCIA_QR/LIMITE_FALLIDOS_IP_POR_MINUTO` → 429 `AQR_011`) → **interruptor** `ASISTENCIA_QR/HABILITADA` (404 `AQR_010`) → **red del campus** `RedInstitucionalPort` con IP de `NetworkClientIpResolver` y `RED/PROXIES_CONFIABLES` (403 `AQR_002`) → **límite por estudiante** (todos los intentos, 429) → **límite por hash de token o por PIN** (todos los intentos, 429) → `usp_registrar_asistencia_por_token`. El filtro **incrementa** el contador de la IP en un `finally` solo si el estado de la respuesta es ≥ 400 y ≠ 429; los 200/201 (registro nuevo o idempotente) no consumen cupo por IP (B-9).
- 201 (registro nuevo) / 200 (`yaRegistrado = true`) `ApiDataResponse<RegistroAsistenciaQrResponse>`:
```json
{ "exitoso": true, "datos": { "idToma": "uuid", "idSesion": "uuid", "nombreAsignatura": "string", "nombreGrupo": "string",
  "numeroSesion": 12, "numeroToma": 2, "yaRegistrado": false, "fechaRegistroUtc": "…Z", "mensaje": "¡Listo! Tu asistencia quedó registrada." } }
```
- Errores: 400 `AQR_007`/`VALIDATION_ERROR`; 401; 403 `AQR_002`, `AQR_004`; 404 `AQR_001`, `AQR_010`; 409 `AQR_005`, `ERR_SESION_CANCELADA`, `ERR_SESION_CERRADA`; 429 `AQR_011` (con `Retry-After: 60`).
- Concurrencia: ante `DeadlockLoserDataAccessException`/SQL 1205 el caso de uso reintenta hasta 3 veces con espera aleatoria de 20-80 ms (la operación es idempotente). Publica `ASISTENCIA_QR_REGISTRADA` solo si `yaRegistrado = false`.

#### 3.2.8 B.2 — Resúmenes por horas (cierran F-DOC-004 y F-EST-002)

| Método y ruta | Rol | Respuesta |
| :--- | :--- | :--- |
| `GET /api/v1/docente/grupos/{grupoId}/resumen-asistencia?pagina=1&tamano=50` (NUEVO) | `DOCENTE` titular | 200 `ApiPageResponse<ResumenAsistenciaEstudianteResponse>`; 403; 404 |
| `GET /api/v1/estudiante/materias` (MODIFICADO) | `ESTUDIANTE` | `MateriaEstudianteDTO` + `indicadores: IndicadoresAsistenciaResponse` (nunca `null`: ceros si no hay sesiones ejecutadas) |

```json
// IndicadoresAsistenciaResponse (y núcleo de ResumenAsistenciaEstudianteResponse)
{ "sesionesEjecutadas": 10, "horasDictadas": 20.00, "horasAsistidas": 16.00, "horasFalta": 3.00, "horasExcusa": 1.00,
  "horasSinRegistro": 0.00, "porcentajeInasistencia": 15.00, "porcentajeAsistencia": 80.00,
  "codigoPermanencia": "REGULAR" | "RIESGO" | "PERDIDA" | null, "umbralAdvertencia": 15.00, "umbralPerdida": 20.00 }
// ResumenAsistenciaEstudianteResponse = { "estudianteId", "nombreCompleto", "codigoEstadoEstudiante", ...IndicadoresAsistenciaResponse }
```

El caso de uso del estudiante combina la consulta actual de materias con `usp_consultar_resumen_asistencia_estudiante` (una llamada, unión por `idGrupo` en Application).

#### 3.2.9 Golden path existentes (cambio de comportamiento, no de ruta)

| Endpoint | Cambio |
| :--- | :--- |
| `POST /api/v1/asistencias/lote` | Request, 201 y evento sin cambio. Escribe en la toma vigente (DEC-013). Nuevo 409 `ERR_SESION_CANCELADA` (sesión cancelada). La validación de ventana duplicada en Java (`RegistrarAsistenciasSesionUseCaseImpl:95-109`) se conserva estricta (DEC-014) y añade el chequeo de cancelación con `uv_sesion_estado` |
| `GET /api/v1/grupos/{grupoId}/asistencias` | Esquema sin cambio: una fila por estudiante y sesión con el **estado consolidado** ([SUPUESTO-B-15]). El HQL `HQL_CONSULTAR_ASISTENCIAS` (`AsistenciaJpaRepository:82-90`) pasa a la entidad de vista `UvAsistenciaSesionHorasEntity` |
| `GET /api/v1/realtime/stream?grupoId=` | Sin cambio de contrato HTTP; política de audiencia por tipo (§3.8) |

#### 3.2.10 Retiros

| Endpoint | Retiro |
| :--- | :--- |
| `GET /api/v1/sesiones/{sesionId}/qr-token` (501) | Método de `AsistenciaQrController`, matcher `SecurityConfig.java:148`, entrada de `access-catalog.json` (línea 177), pruebas que lo esperan 501 (se reescriben a 404 de ruta inexistente) |
| `POST /api/v1/asistencias` (501, TD-009) | **No se retira en B: diferido al paquete D** ([SUPUESTO-B-19]); sigue en 501 y TD-009 sigue abierta |
| Uso de `usp_registrar_asistencia_estudiante_autonomo` | `AsistenciaJpaRepository:44` y la feature `registrarasistenciaautonoma` se reemplazan por `asistenciaqr/registrarasistenciaportoken` (sin tocar permisos en BD, [SUPUESTO-B-18]) |

### 3.3 Paquetes y clases por capa

```text
BE:application/features/
├── sesioncancelacion/
│   ├── cancelarsesion/{primaryports/{CancelarSesionInputPort, dto/CancelarSesionDTO, dto/SesionCanceladaDTO}, usecase/impl/CancelarSesionUseCaseImpl}
│   └── exception/SesionCancelacionErrorCode
├── festivos/
│   ├── consultarfestivos/            (ConsultarFestivosAnioInputPort)
│   ├── recargarfestivos/             (RecargarFestivosAnioInputPort)
│   ├── asegurarfestivos/             (AsegurarFestivosPeriodoInputPort: usado por crear grupo y generación)
│   ├── cargarfestivosautomatico/     (CargarFestivosAutomaticoInputPort: job)
│   ├── consultarsesionesfestivo/     (ConsultarSesionesFestivoConAsistenciaInputPort)
│   ├── common/{FestivoColombia(LocalDate fecha, String nombre), ResultadoObtencionFestivos(fuente, festivos, usoRespaldo, diferencias),
│   │          ObtenerFestivosConRespaldoService}   -- orden por FESTIVOS/PROVEEDOR_PRINCIPAL + ORDEN_RESPALDO; compara con CALCULO_LOCAL
│   └── exception/FestivoErrorCode
├── tomaasistencia/
│   ├── abrirtoma/ consultartomassesion/ cerrartoma/ registrarasistenciastoma/ consultarasistenciastoma/ consultarfaltantestoma/ cerrartomasvencidas/
│   └── exception/TomaAsistenciaErrorCode
├── asistenciaqr/
│   ├── abrirqrtoma/ rotarqrtoma/ cerrarqrtoma/ rotartokensasistenciaautomatico/ registrarasistenciaportoken/
│   ├── common/{AsistenciaQrAccesoPolicy (exigirHabilitada, exigirRedCampus), AsistenciaQrCredencialesEmisor (5 reintentos ante AQR_006),
│   │          AsistenciaQrPresentador (URL_BASE_FRONTEND + "/app/asistencia/qr?t=" + token; QR PNG)}
│   └── exception/AsistenciaQrErrorCode
└── asistencia/consultarresumenasistencia/ (ConsultarResumenAsistenciaGrupoInputPort, ConsultarResumenAsistenciaEstudianteInputPort)

BE:application/secondaryports/
├── repository/{SesionCancelacionRepositoryPort, DiaFestivoRepositoryPort, TomaAsistenciaRepositoryPort, AsistenciaQrRepositoryPort,
│               ResumenAsistenciaQueryPort}
├── calendar/CalendarioFestivosPort          -- String fuente(); List<FestivoColombia> obtenerFestivos(int anio)  (lanza CalendarioFestivosException)
└── security/LimitadorIntentosPort           -- boolean permitir(String clave, int limitePorMinuto)

BE:infrastructure/adapter/secondary/
├── persistence/sqlserver/jpa/repository/{SesionCancelacionJpaRepository, DiaFestivoJpaRepository, TomaAsistenciaJpaRepository,
│                                         AsistenciaQrJpaRepository (SHA-256 aquí), ResumenAsistenciaJpaRepository}
├── persistence/sqlserver/jpa/entity/{UvSesionEstadoEntity, UvTomaAsistenciaEntity, UvAsistenciaSesionHorasEntity, UvDetalleAsistenciaV2Entity}
├── calendar/{CalendariosNacionalesFestivosAdapter, FeriadosIoFestivosAdapter, CalculoLocalFestivosColombiaAdapter}
└── security/SlidingWindowLimitadorIntentosAdapter   -- reutiliza SlidingWindowRateLimiter; máx. claves app.asistencia-qr.rate-limit.max-claves (10000)

BE:infrastructure/adapter/primary/
├── controller/tomaasistencia/{SesionTomaController (/api/v1/sesiones/{id}/tomas), TomaAsistenciaController (/api/v1/tomas/**)}
├── controller/asistenciaqr/{TomaQrController (/api/v1/tomas/{id}/qr**), EstudianteAsistenciaQrController (/api/v1/estudiante/asistencia-qr)}
├── controller/admin/AdminFestivoController (/api/v1/admin/festivos/**)
├── controller/docente/DocentePortalController (cancelar; resumen-asistencia)
├── controller/filter/AsistenciaQrRateLimitFilter      -- POST /api/v1/estudiante/asistencia-qr, clave "ip:<ip>", ASISTENCIA_QR/LIMITE_FALLIDOS_IP_POR_MINUTO (solo respuestas rechazadas)
└── scheduler/{RotacionTokenAsistenciaScheduler, CargaFestivosScheduler}

BE:infrastructure/config/{asistenciaqr/AsistenciaQrWiringConfiguration, festivos/FestivosWiringConfiguration, tomaasistencia/TomaAsistenciaWiringConfiguration}
```

`AsistenciaQrController` (existente) se elimina al moverse su único método vivo a `EstudianteAsistenciaQrController`.

### 3.4 Festivos: `CalendarioFestivosPort` y sus 3 adaptadores (DEC-017)

1. `CalendariosNacionalesFestivosAdapter` (`fuente() = "CALENDARIOS_NACIONALES"`): `GET FESTIVOS/URL_CALENDARIOS_NACIONALES` con `{anio}`; `RestClient` con timeout `FESTIVOS/TIMEOUT_SEGUNDOS`; lee `holidays[]` (`date`, `name`; ignora `type`/`scope` del archivo `nacionales.json`); valida fechas del año. Sin credenciales.
2. `FeriadosIoFestivosAdapter` (`"FERIADOS_IO"`): `GET FESTIVOS/URL_FERIADOS_IO` con `Authorization: Bearer <SecretVaultPort.getSecret(FESTIVOS/NOMBRE_SECRETO_FERIADOS_IO)>`; si el secreto no existe, el adaptador se declara no disponible (no falla el flujo); campos `date`, `name`. La key nunca se registra en logs ni se versiona. Se **mantiene** como respaldo 1 (lo exige 3.7, decisión del orquestador) con **implementación mínima**: un `GET`, timeout, mapeo de dos campos y sus pruebas con `MockRestServiceServer`; sin caché ni reintentos propios.
3. `CalculoLocalFestivosColombiaAdapter` (`"CALCULO_LOCAL"`, sin red): Pascua por el algoritmo gregoriano anónimo (Meeus/Jones/Butcher); Ley 51 de 1983: fijos (1-ene, 1-may, 20-jul, 7-ago, 8-dic, 25-dic), trasladables al lunes siguiente si no caen en lunes (6-ene, 19-mar, 29-jun, 15-ago, 12-oct, 1-nov, 11-nov), de Pascua (Jueves y Viernes Santo; Ascensión = Pascua + 43, Corpus Christi = Pascua + 64, Sagrado Corazón = Pascua + 71, todos lunes); Ley 2578 de 2026: Nuestra Señora del Rosario de Chiquinquirá, 9-jul trasladable al lunes. Devuelve 19 festivos, o menos si dos coinciden en la misma fecha (ya fusionados, [SUPUESTO-B-22]).
4. `ObtenerFestivosConRespaldoService` (application): orden = `PROVEEDOR_PRINCIPAL` + `ORDEN_RESPALDO`; **fusiona** los festivos de la misma fecha de cualquier fuente (nombres unidos por " / ", NB-5) antes de validar y de llamar al SP; usa el primero que responde con un conjunto válido (entre `MINIMO_POR_ANIO` y `MAXIMO_POR_ANIO`, fechas del año); calcula `diferenciasCalculoLocal` (diferencia simétrica de fechas con el adaptador local) y, si es > 0, `log.warn` estructurado con `correlationId`, año, fuente y fechas distintas; gana la fuente principal (§3.7 del prompt). Si todos fallan, el local siempre responde (`usoRespaldo = true`, `FES_010` en el log).
5. `CargaFestivosScheduler` (`SmartLifecycle`, hilo daemon, `app.festivos.carga.tick` = `PT24H`, retardo inicial `PT1M`, interruptor `FESTIVOS/HABILITADO`): para el año actual y los `ANIOS_ADELANTE` siguientes, si `usp_consultar_carga_festivos_anio` devuelve 0 activos → obtener con respaldo → `usp_cargar_dias_festivos_automatico` → `usp_aplicar_festivos_automatico`. No recarga años ya cargados (eso es acción del administrador; respeta "uso razonable" del proveedor).

#### 3.4.1 Tabla de referencia del cálculo local (oráculo de las pruebas Java y de B1-FES-06)

| Festivo | 2026 | 2027 |
| :--- | :--- | :--- |
| Año Nuevo | 01-ene | 01-ene |
| Reyes Magos | 12-ene | 11-ene |
| San José | 23-mar | 22-mar |
| Jueves Santo | 02-abr | 25-mar |
| Viernes Santo | 03-abr | 26-mar |
| Día del Trabajo | 01-may | 01-may |
| Ascensión del Señor | 18-may | 10-may |
| Corpus Christi | 08-jun | 31-may |
| Sagrado Corazón | 15-jun | 07-jun |
| San Pedro y San Pablo | 29-jun | 05-jul |
| Nuestra Señora del Rosario de Chiquinquirá | 13-jul | 12-jul |
| Independencia | 20-jul | 20-jul |
| Batalla de Boyacá | 07-ago | 07-ago |
| Asunción de la Virgen | 17-ago | 16-ago |
| Día de la Raza | 12-oct | 18-oct |
| Todos los Santos | 02-nov | 01-nov |
| Independencia de Cartagena | 16-nov | 15-nov |
| Inmaculada Concepción | 08-dic | 08-dic |
| Navidad | 25-dic | 25-dic |

La prueba de contraste con la fuente principal para 2026 y 2027 (`CalendarioFestivosContrasteIT`, perfil `integration`, con red) compara este conjunto con `calendariosnacionales.com`; sin red se omite con `Assumptions` y queda registrada como verificación manual de Fase 3.

### 3.5 Rotación y cierre automático (scheduler)

`RotacionTokenAsistenciaScheduler` (segundo scheduler, mismo patrón que `RotacionTokenMatriculaScheduler`: `SmartLifecycle`, hilo daemon `rotacion-token-asistencia-qr`, `scheduleWithFixedDelay`, `app.asistencia-qr.rotacion.tick` = `PT5S`, `CorrelationIdContext` propio por pasada, nunca `@Scheduled`). Cada pasada: (1) `RotarTokensAsistenciaAutomaticoUseCaseImpl`: `usp_consultar_tomas_qr_por_rotar` → por toma genera token+PIN → `usp_rotar_token_asistencia_automatico(@forzar = 0)` (reintento AQR_006) → si `rotado = 1` publica `ASISTENCIA_QR_ROTADO`; (2) `CerrarTomasVencidasUseCaseImpl`: `usp_cerrar_tomas_vencidas` → publica `TOMA_CERRADA` (`automatico = true`) por cada toma. La BD decide si rota/cierra (multi-instancia segura). No se generaliza el scheduler de matrícula (menor riesgo sobre HU176B).

### 3.6 Lecturas afectadas por la cardinalidad "un detalle por toma"

| Adaptador | Cambio |
| :--- | :--- |
| `AsistenciaJpaRepository` (`HQL_CONSULTAR_ASISTENCIAS` 82-90) | `UvAsistenciaSesionHorasEntity` (estado consolidado) en lugar de `UvDetalleAsistenciaEntity` |
| `AsistenciaSesionEstudianteJpaRepository` (27-30) | Ídem + horas por sesión; mapea `PARCIAL` |
| `ReporteAsistenciaJpaRepository` (28-33, Excel) | Ídem: una fila por estudiante y sesión, columnas de horas |
| `SesionJpaRepository`, `SesionMateriaEstudianteJpaRepository`, `AsistenciaProgramaJpaRepository`, `FacultadDecanoJpaRepository` | Unión con `UvSesionEstadoEntity` / columnas nuevas de los SP paginados |
| Pruebas de paridad/contrato (`AsistenciaQueryJpaParityIT`, `AsistenciaSesionEstudianteJpaParityIT`, `JpaQueryAdapterContractTest`, `AttendanceCommandFixture`, `AttendanceCommandParityFixture`, `AsistenciaJdbcBaselineOracle`, `ReporteAsistenciaJdbcBaseline`, `AsistenciaJpaQueryPersistenceTest`) | Fixtures con la columna `toma` (igual que [SUPUESTO-B-20]); los oráculos JDBC de línea base se actualizan al mismo agregado; nuevos casos con 2 tomas |
| `SesionV2SchemaCompatibilityVerifier` | Añade la verificación de `uv_sesion_estado`, `uv_toma_asistencia` y de los SP `usp_generar_sesiones_grupo_v2` y `usp_registrar_asistencia_por_token` (falla el arranque si faltan, mismo criterio) |

### 3.7 Notificaciones

- `Notificacion.TIPO_SESION_CANCELADA = "SESION_CANCELADA"`; entrada en `PlantillaPorDefectoCatalogo` con el mismo asunto, cuerpo y marcadores de §2.12; datos: `estudiante, asignatura, grupo, fecha (dd/MM/yyyy en America/Bogota), horaInicio, horaFin, motivo, docente`. Destinatarios: `SesionCancelacionRepositoryPort.consultarDestinatarios` (`usp_consultar_destinatarios_sesion_cancelada`), `Destinatario(rol = "ESTUDIANTE", id, nombre, correo)`.
- Proveedor: con `outbox`/`composite` se encola en `NotificacionSaliente`; con `log` (defecto) solo se registra (riesgo §7).

### 3.8 Eventos SSE (contrato en `INFRA:docs/contracts/events/REALTIME_EVENT_CONTRACT.md` y `GestioAsistenciaBackend/docs/contracts/REALTIME_EVENT_STANDARD.md`)

Todos se publican **después** del commit (nunca ante error), con `payload.grupo` (filtro del canal) y sin JWT, contraseñas ni datos personales salvo lo indicado.

| Tipo | Publica | Payload | Audiencia |
| :--- | :--- | :--- | :--- |
| `TOMA_ABIERTA` | `AbrirTomaAsistenciaUseCaseImpl` | `grupo, sesion, toma, numero, modo, fechaAperturaUtc` | `DOCENTE_TITULAR` |
| `TOMA_CERRADA` | `CerrarTomaAsistenciaUseCaseImpl`, `CerrarTomasVencidasUseCaseImpl` | `grupo, sesion, toma, numero, totalAusentesMarcados, totalFaltantes, automatico` | `DOCENTE_TITULAR` |
| `ASISTENCIA_QR_ROTADO` | abrir, rotar manual y automático | `grupo, sesion, toma, pin, urlAsistencia, qrPngBase64, fechaRotacionUtc, fechaExpiracionUtc, rotacionSegundos` (**lleva el token**, [SUPUESTO-B-16]) | `DOCENTE_TITULAR` **únicamente** |
| `ASISTENCIA_QR_REGISTRADA` | `RegistrarAsistenciaPorTokenUseCaseImpl` (solo registros nuevos) | `grupo, sesion, toma, estudiante (UUID), totalPresentes` | `DOCENTE_TITULAR` |
| `ASISTENCIAS_TOMA_ACTUALIZADAS` | `RegistrarAsistenciasTomaUseCaseImpl`, cierre con ausentes | `grupo, sesion, toma, totalRegistros` | `DOCENTE_TITULAR` |
| `SESION_CANCELADA` | `CancelarSesionUseCaseImpl` | `grupo, sesion, tipo (DOCENTE), fechaHoraInicioUtc` (sin motivo) | `DOCENTE_TITULAR` (C añadirá `ESTUDIANTE_GRUPO`) |

`ASISTENCIAS_SESION_ACTUALIZADAS` (golden path) no cambia. **Política de audiencia** ([SUPUESTO-B-17]; alcance del orquestador): B crea `RealtimeAudienciaPolicy` (`infrastructure/adapter/primary/realtime/sse/`), un mapa tipo → audiencias con **igualdad exacta** de tipo (nunca por prefijo; así `POST /realtime/emit`, que emite tipos `topic.action`, no puede coincidir con un tipo de negocio). En B la única audiencia es `DOCENTE_TITULAR` y el gateway sigue admitiendo solo al docente titular del `grupoId`, como hoy; un tipo no listado se entrega solo al titular. El paquete C (DEC-022 (1)) extiende el mismo mapa con `ESTUDIANTE_GRUPO` y los demás roles y abre la suscripción a ellos.

### 3.9 Seguridad por endpoint (`SecurityConfig` + `infra/security-baseline/access-catalog.json`)

| Método | Ruta | Roles | `ownership` (texto del catálogo) |
| :--- | :--- | :--- | :--- |
| PATCH | `/api/v1/docente/sesiones/{sesionId}/cancelar` | DOCENTE | (existente) Titularidad del docente; la DB y Application validan el grupo |
| GET | `/api/v1/admin/festivos` | ADMINISTRADOR | Catálogo nacional de solo consulta |
| POST | `/api/v1/admin/festivos/{anio}/recarga` | ADMINISTRADOR | Recarga nacional; la aplicación a sesiones se limita a los grupos de su institución (SP) |
| GET | `/api/v1/admin/festivos/{anio}/sesiones-con-asistencia` | ADMINISTRADOR | Solo grupos de su institución (SP) |
| POST, GET | `/api/v1/sesiones/{sesionId}/tomas` | DOCENTE | Docente titular de la sesión (Application + SP: RBAC DOCENTE y titularidad) |
| POST | `/api/v1/tomas/{tomaId}/cierre`, `/api/v1/tomas/{tomaId}/asistencias` | DOCENTE | Docente titular de la sesión de la toma (Application + SP) |
| GET | `/api/v1/tomas/{tomaId}/asistencias`, `/api/v1/tomas/{tomaId}/faltantes` | DOCENTE | Ídem |
| POST, DELETE | `/api/v1/tomas/{tomaId}/qr`; POST `/api/v1/tomas/{tomaId}/qr/rotacion` | DOCENTE | Ídem; el token solo viaja en la respuesta y en el SSE del titular |
| POST | `/api/v1/estudiante/asistencia-qr` | ESTUDIANTE | (texto nuevo) Solo el estudiante autenticado; exige red del campus, interruptor y límites por IP, token y estudiante; matrícula activa en el grupo de la toma (SP) |
| GET | `/api/v1/docente/grupos/{grupoId}/resumen-asistencia` | DOCENTE | Docente titular del grupo (Application + SP) |
| POST | `/api/v1/estudiante/asistencia-qr` (nota) | — | El límite por IP del texto anterior cuenta solo intentos rechazados ([SUPUESTO-B-12]) |

`GET /api/v1/realtime/stream` no cambia en B (sigue solo para el titular). Se retira la entrada de `GET /sesiones/{sesionId}/qr-token`; `POST /asistencias` se conserva hasta D. La prueba de consistencia del catálogo de acceso (la que hoy compara catálogo y controladores) debe pasar.

### 3.10 OpenAPI y contratos WORM

**`openapi-golden-path.yaml` (copias en `INFRA:docs/contracts/openapi/` y en el backend, idénticas, `.sha256` regenerado tras 9.2):**
1. Esquemas `Sesion` y `SesionV2` (`additionalProperties: false`): se añaden a `properties` y a `required` `estado` (`enum: [PROGRAMADA, CANCELADA]`) y `cancelacion` (`type: [object, 'null']`, `additionalProperties: false`, `required: [tipo, motivo, nombreFestivo, fechaCancelacionUtc]`, `tipo: enum [DOCENTE, FESTIVO]`, `nombreFestivo: [string, 'null']`, `fechaCancelacionUtc: UtcInstantResponse`). Afecta a `GET /sesiones/grupo/{grupoId}`, `POST /sesiones`, `GET|PATCH /sesiones/{sesionId}`, `/api/v2/sesiones`, `/api/v2/sesiones/{sesionId}`, `/api/v2/sesiones/grupo/{grupoId}`. Ejemplos actualizados con `estado: PROGRAMADA, cancelacion: null`.
2. `POST /api/v1/asistencias/lote` (NB-1): el 409 sigue siendo el `$ref` único `components/responses/SesionFueraDeVentana`; su descripción añade el código `ERR_SESION_CANCELADA` y su `example` pasa a `examples` (`cerrada`, `cancelada`), sin crear otra respuesta 409. La descripción del endpoint añade: "con varias tomas, el lote escribe en la toma abierta o, si no hay, en la última".
3. `GET /api/v1/grupos/{grupoId}/asistencias`: solo descripción (estado consolidado por sesión); esquema sin cambio.
4. `GET /api/v1/realtime/stream` y `RealtimeEventResponse` (`type: const ASISTENCIAS_SESION_ACTUALIZADAS`): **sin cambio**. Los tipos nuevos no entran al golden path (precedente: `MATRICULA_QR_ROTADO` tampoco está); se documentan en el contrato de eventos.
5. Los endpoints nuevos (tomas, QR, festivos, resumen, cancelar) **no** entran al golden path: se documentan con springdoc (`/v3/api-docs`) y en `GestioAsistenciaBackend/docs/contracts/HTTP_AS_IS_MATRIX.md`.
6. **Versión (NB-10):** `info.version` 1.1.0 → **1.2.0**, con una línea en `info.description`: "CULM-001 B: `Sesion`/`SesionV2` + `estado`, `cancelacion`; lote escribe en la toma vigente; 409 `ERR_SESION_CANCELADA`". B2 pasa a 1.3.0 (se registra en `DECISIONES.md`). Pruebas que se actualizan por este cambio formal: `OpenApiGoldenPathConformanceTest.criticalSchemasDeclareExactlyTheFrozenPropertiesAndRequiredFields` (`Sesion` + 2 campos), `criticalOpenApiSchemasMatchProviderDtoPropertyShapes` (`SesionConsultadaDTO` + 2), `OpenApiSesionesV2ContractRedTest` y el `.sha256` en los dos repos. La lista `forbiddenGhosts` (`tipo`, `status`, …) **no** se toca: `tipo` va anidado dentro de `cancelacion`.

**`BACKEND_GOLDEN_PATH_CONTRACT.md`**: fila 5 (`/asistencias/lote`) + "escribe en la toma vigente; 409 `ERR_SESION_CANCELADA`"; "Nota Sesion" + `estado`/`cancelacion`. Nada más. **`REALTIME_EVENT_CONTRACT.md`** (Infra, WORM con `.sha256`) y `REALTIME_EVENT_STANDARD.md` (backend): tabla AS-IS con los 6 tipos nuevos, la política de audiencia y la excepción documentada de payload con token para `ASISTENCIA_QR_ROTADO` (además de `MATRICULA_QR_ROTADO`, que hoy no figura). `GoldenPathSqlStoredProcedureContractIT` y las pruebas de conformidad OpenAPI del backend se actualizan **solo** en lo que cambian los puntos 1, 2 y 6.

### 3.11 Pruebas RED del backend

| Grupo | Pruebas | Criterio |
| :--- | :--- | :--- |
| Unitarias de casos de uso (100 % líneas y ramas en `application/features/{sesioncancelacion,festivos,tomaasistencia,asistenciaqr}` y `consultarresumenasistencia`) | Un `*UseCaseImplTest` por caso de uso: éxito, cada código de error traducido, evento publicado solo tras éxito y nunca ante error, payload exacto, notificación que falla sin romper la respuesta, reintento `AQR_006` (5) y deadlock (3), `rotado = false` sin evento, `yaRegistrado = true` sin evento, límites (IP en filtro: un 200/201 no incrementa el contador, un 404/400/409 sí y un 429 no; token y estudiante en el caso de uso cuentan todos los intentos), red fuera de CIDR y CIDR vacío (fail-closed), interruptor apagado, festivos: principal OK / principal caída → feriados.io / sin key → local / conjunto inválido → siguiente / diferencias registradas con correlationId / gana la principal; asegurar festivos con años ya cargados no llama a proveedores | JaCoCo del bundle ≥ 80/70 y 100 % en los paquetes nuevos |
| Adaptadores | `CalculoLocalFestivosColombiaAdapterTest` (tabla §3.4.1 exacta, 19 por año, Pascua 2024-2035 contra fechas conocidas, y **2038** con Sagrado Corazón y San Pedro fusionados el 5-jul: 18 filas, NB-5); `ObtenerFestivosConRespaldoServiceTest` (fusión de fechas repetidas de cualquier fuente); `CalendariosNacionalesFestivosAdapterTest` y `FeriadosIoFestivosAdapterTest` con `MockRestServiceServer` (200, 500, timeout, JSON mal formado, cabecera Bearer presente y nunca en logs); `SlidingWindowLimitadorIntentosAdapterTest`; `AsistenciaQrPresentadorTest` (URL exacta, QR decodificable con ZXing) | — |
| ArchUnit | `application` no importa `infrastructure`, `RestClient`, `jakarta.persistence`, `org.springframework.jdbc`; controladores no dependen de `secondary/*`; `CalendarioFestivosPort` solo implementado en `infrastructure/adapter/secondary/calendar`; schedulers solo llaman `InputPort` | Reglas existentes + nuevas |
| Contrato JPA/SP (`-Pintegration`) | `SqlStoredProcedureContractIT`: nombre, parámetros y columnas de salida de cada SP nuevo/modificado; `GoldenPathSqlStoredProcedureContractIT` verde sin cambios; paridad de las lecturas de §3.6 con 1 y 2 tomas | — |
| Controladores (`@WebMvcTest` + seguridad) | Cada endpoint: forma exacta de la respuesta, 400/401/403 (rol equivocado)/404/409/429, `Location` en 201, cuerpo antiguo de `asistencia-qr` → 400; rutas retiradas → 404; matriz `SecurityConfig` vs `access-catalog.json` | — |
| SSE | `LocalSseRealtimeStreamGatewayTest` + `RealtimeAudienciaPolicyTest`: el titular recibe los 6 tipos nuevos; un estudiante (o cualquier no titular) sigue recibiendo 403 al suscribirse (B no abre el canal, [SUPUESTO-B-17]); la política compara por **igualdad exacta** (un tipo `asistencia_qr.rotado` o `ASISTENCIA_QR_ROTADO_X` emitido por `/realtime/emit` no coincide con `ASISTENCIA_QR_ROTADO`); heartbeat intacto | — |
| Concurrencia (`AsistenciaQrConcurrenciaIT`, `-Pintegration`, SQL Server real) | Ronda 1: **5 grupos × 40 estudiantes** registrando por token a la vez (`ExecutorService` de 200 hilos sobre el caso de uso real, el filtro de IP y el adaptador JPA, misma IP `127.0.0.1`); en paralelo rota el scheduler (tick 1 s). Ronda 2 (B-9): **20 grupos × 40** (800 registros) desde la misma IP | 200 / 800 detalles `AN`, 0 duplicados, 0 errores al cliente (deadlocks absorbidos por el reintento y contados), **0 respuestas 429** en ambas rondas; repetición de la ronda 1: 200 `yaRegistrado`; **p50, p95 y máximo por grupo** registrados en el log; si p95 ≥ 500 ms se aplica la alternativa `HOLDLOCK` de §2.8.3 (NB-4) y se repite |
| E2E por API (`INFRA:scripts/tests/test_culm001_b1.ps1` y `test_culm001_b2.ps1`, tokens PKCE de DEC-008) | Cancelar sesión, abrir toma QR, registrar con `uco-estudiante` por PIN y por token, idempotencia, faltantes, cierre, recarga de festivos | Integrado en `test_all_hus.ps1` (§5) |

La carga 5 × 40 por HTTP no es posible con los 5 usuarios `uco-*` del realm: se cubre en BD (B2-CON-01) y en backend (IT anterior); por HTTP se prueba la concurrencia de 5 grupos con el docente y el estudiante disponibles (documentado como límite en §7).

---

## 4. Frontend (`GestioAsistenciaFrontend`)

### 4.1 Reglas comunes

Componentes standalone con `changeDetection: ChangeDetectionStrategy.OnPush`, `input()`/`output()`/`model()` (sin `@Input/@Output`), estado con `signal`/`computed`/`effect` (`onCleanup` para cerrar suscripciones). **Sin `setInterval`, `setTimeout` recursivo ni `interval()` de RxJS** en ningún componente o servicio nuevo o tocado por B ([SUPUESTO-B-13]); la reactividad viene del SSE (`RealtimeService.startForGroup` + `listenType`) y de las respuestas HTTP. Mensajes de error y éxito: `message`/`mensaje` del backend, nunca traducidos en el cliente. Sin `bypassSecurityTrust*` (el QR es `<img [src]>` con `data:image/png;base64,…`, URL que el sanitizador de Angular admite). Móvil primero (375 px sin scroll horizontal, objetivos táctiles ≥ 44 × 44 px, tablas → tarjetas en `< md`), luego tablet y escritorio. Solo tokens de `styles.css` (`primary`, `accent`, `warm`, …); el semáforo de asistencia pasa por un único componente `AttendanceStatusBadgeComponent` (`shared/components/attendance-status-badge/`) para que el paquete E lo retokenice en un solo lugar.

### 4.2 Modelos, servicios y tiempo real

| Archivo | Contenido |
| :--- | :--- |
| `FE:core/models/toma-asistencia.model.ts` (nuevo) | `ModoToma = 'MANUAL' \| 'QR'`, `EstadoToma = 'ABIERTA' \| 'CERRADA'`, `TomaAsistencia`, `VentanaSesion { aperturaUtc, cierreUtc, abierta }`, `TomasSesion`, `CierreToma`, `AsistenciaToma`, `FaltanteToma`, `LoteTomaRequest`, `PaginaApi<T>` (forma de `ApiPageResponse`) |
| `FE:core/models/asistencia-qr.model.ts` (nuevo) | `QrToma`, `RegistroAsistenciaQrRequest = { token: string } \| { pin: string }`, `RegistroAsistenciaQr`, `ASISTENCIA_QR_EVENT = { ROTADO: 'ASISTENCIA_QR_ROTADO', REGISTRADA: 'ASISTENCIA_QR_REGISTRADA' }`, `AsistenciaQrRotadoPayload`, `AsistenciaQrRegistradaPayload` (sin `any`) |
| `FE:core/models/festivo.model.ts` (nuevo) | `DiaFestivo`, `FestivosAnio`, `RecargaFestivos`, `SesionFestivoConAsistencia` |
| Modelos de sesión existentes (`attendance.model.ts`, `role-management.model.ts`, modelos v2) | `EstadoSesion = 'PROGRAMADA' \| 'CANCELADA'`, `CancelacionSesion { tipo: 'DOCENTE' \| 'FESTIVO', motivo, nombreFestivo, fechaCancelacionUtc }`; `IndicadoresAsistenciaMateria` pasa a la forma de `IndicadoresAsistenciaResponse` (§3.2.8); estado de asistencia del estudiante admite `PARCIAL` |
| `FE:core/realtime/model/realtime-event.model.ts` | `REALTIME_EVENT_TYPE` + `TOMA_ABIERTA`, `TOMA_CERRADA`, `ASISTENCIA_QR_ROTADO`, `ASISTENCIA_QR_REGISTRADA`, `ASISTENCIAS_TOMA_ACTUALIZADAS`, `SESION_CANCELADA` con sus payloads tipados |
| `FE:core/services/toma-asistencia.service.ts` (nuevo) | `abrirToma(sesionId, modo)`, `consultarTomas(sesionId)`, `cerrarToma(tomaId, marcarAusentes)`, `registrarAsistencias(tomaId, registros)`, `consultarAsistencias(tomaId, pagina, tamano)`, `consultarFaltantes(tomaId, pagina, tamano)` |
| `FE:core/services/asistencia-qr.service.ts` (nuevo) | `abrirQr(tomaId)`, `rotarQr(tomaId)`, `cerrarQr(tomaId)`, `registrarPorToken(token)`, `registrarPorPin(pin)` |
| `FE:core/services/admin-festivos.service.ts` (nuevo) | `consultar(anio)`, `recargar(anio)`, `sesionesConAsistencia(anio, pagina, tamano)` |
| `FE:core/services/session.service.ts` | `cancelarSesion(id, motivo)` real (se retira el mock `'CANCELADA'` y la marca `@deprecated OUT_OF_GOLDEN_PATH`); **se retiran** `getQrToken` y el antiguo `registrarAsistenciaQr(sesion, codigo)` |
| `FE:core/services/attendance-claim.service.ts`, `FE:core/mappers/student-portal.mapper.ts` | Mapean `estado`, `cancelacion`, horas y `indicadores` reales (el mapper deja de poner `indicadores: null`, F-EST-002) |
| Servicio de resumen del docente (`FE:core/services/teacher-attendance-summary.service.ts`, nuevo) | `consultarResumen(grupoId, pagina, tamano)` → `GET /docente/grupos/{id}/resumen-asistencia` |
| `FE:environments/environment.ts` | `features.sessionQrEnabled = true`, `features.sessionCancelEnabled = true` (y se quita el comentario `OUT_OF_GOLDEN_PATH LB-001B.5A`). Las banderas quedan como interruptor de retirada (§7) |

Si existe modo mock del servicio, los mocks devuelven exactamente las formas de §3.2 (sin PIN ni QR inventados).

### 4.3 Docente: pantalla de la sesión (`/app/asistencia`, `attendance-control`)

- **Selector de sesión**: las sesiones canceladas aparecen deshabilitadas con la etiqueta "Cancelada" y el motivo (o "Día festivo: <nombre>"). La guarda de ventana del cliente (`ventanaAsistenciaAbierta()`, línea 620) deja de calcularse con la hora local: usa `TomasSesion.ventana.abierta` del backend (y se re-consulta al recibir `TOMA_*` o al reabrir la sesión); para el lote legado se conserva el comportamiento SES-01 actual.
- **Panel de tomas** (`components/session-tomas-panel.component.ts`, nuevo): lista de tomas (número, modo, estado, `horasToma`, presentes/ausentes/excusas), botón "Nueva toma" (deshabilitado si hay una abierta, si se alcanzó `maximoTomas` o si la ventana está cerrada, con el texto del motivo) que abre `components/toma-modo-selector.component.ts` (dos tarjetas grandes: **Manual** / **Código QR**).
- **Toma manual**: la tabla existente (`attendance-control-table`) marca y guarda con `registrarAsistencias(tomaId, …)` (lote por toma); "Cerrar toma" con confirmación.
- **Toma QR**: al abrirla se llama `abrirQr(tomaId)` y se muestra `components/toma-qr-proyeccion.component.ts` (nuevo, reemplaza `attendance-projection-modal` y `teacher-proyeccion-qr-modal`): vista a pantalla completa (`requestFullscreen()` tras el clic del docente; si el navegador no lo permite, ocupa la ventana), QR ≥ 60 vmin, PIN en dígitos de ≥ 10 vmin con separador visual (`482 913`), nombre de asignatura/grupo/toma, URL corta de respaldo `…/app/asistencia/pin`, contador "Presentes: N" alimentado por `ASISTENCIA_QR_REGISTRADA.totalPresentes`, barra de rotación CSS y "Próxima rotación: HH:MM:SS" ([SUPUESTO-B-13]); `effect` con `startForGroup(grupoId)` + `listenType(ASISTENCIA_QR_ROTADO)` que reemplaza QR, PIN y tiempos; indicador de conexión SSE (`connectionState$`) con botón "Regenerar" (`rotarQr`) si se pierde la conexión (acción manual, no reintento automático). Botones: "Regenerar", "Dejar de proyectar" (`cerrarQr`), "Cerrar toma".
- **Cierre y faltantes** (`components/toma-faltantes.component.ts`, nuevo): al cerrar una toma (o al recibir `TOMA_CERRADA` del job) se muestra la lista de `consultarFaltantes(tomaId)` en tarjetas (nombre, "Sin lectura" / "Ausente"), con "Marcar presente" por estudiante y selección múltiple "Marcar seleccionados" (un solo `registrarAsistencias` con `AN`); la lista se actualiza con la respuesta y con `ASISTENCIAS_TOMA_ACTUALIZADAS`. Fuera de la ventana los botones se deshabilitan con el mensaje del backend (`SES_008`).
- **Celular y tablet**: todo el flujo (elegir modo, ver faltantes, marcar a mano) funciona a 375 px y 768 px; la proyección se pensó para video beam (alto contraste, sin texto pequeño).
- **Retiros**: `attendance-projection-modal.component.ts` (+ spec, PIN `'392-817'`), `teacher-proyeccion-qr-modal.component.ts`, el bloque QR de `teacher-grupos.component.ts` (~612-686, `setInterval` y llamada a `qr-token`) y `datosQr: any` (F-DOC-002, F-DOC-003).

### 4.4 Docente: grupo, sábana y cancelación

- `teacher-grupo-sesiones.component.ts` / `teacher-grupo-hub.component.ts`: cada sesión muestra `estado` (etiqueta "Cancelada" + motivo o festivo) y las acciones "Tomar asistencia" (navega a `/app/asistencia` con grupo y sesión) y "Cancelar sesión" (solo si no está cancelada; la habilitación final la decide el backend con `SES_012`).
- `modals/teacher-sesion-cancelar-modal.component.ts`: `textarea` con contador (10-500), botón deshabilitado fuera de rango, llama `cancelarSesion`, muestra el `mensaje` del backend y cierra; la lista se actualiza con la respuesta y con `SESION_CANCELADA` (HU047).
- `teacher-grupo-sabana.component.ts`: el porcentaje, las fallas y el semáforo salen de `consultarResumen` (`porcentajeInasistencia`, `horasFalta`/`horasDictadas`, `codigoPermanencia`); se eliminan `getPorcentajeFaltasEstudiante`, el conteo local de SJC y los umbrales 20/10 quemados (F-DOC-004). Las columnas de sesiones canceladas se muestran atenuadas con la etiqueta. Con varias tomas, la celda muestra el estado consolidado y, si `esParcial`, "Parcial" con el detalle por toma en el tooltip/hoja inferior.
- `group-sessions-overview.component.ts`: `estudiantesEnRiesgo` = cantidad con `codigoPermanencia` en `RIESGO`/`PERDIDA` del resumen; `promedioAsistencia` = promedio de `porcentajeAsistencia` del resumen (los dos números vienen del backend; el cliente solo cuenta o promedia filas ya calculadas, sin reglas de negocio). Excluye sesiones canceladas del total.

### 4.5 Estudiante

- **Rutas nuevas** en `app.routes.ts` (hijas de `app`, `authGuard` + `roleGuard` con `ESTUDIANTE`): `asistencia/qr` y `asistencia/pin` → `features/student/student-attendance-qr/student-attendance-qr.component.ts`. No chocan con `asistencia` (docente, ruta hoja). El QR abre `…/app/asistencia/qr?t=<token>` con la **cámara nativa** del celular (sin librería de escaneo ni `getUserMedia`); si no hay sesión, `authGuard` lleva al login y tras el login vuelve a la misma URL con el token. **NB-8:** para estas dos rutas el `authGuard` guarda la URL de retorno (con `?t=`) del lado del cliente en `sessionStorage` (clave propia, se borra al leerla, vida máxima la del token) y redirige a `/login` **sin** `returnUrl` en la query; la URL de retorno nunca viaja al IdP (ni en `redirect_uri` ni en `state`), así que el token no queda en los logs de Keycloak. Guardar ese dato en `sessionStorage` no contradice AGENTS.md (no es un JWT; es un token de un solo uso con vida de segundos).
- **Comportamiento**: lee `t` una sola vez, lo borra de la barra de direcciones (`router.navigate([], { queryParams: { t: null }, replaceUrl: true })`), llama `registrarPorToken` y muestra una tarjeta de resultado (asignatura, grupo, sesión, toma, hora, "ya estaba registrada" si `yaRegistrado`). Si el backend responde `AQR_001` (p. ej. el token venció durante el login) o `AQR_002`, muestra el mensaje del backend y el formulario de PIN.
- **Formulario de PIN** (`/app/asistencia/pin`): un `input` con `inputmode="numeric"`, `pattern="[0-9]*"`, `autocomplete="one-time-code"`, `maxlength="6"`, `enterkeyhint="send"`, fuente grande y botón de 48 px de alto; valida 6 dígitos antes de enviar; muestra los errores del backend (red del campus, demasiados intentos con `Retry-After`, no matriculado, toma cerrada).
- **Materias** (`student-courses`, `student-courses-list`, `student-course-detail`): cada tarjeta muestra el **% de inasistencia por horas**, `horasFalta` de `horasDictadas`, el semáforo por `codigoPermanencia` con los umbrales que entrega el backend y el texto de permanencia; se eliminan `getProgressColor` (85/75) y el promedio simple de porcentajes (F-EST-002, F-EST-009). El modal antiguo de "Auto-Registro" (`student-courses.component.ts:508-540`) se reemplaza por el botón "Registrar asistencia con PIN" que navega a `/app/asistencia/pin` (F-EST-005, F-EST-017).
- **Sesiones de la materia**: etiqueta "Cancelada" + motivo/festivo, horas de la sesión, estado `PARCIAL`; sin botón de reclamo en canceladas. En B el estudiante **no** se suscribe al SSE (lo abre C, [SUPUESTO-B-17]): ve el estado al cargar o recargar la materia y recibe la notificación `SESION_CANCELADA`.

### 4.6 Coordinador y decano

Las listas de sesiones (`coordinator-management.service.ts:591`, `dean-facultad.service.ts:60` y sus componentes, cronograma HU145) muestran `estado`/`cancelacion`. Los KPIs ya vienen calculados por horas; solo cambian textos de ayuda ("% de inasistencia calculado por horas") en los KPIs que B pasa a horas. El consolidado del coordinador (HU061, F-COO-007), las comparativas y la tendencia quedan sin cambio visual en B (diferidos a D, [SUPUESTO-B-23]).

### 4.7 Administrador: festivos (`/app/admin/festivos`, nuevo)

`features/admin/admin-festivos/admin-festivos.component.ts` + entrada en el menú del administrador. Selector de año (actual y siguiente, o el que se escriba), lista de festivos (fecha legible, día de la semana, nombre, fuente; tarjetas en móvil), cabecera con fuente y fecha de la última carga y "Diferencias con el cálculo local: N", botón "Recargar año" con diálogo de confirmación y resumen del resultado (`RecargaFestivosResponse`), lista paginada de "Sesiones en festivo con asistencia registrada (no se cancelaron)" y **atribución visible**: `<a [href]="atribucion.url" target="_blank" rel="noopener noreferrer">{{ atribucion.texto }}</a>` con los valores del backend. Solo consulta + recarga: no hay edición manual de festivos.

### 4.8 Pruebas RED del frontend (`npm run test:ci`, `npm run verify`)

- Servicios nuevos/modificados: URL, método, cuerpo exacto (`{ token }` / `{ pin }`, `{ modo }`, `{ marcarAusentes }`, `{ motivo }`), mapeo de respuestas y paso del `message` del backend en 400/403/404/409/429.
- `toma-qr-proyeccion`: OnPush; al recibir `ASISTENCIA_QR_ROTADO` cambia QR, PIN y "próxima rotación"; `ASISTENCIA_QR_REGISTRADA` actualiza presentes; **`spyOn(window, 'setInterval')` y `setTimeout` nunca llamados**; se desuscribe al destruirse; "Regenerar" llama `rotarQr` una vez.
- `session-tomas-panel` / `toma-modo-selector` / `toma-faltantes`: habilitación por `ventana.abierta`, tomas abiertas y `maximoTomas`; marcar presente envía un lote de un elemento; selección múltiple; mensajes del backend.
- `student-attendance-qr`: lee y borra `t`; flujo token → éxito / `yaRegistrado` / `AQR_001` → muestra PIN; atributos del input (`inputmode="numeric"`, `maxlength="6"`, `autocomplete="one-time-code"`); validación de 6 dígitos; `auth.guard.spec.ts` (NB-8): en `/app/asistencia/qr?t=…` sin sesión, la URL de retorno queda en `sessionStorage`, la navegación a `/login` no lleva `returnUrl` ni el token, el inicio de sesión hacia el IdP no incluye el token en `redirect_uri` ni en `state`, y tras el login se vuelve a la URL con `?t=` y se borra la clave.
- Sábana y overview: no hay cálculo local (las cifras salen del resumen mockeado; un spec falla si se usan `sessions().length` como denominador).
- Cancelación: modal con contador y límites; lista del docente actualizada por la respuesta y por `SESION_CANCELADA` (canal del titular); `SES_016`/`SES_012` muestran el mensaje del backend.
- Festivos del administrador: render, recarga con confirmación, atribución con el enlace del backend.
- Realtime: `npm run coverage:realtime:check` ≥ 90 % líneas / 80 % ramas con los tipos nuevos.
- Retiros: los specs de `attendance-projection-modal` y del bloque QR de `teacher-grupos` se eliminan junto con el código; `session.service.contract.spec.ts` deja de esperar `qr-token`.
- Revisión en pantalla (Fase 3) a 375 × 812 (`resize_window` `mobile`) y escritorio: proyección legible, PIN con teclado numérico, faltantes y marcación a mano.

---

## 5. Documentación

| Documento | Cambio |
| :--- | :--- |
| `INFRA:docs/user-stories/HU-CATALOG.md` | HU047, HU175 y HU176 pasan de `[BLOQUEADO 501]`/Fase 3 a implementadas, **a certificar en la Fase 3** (evidencia: pruebas de §2.16, §3.11, §4.8 y recorrido en pantalla). HU004, HU009, HU013, HU040, HU041, HU065, HU066, HU070, HU102, HU106, HU133, HU138, HU067 y HU069 llevan la nota "porcentaje de inasistencia calculado por horas (CULM-001 B, DEC-012/DEC-024); `asistencias/faltas/excusas` cuentan tomas" (NB-2). HU061, HU103, HU134 y HU139 llevan la nota **"diferido a D: deben pasar a horas"**. HU144/HU145: "muestran sesiones canceladas" |
| `INFRA:docs/baseline/TECHNICAL_DEBT.md` | **TD-009 sigue abierta** (retiro de `POST /asistencias` diferido a D, [SUPUESTO-B-19]). Deudas nuevas: literales de `RazonCausa` en vistas ([SUPUESTO-B-03]); `usp_registrar_asistencia_estudiante_autonomo` sin consumidor, con `REVOKE`/`DROP` pendiente en D ([SUPUESTO-B-18]); cierre masivo con regla mínima por sesiones distintas, que C reescribe por horas; payload con token en `*_QR_ROTADO` ([SUPUESTO-B-16]); límites de intentos en memoria por JVM; generación v2 en dos fases no atómicas (§2.7.6); comparativas, tendencia y consolidado por horas en D ([SUPUESTO-B-23]); SSE para estudiantes en C ([SUPUESTO-B-17]) |
| `AsistenciasUCO-Infra/scripts/tests/test_all_hus.ps1` (y la copia que use el workspace) | Casos nuevos: HU047 (cancelar con motivo 200; repetir 409; sin motivo 400), HU175 (abrir toma QR 201, abrir QR 201 con `pin`/`urlAsistencia`/`qrPngBase64`, rotar 200, cerrar 200), HU176 (registrar por PIN 201, repetir 200 `yaRegistrado`, PIN inválido 404, cuerpo antiguo 400), tomas (faltantes 200, cierre 200), festivos (GET 200, recarga 200), `GET /estudiante/materias` con `indicadores`. Se elimina la expectativa 501 de `qr-token`; `POST /asistencias` sigue esperando 501 hasta D |
| Contratos WORM | §2.15 (manifiesto de Infra con hashes efectivos, post-freeze `WORK_ITEM` de B, addendum de BD) y §3.10 (golden path 1.2.0, `BACKEND_GOLDEN_PATH_CONTRACT.md`, eventos) |
| `docs/realtime-sse-architecture.md` (workspace) y `docs/rutas-por-rol.md` | Tipos nuevos, política de audiencia (solo titular en B), rutas `/app/asistencia/qr`, `/app/asistencia/pin`, `/app/admin/festivos` |
| `DECISIONES.md` (lo registra el orquestador) | DEC-024 (precisión de DEC-012, `DEC-024-propuesta.md`); drift previo del manifiesto de Infra (B-2); golden path 1.2.0 para B y 1.3.0 para B2 (NB-10); política de audiencia en B y apertura a estudiantes en C (NB-11); cancelación de sesiones pasadas sin asistencia (NB-7) |
| Work items por repo | `docs/work-items/CULM-001-B1-sesiones-festivos/` y `CULM-001-B2-tomas-qr/` en DB, Backend y Frontend (PLAN/RED/GREEN/AUDIT/CLOSURE de cada repo, patrón HU176B) |

---

## 6. Orden de integración, ramas y commits

### 6.1 Orden (confirmado por el orquestador: B.1 → B.2)

**B.1** (rama `feature/CULM-001-B1-sesiones-festivos` en los 4 repos, desde `integracion/CULM-001` con A ya integrado):
1. **DB**: tablas + FKs → funciones/vistas → SP → semillas/permisos → migración 15 → pruebas → manifiesto post-freeze. Gate: `infra.ps1 db-test` sin fallos nuevos (F-000 es de línea base) y `freeze-manifest.ps1` verde.
2. **Backend**: puertos y casos de uso → adaptadores (JPA, calendario, vault) → controladores/seguridad/catálogo de acceso → política de audiencia SSE → scheduler → DTOs de sesión. Gate: `mvnw verify` (con `JAVA_TOOL_OPTIONS` de `ESTADO.md`) y `-Pintegration` de los IT de B.1.
3. **Frontend**: modelos/servicios → estado cancelado en todos los roles → cancelar sesión → festivos del administrador. Gate: `npm run verify`.
4. **Infra**: manifiesto de Infra con los hashes efectivos (B-2), golden path 1.2.0, contrato de eventos, `test_all_hus.ps1`, catálogo y deuda. Gate: `infra.ps1 verify` y `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001` en verde; `-Mode Generate` solo después de la aprobación 9.2 y con el `git diff` de los cuatro `.sha256` revisado.

**B.2** (rama `feature/CULM-001-B2-tomas-qr`, desde `integracion/CULM-001` con B.1 integrado): mismo orden DB → Backend → Frontend → Infra.
- **DB**: catálogos y tablas → `DetalleAsistencia` + secuencia → conversión NOT NULL (semilla 36 / migración 16) → sincronización/toma vigente → SP de tomas → horas (funciones, `uv_resumen_*`, consumidores de §2.9, cierre masivo) → QR → consultas → concurrencia. El GREEN de tomas y horas puede empezar mientras se conoce la causa de F-DOC-015.
- **Backend**: tomas → resúmenes → QR (cuando se conozca la causa de F-DOC-015) → lecturas de §3.6 → concurrencia.
- **Frontend**: tomas y faltantes → proyección → estudiante → sábana/indicadores → retiros y banderas.

Los PRs de cada rama van hacia `integracion/CULM-001`: Backend en `alejovh12/AsistenciasUCO` y DB en `johnjduque/gestion-asistencia-db` (DEC-002), Frontend en `shesho22/AsistenciasUCO-Frontend` e Infra en `AsistenciasUCO/AsistenciasUCO-Infra`. Cada PR enlaza este CONTRACT, `REVIEW-1.md` y la revisión final.

### 6.2 Commits

Conventional Commits en español, en imperativo, de 72 caracteres como máximo y atómicos por capa. Pie: `Refs: HU047|HU175|HU176` y `Refs: CULM-001`.

**B.1**
- DB: `feat(db/tables): agregar sesion cancelada y catalogo de dias festivos` · `feat(db/sp): admitir tolerancia y rechazar sesiones canceladas en SES-01` · `feat(db/sp): implementar cancelacion de sesion con justificacion` · `feat(db/sp): cargar festivos por anio y aplicarlos a las sesiones` · `feat(db/sp): generar sesiones v2 y precargar con festivos cancelados` · `feat(db/views): excluir sesiones canceladas del cumplimiento` · `feat(db/seed): sembrar parametros, mensajes y plantilla de B.1` · `feat(db/migrations): agregar migracion 15 de sesiones y festivos` · `test(db): cubrir ventana con tolerancia, cancelacion y festivos` · `chore(db/scripts): generar manifiestos post-freeze por work item` · `docs(db/contracts): registrar manifiesto post-freeze de CULM-001 B.1`
- Backend: `test(backend): agregar pruebas RED de cancelacion y festivos` · `feat(backend/ports): agregar puertos de cancelacion y calendario` · `feat(backend/adapter): agregar proveedores de festivos y respaldo local` · `feat(backend/usecase): implementar cancelacion de sesion HU047` · `feat(backend/controller): exponer festivos del administrador` · `feat(backend/realtime): agregar politica de audiencia por tipo exacto` · `feat(backend/adapter): generar sesiones con festivos cancelados` · `feat(backend/security): actualizar catalogo de acceso de B.1` · `docs(backend): documentar estado de sesion en el golden path 1.2.0`
- Frontend: `test(frontend): agregar specs RED de sesion cancelada y festivos` · `feat(frontend/docente): cancelar sesion con justificacion` · `feat(frontend/ui): mostrar sesiones canceladas en todos los roles` · `feat(frontend/admin): agregar consulta y recarga de festivos`
- Infra: `docs(contracts): agregar estado de sesion al golden path 1.2.0` · `docs(contracts): fijar hashes efectivos UTC-D06 en el manifiesto de BD` · `test(scripts): agregar HU047 y festivos a test_all_hus` · `docs(hus): actualizar HU047 en el catalogo`

**B.2**
- DB: `feat(db/tables): agregar tomas de asistencia y tokens QR por toma` · `feat(db/migrations): migrar detalles existentes a la toma 1` · `feat(db/sp): resolver la toma vigente al sincronizar asistencia` · `feat(db/sp): abrir, cerrar y registrar asistencia por toma` · `feat(db/sp): emitir, rotar y registrar asistencia por QR` · `feat(db/functions): calcular horas de sesion y de toma` · `feat(db/views): calcular inasistencia por horas en el resumen` · `perf(db/sp): reemplazar MAX+1 por secuencia en detalle de asistencia` · `refactor(db/sp): pasar KPIs de coordinador, decano e institucion a horas` · `fix(db/sp): contar sesiones distintas en el cierre por inasistencia` · `refactor(db/sp): evitar filas duplicadas por toma en consultas diferidas` · `feat(db/seed): sembrar catalogos, parametros y mensajes de B.2` · `test(db): cubrir tomas, horas, QR y concurrencia 5x40` · `docs(db/contracts): ampliar manifiesto post-freeze con B.2`
- Backend: `test(backend): agregar pruebas RED de tomas y QR de asistencia` · `feat(backend/usecase): implementar tomas de asistencia y faltantes` · `feat(backend/usecase): implementar QR rotativo de asistencia HU175` · `feat(backend/usecase): registrar asistencia por token o PIN HU176` · `feat(backend/security): limitar rechazos por ip e intentos por token` · `feat(backend/controller): exponer resumen de asistencia por horas` · `refactor(backend/adapter): consolidar asistencia por sesion con tomas` · `refactor(backend/controller): retirar el endpoint qr-token de sesion` · `test(backend): probar 5 y 20 grupos por 40 estudiantes a la vez`
- Frontend: `test(frontend): agregar specs RED de tomas y QR de asistencia` · `feat(frontend/docente): elegir modo de toma y marcar faltantes` · `feat(frontend/docente): proyectar QR rotativo alimentado por SSE` · `feat(frontend/estudiante): registrar asistencia por QR o PIN` · `fix(frontend/auth): guardar la url de retorno del QR fuera del IdP` · `feat(frontend/estudiante): mostrar inasistencia por horas` · `refactor(frontend/docente): usar resumen del backend en la sabana` · `refactor(frontend/docente): retirar proyeccion QR estatica y timers`
- Infra: `docs(contracts): agregar eventos de tomas y QR al contrato realtime` · `docs(contracts): registrar toma vigente en el golden path de lote` · `test(scripts): agregar HU175 y HU176 a test_all_hus` · `docs(baseline): registrar deudas y diferidos del paquete B` · `docs(hus): actualizar HU175, HU176 y KPIs por horas`

---

## 7. Riesgos, rollback y puntos abiertos

### 7.1 Riesgos

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| R1 | `usp_generar_sesiones_grupo_v2` usa `INSERT … EXEC` sobre el SP congelado, que hace `ROLLBACK` en su `CATCH`: un error interno de la fase 1 produce el 3915 con o sin transacción externa | El `CATCH` del v2 traduce el 3915 (y cualquier error de la fase 1) a `SYS_001` con la tupla canónica; B1-FES-08 lo prueba con una falla inyectada; las dos fases son idempotentes (B-6) |
| R2 | `uv_detalle_asistencia` (congelada) cambia de cardinalidad (una fila por toma) sin cambiar su texto: un consumidor no inventariado duplicaría filas | Inventario de §2.9 y §3.6 contrastado por el revisor con RESEARCH §7; addendum del contrato de BD; con una toma por sesión (todo el histórico tras el backfill) no cambia nada |
| R3 | Se tocan unos 30 archivos de prueba, fixture o limpieza ([SUPUESTO-B-20], §2.16.3) | Solo cambian la inserción o el orden de borrado; la única aserción que cambia es la de `test_attendance_commands.sql:202` (cambio formal por DEC-011); el PR lista archivo por archivo; B2-SEG-02 prueba que los fixtures se pueden repetir |
| R4 | Los KPIs cambian de valor en grupos con sesiones de distinta duración (horas frente a sesiones) | Es la regla 3.3 (DEC-012/DEC-024); `porcentajeInasistenciaSesiones` queda para trazabilidad; nota en el catálogo |
| R5 | El token viaja en `ASISTENCIA_QR_ROTADO` | El canal sigue siendo solo del titular; la política de audiencia usa igualdad exacta; queda registrado como deuda |
| R6 | El QR solo abre la app si `ASISTENCIA_QR/URL_BASE_FRONTEND` es alcanzable por HTTPS desde la red del campus; el token puede vencer durante el login (vigencia ≈ rotación + tolerancia = 120 s) | El PIN es el respaldo (`/app/asistencia/pin`); la página del QR cae al PIN con el mensaje del backend; la URL de retorno no viaja al IdP (NB-8) |
| R7 | Límites de intentos en memoria (una JVM) y `local-sse` sin réplica | Suficiente para la demo (una instancia); deuda registrada |
| R8 | Parámetros en dos catálogos | DEC-018: `sqlserver` en local; valores por defecto en código iguales a la semilla |
| R9 | Con el proveedor `log` por defecto, las notificaciones no llegan al correo | En la demo usar `outbox`/`composite`; `estudiantesNotificados` cuenta lo encolado |
| R10 | F-DOC-015 (500 al abrir la matrícula QR) podría estar en un componente que B.2 reutiliza | Dependencia explícita: el GREEN del QR de B.2 espera la causa raíz (paquete A); tomas y horas avanzan antes |
| R11 | Disponibilidad y "uso razonable" de calendariosnacionales.com; feriados.io sin key en local | Solo se cargan los años que faltan; el respaldo local siempre está disponible; las diferencias quedan en el log |
| R12 | Cierre masivo con varias tomas | Cambio mínimo `COUNT(DISTINCT a.sesion)` (B-7) y prueba B2-HOR-10; C lo reescribe por horas |
| R13 | Huecos en `DetalleAsistencia.codigo` por la secuencia | Ningún contrato exige un consecutivo sin huecos (confirmado por el revisor); `codigo` no se expone como folio de negocio |
| R14 | Tamaño de B frente a la fecha objetivo (2026-11-13) | B.1 y B.2 se integran por separado; se difieren a D comparativas, tendencia, consolidado y retiro de `POST /asistencias`, y a C el SSE para estudiantes |
| R15 | Serialización de los 40 registros de un grupo sobre el bloqueo de `Sesion` | Se mide p95 en B2-CON-01 y en el IT; está aprobada de antemano la alternativa `HOLDLOCK` compartido (NB-4) |
| R16 | Permitir cancelar una sesión pasada sin asistencia la saca del cumplimiento HU065 | Decisión del orquestador (NB-7): solo sin asistencia; con asistencia, `SES_016` y reclamo; queda auditada en `SesionCancelacion` (usuario y fecha) |

### 7.2 Rollback

- **Interruptores sin despliegue**: `ASISTENCIA_QR/HABILITADA = false` (404 `AQR_010` en todo el QR), `FESTIVOS/HABILITADO = false` (job detenido), banderas del frontend `sessionQrEnabled`/`sessionCancelEnabled = false`.
- **Por subpaquete**: se revierten los PRs de B.2 en orden Frontend → Backend → DB y se ejecuta `16_culm001_b2_tomas_asistencia_qr_down.sql`. Esa migración colapsa a la toma 1; si hay varias tomas, exige confirmación y archiva los descartados. Después, si hace falta, se revierte B.1 con `15_…_down.sql`. Antes de cada `up` en el entorno compartido se toma un backup `COPY_ONLY` (patrón de `ESTADO.md`).
- Los contratos WORM se restauran desde Git (versión anterior + `.sha256` previo).

### 7.3 Puntos resueltos por REVIEW-1 y por el orquestador

| Punto de la v1 | Resolución |
| :--- | :--- |
| `porcentajeInasistencia`/`codigoPermanencia` a horas con el mismo nombre | Aceptado; se registra como DEC-024 (`DEC-024-propuesta.md`) antes de congelar |
| Estado consolidado por sesión | Aceptado; `PARCIAL` solo en DTOs que no son golden |
| `estado`/`cancelacion` requeridos en `Sesion`/`SesionV2` | Aceptado, con golden path 1.2.0 y las pruebas de conformidad actualizadas |
| SSE para estudiantes en B | Pasa a C; B solo diseña la política de audiencia del titular |
| Secuencia de `codigo` | Aceptada, con `START WITH` dinámico y B2-MIG-06 |
| Toma implícita cerrada y denominador | Aceptados (DEC-024) |
| `CargaDiaFestivo` | Aceptada |
| 4 tomas y límites | 4 tomas, 120 por token y 6 por estudiante aceptados; IP según B-9 |

### 7.4 Supuestos aplicados (resumen)

[SUPUESTO-B-01] numeración · [SUPUESTO-B-02] banderas de catálogo · [SUPUESTO-B-03] literales de `RazonCausa` en vistas · [SUPUESTO-B-04] toma implícita cerrada · [SUPUESTO-B-05] denominador por horas sin estado de toma (DEC-024) · [SUPUESTO-B-06] registro = asistencia o toma · [SUPUESTO-B-07] 4 tomas · [SUPUESTO-B-08] cierre y corrección dentro de la ventana · [SUPUESTO-B-09] cierre automático por el job · [SUPUESTO-B-10] cancelar futuras o sin asistencia; con asistencia, `SES_012`/`SES_016` · [SUPUESTO-B-11] festivos solo sin registros; futuras en mantenimiento · [SUPUESTO-B-12] IP cuenta solo rechazos (600), token 120, estudiante 6 · [SUPUESTO-B-13] contador sin timers · [SUPUESTO-B-14] secuencia · [SUPUESTO-B-15] estado consolidado · [SUPUESTO-B-16] token en el evento del titular · [SUPUESTO-B-17] SSE de estudiantes en C; política de audiencia del titular en B · [SUPUESTO-B-18] autónomo sin consumidor, permisos intactos (D) · [SUPUESTO-B-19] retiro de `POST /asistencias` en D · [SUPUESTO-B-20] fixtures y limpiezas con `toma` · [SUPUESTO-B-21] aplicación de festivos tras cada carga · [SUPUESTO-B-22] fusión de festivos de la misma fecha · [SUPUESTO-B-23] comparativas, tendencia y consolidado en D.

Además se aplican los [SUPUESTO] del prompt:
- §3.4: límites por token y por estudiante, guardados en parámetros.
- §3.7: el administrador ve y recarga los festivos, pero no los edita. En los grupos ya creados solo se cancelan las sesiones futuras sin asistencia; las demás se reportan.

---

## 8. Respuesta a REVIEW-1

| Objeción | Tipo | Cambio en el contrato (o motivo de no cambiar) |
| :--- | :--- | :--- |
| **B-1** `ALTER COLUMN` falla con 4922 | B | **Aceptada con la corrección exacta del revisor** (orden del orquestador). Los tres dependientes de `toma` solo se crean con `AllowsNull = 0`, en `DetalleAsistencia.sql` y en `zz_foreign_keys.sql`. La semilla 36 y `16_up` ejecutan, en este orden: backfill → borrar dependientes → `ALTER` → `DROP UX` antiguo → recrear. El guard 50002 y el bloque del `UX` antiguo quedan condicionados. Prueba nueva B2-MIG-05 con doble despliegue (§2.3, §2.14, §2.16.2) |
| **B-2** Manifiesto de Infra | B | **Aceptada**. Hash efectivo = `SUPERSEDES` de UTC-D06; `usp_generar_sesiones_grupo.sql = ef9de7e9…` y `usp_registrar_asistencias_sesion.sql = 7217604b…`, copiados del post-freeze. El drift previo se anota en `DECISIONES.md`. `-Mode Generate` solo después de 9.2, con el diff de los cuatro `.sha256` revisado (§2.15) |
| **B-3** Manifiesto post-freeze de B | B | **Aceptada**. Solo líneas `WORK_ITEM` y solo los objetos que B define como contrato; quedan fuera los KPIs, `uv_resumen`, `uv_cumplimiento`, `usp_sincronizar_*`, la ventana SES-01, `zz_foreign_keys.sql` y las semillas. Se añade `GeneratePostFreeze -Manifest` y no hay espejo en Infra (no se verifica) (§2.15) |
| **B-4** Pruebas y fixtures omitidos | B | **Aceptada**. Se añaden las limpiezas (`maint_003g`, `dev_pagination_cleanup`, `test_rec3`, `test_utc_d06:531`, `test_usp_precargar_sesiones_concurrency.ps1:172`), el helper de limpieza, los fixtures del backend y B2-SEG-02. El invariante de `test_attendance_commands.sql:202` pasa a `(asistencia, toma)` como cambio formal; las líneas 182 y 195 no cambian; ninguna otra aserción se relaja (§0 B-20, §2.16.3) |
| **B-5** `REVOKE` del SP autónomo | B | **Aceptada**. Se quitan el `REVOKE` y el `GRANT` del `16_down`; B solo retira el consumidor del backend y el `REVOKE`/`DROP` pasa a D (§0 B-18, §2.13, §2.14) |
| **B-6** Premisa del `INSERT … EXEC` | B | **Aceptada**. Sin `SES_015` (queda reservado) ni el requisito `@@TRANCOUNT = 0`, y sin `NOT_SUPPORTED`. El `CATCH` del v2 traduce el 3915 a `SYS_001`. B1-FES-08 usa una falla inyectada al estilo de `test_rec3` TX-04, con prueba de paridad de la tupla (B1-FES-08b) y ruta feliz dentro de una transacción externa (B1-FES-08c) (§2.7.6, §2.10, §2.16.1, §3.2.3) |
| **B-7** Cierre masivo con varias tomas | B | **Aceptada**: `COUNT(DISTINCT a.sesion)` en el `SELECT` y en el `HAVING`, con B2-HOR-10; `test_mass_period_close.sql` entra en la lista de cambios justificados (§1.4, §2.9, §2.16) |
| **B-8** Conflicto textual con DEC-012 | B | **Aceptada**. El texto de la fila DEC-024 está en `paquetes\B-tomas-qr-sesiones\DEC-024-propuesta.md` para que el orquestador la registre **antes de congelar**; el contrato la cita en [SUPUESTO-B-05] y en §2.6 |
| **B-9** Límite por IP y NAT del campus | B | **Aceptada**. La clave por IP cuenta solo los intentos rechazados (≥ 400 y ≠ 429) y el contador se incrementa en `finally`. El parámetro pasa a `ASISTENCIA_QR/LIMITE_FALLIDOS_IP_POR_MINUTO`. El IT añade una ronda de 20 grupos × 40 desde la misma IP sin ningún 429 (§0 B-12, §2.11, §3.2.7, §3.11) |
| NB-1 `SES_010` | NB | **Aceptada**: `SES_010` se traduce a `ERR_SESION_CANCELADA`, y el 409 del golden path usa `examples` (`cerrada`, `cancelada`) en el `$ref` único (§2.10, §3.1, §3.10) |
| NB-2 Unidades | NB | **Aceptada**: documentado en el addendum y en el catálogo; `tomasDictadas` va junto a `sesionesEjecutadas`; columnas de sesión para los consumidores diferidos; prueba B2-HOR-11 (§2.6, §2.9, §2.15, §5) |
| NB-3 Orden de controles | NB | **Aceptada**: filtro de IP → interruptor → CIDR → estudiante → token (§3.2.7) |
| NB-4 Rendimiento 5×40 | NB | **Aceptada**: se mide p50/p95/máximo por grupo y está aprobada de antemano la alternativa `HOLDLOCK` compartido (§2.8.3, §2.16.2, §3.11) |
| NB-5 Festivos en la misma fecha | NB | **Aceptada**: fusión con " / " ([SUPUESTO-B-22]), prueba de 2038 (§3.4, §3.11) |
| NB-6 Cobertura de B1-FES-06 | NB | **Aceptada**: las 19 fechas de 2026 y las 19 de 2027 (§2.16.1) |
| NB-7 Cancelación retroactiva | NB | **Aceptada en parte, por decisión del orquestador**: se puede cancelar una sesión futura o una sin asistencia registrada (también pasada); una pasada con asistencia exige reclamo (`SES_016`, prueba B1-CAN-08). No se adopta el corte general por `ventanaCierreUtc` que propuso el revisor, porque el orquestador decidió permitir cancelar sesiones pasadas sin asistencia ([SUPUESTO-B-10], R16) |
| NB-8 Token en la URL de retorno | NB | **Aceptada**: `sessionStorage` y sin `returnUrl` hacia el IdP, con spec en `auth.guard.spec.ts` (§4.5, §4.8) |
| NB-9 Cabecera sin detalle | NB | **Aceptada**: prueba B2-HOR-09, `sesionesConCabeceraSinDetalle` en el resultset de control y nota de que las sesiones sin asistencia no reciben toma (§2.14, §2.16.2) |
| NB-10 Versión del golden path | NB | **Aceptada**: 1.2.0 para B y 1.3.0 para B2; pruebas de conformidad actualizadas; `forbiddenGhosts` intacto (§3.10) |
| NB-11 SSE del estudiante y DEC-022 | NB | **Resuelta por el alcance del orquestador**: el SSE para estudiantes queda en C y B solo diseña la política de audiencia para eventos del titular, con igualdad exacta de tipo ([SUPUESTO-B-17], §3.8, §3.11, §4.5) |
| Numeración (DEC-028, complemento del orquestador) | — | Migraciones B.1 = 15 y B.2 = 16 (A usa 13/14, B2 usa 17/18), semillas 34-36, prefijos `culm001_b1`/`culm001_b2` en archivos, pruebas y fixtures (`culm001_b2_toma_fixture.sql`, `test_culm001_b1.ps1`, `test_culm001_b2.ps1`, `zz_archivo_DetalleAsistencia_culm001_b2`) y registro de pruebas por nombre exacto, sin comodín `culm001_b2*` ([SUPUESTO-B-01]) |
| §9 de REVIEW-1 (diferibles) | — | Se difieren a D, como recomendó el revisor y decidió el orquestador: comparativas, tendencia y consolidado (marcados "diferido a D: deben pasar a horas") y el retiro de `POST /asistencias`. **No se difieren** feriados.io (respaldo 1 exigido por 3.7, con implementación mínima) ni la lista de sesiones en festivo con asistencia (salida del SP y su consulta), por decisión del orquestador |
