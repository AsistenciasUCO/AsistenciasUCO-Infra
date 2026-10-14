---
status: active
type: test-plan
scope: backend
owner: backend-team
last-reviewed: 2026-09-24
---

# TEST PLAN — LB-001C.1

## Matriz

| ID | Requisito | Prueba | Resultado esperado |
|---|---|---|---|
| OAS-01 | YAML/OpenAPI válido | Swagger Parser 3.1 con resolve | modelo no nulo, cero mensajes de error |
| OAS-02 | `$ref` íntegros | parser + recorrido de refs locales | cero refs rotos |
| OAS-03 | versión/fuente | aserción `openapi=3.1.2`, info/servers/tags/components | PASS |
| OAS-04 | inventario completo | paths/métodos de spec vs mappings Golden Path | 8/8; sin extras |
| OAS-05 | statuses | invocar controllers o semántica HTTP implícita SSE y comparar success | 200/201 AS-IS |
| OAS-06 | media types | annotations/request bodies/responses vs spec | JSON; SSE `text/event-stream` |
| OAS-07 CONTRACT SCHEMA | Schema crítico | OpenAPI properties/required/types/enums/constraints vs contrato congelado | igualdad contractual; sin ghosts; AN/SJC/EX cerrado |
| OAS-07D PROVIDER DTO SHAPE | DTO provider crítico | OpenAPI properties vs `recordComponents`/`BeanInfo` de los 9 DTO/request/response Java reales | igualdad exacta de nombres; `class` excluida; no infiere required/nullability/constraints |
| OAS-08 | seguridad/correlación | bearerAuth y header reusable en respuestas | PASS |
| OAS-09 | reglas PUT | PUT existente clasificado `MIGRATION_CANDIDATE`; no DELETE Golden Path | PASS documental |
| SHA-01 | integridad | SHA-256 recalculado vs `.sha256` | MATCH |
| REG-01 | regresión | `mvn verify` JDK 25 | tests, ArchUnit y JaCoCo PASS |

## RED_SNAPSHOT

- Base: `fa9aa901c73e55ae31071f4e74cfb2245189243a` + worktree previo preservado.
- Tests previstos: `src/test/java/co/edu/uco/asistenciasuco/openapi/*Test.java`.
- RED causal esperado solo si el spec/gate contradice el contrato o controllers.
- No se fabricará una falla retirando/rompiendo el YAML. Si la primera ejecución posterior a
  crear contrato y tests es verde, registrar `NO_RED_OBSERVED` en
  `LB-001C.1-RED-SNAPSHOT.md`, como autoriza la orden.
- El hash de los tests se registrará tras fijar su contenido y antes de cualquier corrección.

## Ambientes y límites

No requiere DB, frontend, Keycloak ni tokens reales. Usa tests unitarios/reflexión/controllers
con mocks. No prueba E2E ni Swagger UI renderizado; la compatibilidad del UI se sustenta en el
parser OpenAPI 3.1 y la estructura estándar, con la limitación consignada en VALIDATION.

## Addendum LB-001C.1A — hardening posterior al review

La historia y el resultado de C.1 anteriores se conservan. C.1A amplía los gates sobre el
contrato ya congelado, sin inferir `required` ni nullability desde reflection Java.

| ID | Requisito C.1A | Prueba RED | Resultado esperado GREEN |
|---|---|---|---|
| OAS-03A | Server portable | rechazar un único server absoluto localhost | `servers=[/]` con descripción contractual |
| OAS-07A | Schemas exactos | properties y required congelados para objetos críticos | igualdad exacta; sin ghost fields |
| OAS-07B | Tipos/UUID/constraints | tipos críticos, UUID, enum, nombre 1..50, registros minItems=1 y `additionalProperties=false` | PASS |
| OAS-07C | Semántica temporal | exigir LocalSessionDateTime sin format y con pattern local; realtime/error mantienen date-time | PASS |
| OAS-08A | Seguridad | bearerAuth reusable `http/bearer/JWT` y security por las 8 operaciones | PASS |
| OAS-08B | Correlación | parameter/header reusable, request parameter en 8/8 y header en cada success | PASS |

### RED_SNAPSHOT C.1A

- Base: `fa9aa901c73e55ae31071f4e74cfb2245189243a` + worktree C.1 preservado.
- Archivo RED: `src/test/java/co/edu/uco/asistenciasuco/openapi/OpenApiGoldenPathConformanceTest.java`.
- Comando: `./mvnw.cmd '-Dtest=OpenApiGoldenPathConformanceTest' test` con JDK 25.
- Fallos causales esperados con el YAML C.1: `LocalSessionDateTime.format=date-time` y server
  exclusivamente `http://localhost:8080`; cualquier garantía adicional ausente debe fallar por
  su assertion específica.
- El SHA-256, fecha, exit code y fallos reales se registrarán en
  `LB-001C.1A-RED-SNAPSHOT.md` antes de modificar el YAML.

### Restauración final OAS-07D

- `OAS-07 CONTRACT SCHEMA` conserva expectations hardcodeadas para properties, required, tipos,
  formatos, constraints, enum y `additionalProperties=false`.
- `OAS-07D PROVIDER DTO SHAPE` compara únicamente nombres de properties del schema con el DTO Java
  real para `HorarioDocenteDTO`, `SesionConsultadaDTO`, `EstudianteGrupoDTO`,
  `AsistenciaConsultadaDTO`, `RegistrarAsistenciasSesionRequest`, `RegistroAsistenciaRequest`,
  `CrearSesionRequest`, `ActualizarSesionRequest` y `RealtimeEventResponse`.
- Records: `recordComponents`. JavaBeans: `BeanInfo`/`PropertyDescriptor`, excluyendo `class`.
- No se deriva required, nullability, constraints, enum, format ni defaults desde Java.
- Si el estado actual coincide en la primera corrida, registrar `NO_RED_OBSERVED`; no fabricar RED
  ni modificar producción.
