---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# QUALITY-PR15 — Test plan futuro; ningún RED ejecutado en Q0

Derivar cada test del comportamiento/contrato, congelar RED_SNAPSHOT antes de src/main y asignar actor distinto a tester/implementador. Unit mock solo de colaboradores; mocks nunca certifican provider ni SQL Server.

| ID | Escenario | Observable/condición incorrecta detectada | Nivel |
|---|---|---|---|
| S01 | ClamAV CLEAN completo válido | Aceptar cualquier string que termine OK debe fallar | Unit + protocolo |
| S02 | FOUND/EICAR de prueba | Nunca escribir bytes infectados | Unit + ClamAV IT |
| S03 | Respuesta ClamAV vacía/truncada/malformada | Fallar cerrado, no CLEAN silencioso | Unit |
| S04 | Timeout/socket indisponible/cierre stream | Error técnico seguro; no objeto almacenado | Unit + IT |
| F01 | MinIO put/get/delete en dos clientes | Bytes round-trip y referencia durable | Unit + MinIO IT |
| F02 | NoSuchKey/NoSuchObject, metadatos faltantes | Respuesta controlada y sin NPE | Unit |
| F03 | bucket inválido, timeout y error SDK | No confirmar operación fallida | Unit |
| F04 | Objeto remoto mayor al presupuesto | Lectura limitada sin OutOfMemory/bytes parciales | Unit |
| F05 | Archivo comprimido con expansión excesiva | Inflate abortado dentro de límite | Unit |
| F06 | Checksum incorrecto, truncamiento | No entregar contenido corrupto | Unit + IT |
| F07 | Compresión >=10% vs sin ahorro | Solo comprimir si mejora; restaurar bytes | Unit |
| F08 | Dueño, docente ajeno, anónimo | Autorización según contrato sin filtrar existencia | App + HTTP IT |
| F09 | MIME y filename manipulados, descarga inline | Content-Type verificado, cabeceras seguras | HTTP unit/contract |
| J01 | AcademicView mapper proyecciones completas/null | Contrato de columnas, conversiones y flags | Unit |
| J02 | CoreView mapper proyecciones/null | Evitar string literal "null" si contrato exige null | Unit |
| J03 | ParameterCatalog cache hit/miss, tipos y parse inválido | Ningún boolean inválido silencioso sin decisión | Unit + SQL IT |
| J04 | MessageCatalog faltantes/formato/cache | Reglas de catálogo preservadas | Unit + SQL IT |
| J05 | Estudiante filtros 0/N combinados y paginación | Semántica de queries intacta | Unit + SQL IT |
| J06 | InstitutionalScope grant/deny/fallo | Fallar cerrado; no escalada | Unit + SQL IT |
| J07 | Commands/queries migradas comparadas con fixture legacy | Paridad SQL y rollback/correlación | SQL IT |
| G01 | clean verify Java25, JaCoCo XML de ese run | Contadores y skips reales, no stale report | Maven/Surefire |
| G02 | Sonar para nuevo SHA | coverage >=80%, ratings A/A e issues resueltos | Sonar remoto |
| G03 | CodeQL/Dependency Review / Docker | Required checks PASS sin jobs skipped | GitHub |
| L01 | LB-004 futuro estudiante→docente | FileId→revisión SQL, bytes iguales, autorizado | E2E posterior |

TEST_TOO_WEAK si ninguna implementación incorrecta hace fallar el test. No cambiar expected para resolver GREEN. No simular provider con Mockito como prueba de integration. No habilitar docente hasta binding DB aprobado.
RED_SNAPSHOT Q0: NO APLICA — DOCUMENTATION_ONLY. Q2/Q3: NOT_RUN; registrar base commit, paths/hash, comando, exit code y fallo esperado antes de implementación. No es permiso para empezar Q2/Q3.

## Concrete RED candidate files — tester authored, NOT_RUN
| Scenario | Source | Expected on audited production | Required JDK25 assertion |
|---|---|---|---|
| S01 control | src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/malwarescan/clamav/ClamAvProtocolBoundaryTest.java | valid stream: OK NUL → CLEAN | PASS |
| S03 malformed suffix | same | current endsWith("OK") incorrectly returns CLEAN | assertion fails for malformed response |
| S03 missing NUL | same | current EOF treated as valid response | assertion fails for truncated response |
| F05 valid 5 MiB | src/test/java/co/edu/uco/asistenciasuco/application/features/archivo/shared/contentsecurity/CompressionPolicyExpansionBoundaryTest.java | roundtrip full bytes | PASS |
| F05 >5 MiB expand | same | current inflate has no expansion limit | assertThrows fails |
| F04 oversize remote object | src/test/java/co/edu/uco/asistenciasuco/infrastructure/adapter/secondary/storage/minio/MinioReadBudgetTest.java | current transferTo consumes full oversize | bounded-read assertion fails |

Test source authoring is NOT equivalent to certified RED. First run tests with JDK25. If a test fails compilation or environment setup, fix the **test alone as tester**, record the cause and freeze new SHA; do not ask implementer to edit RED or claim it was a behavioral RED. Freeze the compiled, causal RED commit/hash only after assertions demonstrate the expected defect. All *IT remain separate. The 5MiB threshold is a baseline content limit; if DB or storage contract indicates a different allowed expansion representation, record CONTRACT_CONFLICT rather than weakening the test silently.

## Q2/Q3 — paquete ampliado de tests de comportamiento (2026-10-08)

Además de los 3 candidatos de seguridad/storage de la iteración previa se incorporan **5 suites / 29 métodos**:
- ParameterCatalogJpaBehaviorTest: claves nulas/blancas sin DB, normalización y cache hit, miss no cacheado, requerido ausente, conversiones tipadas, boolean válido, entero inválido, tipo no soportado, excepción preservada.
- MessageCatalogJpaBehaviorTest: código inválido, cache positivo, miss reconsultado, formatos y args, canales técnico/usuario separados, error del proveedor preservado.
- CoreViewJpaProjectionBehaviorTest: sesión con código y UTC; null del código como ausencia real versus cadena literal; flags de grupo.
- AcademicViewJpaProjectionBehaviorTest: hora académica local, hora ausente, periodo y fechas, institución flag nullable, plan estudio habilitado con int=1.
- ArchivoControllerSecurityBoundaryTest: identidad ausente, fileId inválido, filename hostil sin CRLF/cabecera inyectada.

Son pruebas a nivel unitario y contract del adaptador, NO pruebas de SQL Server real ni JWT filter chain. JPA smoke/parity IT existentes (`CatalogJpaParityIT`, `AcademicQueryJpaParityIT`, `AuthorizationReportJpaParityIT`) se mantienen; verificarlos posteriormente con `-Pintegration`. Los casos de nulabilidad de CoreView proponen paridad con `JdbcBaselineValueMapper.toString(null)=null` y pueden revelar bug real; NO cambiar contrato a `"null"` para verde.

**Ejecución de validación obligatoria previa a implementación:** Java25, `./mvnw -B -ntp "-Dtest=ParameterCatalogJpaBehaviorTest,MessageCatalogJpaBehaviorTest,CoreViewJpaProjectionBehaviorTest,AcademicViewJpaProjectionBehaviorTest,ArchivoControllerSecurityBoundaryTest" test`. Primero resolver solo defectos de compilación/fixture por el rol tester y registrar hash; demostrar fallos RED causales y controles positivos; después congelar snapshot. Separar de los 3 candidatos anteriores (ClamAvProtocolBoundaryTest, CompressionPolicyExpansionBoundaryTest, MinioReadBudgetTest), igualmente no certificados. Los mocks de clase JPA son solo test de mapeo; no certificar SQL real. Revisar y aprobar decisiones de manejo boolean inválido y nosniff antes de crear RED nuevos.
