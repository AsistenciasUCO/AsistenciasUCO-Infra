# CULM-001 · Paquete B2 — REVIEW-1 (revisión independiente de contrato, §9.2)

> **Fecha:** 2026-11-06. **Revisor:** Opus independiente (no redactó el contrato). **Objeto:** `CONTRACT.md` (598 líneas) y `PLAN.md` de B2.
> **Insumos leídos:** `RESEARCH-ASIGNATURA-PLAN.md`, `DECISIONES.md` (DEC-019, DEC-020, DEC-021), `AGENTS.md` §3.3 y §4, `docs/PROMPT_FABLE_CULMINACION.md` §3.8–§3.9, los CONTRACT de A y B (borradores actuales del worktree).
> **Verificación:** grep sobre `C:\Proyectos\GestionAsistencia-CULM001\<repo>` (rama `integracion/CULM-001`, DB `65a4998`). Las líneas citadas son de esa versión.
> S1–S4 ya están aceptados por DEC-021; esta revisión no los reabre y los confirma (ver §9).

---

## 1. Cumplimiento de 3.8/3.9 y de `AGENTS.md` — **OBJECIÓN (parcial)**

Cumple en lo esencial: tabla puente con carácter por catálogo (R1), código único global (R2), separación crear/asociar (R3), `uv_grupo_programa` 1:N con consumidores `EXISTS`/`DISTINCT` (R5), pertenencia por `EstudiantePrograma` (R6), invariante de matrícula (R7), eliminación de los cuatro `TOP 1` (R8, verificados: `usp_registrar_estudiante_en_grupo_interno.sql:122`, `usp_validar_gestion_grupo_coordinador_o_titular_interno.sql:101`, `usp_validar_docente_vinculo_activo_programa_interno.sql:33`, `usp_resolver_programa_coordinador_interno.sql:51`), KPIs por programa (R9), sin sedes. Los SP nuevos declaran `SET XACT_ABORT ON`, transacción explícita, `IS NULL`, paginación `OFFSET/FETCH` + `COUNT(*) OVER()` sobre `uv_*`, mensajes del backend, OnPush/signals.

Incumplimientos concretos (detalle en las objeciones):
- Dos endpoints de golden path en los que §3.8 exige "solo los estudiantes de su programa" siguen sin SP ni ejecutor (O-B1).
- El nuevo grano de `uv_estudiante` rompe R10 para administrador, docente y el propio estudiante (O-B3).
- `usp_consultar_oferta_grupos_estudiante` "prioriza `OBL`": es un código quemado en T-SQL (O-N4).
- Funciones inline sobre vistas que no se pueden desplegar en BD limpia (O-N3).

## 2. Aislamiento jerárquico DENTRO de los SP — **OBJECIÓN BLOQUEANTE (O-B1)**

Bien resuelto para KPIs, alertas, ficha, bitácora, sesiones, asistencias por sesión, grupos del coordinador, malla y decano: el ejecutor viaja al SP y la regla está en `ufn_estudiantes_grupo_visibles` / `ufn_programas_coordinador`.

No resuelto:
- `GET /api/v1/grupos/{grupoId}/estudiantes`: `ConsultarEstudiantesGrupoUseCaseImpl` → `GrupoJpaRepository.consultarEstudiantesGrupo(grupoId)` (l.205) → `HQL_ESTUDIANTES` sobre vista, **sin ejecutor**; el coordinador "conserva visibilidad institucional amplia" (javadoc del caso de uso).
- `GET /api/v1/grupos/{grupoId}/asistencias` y su legacy `POST /api/v1/asistencias/consultas/grupo`: `AsistenciaJpaRepository.consultarAsistenciasPorGrupo` (l.190) → `HQL_CONSULTAR_ASISTENCIAS`, sin ejecutor.
- `GET /api/v1/estudiantes` y `/{id}`: `EstudianteJpaRepository` `HQL_COUNT`/`HQL_PAGE`/`HQL_CONTEXTOS` (l.54-56), sin SP.

El contrato (§1.4, §3.1 fila "`/grupos/{id}/estudiantes`… SP de grupos/sesiones con `ufn_estudiantes_grupo_visibles`") da por hecho que existen SP para esto o que A los crea. **El CONTRACT de A no los crea**: cubre F-COO-004 y F-COO-012 (retiro de solicitudes), no menciona F-COO-001, F-COO-002, F-COO-003 ni F-DOC-013 (grep: 0 coincidencias) ni ningún SP de directorio. §6.4.5 lo deja como hipótesis.

## 3. Migración — **OBJECIÓN BLOQUEANTE (O-B4, O-B5)**

- **Backfill 1:1** de la puente: correcto (guarda `COL_LENGTH`, `WHERE NOT EXISTS`, precheck de duplicados de código con el patrón de `06_*`).
- **`EstudiantePrograma`**: el paso 1 coincide con DEC-020 salvo "matrículas (cualquier estado)" frente a "estudiante activo" de la decisión. El **paso 2 va más allá de DEC-020** (O-B4).
- **Idempotencia**: no está garantizada tal como se redactó. En T-SQL, una referencia a una columna que no existe en una tabla que sí existe es un error de compilación del lote aunque esté dentro de un `IF` (aquí no hay resolución diferida). Si el precheck del paso 1, el backfill del paso 4 o el `UPDATE` del `down` (después del `ADD`) no van en SQL dinámico o en otro lote, el segundo `up` y el `down` no compilan. T-B2-12 lo detectaría, pero el contrato tiene que fijar la técnica (O-B5).
- **Conservación de datos**: la verificación final (paso 11, `THROW 52901` si alguna asignatura quedó sin vínculo) va **después** del `DROP COLUMN` (paso 10). Con una transacción por bloque, la columna ya se borró cuando se lanza el error: se pierde lo único que permite reconstruir el vínculo (O-B5).
- **`down`**: el aborto con datos N:M (`52902`) es correcto y conservador. Hay que definir si cuentan los vínculos inactivos: una asignatura desvinculada de A y asociada a B tiene 2 filas y 1 activa.
- **¿`DROP COLUMN` en una migración posterior?** DEC-019 lo decidió "al final de la misma migración" y no lo reabro. Con O-B5 corregido (verificación antes del `DROP`, `DROP` en el último lote y dentro de una transacción con la verificación, backup COPY_ONLY obligatorio, que ya está en §6.2) el riesgo es aceptable. **Recomendación opcional al orquestador:** separar el `DROP` en `NN+1_*` dentro de la misma ventana de despliegue. El estado final es el mismo y queda un punto de control sin doble escritura. Solo vale la pena si se teme un GREEN parcial del backend.

## 4. Inventario de consumidores — **OBJECIÓN BLOQUEANTE (O-B2, O-B3)**

Lo comparé con `git grep` (`semestrePlanEstudio`, `uv_grupo_programa`, `uv_resumen_asistencia_estudiante_grupo`, `uv_cumplimiento_sesion_grupo`, `uv_asignatura`, `uv_estudiante`, `uv_docente`):

| Consumidor | En el contrato | Problema |
| :--- | :--- | :--- |
| `usp_consultar_tendencia_ausentismo` (l.56-57 `c.idPrograma`) | **No** | `uv_cumplimiento_sesion_grupo` pierde `idPrograma` → "Invalid column name" en ejecución |
| `usp_consultar_kpis_institucion` (l.63-78 `r.idPrograma`, `c.idPrograma`) | Solo l.43/83 | Las uniones por `r.`/`c.idPrograma` también se rompen |
| `usp_consultar_comparativa_facultades` (l.33-52 `r.idPrograma`) | Como "DISTINCT vía `uv_grupo_programa`" | En realidad lee `r.idPrograma`: hay que reescribirlo sobre `uv_resumen_asistencia_estudiante_programa_grupo` |
| `usp_consultar_kpis_decano` (l.46-55 `r.idPrograma`) | Fila sin fuente | Falta decir de dónde sale el programa/facultad |
| `usp_consultar_bitacora_estudiante_programa` (l.79 `c.idPrograma`) | Sí (regla) | Hay que nombrar el reemplazo de `c.idPrograma` |
| B: `usp_consultar_resumen_asistencia_grupo_docente_paginado`, `usp_consultar_resumen_asistencia_estudiante` (CONTRACT B l.619-620: "columnas de `uv_resumen_asistencia_estudiante_grupo`", que B conserva con `idPrograma`, l.339) y sus entidades backend | **No** | Se rompen o cambian de resultset al quitar `idPrograma` |
| `usp_registrar_estudiante_en_programa_interno` (l.46-48: institución por `uv_estudiante`) | Se reutiliza en §2.7.3 | Con el `uv_estudiante` nuevo (fila solo si hay `EstudiantePrograma`), un estudiante sin vínculo da `GEN_002`, justo el caso que §2.7.3 debe crear |
| `usp_buscar_estudiantes_institucion_paginado` (l.65, por `uv_auth_estudiante`) y las ramas administrador/docente/propio de `uv_auth_estudiante` | **No** | El administrador y el docente dejan de ver a los estudiantes sin vínculo o `AMBIGUO` (contra R10) |
| `uv_docente_programa` (l.43, `COUNT(DISTINCT x.idGrupo)` sobre `uv_docente`) | No | Correcto con 1:N, pero debe estar en la prueba de cardinalidad |
| `uv_docente.idPlanEstudio/inpPlanEstudio` | Solo el programa | Falta fijar su valor (O-N5) |
| `uv_auth_asistencia` | No | Hoy no tiene consumidores; si se usa, filtra a nivel de grupo (O-N6) |
| `usp_guardar_horarios_grupo`, `usp_precargar_sesiones_grupo`, `usp_actualizar_grupo` | Heredan | Política (O-N7) |

Las columnas que se retiran de `uv_asignatura` (`idSemestrePlanEstudio`, `inp`, `codigoSemestre`, `nombrePrograma`) solo se usan en SP que ya están en el contrato. Correcto.

**Vista congelada `uv_estudiante_grupo`: CUMPLE.** Une `uv_grupo` (l.de joins: `EstudianteGrupo`, `uv_estudiante_identidad`, `uv_estado_estudiante_grupo`, `uv_grupo`), y `uv_grupo` solo lee `a.id`/`a.nombre` de `uv_asignatura`. Con `uv_asignatura` en 1 fila por asignatura no se duplica. Las vistas de la cadena (`uv_plan_estudio`, `uv_programa`, `uv_semestre_plan_estudio`) no tienen `WHERE`, así que quitar los joins no cambia el conjunto de grupos. El manifiesto (`freeze-manifest.ps1:27-37`) no se edita.

## 5. Cambio de contrato WORM (golden path 1.2.0) — **OBJECIÓN BLOQUEANTE (O-B7)**

Está justificado: el significado de `programaId` en `GET /api/v1/estudiantes` y el filtrado por programa para COORDINADOR en `/grupos/{id}/estudiantes|asistencias` son cambios semánticos reales; DEC-021 lo acepta.

Está **incompleto**:
- `BACKEND_GOLDEN_PATH_CONTRACT.md` (Infra `docs/contracts/openapi/` y Backend `docs/contracts/`, cada uno con su `.sha256`) dice en la fila 3 (l.37) "Devuelve todos los estudiantes del grupo" y en la l.27 "titularidad ajena: 403". §3.4 afirma que no cambia, pero el nuevo filtrado lo contradice.
- Agregar `404` contradice la l.27. **Forma de reducir el cambio:** usar **403** para un grupo fuera de ámbito, como ya dice el contrato vigente. Así no se toca el conjunto de respuestas de la OpenAPI y solo cambian las descripciones.
- Faltan las pruebas que fijan el contrato: `OpenApiGoldenPathConformanceTest` (versión, l.111, y conjuntos de respuestas, l.80-81 y l.419-420), `OpenApiEstudiantesDirectoryConformanceTest`, `OpenApiGoldenPathValidationTest`, `RbacSecurityFilterChainTest`, `SecurityPepEnforcementFilterTest`, el `<include>` del `pom.xml` (l.375) e `infra/scripts/quality/verify-contracts.ps1` (paridad entre repositorios).

## 6. Pruebas RED y pruebas existentes que cambian — **OBJECIÓN (O-N1, O-N2)**

T-B2-01..14 cubren R1, R3–R9, S1, S3 y S4. Faltan:
- **S2 / `ASI_006`**: ninguna prueba (actualizar o activar/desactivar una compartida por CA con CB vinculado).
- **R8** en `usp_guardar_horarios_grupo` y `usp_precargar_sesiones_grupo` con CB sobre G.
- **R10 del administrador** (`usp_buscar_estudiantes_institucion_paginado` con un estudiante `AMBIGUO`).
- `usp_consultar_programas_grupo` (`GEN_001` fuera de ámbito).
- `totalRegistros` con una asignatura compartida en `usp_consultar_asignaturas_coordinador_paginado`, `_planes_estudio_programa_paginado` y `_estudiantes_programa_paginado`.
- Una prueba de compilación de todos los módulos después de la migración (`sp_refreshsqlmodule` sobre cada vista/SP/función), que habría detectado O-B2.
- Despliegue en BD limpia (O-N3).
- Frontend: selector de programa ante `COO_002`, modal de la ventana QR, pantalla pública con `requiereProgramaDocente`, rótulo "n de m" en grupos.

La afirmación "los 31: solo el arrange; ninguna aserción" no es exacta, y la lista de pruebas existentes que cambian está incompleta (O-N1).

## 7. Dependencias con A y B — **OBJECIÓN BLOQUEANTE (O-B1, O-B2, O-B6)**

- **A**: ver O-B1 (directorio y grupos no están en A). Además, B2 debe partir de la versión de A de:
  - `usp_consultar_oferta_grupos_estudiante` (21 columnas con `OUTER APPLY`, A E-01);
  - la regla ESP que A **mantiene** en la rama de reactivación (A §2.3 paso 7 y T-07/RI-04 "con INS o BAS no lo inserta"), que R7 contradice: B2 tiene que eliminarla en las dos ramas y cambiar RI-04 como cambio formal.
- **B**: B conserva `idPrograma` en `uv_resumen_asistencia_estudiante_grupo` (B l.339), agrega columnas a `uv_cumplimiento_sesion_grupo` (`totalTomas`, `horasSesion`) y crea consumidores nuevos (B §2.9, l.619-620). El contrato de B2 dice "se aplica sobre la versión de B" pero no lista esos consumidores (O-B2). El `down` de B2 debe restaurar la versión B.2 de las dos vistas, no la de `develop`.
- **Colisiones de nombres**:
  - semilla `33_*` (A, E-08); `34_*`/`35_*`/`36_*` (B, l.647, 693, 714, 734, 756);
  - `schema/security/rol_asistencias_runtime_culm001_b2.sql` (B l.739, mismo nombre exacto que B2 §2.8.2);
  - prefijos `test_culm001_b2_*` (B l.809) y `migrations/15_culm001_b2_*` (B l.749), porque el subpaquete "B.2" de B usa el mismo prefijo `b2`.

## 8. Alcance frente al plazo del 2026-11-13 (recomendación; decide el orquestador)

**Imprescindible para cumplir 3.8/3.9 y DEC-019/020/021:**
1. BD:
   - catálogo de carácter, puente, migración con backfill (paso 1) y reporte;
   - `uv_asignatura` como catálogo, `uv_asignatura_plan_estudio`, `uv_grupo_programa` 1:N, `uv_estudiante_grupo_programa`, `uv_resumen_asistencia_estudiante_programa_grupo`;
   - quitar `idPrograma` de las dos vistas de B **con todos sus consumidores**;
   - `uv_auth_*`, las cuatro `ufn_*` y los cuatro `TOP 1`;
   - crear, asociar y desvincular;
   - matrícula manual con `EST_005`/`EST_006` y QR con `MQR_008`;
   - KPIs, alertas, ficha, bitácora y resumen del coordinador;
   - asistencias por sesión, sesiones y grupos con filtro R6;
   - HU008, oferta docente y `usp_crear_grupo`;
   - KPIs, aforo y comparativas del decano e institución con `DISTINCT`;
   - SP de malla (el HQL actual se rompe al quitar columnas);
   - SP de directorio, estudiantes de grupo y asistencias de grupo (O-B1);
   - semilla de dos programas para el AUDIT.
2. Backend: repositorios que se rompen por las columnas retiradas, asociar/desvincular (cierra F-COO-005), los tres endpoints de O-B1 por SP, clasificador de errores, OpenAPI.
3. Frontend: malla con carácter, asociar y quitar; carácter en el formulario; selector de programa en la matrícula manual; ajuste mínimo de los modelos con campos cambiados (`planes`, `programas`).

**Diferible sin incumplir las decisiones:**
- F-DEC-013: `sesionesEvaluadasPorMatricula`, `matriculasActivas` y sus rótulos.
- F-DEC-014: `idGrupo` en servidor.
- Paginación en la UI de planes, asignaturas y estudiantes del coordinador (el SP puede entregar `ApiPageResponse` y la UI seguir con una sola página).
- `totalObligatorias`/`totalOptativas`, `estudiantesCompartidos`, `programasCompartidos`, chips y tooltips.
- El rótulo "n de m".
- F-COO-011: modal en lugar de `confirm()`.
- S3 completo: `TokenMatriculaGrupo.programaPorDefecto` y selector en la ventana QR. Sin S3, `MQR_008` y la matrícula manual del docente cumplen DEC-020 ("el que elija el docente"), pero DEC-021 aceptó S3, así que diferirlo exige la anotación del orquestador.
- Los usuarios Keycloak del segundo coordinador (pruebas por SP).

---

## 9. Respuesta a los puntos abiertos de §6.4

1. S1–S4: confirmados (DEC-021).
2. Asociar una asignatura de otra facultad de la misma institución: se mantiene el ámbito institucional (catálogo institucional, §3.9 "optativas y transversales"); `asociables` no expone datos personales.
3. y 4. Fuera del contrato: registrar en `PRS.md`. Si no hay usuarios Keycloak, la matriz de dos programas se prueba en T-SQL (T-B2-05..08) y en `-Pintegration`.
4. (5) Resuelto por O-B1: A **no** lo hace; B2 lo asume de forma explícita.

---

## 10. Objeciones

### Bloqueantes

**O-B1. Ámbito de directorio, estudiantes de grupo y asistencias de grupo sin SP ni dueño.**
Corrección: agregar a §2.7.1 y §3.1/§3.3:
- `usp_consultar_estudiantes_directorio_paginado(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @busqueda, @idTipoIdentificacion, @idInstitucion, @idFacultad, @idPrograma, @idGrupo, @idEstudiante = NULL)`:
  - coordinador por `ufn_programas_coordinador` ∩ `EstudiantePrograma`, administrador por institución, DOCENTE y ESTUDIANTE → `SEC_001` (403);
  - `@idPrograma` ajeno → `COO_003`;
  - `@idEstudiante` fuera de ámbito → `GEN_001` (404 en `/{id}`).
- `usp_consultar_estudiantes_grupo(@idUsuarioEjecutor, @idCorrelacion, @idGrupo)` y `usp_consultar_asistencias_grupo(@idUsuarioEjecutor, @idCorrelacion, @idGrupo, @idSesion = NULL)`:
  - grupo fuera de ámbito → `SEC_002` (403, ver O-B7);
  - filas por `ufn_estudiantes_grupo_visibles`;
  - mismo resultset que el `ApiListResponse` congelado (`id, idEstudiante, documento, nombreCompleto, correo, codigoEstado, nombreEstado` / `AsistenciaConsultadaDTO`).
- Reemplazar `EstudianteJpaRepository.HQL_*`, `GrupoJpaRepository.HQL_ESTUDIANTES` y `AsistenciaJpaRepository.HQL_CONSULTAR_ASISTENCIAS`, también en el endpoint legacy.
- Pruebas T-SQL, de caso de uso y de controlador.
- Retirar §6.4.5 y la columna "Paquete A" de §1.4, salvo que el orquestador congele antes del RED de B2 un addendum de A con exactamente esto.

**O-B2. Consumidores que se rompen al quitar `idPrograma` de `uv_resumen_asistencia_estudiante_grupo` y `uv_cumplimiento_sesion_grupo`.**
Corrección:
- Agregar a §2.7.2:
  - `usp_consultar_tendencia_ausentismo` (l.56-57): programa por `EXISTS uv_grupo_programa` con `DISTINCT` por sesión;
  - las líneas exactas a reescribir en `usp_consultar_kpis_institucion` (l.63-78), `usp_consultar_comparativa_facultades` (l.33-52), `usp_consultar_kpis_decano` (l.46-55) y `usp_consultar_bitacora_estudiante_programa` (l.79), con su fuente (`uv_resumen_asistencia_estudiante_programa_grupo` para conteos por programa; `uv_grupo` + `EXISTS uv_grupo_programa` + `DISTINCT` para facultad e institución).
- Agregar una sección "consumidores introducidos por B" con `usp_consultar_resumen_asistencia_grupo_docente_paginado`, `usp_consultar_resumen_asistencia_estudiante` y las entidades/proyecciones backend de B que mapean `idPrograma`, y la regla de que antes del RED se repite el inventario con `git grep -E "idPrograma" ` sobre los consumidores de las dos vistas en la base A+B.
- Nueva prueba T-B2-15: `sp_refreshsqlmodule` sobre todas las vistas, SP y funciones de `dbo` después del `up`, sin errores.

**O-B3. El nuevo grano de `uv_estudiante` rompe R10 y la creación del vínculo.**
Corrección:
- `uv_estudiante` = 1 fila por (estudiante, grupo, programa del grupo) desde `uv_estudiante_grupo` + `uv_grupo_programa`, con la columna `tieneVinculoPrograma BIT` (`EXISTS EstudiantePrograma`).
- En `uv_auth_estudiante`, solo las ramas coordinador y decano exigen `tieneVinculoPrograma = 1`; las ramas administrador, docente titular y propio no.
- Los consumidores que cuentan usan `DISTINCT` (agregar `usp_buscar_estudiantes_institucion_paginado` a §2.7.2).
- `usp_internal_asegurar_estudiante_programa_grupo` no reutiliza `usp_registrar_estudiante_en_programa_interno` sin cambios: la institución se valida contra el programa elegido, que por construcción es del grupo (o se modifica la l.46-48 para resolverla por `uv_estudiante_grupo` → grupo → programa).
- Pruebas: administrador y docente ven a un estudiante `AMBIGUO`; matrícula de un estudiante sin ningún vínculo → vínculo creado.

**O-B4. El paso 2 del backfill de `EstudiantePrograma` excede DEC-020 y revierte la depuración de transversales.**
DEC-020 autoriza crear vínculos solo para "todo estudiante activo sin programa". El paso 2 crea vínculos para estudiantes que ya tienen programa, que son justo los que `hu008_depurar_estudiante_programa_transversales.sql` retiró. Eso amplía el directorio, la ficha y el derecho a corregir la identidad (`usp_corregir_identidad_usuario.sql:142`) de coordinadores de otros programas, y las asignaturas "propias" de HU008 del estudiante.
Corrección:
- Paso 1 sobre estudiantes con matrícula activa (`A`), o justificar en el contrato por qué "activo" incluye matrículas finalizadas.
- Paso 2: no crea nada; registra el tipo `SIN_INTERSECCION`.
- El script de resolución ofrece (a) asociar la asignatura al plan del programa del estudiante (flujo 4.3.1) o (b) crear el vínculo.
- T-B2-11 admite como excepciones `AMBIGUO` y `SIN_INTERSECCION`.
- El riesgo 9 documenta también la consecuencia de R7 en matrículas nuevas (corrección de identidad y oferta "propias").

**O-B5. La migración pierde datos si falla la verificación y no es idempotente tal como se redactó.**
Corrección:
- Mover las comprobaciones del paso 11 (asignatura sin vínculo, R7 fuera del reporte) **antes** del paso 10, en la misma transacción que el `DROP CONSTRAINT`/`DROP COLUMN` y en el último lote; si fallan, `THROW` sin borrar.
- Toda sentencia que nombre `Asignatura.semestrePlanEstudio` (precheck, backfill, `down` `UPDATE`/`ALTER COLUMN`) va en `sp_executesql` protegida por `COL_LENGTH`, o en un lote propio después de `GO`.
- En el `down`, `52902` cuenta todos los vínculos (activos o no) y restaura desde el único existente.
- T-B2-12 incluye "segundo `up` sobre la BD ya migrada" y "fallo forzado de la verificación → la columna sigue existiendo".

**O-B6. Colisiones de nombres de archivo con A y B.**
Corrección:
- Todos los artefactos de B2 usan el prefijo `culm001_b2nm`: `NN_culm001_b2nm_asignatura_plan_up/down.sql`, `schema/security/rol_asistencias_runtime_culm001_b2nm.sql`, `test/test_culm001_b2nm_*.sql|ps1`, `test/fixtures/b2nm_vincular_asignatura_plan.sql`, `zz_reporte_b2nm_estudiante_programa`, `b2nm_resolver_estudiante_programa_ambiguo.sql`.
- Las semillas (`33`/`34`/`35` en el borrador) toman, como las migraciones, el siguiente número libre al empezar el RED (hoy ≥ 37), con el mismo control previo que §2.8.1 ya exige para los códigos de mensaje.

**O-B7. El cambio WORM está incompleto y abre un código de respuesta innecesario.**
Corrección:
- Para un grupo fuera de ámbito se usa **403** (`SEC_002`), coherente con `BACKEND_GOLDEN_PATH_CONTRACT.md` l.27; no se agrega `404` a la OpenAPI.
- §3.4 incluye `BACKEND_GOLDEN_PATH_CONTRACT.md` filas 3 y 4 ("COORDINADOR: solo estudiantes con `EstudiantePrograma` en sus programas") en Infra (`docs/contracts/openapi/`) y Backend (`docs/contracts/`), con sus `.sha256`.
- §3.7 nombra `OpenApiGoldenPathConformanceTest`, `OpenApiEstudiantesDirectoryConformanceTest`, `OpenApiGoldenPathValidationTest`, `RbacSecurityFilterChainTest`, `SecurityPepEnforcementFilterTest` y `verify-contracts.ps1`.

### No bloqueantes (se corrigen antes de congelar)

**O-N1. Lista de pruebas existentes que cambian.**
Además de las 31, cambian:
- `test_contract_closure.sql` (las tres listas de excepción de resultset, l.247-262, para los SP de consulta nuevos);
- `test_consultas_transversales_hu112_hu157.sql` (forma del resultset, l.41);
- `test_uv_resumen_asistencia_estudiante_grupo.sql` l.184 (`uv_cumplimiento_sesion_grupo.idPrograma`);
- `test_consultas_coordinador_programa.sql`, `test_consultas_decano_facultad.sql`, `test_usp_consultar_grupos_paginado.sql`, `test_usp_consultar_sesiones_y_asistencias_paginado.sql`, `test_consolidado_auditoria_catalogos.sql` (`INSERT … EXEC` de resultsets que cambian);
- `test_uv_estudiante_programa_no_duplicates.sql` (precondición de 3 filas en `uv_estudiante`);
- `test_cruce_horario_docente.sql` l.15-16 y `test_usp_cambiar_estado_docente_programa.sql` l.89-90 (consultas por `a.idSemestrePlanEstudio`, no solo el arrange);
- RI-04/T-07 de A.

Cada una necesita su justificación de cambio formal, y hay que borrar la frase "ninguna aserción".

**O-N2. Pruebas RED que faltan:** las de §6 (S2/`ASI_006`, R8 en horarios y precarga, R10 del administrador, `usp_consultar_programas_grupo`, `totalRegistros` con asignatura compartida, T-B2-15, despliegue limpio y las cuatro specs de frontend).

**O-N3.** `deploy_schema.ps1` despliega `functions/` antes que `views/` (l.78-80, `sqlcmd -b`). Las TVF inline `ufn_programas_grupo` y `ufn_estudiantes_grupo_visibles` (y `ufn_programas_coordinador` si usa `uv_*`) referencian vistas, y una TVF inline no admite resolución diferida, así que la BD limpia falla. Corrección: escribirlas sobre tablas base, o desplegarlas en un paso posterior a las vistas (`schema/functions-post-views/` o dentro del bucle multipaso), con la prueba de `db-deploy` limpio.

**O-N4.** "Si hay varios, se prioriza `OBL`" en la oferta es un código quemado. Corrección: columna `orden INT` en `CaracterAsignaturaPlan` (semilla `OBL` = 1, `OPT` = 2) y `ORDER BY orden`.

**O-N5.** `uv_docente` expone `idPlanEstudio`/`inpPlanEstudio` (y `UvDocenteEntity`). Hay que fijar su valor con la misma regla determinista de `uv_estudiante`, o retirarlos y listar sus consumidores.

**O-N6.** `uv_auth_asistencia` filtra solo por grupo. Declarar que no es fuente de ámbito del coordinador (hoy no tiene consumidores) o filtrarla con `ufn_estudiantes_grupo_visibles`.

**O-N7.** Con `EXISTS` en `usp_validar_gestion_grupo_coordinador_o_titular_interno`, cualquier coordinador de un programa del grupo compartido puede cambiar los horarios y precargar sesiones del grupo. El contrato debe decir si es intencional (y probarlo) o exigir titular, o un coordinador de todos los programas del grupo.

**O-N8.** Declarar en §5.2 que B2 parte de la versión de A de `usp_consultar_oferta_grupos_estudiante` (21 columnas) y que elimina la regla ESP en **las dos** ramas de A (inserción y reactivación) de `usp_registrar_estudiante_en_grupo_interno`.

**O-N9.** El `down` restaura la versión B.2 (no la de `develop`) de `uv_resumen_asistencia_estudiante_grupo`, `uv_cumplimiento_sesion_grupo` y de los consumidores que B modificó.

**O-N10.** Documentar (en §6.3 y como TD) que un grupo creado para un periodo cuyo `fechaFin` es anterior a la fecha del vínculo queda sin programa (invisible para coordinador y decano). Agregar la regla de que `PlanEstudio.estado = 0` no saca a un grupo de `uv_grupo_programa` (historia).

---

VEREDICTO: 17 objeciones (bloqueantes: 7)

1. **O-B1:** especificar en B2 los SP con ejecutor y ámbito para `GET /api/v1/estudiantes[/{id}]`, `GET /grupos/{id}/estudiantes` y `GET /grupos/{id}/asistencias` (+ legacy). Reemplazar los tres HQL. A no los cubre.
2. **O-B2:** agregar `usp_consultar_tendencia_ausentismo`, las líneas `r./c.idPrograma` de `kpis_institucion`, `comparativa_facultades`, `kpis_decano` y `bitácora`, y los consumidores nuevos de B. Agregar T-B2-15 (`sp_refreshsqlmodule`).
3. **O-B3:** `uv_estudiante` con `tieneVinculoPrograma`; solo las ramas coordinador y decano lo exigen. Corregir la resolución de institución de `usp_registrar_estudiante_en_programa_interno`.
4. **O-B4:** el paso 2 del backfill solo reporta (`SIN_INTERSECCION`); el paso 1 se limita a "activo", según DEC-020.
5. **O-B5:** verificación antes del `DROP` y en la misma transacción. Referencias a la columna en SQL dinámico o en lote aparte. Precisar `52902`.
6. **O-B6:** prefijo `culm001_b2nm` en todos los archivos; semillas con el siguiente número libre (A usa 33, B usa 34-36, y `rol_asistencias_runtime_culm001_b2.sql` ya es de B).
7. **O-B7:** 403 en lugar de 404. Actualizar `BACKEND_GOLDEN_PATH_CONTRACT.md` (ambas copias y `.sha256`) y nombrar las pruebas OpenAPI y de seguridad afectadas.
