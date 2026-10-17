---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-30
---

# METADATA CONTRACT TARGET — LB-004B.1

Congela qué metadata durable necesita Application para autorizar y operar el lifecycle de
soportes, y analiza el supuesto `DB_SCHEMA_CHANGE_REQUIRED` sin diseñar SQL. No es un contrato
DB aprobado: es el insumo que este backend, como consumidor de persistencia, entrega al equipo
dueño de la DB para que decida su propia representación, conforme a
[SOURCE_OF_TRUTH](../../governance/SOURCE_OF_TRUTH.md) y
[CONTRACT_ALIGNMENT_PROTOCOL](../../integration/CONTRACT_ALIGNMENT_PROTOCOL.md).

## Evidencia base

- `DB_BASELINE_CONTRACT.md` (SHA-256 `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec`,
  referenciado por `BACKEND_GOLDEN_PATH_CONTRACT.md`) **no menciona** la tabla/objeto ni el shape de
  columnas que respalda `dbo.usp_radicar_solicitud_revision_asistencia`, ni `soporteNombre`/`soporteUrl`.
  No hay evidencia versionada del shape exacto de persistencia de la revisión más allá de lo que
  `SolicitarRevisionAsistenciaRequest.java` envía como parámetros (`soporteNombre`, `soporteUrl`,
  strings sin contrato de longitud/formato documentado en este repositorio).
- `GET /docente/reclamos` responde `FeatureUnavailable` AS-IS (confirmado en `AS_IS.md`/`CONSUMER_MATRIX.md`):
  no existe hoy un SP/vista que permita resolver, dado un soporte, la revisión/sesión/grupo/docente
  titular asociados.
- El principio general del baseline: *"Las tablas y columnas no se expanden para acomodar
  backend/frontend. Cualquier divergencia de shape existente debe reconstruirse desde este baseline,
  no maquillarse con migraciones silenciosas."*

## Metadata mínima que Application necesita (independiente de dónde la persista DB)

| Campo | Uso |
|---|---|
| `fileId` | Identidad opaca UUID, generada por backend; ver [FILE_IDENTITY](#file-identity-fileid) |
| `objectKey`/referencia interna del provider | Uso exclusivo de `Infrastructure`; nunca sale por HTTP ni es identidad de Application |
| `ownerInstitucionalId` | Identidad institucional del estudiante que subió el objeto; base de todo ownership check |
| `estado` | `DRAFT \| ATTACHED \| ORPHAN \| REPLACED` |
| `nombreOriginalSanitizado` | Para presentación (docente/estudiante); nunca identidad |
| `contentTypeVerificado` | Resultado de la verificación de magic bytes, no el header multipart declarado por el cliente |
| `tamanioVerificado` | Tamaño verificado en el servidor, no el `tamanio` informado por el cliente |
| `createdAt` / `updatedAt` | Timestamps para reconciliación/orphan/retención futura |
| `bindingRevisionId` (solo cuando `ATTACHED`) | Relación durable con la revisión, para resolver ownership de lectura docente/estudiante |

## Dos alternativas (sin diseñar SQL)

### Alternativa A — metadata/binding nuevo en SQL Server

Un objeto de persistencia nuevo (no una expansión de columnas de una tabla existente) que
almacene la metadata mínima anterior y el binding a la revisión. Requiere que el equipo DB diseñe,
apruebe y libere su propio shape (tabla/vista/SP), con su propia gobernanza de migración,
integridad referencial y auditoría. Este backend no propone columnas ni tipos.

- Ventaja: integridad referencial y auditoría fuerte del lado DB; consulta directa por `fileId`.
- Costo: nuevo objeto de persistencia, nueva migración, nuevo SP/vista, y el equipo DB debe asumir
  su diseño y aprobación — no evidenciado todavía.

### Alternativa B — reutilizar columnas existentes + metadata durable del objeto para `DRAFT`

- El estado `DRAFT` (antes de `ATTACH`) no toca SQL Server en absoluto: su metadata durable vive en
  el propio objeto del provider (metadata nativa de MinIO), consultada por
  `FileStoragePort`/adapter, sin requerir una fila SQL previa a la adjunción.
- El binding `ATTACHED` reutiliza las columnas existentes `soporteNombre`/`soporteUrl` (sin cambiar
  su shape): `soporteNombre` conserva el nombre original sanitizado; `soporteUrl` conserva una
  referencia backend-neutral construida a partir de `fileId` (p. ej. una ruta relativa del backend),
  nunca una URL de provider ni un `objectKey`.
- Requiere de todos modos una **nueva capability de consulta** (SP/vista) para resolver, dado un
  `fileId`/referencia, la revisión/sesión/grupo/docente titular asociados — porque
  `GET /docente/reclamos` no tiene hoy ningún SP funcional. Esta capability es necesaria en
  cualquiera de las dos alternativas, no solo en B.
- Riesgo no resuelto por esta inspección: si la reconciliación de `ORPHAN` requiere enumerar/filtrar
  objetos `DRAFT` por metadata a escala, la viabilidad depende de una capability de consulta por
  metadata del provider (p. ej. índices/tags consultables), que no está evidenciada como disponible
  ni decidida en LB-004B.1. Tratar esto como resuelto sin esa evidencia sería inventar una capacidad
  de Infrastructure no verificada.

## Resultado obligatorio

```text
DB_SCHEMA_CHANGE_REQUIRED: DECISION_REQUIRED
DB_PUBLIC_CONTRACT_CHANGE_REQUIRED: YES
```

### Por qué `DECISION_REQUIRED` y no `YES`/`NO`

- No hay evidencia versionada del shape real que respalda `soporteNombre`/`soporteUrl` hoy en DB
  (`DB_BASELINE_CONTRACT.md` no lo cubre); este backend no puede afirmar que la Alternativa B es
  compatible con la integridad/gobernanza que el equipo DB exige para ese objeto, ni que la
  Alternativa A es innecesaria.
- La viabilidad de tratar `DRAFT` sin ninguna fila SQL depende de una capability de reconciliación
  por metadata del provider no evidenciada (ver riesgo arriba), que es en parte una decisión de
  Infrastructure/Azure y en parte una decisión DB (si exigen trazabilidad SQL de todo objeto desde
  su creación, por auditoría, eso empuja hacia la Alternativa A).
- Ninguna de las dos alternativas es una expansión de columnas de una tabla existente prohibida por
  el baseline; ambas son formalmente aceptables bajo la regla vigente, pero elegir cuál requiere al
  dueño del contrato de persistencia, no a este análisis.

### Contrato que se solicita al equipo DB (sin inventar tabla/columna)

1. Confirmar el shape real que respalda `dbo.usp_radicar_solicitud_revision_asistencia` para
   `soporteNombre`/`soporteUrl` (tipo, longitud, nullabilidad) y si admite almacenar una referencia
   backend-neutral basada en `fileId` sin romper su contrato actual (Alternativa B), o si exige un
   objeto nuevo de persistencia para metadata/binding de soportes (Alternativa A).
2. Proveer o aprobar una nueva capability de consulta (SP/vista) que, dado un `fileId`/referencia,
   retorne la revisión, sesión, grupo y docente titular asociados — requerida en ambas alternativas
   para materializar `GET /docente/reclamos` y la regla `DOCENTE_READ_RELATED` ya congelada en
   [OWNERSHIP_DECISION](OWNERSHIP_DECISION.md).
3. Indicar si exigen trazabilidad SQL del estado `DRAFT` desde su creación (lo que inclinaría hacia
   la Alternativa A o hacia un híbrido), o si aceptan que el estado pre-adjunción viva únicamente en
   metadata del objeto en el provider hasta el `ATTACH`.

## Addendum LB-004B.2 — evidencia DB adicional (no cambia el veredicto)

Inspección read-only adicional del repositorio DB (`gestion-asistencia-db`, rama `sergio`, commit
`bc6aae0`) confirma, sin modificar nada:

- `usp_radicar_solicitud_revision_asistencia` recibe `@soporteNombre`/`@soporteUrl` pero **no los
  persiste**: el `INSERT INTO dbo.SolicitudRevisionAsistencia` no incluye esas columnas.
- La tabla `SolicitudRevisionAsistencia` no tiene ninguna columna de soporte/archivo hoy.
- No existe SP/vista con nombre relacionado a "reclamo"; `GET /docente/reclamos` no tiene backing SP,
  confirmando `FeatureUnavailable` AS-IS.
- `usp_resolver_solicitud_revision_asistencia` sí resuelve la cadena
  `SolicitudRevisionAsistencia -> Asistencia -> Sesion -> Grupo.docente`, lo que sugiere que la
  capability de consulta pedida al equipo DB (punto 2 de "Contrato que se solicita al equipo DB")
  es alcanzable componiendo objetos existentes, sin necesariamente requerir una tabla nueva solo
  para eso — pero esto sigue siendo una observación, no una decisión: el equipo DB debe confirmarlo.

Esta evidencia **no cambia** `DB_SCHEMA_CHANGE_REQUIRED: DECISION_REQUIRED`: sigue sin existir
ninguna columna que respalde una referencia backend-neutral a `fileId`, y el backend no diseña ni
aprueba schema por sí mismo. Se registra aquí únicamente como insumo adicional para la microfase DB
independiente (`NEXT: DB CONTRACT MICROPHASE`), consistente con `REVIEW_BINDING:
BLOCKED_BY_DB_CONTRACT` en [PROFESSOR_DECISION](PROFESSOR_DECISION.md).

## File identity (`fileId`)

Congelado, sin cambios respecto a LB-004B.0 (`D-LB004B0-002`): `fileId` es un UUID opaco generado
por el backend. Prohibido usar `filename`, `nombreGuardado`, path de filesystem, URL de Blob u
`objectKey` como identidad de Application. El provider puede administrar `objectKey`
internamente en Infrastructure; Application y HTTP solo conocen `fileId` y la metadata neutral de
esta tabla.

```text
FILE_ID_CONTRACT: FROZEN
OBJECT_IDENTITY: fileId UUID opaco, generado por backend
PROHIBITED_AS_IDENTITY: filename, nombreGuardado, filesystem path, Blob URL, objectKey
```
