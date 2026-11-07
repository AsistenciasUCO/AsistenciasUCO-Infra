---
status: review
type: contract-review
work-item: CULM-001
paquete: A
reviewer: Opus independiente (CULM-001 §9.2), segunda ronda
last-reviewed: 2026-11-07
---

# REVIEW-2: CONTRACT v2 del paquete A (A.1 retiro de solicitudes y A.2 correcciones de la Fase 1)

Revisé la v2 completa: `CONTRACT.md`, 832 líneas, incluidas la §8 (A.2) y la §9 (respuesta a REVIEW-1). También leí `CORRECCIONES-A.md`, `DECISIONES.md` (DEC-022, DEC-025, DEC-027 y DEC-028) y las secciones de numeración y mensajes de los contratos B y B2. Comprobé con grep, en los worktrees `C:\Proyectos\GestionAsistencia-CULM001\<repo>`, las afirmaciones de §8 que me parecieron dudosas.

## 0. Respuesta a REVIEW-1: las 18 objeciones están resueltas

Comprobé en el texto de la v2 que se resolvió cada una:

- **B1:** E-04 tiene ahora `XACT_ABORT`, transacción o savepoint y la sección `CATCH`. E-03 declara que usa la transacción del llamador. T-12c prueba ese caso.
- **B2:** la regla 7 solo hace el `UPDATE`. El bloque ESP queda en un solo sitio, y T-07 comprueba con `OBJECT_DEFINITION` que el SP nuevo ya no lo contiene.
- **B3:** el `down` es tolerante. R-8 da por resueltas las filas depuradas o reintentadas, `RESERVADA` vuelve como `PENDIENTE` y las plantillas se archivan con todas sus versiones. Cambiar a dos tablas de archivo es razonable.
- **B4:** se añadieron E-16, la fila HU051 y la spec de `padron`. Que T-155-01 espere 4 estados (P, A, R, X) es coherente con conservar X para A.2-7.
- **B5:** T-01b es condicional.
- **B6:** existe un `@WebMvcTest` con los controladores reales (ver N8).
- **N1-N12:** aplicadas, con verificación en el texto. N5 queda como deuda justificada.

No reabro nada de A.1, salvo la numeración de la migración de A.2 (bloqueante 2).

---

## 1. Lista de comprobación (la de REVIEW-1, sobre la v2)

| # | Punto | Resultado |
| :--- | :--- | :--- |
| 1 | Prompt §3 y `AGENTS.md` | **OBJECIÓN (bloqueante 1)**: DEC-027 no está aplicado. El resto CUMPLE: los SP nuevos (directorio, retiro de reclamo, estado del decano y solape) declaran `XACT_ABORT` y transacción o savepoint cuando escriben; los estados vienen de parámetros (`RECLAMO/*`, `MATRICULA/ESTADO_INSCRITA`); las consultas pasan por `usp_consultar_*`; los mensajes vienen del backend (A2-F-01/03); los commits van por capa y sus títulos tienen 72 caracteres o menos |
| 2 | Aislamiento jerárquico dentro del SP | CUMPLE en A.1. En A.2 hay **OBJECIÓN (bloqueante 4)** en el estado del decano, y N4 y N5 en el ámbito |
| 3 | Migración idempotente, `down` y sin huérfanos | CUMPLE en A.1. En A.2 hay **OBJECIÓN (bloqueante 2)**: el número de la migración choca con DEC-028 |
| 4 | Consumidores | CUMPLE, con N2 y N11 |
| 5 | Pruebas RED por regla | CUMPLE, con N6, N7, N8 y N11. Falta la prueba de la búsqueda de DEC-027 (bloqueante 1) |
| 6 | Datos quemados y secretos | CUMPLE. El fixture usa ids fijos con prefijo `C1B0` y un hash de relleno, sin credenciales reales. **OBJECIÓN (bloqueante 3)**: el código `SES_010` está duplicado entre paquetes |
| 7 | A-C1, A-C2 y A-C3 | CUMPLE. Conservar `X` (A2-C4) es la opción más conservadora |
| 8 | Despliegue conjunto por el mapeo de la oferta | CUMPLE (sin cambios desde REVIEW-1; N3 de REVIEW-1 aplicada) |

## 2. Puntos específicos de §8

| Punto | Resultado | Detalle |
| :--- | :--- | :--- |
| Ámbito dentro del SP de `usp_consultar_directorio_estudiantes_paginado`, `usp_consultar_estudiantes_grupo_ambito_paginado` y `usp_consultar_asistencias_grupo_ambito_paginado` | CUMPLE, con N4 y N5 | El ámbito se resuelve dentro del SP con la unión de roles. Fuera de ámbito: el listado lo filtra y el detalle da 0 filas, que es 404. En los dos SP de grupo, un grupo ajeno o inexistente da `THROW` con `DBCODE=SEC_002` y 403. El marcador existe (`usp_obtener_mensaje_catalogo.sql:71`) y coincide con DEC-025 y A2-C2. Para `GET /grupos`, reutilizar `usp_consultar_grupos_paginado` es correcto: fija su `SESSION_CONTEXT` y `uv_auth_grupo` filtra por administrador e institución, decano, coordinador, docente y estudiante. B2 los reutiliza con los mismos nombres (contrato B2, líneas 69-71) |
| DEC-025: 403 por ámbito o titularidad ajena en `/grupos/{id}/*` | CUMPLE | A2-C2, y `matricula-qr` con un GUID inexistente da 403 |
| DEC-027 | **OBJECIÓN (bloqueante 1)** | No existe `GET /api/v1/grupos/{id}/estudiantes/busqueda?documento=`: grep de `busqueda` sobre `CONTRACT.md` = 0 en A.2. A2-C1 sigue pidiendo "una decisión" y apunta el `x-roles` como deuda, aunque DEC-027 ya decidió recongelarlo. El modal sigue usando `GET /estudiantes` (A2-F-06, "sin cambio de lógica") |
| `usp_validar_solape_sesion_interno` | CUMPLE, con N6 | Va en los internos no congelados: los llamadores son solo `usp_crear_sesion(_v2)` y `usp_actualizar_sesion(_v2)` (grep). El bloqueo ocurre dentro de la transacción ya abierta (`usp_crear_sesion_interno:101-115`). Los bordes no se solapan y una sesión se excluye a sí misma. Responde 400, como declara el OpenAPI |
| Retiro de reclamo propio | CUMPLE | RBAC `ESTUDIANTE`; un reclamo ajeno o inexistente da `REV_006`, sin revelar que existe; usa `UPDLOCK, HOLDLOCK`; P a X por parámetro; A2-T-11 comprueba que X no se cuenta en los KPI. Los códigos `REV_006`..`REV_008` y `DEC_002`/`DEC_003` están libres (seed `04_mensaje.sql` solo tiene REV_001-005 y DEC_001; B y B2 no los usan) |
| Cambio de estado del decano | **OBJECIÓN (bloqueante 4)** | Desactivar al decano no le quita el rol. `uv_usuario_perfil.sql` filtra `WHERE c.estado = 1` en la rama del coordinador (línea 44, D1 de HU121/HU122), pero la rama del decano (líneas 22-30) no filtra por `d.estado`. `usp_validar_permiso_rbac_usuario_interno` resuelve el perfil con esa vista, así que un decano desactivado que conserva el usuario activo (porque tiene otro rol) **sigue pasando el RBAC `DECANO`**, y su JWT sigue trayendo el rol. A2-DB-4 solo cambia `uv_decano`, que es presentación |
| Fixture `culm1_segundo_ambito.sql` | CUMPLE, con N7 | Va fuera del despliegue (`deploy_schema.ps1` no lee `test/`), es idempotente por id fijo y tiene `_down` |
| Mapeo de errores: DEC-018, `ParameterCatalogException`, `NTF_002` y NPE | CUMPLE, con N1, N3 y N9 | `NTF_002` existe (`04_mensaje.sql:108/244`) y lo devuelve `usp_reintentar_notificacion_saliente_interno:41`; no está mapeado en `DbFailureClassifier` (solo NTF_004/005/008), así que mapearlo a 404 es correcto. El NPE sale de `AdministracionNotificacionJpaAdapter.java:302-303` (`requireNonNull`), y validarlo en el request (400) es correcto. Las 7 lecturas del catálogo están en `src/main` |
| Quitar al administrador de las rutas | CUMPLE, con N2 | Hay 58 filas `coordinador/*` (36) y `decano/*` (22) con ADMINISTRADOR (lo comprobé con Python sobre el JSON). Comprobé la única excepción, `GET /coordinador/periodos-academicos`: `admin-periodos` y `admin-system` la cargan, y las escrituras van a `/admin/periodos-academicos`. `admin-facultades` solo lee la señal `planes`, sin pedir datos (el 403 de ADM-16 ya existía). No hay otra pantalla del administrador afectada. Pero la cifra de 57 cuenta 6 filas que A.1 y A.2-14 borran (N2) |
| `DispatcherType.ERROR` como causa del 401 público | Mecanismo PLAUSIBLE, evidencia mal citada (N1) | `SecurityConfig` no tiene `dispatcherTypeMatchers` ni `permitAll` para `/error` (grep). `MatriculaQrRateLimitFilter` se registra con `HIGHEST_PRECEDENCE + 11`, antes de la cadena de seguridad (`MatriculaQrWiringConfiguration:203`). Una excepción en ese filtro llega a Tomcat, que hace el despacho de error a `/error`; Spring Security 6 y 7 autoriza también el despacho `ERROR`, y `anyRequest().authenticated()` sin token responde 401 por el entry point. El log del worktree lo confirma: `HttpRequestTraceFilter` registra `status:500` en `POST /api/v1/public/matricula-qr/validar` (cid `b546c8b9…`, `2f4f4afc…`) con `ParameterCatalogException` en la traza. **El origen no es `NetworkClientIpResolver`/`RED/PROXIES_CONFIABLES`**, sino `MatriculaQrRateLimitFilter.java:58` → `MatriculaQrWiringConfiguration.limiteIp:206` (`MATRICULA_QR/LIMITE_IP_POR_MINUTO`) → `AzureAppConfigParameterCatalogAdapter:58/68`. El cid `ac109cef…` no aparece en el log del worktree |
| Numeración de migraciones y semillas | **OBJECIÓN (bloqueante 2)** | DEC-028 asigna A.2 = **14**, y §8.2 usa `13_culm001_a_correcciones_fase1_*` (también §6.2, §7 rollback, A2-T-16 y el commit DB A.2-7). Las semillas `33_culm001_a_catalogos.sql` y `33_culm001_a_mensajes.sql` están dentro del 33 de A: CUMPLE. Choque entre paquetes que hay que avisar: el contrato B (`[SUPUESTO-B-01]`, línea 16) dice "migraciones `14_*`/`15_*`", lo que choca con A.2 = 14, y DEC-028 le asigna 15/16. B2 usa 17/18 (su contrato, líneas 7 y 146), igual que DEC-028. El mensaje del orquestador ("B2 16-17") y DEC-025 ("migración 16/17") contradicen DEC-028 |
| Pruebas RED A2-T, A2-B y A2-F por regla | CUMPLE, con huecos | Cada ítem A.2-1..A.2-14 tiene al menos una prueba RED en su capa. Faltan: la búsqueda de DEC-027 (bloqueante 1), el RBAC del decano desactivado (bloqueante 4), el mensaje de `SES_010` en pantalla (N11) y la idempotencia del fixture (N7) |
| Códigos de mensaje | **OBJECIÓN (bloqueante 3)** | A2-DB-6 crea `SES_010` (solape, 400), pero el contrato B ya lo define como "sesión cancelada" (409, `ERR_SESION_CANCELADA`, NB-1 aceptada; contrato B, líneas 382, 681 y 1441), y B usa SES_010..SES_016. A2-DB-6 solo miró `04_mensaje.sql` |

---

## Objeciones no bloqueantes

- **N1.** Hay que corregir la evidencia de A.2-5: el origen es `limiteIp` (`MATRICULA_QR/LIMITE_IP_POR_MINUTO`), y el cid debe ser uno de los que están en el log. Además del decorador, `limiteIp` debe tratar una `ParameterCatalogException` como `LIMITE_IP_POR_DEFECTO`. A2-B-08 debe reproducir el fallo **en el filtro** y comprobar que el cuerpo del despacho `ERROR` es `ApiErrorResponse` sin traza (`server.error.include-stacktrace` en `never`).
- **N2.** La cifra de rutas está mal. De las 58 filas con ADMINISTRADOR, 6 se borran (POST y DELETE de `coordinador/grupos/{grupoId}/estudiantes`, GET y PATCH de `coordinador/solicitudes-matricula`, DELETE de `planes-estudio/{planId}/asignaturas/{asigId}` y PATCH de `periodos-academicos/{id}/estado`). Quedan 52: **51** pierden ADMINISTRADOR y 1 lo conserva. Hay que corregir §8.4 A.2-3, R-A2-2 y CLOSURE.
- **N3.** A.2-9 añade una tercera vía de traducción de `DBCODE` en `JpaQueryExecutor`, aunque ya existe `jpa/repository/DbCodeTranslator.java`, que usan 7 repositorios. Hay que reutilizarlo o unificarlo, para que la traducción global no tape las específicas (`GEN_001` con nombre de entidad, `VCE_004` → 404). Las pruebas existentes de esos 7 repositorios deben seguir en verde sin cambios.
- **N4.** En el directorio, el ADMINISTRADOR ve "los estudiantes sin vínculo académico" de **cualquier** institución. Con más de una institución, eso es una fuga entre instituciones (3.8: "cualquier fuga es severidad crítica"). Hace falta una decisión explícita (DEC), o restringirlo (por ejemplo, solo si existe una única institución, o por el dominio de correo de la institución), y una fila en la matriz de la Fase 3.
- **N5.** En un grupo mixto, el coordinador ve en `usp_consultar_estudiantes_grupo_ambito_paginado` a todos los estudiantes, incluidos los de otro programa. B2 lo corrige con `ufn_estudiantes_grupo_visibles`. Hay que declararlo como hueco transitorio de 3.8 en §8.7, con dependencia de B2 en la misma ventana de entrega, o aplicar ya el filtro por `EstudiantePrograma`, que A ya usa en el directorio.
- **N6.** Solape al actualizar: una sesión que ya se solapaba antes, con datos heredados, impediría ediciones sin relación con el horario (por ejemplo, cambiar el nombre). Hay que validar solo si cambian el horario o el grupo, añadir ese caso a A2-T-09 e informar en RED cuántos solapes hay hoy en la semilla.
- **N7.** Fixture: A2-T-15 (`db-test` verde) debe pasar **con y sin** el fixture aplicado, porque hay pruebas con `TOP 1` (`test_transaction_ownership`, `test_group_capacity_decoupling`, H1 de LB004D) que podrían tomar filas del fixture. Falta una prueba de aplicarlo dos veces. El `_down` debe borrar solo los ids `C1B0…` y nunca una `CULM1-Facultad B` que ya existía y se encontró por nombre. Hay que documentar que `seed-clean-data.ps1` lo borra y que hay que volver a aplicarlo.
- **N8.** B-RED-05 tiene que decir cómo se satisfacen en RED las dependencias (los `InputPort`) de los controladores reales que incluye por expresión regular, sin nombrar tipos que se borran. Por ejemplo, con un `BeanFactoryPostProcessor` de prueba que registre mocks de Mockito para los parámetros de constructor sin resolver. Si no, el RED falla por un error de arranque del contexto y no por 200/201/501.
- **N9.** El decorador `@Primary` debe recibir al delegado con un calificador explícito, para que no se inyecte a sí mismo ni cree un ciclo. `ParametrosPorDefecto` debe ser la única fuente en código: hay que quitar o referenciar el `LIMITE_IP_POR_DEFECTO` duplicado de `MatriculaQrWiringConfiguration`.
- **N10.** `@tamanoPagina = NULL` (A2-C3) lee sin límite. Lo acepto por el WORM, pero solo en los dos SP de grupo, con una prueba de que los demás SP siguen rechazándolo.
- **N11.** CORRECCIONES pide mostrar en pantalla el mensaje del backend para el solape. Falta una spec A2-F que lo compruebe: el modal o formulario de sesión muestra el `message` de un 400 con `SES_0xx`.

---

VEREDICTO: 15 objeciones (bloqueantes: 4)

## Objeciones bloqueantes (corrección exacta esperada)

1. **Hay que aplicar DEC-027 completo.**
   - **(a) BD:** un SP nuevo `usp_consultar_estudiante_por_documento_grupo (@idGrupo, @idTipoIdentificacion, @numeroIdentificacion, @idUsuarioEjecutor, @idCorrelacion)`, con titularidad DOCENTE del grupo dentro del SP (`SEC_002` → 403), búsqueda por documento **exacto**, 0 o 1 fila con datos mínimos (id, nombres, correo enmascarado o el mínimo que necesite el modal, y si ya está matriculado y en qué estado), sin listar. Lleva grant y pruebas A2-T (titular, no titular, documento inexistente, estudiante de otra institución).
   - **(b) Backend:** `GET /api/v1/grupos/{grupoId}/estudiantes/busqueda?documento=` (y tipo), con una regla DOCENTE propia antes del comodín `GET /api/v1/grupos/**`, una fila en `access-catalog.json` y pruebas A2-B.
   - **(c) Frontend:** `attendance-enrollment-modal` (387-410) y `student.service.ts:113-137` pasan a ese endpoint. A2-F-06 se reescribe como RED.
   - **(d)** A2-C1 y §8.6 citan DEC-027: DOCENTE se conserva en `GET /estudiantes` con el ámbito del SP, y `x-roles` se recongela en el golden path 1.2.0 junto con B. Hay que decir qué paquete ejecuta el recongelado (archivo, `.sha256` y `infra.ps1 verify`) y quitar la "deuda de drift" de `TECHNICAL_DEBT.md`.
2. **La migración de A.2 debe ser la 14 (DEC-028).** Hay que renombrar `13_culm001_a_correcciones_fase1_*` a `14_culm001_a_correcciones_fase1_up/down.sql` en §8.2, §6.2, §7 (rollback), A2-T-16 y el commit DB A.2-7 (`feat(db/migrations): agregar migracion 14 de correcciones de fase 1`). Hay que avisar al orquestador del choque con B, cuyo `[SUPUESTO-B-01]` dice 14/15 y debe pasar a 15/16, y de que DEC-025 y su mensaje ("B2 16-17") contradicen DEC-028 (B2 = 17/18).
3. **`SES_010` choca con B.** A2-DB-6, §8.3, A2-T-09, A2-B-14 y §8.6 deben usar un código libre en los dos contratos (B usa SES_010..SES_016; por ejemplo `SES_017`), o el que asigne el orquestador con un rango reservado por paquete que se anote en DEC-028. Antes de congelar, hay que hacer grep también sobre los contratos B y B2, no solo sobre `04_mensaje.sql`.
4. **Desactivar al decano debe quitarle el rol en el RBAC de la BD.** A2-DB-4 debe añadir a la rama Decano de `schema/views/uv_usuario_perfil.sql` el filtro `WHERE d.estado = 1`, con el mismo comentario D1 que la del coordinador, en `schema/` y en la migración 14. El `down` lo restaura. `personaSinRolesActivos` se calcula después de ese cambio. A2-T-12 añade dos casos con el decano desactivado y el usuario activo: `usp_validar_permiso_rbac_usuario_interno @codigoPerfilRequerido = 'DECANO'` devuelve `SEC_001`, y una consulta del decano (por ejemplo `usp_consultar_kpis_decano`) lo rechaza. Al reactivarlo, el RBAC vuelve a pasar.
