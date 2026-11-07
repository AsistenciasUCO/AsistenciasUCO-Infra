---
status: review
type: contract-review
work-item: CULM-001
paquete: A
reviewer: Opus independiente (CULM-001 §9.2), tercera ronda
last-reviewed: 2026-11-07
---

# REVIEW-3: CONTRACT v4 del paquete A

Revisé la v4 (875 líneas): la §10 (respuesta a REVIEW-2) y DEC-032, más DEC-028, DEC-031 y DEC-033. La comparé con los contratos congelados de B (`paquetes/B-tomas-qr-sesiones/CONTRACT.md` v4) y B2 (`paquetes/B2-asignaturas-nm/CONTRACT.md`). Comprobé en los worktrees lo que me pareció dudoso.

## 1. Bloqueantes de REVIEW-2

| # | Resultado | Comprobación |
| :--- | :--- | :--- |
| B1 DEC-027 en 4 capas | CUMPLE, con la **objeción bloqueante 1** | Las cuatro capas están en el contrato. **BD:** `usp_buscar_estudiante_por_documento_grupo` (A2-DB-9), con titularidad en el SP (`SEC_002`, 403), documento exacto (0 o 1 fila), datos mínimos, correo enmascarado y el estado de la matrícula en el grupo; tiene grant y pruebas A2-T-17. **Backend:** `GET /grupos/{grupoId}/estudiantes/busqueda`, con regla DOCENTE antes de `GET /grupos/**` y fila en `access-catalog.json`; pruebas A2-B-17 y A2-B-18. **Frontend:** el modal y `student.service` usan el endpoint nuevo, con A2-F-06 RED. **Contrato:** A publica 1.2.0 (A2-C1). Lo verifiqué: `openapi-golden-path.yaml` está en `1.1.0` (línea 5) con `x-roles: [COORDINADOR, ADMINISTRADOR]` (línea 184). La copia del Backend es idéntica (`diff` sin salida). `OpenApiEstudiantesDirectoryConformanceTest.java:51` fija esos 2 roles. `GET /api/v1/estudiantes/{id}` no está en el golden path, y `BACKEND_GOLDEN_PATH_CONTRACT.md` no nombra `/api/v1/estudiantes`. La pieza nueva A2-B-19, que resuelve el correo en el servidor, abre un hueco de ámbito: ver la objeción bloqueante 1 |
| B2 Migración 14 y semillas 33 | CUMPLE | `14_culm001_a_correcciones_fase1_*` aparece en §2.4, §6.2, §7, §8.2, A2-T-16 y §8.8, sin restos de `13_culm001_a_correcciones` (grep). Las semillas `33_culm001_a_catalogos.sql` y `33_culm001_a_mensajes.sql` están dentro del 33 de A. Encaja con DEC-028: el contrato B, ya congelado, usa 15/16 y 34-36 (`[SUPUESTO-B-01]`, línea 16), y B2 usa 17/18 y 37-39 |
| B3 `SES_017` | CUMPLE | No queda ningún `SES_010` propio de A (solo aparece en la tabla de la §10). B usa SES_010..SES_016 y B2 no usa códigos `SES_*`. Coincide con DEC-031 §1 |
| B4 Filtro `d.estado = 1` | CUMPLE en `up` y en las pruebas, con la **objeción bloqueante 2** en el `down` | A2-DB-4 añade el filtro a la rama Decano de `uv_usuario_perfil` (líneas 22-30) con el comentario D1, y `personaSinRolesActivos` se calcula después. A2-T-12 añade `SEC_001` en el RBAC `DECANO`, la ausencia de la fila `DE`, el rechazo de `usp_consultar_kpis_decano` y la vuelta al reactivar. Pero el párrafo del `down` de A.2 (línea 657) no incluye la vista y no fija el orden respecto del `DROP COLUMN` |

## 2. No bloqueantes de REVIEW-2 (N1-N11)

Las 11 están aplicadas en el texto:

| Objeción | Dónde se aplicó |
| :--- | :--- |
| N1 | Origen `limiteIp` con los cid reales; valor por defecto en `limiteIp`; `include-stacktrace = never`; A2-B-08 en el filtro |
| N2 | 51 rutas, no 57 |
| N3 | Sobrecarga de `JpaQueryExecutor` con `DbCodeTranslator`, solo en los repositorios de A.2 |
| N4 | Coincide con DEC-031 §3 (directorio del administrador, 8.2.1) |
| N5 | Coincide con DEC-031 §4 (8.2.2, también en asistencias) |
| N6 | La validación de solape se hace solo si cambian el horario o el grupo; renombrar una sesión con solape heredado está en A2-T-09 |
| N7 | A2-T-15 con y sin fixture; A2-T-18; el `_down` borra solo los ids `C1B0…` |
| N8 | `BeanFactoryPostProcessor` de mocks |
| N9 | `@Qualifier("parameterCatalogDelegado")`; se elimina `LIMITE_IP_POR_DEFECTO` |
| N10 | A2-T-06b |
| N11 | A2-F-09 |

## 3. Coherencia con DEC-028, DEC-031, DEC-032 y los contratos de B y B2

- **DEC-028/031:** CUMPLE. R-A2-8 está desactualizado: el contrato B congelado (DEC-033) ya usa 15/16 (ver N2).
- **DEC-032:** A publica 1.2.0, B publica 1.3.0 y B2 publica 1.4.0. CUMPLE en el contenido, pero el título del commit de contrato no es el corto (N1).
- **Los 3 SP de ámbito:** sus nombres coinciden con los de B2. `usp_consultar_directorio_estudiantes_paginado`, `usp_consultar_estudiantes_grupo_ambito_paginado` y `usp_consultar_asistencias_grupo_ambito_paginado` aparecen 15 veces en B2. B2 extiende la rama del coordinador (`COO_003` para un `programaId` ajeno) en 1.4.0, sobre la base de A. Sin choque de códigos: A usa `REV_006`-`REV_008`, `DEC_002`/`DEC_003` y `SES_017`; B2 usa `COO_002`/`COO_003`, `ASI_006` y `MQR_008`.

---

## Objeciones no bloqueantes

- **N1.** El commit `docs(contratos): publicar golden path 1.2.0 con docente en el directorio de estudiantes` (§6.2, línea 487, y §8.8, línea 816, en Infra y Backend) tiene **87 caracteres**. Incumple la regla de 72 que el propio contrato fija en la línea 493, y `contratos` no es un alcance normalizado (B usa `docs(contracts)`). Hay que cambiarlo por `docs(contracts): publicar golden path 1.2.0 con docente en estudiantes` (70 caracteres), en los dos repos.
- **N2.** R-A2-8 y la §10 (B2) siguen diciendo que el contrato B "todavía dice 14/15". El contrato B congelado ya dice 15/16. Hay que marcar R-A2-8 como resuelto (DEC-031 §2 y DEC-033).
- **N3.** A2-DB-9 devuelve a cualquier docente titular un estudiante **sin vínculos**, con datos mínimos y correo enmascarado. Lo acepto, porque la búsqueda es exacta y hace falta para no duplicar la cuenta. Hay que anotar en A2-C1 que es una excepción deliberada al fail-closed de DEC-031 §3 (directorio) y añadir la fila correspondiente a la matriz de la Fase 3.
- **N4.** DEC-033 mueve `SlidingWindowRateLimiter` a `infrastructure/ratelimit/` en B, y A.2-4 lo reutiliza en su paquete actual. Como A se mezcla primero, hay que anotar en §8.7 que B actualiza el import de `OperacionAutenticadaRateLimitFilter` al mezclar.

---

VEREDICTO: 6 objeciones (bloqueantes: 2)

## Objeciones bloqueantes (corrección exacta esperada)

1. **A2-B-19 deja que el docente matricule a cualquier usuario sabiendo solo su documento.** El correo se resuelve en el servidor con `UsuarioRepositoryPort` por documento. El método que existe, `consultarUsuarioPorIdentificacion`, no exige que haya fila `Estudiante` ni que la institución coincida. Con `correo` vacío, un docente titular podría matricular en su grupo a un usuario de otra institución o con otro rol (docente, coordinador). Antes hacía falta conocer su correo. Esto contradice el alcance que A2-DB-9 aplica a propósito.
   - **Corrección:** la resolución usa los mismos criterios que A2-DB-9. Lo preferible es que el caso de uso llame a `usp_buscar_estudiante_por_documento_grupo` (titularidad e institución dentro del SP). Si da 0 filas: 400 `FIELD_REQUIRED` (`correo`) y no se resuelve nada. El correo real se obtiene a partir del `idEstudiante` devuelto, nunca a partir de un documento libre.
   - **Pruebas que añadir:** a A2-B-19, el documento de un usuario de otra institución y el de un usuario sin fila `Estudiante`, ambos con resultado 400 y sin llamar al SP de matrícula. A A2-T-17, el mismo caso en BD.
2. **El `down` de A.2 debe restaurar `uv_usuario_perfil` antes de borrar `Decano.estado`.** El párrafo del `down` de A.2 (línea 657) solo restaura `uv_decano` y hace `DROP COLUMN estado`. La vista `uv_usuario_perfil` filtrada por `d.estado` no está en la lista. Si se borra la columna con la vista filtrada todavía en uso, la vista queda inválida y falla **todo** el RBAC (`usp_validar_permiso_rbac_usuario_interno` la lee en cada SP).
   - **Corrección:** el `down` hace `CREATE OR ALTER VIEW dbo.uv_usuario_perfil` y `dbo.uv_decano` como estaban en `65a4998`, y **después** `ALTER TABLE dbo.Decano DROP CONSTRAINT DF_Decano_estado, COLUMN estado`. El `up` hace lo contrario: primero la columna, después las vistas.
   - **Pruebas que añadir:** A2-T-16 comprueba, después del `down`, que `usp_validar_permiso_rbac_usuario_interno` con un usuario `DECANO` y otro `DOCENTE` devuelve `estadoResultado = 1`, y que `SELECT TOP 1 * FROM dbo.uv_usuario_perfil` no da error.
