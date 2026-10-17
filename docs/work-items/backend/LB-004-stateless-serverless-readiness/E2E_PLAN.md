---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# E2E PLAN — secuencia posterior a LB-004B.2

## FASE 1 — esta tarea (LB-004B.2)

Backend + MinIO + ClamAV. Storage stateless `PASS`/`FAIL` según `LB-004B.2-VALIDATION.md`.
Estudiante propietario sube/lee su propio soporte; docente/coordinador/administrador
`DENY_BY_DEFAULT` hasta `REVIEW_BINDING` resuelto. Sin cambios DB ni frontend.

## FASE 2 — DB contract alignment

Microfase independiente en el repositorio DB (`NEXT: DB CONTRACT MICROPHASE`, ya identificada en
`PLAN.md`/`DECISIONS.md` desde LB-004B.1). Persistir la referencia del objeto (`fileId`/referencia
backend-neutral) junto al artefacto/revisión, sin bytes en DB, resolviendo `DR-LB004-DB-002`
(Alternativa A o B de `METADATA_CONTRACT_TARGET.md`) y proveyendo la capability de consulta
`fileId → revisión → sesión → grupo → docente`.

## FASE 3 — backend attach + ownership docente/revisión

Una vez FASE 2 esté disponible: implementar `POST /api/v1/asistencias/revisiones` con
`soporteArchivoId` autoritativo (ver `HTTP_CONTRACT_TARGET.md`), binding `DRAFT -> ATTACHED`, y
habilitar `DOCENTE_READ_RELATED` reemplazando el `DENY_BY_DEFAULT` de LB-004B.2 por la
autorización real vía `InstitutionalScopePort`/capability de consulta.

## FASE 4 — frontend

- Upload sigue pasando por el backend (sin acceso directo a MinIO).
- Angular usa `fileId` (ya disponible de forma aditiva desde LB-004B.2) en vez de `nombreGuardado`.
- Descarga migra de `window.open` a `HttpClient` con `Blob`, para que el interceptor adjunte Bearer.
- Límite anunciado baja de 10 MB a 5 MiB.
- Manejo explícito de errores de malware/content-security (mensajes distintos de un 404 genérico).

## FASE 5 — E2E real

```text
Estudiante
  -> login
  -> sube soporte limpio
       -> Backend valida contenido
       -> ClamAV escanea (CLEAN)
       -> MinIO almacena
  -> radica revisión (soporteArchivoId)
       -> SQL guarda referencia (FASE 2/3)
  -> Docente relacionado
       -> descarga
            -> Backend autoriza (ownership real vía FASE 3)
            -> MinIO entrega bytes
       -> mismos bytes que subió el estudiante
```

Casos negativos que debe cubrir el E2E de FASE 5:

- Archivo infectado (EICAR en pruebas) → rechazado, nunca almacenado.
- Tipo falso (extensión/magic bytes no coinciden) → rechazado.
- Archivo `> 5 MiB` → rechazado.
- Docente ajeno (no titular del grupo/sesión) → `404`.
- Usuario no autenticado → `401`.
- MinIO caído → fallo técnico seguro, sin confirmar referencia rota.
- ClamAV caído → `FAIL CLOSED`, nunca `CLEAN` por defecto.

## Trazabilidad de bloqueo

`REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT` en LB-004B.2 se resuelve exactamente al completar FASE 2.
`TD-004` permanece `PARTIAL` (no `CLOSED`) hasta que FASE 3/4/5 certifiquen el flujo completo
docente-relacionado + frontend real, conforme a la `DEFINITION_OF_DONE.md` del proyecto.
