# CULM-001 · Paquete B — REVIEW-3 (tercera ronda, sección 9.2)

- **Revisor:** Opus independiente, el mismo de REVIEW-1 y REVIEW-2.
- **Fecha:** 2026-11-07.
- **Objeto:** `CONTRACT.md` v3 (1475 líneas) y su §9 "Respuesta a REVIEW-2".
- **Verificación propia:**
  - Lectura de §1.2, §2.7.6, §2.14, §2.16.1, §3.3, §3.10 y §7.1 (R1) del contrato.
  - DEC-027 y DEC-030 en `DECISIONES.md`.
  - Grep en el backend de los usos actuales de `SlidingWindowRateLimiter`.

## 1. Seguimiento de REVIEW-2

| # | Estado | Verificación |
| :--- | :--- | :--- |
| **R2-1** (B) | **RESUELTA** | El texto coincide con el comportamiento que reproduje en `tempdb`. **§2.7.6, paso 4:** el v2 guarda `@trancountEntrada`. Si vale 0, hace `ROLLBACK` cuando `@@TRANCOUNT > 0`, devuelve la tupla `SYS_001` y sale con `@@TRANCOUNT = 0`. Si vale más de 0, hace `THROW` sin `ROLLBACK`, y el adaptador lo traduce a 500 `SYS_001`. **Pruebas:** B1-FES-08a (sin transacción externa: tupla, `@@TRANCOUNT = 0`, 0 sesiones), B1-FES-08b2 (con transacción externa: `THROW`, `XACT_STATE() = -1`, `ROLLBACK` del llamador, 0 sesiones); 08b (paridad) y 08c (ruta feliz) no cambian. R1 está actualizado. |
| **R2-2** (NB) | **RESUELTA**, con un detalle pendiente (R3-1) | El limitador pasa a `infrastructure/ratelimit/` con `superaLimite` (solo lectura, poda sin registrar) y `registrar`. `tryAcquire` no cambia. `AsistenciaQrRateLimitFilter` llama a `superaLimite` antes y a `registrar` en el `finally` cuando la respuesta es ≥ 400 y ≠ 429. Tiene pruebas unitarias. La regla ArchUnit permite usarlo desde `adapter.primary` y `adapter.secondary`, y lo prohíbe desde `application`. |
| **R2-3** (NB) | **RESUELTA** | Línea 801: "la 15". Línea 64: "`usp_consultar_kpis_decano` por horas (comparativas diferidas a D)". |
| **R2-4** (NB) | **RESUELTA**, con un detalle pendiente (R3-2) | DEC-030 está registrada (B = 1.2.0, B2 = 1.3.0) y se cita en §3.10, §5 y §8. |

## 2. Objeciones nuevas (no bloqueantes)

**R3-1. La lista de archivos que cambian por la mudanza del limitador está incompleta.**

§3.3 dice que solo cambian su `import` `MatriculaQrRateLimitFilter`, `VerificacionCorreoRateLimitFilter` y `MatriculaQrWiringConfiguration`. El grep encuentra además:
- `infrastructure/config/wiring/VerificacionCorreoWiringConfiguration.java`
- `infrastructure/config/security/SecurityConfig.java`
- `src/test/.../controller/filter/SlidingWindowRateLimiterTest.java`, que debe moverse al paquete nuevo junto con la clase.
- `VerificacionCorreoRateLimitFilterTest.java` y `MatriculaQrControllersTest.java`.

El compilador lo detectaría igual, pero el PR debe listar archivo por archivo.

- **Corrección:** completar la lista en §3.3 y declarar que el cambio es solo de `import` o de paquete, sin cambios de comportamiento ni de aserciones.

**R3-2. Falta el cambio de DEC-027 en la versión 1.2.0 que describe B.**

DEC-030 dice que la 1.2.0, que se congela con B, incluye "DOCENTE en `x-roles` de `/estudiantes` por DEC-027". DEC-027 es del paquete A y dice "versión 1.2.0 junto con B". Pero §3.10, punto 6, de B describe la 1.2.0 solo con `Sesion`/`SesionV2` y el 409 de `/asistencias/lote`. Si nadie lo dice en B, el recongelado de B puede omitir el cambio de A, o pisarlo.

- **Corrección:** en §3.10, punto 6, añadir a la línea de `info.description` y a la lista de pruebas el cambio de DEC-027: DOCENTE en `x-roles` de `GET /api/v1/estudiantes` y `/{id}`, y `OpenApiEstudiantesDirectoryConformanceTest`.
  - El texto lo aporta A si se integra antes.
  - Si A aún no está integrado, B no lo inventa: deja la 1.2.0 abierta hasta que entre A, o el orquestador decide en `DECISIONES.md` cuál de los dos publica la 1.2.0.

Ninguna de las dos cambia reglas, datos ni pruebas de negocio. Se pueden corregir al congelar, sin otra ronda de revisión, si el orquestador así lo decide.

---

VEREDICTO: 2 objeciones (bloqueantes: 0)
