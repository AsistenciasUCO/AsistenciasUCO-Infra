# CULM-001 · Paquete D: REVIEW-1 (revisión independiente de contrato, sección 9.2)

> **Objeto:** `CONTRACT.md` v1 (730 líneas) y `PLAN.md` del paquete D. **Revisor:** independiente (no redactó el contrato). **Fecha:** 2026-11-07.
> **Fuentes contrastadas:** `DECISIONES.md` (DEC-022, DEC-025, DEC-028, DEC-036, DEC-037/038, DEC-040, DEC-042); `docs/PROMPT_FABLE_CULMINACION.md` §3.6 y §3.8; `AGENTS.md` §3.3 y §4; `TECHNICAL_DEBT.md` (Infra y Backend); CONTRACT de A, B, B2 (congelado, `CONTRACT.sha256`) y C.
> **Verificación en código:** worktrees `C:\Proyectos\GestionAsistencia-CULM001\*` (`integracion/CULM-001`, con A y B.1) y `C:\Proyectos\GestionAsistencia-CULM001-B\*` (rama B.2; el backend de B.2 todavía está en el commit de integración `ffc42b1f`). Comprobaciones con grep y lectura directa; las rutas y líneas citadas abajo son las observadas.
> **Formato:** cada punto lleva CUMPLE u OBJECIÓN. Las objeciones marcadas **[BLOQ-n]** impiden congelar; las **[OBS-n]** se corrigen en la v2 sin nueva ronda si el redactor las acepta tal cual.

---

## 1. Cumplimiento de §3.6 y de `AGENTS.md`

| Requisito | Resultado | Detalle |
| :--- | :--- | :--- |
| HU026B: plazo con `ASISTENCIA/DIAS_LIMITE_JUSTIFICACION` | **CUMPLE** con objeciones de diseño | El parámetro existe (`schema/seed/03_parametro.sql:40`, `5`, `INT`) y `TIEMPO/ZONA_HORARIA_SQLSERVER` también (`:46`). `ufn_obtener_parametro_int(@p_valor, @p_grupo, @p_claveDefecto)` y `ufn_obtener_parametro_texto` tienen la firma que usa el contrato. La regla vive en el SP y Java no recalcula. Ver **[BLOQ-2]** (objeto de lectura de sesiones) y **[BLOQ-3]** (orden frente a la reejecución idempotente de v2). |
| HU015: varios soportes vía API + ClamAV + MinIO, sin URLs directas | **CUMPLE** en el diseño; **OBJECIÓN** en pruebas | Subida por `POST /archivos/subir` (ClamAV `INSTREAM` → MinIO → `DRAFT`), descarga por `GET /archivos/{fileId}` con `usp_consultar_archivo_soporte_autorizado`; ningún URL de almacenamiento llega al cliente. Faltan pruebas RED de ClamAV y del límite de subidas con N archivos: **[BLOQ-7]**. |
| HU014 (MED con soporte obligatorio) | **CUMPLE** | `CategoriaJustificacion.codigo` existe (`UQ_CategoriaJustificacion_codigo`; MED/CAL/ACA/FMA/LAB/OTR en `30_categoria_justificacion.sql`). |
| HU168: tipo, rango, auditoría | **CUMPLE** con objeción de ámbito | Lista blanca en tabla satélite (DEC-042 acepta D-03; el guard de 9 columnas de `CatalogoParametro.sql` y `DB_BASELINE_CONTRACT.md` §Catalog Deploy lo justifican). Auditoría doble (`CambioParametro` + `AuditoriaEvento`). Ámbito: **[BLOQ-10]**. |
| HU156: sin matricular | **CUMPLE** con observación | `usp_sincronizar_estudiante_interno` y `usp_registrar_estudiante_en_programa_interno` existen; no hay escritura en `EstudianteGrupo` (D4-01). §3.6 dice "crea **o corrige**": si se difiere `PUT /admin/estudiantes/{id}/identidad` (§1.2), HU156 no puede pasar a "implementada": **[OBS-6]**. |
| HU171: solo roles no estudiantes, jerarquía de la alta individual, CSV con plantilla, validación previa fila por fila, confirmación | **CUMPLE** | `JerarquiaAltaUsuario` (COORDINADOR→DOCENTE, DECANO→COORDINADOR, ADMINISTRADOR→DECANO), creación por los casos de uso individuales de HU091/HU120/HU117-B, validación sin escritura (D5-01 con conteos), confirmación con huella. Estudiantes fuera. Observaciones menores en **[OBS-11]**/**[OBS-12]**. |
| HU169/HU170/HU177 en espera | **CUMPLE** | §12, con la nota "En espera de <equipo>". |
| `AGENTS.md` §3.3 (SP con `XACT_ABORT`, consultas `usp_consultar_*` sobre `uv_*`, cero datos quemados, OnPush/signals, sin polling, sin `bypassSecurityTrust*`, mensajes del backend) | **CUMPLE** en §1.4, con excepciones puntuales | Literales residuales y duplicado de parámetro de paginación: **[OBS-3]**, **[OBS-8]**, **[OBS-15]**. |
| `AGENTS.md` §3.3.5 (MinIO/ClamAV, backend stateless) | **CUMPLE** | El CSV de D.5 es transitorio (no se persiste), así que [SUPUESTO-D-09] es coherente con la regla ("antes de su persistencia en MinIO"). |
| `AGENTS.md` §4 (integridad de pruebas) | **OBJECIÓN** | La tolerancia de D8-03 está mal calculada y obligaría a relajar la prueba después: **[BLOQ-9]**. Las sustituciones de pruebas de D.7 deben citar las pruebas de B.2 por ID en el contrato: **[OBS-13]**. |

## 2. Ámbito dentro de los SP, por subpaquete

| D.x | Resultado | Detalle |
| :--- | :--- | :--- |
| D.1 | **CUMPLE** | Propiedad antes del plazo (D1-06: sesión ajena no revela su plazo). |
| D.2 | **CUMPLE** | Dueño y estado de cada archivo bajo `UPDLOCK, HOLDLOCK` en orden de `id`; descarga por archivo con el SP autorizado (D2-09). |
| D.3 | **OBJECIÓN [BLOQ-10]** | `CatalogoParametro` es global (sin institución), pero §3.8 limita al administrador a "su institución". Cualquier administrador de cualquier institución cambiaría umbrales y límites de todas. |
| D.4 | **CUMPLE** | `ADS_003` exige programa de la institución del administrador; la corrección por administrador se acota a estudiantes con `EstudiantePrograma` en su institución. |
| D.5 | **CUMPLE** | Validación por `JerarquiaAltaUsuario` + ámbito con los internos existentes, y doble defensa: la creación pasa por `usp_crear_coordinador`/`usp_crear_decano`/`usp_vincular_docente_programa`, que validan su propio ámbito. |
| D.6 | **CUMPLE** (lectura global preexistente) | `usp_consultar_auditoria_eventos_paginado` no filtra por institución (`AuditoriaEvento` no la tiene). Es previo a D; inclúyase en el mismo supuesto de [BLOQ-10]. |
| D.8 | **OBJECIÓN [BLOQ-4]** | La población por ámbito de esos 4 SP la redefine B2 (grano grupo-programa). |
| D.9 | **OBJECIÓN [BLOQ-4]** | F-TRX-021 contradice el 404 `PLA_002` congelado en B2 para las mallas por plan. El resto (F-DEC-003, F-DEC-014, R-8) valida el ámbito en el SP antes de leer: CUMPLE. |

## 3. Migraciones, datos y manifiestos

| Aspecto | Resultado | Detalle |
| :--- | :--- | :--- |
| Numeración de migraciones `20`–`28` | **CUMPLE** | Libres: A 13/14, B.1 15, B.2 16, B2 17/18, C 19 (verificado en `migrations/` y en los contratos). |
| Numeración de semillas `41`–`49` | **OBJECIÓN [BLOQ-1]** | C usa `40_culm001_c_*` **y `41_culm001_c_plantillas_notificacion.sql`** (C CONTRACT, [SUPUESTO-C-01] y §2.9). DEC-028 solo reserva "C = 40+"; no asigna nada a D, así que la cabecera atribuye a DEC-028 una regla que no dice. |
| `up/down` idempotentes y `up → down → up` | **CUMPLE** en D.1, D.3–D.8; objeciones en D.2 | D.2 `down` borra `categoriaJustificacion` y pierde las categorías persistidas: **[BLOQ-8]**. El `CREATE NONCLUSTERED INDEX IX_ArchivoSoporte_Solicitud` del bloque DDL no está guardado con `IF NOT EXISTS` (el despliegue corre `tables/` en cada `db-deploy`): **[OBS-1]**. |
| Objetos tocados por varios D.x | **OBJECIÓN [BLOQ-8]** | v2 (D.1 y D.2), `usp_crear_decano` (D.5 y D.9), `usp_consultar_sesiones_facultad_paginado` (B2 y D.9): cada `down` "restaura el texto anterior" sin fijar el orden. |
| `deploy_schema.ps1` no borra objetos | **CUMPLE** | D.7 hace `REVOKE`/`DROP` en la migración 26, como la 13 de A ("deploy_schema.ps1 no borra objetos"). El `GRANT` a nivel de objeto desaparece con el `DROP`; `rol_asistencias_runtime.sql` hace `THROW 52120` si un SP listado no existe, así que quitarlo de la lista (línea 54) es obligatorio y está previsto. |
| Regeneración de manifiestos | **OBJECIÓN [BLOQ-11]** | Ver abajo. |

**Manifiestos verificados:**
- `DB_LB004D_SUPPORT_BINDING_MANIFEST.sha256` tiene 9 líneas: `ArchivoSoporte.sql`, `15_lb004d_archivo_soporte.sql`, `rol_asistencias_runtime_lb004d.sql`, `usp_registrar_archivo_soporte.sql`, v2, `usp_consultar_archivo_soporte_autorizado.sql`, R2 (`usp_consultar_solicitudes_revision_docente.sql`), `test_lb004d_support_binding.sql`, `test_lb004d_concurrency.ps1`. D toca 6 (`ArchivoSoporte`, v2, archivo autorizado, R2 y las dos pruebas). **DEC-042 solo autoriza `ArchivoSoporte`, R2 y el SP de archivo autorizado.** Faltan v2 (dos veces: D.1 y D.2) y las dos pruebas.
- `DB_UTC_D06_POST_FREEZE_MANIFEST.sha256:15`: `rol_asistencias_runtime.sql WORK_ITEM` (autorizado por DEC-042).
- `DB_DEVELOP_FREEZE_MANIFEST.sha256` congela `schema/views/uv_sesion.sql`, que es la fuente real de `GET /estudiante/materias/{materiaId}/sesiones`: **[BLOQ-2]**.
- `openapi-golden-path.yaml` incluye `/api/v1/realtime/stream` con respuestas 200/400/401/403/500. F-TRX-019 añade un 406 y un comentario inicial a esa operación, y §12 afirma "Sin cambio (ninguna ruta de D es golden path)": **[BLOQ-11]**.

## 4. Consumidores

| Cambio | Resultado | Detalle |
| :--- | :--- | :--- |
| `ApiListResponse` → `ApiPageResponse` en 10 listados (F-ADM-023 + `/admin/parametros`) | **OBJECIÓN [BLOQ-6]** | El contrato dice "y sus servicios del frontend" sin enumerarlos. `ApiPageResponse` serializa `elementos` (no `datos`), así que todo lector de `.datos` se rompe en silencio. La lista exacta está en [BLOQ-6]. |
| Retiro de `POST /api/v1/asistencias` y del SP autónomo | **CUMPLE** con precisiones | Las pruebas se sustituyen por ausencia del objeto y de permisos (no se relajan), y la garantía SES-01 queda en B.2. Rangos de líneas incompletos y consumidores Java sin listar: **[OBS-13]**. En el frontend no hay ningún llamador de `POST …/asistencias` exacto (búsqueda en `src/app`: solo `coordinador/sesiones/{id}/asistencias`). |
| `POST /api/v1/realtime/emit` | **OBJECIÓN [BLOQ-5]** | No tiene consumidores en el frontend, pero DEC-042 decidió **mantenerlo** restringido a ADMINISTRADOR con cuerpo validado. El contrato propone retirarlo. |

## 5. Pruebas RED por regla

| Regla | Resultado |
| :--- | :--- |
| BD por subpaquete (D1-01…D9-*) | **CUMPLE**, salvo la tolerancia de D8-03 (**[BLOQ-9]**) y los casos que faltan por [BLOQ-3] y [OBS-9]. |
| Backend (caso de uso, adaptador, controlador, contrato SP, ArchUnit, `AdminMutacionesAuditadasTest`) | **CUMPLE**. |
| Frontend (specs por pantalla, móvil 375 px, sin `setInterval`) | **CUMPLE**, salvo la enumeración de [BLOQ-6]. |
| `clave_inicial` nunca en logs ni respuestas | **CUMPLE**: captura del appender, respuesta sin clave ni nombres, auditoría solo con conteos y denegación por nombre exacto en `metadata`. Además `SensitiveDataSanitizer.isSensitiveKey` no cubre `clave_inicial`/`claveInicial` (solo `password`, `token`, `secret`…), así que la lista de denegación de D.6 es necesaria y su prueba también. Observación en [OBS-12]. |
| Rate limit y ClamAV de los soportes | **OBJECIÓN [BLOQ-7]**: ninguna prueba de D.2 los ejercita con N archivos. |
| Rate limit de la carga CSV (429 `CMA_014`) | **CUMPLE** (`SlidingWindowRateLimiter` ya está en integración; ver [OBS-2]). |

## 6. Datos quemados, secretos y choques de códigos

- **Mensajes:** `REV_020`–`REV_025`, `PRM_001`–`PRM_011`, `ADS_001`–`ADS_006`, `CMA_001`–`CMA_015`, `DEC_020`, `NTF_020`/`NTF_021` no existen en las semillas de integración ni de B.2 (existen `REV_001`–`REV_008`, `DEC_001`–`DEC_003`, `NTF_001`–`NTF_009`, `ARC_001/002/003/005`), ni en Java, ni en los contratos de A, B, B2 y C. **CUMPLE.**
- **Prefijos** `culm001_d<x>` y el manifiesto `DB_CULM001_D_POST_FREEZE_MANIFEST`: sin choque con `culm001_a`, `culm001_b1`, `culm001_b2`, `culm001_b2nm`, `culm001_c`. **CUMPLE.**
- **Semillas:** **[BLOQ-1]**.
- **Secretos:** la lista blanca excluye URLs, nombres de secreto y `RED/*`; F-TRX-011 quita el valor por defecto de la clave SA. **CUMPLE** (observación operativa en [OBS-16]).
- **Datos quemados:** **CUMPLE**, salvo [OBS-3] (tipos `BOOLEAN`/`STRING` en `ufn_validar_valor_parametro`), [OBS-8] (`N'A'` → parámetro de A) y [OBS-15] (`GENERAL/TAMANO_PAGINA_MAXIMO` duplica `PAGINACION/TAMANO_MAXIMO`).

## 7. Dependencias

| Dependencia | Resultado |
| :--- | :--- |
| D.7 tras B.2 (backend y BD) | **CUMPLE**. B.2 retira el consumidor ([SUPUESTO-B-18]) y no toca permisos; hoy `AsistenciaQrController` (`POST /estudiante/asistencia-qr`) y `AsistenciaJpaRepository:43` siguen usando el SP autónomo, también en la rama B.2. |
| D.8 tras B.2 (BD) | **OBJECIÓN [BLOQ-4]**: también tras B2 (17 y 18). |
| D.9-a tras D.6 | **OBJECIÓN [BLOQ-4]**: también tras B2 (F-DEC-014 y los listados del decano de F-ADM-023 tocan objetos que B2 reescribe). Para F-ADM-026, conviene esperar a C, que modifica `POST /admin/cierre-masivo` (nuevo 409 `RCN_012`). |
| D.9-c tras C | **CUMPLE** (C modifica `RealtimeEventsController`, `RealtimeAudienciaPolicy` y el golden path a 1.5.0). |
| D.3 `PARAMETER_UPDATED` y C | **OBS-14**: C y D editan `REALTIME_EVENT_CONTRACT.md` y su `.sha256`; la parte diferible de D.3 va después de C. |
| D.5 tras D.4 y D.6 | **CUMPLE**. |
| PDP (B-01, DEC-037/038) | **CUMPLE**: gates de código independientes, prueba en pantalla condicionada y anotada en `PRS.md`. |

## 8. Alcance frente al plazo (2026-11-13)

**Confirmo** el orden **D.1, D.3, D.4, D.6, D.7 > D.2, D.8 > D.5, D.9**, con tres precisiones:

1. **D.7** es "no diferible" pero depende de B.2, cuyo backend no ha empezado (la rama B.2 está en el commit de integración). Si B.2 no se mezcla antes del 2026-11-11, D.7 debe quedar en RED listo y con TD-009 abierta; no hay que retirar la ruta antes que B.2.
2. **Dentro del segundo nivel, D.2 va antes que D.8.** HU015/HU014 están en §3.6. D.8 no está en §3.6 y, tras [BLOQ-4], depende de B.2 y de B2. D.8 es el primer candidato a diferir de ese nivel.
3. **D.5 es alcance explícito de §3.6 (HU171).** Si se difiere, CLOSURE debe declararlo como incumplimiento de §3.6, no como "propuesta". Recomiendo entregar al menos el tramo coordinador → docentes (ya previsto en §1.2).

**Diferir primero, en este orden:** D.9-c, D.9-d, `PARAMETER_UPDATED` y el historial de D.3, los filtros de pantalla de D.6, las plantillas de decano y administrador de D.5, y D.8. **No diferir** `PUT /admin/estudiantes/{id}/identidad` sin dejar HU156 en `[PARCIAL]` ([OBS-6]).

---

## Objeciones bloqueantes y corrección exacta

**[BLOQ-1] Choque de numeración de semillas con C.** C usa `41_culm001_c_plantillas_notificacion.sql`; D.1 usa `41_culm001_d1_mensajes.sql`. *Corrección:* semillas de D = `50 + x` (D.1 = `51` … D.9 = `59`) en la cabecera, §0–§11, §13 y `PLAN.md` (línea 5). La cabecera debe decir que DEC-028 no reserva semillas para D. Hay que registrarlo en `DECISIONES.md` como precisión de DEC-028 (D = migraciones 20–28, semillas 51–59).

**[BLOQ-2] D.1: la lectura de sesiones del estudiante no está identificada y su fuente está congelada.** `GET /estudiante/materias/{materiaId}/sesiones` sale de HQL en `SesionMateriaEstudianteJpaRepository` (`UvSesionEntity`, `UvEstudianteGrupoEntity`, `UvGrupoEntity`), y `uv_sesion.sql` está en `DB_DEVELOP_FREEZE_MANIFEST.sha256`. "El RED lo localiza" no es un contrato. *Corrección:* objeto nuevo `uv_plazo_justificacion_sesion` (`idSesion`, `fechaLimiteJustificacionUtc` = `ufn_calcular_fecha_limite_justificacion(fechaHoraFin)`, `plazoJustificacionVigente`), más una de dos rutas: (a) un SP nuevo `usp_consultar_sesiones_materia_estudiante` (ámbito del estudiante en el SP, preferido por §3.3), o (b) una entidad JPA de solo lectura sobre la vista unida en la HQL existente. Sin tocar `uv_sesion`. D1-10 se reescribe contra el objeto nuevo. La firma y las columnas quedan en el contrato.

**[BLOQ-3] D.1/D.2: v2 como envoltorio de v3 y el orden del plazo.** (a) Para conservar el resultset de 4 columnas de v2 habría que capturar el de v3 con `INSERT … EXEC`, y v3 hace `ROLLBACK`/`SAVE TRANSACTION`. SQL Server lo prohíbe dentro de `INSERT-EXEC` (Msg 3915; es el mismo hallazgo registrado en DEC-036). (b) v2 tiene reejecución idempotente por correlación ("Reintento con la misma correlacion tras un exito => exito idempotente", cabecera del SP). Si el plazo se valida antes, un reintento legítimo tras el vencimiento devolvería `REV_020`. *Corrección:* extraer `usp_internal_radicar_solicitud_revision` (parámetros `OUTPUT`: tupla, `idSolicitudRevision`, `totalSoportes`). v2 y v3 lo invocan y cada uno emite su propio resultset. Orden: correlación → RBAC → propiedad/asistencia → **reejecución idempotente** → plazo → resto. Pruebas nuevas: D1-12 (reintento con la misma correlación después del vencimiento → éxito idempotente, 0 filas nuevas) y D2-15 (lo mismo en v3, sin adjuntar dos veces).

**[BLOQ-4] Choques con B2 (contrato congelado, `CONTRACT.sha256` `9b668c7d…`).**
- (a) B2 §5 (líneas 471 y 489) fija **404 `PLA_002`** para `GET /coordinador/planes-estudio/{id}/asignaturas` y `GET /decano/planes-estudio/{planId}/asignaturas` cuando el plan no existe o está fuera de ámbito, y cubre F-DEC-015. D.9 F-TRX-021 y [SUPUESTO-D-14] les ponen 403. *Corrección:* quitar esas dos rutas de F-TRX-021 (queda solo `GET /grupos/{id}/reportes/asistencia-excel`), acotar [SUPUESTO-D-14] a las rutas por grupo y quitar de §11 la frase "es la regla que A y B2 ya aplican" para las mallas.
- (b) B2 §2.7.4 (líneas 339–346) reescribe `usp_consultar_tendencia_ausentismo`, las dos comparativas, `usp_consultar_consolidado_asistencia_grupos_paginado` (grano **grupo, programa del ámbito**) y `usp_consultar_sesiones_facultad_paginado`, y cambia columnas de `/decano/asignaturas`. *Corrección:* D.8 y D.9-a dependen de B2 mezclado (migraciones 17 y 18) además de B.2 (§1.1, §13.1, `PLAN.md`). Las fórmulas de D.8 se escriben sobre `uv_resumen_asistencia_estudiante_programa_grupo` (que ya trae las columnas de horas de B.2) y el consolidado sobre el grano de B2. El `down` de 27 restaura el texto B2 + B.2.

**[BLOQ-5] `POST /realtime/emit` contradice DEC-042.** DEC-042: "se mantiene restringido a ADMINISTRADOR con cuerpo validado (400 ante `{}`)". El contrato (§10 y F-TRX-016) lo retira "o" lo restringe. *Corrección:* una sola opción. Se mantiene solo ADMINISTRADOR (ya está en `SecurityConfig.java:215`), con tipo de evento del contrato realtime, audiencia obligatoria, 400 `VALIDATION_ERROR` ante `{}` o tipo desconocido, y pruebas 400/403 (DOCENTE)/200. En §10, la fila pasa de "retirada" a "cambia la validación". `GET /realtime/status` → solo ADMINISTRADOR sin cambios.

**[BLOQ-6] Consumidores del cambio de sobre sin enumerar.** `ApiPageResponse` usa `elementos`; `ApiListResponse` usa `datos`. *Corrección:* §11 F-ADM-023 lista, cada uno con su spec:
- **Frontend:** `core/services/consultas-transversales.service.ts` (`listar`, `getProgramasCreditos`, `getDocentesFacultad`, `getDocentesInstitucion`, `buscarAsignaturas`, `buscarEstudiantes`, `getAuditoria`); `core/mocks/mock-consultas-transversales.ts`; `core/interceptors/mock-backend.interceptor.ts`; `core/services/dean-facultad.service.ts` (`/decano/sesiones`, que B2 también toca); `core/services/admin-management.service.ts` (`/admin/parametros`); `core/services/attendance-claim.service.ts` (400 de paginación); y los componentes `admin-estudiantes`, `admin-system/admin-auditoria`, `dean-docentes`, `dean-asignaturas`, `dean-estudiantes`, `dean-programas`, `dean-grupo-detalle`, `dean-cronograma` y `dean-faculty`.
- **Backend:** pruebas de `AdminConsultasTransversalesController`, `DecanoConsultasTransversalesController` y `DecanoFacultadConsultaController` (helpers `lista(PaginaDTO)`).
- **E2E:** `AsistenciasUCO-Infra/scripts/tests/test_all_hus.ps1` lee `.datos` en las líneas 961–966 (`/decano/docentes`), 999 (`/decano/sesiones`), 1022–1027 y 1132 (`/admin/auditoria`) y 1039/1052 (`/admin/estudiantes`). Pasan a `.elementos`. El caso HU156 (1061–1073) usa `tipoIdentificacionId` y no envía `idPrograma`: se reescribe al contrato de D.4 (ver [OBS-5]).

**[BLOQ-7] Faltan pruebas RED de ClamAV y del límite de subidas con varios soportes.** *Corrección:* en §3.3/§3.4 añadir:
- **Backend:** una secuencia de 3 subidas en la que el archivo infectado (firma EICAR en el doble de ClamAV) se rechaza con el código existente y no produce `fileId`, mientras los otros dos quedan `DRAFT`; la subida número `ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO + 1` en un minuto da 429; radicar con un `fileId` inexistente o `ORPHAN` da `ARC_001` sin escrituras; `GET /configuracion/reclamos` devuelve `tamanioMaximoBytes` ≤ límite multipart.
- **Frontend:** 429 e infectado mostrados por archivo con el `message` del backend; "Enviar" desactivado hasta que todas las subidas terminen; nunca se envía una lista con ids fallidos.

**[BLOQ-8] Pérdida de datos en el `down` de D.2 y orden de los `down` entre D.x.** *Corrección:*
- (a) Antes de quitar la columna, el `down` de 21 copia `(id, categoriaJustificacion)` a `zz_archivo_SolicitudRevisionCategoria_culm001_d2` y el mapa de soportes colapsados `(idArchivo, idSolicitud)` a `zz_archivo_SoporteColapsado_culm001_d2` (patrón DEC-010, sin FK ni GRANT). Al pasar a `ORPHAN` deja `solicitudRevisionAsistencia`, `fechaAdjuncionUtc` e `idCorrelacionAdjuncion` en `NULL` (`CK_ArchivoSoporte_EstadoVinculo`).
- (b) Nueva sección "Orden de rollback": los `down` se aplican en orden inverso de mezcla. El `down` de D.1 aborta (`THROW`) si existe v3 (D.2 aplicada), y el de D.5 aborta si `usp_crear_decano` contiene la firma de D.9 (`DEC_020`). Igual para cualquier otro objeto compartido. Cada caso con su prueba.

**[BLOQ-9] Tolerancia de D8-03 incorrecta.** Cuatro porcentajes `DECIMAL(5,2)` redondeados por separado pueden sumar 100 ± 0,02, no ± 0,01. La prueba daría un rojo espurio o habría que relajarla, y §4 de `AGENTS.md` lo prohíbe. *Corrección:* el SP calcula tres porcentajes con `ROUND(…, 2)` y el cuarto como `100 − suma` (o por mayor resto), y D8-03 exige exactamente `100.00` (0 si `D = 0`).

**[BLOQ-10] Ámbito de la edición de parámetros (y de la auditoría) frente a §3.8.** `CatalogoParametro` y `AuditoriaEvento` son globales; §3.8 limita al administrador a "su institución". *Corrección:* añadir **[SUPUESTO-D-16]**: "Los parámetros de negocio son de toda la instalación, que tiene una sola institución. `usp_actualizar_parametro` comprueba que hay exactamente una `Institucion` activa y, si hay más, responde `PRM_003` hasta que exista parámetro por institución (deuda nueva)". La misma nota vale para la lectura de auditoría. Necesita aceptación del orquestador en `DECISIONES.md`.

**[BLOQ-11] Manifiestos y contratos WORM: autorización incompleta y golden path.** *Corrección:*
- (a) DEC-042 se amplía (o una DEC nueva) con la lista exacta: LB-004D, las 6 líneas (`ArchivoSoporte.sql`, v2 en D.1 y en D.2, `usp_consultar_archivo_soporte_autorizado.sql`, R2, `test_lb004d_support_binding.sql`, `test_lb004d_concurrency.ps1`); UTC-D06, 1 línea; los `.sha256` de `DB_DEVELOP_FREEZE_ADDENDUM.md` (BD e Infra) y de `REALTIME_EVENT_CONTRACT.md` (Infra y la copia del backend).
- (b) Cada línea se regenera en el **mismo commit** que modifica el archivo (DEC-036), con `scripts/lb004d-manifest.ps1`/`freeze-manifest.ps1`. Eso incluye el commit RED que cambia `test_lb004d_support_binding.sql` (su aserción de la línea 112 sobre `UX_ArchivoSoporte_Solicitud` también cambia), para no dejar el gate rojo durante el RED.
- (c) `DB_CULM001_D_POST_FREEZE_MANIFEST` se crea en el GREEN de la primera D.x mezclada y cada D.x añade sus líneas (no puede generarse "tras la aprobación 9.2", antes de que existan los archivos).
- (d) F-TRX-019: el 406 en `/api/v1/realtime/stream` cambia una operación del golden path. O se formaliza como enmienda tras el 1.5.0 de C (versión, `.sha256` y prueba de conformidad), o se quita el 406 de D y quedan solo el comentario inicial y la comparación de GUID sin mayúsculas. En los dos casos se corrige la fila "Sin cambio" de §12.

## Observaciones no bloqueantes (corregir en la v2)

- **[OBS-1]** `ArchivoSoporte.sql`: guardar `CREATE NONCLUSTERED INDEX IX_ArchivoSoporte_Solicitud` con `IF NOT EXISTS` y cambiar el comentario "A lo sumo un soporte por solicitud".
- **[OBS-2]** `CanonicalStoredProcedureExecutor` no existe. Lo que hay es `JpaProcedureExecutor`/`CanonicalProcedureResult` (`…/persistence/sqlserver/support/procedure/`). `SlidingWindowRateLimiter` está en `infrastructure/adapter/primary/controller/filter/` y ya está en integración (no viene de B).
- **[OBS-3]** `ufn_validar_valor_parametro`: no ramificar por los literales `BOOLEAN`/`STRING`/`NVARCHAR`. Si hay `valoresPermitidos` → pertenencia; si el tipo está en `PARAMETROS/TIPOS_NUMERICOS` → conversión y rango; si no → longitud.
- **[OBS-4]** `CatalogoParametro.fechaModificacion` es `DATETIME` (1/300 s). Fijar en el contrato que `fechaModificacionEsperada` viaja en UTC con milisegundos y probar el viaje de ida y vuelta (un valor `.007` debe coincidir).
- **[OBS-5]** D.4: usar `tipoIdentificacionId` (convención de F-ADM-011 y del E2E), no `idTipoIdentificacion`.
- **[OBS-6]** Si se difiere `PUT /admin/estudiantes/{id}/identidad`, HU156 queda `[PARCIAL]` ("crea o corrige", §3.6). Aclarar además el texto de `usp_corregir_identidad_usuario`: el `CASE` con literales existe (línea 47) y se reemplaza por `IDENTIDAD/PERFILES_CORRECCION_ESTUDIANTE`, con una rama de ámbito por perfil.
- **[OBS-7]** `usp_consultar_auditoria_eventos_paginado` tiene `@soloAsistencia BIT = 1` **por defecto**. Con `@soloAdministracion = 1` y el defecto, la regla "los dos a la vez → error" fallaría siempre. Hay que definir que el backend envía los dos explícitos o que `@soloAdministracion = 1` implica `@soloAsistencia = 0` salvo que se pase 1, y añadir D6-05.
- **[OBS-8]** D.8: el literal `N'A'` pasa a `MATRICULA/ESTADO_INSCRITA` (parámetro de A que C reutiliza), no a `ufn_obtener_estado_estudiante_grupo`.
- **[OBS-9]** `PARAMETROS/GRUPOS_NO_EDITABLES = RED,TIEMPO,GENERAL,PARAMETROS` no cubre `REGISTRO`, `IDENTIDAD`, `RECLAMO`, `TOMA_ASISTENCIA`, `AUDITORIA` ni `PAGINACION`, que la tabla declara "nunca". Incluirlos en el parámetro o reescribir la fila y D3-15.
- **[OBS-10]** D.5: el parámetro nuevo `@idTipoIdIdentificacion` de `usp_crear_coordinador`/`usp_crear_decano` va **al final** de la firma.
- **[OBS-11]** D.5: la regla de inyección de fórmulas no aplica a `clave_inicial` (una clave válida puede empezar por `@`, `+` o `-`, y la clave nunca se reexporta). Hay que probarlo.
- **[OBS-12]** D.4/D.5: añadir una prueba de que `password` (admisión) no llega a `metadata` de auditoría ni a los logs del `GlobalExceptionHandler`, igual que para `clave_inicial`.
- **[OBS-13]** D.7: `test_ses01_ventana_asistencia.sql` bloque J ocupa las líneas 196–240 (tres casos: `SES01_AUTO_CLOSED`, `SES01_AUTO_BEFORE_START`, `SES01_AUTO_INDETERMINATE`), no 196–225. `test_attendance_commands.sql` sigue después de la 460 (caso `VAL_007`). Añadir `DbFailureClassifier.java:176` (comentario) y `DbFailureClassifierVentanaAsistenciaTest`. Citar en el contrato los IDs de las pruebas de B.2 que heredan la garantía SES-01, no solo en el commit.
- **[OBS-14]** D.3 `PARAMETER_UPDATED`: se mezcla después de C (los dos editan `REALTIME_EVENT_CONTRACT.md`).
- **[OBS-15]** `GENERAL/TAMANO_PAGINA_MAXIMO` duplica `PAGINACION/TAMANO_MAXIMO = 100` (`16_modalidad_jornada_programa.sql:38`) y su mensaje `PAG_001`. Reutilizarlos.
- **[OBS-16]** F-TRX-011: al quitar el valor por defecto de `MSSQL_SA_PASSWORD`, `infra.ps1` y un `.env.example` deben aportarlo; si no, `db-deploy`/`db-test` dejan de arrancar en checkouts sin `.env`.
- **[OBS-17]** F-EST-024: `UnmappedRouteFilter` va **después** de la autenticación (un anónimo sigue recibiendo 401). Probarlo.
- **[OBS-18]** F-ADM-008: no editar `AGENTS.md` §2.3 desde D (es gobernanza). Registrar la parte de catálogos acotados como "no-se-corrige (propuesta)" en `FINDINGS.md` y CLOSURE, y que el orquestador lo confirme (DEC-042 habla de "listados admin/decano" en general).
- **[OBS-19]** Las deudas nuevas (§12) llevan número. Infra termina en TD-056 y Backend tiene TD-062: reservar números con el orquestador para no chocar con otros paquetes.
- **[OBS-20]** §11: listar los objetos de la migración `28_culm001_d9_*` (hoy solo el nombre) y nombrar `usp_reintentar_notificacion_saliente` en F-ADM-027.

---

**VEREDICTO: CON OBJECIONES. No se congela.** Hay 11 bloqueantes:
1. Semillas `41` que chocan con C.
2. Objeto de lectura de sesiones congelado y sin identificar.
3. v2→v3 con `INSERT-EXEC` y el orden frente a la reejecución idempotente.
4. Choques con B2 (404 `PLA_002` y SP reescritos; dependencia de B2 para D.8 y D.9-a).
5. `realtime/emit` contra DEC-042.
6. Consumidores de `ApiPageResponse` (frontend, backend y E2E `.datos`) sin enumerar.
7. Pruebas de ClamAV y del límite de subidas para N soportes.
8. `down` de D.2 con pérdida de categorías y orden de rollback entre D.x.
9. Tolerancia de D8-03.
10. Supuesto de ámbito global de parámetros y auditoría frente a §3.8.
11. Autorización completa de manifiestos, regeneración en el mismo commit y golden path de `/realtime/stream`.

Corregidas, y con las DEC de [BLOQ-1], [BLOQ-10] y [BLOQ-11] registradas, basta una REVIEW-2 de verificación.
