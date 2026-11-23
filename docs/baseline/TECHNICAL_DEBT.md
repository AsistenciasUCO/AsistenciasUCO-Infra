---
status: active
type: ledger
scope: backend
owner: backend-team
last-reviewed: 2026-11-17
---

# Ledger único de deuda técnica

TD-001..TD-005 conservan los IDs del paquete; los demás consolidan la documentación previa. Una brecha TARGET no significa un defecto AS-IS. No reciclar IDs. Fecha de incorporación: 2026-09-20; responsable de seguimiento: backend-team, con los equipos DB/identidad/frontend/operaciones donde se indica. Evidencia externa no aportada se declara pendiente; no se inventan aprobaciones ni corridas.

Las propuestas Redis, RabbitMQ, CQRS, MinIO, SBOM y técnicas avanzadas se mantienen en [LINEA_BASE](LINEA_BASE.md) como evoluciones, no como deuda que obligue a introducirlas.

## Estado para el cierre (2026-11-17)

Clasificación de lo que sigue abierto según su efecto en la entrega. La entrega es una demostración con imágenes Docker; el despliegue real en servidores de la universidad es futuro y sus requisitos se documentan en [REQUISITOS_PRODUCCION](../runbooks/REQUISITOS_PRODUCCION.md), no se implementan ahora.

- **Bloquea la demostración:** ninguna. Las cuatro que la bloqueaban el 2026-11-16 (TD-097, TD-098, TD-102 y TD-107) quedaron cerradas con el cierre del 2026-11-16/17 (ver "Cerradas" más abajo y el work item [CIERRE-001](../work-items/CIERRE-001-cierre-proyecto/README.md)).
- **Pendiente de decisión del responsable (no bloquea):** TD-116 (cifras de pérdida: matrículas frente a personas), TD-117 (enlace directo a las decisiones de cancelación pendientes del docente) y TD-118 (semántica de `esResolutorActual` del docente).
- **Requisito para producción (no bloquea la demo):** TD-003, TD-011, TD-014, TD-018, TD-020, TD-023, TD-027, TD-063, TD-072, TD-073, TD-093, TD-099, TD-100, TD-101, TD-103, TD-104, TD-108, TD-110, TD-124.
- **Aplazable:** TD-004, TD-006, TD-007, TD-012, TD-013, TD-015, TD-016, TD-019, TD-024 a TD-026, TD-034, TD-044, TD-045, TD-046, TD-050, TD-054, TD-056, TD-062, TD-064 a TD-071, TD-074 a TD-083, TD-085 a TD-092, TD-105, TD-106, TD-111 a TD-115, TD-119 a TD-123, TD-CULM001-A-01 a A-03 y TD-CULM001-D-01 a D-05.
- **Cerradas en esta revisión (2026-11-16), con evidencia en su entrada:** TD-010, TD-022, TD-039, TD-041, TD-043, TD-047, TD-049, TD-055 y TD-084. TD-094 a TD-096 llegan cerradas desde el registro del backend.
- **Cerradas en la revisión del 2026-11-17 (cierre en `develop`), con evidencia en su entrada:** TD-097 (BD PR 140), TD-098 (W1B), TD-102 en cuanto al arranque (Frontend PR 140; el simulador sigue en el bundle, ver TD-106), TD-107 (los seis paquetes W1A a W3I; lo que quedó expresamente sin mover en el cliente está en TD-119; relacionadas: TD-113, TD-114 y TD-117) y TD-109 (Frontend PR 140).
- **Datos medidos el 2026-11-17:** TD-072 y TD-073 con cifras nuevas; TD-075 (aviso del presupuesto); TD-105 (17 pruebas omitidas en la última corrida de integración).

Equivalencias con el registro histórico del backend (congelado al 2026-11-12): TD-055 del backend = TD-094, TD-056 del backend = TD-095, TD-057 del backend = TD-096, TD-058 del backend = TD-097. Los TD-055 y TD-056 de este registro son los de MessageUcoLab.

**Pendiente de decisión (hallazgo de esta revisión):** el registro histórico del backend contiene TD-062 a TD-082 (notificaciones NOTIF-001/002A e IDENT-001: SMTP, plantillas, verificación de correo, matrícula manual) con un significado distinto al de los mismos IDs de este registro, y sin equivalente aquí. No se trasladaron en esta revisión; hasta decidirlo, ese histórico es la única fuente de esas deudas y debe leerse con sus IDs de origen. TD-059 a TD-061 sí coinciden en significado (aquí figuran cerradas).

| ID | Descripción | Estado | Bloquea línea base |
|---|---|---|---|
| [TD-001](#td-001) | Piloto JDBC → JPA pendiente | CLOSED (LB-002.2) | no |
| [TD-002](#td-002) | Contrato OpenAPI no consolidado | CLOSED (LB-001C.1) | no |
| [TD-003](#td-003) | Realtime local efímero y por JVM | ABIERTA | no para la demostración (una instancia); sí al escalar a varias réplicas (producción); bloqueo LB-005 obsoleto |
| [TD-004](#td-004) | Storage local y ownership | ABIERTA | sí, LB-004 |
| [TD-005](#td-005) | Política temporal DB/API | CLOSED_FOR_GOLDEN_PATH (wire HTTP congelado en LB-001C.1; política global no cerrada) | no para Golden Path |
| [TD-006](#td-006) | Identificación numérica | ABIERTA | no, salvo alcance de identificación |
| [TD-007](#td-007) | Códigos DB machine-readable | ABIERTA | sí, si bloquea contrato de errores LB-001/002 |
| [TD-008](#td-008) | Validación runtime de sesión/asistencia | CLOSED — LB-003 | no |
| [TD-009](#td-009) | Estados de asistencia y registro individual | CLOSED (2026-11-07, CULM-001 D.7) | no |
| [TD-010](#td-010) | Auditoría SQL con DML directo | CERRADA — RESUELTA POR DECISIÓN (2026-11-16; Opción A, JPA directo) | no |
| [TD-011](#td-011) | Outbox y consistencia durable | ABIERTA | no; bloqueo LB-005 obsoleto; solo condiciona si producción exige entrega durable de eventos |
| [TD-012](#td-012) | DataSource específico por provider | ABIERTA | no, salvo incorporar otro provider |
| [TD-013](#td-013) | Provisioning institucional incompleto | ABIERTA | no para Golden Path; sí antes de liberar provisioning afectado |
| [TD-014](#td-014) | Confianza del correo en IdP | ABIERTA | no para LB-000; sí release de identidad |
| [TD-015](#td-015) | Consistencia DB/IdP y commands multi-adapter | ABIERTA | no para Golden Path; sí alcance de reconciliación |
| [TD-016](#td-016) | Autorización contextual por completar | ABIERTA | sí cuando la vertical afectada lo requiera |
| [TD-017](#td-017) | Consumo frontend/SSE | CLOSED_FOR_GOLDEN_PATH (MV-001 PASS reportado externamente) | no para Golden Path |
| [TD-018](#td-018) | Diagnóstico realtime en producción | ABIERTA | no para LB-000; sí release realtime |
| [TD-019](#td-019) | Contratos DB ausentes o limitados | PENDIENTE DE EVIDENCIA DB | no para LB-000; sí cada vertical dependiente |
| [TD-020](#td-020) | Hashing DB y autenticación histórica | PENDIENTE DE VALIDACIÓN | no para LB-000; sí release de credenciales |
| [TD-021](#td-021) | Serialización común de errores de seguridad | CLOSED (LB-001C.1) | no |
| [TD-022](#td-022) | Exposición Actuator y Prometheus | CERRADA (2026-11-16) | no |
| [TD-023](#td-023) | CI DB reproducible y gates remotos | OPEN / PARTIAL | no (LB-003 y LB-006 obsoletas); evidencia de gates remotos como requisito de producción |
| [TD-024](#td-024) | Verificación histórica de uploads | CERRADA EN ÍNDICE LOCAL; HISTORIAL NO EVALUADO | no |
| [TD-025](#td-025) | Limpieza oportunista de helpers | ABIERTA | no |
| [TD-026](#td-026) | Nombre FeaturesBeansConfigTest | ABIERTA | no |
| [TD-027](#td-027) | Evidencia operacional Azure/telemetría | ABIERTA | no; requisito de producción (certificar el ambiente real Azure/telemetría); bloqueo LB-006 obsoleto |
| [TD-028](#td-028) | Conflicto guía de métodos HTTP | CLOSED (LB-001C.1, API_DESIGN_RULES) | no |
| [TD-029](#td-029) | Gate ArchUnit preexistente fallido | CERRADA (TECH-001) | no |
| [TD-030](#td-030) | VAL_003 usado para fallos de autorización/titularidad en SPs internos | RESOLVED BY FROZEN DB BASELINE (LB-001B.4) | no |
| [TD-031](#td-031) | Frontend: orden de interceptores puede anular el refresco silencioso tras un 401 HTTP | CERRADA (frontend LB-001B.1C) | no |
| [TD-032](#td-032) | Frontend: credencial por defecto embebida en el flujo de matrícula (SECURITY_FINDING) | CERRADA (frontend LB-001B.1C) | no |
| [TD-033](#td-033) | Frontend: fallos de carga de sesiones y del canal realtime no se muestran al usuario | CERRADA (frontend LB-001B.1C) | no |
| [TD-034](#td-034) | Código muerto: `SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` sin lanzador tras LB-001B.1 | ABIERTA | no |
| [TD-035](#td-035) | Frontend: `attendance.mapper.ts` mantiene un contrato paralelo (`studentFromDTO()`/`ClassSessionDTO`) con residuo `estado_asistencia \|\| 'AN'` | CERRADA (frontend LB-001B.1C) | no |
| [TD-036](#td-036) | Mapeo determinista de errores DB (`SEC_001/SEC_002/ATT_001-3/SES_003/SES_004/GEN_002`) sin señal de clasificación formal | CLOSED (LB-001B.4) | no |
| [TD-037](#td-037) | `SesionMateriaEstudianteSqlServerAdapter` lee `Sesion.fechaHoraInicio/fechaHoraFin` con `toLocalDateTime` dependiente de `TimeZone.getDefault()`, no UTC fijo | CLOSED (LB-001B.4) | no |
| [TD-038](#td-038) | `ReporteAsistenciaSqlServerAdapterTest` no asevera `fechaHoraInicio`/`fechaHoraFin`; no detectaría una regresión de `toLocalDateTimeUtc` a `toLocalDateTime` | CLOSED (LB-001B.4) | no |
| [TD-039](#td-039) | Firma exacta de parámetros de `usp_cerrar_sesion` no documentada en `DB_BASELINE_CONTRACT.md` | CERRADA — RESUELTA POR EVIDENCIA (2026-11-16) | no |
| [TD-040](#td-040) | `uv_estudiante_identidad`/`uv_usuario` no documentadas en el contrato DB, usadas por `GET /api/v1/grupos/{grupoId}/estudiantes` | CLOSED — EVIDENCE_RESOLVED (LB-001B.4; salvedad: TD-046) | no |
| [TD-041](#td-041) | Rama DB origen `feat/db-golden-path-baseline-freeze` no fusionada a `main`/`develop` del repo DB | CERRADA (2026-11-16) | no |
| [TD-042](#td-042) | Test de serialización ISO-8601 UTC de `RealtimeEvent.occurredAt` sin contexto Spring real | CLOSED (LB-001B.4A, `RealtimeEventResponseSpringJsonTest` con `@SpringBootTest`) | no |
| [TD-043](#td-043) | NON_GOLDEN_DB_CONTRACT_DRIFT: 3 SP consumidos por el backend no existen en la DB oficial (`usp_sincronizar_usuario`, `usp_registrar_o_actualizar_plan_estudio`, `usp_registrar_estudiante_en_grupo_usuario_no_existente`) | CERRADA (2026-11-16) | no |
| [TD-044](#td-044) | 2 skips de `DocenteRepositorySqlServerIT` (`assumeTrue` por datos, sin fixture propio) | ABIERTA | no (fuera del Golden Path) |
| [TD-045](#td-045) | Riesgo de `CPI`/`CPVP` históricos en `RazonCausa` frente a la lectura fail-closed de estado | ABIERTA | no |
| [TD-046](#td-046) | Vistas `uv_estudiante_grupo`, `uv_estudiante_identidad`, `uv_usuario` sin documentar en `DB_BASELINE_CONTRACT.md` | ABIERTA (acción equipo DB) | no |
| [TD-047](#td-047) | `USU_001` sin mapeo formal DBCODE (cae en `ERR_DB_UNCLASSIFIED`) | CERRADA (2026-11-16) | no |
| [TD-048](#td-048) | `Sesion.nombre` es `nvarchar(50)` en DB pero el backend valida 1..150 (nombres de 51..150 fallarían en persistencia como error técnico) | CLOSED (LB-001B.4B) | no |
| [TD-049](#td-049) | `/usuarios/perfil` responde 501 | CERRADA (2026-11-16) | no |
| [TD-050](#td-050) | Latencia de reconciliación realtime observada en MV-001 | ABIERTA / NON_BLOCKING | no |
| [TD-051](#td-051) | Webhook Azure con credencial default funcional insegura | RESUELTA (LB-001D.2) | no |
| [TD-052](#td-052) | Webhook Azure acepta credencial por URL/query | RESUELTA (LB-001D.2) | no |
| [TD-053](#td-053) | Cloud Integration Azure corre como test normal | RESUELTA (LB-001D.2) | no |
| [TD-054](#td-054) | Semántica Azure→realtime sin decisión explícita | DECISION_REQUIRED | no para documentación; sí para cambio realtime futuro |
| [TD-CULM001-A-01](#td-culm001-a-01) | Dos fuentes del código `I` de matrícula retirada | ABIERTA / NON_BLOCKING | no |
| [TD-CULM001-A-02](#td-culm001-a-02) | Texto local del 409 de matrícula duplicada en el frontend | ABIERTA / NON_BLOCKING | no |
| [TD-CULM001-A-03](#td-culm001-a-03) | `SES_017` ausente de la tabla §G del Golden Path | ABIERTA / NON_BLOCKING | no |
| [TD-055](#td-055) | MessageUcoLab: validación operacional extremo a extremo pendiente | CERRADA (2026-11-16) | no |
| [TD-056](#td-056) | MessageUcoLab: límites de código (10) y contenido (100) incompatibles con el catálogo canónico | DECISION_REQUIRED | no mientras `azure` sea el provider por defecto |
| [TD-059](#td-059) | `DELETE` sobre `SolicitudRevisionAsistencia` falla con Msg 8624 (FK + índice filtrado LB-004D) | CLOSED (2026-11-08, CULM-001 D.2) | no |
| [TD-060](#td-060) | Categoría de radicación no se persistía en `SolicitudRevisionAsistencia` | CLOSED (2026-11-07, CULM-001 D.2) | no |
| [TD-061](#td-061) | Literales `'ATTACHED'`/`'DRAFT'` quemados en SP de LB-004D | CLOSED (2026-11-07, CULM-001 D.2) | no |
| [TD-CULM001-D-01](#td-culm001-d-01) | Propagación BD → Azure App Configuration de parámetros editados (`PUT /admin/parametros/{id}`) | ABIERTA / NON_BLOCKING | no |
| [TD-CULM001-D-02](#td-culm001-d-02) | Invalidación distribuida de caché de parámetros en entornos multi-instancia | ABIERTA / NON_BLOCKING | no |
| [TD-CULM001-D-03](#td-culm001-d-03) | Parámetros y auditoría particionados por institución [SUPUESTO-D-16] | DECISION_REQUIRED | no para monoinstitucional; sí multi-institución |
| [TD-CULM001-D-04](#td-culm001-d-04) | Depuración y limpieza periódica de archivos soporte huérfanos (`DRAFT` / `ORPHAN`) | ABIERTA / NON_BLOCKING | no |
| [TD-CULM001-D-05](#td-culm001-d-05) | Manejo paginado en sesiones de estudiante si total supera `PAGINACION/TAMANO_MAXIMO` | ABIERTA / NON_BLOCKING | no |
| TD-062 | Avisos de alertas sin reintento previo al outbox (detalle en la sección TD-062 a TD-065) | ABIERTA / NON_BLOCKING | no |
| TD-063 | SSE `local-sse` de una JVM con audiencias por instantánea | ABIERTA / NON_BLOCKING | no |
| TD-064 | Vista de revisiones del administrador diferida | ABIERTA / NON_BLOCKING | no |
| TD-065 | Revisión sin resolutor posible y marca de agua con solape | ABIERTA / NON_BLOCKING | no |
| [TD-066](#td-066) | Prueba de la migración 19 sin comparación byte a byte del SP restaurado | ABIERTA / NON_BLOCKING | no |
| [TD-067](#td-067) | Pruebas C-DB-50 y C-DB-46 sin ejecución en paralelo real | ABIERTA / NON_BLOCKING | no |
| [TD-068](#td-068) | C-DB-62 (despliegue limpio) cubierta solo por el gate del lote | ABIERTA / NON_BLOCKING | no |
| [TD-069](#td-069) | `CierreMasivoRcn012IT` pendiente de ejecución o ajuste | ABIERTA / NON_BLOCKING (revisada 2026-11-16) | no |
| [TD-070](#td-070) | E2E PKCE de C (`test_culm001_c.ps1`) sin ejecutar | ABIERTA / NON_BLOCKING (revisada 2026-11-16) | no |
| [TD-071](#td-071) | Manifiesto post-freeze de C sin modo en `freeze-manifest.ps1` (`DB_UTC_D06`) | ABIERTA / NON_BLOCKING | no |
| [TD-072](#td-072) | `--prune` del PDP pendiente (128 concesiones sobrantes medidas el 2026-11-17) | ABIERTA / NON_BLOCKING | no |
| [TD-073](#td-073) | 48 recursos huérfanos en el PDP (medidos el 2026-11-17) | ABIERTA / NON_BLOCKING | no |
| [TD-074](#td-074) | Drift de dos SP congelados (`usp_generar_sesiones_grupo`, `usp_registrar_asistencias_sesion`) | ABIERTA / NON_BLOCKING | no |
| [TD-075](#td-075) | Presupuesto del bundle frontend excedido (aviso de ~3,2 kB sobre 500 kB en los builds del 2026-11-16; antes +7,6 kB) | ABIERTA / NON_BLOCKING (revisada 2026-11-17) | no |
| [TD-076](#td-076) | `horasDictadas` del consolidado sin multiplicar por activos | ABIERTA / NON_BLOCKING | no |
| [TD-077](#td-077) | `codigo_programa` y `codigo_facultad` del CSV resueltos por nombre | ABIERTA / NON_BLOCKING | no |
| [TD-078](#td-078) | `details[]` en inglés `{field, code, message}` | ABIERTA / NON_BLOCKING | no |
| [TD-079](#td-079) | Bloque '2 tomas = 1 toma' de `test_culm001_b2_horas` diferido | ABIERTA / NON_BLOCKING | no |
| [TD-080](#td-080) | Resultsets de tres SP excluidos del cierre canónico | ABIERTA / NON_BLOCKING | no |
| [TD-081](#td-081) | Orden de despliegue de BD: migraciones antes de `deploy_schema` | ABIERTA / NON_BLOCKING | no |
| [TD-082](#td-082) | Detalle `esParcial` por toma sin endpoint | ABIERTA / NON_BLOCKING | no |
| [TD-083](#td-083) | HU042 por SSE y campana de notificaciones diferidas (C.2) | ABIERTA / NON_BLOCKING | no |
| [TD-084](#td-084) | Regla escrita de seguridad web (cookies HttpOnly y CSRF) contradice la implementación Bearer | CERRADA — RESUELTA POR DECISIÓN (2026-11-16) | no |
| [TD-085](#td-085) | Código aleatorio de sesión en `usp_generar_sesiones_grupo` colisiona con `UX_Sesion_Grupo_Codigo` (CI de BD intermitente) | ABIERTA / NON_BLOCKING | no |
| [TD-086](#td-086) | Security Baseline 0.1.13: el entrypoint de Keycloak fija el Admin API en 8080 (relevo `keycloak-relay` en el compose endurecido) | ABIERTA / NON_BLOCKING | no |
| [TD-087](#td-087) | `provision_asistencias.py verify` falla en `develop`: `extract_endpoints.py` no admite rutas constantes (`RecuperacionClaveController`, HU177) | CERRADA (backend PR #153) | no |
| [TD-088](#td-088) | Catálogo de Parámetros 0.1.7: plantilla de recursos vacía, `tipos-parametro` sin semilla y sin validación de referencia en `POST /parametros` | ABIERTA / NON_BLOCKING | no |
| [TD-089](#td-089) | Gateway Kong de MessageUcoLab degradado tras ~4 h: deja de aceptar conexiones nuevas desde contenedores | ABIERTA / NON_BLOCKING | no |
| [TD-090](#td-090) | `/api/v1/admin/parametros` y sus SP sin uso desde la UI: la administración de parámetros es el micro frontend del Catálogo | ABIERTA / NON_BLOCKING | no |
| [TD-091](#td-091) | `parametros-administration.js` 1.0.0: sondeo por defecto cada 60 s, CORS de un solo origen; nginx propio sin rutas a los micro frontends | ABIERTA / NON_BLOCKING | no |
| [TD-092](#td-092) | MessageUcoLab: el micro frontend elige la aplicación por nombre y el backend por id (dos "Asistencias UCO" en el laboratorio); contingencia `azure` por defecto sin Azure en local | ABIERTA / NON_BLOCKING | no |
| [TD-093](#td-093) | Unicidad de personas y roles: altas de decano y coordinador reutilizan a otra persona por número sin tipo; sin índices únicos ni bloqueos; segundo rol sin acceso en el PDP | ABIERTA | no; sí antes de abrir altas masivas o producción |
| [TD-094](#td-094) | (antes TD-055 del backend) JDBC directo residual en `src/main` durante la migración JPA-only | CERRADA (LB-008 JPA-07, 2026-10-06) | no |
| [TD-095](#td-095) | (antes TD-056 del backend) `usp_registrar_asistencia_estudiante_autonomo` sin frontera transaccional | CERRADA (2026-10-07) | no |
| [TD-096](#td-096) | (antes TD-057 del backend) Catálogo `dbo.Estado` sin códigos de revisión: toda solicitud nacía aceptada | CERRADA (2026-10-07) | no |
| [TD-097](#td-097) | (antes TD-058 del backend) `usp_ejecutar_cierre_masivo_periodo` resuelve el período con fallback al más reciente | CERRADA (BD PR 140, 2026-11-17) | no |
| [TD-098](#td-098) | `GET /api/v1/docentes` y variantes sin ámbito por coordinador ni paginación | CERRADA (CIERRE-W1B, 2026-11-17) | no |
| [TD-099](#td-099) | El generador de entorno conecta el backend como `sa`; existen dos roles de mínimo privilegio distintos | ABIERTA | no; requisito de producción |
| [TD-100](#td-100) | Vistas `uv_usuario_autenticacion` y `uv_administrador` exponen la columna `password`; el rol de aplicación lee toda vista `uv_%` | ABIERTA | no; requisito de producción |
| [TD-101](#td-101) | `deploy_schema.ps1` siembra siempre cuentas con credenciales fijas | ABIERTA | no; requisito de producción |
| [TD-102](#td-102) | El simulador del frontend viaja en el bundle de producción y se activa con `USE_MOCKS` sin fallo cerrado | CERRADA en cuanto al arranque (Frontend PR 140, 2026-11-17); el simulador sigue en el bundle (TD-106) | no |
| [TD-103](#td-103) | `environment.production` queda en `false` en el build de producción | ABIERTA | no; requisito de producción |
| [TD-104](#td-104) | SSE sin límite de conexiones por usuario ni revalidación de ámbito tras suscribir | ABIERTA | no; requisito de producción |
| [TD-105](#td-105) | 59 llamadas `assume*` en 18 pruebas de integración del backend pueden omitirse en silencio (17 omitidas en la última corrida) | ABIERTA / NON_BLOCKING | no (relacionada con TD-044) |
| [TD-106](#td-106) | Los E2E del frontend corren solo contra el simulador y en modo `legacy` | ABIERTA / NON_BLOCKING | no |
| [TD-107](#td-107) | Frontend con filtrado, paginación y cálculos de negocio en el cliente | CERRADA (seis paquetes W1A a W3I, 2026-11-17); remanentes en TD-119 | no |
| [TD-108](#td-108) | Sin configuración ni runbook de producción (Keycloak en `start-dev`, HTTP, sin TLS, sin rollback) | ABIERTA | no; requisito de producción |
| [TD-109](#td-109) | Sin política de caché en nginx para `index.html` y los assets con hash | CERRADA (Frontend PR 140, 2026-11-17) | no |
| [TD-110](#td-110) | Migración futura a sesión por cookie HttpOnly / BFF para producción (diferida) | DIFERIDA A PRODUCCIÓN | no |
| [TD-111](#td-111) | Dos pruebas de BD inestables ajenas a los cambios (`CULM001_D3_13`, `LB004D_W2_ATTACH_STATE_UTC`) | ABIERTA / NON_BLOCKING | no |
| [TD-112](#td-112) | Simulador del frontend incompleto o divergente del backend real | ABIERTA / NON_BLOCKING | no |
| [TD-113](#td-113) | Textos de interfaz literales fuera del catálogo y rótulos de período escritos a mano | ABIERTA / NON_BLOCKING | no |
| [TD-114](#td-114) | Código del frontend sin uso tras el cierre y servicio duplicado | ABIERTA / NON_BLOCKING | no |
| [TD-115](#td-115) | RBAC por perfil acepta código o nombre; ~120 llamadores pasan el nombre; perfiles y estados literales en SP y vistas | ABIERTA / NON_BLOCKING | no |
| [TD-116](#td-116) | Cifras de pérdida: el consolidado cuenta matrículas y el indicador del decano cuenta personas (958 frente a 675) | ABIERTA — DECISION_REQUIRED | no |
| [TD-117](#td-117) | F-DOC-03: el tablero del docente no enlaza directo a las decisiones de cancelación pendientes | ABIERTA — DECISION_REQUIRED | no |
| [TD-118](#td-118) | `esResolutorActual` del docente queda siempre en 0 | ABIERTA — DECISION_REQUIRED | no |
| [TD-119](#td-119) | Restos de filtrado, conteo y valores por defecto en el cliente declarados por los paquetes del cierre | ABIERTA / NON_BLOCKING | no |
| [TD-120](#td-120) | El interceptor global de errores solo avisa 403 y 5xx; 400/409/422 dependen de cada pantalla | ABIERTA / NON_BLOCKING | no |
| [TD-121](#td-121) | `/admin/docentes` muestra solo docentes con vínculo activo (HU136): un docente sin vínculo no aparece en el selector del administrador | ABIERTA / NON_BLOCKING | no |
| [TD-122](#td-122) | 14 cuentas de prueba posteriores al conjunto de datos alteran los conteos de `verificar_datos_prueba.py` (26 de 28) | ABIERTA / NON_BLOCKING | no |
| [TD-123](#td-123) | Incidente operativo del 2026-11-16: contenedor desechable montó el volumen de MinIO del laboratorio; verificación de objetos pendiente | ABIERTA / NON_BLOCKING (verificación) | no |
| [TD-124](#td-124) | Notificaciones: autenticación entre servicios con `X-Api-Key` (secreto compartido); falta OAuth2 client-credentials | ABIERTA | no; requisito de producción |
| [TD-125](#td-125) | Prueba inestable del Backend `CatalogoParametrosHttpParameterCatalogAdapterTest.fallo_sincrono_al_lanzar_el_refresco` (TooManyActualInvocations por tiempos) | ABIERTA | no |
| [TD-126](#td-126) | Notificaciones: el token de verificación de correo vive en memoria (`VerificacionCorreoMarcadorProvider`); un reinicio entre intentos reemite y revoca el enlace previo | ABIERTA | no |
| [TD-127](#td-127) | Catálogo de Parámetros 0.1.17: los ambientes y estados de metadato-ambiente pasaron a ids fijos sin migrar los datos de 0.1.7 (metadatos huérfanos; `GET /ambientes/<id viejo>` 404) | ABIERTA | no |
| [TD-128](#td-128) | Catálogo de Parámetros 0.1.17: el compose obliga a `app` a depender de `otel-collector` y este de `jaeger`; sin observabilidad no se puede levantar solo el núcleo | ABIERTA | no |
| [TD-129](#td-129) | Seguridad 0.1.13/0.1.14: crear una identidad de servicio puede responder 500 por timeout de 3 s y dejar el cliente en Keycloak sin fila en el PDP | ABIERTA | no |

## TD-001

- **Descripción:** Piloto JDBC → JPA pendiente. La persistencia vigente era JDBC; brecha respecto al objetivo, no un defecto funcional.
- **Impacto:** Medio.
- **Evidencia:** pom.xml; adapters persistence/sqlserver; work item [LB-002-jpa-incremental](../work-items/LB-002-jpa-incremental/).
- **Motivo:** LB-002 requería contrato y paridad antes de activar JPA junto al fallback JDBC.
- **Resolución esperada:** Golden Path con JPA/paridad y rollback certificados.
- **Bloquea línea base:** no (cerrada).
- **Estado:** **CLOSED (2026-09-29, LB-002.2).** Condición de cierre cumplida: JPA query pilot PASS
  (LB-002.0/LB-002.1); JPA query activation PASS en `local`/`dev` (LB-002.1B); JPA command pilot PASS
  para `registrarAsistenciasSesion` (LB-002.2A-C); paridad JDBC↔JPA en SQL Server real
  `PARITY_MISMATCHES = 0` (LB-002.2D); fallback JDBC preservado en Composition Root (selectores
  independientes, default `jdbc`, fail-closed); runtime local JPA (`query=jpa`, `command=jpa`) PASS;
  Golden Path manual PASS, incluyendo realtime (dos clientes SSE y reconexión, reconvergencia ~25 s)
  (LB-002.2E). No se afirma retiro de JDBC: los demás commands de `Asistencia` permanecen en JDBC,
  sin cambio. Ver [LB-002.2-FINAL-CLOSURE](../work-items/LB-002-jpa-incremental/LB-002.2-jpa-command-pilot/LB-002.2-FINAL-CLOSURE.md).

## TD-002

- **Descripción:** Contrato OpenAPI no consolidado. Históricamente no existía spec aprobada ni gate.
- **Impacto:** Alto.
- **Evidencia:** contracts/openapi/README.md; .github/workflows/backend-ci.yml.
- **Motivo:** LB-001 debe reunir contrato/consumidores.
- **Resolución esperada:** Spec aprobada, compatibilidad y validación automatizada.
- **Bloquea línea base:** no; cerrada en LB-001C.1 para las 8 operaciones cubiertas.
- **Estado:** **CLOSED (2026-09-24, LB-001C.1).** OpenAPI 3.1.2 canónico en
  `docs/contracts/openapi/openapi-golden-path.yaml`, SHA-256 adyacente y gate en `mvn verify`
  mediante Swagger Parser + conformance controller/DTO. Alcance: 8 operaciones Golden Path; las
  operaciones fuera de alcance siguen gobernadas por AS-IS hasta contrato propio.

## TD-003

> **Reclasificada (2026-11-16).** El bloqueo "LB-005" es de una línea base ya cerrada. Hoy no bloquea la demostración (una instancia); bloquea escalar a varias réplicas, porque el canal sigue siendo SSE en memoria de una JVM (`ReactorRealtimeAdapter` sigue en `infrastructure/adapter/secondary/realtime/localsse/`). Véanse también TD-063 y TD-104.

- **Descripción:** Realtime local efímero y por JVM. No distribuye entre réplicas, no replay/durabilidad; consumidor lento puede perder eventos y dropped mide rechazos globales.
- **Impacto:** Alto al escalar.
- **Evidencia:** [ReactorRealtimeAdapter](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/realtime/localsse/ReactorRealtimeAdapter.java); reactive-realtime.md.
- **Motivo:** Diseñar distribución solo tras ADR y necesidad operacional.
- **Resolución esperada:** Pruebas multi-instancia y recuperación según contrato aprobado.
- **Bloquea línea base:** sí, LB-005.
- **Estado:** ABIERTA.
- **Actualización LB-001B.3 (2026-09-23):** hallazgo re-confirmado formalmente por auditoría de LB-001B.3 (`CONTRACT_MATRIX.md#m-24`, `TASK_AUTORIZADA.md` §26 de ese work item — auditoría de "serverless readiness" del Golden Path). Mismo componente, mismo diagnóstico (`Sinks.many().multicast().directBestEffort()`, Javadoc propio ya lo declara "best-effort... efímero"); no se abre un ID nuevo para evitar duplicar deuda. Sin refactor en esa fase, conforme a `TASK_AUTORIZADA.md` §26 ("No implementar infraestructura serverless ahora... registrar hallazgos en deuda técnica").

## TD-004

- **Descripción:** Storage local y ownership. ArchivoController usa filesystem; FileStoragePort/caso de uso de storage faltan; /archivos/** solo exige autenticación.
- **Impacto:** Alto en serverless/seguridad.
- **Evidencia:** ArchivoController; [runtime-security-provider-architecture.md](../security/runtime-security-provider-architecture.md).
- **Motivo:** Necesita contrato funcional de propietario/recurso/grupo antes de puerto y adapter.
- **Resolución esperada:** InputPort/UseCase/Port con consumidor real, autorización contextual y almacenamiento adecuado.
- **Bloquea línea base:** sí, LB-004.
- **Estado:** ABIERTA.
- **Revisada 2026-11-16: sigue vigente, acotada.** La parte de filesystem ya no aplica: `ArchivoController` depende solo de `InputPort` y el almacenamiento es MinIO con antivirus (véase su Javadoc). Sigue abierto el ownership de lectura docente: `DescargarArchivoUseCaseImpl` mantiene `DENY_BY_DEFAULT` ("sin fila autorizada en SQL no hay lectura del storage") y la descarga cae en la regla `authenticated()` de `SecurityConfig` (el ownership se resuelve en Application). No se confirmó que la lectura del docente de los soportes de un reclamo esté cubierta.

## TD-005

- **Descripción:** Política temporal DB/API. Hay LocalDateTime en sesiones y timestamps de eventos Instant; UTC end-to-end no está acordado con DB.
- **Impacto:** Medio.
- **Evidencia:** application/features/sesion; application/secondaryports/realtime/RealtimeEvent.java.
- **Motivo:** No convertir horas existentes por inferencia.
- **Resolución esperada:** Contrato temporal por campo y tests con DB/frontend aprobados. LB-001B documenta el mapeo del consumer (`date/startTime/endTime` reciben el datetime completo) como [DR-003](../work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md#dr-003--representación-temporal-de-sesión); no resuelve timezone.
- **Bloquea línea base:** sí, LB-001 si afecta sus campos.
- **Estado:** CLOSED_FOR_GOLDEN_PATH (LB-001C.1). Wire HTTP congelado; no equivale a política temporal global cerrada.
- **Actualización LB-001B.3 (2026-09-23, avance parcial, NO cierre):** `CONTRACT_FREEZE.md` §5 de ese work item introdujo `JdbcValueMapper.toLocalDateTimeUtc(Object)`, que decodifica `Sesion.fechaHoraInicio`/`fechaHoraFin` como UTC fijo ignorando `TimeZone.getDefault()` en el momento de la lectura, verificado con test real (no solo Javadoc). Aplicado y GREEN en 2 de 3 llamadores confirmados (`SesionRepositorySqlServerAdapter`, `ReporteAsistenciaSqlServerAdapter`); el tercero (`SesionMateriaEstudianteSqlServerAdapter`) permanece con el defecto original por un `TEST_CONTRACT_CONFLICT` sin resolver (ver [TD-037](#td-037)). La representación HTTP (wire format) no cambió, sigue `READY_FOR_OPENAPI_DECISION` conforme a la tarea de ese work item §22. **No se cierra esta deuda**: persistencia parcialmente resuelta, contrato HTTP sin decidir. Ver [LB-001B.3 CLOSURE](../work-items/LB-001B.3-backend-db-alignment/CLOSURE.md).
- **Actualización LB-001B.4 (2026-09-23):** para el Golden Path queda resuelta la persistencia/realtime: los lectores de `Sesion.fechaHoraInicio/fechaHoraFin` usan `toLocalDateTimeUtc` (TD-037 cerrada), `occurredAt` es `Instant` UTC con `Z` y `Horario` es hora local institucional ([contrato](../contracts/BACKEND_GOLDEN_PATH_CONTRACT.md) §I). **No se declara cerrada una migración temporal global**: la representación HTTP final de `LocalDateTime` (sin zona) se congela en LB-001C. Ver [CLOSURE](../work-items/LB-001B.4-final-backend-contract-closure/CLOSURE.md).
- **Actualización LB-001C.1 (2026-09-24):** el wire AS-IS de sesión queda congelado como ISO local
  sin offset, con semántica UTC persistida y extensión explícita en OpenAPI. Es
  `MIGRATION_CANDIDATE`, no RFC 3339 UTC fingido. La política temporal global continúa fuera de
  alcance; TD-005 ya no bloquea el contrato Golden Path.

## TD-006

- **Descripción:** Identificación numérica. numeroIdentificacion continúa Integer en Java; documento histórico describe INT DB. Migración String/VARCHAR exige contrato externo.
- **Impacto:** Medio.
- **Evidencia:** archive/pendientes-arquitectura.md; requests y DTO de usuario.
- **Motivo:** Mantener JSON NUMBER vigente; no afirmar tipo DB desplegado sin DDL.
- **Resolución esperada:** Contrato coordinado DB/HTTP/frontend y migración compatible.
- **Bloquea línea base:** no, salvo alcance de identificación.
- **Estado:** ABIERTA.

## TD-007

- **Descripción:** Códigos DB machine-readable. Clasificador depende de operación/mensajes; falta código estable junto a estadoResultado/mensajeUsuarioResultado/mensajeTecnicoResultado. Caso histórico GEN_001 en usp_validar_tipo_identificacion_exista_por_id_interno puede terminar ERR_DB_UNCLASSIFIED.
- **Impacto:** Alto diagnóstico.
- **Evidencia:** [DbFailureClassifier](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java); archive/pendientes-arquitectura.md.
- **Motivo:** Requiere equipo DB, no inventar codigoResultado.
- **Resolución esperada:** Catálogo DB liberado y traducción/tests por código estable.
- **Bloquea línea base:** sí, si bloquea contrato de errores LB-001/002.
- **Estado:** ABIERTA.

## TD-008

- **Descripción:** Validación runtime de sesión/asistencia sobre la DB actual.
- **Impacto:** Alto mientras estuvo abierta.
- **Evidencia de cierre:** [LB-003 VALIDATION](../work-items/LB-003-quality-gate-golden-path/VALIDATION.md) registra la suite targeted sobre SQL Server 16.0 / `gestionasistenciadb`: 59 tests, 0 failures, 0 errors y 0 skips, con fixtures reales, firma Golden Path 16/16, write/read, paridad JDBC/JPA, atomicidad, concurrencia y realtime posterior al commit. [MV-006](MANUAL_VALIDATION_LEDGER.md) conserva la validación runtime/E2E manual de POST, readback, AN/SJC/EX, dos clientes SSE y reconvergencia HTTP.
- **Motivo del cierre:** se satisfizo la resolución esperada: IT real con fixtures, cero skips relevantes, versión DB y E2E trazables. La certificación no depende de inspección estática.
- **Resolución esperada:** cumplida por LB-003.
- **Bloquea línea base:** no; condición resuelta para LB-003.
- **Estado:** CLOSED — LB-003 (2026-09-29).

## TD-009

- **Descripción:** Estados de asistencia y registro individual. Java lote admite AN/SJC/EX. Históricos A/T y mapeo idEstadoAsistencia individual no tienen contrato DB inequívoco; registrarAsistencia lanza FeatureUnavailableException.
- **Impacto:** Alto.
- **Evidencia:** RegistroAsistenciaSesionDomain; [AsistenciaRepositorySqlServerAdapter](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/core/AsistenciaRepositorySqlServerAdapter.java); archive/pendientes-arquitectura.md.
- **Motivo:** No extrapolar enum de lote al registro individual.
- **Resolución esperada:** Contrato DB liberado y semántica individual acordada; paridad/negativos certificados. LB-001B añade el lado de **lectura**: `GET …/asistencias` devuelve `codigoRazonCausa` sin filtrar y el consumer solo admite AN/SJC/EX ([DR-006](../work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md#dr-006--dominio-de-estado-en-lectura)).
- **Bloquea línea base:** no (resuelta).
- **Estado:** **CLOSED (2026-11-07, CULM-001 D.7).** Se retiró el registro individual autónomo `POST /api/v1/asistencias` y el procedimiento almacenado `usp_registrar_asistencia_estudiante_autonomo` (migración 26). El registro de asistencia individual queda cubierto por lote y registro por toma (HU027).

## TD-010

> **Estado vigente (2026-11-16): CERRADA — RESUELTA POR DECISIÓN (Opción A).** `src/main` ya no contiene `JdbcTemplate` ni `AuditEventJdbcRepository`; la auditoría se persiste con `AuditEventJpaRepository` y `AuditEventEntity` (`infrastructure/adapter/secondary/persistence/sqlserver/jpa/`). La decisión (DML directo JPA sobre `dbo.AuditoriaEvento`, sin SP nuevo) consta en el registro histórico del backend (`docs/baseline/TECHNICAL_DEBT.md`, TD-010), que aclara que la aprobación vino de la instrucción del arquitecto y que no hay aprobación formal escrita del dueño de BD. Lo que sigue más abajo es histórico.

- **Descripción:** Auditoría SQL con DML directo. AuditEventJdbcRepository escribe/consulta dbo.AuditoriaEvento directamente, excepción conocida a SP público/views. Prioridad P1 histórica.
- **Impacto:** Alto.
- **Evidencia:** infrastructure/audit/adapter/sqlserver/AuditEventJdbcRepository.java; [infrastructure-structure.md](../architecture/infrastructure-structure.md).
- **Motivo:** Requiere SPs DB; nombres usp_RegistrarEventoAuditoria/usp_ConsultarEventoAuditoriaPorCorrelationId son propuestas, no objetos comprobados.
- **Resolución esperada:** Contratos públicos liberados y adapter con CanonicalStoredProcedureExecutor, pruebas de auditoría.
- **Bloquea línea base:** no para LB-000; revisar release DB.
- **Estado:** ABIERTA.

## TD-011

> **Reclasificada (2026-11-16).** El bloqueo "LB-005" es de una línea base ya cerrada. Hoy no bloquea la demostración; solo condiciona si producción exige entrega durable de los eventos en tiempo real (SSE en memoria, véanse TD-003 y TD-063).

- **Descripción:** Outbox y consistencia durable. Outbox puede requerir estructura DB; hoy SQL/realtime no tienen atomicidad distribuida.
- **Impacto:** Medio.
- **Evidencia:** archive/pendientes-arquitectura.md; [reactive-realtime.md](../architecture/reactive-realtime.md).
- **Motivo:** Evolución condicionada por necesidades de entrega y equipo DB.
- **Resolución esperada:** ADR de garantías, contrato DB y pruebas de recuperación si se adopta.
- **Bloquea línea base:** sí, LB-005 si exige durabilidad.
- **Estado:** ABIERTA.

## TD-012

- **Descripción:** DataSource específico por provider. Solo SQL Server; antes de otro motor o provider no JDBC debe separarse ownership/config del DataSource.
- **Impacto:** Medio.
- **Evidencia:** [adapter-composition-standard.md](../architecture/adapter-composition-standard.md); infrastructure-structure.md.
- **Motivo:** No crear abstracción especulativa con un solo provider.
- **Resolución esperada:** Segundo provider no fuerza DataSource SQL Server y wiring probado.
- **Bloquea línea base:** no, salvo incorporar otro provider.
- **Estado:** ABIERTA.

## TD-013

- **Descripción:** Provisioning institucional incompleto. CrearCoordinadorUseCaseImpl y RegistrarDocenteDesdeUsuarioUseCaseImpl no llaman Identity; POST /usuarios provisiona siempre ESTUDIANTE y está bajo authenticated(). Falta política de quién puede provisionar cada rol.
- **Impacto:** Alto.
- **Evidencia:** keycloak-identity-provider.md; [runtime-security-provider-architecture.md](../security/runtime-security-provider-architecture.md).
- **Motivo:** Resolver contrato funcional/roles, sin inventar permisos.
- **Resolución esperada:** Flujos/roles autorizados acordados, implementados y E2E (MV-002).
- **Bloquea línea base:** no para Golden Path; sí antes de liberar provisioning afectado.
- **Estado:** ABIERTA.

## TD-014

- **Descripción:** Confianza del correo en IdP. Adapter marca emailVerified=true suponiendo correo institucional confiable.
- **Impacto:** Alto.
- **Evidencia:** [KeycloakIdentityProviderAdapter](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/identity/keycloak/KeycloakIdentityProviderAdapter.java); keycloak-identity-provider.md §3.2.
- **Motivo:** Confirmación funcional necesaria antes de producción.
- **Resolución esperada:** Política aprobada y pruebas de verificación acordes.
- **Bloquea línea base:** no para LB-000; sí release de identidad.
- **Estado:** ABIERTA.

## TD-015

- **Descripción:** Consistencia DB/IdP y commands multi-adapter. DB-first puede confirmar y fallar luego en Identity; no hay rollback distribuido. Drift username/correo/idUsuario requiere reconciliación; compensación del adapter solo cubre identidad nueva dentro de su operación.
- **Impacto:** Alto.
- **Evidencia:** [keycloak-identity-provider.md](../security/keycloak-identity-provider.md) §§3,7,8; archive/backend-roadmap.md.
- **Motivo:** Requiere estrategia transaccional/reintentos/idempotencia aprobada.
- **Resolución esperada:** Recuperación/reconciliación trazable sin borrar cuenta preexistente ni rollback ficticio.
- **Bloquea línea base:** no para Golden Path; sí alcance de reconciliación.
- **Estado:** ABIERTA.

## TD-016

- **Descripción:** Autorización contextual por completar. Revisar GET sesión por ID, docente por ID/asignaciones y estudiante por ID. Consulta sesiones por grupo ya aplica titularidad en código; falta evidencia runtime. ABAC más fino no implementado.
- **Impacto:** Alto.
- **Evidencia:** [runtime-security-provider-architecture.md](../security/runtime-security-provider-architecture.md); ConsultarSesionesPorGrupoUseCaseImpl.
- **Motivo:** No improvisar ownership en controller ni confundir Layer 1 con Layer 2.
- **Resolución esperada:** Reglas aprobadas y pruebas positivas/negativas por recurso.
- **Bloquea línea base:** sí cuando la vertical afectada lo requiera.
- **Estado:** ABIERTA.

## TD-017

- **Descripción:** Consumo frontend/SSE sin evidencia runtime. El frontend no está en este checkout; hasta LB-001B no se demostraba cliente Bearer, reconexión, refresh ni actualización UI. Polling periódico no es realtime.
- **Impacto:** Alto.
- **Evidencia:** archive/frontend-contract-alignment.md; [reactive-realtime.md](../architecture/reactive-realtime.md). **LB-001B (2026-09-20):** análisis estático del consumer (`AsistenciasUCO-Frontend@71ee6d3`) con Bearer por header, reconexión con backoff, refresh de token y recarga HTTP tras evento/reconexión; suite frontend 97/97 en verde; ver [CONTRACT_MATRIX](../work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md) (C-007, C-009…C-011).
- **Motivo:** El análisis estático no sustituye una corrida E2E con `USE_MOCKS=false`; no afirmar que está probado en runtime.
- **Resolución esperada:** Compatibilidad HTTP/eventos y MV-001/E2E.
- **Bloquea línea base:** no para Golden Path; otros escenarios realtime conservan sus gates propios.
- **Estado:** **CLOSED_FOR_GOLDEN_PATH (2026-09-24).** MV-001 fue reportado PASS por el responsable
  al autorizar LB-001C.1: SSE entre navegadores, offline→online y reconciliación HTTP. El artefacto
  externo no está en este checkout; ver
  [ENTRY_EVIDENCE](../work-items/LB-001C-openapi-contract-first/ENTRY_EVIDENCE.md). No certifica
  multi-instancia ni durabilidad (TD-003 permanece abierta).

## TD-018

- **Descripción:** Diagnóstico realtime en producción. POST /realtime/emit restringido a ADMINISTRADOR; falta decidir conservar, condicionar por property o retirar.
- **Impacto:** Medio.
- **Evidencia:** [RealtimeEventsController](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/realtime/sse/controller/RealtimeEventsController.java); SecurityConfig.
- **Motivo:** Decisión previa a producción, no bypass de casos de uso.
- **Resolución esperada:** Política y tests del comportamiento elegido.
- **Bloquea línea base:** no para LB-000; sí release realtime.
- **Estado:** ABIERTA.

## TD-019

- **Descripción:** Contratos DB ausentes o limitados. Histórico: sin command público Horario; usp_crear_grupo no persiste aula; usp_actualizar_grupo no persiste cupoMaximo/aula; uv_grupo usa cantidadEstudiantes como capacidadMaximaPermitida aunque inicia en 0. Falta definir SolicitudMatricula, Sede/EspacioFisico, DELETE físico Asignatura y DTO/alcance de reclamos sobre uv_solicitud_revision_asistencia.
- **Impacto:** Alto en verticales afectadas.
- **Evidencia:** Matriz original backend-baseline-contract; archive/pendientes-arquitectura.md; controllers con [FeatureUnavailableException](../../src/main/java/co/edu/uco/asistenciasuco/application/exception/business/FeatureUnavailableException.java).
- **Motivo:** Son hallazgos previos DB, no DDL probado en LB-000; algunos endpoints siguen bloqueados.
- **Resolución esperada:** Equipo DB aporta contratos públicos/versiones; luego contrato funcional e IT por capacidad, confirmar firmas antes de release.
- **Bloquea línea base:** no para LB-000; sí cada vertical dependiente.
- **Estado:** PENDIENTE DE EVIDENCIA DB.

## TD-020

- **Descripción:** Hashing DB y autenticación histórica. Documento antiguo no demostraba hashing de dbo.Usuario.password (nvarchar(500) NOT NULL según contrato previo). Java ya usa PasswordEncoderPort y existe UsuarioPasswordHashSqlServerIT.
- **Impacto:** Alto.
- **Evidencia:** sqlserver-connection.md; [UsuarioPasswordHashSqlServerIT](../../src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/integration/UsuarioPasswordHashSqlServerIT.java); keycloak-identity-provider.md.
- **Motivo:** No afirmar password plano actual ni cerrar hallazgo solo por test existente.
- **Resolución esperada:** Verificar contrato DB/filas de prueba sin imprimir valores y corrida IT; política conjunta DB/IdP.
- **Bloquea línea base:** no para LB-000; sí release de credenciales.
- **Estado:** PENDIENTE DE VALIDACIÓN.

## TD-021

- **Descripción:** Serialización común de errores de seguridad. SecurityErrorResponseWriter y ApiErrorResponse requieren revisar consistencia contractual.
- **Impacto:** Medio.
- **Evidencia:** archive/backend-roadmap.md; ambos tipos de Infrastructure.
- **Motivo:** No cambiar formato de 401/403 durante reorganización.
- **Resolución esperada:** Contrato común aprobado y tests de compatibilidad.
- **Bloquea línea base:** no.
- **Estado:** **CLOSED (2026-09-24, LB-001C.1).** `SecurityErrorResponseWriter` serializa el mismo
  `ApiErrorResponse`; el OpenAPI reutiliza `ApiErrorResponse` para 401/403 y `mvn verify` pasó los
  tests RBAC/seguridad. No se modificó producción.

## TD-022

> **Estado vigente (2026-11-16): CERRADA.** Evidencia: `src/main/resources/application.yml` (bloque `management`) publica solo `health,prometheus` en un puerto de gestión propio (`MANAGEMENT_SERVER_PORT`, 8090) con dirección `127.0.0.1` por defecto; `SecurityConfig` ya no menciona `/actuator/**`; `ManagementEndpointsSecurityConfiguration` limita ese puerto a `GET` de `health` y `prometheus`. Condición que pasa a producción: el puerto de gestión no debe publicarse fuera de la máquina o la red interna (en el laboratorio se abre con `MANAGEMENT_SERVER_ADDRESS=0.0.0.0` para que Prometheus en Docker llegue). Lo que sigue más abajo es histórico.

- **Descripción:** Exposición Actuator y Prometheus. SecurityConfig permite /actuator/** y application.yml expone health/prometheus; topología de despliegue determina restricciones.
- **Impacto:** Alto según exposición.
- **Evidencia:** [SecurityConfig](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/security/SecurityConfig.java); application.yml; archive/backend-roadmap.md.
- **Motivo:** No declarar producción segura por defaults locales.
- **Resolución esperada:** Decisión de despliegue y controles verificados sin romper scrape autorizado.
- **Bloquea línea base:** sí, LB-006.
- **Estado:** ABIERTA.

## TD-023

> **Reclasificada (2026-11-16).** Los bloqueos "LB-003/006" son de líneas base cerradas. La CI de BD reproducible ya existe (TD-085 describe una falla intermitente de ese pipeline). Sigue abierta solo la evidencia de gates remotos (ruleset y checks requeridos), que pasa a requisito de producción; no bloquea la demostración.

- **Descripción:** CI DB reproducible y gates remotos. Integration workflow es manual; DB externa sin provisioning versionado cross-repo. Rulesets y umbrales Sonar remotos no se prueban desde YAML.
- **Impacto:** Medio.
- **Evidencia:** [integration.yml](../../.github/workflows/integration.yml); backend-ci.yml; .github/CI.md.
- **Motivo:** No convertir integración en required check sin DB CI reproducible.
- **Resolución esperada:** CI DB controlada/versionada, evidencia remota y MV-004.
- **Bloquea línea base:** sí, LB-003/006 según alcance.
- **Estado:** OPEN / PARTIAL.
- **Actualización LB-003 (2026-09-29) — gobernanza remota OBSERVED, deuda NO cerrada:** para la
  revisión `0bfc02a` se observaron Backend CI/Quality Gate y SonarQube Cloud SUCCESS, Backend
  Security y CodeQL SUCCESS, y Dependency Review SUCCESS en el PR inmediato. Revisión humana
  autenticada de GitHub confirmó además el ruleset `Protect develop` (`status: active`,
  `target: refs/heads/develop`; PR requerido, `deletion`/`non-fast-forward` bloqueados, sin bypass)
  y sus 4 required status checks: `Backend Quality Gate`, `CodeQL Java Analysis`,
  `Dependency Review`, `SonarCloud Code Analysis`. Ruleset + required checks quedan **OBSERVED**.
  Lo pendiente para cerrar el gate LB-003 es la ejecución remota de esos 4 checks sobre el
  commit/PR que contenga los cambios actuales de LB-002/LB-003; los runs citados corresponden solo
  al commit base. [MV-004](MANUAL_VALIDATION_LEDGER.md) queda `PARTIAL / PENDING` y LB-003 queda
  `BLOCKED_PENDING_REMOTE_CI`. La deuda de CI DB reproducible/versionada se mantiene como pendiente
  posterior, previsiblemente LB-006, salvo nueva decisión normativa. Ver
  [LB-003 VALIDATION](../work-items/LB-003-quality-gate-golden-path/VALIDATION.md).

## TD-024

- **Descripción:** Verificación histórica de uploads. Runbook previo advertía posibles uploads/soportes ya indexados. git ls-files uploads/ está vacío en LB-000.
- **Impacto:** Bajo local; histórico no auditado.
- **Evidencia:** archive/repository-cleanup.md; inventario LB-000.
- **Motivo:** No borrar archivos ni reescribir historial; evaluar remoto si se acredita publicación sensible.
- **Resolución esperada:** Índice local ya limpio; análisis histórico solo si procede.
- **Bloquea línea base:** no.
- **Estado:** CERRADA EN ÍNDICE LOCAL; HISTORIAL NO EVALUADO.

## TD-025

- **Descripción:** Limpieza oportunista de helpers. ObjectHelper/CrosscuttingException se revisan solo al tocar código relacionado.
- **Impacto:** Bajo.
- **Evidencia:** archive/backend-roadmap.md.
- **Motivo:** Evitar refactor global fuera del alcance.
- **Resolución esperada:** Mejora justificada por necesidad y pruebas relevantes.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA.

## TD-026

- **Descripción:** Nombre FeaturesBeansConfigTest. Prueba SqlServerCoreRepositoryAdapterConfiguration; nombre engañoso tras refactor.
- **Impacto:** Bajo.
- **Evidencia:** infrastructure/config/FeaturesBeansConfigTest.java; archive/infrastructure-refactor-mapping.md.
- **Motivo:** Cosmético, cero Java en LB-000.
- **Resolución esperada:** Nombre coherente cuando se autorice limpieza del test.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA.

## TD-027

> **Reclasificada (2026-11-16).** El bloqueo "LB-006" es de una línea base cerrada. Hoy no bloquea la demostración; certificar el ambiente real Azure/telemetría es requisito de producción (en el laboratorio el baúl y los catálogos de Azure no se usan, véase TD-092).

- **Descripción:** Evidencia operacional Azure/telemetría. Existen capabilities, adapters, Composition Root, caches e invalidación Azure documentados; no hay artefacto vigente que certifique el ambiente real completo.
- **Impacto:** Medio.
- **Evidencia:** [adapter-composition-standard.md](../architecture/adapter-composition-standard.md); application.yml; infra/observability.
- **Motivo:** No confundir implementación AS-IS con validación de ambiente.
- **Resolución esperada:** MV-003 con versión/ambiente y evidencia sanitizada.
- **Bloquea línea base:** sí, LB-006; según capacidad modificada.
- **Estado:** ABIERTA.

## TD-028

- **Descripción:** Conflicto guía de métodos HTTP. La guía prescribe POST para commands mientras la API vigente contiene PUT/PATCH/DELETE. CORS sí permite esos métodos.
- **Impacto:** Medio.
- **Evidencia:** [http-command-query-guidelines.md](../architecture/http-command-query-guidelines.md); SecurityConfig; HTTP_AS_IS_MATRIX.md.
- **Motivo:** CONTRACT_CONFLICT CF-001: no reinterpretar por cuenta del agente.
- **Resolución esperada:** Equipo de contrato decide política para nuevos commands y compatibilidad de los existentes.
- **Bloquea línea base:** no.
- **Estado:** **CLOSED (2026-09-24, LB-001C.1).** CF-001 fue resuelto por
  [API_DESIGN_RULES](../governance/API_DESIGN_RULES.md): recursos pragmáticos + business commands,
  PUT/DELETE nuevos restringidos con `METHOD_EXCEPTION`, y compatibilidad/migración explícita para
  métodos existentes. No se cambió ningún endpoint de producción.

## Navegación de evidencia

- [adapter-composition-standard.md](../architecture/adapter-composition-standard.md)
- [infrastructure-structure.md](../architecture/infrastructure-structure.md)
- [reactive-realtime.md](../architecture/reactive-realtime.md)
- [http-command-query-guidelines.md](../architecture/http-command-query-guidelines.md)
- [keycloak-identity-provider.md](../security/keycloak-identity-provider.md)
- [runtime-security-provider-architecture.md](../security/runtime-security-provider-architecture.md)
- [sqlserver-connection.md](../integration/sqlserver-connection.md)
- [HTTP_AS_IS_MATRIX.md](../contracts/HTTP_AS_IS_MATRIX.md)
- [FINDINGS.md](../work-items/LB-000-gobernanza-documentacion/FINDINGS.md)
- [INVENTORY.md](../work-items/LB-000-gobernanza-documentacion/INVENTORY.md)

## TD-029

- **Descripción:** GlobalExceptionHandler depende de MessageCatalogPort en constructor/campo/llamada, infringiendo ControllersMustDependOnlyOnInputPortsTest.
- **Impacto:** mvn verify falla antes del gate JaCoCo; no se puede declarar build verde/DONE integral.
- **Evidencia:** corrida previa LB-000 (920 tests, 1 failure), [VALIDATION](../work-items/LB-000-gobernanza-documentacion/VALIDATION.md), CF-002.
- **Motivo:** defecto/contradicción preexistente ajeno a la reorganización; el usuario prohíbe cambios Java/tests/gates aquí.
- **Resolución esperada:** tarea arquitectónica separada con requisito/contrato, corrección autorizada y verify completo sin relajar la regla para ocultar la dependencia.
- **Bloquea línea base:** sí, DoD integral de LB-000 y cambios posteriores que requieran build verde.
- **Estado:** CERRADA (2026-09-20, [TECH-001](../work-items/TECH-001-restaurar-gate-arquitectura/CLOSURE.md)): `GlobalExceptionHandler` usa `ResolverMensajeUsuarioInputPort`; ArchUnit PASS sin cambios a la regla; `mvn verify` BUILD SUCCESS (932 tests). CF-002 RESUELTO; `TECHNICAL_BUILD_GATE = PASS`.

## TD-030

- **Fecha / responsable:** 2026-09-20 / backend-team + equipo DB.
- **Descripción:** `usp_validar_titularidad_jerarquica_interno` y `usp_validar_permiso_rbac_usuario_interno` usan `VAL_003` para fallos de autorización/titularidad, pero `VAL_003` describe nombres y apellidos obligatorios.
- **Impacto:** Medio. Código de error semánticamente incorrecto; puede confundir el mapeo de errores y el contrato HTTP.
- **Evidencia:** observación reportada durante la certificación externa DB del Golden Path (TECH-001); no verificada en este repositorio (el esquema DB no está versionado aquí).
- **Motivo:** fuera del alcance de TECH-001; no se modifica DB ni contratos.
- **Resolución esperada:** definir códigos propios de autorización/titularidad en el contrato de errores y alinear DB/backend antes del freeze OpenAPI. Relacionada con [TD-007](#td-007).
- **Bloquea línea base:** sí, LB-001C (contrato de errores).
- **Estado:** RESOLVED BY FROZEN DB BASELINE (LB-001B.4, 2026-09-23). DR-009 pasa a RESOLVED.
- **Actualización LB-001B (2026-09-20):** sigue ABIERTA y bloquea el freeze completo del contrato de errores en LB-001C; se registra como [DR-009](../work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md#dr-009--códigos-de-error-de-autorizacióntitularidad-td-030). No se resuelve en LB-001B.
- **Actualización LB-001B.3 (2026-09-23, NO se cierra):** el Bloqueo 1 de ese work item (`CONTRACT_MATRIX.md#m-19`, mapeo determinista de errores DB `SEC_001/SEC_002/ATT_001-3/SES_003/SES_004/GEN_002`) es la manifestación exacta de este mismo defecto estructural a nivel de contrato: sin código de catálogo estable garantizado por el result set público (4 columnas, sin quinto campo `codigo`), no se puede construir el mapeo `SEC_*`/`VAL_003` que `DR-009`/`TD-030` exigen. Declarado `CONTRACT_CONFLICT` por decisión explícita del usuario de dejarlo en espera; ver [TD-036](#td-036) (nueva, alcance más preciso de este mismo problema) y [LB-001B.3 CLOSURE](../work-items/LB-001B.3-backend-db-alignment/CLOSURE.md). Sigue **ABIERTA**, sin evidencia de resolución.
- **Actualización LB-001B.4 (2026-09-23):** el contrato DB congelado (SHA-256 `45e48c5a...9aec`) formaliza el canal `DBCODE` y los SP del Golden Path emiten `SEC_001/SEC_002` (autorización/titularidad) en lugar de `VAL_003`. El backend mapea `SEC_001/SEC_002/EST_004 -> 403/FORBIDDEN` (`ForbiddenException`), verificado con `AsistenciaRepositorySqlServerIT` 6/6 sobre DB real (docente ajeno -> `FORBIDDEN`). Ver [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md), [VALIDATION](../work-items/LB-001B.4-final-backend-contract-closure/VALIDATION.md).

## TD-031

- **Fecha / responsable:** 2026-09-20 / equipo frontend (hallazgo de LB-001B).
- **Descripción:** En el frontend `withInterceptors([correlation, auth, error])`: ante un 401 devuelto por el backend, `errorInterceptor` (el más cercano al backend) invoca `notifySessionExpired()` —que limpia el token y el refresh token en memoria y redirige a `/login`— antes de que `authInterceptor.handle401` intente renovar el token, por lo que el refresco silencioso tras 401 (commit `7d21f28`) no puede tener éxito. La renovación preventiva (`getValidAccessToken(30)`) no se ve afectada.
- **Impacto:** Medio (sesión expirada prematuramente ante un 401 recuperable).
- **Evidencia:** `src/app/app.config.ts` l.21; `src/app/core/interceptors/error.interceptor.ts` l.14-24; `auth.interceptor.ts` l.47-54,66-107; `auth.service.ts` l.439-454 (`AsistenciasUCO-Frontend@71ee6d3`). **Inferido por lectura estática; no ejecutado ni cubierto por specs** (no existe spec de interceptores).
- **Motivo:** LB-001B es `CONTRACT_ANALYSIS` y el frontend es READ-ONLY; no es una decisión contractual con el provider.
- **Resolución esperada:** confirmar con una prueba/ejecución en el frontend y, si se confirma, corregir el orden o la responsabilidad de `notifySessionExpired`; condición de cierre: spec que demuestre reintento tras 401 con refresh válido.
- **Bloquea línea base:** no para el contrato; sí antes de certificar autenticación E2E (LB-003).
- **Estado:** CERRADA (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`). Evidencia: `npm run verify` PASS 184/184; no queda como bloqueador de LB-001C.

## TD-032

- **Fecha / responsable:** 2026-09-20 / equipo frontend (hallazgo de LB-001B).
- **Descripción:** `SECURITY_FINDING` (tipo: credencial por defecto embebida en código cliente). El flujo de matrícula de estudiantes de la pantalla de asistencia asigna una contraseña por defecto cuando el docente no la indica. **El valor no se reproduce en este ledger.**
- **Impacto:** Medio (cuentas provisionadas con una credencial conocida por cualquiera que lea el bundle). Fuera del Golden Path; relacionada con [TD-013](#td-013) y [TD-020](#td-020).
- **Evidencia:** `src/app/features/attendance/attendance-control/attendance-control.component.ts`, método `onRegisterStudentSubmit` (`AsistenciasUCO-Frontend@71ee6d3`).
- **Motivo:** LB-001B no modifica el frontend; el valor no se copia por regla de secretos de [AGENTS](../../AGENTS.md).
- **Resolución esperada:** retirar la credencial por defecto (exigir contraseña o política de provisioning acordada con backend/IdP); condición de cierre: sin contraseña literal en el código y prueba que lo verifique.
- **Bloquea línea base:** no para el Golden Path; sí release del frontend.
- **Estado:** CERRADA (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`). Evidencia: `PASSWORD DEFAULT COUNT = 0`; los formularios exigen contraseña explícita y los tests de validación permanecen verdes.

## TD-033

- **Fecha / responsable:** 2026-09-20 / equipo frontend (hallazgo de LB-001B).
- **Descripción:** En `AttendanceControlComponent` un error al cargar las sesiones del grupo se resuelve con `sessions.set([])` sin aviso, y los estados realtime `UNAUTHORIZED`/`ERROR`/`DISCONNECTED` no se muestran a nadie (solo el servicio de sincronización se suscribe a `connectionState$`). Un 403/500 se ve como «sin sesiones» y la pérdida de actualizaciones en vivo es invisible.
- **Impacto:** Medio (oculta fallos de contrato/autorización al usuario y al diagnóstico).
- **Evidencia:** `attendance-control.component.ts` l.460-462; `attendance-realtime-sync.service.ts`; `fetch-sse-realtime-transport.ts` l.197-202 (`AsistenciasUCO-Frontend@71ee6d3`); ver [CONTRACT_MATRIX](../work-items/LB-001B-backend-frontend-asistencia/CONTRACT_MATRIX.md) F-08, F-14, C-009g.
- **Motivo:** LB-001B es análisis; el frontend es READ-ONLY.
- **Resolución esperada:** mostrar el error de carga y el estado de conexión; condición de cierre: specs que verifiquen aviso ante error de sesiones y ante estado `UNAUTHORIZED`/`ERROR`.
- **Bloquea línea base:** no para el contrato; sí certificación de UX del Golden Path (LB-003).
- **Estado:** CERRADA (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`). Evidencia: `npm run verify` PASS; la UX del Golden Path reporta fallos de carga/sincronización según los tests frontend vigentes.

## TD-034

- **Fecha / responsable:** 2026-09-22 / backend-team (hallazgo de LB-001B.1).
- **Descripción:** `SesionErrorCode.ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA` permanece declarada en `SesionErrorCode.java` pero, tras el retiro de `descripcion` del contrato de creación/actualización de `Sesion` (LB-001B.1: DR-001/DR-004 Opción B), ya no existe ningún `validarDescripcion(...)` en `CrearSesionDomain`/`ActualizarSesionDomain` que la lance. Confirmado por 03-tester-red (decisión de alcance: mantener la constante) y re-verificado por 05-auditor (`grep -rn "ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA" src/` solo encuentra la declaración).
- **Impacto:** Bajo. Código muerto, sin efecto funcional ni de seguridad; ruido de mantenimiento.
- **Evidencia:** `SesionErrorCode.java` línea 13; [LB-001B.1 AUDIT](../work-items/LB-001B.1-db-source-of-truth-cleanup/AUDIT.md) sección 9; [LB-001B.1 VALIDATION](../work-items/LB-001B.1-db-source-of-truth-cleanup/VALIDATION.md).
- **Motivo:** fuera de las rutas permitidas/alcance de LB-001B.1 (que retira campos del contrato, no códigos de error); retirar la constante requiere confirmar que ningún consumidor (catálogo de mensajes, frontend, tests) referencia su código machine-readable antes de eliminarla.
- **Resolución esperada:** tarea futura de limpieza menor que confirme ausencia de referencias externas y retire la constante junto con su entrada de catálogo de mensajes si aplica.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA. **Work item relacionado:** [LB-001B.1](../work-items/LB-001B.1-db-source-of-truth-cleanup/CLOSURE.md).
- **Re-confirmación LB-001B.3 (2026-09-23):** `05-auditor` de ese work item re-encontró el mismo hallazgo de forma independiente (`grep -rn "ERR_DESCRIPCION_SESION_LONGITUD_INVALIDA" src/` — solo la declaración, cero lanzadores) durante el barrido de auditoría §32. Mismo código muerto, sin cambio de estado; no se abre un ID nuevo para evitar duplicar la misma deuda. Ver [LB-001B.3 CLOSURE](../work-items/LB-001B.3-backend-db-alignment/CLOSURE.md).

## TD-035

- **Fecha / responsable:** 2026-09-22 / equipo frontend (hallazgo de LB-001B.1, confirmado primero en LB-001B.1A/1B del repo frontend).
- **Descripción:** `attendance.mapper.ts` (repo frontend) contiene **dos contratos paralelos**: (a) `fromGroupStudentsAndAttendances()`, el camino real del Golden Path, ya corregido (ausencia de asistencia ⇒ `null`, no `'AN'`, resuelto por DR-002 en LB-001B.1A); y (b) `studentFromDTO()`/`StudentAttendanceDTO`/`ClassSessionDTO` (contrato snake_case alterno, con `aula`, `tipo_sesion`, `estado_sesion`, `tema`, y el residuo `(dto.estado_asistencia as AttendanceStatus) || 'AN'` — el mismo patrón que DR-002 prohíbe en el camino real). Los consumidores de `studentFromDTO()`/`ClassSessionDTO` no fueron identificados en esta sesión backend.
- **Impacto:** Medio si algún flujo activo usa `studentFromDTO()`: reintroduciría por esa vía la síntesis ausencia→`AN` que el Golden Path ya corrigió. Bajo si el contrato paralelo está muerto/sin consumidor.
- **Evidencia:** `AsistenciasUCO-Frontend/src/app/core/mappers/attendance.mapper.ts` (línea ~49, `studentFromDTO()`), leído completo en la sesión de [LB-001B.1 PLAN](../work-items/LB-001B.1-db-source-of-truth-cleanup/PLAN.md) AS-IS #13; confirmado sin corrección por diseño en `LB-001B.1A CLOSURE.md` y en el `PLAN.md` de `LB-001B.1B-db-source-of-truth-cleanup` (repo frontend), ambos excluyéndolo explícitamente de su alcance.
- **Motivo:** decisión humana 2026-09-22 (sección de la tarea autorizada de LB-001B.1): no se corrige dentro de LB-001B.1 (backend) ni de LB-001B.1A/1B (frontend); se documenta como deuda para una tarea futura dedicada, que primero debe identificar consumidores reales de `studentFromDTO()`/`ClassSessionDTO`.
- **Resolución esperada:** identificar consumidores del contrato paralelo; si tiene uso activo, aplicar la misma corrección que DR-002 (ausencia ⇒ `null`, no `'AN'`) o retirar el contrato paralelo si está muerto; condición de cierre: sin residuo `|| 'AN'` alcanzable desde código en uso, con test que lo verifique.
- **Bloquea línea base:** no para el Golden Path; sí antes de certificar UX/datos del Golden Path (LB-003), si se confirma consumidor activo.
- **Estado:** CERRADA (2026-09-22, frontend `LB-001B.1C-final-contract-cleanup`). Evidencia: `ClassSessionDTO`, `studentFromDTO`, `studentToDTO`, `sessionFromDTO` y `sessionToDTO` eliminados; residuo `|| 'AN'` = 0; `npm run verify` PASS 184/184.

## TD-036

- **Fecha / responsable:** 2026-09-23 / backend-team, con decisión pendiente del equipo DB o del usuario sobre cómo exponer un canal determinista de errores.
- **Descripción:** El mapeo `DB semantic → backend ErrorDefinition → HTTP status → ApiErrorResponse.code` exigido para `SEC_001`, `SEC_002`, `ATT_001`, `ATT_002`, `ATT_003`, `SES_003`, `SES_004`, `GEN_002` no existe de forma determinista. `DbFailureClassifier`/`DbExceptionTranslator` son 100 % *pattern matching* de frases en español; ningún literal de código de catálogo (`SEC_*`/`ATT_*`/`SES_*`/`GEN_*`) aparece como señal de clasificación. El result set público del contrato DB congelado tiene exactamente 4 columnas (`idCorrelacion, mensajeUsuarioResultado, mensajeTecnicoResultado, estadoResultado`), sin un quinto campo `codigo` garantizado. 8 de 11 códigos relevantes del Golden Path caen hoy en `ERR_DB_UNCLASSIFIED` → HTTP 500 en vez de 403/400/409, violando el requisito de no devolver 500 para RBAC/titularidad. `SES_001`, `RC_001`, `EST_004` funcionan hoy solo por coincidencia accidental de texto libre con patrones de otros dominios, sin garantía contractual.
- **Impacto:** Crítico. Toca prácticamente todo el Golden Path protegido (crear/actualizar sesión, batch de asistencia, RBAC/titularidad).
- **Evidencia:** [DbFailureClassifier](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java); [DbExceptionTranslator](../../src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbExceptionTranslator.java); [LB-001B.3 CONTRACT_MATRIX](../work-items/LB-001B.3-backend-db-alignment/CONTRACT_MATRIX.md#matriz) fila M-19 y tabla "Códigos/enums"; [LB-001B.3 CONTRACT_FREEZE](../work-items/LB-001B.3-backend-db-alignment/CONTRACT_FREEZE.md) §6.
- **Motivo:** `CONTRACT_CONFLICT` declarado explícitamente conforme a `AGENTS.md` §"Cuándo detenerse" — no se clasifica por heurística de texto frágil sin test contractual; decisión explícita del usuario (2026-09-23) de dejarlo en espera y continuar solo con el alcance ya desbloqueado de `LB-001B.3`.
- **Resolución esperada:** decisión humana sobre si se solicita al repo DB un canal estructurado adicional (p. ej. un quinto campo `codigo` en el result set público) o si se acepta el riesgo de texto libre con tests de regresión explícitos marcados como no-contractuales; luego construir la tabla de mapeo exigida y congelarla con tests.
- **Bloquea línea base:** sí, LB-001C (contrato de errores) — mismo bloqueo que [TD-030](#td-030)/DR-009, alcance más preciso.
- **Estado:** CLOSED (LB-001B.4, 2026-09-23). Sustituye el `CONTRACT_CONFLICT`.
- **Actualización LB-001B.4 (2026-09-23):** CERRADA. Parser estricto `DbTechnicalError` (`^DBCODE=([A-Z0-9_]+)\|(.*)$`) + `DbFailureClassifier` por código (`SEC_001/SEC_002/EST_004 -> FORBIDDEN`; `ATT_001-003/GEN_002/RC_001/SES_004 -> VALIDATION_ERROR`; `SES_001 -> RESOURCE_NOT_FOUND`; `SES_003 -> FEATURE_UNAVAILABLE`; desconocido/malformado -> `ERR_DB_UNCLASSIFIED`, fail-closed). Texto legacy solo si no hay marcador DBCODE. 959/959 tests; sin clasificación por texto en el Golden Path. `USU_001` sin mapeo formal: [TD-047](#td-047).

## TD-037

- **Fecha / responsable:** 2026-09-23 / backend-team (hallazgo de LB-001B.3, `04-implementador` + confirmado por `05-auditor`).
- **Descripción:** `SesionMateriaEstudianteSqlServerAdapter` sigue leyendo `Sesion.fechaHoraInicio`/`fechaHoraFin` con `JdbcValueMapper.toLocalDateTime(Object)` (dependiente de `TimeZone.getDefault()` en el momento de la lectura), no con el método dedicado `toLocalDateTimeUtc(Object)` introducido en la misma fase para los otros dos llamadores confirmados de este campo. El cambio de llamada se intentó y se revirtió en la misma sesión porque rompía `SesionMateriaEstudianteSqlServerAdapterTest.consultarSesionesMateria_mapea_proyeccion_completa` (fixture construye el `Timestamp` bajo zona ambiental no controlada, mismo defecto ya dictaminado para `SesionRepositorySqlServerAdapterTest`), un `TEST_CONTRACT_CONFLICT` que ni `CONTRACT_FREEZE.md` §5.4 ni el dictamen previo de `05-auditor` cubrieron.
- **Impacto:** Medio. Defecto de producción real y activo (no solo brecha de cobertura): en una máquina cuya zona horaria por defecto no sea UTC, la fecha/hora de sesión leída por este adaptador queda desplazada. Fuera del Golden Path de `TASK_AUTORIZADA.md` §7 (el endpoint que lo consume es `GET /api/v1/estudiante/materias/{materiaId}/sesiones`), pero dentro del alcance textual de la prohibición general de `ZoneId.systemDefault()`/equivalentes para `Sesion`.
- **Evidencia:** `SesionMateriaEstudianteSqlServerAdapter.java` líneas 43-44; [LB-001B.3 VALIDATION](../work-items/LB-001B.3-backend-db-alignment/VALIDATION.md) §7.2; [LB-001B.3 AUDIT](../work-items/LB-001B.3-backend-db-alignment/AUDIT.md) §2.5, §3.
- **Motivo:** `04-implementador` no modifica tests RED para forzar GREEN; revirtió el cambio de producción dependiente en vez de tocar `SesionMateriaEstudianteSqlServerAdapterTest.java`, conforme a su rol. Requiere que `02-contratos` autorice la misma corrección de fixture ya aplicada a `SesionRepositorySqlServerAdapterTest` (`TimeZone.setDefault(UTC)` antes de construir el `Timestamp`, restaurar en `finally`) y que `03-tester-red` la ejecute.
- **Resolución esperada:** corrección de fixture autorizada + re-aplicación del cambio de llamada a `toLocalDateTimeUtc` en `SesionMateriaEstudianteSqlServerAdapter.java`; condición de cierre: test GREEN con el mismo patrón de estabilidad UTC ya usado en `JdbcValueMapperTest`/`SesionRepositorySqlServerAdapterTest`.
- **Bloquea línea base:** no para el Golden Path; sí antes de certificar UTC end-to-end para todos los lectores de `Sesion.fechaHoraInicio`/`fechaHoraFin` (relacionado con [TD-005](#td-005)).
- **Estado:** CLOSED (LB-001B.4, 2026-09-23).
- **Actualización LB-001B.4 (2026-09-23):** CERRADA. `SesionMateriaEstudianteSqlServerAdapter` usa `toLocalDateTimeUtc`; el fixture se construye con `Timestamp.from(Instant)` (dictamen `TEST_CONTRACT_CONFLICT` en [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md)). 959/959 GREEN.

## TD-038

- **Fecha / responsable:** 2026-09-23 / backend-team (hallazgo de `05-auditor` en LB-001B.3).
- **Descripción:** `ReporteAsistenciaSqlServerAdapterTest.consultarReporteAsistenciaGrupo_mapea_fila_completa` construye un `Timestamp` bajo zona ambiental no controlada para `fechaHoraInicio`/`fechaHoraFin`, pero **no asevera el valor de esos campos** (solo asevera `codigoGrupo`, `numeroSesion`, `asistio`, `razonCausa`). El código de producción (`ReporteAsistenciaSqlServerAdapter`) ya es correcto — usa `toLocalDateTimeUtc` desde esta misma fase — pero el test no lo protege: si alguien revirtiera esa llamada a `toLocalDateTime`, esta suite no lo detectaría.
- **Impacto:** Bajo. No es un defecto de producción activo, es una brecha de cobertura de regresión.
- **Evidencia:** `ReporteAsistenciaSqlServerAdapterTest.java` líneas 43-44 (construcción) sin aserción de los campos temporales; [LB-001B.3 VALIDATION](../work-items/LB-001B.3-backend-db-alignment/VALIDATION.md) §7.2; [LB-001B.3 AUDIT](../work-items/LB-001B.3-backend-db-alignment/AUDIT.md) §3.
- **Motivo:** fuera del alcance de `CONTRACT_FREEZE.md` §5.4 de `LB-001B.3` (que solo autorizó corregir el fixture de `SesionRepositorySqlServerAdapterTest`); no reportado antes de la auditoría de esa fase.
- **Resolución esperada:** agregar aserción explícita de `fechaHoraInicio`/`fechaHoraFin` (con fixture bajo zona controlada, mismo patrón que los demás tests de estabilidad UTC) a `ReporteAsistenciaSqlServerAdapterTest`.
- **Bloquea línea base:** no.
- **Estado:** CLOSED (LB-001B.4, 2026-09-23).
- **Actualización LB-001B.4 (2026-09-23):** CERRADA. `ReporteAsistenciaSqlServerAdapterTest` incluido en el RED con fixture UTC estable; 959/959 GREEN.

## TD-039

> **Estado vigente (2026-11-16): CERRADA — RESUELTA POR EVIDENCIA.** La firma que faltaba está en el SP de `develop` de BD (`schema/stored-procedures/usp_cerrar_sesion.sql`): `@idSesion`, `@idDocente`, `@idCorrelacion`, `@idUsuarioEjecutor`, los mismos cuatro parámetros que envía `SesionJpaRepository.SQL_CERRAR_SESION`; el SP sigue siendo legacy no soportado (`SES_003`, sin escrituras), como dice el contrato. El texto de `DB_BASELINE_CONTRACT.md` no cambia (contrato congelado). Lo que sigue más abajo es histórico.

- **Fecha / responsable:** 2026-09-23 / backend-team + equipo DB.
- **Descripción:** El contrato DB congelado (`DB_BASELINE_CONTRACT.md`) documenta el comportamiento de `usp_cerrar_sesion` (legacy no soportado: retorna `SES_003`, `estadoResultado = 0`, sin escrituras) pero **no documenta su firma exacta de parámetros**. El backend (`SesionRepositorySqlServerAdapter.SQL_CERRAR_SESION`) sigue enviando `@idSesion, @idDocente, @idCorrelacion, @idUsuarioEjecutor`; no se puede confirmar si `@idDocente` ahí es un ghost param real o si el SP legacy todavía lo requiere sin abrir el repo DB. El endpoint HTTP `POST /api/v1/sesiones/cierres` sigue vivo (no es código muerto) pero fuera del Golden Path de `TASK_AUTORIZADA.md` §7.
- **Impacto:** Medio. El comportamiento observable es correcto (el SP frozen garantiza que la llamada siempre falla con `SES_003`, nunca simula éxito), pero la firma real que el backend envía no está congelada ni verificada contra el contrato.
- **Evidencia:** `SesionRepositorySqlServerAdapter.java` líneas 53-59, 226-241; `SesionController.java` líneas 130-138; [LB-001B.3 CONTRACT_MATRIX](../work-items/LB-001B.3-backend-db-alignment/CONTRACT_MATRIX.md#matriz) fila M-03; [LB-001B.3 CONTRACT_FREEZE](../work-items/LB-001B.3-backend-db-alignment/CONTRACT_FREEZE.md) §3.
- **Motivo:** `BLOCKED_BY_MISSING_EVIDENCE` — no se puede saber sin abrir el repo DB, fuera de alcance de `LB-001B.3`. Clasificado `OUT_OF_TARGET`/`LEGACY_NOT_SUPPORTED` para el contrato target de `LB-001C`, sin tocar código ni eliminar el endpoint sin evidencia de ausencia de consumidores.
- **Resolución esperada:** equipo DB aporta la firma exacta documentada de `usp_cerrar_sesion`; luego decidir si `@idDocente` se retira del envío o si el SP legacy lo requiere tal cual.
- **Bloquea línea base:** no para el Golden Path (endpoint fuera de alcance); sí antes de incluir `POST /sesiones/cierres` en cualquier contrato congelado futuro.
- **Estado:** BLOCKED_BY_MISSING_EVIDENCE. **Work item relacionado:** [LB-001B.3](../work-items/LB-001B.3-backend-db-alignment/CLOSURE.md).

## TD-040

- **Fecha / responsable:** 2026-09-23 / backend-team + equipo DB.
- **Descripción:** `GrupoRepositorySqlServerAdapter.SQL_CONSULTAR_ESTUDIANTES_GRUPO` (usado por `GET /api/v1/grupos/{grupoId}/estudiantes`, endpoint del Golden Path) hace `INNER JOIN` contra `uv_estudiante_identidad` y `uv_usuario` para derivar `documento`, `correo` y `nombreCompleto`, en vez de usar `eg.nombreCompletoEstudiante` ya provisto por `uv_estudiante_grupo` (vista sí documentada). Ninguna de las dos vistas usadas por el `JOIN` (`uv_estudiante_identidad`, `uv_usuario`) está documentada en `DB_BASELINE_CONTRACT.md`, ni en el inventario de objetos ni en las proyecciones de lectura del Golden Path.
- **Impacto:** Alto. El endpoint SÍ está en el Golden Path de `TASK_AUTORIZADA.md` §7; no se puede confirmar `MATCH` ni `MISMATCH` de esta porción del contrato sin evidencia DB adicional.
- **Evidencia:** `GrupoRepositorySqlServerAdapter.java` líneas 127-143; [LB-001B.3 CONTRACT_MATRIX](../work-items/LB-001B.3-backend-db-alignment/CONTRACT_MATRIX.md#matriz) fila M-08.
- **Motivo:** `BLOCKED_BY_MISSING_EVIDENCE` — no se modifica sin evidencia; el comportamiento AS-IS permanece intacto (no se prohíbe seguir operando, solo se prohíbe modificar sin evidencia).
- **Resolución esperada:** equipo DB documenta `uv_estudiante_identidad`/`uv_usuario` en `DB_BASELINE_CONTRACT.md` (o su equivalente congelado); luego confirmar si el `JOIN` actual es correcto o si debe reemplazarse por `eg.nombreCompletoEstudiante`.
- **Bloquea línea base:** sí — está en el Golden Path; bloquea el freeze íntegro del contrato de lectura de estudiantes por grupo antes de `LB-001C`.
- **Estado:** CLOSED — EVIDENCE_RESOLVED (LB-001B.4, 2026-09-23), con salvedad TD-046.
- **Actualización LB-001B.4 (2026-09-23):** columnas de `uv_estudiante_grupo`, `uv_estudiante_identidad` y `uv_usuario` confirmadas contra la DB real (`GoldenPathSqlStoredProcedureContractIT` 16/16); el `SELECT` del adapter se ejecutó en solo lectura y conserva el conteo de `uv_estudiante_grupo` (2 = 2). **Salvedad del auditor:** `DB_BASELINE_CONTRACT.md` sigue sin documentar esas vistas; acción no bloqueante para el equipo DB en [TD-046](#td-046).

## TD-041

> **Estado vigente (2026-11-16): CERRADA.** El commit `99190f0` de la rama `feat/db-golden-path-baseline-freeze` es ancestro de `develop` del repositorio de BD (`git merge-base --is-ancestor 99190f0 repo-antiguo/develop` devuelve verdadero), así que el snapshot ya no depende de una rama sin fusionar; el contrato DB está congelado en `docs/contracts/db/`. El bloqueo "LB-001C" era de una línea base cerrada. Lo que sigue más abajo es histórico.

- **Fecha / responsable:** 2026-09-23 / backend-team + equipo DB.
- **Descripción:** La rama de origen del snapshot DB congelado (`feat/db-golden-path-baseline-freeze`, commit `99190f0...`, repo `gestion-asistencia-db`) no está fusionada a `main`/`develop` de ese repositorio, conforme a `docs/contracts/external/db/PROVENANCE.md`. Si esa rama recibe nuevos commits antes de que `LB-001C` congele el contrato definitivo, el snapshot ya importado (`DB_BASELINE_CONTRACT.md`, SHA-256 `1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103`) queda desactualizado.
- **Impacto:** Medio. Riesgo de trabajar sobre un contrato obsoleto sin darse cuenta, no un defecto actual.
- **Evidencia:** `docs/contracts/external/db/PROVENANCE.md`; [LB-001B.3 PLAN](../work-items/LB-001B.3-backend-db-alignment/PLAN.md) riesgo 1.
- **Motivo:** fuera del control del backend; requiere seguimiento del repo DB (equipo/owner externo a este checkout).
- **Resolución esperada:** confirmar con el equipo DB que la rama se fusionó (o re-capturar un nuevo snapshot con SHA-256 actualizado) antes de congelar `LB-001C`.
- **Bloquea línea base:** sí, si el snapshot se desactualiza antes del freeze de `LB-001C` — cualquier fase que dependa de un detalle no cubierto por el snapshot actual debe registrar `BLOCKED_BY_MISSING_EVIDENCE`, no asumir texto del repo DB no importado.
- **Estado:** ABIERTA (seguimiento externo). **Work item relacionado:** [LB-001B.3](../work-items/LB-001B.3-backend-db-alignment/CLOSURE.md).
- **Actualización LB-001B.4 (2026-09-23):** el snapshot vigente es `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec` (repo DB, HEAD `99190f0...`); su origen sigue siendo `UNCOMMITTED_WORKTREE`. Sigue ABIERTA (seguimiento externo).

## TD-042

- **Fecha / responsable:** 2026-09-23 / backend-team (hallazgo de `03-tester-red`/`02-contratos` en LB-001B.3).
- **Descripción:** No existe ningún test que asegure que `RealtimeEvent.occurredAt` (tipo `Instant`, ya correcto) se serializa en HTTP/SSE como ISO-8601 UTC con sufijo `Z`. No hay ningún `JacksonOutputConfig`/customizer explícito de salida en `src/main/java`; el comportamiento real depende enteramente del autoconfigure default de Spring Boot. Punto **O** de `TASK_AUTORIZADA.md` §27 de `LB-001B.3`, evaluado pero no alcanzado en esa fase por riesgo de RED fabricado por el arnés de prueba (un `JsonMapper` "pelado" sin `ApplicationContext` real invierte el default `WRITE_DATES_AS_TIMESTAMPS`).
- **Impacto:** Bajo-medio. El tipo es correcto (`Instant`, MATCH), pero el contrato exige el test, no solo el tipo — sin evidencia de test, no hay garantía de regresión.
- **Evidencia:** `RealtimeEvent.java`; `RealtimeEventResponse.java`; [LB-001B.3 CONTRACT_MATRIX](../work-items/LB-001B.3-backend-db-alignment/CONTRACT_MATRIX.md#matriz) fila M-22; [LB-001B.3 TEST_PLAN](../work-items/LB-001B.3-backend-db-alignment/TEST_PLAN.md) sección "Punto O".
- **Motivo:** `MISSING_IN_BACKEND`, no `CONTRACT_CONFLICT` — el punto es opcional en el alcance de esa sesión y se priorizaron los 10 puntos obligatorios (A-H, N, P).
- **Resolución esperada:** crear el test de serialización solo con evidencia de un `ApplicationContext`/`@SpringBootTest` real, o confirmar/crear un `JacksonOutputConfig` de producción equivalente a `JacksonInputConfig` antes de escribir el test — no con un `JsonMapper` construido a mano.
- **Bloquea línea base:** no para el Golden Path funcional; sí antes de certificar el contrato realtime completo (`BACKEND_GOLDEN_PATH_CONTRACT.md`, punto M/N de `TASK_AUTORIZADA.md` §33).
- **Estado:** CLOSED (LB-001B.4A, 2026-09-24). Estado histórico: MISSING_IN_BACKEND. **Work item relacionado:** [LB-001B.3](../work-items/LB-001B.3-backend-db-alignment/CLOSURE.md).
- **Actualización LB-001B.4 (2026-09-23) — histórico:** se mantuvo abierta porque `RealtimeEventResponseTest` usa un `JsonMapper` construido a mano, insuficiente según esta deuda.
- **Actualización LB-001B.4A (2026-09-24) — CLOSED:** `RealtimeEventResponseSpringJsonTest` usa `@SpringBootTest` (`JacksonAutoConfiguration` + `JacksonInputConfig`) con el `JsonMapper` inyectado por Spring (y un segundo test con `JacksonJsonHttpMessageConverter`), y afirma `occurredAt` ISO-8601 con `Z`. No hay `spring.jackson.*` en recursos, por lo que el auto-config es el de producción. Cumple la "Resolución esperada". Salvedad: contexto Jackson mínimo, no la aplicación completa; suficiente para el criterio. Ver [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md).

## TD-043

> **Estado vigente (2026-11-16): CERRADA.** Los tres SP ya no están en deriva: (1) `usp_sincronizar_usuario` no tiene consumidores, el alta genérica se retiró con `POST /api/v1/usuarios` (VAL ROL-05, 2026-11-12; comentarios en `UsuarioRepositoryPort` y `UsuarioJpaRepository`); (2) `usp_registrar_o_actualizar_plan_estudio` existe en `schema/stored-procedures/` de `develop` de BD y lo invoca `PlanEstudioJpaRepository`; (3) `usp_registrar_estudiante_en_grupo_usuario_no_existente` ya no se referencia en `src/main`: `GrupoJpaRepository.SQL_REGISTRAR_ESTUDIANTE` ejecuta `dbo.usp_registrar_estudiante_en_grupo`, que existe en `develop` de BD. No se volvió a ejecutar `-Pintegration verify` completo para esta revisión. Lo que sigue más abajo es histórico.

- **Fecha / responsable:** 2026-09-23 / backend-team + equipo DB. **Clasificación:** `NON_GOLDEN_DB_CONTRACT_DRIFT`.
- **Descripción:** tres SP invocados por adapters del backend no existen en la DB oficial (`gestionasistenciadb`, esquema `dbo`, verificado por SELECT de solo lectura sobre `sys.objects`/`sys.parameters`; ver [CONTRACT_DECISION_TD043](../work-items/LB-001B.4-final-backend-contract-closure/CONTRACT_DECISION_TD043.md)). Ningún SP existente tiene firma y semántica inequívocamente equivalentes, por lo que no se mapea por parecido de nombre.

| Adapter consumidor | SP esperado por el backend | SP en DB oficial | Vertical afectada |
|---|---|---|---|
| `UsuarioRepositorySqlServerAdapter` (`SQL_SINCRONIZAR_USUARIO`) | `dbo.usp_sincronizar_usuario` | inexistente | sincronización de usuario (identidad/perfil) |
| `PlanEstudioSqlServerAdapter` (`registrarOActualizarPlanEstudio`) | `dbo.usp_registrar_o_actualizar_plan_estudio` | inexistente | registro/actualización de plan de estudio (académico) |
| `GrupoRepositorySqlServerAdapter` (`SQL_REGISTRAR_ESTUDIANTE`) | `dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente` | inexistente | registro de estudiante nuevo en grupo (usuario no existente) |

- **Impacto:** las tres operaciones fallarán en runtime contra la DB oficial. Fuera del Golden Path LB-001; el perfil de integración completo queda `NOT_GREEN` solo por esto.
- **Evidencia:** [CONTRACT_DECISION_TD043](../work-items/LB-001B.4-final-backend-contract-closure/CONTRACT_DECISION_TD043.md).
- **Motivo:** `NON_GOLDEN_DB_CONTRACT_DRIFT`; sin evidencia suficiente para mapear a SP existentes (`usp_sincronizar_usuario_interno`, `usp_registrar_estudiante_en_grupo`, etc. difieren en firma/semántica). No se modifica código ni DB.
- **Resolución esperada:** work item contractual propio (DB owner vs backend consumer) antes de liberar cada feature: crear el SP en DB o adaptar el backend, con decisión explícita de OWNER.
- **Bloquea línea base:** no para el Golden Path; sí para liberar las tres features anteriores.
- **Actualización LB-002.1 (2026-09-26) — nueva evidencia, deuda NO cerrada:** `.\mvnw.cmd -Pintegration verify` contra `sql_server_asistencias`/`gestionasistenciadb` (freeze DB desplegado) da 6 fallos: `SqlStoredProcedureContractIT` ×3 (los tres SP de esta deuda), `GrupoRepositorySqlServerIT` ×2 y `UsuarioPasswordHashSqlServerIT` ×1 (`Could not find stored procedure`, error 2812). Son **idénticos sobre `HEAD` limpio (`df66a67`) sin cambios JPA**: preexistentes al piloto JPA, sin regresión causada por LB-002.1. El perfil `-Pintegration` global continúa `NOT_GREEN_TD043`; no se convierte en PASS. Los ITs no se modificaron (sin `@Disabled`, `Assumptions`, exclusiones, mocks ni cambio de expected); no se tocó DB. Ver [LB-002.1-VALIDATION](../work-items/LB-002-jpa-incremental/LB-002.1-VALIDATION.md).
- **Actualización LB-002.1C (2026-09-27) — consolidación NON-GOLDEN, deuda DIFERIDA (solo documental; no resuelta):** por decisión humana de priorización, la remediación de TD-043 se **difiere** y el trabajo independiente del Golden Path continúa. Sin cambios de Java, tests, OpenAPI, DB ni frontend; sin nuevos RED ni investigación adicional. Los tres componentes conocidos (no se asume equivalencia por parecido de nombre; ver también la tabla de arriba):

```text
TD-043:                     NON_GOLDEN_DB_CONTRACT_DRIFT
STATUS:                     OPEN / DEFERRED
GLOBAL EFFECT:              mvn -Pintegration verify permanece NOT_GREEN_TD043
GOLDEN PATH EFFECT:         NONE
```

  - **A. STUDENT ENROLLMENT** — backend espera `dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente` (`GrupoRepositorySqlServerAdapter`, `SQL_REGISTRAR_ESTUDIANTE`). DB: SP legacy eliminado; el contrato público vigente (`dbo.usp_registrar_estudiante_en_grupo`) exige perfil `ESTUDIANTE` en `@idUsuarioEjecutor`. Evidencia: análisis y adaptaciones de `LB-002.1C-B1` disponibles en branch/work item; decisión de diseño público de matrícula vs auto-matrícula pendiente de consenso. Estado: **DEFERRED — B1/B2 EVIDENCE AVAILABLE**.
  - **B. USER SYNCHRONIZATION** — backend espera `dbo.usp_sincronizar_usuario` (`UsuarioRepositorySqlServerAdapter`, `SQL_SINCRONIZAR_USUARIO`). DB: objeto público ausente en el contrato congelado/vigente. Remediación futura: análisis dedicado de consumidor/contrato **antes** de implementar. No asumir que el SP interno (`usp_sincronizar_usuario_interno`) es un reemplazo público válido. Estado: **DEFERRED — ANALYSIS_REQUIRED**.
  - **C. STUDY PLAN COMMAND** — backend espera `dbo.usp_registrar_o_actualizar_plan_estudio` (`PlanEstudioSqlServerAdapter.registrarOActualizarPlanEstudio`). DB: objeto público ausente en el contrato congelado/vigente; el código consumidor sigue presente. Remediación futura: análisis dedicado de consumidor/contrato antes de implementar **o retirar**. Estado: **DEFERRED — ANALYSIS_REQUIRED**.

  **Sin falsas afirmaciones:** TD-043 permanece OPEN; `-Pintegration verify` global permanece `NOT_GREEN_TD043` (6 fallos idénticos, no re-ejecutados en esta actualización); los ITs no se deshabilitan y las expectativas contractuales no se borran ni se ocultan. Esto **no** significa LB-002 GLOBAL CLOSED, `-Pintegration` GREEN ni TD-043 RESOLVED.

  **Excepción de continuidad del Golden Path (decisión de planificación):** TD-043 es NON-GOLDEN y el Golden Path funcional de asistencia es independiente de estas tres capabilities. `NON-GOLDEN TD-043 REMEDIATION: DEFERRED` · `GOLDEN PATH ENGINEERING: AUTHORIZED TO CONTINUE` (por priorización humana). Siguiente objetivo autorizado: Golden Path `registrarAsistenciasSesion`, fase técnica **LB-002.2 — JPA COMMAND PILOT** (TD-043 permanece como excepción/deuda NON-GOLDEN reconocida). Ver [LINEA_BASE](LINEA_BASE.md).
- **Estado:** **OPEN / DEFERRED** — NON_GOLDEN_DB_CONTRACT_DRIFT (no resuelta; requiere work item propio si se decide resolver). **Work item relacionado:** [LB-001B.4](../work-items/LB-001B.4-final-backend-contract-closure/CONTRACT_DECISION_TD043.md).

## TD-044

- **Fecha / responsable:** 2026-09-23 / backend-team (condición del auditor de LB-001B.4).
- **Descripción:** `DocenteRepositorySqlServerIT` omite 2 tests (`assumeTrue` por ausencia de datos). Prueban `consultarAsignacionesAcademicas` (`GET /api/v1/docentes/{docenteId}/asignaciones`), no `GET /api/v1/docente/horarios` (que usa `uv_horario_docente`, verificada por `GoldenPathSqlStoredProcedureContractIT`).
- **Impacto:** Bajo. Un skip no es PASS: esa consulta no está certificada contra DB real.
- **Evidencia:** [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md) (§Los 2 skips); [VALIDATION](../work-items/LB-001B.4-final-backend-contract-closure/VALIDATION.md).
- **Resolución esperada:** fixture autocontenido con prefijo `IT-LB001B4-`, sin `assumeTrue`, y limpieza verificable.
- **Bloquea línea base:** no (fuera del Golden Path); sí antes de certificar esa consulta.
- **Estado:** ABIERTA. **Work item relacionado:** [LB-001B.4](../work-items/LB-001B.4-final-backend-contract-closure/CLOSURE.md).

## TD-045

- **Fecha / responsable:** 2026-09-23 / backend-team + equipo DB.
- **Descripción:** `dbo.RazonCausa` conserva códigos históricos (`CPI`, `CPVP`, entre otros). La escritura solo admite `AN/SJC/EX`; la lectura (`AsistenciaConsultadaEntity`) **falla cerrado** ante cualquier estado fuera de ese dominio (DR-006, Opción A). Una fila histórica en `uv_detalle_asistencia` haría fallar todo el listado `GET /api/v1/grupos/{grupoId}/asistencias`.
- **Impacto:** Medio latente. Hoy `uv_detalle_asistencia` tiene 0 filas; el riesgo aparece con datos históricos.
- **Evidencia:** [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md) (AN/SJC/EX); test RED de la entidad.
- **Resolución esperada:** decisión de contrato (migrar/mapear históricos en DB o definir tratamiento por fila) antes de cargar datos históricos; no relajar el fail-closed por suposición.
- **Bloquea línea base:** no; sí antes de cargar datos históricos de asistencia.
- **Estado:** ABIERTA. **Work item relacionado:** [LB-001B.4](../work-items/LB-001B.4-final-backend-contract-closure/CLOSURE.md).

## TD-046

- **Fecha / responsable:** 2026-09-23 / equipo DB (con seguimiento backend-team).
- **Descripción:** salvedad del cierre de [TD-040](#td-040): las vistas `uv_estudiante_grupo`, `uv_estudiante_identidad` y `uv_usuario`, usadas por `GET /api/v1/grupos/{grupoId}/estudiantes`, existen y coinciden en columnas en la DB real, pero no están documentadas en `DB_BASELINE_CONTRACT.md` del repositorio DB.
- **Impacto:** Bajo. Contrato verificable solo por integración, no por documento.
- **Evidencia:** [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md) (TD-040).
- **Resolución esperada:** el equipo DB las documenta en su contrato y se re-importa el snapshot (nuevo SHA-256).
- **Bloquea línea base:** no.
- **Estado:** ABIERTA (acción externa, equipo DB). **Work item relacionado:** [LB-001B.4](../work-items/LB-001B.4-final-backend-contract-closure/CLOSURE.md).
- **Revisada 2026-11-16: sigue vigente, acotada.** `DB_BASELINE_CONTRACT.md` ya documenta `uv_estudiante_grupo`; `uv_estudiante_identidad` y `uv_usuario` siguen sin aparecer en ese contrato (solo se mencionan en `openapi-golden-path.yaml`, descripción de `GET /api/v1/grupos/{grupoId}/estudiantes`). El contrato está congelado: la acción corresponde al equipo de BD con un nuevo snapshot.

## TD-047

> **Estado vigente (2026-11-16): CERRADA.** `DbFailureClassifier` (líneas 205-206) mapea `USU_001` a `UsuarioErrorCode.ERR_USUARIO_NO_EXISTE`; ya no cae en `ERR_DB_UNCLASSIFIED`. Lo que sigue más abajo es histórico.

- **Fecha / responsable:** 2026-09-23 / backend-team + equipo DB.
- **Descripción:** el código `USU_001` no tiene mapeo formal DBCODE en `DbFailureClassifier`; cae en `ERR_DB_UNCLASSIFIED` (500, fail-closed). No forma parte del Golden Path.
- **Impacto:** Bajo. Comportamiento seguro pero no semántico para esa vertical.
- **Evidencia:** [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md) (DBCODE formal); `DbFailureClassifier`.
- **Resolución esperada:** definir HTTP/código semántico de `USU_001` en el contrato de la vertical de usuarios.
- **Bloquea línea base:** no (fuera del Golden Path).
- **Estado:** ABIERTA. **Work item relacionado:** [LB-001B.4](../work-items/LB-001B.4-final-backend-contract-closure/CLOSURE.md).

## TD-048

- **Fecha / responsable:** 2026-09-24 / backend-team + equipo DB (hallazgo F-4A-1 del auditor de LB-001B.4A).
- **Descripción:** `Sesion.nombre` es `nvarchar(50) NOT NULL` según la evidencia congelada ([LB-001B.1 PLAN](../work-items/LB-001B.1-db-source-of-truth-cleanup/PLAN.md), tabla "DB SESSION CONTRACT"), pero el backend valida 1..150 en Crear, Actualizar y la entidad de lectura (antes Crear 5..100). Un `nombre` de 51..150 caracteres pasa la validación y fallaría en el `INSERT`/`UPDATE` como error técnico de persistencia en lugar de 400 `VALIDATION_ERROR` sobre `nombre`.
- **Impacto:** Bajo-medio. Defecto demostrado por documentación, no por IT (no se ejecutó contra DB). `DB_BASELINE_CONTRACT.md` no documenta longitudes.
- **Evidencia:** [AUDIT](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md) (LB-001B.4A, F-4A-1).
- **Resolución esperada:** 02-contratos decide el máximo (propuesta 50, a confirmar con el equipo DB); luego RED (151 → 51), ajuste de validadores/entidad/mensaje y documentación en `BACKEND_GOLDEN_PATH_CONTRACT.md`. No restaurar 5..100 (sin respaldo en DB).
- **Bloquea línea base:** no.
- **Estado:** **CLOSED (2026-09-24, LB-001B.4B) — backend aligned to frozen DB NVARCHAR(50).** Decisión humana: máx. 50. `Sesion.nombre` 1..50 en `CrearSesionRequestValidator`, `CrearSesionDomain`, `ActualizarSesionDomain` y `SesionConsultadaEntity`; contrato actualizado en `BACKEND_GOLDEN_PATH_CONTRACT.md`. Evidencia: [AUDIT 4B](../work-items/LB-001B.4-final-backend-contract-closure/AUDIT.md) (PASS, sin bloqueantes), [VALIDATION](../work-items/LB-001B.4-final-backend-contract-closure/VALIDATION.md) (970 tests, 0F/0E/0S). TD-034 sigue abierta (no bloqueante). **Work item relacionado:** [LB-001B.4](../work-items/LB-001B.4-final-backend-contract-closure/CLOSURE.md).

## TD-049

> **Estado vigente (2026-11-16): CERRADA.** `GET /api/v1/usuarios/perfil` está implementado (HU006): `UsuarioPerfilController` delega en `ConsultarPerfilInputPort` con el id del usuario autenticado y tiene prueba (`UsuarioPerfilControllerTest`); `PUT /perfil` y el alta genérica `POST /api/v1/usuarios` se retiraron (VAL ROL-05). Ya no responde 501. Lo que sigue más abajo es histórico.

- **Fecha / responsable:** 2026-09-24 / backend-team + equipo DB.
- **Descripción:** `GET/PUT /api/v1/usuarios/perfil` permanecen fuera del Golden Path y responden
  501 por capacidad pública no implementada/confirmada.
- **Impacto:** Funcional para la vertical de perfil; no afecta las 8 operaciones LB-001C.1.
- **Evidencia:** estado de entrada reportado en
  [ENTRY_EVIDENCE](../work-items/LB-001C-openapi-contract-first/ENTRY_EVIDENCE.md) y tests de
  `UsuarioController` dentro de `mvn verify`.
- **Resolución esperada:** contrato/consumer/DB propios antes de implementar o publicar en OpenAPI.
- **Bloquea línea base:** no para Golden Path.
- **Estado:** ABIERTA / OUT_OF_GOLDEN_PATH / NON_BLOCKING.

## TD-050

- **Fecha / responsable:** 2026-09-24 / backend-team + frontend.
- **Descripción:** MV-001 observó latencia de reconciliación realtime; HTTP recupera el estado y
  sigue siendo source of truth.
- **Impacto:** Experiencia de usuario/operación; no se reportó pérdida de consistencia.
- **Evidencia:** estado de entrada reportado en
  [ENTRY_EVIDENCE](../work-items/LB-001C-openapi-contract-first/ENTRY_EVIDENCE.md). No hay métrica o
  traza sanitizada adjunta en este checkout.
- **Resolución esperada:** medir percentiles y separar latencia SSE, reconexión y recarga HTTP en
  un work item de observabilidad/realtime; no introducir broker/cache por suposición.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-051

- **Fecha / responsable:** 2026-09-26 / backend-team + seguridad.
- **Clasificación:** `SECURITY_FINDING`, prioridad alta.
- **Descripción:** webhook credential currently has an unsafe functional default.
- **Impacto:** una configuración omitida puede dejar habilitada una credencial conocida por el código/configuración distribuida.
- **Evidencia:** `SecurityConfig` y configuración runtime; se registra archivo/tipo, nunca el valor.
- **Motivo para no resolver ahora:** LB-001D.1 es documentation/governance only; producción/tests/config están prohibidos.
- **Resolución esperada:** LB-001D.2 elimina el default funcional, exige configuración fail-fast/disabled segura y agrega pruebas negativas sin debilitar la autenticación del webhook.
- **Bloquea línea base:** no (resuelta).
- **Estado:** RESUELTA en LB-001D.2 (2026-09-26): `@Value("${app.security.azure-events.webhook-token:}")` y `webhook-token: ${AZURE_EVENTGRID_WEBHOOK_TOKEN:}` sin valor por defecto; credencial vacía/ausente/en blanco → 401 fail-closed. Evidencia: `AzureWebhookUnconfiguredSecurityChainTest`, `AzureEventGridAuthFilterTest`. **Work item:** [LB-001D.2](../work-items/LB-001D-governance-hardening/LB-001D.2-REPORT.md).

## TD-052

- **Fecha / responsable:** 2026-09-26 / backend-team + seguridad.
- **Clasificación:** `SECURITY_FINDING`, prioridad alta.
- **Descripción:** credential may be accepted through URL query parameter.
- **Impacto:** una credencial en URL puede quedar expuesta en historial, proxies, access logs o evidencia.
- **Evidencia:** `AzureEventGridAuthFilter`; no se registra el valor de ninguna credencial.
- **Motivo para no resolver ahora:** LB-001D.1 no modifica código ni tests.
- **Resolución esperada:** LB-001D.2 acepta la credencial únicamente por el header operacional aprobado, agrega negativos de query y verifica logs/evidencia sanitizados.
- **Bloquea línea base:** no (resuelta).
- **Estado:** RESUELTA en LB-001D.2 (2026-09-26): se eliminó `request.getParameter("token")`; la credencial se acepta solo por `aeg-sas-token`, con comparación de digests SHA-256 vía `MessageDigest.isEqual`. Evidencia: query-only (`token`, `access_token`, `key`) → 401 en filtro y en cadena real. **Work item:** [LB-001D.2](../work-items/LB-001D-governance-hardening/LB-001D.2-REPORT.md).

## TD-053

- **Fecha / responsable:** 2026-09-26 / backend-team + testing.
- **Clasificación:** `TEST_CLASSIFICATION_DEBT`.
- **Descripción:** `AzureCloudIntegrationE2ETest` consume Azure real, pero su nombre `*Test` lo sitúa en la suite normal en lugar de un perfil Cloud Integration explícito.
- **Impacto:** `mvn verify` puede depender de red, identidad y recursos Azure; un fallo ambiental se mezcla con unit/component y el build deja de ser reproducible.
- **Evidencia:** clase de test y convenciones Surefire/Failsafe del `pom.xml`.
- **Motivo para no resolver ahora:** renombrar/reconfigurar tests o POM está prohibido en LB-001D.1.
- **Resolución esperada:** LB-001D.2 aísla Azure real mediante perfil/comando explícito, mantiene unit/component sin cloud y registra ambiente/evidencia sanitizada.
- **Bloquea línea base:** no (resuelta).
- **Estado:** RESUELTA en LB-001D.2 (2026-09-26) por clasificación/perfil, sin skips: `AzureCloudIntegrationE2ETest` → `AzureCloudIntegrationIT` (Failsafe, solo lectura, endpoints por `AZURE_KEYVAULT_ENDPOINT`/`AZURE_APPCONFIG_ENDPOINT`), excluido de `-Pintegration` y ejecutado únicamente con `-Pazure-integration`; `mvn verify` no lo ejecuta (`CloudIntegrationClassificationTest` lo protege). Esto no cierra MV-003. **Work item:** [LB-001D.2](../work-items/LB-001D-governance-hardening/LB-001D.2-REPORT.md).

## TD-054

- **Fecha / responsable:** 2026-09-26 / backend-team + contratos/realtime.
- **Clasificación:** `DECISION_REQUIRED`.
- **Descripción:** el procesamiento Azure publica hoy algunos `RealtimeEvent`, mientras el SSE académico entrega solo eventos con `payload.grupo`; cambios de catálogo/configuración no necesariamente tienen ese scope.
- **Impacto:** intención y consumidor del evento no están definidos; podría ser invalidación interna, señal distribuida o evento cliente.
- **Evidencia:** `ProcesarEventoAzureUseCaseImpl`, `LocalSseRealtimeStreamGateway`, [DR-AZ-001](../work-items/LB-001D-governance-hardening/LB-001D.1-DECISIONS.md#dr-az-001).
- **Motivo para no resolver ahora:** la tarea prohíbe decidir por intuición o cambiar realtime.
- **Resolución esperada:** decisión explícita A/B/C, contrato/consumidores y tests antes de cualquier cambio realtime.
- **Bloquea línea base:** no para LB-001D.1; sí para un cambio realtime relacionado.
- **Estado:** DECISION_REQUIRED. **Work item:** [LB-001D.1](../work-items/LB-001D-governance-hardening/LB-001D.1-PLAN.md).

## TD-055

> **Estado vigente (2026-11-16): CERRADA.** El provider `messageucolab` se ejecutó contra el componente real: [INT-002 ESTADO](../work-items/INT-002-complementos-seguridad-mensajes-parametros/ESTADO.md) (MessageUcoLab 0.2.0, aplicación `healthy` y consulta pública respondiendo) e [INT-003 ESTADO](../work-items/INT-003-eventos-complementos/ESTADO.md) (0.3.0); la certificación en pantalla de HU169 (2026-11-13) está descrita en TD-092 (la edición del mensaje se reflejó en lo que responde el backend). Lo que sigue más abajo es histórico.

- **Fecha / responsable:** 2026-11-02 / backend-team + infra.
- **Clasificación:** `NON_BLOCKING`.
- **Descripción:** el switch `app.adapters.message-catalog.provider=messageucolab` está probado con `MessageReader` simulado y `ApplicationContextRunner`, pero no contra el componente real levantado (requiere Doppler, registro en Security Baseline y carga de mensajes).
- **Impacto:** un mock no certifica el provider externo; comportamiento real de `{}`, 409 y traducción sin evidencia.
- **Evidencia:** [MSG-001 VALIDATION](../work-items/backend/MSG-001-messageucolab-catalog-switch/VALIDATION.md).
- **Resolución esperada:** ejecutar los pasos de [MESSAGEUCOLAB_INTEGRATION §3](../governance/MESSAGEUCOLAB_INTEGRATION.md) y registrar resultados.
- **Bloquea línea base:** no. **Estado:** ABIERTA. **Work item:** MSG-001.

## TD-056

- **Fecha / responsable:** 2026-11-02 / backend-team + equipo de mensajería.
- **Clasificación:** `DECISION_REQUIRED`.
- **Descripción:** MessageUcoLab limita el código a 10 caracteres tras `MSG_` y el contenido a 100; 54 de 150 códigos y 9 mensajes de Asistencias exceden esos límites.
- **Impacto:** esos mensajes solo se resuelven vía alias o contingencia Azure; la migración total a MessageUcoLab no es viable sin cambio del componente o de los códigos canónicos (contrato público).
- **Evidencia:** análisis de `GestioAsistenciaDB/schema/seed/04_mensaje.sql`; hallazgos H-01/H-02 en [FINDINGS_FOR_MESSAGES_TEAM](../work-items/backend/MSG-001-messageucolab-catalog-switch/FINDINGS_FOR_MESSAGES_TEAM.md).
- **Resolución esperada:** respuesta del equipo de mensajería (ampliar límites) o decisión contractual sobre alias.
- **Bloquea línea base:** no. **Estado:** DECISION_REQUIRED. **Work item:** MSG-001.

## TD-CULM001-A-01

- **Descripción:** Dos fuentes del código `I` (matrícula retirada): el parámetro `MATRICULA/ESTADO_RETIRADA`, que lee la reactivación de matrícula (DEC-009), y el literal `'I'` en `usp_retirar_estudiante_grupo.sql:41`.
- **Impacto:** Medio-bajo; si el parámetro cambia, el retiro y la reactivación divergen.
- **Evidencia:** contrato CULM-001 paquete A, riesgo R-12 y objeción N5 de REVIEW-1.
- **Motivo:** No se toca `usp_retirar_estudiante_grupo` (HU051 certificada) fuera del alcance del paquete A.
- **Resolución esperada:** que el retiro lea el mismo parámetro que la reactivación.
- **Bloquea línea base:** no. **Estado:** ABIERTA. **Work item:** CULM-001 A.

## TD-CULM001-A-02

- **Descripción:** El texto local `MENSAJE_MATRICULA_DUPLICADA_DOCENTE` del frontend (`attendance-control.component.ts`) muestra el 409 `ERR_MATRICULA_DUPLICADA` sin pasar por el catálogo.
- **Impacto:** Bajo; contradice SSOT de mensajes (el texto debe venir del catálogo).
- **Evidencia:** contrato CULM-001 paquete A, A-C5 y riesgo R-9.
- **Resolución esperada:** pasar a `messages:user:ERR_MATRICULA_DUPLICADA` con un texto para el docente.
- **Bloquea línea base:** no. **Estado:** ABIERTA. **Work item:** CULM-001 A.

## TD-CULM001-A-03

- **Descripción:** El solape de sesiones responde 400 `VALIDATION_ERROR` con `SES_017`, pero la tabla §G de `BACKEND_GOLDEN_PATH_CONTRACT.md` (orígenes de `VALIDATION_ERROR`) no lo enumera.
- **Impacto:** Bajo; documentación del contrato incompleta.
- **Evidencia:** contrato CULM-001 paquete A, §8.1 (nota para la próxima revisión formal).
- **Resolución esperada:** añadir `SES_017` a la tabla §G en la próxima revisión formal del contrato (WORM: requiere nuevo hash).
- **Bloquea línea base:** no. **Estado:** ABIERTA. **Work item:** CULM-001 A.

## TD-059

- **Fecha / responsable:** 2026-10-21 / fullstack-team (HU035-HU036, E2E y triage de `-Pintegration`).
- **Clasificación:** `DB_ENGINE_PLAN_DEFECT`. **Prioridad:** ALTA.
- **Descripción:** Cualquier `DELETE` sobre `dbo.SolicitudRevisionAsistencia` fallaba con `Msg 8624` (Internal Query Processor Error) por conflicto del optimizador entre la clave foránea `FK_ArchivoSoporte_SolicitudRevisionAsistencia` y el índice único filtrado `UX_ArchivoSoporte_Solicitud` (`WHERE solicitudRevisionAsistencia IS NOT NULL`) de LB-004D.
- **Impacto:** Imposibilidad de eliminar reclamos desde SP, fixtures o scripts de limpieza.
- **Resolución en CULM-001 D.2:** En el Paquete D (D.2) se reemplazó el índice único filtrado por el índice no único y no filtrado `IX_ArchivoSoporte_Solicitud` permitiendo 1:N soportes.
- **Estado:** **CLOSED (2026-11-08, CULM-001 D.2).** La causa (Msg 8624 por FK + índice filtrado) quedó reclasificada y cerrada junto con TD-060/TD-061 al reemplazar el índice filtrado por `IX_ArchivoSoporte_Solicitud` (DEC-042, DEC-052). La comprobación formal D2-14 (`BEGIN TRAN; DELETE ...; ROLLBACK;` con FK habilitada) forma parte de la suite de BD del gate del lote (816 TEST_PASS, 0 fallos); su traza individual queda pendiente de verificar en Fase 3. **Work item:** CULM-001 Paquete D (D.2).

## TD-060

- **Fecha / responsable:** 2026-10-21 / fullstack-team (HU035-HU036, análisis AS-IS).
- **Clasificación:** `DATA_LOSS_CONTRACT_GAP`. **Prioridad:** MEDIA.
- **Descripción:** `dbo.usp_radicar_solicitud_revision_asistencia_v2` recibía `@categoria` pero no la persistía al no existir columna en `SolicitudRevisionAsistencia`.
- **Impacto:** Pérdida de la causal/categoría normativa (médica, laboral, etc.) elegida por el estudiante al radicar.
- **Resolución en CULM-001 D.2:** Se agregó la clave foránea `idCategoriaJustificacion` en `SolicitudRevisionAsistencia`, persistida por `usp_internal_radicar_solicitud_revision` y expuesta en vistas y DTOs (HU014/HU015).
- **Estado:** **CLOSED (2026-11-07, CULM-001 D.2)**. **Work item:** CULM-001 Paquete D (D.2).

## TD-061

- **Fecha / responsable:** 2026-10-21 / fullstack-team.
- **Clasificación:** `HARDCODED_STATE_LITERAL`. **Prioridad:** BAJA.
- **Descripción:** `usp_consultar_solicitudes_revision_docente`, `usp_consultar_archivo_soporte_autorizado` y `usp_radicar_solicitud_revision_asistencia_v2` comparaban contra los literales de cadena `'ATTACHED'` y `'DRAFT'`.
- **Impacto:** Vulneración de la regla arquitectural UCO "Cero Datos Quemados".
- **Resolución en CULM-001 D.2:** Los SPs se refactorizaron para resolver los estados desde el catálogo de parámetros (`ARCHIVO.ESTADO_ADJUNTO`, `ARCHIVO.ESTADO_BORRADOR`).
- **Estado:** **CLOSED (2026-11-07, CULM-001 D.2)**. **Work item:** CULM-001 Paquete D (D.2).

## TD-CULM001-D-01

- **Fecha / responsable:** 2026-11-07 / backend-team & ops (CULM-001 Paquete D §12).
- **Clasificación:** `CONFIG_SYNC_DUAL_SOURCE`. **Prioridad:** MEDIA.
- **Descripción:** Cuando el catálogo de parámetros del backend opera con el proveedor `azure` (Azure App Configuration) en lugar de `sqlserver`, la mutación `PUT /admin/parametros/{id}` actualiza la base de datos SQL Server (`CatalogoParametro`), pero no propaga automáticamente el cambio a Azure App Configuration.
- **Impacto:** Posible inconsistencia entre el valor en BD y el valor en Azure App Configuration si no se ejecuta sincronización externa.
- **Resolución esperada:** Implementar un publicador o proceso que propague el parámetro actualizado a Azure App Configuration vía SDK/CLI cuando el provider activo sea `azure`.
- **Bloquea línea base:** No. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001 D.3 (§12).

## TD-CULM001-D-02

- **Fecha / responsable:** 2026-11-07 / backend-team (CULM-001 Paquete D §12).
- **Clasificación:** `CACHE_COHERENCE_MULTI_INSTANCE`. **Prioridad:** MEDIA.
- **Descripción:** La invalidación de caché ante `PUT /admin/parametros/{id}` (`ParameterCatalogPort.invalidate()`) se ejecuta en la memoria local de la instancia Spring Boot que procesa la petición HTTP. En un despliegue multi-instancia (clúster/escalado horizontal), las demás réplicas retendrán el valor anterior hasta la expiración por TTL.
- **Impacto:** Inconsistencia temporal entre instancias ante cambios en caliente de parámetros.
- **Resolución esperada:** Integrar un canal distribuido de invalidación (Event Grid, Redis Pub/Sub o mensaje SSE/bus) para notificar a todas las réplicas activas.
- **Bloquea línea base:** No. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001 D.3 (§12).

## TD-CULM001-D-03

- **Fecha / responsable:** 2026-11-07 / architecture & database-team (CULM-001 Paquete D §12, [SUPUESTO-D-16]).
- **Clasificación:** `MULTI_TENANCY_SCOPE_GAP`. **Prioridad:** MEDIA.
- **Descripción:** `CatalogoParametro` y `AuditoriaEvento` no cuentan con columna `idInstitucion`: los parámetros de negocio y los registros de auditoría operan a nivel global de toda la instalación monoinstitucional. `usp_actualizar_parametro` y `usp_consultar_auditoria_eventos_paginado` validan defensivamente que exista exactamente una institución activa (`PRM_012` y `AUD_001`).
- **Impacto:** Si la universidad decide activar un despliegue multi-institucional compartido en la misma base de datos, los parámetros y la auditoría requerirán aislamiento por institución.
- **Resolución esperada:** Añadir `idInstitucion` a `CatalogoParametro` y `AuditoriaEvento` con filtrado estricto por ámbito institucional del administrador.
- **Bloquea línea base:** No para despliegue monoinstitucional UCO. **Estado:** DECISION_REQUIRED. **Work item:** CULM-001 D.3/D.6 (§12, [SUPUESTO-D-16]).

## TD-CULM001-D-04

- **Fecha / responsable:** 2026-11-07 / backend-team & infra (CULM-001 Paquete D §12).
- **Clasificación:** `STORAGE_HOUSEKEEPING`. **Prioridad:** BAJA.
- **Descripción:** Cuando un estudiante sube un archivo soporte mediante `POST /api/v1/archivos/subir`, el archivo se almacena en MinIO/S3 y se registra en `ArchivoSoporte` con estado `DRAFT`. Si el estudiante no culmina la radicación del reclamo (`POST /asistencias/revisiones`), el soporte queda en estado borrador permanentemente (soporte huérfano).
- **Impacto:** Acumulación progresiva de archivos no vinculados en el bucket MinIO y filas `DRAFT` en BD.
- **Resolución esperada:** Implementar un job batch programado que identifique soportes en estado `DRAFT` con más de X días de antigüedad (definido por parámetro), elimine el objeto en MinIO y marque la fila como eliminada/expirada.
- **Bloquea línea base:** No. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001 D.2 (§12).

## TD-CULM001-D-05

- **Fecha / responsable:** 2026-11-07 / backend-team (CULM-001 Paquete D §12).
- **Clasificación:** `API_CONTRACT_PAGINATION_CONSISTENCY`. **Prioridad:** BAJA.
- **Descripción:** El endpoint `GET /api/v1/estudiante/materias/{materiaId}/sesiones` consulta el SP `usp_consultar_sesiones_materia_estudiante` con límite `PAGINACION/TAMANO_MAXIMO` (100). En la práctica académica ninguna materia supera 100 sesiones por semestre; sin embargo, si una materia atípica superara ese límite, el backend actualmente registra un log WARN con `correlationId` y devuelve únicamente la primera página para conservar el sobre no paginado histórico consumido por el frontend.
- **Impacto:** Sesiones más allá de la 100 no serían visibles si una materia excede dicho umbral.
- **Resolución esperada:** Evolucionar el contrato del endpoint y frontend hacia `ApiPageResponse` con controles de paginación explícitos si se requiere soportar materias con más de 100 sesiones.
- **Bloquea línea base:** No. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001 D.1 (§12, §2.3).

## TD-062 a TD-065 — Paquete C.1 (cancelación por inasistencia, HU026C)

- **TD-062 — Avisos de alertas sin reintento previo al outbox.** `AvisoAlertasInasistenciaService` y `AvisoRevisionCancelacionService` encolan avisos de mejor esfuerzo; si el outbox falla el aviso se pierde (queda la alerta en BD y la página de alertas). **Prioridad:** BAJA. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001 C.1.
- **TD-063 — SSE `local-sse` de una JVM con audiencias por instantánea.** Las audiencias del canal de grupo se resuelven una vez al suscribirse; un cambio de ámbito (p. ej. matrícula a `CI`) se aplica en la siguiente suscripción. **Prioridad:** BAJA. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001 C.1 (§3.6).
- **TD-064 — Vista de revisiones del administrador diferida.** C.1 no expone las revisiones al administrador (DEC-022 §2). **Prioridad:** BAJA. **Estado:** ABIERTA / NON_BLOCKING.
- **TD-065 — Revisión sin resolutor posible y marca de agua con solape.** Si el programa no tiene coordinador activo y su facultad no tiene decano activo, la propuesta se rechaza con `RCN_013` y el job audita `REVISION_CANCELACION_SIN_RESOLUTOR` una sola vez por cambio de huella; la marca de agua del job re-evalúa de forma idempotente hasta `SOLAPE_MARCA_SEGUNDOS` (120 s). **Prioridad:** BAJA. **Estado:** ABIERTA / NON_BLOCKING.

## TD-066 a TD-084 — Deudas de la certificación de CULM-001 (registradas 2026-11-08)

Origen: desviaciones de DEC-046 y DEC-055..DEC-060, `ESTADO.md` y hallazgos de la Fase 3. Ninguna bloquea la línea base.

## TD-066

- **Título:** Prueba de la migración 19 sin comparación byte a byte del SP restaurado.
- **Origen:** DEC-059 (C.1).
- **Descripción:** La prueba de la migración 19 solo verifica la ausencia del motor y de la marca en el SP restaurado; no compara su texto con el original.
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Comparar el SP restaurado con el texto de origen (hash) en la prueba de migración.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-067

- **Título:** Pruebas C-DB-50 y C-DB-46 sin ejecución en paralelo real.
- **Origen:** DEC-059 (C.1).
- **Descripción:** Las pruebas de concurrencia del motor de alertas y de la decisión de revisión no se ejecutaron con sesiones paralelas reales.
- **Impacto:** Medio.
- **Resolución esperada / propuesta:** Añadir un arnés PowerShell con dos o más sesiones SQL concurrentes (patrón de `test_lb004d_concurrency.ps1`).
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-068

- **Título:** C-DB-62 (despliegue limpio) cubierta solo por el gate del lote.
- **Origen:** DEC-059, DEC-060.
- **Descripción:** El caso no tiene prueba propia; lo cubre el gate de BD con datos canónicos (migraciones 13–28 y luego `deploy_schema`).
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Convertir el orden del gate en una prueba automatizada de despliegue desde cero.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-069

- **Título:** `CierreMasivoRcn012IT` pendiente de ejecución o ajuste.
- **Origen:** DEC-059 (C.1).
- **Descripción:** La prueba de integración del bloqueo `RCN_012` del cierre masivo (HU174) no está certificada; depende de la BD de integración y del perfil `-Pintegration` (línea base con fallos de integración sin analizar).
- **Impacto:** Medio.
- **Resolución esperada / propuesta:** Ejecutarla en la Fase 3 sobre BD canónica y corregir el código, no la prueba.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.
- **Revisada 2026-11-16: sigue vigente porque la prueba no existe.** No hay ninguna clase `CierreMasivoRcn012IT` en `src/test` del backend (solo `CierreMasivoRequestValidatorTest`; `RCN_012` aparece únicamente en `DbFailureClassifierMrmCancelacionTest`). La resolución es crearla y ejecutarla contra la BD canónica. Su alcance se solapa con TD-097.

## TD-070

- **Título:** E2E PKCE de C (`test_culm001_c.ps1`) sin ejecutar.
- **Origen:** DEC-059 (C.1).
- **Descripción:** El script E2E de C en Infra usa el flujo PKCE (DEC-008); pendiente de verificar en Fase 3 contra el backend de integración.
- **Impacto:** Medio.
- **Resolución esperada / propuesta:** Ejecutarlo en la Fase 3 e incorporarlo a `test_all_hus.ps1`.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.
- **Revisada 2026-11-16: sigue vigente.** El script `test_culm001_c.ps1` ya no existe en Infra. La suite vigente es `scripts/tests/test_all_hus.ps1`, que usa PKCE (`Get-SpaToken.ps1`, Security Baseline); no se confirmó que cubra los escenarios del paquete C ni se ejecutó contra un backend en esta revisión.

## TD-071

- **Título:** Manifiesto post-freeze de C sin modo en `freeze-manifest.ps1` (`DB_UTC_D06`).
- **Origen:** DEC-059; PRs #105 (BD) y #29 (Infra).
- **Descripción:** El script no tiene modo para generar el manifiesto post-freeze de C; las PR #105 y #29 (Antigravity) siguen abiertas, la de BD con conflicto, y requieren la confirmación de excepción del propietario.
- **Impacto:** Medio.
- **Resolución esperada / propuesta:** Re-integrar #105/#29 sobre `integracion/CULM-001`, añadir el modo y regenerar las líneas afectadas con registro en DECISIONES.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-072

- **Título:** `--prune` del PDP pendiente (concesiones sobrantes).
- **Origen:** DEC-046.
- **Descripción:** La revocación de concesiones obsoletas solo ocurre con `provision_asistencias.py pdp --prune`, no ejecutado sin autorización del responsable.
- **Impacto:** Medio (permisos mayores a los necesarios).
- **Resolución esperada / propuesta:** Autorizar y ejecutar `--prune`; después `verify` y `verify-decisions`.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.
- **Medición del 2026-11-17 (laboratorio, tras aprovisionar el PDP de forma incremental: 0 recursos y 0 permisos faltantes):** 128 concesiones sobrantes (ADMINISTRADOR 86, DECANO 7, COORDINADOR 19, DOCENTE 9, ESTUDIANTE 7; la medición anterior, del 2026-11-07, era ADMINISTRADOR 76, COORDINADOR 10, ESTUDIANTE 5, DOCENTE 4, DECANO 2). Sigue sin ejecutarse `--prune`: no se autorizó. Medida en el aprovisionamiento del cierre; esta revisión documental no la repitió.

## TD-073

- **Título:** 48 recursos huérfanos en el PDP (medición del 2026-11-17; antes 32).
- **Origen:** DEC-046; ESTADO.
- **Descripción:** Rutas retiradas (solicitudes de ingreso, `qr-token`, catálogos admin; `POST /asistencias` por D.7 y, desde CIERRE-W1B, las cinco rutas de `/api/v1/docentes/**`) siguen como recursos; `verify` queda `clean=false`. Medición del 2026-11-17: 48 recursos huérfanos, incluidos los de las rutas `/docentes` retiradas; sigue sin `--prune` (TD-072).
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Se resuelve con el mismo `--prune` de TD-072.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-074

- **Título:** Drift de dos SP congelados (`usp_generar_sesiones_grupo`, `usp_registrar_asistencias_sesion`).
- **Origen:** Línea base (Fase 0).
- **Descripción:** `verify-contracts.ps1` reporta `DB_OBJ_MISMATCH` entre `DB_DEVELOP_FREEZE_MANIFEST.sha256` y la BD de `develop` para ambos SP; conocido desde la línea base.
- **Impacto:** Medio (gate de contratos no totalmente en verde).
- **Resolución esperada / propuesta:** Regenerar las entradas con registro formal (relacionado con TD-071) o restaurar el texto congelado.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-075

- **Título:** Presupuesto del bundle frontend excedido (aviso de ~3,2 kB sobre 500 kB en los builds del 2026-11-16; antes +7,6 kB).
- **Origen:** Gate de frontend.
- **Descripción:** El build de producción supera el presupuesto del bundle en 7,6 kB tras los paquetes de CULM-001.
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Dividir módulos con carga diferida o subir el presupuesto con decisión registrada.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.
- **Revisada 2026-11-16: sigue vigente porque no se pudo medir.** Los presupuestos de `angular.json` (configuración `production`) son 500 kB de aviso y 1 MB de error para `initial`; no se compiló el frontend en esta revisión (solo lectura), así que no se confirma si el exceso de 7,6 kB persiste ni contra qué umbral se midió.
- **Revisada 2026-11-17: sigue abierta.** `angular.json` conserva `initial` con `maximumWarning` 500 kB y `maximumError` 1 MB (líneas 49-54). Esta revisión no compiló el frontend; la cifra de ~3,2 kB sobre los 500 kB es el aviso que reportaron los builds de producción del 2026-11-16 de los paquetes del cierre (no se midió aquí). Es un aviso, no un error.

## TD-076

- **Título:** `horasDictadas` del consolidado sin multiplicar por activos.
- **Origen:** DEC-056 (D.8).
- **Descripción:** `horasDictadas` son las horas del grupo por estudiante; los porcentajes usan `D = horas × activos`. La columna no es la suma institucional.
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Aclarar la semántica en el contrato o exponer la suma real.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-077

- **Título:** `codigo_programa` y `codigo_facultad` del CSV resueltos por nombre.
- **Origen:** DEC-058 (D.5).
- **Descripción:** `Programa` y `Facultad` no tienen columna `codigo`; la carga masiva resuelve por nombre exacto dentro del ámbito del ejecutor.
- **Impacto:** Medio (fragilidad ante homónimos).
- **Resolución esperada / propuesta:** Decidir si se añade `codigo` al modelo (semillas y pantallas) y migrar la plantilla CSV.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-078

- **Título:** `details[]` en inglés `{field, code, message}`.
- **Origen:** DEC-057 (D.9-a).
- **Descripción:** El golden path WORM fija `details[]` con claves en inglés, distinto del idioma del resto de mensajes.
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Revisarlo en una próxima versión formal del golden path con nuevo hash.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-079

- **Título:** Bloque '2 tomas = 1 toma' de `test_culm001_b2_horas` diferido.
- **Origen:** DEC-056.
- **Descripción:** El caso queda diferido por §9.2 del contrato de B.
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Reactivarlo cuando se defina el criterio de tomas equivalentes.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-080

- **Título:** Resultsets de tres SP excluidos del cierre canónico.
- **Origen:** DEC-055, DEC-060.
- **Descripción:** `usp_consultar_cambios_parametro_paginado`, `usp_consultar_parametros_paginado` y `usp_validar_carga_masiva_usuarios` están en las excepciones de `PUBLIC_CANONICAL_RESULTSET` (error 11520 de `sp_describe_first_result_set`).
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Reescribir los SP para admitir descripción de metadatos o fijar su contrato por otra vía.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-081

- **Título:** Orden de despliegue de BD: migraciones antes de `deploy_schema`.
- **Origen:** DEC-060.
- **Descripción:** Algunas migraciones re-crean SP con el texto de su época; con otro orden se pisan objetos de C.1 (SUPUESTO-C-15). La migración 24 requiere `:r $(MIGDIR)`.
- **Impacto:** Medio.
- **Resolución esperada / propuesta:** Documentarlo en `infra.ps1 db-deploy` o hacerlo cumplir en el script.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-082

- **Título:** Detalle `esParcial` por toma sin endpoint.
- **Origen:** ESTADO (B.2).
- **Descripción:** La sábana del docente no puede mostrar `esParcial` por toma: ningún endpoint lo entrega.
- **Impacto:** Bajo.
- **Resolución esperada / propuesta:** Exponerlo en el resumen por grupo o en un detalle por toma.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-083

- **Título:** HU042 por SSE y campana de notificaciones diferidas (C.2).
- **Origen:** DEC-043.
- **Descripción:** `SOLICITUD_REVISION_RESUELTA` (F-TRX-005) y la campana del frontend no se entregaron en C.1.
- **Impacto:** Medio.
- **Resolución esperada / propuesta:** Implementar C.2 (el SSE por ámbito ya existe desde C.1).
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-084

> **Estado vigente (2026-11-16): CERRADA — RESUELTA POR DECISIÓN.** El responsable decidió mantener el access token Bearer solo en memoria con Authorization Code + PKCE (modo `baseline`); `CONSTITUTION.md` 4.04.1 ya admite el "almacenamiento protegido en memoria" y se enmendó 4.04.2 (cookies y CSRF aplican cuando la sesión se gobierne por cookies). `AGENTS.md` 3.3.4 se corrigió en consecuencia. La migración a cookie HttpOnly se difiere a producción (TD-110).
>
> **Corrección sobre la CSP:** el backend sí envía cabeceras de seguridad y CSP (`SecurityHttpHeaders`: `Content-Security-Policy` con `default-src 'none'` para la API, `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `Referrer-Policy`, `Permissions-Policy`; HSTS solo detrás de HTTPS) y el nginx del frontend genera su CSP en `csp.conf` (`docker-entrypoint.d/40-env-js.sh`). Lo que sigue más abajo es histórico.

- **Título:** Regla escrita de seguridad web (cookies HttpOnly y CSRF) contradice la implementación Bearer.
- **Origen:** F-TRX-015.
- **Descripción:** `AGENTS.md` 3.3.4 exige cookies HttpOnly, `withCredentials` y `X-XSRF-TOKEN`; el código usa Bearer en memoria y `SecurityConfig` no define CSP.
- **Impacto:** Bajo (decisión defendible).
- **Resolución esperada / propuesta:** Decidir: ajustar `AGENTS.md` o migrar el esquema de sesión; evaluar CSP.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001.

## TD-085

- **Título:** Código aleatorio de sesión en `usp_generar_sesiones_grupo` colisiona con `UX_Sesion_Grupo_Codigo` (CI de BD intermitente).
- **Origen:** CI de la PR #118 de BD (revisión 2, 2026-11-10): `Msg 3915 Cannot use the ROLLBACK statement within an INSERT-EXEC statement` en `usp_generar_sesiones_grupo` línea 339, dentro de `CULM001_B1_FES_08C` (generación v2 de 730 sesiones), con la suite abortada después (186 casos sin ejecutar).
- **Descripción:** El generador congelado v1 asigna a cada sesión `codigo = UPPER(LEFT(REPLACE(NEWID(), '-', ''), 6))` (6 hexadecimales, 16,7 M valores) y `UX_Sesion_Grupo_Codigo` exige unicidad por grupo. Con 730 sesiones por grupo la probabilidad de colisión es ≈ 1,6 % por grupo (paradoja del cumpleaños); la suite genera tres grupos así, ≈ 5 % de fallo por ejecución de la CI. Reproducido en local: 2 de 150 ejecuciones directas de la v1 devuelven `2601 Cannot insert duplicate key row in object 'dbo.Sesion' with unique index 'UX_Sesion_Grupo_Codigo'`. Como `usp_generar_sesiones_grupo_v2` invoca a la v1 con `INSERT ... EXEC`, el `ROLLBACK` del CATCH de la v1 se convierte en el 3915 que enmascara la causa, y con `sqlcmd -b` la suite se detiene.
- **Impacto:** Medio para la CI (falsos negativos intermitentes, reintento manual); bajo en producción (un grupo real rara vez supera 100 sesiones: ≈ 0,03 %), pero una generación fallida deja la tupla `SYS_001` sin filas.
- **Resolución esperada / propuesta:** Sustituir la v1 congelada mediante supersesión autorizada en un manifiesto post-freeze (`scripts/freeze-manifest.ps1`, mecanismo `SUPERSEDES`) con un código determinista por grupo (p. ej. derivado de `numero`) o un reintento acotado ante colisión; actualizar `test_golden_path_immutability.sql` y el contrato B1 (§2.7.6) que fijan su texto. No se corrige dentro de la revisión 2 porque exige cambio de contrato WORM.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** CULM-001 (revisión 2).

## TD-086

- **Título:** Security Baseline 0.1.13: el entrypoint de la imagen de Keycloak fija el Admin API en `127.0.0.1:8080`; el laboratorio endurecido necesita un relevo de puerto.
- **Origen:** INT-002 (2026-11-11), actualización 0.1.9 → 0.1.13 para habilitar las identidades de servicio (autenticación entre aplicaciones).
- **Descripción:** La 0.1.11 anunciada por el equipo de seguridad no puede crear identidades de servicio sobre un realm persistido (`POST /applications/{id}/service-identities` → 500; el PDP recibe 401 de Keycloak porque falta el cliente `security-pdp-provisioner`). La 0.1.13 migra el realm al arrancar, pero su `security-baseline-entrypoint.sh` espera `</dev/tcp/127.0.0.1/8080` y usa `kcadm --server http://127.0.0.1:8080`; con `KC_HTTP_PORT=19090` (puerto oficial del laboratorio) aborta con `Keycloak no abrió el puerto de administración a tiempo`. El compose endurecido del backend deja Keycloak en el 8080 interno y agrega `keycloak-relay` (`alpine/socat`, `network_mode: service:keycloak`, 19090 → 8080) para que PDP/PEP y el host sigan usando `keycloak.localhost:19090`.
- **Impacto:** Bajo (un contenedor auxiliar más; sin cambio de contrato). Riesgo: cada versión nueva del entrypoint puede cambiar la suposición del puerto.
- **Resolución esperada:** Pedir al equipo de seguridad que el entrypoint lea `KC_HTTP_PORT` (o acepte un `SECURITY_BASELINE_ADMIN_PORT`) y retirar el relevo.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** INT-002.

## TD-087

- **Título:** `provision_asistencias.py verify` falla en `develop` porque `extract_endpoints.py` exige rutas literales y HU177 usa constantes.
- **Origen:** INT-002 (2026-11-11), verificación de solo lectura del PDP tras actualizar Security Baseline.
- **Descripción:** `extract_endpoints.ExtractionError: RecuperacionClaveController.java: la ruta no es un literal de texto (SecurityPublicEndpoints.RECUPERACION_CLAVE_SOLICITUD)`. El inventario sin JVM no resuelve referencias a constantes, así que `verify`, `catalog` y `pdp` quedan inutilizables hasta corregirlo (la prueba Maven `AccessCatalogConsistencyTest` sí usa el mapeo real).
- **Impacto:** Medio para la operación del laboratorio (no se puede verificar deriva PDP ↔ catálogo desde la CLI).
- **Resolución esperada:** Que `extract_endpoints.py` resuelva constantes `static final String` del mismo árbol (`SecurityPublicEndpoints`) o que los controladores usen literales con el catálogo como única fuente.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** CERRADA. **Work item:** INT-002.
- **Cierre (2026-11-16):** el PR del backend #153 (`fix/extractor-constantes-ruta`) hace que `extract_endpoints.py` resuelva constantes de ruta. Sobre develop 8530bd54: suite `test_*.py` 66 de 66 OK y `provision_asistencias.py catalog` con 193 endpoints, 0 sin regla, 0 obsoletos (VAL-oleada7).

## TD-088

- **Título:** Catálogo de Parámetros 0.1.7 (componente del equipo de parámetros): plantilla de recursos vacía, `tipos-parametro` sin semilla y sin validación de referencias.
- **Origen:** INT-002 (2026-11-11), instalación y siembra del Catálogo en el laboratorio.
- **Descripción:** (1) `plantilla-resources.xlsx` entregada solo con encabezados: los recursos que exige el microfrontend se registraron por API a partir del OpenAPI del componente (104 recursos). (2) `GET /tipos-parametro` devuelve `[]` y no hay `POST`; `POST /parametros` exige `idTipoParametro` pero acepta un UUID inexistente (se usó `00000000-0000-0000-0000-000000000001`). (3) `POST /metadatos` rechaza el valor vacío (`RED.PROXIES_CONFIABLES` queda sin metadato y usa el valor por defecto del backend). (4) `GET /parametros` y `GET /metadatos-ambiente` paginan a 10 por defecto (`page`, `pageSize`). (5) El app registra en bucle `UnknownHostException: otel-collector` cuando la observabilidad del compose está apagada. (6) `GET /tokens/{id}/parametros` consulta mensajes en MessageUcoLab antes de responder: si Kong no responde se cuelga más de 30 s en vez de devolver los parámetros sin mensajes. (7) La lectura fría del token tarda entre 1 y 13 s (el backend subió su timeout a 10 s y sirve la caché vencida mientras refresca).
- **Impacto:** Bajo para AsistenciasUCO (el adaptador y el decorador DEC-018 lo absorben); los hallazgos son del otro equipo.
- **Resolución esperada:** Informar al equipo de parámetros: plantilla con los recursos reales, semilla de `tipos-parametro`, validación de referencias y valor vacío permitido o documentado, y que el endpoint de token no dependa de MessageUcoLab (o falle rápido y devuelva los parámetros) y reduzca la latencia en frío.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** INT-002.

## TD-089

- **Título:** Gateway Kong de MessageUcoLab (`api-gateway-kong`, puerto 8000) se degrada tras ~4 h y deja de aceptar conexiones nuevas desde contenedores.
- **Origen:** INT-002 (2026-11-12), diagnóstico de latencias >30 s en `GET /tokens/{id}/parametros` del Catálogo de Parámetros.
- **Descripción:** Con el contenedor limitado a 1,6 GiB de memoria, tras unas 4 h de ejecución Kong no acepta conexiones nuevas desde otros contenedores (el Catálogo, que consulta mensajes por Kong, se cuelga). `docker restart api-gateway-kong` lo recupera. La comprobación de Kong de `scripts/tests/test_catalogo_parametros.ps1` lo detecta (sin respuesta en 5 s).
- **Impacto:** Medio para el laboratorio: degrada Catálogo y mensajes sin error claro.
- **Resolución esperada:** Que el equipo de mensajes revise el consumo de memoria/conexiones de Kong (límites, keepalive, fugas) y añada un healthcheck que detecte la degradación.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** INT-002.

## TD-090

- **Título:** Endpoints y SP de administración propia de parámetros (`/api/v1/admin/parametros`, HU168) sin uso desde la UI tras montar el micro frontend del Catálogo.
- **Origen:** INT-002 (2026-11-12). Decisión del responsable: la administración de parámetros de AsistenciasUCO es únicamente `parametros-administration.js` del equipo de parámetros, montado en la administración del sistema (ADMINISTRADOR).
- **Descripción:** El frontend (rama `feat/INT-002-microfrontend-parametros`) retiró la lista de parámetros y `parametro-edicion-modal.component.ts` de `admin-system`; la pestaña Parámetros (en `/app/admin/sistema` y en `/app/admin/configuracion/parametros`, que reutiliza el mismo componente) monta ahora el micro frontend. Siguen vivos, sin consumidor de UI: `AdminParametroController` (`GET /api/v1/admin/parametros` paginado, `PUT /api/v1/admin/parametros/{id}` y su historial de cambios), sus casos de uso y los SP de consulta/actualización de `dbo.CatalogoParametro`, además de `AdminManagementService.cargarParametros/actualizarParametro` en el frontend. No se borraron a propósito: los SP/ufn siguen leyendo `dbo.CatalogoParametro` y con el proveedor `catalogoparametros` nada sincroniza el Catálogo externo hacia la BD (brecha anotada en INT-002 §2.3; la edición local responde 409 PRM_010).
- **Impacto:** Bajo (superficie de API sin uso; riesgo de que alguien edite la tabla local creyendo que es la fuente de verdad).
- **Resolución esperada:** Cuando exista la sincronización Catálogo → BD (webhook delgado con HMAC → backend invalida caché y actualiza la fila vía SP), retirar el `PUT` y el historial, dejar el `GET` solo si un reporte lo necesita, y borrar los métodos del servicio del frontend y sus pruebas.
- **Prioridad:** BAJA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** INT-002.

## TD-091

- **Título:** Micro frontend `parametros-administration.js` 1.0.0: refresco periódico por defecto (sondeo cada 60 s) y CORS de un solo origen en la API del Catálogo.
- **Origen:** INT-002 (2026-11-12), montaje del micro frontend en AsistenciasUCO (lectura del bundle servido en `http://localhost:4201/parametros-ui/`).
- **Descripción:** (1) `mount()` usa `refreshIntervalMs ?? 60000` y con un valor distinto de 0 programa un `setInterval` que llama `refresh()` mientras la pestaña está visible; acepta `0` (sin intervalo) o un valor entre 30000 y 86400000. El componente ya abre SSE (`{apiBaseUrl}/aplicaciones/{id}/administracion/events`, evento `catalogo-aplicacion`) y refresca al reconectar, así que el intervalo es sondeo redundante; AGENTS.md prohíbe el polling y AsistenciasUCO monta con `refreshIntervalMs: 0`. La guía §8 de liberación muestra `60000` como ejemplo. (2) La API del Catálogo (`FRONTEND_ALLOWED_ORIGINS`, por defecto solo `http://localhost:4201`) responde 403 de CORS a cualquier petición con `Origin: http://localhost:4200`, aunque llegue por proxy del mismo origen; el PDP sí admite 4200. El proxy de desarrollo de AsistenciasUCO quita la cabecera `Origin` en `/catalogo-parametros` (mismo arreglo que `/messageucolab`). (3) ~~Del lado de AsistenciasUCO, el nginx de producción del frontend no publicaba `/parametros-ui`, `/catalogo-parametros` ni `/messageucolab`~~ **Resuelto el 2026-11-12** (rama `feat/INT-002-microfrontend-parametros`): `nginx/templates/default.conf.template` reenvía las tres rutas a `MESSAGEUCOLAB_UPSTREAM`, `CATALOGO_PARAMETROS_UPSTREAM` y `CATALOGO_PARAMETROS_UI_UPSTREAM` (por defecto `host.docker.internal:8000/8081/4201`), quita `Origin` en las APIs y no acumula los eventos SSE; probado con `nginx:alpine` sobre el build de producción (configuración válida, módulo 200, API 401 sin sesión y sin 403 de CORS).
- **Impacto:** Bajo en el laboratorio; en un despliegue real los tres puntos impiden o degradan la administración de parámetros.
- **Resolución esperada:** Pedir al equipo de parámetros que el valor por defecto sea `0` (o que se retire el intervalo y se documenten los eventos SSE como mecanismo de actualización, idealmente con un webhook para consumidores backend) y que `FRONTEND_ALLOWED_ORIGINS` admita una lista de orígenes documentada. En AsistenciasUCO, agregar al nginx las ubicaciones con destino configurable (o publicar los micro frontends detrás del mismo gateway) antes del despliegue.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** INT-002.

## TD-092

- **Título:** MessageUcoLab: el micro frontend y el backend pueden apuntar a aplicaciones distintas; la contingencia `azure` sigue por defecto sin Azure en local.
- **Origen:** INT-002 (2026-11-13), certificación en pantalla de HU169.
- **Descripción:** (1) `message-administration.component` monta `minifront-mensajes` con `applicationName`/`environmentName` ("Asistencias UCO" / "Develop", de `env.js`) y el widget resuelve la aplicación con la sesión del usuario; el backend lee con ids fijos (`MESSAGEUCOLAB_APPLICATION_ID` y `MESSAGEUCOLAB_ENVIRONMENT_ID`). En el laboratorio había dos aplicaciones "Asistencias UCO": `uco-administrador` administraba `c05f384e…` (Develop `9732b9aa…`) y el `.env` del backend apuntaba a `086b3ff9…` (Develop `23054ff3…`). Editar un mensaje en la pantalla no cambiaba lo que respondía el backend, sin ningún error visible. Al apuntar el backend a `c05f384e…` la edición se reflejó (máximo 5 min por la caché del adaptador). Las dos aplicaciones tienen el catálogo viejo (unos 140 mensajes; faltan, por ejemplo, `MSG_TOM012`, `MSG_PRM010` y `MSG_RCN012`), frente a los 398 que genera el script de VAL-oleada3-mensajes. (2) `messageucolab.fallback` vale `azure` por defecto (`MESSAGEUCOLAB_FALLBACK`); desde SEC-12 `AZURE_APPCONFIG_ENDPOINT` no tiene valor por defecto, así que con `messageucolab` y sin Azure el backend no arranca (`app.providers.azure-appconfig.endpoint es obligatorio…`). En el laboratorio se usa `MESSAGEUCOLAB_FALLBACK=none`.
- **Impacto:** Medio: en un despliegue real, el administrador puede editar un catálogo que la aplicación no lee.
- **Resolución esperada:** (a) Dejar una sola aplicación "Asistencias UCO" en MessageUcoLab por ambiente, con el catálogo completo importado y el rol del administrador con acceso a ella. (b) Que el frontend monte el widget con los mismos ids del backend (el widget acepta ids en lugar de nombres) o, al menos, que el backend registre al arrancar el id y el nombre de la aplicación que lee. (c) En los perfiles `local` y `dev`, usar `none` como contingencia por defecto, como ya hace SEC-12 con el baúl y los catálogos.
- **Prioridad:** MEDIA. **Bloquea línea base:** no. **Estado:** ABIERTA / NON_BLOCKING. **Work item:** INT-002.

## TD-093

- **Título:** Unicidad de personas y roles en las altas: decano y coordinador reutilizan a otra persona, sin índices únicos ni bloqueos, y el segundo rol de una persona queda sin acceso en el PDP.
- **Origen:** Revisión de registros duplicados y usuarios con varios roles (2026-11-15), sobre `develop` de BD (migración 44) y del backend. Cada escenario se corrió en una transacción con `ROLLBACK` (`@@TRANCOUNT = 0` al final); los datos del laboratorio estaban limpios (0 correos o documentos repetidos, 71 usuarios con un rol cada uno).
- **Descripción:**
  1. **Decano y coordinador buscan a la persona solo por número o correo** (`usp_crear_decano_interno`, `usp_crear_coordinador_interno`: `SELECT TOP 1 ... WHERE correo = ... OR numeroIdentificacion = ...`). No comparan el tipo de documento, no detectan que documento y correo sean de personas distintas y no bloquean la lectura. El backend (`CrearDecanoUseCaseImpl`, `CrearCoordinadorUseCaseImpl`) frena por la API los casos con documento y correo de personas distintas (`ERR_UNICIDAD_DOCUMENTO`, `ERR_UNICIDAD_CORREO`, `ERR_IDENTIDAD_USUARIO_CONFLICTO`), pero no el siguiente.
  2. **Mismo número, distinto tipo (llega por la API):** alta de un decano nuevo con CE y el número de un estudiante existente con CC. El backend no encuentra a nadie con CE, el SP reutiliza al estudiante, lo hace decano y confirma; el control posterior del backend no encuentra a la persona por tipo y número y responde 500. Sin `@Transactional` ni compensación, el estudiante queda como decano y la persona nueva no existe.
  3. **Rol inactivo:** volver a crear un decano o coordinador desactivado responde "registrado exitosamente" y el rol sigue con `estado = 0`.
  4. **Coordinador repetido:** crear como coordinador a quien ya lo es responde "registrado exitosamente" (no crea fila doble); decano sí avisa con `DEC_020`.
  5. **Sin índices únicos:** solo hay claves primarias y los únicos de `IdentidadExterna`. No hay único en `Usuario.correo`, en `Usuario(idTipoIdentificacion, numeroIdentificacion)` ni en la columna `usuario` de `Docente`, `Decano`, `Coordinador`, `Estudiante` y `Administrador`. La unicidad depende de los SP, y solo `usp_admitir_estudiante` lee con `UPDLOCK, HOLDLOCK`: un doble envío o dos altas simultáneas pueden duplicar.
  6. **Segundo rol sin acceso:** tener varios roles es intencional (HU121-HU122 R5, ámbito como unión). La SPA une los roles y entra por el de mayor prioridad. `KeycloakIdentityProviderAdapter.crearCuenta` agrega el rol de cliente a la cuenta existente, pero con `SECURITY_BASELINE_PDP_PROFILE_SYNC_ENABLED=false` (valor por defecto) el perfil del PDP no cambia: la persona recibe 403 en el nuevo rol hasta reconciliar (`/identidad/cuentas/acceso/reconciliaciones`).
  7. **Docente (fuera de esta corrección por decisión del responsable):** `usp_vincular_docente_programa` rechaza documento o correo repetidos (`DOC_003`), pero también a una persona distinta con el mismo número y otro tipo, y no bloquea la lectura.
  8. Relacionado: el documento es `INT` (TD-006); 15 correos están guardados con mayúsculas (sin efecto en la unicidad por la collation `CI`).
- **Impacto:** Medio. El caso 2 deja datos incorrectos con una entrada válida desde la pantalla; el 5 es un riesgo de carrera; el 6 confunde las pruebas manuales con usuarios de varios roles.
- **Resolución esperada:**
  - BD: decano y coordinador al estilo de `usp_admitir_estudiante` (tipo y número, rechazo equivalente a `ADS_004` para personas distintas, `UPDLOCK, HOLDLOCK`), reactivar o avisar del rol inactivo, mensaje de "ya es coordinador", migración con índices únicos (correo, tipo y número, `usuario` en cada tabla de rol; los datos actuales ya cumplen) y pruebas en `test_suite.sql`.
  - Backend: que un fallo posterior al SP no deje cambios a medias (resolverlo en la BD es lo preferido).
  - Seguridad: activar la sincronización de perfiles en el laboratorio o incluir la reconciliación en el guion de pruebas manuales de usuarios con varios roles.
- **Prioridad:** MEDIA. **Bloquea línea base:** no; sí antes de abrir altas masivas o producción. **Estado:** ABIERTA.

## TD-094

- **Descripción:** (ID antiguo: TD-055 del registro del backend.) JDBC directo residual en `src/main` durante la migración JPA-only (45 archivos en la línea base JPA-00).
- **Impacto:** Medio (histórico).
- **Evidencia:** registro histórico del backend (TD-055, `DIRECT_JDBC_IN_SRC_MAIN = 0` tras LB-008 JPA-07, 2026-10-06). Comprobado el 2026-11-16: la búsqueda de `JdbcTemplate` y `NamedParameterJdbc` en `src/main` del backend no devuelve ningún archivo.
- **Resolución esperada:** ninguna pendiente.
- **Bloquea línea base:** no.
- **Estado:** **CERRADA (LB-008 JPA-07, 2026-10-06).** Consecuencia documental: ya no queda ningún adaptador JDBC; la frase "JDBC legacy en coexistencia temporal" es obsoleta.

## TD-095

- **Descripción:** (ID antiguo: TD-056 del registro del backend.) `usp_registrar_asistencia_estudiante_autonomo` no abría una transacción que cubriera `Asistencia` y `DetalleAsistencia`.
- **Impacto:** Medio (histórico).
- **Evidencia:** registro histórico del backend (TD-056): cerrada el 2026-10-07 por la alineación final de la BD, que garantiza la atomicidad de ambas escrituras.
- **Resolución esperada:** ninguna pendiente.
- **Bloquea línea base:** no.
- **Estado:** **CERRADA (2026-10-07).**

## TD-096

- **Descripción:** (ID antiguo: TD-057 del registro del backend.) El catálogo `dbo.Estado` desplegado no tenía los códigos que usaban los SP de revisión (`P`/`PEND`, `APRO`, `RECH`): los SP caían a `TOP 1 ORDER BY id` y toda solicitud nacía aceptada, también las rechazadas.
- **Impacto:** Alto (histórico).
- **Evidencia:** registro histórico del backend (TD-057): cerrada el 2026-10-07 por la alineación final de la BD. Comprobado en `develop` de BD el 2026-11-16: `usp_resolver_solicitud_revision_asistencia.sql` documenta que `RECHAZADA` pasa la solicitud a `R`, y `usp_radicar_solicitud_revision_asistencia.sql` resuelve el estado pendiente por `codigo IN ('P', 'PEND')`.
- **Resolución esperada:** ninguna pendiente.
- **Bloquea línea base:** no.
- **Estado:** **CERRADA (2026-10-07).**

## TD-097

- **Descripción:** (ID antiguo: TD-058 del registro del backend.) En `dbo.usp_ejecutar_cierre_masivo_periodo` la búsqueda del período objetivo tiene dos pasos: primero por `nombre`/`codigo` y, si no encuentra nada, toma el período con mayor `anio` de toda `uv_periodo_academico` y cierra ese. Con un ejecutor ADMINISTRADOR válido, un código inexistente cierra un período real que nadie nombró.
- **Impacto:** Alto para la integridad de los datos académicos (estados de `EstudianteGrupo`, contadores de `Grupo` y `AuditoriaEvento`).
- **Evidencia:** `schema/stored-procedures/usp_ejecutar_cierre_masivo_periodo.sql` en `develop` de BD, "PASO 2" (líneas 98-126 al 2026-11-16): el segundo `SELECT TOP 1 ... ORDER BY anio DESC, codigo DESC` es el fallback; `VAL_002` solo se devuelve si la vista está vacía. El registro histórico del backend marcó esta deuda como cerrada el 2026-10-07 por la alineación de la BD; la comprobación en `develop` muestra que el fallback sigue presente, así que esa afirmación no se sostiene.
- **Resolución esperada:** regla del responsable (2026-11-16): el cierre masivo se rechaza si el período no existe (`VAL_002`), sin fallback. Añadir una prueba de código inexistente con ejecutor ADMINISTRADOR que verifique que no cambia ninguna fila (relacionada con TD-069).
- **Bloquea línea base:** no.
- **Estado:** **CERRADA (2026-11-17), BD PR 140** (`fix/cierre-masivo-decano-acciones`, mezclado en `develop` con CI en verde).
- **Evidencia de cierre (comprobada en `develop` de BD el 2026-11-17):** `schema/stored-procedures/usp_ejecutar_cierre_masivo_periodo.sql`: el PASO 2 resuelve el período solo por `@codigoPeriodoDefecto` (nombre o código); sin código responde `GEN_002` y con un código que no existe responde `PER_001`, ambos con `estadoResultado = 0` y sin cerrar ni auditar nada. El `SELECT TOP 1 ... ORDER BY anio DESC` que queda solo desempata entre coincidencias exactas; ya no hay fallback al período más reciente. Pruebas `FIX001_CIE_01` a `_03` en `test/test_fix_cierre_001_cierre_masivo.sql`; `FIX001_CIE_01` fallaba en RED con el SP anterior (`GestioAsistenciaDB/docs/work-items/FIX-CIERRE-001-cierre-decano-acciones/VALIDATION.md`). Los códigos de la regla son `GEN_002` y `PER_001`, no `VAL_002`. Sigue pendiente la prueba de integración del backend de TD-069.

## TD-098

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** `GET /api/v1/docentes` devuelve la lista completa de docentes sin filtrar por el ámbito del coordinador y sin paginación. `DocenteController.consultarDocentes()` no recibe usuario ni parámetros de página (`consultarDocentesInputPort.execute()` sin argumentos) y responde `List<DocenteIdentidadDTO>`, y `SecurityConfig` (~línea 155) permite `/api/v1/docentes/**` a `COORDINADOR` y `ADMINISTRADOR`. Las variantes bajo esa ruta comparten la misma regla de rol; su ámbito no se verificó una por una.
- **Impacto:** Alto: un coordinador puede ver docentes de programas ajenos, contra la regla de aislamiento jerárquico (el coordinador ve solo docentes de sus programas) y contra la regla de paginación.
- **Evidencia:** `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/adapter/primary/controller/docente/DocenteController.java` (líneas 57-60) e `infrastructure/config/security/SecurityConfig.java` (línea 155, con el comentario "hoy sin contrato funcional explícito de quién debe administrarlo"). Ya existe un caso de uso con ámbito de programa (`ConsultarDocentesProgramaUseCase`).
- **Resolución esperada:** ámbito y paginación forzados dentro de un SP de consulta (`usp_consultar_*` sobre vista) y `ApiPageResponse<T>` en el backend; el coordinador ve solo docentes de sus programas.
- **Bloquea línea base:** no.
- **Estado:** **CERRADA (2026-11-17), CIERRE-W1B** (Backend PR 168, BD PR 142, Frontend PR 142).
- **Evidencia de cierre (comprobada en `develop` el 2026-11-17):** el paquete retiró las cinco rutas de `/api/v1/docentes/**` (`GET /docentes`, `GET /docentes/{id}`, `GET /docentes/{id}/asignaciones`, `POST /docentes/consultas/id` y `/consultas/asignaciones`; contrato en `CIERRE-W1B-directorios-ambito/CONTRACT.md` del backend, sección 1). `DocenteController` ya no existe (el directorio `controller/docente/` solo contiene controladores de `/docente/**`); `SecurityConfig.java:151-152` deja solo el comentario de la retirada; `infra/security-baseline/access-catalog.json` ya no lista rutas `/api/v1/docentes` y conserva los sustitutos con ámbito validado en el SP: `/admin/docentes` (línea 31), `/decano/docentes` (línea 124) y `/coordinador/docentes` (líneas 76-82). El selector de personas del frontend (`user-picker-modal`) consulta esos sustitutos con búsqueda y paginación en servidor. La copia vieja `scripts/general/tests/test_all_hus.ps1` de la raíz del workspace (fuera de git) todavía llama a `GET /docentes` (línea 657); la suite vigente `scripts/tests/test_all_hus.ps1` de este repositorio no referencia ninguna ruta retirada.

## TD-099

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** el generador de entorno escribe `SPRING_DATASOURCE_USERNAME=sa` en el `.env` del backend, así que el mínimo privilegio no se ejerce en ningún entorno generado con él. Además existen dos roles distintos de aplicación: `db_app_executor` (Infra, `components/sqlserver/init/01-hardening-least-privilege.sql`) y `rol_asistencias_runtime` (repositorio de BD, `schema/security/rol_asistencias_runtime.sql`).
- **Impacto:** Alto en producción (la aplicación podría hacer cualquier cosa en el motor); nulo para la demostración local. Contradice `CONSTITUTION.md` 2.07.1 ("nunca se conectan con `sa`").
- **Evidencia:** `AsistenciasUCO-Infra/scripts/orchestration/init-env.ps1` (~línea 265) y los dos scripts de rol citados.
- **Resolución esperada:** un solo rol y un usuario SQL dedicado de mínimo privilegio en el generador de entorno; documentar el rol vigente y retirar el otro.
- **Bloquea línea base:** no; requisito de producción.
- **Estado:** ABIERTA.

## TD-100

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** las vistas `uv_usuario_autenticacion` y `uv_administrador` seleccionan la columna `password` de `Usuario`, y el rol de aplicación recibe `SELECT` sobre toda vista que coincida con `uv[_]%`.
- **Impacto:** Alto en producción: cualquier lectura por vistas puede alcanzar el valor almacenado de la contraseña. Relacionada con TD-020.
- **Evidencia:** `GestioAsistenciaDB/schema/views/uv_usuario_autenticacion.sql` (`passwordUsuario = u.password`), `schema/views/uv_administrador.sql` (`password = u.password`) y `schema/security/rol_asistencias_runtime.sql` (bucle de `GRANT SELECT` sobre `sys.views` con `LIKE N'uv[_]%'`), todos en `develop` de BD.
- **Resolución esperada:** quitar la columna de las vistas o conceder esas vistas de forma explícita y mínima; mantener la verificación de credenciales fuera de las vistas de lectura general.
- **Bloquea línea base:** no; requisito de producción.
- **Estado:** ABIERTA.

## TD-101

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** `deploy_schema.ps1` ejecuta siempre todos los `schema/seed/*.sql`, incluido `12_usuarios_roles.sql`, que crea cuentas con credenciales fijas versionadas en el repositorio.
- **Impacto:** Alto en producción (cuentas conocidas en una BD real).
- **Evidencia:** `GestioAsistenciaDB/deploy_schema.ps1` (recorrido de `schema\seed`) y `schema/seed/12_usuarios_roles.sql`, en `develop` de BD.
- **Resolución esperada:** separar la semilla de catálogos de la de cuentas y no sembrar cuentas fuera del laboratorio.
- **Bloquea línea base:** no; requisito de producción.
- **Estado:** ABIERTA.

## TD-102

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** el simulador del frontend (`mock-backend.interceptor`) viaja en el build de producción como un fragmento de carga diferida (`mock-backend-lazy.interceptor.ts` lo importa dinámicamente) y se activa con el flag de ejecución `USE_MOCKS === 'true'` de `assets/env.js` (`environment.useFrontendMocks`). El entrypoint `docker-entrypoint.d/40-env-js.sh` toma `USE_MOCKS` del entorno (por defecto `false`), pero no falla ni se niega a arrancar si llega en `true`.
- **Impacto:** Alto para la demostración si el contenedor arranca con el flag mal puesto: la interfaz respondería con datos simulados sin avisar.
- **Evidencia:** archivos citados en `GestioAsistenciaFrontend` (`origin/develop`).
- **Resolución esperada:** fallo cerrado en el entrypoint (negarse a arrancar con `USE_MOCKS=true` en la imagen de entrega) y/o exclusión del simulador del build de producción.
- **Bloquea línea base:** no.
- **Estado:** **CERRADA en cuanto al arranque (2026-11-17), Frontend PR 140.** El simulador sigue viajando en el bundle: queda como nota de TD-106 (no se abrió una entrada aparte).
- **Evidencia de cierre (comprobada en `develop` del frontend el 2026-11-17):** `docker-entrypoint.d/40-env-js.sh` (líneas 8-13) termina con error si `USE_MOCKS=true` sin `ALLOW_MOCKS=true` (falla cerrada, solo laboratorio); `docker-compose.yml` (línea 14) lo documenta. Lo que no cambia: `src/app/core/interceptors/mock-backend-lazy.interceptor.ts:8` sigue importando dinámicamente `mock-backend.interceptor`, es decir, el fragmento del simulador se sigue generando en el build de producción; solo no se activa sin las dos variables.

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** `environment.production` vale `false` también en el build de producción: hay un único `src/environments/environment.ts` y `angular.json` no define `fileReplacements`, mientras el `Dockerfile` compila con `--configuration=production`.
- **Impacto:** Medio en producción (cualquier lógica condicionada por `environment.production` se comporta como en desarrollo).
- **Evidencia:** `GestioAsistenciaFrontend/src/environments/environment.ts` (`production: false`), `angular.json` (sin `fileReplacements`) y `Dockerfile`.
- **Resolución esperada:** archivo de entorno de producción con `fileReplacements`, o derivar el valor del build.
- **Bloquea línea base:** no; requisito de producción.
- **Estado:** ABIERTA.

## TD-104

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** el stream SSE (`GET /api/v1/realtime/stream?grupoId=`) valida la titularidad del docente una única vez al suscribir y no tiene un máximo de conexiones por usuario (no hay ningún límite en `src/main` ni en `application.yml`).
- **Impacto:** Medio en producción (agotamiento de recursos por conexiones abiertas; un docente al que se le retira el grupo conserva el stream mientras siga abierto).
- **Evidencia:** `RealtimeEventsController.subscribe` (Javadoc: "se valida una unica vez al establecer la suscripcion") y ausencia de configuración de límite.
- **Resolución esperada:** tope de conexiones por usuario y revalidación periódica o por evento del ámbito.
- **Bloquea línea base:** no; requisito de producción.
- **Estado:** ABIERTA.

## TD-105

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** hay 59 llamadas `assume*` (52 de ellas `assumeTrue`) repartidas en 18 clases de integración (`*IT`) del backend; si faltan datos o servicio, la prueba se omite en silencio y el resultado sigue en verde. Cifra observada más reciente: 17 pruebas omitidas en la última corrida de integración (`mvnw clean verify -Pintegration` de CIERRE-W2B, 2026-11-16/17: 367 de integración según su VALIDATION, 0 fallos, 17 omitidas; el reporte de la sesión de cierre habla de 368).
- **Impacto:** Medio: oculta regresiones. Relacionada con TD-044.
- **Evidencia:** búsqueda de `assume`, `assumeTrue`, `assumeFalse` y `assumeThat` en `GestioAsistenciaBackend/src/test` (conteo del 2026-11-16).
- **Resolución esperada:** fixtures propios y fallo explícito (o un reporte de omitidas en la CI).
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING (aplazable).

## TD-106

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** todos los E2E de Playwright del frontend corren contra el simulador (`USE_MOCKS=true`) y con `SECURITY_PROVIDER=legacy`; no ejercitan el modo `baseline` (Authorization Code + PKCE) ni el backend real.
- **Impacto:** Medio: el camino de autenticación vigente y la integración real no tienen E2E de interfaz.
- **Evidencia:** `playwright.config.ts` (comentario de cabecera) y `e2e/support/env.e2e.js` en `GestioAsistenciaFrontend`. La cobertura contra el backend real, sin interfaz, la da `scripts/tests/test_all_hus.ps1` de Infra.
- **Nota (2026-11-17):** con el cierre de TD-102 el contenedor ya no arranca con `USE_MOCKS=true` sin `ALLOW_MOCKS=true`, pero el simulador sigue en el bundle de producción (`mock-backend-lazy.interceptor.ts:8`, importación dinámica). Excluirlo del build de producción queda como parte de esta deuda, junto con ampliar los E2E contra el stack real. Ver también TD-112 (el simulador diverge del backend real).
- **Resolución esperada:** un subconjunto de E2E contra el stack real en modo `baseline`.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING (aplazable).

## TD-107

- **Origen:** auditoría del 2026-11-16 (la auditoría cuenta 27 puntos; no se recontaron al redactar esta entrada).
- **Descripción:** el frontend filtra, pagina y calcula datos de negocio en el cliente, contra la regla de presentación pura. Ejemplos comprobados: `dean-management.service.ts` pide los coordinadores con `pagina=1` y `tamano=100` y `dean-coordinadores.component.ts` filtra y pagina en el cliente, de modo que más de 100 se truncan; la búsqueda de `teacher-claims.component.ts` filtra solo la página ya cargada; el folio `REC-#…` se compone en el cliente (`id.slice(0, 8).toUpperCase()` en `teacher-claims.component.ts` y `group-claims-modal.component.ts`).
- **Impacto:** Alto con datos reales: listas truncadas, búsquedas incompletas y folios que no coinciden con los del servidor.
- **Evidencia:** archivos citados en `GestioAsistenciaFrontend` (`origin/develop`).
- **Resolución esperada:** mover filtros, paginación y folios al servidor (SP de consulta con `ApiPageResponse<T>`), por fases.
- **Bloquea línea base:** no.
- **Estado:** **CERRADA (2026-11-17)** por los seis paquetes del cierre; lo que quedó expresamente sin mover está en TD-119 y relacionadas (TD-113, TD-114, TD-117).
- **Evidencia de cierre (contratos en `GestioAsistenciaBackend/docs/work-items/CIERRE-*/CONTRACT.md`; los seis paquetes mezclados en `develop` con CI en verde):**
  - **W1A (docente: reclamos y padrón; BD 141, Backend 167, Frontend 141):** `GET /docente/reclamos` filtra por `busqueda` y `grupoId` en el SP y devuelve el folio `REC-XXXXXXXX` generado por el servidor (campo `nombre`); ruta nueva `GET /docente/grupos/{grupoId}/estudiantes` paginada en servidor. En el frontend ya no se compone el folio con `id.slice(0, 8)` (solo queda un `slice` en un adaptador de simulación).
  - **W1B (directorios; BD 142, Backend 168, Frontend 142):** `GET /decano/coordinadores` filtra (`busqueda`, `estaActivo`, `sinPrograma`) y pagina con el SP `usp_consultar_coordinadores_facultad_paginado`, sin el tope de 100 y con el total real; nombres y apellidos separados desde el backend.
  - **W2A (coordinador; BD 143, Backend 169, Frontend 143):** `GET /coordinador/grupos` pasa a `ApiPageResponse` con `franjas`; filtro `caracter` en materias; `consolidado-asistencia/opciones` para coordinador y decano; `estado` del período calculado por `uv_periodo_academico` (PLANEACION, ACTIVO, CERRADO); totales con `totalElementos`.
  - **W2B (estudiante; BD 145, Backend 171, Frontend 146):** `GET /estudiante/materias/resumen` (materias, en riesgo, horas de falta y créditos desde la base); sesiones del estudiante ordenadas y paginadas en servidor.
  - **W3M (matriz del docente; BD 144, Backend 170, Frontend 144):** `GET /docente/grupos/{grupoId}/matriz-asistencia` y `.../resumen-sesiones`; el estado de cada sesión se decide en la base con el reloj del servidor (UTC).
  - **W3I (indicadores; BD 146, Backend 172, Frontend 145):** los totales de portada de administrador, decano, coordinador y docente (`GET /docente/resumen-grupos`) y el nivel de permanencia (`codigoPermanencia`, `codigoPermanenciaActual`) vienen del servidor con `ufn_clasificar_permanencia`; el cliente distingue "cargando" de "sin datos".
- **Sin mover, declarado por los paquetes:** ver TD-119 (restos menores en el cliente), TD-113 (textos y rótulos), TD-114 (código sin uso) y TD-117 (F-DOC-03). La diferencia de definición de las cifras de pérdida pasó a TD-116.

## TD-108

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** no existe configuración ni runbook de producción: el Keycloak del compose de Infra arranca con `start-dev` (`docker-compose.yml` y `components/keycloak/docker-compose.yml`), todo va por HTTP sin terminación TLS definida (el HSTS del frontend solo se emite con `ENABLE_HSTS=true`) y no hay runbook de despliegue ni de rollback de release (`docs/runbooks/` solo trata el laboratorio local; el rollback de `MIGRATION_GUIDE.md` es del cambio de scripts).
- **Impacto:** Alto para un despliegue real; nulo para la demostración.
- **Evidencia:** archivos citados y lista de requisitos en [REQUISITOS_PRODUCCION](../runbooks/REQUISITOS_PRODUCCION.md).
- **Resolución esperada:** la universidad define el entorno y se escribe el runbook correspondiente.
- **Bloquea línea base:** no; requisito de producción.
- **Estado:** ABIERTA.

## TD-109

- **Origen:** auditoría del 2026-11-16.
- **Descripción:** el nginx del frontend solo define `Cache-Control` para `/assets/env.js` (`no-store`); `location /` no fija caché para `index.html` ni para los assets con hash (`outputHashing: all`).
- **Impacto:** Bajo en la demostración; en producción, recargas innecesarias o un `index.html` viejo tras un despliegue.
- **Evidencia:** `GestioAsistenciaFrontend/nginx/templates/default.conf.template`.
- **Resolución esperada:** `no-cache` para `index.html` y caché larga e inmutable para los assets con hash.
- **Bloquea línea base:** no.
- **Estado:** **CERRADA (2026-11-17), Frontend PR 140.**
- **Evidencia de cierre (comprobada en `develop` del frontend el 2026-11-17):** `nginx/templates/default.conf.template`: `location = /index.html` con `Cache-Control "no-cache"` (líneas 46-47) y un `location` para los assets con hash (`js`, `css`, fuentes) con `Cache-Control "public, max-age=31536000, immutable"` (líneas 55-56); `/assets/env.js` conserva `no-store` (línea 38).

## TD-110

- **Origen:** decisión del responsable, 2026-11-16 (cierra TD-084).
- **Descripción:** migración futura a una sesión por cookie `HttpOnly` con protección CSRF, o a un patrón BFF, para producción. Se evaluó y se difirió. Motivos: (1) el PEP de Security Baseline exige el Bearer del usuario; (2) haría falta un cliente confidencial; (3) tres contratos congelados fijan Bearer (`docs/contracts/openapi/openapi-golden-path.yaml`, `docs/contracts/openapi/BACKEND_GOLDEN_PATH_CONTRACT.md` y `docs/contracts/events/REALTIME_EVENT_CONTRACT.md`).
- **Impacto:** Bajo para la demostración. El modo `baseline` guarda el access token solo en memoria; el modo `legacy` (contingencia, `SECURITY_PROVIDER=legacy`) conserva además un refresh token en `sessionStorage` (`auth.service.ts`), por eso no debe usarse fuera del laboratorio.
- **Evidencia:** cabecera de `baseline-oidc.ts` en el frontend (access token solo en memoria, sin refresh token), `CONSTITUTION.md` 4.04.1 y [SECURITY_BASELINE_INTEGRATION](../governance/SECURITY_BASELINE_INTEGRATION.md).
- **Resolución esperada:** si la universidad lo exige, una nueva decisión con cambio de los contratos congelados y de la configuración de Security Baseline.
- **Bloquea línea base:** no.
- **Estado:** DIFERIDA A PRODUCCIÓN.

## TD-111

- **Origen:** gates de BD de los paquetes W1B, W2B y otros del cierre del 2026-11-16/17.
- **Descripción:** dos pruebas de la suite de BD fallaron una vez y pasaron al repetir sin cambios, en tres paquetes distintos, sin relación con lo que cada paquete cambiaba: `CULM001_D3_13` (consulta de parámetros; el reporte del cierre la atribuye a un empate de marcas de tiempo) y `LB004D_W2_ATTACH_STATE_UTC` (comparación de marcas de tiempo; el VALIDATION de CIERRE-W2B anota que "paso al repetir sin cambios").
- **Impacto:** Bajo-medio: una compuerta de CI roja intermitente que obliga a repetir y puede ocultar una falla real. Relacionada con TD-085 (otra falla intermitente del mismo pipeline).
- **Evidencia:** `GestioAsistenciaDB/test/test_culm001_d3_parametros.sql` (aserciones `CULM001_D3_13`, líneas 318-322) y `test/test_lb004d_support_binding.sql` (línea 288, `W2_ATTACH_STATE_UTC`); `GestioAsistenciaBackend/docs/work-items/CIERRE-W2B-estudiante-resumen/VALIDATION.md` (última línea). La causa exacta no se analizó en esta revisión documental.
- **Resolución esperada:** hacer deterministas las comparaciones de tiempo (instante fijo del fixture o tolerancia explícita y justificada en el contrato de la prueba); no relajar la aserción para que pase (regla de integridad de pruebas de `AGENTS.md`).
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-112

- **Origen:** recorrido de los paquetes del cierre, 2026-11-16/17.
- **Descripción:** el simulador del frontend (`mock-backend.interceptor`, solo laboratorio) diverge del backend real: (1) no atiende `GET /api/v2/sesiones/grupo/{id}` (el servicio de sesiones v2 la pide), de modo que cae en la respuesta por defecto del simulador (501 `MOCK_ROUTE_NOT_IMPLEMENTED`) al elegir un grupo, y la matriz simulada sale sin sesiones (`sesiones: []`, `celdas: []`); (2) los reclamos simulados no traen `grupoId`, así que el filtro por grupo del listado de reclamos devuelve vacío; (3) el estado de matrícula sale `ACTIVO` en el padrón simulado y `A` en las rutas nuevas (matriz y resumen).
- **Impacto:** Bajo (solo laboratorio con `USE_MOCKS=true` y `ALLOW_MOCKS=true`). Relacionada con TD-106.
- **Evidencia:** `GestioAsistenciaFrontend/src/app/core/interceptors/mock-backend.interceptor.ts` (respuesta 501 por defecto en las líneas ~1105-1112; el padrón copia `e.estadoMatricula`, líneas 116-117, mientras `codigoMatriculaMock` mapea `ACTIVO` a `A`, líneas 94-96, y la matriz declara que no simula sesiones, líneas 779-780; el filtro `grupoId` de reclamos está en la línea 760); `core/services/session-v2.service.ts:44` (la ruta v2 que el simulador no atiende); `core/mocks/role-management.mock.ts` (`MOCK_SOLICITUDES_REVISION` sin campo `grupoId`). El 501 al elegir un grupo es lo observado en el recorrido; esta revisión lo dedujo de la lectura del código y no lo reprodujo.
- **Resolución esperada:** completar el simulador con las rutas y los códigos del backend real, o retirarlo del build de producción (TD-106).
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-113

- **Origen:** paquetes W3M y W3I (declarado como fuera de alcance).
- **Descripción:** hay textos de interfaz literales fuera del catálogo de mensajes y rótulos de período escritos a mano: "Ningún estudiante del grupo coincide con la búsqueda." en la planilla y en la lista de estudiantes del docente, y "Semestre 2026-II" en los tableros del docente y del estudiante.
- **Impacto:** Bajo. El texto no cambia con el catálogo (SSOT de mensajes) y el rótulo del período queda desactualizado al cambiar de semestre.
- **Evidencia:** `GestioAsistenciaFrontend/src/app/features/teacher/teacher-grupos/components/teacher-grupo-sabana.component.ts:111` y `teacher-grupo-estudiantes.component.ts:44`; `features/dashboard/overview/components/overview-teacher.component.ts:30` y `overview-student.component.ts:30`; ninguno figura en `core/messages/mensajes-ui.ts`. `GestioAsistenciaBackend/docs/work-items/CIERRE-W3I-indicadores/PLAN.md` (sección "Fuera de alcance") reporta los rótulos de período escritos a mano.
- **Resolución esperada:** códigos nuevos en `MENSAJES_UI` (y en el catálogo de MessageUcoLab) y el nombre del período tomado del servidor.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-114

- **Origen:** paquetes W2A, W3M y W1B.
- **Descripción:** tras el cierre quedó código del frontend sin llamadores en la aplicación (solo en pruebas): `CourseService.getDeanCourses` y `CoordinatorManagementService.getEstudiantesDirectorio` (descarga todas las páginas); y `GroupService.getStudentsByGroup` y `StudentService.getStudentsByGroup` duplican la misma responsabilidad (la primera la usa `attendance-control`, la segunda `teacher-grupos`).
- **Impacto:** Bajo: confusión y riesgo de reintroducir lectura sin paginar.
- **Evidencia:** `GestioAsistenciaFrontend/src/app/core/services/course.service.ts:70`, `coordinator-management.service.ts:569`, `group.service.ts:45` y `student.service.ts:87`; búsqueda de llamadores sobre `src/app` (solo `getDeanCoursesPage` y `getEstudiantesDirectorioPagina` se usan).
- **Resolución esperada:** eliminar los dos métodos sin uso y unificar los dos `getStudentsByGroup` en un servicio.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-115

- **Origen:** CIERRE-W1B (`CONTRACT.md`, sección 5).
- **Descripción:** `usp_validar_permiso_rbac_usuario_interno` ya no acepta subcadenas: compara el perfil por código (`AD`, `DE`, `CD`, `DO`, `ES`) o por el nombre completo exacto, sin distinguir mayúsculas, y descarta los elementos vacíos de la lista. Unos 120 llamadores (cifra del contrato) pasan el nombre (`'DOCENTE'`); solo `usp_resolver_revision_cancelacion` pasa el código. Migrarlos a códigos es deuda opcional. Se relaciona con los perfiles y estados literales en SP y vistas (por ejemplo, `estado` de `uv_periodo_academico`, con `PLANEACION`, `ACTIVO` y `CERRADO` escritos en la vista como los códigos de `uv_grupo`).
- **Impacto:** Bajo: funciona y es exacto; el costo es de coherencia con la regla de cero datos quemados.
- **Evidencia:** `GestioAsistenciaDB/schema/stored-procedures/usp_validar_permiso_rbac_usuario_interno.sql` (líneas 56-67: `STRING_SPLIT` y comparación exacta con `codigoPerfil` o `nombrePerfil`); `schema/views/uv_periodo_academico.sql` (líneas 20-22). Referencias a `usp_validar_permiso_rbac_usuario_interno` en 92 archivos de `schema/` (conteo propio del 2026-11-17).
- **Resolución esperada:** si se decide, migrar los llamadores a códigos de perfil y resolver los estados contra catálogos; mientras tanto, mantener la comparación exacta.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-116

- **Origen:** CIERRE-W3I (`CONTRACT.md`, sección 3).
- **Descripción:** DECISION_REQUIRED. El consolidado de asistencia por grupo del decano cuenta MATRÍCULAS en pérdida (incluye canceladas por inasistencia y todos los períodos del filtro), y el indicador del decano cuenta PERSONAS con matrícula activa en el período vigente (decisión D3: la peor clasificación de cada persona). Caso observado: 958 frente a 675. No es un error: son dos definiciones intencionales. Un estudiante que pierde dos grupos suma 2 en la tabla y 1 en el indicador.
- **Impacto:** Bajo-medio: dos cifras con rótulos parecidos pueden leerse como contradicción en la demostración.
- **Evidencia:** `CIERRE-W3I-indicadores/CONTRACT.md` sección 3 y la prueba de BD `W3I_DIF_01_PERDIDA` (fixture con un estudiante que pierde dos grupos: consolidado 2, indicador 1 de 3).
- **Resolución esperada:** decisión del responsable: unificar la definición o aclarar los rótulos de las dos cifras.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA — DECISION_REQUIRED.

## TD-117

- **Origen:** hallazgo F-DOC-03 del recorrido del 2026-11-15 (`FASE-2B-certificacion-integral/VALIDATION.md` del backend).
- **Descripción:** DECISION_REQUIRED. El tablero del docente muestra las revisiones pendientes pero no enlaza directo a las decisiones de cancelación pendientes: viven en el hub de cada grupo ("Decisiones pendientes" dentro de Mis Grupos). Un enlace directo exige una pantalla global de decisiones del docente.
- **Impacto:** Bajo: la función existe; es de descubrimiento.
- **Evidencia:** F-DOC-03 en el VALIDATION citado; `GestioAsistenciaFrontend/src/app/features/teacher/teacher-grupos/components/teacher-grupo-decisiones.component.ts` (las decisiones son un componente del hub del grupo) y `app.routes.ts` (no hay ruta global de decisiones del docente; `docente/grupos`, `docente/horarios` y `docente/reclamos`).
- **Resolución esperada:** decidir si se crea una pantalla global o se deja el recorrido por grupo.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA — DECISION_REQUIRED.

## TD-118

- **Origen:** FIX-CIERRE-001 de BD.
- **Descripción:** `esResolutorActual` queda siempre en 0 en `usp_consultar_revisiones_cancelacion_docente_paginado`: la columna significa "es resolutor de esta revisión" (coordinador), el docente nunca resuelve (DEC-065) y el cliente del docente no la usa. Si se quisiera la semántica "quién debe actuar ahora", hay que decidirla; no se puede derivar del código.
- **Impacto:** Bajo.
- **Evidencia:** `GestioAsistenciaDB/schema/stored-procedures/usp_consultar_revisiones_cancelacion_docente_paginado.sql:95` (`esResolutorActual = CAST(0 AS BIT)`) y su comentario de cabecera; `GestioAsistenciaDB/docs/work-items/FIX-CIERRE-001-cierre-decano-acciones/VALIDATION.md`.
- **Resolución esperada:** decisión de producto sobre la semántica (o retirar la columna del contrato del docente).
- **Bloquea línea base:** no.
- **Estado:** ABIERTA — DECISION_REQUIRED.

## TD-119

- **Origen:** declarado por los paquetes W3I, W1B y W3M como fuera de alcance o sin cambio.
- **Descripción:** restos menores de lógica o de valores por defecto en el cliente: (1) `dean-programas` suma los créditos y asignaturas de un catálogo pequeño cargado completo página a página; (2) `admin-decanos` y `admin-facultades` filtran y cuentan en el cliente catálogos pequeños y completos; (3) los formularios de alta preseleccionan el primer tipo de identificación y usan `|| 'CC'` como respaldo; (4) las reglas de marcado masivo y la ventana de toma de asistencia viven en el cliente (el backend revalida).
- **Impacto:** Bajo mientras los catálogos sigan pequeños; el valor por defecto `'CC'` puede mostrar un tipo de documento que el servidor no entregó.
- **Evidencia:** `GestioAsistenciaFrontend/src/app/features/dean/dean-programas/dean-programas.component.ts:205`; `features/admin/admin-decanos/admin-decanos.component.ts:438` y `:595-596`; `features/admin/admin-facultades/admin-facultades.component.ts:63`; `core/services/admin-management.service.ts:144`, `dean-management.service.ts:76`, `shared/components/user-picker-modal/datos-persona-seleccionada.ts:35` y `features/coordinator/coordinator-docentes/components/coordinator-docente-form-modal.component.ts:62,161`; `core/utils/session-attendance-window.util.ts` y `session-selection.util.ts` (fuera de alcance de W3M, sección 6); `CIERRE-W3I-indicadores/PLAN.md` (decisión por pantalla).
- **Resolución esperada:** mover los totales al SP si los catálogos crecen; sin valores por defecto de negocio en los formularios; decidir si la ventana de toma sale del cliente.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-120

- **Origen:** revisión de código, 2026-11-17.
- **Descripción:** el interceptor global de errores del frontend solo muestra aviso para 403 y para 5xx; los 400, 409 y 422 dependen de cada pantalla (los modales de alta se apoyan en el aviso flotante, cuya capa se corrigió en Frontend PR 140). Una pantalla nueva que no maneje esos códigos queda sin mensaje (el síntoma de los hallazgos F-COORD-02 y F-EST-02).
- **Impacto:** Bajo-medio: riesgo de silencio ante rechazos del backend en pantallas nuevas.
- **Evidencia:** `GestioAsistenciaFrontend/src/app/core/interceptors/error.interceptor.ts:20-29` (solo `FORBIDDEN` y `status >= 500`).
- **Resolución esperada:** decidir una política común para 400/409/422 (aviso global con opt-out, como ya existe `BYPASS_GLOBAL_ERROR_TOAST`) o una regla de revisión por pantalla.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-121

- **Origen:** CIERRE-W1B y regla HU136.
- **Descripción:** `GET /api/v1/admin/docentes` devuelve por defecto solo docentes con vínculo activo en las facultades de la institución del administrador (regla HU136). Un docente que nunca tuvo vínculo con un programa no aparece en el selector del administrador (por ejemplo, para nombrarlo decano).
- **Impacto:** Bajo: comportamiento definido, pero puede sorprender en una demostración.
- **Evidencia:** `GestioAsistenciaBackend/infra/security-baseline/access-catalog.json:31` ("HU136: docentes con vinculo activo en las facultades de la institucion del administrador") y `CIERRE-W1B-directorios-ambito/CONTRACT.md` sección 1.
- **Resolución esperada:** decidir si el administrador necesita ver también docentes sin vínculo (parámetro o ruta aparte).
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-122

- **Origen:** verificación de solo lectura por rol del 2026-11-17.
- **Descripción:** `scripts/tests/verificar_datos_prueba.py` dio 26 de 28 contra el laboratorio real. Las dos diferencias son de CONTEO, no de permisos: coordinadores de Ingeniería 9 frente a 4 esperados y estudiantes de Sistemas 10 frente a 8. La causa son 14 cuentas de prueba creadas después de cargar el conjunto de datos: `culm1-e2e-*`, `PAULA PASAPORTE`, `VALENTINA PRERREGISTRO PRUEBA`, `LAURA ACTIVACION` y `TEST HOY`. Las otras 20 rutas nuevas de los paquetes dieron correctas por rol.
- **Impacto:** Bajo: usar ese script como compuerta sin limpiar da falsos rojos; el guion de pruebas manuales lo advierte.
- **Evidencia:** `scripts/tests/verificar_datos_prueba.py` (casos "Ingeniería: coordinadores de su facultad" con 4 esperados y "Sistemas: sus 8 estudiantes" con 8 esperados); la medición la hizo la sesión de cierre contra el laboratorio (no se repitió en esta revisión documental).
- **Resolución esperada:** eliminar esas cuentas o recargar la base con `infra.ps1 datos-prueba cargar -Yes` antes de usar el script como compuerta.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-123

- **Origen:** incidente operativo del 2026-11-16 (nota, no deuda de código).
- **Descripción:** un contenedor desechable de pruebas montó por error el volumen `asistencias-minio-data` del laboratorio. Se eliminó ese contenedor y el servicio quedó sano, con el bucket `asistencias-soportes` (22 archivos), pero no hubo un conteo previo contra el cual comparar, así que no se puede afirmar que no se perdió ni se modificó ningún objeto.
- **Impacto:** Bajo (laboratorio; los soportes de prueba se pueden recrear).
- **Evidencia:** reporte de la sesión de cierre; sin conteo previo.
- **Resolución esperada:** conservar el conteo de objetos antes de operar sobre volúmenes del laboratorio; no montar volúmenes con nombre en contenedores desechables.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING (verificación pendiente).

## TD-124

- **Origen:** fase F3 (Infra) del plan del componente propio de Notificaciones, 2026-11-22.
- **Descripción:** el Backend y el Servicio de Notificaciones UCO se autentican entre sí con un secreto compartido en la cabecera `X-Api-Key` (`NOTIFICACIONES_API_KEY`, generado por `infra.ps1 stack up` en `stack/.env`). Es suficiente para el laboratorio y la demostración, pero no da identidad por servicio, rotación ni revocación individual. El destino es OAuth2 client-credentials emitido por Seguridad para servicios, como ya hace MessageUcoLab; hoy Seguridad no lo ofrece para este tipo de cliente.
- **Impacto:** Medio para producción; sin efecto en la demostración.
- **Evidencia:** `docs/contracts/notificaciones/NOTIFICACIONES_CONTRACT.md` (sección 4); `Complementos/Notificaciones/Guia-integracion-Notificaciones.md` (sección 2).
- **Resolución esperada:** cuando Seguridad ofrezca client-credentials para servicios, registrar al Backend como cliente, validar el JWT en el componente (y retirar `X-Api-Key`), publicar el cambio como addendum del contrato con hash nuevo y rotar el secreto.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA; requisito de producción.

## TD-125

- **Origen:** extracción de Notificaciones, corridas del Backend del 2026-11-22.
- **Descripción:** la prueba `CatalogoParametrosHttpParameterCatalogAdapterTest.fallo_sincrono_al_lanzar_el_refresco` es inestable: a veces falla con `TooManyActualInvocations` (2 esperadas frente a 3 reales) porque depende de los tiempos del refresco asíncrono del adaptador. No hay cambio de código de por medio: la misma prueba pasa y falla en corridas consecutivas.
- **Impacto:** Bajo: falsos rojos en `mvnw test` y en la CI.
- **Evidencia:** `GestioAsistenciaBackend`, clase `CatalogoParametrosHttpParameterCatalogAdapterTest` (corridas intermitentes).
- **Resolución esperada:** volver determinista la prueba (ejecutor síncrono o sincronización explícita en lugar de depender de los tiempos), sin relajar la aserción de invocaciones.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-126

- **Origen:** extracción de Notificaciones, 2026-11-22.
- **Descripción:** `VerificacionCorreoMarcadorProvider` recuerda en memoria el token de verificación de correo ya emitido. Si el proceso se reinicia entre dos intentos de despacho, el marcador se pierde: se emite un token nuevo, se revoca el enlace anterior y el correo ya entregado queda con un enlace inválido.
- **Impacto:** Bajo/Medio: caso residual acotado a reinicios entre intentos de despacho.
- **Evidencia:** `GestioAsistenciaBackend`, `VerificacionCorreoMarcadorProvider`.
- **Resolución esperada:** persistir el marcador con un procedimiento almacenado idempotente (emitir-o-reutilizar token vigente por usuario y propósito) en la BD, en vez de memoria del proceso; cambio de DB y Backend con su contrato.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-127

- **Origen:** INT-004, actualización del Catálogo de Parámetros a 0.1.17 (2026-11-22).
- **Descripción:** en 0.1.17 los ambientes son un catálogo fijo (`00000000-0000-0000-0000-000000000010/11/12`: Producción, Desarrollo, Pruebas) y los estados de metadato-ambiente también (`…0020` Activo, `…0021` Inactivo). Los metadatos y metadatos-ambiente creados con 0.1.7 conservaron sus ids viejos (ambiente `36ddaf78-…`, estado `829875d4-…`), que ya no existen (`GET /ambientes/36ddaf78-…` 404). El volumen persiste y no hay migración ni aviso: la consulta M2M no devuelve parámetros hasta corregir cada fila a mano.
- **Impacto:** Medio para quien actualiza con datos: la configuración parece intacta en el listado y la consulta sale vacía.
- **Evidencia:** `Complementos/CatalogoParametros/Catalogo-Parametros`, `/administracion` de la aplicación `AsistenciasUCO` antes y después de la migración (INT-004 §4).
- **Resolución esperada:** del equipo de Parámetros (migración de datos o nota de actualización). En el laboratorio se migró con `PUT` de cada fila; se reporta al equipo, no se parcha su componente.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-128

- **Origen:** INT-004, kit del Catálogo 0.1.17.
- **Descripción:** `docker-compose.yml` hace depender `app` de `otel-collector` (`service_started`) y este de `jaeger`: `docker compose up app` arranca Prometheus, Grafana, Loki y Jaeger aunque no se quieran. Infra lo evita con `depends_on: !override` en `stack/secciones/ext-parametros.yml`. El app, sin collector, registra `UnknownHostException` cada minuto.
- **Impacto:** Bajo (memoria del laboratorio).
- **Evidencia:** compose del kit; `stack/secciones/ext-parametros.yml`.
- **Resolución esperada:** del equipo de Parámetros: perfil `observabilidad` para esos servicios y exportación OTLP apagada por defecto.
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.

## TD-129

- **Origen:** INT-004, creación de la identidad `asistencias-uco-a-catalogo-parametros-dev` (2026-11-22); mismo patrón que INT-002 (identidad `…-dev` de Catálogo → MessageUcoLab).
- **Descripción:** `POST /api/v1/applications/{id}/service-identities` respondió 500 `INTERNAL_ERROR` (`TimeoutException` de 3000 ms en `ServiceIdentityAdministrationController#create`) pero el cliente `svc-…` ya estaba creado en Keycloak y el PDP no tenía la fila: el nombre queda ocupado y el secreto perdido. En el laboratorio se borró el cliente huérfano por el Admin REST de Keycloak y se reintentó.
- **Impacto:** Medio en el laboratorio; operación riesgosa en cualquier ambiente.
- **Evidencia:** log de `ext-seguridad-pdp` (`Error no manejado al atender la petición`), clientes `svc-*` de `security-baseline`.
- **Resolución esperada:** del equipo de Seguridad: timeout configurable, creación idempotente o compensación (borrar el cliente si falla el registro).
- **Bloquea línea base:** no.
- **Estado:** ABIERTA / NON_BLOCKING.
