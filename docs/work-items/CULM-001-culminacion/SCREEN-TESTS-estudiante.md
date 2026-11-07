# SCREEN-TESTS-estudiante (CULM-001 Fase 1)

Guion para el probador en pantalla. Rol: ESTUDIANTE, usuario `uco-estudiante` (Carlos; la clave está en `docs/CREDENCIALES_PRUEBAS_LOCAL.md`, no copiarla aquí). Ejecutar en serie, un rol a la vez. En cada paso abrir la consola (errores) y la pestaña Red (códigos HTTP y `X-Correlation-Id`). **[M]** = repetir en móvil 375x812. **[DATOS]** = necesita datos previos de otro rol.

Datos conocidos de la BD (solo lectura): asignatura "Arquitectura de Software" (`E2F3A4B5-...0001`). Carlos está en el grupo `...5C6D` (activo; 2 sesiones ejecutadas, 0 asistencias registradas para él) y en el grupo `...5C23` (estado de matrícula `I`, 0 sesiones). Ana solo está en `...5C6D` con 2 asistencias. Existe una solicitud de revisión `REC-0FBDC18D` en estado `rechazada`: comprobar que Carlos no la ve si no es suya.

## 0. Preparación
1. Abrir `http://localhost:4200` en ventana limpia. Esperado: portada pública sin errores de consola. **[M]**
2. Ir directo a `http://localhost:4200/app/estudiante/materias` sin sesión. Esperado: redirige a login, sin mostrar datos.

## 1. Login y dashboard
3. Botón de ingreso, formulario Keycloak (`keycloak.localhost:19090`), `uco-estudiante` + clave. Esperado: vuelve a la app autenticado y aterriza en `/app/estudiante/horarios`. Red: ningún token en la URL. Application: `localStorage`/`sessionStorage` sin JWT. **[M]**
4. Login con clave incorrecta (en Keycloak). Esperado: mensaje del proveedor, la app no se rompe.
5. Ruta `/app` (overview). Esperado: contenido propio del estudiante o redirección razonable; anotar si aparece un dashboard vacío o genérico. **[M]**
6. Menú lateral. Esperado: Horarios, Materias, Reclamos, Oferta, Solicitudes (las dos últimas se retirarán: anotar que existen hoy). Probar menú hamburguesa y cierre en móvil. **[M]**
7. Escribir URLs de otros roles: `/app/docente/...`, `/app/coordinador/estudiantes`, `/app/admin/estudiantes`, `/app/decano/estudiantes`. Esperado: redirige a la landing del estudiante (role guard) sin llamadas de datos.

## 2. Materias, detalle y % de inasistencia (HU001, HU002, HU003, HU004, HU007, HU009, HU013, HU018, HU019, HU024)
8. `/app/estudiante/materias`. Esperado: tarjeta "Arquitectura de Software" con grupo y contador "Materias Inscritas". Anotar si salen dos tarjetas (grupo activo y grupo con matrícula `I`). Red: `GET /estudiante/materias` 200 (guardar `X-Correlation-Id`). Anotar si la tarjeta dice "Asistencia: No disponible" y si faltan código, docente, horario y créditos (sospecha F-EST-001). **[M]**
9. Tarjetas "Promedio de Asistencia" y "Fallas Registradas". Esperado según BD: 0 faltas y 0% de inasistencia para Carlos. Anotar lo que muestra. **[M]**
10. Estado de carga: recargar con red "Slow 3G" y observar el esqueleto. **[M]**
11. Estado de error: en DevTools bloquear `*/estudiante/materias*` y recargar. Esperado: bloque de error con "Reintentar"; quitar el bloqueo y reintentar. **[M]**
12. Buscar controles de búsqueda/filtro de materias (HU007), acordeón por semestre (HU018) y barra de créditos (HU019). Anotar si no existen (sospecha F-EST-006).
13. "Ver Detalle" del grupo activo. Esperado: cabecera con nombre y grupo; lista de sesiones. Red: `GET /estudiante/materias/{id}/sesiones` 200. Anotar número de sesiones, estado por sesión (Presente/Falta/Justificada/No disponible), fecha/hora y zona horaria, leyenda de estados (HU024). Comprobar que no aparecen sesiones del grupo inactivo mezcladas. **[M]**
14. Bloque desplegable "¿Por qué motivos puedo justificar una inasistencia?" (HU005/HU016). Esperado: 6 categorías de `GET /categorias-justificacion`. **[M]**
15. Comparar el % de inasistencia visible (si lo hay) con la BD: Carlos = 0.00 (2 sesiones ejecutadas, 0 faltas). Anotar diferencias.
16. Botón "Volver" y botón atrás del navegador desde el detalle. Anotar si el atrás del navegador sale de la sección (el detalle es un estado interno sin ruta).
17. Lista de compañeros del grupo (HU003): buscar el modal. Anotar si no existe.
18. [DATOS] Para ver un % distinto de 0: pedir al docente que registre una falta a Carlos en el grupo `...5C6D` (rol docente) y repetir 8, 9 y 13. Comparar con la vista del docente y del coordinador (mismo %).

## 3. Reclamo con soporte (HU010, HU011, HU012, HU014, HU015, HU026B)
19. [DATOS] Requiere una sesión con falta de Carlos (paso 18). En el detalle, el botón de reclamar solo debe salir en sesiones con falta y sin solicitud previa. **[M]**
20. Abrir el formulario de reclamo. Esperado: categoría (catálogo), justificación y adjunto. Enviar vacío: botón deshabilitado o error visible. **[M]**
21. Adjuntar: (a) PDF válido menor de 5 MB, (b) .exe renombrado a .pdf, (c) PNG de 6 MB, (d) archivo de prueba EICAR. Esperado: (a) sube y muestra el nombre; (b)(c)(d) rechazo con mensaje claro; quitar adjunto funciona. Red: `POST /archivos/subir` (código y `code`). **[M]**
22. Enviar el reclamo con prefijo `CULM1-` en el texto. Esperado: éxito con el `mensajeUsuario` del backend; la sesión pasa a "solicitud pendiente". Red: `POST /asistencias/revisiones`. Doble clic rápido: no debe duplicar.
23. Plazo de 5 días (HU026B): si hay una falta de más de 5 días, intentar reclamar. Esperado: bloqueo con mensaje; anotar si deja radicar (sospecha F-EST-010).
24. "Retirar solicitud" en una solicitud pendiente. Esperado: retirada. Sospecha: 501 de `DELETE /estudiante/reclamos/{id}` (F-EST-003). Anotar el mensaje mostrado.
25. `/app/estudiante/reclamos`: lista, filtro Estado, paginación y tamaño de página, "Descargar soporte" (abrir el archivo subido en 22). Esperado: solo reclamos de Carlos. Estado vacío con filtro sin resultados. Anotar formato de fechas y etiquetas de estado. **[M]**
26. [DATOS] El docente resuelve el reclamo. Volver como estudiante SIN recargar: ¿se actualiza por SSE? ¿hay aviso? Luego recargar y comprobar estado y "Respuesta del docente" (sospecha F-EST-007).

## 4. Horario (HU017, HU021)
27. `/app/estudiante/horarios`. Esperado: grilla lunes a viernes con las franjas del grupo; sábado solo si hay clase. Anotar materia, docente y hora, y que coincida con lo que ve el docente. Red: `GET /estudiante/horarios`. **[M]** (en móvil: columnas apiladas, sin scroll horizontal)
28. Estado vacío y de error (bloquear la URL como en 11). Buscar un selector de días (HU021). **[M]**

## 5. Oferta y solicitudes de ingreso (HU008, HU026: se retiran, solo documentar)
29. `/app/estudiante/oferta`. Anotar tarjetas, cupos, badge Vigente/Próximo, botón "Solicitar ingreso" (a retirar), búsqueda con debounce y paginación. No pulsar "Solicitar ingreso" salvo para documentar la respuesta (no registrar como bug). **[M]**
30. `/app/estudiante/solicitudes`. Anotar lista, botón "Solicitar ingreso", filtro por estado y retiro (paquete A). **[M]**

## 6. Matrícula por QR/PIN (HU176B) y auto-asistencia (HU175 lado estudiante, HU176)
31. En Materias: "Matricularse con Código" abre un modal. Probar vacío, "12", letras y "000000". Esperado: mensajes del backend; el modal captura foco, Escape cierra, tiene etiquetas. **[M]**
32. [DATOS] El docente abre una ventana de matrícula QR en un grupo propio. Con PIN válido: matrícula exitosa y nueva tarjeta. PIN expirado/rotado: error claro. Validar red Wi-Fi: desde una red no institucional el backend debe rechazar (anotar mensaje).
33. "Auto-Registro Asistencia" abre un modal de PIN. Probar vacío, "ABCDEF" y sesión no activa. [DATOS] Con sesión activa y PIN real: registro exitoso y la sesión pasa a Presente sin recargar a mano. Anotar si hay lector de cámara QR (HU176 lo menciona). **[M]**
34. Páginas públicas (cerrar sesión antes): `/matricula/pin` (6 dígitos), `/matricula/qr?t=<token falso>` (el token se borra de la URL; error legible), `/verificar-correo` sin token y con token falso, `/register` (esperado: redirige a login). **[M]**
35. [DATOS] Con PIN real: flujo "cuenta nueva" con datos `CULM1-` y flujo "ya tengo cuenta" (login y vuelve con el modal precargado).

## 7. Perfil, notificaciones/alertas y SSE (HU006, HU022, HU026C)
36. `/app/perfil`. Esperado: datos propios en solo lectura; el botón "Editar" no debe existir (el PUT se retira). Anotar si sigue visible. **[M]**
37. Campana o panel de alertas de riesgo (15% y 20%, HU026C). Anotar si hay algún indicador o toast.
38. SSE: en Red filtrar `realtime/stream`. Esperado: una sola conexión abierta con Bearer en cabecera y sin token en la URL. Dejar 3 minutos en Materias: sin llamadas HTTP repetidas (polling). Al cerrar sesión la conexión se cierra.
39. Cerrar sesión desde el menú de usuario y verificar que el botón atrás no muestra datos del estudiante.

## 8. Consistencia entre roles [DATOS]
40. Comparar para Carlos (grupo `...5C6D`) el % de inasistencia y el número de sesiones en la vista estudiante, docente y coordinador. BD: 2 sesiones ejecutadas, 0 asistencias, 0 faltas, 0.00%. La BD muestra 2 sesiones ejecutadas pero 0 asistencias de Carlos: anotar cómo se presenta.
