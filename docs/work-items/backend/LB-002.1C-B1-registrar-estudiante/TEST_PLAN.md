# TEST_PLAN — LB-002.1C-B1: registrarEstudianteEnGrupo

Fase 03-tester-red / 04-implementador.

## 1. Alcance de Pruebas

Verificar la adaptacion de la invocacion de persistencia de registro de estudiantes en grupo:
1. Reemplazo del SP deprecado dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente por el SP canonico de DB dbo.usp_registrar_estudiante_en_grupo.
2. Supresion del parametro no existente en BD @idTipoIdIdentificacion.
3. Inyeccion y propagacion del parametro obligatorio @idUsuarioEjecutor (UUID) desde la autenticacion HTTP hasta el adaptador JDBC.
4. Ajuste en BD en el procedimiento almacenado dbo.usp_registrar_estudiante_en_grupo para validar RBAC permitiendo perfiles de Docente, Coordinador y Administrador institucional ademas de Estudiante.

## 2. Casos de Prueba Unitarios y de Integracion

- **GrupoRepositorySqlServerAdapterTest:**
  - registrarEstudiante_ejecuta_procedimiento_canonico_y_retorna_proyeccion: verifica invocacion a dbo.usp_registrar_estudiante_en_grupo, ausencia de @idTipoIdIdentificacion, presencia de @idUsuarioEjecutor y los 10 parametros exactos.
  - registrarEstudiante_propaga_error_de_negocio_del_ejecutor_canonico: verifica manejo estricto de excepciones de negocio (ConflictException).
- **Mappers y Dominio:**
  - RegistrarEstudianteHttpMapperTest: mapeo de HTTP request + usuarioEjecutor a DTO de aplicacion.
  - RegistrarEstudianteDomainTest: construccion valida con usuarioEjecutor.
  - RegistrarEstudianteUseCaseImplTest: orquestacion del caso de uso.
  - RegistrarEstudianteRepositoryMapperTest: mapeo hacia DTO de persistencia.
- **Contratos:**
  - SqlStoredProcedureContractIT: firma actualizada con 10 parametros canonicos.
