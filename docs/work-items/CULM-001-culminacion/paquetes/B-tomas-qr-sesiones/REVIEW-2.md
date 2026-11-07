# CULM-001 · Paquete B — REVIEW-2 (segunda ronda, sección 9.2)

**Datos de la revisión**

| Campo | Valor |
| :--- | :--- |
| Revisor | Opus independiente, el mismo de REVIEW-1 |
| Fecha | 2026-11-07 |
| Objeto | `CONTRACT.md` v2 (1453 líneas), con la §8 "Respuesta a REVIEW-1" |
| Decisiones del orquestador tenidas en cuenta | DEC-024 (precisión de DEC-012), DEC-028 (numeración), DEC-029 (B2 congelado), SSE de estudiantes en C, diferidos a D y NB-7 parcial |

**Qué verifiqué por mi cuenta**
- Grep en los worktrees `C:\Proyectos\GestionAsistencia-CULM001\<repo>`.
- Lectura de `SlidingWindowRateLimiter.java`, de los contratos A y B2 (numeración y versión) y del catálogo de HUs.
- Tres pruebas en `tempdb` del contenedor `sql_server_asistencias`, sin tocar la BD del proyecto: `INSERT … EXEC` con y sin transacción externa, y el orden de la conversión a NOT NULL.

---

## 1. Seguimiento de las bloqueantes de REVIEW-1

| # | Estado | Verificación |
| :--- | :--- | :--- |
| B-1 `ALTER COLUMN` 4922 | **RESUELTA** | §2.3 y §2.14: los tres dependientes de `toma` se crean solo con `AllowsNull = 0`, tanto en `tables/` como en `zz_foreign_keys.sql`. La semilla 36 y `16_up` siguen el orden backfill → `DROP` dependientes → `ALTER` → `DROP UX` antiguo → recrear, en una transacción y solo si `AllowsNull = 1`. El guard 50002 y el `UX` antiguo quedan condicionados. B2-MIG-05 cubre el doble despliegue. El orden coincide con el que probé (el `ALTER` solo falla si un índice o una FK ya usan la columna). |
| B-2 Manifiesto de Infra | **RESUELTA** | §2.15: hash efectivo = `SUPERSEDES` de UTC-D06. Las dos líneas que hoy fallan pasan a `ef9de7e9…` y `7217604b…`, que coinciden con `DB_UTC_D06_POST_FREEZE_MANIFEST.sha256` (líneas 3 y 4) y con lo que calculó `verify-contracts.ps1` en REVIEW-1. `-Mode Generate` queda para después de 9.2, con el diff revisado. |
| B-3 Post-freeze de B | **RESUELTA** | Solo líneas `WORK_ITEM` y solo objetos propios de B. Ninguno de los SP que modifica B2 (KPI, alertas, bitácora, consolidado, comparativas, `_asistencias_sesion_paginado`, `_sesiones_grupo_paginado`, `uv_resumen_*`) entra. `Verify` recorre `DB_*_POST_FREEZE_MANIFEST.sha256` y no hay espejo sin verificar. |
| B-4 Pruebas y fixtures | **RESUELTA** | §2.16.3 lista exactamente: la aserción de `test_attendance_commands.sql:202`, las 5 limpiezas de `Sesion` que encontré, el helper de limpieza, los fixtures backend, las 21 + 2 inserciones y B2-SEG-02. |
| B-5 `REVOKE` del SP autónomo | **RESUELTA** | Sin `REVOKE` ni `GRANT` en `16_down`. `verify_runtime_role_login.ps1:31` y `rol_asistencias_runtime.sql` quedan intactos. |
| B-6 `INSERT … EXEC` | **RESUELTA en el SP**; queda una objeción en su prueba (R2-1) | Se quitan `SES_015`, el requisito `@@TRANCOUNT = 0` y `NOT_SUPPORTED`. El `CATCH` traduce el 3915 y respeta el ownership (THROW si la transacción no es propia). |
| B-7 Cierre masivo | **RESUELTA** | `COUNT(DISTINCT a.sesion)` en el `SELECT` y en el `HAVING`, sin otro cambio. El `16_down` restaura `COUNT(da.id)`. B2-HOR-10 cubre los dos casos (3 tomas en una sesión → sigue `A`; 3 sesiones → `CI`). |
| B-8 DEC-012 | **RESUELTA** | DEC-024 está registrada en `DECISIONES.md` con la opción (b) y el contrato la cita en [SUPUESTO-B-05] y §2.6. |
| B-9 Límite por IP | **RESUELTA en la regla**; precisión pendiente en R2-2 | La clave por IP cuenta solo los rechazos (≥ 400 y ≠ 429), con el parámetro `LIMITE_FALLIDOS_IP_POR_MINUTO`. Se añade la ronda de 20 grupos × 40 desde la misma IP sin 429. |

## 2. Seguimiento de las no bloqueantes

| # | Estado | Nota |
| :--- | :--- | :--- |
| NB-1 `ERR_SESION_CANCELADA` | Resuelta | Se usan `examples` dentro del `$ref` único del 409 |
| NB-2 Unidades | Resuelta | Columnas de sesión `sesionesAsistidas`, `sesionesConFaltaSinJustaCausa` y `sesionesConExcusa` para los consumidores diferidos; las comparativas no mezclan tomas con sesiones |
| NB-3 Orden de controles | Resuelta | |
| NB-4 p95 de 5×40 | Resuelta | Métrica y alternativa `HOLDLOCK` aprobadas de antemano |
| NB-5 Festivos en la misma fecha | Resuelta | Fusión de nombres y prueba de 2038 con 18 filas |
| NB-6 Cobertura de festivos | Resuelta | Las 38 fechas (19 por año) |
| NB-7 Cancelación retroactiva | Resuelta por decisión del orquestador | Futuras o sin asistencia; `SES_016` y B1-CAN-08. Se registra el riesgo R16 |
| NB-8 `returnUrl` | Resuelta | `sessionStorage` y spec del guard |
| NB-9 Cabecera sin detalle | Resuelta | B2-HOR-09 y control en `16_up` |
| NB-10 Versión del golden path | Resuelta en B | Coordinación pendiente con B2 en R2-4 |
| NB-11 SSE del estudiante | Resuelta por alcance | Pasa a C; `RealtimeAudienciaPolicy` compara el tipo con igualdad exacta |

**Numeración (DEC-028): CUMPLE.**
- B usa 15/16 (`culm001_b1`/`culm001_b2`) y las semillas 34-36.
- B2 usa 17/18 (`culm001_b2nm`, contrato v4, líneas 146-182) y la semilla 37.
- A usa 13; no hay choque con B.
- Todas las pruebas se registran por nombre exacto, sin el comodín `culm001_b2*`.
- En el orden de despliegue (`Sort-Object Name`), `rol_asistencias_runtime_culm001_b2.sql` y `…_culm001_b2nm.sql` no se pisan.
- Fuera del alcance de B, para el orquestador: el contrato A llama `13_culm001_a_correcciones_fase1_*` (línea 604) a lo que DEC-028 reserva como migración 14.

**Diferidos a D: CUMPLE con 3.3.** HU061, HU103, HU134 y HU139 no están en la lista de 3.3. HU106 sale de `usp_consultar_kpis_decano` (`tasaRetencion`), que sí pasa a horas en B.

---

## 3. Objeciones nuevas de la segunda ronda

**R2-1 (BLOQUEANTE): la prueba B1-FES-08 espera algo imposible con transacción externa (verificado).**

B1-FES-08 espera, "con y sin transacción externa", `estadoResultado = 0` con `SYS_001` y el `@@TRANCOUNT` igual al de entrada.

Lo reproduje con un SP que imita al congelado (`SET XACT_ABORT ON`, `BEGIN TRANSACTION`, error y `ROLLBACK` en el `CATCH`) y un v2 que lo invoca con `INSERT … EXEC`:
- **Sin transacción externa:** el v2 captura el 3915 con `@@TRANCOUNT = 0` y puede devolver la tupla. Es lo que dice el contrato.
- **Con transacción externa:** el `CATCH` del v2 ve `XACT_STATE() = -1` y `@@TRANCOUNT = 2`, porque el `BEGIN TRANSACTION` del SP congelado queda sin cerrar al fallar su `ROLLBACK`. El llamador recibe el error 266 con la transacción condenada. Entonces el v2 no puede devolver una tupla ni dejar `@@TRANCOUNT` igual al de entrada; el propio §2.7.6, paso 4, ya manda hacer `THROW` en ese caso.

Tal como está, esa prueba RED nunca podría pasar a GREEN sin "ajustarla", y AGENTS.md §4 prohíbe ajustar pruebas por conveniencia.

**Corrección exacta:**
1. B1-FES-08 se divide en dos casos:
   - **(a) Sin transacción externa:** tupla `estadoResultado = 0` con `SYS_001`, `@@TRANCOUNT = 0` y 0 sesiones del grupo.
   - **(b) Con transacción externa:** el v2 hace `THROW` sin `ROLLBACK`; el llamador observa en su `CATCH` `XACT_STATE() = -1`, ejecuta `ROLLBACK` y quedan 0 sesiones del grupo.
2. En §2.7.6, paso 4, se fija la condición de reversión por el nivel de entrada y no por una bandera de la fase 2. El v2 guarda `@trancountEntrada = @@TRANCOUNT` al empezar y, en el `CATCH`:
   - si `@trancountEntrada = 0` y `@@TRANCOUNT > 0`, hace `ROLLBACK` y devuelve `SYS_001`;
   - si `@trancountEntrada > 0`, hace `THROW`.

**R2-2 (no bloqueante): el limitador actual no permite "consultar sin consumir".**

`SlidingWindowRateLimiter` (`infrastructure/adapter/primary/controller/filter/SlidingWindowRateLimiter.java:40`) solo expone `tryAcquire(clave, limite)`, que consulta y registra en un solo paso. El filtro de B-9 necesita consultar el contador antes de la llamada y registrar solo en el `finally` si la respuesta fue un rechazo.

Además, §3.3 pone a `SlidingWindowLimitadorIntentosAdapter` (adaptador secundario) a reutilizar una clase del paquete del adaptador primario.

**Corrección:**
- Añadir a `SlidingWindowRateLimiter` dos métodos: `superaLimite(clave, limite)` (solo lectura) y `registrar(clave)`, con pruebas unitarias. `tryAcquire` se conserva sin cambio para la matrícula QR.
- Moverlo a un paquete compartido de infraestructura (por ejemplo `infrastructure/support/ratelimit/`), o dejar el límite por IP solo en el filtro y crear el adaptador secundario con su propia instancia.
- La prueba ArchUnit debe pasar.

**R2-3 (no bloqueante): textos que quedaron de la v1.**
- §2.14, línea 799: "y la 14 en `test_culm001_b1_sesion_cancelada.sql`" debe decir **15**.
- §1.2, fila HU102/HU106: "`usp_consultar_kpis_decano` y comparativas por horas" debe decir "`usp_consultar_kpis_decano` por horas (comparativas diferidas a D)".

**R2-4 (no bloqueante): la versión del golden path de B2.**

El contrato B2 congelado (v4, línea 522) dice "1.2.0 (CULM-001-B2NM), o a la menor siguiente si A ya publicó una 1.1.x". DEC-029 menciona "1.2.0/1.3.0" sin decir cuál usa cada paquete. B fija B = 1.2.0 y B2 = 1.3.0, pero eso aún no consta como decisión.

**Corrección:** registrar en `DECISIONES.md` una línea: "golden path: B = 1.2.0, B2 = 1.3.0 (B2 se rebasa sobre B); la cláusula 'menor siguiente' de B2 v4 se interpreta así". No hace falta tocar B2.

---

VEREDICTO: 4 objeciones (bloqueantes: 1)

**Bloqueante:**

1. **R2-1:** B1-FES-08 se divide en (a) sin transacción externa y (b) con transacción externa, con los resultados de la sección 3. En §2.7.6, paso 4, el v2 decide si revierte según `@trancountEntrada`: con 0 hace `ROLLBACK` y devuelve `SYS_001`; con más de 0 hace `THROW`.
