# CULM-001 Fase 3 - Recorrido de certificacion en pantalla (5 roles)

Fecha: 2026-11-09. Entorno: frontend `http://localhost:4200` (baseline), backend `:8080`, Keycloak `security-baseline`. Navegador integrado, escritorio 1280x800 y movil 375x812. Solo observacion; sin cambios de codigo. Navegacion por clics dentro de la SPA.

Metodo movil: se comprobo `scrollWidth > innerWidth` a nivel de pagina por ruta; los elementos que sobresalen dentro de tablas con scroll interno no se cuentan como hallazgo.
Limitaciones: la ventana del navegador quedo oculta parte del tiempo (capturas solo 2). No se ejecutaron acciones de escritura (cierre masivo, cargas CSV, altas) ni una toma QR de asistencia en vivo: no hay sesion en curso hoy (ver pendientes de datos).

## Estudiante (`uco-estudiante`) - 8 pantallas
| Pantalla | Escritorio | Movil | Evidencia |
| :-- | :-- | :-- | :-- |
| Panel `/app/dashboard` | hallazgo F3-EST-01 | OK | Tarjeta de materia: "Docente No informado", "Horario No informado" aunque el horario semanal lista docente y lunes 08:00 |
| Horarios | OK | OK | Lunes 08:00-10:00 Arquitectura de Software, docente visible |
| Materias | hallazgo F3-EST-01/02 | OK | Sin creditos ni caracter OBL/OPT; "Docente: No informado"; pie "Advertencia desde 15% - perdida desde 20%" |
| Detalle de materia | hallazgo F3-EST-03 | OK | Plazo por sesion "Plazo vencido - vencio el ..." (D.1 OK); sesiones sin registro muestran "Estado no disponible"; "0.08 h con excusa"; sin alertas C.1 porque 0 % (pendiente de datos) |
| Oferta de grupos | OK | OK | Caracter "Obligatoria", cupos, periodo vigente, "Ya estas matriculado" |
| Reclamos | hallazgo F3-EST-04 | OK | 2 reclamos; un solo soporte por reclamo (varios soportes/categoria: pendiente de datos); reclamo "Rechazada" con respuesta "Soporte validado" |
| Mis alertas | OK | OK | "0 alertas" (pendiente de datos: nadie cruzo 15 %/20 %) |
| Marcar por PIN `/app/asistencia/pin` | OK | no probado | Carga: "Solo funciona con la red Wi-Fi del campus UCO", campo PIN de 6 digitos |

## Docente (`uco-docente`) - 10 pantallas/vistas
| Pantalla | Escritorio | Movil | Evidencia |
| :-- | :-- | :-- | :-- |
| Mis grupos | hallazgo F3-DOC-04 | OK | 4 grupos; 2 con el mismo nombre "CULM1-E2E-Grupo Modificado" |
| Control de asistencia del grupo | hallazgo F3-DOC-03 | OK (tabla con scroll interno) | Tarjeta "7 sesiones programadas" vs 9 filas; el selector de sesion lista 13 |
| Detalle del grupo (cronograma, acciones) | OK | OK | Cancelar, Ajustar horario, QR/PIN; en sesiones canceladas los botones estan deshabilitados |
| Sabana (Matriz) | hallazgo F3-DOC-01/02 | OK (scroll interno) | Columna SEGUIMIENTO presente y vacia; celdas por sesion todas "-"; total 5.33 h vs 4.17 h del estudiante |
| Tomas por horas `/app/asistencia` | OK | OK | "Toma 1 Manual Cerrada 0.08 h", "Toma 2 Codigo QR Cerrada 0.08 h"; dialogo "Como tomaras la asistencia?" Manual/Codigo QR; sesion finalizada solo se modifica por reclamo |
| QR/PIN de matricula | OK | no probado | QR (imagen) + PIN; el PIN roto 316277 -> 725410 en ~1-2 min; parametro ROTACION_SEGUNDOS=60; "ventana termina a las 1:12 PM" |
| Matricular manual | OK | no probado | Tipo y numero de documento, buscar, registrar alumno nuevo. Selector de programa para grupo mixto: no visible (grupo 001 es de un solo programa; pendiente de datos) |
| Reclamos | hallazgo F3-DOC-05 | OK | Bandeja con filtro; detalle con categoria "Medico / Salud", soportes (1); "Resolucion registrada el :" sin fecha |
| Horarios | hallazgo F3-DOC-06 | OK | "08:00:00 - 10:00:00" con segundos; "1 estudiantes" en grupos con 0 |
| Panel | hallazgo F3-DOC-04 | OK | "5 asignaturas a cargo", "Hoy a las 17:00:00" |

## Coordinador (`uco-coordinador`) - 12 pantallas
| Pantalla | Escritorio | Movil | Evidencia |
| :-- | :-- | :-- | :-- |
| Panel | hallazgo F3-COO-01 | OK | "Estudiantes matriculados 16"; "Asistencia promedio 92%" |
| Docentes | OK | OK | Filtros, "Carga masiva CSV" (plantilla CSV descargable, .csv UTF-8, max 100 filas/1 MB, "Validar archivo") |
| Planes de estudio | OK | OK | 1 plan INP-2024 |
| Malla (B2) | OK | no probado | Asociar asignatura existente (semestre + caracter), filtro por caracter, Modificar y "Desvincular del plan" por asignatura; ARQ-402 Obligatoria S8 3 creditos |
| Periodos | OK | OK | Solo lectura, 2026-2 ACTUAL |
| Indicadores | hallazgo F3-COO-01 | OK | FALTAS 3, 3.85 % (contra 3.46 % consolidado y 3.13 % sabana) |
| Estudiantes (paginado) | hallazgo F3-COO-02 | OK | "Semestre/Programa/Promedio: No informado" |
| Grupos | OK | OK | 5 grupos, edicion |
| Materias | hallazgo F3-COO-03 | OK | "Horas/Sem 0h" |
| Asistencias | OK | OK | 5 grupos, "Ver sesiones" |
| Consolidado (D.8) | OK | OK (scroll interno) | Columnas % asistencia / inasistencia / EXCUSA / SIN REGISTRO, en riesgo, perdida |
| Revisiones de cancelacion (C.1) | OK (vacio: pendiente de datos) | OK | "No tienes revisiones pendientes" |

## Decano (`uco-decano`) - 16 pantallas
| Pantalla | Escritorio | Movil | Evidencia |
| :-- | :-- | :-- | :-- |
| Panel | hallazgo F3-DEC-02 | OK | "Coordinadores asignados 0", "Docentes de facultad 0", "No hay coordinadores asignados" |
| Indicadores (D.8) | OK | OK | Ausentismo por programa por horas (2.25 h sobre 65 h), aforo |
| Facultad | OK | OK | Resumen ejecutivo |
| Grupos | hallazgo F3-DEC-04 | OK | Columna Horario vacia; modalidad "Catedra Institucional" en todos |
| Detalle de grupo (D.9) | hallazgo F3-DEC-01 | no probado | Sin bucle de redireccion, pero la lista de sesiones queda truncada (ver F3-DEC-01) |
| Programas | OK | hallazgo F3-DEC-05 | Movil: scrollWidth 625 sobre 375 |
| Periodos / Areas / Estructura | OK | OK | |
| Coordinadores | hallazgo F3-DEC-02 | OK | "No se encontraron coordinadores"; botones Nombrar / Carga masiva CSV (plantilla y validacion) / Registrar |
| Estudiantes (paginado) | OK | OK (scroll interno) | 13, paginado |
| Cronograma | hallazgo F3-DEC-06 | OK | 29 sesiones; "Sesion 1 2B5893" frente a "SES-01"; festivo mostrado |
| Docentes / Asignaturas | OK | OK | Asignatura con 1 plan (planes compartidos: pendiente de datos) |
| Consolidado | OK | OK | Igual al del coordinador |
| Revisiones por escalamiento (C.1) | OK (vacio: pendiente de datos) | OK | |

## Administrador (`uco-administrador`) - 17 pantallas
| Pantalla | Escritorio | Movil | Evidencia |
| :-- | :-- | :-- | :-- |
| Panel | hallazgo F3-ADM-02 | OK | "Decanos registrados 4 - En ejercicio activo" con 3 inactivos; "Asistencia promedio campus 100%"; "Asignado:" sin fecha |
| Instituciones (D.9-b) | OK | OK | Solo lectura; codigo y NIT "-" |
| Facultades | hallazgo F3-ADM-01 | OK | Facultades inactivas con "PROGRAMAS 4 / ESTUDIANTES 320" |
| Indicadores (D.8) | OK | OK | Comparativa por facultad (horas) y tendencia con Semana/Mes |
| Decanos | hallazgo F3-ADM-03 | OK | Carga masiva CSV presente; GUID visible como titulo |
| Catalogos / Estados / Areas | OK | OK | Solo consulta |
| Festivos | OK | OK | 19 festivos, recarga por ano |
| Periodos | OK | OK | 2026-2 ACTUAL ACTIVO, editar fechas |
| Docentes | OK | OK (scroll interno) | |
| Estudiantes (D.4) | OK | hallazgo F3-ADM-05 | "Admitir estudiante", "Corregir identidad"; movil: scrollWidth 804 |
| Asignaturas | OK | OK | |
| Sistema: parametros (D.3) | OK | OK | 20 parametros con tipo y rango; la auditoria registra PRM_005 y PRM_008 |
| Sistema: cierre masivo | hallazgo F3-ADM-06 | OK | Selector de periodo; "Ejecutar cierre definitivo" (no ejecutado); historial no disponible |
| Sistema: auditoria (D.6) | OK | OK | Filtro "ID de correlacion"; la apertura de QR de matricula del docente aparece con su correlacion |
| Seguridad | pendiente de entorno F3-ADM-07 | OK | Security UI no carga desde `localhost:5175` |
| Mensajes | OK | OK | MessageUcoLab renderiza (shadow DOM) |
| Correos / notificaciones (D.9) | hallazgo F3-ADM-04 | OK | Muestra host y puerto |

## Transversal
| Aspecto | Resultado |
| :-- | :-- |
| Identidad E.1/E.2 | Color primario verde en login, PIN y paneles. No aparecio ningun `window.confirm` en lo recorrido (no se dispararon acciones destructivas) |
| Menus por rol | OK: estudiante 6, docente 5, coordinador 11, decano 15, administrador 17 entradas, sin rutas cruzadas |
| 404/403 amigables | hallazgo F3-TRX-01 |
| Movil 375x812 | Sin scroll horizontal de pagina salvo `/app/decano/programas` (625) y `/app/admin/estudiantes` (804) |
| 403 `NO_APPLICABLE_POLICY` | No se produjo en ninguna ruta |
| Error de consola | `SessionTimeZoneError` en detalle de grupo del decano (F3-DEC-01) |
| Cierre de sesion | El boton solo tiene `title`, sin `aria-label` (F3-TRX-02) |

## Pendiente de datos (no son defectos)
- Alertas C.1 del estudiante, marca de seguimiento en la sabana y revisiones de cancelacion: nadie cruzo el 15 %/20 %.
- Reclamos con varios soportes y categorias variadas; planes compartidos entre programas y selector de programa en grupos mixtos.
- Toma QR de asistencia en vivo (rotacion): no hay sesion en curso hoy (2026-11-09); solo se verifico la rotacion del PIN/QR de matricula y los modos de toma (Manual/QR) en el dialogo.
- Parametro de rotacion del QR de asistencia: 60 s (ROTACION_SEGUNDOS).
- Cierre masivo: bloqueo RCN_012 no verificado (no se ejecuto).

## Hallazgos
| Codigo | Sev. | Hallazgo | Pasos | Contrato incumplido |
| :-- | :-- | :-- | :-- | :-- |
| F3-DEC-01 | alto | Detalle de grupo del decano: encabezado "13 sesiones" pero solo se pinta "Semana 1" y la primera sesion; consola con `SessionTimeZoneError: Instante o zona IANA invalidos` en `DeanGrupoDetalleComponent.fecha` | Decano > Grupos > "Ver Sesiones" en Grupo 001; leer consola | D.9 (detalle de grupo sin bucle: ya no hay bucle, pero la lista no se muestra); duplica F-ADM-S02 |
| F3-DEC-02 | alto | Decano ve "0 coordinadores" y "No se encontraron coordinadores" en Coordinadores y panel, pero Programas y Estructura muestran coordinador "Andres Felipe Lopez Martinez" | Decano > Coordinadores; Decano > Programas | Alcance/consistencia del decano (MATRIZ-AMBITO) |
| F3-ADM-04 | alto | El estado del canal de correo muestra servidor `smtp.gmail.com` y puerto 587; remitente `<>`, usuario y topes vacios; "Modo de pruebas" aparece como produccion pese a configuracion de pruebas | Administrador > Correos > Canal Gmail / SMTP | D.9 (estado-canal sin host/puerto) |
| F3-ADM-01 | alto | Cada facultad inactiva muestra "PROGRAMAS 4 / ESTUDIANTES 320" mientras Indicadores dice 0 estudiantes y 0 programas | Administrador > Facultades | Consistencia de datos (D.8); parece valor fijo |
| F3-COO-01 | medio | Tres cifras de inasistencia distintas para el mismo grupo: coordinador-Indicadores 3.85 % (faltas por conteo), consolidado y decano 3.46 %, sabana del docente 3.13 % (0.17/5.33 h); estudiante ve 4.17 h dictadas contra 5.33 h; "estudiantes matriculados" 16 en el panel y 13 en Indicadores | Comparar pantallas citadas | C.1/D.8 (calculo por horas dictadas) |
| F3-DOC-01 | medio | La sabana muestra "-" en todas las celdas por sesion aunque hay tomas (Presente/Excusa) y horas de falta; columna SEGUIMIENTO vacia (sin datos de riesgo) | Docente > Grupo 001 > Matriz | C.1 (columna Seguimiento), sabana |
| F3-DOC-02 | medio | Total de horas dictadas distinto entre sabana docente (5.33 h) y vista del estudiante (4.17 h) | Docente > Matriz; Estudiante > Detalle de materia | C.1/D.8 |
| F3-DOC-03 | medio | "7 sesiones programadas" en la tarjeta, 9 filas en el cronograma y 13 en el selector de sesion | Docente > Grupo 001 | B.2 (coherencia de sesiones) |
| F3-EST-01 | medio | "Docente: No informado" y "Horario no informado" en panel, materias y detalle, pese a existir horario y docente en la oferta y el horario semanal | Estudiante > Panel / Materias | D (F-EST) |
| F3-EST-02 | medio | La tarjeta de materia no muestra creditos ni caracter (OBL/OPT) | Estudiante > Materias | B2 / F-EST-006 (`materia.creditos`) |
| F3-ADM-02 | medio | Panel: "Decanos en ejercicio activo: 4" con 3 inactivos; "Asistencia campus 100%" frente a 96.54 % en Indicadores | Administrador > Panel | D.8 |
| F3-ADM-03 | medio | Lista de decanos usa el GUID como titulo de tarjeta | Administrador > Decanos | E (UX) |
| F3-ADM-05 | medio | `/app/admin/estudiantes` desborda la pagina en movil (804 px sobre 375) | Movil 375 > Administrador > Estudiantes | E (movil sin scroll horizontal) |
| F3-DEC-05 | medio | `/app/decano/programas` desborda la pagina en movil (625 px sobre 375) | Movil 375 > Decano > Programas | E (movil) |
| F3-ADM-06 | medio | Cierre masivo: historial "no esta disponible en esta pantalla" y tabla de historial vacia | Administrador > Sistema > Cierre Masivo | D (cierre masivo) |
| F3-TRX-01 | medio | Ruta inexistente o ajena (`/app/noexiste`, `/app/admin/parametros` como estudiante, `/app/docente/grupos` como estudiante) redirige en silencio a `/login` y de ahi al inicio del rol; sin pagina 404/403 | `history.pushState` + popstate dentro de la SPA | E/F-DEC-S09 (404/403 amigables) |
| F3-DEC-04 | bajo | En Grupos del decano la columna Horario esta vacia y la modalidad es "Catedra Institucional" en los 5 grupos | Decano > Grupos | D |
| F3-DEC-06 | bajo | Cronograma: sesiones nuevas con etiqueta "Sesion 1 2B5893" y las antiguas con "SES-01" | Decano > Cronograma | Gobernanza de folios |
| F3-DOC-04 | bajo | Panel docente: "5 asignaturas" frente a 4 grupos en Mis grupos; dos grupos con el mismo nombre | Docente > Panel / Mis grupos | B2 |
| F3-DOC-05 | bajo | Detalle de reclamo: "Resolucion registrada el :" sin fecha | Docente > Reclamos > Revisar en detalle | D.2 |
| F3-DOC-06 | bajo | Horarios y panel con segundos ("08:00:00"), "1 estudiantes" en grupos con 0 inscritos | Docente > Horarios | E (UX) |
| F3-EST-03 | bajo | Sesiones pasadas sin registro muestran "Estado no disponible" en lugar de "Sin registro" | Estudiante > Detalle de materia | D.8 (Sin registro) |
| F3-EST-04 | bajo | Reclamo "Rechazada" con respuesta de texto "Soporte validado" (dato de prueba incoherente) | Estudiante > Reclamos | datos |
| F3-COO-02 | bajo | Estudiantes: Semestre, Programa y Promedio "No informado" | Coordinador > Estudiantes | D |
| F3-COO-03 | bajo | Materias: "Horas/Sem 0h" para ARQ-402 | Coordinador > Materias | D |
| F3-ADM-07 | bajo | Seguridad: "No se pudo cargar Security UI desde http://localhost:5175/security-administration.js" (pendiente de entorno; el mensaje expone una URL local) | Administrador > Seguridad | Entorno / mensajes |
| F3-TRX-02 | bajo | Boton "Cerrar sesion" sin `aria-label` (solo `title`); dialogos de carga masiva no son `role=dialog` | Cualquier rol | a11y (E) |
