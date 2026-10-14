# CONTRACT SPECIFICATION — LB-002.1C-B1: registrarEstudianteEnGrupo

## 1. Identidad y Autoridad
- **Work Item:** LB-002.1C-B1
- **Fecha:** 2026-09-28
- **Estado:** FORMALIZED (CONTRACT_FROZEN)
- **Ámbito:** Persistencia (`GestioAsistenciaDB`) y Adaptador Secundario (`GestioAsistenciaBackend`).

---

## 2. Definición Contractual del SP Público

### 2.1 Nombre Canónico
`dbo.usp_registrar_estudiante_en_grupo`

### 2.2 Firma Unificada y Tipado de Parámetros

| Parámetro | Tipo SQL | Nullable / Default | Descripción |
| :--- | :--- | :--- | :--- |
| `@idGrupo` | `UNIQUEIDENTIFIER` | No | ID del grupo en el que se inscribirá el estudiante. |
| `@numeroIdentificacion` | `INT` | No | Número de documento de identidad del estudiante. |
| `@primerNombre` | `NVARCHAR(50)` | No | Primer nombre. |
| `@segundoNombre` | `NVARCHAR(50)` | Sí (`NULL`) | Segundo nombre (opcional). |
| `@primerApellido` | `NVARCHAR(50)` | No | Primer apellido. |
| `@segundoApellido` | `NVARCHAR(50)` | Sí (`NULL`) | Segundo apellido (opcional). |
| `@correo` | `NVARCHAR(100)` | No | Correo institucional del estudiante. |
| `@password` | `NVARCHAR(500)` | No | Hash o credencial inicial del usuario. |
| `@idCorrelacion` | `UNIQUEIDENTIFIER` | No | Identificador de correlación para trazabilidad distribuida. |
| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | No | ID del usuario autenticado que ejecuta la operación. |
| `@idTipoIdIdentificacion` | `UNIQUEIDENTIFIER` | Sí (`DEFAULT NULL`) | ID del tipo de identificación en `dbo.TipoIdentificacion`. Si es `NULL`, se asume `'CC'`. |

---

## 3. Reglas de Negocio y Autorización (RBAC)

1. **Resolución del Tipo de Identificación:**
   - Si `@idTipoIdIdentificacion IS NOT NULL`: Se valida su existencia en `dbo.TipoIdentificacion` y se utiliza para sincronizar el usuario.
   - Si `@idTipoIdIdentificacion IS NULL`: Se consulta el tipo `'CC'` (Cédula de Ciudadanía) por defecto como fallback seguro.

2. **Validación de Ejecutor y Autorización:**
   - `@idUsuarioEjecutor` es **OBLIGATORIO** (`GEN_002` si es `NULL`).
   - El ejecutor debe tener uno de los siguientes roles institucionales válidos:
     * **`DOCENTE`**: Debe ser el titular asignado al `@idGrupo` (matrícula manual en aula).
     * **`COORDINADOR`**: Debe coordinar el programa al que pertenece la asignatura del grupo.
     * **`ADMINISTRADOR`**: Autorización global institucional.
     * **`ESTUDIANTE`**: Únicamente autorizado si se trata de auto-enrolamiento (el ID del ejecutor corresponde al estudiante matriculado).
   - En caso de no cumplir la condición de autorización, retorna `SEC_001` (perfil inválido) o `SEC_002` (falta de titularidad sobre el grupo).

3. **Invariante de Capacidad y Atomicidad Transaccional:**
   - Se valida el cupo del grupo (`usp_validar_cupo_disponible_grupo_interno`) **antes** de cualquier inserción en `dbo.Usuario` o `dbo.Estudiante`.
   - Si no hay cupo disponible, se rechaza inmediatamente con `ERR_CUPO_SUPERADO` sin crear registros huérfanos.
   - Toda la operación se ejecuta bajo control transaccional explícito `SET XACT_ABORT ON; BEGIN TRANSACTION ... COMMIT / ROLLBACK`.

---

## 4. Estructura de Respuesta Unificada

Conforme al estándar del `DB_BASELINE_CONTRACT.md`, el procedimiento retorna exactamente una fila con las 4 columnas canónicas:

1. `idCorrelacion` (`UNIQUEIDENTIFIER`)
2. `mensajeUsuarioResultado` (`NVARCHAR`)
3. `mensajeTecnicoResultado` (`NVARCHAR`) en formato contractual `DBCODE=<catalog-code>|<detalle>`
4. `estadoResultado` (`BIT`)

---

## 5. Mapeo en Backend (`GestioAsistenciaBackend`)

En `GrupoRepositorySqlServerAdapter`:
```java
MapSqlParameterSource parameters = new MapSqlParameterSource()
    .addValue("idGrupo", dto.idGrupo())
    .addValue("numeroIdentificacion", dto.numeroIdentificacion())
    .addValue("primerNombre", dto.primerNombre())
    .addValue("segundoNombre", dto.segundoNombre())
    .addValue("primerApellido", dto.primerApellido())
    .addValue("segundoApellido", dto.segundoApellido())
    .addValue("correo", dto.correo())
    .addValue("password", dto.password())
    .addValue("idCorrelacion", dto.idCorrelacion())
    .addValue("idUsuarioEjecutor", dto.idUsuarioEjecutor())
    .addValue("idTipoIdIdentificacion", dto.idTipoIdIdentificacion());
```
