# CULM-001 · Paquete B2 — CONTRACT: asignaturas en varios planes/programas y ámbito por relación en grupos mixtos

> **Estado:** BORRADOR para revisión independiente (§9.2 del prompt). Se congela con su `.sha256` antes del RED.
> **Fecha:** 2026-11-06. **Fuentes:** `docs/PROMPT_FABLE_CULMINACION.md` §3.8–§3.9 (líneas 91-100), `DECISIONES.md` DEC-019 y DEC-020 (cerradas, no se reabren), `RESEARCH-ASIGNATURA-PLAN.md`, `FINDINGS-coordinador.md`, `FINDINGS-docente.md`, `FINDINGS-decano.md`, `AGENTS.md` §3.3.
> **Rutas:** relativas a cada worktree `C:\Proyectos\GestionAsistencia-CULM001\<repo>`. DB = `GestioAsistenciaDB/`, BE = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, FE = `GestioAsistenciaFrontend/src/app/`.
> **Base:** `integracion/CULM-001` **después** de mezclar A y B. Todo objeto que A o B ya hayan modificado se edita sobre su versión (§5.2).

---

## 1. Alcance, decisiones aplicadas y HUs

### 1.1 Alcance

| Incluido | Excluido |
| :--- | :--- |
| Relación N:M `Asignatura` ↔ `SemestrePlanEstudio` con carácter por catálogo (DEC-019) | Sedes, bloques o aulas (§3.9: el sistema no gestiona sedes) |
| Separar "crear asignatura" de "asociar asignatura existente a un plan/semestre"; desvincular (reemplaza el 501 de F-COO-005) | Prerrequisitos (HU025 descartada; `07_hu025_descartar_prerrequisitos_up.sql`) |
| Ámbito por `EstudiantePrograma` en grupos mixtos para coordinador y decano (DEC-020); eliminación de los `TOP 1` de programa | Flujo de cancelación por inasistencia (paquete C). B2 deja lista la función de pertenencia (`ufn_programas_grupo`, R6) que C usa para "coordinador del programa del estudiante" |
| Backfill de vínculos y reporte de ambiguos; la matrícula manual y por QR exigen o crean el vínculo | Cálculo por horas y sesiones canceladas (paquete B). B2 solo cambia el join de programa de las vistas que B ya modificó |
| Malla, oferta, creación de asignaturas y grupos, KPIs por programa, listados del coordinador y del decano | Rediseño visual (paquete E). B2 agrega los controles necesarios con los componentes existentes |
| | `usp_ejecutar_cierre_masivo_periodo`: no une a plan ni a programa (solo `EstudianteGrupo`/`Grupo`/`Sesion`); no cambia en B2. Su umbral fijo de 3 faltas es del paquete C |

### 1.2 Decisiones aplicadas (detalle de DEC-019 y DEC-020)

| Regla | Detalle contractual |
| :--- | :--- |
| R1 (DEC-019) | Tabla puente `AsignaturaPlanEstudio (asignatura, semestrePlanEstudio, caracter, estaActivo)` única por `(asignatura, semestrePlanEstudio)`. El carácter es FK al catálogo `CaracterAsignaturaPlan` (`OBL` Obligatoria, `OPT` Optativa); nunca un literal en T-SQL: los SP reciben `@codigoCaracter` tipado o leen `ASIGNATURA_PLAN/CARACTER_DEFECTO`. |
| R2 (DEC-019) | `Asignatura.codigo` pasa a UNIQUE global (`UX_Asignatura_codigo`). La asignatura es un elemento de catálogo; su pertenencia a planes vive solo en la puente. |
| R3 (DEC-019) | "Crear asignatura" (`usp_crear_asignatura`) inserta el catálogo **y** su primer vínculo en la misma transacción (vía `usp_internal_asociar_asignatura_plan`); "asociar asignatura existente" (`usp_asociar_asignatura_plan`) solo crea o reactiva un vínculo. Crear con un código existente → `ASI_002` (409); la UI ofrece siempre "Asociar asignatura existente" en la malla (sin parsear el mensaje). |
| R4 (DEC-019) | `Asignatura.semestrePlanEstudio` y `FK_Asignatura_SemestrePlanEstudio` se eliminan **al final de la misma migración**; el `down` restaura la columna desde la puente cuando cada asignatura tiene un único vínculo. |
| R5 (DEC-019) | `uv_grupo_programa` es explícitamente 1:N (un grupo → todos los programas cuyos planes contienen su asignatura con vínculo vigente). Todo consumidor que cuente o pagine grupos, sesiones o estudiantes usa `EXISTS` o `DISTINCT` sobre la clave de negocio. |
| R6 (DEC-020) | La pertenencia de un estudiante a un programa se resuelve **solo** por `EstudiantePrograma`. En un grupo, un coordinador ve al estudiante si existe `EstudiantePrograma(estudiante, p)` con `p` ∈ (programas que coordina ∩ programas del grupo). Igual para el decano con los programas de su facultad. |
| R7 (DEC-020) | Invariante: toda matrícula `EstudianteGrupo` tiene al menos un `EstudiantePrograma` del estudiante en un programa del grupo. La garantizan el backfill (§2.4) y la matrícula manual y por QR (§2.7.3). Las excepciones del backfill quedan en el reporte y en la prueba de invariante (T-B2-11). |
| R8 (DEC-020) | Se eliminan los `TOP 1` que eligen "el" programa: `usp_registrar_estudiante_en_grupo_interno.sql:122`, `usp_validar_gestion_grupo_coordinador_o_titular_interno.sql:101`, `usp_validar_docente_vinculo_activo_programa_interno.sql:33`, `usp_resolver_programa_coordinador_interno.sql:51`. Se reemplazan por `EXISTS` sobre conjuntos o por un programa explícito y validado. |
| R9 (DEC-020) | Los KPIs por programa cuentan solo estudiantes con `EstudiantePrograma` en ese programa. Los de facultad e institución cuentan `DISTINCT` (un estudiante o grupo compartido por dos programas de la misma facultad cuenta una vez). La comparativa por programa puede sumar más que el total de la facultad; se rotula en la API y en la UI. |
| R10 (derivada) | El docente titular sigue viendo a **todos** los estudiantes de su grupo (§3.8: "docente → solo los grupos donde es titular y sus estudiantes"); el filtro por programa aplica a coordinador y decano. El administrador ve su institución. |

**Supuestos que la revisión debe confirmar** (detalle no decidido; no reabren DEC-019/020):
- **S1.** Fechas de vigencia del vínculo (`fechaVinculacionUtc`, `fechaDesvinculacionUtc`) para que desvincular no borre la historia de KPIs ni haga visibles a otro programa los grupos anteriores a su vínculo (§2.1).
- **S2.** Los datos de catálogo de una asignatura compartida (código, nombre, créditos, área, componente, estado global) solo los cambia un coordinador que coordine **todos** los programas con vínculo activo; si no, `ASI_006` y solo puede cambiar semestre y carácter de su propio vínculo.
- **S3.** En la matrícula por QR de un grupo de varios programas, el docente fija al abrir la ventana un programa por defecto para estudiantes sin vínculo con ninguno de ellos ("el que elija el docente", DEC-020); si no lo fija, `MQR_008`.
- **S4.** Un coordinador de varios programas filtra con `programaId`; si lo omite, las listas usan todos sus programas y los KPIs exigen elegir uno (`COO_002`) cuando tiene más de uno. Con la semilla (un programa por coordinador) el comportamiento actual no cambia.

### 1.3 HUs y hallazgos afectados

| HU / hallazgo | Qué cambia en B2 |
| :--- | :--- |
| HU075, HU084, HU108 (malla) | La malla de un plan lista sus vínculos con semestre y carácter y marca las compartidas; el coordinador asocia, edita el vínculo y desvincula; el decano consulta |
| HU008 (oferta del estudiante) | "Propias" = grupos cuya asignatura tiene vínculo activo con un plan de un programa del estudiante; muestra el carácter en su programa; sin duplicados |
| HU076B, HU085 (crear asignatura) | Código único global; carácter obligatorio; código existente → `ASI_002` y flujo de asociación |
| HU087 (crear grupo) | El docente debe tener vínculo activo con **algún** programa de la asignatura; la firma congelada de `usp_crear_grupo` (`DB_BASELINE_CONTRACT.md:79`) no cambia |
| HU065, HU066, HU070 (KPIs y alertas del coordinador), HU102, HU106 (KPIs del decano) | R9; cierra F-COO-006 (13 vs 12) y F-DEC-013 (nombre `sesionesEjecutadas`) |
| HU060, HU064, HU068, HU069, HU071, HU072 (listados del coordinador) | Paginados por `usp_consultar_*`; filtro por `EstudiantePrograma` en grupos mixtos; 404 por id fuera de ámbito (F-COO-003, F-COO-008) |
| HU144 (decano grupos y sesiones) | SP paginado con ámbito de facultad (F-DEC-002); `idGrupo` filtrado en servidor (F-DEC-014); 404 en plan inexistente o ajeno (F-DEC-015) |
| F-COO-001, F-COO-002, F-DOC-013 (críticos) | **A** corrige de inmediato; **B2** rehace el ámbito sobre N:M (§1.4) |
| F-COO-005 | `DELETE /coordinador/planes-estudio/{planId}/asignaturas/{asigId}` deja de responder 501 |
| F-COO-011 | La confirmación de desvincular usa el modal del sistema de diseño (misma pantalla) |

### 1.4 Reparto A / B2 para los hallazgos críticos y altos de ámbito

| Hallazgo | Paquete A (inmediato, modelo 1:1) | Paquete B2 (completa sobre N:M) |
| :--- | :--- | :--- |
| F-COO-001 `GET /api/v1/estudiantes` | El caso de uso recibe al ejecutor; la consulta pasa a un SP paginado con ámbito dentro del SP (nombre lo fija el CONTRACT de A; aquí `usp_consultar_estudiantes_directorio_paginado`): coordinador → estudiantes con `EstudiantePrograma` en su programa; administrador → su institución; DOCENTE y ESTUDIANTE → 403 (el golden path ya dice "No se abre a DOCENTE") | La rama coordinador pasa a `ufn_programas_coordinador` (varios programas, sin `TOP 1`); `programaId` fuera de ámbito → 403; `programaId` significa vínculo `EstudiantePrograma` (cambio formal del golden path, §3.4) |
| F-COO-002 `GET /api/v1/estudiantes/{id}` | 404 si el estudiante no está en el ámbito (misma regla que el listado) | Mismo SP con `@idEstudiante`; los contextos académicos del detalle muestran solo grupos cuyo programa ∩ programas del ejecutor ≠ ∅ |
| F-DOC-013 (docente) | 403 en ambos endpoints para DOCENTE | Sin cambio adicional (el docente usa `/grupos/{id}/estudiantes`) |
| F-COO-003 grupos sin ámbito | Los casos de uso reciben al ejecutor; grupo fuera del programa → 404; listado de grupos del coordinador filtrado por su programa | En grupos mixtos, `/grupos/{id}/estudiantes`, `/grupos/{id}/asistencias` y `/sesiones/{id}/asistencias` muestran a un coordinador solo los estudiantes de sus programas (R6); conteos por programa |

Si el CONTRACT de A congela otro nombre para el SP del directorio, B2 modifica ese objeto con la misma semántica; no crea un segundo SP.

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
        estado  BIT              NOT NULL CONSTRAINT DF_CaracterAsignaturaPlan_estado DEFAULT (1),
        CONSTRAINT PK_CaracterAsignaturaPlan PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_CaracterAsignaturaPlan_codigo UNIQUE (codigo),
        CONSTRAINT UQ_CaracterAsignaturaPlan_nombre UNIQUE (nombre)
    );
END
```
Semilla `DB/schema/seed/33_caracter_asignatura_plan.sql` (MERGE idempotente con GUIDs fijos de semilla, como `16_tipo_vinculacion.sql`): `OBL` Obligatoria, `OPT` Optativa. Catálogo de solo consulta (sin SP de escritura), igual que `CategoriaJustificacion` (`12_categoria_justificacion_up.sql`).

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
FKs en `zz_foreign_keys.sql` (bloques nuevos con `IF NOT EXISTS`): `FK_AsignaturaPlanEstudio_Asignatura`, `FK_AsignaturaPlanEstudio_SemestrePlanEstudio`, `FK_AsignaturaPlanEstudio_CaracterAsignaturaPlan`. Se **retira** el bloque 18 (`FK_Asignatura_SemestrePlanEstudio`, `zz_foreign_keys.sql:140-144`).

**Regla de vigencia (S1).** Un vínculo aplica a un grupo `g` del periodo `pa` si `fechaLocal(fechaVinculacionUtc) <= pa.fechaFin` y (`fechaDesvinculacionUtc IS NULL` o `fechaLocal(fechaDesvinculacionUtc) >= pa.fechaInicio`), con la fecha local institucional del parámetro `TIEMPO/ZONA_HORARIA_SQLSERVER` (mismo cálculo que `uv_grupo`). Se encapsula en la función inline `ufn_vinculo_asignatura_vigente_periodo` (§2.6). Reasociar un vínculo inactivo reactiva **la misma fila** (por el UNIQUE): `estaActivo = 1`, `fechaDesvinculacionUtc = NULL`, conserva `fechaVinculacionUtc` (limitación aceptada, §6.3).

**Unicidad por plan.** Una asignatura no puede tener dos vínculos **activos** en semestres distintos del mismo plan. Se valida en `usp_internal_asociar_asignatura_plan` con `WITH (UPDLOCK, HOLDLOCK)` (`ASI_003`); no se agrega una columna `planEstudio` redundante.

### 2.2 Cambios en tablas y semillas existentes

| Objeto | Cambio |
| :--- | :--- |
| `tables/Asignatura.sql` | El `CREATE TABLE` deja de tener `semestrePlanEstudio`; se agrega `UX_Asignatura_codigo` (índice único sobre `codigo`; el SP ya lo guarda en `UPPER(TRIM())`, `usp_crear_asignatura.sql:33`) |
| `tables/EstudiantePrograma.sql` | `UX_EstudiantePrograma_estudiante_programa` único `(estudiante, programa)`: cierra el "sin UNIQUE" de la investigación §1 y protege la creación concurrente de vínculos (§2.7.3) |
| `tables/TokenMatriculaGrupo.sql` (HU176B) | Columna `programaPorDefecto UNIQUEIDENTIFIER NULL` + FK a `Programa` (S3). No está en el manifiesto congelado |
| `migrations/01_gestionasistenciadb.sql` | No se edita (baseline histórico) |
| `seed/13_academico_asignaturas.sql` | El MERGE de `Asignatura` deja de usar `semestrePlanEstudio`; se agrega el MERGE del vínculo `ARQ-402` (`E2F3A4B5-...01`) ↔ SPE `D2E3F4A5-...01` con carácter `OBL` |
| `seed/14_grupos_sesiones.sql` | La inserción de `EstudiantePrograma` deja de depender de la regla ESP (R7: un vínculo por estudiante matriculado) |
| `seed/34_culm001_b2_programa_compartido.sql` (nueva) | Segundo programa en la misma facultad con su coordinador, plan y semestre; una optativa `OPT` vinculada a ambos planes; un grupo de esa optativa con un estudiante de cada programa. Permite repetir la matriz de fugas con dos programas reales (recomendación de `FINDINGS-coordinador.md`) |

### 2.3 Migración `NN_culm001_b2_asignatura_plan_nm_up.sql` / `_down.sql`

`NN` = siguiente número libre en `DB/migrations/` al empezar el RED (hoy el último es `12_*`; A y B toman los siguientes). Ambos scripts son idempotentes, usan `SET XACT_ABORT ON`, una transacción explícita por bloque de datos y `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;` en el `CATCH`.

**`up` (orden obligatorio):**
1. Prechequeo (patrón `06_catalogos_area_estado_unicidad_up.sql:8-12`): `THROW 52900` si hay duplicados `UPPER(TRIM(codigo))` en `Asignatura` (el mensaje lista los códigos) o asignaturas cuyo `semestrePlanEstudio` no existe.
2. Crear `CaracterAsignaturaPlan` + semilla; crear `AsignaturaPlanEstudio`, sus FKs e índice.
3. Parámetro `ASIGNATURA_PLAN/CARACTER_DEFECTO = OBL` en `CatalogoParametro` (MERGE).
4. Backfill 1:1 (solo si `COL_LENGTH('dbo.Asignatura','semestrePlanEstudio')` no es NULL): un vínculo por asignatura con su `semestrePlanEstudio`, carácter `CARACTER_DEFECTO`, `estaActivo = 1` (el estado global sigue en `Asignatura.estado`), `fechaVinculacionUtc = COALESCE(MIN(pa.fechaInicio) de los periodos de sus grupos, SYSUTCDATETIME())` para que la historia siga vigente; `WHERE NOT EXISTS` sobre el UNIQUE.
5. `UX_Asignatura_codigo`.
6. Deduplicar `EstudiantePrograma` (conserva la fila de menor `id`; las borradas quedan en el reporte con tipo `DEDUPLICADO`) y crear `UX_EstudiantePrograma_estudiante_programa`. No hay FKs hacia `EstudiantePrograma`.
7. `ALTER TABLE TokenMatriculaGrupo ADD programaPorDefecto` + FK.
8. `CREATE OR ALTER` de funciones, vistas y SPs de §2.5–§2.7 (el `up` incluye su texto, como las migraciones 11 y 12; `deploy_schema.ps1` despliega los mismos archivos de `schema/`).
9. Backfill de `EstudiantePrograma` (§2.4).
10. `DROP CONSTRAINT FK_Asignatura_SemestrePlanEstudio` y `DROP COLUMN semestrePlanEstudio` (con guardas).
11. Mensajes (§2.8.1), permisos (§2.8.2) y verificación final: `THROW 52901` si alguna asignatura quedó sin vínculo o si hay matrículas que violan R7 sin fila en el reporte.

**`down`:**
1. `THROW 52902` (sin cambios) si alguna asignatura tiene 0 o más de 1 vínculo: el `down` solo es seguro con datos 1:1; el mensaje técnico lista las asignaturas. Para volver atrás con datos compartidos hay que desvincular primero.
2. `ADD semestrePlanEstudio UNIQUEIDENTIFIER NULL`; `UPDATE` desde el único vínculo; `ALTER COLUMN ... NOT NULL`; recrear `FK_Asignatura_SemestrePlanEstudio`.
3. Restaurar el texto previo de vistas, funciones y SPs (el de `integracion/CULM-001` antes de B2, incluido en el `down`) y eliminar los objetos nuevos.
4. Borrar los `EstudiantePrograma` con tipo `CREADO` en el reporte (los `DEDUPLICADO` no se reinsertan: eran duplicados exactos); quitar `UX_EstudiantePrograma_estudiante_programa`, `UX_Asignatura_codigo`, `TokenMatriculaGrupo.programaPorDefecto`, la puente, el catálogo, el parámetro y los mensajes nuevos.
5. El reporte `zz_reporte_b2_estudiante_programa` se conserva (solo lectura) para auditoría.

Prueba `up → down → up` en T-B2-12.

### 2.4 Backfill de `EstudiantePrograma` y reporte de ambiguos

Tabla de reporte (sin FKs, `DENY INSERT, UPDATE, DELETE` al runtime, patrón `zz_archivo_*` de DEC-010):
```sql
CREATE TABLE dbo.zz_reporte_b2_estudiante_programa (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_zz_reporte_b2_estudiante_programa PRIMARY KEY,
    estudiante  UNIQUEIDENTIFIER NOT NULL,
    grupo       UNIQUEIDENTIFIER NULL,
    programa    UNIQUEIDENTIFIER NULL,
    tipo        NVARCHAR(20)     NOT NULL,   -- CREADO | AMBIGUO | DEDUPLICADO | RESUELTO
    detalle     NVARCHAR(400)    NULL,
    fechaUtc    DATETIME2(3)     NOT NULL CONSTRAINT DF_zz_reporte_b2_fecha DEFAULT (SYSUTCDATETIME())
);
```
Algoritmo (con la puente ya creada; los programas de un grupo salen de la nueva `uv_grupo_programa`):
1. **Estudiantes sin ningún `EstudiantePrograma`** con matrículas (cualquier estado): si todas caen en **un único** programa → se crea el vínculo (`CREADO`). Si caen en dos o más → no se crea nada (`AMBIGUO`, `detalle` = programas). Es la regla literal de DEC-020.
2. **Estudiantes con vínculo** cuya matrícula en un grupo no tiene intersección con los programas del grupo (caso F-COO-006 y transversales depuradas por `scripts/maintenance/hu008_depurar_estudiante_programa_transversales.sql`): si el grupo tiene un único programa → se crea el vínculo (`CREADO`, la misma regla que la matrícula de §2.7.3); si tiene varios → `AMBIGUO`. Antes de B2 todo grupo tiene un único programa, así que en la práctica los `AMBIGUO` solo salen del paso 1.
3. El `up` devuelve un resumen (`SELECT tipo, COUNT(*)`) y deja el detalle en la tabla. Los `AMBIGUO` se resuelven con `DB/scripts/maintenance/b2_resolver_estudiante_programa_ambiguo.sql` (`@idEstudiante`, `@idPrograma`; valida que el programa sea de uno de sus grupos, crea el vínculo y registra `RESUELTO`). Mientras tanto el docente los ve (R10); coordinador y decano no.
4. `hu008_depurar_estudiante_programa_transversales.sql` se **retira** porque contradice R7 (se borra en el commit de BD con esa justificación).

Resultado esperado en la BD local actual (un programa): 0 `AMBIGUO`; `CREADO` incluye al estudiante `b1a2c3d4-...-0023` de F-COO-006; después, `totalEstudiantes` del KPI = directorio del coordinador.

### 2.5 Vistas

**Nuevas**

| Vista | Grano | Columnas / definición |
| :--- | :--- | :--- |
| `uv_caracter_asignatura_plan` | 1 por carácter | id, codigo, nombre, estaActivo |
| `uv_asignatura_plan_estudio` | 1 por vínculo | idAsignaturaPlanEstudio, idAsignatura, codigoAsignatura, nombreAsignatura, credito, idArea, nombreArea, idComponente, codigoComponente, nombreComponente, estaActivaAsignatura, idSemestrePlanEstudio, idSemestre, numeroSemestre, codigoSemestre, idPlanEstudio, inpPlanEstudio, estaActivoPlan, idPrograma, nombrePrograma, idFacultad, idInstitucion, idCaracter, codigoCaracter, nombreCaracter, estaActivoVinculo, fechaVinculacionUtc, fechaDesvinculacionUtc, totalProgramasActivos (programas distintos con vínculo activo de la asignatura) |
| `uv_estudiante_grupo_programa` | 1 por (matrícula, programa propio que comparte el grupo) | idEstudianteGrupo, idEstudiante, idGrupo, idPrograma, idPeriodoAcademico, codigoEstadoEstudiante: `uv_estudiante_grupo eg JOIN uv_grupo_programa gp ON gp.idGrupo = eg.idGrupo JOIN EstudiantePrograma ep ON ep.estudiante = eg.idEstudiante AND ep.programa = gp.idPrograma` (investigación §5, propuesta 1) |
| `uv_resumen_asistencia_estudiante_programa_grupo` | 1 por (matrícula, programa) | columnas de `uv_resumen_asistencia_estudiante_grupo` + idPrograma: resumen `JOIN uv_estudiante_grupo_programa` por `idEstudianteGrupo` |

**Modificadas** (lista exacta; cada una con prueba de cardinalidad en §2.9)

| Vista | Cambio | Grano resultante |
| :--- | :--- | :--- |
| `uv_asignatura` | Deja de unir plan/semestre/programa (`uv_asignatura.sql:30-35`). Se quitan `idSemestrePlanEstudio`, `inp`, `nombrePrograma`, `codigoSemestre`; se agrega `totalPlanesActivos` | 1 por asignatura (catálogo) |
| `uv_grupo_programa` | `uv_grupo g JOIN AsignaturaPlanEstudio apl ON apl.asignatura = g.idAsignatura JOIN SemestrePlanEstudio JOIN PlanEstudio` con `ufn_vinculo_asignatura_vigente_periodo` y `SELECT DISTINCT idGrupo, idPrograma, idPeriodoAcademico, grupoEstaHablitado` (dos semestres o dos planes del mismo programa no duplican) | **1:N** por (grupo, programa) |
| `uv_grupo` | **Sin cambio de texto**: une `uv_asignatura` por `id` y solo lee `id`/`nombre` (`uv_grupo.sql` l.40); como `uv_asignatura` sigue siendo 1 por asignatura, conserva 1 fila por grupo | 1 por grupo |
| `uv_estudiante_grupo` (**congelada**) | **No se toca**. Depende de `uv_grupo`, que sigue 1:1; por eso no se duplica. T-B2-03 fija `COUNT(*) = COUNT(DISTINCT id)` con una asignatura en dos planes y el hash del manifiesto no cambia | 1 por matrícula |
| `uv_auth_grupo` | El join a la cadena `Asignatura.semestrePlanEstudio → ... → Facultad` (l.29-33) se reemplaza, en las ramas administrador (`f.institucion`), decano (`f.decano`) y coordinador (`pr.coordinador`), por `EXISTS` sobre `uv_grupo_programa gp JOIN Programa pr JOIN Facultad f`; ramas docente y estudiante sin cambio | 1 por grupo |
| `uv_auth_programa`, `uv_auth_facultad`, `uv_auth_institucion` | Ramas docente y estudiante (l.41-45, 34-39, 33-50): la cadena se reemplaza por `uv_grupo_programa` dentro del `EXISTS` | sin cambio |
| `uv_docente` | Programa por `uv_grupo_programa` en lugar de `uv_asignatura.idSemestrePlanEstudio` (l.46-51) | 1 por (docente, grupo, programa del grupo) |
| `uv_estudiante` | Programa por `uv_estudiante_grupo_programa` (R6): la fila existe si el estudiante tiene `EstudiantePrograma` en un programa del grupo. `idPlanEstudio`/`inpPlanEstudio` = plan **activo** de ese programa que contiene la asignatura; si hay varios, el de mayor `inp` y luego menor `id` (regla determinista documentada en la vista, no un `TOP 1` arbitrario) | 1 por (estudiante, grupo, programa propio) |
| `uv_auth_estudiante` | Sin cambio de texto: su rama coordinador (`pr.id = e.idPrograma`, l.42) queda correcta al cambiar `uv_estudiante` | idem |
| `uv_estudiante_programa` | Parte de `EstudiantePrograma` + `uv_estudiante_identidad` (no de `DISTINCT uv_estudiante`); un estudiante con vínculo y sin grupos también aparece; agrega `estaActivoUsuario` | 1 por vínculo |
| `uv_cumplimiento_sesion_grupo` | Se quita `idPrograma` (una sesión no tiene programa propio); `idPeriodoAcademico` sale de `uv_grupo`. Se aplica sobre la versión de B (exclusión de canceladas, DEC-016) | 1 por sesión |
| `uv_resumen_asistencia_estudiante_grupo` | Se quita `idPrograma` y el join a `uv_grupo_programa`; `idPeriodoAcademico` sale de `uv_grupo`. Se aplica sobre la versión de B (columnas de horas, DEC-012) | 1 por matrícula |
| `uv_semestre_plan_estudio`, `uv_plan_estudio`, `uv_auth_docente`, `uv_auth_sesion` | Sin cambio de texto | — |

Ningún objeto del manifiesto (`DB/scripts/freeze-manifest.ps1:29-37`) se edita.

### 2.6 Funciones nuevas

| Función | Firma (inline TVF) | Uso |
| :--- | :--- | :--- |
| `ufn_vinculo_asignatura_vigente_periodo` | `(@fechaVinculacionUtc, @fechaDesvinculacionUtc, @fechaInicioPeriodo, @fechaFinPeriodo) RETURNS TABLE (vigente BIT)` | Regla S1 en `uv_grupo_programa` |
| `ufn_programas_coordinador` | `(@idUsuario UNIQUEIDENTIFIER) RETURNS TABLE (idPrograma)` | Todos los programas que coordina el usuario; reemplaza el `TOP 1` en listas y validaciones |
| `ufn_programas_grupo` | `(@idGrupo UNIQUEIDENTIFIER) RETURNS TABLE (idPrograma)` sobre `uv_grupo_programa` | Matrícula, titularidad, oferta y revisión de cancelación (C) |
| `ufn_estudiantes_grupo_visibles` | `(@idGrupo, @idUsuarioEjecutor) RETURNS TABLE (idEstudianteGrupo, idEstudiante)` | Filtro R6/R10 reutilizable: titular, administrador de la institución → todos; coordinador → `uv_estudiante_grupo_programa` ∩ `ufn_programas_coordinador`; decano → programas de su facultad |

### 2.7 Procedimientos almacenados

Todos los SP nuevos o modificados: `SET NOCOUNT ON; SET XACT_ABORT ON;`, `BEGIN TRY` / `BEGIN TRANSACTION ... COMMIT` en los de escritura, `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;` en el `CATCH`, parámetros evaluados con `IS NULL`, salida canónica `(idCorrelacion, mensajeUsuarioResultado, mensajeTecnicoResultado, estadoResultado)` y, en consultas, `@numeroPagina`, `@tamanoPagina` con `OFFSET ... FETCH NEXT` y `COUNT(*) OVER() AS totalRegistros` sobre vistas `uv_*`. El ámbito se valida **dentro** del SP (RBAC con `usp_validar_permiso_rbac_usuario_interno` + titularidad). `@tamanoPagina` se acota con el parámetro de paginación existente (máximo del catálogo).

#### 2.7.1 SP nuevos

| SP | Firma | Reglas | Mensajes |
| :--- | :--- | :--- | :--- |
| `usp_internal_asociar_asignatura_plan` | `(@idAsignatura, @idPlanEstudio, @semestreNumero INT, @codigoCaracter NVARCHAR(3), @idCorrelacion, @mensajeUsuarioResultado OUT, @mensajeTecnicoResultado OUT, @estadoResultado OUT)` | Interno (DENY al runtime). Resuelve SPE por plan+número (`PLA_004`); carácter por código activo, NULL → `CARACTER_DEFECTO` (`ASI_007`); con `UPDLOCK, HOLDLOCK` sobre los vínculos de la asignatura en ese plan: vínculo activo en el mismo semestre → `ASI_003`; activo en otro semestre del mismo plan → `ASI_003`; inactivo en el mismo semestre → reactiva; si no, inserta | `PLA_004`, `ASI_003`, `ASI_007`, `GEN_004` |
| `usp_asociar_asignatura_plan` | `(@idAsignatura, @idPlanEstudio, @semestreNumero INT, @codigoCaracter NVARCHAR(3) = NULL, @idCorrelacion, @idUsuarioEjecutor = NULL)` | Público (HU075). RBAC COORDINADOR; el plan existe (`PLA_002`) y es de un programa que coordina (`SEC_002` vía `usp_validar_titularidad_jerarquica_interno`); la asignatura existe (`GEN_001`) y es de la **misma institución** (tiene algún vínculo con un programa de la institución del plan, si no `GEN_001`: no se revela su existencia); llama al interno | + `PLA_002`, `SEC_002`, `GEN_001` |
| `usp_desvincular_asignatura_plan` | `(@idAsignatura, @idPlanEstudio, @idCorrelacion, @idUsuarioEjecutor = NULL)` | Público; reemplaza el 501 de F-COO-005. Mismas validaciones de ámbito. Vínculo activo inexistente → `ASI_004`. Bloqueo: si existen grupos de la asignatura en un periodo vigente o futuro **y** este es el único programa vigente del grupo, o si hay matrículas activas cuyo único programa común con el grupo es el de este plan → `ASI_005` (impide romper R7 o dejar grupos sin programa). Si pasa: `estaActivo = 0`, `fechaDesvinculacionUtc = SYSUTCDATETIME()` (baja lógica; la historia de KPIs se conserva por S1) | `ASI_004`, `ASI_005`, `GEN_005` |
| `usp_consultar_asignaturas_plan_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @idPlanEstudio, @numeroPagina, @tamanoPagina, @numeroSemestre INT = NULL, @codigoCaracter NVARCHAR(3) = NULL, @busqueda NVARCHAR(100) = NULL, @incluirInactivos BIT = NULL)` | Malla del coordinador y del decano (HU075, HU084, HU108). Plan inexistente o fuera de ámbito → `PLA_002` (404, cierra F-COO-008 y F-DEC-015). Ámbito: coordinador → plan de `ufn_programas_coordinador`; decano → plan de su facultad; administrador → su institución. Sobre `uv_asignatura_plan_estudio`; columnas extra `compartida = IIF(totalProgramasActivos > 1, 1, 0)` y `programasCompartidos` (`STRING_AGG` de los otros programas, solo nombres) | `PLA_002`, `VAL_*` |
| `usp_consultar_asignaturas_asociables_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @idPlanEstudio, @numeroPagina, @tamanoPagina, @busqueda NVARCHAR(100) = NULL)` | Candidatas para "Asociar asignatura existente": asignaturas activas de la institución del plan sin vínculo activo en ese plan; búsqueda por código o nombre; 1 fila por asignatura con `planes` (`STRING_AGG` de "Programa · Plan inp · S n") | `PLA_002`, `SEC_002` |
| `usp_consultar_asignaturas_coordinador_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @idPrograma = NULL, @busqueda = NULL, @estaActiva BIT = NULL)` | Reemplaza el JPQL de `GET /coordinador/asignaturas` (F-COO-008). 1 fila por (asignatura, plan de sus programas); `@idPrograma` fuera de su coordinación → `COO_003` | `COO_003` |
| `usp_consultar_planes_estudio_programa_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @idPrograma = NULL, @estaActivo BIT = NULL)` | Reemplaza `PlanEstudioJpaRepository.HQL_POR_PROGRAMA`/`HQL_TOTAL_SEMESTRES` y el conteo de créditos (F-COO-008). `totalAsignaturas`, `totalCreditos`, `totalObligatorias`, `totalOptativas` por plan **vía la puente** (vínculos activos) | `COO_003` |
| `usp_consultar_estudiantes_programa_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @idPrograma = NULL, @busqueda NVARCHAR(100) = NULL, @estaActivo BIT = NULL)` | `GET /coordinador/estudiantes` (HU068, F-COO-008): estudiantes con `EstudiantePrograma` en sus programas, paginado; columnas `programas` y `gruposActivos` (solo grupos donde R6 los hace visibles) | `COO_003` |
| `usp_consultar_grupos_facultad_paginado` | `(@idUsuarioEjecutor, @idCorrelacion, @numeroPagina, @tamanoPagina, @idPeriodoAcademico = NULL, @idPrograma = NULL, @busqueda = NULL)` | `GET /decano/grupos` (F-DEC-002): ámbito de facultad dentro del SP con `EXISTS` sobre `uv_grupo_programa`; 1 fila por grupo; `programas` agregado; `@idPrograma` fuera de su facultad → `KPI_003` | `KPI_003` |
| `usp_consultar_programas_grupo` | `(@idUsuarioEjecutor, @idCorrelacion, @idGrupo)` | Programas del grupo para el selector de la matrícula manual y de la ventana QR; solo titular, coordinador o decano con ámbito (`GEN_001` si no) | `GEN_001` |

#### 2.7.2 SP modificados (firma y regla)

| SP | Cambio de firma | Cambio de regla |
| :--- | :--- | :--- |
| `usp_crear_asignatura` | + `@codigoCaracter NVARCHAR(3) = NULL` | Unicidad de código contra la **tabla** con `UPDLOCK, HOLDLOCK` → `ASI_002` (antes `VAL_006` sobre la vista, l.141); inserta el catálogo sin `semestrePlanEstudio` y llama a `usp_internal_asociar_asignatura_plan` en la misma transacción; agrega `SET XACT_ABORT ON` y la transacción explícita que hoy no tiene |
| `usp_actualizar_asignatura` | + `@codigoCaracter NVARCHAR(3) = NULL` (`@idPlanEstudio`, `@semestreNumero` ya existen, hoy ignorados) | Actualiza el **vínculo** del plan (semestre, carácter) y, si S2 lo permite, los datos de catálogo; código duplicado → `ASI_002`; compartida con programas ajenos y cambian datos de catálogo → `ASI_006` |
| `usp_toggle_estado_asignatura` | sin cambio | Estado **global**; con S2 (`ASI_006` si es compartida con programas ajenos). Para quitarla de un plan se usa desvincular |
| `usp_validar_gestion_asignatura_coordinador_interno` | + `@idPlanEstudio = NULL`, + `@exigirTodosLosProgramas BIT = 0` | Sin `SELECT` de un único programa (l.63-65): el coordinador debe coordinar **algún** programa con vínculo de la asignatura (o el del plan, si llega); con `@exigirTodosLosProgramas = 1` debe coordinar **todos** (S2) |
| `usp_validar_gestion_grupo_coordinador_o_titular_interno` | sin cambio | `TOP 1 pe.idPrograma` (l.101) → `EXISTS (ufn_programas_grupo ∩ ufn_programas_coordinador)` |
| `usp_validar_docente_vinculo_activo_programa_interno` | sin cambio | `TOP 1 idPrograma` (l.33) → `EXISTS` de `DocentePrograma` activo en algún programa con vínculo activo de la asignatura; `DOC_009` si solo hay vínculos inactivos |
| `usp_crear_grupo` | **sin cambio** (firma congelada, `DB_BASELINE_CONTRACT.md:79`) | PASO 2B (l.117-119): el docente debe tener `uv_docente_programa` activo en **algún** programa de la asignatura (`SEC_002` si no); la asignatura debe tener al menos un vínculo activo con plan activo (`ASI_004`) |
| `usp_resolver_programa_coordinador_interno` | + `@idProgramaSolicitado UNIQUEIDENTIFIER = NULL` | Sin `TOP 1` (l.51): con `@idProgramaSolicitado` valida que lo coordine (`COO_003`); sin él, si coordina uno lo devuelve, si coordina varios → `COO_002`, si ninguno → `KPI_001` (S4). Los SP de §2.7.2 que lo invocan (`usp_consultar_kpis_coordinador`, `_alerta_temprana_programa`, `_ficha_estudiante_programa`, `_bitacora_estudiante_programa`, `_resumen_asistencia_estudiante_programa`, `_resumen_docentes_programa`, `_historial_grupos_docente_programa`) reciben `@idPrograma UNIQUEIDENTIFIER = NULL` y lo pasan |
| `usp_validar_estudiante_en_programa_interno` | sin cambio | `EXISTS` sobre `uv_estudiante_grupo_programa` (l.37) en lugar de "algún grupo cuya asignatura es del programa" (investigación §5, propuesta 2) |
| `usp_consultar_kpis_coordinador` | + `@idPrograma = NULL` | Resumen sobre `uv_resumen_asistencia_estudiante_programa_grupo` (`idPrograma = @programa`) y cumplimiento con `EXISTS uv_grupo_programa`; `totalEstudiantes = COUNT(DISTINCT idEstudiante)` de estudiantes del programa (cierra F-COO-006) |
| `usp_consultar_alerta_temprana_programa` | + `@idPrograma = NULL` | Sobre `uv_resumen_asistencia_estudiante_programa_grupo`; solo estudiantes del programa |
| `usp_consultar_resumen_asistencia_estudiante_programa`, `usp_consultar_ficha_estudiante_programa`, `usp_consultar_bitacora_estudiante_programa` | + `@idPrograma = NULL` | Solo grupos donde el estudiante comparte el programa (R6); estudiante ajeno → `GEN_001` (404, comportamiento actual) |
| `usp_consultar_consolidado_asistencia_grupos_paginado` | sin cambio (ya tiene `@idPrograma`) | 1 fila por grupo (`EXISTS` sobre `uv_grupo_programa`, l.74); para coordinador los conteos y porcentajes del grupo se calculan solo con sus estudiantes (`estudiantesPrograma`) y se agrega `estudiantesGrupo` (total, sin identidad) |
| `usp_consultar_grupos_paginado` | + `@idPrograma = NULL` | Coordinador: `estudiantesActivos` = solo sus estudiantes; `capacidadMaximaPermitida`, `cuposDisponibles` siguen siendo del grupo (recurso compartido, sin datos personales). Titular/administrador sin cambio |
| `usp_consultar_asistencias_sesion_paginado`, `usp_consultar_sesiones_grupo_paginado` | sin cambio | Filtran `eg.idEstudiante` con `ufn_estudiantes_grupo_visibles` (l.121-126); conteos recalculados con ese filtro (investigación §5, propuesta 4) |
| `usp_consultar_kpis_decano` | sin cambio | Totales de facultad con `COUNT(DISTINCT)`; `sesionesEjecutadas` = sesiones distintas (misma semántica que el coordinador) y se agrega `sesionesEvaluadasPorMatricula` (el denominador que hoy viaja con ese nombre) y `matriculasActivas` rotulada aparte de `totalEstudiantes` (cierra F-DEC-013) |
| `usp_consultar_kpis_institucion`, `usp_consultar_comparativa_facultades` | sin cambio | `DISTINCT` por estudiante/grupo/sesión al pasar por `uv_grupo_programa` (l.43, 83) |
| `usp_consultar_comparativa_programas_facultad` | sin cambio | Cada programa cuenta sus estudiantes por `uv_resumen_asistencia_estudiante_programa_grupo`; agrega `estudiantesCompartidos` (también en otro programa) para rotular R9 |
| `usp_consultar_aforo_grupos_facultad` | sin cambio | 1 fila por grupo (`EXISTS`, l.69), `programas` agregado; filtro por programa con `EXISTS` |
| `usp_consultar_sesiones_facultad_paginado` | + `@idGrupo = NULL` | Filtro por grupo en servidor; grupo fuera de la facultad → `GEN_001` (cierra F-DEC-014); 1 fila por sesión (`EXISTS`, l.108) |
| `usp_consultar_historial_estudiante` | sin cambio | Programa por `uv_estudiante_grupo_programa` (l.115); sin filas repetidas por grupo compartido |
| `usp_resolver_periodo_kpi_interno`, `_facultad_interno`, `_institucion_interno` | sin cambio | `EXISTS` sobre `uv_grupo_programa` (l.46/44/44) |
| `usp_cambiar_estado_programa_academico_interno` | sin cambio | Regla D4 (l.57): bloquea si hay grupos habilitados con vínculo vigente al programa (`EXISTS`) |
| `usp_buscar_asignaturas_paginado` | sin cambio | Decano/administrador `/asignaturas` (l.85-86): 1 fila por asignatura con vínculos en planes de su ámbito; columnas `planes` (`STRING_AGG` "Programa · Plan inp · S n · Carácter") y `totalPlanes`; desaparecen `codigoSemestre`, `inpPlanEstudio`, `nombrePrograma` sueltos |
| `usp_consultar_programas_creditos_facultad_paginado` | sin cambio | Créditos por plan vía la puente (l.64-70), vínculos activos |
| `usp_consultar_componentes_formacion` | sin cambio | Cuenta asignaturas sobre `uv_asignatura` (1 por asignatura, l.77): sin cambio de texto si compila sin las columnas retiradas |
| `usp_quitar_semestre_plan_estudio` | sin cambio | Bloqueo `PLA_006` (l.145) contra vínculos **activos** de la puente en ese SPE |
| `usp_consultar_oferta_creacion_grupo_docente` | sin cambio | Sobre `uv_asignatura_plan_estudio` (l.79) con vínculos activos en programas del docente; 1 fila por asignatura, `programas` agregado |
| `usp_consultar_oferta_grupos_estudiante` (HU008) | sin cambio | "Propias": grupos cuya asignatura tiene vínculo activo con un plan de un programa del estudiante (`EXISTS`, l.93-111); "transversales" BAS/INS por institución como hoy, excluyendo las ya propias; 1 fila por grupo; `codigoCaracter`/`nombreCaracter` del vínculo en el programa del estudiante (si hay varios, se prioriza `OBL`) |
| `usp_consultar_historial_grupos_docente_programa` | + `@idPrograma = NULL` | `EXISTS` sobre `uv_grupo_programa` (l.94-97) |
| `usp_consultar_destinatarios_retiro_estudiante_grupo` | sin cambio | Notifica a los coordinadores de los programas del **estudiante** que comparten el grupo (R6), no al de la asignatura (l.64-67) |
| `usp_consultar_reenvio_verificacion_correo` | sin cambio | Ámbito del coordinador (l.79-83) por `EstudiantePrograma` ∩ `ufn_programas_coordinador` |
| SP del directorio de A (`usp_consultar_estudiantes_directorio_paginado`) | + `@idEstudiante = NULL` si A no lo trae | Rama coordinador con `ufn_programas_coordinador`; `@idPrograma` fuera de ámbito → `COO_003`; contextos por `uv_estudiante` (ya filtrado por R6) |
| `usp_consultar_estudiantes_facultad_paginado`, `usp_consultar_estudiante_facultad_detalle` | sin cambio | Heredan R6 por `uv_estudiante`/`uv_auth_estudiante`; los `STRING_AGG(DISTINCT)` actuales evitan repetir programas |

#### 2.7.3 Matrícula manual y por QR: el vínculo `EstudiantePrograma`

Las tres vías terminan en `usp_registrar_estudiante_en_grupo_interno` (manual del docente `usp_registrar_estudiante_en_grupo:164`, QR autenticado y público por `usp_internal_matricular_por_token:232`). Se modifica sobre la versión de A (reactivación `I → A`, DEC-009).

| SP | Cambio de firma | Regla |
| :--- | :--- | :--- |
| `usp_internal_asegurar_estudiante_programa_grupo` (nuevo, interno) | `(@idEstudiante, @idGrupo, @idProgramaElegido = NULL, @idCorrelacion, @idProgramaResultado OUT, @mensajeUsuarioResultado OUT, @mensajeTecnicoResultado OUT, @estadoResultado OUT)` | Con `UPDLOCK, HOLDLOCK` sobre `EstudiantePrograma` del estudiante: (1) si ya tiene vínculo con algún programa del grupo → lo devuelve, no crea nada (si llegó `@idProgramaElegido` distinto, se ignora y se informa en el mensaje técnico); (2) si no y el grupo tiene un único programa → crea el vínculo con ese programa (reutiliza `usp_registrar_estudiante_en_programa_interno`, hoy sin consumidores); (3) si no y el grupo tiene varios → exige `@idProgramaElegido` ∈ programas del grupo (`EST_005` si falta, `EST_006` si no pertenece) y crea el vínculo. Una violación del UNIQUE por carrera se trata como "ya existe" |
| `usp_registrar_estudiante_en_grupo_interno` | + `@idProgramaElegido UNIQUEIDENTIFIER = NULL` | Se elimina el `TOP 1 pe.programa` con `comp.codigo = 'ESP'` (l.122-135, regla ESP de HU008 sustituida por R7 de DEC-020); llama al interno anterior antes de insertar o reactivar la matrícula, en la misma transacción |
| `usp_registrar_estudiante_en_grupo` (manual) | + `@idPrograma UNIQUEIDENTIFIER = NULL` | Lo pasa como `@idProgramaElegido` |
| `usp_abrir_ventana_matricula_grupo` (HU176B) | + `@idProgramaPorDefecto UNIQUEIDENTIFIER = NULL` | Si llega, debe ser un programa del grupo (`EST_006`) y se guarda en `TokenMatriculaGrupo.programaPorDefecto` (S3) |
| `usp_internal_matricular_por_token` | sin cambio | Pasa `programaPorDefecto` del token como `@idProgramaElegido`; si el grupo tiene varios programas, el estudiante no comparte ninguno y el token no tiene programa por defecto → `MQR_008` (409) y no se crea usuario ni matrícula (en el flujo público, antes de crear el usuario) |
| `usp_validar_token_matricula_publico` | sin cambio | Devuelve además `requiereProgramaDocente BIT` para que la pantalla pública avise antes de pedir datos |

#### 2.7.4 Objetos que dejan de existir

- `FK_Asignatura_SemestrePlanEstudio` y la columna `Asignatura.semestrePlanEstudio`.
- `scripts/maintenance/hu008_depurar_estudiante_programa_transversales.sql` (§2.4).

### 2.8 Mensajes y permisos

#### 2.8.1 Mensajes nuevos

Seed `DB/schema/seed/35_mensajes_asignatura_plan.sql` (MERGE en `CatalogoMensajeUsuario` y `CatalogoMensajeTecnico`, formato de `29_mensajes_asignatura.sql`) y las mismas claves en Azure App Configuration (`messages:user:<CODIGO>`, label `es`; `messages:technical:<CODIGO>`). Con DEC-018 la demo local usa el proveedor `sqlserver`. Los códigos se reservan para B2; antes del RED se verifica que A y B no los usaron.

| Código | Tipo / HTTP | Mensaje al usuario |
| :--- | :--- | :--- |
| `ASI_002` | CONFLICT / 409 | Ya existe una asignatura con ese código. Usa "Asociar asignatura existente" para agregarla a este plan. |
| `ASI_003` | CONFLICT / 409 | La asignatura ya está asociada a este plan de estudios. |
| `ASI_004` | NOT_FOUND / 404 | La asignatura no está asociada a este plan de estudios. |
| `ASI_005` | CONFLICT / 409 | No puedes quitar la asignatura de este plan: tiene grupos o estudiantes del programa en el periodo vigente o en periodos futuros. |
| `ASI_006` | CONFLICT / 409 | La asignatura es compartida con programas que no coordinas; solo puedes cambiar su semestre y su carácter en tu plan. |
| `ASI_007` | VALIDATION / 400 | El carácter de la asignatura no es válido. |
| `EST_005` | VALIDATION / 400 | El grupo pertenece a varios programas: indica el programa del estudiante. |
| `EST_006` | VALIDATION / 400 | El programa indicado no corresponde a los programas del grupo. |
| `MQR_008` | CONFLICT / 409 | Este grupo pertenece a varios programas. Pide a tu docente que te matricule o que defina el programa de la matrícula por QR. |
| `COO_002` | VALIDATION / 400 | Coordinas varios programas: selecciona el programa que quieres consultar. |
| `COO_003` | FORBIDDEN / 403 | El programa indicado no pertenece a tu coordinación. |

Mapeo en `BE/infrastructure/adapter/secondary/persistence/sqlserver/support/error/DbFailureClassifier.java` (junto a `PLA_002`/`PLA_004` → `RESOURCE_NOT_FOUND`, l.77): `ASI_004` → `RESOURCE_NOT_FOUND`; `ASI_002/003/005/006`, `MQR_008` → `CONFLICT`; `ASI_007`, `EST_005/006`, `COO_002` → `VALIDATION`; `COO_003` → `FORBIDDEN`.

#### 2.8.2 Permisos

Script aditivo `DB/schema/security/rol_asistencias_runtime_culm001_b2.sql` (patrón `rol_asistencias_runtime_hu081_hu083.sql`; no edita `rol_asistencias_runtime.sql`, que está en el manifiesto post-freeze): `THROW` si falta un SP requerido; `GRANT EXECUTE` sobre los SP públicos nuevos de §2.7.1; `DENY EXECUTE` sobre `usp_internal_asociar_asignatura_plan` y `usp_internal_asegurar_estudiante_programa_grupo`; `DENY INSERT, UPDATE, DELETE` sobre `AsignaturaPlanEstudio`, `CaracterAsignaturaPlan`, `zz_reporte_b2_estudiante_programa` y `EstudiantePrograma`. Las vistas `uv_*` nuevas reciben `SELECT` por el bucle de vistas de `rol_asistencias_runtime.sql:79`; las TVF `ufn_*` nuevas, `SELECT` explícito.

### 2.9 Pruebas T-SQL (RED)

Archivos nuevos en `DB/test/`, con fixture propio (dos programas A y B de la misma facultad, coordinadores CA y CB, decano D, docente T vinculado a ambos, optativa `OPT` vinculada a los planes de A y B, un grupo G de esa optativa con estudiantes EA ∈ A y EB ∈ B, y un segundo grupo de una asignatura solo de A). Cada prueba termina con `@@TRANCOUNT = 0` y deja la BD como estaba.

| ID | Archivo | Caso (esperado) |
| :--- | :--- | :--- |
| T-B2-01 | `test_culm001_b2_asignatura_plan_nm.sql` | Asociar `OPT` a 2 planes → 2 vínculos; `uv_asignatura` 1 fila; `uv_asignatura_plan_estudio` 2; `uv_grupo` 1 fila por grupo; `uv_grupo_programa` 2 filas para G |
| T-B2-02 | idem | Crear con código existente → `ASI_002`; asociar dos veces → `ASI_003`; asociar a otro semestre del mismo plan → `ASI_003`; carácter inválido → `ASI_007`; plan ajeno → `SEC_002`; asignatura de otra institución → `GEN_001` |
| T-B2-03 | idem | Cardinalidad de vistas congeladas y heredadas con G en 2 programas: `uv_estudiante_grupo`, `uv_asistencia`, `uv_detalle_asistencia`, `uv_sesion` con `COUNT(*) = COUNT(DISTINCT id)`; `uv_cumplimiento_sesion_grupo` 1 por sesión; `uv_resumen_asistencia_estudiante_grupo` 1 por matrícula |
| T-B2-04 | idem | Desvincular: con grupo vigente y único programa → `ASI_005`; sin grupos → `estaActivo = 0`; grupos de periodos pasados siguen en `uv_grupo_programa` del programa (S1); grupos creados después no aparecen para el programa desvinculado; reasociar reactiva la misma fila |
| T-B2-05 | `test_culm001_b2_ambito_grupo_mixto.sql` | CA ve G y su docente; en `usp_consultar_asistencias_sesion_paginado`, `usp_consultar_grupos_paginado`, `usp_consultar_estudiantes_programa_paginado`, ficha, bitácora y alertas, CA ve EA y **no** EB; CB al revés; T ve EA y EB; D ve ambos |
| T-B2-06 | idem | Ficha/bitácora/resumen de EB pedidos por CA → `GEN_001` sin datos; `usp_consultar_estudiantes_directorio_paginado` con `@idPrograma = B` por CA → `COO_003` |
| T-B2-07 | idem | KPIs: `usp_consultar_kpis_coordinador` de A cuenta EA y no EB; comparativa por programa cuenta EA en A y EB en B; `usp_consultar_kpis_decano` cuenta G una vez y 2 estudiantes; un estudiante con vínculo a A y B en G cuenta en ambos programas y una vez en la facultad |
| T-B2-08 | idem | Coordinador con 2 programas: sin `@idPrograma` los KPIs → `COO_002`; con `@idPrograma` de otro → `COO_003`; las listas sin `@idPrograma` incluyen ambos |
| T-B2-09 | `test_culm001_b2_matricula_vinculo_programa.sql` | Manual: estudiante sin vínculo en grupo de un programa → vínculo creado; en G sin vínculo y sin `@idPrograma` → `EST_005`; con programa ajeno → `EST_006`; con vínculo previo a A → no crea otro; reactivación `I → A` de A conserva el vínculo |
| T-B2-10 | idem | QR: G sin programa por defecto y estudiante sin vínculo → `MQR_008` sin crear usuario (público) ni matrícula; con `programaPorDefecto` → vínculo creado; concurrencia (dos sesiones) no viola `UX_EstudiantePrograma_estudiante_programa` |
| T-B2-11 | idem | Invariante R7: `NOT EXISTS` matrícula sin vínculo en un programa de su grupo, salvo las del reporte `AMBIGUO` |
| T-B2-12 | `test_culm001_b2_migracion.ps1` | Sobre una BD con el esquema previo: `up` → backfill 1:1 (vínculos = asignaturas), columna eliminada, reporte con `CREADO`/`AMBIGUO` esperados; `up` otra vez no cambia nada; `down` restaura la columna con los mismos valores; `down` con una asignatura compartida → `THROW 52902` sin cambios; `up` de nuevo; `@@TRANCOUNT = 0` tras cada paso |
| T-B2-13 | `test_culm001_b2_oferta_y_grupos.sql` | HU008: G aparece una vez en "propias" para EA y EB con su carácter; oferta docente 1 fila por asignatura; `usp_crear_grupo` con T vinculado solo a B sobre `OPT` → OK, con docente sin vínculo → `SEC_002`; `usp_quitar_semestre_plan_estudio` con vínculo activo → `PLA_006` |
| T-B2-14 | `test_culm001_b2_decano.sql` | `usp_consultar_grupos_facultad_paginado` 1 fila por G; `usp_consultar_sesiones_facultad_paginado @idGrupo` ajeno → `GEN_001`; `usp_consultar_asignaturas_plan_paginado` con plan inexistente o de otra facultad → `PLA_002` |

**Pruebas existentes que fijan el modelo actual.** Son 31 archivos de `DB/test/` (30 `.sql` + `test_usp_precargar_sesiones_concurrency.ps1`) que insertan `Asignatura(..., semestrePlanEstudio)` en el arrange: `test_authorized_views_rbac`, `test_consultas_transversales_hu112_hu157`, `test_cruce_horario_docente`, `test_hu008_regla_inscripcion_programa`, `test_ident001_correo_verificacion`, `test_rec2_rbac_asignatura`, `test_ufn_clasificar_permanencia`, `test_usp_abrir_ventana_matricula_grupo`, `test_usp_cambiar_estado_docente_programa`, `test_usp_cambiar_estado_programa_academico`, `test_usp_consultar_{aforo_grupos_facultad, alerta_temprana_programa, bitacora_estudiante_programa, comparativa_facultades, comparativa_programas_facultad, ficha_estudiante_programa, historial_grupos_docente_programa, kpis_coordinador, kpis_decano, kpis_institucion, oferta_creacion_grupo_docente, oferta_grupos_estudiante, tendencia_ausentismo}`, `test_usp_guardar_horarios_grupo`, `test_usp_plan_estudio_estado_semestres`, `test_usp_precargar_sesiones_{concurrency.ps1, grupo}`, `test_usp_resolvers_{decano, institucion_admin}`, `test_usp_retirar_estudiante_grupo`, `test_uv_resumen_asistencia_estudiante_grupo`.

| Grupo | Qué se actualiza (cambio formal de contrato, AGENTS §4) | Qué **no** cambia |
| :--- | :--- | :--- |
| Los 31 | Solo el arrange: `Asignatura` sin `semestrePlanEstudio` + un `INSERT AsignaturaPlanEstudio` (helper común `test/fixtures/b2_vincular_asignatura_plan.sql`) | Ninguna aserción |
| `test_hu008_regla_inscripcion_programa` | La aserción "transversal BAS/INS no crea `EstudiantePrograma`" se reemplaza por R7 (DEC-020 sustituye la regla ESP); las demás aserciones de oferta se conservan | — |
| `test_uv_resumen_asistencia_estudiante_grupo` | Las aserciones sobre `idPrograma` pasan a `uv_resumen_asistencia_estudiante_programa_grupo` (la columna se movió) | Aserciones de porcentajes y horas (las de B) |
| `test_usp_consultar_kpis_coordinador`, `test_usp_consultar_kpis_decano` | Cada fixture con estudiantes del programa recibe su `EstudiantePrograma` (R6); el KPI de decano agrega las aserciones de `sesionesEvaluadasPorMatricula` (F-DEC-013) | Los valores esperados de los casos existentes |
| `test_authorized_views_rbac`, `test_rec2_rbac_asignatura` | Arrange; se agregan casos de grupo mixto en el mismo archivo | Las aserciones de RBAC existentes |

---

## 3. Backend

### 3.1 Endpoints nuevos y modificados

Todos devuelven `ApiDataResponse<T>`, `ApiListResponse<T>` o `ApiPageResponse<T>` (`elementos`, `numeroPagina`, `tamanoPagina`, `totalElementos`, `totalPaginas`) y errores `ApiErrorResponse` con `X-Correlation-Id`. El ejecutor sale de `authenticatedUserResolver.requireAuthenticatedUserId()` y viaja al SP; ninguna regla de ámbito se decide solo en Java.

| Método y ruta | Estado | Caso de uso → SP | Respuesta / errores |
| :--- | :--- | :--- | :--- |
| `GET /api/v1/coordinador/planes-estudio?programaId&estaActivo&pagina&tamano` | modificado (paginado) | `ConsultarPlanesEstudioUseCase` → `usp_consultar_planes_estudio_programa_paginado` | `ApiPageResponse<PlanEstudioDTO>` (+ `totalObligatorias`, `totalOptativas`); 403 `COO_003` |
| `GET /api/v1/coordinador/planes-estudio/{id}/asignaturas?semestre&caracter&busqueda&pagina&tamano` | modificado (paginado, 404) | `ConsultarAsignaturasPlanUseCase` → `usp_consultar_asignaturas_plan_paginado` | `ApiPageResponse<AsignaturaPlanDTO>`; 404 `PLA_002` (plan inexistente o ajeno) |
| `POST /api/v1/coordinador/planes-estudio/{id}/asignaturas` | modificado | `GestionarAsignaturaUseCase.crear` → `usp_crear_asignatura` | Cuerpo `GuardarAsignaturaRequest` + `codigoCaracter` (requerido); 201; 409 `ASI_002`, `ASI_003`; 404 `PLA_004`; 400 `ASI_001`, `ASI_007` |
| `PUT /api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | modificado | `GestionarAsignaturaUseCase.actualizar` → `usp_actualizar_asignatura` | + `codigoCaracter`; 409 `ASI_002`, `ASI_003`, `ASI_006`; 404 `ASI_004` |
| `POST /api/v1/coordinador/planes-estudio/{planId}/asignaturas-asociadas` | **nuevo** | `AsociarAsignaturaPlanUseCase` → `usp_asociar_asignatura_plan` | Cuerpo `{ idAsignatura, semestreNumero, codigoCaracter }`; 201; 404 `PLA_002`, `PLA_004`, `GEN_001`; 409 `ASI_003`; 403 `SEC_002` |
| `DELETE /api/v1/coordinador/planes-estudio/{planId}/asignaturas/{asigId}` | **reemplaza el 501** (`CoordinadorPortalController.java:136-137`) | `DesvincularAsignaturaPlanUseCase` → `usp_desvincular_asignatura_plan` | 200; 404 `ASI_004`; 409 `ASI_005` |
| `GET /api/v1/coordinador/planes-estudio/{planId}/asignaturas-asociables?busqueda&pagina&tamano` | **nuevo** | `ConsultarAsignaturasAsociablesUseCase` → `usp_consultar_asignaturas_asociables_paginado` | `ApiPageResponse<AsignaturaAsociableDTO>`; 404 `PLA_002` |
| `GET /api/v1/coordinador/caracteres-asignatura` | **nuevo** | `ConsultarCaracteresAsignaturaUseCase` → lectura de `uv_caracter_asignatura_plan` por adaptador JPA (catálogo sin ámbito, como los demás catálogos de solo consulta) | `ApiListResponse<CaracterAsignaturaDTO>` |
| `GET /api/v1/coordinador/asignaturas?programaId&busqueda&estaActiva&pagina&tamano` | modificado (paginado) | `ConsultarAsignaturasUseCase` → `usp_consultar_asignaturas_coordinador_paginado` | `ApiPageResponse<AsignaturaPlanDTO>` (1 por asignatura y plan); 403 `COO_003` |
| `PATCH /api/v1/coordinador/asignaturas/{id}/estado` | modificado | `usp_toggle_estado_asignatura` | 409 `ASI_006` |
| `GET /api/v1/coordinador/estudiantes?programaId&busqueda&estaActivo&pagina&tamano` | modificado (paginado, SP) | `ConsultarEstudiantesProgramaUseCase` → `usp_consultar_estudiantes_programa_paginado` (deja `EstudianteProgramaJpaRepository.java:21-31`) | `ApiPageResponse<EstudianteProgramaDTO>` (+ `programas`, `gruposActivos`); 403 `COO_003` |
| `GET /api/v1/coordinador/indicadores?programaId`, `/alertas-tempranas?programaId`, `/estudiantes/{id}/ficha?programaId`, `/estudiantes/{id}/bitacora?programaId`, `/consolidado-asistencia` | modificado (parámetro opcional) | SP de §2.7.2 | 400 `COO_002`, 403 `COO_003`, 404 `GEN_001` |
| `GET /api/v1/grupos`, `/grupos/{id}/estudiantes`, `/grupos/{id}/asistencias`, `/sesiones/{id}/asistencias` (coordinador) | modificado (sobre A) | SP de grupos/sesiones con `ufn_estudiantes_grupo_visibles` | Coordinador: solo sus estudiantes (R6); grupo ajeno 404 (A) |
| `GET /api/v1/grupos/{id}/programas` | **nuevo** | `ConsultarProgramasGrupoUseCase` → `usp_consultar_programas_grupo` | `ApiListResponse<ProgramaResumenDTO>`; 404 `GEN_001` |
| `POST /api/v1/grupos/{id}/estudiantes` (docente) | modificado | `usp_registrar_estudiante_en_grupo` | + `idPrograma` opcional; 400 `EST_005`, `EST_006` |
| `POST /api/v1/docente/grupos/{id}/ventana-matricula` (HU176B, ruta vigente) | modificado | `usp_abrir_ventana_matricula_grupo` | + `idProgramaPorDefecto` opcional; 400 `EST_006` |
| `POST /api/v1/estudiante/matricula-qr` y la matrícula pública por token (rutas vigentes de HU176B) | modificado | `usp_matricular_estudiante_por_token`, `usp_registrar_estudiante_por_token_publico` | 409 `MQR_008`; la validación pública del token devuelve `requiereProgramaDocente` |
| `GET /api/v1/decano/planes-estudio/{planId}/asignaturas?semestre&caracter&pagina&tamano` | modificado (SP, paginado, 404) | `usp_consultar_asignaturas_plan_paginado` (deja `canDecanoAccessPrograma` en el caso de uso) | `ApiPageResponse<AsignaturaPlanDTO>`; 404 `PLA_002` (cierra F-DEC-015) |
| `GET /api/v1/decano/asignaturas` | modificado (columnas) | `usp_buscar_asignaturas_paginado` | `planes`, `totalPlanes` en lugar de `codigoSemestre`/`inpPlanEstudio`/`nombrePrograma` |
| `GET /api/v1/decano/grupos?periodoId&programaId&busqueda&pagina&tamano` | modificado (SP, paginado) | `ConsultarGruposDecanoUseCase` → `usp_consultar_grupos_facultad_paginado` (deja `GrupoJpaRepository.java:85-90,193-199`) | `ApiPageResponse<GrupoFacultadDTO>` (cierra F-DEC-002) |
| `GET /api/v1/decano/sesiones?idGrupo` | modificado | `usp_consultar_sesiones_facultad_paginado @idGrupo` (`DecanoFacultadConsultaController.java:66`) | 404 `GEN_001` (cierra F-DEC-014) |
| `GET /api/v1/decano/indicadores` | modificado (campos) | `usp_consultar_kpis_decano` | + `sesionesEvaluadasPorMatricula`, `matriculasActivas` (F-DEC-013) |
| `GET /api/v1/estudiante/oferta-academica` | modificado (campos) | `usp_consultar_oferta_grupos_estudiante` | + `codigoCaracter`, `nombreCaracter` |
| `GET /api/v1/docente/oferta-creacion-grupos` | modificado (campos) | `usp_consultar_oferta_creacion_grupo_docente` | `programas: string[]` en lugar de `nombrePrograma` |
| `GET /api/v1/estudiantes`, `GET /api/v1/estudiantes/{id}` | modificado sobre A | SP del directorio | §3.4 |

Las rutas exactas de HU176B se toman del código vigente al empezar el GREEN; el contrato fija el parámetro y los errores, no renombra rutas.

### 3.2 Entidades, repositorios y DTOs

| Capa | Archivos |
| :--- | :--- |
| Entidades de resultado de SP (`.../jpa/entity/`, patrón `SpKpisCoordinadorEntity`) | `SpAsignaturaPlanEntity`, `SpAsignaturaAsociableEntity`, `SpAsignaturaCoordinadorEntity`, `SpPlanEstudioProgramaEntity`, `SpEstudianteProgramaEntity`, `SpGrupoFacultadEntity`, `SpProgramaGrupoEntity`; `UvCaracterAsignaturaPlanEntity` (`@Immutable`) |
| Entidades de vista modificadas | `UvAsignaturaEntity` (sin `idSemestrePlanEstudio`, `inp`, `nombrePrograma`, `codigoSemestre`; + `totalPlanesActivos`), `UvEstudianteEntity` y `UvEstudianteProgramaEntity` (cardinalidad nueva, §2.5), `UvDocenteEntity`, `SpKpisCoordinadorEntity`, `SpComparativaProgramaEntity`, `SpAforoGrupoEntity`, `SpEstructuraFacultadEntity`, `SpFichaEstudianteEntity` (campos de §2.7.2) |
| Repositorios (`.../jpa/repository/`) | Nuevo `AsignaturaPlanEstudioJpaRepository` (EXEC asociar, desvincular, consultar plan, asociables, programas del grupo). Modificados: `AsignaturaJpaRepository` (quita `HQL_SELECT`/`HQL_POR_PROGRAMA`/`HQL_POR_FACULTAD`/`HQL_POR_PLAN`, l.61-73; EXEC crear/actualizar con `@codigoCaracter`, l.30-45), `PlanEstudioJpaRepository` (quita `HQL_TOTAL_SEMESTRES` y conteos, l.74-90), `GrupoJpaRepository` (quita `HQL_GRUPOS_POR_FACULTAD`), `EstudianteProgramaJpaRepository` (EXEC), `CoordinadorIndicadoresJpaRepository`, `DecanoIndicadoresJpaRepository`, `OfertaGruposEstudianteJpaRepository`, `OfertaCreacionGruposDocenteJpaRepository`, `ConsultasTransversalesJpaRepository`, `EstudianteJpaRepository` (SP del directorio, sobre A), `AsistenciaProgramaJpaRepository` (`@idPrograma`). `InstitutionalScopeJpaRepository` (l.84-97) y `CoordinadorJpaRepository` (l.97) ya usan `EXISTS`/conteos filtrados por programa sobre `uv_grupo_programa`: se revisan con la prueba de cardinalidad, sin cambio esperado |
| Mapper/proyección | `AcademicViewJpaProjectionMapper.java:144` y `AsignaturaQueryRow` (sin `idSemestrePlanEstudio`); nuevas `AsignaturaPlanQueryRow`, `AsignaturaAsociableQueryRow` |
| Aplicación (`BE/application/`) | Puertos primarios nuevos: `AsociarAsignaturaPlanInputPort`, `DesvincularAsignaturaPlanInputPort`, `ConsultarAsignaturasAsociablesInputPort`, `ConsultarCaracteresAsignaturaInputPort`, `ConsultarProgramasGrupoInputPort` con sus `*UseCaseImpl`. Puertos secundarios: `AsignaturaPlanCommandPort`, `AsignaturaPlanQueryPort`; `AsignaturaCommandPort`/`AsignaturaQueryPort`, `PlanEstudioQueryPort` cambian a resultados paginados |
| DTOs | `AsignaturaDTO` (`features/coordinador/common/dto`) se divide: `AsignaturaDTO` (catálogo) y `AsignaturaPlanDTO` (`idAsignatura, codigo, nombre, credito, idArea, nombreArea, idComponente, nombreComponente, idPlanEstudio, inpPlanEstudio, idPrograma, nombrePrograma, idSemestrePlanEstudio, numeroSemestre, codigoSemestre, codigoCaracter, nombreCaracter, estaActivoVinculo, estaActivaAsignatura, compartida, programasCompartidos`); `GuardarAsignaturaDTO` + `codigoCaracter`; nuevos `AsociarAsignaturaPlanDTO`, `AsignaturaAsociableDTO`, `CaracterAsignaturaDTO`, `ProgramaResumenDTO`, `GrupoFacultadDTO`; dominio y mappers de `consultarasignaturas/**`, `consultarasignaturasplan/**`, `consultarplanesestudio/**`, `docente/consultarofertacreaciongrupos/**`, `estudiante/consultarestudianteporid/**` (`EstudianteContextoAcademico`), `consultarestudiantesprograma/**`, `consultarkpis/**`, `indicadores/rule/IndicadoresRules.java` |

### 3.3 Casos de uso que dejan el JPQL directo y pasan a SP

| Caso de uso | Hoy | Después | Hallazgo |
| :--- | :--- | :--- | :--- |
| `ConsultarEstudiantesProgramaUseCaseImpl` | JPQL sobre `uv_estudiante_programa` con ámbito en Application (`InstitutionalScopePort`) | `usp_consultar_estudiantes_programa_paginado` | F-COO-008 |
| `ConsultarAsignaturasUseCaseImpl` (coordinador) | `AsignaturaJpaRepository.HQL_POR_PROGRAMA` | `usp_consultar_asignaturas_coordinador_paginado` | F-COO-008 |
| `ConsultarAsignaturasPlanUseCaseImpl` (coordinador y decano) | `HQL_POR_PLAN` + `canDecanoAccessPrograma` | `usp_consultar_asignaturas_plan_paginado` | F-COO-008, F-DEC-015 |
| `ConsultarPlanesEstudioUseCaseImpl` | `PlanEstudioJpaRepository.HQL_POR_PROGRAMA`/`HQL_TOTAL_SEMESTRES` | `usp_consultar_planes_estudio_programa_paginado` | F-COO-008 |
| `ConsultarGruposDecanoUseCaseImpl` (l.35-37) | HQL sobre `uv_grupo` | `usp_consultar_grupos_facultad_paginado` | F-DEC-002 |
| `ConsultarEstudiantesUseCaseImpl`, `ConsultarEstudiantePorIdUseCaseImpl` | A los pasa a SP | B2 ajusta la rama coordinador | F-COO-001/002 |

`InstitutionalScopePort` se conserva como defensa en profundidad (403 temprano), pero ya no es la fuente del ámbito de estas consultas.

### 3.4 OpenAPI golden path (WORM)

`AsistenciasUCO-Infra/docs/contracts/openapi/openapi-golden-path.yaml` (y su copia en el backend, que debe ser idéntica, DEC-005) pasa a **1.2.0 (CULM-001-B2)** con su `.sha256` regenerado en los dos repos. Cambios (solo descripción y respuestas; ningún schema de datos cambia):

| Operación | Cambio |
| :--- | :--- |
| `consultarEstudiantes` (`GET /api/v1/estudiantes`, l.171-260) | Descripción: el ámbito se aplica en el SP; COORDINADOR → estudiantes con `EstudiantePrograma` en sus programas; ADMINISTRADOR → su institución. `programaId` (l.237-240): "El estudiante tiene vínculo `EstudiantePrograma` con el programa" (antes "Algún contexto académico del estudiante pertenece al programa"). `programaId` fuera del ámbito → 403. Sigue sin envoltorio `exitoso/datos` |
| `consultarEstudiantesGrupo` (`GET /api/v1/grupos/{grupoId}/estudiantes`, l.124-170) | "Devuelve todos los estudiantes del grupo" pasa a: todos para DOCENTE titular y ADMINISTRADOR de la institución; para COORDINADOR, solo los que tienen `EstudiantePrograma` en sus programas. Se agrega `404` (grupo inexistente o fuera de ámbito, regla de A) |
| `consultarAsistenciasGrupo` (`GET /api/v1/grupos/{grupoId}/asistencias`, l.317-) | Misma regla de visibilidad para COORDINADOR; `404` |

`BACKEND_GOLDEN_PATH_CONTRACT.md` y `DB_BASELINE_CONTRACT.md` no cambian (la firma de `usp_crear_grupo` se conserva). Si A ya publicó una versión 1.1.x con sus cambios, B2 parte de ella y sube a la siguiente menor. La prueba de conformidad OpenAPI del backend se actualiza solo en estas tres descripciones y en los `404` añadidos.

### 3.5 Seguridad HTTP

`SecurityConfig` no abre rutas nuevas a roles nuevos: las rutas `/coordinador/**` siguen en COORDINADOR (y la lectura del decano que ya existe en planes), `/grupos/{id}/programas` en DOCENTE, COORDINADOR y DECANO, y la matriz de acceso (`access-catalog.json`) se actualiza con las rutas nuevas. El PEP del Security Baseline recibe las rutas nuevas en su catálogo; si ese catálogo lo administra el equipo de seguridad, se entrega la lista en `PRS.md` (§6.4).

### 3.6 Observabilidad

Los SP reciben `CorrelationIdContext.get()` como `@idCorrelacion`. Los casos de uso de asociar/desvincular registran un log estructurado `asignatura.plan.asociada` / `asignatura.plan.desvinculada` con `idAsignatura`, `idPlanEstudio`, `correlationId` (sin datos personales). La matrícula que crea un vínculo registra `estudiante.programa.vinculado` con el origen (`MANUAL`, `QR`).

### 3.7 Pruebas backend (RED)

| Tipo | Pruebas |
| :--- | :--- |
| Unitarias (100 % ramas en casos de uso y mappers nuevos) | `AsociarAsignaturaPlanUseCaseImplTest`, `DesvincularAsignaturaPlanUseCaseImplTest`, `ConsultarAsignaturasAsociablesUseCaseImplTest`, `ConsultarProgramasGrupoUseCaseImplTest`, `GestionarAsignaturaUseCaseImplTest` y `GestionarAsignaturaMapperTest` (+ `codigoCaracter`), `ConsultarAsignaturasPlan*Test`, `ConsultarPlanesEstudio*Test`, `ConsultarGruposDecanoUseCaseImplTest`, `ConsultarEstudiantesProgramaUseCaseImplTest`; `DbFailureClassifierAsignaturaPlanTest` (los 11 códigos de §2.8.1) |
| Controladores | `CoordinadorPortalControllerTest`: `DELETE .../asignaturas/{id}` ya no es 501 (200, 404, 409); `POST .../asignaturas-asociadas` 201/404/409/403; listados paginados; `programaId` ajeno 403. `DecanoPlanEstudioControllerTest` 404 con plan inexistente; `DecanoGrupoControllerTest` paginado; `DecanoFacultadConsultaControllerTest` `idGrupo` ajeno 404; `EstudianteControllerTest` (sobre A) `programaId` ajeno 403; `GrupoControllerTest` `/grupos/{id}/programas` |
| ArchUnit | Sin reglas nuevas: `JpaIsolationRulesTest`, `ControllersMustDependOnlyOnInputPortsTest` y `JpaRepositoryArchitectureRulesTest` deben pasar con los repositorios nuevos (ningún controlador ni clase de `application` importa `jpa/**`) |
| Paridad JPA / oráculos | `AcademicUserParityFixture`, `AcademicUserJdbcBaselineOracle`, `baseline/AsignaturaJdbcBaseline`, `baseline/PlanEstudioJdbcBaseline` se actualizan por el cambio formal de contrato (columnas de `uv_asignatura`, firmas con `@codigoCaracter`, HQL retirados); `AcademicQueryJpaParityIT`, `AcademicUserCommandsSpParityIT`/`SuccessParityIT`, `CoreViewQueriesJpaParityIT`, `SqlStoredProcedureContractIT` (firmas nuevas), `ViewEntityProjectionMappingTest` (columnas de vistas = campos de entidad), `AcademicViewJpaProjectionBehaviorTest`, `AsignaturaJpaCommandPatternTest`, `PlanEstudioJpaCommandPatternTest`, `PlanEstudioJpaRepositoryTest`, `ConsultasTransversalesJpaRepositoryTest`, `FacultadDecanoJpaRepositoryTest`, `EstudianteJpaQueryContractTest`, `LecturaPorFacultadJpaPatternTest`, `JpaQueryAdapterContractTest`, `UsuarioPlanEstudioProvidersSqlServerIT`, `DbFailureClassifierPlanEstudioTest` |
| Integración (`-Pintegration`) | `AsignaturaPlanEstudioSqlServerIT`: asociar/desvincular contra SQL Server con la semilla 34; `AmbitoGrupoMixtoSqlServerIT`: CA no recibe EB en `/grupos/{id}/estudiantes`, `/sesiones/{id}/asistencias`, `/coordinador/estudiantes`, KPIs |
| OpenAPI | Prueba de conformidad del golden path con la versión 1.2.0 y el `.sha256` nuevo |

---

## 4. Frontend

### 4.1 Modelos y servicios

| Archivo | Cambio |
| :--- | :--- |
| `core/models/role-management.model.ts:272-283` (`AsignaturaPlanItem`) | + `idSemestrePlanEstudio`, `codigoCaracter`, `nombreCaracter`, `compartida`, `programasCompartidos: string[]`, `estaActivoVinculo`; `semestre` = `numeroSemestre`; nuevos `AsignaturaAsociable`, `CaracterAsignatura`, `ProgramaResumen` |
| `core/api/models/oferta-creacion-grupos-docente-api-dto.model.ts`, `asignatura-docente-api-dto.model.ts`, `estudiante-api-dto.model.ts`, `docente-api-dto.model.ts`, `core/models/consultas-transversales.model.ts` | Campos de §3.1 (`programas`, `planes`, `totalPlanes`, `codigoCaracter`); sin `any` |
| `core/services/coordinator-management.service.ts` | `normalizarAsignaturaPlan` (l.78-88) y `aSolicitudAsignatura` (l.96-105, + `codigoCaracter`); nuevos `asociarAsignaturaPlan`, `buscarAsignaturasAsociables`, `getCaracteresAsignatura`; `desvincularAsignaturaPlan` (DELETE, l.352) ya existe y ahora responde 200; listados de planes, asignaturas y estudiantes paginados (`ApiPageResponse`) con `programaId` opcional; `getEstudiantes` del coordinador pasa de `/api/v1/estudiantes` (l.489) a `/coordinador/estudiantes` |
| `core/services/dean-facultad.service.ts` | Malla paginada, grupos paginados, `idGrupo` en sesiones |
| `core/services/oferta-academica.service.ts`, `group.service.ts`, `course.service.ts` | Carácter en la oferta; `getProgramasGrupo(idGrupo)`; `idPrograma` en la matrícula manual; `idProgramaPorDefecto` al abrir la ventana QR |
| `core/interceptors/mock-backend.interceptor.ts`, `core/mocks/{role-management.mock, mock-consultas-transversales}.ts` | Datos de ejemplo con una asignatura compartida y carácter |

### 4.2 Componentes

Todos `changeDetection: ChangeDetectionStrategy.OnPush`, `input()`/`output()`/`model()`, estado en `signal`/`computed`, sin `setInterval`, sin `localStorage`, errores por `getApiErrorMessage` (texto del backend), etiquetas accesibles en filtros nuevos (F-COO-010 en los controles que B2 toca).

| Componente | Cambio |
| :--- | :--- |
| `features/coordinator/coordinator-study-plans/coordinator-study-plans.component.ts`, `components/study-plans-list.component.ts` | Lista paginada (`PaginationComponent`); totales obligatorias/optativas |
| `components/subject-form.component.ts` (+ `pages/subject-form-page.component.ts`) | Select **Carácter** requerido (catálogo); semestre del plan (l.39-59, 159-160) se conserva; en edición de una compartida muestra el aviso "Compartida con …" y deshabilita campos de catálogo si el backend responde `ASI_006` (se muestra el mensaje; no se infiere en cliente) |
| `components/associate-subject-dialog.component.ts` (**nuevo**) | Flujo "Asociar asignatura existente": búsqueda paginada (`asignaturas-asociables`), elegir semestre del plan y carácter, confirmar; emite `asociada` |
| `components/study-plan-mesh.component.ts`, `pages/study-plan-mesh-page.component.ts` | Por semestre: insignia Obligatoria/Optativa, chip "Compartida con N programas" (tooltip con `programasCompartidos`); botones "Nueva asignatura" y "Asociar asignatura existente"; "Quitar del plan" con el modal de confirmación del sistema de diseño en lugar de `confirm()` (l.187-200, F-COO-011) llamando al DELETE |
| `features/coordinator/coordinator-subjects/coordinator-subjects.component.ts` | Una fila por (asignatura, plan); `irAMallaPlan(asig.planEstudioId)` (l.288) usa el plan de la fila; paginado; filtro por programa si coordina varios |
| `features/coordinator/coordinator-students/coordinator-students.component.ts` (l.244) | Consume `/coordinador/estudiantes` paginado; filtro por programa (S4); columna "Programas" |
| `features/coordinator/coordinator-groups`, pantallas de sesiones/asistencias del coordinador | Sin cambio de lógica: muestran lo que devuelve el backend (ya filtrado); rótulo "Estudiantes de tu programa: n de m" con `estudiantesPrograma`/`estudiantesGrupo` |
| KPIs del coordinador | Selector de programa cuando el backend responde `COO_002` (el componente muestra el mensaje y el selector con los programas del coordinador) |
| `features/dean/dean-plan-malla/dean-plan-malla.component.ts` | Malla paginada con carácter y chip de compartida; 404 → estado "Plan no encontrado" |
| `features/dean/dean-asignaturas/dean-asignaturas.component.ts` (l.109) | "Plan {{ inpPlanEstudio }}" → lista de `planes` |
| `features/dean/dean-grupos` / `dean-grupo-detalle` | Grupos paginados; sesiones filtradas por `idGrupo` en servidor (deja de filtrar en cliente, F-DEC-003/014) |
| KPIs del decano (`features/dean/dean-indicators`) | Rótulos "Sesiones ejecutadas" vs "Sesiones evaluadas por matrícula" y "Matrículas activas" vs "Estudiantes" (F-DEC-013); comparativa por programa con la nota de R9 |
| `features/student/student-group-offer/student-group-offer.component.ts` | Insignia Obligatoria/Optativa en "propias"; sin duplicados (lo garantiza el backend) |
| `features/teacher/teacher-grupos/**/teacher-matricula-modal.component.ts`, `teacher-grupo-estudiantes.component.ts` | Si `getProgramasGrupo` devuelve más de uno, select **Programa del estudiante** (opcional; requerido cuando el backend responde `EST_005`) |
| Modal de apertura de la ventana QR de matrícula (HU176B) | Select "Programa para estudiantes nuevos" visible solo si el grupo tiene varios programas |
| Pantalla pública de matrícula por QR | Si `requiereProgramaDocente`, muestra el mensaje del backend antes del formulario |
| Oferta de creación de grupos del docente (`teacher-grupo-form.component.ts`) | Muestra `programas` de la asignatura |

### 4.3 Flujos de usuario

1. **Asociar asignatura existente a un plan (coordinador):** Malla del plan → "Asociar asignatura existente" → buscar por código o nombre (solo asignaturas de la institución no asociadas al plan) → elegir semestre del plan y carácter → Asociar → la malla se recarga y la asignatura aparece con el chip "Compartida". Errores: `ASI_003` (ya asociada), `PLA_004` (semestre inexistente).
2. **Crear asignatura nueva:** Malla → "Nueva asignatura" → código, nombre, créditos, área, componente, semestre y **carácter** → Guardar. Si el código existe, el backend responde `ASI_002` y la UI muestra el mensaje; el botón "Asociar asignatura existente" está siempre visible al lado.
3. **Cambiar carácter o semestre en un plan:** editar desde la malla; en una compartida solo cambian semestre y carácter de ese plan (S2).
4. **Quitar del plan:** "Quitar del plan" → modal de confirmación → DELETE; `ASI_005` explica por qué no se puede.

### 4.4 Rutas

Sin rutas nuevas (`app.routes.ts` l.342-387 se conservan); el diálogo de asociación vive dentro de la malla. `decano/programas/:planId` (l.228) y `decano/asignaturas` (l.293) se conservan.

### 4.5 Pruebas frontend (RED)

- Nuevas: `associate-subject-dialog.component.spec.ts` (búsqueda, paginación, selección, error 409, accesibilidad de etiquetas).
- Actualizadas por el cambio de contrato (las 15 specs que citan `planEstudioId`/`idPlanEstudio`/`semestre`, investigación §4): `subject-form.component.spec.ts` (carácter requerido), `study-plan-mesh.component.spec.ts` (insignias, chip, modal en vez de `confirm`), `coordinator-study-plans.component.spec.ts`, `coordinator-subjects.component.spec.ts` (fila por plan), `coordinator-students.component.spec.ts` (endpoint y paginación), `dean-asignaturas.component.spec.ts`, `dean-plan-malla.component.spec.ts` (404), `student-group-offer.component.spec.ts`, `teacher-matricula-modal.component.spec.ts` (selector de programa), `coordinator-management.service.spec.ts` (l.690 y nuevos métodos), `mock-backend.interceptor.spec.ts`.
- `npm run verify` en verde (incluye el gate realtime, que B2 no toca).

---

## 5. Docs, orden de integración, ramas y commits

### 5.1 Documentación

| Documento | Cambio |
| :--- | :--- |
| `AsistenciasUCO-Infra/docs/user-stories/HU-CATALOG.md` | HU075, HU084, HU108, HU008, HU076B, HU085, HU087, HU065/066/070, HU068, HU102/106, HU144: estado y nota "N:M por `AsignaturaPlanEstudio`; ámbito por `EstudiantePrograma`" |
| `AsistenciasUCO-Infra/docs/contracts/openapi/openapi-golden-path.yaml` + `.sha256` (Infra y Backend) | 1.2.0 (§3.4) |
| `AsistenciasUCO-Infra/docs/baseline/TECHNICAL_DEBT.md` | TD nueva: reactivación de un vínculo conserva `fechaVinculacionUtc` (§6.3); TD nueva si queda algún `AMBIGUO` sin resolver |
| `GestioAsistenciaDB/docs/contracts/DB_UTC_D06_POST_FREEZE_MANIFEST.sha256` | Sin cambio (no se toca ningún archivo del manifiesto); se verifica con `freeze-manifest.ps1 -Mode Verify` |
| `docs/arquitectura-integral.md` (workspace) | Modelo `Asignatura` ↔ `AsignaturaPlanEstudio` ↔ `SemestrePlanEstudio` y regla R6 |
| `CULM-001-culminacion/DECISIONES.md` | Registrar S1–S4 si la revisión los aprueba (DEC-0xx, paquete B2) |

### 5.2 Orden de integración

1. Requisitos: A y B mezclados en `integracion/CULM-001`. B2 rebasa sobre ellos y edita **sus** versiones de `usp_registrar_estudiante_en_grupo_interno` (A, DEC-009), del SP del directorio de estudiantes y de los casos de uso de grupos (A), y de `uv_resumen_asistencia_estudiante_grupo` / `uv_cumplimiento_sesion_grupo` (B, DEC-012/DEC-016).
2. **DB** (`feature/CULM-001-B2-asignaturas-nm`): RED (pruebas nuevas fallando + arrange de las 31 actualizado) → GREEN (tablas, semillas, funciones, vistas, SPs, permisos, migración) → `infra.ps1 db-deploy` sobre BD limpia **y** `up` sobre la BD local con backup COPY_ONLY previo → `infra.ps1 db-test`.
3. **Backend** (misma rama en su repo): entidades, repositorios, casos de uso, controladores, clasificador, OpenAPI → `mvnw verify` y `-Pintegration`.
4. **Frontend**: modelos, servicios, componentes, specs → `npm run verify`.
5. **Infra**: HU-CATALOG, contrato OpenAPI y hashes, deuda técnica → `.\AsistenciasUCO-Infra\infra.ps1 verify` (paridad cross-repo del golden path).
6. AUDIT: matriz de fugas con la semilla 34 (dos programas) para coordinador, decano, docente y estudiante; recorrido de pantalla de la malla.
7. PRs hacia `integracion/CULM-001`: DB y Backend en `johnjduque/gestion-asistencia-db` y `alejovh12/AsistenciasUCO` (DEC-002), Frontend en `shesho22/AsistenciasUCO-Frontend`, Infra en `AsistenciasUCO/AsistenciasUCO-Infra`; se registran en `PRS.md`. Se mezclan en el orden DB → Backend → Frontend → Infra; ningún despliegue mezcla un backend viejo con la BD nueva (las columnas retiradas de `uv_asignatura` lo romperían).

### 5.3 Commits (Conventional Commits, atómicos por capa, `Refs:` de las HU)

DB:
1. `test(db): agregar pruebas red de asignatura en varios planes y ambito mixto` (T-B2-01..14; `Refs: HU075, HU084, HU108, HU008, HU087`)
2. `test(db): actualizar arrange de pruebas al vinculo asignatura-plan` (31 archivos; cuerpo con la justificación de cambio formal de contrato)
3. `feat(db/tables): agregar AsignaturaPlanEstudio y catalogo de caracter`
4. `feat(db/views): resolver programa del grupo por la tabla puente`
5. `feat(db/sp): asociar, desvincular y consultar asignaturas por plan`
6. `fix(db/sp): resolver ambito del coordinador por EstudiantePrograma` (`Refs: F-COO-006, F-COO-008`)
7. `feat(db/sp): exigir vinculo de programa en la matricula manual y QR`
8. `feat(db/seed): sembrar segundo programa con optativa compartida`
9. `feat(db): migracion up/down de asignaturas N:M con backfill de vinculos` (`BREAKING CHANGE: se elimina Asignatura.semestrePlanEstudio y cambian las columnas de uv_asignatura`)

Backend:
1. `test(backend): agregar pruebas red de asignaturas por plan y ambito mixto`
2. `feat(backend/adapter): repositorio de asignaturas por plan sobre SP`
3. `feat(backend/usecase): asociar y desvincular asignaturas del plan`
4. `refactor(backend/adapter): mover consultas del coordinador y decano a SP paginados` (`Refs: F-COO-008, F-DEC-002`)
5. `feat(backend/controller): endpoints de asociacion, desvinculacion y paginacion` (`Refs: F-COO-005, F-DEC-014, F-DEC-015`)
6. `docs(backend): sincronizar openapi golden path 1.2.0`

Frontend:
1. `test(frontend): actualizar specs de malla y listados al contrato N:M`
2. `feat(frontend/coordinador): asociar asignatura existente y caracter en la malla`
3. `feat(frontend/decano): malla y asignaturas con planes compartidos`
4. `feat(frontend/docente): seleccionar programa en matricula de grupos mixtos`
5. `feat(frontend/estudiante): mostrar caracter en la oferta de grupos`

Infra:
1. `docs(contracts): publicar openapi golden path 1.2.0 de CULM-001-B2`
2. `docs(hus): actualizar HUs de malla, oferta y ambito por relacion`

Todos terminan con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

## 6. Riesgos, rollback y puntos abiertos

### 6.1 Riesgos

| # | Riesgo | Mitigación |
| :--- | :--- | :--- |
| 1 | Duplicación de filas por el join 1:N (`uv_grupo_programa`) en KPIs, aforo, consolidado, paginación (`COUNT(*) OVER()`) | `uv_asignatura` queda como catálogo (1:1), `uv_cumplimiento_sesion_grupo` y `uv_resumen_asistencia_estudiante_grupo` pierden `idPrograma`; consumidores con `EXISTS`/`DISTINCT`; T-B2-03 y T-B2-07 fijan la cardinalidad con una asignatura compartida |
| 2 | Vista congelada `uv_estudiante_grupo` alterada por cambio de cardinalidad | No se toca; depende de `uv_grupo`, que sigue 1:1; T-B2-03 + `freeze-manifest.ps1 -Mode Verify` |
| 3 | Estudiantes invisibles para coordinadores (sin vínculo o `AMBIGUO`) | Backfill + R7 en matrícula; reporte y script de resolución; T-B2-11; el docente siempre los ve |
| 4 | Fuga entre coordinadores en grupos mixtos por algún SP no revisado | Lista exhaustiva de §2.7.2 construida desde los consumidores de `uv_grupo_programa`, `uv_resumen_*` y `uv_estudiante`; AUDIT con la matriz de fugas sobre la semilla 34; `ufn_estudiantes_grupo_visibles` como único filtro |
| 5 | Migración destructiva (`DROP COLUMN`) | Backup COPY_ONLY previo; `down` probado (T-B2-12); `down` aborta sin cambios si hay datos N:M |
| 6 | Conflictos con A y B (mismos objetos) | B2 empieza después de mezclar A y B; §5.2 lista los objetos compartidos; los mensajes y números de migración se verifican antes del RED |
| 7 | Desajuste BD nueva / backend viejo | Integración simultánea DB → Backend en la misma ventana; sin despliegue parcial |
| 8 | Volumen del cambio (≈19 SP con join directo + ≈17 por vistas, ≈12 repositorios, ≈15 componentes) frente a la fecha del 2026-11-13 | Orden de prioridad del PLAN del work item: si falta tiempo, se entregan primero BD + backend del ámbito (R6–R9) y la asociación; la UI de asociación puede ir al final del paquete |
| 9 | Un estudiante de A matriculado en una asignatura solo de B pasa a tener vínculo con B (R7) y aparece en el directorio de B | Consecuencia directa de DEC-020 ("exigen o crean el vínculo"); se documenta en HU-CATALOG; para evitarlo, la asignatura debe asociarse también al plan de A (flujo 4.3.1) |

### 6.2 Rollback

- **BD:** `NN_..._down.sql` (precondición 1:1) o restauración del backup COPY_ONLY tomado justo antes del `up` (obligatorio en la BD local y en cualquier entorno compartido).
- **Backend y frontend:** revertir los PRs de B2 en `integracion/CULM-001` (DB, Backend, Frontend e Infra juntos, en orden inverso).
- **Contrato:** volver a la versión anterior del golden path y su `.sha256` en los dos repos.

### 6.3 Limitaciones aceptadas

- Reactivar un vínculo conserva su `fechaVinculacionUtc`: los grupos creados durante la baja se consideran del programa (TD nueva).
- La comparativa por programa puede sumar más estudiantes que el total de la facultad (R9); se rotula.
- `uv_estudiante.idPlanEstudio` elige de forma determinista el plan de mayor `inp` cuando el programa tiene varios planes activos con la asignatura.

### 6.4 Puntos abiertos para la revisión

1. Aprobar S1–S4 (§1.2) o sustituirlos antes de congelar.
2. ¿Un coordinador puede asociar una asignatura cuyo único vínculo es de otro programa de **otra facultad** de la misma institución? El contrato lo permite (catálogo institucional); alternativa: limitar a su facultad.
3. Usuarios de prueba para el segundo coordinador y su estudiante en el realm `security-baseline` (`uco-coordinador-2`, `uco-estudiante-2`): el realm lo administra el equipo de seguridad; sin ellos, la matriz de fugas con dos programas se prueba por API con tokens de los usuarios existentes reasignados en BD solo en la semilla de pruebas, o se documenta como limitación.
4. Catálogo del PEP (Security Baseline) con las rutas nuevas: confirmar si lo actualiza este equipo o se entrega al equipo de seguridad.
5. Si el CONTRACT de A no mueve `/api/v1/estudiantes` a SP, B2 asume ese trabajo completo (aumenta el alcance).
