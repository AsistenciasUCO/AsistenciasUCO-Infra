---
status: suspended
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-28
---

# STATUS — LB-002.1C-B1: registrarEstudianteEnGrupo

Fase 02-contratos / SUSPENDED.

## 1. Identidad y alcance

- **Work item:** LB-002.1C-B1-registrar-estudiante
- **Fecha:** 2026-09-28.
- **Estado:** SUSPENDED / DEFERRED.

## 2. Motivo de Suspension

El procedimiento almacenado en BD (dbo.usp_registrar_estudiante_en_grupo) se mantiene en su estado original estricto de auto-matrícula de estudiante (@codigoPerfilRequerido = 'ESTUDIANTE').

La decisión de diseño sobre si extender este procedimiento mediante soporte multi-rol en usp_validar_permiso_rbac_usuario_interno o crear un procedimiento público dedicado para matrícula institucional por parte de Docente/Coordinador queda diferida (DEFERRED) para una fase posterior con consenso de diseño.

## 3. Estado de Repositorios

- **GestioAsistenciaDB:** Revertido a su estado original (git checkout HEAD).
- **GestioAsistenciaBackend:** Código adaptado al SP canónico con cobertura unitaria completa (1291/1291 PASS).
