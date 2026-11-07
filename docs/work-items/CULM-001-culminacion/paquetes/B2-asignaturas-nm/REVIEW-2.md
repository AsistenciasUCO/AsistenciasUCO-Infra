# CULM-001 · Paquete B2 — REVIEW-2 (segunda ronda §9.2)

> **Fecha:** 2026-11-07. **Revisor:** el mismo Opus independiente de REVIEW-1. **Objeto:** `CONTRACT.md` v2 (731 líneas), §8 "Respuesta a REVIEW-1" y §7 (D-01..D-11).
> **Decisiones posteriores a REVIEW-1 que se verifican:**
> - DEC-025: `DROP COLUMN` en una migración 17 propia, justo después de la 16.
> - 403 (no 404) para ámbito ajeno en `/grupos/{id}/*`.
> - Los tres SP de ámbito los crea A.2 (`usp_consultar_directorio_estudiantes_paginado`, `usp_consultar_estudiantes_grupo_ambito_paginado`, `usp_consultar_asistencias_grupo_ambito_paginado`) y B2 los extiende.
>
> **Verificación:** grep en los worktrees `C:\Proyectos\GestionAsistencia-CULM001\<repo>` (DB `65a4998`) y en los contratos de A (`CONTRACT.md`, `CORRECCIONES-A.md`) y de B.

---

## 1. Estado de las objeciones de REVIEW-1

| Objeción | Estado | Comprobación |
| :--- | :--- | :--- |
| O-B1 | **Resuelta** | §1.4, §2.7.5, §3.1 y §3.3 extienden los tres SP de A.2 con los nombres de la decisión, sin redefinirlos, e incluyen el endpoint legacy. Se retiró el punto 6.4.5 |
| O-B2 | **Resuelta** | Comparé §2.7.4 con `git grep` de los SP que leen `.idPrograma` de `uv_resumen_asistencia_estudiante_grupo` o `uv_cumplimiento_sesion_grupo`. Salen 11 SP (`alerta_temprana`, `bitacora`, `comparativa_facultades`, `comparativa_programas_facultad`, `consolidado`, `historial_estudiante`, `kpis_coordinador` l.42/52, `kpis_decano`, `kpis_institucion`, `resumen_asistencia_estudiante_programa` l.50, `tendencia_ausentismo` l.56-57) y los 11 tienen línea y reemplazo. §2.7.5 cubre los consumidores de B (sábana, resumen del estudiante y sus entidades). Hay regla de inventario antes del RED y la prueba B2NM-15 |
| O-B3 | **Resuelta** | `uv_estudiante` con `tieneVinculoPrograma`, que solo exigen las ramas coordinador y decano. `usp_buscar_estudiantes_institucion_paginado` agrupa (l.70-73) y usa `DISTINCT` (l.83-85), así que el grano nuevo no duplica. `usp_registrar_estudiante_en_programa_interno` ya no depende de `uv_estudiante`. Pruebas B2NM-09 y B2NM-19 |
| O-B4 | **Resuelta** | Paso 1 solo para estudiantes activos sin vínculo; el paso 2 solo reporta `SIN_INTERSECCION`; el script de resolución ofrece dos vías; el riesgo 9 está ampliado |
| O-B5 | **Resuelta en la técnica, superada por DEC-025** | La técnica es correcta: SQL dinámico con `COL_LENGTH`, la verificación antes del `DROP` en la misma transacción y `52902` contando activos e inactivos. Pero el contrato sigue con el `DROP` en la migración 16 (ver O2-B1) |
| O-B6 | **Resuelta** | Prefijo `culm001_b2nm`, migración `16`, semillas `37`–`39`. No hay choque con A (`13_*`, `33_*`, `test_culm001_a_*`) ni con B (`14_culm001_b1_*`, `15_culm001_b2_*`, semillas `34`–`36`, `rol_asistencias_runtime_culm001_b1/_b2`, `test_culm001_b_`/`_b1_`/`_b2_*`). Los números de A.2 son un riesgo aparte (O2-N1) |
| O-B7 | **Resuelta** | 403 para un grupo fuera de ámbito sin cambiar los conjuntos de respuesta. `BACKEND_GOLDEN_PATH_CONTRACT.md` (filas 3 y 4) se actualiza en las dos copias con su `.sha256`, y las pruebas OpenAPI y de seguridad están nombradas |
| O-N1 … O-N10 | **Resueltas** | Les falta un detalle a O-N1 (prueba T-02 de A) y una consecuencia de DEC-025 en O-N9 (ver O2-B1 y O2-N2) |

## 2. Lista de comprobación (segunda pasada)

1. **3.8/3.9 y `AGENTS.md` — CUMPLE, salvo O2-B2.**
   - Puente N:M y carácter por catálogo con `orden` (ya no hay `OBL` quemado).
   - Coordinador de A ve solo a los estudiantes de A (R6), KPIs por programa (R9), sin sedes.
   - Los SP declaran `XACT_ABORT`, transacción, `IS NULL` y paginación sobre `uv_*`.
   - Las TVF leen solo tablas base, así que el despliegue limpio funciona. OnPush/signals y mensajes del backend.
2. **Aislamiento dentro de los SP — CUMPLE en el GREEN.**
   - `ufn_estudiantes_grupo_visibles` y `ufn_programas_ambito_ejecutor` cubren coordinador y decano.
   - Los tres SP de A.2 están extendidos.
   - O-N7 se resolvió con mínimo privilegio.
   - Queda el diferible D-04 (O2-B2).
3. **Migración — OBJECIÓN BLOQUEANTE (O2-B1).**
   - El orden interno de los pasos es correcto: precheck → tablas y parámetro → backfill de la puente → índices únicos y deduplicación → objetos programables → backfill de `EstudiantePrograma` → verificación y `DROP` → mensajes y permisos. El parámetro `CARACTER_DEFECTO` existe antes del backfill y la deduplicación va antes del índice único y del backfill.
   - Pero el contrato no refleja DEC-025, y aplicar DEC-025 tal cual, sin más cambios, rompe la ventana entre la 16 y la 17.
4. **Consumidores — CUMPLE.** Inventario de `idPrograma` completo (§1, O-B2). `uv_estudiante_grupo` (congelada) no se toca y B2NM-03 fija su cardinalidad.
5. **WORM — CUMPLE.** 1.2.0, cuatro archivos y cuatro `.sha256`, solo descripciones, 403 coherente con la l.27 del contrato backend.
6. **Pruebas RED y pruebas existentes — CUMPLE**, con el detalle de O2-N2.
7. **Dependencias con A y B — CUMPLE**, con las notas O2-N1 y O2-N3.
   - Base A: oferta de 19 columnas (A T-02 y B-RED-04) que pasa a 21; la regla ESP se elimina en las dos ramas.
   - Base B: versiones B.2 de las dos vistas y sus consumidores; el `down` restaura A+B.
8. **Diferibles frente a 3.8/3.9 — OBJECIÓN BLOQUEANTE en D-04 (O2-B2).** El resto no incumple:
   - D-01 y D-02 no producen fuga (F-DEC-014 filtra en el cliente datos ya de su facultad).
   - D-03, D-05, D-06, D-07, D-09 y D-11 son presentación o información adicional.
   - D-08 no incumple S4: la API ya responde `COO_002` y no hay coordinadores con varios programas en los datos. Queda documentarlo como TD, como ya dice §7.
   - D-10 está cubierto por T-SQL y `-Pintegration`.

---

## 3. Objeciones de esta ronda

### Bloqueantes

**O2-B1. El contrato no refleja DEC-025, y llevar el `DROP` a la 17 sin más cambios rompe la ventana 16 → 17.**

Siguen diciendo "misma migración" o "migración 16":
- R4 (l.32);
- §2.3, paso 7 del `up`, y el `down` de la 16;
- §6.1, riesgo 5;
- §6.2;
- §6.4.1 ("no se adopta");
- §8, fila O-B5;
- B2NM-12;
- el commit DB 8 (`BREAKING CHANGE: se elimina Asignatura.semestrePlanEstudio` dentro de la 16).

Además, si la columna sigue existiendo `NOT NULL` después de la 16, los `usp_crear_asignatura` y `usp_internal_asociar_asignatura_plan` nuevos, que insertan el catálogo sin `semestrePlanEstudio`, fallan con un error de `NOT NULL`. B2NM-01, B2NM-02 y la UI de "Nueva asignatura" fallarían mientras no se aplique la 17.

Corrección esperada:
- (a) R4 y §2.3 describen dos migraciones.
- **(b) Migración `16_culm001_b2nm_asignatura_plan_up/down.sql`:**
  - pasos 1–6 y 8 actuales;
  - más `ALTER TABLE dbo.Asignatura ALTER COLUMN semestrePlanEstudio UNIQUEIDENTIFIER NULL` (SQL dinámico con `COL_LENGTH`), que conserva la FK;
  - sin verificación final ni `DROP`.
- **(c) Migración `17_culm001_b2nm_retirar_semestre_plan_up/down.sql`:**
  - el `up` es el actual paso 7: verificación `52901` y `DROP CONSTRAINT`/`DROP COLUMN` en la misma transacción;
  - el `down` hace `ADD semestrePlanEstudio NULL`, la llena desde el único vínculo (`52902` si no es 1:1) y recrea la FK, dejando la columna `NULL` como al final de la 16.
- **(d) El `down` de la 16** se ejecuta solo con la columna presente (si no, `THROW`, con la indicación "ejecute antes el down de la 17"). Llena con el único vínculo las asignaturas creadas después de la 16 (`52902` si no es 1:1) y restaura `NOT NULL`.
- **(e) B2NM-12** cubre: `16 up` → crear y asociar con la columna `NULL` → `16 up` repetido → `17 up` → `17 up` repetido → fallo forzado de la 17 con la columna intacta → `17 down` → `16 down` → `16 up` → `17 up`, con `@@TRANCOUNT = 0` en cada paso.
- **(f) §6.2** describe el rollback en orden `17_down` → `16_down`. El commit 8 se divide: `feat(db): migracion 16 …` y `feat(db): migracion 17 retira Asignatura.semestrePlanEstudio`, este último con el `BREAKING CHANGE`. §6.4.1 y la fila O-B5 de §8 citan DEC-025.
- **(g) §5.2 paso 2:** la 17 se aplica en la misma ventana, solo con `db-test` de la 16 en verde. La limpieza del esquema (`schema/tables/Asignatura.sql` sin columna) equivale al estado posterior a la 17, y B2NM-16 lo fija.

**O2-B2. D-04 difiere una regla de 3.8 y de S4.**
`GET /coordinador/estudiantes` seguiría resolviendo el ámbito en Application, con un único programa: `ConsultarEstudiantesProgramaUseCaseImpl.java:17` llama a `findProgramaIdByCoordinadorUsuario`, que hace `singleUuid(HQL_PROGRAMA_POR_COORDINADOR)` (`InstitutionalScopeJpaRepository.java:195-196`). Y sigue usando JPQL sobre una vista (`EstudianteProgramaJpaRepository`). Eso incumple dos cosas:
- §3.8: "la validación se hace dentro de los SP";
- S4/DEC-021: "las listas usan todos sus programas". Es un `TOP 1` encubierto, en Java.

Corrección esperada, sin SP nuevo: sacar D-04 de §7 y apuntar `GET /coordinador/estudiantes` a `usp_consultar_directorio_estudiantes_paginado` de A.2, ya extendido por B2 con `ufn_programas_coordinador` y `@idPrograma` (`COO_003`). Se reutilizan su resultset (o se mapea a `EstudianteProgramaDTO`) y sus pruebas, y se agrega a B2NM-08 el caso "lista de un coordinador de 2 programas sin `programaId` incluye ambos". Si el orquestador prefiere conservar D-04, debe decidirlo de forma explícita en DECISIONES, como excepción a 3.8 con TD.

### No bloqueantes

**O2-N1.** `CORRECCIONES-A.md` (A.2) no reserva números de migración ni de semilla. Exige sembrar parámetros nuevos (`ARCHIVOS/LIMITE_SUBIDAS_POR_MINUTO`, `ASISTENCIA_QR/*`) y SP nuevos, y todavía no fija las firmas de los tres SP de ámbito. Además, para F-COO-003 dice "id inexistente o ajeno → 404", que contradice DEC-025 (403). Corrección: registrar en ESTADO o DECISIONES la reserva (A.2 → siguiente libre después de 17 y de 39, o números explícitos), y alinear el texto de A.2 con DEC-025 antes de congelar A.2.

**O2-N2.** En la tabla de pruebas existentes de §2.9 falta **A T-02**, que fija exactamente 19 columnas en `sys.dm_exec_describe_first_result_set_for_object` de la oferta. Pasa a 21 por el mismo cambio formal que `B-RED-04`/`OR08`.

**O2-N3.** El prefijo `culm001_b2nm` empieza con `culm001_b2`, el de B.2. Hay que declarar en §5.2 que ningún runner, manifiesto ni filtro de B usa comodines `culm001_b2*`/`culm001_b*`; los manifiestos de B usan rutas explícitas. Si alguno usa comodín, se cambia el filtro, no el prefijo.

---

VEREDICTO: 5 objeciones (bloqueantes: 2)

1. **O2-B1:** reflejar DEC-025 en todo el contrato.
   - La migración 16 deja `semestrePlanEstudio` como `NULL` (conserva la FK), para que los SP nuevos inserten sin la columna.
   - La migración 17 (`17_culm001_b2nm_retirar_semestre_plan_*`) hace la verificación `52901` y el `DROP` en una transacción, con un `down` que restaura desde la puente.
   - El `down` de la 16 exige la columna y restaura `NOT NULL`.
   - B2NM-12 prueba la secuencia 16/17 y sus `down`; el rollback va en orden 17 → 16; el `BREAKING CHANGE` va en el commit de la 17.
2. **O2-B2:** sacar D-04 de §7. `GET /coordinador/estudiantes` pasa a `usp_consultar_directorio_estudiantes_paginado` (A.2 + extensión B2), eliminando el `findProgramaIdByCoordinadorUsuario` de un único programa. Si se conserva, el orquestador lo decide como excepción explícita.
