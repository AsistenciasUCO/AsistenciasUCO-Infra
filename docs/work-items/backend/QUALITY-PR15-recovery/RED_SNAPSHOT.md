---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# QUALITY-PR15 — RED_SNAPSHOT Q2/Q3 (certificado con Java 25)

Base: `31dbddd150136ac7a40112c1451b4c36e42bfd8b` (rama `jose-valencia/lb-004-stateless-serverless-readiness`).
Rol: tester (Claude, misma herramienta que el implementador posterior → **independencia limitada**; auditoría humana pendiente).
Entorno: JDK 25 (`JAVA_HOME=C:\Program Files\Java\jdk-25`), `mvnw.cmd`, Windows 11. Fecha 2026-10-08.
El commit que contiene este archivo es el snapshot RED congelado; el implementador no modifica estos tests.

## 1. Certificación de las 8 suites candidatas (antes de correcciones)
Comando: `./mvnw.cmd -B -ntp "-Dtest=ClamAvProtocolBoundaryTest,CompressionPolicyExpansionBoundaryTest,MinioReadBudgetTest,ParameterCatalogJpaBehaviorTest,MessageCatalogJpaBehaviorTest,CoreViewJpaProjectionBehaviorTest,AcademicViewJpaProjectionBehaviorTest,ArchivoControllerSecurityBoundaryTest" -Djacoco.skip=true test` → exit 1; 37 tests, 5 failures, 0 errors. Compilación: PASS (sin errores).

| Suite | Tests | Clasificación inicial | Acción tester |
|---|---:|---|---|
| ClamAvProtocolBoundaryTest | 5 | 2 RED funcional (sufijo `OK` arbitrario, respuesta sin NUL); 3 GREEN regresión | ninguna |
| CompressionPolicyExpansionBoundaryTest | 2 | 1 RED funcional (inflate sin límite); 1 GREEN control | ninguna |
| MinioReadBudgetTest | 1 | **PROBLEMA DE FIXTURE / TEST_TOO_WEAK**: pasaba en vacío | reescrita (ver §2) |
| CoreViewJpaProjectionBehaviorTest | 4 | **PROBLEMA DE FIXTURE** en 2 casos (falla por la causa equivocada) | stub explícito de `null` |
| AcademicViewJpaProjectionBehaviorTest | 5 | GREEN regresión | ninguna |
| ParameterCatalogJpaBehaviorTest | 9 | GREEN regresión | ninguna |
| MessageCatalogJpaBehaviorTest | 7 | GREEN regresión | ninguna |
| ArchivoControllerSecurityBoundaryTest | 4 | GREEN regresión | ninguna |

## 2. Correcciones de tester (solo `src/test/**`)
- **MinioReadBudgetTest**: mockeaba `GetObjectResponse`; Mockito anula `InputStream.transferTo` (consumo 0) y la excepción esperada nacía de `userMetadata()` nulo (NPE envuelta), no del presupuesto. Ahora usa un `GetObjectResponse` real sobre un stream contador y metadata válida. Se añaden: cuerpo más largo que el tamaño declarado (RED) y control positivo de 5 MiB exactos (GREEN).
- **CoreViewJpaProjectionBehaviorTest**: Mockito devuelve `0` (no `null`) para `Integer`; el test fallaba con `"0"` y no demostraba el defecto `"null"`. Se stubbea `codigoGrupo()`/`codigo()` a `null`. Oráculo verificado en el baseline JDBC retirado (`4cae0a3~1`): `SesionRepositorySqlServerAdapter` usaba `JdbcValueMapper.toString(rs.getObject("codigoGrupo"))` y `GrupoRepositoryRowMapper` `resultSet.getString("codigo")` → `null`. Contrato correcto; fallo ahora causal (`expected <null> but was "null"`).

## 3. RED nuevos derivados de issues Sonar exactos y riesgos verificados
| Archivo | Origen | Fallo RED observado |
|---|---|---|
| ByteArrayRecordValueSemanticsTest (21 casos) | Sonar java:S6218 ×7 (ver SONAR_TRIAGE) | 14 fallan: equals/toString por identidad `[B@…` |
| EstudianteJpaQueryContractTest (7) | Sonar java:S2077 ×2 | 1 falla: JPQL varía con los filtros; 6 GREEN conductuales |
| ClamAvFailClosedBoundaryTest (8) | Sonar java:S8786 + S03/S04 | 2 fallan: firma vacía y respuesta de 64 KiB aceptadas como INFECTED; 6 GREEN |
| DescargarArchivoFailClosedTest (4) | F08 ownership DENY_BY_DEFAULT | 1 falla: metadata sin owner → `NullPointerException` (500) en vez de 404 |

## 4. Snapshot final
Comando (12 suites) → exit 1; **79 tests, 25 failures, 0 errors, 0 skipped**. Todos los fallos son aserciones semánticas; controles positivos en verde.

| Archivo de test | SHA-256 |
|---|---|
| ClamAvProtocolBoundaryTest.java | 39c6cfca8f5499d40b1d81bc890c3521c8e2444b840fba9b380a34424eca25e0 |
| ClamAvFailClosedBoundaryTest.java | bce3161a0134a9cd90f7fe1e6efc6bfce82f6f2536d1fdb772cf387ff937ee52 |
| CompressionPolicyExpansionBoundaryTest.java | 23e2c53864c3f51a1bc1da03d75832dd6200d3cbe3992ee0566822512d17d638 |
| MinioReadBudgetTest.java | d769b2dda4a4f3461236b10e8af73d62162fd4883c4663e0d95f64c6f85a0405 |
| CoreViewJpaProjectionBehaviorTest.java | a1ac6970ea5a391387003b0a8169aedb2373593c6bf66b52c3136b6ebb2238dc |
| ByteArrayRecordValueSemanticsTest.java | 7f0c5a18ae071bb7ce25641b1f696c6f6033e37f567b1113bad40338af9399f4 |
| EstudianteJpaQueryContractTest.java | bddc0970c14aca6a4b56cd0cc74045ad4fd57fe623fa32b304409bb287beb974 |
| DescargarArchivoFailClosedTest.java | 526593a4262144798f3bdad91996f82b1a7c8cf58152fe25acd23c8b0a0d9a02 |

## 5. Decisiones de contrato usadas / no tomadas
- Límites usados: 5 MiB (`CONTENT_SECURITY`), fail-closed ClamAV (`CONTENT_SECURITY`), deny-by-default (`PROFESSOR_DECISION` addendum 7). Ninguno nuevo.
- **No** se crean RED para `X-Content-Type-Options: nosniff` ni para rechazar booleanos inválidos en `ParameterCatalog` (`Boolean.valueOf`): el TEST_PLAN exige decisión previa. Quedan `DECISION_REQUIRED`.
- Protocolo clamd verificado contra el ClamAV real local (puerto 3310): respuesta limpia `stream: OK\0`, comando desconocido `UNKNOWN COMMAND\0`; `ClamAvMalwareScanAdapterIT` (3/3) confirma la detección EICAR `Eicar-Test-Signature FOUND`.
