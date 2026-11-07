# SCREEN-TESTS administrador (CULM-001 Fase 1)

Usuario: `uco-administrador` (clave común del documento de credenciales). Ejecutar en serie, un rol a la vez, con la consola y la pestaña Red abiertas. Los pasos marcados **[M]** se repiten en vista móvil 375×812. Los datos que se creen llevan prefijo `CULM1-`. No desactivar entidades sembradas. **Nunca ejecutar el cierre masivo real** (paso 31 solo comprueba confirmación y cancelación).

Precondición bloqueante: F-ADM-001 (el backend responde 401 a tokens válidos). Si el login deja la app sin datos, anotar y detener el recorrido; confirmar primero `GET /api/v1/admin/areas` en Red con Bearer.

Para todos los pasos mirar: consola sin errores, Red sin 5xx inesperados, cabecera `X-Correlation-Id` presente y ningún JWT en la URL ni en `localStorage`.

## A. Ingreso y menú
1. `http://localhost:4200` → botón de ingreso → formulario Keycloak → `uco-administrador`. Esperado: aterriza en el panel del administrador. Red: `Authorization: Bearer` en las llamadas `/api/v1`, sin 401.
2. **[M]** Abrir el menú lateral. Esperado: ítems Facultades, Indicadores, Decanos, Tipos de Programa, Estados, Áreas, Períodos, Docentes, Estudiantes, Búsqueda de Asignaturas, Sistema & Auditoría, Seguridad UCO, Mensajes, Correos. No debe aparecer ningún ítem de Sedes, Espacios físicos ni Instituciones (F-ADM-009).
3. Navegar por URL directa a `/app/admin/sedes` y `/app/admin/espacios-fisicos`. Esperado: no existen (redirección o 404 de la app), sin pantalla de sedes.

## B. Catálogos de solo consulta (HU150, HU153, HU154, HU155)
4. **[M]** `/app/admin/areas`. Esperado: tabla Código/Nombre/Estado sin botones de crear, editar ni cambiar estado (HU151/HU152 descartadas). Con la red limitada a "Slow 3G", ver si aparece "Cargando…" o directamente "No hay áreas" (F-ADM-019).
5. **[M]** `/app/admin/catalogos` (Tipos de Programa). Esperado: solo consulta, estado de carga correcto.
6. **[M]** `/app/admin/estados`. Esperado: dos tablas (Estados de solicitudes y Estado del estudiante en el grupo), sin acciones de edición.

## C. Facultades y decanos
7. **[M]** `/app/admin/facultades`. Esperado: lista con paginación (¿es del servidor o del cliente? F-ADM-008), estados vacío y carga. Mirar la red: `GET /admin/facultades` devuelve la lista completa.
8. Crear facultad `CULM1-Facultad Prueba` con un decano existente. Esperado: 201, toast con el mensaje del backend, aparece en la lista. Repetir con el mismo nombre. Esperado: 409 con texto del backend (hoy el texto es fijo con "Conflicto 409", F-ADM-010).
9. Editar el nombre de `CULM1-Facultad Prueba` a `CULM1-Facultad Prueba 2`. Esperado: 200 y lista actualizada. Probar nombre de menos de 3 caracteres y nombre vacío: validación visible y accesible (etiquetas, foco).
10. Cambiar el estado de `CULM1-Facultad Prueba 2` (activar/inactivar). Esperado: 200 y cambio visible; no tocar facultades sembradas.
11. **[M]** `/app/admin/decanos`. Esperado: tarjetas con estado; observar si hay paginación (no hay, F-ADM-008) y la etiqueta `DEC-<documento>` (F-ADM-011).
12. Pulsar "Desactivar" en un decano creado en esta sesión (si no existe, crear uno `CULM1-` con correo `culm1.decano@uco.edu.co`, clave de 12+ caracteres con mayúscula, minúscula, número y símbolo). Esperado hoy: error 501 (F-ADM-002). Registrar mensaje mostrado y la respuesta (`code`, `X-Correlation-Id`).
13. Crear decano `CULM1-` con datos válidos. Esperado: 201 y aparece en la lista. Repetir con el mismo documento y con el mismo correo: 409 con mensaje del backend. Probar contraseña corta y contraseña igual al documento: validación de la UI.
14. HU159: en un decano creado `CULM1-`, abrir "Corregir identidad", cambiar nombres y documento (parámetro `IDENTIDAD/PERMITIR_CORREGIR_DOCUMENTO`=1). Esperado: 200 con mensaje; documento duplicado: 409; documento vacío: 400. No modificar decanos sembrados.

## D. Períodos (HU096–HU098, vista admin)
15. **[M]** `/app/admin/periodos`. Esperado: lista de períodos con acciones crear, editar y eliminar.
16. Crear período `CULM1-` con fechas válidas; luego con fecha fin anterior a la de inicio (400) y con código repetido (409). Esperado: mensajes del backend.
17. Eliminar el período `CULM1-` creado: aparece `window.confirm` nativo (F-ADM-007). Confirmar. Esperado: 200 y desaparece. Intentar eliminar un período sembrado con grupos: NO confirmar.

## E. Estudiantes y ficha unificada (HU157)
18. **[M]** `/app/admin/estudiantes`. Esperado: tabla paginada con total, filtros de facultad y estado; buscar por nombre parcial y por documento con Enter (no hay botón, F-ADM-014).
19. Cambiar tamaño de página y página. Esperado: la petición lleva `pagina`/`tamano` y responde `ApiPageResponse`.
20. Buscar un texto sin resultados. Esperado: "No hay estudiantes que coincidan".
21. Abrir "Ver ficha" de un estudiante sembrado (Carlos o Ana). Esperado: historial con programas, grupos por período y resumen de asistencia; el porcentaje de inasistencia debe coincidir con el que ve el docente y el estudiante (anotar cifra; cruzar con los otros roles).
22. Intentar abrir por URL `GET /api/v1/admin/estudiantes/{id}/historial` con un id inexistente (desde Red/consola). Esperado: 404 sin datos filtrados.
23. HU156: buscar en la pantalla un botón o formulario de "Admitir estudiante". Esperado hoy: no existe (F-ADM-004).
24. `/app/admin/docentes` y `/app/admin/asignaturas`: búsqueda con paginación y sin acciones de edición. **[M]**

## F. Indicadores
25. **[M]** `/app/admin/indicadores`. Esperado: tarjetas de KPI, comparativa por facultad y gráfico de tendencia; cambiar Semana/Mes dispara una sola petición. Ver estilo (paleta `gray`, F-ADM-015) y estado de carga. Dejar 3 minutos y comprobar que no hay llamadas repetidas (sin polling) ni conexión SSE duplicada.

## G. Sistema, parámetros, auditoría y cierre (HU168, HU172, HU174)
26. **[M]** `/app/admin/sistema` pestaña Parámetros. Esperado: tarjetas de parámetros en modo consulta con aviso "Edición de parámetros no disponible" (F-ADM-003); observar constantes técnicas visibles (F-ADM-012). Verificar que `UMBRAL_ALERTA_PERDIDA` muestra 20.
27. En consola: `fetch` de `PUT /api/v1/admin/parametros/{id}` con el id de un parámetro y cuerpo `{"valor":"25"}`. Esperado hoy: 501 (registrar `code` y `X-Correlation-Id`). No intentar con valores reales sobre parámetros de producción.
28. Pestaña Trazabilidad y Auditoría: filtros por defecto (últimos 7 días, "Solo acciones de asistencia" marcado). Esperado: tabla paginada. Desmarcar "Solo acciones de asistencia" y consultar: deben aparecer las acciones hechas en los pasos 8–17 con usuario, acción, recurso, método/ruta, estado y resultado; anotar si se ve `correlationId` (hoy no, F-ADM-013) y comparar con el `X-Correlation-Id` capturado en Red.
29. Rango inválido: desde posterior a hasta y rango mayor de 90 días. Esperado: mensaje de rango; sin llamada al backend. **[M]** comprobar que la tabla de auditoría se desplaza horizontalmente.
30. Filtro por acción (`CREAR_SESION` u otra visible) y por resultado Fallido: la tabla se filtra y la paginación se reinicia.
31. Pestaña Cierre Masivo (**no ejecutar**): ver el período inicial (¿`2026-2` aunque no exista? F-ADM-005), cambiar de período, pulsar "Ejecutar Cierre Masivo" y en el `window.confirm` pulsar **Cancelar**. Esperado: no hay petición `POST /admin/cierre-masivo`. Comprobar rótulo "Simulador" (F-ADM-006), historial vacío y que la tabla de historial se corta a 375 px **[M]**.
32. Botón "Gestión de Correos (SMTP)" del encabezado: navega a `/app/admin/correos`.

## H. Correos y pantallas de otros equipos
33. **[M]** `/app/admin/correos`: plantillas, vista previa, cola con paginación propia y diagnóstico del canal. Probar vista previa con tipo válido; "Reintentar" solo sobre un correo en estado fallido que no sea real. Mirar el banner con jerga interna (F-ADM-018) y los toasts fijos al provocar un fallo (cortar la red).
34. `/app/admin/seguridad` (Seguridad UCO): esperado carga del micro frontend o mensaje de error/permiso legible; sin errores de consola (`process is not defined`). Solo consulta (HU170 pendiente).
35. `/app/admin/mensajes`: esperado carga de MessageUcoLab o estado `error`/`unauthorized` con botón Reintentar. Solo consulta (HU169 pendiente).

## I. Tiempo real y sesión
36. En Red filtrar `realtime/stream`: una sola conexión con Bearer en cabecera y sin token en la URL. Cambiar un dato desde otra pestaña (p. ej. crear período) y ver si la lista abierta se actualiza sin recargar (si no, anotar).
37. Provocar 401 (borrar cookies de Keycloak o esperar la expiración) y 403 (navegar con otro rol a `/app/admin/...` en el paso de cada rol): esperado redirección o mensaje del backend, sin pantalla en blanco.
38. Cerrar sesión desde el menú de usuario. Esperado: vuelve a la pantalla pública, se cierra la conexión SSE y no queda token en `localStorage`/`sessionStorage`.

## J. Pruebas de API cruzadas con roles (para ejecutar por token, después de resolver F-ADM-001)
Obtención de token (sin guardar la clave): PKCE contra `http://keycloak.localhost:19090/realms/security-baseline` con cliente `asistencias-uco-spa` y `redirect_uri=http://localhost:4200/login`; el formulario de Keycloak solo guarda las cookies Secure si se reenvían a mano (curl no las conserva sobre http). Con tokens de `uco-decano` y `uco-coordinador`, verificar 403 en: `GET /admin/decanos`, `GET /admin/facultades`, `POST /admin/facultades`, `GET /admin/parametros`, `PUT /admin/parametros/{id}`, `GET /admin/auditoria`, `POST /admin/cierre-masivo`, `GET /admin/estudiantes`, `GET /admin/notificaciones/cola`, `POST /realtime/emit`. Esperado: 403 `ApiErrorResponse` con `code`, `message` y `X-Correlation-Id`. `GET /admin/areas` debe dar 200 para decano y coordinador (excepción documentada). `POST /admin/cierre-masivo` con administrador y `{}` o `idPeriodoAcademico` no UUID: esperado 400, sin ejecutar nada. `GET /admin/sedes` y `/admin/espacios-fisicos` con administrador: esperado 404.