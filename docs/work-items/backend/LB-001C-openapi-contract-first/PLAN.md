---
status: active
type: plan
scope: backend
owner: backend-team
last-reviewed: 2026-09-24
---

# PLAN — LB-001C.1: API style + OpenAPI/Swagger Golden Path baseline

## Identidad y objetivo

- Fecha / rol / base Git: 2026-09-24 / 01-planificador / rama `sergio`, base
  `fa9aa901c73e55ae31071f4e74cfb2245189243a`, worktree con cambios previos del usuario.
- Objetivo: gobernar el estilo `PRAGMATIC_RESOURCE_PLUS_BUSINESS_COMMAND`, congelar en OpenAPI
  3.1.2 las 8 operaciones del Golden Path ya aprobadas, agregar validación y conformance en
  `mvn verify`, y dejar una estrategia Swagger UI estática sin convertir annotations en fuente.
- Criterios: reglas API normativas; inventario y auditoría HTTP; YAML canónico y SHA-256; parser
  sin errores/$ref rotos; tests de método/path/status/media/schema; verify/ArchUnit/JaCoCo verdes;
  producción, frontend, DB y Keycloak sin cambios.
- Skills: `uco-baseline`, `uco-contratos`, `uco-testing`, `uco-seguridad`,
  `uco-observabilidad`, `uco-realtime`.
- Autorización y estado de entrada: [ENTRY_EVIDENCE](ENTRY_EVIDENCE.md).

## AS-IS y evidencia

| Hecho | Fuente | Límite |
|---|---|---|
| Ocho operaciones Golden Path, roles, envelopes, DTOs, tiempos y SSE | `docs/contracts/BACKEND_GOLDEN_PATH_CONTRACT.md` | No incluye endpoints legacy/administrativos |
| Controllers y DTOs implementados | `src/main/java/**/controller/**`, `SecurityConfig` | Código describe AS-IS; no sustituye contrato aprobado |
| Contrato realtime best-effort | `REALTIME_EVENT_STANDARD.md`, `reactive-realtime.md` | Sin replay/durabilidad/multi-instancia |
| API sin OpenAPI aprobado ni gate | `OPENAPI_STANDARD.md`, `pom.xml` | Brecha TD-002 |
| PUT de sesión existente y consumido | `SesionController`, contrato backend | Compatibilidad: no se cambia en esta microfase |
| MV-001 PASS | [ENTRY_EVIDENCE](ENTRY_EVIDENCE.md) | Certificación externa reportada; artefacto no presente |

## TARGET

- Contrato canónico: `docs/contracts/openapi/openapi-golden-path.yaml`, OpenAPI 3.1.2.
- Estilo: recursos pragmáticos + comandos de negocio; PUT/DELETE nuevos restringidos por
  `METHOD_EXCEPTION`; métodos existentes se inventarían y clasifican antes de migrar.
- El PUT existente de sesión se congela por compatibilidad como `MIGRATION_CANDIDATE`, no como
  precedente para APIs nuevas.
- Swagger Editor/UI consumen el YAML; no se agregan annotations ni runtime dependency en C.1.
- Gate de test con Swagger Parser solo en scope `test` y conformance por reflexión/invocación de
  controllers, sin generación de código.

## Clase de cambio y alcance de rutas

- Change class: `CONTRACT_CHANGE` (contrato, gobernanza y gate de test; sin behavior change).
- Variable principal: contrato público Golden Path HTTP/SSE.
- Allowed:
  - `AGENTS.md`, `.claude/agents/*.md`;
  - `docs/governance/API_DESIGN_RULES.md`, `docs/governance/SOURCE_OF_TRUTH.md`;
  - `docs/contracts/OPENAPI_STANDARD.md`, `docs/contracts/openapi/**`;
  - `docs/architecture/http-command-query-guidelines.md` y `docs/testing/TESTING_STANDARD.md`
    para retirar CF-001 y registrar el gate;
  - `contracts/openapi/README.md` como redirección histórica;
  - `docs/work-items/LB-001C-openapi-contract-first/**`;
  - `docs/baseline/{LINEA_BASE,TECHNICAL_DEBT,MANUAL_VALIDATION_LEDGER}.md`;
  - `docs/README.md` si requiere actualizar navegación;
  - `pom.xml` exclusivamente para dependencia de validación en tests;
  - `src/test/java/**/openapi/**`.
- Forbidden:
  - `src/main/**`, `src/main/resources/**`, otros tests no RED de esta fase;
  - frontend, DB/SQL, Keycloak/IdP, `infra/**`, `.github/workflows/**`;
  - JPA, Redis, RabbitMQ, serverless, cliente Angular, Swagger annotations y code generation.

Lo no listado como Allowed no se modifica. Los cambios previos del worktree se preservan.

## Alcance

1. Resolver CF-001/TD-028 con norma única de estilo API.
2. Inventariar exactamente las 8 operaciones Golden Path y auditar sus métodos.
3. Crear spec 3.1.2, ejemplos ficticios, seguridad/correlación/errores/SSE y SHA.
4. Agregar validación semántica/$ref y conformance crítica al lifecycle de tests Maven.
5. Actualizar instrucciones mínimas de agentes y evidencia de fase.

## No alcance

Migrar PUT a PATCH; cambiar URL/status/DTO; documentar toda la API; integrar Swagger UI runtime;
generar clientes; corregir TD-049/TD-050; ejecutar DB/Keycloak/frontend; iniciar C.2 o LB-002.

## Archivos afectados

- EXISTENTES: las rutas Allowed ya presentes.
- NUEVOS: `API_DESIGN_RULES.md`, `docs/contracts/openapi/{openapi-golden-path.yaml,
  openapi-golden-path.sha256}`, documentos del work item y tests bajo `.../openapi/`.
- RETIRAR: ninguno.

## Contratos y consumidores afectados

- HTTP: freeze del Golden Path AS-IS aprobado; frontend verificado según evidencia de entrada.
- SECURITY: Bearer/roles/ownership y 401/403 preservados.
- REALTIME: SSE como señal; HTTP source of truth; sin nuevas garantías.
- DOMAIN/PERSISTENCE: no cambian. DBCODE no se expone.

## Riesgos y dependencias

- OpenAPI 3.1 `date-time` exige offset, mientras el wire AS-IS de sesión usa ISO local sin zona.
  Se documenta como extensión de compatibilidad y `MIGRATION_CANDIDATE`; no se finge UTC wire.
- El parser puede emitir warnings o no validar cada keyword JSON Schema; se complementa con
  assertions críticas de estructura/ref/schema.
- El worktree está sucio; se usan archivos nuevos y parches focalizados sin revertir cambios.
- Dependencia de test nueva puede requerir descarga de Maven.

## Test plan

Ver [TEST_PLAN](TEST_PLAN.md). Secuencia: contrato aprobado por esta orden → tests/gate → snapshot
RED honesto (o `NO_RED_OBSERVED`) → verify → auditoría.

## Rollback

Retirar únicamente los archivos nuevos de C.1, la dependencia de test Swagger Parser y las
referencias de gobernanza/ledgers de esta fase. No hay migración de datos ni producción que
revertir. Conservar evidencia histórica del work item si el contrato se reemplaza.

## Stop conditions

- `CONTRACT_CONFLICT`: evidencia del controller contradice el contrato backend aprobado.
- `TEST_CONTRACT_CONFLICT`: una aserción exige semántica no aprobada.
- `BLOCKED_BY_MISSING_EVIDENCE`: endpoint/DTO/rol/status no respaldado.
- Parser OpenAPI o SHA fallan; verify/ArchUnit/JaCoCo fallan; cambios fuera de Allowed.

## Deuda conocida y validación manual

- TD-049 y TD-050 abiertas `NON_BLOCKING` según entrada.
- TD-003, TD-041, TD-043, TD-045 y TD-046 permanecen sin ampliación de alcance.
- MV-001 pasa a `PASS_REPORTED_EXTERNAL` con limitación; MV-004 sigue pendiente.

## Definition of Ready

**READY.** La orden actual aporta autorización humana, estilo/métodos/OpenAPI version/path y
estado de entrada; el contrato backend aprobado y el código permiten derivar spec/tests; el gate
técnico previo es verde. No quedan conflictos relevantes para documentar las 8 operaciones. La
divergencia temporal se conserva como AS-IS explícito y candidato de migración, no como cambio de
producción silencioso.

## Addendum LB-001C.1A — OpenAPI Contract Hardening

- Fecha / autorización: 2026-09-24 / orden humana `LB-001C.1A — OPENAPI CONTRACT HARDENING`.
- Change class: `CONTRACT_CHANGE`, sin cambio de comportamiento ni código productivo.
- Variable principal: precisión semántica y ejecutabilidad del contrato OpenAPI Golden Path.
- Objetivo: retirar `format: date-time` exclusivamente de `LocalSessionDateTime`, conservar el
  wire local AS-IS, endurecer OAS-07/OAS-08 y hacer portable la declaración `servers`.
- Rutas permitidas: `docs/contracts/openapi/**`,
  `src/test/java/co/edu/uco/asistenciasuco/openapi/**`,
  `docs/work-items/LB-001C-openapi-contract-first/**` y `docs/baseline/LINEA_BASE.md`.
- Rutas prohibidas: `src/main/**`, frontend, DB/SQL, Keycloak/IdP, `infra/**`, runtime config,
  otros tests, `pom.xml`, workflows, JPA y cualquier alcance de LB-001C.2.
- AS-IS: `LocalSessionDateTime` combina un pattern local sin offset con el format RFC 3339
  `date-time`; `servers` publica exclusivamente `http://localhost:8080`; OAS-07/OAS-08 no
  ejecutan toda la matriz ya declarada en TEST_PLAN.
- TARGET aprobado: `LocalSessionDateTime` mantiene `type`, `pattern`, descripción, extensiones y
  ejemplo, pero sin `format`; `RealtimeEventResponse.occurredAt` y `ApiErrorResponse.timestamp`
  conservan `date-time`; server relativo `/`; gates explícitos de properties/required/tipos/
  constraints/seguridad/correlación para las 8 operaciones.
- Consumidores: Swagger/parser y clientes del Golden Path; no cambia ningún valor JSON ni
  endpoint, por lo que la compatibilidad wire se preserva.
- Riesgos: resolver `$ref` sin ocultar constraints, confundir required con reflexión Java o
  convertir el hardening en una migración temporal. Mitigación: expectations congeladas desde
  contrato aprobado y pruebas RED causales antes del YAML.
- Rollback: revertir exclusivamente el addendum C.1A, las assertions nuevas, el cambio puntual
  del YAML y su SHA; no hay datos ni runtime que restaurar.
- Stop conditions: conflicto con contrato aprobado, RED no causal, parser/ref/SHA/verify rojo,
  o cualquier cambio fuera de rutas permitidas.
- Deuda/validación manual: no crea deuda ni exige DB/frontend/Keycloak/E2E; CI remoto continúa
  pendiente y no se presume.

### Definition of Ready C.1A

**READY.** La orden fija resultado, alcance, no alcance, contrato temporal, server portable,
matriz OAS-07/OAS-08 y validación. Las fuentes aprobadas respaldan required, tipos, constraints,
Bearer JWT y correlación. No hay `CONTRACT_CONFLICT`, `TEST_CONTRACT_CONFLICT` ni
`BLOCKED_BY_MISSING_EVIDENCE` relevantes. LB-001C.2 permanece `NOT STARTED`.

## Addendum final LB-001C.1A — restauración del gate de conformance DTO

- Fecha / autorización: 2026-09-24 / orden humana `LB-001C.1A — FINAL DTO CONFORMANCE GATE RESTORATION`.
- Change class: `CONTRACT_CHANGE` limitado al gate de test y su evidencia; OpenAPI y runtime no
  cambian.
- Variable principal: detección de drift entre nombres de properties OpenAPI y DTO Java provider.
- TARGET: conservar el gate de expectations contractuales y agregar un gate independiente para
  los 9 DTO/request/response críticos. Records se inspeccionan con `recordComponents`; JavaBeans
  con `BeanInfo`/`PropertyDescriptor`, excluyendo `class`.
- Rutas permitidas: `src/test/java/co/edu/uco/asistenciasuco/openapi/**` y evidencia de este work
  item. Rutas prohibidas: `src/main/**`, YAML/OpenAPI salvo mismatch real, frontend, DB, Keycloak,
  JPA, `pom.xml`, workflows y cualquier alcance de LB-001C.2.
- Reflection no gobierna required, nullability, constraints, enum, format ni defaults; esas
  expectations permanecen congeladas por contrato.
- Stop condition: un mismatch real es `CONTRACT_CONFLICT` y detiene cambios de OpenAPI/producción.
- Rollback: retirar solo el test/helper OAS-07D y este addendum documental.

### Definition of Ready — restauración final

**READY.** La orden identifica los 9 pares DTO/schema, el mecanismo de inspección, las rutas
permitidas/prohibidas, la validación y la conducta ante mismatch. No hay conflicto abierto de
entrada y LB-001C.2 permanece `NOT STARTED`.
