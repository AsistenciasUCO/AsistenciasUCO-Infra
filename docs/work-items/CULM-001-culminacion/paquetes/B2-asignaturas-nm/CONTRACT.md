# CULM-001 · Paquete B2 — CONTRACT: asignaturas en varios planes/programas y ámbito por relación en grupos mixtos

> **Estado:** versión 2 (corrige `REVIEW-1.md`: 17 objeciones, 7 bloqueantes). Se congela con su `.sha256` cuando la revisión cierre las objeciones.
> **Fecha:** 2026-11-07. **Fuentes:** `docs/PROMPT_FABLE_CULMINACION.md` §3.8–§3.9 (líneas 91-100); `DECISIONES.md` DEC-019, DEC-020, DEC-021 (S1–S4 aceptados) y DEC-022 (fixture de segundo ámbito en A); `RESEARCH-ASIGNATURA-PLAN.md`; `FINDINGS-{coordinador,docente,decano}.md`; CONTRACT de A (incluida su sección A.2) y de B; `AGENTS.md` §3.3 y §4.
> **Rutas:** relativas a cada worktree `C:\Proyectos\GestionAsistencia-CULM001\<repo>`. DB = `GestioAsistenciaDB/`, BE = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, FE = `GestioAsistenciaFrontend/src/app/`.
> **Base:** `integracion/CULM-001` **después** de mezclar A y B (B.1 y B.2). Todo objeto que A o B modifiquen se edita sobre su versión (§5.2).
> **Prefijo de artefactos:** `culm001_b2nm` (migración `16_culm001_b2nm_*`, pruebas, permisos, fixture, reporte). El prefijo `culm001_b2` es del subpaquete B.2 de B.
> **Alcance del GREEN:** el "alcance mínimo imprescindible" de REVIEW-1 §8. El resto está en §7 como diferible (post 2026-11-13).

---

## 1. Alcance, decisiones aplicadas y HUs

### 1.1 Alcance

| Incluido (GREEN) | Excluido |
| :--- | :--- |
| Relación N:M `Asignatura` ↔ `SemestrePlanEstudio` con carácter por catálogo (DEC-019); `Asignatura.codigo` único | Sedes, bloques o aulas (§3.9) |
| Crear asignatura (catálogo + primer vínculo), asociar una asignatura existente, cambiar semestre o carácter de un vínculo, desvincular (reemplaza el 501 de F-COO-005) | Prerrequisitos (HU025 descartada) |
| Ámbito por `EstudiantePrograma` en grupos mixtos para coordinador y decano (DEC-020), extendiendo los tres SP de ámbito de A (A.2); eliminación de los cuatro `TOP 1` de programa | Flujo de cancelación por inasistencia (paquete C). B2 entrega `ufn_programas_grupo` y R6, que C usa para "coordinador del programa del estudiante" |
| Backfill de vínculos (solo estudiantes activos sin programa) y reporte; matrícula manual y por QR que exigen o crean el vínculo; S3 en su forma mínima | Horas y sesiones canceladas (B). B2 solo cambia el join de programa de las vistas que B ya modificó |
| Malla, oferta (HU008), creación de asignaturas y grupos, KPIs por programa, y las consultas del coordinador, del decano y de la institución que pasan por la cadena asignatura → programa | `usp_ejecutar_cierre_masivo_periodo`: no une a plan ni a programa; su umbral fijo de 3 faltas es de C |
| | Todo lo listado en §7 (diferible) |

### 1.2 Decisiones aplicadas

| Regla | Detalle contractual |
| :--- | :--- |
| R1 (DEC-019) | Tabla puente `AsignaturaPlanEstudio (asignatura, semestrePlanEstudio, caracter, estaActivo)` única por `(asignatura, semestrePlanEstudio)`. El carácter es FK a `CaracterAsignaturaPlan` (`OBL`, `OPT`, con columna `orden`). Los SP reciben `@codigoCaracter` o leen `ASIGNATURA_PLAN/CARACTER_DEFECTO`; ningún literal de carácter en T-SQL. |
| R2 (DEC-019) | `Asignatura.codigo` es UNIQUE global (`UX_Asignatura_codigo`). La pertenencia a planes vive solo en la puente. |
| R3 (DEC-019) | `usp_crear_asignatura` inserta el catálogo y el primer vínculo en una transacción; `usp_asociar_asignatura_plan` crea o reactiva un vínculo. Un código existente devuelve `ASI_002`; la UI deja siempre visible "Asociar asignatura existente" (no interpreta el mensaje). |
| R4 (DEC-019) | `Asignatura.semestrePlanEstudio` y su FK se eliminan al final de la misma migración, después de la verificación y en la misma transacción (§2.3). El `down` la restaura cuando cada asignatura tiene un único vínculo. |
| R5 (DEC-019) | `uv_grupo_programa` es 1:N. Todo consumidor que cuente o pagine grupos, sesiones o estudiantes usa `EXISTS` o `DISTINCT` sobre la clave de negocio, o declara su nuevo grano. |
| R6 (DEC-020) | Para **coordinador y decano**, un estudiante de un grupo es visible si existe `EstudiantePrograma(estudiante, p)` con `p` ∈ (programas del grupo ∩ programas del ámbito del ejecutor). |
| R7 (DEC-020) | Toda matrícula **activa** tiene al menos un `EstudiantePrograma` en un programa de su grupo, salvo las filas `AMBIGUO` y `SIN_INTERSECCION` del reporte del backfill. La matrícula manual y por QR la garantizan hacia adelante. |
| R8 (DEC-020) | Se eliminan los `TOP 1` de programa de `usp_registrar_estudiante_en_grupo_interno.sql:122`, `usp_validar_gestion_grupo_coordinador_o_titular_interno.sql:101`, `usp_validar_docente_vinculo_activo_programa_interno.sql:33` y `usp_resolver_programa_coordinador_interno.sql:51`. |
| R9 (DEC-020) | KPIs por programa: solo estudiantes con `EstudiantePrograma` en ese programa. Facultad e institución: `COUNT(DISTINCT)` por estudiante, grupo o sesión. |
| R10 | El administrador (en su institución), el docente titular y el propio estudiante **no** dependen de `EstudiantePrograma`: ven a todos los estudiantes de sus grupos, incluidos los `AMBIGUO` y `SIN_INTERSECCION`. |

**Supuestos aceptados por DEC-021:**
- **S1.** Vigencia del vínculo con `fechaVinculacionUtc` / `fechaDesvinculacionUtc` (§2.1).
- **S2.** Los datos de catálogo de una asignatura compartida solo los cambia quien coordina **todos** sus programas con vínculo activo (`ASI_006`).
- **S3 (forma mínima, decisión del orquestador).** `POST /api/v1/grupos/{grupoId}/matricula-qr` recibe `programaId` opcional. Es **obligatorio** solo si el grupo pertenece a más de un programa (`EST_005`), debe ser un programa del grupo (`EST_006`) y se guarda en `TokenMatriculaGrupo.programaPorDefecto`. La matrícula por QR de un estudiante sin vínculo con los programas del grupo usa ese programa. `MQR_008` queda solo como defensa para ventanas abiertas antes de la migración.
- **S4.** El coordinador de varios programas filtra con `programaId`. Sin ese parámetro, las listas usan todos sus programas y los KPIs devuelven `COO_002`.

DEC-021 menciona un 404 de ámbito en `/grupos/{id}/estudiantes|asistencias`. Por decisión del orquestador sobre O-B7 se usa **403** (§3.4).

### 1.3 HUs y hallazgos

| HU / hallazgo | Qué cambia en el GREEN |
| :--- | :--- |
| HU075, HU084, HU108 (malla) | Vínculos con semestre y carácter. El coordinador asocia, edita el vínculo y desvincula; el decano consulta. Plan inexistente o ajeno → 404 (F-COO-008, F-DEC-015) |
| HU008 (oferta) | "Propias" = grupos con vínculo activo a un plan de un programa del estudiante; carácter en su programa; sin duplicados |
| HU076B, HU085 | Código único; carácter obligatorio; `ASI_002` |
| HU087 | Docente con vínculo activo a **algún** programa de la asignatura; la firma congelada de `usp_crear_grupo` no cambia |
| HU065, HU066, HU070, HU102, HU106 | R9; cierra F-COO-006 (13 vs 12) |
| HU060, HU064, HU068, HU069, HU071, HU072 | R6 en grupos, sesiones, asistencias, ficha, bitácora y alertas; grupo fuera de ámbito → 403 (F-COO-003, sobre A) |
| HU144 | `GET /decano/grupos` por SP con ámbito (F-DEC-002); el HQL actual se rompe al retirar columnas |
| F-COO-001, F-COO-002, F-DOC-013, F-COO-003 | Los resuelven los SP de A.2; B2 los extiende a N:M (§1.4) |
| F-COO-005 | `DELETE .../planes-estudio/{planId}/asignaturas/{asigId}` deja de responder 501 (A lo oculta hasta B2, DEC-022 punto 8) |

### 1.4 Reparto con A (A.2): B2 reutiliza y extiende, no redefine

El paquete A crea estos SP con el ámbito **dentro** del SP y la regla de DEC-020 en el modelo 1:1:

| SP de A.2 | Endpoint | Regla en A | Extensión en B2 (mismo objeto, misma firma + parámetros opcionales) |
| :--- | :--- | :--- | :--- |
| `usp_consultar_directorio_estudiantes_paginado` | `GET /api/v1/estudiantes`, `GET /api/v1/estudiantes/{id}` | ADMINISTRADOR → institución; COORDINADOR → `EstudiantePrograma` en su programa; DOCENTE → titularidad de grupo | Rama coordinador sobre `ufn_programas_coordinador` (varios programas, sin `TOP 1`). `@idPrograma` fuera de su coordinación → `COO_003` (403). Los contextos académicos del detalle salen de `uv_estudiante` con `tieneVinculoPrograma = 1` e intersección de programas (R6). Ramas administrador y docente sin cambio (R10) |
| `usp_consultar_estudiantes_grupo_ambito_paginado` | `GET /api/v1/grupos/{grupoId}/estudiantes` | Grupo fuera de ámbito → 403; el coordinador ve a los estudiantes con `EstudiantePrograma` en su programa | Ámbito del grupo por `EXISTS (ufn_programas_grupo ∩ programas del ejecutor)`; filas por `ufn_estudiantes_grupo_visibles` (R6/R10) |
| `usp_consultar_asistencias_grupo_ambito_paginado` | `GET /api/v1/grupos/{grupoId}/asistencias` y el legacy `POST /api/v1/asistencias/consultas/grupo` (`AsistenciaQueryController.java:61`) | idem | idem. Si A no conecta el legacy, B2 lo apunta al mismo SP |

El resultset de los tres SP es el de A, que respeta los DTO congelados del golden path; B2 no agrega columnas. Si al empezar el RED la firma de A difiere, B2 extiende la que esté mezclada.

---

## 2. Base de datos

### 2.1 DDL nuevo

`DB/schema/tables/CaracterAsignaturaPlan.sql`
```sql
IF OBJECT_ID('dbo.CaracterAsignaturaPlan', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CaracterAsignaturaPlan (
        id      UNIQUEIDENTIFIER NOT NULL,
        codigo  NVARCHAR(3)      NOT NULL,
        nombre  NVARCHAR(50)     NOT NULL,
        orden   INT              NOT NULL,
        estado  BIT              NOT NULL CONSTRAINT DF_CaracterAsignaturaPlan_estado DEFAULT (1),
        CONSTRAINT PK_CaracterAsignaturaPlan PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_CaracterAsignaturaPlan_codigo UNIQUE (codigo),
        CONSTRAINT UQ_CaracterAsignaturaPlan_nombre UNIQUE (nombre),
        CONSTRAINT UQ_CaracterAsignaturaPlan_orden UNIQUE (orden)
    );
END
```
Semilla `DB/schema/seed/37_caracter_asignatura_plan.sql` (MERGE con GUIDs fijos, patrón `16_tipo_vinculacion.sql`): `OBL` Obligatoria con `orden 1`, `OPT` Optativa con `orden 2`. Es un catálogo de solo consulta. Cuando hay que elegir un carácter entre varios se ordena por `orden` (O-N4).

`DB/schema/tables/AsignaturaPlanEstudio.sql`
```sql
IF OBJECT_ID('dbo.AsignaturaPlanEstudio', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AsignaturaPlanEstudio (
        id                      UNIQUEIDENTIFIER NOT NULL,
        asignatura              UNIQUEIDENTIFIER NOT NULL,
        semestrePlanEstudio     UNIQUEIDENTIFIER NOT NULL,
        caracter                UNIQUEIDENTIFIER NOT NULL,
        estaActivo              BIT              NOT NULL CONSTRAINT DF_AsignaturaPlanEstudio_estaActivo DEFAULT (1),
        fechaVinculacionUtc     DATETIME2(3)     NOT NULL CONSTRAINT DF_AsignaturaPlanEstudio_fechaVinculacionUtc DEFAULT (SYSUTCDATETIME()),
        fechaDesvinculacionUtc  DATETIME2(3)     NULL,
        CONSTRAINT PK_AsignaturaPlanEstudio PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_AsignaturaPlanEstudio_asignatura_semestre UNIQUE (asignatura, semestrePlanEstudio),
        CONSTRAINT CK_AsignaturaPlanEstudio_vigencia CHECK (
               (estaActivo = 1 AND fechaDesvinculacionUtc IS NULL)
            OR (estaActivo = 0 AND fechaDesvinculacionUtc IS NOT NULL AND fechaDesvinculacionUtc >= fechaVinculacionUtc))
    );
    CREATE INDEX IX_AsignaturaPlanEstudio_semestre
        ON dbo.AsignaturaPlanEstudio (semestrePlanEstudio) INCLUDE (asignatura, caracter, estaActivo);
END
```
FKs en `zz_foreign_keys.sql`: `FK_AsignaturaPlanEstudio_Asignatura`, `_SemestrePlanEstudio` y `_CaracterAsignaturaPlan`. Se retira el bloque 18 (`FK_Asignatura_SemestrePlanEstudio`, l.140-144).

**Vigencia (S1).** Un vínculo aplica a un grupo del periodo `pa` si `fechaLocal(fechaVinculacionUtc) <= pa.fechaFin` y además `fechaDesvinculacionUtc IS NULL` o `fechaLocal(fechaDesvinculacionUtc) >= pa.fechaInicio`. La zona sale de `CatalogoParametro` (`TIEMPO/ZONA_HORARIA_SQLSERVER`), con el mismo cálculo que `uv_grupo`. `PlanEstudio.estado = 0` **no** saca un grupo de `uv_grupo_programa`, para conservar la historia (O-N10). Reactivar un vínculo reutiliza la fila y conserva `fechaVinculacionUtc` (§6.3).

**Unicidad por plan.** Una asignatura no puede tener dos vínculos activos en semestres distintos del mismo plan. Lo valida `usp_internal_asociar_asignatura_plan` con `WITH (UPDLOCK, HOLDLOCK)` (`ASI_003`).

### 2.2 Cambios en tablas, semillas y fixtures

| Objeto | Cambio |
| :--- | :--- |
| `tables/Asignatura.sql` | Sin `semestrePlanEstudio`; índice único `UX_Asignatura_codigo` |
| `tables/EstudiantePrograma.sql` | Índice único `UX_EstudiantePrograma_estudiante_programa (estudiante, programa)` |
| `tables/TokenMatriculaGrupo.sql` | `programaPorDefecto UNIQUEIDENTIFIER NULL` + FK a `Programa` (S3 mínimo) |
| `migrations/01_gestionasistenciadb.sql` | No se edita |
| `seed/13_academico_asignaturas.sql` | MERGE de `Asignatura` sin `semestrePlanEstudio` + MERGE del vínculo `ARQ-402` (`E2F3A4B5-...01`) ↔ SPE `D2E3F4A5-...01`, con el carácter `OBL` resuelto por código contra la tabla |
| `seed/14_grupos_sesiones.sql` | `EstudiantePrograma` para cada estudiante matriculado (sin la regla ESP) |
| Fixture de segundo ámbito de A (DEC-022 punto 9) | B2 **no** crea una semilla de segundo programa. Agrega `test/fixtures/culm001_b2nm_asignatura_compartida.sql`, que sobre el fixture de A crea una optativa `OPT` vinculada a los planes de los dos programas, un grupo G de esa optativa con un estudiante de cada programa y un estudiante sin vínculo (para R10) |

Las semillas nuevas usan el siguiente número libre después de A (`33_*`) y B (`34_*`–`36_*`): `37_caracter_asignatura_plan.sql`, `38_mensajes_asignatura_plan.sql` y `39_parametro_asignatura_plan.sql`. Antes del RED se repite el control de números libres.

### 2.3 Migración `16_culm001_b2nm_asignatura_plan_up.sql` / `_down.sql`

Técnica obligatoria (O-B5):
- Toda sentencia que nombra `Asignatura.semestrePlanEstudio` (precheck, backfill, `UPDATE` y `ALTER COLUMN` del `down`) va en `EXEC sys.sp_executesql` dentro de `IF COL_LENGTH('dbo.Asignatura','semestrePlanEstudio') IS NOT NULL` (o `IS NULL` en el `down`). Así el lote compila con la columna presente o ausente.
- `SET XACT_ABORT ON`. Cada bloque de datos va en `BEGIN TRY / BEGIN TRANSACTION ... COMMIT`, con `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; THROW;` en el `CATCH`.
- Lotes separados con `GO` para el DDL de objetos programables (`CREATE OR ALTER`).

**`up`:**
1. Precheck (patrón `06_catalogos_area_estado_unicidad_up.sql:8-12`, en SQL dinámico): `THROW 52900` si hay códigos duplicados por `UPPER(TRIM(codigo))` o asignaturas cuyo `semestrePlanEstudio` no existe.
2. Tablas `CaracterAsignaturaPlan` (con sus filas) y `AsignaturaPlanEstudio`, FKs e índice; parámetro `ASIGNATURA_PLAN/CARACTER_DEFECTO = OBL`.
3. Backfill 1:1 de la puente (SQL dinámico, `WHERE NOT EXISTS`): un vínculo por asignatura con el carácter por defecto, `estaActivo = 1` y `fechaVinculacionUtc = COALESCE(MIN(pa.fechaInicio) de los periodos de sus grupos, SYSUTCDATETIME())`.
4. `UX_Asignatura_codigo`. Deduplicación de `EstudiantePrograma` (conserva el menor `id`; las filas borradas quedan en el reporte como `DEDUPLICADO`) y `UX_EstudiantePrograma_estudiante_programa`. Columna `TokenMatriculaGrupo.programaPorDefecto`.
5. `CREATE OR ALTER` de funciones, vistas y SP de §2.5–§2.7, con el mismo texto que `schema/`.
6. Backfill de `EstudiantePrograma` (§2.4).
7. **Último lote, una sola transacción:**
   - (a) Verificación: `THROW 52901` si alguna asignatura no tiene vínculo, o si hay matrículas activas que violan R7 sin fila `AMBIGUO`/`SIN_INTERSECCION` en el reporte.
   - (b) Solo si pasa la verificación: `DROP CONSTRAINT FK_Asignatura_SemestrePlanEstudio` y `DROP COLUMN semestrePlanEstudio` (SQL dinámico con guardas). Si (a) falla, la columna queda intacta.
8. Mensajes (§2.8.1) y permisos (§2.8.2), idempotentes.

Un segundo `up` sobre la BD migrada no cambia nada: los pasos que nombran la columna se saltan por `COL_LENGTH`, y los MERGE e índices son condicionales.

**`down`:**
1. `THROW 52902`, sin cambios, si alguna asignatura tiene **0 o más de 1 vínculo, contando activos e inactivos**. Una asignatura desvinculada de un plan y asociada a otro tiene 2 filas, así que no es 1:1. El mensaje técnico lista las asignaturas.
2. `ADD semestrePlanEstudio NULL`. En otro lote: `UPDATE` desde el único vínculo, `ALTER COLUMN ... NOT NULL` y FK (SQL dinámico).
3. Restaura el texto de vistas, funciones y SP **en su versión A + B mezclada**, copiada literal en el `down` (O-N9). Eso incluye las versiones B.2 de `uv_resumen_asistencia_estudiante_grupo`, `uv_cumplimiento_sesion_grupo`, `usp_consultar_resumen_asistencia_grupo_docente_paginado` y `usp_consultar_resumen_asistencia_estudiante`, y la versión A.2 de los tres SP de ámbito. Elimina los objetos nuevos.
4. Borra los `EstudiantePrograma` con tipo `CREADO` en el reporte; quita los dos índices únicos, `programaPorDefecto`, la puente, el catálogo, el parámetro y los mensajes de B2.
5. Conserva `zz_reporte_culm001_b2nm_estudiante_programa` (solo lectura).

### 2.4 Backfill de `EstudiantePrograma` y reporte

```sql
CREATE TABLE dbo.zz_reporte_culm001_b2nm_estudiante_programa (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_zz_reporte_culm001_b2nm PRIMARY KEY,
    estudiante  UNIQUEIDENTIFIER NOT NULL,
    grupo       UNIQUEIDENTIFIER NULL,
    programa    UNIQUEIDENTIFIER NULL,
    tipo        NVARCHAR(20)     NOT NULL,   -- CREADO | AMBIGUO | SIN_INTERSECCION | DEDUPLICADO | RESUELTO
    detalle     NVARCHAR(400)    NULL,
    fechaUtc    DATETIME2(3)     NOT NULL CONSTRAINT DF_zz_reporte_culm001_b2nm_fecha DEFAULT (SYSUTCDATETIME())
);
```
Sin FKs; `DENY INSERT, UPDATE, DELETE` al runtime (patrón `zz_archivo_*` de DEC-010).

Algoritmo, literal a DEC-020 (O-B4):
1. **Solo estudiantes activos sin ningún `EstudiantePrograma`.** "Activo" significa con al menos una matrícula en estado activo; el estado se resuelve contra `EstadoEstudianteGrupo`, sin literal.
   - Si sus matrículas activas caen en un único programa → se crea el vínculo (`CREADO`).
   - Si caen en dos o más → `AMBIGUO` (`detalle` = programas) y no se crea nada.
2. **Matrículas activas sin intersección** de estudiantes que ya tienen algún vínculo: **solo se reportan** como `SIN_INTERSECCION`; no se crea nada. Es el caso de F-COO-006 si el estudiante tiene otro programa, y el de las transversales depuradas por `hu008_depurar_estudiante_programa_transversales.sql`.
3. Estudiantes sin vínculo y sin matrículas activas (solo historia): no se crean ni se reportan. Su historia la ven el administrador y el docente (R10).
4. El `up` devuelve `SELECT tipo, COUNT(*)`. `DB/scripts/maintenance/culm001_b2nm_resolver_estudiante_programa.sql` resuelve cada fila con una de dos opciones explícitas y registra `RESUELTO`:
   - (a) asociar la asignatura del grupo al plan del programa del estudiante (llama a `usp_asociar_asignatura_plan`; flujo §4.3.1);
   - (b) crear el vínculo `EstudiantePrograma` con un programa del grupo.
5. `hu008_depurar_estudiante_programa_transversales.sql` se conserva, porque no contradice el backfill literal. Su cabecera se actualiza para decir que la matrícula nueva sigue R7.

Resultado esperado en la BD local (un programa): si el estudiante `b1a2c3d4-...-0023` de F-COO-006 no tiene ningún vínculo, sale como `CREADO`; si tiene otro, sale como `SIN_INTERSECCION` y se resuelve con el script. Después de la resolución, `totalEstudiantes` del KPI coincide con el directorio del coordinador.

### 2.5 Vistas

**Nuevas**

| Vista | Grano | Definición |
| :--- | :--- | :--- |
| `uv_caracter_asignatura_plan` | 1 por carácter | id, codigo, nombre, orden, estaActivo |
| `uv_asignatura_plan_estudio` | 1 por vínculo | idAsignaturaPlanEstudio, idAsignatura, codigoAsignatura, nombreAsignatura, credito, idArea, nombreArea, idComponente, codigoComponente, nombreComponente, estaActivaAsignatura, idSemestrePlanEstudio, idSemestre, numeroSemestre, codigoSemestre, idPlanEstudio, inpPlanEstudio, estaActivoPlan, idPrograma, nombrePrograma, idFacultad, idInstitucion, idCaracter, codigoCaracter, nombreCaracter, ordenCaracter, estaActivoVinculo, fechaVinculacionUtc, fechaDesvinculacionUtc, totalProgramasActivos |
| `uv_estudiante_grupo_programa` | 1 por (matrícula, programa del grupo con vínculo del estudiante) | `uv_estudiante_grupo eg JOIN uv_grupo_programa gp ON gp.idGrupo = eg.idGrupo JOIN EstudiantePrograma ep ON ep.estudiante = eg.idEstudiante AND ep.programa = gp.idPrograma` |
| `uv_resumen_asistencia_estudiante_programa_grupo` | 1 por (matrícula, programa) | Columnas de `uv_resumen_asistencia_estudiante_grupo` (versión B.2) + `idPrograma`, por `JOIN uv_estudiante_grupo_programa` |

**Modificadas**

| Vista | Cambio | Grano |
| :--- | :--- | :--- |
| `uv_asignatura` | Sin la cadena plan/programa; sin `idSemestrePlanEstudio`, `inp`, `nombrePrograma`, `codigoSemestre`; + `totalPlanesActivos` | 1 por asignatura |
| `uv_grupo_programa` | `uv_grupo` + `CROSS APPLY dbo.ufn_programas_grupo(g.id)` (S1). Columnas: idGrupo, idPrograma, idPeriodoAcademico, grupoEstaHablitado, **idPlanEstudio, inpPlanEstudio**. El plan es el del programa que contiene la asignatura con vínculo vigente; si hay varios: activo primero, mayor `inp`, menor `id` (regla documentada en la vista) | 1:N por (grupo, programa) |
| `uv_grupo` | Sin cambio de texto: solo lee `id` y `nombre` de `uv_asignatura` | 1 por grupo |
| `uv_estudiante_grupo` (**congelada**) | No se toca. Depende de `uv_grupo`, que sigue 1:1. B2NM-03 fija su cardinalidad y el manifiesto no cambia | 1 por matrícula |
| `uv_auth_grupo` | Ramas administrador, decano y coordinador por `EXISTS` sobre `uv_grupo_programa` + `Programa` + `Facultad`, en lugar del join de l.29-33 | 1 por grupo |
| `uv_auth_programa`, `uv_auth_facultad`, `uv_auth_institucion` | Ramas docente y estudiante por `uv_grupo_programa` dentro del `EXISTS` | sin cambio |
| `uv_docente` | Programa y plan desde `uv_grupo_programa`; `idPlanEstudio`/`inpPlanEstudio` con la misma regla (O-N5) | 1 por (docente, grupo, programa del grupo) |
| `uv_docente_programa` | Sin cambio de texto: su `COUNT(DISTINCT x.idGrupo)` (l.43) sigue siendo correcto con el nuevo grano de `uv_docente`. Entra en B2NM-03 | — |
| `uv_estudiante` | Se construye desde `uv_estudiante_grupo` + `uv_grupo_programa` y no exige vínculo. Nueva columna `tieneVinculoPrograma BIT = IIF(EXISTS EstudiantePrograma(estudiante, idPrograma), 1, 0)`. El plan sale de `uv_grupo_programa` (O-B3) | 1 por (estudiante, grupo, programa del grupo) |
| `uv_auth_estudiante` | Las ramas **coordinador** y **decano** exigen `e.tieneVinculoPrograma = 1`; las ramas administrador, docente titular y propio no (R10). Expone `tieneVinculoPrograma` | idem |
| `uv_estudiante_programa` | Desde `EstudiantePrograma` + `uv_estudiante_identidad`, no desde `DISTINCT uv_estudiante`; + `estaActivoUsuario` | 1 por vínculo |
| `uv_cumplimiento_sesion_grupo` (versión B.1/B.2) | Se quita `idPrograma`; `idPeriodoAcademico` sale de `uv_grupo`. Se conservan las columnas de B (`totalTomas`, `horasSesion`, exclusión de canceladas) | 1 por sesión |
| `uv_resumen_asistencia_estudiante_grupo` (versión B.2) | Se quita `idPrograma` y el join a `uv_grupo_programa`; `idPeriodoAcademico` sale de `uv_grupo`. Las columnas de horas de B quedan intactas | 1 por matrícula |
| `uv_auth_asistencia` | Sin cambio. Se declara, en un comentario de la vista y en este contrato, que **no** es fuente de ámbito del coordinador: filtra por grupo y hoy no tiene consumidores. Un consumidor nuevo debe usar `ufn_estudiantes_grupo_visibles` (O-N6) | — |
| `uv_semestre_plan_estudio`, `uv_plan_estudio`, `uv_auth_docente`, `uv_auth_sesion` | Sin cambio | — |

No se edita ningún archivo del manifiesto (`DB/scripts/freeze-manifest.ps1:27-37`).

### 2.6 Funciones nuevas (sobre tablas base, O-N3)

`deploy_schema.ps1` despliega `functions/` antes que `views/` (l.75-80), y una TVF inline no admite resolución diferida. Por eso las cuatro funciones leen **solo tablas base**: `Grupo`, `PeriodoAcademico`, `AsignaturaPlanEstudio`, `SemestrePlanEstudio`, `PlanEstudio`, `Programa`, `Facultad`, `Coordinador`, `Decano`, `Docente`, `Administrador`, `Estudiante`, `EstudianteGrupo`, `EstudiantePrograma` y `CatalogoParametro` (como ya hace `uv_grupo` con `CatalogoParametro`). Las vistas pueden usarlas porque se despliegan después. B2NM-16 prueba `db-deploy` en una BD limpia.

| Función | Firma (inline TVF) | Uso |
| :--- | :--- | :--- |
| `ufn_programas_grupo` | `(@idGrupo UNIQUEIDENTIFIER) RETURNS TABLE (idPrograma, idPlanEstudio, inpPlanEstudio)`, con la regla de vigencia S1 | `uv_grupo_programa`, matrícula, validaciones, C |
| `ufn_programas_coordinador` | `(@idUsuario UNIQUEIDENTIFIER) RETURNS TABLE (idPrograma)` | Reemplaza el `TOP 1` en listas y validaciones |
| `ufn_programas_ambito_ejecutor` | `(@idUsuario UNIQUEIDENTIFIER) RETURNS TABLE (idPrograma, rol)` | Coordinador → sus programas; decano → programas de su facultad |
| `ufn_estudiantes_grupo_visibles` | `(@idGrupo, @idUsuarioEjecutor) RETURNS TABLE (idEstudianteGrupo, idEstudiante)` | Titular del grupo y administrador de la institución → todas las matrículas (R10). Coordinador y decano → matrículas con `EstudiantePrograma` en (programas del grupo ∩ `ufn_programas_ambito_ejecutor`) (R6) |

### 2.7 Procedimientos almacenados

Reglas comunes:
- `SET NOCOUNT ON; SET XACT_ABORT ON;`; transacción explícita en las escrituras e `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;` en el `CATCH`.
- Parámetros evaluados con `IS NULL`; salida canónica `(idCorrelacion, mensajeUsuarioResultado, mensajeTecnicoResultado, estadoResultado)`.
- Consultas con `@numeroPagina`, `@tamanoPagina`, `OFFSET ... FETCH NEXT` y `COUNT(*) OVER() AS totalRegistros` sobre `uv_*`.
- RBAC con `usp_validar_permiso_rbac_usuario_interno` y titularidad dentro del SP.

#### 2.7.1 SP nuevos

| SP | Firma | Reglas | Mensajes |
| :--- | :--- | :--- | :--- |
| `usp_internal_asociar_asignatura_plan` | `(@idAsignatura, @idPlanEstudio, @semestreNumero INT, @codigoCaracter NVARCHAR(3), @idCorrelacion, @mensajeUsuarioResultado OUT, @mensajeTecnicoResultado OUT, @estadoResultado OUT)` | Interno (DENY al runtime). Resuelve el SPE por plan + número (`PLA_004`) y el carácter activo por código; NULL → `CARACTER_DEFECTO` (`ASI_007`). Con `UPDLOCK, HOLDLOCK`: vínculo activo en el mismo u otro semestre del plan → `ASI_003`; inactivo en el mismo semestre → lo reactiva; si no, inserta | `PLA_004`, `ASI_003`, `ASI_007`, `GEN_004` |
| `usp_asociar_asignatura_plan` | `(@idAsignatura, @idPlanEstudio, @semestreNumero INT, @codigoCaracter NVARCHAR(3) = NULL, @idCorrelacion, @idUsuarioEjecutor = NULL)` | RBAC COORDINADOR. El plan existe (`PLA_002`) y es de un programa suyo (`SEC_002` por `usp_validar_titularidad_jerarquica_interno`). La asignatura está activa y tiene algún vínculo en un programa de la misma institución (si no, `GEN_001`) | + `PLA_002`, `SEC_002`, `GEN_001` |
| `usp_desvincular_asignatura_plan` | `(@idAsignatura, @idPlanEstudio, @idCorrelacion, @idUsuarioEjecutor = NULL)` | Mismas validaciones. Sin vínculo activo → `ASI_004`. `ASI_005` si hay grupos de la asignatura en un periodo vigente o futuro cuyo único programa vigente es el de este plan, o matrículas activas cuyo único programa común con el grupo es este. Si pasa: `estaActivo = 0`, `fechaDesvinculacionUtc = SYSUTCDATETIME()` | `ASI_004`, `ASI_005`, `GEN_005` |
| `usp_consultar_asignaturas_plan_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @idPlanEstudio, @numeroPagina, @tamanoPagina, @numeroSemestre INT = NULL, @codigoCaracter NVARCHAR(3) = NULL, @busqueda NVARCHAR(100) = NULL)` | Malla del coordinador y del decano. Plan inexistente o fuera de ámbito → `PLA_002`. Coordinador → `ufn_programas_coordinador`; decano → su facultad. Lee `uv_asignatura_plan_estudio` (vínculos activos) con la columna `compartida = IIF(totalProgramasActivos > 1, 1, 0)` | `PLA_002` |
| `usp_consultar_asignaturas_asociables_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @idPlanEstudio, @numeroPagina, @tamanoPagina, @busqueda NVARCHAR(100) = NULL)` | Asignaturas activas de la institución del plan sin vínculo activo en él. 1 fila por asignatura con `planes` (`STRING_AGG` "Programa · Plan inp · S n") | `PLA_002`, `SEC_002` |
| `usp_consultar_asignaturas_coordinador_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @idPrograma = NULL, @busqueda = NULL, @estaActiva BIT = NULL)` | Reemplaza `AsignaturaJpaRepository.HQL_POR_PROGRAMA`, que se rompe al retirar columnas. 1 fila por (asignatura, plan de sus programas). `@idPrograma` ajeno → `COO_003` | `COO_003` |
| `usp_consultar_planes_estudio_programa_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @idPrograma = NULL, @estaActivo BIT = NULL)` | Reemplaza en `PlanEstudioJpaRepository` `HQL_POR_PROGRAMA`, `HQL_TOTAL_SEMESTRES` y el conteo y la suma de créditos (l.74-90), que pasan a calcularse por la puente (vínculos activos) | `COO_003` |
| `usp_consultar_grupos_facultad_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @idPeriodoAcademico = NULL, @idPrograma = NULL, @busqueda = NULL)` | Reemplaza `GrupoJpaRepository.HQL_GRUPOS_POR_FACULTAD` (l.85-91), que se rompe. Ámbito de facultad por `EXISTS uv_grupo_programa`; 1 fila por grupo con `programas`. `@idPrograma` fuera de su facultad → `KPI_003` | `KPI_003` |
| `usp_consultar_programas_grupo` | `(@idUsuarioEjecutor, @idCorrelacion, @idGrupo)` | Alimenta el selector de la matrícula manual y de la ventana QR. Lo pueden usar el titular y el coordinador o decano con ámbito; si no, `SEC_002` | `SEC_002` |
| `usp_internal_asegurar_estudiante_programa_grupo` | `(@idEstudiante, @idGrupo, @idProgramaElegido = NULL, @idCorrelacion, @idProgramaResultado OUT, @mensajeUsuarioResultado OUT, @mensajeTecnicoResultado OUT, @estadoResultado OUT)` | Interno, ver §2.7.3 | `EST_005`, `EST_006` |

#### 2.7.2 SP modificados: escritura y validación

| SP | Firma | Regla |
| :--- | :--- | :--- |
| `usp_crear_asignatura` | + `@codigoCaracter NVARCHAR(3) = NULL` | Unicidad contra la tabla con `UPDLOCK, HOLDLOCK` → `ASI_002` (antes `VAL_006` sobre la vista, l.141). Inserta el catálogo y llama a `usp_internal_asociar_asignatura_plan` en la misma transacción. Agrega `SET XACT_ABORT ON` y la transacción que hoy no tiene |
| `usp_actualizar_asignatura` | + `@codigoCaracter NVARCHAR(3) = NULL` | Actualiza el vínculo del plan (semestre, carácter). Los datos de catálogo solo con S2 (`ASI_006`). Código duplicado → `ASI_002` |
| `usp_toggle_estado_asignatura` | sin cambio | Estado global, con S2 (`ASI_006`) |
| `usp_validar_gestion_asignatura_coordinador_interno` | + `@idPlanEstudio = NULL`, + `@exigirTodosLosProgramas BIT = 0` | Sin el `SELECT` de un único programa (l.63-65). Basta coordinar "algún programa"; con el flag, "todos" (S2) |
| `usp_validar_gestion_grupo_coordinador_o_titular_interno` | sin cambio | Sin `TOP 1` (l.101). **Regla para grupos compartidos (O-N7):** el titular siempre puede; un coordinador solo si coordina **todos** los programas vigentes del grupo (`NOT EXISTS (ufn_programas_grupo EXCEPT ufn_programas_coordinador)`); si no, `SEC_002`. Es la opción de mínimo privilegio, coherente con S2. Afecta a `usp_guardar_horarios_grupo`, `usp_precargar_sesiones_grupo` y `usp_actualizar_grupo`, que lo invocan |
| `usp_validar_docente_vinculo_activo_programa_interno` | sin cambio | Sin `TOP 1` (l.33): `EXISTS` de un `DocentePrograma` activo en algún programa con vínculo activo de la asignatura. `DOC_009` si solo hay vínculos inactivos |
| `usp_crear_grupo` | **sin cambio** (`DB_BASELINE_CONTRACT.md:79`) | PASO 2B (l.117-119): el docente necesita vínculo activo en algún programa de la asignatura (`SEC_002`). Asignatura sin vínculo activo con un plan activo → `ASI_004` |
| `usp_resolver_programa_coordinador_interno` | + `@idProgramaSolicitado = NULL` | Sin `TOP 1` (l.51). Con `@idProgramaSolicitado`, lo valida (`COO_003`). Sin él: un programa → ese; varios → `COO_002`; ninguno → `KPI_001` (S4) |
| `usp_validar_estudiante_en_programa_interno` | sin cambio | `EXISTS` sobre `uv_estudiante_grupo_programa` (l.37) |
| `usp_quitar_semestre_plan_estudio` | sin cambio | `PLA_006` (l.145) contra los vínculos activos de la puente |
| `usp_registrar_estudiante_en_programa_interno` | sin cambio | La institución del estudiante (l.46-48) ya no se lee de `uv_estudiante`, que con el grano nuevo puede no tener fila de ese programa. Se resuelve por `EstudianteGrupo` → `Grupo` → `ufn_programas_grupo` → `Programa` → `Facultad` → `institucion` de cualquiera de sus matrículas. Si no tiene matrículas, se omite la comparación y se valida solo el programa (O-B3) |

#### 2.7.3 Matrícula manual y por QR

Las tres vías terminan en `usp_registrar_estudiante_en_grupo_interno`: la manual (`usp_registrar_estudiante_en_grupo:164`) y la QR autenticada y pública (`usp_internal_matricular_por_token:232`). B2 parte de la versión de A (inserción + reactivación `I → A`, DEC-009) y **elimina la regla ESP en las dos ramas**: inserción (hoy l.122-135) y reactivación (A §2.3 paso 7) (O-N8).

| SP | Firma | Regla |
| :--- | :--- | :--- |
| `usp_internal_asegurar_estudiante_programa_grupo` | (§2.7.1) | Con `UPDLOCK, HOLDLOCK` sobre los `EstudiantePrograma` del estudiante: (1) si ya tiene vínculo con algún programa del grupo, lo devuelve; (2) si no y el grupo tiene un único programa, crea el vínculo; (3) si no y el grupo tiene varios, exige `@idProgramaElegido` ∈ programas del grupo (`EST_005` si falta, `EST_006` si es ajeno) y crea el vínculo. La creación valida la institución contra el programa elegido (que por construcción es del grupo) e inserta directamente con el mismo control de duplicado; una violación del índice único por carrera se trata como "ya existe" |
| `usp_registrar_estudiante_en_grupo_interno` | + `@idProgramaElegido = NULL` | Llama al anterior en la misma transacción, antes de insertar o reactivar |
| `usp_registrar_estudiante_en_grupo` (manual) | + `@idPrograma = NULL` | Lo pasa como `@idProgramaElegido` |
| `usp_abrir_ventana_matricula_grupo` | + `@idPrograma = NULL` | S3 mínimo: si el grupo tiene más de un programa y llega NULL → `EST_005`; si no es del grupo → `EST_006`. Se guarda en `TokenMatriculaGrupo.programaPorDefecto` |
| `usp_internal_matricular_por_token` | sin cambio | Pasa el `programaPorDefecto` del token. Si aun así no se puede resolver (ventana abierta antes de la migración en un grupo que pasó a tener varios programas) → `MQR_008`, antes de crear usuario o matrícula |

#### 2.7.4 SP modificados: consultas (inventario completo de consumidores, O-B2)

Origen del inventario: `git grep` de `semestrePlanEstudio`, `uv_grupo_programa`, `uv_resumen_asistencia_estudiante_grupo`, `uv_cumplimiento_sesion_grupo`, `uv_asignatura`, `uv_estudiante` y `uv_docente` sobre la base `65a4998`, más los consumidores que introducen A y B (§2.7.5).

Fuentes de reemplazo:
- conteos por programa → `uv_resumen_asistencia_estudiante_programa_grupo`;
- programa de una sesión o de un grupo → `EXISTS uv_grupo_programa`;
- facultad o institución → `uv_grupo` + `EXISTS uv_grupo_programa` + `DISTINCT`.

| SP | Firma | Línea(s) y reemplazo |
| :--- | :--- | :--- |
| `usp_consultar_kpis_coordinador` | + `@idPrograma = NULL` | l.42 `r.idPrograma` → `uv_resumen_asistencia_estudiante_programa_grupo` con `idPrograma = @idPrograma`. l.52 `c.idPrograma` → `EXISTS (uv_grupo_programa gp WHERE gp.idGrupo = c.idGrupo AND gp.idPrograma = @idPrograma)`. `totalEstudiantes = COUNT(DISTINCT idEstudiante)` (F-COO-006) |
| `usp_consultar_alerta_temprana_programa` | + `@idPrograma = NULL` | l.71 → `uv_resumen_asistencia_estudiante_programa_grupo` |
| `usp_consultar_resumen_asistencia_estudiante_programa` | + `@idPrograma = NULL` | l.50 → idem |
| `usp_consultar_ficha_estudiante_programa` | + `@idPrograma = NULL` | Por `usp_validar_estudiante_en_programa_interno`; estudiante ajeno → `GEN_001` |
| `usp_consultar_bitacora_estudiante_programa` | + `@idPrograma = NULL` | l.79 `c.idPrograma = @idPrograma` → `EXISTS uv_grupo_programa` sobre `c.idGrupo` |
| `usp_consultar_resumen_docentes_programa`, `usp_consultar_historial_grupos_docente_programa` | + `@idPrograma = NULL` | Resolver sin `TOP 1`; el historial (l.94-97) por `EXISTS uv_grupo_programa` |
| `usp_consultar_tendencia_ausentismo` | sin cambio | l.56-57 `JOIN uv_programa p ON p.id = c.idPrograma` → `JOIN uv_grupo_programa gp ON gp.idGrupo = c.idGrupo JOIN uv_programa p ON p.id = gp.idPrograma`, con `COUNT(DISTINCT c.idSesion)` en los agregados de facultad e institución |
| `usp_consultar_kpis_decano` | sin cambio | l.47 y l.55 `r.idPrograma` → `uv_resumen_asistencia_estudiante_programa_grupo` filtrado a los programas de la facultad, con `COUNT(DISTINCT idEstudiante)` y `COUNT(DISTINCT idEstudianteGrupo)`. l.62 `gp.idPrograma` con `DISTINCT idGrupo` |
| `usp_consultar_kpis_institucion` | sin cambio | l.64 y 72 `r.idPrograma` → `uv_resumen_asistencia_estudiante_programa_grupo` + `DISTINCT`. l.78 `c.idPrograma` → `EXISTS uv_grupo_programa`. l.44 y 84 `gp.idPrograma` con `DISTINCT idGrupo`. l.37 (`ep.idPrograma`) sin cambio |
| `usp_consultar_comparativa_facultades` | sin cambio | l.34 y 52 `r.idPrograma` → `uv_resumen_asistencia_estudiante_programa_grupo` + `DISTINCT idEstudiante` por facultad |
| `usp_consultar_comparativa_programas_facultad` | sin cambio | l.31-54 `r.idPrograma` → `uv_resumen_asistencia_estudiante_programa_grupo`: cada programa cuenta sus estudiantes (R9) |
| `usp_consultar_consolidado_asistencia_grupos_paginado` | sin cambio | l.70-76 `gp.idPrograma` → grano declarado **(grupo, programa del ámbito)**: cada fila cuenta solo a los estudiantes con vínculo en ese programa. Para un coordinador de un programa sale 1 fila por grupo |
| `usp_consultar_aforo_grupos_facultad` | sin cambio | l.69 → 1 fila por grupo (`EXISTS`), con `programas` agregado |
| `usp_consultar_sesiones_facultad_paginado` | sin cambio | l.108 → 1 fila por sesión (`EXISTS`) |
| `usp_consultar_historial_estudiante` | sin cambio | l.93 y 115 → `uv_estudiante_grupo_programa`, sin repeticiones |
| `usp_resolver_periodo_kpi_interno`, `_facultad_interno`, `_institucion_interno` | sin cambio | l.46/44/44 → `EXISTS uv_grupo_programa` |
| `usp_cambiar_estado_programa_academico_interno` | sin cambio | l.57 (regla D4) → `EXISTS` |
| `usp_consultar_grupos_paginado` | + `@idPrograma = NULL` | Para el coordinador, `estudiantesActivos` cuenta solo a sus estudiantes (R6); capacidad y cupos son los del grupo |
| `usp_consultar_asistencias_sesion_paginado`, `usp_consultar_sesiones_grupo_paginado` | sin cambio | l.121-126: estudiantes por `ufn_estudiantes_grupo_visibles`, y conteos con ese mismo filtro |
| `usp_buscar_asignaturas_paginado` | sin cambio | l.76-86: 1 fila por asignatura con `planes` y `totalPlanes`, en lugar de `codigoSemestre`, `inpPlanEstudio` y `nombrePrograma` |
| `usp_consultar_programas_creditos_facultad_paginado` | sin cambio | l.64-70 → puente, vínculos activos |
| `usp_consultar_estructura_facultad` | sin cambio | No usa asignaturas (l.88-98); se verifica que compila (B2NM-15) |
| `usp_consultar_componentes_formacion` | sin cambio | l.77 sobre `uv_asignatura` 1:1; se verifica que compila |
| `usp_consultar_oferta_creacion_grupo_docente` | sin cambio | l.79 → `uv_asignatura_plan_estudio` (vínculos activos, programas del docente); 1 fila por asignatura con `programas` |
| `usp_consultar_oferta_grupos_estudiante` (versión A, 19 columnas) | sin cambio | l.93-111: "propias" por `EXISTS` sobre vínculos activos en planes de programas del estudiante; transversales BAS/INS como en A; 1 fila por grupo. Agrega al final `codigoCaracter` y `nombreCaracter` (vínculo en un programa del estudiante; si hay varios, el de menor `orden`). Quedan **21 columnas** posicionales: `17 codigoComponente`, `18 codigoCaracter`, `19 nombreCaracter`, `20 totalRegistros` |
| `usp_buscar_estudiantes_institucion_paginado` | sin cambio | l.64-85 por `uv_auth_estudiante`, rama administrador sin exigir vínculo (R10). `COUNT(DISTINCT id)` y `STRING_AGG(DISTINCT)` de programas ya presentes; prueba de cardinalidad |
| `usp_consultar_estudiantes_facultad_paginado`, `usp_consultar_estudiante_facultad_detalle` | sin cambio | La rama decano de `uv_auth_estudiante` exige vínculo (R6). El `STRING_AGG` sobre `DISTINCT` (l.107-108) ya evita repetidos |
| `usp_consultar_destinatarios_retiro_estudiante_grupo` | sin cambio | l.64-67 → coordinadores de los programas del **estudiante** que comparten el grupo |
| `usp_consultar_reenvio_verificacion_correo` | sin cambio | l.79-83 → `EstudiantePrograma` ∩ `ufn_programas_coordinador` |

Regla de cierre: antes del RED se repite el inventario con `git grep -nE "idPrograma|semestrePlanEstudio|idSemestrePlanEstudio"` sobre los consumidores de las vistas modificadas en la base A+B mezclada. Todo consumidor nuevo se agrega a esta tabla. B2NM-15 (`sp_refreshsqlmodule`) es la prueba que lo garantiza.

#### 2.7.5 Consumidores introducidos por A y B

| SP (paquete) | Cambio en B2 |
| :--- | :--- |
| `usp_consultar_directorio_estudiantes_paginado`, `usp_consultar_estudiantes_grupo_ambito_paginado`, `usp_consultar_asistencias_grupo_ambito_paginado` (A.2) | Extensión de §1.4 |
| `usp_consultar_resumen_asistencia_grupo_docente_paginado` (B.2, sábana del docente) | Deja de devolver `idPrograma` (la columna sale de la vista). Si su resultset es posicional, el mapeo backend de B (entidad o proyección de la sábana) se actualiza en el mismo commit, y la prueba de B que fija el resultset se actualiza por cambio formal |
| `usp_consultar_resumen_asistencia_estudiante` (B.2, vista del estudiante) | Igual |
| `usp_registrar_estudiante_en_grupo_interno` (A, rama de reactivación) | §2.7.3 |
| `usp_consultar_oferta_grupos_estudiante` (A, 19 columnas) | §2.7.4 |

### 2.8 Mensajes y permisos

#### 2.8.1 Mensajes

- Semilla `38_mensajes_asignatura_plan.sql`: MERGE en `CatalogoMensajeUsuario` y `CatalogoMensajeTecnico`, con el formato de `29_mensajes_asignatura.sql`.
- Las mismas claves en Azure App Configuration: `messages:user:<CODIGO>` (label `es`) y `messages:technical:<CODIGO>`. Con DEC-018, la demo local usa el proveedor `sqlserver`.
- `DB/scripts/generar-catalogo-mensajes.ps1 -Check` debe pasar.
- Antes del RED se verifica que los códigos siguen libres en la base A+B.

| Código | Clase / HTTP | Mensaje al usuario |
| :--- | :--- | :--- |
| `ASI_002` | CONFLICT / 409 | Ya existe una asignatura con ese código. Usa "Asociar asignatura existente" para agregarla a este plan. |
| `ASI_003` | CONFLICT / 409 | La asignatura ya está asociada a este plan de estudios. |
| `ASI_004` | RESOURCE_NOT_FOUND / 404 | La asignatura no está asociada a este plan de estudios. |
| `ASI_005` | CONFLICT / 409 | No puedes quitar la asignatura de este plan: tiene grupos o estudiantes del programa en el periodo vigente o en periodos futuros. |
| `ASI_006` | CONFLICT / 409 | La asignatura es compartida con programas que no coordinas; solo puedes cambiar su semestre y su carácter en tu plan. |
| `ASI_007` | VALIDATION / 400 | El carácter de la asignatura no es válido. |
| `EST_005` | VALIDATION / 400 | El grupo pertenece a varios programas: indica el programa. |
| `EST_006` | VALIDATION / 400 | El programa indicado no corresponde a los programas del grupo. |
| `MQR_008` | CONFLICT / 409 | No se pudo determinar tu programa en este grupo. Pide a tu docente que te matricule. |
| `COO_002` | VALIDATION / 400 | Coordinas varios programas: selecciona el programa que quieres consultar. |
| `COO_003` | FORBIDDEN / 403 | El programa indicado no pertenece a tu coordinación. |

El mapeo va en `BE/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java`, junto a l.77-78.

#### 2.8.2 Permisos

`DB/schema/security/rol_asistencias_runtime_culm001_b2nm.sql`, aditivo, con el patrón de `rol_asistencias_runtime_hu081_hu083.sql`; no edita `rol_asistencias_runtime.sql`.
- `THROW` si falta un SP requerido.
- `GRANT EXECUTE` a los SP públicos nuevos.
- `DENY EXECUTE` a `usp_internal_asociar_asignatura_plan` y `usp_internal_asegurar_estudiante_programa_grupo`.
- `DENY INSERT, UPDATE, DELETE` en `AsignaturaPlanEstudio`, `CaracterAsignaturaPlan`, `EstudiantePrograma` y `zz_reporte_culm001_b2nm_estudiante_programa`.
- `GRANT SELECT` a las TVF nuevas.

Las vistas nuevas reciben `SELECT` por el bucle de `rol_asistencias_runtime.sql:79`.

### 2.9 Pruebas T-SQL (RED)

Fixture: el de segundo ámbito de A + `test/fixtures/culm001_b2nm_asignatura_compartida.sql`. Contiene:
- programas A y B de la misma facultad, con coordinadores CA y CB, decano D y administrador AD;
- docente T con vínculo a ambos programas;
- optativa `OPT` en los planes de A y de B;
- grupo G de `OPT` con EA ∈ A, EB ∈ B y E0 sin vínculo;
- un grupo de una asignatura que solo está en A.

Cada prueba deja `@@TRANCOUNT = 0` y la BD como estaba. Archivos `test/test_culm001_b2nm_*.sql|ps1`.

| ID | Archivo | Caso (esperado) |
| :--- | :--- | :--- |
| B2NM-01 | `_asignatura_plan.sql` | Asociar `OPT` a 2 planes: 2 vínculos; `uv_asignatura` 1 fila; `uv_asignatura_plan_estudio` 2; `uv_grupo` 1 por grupo; `uv_grupo_programa` 2 para G |
| B2NM-02 | idem | Código existente `ASI_002`; doble asociación y otro semestre del mismo plan `ASI_003`; carácter inválido `ASI_007`; plan ajeno `SEC_002`; asignatura de otra institución `GEN_001` |
| B2NM-03 | idem | Cardinalidad con G en 2 programas: `uv_estudiante_grupo`, `uv_asistencia`, `uv_detalle_asistencia` y `uv_sesion` con `COUNT(*) = COUNT(DISTINCT id)`; `uv_cumplimiento_sesion_grupo` 1 por sesión; `uv_resumen_asistencia_estudiante_grupo` 1 por matrícula; `uv_docente_programa` sin grupos repetidos |
| B2NM-04 | idem | Desvincular: grupo vigente con único programa `ASI_005`; sin grupos → baja lógica; los grupos pasados siguen en `uv_grupo_programa` (S1) y los posteriores no; reasociar reactiva la misma fila; `PlanEstudio.estado = 0` no saca grupos |
| B2NM-05 | `_ambito_grupo_mixto.sql` | En los tres SP de A.2, asistencias de sesión, grupos, ficha, bitácora y alertas: CA ve EA y no EB; CB al revés; D ve EA y EB; T y AD ven EA, EB y E0; CA y D no ven E0 |
| B2NM-06 | idem | Ficha, bitácora y resumen de EB pedidos por CA → `GEN_001`; directorio con `@idPrograma = B` por CA → `COO_003`; grupo de otra facultad por CA → `SEC_002` |
| B2NM-07 | idem | KPIs: el coordinador de A cuenta EA y no EB; la comparativa por programa cuenta EA en A y EB en B; el decano cuenta G una vez; un estudiante con vínculo a A y B en G cuenta en ambos programas y una sola vez en facultad e institución; la tendencia de ausentismo no repite sesiones |
| B2NM-08 | idem | Coordinador con 2 programas: KPIs sin `@idPrograma` `COO_002`; con programa ajeno `COO_003`; las listas sin `@idPrograma` incluyen ambos |
| B2NM-09 | `_matricula.sql` | Manual: estudiante sin vínculo en un grupo de un programa → vínculo creado; en G sin programa `EST_005`; con programa ajeno `EST_006`; con vínculo previo no crea otro; la reactivación `I → A` aplica la misma regla y ya no mira ESP; estudiante nuevo sin ninguna matrícula previa → vínculo creado (O-B3) |
| B2NM-10 | idem | QR: abrir la ventana en G sin `@idPrograma` `EST_005`; con un programa del grupo, OK; la matrícula por QR de un estudiante sin vínculo usa `programaPorDefecto`; un token sin programa en un grupo multiprograma da `MQR_008` sin crear usuario ni matrícula; dos sesiones concurrentes no violan el índice único |
| B2NM-11 | idem | Invariante R7 sobre matrículas activas, con las excepciones `AMBIGUO` y `SIN_INTERSECCION` del reporte |
| B2NM-12 | `_migracion.ps1` | Sobre el esquema A+B: `up` (vínculos = asignaturas; columna eliminada; reporte con los `CREADO`, `AMBIGUO` y `SIN_INTERSECCION` esperados; el paso 2 no crea vínculos); **segundo `up`** sin cambios ni errores; verificación forzada a fallar → `THROW 52901` y **la columna sigue existiendo**; `down` restaura columna, valores y versiones A+B de vistas y SP; `down` con una asignatura con 2 vínculos (uno inactivo) → `THROW 52902` sin cambios; `up` otra vez; `@@TRANCOUNT = 0` en cada paso |
| B2NM-13 | `_oferta_y_grupos.sql` | HU008: G aparece una vez en "propias" de EA y de EB, con carácter; resultset de 21 columnas; oferta docente 1 fila por asignatura; `usp_crear_grupo` de T sobre `OPT` OK y con docente sin vínculo `SEC_002`; `usp_quitar_semestre_plan_estudio` con vínculo activo `PLA_006` |
| B2NM-14 | `_decano.sql` | `usp_consultar_grupos_facultad_paginado` 1 fila por G; `usp_consultar_asignaturas_plan_paginado` con plan inexistente o de otra facultad `PLA_002` |
| B2NM-15 | `_compilacion.sql` | Después del `up`, `EXEC sys.sp_refreshsqlmodule` sobre cada vista, SP y función de `dbo` (cursor sobre `sys.sql_modules`, sin los de esquema enlazado): **cero errores**. Se repite después del `down` |
| B2NM-16 | `_deploy_limpio.ps1` | `infra.ps1 db-deploy` sobre una BD vacía termina sin errores (orden funciones → vistas) y `db-test` pasa |
| B2NM-17 | `_asignatura_plan.sql` | S2: CA actualiza código, nombre o créditos, o cambia el estado global de `OPT` (compartida con B) → `ASI_006`; CA cambia semestre o carácter de su vínculo, OK; un coordinador de A y B puede cambiar el catálogo |
| B2NM-18 | `_ambito_grupo_mixto.sql` | O-N7: CA sobre G en `usp_guardar_horarios_grupo`, `usp_precargar_sesiones_grupo` y `usp_actualizar_grupo` → `SEC_002`; T (titular) OK; un coordinador de A y B OK |
| B2NM-19 | idem | R10 del administrador: `usp_buscar_estudiantes_institucion_paginado` y el directorio de A.2 consultados por AD incluyen a E0 y a un `AMBIGUO`, una vez cada uno; T ve a E0 en `usp_consultar_estudiantes_grupo_ambito_paginado` |
| B2NM-20 | idem | `usp_consultar_programas_grupo`: T, CA y D OK; un coordinador de otra facultad `SEC_002`. `totalRegistros` correcto con `OPT` compartida en `usp_consultar_asignaturas_coordinador_paginado`, `_planes_estudio_programa_paginado`, `_asignaturas_plan_paginado` y el directorio |

**Pruebas existentes que cambian por el cambio formal de contrato (AGENTS §4).** Cada cambio lleva en el commit la referencia a DEC-019/020 y a este contrato. No se relaja ninguna regla de negocio; donde cambia una aserción se indica cuál y por qué.

| Prueba | Qué cambia |
| :--- | :--- |
| Los 31 archivos que insertan `Asignatura(..., semestrePlanEstudio)`: `test_authorized_views_rbac`, `test_consultas_transversales_hu112_hu157`, `test_cruce_horario_docente`, `test_hu008_regla_inscripcion_programa`, `test_ident001_correo_verificacion`, `test_rec2_rbac_asignatura`, `test_ufn_clasificar_permanencia`, `test_usp_abrir_ventana_matricula_grupo`, `test_usp_cambiar_estado_docente_programa`, `test_usp_cambiar_estado_programa_academico`, `test_usp_consultar_{aforo_grupos_facultad, alerta_temprana_programa, bitacora_estudiante_programa, comparativa_facultades, comparativa_programas_facultad, ficha_estudiante_programa, historial_grupos_docente_programa, kpis_coordinador, kpis_decano, kpis_institucion, oferta_creacion_grupo_docente, oferta_grupos_estudiante, tendencia_ausentismo}`, `test_usp_guardar_horarios_grupo`, `test_usp_plan_estudio_estado_semestres`, `test_usp_precargar_sesiones_{concurrency.ps1, grupo}`, `test_usp_resolvers_{decano, institucion_admin}`, `test_usp_retirar_estudiante_grupo`, `test_uv_resumen_asistencia_estudiante_grupo` | El arrange usa `test/fixtures/culm001_b2nm_vincular_asignatura_plan.sql`; los fixtures con estudiantes de un programa reciben su `EstudiantePrograma` (R6). Las aserciones que cambian se listan en las filas siguientes |
| `test_cruce_horario_docente.sql` l.15-16, `test_usp_cambiar_estado_docente_programa.sql` l.89-90 | Las consultas del arrange por `a.idSemestrePlanEstudio` pasan a `uv_asignatura_plan_estudio` |
| `test_uv_resumen_asistencia_estudiante_grupo.sql` (incluida l.184 `uv_cumplimiento_sesion_grupo.idPrograma`) | Las aserciones sobre `idPrograma` pasan a `uv_resumen_asistencia_estudiante_programa_grupo` y a `EXISTS uv_grupo_programa` (la columna se movió). Porcentajes y horas de B intactos |
| `test_hu008_regla_inscripcion_programa.sql` (RI-01..RI-04 de A) y T-07 de A | "INS/BAS no inscribe en `EstudiantePrograma`" se sustituye por R7, porque DEC-020 reemplaza la regla ESP: la matrícula de un estudiante sin vínculo crea el vínculo con el programa del grupo, tanto en la inserción como en la reactivación |
| `test_consultas_transversales_hu112_hu157.sql` l.41 | Forma del resultset de `usp_buscar_asignaturas_paginado` (`planes`, `totalPlanes`) |
| `test_contract_closure.sql` l.247-262 | Las listas de excepción de resultset incluyen los SP de consulta nuevos de §2.7.1 |
| `test_consultas_coordinador_programa.sql`, `test_consultas_decano_facultad.sql`, `test_usp_consultar_grupos_paginado.sql`, `test_usp_consultar_sesiones_y_asistencias_paginado.sql`, `test_consolidado_auditoria_catalogos.sql` | Tablas temporales de `INSERT … EXEC` con las columnas nuevas o retiradas; el consolidado con el grano (grupo, programa) |
| `test_uv_estudiante_programa_no_duplicates.sql` | La precondición de 3 filas en `uv_estudiante` se recalcula con el grano nuevo; la aserción "sin duplicados en `uv_estudiante_programa`" se mantiene |
| Pruebas de B que fijan el resultset de la sábana y del resumen del estudiante | Sin `idPrograma` |

---

## 3. Backend

### 3.1 Endpoints (GREEN)

Respuestas en `ApiDataResponse<T>`, `ApiListResponse<T>` o `ApiPageResponse<T>`; errores en `ApiErrorResponse` con `X-Correlation-Id`. El ejecutor sale de `authenticatedUserResolver.requireAuthenticatedUserId()` y viaja al SP.

| Método y ruta | Estado | Caso de uso → SP | Respuesta / errores |
| :--- | :--- | :--- | :--- |
| `GET /api/v1/coordinador/planes-estudio?programaId&estaActivo&pagina&tamano` | modificado | `ConsultarPlanesEstudioUseCase` → `usp_consultar_planes_estudio_programa_paginado` | `ApiPageResponse<PlanEstudioDTO>`; 403 `COO_003` |
| `GET /api/v1/coordinador/planes-estudio/{id}/asignaturas?semestre&caracter&busqueda&pagina&tamano` | modificado | `ConsultarAsignaturasPlanUseCase` → `usp_consultar_asignaturas_plan_paginado` | `ApiPageResponse<AsignaturaPlanDTO>`; 404 `PLA_002` |
| `POST /api/v1/coordinador/planes-estudio/{id}/asignaturas` | modificado | `GestionarAsignaturaUseCase.crear` → `usp_crear_asignatura` | + `codigoCaracter` (requerido); 409 `ASI_002/003`; 404 `PLA_004`; 400 `ASI_001/007` |
| `PUT /api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | modificado | `usp_actualizar_asignatura` | + `codigoCaracter`; 409 `ASI_002/003/006`; 404 `ASI_004` |
| `POST /api/v1/coordinador/planes-estudio/{planId}/asignaturas-asociadas` | nuevo | `AsociarAsignaturaPlanUseCase` → `usp_asociar_asignatura_plan` | `{ idAsignatura, semestreNumero, codigoCaracter }`; 201; 404 `PLA_002/004`, `GEN_001`; 409 `ASI_003`; 403 `SEC_002` |
| `DELETE /api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | reemplaza el 501 (`CoordinadorPortalController.java:136-137`) | `DesvincularAsignaturaPlanUseCase` → `usp_desvincular_asignatura_plan` | 200; 404 `ASI_004`; 409 `ASI_005` |
| `GET /api/v1/coordinador/planes-estudio/{planId}/asignaturas-asociables?busqueda&pagina&tamano` | nuevo | `ConsultarAsignaturasAsociablesUseCase` | `ApiPageResponse<AsignaturaAsociableDTO>`; 404 `PLA_002` |
| `GET /api/v1/coordinador/caracteres-asignatura` | nuevo | `ConsultarCaracteresAsignaturaUseCase` → adaptador JPA sobre `uv_caracter_asignatura_plan` (catálogo sin ámbito, como los demás de solo consulta) | `ApiListResponse<CaracterAsignaturaDTO>` |
| `GET /api/v1/coordinador/asignaturas?programaId&busqueda&estaActiva&pagina&tamano` | modificado | `usp_consultar_asignaturas_coordinador_paginado` | `ApiPageResponse<AsignaturaPlanDTO>`; 403 `COO_003` |
| `PATCH /api/v1/coordinador/asignaturas/{id}/estado` | modificado | `usp_toggle_estado_asignatura` | 409 `ASI_006` |
| `GET /api/v1/coordinador/indicadores`, `/alertas-tempranas`, `/estudiantes/{id}/ficha`, `/estudiantes/{id}/bitacora` | modificado | + `programaId` opcional | 400 `COO_002`, 403 `COO_003`, 404 `GEN_001` |
| `GET /api/v1/estudiantes`, `GET /api/v1/estudiantes/{id}` | sobre A.2 | `usp_consultar_directorio_estudiantes_paginado` | `programaId` ajeno → 403 `COO_003` |
| `GET /api/v1/grupos/{grupoId}/estudiantes` | sobre A.2 | `usp_consultar_estudiantes_grupo_ambito_paginado` | El coordinador recibe solo a sus estudiantes; grupo fuera de ámbito → 403 |
| `GET /api/v1/grupos/{grupoId}/asistencias`, `POST /api/v1/asistencias/consultas/grupo` (legacy) | sobre A.2 | `usp_consultar_asistencias_grupo_ambito_paginado` | idem |
| `GET /api/v1/grupos/{grupoId}/programas` | nuevo | `ConsultarProgramasGrupoUseCase` → `usp_consultar_programas_grupo` | `ApiListResponse<ProgramaResumenDTO>`; 403 `SEC_002` |
| `POST /api/v1/grupos/{grupoId}/estudiantes` (docente) | modificado | `usp_registrar_estudiante_en_grupo` | + `idPrograma` opcional; 400 `EST_005/006` |
| `POST /api/v1/grupos/{grupoId}/matricula-qr` (`GrupoMatriculaQrController.java:61`) | modificado (S3 mínimo) | `usp_abrir_ventana_matricula_grupo` | + `programaId` opcional; 400 `EST_005/006` |
| `POST /api/v1/estudiante/matricular-grupo`, `POST /api/v1/public/matricula-qr/registro` | modificado | SP de token | 409 `MQR_008` |
| `GET /api/v1/decano/planes-estudio/{planId}/asignaturas` | modificado | `usp_consultar_asignaturas_plan_paginado` | `ApiPageResponse<AsignaturaPlanDTO>`; 404 `PLA_002` (F-DEC-015) |
| `GET /api/v1/decano/asignaturas` | modificado (columnas) | `usp_buscar_asignaturas_paginado` | `planes`, `totalPlanes` |
| `GET /api/v1/decano/grupos` | modificado | `ConsultarGruposDecanoUseCase` → `usp_consultar_grupos_facultad_paginado` | `ApiPageResponse<GrupoFacultadDTO>` (F-DEC-002) |
| `GET /api/v1/estudiante/oferta-academica` | modificado (campos) | `usp_consultar_oferta_grupos_estudiante` | + `codigoCaracter`, `nombreCaracter` |
| `GET /api/v1/docente/oferta-creacion-grupos` | modificado (campos) | `usp_consultar_oferta_creacion_grupo_docente` | `programas: string[]` en lugar de `nombrePrograma` |

### 3.2 Entidades, repositorios y DTOs

| Capa | Archivos |
| :--- | :--- |
| Entidades de resultado de SP (patrón `SpKpisCoordinadorEntity`) | `SpAsignaturaPlanEntity`, `SpAsignaturaAsociableEntity`, `SpAsignaturaCoordinadorEntity`, `SpPlanEstudioProgramaEntity`, `SpGrupoFacultadEntity`, `SpProgramaGrupoEntity`; `UvCaracterAsignaturaPlanEntity` (`@Immutable`) |
| Entidades de vista | `UvAsignaturaEntity` (sin `idSemestrePlanEstudio`, `inp`, `nombrePrograma`, `codigoSemestre`; + `totalPlanesActivos`); `UvEstudianteEntity` (+ `tieneVinculoPrograma`, grano nuevo); `UvEstudianteProgramaEntity` (+ `estaActivoUsuario`); `UvDocenteEntity`; las entidades de resultado de B para la sábana y el resumen del estudiante (sin `idPrograma`) |
| Repositorios | Nuevo: `AsignaturaPlanEstudioJpaRepository` (EXEC). Modificados: `AsignaturaJpaRepository` (retira `HQL_SELECT` y `HQL_POR_PROGRAMA/FACULTAD/PLAN`, l.61-73; EXEC de crear/actualizar con `@codigoCaracter`, l.30-45), `PlanEstudioJpaRepository` (l.74-90), `GrupoJpaRepository` (`HQL_GRUPOS_POR_FACULTAD`), `OfertaGruposEstudianteJpaRepository` (mapeo posicional de 21 columnas), `OfertaCreacionGruposDocenteJpaRepository`, `ConsultasTransversalesJpaRepository`, `CoordinadorIndicadoresJpaRepository`, `DecanoIndicadoresJpaRepository`, `AsistenciaProgramaJpaRepository`, `MatriculaQr*` (parámetro `@idPrograma`) y los repositorios de A.2 (parámetros nuevos). Sin cambio: `InstitutionalScopeJpaRepository` (l.84-97) y `CoordinadorJpaRepository` (l.97), que ya usan `EXISTS` y conteos por programa; los cubre la prueba de cardinalidad |
| Mapper/proyección | `AcademicViewJpaProjectionMapper.java:144` y `AsignaturaQueryRow`; nuevas `AsignaturaPlanQueryRow` y `AsignaturaAsociableQueryRow` |
| Aplicación | Puertos primarios nuevos `AsociarAsignaturaPlanInputPort`, `DesvincularAsignaturaPlanInputPort`, `ConsultarAsignaturasAsociablesInputPort`, `ConsultarCaracteresAsignaturaInputPort` y `ConsultarProgramasGrupoInputPort`, con sus `*UseCaseImpl`. Secundarios `AsignaturaPlanCommandPort` y `AsignaturaPlanQueryPort`. `AsignaturaQueryPort` y `PlanEstudioQueryPort` pasan a paginados |
| DTOs | `AsignaturaDTO` (catálogo) y `AsignaturaPlanDTO` (`idAsignatura, codigo, nombre, credito, idArea, nombreArea, idComponente, nombreComponente, idPlanEstudio, inpPlanEstudio, idPrograma, nombrePrograma, idSemestrePlanEstudio, numeroSemestre, codigoSemestre, codigoCaracter, nombreCaracter, estaActivoVinculo, estaActivaAsignatura, compartida`); `GuardarAsignaturaDTO` + `codigoCaracter`; nuevos `AsociarAsignaturaPlanDTO`, `AsignaturaAsociableDTO`, `CaracterAsignaturaDTO`, `ProgramaResumenDTO` y `GrupoFacultadDTO`; dominio y mappers de `consultarasignaturas/**`, `consultarasignaturasplan/**`, `consultarplanesestudio/**`, `docente/consultarofertacreaciongrupos/**`, `estudiante/consultarestudianteporid/**` y `consultarkpis/**` |

### 3.3 Casos de uso que dejan el JPQL directo

| Caso de uso | Hoy | Después |
| :--- | :--- | :--- |
| `ConsultarAsignaturasUseCaseImpl` (coordinador) | `HQL_POR_PROGRAMA` | `usp_consultar_asignaturas_coordinador_paginado` |
| `ConsultarAsignaturasPlanUseCaseImpl` (coordinador y decano) | `HQL_POR_PLAN` + `canDecanoAccessPrograma` | `usp_consultar_asignaturas_plan_paginado` |
| `ConsultarPlanesEstudioUseCaseImpl` | `HQL_POR_PROGRAMA`, `HQL_TOTAL_SEMESTRES` | `usp_consultar_planes_estudio_programa_paginado` |
| `ConsultarGruposDecanoUseCaseImpl` (l.35-37) | HQL sobre `uv_grupo` | `usp_consultar_grupos_facultad_paginado` |
| Directorio, estudiantes de grupo, asistencias de grupo | Pasan a SP en A.2 | B2 solo pasa los parámetros nuevos |

`InstitutionalScopePort` queda como defensa en profundidad, pero deja de ser la fuente del ámbito.

### 3.4 Contratos WORM

Cada archivo tiene dos copias idénticas, y cada copia su `.sha256` regenerado:
- `openapi-golden-path.yaml`, en Infra `docs/contracts/openapi/` y en Backend `docs/contracts/openapi/`: pasa a **1.2.0 (CULM-001-B2NM)**, o a la menor siguiente si A ya publicó una 1.1.x.
- `BACKEND_GOLDEN_PATH_CONTRACT.md`, en Infra `docs/contracts/openapi/` y en Backend `docs/contracts/`.

Solo cambian descripciones; **ningún** schema ni conjunto de respuestas cambia:

| Operación | Cambio |
| :--- | :--- |
| `consultarEstudiantes` (`GET /api/v1/estudiantes`, OpenAPI l.171-260) | El ámbito se aplica en el SP: COORDINADOR → estudiantes con `EstudiantePrograma` en sus programas; ADMINISTRADOR → su institución. `programaId` (l.237-240) pasa a decir "El estudiante tiene vínculo `EstudiantePrograma` con el programa". Un `programaId` fuera de ámbito devuelve `403`, que ya está en el conjunto de respuestas |
| `consultarEstudiantesGrupo` (`GET /api/v1/grupos/{grupoId}/estudiantes`, l.124-170) y fila 3 de `BACKEND_GOLDEN_PATH_CONTRACT.md` (l.37) | "Devuelve todos los estudiantes del grupo" pasa a "todos para DOCENTE titular y ADMINISTRADOR de la institución; para COORDINADOR, solo los que tienen `EstudiantePrograma` en sus programas". Un grupo fuera de ámbito devuelve **403**, coherente con la l.27 ("titularidad ajena: 403"); no se agrega 404 |
| `consultarAsistenciasGrupo` (`GET /api/v1/grupos/{grupoId}/asistencias`, l.317-) y fila 4 (l.20) | Misma regla para COORDINADOR; 403 |

`DB_BASELINE_CONTRACT.md` no cambia (`usp_crear_grupo` conserva la firma). Si el CONTRACT de A ya modifica estas descripciones, B2 parte de su texto.

### 3.5 Seguridad HTTP

`SecurityConfig` no abre rutas a roles nuevos; `/grupos/{id}/programas` queda para DOCENTE, COORDINADOR y DECANO. `access-catalog.json` y el catálogo del PEP reciben las rutas nuevas; si el PEP lo administra el equipo de seguridad, la lista va en `PRS.md`. Por DEC-022 punto 2, el administrador ya no está en `/coordinador/*` ni en `/decano/*`.

### 3.6 Observabilidad

Todos los SP reciben `@idCorrelacion = CorrelationIdContext.get()`. Logs estructurados, sin datos personales:
- `asignatura.plan.asociada` / `asignatura.plan.desvinculada` (`idAsignatura`, `idPlanEstudio`, `correlationId`);
- `estudiante.programa.vinculado` (origen `MANUAL` o `QR`).

### 3.7 Pruebas backend (RED)

| Tipo | Pruebas |
| :--- | :--- |
| Unitarias (100 % de ramas en casos de uso y mappers nuevos) | `AsociarAsignaturaPlanUseCaseImplTest`, `DesvincularAsignaturaPlanUseCaseImplTest`, `ConsultarAsignaturasAsociablesUseCaseImplTest`, `ConsultarProgramasGrupoUseCaseImplTest`, `GestionarAsignaturaUseCaseImplTest`, `GestionarAsignaturaMapperTest`, `ConsultarAsignaturasPlan*Test`, `ConsultarPlanesEstudio*Test`, `ConsultarGruposDecanoUseCaseImplTest`; `DbFailureClassifierAsignaturaPlanTest` (11 códigos) |
| Controladores | `CoordinadorPortalControllerTest` (DELETE 200/404/409; `asignaturas-asociadas` 201/404/409/403; paginados; `programaId` ajeno 403); `DecanoPlanEstudioControllerTest` (404); `DecanoGrupoControllerTest`; `GrupoControllerTest` (`/programas`, `idPrograma` en la matrícula); `GrupoMatriculaQrControllerTest` (`programaId`); `EstudianteControllerTest` y los controladores de A.2 (403 por `programaId` ajeno y por grupo fuera de ámbito) |
| Seguridad | `RbacSecurityFilterChainTest` (rutas nuevas y sus roles); `SecurityPepEnforcementFilterTest` (rutas nuevas en el catálogo del PEP) |
| OpenAPI | `OpenApiGoldenPathConformanceTest` (versión, l.111; conjuntos de respuestas sin cambio, l.80-81 y l.419-420), `OpenApiEstudiantesDirectoryConformanceTest` (descripción de `programaId`), `OpenApiGoldenPathValidationTest`. El `<include>openapi-golden-path.yaml</include>` del `pom.xml` (l.375) no cambia de ruta. `AsistenciasUCO-Infra/scripts/quality/verify-contracts.ps1` comprueba la paridad de las dos copias y de los `.sha256` |
| ArchUnit | Sin reglas nuevas; `JpaIsolationRulesTest`, `ControllersMustDependOnlyOnInputPortsTest` y `JpaRepositoryArchitectureRulesTest` en verde con los repositorios nuevos |
| Paridad JPA / oráculos (actualizados por el cambio formal de contrato) | `AcademicUserParityFixture`, `AcademicUserJdbcBaselineOracle`, `baseline/AsignaturaJdbcBaseline`, `baseline/PlanEstudioJdbcBaseline`, `AcademicQueryJpaParityIT`, `AcademicUserCommandsSpParityIT`/`SuccessParityIT`, `CoreViewQueriesJpaParityIT`, `SqlStoredProcedureContractIT`, `ViewEntityProjectionMappingTest`, `AcademicViewJpaProjectionBehaviorTest`, `AsignaturaJpaCommandPatternTest`, `PlanEstudioJpaCommandPatternTest`, `PlanEstudioJpaRepositoryTest`, `ConsultasTransversalesJpaRepositoryTest`, `FacultadDecanoJpaRepositoryTest`, `EstudianteJpaQueryContractTest`, `LecturaPorFacultadJpaPatternTest`, `JpaQueryAdapterContractTest`, `UsuarioPlanEstudioProvidersSqlServerIT`, `DbFailureClassifierPlanEstudioTest`. En `OfertaGruposEstudianteJpaRepositoryTest` (B-RED-04 de A), `OR08` pasa a 21 posiciones (`codigoCaracter` en 18, `nombreCaracter` en 19 y el total en 20) y `OR09` rechaza 19 |
| Integración (`-Pintegration`) | `AsignaturaPlanEstudioSqlServerIT` (asociar y desvincular); `AmbitoGrupoMixtoSqlServerIT` (CA no recibe a EB en los tres endpoints de A.2, ni en sesiones ni en KPIs) |

---

## 4. Frontend (GREEN)

### 4.1 Modelos y servicios

| Archivo | Cambio |
| :--- | :--- |
| `core/models/role-management.model.ts:272-283` | `AsignaturaPlanItem` + `idSemestrePlanEstudio`, `codigoCaracter`, `nombreCaracter`, `compartida`; nuevos `AsignaturaAsociable`, `CaracterAsignatura`, `ProgramaResumen` |
| `core/api/models/oferta-creacion-grupos-docente-api-dto.model.ts`, `asignatura-docente-api-dto.model.ts`, `estudiante-api-dto.model.ts`, `core/models/consultas-transversales.model.ts` | `programas`, `planes`, `totalPlanes`, `codigoCaracter`, `nombreCaracter`; sin `any` |
| `core/services/coordinator-management.service.ts` | `normalizarAsignaturaPlan` (l.78-88) y `aSolicitudAsignatura` (l.96-105, + `codigoCaracter`); nuevos `asociarAsignaturaPlan`, `buscarAsignaturasAsociables` y `getCaracteresAsignatura`. `desvincularAsignaturaPlan` (l.352) ya existe y ahora responde 200. Los listados leen `ApiPageResponse` pidiendo una sola página grande (la paginación en la UI se difiere) |
| `core/services/dean-facultad.service.ts`, `oferta-academica.service.ts`, `group.service.ts`, `course.service.ts` | `ApiPageResponse` en la malla y los grupos del decano; carácter en la oferta; `getProgramasGrupo`; `idPrograma` en la matrícula manual y `programaId` en la ventana QR |
| `core/interceptors/mock-backend.interceptor.ts`, `core/mocks/*` | Datos de ejemplo con una asignatura compartida y carácter |

### 4.2 Componentes

Todos OnPush, con `input()`/`output()`/`model()` y `signal`/`computed`, sin `setInterval` ni `localStorage`, y con los mensajes por `getApiErrorMessage`.

| Componente | Cambio |
| :--- | :--- |
| `features/coordinator/coordinator-study-plans/components/subject-form.component.ts` (y su página) | Select **Carácter** requerido |
| `components/associate-subject-dialog.component.ts` (nuevo) | Buscar asignaturas asociables, elegir semestre y carácter, y asociar; emite `asociada` |
| `components/study-plan-mesh.component.ts`, `pages/study-plan-mesh-page.component.ts` | Insignia Obligatoria/Optativa; botones "Nueva asignatura" y "Asociar asignatura existente"; "Quitar del plan" llama al DELETE (se conserva el `confirm()` actual; el modal se difiere) |
| `features/coordinator/coordinator-subjects/coordinator-subjects.component.ts` | Una fila por (asignatura, plan); `irAMallaPlan` (l.288) usa el plan de la fila |
| `features/dean/dean-plan-malla/dean-plan-malla.component.ts` | Insignia de carácter; un 404 muestra "Plan no encontrado" |
| `features/dean/dean-asignaturas/dean-asignaturas.component.ts` (l.109) | `planes` en lugar de "Plan {{ inpPlanEstudio }}" |
| `features/dean/dean-grupos` | Consume `ApiPageResponse` (una página) |
| `features/student/student-group-offer/student-group-offer.component.ts` | Insignia de carácter en "propias" |
| `features/teacher/teacher-grupos/**/teacher-matricula-modal.component.ts` | Select **Programa del estudiante**, visible si `getProgramasGrupo` devuelve más de un programa |
| Modal de apertura de la ventana QR (HU176B, `teacher-grupos`) | Select **Programa**, visible y requerido solo si el grupo tiene más de un programa (S3 mínimo) |
| `features/teacher/teacher-grupos/components/teacher-grupo-form.component.ts` | Muestra los `programas` de la asignatura |

### 4.3 Flujos

1. **Asociar una asignatura existente:** Malla → "Asociar asignatura existente" → buscar → elegir semestre y carácter → Asociar → la malla se recarga. Errores del backend: `ASI_003`, `PLA_004`.
2. **Crear asignatura:** Malla → "Nueva asignatura" → datos y carácter → Guardar. Si responde `ASI_002`, la UI muestra el mensaje y el botón de asociar sigue visible.
3. **Editar un vínculo:** se cambian semestre y carácter. En una compartida, tocar datos de catálogo devuelve `ASI_006` (mensaje del backend).
4. **Quitar del plan:** confirmación → DELETE. `ASI_005` explica el bloqueo.
5. **Matrícula en un grupo mixto:** el docente elige el programa en la matrícula manual y al abrir la ventana QR.

### 4.4 Rutas

No hay rutas nuevas (`app.routes.ts` l.342-387, l.228, l.293).

### 4.5 Pruebas frontend (RED)

- Nueva: `associate-subject-dialog.component.spec.ts` (búsqueda, selección, error 409, etiquetas accesibles).
- Actualizadas por el cambio de contrato:
  - `subject-form.component.spec.ts` (carácter requerido);
  - `study-plan-mesh.component.spec.ts` (insignia, botones, DELETE 200 y 409);
  - `coordinator-study-plans.component.spec.ts`, `coordinator-subjects.component.spec.ts`, `dean-asignaturas.component.spec.ts`;
  - `dean-plan-malla.component.spec.ts` (404);
  - `student-group-offer.component.spec.ts`;
  - `teacher-matricula-modal.component.spec.ts` (selector de programa);
  - spec del modal de la ventana QR (el selector solo aparece, y es requerido, con varios programas);
  - `coordinator-management.service.spec.ts` (l.690 y métodos nuevos);
  - `mock-backend.interceptor.spec.ts`.
- `npm run verify` en verde.

---

## 5. Docs, orden de integración, ramas y commits

### 5.1 Documentación

| Documento | Cambio |
| :--- | :--- |
| `AsistenciasUCO-Infra/docs/user-stories/HU-CATALOG.md` | HU075, HU084, HU108, HU008, HU076B, HU085, HU087, HU065/066/070, HU102/106, HU144 |
| Contratos WORM | §3.4 (4 archivos + 4 `.sha256`) |
| `AsistenciasUCO-Infra/docs/baseline/TECHNICAL_DEBT.md` | TD por cada uno de estos puntos: la reactivación de un vínculo conserva `fechaVinculacionUtc`; un grupo de un periodo que termina antes del vínculo queda sin programa (O-N10); cada `AMBIGUO`/`SIN_INTERSECCION` sin resolver; los diferibles de §7 |
| `GestioAsistenciaDB/docs/contracts/DB_UTC_D06_POST_FREEZE_MANIFEST.sha256` | Sin cambio; `freeze-manifest.ps1 -Mode Verify` |
| `docs/arquitectura-integral.md` (workspace) | Modelo con la puente y R6 |

### 5.2 Orden de integración

1. **Requisitos:** A (incluida A.2) y B (B.1 y B.2) mezclados en `integracion/CULM-001`. B2 edita la versión de A o B de estos objetos:
   - los tres SP de A.2;
   - `usp_registrar_estudiante_en_grupo_interno` (inserción y reactivación);
   - `usp_consultar_oferta_grupos_estudiante` (19 columnas);
   - `uv_resumen_asistencia_estudiante_grupo` y `uv_cumplimiento_sesion_grupo`;
   - `usp_consultar_resumen_asistencia_grupo_docente_paginado` y `usp_consultar_resumen_asistencia_estudiante`;
   - las pruebas RI-04/T-07 y B-RED-04.
2. **DB** (rama `feature/CULM-001-B2-asignaturas-nm`): inventario repetido (§2.7.4) → RED → GREEN → `db-deploy` sobre BD limpia y `up` sobre la BD local con backup COPY_ONLY previo → `db-test`.
3. **Backend:** entidades, repositorios, casos de uso, controladores, clasificador y contratos WORM → `mvnw verify` y `-Pintegration`.
4. **Frontend** → `npm run verify`.
5. **Infra:** HU-CATALOG, contratos y hashes, deuda técnica → `.\AsistenciasUCO-Infra\infra.ps1 verify`.
6. **AUDIT:** matriz de fugas con el fixture de dos programas, en T-SQL y `-Pintegration` (las cuentas Keycloak del segundo coordinador están en §7).
7. **PRs** hacia `integracion/CULM-001`, registrados en `PRS.md` y mezclados en orden DB → Backend → Frontend → Infra, sin despliegue parcial:
   - DB y Backend en `johnjduque/gestion-asistencia-db` y `alejovh12/AsistenciasUCO` (DEC-002);
   - Frontend en `shesho22/AsistenciasUCO-Frontend`;
   - Infra en `AsistenciasUCO/AsistenciasUCO-Infra`.

### 5.3 Commits (atómicos por capa)

DB:
1. `test(db): agregar pruebas red de asignaturas por plan y ambito mixto`
2. `test(db): actualizar fixtures al vinculo asignatura-plan` (el cuerpo justifica el cambio formal y lista las aserciones cambiadas)
3. `feat(db/tables): agregar AsignaturaPlanEstudio y catalogo de caracter`
4. `feat(db/views): resolver programa del grupo por la tabla puente`
5. `feat(db/sp): asociar, desvincular y consultar asignaturas por plan`
6. `fix(db/sp): resolver ambito del coordinador por EstudiantePrograma`
7. `feat(db/sp): exigir vinculo de programa en la matricula manual y QR`
8. `feat(db): migracion 16 de asignaturas N:M con backfill de vinculos` (`BREAKING CHANGE: se elimina Asignatura.semestrePlanEstudio y cambian columnas de uv_asignatura, uv_estudiante, uv_resumen_asistencia_estudiante_grupo y uv_cumplimiento_sesion_grupo`)

Backend:
1. `test(backend): agregar pruebas red de asignaturas por plan y ambito mixto`
2. `feat(backend/adapter): repositorio de asignaturas por plan sobre SP`
3. `feat(backend/usecase): asociar y desvincular asignaturas del plan`
4. `refactor(backend/adapter): mover consultas de malla y grupos del decano a SP`
5. `feat(backend/controller): endpoints de asociacion y desvinculacion`
6. `docs(backend): actualizar contratos golden path de CULM-001-B2NM`

Frontend:
1. `test(frontend): actualizar specs de malla y matricula al contrato N:M`
2. `feat(frontend/coordinador): asociar asignatura existente y caracter en la malla`
3. `feat(frontend/decano): malla y asignaturas con planes compartidos`
4. `feat(frontend/docente): seleccionar programa en matricula de grupos mixtos`
5. `feat(frontend/estudiante): mostrar caracter en la oferta de grupos`

Infra:
1. `docs(contracts): publicar golden path de CULM-001-B2NM`
2. `docs(hus): actualizar HUs de malla, oferta y ambito por relacion`

Pie común: `Refs:` con las HU y los hallazgos, y `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

## 6. Riesgos, rollback, limitaciones y puntos abiertos

### 6.1 Riesgos

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| 1 | Duplicación por el join 1:N en KPIs, aforo, consolidado y paginación | `uv_asignatura` 1:1; las dos vistas sin `idPrograma`; inventario completo (§2.7.4–§2.7.5); pruebas B2NM-03, 07, 15 y 20 |
| 2 | Vista congelada `uv_estudiante_grupo` | No se toca; B2NM-03 + `freeze-manifest.ps1 -Mode Verify` |
| 3 | Estudiantes invisibles para coordinador y decano (`AMBIGUO`, `SIN_INTERSECCION`) | Reporte + script con dos vías de resolución; R10 para administrador y docente (B2NM-19); una TD por cada fila sin resolver |
| 4 | Fuga entre coordinadores en grupos mixtos | `ufn_estudiantes_grupo_visibles` como único filtro; extensión de los SP de A.2; AUDIT con dos programas |
| 5 | Migración destructiva | Verificación y `DROP` en la misma transacción; SQL dinámico; backup COPY_ONLY; B2NM-12 |
| 6 | Conflictos con A y B | B2 empieza después de A y B; §5.2 lista los objetos compartidos; prefijo `culm001_b2nm`; números de semilla y códigos verificados antes del RED |
| 7 | BD nueva con backend viejo | Mezcla DB → Backend en la misma ventana; sin despliegue parcial |
| 8 | Volumen frente al 2026-11-13 | GREEN acotado al alcance mínimo; §7 diferible |
| 9 | Si un estudiante de A se matricula en una asignatura que solo está en B, la matrícula crea su vínculo con B (R7/DEC-020). Entonces aparece en el directorio, la ficha y la oferta "propias" de B, y el coordinador de B obtiene el derecho de corregir su identidad (`usp_corregir_identidad_usuario.sql:142`) | Es consecuencia de DEC-020; se documenta en HU-CATALOG. Para evitarlo, la asignatura se asocia también al plan de A (flujo §4.3.1) |
| 10 | Un coordinador que no coordina todos los programas de un grupo compartido pierde la gestión de horarios y precarga (O-N7) | Mínimo privilegio explícito; B2NM-18. El titular y quien coordina todos los programas sí pueden |

### 6.2 Rollback

- BD: `16_culm001_b2nm_asignatura_plan_down.sql` (precondición 1:1) o el backup COPY_ONLY previo al `up`.
- Backend, frontend e infra: revertir los PRs de B2 en orden inverso.
- Contratos: volver a la versión anterior y su `.sha256` en las dos copias.

### 6.3 Limitaciones aceptadas

- Reactivar un vínculo conserva `fechaVinculacionUtc` (TD).
- Un grupo creado para un periodo que terminó antes de la fecha del vínculo de su asignatura queda sin programa, invisible para coordinador y decano. `PlanEstudio.estado = 0` no saca grupos de `uv_grupo_programa` (O-N10, TD).
- La comparativa por programa puede sumar más estudiantes que el total de la facultad (R9).
- Cuando el programa tiene varios planes con la asignatura, el plan expuesto en `uv_estudiante` y `uv_docente` sigue una regla determinista: activo, mayor `inp`, menor `id`.

### 6.4 Puntos abiertos

1. Separar el `DROP COLUMN` en una migración `17_*` dentro de la misma ventana (recomendación opcional de REVIEW-1 §3). No se adopta salvo indicación del orquestador, porque DEC-019 lo fija en la misma migración.
2. Catálogo del PEP: confirmar quién lo actualiza (§3.5).

---

## 7. Diferible (post 2026-11-13)

Nada de esta tabla entra en el GREEN de B2. Cada punto queda como TD en `TECHNICAL_DEBT.md` con referencia a este contrato.

| # | Elemento | Por qué se puede diferir |
| :--- | :--- | :--- |
| D-01 | F-DEC-013: `sesionesEvaluadasPorMatricula`, `matriculasActivas` y rótulos del decano | Es una inconsistencia de nombres; no afecta al ámbito ni a DEC-019/020 |
| D-02 | F-DEC-014: filtro `idGrupo` en el servidor para `GET /decano/sesiones` | Hoy filtra el cliente y no hay fuga (los datos ya son de su facultad) |
| D-03 | Paginación en la UI (`PaginationComponent`) de planes, asignaturas y estudiantes del coordinador y de los grupos del decano | Los SP ya entregan `ApiPageResponse`; la UI pide una sola página |
| D-04 | `usp_consultar_estudiantes_programa_paginado` para `GET /coordinador/estudiantes` (parte de F-COO-008) | `uv_estudiante_programa` ya parte de `EstudiantePrograma` y el ámbito por vínculo se cumple; solo queda el JPQL heredado sobre la vista |
| D-05 | `totalObligatorias`/`totalOptativas` por plan, `estudiantesCompartidos` en la comparativa, `programasCompartidos`, chips "Compartida con N programas" y tooltips | Es información adicional; la marca `compartida` sí entra |
| D-06 | Rótulo "n de m estudiantes de tu programa" en los grupos del coordinador | Presentación |
| D-07 | F-COO-011: modal del sistema de diseño en lugar de `confirm()` al quitar del plan | Presentación (severidad baja) |
| D-08 | Selector de programa en la UI de KPIs cuando el backend responde `COO_002` | Ningún coordinador de los datos actuales tiene más de un programa, y la API ya responde `COO_002`/`COO_003` |
| D-09 | `requiereProgramaDocente` en la validación pública del token | Con S3 mínimo, la ventana de un grupo multiprograma siempre tiene programa; `MQR_008` cubre el caso residual |
| D-10 | Cuentas Keycloak del segundo coordinador y su estudiante (`security-baseline`) | La matriz de dos programas se prueba en T-SQL y en `-Pintegration` (DEC-022 punto 9) |
| D-11 | Columna extra `estudiantesGrupo` en el consolidado | El grano (grupo, programa) ya da los conteos correctos por programa |

---

## 8. Respuesta a REVIEW-1

| Objeción | Cambio hecho / motivo |
| :--- | :--- |
| §1 (parcial) | Se resuelve con O-B1, O-B3, O-N3 y O-N4 (filas siguientes) |
| **O-B1** Directorio, estudiantes y asistencias de grupo sin SP | Por decisión del orquestador, A.2 crea `usp_consultar_directorio_estudiantes_paginado`, `usp_consultar_estudiantes_grupo_ambito_paginado` y `usp_consultar_asistencias_grupo_ambito_paginado` con el ámbito dentro del SP. B2 los **extiende** a N:M sin redefinirlos (§1.4, §2.7.5, §3.1, §3.3), incluido el legacy `POST /asistencias/consultas/grupo`. Se retiraron el nombre provisional `usp_consultar_estudiantes_directorio_paginado` y el punto abierto 6.4.5. No se adoptan los nombres que propone el revisor (`usp_consultar_estudiantes_grupo`, `usp_consultar_asistencias_grupo`) para no duplicar los de A |
| **O-B2** Consumidores rotos al retirar `idPrograma` | §2.7.4 indica línea y reemplazo de `usp_consultar_tendencia_ausentismo` (l.56-57), `usp_consultar_kpis_institucion` (l.64, 72, 78), `usp_consultar_comparativa_facultades` (l.34, 52), `usp_consultar_kpis_decano` (l.47, 55, 62) y `usp_consultar_bitacora_estudiante_programa` (l.79), además de los ya listados. §2.7.5 recoge los consumidores de B (sábana y resumen del estudiante) y sus entidades. Se añade la regla de repetir el inventario antes del RED y la prueba B2NM-15 con `sp_refreshsqlmodule` |
| **O-B3** El grano de `uv_estudiante` rompe R10 | `uv_estudiante` pasa a (estudiante, grupo, programa del grupo) con `tieneVinculoPrograma`, que solo exigen las ramas coordinador y decano de `uv_auth_estudiante`. Se agrega `usp_buscar_estudiantes_institucion_paginado`. La institución en `usp_registrar_estudiante_en_programa_interno` se resuelve por matrícula → grupo → programa, y el SP que asegura el vínculo valida contra el programa elegido (§2.5, §2.7.2, §2.7.3). Pruebas B2NM-09 y B2NM-19 |
| **O-B4** El paso 2 del backfill excede DEC-020 | El paso 1 se limita a estudiantes con matrícula activa y sin vínculo; el paso 2 solo reporta `SIN_INTERSECCION`. El script de resolución ofrece las dos vías. B2NM-11 admite `AMBIGUO` y `SIN_INTERSECCION`. El riesgo 9 se amplía (corrección de identidad y oferta "propias"). El script de depuración HU008 ya no se retira (§2.4) |
| **O-B5** Pérdida de datos e idempotencia de la migración | La verificación y el `DROP` van en el último lote y en la misma transacción; las referencias a la columna van en `sp_executesql` con `COL_LENGTH`; `52902` cuenta vínculos activos e inactivos. B2NM-12 incluye el segundo `up` y el fallo forzado (§2.3). La separación en `17_*` queda como punto abierto opcional (§6.4.1) porque DEC-019 la fija en la misma migración |
| **O-B6** Colisiones de nombres | Prefijo `culm001_b2nm` en la migración (`16_culm001_b2nm_*`), las pruebas, los permisos, el fixture, el reporte y el script; semillas `37`–`39`. El segundo programa sale del fixture de A (DEC-022 punto 9), no de una semilla propia |
| **O-B7** WORM incompleto y 404 innecesario | 403 para un grupo fuera de ámbito, sin cambiar los conjuntos de respuesta. `BACKEND_GOLDEN_PATH_CONTRACT.md` (filas 3 y 4) se actualiza en las dos copias, con su `.sha256`. Pruebas nombradas: `OpenApiGoldenPathConformanceTest`, `OpenApiEstudiantesDirectoryConformanceTest`, `OpenApiGoldenPathValidationTest`, `RbacSecurityFilterChainTest`, `SecurityPepEnforcementFilterTest`, `pom.xml` l.375 y `verify-contracts.ps1` (§3.4, §3.7). Diverge del texto de DEC-021, que decía 404, por decisión del orquestador |
| **O-N1** Lista de pruebas existentes | Tabla de §2.9 ampliada: `test_contract_closure`, `test_consultas_transversales_hu112_hu157` l.41, `test_uv_resumen_*` l.184, `test_consultas_coordinador_programa`, `test_consultas_decano_facultad`, `test_usp_consultar_grupos_paginado`, `test_usp_consultar_sesiones_y_asistencias_paginado`, `test_consolidado_auditoria_catalogos`, `test_uv_estudiante_programa_no_duplicates`, `test_cruce_horario_docente` l.15-16, `test_usp_cambiar_estado_docente_programa` l.89-90, RI-04/T-07 de A, B-RED-04 y las pruebas de B. Se eliminó "ninguna aserción" y se listan las aserciones que cambian |
| **O-N2** Pruebas RED faltantes | B2NM-15 a B2NM-20: compilación, despliegue limpio, S2, R8/O-N7 en horarios y precarga, R10 del administrador, `usp_consultar_programas_grupo` y `totalRegistros`. Se agregan las specs de frontend del selector de matrícula y de la ventana QR. Las de `COO_002`, `requiereProgramaDocente` y "n de m" no aplican, porque esas piezas pasaron a §7 (D-06, D-08, D-09) |
| **O-N3** TVF sobre vistas en BD limpia | Las cuatro funciones leen solo tablas base y `uv_grupo_programa` las usa; B2NM-16 (§2.6) |
| **O-N4** `OBL` quemado | Columna `orden` en `CaracterAsignaturaPlan`; la oferta elige el de menor `orden` (§2.1, §2.7.4) |
| **O-N5** `uv_docente.idPlanEstudio` | Misma regla determinista que `uv_estudiante`, calculada en `ufn_programas_grupo`/`uv_grupo_programa` (§2.5) |
| **O-N6** `uv_auth_asistencia` | Queda declarada como no fuente de ámbito del coordinador; los consumidores futuros deben usar `ufn_estudiantes_grupo_visibles` (§2.5) |
| **O-N7** Horarios y precarga en grupos compartidos | Se exige el titular o un coordinador de **todos** los programas del grupo (mínimo privilegio); B2NM-18; riesgo 10 (§2.7.2) |
| **O-N8** Base de A | §2.7.3, §2.7.4 y §5.2: se parte de la oferta de 19 columnas de A (pasa a 21) y se elimina la regla ESP en inserción y reactivación; RI-04/T-07 cambian por cambio formal |
| **O-N9** El `down` restaura B.2 | §2.3, paso 3 del `down`: restaura las versiones A+B (B.2 de las dos vistas y sus consumidores, A.2 de los SP de ámbito) |
| **O-N10** Grupo sin programa por fecha y plan inactivo | §2.1 (un plan inactivo no saca grupos), §6.3 y TD |
| §8 Alcance | Adoptado como GREEN; el resto pasa a §7. S3 se mantiene en su forma mínima (DEC-021 y decisión del orquestador): `programaId` opcional en `POST /grupos/{id}/matricula-qr`, obligatorio solo con varios programas |
| §9 Puntos abiertos | 1 y 2 confirmados; 3 y 4 en §3.5 y §7 (D-10); 5 resuelto por O-B1 (A.2) |
