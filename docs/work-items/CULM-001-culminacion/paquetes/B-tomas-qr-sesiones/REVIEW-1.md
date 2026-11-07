# CULM-001 · Paquete B — REVIEW-1 (revisión independiente de contrato, sección 9.2)

> **Revisor:** Opus independiente (no redactó el contrato). **Fecha:** 2026-11-07.
> **Objeto:** `CONTRACT.md` (BORRADOR, 1347 líneas) y `PLAN.md` del paquete B.
> **Fuentes contrastadas:** `PROMPT_FABLE_CULMINACION.md` §3.2-3.4, 3.7, 3.10; `DECISIONES.md` DEC-011..DEC-018 y DEC-022; `RESEARCH-MODELO-ACTUAL.md` §2 y §7; `AGENTS.md` §2.4, §3.3, §4; contrato del paquete B2 (por solapamiento).
> **Verificación propia en los worktrees** (`C:\Proyectos\GestionAsistencia-CULM001\<repo>`, rama `integracion/CULM-001`): grep de DDL, SP, pruebas y fixtures; lectura de `freeze-manifest.ps1`, `verify-contracts.ps1`, `rol_asistencias_runtime.sql`, `verify_runtime_role_login.ps1`, `openapi-golden-path.yaml`, `OpenApiGoldenPathConformanceTest`, `LocalSseRealtimeStreamGateway`; ejecución de `verify-contracts.ps1 -Root C:\Proyectos\GestionAsistencia-CULM001`; dos pruebas en `tempdb` del contenedor `sql_server_asistencias` (sin tocar la BD del proyecto) para confirmar el comportamiento de `ALTER COLUMN` y de `INSERT … EXEC`.
> **Leyenda:** CUMPLE · OBJECIÓN (B = bloqueante, NB = no bloqueante) + detalle + corrección exacta.

---

## 1. Reglas de la sección 3 y de AGENTS.md

### 1.1 Regla 3.2: ventana con tolerancia y margen para abrir tomas y generar el QR

**CUMPLE.** `usp_validar_sesion_ventana_registro_interno` recibe `@toleranciaMinutos`/`@margenMinutos` opcionales (NULL = 0). Los llamadores congelados siguen con la regla estricta, como dice DEC-014. Abrir toma, generar QR, registrar por toma y registrar por token usan `[inicio − TOLERANCIA, fin + MARGEN)`. El rechazo de sesiones canceladas (`SES_010`) se lee después del `UPDLOCK` sobre `Sesion` (§2.7.1). Las pruebas B1-VEN-01..05 cubren los bordes y dejan intacto `test_ses01_ventana_asistencia.sql`.

- **NB-1 (mapeo HTTP de `SES_010`):** en `/asistencias/lote`, `SES_007/008/009` salen como `ERR_SESION_*`, pero `SES_010` saldría crudo. El 409 del golden path es un `$ref` único (`components/responses/SesionFueraDeVentana`, yaml:999), así que no se puede "añadir una respuesta 409 de ejemplo" aparte.
  - **Corrección:** traducir `SES_010` → `ERR_SESION_CANCELADA` en `DbCodeTranslator`, igual que los otros códigos de ventana.
  - Ampliar la descripción de `SesionFueraDeVentana` con ese código y convertir su `example` en `examples` (`cerrada`, `cancelada`) en lugar de crear otra respuesta 409.

### 1.2 Regla 3.3: modo por toma, `horasToma = duración / nTomas`, porcentaje por horas, una toma = comportamiento actual

**CUMPLE en diseño.** Se cumple con `TomaAsistencia` (DEC-011), la toma vigente en `usp_sincronizar_asistencia_estudiante_interno` (DEC-013), `ufn_horas_*` y `uv_resumen_*` por horas. Las pruebas B2-TOM-01/02 y B2-HOR-01..06 cubren las reglas, incluidas "2 tomas", "sesión cancelada" y "EX fuera de faltas y dentro del denominador".

- **B-8 (conflicto textual con DEC-012):** dos puntos del contrato contradicen el texto de esa decisión cerrada.
  - DEC-012 define `horasDictadas` como "Σ horasToma de **tomas cerradas** de sesiones vencidas con registro". [SUPUESTO-B-05] cuenta todas las tomas y usa `horasSesion` aunque la sesión no tenga tomas (por ejemplo, la cabecera `Asistencia` que crea un reclamo sin detalle).
  - DEC-012 dice "conservando las columnas actuales y añadiendo las de horas". El contrato cambia la semántica de `porcentajeInasistencia`, que conserva el nombre y pasa a horas (§7.3-1).
  - Técnicamente apruebo las dos opciones del contrato, porque son las que conservan "una toma = comportamiento actual" y no dejan consumidores sin migrar. Pero el revisor no puede congelar un contrato que contradice una decisión cerrada sin que conste por escrito.
  - **Corrección:** antes de congelar, registrar en `DECISIONES.md` una entrada (DEC-0xx, paquete B) que precise DEC-012. Debe decir que (a) `horasDictadas` = Σ `horasSesion` de sesiones vencidas, con registro (`Asistencia` o `TomaAsistencia`) y no canceladas, sin mirar el estado de la toma, y (b) `porcentajeInasistencia`/`codigoPermanencia` cambian de semántica a horas conservando el nombre, con `porcentajeInasistenciaSesiones` solo para trazabilidad.

- **NB-2 (unidades mezcladas):** `faltasSinJustaCausa`, `asistencias` y `excusas` pasan a contar tomas, mientras `sesionesEjecutadas` sigue contando sesiones. Varios SP los exponen juntos: `usp_consultar_alerta_temprana_programa.sql:68,82`, `usp_consultar_historial_estudiante.sql:105-107` y `usp_consultar_resumen_asistencia_estudiante_programa.sql:41-43`.
  - **Corrección:** documentar en el addendum de BD y en el catálogo de HUs que esas columnas cuentan **tomas**.
  - Que los SP de §2.9 que las exponen añadan `tomasDictadas` junto a `sesionesEjecutadas`.

### 1.3 Regla 3.4: QR y PIN rotativos, validaciones, idempotencia, faltantes, concurrencia 5×40 y `sessionQrEnabled`

**CUMPLE.**
- Token y PIN se generan en el backend, la BD solo guarda el hash SHA-256 y la rotación la hace el scheduler (patrón HU176B).
- Se valida matrícula `A` (`AQR_004`), toma abierta (`AQR_005`) y ventana.
- Un registro por estudiante y toma es idempotente (`@soloSiNoExiste`, `AQR_008`) y no pisa una marca previa del docente.
- La lista de faltantes se muestra con marcación a mano dentro de la ventana, y el cierre QR marca `SJC`.
- La prueba 5×40 se hace en BD y en backend, y `sessionQrEnabled = true`.

- **B-9 (límite por IP mal dimensionado para el NAT del campus):** [SUPUESTO-B-12] calcula 600/min para 5 grupos × 40 estudiantes. Pero la clave `ip:<ip>` es **una sola para todo el campus** detrás del NAT.
  - Con más de 15 grupos registrando en el mismo minuto (cambio de clase), el filtro devuelve 429 a salones completos.
  - Eso viola 3.4: "rate limit que no bloquee a un salón completo detrás de la misma IP de NAT del campus" con "varios docentes con varios grupos al mismo tiempo".
  - El riesgo que se quiere frenar (adivinar PIN) está acotado por el límite por estudiante (6/min) y por `AQR_004`: un PIN válido de otro grupo no escribe.
  - **Corrección:** la clave por IP debe contar **solo intentos rechazados** (`AQR_001`, `AQR_007`, `AQR_005`, `VALIDATION_ERROR`). El filtro consulta el contador antes de la llamada y lo incrementa en `finally` si el estado de la respuesta es ≥ 400 y ≠ 429.
  - Los registros exitosos o idempotentes (200/201) no consumen cupo por IP. Los límites por estudiante y por token siguen contando todos los intentos.
  - Renombrar el parámetro a `ASISTENCIA_QR/LIMITE_FALLIDOS_IP_POR_MINUTO` (o documentar la semántica de `LIMITE_IP_POR_MINUTO`).
  - Añadir a `AsistenciaQrConcurrenciaIT` una ronda de 20 grupos × 40 desde `127.0.0.1` sin ningún 429.
- **NB-3 (orden de controles):** §3.2.7 pone el interruptor antes del límite por IP, pero `AsistenciaQrRateLimitFilter` corre antes del controlador.
  - **Corrección:** fijar el orden real: filtro de IP → interruptor → CIDR → estudiante → token.
- **NB-4 (rendimiento 5×40):** cada registro por token toma `Sesion WITH (UPDLOCK, HOLDLOCK)`, así que los 40 registros de un grupo se serializan. Con 10-15 ms por transacción, el registro 40 espera unos 0,5 s y el objetivo p95 < 500 ms queda al límite. Es aceptable porque evita deadlocks, pero hay que medirlo.
  - **Corrección:** mantener el bloqueo y dejar que el IT registre p50/p95/máximo por grupo.
  - Si p95 ≥ 500 ms, la alternativa aprobada de antemano es: en `usp_registrar_asistencia_por_token`, validar la ventana con una lectura `WITH (HOLDLOCK)` (compartida) en lugar de `UPDLOCK`. La cancelación (U/X) sigue serializada contra los registros, y el registro no actualiza `Sesion`, así que no hay conversión de bloqueo.

### 1.4 Regla 3.7: festivos

**CUMPLE.**
- El modelo `SesionCancelacion` lo comparten los festivos y HU047 (DEC-016) y se ve en los cinco roles mediante `uv_sesion_estado` y los DTOs.
- Una sesión cancelada no cuenta horas y no permite abrir tomas (`SES_010`).
- `CalendarioFestivosPort` tiene 3 adaptadores, con proveedor, URL y orden en parámetros; la key de feriados.io va por `SecretVaultPort`.
- `DiaFestivo` es la SSOT y la BD nunca llama a internet.
- La carga es por job y por administrador, y los grupos ya creados se tratan con `usp_aplicar_festivos_*` (solo futuras sin asistencia; las demás se reportan).
- La atribución sale de parámetros.
- Verifiqué a mano la tabla §3.4.1 para 2026 (Pascua 5-abr) y 2027 (Pascua 28-mar): las 19 fechas de cada año son correctas, incluido Chiquinquirá 13-jul-2026 y 12-jul-2027.
- La fecha local de B1-FES-13 está bien planteada.

- **NB-5 (festivos que coinciden en la misma fecha):** en algunos años dos festivos móviles caen el mismo lunes; por ejemplo, Sagrado Corazón y San Pedro el 5-jul-2038 (y ya pasó en 2011). `UQ_DiaFestivo_fecha` y `FES_002` ("fecha repetida") rechazarían el conjunto, y el total sería 18, no 19. El rango admitido llega hasta 2100.
  - **Corrección:** `ObtenerFestivosConRespaldoService` fusiona los festivos de la misma fecha (nombres unidos con " / ") antes de llamar al SP.
  - El cálculo local devuelve "19 o menos si coinciden".
  - Añadir 2038 a `CalculoLocalFestivosColombiaAdapterTest`.
- **NB-6 (cobertura de B1-FES-06):** la prueba no lista San Pedro ni Día de la Raza de 2026 (no se trasladan ese año) ni todos los fijos de 2027.
  - **Corrección:** "una sesión en cada una de las 19 fechas de 2026 y de las 19 de 2027 de la tabla §3.4.1".

### 1.5 HU047: cancelar con justificación, sin horas, aviso a estudiantes

**CUMPLE.** Lo cubren `usp_cancelar_sesion`, `SES_011/012/013`, la plantilla `SESION_CANCELADA` por `NotificacionPort`, el evento SSE y las pruebas B1-CAN-01..07.

- **NB-7 (cancelación retroactiva):** [SUPUESTO-B-10] permite cancelar una sesión ya vencida sin registros. Eso saca de `sesionesProgramadas` y `vencidas` la sesión que el docente no dictó, y altera el cumplimiento HU065 que lee el coordinador. Es lo contrario de la opción conservadora (§9.3).
  - **Corrección:** el docente solo cancela mientras `SYSUTCDATETIME() < ventanaCierreUtc` (fin + margen).
  - Después de eso: nuevo `SES_016` (409, "La sesión ya terminó; no se puede cancelar"), con su prueba B1-CAN-08.
  - Si el responsable quiere cancelación retroactiva, que la decida en `DECISIONES.md`.

### 1.6 Regla 3.10: móvil y tablet, QR legible, cámara nativa, `inputmode="numeric"`

**CUMPLE.** El contrato fija: QR de al menos 60 vmin y PIN de al menos 10 vmin; cámara nativa sin `getUserMedia`; `inputmode="numeric"`, `pattern`, `autocomplete="one-time-code"`; objetivos táctiles de 44-48 px; tarjetas por debajo de `md`; recorrido a 375 × 812; respaldo por PIN.

- **NB-8 (token en la URL de retorno):** el token `?t=` viaja en `returnUrl` durante el login.
  - **Corrección:** el `authGuard` debe guardar `returnUrl` del lado del cliente (`sessionStorage`) y no mandarlo al IdP en `redirect_uri` ni en `state`, para que no quede en los logs de Keycloak.
  - Añadir un spec que lo compruebe.

### 1.7 AGENTS.md

**CUMPLE** en los SP con `SET XACT_ABORT ON` y transacción con ownership/savepoint (§2.0), y en cero literales mediante columnas bandera (`UQ_*_esAutomatica`, `usaCodigoQr`, `estaAbierta`). El índice filtrado por `fechaCierreUtc IS NULL` es una buena solución que evita la excepción literal de HU176B.

También cumple en:
- consultas vía `usp_consultar_*` sobre `uv_*`;
- aislamiento dentro de los SP;
- flujo Controller → InputPort → UseCase → SecondaryPort → adaptador JPA;
- OnPush, signals, `input()`/`output()`;
- cero `setInterval`/`setTimeout`, con un spec que lo comprueba;
- mensajes que vienen del backend;
- MinIO no aplica.

[SUPUESTO-B-03] (literales de `RazonCausa` en las vistas) es aceptable porque conserva el comportamiento actual y queda registrado como TD.

---

## 2. Aislamiento jerárquico dentro de los SP

**CUMPLE.**
- Los comandos del docente (abrir/cerrar toma, lote por toma, QR, cancelar) usan RBAC `DOCENTE` + `usp_validar_titularidad_jerarquica_interno('SESION')`, o la sesión de la toma.
- `usp_registrar_asistencia_por_token` usa RBAC `ESTUDIANTE` y matrícula `A` en el grupo **de la toma resuelta**: un token válido de otro grupo no escribe (B2-QR-06/07).
- Las consultas del estudiante quedan limitadas a sus matrículas.
- El administrador solo ve su institución.
- Coordinador y decano solo leen: no tienen ningún comando nuevo y sus SP de lectura heredan el ámbito actual.

---

## 3. Migración

**CUMPLE en lo funcional.**
- El backfill crea la toma 1 MANUAL CERRADA e implícita por cada sesión con detalle.
- Se aborta si hay más de un detalle por asistencia.
- Hay resultset de control.
- `up` es idempotente y se repite en la semilla 36.
- El `down` colapsa a la toma 1, con confirmación y archivo `zz_archivo_*` (patrón DEC-010), y conserva la `SJC`.
- Las pruebas `up → down → up` comparan checksums.

- **B-1 (el "camino único" de DDL falla; verificado):** `deploy_schema.ps1` ejecuta `tables/` (incluido `zz_foreign_keys.sql`) antes de `seed/`. Según §2.3, `DetalleAsistencia.sql` crea `UX_DetalleAsistencia_Asistencia_Toma (asistencia, toma)` e `IX_DetalleAsistencia_Toma (toma)`, y la FK `FK_DetalleAsistencia_TomaAsistencia` se crea mientras `toma` es NULL.
  - Después, la semilla 36 ejecuta `ALTER COLUMN toma … NOT NULL`. En SQL Server 2022 eso falla con **4922** ("ALTER TABLE ALTER COLUMN toma failed because one or more objects access this column"); lo probé en `tempdb` con un índice único compuesto.
  - En una BD existente el despliegue se rompe. En una BD nueva también.
  - **Corrección exacta:**
    - (a) `DetalleAsistencia.sql` y `zz_foreign_keys.sql` crean `UX_DetalleAsistencia_Asistencia_Toma`, `IX_DetalleAsistencia_Toma` y `FK_DetalleAsistencia_TomaAsistencia` **solo si** `COLUMNPROPERTY(OBJECT_ID('dbo.DetalleAsistencia'),'toma','AllowsNull') = 0`.
    - (b) La semilla 36 y `15_up`, en este orden y en una transacción: backfill → `DROP` de esos tres objetos si existen → `ALTER COLUMN toma uniqueidentifier NOT NULL` → `DROP INDEX UX_DetalleAsistencia_Asistencia` → `CREATE` de los tres.
    - (c) El guard `THROW 50002` y el bloque que recrea `UX_DetalleAsistencia_Asistencia` quedan condicionados a `toma IS NULL / AllowsNull = 1`.
    - (d) Añadir B2-MIG-05: `deploy_schema.ps1` dos veces seguidas sobre una BD nueva y sobre una copia con datos, sin errores.
- **NB-9 (sesiones con cabecera y sin detalle):** la cabecera `Asistencia` que crea el reclamo (`usp_radicar_solicitud_revision_asistencia_v2.sql:204-223`) no tiene toma tras el backfill. Esa sesión cuenta como "con registro" (B-05 / B-06) y tiene 0 tomas.
  - **Corrección:** añadir la prueba B2-HOR-09: `uv_asistencia_sesion_horas` da `horasSinRegistro = horasSesion` y `totalTomasSesion = 0` sin dividir por cero, y `uv_resumen_*` la mete en `horasDictadas`.
  - Añadir una línea en el resultset de control de `15_up` que cuente `sesionesConCabeceraSinDetalle`.
  - Las sesiones sin ninguna asistencia **no** reciben toma (correcto; dejarlo escrito).

---

## 4. Consumidores (contrastado con RESEARCH §7)

**BD (§7.2):** todos los lectores de `uv_detalle_asistencia` y `DetalleAsistencia` están en §2.9 o se justifican:
- `uv_resumen_*:43`, `usp_consultar_asistencias_sesion_paginado:123`, `usp_consultar_bitacora_estudiante_programa:74`, `usp_consultar_tendencia_ausentismo:67`;
- `usp_consultar_detalle_solicitud_revision_docente:123`, `usp_resolver_solicitud_revision_asistencia:174,221`, `usp_sincronizar_*:144-164`, `usp_ejecutar_cierre_masivo_periodo:120` (ver B-7).

`uv_auth_asistencia`, `uv_solicitud_revision_asistencia`, `usp_consultar_archivo_soporte_autorizado`, `usp_consultar_destinatarios_reclamo_asistencia`, `usp_consultar_solicitudes_revision_estudiante` y `usp_radicar_*` leen solo la cabecera `Asistencia`, cuya cardinalidad no cambia, así que no necesitan cambio. **CUMPLE.**

`usp_generar_sesiones_grupo` lo consumen `SesionJpaRepository` (pasa a `_v2`) y `test_rec3:224` y `test_utc_d06:440,455` (SP congelado, sin cambio). **CUMPLE.**

**Backend (§7.1):** `AsistenciaJpaRepository:82-90`, `AsistenciaSesionEstudianteJpaRepository`, `ReporteAsistenciaJpaRepository`, `AsistenciaProgramaJpaRepository` (vía `SpAsistenciaSesionPaginadoEntity`), los DTOs v1/v2/estudiante/coordinador/decano y `SesionV2SchemaCompatibilityVerifier` están en §3.2.4 y §3.6. **CUMPLE.**

- **B-7 (cierre masivo con varias tomas):** `usp_ejecutar_cierre_masivo_periodo.sql:113-128` aplica `COUNT(da.id) >= 3` sobre `asistio = 0`. Con varias tomas, **una sola sesión** con 3 tomas ausentes pasa al estudiante a `CI`. Es una regresión que introduce B sobre el estado académico del estudiante.
  - La mitigación R12 ("no se usan varias tomas en datos de cierre") no se puede hacer cumplir.
  - **Corrección mínima** (SP no congelado; C lo reescribirá después): reemplazar `COUNT(da.id)` por `COUNT(DISTINCT a.sesion)` en el `SELECT` y en el `HAVING`, sin otro cambio de regla.
  - Añadir la prueba B2-HOR-10 (3 tomas ausentes en 1 sesión → sigue `A`) y añadir `test_mass_period_close.sql` a la lista de cambios justificados.

---

## 5. Contratos congelados

**CUMPLE** que B no edite ningún objeto congelado:
- `uv_detalle_asistencia` y `uv_asistencia` conservan texto y forma, y `test_golden_path_immutability.sql` compara la forma de columnas y las firmas, que no cambian.
- `usp_registrar_asistencias_sesion` llama a `usp_sincronizar_*` con 7 parámetros **nombrados** (líneas 313-320), así que los parámetros nuevos con valor por defecto son compatibles.
- `usp_generar_sesiones_grupo` solo se envuelve.
- `Sesion.sql` no se toca.

- **B-2 (sincronización de manifiestos equivocada; verificado):** el `DB_DEVELOP_FREEZE_MANIFEST.sha256` de Infra **no es una copia** del del repo DB.
  - `verify-contracts.ps1` (líneas 196-225) compara cada línea con el hash **actual** de los archivos de `GestioAsistenciaDB`. El del repo DB guarda los hashes originales de DB-GP-001C, y `freeze-manifest.ps1` los combina con las líneas `SUPERSEDES`.
  - Hoy `verify-contracts.ps1 -Root …CULM001` **falla** en `usp_generar_sesiones_grupo.sql` (Infra `099a5cf4…` vs actual `ef9de7e9…`) y en `usp_registrar_asistencias_sesion.sql` (Infra `a0372fd6…` vs actual `7217604b…`). `usp_crear_sesion` y `usp_actualizar_sesion` pasan.
  - Copiar el manifiesto del repo DB (`85dc…`, `e6ac…`, `f4c7…`, `a037…`) dejaría **4** fallos. El diagnóstico de §2.15 ("difiere en crear/actualizar/generar") compara dos manifiestos entre sí, no los manifiestos con los archivos.
  - **Corrección exacta:**
    - El manifiesto de Infra se define como "hash **efectivo** = SUPERSEDES de `DB_UTC_D06_POST_FREEZE_MANIFEST` si existe, si no el base".
    - Sus líneas de `usp_generar_sesiones_grupo.sql` y `usp_registrar_asistencias_sesion.sql` pasan a `ef9de7e9…` y `7217604b…`, valores tomados del post-freeze del repo DB y no recalculados a mano.
    - Anotar en `DECISIONES.md` que ese drift (UTC-D06 y SES-01 sin propagar a Infra) es previo a B.
    - `-Mode Generate` regenera **también** los cuatro `.sha256` canónicos. Solo se ejecuta tras la aprobación 9.2 y con un `git diff` revisado de los cuatro contratos.
- **B-3 (manifiesto post-freeze de B):**
  - (i) `freeze-manifest.ps1` (líneas 106-113) solo acepta líneas `… SUPERSEDES <sha>` o `… WORK_ITEM`. Una línea `<sha256>  <ruta>` a secas da `POST_FREEZE_MANIFEST_INVALID_LINE`.
  - (ii) El contrato mete en el manifiesto objetos compartidos que **B2 y C modificarán después**: los KPI, `uv_resumen_*`, `uv_cumplimiento_*`, `usp_consultar_asistencias_sesion_paginado`, bitácora, consolidado, comparativas y `usp_sincronizar_*`. B2 §2.7 modifica `usp_consultar_kpis_*`, `_alerta_temprana_*`, `_bitacora_*`, `_consolidado_*`, `_comparativa_*`, `_asistencias_sesion_paginado` y `_sesiones_grupo_paginado`, y declara "sin cambio de manifiestos".
  - Con lo propuesto, el gate `freeze-manifest.ps1` de B2/C fallaría con `HASH_MISMATCH`, y el verificador no tiene supersesión para líneas `WORK_ITEM`.
  - **Corrección exacta:** el manifiesto `DB_CULM001_B_POST_FREEZE_MANIFEST.sha256` usa solo líneas `WORK_ITEM` y se limita a lo que B **define como contrato**: tablas nuevas, `DetalleAsistencia.sql`, `uv_sesion_estado`, `uv_toma_asistencia`, `uv_detalle_asistencia_v2`, `uv_asistencia_sesion_horas`, `usp_generar_sesiones_grupo_v2`, `usp_registrar_asistencia_por_token`, `usp_abrir_toma_asistencia`/`usp_cerrar_toma_asistencia`/`usp_registrar_asistencias_toma`, las migraciones 14/15 y `rol_asistencias_runtime_culm001_b1|b2.sql`.
  - Los consumidores de §2.9, `zz_foreign_keys.sql` y las semillas **no** entran.
  - `freeze-manifest.ps1` añade `-Mode GeneratePostFreeze -Manifest <ruta>` para regenerar ese manifiesto.
  - El espejo en Infra solo existe si `verify-contracts.ps1` lo verifica; si no, se omite (hoy `DB_UTC_D06_POST_FREEZE` tampoco tiene espejo).
- **B-5 (REVOKE del SP autónomo contra un objeto congelado):**
  - `rol_asistencias_runtime.sql` (post-freeze, `WORK_ITEM`) concede explícitamente `usp_registrar_asistencia_estudiante_autonomo` (línea 54) y lanza 52120 si falta.
  - `test/verify_runtime_role_login.ps1:31` exige que el login de runtime tenga `EXECUTE` sobre él.
  - El `REVOKE` en `rol_asistencias_runtime_culm001_b2.sql` anula en cada despliegue lo que concede el archivo congelado y rompe esa prueba; el contrato no lo declara.
  - **Corrección:** quitar el `REVOKE` de B. B solo retira el consumidor del backend (`AsistenciaJpaRepository:44` y la feature `registrarasistenciaautonoma`), lo que basta para que `Sesion.codigo` deje de ser credencial.
  - El `REVOKE`/`DROP` pasa al paquete D, que debe sustituir `rol_asistencias_runtime.sql` con la regeneración del post-freeze y actualizar `verify_runtime_role_login.ps1`.
  - Se quita el `GRANT` del `15_down`.
- **NB-10 (versión del golden path):** añadir `estado` y `cancelacion` como **requeridos** en `Sesion`/`SesionV2`, que tienen `additionalProperties: false`, es un cambio de contrato de respuesta. Lo acepto (§7.3-3): es lo único coherente con "se ve cancelada en todos los roles". Pero la descripción de `info` dice que 1.1.0 no modifica "ningún schema v1", y B2 también reclama 1.2.0.
  - **Corrección:** B sube `info.version` a 1.2.0 con una línea en la descripción ("CULM-001 B: `Sesion`/`SesionV2` + `estado`, `cancelacion`; lote escribe en la toma vigente; 409 `ERR_SESION_CANCELADA`"), y B2 pasa a 1.3.0. Registrarlo en `DECISIONES.md`.
  - Actualizar `OpenApiGoldenPathConformanceTest`:
    - `criticalSchemasDeclareExactlyTheFrozenPropertiesAndRequiredFields`: Sesion + 2;
    - `criticalOpenApiSchemasMatchProviderDtoPropertyShapes`: `SesionConsultadaDTO` + 2;
    - `OpenApiSesionesV2ContractRedTest`, y el `.sha256` de los dos repos.
  - La lista `forbiddenGhosts` (`tipo`, `status`…) no se toca: `tipo` va anidado dentro de `cancelacion`, no en el nivel superior.
  - Con eso, las pruebas de conformidad y `test_golden_path_immutability.sql` quedan verdes.

---

## 6. Pruebas RED y pruebas existentes que cambian

**CUMPLE** que haya pruebas RED por cada regla en BD (§2.16), backend (§3.11), frontend (§4.8) y concurrencia (B2-CON-01 y `AsistenciaQrConcurrenciaIT`). Las 21 pruebas, el fixture y la migración 02 de §2.16.3 coinciden exactamente con el grep de `INSERT … DetalleAsistencia`. En todas, el cambio es solo de inserción.

- **B-4 (lista incompleta de pruebas y fixtures afectados; verificado):** el contrato omite cinco grupos de archivos.
  - **(a) Una aserción que cambia:** `test/test_attendance_commands.sql:202` lanza 51876-like si `DetalleAsistencia GROUP BY asistencia HAVING COUNT(*) > 1`. Es un invariante **global** que se vuelve falso cuando existe cualquier asistencia con 2 tomas (pruebas B2 que no limpien o datos de la demo). Cambiarlo a `GROUP BY asistencia, toma` es un cambio de aserción por contrato y hay que declararlo y justificarlo. Lo mismo para cualquier `COUNT(*) … = 1` por asistencia en las líneas 182 y 195: siguen siendo válidos con una toma; se deja escrito.
  - **(b) Limpiezas que borran `Sesion`** y que fallarán por `FK_TomaAsistencia_Sesion` (la toma implícita la crea el lote congelado) o por `FK_SesionCancelacion_Sesion` (precarga en festivo):
    - `test/fixtures/maint_003g_attendance_fixture.sql:40-51`, que además alimenta los IT Java vía `prepare_java_integration_fixture.ps1`;
    - `test/fixtures/dev/dev_pagination_cleanup.sql:21-24`;
    - `test/test_rec3_falla_intermedia_transaccion.sql:73,135-137,244`;
    - `test/test_utc_d06_procedencia_temporal.sql:531`;
    - `test/test_usp_precargar_sesiones_concurrency.ps1:172`.
  - **(c)** `test/verify_runtime_role_login.ps1:31` (desaparece si se acepta B-5).
  - **(d)** Los fixtures backend de §3.6 también deben limpiar `TokenAsistenciaToma`, `TomaAsistencia` y `SesionCancelacion`.
  - **(e)** `test/fixtures/culm001_b_toma_fixture.sql` debe ofrecer el helper de **limpieza** además del de creación.
  - **Corrección:** añadir todos estos archivos a §2.16.3 y a R3. Cada limpieza borra, en orden, `DetalleAsistencia → TokenAsistenciaToma → TomaAsistencia → SesionCancelacion → Asistencia → Sesion`, sin cambiar ninguna aserción salvo (a), que queda anotada como cambio formal por DEC-011.
  - Añadir B2-SEG-02: se ejecutan dos veces seguidas `maint_003g_attendance_fixture.sql` y `dev_pagination_fixture.sql` + `cleanup`, sin errores de FK.

---

## 7. Seguridad del SSE y del registro

**CUMPLE.**
- `ASISTENCIA_QR_ROTADO` y `TOMA_*` solo van al docente titular.
- Un tipo no listado se entrega solo al docente; el estudiante recibe únicamente `SESION_CANCELADA`, sin motivo.
- Hay prueba de que un estudiante suscrito nunca recibe el token.
- Los eventos se publican después del commit.
- Verifiqué que `POST /api/v1/realtime/emit` (ADMINISTRADOR) emite tipos `topic.action` (siempre con punto), así que no puede falsificar `SESION_CANCELADA` ni `ASISTENCIA_QR_ROTADO`.
  - Requisito: `RealtimeAudienciaPolicy` compara el tipo con **igualdad exacta**, nunca por prefijo. Añadirlo al test.
- CIDR con `RED/PROXIES_CONFIABLES` es fail-closed (prueba con CIDR vacío).
- El body antiguo responde 400 (`JacksonInputConfig` ya activa `FAIL_ON_UNKNOWN_PROPERTIES`).
- `Sesion.codigo` sale de `SesionMateriaEstudianteResponse`.

- **NB-11 (SSE del estudiante frente a DEC-022):** DEC-022 (1) asigna al paquete **C** abrir el SSE a todos los roles con filtro de ámbito. [SUPUESTO-B-17] adelanta la rama del estudiante. No es necesario para HU047 (el aviso va por notificación y la UI recarga), pero acepto adelantarlo si queda coordinado.
  - **Corrección:** registrar en `DECISIONES.md` que B implementa `RealtimeAudienciaPolicy` y la rama "estudiante con matrícula `A`" de DEC-022 (1), y que C la extiende a coordinador, decano y administrador sobre el mismo mapa.
  - Alternativa sin coste de plazo: diferir esa rama a C (ver §9).

---

## 8. Supuestos de §7.3 y otros señalados por el redactor

| # | Supuesto | Dictamen |
| :--- | :--- | :--- |
| 1 | `porcentajeInasistencia` cambia a horas conservando el nombre | Aceptado, con el registro de B-8 |
| 2 | Estado consolidado por sesión (B-15) | Aceptado: conserva el esquema golden path de `GET /grupos/{id}/asistencias`; `PARCIAL` solo en DTOs no golden |
| 3 | `estado`/`cancelacion` requeridos en `Sesion`/`SesionV2` | Aceptado, con NB-10 (versión 1.2.0 y pruebas) |
| 4 | SSE para el estudiante en B | Aceptado condicionado a NB-11 |
| 5 | Secuencia `seq_detalle_asistencia_codigo` (B-14) | Aceptado: hoy el `MAX+1` con `UPDLOCK, HOLDLOCK` sobre toda la tabla (`usp_sincronizar_*:150-151`) serializa a todo el campus, y ningún contrato exige que `codigoDetalleAsistencia` sea consecutivo. Crear la secuencia con `START WITH` dinámico **dentro** de `DetalleAsistencia.sql` y `15_up`, y añadir B2-MIG: `NEXT VALUE` > `MAX(codigo)` tras el despliegue |
| 6 | B-04 (toma implícita CERRADA) y B-05 | Aceptados (B-05, con B-8) |
| 7 | `CargaDiaFestivo` | Aceptada: bitácora de la carga que pide 3.7 ("registrada con su fuente y fecha") |
| 8 | 4 tomas; límites 600/120/6 | 4 tomas aceptado. Límites: 120 por token y 6 por estudiante aceptados; IP según B-9 |
| — | `INSERT … EXEC` sobre el SP congelado con `@@TRANCOUNT = 0` y `SES_015` | **B-6**, abajo |
| — | Eventos nuevos fuera del golden path | Aceptado (precedente `MATRICULA_QR_ROTADO`); se documentan en `REALTIME_EVENT_CONTRACT.md` con su `.sha256` |
| — | `SES_015` | Ver B-6 |

- **B-6 (premisa del `INSERT … EXEC` incorrecta; verificado en `tempdb`):**
  - (i) La ruta feliz sí funciona dentro de una transacción externa: `test_rec3_falla_intermedia_transaccion.sql:223-224` ya ejecuta `BEGIN TRANSACTION; INSERT INTO #preTX04 EXEC dbo.usp_generar_sesiones_grupo …` con éxito.
  - (ii) Dentro de `INSERT … EXEC`, `@@TRANCOUNT` vale **1** aunque fuera valga 0. El `ROLLBACK` del `CATCH` del SP congelado (`usp_generar_sesiones_grupo.sql:344-345`) lanza **3915 también con `@@TRANCOUNT = 0`**. Lo reproduje: "outer trancount=0 / inside trancount=1 / INSERT_EXEC_FAIL 3915".
  - Por tanto `SES_015` no evita el 3915 y rechaza llamadores válidos.
  - **Corrección exacta:**
    - Quitar `SES_015`, el requisito `@@TRANCOUNT = 0` y el `Propagation.NOT_SUPPORTED` obligatorio. Se conserva la transacción propia o savepoint de §2.0 para la fase 2.
    - El `CATCH` de `usp_generar_sesiones_grupo_v2` trata 3915 (y cualquier error de la fase 1) como `SYS_001` con la tupla canónica, tras `IF XACT_STATE() <> 0 ROLLBACK`.
    - B1-FES-08 pasa a: "falla inyectada en la fase 1 con el patrón `CK_REC3_TMP_SESION` de `test_rec3` → `estadoResultado = 0`, 0 sesiones del grupo, `@@TRANCOUNT` igual al de entrada".
    - Las fases de errores de negocio del SP congelado ocurren antes de su `BEGIN TRANSACTION` (línea 237) y no hacen `ROLLBACK`, así que su tupla se devuelve intacta. Añadir una prueba: grupo sin horarios → la misma tupla que el v1.
    - Se mantiene la nota de "dos fases idempotentes" de R1.

---

## 9. Riesgo de plazo (fecha objetivo 2026-11-13); solo recomendación

**Orden recomendado: B.1 → B.2** (como dice el PLAN). B.2 depende de `uv_sesion_estado` y de `SES_010`, y B.1 es más pequeño y cierra HU047 y 3.7 por sí solo.

Se puede diferir sin incumplir la sección 3:
1. Dentro de B.2, la reescritura de comparativas (HU103/HU139), tendencia (HU134) y consolidado (HU061). No están en la lista de 3.3, y heredan horas parcialmente vía `uv_resumen_*`.
2. La rama del SSE para estudiantes (NB-11 → C, según DEC-022).
3. El retiro de `POST /api/v1/asistencias` y el cierre de TD-009 (se puede dejar en 501 hasta D).
4. `GET /admin/festivos/{anio}/sesiones-con-asistencia`. El reporte puede quedar solo en log o tabla; 3.7 pide "se reportan", no una pantalla.
5. Los adaptadores de feriados.io, si no hay key. El respaldo local cumple.

No se puede diferir: la toma vigente con backfill, las horas en `uv_resumen_*` y los KPI de la lista de 3.3, el QR/PIN con CIDR, límites e idempotencia, la prueba 5×40, la cancelación con festivos y su visibilidad en los 5 roles, la pantalla de festivos con atribución, y `sessionQrEnabled`.

Dentro de B.2 conviene empezar el GREEN de BD (tomas + horas) mientras se conoce la causa de F-DOC-015 (R10), para que esa dependencia no bloquee el resto.

---

VEREDICTO: 20 objeciones (bloqueantes: 9)

**Objeciones bloqueantes (corrección exacta en la sección indicada):**

1. **B-1 (§3)** — El `ALTER COLUMN toma NOT NULL` falla con 4922 porque los índices y la FK se crean antes en `tables/`.
   - Crear `UX_DetalleAsistencia_Asistencia_Toma`, `IX_DetalleAsistencia_Toma` y `FK_DetalleAsistencia_TomaAsistencia` solo cuando `AllowsNull = 0`.
   - En la semilla 36 y en `15_up`: backfill → `DROP` dependientes → `ALTER` → `DROP UX` antiguo → `CREATE`.
   - Condicionar el guard 50002 y el bloque del `UX` antiguo.
   - Prueba B2-MIG-05 (doble despliegue en BD nueva y existente).
2. **B-2 (§5)** — El manifiesto de Infra guarda hashes efectivos verificados contra los archivos actuales; no se copia del repo DB.
   - Fijar `usp_generar_sesiones_grupo.sql = ef9de7e9…` y `usp_registrar_asistencias_sesion.sql = 7217604b…` (los SUPERSEDES de UTC-D06).
   - Anotar el drift previo en `DECISIONES.md`.
   - Ejecutar `-Mode Generate` solo tras 9.2, revisando el diff de los 4 `.sha256` canónicos.
3. **B-3 (§5)** — El manifiesto post-freeze de B usa solo líneas `WORK_ITEM`.
   - Limitarlo a los objetos que B define como contrato; excluir los consumidores de §2.9 que B2 y C modifican, `zz_foreign_keys.sql` y las semillas.
   - Añadir `GeneratePostFreeze -Manifest` a `freeze-manifest.ps1`.
   - Espejo en Infra solo si se verifica.
4. **B-4 (§6)** — Ampliar §2.16.3 con:
   - la aserción global de `test_attendance_commands.sql:202` → `GROUP BY asistencia, toma` (cambio formal justificado);
   - las limpiezas de `Sesion` en `maint_003g_attendance_fixture.sql`, `dev_pagination_cleanup.sql`, `test_rec3_*`, `test_utc_d06_*:531` y `test_usp_precargar_sesiones_concurrency.ps1:172`, con el orden de borrado indicado;
   - el helper de limpieza y la limpieza de los fixtures backend;
   - la prueba B2-SEG-02.
5. **B-5 (§5)** — Quitar el `REVOKE EXECUTE` de `usp_registrar_asistencia_estudiante_autonomo`, porque contradice `rol_asistencias_runtime.sql` (congelado) y `verify_runtime_role_login.ps1:31`.
   - B solo retira el consumidor del backend; el `REVOKE`/`DROP` pasa a D.
   - Quitar el `GRANT` del `15_down`.
6. **B-6 (§8)** — Quitar `SES_015` y el requisito `@@TRANCOUNT = 0`, porque el 3915 ocurre igual con `@@TRANCOUNT = 0`.
   - El `CATCH` del v2 mapea 3915 → `SYS_001`.
   - B1-FES-08 se reescribe con falla inyectada estilo `test_rec3` TX-04, más una prueba de paridad de la tupla de negocio.
7. **B-7 (§4)** — En `usp_ejecutar_cierre_masivo_periodo`, `COUNT(da.id)` → `COUNT(DISTINCT a.sesion)` en el `SELECT` y en el `HAVING`, para que varias tomas de una sesión no lleven a `CI`.
   - Prueba B2-HOR-10.
   - `test_mass_period_close.sql` en la lista de cambios justificados.
8. **B-8 (§1.2)** — Registrar en `DECISIONES.md` la precisión de DEC-012 antes de congelar:
   - `horasDictadas` = Σ `horasSesion` de sesiones vencidas, con registro y no canceladas, sin mirar el estado de la toma;
   - `porcentajeInasistencia`/`codigoPermanencia` pasan a horas conservando el nombre.
9. **B-9 (§1.3)** — El límite por IP cuenta solo intentos rechazados (≥ 400 y ≠ 429); los registros exitosos o idempotentes no consumen cupo por IP.
   - Renombrar o documentar el parámetro.
   - Añadir al IT una ronda de 20 grupos × 40 desde la misma IP sin 429.

**No bloqueantes (11):** NB-1 `SES_010` → `ERR_SESION_CANCELADA` y `examples` en el 409; NB-2 unidades de los conteos; NB-3 orden filtro/interruptor; NB-4 medir p95 con la alternativa `HOLDLOCK`; NB-5 fusionar festivos de la misma fecha; NB-6 cubrir las 19 fechas por año; NB-7 limitar la cancelación retroactiva (`SES_016`); NB-8 `returnUrl` sin token hacia el IdP; NB-9 sesiones con cabecera y sin detalle; NB-10 golden path 1.2.0 (B2 → 1.3.0) y pruebas de conformidad; NB-11 SSE del estudiante coordinado con DEC-022.
