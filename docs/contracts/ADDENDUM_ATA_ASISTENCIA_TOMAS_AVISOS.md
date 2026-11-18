# Addendum ATA — tomas, aviso de falta por sesión, denominador, solicitudes y horario (sesión 1)

> Fecha: 2026-11-18. Rama `feat/asistencia-tomas-avisos` en DB, Backend, Frontend e Infra.
> Complementa, sin reemplazar, `DB_BASELINE_CONTRACT.md`, `BACKEND_GOLDEN_PATH_CONTRACT.md` y `REALTIME_EVENT_CONTRACT.md`.
> **Golden Path: sin cambios.** Las rutas nuevas son extensiones fuera del Golden Path.
> Decisiones de producto: `docs/PLAN_ASISTENCIA_TOMAS_AVISOS.md` del workspace (D1, D2, D4, D4b, D6, D7, D8). D3 (revisión
> al 20 %) queda para la sesión 2 y NO se toca aquí.

Convenciones: SP con la tupla canónica (`idResultado, exitoso, mensajeUsuario, mensajeTecnico`) en comandos; consultas con
`THROW 51000` en validación (patrón existente); sin GUID ni textos quemados (catálogos y parámetros); columnas nuevas
siempre al final de vistas existentes; mensajes nuevos en el catálogo de mensajes (seed) con su fallback en backend.

---

## A. D4 — Edición durante la sesión y cierre al terminar

**Regla:** mientras la ventana de la sesión esté abierta, el docente titular puede registrar y corregir **cualquier** toma
de la sesión (abierta o cerrada). Al cerrar la ventana, las tomas abiertas se cierran solas marcando falta (SJC) a quien no
tenga registro (si el modo de la toma marca ausentes) y ya nada se edita: solo cambia por reclamo.

| Objeto | Cambio |
| :--- | :--- |
| `usp_registrar_asistencias_toma` | Se elimina el rechazo **TOM_012** (toma cerrada con una toma posterior). La única barrera temporal es la ventana de la sesión (`usp_validar_sesion_ventana_registro_interno`, SES_007..010). El mensaje TOM_012 se conserva en el catálogo (no se borra) pero ningún SP lo emite. |
| `usp_consultar_tomas_sesion` | `esEditable = IIF(t.idToma IS NULL, NULL, IIF(se.ventanaAbierta = 1, 1, 0))`; `editableHastaUtc = IIF(t.idToma IS NULL, NULL, se.ventanaCierreUtc)`. Mismas columnas, mismo orden. |
| Parámetro `ASISTENCIA/MARGEN_RETARDO_MINUTOS` | Valor por defecto **0** (seed y migración: si el valor vigente es el sembrado `30`, pasa a `0`; si un administrador lo cambió a otro valor, se respeta). Sigue en la lista blanca editable. Con 0, `ventanaCierreUtc = fechaHoraFin`: el cierre automático existente (`usp_cerrar_tomas_vencidas`, cada tick del `RotacionTokenAsistenciaScheduler`) cierra a la hora de fin. |
| `usp_cerrar_tomas_vencidas` | Sin cambio de firma ni comportamiento (ya cierra al vencer la ventana y marca SJC). |

**Pruebas:** las pruebas de BD/backend/frontend que esperaban TOM_012 o "editable hasta abrir la siguiente toma" se
**actualizan por cambio formal de contrato** (este addendum); se agregan casos: editar toma 1 cerrada con toma 2 abierta
dentro de la ventana → éxito; editar tras `ventanaCierreUtc` → SES_008.

## B. D2 — Denominador de la pérdida = horas del período

**Regla:** % inasistencia = horas de falta (sesiones vencidas) ÷ horas de **todas** las sesiones del grupo en el período,
incluidas las extraordinarias aprobadas, excluidas las canceladas (docente o festivo) y las solicitudes de sesión no
aprobadas (pendientes o rechazadas). Las excusas no cuentan (sin cambio). Cálculo por tramos sin cambio (D4b, peor caso).

| Objeto | Cambio |
| :--- | :--- |
| `uv_cumplimiento_sesion_grupo` | Columna nueva al final `cuentaParaPeriodo BIT` = 1 si la sesión no es una solicitud pendiente ni rechazada (usar `uv_solicitud_sesion`/`EstadoSolicitudSesion` por catálogo, sin literales). Las canceladas ya están excluidas por la vista. |
| `uv_resumen_asistencia_estudiante_grupo` | Columnas nuevas al final: `sesionesPeriodo INT`, `horasPeriodo DECIMAL(12,6)` (suma de `horasSesion` con `cuentaParaPeriodo = 1`, cualquier fecha). **`porcentajeInasistencia` pasa a `ufn_calcular_porcentaje_inasistencia_horas(horasFalta, horasPeriodo)`** y `codigoPermanencia` se clasifica sobre ese valor. `horasDictadas`, `sesionesEjecutadas` y `porcentajeInasistenciaSesiones` se conservan con su significado (trazabilidad). |
| `uv_resumen_asistencia_estudiante_programa_grupo` | Expone `horasPeriodo` al final si la vista base lo propaga (mismo criterio). |
| `usp_evaluar_alertas_inasistencia_grupo` | Usa el `porcentajeInasistencia` de la vista (no recalcula con `horasDictadas`). Sin cambio de firma. |
| SP de consulta que recalculen el % con `horasDictadas` (lista del relevamiento: comparativas, consolidado, historial, KPIs, resúmenes, alerta temprana, revisiones) | Si calculan el porcentaje por su cuenta, pasan a `horasPeriodo`; si solo muestran horas, sin cambio. Firmas y resultsets sin cambio salvo columnas nuevas al final. |

**Pruebas:** grupo con 10 sesiones de 2 h programadas y 1 vencida con falta completa → 10 % (no 100 %); sesión
cancelada y solicitud pendiente/rechazada no suman; extraordinaria aprobada suma.

## C. D1 — Aviso de falta por sesión (correo, uno por estudiante y sesión)

**Regla:** cuando una sesión termina (ventana cerrada y todas sus tomas cerradas), cada estudiante con al menos una toma en
SJC recibe **un** correo. Contenido: "falta general" si quedó SJC en todas las tomas; si no, la lista de tomas en falta
con su hora (punto de control, hora institucional); fecha límite para reclamar (`ufn_calcular_fecha_limite_justificacion`,
parámetro `ASISTENCIA/DIAS_LIMITE_JUSTIFICACION`) y enlace a la materia. Sin aviso: sesión cancelada, sin tomas, o
estudiante sin SJC. Las tomas "sin registro" no se mencionan.

### Base de datos
| Objeto | Definición |
| :--- | :--- |
| Tabla `AvisoFaltaSesion` | `sesion UNIQUEIDENTIFIER PK FK Sesion`, `fechaAvisoUtc DATETIME2(3) NOT NULL`, `totalEstudiantesAvisados INT NOT NULL`, `idCorrelacion UNIQUEIDENTIFIER NOT NULL`. Una fila = sesión ya avisada. |
| Parámetros (grupo `AVISO_FALTA_SESION`) | `HABILITADO` BOOLEAN `true`; `LOTE` INT `50`; `HORAS_MAXIMAS_ATRASO` INT `24` (no se avisan sesiones que terminaron hace más de N horas: evita correos masivos al desplegar o recargar datos). No editables por el administrador. |
| `usp_consultar_sesiones_pendientes_aviso_falta (@idCorrelacion, @tamanoLote INT = NULL)` | Comando de sistema (sin usuario). Filas `idSesion, idGrupo, fechaHoraFinUtc` de sesiones: no canceladas, con ≥ 1 toma, todas sus tomas cerradas, `ventanaCierreUtc <= SYSUTCDATETIME()`, `ventanaCierreUtc >= SYSUTCDATETIME() - HORAS_MAXIMAS_ATRASO`, sin fila en `AvisoFaltaSesion`. Orden por `fechaHoraFin`. Lote = parámetro si `@tamanoLote` es NULL. Si `HABILITADO = false` → 0 filas. |
| `usp_consultar_faltas_sesion_aviso (@idSesion, @idCorrelacion)` | Comando de sistema. Una fila por (estudiante con SJC, toma en SJC): `idSesion, idGrupo, idAsignatura, nombreAsignatura, nombreGrupo, fechaHoraInicioUtc, fechaHoraFinUtc, idUsuarioEstudiante, nombreEstudiante, correoEstudiante, numeroToma, fechaPuntoControlUtc, totalTomasSesion, totalTomasEnFalta, minutosFalta, fechaLimiteReclamoUtc`. Solo matrículas activas con usuario activo y correo. |
| `usp_registrar_aviso_falta_sesion (@idSesion, @totalEstudiantesAvisados, @idCorrelacion)` | Comando de sistema transaccional, idempotente (si ya existe la fila: éxito sin escritura). Tupla canónica. |
| Plantilla `FALTA_ASISTENCIA_SESION_ESTUDIANTE` (es, v1) | Marcadores: `estudiante, asignatura, grupo, fecha, horaInicio, horaFin, detalleFaltas, fechaLimiteReclamo, enlaceReclamo`. Asunto: `Registro de inasistencia: {asignatura} ({fecha})`. Cuerpo (texto por defecto, replicado en `PlantillaPorDefectoCatalogo`): `Hola {estudiante}. En la sesión de {asignatura} del grupo {grupo} del {fecha} de {horaInicio} a {horaFin} quedó registrada inasistencia: {detalleFaltas}. Si consideras que hay un error, puedes radicar un reclamo por cada toma hasta el {fechaLimiteReclamo} desde {enlaceReclamo}.` |
| Migración | `up/down` del número siguiente + marcadores en `scripts/migrar-marcadores.json`. Manifiesto post-freeze actualizado con `freeze-manifest.ps1`. |

### Backend
- Constante `Notificacion.TIPO_FALTA_ASISTENCIA_SESION_ESTUDIANTE`.
- Caso de uso `AvisarFaltasSesionUseCase` (feature `application/features/tomaasistencia/avisarfaltassesion`, puerto
  primario + impl + puerto secundario en el repositorio de tomas o uno nuevo `AvisoFaltaSesionRepositoryPort`), invocado en
  la pasada de `RotacionTokenAsistenciaScheduler` **después** de `cerrarVencidas` (mismo try/catch aislado por paso).
- Por sesión pendiente: consulta las faltas, arma **una `Notificacion` por estudiante** (destinatario único, rol
  ESTUDIANTE), `detalleFaltas` = `"falta general (no registró asistencia en ninguna toma)"` si `totalTomasEnFalta =
  totalTomasSesion`, si no `"toma 1 (08:15), toma 3 (09:40)"` en hora institucional (`America/Bogota`, igual que
  `AvisoSesionSupport`). `enlaceReclamo` = `{SMTP_NOTIFICATION_PLATFORM_URL}/app/estudiante/mis-materias/materias?materia={idAsignatura}&grupo={idGrupo}` (query params ya soportados por el frontend). Luego registra la marca con el total avisado. Mejor esfuerzo: un fallo por estudiante se registra y continúa; un fallo de la sesión no la marca (se reintenta en la siguiente pasada).
- Sin evento realtime nuevo. Sin endpoint nuevo.

**Pruebas:** unitarias del caso de uso (falta general, faltas parciales, sin destinatarios, fallo de envío), IT del
contrato de SP (`SqlStoredProcedureContractIT`) y de BD (sesión con 3 tomas, estudiante 1-3 → un aviso con "toma 2";
segunda pasada no repite; sesión de hace > 24 h no se avisa).

## D. D6 — Solicitudes de sesión en el menú

| Capa | Definición |
| :--- | :--- |
| BD | `usp_consultar_solicitudes_sesion_docente_paginado (@idUsuario, @soloPendientes BIT = 1, @idGrupo UNIQUEIDENTIFIER = NULL, @numeroPagina INT = 1, @tamanoPagina INT = 20, @idCorrelacion)`: RBAC DOCENTE; solo solicitudes de grupos donde es titular; mismas columnas y orden que `usp_consultar_solicitudes_sesion_coordinador_paginado` + `totalRegistros`; reutilizar validaciones internas (no copiar preámbulos: Sonar 3 %). |
| Backend | `GET /api/v1/docente/sesiones/solicitudes?soloPendientes=true&grupoId&pagina=1&tamano=20` → `ApiPageResponse<SolicitudSesionResponse>` (mismo record del coordinador). Alta en `access-catalog.json` (DOCENTE) y `HTTP_AS_IS_MATRIX.md`. |
| Realtime | Evento nuevo **`SESION_SOLICITUD_RECHAZADA`** publicado al rechazar (payload `grupo, sesion, fechaHoraInicio, docente` como `SESION_SOLICITUD_CREADA`), audiencia AMBITO_GRUPO + DOCENTE_TITULAR. La aprobación sigue publicando `SESION_MANUAL_CREADA`. Actualizar `REALTIME_EVENT_CONTRACT.md` y su `.sha256`. |
| Frontend | Entrada de menú **"Solicitudes de sesión"**: coordinador `/app/coordinador/solicitudes-sesion` (reubica `CoordinatorSolicitudesSesionComponent`, que sale de la página "Asistencia"); docente `/app/docente/solicitudes-sesion` (lista de solo lectura de sus solicitudes con estado, filtro pendientes/todas, paginación). Contador en el menú = `total` de la consulta con `soloPendientes=true, tamano=1` del rol; se recarga al fijar el rol y con los eventos `SESION_SOLICITUD_CREADA`, `SESION_SOLICITUD_RECHAZADA` y `SESION_MANUAL_CREADA` (SSE, sin polling). |

## E. D7 — Horario semanal con fechas

| Capa | Definición |
| :--- | :--- |
| BD | Vista `uv_sesion_calendario`: una fila por sesión con `idSesion, idGrupo, codigoGrupo, nombreGrupo, idAsignatura, codigoAsignatura, nombreAsignatura, idDocente, nombreDocente, fechaHoraInicioUtc, fechaHoraFinUtc, esExtraordinaria BIT (sesión manual, uv_sesion_manual), estaCancelada BIT, motivoCancelacion, esCancelacionAutomatica BIT, nombreDiaFestivo`, excluye solicitudes pendientes o rechazadas. SP `usp_consultar_sesiones_calendario_estudiante (@idUsuario, @desde DATE, @hasta DATE, @idCorrelacion)` (grupos con matrícula activa del estudiante) y `usp_consultar_sesiones_calendario_docente (@idUsuario, @desde, @hasta, @idCorrelacion)` (grupos donde es titular). Rango en fecha local institucional, `@hasta >= @desde`, máximo 31 días (si no → THROW 51000 con mensaje de catálogo nuevo `CAL_001`). Orden por inicio. |
| Backend | `GET /api/v1/estudiante/sesiones/calendario?desde=YYYY-MM-DD&hasta=YYYY-MM-DD` y `GET /api/v1/docente/sesiones/calendario?desde&hasta` → `ApiDataResponse<List<SesionCalendarioResponse>>` con `idSesion, idGrupo, codigoGrupo, nombreGrupo, idAsignatura, codigoAsignatura, nombreAsignatura, nombreDocente, fechaHoraInicioUtc, fechaHoraFinUtc (ISO-8601 con Z), esExtraordinaria, estaCancelada, motivoCancelacion, esCancelacionAutomatica, nombreDiaFestivo`. Errores 400 con `CAL_001`. Alta en `access-catalog.json` y `HTTP_AS_IS_MATRIX.md`. |
| Frontend | "Mi Horario" de estudiante y docente pasa a semana con fechas (lunes–domingo), navegable (anterior / hoy / siguiente), construida **solo** con el endpoint de calendario (las franjas regulares ya son sesiones). Etiqueta "Extraordinaria" en `esExtraordinaria`; canceladas tachadas con motivo o festivo. Los endpoints `/horarios` quedan sin uso en esas vistas (no se retiran). Horas en zona institucional con `SessionTimeZoneService`. |

## F. D8 y D4 en la pantalla de la toma (solo frontend)
- **D8:** al pulsar un estado igual al ya guardado (sin cambio local), la fila muestra "Ya registrada, sin cambios por guardar" (aria-live), sin habilitar Guardar.
- **D4:** `avisoEdicion` usa el nuevo significado de `editableHastaUtc` (fin de la ventana de la sesión): toma editable →
  "Puedes corregir las tomas de esta sesión hasta las {hora}."; no editable → "La sesión terminó: las tomas quedaron cerradas. Las correcciones se hacen por reclamo.". Se retira el texto de "hasta que abras la siguiente toma".
- **Recordatorio de cierre:** en el panel de tomas, cuando falten ≤ `TOLERANCIA_MINUTOS` (15) para `ventana.cierreUtc`,
  banner "La sesión termina a las {hora}: revisa y cierra las tomas. Al terminar se cerrarán solas y quien no tenga
  registro quedará con falta." Se activa con **un único `setTimeout`** programado al instante de inicio del aviso (no
  `setInterval`, no polling) y se limpia al destruir. El valor de 15 min es constante de presentación del frontend.

## G. Verificación
- Infra: `infra.ps1 verify` en verde (secretos, contratos con `.sha256` regenerados solo para `REALTIME_EVENT_CONTRACT.md`).
- DB: `deploy_schema.ps1` desde cero en contenedor desechable propio + `test_summary.ps1` (exit 0).
- Backend: `mvnw clean verify` y `mvnw clean verify -Pintegration` contra BD desechable con el esquema de la rama.
- Frontend: `npm run verify` (incluye `sync:matriz-hu`/`check:matriz-hu`) y `ng build`.

## H. Ajustes de implementación (2026-11-18)
- D7: los endpoints de calendario viven en `EstudianteSesionCalendarioController` y `DocenteSesionCalendarioController`
  (controladores nuevos) para no alterar los `*PortalController`. `CAL_001` usa texto fijo ("máximo 31 días"); el límite es
  constante del SP.
- D6: un `grupoId` ajeno en `GET /api/v1/docente/sesiones/solicitudes` devuelve página vacía (igual que la bandeja del
  coordinador); paginación inválida → `PAG_001` (400); usuario sin perfil docente → 403.
- D4: la consulta de una toma individual no conoce la ventana de la sesión; `esEditable`/`editableHastaUtc` autoritativos
  solo en `usp_consultar_tomas_sesion`.
- D1: si `SMTP_NOTIFICATION_PLATFORM_URL` está vacía, `enlaceReclamo` se rellena con "la plataforma de asistencia". Si
  fallan todos los envíos de una sesión, no se marca y se reintenta en la siguiente pasada.

## I. D9 — Nueva toma cierra la anterior y el grupo sin modo "Hoy" (2026-11-18, sesión 1b)

Decisiones del usuario (2026-11-18): (1) quien quede sin marca al cerrarse una toma queda con falta — **ya vigente**: el
seed `35_catalogos_toma_asistencia.sql` deja `marcaAusentesAlCerrar = 1` en MANUAL y QR, así que el cierre manual con
`@marcarAusentes = NULL` y `usp_cerrar_tomas_vencidas` marcan SJC; solo se corrige el comentario desactualizado de la
cabecera de `usp_cerrar_toma_asistencia` ("MANUAL 0"). (2) "Nueva toma" con una toma abierta la cierra sola, en el
servidor y en la misma transacción. (3) El texto del recordatorio de cierre ya es correcto. (4) Se retira el modo "Hoy"
del grupo del docente y "Padrón y retiros" abre directo la matrícula.

### I.1 Base de datos
| Objeto | Cambio |
| :--- | :--- |
| `usp_internal_cerrar_toma` (nuevo, interno, sin GRANT) | Extrae de `usp_cerrar_toma_asistencia` el cierre de una toma ya bloqueada: si `@marcarAusentes` (NULL ⇒ `ModoTomaAsistencia.marcaAusentesAlCerrar`) y la ventana de la sesión sigue abierta, marca SJC con `usp_internal_marcar_ausentes_toma`; cierra el token QR activo; pone estado CERRADA, `fechaCierreUtc`, `idCorrelacionCierre`, `totalAusentesMarcados`. Devuelve por OUTPUT `@totalAusentesMarcados` y `@fechaCierreUtc`. Sin transacción propia (la gobierna el llamador). `usp_cerrar_toma_asistencia` pasa a usarlo sin cambiar firma, resultset ni mensajes. |
| `usp_abrir_toma_asistencia` | Orden de validación: titularidad → modo → ventana → **máximo de tomas (TOM_004, sin cerrar nada)** → si hay toma abierta, la cierra con `usp_internal_cerrar_toma` (`@marcarAusentes = NULL`, mismo `@idCorrelacion`) y continúa → inserta la nueva. **TOM_003 deja de emitirse** (se conserva en el catálogo). Todo en la misma transacción; si algo falla no se cierra la anterior. Resultset: mismas columnas y orden + al final `idTomaCerradaAnterior UNIQUEIDENTIFIER NULL`, `numeroTomaCerradaAnterior SMALLINT NULL`, `totalAusentesMarcadosAnterior INT NULL` (NULL si no había toma abierta o si `estadoResultado = 0`). |
| Migración `53_ata_nueva_toma_cierra_anterior` (up/down) | Crea/elimina `usp_internal_cerrar_toma` y recompila los dos SP; marcadores en `scripts/migrar-marcadores.json`; manifiesto post-freeze. |

Pruebas BD: abrir con toma abierta ⇒ la anterior queda CERRADA con SJC a los sin marca y la nueva ABIERTA (numero + 1);
con 20 tomas y una abierta ⇒ TOM_004 y la abierta sigue abierta; sin toma abierta ⇒ columnas nuevas NULL; cierre manual
sin cambios de comportamiento. Las pruebas que esperaban TOM_003 se actualizan por este addendum.

### I.2 Backend
- `POST /api/v1/sesiones/{sesionId}/tomas` (sin cambio de ruta ni de petición): `TomaAsistenciaResponse` gana el campo
  aditivo `tomaCerradaAnterior` (`{ idToma, numero, totalAusentesMarcados }` o `null`).
- Si se cerró una anterior, tras el commit se emiten, en este orden, `TOMA_CERRADA` (payload vigente, `automatico =
  false`, `totalFaltantes` de la toma cerrada si el puerto ya lo provee; si no, se omite como en el cierre automático) y
  `ASISTENCIAS_TOMA_ACTUALIZADAS` de la anterior, y luego `TOMA_ABIERTA` de la nueva. Sin cambio del
  `REALTIME_EVENT_CONTRACT`.
- `SqlStoredProcedureContractIT` con las tres columnas nuevas; pruebas unitarias del caso de uso y del controlador.

### I.3 Frontend
- **Nueva toma:** habilitada aunque haya una toma abierta (se retira "Hay una toma abierta; ciérrala para abrir otra.").
  Con una toma abierta, el botón pide confirmación: "Se cerrará la toma {n}: quien no tenga marca quedará con falta.
  Podrás corregirla hasta que termine la sesión." Si la toma abierta tiene cambios sin guardar, el diálogo lo dice y no
  deja confirmar hasta guardarlos o descartarlos. Tras abrir, el aviso de éxito usa `tomaCerradaAnterior` del servidor
  ("Se cerró la toma {n} ({k} ausentes) y se abrió la toma {n+1}").
- **Grupo del docente (Mis Grupos):** se retira el modo "Hoy" (y su conmutador Hoy/Grupo); el grupo abre en "Planilla".
  Las decisiones por inasistencia se mantienen. Si el encabezado del grupo no tiene acceso a la toma, se agrega la acción
  primaria "Tomar asistencia" (lleva a `/app/asistencia?courseId=…`).
- **"Padrón y retiros"** (menú "Más" de Tomar Asistencia) navega a `/app/docente/grupos?grupo={id}&pestana=ESTUDIANTES`
  y el grupo abre en la pestaña "Matrícula". Un valor de `pestana` desconocido abre "Planilla".
- Pruebas: specs del panel/diálogo de nueva toma, del hub sin modo Hoy y de la navegación con `pestana`.

### I.4 Verificación
Igual que G, más la simulación de laboratorio (`scratch/reloj-sesion.ps1`): 4 tomas manuales cada 30 min sin cerrar a
mano ⇒ cada "Nueva toma" cierra la anterior con faltas a los sin marca, y el cierre automático cierra la última.
