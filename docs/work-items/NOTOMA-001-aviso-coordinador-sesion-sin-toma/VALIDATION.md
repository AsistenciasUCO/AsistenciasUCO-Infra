# VALIDATION - NOTOMA-001 (2026-11-19)

## Resultados reales

| Capa | Comando | Resultado |
|---|---|---|
| DB | `test/test_notoma_aviso_sin_toma.sql` sobre una base temporal `gestionasistenciadb_notoma` (esquema desplegado desde las ramas) | `NOTOMA_00` a `NOTOMA_06` y `NOTOMA_TRANCOUNT_ZERO` en `TEST_PASS` |
| DB | `test/test_notoma_migraciones.ps1 -Database gestionasistenciadb_notoma` | `TEST_PASS:NOTOMA_MIG_UP_DOWN_UP` |
| DB | `test/test_runtime_grants_backend_inventory.sql` y `test/test_ata_p1_aviso_falta.sql` sobre la base temporal | `TEST_PASS` (sin regresion del aviso de falta) |
| Backend | `.\mvnw.cmd verify` (sin `-Pintegration`) | 4902 pruebas, 0 fallos, 0 errores, 0 omitidas; `BUILD SUCCESS`; compuertas JaCoCo cumplidas (bundle LINE 95.2 %, BRANCH 87.3 %; clases nuevas 100 % y 100 %) |

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
