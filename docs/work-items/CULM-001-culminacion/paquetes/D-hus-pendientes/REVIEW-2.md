# CULM-001 · Paquete D: REVIEW-2 (verificación de la v2, sección 9.2)

> **Objeto:** `CONTRACT.md` v2 (805 líneas, con la sección "Cambios respecto a v1") frente a `REVIEW-1.md` (11 bloqueantes y 20 observaciones) y `DECISIONES.md` **DEC-044**. **Revisor:** el mismo de REVIEW-1 (independiente del redactor). **Fecha:** 2026-11-07.
> **Verificación en código:** worktrees `C:\Proyectos\GestionAsistencia-CULM001\*` (`integracion/CULM-001`) y contrato B (`paquetes/B-tomas-qr-sesiones/CONTRACT.md`) para los IDs de pruebas citados. No se modificó el contrato ni código; no hay commit.
> **Formato:** cada punto lleva CUMPLE u OBJECIÓN. **[R-n]** son residuos menores: se corrigen en la edición de congelación sin otra ronda.

---

## 1. Desviaciones del redactor que el orquestador propone aceptar

| Desviación | Resultado | Motivo |
| :--- | :--- | :--- |
| (a) Nombres reales `usp_radicar_solicitud_revision_asistencia_v2`/`_v3` e interno `usp_internal_radicar_solicitud_revision` (DEC-044 (3) dice `usp_registrar_reclamo_v2/v3`) | **CUMPLE, se acepta** | Son los nombres que existen en `schema/stored-procedures/` y en el manifiesto LB-004D. Con los de DEC-044, la línea del manifiesto autorizada no correspondería a ningún archivo. Conviene anotar la corrección de nombre en DEC-044 o en una nota del orquestador, para que la autorización de manifiesto de DEC-044 (11) apunte al archivo real (`usp_radicar_solicitud_revision_asistencia_v2.sql`). |
| (b) F-TRX-021: el Excel por grupo mantiene 403 (DEC-025/[SUPUESTO-D-14]); solo las mallas por plan usan el 404 `PLA_002` de B2 | **CUMPLE, se acepta** | Es lo que pedía REVIEW-1 [BLOQ-4] (a). `PLA_002` es un mensaje de plan y no aplica a `/grupos/{id}/reportes/asistencia-excel`. El 403 uniforme de `/grupos/{id}/*` es la regla de DEC-025 que A y B2 ya aplican. Las mallas por plan quedan con el 404 de B2, con pruebas de regresión D9-TRX-02/03. |

## 2. Bloqueantes de REVIEW-1

| ID | Resultado | Verificación |
| :--- | :--- | :--- |
| BLOQ-1 Semillas | **CUMPLE** | Semillas `51`–`59` en la cabecera y en todas las secciones. La búsqueda `4[1-9]_culm001` en el contrato da 0 resultados. C conserva `40`/`41` (C CONTRACT [SUPUESTO-C-01]). `PLAN.md` línea 5 ya dice `50 + x`. Queda un residuo de `PLAN.md`: [R-3]. |
| BLOQ-2 Lectura de sesiones | **CUMPLE** | Vista nueva `uv_sesion_estudiante_reclamo` sobre `uv_sesion_v2` + `uv_sesion_estado` (las dos existen) + `uv_estudiante_grupo`, y SP `usp_consultar_sesiones_materia_estudiante` con ámbito en el SP. `uv_sesion` (congelada) no se toca. La HQL de `SesionMateriaEstudianteJpaRepository` se sustituye. Hay una ambigüedad en D1-10: [R-2]. |
| BLOQ-3 v2/v3 e idempotencia | **CUMPLE** | Interno con parámetros `OUTPUT` que no emite resultset; v2 y v3 lo llaman y cada uno emite el suyo. Regla general en §1.4 ("nunca `INSERT … EXEC`"). Orden: reejecución idempotente → plazo, en v2 (D.1) y en el interno (D.2). Pruebas D1-12, D2-15 y D2-16 (búsqueda en `sys.sql_modules`). |
| BLOQ-4 B2 | **CUMPLE** | (a) Las mallas por plan siguen el 404 `PLA_002` de B2 (D solo añade regresión) y [SUPUESTO-D-14] queda acotado a rutas por grupo. (b) D.8 y D.9-a dependen de B2 (§1.1, §13.1 y `PLAN.md`). D.8 se escribe sobre `uv_resumen_asistencia_estudiante_programa_grupo` con grano (grupo, programa) y tiene una prueba propia (D8-07). Los `down` de 27 y 28 restauran el texto de B2. |
| BLOQ-5 `realtime/emit` | **CUMPLE** | Se mantiene solo ADMINISTRADOR (`SecurityConfig.java:215`) con cuerpo validado (`{}`, tipo desconocido o sin audiencia → 400). §10 dice "cambia la validación (no se retira)", conforme a DEC-042 y DEC-044 (5). |
| BLOQ-6 Consumidores de `ApiPageResponse` | **CUMPLE** | §11.3 enumera: los 7 métodos del servicio transversal, el mock, el interceptor de mocks, `dean-facultad`, `admin-management`, `attendance-claim`, los 9 componentes, las 3 pruebas de controlador y las líneas exactas de `test_all_hus.ps1` (más el caso HU156). Cada uno con su prueba RED, y una búsqueda de `\.datos` que debe quedar vacía en el GREEN. |
| BLOQ-7 ClamAV y límite de subidas | **CUMPLE** | Backend: secuencia de 3 subidas con EICAR en la segunda (sin `fileId` ni fila), límite por minuto con 429 sin afectar a otro estudiante, `fileId` inexistente u `ORPHAN` → `ARC_001`, y `tamanioMaximoBytes` ≤ multipart. Frontend: error por archivo y lista enviada sin ids fallidos. |
| BLOQ-8 `down` de D.2 y orden de rollback | **CUMPLE** | El `down` de 21 archiva categorías y soportes colapsados en `zz_archivo_*` y anula los tres campos que exige `CK_ArchivoSoporte_EstadoVinculo`. El `up` siguiente los restaura (D2-13). §14.2 fija el orden por objeto compartido, con aborto (`THROW 50020`/`50024`) y pruebas D-RB-01…03. |
| BLOQ-9 D8-03 | **CUMPLE** con residuo | Cada porcentaje se compara con su esperado y el cuarto se calcula como `100 −` la suma de los otros tres. Falta acotar el caso en que el cuarto saldría negativo: [R-1]. |
| BLOQ-10 Ámbito global | **CUMPLE** con residuo | [SUPUESTO-D-16] está aceptado por DEC-044 (10). `usp_actualizar_parametro` y `usp_consultar_parametros_paginado` comprueban que hay una sola `Institucion` activa (`PRM_012`, D3-17). Los fixtures que crean una segunda institución (`culm1_segundo_ambito.sql` usa la sembrada; las pruebas de KPI y festivos la crean dentro de una transacción con `ROLLBACK`) no rompen la regla. A la auditoría le falta código y prueba: [R-4]. |
| BLOQ-11 Manifiestos y golden path | **CUMPLE** | §12 tiene la lista exacta de 6 líneas de LB-004D y deja fuera, de forma explícita, `15_lb004d_*`, `rol_*_lb004d` y `usp_registrar_archivo_soporte`. Incluye la línea UTC-D06 y la regla de regenerar en el mismo commit, también en los commits RED. `DB_CULM001_D_POST_FREEZE_MANIFEST` nace en el primer GREEN. Golden path **1.6.0** tras el 1.5.0 de C (406 en `/realtime/stream` y `POST /realtime/emit`), con `.sha256` y prueba de conformidad, conforme a DEC-044 (11). |

## 3. Observaciones de REVIEW-1

| ID | Resultado | Verificación |
| :--- | :--- | :--- |
| OBS-1 | CUMPLE | `IF EXISTS … DROP` / `IF NOT EXISTS … CREATE`, con comentario nuevo. |
| OBS-2 | CUMPLE | `JpaProcedureExecutor`/`CanonicalProcedureResult` y la ruta real de `SlidingWindowRateLimiter`. La búsqueda de `CanonicalStoredProcedure` e `infrastructure/ratelimit` da 0 resultados. |
| OBS-3 | CUMPLE | La función ramifica por `valoresPermitidos`, `PARAMETROS/TIPOS_NUMERICOS` y `PARAMETROS/TIPOS_ENTEROS`, sin literales de tipo. |
| OBS-4 | CUMPLE | ISO-8601 UTC con milisegundos; pruebas D3-18 y de ida y vuelta en adaptador y controlador. |
| OBS-5 | CUMPLE | `tipoIdentificacionId` en D.4 y en el E2E. |
| OBS-6 | CUMPLE | `PUT /admin/estudiantes/{id}/identidad` no es diferible. El `CASE` de la línea 47 pasa a parámetros con rama de ámbito por perfil; D4-10 comprueba que no queden literales. |
| OBS-7 | CUMPLE | El backend envía siempre los dos filtros; el SP rechaza `1/1`. D6-05 cubre los tres casos y el adaptador. |
| OBS-8 | CUMPLE | `MATRICULA/ESTADO_INSCRITA` (existe, `33_culm001_a_catalogos.sql:19`). |
| OBS-9 | CUMPLE | Los 11 grupos "nunca" están en `PARAMETROS/GRUPOS_NO_EDITABLES` y D3-03 recorre cada uno. |
| OBS-10 | CUMPLE | Parámetro al final de la firma; D5-12 prueba que los llamadores actuales no cambian. |
| OBS-11 | CUMPLE | `clave_inicial` exenta de la regla de fórmulas, con prueba en el parser. |
| OBS-12 | CUMPLE | `password` fuera de `metadata` y de los logs del `GlobalExceptionHandler` (400 y 500), en D.4 y D.5. |
| OBS-13 | CUMPLE | Rangos 437+ (incluido `VAL_007`) y 196–240. También los marcadores de `test_summary.ps1` (líneas 74 y 178–190) y de `test-summary.ps1` de Infra, y los consumidores Java. IDs de B.2 verificados en el contrato B: B2-TOM-03 (l. 866), B2-TOM-09 (l. 872), B2-QR-01 (l. 886) y B2-QR-10 (l. 895). Como ninguno cubre el registro por token después del cierre de la ventana, D.7 añade D7-04. |
| OBS-14 | CUMPLE | `PARAMETER_UPDATED` va después de C (ola 5). |
| OBS-15 | CUMPLE | `PAGINACION/TAMANO_MAXIMO` y `PAG_001`; no se crea `GENERAL/TAMANO_PAGINA_MAXIMO`. |
| OBS-16 | CUMPLE | `infra.ps1` y `.env.example` aportan la variable, con prueba de arranque en un checkout limpio. |
| OBS-17 | CUMPLE | Filtro después de la autenticación; anónimo → 401. |
| OBS-18 | CUMPLE | `AGENTS.md` no se edita; "no-se-corrige (propuesta)" a confirmar por el orquestador. |
| OBS-19 | CUMPLE | Deudas nuevas listadas, con número a reservar con el orquestador. |
| OBS-20 | CUMPLE | Objetos de la migración 28 listados (§11.2) y `usp_reintentar_notificacion_saliente` nombrado. |

## 4. Residuos nuevos (no bloqueantes; corrección exacta)

- **[R-1] D.8: el cuarto porcentaje puede salir negativo.** Con `porcentajeSinRegistro = 100 − (A + I + E)`, si los tres redondeos suben (por ejemplo 33,335 + 33,335 + 33,33 = 100,01), resulta −0,01. *Corrección:* `porcentajeSinRegistro = MAX(0, 100 − suma)`. Si `100 − suma < 0`, el exceso se resta del mayor de los tres redondeados, de modo que los cuatro sigan sumando `100.00` y ninguno sea negativo. Añadir D8-09 con ese caso.
- **[R-2] D1-10 es ambiguo.** (a) La HQL actual no filtra por estado de matrícula y el SP nuevo sí (`MATRICULA/ESTADO_INSCRITA`), así que "mismas filas que la HQL" solo se cumple con matrículas `A`. *Corrección:* la paridad se mide sobre matrículas `A`, y con `I`/`CI` el SP devuelve 0 filas, como cambio intencional según DEC-022 §3. (b) Para "materia ajena → 0 filas o error de ámbito según el contrato existente", fijar **0 filas** (lo que hace hoy la HQL). (c) Precisar que `plazoJustificacionVigente = 0` cuando `estaCancelada = 1`.
- **[R-3] `PLAN.md` desactualizado.** La línea 3 dice "(v1, pendiente de la revisión 9.2)". La línea 48 ("Si falta tiempo") conserva el orden de v1 (`D.2, D.8 > D.5 > D.9`, con D.5 diferible). Además pone D.8 en la ola 2, mientras §13.1 lo pone en la ola 3. *Corrección:* alinear con DEC-044 y §1.2/§13.1: `D.1, D.3, D.4, D.6, D.7 > D.2 > D.8 > D.5, D.9`, D.5 no diferible, solo los diferibles de §1.2. La nota de §14.3 ("PLAN no se editó") pasa a "alineado".
- **[R-4] Ámbito de auditoría sin código ni prueba.** §7.3 dice "Comprobación de [SUPUESTO-D-16]" en `usp_consultar_auditoria_eventos_paginado` sin código de mensaje. *Corrección:* reutilizar `PRM_012` con un texto genérico o crear `AUD_0xx` (nuevo, sin choque), y añadir D6-06: segunda `Institucion` activa en la transacción de prueba → ese código, sin filas.

---

**VEREDICTO: APROBADO.** Los 11 bloqueantes y las 20 observaciones de REVIEW-1 están resueltos, y se aceptan las dos desviaciones del redactor (nombres reales de v2/v3 y 403 en el Excel por grupo). Los residuos [R-1]…[R-4] son de redacción o de una regla puntual y no reabren el diseño. Se aplican en la edición de congelación, antes de firmar el `.sha256` y de empezar el RED, y basta con que el orquestador los compruebe; no hace falta REVIEW-3. [R-1] es obligatorio porque evita un porcentaje negativo en producción.
