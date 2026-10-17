---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# HTTP CONTRACT TARGET — LB-004B.1 (FROZEN, conceptual — no es OpenAPI)

Congela el contrato HTTP conceptual futuro para soportes de revisión. No modifica
`docs/contracts/openapi/openapi-golden-path.yaml`: `/api/v1/archivos/**` y
`/api/v1/asistencias/revisiones` no forman parte del Golden Path OpenAPI (confirmado: ninguna
coincidencia en el YAML canónico); su AS-IS vive en
[HTTP_AS_IS_MATRIX](../../contracts/HTTP_AS_IS_MATRIX.md). Este documento es el freeze conceptual
que una futura microfase `CONTRACT_CHANGE` debe trasladar a especificación si decide incorporarlos
a OpenAPI. Verificado contra
[API_DESIGN_RULES](../../governance/API_DESIGN_RULES.md): no se crea ningún `PUT`/`DELETE` nuevo,
por lo que `METHOD_EXCEPTION` **no aplica** a este contrato.

## UPLOAD — `POST /api/v1/archivos/subir` (ruta preservada)

- Método: `POST` sobre colección, servidor controla el identificador → conforme sin
  `METHOD_EXCEPTION`.
- Request: sin cambios (multipart `archivo`).
- Response mínima (además de lo existente): `{ fileId, nombre, url, tamanio }`.
  - `fileId`: UUID opaco generado por backend (ver [METADATA_CONTRACT_TARGET](METADATA_CONTRACT_TARGET.md)).
  - `nombre`: nombre original sanitizado (preservado, ya existe).
  - `url`: ruta **relativa al backend**, construida a partir de `fileId`
    (p. ej. `/api/v1/archivos/{fileId}`). Nunca Blob URL, nunca SAS, nunca `objectKey`.
  - `tamanio`: tamaño verificado por el servidor (no solo el reportado por el cliente).
  - `nombreGuardado`: campo heredado. El consumer confirmado lo tipa pero no lo usa
    (`CONSUMER_MATRIX.md`). Estrategia: `DEPRECATE` — puede seguir presente por compatibilidad de
    forma durante la transición, pero deja de ser la base de cualquier URL o identidad; su remoción
    definitiva es una decisión de una fase de limpieza posterior, no bloqueante aquí.
  - Status: `201` (preservado; ya es el comportamiento AS-IS).

## DOWNLOAD — `GET /api/v1/archivos/{fileId}` (ruta preservada, segmento resemantizado)

- Método: `GET`, lectura de recurso → conforme.
- El segmento de path pasa a identificar `fileId`, no `nombreArchivo`/`nombreGuardado`.
- Bearer **obligatorio** (ya es la regla `authenticated()` vigente; se preserva).
- Ownership **obligatorio** en Application: ver [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md).
- Resultado por caso:
  - Sin Bearer / inválido → `401`.
  - Bearer válido, sin relación con el `fileId` (ajeno) → `404`, sin revelar existencia.
  - Bearer válido, relación confirmada (estudiante propietario o docente relacionado) → `200`,
    bytes desde `FileStoragePort` (MinIO en Infrastructure para la baseline vigente).
- Angular debe migrar de `window.open(url)` a `HttpClient` con `Blob` para que el interceptor
  agregue el Bearer; ver [FRONTEND CONTRACT DELTA](CONSUMER_MATRIX.md#frontend-contract-delta-lb-004b1).

## ATTACH — `POST /api/v1/asistencias/revisiones` (ruta preservada, request cambia)

- Método: `POST` business command → conforme, sin `METHOD_EXCEPTION`.
- **El request NO debe confiar en `soporteUrl`/`nombreGuardado` como fuente de verdad para el
  binding.** Nuevo campo autoritativo: `soporteArchivoId` (UUID = `fileId`), opcional (coherente con
  `SUPPORT_OPTIONAL: YES`).
- Comportamiento del backend cuando `soporteArchivoId` está presente: Application resuelve el
  `fileId`, valida ownership (`DRAFT` propio, no expirado) y deriva `soporteNombre`/`soporteUrl` de
  la metadata del objeto — nunca del valor que el cliente hubiera enviado para esos campos.
- Campos legacy `soporteNombre`/`soporteUrl` en el **request** (los que el cliente construye hoy en
  `AttendanceClaimService.crearReclamo`): estrategia `DEPRECATE` con **corte coordinado**, no una
  ventana de doble confianza server-side:
  - Motivo: mantener esos campos como fuente de verdad de binding perpetuaría los
    `SECURITY_FINDING` ya registrados (`OBJECT_LEVEL_AUTHORIZATION_MISSING`,
    `FILE_BINDING_AND_CONTENT_POLICY_UNDEFINED` en `AS_IS.md`) y el riesgo `R-LB004-003`/`R-LB004-013`
    en `RISKS.md`. No es una decisión de UX, es una corrección de seguridad.
  - Rollout: coordinado con el release de frontend que envíe `soporteArchivoId`, siguiendo la
    estrategia de dos releases ya definida en `PROVIDER_DECISION.md` (release compatible primero,
    activar después). No se implementa en esta microfase; queda congelado como contrato para
    `LB-004B.2` y la fase de implementación.
  - Si el frontend aún no migró y envía solo los campos legacy sin `soporteArchivoId`: el
    comportamiento (aceptar sin soporte vinculado vs. rechazar) es competencia de la fase de
    implementación siguiendo `SUPPORT_OPTIONAL: YES` — una revisión sin `soporteArchivoId` es
    simplemente una revisión sin soporte, igual que hoy. Lo que se elimina es la confianza en
    `soporteUrl` arbitraria como si fuera un binding válido.
- Response: sin cambio de wrapper/status (`ApiMessageResponse`, `202`, preservados).

## Límite de tamaño

Ver `MAX_FILE_SIZE` congelado en la sección siguiente de este documento y en `DECISIONS.md`.

```text
MAX_FILE_SIZE_FINAL: 5 MiB (5 242 880 bytes)
```

Se preserva el límite backend AS-IS (`5L * 1024 * 1024` en `ArchivoController`). No hay requisito
funcional evidenciado que justifique subir a 10 MB; el frontend debe bajar su límite anunciado/
validado de 10 MB a 5 MiB. Nota menor no bloqueante: el mensaje de error AS-IS dice "(5 MB)" pero el
cálculo real es MiB (≈5.24 MB); es una imprecisión de texto, no de contrato.

## Content security (congelado, no implementado)

| Control | Decisión |
|---|---|
| Extensiones permitidas | Preservar `pdf, png, jpg, jpeg` (AS-IS); sin requisito para ampliar |
| Content-Type declarado por el cliente | No se confía solo en el header/extensión; debe verificarse contra los bytes reales |
| Magic bytes / content sniffing | `REQUIRED` en la implementación futura |
| `Content-Disposition` | Preservar `inline`, dado el whitelist cerrado de tipos (sin HTML/SVG); nombre mostrado debe sanitizarse para evitar inyección de encabezado (comillas/CRLF) |
| Nombre original sanitizado | `REQUIRED`; ya existe sanitización parcial del nombre guardado (regex), se congela como requisito explícito para el nombre mostrado también |
| Antivirus / malware scanning | **`REQUIRED`** (actualizado en LB-004B.2 por decisión humana explícita, ver [PROFESSOR_DECISION](PROFESSOR_DECISION.md); reemplaza el `DEFERRED` congelado en LB-004B.1). ClamAV vía protocolo `clamd`/`INSTREAM`; `INFECTED -> REJECT`, `ERROR -> FAIL CLOSED` (nunca `SCAN_ERROR = CLEAN`), `CLEAN -> continuar`. Nunca se almacena un archivo declarado infectado. |
| Provider internals en response | `FORBIDDEN`: la respuesta de upload/download nunca expone bucket, objectKey, endpoint MinIO, access key, secret ni presigned URL — solo `fileId`, `nombre`, `url` relativa al backend y `tamanio`. |

## Verificación contra API_DESIGN_RULES

```text
NEW_PUT_OR_DELETE: NONE
METHOD_EXCEPTION_REQUIRED: NOT_APPLICABLE
BREAKING_CHANGE (ATTACH request): YES — requiere decisión, consumidores, migración y deprecación,
  ya registrados arriba y coordinados con el rollout de PROVIDER_DECISION.md
OPENAPI_CHANGE: NONE (fuera del Golden Path OpenAPI; no se modifica el YAML en esta microfase)
```

## Resultado

```text
HTTP_CONTRACT: FROZEN
UPLOAD_RESPONSE_MIN_FIELDS: fileId, nombre, url, tamanio
DOWNLOAD_PATH_SEGMENT: fileId
ATTACH_REQUEST_FIELD: soporteArchivoId (nuevo, autoritativo)
LEGACY_REQUEST_FIELDS: soporteNombre/soporteUrl -> DEPRECATE (corte coordinado, no dual-trust)
LEGACY_RESPONSE_FIELD: nombreGuardado -> DEPRECATE (compatibilidad de forma, no identidad)
```
