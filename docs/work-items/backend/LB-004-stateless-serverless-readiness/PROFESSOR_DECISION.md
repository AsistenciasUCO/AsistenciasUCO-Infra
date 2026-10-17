---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# PROFESSOR DECISION — LB-004B.2 (autoridad humana / funcional)

## Contexto y por qué existe este documento

El preflight de `LB-004B.2` encontró un `CONTRACT_CONFLICT` real entre dos fuentes ya congeladas
del propio work item (`DECISIONS.md` `D-LB004B1-005`, `PROVIDER_DECISION.md`, ambos `status: active`,
fecha `2026-09-29`, mismo commit base que esta rama) y la instrucción recibida para esta microfase:

| Campo | LB-004B.1 (congelado) | LB-004B.2 (esta instrucción) |
|---|---|---|
| `STORAGE_PROVIDER` | `AZURE_BLOB_STORAGE` / `APPROVED` | `MINIO` / `APPROVED` |
| `MALWARE_SCAN` | `DEFERRED` (`D-LB004B1-004`) | `REQUIRED` |
| Presigned URLs | no seleccionadas como contrato público principal, pero no prohibidas explícitamente como alternativa futura | `FORBIDDEN` explícito en esta línea base |
| `FRONTEND_DIRECT_STORAGE_ACCESS` | no mencionado | `FORBIDDEN` explícito |

Conforme a `AGENTS.md` (*"Ante contradicción relevante entre fuentes autoritativas, aplicar
`CONTRACT_CONFLICT`... No elijas ni cambies código para resolverlas por suposición"*), este backend
no resuelve la contradicción por inferencia. La resuelve una decisión humana explícita, recibida en
esta tarea y registrada aquí como autoridad funcional — análoga a la aprobación humana que ya cerró
`LB-004A` (`ASSESSMENT: APPROVED`). Esta decisión **reemplaza** `D-LB004B1-005` y la parte de
`D-LB004B1-004` referida a antivirus; no se borra el historial: ambas quedan `SUPERSEDED` con
referencia a este documento (ver `DECISIONS.md`, `PROVIDER_DECISION.md`, `HTTP_CONTRACT_TARGET.md`).

## Decisión registrada (verbatim funcional, numerada)

1. Los bytes de los archivos **no** se persisten en filesystem local del backend ni como BLOB/binario
   dentro de SQL Server.
2. Los bytes deben estar en almacenamiento externo.
3. Provider seleccionado para esta línea base: **MinIO** — object storage open source, compatible
   con el requisito stateless/multi-instancia y utilizable localmente sin depender de un recurso
   cloud provisionado.
4. Único componente autorizado para acceder directamente a MinIO: **el backend**.
   `FRONTEND_DIRECT_STORAGE_ACCESS: FORBIDDEN`.
5. No se usan presigned URLs entregadas al frontend en esta línea base.
6. El backend es responsable de autenticación, autorización, validación del archivo, análisis de
   malware, decisión de compresión y upload/download contra MinIO.
7. Antes de almacenar un archivo: validar estructura/contenido, detectar malware/virus, comprimir
   únicamente cuando resulte técnicamente beneficioso.
8. La ubicación/referencia lógica del archivo se persiste junto con la información del
   artefacto/revisión correspondiente — sujeto a `DR-LB004-DB-002`, ver `REVIEW_BINDING` más abajo.
9. MinIO almacena bytes; SQL Server continúa siendo autoridad del negocio.
10. El backend decide quién puede recibir el contenido.

## Estado resultante (reemplaza el dictamen previo para estos campos)

```text
STORAGE_PROVIDER: MINIO / APPROVED
OBJECT_VISIBILITY: PRIVATE
STORAGE_ACCESS: BACKEND_ONLY
MALWARE_SCAN: REQUIRED
DOWNLOAD: BACKEND_MEDIATED
UPLOAD: BACKEND_MEDIATED
CACHE: NO_DISTRIBUTED_CACHE_REQUIRED
FRONTEND_DIRECT_STORAGE_ACCESS: FORBIDDEN
PRESIGNED_URLS: NOT_USED
```

## Decisiones previas marcadas `SUPERSEDED` (historial conservado, no borrado)

| Decisión previa | Documento origen | Estado | Reemplazada por |
|---|---|---|---|
| `STORAGE_PROVIDER: AZURE_BLOB_STORAGE` (`D-LB004B1-005`) | `DECISIONS.md`, `PROVIDER_DECISION.md` | `SUPERSEDED` | Este documento, ítem 3 |
| Antivirus/malware scanning `DEFERRED` (`D-LB004B1-004`) | `DECISIONS.md`, `HTTP_CONTRACT_TARGET.md` | `SUPERSEDED` | Este documento, ítem 6/7 |
| Alternativa de storage directo frontend→provider (nunca `APPROVED`, pero mencionada como rechazada `D` en `PROVIDER_DECISION.md §Contrato de URL/download`) | `PROVIDER_DECISION.md` | `SUPERSEDED` (confirmado `FORBIDDEN`, no solo "no seleccionada ahora") | Este documento, ítem 4 |
| Presigned URL como alternativa `B` no seleccionada pero no cerrada | `PROVIDER_DECISION.md` | `SUPERSEDED` (confirmado `NOT_USED`, cierre explícito) | Este documento, ítem 5 |

La comparación arquitectónica local-fs / shared-fs / Azure Blob de `PROVIDER_DECISION.md` permanece
como evidencia histórica de por qué se descartó filesystem local y compartido — esa parte del
razonamiento (stateless, multi-instancia, ownership) sigue siendo válida y aplica igual a MinIO. Lo
que cambia es exclusivamente la columna de provider ganador.

## Qué NO decide este documento

- No resuelve `DR-LB004-DB-002` (contrato DB de metadata/binding). El backend no modifica el
  repositorio DB en esta tarea. Mientras no exista ese contrato:

  ```text
  REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT
  ```

  Esto es explícitamente aceptable: la instrucción de esta microfase separa la storage foundation
  (bytes fuera del backend, validados y autorizados) del binding completo `fileId → revisión →
  sesión → grupo → docente`, que sigue bloqueado por evidencia DB, no por decisión pendiente.
- No otorga acceso de lectura a `DOCENTE`/`COORDINADOR`/`ADMINISTRADOR` más allá de lo ya congelado
  en `OWNERSHIP_DECISION.md`. Ver actualización puntual en ese documento: mientras `REVIEW_BINDING`
  esté bloqueado, `DOCENTE_FILE_ACCESS: DENY_BY_DEFAULT` en runtime (la regla `DOCENTE_READ_RELATED:
  DECIDED YES` permanece congelada como regla de producto, pero su implementación exige la capability
  de consulta que no existe; hasta entonces, fail-closed).
- No autoriza IaC, despliegue cloud, Redis, RabbitMQ, Kafka, CQRS, outbox, ni el inicio de LB-005/LB-006.
- No modifica el repositorio DB ni el frontend.

## Trazabilidad

- Sustituye para efectos de implementación: `D-LB004B1-005` (provider), la cláusula de antivirus de
  `D-LB004B1-004`.
- No sustituye: `D-LB004B0-002/003` (identidad `fileId`, ownership), `D-LB004B1-001/002/003`
  (ownership final, contrato HTTP conceptual, tamaño máximo `5 MiB`) — estas decisiones permanecen
  `FROZEN` y se heredan sin cambio en `LB-004B.2`.
- Ver actualización formal en [DECISIONS.md](DECISIONS.md) (`D-LB004B2-001`),
  [PROVIDER_DECISION.md](PROVIDER_DECISION.md) y [HTTP_CONTRACT_TARGET.md](HTTP_CONTRACT_TARGET.md).

## Addendum LB-004B.2H — autoridad funcional final del profesor (2026-09-30)

La revisión humana posterior confirma y precisa la decisión anterior:

1. Storage no autoriza usuarios finales y ningún usuario/frontend accede directamente a MinIO.
2. El backend es el único componente de runtime que accede a los objetos, mediante una identidad
   técnica propia de mínimo privilegio; las credenciales root son solo bootstrap/administración.
3. El backend decide el acceso por autorización de negocio, recupera el stream y responde con el
   `Content-Type` verificado. MinIO nunca decide autorización académica.
4. SQL Server debe conservar la referencia lógica del objeto junto con el artefacto/revisión. Esta
   obligación permanece `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT`; no autoriza cambios DB aquí.
5. `FileStoragePort.delete` permanece como capability interna de compensación/purga, sin endpoint
   público. La purga final depende del lifecycle durable del proceso/artefacto, no de la edad del
   objeto decidida unilateralmente por storage.
6. Debe diseñarse cold storage para información de poco acceso, sin implementarlo en esta microfase.
7. Mientras el binding DB no exista: solo el estudiante propietario del `DRAFT` puede leer;
   `DOCENTE`, `COORDINADOR` y `ADMINISTRADOR` permanecen `DENY_BY_DEFAULT`.

La metadata `ownerSubject` en MinIO es una protección técnica temporal para `DRAFT`; la
autorización final debe derivarse de JWT + relación de negocio durable en SQL Server
(`revisión/estudiante/sesión/grupo/docente`).
