# CULM-001 · Paquete B2 — REVIEW-3 (tercera ronda §9.2)

> **Fecha:** 2026-11-07. **Revisor:** el mismo Opus independiente de REVIEW-1 y REVIEW-2.
> **Objeto:** `CONTRACT.md` v3 (783 líneas) y su §9, "Respuesta a REVIEW-2".
> **Verificación:**
> - grep sobre la v3: ya no queda ninguna mención a "misma migración";
> - lectura de §2.3.1–§2.3.4, B2NM-08, B2NM-12, §3.1, §3.3, §5.2, §6.1, §6.2, §6.4 y §7;
> - comparación con los CONTRACT de A y B y con `DECISIONES.md` (DEC-025).

## 1. Bloqueantes de REVIEW-2

| Objeción | Estado | Comprobación |
| :--- | :--- | :--- |
| **O2-B1** DEC-025 | **Resuelta** | Ver los puntos que siguen a la tabla |
| **O2-B2** D-04 | **Resuelta** | Ver los puntos que siguen a la tabla |

**Cómo queda resuelta O2-B1:**
- **R4 (l.33):** describe dos migraciones.
- **Migración 16 (§2.3.1):**
  - paso 5: `ALTER COLUMN ... NULL` con SQL dinámico, conservando la FK;
  - no verifica ni borra; un segundo `up` no hace nada.
- **`down` de la 16 (§2.3.2):**
  - `52903` si la columna no existe, con la indicación "ejecute antes el down de la 17";
  - `52902` contando vínculos activos e inactivos;
  - llena la columna y restaura `NOT NULL`.
- **Migración 17 (§2.3.3):** idempotente; la verificación `52901` y el `DROP CONSTRAINT`/`DROP COLUMN` van en una sola transacción.
- **`down` de la 17 (§2.3.4):** columna `NULL` llenada desde la puente, con la FK recreada.
- **`schema/`:** equivale al estado posterior a la 17; B2NM-16 lo fija.
- **B2NM-12:** prueba la secuencia completa en 11 pasos, incluido el fallo forzado de la 17 con la columna intacta.
- **Orden y ventana:**
  - rollback 17 → 16 en §6.2;
  - en §5.2, la 17 se aplica solo con `db-test` de la 16 en verde;
  - el `BREAKING CHANGE` va en el commit 9 (migración 17);
  - riesgo 5 y §6.4.1 actualizados.

**Cómo queda resuelta O2-B2:**
- D-04 está tachado en §7.
- `GET /coordinador/estudiantes` pasa a `usp_consultar_directorio_estudiantes_paginado` (A.2 + extensión B2), sin SP nuevo (§1.4 l.75, §3.1 l.479, §3.3 l.513).
- Se retiran el JPQL y `findProgramaIdByCoordinadorUsuario`.
- B2NM-08 cubre la lista de un coordinador de dos programas.
- Los diferibles que quedan (D-01..D-03, D-05..D-11) no incumplen 3.8/3.9: no producen fuga ni contradicen R6, R9 o S4 en la API.

## 2. No bloqueantes de REVIEW-2

| Objeción | Estado |
| :--- | :--- |
| O2-N1 (numeración y 403 de A.2) | Atendida en parte: la nota de §1.4 fija el 403 y pide alinear A.2. **La numeración que declara no coincide con B** (ver O3-N1) |
| O2-N2 (T-02 de A) | Resuelta (§2.9, l.451: pasa de 19 a 21 columnas) |
| O2-N3 (comodín de prefijo) | Resuelta (§5.2, l.642: comprobación con `git grep` antes del RED) |

## 3. Objeciones de esta ronda (no bloqueantes)

**O3-N1. La reserva de números de migración contradice el CONTRACT de B.**
- La v3 dice (l.77 y §9 O2-N1): "A usa las migraciones `13` y `14` (A.2); B, la migración `15`".
- El CONTRACT de B usa `14_culm001_b1_sesion_cancelada_festivos_*` (l.776) y `15_culm001_b2_tomas_asistencia_qr_*` (l.779).
- `DECISIONES.md` no registra ninguna reserva.
- Si A.2 toma la `14`, B se desplaza a `15`/`16` y la B.2 chocaría con la `16` de B2.

Corrección: que el orquestador registre la reserva en DECISIONES o ESTADO. Dos opciones:
- A.2 = siguiente libre después de 17, B = 14/15, B2 = 16/17;
- o una numeración equivalente sin solapes.

Después, la l.77 y §9 se corrigen al texto registrado. El control de números libres antes del RED (§2.2) mitiga el riesgo, pero no reemplaza la reserva.

**O3-N2. El `down` de la 16 restaura valores obsoletos si un vínculo cambió de semestre durante la ventana 16 → 17.**
- El paso 3 de §2.3.2 llena solo las filas en `NULL`.
- Una asignatura antigua cuyo vínculo se movió de semestre con `usp_actualizar_asignatura` durante la ventana conserva en la columna el SPE anterior. El `down` la devolvería al semestre viejo.
- Mientras exista esa FK, ese valor obsoleto también puede impedir que `usp_quitar_semestre_plan_estudio` borre el SPE antiguo, con un error de FK en lugar de `PLA_006`.

Corrección:
- (a) En el paso 3 del `down` de la 16, el `UPDATE` cubre **todas** las filas desde el único vínculo, no solo las que están en `NULL`.
- (b) Durante el estado 16, el SP que mueve o desvincula un vínculo pone en `NULL` la columna de esa asignatura (SQL dinámico con `COL_LENGTH`). Así la FK nunca apunta a un SPE que la puente ya no usa.
- (c) B2NM-12 agrega este caso: después del paso 2, mover el semestre de una asignatura antigua, quitar el SPE viejo (`PLA_006` o éxito, nunca un error de FK), y comprobar que el `down` de la 16 la restaura con el semestre nuevo.

---

VEREDICTO: 2 objeciones (bloqueantes: 0)

O2-B1 y O2-B2 quedan resueltas. O3-N1 y O3-N2 se pueden corregir al congelar o en el RED, sin otra ronda de revisión.
