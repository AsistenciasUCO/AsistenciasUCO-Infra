# Pruebas locales de la versión final

Guía para que cualquier integrante deje su laboratorio listo para probar todos los roles con los mismos datos.
Todo se ejecuta desde la raíz del workspace con `.\AsistenciasUCO-Infra\infra.ps1`.

## 1. Levantar lo necesario

```powershell
.\AsistenciasUCO-Infra\infra.ps1 stack up basico      # BD + Seguridad + Backend y Frontend en contenedores
.\AsistenciasUCO-Infra\infra.ps1 stack status
```

Use `mensajes`, `parametros`, `soportes` u `observabilidad` según lo que vaya a probar (ver [stack/README.md](../../stack/README.md)).
La Seguridad del equipo debe estar aprovisionada una vez (`provision_asistencias.py keycloak` y `pdp`, ver
`GestioAsistenciaBackend/infra/security-baseline`).

## 2. Cargar los datos de prueba variados

```powershell
.\AsistenciasUCO-Infra\infra.ps1 datos-prueba cargar -Yes
```

Respalda la base actual en `/var/opt/mssql/backup`, la recrea desde el esquema de `develop`, carga el conjunto de
`GestioAsistenciaDB/scripts/datos-prueba`, da de alta los 73 usuarios en Keycloak y el PDP y verifica cada rol (unos 10
minutos). Requiere Python 3 de Windows (`-Python <ruta>` si no está el lanzador `py`).

| Paso suelto | Comando |
| :--- | :--- |
| Solo cuentas y perfiles de Seguridad | `infra.ps1 datos-prueba seguridad` |
| Solo la verificación por rol (lectura) | `infra.ps1 datos-prueba verificar` |
| Guardar el estado actual antes de probar | `infra.ps1 db-reset-qa -Mode Snapshot` |
| Volver a ese estado | `infra.ps1 db-reset-qa -Mode Restore -Backup <archivo.bak> -Yes` (detener antes el backend) |

Los usuarios, con su rol, programa y grupos, están en
[USUARIOS.md](../../../GestioAsistenciaDB/scripts/datos-prueba/USUARIOS.md). Todos usan la contraseña común de
laboratorio (`AGENTS.md`, sección 7) y entran por correo en `http://localhost:4200`.

## 3. Casos preparados

| Funcionalidad | Con quién | Qué hay listo |
| :--- | :--- | :--- |
| Cambio de decano | Administrador, Facultades | Andrés Ospina es decano sin facultad; Paula Zuluaga dirige una facultad sin programas (se puede desactivar) |
| Cambio de coordinador | Decano de Ingeniería o de Económicas, Programas | Mauricio Quintero y Claudia Montoya están libres en su facultad; Esteban Rendón está inactivo (debe rechazarse) |
| Cambio de docente de un grupo | Coordinador, Grupos | Julián Hoyos está vinculado a Sistemas y Tec. Software sin grupos; Liliana Mejía tiene el vínculo inactivo (debe rechazarse) |
| Reasignación de una propuesta | Cambiar la coordinadora de Sistemas | La propuesta de cancelación de Santiago (Bases de Datos) pasa al nuevo coordinador |
| Decisión del docente | Alejandro Cárdenas | Revisión de Brayan (Ética, 26,7 %) pendiente |
| Reclamos | María Rostagno, Hugo Serna, Sebastián Toro | 3 pendientes; también hay uno aceptado, uno rechazado y uno retirado |
| Solicitudes de sesión | Coordinadora de Sistemas y de Tec. Software | 2 sesiones extraordinarias pendientes |
| Alertas | Estudiantes Santiago, Kevin, Brayan (pérdida) y Mateo, Laura, Camila, Valeria (riesgo) | Alertas activas |
| Cierre masivo | Administrador, período 2026-1 | Terminó sin cerrar; Alejandro Pineda supera el 20 % y quedaría cancelado por inasistencia |
| Visibilidad por rol | Cualquiera | Grupos compartidos entre programas y facultades (Cátedra, Ética, Cálculo, Costos) |
| Doble rol | Diana Londoño | Coordinadora de Tec. Software y docente de Pruebas de Software |

Los correos que genere la aplicación van al buzón de prueba (`SMTP_NOTIFICATION_TEST_MODE_ENABLED=true`).

## 4. Suites automáticas

```powershell
.\AsistenciasUCO-Infra\infra.ps1 datos-prueba verificar      # visibilidad por rol sobre estos datos
.\AsistenciasUCO-Infra\scripts\tests\test_all_hus.ps1         # HU de los 5 roles
.\AsistenciasUCO-Infra\infra.ps1 verify                       # secretos y contratos antes de un commit
```

Guion de pruebas manuales por rol para la demostración (qué cambió en el cierre y qué sigue abierto): [GUION-PRUEBAS-MANUALES](../work-items/CIERRE-001-cierre-proyecto/GUION-PRUEBAS-MANUALES.md).

## Advertencias operativas de base de datos

- **Orden: migraciones antes de `deploy_schema` (TD-081).** Algunas migraciones vuelven a crear SP con el texto de su época; con otro orden pisan objetos de C.1. La migración 24 requiere `:r $(MIGDIR)`.
- **`migrar.ps1 -Modo Aplicar` con el registro vacío re-ejecuta todo.** Si `dbo.MigracionAplicada` está vacía, todas las migraciones desde la 05 (`-VersionMinima` por defecto) figuran PENDIENTE y se vuelven a ejecutar. Por eso se corre siempre antes `GestioAsistenciaDB/scripts/migrar.ps1 -Modo Estado` (es el modo por defecto y solo lee). Para una base vieja sin registro, `-Modo Detectar` y `-Modo Baseline -SoloDetectadas` registran lo ya aplicado sin ejecutarlo; una migración `PARCIAL` la decide una persona.

## Límites conocidos

- Red del campus: con el backend en contenedor, las peticiones llegan desde la red de Docker (p. ej. `192.168.80.1`).
  Los datos de prueba dejan `RED/CIDRS_CAMPUS` con loopback y los rangos privados `172.16.0.0/12` y `192.168.0.0/16`
  para que el registro por QR/PIN funcione en el laboratorio (también desde un celular en la misma red). Con la sección
  `ext-parametros` el valor sale del Catálogo de Parámetros.
- 2026-1 terminó sin cierre masivo: mientras no se cierre, el horario del estudiante y la lista de grupos del
  coordinador muestran también esos grupos (hallazgo abierto: no filtran por período vigente).

- El historial de asistencia se registra hasta el momento de la carga; las cifras exactas cambian según el día.
- Los scripts siembran el período 2026-2 (1 de agosto a 15 de diciembre de 2026): después de esa fecha el generador
  de sesiones rechaza el período y hay que mover las fechas en `generar_datos_prueba.py`.
