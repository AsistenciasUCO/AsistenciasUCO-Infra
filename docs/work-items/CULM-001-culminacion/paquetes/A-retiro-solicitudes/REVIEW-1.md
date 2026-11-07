---
status: review
type: contract-review
work-item: CULM-001
paquete: A
reviewer: Opus independiente (CULM-001 §9.2)
last-reviewed: 2026-11-06
---

# REVIEW-1: CONTRACT del paquete A (retiro de solicitudes de ingreso)

Revisé `CONTRACT.md` (543 líneas), `PLAN.md`, `RESEARCH-SOLICITUDES-INGRESO.md`, `DECISIONES.md` (DEC-009 y DEC-010), `AGENTS.md` §3.3 y §4, y el prompt (§3.1 y §3.8). Comprobé con grep las afirmaciones que me parecieron dudosas en los worktrees `C:\Proyectos\GestionAsistencia-CULM001\<repo>` (DB `65a4998`, Backend `72a1675e`, Frontend `886a01b`, Infra `integracion/CULM-001`).

**Afirmaciones que comprobé y son correctas:** firmas y pasos de `usp_registrar_estudiante_en_grupo` (perfil `'DOCENTE,COORDINADOR'` en la línea 62) y de `usp_registrar_estudiante_en_grupo_interno` (cupo 88, cruce 98-105, duplicado 107-116, bloque ESP 121-136); `usp_validar_titularidad_jerarquica_interno` con `GRUPO` y `SEC_002`; el patrón de `usp_cerrar_ventana_matricula_grupo.sql:69-76`; que el cruce de horario excluye el propio grupo (`hNuevo.idGrupo <> hExistente.idGrupo`), así que una matrícula `I` del mismo grupo no bloquea la reactivación; el resultset de 21 columnas de la oferta (líneas 145-146 y `OUTER APPLY` 152-157); los índices `f[17]`..`f[20]` de `OfertaGruposEstudianteJpaRepository` (líneas 63 y 71-74); las 11 filas citadas de `access-catalog.json` (81, 82, 98, 99, 124, 131, 146-148, 155 y 159); `SecurityConfig:185-186`; `DbFailureClassifier` (`SEC_001`/`SEC_002` → 403, `SIG_*` en 110-115); los 49 `.java` que se borran (37 en los 5 paquetes de feature y 12 sueltos, el mismo inventario que da grep); las 9 pruebas backend que se borran y las 10 que se editan (no hay otras referencias en `src/test`); `EXPECTED_REPOSITORIES = 56`; `NoResourceFoundException` en `GlobalExceptionHandler:181`; el bloque "42-46" de `zz_foreign_keys.sql:352-377`; que la única FK restante hacia `Estado` es `FK_SolicitudRevisionAsistencia_Estado`; los GUID de E y X (solo aparecen en el seed 22 y en el índice filtrado); `EstadoNotificacion` con `esTerminal`; las columnas de `NotificacionSaliente`; `test_contract_closure.sql:201-206/252/271/292`; las aserciones de `test_notif002a` (4 plantillas y 9 marcadores: quedan 1 y 3); las cuentas de `HU-CATALOG.md` (134 + 3 + 2 + 2 + 7 + 24 = 172); los bloques E2E 224, 381, 409 y 629 de `test_all_hus.ps1`; que no hay eventos SSE de solicitudes. Los contratos WORM no mencionan nada de esto.

---

## Lista de comprobación

### 1. Sección 3 del prompt y `AGENTS.md`

| Regla | Resultado | Detalle |
| :--- | :--- | :--- |
| 3.1 retiro en 3 capas, con `up`/`down` idempotente | CUMPLE (con las objeciones 3 y 5) | El inventario de tabla, SP, grants, seeds, endpoints, `access-catalog.json`, plantillas, pantallas, servicios, mocks y specs está completo, salvo los consumidores de la objeción 4 |
| HU008 solo consulta | CUMPLE | Se quitan el botón, `idSolicitudAbierta` y `estadoSolicitud`. El texto informativo fijo es presentación, no traduce mensajes |
| HU026/053/054/055 descartadas | CUMPLE | §5.1 |
| 3.8: matrícula solo del docente titular o por QR | CUMPLE | E-04 (perfil `DOCENTE` y titularidad en el SP), `SecurityConfig`, fila 155 y la prueba E2E de 403 |
| SP con `SET XACT_ABORT ON` y transacción explícita | **OBJECIÓN (bloqueante 1)** | El SP nuevo sí la tiene. E-04 y E-03 modifican dos SP que no tienen ni `XACT_ABORT` ni transacción, y el contrato no los adecúa ni justifica la excepción |
| Cero datos quemados | **OBJECIÓN (bloqueante 2)** y no bloqueantes N5 y N10 | La regla 7 del SP nuevo repite el filtro `comp.codigo = 'ESP'`. Contradice A-C4, que parametriza `'I'` |
| Consultas vía `usp_consultar_*`/`uv_*` | CUMPLE | El SP nuevo es un comando. La desviación previa de la oferta (lee tablas) queda declarada fuera de alcance (§1.3) |
| Aislamiento dentro del SP | CUMPLE | Ver punto 2 |
| Clean Architecture | CUMPLE | Las rutas se borran por capa. `RegistrarEstudianteUseCaseImpl` no tiene lógica de ámbito propia que quede muerta (verificado) |
| OnPush y signals | CUMPLE | No se añaden componentes; se quitan miembros de `model<>`/`output<>` |
| Mensajes del backend | CUMPLE con reserva | A-C5 mantiene una sustitución local del texto del 409 ya existente (F3) y la registra como deuda R-9. Lo acepto: el texto del catálogo le habla al estudiante ("Usted ya se encuentra…") |
| Conventional Commits por capa | **OBJECIÓN (no bloqueante N1)** | Hay commits atómicos por repo y por capa, pero 3 títulos pasan de 72 caracteres |

### 2. Aislamiento jerárquico dentro del SP: CUMPLE

El PASO 1.85 nuevo (`usp_validar_titularidad_jerarquica_interno`, `GRUPO`) va antes del cupo y antes de sincronizar la identidad, así que un no titular no deja escrituras. El coordinador cae en `SEC_001` (perfil `DOCENTE`) y el administrador queda en 403 en el filtro HTTP. T-08 y T-09 lo fijan. QR: solo `ESTUDIANTE`, sin cambios.

### 3. Migración: **OBJECIÓN (bloqueante 3)**, y además N11

La parte de `SolicitudIngresoGrupo` está bien: archivo con PK y sin FK, guardia U-3, `DROP` después de archivar, estados por código y `down` R-4/R-5 con `NOCHECK` si hace falta. Los huecos están en las notificaciones y las plantillas:

- **(a) R-9 lanza `THROW 53310` en casos normales.** `usp_depurar_notificaciones_salientes_interno` (líneas 53-61) borra filas `FALLIDA_DEFINITIVA` con `creadoEn` anterior a la retención, así que la primera depuración después del `up` puede borrar filas archivadas. Además, `usp_reintentar_notificacion_saliente_interno` (líneas 67 y 86-94) deja que el administrador pase una `FALLIDA_DEFINITIVA` a `PENDIENTE` y limpia el `codigoError`. En los dos casos R-8 no restaura la fila, R-9 la ve "sin restaurar" y el `down` falla. El paso 2 del rollback (§7) dice entonces "se restaura el backup COPY_ONLY", y eso pierde todo lo escrito después del `up`.
- **(b) Una fila `RESERVADA` vencida queda atascada tras el `down`.** U-0 solo bloquea las reservas vigentes, así que una reserva vencida se archiva como `RESERVADA`. U-2(c) anula `reservadoHasta`/`reservadoPor`, el archivo no los guarda, y R-8 la devuelve a `RESERVADA` con `reservadoHasta = NULL`. El despachador solo toma las `RESERVADA` con `reservadoHasta < @ahora` (`usp_reservar_notificaciones_salientes_interno:57`), así que esa fila nunca se vuelve a enviar.
- **(c) Las versiones de plantilla creadas por el administrador se pierden sin archivo.** `PlantillaNotificacion` tiene versiones (`UQ (tipo, idioma, version)`, `creadoPor`), y NOTIF-002B permite crear versiones nuevas. U-2(d) borra todas las versiones de los 3 tipos, y R-7 solo restaura la v1 del seed. Esto contradice DEC-010 ("sin pérdida de datos y reversible").

### 4. Consumidores: **OBJECIÓN (bloqueante 4)**

Busqué por mi cuenta los endpoints, los DTO, las columnas, los eventos y las plantillas. El contrato cubre el backend completo (los 40 archivos de `src/main` que nombran `SolicitudIngreso*`/`SOLICITUD_INGRESO_*`, el DTO, la proyección, el wiring y el `.psv`). En el frontend cubre todos los archivos que nombran los identificadores retirados. Faltan estos:

- `GestioAsistenciaDB/test/test_consolidado_auditoria_catalogos.sql:148-150` (T-155-01): exige `COUNT(*) FROM uv_estado WHERE codigo IN ('P','A','R','E','X') = 5`. Con A-C3/U-6 y el borrado del seed 22 **pasa a rojo**, y no está en §2.2.
- `AsistenciasUCO-Infra/scripts/tests/test_all_hus.ps1:419-424` (`Run-Test "HU051"`): llama a `DELETE /grupos/{id}/estudiantes/{id}`, el stub que se retira (hoy 501, después 404). HU051 sigue viva por `POST /docente/grupos/{g}/estudiantes/{e}/retiro`, y §5.3 no lo menciona.
- `GestioAsistenciaFrontend/src/app/features/attendance/attendance-control/components/group-sessions-overview.component.spec.ts:147`: busca `[data-testid="padron-solicitudes"]`, que §4.2 renombra a `padron`. El contrato no lista esta spec.

Sin hallazgos en: `JpaQueryAdapterContractTest` (no lee la oferta), `SqlStoredProcedureContractIT` (solo parámetros, que no cambian), mocks de `admin/estados` (no traen E/X), `admin-email-management` (tiene un respaldo para tipos desconocidos, `PLANTILLA_METADATA[tipo] || …`, línea 1164) y las demás pruebas de BD que llaman a `usp_registrar_estudiante_en_grupo` (`test_ident001`, `test_group_capacity_decoupling` y `test_transaction_ownership` usan al titular o a un estudiante, así que siguen verdes con E-04).

### 5. Pruebas RED: **OBJECIÓN (bloqueantes 5 y 6)**, y además N2

- **B-RED-05 nunca está en rojo.** `RbacSecurityFilterChainTest` es un `@WebMvcTest` con un `RbacProbeController` sonda que no mapea ninguna de las 10 rutas y no importa `GlobalExceptionHandler`. Las 10 rutas ya responden 404 allí **antes** del cambio. Incumple la compuerta del PLAN ("cada prueba nueva falla por la razón esperada") y da una cobertura falsa.
- **T-01b deja `db-test` en rojo en una BD nueva.** Exige que existan las dos `zz_archivo_*`, pero solo las crea la migración 13 (no están en `schema/`, y `deploy_schema.ps1` no ejecuta migraciones). Toda BD construida con `deploy_schema.ps1` (entorno nuevo o CI) fallaría siempre.
- Los cambios de expectativa están justificados como cambio formal y ninguno relaja aserciones: RM-02 de "en espera" a `ERR_CUPO_SUPERADO` porque HU055 se descarta; coordinador de 200 a 403 por F-COO-004; el texto del 409 por DEC-009; E-15 con el titular como ejecutor. Lo acepto.

### 6. Datos quemados y secretos: CUMPLE con la objeción 2

No hay secretos. Los literales que la migración usa (GUID de E/X, `FALLIDA_DEFINITIVA`, `TIPO_NOTIFICACION_RETIRADO`) son datos de migración y siguen el patrón de los seeds. Ver N5 y N10.

### 7. A-C1, A-C2 y A-C3

- **A-C1 (cancelar = `FALLIDA_DEFINITIVA` + `codigoError`): correcta y la más conservadora** dentro de DEC-010. Un estado `CANCELADA` tocaría el panel, el resumen y la depuración. Borrar las filas quitaría visibilidad. Pendiente menor (N6): el reintento del administrador puede volver a encolarlas.
- **A-C2 (segunda tabla de archivo): correcta en la idea, incompleta en la ejecución.** Ver la objeción 3: faltan `reservadoHasta`/`reservadoPor` (o restaurar como `PENDIENTE`), el `down` tiene que tolerar las filas depuradas o reintentadas, y faltan las versiones de plantilla.
- **A-C3 (borrar E/X de `dbo.Estado`): correcta.** Es reversible (el archivo guarda códigos y R-3 vuelve a crear los id fijos), no deja catálogo huérfano y U-6 comprueba las FK. La condición es actualizar T-155-01 (objeción 4).

### 8. Despliegue conjunto por el mapeo posicional: CUMPLE (bien mitigado), con N3

Hay despliegue conjunto con el backend detenido (U-0). T-02 fija ordinales en BD, B-RED-04 lo hace en Java, y `COLUMNAS_OFERTA = 19` convierte un desfase silencioso en un error visible. Con un backend viejo sobre la BD nueva, `f[20]` da un `ArrayIndexOutOfBounds` (500 visible). Con un backend nuevo sobre la BD vieja, la guardia de longitud corta. Falta precisar el tipo de excepción (N3).

---

## Objeciones no bloqueantes

- **N1.** Hay títulos de commit de más de 72 caracteres (AGENTS 5.4): `refactor(backend/controller): retirar endpoints y casos de uso de solicitudes` (77), `refactor(frontend/coordinador): eliminar metodos de solicitudes y matricula` (75) y `refactor(frontend/estudiante): eliminar pantalla y servicio de solicitudes` (74). Hay que acortarlos.
- **N2.** T-05 y T-06 (manual y QR) ya están en verde hoy: el cupo lo rechaza `usp_validar_cupo_disponible_grupo_interno` antes de llegar al SP nuevo, y el duplicado o `MQR_004` ya existen. Son pruebas de caracterización. §2.6 dice "Todas fallan hoy (RED)": hay que etiquetarlas así. La regla 6 (cupo bajo bloqueo) solo la cubre T-12 al llamar directo al SP nuevo.
- **N3.** `COLUMNAS_OFERTA` debe lanzar `IllegalStateException`. `JpaQueryExecutor.execute` (línea 36) solo envuelve `PersistenceException | IllegalStateException | IllegalArgumentException | ArithmeticException` en `DatabaseOperationException`, y OR09 debe comprobar ese tipo. Recomendado: añadir la forma del resultset de la oferta a `SqlStoredProcedureContractIT` (`-Pintegration`).
- **N4.** La regla 4 toma `UPDLOCK, HOLDLOCK` sobre `Grupo` y un rango sobre `EstudianteGrupo` en **cada** matrícula, haya reactivación o no. `EstudianteGrupo` no tiene índice por `(grupo, estudiante)` (grep en `schema/tables`), así que el rango puede abarcar la tabla y serializar ráfagas de QR (HU176B). Se puede buscar primero la fila `I` sin bloqueo y bloquear solo si existe.
- **N5.** `MATRICULA/ESTADO_RETIRADA` y `usp_retirar_estudiante_grupo.sql:41` (`codigo = 'I'` literal) son dos fuentes del mismo dato. O el retiro lee el mismo parámetro, o se registra como deuda en `TECHNICAL_DEBT.md`.
- **N6.** `usp_reintentar_notificacion_saliente` acepta `FALLIDA_DEFINITIVA`. Hay dos salidas: rechazar las filas con `codigoError = 'TIPO_NOTIFICACION_RETIRADO'`, o documentar que se reencolan y vuelven a fallar por falta de plantilla. En los dos casos hay que añadirlo a T-11.
- **N7.** T-10 dice que lo "invoca `infra.ps1 db-test`", pero `db-test` ejecuta `components/sqlserver/scripts/test-summary.ps1` de Infra, y §5 no lo edita. Hay que aclarar que es una compuerta manual del PLAN o añadir la edición.
- **N8.** Quedan las claves `messages:user:SIG_*` y `messages:technical:SIG_*` en Azure App Configuration (SSOT de mensajes). Hay que anotarlas como pendientes en `PRS.md`/CLOSURE, igual que el `--prune` del PDP.
- **N9.** F-RED-04 usa `(service as any)`, contra la regla de cero `any`. Basta con `expect('getSolicitudesMatricula' in service).toBeFalse()`. Además, TypeScript ya garantiza la ausencia de esos métodos al compilar.
- **N10.** En SP que se reescriben quedan literales previos: `'A'` en `usp_registrar_estudiante_en_grupo_interno:46` y en `matriculado` de la oferta (línea 144). Hay que registrarlos como deuda si no se corrigen aquí.
- **N11.** Para que el `down` sea idempotente, R-5 y R-8 deben ir protegidos con `IF OBJECT_ID('dbo.zz_archivo_…','U') IS NOT NULL`, porque R-9 borra esas tablas en la primera pasada.
- **N12.** R-4 (§7) atribuye el manejo de `XACT_STATE() = -1` a `usp_internal_matricular_por_token:264-274`. En realidad, el `CATCH` del interno (`usp_registrar_estudiante_en_grupo_interno:152-160`) atrapa el `THROW` del SP nuevo y no lo relanza, así que lo resuelve el PASO 5 (255-260) **solo** con transacción propia. T-12 debe cubrir el error del SP nuevo bajo QR con una transacción externa (en ese caso, la transacción vuelve al llamador marcada como no confirmable, `XACT_STATE() = -1`).

---

VEREDICTO: 18 objeciones (bloqueantes: 6)

## Objeciones bloqueantes (corrección exacta esperada)

1. **`XACT_ABORT` y transacción en los SP modificados (AGENTS 3.3.1).** E-04 debe añadir a `usp_registrar_estudiante_en_grupo` `SET XACT_ABORT ON` y el patrón de transacción propia o savepoint de `usp_internal_matricular_por_token:64-74` y `:255-283`: `ROLLBACK` del savepoint si `@estadoResultado = 0` después de escribir y `IF @@TRANCOUNT > 0 ROLLBACK` en el `CATCH`, con la firma y el resultset sin cambio. E-03 debe declarar por escrito que `usp_registrar_estudiante_en_grupo_interno` participa en la transacción del llamador, con su justificación. T-12 debe probar que un fallo del interno después de crear `Usuario`/`Estudiante` (por ejemplo `HOR_001`) no deja filas parciales y conserva `@@TRANCOUNT`. También hay que corregir R-4 según N12.
2. **La regla ESP debe vivir en un solo sitio.** La regla 7 de §2.3 se reescribe: `usp_internal_reactivar_matricula_retirada` solo hace el `UPDATE` de `I` a destino. La inscripción en `EstudiantePrograma` (componente ESP) la sigue aplicando el bloque existente del interno (líneas 121-136) para los dos caminos, moviéndolo antes de la bifurcación `@reactivada` o extrayéndolo a un `usp_internal_*` que llamen ambos. Sin literal `'ESP'` nuevo. T-07 no cambia.
3. **El `down` tiene que completarse y restaurar todo (A-C2 y DEC-010).** (a) R-8/R-9: una fila archivada que ya no existe en `NotificacionSaliente` (depurada) o cuyo `codigoError` ya no es `TIPO_NOTIFICACION_RETIRADO` (reintentada) cuenta como resuelta y se informa por `PRINT`. El `THROW 53310` queda solo para las filas de `zz_archivo_SolicitudIngresoGrupo` que falten en `SolicitudIngresoGrupo`. (b) Hay que añadir `reservadoHasta`/`reservadoPor` al archivo de notificaciones, o que R-8 devuelva una `RESERVADA` como `PENDIENTE` con `proximoIntentoEn = SYSDATETIMEOFFSET()`. (c) Antes de U-2(d), hay que copiar todas las filas de `PlantillaNotificacion` y `PlantillaNotificacionMarcador` de los 3 tipos (todas las versiones) a una `dbo.zz_archivo_PlantillaSolicitudIngreso` sin FK, y R-7 las restaura desde ahí. T-10/T-11 deben sembrar una versión 2 creada por el administrador, una `RESERVADA` vencida y una fila depurada, y comprobar `up` → `down` sin error.
4. **Consumidores que faltan.** Hay que añadir a §2.2 la fila E-16 `test/test_consolidado_auditoria_catalogos.sql:148-150`: T-155-01 pasa a `codigo IN ('P','A','R') = 3` y `NOT EXISTS (codigo IN ('E','X'))`, como cambio formal por A-C3. A §5.3 hay que añadir `test_all_hus.ps1:419-424` (HU051), redirigido a `POST /docente/grupos/{grupoId}/estudiantes/{estudianteId}/retiro` con motivo y con las mismas aserciones de éxito. A §4.2 hay que añadir `group-sessions-overview.component.spec.ts:147`, con `data-testid="padron"` y la misma aserción del clic.
5. **T-01b no debe depender de la migración.** En `test_culm001_a_retiro_solicitudes.sql` (dentro de `test_suite.sql`), T-01b queda condicional: *si* existen las `zz_archivo_*`, no tienen FK, ni permisos para `rol_asistencias_runtime`, ni dependencias. La aserción de existencia pasa a `test_migracion_13_up_down.ps1` (T-10).
6. **B-RED-05 debe estar de verdad en rojo.** Hay que sacarlo de `RbacSecurityFilterChainTest`, cuya sonda no mapea esas rutas. Se pone en una prueba nueva que cargue los controladores **reales** afectados (`@WebMvcTest(controllers = {EstudianteSolicitudIngresoController, DocenteSolicitudIngresoController, CoordinadorPortalController, GrupoController})` en RED, que en GREEN quedan sin las rutas) con `GlobalExceptionHandler` importado, y que falle hoy con 200/201/501 en las 10 rutas. Si no, hay que eliminar B-RED-05 y declarar que la cobertura de rutas la dan B-RED-01, B-RED-03 y B-RED-07.
