# CULM-001 · Paquete C — REVIEW-3 (verificación final de la v3, sección 9.2)

> **Fecha:** 2026-11-07. **Objeto:** `CONTRACT.md` v3 (969 líneas), cambios listados en §0.1. **Revisor:** el mismo de REVIEW-1 y REVIEW-2.
> **Alcance:** solo los cambios que responden a N-1..N-4 de `REVIEW-2.md`. No se toca el contrato ni el código; sin commit.

## Verificación

| Objeción | Resultado | Evidencia en la v3 |
| :--- | :--- | :--- |
| **N-1** (bloqueante) | **RESUELTA** | Se aplicó la opción (a). [SUPUESTO-C-10] y §2.6 (2): el cierre no ejecuta el motor ni ningún SP que devuelva resultsets. §2.6 (4): `RCN_012` se decide dentro de la transacción con las revisiones pendientes y las pérdidas sin revisión ya existentes, sin crear revisiones. §2.6, "Salida": un solo resultset de una fila en todos los casos. C-DB-47 lo prueba (incluido `INSERT INTO #t EXEC`, sin error 8164 y sin dependencia del motor en `sys.sql_expression_dependencies`). El IT `CierreMasivoRcn012IT` recorre `CierrePeriodoJpaRepository`/`JpaProcedureExecutor` y espera 409. C-DB-40 queda "sin crear la revisión". En MASS_CLOSE y HOR_10, la fase 2 ejecuta el motor de forma explícita, y la limpieza se justifica por esa fase. TX-03 sigue sin cambio de aserción y su precondición queda explícita (la fila no es `RCN_012`) |
| **N-2** | **RESUELTA** | [SUPUESTO-C-18] y §4.1/§4.8: carga al entrar, recarga en cada reconexión (el primer `CONNECTED` no recarga) y por evento. La secuencia de prueba da **exactamente 3** cargas, más un caso `ERROR` con 1 carga. Las vistas no suscritas en C.1 cargan al entrar y tras cada acción propia, sin `connectionState$` |
| **N-3** | **RESUELTA** | [SUPUESTO-C-13], §2.5.3 y §4.2: el contador de C.1 es `contarVigentes()` (`soloVigentes=true`, alertas vigentes de matrículas activas) y baja cuando una alerta pasa a `SUPERADA`. El contador de no leídas pasa a C.2. Si C.2 se difiere, se registra en `CLOSURE.md` |
| **N-4** | **RESUELTA** | §2.0: orden y modo dentro del cierre. Primero `RevisionCancelacion` y `EstudianteGrupo` con `UPDLOCK, HOLDLOCK`; luego la lectura de `uv_resumen_*` en `READ COMMITTED` sin retener bloqueos; al final `Grupo` y `AuditoriaEvento`. Se justifica que no hay ciclo con el motor, el lote (`EstudianteGrupo` antes que `Asistencia`), la resolución y el retiro. C-DB-50 añade cierre y lote a la vez (20 repeticiones sin error 1205) y cierre y motor a la vez |

## Observación (no bloqueante, puede corregirse en el GREEN)

§3.4 dice que, si el motor falló para un grupo, "el job la evaluará y avisará en su siguiente pase". El job solo recorre periodos **no terminados** ([SUPUESTO-C-03]), y el cierre suele correr con el periodo ya terminado. En ese caso lo que corrige la pérdida sin revisión es **reintentar el cierre**: su caso de uso vuelve a evaluar con avisos todos los grupos del periodo. Conviene ajustar el texto (y el mensaje operativo de `RCN_012` en el runbook): "reintente el cierre tras corregir la causa del fallo del motor". No cambia ninguna regla ni prueba.

## Veredicto

**VEREDICTO: APROBADO.** No quedan objeciones bloqueantes y el contrato C v3 puede congelarse (`CONTRACT.sha256`). La observación de §3.4 es solo de redacción.
