# CONTRACT MATRIX — LB-002.1C-B1: registrarEstudianteEnGrupo

Formulario del protocolo de alineacion contractual entre DB y Backend.

## Evidencia

| Sistema | Repo/version | Archivo/objeto | Hash/commit | Autoridad |
|---|---|---|---|---|
| DB | `GestioAsistenciaDB` (branch `sergio`) | `schema/stored-procedures/usp_registrar_estudiante_en_grupo.sql` | HEAD `bc6aae0` | OWNER del contrato de persistencia |
| Backend | `GestioAsistenciaBackend` (branch `develop`) | `GrupoRepositorySqlServerAdapter.java:95` | HEAD `0bfc02a` | CONSUMER |

## Matriz de Parametros

| # | Parametro DB (`usp_registrar_estudiante_en_grupo`) | Tipo SQL | Parametro Backend Actual | Tipo Java | Estado | Accion requerida |
|---|---|---|---|---|---|---|
| 1 | `@idGrupo` | `UNIQUEIDENTIFIER` | `:idGrupo` | `UUID` | MATCH | Mantener |
| 2 | `@numeroIdentificacion` | `INT` | `:numeroIdentificacion` | `Integer` | MATCH | Mantener |
| 3 | `@primerNombre` | `NVARCHAR(50)` | `:primerNombre` | `String` | MATCH | Mantener |
| 4 | `@segundoNombre` | `NVARCHAR(50)` | `:segundoNombre` | `String` | MATCH | Mantener (permite null/vacio) |
| 5 | `@primerApellido` | `NVARCHAR(50)` | `:primerApellido` | `String` | MATCH | Mantener |
| 6 | `@segundoApellido` | `NVARCHAR(50)` | `:segundoApellido` | `String` | MATCH | Mantener (permite null/vacio) |
| 7 | `@correo` | `NVARCHAR(100)` | `:correo` | `String` | MATCH | Mantener |
| 8 | `@password` | `NVARCHAR(500)` | `:password` | `String` | MATCH | Mantener |
| 9 | `@idCorrelacion` | `UNIQUEIDENTIFIER` | `:idCorrelacion` | `UUID` | MATCH | Mantener |
| 10| `@idUsuarioEjecutor` | `UNIQUEIDENTIFIER` | (NO ENVIADO) | `UUID` | MISSING_IN_CONSUMER | Agregar en DTO y parametro JDBC |
| --| `@idTipoIdIdentificacion` | NO EXISTE EN DB | `:idTipoIdIdentificacion` | `UUID` | MISSING_IN_PROVIDER | Retirar de la llamada SQL en adapter |

## Conflicto Semantico y de Autorizacion (DECISION_REQUIRED)

- **Comportamiento en DB actual:**
  El paso 1.5 del SP ejecuta:
  `EXEC dbo.usp_validar_permiso_rbac_usuario_interno @idUsuario = @idUsuarioEjecutor, @codigoPerfilRequerido = 'ESTUDIANTE'`.
  Si el ejecutor no es ESTUDIANTE, retorna error `SEC_001`.
- **Regla Institucional UCO (AGENTS.md seccion 3.3):**
  La matricula manual es potestad del **Docente titular**, **Coordinador** o **Administrador**.
- **Opciones de resolucion:**
  - **Opcion 1 (Ajuste en BD):** Modificar el SP en BD para que acepte que `@idUsuarioEjecutor` sea el DOCENTE titular del grupo, un COORDINADOR o ADMINISTRADOR (o perfil ESTUDIANTE en auto-matricula).
  - **Opcion 2 (Workaround en Backend):** Enviar el ID del propio estudiante como ejecutor si ya existe, lo cual contradice la auditoria cuando un docente es quien realiza la accion.
  - **Recomendacion:** Opcion 1.
