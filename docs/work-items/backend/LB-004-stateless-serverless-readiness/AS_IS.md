---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-29
---

# AS-IS — LB-004A / LB-004B.0 Stateless Storage

## Snapshot

| Campo | Valor |
|---|---|
| Base | `0b7905cdba54189bbabe7dd3ea14b66e14bd0c2d` |
| Rama | `jose-valencia/lb-004-stateless-serverless-readiness` |
| LB-003 | `CLOSED / PASS` |
| Método | inspección estática de fuentes normativas, código, tests y configuración; sin E2E storage ni Blob real |
| Backend | AsistenciasUCO `0b7905c` |
| Frontend | AsistenciasUCO-Frontend `develop@b0c2225e8a9dd9960d124d960725cb94b7b0abb8`, árbol limpio |

## Flujo de archivos comprobado

```text
POST /api/v1/archivos/subir
  -> ArchivoController
  -> valida vacío, tamaño <= 5 MiB, nombre simple y extensión pdf/png/jpg/jpeg
  -> UUID + nombre normalizado
  -> Files.copy(..., REPLACE_EXISTING)
  -> <working-directory>/uploads/soportes por defecto
  -> 201 { nombre, nombreGuardado, url, tamanio }

GET /api/v1/archivos/{nombreArchivo}
  -> ArchivoController
  -> valida nombre/ruta/real path/regular file
  -> UrlResource desde el mismo filesystem local
  -> 200 inline
```

Hechos:

- El directorio se crea en el constructor del controller. Un fallo de creación solo se registra; no hay fail-fast de startup.
- La configuración `APP_STORAGE_UPLOAD_DIRECTORY` cambia la ruta, no el provider.
- La ruta por defecto depende del working directory de la JVM.
- No hay metadata durable creada por el upload: propietario, sesión, revisión, grupo, hash, content type verificado, estado de adjunción, retención ni fecha de expiración.
- No hay endpoint de borrado ni lifecycle de objetos.
- En el checkout local, `uploads/soportes` existe vacío; esto no prueba que otros ambientes carezcan de archivos.
- `uploads/` está ignorado por Git y no hay archivos de uploads versionados.

## Consumidor funcional comprobado y límite de evidencia

`POST /api/v1/asistencias/revisiones` recibe `soporteNombre` y `soporteUrl`. El caso de uso resuelve el estudiante autenticado mediante `InstitutionalScopePort` y el adapter envía ambos campos a `dbo.usp_radicar_solicitud_revision_asistencia`. Esta inspección estática prueba el envío de parámetros, no el resultado de una ejecución DB en esta microfase.

No hay dependencia en código entre esa revisión y `ArchivoController`:

- el request puede omitir ambos campos;
- `soporteUrl` es texto proporcionado por el cliente;
- no se comprueba que apunte a `/api/v1/archivos/**`;
- no se comprueba que el archivo exista;
- no se comprueba que el uploader sea el estudiante de la revisión;
- no se crea un identificador durable de relación archivo-revisión.

La intención “soporte de inasistencia” aparece en el Javadoc de `ArchivoController` y coincide con los campos de revisión. Un test contractual del controller de revisión acepta incluso una URL externa arbitraria, confirmando que hoy no existe restricción a storage propio.

LB-004B.0 obtuvo el consumer real. El estudiante selecciona un archivo desde `StudentClaimFormComponent`; `StudentCoursesComponent.onFileSelected` ejecuta el upload inmediatamente y guarda `nombre` + `url` (no usa `nombreGuardado`). Al radicar, `AttendanceClaimService.crearReclamo` envía esos valores como `soporteNombre`/`soporteUrl`. El soporte es opcional. La ruta docente muestra el soporte y `TeacherClaimsComponent.descargarSoporte` usa `window.open`.

Hallazgos:

- la UI anuncia máximo 10 MB, mientras el backend limita a 5 MiB;
- `window.open` no pasa por `HttpClient` y no agrega el Bearer obligatorio para `/api/v1/**`;
- URLs absolutas externas también se aceptan en el consumer;
- `GET /docente/reclamos` responde feature unavailable AS-IS, por lo que no existe E2E real del download docente.

Detalle: [CONSUMER_MATRIX](CONSUMER_MATRIX.md). Por tanto:

```text
BACKEND_CONSUMER: CONFIRMED (revision metadata)
FRONTEND_CONSUMER: CONFIRMED (develop@b0c2225)
UPLOAD_TO_REVISION_BINDING: NOT_IMPLEMENTED
AUTHENTICATED_DOWNLOAD: CONSUMER_CHANGE_REQUIRED
```

## Seguridad

| Operación | Acceso AS-IS | Ownership AS-IS |
|---|---|---|
| Subir | cualquier identidad autenticada por la regla global `/api/v1/**` | ninguno; no se registra uploader/recurso/grupo |
| Leer | cualquier identidad autenticada que conozca `nombreArchivo` | ninguno; descarga directa por nombre guardado |
| Borrar | operación HTTP no encontrada | no aplica en AS-IS; lifecycle pendiente |
| Adjuntar a revisión | `ESTUDIANTE`; el caso de uso resuelve su estudiante institucional | solo scope del actor de la revisión; no verifica propiedad/existencia del archivo ni el origen de `soporteUrl` |

`SecurityConfig` cae en la regla global `/api/v1/** -> authenticated()` para archivos. No hay regla de rol específica ni autorización contextual.

`SECURITY_FINDING — OBJECT_LEVEL_AUTHORIZATION_MISSING`

- Archivo/tipo: `ArchivoController` + `SecurityConfig`; descarga por nombre sin ownership.
- Impacto comprobable: cualquier identidad autenticada que conozca un nombre guardado puede solicitar ese objeto; no existe check de propietario, revisión, grupo o rol relacionado.
- Límite: no se afirma explotación ni exposición en un ambiente concreto.

`SECURITY_FINDING — FILE_BINDING_AND_CONTENT_POLICY_UNDEFINED`

- Archivo/tipo: `ArchivoController`, `SolicitarRevisionAsistenciaRequest` y validator.
- Evidencia: el upload acepta por extensión y sirve `inline`; la revisión acepta una URL sin vínculo verificable.
- Decisión requerida: política de magic bytes/antimalware/content-disposition y valores de retención/delete. LB-004B.0 decide identidad/backend mediation y propone lifecycle; producto aún debe aprobar sus valores.

La defensa contra path traversal sí está presente: nombre simple, normalización, `startsWith`, `toRealPath` y archivo regular.

## Comportamiento ante reemplazo o múltiples réplicas

### Instancia destruida

- Los bytes guardados en su disco se pierden si el volumen es efímero.
- El backend puede enviar `soporteNombre`/`soporteUrl` al SP mientras los bytes locales desaparecen; una referencia aceptada por DB podría quedar apuntando a un objeto ausente. La ejecución DB no se probó en LB-004A.
- Caches Azure/SQL se reconstruyen bajo demanda desde su source of truth; se pierde solo estado derivado.
- Suscripciones/eventos SSE y counters locales se pierden; por contrato son efímeros y LB-005.
- Correlation/MDC se pierde al terminar el request, que es el comportamiento correcto.

### Request siguiente atendido por otra réplica

- Upload en A seguido de GET en B retorna 404 salvo que ambas compartan el mismo filesystem por una decisión externa no evidenciada.
- Las réplicas pueden tener distinta edad de cache. Azure tiene TTL; SQL no tiene TTL y el invalidation adapter solo delega en adapters Azure.
- El evento realtime publicado en A no llega a subscribers de B; limitación explícita LB-005.
- `/api/v1/realtime/status` reporta subscribers de la instancia que atiende, no del cluster.

## Estado externalizado

| Estado | Source of truth | Evaluación |
|---|---|---|
| Dominio/persistencia | SQL Server | Externalizado; compartible entre réplicas. |
| Runtime identity/JWT | Keycloak + token firmado | Sin sesión de servidor; externalizado. |
| Identity provisioning | Keycloak | Externalizado; MV-002 pendiente para E2E real. |
| Parámetros/mensajes | Azure App Configuration o SQL Server | Externalizados con caches locales derivadas. |
| Secret capability | Azure Key Vault o entorno local | Provider externo; el Port no es bootstrap de todas las properties de Spring. |
| Credenciales DB/Keycloak/webhook | variables de entorno/configuración externa | No hay defaults funcionales para secretos obligatorios inspeccionados. |
| Auditoría | log estructurado y, si está disponible, SQL Server | La copia SQL es durable; el archivo log local no lo es. |
| Métricas/traces | Micrometer/Prometheus y OTLP | Exportación/scrape externos; buffers/counters locales no son estado funcional. |

## Caches

| Adapter | Localidad | Política | Riesgo multi-réplica |
|---|---|---|---|
| Azure Key Vault | heap/Caffeine por JVM | 50, TTL 5 min | secreto stale hasta TTL o invalidación en cada réplica. |
| Azure parameters | heap/Caffeine por JVM | 1000, TTL 10 min | parámetro stale hasta TTL o invalidación por réplica. |
| Azure messages | dos Caffeine por JVM | 2000 cada una, TTL 30 min | mensaje stale hasta TTL o invalidación por réplica. |
| SQL parameters | `ConcurrentHashMap` por JVM | sin límite/TTL | valor derivado puede divergir indefinidamente hasta restart/`clearCache`; no hay invalidación genérica activa. |
| SQL messages | dos `ConcurrentHashMap` por JVM | sin límite/TTL | mismo riesgo; mensaje de usuario/técnico puede diferir entre réplicas. |

No se encontró un consumidor funcional productivo de `ParameterCatalogPort` aparte del wiring/invalidation. `MessageCatalogPort` sí resuelve mensajes de usuario. La necesidad de coherencia fuerte no está definida; una cache compartida no se justifica por esta inspección.

## Otros hallazgos de instancia

- `CorrelationIdContext`: `ThreadLocal` request-scoped, establecido y limpiado en `finally`; no es estado persistente.
- `SecurityContextHolder`: contexto request-scoped del framework; no es sesión durable.
- Realtime: `Sinks.Many` y `AtomicInteger` locales; fuera de LB-004.
- Heartbeat: `Flux.interval` por conexión; no scheduler de negocio durable.
- No se encontraron locks locales de negocio, `@Scheduled`, `TimerTask`, `HttpSession`, creación de archivos temporales ni maps estáticos mutables de estado de dominio en `src/main/java`.
- La generación de reporte Excel usa un `ByteArrayOutputStream` local al request; es estado transitorio reconstruible, no persistencia de instancia.
- Logs: ruta JSONL local y relativa al working directory por defecto, con rolling policy. Es estado operacional, no contractual; un runtime serverless requerirá una decisión de logging/collector en LB-006.
- Recursos Swagger/OpenAPI empaquetados son read-only y no constituyen estado mutable.

## Golden Path

El Golden Path de asistencia no usa `ArchivoController` ni storage de soportes. Sus writes/reads viven en SQL Server y su seguridad/contrato están congelados. Realtime local sigue siendo una señal secundaria; su distribución no se incorpora a LB-004.

```text
GOLDEN_PATH_STORAGE_DEPENDENCY: NONE FOUND
GOLDEN_PATH_HTTP_CHANGE_REQUIRED_BY_ASSESSMENT: NO
GOLDEN_PATH_DB_CHANGE_REQUIRED_BY_ASSESSMENT: NO
```

