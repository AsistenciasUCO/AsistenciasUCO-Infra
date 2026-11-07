# CULM-001 · Fase 1 — Brief común para líderes y probadores

> Léelo completo antes de empezar. Es la única referencia compartida; el brief individual de cada líder solo añade su rol y sus HUs.

## 1. Contexto

- Proyecto: Sistema de Gestión de Asistencia UCO (SQL Server + Spring Boot 4 + Angular 19). Cuatro repos en **worktrees** bajo `C:\Proyectos\GestionAsistencia-CULM001\`: `AsistenciasUCO-Infra`, `GestioAsistenciaBackend`, `GestioAsistenciaFrontend`, `GestioAsistenciaDB` (rama `integracion/CULM-001`). **Trabaja solo ahí.** No toques `C:\Proyectos\GestionAsistencia\<repo>` (checkouts originales) salvo para leer los `docs/*.md` del workspace raíz.
- Fase 1 = **auditoría sin cambios de código**. No edites archivos de los repos; solo escribes tus archivos de salida (sección 7).
- Catálogo de HUs (fuente de verdad de estados): `AsistenciasUCO-Infra/docs/user-stories/HU-CATALOG.md` (worktree). Lee solo la sección de tu módulo.
- Rutas del backend por rol: `C:\Proyectos\GestionAsistencia\docs\rutas-por-rol.md` (del 2026-10-29; confirma contra `SecurityConfig.java` y los `*Controller` del worktree del backend si algo no cuadra). Catálogo de accesos del PDP: `GestioAsistenciaBackend/infra/security-baseline/access-catalog.json`. Las sedes fueron retiradas del sistema (RETIRO-SEDES): si ves endpoints, rutas o pantallas de sedes, es hallazgo.
- Usuarios y datos sembrados: `C:\Proyectos\GestionAsistencia\docs\autenticacion-usuarios-y-roles.md` y el documento de credenciales (sección 3).
- Sistema de diseño: `C:\Proyectos\GestionAsistencia\docs\sistema-diseno.md`. SSE: `C:\Proyectos\GestionAsistencia\docs\realtime-sse-architecture.md`. Rutas del frontend: `GestioAsistenciaFrontend/src/app/app.routes.ts` y `src/app/features/<rol>/`.

## 2. Entorno (todo local)

| Servicio | URL |
| :--- | :--- |
| Frontend (worktree) | `http://localhost:4200` |
| Backend (worktree) | `http://localhost:8080/api/v1` · Swagger `http://localhost:8080/swagger-ui.html` · salud `/actuator/health` |
| Keycloak Security Baseline | `http://keycloak.localhost:19090/realms/security-baseline` (el Keycloak propio `:8081` **no existe** en este entorno) |
| PEP / PDP | `http://localhost:18081` / `http://localhost:18080` (si una llamada directa al backend da 401/403 atribuible al PEP/PDP, anótalo con el cuerpo de la respuesta y compara con lo que hace el frontend) |
| SQL Server | `localhost:1433`, contenedor Docker `sql_server_asistencias`, BD `gestionasistenciadb`. Consultas desde PowerShell: `docker exec sql_server_asistencias /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "<clave del documento de credenciales>" -C -d gestionasistenciadb -Q "<T-SQL>"` (en Git Bash exporta antes `MSYS_NO_PATHCONV=1`). **Solo SELECT**; nunca modifiques datos por SQL. |

## 3. Credenciales (nunca las copies a archivos, commits ni a tu reporte)

- Documento: `C:\Proyectos\GestionAsistencia\docs\CREDENCIALES_PRUEBAS_LOCAL.md`. Léelo para obtener el usuario `uco-<rol>` de tu rol, su correo, su GUID en `dbo.Usuario` y la clave común.
- Token por API: `POST http://keycloak.localhost:19090/realms/security-baseline/protocol/openid-connect/token` con `grant_type=password`, `client_id=admin-cli`, `username`, `password` (form-urlencoded). Usa el `access_token` como `Authorization: Bearer`.
- Suite E2E ya adaptada (referencia de cómo llamar a los endpoints y de los GUID de prueba): `AsistenciasUCO-Infra/scripts/tests/test_all_hus.ps1` (lee la clave de la variable de entorno `E2E_PASSWORD`).
- Login en pantalla: `http://localhost:4200` → botón de ingreso → formulario de Keycloak (`keycloak.localhost:19090`) → usuario `uco-<rol>` + clave. Cerrar sesión al terminar cada recorrido (menú de usuario) para no dejar al siguiente rol con la sesión anterior.

## 4. Reglas del proyecto que debes verificar (resumen de `AGENTS.md`)

- Aislamiento jerárquico **dentro de los SP** y en el backend: docente → solo sus grupos; coordinador → solo su programa; decano → solo su facultad; estudiante → solo sus datos. Intentar acceder a datos de otro ámbito (id directo en URL, filtros, búsqueda) debe dar 403/404 **sin filtrar datos**. Cualquier fuga = severidad **crítica**.
- Asistencia la registra solo el docente titular; coordinador y decano son de solo lectura.
- Mensajes al usuario vienen del backend (`mensajeUsuario` / `message`), no de texto fijo del frontend ni de parseo heurístico de errores.
- Reactividad por SSE (`/api/v1/realtime/stream`); **prohibido polling** (`setInterval`, `timer`, llamadas repetidas). Un timer para refrescar datos = hallazgo.
- Frontend: OnPush, `input()/output()`, sin JWT en `localStorage`, sin `bypassSecurityTrust*`, listados paginados con `PaginationComponent`, 0 errores de consola.
- Respuestas: `ApiDataResponse<T>` / `ApiPageResponse<T>` (`elementos`, `numeroPagina`, `tamanoPagina`, `totalElementos`, `totalPaginas`); errores `ApiErrorResponse` con `code`, `message` y cabecera `X-Correlation-Id`.
- 501 (`FeatureUnavailableException`) en una función visible del rol = hallazgo (tipo bug; severidad alta si la pantalla lo expone al usuario).

## 5. Qué revisa cada líder (lista de verificación por HU)

Para cada HU de tu módulo (certificadas y no certificadas): camino feliz; validaciones (400); permisos (401 sin token, 403 con otro rol, acceso a datos de otro ámbito); 404; 409; estados vacíos, de carga y de error en pantalla; mensajes del backend; actualización en tiempo real por SSE donde aplique; notificaciones y alertas; comportamiento en móvil (375 px); consistencia de datos entre pantallas y entre roles (por ejemplo, el % de inasistencia debe ser igual para estudiante, docente y coordinador).

Además, UX/UI del rol: jerarquía visual, consistencia con `docs/sistema-diseno.md`, textos, accesibilidad básica (contraste, foco, etiquetas), estados vacíos/carga/error y fricciones del flujo. Cada propuesta UX/UI va como hallazgo de tipo UX/UI con **recomendación concreta**.

## 6. Organización del trabajo y recursos compartidos

- Hay **un solo navegador integrado**, una sola SQL Server y un solo Keycloak. **Los recorridos en pantalla NO los haces tú ni tus probadores en esta fase**: redactas el guion (`SCREEN-TESTS-<rol>.md`) y el orquestador lo ejecuta en serie, un rol a la vez. Lo que sí haces en paralelo: pruebas de API con token (probadores Haiku), consultas SQL de solo lectura y revisión estática de código (frontend y backend) para UX/UI, a11y, polling, 501, mensajes fijos y fugas de ámbito.
- Probadores Haiku (`subagent_type: general-purpose`, `model: haiku`, `effort: low`): dales un guion concreto y autocontenido (endpoints, token de qué usuario, payloads válidos e inválidos, qué esperar, cómo obtener el token y dónde leer la clave) y pídeles **solo** el resultado en el formato de la sección 7, sin volcados. Lanza varios en paralelo si no comparten datos de escritura.
- Las pruebas que **modifican datos** usan datos propios del rol (por ejemplo, los grupos del docente de prueba) y no deben chocar con otros roles; no ejecutes cierre masivo, no canceles ni desactives grupos, periodos, programas, facultades ni usuarios sembrados; si creas registros, nómbralos con el prefijo `CULM1-` para poder identificarlos.
- No leas archivos completos que puedas resumir con `grep`/`Grep`; cita rutas y líneas.
- No ejecutes `mvnw`, `npm run build/test`, `db-deploy` ni `db-seed`: el orquestador controla esos gates y los servicios ya están arriba. No reinicies backend ni frontend.

## 7. Formato de salida (obligatorio)

Escribe dos archivos en `AsistenciasUCO-Infra/docs/work-items/CULM-001-culminacion/`:

1. `FINDINGS-<rol>.md` (rol en minúsculas: `estudiante`, `docente`, `coordinador`, `decano`, `administrador`, `transversal`). Una tabla Markdown con **exactamente** estas columnas y una fila por hallazgo, IDs `F-<ROL3>-NNN` (`F-EST-001`, `F-DOC-001`, `F-COO-001`, `F-DEC-001`, `F-ADM-001`, `F-TRX-001`):

   `| ID | Rol | HU | Severidad | Tipo | Pasos | Esperado | Obtenido | Evidencia | Capa sospechosa | Estado |`

   Severidad: crítica/alta/media/baja. Tipo: bug/inconsistencia/seguridad/UX/UI/a11y/notificación/rendimiento. Capa sospechosa: DB/Backend/Frontend/Infra. Estado inicial siempre `abierto`. Evidencia = endpoint + código HTTP + `X-Correlation-Id` o `code`, o `archivo:línea` para hallazgos de código. Sin secretos. Sin filas "todo bien": si una HU pasa no genera fila; resúmelo al pie del archivo ("HUs verificadas sin hallazgos: ...").
2. `SCREEN-TESTS-<rol>.md`: guion de recorrido en pantalla para que un probador lo ejecute en serie, paso a paso (ruta de la app, acción, dato a usar, resultado esperado, qué mirar en consola y red), ordenado por HU, marcando qué pasos repetir en vista móvil (375×812) y cuáles necesitan datos previos de otro rol.

Tu respuesta final al orquestador: **solo** un resumen de 25 líneas o menos: número de hallazgos por severidad, los críticos y altos listados por ID y título, HUs verificadas, HUs que no pudiste probar y por qué, y las rutas de tus dos archivos. Nada más.
