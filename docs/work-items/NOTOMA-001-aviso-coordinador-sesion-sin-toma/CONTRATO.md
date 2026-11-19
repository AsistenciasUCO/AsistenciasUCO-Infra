# CONTRATO - NOTOMA-001 (ADDENDUM PROPUESTO, no congelado)

No se modifica ningun contrato WORM congelado (`ADDENDUM_ATA_ASISTENCIA_TOMAS_AVISOS.md` y su `.sha256` quedan intactos). Si el equipo adopta
el cambio, este texto pasa a ser la seccion L de ese addendum con su hash nuevo. Todo es NON_GOLDEN_PATH_EXTENSION: sin cambios en OpenAPI
ni en el contrato de eventos realtime (no hay evento nuevo).

## DB

### Tabla `dbo.AvisoSesionSinToma`
`sesion UNIQUEIDENTIFIER PK` (FK a `Sesion`), `fechaAvisoUtc DATETIME2(3)`, `totalCoordinadoresAvisados INT >= 0`, `idCorrelacion UNIQUEIDENTIFIER`.
Una fila = sesion ya avisada. Sin permisos directos al rol runtime; solo la escribe el SP.

### Parametros (`CatalogoParametro`, grupo `AVISO_SESION_SIN_TOMA`, no editables)
`HABILITADO` BOOLEAN `true`; `LOTE` INT `50`; `HORAS_MAXIMAS_ATRASO` INT `24`. Con `HABILITADO = false` el SP de pendientes devuelve 0 filas.

### `usp_consultar_sesiones_pendientes_aviso_sin_toma (@idCorrelacion, @tamanoLote = NULL)`
Comando de sistema (sin usuario). Resultset: `idSesion`, `idGrupo`, `fechaHoraFinUtc`; orden fin, id. Reglas del PLAN. Lote: `@tamanoLote` o `LOTE`.

### `usp_consultar_destinatarios_aviso_sin_toma (@idSesion, @idCorrelacion)`
Comando de sistema. Una fila por coordinador destinatario (sin duplicar por persona): `idSesion`, `idGrupo`, `idAsignatura`, `nombreAsignatura`,
`nombreGrupo`, `nombreDocente`, `fechaHoraInicioUtc`, `fechaHoraFinUtc`, `idUsuarioCoordinador`, `nombreCoordinador`, `correoCoordinador`.
Devuelve 0 filas si la sesion no existe, esta cancelada o tiene alguna toma. El correo es de uso interno del `NotificacionPort`.

### `usp_registrar_aviso_sesion_sin_toma (@idSesion, @totalCoordinadoresAvisados, @idCorrelacion)`
Tupla canonica (`idCorrelacion`, `mensajeUsuarioResultado`, `mensajeTecnicoResultado`, `estadoResultado`). Transaccional e idempotente (`UPDLOCK, HOLDLOCK`);
GEN_002 (nulos o negativos) y SES_001 (sesion inexistente). `SET XACT_ABORT ON`.

### Plantilla `SESION_SIN_TOMA_COORDINADOR` (es, v1)
Marcadores obligatorios (`coordinador` = nombre del coordinador destinatario): `coordinador`, `asignatura`, `grupo`, `fecha`, `horaInicio`, `horaFin`, `docente`, `enlaceSesiones`.
Asunto: `Sesión sin toma de asistencia: {asignatura} ({fecha})`.
Cuerpo: `Hola {coordinador}. El docente {docente} no tomó asistencia en la sesión de {asignatura} del grupo {grupo} del {fecha} de {horaInicio} a {horaFin}. Este aviso es solo informativo; puede revisar el grupo en {enlaceSesiones}.`

### Migracion
`57_notoma_aviso_sesion_sin_toma_up.sql` / `_down.sql` (idempotentes; el down borra SP, tabla y parametros y conserva la plantilla, como la 51).

## Backend

- Puerto secundario `AvisoSesionSinTomaRepositoryPort`: `consultarSesionesPendientes()`, `consultarDestinatarios(UUID)`, `registrarAviso(UUID, int)`.
- Caso de uso `AvisarSesionesSinTomaUseCase.execute()` devuelve cuantas sesiones se marcaron. UNA `Notificacion` por coordinador (mejor esfuerzo por persona, como el aviso de falta a estudiantes), tipo `SESION_SIN_TOMA_COORDINADOR`, destinatario unico con rol `COORDINADOR` y saludo con su nombre.
- Si falla el encolado de TODOS los coordinadores, la sesion no se marca; si falla solo alguno, se marca con los avisados. Un fallo de consulta o de marca tampoco marca; se reintenta en la siguiente pasada. Sin destinatarios: se marca con 0.
- Paso nuevo del scheduler tras el aviso de faltas; nunca propaga excepciones; correlacion propia por pasada.
- `enlaceSesiones` = `<platform-url>/app/coordinador/asistencia`; sin URL configurada se nombra la plataforma sin enlace (igual que el aviso de falta).

## Decisiones abiertas para el dueno del producto

1. Momento del aviso: al vencer la ventana de cierre (fin + margen), como el aviso de faltas. Alternativa: al terminar la hora de fin.
2. Decano: no se avisa (la regla pedida es solo coordinacion).
3. Grupos compartidos: se avisa a los coordinadores de cada programa vigente del grupo, una vez por persona.
4. Evento realtime: no se publica ninguno.
