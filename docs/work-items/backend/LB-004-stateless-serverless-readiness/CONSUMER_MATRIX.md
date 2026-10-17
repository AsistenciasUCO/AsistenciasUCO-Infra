---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# CONSUMER MATRIX — LB-004B.0

## Snapshot del consumidor

| Campo | Evidencia |
|---|---|
| Repositorio | `https://github.com/shesho22/AsistenciasUCO-Frontend.git` |
| Ruta inspeccionada | `C:\Users\josev\OneDrive\Documentos\Front_Asistecias\AsistenciasUCO-Frontend` |
| Rama / commit | `develop` / `b0c2225e8a9dd9960d124d960725cb94b7b0abb8` |
| Fecha del commit | 2026-09-27T23:09:54-05:00 |
| Estado del árbol | limpio (`git status --porcelain=v1`: 0 entradas) |
| Método | inspección estática; no se ejecutó E2E frontend-backend |

Este snapshot es el consumer real disponible para LB-004B.0. El repositorio frontend se leyó sin modificarlo.

## Flujo comprobado

| Paso | Consumer / símbolo | Comportamiento AS-IS | Contrato backend relacionado | Dictamen |
|---|---|---|---|---|
| Selección | `StudentClaimFormComponent`, ruta `estudiante/materias` protegida con rol `ESTUDIANTE` | `<input type="file">`, un solo archivo, `accept=.pdf,.png,.jpg,.jpeg`; el soporte no es obligatorio para habilitar `Radicar Reclamo` | tipos admitidos coinciden; la UI anuncia máximo 10 MB | CONFIRMED con mismatch de límite: backend acepta máximo 5 MiB |
| Upload | `StudentCoursesComponent.onFileSelected` | el archivo se sube inmediatamente al seleccionarlo, antes de radicar la revisión | `POST /api/v1/archivos/subir`, multipart field `archivo` | CONFIRMED |
| Respuesta upload | `AttendanceClaimService.subirSoporte` y `onFileSelected` | tipa `nombre`, `nombreGuardado`, `url`, `tamanio`; usa `nombre` y `url`; ignora `nombreGuardado` y `tamanio`, calculando tamaño/tipo desde el `File` local | backend responde 201 con `ApiDataResponse` y esos cuatro campos | COMPATIBLE para upload AS-IS |
| Attach | `StudentCoursesComponent.enviarReclamo` → `AttendanceClaimService.crearReclamo` | al enviar el formulario copia `soporteAdjunto.nombre` a `soporteNombre` y `soporteAdjunto.urlSimulada` a `soporteUrl` | `POST /api/v1/asistencias/revisiones` | CONFIRMED |
| Revisión sin soporte | `StudentClaimFormComponent.onSubmit` | solo exige justificación; `soporteAdjunto` es opcional y ambos campos se omiten si no hubo upload | validator backend tampoco exige soporte | CONFIRMED: una revisión puede existir sin soporte |
| Lectura docente | `TeacherClaimsComponent`, ruta `docente/reclamos` protegida con rol `DOCENTE` | muestra el soporte y ofrece `Descargar Soporte`; abre `urlSimulada` en otra pestaña | `GET /api/v1/archivos/{nombreArchivo}` | CONSUMER CONFIRMED; integración real no disponible porque `GET /docente/reclamos` responde feature unavailable AS-IS |
| Forma de URL | `TeacherClaimsComponent.descargarSoporte` | acepta URL absoluta que empiece por `http`; si es relativa concatena `http://localhost:8080`; llama `window.open` | backend devuelve ruta relativa `/api/v1/archivos/{nombreGuardado}` y exige Bearer para `/api/v1/**` | MISMATCH: navegación directa no usa `HttpClient` ni agrega Authorization |
| Preview | `window.open(url, '_blank')` + respuesta backend `inline` | el navegador puede previsualizar formatos soportados o descargarlos; no existe componente de preview propio | GET devuelve bytes inline | CONFIRMED como apertura/descarga, no como preview contractual |

## Campos efectivamente consumidos

| Campo de upload | Uso Angular | Consecuencia contractual |
|---|---|---|
| `nombre` | se muestra y se envía como `soporteNombre` | preservar significado de nombre original sanitizado para presentación; nunca usarlo como identidad |
| `nombreGuardado` | tipado pero no leído después de la respuesta | no es dependencia del consumer confirmado; no debe convertirse en identidad de Application |
| `url` | se conserva como `urlSimulada` y se envía como `soporteUrl` | el consumer depende de una referencia resoluble, no de una URL de provider concreta |
| `tamanio` | tipado pero ignorado; la UI calcula `file.size / 1024` | no autoriza confiar en tamaño informado por cliente |

## Roles observados

| Rol | Consumo comprobado | Límite de evidencia |
|---|---|---|
| `ESTUDIANTE` | selecciona, sube y adjunta un soporte a su solicitud; puede radicar sin soporte | no se encontró descarga del soporte propio |
| `DOCENTE` | la UI de reclamos relacionados muestra y abre/descarga el soporte para resolver la revisión | el listado backend `GET /docente/reclamos` está `FeatureUnavailable` y no hubo E2E |
| `COORDINADOR` | ninguno para soportes | no autoriza acceso por inferencia |
| `ADMINISTRADOR` | ninguno para soportes | no autoriza acceso por inferencia |

## Expectativa HTTP Angular

- Upload: cualquier 2xx que deserialice `ApiResponse`, con `exitoso=true` y `datos.nombre`/`datos.url` presentes. El backend AS-IS entrega 201.
- Attach: cualquier 2xx con `exitoso=true`; el flujo no necesita `datos`. El backend AS-IS entrega 202 `ApiMessageResponse`.
- Download: navegación directa a la URL almacenada. Esa forma no puede aportar el Bearer que exige la API y no debe usarse como razón para volver público el objeto.
- Errores de upload se reducen hoy a un mensaje genérico; no hay expectativa frontend específica por status.

## Resultado

```text
FRONTEND_CONSUMER: CONFIRMED
REVISION_WITHOUT_SUPPORT: YES
UPLOAD_LIMIT_CONFLICT: FRONTEND_10_MB_VS_BACKEND_5_MIB
AUTHENTICATED_DOWNLOAD_CONSUMER_CHANGE_REQUIRED: YES
```

## Frontend contract delta (LB-004B.1)

Matriz exacta de cambios futuros requeridos en `AsistenciasUCO-Frontend` para alinear con
[HTTP_CONTRACT_TARGET](HTTP_CONTRACT_TARGET.md) y [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md).
**No implementado aquí**; es el input congelado para un prompt frontend independiente. No se
modifica el repositorio frontend en LB-004B.1.

| # | Símbolo/flujo AS-IS | Cambio requerido | Motivo contractual |
|---|---|---|---|
| 1 | `AttendanceClaimService.subirSoporte` / `onFileSelected` consumen `nombre`/`url`, ignoran `nombreGuardado`/`tamanio` | Consumir también `fileId` de la respuesta de upload y conservarlo como el identificador autoritativo del soporte seleccionado, en vez de derivar identidad de `nombre`/`url` | `fileId` es la única identidad de objeto congelada; `nombreGuardado`/`url` de provider no deben tratarse como identidad |
| 2 | `crearReclamo` envía `soporteNombre` (=`nombre`) y `soporteUrl` (=`urlSimulada`) al radicar | Enviar `soporteArchivoId` (= `fileId`) como campo autoritativo del request de `POST /api/v1/asistencias/revisiones`; dejar de construir/enviar `soporteUrl` como fuente de verdad | El backend ya no confía en `soporteUrl`/`nombreGuardado` de cliente para el binding (`HTTP_CONTRACT_TARGET`, corrección de `SECURITY_FINDING — OBJECT_LEVEL_AUTHORIZATION_MISSING`) |
| 3 | `TeacherClaimsComponent.descargarSoporte` usa `window.open(url)`, sin `HttpClient`, sin Bearer | Usar `HttpClient` con `responseType: 'blob'` (el interceptor de Authorization ya existente agrega el Bearer) y generar un `Object URL` local (`URL.createObjectURL`) para previsualizar/descargar, revocándolo tras su uso | `GET /api/v1/archivos/{fileId}` exige Bearer y ownership; `window.open` no puede satisfacerlo. Riesgo `R-LB004-006` |
| 4 | UI anuncia máximo 10 MB en `StudentClaimFormComponent` | Bajar el límite anunciado/validado a 5 MiB (5 242 880 bytes), igual al backend | `MAX_FILE_SIZE_FINAL: 5 MiB` congelado en `HTTP_CONTRACT_TARGET`. Riesgo `R-LB004-007` |
| 5 | El frontend nunca maneja una URL de storage directamente (AS-IS ya usa rutas backend relativas) | Mantener esa propiedad: el frontend nunca debe aceptar ni construir una URL MinIO/S3/presigned; solo la ruta relativa de backend derivada de `fileId` | `OBJECT_VISIBILITY: PRIVATE`, `DOWNLOAD: BACKEND_MEDIATED` (`PROVIDER_DECISION`). Riesgo `R-LB004-013` |
| 6 | `soporteAdjunto` sigue siendo opcional en el formulario | Sin cambio: `SUPPORT_OPTIONAL: YES` se preserva | Confirmado en `OWNERSHIP_DECISION` |
| 7 | El estudiante no descarga su propio soporte hoy (solo lo muestra localmente antes de radicar) | Opcional para el frontend: puede añadir una acción de descarga propia usando el mismo patrón `HttpClient`/Bearer del punto 3, ya que `ESTUDIANTE_READ_OWN: DECIDED YES` lo permite en backend | No obligatorio para este contrato; es una capability disponible, no un requisito de UI |
| 8 | `GET /docente/reclamos` responde `FeatureUnavailable` AS-IS; la UI docente ya asume que existe | Ninguno del lado frontend hasta que el backend materialice el endpoint (bloqueado por `DB_PUBLIC_CONTRACT_CHANGE_REQUIRED`) | Dependencia backend→DB, no frontend |

```text
FRONTEND_DELTA: DEFINED
FRONTEND_IMPLEMENTATION: NOT_STARTED (prompt independiente posterior)
```

