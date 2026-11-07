---
status: draft-r3
type: contract
scope: db-backend-frontend-infra
work-item: CULM-001
paquete: A
owner: fullstack-team
last-reviewed: 2026-11-07
---

# CONTRACT — CULM-001 paquete A: retiro de las solicitudes de ingreso (A.1) y correcciones críticas y altas de la Fase 1 (A.2)

Fase SDD: **02 CONTRACT, versión 3**. Atiende `REVIEW-1.md` (18 objeciones, respondidas en la §9) y `REVIEW-2.md` (15 objeciones, respondidas en la §10), e integra `CORRECCIONES-A.md`/DEC-022 como §8 (A.2), con las decisiones DEC-027, DEC-028, DEC-030 y DEC-031. Secciones 1-7: A.1, retiro de solicitudes. Insumos: `../../RESEARCH-SOLICITUDES-INGRESO.md`, `../../DECISIONES.md` (DEC-009, DEC-010), `../../FINDINGS-estudiante.md` (F-EST-016 y el inventario), `../../FINDINGS-docente.md` (inventario), `../../FINDINGS-coordinador.md` (F-COO-004, F-COO-012). Este contrato **no se ejecuta**: lo revisa un Opus independiente antes de la fase RED.

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
| A-C3 (revisada) | El estado `E` (en espera, `C5D1E2F3-4A5B-4C6D-8E7F-901A2B3C4D5E`) de `dbo.Estado` se borra si ninguna fila lo referencia. **El estado `X` (retirada, `D6E2F3A4-5B6C-4D7E-9F80-A12B3C4D5E6F`) se conserva** y pasa a `33_culm001_a_catalogos.sql`, porque A.2-7 lo reutiliza para el reclamo retirado (A2-C4). El archivo guarda el **código** del estado, no la FK | `E` solo lo usaba `SolicitudIngresoGrupo` (grep: aparece solo en `seed/22_estados_solicitud_ingreso_grupo.sql` y en `tables/SolicitudIngresoGrupo.sql:34`). La única FK restante hacia `Estado` es `FK_SolicitudRevisionAsistencia_Estado` (`zz_foreign_keys.sql:275-280`). Consumidor afectado: `test_consolidado_auditoria_catalogos.sql:148-150` (E-16) |
| A-C4 | El código del estado "retirado" se lee de un parámetro nuevo, `MATRICULA` / `ESTADO_RETIRADA` = `I`. No se escribe `'I'` en el SP nuevo. | Regla "cero datos quemados" de AGENTS 3.3. Se siembra en `33_culm001_a_catalogos.sql` junto con `MATRICULA/ESTADO_INSCRITA` = `A` (N10); mismo patrón que `MATRICULA_QR/ESTADO_MATRICULA` (`seed/29_parametros_matricula_qr.sql:26`). |
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

A.2 toca endpoints WORM (`GET /api/v1/estudiantes` y `GET /api/v1/grupos/{grupoId}/estudiantes` y `/asistencias`) y SP de sesiones congelados **sin editar ningún archivo congelado**. Cómo se preserva cada uno, y el drift previo de `x-roles`, está en §8.1.

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
| D-10 | Seed de los estados `E` y `X` en `dbo.Estado`. **`E` se elimina; `X` (retirada) se conserva y pasa a `schema/seed/33_culm001_a_catalogos.sql`**, porque A.2-7 lo reutiliza para el reclamo retirado por el estudiante (A-C3 revisada) | `schema/seed/22_estados_solicitud_ingreso_grupo.sql` |
| D-11 | Seed de los mensajes `SIG_001`..`SIG_015` (usuario y técnico) | `schema/seed/23_mensajes_solicitud_ingreso_grupo.sql` |
| D-12 | Prueba `test/test_solicitud_ingreso_grupo.sql` (S-01..S-12) | Se borra el archivo y su línea `:r /tmp/test/test_solicitud_ingreso_grupo.sql` de `test_suite.sql:34` |

No hay vistas `uv_*` ni funciones `ufn_*` propias de las solicitudes (grep sin coincidencias), ni filas propias en `CatalogoParametro`.

### 2.2 Objetos que se editan

| # | Archivo | Antes | Después |
| :--- | :--- | :--- | :--- |
| E-01 | `schema/stored-procedures/usp_consultar_oferta_grupos_estudiante.sql` | Firma `(@busqueda NVARCHAR(50)=NULL, @numeroPagina INT=1, @tamanoPagina INT=10, @idCorrelacion UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER)`. Resultset de **21** columnas: `0 idGrupo, 1 codigoGrupo, 2 nombreGrupo, 3 idAsignatura, 4 codigoAsignatura, 5 nombreAsignatura, 6 nombreDocente, 7 idPeriodoAcademico, 8 nombrePeriodoAcademico, 9 fechaInicioPeriodo, 10 fechaFinPeriodo, 11 estadoPeriodo, 12 horario, 13 capacidadMaxima, 14 estudiantesActivos, 15 cuposDisponibles, 16 matriculado, 17 idSolicitudAbierta, 18 codigoEstadoSolicitud, 19 codigoComponente, 20 totalRegistros`; `OUTER APPLY` sobre `dbo.SolicitudIngresoGrupo` (líneas 152-157); literal `'A'` en `activos` (línea 88) y en `matriculado` (línea 144) | **Firma igual.** Resultset de **19** columnas: `0..16` iguales, `17 codigoComponente NVARCHAR(3)`, `18 totalRegistros INT`. Se quitan las líneas 145-146 y el `OUTER APPLY` 152-157. Los dos `'A'` se sustituyen por `@codigoInscrita = dbo.ufn_obtener_parametro('MATRICULA','ESTADO_INSCRITA')` (N10; mismo parámetro que A.2-11). La cabecera (líneas 17-21) deja de mencionar HU053-HU055. Orden, paginación (`OFFSET/FETCH`, `COUNT(*) OVER()`), ámbito ESP/transversales y `OFERTA.INCLUIR_TRANSVERSALES`: sin cambio |
| E-02 | **Nuevo** `schema/stored-procedures/usp_internal_reactivar_matricula_retirada.sql` | — | Ver 2.3. Sin `GRANT` al runtime (es interno) |
| E-03 | `schema/stored-procedures/usp_registrar_estudiante_en_grupo_interno.sql` | Firma `(@idEstudiante, @idGrupo, @idCorrelacion, @codigoEstado NVARCHAR(10)='A', @mensajeUsuarioResultado OUT, @mensajeTecnicoResultado OUT, @estadoResultado BIT OUT)`. Pasos: estado (línea 46: `IF @codigoEstadoDefecto = '' SET @codigoEstadoDefecto = 'A'`) → estudiante existe → grupo existe → cupo → cruce de horario → duplicado (`uv_estudiante_grupo` sin filtro de estado, `ERR_MATRICULA_DUPLICADA`) → bloque ESP de `EstudiantePrograma` (121-136) → `INSERT` | **Firma igual** (el defecto `'A'` del parámetro se mantiene por compatibilidad de firma, pero el `''` de la línea 46 resuelve `MATRICULA/ESTADO_INSCRITA`, N10). Nuevo orden: validaciones (sin cambio) → **PASO 3.8** `EXEC dbo.usp_internal_reactivar_matricula_retirada ... @reactivada OUTPUT` → si `@estadoResultado = 1 AND @reactivada = 0`: duplicado (sin cambio) → si `@estadoResultado = 1`: **bloque ESP existente (121-136), común a los dos caminos y sin literal nuevo** → si `@estadoResultado = 1 AND @reactivada = 0`: `INSERT EstudianteGrupo` → mensaje `GEN_004` en los dos caminos. **Transacción (bloqueante 1):** el interno no abre transacción ni usa `XACT_ABORT`: **participa en la transacción de su llamador**. Sus dos llamadores públicos la abren (E-04 y `usp_internal_matricular_por_token:64-74`, savepoint `sp_hu176b_negocio` en 194/249). Así lo justifica `docs/arquitectura/transaccion-procedimiento.md` para los internos de validación y escritura compuestos. Se declara en la cabecera del SP: "Requiere transacción del llamador; no la abre ni la confirma". Su `CATCH` (152-160) no se modifica: convierte el error en `SYS_001` y `@estadoResultado = 0`, y el llamador revierte su savepoint |
| E-04 | `schema/stored-procedures/usp_registrar_estudiante_en_grupo.sql` (F-COO-004 y bloqueante 1) | Línea 62: `@codigoPerfilRequerido = 'DOCENTE,COORDINADOR'`; sin titularidad; **sin `XACT_ABORT` ni transacción**: si el interno falla después de que `usp_sincronizar_usuario_interno`/`usp_sincronizar_estudiante_interno` crearon `Usuario`/`Estudiante` (por ejemplo `HOR_001` o `ERR_MATRICULA_DUPLICADA`), esas filas quedan | `@codigoPerfilRequerido = 'DOCENTE'`. Nuevo **PASO 1.85** tras el 1.8 (grupo existe, 70-78) y antes del cupo: `EXEC dbo.usp_validar_titularidad_jerarquica_interno @idUsuario = @idUsuarioEjecutorDefecto, @idEntidadPadre = @idGrupoDefecto, @tipoEntidadPadre = 'GRUPO', ...` → `SEC_002` (patrón de `usp_cerrar_ventana_matricula_grupo.sql:69-76`). **Transacción (patrón de `usp_internal_matricular_por_token:42-74` y `:254-283`):** `SET XACT_ABORT ON`; `@conteoTransaccionesInicial = @@TRANCOUNT`; si es 0, `BEGIN TRANSACTION` con `@transaccionPropia = 1`, si no, `SAVE TRANSACTION sp_registrar_estudiante_grupo` con `@savepointCreado = 1`. Las validaciones sin escritura (pasos 1-1.9) van antes de un `SAVE TRANSACTION sp_registrar_estudiante_negocio`. Si `@estadoResultado = 0` después de escribir y `XACT_STATE() = 1`: `ROLLBACK TRANSACTION sp_registrar_estudiante_negocio`. Cierre: con transacción propia, `COMMIT` si `XACT_STATE() = 1` o `ROLLBACK` si `= -1`. `CATCH`: con transacción propia, `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION`; con savepoint y `XACT_STATE() = 1`, `ROLLBACK TRANSACTION sp_registrar_estudiante_grupo`; con `XACT_STATE() = -1` y sin transacción propia, `THROW`; después `SYS_001`. El `SELECT` final del resultset canónico va **fuera** de la transacción. Firma y resultset sin cambio |
| E-05 | `schema/tables/zz_foreign_keys.sql` | Bloque "42-46" (líneas 352-377) | Bloque quitado (D-02) |
| E-06 | `schema/seed/04_mensaje.sql` | Líneas 118 (usuario) y 254 (técnico): `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA` | Filas quitadas |
| E-07 | `schema/seed/26_plantillas_notificacion.sql` | Marcadores, líneas 17-22, y plantillas, líneas 71-73, de `SOLICITUD_INGRESO_REGISTRADA`, `_RESUELTA` y `_RETIRADA` | Filas quitadas. `RETIRO_ESTUDIANTE_GRUPO` y las demás, intactas |
| E-08 | **Nuevo** `schema/seed/33_culm001_a_catalogos.sql` (numeración 33 de A) | — | `MERGE` idempotente en `CatalogoParametro` (forma de `29_parametros_matricula_qr.sql`: `grupo, clave, valor, tipoDato, valorDefecto`): `('MATRICULA','ESTADO_RETIRADA',N'I','STRING',N'I')` y `('MATRICULA','ESTADO_INSCRITA',N'A','STRING',N'A')`, más los de A.2 (§8.3). `MERGE` en `dbo.Estado` del estado `X` (`D6E2F3A4-5B6C-4D7E-9F80-A12B3C4D5E6F`, `'retirada'`), que hoy está en el seed 22 que se borra |
| E-09 | `test_suite.sql` | Línea 34, `test_solicitud_ingreso_grupo.sql` | Línea quitada. Se añade `:r /tmp/test/test_culm001_a_retiro_solicitudes.sql` **después** de `test_usp_matricular_estudiante_por_token.sql` (usa la ventana QR) |
| E-10 | `test/test_contract_closure.sql` | Excepciones en líneas 201-206 y listas `NOT IN` en 252, 271 y 292 con `usp_resolver_solicitud_ingreso_grupo`, `usp_consultar_solicitudes_ingreso_grupo_docente`, `usp_consultar_solicitudes_ingreso_estudiante` y `usp_consultar_destinatarios_solicitud_ingreso_grupo` | Esos 4 nombres quitados de los comentarios y de las 3 listas. El SP nuevo es `usp_internal_*` y no es público. Las excepciones que añade A.2 están en §8.2 |
| E-11 | `test/test_notif002a_plantillas_contacto.sql` | Líneas 36, 49-83, 94-104 y 328-330: aserciones de los 3 tipos; conteos de 4 plantillas y 9 marcadores | Se quitan las aserciones de los 3 tipos. Los conteos esperados se recalculan **restando exactamente** las filas retiradas: quedan 1 plantilla y 3 marcadores (comprobado por REVIEW-1). No se relaja ninguna otra aserción |
| E-12 | `test/test_usp_consultar_oferta_grupos_estudiante.sql` | Fixture `INSERT INTO dbo.SolicitudIngresoGrupo` (línea 96); `#o` con 21 columnas (99-103); G2 "con solicitud abierta P" (128-129); `idSolicitudAbierta IS NULL` (123) | Fixture quitado; `#o` con 19 columnas; G2 se valida como `PROXIMO` con `cuposDisponibles = 30` y `matriculado = 0`; se quita la condición `idSolicitudAbierta IS NULL`. **Se añade O-06** (2.6, T-02). O-01..O-05 se conservan sin relajar |
| E-13 | `test/test_hu008_regla_inscripcion_programa.sql` | RI-01..RI-03 matriculan por `usp_registrar_solicitud_ingreso_grupo` + `usp_resolver_solicitud_ingreso_grupo` (líneas 55-85) | La vía pasa a `usp_registrar_estudiante_en_grupo` ejecutado por el **docente titular** (`@userT`), con usuarios existentes (el SP encuentra el correo). Mismas 3 reglas: ESP inscribe en `EstudiantePrograma`; INS y BAS no. Se quitan `#rx`, los `@s*` y la nota de `QUOTED_IDENTIFIER`. Se añade RI-04 (T-07) |
| E-14 | `test/test_int_hu01_reactivar_matricula_retirada.sql` | RM-01..RM-03 por solicitud + resolver | Se reescribe con T-03, T-05 y T-06 de 2.6 (manual). Conserva los nombres `INT_HU01_RM01_*`, `RM02_*` y `RM03_*`. RM-02 pasa de "queda EN ESPERA" a "rechaza `ERR_CUPO_SUPERADO`" porque HU055 (lista de espera) se descarta |
| E-15 | `test/test_usp_registrar_estudiante_en_grupo_usuario_no_existente.sql` | Línea 13: el ejecutor es `TOP 1` docente activo cualquiera, no necesariamente el titular de `@grupo` | El ejecutor pasa a ser el titular de `@grupo` (`uv_grupo.idDocente` → `uv_docente_identidad.idUsuario`). Es un ajuste del fixture por el cambio formal E-04: `STUDENT_SUCCESS`, grupo inexistente, cerrado y lleno conservan sus aserciones. T-08 y T-09 cubren el rechazo |
| E-16 | `test/test_consolidado_auditoria_catalogos.sql:148-150` (T-155-01) (bloqueante 4) | `COUNT(*) FROM uv_estado WHERE codigo IN ('P','A','R','E','X') = 5` | `COUNT(*) ... codigo IN ('P','A','R','X') = 4` **y** `NOT EXISTS (codigo = 'E')`, con el mensaje "uv_estado debe exponer los 4 estados de solicitud del seed (E retirado en CULM-001 A)". Es un cambio formal por A-C3 revisada. Las demás aserciones de T-155-01 (codigo y nombre no nulos, `uv_estado_estudiante_grupo`) no cambian |

### 2.3 Contrato del SP nuevo `dbo.usp_internal_reactivar_matricula_retirada` (DEC-009)

```text
CREATE OR ALTER PROCEDURE [dbo].[usp_internal_reactivar_matricula_retirada]
(
    @idEstudiante            UNIQUEIDENTIFIER,
    @idGrupo                 UNIQUEIDENTIFIER,
    @idCorrelacion           UNIQUEIDENTIFIER,
    @codigoEstadoDestino     NVARCHAR(10),          -- codigo de uv_estado_estudiante_grupo resuelto por el interno
    @mensajeUsuarioResultado NVARCHAR(4000) OUTPUT,
    @mensajeTecnicoResultado NVARCHAR(4000) OUTPUT,
    @estadoResultado         BIT OUTPUT,
    @reactivada              BIT OUTPUT             -- 1 si hubo I -> destino; 0 si no habia matricula retirada
)
```

Reglas (corregidas por los bloqueantes 2, N4 y N12):
1. `SET NOCOUNT ON; SET XACT_ABORT ON;` y `BEGIN TRY/CATCH`. Transacción propia si `@@TRANCOUNT = 0`; si no, `SAVE TRANSACTION sp_reactivar_matricula` (patrón de `usp_retirar_estudiante_grupo.sql:57-190`). En el `CATCH`: con transacción propia, `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION`; con savepoint y `XACT_STATE() = 1`, `ROLLBACK TRANSACTION sp_reactivar_matricula`; con `XACT_STATE() = -1` y sin transacción propia, `THROW`. Mensaje `SYS_001` y `ufn_obtener_detalle_error`.
2. Parámetros evaluados con `IS NULL`; defectos con `ufn_obtener_parametro_guid` / `ufn_obtener_parametro_texto`.
3. El código retirado sale de `dbo.ufn_obtener_parametro('MATRICULA','ESTADO_RETIRADA')`; el id destino, de `uv_estado_estudiante_grupo WHERE codigo = @codigoEstadoDestino`. Si alguno no existe: `GEN_001`, `@estadoResultado = 0` y ninguna escritura.
4. **Búsqueda antes del bloqueo (N4):** primero `SELECT TOP 1 @idEstudianteGrupo = eg.id FROM dbo.EstudianteGrupo eg INNER JOIN dbo.uv_estado_estudiante_grupo es ON es.id = eg.estado WHERE eg.grupo = @idGrupo AND eg.estudiante = @idEstudiante AND es.codigo = @codigoRetirada ORDER BY eg.id`, **sin** pistas de bloqueo. Si no hay fila: `@reactivada = 0`, `@estadoResultado = 1`, sin escrituras, y se libera la transacción o el savepoint. Así la matrícula nueva normal (el caso masivo de HU176B) no toma bloqueos adicionales.
5. **Solo si hay fila retirada:** `SELECT @capacidad = g.cantidadEstudiantes FROM dbo.Grupo g WITH (UPDLOCK, HOLDLOCK) WHERE g.id = @idGrupo`. Después se vuelve a leer la fila `I` con `WITH (UPDLOCK, HOLDLOCK)` por su `id` (si cambió de estado entre lecturas: `@reactivada = 0`, sin error), y `SELECT @activos = COUNT(*) FROM dbo.EstudianteGrupo eg WITH (UPDLOCK, HOLDLOCK) ... WHERE eg.grupo = @idGrupo AND es.codigo = @codigoEstadoDestino`. El bloqueo sobre `Grupo` serializa las reactivaciones del mismo grupo sin depender de un índice por `(grupo, estudiante)`.
6. Con matrícula retirada y `@capacidad - @activos <= 0`: `ERR_CUPO_SUPERADO` (`@p_param1 = @idGrupo`), `@estadoResultado = 0`, `@reactivada = 0`, sin escrituras.
7. **Con cupo: solo** `UPDATE dbo.EstudianteGrupo SET estado = @idEstadoDestino WHERE id = @idEstudianteGrupo`. Se conserva la misma fila y sus asistencias históricas (INT-HU-01). `@reactivada = 1`, `@estadoResultado = 1`. **No inscribe en `EstudiantePrograma` ni contiene el literal `'ESP'`** (bloqueante 2): esa regla la aplica una sola vez el bloque existente del interno (E-03), común a los dos caminos. El mensaje `GEN_004` lo pone el interno.
8. `@mensajeTecnicoResultado` termina en `' Correlacion: ' + @idCorrelacion`.
9. `@@TRANCOUNT` al salir es igual al de entrada.

Efecto en las vías:
- **Manual (HU050):** `POST /api/v1/grupos/{grupoId}/estudiantes` con un estudiante retirado → 201 y la misma matrícula `A`. Antes respondía 409 `ERR_MATRICULA_DUPLICADA`. Con matrícula activa, sigue el 409.
- **QR/PIN (HU176B):** `usp_internal_matricular_por_token` rechaza con `MQR_004` solo si la matrícula está en `MATRICULA_QR/ESTADO_MATRICULA` (`A`) (146-154); una `I` llega al interno y se reactiva; `totalMatriculas` + 1 (244). Modo público: sin estudiante conocido no hay reactivación (`MQR_005`).
- **Errores bajo QR (N12):** si el SP nuevo falla dentro de la transacción del QR, el `CATCH` del interno (152-160) lo convierte en `@estadoResultado = 0` **sin relanzar**. Con `XACT_STATE() = 1`, `usp_internal_matricular_por_token` revierte `sp_hu176b_negocio` (246-251). Con `XACT_STATE() = -1` (error con `XACT_ABORT ON`), el PASO 5 (255-260) lo resuelve **solo con transacción propia** (`ROLLBACK`). Con una transacción externa del llamador, esta vuelve al llamador no confirmable (`XACT_STATE() = -1`) y el llamador debe revertirla. Lo fija T-12c.

### 2.4 Migración `migrations/13_culm001_a_retiro_solicitudes_up.sql`

Número 13 (el último en uso es `12_categoria_justificacion_*`; ya hay números repetidos, como los dos `11_*`). Prefijo `culm001_a` de A. La migración de A.2 es la **14** (`14_culm001_a_correcciones_fase1_*`, §8.2; DEC-028, que prevalece por DEC-031 §2) y se aplica después. Cabecera al estilo de `11_catalogos_solo_consulta_up.sql`: `USE [gestionasistenciadb]; GO; SET NOCOUNT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;`, más un comentario con la decisión del responsable (2026-11-06), DEC-009, DEC-010, F-COO-004 y "deploy_schema.ps1 no borra objetos. Idempotente".

| Paso | Lote | Contenido | Idempotencia |
| :--- | :--- | :--- | :--- |
| U-0 | propio | Si existe la tabla y hay filas de `NotificacionSaliente` en `RESERVADA` de los 3 tipos con `reservadoHasta > SYSDATETIMEOFFSET()`: `THROW 53300, 'CULM001_A: hay notificaciones de solicitud reservadas por el despachador; detener el backend y reintentar.', 1`. Las reservas **vencidas** no bloquean (ver U-2b y R-8) | Solo lectura |
| U-1 | propio | Tablas de archivo, todas **sin FK** y sin `GRANT`: (1) `dbo.zz_archivo_SolicitudIngresoGrupo (id UNIQUEIDENTIFIER NOT NULL PK, estudiante, grupo UNIQUEIDENTIFIER NOT NULL, codigoEstado CHAR(1) NOT NULL, fechaSolicitudUtc DATETIME2(7) NOT NULL, fechaResolucionUtc DATETIME2(7) NULL, motivoRechazo NVARCHAR(500) NULL, docenteResolutor UNIQUEIDENTIFIER NULL, estudianteGrupo UNIQUEIDENTIFIER NULL, fechaArchivoUtc DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(), origen VARCHAR(20) NOT NULL DEFAULT 'CULM-001-A')`. (2) `dbo.zz_archivo_NotificacionSolicitudIngreso (idNotificacion UNIQUEIDENTIFIER NOT NULL PK, codigoEstadoAnterior VARCHAR(30) NOT NULL, codigoErrorAnterior VARCHAR(40) NULL, detalleErrorAnterior NVARCHAR(300) NULL, proximoIntentoEnAnterior DATETIMEOFFSET(7) NULL, fechaCancelacionUtc DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME())` (A-C2). (3) **Nuevas (bloqueante 3c):** `dbo.zz_archivo_PlantillaSolicitudIngreso` con las mismas columnas que `PlantillaNotificacion` (`id, tipo, idioma, version, asunto, cuerpo, activa, creadoPor, creadoEn`; PK `id`) y `dbo.zz_archivo_PlantillaMarcadorSolicitudIngreso` con las de `PlantillaNotificacionMarcador` (`id, tipo, marcador, descripcion, ejemplo, obligatorio`; PK `id`) | `IF OBJECT_ID ... IS NULL` |
| U-2 | propio, transaccional | `SET XACT_ABORT ON; BEGIN TRY; BEGIN TRANSACTION;`. (a) Si existe la tabla, `INSERT INTO zz_archivo_SolicitudIngresoGrupo SELECT s.id, ..., e.codigo, ... FROM dbo.SolicitudIngresoGrupo s INNER JOIN dbo.Estado e ON e.id = s.estado WHERE NOT EXISTS (archivo con el mismo id)`, por `sp_executesql` para que el lote compile sin la tabla. (b) `INSERT INTO zz_archivo_NotificacionSolicitudIngreso` de las filas de `NotificacionSaliente` con `tipo IN ('SOLICITUD_INGRESO_REGISTRADA','SOLICITUD_INGRESO_RESUELTA','SOLICITUD_INGRESO_RETIRADA')` y `EstadoNotificacion.esTerminal = 0`, sin duplicar. (c) `UPDATE NotificacionSaliente SET idEstado = (EstadoNotificacion 'FALLIDA_DEFINITIVA'), codigoError = 'TIPO_NOTIFICACION_RETIRADO', detalleError = N'CULM-001 A: el tipo de notificacion fue retirado con las solicitudes de ingreso.', proximoIntentoEn = NULL, reservadoHasta = NULL, reservadoPor = NULL` sobre esas filas (A-C1). (d) **Antes de borrar**, copiar **todas las versiones** de `PlantillaNotificacion` y **todos** los `PlantillaNotificacionMarcador` de los 3 tipos a las tablas (3) sin duplicar; después `DELETE` de marcadores y plantillas. (e) `DELETE CatalogoMensajeUsuario` y `CatalogoMensajeTecnico` con `codigo IN ('SIG_001',...,'SIG_015','ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA')`. (f) `MERGE` de E-08 (parámetros `MATRICULA/*` y estado `X`). `COMMIT`. `CATCH`: `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;` | `NOT EXISTS` / `MERGE` / `DELETE` de 0 filas |
| U-3 | propio | Guardias: si existe la tabla y hay filas sin archivo, `THROW 53301, 'CULM001_A: archivo incompleto; no se elimina SolicitudIngresoGrupo.', 1`. Si quedan plantillas o marcadores de los 3 tipos sin archivo, `THROW 53303` | Solo lectura |
| U-4 | un lote por SP | `IF OBJECT_ID(N'dbo.<sp>', N'P') IS NOT NULL DROP PROCEDURE [dbo].[<sp>];` para D-03..D-08 (los `GRANT` caen con el `DROP`) | `IF OBJECT_ID` |
| U-5 | propio | `IF OBJECT_ID('dbo.SolicitudIngresoGrupo','U') IS NOT NULL DROP TABLE dbo.SolicitudIngresoGrupo;` (FK, índices y default incluidos) | `IF OBJECT_ID` |
| U-6 | propio | Comprobación genérica en `sys.foreign_keys`: la única FK restante hacia `dbo.Estado` es `FK_SolicitudRevisionAsistencia_Estado`; si aparece otra, `THROW 53302`. Después, `DELETE FROM dbo.Estado WHERE id = 'C5D1E2F3-4A5B-4C6D-8E7F-901A2B3C4D5E' AND codigo = 'E' AND NOT EXISTS (SELECT 1 FROM dbo.SolicitudRevisionAsistencia r WHERE r.estado = Estado.id)`. **`X` no se borra** (A-C3 revisada) | `DELETE` idempotente |
| U-7 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_consultar_oferta_grupos_estudiante` (E-01); conserva su `GRANT` | `CREATE OR ALTER` |
| U-8 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_internal_reactivar_matricula_retirada` (2.3) | `CREATE OR ALTER` |
| U-9 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_registrar_estudiante_en_grupo_interno` (E-03) | `CREATE OR ALTER` |
| U-10 | propio | `CREATE OR ALTER PROCEDURE dbo.usp_registrar_estudiante_en_grupo` (E-04); conserva su `GRANT` | `CREATE OR ALTER` |
| U-11 | propio | Verificación final con `PRINT`: `OBJECT_ID` nulos de D-01 y D-03..D-08 y conteos de las 4 tablas de archivo y de notificaciones canceladas | Solo lectura |

Los cuerpos de U-7..U-10 son **copias exactas** de los archivos de `schema/` del mismo commit (T-13).

### 2.5 Migración `migrations/13_culm001_a_retiro_solicitudes_down.sql`

Cabecera: "Rollback de 13_culm001_a_retiro_solicitudes_up.sql: restaura los objetos tal como estaban en develop (`65a4998`)". Cuerpos de SP tomados con `git show 65a4998:<ruta>`. **El `down` tolera lo que pasó después del `up`** (depuración, reintentos, reservas vencidas) y solo se detiene si se perderían solicitudes. Orden:

| Paso | Contenido |
| :--- | :--- |
| R-1 | `CREATE OR ALTER` de `usp_registrar_estudiante_en_grupo` (perfil `'DOCENTE,COORDINADOR'`, sin titularidad ni transacción), `usp_registrar_estudiante_en_grupo_interno` (sin reactivación) y `usp_consultar_oferta_grupos_estudiante` (21 columnas con `OUTER APPLY`). Van **antes** que la tabla porque la resolución diferida de nombres lo permite. Si ya se aplicó el `up` de A.2, primero se aplica su `down` (§8.2) |
| R-2 | `IF OBJECT_ID(...) IS NOT NULL DROP PROCEDURE dbo.usp_internal_reactivar_matricula_retirada`; `DELETE CatalogoParametro WHERE grupo = 'MATRICULA' AND clave IN ('ESTADO_RETIRADA','ESTADO_INSCRITA')` |
| R-3 | `MERGE` del estado `E` con su id fijo. `X` sigue existiendo, porque no se borró |
| R-4 | `IF OBJECT_ID('dbo.SolicitudIngresoGrupo','U') IS NULL`: se crean la tabla, la PK, el default y los 2 índices (contenido de `tables/SolicitudIngresoGrupo.sql`) |
| R-5 | **`IF OBJECT_ID('dbo.zz_archivo_SolicitudIngresoGrupo','U') IS NOT NULL` (N11)**, en transacción con `XACT_ABORT ON`: `INSERT INTO dbo.SolicitudIngresoGrupo` desde el archivo, con `estado` resuelto por `Estado.codigo`, saltando ids ya presentes. Después, las 5 FK con `IF NOT EXISTS (sys.foreign_keys)`. Si una FK no valida porque falta un `EstudianteGrupo` o `Docente` referenciado, se crea `WITH NOCHECK` y se avisa por `PRINT`, sin perder datos |
| R-6 | 6 SP completos (D-03..D-08) con `CREATE OR ALTER` y su `GRANT EXECUTE ... TO [rol_asistencias_runtime]` |
| R-7 | Mensajes `SIG_001`..`SIG_015` y `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA` (usuario y técnico) por `MERGE`. **Plantillas y marcadores desde `zz_archivo_Plantilla*SolicitudIngreso` (bloqueante 3c), con todas las versiones, `activa`, `creadoPor` y `creadoEn` tal como estaban.** Solo si el archivo no existe (BD sin `up`) se usa el contenido v1 del seed (`26_plantillas_notificacion.sql` 17-22 y 71-73). Va protegido con `IF OBJECT_ID ... IS NOT NULL` (N11) |
| R-8 | **`IF OBJECT_ID('dbo.zz_archivo_NotificacionSolicitudIngreso','U') IS NOT NULL` (N11).** Para cada fila archivada: (i) si la notificación ya no existe en `NotificacionSaliente` (**depurada** por `usp_depurar_notificaciones_salientes_interno:53-61`) o su `codigoError` ya no es `TIPO_NOTIFICACION_RETIRADO` (**reintentada** por el administrador con `usp_reintentar_notificacion_saliente_interno:67,86-94`), cuenta como **resuelta**: no se toca y se informa por `PRINT` con el conteo de cada caso. (ii) Si sigue cancelada: se restaura `idEstado` por código, `codigoError`, `detalleError` y `proximoIntentoEn`. **Si el estado anterior era `RESERVADA`, se restaura como `PENDIENTE` con `proximoIntentoEn = SYSDATETIMEOFFSET()`** (bloqueante 3b): el despachador solo toma las `RESERVADA` con `reservadoHasta < @ahora` (`usp_reservar_notificaciones_salientes_interno:57`) y `reservadoHasta` ya es NULL |
| R-9 | `DROP TABLE` de `zz_archivo_NotificacionSolicitudIngreso` y de las dos `zz_archivo_Plantilla*` cuando R-7 y R-8 terminan. `zz_archivo_SolicitudIngresoGrupo` se borra **solo** si todas sus filas existen en `SolicitudIngresoGrupo`; si no, `THROW 53310, 'CULM001_A: hay solicitudes archivadas sin restaurar.', 1`. **Es el único `THROW` del `down`** (bloqueante 3a) |

El `down` es idempotente: los pasos R-5, R-7 y R-8 se saltan sin error cuando las tablas de archivo ya no existen (N11). El backend que acompaña al `down` es el de develop (sección 7).

### 2.6 Pruebas T-SQL

Archivo nuevo: `test/test_culm001_a_retiro_solicitudes.sql`. Las reescrituras E-11..E-16 van en sus archivos. Formato del repo: `SET NOCOUNT ON; SET XACT_ABORT OFF;`, fixtures dentro de **una** transacción con `ROLLBACK` final, `THROW 5xxxx 'TEST FAILED: ...'`, `PRINT 'TEST_PASS:<id>'` e `IF @@TRANCOUNT <> 0 THROW ...` al final. Columna "Tipo": **RED** falla hoy y pasa tras el cambio; **CAR** (caracterización, N2) ya pasa hoy y fija que el cambio no rompe la regla.

| ID | Tipo | Regla | Aserción | Archivo |
| :--- | :--- | :--- | :--- | :--- |
| T-01 | RED | Objetos ausentes tras `up` + `deploy_schema.ps1` | `OBJECT_ID` nulo para `dbo.SolicitudIngresoGrupo` (`U`) y los 6 SP (`P`); 0 FK `FK_SolicitudIngresoGrupo_%`; 0 filas en `CatalogoMensajeUsuario`/`CatalogoMensajeTecnico` con `SIG_0%`/`SIG_1%` o `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`; 0 filas en `PlantillaNotificacion`/`PlantillaNotificacionMarcador` con `tipo LIKE 'SOLICITUD_INGRESO_%'`; 0 filas en `Estado` con `codigo = 'E'`; `X` existe; `CatalogoParametro MATRICULA/ESTADO_RETIRADA = 'I'` y `MATRICULA/ESTADO_INSCRITA = 'A'` | `test_culm001_a_retiro_solicitudes.sql` (`CULM001A_T01_OBJETOS_RETIRADOS`) |
| T-01b | RED (condicional, bloqueante 5) | Archivo aislado, **solo si existe** | `IF OBJECT_ID('dbo.zz_archivo_SolicitudIngresoGrupo','U') IS NOT NULL` (y lo mismo para las otras 3): `sys.foreign_keys` con `parent_object_id` de cualquiera = 0; `sys.database_permissions` del principal `rol_asistencias_runtime` sobre ellas = 0; ningún módulo las referencia (`sys.sql_expression_dependencies`). En una BD construida solo con `deploy_schema.ps1` (CI, entorno nuevo) imprime `TEST_PASS` sin aserciones de existencia. **La existencia se exige en T-10** | idem (`CULM001A_T01B_ARCHIVO_AISLADO`) |
| T-02 | RED | La oferta no trae columnas de solicitud | `sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.usp_consultar_oferta_grupos_estudiante'), 0)`: 19 columnas; ninguna es `idSolicitudAbierta` ni `codigoEstadoSolicitud`; `column_ordinal` 18 = `codigoComponente` y 19 = `totalRegistros`. Fija el orden posicional que lee el backend | `test_usp_consultar_oferta_grupos_estudiante.sql` (O-06, `TEST_PASS:HU008_OFERTA_SIN_SOLICITUD`) |
| T-03 | RED | Reactivación manual `I`→`A` | E1 matriculado por `usp_registrar_estudiante_en_grupo` (ejecutor `@userT`, titular) y retirado por `usp_retirar_estudiante_grupo` (`I`). Al volver a matricularlo a mano: `estadoResultado = 1`, mensaje `GEN_004`, `COUNT(EstudianteGrupo WHERE grupo, estudiante) = 1`, **mismo `id`** y estado `A` | `test_int_hu01_reactivar_matricula_retirada.sql` (`INT_HU01_RM01_REACTIVA_MATRICULA`) |
| T-04 | RED | Reactivación por QR `I`→`A` con cupo | Ventana abierta por `usp_abrir_ventana_matricula_grupo` (PIN de prueba, como en `test_usp_matricular_estudiante_por_token.sql:68-76`); E2 matriculado y retirado (`I`); `usp_matricular_estudiante_por_token @pin, @idUsuarioEjecutor = <usuario E2>`: `estadoResultado = 1`, misma fila `EstudianteGrupo` en `A`, `TokenMatriculaGrupo.totalMatriculas` + 1 | `test_culm001_a_retiro_solicitudes.sql` (`CULM001A_T04_QR_REACTIVA`) |
| T-05 | CAR | Un grupo lleno rechaza la reactivación | Grupo con `cantidadEstudiantes = activos` y E1 en `I`. Manual: `estadoResultado = 0`, `ERR_CUPO_SUPERADO`, E1 sigue en `I` y sin filas nuevas. QR: `estadoResultado = 0` y `totalMatriculas` sin cambio. Ya pasa hoy (lo rechaza `usp_validar_cupo_disponible_grupo_interno` antes del SP nuevo); la regla 6 bajo bloqueo la prueba T-12b | `test_int_hu01_...` (`INT_HU01_RM02_CUPO_RESPETADO`) y `test_culm001_a_...` (`CULM001A_T05_QR_CUPO_LLENO`) |
| T-06 | CAR | Una matrícula activa sigue bloqueando | E1 en `A`; manual → `ERR_MATRICULA_DUPLICADA` sin cambios; QR → `MQR_004` | `test_int_hu01_...` (`INT_HU01_RM03_ACTIVA_SIGUE_BLOQUEADA`) |
| T-07 | RED | Regla ESP al reactivar (un solo sitio) | Asignatura ESP y E3 en `I` sin `EstudiantePrograma`: la reactivación manual inscribe en `EstudiantePrograma` (lo hace el bloque del interno); con INS o BAS no inscribe. Además, `OBJECT_DEFINITION(OBJECT_ID('dbo.usp_internal_reactivar_matricula_retirada')) NOT LIKE '%EstudiantePrograma%'` y `NOT LIKE '%''ESP''%'` (bloqueante 2) | `test_hu008_regla_inscripcion_programa.sql` (RI-04) |
| T-08 | RED | El coordinador no matricula (F-COO-004) | `usp_registrar_estudiante_en_grupo` con un coordinador como ejecutor → `estadoResultado = 0` con `SEC_001`; sin `Usuario`/`Estudiante`/`EstudianteGrupo` nuevos | `test_culm001_a_...` (`CULM001A_T08_COORDINADOR_403`) |
| T-09 | RED | Un docente que no es titular no matricula | Docente activo no titular del grupo → `estadoResultado = 0`, `SEC_002`; sin escrituras | idem (`CULM001A_T09_DOCENTE_NO_TITULAR`) |
| T-10 | RED (compuerta manual del PLAN, N7) | `up` idempotente, `down` tolerante, `up` de nuevo | **Nuevo** `scripts/tests/test_migracion_13_culm001_a.ps1`, que **no** forma parte de `infra.ps1 db-test`: se ejecuta a mano en las fases GREEN y AUDIT, y su salida se adjunta a `VALIDATION.md`. Corre sobre una **base clonada** (`RESTORE` del backup COPY_ONLY con otro nombre), nunca sobre `gestionasistenciadb`. **Siembra antes del `up`:** 2 solicitudes (P y A); una **versión 2** de `SOLICITUD_INGRESO_REGISTRADA` creada por un administrador (`creadoPor` no nulo, `activa = 1`, la v1 en `activa = 0`); una notificación `RESERVADA` **vencida** (`reservadoHasta` en el pasado). Secuencia: `up` → comprobaciones: existen las 4 `zz_archivo_*` con sus filas (incluidas las dos versiones de plantilla) → `up` otra vez (sin error y mismos conteos) → **después del `up`, simula la depuración** (borra de `NotificacionSaliente` una fila cancelada) **y el reintento** (pasa otra a `PENDIENTE` y limpia `codigoError`, como `usp_reintentar_notificacion_saliente_interno`) → `down` **sin error** → comprobaciones: tabla y 6 SP con `GRANT`; `E` existe; `SIG_*`; las **2 versiones** de plantilla con su `activa` y su `creadoPor`; las 2 solicitudes; oferta de 21 columnas; la `RESERVADA` vencida queda `PENDIENTE` con `proximoIntentoEn` no nulo; la depurada y la reintentada se informan como resueltas; no quedan `zz_archivo_*` → `down` otra vez (sin error, N11) → `up` de nuevo | `test_migracion_13_culm001_a.ps1` (`TEST_PASS:CULM001A_T10_UP_DOWN_UP`) |
| T-11 | RED | Notificaciones pendientes canceladas y no reenviables | En la base clonada, antes del `up`: una `PENDIENTE` de `SOLICITUD_INGRESO_REGISTRADA`, una `FALLIDA_REINTENTABLE` de `_RESUELTA`, una `ENTREGADA` de `_RETIRADA`, una `RESERVADA` vencida de `_REGISTRADA` y una `PENDIENTE` de `RETIRO_ESTUDIANTE_GRUPO`. Tras el `up`: las 3 no terminales de solicitud quedan en `FALLIDA_DEFINITIVA` con `codigoError = 'TIPO_NOTIFICACION_RETIRADO'` y archivadas con su estado previo; la `ENTREGADA` y la de `RETIRO_ESTUDIANTE_GRUPO` no cambian; `usp_reservar_notificaciones_salientes` no devuelve ninguna de los 3 tipos. **N6:** `usp_reintentar_notificacion_saliente` sobre una cancelada la vuelve a encolar (comportamiento documentado, no se cambia el SP); el despachador del backend la marca `FALLIDA_DEFINITIVA` porque el tipo ya no está en `PlantillaPorDefectoCatalogo` (lo cubre B-RED-09) | `test_migracion_13_culm001_a.ps1` (`CULM001A_T11_OUTBOX_CANCELADO`) |
| T-12 | RED | Transacciones (bloqueante 1, N12) | **T-12a:** en T-03..T-09, `IF @@TRANCOUNT <> 1 THROW` antes del `ROLLBACK` del test y `IF @@TRANCOUNT <> 0 THROW` al final. **T-12b:** `usp_internal_reactivar_matricula_retirada` llamado directamente con `@@TRANCOUNT = 0` (sale en 0) y con `@@TRANCOUNT = 1` (sale en 1), en un caso feliz y en uno con cupo lleno **bajo bloqueo** (para fijar la regla 6, se reduce `cantidadEstudiantes` después de la validación del interno). **T-12c:** `usp_registrar_estudiante_en_grupo` con un **usuario nuevo** cuya matrícula falla en el interno **después** de crear `Usuario`/`Estudiante`. El fallo se fuerza con una restricción `CHECK` temporal `CK_CULM001A_TMP_EG` sobre `EstudianteGrupo`, el patrón de `test_rec3_falla_intermedia_transaccion.sql` (`CK_REC3_TMP_*`), creada y eliminada dentro de la transacción del test; un usuario nuevo no tiene matrículas con las que provocar `HOR_001` → `estadoResultado = 0` y **0 filas nuevas** en `Usuario`, `Estudiante`, `EstudiantePrograma` y `EstudianteGrupo`; se ejecuta con `@@TRANCOUNT = 0` (sale en 0) y dentro de una transacción del test (sale en 1 y `XACT_STATE() = 1`). **T-12d:** error forzado dentro del SP nuevo bajo el QR con transacción externa del test: el llamador recibe `XACT_STATE() = -1` y `estadoResultado = 0`, y el test revierte | todos (`CULM001A_T12_TRANCOUNT`) |
| T-13 | RED | Esquema desplegado = `schema/` | Para U-7..U-10, `OBJECT_DEFINITION` coincide con el archivo (hash sin `GO`) | `test_migracion_13_culm001_a.ps1` |

`test_solicitud_ingreso_grupo.sql` (S-01..S-12) desaparece con la HU, porque prueba un flujo descartado. Ninguna otra prueba de BD se quita. CLOSURE informa el total de `TEST_PASS` antes y después.

### 2.7 Seeds y grants después del cambio

- Seeds que se borran: `22_estados_solicitud_ingreso_grupo.sql` (el estado `X` pasa al 33) y `23_mensajes_solicitud_ingreso_grupo.sql`. Seeds que se editan: `04_mensaje.sql` y `26_plantillas_notificacion.sql`. Seeds nuevos, con el número 33 de A: `33_culm001_a_catalogos.sql` y `33_culm001_a_mensajes.sql` (§8.3).
- Grants que se borran: `rol_asistencias_runtime_hu053_hu055.sql`. Grants sin cambio: `usp_consultar_oferta_grupos_estudiante` y `usp_registrar_estudiante_en_grupo` (`CREATE OR ALTER` los conserva). Sin permiso para el runtime: `usp_internal_reactivar_matricula_retirada` y las 4 `zz_archivo_*`. Los grants de A.2 van en `schema/security/rol_asistencias_runtime_culm001_a.sql` (§8.2).
- `test_runtime_grants_backend_inventory.sql` no menciona estos SP (verificado); los de A.2 sí se añaden (§8.2).

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

**Se borran (9)**, porque la HU se descarta: `BT/application/features/docente/consultarsolicitudesingreso/usecase/impl/ConsultarSolicitudesIngresoDocenteUseCaseImplTest.java`, `BT/application/features/docente/resolversolicitudingreso/usecase/impl/ResolverSolicitudIngresoUseCaseImplTest.java`, `BT/application/features/estudiante/consultarsolicitudesingreso/usecase/impl/ConsultarSolicitudesIngresoEstudianteUseCaseImplTest.java`, `BT/application/features/estudiante/retirarsolicitudingreso/usecase/impl/RetirarSolicitudIngresoUseCaseImplTest.java`, `BT/application/features/estudiante/solicitaringresogrupo/usecase/impl/SolicitarIngresoGrupoUseCaseImplTest.java`, `BT/infrastructure/adapter/primary/controller/docente/DocenteSolicitudIngresoControllerTest.java`, `BT/infrastructure/adapter/primary/controller/estudiante/EstudianteSolicitudIngresoControllerTest.java`, `BT/infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/SolicitudIngresoGrupoJpaRepositoryTest.java` y `BT/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifierSolicitudIngresoTest.java`.

**Se editan, sin relajar aserciones:**

| Archivo | Cambio |
| :--- | :--- |
| `BT/application/secondaryports/notification/CasosDeUsoEmisoresNotif002aDatosTest.java` | Quitar los 3 casos de solicitud (líneas ~78-195, incluido `BE_U01_U02_solicitud_ingreso_retirada`); se conservan los de retiro HU051 |
| `BT/infrastructure/adapter/primary/controller/coordinador/CoordinadorPortalControllerTest.java` | Líneas 172-174: los 4 stubs retirados salen de la lista de 501. `toggleEstadoPeriodoAcademico` también sale, porque A.2-14 lo retira; si la lista queda vacía, el caso se elimina. Se añade B-RED-03 |
| `BT/infrastructure/adapter/primary/controller/grupo/GrupoControllerWriteEndpointsTest.java` | El caso `delete(".../estudiantes/{estudianteId}")` (línea 289), que esperaba 501, se sustituye por B-RED-03 (sin ruta) |
| `BT/infrastructure/adapter/primary/security/RbacSecurityFilterChainTest.java` | `matricular_estudiante_coordinador_es_permitido_por_security_filter_chain` (420-425) pasa a `matricular_estudiante_coordinador_recibe_403`, con `isForbidden()`. Es un **cambio de expectativa por un cambio formal de regla (F-COO-004)**; la aserción es más estricta. DOCENTE 200 y ADMINISTRADOR 403 no cambian. El comentario de 410-411 se actualiza |
| `BT/infrastructure/adapter/secondary/notification/template/PlantillaRendererTest.java`, `PlantillaNotificacionJpaRepositoryTest.java`, `channel/smtp/SmtpNotificacionChannelSenderTest.java`, `channel/smtp/NotificacionSmtpGreenMailIT.java` | Usan `SOLICITUD_INGRESO_*` como dato de ejemplo (6, 3, 2 y 5 usos). Pasan a `RETIRO_ESTUDIANTE_GRUPO` con marcadores que existan en esa plantilla, y se mantienen las mismas aserciones de renderizado |
| `BT/infrastructure/adapter/secondary/persistence/sqlserver/jpa/JpaRepositoryBeanUniquenessTest.java` | `EXPECTED_REPOSITORIES` de 56 a **55**, con el comentario "CULM-001 A: − SolicitudIngresoGrupoJpaRepository". A.2 no añade `@Repository` nuevos: amplía los existentes |
| `BT/application/features/estudiante/consultarofertagrupos/ConsultarOfertaGruposUseCaseImplTest.java`, `BT/infrastructure/adapter/primary/controller/estudiante/EstudianteOfertaAcademicaControllerTest.java` | Quitar las aserciones de los 2 campos y construir proyecciones y DTO con 18 y 19 campos |
| `BT/infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/OfertaGruposEstudianteJpaRepositoryTest.java` | Fila simulada (línea 58) de 19 posiciones; OR01 y OR07 sin `idSolicitudAbierta` (93, 164); OR06 con columnas nulas en 19 posiciones; se añade B-RED-04 |
| `GestioAsistenciaBackend/src/test/resources/messageucolab/catalogo-mensajes-usuario.psv` | Quitar la línea 75 (`ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA`) y las 124-138 (`SIG_001..SIG_015`). Las filas que añade A.2 están en §8.3 |

**Pruebas nuevas.** RED falla hoy por la razón esperada; CAR es de caracterización.

| ID | Tipo | Archivo | Aserción |
| :--- | :--- | :--- | :--- |
| B-RED-01 | RED, ArchUnit | **Nuevo** `BT/architecture/SolicitudesIngresoRetiradasTest.java` | Ninguna clase importada de `co.edu.uco.asistenciasuco` tiene un nombre simple que coincida con `.*(SolicitudIngreso\|SolicitarIngreso\|SolicitudesIngreso).*`, ni vive en `..consultarsolicitudesingreso..`, `..resolversolicitudingreso..`, `..retirarsolicitudingreso..` o `..solicitaringresogrupo..`. `Notificacion` no declara campos `TIPO_SOLICITUD_INGRESO_*`. Aserción positiva: `SolicitudRevisionEstudianteJpaRepository` (reclamos) sigue existiendo, para no dar un falso verde |
| B-RED-02 | RED, recurso | idem | `getResource("notification/templates/SOLICITUD_INGRESO_*.es.properties")` es nulo para los 3 tipos |
| B-RED-03 | RED, inventario de rutas | `CoordinadorPortalControllerTest` y `GrupoControllerTest` | Por reflexión, como en `AdminPortalControllerTest.sedes_y_espacios_fisicos_retirados_no_tienen_ruta` (296-316): `CoordinadorPortalController` no tiene rutas que empiecen por `/solicitudes-matricula` ni `/grupos/{grupoId}/estudiantes`, y `GrupoController` no tiene `@DeleteMapping` |
| B-RED-04 | RED, contrato JPA de la oferta | `OfertaGruposEstudianteJpaRepositoryTest` | `OR08_fila_de_19_columnas_mapea_componente_en_17_y_total_en_18`: con valores distinguibles, `codigoComponente = "ESP"` sale de `f[17]` y `total` de `f[18]`. `OR09_fila_con_longitud_distinta_falla`: una fila de 21 posiciones hace que la guardia `COLUMNAS_OFERTA = 19` lance **`IllegalStateException`** (N3), que `JpaQueryExecutor.execute` (línea 36) envuelve; el test comprueba **`DatabaseOperationException` con causa `IllegalStateException`**. Con T-02 en BD fija el contrato posicional a los dos lados. Recomendado (N3): añadir la forma del resultset de la oferta a `SqlStoredProcedureContractIT` (`-Pintegration`) |
| B-RED-05 | RED, 404 HTTP con controladores reales (bloqueante 6) | **Nuevo** `BT/infrastructure/adapter/primary/controller/RutasSolicitudesRetiradasWebMvcTest.java` | `@WebMvcTest(useDefaultFilters = false, includeFilters = @ComponentScan.Filter(type = FilterType.REGEX, pattern = "co\\.edu\\.uco\\.asistenciasuco\\.infrastructure\\.adapter\\.primary\\.controller\\..*\\.(EstudianteSolicitudIngreso\|DocenteSolicitudIngreso\|CoordinadorPortal\|Grupo)Controller"))` con `@Import({GlobalExceptionHandler.class, <configuración de seguridad de prueba de RbacSecurityFilterChainTest>})`. El filtro va **por nombre**, no por clase, para que compile después de borrar los dos controladores. Las dependencias de los controladores incluidos se satisfacen **sin nombrar tipos que se borran** (N8): un `BeanFactoryPostProcessor` de prueba (`MocksParaControladoresIncluidosPostProcessor`) recorre los constructores de los beans `@RestController` registrados y, para cada parámetro sin bean, registra `Mockito.mock(tipo)` con `RETURNS_DEFAULTS` (las respuestas vacías bastan para obtener 200/201). Las rutas 501 no necesitan mocks. Así el RED falla por 200/201/501 y no porque el contexto no arranque. Con el token del rol que hoy tiene acceso, cada una de las 10 rutas de 3.1 debe responder **404** con `ApiErrorResponse` (`NoResourceFoundException`, `GlobalExceptionHandler:181`). **En RED falla de verdad:** hoy responden 200/201 (estudiante y docente, con los ports simulados) o 501 (stubs). En GREEN no hay que editar la prueba: el filtro por nombre ya no encuentra los controladores borrados y el post-procesador no tiene nada que simular. Sustituye al B-RED-05 de la versión 1, que estaba en `RbacSecurityFilterChainTest` y nunca podía fallar |
| B-RED-06 | RED, 403 del coordinador | `RbacSecurityFilterChainTest` | `POST /api/v1/grupos/{grupoId}/estudiantes` con COORDINADOR → 403 (fila de edición de arriba) |
| B-RED-07 | RED, consistencia del catálogo | `AccessCatalogConsistencyTest` (sin editar) | Pasa a verde solo si las 10 filas quitadas coinciden con los 10 handlers retirados y si la fila 155 (`["DOCENTE"]`) coincide con `SecurityConfig` |
| B-RED-08 | RED, DTO de la oferta | `EstudianteOfertaAcademicaControllerTest` | El JSON de `GET /api/v1/estudiante/oferta-academica` no tiene `idSolicitudAbierta` ni `estadoSolicitud` (`jsonPath("$.datos[0].idSolicitudAbierta").doesNotExist()`) y sí `tipoAsignatura` y `transversal` |
| B-RED-09 | RED, outbox de tipos retirados (N6) | `BT/infrastructure/adapter/secondary/notification/template/PlantillaPorDefectoCatalogoTest.java` (o el test del despachador que ya cubre tipos desconocidos) | Una notificación `SOLICITUD_INGRESO_REGISTRADA` reencolada por el administrador no se envía: el despachador registra el fallo definitivo (`usp_registrar_fallo_notificacion`) porque el tipo no está en `TIPOS_CONOCIDOS` |

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
| `F/features/attendance/attendance-control/components/group-sessions-overview.component.spec.ts` (línea 147) (bloqueante 4) | El selector `[data-testid="padron-solicitudes"]` pasa a `[data-testid="padron"]`. El nombre del caso (línea 143) pasa a 'HU051: el botón "Padrón" emite gestionarPadron'; se conserva la aserción `expect(emitido).toBeTrue()` |
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
| F-RED-04 | `F/core/services/coordinator-management.service.spec.ts` y `F/core/services/oferta-academica.service.spec.ts` | `expect('getSolicitudesMatricula' in service).toBeFalse()` (sin `any`, N9), y lo mismo para `crearSolicitudMatricula`, `resolverSolicitudMatricula`, `matricularEstudianteGrupo` y `retirarEstudianteGrupo`. La oferta mapeada no tiene las claves `idSolicitudAbierta` ni `estadoSolicitud` |
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
| `scripts/tests/test_all_hus.ps1` | 381, `Run-Test "HU043,HU055"` (prueba `usp_crear_grupo`) | **Se conserva la prueba**; la etiqueta pasa a `"HU043"`. Cuerpo y aserciones sin cambios |
| `scripts/tests/test_all_hus.ps1` | **419-424, `Run-Test "HU051"` (bloqueante 4)**: llama a `DELETE /grupos/{id}/estudiantes/F1A2B3C4-0000-0000-0000-000000000005`, el stub que se retira (hoy 501, después 404) | HU051 sigue viva. La llamada pasa a `POST $BASE/docente/grupos/$($script:tempGrupoDocId)/estudiantes/F1A2B3C4-0000-0000-0000-000000000005/retiro` con cuerpo `@{ motivo = "Retiro E2E CULM-001 A" } \| ConvertTo-Json` y `-ContentType "application/json"`, con el token docente. Se conservan las aserciones (`if (-not $res.exitoso) { throw ... }`) y el mensaje de éxito. El estudiante debe estar matriculado por HU050 (409-417) en ese grupo temporal; si HU050 matricula a otro documento, se usa el `idEstudiante` que devuelve HU050 |
| `scripts/quality/test-e2e-hus.ps1` | 248-256, `Run-TestItem "HU026"` | Se elimina |
| `scripts/quality/test-e2e-hus.ps1` | 364, `Run-TestItem "HU043,HU055"` | Etiqueta a `"HU043"`; cuerpo igual |
| `scripts/quality/test-e2e-hus.ps1` | 258-263, `Run-TestItem "HU010-Anular"` (`DELETE /estudiante/reclamos/{id}`) | Se conserva sin cambios: A.2-7 implementa la ruta |
| `scripts/tests/test_all_hus.ps1` | 409-417, `Run-Test "HU050"` (docente sobre su grupo temporal) | Sin cambios; debe seguir en PASS con E-04 porque el ejecutor es el titular |
| `scripts/tests/test_all_hus.ps1` | Nuevo `Run-Test "F-COO-004"` | `POST /grupos/{grupoDocente}/estudiantes` con el token del coordinador → **403**; si responde 2xx o 400, falla |

No se relaja ni se elimina ninguna otra prueba. CLOSURE compara contra la línea base (21 PASS / 52 FAIL) y reporta aparte las pruebas que desaparecen con las HU descartadas.

### 5.4 Otros

- `docs/work-items/INDEX.md`: registrar `CULM-001/paquetes/A-retiro-solicitudes`.
- `docs/work-items/CULM-001-culminacion/SCREEN-TESTS-estudiante.md` (sección 5, 45-47): actualizar tras el retiro.
- `docs/work-items/backend/REG-000-programa-registro-vinculacion-roles/PLAN.md` (62, 77) y `docs/work-items/backend/LB-002-jpa-incremental/LB-002.1C-B2-DECISION.md`: anotar "descartado en CULM-001 A".
- **Fuera de Git (solo anotar en CLOSURE):** `C:\Proyectos\GestionAsistencia\docs\rutas-por-rol.md`, líneas 58-59 (`/coordinador/grupos/{grupoId}/estudiantes` POST/DELETE), 74-75 (`/coordinador/solicitudes-matricula`), 85 (`DELETE /grupos/{grupoId}/estudiantes/{estudianteId}`), 116 (`POST /grupos/{grupoId}/estudiantes`, rol) y 144 (`POST /estudiante/solicitudes-matricula`, que además atribuye mal la clase a `EstudiantePortalController`).

---

## 6. Orden de integración, ramas y commits

### 6.1 Ramas y destino

Rama `feature/CULM-001-A-retiro-solicitudes` en cada repo, desde `integracion/CULM-001`, con PR hacia `integracion/CULM-001`. **A.1 (secciones 2-5) y A.2 (sección 8) van en la misma rama**, en ese orden. Según DEC-002, los PR de DB y Backend se abren en `johnjduque/gestion-asistencia-db` y `alejovh12/AsistenciasUCO`; los de Frontend e Infra, en sus `origin`.

### 6.2 Orden

1. **DB A.1:** RED → GREEN → migración `13_culm001_a_retiro_solicitudes_*` → limpieza de `schema/`. Backup COPY_ONLY nuevo, `deploy_schema.ps1` y `up` en la BD local. `infra.ps1 db-test` sin fallos nuevos y `test_migracion_13_culm001_a.ps1` sobre la base clonada (compuerta manual, N7).
2. **DB A.2:** RED → GREEN → `14_culm001_a_correcciones_fase1_*` (§8.2). `db-test` **verde** (F-000, A.2-12) y `culm1_segundo_ambito.sql` aplicado en local.
3. **Backend A.1 → A.2:** contra la BD ya migrada. `mvnw verify`, rebuild y reinicio con `start-backend-baseline.ps1` y `APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=sqlserver` en el `.env` del worktree (DEC-018). Comprobación con `curl`: las rutas retiradas responden 404; la matriz de ámbito del segundo programa, 403/404 sin datos; sin 500 en `/configuracion/*` ni en la matrícula QR.
4. **Frontend A.1 → A.2:** `npm run verify` y recorrido en pantalla por rol.
5. **Infra:** catálogo, hoja de ruta, suites E2E, `test-summary.ps1` (F-000), `test_all_hus.ps1` e `infra.ps1 verify`.

La BD y el backend se despliegan **juntos** (riesgo R-2).

### 6.3 Commits atómicos de A.1

Todos en español, en imperativo, de 72 caracteres o menos (N1, comprobado con `awk '{ print length }'`), con cuerpo (qué, por qué y cómo), pie `Refs: CULM-001` más las HU, y `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

**GestioAsistenciaDB**
1. `test(db/sp): agregar pruebas red del retiro de solicitudes de ingreso` (T-01..T-13, E-11..E-16 y el script de T-10). Refs: HU008, HU050, HU176B, HU053, HU054, HU055.
2. `feat(db/sp): reactivar matricula retirada en matricula manual y qr` (E-02, E-03, E-08; DEC-009). Refs: HU050, HU176B.
3. `fix(db/sp): exigir docente titular y transaccion en matricula manual` (E-04, E-15; F-COO-004 y bloqueante 1). Refs: HU050.
4. `refactor(db/sp): quitar columnas de solicitud de la oferta de grupos` (E-01). Pie: `BREAKING CHANGE: el resultset pasa de 21 a 19 columnas`.
5. `feat(db/migrations): agregar migracion 13 de retiro de solicitudes` (`13_culm001_a_retiro_solicitudes_up/down.sql`; DEC-010).
6. `chore(db/tables): eliminar tabla, sp, grants y seeds de solicitudes` (D-01..D-12, E-05..E-07, E-09, E-10). Refs: HU053, HU054, HU055.
7. `docs(db): actualizar fichas e inventario tras el retiro de solicitudes`.

**GestioAsistenciaBackend**
1. `test(backend): agregar pruebas red del retiro de solicitudes de ingreso` (B-RED-01..09 y los ajustes de expectativa de 3.6).
2. `refactor(backend/adapter): reindexar el mapeo posicional de la oferta`. Pie: `BREAKING CHANGE: oferta-academica sin idSolicitudAbierta ni estadoSolicitud`. Refs: HU008.
3. `refactor(backend/controller): retirar endpoints de solicitudes ingreso` (los 49 `.java`, el wiring y `access-catalog.json`). Pie: `BREAKING CHANGE: se eliminan 10 rutas (404)`. Refs: HU026, HU053, HU054, HU055.
4. `fix(backend/security): restringir la matricula de grupo al rol docente` (`SecurityConfig`, fila 155, stubs del coordinador y `DELETE /grupos/...`; F-COO-004). Refs: HU050.
5. `chore(backend): retirar plantillas y codigos sig de solicitudes`.
6. `docs(backend): actualizar matriz http y linea base tras el retiro`.

**GestioAsistenciaFrontend**
1. `test(frontend): agregar specs red del retiro de solicitudes de ingreso` (F-RED-01..08).
2. `refactor(frontend/estudiante): quitar solicitar ingreso de la oferta`. Refs: HU008.
3. `refactor(frontend/estudiante): eliminar pantalla de solicitudes` (rutas, menú, pantalla, servicio, `student-course-enroll-form` y código muerto). Refs: HU026, HU053.
4. `refactor(frontend/docente): eliminar la bandeja de solicitudes del hub` (hub, `teacher-grupos`, botón "Padrón", mensaje del 409 y su spec). Refs: HU054, HU055.
5. `refactor(frontend/coordinador): quitar solicitudes y matricula` (servicio, `coordinator-students` y modelo; F-COO-004, F-COO-012).
6. `chore(frontend): limpiar mocks y plantillas de solicitudes de ingreso`.
7. `docs(frontend): actualizar mapa de componentes y contrato front-back`.

**AsistenciasUCO-Infra**
1. `docs(hus): descartar HU026, HU053, HU054 y HU055 en el catalogo`.
2. `docs(roles): quitar solicitudes de ingreso de la hoja de ruta`.
3. `test(scripts): retirar pruebas e2e de HU026, HU053 y HU054` (más la prueba 403 F-COO-004, las etiquetas `HU043` y HU051 redirigida).
4. `docs(work-items): registrar el paquete A de CULM-001`.

Los commits de A.2 están en §8.8.

---

## 7. Riesgos y rollback

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| R-1 | **Pérdida de historial, outbox o plantillas.** `DROP TABLE` y `DELETE` de plantillas | DEC-010: cuatro tablas de archivo (U-1), guardias U-3, `down` tolerante (R-5, R-7, R-8) que solo se detiene si faltan solicitudes, y backup COPY_ONLY antes de aplicar. T-10 y T-11 lo prueban con versión 2, reserva vencida, fila depurada y fila reintentada |
| R-2 | **Mapeo posicional de la oferta** (de 21 a 19 columnas) | Despliegue conjunto; T-02 y B-RED-04 fijan el contrato posicional; `COLUMNAS_OFERTA = 19` lanza `IllegalStateException`, que llega como `DatabaseOperationException` visible (N3) |
| R-3 | **Concurrencia en la reactivación** | La regla 5 bloquea `Grupo` y la fila `I` con `UPDLOCK, HOLDLOCK` solo cuando hay una fila retirada (N4); T-12b. Caso "dos reactivaciones con 1 cupo" en la prueba de concurrencia QR de la Fase 3 |
| R-4 | **Errores del SP nuevo dentro de una transacción externa** (corregido por N12) | El `CATCH` del interno (`usp_registrar_estudiante_en_grupo_interno:152-160`) atrapa el error del SP nuevo y **no** lo relanza: devuelve `@estadoResultado = 0`. Con `XACT_STATE() = 1`, el llamador público revierte su savepoint (`sp_hu176b_negocio` en QR, `sp_registrar_estudiante_negocio` en manual, E-04). Con `XACT_STATE() = -1`, el PASO 5 del QR (255-260) y el cierre de E-04 hacen `ROLLBACK` **solo con transacción propia**; si la transacción es de un llamador externo, vuelve no confirmable y la revierte ese llamador. T-12c y T-12d lo fijan |
| R-5 | **F-COO-004 cambia un comportamiento certificado** | Es la regla de producto; RbacSecurityFilterChainTest, T-08, T-09 y la prueba E2E nueva lo fijan. Se comunica en el PR |
| R-6 | **Notificación en vuelo** (`RESERVADA` vigente) durante el `up` | U-0 aborta; se aplica con el backend detenido. Las reservas vencidas se archivan y el `down` las devuelve como `PENDIENTE` (R-8) |
| R-7 | **PDP del laboratorio desalineado** con `access-catalog.json` hasta aprobar `--prune` | Las filas sobrantes del PDP solo afectan a rutas que ya dan 404. Queda pendiente en `PRS.md` |
| R-8 | **Cruce de horario con matrículas `I` de otros grupos** (defecto previo) | Fuera de alcance; se registra como hallazgo para el paquete D |
| R-9 | **Texto local del 409 en el frontend** (A-C5) | Deuda en `TECHNICAL_DEBT.md` de Infra: pasar a `messages:user:ERR_MATRICULA_DUPLICADA` con un texto para el docente |
| R-10 | **Borrado de `E` en `dbo.Estado`** (catálogo de solo consulta, CAT-01) | Por migración; U-6 comprueba las FK hacia `Estado`; R-3 lo restaura. `X` se conserva para A.2-7 |
| R-11 | **Grep ciego por "solicitud"** que borre reclamos | Inventario por archivo, la aserción positiva de B-RED-01 y F-RED-08 limitado a los identificadores de ingreso |
| R-12 | **Dos fuentes del código `I`** (N5): `MATRICULA/ESTADO_RETIRADA` y el literal `'I'` de `usp_retirar_estudiante_grupo.sql:41` | Deuda **TD-CULM001-A-01** en `AsistenciasUCO-Infra/docs/baseline/TECHNICAL_DEBT.md`: que el retiro lea el mismo parámetro. No se cambia aquí, para no tocar HU051 certificada fuera del alcance |
| R-13 | **Claves de mensajes en Azure App Configuration** (N8): `messages:user:SIG_*`/`messages:technical:SIG_*` y `ERR_SOLICITUD_MATRICULA_NO_IMPLEMENTADA` quedan huérfanas; faltan las claves nuevas de A.2 (§8.3) | Pendiente operativo en `PRS.md` y en CLOSURE (sin acceso a Azure desde el laboratorio, DEC-018), igual que el `--prune` del PDP. MessageUcoLab se regenera con `components/messages/build-message-catalog.py` |

### Rollback

1. Revertir los PR en orden inverso (Infra → Frontend → Backend → DB) en `integracion/CULM-001`.
2. Detener el backend; aplicar `14_culm001_a_correcciones_fase1_down.sql` y después `13_culm001_a_retiro_solicitudes_down.sql`. El `down` de A.1 solo falla si hay solicitudes archivadas sin restaurar (`THROW 53310`); en ese caso se corrige el dato y se vuelve a ejecutar. El backup COPY_ONLY es el último recurso, porque pierde lo escrito después del `up`.
3. Desplegar el `schema/` de develop (`65a4998`) con `deploy_schema.ps1`.
4. Arrancar el backend de `72a1675e` y el frontend de `886a01b`.
5. Comprobar con `db-test`, `mvnw verify` y `npm run verify`, y que las rutas de solicitud vuelven a responder 200.
6. Reprovisionar el PDP con el `access-catalog.json` de develop.

---

## 8. A.2 Correcciones críticas y altas de la Fase 1

Fuente: `CORRECCIONES-A.md` (triage del orquestador), DEC-022 y DEC-018, `FINDINGS-*.md` y `MATRIZ-AMBITO.md`. Los nombres de los SP de consulta con ámbito los fijó el orquestador, en coordinación con B2, que los reutiliza. Las causas raíz de los 500 se comprobaron en `GestioAsistenciaBackend/infra/observability/logs/asistencias-uco.jsonl` por `correlationId`. Prefijos de prueba: **A2-T** (BD), **A2-B** (backend), **A2-F** (frontend).

### 8.1 Alcance, decisiones y contratos

| Ítem | Hallazgos | Severidad | Capas |
| :--- | :--- | :--- | :--- |
| A.2-1 Directorio de estudiantes con ámbito en SP | F-COO-001, F-COO-002, F-DOC-013 | crítica | DB + Backend |
| A.2-2 Grupos, estudiantes y asistencias del grupo con ámbito | F-COO-003 | alta | DB + Backend |
| A.2-3 El administrador sale de `coordinador/*` y `decano/*` | F-TRX-018 (DEC-022 §2) | media → A | Backend + Infra |
| A.2-4 Límite de intentos en subida de archivos y asistencia por QR | F-TRX-003 | alta | DB (seed) + Backend |
| A.2-5 Rutas públicas de matrícula QR alcanzables sin token | F-EST-019 | alta | Backend + entorno |
| A.2-6 Sin 500: parámetros (DEC-018), errores sin clasificar y validación | F-EST-018, F-DOC-015, F-DOC-016, F-TRX-017 | alta | Backend + entorno |
| A.2-7 Retiro del reclamo propio pendiente | F-EST-003 | alta | DB + Backend + Frontend |
| A.2-8 Cambio de estado del decano | F-ADM-002 | alta | DB + Backend + Frontend |
| A.2-9 Traducción de errores de consulta a 403/404/400/409 | F-TRX-017, DEC-022 §5 | alta | Backend |
| A.2-10 Sesiones solapadas | F-DOC-017 | alta | DB + Backend |
| A.2-11 Solo la matrícula `A` cuenta como inscrita | F-EST-S01, F-EST-020 (DEC-022 §3) | alta | DB + Backend |
| A.2-12 Compuerta `db-test` en verde | F-000 | alta | DB + Infra |
| A.2-13 Fixture del segundo ámbito | F-TRX-008, F-DEC-011 | alta | DB (test) |
| A.2-14 Retiro de stubs 501 expuestos | F-COO-005, F-EST-004, F-TRX-004 (resto, DEC-022 §8) | alta/media | Backend + Frontend |
| A.2-15 Búsqueda del estudiante a matricular por documento exacto (DEC-027) | F-DOC-013, A2-C1 | crítica | DB + Backend + Frontend + Infra (golden path 1.2.0 con B) |

Fuera de A (ya asignados): F-EST-002, F-EST-017, F-DOC-002, F-TRX-002 → B; F-EST-S05, F-TRX-005, F-TRX-006 → C; F-ADM-003, F-ADM-004, F-ADM-022 → D; F-EST-S03 y UX → E. Del resto de F-TRX-004: `GET /sesiones/{id}/qr-token`, `PATCH /docente/sesiones/{id}/cancelar` y `POST /asistencias` → B; `PUT /admin/parametros/{id}` → D.

**Concreciones de A.2 (para el revisor):**

| ID | Concreción | Motivo |
| :--- | :--- | :--- |
| A2-C1 (DEC-027) | `GET /api/v1/estudiantes` y `/{id}` **mantienen DOCENTE**, con el ámbito del SP (solo estudiantes de sus grupos). La búsqueda del modal de matrícula manual pasa a un endpoint propio del docente, `GET /api/v1/grupos/{grupoId}/estudiantes/busqueda` (A.2-15: titularidad en el SP, documento exacto, datos mínimos, sin listar). El `x-roles` de `/api/v1/estudiantes` en `openapi-golden-path.yaml:184` se **recongela con DOCENTE en el golden path 1.2.0** (DEC-030), y **lo ejecuta el paquete B** al congelar 1.2.0: edita `openapi-golden-path.yaml` y `BACKEND_GOLDEN_PATH_CONTRACT.md`, regenera los `.sha256` en Infra y en Backend en el mismo commit, actualiza las pruebas de conformidad OpenAPI del backend y pasa `infra.ps1 verify`. A **no** edita archivos congelados. Si A llega a `develop` antes que B, la diferencia previa (el código ya admite DOCENTE) dura hasta 1.2.0; no se registra como deuda | Ya no queda decisión pendiente: DEC-027 opción (b) |
| A2-C2 | En `GET /grupos/{id}/estudiantes` y `/asistencias`, un grupo inexistente o fuera de ámbito responde **403** (no 404) | Instrucción del orquestador, coherente con `BACKEND_GOLDEN_PATH_CONTRACT.md` §A ("titularidad ajena: 403") y con la respuesta `'403'` ya declarada en el OpenAPI |
| A2-C3 | Los SP de grupo aceptan `@tamanoPagina = NULL`, que significa "todas las filas", y el backend lo usa | El contrato WORM fija listas completas, sin `page/size` (DR-010, `BACKEND_GOLDEN_PATH_CONTRACT.md` §C 3-4). La paginación existe en el SP para B2 y otros consumidores. **Solo estos dos SP** aceptan `NULL` sin límite (N10): los demás SP paginados siguen acotando el tamaño a 1..100, y A2-T-06b lo prueba con `usp_consultar_directorio_estudiantes_paginado` y `usp_consultar_grupos_paginado` |
| A2-C4 | El reclamo retirado usa el estado `X` "retirada" de `dbo.Estado`, que A.1 conserva | Evita crear un estado nuevo en un catálogo de solo consulta (CAT-01) y reutiliza un id fijo ya sembrado |
| A2-C5 | `Decano` gana la columna `estado BIT NOT NULL DEFAULT 1`, el mismo patrón que `Coordinador` (HU121/HU122, migración 05) | El decano no tiene estado propio; `uv_decano.estaActivoDecano` se calcula desde el usuario y la facultad |
| A2-C6 | No se añade un comodín `/api/v1/public/**` al PEP | Ver A.2-5: la causa raíz no es el PEP; `SecurityPublicEndpoints.pepExempt()` ya excluye las 3 rutas públicas y `SecurityConfig:104-108` prohíbe el comodín de forma explícita (mínimo privilegio) |

**Contratos WORM en A.2: sin cambio de archivo congelado ni de `.sha256`.** Endpoints WORM afectados y cómo se preserva cada uno:
- `GET /api/v1/estudiantes`: se conservan parámetros, validaciones (`page` desde 0, `size` 1..100, 400), forma `EstudiantePagina` (`items, totalItems, totalPages, page, size`, sin envoltorio), orden fijo y semántica de filtros. El SP lee `uv_estudiante_identidad`, `uv_usuario` y `EXISTS` sobre `uv_estudiante`, como dice la descripción. Cambia **qué filas** ve cada rol, dentro del 200/403 declarado. `x-roles` se recongela con DOCENTE en 1.2.0, ejecutado por B (A2-C1, DEC-027, DEC-030). La ruta nueva `/grupos/{grupoId}/estudiantes/busqueda` **no** pertenece al golden path.
- `GET /api/v1/grupos/{grupoId}/estudiantes` y `/asistencias` (#3 y #4): mismos roles, mismos DTO y listas completas (A2-C3); el 403 por ámbito ya está declarado.
- `POST /api/v1/sesiones`, `PATCH`/`PUT /api/v1/sesiones/{id}` y `POST /api/v2/sesiones`: el solape responde **400** `VALIDATION_ERROR` (como `SES_004`), porque el OpenAPI de esas operaciones declara 400 y no 409. **Nota para la próxima revisión formal:** la tabla §G de `BACKEND_GOLDEN_PATH_CONTRACT.md` enumera los orígenes de `VALIDATION_ERROR` y no incluirá `SES_017`; se anota en CLOSURE, sin re-congelar en A.
- `usp_crear_sesion`, `usp_actualizar_sesion` y `usp_generar_sesiones_grupo` (manifiesto de BD): **no se editan**; la validación va en los internos no congelados.

### 8.2 Base de datos (A.2)

Migración `migrations/14_culm001_a_correcciones_fase1_up.sql` / `_down.sql`, con el mismo estilo que 2.4/2.5: lotes idempotentes, `CREATE OR ALTER` copiado de `schema/` y comprobado por T-13 ampliado. Grants nuevos en `schema/security/rol_asistencias_runtime_culm001_a.sql`: `GRANT EXECUTE` al runtime de cada SP **público** nuevo, con guardia `THROW` si falta el SP (patrón del archivo de grants borrado). Ninguno para los `usp_*_interno`. Los SP públicos de consulta nuevos se añaden a las listas de excepción `READ_QUERY_RESULTSET` de `test_contract_closure.sql` (252, 271, 292) y a `test_runtime_grants_backend_inventory.sql`.

#### 8.2.1 `usp_consultar_directorio_estudiantes_paginado` (A.2-1)

```text
(@idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER,
 @idEstudiante UNIQUEIDENTIFIER = NULL,                       -- modo detalle
 @idTipoIdentificacion UNIQUEIDENTIFIER = NULL, @numeroIdentificacion INT = NULL,
 @nombre NVARCHAR(100) = NULL, @correo NVARCHAR(100) = NULL,
 @idInstitucion UNIQUEIDENTIFIER = NULL, @idFacultad UNIQUEIDENTIFIER = NULL,
 @idPrograma UNIQUEIDENTIFIER = NULL, @idGrupo UNIQUEIDENTIFIER = NULL, @activo BIT = NULL,
 @numeroPagina INT = 1, @tamanoPagina INT = 20)
```
- Clasificación `READ_QUERY_RESULTSET`. `SET NOCOUNT ON; SET XACT_ABORT ON`. Ejecutor nulo → `THROW 51000` con `VAL_001` (patrón de `usp_consultar_oferta_grupos_estudiante` 63-77). Paginación protegida: página ≥ 1 y tamaño entre 1 y 100.
- **Ámbito dentro del SP** (CTE `ambito(idEstudiante)`; un usuario con varios roles recibe la **unión**):
  - ADMINISTRADOR (`Administrador.usuario = ejecutor`): **solo la institución del ejecutor** (DEC-031 §3, N4). Son los estudiantes con `EstudiantePrograma` en un programa de su institución (programa → facultad → `institucion`) o con `EstudianteGrupo` en un grupo de su institución; así se ven también los que no tienen `EstudiantePrograma` pero sí matrícula. Un estudiante **sin ningún vínculo** (ni programa ni grupo) no tiene institución resoluble y **no aparece** (fail-closed: no hay fuga entre instituciones). Se añade una fila a la matriz de la Fase 3: un administrador de otra institución no ve a los estudiantes del fixture del segundo ámbito.
  - COORDINADOR (`Coordinador.usuario = ejecutor` y `Coordinador.estado = 1`): estudiantes con `EstudiantePrograma.programa` en algún `Programa` con `coordinador = <su id>`.
  - DOCENTE (`Docente.usuario = ejecutor`): estudiantes con alguna `EstudianteGrupo` (en cualquier estado, porque es el padrón histórico) en un grupo con `docente = <su id>`.
  - Cualquier otro rol (DECANO, ESTUDIANTE): ámbito vacío. Fuera de ámbito: **en el listado la fila no aparece; en el detalle hay 0 filas**, que el backend convierte en **404**.
- Filtros con la semántica del OpenAPI: igualdad para tipo y número; `nombre` con `LIKE` sobre `UPPER(nombreCompleto)` y `correo` con `LIKE` sobre `LOWER(correo)`, ambos escapando `%`, `_` y `\`; los académicos con `EXISTS` sobre `uv_estudiante`. Los filtros **solo restringen dentro del ámbito**: un `programaId` ajeno da 0 filas.
- Resultset (listado): `id, idUsuario, tipoIdentificacionId, numeroIdentificacion, primerApellido, segundoApellido, primerNombre, segundoNombre, nombreCompleto, correo, estaActivoUsuario, totalRegistros`. Orden: `primerApellido, primerNombre, numeroIdentificacion, id`. En modo detalle, las mismas 11 columnas más las de contexto que hoy lee `EstudianteJpaRepository.HQL_CONTEXTOS` desde `uv_estudiante` (institución, facultad, programa, plan, asignatura y grupo, con id y nombre), **limitadas al ámbito del ejecutor**: una fila por contexto, o una sola con contexto NULL si no tiene ninguno visible.

#### 8.2.2 `usp_consultar_estudiantes_grupo_ambito_paginado` y `usp_consultar_asistencias_grupo_ambito_paginado` (A.2-2)

```text
usp_consultar_estudiantes_grupo_ambito_paginado
 (@idGrupo UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER, @idCorrelacion UNIQUEIDENTIFIER,
  @numeroPagina INT = 1, @tamanoPagina INT = NULL)          -- NULL = todas (A2-C3)
 -> id, idEstudiante, documento, nombreCompleto, correo, codigoEstado, nombreEstado, totalRegistros
usp_consultar_asistencias_grupo_ambito_paginado
 (@idGrupo UNIQUEIDENTIFIER, @idSesion UNIQUEIDENTIFIER = NULL, @idUsuarioEjecutor UNIQUEIDENTIFIER,
  @idCorrelacion UNIQUEIDENTIFIER, @numeroPagina INT = 1, @tamanoPagina INT = NULL)
 -> asistencia, estudiante, grupo, sesion, presente, estado, observacion, totalRegistros
```
- Las columnas son las de `EstudianteGrupoDTO` y `AsistenciaConsultadaDTO` (`BACKEND_GOLDEN_PATH_CONTRACT.md` §C 3-4). Estudiantes en **todos los estados** (DR-007). Asistencias con `INNER JOIN` desde `uv_detalle_asistencia`/`uv_asistencia` (vistas congeladas, solo lectura; "ausencia = sin fila", §E). Mismo filtro opcional de sesión que el HQL actual.
- Ámbito del grupo, validado **antes** de leer filas: DOCENTE titular (`Grupo.docente`); COORDINADOR activo del programa del grupo (asignatura → semestre → plan → programa → `coordinador`), que **dentro del grupo solo ve a los estudiantes, y sus asistencias, con `EstudiantePrograma` en alguno de sus programas** (DEC-031 §4, que aplica ya la regla DEC-020; N5). B2 completa la relación N:M con `ufn_estudiantes_grupo_visibles` sobre los mismos SP. DOCENTE titular y ADMINISTRADOR ven a todos; ADMINISTRADOR de la institución del grupo (facultad → institución). Grupo inexistente o fuera de ámbito → `THROW 51000` con el mensaje técnico de `usp_obtener_mensaje_catalogo 'SEC_002'`, que incluye el marcador `DBCODE=SEC_002|...` (`usp_obtener_mensaje_catalogo.sql:71`) → **403** (A.2-9, A2-C2).
- `GET /api/v1/grupos` (listado) **reutiliza** `usp_consultar_grupos_paginado`, que ya existe, ya aplica ámbito por `uv_auth_grupo`/`SESSION_CONTEXT` y devuelve las columnas de `GrupoDTO`. El adaptador lo pagina de 100 en 100 hasta `totalRegistros` para conservar la lista completa. Sin cambios de BD.

#### 8.2.3 Otros objetos de A.2

| # | Objeto | Contrato |
| :--- | :--- | :--- |
| A2-DB-1 | **Nuevos** `usp_consultar_materias_estudiante (@idUsuarioEjecutor, @idCorrelacion)` y `usp_consultar_horario_estudiante (@idUsuarioEjecutor, @idCorrelacion)` (A.2-11) | El estudiante sale del ejecutor (`Estudiante.usuario`); sin estudiante, 0 filas. **Solo matrículas con `codigo = ufn_obtener_parametro('MATRICULA','ESTADO_INSCRITA')`**: `I`, `CI`, `CVP` y `F` no aparecen. Columnas: las de `MateriaEstudianteQueryRow` (`idAsignatura, nombreAsignatura, idGrupo, nombreGrupo`) y las de `uv_horario_estudiante` que lee `HorarioEstudianteJpaRepository`. Hoy la vista no filtra por estado (`uv_horario_estudiante.sql:24`). La vista no se cambia: el filtro va en el SP |
| A2-DB-2 | **Nuevo** `usp_validar_solape_sesion_interno (@idGrupo, @idSesionExcluir UNIQUEIDENTIFIER = NULL, @fechaHoraInicio DATETIME2, @fechaHoraFin DATETIME2, @idCorrelacion, OUTPUT x3)` (A.2-10) | Rechaza con `SES_017` si existe una `Sesion s` con `s.fechaHoraInicio < @fechaHoraFin AND s.fechaHoraFin > @fechaHoraInicio` (los bordes iguales **no** solapan) y `s.id <> @idSesionExcluir`, que esté en **el mismo grupo** o en **otro grupo del mismo docente** (`Grupo.docente` del grupo). Lee con `WITH (UPDLOCK, HOLDLOCK)` sobre las sesiones de los grupos del docente para serializar creaciones concurrentes. Lo llaman `usp_crear_sesion_interno` (dentro de la transacción abierta en 104-109, antes del `INSERT`) y `usp_actualizar_sesion_interno` (después de la titularidad, 77-88, con `@idSesionExcluir` = la sesión) **solo si cambian `fechaHoraInicio`, `fechaHoraFin` o el grupo** respecto de la fila guardada (N6): una sesión con un solape heredado puede seguir cambiando de nombre. En RED se informa en `VALIDATION.md` cuántos solapes hay hoy en la semilla (consulta de pares de sesiones del mismo docente con intervalos que se cruzan). **Los SP públicos congelados no se tocan.** Cuando B introduzca `SesionCancelacion` (DEC-016), deberá excluir las sesiones canceladas; queda anotado para B |
| A2-DB-3 | **Nuevo** `usp_retirar_solicitud_revision_asistencia (@idSolicitudRevision, @idCorrelacion, @idUsuarioEjecutor)` (A.2-7) | Comando con el resultset canónico de 4 columnas. `SET XACT_ABORT ON`, transacción propia o savepoint, `CATCH` con `IF @@TRANCOUNT > 0 ROLLBACK`. RBAC `ESTUDIANTE` (`usp_validar_permiso_rbac_usuario_interno`). Ámbito dentro del SP: el reclamo debe ser del ejecutor (`asistencia → EstudianteGrupo → Estudiante.usuario`); si no existe o es ajeno, `REV_006` (404, sin revelar que existe). Bajo `UPDLOCK, HOLDLOCK`, su estado debe ser el código de `RECLAMO/ESTADO_PENDIENTE` (`P`); si no, `REV_007` (409; un segundo retiro también da `REV_007`). `UPDATE estado` al id de `RECLAMO/ESTADO_RETIRADO` (`X`, A2-C4). Éxito `REV_008`. El soporte (`ArchivoSoporte`) se conserva, porque el almacenamiento WORM y la auditoría lo exigen. Sin notificación: la opción "notificación opcional" de CORRECCIONES-A queda en no. **Consumidores del estado nuevo:** los mappers `ConsultarReclamosEstudianteMapper:68` y `ConsultarReclamosDocenteMapper:84` y los dominios `ConsultarReclamos*Domain:19` añaden `X → RETIRADA`. Las consultas del docente (`usp_consultar_solicitudes_revision_docente`) y los KPI de reclamos se revisan en RED (A2-T-11) para que un `X` no cuente como pendiente ni como resuelto |
| A2-DB-4 | `Decano` + **nuevo** `usp_cambiar_estado_decano (@idDecano, @estaActivo BIT = NULL, @idCorrelacion, @idUsuarioEjecutor)` (A.2-8) | En `schema/tables/Decano.sql`: `IF COL_LENGTH('dbo.Decano','estado') IS NULL ALTER TABLE dbo.Decano ADD estado BIT NOT NULL CONSTRAINT DF_Decano_estado DEFAULT (1)` (A2-C5; también en la migración). `uv_decano.estaActivoDecano` y `estaActivoTextoDecano` (líneas 22-23) suman `AND d.estado = 1`. **RBAC (bloqueante 4):** la rama Decano de `schema/views/uv_usuario_perfil.sql` (líneas 22-30) añade `WHERE d.estado = 1`, con el mismo comentario que la del coordinador ("-- CULM-001 A.2 (D1, como HU121/HU122): un rol de decano inactivo deja de figurar como perfil (RBAC y roles activos)"), en `schema/` y en la migración 14. El `down` restaura la vista sin el filtro. Como `usp_validar_permiso_rbac_usuario_interno` resuelve el perfil con esta vista, un decano desactivado deja de pasar el RBAC `DECANO` aunque su usuario siga activo por otro rol. El SP replica `usp_cambiar_estado_coordinador`: RBAC `ADMINISTRADOR`; ámbito de institución dentro del SP (la facultad del decano es de la institución del administrador; si no, `DEC_001`, 404); `@estaActivo NULL` invierte el estado actual (la ruta es un *toggle*); **regla `DEC_002` (409):** no se desactiva al decano de una facultad con algún `Programa.estado = 1`; `personaSinRolesActivos` se calcula **después** del `UPDATE` de `Decano.estado`, con la vista ya filtrada; `Usuario.estado` pasa a 0 solo si la persona no tiene otro rol activo (regla D1 del coordinador) y vuelve a 1 al reactivar. Idempotente. Resultset canónico más `idUsuario`, `personaSinRolesActivos` y `estaActivoDecano`, para que el backend sincronice la identidad |
| A2-DB-5 | `33_culm001_a_catalogos.sql` (A.2, se suma a E-08) | Parámetros (valor = valor por defecto en código, DEC-018): `ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO = 10`, `ASISTENCIA_QR/LIMITE_IP_POR_MINUTO = 20`, `ASISTENCIA_QR/LIMITE_ESTUDIANTE_POR_MINUTO = 5`, `RECLAMO/ESTADO_PENDIENTE = P`, `RECLAMO/ESTADO_RETIRADO = X`. Los valores de límite son una propuesta y el responsable puede ajustarlos (se administran en `GET /admin/parametros`) |
| A2-DB-6 | **Nuevo** `33_culm001_a_mensajes.sql` | Usuario y técnico: `SES_017` ("La sesión se cruza con otra sesión del grupo o del docente en ese horario."), `REV_006` ("La solicitud de revisión no existe."), `REV_007` ("Solo se puede retirar una solicitud de revisión pendiente."), `REV_008` ("La solicitud de revisión fue retirada."), `DEC_002` ("No se puede desactivar al decano de una facultad con programas activos.") y `DEC_003` ("Se actualizó el estado del decano."). **Rango de sesión de A (DEC-031 §1):** B ocupa `SES_010`–`SES_016`, A usa `SES_017` en adelante (solape = `SES_017`) y C usará `SES_030` en adelante. Antes de congelar se hizo grep de los códigos sobre `04_mensaje.sql` y **sobre los contratos B y B2** (`paquetes/*/CONTRACT.md`): `SES_017`, `REV_006..REV_008` y `DEC_002/DEC_003` están libres; hoy existen `REV_001..REV_005`, `DEC_001` y `SES_001..SES_009`, y B reserva `SES_010..SES_016` |
| A2-DB-7 | `test/fixtures/culm1_segundo_ambito.sql` y `culm1_segundo_ambito_down.sql` (A.2-13) | Fuera del despliegue (`deploy_schema.ps1` no lee `test/`). Idempotente: `MERGE` por id fijo con el prefijo `C1B0...` y nombres `CULM1-*`. En la institución sembrada crea, si no existen (la facultad se busca primero por nombre, porque puede existir ya), `CULM1-Facultad B` con `CULM1-Decano B`; `CULM1-Programa B` con `CULM1-Coordinador B`, plan, semestre y asignatura `CULM1-ASG-B` (ESP); `CULM1-Docente B`; `CULM1-Grupo B` en el período vigente con horario; 3 estudiantes `CULM1-Est B1..B3` con `EstudianteGrupo` `A` y `EstudiantePrograma`; una sesión vencida con asistencias y un reclamo `P` de B1 (para probar el ámbito de reclamos). Usuarios solo en BD (correo `@uco.edu.co` de prueba, contraseña con hash de relleno, **sin** cuentas en el realm: no hacen falta para probar que los `uco-*` **no** los ven). El `_down` borra **solo las filas con ids `C1B0...`** que el script creó, en orden de FK. **Nunca** borra una `CULM1-Facultad B` (ni su decano) que ya existía y se encontró por nombre: en ese caso, el script la registra en una tabla temporal de sesión y el `_down` la deja. `seed-clean-data.ps1` (`AsistenciasUCO-Infra/components/sqlserver/scripts/`) borra todo el fixture al restablecer los datos; después hay que volver a aplicarlo (se anota en su cabecera y en `ESTADO.md`). N7: A2-T-15 pasa **con y sin** el fixture aplicado, y A2-T-18 prueba la doble aplicación. Lo usan la matriz de la Fase 3 y la verificación A.2 por API. Las pruebas A2-T crean sus propios datos dentro de su transacción |
| A2-DB-8 | F-000 (A.2-12), dos causas distintas | **(a) `TEACHER_GROUP_NOT_FOUND`** lo exige `AsistenciasUCO-Infra/components/sqlserver/scripts/test-summary.ps1:110`, pero su prueba y su objeto (`usp_registrar_docente_en_grupo`) se borraron en DB `1e66740` ("eliminar 18 objetos sin uso", que quitó los IDs del `test_summary.ps1` de DB, no del de Infra). Corrección: quitar el ID de la lista de Infra, citando `1e66740`; es un error de la prueba, no del código. **(b) `LB004D_R2_TEACHER_SCOPE_AND_SUPPORT`** (`test/test_lb004d_support_binding.sql:415-425`). Hipótesis H1, que se comprueba en RED con evidencia en `VALIDATION.md`: la aserción `NOT EXISTS (SELECT 1 FROM #r2 WHERE idGrupo <> @group)` supone que el docente solo es titular de `@group`, pero en la semilla el único docente es titular de los 2 grupos (F-TRX-008) y Carlos tiene un reclamo en el otro grupo, que el SP devuelve **correctamente**. Paso 1: ejecutar el bloque R2 aislado e imprimir `#r2` con `idGrupo` y el docente del grupo. Si H1 se confirma, la aserción pasa a `NOT EXISTS (SELECT 1 FROM #r2 r INNER JOIN dbo.Grupo g ON g.id = r.idGrupo WHERE g.docente <> @teacher)`: es **la misma regla** (solo grupos del titular) sin la suposición sobre los datos, y se justifica por escrito en el commit. Si H1 no se confirma, se corrige `usp_consultar_solicitudes_revision_docente`, no la prueba |
| A2-DB-9 | **Nuevo** `usp_buscar_estudiante_por_documento_grupo (@idGrupo UNIQUEIDENTIFIER, @idTipoIdentificacion UNIQUEIDENTIFIER, @numeroIdentificacion INT, @idCorrelacion UNIQUEIDENTIFIER, @idUsuarioEjecutor UNIQUEIDENTIFIER)` (A.2-15, DEC-027) | `READ_QUERY_RESULTSET`; `SET NOCOUNT ON; SET XACT_ABORT ON`. Ejecutor nulo → `THROW 51000` (`VAL_001`). **Titularidad dentro del SP:** el ejecutor debe ser el DOCENTE titular del grupo (`Grupo.docente` → `Docente.usuario`); si no lo es, o el grupo no existe, `THROW 51000` con `DBCODE=SEC_002` → 403 (DEC-025). Parámetros de documento nulos o `@numeroIdentificacion <= 0` → `THROW` con `VAL_001` → 400. **Búsqueda exacta** por `(Usuario.tipoIdIdentificacion, Usuario.numeroIdentificacion)` de un usuario **con fila `Estudiante`**, sin `LIKE` y sin listar: 0 o 1 fila. **Datos mínimos:** `idEstudiante`, `primerNombre`, `segundoNombre`, `primerApellido`, `segundoApellido` (el modal los necesita para rellenar el formulario, `attendance-enrollment-modal.component.ts:407-410`), `nombreCompleto`, `numeroIdentificacion`, `correoEnmascarado` (primer carácter del usuario + `***` + `@dominio`, calculado en el SP; el correo real nunca sale) y `codigoEstadoMatriculaGrupo` (código de `uv_estado_estudiante_grupo` de su matrícula en **ese** grupo, NULL si no tiene). **Alcance institucional:** solo devuelve al estudiante si no tiene vínculos (alta pendiente de matrícula) o si alguno de sus vínculos es de la institución del grupo; un estudiante de otra institución da 0 filas, como uno inexistente, para no revelar que existe. Grant al runtime en `rol_asistencias_runtime_culm001_a.sql`; excepción `READ_QUERY_RESULTSET` en `test_contract_closure.sql` |

`down` de A.2: `DROP` de los SP nuevos; `CREATE OR ALTER` de `usp_crear_sesion_interno`, `usp_actualizar_sesion_interno` y `uv_decano` como estaban en `65a4998`; `ALTER TABLE dbo.Decano DROP CONSTRAINT DF_Decano_estado, COLUMN estado` (si existen); `DELETE` de los parámetros y mensajes de A2-DB-5/6. No borra datos de negocio: un reclamo en `X` vuelve a `P`, y se informa por `PRINT`.

#### 8.2.4 Pruebas T-SQL de A.2 (archivo `test/test_culm001_a_correcciones.sql`, incluido en `test_suite.sql` después de E-09)

| ID | Tipo | Regla | Aserción |
| :--- | :--- | :--- | :--- |
| A2-T-01 | RED | Directorio, ADMINISTRADOR | Con fixtures de 2 programas en la transacción: ve los de su institución y los sin vínculo; `totalRegistros` coherente; ejecutor nulo → `THROW 51000` |
| A2-T-02 | RED | Directorio, COORDINADOR | Solo estudiantes con `EstudiantePrograma` en sus programas; `@idPrograma` ajeno → 0 filas; con `Coordinador.estado = 0` → 0 filas |
| A2-T-03 | RED | Directorio, DOCENTE | Solo estudiantes de sus grupos (incluidos los `I`); el estudiante de un grupo ajeno no aparece |
| A2-T-04 | RED | Directorio, detalle | `@idEstudiante` fuera de ámbito → 0 filas; dentro → filas de contexto solo del ámbito |
| A2-T-05 | RED | Directorio, otros roles y semántica | DECANO y ESTUDIANTE → 0 filas; orden fijo; `nombre` con `%` y `_` escapados; página posterior a la última → 0 filas con `totalRegistros` real |
| A2-T-06 | RED | Estudiantes del grupo | Titular → todas las filas en todos los estados; docente ajeno, coordinador de otro programa y grupo inexistente → `THROW` con `DBCODE=SEC_002`; administrador de la institución → filas; `@tamanoPagina NULL` → todas |
| A2-T-07 | RED | Asistencias del grupo | Lo mismo que A2-T-06, más el filtro `@idSesion` y "sin registro = sin fila" |
| A2-T-08 | RED | Solo `A` cuenta | Matrículas `A`, `I`, `CI`, `CVP` y `F` del mismo estudiante en 5 grupos: materias y horario devuelven solo el grupo `A`; la oferta marca `matriculado = 1` solo en `A` |
| A2-T-09 | RED | Solape | Crear sesión solapada en el mismo grupo → `SES_017`; en otro grupo del mismo docente → `SES_017`; adyacente (fin = inicio) → éxito; otro docente a la misma hora → éxito; actualizar una sesión sin cambiar su horario → éxito (se excluye a sí misma); **renombrar una sesión que ya tenía un solape heredado → éxito** (no se valida porque el horario y el grupo no cambian, N6); por las fachadas congeladas `usp_crear_sesion`, `usp_crear_sesion_v2`, `usp_actualizar_sesion` y `_v2`; `@@TRANCOUNT` intacto |
| A2-T-10 | RED | Retiro de reclamo | Propietario y `P` → `X` y `REV_008`; ajeno → `REV_006` sin cambios; ya `A`/`R`/`X` → `REV_007`; perfil no estudiante → `SEC_001`; `@@TRANCOUNT` intacto |
| A2-T-11 | RED | `X` no contamina reclamos | `usp_consultar_solicitudes_revision_docente` con `@codigoEstado = 'P'` no devuelve los `X`; los KPI de reclamos (`usp_consultar_kpis_*` que cuenten reclamos) no cuentan `X` como pendiente ni como resuelto |
| A2-T-12 | RED | Estado del decano | Administrador de la institución: desactivar al decano de una facultad sin programas activos → `estaActivoDecano = 0`; con programas activos → `DEC_002`; persona con otro rol activo conserva `Usuario.estado = 1`; reactivar → 1; administrador de otra institución → `DEC_001`; no administrador → `SEC_001`. **RBAC (bloqueante 4):** con el decano desactivado y el usuario activo por otro rol, `usp_validar_permiso_rbac_usuario_interno @codigoPerfilRequerido = DECANO` → `SEC_001`, `uv_usuario_perfil` no tiene la fila `DE` y `usp_consultar_kpis_decano` con ese ejecutor lo rechaza; al reactivarlo, el RBAC vuelve a pasar y la consulta responde |
| A2-T-13 | RED | Semillas 33 | Los valores sembrados de A2-DB-5 y E-08 son exactamente los de la tabla de valores por defecto del backend (§8.4, A2-B-09); los 6 mensajes existen en usuario y técnico |
| A2-T-14 | RED | Grants | El runtime tiene `EXECUTE` sobre los 7 SP públicos nuevos y no sobre `usp_validar_solape_sesion_interno` |
| A2-T-15 | RED | F-000 | `db-test` completo sin `TEST FAILED` y sin IDs canónicos faltantes, **dos veces: sin el fixture del segundo ámbito y con él aplicado** (N7). Las pruebas que usan `TOP 1` (`test_transaction_ownership`, `test_group_capacity_decoupling` y LB004D con H1) no deben depender de que el fixture esté o no |
| A2-T-16 | RED (compuerta manual) | Migración A.2 | `test_migracion_13_culm001_a.ps1` añade `up` → `up` → `down` → `up` de `14_culm001_a_correcciones_fase1_*` |
| A2-T-06b | RED | `@tamanoPagina` sin límite solo en los SP de grupo (N10) | `usp_consultar_estudiantes_grupo_ambito_paginado` con `NULL` devuelve más de 100 filas (fixture de 101 matrículas en la transacción); `usp_consultar_directorio_estudiantes_paginado` y `usp_consultar_grupos_paginado` con `NULL` o con 500 devuelven como mucho 100 |
| A2-T-17 | RED | Búsqueda por documento (DEC-027) | Titular + documento de un estudiante existente → 1 fila con `correoEnmascarado` (sin el correo real) y `codigoEstadoMatriculaGrupo` (`A`, `I` o NULL); documento inexistente → 0 filas; documento de un estudiante de **otra institución** → 0 filas; docente **no titular**, coordinador y grupo inexistente → `THROW` `DBCODE=SEC_002`; documento nulo o `<= 0` → `VAL_001`; un documento parcial no encuentra (no hay `LIKE`); nunca devuelve más de 1 fila |
| A2-T-18 | RED | Fixture idempotente (N7) | Aplicar `culm1_segundo_ambito.sql` dos veces deja los mismos conteos; `_down` deja la BD como antes; si `CULM1-Facultad B` existía antes, el `_down` no la borra |

### 8.3 Catálogo de mensajes y parámetros

- BD: A2-DB-5 y A2-DB-6 (seeds 33).
- Backend `DbFailureClassifier.classifyDbCode`: `SES_017` → `CommonErrorCode.VALIDATION_ERROR` (400, A2-C2/§8.1); `REV_006`, `NTF_002` → `RESOURCE_NOT_FOUND` (404); `REV_007`, `DEC_002` → `CONFLICT` (409). `DEC_001` y `SEC_00x` ya están mapeados.
- `src/test/resources/messageucolab/catalogo-mensajes-usuario.psv`: una fila por código nuevo; se regenera con `AsistenciasUCO-Infra/components/messages/build-message-catalog.py` (lo valida `MessageUcoLabCatalogoTest`).
- Azure App Configuration (`messages:user:<COD>` y `messages:technical:<COD>`): pendiente operativo (R-13).

### 8.4 Backend (A.2)

| Ítem | Archivos (prefijo `B/`) | Cambio |
| :--- | :--- | :--- |
| A.2-1 | `infrastructure/adapter/primary/controller/estudiante/EstudianteController.java`; `application/features/estudiante/consultarestudiantes/**` y `consultarestudianteporid/**`; `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/EstudianteJpaRepository.java` | El controlador pasa `authenticatedUserResolver.requireAuthenticatedUserId()` a los dos casos de uso (hoy no lo pasa: líneas 40-77). Los dominios y DTO de repositorio ganan `actorUsuarioId`. El adaptador sustituye `HQL_COUNT`, `HQL_PAGE` y `HQL_CONTEXTOS` por `EXEC dbo.usp_consultar_directorio_estudiantes_paginado` (consulta nativa con parámetros nombrados, como en `OfertaGruposEstudianteJpaRepository`), con `@numeroPagina = page + 1` y `totalPages = ceil(totalRegistros / size)`. `ConsultarEstudiantePorIdUseCaseImpl`: sin filas → `ResourceNotFoundException` (404). `SecurityConfig:136-138` y el catálogo (149-150): roles sin cambio (A2-C1, DEC-027; `x-roles` se recongela en 1.2.0 con B); el `ownership` pasa a "Ámbito en el SP usp_consultar_directorio_estudiantes_paginado (ADMINISTRADOR institución, COORDINADOR programas, DOCENTE grupos propios)" |
| A.2-2 | `application/features/grupo/consultarestudiantesgrupo/**`, `application/features/asistencia/consultarasistenciasporgrupo/**`, `application/features/grupo/consultargrupos/**`; `GrupoJpaRepository.java` (`consultarEstudiantesGrupo` 205-213, `consultarGrupos` 183-190) y `AsistenciaJpaRepository.java` (`consultarAsistenciasPorGrupo` 190-206); `GrupoController.listarGrupos` (76-80) | Los puertos reciben el ejecutor. Los adaptadores llaman a los SP de 8.2.2 (`@tamanoPagina = NULL`) y `consultarGrupos(actor)` usa `usp_consultar_grupos_paginado` paginando hasta `totalRegistros`, conservando `conHorarios`. En los casos de uso, el control previo de titularidad del docente (`InstitutionalScopePort`) se conserva como defensa adicional; el SP es la autoridad para los tres roles. El Javadoc "Coordinador/Administrador conservan visibilidad institucional amplia" se corrige |
| A.2-3 | `infrastructure/config/security/SecurityConfig.java:122-125`; `infra/security-baseline/access-catalog.json` | `"/api/v1/decano/**"` → `.hasRole(ROLE_DECANO)`; `"/api/v1/coordinador/**"` → `.hasRole(ROLE_COORDINADOR)`. En la regla GET de catálogos (123-124), ADMINISTRADOR **solo** se conserva para `GET /api/v1/coordinador/periodos-academicos`: es la única ruta `coordinador/*` o `decano/*` que consume una pantalla del administrador (`admin-periodos.component.ts:61` y `admin-system.component.ts:238` vía `coordinator-management.service.ts:getPeriodosAcademicos`; 200 en `MATRIZ-AMBITO.md:80`). Quedaría como regla propia `HttpMethod.GET, "/api/v1/coordinador/periodos-academicos"` con DECANO, COORDINADOR y ADMINISTRADOR, antes de la regla general. Catálogo: de las **58** filas `coordinador/*`/`decano/*` con ADMINISTRADOR (36 y 22, contadas sobre el JSON), **6 se borran** (A.1: `POST` y `DELETE /coordinador/grupos/{grupoId}/estudiantes...` y `GET`/`PATCH /coordinador/solicitudes-matricula...`; A.2-14: `DELETE /coordinador/planes-estudio/{planId}/asignaturas/{asigId}` y `PATCH /coordinador/periodos-academicos/{id}/estado`). De las 52 restantes, **51 pierden ADMINISTRADOR** y 1 lo conserva (N2). Verificado: no hay rutas de pantalla del administrador hacia `/app/decano/*` ni `/app/coordinador/*` (`app.routes.ts`) |
| A.2-4 | **Nuevo** `infrastructure/adapter/primary/controller/filter/OperacionAutenticadaRateLimitFilter.java`; wiring en un `RateLimitWiringConfiguration` nuevo | Reutiliza `SlidingWindowRateLimiter` y `NetworkClientIpResolver`. Se registra **después** de la cadena de Spring Security (`SecurityProperties.DEFAULT_FILTER_ORDER + 10`), así que conoce al principal; los filtros de matrícula y verificación siguen antes. Tabla de rutas: `POST /api/v1/archivos/subir` → claves `usr:<sub>` e `ip:<ip>` con `ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO`; `POST /api/v1/estudiante/asistencia-qr` → `ip:<ip>` con `ASISTENCIA_QR/LIMITE_IP_POR_MINUTO` y `usr:<sub>` con `ASISTENCIA_QR/LIMITE_ESTUDIANTE_POR_MINUTO`. Al superar el límite: 429 `SecurityErrorCode.TOO_MANY_REQUESTS` por `SecurityErrorResponseWriter`. El límite por token de asistencia queda para B |
| A.2-5 | `SecurityConfig.java` (cadena), `MatriculaQrWiringConfiguration.java:78-81` y `:204-214`, `NetworkClientIpResolver.java` | **Causa raíz (evidencia corregida, N1):** en `POST /api/v1/public/matricula-qr/validar`, `HttpRequestTraceFilter` registra `status:500` con `ParameterCatalogException` en la traza (cid `b546c8b9…` y `2f4f4afc…` en el log del worktree). El origen es `MatriculaQrRateLimitFilter.java:58` → `MatriculaQrWiringConfiguration.limiteIp:206` (`MATRICULA_QR/LIMITE_IP_POR_MINUTO`) → `AzureAppConfigParameterCatalogAdapter:58/68` (401 de Azure). Ese filtro va **antes** de la cadena de seguridad (`HIGHEST_PRECEDENCE + 11`, `MatriculaQrWiringConfiguration:203`). En la v2 se atribuía a `NetworkClientIpResolver`/`RED/PROXIES_CONFIABLES`, que es la causa del cid `ac109cef` en `/estudiante/matricular-grupo`, no de la ruta pública. La excepción en el filtro dispara el despacho de error a `/error`, que la cadena trata como no autenticado → **401**. **Corrección:** (1) DEC-018 (A.2-6) y el decorador de valores por defecto, para que el catálogo no falle; (2) `.dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()` en `SecurityConfig`, para que un error en un filtro muestre su estado real y no un 401 falso (el PEP ya exime `/error`, `SecurityPublicEndpoints.ERROR_VIEW`); (3) `limiteIp` trata una `ParameterCatalogException` como el valor por defecto de `ParametrosPorDefecto` (`MATRICULA_QR/LIMITE_IP_POR_MINUTO = 20`), y `NetworkClientIpResolver` trata un fallo del catálogo como "sin proxies confiables" (el valor seguro: no confiar en `X-Forwarded-For`); (4) `server.error.include-stacktrace: never` (y `include-message`/`include-exception` desactivados) en `application.yml`, para que el cuerpo del despacho `ERROR` sea `ApiErrorResponse` sin traza. **Sin comodín `/api/v1/public/**`** (A2-C6). La propiedad `SECURITY_PEP_PUBLIC_PATHS` / `security.pep.enforcement.public-paths` no existe en el código (grep: 0). Solo se crea si, después de esta corrección, A2-B-08 en vivo sigue dando 401 desde el PEP; en ese caso su valor por defecto serían las **tres rutas explícitas** de `SecurityPublicEndpoints`, y si el bloqueo es configuración del laboratorio se documenta como dependencia del equipo de seguridad. `GET /api/v1/configuracion/registro-estudiante` **no es pública** (catálogo línea 73: COORDINADOR y DOCENTE; su único consumidor es el modal del docente) y se queda así; su 500 lo corrige A.2-6 |
| A.2-6 | **Nuevo** `infrastructure/adapter/secondary/catalog/composite/ParametroConValorPorDefectoCatalogAdapter.java` (`@Primary`, envuelve al proveedor configurado); **nuevo** `ParametrosPorDefecto.java`; `.env.example` y `.env.template` (línea documentada); `.env` del worktree (sin versionar) | **DEC-018.** El decorador recibe al delegado con un **calificador explícito** (`@Qualifier("parameterCatalogDelegado")` sobre el bean del proveedor configurado, Azure o `sqlserver`), para no inyectarse a sí mismo ni crear un ciclo (N9). `ParametrosPorDefecto` es la **única fuente** de valores por defecto en código: se elimina `LIMITE_IP_POR_DEFECTO` de `MatriculaQrWiringConfiguration` y se reemplaza por la referencia a `ParametrosPorDefecto`. `getParameter`: delega; si el resultado está vacío o lanza `ParameterCatalogException`, devuelve el valor por defecto de `ParametrosPorDefecto` y escribe un WARN con `correlationId` (sin valores sensibles). `getRequiredParameter`: igual, y `ParameterNotFoundException` solo si no hay valor por defecto. **Tabla de valores por defecto = semilla:** `MATRICULA_QR/HABILITADA=true`, `URL_BASE_FRONTEND=http://localhost:4200`, `LIMITE_IP_POR_MINUTO=20`, `LIMITE_REGISTROS_TOKEN_POR_MINUTO=5`, `ESTADO_MATRICULA=A`; `RED/CIDRS_CAMPUS=127.0.0.1/32,::1/128` (solo loopback: fuera de desarrollo sigue negando todo); `RED/PROXIES_CONFIABLES=` (vacío); `IDENTIDAD/PERMITIR_CORREGIR_DOCUMENTO=1`; `REGISTRO/DOMINIO_CORREO_ESTUDIANTE=@uco.edu.co`; y los de A2-DB-5. Son las 7 lecturas del catálogo que hay en `src/main` (`CorreccionIdentidadService:77`, `MatriculaQrAccesoPolicy:30`, `MatriculaQrPresentador:30`, `CorreoInstitucionalPolicy:33`, `CidrRedInstitucionalAdapter:36`, `MatriculaQrWiringConfiguration:80,206`) más las nuevas. En local: `APP_ADAPTERS_PARAMETER_CATALOG_PROVIDER=sqlserver` (activa `ParameterCatalogJpaRepository`, `@ConditionalOnProperty ... havingValue = "sqlserver"`). Así desaparecen los 500 de `/configuracion/identidad` (5 roles), `/configuracion/registro-estudiante`, `POST /grupos/{id}/matricula-qr` y `/rotacion` (titular → 201/200) y `POST /estudiante/matricular-grupo` con PIN `000000` (el SP llega a responder `MQR_001`, ya mapeado). El `GUID` de grupo inexistente en `matricula-qr` → **403** (titularidad del SP, A2-C2). **Validación de cuerpo:** `POST /admin/notificaciones/plantillas/{tipo}/versiones` con `{}` → 400 `VALIDATION_ERROR` en el request (`asunto` y `cuerpo` obligatorios), antes del `Objects.requireNonNull` de `AdministracionNotificacionJpaAdapter:302` que hoy da el NPE 500 (`cid 265931af...`). `POST /admin/notificaciones/cola/{id}/reintentar` con id inexistente: `NTF_002` → 404 (§8.3; hoy `ERR_DB_UNCLASSIFIED`, `cid 253e14d9...`) |
| A.2-7 | `EstudiantePortalController.java:93-96`; **nueva** feature `application/features/estudiante/retirarreclamo/**` (InputPort, DTO, Interactor, UseCase, UseCaseImpl); puerto existente de revisiones (`AsistenciaRepositoryPort`) con un método nuevo `retirarSolicitudRevision`, implementado en `AsistenciaJpaRepository` (`EXEC dbo.usp_retirar_solicitud_revision_asistencia` por `procedureExecutor`, con `OP_RETIRAR_SOLICITUD_REVISION`); wiring en `EstudianteWiringConfiguration` | `DELETE /api/v1/estudiante/reclamos/{id}` → 200 `ApiMessageResponse(true, mensajeUsuario)`; 404 (`REV_006`) y 409 (`REV_007`). `@AuditableOperation(action = "RETIRAR_SOLICITUD_REVISION", resourceType = "SOLICITUD_REVISION")`. **`POST /api/v1/estudiante/reclamos` (501) se elimina** del controlador y del catálogo: el flujo real es `POST /asistencias/revisiones`. Los mappers de reclamos añaden `X → RETIRADA` (A2-DB-3) |
| A.2-8 | `AdminPortalController.java:100-103`; **nueva** feature `application/features/admin/cambiarestadodecano/**`, que replica `application/features/decano/cambiarestadocoordinador/**` (incluida la sincronización con `IdentityProviderPort` cuando `personaSinRolesActivos`); `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/DecanoJpaRepository.java` (el que ya ejecuta `usp_crear_decano`) con `EXEC dbo.usp_cambiar_estado_decano` | `PATCH /api/v1/admin/decanos/{id}/toggle` (ruta y fila 28 del catálogo sin cambio) → 200 `ApiDataResponse<DecanoItemDTO>` con el estado nuevo, que es lo que espera `admin-decanos.component.ts:564-575` (`res.exitoso && res.datos`); 409 `DEC_002`; 404 `DEC_001` |
| A.2-9 | `infrastructure/adapter/secondary/persistence/sqlserver/jpa/repository/DbCodeTranslator.java` (existente, lo usan 7 repositorios) y `infrastructure/adapter/secondary/persistence/sqlserver/support/query/JpaQueryExecutor.java` | **Se reutiliza `DbCodeTranslator`, no se crea una tercera vía (N3).** Se añade una sobrecarga `JpaQueryExecutor.execute(operation, errorMessage, query, Function<PersistenceException, RuntimeException> traductor)`, que usan **solo** los repositorios nuevos o migrados de A.2 (directorio, grupo, asistencias, búsqueda, materias y horario) pasando `DbCodeTranslator::traducir`. La firma actual de 3 argumentos **no cambia de comportamiento**, así que las traducciones específicas de los 7 repositorios que ya usan `DbCodeTranslator` (`GEN_001` con el nombre de la entidad, `VCE_004` → 404, `MQR_001`) siguen igual, y sus pruebas quedan en verde sin cambios. `DbCodeTranslator` añade los códigos que faltan (`SEC_002` → 403, `NTF_002` → 404) delegando en el mapeo de `DbFailureClassifier`, para que haya una sola tabla de códigos |
| A.2-10 | `DbFailureClassifier` (`SES_017` → 400) | Sin cambios en `SesionJpaRepository`: los SP públicos ya devuelven el resultset canónico |
| A.2-11 | `MateriaEstudianteJpaRepository.java` (`HQL_POR_ESTUDIANTE`, 20-28) y `HorarioEstudianteJpaRepository.java` (`HQL_POR_ESTUDIANTE`, 23-26) | Pasan a `EXEC dbo.usp_consultar_materias_estudiante` y `EXEC dbo.usp_consultar_horario_estudiante`, con el **usuario** ejecutor (el SP resuelve el estudiante). El dashboard del estudiante usa `GET /estudiante/materias` (`overview-student.component.ts`), así que "Materias Inscritas" queda corregido sin cambios en el frontend |
| A.2-14 | `CoordinadorPortalController.java:136-137` (`DELETE /planes-estudio/{planId}/asignaturas/{asigId}`) y `:157-158` (`PATCH /periodos-academicos/{id}/estado`); `UsuarioController.java:45-50` (`PUT /usuarios/perfil`); `EstudiantePortalController.java:93-94` (`POST /estudiante/reclamos`) | Se retiran los 4 stubs 501 y sus filas del catálogo. `unavailable()` de `CoordinadorPortalController` se elimina si queda sin uso, y `FeatureUnavailableException` deja de importarse donde sobre. B2 vuelve a crear la ruta de desvincular cuando exista `usp_desvincular_asignatura_plan`. Quedan en 501, a cargo de B o D: `GET /sesiones/{id}/qr-token`, `PATCH /docente/sesiones/{id}/cancelar` y `PUT /admin/parametros/{id}` |
| A.2-15 (DEC-027) | **Nuevo** `GET /api/v1/grupos/{grupoId}/estudiantes/busqueda` en `GrupoController` (parámetros `tipoIdentificacionId` UUID y `documento` int obligatorios); **nueva** feature `application/features/grupo/buscarestudiantepordocumento/**` (InputPort, DTO, Interactor, UseCase, UseCaseImpl, Domain); `GrupoRepositoryPort.buscarEstudiantePorDocumento(grupoId, tipoId, numero, actor)`, implementado en `GrupoJpaRepository` con `EXEC dbo.usp_buscar_estudiante_por_documento_grupo`, sobrecarga con `DbCodeTranslator`; `SecurityConfig`: regla `HttpMethod.GET, "/api/v1/grupos/*/estudiantes/busqueda"` → `.hasRole(ROLE_DOCENTE)` **antes** de `GET /api/v1/grupos/**` (178-180); `access-catalog.json`: fila nueva `{"method": "GET", "path": "/api/v1/grupos/{grupoId}/estudiantes/busqueda", "roles": ["DOCENTE"], "access": "ROLES", "ownership": "DEC-027: solo el docente titular del grupo; documento exacto y datos mínimos (usp_buscar_estudiante_por_documento_grupo)."}`. **Matrícula de un estudiante encontrado:** como el modal solo recibe el correo enmascarado, `RegistrarEstudianteRequest.correo` pasa a ser opcional cuando el documento corresponde a un estudiante existente: `RegistrarEstudianteUseCaseImpl.validarConflictoIdentidadUsuario` resuelve el correo en el servidor por documento antes de llamar al SP, que no cambia (sigue buscando por correo, y `IDN_001` se conserva). Un alta nueva sigue exigiendo correo institucional (IDENT-001) | El docente ya no necesita el directorio institucional para matricular (cierra F-DOC-013) |

**Pruebas backend A.2:**

| ID | Tipo | Archivo | Aserción |
| :--- | :--- | :--- | :--- |
| A2-B-01 | RED | `EstudianteJpaRepositoryTest` | Ejecuta el SP con parámetros nombrados (incluido el ejecutor) y mapea por posición las 12 columnas; `page 0` → `@numeroPagina 1`; `totalPages` correcto; el modo detalle agrupa los contextos |
| A2-B-02 | RED | `ConsultarEstudiantesUseCaseImplTest`, `ConsultarEstudiantePorIdUseCaseImplTest`, `EstudianteControllerTest` | El actor llega al puerto; el detalle vacío da `ResourceNotFoundException` y 404 `ApiErrorResponse`; la respuesta del listado conserva la forma `EstudiantePagina` del OpenAPI (y `OpenApiGoldenPathConformanceTest` sigue en verde, sin editarlo) |
| A2-B-03 | RED | `DbCodeTranslatorTest` (ampliado) y `JpaQueryExecutorTest` | La sobrecarga con traductor: `DBCODE=SEC_002\|...` → 403, `PAG_001` → 400, `NTF_002` → 404; sin marcador → `DatabaseOperationException`. La firma de 3 argumentos se comporta igual que hoy. Las pruebas de los 7 repositorios que ya usan `DbCodeTranslator` pasan sin modificarse |
| A2-B-04 | RED | `GrupoControllerTest` y el test de `AsistenciaPorGrupo` (`@WebMvcTest` con `GlobalExceptionHandler`) | Un repositorio que lanza la excepción de `SEC_002` → 403 en `GET /grupos/{id}/estudiantes` y `/asistencias`; el éxito devuelve la lista completa sin parámetros de paginación |
| A2-B-05 | RED | `GrupoJpaRepositoryTest` | `consultarGrupos(actor)` recorre 2 páginas de `usp_consultar_grupos_paginado` y une los horarios; el ejecutor llega al SP |
| A2-B-06 | RED | `RbacSecurityFilterChainTest` + `AccessCatalogConsistencyTest` (sin editar) | ADMINISTRADOR → 403 en una muestra de `coordinador/*` (`/coordinador/estudiantes`, `/coordinador/indicadores`) y `decano/*` (`/decano/estructura`, `POST /decano/coordinadores`); ADMINISTRADOR → 200 en `GET /coordinador/periodos-academicos`; COORDINADOR y DECANO sin cambios. Los tests actuales que esperan 200 para ADMINISTRADOR en esas rutas cambian de expectativa por un cambio formal (DEC-022 §2), y cada uno se lista en el commit |
| A2-B-07 | RED | `OperacionAutenticadaRateLimitFilterTest` | `N+1` subidas por usuario → 429, y por IP con usuarios distintos → 429; asistencia QR por IP y por estudiante → 429; otras rutas sin límite; si el catálogo falla, rigen los valores por defecto |
| A2-B-08 | RED | `MatriculaQrPublicaSinTokenWebMvcTest` (nuevo, con `MatriculaQrRateLimitFilter` registrado como en producción) | `POST /api/v1/public/matricula-qr/validar` **sin token**, con el delegado del catálogo lanzando `ParameterCatalogException`: el fallo se reproduce **en el filtro** (`limiteIp`) y la respuesta nunca es 401 sino 400/404/429 de negocio. Con el decorador desactivado, el filtro sigue usando el valor por defecto. Un filtro que lanza una excepción produce su estado real (`DispatcherType.ERROR` permitido), y el cuerpo es `ApiErrorResponse` **sin traza** (`server.error.include-stacktrace = never`) (N1) |
| A2-B-09 | RED | `ParametroConValorPorDefectoCatalogAdapterTest` | Un delegado que falla o está vacío → valor por defecto; el contexto arranca con el decorador `@Primary` y el delegado calificado, sin ciclo (N9); `MatriculaQrWiringConfiguration` ya no declara `LIMITE_IP_POR_DEFECTO` (comprobación por reflexión); obligatorio sin valor por defecto → `ParameterNotFoundException`. La tabla de `ParametrosPorDefecto` es exactamente la de §8.4 (la misma lista que fija A2-T-13 en BD) y cubre todas las claves leídas en `src/main` (lista explícita revisada en AUDIT) |
| A2-B-10 | RED | `CorreccionIdentidadControllerTest`, `ConfiguracionRegistroEstudianteControllerTest`, `AbrirVentanaMatriculaUseCaseImplTest` | Con el catálogo caído: `GET /configuracion/identidad` y `/registro-estudiante` → 200; abrir y rotar la ventana con titular → 201/200 |
| A2-B-11 | RED | `AdministracionNotificacionesControllerTest`, `DbFailureClassifierTest` | `{}` en versiones → 400 sin llegar al adaptador; `NTF_002` → 404 |
| A2-B-12 | RED | `RetirarReclamoUseCaseImplTest`, `EstudiantePortalControllerTest`, `AsistenciaJpaRepositoryTest` | 200 con `mensajeUsuario`; `REV_006` → 404; `REV_007` → 409; el ejecutor llega del token; `POST /estudiante/reclamos` sin ruta (reflexión) |
| A2-B-13 | RED | `CambiarEstadoDecanoUseCaseImplTest`, `AdminPortalControllerTest` | Éxito con `DecanoItemDTO`; `DEC_002` → 409; sincroniza la identidad solo si `personaSinRolesActivos`; `endpoints_no_implementados_lanzan_featureUnavailable` (`AdminPortalControllerTest:318-330`) deja de incluir `toggleDecano` |
| A2-B-14 | RED | `SesionControllerTest`/`SesionJpaRepositoryTest` | `SES_017` → 400 `VALIDATION_ERROR` en `POST /api/v1/sesiones`, `/api/v2/sesiones` y `PATCH /api/v1/sesiones/{id}`; `OpenApiGoldenPathConformanceTest` sin cambios y en verde |
| A2-B-15 | RED | `MateriaEstudianteJpaRepositoryTest`, `HorarioEstudianteJpaRepositoryTest` | Llaman al SP con el usuario ejecutor; ya no usan HQL sobre vistas |
| A2-B-16 | RED | `CoordinadorPortalControllerTest`, `UsuarioControllerTest`, `EstudiantePortalControllerTest` + `AccessCatalogConsistencyTest` | Las 4 rutas 501 de A.2-14 no tienen mapeo (reflexión) y no tienen fila en el catálogo |
| A2-B-17 | RED | `GrupoControllerTest` (búsqueda), `BuscarEstudiantePorDocumentoUseCaseImplTest`, `GrupoJpaRepositoryTest` | `GET /api/v1/grupos/{grupoId}/estudiantes/busqueda?tipoIdentificacionId=&documento=` → 200 `ApiDataResponse<EstudianteBusquedaDTO>` con los campos mínimos de A2-DB-9 (sin `correo`); sin resultado → 200 con `datos: null` (el modal pasa a alta nueva y no hay 404 que revele nada); `SEC_002` → 403; `documento` vacío, no numérico o `<= 0` → 400 `FIELD_INVALID_*` en el request |
| A2-B-18 | RED | `RbacSecurityFilterChainTest` + `AccessCatalogConsistencyTest` | La búsqueda: DOCENTE → pasa el filtro; COORDINADOR, ADMINISTRADOR, DECANO y ESTUDIANTE → 403 (la regla propia va antes de `GET /api/v1/grupos/**`); el catálogo tiene la fila nueva |
| A2-B-19 | RED | `RegistrarEstudianteUseCaseImplTest`, `GrupoControllerWriteEndpointsTest` | Matrícula manual de un estudiante encontrado: con `correo` vacío y documento de un estudiante existente, el backend resuelve el correo **en el servidor** (`UsuarioRepositoryPort` por documento) y aplica la regla `IDN_001` con ese correo; con `correo` vacío y documento inexistente → 400 `FIELD_REQUIRED` (`correo`); con un correo informado, el comportamiento no cambia |

### 8.5 Frontend (A.2) (prefijo `F/`)

| Ítem | Archivo | Cambio |
| :--- | :--- | :--- |
| A.2-7 | `core/services/attendance-claim.service.ts:276-282` | `eliminarReclamo(id: string)` (sin los parámetros sin uso `materiaId` y `sesionId`) → `DELETE /estudiante/reclamos/{id}`, tipado `ApiMessageResponse` |
| A.2-7 | `features/student/student-courses/components/student-course-detail.component.ts:205-212` | El botón "Retirar" solo aparece en reclamos `PENDIENTE`; al pulsarlo muestra el `mensajeUsuario` del backend y recarga la lista. Un error muestra el `message` del backend (regla de presentación pura). Se añade la insignia "Retirada" para `RETIRADA` |
| A.2-7 | `features/teacher/**` (listas de reclamos del docente) y `core/models/role-management.model.ts` | El tipo de estado de reclamo admite `'RETIRADA'`; las bandejas del docente no lo cuentan como pendiente |
| A.2-8 | `features/admin/admin-decanos/admin-decanos.component.ts:141-149,564-575`; `core/services/admin-management.service.ts:113-115` | El *toggle* actualiza la tarjeta con `res.datos` y muestra el `mensajeUsuario`; un 409 muestra el `message` del backend |
| A.2-14 | `features/coordinator/coordinator-study-plans/pages/study-plan-mesh-page.component.ts:39` (`(deleteSubject)`) y el método de ~187-200; el componente de malla que emite `deleteSubject`; `core/services/coordinator-management.service.ts:351` (`eliminarAsignaturaPlan`) | Se oculta el control "desvincular asignatura" (no se emite ni se enlaza `deleteSubject`) y se quita el método del servicio que llama a `DELETE /coordinador/planes-estudio/{planId}/asignaturas/{asigId}`. B2 los vuelve a añadir con su SP |
| A.2-14 | `core/services/auth.service.ts:768-...` (`updateUserProfile`); `features/profile/profile.component.ts` (botones "Editar" en 56-60, 150-154, 186-189, 307-311, más la lógica asociada en 334 y 405-408) | Se quitan `updateUserProfile` y los botones de edición; HU006 queda como consulta (`GET /usuarios/perfil` sigue) |
| A.2-14 | `core/interceptors/mock-backend.interceptor.ts:531` | `POST /estudiante/reclamos` sale del mock (queda `POST /asistencias/revisiones`); se añade el mock de `DELETE /estudiante/reclamos/{id}` |
| A.2-15 | `features/attendance/attendance-control/components/attendance-enrollment-modal.component.ts:387-430`; `core/services/student.service.ts:113-137` (`searchStudentByIdentification`); el modelo de respuesta en `core/api/models` | `searchStudentByIdentification(grupoId, tipo, documento)` pasa a `GET /grupos/{grupoId}/estudiantes/busqueda` y devuelve `EstudianteBusquedaApiDto` (los campos mínimos, sin correo real). El modal: si hay resultado, rellena nombres y apellidos, muestra `correoEnmascarado` como **solo lectura**, no envía `correo` ni contraseña (deja de fijar `Temporal2026*`, líneas 411-413) y, si `codigoEstadoMatriculaGrupo` es `A`, muestra "Ya está matriculado en este grupo" sin enviar; con `I` indica que se reactivará (DEC-009). Sin resultado: formulario de alta limpio, como hoy. Un error 403 o 400 muestra el `message` del backend y no abre el alta |

**Specs A.2:**

| ID | Tipo | Spec | Aserción |
| :--- | :--- | :--- | :--- |
| A2-F-01 | RED | `student-course-detail.component.spec.ts` | "Retirar" solo en `PENDIENTE`; llama a `eliminarReclamo(id)`; muestra el mensaje del backend y recarga; el error muestra `message` |
| A2-F-02 | RED | `attendance-claim.service.spec.ts` | `DELETE` a `/estudiante/reclamos/{id}` con un solo argumento |
| A2-F-03 | RED | `admin-decanos.component.spec.ts` | El *toggle* refleja `res.datos.estaActivo`; el 409 muestra el mensaje del backend |
| A2-F-04 | RED | `study-plan-mesh-page.component.spec.ts` | No se renderiza el control de desvincular; `'eliminarAsignaturaPlan' in service` es `false` (sin `any`, N9) |
| A2-F-05 | RED | `profile.component.spec.ts`, `auth.service.spec.ts` | No hay botones "Editar"; `'updateUserProfile' in authService` es `false` |
| A2-F-06 | RED (reescrita, DEC-027) | `attendance-enrollment-modal.component.spec.ts` y `student.service.spec.ts` | La búsqueda llama a `GET /grupos/{grupoId}/estudiantes/busqueda` y **no** a `/estudiantes`; con resultado rellena los nombres, muestra el correo enmascarado, no tiene campo de correo editable y no envía `correo` ni `password` al matricular; con `A` bloquea el envío con el aviso; con `I` muestra el aviso de reactivación; sin resultado abre el alta limpia; con 403 muestra el `message` del backend |
| A2-F-07 | RED | specs de las listas de reclamos (estudiante y docente) | La insignia "Retirada" aparece y no cuenta como pendiente |
| A2-F-08 | RED | `mock-backend.interceptor.spec.ts` | El mock no resuelve `POST /estudiante/reclamos`; `DELETE /estudiante/reclamos/{id}` sí |
| A2-F-09 | RED | `attendance-control.component.spec.ts` (creación de sesión, `createSession` en 671) y `teacher-grupos.component.spec.ts` (514) | Un 400 con `code` `SES_017` al crear o editar una sesión muestra en pantalla el `message` del backend, sin texto local (N11) |

### 8.6 Docs e Infra (A.2)

- `AsistenciasUCO-Infra/components/sqlserver/scripts/test-summary.ps1:110`: quitar `TEACHER_GROUP_NOT_FOUND` (A2-DB-8a).
- `HU-CATALOG.md`: HU010/HU012 (retiro del reclamo), HU006 (solo consulta), HU034 (solape), la fila del decano (vecina de HU159) y HU001/HU017 (solo matrícula `A`), con su estado real tras la Fase 3. HU044: se corrige la fila ("edición de aforo por coordinador/administrador"), según DEC-022 §7.
- `HOJA_DE_RUTA_JERARQUIA_ROLES.md`: el administrador no opera las vistas de coordinador ni de decano (F-TRX-018).
- `TECHNICAL_DEBT.md` de Infra: TD-CULM001-A-01 (R-12), la deuda del 409 local (R-9), y `SES_017` ausente de la tabla §G (§8.1). **No** se registra deuda por el `x-roles` de `GET /estudiantes`: se recongela en 1.2.0 con B (DEC-027, DEC-030). Si la v2 la hubiera dado de alta, se borra.
- Fuera de Git (CLOSURE): `C:\Proyectos\GestionAsistencia\docs\rutas-por-rol.md`, con los roles de `coordinador/*` y `decano/*` sin ADMINISTRADOR y las rutas 501 retiradas.

### 8.7 Riesgos nuevos de A.2

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| R-A2-1 | **Romper pantallas del coordinador, del docente o del administrador al mover el ámbito al SP.** Por ejemplo, el coordinador con grupos mixtos o un estudiante sin `EstudiantePrograma` deja de verse donde antes se veía | A2-T-01..07 por rol, la matriz repetida con `culm1_segundo_ambito.sql` (Fase 3) y la paridad de forma con `OpenApiGoldenPathConformanceTest`. La pertenencia por relación en grupos mixtos (DEC-020) la termina B2, sobre los mismos SP |
| R-A2-2 | **Quitar ADMINISTRADOR de 51 rutas** deja sin acceso a una pantalla del administrador que no se haya detectado | El grep de consumidores y la excepción de `GET /coordinador/periodos-academicos`; el recorrido de la Fase 3 del administrador; `AccessCatalogConsistencyTest`; el PDP pendiente de `--prune` |
| R-A2-3 | **Los valores por defecto en código ocultan una configuración rota en producción** (DEC-018) | Valores = semilla, WARN con `correlationId` en cada uso del valor por defecto y CIDR por defecto solo de loopback (sigue negando fuera de desarrollo). A2-T-13/A2-B-09 fijan la paridad; en producción debe estar configurado el proveedor real |
| R-A2-4 | **El estado `X` en reclamos** se cuela en KPI o bandejas | A2-T-11, A2-F-07 y los mappers explícitos |
| R-A2-5 | **Solape por `UPDLOCK` sobre las sesiones del docente** contiende con la creación masiva | El bloqueo solo cubre las sesiones del docente en el rango; `usp_generar_sesiones_grupo` (congelado) no pasa por el interno; se mide en la prueba de concurrencia de la Fase 3 |
| R-A2-6 | **Columna nueva en `Decano`** (cambio de tabla) | El mismo patrón que `Coordinador` (migración 05); `down` reversible; `uv_decano` actualizada; la revisa el responsable (skill `consistencia-tablas`) |
| R-A2-7 | **El modal de matrícula cambia de fuente (DEC-027):** si el backend no resuelve bien el correo por documento, se rompe la matrícula manual de un estudiante existente | A2-B-19, A2-F-06, la prueba E2E HU050 y un recorrido en pantalla en la AUDIT con un estudiante existente y otro nuevo |
| R-A2-8 | **Choques de numeración entre paquetes:** el `[SUPUESTO-B-01]` del contrato B (línea 16) todavía dice migraciones 14/15 y DEC-025 decía 16/17 para B2 | DEC-028 prevalece (DEC-031 §2): A.1 = 13, A.2 = 14, B = 15/16, B2 = 17/18. Se avisa al orquestador para corregir los contratos B y B2 |

### 8.8 Commits atómicos de A.2 (misma rama)

**GestioAsistenciaDB**
1. `test(db): agregar pruebas red de correcciones de fase 1 del paquete a`
2. `feat(db/sp): agregar consultas con ambito de estudiantes y grupos`. Refs: HU068, HU069, HU060, HU064.
3. `feat(db/sp): consultar materias y horario solo con matricula activa`. Refs: HU001, HU017.
4. `fix(db/sp): rechazar sesiones solapadas del grupo y del docente`. Refs: HU034.
5. `feat(db/sp): permitir al estudiante retirar su reclamo pendiente`. Refs: HU010, HU012.
6. `feat(db/sp): agregar cambio de estado del decano`
7. `feat(db/migrations): agregar migracion 14 de correcciones de fase 1`
8. `test(db): corregir supuesto de datos en la prueba lb004d r2` (solo si H1 se confirma; con evidencia)
9. `test(db/fixtures): agregar datos del segundo ambito culm1`
10. `feat(db/sp): buscar estudiante por documento en grupo del docente`. Refs: HU050 (DEC-027).

**GestioAsistenciaBackend**
1. `test(backend): agregar pruebas red de correcciones de fase 1`
2. `fix(backend/adapter): consultar estudiantes y grupos por sp con ambito`
3. `fix(backend/adapter): traducir codigos de error de consultas sql`
4. `fix(backend/security): retirar administrador de coordinador y decano`
5. `feat(backend/security): limitar intentos de subida y asistencia qr`
6. `fix(backend/adapter): usar valores por defecto en catalogo de parametros`
7. `fix(backend/security): mostrar el estado real de errores en filtros`
8. `feat(backend/controller): retirar reclamo propio del estudiante`
9. `feat(backend/controller): cambiar estado del decano desde administracion`
10. `refactor(backend/controller): retirar stubs 501 expuestos en pantallas`
11. `feat(backend/controller): buscar estudiante por documento en grupo`. Refs: HU050 (DEC-027).

**GestioAsistenciaFrontend**
1. `test(frontend): agregar specs red de correcciones de fase 1`
2. `feat(frontend/estudiante): retirar reclamo pendiente desde el detalle`
3. `feat(frontend/admin): conectar el cambio de estado del decano`
4. `refactor(frontend/ui): ocultar desvincular asignatura y editar perfil`
5. `feat(frontend/docente): buscar estudiante por documento al matricular`. Refs: HU050 (DEC-027).

**AsistenciasUCO-Infra**
1. `fix(scripts): quitar resultado canonico de objeto eliminado en db`
2. `docs(hus): actualizar catalogo con las correcciones de fase 1`

---

## 9. Respuesta a REVIEW-1

| Objeción | Cambio hecho (sección) o motivo de no cambiar |
| :--- | :--- |
| **B1** `XACT_ABORT` y transacción en los SP modificados | **Aceptada.** E-04 adopta el patrón de `usp_internal_matricular_por_token` (transacción propia o savepoint, savepoint de negocio, `ROLLBACK` ante `@estadoResultado = 0` después de escribir, `IF @@TRANCOUNT > 0 ROLLBACK` en el `CATCH`, firma y resultset sin cambio). E-03 declara por escrito que el interno participa en la transacción del llamador. T-12c prueba la falla después de crear `Usuario`/`Estudiante` (con una `CHECK` temporal) sin filas parciales y con `@@TRANCOUNT` intacto. R-4 corregido (N12) |
| **B2** Regla ESP en un solo sitio | **Aceptada.** El SP nuevo solo hace el `UPDATE` (2.3, regla 7). El bloque ESP del interno se vuelve común a los dos caminos (E-03). T-07 añade la comprobación de que el SP nuevo no contiene `EstudiantePrograma` ni `'ESP'` |
| **B3** `down` tolerante | **Aceptada con una variante.** (a) R-8 da por resueltas las filas depuradas y reintentadas; el único `THROW` es el de solicitudes (R-9). (b) Una `RESERVADA` vuelve como `PENDIENTE` con `proximoIntentoEn = SYSDATETIMEOFFSET()`. (c) Las plantillas se archivan con todas sus versiones; **variante:** dos tablas (`zz_archivo_PlantillaSolicitudIngreso` y `zz_archivo_PlantillaMarcadorSolicitudIngreso`) en lugar de una, porque `PlantillaNotificacion` y `PlantillaNotificacionMarcador` tienen columnas y PK distintas; una sola tabla exigiría columnas nulas y un discriminador. T-10 y T-11 ampliadas con versión 2, reserva vencida, fila depurada y fila reintentada |
| **B4** Consumidores que faltan | **Aceptada con un ajuste.** E-16, la fila HU051 de §5.3 y `group-sessions-overview.component.spec.ts:147` (§4.2). **Ajuste en T-155-01:** queda `('P','A','R','X') = 4` y `NOT EXISTS ('E')`, no `= 3`, porque A.2-7 conserva `X` para el reclamo retirado (A-C3 revisada, A2-C4) |
| **B5** T-01b condicional | **Aceptada.** T-01b solo aplica si existen las tablas de archivo; la existencia se exige en T-10 |
| **B6** B-RED-05 en rojo de verdad | **Aceptada.** Nuevo `RutasSolicitudesRetiradasWebMvcTest` con los 4 controladores reales (filtro por nombre, para que compile después del borrado) y `GlobalExceptionHandler`; hoy falla con 200/201/501 |
| N1 Títulos de más de 72 caracteres | **Aceptada.** Los tres títulos se acortaron; todos los de §6.3 y §8.8 se comprobaron con `awk` |
| N2 T-05/T-06 ya en verde | **Aceptada.** Columna "Tipo" RED/CAR en 2.6. La regla 6 bajo bloqueo la cubre T-12b |
| N3 Tipo de excepción de `COLUMNAS_OFERTA` | **Aceptada.** `IllegalStateException`, comprobada como `DatabaseOperationException` con esa causa en OR09. Se recomienda `SqlStoredProcedureContractIT` |
| N4 Bloqueos en cada matrícula | **Aceptada.** Búsqueda sin bloqueo y bloqueo solo si hay fila `I` (2.3, reglas 4-5) |
| N5 Dos fuentes del código `I` | **Aceptada como deuda** TD-CULM001-A-01 (R-12): no se toca `usp_retirar_estudiante_grupo` (HU051 certificada) fuera del alcance |
| N6 El reintento reencola canceladas | **Aceptada (opción documentar).** T-11 y B-RED-09: la fila reencolada vuelve a fallar de forma definitiva porque el tipo no se conoce; R-8 la da por resuelta |
| N7 T-10 no lo ejecuta `db-test` | **Aceptada.** T-10 es una compuerta manual del PLAN, con evidencia en `VALIDATION.md` |
| N8 Claves en Azure App Configuration | **Aceptada.** R-13, pendiente en `PRS.md` y en CLOSURE |
| N9 `(service as any)` | **Aceptada.** F-RED-04 usa `'getSolicitudesMatricula' in service` (§4.4); A2-F-04/05 siguen el mismo patrón |
| N10 Literales `'A'` en los SP reescritos | **Aceptada (corrección, no deuda).** E-01 y E-03 usan `MATRICULA/ESTADO_INSCRITA`, el mismo parámetro de A.2-11 |
| N11 Idempotencia del `down` | **Aceptada.** R-5, R-7 y R-8 protegidos con `IF OBJECT_ID`; T-10 ejecuta el `down` dos veces |
| N12 Atribución del manejo de `XACT_STATE() = -1` | **Aceptada.** Corregida en 2.3 ("Errores bajo QR") y en R-4; T-12d cubre la transacción externa |

**Puntos del orquestador no aplicados al pie de la letra (con motivo):**
1. **`SECURITY_PEP_PUBLIC_PATHS` con `/api/v1/public/**`** (CORRECCIONES-A §A.2.1): la propiedad no existe; la causa raíz comprobada es el `ParameterCatalogException` dentro del filtro y el despacho de error a `/error` (401). Se corrige ahí (A.2-5). El comodín contradice `SecurityConfig:104-108` y el mínimo privilegio; si hiciera falta, se crearía la propiedad con las tres rutas explícitas (A2-C6).
2. **`/api/v1/configuracion/registro-estudiante` "fuera del PEP"**: no es una ruta pública (COORDINADOR y DOCENTE; la usa el modal del docente), así que sigue autenticada. Su 500 lo corrige DEC-018.
3. **404 en grupos ajenos** (CORRECCIONES-A §A.2.1 F-COO-003): se aplica el **403** de la instrucción posterior del orquestador y de `BACKEND_GOLDEN_PATH_CONTRACT.md` (A2-C2).
4. **DOCENTE en `GET /api/v1/estudiantes`**: resuelto por DEC-027. Se conserva DOCENTE con ámbito, se crea la búsqueda por documento (A.2-15) y B recongela `x-roles` en 1.2.0 (ver A2-C1 y §10).

---

## 10. Respuesta a REVIEW-2

| Objeción | Cambio hecho (sección) o motivo |
| :--- | :--- |
| **B1** DEC-027 completo | **Aceptada.** (a) BD: `usp_buscar_estudiante_por_documento_grupo` (A2-DB-9; usa el nombre que fijó el orquestador, no el `usp_consultar_...` que propone el revisor), con titularidad dentro del SP (`SEC_002`, 403), documento exacto, 0 o 1 fila, correo enmascarado y estado de la matrícula en ese grupo, grant y A2-T-17. (b) Backend: `GET /api/v1/grupos/{grupoId}/estudiantes/busqueda`, con una regla DOCENTE propia antes de `GET /api/v1/grupos/**`, una fila en el catálogo, A2-B-17 y A2-B-18. Como el modal ya no recibe el correo real, la matrícula de un estudiante encontrado resuelve el correo en el servidor (A.2-15, A2-B-19). (c) Frontend: el modal y `student.service.ts` pasan al endpoint nuevo; A2-F-06 se reescribe como RED. (d) A2-C1 cita DEC-027 y DEC-030: el paquete B recongela `x-roles` en 1.2.0 (archivos, `.sha256` en Infra y Backend, pruebas de conformidad e `infra.ps1 verify`), y se quita la deuda de drift (§8.6) |
| **B2** Migración 14 | **Aceptada.** `14_culm001_a_correcciones_fase1_up/down.sql` en §2.4, §6.2, §7, §8.2, A2-T-16 y el commit DB (`feat(db/migrations): agregar migracion 14 de correcciones de fase 1`). **Aviso al orquestador (R-A2-8):** el `[SUPUESTO-B-01]` del contrato B (línea 16) dice 14/15 y debe pasar a 15/16; DEC-025 y el mensaje "B2 16-17" contradicen DEC-028 (B2 = 17/18). Según DEC-031 §2, prevalece DEC-028 |
| **B3** `SES_010` choca con B | **Aceptada (DEC-031 §1).** Solape = `SES_017` en A2-DB-2, A2-DB-6, §8.3, A2-T-09, A2-B-14, A2-F-09 y §8.6. Antes de congelar se hizo grep también sobre los contratos B y B2 (A2-DB-6) |
| **B4** El decano desactivado conserva el rol en el RBAC | **Aceptada.** La rama Decano de `uv_usuario_perfil.sql` filtra `d.estado = 1`, con el comentario D1, en `schema/` y en la migración 14, y el `down` la restaura. `personaSinRolesActivos` se calcula después del cambio (A2-DB-4). A2-T-12 añade `SEC_001` en el RBAC `DECANO`, el rechazo de `usp_consultar_kpis_decano` y la vuelta al reactivar |
| N1 Origen del 401 público | **Aceptada.** El origen es `MatriculaQrRateLimitFilter` → `limiteIp` (`MATRICULA_QR/LIMITE_IP_POR_MINUTO`), con los cid `b546c8b9…` y `2f4f4afc…`. `limiteIp` usa el valor por defecto cuando falla el catálogo, `server.error.include-stacktrace = never`, y A2-B-08 reproduce el fallo en el filtro (A.2-5) |
| N2 51 rutas, no 57 | **Aceptada.** 58 − 6 borradas = 52; 51 pierden ADMINISTRADOR y 1 lo conserva (A.2-3, R-A2-2). CLOSURE usará esa cifra |
| N3 Tercera vía de `DBCODE` | **Aceptada.** Se reutiliza `DbCodeTranslator` mediante una sobrecarga de `JpaQueryExecutor` con traductor, que solo usan los repositorios de A.2. Los 7 repositorios actuales y sus pruebas no cambian (A.2-9, A2-B-03) |
| N4 Estudiantes sin vínculo del administrador | **Aceptada (DEC-031 §3).** El administrador ve solo su institución, por `EstudiantePrograma` o `EstudianteGrupo`. Un estudiante sin ningún vínculo no aparece (fail-closed), y hay una fila nueva en la matriz de la Fase 3 (8.2.1) |
| N5 Grupos mixtos | **Aceptada (DEC-031 §4).** El coordinador ve en los SP de grupo solo a los estudiantes, y sus asistencias, con `EstudiantePrograma` en su programa; B2 completa la relación N:M (8.2.2) |
| N6 Solape heredado al editar | **Aceptada.** Solo se valida si cambian el horario o el grupo; A2-T-09 añade el renombrado de una sesión con solape heredado, y en RED se informa cuántos solapes hay en la semilla (A2-DB-2) |
| N7 Fixture | **Aceptada.** A2-T-15 se ejecuta con y sin el fixture; A2-T-18 prueba la doble aplicación y el `_down`; el `_down` borra solo los ids `C1B0…` y nunca una facultad que ya existía; se anota que `seed-clean-data.ps1` lo borra (A2-DB-7) |
| N8 Dependencias de B-RED-05 | **Aceptada.** Un `BeanFactoryPostProcessor` de prueba registra mocks para los parámetros de constructor sin bean, sin nombrar tipos que se borran, y en GREEN la prueba no se edita (3.6) |
| N9 Calificador del decorador y fuente única | **Aceptada.** El delegado se inyecta con `@Qualifier("parameterCatalogDelegado")`; `ParametrosPorDefecto` es la única fuente y se elimina `LIMITE_IP_POR_DEFECTO`; A2-B-09 lo comprueba (A.2-6) |
| N10 `NULL` sin límite | **Aceptada.** Solo en los dos SP de grupo; A2-T-06b prueba que los demás siguen acotando a 100 (A2-C3) |
| N11 Mensaje del solape en pantalla | **Aceptada.** A2-F-09: el formulario de sesión muestra el `message` del backend para `SES_017` |

Objeciones no aceptadas: ninguna. Variante menor: el nombre del SP de búsqueda es el del orquestador (`usp_buscar_estudiante_por_documento_grupo`).
