# Paquete A · Parte 2: correcciones críticas y altas de la Fase 1 (triage del orquestador, 2026-11-07)

Se integran en el mismo paquete A (ramas `feature/CULM-001-A-retiro-solicitudes` por repo) después del retiro de solicitudes, con TDD por capa. Cada ítem cita el hallazgo de `FINDINGS.md`; la decisión del orquestador está en `DECISIONES.md` (DEC-022).

## A.2.1 Seguridad y ámbito (críticos primero)

| Hallazgo | Corrección exigida | Capa |
| :--- | :--- | :--- |
| F-COO-001, F-COO-002, F-DOC-013 (críticos) | `GET /api/v1/estudiantes` y `GET /api/v1/estudiantes/{id}` pasan por un SP de consulta con ámbito dentro del SP: ADMINISTRADOR → institución; COORDINADOR → estudiantes con `EstudiantePrograma` en su(s) programa(s); DOCENTE → solo estudiantes con matrícula en grupos donde es titular. Fuera de ámbito: 404 sin datos (listado: filtrado; detalle: 404). El filtro `programaId` solo restringe dentro del ámbito. Pruebas RED en BD (SP), backend (403/404, paridad) y matriz de ámbito repetida con el 2.º ámbito (A.2.6). | DB + Backend |
| F-COO-003 | `GET /grupos`, `GET /grupos/{id}/estudiantes`, `GET /grupos/{id}/asistencias`: ámbito de programa para el coordinador dentro del SP (`usp_consultar_*`), de titularidad para el docente; id inexistente o ajeno → 404 (no 200 vacío). | DB + Backend |
| F-COO-004 | Matrícula manual solo DOCENTE titular (ya en CONTRACT.md §backend); el coordinador recibe 403; se retiran los stubs 501 del coordinador. | DB + Backend + Frontend |
| F-TRX-018 | El administrador se retira de las rutas `coordinador/*` y `decano/*` en `SecurityConfig` y `access-catalog.json` (los SP ya lo rechazan; principio de mínimo privilegio). Se documenta en `rutas-por-rol.md` (fuera de Git: nota en CLOSURE). | Backend + Infra |
| F-TRX-003 | Rate limit del `MatriculaQrRateLimitFilter` generalizado a `POST /api/v1/archivos/subir` (por usuario e IP; parámetro `ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO`) y a `POST /api/v1/estudiante/asistencia-qr` (por IP y por estudiante; parámetros `ASISTENCIA_QR/LIMITE_IP_POR_MINUTO`, `ASISTENCIA_QR/LIMITE_ESTUDIANTE_POR_MINUTO`, sembrados en BD). El límite por token lo añade B. | DB (seed) + Backend |
| F-EST-019 | Rutas públicas `/api/v1/public/**` y `/api/v1/configuracion/registro-estudiante` fuera del PEP: `security.pep.enforcement.public-paths` (`SECURITY_PEP_PUBLIC_PATHS`) incluye `/api/v1/public/**` por defecto en `application.yml` y en el `.env` del worktree; prueba RED de que `POST /public/matricula-qr/validar` sin token responde 200/400 y nunca 401. Si el PEP sigue bloqueando por configuración del laboratorio, queda documentado como dependencia del equipo de seguridad. | Backend + entorno |

## A.2.2 Errores 500 y 501 expuestos

| Hallazgo | Corrección exigida | Capa |
| :--- | :--- | :--- |
| F-EST-018, F-DOC-015, F-DOC-016, F-TRX-017 | Ningún 500 funcional: PIN inexistente → 404/409 con mensaje del catálogo; `POST /grupos/{id}/matricula-qr` y `/rotacion` con titular → 201/200 (causa raíz a diagnosticar: probablemente parámetros `MATRICULA_QR/*` leídos de Azure inaccesible → aplicar DEC-018: proveedor `sqlserver` en local y valores por defecto en código); GUID inexistente → 404; `/configuracion/identidad` y `/configuracion/registro-estudiante` → 200 con valores de BD y 404 para grupo inexistente; notificaciones admin con id inexistente → 404; cuerpo `{}` → 400. Mapear en `DbExceptionTranslator`/`GlobalExceptionHandler` todo error de catálogo no clasificado a 404/409 según corresponda. | Backend (+ DB mensajes) |
| F-EST-003 | `DELETE /estudiante/reclamos/{id}`: implementar el retiro de un reclamo propio en estado pendiente (SP `usp_retirar_solicitud_revision_asistencia` nuevo o existente, auditado, notificación opcional) y conectar el botón "Retirar"; si no existe SP y no cabe en A, ocultar el botón y pasar a D (decisión del implementador, documentada). `POST /estudiante/reclamos` (501) se retira: el flujo real es `POST /asistencias/revisiones`. | DB + Backend + Frontend |
| F-ADM-002 | `PATCH /admin/decanos/{id}/toggle`: implementar con SP de cambio de estado del decano (RBAC ADMINISTRADOR, no desactivar al único decano activo de una facultad con programas activos → 409) y conectar el botón. | DB + Backend + Frontend |
| F-COO-005 | Ocultar en la malla "desvincular asignatura" hasta B2 (que implementa `usp_desvincular_asignatura_plan`); el 501 del backend se retira del catálogo de accesos. | Backend + Frontend |
| F-EST-004 | Retirar `PUT /usuarios/perfil` (501), `updateUserProfile` y los botones "Editar" del perfil (HU006 es solo consulta). | Backend + Frontend |
| F-TRX-004 (resto) | `GET /sesiones/{id}/qr-token`, `PATCH /docente/sesiones/{id}/cancelar`, `POST /asistencias` → los resuelve B (no tocar en A); `PUT /admin/parametros/{id}` → D (HU168); `DELETE /grupos/{id}/estudiantes/{id}` → retirar (el retiro usa `POST .../retiro`); `/coordinador/solicitudes-matricula` y `/coordinador/grupos/{id}/estudiantes` → retirar (ya en CONTRACT.md). | Backend |

## A.2.3 Reglas de negocio rotas

| Hallazgo | Corrección exigida | Capa |
| :--- | :--- | :--- |
| F-DOC-017 | HU034: `usp_crear_sesion(_v2)`/`usp_actualizar_sesion(_v2)` rechazan solapes dentro del mismo grupo y entre grupos del mismo docente (`SES_0xx` nuevo) — vía `usp_validar_solape_sesion_interno` llamado por los SP internos (no congelados); pruebas RED en BD y backend; mensaje del backend en pantalla. | DB + Backend |
| F-EST-S01, F-EST-020 | Solo la matrícula en estado `A` cuenta como inscrita en `GET /estudiante/materias`, dashboard y oferta (ámbito por estado dentro del SP/consulta); las matrículas `I`, `CI`, `CVP`, `F` no aparecen como materias activas. | DB + Backend |
| F-000 | `test_suite.sql` verde: diagnosticar `LB004D_R2_TEACHER_SCOPE_AND_SUPPORT` (ámbito docente y soporte de reclamo) y corregir el código de producción o el fixture de la prueba solo si está mal (justificación escrita). El gate `db-test` debe quedar verde antes de cerrar A. | DB |

## A.2.4 Datos de prueba del segundo ámbito (F-TRX-008, F-DEC-011)

Script idempotente `GestioAsistenciaDB/test/fixtures/culm1_segundo_ambito.sql` (no forma parte del despliegue): en `CULM1-Facultad B` (ya creada) un programa `CULM1-Programa B` con plan, semestre, asignatura `CULM1-ASG-B`, coordinador `CULM1` (solo BD), docente `CULM1` (solo BD), grupo `CULM1-Grupo B` y 3 estudiantes `CULM1` matriculados (solo BD; sin cuentas en Keycloak: no se necesitan para probar que los usuarios `uco-*` NO los ven). Se ejecuta antes de las pruebas de ámbito y lo usa la matriz del transversal en la Fase 3.

## A.2.5 Lo que NO entra en A (va a otro paquete, ya asignado en FINDINGS.md)

F-EST-002, F-EST-017, F-DOC-002, F-TRX-002 → B · F-EST-S05, F-TRX-005, F-TRX-006 → C · F-ADM-003, F-ADM-004, F-ADM-022 → D · F-EST-S03 y el resto de UX/UI/a11y → E.
