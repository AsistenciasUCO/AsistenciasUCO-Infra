# VALIDATION - NOTOMA-001 (2026-11-19)

## Resultados reales

| Capa | Comando | Resultado |
|---|---|---|
| DB | `test/test_notoma_aviso_sin_toma.sql` sobre una base temporal `gestionasistenciadb_notoma` (esquema desplegado desde las ramas) | `NOTOMA_00` a `NOTOMA_08` y `NOTOMA_TRANCOUNT_ZERO` en `TEST_PASS` |
| DB | `test/test_notoma_migraciones.ps1 -Database gestionasistenciadb_notoma` | `TEST_PASS:NOTOMA_MIG_UP_DOWN_UP` |
| DB | `test/test_runtime_grants_backend_inventory.sql` y `test/test_ata_p1_aviso_falta.sql` sobre la base temporal | `TEST_PASS` (sin regresion del aviso de falta) |
| Backend | `.\mvnw.cmd verify` (sin `-Pintegration`) | 4902 pruebas, 0 fallos, 0 errores, 0 omitidas; `BUILD SUCCESS`; compuertas JaCoCo cumplidas (bundle LINE 95.2 %, BRANCH 87.3 %; clases nuevas 100 % y 100 %) |

## Decisiones del usuario 2026-11-19 (cambio: exclusion por estudiantes y docente)

Decisiones 1 a 3 sin cambio (momento = ventana vencida, solo coordinadores, un correo por coordinador). Decision 4: el SP de pendientes excluye grupos sin estudiantes activos y de docente inactivo SIN marcar la sesion (se avisa si dentro de `HORAS_MAXIMAS_ATRASO` llegan estudiantes o se reactiva el docente).
Metodo: `NOTOMA_07_SIN_ESTUDIANTES` y `NOTOMA_08_DOCENTE_INACTIVO` se escribieron primero y se corrieron contra el SP anterior: RED real (`TEST FAILED NOTOMA_07_SIN_ESTUDIANTES ... Msg 59570`). Tras aplicar el SP nuevo: GREEN con `NOTOMA_00` a `NOTOMA_08` y la migracion up/down/up (con el texto regenerado), `test_ata_p1_aviso_falta.sql` y el inventario de grants, todo en `TEST_PASS`. El backend no cambio (la seleccion es de la BD): el ultimo `mvnw verify` (4902 pruebas, 0 fallos, JaCoCo cumplido) corresponde al mismo arbol; no se repitio.

## No verificado

- `test_summary.ps1` completo y `deploy_schema.ps1` del repositorio contra `gestionasistenciadb` (no se toco la base del laboratorio).
- `mvnw verify -Pintegration` (incluye `SqlStoredProcedureContractIT`, al que se agregaron los 3 SP nuevos): requiere la base del laboratorio.
- Envio real del correo por SMTP / outbox y la ejecucion del job con datos del laboratorio.
- Las pruebas T-SQL se escribieron antes que los objetos pero se corrieron por primera vez ya con ellos desplegados (no hay ejecucion RED registrada).

## Prueba manual sugerida (laboratorio, tras aplicar la migracion 57 con `migrar.ps1`)

1. Con el docente titular, no abrir ninguna toma en una sesion del dia y esperar a que venza su ventana (fin + `MARGEN_RETARDO_MINUTOS`).
2. En la siguiente pasada del job (tick de 5 s) cada coordinador activo de los programas del grupo recibe un correo "Sesión sin toma de asistencia: ...".
3. `SELECT * FROM dbo.AvisoSesionSinToma` muestra una fila para la sesion; no hay segundo correo en pasadas posteriores.
4. Con `AVISO_SESION_SIN_TOMA/HABILITADO = false` no se envia nada.
