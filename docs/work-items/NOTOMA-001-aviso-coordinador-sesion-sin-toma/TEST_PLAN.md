# TEST_PLAN - NOTOMA-001

## DB (test/test_notoma_aviso_sin_toma.sql, T-SQL transaccional revertido; ids en test_summary.ps1)
- NOTOMA_00_OBJETOS: tabla, 3 parametros no editables, 3 SP, plantilla con 8 marcadores, EXECUTE al rol runtime.
- NOTOMA_01_PENDIENTES: entra la sesion terminada sin tomas; no entran con tomas, con asistencia, cancelada, en curso, mas antigua que el atraso, ya avisada ni con solicitud pendiente; el lote limita.
- NOTOMA_02_DESTINATARIOS: coordinadores de cada programa del grupo compartido, una fila por persona; excluye coordinador inactivo o sin correo; 0 filas si la sesion tiene tomas o esta cancelada.
- NOTOMA_03_REGISTRAR_IDEMPOTENTE: una sola marca; el segundo registro es exito sin escribir; la sesion sale de las pendientes.
- NOTOMA_04_SESION_INEXISTENTE: SES_001 y GEN_002 sin escribir.
- NOTOMA_05_HABILITADO_FALSE y NOTOMA_06_ATRASO_MAXIMO.
- NOTOMA_TRANCOUNT_ZERO. Migracion: up -> down -> up.

## Backend (JUnit, sin BD)
- Caso de uso: una notificacion por sesion con todos los coordinadores; datos y asunto; hora institucional; enlace con y sin URL; sin destinatarios marca 0; fallo al encolar no marca; fallo de consulta o marca no propaga; varias sesiones.
- Adaptador JPA: columnas por nombre, correlacion, comando canonico, errores.
- Scheduler: el paso corre despues del aviso de faltas y su fallo no se propaga.
- Plantilla por defecto y marcadores; ArchUnit existentes y JaCoCo (LINE >= 80, BRANCH >= 70) sin regresion.
