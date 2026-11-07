---
status: draft
type: contract
scope: db-backend-frontend-infra
work-item: CULM-001
paquete: A
owner: fullstack-team
last-reviewed: 2026-11-06
---

# CONTRACT — CULM-001 paquete A: retiro completo de las solicitudes de ingreso a grupos

Fase SDD: **02 CONTRACT**. Insumos: `../../RESEARCH-SOLICITUDES-INGRESO.md`, `../../DECISIONES.md` (DEC-009, DEC-010), `../../FINDINGS-estudiante.md` (F-EST-016 y el inventario), `../../FINDINGS-docente.md` (inventario), `../../FINDINGS-coordinador.md` (F-COO-004, F-COO-012). Este contrato **no se ejecuta**: lo revisa un Opus independiente antes de la fase RED.

Rutas relativas a la raíz de cada repo, dentro de `C:\Proyectos\GestionAsistencia-CULM001\<repo>\`. Se comprobaron con grep sobre las bases de los worktrees: DB `65a4998`, Backend `72a1675e`, Frontend `886a01b`, Infra `integracion/CULM-001` (`9d55f7c` + 4). Prefijos: `B/` = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, `BT/` = `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`, `F/` = `GestioAsistenciaFrontend/src/app/`.

---

## 1. Alcance y decisiones aplicadas

### 1.1 Decisiones fijas (no se reabren)

| ID | Contenido aplicado en este contrato |
| :--- | :--- |
| Decisión del responsable (prompt 3.1, 2026-11-06) | La matrícula solo se hace por QR/PIN (HU176B) o manualmente por el docente titular (HU050). **HU026, HU053, HU054 y HU055 pasan a `[DESCARTADA]`.** HU008 queda como consulta de oferta y cupos, **sin** "Solicitar ingreso" y **sin** `idSolicitudAbierta` ni `estadoSolicitud` en la respuesta. |
| DEC-009 | La reactivación `EstudianteGrupo` `I` → `A` (regla INT-HU-01) sale de `usp_resolver_solicitud_ingreso_grupo` y pasa a las dos vías que quedan. Las dos llegan a `usp_registrar_estudiante_en_grupo_interno` (manual desde `usp_registrar_estudiante_en_grupo:164`; QR desde `usp_internal_matricular_por_token:232`), así que la regla se pone una sola vez, en un procedimiento interno nuevo que ese interno llama. El cupo se controla con bloqueo. |
| DEC-010 | Antes de borrar la tabla, la migración `up` copia el historial a `dbo.zz_archivo_SolicitudIngresoGrupo` (solo lectura, sin FK). Antes de borrar las plantillas, cancela las notificaciones pendientes de los tipos `SOLICITUD_INGRESO_*`. El `down` restaura la tabla y las plantillas a partir del archivo. |
| F-COO-004 (alta) | El coordinador deja de matricular: (a) `POST /api/v1/grupos/{grupoId}/estudiantes` responde 403 al COORDINADOR en el filtro HTTP; (b) el SP exige perfil `DOCENTE` y titularidad del grupo; (c) se retiran los stubs 501 `POST /api/v1/coordinador/grupos/{grupoId}/estudiantes`, `DELETE /api/v1/coordinador/grupos/{grupoId}/estudiantes/{estudianteId}` y `DELETE /api/v1/grupos/{grupoId}/estudiantes/{estudianteId}`. El retiro sigue siendo `POST /api/v1/docente/grupos/{grupoId}/estudiantes/{estudianteId}/retiro` (HU051). |
| F-COO-012 / F-EST-016 | Se retiran los stubs `GET`/`PATCH /api/v1/coordinador/solicitudes-matricula` y el código muerto del frontend (`abrirSolicitudMatricula`, `enviarSolicitudMatricula`, `crearSolicitudMatricula`, mocks). |

### 1.2 Concreciones de este contrato (las revisa el Opus independiente)

| ID | Concreción | Por qué |
| :--- | :--- | :--- |
| A-C1 | "Cancelar" una notificación (DEC-010) significa pasarla a `FALLIDA_DEFINITIVA` con `codigoError = 'TIPO_NOTIFICACION_RETIRADO'`. No se crea un estado `CANCELADA` en `EstadoNotificacion`. | `seed/22_estado_notificacion.sql` solo tiene `PENDIENTE`, `RESERVADA`, `FALLIDA_REINTENTABLE`, `ENTREGADA` y `FALLIDA_DEFINITIVA`. Un estado nuevo obligaría a tocar el panel `admin-email-management` (filtros fijos en las líneas 581-585 y 1217-1264), el resumen de `usp_consultar_notificaciones_salientes_admin_interno` y la depuración. `FALLIDA_DEFINITIVA` ya es terminal (`esTerminal = 1`): el despachador no la toma y la depuración la trata como cerrada. |
| A-C2 | El estado previo de cada notificación cancelada se guarda en una segunda tabla de archivo, `dbo.zz_archivo_NotificacionSolicitudIngreso`. | Sin ella, el `down` no sabría si una fila estaba `PENDIENTE` o `FALLIDA_REINTENTABLE`, y DEC-010 pide reversibilidad. |
| A-C3 | Los estados `E` (en espera, `C5D1E2F3-4A5B-4C6D-8E7F-901A2B3C4D5E`) y `X` (retirada, `D6E2F3A4-5B6C-4D7E-9F80-A12B3C4D5E6F`) de `dbo.Estado` se borran si ninguna fila los referencia. El archivo guarda el **código** del estado, no la FK. | Solo los usaba `SolicitudIngresoGrupo` (grep: aparecen únicamente en `seed/22_estados_solicitud_ingreso_grupo.sql` y `tables/SolicitudIngresoGrupo.sql:34`). La única FK restante hacia `Estado` es `FK_SolicitudRevisionAsistencia_Estado` (`zz_foreign_keys.sql:275-280`), que usa P, A y R. |
| A-C4 | El código del estado "retirado" se lee de un parámetro nuevo, `MATRICULA` / `ESTADO_RETIRADA` = `I`. No se escribe `'I'` en el SP nuevo. | Regla "cero datos quemados" de AGENTS 3.3; mismo patrón que `MATRICULA_QR/ESTADO_MATRICULA` (`seed/29_parametros_matricula_qr.sql:26`). |
| A-C5 | El texto local `MENSAJE_MATRICULA_DUPLICADA_DOCENTE` (`F/features/attendance/attendance-control/attendance-control.component.ts:64-65`) se cambia y deja de remitir al flujo retirado. No se cambia el catálogo de mensajes (Azure App Configuration / MessageUcoLab). | Con DEC-009 el 409 `ERR_MATRICULA_DUPLICADA` solo aparece con una matrícula **activa**. Pasar ese texto al catálogo queda como deuda (sección 7, R-9). |

### 1.3 Fuera de alcance

- Reclamos (`SolicitudRevisionAsistencia`, `usp_*solicitud_revision*`, `uv_*solicitud_revision*`, `estadoSolicitud` de reclamos, estados P/A/R). Son homónimos y **no se tocan**.
- HU176B (`usp_matricular_estudiante_por_token`, `usp_registrar_estudiante_por_token_publico`, `usp_internal_resolver_token_matricula`, rotación): solo se ve afectada de forma indirecta, por la reactivación que hace el interno.
- F-EST-020 (la materia con matrícula `I` aparece en `GET /estudiante/materias`): queda para el paquete del estudiante.
- El cruce de horario cuenta matrículas `I` de **otros** grupos (`usp_validar_cruce_horario_estudiante_interno.sql:67-80`, no filtra por estado): es un defecto previo. Se anota como R-8 y no se corrige aquí.
- `usp_consultar_oferta_grupos_estudiante` lee tablas en lugar de una vista `uv_*`. Es una desviación previa de la regla "consulta paginada vía SP sobre vista". Se conserva su estructura; solo se le quitan las columnas de solicitud.

### 1.4 Contratos WORM: **sin cambio de contrato congelado**

Se comprobó con grep (`solicitud.?ingreso|solicitudes-matricula|solicitudes-ingreso|SolicitudIngreso|SOLICITUD_INGRESO|oferta-academica|oferta_grupos`) sobre `AsistenciasUCO-Infra/docs/contracts/**` y sobre la copia del backend `GestioAsistenciaBackend/docs/contracts/openapi/openapi-golden-path.yaml`: **0 coincidencias**. La única aparición de "solicitud" en el OpenAPI del backend (línea 941) es el texto genérico "La solicitud contiene campos inválidos".

| Contrato | Qué menciona de lo que se toca | Cambia |
| :--- | :--- | :--- |
| `docs/contracts/openapi/openapi-golden-path.yaml` (+`.sha256`) | Solo `GET /api/v1/grupos/{grupoId}/estudiantes` (línea 124). No contiene `POST`/`DELETE` de esa ruta, ni la oferta, ni las solicitudes | No |
| `docs/contracts/openapi/BACKEND_GOLDEN_PATH_CONTRACT.md` (+`.sha256`) | Fila 3: `GET /api/v1/grupos/{grupoId}/estudiantes` | No |
| `docs/contracts/db/DB_BASELINE_CONTRACT.md` y `DB_BASELINE_CONTRACT.sha256` | Nada | No |
| `docs/contracts/db/DB_DEVELOP_FREEZE_MANIFEST.sha256` | 10 archivos: `uv_horario_docente`, `uv_sesion`, **`uv_estudiante_grupo`**, `uv_asistencia`, `uv_detalle_asistencia`, `usp_crear_sesion`, `usp_actualizar_sesion`, `usp_generar_sesiones_grupo`, `usp_registrar_asistencias_sesion` y el contrato | No. **`uv_estudiante_grupo.sql` no se edita**: el SP nuevo lee `EstudianteGrupo` y `uv_estado_estudiante_grupo` |
| `docs/contracts/db/DB_DEVELOP_FREEZE_ADDENDUM.md` | Línea 80: `usp_registrar_estudiante_en_grupo` es el "STUDENT-GROUP CANONICAL COMMAND" (NON-GOLDEN; no está en el manifiesto) | No. Su firma y su resultset no cambian; cambian las reglas internas (perfil, titularidad, reactivación), igual que en LB-002.1C-A |
| `docs/contracts/events/REALTIME_EVENT_CONTRACT.md` (+`.sha256`) | Nada (no hay eventos SSE de solicitudes) | No |

Contratos **vivos, no WORM**, que sí cambian: el JSON de `GET /api/v1/estudiante/oferta-academica` (HU008 pierde 2 campos, sección 3.4) y `GestioAsistenciaBackend/docs/contracts/HTTP_AS_IS_MATRIX.md`. Compuerta: `.\AsistenciasUCO-Infra\infra.ps1 verify` (y `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001`) no debe sumar fallos a la línea base registrada en `ESTADO.md`. La línea base ya trae dos fallos previos, `DB_OBJ_MISMATCH` de `usp_generar_sesiones_grupo.sql` y `usp_registrar_asistencias_sesion.sql`, que este paquete no toca.

---

## 2. Base de datos (`GestioAsistenciaDB/`)

### 2.1 Objetos que se eliminan (se borra el archivo de `schema/` y se hace `DROP` en la migración)

`deploy_schema.ps1` vuelve a crear todo lo que encuentra en `schema/{tables,stored-procedures,security,seed}`. Por eso hay que borrar los archivos, como hizo CAT-01.

| # | Objeto | Archivo a borrar |
| :--- | :--- | :--- |
| D-01 | Tabla `dbo.SolicitudIngresoGrupo`: PK `PK_SolicitudIngresoGrupo`, default `DF_SolicitudIngresoGrupo_fechaSolicitudUtc`, índices `UX_SolicitudIngresoGrupo_Abierta` (filtrado por P/E) e `IX_SolicitudIngresoGrupo_Grupo_Estado_Fecha` | `schema/tables/SolicitudIngresoGrupo.sql` |
| D-02 | FK `FK_SolicitudIngresoGrupo_Estudiante`, `_Grupo`, `_Estado`, `_Docente`, `_EstudianteGrupo`. Ninguna tabla externa referencia a `SolicitudIngresoGrupo` | Se quita el bloque "42-46" de `schema/tables/zz_foreign_keys.sql` (líneas 352-377). El archivo se conserva |
| D-03 | SP `usp_registrar_solicitud_ingreso_grupo` | `schema/stored-procedures/usp_registrar_solicitud_ingreso_grupo.sql` |
| D-04 | SP `usp_resolver_solicitud_ingreso_grupo` | `schema/stored-procedures/usp_resolver_solicitud_ingreso_grupo.sql` |
| D-05 | SP `usp_retirar_solicitud_ingreso_grupo` | `schema/stored-procedures/usp_retirar_solicitud_ingreso_grupo.sql` |
| D-06 | SP `usp_consultar_solicitudes_ingreso_grupo_docente` | `schema/stored-procedures/usp_consultar_solicitudes_ingreso_grupo_docente.sql` |
| D-07 | SP `usp_consultar_solicitudes_ingreso_estudiante` | `schema/stored-procedures/usp_consultar_solicitudes_ingreso_estudiante.sql` |
| D-08 | SP `usp_consultar_destinatarios_solicitud_ingreso_grupo` | `schema/stored-procedures/usp_consultar_destinatarios_solicitud_ingreso_grupo.sql` |
| D-09 | `GRANT EXECUTE` de D-03..D-08 a `rol_asistencias_runtime`. Si el archivo se quedara, haría `THROW 52183..52188` al faltar los SP | `schema/security/rol_asistencias_runtime_hu053_hu055.sql` |
| D-10 | Seed de los estados `E` y `X` en `dbo.Estado` (A-C3) | `schema/seed/22_estados_solicitud_ingreso_grupo.sql` |
| D-11 | Seed de los mensajes `SIG_001`..`SIG_015` (usuario y técnico) | `schema/seed/23_mensajes_solicitud_ingreso_grupo.sql` |
| D-12 | Prueba `test/test_solicitud_ingreso_grupo.sql` (S-01..S-12) | Se borra el archivo y su línea `:r /tmp/test/test_solicitud_ingreso_grupo.sql` de `test_suite.sql:34` |

No hay vistas `uv_*` ni funciones `ufn_*` propias de las solicitudes (grep sin coincidencias), ni filas propias en `CatalogoParametro`.

### 2.2 Objetos que se editan

| # | Archivo | Antes | Después |
| :--- | :--- | :--- | :--- |
| E-01 | `schema/stored-procedures/usp_consultar_oferta_grupos_estudiante.sql` | Firma `(@busqueda NVARCHAR(50)=NULL, @numeroPagina INT=1, @tamanoPagina INT=10, @idCorrelacion UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER)`. Resultset de **21** columnas: `0 idGrupo, 1 codigoGrupo, 2 nombreGrupo, 3 idAsignatura, 4 codigoAsignatura, 5 nombreAsignatura, 6 nombreDocente, 7 idPeriodoAcademico, 8 nombrePeriodoAcademico, 9 fechaInicioPeriodo, 10 fechaFinPeriodo, 11 estadoPeriodo, 12 horario, 13 capacidadMaxima, 14 estudiantesActivos, 15 cuposDisponibles, 16 matriculado, 17 idSolicitudAbierta, 18 codigoEstadoSolicitud, 19 codigoComponente, 20 totalRegistros`; `OUTER APPLY` sobre `dbo.SolicitudIngresoGrupo` (líneas 152-157) | **Firma igual.** Resultset de **19** columnas: `0..16` iguales, `17 codigoComponente NVARCHAR(3)`, `18 totalRegistros INT`. Se quitan las líneas 145-146 y el `OUTER APPLY` 152-157. La cabecera (líneas 17-21) deja de mencionar HU053-HU055 y el "enlace del docente, HU053" pasa a "QR/PIN o matrícula manual del docente". Orden, paginación (`OFFSET/FETCH`, `COUNT(*) OVER()`), ámbito ESP/transversales y `OFERTA.INCLUIR_TRANSVERSALES`: sin cambio |
| E-02 | **Nuevo** `schema/stored-procedures/usp_internal_reactivar_matricula_retirada.sql` | — | Ver 2.3. Sin `GRANT` al runtime (es interno) |
| E-03 | `schema/stored-procedures/usp_registrar_estudiante_en_grupo_interno.sql` | Firma `(@idEstudiante, @idGrupo, @idCorrelacion, @codigoEstado NVARCHAR(10)='A', @mensajeUsuarioResultado OUT, @mensajeTecnicoResultado OUT, @estadoResultado BIT OUT)`. Pasos: estado → estudiante existe → grupo existe → cupo → cruce de horario → duplicado (`uv_estudiante_grupo` sin filtro de estado, `ERR_MATRICULA_DUPLICADA`) → `INSERT` | **Firma igual.** Entre el cruce de horario (línea 105) y el duplicado (línea 107) se añade `EXEC dbo.usp_internal_reactivar_matricula_retirada @idEstudiante, @idGrupo, @idCorrelacion, @codigoEstadoDestino = @codigoEstadoDefecto, ..., @reactivada OUTPUT`. Con `@reactivada = 1` **no** se valida duplicado ni se inserta (el mensaje y el estado son los del SP nuevo). Con `@reactivada = 0` y `@estadoResultado = 1`, el flujo sigue igual. Si el SP nuevo devuelve `@estadoResultado = 0` (por ejemplo, cupo agotado bajo bloqueo), se propaga |
| E-04 | `schema/stored-procedures/usp_registrar_estudiante_en_grupo.sql` (F-COO-004) | Línea 62: `@codigoPerfilRequerido = 'DOCENTE,COORDINADOR'`; sin validación de titularidad | `@codigoPerfilRequerido = 'DOCENTE'`. Después del PASO 1.8 (grupo existe, línea 70-78) y antes del cupo, nuevo PASO 1.85: `EXEC dbo.usp_validar_titularidad_jerarquica_interno @idUsuario = @idUsuarioEjecutorDefecto, @idEntidadPadre = @idGrupoDefecto, @tipoEntidadPadre = 'GRUPO', ...`, que responde `SEC_002` (patrón de `usp_cerrar_ventana_matricula_grupo.sql:69-76`). Firma y resultset sin cambio. El DOCENTE titular sigue pudiendo matricular; el COORDINADOR recibe `SEC_001`; un DOCENTE que no es titular recibe `SEC_002` |
| E-05 | `schema/tables/zz_foreign_keys.sql` | Bloque "42-46" (líneas 352-377) | Bloque quitado (D-02) |
| E-06 | `schema/seed/04_mensaje.sql` | Líneas 118 (usuario) y 254 (técnico): `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA` | Filas quitadas |
| E-07 | `schema/seed/26_plantillas_notificacion.sql` | Marcadores, líneas 17-22, y plantillas, líneas 71-73, de `SOLICITUD_INGRESO_REGISTRADA`, `_RESUELTA` y `_RETIRADA` | Filas quitadas. `RETIRO_ESTUDIANTE_GRUPO` y las demás, intactas |
| E-08 | **Nuevo** `schema/seed/33_parametro_reactivacion_matricula.sql` | — | `MERGE` idempotente en `CatalogoParametro`: `('MATRICULA', 'ESTADO_RETIRADA', N'I', 'STRING', N'I')`, con la misma forma que `29_parametros_matricula_qr.sql` (columnas `grupo, clave, valor, tipoDato, valorDefecto`) |
| E-09 | `test_suite.sql` | Línea 34, `test_solicitud_ingreso_grupo.sql` | Línea quitada. Se añade `:r /tmp/test/test_culm001_a_retiro_solicitudes.sql` **después** de `test_usp_matricular_estudiante_por_token.sql` (porque usa la ventana QR) |
| E-10 | `test/test_contract_closure.sql` | Excepciones en líneas 201-206 y listas `NOT IN` en 252, 271 y 292 con `usp_resolver_solicitud_ingreso_grupo`, `usp_consultar_solicitudes_ingreso_grupo_docente`, `usp_consultar_solicitudes_ingreso_estudiante` y `usp_consultar_destinatarios_solicitud_ingreso_grupo` | Esos 4 nombres quitados de los comentarios y de las 3 listas. No se añaden excepciones nuevas: el SP nuevo es `usp_internal_*` y no es público |
| E-11 | `test/test_notif002a_plantillas_contacto.sql` | Líneas 36, 49-83, 94-104 y 328-330: aserciones de los 3 tipos y conteos | Se quitan las aserciones de los 3 tipos y los conteos esperados se recalculan **restando exactamente** las filas retiradas (3 plantillas, 6 marcadores). No se relaja ninguna otra aserción |
| E-12 | `test/test_usp_consultar_oferta_grupos_estudiante.sql` | Fixture `INSERT INTO dbo.SolicitudIngresoGrupo` (línea 96); `#o` con 21 columnas (99-103); G2 "con solicitud abierta P" (128-129); `idSolicitudAbierta IS NULL` (123) | Fixture quitado; `#o` con 19 columnas; G2 se valida como `PROXIMO` con `cuposDisponibles = 30` y `matriculado = 0`; se quita la condición `idSolicitudAbierta IS NULL`. **Se añade O-06** (2.6, T-02). O-01..O-05 se conservan sin relajar |
| E-13 | `test/test_hu008_regla_inscripcion_programa.sql` | RI-01..RI-03 matriculan por `usp_registrar_solicitud_ingreso_grupo` + `usp_resolver_solicitud_ingreso_grupo` (líneas 55-85) | La vía pasa a ser `usp_registrar_estudiante_en_grupo` ejecutado por el **docente titular** (`@userT`), con usuarios ya existentes (el SP encuentra el correo y no crea un usuario nuevo). Las mismas 3 reglas: ESP inscribe en `EstudiantePrograma`; INS y BAS no. Se quitan `#rx`, los `@s*` y la nota de `QUOTED_IDENTIFIER` del índice filtrado. Se añade RI-04: reactivación `I`→`A` en una ESP sin `EstudiantePrograma` previo → lo inscribe |
| E-14 | `test/test_int_hu01_reactivar_matricula_retirada.sql` | RM-01..RM-03 por solicitud + resolver | Se reescribe con T-03, T-05 y T-06 de 2.6 (manual). Conserva los nombres `INT_HU01_RM01_*`, `RM02_*` y `RM03_*` con la regla nueva: RM-02 pasa de "queda EN ESPERA" a "rechaza `ERR_CUPO_SUPERADO`", porque la lista de espera desaparece con HU055 |
| E-15 | `test/test_usp_registrar_estudiante_en_grupo_usuario_no_existente.sql` | Línea 13: el ejecutor es `TOP 1` docente activo cualquiera, no necesariamente el titular de `@grupo` | El ejecutor pasa a ser el titular de `@grupo` (`uv_grupo.idDocente` → `uv_docente_identidad.idUsuario`). Es un ajuste del fixture por el cambio formal E-04, no un relajamiento: los casos `STUDENT_SUCCESS`, grupo inexistente, cerrado y lleno conservan sus aserciones. Se añaden T-08 y T-09 (2.6) en `test_culm001_a_retiro_solicitudes.sql` |

### 2.3 Contrato del SP nuevo `dbo.usp_internal_reactivar_matricula_retirada` (DEC-009)

```text
CREATE OR ALTER PROCEDURE [dbo].[usp_internal_reactivar_matricula_retirada]
(
    @idEstudiante            UNIQUEIDENTIFIER,
    @idGrupo                 UNIQUEIDENTIFIER,
    @idCorrelacion           UNIQUEIDENTIFIER,
    @codigoEstadoDestino     NVARCHAR(10),          -- codigo de uv_estado_estudiante_grupo (A desde el interno)
    @mensajeUsuarioResultado NVARCHAR(4000) OUTPUT,
    @mensajeTecnicoResultado NVARCHAR(4000) OUTPUT,
    @estadoResultado         BIT OUTPUT,
    @reactivada              BIT OUTPUT             -- 1 si hubo I -> destino; 0 si no habia matricula retirada
)
```

Reglas:
1. `SET NOCOUNT ON; SET XACT_ABORT ON;`, con `BEGIN TRY/CATCH`. Abre transacción propia si `@@TRANCOUNT = 0`; si no, `SAVE TRANSACTION sp_reactivar_matricula`. Es el mismo patrón que `usp_retirar_estudiante_grupo.sql:57-190`. En el `CATCH`: `IF @@TRANCOUNT > 0` con transacción propia hace `ROLLBACK TRANSACTION`; con savepoint y `XACT_STATE() = 1` hace `ROLLBACK TRANSACTION sp_reactivar_matricula`; con `XACT_STATE() = -1` y sin transacción propia, `THROW` (lo recoge el llamador; `usp_internal_matricular_por_token:273-274` ya lo maneja). Mensaje `SYS_001` y `ufn_obtener_detalle_error`.
2. Todo parámetro se evalúa con `IS NULL`; los defectos se toman con `ufn_obtener_parametro_guid` / `ufn_obtener_parametro_texto` (sin `ISNULL` ni el GUID vacío literal).
3. El código retirado sale de `dbo.ufn_obtener_parametro('MATRICULA', 'ESTADO_RETIRADA')` y el id de destino, de `uv_estado_estudiante_grupo WHERE codigo = @codigoEstadoDestino`. Si alguno de los dos no existe: `GEN_001`, `@estadoResultado = 0`, sin escribir nada.
4. Bloqueo y cupo: `SELECT @capacidad = g.cantidadEstudiantes FROM dbo.Grupo g WITH (UPDLOCK, HOLDLOCK) WHERE g.id = @idGrupo`; `SELECT @activos = COUNT(*) FROM dbo.EstudianteGrupo eg WITH (UPDLOCK, HOLDLOCK) INNER JOIN dbo.uv_estado_estudiante_grupo es ON es.id = eg.estado WHERE eg.grupo = @idGrupo AND es.codigo = @codigoEstadoDestino`; y la matrícula retirada `SELECT TOP 1 @idEstudianteGrupo = eg.id ... WITH (UPDLOCK, HOLDLOCK) WHERE eg.grupo = @idGrupo AND eg.estudiante = @idEstudiante AND es.codigo = @codigoRetirada ORDER BY eg.id`.
5. Sin matrícula retirada: `@reactivada = 0`, `@estadoResultado = 1`, sin escrituras; se confirma la transacción propia o se libera el savepoint.
6. Con matrícula retirada y `@capacidad - @activos <= 0`: `ERR_CUPO_SUPERADO` (`@p_param1 = @idGrupo`), `@estadoResultado = 0`, `@reactivada = 0`, sin escrituras.
7. Con matrícula retirada y cupo: `UPDATE dbo.EstudianteGrupo SET estado = @idEstadoDestino WHERE id = @idEstudianteGrupo`. Se conserva la **misma fila**, y con ella sus asistencias históricas (es la regla INT-HU-01 tal como estaba en `usp_resolver_solicitud_ingreso_grupo.sql:174-200`). La regla HU008 se aplica igual que en el interno: si la asignatura es de componente `ESP` y no existe la fila `EstudiantePrograma`, se inserta. Mensaje de éxito `GEN_004` (`@p_param1 = 'Estudiante en Grupo'`), el mismo que el alta. `@reactivada = 1`, `@estadoResultado = 1`.
8. `@mensajeTecnicoResultado` termina en `' Correlacion: ' + @idCorrelacion`, como el resto de internos.
9. `@@TRANCOUNT` al salir es igual al de entrada.

Efecto en las vías:
- **Manual (HU050):** `POST /api/v1/grupos/{grupoId}/estudiantes` con un estudiante retirado → 201 y la misma matrícula `A`. Antes respondía 409 `ERR_MATRICULA_DUPLICADA`. Con matrícula activa, sigue el 409.
- **QR/PIN (HU176B):** `usp_internal_matricular_por_token` solo rechaza con `MQR_004` si la matrícula está en `MATRICULA_QR/ESTADO_MATRICULA` (`A`) (líneas 146-154); una `I` pasa al interno, que la reactiva. `TokenMatriculaGrupo.totalMatriculas` se incrementa (línea 244). En modo público no hay estudiante conocido: no hay reactivación, y `MQR_005` sigue rechazando a la persona ya registrada.

### 2.4 Migración `migrations/13_retiro_solicitudes_ingreso_grupo_up.sql`

Siguiente número libre: el último en uso es `12_categoria_justificacion_*` (hay dos `11_*`). Cabecera al estilo de `11_catalogos_solo_consulta_up.sql`: `USE [gestionasistenciadb]; GO; SET NOCOUNT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;`, más un comentario con la decisión del responsable (2026-11-06), DEC-009, DEC-010, F-COO-004 y "deploy_schema.ps1 no borra objetos. Idempotente". Cada paso se puede volver a ejecutar sin efecto.

| Paso | Lote | Contenido | Idempotencia |
| :--- | :--- | :--- | :--- |
| U-0 | propio | Precondición: si `OBJECT_ID('dbo.SolicitudIngresoGrupo','U') IS NOT NULL` y hay filas de `NotificacionSaliente` en `RESERVADA` de los 3 tipos con `reservadoHasta > SYSDATETIMEOFFSET()`, `THROW 53300, 'CULM001_A: hay notificaciones de solicitud reservadas por el despachador; detener el backend y reintentar.', 1` | Solo lectura |
| U-1 | propio | `IF OBJECT_ID('dbo.zz_archivo_SolicitudIngresoGrupo','U') IS NULL CREATE TABLE dbo.zz_archivo_SolicitudIngresoGrupo (id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_zz_archivo_SolicitudIngresoGrupo PRIMARY KEY, estudiante UNIQUEIDENTIFIER NOT NULL, grupo UNIQUEIDENTIFIER NOT NULL, codigoEstado CHAR(1) NOT NULL, fechaSolicitudUtc DATETIME2(7) NOT NULL, fechaResolucionUtc DATETIME2(7) NULL, motivoRechazo NVARCHAR(500) NULL, docenteResolutor UNIQUEIDENTIFIER NULL, estudianteGrupo UNIQUEIDENTIFIER NULL, fechaArchivoUtc DATETIME2(7) NOT NULL CONSTRAINT DF_zz_archivo_SIG_fecha DEFAULT SYSUTCDATETIME(), origen VARCHAR(20) NOT NULL CONSTRAINT DF_zz_archivo_SIG_origen DEFAULT 'CULM-001-A')`. **Sin FK.** También `dbo.zz_archivo_NotificacionSolicitudIngreso (idNotificacion UNIQUEIDENTIFIER NOT NULL PRIMARY KEY, codigoEstadoAnterior VARCHAR(30) NOT NULL, codigoErrorAnterior VARCHAR(40) NULL, detalleErrorAnterior NVARCHAR(300) NULL, proximoIntentoEnAnterior DATETIMEOFFSET(7) NULL, fechaCancelacionUtc DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME())`, sin FK (A-C2). Ningún `GRANT` | `IF OBJECT_ID ... IS NULL` |
| U-2 | propio, transaccional | `SET XACT_ABORT ON; BEGIN TRY; BEGIN TRANSACTION;`. (a) Si existe la tabla: `INSERT INTO zz_archivo_SolicitudIngresoGrupo SELECT s.id, s.estudiante, s.grupo, e.codigo, ... FROM dbo.SolicitudIngresoGrupo s INNER JOIN dbo.Estado e ON e.id = s.estado WHERE NOT EXISTS (archivo con el mismo id)`, en SQL dinámico (`sp_executesql`) para que el lote compile sin la tabla. (b) `INSERT INTO zz_archivo_NotificacionSolicitudIngreso` las filas de `NotificacionSaliente` con `tipo IN ('SOLICITUD_INGRESO_REGISTRADA','SOLICITUD_INGRESO_RESUELTA','SOLICITUD_INGRESO_RETIRADA')` cuyo `EstadoNotificacion.esTerminal = 0`, sin duplicar. (c) `UPDATE NotificacionSaliente SET idEstado = (SELECT id FROM EstadoNotificacion WHERE codigo = 'FALLIDA_DEFINITIVA'), codigoError = 'TIPO_NOTIFICACION_RETIRADO', detalleError = N'CULM-001 A: el tipo de notificacion fue retirado con las solicitudes de ingreso.', proximoIntentoEn = NULL, reservadoHasta = NULL, reservadoPor = NULL` para esas filas (A-C1). (d) `DELETE PlantillaNotificacionMarcador` y luego `DELETE PlantillaNotificacion` de los 3 tipos (no hay FK desde `NotificacionSaliente.tipo`). (e) `DELETE CatalogoMensajeUsuario` y `CatalogoMensajeTecnico` donde `codigo IN ('SIG_001',...,'SIG_015','ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA')`. (f) `MERGE` del parámetro `MATRICULA/ESTADO_RETIRADA` (E-08). `COMMIT`. En el `CATCH`: `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;` | `NOT EXISTS` / `MERGE` / `DELETE` sobre lo ya borrado = 0 filas |
| U-3 | propio | Guardia: si existe la tabla y `EXISTS (fila de la tabla sin fila en el archivo)`, `THROW 53301, 'CULM001_A: archivo incompleto; no se elimina SolicitudIngresoGrupo.', 1` | Solo lectura |
| U-4 | un lote por SP | `IF OBJECT_ID(N'dbo.<sp>', N'P') IS NOT NULL DROP PROCEDURE [dbo].[<sp>];` para D-03..D-08. Los `GRANT` caen con el `DROP` | `IF OBJECT_ID` |
| U-5 | propio | `IF OBJECT_ID('dbo.SolicitudIngresoGrupo','U') IS NOT NULL DROP TABLE dbo.SolicitudIngresoGrupo;`. Se lleva por delante las 5 FK, los índices y el default | `IF OBJECT_ID` |
| U-6 | propio | `DELETE FROM dbo.Estado WHERE codigo IN ('E','X') AND id IN ('C5D1E2F3-4A5B-4C6D-8E7F-901A2B3C4D5E','D6E2F3A4-5B6C-4D7E-9F80-A12B3C4D5E6F') AND NOT EXISTS (SELECT 1 FROM dbo.SolicitudRevisionAsistencia r WHERE r.estado = Estado.id);`. Antes, un bloque genérico comprueba en `sys.foreign_keys` que la única FK restante hacia `dbo.Estado` es `FK_SolicitudRevisionAsistencia_Estado`; si aparece otra, `THROW 53302` (A-C3) | `DELETE` idempotente |
| U-7 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_consultar_oferta_grupos_estudiante` con el cuerpo de E-01. Conserva su `GRANT` | `CREATE OR ALTER` |
| U-8 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_internal_reactivar_matricula_retirada` (2.3) | `CREATE OR ALTER` |
| U-9 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_registrar_estudiante_en_grupo_interno` (E-03) | `CREATE OR ALTER` |
| U-10 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_registrar_estudiante_en_grupo` (E-04). Conserva su `GRANT` | `CREATE OR ALTER` |
| U-11 | propio | Verificación final con `PRINT`: `OBJECT_ID` nulos de D-01 y D-03..D-08, conteo de archivo y de notificaciones canceladas | Solo lectura |

Los cuerpos de U-7..U-10 son **copias exactas** de los archivos de `schema/` del mismo commit. La compuerta T-10 compara la definición desplegada con el archivo.

### 2.5 Migración `migrations/13_retiro_solicitudes_ingreso_grupo_down.sql`

Cabecera: "Rollback de 13_retiro_solicitudes_ingreso_grupo_up.sql: restaura los objetos tal como estaban en develop (`65a4998`)". Cuerpos tomados con `git show 65a4998:<ruta>`, como en `11_catalogos_solo_consulta_down.sql`. Orden:

| Paso | Contenido |
| :--- | :--- |
| R-1 | `CREATE OR ALTER` de `usp_registrar_estudiante_en_grupo` (perfil `'DOCENTE,COORDINADOR'`, sin titularidad), `usp_registrar_estudiante_en_grupo_interno` (sin reactivación) y `usp_consultar_oferta_grupos_estudiante` (21 columnas con `OUTER APPLY`). Se crean **antes** que la tabla porque la resolución diferida de nombres lo permite |
| R-2 | `IF OBJECT_ID(...) IS NOT NULL DROP PROCEDURE dbo.usp_internal_reactivar_matricula_retirada`; `DELETE CatalogoParametro WHERE grupo = 'MATRICULA' AND clave = 'ESTADO_RETIRADA'` |
| R-3 | `MERGE` de los estados `E` y `X` con sus ids fijos (contenido de `seed/22_estados_solicitud_ingreso_grupo.sql`) |
| R-4 | `IF OBJECT_ID('dbo.SolicitudIngresoGrupo','U') IS NULL`: se crean la tabla, la PK, el default y los 2 índices (contenido de `tables/SolicitudIngresoGrupo.sql`) |
| R-5 | En una transacción con `XACT_ABORT ON`: `INSERT INTO dbo.SolicitudIngresoGrupo` desde `zz_archivo_SolicitudIngresoGrupo`, resolviendo `estado` por `Estado.codigo` y saltando ids ya presentes. Luego las 5 FK con `IF NOT EXISTS (sys.foreign_keys)`. Si alguna FK no valida, porque un `EstudianteGrupo` o un `Docente` referenciado ya no existe, se crea con `WITH NOCHECK` y se avisa por `PRINT`; los datos no se pierden |
| R-6 | 6 SP completos (D-03..D-08) con `CREATE OR ALTER` y el `GRANT EXECUTE ... TO [rol_asistencias_runtime]` de cada uno (contenido de `rol_asistencias_runtime_hu053_hu055.sql`) |
| R-7 | `MERGE` de los mensajes `SIG_001`..`SIG_015` (usuario y técnico) y de `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA` (líneas 118 y 254 de `04_mensaje.sql`); `MERGE` de los marcadores y de las plantillas de los 3 tipos (líneas 17-22 y 71-73 de `26_plantillas_notificacion.sql`) |
| R-8 | `UPDATE NotificacionSaliente` desde `zz_archivo_NotificacionSolicitudIngreso`: restaura `idEstado` (por código), `codigoError`, `detalleError` y `proximoIntentoEn`, solo si la fila sigue con `codigoError = 'TIPO_NOTIFICACION_RETIRADO'` |
| R-9 | `DROP TABLE` de las dos tablas `zz_archivo_*`, **solo** si cada fila archivada ya está restaurada (si no, `THROW 53310`) |

El `down` es idempotente. El backend que acompaña al `down` es el de develop: la reversión es por despliegue conjunto (sección 7).

### 2.6 Pruebas T-SQL RED

Archivo nuevo: `test/test_culm001_a_retiro_solicitudes.sql`. Las reescrituras E-12..E-15 van en sus archivos. Formato del repo: `SET NOCOUNT ON; SET XACT_ABORT OFF;`, fixtures dentro de **una** transacción con `ROLLBACK` final, `THROW 5xxxx 'TEST FAILED: ...'`, `PRINT 'TEST_PASS:<id>'` y `IF @@TRANCOUNT <> 0 THROW ...` al final. Todas fallan hoy (RED) y pasan tras `up` + `deploy_schema.ps1`.

| ID | Regla | Aserción | Archivo |
| :--- | :--- | :--- | :--- |
| T-01 | Objetos ausentes tras `up` | `OBJECT_ID` nulo para `dbo.SolicitudIngresoGrupo` (`U`) y los 6 SP (`P`); 0 FK `FK_SolicitudIngresoGrupo_%`; 0 filas en `CatalogoMensajeUsuario`/`CatalogoMensajeTecnico` con `SIG_0%`/`SIG_1%` o `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`; 0 filas en `PlantillaNotificacion`/`PlantillaNotificacionMarcador` con `tipo LIKE 'SOLICITUD_INGRESO_%'`; 0 filas en `Estado` con `codigo IN ('E','X')`; `CatalogoParametro MATRICULA/ESTADO_RETIRADA = 'I'` existe | `test_culm001_a_retiro_solicitudes.sql` (`TEST_PASS:CULM001A_T01_OBJETOS_RETIRADOS`) |
| T-01b | Archivo de solo lectura y sin FK | Existen las dos tablas `zz_archivo_*`; `sys.foreign_keys` con `parent_object_id` de cualquiera = 0; `sys.database_permissions` del principal `rol_asistencias_runtime` sobre ellas = 0; ningún módulo (`sys.sql_expression_dependencies`) las referencia | idem (`CULM001A_T01B_ARCHIVO_AISLADO`) |
| T-02 | La oferta no trae columnas de solicitud | `sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.usp_consultar_oferta_grupos_estudiante'), 0)` devuelve 19 columnas; ninguna se llama `idSolicitudAbierta` ni `codigoEstadoSolicitud`; `column_ordinal` 18 = `codigoComponente` y 19 = `totalRegistros`. Fija el orden posicional que lee el backend | `test_usp_consultar_oferta_grupos_estudiante.sql` (O-06, `TEST_PASS:HU008_OFERTA_SIN_SOLICITUD`) |
| T-03 | Reactivación manual `I`→`A` | Con fixtures: E1 matriculado por `usp_registrar_estudiante_en_grupo` (ejecutor `@userT` titular), retirado por `usp_retirar_estudiante_grupo` (`I`); al volver a matricular manualmente: `estadoResultado = 1`, mensaje `GEN_004`, `COUNT(EstudianteGrupo WHERE grupo, estudiante) = 1`, **mismo `id`** de antes y estado `A` | `test_int_hu01_reactivar_matricula_retirada.sql` (`INT_HU01_RM01_REACTIVA_MATRICULA`) |
| T-04 | Reactivación por QR `I`→`A` con cupo | Ventana abierta por `usp_abrir_ventana_matricula_grupo` (PIN de prueba, igual que en `test_usp_matricular_estudiante_por_token.sql:68-76`); E2 matriculado y retirado (`I`); `usp_matricular_estudiante_por_token @pin, @idUsuarioEjecutor = <usuario E2>`: `estadoResultado = 1`, misma fila `EstudianteGrupo` en `A`, `TokenMatriculaGrupo.totalMatriculas` + 1 | `test_culm001_a_retiro_solicitudes.sql` (`CULM001A_T04_QR_REACTIVA`) |
| T-05 | Un grupo lleno rechaza la reactivación | Grupo con `cantidadEstudiantes = activos`; E1 en `I`; manual → `estadoResultado = 0`, mensaje `ERR_CUPO_SUPERADO`, E1 sigue en `I` y sin filas nuevas; mismo caso por QR → `estadoResultado = 0` (`ERR_CUPO_SUPERADO`), `totalMatriculas` sin cambio | `test_int_hu01_...` (`INT_HU01_RM02_CUPO_RESPETADO`) y `test_culm001_a_...` (`CULM001A_T05_QR_CUPO_LLENO`) |
| T-06 | Una matrícula activa sigue bloqueando | E1 en `A`; manual → `ERR_MATRICULA_DUPLICADA`, sin cambios; QR → `MQR_004` | `test_int_hu01_...` (`INT_HU01_RM03_ACTIVA_SIGUE_BLOQUEADA`) |
| T-07 | Regla ESP del programa al reactivar | Asignatura ESP, E3 en `I` y sin `EstudiantePrograma`; la reactivación inserta `EstudiantePrograma`; con INS o BAS no lo inserta | `test_hu008_regla_inscripcion_programa.sql` (RI-04) |
| T-08 | El coordinador no matricula (F-COO-004) | `usp_registrar_estudiante_en_grupo` con `@idUsuarioEjecutor` = un coordinador → `estadoResultado = 0` con el mensaje `SEC_001` de `usp_validar_permiso_rbac_usuario_interno`; sin `Usuario`/`Estudiante`/`EstudianteGrupo` nuevos | `test_culm001_a_...` (`CULM001A_T08_COORDINADOR_403`) |
| T-09 | Un docente que no es titular no matricula | Docente activo que no es titular del grupo → `estadoResultado = 0`, `SEC_002`; sin escrituras | idem (`CULM001A_T09_DOCENTE_NO_TITULAR`) |
| T-10 | El `down` restaura y el `up` es idempotente | Se ejecuta fuera de `test_suite.sql`, en un script de `scripts/` invocado por `infra.ps1 db-test` solo en entorno local. Secuencia: `up` → `up` (sin error ni cambios: mismos conteos de archivo) → `down` → comprobaciones (existen la tabla, los 6 SP con `GRANT`, `E`/`X`, `SIG_*` y las 3 plantillas; las filas archivadas vuelven a `SolicitudIngresoGrupo`; la oferta vuelve a 21 columnas; las notificaciones canceladas recuperan su estado previo; no quedan `zz_archivo_*`) → `up` de nuevo. Se ejecuta en una **base clonada** (`RESTORE` del backup COPY_ONLY de `ESTADO.md` con otro nombre), nunca sobre `gestionasistenciadb` | **Nuevo** `scripts/tests/test_migracion_13_up_down.ps1` (`TEST_PASS:CULM001A_T10_UP_DOWN_UP`) |
| T-11 | Notificaciones pendientes canceladas | Antes del `up` (en la base clonada de T-10), se siembran 3 filas `NotificacionSaliente`: una `PENDIENTE` de `SOLICITUD_INGRESO_REGISTRADA`, una `FALLIDA_REINTENTABLE` de `_RESUELTA` y una `ENTREGADA` de `_RETIRADA`, más una `PENDIENTE` de `RETIRO_ESTUDIANTE_GRUPO`. Tras el `up`: las 2 primeras quedan en `FALLIDA_DEFINITIVA` con `codigoError = 'TIPO_NOTIFICACION_RETIRADO'` y en `zz_archivo_NotificacionSolicitudIngreso` con su estado anterior; la `ENTREGADA` y la de `RETIRO_ESTUDIANTE_GRUPO` no cambian. `usp_reservar_notificaciones_salientes` ya no devuelve ninguna de los 3 tipos | `test_migracion_13_up_down.ps1` (`CULM001A_T11_OUTBOX_CANCELADO`) |
| T-12 | `@@TRANCOUNT = 0` y el nivel del llamador intacto | En T-03..T-09: `IF @@TRANCOUNT <> 1 THROW` dentro de la transacción del test, antes del `ROLLBACK`, y `IF @@TRANCOUNT <> 0 THROW` al final de cada archivo. Además, `usp_internal_reactivar_matricula_retirada` se llama directamente con `@@TRANCOUNT = 0` (sale en 0) y con `@@TRANCOUNT = 1` (sale en 1), tanto en un caso feliz como en uno de cupo lleno | todos (`CULM001A_T12_TRANCOUNT`) |
| T-13 | Esquema desplegado = `schema/` | Para U-7..U-10, `OBJECT_DEFINITION` del SP desplegado coincide con el archivo (comparación de hash en `test_migracion_13_up_down.ps1`, quitando los `GO`) | `test_migracion_13_up_down.ps1` |

Cifra: `test_solicitud_ingreso_grupo.sql` (S-01..S-12) desaparece con la HU, porque prueba un flujo descartado. Ninguna otra prueba de BD se quita. CLOSURE informa el total de `TEST_PASS` antes y después.

### 2.7 Seeds y grants después del cambio

- Seeds que se borran: `22_estados_solicitud_ingreso_grupo.sql` y `23_mensajes_solicitud_ingreso_grupo.sql`. Seeds que se editan: `04_mensaje.sql` y `26_plantillas_notificacion.sql`. Seed nuevo: `33_parametro_reactivacion_matricula.sql`.
- Grants que se borran: `rol_asistencias_runtime_hu053_hu055.sql`. Grants sin cambio: `usp_consultar_oferta_grupos_estudiante` y `usp_registrar_estudiante_en_grupo` (`CREATE OR ALTER` los conserva). `usp_internal_reactivar_matricula_retirada` y las dos `zz_archivo_*` quedan **sin** permiso para el runtime.
- `test_runtime_grants_backend_inventory.sql` no menciona estos SP (verificado): no cambia.

### 2.8 Docs de BD

- Se borra `docs/work-items/HU053-HU054-HU055-solicitudes-ingreso-grupo/`.
- Se editan fichas y conteos: `docs/arquitectura/DOCUMENTACION_PROCEDIMIENTOS_PUBLICOS.md`, `docs/arquitectura/especificacion_sp_endpoints.md`, `docs/arquitectura/transaccion-procedimiento.md`, `docs/catalogos/catalogo-mensajes.md` (15 filas `SIG_` y `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`) y `docs/work-items/HU008-oferta-grupos-estudiante/PLAN.md`. Se añade la ficha de `usp_internal_reactivar_matricula_retirada`.
- Se anota "retirado en CULM-001 A" en los históricos: `docs/work-items/{HU051-retirar-estudiante-grupo,INT-HU-01-reactivar-matricula-retirada,CERT-F3-CORRECCIONES,BD-eliminar-codigo-sin-uso}/PLAN.md`.

---

## 3. Backend (`GestioAsistenciaBackend/`)

### 3.1 Endpoints antes y después

| Método y ruta | Clase actual | Antes | Después |
| :--- | :--- | :--- | :--- |
| `POST /api/v1/estudiante/solicitudes-matricula` | `EstudianteSolicitudIngresoController` | 201 (HU053) | **404** (sin handler) |
| `GET /api/v1/estudiante/solicitudes-matricula` | idem | 200 | **404** |
| `POST /api/v1/estudiante/solicitudes-matricula/{id}/retiro` | idem | 200 (HU055) | **404** |
| `GET /api/v1/docente/grupos/{grupoId}/solicitudes-ingreso` | `DocenteSolicitudIngresoController` | 200 | **404** |
| `PATCH /api/v1/docente/solicitudes-ingreso/{id}` | idem | 200 | **404** |
| `GET /api/v1/coordinador/solicitudes-matricula` | `CoordinadorPortalController:165-166` | 501 | **404** |
| `PATCH /api/v1/coordinador/solicitudes-matricula/{id}` | `CoordinadorPortalController:167-168` | 501 | **404** |
| `POST /api/v1/coordinador/grupos/{grupoId}/estudiantes` | `CoordinadorPortalController:169-170` | 501 | **404** |
| `DELETE /api/v1/coordinador/grupos/{grupoId}/estudiantes/{estudianteId}` | `CoordinadorPortalController:171-172` | 501 | **404** |
| `DELETE /api/v1/grupos/{grupoId}/estudiantes/{estudianteId}` | `GrupoController:128-136` | 501 (COORDINADOR/ADMINISTRADOR) | **404** |
| `POST /api/v1/grupos/{grupoId}/estudiantes` | `GrupoController:113-126` | DOCENTE y COORDINADOR pasan el filtro | **Solo DOCENTE**. COORDINADOR y ADMINISTRADOR → **403** en el filtro HTTP; DOCENTE no titular → 403 (`SEC_002`, vía `DbFailureClassifier`); retirado → 201 (DEC-009) |
| `GET /api/v1/estudiante/oferta-academica` | `EstudianteOfertaAcademicaController` | 200, `GrupoOfertaDTO` con 21 campos | 200, `GrupoOfertaDTO` con 19 campos (3.4) |

`CoordinadorPortalController.unavailable()` se conserva: lo sigue usando `toggleEstadoPeriodoAcademico` (línea 158).

### 3.2 Archivos de producción que se borran (52)

- `B/application/features/docente/consultarsolicitudesingreso/**` (10): `ConsultarSolicitudesIngresoDocenteInputPort`, `ConsultarSolicitudesIngresoDocenteDTO`, `SolicitudesIngresoDocentePaginaDTO`, `SolicitudIngresoDocenteDTO`, `ConsultarSolicitudesIngresoDocenteInteractor`, `ConsultarSolicitudesIngresoDocenteUseCase`, `ConsultarSolicitudesIngresoDocenteDomain`, `SolicitudesIngresoDocentePaginaDomain`, `SolicitudIngresoDocenteDomain`, `ConsultarSolicitudesIngresoDocenteUseCaseImpl`.
- `B/application/features/docente/resolversolicitudingreso/**` (7): `ResolverSolicitudIngresoDTO`, `ResultadoSolicitudIngresoDTO`, `ResolverSolicitudIngresoInteractor`, `ResolverSolicitudIngresoInputPort`, `ResolverSolicitudIngresoDomain`, `ResolverSolicitudIngresoUseCaseImpl`, `ResolverSolicitudIngresoUseCase`.
- `B/application/features/estudiante/consultarsolicitudesingreso/**` (10, las mismas piezas con sufijo `Estudiante`).
- `B/application/features/estudiante/retirarsolicitudingreso/**` (5): `RetirarSolicitudIngresoDTO`, `RetirarSolicitudIngresoInteractor`, `RetirarSolicitudIngresoInputPort`, `RetirarSolicitudIngresoUseCaseImpl`, `RetirarSolicitudIngresoUseCase`.
- `B/application/features/estudiante/solicitaringresogrupo/**` (5): `SolicitarIngresoGrupoDTO`, `SolicitarIngresoGrupoInteractor`, `SolicitarIngresoGrupoInputPort`, `SolicitarIngresoGrupoUseCaseImpl`, `SolicitarIngresoGrupoUseCase`.
- `B/application/secondaryports/academic/SolicitudIngresoGrupoPort.java`.
- `B/application/secondaryports/academic/projection/{DestinatarioSolicitudIngresoProjection,SolicitudIngresoDocenteProjection,SolicitudIngresoEstudianteProjection}.java`.
- `B/infrastructure/adapter/primary/controller/docente/{DocenteSolicitudIngresoController.java,request/ResolverSolicitudIngresoRequest.java,response/SolicitudIngresoDocenteResponse.java}`.
- `B/infrastructure/adapter/primary/controller/estudiante/{EstudianteSolicitudIngresoController.java,request/SolicitarIngresoGrupoRequest.java,response/SolicitudIngresoCreadaResponse.java,response/SolicitudIngresoEstudianteResponse.java}`.
- `B/infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/SolicitudIngresoGrupoJpaRepository.java` (es un `@Repository` nativo; no hay entidad JPA ni mapper propios).
- `GestioAsistenciaBackend/src/main/resources/notification/templates/{SOLICITUD_INGRESO_REGISTRADA,SOLICITUD_INGRESO_RESUELTA,SOLICITUD_INGRESO_RETIRADA}.es.properties`.

No hay eventos SSE de solicitudes, ni entidades JPA o mappers propios.

### 3.3 Archivos de producción que se editan

| Archivo | Cambio |
| :--- | :--- |
| `B/infrastructure/config/wiring/EstudianteWiringConfiguration.java` | Quitar los imports (líneas 35 y 42-53) y los beans de 137-163 (solicitar, retirar y consultar, con sus interactors) |
| `B/infrastructure/config/wiring/DocenteWiringConfiguration.java` | Quitar los imports (41-49) y los beans de 179-195 (resolver y consultar) |
| `B/infrastructure/adapter/primary/controller/coordinador/CoordinadorPortalController.java` | Quitar los 4 métodos de las líneas 165-172 (`DeleteMapping` se sigue usando en 105 y 136) |
| `B/infrastructure/adapter/primary/controller/grupo/GrupoController.java` | Quitar `retirarEstudiante` (128-136) y los imports sin uso (`DeleteMapping`, `FeatureUnavailableException` si quedan libres) |
| `B/infrastructure/config/security/SecurityConfig.java` | Líneas 181-186: la regla `POST /api/v1/grupos/*/estudiantes` pasa de `.hasAnyRole(ROLE_DOCENTE, ROLE_COORDINADOR)` a `.hasRole(ROLE_DOCENTE)`, con el comentario "F-COO-004 (CULM-001 A): matricula solo del DOCENTE titular (la DB valida titularidad, SEC_002)". Las demás reglas no cambian; `/api/v1/estudiante/**`, `/docente/**` y `/coordinador/**` siguen como comodines de rol |
| `B/application/secondaryports/notification/Notificacion.java` | Quitar `TIPO_SOLICITUD_INGRESO_REGISTRADA` (23), `_RESUELTA` (25) y `_RETIRADA` (27) |
| `B/infrastructure/adapter/secondary/notification/template/PlantillaPorDefectoCatalogo.java` | Quitar los 3 tipos de `TIPOS_CONOCIDOS` (24-26) |
| `B/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` | Quitar el bloque `SIG_001..SIG_013` (110-115). `SEC_001`, `SEC_002`, `ERR_CUPO_SUPERADO` y `ERR_MATRICULA_DUPLICADA` siguen mapeados como hoy |
| `B/application/secondaryports/academic/projection/GrupoOfertaEstudianteProjection.java` | Quitar `idSolicitudAbierta` y `codigoEstadoSolicitud`; Javadoc sin HU053-HU055 |
| `B/infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/OfertaGruposEstudianteJpaRepository.java` | Línea 63: total en `f[18]` (antes `f[20]`). Líneas 71-74: `codigoComponente` en `f[17]` (antes `f[19]`); se quitan `f[17]` UUID y `f[18]` texto. Se añade la constante `static final int COLUMNAS_OFERTA = 19` y, si la fila no tiene esa longitud, se lanza la excepción de persistencia del patrón (`JpaQueryExecutor`). El desfase entre BD y backend falla así de forma visible y no desordena campos en silencio |
| `B/application/features/estudiante/consultarofertagrupos/usecase/domain/GrupoOfertaDomain.java` | Quitar los 2 campos y el Javadoc de `estadoSolicitud` |
| `B/application/features/estudiante/consultarofertagrupos/primaryports/dto/GrupoOfertaDTO.java` | Quitar `idSolicitudAbierta` y `estadoSolicitud` (cuerpo HTTP, 3.4) |
| `B/application/features/estudiante/consultarofertagrupos/primaryports/interactor/ConsultarOfertaGruposInteractor.java` | Ajustar el mapeo (línea 29) |
| `B/application/features/estudiante/consultarofertagrupos/usecase/impl/ConsultarOfertaGruposUseCaseImpl.java` | Quitar `ESTADO_SOLICITUD` (28) y su uso en `toDomain` (66-71); el Javadoc (línea ~20) ya no menciona "solicitud de ingreso abierta" |
| `GestioAsistenciaBackend/src/main/resources/application.yml` | Quitar `"[ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA]": ERR021` (178). `ERR021` queda libre; no se renumera |
| `GestioAsistenciaBackend/infra/security-baseline/access-catalog.json` | Ver 3.5 |

### 3.4 DTO de la oferta (HU008) después

`GrupoOfertaDTO` (cuerpo de cada elemento de `ApiListResponse` en `GET /api/v1/estudiante/oferta-academica`), 19 campos en este orden:

```text
UUID idGrupo, Integer codigoGrupo, String nombreGrupo, UUID idAsignatura, String codigoAsignatura,
String nombreAsignatura, String nombreDocente, UUID idPeriodoAcademico, String nombrePeriodoAcademico,
LocalDate fechaInicioPeriodo, LocalDate fechaFinPeriodo, String estadoPeriodo, String horario,
int capacidadMaxima, int estudiantesActivos, int cuposDisponibles, boolean matriculado,
String tipoAsignatura, boolean transversal
```

Se eliminan `idSolicitudAbierta` (UUID|null) y `estadoSolicitud` (`PENDIENTE`|`EN_ESPERA`|null). `GrupoOfertaEstudianteProjection` queda con 18 campos (hasta `matriculado`, más `codigoComponente`). Es un cambio incompatible para consumidores externos del JSON, pero el único consumidor es el frontend (4.3); se declara `BREAKING CHANGE` en el commit.

### 3.5 `access-catalog.json` y roles por endpoint después

Se quitan 10 filas: 81 (`POST /coordinador/grupos/{grupoId}/estudiantes`), 82 (`DELETE /coordinador/grupos/{grupoId}/estudiantes/{estudianteId}`), 98-99 (`GET`/`PATCH /coordinador/solicitudes-matricula`), 124 (`GET /docente/grupos/{grupoId}/solicitudes-ingreso`), 131 (`PATCH /docente/solicitudes-ingreso/{id}`), 146-148 (`GET`/`POST /estudiante/solicitudes-matricula` y `POST .../{id}/retiro`) y 159 (`DELETE /grupos/{grupoId}/estudiantes/{estudianteId}`).

Se edita la fila 155:

```json
{"method": "POST", "path": "/api/v1/grupos/{grupoId}/estudiantes", "roles": ["DOCENTE"], "access": "ROLES", "ownership": "Solo el DOCENTE titular del grupo (SP: perfil DOCENTE y titularidad GRUPO, SEC_002). F-COO-004: el coordinador no matricula."}
```

Roles resultantes de las rutas de matrícula y retiro:

| Ruta | Roles en `SecurityConfig` y catálogo |
| :--- | :--- |
| `POST /api/v1/grupos/{grupoId}/estudiantes` | DOCENTE |
| `GET /api/v1/grupos/{grupoId}/estudiantes` | DOCENTE, COORDINADOR, ADMINISTRADOR (sin cambio, WORM) |
| `POST /api/v1/docente/grupos/{grupoId}/estudiantes/{estudianteId}/retiro` | DOCENTE (sin cambio) |
| `POST /api/v1/grupos/{grupoId}/estudiantes/{estudianteId}/reenviar-verificacion` | DOCENTE, COORDINADOR (sin cambio; no matricula) |
| `POST/DELETE /api/v1/grupos/{grupoId}/matricula-qr`, `POST .../rotacion` | DOCENTE (sin cambio) |
| `POST /api/v1/estudiante/matricular-grupo` | ESTUDIANTE (sin cambio) |
| `GET /api/v1/estudiante/oferta-academica` | ESTUDIANTE (sin cambio) |

PDP del laboratorio: después de editar el catálogo se ejecuta `python -m unittest test_catalog_tools test_e2e_safety` en `infra/security-baseline/scripts`. El `provision_asistencias.py --prune` de las 10 filas **queda pendiente de aprobación del responsable**, igual que en RETIRO-SEDES; se anota en `PRS.md`.

### 3.6 Pruebas backend

**Se borran (9)**, porque la HU se descarta: `BT/application/features/docente/consultarsolicitudesingreso/usecase/impl/ConsultarSolicitudesIngresoDocenteUseCaseImplTest.java`, `BT/application/features/docente/resolversolicitudingreso/usecase/impl/ResolverSolicitudIngresoUseCaseImplTest.java`, `BT/application/features/estudiante/consultarsolicitudesingreso/usecase/impl/ConsultarSolicitudesIngresoEstudianteUseCaseImplTest.java`, `BT/application/features/estudiante/retirarsolicitudingreso/usecase/impl/RetirarSolicitudIngresoUseCaseImplTest.java`, `BT/application/features/estudiante/solicitaringresogrupo/usecase/impl/SolicitarIngresoGrupoUseCaseImplTest.java`, `BT/infrastructure/adapter/primary/controller/docente/DocenteSolicitudIngresoControllerTest.java`, `BT/infrastructure/adapter/primary/controller/estudiante/EstudianteSolicitudIngresoControllerTest.java`, `BT/infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/SolicitudIngresoGrupoJpaRepositoryTest.java`, `BT/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifierSolicitudIngresoTest.java`.

**Se editan, sin relajar aserciones:**

| Archivo | Cambio |
| :--- | :--- |
| `BT/application/secondaryports/notification/CasosDeUsoEmisoresNotif002aDatosTest.java` | Quitar los 3 casos de solicitud (líneas ~78-195, incluido `BE_U01_U02_solicitud_ingreso_retirada`); se conservan los de retiro HU051 |
| `BT/infrastructure/adapter/primary/controller/coordinador/CoordinadorPortalControllerTest.java` | Líneas 172-174: la lista de 501 queda solo con `toggleEstadoPeriodoAcademico`; se añade el caso B-RED-03 |
| `BT/infrastructure/adapter/primary/controller/grupo/GrupoControllerWriteEndpointsTest.java` | El caso `delete(".../estudiantes/{estudianteId}")` (línea 289), que esperaba 501, se sustituye por B-RED-03 (sin ruta) |
| `BT/infrastructure/adapter/primary/security/RbacSecurityFilterChainTest.java` | `matricular_estudiante_coordinador_es_permitido_por_security_filter_chain` (420-425) pasa a `matricular_estudiante_coordinador_recibe_403` con `isForbidden()`. Es un **cambio de expectativa por cambio formal de regla (F-COO-004)**, no un relajamiento: la aserción es más estricta. DOCENTE 200 y ADMINISTRADOR 403 quedan igual. Comentario de 410-411 actualizado |
| `BT/infrastructure/adapter/secondary/notification/template/PlantillaRendererTest.java`, `PlantillaNotificacionJpaRepositoryTest.java`, `channel/smtp/SmtpNotificacionChannelSenderTest.java`, `channel/smtp/NotificacionSmtpGreenMailIT.java` | Usan `SOLICITUD_INGRESO_*` como dato de ejemplo (6, 3, 2 y 5 usos). Pasan a `RETIRO_ESTUDIANTE_GRUPO` con marcadores que existan en esa plantilla, y se mantienen las mismas aserciones de renderizado |
| `BT/infrastructure/adapter/secondary/persistence/sqlserver/jpa/JpaRepositoryBeanUniquenessTest.java` | `EXPECTED_REPOSITORIES` de 56 a **55**; el comentario anota "CULM-001 A: − SolicitudIngresoGrupoJpaRepository" |
| `BT/application/features/estudiante/consultarofertagrupos/ConsultarOfertaGruposUseCaseImplTest.java`, `BT/infrastructure/adapter/primary/controller/estudiante/EstudianteOfertaAcademicaControllerTest.java` | Quitar las aserciones de los 2 campos y construir las proyecciones o DTO con 18 o 19 campos |
| `BT/infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/OfertaGruposEstudianteJpaRepositoryTest.java` | Fila simulada (línea 58) de 19 posiciones; OR01 y OR07 sin `idSolicitudAbierta` (93, 164); OR06 con columnas nulas en 19 posiciones; se añade B-RED-04 |
| `GestioAsistenciaBackend/src/test/resources/messageucolab/catalogo-mensajes-usuario.psv` | Quitar la línea 75 (`ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`) y las 124-138 (`SIG_001..SIG_015`) |

**Pruebas RED nuevas:**

| ID | Tipo | Archivo | Aserción |
| :--- | :--- | :--- | :--- |
| B-RED-01 | ArchUnit | **Nuevo** `BT/architecture/SolicitudesIngresoRetiradasTest.java` | Ninguna clase importada de `co.edu.uco.asistenciasuco` tiene nombre simple que coincida con `.*(SolicitudIngreso|SolicitarIngreso|SolicitudesIngreso).*`, ni vive en un paquete `..consultarsolicitudesingreso..`, `..resolversolicitudingreso..`, `..retirarsolicitudingreso..` o `..solicitaringresogrupo..`. `Notificacion` no declara campos `TIPO_SOLICITUD_INGRESO_*`. El patrón **no** cubre `SolicitudRevision*` (reclamos); el test incluye una aserción positiva de que `SolicitudRevisionEstudianteJpaRepository` sigue existiendo, para no dar un falso verde |
| B-RED-02 | Recurso | idem | `getResource("notification/templates/SOLICITUD_INGRESO_*.es.properties")` es nulo para los 3 tipos |
| B-RED-03 | Rutas retiradas (inventario) | `CoordinadorPortalControllerTest` y `GrupoControllerTest` | Por reflexión, como en `AdminPortalControllerTest.sedes_y_espacios_fisicos_retirados_no_tienen_ruta` (líneas 296-316): `CoordinadorPortalController` no tiene rutas que empiecen por `/solicitudes-matricula` ni `/grupos/{grupoId}/estudiantes`, y `GrupoController` no tiene `@DeleteMapping` |
| B-RED-04 | Contrato JPA de la oferta | `OfertaGruposEstudianteJpaRepositoryTest` | `OR08_fila_de_19_columnas_mapea_componente_en_17_y_total_en_18`: con una fila de 19 posiciones de valores distinguibles, `codigoComponente = "ESP"` sale de `f[17]` y `total` de `f[18]`. `OR09_fila_con_longitud_distinta_falla`: una fila de 21 posiciones (forma vieja) lanza la excepción de persistencia y no devuelve datos desordenados. Junto con T-02 en BD, fija el contrato posicional a los dos lados |
| B-RED-05 | 404 de rutas retiradas (HTTP) | `RbacSecurityFilterChainTest` (probe MVC con `GlobalExceptionHandler`) | Con un token del rol que antes tenía acceso, cada una de las 10 rutas de 3.1 responde **404** con `ApiErrorResponse` (handler `NoResourceFoundException`, `GlobalExceptionHandler.java:181`). Ninguna responde 501 ni 200 |
| B-RED-06 | 403 del coordinador | `RbacSecurityFilterChainTest` | `POST /api/v1/grupos/{grupoId}/estudiantes` con COORDINADOR → 403 (ver la fila de edición) |
| B-RED-07 | Consistencia del catálogo | `AccessCatalogConsistencyTest` (sin editar) | Pasa en verde solo si las 10 filas quitadas coinciden con los 10 handlers retirados y si la fila 155 (`["DOCENTE"]`) coincide con `SecurityConfig`. Es la compuerta cruzada de 3.5 |
| B-RED-08 | DTO de la oferta | `EstudianteOfertaAcademicaControllerTest` | La respuesta JSON de `GET /api/v1/estudiante/oferta-academica` no contiene las claves `idSolicitudAbierta` ni `estadoSolicitud` (`jsonPath("$.datos[0].idSolicitudAbierta").doesNotExist()`) y sí `tipoAsignatura` y `transversal` |

Compuerta: `.\mvnw.cmd verify` con `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\jtmp` (línea base: 3309 pruebas, 0 fallos). JaCoCo LINE ≥ 80 % y BRANCH ≥ 70 %, **sin tocar umbrales**. CLOSURE informa la cifra nueva.

### 3.7 Docs de backend

- Se borra `docs/work-items/HU053-HU054-HU055-solicitudes-ingreso-grupo/`.
- Se editan: `docs/contracts/HTTP_AS_IS_MATRIX.md` (líneas 94-98, 173-174 y 200-205; filas de `POST /grupos/{grupoId}/estudiantes` con el rol nuevo; filas de los stubs del coordinador y del `DELETE /grupos/...`), `docs/baseline/LINEA_BASE.md:325`, `docs/work-items/README.md:65`, `docs/baseline/TECHNICAL_DEBT.md:948` y `docs/work-items/HU008-oferta-grupos-estudiante/{PLAN,CONTRACT}.md`.
- Históricos (solo anotación): `NOTIF-002A-plantillas-correo/*`, `HU051-retirar-estudiante-grupo/CLOSURE.md`, `SEC-BASELINE-018/019`. Los scripts de `docs/work-items/INTEGRACION-DEVELOP-20261027/live-db/*` **no se tocan**: son una integración ya ejecutada.

---

## 4. Frontend (`GestioAsistenciaFrontend/`)

### 4.1 Archivos que se borran (7)

- `F/features/student/student-enrollment-requests/student-enrollment-requests.component.ts` y `.spec.ts`.
- `F/features/teacher/teacher-grupos/components/teacher-grupo-solicitudes.component.ts` y `.spec.ts`.
- `F/core/services/solicitud-ingreso.service.ts` y `.spec.ts`.
- `F/features/student/student-courses/components/student-course-enroll-form.component.ts` (huérfano y sin spec).

### 4.2 Archivos que se editan

| Archivo | Cambio |
| :--- | :--- |
| `F/app.routes.ts` | Quitar la ruta `estudiante/solicitudes` (525-532); `estudiante/oferta` se conserva. Sin redirección propia: `/app/estudiante/solicitudes` cae en el comodín `'**' → 'login'` (545-547) |
| `F/layouts/dashboard-layout/dashboard-layout.component.ts` | Quitar la entrada "Solicitudes de Ingreso" (478-483) |
| `F/features/student/student-group-offer/student-group-offer.component.ts` | Quitar el import y la inyección de `SolicitudIngresoService` (7, 122), la señal `enviando` (134-135), el método `solicitar(g)` (~180-195), el badge de solicitud (91-92) y el botón `data-accion="solicitar-ingreso"` (93-104). En su lugar, para `!g.matriculado`, un texto fijo de presentación `data-testid="oferta-como-matricularse"`: "Para matricularte, usa el QR o PIN que proyecta el docente en clase o pídele la matrícula manual". No hay llamada HTTP. Se conservan la tarjeta, los cupos, el badge Vigente/Próximo, "Ya estás matriculado", la búsqueda con debounce y la paginación. El Javadoc (línea 19) ya no menciona HU053. `ChangeDetectionStrategy.OnPush` y signals, sin cambio |
| `F/core/services/oferta-academica.service.ts` (+`.spec.ts`) | `GrupoOferta` sin `idSolicitudAbierta` ni `estadoSolicitud` (líneas 27-28); queda con los 19 campos de 3.4 |
| `F/features/teacher/teacher-grupos/components/teacher-grupo-hub.component.ts` | Quitar el import y el registro (9, 24), la pestaña `data-tab="solicitudes"` (154-162), el bloque `<app-teacher-grupo-solicitudes>` (227-228), `'SOLICITUDES'` del `model<...>` (263) y el `output` `padronCambiado` (274-275), que solo emitía la bandeja |
| `F/features/teacher/teacher-grupos/teacher-grupos.component.ts` | Quitar `'SOLICITUDES'` de la unión (192), el binding `(padronCambiado)=...` (104) y la mención a HU053-HU055 del Javadoc (270-271) |
| `F/features/attendance/attendance-control/components/group-sessions-overview.component.ts` | Botón `data-testid="padron-solicitudes"` (194-202): texto "Padrón", `title` "Retirar estudiantes del padrón del grupo" y `data-testid="padron"`. Javadoc 333 sin "solicitudes de ingreso" |
| `F/features/attendance/attendance-control/attendance-control.component.ts` | `irAPadronYSolicitudes` pasa a `irAPadron` (137, 316). `MENSAJE_MATRICULA_DUPLICADA_DOCENTE` (64-65) pasa a "El estudiante ya tiene una matrícula activa en este grupo." (A-C5). Comentario 886-887 actualizado (DEC-009: el retirado se vuelve a matricular por esta misma vía) |
| `F/features/attendance/attendance-control/attendance-control.component.spec.ts` | El caso de la línea 331 pasa a "el 409 ERR_MATRICULA_DUPLICADA indica matrícula activa": `toBe(MENSAJE_MATRICULA_DUPLICADA_DOCENTE)` y `not.toContain('solicitud')`, en lugar de `toContain('solicitud de ingreso')` (363). Es un cambio de expectativa por DEC-009. El caso de la línea 547 se renombra a "Padrón" y llama a `irAPadron` |
| `F/features/student/student-courses/student-courses.component.ts` | Quitar `'SOLICITAR_MATRICULA'` (36), `cursosDisponibles` (147), `abrirSolicitudMatricula` y `enviarSolicitudMatricula` (237-275, con las identidades inventadas de F-EST-016), la inyección de `CoordinatorManagementService` si queda sin uso, y el bloque de plantilla de `SOLICITAR_MATRICULA` |
| `F/features/student/student-courses/components/student-courses-list.component.ts` | Quitar el output sin uso `openEnrollmentRequest` (211) y su botón, si lo hay |
| `F/features/student/student-courses/student-courses.component.spec.ts` | Quitar el spy `crearSolicitudMatricula` (279) y su provider |
| `F/core/services/coordinator-management.service.ts` (+`.spec.ts`) | Quitar `SolicitudMatriculaItem` del import (22), la señal `solicitudesMatricula` (136-137), `getSolicitudesMatricula`, `crearSolicitudMatricula`, `resolverSolicitudMatricula` (536-570) y, por F-COO-004, `matricularEstudianteGrupo` y `retirarEstudianteGrupo` (496-533), que no tienen llamadores (grep). En el spec, quitar los casos de 539-558, 561-600 y 633-670 |
| `F/features/coordinator/coordinator-students/coordinator-students.component.ts` (+`.spec.ts`) | `PestanaModulo` (19) queda en `'DIRECTORIO'`: se quitan `'MATRICULA_GRUPO'` y `'SOLICITUDES'`, que no se usan en la plantilla. Spec: líneas 36 y 46 |
| `F/core/models/role-management.model.ts` | Quitar `SolicitudMatriculaItem` (298-313) |
| `F/core/mocks/role-management.mock.ts` | Quitar `MOCK_SOLICITUDES_MATRICULA` (11, 902) |
| `F/core/mocks/mock-data-store.ts` | Quitar las referencias de las líneas 11, 34 y 61 |
| `F/core/mocks/mock-notificaciones.ts` | Quitar las 3 plantillas `SOLICITUD_INGRESO_*` (41-65) |
| `F/core/interceptors/mock-backend.interceptor.ts` | Quitar `SolicitudIngresoMock` (14, 18-38), `SOL-MAT-*` (234-248), los campos de solicitud de la oferta mock (559-577), los 5 endpoints mock (580-625) y 756-757 |
| `F/core/interceptors/mock-backend.interceptor.spec.ts` | Quitar MK-01 y el caso de oferta con solicitud (289-346) |
| `F/features/admin/admin-email-management/admin-email-management.component.ts` (+spec si cuenta entradas) | Quitar los 3 tipos del mapa (56-70) |
| `F/features/admin/admin-estados/admin-estados.component.ts` | Solo texto (18, 35-38, 56): "Estados de reclamos de asistencia (P, A, R)". Tras A-C3, el panel ya no recibe E ni X |

Sin cambios: `F/core/realtime/**`, guards, `environment*.ts`, `F/core/golden-path-real-mode.spec.ts`, `F/core/api/models/estudiante-portal-api-dto.model.ts` (su `estadoSolicitud` es de reclamos), y todas las pantallas de reclamos (`teacher-claims`, `teacher-grupo-reclamos`, `student-claims`, `overview-*`).

### 4.3 Modelo de oferta después

```ts
export interface GrupoOferta {
  idGrupo: string; codigoGrupo: number | null; nombreGrupo: string;
  idAsignatura: string; codigoAsignatura: string; nombreAsignatura: string; nombreDocente: string;
  idPeriodoAcademico: string; nombrePeriodoAcademico: string; fechaInicioPeriodo: string; fechaFinPeriodo: string;
  estadoPeriodo: 'VIGENTE' | 'PROXIMO'; horario: string | null;
  capacidadMaxima: number; estudiantesActivos: number; cuposDisponibles: number; matriculado: boolean;
  tipoAsignatura: 'ESPECIFICA' | 'BASICA' | 'INSTITUCIONAL' | null; transversal: boolean;
}
```

### 4.4 Specs RED

| ID | Spec | Aserción |
| :--- | :--- | :--- |
| F-RED-01 | `F/features/student/student-group-offer/student-group-offer.component.spec.ts` | Reemplaza OF-02, OF-03 y OF-04 (líneas 79-120; OF-03 y OF-04 prueban una acción que desaparece). **OF-02b**: con un grupo no matriculado y con cupo, el DOM no contiene `[data-accion="solicitar-ingreso"]` ni el texto "Solicitar ingreso", y sí `[data-testid="oferta-como-matricularse"]`. **OF-03b**: con un grupo matriculado se ve "Ya estás matriculado" y no se ve el texto informativo. **OF-04b**: el componente no inyecta `SolicitudIngresoService` (TestBed sin ese provider) y no hace ninguna petición HTTP fuera de `GET /estudiante/oferta-academica` (`HttpTestingController.verify()`). OF-01 y OF-05..OF-07 se conservan sin cambios |
| F-RED-02 | `F/app.routes.spec.ts` | Nuevo `it('las rutas de solicitudes de ingreso fueron retiradas')`: ninguna ruta hija de `app` tiene `path` `estudiante/solicitudes`, y navegar con `Router` a `/app/estudiante/solicitudes` termina en `/login` (comodín). El caso existente "resuelve ... todas las rutas" (línea 23) sigue verde sin el componente borrado |
| F-RED-03 | `F/layouts/dashboard-layout/dashboard-layout.component.spec.ts` | En `filteredNavItems` (línea 72), para ESTUDIANTE ninguna entrada tiene `route` `/app/estudiante/solicitudes` ni `label` que contenga "Solicitudes de Ingreso"; "Oferta de Grupos" sigue presente |
| F-RED-04 | `F/core/services/coordinator-management.service.spec.ts` y `F/core/services/oferta-academica.service.spec.ts` | `expect((service as any).getSolicitudesMatricula).toBeUndefined()`, y lo mismo para `crearSolicitudMatricula`, `resolverSolicitudMatricula`, `matricularEstudianteGrupo` y `retirarEstudianteGrupo`. La oferta mapeada no tiene las claves `idSolicitudAbierta` ni `estadoSolicitud` |
| F-RED-05 | `F/core/interceptors/mock-backend.interceptor.spec.ts` | Con mocks activos, `GET /estudiante/solicitudes-matricula`, `GET /docente/grupos/{id}/solicitudes-ingreso` y `GET /coordinador/solicitudes-matricula` **no** los resuelve el mock (pasan al siguiente handler, o 404 según el patrón del interceptor), y la oferta mock no trae los campos de solicitud |
| F-RED-06 | `F/features/teacher/teacher-grupos/components/teacher-grupo-hub.component.spec.ts` (existe; caso nuevo) | El hub no renderiza `[data-tab="solicitudes"]` ni `app-teacher-grupo-solicitudes`, y las pestañas visibles son las de hoy (sesiones, horarios, estudiantes, reclamos y "Sábana de Asistencia") sin la de solicitudes. Quitar `'SOLICITUDES'` de la unión hace que cualquier uso posterior falle al compilar |
| F-RED-07 | `F/features/attendance/attendance-control/attendance-control.component.spec.ts` | El 409 `ERR_MATRICULA_DUPLICADA` muestra `MENSAJE_MATRICULA_DUPLICADA_DOCENTE`, que no contiene "solicitud"; el botón del overview es "Padrón" (`data-testid="padron"`) |
| F-RED-08 | Compuerta de fuente: **nuevo** `GestioAsistenciaFrontend/scripts/check-retiro-solicitudes.mjs`, ejecutado por un script `check:retiro-solicitudes` que se añade a `verify` en `package.json` (línea 14) antes del build. Karma no lee la fuente y el repo no usa `import.meta.glob` en specs | Ningún archivo de `src/` contiene `solicitud-ingreso.service`, `SolicitudIngresoService`, `solicitudes-matricula`, `solicitudes-ingreso`, `SolicitudMatriculaItem`, `SOLICITUD_INGRESO_`, `idSolicitudAbierta` ni `solicitar-ingreso`. Si encuentra alguno, termina con código distinto de 0 e indica el archivo y la línea. Antes del GREEN falla (RED) |

Compuerta: `npm run verify` (línea base: 1630/1630 specs; realtime LINE 95.06 % y BRANCH 84.52 %; build de producción OK), con 0 errores de `npm run build`. La cifra baja por las specs borradas; CLOSURE la informa.

### 4.5 Docs de frontend

Se borra `docs/work-items/HU053-HU054-HU055-solicitudes-ingreso-grupo/`. Se editan `docs/MAPA_COMPONENTES_FRONTEND.md` (57, 88-89), `docs/frontend-backend-contract.md` (93-94, 101) y `docs/work-items/HU008-oferta-grupos-estudiante/{PLAN,TEST_PLAN}.md`. Histórico: `docs/work-items/CERT-F3-CORRECCIONES/PLAN.md`, solo una anotación.

---

## 5. Docs e Infra (`AsistenciasUCO-Infra/`)

### 5.1 `docs/user-stories/HU-CATALOG.md`

| Fila | Después |
| :--- | :--- |
| HU008 (línea 59) | Columna de UI: `/app/estudiante/oferta` (consulta de oferta y cupos; la matrícula es por QR/PIN o manual del docente, CULM-001 A). Estado `[CERTIFICADA]` (sin cambio de estado; se recertifica en Fase 3) |
| HU026 (77) | `~~Solicitud de inscripción o matrícula por QR~~ \| Descartada (decisión del responsable, 2026-11-06): la matrícula es por QR/PIN del docente (HU176B) o manual (HU050) \| Se retiró \`POST /api/v1/estudiante/solicitudes-matricula\` \| Sin acción en la UI \| \`[DESCARTADA]\`` |
| HU053 (113) | `~~Consultar postulaciones de ingreso al curso~~`, descartada el 2026-11-06; retiro de la tabla `SolicitudIngresoGrupo` (migración 13), de `GET /docente/grupos/{grupoId}/solicitudes-ingreso` y de la pestaña del hub; `[DESCARTADA]` |
| HU054 (114) | Igual, con `PATCH /docente/solicitudes-ingreso/{id}`; `[DESCARTADA]` |
| HU055 (115) | Igual. El control de cupo se conserva en la matrícula manual y en la de QR (DEC-009); `[DESCARTADA]` |
| HU050 (110) | Se añade: "solo el docente titular (F-COO-004); reactiva una matrícula retirada respetando el cupo (DEC-009)" |
| Resumen (264-271) | `[CERTIFICADA]` 137 → **134** (77.9 %); `[BLOQUEADO 501]` 3 → **2** (1.2 %); `[DESCARTADA]` 20 → **24** (14.0 %), y la lista añade "HU026, HU053, HU054 y HU055, 2026-11-06 (CULM-001 A)"; el TOTAL sigue en **172**. Comprobación: 134 + 3 + 2 + 2 + 7 + 24 = 172 |

### 5.2 `docs/user-stories/HOJA_DE_RUTA_JERARQUIA_ROLES.md`

- Línea 34: "...matricula (por QR/PIN o manualmente, solo en sus grupos) y retira alumnos de su curso." Se quitan "(el coordinador también puede inscribir estudiantes en los grupos de su programa)" (F-COO-004) y "y resuelve las solicitudes de ingreso de los estudiantes (HU053-HU055)".
- Línea 35: "...radica solicitudes de justificación y consulta la oferta de grupos (HU008); se matricula con el QR o PIN del docente (HU176B)."

### 5.3 Suites E2E (solo se quitan las pruebas de HU descartadas)

| Archivo | Bloque | Acción |
| :--- | :--- | :--- |
| `scripts/tests/test_all_hus.ps1` | 224-232, `Run-Test "HU026"` (`POST /estudiante/solicitudes-matricula`) | Se elimina (HU descartada) |
| `scripts/tests/test_all_hus.ps1` | 629-641, `Run-Test "HU053,HU054"` (`GET`/`PATCH /coordinador/solicitudes-matricula`) | Se elimina (HU descartadas) |
| `scripts/tests/test_all_hus.ps1` | 381, `Run-Test "HU043,HU055"` (prueba `usp_crear_grupo`) | **Se conserva la prueba**; la etiqueta pasa a `"HU043"`. Su cuerpo y sus aserciones no cambian |
| `scripts/quality/test-e2e-hus.ps1` | 248-256, `Run-TestItem "HU026"` | Se elimina |
| `scripts/quality/test-e2e-hus.ps1` | 364, `Run-TestItem "HU043,HU055"` | Etiqueta a `"HU043"`; cuerpo igual |
| `scripts/tests/test_all_hus.ps1` | 409-417, `Run-Test "HU050"` (docente sobre su grupo temporal) | Sin cambios. Debe seguir en PASS con E-04 porque el ejecutor es el titular |
| `scripts/tests/test_all_hus.ps1` | Nuevo `Run-Test "F-COO-004"` | `POST /grupos/{grupoDocente}/estudiantes` con el token del coordinador debe responder **403**; si responde 2xx o 400, la prueba falla |

No se relaja ni se elimina ninguna otra prueba. CLOSURE compara el resultado contra la línea base (21 PASS / 52 FAIL): los fallos de HU026 y HU053/054 desaparecen porque las pruebas dejan de existir, y se informan aparte.

### 5.4 Otros

- `docs/work-items/INDEX.md`: registrar `CULM-001/paquetes/A-retiro-solicitudes`.
- `docs/work-items/CULM-001-culminacion/SCREEN-TESTS-estudiante.md` (sección 5, 45-47): actualizar tras el retiro.
- `docs/work-items/backend/REG-000-programa-registro-vinculacion-roles/PLAN.md` (62, 77) y `docs/work-items/backend/LB-002-jpa-incremental/LB-002.1C-B2-DECISION.md`: anotar "descartado en CULM-001 A".
- **Fuera de Git (solo anotar en CLOSURE):** `C:\Proyectos\GestionAsistencia\docs\rutas-por-rol.md`, líneas 58-59 (`/coordinador/grupos/{grupoId}/estudiantes` POST/DELETE), 74-75 (`/coordinador/solicitudes-matricula`), 85 (`DELETE /grupos/{grupoId}/estudiantes/{estudianteId}`), 116 (`POST /grupos/{grupoId}/estudiantes`, rol) y 144 (`POST /estudiante/solicitudes-matricula`, que además atribuye mal la clase a `EstudiantePortalController`).

---

## 6. Orden de integración, ramas y commits

### 6.1 Ramas y destino

Rama `feature/CULM-001-A-retiro-solicitudes` en cada repo, desde `integracion/CULM-001`, con PR hacia `integracion/CULM-001`. Según DEC-002, los PR de DB y Backend se abren en `johnjduque/gestion-asistencia-db` y `alejovh12/AsistenciasUCO`; los de Frontend e Infra, en sus `origin`.

### 6.2 Orden

1. **DB:** commits RED → GREEN → migración → limpieza de `schema/`. `deploy_schema.ps1` y `13_*_up.sql` en la BD local (antes, un backup COPY_ONLY nuevo). Se pasan `infra.ps1 db-test` (sin fallos nuevos frente a F-000) y `test_migracion_13_up_down.ps1` sobre la base clonada.
2. **Backend:** RED → GREEN contra la BD ya migrada. `mvnw verify`, rebuild y reinicio con `start-backend-baseline.ps1`. Comprobación manual: `curl` de las 10 rutas retiradas → 404; `POST /grupos/{id}/estudiantes` con coordinador → 403; oferta sin los 2 campos.
3. **Frontend:** RED → GREEN y `npm run verify`. Recorrido en pantalla: oferta del estudiante sin botón, menú sin "Solicitudes de Ingreso", hub del docente sin la pestaña, matrícula manual de un retirado → reactivado.
4. **Infra:** catálogo, hoja de ruta y suites E2E. `test_all_hus.ps1` y `infra.ps1 verify`.

La BD y el backend se despliegan **juntos**: un backend viejo contra la BD migrada da 500 en la oferta y en las rutas de solicitud; uno nuevo contra la BD sin migrar desordena la oferta (sección 7, R-2).

### 6.3 Commits atómicos previstos

Todos en español, en imperativo, de 72 caracteres o menos, con cuerpo (qué, por qué y cómo) y pie `Refs: CULM-001` más las HU que correspondan, y `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

**GestioAsistenciaDB**
1. `test(db/sp): agregar pruebas red del retiro de solicitudes de ingreso`. Incluye T-01..T-13, E-12..E-15 y `test_migracion_13_up_down.ps1`. Refs: HU008, HU050, HU176B, HU053, HU054, HU055.
2. `feat(db/sp): reactivar matricula retirada en la matricula manual y qr`. Incluye E-02, E-03 y E-08 (DEC-009). Refs: HU050, HU176B.
3. `fix(db/sp): restringir la matricula manual al docente titular del grupo`. Incluye E-04 y E-15 (F-COO-004). Refs: HU050.
4. `refactor(db/sp): quitar columnas de solicitud de la oferta de grupos`. Incluye E-01 (HU008). Pie: `BREAKING CHANGE: el resultset pasa de 21 a 19 columnas`.
5. `feat(db/migrations): agregar migracion 13 de retiro de solicitudes`. Incluye `13_*_up.sql` y `13_*_down.sql` (DEC-010).
6. `chore(db/tables): eliminar tabla, sp, grants y seeds de solicitudes`. Incluye D-01..D-12, E-05..E-07, E-09..E-11. Refs: HU053, HU054, HU055.
7. `docs(db): actualizar fichas e inventario tras el retiro de solicitudes`.

**GestioAsistenciaBackend**
1. `test(backend): agregar pruebas red del retiro de solicitudes de ingreso`. Incluye B-RED-01..08 y los ajustes de expectativa de 3.6.
2. `refactor(backend/adapter): reindexar el mapeo posicional de la oferta`. Incluye la proyección, el repositorio, el dominio, el DTO y el caso de uso de la oferta. Pie: `BREAKING CHANGE: GET /estudiante/oferta-academica sin idSolicitudAbierta ni estadoSolicitud`. Refs: HU008.
3. `refactor(backend/controller): retirar endpoints y casos de uso de solicitudes`. Incluye los 49 `.java`, el wiring y `access-catalog.json`. Pie: `BREAKING CHANGE: se eliminan 10 rutas (404)`. Refs: HU026, HU053, HU054, HU055.
4. `fix(backend/security): restringir la matricula de grupo al rol docente`. Incluye `SecurityConfig`, la fila 155 del catálogo y la retirada de los stubs del coordinador y de `DELETE /grupos/...` (F-COO-004). Refs: HU050.
5. `chore(backend): retirar plantillas y codigos sig de solicitudes`. Incluye los `.properties`, `Notificacion`, `PlantillaPorDefectoCatalogo`, `DbFailureClassifier`, `application.yml` y el `.psv`.
6. `docs(backend): actualizar matriz http y linea base tras el retiro`.

**GestioAsistenciaFrontend**
1. `test(frontend): agregar specs red del retiro de solicitudes de ingreso`. Incluye F-RED-01..08.
2. `refactor(frontend/estudiante): quitar solicitar ingreso de la oferta`. Incluye el componente, `GrupoOferta` y su spec. Refs: HU008.
3. `refactor(frontend/estudiante): eliminar pantalla y servicio de solicitudes`. Incluye las rutas, el menú, `student-enrollment-requests`, `solicitud-ingreso.service`, `student-course-enroll-form` y el código muerto de `student-courses`. Refs: HU026, HU053.
4. `refactor(frontend/docente): eliminar la bandeja de solicitudes del hub`. Incluye el hub, `teacher-grupos`, `teacher-grupo-solicitudes`, el botón "Padrón" y el mensaje 409. Refs: HU054, HU055.
5. `refactor(frontend/coordinador): eliminar metodos de solicitudes y matricula`. Incluye el servicio, `coordinator-students` y el modelo (F-COO-004, F-COO-012).
6. `chore(frontend): limpiar mocks y plantillas de solicitudes de ingreso`. Incluye el interceptor, los mocks, `admin-email-management` y `admin-estados`.
7. `docs(frontend): actualizar mapa de componentes y contrato front-back`.

**AsistenciasUCO-Infra**
1. `docs(hus): descartar HU026, HU053, HU054 y HU055 en el catalogo`.
2. `docs(roles): quitar solicitudes de ingreso de la hoja de ruta`.
3. `test(scripts): retirar pruebas e2e de HU026, HU053 y HU054`. Incluye la nueva prueba de 403 F-COO-004 y las etiquetas `HU043`.
4. `docs(work-items): registrar el paquete A de CULM-001`. Incluye `INDEX.md`, este CONTRACT, PLAN, TEST_PLAN y CLOSURE.

---

## 7. Riesgos y rollback

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| R-1 | **Pérdida de historial y de outbox.** `DROP TABLE` y `DELETE` de plantillas | DEC-010: archivo completo (U-2a), guardia U-3, archivo de estados de notificación (A-C2), `down` R-5/R-8, y backup COPY_ONLY antes de aplicar en cualquier entorno con datos |
| R-2 | **Mapeo posicional de la oferta.** Quitar 2 columnas desplaza `f[19]`/`f[20]`. Si BD y backend se despliegan por separado, el desfase no rompe la compilación | Despliegue conjunto; T-02 (BD) y B-RED-04 (backend) fijan el contrato posicional, y `COLUMNAS_OFERTA = 19` hace fallar a la vista ante una fila de otra longitud |
| R-3 | **Concurrencia en la reactivación.** `usp_validar_cupo_disponible_grupo_interno` lee `uv_grupo` sin bloqueo | El SP nuevo vuelve a comprobar el cupo con `UPDLOCK, HOLDLOCK` sobre `Grupo` y `EstudianteGrupo` (2.3, regla 4), igual que hacía el resolver. Se añade a la prueba de concurrencia de QR de la Fase 3 un caso "dos reactivaciones con 1 cupo" |
| R-4 | **`XACT_ABORT ON` dentro de la transacción del QR.** Un error en el SP nuevo deja la transacción de `usp_internal_matricular_por_token` en `XACT_STATE() = -1` | El llamador ya trata ese estado (líneas 264-274: `ROLLBACK` propio o `THROW`). T-12 cubre la llamada anidada |
| R-5 | **F-COO-004 cambia un comportamiento certificado.** Un coordinador que matriculaba deja de poder hacerlo; un docente no titular, también | Es la regla de producto. RbacSecurityFilterChainTest, T-08/T-09 y la prueba E2E nueva lo fijan. Se comunica en el PR. La matrícula de un estudiante en un grupo ajeno no tiene ya ninguna vía |
| R-6 | **Notificación en vuelo** (`RESERVADA`) durante el `up` | U-0 aborta la migración si hay reservas vigentes; se aplica con el backend detenido |
| R-7 | **PDP del laboratorio desalineado** con `access-catalog.json` hasta que se apruebe `--prune` | El backend aplica `SecurityConfig` y el catálogo; las filas sobrantes del PDP solo afectan a rutas que ya dan 404. Queda pendiente en `PRS.md` |
| R-8 | **Cruce de horario con matrículas `I` de otros grupos** (defecto previo) | Fuera de alcance; se registra como hallazgo nuevo para el paquete D |
| R-9 | **Texto local en el frontend para el 409** (A-C5) | Deuda: pasar a `messages:user:ERR_MATRICULA_DUPLICADA` con un texto para el docente y quitar el reemplazo en la UI. Se registra en `TECHNICAL_DEBT.md` de Infra |
| R-10 | **Borrado de E y X en `dbo.Estado`**, un catálogo de solo consulta (CAT-01) | Se borra por migración, no por SP de escritura; U-6 comprueba que no queda ninguna otra FK hacia `Estado`; R-3 del `down` lo restaura |
| R-11 | **Grep ciego por "solicitud"** que borre reclamos | Inventario explícito por archivo (secciones 2-4), la aserción positiva de B-RED-01 y F-RED-08 limitado a identificadores de ingreso |

### Rollback

1. Revertir los PR en orden inverso (Infra → Frontend → Backend → DB) en `integracion/CULM-001`.
2. Detener el backend y aplicar `13_retiro_solicitudes_ingreso_grupo_down.sql` en la BD. Si el `down` falla, se restaura el backup COPY_ONLY tomado antes del `up`.
3. Desplegar el `schema/` de develop (`65a4998`) con `deploy_schema.ps1`: vuelve a crear seeds y grants idempotentes.
4. Arrancar el backend de `72a1675e` y el frontend de `886a01b`.
5. Comprobar con `db-test`, `mvnw verify` y `npm run verify`, y con las rutas de solicitud en 200.
6. Reprovisionar el PDP con el `access-catalog.json` de develop.
