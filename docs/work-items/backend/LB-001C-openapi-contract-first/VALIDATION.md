---
status: active
type: validation
scope: backend
owner: backend-team
last-reviewed: 2026-09-24
---

# VALIDATION — LB-001C.1

## Dictamen

**PASS.** Contrato, SHA, parser, referencias, conformance, build, arquitectura y cobertura pasan.
Auditoría realizada por el mismo agente en un pase conceptual separado; no se afirma revisión
externa independiente.

## Entorno y base

- Windows 11, Java 25 (`C:\Program Files\Java\jdk-25`), Maven Wrapper 3.9.15.
- Rama `sergio`, base `fa9aa901c73e55ae31071f4e74cfb2245189243a`.
- Worktree sucio previo preservado; no se revirtieron ni apropiaron cambios ajenos.
- Fecha de validación: 2026-09-24, zona America/Bogota.

## Ejecuciones

| Comando | Exit | Resultado |
|---|---:|---|
| `./mvnw.cmd '-Dtest=OpenApiGoldenPathValidationTest,OpenApiGoldenPathConformanceTest' test` | 0 | 5 tests, 0F/0E/0S; primera corrida contractual GREEN (`NO_RED_OBSERVED`) |
| `./mvnw.cmd verify` | 0 | BUILD SUCCESS; 975 tests, 0F/0E/0S; JAR, JaCoCo report/check |
| `git diff --check` | 0 | sin whitespace errors; Git emitió warning LF→CRLF sobre `.gitignore` preexistente/no modificado por C.1 |

Los primeros intentos dentro del sandbox fallaron antes de cargar el proyecto por bloqueo de red
Maven (`Permission denied: getsockopt`). Se repitieron con acceso autorizado a Maven Central; no
se contabilizan como fallo de contrato.

## Gates

| Gate | Resultado | Evidencia |
|---|---|---|
| OpenAPI 3.1.2/YAML | PASS | Swagger Parser 2.1.46, cero mensajes |
| Broken `$ref` | PASS, 0 | resolución parser + recorrido de referencias locales |
| SHA-256 | PASS | `c4fb9f53a636410e0c58084f740bf965a9c782ed72bf848224c24357f53dba25` (vigente tras C.1A) |
| Controller conformance | PASS | 8 métodos/paths exactos; success status y media types |
| DTO conformance | PASS | request/response properties, ghosts, enum y maxLength críticos |
| Contract tests | PASS | 5/5 |
| Backend tests | PASS | 975/975, 0 skips |
| ArchUnit | PASS | 67/67, 0F/0E/0S |
| JaCoCo LINE | PASS | 6.927 cubiertas / 7.987 total = 86,73 % (gate 80 %) |
| JaCoCo BRANCH | PASS | 1.414 cubiertas / 1.992 total = 70,98 % (gate 70 %) |
| Seguridad | PASS aplicable | tests RBAC/security en verify; bearer/401/403/envelope congelados |
| DB integration | NO APLICA | no cambia persistencia; TD-043 fuera del Golden Path sigue visible |
| MV-001 | PASS_REPORTED_EXTERNAL | [ENTRY_EVIDENCE](ENTRY_EVIDENCE.md); no reproducido aquí |
| CI remoto/MV-004 | PENDIENTE | no se presume desde Maven local |

## HTTP METHOD AUDIT

- GET 5; POST 2; PUT 1; PATCH 0; DELETE 0; total 8.
- PUT sesión: partial representation AS-IS, frontend validado según entrada;
  `MIGRATION_CANDIDATE`, sin cambio en C.1.
- DELETE: ninguno en el Golden Path.
- METHOD_EXCEPTION: ninguna nueva.

## Swagger compatibility

- Swagger Editor compatible: **YES**, sustentado por parse/validation OpenAPI 3.1.2 sin errores.
- Limitación: no se abrió una UI remota ni se cargó el contrato en un editor web durante esta
  corrida; la afirmación es estructural/parser, no evidencia visual.
- Swagger UI strategy: UI futura/runtime servirá el YAML canónico estático. No annotations, no
  code-first, no dependencia runtime en C.1. Spring Boot 4/Java 25 no se arriesgan todavía con una
  integración UI no necesaria para el gate.

## Alcance y limitaciones

- Producción Java/resources: no modificados por LB-001C.1.
- Frontend/DB/Keycloak/infra/workflows: no modificados.
- No JPA/Redis/RabbitMQ/serverless/codegen.
- Fechas de sesión: la afirmación original de C.1 sobre `format: date-time` fue corregida por el
  hardening C.1A. El wire AS-IS sigue siendo ISO local sin offset, expresado por type/pattern/
  extensiones y sin format RFC 3339; migrarlo exige fase compatible.
- 409 no se añadió a las operaciones: no existe evidencia específica aplicable en estas 8; no se
  inventó para satisfacer una lista genérica.

## Hashes

- OpenAPI vigente tras C.1A:
  `c4fb9f53a636410e0c58084f740bf965a9c782ed72bf848224c24357f53dba25`.
- BACKEND_GOLDEN_PATH_CONTRACT (sin cambios):
  `02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121`.
- Tests congelados: ver [LB-001C.1-RED-SNAPSHOT](LB-001C.1-RED-SNAPSHOT.md).

## Addendum de validación — LB-001C.1A Contract Hardening

### Dictamen

**PASS.** Auditoría realizada por el mismo agente en un pase conceptual separado; no se afirma
independencia externa. El hardening corrige semántica OpenAPI sin cambiar el wire ni producción.

### RED → GREEN

| Comando / evidencia | Exit | Resultado |
|---|---:|---|
| `./mvnw.cmd '-Dtest=OpenApiGoldenPathConformanceTest' test` sobre YAML C.1 | 1 | RED causal: 7 tests, 3F/0E/0S; localhost, format local incorrecto y UUID realtime ausente |
| mismo comando tras el cambio contractual | 0 | GREEN: 7/7, 0F/0E/0S |
| `./mvnw.cmd '-Dtest=OpenApiGoldenPathValidationTest,OpenApiGoldenPathConformanceTest' test` | 0 | OpenAPI completo 9/9, parser/ref/SHA/conformance PASS |
| `./mvnw.cmd verify` | 0 | BUILD SUCCESS; 979 tests, 0F/0E/0S; JAR y JaCoCo check PASS |
| `git diff --check` | 0 | sin whitespace errors; warning LF→CRLF sobre `.gitignore` preexistente |

El primer intento focalizado no cargó el proyecto por `Permission denied: getsockopt` contra
Maven Central; se repitió con acceso autorizado y no se contó como RED. La corrección del tester
por el modelo inline de `items.$ref` de Swagger Parser está trazada en
[RED C.1A](LB-001C.1A-RED-SNAPSHOT.md).

### Gates C.1A

| Gate | Resultado | Evidencia |
|---|---|---|
| LocalSessionDateTime | PASS | string + pattern local; sin `format`; wire/extensiones/example preservados |
| Instantes RFC 3339 | PASS | realtime `occurredAt` y error `timestamp` conservan `date-time` |
| Properties/required | PASS | expectations contractuales explícitas para 18 object schemas; sin reflection para required |
| Tipos/UUID/constraints | PASS | tipos críticos, UUID, enum `AN/SJC/EX`, nombre 1..50, registros minItems=1 |
| Ghost fields | PASS | properties exactas + `additionalProperties=false` |
| Security | PASS | bearerAuth `http`/`bearer`/`JWT`; 8/8 operaciones |
| Correlation | PASS | component parameter/header; request 8/8 y success response 8/8 |
| Server portability | PASS | server relativo `/`, sin dominio ficticio |
| Swagger Parser / refs / SHA | PASS | cero mensajes, broken refs=0, hash MATCH |
| ArchUnit | PASS | 67/67, 0F/0E/0S |
| JaCoCo LINE | PASS | 6.927/7.987 = 86,73 % (gate 80 %) |
| JaCoCo BRANCH | PASS | 1.414/1.992 = 70,98 % (gate 70 %) |
| DB/frontend/Keycloak runtime | NO APLICA | no se modifican ni se requieren para este contrato estático |
| CI remoto | PENDIENTE | no se presume desde el verify local |

### Hashes C.1A

- OpenAPI: `c4fb9f53a636410e0c58084f740bf965a9c782ed72bf848224c24357f53dba25`.
- Test RED: `c89c143192b446b49aadddc78af8ed9fd300549cca0286bac99b57b38ba7852e`.
- Test GREEN tras corrección trazada:
  `082ad87e7e11f6430759f02434f1713212eea2c7e9211e6f8a27f8a7a388adb3`.
- `BACKEND_GOLDEN_PATH_CONTRACT.md` sin cambios:
  `02a174564defb17313b7e74aee10351aa8452f161e8fab196403f40ede3db121`.

### Auditoría de alcance

- Producción Java/resources, frontend, DB/SQL, Keycloak, infra y workflows: no modificados por
  C.1A.
- DTOs, serialización y wire temporal: no modificados.
- LB-001C.2/JPA: no iniciados.
- HTTP METHOD AUDIT: sin cambios; continúa GET 5, POST 2, PUT 1, DELETE 0.

## Addendum final — restauración del provider DTO conformance gate

### Dictamen

**PASS.** Se restauró OAS-07D como gate aditivo e independiente de las expectations
contractuales. Los nueve DTOs coinciden con sus schemas; no apareció mismatch ni
`CONTRACT_CONFLICT`. Resultado RED honesto: `NO_RED_OBSERVED`.

### Ejecuciones

| Comando / evidencia | Exit | Resultado |
|---|---:|---|
| `./mvnw.cmd '-Dtest=OpenApiGoldenPathConformanceTest,OpenApiGoldenPathValidationTest' test` antes de OAS-07D | 0 | baseline GREEN: 9/9, 0F/0E/0S; `NO_RED_OBSERVED` |
| mismo comando con OAS-07D | 0 | 10/10, 0F/0E/0S; conformance 8/8 y validation/SHA 2/2 |
| `./mvnw.cmd verify` | 0 | BUILD SUCCESS; 980/980, 0F/0E/0S; JAR y JaCoCo check PASS |

El primer intento baseline dentro del sandbox terminó antes de cargar el proyecto por
`Permission denied: getsockopt` contra Maven Central. Se repitió con acceso autorizado; no se
contabiliza como fallo de test o contrato.

### Gates finales C.1A

| Gate | Resultado | Evidencia |
|---|---|---|
| DTO property conformance | PASS | 9/9 pares schema↔DTO, igualdad exacta de nombres |
| OAS-07 contract expectation | PASS | properties/required/types/formats/constraints/enum/additionalProperties preservados |
| OAS-07D provider DTO shape | PASS | records vía `recordComponents`; JavaBeans vía `BeanInfo`, sin `class` |
| Controller conformance | PASS | 8 methods/paths/status/media types |
| OpenAPI validation | PASS | parser y refs PASS; SHA MATCH |
| ArchUnit | PASS | 67/67, 0F/0E/0S |
| JaCoCo LINE | PASS | 6.927/7.987 = 86,73 % (gate 80 %) |
| JaCoCo BRANCH | PASS | 1.414/1.992 = 70,98 % (gate 70 %) |

### Integridad y alcance final

- OpenAPI SHA-256: `c4fb9f53a636410e0c58084f740bf965a9c782ed72bf848224c24357f53dba25`.
- SHA-256 del test con OAS-07D:
  `3552a11afa0a0930e747b2e7323dcddac87b8235288305c1eabc1642e1f99694`.
- YAML, producción, frontend, DB y Keycloak: no modificados.
- JPA y LB-001C.2: no iniciados.
- Commits/push: no realizados.
