# PLAN - NOTOMA-001 aviso al coordinador de sesion sin toma de asistencia

Fecha: 2026-11-19. Ramas `feat/aviso-coordinador-sesion-sin-toma` desde `repo-antiguo/develop` (Backend 9adf99fb, DB dadf8dc) y `origin/develop` (Infra 50bd0be). Frontend: sin cambios.
Pipeline SDD/TDD: PLAN (01) -> CONTRACT (02) -> TEST RED (03) -> IMPLEMENT GREEN (04) -> AUDIT (05) -> CLOSURE (06).

## Objetivo

Cuando una sesion termina (su ventana de registro ya vencio) y el docente NO hizo ninguna toma de asistencia, el sistema envia UN correo a
la coordinacion del programa del grupo informando que el docente no tomo asistencia. Una sola vez por sesion (idempotente). El correo solo
informa: el coordinador sigue siendo de solo lectura sobre la asistencia.

## Hueco que cubre

El aviso de falta por sesion a estudiantes (ADDENDUM_ATA_ASISTENCIA_TOMAS_AVISOS C, `AvisoFaltaSesion`) exige `totalTomas >= 1`, asi que una
sesion sin tomas no avisa a nadie. Este work item reutiliza el mismo patron (consulta de pendientes + datos + marca idempotente + job
del scheduler + plantilla + outbox) sin inventar mecanismos nuevos.

## Alcance por capa

| Capa | Cambio |
|---|---|
| DB | Tabla `AvisoSesionSinToma`; parametros `AVISO_SESION_SIN_TOMA` (HABILITADO, LOTE, HORAS_MAXIMAS_ATRASO); SP `usp_consultar_sesiones_pendientes_aviso_sin_toma`, `usp_consultar_destinatarios_aviso_sin_toma`, `usp_registrar_aviso_sesion_sin_toma`; plantilla `SESION_SIN_TOMA_COORDINADOR` y marcadores; EXECUTE al rol runtime; migracion 57 up/down; prueba T-SQL. |
| Backend | Puerto `AvisoSesionSinTomaRepositoryPort`, caso de uso `AvisarSesionesSinTomaUseCase`, adaptador JPA, tipo `SESION_SIN_TOMA_COORDINADOR`, plantilla por defecto, paso nuevo del `RotacionTokenAsistenciaScheduler`. |
| Frontend | Ninguno (es un correo). No se agregan textos al catalogo de mensajes. |
| Infra | Este work item, indice (2.4) y addendum propuesto (`CONTRATO.md`). |

## Reglas aplicadas

- Sesion no cancelada (una solicitud rechazada ya queda cancelada), con procedencia temporal confirmada, sin solicitud pendiente de aprobacion.
- `totalTomas = 0` y sin registros de asistencia (`DetalleAsistencia`) en la sesion.
- `ventanaCierreUtc <= ahora` (fin + `ASISTENCIA/MARGEN_RETARDO_MINUTOS`) y no mas de `HORAS_MAXIMAS_ATRASO` horas despues (evita correos masivos al cargar datos).
- Sin fila en `AvisoSesionSinToma`.
- Destinatarios: coordinadores activos de TODOS los programas vigentes del grupo (`ufn_programas_grupo`), sin duplicar por persona, con usuario activo y correo.
- Mejor esfuerzo; si falla el envio la sesion no se marca (reintento en la siguiente pasada); sin coordinadores con correo se marca con total 0.

## Fuera de alcance / decisiones abiertas

Ver seccion final de `CONTRATO.md` (momento exacto del aviso, decano, evento realtime).
