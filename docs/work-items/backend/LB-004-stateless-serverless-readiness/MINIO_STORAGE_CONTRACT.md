---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# MINIO STORAGE CONTRACT — LB-004B.2

Congela el contrato técnico entre Application e Infrastructure para el almacenamiento de bytes de
soporte. Deriva de la decisión humana en [PROFESSOR_DECISION](PROFESSOR_DECISION.md) (`D-LB004B2-001`).

## Target architecture (obligatoria)

```text
HTTP Controller (ArchivoController)
      |
InputPort (SubirArchivoInputPort / DescargarArchivoInputPort)
      |
UseCase (SubirArchivoUseCase / DescargarArchivoUseCase)
      |-- ContentSecurityValidator (política pura de Application)
      |-- MalwareScanPort
      |-- FileStoragePort
              |
       MinioFileStorageAdapter (Infrastructure, único lugar que conoce MinIO)
```

Prohibido explícitamente:

```text
Controller -> MinioClient            FORBIDDEN
Controller -> Files.*                FORBIDDEN
Application -> SDK MinIO             FORBIDDEN
Application -> bucket/objectKey      FORBIDDEN
```

Enforced por `StorageProviderIsolationRulesTest` (ArchUnit) y `STORAGE-001`.

## `FileStoragePort` (Application, neutral)

El contrato **no** menciona `MinioClient`, `bucket`, `S3`, `Blob`, filesystem ni presigned URL.
Opera sobre `fileId` (UUID opaco generado por backend) y un `StoredObjectMetadata` neutral.

Operaciones mínimas: `store`, `read` (bytes + metadata), `exists`, `delete` (uso interno de
reconciliación; no expuesto como endpoint HTTP público, ver `OWNERSHIP_DECISION.md`:
`DELETE_ENDPOINT: NO`).

El `objectKey` interno se deriva determinísticamente de `fileId` (conceptualmente
`soportes/<uuid>`), pero esa representación es detalle exclusivo de `MinioFileStorageAdapter`;
Application nunca la ve ni la persiste. El filename original **no** es objectKey de autoridad.

## Metadata técnica del objeto (temporal, hasta que el binding DB quede congelado)

MinIO conserva metadata técnica del objeto, no negocio académico:

| Campo | Uso |
|---|---|
| `fileId` | identidad opaca |
| `ownerSubject` | identidad institucional (subject JWT) del usuario que subió el objeto |
| `originalFilename` | nombre original sanitizado, solo presentación |
| `contentType` | tipo verificado tras coherencia de extensión + MIME declarado + magic bytes; el header multipart no es autoridad por sí solo |
| `originalSize` / `storedSize` | tamaño verificado antes/después de decisión de compresión |
| `compressed` / `compressionAlgorithm` | resultado de la política de compresión (`CONTENT_SECURITY.md`) |
| `checksumSha256` | integridad, calculado sobre el contenido aceptado |
| `uploadedAt` | timestamp técnico |

MinIO **no** es source of truth de grupo, sesión, docente, estado académico ni decisión de revisión
— eso sigue perteneciendo a SQL Server. Mientras `REVIEW_BINDING: BLOCKED_BY_DB_CONTRACT`, no existe
un `bindingRevisionId` persistido; el objeto queda en estado técnico `DRAFT` (metadata de objeto
propia, sin fila SQL), consistente con la Alternativa B de `METADATA_CONTRACT_TARGET.md`.

## Imagen y layout de infraestructura (ver `RISKS.md R-LB004-024`)

La infraestructura vive en `infra/files/compose.yaml`; el compose raíz conserva solo el backend.
`infra/files/minio/Dockerfile` compila MinIO Community desde source upstream fijado al tag
`RELEASE.2025-10-15T17-29-55Z` y compila `mc` desde
`RELEASE.2025-08-13T08-35-41Z`. No usa `:latest`, `bitnamilegacy` ni una imagen comercial.

El source MinIO Community es AGPL-3.0 y upstream quedó archivado/read-only en 2026. Aunque el build
queda trazable y reproducible por tag, se clasifica `LOCAL_DEV_TEMPORARY`, no target productivo
mantenido. La decisión productiva y la revisión de obligaciones AGPL siguen pendientes.

## MinIO adapter (Infrastructure)

- Dependencia oficial `io.minio:minio` únicamente en Infrastructure (`pom.xml`, sin scope `test`).
- Bucket privado (`asistencias-soportes`), sin política pública, sin presigned URLs retornadas al
  llamador de Application.
- Endpoint/bucket por `app.providers.minio.*` (properties); `MINIO_ACCESS_KEY`/`MINIO_SECRET_KEY`
  exclusivamente por variables de entorno — cero secretos hardcoded.
- Fail-fast/fail-closed: si `app.adapters.storage.provider=minio` y falta configuración obligatoria
  (endpoint/bucket/credenciales), el arranque falla con excepción clara, nunca fallback silencioso a
  `local`.
- Creación del bucket: delegada al servicio real `minio-init` en `infra/files/compose.yaml` (política local del
  proyecto), no responsabilidad del adapter en producción; el adapter puede verificar existencia de
  forma idempotente en `read`/`store`, pero no crea infraestructura por sí mismo en caliente.
- Errores técnicos del SDK se traducen a excepciones propias (`FileStoragePort.StorageException`,
  `FileStoragePort.StorageUnavailableException`), nunca se propaga el tipo del SDK MinIO fuera de
  Infrastructure.
- Logging: nunca access key, secret key, payload de archivo, ni objectKey completo si no es
  necesario; sí `fileId`, operación, resultado, tamaño (ver `docs/architecture` convención de
  observabilidad).

## Composition Root

`app.adapters.storage.provider` soporta exclusivamente `MINIO`. `LOCAL` no es un valor válido y no
existe fallback silencioso.
`StorageAdapterConfiguration`-equivalente (`@ConditionalOnProperty(prefix="app.adapters.storage",
name="provider", havingValue="minio")`) expone `FileStoragePort` como bean solo cuando el selector
apunta a MinIO, siguiendo exactamente el patrón ya usado por `vault`/`identity`/`security`
(`AzureKeyVaultAdapterConfiguration`/`LocalEnvVaultAdapterConfiguration`).

## Identidad pública y neutralidad HTTP

La respuesta HTTP nunca expone bucket, objectKey, endpoint MinIO, access key, secret ni presigned
URL (ver `HTTP_CONTRACT_TARGET.md`, actualizado en LB-004B.2). Solo `fileId`, `nombre`, `url`
relativa al backend y `tamanio`.

## Certificación de statelessness (parcial, esta microfase)

```text
STORAGE-005 (restart no pierde objeto): certificable con Docker local (volumen MinIO persistente).
STORAGE-006 (dos adapters, mismo MinIO, mismo objeto): certificable con dos clientes MinIO
  independientes contra el mismo contenedor/bucket.
STORAGE_STATELESSNESS: ver LB-004B.2-VALIDATION.md para el veredicto real tras ejecutar los IT.
```

El volumen Docker de MinIO pertenece al storage, no al backend: no se monta dentro del contenedor
`backend`; `infra/files/compose.yaml` declara un volumen nombrado exclusivo del servicio `minio`.

## Identidades y least privilege

- `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`: solo `minio`, `minio-init` y el perfil explícito de
  validación; nunca Spring Boot.
- `MINIO_ACCESS_KEY`/`MINIO_SECRET_KEY`: usuario técnico del backend creado/verificado por
  `minio-init`.
- Policy `asistencias-backend`: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` únicamente sobre
  `arn:aws:s3:::asistencias-soportes/soportes/*`, más `s3:GetBucketLocation` exclusivamente sobre
  `arn:aws:s3:::asistencias-soportes`. La integración real evidenció que el SDK MinIO Java ejecuta
  esta consulta antes del `PutObject`; sin el permiso acotado responde `AccessDenied`.
- Sin administración, user/policy management, create/delete bucket ni acceso a otro bucket/prefix.

La validación real vive en `infra/files/minio/validate-policy.sh`; exige Put/Get/Delete permitidos y
create-bucket/otro-bucket/anonymous GET/PUT denegados.
