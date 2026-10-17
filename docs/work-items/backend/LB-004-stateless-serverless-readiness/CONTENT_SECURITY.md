---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# CONTENT SECURITY — LB-004B.2

Congela la política de validación de contenido, malware y compresión para soportes de revisión.
Deriva de [PROFESSOR_DECISION](PROFESSOR_DECISION.md) y hereda `MAX_FILE_SIZE_FINAL`/extensiones ya
`FROZEN` en `HTTP_CONTRACT_TARGET.md` (LB-004B.1).

## Tamaño

```text
MAX_FILE_SIZE: 5 MiB exacto = 5 * 1024 * 1024 = 5242880 bytes
```

Sin cambio respecto al límite AS-IS/LB-004B.1.

## Tipos permitidos y verificación

| Tipo | Extensión | Magic bytes requeridos |
|---|---|---|
| PDF | `.pdf` | `25 50 44 46 2D` (`%PDF-`) |
| PNG | `.png` | `89 50 4E 47 0D 0A 1A 0A` |
| JPEG | `.jpg`/`.jpeg` | `FF D8 FF` |

No se confía únicamente en extensión ni en el `Content-Type` declarado por el cliente. Se valida,
en este orden:

1. Filename sanitizado (sin `../`, sin ruta absoluta, sin separadores `/`/`\`, sin `:`, sin
   caracteres de control).
2. Extensión dentro del whitelist.
3. `Content-Type` declarado coherente con la extensión (control obligatorio, no autoridad final).
4. Magic bytes reales del contenido coherentes con la extensión declarada.
5. Tamaño dentro del límite, archivo no vacío.

Casos que deben rechazarse (`CONTENT-004..006`):

- `.exe` renombrado a `.pdf` (magic bytes no coinciden).
- PDF con magic bytes incorrectos.
- MIME declarado incompatible con la extensión.
- Archivo vacío.
- Archivo `> 5 MiB`.
- Filename con `../`, ruta absoluta, separadores para escapar namespace, caracteres de control.

## Malware scanning (ClamAV) — `REQUIRED`

Reemplaza `DEFERRED` de LB-004B.1 por decisión humana (`D-LB004B2-001`).

```text
archivo recibido
   -> validación estructural (sección anterior)
   -> ClamAV (protocolo clamd / INSTREAM)
        INFECTED -> REJECT (400, nunca se almacena)
        ERROR    -> FAIL CLOSED (error técnico 5xx seguro, nunca se trata como CLEAN ni como 400)
        CLEAN    -> continuar a decisión de compresión y storage
```

- `MalwareScanPort` es neutral en Application; `ClamAvMalwareScanAdapter` vive solo en Infrastructure.
- Solo se usa la firma de prueba **EICAR** para verificar detección (`MALWARE-001`); prohibido usar
  malware real en cualquier fixture o entorno de prueba.
- `ClamAV` corre en `infra/files/compose.yaml`, versión y digest pinneados, con healthcheck; el adapter falla cerrado
  si el servicio no está disponible o no responde dentro de un timeout acotado.
- Archivo infectado produce un 4xx controlado. Indisponibilidad, timeout o error de protocolo usa el
  error técnico estándar existente (`INTERNAL_APPLICATION_ERROR`, HTTP 500); el proyecto no tiene
  hoy un patrón 503 compatible y esta microfase no crea una taxonomía paralela.

## Política de compresión

Instrucción: *"si se puede comprimir, se comprima"* — interpretada como evaluación explícita y
testeable, no como "todo a ZIP".

```text
original bytes
   -> evaluar compresión candidata
   -> si la reducción es materialmente beneficiosa (umbral: ahorro >= 10% del tamaño original
      Y tamaño comprimido estrictamente menor)
        -> almacenar representación comprimida; compressed=true
   -> si no
        -> almacenar original; compressed=false
```

PDF, JPEG y PNG ya suelen estar comprimidos internamente: la evaluación empírica sobre fixtures
representativos de estos tres tipos no produce, en general, un ahorro material (`COMPRESSION_CURRENT_
FORMATS: NO_BENEFIT / STORE_ORIGINAL` es el resultado esperado y aceptable — satisface el requisito
de *evaluar* sin forzar compresión cosmética que empeore tamaño, compatibilidad o CPU). La política
se implementa de forma genérica (no hardcodeada a "nunca comprimir PDF/PNG/JPEG") para que un fixture
sintético compresible dentro de esos mismos tipos (`COMPRESSION-002`) sí resulte en `compressed=true`,
demostrando que la evaluación es real y no una rama muerta.

La descarga siempre devuelve el contenido original tal como el usuario lo subió (transparente);
`compressed`/`compressionAlgorithm` son metadata técnica interna, nunca cambian el contrato de bytes
devueltos por `GET /api/v1/archivos/{fileId}`.

## Checksum / integridad

SHA-256 del contenido aceptado (post-scan, pre-decisión de compresión, sobre los bytes originales del
usuario) se calcula y se guarda como metadata técnica del objeto (`INTEGRITY-001`). No se usa como
mecanismo de autorización — solo de integridad/verificación.

## Multipart / filesystem local

`ArchivoController` deja de usar `Files.copy`, `Paths.get(uploadDir)` o cualquier directorio
persistente (`LOCAL_FILESYSTEM_CONTRACTUAL_STATE: 0`). El archivo recibido se procesa en memoria
acotada (máximo 5 MiB ya impuesto por la validación); `spring.servlet.multipart.max-file-size` /
`max-request-size` se configuran explícitamente en 5 MiB/6 MiB y `file-size-threshold=5MB`, de modo
que los archivos contractualmente válidos (máximo 5 MiB) permanezcan en memoria durante el parsing
multipart. `LOCAL_FILESYSTEM_CONTRACTUAL_STATE: 0` significa cero persistencia contractual/local
del archivo; no afirma que la JVM no use memoria transitoria durante la request.

## Integridad en lectura

En descarga se recupera el objeto, se descomprime si aplica, se calcula SHA-256 sobre los bytes
originales y se compara con `metadata.checksumSha256`. Un mismatch falla cerrado con error técnico;
no se retornan bytes potencialmente corruptos.
