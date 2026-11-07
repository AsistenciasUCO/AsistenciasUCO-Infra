---
status: review
type: contract-review
work-item: CULM-001
paquete: A
reviewer: Opus independiente (CULM-001 §9.2), verificación final
last-reviewed: 2026-11-07
---

# REVIEW-4: verificación final del CONTRACT v5 del paquete A

Alcance: comprobar en el texto de la v5 (891 líneas, §11) que quedaron bien resueltas las 2 objeciones bloqueantes y las 4 no bloqueantes de REVIEW-3.

| Objeción | Resultado | Dónde |
| :--- | :--- | :--- |
| **B1** A2-B-19 matriculaba a cualquier usuario por documento | CUMPLE | §8.4 A.2-15: con `correo` vacío, el caso de uso llama primero a `buscarEstudiantePorDocumento`, que ejecuta `usp_buscar_estudiante_por_documento_grupo` con titularidad, fila `Estudiante` e institución dentro del SP. Con 0 filas responde 400 `FIELD_REQUIRED` (`correo`) sin llamar al SP de matrícula. El correo se obtiene de `consultarCorreoPorEstudiante(idEstudiante)`, que no se expone por HTTP. `consultarUsuarioPorIdentificacion` queda excluido de forma explícita. A2-B-19 cubre otra institución, usuario sin fila `Estudiante`, documento inexistente y docente no titular (403), con `verify(..., never())` y una comprobación por reflexión. A2-T-17 cubre los mismos casos en BD |
| **B2** `down` de la 14: vistas antes del `DROP COLUMN` | CUMPLE | §8.2.3, línea 657. El orden es: SP, después `CREATE OR ALTER VIEW` de `uv_usuario_perfil` y `uv_decano` de `65a4998`, después la guardia `sys.sql_expression_dependencies` (`THROW 53320`) y por último `DROP CONSTRAINT`/`COLUMN`. El `up` sigue el orden inverso. A2-T-16 comprueba después del `down` que las dos vistas se pueden consultar, que el RBAC `DECANO` y `DOCENTE` da `estadoResultado = 1` y que `COL_LENGTH IS NULL`. Comprueba también que, tras el segundo `up`, el decano desactivado vuelve a dar `SEC_001` |
| N1 Título del commit de contrato | CUMPLE | `docs(contracts): publicar golden path 1.2.0 con docente en estudiantes` (70 caracteres), en las líneas 487, 796 y 817. No queda ningún `docs(contratos)` (grep = 0) |
| N2 R-A2-8 desactualizado | CUMPLE | R-A2-8 queda "Resuelto" (DEC-031 §2, DEC-033), en la línea 778 |
| N3 Estudiante sin vínculos | CUMPLE | A2-C1 lo declara como excepción deliberada a DEC-031 §3, con su fila en la matriz de la Fase 3. A2-T-17 comprueba "sin vínculos → 1 fila" |
| N4 `SlidingWindowRateLimiter` | CUMPLE | R-A2-9 (línea 779): B actualiza el import al mezclar |

No encontré regresiones en las secciones tocadas.

VEREDICTO: sin objeciones
