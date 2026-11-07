# CULM-001 · Paquete C — REVIEW-2 (verificación de la v2, sección 9.2)

> **Fecha:** 2026-11-07. **Objeto:** `CONTRACT.md` v2 (956 líneas, respuesta en §7) y `PLAN.md` (partición C.1/C.2).
> **Revisor:** el mismo subagente independiente de REVIEW-1. No modifica contrato ni código y no hace commits.
> **Contrastado con:** `DECISIONES.md` DEC-043 (escalamiento al decano, `RCN_012` solo con el motor habilitado, partición C.1/C.2); `REVIEW-1.md`; código de `integracion/CULM-001` y de la BD de B.2 (`C:\Proyectos\GestionAsistencia-CULM001-B\GestioAsistenciaDB`).
> **Desviación aceptada por el orquestador:** C.1 conserva la bandeja del decano (la necesita el escalamiento) y las suscripciones de grupo del coordinador y del decano (cierran F-TRX-006). No se objeta: es coherente con DEC-043 y con 3.8.

---

## 1. Verificación de las objeciones de REVIEW-1

| Objeción | Resultado | Evidencia en la v2 (y en el código) |
| :--- | :--- | :--- |
| **O-1** función con vistas y orden de despliegue | **RESUELTA** | `ufn_revision_cancelacion_resolutores` (§2.3) lee solo tablas base y no llama a funciones de usuario; regla general en §2.0. Comprobé que existen las columnas que usa: `Programa.coordinador`/`estado`, `Facultad.decano`/`estado`, `Coordinador.estado` (`tables/Coordinador.sql` l.22), `Decano.estado` (l.23), `Usuario.estado`; reproduce la regla de `uv_coordinador` l.29. Pruebas C-DB-62 (despliegue limpio con `sys.sql_expression_dependencies`) y C-DB-63 (paridad con `ufn_programas_grupo`) |
| **O-2** propuesta atascada | **RESUELTA** (DEC-043) | El proponente queda excluido como resolutor; si no queda coordinador, la propuesta escala al decano (`RCN_015`, historial `ESCALAR`, auditoría). El resolutor se calcula en vivo y el job lo reasigna (`usp_actualizar_resolutores_revisiones_cancelacion`). `RCN_013` solo cuando no hay coordinador ni decano. Pruebas C-DB-29, C-DB-33 y C-DB-34. El caso residual (facultad sin decano activo) tiene salida administrativa (activar al decano) y está en R5 y en la deuda |
| **O-3** cierre bloqueado con el motor apagado | **RESUELTA en la regla** (DEC-043) | `@motorActivo` = motor habilitado ∧ umbrales válidos; sin motor activo, `A → F` con auditoría detallada; C-DB-43 y C-DB-44. **La implementación del §2.6 abre una objeción nueva (N-1)** |
| **O-4** pruebas existentes | **RESUELTA** salvo TX-03 | §2.13.2 y §3.9.2 dan, por cada prueba, la aserción actual, la nueva y la justificación. MASS_CLOSE y HOR_10 se reemplazan sin relajar nada. TX-03 dice "sin cambio de aserción", pero con el diseño del §2.6 su `INSERT INTO #preTX03 EXEC` (l.178) deja de funcionar: ver N-1 |
| **O-5** carga inicial y al reconectar | **RESUELTA**, con una precisión pendiente (N-2) | [SUPUESTO-C-18], §4.1 y §4.8; el detalle de la materia no se suscribe si la matrícula no está en `A` |
| **O-6** `down` incompatible con B2 | **RESUELTA** | §2.11 `down` (3) restaura el texto posterior a B2 (sin `idPrograma`); C-DB-60 compara `sys.sql_modules`; el orden de los `down` entre paquetes está documentado |
| O-7 comprobación fuera de la transacción | RESUELTA | §2.6 (3)-(4), con `RevisionCancelacion → EstudianteGrupo` bloqueados; caso en C-DB-50 |
| O-8 marca de agua | RESUELTA | El corte se captura al inicio, en `DATETIME2(3)`, y la consulta aplica un solape de `SOLAPE_MARCA_SEGUNDOS`; caso límite en C-DB-11 |
| O-9 `idGrupo` del reclamo | RESUELTA | Cambio retirado; se usa `DestinatarioReclamoProjection.idGrupo` |
| O-10 inventario WORM | RESUELTA | Primero se sincroniza el contrato de eventos de Infra con el del backend; el golden path queda en 3 copias, incluida la del frontend con `PROVENANCE.md`; hashes 3 + 2 + 1; `destinatariosUsuario` en la fila "Evento neutral" |
| O-11 ámbito SSE duplicado | RESUELTA | `ufn_programas_grupo ∩ ufn_programas_ambito_ejecutor` (§2.5.10) |
| O-12 precondiciones de la migración 19 | RESUELTA | `THROW 50019` en el paso 0, antes de crear nada; probado en C-DB-60 |
| O-13 huecos de prueba | RESUELTA | C-DB-46; `RCN_011`/`RCN_004` alineados (§2.5.8 paso 5, §4.5); pérdida ya superada en C-DB-40 y en el texto de `RCN_012` |
| O-14 detalles menores | RESUELTA | Vista de historial retirada; auditoría `ALERTA_INASISTENCIA_ACTUALIZADA`; [SUPUESTO-C-20]; `totalRegistros` documentado; p95 ≤ 300 ms o ejecución tras responder |

Concordancia con DEC-043: escalamiento (O-2) ✓; `RCN_012` solo con el motor habilitado y umbrales válidos (O-3) ✓; partición C.1/C.2 ✓. La bandeja propia del docente pasa a C.2 porque el docente decide desde la planilla en C.1: no incumple 3.5.

---

## 2. Objeciones nuevas

### N-1 — BLOQUEANTE — Llamar al motor desde el SP del cierre masivo rompe el contrato de salida del cierre

**Evidencia.** El §2.6 (2) ejecuta `EXEC usp_evaluar_alertas_inasistencia_grupo` por cada grupo **dentro** de `usp_ejecutar_cierre_masivo_periodo`, y el §3.4 lo describe como "salvaguarda". Según §2.5.1, el motor termina con un `SELECT` (la tupla más contadores y `novedadesJSON`), así que:

1. **Backend:** `CierrePeriodoJpaRepository` ejecuta el SP con `JpaProcedureExecutor`, que hace `query.getResultList()` + `ProcedureResultMapper.mapSingleWithExtras` (`JpaProcedureExecutor` l.83). Con SQL Server ese método lee el **primer** resultset, que sería la tupla `ALR_003` (éxito) del primer grupo, no la del cierre. Un cierre bloqueado con `RCN_012` (`estadoResultado = 0`) se informaría como exitoso y el 409 de §3.2 no ocurriría.
2. **Pruebas:** TX-03 de `test_rec3_falla_intermedia_transaccion.sql` (l.177-179) hace `INSERT INTO #preTX03 (4 columnas) EXEC usp_ejecutar_cierre_masivo_periodo`. Si el cierre deja salir los resultsets del motor, el número de columnas no coincide; si los captura con `INSERT … EXEC`, se produce el error 8164 ("An INSERT EXEC statement cannot be nested"). En los dos casos TX-03 falla, aunque §2.13.2 dice "sin cambio de aserción". `MASS_CLOSE_SUCCESS` (l.68-72) encierra la salida entre los marcadores `TEST_RESULT_BEGIN/END`, y los resultsets extra cambian la salida esperada.
3. **Avisos perdidos:** el `novedadesJSON` de esas evaluaciones internas se descarta, y por [SUPUESTO-C-05] la alerta no se vuelve a notificar. Ni el estudiante ni el docente (`REVISION_CANCELACION_PENDIENTE`) reciben aviso de las alertas y revisiones que nazcan ahí.

**Corrección exacta (cualquiera de las dos; preferida la a):**
- **(a)** El SP del cierre **no** evalúa. La evaluación con avisos la hace solo el backend antes de llamar al SP (§3.4, ya previsto). Dentro de su transacción, el SP cuenta las pérdidas por horas sin revisión (`uv_resumen_*` ∧ `NOT EXISTS RevisionCancelacion`) como causa de `RCN_012`. El job o la siguiente invocación crean esas revisiones y avisan. Hay que actualizar C-DB-40: "pérdida sin revisión → `RCN_012` sin crear la revisión".
- **(b)** Separar el motor en `usp_internal_evaluar_alertas_inasistencia_grupo` (solo parámetros `OUTPUT`, sin `SELECT`), que usan el SP público y el cierre. El cierre devuelve una sola fila con una columna extra `novedadesJSON` agregada, y el backend la notifica.

En los dos casos hay que añadir C-DB-47: el cierre devuelve **exactamente un** resultset, en el caso bloqueado y en el exitoso, y `INSERT INTO #t EXEC usp_ejecutar_cierre_masivo_periodo` funciona. Y en §3.9 un IT que compruebe que `RCN_012` llega al backend como 409.

### N-2 — no bloqueante — Conteo de cargas del spec de reconexión

El §4.1 pide cargar "al iniciar **y** en cada `CONNECTED` (primera conexión y reconexiones)", y la secuencia `CONNECTING → CONNECTED → RECONNECTING → CONNECTED` más un evento da 4 cargas. El §4.8 exige **exactamente 3** ("inicio, reconexión, evento"). Hay que fijar una de dos reglas: (i) la carga inicial ocurre en el primer `CONNECTED` y no antes, o (ii) son 4 cargas. Además, la página de alertas y las bandejas de coordinador y decano no se suscriben al SSE en C.1 (§4.3, §4.5): para ellas el spec de C.1 debe exigir solo "carga al entrar y tras cada acción propia", sin `connectionState$`.

### N-3 — no bloqueante — Contador de no leídas en C.1 sin forma de marcar leídas

En C.1 el menú del estudiante muestra `contarNoLeidas()` (§4.3), pero marcar como leídas es de C.2. Si C.2 no llega, el contador solo crece. Hay que elegir: en C.1 mostrar el número de alertas **vigentes** (`estaVigente = 1`), o no mostrar contador hasta C.2. Si C.2 se difiere, registrarlo en `CLOSURE.md`.

### N-4 — no bloqueante — Lecturas dentro de la transacción del cierre

El §2.0 declara el orden `RevisionCancelacion → EstudianteGrupo` (y después `Grupo`) para el cierre. Pero el paso (4) del §2.6 lee además `uv_resumen_*` (`Asistencia`/`DetalleAsistencia`) con las matrículas ya bloqueadas. Con la corrección N-1 (a), esa lectura queda como única fuente de "pérdida sin revisión". Hay que declararla en el §2.0, justificar que no forma ciclo con el lote (que toma `EstudianteGrupo` antes que `Asistencia`) y hacer que C-DB-50 la cubra explícitamente (cierre y lote del mismo periodo a la vez, sin 1205).

---

## 3. Veredicto

**VEREDICTO: CON OBJECIONES — 1 bloqueante.** Las 6 bloqueantes y las 8 no bloqueantes de REVIEW-1 están resueltas, y lo que decide DEC-043 está bien reflejado. La única objeción que impide congelar es nueva y salió de la corrección de O-3:

1. **N-1:** el SP del cierre ejecuta el SP público del motor, que devuelve resultsets. El backend leería la tupla del motor en lugar de la del cierre (un `RCN_012` llegaría como éxito), TX-03 (`INSERT … EXEC`) fallaría y se perderían los avisos de las alertas creadas ahí. La corrección es quitar esa evaluación del SP (preferida) o usar una variante interna sin resultset. En los dos casos, añadir la prueba "un solo resultset" (C-DB-47) y el IT del 409.

N-2, N-3 y N-4 se pueden atender en la misma v3 sin otra ronda: si N-1 se corrige con la opción (a) y las tres no bloqueantes quedan atendidas, el contrato se puede congelar sin una REVIEW-3 completa (basta con verificar los cambios).
