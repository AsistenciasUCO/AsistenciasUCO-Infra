---
status: draft
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-28
---

# PLAN — LB-002.1C-B1: Backend AS-IS Contract Analysis — registrarEstudianteEnGrupo

Fase 01-planificador / 02-contratos. Analisis contractual.

## Identidad y objetivo

- **Fecha:** 2026-09-28.
- **Rol:** 01-planificador / 02-contratos.
- **Base Git:**
  - Backend: `develop` (HEAD `0bfc02a`)
  - DB: `sergio` (HEAD `bc6aae0`)
  - Frontend: `develop` (HEAD `b0c2225`)
- **Objetivo:** Analizar y formalizar la alineacion de `GrupoRepositorySqlServerAdapter` frente al SP canonico `dbo.usp_registrar_estudiante_en_grupo`, resolviendo la brecha de TD-043 y el conflicto de autorizacion/parametros.

## AS-IS y evidencia

| Dimension | Base de Datos (GestioAsistenciaDB) | Backend (GestioAsistenciaBackend) | Clasificacion |
|---|---|---|---|
| **Comando SQL** | `dbo.usp_registrar_estudiante_en_grupo` (en `schema/`) | `dbo.usp_registrar_estudiante_en_grupo_usuario_no_existente` (en `GrupoRepositorySqlServerAdapter.java:95`) | `MISMATCH` / `MISSING_IN_PROVIDER` |
| **Parametro Tipo Identificacion** | NO lo recibe. Asigna `CC` por defecto internamente. | Envia `@idTipoIdIdentificacion = :idTipoIdIdentificacion` | `MISMATCH` |
| **Parametro Usuario Ejecutor** | `@idUsuarioEjecutor UNIQUEIDENTIFIER` (requerido; `NULL` falla con `GEN_002`) | NO lo envia en `buildRegistrarEstudianteParameters` | `MISSING_IN_CONSUMER` |
| **Autorizacion RBAC en SP** | Exige `@codigoPerfilRequerido = 'ESTUDIANTE'` en el ejecutor (`SEC_001` si no lo tiene) | `SecurityConfig` y `GrupoController` exigen `DOCENTE`, `COORDINADOR` o `ADMINISTRADOR` | `CONTRACT_CONFLICT` / `DECISION_REQUIRED` |
| **Formato de Error DB** | Retorna `DBCODE=<codigo>|<detalle>` con `estadoResultado = 0` | Manejado mediante `CanonicalStoredProcedureExecutor` | `MATCH` |

## TARGET

1. `GrupoRepositorySqlServerAdapter` debe invocar `dbo.usp_registrar_estudiante_en_grupo`.
2. Resolver el conflicto funcional de autorizacion entre el SP de BD y la regla institucional UCO de matricula manual.

## Definition of Ready (DoR)

- [x] Base Git limpia y compilada en Backend (`mvn test-compile` SUCCESS).
- [x] Evidencia del comando real capturada desde `GestioAsistenciaDB`.
- [x] Decision tomada sobre el conflicto RBAC de `@idUsuarioEjecutor` (`ESTUDIANTE` vs `DOCENTE`/`COORDINADOR`) y soporte opcional de `@idTipoIdIdentificacion`.
- **Estado DoR:** `READY` para implementación guiada por TDD conforme a `CONTRACT.md`.
