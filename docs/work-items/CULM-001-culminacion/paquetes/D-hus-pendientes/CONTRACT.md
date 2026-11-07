# CULM-001 · Paquete D — CONTRACT (HUs pendientes de la sección 3.6 y hallazgos medios)

> **Estado:** v2, aplica `REVIEW-1.md` (11 bloqueantes y 20 observaciones) y DEC-044. Pendiente de REVIEW-2 (verificación). No se congela ni se firma (`.sha256`) antes de "sin objeciones". El RED empieza después de la revisión.
> **Fecha:** 2026-11-07 (v1 y v2). **Fase SDD:** 02 CONTRACT.
> **Fuentes:** `docs/PROMPT_FABLE_CULMINACION.md` §3.6 (líneas 66-72) y §3.8; `DECISIONES.md` DEC-040 (alcance), DEC-042 (supuestos de D aceptados), **DEC-044** (bloqueantes de REVIEW-1), DEC-022 §4/§8, DEC-025, DEC-028, DEC-031, DEC-036, DEC-037/DEC-038, DEC-041 (golden path 1.5.0 de C); `FINDINGS.md` (35 filas `paquete-D`, más F-COO-007 y R-8 de A, que A y B difirieron a D); `RESEARCH-MODELO-ACTUAL.md` §2.5, §4.3 y §6; `HU-CATALOG.md`; `TECHNICAL_DEBT.md` de Infra y de Backend; `GestioAsistenciaDB/docs/work-items/HU005-HU016-categorias-justificacion/DISENO_CAMBIO_COORDINADO.md`; CONTRACT de A, B, B2 (congelado v5, `9b668c7d…`) y C; `AGENTS.md` §3.3 y §4.
> **Rutas:** `DB:` = `GestioAsistenciaDB/`, `BE:` = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, `BE-T:` = `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`, `FE:` = `GestioAsistenciaFrontend/src/app/`, `INFRA:` = `AsistenciasUCO-Infra/`. Todo bajo `C:\Proyectos\GestionAsistencia-CULM001\`.
> **Base:** `integracion/CULM-001` con A y B.1. D.7 exige B.2 (backend y BD); D.8 y D.9-a exigen B.2 y **B2** (migraciones 17 y 18); D.9-c y la parte de tiempo real de D.3 exigen C (§13).
> **Numeración:** migración del subpaquete D.x = `19 + x` (DEC-028: "D = 20+"; D.1 = `20` … D.9 = `28`). **Semilla de D.x = `50 + x` (D.1 = `51` … D.9 = `59`)**: DEC-028 no reserva semillas para D y C usa `40` y `41`; la precisión está registrada en DEC-044 (1). Prefijo `culm001_d<x>` en pruebas, permisos y manifiestos. Cada D.x se puede mezclar en cualquier orden sin renumerar.

---

## Cambios respecto a v1

| Objeción | Corrección en v2 | Dónde |
| :--- | :--- | :--- |
| BLOQ-1 | Semillas `51`–`59` (DEC-044 (1)) | Cabecera, §2–§11, §13 |
| BLOQ-2 | Fecha límite desde la vista nueva `uv_sesion_estudiante_reclamo` y el SP `usp_consultar_sesiones_materia_estudiante`; `uv_sesion` (congelada) no se toca; la HQL de `SesionMateriaEstudianteJpaRepository` se sustituye (DEC-044 (2)) | §2.2, §2.3 |
| BLOQ-3 | v2 y v3 comparten `usp_internal_radicar_solicitud_revision` con parámetros `OUTPUT` (sin `INSERT-EXEC`); el plazo se valida **después** de la reejecución idempotente por correlación; pruebas D1-12 y D2-15 (DEC-044 (3)) | §2.2, §3.2 |
| BLOQ-4 | F-TRX-021: las mallas por plan siguen el 404 `PLA_002` de B2 (D solo añade pruebas de regresión); [SUPUESTO-D-14] queda acotado a rutas por grupo. D.8 y D.9-a dependen de B2 y escriben sobre `uv_resumen_asistencia_estudiante_programa_grupo` y el grano (grupo, programa) de B2 (DEC-044 (4)) | §0, §1.1, §9, §11, §13 |
| BLOQ-5 | `POST /realtime/emit` se **mantiene** solo ADMINISTRADOR con cuerpo validado (DEC-042, DEC-044 (5)) | §10, §11 F-TRX-016 |
| BLOQ-6 | Consumidores de `ApiPageResponse` enumerados uno a uno (frontend, backend, `test_all_hus.ps1`) con prueba RED por consumidor (DEC-044 (6)) | §11.3 |
| BLOQ-7 | Pruebas RED de ClamAV (EICAR) y del límite de subidas por minuto con varios archivos, en backend y frontend (DEC-044 (7)) | §3.3, §3.4 |
| BLOQ-8 | `down` de D.2 archiva categorías y soportes colapsados en `zz_archivo_*` (patrón A.1/DEC-010); sección nueva "Orden de rollback" con aborto por objeto compartido y pruebas (DEC-044 (8)) | §3.2, §14.2 |
| BLOQ-9 | El consolidado calcula tres porcentajes con `ROUND(…, 2)` y el cuarto como `100 −` la suma; D8-03 compara cada porcentaje con su esperado (DEC-044 (9)) | §9.2 |
| BLOQ-10 | [SUPUESTO-D-16]: despliegue monoinstitucional; parámetros y auditoría globales = ámbito del administrador; el SP lo comprueba (DEC-044 (10)) | §0, §4.2, §7.3 |
| BLOQ-11 | Lista exacta de líneas de manifiesto (DEC-042 ampliada por DEC-044 (11)); cada línea se regenera en el mismo commit que cambia el archivo, incluido el RED; `DB_CULM001_D_POST_FREEZE_MANIFEST` nace en el primer GREEN; golden path **1.6.0** (406 en `/realtime/stream`, `/realtime/emit` ADMINISTRADOR) | §12, §13.3 |
| OBS-1 | `IX_ArchivoSoporte_Solicitud` con `IF NOT EXISTS` y comentario corregido | §3.2 |
| OBS-2 | Se nombran `JpaProcedureExecutor`/`CanonicalProcedureResult`; `SlidingWindowRateLimiter` está en `infrastructure/adapter/primary/controller/filter/` | §1.4, §6.4 |
| OBS-3 | `ufn_validar_valor_parametro` sin ramas por literales de tipo | §4.2 |
| OBS-4 | `fechaModificacionEsperada` en UTC con milisegundos; prueba de ida y vuelta (`.007`) | §4.2, §4.3 |
| OBS-5 | D.4 usa `tipoIdentificacionId` | §5.3 |
| OBS-6 | `PUT /admin/estudiantes/{id}/identidad` no es diferible (HU156 "crea o corrige"); `CASE` de la línea 47 reemplazado por parámetro con rama de ámbito por perfil | §1.2, §5.2 |
| OBS-7 | Regla explícita entre `@soloAsistencia` (defecto 1) y `@soloAdministracion`; prueba D6-05 | §7.3 |
| OBS-8 | `N'A'` → `MATRICULA/ESTADO_INSCRITA` | §9.2 |
| OBS-9 | `PARAMETROS/GRUPOS_NO_EDITABLES` con todos los grupos "nunca" | §4.2 |
| OBS-10 | `@idTipoIdIdentificacion` al final de la firma | §6.3 |
| OBS-11 | La regla de fórmulas no aplica a `clave_inicial`; prueba | §6.2, §6.4 |
| OBS-12 | `password` de admisión fuera de `metadata` y de los logs del `GlobalExceptionHandler`; prueba | §5.3, §6.4 |
| OBS-13 | Rangos de líneas corregidos, consumidores Java listados y pruebas de B.2 que heredan la garantía SES-01 citadas por ID | §8 |
| OBS-14 | `PARAMETER_UPDATED` se mezcla después de C | §4.5, §13 |
| OBS-15 | Se reutilizan `PAGINACION/TAMANO_MAXIMO` y `PAG_001` (no se crea `GENERAL/TAMANO_PAGINA_MAXIMO`) | §1.4, §11 |
| OBS-16 | `infra.ps1` y `.env.example` aportan `MSSQL_SA_PASSWORD` | §11 F-TRX-011 |
| OBS-17 | `UnmappedRouteFilter` después de la autenticación; prueba de 401 anónimo | §11 F-EST-024 |
| OBS-18 | `AGENTS.md` no se edita; catálogos acotados → "no-se-corrige (propuesta)" a confirmar por el orquestador | §11 F-ADM-008 |
| OBS-19 | Deudas nuevas con número a reservar con el orquestador | §12 |
| OBS-20 | Objetos de la migración 28 listados; `usp_reintentar_notificacion_saliente` nombrado | §11.2 |

Además: el orden de prioridad pasa a **D.1, D.3, D.4, D.6, D.7 > D.2 > D.8 > D.5, D.9** y la lista de diferibles es la de DEC-044 (§1.2). F-ADM-026 espera a C (C añade el 409 `RCN_012` a `POST /admin/cierre-masivo`).

---

## 0. Supuestos y precisiones de diseño

DEC-042 aceptó D-02, D-03, D-08, D-12 y D-14 (este último acotado por DEC-044 (4)). DEC-044 (10) acepta D-16. Los demás se mantienen para la revisión.

| ID | Supuesto | Motivo |
| :--- | :--- | :--- |
| [SUPUESTO-D-01] | **Plazo de HU026B (DEC-040: "días calendario desde el fin de la sesión"):** la radicación se admite mientras `SYSUTCDATETIME() < límite`. El límite es la medianoche local (`TIEMPO/ZONA_HORARIA_SQLSERVER`) del día `fecha local de fin de la sesión + N + 1`, con `N = ASISTENCIA/DIAS_LIMITE_JUSTIFICACION`. Ejemplo: con N = 5, una sesión que termina el miércoles 2026-11-04 a las 08:00 de Bogotá se puede justificar hasta el lunes 2026-11-09 a las 23:59:59 de Bogotá | "Días calendario" entendidos como días completos del calendario local: una sesión que termina a las 23:30 no pierde un día. Prevalece DEC-040 sobre `DISENO_CAMBIO_COORDINADO.md` ("desde la fecha de la sesión") |
| [SUPUESTO-D-02] (DEC-042) | La relación 1:N de soportes por reclamo se realiza sobre la FK que ya existe, `ArchivoSoporte.solicitudRevisionAsistencia`: el índice único filtrado `UX_ArchivoSoporte_Solicitud` se reemplaza por el índice no único y no filtrado `IX_ArchivoSoporte_Solicitud`, y se publica `uv_soporte_reclamo`. No se crea la tabla `SoporteReclamo` | Una tabla puente duplicaría el vínculo de `ArchivoSoporte` y también obligaría a tocarla. Quitar el índice filtrado es la hipótesis de cierre de TD-059 |
| [SUPUESTO-D-03] (DEC-042) | Lista blanca, rango y presentación de los parámetros en la tabla satélite `CatalogoParametroEdicion` (1:1), no en columnas nuevas de `CatalogoParametro` | `DB_BASELINE_CONTRACT.md` §"Catalog Deploy" y el guard de 9 columnas |
| [SUPUESTO-D-04] | La auditoría de un cambio de parámetro es doble: `CambioParametro` en la misma transacción que el `UPDATE`, y el evento HTTP de `AuditoriaEvento` (D.6) con anterior y nuevo en `metadata` | El interceptor HTTP es de mejor esfuerzo |
| [SUPUESTO-D-05] | `motivo` obligatorio (10–500 caracteres) y concurrencia optimista con `fechaModificacionEsperada` | Igual que HU159; F-ADM-003 |
| [SUPUESTO-D-06] | Con el catálogo de parámetros del backend en `azure`, `PUT /admin/parametros/{id}` responde 409 `PRM_010` | Evita dos verdades; en el laboratorio rige DEC-018 (`sqlserver`) |
| [SUPUESTO-D-07] | HU156 exige un programa de la institución del administrador y crea `EstudiantePrograma`, sin matrícula en grupos | DEC-020: sin vínculo, el coordinador no lo ve |
| [SUPUESTO-D-08] (DEC-042) | `clave_inicial` en el CSV (obligatoria solo para personas nuevas, `PasswordRegistroRule`), procesada solo en memoria, nunca en logs, en respuestas ni en `metadata` | HU177 está en espera del equipo de seguridad |
| [SUPUESTO-D-09] | El CSV es transitorio (no se persiste): no pasa por ClamAV; se valida como texto UTF-8 con tamaño y filas limitados por parámetro | `AGENTS.md` §3.3.5 aplica a lo que se persiste en MinIO |
| [SUPUESTO-D-10] (DEC-042) | Creación fila por fila con el caso de uso individual, sin transacción global; repetir el archivo es idempotente | Resultado por fila; el IdP no entra en una transacción |
| [SUPUESTO-D-11] | Fila `YA_EXISTE` = misma persona (documento y correo) que ya tiene el rol destino en ese ámbito; documento y correo de personas distintas → `ERROR` (`CMA_008`) | Idempotencia sin ocultar conflictos |
| [SUPUESTO-D-12] (DEC-042) | F-ADM-024: decano ya existente → `buscarCuentaPorIdUsuario`; cuenta existente → 409 `DEC_020`; cuenta faltante → se crea, 201 con `cuentaReparada = true`; sin esa capacidad del proveedor → 409 | El 201 silencioso de hoy es la única vía de reintentar un aprovisionamiento fallido |
| [SUPUESTO-D-13] | D.8 conserva los nombres de columna (como DEC-024) y añade columnas de horas y porcentajes al final | Sin romper el contrato posicional |
| [SUPUESTO-D-14] (DEC-042, acotado por DEC-044 (4)) | En rutas **por grupo** (`/grupos/{id}/reportes/asistencia-excel`, `GET /decano/grupos/{id}`, `GET /decano/sesiones?idGrupo=`), un id inexistente y uno fuera de ámbito responden igual: 403 (DEC-025). Las mallas por plan **no** entran: siguen el 404 `PLA_002` congelado en B2 | Coherente con A/B2 en `/grupos/{id}/*` y con B2 en `/planes-estudio/{id}/*` |
| [SUPUESTO-D-15] | La jerarquía de la carga masiva vive en la tabla de catálogo `JerarquiaAltaUsuario (perfilEjecutor, perfilDestino)` con 3 filas: COORDINADOR→DOCENTE, DECANO→COORDINADOR, ADMINISTRADOR→DECANO | Cero datos quemados |
| **[SUPUESTO-D-16]** (DEC-044 (10)) | **El despliegue es monoinstitucional.** `CatalogoParametro` y `AuditoriaEvento` no tienen institución: los parámetros y la auditoría son de toda la instalación y coinciden con el ámbito del administrador (§3.8). Defensa: `usp_actualizar_parametro` y `usp_consultar_auditoria_eventos_paginado` comprueban que hay **exactamente una** `Institucion` activa; si hay más, responden `PRM_012`/error de ámbito hasta que exista parámetro por institución (deuda nueva, §12) | §3.8 limita al administrador a su institución; hoy hay una sola |

---

## 1. Alcance

### 1.1 Subpaquetes, prioridad y dependencias

| D.x | Contenido | HU / hallazgos | Prioridad (DEC-044) | Depende de |
| :--- | :--- | :--- | :--- | :--- |
| **D.1** | Plazo de excusas en `usp_radicar_solicitud_revision_asistencia(_v2)` (después de la reejecución idempotente) y fecha límite visible; fecha de radicación local | HU026B; F-EST-008, F-EST-S16 | 1 | A |
| **D.3** | `PUT /admin/parametros/{id}` con lista blanca, tipo, rango, reglas cruzadas, concurrencia, auditoría e invalidación; consulta paginada y legible | HU168; F-ADM-003, F-ADM-012 | 1 | A (la parte `PARAMETER_UPDATED`, después de C) |
| **D.4** | `POST /admin/estudiantes/admision`, `PUT /admin/estudiantes/{id}/identidad`, `GET /admin/programas`, `AsegurarCuentaIdentidadService` | HU156; F-ADM-004 | 1 | A |
| **D.6** | Auditoría de todas las mutaciones `/api/v1/admin/**`, `correlationId` expuesto, prueba de arquitectura | HU172 (DEC-022 §4); F-ADM-022, F-ADM-S13 | 1 | A |
| **D.7** | Retiro de `POST /api/v1/asistencias` y `REVOKE`/`DROP` de `usp_registrar_asistencia_estudiante_autonomo` | HU027 (TD-009); F-DOC-022 | 1 (si B.2 no está mezclado antes del 2026-11-11: queda en RED listo, TD-009 abierta y la ruta no se retira antes que B.2) | **B.2** (backend y BD) |
| **D.2** | Varios soportes; categoría persistida (TD-060); soporte obligatorio por categoría (HU014); TD-061; comprobación de TD-059 | HU015, HU014 | 2 | D.1 |
| **D.8** | Comparativas, tendencia y consolidado por horas | HU061, HU103, HU134, HU139; F-COO-007 | 3 | **B.2 y B2** |
| **D.5** | Carga masiva CSV de roles no estudiantes | HU171 | 4 (no diferible: §3.6) | D.4 y D.6 |
| **D.9** | Hallazgos medios y bajos (§11) | 27 hallazgos propios (los otros 8 `paquete-D` van a D.1, D.3, D.4, D.6 y D.7) más R-8 de A | 4 | D.6 y **B2** (D.9-a); C (D.9-c y F-ADM-026) |

**Fuera de D:** HU169, HU170 y HU177 quedan `[PENDIENTE]` "En espera de <equipo>" (§12). HU026C es de C; HU047 entró en B.1. Los fallos de línea base de `mvnw verify -Pintegration` son de la Fase 3, salvo los que D toque.

### 1.2 Diferibles (DEC-044)

Si falta tiempo antes del 2026-11-13 se difieren **solo** estas partes, y en este orden:

| Orden | Parte | Qué queda |
| :--- | :--- | :--- |
| 1 | D.9-c (SSE: `status`, `emit`, 406, comentario inicial) | F-TRX-016/019 vuelven a `abierto (diferido)`; el golden path se queda en 1.5.0 |
| 2 | D.9-d (docs e infra: F-ADM-020, F-TRX-011, F-TRX-020 en Infra, catálogo de F-EST-006) | Filas `abierto (diferido)` |
| 3 | Parte diferible de D.3: evento `PARAMETER_UPDATED` en el contrato de tiempo real y `GET /admin/parametros/{id}/cambios` con su pestaña | `CambioParametro` se escribe igual; la caché se invalida igual |
| 4 | D.8 entero | Comparativas, tendencia y consolidado siguen en unidades de sesión (nota "diferido" en el catálogo) |

Todo lo demás **no** es diferible: D.1, D.2, D.3 (salvo lo anterior), D.4 completo (incluido `PUT /admin/estudiantes/{id}/identidad`, sin el cual HU156 quedaría `[PARCIAL]`), D.5 completo (los tres roles), D.6 completo, D.7 (con la condición de B.2 de §1.1) y D.9-a/b. Si algo de esto no llega, CLOSURE lo declara como incumplimiento de §3.6 o de DEC-040, no como propuesta.

### 1.3 HUs cubiertas

| HU | Antes | Después de D |
| :--- | :--- | :--- |
| HU026B | `[PENDIENTE]` | Implementada (D.1) |
| HU015 | `[PARCIAL]` | Implementada (D.2) |
| HU014 | Fase 3, bloqueada por LB-004D | Categoría MED con soporte obligatorio en el mismo formulario (D.2) |
| HU168 | `[PARCIAL]` (PUT 501) | Implementada (D.3) |
| HU156 | `[PENDIENTE]` | Implementada, crea y corrige (D.4) |
| HU171 | `[PENDIENTE]` ("secretaría") | Implementada con la regla de DEC-040 (D.5) |
| HU172 | `[CERTIFICADA]` | Ampliada a las mutaciones del administrador (D.6) |
| HU027 | `POST /api/v1/asistencias` | `POST /asistencias/lote` y registro por toma (D.7) |
| HU061, HU103, HU134, HU139 | "diferido a D" | Por horas (D.8) |

Todas quedan "a certificar en la Fase 3".

### 1.4 Reglas comunes

**BD** (B §2.0): `SET NOCOUNT ON; SET XACT_ABORT ON;`; transacción propia si `@@TRANCOUNT = 0`, si no `SAVE TRANSACTION`; `CATCH` con `IF @@TRANCOUNT > 0 ROLLBACK` o rollback al savepoint; `XACT_STATE() = -1` → `THROW`. Paso 1 `usp_validar_id_correlacion_esta_presente_interno`; RBAC con `usp_validar_permiso_rbac_usuario_interno`; mensajes con `usp_obtener_mensaje_catalogo`; `SYS_001` + `ufn_obtener_detalle_error`. `@x IS NULL` explícito. **Nunca `INSERT … EXEC` sobre un SP que gestiona transacciones** (Msg 3915, DEC-036): la lógica compartida va a `usp_internal_*` con parámetros `OUTPUT`. Consultas `usp_consultar_*` sobre `uv_*` con `OFFSET/FETCH` y `COUNT(1) OVER()`; `@tamanoPagina` entre 1 y `PAGINACION/TAMANO_MAXIMO` (existe, 100) con el mensaje existente `PAG_001`. Ámbito dentro del SP. Sin literales de estado, tipo ni rol. Los `*_interno`/`usp_internal_*` nunca reciben `GRANT`.

**Backend:** `Controller → PrimaryPort → UseCaseImpl → SecondaryPort → adaptador` con `JpaProcedureExecutor`/`CanonicalProcedureResult` (`…/persistence/sqlserver/support/procedure/`); clasificación de códigos en `DbFailureClassifier`. Mensajes al cliente del catálogo. Listados en `ApiPageResponse<T>`. Rutas nuevas en `SecurityConfig` y `access-catalog.json` (§10). JaCoCo sin bajar del gate; casos de uso nuevos al 100 %.

**Frontend:** standalone, `OnPush`, `input()`/`output()`/`model()`, signals, sin `setInterval`, sin `bypassSecurityTrust*`, sin reglas de negocio en el cliente, tokens (`lint:tokens`), móvil 375 × 812, `PaginationComponent`.

**Pruebas:** RED antes del código, cada prueba falla por la causa esperada. Una prueba existente solo cambia si un cambio de contrato de este documento la invalida, y el commit cita la sección.

---

## 2. D.1 — Plazo de excusas (HU026B)

### 2.1 Alcance

La radicación fuera de plazo se rechaza **en el SP** (única regla). El backend solo mapea el error y entrega la fecha límite, y el frontend la muestra. Corrige también la fecha de radicación en UTC (F-EST-S16).

### 2.2 BD

| Objeto | Cambio |
| :--- | :--- |
| `ufn_calcular_fecha_limite_justificacion` (**nueva**) | `(@fechaHoraFinSesionUtc DATETIME2(7)) RETURNS DATETIME2(7)`. `N = ufn_obtener_parametro_int(NULL,'ASISTENCIA','DIAS_LIMITE_JUSTIFICACION')`, `@tz = ufn_obtener_parametro_texto(NULL,'TIEMPO','ZONA_HORARIA_SQLSERVER')`; `fechaLocal = CAST((@fin AT TIME ZONE 'UTC') AT TIME ZONE @tz AS DATE)`; devuelve `DATEADD(DAY, N + 1, fechaLocal)` a las 00:00 locales convertido a UTC (límite **exclusivo**). `NULL` si falta `N` o `@tz`, si `N < 0` o si `@fin IS NULL` |
| `usp_internal_validar_plazo_justificacion` (**nuevo**) | `(@idSesion, @idCorrelacion, @fechaLimiteUtc DATETIME2(7) OUTPUT, @mensajeUsuarioResultado OUTPUT, @mensajeTecnicoResultado OUTPUT, @estadoResultado BIT OUTPUT)`. Función `NULL` → `REV_025`; `SYSUTCDATETIME() >= @fechaLimiteUtc` → `REV_020` con la fecha local como parámetro. Sin escrituras |
| `usp_radicar_solicitud_revision_asistencia_v2` (LB-004D, **modificado**) | Orden (DEC-044 (3)): correlación → RBAC → propiedad y asistencia → **reejecución idempotente por correlación** (bloque actual: "reintento con la misma correlación tras un éxito ⇒ éxito idempotente") → **plazo** → resto. Así, un reintento legítimo después del vencimiento sigue devolviendo el éxito original sin escribir. `SolicitudRevisionAsistencia.fecha` pasa a la fecha local (`CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE)`). Firma y resultset sin cambio. En D.2 este cuerpo pasa al interno compartido (§3.2) |
| `usp_radicar_solicitud_revision_asistencia` (v1, sin consumidor en el backend, **modificado**) | El mismo paso de plazo después de propiedad y asistencia (v1 no tiene reejecución idempotente) y la fecha local |
| `uv_sesion_estudiante_reclamo` (**vista nueva**, DEC-044 (2)) | Sobre `uv_sesion_v2` + `uv_sesion_estado` (B.1) + `uv_estudiante_grupo`: `idSesion, idGrupo, idEstudianteGrupo, idEstudiante, numero, nombre, fechaHoraInicio, fechaHoraFin, estaCancelada, fechaLimiteJustificacionUtc (= ufn_calcular_fecha_limite_justificacion(fechaHoraFin)), plazoJustificacionVigente BIT (= SYSUTCDATETIME() < límite)`. **`uv_sesion` (congelada en `DB_DEVELOP_FREEZE_MANIFEST`) no se toca** |
| `usp_consultar_sesiones_materia_estudiante` (**nuevo**, consulta) | `(@idUsuarioEjecutor, @idCorrelacion, @idMateria UNIQUEIDENTIFIER, @numeroPagina INT, @tamanoPagina INT)`. RBAC ESTUDIANTE; ámbito en el SP: solo matrículas del ejecutor con estado `MATRICULA/ESTADO_INSCRITA` en el grupo de `@idMateria` (misma semántica de `materiaId` que la HQL actual, que lo resuelve contra `UvGrupoEntity`; la prueba de paridad D1-10 lo fija). Devuelve las columnas que hoy entrega la HQL de `SesionMateriaEstudianteJpaRepository` más `fechaLimiteJustificacionUtc` y `plazoJustificacionVigente`, y `totalRegistros`. Orden `fechaHoraInicio` |
| Mensajes (`51_culm001_d1_mensajes.sql`) | `REV_020` usuario "El plazo para justificar esta inasistencia venció el {}." · técnico "HU026B: instante {} >= límite {} (ASISTENCIA/DIAS_LIMITE_JUSTIFICACION={})." `REV_025` usuario "No es posible validar el plazo de justificación en este momento." · técnico "HU026B: falta ASISTENCIA/DIAS_LIMITE_JUSTIFICACION o TIEMPO/ZONA_HORARIA_SQLSERVER." |
| Permisos `rol_asistencias_runtime_culm001_d1.sql` | `GRANT EXECUTE` a `usp_consultar_sesiones_materia_estudiante`; `GRANT SELECT` a `uv_sesion_estudiante_reclamo` si el bucle `uv_*` no la cubre (`test_public_objects.sql`) |
| Migración `20_culm001_d1_plazo_justificacion_up/down.sql` | `up`: función, interno, vista, SP de consulta, v1, v2, mensajes. `down`: §14.2 (aborta si existe v3); restaura v1 y v2 (texto literal), `DROP` de SP de consulta, vista, interno y función; borra `REV_020`/`REV_025` |
| Manifiesto LB-004D | La línea de v2 se regenera **en el mismo commit** que cambia v2 (§12) |

**Pruebas RED** `DB:test/test_culm001_d1_plazo_justificacion.sql` (sesiones relativas a `SYSUTCDATETIME()` en hora local):

| ID | Caso | Esperado |
| :--- | :--- | :--- |
| D1-01 | Falta en una sesión que terminó hace 2 días | Éxito; solicitud creada |
| D1-02 | Sesión cuyo día local `+N` es hoy | Se admite |
| D1-03 | Sesión cuyo día local `+N+1` ya empezó | `REV_020`; 0 filas nuevas en `SolicitudRevisionAsistencia`; ningún `ArchivoSoporte` a `ATTACHED`; `@@TRANCOUNT = 0` |
| D1-04 | Parámetro en 1 dentro de la transacción de prueba | El límite cambia |
| D1-05 | v1 con sesión vencida | `REV_020` |
| D1-06 | Sesión de otro estudiante y vencida | Error de propiedad existente, no `REV_020` |
| D1-07 | Fin a las 23:30 locales, N = 5 | Límite = medianoche local del día +6 |
| D1-08 | Parámetro ausente | `REV_025`, sin escritura |
| D1-09 | Fecha de radicación | Fecha local de Bogotá |
| D1-10 | `usp_consultar_sesiones_materia_estudiante` | Mismas filas y columnas que la HQL actual sobre el fixture (paridad), más las dos columnas nuevas; materia ajena → 0 filas o error de ámbito según el contrato existente; paginación inválida → `PAG_001` |
| D1-11 | `up → down → up` de la 20 | Idempotente |
| **D1-12** | Radicación con éxito; se vence el plazo (sesión movida en el fixture); **reintento con la misma correlación** | Éxito idempotente; 0 filas nuevas (DEC-044 (3)) |

### 2.3 Backend

- `REV_020` → 409 `ERR_PLAZO_JUSTIFICACION_VENCIDO`; `REV_025` → 500 `ERR_CONFIGURACION_PLAZO_JUSTIFICACION` (`DbFailureClassifier`). Java no recalcula el plazo (se corrige la fila del catálogo que lo atribuía al caso de uso).
- `GET /api/v1/estudiante/materias/{materiaId}/sesiones` (ESTUDIANTE): la HQL de `SesionMateriaEstudianteJpaRepository` se sustituye por el adaptador del SP nuevo (respuesta con la misma forma; cada sesión añade `fechaLimiteJustificacionUtc` ISO-8601 UTC o `null`, y `plazoJustificacionVigente`). Parámetros opcionales `pagina` (1) y `tamano` (`PAGINACION/TAMANO_MAXIMO`); la respuesta conserva su sobre actual (una materia tiene menos sesiones que el máximo; si `totalRegistros` lo supera, se registra un WARN con `correlationId` y se devuelve la primera página: deuda a revisar en CLOSURE).
- Pruebas RED: `SolicitarRevisionAsistenciaUseCaseImplTest` (`REV_020` → `ConflictException` con el mensaje del catálogo), `AsistenciaControllerTest` (409 con `code`/`message`), `DbFailureClassifierReclamoRevisionTest` (`REV_020`/`REV_025`), adaptador nuevo (mapeo posicional, `null`), prueba de que `SesionMateriaEstudianteJpaRepository` ya no usa HQL sobre `UvSesionEntity` para este caso.

### 2.4 Frontend

- `student-claim-form.component.ts`: "Puedes justificar hasta el <fecha y hora local>" desde `fechaLimiteJustificacionUtc` (formato con `core/time`); un 409 muestra el `message` del backend y desactiva "Enviar".
- Detalle de la materia: "Justificar" desactivado si `plazoJustificacionVigente === false`, con "Plazo vencido" y la fecha.
- Specs RED: fecha visible, 409 con el mensaje del backend, sin cálculo local, acción desactivada; móvil 375 px.

### 2.5 Docs y riesgos

`HU-CATALOG.md` HU026B implementada; F-EST-008 y F-EST-S16 → `corregido`. Riesgos: filas antiguas con `fecha` en UTC (sin migración; se documenta en el addendum); un cambio del parámetro aplica de inmediato a radicaciones nuevas.

---

## 3. D.2 — Varios soportes, categoría persistida y soporte obligatorio (HU015, HU014, TD-060)

### 3.1 Alcance

De 0 a `ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO` soportes por reclamo. Subida y descarga sin cambio: `POST /api/v1/archivos/subir` (ClamAV `INSTREAM` → MinIO → `usp_registrar_archivo_soporte`, `DRAFT`) y `GET /api/v1/archivos/{fileId}` (`usp_consultar_archivo_soporte_autorizado`). Categoría con FK (TD-060). MED, ACA y LAB exigen soporte. HU014 = MED en el mismo formulario.

### 3.2 BD

**DDL** (idempotente; FK en `zz_foreign_keys.sql`):

```sql
-- SolicitudRevisionAsistencia.sql
IF COL_LENGTH('dbo.SolicitudRevisionAsistencia','categoriaJustificacion') IS NULL
    ALTER TABLE dbo.SolicitudRevisionAsistencia ADD [categoriaJustificacion] uniqueidentifier NULL;   -- sin backfill
-- zz_foreign_keys.sql: FK_SolicitudRevisionAsistencia_CategoriaJustificacion → CategoriaJustificacion(id);
--                      IX_SolicitudRevisionAsistencia_Categoria (categoriaJustificacion)
-- CategoriaJustificacion.sql
IF COL_LENGTH('dbo.CategoriaJustificacion','requiereSoporte') IS NULL
    ALTER TABLE dbo.CategoriaJustificacion ADD [requiereSoporte] bit NOT NULL
        CONSTRAINT DF_CategoriaJustificacion_requiereSoporte DEFAULT 0;
-- ArchivoSoporte.sql (LB-004D) — [SUPUESTO-D-02]. Comentario nuevo: "Varios soportes por solicitud (hasta
-- ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO); un fileId pertenece a una sola solicitud por la PK."
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ArchivoSoporte') AND name = 'UX_ArchivoSoporte_Solicitud')
    DROP INDEX UX_ArchivoSoporte_Solicitud ON dbo.ArchivoSoporte;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ArchivoSoporte') AND name = 'IX_ArchivoSoporte_Solicitud')
    CREATE NONCLUSTERED INDEX IX_ArchivoSoporte_Solicitud ON dbo.ArchivoSoporte (solicitudRevisionAsistencia)
        INCLUDE (estado, nombreOriginal, tipoContenido, tamanioBytes, fechaAdjuncionUtc);   -- no filtrado (TD-059)
```

**Vistas:** `uv_soporte_reclamo` (`idSolicitud, idArchivo, nombreOriginal, tipoContenido, tamanioBytes, fechaAdjuncionUtc, orden = ROW_NUMBER() OVER (PARTITION BY solicitud ORDER BY fechaAdjuncionUtc, id)`; solo estado `ARCHIVO/ESTADO_ADJUNTO`). `uv_categoria_justificacion` + `requiereSoporte`. `uv_solicitud_revision_asistencia` + `idCategoriaJustificacion, codigoCategoria, nombreCategoria, totalSoportes`.

**SP** (DEC-044 (3)):

| SP | Firma / regla |
| :--- | :--- |
| `usp_internal_radicar_solicitud_revision` (**nuevo**, interno, sin `GRANT`) | `(@idEstudiante, @idSesion, @categoria NVARCHAR(50), @justificacion NVARCHAR(MAX), @idsArchivoSoporte NVARCHAR(MAX) /* JSON ["guid",...] o NULL */, @idCorrelacion, @idUsuarioEjecutor, @idSolicitudRevision UNIQUEIDENTIFIER OUTPUT, @totalSoportes INT OUTPUT, @mensajeUsuarioResultado NVARCHAR(4000) OUTPUT, @mensajeTecnicoResultado NVARCHAR(4000) OUTPUT, @estadoResultado BIT OUTPUT)`. Contiene **toda** la lógica que hoy tiene v2 (con el paso de D.1) más la de varios soportes. Orden: correlación → RBAC ESTUDIANTE → propiedad y asistencia → **reejecución idempotente por correlación** (devuelve el `idSolicitudRevision` y `totalSoportes` originales sin escribir) → plazo (D.1) → categoría por `codigo` o por `nombre` (`REV_021`) → JSON válido y GUID distintos (`REV_024`) → cantidad ≤ máximo (`REV_023`) → `requiereSoporte` sin soportes (`REV_022`) → cada archivo `WITH (UPDLOCK, HOLDLOCK)` en orden de `id`: dueño = ejecutor y estado `ARCHIVO/ESTADO_BORRADOR` (si no, `ARC_001`/`ARC_00x` existentes) → `INSERT SolicitudRevisionAsistencia` (categoría y fecha local) → `UPDATE ArchivoSoporte` a `ARCHIVO/ESTADO_ADJUNTO` para todos → verificación de N. Gestiona su savepoint; no emite resultset |
| `usp_radicar_solicitud_revision_asistencia_v3` (**nuevo**, comando) | `(@idEstudiante, @idSesion, @categoria, @justificacion, @idsArchivoSoporte NVARCHAR(MAX) = NULL, @idCorrelacion, @idUsuarioEjecutor)`. Transacción propia o savepoint, llama al interno y emite **su** resultset: tupla + `idSolicitudRevision, totalSoportes` |
| `usp_radicar_solicitud_revision_asistencia_v2` (LB-004D, **modificado**) | Transacción propia o savepoint, arma `["@idArchivoSoporte"]` (o `NULL`), llama al **interno** (no a v3) y emite **su** resultset de 4 columnas (firma y resultset sin cambio). Ahora guarda la categoría y exige soporte según la categoría |
| `usp_consultar_solicitudes_revision_docente` (R2, LB-004D) | Columnas al final `codigoCategoria, nombreCategoria, totalSoportes`; literal `'ATTACHED'` → parámetro (TD-061) |
| `usp_consultar_detalle_solicitud_revision_docente`, `usp_consultar_solicitudes_revision_estudiante` | Columnas al final `codigoCategoria, nombreCategoria, soportesJson` (`FOR JSON PATH` sobre `uv_soporte_reclamo`); el soporte único actual se conserva (el primero) |
| `usp_consultar_archivo_soporte_autorizado` (LB-004D) | Solo TD-061: literales → parámetros |
| `usp_consultar_configuracion_reclamos` (**nuevo**, consulta de una fila) | `maximoSoportes, tamanioMaximoBytes, tiposPermitidos, limiteSubidasPorMinuto, diasLimiteJustificacion`; RBAC ESTUDIANTE o DOCENTE |

**Semillas** (`52_culm001_d2_*`): parámetros `ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO = 3` y `ARCHIVO/ESTADO_BORRADOR = DRAFT` (patrón `29_*`, sin pisar `valor`), con la fila de edición de `MAXIMO_SOPORTES_POR_RECLAMO` ([1, 10]) si existe `CatalogoParametroEdicion`; `requiereSoporte = 1` para MED, ACA y LAB; mensajes `REV_021` "La categoría de justificación no es válida.", `REV_022` "La categoría «{}» exige adjuntar al menos un soporte.", `REV_023` "Puedes adjuntar como máximo {} soportes.", `REV_024` "Un mismo soporte no se puede adjuntar dos veces.", con sus técnicos.
**Permisos** `rol_asistencias_runtime_culm001_d2.sql`: v3, `usp_consultar_configuracion_reclamos`; `uv_soporte_reclamo` si el bucle no la cubre.
**Migración** `21_culm001_d2_soportes_categoria_up/down.sql`. `up`: DDL, vistas, SP, semillas. **`down`** (DEC-044 (8), patrón A.1/DEC-010):
1. Aborta (`THROW 50021`) si alguna solicitud tiene más de un `ATTACHED` y no se pasó `:setvar CONFIRMAR_COLAPSO_SOPORTES 1`.
2. Copia `(id, categoriaJustificacion)` de las solicitudes con categoría a `zz_archivo_SolicitudRevisionCategoria_culm001_d2` (sin FK ni `GRANT`; `IF OBJECT_ID … IS NULL` para crearla; `MERGE` por `id`).
3. Con confirmación, copia `(idArchivo, idSolicitud, fechaAdjuncionUtc, idCorrelacionAdjuncion)` de los soportes que se colapsan a `zz_archivo_SoporteColapsado_culm001_d2`; deja `ATTACHED` el de menor `fechaAdjuncionUtc` y pasa los demás a `ORPHAN` con `solicitudRevisionAsistencia`, `fechaAdjuncionUtc` e `idCorrelacionAdjuncion` en `NULL` (`CK_ArchivoSoporte_EstadoVinculo`).
4. Recrea `UX_ArchivoSoporte_Solicitud`, quita `IX_ArchivoSoporte_Solicitud`, FK, índice y columna de categoría, y `requiereSoporte`.
5. Restaura el texto anterior (literal) de v2, R2, detalle, lista del estudiante, archivo autorizado y vistas; `DROP` de v3, del interno, de la configuración y de `uv_soporte_reclamo`.
El `up` siguiente **restaura** las categorías desde `zz_archivo_SolicitudRevisionCategoria_culm001_d2` y los vínculos colapsados desde `zz_archivo_SoporteColapsado_culm001_d2` (solo si el archivo sigue `ORPHAN`), y no borra las tablas de archivo.

**Pruebas RED** `DB:test/test_culm001_d2_soportes_categoria.sql` (+ `test_lb004d_concurrency.ps1` ampliado):

| ID | Caso | Esperado |
| :--- | :--- | :--- |
| D2-01 | v3 con 3 soportes `DRAFT` propios, categoría CAL | 3 `ATTACHED` en la misma solicitud; `totalSoportes = 3` |
| D2-02 | 4 soportes con máximo 3 | `REV_023`; 0 escrituras |
| D2-03 | GUID repetido | `REV_024` |
| D2-04 | Soporte de otro usuario / ya `ATTACHED` / `ORPHAN` / inexistente | `ARC_00x` / `ARC_001`; 0 escrituras |
| D2-05 | MED, ACA, LAB sin soportes / CAL, FMA, OTR sin soportes | `REV_022` / éxito |
| D2-06 | Categoría por `codigo` y por `nombre` | Misma FK |
| D2-07 | Categoría inexistente | `REV_021` |
| D2-08 | v2 con un soporte y MED | Igual que v3 con uno; resultset de 4 columnas |
| D2-09 | Descarga de cada uno de los N | Dueño y docente titular sí; otro docente y otro estudiante no |
| D2-10 | R2, detalle y lista del estudiante | Categoría, `totalSoportes`, `soportesJson`; sin literales `ATTACHED`/`DRAFT` en los 3 SP de TD-061 (`sys.sql_modules`) |
| D2-11 | Dos radicaciones concurrentes con el mismo `fileId` | Una adjunta, otra `ARC_001`; sin deadlock |
| D2-12 | Plazo vencido con soportes | `REV_020`; los soportes siguen `DRAFT` |
| D2-13 | `up → down (con confirmación) → up` | Idempotente; sin confirmación aborta; tras el segundo `up` las categorías y los vínculos se recuperan del archivo |
| D2-15 | v3: éxito con 2 soportes, plazo vencido, **reintento con la misma correlación** | Éxito idempotente, `totalSoportes = 2`, 0 filas nuevas, ningún soporte adjuntado dos veces |
| D2-16 | Ningún SP de D.2 usa `INSERT … EXEC` sobre v2/v3/interno | Búsqueda en `sys.sql_modules` |

**Comprobación de TD-059 (no es prueba del gate):** `BEGIN TRAN; DELETE FROM dbo.SolicitudRevisionAsistencia WHERE id = @x; ROLLBACK;` con la FK habilitada. Si funciona, entra como D2-14 y TD-059 se cierra; si no, sigue abierta con la evidencia.

**Pruebas existentes que cambian por contrato:** `test_lb004d_support_binding.sql` (la aserción de la línea 112 sobre `UX_ArchivoSoporte_Solicitud` y "a lo sumo un soporte" pasan a `IX_ArchivoSoporte_Solicitud` no único y "a lo sumo `MAXIMO_SOPORTES_POR_RECLAMO`"); las pruebas que radican sin archivo con MED pasan a CAL. Su línea del manifiesto se regenera en el mismo commit RED (§12).

### 3.3 Backend

| Endpoint | Cambio |
| :--- | :--- |
| `POST /api/v1/asistencias/revisiones` (ESTUDIANTE) | Cuerpo: `categoria` (código o nombre), `justificacion`, `soporteArchivoIds: UUID[]` (0..N). `soporteArchivoId` (legado) = lista de uno; los dos a la vez → 400 `FIELD_INVALID`. 202 sin cambio. 400 (`REV_021`–`REV_024`), 409 (`REV_020`, `ARC_001`) |
| `GET /api/v1/configuracion/reclamos` (**nuevo**; ESTUDIANTE, DOCENTE) | `ApiDataResponse<ConfiguracionReclamosDTO>{maximoSoportes, tamanioMaximoBytes, tiposPermitidos[], limiteSubidasPorMinuto, diasLimiteJustificacion}` |
| `GET /api/v1/categorias-justificacion` | + `requiereSoporte` |
| Detalle del docente (HU036) y `GET /api/v1/estudiante/reclamos` | + `categoria {codigo, nombre}` y `soportes[{fileId, nombre, tipoContenido, tamanioBytes}]`; el soporte único queda `@Deprecated` una versión |

Capas: DTOs con `List<UUID> soportes`; el adaptador llama a v3 con el JSON (`ObjectMapper`); `ConsultarConfiguracionReclamosInputPort` + caso de uso + `ConfiguracionReclamosQueryPort` + adaptador.

**Pruebas RED** (además de validador, caso de uso, adaptador, mappers, controlador y `SqlStoredProcedureContractIT` para v3 y configuración), DEC-044 (7):
- **ClamAV con varios archivos** (`ArchivoControllerTest`/IT con el doble de ClamAV): secuencia de 3 subidas en la que la segunda lleva la firma EICAR → rechazada con el código existente del antivirus y **sin** `fileId` ni fila en `ArchivoSoporte`; la primera y la tercera quedan `DRAFT`; radicar con los dos `fileId` válidos → 202.
- **Límite de subidas por minuto**: `ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO` subidas seguidas del mismo estudiante → 201; la siguiente en el mismo minuto → 429 con el código existente; otro estudiante no queda afectado.
- Radicar con un `fileId` inexistente u `ORPHAN` → `ARC_001`, sin escrituras.
- `GET /configuracion/reclamos`: `tamanioMaximoBytes` ≤ límite multipart de Spring (`spring.servlet.multipart.max-file-size`).

### 3.4 Frontend

- `student-claim-form`: varios adjuntos (`archivos = input<SoporteAdjuntoItem[]>()`, salidas `adjuntar`/`quitar`); límite, tipos y límite por minuto desde `GET /configuracion/reclamos`; "Soporte obligatorio" según `requiereSoporte`; ayuda de MED desde la `descripcion` de la categoría.
- `student-courses` (contenedor): sube cada archivo con el servicio actual; estado por archivo (subiendo, listo, rechazado con el `message` del backend).
- Docente (`teacher-claims`, detalle): categoría y lista de soportes con descarga por la API.
- **Specs RED** (DEC-044 (7)): archivo infectado y 429 mostrados **en ese archivo** con el `message` del backend, sin afectar a los otros; "Enviar" desactivado mientras haya subidas en curso o falte un soporte obligatorio; la lista enviada nunca contiene ids de subidas fallidas; varios adjuntos, quitar, límite, detalle del docente con N soportes; móvil 375 px.

### 3.5 Docs y riesgos

HU015 y HU014 implementadas; TD-060 y TD-061 cerradas; TD-059 según la comprobación. Riesgos: soportes `DRAFT` abandonados (limpieza fuera de D, deuda nueva); contrato posicional de R2 (columnas solo al final, prueba de contrato).

---

## 4. D.3 — Parámetros editables (HU168)

### 4.1 Alcance

El administrador ve los parámetros de negocio legibles, agrupados y filtrables, y edita solo la lista blanca con validación de tipo, rango y reglas cruzadas, motivo, concurrencia optimista, auditoría e invalidación. `RED/*` y `TIEMPO/*` nunca. Ámbito: [SUPUESTO-D-16].

### 4.2 BD

**Tablas nuevas:**

```sql
CREATE TABLE dbo.CatalogoParametroEdicion (            -- [SUPUESTO-D-03]
    parametro                 uniqueidentifier NOT NULL CONSTRAINT PK_CatalogoParametroEdicion PRIMARY KEY, -- FK → CatalogoParametro(id)
    esEditable                bit              NOT NULL CONSTRAINT DF_CPE_esEditable DEFAULT 0,
    valorMinimo               decimal(19,4)    NULL,
    valorMaximo               decimal(19,4)    NULL,
    valoresPermitidos         nvarchar(500)    NULL,    -- lista separada por comas
    parametroDebeSerMenorQue  uniqueidentifier NULL,    -- FK → CatalogoParametro(id): regla cruzada estricta
    etiqueta                  nvarchar(120)    NOT NULL,
    descripcion               nvarchar(500)    NOT NULL,
    unidad                    nvarchar(30)     NULL,
    categoriaVisual           nvarchar(60)     NOT NULL,
    orden                     smallint         NOT NULL CONSTRAINT DF_CPE_orden DEFAULT 0,
    CONSTRAINT CK_CPE_Rango CHECK (valorMinimo IS NULL OR valorMaximo IS NULL OR valorMinimo <= valorMaximo),
    CONSTRAINT CK_CPE_NoAutoReferencia CHECK (parametroDebeSerMenorQue IS NULL OR parametroDebeSerMenorQue <> parametro)
);
CREATE TABLE dbo.CambioParametro (                     -- [SUPUESTO-D-04]
    id uniqueidentifier NOT NULL CONSTRAINT PK_CambioParametro PRIMARY KEY,
    parametro uniqueidentifier NOT NULL,                -- FK → CatalogoParametro(id)
    valorAnterior nvarchar(4000) NOT NULL, valorNuevo nvarchar(4000) NOT NULL,
    motivo nvarchar(500) NOT NULL, idUsuarioEjecutor uniqueidentifier NOT NULL,
    idCorrelacion uniqueidentifier NOT NULL, fechaCambioUtc datetime2(7) NOT NULL
);
CREATE INDEX IX_CambioParametro_Parametro_Fecha ON dbo.CambioParametro (parametro, fechaCambioUtc DESC);
```

**Objetos:**

| Objeto | Definición |
| :--- | :--- |
| `ufn_validar_valor_parametro(@tipoDato VARCHAR(20), @valor NVARCHAR(4000), @min, @max, @permitidos) RETURNS VARCHAR(20)` | Sin ramas por literales de tipo (OBS-3): (1) si hay `valoresPermitidos` → pertenencia exacta o `PRM_006`; (2) si no, y `@tipoDato` está en `PARAMETROS/TIPOS_NUMERICOS` (`INT,DECIMAL`) → `TRY_CONVERT(DECIMAL(19,4))` no nulo (`PRM_004`), sin parte decimal cuando el tipo está en `PARAMETROS/TIPOS_ENTEROS` (`INT`) (`PRM_004`), dentro de `[min, max]` (`PRM_005`); (3) si no → longitud 1–4000 (`PRM_004`). Devuelve `NULL` si cumple |
| `uv_parametro_edicion` | `uv_parametro` LEFT JOIN `CatalogoParametroEdicion` + último cambio (`OUTER APPLY TOP 1` + `uv_usuario`): `id, grupo, clave, valor, valorDefecto, tipoDato, esEditable, valorMinimo, valorMaximo, valoresPermitidos, etiqueta, descripcion, unidad, categoriaVisual, orden, fechaModificacion, fechaUltimoCambioUtc, nombreUltimoActor, esGrupoProtegido` |
| `usp_consultar_parametros_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @grupo = NULL, @texto = NULL, @soloEditables BIT = 1)`; RBAC ADMINISTRADOR; comprobación de [SUPUESTO-D-16]; orden `categoriaVisual, orden, clave` |
| `usp_actualizar_parametro` | `(@idParametro, @valor NVARCHAR(4000), @fechaModificacionEsperada DATETIME, @motivo NVARCHAR(500), @idCorrelacion, @idUsuarioEjecutor)`. Pasos: correlación → RBAC ADMINISTRADOR → **una sola `Institucion` activa** ([SUPUESTO-D-16]; si no, `PRM_012`) → motivo con al menos `PARAMETROS/LONGITUD_MINIMA_MOTIVO` caracteres tras `TRIM` (`PRM_009`) → `CatalogoParametro WITH (UPDLOCK, HOLDLOCK)` por id, activo (`PRM_002`) → grupo en `PARAMETROS/GRUPOS_NO_EDITABLES` o sin fila editable (`PRM_003`) → `fechaModificacion <> @fechaModificacionEsperada` (`PRM_008`; comparación exacta en `DATETIME`) → `ufn_validar_valor_parametro` → reglas cruzadas en las dos direcciones (`PRM_007`) → valor igual (`PRM_011`, éxito sin escritura) → `UPDATE valor, fechaModificacion = SYSUTCDATETIME()` + `INSERT CambioParametro`. Salida: tupla + `idParametro, grupo, clave, valorAnterior, valorNuevo, fechaModificacion` |
| `usp_consultar_cambios_parametro_paginado` (diferible) | `(@idUsuarioEjecutor, @idCorrelacion, @idParametro, @numeroPagina, @tamanoPagina)` |

**Lista blanca inicial** (semilla `53_culm001_d3_parametro_edicion.sql`, MERGE por `(grupo, clave)` contra `CatalogoParametro`; solo inserta filas de parámetros que existen):

| Grupo / clave | Tipo | Editable | Rango / valores | Unidad | Regla / nota |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ASISTENCIA/TOLERANCIA_MINUTOS | INT | sí | [0, 60] | minutos | |
| ASISTENCIA/MARGEN_RETARDO_MINUTOS | INT | sí | [0, 120] | minutos | |
| ASISTENCIA/DIAS_LIMITE_JUSTIFICACION | INT | sí | [1, 30] | días | D.1 |
| ASISTENCIA/UMBRAL_ALERTA_ADVERTENCIA | DECIMAL | sí | [1, 99] | % | `< UMBRAL_ALERTA_PERDIDA` |
| ASISTENCIA/UMBRAL_ALERTA_PERDIDA | DECIMAL | sí | [1, 100] | % | |
| ASISTENCIA/CODIGO_RAZON_* (B.2) | — | no | — | — | Técnico |
| MATRICULA_QR/ROTACION_SEGUNDOS · TOLERANCIA_SEGUNDOS · DURACION_MAXIMA_MINUTOS | INT | sí | [15, 300] · [0, 300] · [5, 240] | s · s · min | |
| MATRICULA_QR/HABILITADA | BOOLEAN | sí | true,false | — | |
| MATRICULA_QR/LIMITE_IP_POR_MINUTO · LIMITE_REGISTROS_TOKEN_POR_MINUTO | INT | sí | [5, 1000] · [1, 200] | por minuto | |
| MATRICULA_QR/ESTADO_*, LOTE_ROTACION, URL_BASE_FRONTEND | — | no | — | — | Técnico / despliegue |
| ASISTENCIA_QR/HABILITADA | BOOLEAN | sí | true,false | — | |
| ASISTENCIA_QR/ROTACION_SEGUNDOS · TOLERANCIA_SEGUNDOS | INT | sí | [15, 300] · [0, 300] | s | |
| ASISTENCIA_QR/LIMITE_IP_POR_MINUTO · LIMITE_FALLIDOS_IP_POR_MINUTO · LIMITE_TOKEN_POR_MINUTO · LIMITE_ESTUDIANTE_POR_MINUTO | INT | sí | [5, 1000] · [50, 5000] · [10, 2000] · [1, 60] | por minuto | |
| ASISTENCIA_QR/LOTE_ROTACION, URL_BASE_FRONTEND | — | no | — | — | |
| FESTIVOS/HABILITADO | BOOLEAN | sí | true,false | — | |
| FESTIVOS/PROVEEDOR_PRINCIPAL | STRING | sí | CALENDARIOS_NACIONALES,FERIADOS_IO,CALCULO_LOCAL | — | |
| FESTIVOS/TIMEOUT_SEGUNDOS · ANIOS_ADELANTE | INT | sí | [1, 60] · [0, 3] | s · años | |
| FESTIVOS/MINIMO_POR_ANIO · MAXIMO_POR_ANIO | INT | sí | [10, 30] · [10, 40] | festivos | `MINIMO < MAXIMO` |
| FESTIVOS/URL_*, NOMBRE_SECRETO_*, FUENTES_VALIDAS, ORDEN_RESPALDO, ANIO_MINIMO, ANIO_MAXIMO, PREFIJO_MOTIVO_CANCELACION, ATRIBUCION_* | — | no | — | — | URLs y secretos (SSRF), constantes, atribución |
| ARCHIVO/TAMANIO_MAXIMO_BYTES | INT | sí | [262144, 5242880] | bytes | No supera el límite multipart |
| ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO | INT | sí | [1, 60] | por minuto | |
| ARCHIVOS/MAXIMO_SOPORTES_POR_RECLAMO (D.2) | INT | sí | [1, 10] | soportes | Fila insertada por la semilla 52 |
| ARCHIVO/ESTADO_* | — | no | — | — | |
| CARGA_MASIVA/MAXIMO_FILAS · LIMITE_POR_MINUTO · TAMANIO_MAXIMO_BYTES (D.5) | INT | sí | [1, 500] · [1, 20] · [10240, 2097152] | filas · por minuto · bytes | Filas insertadas por la semilla 55 |
| `RED`, `TIEMPO`, `GENERAL`, `REGISTRO`, `IDENTIDAD`, `RECLAMO`, `TOMA_ASISTENCIA`, `PARAMETROS`, `AUDITORIA`, `PAGINACION`, `MATRICULA` | — | **nunca** | — | — | **Todos** en `PARAMETROS/GRUPOS_NO_EDITABLES` (OBS-9) |

**Parámetros** (`53_culm001_d3_parametros.sql`; ninguno editable): `PARAMETROS/GRUPOS_NO_EDITABLES = RED,TIEMPO,GENERAL,REGISTRO,IDENTIDAD,RECLAMO,TOMA_ASISTENCIA,PARAMETROS,AUDITORIA,PAGINACION,MATRICULA`, `PARAMETROS/TIPOS_NUMERICOS = INT,DECIMAL`, `PARAMETROS/TIPOS_ENTEROS = INT`, `PARAMETROS/LONGITUD_MINIMA_MOTIVO = 10`.
**Mensajes** (`53_culm001_d3_mensajes.sql`): `PRM_001` "Parámetro actualizado." · `PRM_002` "El parámetro no existe." (404) · `PRM_003` "Este parámetro no se puede editar." (403) · `PRM_004` "El valor debe ser de tipo {}." (400) · `PRM_005` "El valor debe estar entre {} y {}." (400) · `PRM_006` "El valor debe ser uno de: {}." (400) · `PRM_007` "«{}» debe ser menor que «{}»." (400) · `PRM_008` "Otro usuario modificó el parámetro. Recarga y vuelve a intentarlo." (409) · `PRM_009` "Indica un motivo de al menos {} caracteres." (400) · `PRM_010` "La edición de parámetros no está disponible con el catálogo de configuración activo." (409) · `PRM_011` "El valor no cambió." (200) · `PRM_012` "La edición de parámetros requiere una sola institución activa." (409).
**Permisos** `rol_asistencias_runtime_culm001_d3.sql`: los tres SP públicos.
**Migración** `22_culm001_d3_parametros_editables_up/down.sql` (el `down` exporta `CambioParametro` a `zz_archivo_CambioParametro_culm001_d3` antes del `DROP`, conserva los valores administrados de `CatalogoParametro` y el `up` siguiente restaura el historial).

**Pruebas RED** `DB:test/test_culm001_d3_parametros.sql`: D3-01 cambio válido (historial, `fechaModificacion` avanza) · D3-02 `RED/CIDRS_CAMPUS` con `esEditable = 1` forzado → `PRM_003` · D3-03 `TIEMPO/*`, sin fila de edición, y **cada grupo de `GRUPOS_NO_EDITABLES`** → `PRM_003` · D3-04 tipos (`abc` en INT, `7.5` en INT, `x` en DECIMAL) → `PRM_004` · D3-05 rango → `PRM_005` · D3-06 valores permitidos → `PRM_006` · D3-07 regla cruzada en las dos direcciones → `PRM_007` · D3-08 versión antigua → `PRM_008` · D3-09 concurrencia (`test_culm001_d3_concurrencia.ps1`): uno `PRM_001`, otro `PRM_008` · D3-10 motivo corto → `PRM_009` · D3-11 valor igual → `PRM_011` sin historial · D3-12 COORDINADOR → RBAC · D3-13 consulta: sin técnicos con `soloEditables = 1`, paginación inválida → `PAG_001` · D3-14 efecto inmediato en `ufn_calcular_fecha_limite_justificacion` · D3-15 ninguna fila editable en un grupo protegido; editables numéricas con rango · D3-16 `up → down → up` con historial recuperado · **D3-17** una segunda `Institucion` activa en la transacción de prueba → `PRM_012` · **D3-18** `fechaModificacion` con milisegundos `.007` (redondeo de `DATETIME`): la misma fecha enviada de vuelta coincide (OBS-4).

### 4.3 Backend

| Endpoint | Rol | Petición / respuesta |
| :--- | :--- | :--- |
| `GET /api/v1/admin/parametros?grupo&texto&soloEditables=true&pagina=1&tamano=20` (pasa a `ApiPageResponse`) | ADMINISTRADOR | `ApiPageResponse<ParametroAdminDTO>{id, grupo, clave, valor, valorDefecto, tipoDato, esEditable, valorMinimo, valorMaximo, valoresPermitidos[], etiqueta, descripcion, unidad, categoriaVisual, orden, fechaModificacion, fechaUltimoCambioUtc, nombreUltimoActor}` |
| `PUT /api/v1/admin/parametros/{id}` (hoy 501) | ADMINISTRADOR | `{valor, fechaModificacionEsperada, motivo}` → 200 `ApiDataResponse<ParametroActualizadoDTO>{id, grupo, clave, valorAnterior, valorNuevo, fechaModificacion, sinCambios}`; 400 (`PRM_004/5/6/7/9`), 403 (`PRM_003`, otro rol), 404 (`PRM_002`), 409 (`PRM_008`, `PRM_010`, `PRM_012`) |
| `GET /api/v1/admin/parametros/{id}/cambios?pagina&tamano` (diferible) | ADMINISTRADOR | `ApiPageResponse<CambioParametroDTO>` |

- **Formato de `fechaModificacion`/`fechaModificacionEsperada`** (OBS-4): ISO-8601 en UTC con milisegundos (`2026-11-07T15:04:05.007Z`), sin pérdida de precisión entre `DATETIME`, Java (`Instant`/`LocalDateTime` en UTC) y JSON. Prueba de ida y vuelta en adaptador y controlador.
- `ActualizarParametroUseCaseImpl`: forma → `ParametroEdicionCapacidadPort.admiteEdicion()` (`false` si el proveedor no es `sqlserver` → 409 `PRM_010`) → `ParametroCommandPort.actualizar` (`JpaProcedureExecutor` → `usp_actualizar_parametro`) → si cambió: `CatalogInvalidationPort.invalidateParameter(grupo, clave)` y, cuando C esté mezclado, `RealtimePublisherPort.publish(PARAMETER_UPDATED {grupo, clave})` con audiencia ADMINISTRADOR (un fallo de la publicación no revierte).
- `GET` por `usp_consultar_parametros_paginado`; se retira la HQL directa de `ParametroJpaRepository`.
- Controlador con `@AuditableOperation(action = "ACTUALIZAR_PARAMETRO", resourceType = "PARAMETRO", resourceIdPathVariable = "id", metadataResponseFields = {"grupo", "clave", "valorAnterior", "valorNuevo"}, metadataRequestFields = {"motivo"})`.
- Pruebas RED: validador, caso de uso (proveedor `azure`, `sinCambios`, éxito invalida una vez, publicación fallida → 200), `DbFailureClassifier` (12 códigos a 400/403/404/409), controlador, contrato SP, auditoría con anterior y nuevo, ida y vuelta de la fecha.

### 4.4 Frontend

`FE:features/admin/admin-system`, pestaña "Parámetros": lista paginada agrupada por `categoriaVisual`, buscador, filtro de grupo, "Mostrar parámetros técnicos (solo lectura)"; cada fila con etiqueta, descripción, valor y unidad, rango y último cambio (F-ADM-012). Modal `parametro-edicion-modal`: control por `tipoDato`/`valoresPermitidos`, motivo, `fechaModificacionEsperada` reenviada tal como llegó, errores del backend; un 409 `PRM_008` recarga. Specs RED: agrupación, búsqueda, paginación, control por tipo, envío exacto de la fecha, 400/403/409, sin `setInterval`; móvil en tarjetas y modal a pantalla completa.

### 4.5 Docs y riesgos

HU168 implementada. `PARAMETER_UPDATED` en `REALTIME_EVENT_CONTRACT.md` y su copia del backend **después de C** (los dos editan el contrato), con `.sha256` regenerado en el mismo commit (diferible). Deudas nuevas: propagación BD → Azure; caché con varias instancias; parámetros por institución ([SUPUESTO-D-16]). Riesgos: bajar un umbral no reevalúa alertas de C de forma retroactiva (C evalúa en el siguiente registro o en su job); los rangos acotan errores en los límites de QR.

---

## 5. D.4 — Admisión de estudiantes por el administrador (HU156)

### 5.1 Alcance

El administrador **crea o corrige** estudiantes que no pueden usar el QR, sin matricularlos ([SUPUESTO-D-07]). La cuenta se aprovisiona como en HU091/HU117-B/HU120.

### 5.2 BD

| Objeto | Definición |
| :--- | :--- |
| `usp_admitir_estudiante` (**nuevo**) | `(@idTipoIdIdentificacion, @numeroIdentificacion INT, @primerNombre, @segundoNombre = NULL, @primerApellido, @segundoApellido = NULL, @correo, @password NVARCHAR(500) = NULL /* hash */, @idPrograma, @idCorrelacion, @idUsuarioEjecutor)`. Correlación → RBAC ADMINISTRADOR → programa activo de su institución (`ADS_003`) → `usp_validar_unicidad_usuario_interno` (`ADS_004`) → correo institucional en alta nueva (`ADS_005`) → `usp_sincronizar_usuario_interno` si no existe (sin contraseña `ADS_006`) → `usp_sincronizar_estudiante_interno` → `usp_registrar_estudiante_en_programa_interno`. Ya admitido en el programa → `ADS_002`. `Usuario` bloqueado por documento y correo (`UPDLOCK, HOLDLOCK`) antes de insertar. Salida: tupla + `idUsuario, idEstudiante, esUsuarioNuevo, esEstudianteNuevo` |
| `usp_corregir_identidad_usuario` (**modificado**, OBS-6) | El `CASE` con literales de perfil (línea 47) se reemplaza: para `ESTUDIANTE`, el perfil del ejecutor debe estar en `IDENTIDAD/PERFILES_CORRECCION_ESTUDIANTE = COORDINADOR,ADMINISTRADOR`; para `DECANO`, en `IDENTIDAD/PERFILES_CORRECCION_DECANO = ADMINISTRADOR`. Rama de ámbito por perfil: COORDINADOR → estudiante con `EstudiantePrograma` en uno de sus programas (regla actual); ADMINISTRADOR → estudiante con `EstudiantePrograma` en un programa de su institución, o decano de una facultad de su institución (regla actual) |
| `usp_consultar_programas_institucion_paginado` (**nuevo**) | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @texto = NULL, @idFacultad = NULL)`; RBAC ADMINISTRADOR; programas activos de su institución |
| Semillas `54_culm001_d4_*` | Mensajes `ADS_001` "Estudiante admitido." · `ADS_002` "El estudiante ya está admitido en este programa." · `ADS_003` "El programa no existe o no pertenece a tu institución." · `ADS_004` "El documento y el correo corresponden a personas distintas." · `ADS_005` "El correo debe ser institucional ({})." · `ADS_006` "Indica una contraseña inicial para el estudiante nuevo."; parámetros `IDENTIDAD/PERFILES_CORRECCION_ESTUDIANTE`, `IDENTIDAD/PERFILES_CORRECCION_DECANO` |
| Permisos `rol_asistencias_runtime_culm001_d4.sql` | `usp_admitir_estudiante`, `usp_consultar_programas_institucion_paginado` |
| Migración `23_culm001_d4_admision_estudiantes_up/down.sql` | SP y semillas / `DROP` y restauración literal de `usp_corregir_identidad_usuario` |

**Pruebas RED** `test_culm001_d4_admision.sql`: D4-01 alta nueva sin `EstudianteGrupo` · D4-02 persona existente con el mismo documento y correo → perfil ES sin duplicar · D4-03 repetición → `ADS_002` · D4-04 → `ADS_004` · D4-05 → `ADS_003` · D4-06 → `ADS_005` · D4-07 → `ADS_006` · D4-08 COORDINADOR → RBAC · D4-09 fallo provocado tras crear el Usuario → sin filas parciales, `@@TRANCOUNT = 0` · D4-10 corrección por ADMINISTRADOR dentro y fuera de su institución; COORDINADOR sigue igual; DECANO por ADMINISTRADOR sigue igual; sin literales de perfil en el SP (`sys.sql_modules`) · D4-11 programas paginados de su institución · D4-12 `up → down → up`.

### 5.3 Backend

| Endpoint | Rol | Petición / respuesta |
| :--- | :--- | :--- |
| `POST /api/v1/admin/estudiantes/admision` | ADMINISTRADOR | `{tipoIdentificacionId, numeroIdentificacion, primerNombre, segundoNombre?, primerApellido, segundoApellido?, correo, password?, idPrograma}` (OBS-5) → 201 `ApiDataResponse<AdmisionEstudianteDTO>{idEstudiante, idUsuario, esUsuarioNuevo, estadoCuenta: ACTIVA \| PENDIENTE_VERIFICACION \| PENDIENTE_SINCRONIZACION, cuentaReparada}`; 400 (campos con `details`, `ADS_005`, `ADS_006`, política de clave), 403 (`ADS_003`, otro rol), 409 (`ADS_002` con cuenta existente, `ADS_004`) |
| `PUT /api/v1/admin/estudiantes/{idEstudiante}/identidad` (**no diferible**) | ADMINISTRADOR | Mismo cuerpo y respuesta que `PUT /coordinador/estudiantes/{id}/identidad` (`CorreccionIdentidadController`, tipo ESTUDIANTE) |
| `GET /api/v1/admin/programas?texto&idFacultad&pagina&tamano` | ADMINISTRADOR | `ApiPageResponse<ProgramaInstitucionDTO>{id, codigo, nombre, idFacultad, nombreFacultad}` |

- `AdmitirEstudianteUseCaseImpl` (patrón de `RegistrarEstudianteUseCaseImpl`: identidad, IDENT-001, `PasswordRegistroRule.resolverCredencialNueva` solo para personas nuevas, `PasswordEncoderPort`) → `AdmisionEstudianteCommandPort` → `AsegurarCuentaIdentidadService.asegurar(usuario, ESTUDIANTE)` → aviso IDENT-001 (mejor esfuerzo).
- `AsegurarCuentaIdentidadService` (application; lo reutilizan D.5 y D.9 F-ADM-024): `crearCuenta`; `IdentityProviderException` → desfase en `UsuarioSincronizacionIdentidadPort` y `PENDIENTE_SINCRONIZACION` (sin 500). Para `ADS_002`: `buscarCuentaPorIdUsuario` → existe: 409; falta: `crearCuenta`, `cuentaReparada = true`, 201; capacidad ausente: 409. El RED verifica si el adaptador baseline implementa `buscarCuentaPorIdUsuario`.
- Pruebas RED: caso de uso (todas las ramas), servicio de cuenta (4 ramas), validador con `details`, controladores (201/400/403/409; identidad 200/403), contrato SP, ArchUnit. **OBS-12:** con `password` en el cuerpo, ni `metadata` de auditoría ni los logs del `GlobalExceptionHandler` (en 400 y en 500) contienen el valor (captura del appender y del publicador de auditoría).

### 5.4 Frontend

`FE:features/admin/admin-estudiantes`: "Admitir estudiante" con modal `admision-estudiante-modal` (tipo de documento del catálogo, selector de programa con búsqueda en servidor, contraseña inicial pedida cuando el backend responde `ADS_006`, mensajes del backend, aviso si `estadoCuenta` no es `ACTIVA`); "Corregir identidad" con `shared/components/correccion-identidad-modal`. Specs RED (formulario, `details`, 409, `ADS_006`, estado pendiente, corrección); móvil a pantalla completa.

### 5.5 Docs y riesgos

HU156 implementada (crea y corrige); F-ADM-004 corregido. Riesgo: aprovisionamiento parcial, cubierto por `PENDIENTE_SINCRONIZACION` y la reparación al repetir.

---

## 6. D.5 — Carga masiva CSV de roles no estudiantes (HU171)

### 6.1 Alcance

Coordinador → docentes de sus programas (HU091); decano → coordinadores de su facultad (HU120); administrador → decanos (HU117-B). Estudiantes fuera. Plantilla → validación previa sin crear nada → confirmación → creación fila por fila con el caso de uso individual. **No diferible** (§3.6).

### 6.2 Formato CSV

- UTF-8 (BOM opcional); separador `,` o `;` detectado en la cabecera; comillas RFC 4180; CRLF o LF; líneas vacías ignoradas.
- Cabecera obligatoria con los nombres exactos (sin distinguir mayúsculas), en cualquier orden; desconocida o faltante → `CMA_004`.
- Límites: `CARGA_MASIVA/TAMANIO_MAXIMO_BYTES = 1048576` (`CMA_002`), `CARGA_MASIVA/MAXIMO_FILAS = 100` (`CMA_001`), `CARGA_MASIVA/LIMITE_POR_MINUTO = 3` por actor (429 `CMA_014`).
- Número de fila = número de línea (la cabecera es la 1).
- Inyección de fórmulas: una celda que empieza por `=`, `+`, `-`, `@`, tabulador o retorno de carro → `CMA_011`, **excepto `clave_inicial`** (OBS-11: una clave válida puede empezar por esos caracteres y nunca se reexporta).

| Columna | Docentes (coordinador) | Coordinadores (decano) | Decanos (administrador) | Regla |
| :--- | :--- | :--- | :--- | :--- |
| `tipo_documento` | obligatoria | obligatoria | obligatoria | Código de `TipoIdentificacion` (`CMA_006`) |
| `numero_documento` | obligatoria | obligatoria | obligatoria | Entero positivo en rango `INT` (`CMA_005`) |
| `primer_nombre`, `primer_apellido` | obligatorias | obligatorias | obligatorias | Validadores del alta individual |
| `segundo_nombre`, `segundo_apellido` | opcionales | opcionales | opcionales | Ídem |
| `correo` | obligatoria | obligatoria | obligatoria | Formato y dominio del alta individual |
| `clave_inicial` | si es nueva | si es nueva | si es nueva | `PasswordRegistroRule` (`CMA_012` si falta); se ignora si la persona existe |
| `codigo_tipo_vinculacion` | obligatoria | — | — | `TipoVinculacion.codigo` |
| `codigo_programa` | obligatoria si el coordinador tiene más de un programa (DEC-021 S4) | obligatoria | — | `CMA_007` |
| `codigo_facultad` | — | — | opcional | `CMA_007` |

Plantillas `plantilla-carga-docentes.csv`, `plantilla-carga-coordinadores.csv`, `plantilla-carga-decanos.csv` (solo cabecera, `;`, BOM).

### 6.3 BD

| Objeto | Definición |
| :--- | :--- |
| `JerarquiaAltaUsuario` (tabla de catálogo) + `uv_jerarquia_alta_usuario` | `id, perfilEjecutor (FK Perfil), perfilDestino (FK Perfil)`, única por par; 3 filas sembradas por código de perfil |
| `usp_validar_carga_masiva_usuarios` (solo lectura, `READ_QUERY_RESULTSET`) | `(@idUsuarioEjecutor, @idCorrelacion, @codigoPerfilDestino VARCHAR(20), @filasJson NVARCHAR(MAX))`; `@filasJson` = `[{numeroFila, tipoDocumento, numeroDocumento, correo, codigoTipoVinculacion, codigoPrograma, codigoFacultad}]` (sin nombres ni clave). Par (perfil del ejecutor, destino) en `JerarquiaAltaUsuario` o `THROW` `CMA_009`; más filas que el parámetro → `THROW` `CMA_001`. Una fila de salida por fila de entrada: `numeroFila, esValida, yaExiste, codigoMensaje, mensajeUsuario, idTipoIdentificacion, idTipoVinculacion, idPrograma, idFacultad, idUsuarioExistente`. Reglas: catálogos (`CMA_006`), ámbito con los internos existentes (`CMA_007`), identidad (`CMA_008`), duplicado en el archivo (`CMA_010`), `yaExiste` según [SUPUESTO-D-11]. Sin escrituras |
| `usp_crear_coordinador`, `usp_crear_decano` (**modificados**) | Parámetro nuevo **al final** de la firma (OBS-10): `@idTipoIdIdentificacion UNIQUEIDENTIFIER = NULL`; `NULL` → `IDENTIDAD/TIPO_IDENTIFICACION_DEFECTO` (en lugar del literal `'CC'`, líneas 165 y 109). Los llamadores actuales no cambian |
| Semillas `55_culm001_d5_*` | Parámetros `CARGA_MASIVA/MAXIMO_FILAS`, `TAMANIO_MAXIMO_BYTES`, `LIMITE_POR_MINUTO` (con filas de edición si existe la tabla), `IDENTIDAD/TIPO_IDENTIFICACION_DEFECTO = CC`; jerarquía; mensajes `CMA_001` "El archivo supera {} filas." · `CMA_002` "El archivo supera el tamaño permitido." · `CMA_003` "El archivo cambió desde la validación. Valídalo de nuevo." · `CMA_004` "La cabecera no coincide con la plantilla: {}." · `CMA_005` "Número de documento inválido." · `CMA_006` "Código de {} desconocido: {}." · `CMA_007` "«{}» no está en tu ámbito." · `CMA_008` "El documento y el correo corresponden a personas distintas." · `CMA_009` "Tu rol no puede cargar este tipo de cuentas." · `CMA_010` "Fila repetida en el archivo (línea {})." · `CMA_011` "Valor no permitido en la columna {}." · `CMA_012` "Falta la clave inicial para una persona nueva." · `CMA_013` "El archivo no es un CSV UTF-8 válido." · `CMA_014` "Has superado el número de cargas por minuto." · `CMA_015` "Carga procesada: {} creadas, {} ya existentes, {} con error." |
| Permisos `rol_asistencias_runtime_culm001_d5.sql` | `usp_validar_carga_masiva_usuarios` |
| Migración `24_culm001_d5_carga_masiva_up/down.sql` | Tabla, semillas, SP nuevo, firma de los dos SP. `down`: §14.2 (aborta si `usp_crear_decano` contiene `DEC_020` de D.9) |

**Pruebas RED** `test_culm001_d5_carga_masiva.sql`: D5-01 coordinador con 3 filas válidas → 3 `esValida` y 0 escrituras · D5-02 decano con un programa de otra facultad → `CMA_007` · D5-03 administrador con destino DOCENTE → `CMA_009` · D5-04 duplicado por documento y por correo → `CMA_010` en la segunda aparición · D5-05 persona con el rol en el ámbito → `yaExiste = 1` · D5-06 → `CMA_008` · D5-07 → `CMA_006` · D5-08 coordinador de 2 programas sin `codigoPrograma` → `CMA_007` · D5-09 más filas que el parámetro → `CMA_001` · D5-10 `usp_crear_coordinador` con `@idTipoIdIdentificacion` → tipo guardado; `NULL` → parámetro (sin literal en `sys.sql_modules`) · D5-11 `up → down → up` · **D5-12** llamadas existentes a `usp_crear_coordinador`/`usp_crear_decano` sin el parámetro nuevo siguen funcionando.

### 6.4 Backend

| Endpoint | Rol | Petición / respuesta |
| :--- | :--- | :--- |
| `GET /api/v1/{coordinador\|decano\|admin}/cargas/plantilla` | COORDINADOR / DECANO / ADMINISTRADOR | `text/csv; charset=UTF-8`, `attachment; filename=plantilla-carga-<destino>.csv` |
| `POST /api/v1/{rol}/cargas/validacion` | Ídem | `multipart` `archivo` → 200 `ApiDataResponse<ResultadoValidacionCargaDTO>{huella, perfilDestino, totalFilas, filasValidas, filasYaExistentes, filasConError, filas[{numeroFila, documento, correo, estado: VALIDA \| YA_EXISTE \| ERROR, errores[{campo, codigo, mensaje}]}]}`; no crea nada; 400/403/429 |
| `POST /api/v1/{rol}/cargas` | Ídem | `multipart` `archivo` + `huella` → 200 `ApiDataResponse<ResultadoCargaDTO>{totalFilas, creadas, yaExistentes, conError, cuentasPendientes, filas[{numeroFila, documento, correo, estado: CREADA \| CREADA_CUENTA_PENDIENTE \| YA_EXISTE \| YA_EXISTE_CUENTA_REPARADA \| ERROR, idUsuario?, errores[]}], mensaje}`; 409 `CMA_003` |

`{rol}` → destino fijo: `coordinador` → DOCENTE, `decano` → COORDINADOR, `admin` → DECANO. Sin `clave_inicial` ni nombres en la respuesta; lista acotada por `MAXIMO_FILAS` (excepción justificada a `ApiPageResponse`).

- Primario: tres rutas fijas por rol y `CsvCargaUsuariosParser` en `infrastructure/adapter/primary/controller/cargas/` (sin librería nueva o, si se añade, con versión fija). Límite por actor con `SlidingWindowRateLimiter` (`infrastructure/adapter/primary/controller/filter/`, ya en integración).
- Application `features/cargamasiva/`: `ValidarCargaUsuariosUseCaseImpl` (forma por fila + `CargaUsuariosValidacionPort` → SP) y `EjecutarCargaUsuariosUseCaseImpl` (huella, revalidación, caso de uso individual por fila válida —`VincularDocenteProgramaInputPort`, `CrearCoordinadorInputPort`, `CrearDecanoInputPort`—, excepciones por fila con el mensaje del catálogo, `AsegurarCuentaIdentidadService` para `YA_EXISTE`; secuencial y sin transacción global).
- `CrearCoordinadorDTO`/request y el adaptador de `usp_crear_decano` pasan el tipo de documento.
- Auditoría: `@AuditableOperation(action = "CARGA_MASIVA_<DESTINO>", resourceType = "CARGA_MASIVA", metadataResponseFields = {"totalFilas", "creadas", "yaExistentes", "conError"})` en `POST …/cargas`; la validación no se audita. Logs solo con conteos y `correlationId`.
- Pruebas RED: parser (BOM, separadores, comillas, cabecera, vacías, fórmula, no UTF-8, tamaño, **`clave_inicial` que empieza por `@`, `+` o `-` aceptada**), casos de uso (validación sin comandos; huella distinta → 409 sin llamadas; excepción en la fila 2 no detiene la 3; reparación de cuenta; IdP caído → `CREADA_CUENTA_PENDIENTE`; repetición → todo `YA_EXISTE`), controladores (plantilla exacta por rol, 403 cruzado, 429), **seguridad**: la clave no aparece en logs (appender), en la respuesta, en `metadata` de auditoría ni en los logs del `GlobalExceptionHandler` (OBS-12), rendimiento con 100 filas e IdP simulado a 200 ms (p95 registrado; si supera 60 s, el orquestador baja `MAXIMO_FILAS`).

### 6.5 Frontend

`shared/components/carga-masiva-usuarios` (`destino = input.required<'DOCENTE' | 'COORDINADOR' | 'DECANO'>()`, `carga-masiva.service.ts`) en `coordinator-docentes`, `dean-coordinadores` y `admin-decanos`: plantilla → validar → tabla por fila y resumen → confirmación ("se crearán N, se omitirán M") → resultado por fila y "Descargar resultado" (solo número de fila, estado y mensajes). Specs RED: flujo, confirmación, 409 de huella, 429, la clave nunca se muestra, OnPush/signals; móvil en tarjetas.

### 6.6 Docs y riesgos

HU171 con el texto de DEC-040 y su SP. Riesgos: tiempo síncrono con el IdP (límite y p95); contraseñas en un archivo del operador (solo en memoria; la pantalla recomienda borrarlo); éxito parcial por diseño, visible y repetible.

---

## 7. D.6 — Auditoría de las mutaciones `/api/v1/admin/**` (DEC-022 §4)

### 7.1 Alcance

Toda petición `POST`/`PUT`/`PATCH`/`DELETE` bajo `/api/v1/admin/**` (y `PUT /api/v1/admin/decanos/{id}/identidad`) deja un `AuditoriaEvento` con actor, acción, recurso, resultado, `correlationId` y valores en `metadata`. `AuditoriaEvento` no cambia. La lectura de auditoría es global y coincide con el ámbito del administrador ([SUPUESTO-D-16]).

### 7.2 Backend

- `@AuditableOperation` + `metadataRequestFields`/`metadataResponseFields` (String[]). `AuditInterceptor.metadata()` arma `{handlerType, <campo>: <valor saneado>}` (240 caracteres por valor, 4 KB en total) con **denegación por nombre exacto** (`password`, `clave_inicial`, `claveInicial`, `token`, `pin`, `secret`) que gana a la lista blanca; `SensitiveDataSanitizer.isSensitiveKey` no cubre `clave_inicial`/`claveInicial`, por eso la denegación es obligatoria y tiene prueba. `clave` (de parámetro) no es sensible: el RED comprueba que el saneador no la oculta.
- Anotaciones nuevas (acción · recurso · id): `POST /admin/decanos` `CREAR_DECANO` · `PUT /admin/decanos/{id}/identidad` `CORREGIR_IDENTIDAD_DECANO` · `PUT /admin/parametros/{id}` (D.3) · `POST /admin/cierre-masivo` `CIERRE_MASIVO_PERIODO` · `POST /admin/facultades` `CREAR_FACULTAD` · `PUT /admin/facultades/{id}` `ACTUALIZAR_FACULTAD` · `PATCH /admin/facultades/{id}/estado` `CAMBIAR_ESTADO_FACULTAD` · `POST`/`PUT`/`DELETE /admin/periodos-academicos[/{id}]` `CREAR_/ACTUALIZAR_/ELIMINAR_PERIODO_ACADEMICO` · `POST /admin/notificaciones/plantillas/{tipo}/versiones` `CREAR_VERSION_PLANTILLA` · `PATCH …/versiones/{version}/activar` `ACTIVAR_VERSION_PLANTILLA` · `POST /admin/notificaciones/cola/{id}/reintentar` `REINTENTAR_NOTIFICACION` · `POST /admin/notificaciones/prueba` `ENVIAR_NOTIFICACION_PRUEBA` · `POST /admin/estudiantes/admision` `ADMITIR_ESTUDIANTE` · `PUT /admin/estudiantes/{id}/identidad` `CORREGIR_IDENTIDAD_ESTUDIANTE` · `POST /admin/cargas` (D.5). Ya están: `PATCH /admin/decanos/{id}/toggle`, `POST /admin/festivos/{anio}/recarga`.
- Excepciones (sin escritura): `POST /admin/notificaciones/plantillas/{tipo}/vista-previa`, `POST /admin/cargas/validacion`.
- **`BE-T:…/architecture/AdminMutacionesAuditadasTest`**: recorre `RequestMappingHandlerMapping` y falla si un handler `POST|PUT|PATCH|DELETE` de `/api/v1/admin/**` no tiene `@AuditableOperation` y no está en la lista de excepciones del propio test.
- Lectura (F-ADM-022): `EventoAuditoriaDTO` + `idCorrelacion` (se conserva `idTraza`); `GET /api/v1/admin/auditoria` admite `idCorrelacion` y `soloAdministracion`.
- Pruebas RED: interceptor (metadatos, denegación, truncado, publicador que falla), cada controlador administrativo (evento en éxito y en 400/403), DTO con `idCorrelacion`, controlador con los filtros.

### 7.3 BD

- `usp_consultar_auditoria_eventos_paginado` (**modificado**): al final `@idCorrelacionEvento UNIQUEIDENTIFIER = NULL`, `@soloAdministracion BIT = 0`. **Regla entre filtros (OBS-7):** `@soloAsistencia` conserva su defecto `1` (comportamiento actual intacto). T-SQL no distingue un valor por defecto de uno pasado, así que **el backend envía siempre los dos parámetros explícitos** (con `soloAdministracion = true` envía `soloAsistencia = false`) y el SP rechaza (`THROW`, error de validación) la combinación `@soloAsistencia = 1 AND @soloAdministracion = 1`. Con `@soloAdministracion = 1` filtra `path LIKE ufn_obtener_parametro_texto(NULL,'AUDITORIA','PREFIJO_RUTA_ADMINISTRACION') + '%'`. Comprobación de [SUPUESTO-D-16]. Columnas sin cambio.
- Semilla `56_culm001_d6_parametros.sql`: `AUDITORIA/PREFIJO_RUTA_ADMINISTRACION = /api/v1/admin/`. Migración `25_culm001_d6_auditoria_admin_up/down.sql`.
- Pruebas RED `test_culm001_d6_auditoria.sql`: D6-01 filtro por correlación · D6-02 solo rutas administrativas · D6-03 los dos a 1 → error · D6-04 sin filtros nuevos, igual que antes · **D6-05** `@soloAsistencia = 0, @soloAdministracion = 1` → solo administración; solo `@soloAdministracion = 1` con el defecto de `@soloAsistencia` → error (documenta que el llamador debe pasar los dos); llamada con los parámetros por defecto → solo asistencia; prueba del backend de que el adaptador envía siempre los dos parámetros.

### 7.4 Frontend

Pestaña "Trazabilidad y Auditoría": columna "Correlación" copiable, filtro por correlación, "Solo acciones administrativas" excluyente con "Solo acciones de asistencia", detalle con los metadatos. Specs RED; móvil en tarjetas.

### 7.5 Docs y riesgos

HU172 ampliada; F-ADM-022 y F-ADM-S13 corregidos. Riesgos: fuga en `metadata` (lista blanca + denegación con prueba); el evento HTTP es de mejor esfuerzo (para parámetros hay además `CambioParametro`).

---

## 8. D.7 — Retiro de `POST /api/v1/asistencias` y del SP autónomo (TD-009)

### 8.1 Alcance y precondición

El registro individual queda cubierto por el lote (golden path) y por el registro por toma de B.2. **Precondición:** B.2 mezclado. Hoy `AsistenciaQrController` (`POST /estudiante/asistencia-qr`) y `AsistenciaJpaRepository:43` usan el SP autónomo también en la rama B.2: B.2 los retira ([SUPUESTO-B-18]); si al llegar D.7 siguen, D.7 los retira. Si B.2 no está mezclado antes del 2026-11-11, D.7 queda en RED y TD-009 sigue abierta.

### 8.2 BD

- Migración `26_culm001_d7_retiro_registro_autonomo_up.sql`: `REVOKE EXECUTE … FROM [rol_asistencias_runtime]` (si existe) y `DROP PROCEDURE`. `_down.sql`: recrea el SP con su texto literal y el `GRANT`.
- Se borra `DB:schema/stored-procedures/usp_registrar_asistencia_estudiante_autonomo.sql`.
- `rol_asistencias_runtime.sql`: se quita la línea 54 de la lista (si no, `THROW 52120` porque el SP ya no existe); su línea `WORK_ITEM` en UTC-D06 se regenera **en el mismo commit** (DEC-042).
- `test/verify_runtime_role_login.ps1:31`: se quita el SP de la lista esperada y se añade la aserción negativa.
- Pruebas que cambian por contrato (objeto retirado), OBS-13:
  - `test_attendance_commands.sql`: el bloque de comandos individuales/autónomo desde la línea 437, **incluido el caso `VAL_007`** posterior a la 460 (código de verificación incorrecto), se sustituye por D7-01/D7-02.
  - `test_ses01_ventana_asistencia.sql`: bloque J, líneas **196–240**, con sus tres casos `SES01_AUTO_CLOSED`, `SES01_AUTO_BEFORE_START` y `SES01_AUTO_INDETERMINATE`; se quitan también sus marcadores de las listas de IDs esperados de `DB:test_summary.ps1` e `INFRA:components/sqlserver/scripts/test-summary.ps1`.
  - **Garantía SES-01 heredada** ("ninguna ruta alternativa escribe fuera de la ventana"): la cubren las pruebas de B.2 **B2-TOM-03** (abrir toma fuera de ventana → `SES_007/008`), **B2-TOM-09** (lote por toma fuera de ventana → `SES_008`), **B2-QR-01** (QR fuera de ventana → `SES_008`) y **B2-QR-10** (sesión cancelada → `SES_010`). Como ninguna registra **por token** después del cierre de la ventana, D.7 añade **D7-04**: registro por token con la toma abierta y la ventana ya vencida → `SES_008` y sin escritura (si B.2 ya lo cubre con otro ID, D7-04 se sustituye por la cita).
- Documentos derivados (`DOCUMENTACION_PROCEDIMIENTOS_*.md`, `especificacion_sp_endpoints.md`) sin el SP.
- Pruebas RED `test_culm001_d7_retiro.sql`: D7-01 (`OBJECT_ID IS NULL`), D7-02 (sin permisos en `sys.database_permissions`), D7-03 (`up → down → up`), D7-04.

### 8.3 Backend

- Se retiran: el handler de `POST /api/v1/asistencias`, `RegistrarAsistenciaInputPort`, su caso de uso, DTO, dominio, request, validador, la parte del mapper, el método de puerto/adaptador con `FeatureUnavailableException`, la feature `registrarasistenciaautonoma` si sigue, el matcher de `SecurityConfig` y la entrada de `access-catalog.json`.
- Consumidores de prueba (OBS-13): `AsistenciaControllerTest` (sus casos pasan a uno: `POST /api/v1/asistencias` → 404), `SqlStoredProcedureContractIT`, `AsistenciaCommandsSpParityIT`, `AsistenciaJdbcBaselineOracle`, `AsistenciaJpaCommandNativeQueryPatternTest`, `DbFailureClassifierVentanaAsistenciaTest` (casos del autónomo) y el comentario de `DbFailureClassifier.java:176`.
- Golden path: sin cambio por D.7 (la ruta no está en `openapi-golden-path.yaml`).

### 8.4 Frontend

No hay llamadores de `POST …/asistencias` exacto (verificado por REVIEW-1: solo `coordinador/sesiones/{id}/asistencias`). Se añade una prueba que lo fija (búsqueda en `src/app`).

### 8.5 Docs y riesgos

TD-009 cerrada; deuda "autónomo sin consumidor" de B cerrada; HU027 con `POST /asistencias/lote` y toma; `test_all_hus.ps1`: `POST /asistencias` espera 404 (con PDP sin `--prune`; tras `--prune` sería 403 salvo que F-EST-024 esté hecho); F-DOC-022 corregido. Riesgo: mezclar antes que B.2 (lo impide la precondición).

---

## 9. D.8 — Comparativas, tendencia y consolidado por horas (HU103, HU139, HU134, HU061; F-COO-007)

### 9.1 Alcance y precondición

Los cuatro SP diferidos por B ([SUPUESTO-B-23]) pasan a horas (DEC-012/DEC-024) **sobre el texto que deja B2** (§2.7.4 de B2: `uv_resumen_asistencia_estudiante_programa_grupo`, conteo por `DISTINCT idEstudiante`, consolidado con grano **(grupo, programa del ámbito)**, tendencia por `uv_grupo_programa`). **Precondición:** B.2 y B2 (migraciones 16, 17 y 18) mezclados.

### 9.2 BD

| SP | Fórmula nueva (misma población y grano que B2) | Columnas al final |
| :--- | :--- | :--- |
| `usp_consultar_comparativa_facultades` (HU139), `usp_consultar_comparativa_programas_facultad` (HU103) | Sobre `uv_resumen_asistencia_estudiante_programa_grupo` (columnas de horas de B.2 + `idPrograma` de B2): `porcentajeAusentismo = ROUND(100 · Σ horasFalta / Σ horasDictadas, 2)` por facultad o por programa (`NULL` si Σ `horasDictadas` = 0). `sesionesEjecutadas` y `faltasSinJustaCausa` siguen en sesiones | `horasDictadas DECIMAL(12,2), horasFalta DECIMAL(12,2)` |
| `usp_consultar_tendencia_ausentismo` (HU134) | Por intervalo (semana o mes local del inicio), con los `JOIN` de B2 (`uv_grupo_programa`) y `COUNT(DISTINCT c.idSesion)`: `ROUND(100 · Σ horasFalta / Σ (horasSesion × matrículas activas de la sesión), 2)`; las canceladas no cuentan | `horasDictadasEstudiante DECIMAL(14,2), horasFalta DECIMAL(14,2)` |
| `usp_consultar_consolidado_asistencia_grupos_paginado` (HU061) | Por fila (grupo, programa del ámbito), con `D = horasDictadas × activos del programa en el grupo`: `porcentajeAsistencia = ROUND(100 · Σ horasAsistidas / D, 2)`, `porcentajeInasistencia = ROUND(100 · Σ horasFalta / D, 2)`, `porcentajeExcusa = ROUND(100 · Σ horasExcusa / D, 2)` y **`porcentajeSinRegistro = 100 − (las tres anteriores)`** (DEC-044 (9)): los cuatro suman exactamente `100.00`; si `D = 0`, los cuatro son `0`. El literal `N'A'` pasa a `MATRICULA/ESTADO_INSCRITA` (OBS-8) | `horasDictadas DECIMAL(12,2), porcentajeExcusa DECIMAL(5,2), porcentajeSinRegistro DECIMAL(5,2)` |

- Migración `27_culm001_d8_kpis_horas_up/down.sql`: el `down` restaura el texto **B2 + B.2** (literal). `DB_DEVELOP_FREEZE_ADDENDUM.md` (BD e Infra): sección "CULM-001 D.8" con la unidad de cada columna; `.sha256` en el mismo commit.
- **Pruebas RED** `test_culm001_d8_kpis_horas.sql` (fixture con sesiones de 2 h y 1 h, una con 2 tomas, una cancelada, una cabecera sin detalle y un grupo de dos programas):
  - D8-01 comparativas = valor esperado calculado a mano (por programa, sin contar dos veces a un estudiante, regla de B2).
  - D8-02 tendencia por semana y por mes = esperado.
  - **D8-03** consolidado: **cada** porcentaje (`porcentajeAsistencia`, `porcentajeInasistencia`, `porcentajeExcusa`, `porcentajeSinRegistro`) es **igual** a su valor esperado, calculado a mano con la misma regla de redondeo (los tres primeros con `ROUND(…, 2)` y el cuarto como `100 −` la suma de los tres redondeados); el caso F-COO-007 (10 activos, 2 sesiones, sin faltas) da su `porcentajeSinRegistro` esperado (> 0); con `D = 0`, los cuatro son `0`. No se compara la suma con tolerancia.
  - D8-04 con una toma y sesiones de igual duración coincide con la fórmula por sesiones (regresión).
  - D8-05 sin literal `'A'` (`sys.sql_modules`).
  - D8-06 la cancelada no suma.
  - D8-07 grano (grupo, programa): un grupo de dos programas da una fila por programa del ámbito, cada una con sus estudiantes.
  - D8-08 `up → down → up` (el `down` deja el texto de B2).

### 9.3 Backend y frontend

DTOs de `GET /admin/comparativa-facultades`, `/decano/comparativa-programas`, `/admin/tendencia-ausentismo` y `/{coordinador|decano}/consolidado-asistencia` con los campos nuevos (proyecciones, mappers, contrato posicional; pruebas RED). Indicadores: "calculado por horas"; `ConsolidadoAsistenciaComponent`: columnas "Excusa" y "Sin registro", barra apilada de 4 segmentos; specs RED; móvil.

### 9.4 Docs y riesgos

HU061/103/134/139 por horas; F-COO-007 y F-COO-S02 corregidos. Riesgo: los números cambian con sesiones de duraciones distintas (se comunica en el PR).

---

## 10. Catálogo de accesos (DEC-037/DEC-038)

Cada fila entra en `SecurityConfig` y `access-catalog.json`. **B-01:** hasta que el responsable ejecute `python -X utf8 -I infra\security-baseline\scripts\provision_asistencias.py pdp` (y `verify`, `verify-decisions`), las rutas **nuevas** dan 403 en el laboratorio; los gates de código no dependen de esto; la prueba en pantalla queda anotada en `PRS.md`.

| D.x | Método y ruta | Roles | Ámbito | Tipo |
| :--- | :--- | :--- | :--- | :--- |
| D.1 | `GET /api/v1/estudiante/materias/{materiaId}/sesiones` | ESTUDIANTE | SP con ámbito; campos nuevos y `pagina`/`tamano` opcionales | cambia (ya registrada) |
| D.2 | `GET /api/v1/configuracion/reclamos` | ESTUDIANTE, DOCENTE | Configuración institucional | nueva |
| D.3 | `GET /api/v1/admin/parametros` | ADMINISTRADOR | Paginada; [SUPUESTO-D-16] | cambia la respuesta |
| D.3 | `PUT /api/v1/admin/parametros/{id}` | ADMINISTRADOR | Lista blanca y concurrencia en el SP; auditada | registrada (501 → implementada) |
| D.3 | `GET /api/v1/admin/parametros/{id}/cambios` | ADMINISTRADOR | Historial | nueva (diferible) |
| D.4 | `POST /api/v1/admin/estudiantes/admision` | ADMINISTRADOR | Programa de su institución (SP) | nueva |
| D.4 | `PUT /api/v1/admin/estudiantes/{idEstudiante}/identidad` | ADMINISTRADOR | Estudiante de su institución (SP); motivo obligatorio | nueva |
| D.4 | `GET /api/v1/admin/programas` | ADMINISTRADOR | Programas de su institución (SP) | nueva |
| D.5 | `GET …/coordinador/cargas/plantilla`, `POST …/coordinador/cargas/validacion`, `POST …/coordinador/cargas` | COORDINADOR | Docentes de sus programas | nuevas |
| D.5 | `GET …/decano/cargas/plantilla`, `POST …/decano/cargas/validacion`, `POST …/decano/cargas` | DECANO | Coordinadores de su facultad | nuevas |
| D.5 | `GET …/admin/cargas/plantilla`, `POST …/admin/cargas/validacion`, `POST …/admin/cargas` | ADMINISTRADOR | Decanos de su institución | nuevas |
| D.6 | `GET /api/v1/admin/auditoria` | ADMINISTRADOR | Filtros nuevos | cambia los parámetros |
| D.7 | `POST /api/v1/asistencias` | — | — | **retirada** (`--prune` a cargo del responsable, TD-062) |
| D.9 | `GET /api/v1/admin/periodos-academicos` | ADMINISTRADOR | Períodos de su institución | nueva |
| D.9 | `GET /api/v1/decano/grupos/{grupoId}` | DECANO | Su facultad; ajeno o inexistente → 403 ([SUPUESTO-D-14]) | nueva |
| D.9 | `GET /api/v1/decano/sesiones` | DECANO | `idGrupo` filtrado en el SP | cambia los parámetros |
| D.9-c | `GET /api/v1/realtime/status` | ADMINISTRADOR | Antes, cualquier autenticado | cambian los roles |
| D.9-c | `POST /api/v1/realtime/emit` | ADMINISTRADOR (sin cambio, `SecurityConfig.java:215`) | Cuerpo validado (DEC-042) | **cambia la validación** (no se retira) |

---

## 11. D.9 — Hallazgos medios y bajos asignados a D

Grupos: **a** (BD/backend: seguridad y 4xx/404; después de D.6 **y de B2**), **b** (frontend), **c** (SSE; después de C), **d** (docs/infra).

### 11.1 Tabla de hallazgos

| Hallazgo | Corrección concreta | Capa | Prueba RED | Grupo |
| :--- | :--- | :--- | :--- | :--- |
| F-ADM-003, F-ADM-012 | → D.3 | | | D.3 |
| F-ADM-004 | → D.4 | | | D.4 |
| F-EST-008, F-EST-S16 | → D.1 | | | D.1 |
| F-ADM-022, F-ADM-S13 | → D.6 | | | D.6 |
| F-DOC-022 | → D.7 | | | D.7 |
| F-ADM-008 | `/admin/parametros` → D.3. `decanos`, `facultades`, `areas` e `instituciones` son catálogos acotados por institución y se quedan en `ApiListResponse`: **"no-se-corrige (propuesta)"** en `FINDINGS.md` y CLOSURE, a confirmar por el orquestador (OBS-18). **D no edita `AGENTS.md`** | Docs | — | d |
| F-ADM-023 (+ F-EST-022) | Pasan a `ApiPageResponse` (`elementos, numeroPagina, tamanoPagina, totalElementos, totalPaginas`) los listados ya paginados por SP: `GET /admin/estudiantes`, `/admin/docentes`, `/admin/asignaturas`, `/admin/auditoria`, `/decano/programas-creditos`, `/decano/docentes`, `/decano/asignaturas`, `/decano/estudiantes`, `/decano/sesiones` (helpers `lista(PaginaDTO)` → `pagina(PaginaDTO, numero, tamano)`). Validación común `PaginacionRequestValidator` (`pagina ≥ 1`, `1 ≤ tamano ≤ PAGINACION/TAMANO_MAXIMO`) → 400 `PAG_001` en esos endpoints y en `/docente/reclamos` y `/estudiante/reclamos`. **No en D:** `GET /api/v1/estudiantes` (golden path WORM) y `/tipos-identificacion` (catálogo plano). Consumidores en §11.3 | BE + FE + E2E | §11.3 | a + b |
| F-ADM-024 | [SUPUESTO-D-12]: `usp_crear_decano` devuelve `DEC_020` si la persona ya es decano activo; `CrearDecanoUseCaseImpl` usa `AsegurarCuentaIdentidadService` | BD + BE | D9-DEC-01; caso de uso (3 ramas); controlador 409/201 | a |
| F-ADM-025 | `GlobalExceptionHandler` llena `details[{campo, codigo, mensaje}]` para `RequestValidationGuard`; validadores de decano y facultad con campo y regla; política de clave solo en el backend | BE + FE | `POST /admin/decanos` con `primerNombre=CULM1-Decano` → 400 con `details[0].campo = primerNombre`; ídem facultades | a |
| F-ADM-011 | `admin-decanos`: sin GUID quemado ni `CC` de respaldo, sin la etiqueta `DEC-{{…}}`, sin la regla de 12 caracteres. El backend honra `tipoIdentificacionId` (cambio de `usp_crear_decano` de D.5; si D.5 llega después, el cambio de SP se hace aquí con la misma firma) | FE (+BD) | Specs (sin GUID literal, sin `DEC-`, error de catálogo) | b |
| F-ADM-026 | `CierreMasivoRequest`: `idPeriodoAcademico` obligatorio → 400 `FIELD_REQUIRED`. **Después de C** (C añade el 409 `RCN_012` en el mismo endpoint) | BE | `POST /admin/cierre-masivo {}` → 400 | a (tras C) |
| F-ADM-027 | `usp_reintentar_notificacion_saliente` (y su interno) devuelve `NTF_020` si el id no existe → 404 (hoy 500 `ERR_DB_UNCLASSIFIED`); `vista-previa` con tipo inexistente → 404 `NTF_021` (validado contra el catálogo de plantillas) | BD + BE | D9-NTF-01/02; `DbFailureClassifierNotificacionTest`; controlador 404 | a |
| F-ADM-029 | `GET /admin/notificaciones/estado-canal` sin host, puerto ni usuario: `{canalActivo, ultimoEnvioUtc, ultimoError}` | BE + FE | Aserción de JSON sin esos campos | a |
| F-ADM-030 | `POST /admin/periodos-academicos` → 201 con el período creado; nuevo `GET /admin/periodos-academicos` (consulta del coordinador y su SP con perfil ADMINISTRADOR e institución, más `esVigente`) | BD + BE | 201 con id; GET 200 paginado, 403 para DOCENTE | a |
| F-ADM-005 | `admin-system` (cierre masivo): período inicial = `esVigente` del backend; siempre UUID; lista vacía con mensaje | FE | Specs | b |
| F-ADM-009 | Pantalla de solo lectura `/app/admin/instituciones` con menú y tabla | FE | Specs | b |
| F-ADM-016 | `environment.ts` sin lecturas de `localStorage` para `USE_MOCKS`/`USER_PROFILE_ENDPOINT_ENABLED`; mocks solo por `fileReplacements`; sin banderas muertas (`teacherClaimsEnabled`, `sessionsEnabled`, `attendanceEnabled`); `auth.service` sin rol mock restaurado | FE | Spec con `localStorage.USE_MOCKS='true'` → backend real; búsqueda de banderas | b |
| F-DOC-006 | `attendance-enrollment-modal`: solo 404 o vacío abren el alta; 403/500/red muestran el `message` | FE | Specs | b |
| F-EST-012 | El token `t` del QR se conserva a través del login (estado de navegación) y el modal envía `{token}` | FE | Spec | b |
| F-EST-006 | Parcial: `materia.creditos` desde la asignatura y filtro de texto de materias. "No-se-corrige (propuesta)": buscar compañeros (privacidad) y acordeón por semestre (depende de B2). `HU-CATALOG.md` corrige HU003/HU007/HU018/HU019 | BE + FE + docs | Mapper con créditos; spec del filtro | a + b + d |
| F-EST-S06, F-DOC-021 | Datos: el fixture de datos limpios y `culm1_segundo_ambito.sql` siembran franjas (`HorarioGrupo`) coherentes con las sesiones; las pantallas de horario muestran un estado vacío explicado | Datos + FE | D9-HOR-01; specs | a + b |
| F-DEC-003 | `GET /api/v1/decano/grupos/{grupoId}` (`usp_consultar_grupo_facultad_detalle`, ajeno o inexistente → 403); `dean-grupo-detalle` sin el bucle de 50 páginas: detalle + `GET /decano/sesiones?idGrupo=` paginado | BD + BE + FE | D9-DEC-02/03; controlador 200/403; spec sin bucle | a + b |
| F-DEC-014 | `usp_consultar_sesiones_facultad_paginado` (**sobre el texto de B2**, 1 fila por sesión con `EXISTS`) añade `@idGrupo = NULL`; grupo fuera de la facultad → 403 | BD + BE | D9-DEC-04 | a |
| F-TRX-021 | Por DEC-044 (4): las mallas por plan (`/coordinador/planes-estudio/{id}/asignaturas`, `/decano/planes-estudio/{planId}/asignaturas`) ya responden **404 `PLA_002`** por B2 (cubre también F-DEC-015); D **no** las cambia y añade pruebas de regresión. D corrige solo `GET /grupos/{id}/reportes/asistencia-excel`: id inexistente o fuera de ámbito → 403, validado en el SP antes de generar el `.xlsx` (regla DEC-025 de `/grupos/{id}/*`, [SUPUESTO-D-14]; ver §14.3) | BD + BE | D9-TRX-01 (excel 403 sin archivo); D9-TRX-02/03 (regresión: plan inexistente → 404 `PLA_002` en coordinador y decano) | a |
| F-EST-024 | `UnmappedRouteFilter` **después de la autenticación y antes del PEP** (OBS-17): ruta sin handler → 404 `RESOURCE_NOT_FOUND` sin consultar el PDP | BE | `GET /estudiante/materias/{id}/prerrequisitos` con token → 404; **sin token → 401**; ruta existente sin permiso → 403 | a |
| F-TRX-020 | `management.server.port` aparte (`MANAGEMENT_SERVER_PORT`, defecto 8090, comprobando conflictos) en `127.0.0.1`; `SecurityPublicEndpoints.ACTUATOR` → `/actuator/health/**`; recolección de Prometheus de Infra al puerto nuevo | BE + Infra | `:8080/actuator/prometheus` → 404/401; `:8090` loopback → 200 | a + d |
| F-TRX-011 | `docker-compose.yml:51`: `${MSSQL_SA_PASSWORD:?…}`; Traefik del perfil `proxy` en `127.0.0.1` y dashboard desactivado. **OBS-16:** `infra.ps1` (lee el `.env` del repo de BD o exporta el valor de laboratorio documentado) y un `.env.example` aportan la variable para que `db-deploy`/`db-test` sigan arrancando en checkouts sin `.env`. "No-se-corrige": claves de laboratorio documentadas en `AGENTS.md` §7 | Infra | `docker compose config` sin la variable falla; `infra.ps1 db-test` en checkout limpio con `.env.example` arranca | d |
| F-TRX-016 | `GET /realtime/status` solo ADMINISTRADOR. **`POST /realtime/emit` se mantiene** solo ADMINISTRADOR (DEC-042, DEC-044 (5)), con cuerpo validado: tipo de evento del `REALTIME_EVENT_CONTRACT`, audiencia obligatoria según la política de audiencia de C, payload JSON; `{}` o tipo desconocido → 400 `VALIDATION_ERROR` | BE | `status` 403 para DOCENTE; `emit` 400 (`{}`, tipo desconocido, sin audiencia), 403 (DOCENTE), 200 (válido) | c |
| F-TRX-019 | `GET /realtime/stream` con `Accept` incompatible → **406** (no 500); comentario SSE inicial (`: conectado`) al abrir; GUID sin distinguir mayúsculas. El 406 entra en el golden path **1.6.0** (§12) | BE + contrato | 406; primera respuesta < 1 s; GUID en mayúscula entregado; conformidad OpenAPI 1.6.0 | c |
| F-ADM-020 | `INFRA:docs/architecture/rutas-por-rol.md` generado desde `access-catalog.json` por `INFRA:scripts/docs/generar-rutas-por-rol.ps1` (`-Check` en `infra.ps1 verify`); el documento del workspace raíz se marca obsoleto | Docs | `-Check` | d |
| R-8 de A | `usp_validar_cruce_horario_estudiante_interno` cuenta solo matrículas `MATRICULA/ESTADO_INSCRITA` | BD | D9-CRU-01 | a |

### 11.2 BD de D.9 (OBS-20)

Migración `28_culm001_d9_hallazgos_up/down.sql` con estos objetos (el `down` restaura cada uno a su texto anterior, el de B2 cuando B2 lo tocó; §14.2):
- `usp_crear_decano` (rama `DEC_020`, sobre la firma de D.5).
- `usp_reintentar_notificacion_saliente` y `usp_reintentar_notificacion_saliente_interno` (`NTF_020`).
- Validación del tipo de plantilla para la vista previa (`usp_consultar_plantilla_notificacion_activa` con `NTF_021`).
- Consulta de períodos del administrador (SP de consulta del coordinador con perfil ADMINISTRADOR y `esVigente`) y `usp_crear_periodo_academico` (devuelve el id en el resultset).
- `usp_consultar_grupo_facultad_detalle` (nuevo) y `usp_consultar_sesiones_facultad_paginado` (`@idGrupo`).
- Validación de ámbito del reporte Excel por grupo (el SP que alimenta `GET /grupos/{id}/reportes/asistencia-excel`).
- `usp_validar_cruce_horario_estudiante_interno` (R-8).
- Datos: franjas en el fixture (no en la migración).

Semilla `59_culm001_d9_mensajes.sql`: `DEC_020` "La persona ya está registrada como decano.", `NTF_020` "La notificación no existe.", `NTF_021` "El tipo de plantilla no existe." (con técnicos). **No** se crea `GENERAL/TAMANO_PAGINA_MAXIMO`: se reutilizan `PAGINACION/TAMANO_MAXIMO` y `PAG_001` (OBS-15). Permisos `rol_asistencias_runtime_culm001_d9.sql`: `usp_consultar_grupo_facultad_detalle`.

### 11.3 Consumidores del cambio a `ApiPageResponse` (DEC-044 (6))

`ApiPageResponse` serializa `elementos`; `ApiListResponse` serializa `datos`. Cada consumidor lleva su prueba RED, que falla mientras lea `.datos`:

| Consumidor | Listados | Prueba RED |
| :--- | :--- | :--- |
| `FE:core/services/consultas-transversales.service.ts`: `listar`, `getProgramasCreditos`, `getDocentesFacultad`, `getDocentesInstitucion`, `buscarAsignaturas`, `buscarEstudiantes`, `getAuditoria` | admin estudiantes/docentes/asignaturas/auditoría; decano programas-créditos/docentes/asignaturas/estudiantes | `consultas-transversales.service.spec.ts`: un caso por método con una respuesta `{elementos, numeroPagina, …}` |
| `FE:core/mocks/mock-consultas-transversales.ts` | Mismos | Spec del mock: devuelve el sobre nuevo |
| `FE:core/interceptors/mock-backend.interceptor.ts` | Mismos | Spec del interceptor: sobre nuevo |
| `FE:core/services/dean-facultad.service.ts` | `/decano/sesiones` (que B2 también toca) | Spec nuevo del servicio |
| `FE:core/services/admin-management.service.ts` | `/admin/parametros` (D.3) | `admin-management.service.spec.ts` |
| `FE:core/services/attendance-claim.service.ts` | 400 `PAG_001` en `/docente/reclamos` y `/estudiante/reclamos` | `attendance-claim.service.spec.ts`: el 400 llega con el `message` del backend |
| Componentes `admin-estudiantes`, `admin-system/admin-auditoria`, `dean-docentes`, `dean-asignaturas`, `dean-estudiantes`, `dean-programas`, `dean-grupo-detalle`, `dean-cronograma`, `dean-faculty` | Los anteriores | Spec de cada componente: pinta `elementos` y enlaza `PaginationComponent` con `totalElementos`/`totalPaginas` |
| `BE-T`: pruebas de `AdminConsultasTransversalesController`, `DecanoConsultasTransversalesController`, `DecanoFacultadConsultaController` (helpers `lista(PaginaDTO)`) | Todos | Aserciones de JSON sobre `elementos`, `numeroPagina`, `tamanoPagina`, `totalElementos`, `totalPaginas`; 400 `PAG_001` con `pagina=0`, `pagina=-1`, `tamano=100000` |
| `INFRA:scripts/tests/test_all_hus.ps1`: líneas 961–966 (`/decano/docentes`), 999 (`/decano/sesiones`), 1022–1027 y 1132 (`/admin/auditoria`), 1039 y 1052 (`/admin/estudiantes`) | Mismos | `.datos` → `.elementos` en cada línea; el caso HU156 (1061–1073) se reescribe al contrato de D.4 (`tipoIdentificacionId`, `idPrograma`) |

La búsqueda `\.datos` sobre esos servicios y componentes, y sobre `test_all_hus.ps1` para esas rutas, debe quedar vacía en el GREEN (prueba de búsqueda en el RED del frontend).

---

## 12. Documentación, contratos y manifiestos

| Documento | Cambio |
| :--- | :--- |
| `HU-CATALOG.md` | Filas de §1.3; HU169 `[PENDIENTE]` "En espera del equipo de mensajes"; HU170 y HU177 `[PENDIENTE]` "En espera del equipo de seguridad"; HU003/HU007/HU018/HU019 con su estado real |
| `TECHNICAL_DEBT.md` (Infra y Backend) | TD-009 cerrada (D.7); TD-060 y TD-061 cerradas (D.2); TD-059 según la comprobación. **Deudas nuevas con número reservado con el orquestador** (Infra termina en TD-056 y Backend en TD-062; OBS-19): propagación BD → Azure de parámetros; caché de parámetros con varias instancias; parámetros y auditoría por institución ([SUPUESTO-D-16]); limpieza de soportes `DRAFT`/`ORPHAN`; primera página en `GET /estudiante/materias/{id}/sesiones` si una materia superara `PAGINACION/TAMANO_MAXIMO` |
| `openapi-golden-path.yaml` + `BACKEND_GOLDEN_PATH_CONTRACT.md` (Infra y Backend) | **1.6.0** (después de 1.5.0 de C; DEC-044 (11)): respuesta 406 en `GET /api/v1/realtime/stream` y operación `POST /api/v1/realtime/emit` (solo ADMINISTRADOR, cuerpo validado, 400/403/200). Ambos `.sha256` y la prueba de conformidad OpenAPI del backend en el mismo commit |
| `REALTIME_EVENT_CONTRACT.md` (Infra) y copia del backend + `.sha256` | `PARAMETER_UPDATED` (D.3, después de C, diferible) |
| `DB_DEVELOP_FREEZE_ADDENDUM.md` (BD e Infra) + `.sha256` | Secciones D.1 (fecha local de radicación) y D.8 (unidades) |
| `DB_LB004D_SUPPORT_BINDING_MANIFEST.sha256` | Líneas autorizadas por DEC-042 ampliada por DEC-044 (11): `ArchivoSoporte.sql` (D.2), `usp_radicar_solicitud_revision_asistencia_v2.sql` (D.1 y D.2), `usp_consultar_archivo_soporte_autorizado.sql` (D.2), `usp_consultar_solicitudes_revision_docente.sql` (R2, D.2), `test_lb004d_support_binding.sql` y `test_lb004d_concurrency.ps1` (D.2). No se tocan `15_lb004d_archivo_soporte.sql`, `rol_asistencias_runtime_lb004d.sql` ni `usp_registrar_archivo_soporte.sql` |
| `DB_UTC_D06_POST_FREEZE_MANIFEST.sha256` | Solo la línea `WORK_ITEM` de `rol_asistencias_runtime.sql` (D.7) |
| `DB_CULM001_D_POST_FREEZE_MANIFEST.sha256` (nuevo, solo `WORK_ITEM`) | Se **crea en el GREEN de la primera D.x mezclada** y cada D.x añade sus líneas en su GREEN: tablas `CatalogoParametroEdicion`, `CambioParametro`, `JerarquiaAltaUsuario`; vistas `uv_parametro_edicion`, `uv_soporte_reclamo`, `uv_sesion_estudiante_reclamo`; SP `usp_internal_radicar_solicitud_revision`, `usp_radicar_solicitud_revision_asistencia_v3`, `usp_actualizar_parametro`, `usp_admitir_estudiante`, `usp_validar_carga_masiva_usuarios`; función `ufn_calcular_fecha_limite_justificacion`; migraciones `20`–`28`; permisos `rol_asistencias_runtime_culm001_d*.sql` |
| `test_all_hus.ps1` | Casos HU026B (409 fuera de plazo), HU015 (radicar con 2 soportes 202), HU168 (PUT 200, 400 de rango, 403 de `RED/*`, 409 de versión), HU156 (201, 409), HU171 (validación 200 sin crear, carga 200, repetición todo `YA_EXISTE`), HU172 (evento con `idCorrelacion` tras un `PUT`), `POST /asistencias` 404, y §11.3 |
| `PRS.md` / `ESTADO.md` | PRs por D.x y B-01 para las rutas de §10 |

**Regla de regeneración (DEC-036, DEC-044 (11)):** cada línea de manifiesto y cada `.sha256` de contrato se regenera **en el mismo commit que modifica el archivo**, con `scripts/lb004d-manifest.ps1` o `scripts/freeze-manifest.ps1`, **incluidos los commits RED** que cambian `test_lb004d_support_binding.sql` o `test_lb004d_concurrency.ps1`, para que `infra.ps1 verify`/`db-test` no queden rojos por hash entre commits. Ninguna regeneración se hace antes de la aprobación 9.2 de este contrato.

---

## 13. Orden de integración, ramas y commits

### 13.1 Orden y paralelismo

| Ola | Subpaquetes (en paralelo dentro de la ola) | Condición de entrada |
| :--- | :--- | :--- |
| 1 | **D.1**, **D.3 + D.6** (comparten `AdminPortalController`, `@AuditableOperation`, `admin-system`), **D.4** | A y B.1 (hoy) |
| 2 | **D.7** | B.2 mezclado (si no llega antes del 2026-11-11: RED listo, sin retirar) |
| 2 | **D.2** | D.1 mezclado |
| 3 | **D.8** | B.2 **y B2** mezclados |
| 4 | **D.5** | D.4 y D.6 mezclados |
| 4 | **D.9-a, b, d** | D.6 y **B2** mezclados (F-ADM-026, además, tras C) |
| 5 | **D.9-c** y `PARAMETER_UPDATED` de D.3 | C mezclado (golden path 1.5.0 publicado) |

La BD local es compartida: cada D.x despliega solo sus objetos y repite `infra.ps1 db-test` tras cada mezcla (DEC-034).

### 13.2 Ramas

Una rama por D.x y repo desde `integracion/CULM-001`, en worktrees `C:\Proyectos\GestionAsistencia-CULM001-D<x>\<repo>` cuando hay paralelismo: `feature/CULM-001-D1-plazo-excusas`, `…-D2-soportes-categoria`, `…-D36-parametros-auditoria`, `…-D4-admision-estudiantes`, `…-D5-carga-masiva`, `…-D7-retiro-registro-individual`, `…-D8-kpis-horas`, `…-D9-hallazgos-medios` (D.9-c en un segundo PR). Archivos de lista compartidos (`access-catalog.json`, `SecurityConfig`, `test_all_hus.ps1`, `HU-CATALOG.md`, `TECHNICAL_DEBT.md`, `FINDINGS.md`): conflictos resueltos al mezclar, añadiendo entradas, con los gates repetidos. Remotos de Backend y BD según DEC-002.

### 13.3 Commits

Conventional Commits en español, atómicos por capa, `Refs:` con la HU o el hallazgo, y cuerpo (qué, por qué, cómo) en los commits de contrato y de manifiesto.
- **D.1** · DB: `feat(db/functions): calcular la fecha limite de justificacion` · `feat(db/views): exponer la fecha limite de reclamo por sesion del estudiante` · `feat(db/sp): consultar sesiones de la materia del estudiante` · `feat(db/sp): validar el plazo de excusas tras la reejecucion idempotente` · `fix(db/sp): guardar la fecha local de radicacion` · `test(db): cubrir el plazo de HU026B` — BE: `feat(backend/adapter): mapear el plazo vencido de justificacion` · `refactor(backend/adapter): leer sesiones del estudiante por procedimiento` — FE: `feat(frontend/estudiante): mostrar la fecha limite para justificar` — `Refs: HU026B`.
- **D.2** · DB: `feat(db/tables): persistir la categoria del reclamo` · `refactor(db/tables): permitir varios soportes por reclamo` · `refactor(db/sp): extraer la radicacion de reclamos a un procedimiento interno` · `feat(db/sp): radicar reclamos con varios soportes` · `fix(db/sp): leer estados de soporte desde parametros` · `test(db): cubrir soportes multiples y categoria` — BE: `feat(backend/usecase): radicar con lista de soportes` · `feat(backend/controller): exponer la configuracion de reclamos` · `test(backend): cubrir antivirus y limite de subidas con varios soportes` — FE: `feat(frontend/estudiante): adjuntar varios soportes al reclamo` · `feat(frontend/docente): listar soportes y categoria del reclamo` — `Refs: HU015, HU014`.
- **D.3 + D.6** · DB: `feat(db/tables): agregar metadatos de edicion e historial de parametros` · `feat(db/sp): actualizar parametros con lista blanca y rango` · `feat(db/sp): filtrar auditoria por correlacion y administracion` · `test(db): cubrir edicion de parametros` — BE: `feat(backend/usecase): actualizar parametros e invalidar cache` · `feat(backend/observability): auditar mutaciones del administrador con valores` · `test(backend): exigir auditoria en rutas admin` — FE: `feat(frontend/admin): editar parametros con tipo y rango` · `feat(frontend/admin): filtrar auditoria por correlacion` — Infra (tras C): `docs(contracts): agregar parameter_updated al contrato realtime` — `Refs: HU168, HU172`.
- **D.4** · DB: `feat(db/sp): admitir estudiantes sin matricula` · `refactor(db/sp): leer perfiles de correccion de identidad desde parametros` · BE: `feat(backend/usecase): admitir estudiantes y asegurar su cuenta` · FE: `feat(frontend/admin): agregar admision de estudiantes` — `Refs: HU156`.
- **D.5** · DB: `feat(db/sp): validar cargas masivas por jerarquia` · `fix(db/sp): recibir el tipo de documento en coordinador y decano` · BE: `feat(backend/controller): cargar cuentas por csv con validacion previa` · FE: `feat(frontend/ui): agregar carga masiva de cuentas` — `Refs: HU171`.
- **D.7** · DB: `refactor(db/sp): retirar el registro autonomo por codigo estatico` · `test(db): reemplazar pruebas del registro autonomo retirado` · BE: `refactor(backend/controller): retirar el registro individual de asistencia` · Infra: `docs(baseline): cerrar TD-009` — `Refs: HU027`.
- **D.8** · DB: `refactor(db/sp): pasar comparativas, tendencia y consolidado a horas` · BE: `feat(backend/adapter): exponer horas en comparativas y consolidado` · FE: `feat(frontend/coordinador): mostrar excusa y sin registro en el consolidado` — `Refs: HU061, HU103, HU134, HU139`.
- **D.9**: un commit por hallazgo o grupo de la misma capa, con `Refs: F-xxx-nnn`; en D.9-c, `docs(contracts): publicar golden path 1.6.0 con 406 en stream y emit admin`.
- Todo commit que cambia un archivo de LB-004D, de UTC-D06 o un contrato WORM incluye su línea de manifiesto o `.sha256` regenerada (§12). Pie `Co-Authored-By` según la configuración de la sesión.

---

## 14. Riesgos, rollback y puntos abiertos

### 14.1 Riesgos

| ID | Riesgo | Mitigación |
| :--- | :--- | :--- |
| RD-1 | Regenerar manifiestos ajenos | Lista exacta autorizada (DEC-042 + DEC-044 (11)); regeneración en el mismo commit |
| RD-2 | B.2 o B2 se retrasan (D.7, D.8, D.9-a) | Ola 1 independiente; D.7 en RED listo; D.8 diferible |
| RD-3 | Choque con C (gateway SSE, contrato de tiempo real, cierre masivo, umbrales) | D.9-c, `PARAMETER_UPDATED` y F-ADM-026 después de C; la regla cruzada de umbrales vive en BD |
| RD-4 | B-01 impide probar en pantalla las rutas nuevas | Gates de código independientes; instrucción al responsable en `PRS.md` |
| RD-5 | Aprovisionamiento parcial BD/IdP | `AsegurarCuentaIdentidadService` con estado pendiente y reparación |
| RD-6 | Datos sensibles (`clave_inicial`, `password`, valores en auditoría) | Solo en memoria; denegación por nombre exacto; pruebas de logs, respuestas, `metadata` y `GlobalExceptionHandler` |
| RD-7 | Cambios de sobre de respuesta | Consumidores enumerados con prueba (§11.3); backend y frontend del mismo D.x se mezclan juntos |
| RD-8 | Plazo | Prioridad y diferibles de §1.2 (DEC-044) |

### 14.2 Orden de rollback (DEC-044 (8))

Los `down` se aplican en **orden inverso de mezcla**. Cada objeto compartido tiene un `down` que se niega a retroceder por debajo de una versión posterior:

| Objeto compartido | Versiones (en orden) | Regla del `down` | Prueba |
| :--- | :--- | :--- | :--- |
| `usp_radicar_solicitud_revision_asistencia_v2` | LB-004D → D.1 (plazo) → D.2 (usa el interno) | El `down` de la **20** (D.1) aborta (`THROW 50020`) si existen `usp_radicar_solicitud_revision_asistencia_v3` o `usp_internal_radicar_solicitud_revision` (D.2 aplicada); el `down` de la 21 restaura la versión de D.1 | D-RB-01: aplicar 21 y ejecutar el `down` de 20 → aborta sin cambios |
| `usp_crear_decano` | Base → D.5 (`@idTipoIdIdentificacion`) → D.9 (`DEC_020`) | El `down` de la **24** (D.5) aborta (`THROW 50024`) si el texto de `usp_crear_decano` contiene `DEC_020`; el `down` de la 28 restaura la versión de D.5 (o la base si D.5 no se aplicó, comprobando la firma) | D-RB-02 |
| `usp_crear_coordinador` | Base → D.5 | Solo D.5 | D5-11 |
| `usp_consultar_sesiones_facultad_paginado` | B2 → D.9 (`@idGrupo`) | El `down` de la **28** restaura el texto de B2 | D-RB-03: el `down` de 28 deja el texto de B2 (hash) |
| Comparativas, tendencia y consolidado | B2 + B.2 → D.8 | El `down` de la **27** restaura el texto B2 + B.2 | D8-08 |
| `usp_consultar_auditoria_eventos_paginado` | Base → D.6 | Solo D.6 | D6-04 |
| `usp_corregir_identidad_usuario` | Base → D.4 | Solo D.4 | D4-12 |

Las pruebas D-RB-01…03 están en `DB:test/test_culm001_d_rollback.sql`. Revertir el PR de backend o frontend de un D.x no requiere su `down`, salvo en D.2 (v3 y el interno) y en D.7.

### 14.3 Puntos abiertos para REVIEW-2

- **Nombres en DEC-044 (3):** DEC-044 dice `usp_registrar_reclamo_v2`/`v3`. En el código se llaman `usp_radicar_solicitud_revision_asistencia_v2`/`_v3`; el contrato usa esos nombres reales y el interno `usp_internal_radicar_solicitud_revision`.
- **F-TRX-021:** DEC-044 (4) dice "404 `PLA_002` como B2". El contrato lo aplica a las mallas por plan, que ya cubre B2. En el reporte Excel por grupo, `PLA_002` (mensaje de plan) no corresponde, así que se aplica la regla DEC-025 de `/grupos/{id}/*` (403). Si el orquestador prefiere 404 también ahí, hace falta un código de grupo (`GRUP_0xx`) y cambia [SUPUESTO-D-14].
- **`PLAN.md`:** sigue con las semillas `41`–`49` y el orden de v1. Hay que pasarlo a `51`–`59` y a las olas de §13.1; no se editó en esta ronda por instrucción del orquestador.
