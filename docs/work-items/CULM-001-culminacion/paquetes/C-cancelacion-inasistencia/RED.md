# CULM-001 C.1 — RED (fase 03)

Fecha: 2026-11-08. Pruebas T-SQL de la BD escritas antes de los SP; ejecutadas sobre una BD con las tablas, funciones y vistas pero sin los SP de C.

```text
=== test/test_culm001_c_revisiones.sql
Changed database context to 'gestionasistenciadb'.
TEST START: test_culm001_c_revisiones
Msg 102, Level 15, State 1, Server dabff5c7546b, Line 121
Incorrect syntax near 'x'.
=== test/test_culm001_c_cierre_masivo.sql
Changed database context to 'gestionasistenciadb'.
TEST START: test_culm001_c_cierre_masivo
Msg 58399, Level 16, State 1, Server dabff5c7546b, Line 126
TEST FAILED: C-DB-40/47 el cierre con 2 perdidas sin revision debe responder RCN_012 en una sola fila. [lote:72]
=== test/test_culm001_c_realtime_audiencias.sql
Changed database context to 'gestionasistenciadb'.
TEST START: test_culm001_c_realtime_audiencias
Msg 58419, Level 16, State 1, Server dabff5c7546b, Line 140
Could not find stored procedure 'dbo.usp_consultar_audiencias_realtime_grupo'. [lote:95]
```

Razones del fallo: objeto inexistente (usp_evaluar_alertas_inasistencia_grupo, usp_consultar_audiencias_realtime_grupo) y cierre masivo con la regla anterior por conteo (CI en vez de RCN_012).
