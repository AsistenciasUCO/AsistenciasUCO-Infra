# SCREEN-TESTS · transversal (seguridad, tiempo real, notificaciones, accesibilidad, móvil)

Ejecutar en serie, un rol a la vez, en `http://localhost:4200`. Login por el botón de ingreso hacia `keycloak.localhost:19090` (usuarios `uco-*`, clave en `docs/CREDENCIALES_PRUEBAS_LOCAL.md`). Cerrar sesión al terminar cada bloque. Abrir DevTools (F12) con las pestañas Application, Network (filtro "Fetch/XHR" y "EventStream") y Console. Marcar con (M) los pasos a repetir en 375×812 (emulación móvil).

## T1. Tokens fuera del almacenamiento (todos los roles) (M)
1. Iniciar sesión con `uco-docente`. DevTools > Application > Local Storage y Session Storage de `localhost:4200`.
2. Esperado: ninguna clave con un JWT (texto `eyJ...`) ni `gestio_*_token`. Solo se acepta el estado PKCE efímero en Session Storage durante el login. Cookies sin tokens de la API.
3. Network: una llamada a `/api/v1/...` lleva `Authorization: Bearer` y ninguna lleva el token en la URL. Consola sin errores rojos. Repetir con `uco-estudiante`.
4. Hallazgo F-TRX-010: en la consola ejecutar `localStorage.setItem('USE_MOCKS','true')`, recargar y anotar si la SPA entra en modo mock. Revertir con `localStorage.removeItem('USE_MOCKS')`.

## T2. SSE en vivo entre dos roles (requiere dos sesiones: docente y estudiante)
Datos previos: grupo `A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D` (SES-01, SES-02) con Carlos matriculado y la docente titular.
1. Sesión A: `uco-docente` en `/app/asistencia` (control de asistencia) del grupo; Network > EventStream: debe aparecer `GET /api/v1/realtime/stream?grupoId=...` en estado pendiente, con `Authorization` y sin token en la URL. Anotar cuánto tarda en pasar a "conectado" (F-TRX-019, puede tardar hasta 25 s).
2. Sesión B (otra ventana de incógnito): `uco-estudiante` en `/app/estudiante/...`: abrir Network y confirmar que NO se abre un stream SSE (F-TRX-006). Anotar si la pantalla se actualiza sin recargar.
3. En A: marcar asistencia por lote ("Todos presentes") sobre una sesión abierta. Esperado en A: evento `ASISTENCIAS_SESION_ACTUALIZADAS` en EventStream y la tabla se actualiza sin recargar.
4. En B: recargar y confirmar que el porcentaje de inasistencia del estudiante coincide con el de la pantalla del docente. Anotar si B se actualizó solo (no debería, F-TRX-005/006).
5. Cortar y restaurar la red (DevTools > Network > Offline y Online): el estado debe pasar a "reconectando" y volver a "conectado" con backoff, sin ráfaga de peticiones.
6. Apagar y encender la pestaña del docente en una sesión sin titularidad: no aplicable (no hay segundo docente).

## T3. Notificaciones visibles
1. `uco-estudiante`: crear un reclamo con soporte (`/app/estudiante/reclamos`). Esperado: toast de confirmación con texto del backend. Si falla con 501 (`POST /estudiante/reclamos`), anotar el mensaje (F-TRX-004).
2. `uco-docente`: resolver el reclamo (`/app/docente/reclamos`). Esperado: toast del backend. Después, en Admin > Notificaciones (`uco-administrador`, `/app/admin/...correos`): cola con el correo del reclamo en estado pendiente o enviado, redirigido a la casilla de prueba. No debería llegar nada al estudiante en pantalla en tiempo real (F-TRX-005).
3. `uco-administrador`: en el panel de correos revisar plantillas, estado del canal y reintento de un envío fallido. Anotar cualquier error 500 (F-TRX-017).

## T4. Teclado, foco y lector de pantalla (rol cualquiera, probar con `uco-docente`) (M)
1. Recargar la página y pulsar Tab: ¿aparece un enlace "saltar al contenido"? (esperado: no, F-TRX-014).
2. Recorrer el menú lateral solo con teclado: cada elemento muestra un anillo de foco visible; el orden de tabulación sigue el orden visual.
3. Abrir cualquier modal (p. ej. crear grupo o corrección de identidad): al abrirse el foco debe pasar al diálogo; Tab no debe salir del modal; Esc lo cierra y devuelve el foco al botón que lo abrió (esperado: falla, F-TRX-014).
4. Paginación de una tabla: Tab hasta los botones de página; en 375 px los botones "Anterior/Siguiente" quedan solo con icono: revisar que el lector anuncie su nombre.
5. Provocar un error (por ejemplo, enviar un formulario vacío): ¿el mensaje se anuncia al lector (role=alert)? ¿El toast de error es perceptible sin color?
6. Contraste: con la extensión de contraste de DevTools (Elements > Accessibility > Contrast) revisar textos secundarios grises claros, etiquetas de tablas y enlaces verdes; anotar los < 4.5:1 (F-TRX-013).

## T5. Móvil 375×812 (M)
1. DevTools > modo dispositivo 375×812, recargar con `uco-estudiante`. El menú hamburguesa abre el sidebar; el botón tiene nombre accesible; el overlay cierra el menú al tocar fuera; Esc cierra.
2. Sin scroll horizontal en: inicio, mis materias, reclamos, horarios. Tablas con desplazamiento propio o tarjetas. Botones táctiles de al menos 44 px.
3. Repetir con `uco-docente` en control de asistencia y grupos: la lista de estudiantes y los botones de marcación son usables con el pulgar.
4. Consola sin errores rojos en todos los pasos; en Network ninguna petición repetida cada pocos segundos (F-TRX-009).

## T6. Seguridad en pantalla (rutas por URL)
1. Sesión `uco-estudiante`: navegar manualmente a `/app/docente`, `/app/coordinador`, `/app/decano`, `/app/admin`. Esperado: redirección o pantalla de acceso denegado, nunca datos. Repetir con cada rol hacia las rutas de los demás.
2. Con `uco-docente`, abrir directamente `/app/...` de un grupo con un UUID inventado: mensaje del backend (403/404), sin datos ni pantalla en blanco.
3. Cerrar sesión desde el menú de usuario; con el botón Atrás del navegador no debe verse contenido autenticado; en una segunda pestaña abierta, la sesión se cierra (BroadcastChannel).
4. Subida de archivo (estudiante, reclamo con soporte): subir un PDF válido y un archivo con extensión falsa; esperado: aceptado el primero y rechazado el segundo con mensaje del backend; la descarga usa una URL `/api/v1/archivos/{id}`, nunca un host de MinIO.
5. Asistencia por QR/PIN (si la pantalla está habilitada): desde una red que no sea la del campus, el registro debe rechazarse (hoy no hay validación, F-TRX-002); intentar 20 PIN erróneos seguidos y anotar si hay bloqueo (F-TRX-003).
