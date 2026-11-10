# CULM-001 — Guía de pruebas manuales (laboratorio local)

> Fuente de credenciales: `docs/CREDENCIALES_PRUEBAS_LOCAL.md` del workspace raíz (`C:\Proyectos\GestionAsistencia\docs\`).
> Nunca copiar claves a chats, commits ni reportes: citar ese archivo.

## 1. Levantar el laboratorio (tras un apagado)

1. Docker Desktop abierto. Arrancar solo lo propio del proyecto y la línea base de seguridad:
   ```powershell
   docker start sql_server_asistencias asistencias-security-lab-redis-1 asistencias-security-lab-surrealdb-1 asistencias-security-lab-opa-1
   docker start asistencias-security-lab-keycloak-1
   docker start asistencias-security-lab-pdp-1 asistencias-security-lab-pep-1
   ```
   MinIO (`asistencias-files-minio-1`) y ClamAV (`clamav_asistencias`) arrancan solos. No levantar `messageucolab-*`, `pulsar`, `loki`, `test_ci_clean`, `security-baseline-*` (0.1.7) ni observabilidad; detener `api-gateway-kong` y `keycloak_db_asistencias` si arrancan solos.
2. Backend (desde el checkout de `develop` del backend, jar construido con `.\mvnw.cmd clean package -DskipTests`):
   ```powershell
   $env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:\jtmp'
   .\infra\security-baseline\scripts\start-backend-baseline.ps1 -Provider baseline -LogDirectory C:\jtmp\backend-logs
   ```
   Salud: `http://127.0.0.1:8090/actuator/health` (la gestión vive en 8090 desde D.9; `http://localhost:8080/actuator/prometheus` responde 401, es correcto).
3. Frontend: `npm start` en el checkout de `develop` del frontend → `http://localhost:4200/` (modo seguridad baseline: `public/assets/env.js` con `SECURITY_PROVIDER='baseline'`).
4. Datos canónicos: si la BD quedó sucia, restaurar el respaldo base y aplicar migraciones 13–28 antes de `deploy_schema.ps1` (orden de DEC-060), o usar `.\AsistenciasUCO-Infra\infra.ps1 db-deploy` sobre una BD nueva.

## 2. Direcciones

| Componente | URL | Notas |
| :--- | :--- | :--- |
| Frontend (SPA) | `http://localhost:4200/` | El login redirige a Keycloak baseline |
| Backend API | `http://localhost:8080/api/v1` | OpenAPI: `http://localhost:8080/swagger-ui.html`, `http://localhost:8080/v3/api-docs` |
| Gestión backend | `http://127.0.0.1:8090/actuator/health` | Solo loopback |
| Keycloak (línea base) | `http://keycloak.localhost:19090`, realm `security-baseline`, cliente `asistencias-uco-spa` | Login de los usuarios `uco-*` |
| PDP / PEP | `http://localhost:18080` / `http://localhost:18081` | Políticas sincronizadas con `provision_asistencias.py pdp` |
| SQL Server | `localhost:1433`, BD `gestionasistenciadb` | Contenedor `sql_server_asistencias` |
| MinIO / ClamAV | solo vía backend | Sin consola web (`MINIO_BROWSER=off`) |

## 3. Usuarios de prueba

| Rol | Usuario | Clave |
| :--- | :--- | :--- |
| Estudiante | `uco-estudiante` | ver `docs/CREDENCIALES_PRUEBAS_LOCAL.md` (clave común) |
| Docente | `uco-docente` | ídem |
| Coordinador | `uco-coordinador` | ídem |
| Decano | `uco-decano` | ídem |
| Administrador | `uco-administrador` | ídem |

Para cambiar de rol: menú de la app → Cerrar sesión (o `http://keycloak.localhost:19090/realms/security-baseline/protocol/openid-connect/logout`). No recargar URLs completas con la sesión abierta: el token vive en memoria y una recarga vuelve al login.

## 4. Rutas de la SPA por rol (todas bajo `http://localhost:4200/app/...`)

| Rol | Rutas | Qué probar (paquete) |
| :--- | :--- | :--- |
| Todos | `dashboard`, `perfil`, `acceso-denegado` (403), cualquier ruta inexistente (404 propia) | Identidad visual E, menú por rol, mensajes del backend tal cual |
| Estudiante | `estudiante/materias` (créditos y carácter OBL/OPT), `estudiante/oferta`, `estudiante/horarios`, `estudiante/reclamos` (varios soportes, categoría, plazo), `estudiante/alertas`, `asistencia` (marcar por token/QR), `matricula/qr`, `matricula/pin` | B2, D.1, D.2, C.1, B.2 |
| Docente | `docente/grupos` (planilla con columna Seguimiento, tomas por horas, ventana QR/PIN rotativa, matrícula manual/QR con selección de programa en grupos mixtos), `docente/horarios`, `docente/reclamos` | B.2, B2, C.1, D.2 |
| Coordinador | `coordinador/planes-estudio` (asociar/desvincular asignaturas, carácter, selector de programa), `coordinador/planes-estudio/nuevo`, `coordinador/materias`, `coordinador/grupos`, `coordinador/estudiantes`, `coordinador/docentes` (carga masiva CSV), `coordinador/asistencias`, `coordinador/consolidado-asistencia` (Excusa y Sin registro), `coordinador/indicadores`, `coordinador/periodos`, `coordinador/revisiones-cancelacion` | B2, D.5, D.8, C.1 |
| Decano | `decano/facultad`, `decano/estructura`, `decano/programas`, `decano/asignaturas` (planes compartidos), `decano/coordinadores` (carga masiva), `decano/docentes`, `decano/estudiantes`, `decano/grupos` (detalle sin bucle), `decano/cronograma`, `decano/consolidado-asistencia`, `decano/indicadores` (comparativa por horas), `decano/periodos`, `decano/areas`, `decano/infraestructura`, `decano/revisiones-cancelacion` (escalamiento) | B2, D.8, D.9, C.1 |
| Administrador | `admin/estudiantes` (admisión), `admin/decanos` (carga masiva), `admin/docentes`, `admin/asignaturas`, `admin/facultades`, `admin/instituciones` (solo lectura), `admin/areas`, `admin/periodos` (201, esVigente), `admin/festivos`, `admin/catalogos`, `admin/estados`, `admin/sistema` (cierre masivo con periodo obligatorio y bloqueo RCN_012; parámetros editables; auditoría por correlación), `admin/correos` (estado del canal sin host/puerto), `admin/mensajes`, `admin/indicadores` (comparativa de facultades y tendencia por horas), `admin/seguridad` | D.3, D.4, D.5, D.6, D.8, D.9 |

## 5. Pruebas por API (sin pantalla)

- Suite E2E de HUs: `.\scripts\tests\test_all_hus.ps1` (Infra) con `$env:E2E_PASSWORD` tomado de `docs/CREDENCIALES_PRUEBAS_LOCAL.md`; 82 casos, 1 omitido salvo `E2E_PERMITIR_CIERRE_MASIVO=1`.
- Token PKCE para llamadas manuales: `.\scripts\tests\Get-SpaToken.ps1` (Infra). Enviar `Authorization: Bearer <token>` a `http://localhost:8080/api/v1/...`.
- Tiempo real: `GET /api/v1/realtime/stream?grupoId=<uuid>` (SSE, 5 roles con ámbito; `Accept` incompatible → 406); `POST /api/v1/realtime/emit` solo ADMINISTRADOR.

## 6. Datos útiles del laboratorio

- Grupo canónico del docente: "Grupo 001 - Arq Software" (asignatura ARQ-402, programa Ingeniería de Sistemas); la suite E2E crea datos `CULM1-E2E-*`.
- Alertas y revisiones de cancelación (C.1) solo aparecen cuando un estudiante cruza el 15 % / 20 % de inasistencia por horas: registrar faltas en varias tomas de sesiones ejecutadas para provocarlas.
- Un recurso nuevo del backend que responda 403 `NO_APPLICABLE_POLICY` indica PDP sin sincronizar: `python -X utf8 -I infra\security-baseline\scripts\provision_asistencias.py pdp` (backend) con el Python de Windows.
