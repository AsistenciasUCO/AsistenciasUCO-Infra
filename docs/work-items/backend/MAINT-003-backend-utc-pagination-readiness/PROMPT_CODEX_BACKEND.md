# Prompt backend exclusivo — ejecutar antes que frontend

Actúa como backend developer senior y QA de integración en `alejovh12/AsistenciasUCO` (Java25/Spring Boot4/JPA-only/SQL Server) y `johnjduque/gestion-asistencia-db` (fuente de verdad; NO cambiar shape unilateralmente).

## Orden
1. Leer AGENTS.md, DoR, ADR-003, DB_BASELINE_CONTRACT, MAINT-001/002 y MAINT-003 (PLAN, TEST_PLAN, BACKEND_TO_FRONTEND_HANDOFF). Auditar PR18 `39e34c49` y PR19 `3985b0ac`; no merge. Crear ramas de validación derivadas de cada PR si hace falta y mantener worktrees aislados.
2. Entorno real: Docker SQL Server 2022, Keycloak y backend Java25. Identificar conexión sin revelar secretos; backup/snapshot de DB de pruebas y fixture determinística >=11 estudiantes, multigrupo, identificaciones diversas; no tocar la DB compartida ni producción. Confirmar vistas físicas `uv_estudiante_identidad,uv_estudiante,uv_usuario`.
3. Ejecutar `mvn clean verify`, `mvn -Pintegration verify` y específicamente `CoreViewQueriesJpaParityIT` + `CatalogJpaParityIT`; cero fallos, **cero skips en tests focales**. Revisar resultados reales (no asumir que CI ejecuta IT).
4. Ejecutar HTTP real con JWT (rol COORDINADOR, ADMINISTRADOR, DOCENTE, ESTUDIANTE): filtros y páginas 0/1/2 size5 y size100, límite invalido, totalItems/totalPages, orden, IDs únicos, sin filtrado in-memory, cambio de criterios vuelve a página0. Capture status/body desensibilizado y SQL SELECT de prueba. No inventes 200/401/403/501.
5. UTC: caracterizar `Sesion.datetime2` y código legacy v1; decidir con owner (NO asumir que históricos son UTC por existir comentario). Preparar ADR contratada para v2 con offsets RFC3339; implementar endpoints y adapter `HttpUtcInstantCodec` sólo después de contrato aprobado, unit+OpenAPI+HTTP+SQL IT; RFC3339 +02/+01/-05 y cambios DST; GET Z, DB UTC, sin doble conversión. Definir zona institucional para horarios recurrentes; no cambiar LocalTime ciegamente. No hacer migración DDL ni rewrite de históricas sin autoridad DB.
6. Regresión: Maven Java25, ArchUnit, JaCoCo, Sonar, CodeQL, Trivy y JWT ownership, SSE. Documentar todos los comandos y capturar evidencia validada. Corregir fallos pequeños por micro-PR, sin bajar umbrales ni borrar tests.
7. Publicar acta de aceptación `BACKEND_READY_FOR_FRONTEND.md` con SHA, contrato HTTP definitivo, fecha y roles, resultados en SQL real, estado de históricos, riesgos, evidencias y rollback. **No declarar READY** mientras falte una prueba o aprobación.

STOP CONDITIONS: sin fixture, token, DB aislada o contrato UTC aprobado => BLOCKED con causa, no false PASS. NO merge PR18, PR19 ni UTC sin autorización explícita del usuario.
