# CULM-001 · Paquete C — REVIEW-1 (revisión independiente de contrato, sección 9.2)

> **Fecha:** 2026-11-07. **Objeto:** `CONTRACT.md` v1 (896 líneas) y `PLAN.md` del paquete C.
> **Revisor:** subagente Opus independiente (no redactó el contrato). No modifica código ni contrato.
> **Fuentes contrastadas:** `PROMPT_FABLE_CULMINACION.md` §3.5 (l.59-64), §3.8/§3.9 (l.91-101); `DECISIONES.md` DEC-011/012/024, DEC-020/021/031, DEC-022 §1, DEC-028, DEC-032, DEC-037/038, DEC-039, DEC-041; contratos congelados de B (§3.8 eventos, l.1205-1218; §golden path l.1240-1248) y B2 (§2.5 l.254, l.262-269, l.370); `AGENTS.md` §2.4, §3.3, §4.
> **Código verificado:** `integracion/CULM-001` (A + B.1) en `C:\Proyectos\GestionAsistencia-CULM001\<repo>` y la BD de B.2 en `C:\Proyectos\GestionAsistencia-CULM001-B\GestioAsistenciaDB` (`feature/CULM-001-B2-tomas-qr`, `a8a59fa`).

---

## 1. Lista de comprobación

| # | Punto | Resultado |
| :--- | :--- | :--- |
| 1 | Cumple 3.5 punto por punto | **CUMPLE** (con O-3 y O-2 que pueden dejar el flujo sin salida) |
| 2 | Aislamiento jerárquico dentro de los SP (grupo mixto) | **CUMPLE** en reglas; **OBJECIÓN** de despliegue en la función que lo implementa (O-1) |
| 3 | Migración 19 `up/down`, dependencias B.2/B2 | **OBJECIÓN** (O-6, O-9, O-12) |
| 4 | Consumidores; cierre masivo y sus pruebas existentes | **OBJECIÓN** (O-3, O-4, O-9) |
| 5 | Pruebas RED por regla y concurrencia | **CUMPLE** en lo nuevo; **OBJECIÓN** en pruebas existentes y en dos huecos (O-4, O-13) |
| 6 | SSE: apertura, canal personal, WORM, política B.1 | **CUMPLE** en diseño; **OBJECIÓN** en el cliente (O-5) y en el inventario WORM (O-10) |
| 7 | Sin datos quemados ni choques de códigos/numeración | **CUMPLE** |
| 8 | Alcance vs plazo | Ver §3 (recomendación, no bloqueante) |

### 1.1 Detalle del punto 1 (3.5)

| Regla 3.5 | Contrato | Resultado |
| :--- | :--- | :--- |
| Umbrales `ASISTENCIA/UMBRAL_ALERTA_PERDIDA` (20) y `..._ADVERTENCIA` (15) configurables | `TipoAlertaInasistencia.claveParametroUmbral` + `ufn_umbral_alerta_inasistencia` (`TRY_CAST`, misma lectura que `ufn_clasificar_permanencia`, verificada en `schema/functions/ufn_clasificar_permanencia.sql`) | CUMPLE |
| EX no cuenta; cálculo por horas | Motor lee `porcentajeInasistencia = horasFalta/horasDictadas` de `uv_resumen_asistencia_estudiante_grupo` de B.2 (verificado: `horasFalta` solo SJC, sesiones canceladas y no vencidas fuera) | CUMPLE |
| Advertencia: estudiante por SSE + correo; docente: marca en planilla sin notificación | §3.5 (plantilla `ALERTA_RIESGO_INASISTENCIA`), §3.6.4 `ALERTA_INASISTENCIA` (`DOCENTE_TITULAR` + `DESTINATARIO`), columna de marca en el resumen del docente | CUMPLE |
| Pérdida: revisión idempotente (una por estudiante y grupo) + aviso al docente titular | `UQ_RevisionCancelacion_EstudianteGrupo`, cerrojo por grupo en `EvaluacionAlertaGrupo`, `REVISION_CANCELACION_PENDIENTE` (DEC-041 acepta la plantilla nueva) | CUMPLE |
| Decisión del docente con motivo obligatorio (proponer / mantener) | `usp_decidir_revision_cancelacion` pasos 2-3, `RCN_003` | CUMPLE |
| Si mantiene: sin nueva alerta automática, marcado, puede proponer después | Unicidad por (matrícula, tipo); transición `MANTENIDA → PROPONER`; C-DB-21 | CUMPLE |
| Propuesta → coordinador del programa del estudiante; aprueba (`CI`, notifica a ambos, fuera del registro) o rechaza con motivo (notifica al docente, sigue activo) | `ufn_coordinadores_revision_cancelacion` (EstudiantePrograma ∩ programas del grupo), `usp_resolver_revision_cancelacion`, `CANCELACION_APROBADA` (estudiante y docente), `CANCELACION_RECHAZADA` (docente). Fuera del registro verificado en B.2: `usp_registrar_asistencias_toma` exige `MATRICULA/ESTADO_INSCRITA` (`EST_004`, l.175-181), `usp_internal_marcar_ausentes_toma` l.28, `uv_faltantes_toma` l.32, `AQR_004` sembrado en `35_mensajes_toma_asistencia_qr.sql` | CUMPLE |
| Todo auditado | `AuditoriaEvento` en motor (`SYSTEM`), decisión y resolución + `RevisionCancelacionHistorial` | CUMPLE (ver O-14, no bloqueante) |
| El coordinador no edita asistencias | Ninguna ruta ni SP nuevo escribe asistencias para el coordinador | CUMPLE |
| Ámbito dentro de los SP | §2.0 y cada SP | CUMPLE |

Desviaciones de DEC-039 ya aceptadas por DEC-041 (no se objetan): motor no se invoca tras el token (C-04), aviso de pérdida al estudiante + plantilla nueva al docente (C-06), re-proponer tras `RECHAZADA` (C-07), umbral exigido al proponer/aprobar (C-08), cierre masivo que bloquea (C-10), canal personal (C-11).

### 1.2 Detalle del punto 7 (datos quemados y numeración)

Verificado con `grep` en las dos BD y el backend: `ALR_*` y `RCN_*` no existen; `AlertaInasistencia`, `RevisionCancelacion` y demás tablas nuevas no existen; semillas ocupadas 30-36 (A = 33, B = 34-36; B2 reserva 37-39) y migraciones 15/16 (B2 17/18): 19 y 40/41 libres (DEC-028). `MATRICULA/ESTADO_INSCRITA` existe (`33_culm001_a_catalogos.sql` l.19). Plantillas `ALERTA_RIESGO_INASISTENCIA` (marcadores `estudiante, grupo, porcentaje, umbral`) y `ALERTA_PERDIDA_INASISTENCIA` (`..., limite`) existen en `26_plantillas_notificacion.sql` l.36-44. Literales restantes (`'true'`, `1000` de la columna, códigos de perfil RBAC) siguen la práctica del repo. **CUMPLE.**

---

## 2. Objeciones

### O-1 — BLOQUEANTE — `ufn_coordinadores_revision_cancelacion` rompe el despliegue en BD limpia

**Evidencia.** §2.3 define la función como TVF inline que lee `uv_coordinador.estaActivoCoordinador` y `ufn_programas_grupo`. `deploy_schema.ps1` aplica `functions/` en una sola pasada ordenada por nombre (l.78-81) **antes** de `views/` (l.84+, con reintentos solo para vistas). B2 §2.5 (l.262) ya fijó la regla por esto mismo: "una TVF inline no admite resolución diferida. Por eso las cuatro funciones leen **solo tablas base**". La función de C falla dos veces en una BD limpia: `uv_coordinador` aún no existe y `ufn_coordinadores_…` se ordena antes que `ufn_programas_grupo`. En una BD ya desplegada (`CREATE OR ALTER`) pasa, así que el defecto no lo vería `db-test` sobre la BD local, sí `db-deploy` limpio.

**Corrección exacta.** (1) En §2.3, `ufn_coordinadores_revision_cancelacion` lee solo tablas base (`EstudianteGrupo`, `EstudiantePrograma`, `Coordinador`, `Usuario`, `Programa` y las tablas que use `ufn_programas_grupo`) y reproduce la regla de actividad de `uv_coordinador` l.29 (usuario activo ∧ rol coordinador activo ∧ programa activo); (2) renombrarla para que ordene después de `ufn_programas_grupo` (p. ej. `ufn_revision_cancelacion_coordinadores`) o inlinear la regla de programas del grupo; (3) añadir C-DB-62 "despliegue en BD limpia" (patrón B2NM-16).

### O-2 — BLOQUEANTE — Revisión atascada en `PROPUESTA` cuando el único coordinador competente es el propio docente

**Evidencia.** Paso 9 de §2.5.6: `PROPONER` solo exige `EXISTS ufn_coordinadores_revision_cancelacion(@eg)`. Si el docente titular es también el único coordinador competente del programa del estudiante (caso real: coordinadores que dictan), la propuesta pasa, pero el paso 5 de §2.5.8 responde `RCN_014` a su aprobación y no hay otro coordinador. Desde `PROPUESTA` no hay transición del docente (§2.1). Resultado: revisión que nadie puede resolver y, por [SUPUESTO-C-10], cierre masivo bloqueado para siempre con `RCN_012`.

**Corrección exacta.** En §2.5.6 paso 9 y en `TransicionRevisionCancelacion.exigeCoordinadorDisponible`: `NOT EXISTS (SELECT 1 FROM ufn_coordinadores_revision_cancelacion(@idEstudianteGrupo) WHERE idUsuario <> @idUsuarioEjecutor)` → `RCN_013`. En §3.5, los destinatarios de `PROPUESTA_CANCELACION` y de `REVISION_CANCELACION_DECIDIDA` excluyen al proponente. C-DB-29 añade: "T es el único coordinador de PA → `PROPONER` = `RCN_013`".
**Punto a confirmar por el orquestador (no bloqueante):** coordinador desactivado después de `PROPUESTA` deja el mismo atasco. Opción conservadora: transición `PROPUESTA + MANTENER` del docente (retirar la propuesta) o que `RCN_012` liste el caso para el administrador. Hoy el contrato no da salida.

### O-3 — BLOQUEANTE — Cierre masivo inutilizable con `ALERTA_INASISTENCIA/HABILITADA = false`

**Evidencia.** El interruptor es el mecanismo declarado de rollback "sin despliegue" (§6.2) y de control del primer pase ([SUPUESTO-C-15], R3). Con el interruptor en `false` el motor no escribe (§2.5.1 paso 2), así que toda matrícula `A` con `codigoPermanencia = PERDIDA` queda "sin revisión" y el SP del cierre responde `RCN_012` (§2.6) sin forma de resolverlo: HU174 queda bloqueada mientras dure el rollback. Lo mismo si el motor falla con `ALR_002` (umbral mal configurado): `evaluarYAvisar` traga el error (§3.4) y el cierre se bloquea con un mensaje que habla de "casos sin resolver".

**Corrección exacta.** Definir en §2.6 y [SUPUESTO-C-10] el comportamiento con el interruptor apagado (elegir uno y llevarlo a DEC): (a) el cierre solo bloquea por revisiones que requieren acción y las pérdidas sin revisión pasan a `F` (documentado en el addendum), o (b) bloquea con un mensaje propio (`RCN_015`, "las alertas de inasistencia están deshabilitadas; habilítelas y ejecute la evaluación antes del cierre"). Añadir C-DB-43 con el interruptor apagado y C-DB-44 con umbral inválido.

### O-4 — BLOQUEANTE — No se enumeran las pruebas existentes que cambian por la nueva regla del cierre y del gateway

**Evidencia.** AGENTS.md §4 solo permite modificar un test por un cambio formal de contrato, y el contrato debe decir cuál y cómo. §2.13 y §3.8 omiten:
- `GestioAsistenciaDB/test/test_mass_period_close.sql`: `MASS_CLOSE_SUCCESS` exige `CI` para tres ausencias (l.76-77, "did not cancel three absences") y `CULM001_B2_HOR_10` (l.105-166) exige `CI` por ausencias en 3 sesiones distintas. Ambas fallan con C por diseño.
- `test/test_rec3_falla_intermedia_transaccion.sql` TX-03 (l.152-190): si su fixture tiene una matrícula en pérdida sin revisión, el SP corta con `RCN_012` **antes** de la falla forzada y la prueba pasaría o fallaría por la razón equivocada.
- `test/test_culm001_b2_migraciones.sql` l.56: comprueba el texto del cierre tras el `down` de B.2; el orden de `down` C → B.2 debe quedar dicho.
- Backend: `EjecutarCierreMasivoUseCaseImplTest` y `EjecutarCierreMasivoAvisoTest` (constructor y llamada previa al motor), `RealtimeStreamErrorHttpTest` (construye el gateway con `InstitutionalScopePort`, l.48-56), `RbacSecurityFilterChainTest` l.702-722 (`/realtime/stream` y la ruta personal).

**Corrección exacta.** Añadir en §2.13 y §3.9 una tabla "Pruebas existentes que cambian" con: archivo y caso, aserción actual, aserción nueva y justificación (DEC-041 C-10 / DEC-039 §5). Para MASS_CLOSE y HOR_10: el estudiante con 3 sesiones SJC y < 20 % por horas pasa a `F`; con ≥ 20 % y sin revisión el cierre responde `RCN_012`; con revisión `APROBADA` sigue `CI`. Para TX-03: fijar el fixture sin pérdidas para que la falla siga siendo la de contadores. Ninguna aserción se elimina sin su reemplazo.

### O-5 — BLOQUEANTE — El almacén de avisos del cliente no carga al iniciar ni al reconectar

**Evidencia.** §4.8: "recuento solo por evento o acción (spy: ninguna llamada HTTP sin evento)". El golden path congelado dice lo contrario: `BACKEND_GOLDEN_PATH_CONTRACT.md` §L, "Ante un evento, **o al reconectar**, el frontend recarga por HTTP". Con la prueba tal como está escrita, la campana del estudiante y los contadores del docente y del coordinador arrancan en 0 tras el login y no se corrigen tras un corte (el SSE no tiene replay). Además, mientras siga B-01 la ruta personal responde 403 y no llegará ningún evento.

**Corrección exacta.** §4.2 `AvisosRealtimeStore`: recuento HTTP (a) al iniciar la sesión, (b) en cada transición de `connectionState$` a `CONNECTED` y (c) por evento; nunca por temporizador. §4.8: el spec exige exactamente esas llamadas y ninguna otra. Mismo criterio para la planilla, las bandejas y las vistas de grupo de §4.3-§4.6 (recarga al reconectar). El detalle de la materia no se suscribe si `estadoMatricula ≠ 'A'` (el gateway le respondería 403).

### O-6 — BLOQUEANTE — El `down` restauraría un texto de SP incompatible con B2

**Evidencia.** §2.11 `down` (3): "restaura el texto de B.2 de `usp_consultar_resumen_asistencia_grupo_docente_paginado`". B2 modifica ese SP (B2 CONTRACT l.370: "deja de devolver `idPrograma`") y quita `idPrograma` de `uv_resumen_*` (l.254). Restaurar el texto de B.2 vuelve a referenciar `idPrograma`: `CREATE OR ALTER PROCEDURE` falla con columna inválida (la resolución diferida no cubre columnas de objetos existentes) y C-DB-60 `up → down → up` no puede pasar.

**Corrección exacta.** §2.11 y §6.2: "restaura el texto vigente en `integracion/CULM-001` **después de B2** (sin `idPrograma`)", copiado literal en el `down` al iniciar el GREEN de C, y C-DB-60 lo verifica comparando `sys.sql_modules` con ese texto. Para `usp_ejecutar_cierre_masivo_periodo` sí vale el de B.2 (B2 l.23 no lo toca).

### O-7 — no bloqueante — Comprobación del bloqueo del cierre fuera de la transacción

§2.6 hace la comprobación "antes de abrir la transacción". Un lote o el job pueden crear una pérdida entre la comprobación y el `UPDATE … → F`; ese estudiante terminaría `F` sin revisión, contra lo que dice [SUPUESTO-C-10]. **Corrección:** comprobar dentro de la transacción, tomando primero `RevisionCancelacion` y luego `EstudianteGrupo` del periodo con `UPDLOCK, HOLDLOCK` (mismo orden que la resolución, §2.0, para no crear un ciclo), y añadir el caso a C-DB-50.

### O-8 — no bloqueante — Marca de agua del job puede saltarse sesiones

`EvaluacionAlertaGrupo.fechaUltimaEvaluacionUtc` es `DATETIME2(0)` y se escribe con `SYSUTCDATETIME()` al **final** (paso 9). La conversión a `DATETIME2(0)` redondea (09:59:59.6 → 10:00:00) y las sesiones que vencen entre el paso 5 y el paso 9 no se contaron. En ambos casos `fechaHoraFin > marca` es falso y el job no vuelve a evaluar el grupo hasta otra sesión. **Corrección:** capturar `@ahora = SYSUTCDATETIME()` al inicio, usarlo como corte de "vencida" en la lectura y guardar como marca `MAX(fechaHoraFin)` de las sesiones vencidas consideradas (`DATETIME2(7)` o el tipo de `Sesion.fechaHoraFin`). C-DB-11 añade el caso límite.

### O-9 — no bloqueante — `usp_consultar_destinatarios_reclamo_asistencia` ya devuelve `idGrupo`

§2.6 añade "columna nueva `idGrupo` al final". Ya existe: `usp_consultar_destinatarios_reclamo_asistencia.sql` l.104-117 y `DestinatariosReclamoJpaRepository.toProjection` la lee en la posición 4 (mapeo posicional). Una segunda columna duplicaría el nombre sin aportar nada. **Corrección:** quitar la fila de §2.6, el punto (3) del `down` para ese SP, C-DB-42 y el "3 modificados" de §3.9 (pasan a 2); usar `DestinatarioReclamoProjection.idGrupo`.

### O-10 — no bloqueante — Inventario WORM incompleto

1. **Deriva existente:** `GestioAsistenciaBackend/docs/contracts/REALTIME_EVENT_STANDARD.md` ya tiene las filas de B.1 (cancelación, matrícula QR, política de audiencia) y `AsistenciasUCO-Infra/docs/contracts/events/REALTIME_EVENT_CONTRACT.md` no (hash `e016…` vs `2263…`): `verify-contracts.ps1` ya marca `CROSS_REPO_DRIFT`. §3.8 debe decir que C parte de la copia del backend y deja ambas idénticas.
2. **Tercera copia:** `GestioAsistenciaFrontend/docs/contracts/external/backend/BACKEND_GOLDEN_PATH_CONTRACT.md` tiene su `.sha256` y `PROVENANCE.md` (y ya está desfasada). Decir si C la sincroniza o lo registra como deuda; hoy no se menciona.
3. "Se regeneran los `.sha256` de los tres en Infra y backend": el `REALTIME_EVENT_STANDARD.md` del backend no tiene `.sha256`; son 3 en Infra + 2 en backend (`openapi-golden-path.sha256`, `BACKEND_GOLDEN_PATH_CONTRACT.sha256`). Precisarlo.
4. La fila "Evento neutral" (l.18 del contrato de eventos) debe incluir `destinatariosUsuario` como metadato interno no serializado.

### O-11 — no bloqueante — Ámbito de lectura del SSE duplicado

`usp_consultar_audiencias_realtime_grupo` reimplementa "coordinador con programa ∩ grupo, o decano de la facultad". B2 entrega `ufn_programas_ambito_ejecutor` (coordinador → sus programas; decano → programas de su facultad). **Corrección:** `esAmbitoLectura` = `EXISTS (ufn_programas_grupo(@g) ∩ ufn_programas_ambito_ejecutor(@u))` ∨ administrador de la institución, para que haya una sola definición del ámbito (3.8).

### O-12 — no bloqueante — Precondiciones de la migración 19

La dependencia de B.2/B2 está bien descrita en [SUPUESTO-C-02], pero el `up` no la verifica. **Corrección:** al inicio del `up`, `THROW` con mensaje claro si falta `TomaAsistencia`, `uv_asistencia_sesion_horas`, `ufn_programas_grupo` o si `uv_resumen_asistencia_estudiante_grupo` aún expone `idPrograma` (señal de que B2 no está aplicado). Así no se crea una C a medias sobre una base sin B2 (la vista de B.2 actual hace `INNER JOIN uv_grupo_programa` y con B2 sería 1:N).

### O-13 — no bloqueante — Huecos de prueba

- Concurrencia de resolución: dos coordinadores competentes (estudiante en PA y PB) resuelven a la vez → una gana, la otra recibe `RCN_004`/`RCN_011`, una sola fila de historial.
- §4.5 dice que el cliente muestra `RCN_004` "si otro coordinador ya resolvió", pero §2.5.8 paso 6 responde `RCN_011` si la decisión coincide (APROBAR + APROBAR de otro coordinador). Alinear el texto y probar ambos casos.
- Revisión `PENDIENTE_DOCENTE` cuya alerta de pérdida pasó a `SUPERADA` (excusa aprobada): bloquea el cierre hasta que el docente `MANTENER`. Es coherente con 3.5, pero debe estar en C-DB-40 y en el texto de `RCN_012`.

### O-14 — no bloqueante — Detalles menores

- `uv_revision_cancelacion_historial` no tiene consumidor (ningún SP ni endpoint la lee). Exponerla en la bandeja (historial de motivos) o quitarla.
- Las transiciones de alerta `SUPERADA`/reactivada no se auditan (solo `UPDATE`). Para "todo queda auditado", una fila `ALERTA_INASISTENCIA_ACTUALIZADA` en `AuditoriaEvento` por cambio de estado.
- `Grupo.cantidadEstudiantesCancelaronAutomaticamente` cambia de significado (ya no hay cancelación automática). Registrarlo en el addendum de BD.
- `ASISTENCIAS_*_ACTUALIZADAS.totalRegistros` llega al coordinador de PA en un grupo mixto e incluye registros de PB. Es un conteo sin identidad (aceptable), pero hay que documentarlo en la tabla de audiencias.
- El motor síncrono tras cada lote y cada cierre de toma suma latencia a la respuesta HTTP y al job de B.2 (prueba 5 × 40). R9 lo mide; definir el umbral de aceptación (p. ej. p95 ≤ 300 ms) o ejecutarlo en un ejecutor de hilos virtuales tras responder.

---

## 3. Alcance frente al plazo (punto 8; recomendación, no bloqueante)

C no puede empezar el RED hasta que B.2 (sin backend ni frontend aún) y B2 estén en `integracion/CULM-001`, y las 7 rutas nuevas darán 403 en pantalla hasta resolver B-01. Para llegar a 2026-11-13 se recomienda partir C:

- **C.1 (imprescindible para 3.5 y DEC-022 §1):** catálogos y tablas; motor + job + invocación tras escrituras; decisión y resolución (SP, endpoints, auditoría, notificaciones); bandeja del coordinador; decisión del docente desde la planilla (modal) o desde la bandeja, **una** de las dos; página de alertas del estudiante; cierre masivo por horas; apertura del canal de grupo por ámbito con la política ampliada (cierra F-TRX-006 y F-EST-S05 en el detalle de la materia).
- **C.2 (diferible sin incumplir 3.5):** canal personal, campana y `AvisosRealtimeStore` (el estudiante recibe el SSE en el canal de grupo y la campana se puede calcular por HTTP al navegar); `PATCH /estudiante/alertas/lectura`; bandeja separada del docente si la planilla ya permite decidir; `SOLICITUD_REVISION_RESUELTA` (HU042); suscripciones de grupo del coordinador y del decano; `uv_revision_cancelacion_historial`; `features.cancelacionInasistenciaEnabled`.

Si se difiere C.2, el golden path 1.5.0 y el contrato de eventos se publican solo con la apertura por ámbito (el cambio del invariante "`grupoId` obligatorio" pasa a C.2).

---

## 4. Veredicto

**VEREDICTO: CON OBJECIONES — no se congela.** El diseño cumple 3.5, DEC-039 y DEC-041 y el aislamiento por programa del estudiante está bien planteado. Antes de congelar hay que corregir 6 bloqueantes, y conviene atender las 8 no bloqueantes en la misma versión.

Bloqueantes:
1. **O-1:** `ufn_coordinadores_revision_cancelacion` lee `uv_coordinador` y depende de `ufn_programas_grupo`, que se despliega después; falla en una BD limpia. Debe leer solo tablas base y tener prueba de despliegue limpio.
2. **O-2:** si el docente titular es el único coordinador competente, la revisión queda en `PROPUESTA` para siempre (`RCN_014`) y bloquea el cierre. `RCN_013` debe excluir al ejecutor.
3. **O-3:** con `ALERTA_INASISTENCIA/HABILITADA = false` (rollback declarado) o con `ALR_002`, el cierre masivo queda bloqueado para siempre con `RCN_012`. Falta definir esa regla.
4. **O-4:** faltan en el contrato las pruebas existentes que cambian (`test_mass_period_close.sql` MASS_CLOSE_SUCCESS y HOR_10, TX-03 de `test_rec3…`, `test_culm001_b2_migraciones.sql` l.56, pruebas backend del cierre, del gateway y de seguridad), cada una con su aserción nueva.
5. **O-5:** el spec del cliente prohíbe el recuento HTTP sin evento. Contradice el §L del golden path, y los contadores arrancan en 0 tras el login y quedan mal tras un corte. Hay que contar al iniciar y al reconectar.
6. **O-6:** el `down` restauraría el texto de B.2 del resumen del docente, que referencia el `idPrograma` que B2 elimina. Debe restaurar el texto posterior a B2.
