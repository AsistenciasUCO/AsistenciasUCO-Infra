SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- 1. Asegurar que el Programa apunte al Coordinador Real Institucional (Andrés López)
UPDATE dbo.Programa
SET coordinador = 'f1a2b3c4-0000-0000-0000-000000000002'
WHERE id = 'b2c3d4e5-0000-0000-0000-000000000001';

-- 2. Eliminar horarios de grupos de prueba
DELETE FROM dbo.Horario 
WHERE grupo IN (SELECT id FROM dbo.Grupo WHERE nombre LIKE '%Test%');

-- 3. Eliminar grupos de prueba
DELETE FROM dbo.Grupo 
WHERE nombre LIKE '%Test%';

-- 4. Eliminar coordinadores de prueba
DELETE FROM dbo.Coordinador 
WHERE usuario IN (SELECT id FROM dbo.Usuario WHERE correo LIKE 'coord.10%');

DELETE FROM dbo.Usuario 
WHERE correo LIKE 'coord.10%';

-- 5. Eliminar docentes de prueba
DELETE FROM dbo.Docente 
WHERE usuario IN (SELECT id FROM dbo.Usuario WHERE correo LIKE 'docente.test%');

DELETE FROM dbo.Usuario 
WHERE correo LIKE 'docente.test%';

-- 6. Eliminar facultades de prueba
DELETE FROM dbo.Facultad 
WHERE id <> 'a2b3c4d5-0000-0000-0000-000000000001';

-- 7. Enrolar estudiantes institucionales en Grupo 02 si existen
DECLARE @idGrupo2 UNIQUEIDENTIFIER = 'de8a9d2d-65fc-4415-8b9e-47fab30a9091';
DECLARE @estadoA UNIQUEIDENTIFIER = (SELECT TOP 1 id FROM dbo.EstadoEstudianteGrupo WHERE codigo = 'A');

IF EXISTS (SELECT 1 FROM dbo.Grupo WHERE id = @idGrupo2) AND @estadoA IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Estudiante WHERE id = 'F1A2B3C4-0000-0000-0000-000000000004')
       AND NOT EXISTS (SELECT 1 FROM dbo.EstudianteGrupo WHERE grupo = @idGrupo2 AND estudiante = 'F1A2B3C4-0000-0000-0000-000000000004')
        INSERT INTO dbo.EstudianteGrupo (id, estudiante, grupo, estado)
        VALUES (NEWID(), 'F1A2B3C4-0000-0000-0000-000000000004', @idGrupo2, @estadoA);

    IF EXISTS (SELECT 1 FROM dbo.Estudiante WHERE id = 'F1A2B3C4-0000-0000-0000-000000000007')
       AND NOT EXISTS (SELECT 1 FROM dbo.EstudianteGrupo WHERE grupo = @idGrupo2 AND estudiante = 'F1A2B3C4-0000-0000-0000-000000000007')
        INSERT INTO dbo.EstudianteGrupo (id, estudiante, grupo, estado)
        VALUES (NEWID(), 'F1A2B3C4-0000-0000-0000-000000000007', @idGrupo2, @estadoA);

    IF EXISTS (SELECT 1 FROM dbo.Estudiante WHERE id = 'F1A2B3C4-0000-0000-0000-000000000008')
       AND NOT EXISTS (SELECT 1 FROM dbo.EstudianteGrupo WHERE grupo = @idGrupo2 AND estudiante = 'F1A2B3C4-0000-0000-0000-000000000008')
        INSERT INTO dbo.EstudianteGrupo (id, estudiante, grupo, estado)
        VALUES (NEWID(), 'F1A2B3C4-0000-0000-0000-000000000008', @idGrupo2, @estadoA);
END;

-- 8. Actualizar cupos y contadores en Grupo (Añade margen de 40 cupos disponibles para pruebas)
UPDATE g
SET g.cantidadEstudiantes = (SELECT COUNT(1) FROM dbo.EstudianteGrupo eg WHERE eg.grupo = g.id) + 40
FROM dbo.Grupo g;

-- 9. Resumen de Verificación
SELECT 'Usuarios Institucionales' AS Entidad, COUNT(1) AS TotalRegistros FROM dbo.Usuario
UNION ALL
SELECT 'Grupos Oficiales', COUNT(1) FROM dbo.Grupo
UNION ALL
SELECT 'Facultades Oficiales', COUNT(1) FROM dbo.Facultad
UNION ALL
SELECT 'Franjas de Horarios', COUNT(1) FROM dbo.Horario
UNION ALL
SELECT 'Estudiantes en Grupos', COUNT(1) FROM dbo.EstudianteGrupo;

COMMIT TRANSACTION;
