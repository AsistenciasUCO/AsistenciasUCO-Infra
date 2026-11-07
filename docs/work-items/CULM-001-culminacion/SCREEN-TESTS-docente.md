# SCREEN-TESTS-docente — Guion de recorrido en pantalla (CULM-001 Fase 1)

Usuario: `uco-docente` (María Rostagno), clave en el documento de credenciales. App: `http://localhost:4200`.
Grupos de María: `Grupo 001 - Arq Software` (G1, 10 activos, cupo 30) y `Grupo 03 (prueba)` (G2, 5 activos, cupo 42). Solo hay 1 docente sembrado (no hay grupos ajenos, F-DOC-014).
En todos los pasos: consola sin errores; en Red cada llamada 2xx (salvo lo indicado) con `X-Correlation-Id`. Registros nuevos con prefijo `CULM1-`. No cerrar ni cancelar grupos/periodos; no retirar estudiantes sembrados.
Marcas: **[M]** repetir en móvil 375x812; **[T]** tablet 768x1024; **[PRE]** requiere datos previos de otro rol.
Precondición: la BD solo tiene 2 sesiones (ago-2026). En P7 crear `CULM1-Sesion hoy` (hoy, inicio ~5 min antes, fin ~2 h después) y `CULM1-Sesion futura` (mañana).
Prerrequisito de entorno: el backend debe aceptar tokens baseline (F-DOC-001), si no el login en pantalla también fallará con 401.

## P1 Login y dashboard (HU031) [M]
1. `/` → ingreso → formulario Keycloak → `uco-docente`. Esperado: llega al dashboard o a `/app/docente/grupos`, sin 401/403 del PDP.
2. `/app/dashboard`: tarjetas del docente, enlaces a reclamos y grupos, estados carga/vacío. Contadores coherentes con P4 y P11.
3. Menú lateral: debe haber "Mis Grupos" y "Mis Horarios"; anotar que faltan "Reclamos" y "Tomar asistencia" (F-DOC-008).

## P2 Lista de grupos (HU031, HU043, HU058) [M][T]
1. `/app/docente/grupos`: exactamente 2 grupos. Probar filtro "Nivel formativo" (HU058), búsqueda, estado vacío (texto inexistente).
2. Comparar cupo y activos con BD (10/30 y 5/42).
3. Manipular la URL/estado con un GUID inventado: mensaje del backend, sin datos.

## P3 Hub y configuración (HU043, HU044) [M][T]
1. Entrar a G1: pestañas Estudiantes, Sesiones, Sábana, Horarios, Reclamos, Solicitudes de ingreso, Configuración.
2. HU044: en G2 editar observaciones a `CULM1-obs`, guardar (toast del backend); aforo menor a los 5 activos → error con mensaje del backend; restaurar el valor original.
3. Botones: debe verse "QR / PIN Matrícula"; NO "Proyectar Auto-Registro" (flag apagada).

## P4 Padrón (HU032, HU052, HU051) [M][T]
1. Pestaña Estudiantes de G1: 10 filas; buscador predictivo; estado vacío. Anotar ausencia de paginación (F-DOC-007) y comportamiento de la tabla en 375 px.
2. HU051: abrir modal "Retirar" en un estudiante: validar motivo vacío y >500 caracteres; **cancelar**. Retirar solo un estudiante `CULM1-` creado en P5.

## P5 Matrícula manual y por QR/PIN (HU050, HU176B) [M][T]
1. Matrícula manual (`/app/asistencia` → matricular): crear `CULM1-Estudiante Uno` (correo `culm1.uno@example.com`). Probar vacíos, documento duplicado, correo inválido. El padrón y el contador de cupo se actualizan sin recargar (SSE). Simular fallo de la búsqueda previa (modo offline) y observar F-DOC-006.
2. "QR / PIN Matrícula" en G2: QR, PIN, enlace, cuenta regresiva; copiar PIN/enlace (toast); "Regenerar" cambia el código; esperar una rotación automática: llega por SSE (Red sin llamadas repetidas).
3. [PRE estudiante] con `uco-estudiante`/enlace público usar PIN o enlace; el modal del docente debe reaccionar (evento `ESTUDIANTE_MATRICULADO`).
4. "Cerrar matrícula": el enlace anterior debe dar error del backend.
5. Reconexión SSE: modo offline y restaurar → el modal pide un código fresco.
6. [M] QR dentro de 375 px y PIN legible.

## P6 Solicitudes de ingreso (HU053–055, SE RETIRAN) [M]
1. Pestaña "Solicitudes de ingreso": solo documentar contenido y estado vacío (inventario en FINDINGS). No es bug.

## P7 Sesiones (HU028, HU030, HU034, HU045–HU049, HU059) [M][T]
1. Pestaña Sesiones de G1: lista con badges y folio SES-xx.
2. Crear `CULM1-Sesion hoy` (aula `CULM1-A1`): 201, folio asignado por backend.
3. HU034: crear otra que se cruce con la anterior (también en G2): error de cruce con mensaje del backend.
4. Validaciones: fecha vacía, fin < inicio, zona horaria; anotar cuáles mensajes son fijos del frontend.
5. Crear `CULM1-Sesion futura`; editarla (hora y aula) → "Sesión actualizada."; verificar en `/app/docente/horarios`.
6. HU047: no debe aparecer "Cancelar sesión".
7. Detalle de sesión (modal) [M].

## P8 Tomar asistencia en sesión activa (HU027, HU029, HU033, HU040, HU041, HU056) [M][T]
1. `/app/asistencia?courseId=<G1>` → `CULM1-Sesion hoy`: ventana ABIERTA, 10 estudiantes activos.
2. "Todos Presentes" → guardar: `POST /api/v1/asistencias/lote` 200, toast del backend.
3. Marcar 2 ausentes y 1 excusa, guardar, recargar: persiste.
4. Métricas y semáforo (HU040/041): comparar % con la sábana (P10) y con `/app/estudiante/materias` [PRE estudiante].
5. SSE: misma sesión en dos pestañas; guardar en una y ver el cambio en la otra sin recargar.
6. "Proyectar QR" (HU175): debe mostrar QR/PIN reales o no ofrecerse; hoy muestra QR simulado y PIN `392-817` (F-DOC-002). Confirmar que el estudiante no puede usarlo.

## P9 Fuera de ventana (SES-01) [M]
1. Elegir `CULM1-Sesion futura` y una sesión de agosto: botones deshabilitados y texto de ventana.
2. Forzar el envío tras vencer la ventana (editar fin de la sesión de hoy al pasado sin recargar la planilla): `POST /asistencias/lote` 409 `ERR_SESION_NO_INICIADA`/`ERR_SESION_CERRADA` y la pantalla muestra el `message` del backend.

## P10 Sábana (HU029, HU040) [M][T]
1. Pestaña Sábana de G1: columna de estudiante fija, scroll horizontal, leyenda.
2. Comparar "faltas / total" y % con BD y estudiante (F-DOC-004: el % es del cliente, denominador = todas las sesiones).
3. [M] la matriz se lee con scroll horizontal sin romper el layout.

## P11 Reclamos (HU035–HU039, HU042) [M][T][PRE estudiante]
1. [PRE] `uco-estudiante` crea un reclamo `CULM1-` con PDF pequeño.
2. `/app/docente/reclamos`: pendiente, filtro por estado, paginación, detalle con causal, soporte descargable (200 vía API, sin URL directa de MinIO).
3. Aprobar con observación; rechazar otro; el estudiante recibe notificación por SSE (HU042) y su % cambia.
4. Resolver dos veces el mismo reclamo: 409 con mensaje del backend.
5. Estados vacío y error (offline) con reintento. Comprobar que `teacherClaimsEnabled:false` no oculta nada (F-DOC-009).

## P12 Horario y perfil [M][T]
1. `/app/docente/horarios`: franjas, vacío, error (mensaje fijo, F-DOC-005).
2. `/app/perfil`: carga y comportamiento con `userProfileEndpointEnabled:false`.

## P13 SSE y notificaciones [M]
1. Red: una sola conexión `/api/v1/realtime/stream` sin token en la URL; sin peticiones periódicas durante 2 min en hub, asistencia y reclamos.
2. Campana de notificaciones: matrícula, reclamo nuevo, retiro.

## P14 Cierre
1. Menú de usuario → cerrar sesión: vuelve al login. Revisar consola acumulada: 0 errores.
