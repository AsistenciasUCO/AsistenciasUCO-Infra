-- ==============================================================================
-- 🏛️ ASISTENCIAS UCO - SCRIPT DE HARDENING DE MÍNIMO PRIVILEGIO (SQL SERVER)
-- ==============================================================================
-- Propósito: Implementar el principio de mínimo privilegio (Least Privilege)
--            creando el usuario de aplicación 'app_asistencias_user'.
--
-- Reglas de Seguridad Institucionales UCO:
--  1. La aplicación Spring Boot NUNCA debe conectarse como 'sa' en producción.
--  2. La aplicación solo tiene permisos para ejecutar Procedimientos Almacenados (EXECUTE).
--  3. La aplicación solo puede leer datos a través de Vistas de consulta (SELECT).
--  4. Se deniega terminantemente la manipulación directa de tablas (INSERT/UPDATE/DELETE).
-- ==============================================================================

USE [master];
GO

SET XACT_ABORT ON;
GO

-- 1. Crear Base de Datos si no existe con la intercalación institucional
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'gestionasistenciadb')
BEGIN
    CREATE DATABASE [gestionasistenciadb]
    COLLATE Modern_Spanish_CI_AS;
    PRINT 'Base de datos [gestionasistenciadb] creada con collation Modern_Spanish_CI_AS.';
END
GO

-- 2. Crear (o sincronizar) el Login a nivel de Servidor
-- La contraseña NO está en este archivo: llega como variable de sqlcmd $(APP_DB_PASSWORD_TSQL), que deploy-schema.ps1
-- toma de APP_DB_PASSWORD (.env de Infra, generado por init-env) con las comillas simples ya duplicadas, y pasa por el
-- entorno del proceso (no por la línea de comandos). __SIN_CLAVE__ = no hay APP_DB_PASSWORD: no se crea ni se toca el
-- login y solo se aplican el rol y los permisos. Si el login ya existe se le asigna la contraseña actual, para que coincida con el .env.
IF N'$(APP_DB_PASSWORD_TSQL)' = N'__SIN_CLAVE__'
BEGIN
    PRINT 'APP_DB_PASSWORD no definida: se omite el login [app_asistencias_user] (solo rol y permisos).';
END
ELSE IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'app_asistencias_user')
BEGIN
    CREATE LOGIN [app_asistencias_user]
    WITH PASSWORD = N'$(APP_DB_PASSWORD_TSQL)',
         DEFAULT_DATABASE = [gestionasistenciadb],
         CHECK_EXPIRATION = OFF,
         CHECK_POLICY = ON;
    PRINT 'Login a nivel de servidor [app_asistencias_user] creado exitosamente.';
END
ELSE
BEGIN
    ALTER LOGIN [app_asistencias_user] WITH PASSWORD = N'$(APP_DB_PASSWORD_TSQL)';
    PRINT 'Login a nivel de servidor [app_asistencias_user] ya existe: contraseña sincronizada con APP_DB_PASSWORD.';
END
GO

-- 3. Configurar permisos dentro de la base de datos institucional
USE [gestionasistenciadb];
GO

-- Crear Usuario de Base de Datos mapeado al Login (si el login existe)
IF EXISTS (SELECT name FROM sys.server_principals WHERE name = N'app_asistencias_user')
   AND NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'app_asistencias_user')
BEGIN
    CREATE USER [app_asistencias_user] FOR LOGIN [app_asistencias_user];
    PRINT 'Usuario de base de datos [app_asistencias_user] creado.';
END
GO

-- 4. Crear Rol de Aplicación para Ejecución y Consulta Controlada
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'db_app_executor' AND type = 'R')
BEGIN
    CREATE ROLE [db_app_executor];
    PRINT 'Rol de base de datos [db_app_executor] creado.';
END
GO

-- 5. Asignar Permisos Estrictos al Rol
-- A. Permitir ejecución de Procedimientos Almacenados
GRANT EXECUTE TO [db_app_executor];

-- B. Permitir lectura en Vistas y Funciones
GRANT SELECT TO [db_app_executor];

-- C. DENEGAR explícitamente modificación directa de tablas físicas (Zero Direct Table Mutations)
DENY INSERT TO [db_app_executor];
DENY UPDATE TO [db_app_executor];
DENY DELETE TO [db_app_executor];

-- D. DENEGAR operaciones DDL (prohibido alterar estructuras desde la aplicación)
DENY ALTER TO [db_app_executor];
DENY CREATE TABLE TO [db_app_executor];

-- 6. Asignar el usuario de aplicación al rol seguro (si existe)
IF EXISTS (SELECT name FROM sys.database_principals WHERE name = N'app_asistencias_user')
    ALTER ROLE [db_app_executor] ADD MEMBER [app_asistencias_user];
GO

PRINT '==============================================================================';
PRINT 'Hardening de mínimo privilegio completado: [app_asistencias_user] configurado.';
PRINT 'Permisos: EXECUTE (SPs) = GRANT, SELECT (Vistas) = GRANT, INSERT/UPDATE/DELETE = DENY.';
PRINT '==============================================================================';
GO
