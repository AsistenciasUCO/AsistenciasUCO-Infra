---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-10-26
---

# CONTRACT MATRIX — HU064-HU060-HU061-consultas-coordinador

Formulario del [protocolo de alineación contractual](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md). Sin implementación. Sin secretos.

## Evidencia

| Sistema | Repo/versión | Archivo/objeto | Hash/commit | Autoridad |
|---|---|---|---|---|
| DB | gestion-asistencia-db `develop` | `usp_consultar_grupos_paginado`, `usp_consultar_sesiones_grupo_paginado`, `usp_consultar_asistencias_sesion_paginado` (sin cambios) | PR #44 (merge `b935f28`) | OWNER |
| Backend | AsistenciasUCO `develop` | `AsistenciaProgramaJpaRepository`, `CoordinadorAsistenciaProgramaController` | PR #41 (merge `758d555`) | CONSUMER |

## Matriz

| ID | Capacidad | Provider contract | Backend expectation | Status | Evidence | Impact | Owner action |
|---|---|---|---|---|---|---|---|
| C-064 | Grupos del programa | READ_QUERY_RESULTSET + `totalRegistros`; `@idPeriodoAcademico`, `@filtroTexto`, paginación | `GET /api/v1/coordinador/grupos` | MATCH | T-064-01 + `AsistenciaProgramaJpaRepositoryTest` | — | — |
| C-060 | Sesiones del grupo | idem con `@idGrupo`, `@fechaDesde`, `@fechaHasta` | `GET /api/v1/coordinador/grupos/{id}/sesiones` | MATCH | T-060-01 | — | — |
| C-061 | Asistencias de la sesión | idem con `@idSesion`, `@asistio` | `GET /api/v1/coordinador/sesiones/{id}/asistencias` | MATCH | T-061-01 | — | — |

## Tipos y campos

| Campo | DB type/nullability | Java type/nullability | Semántica | Status |
|---|---|---|---|---|
| `codigo` (grupo) | INT | Integer | Código del grupo | MATCH |
| `fechaInicioPeriodoAcademico` / `fechaFinPeriodoAcademico` | DATE | LocalDate | Período del grupo | MATCH |
| `numeroIdentificacion` | INT | String (convertido) | Documento del estudiante | MATCH |
| `asistio` | BIT | boolean (NULL ⇒ false) | Asistencia | MATCH |

## Códigos/enums

`PAG_001` (paginación), `VAL_001` (ejecutor).

## Error semantics

`PAG_001` → `ValidationException` (400); fallo técnico → `DatabaseOperationException`; usuario sin programa de coordinador → 403 en el caso de uso.

## Transacción/atomicidad

Solo lectura; los SP capturan y restauran `SESSION_CONTEXT`.

## Tiempo/UTC

`fechaHoraInicio`/`fechaHoraFin` (DATETIME2) se exponen como LocalDateTime, igual que el resto de consultas de sesión.

## Decisiones requeridas

| ID mismatch | OWNER | CONSUMER | Opciones | Decisión / aprobador / referencia |
|---|---|---|---|---|
| NO APLICA | — | — | — | Sin mismatches abiertos. HU061 parcial frente al catálogo (ver [CLOSURE](CLOSURE.md)). |

## Bloqueos

Ninguno.

## Contrato congelado

APPROVED

Evidence of approval: PR integrados en `develop` con CI remoto en verde; [VALIDATION](VALIDATION.md).
