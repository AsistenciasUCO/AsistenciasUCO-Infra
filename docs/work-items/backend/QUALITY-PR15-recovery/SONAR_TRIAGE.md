---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# QUALITY-PR15 — issues Sonar y security hardening

Fuente: https://sonarcloud.io/dashboard?id=alejovh12_AsistenciasUCO&pullRequest=15
HISTÓRICO (SHA 4cae0a3): New Code Coverage 48.4% (mínimo 80%), Security C (requerido A), Reliability C (requerido A). Las claves/issues se recuperaron posteriormente en Q1 (tabla de esta página). No usar esta primera cifra como estado actual.

## Procedimiento Q1
1. Filtrar issues abiertos de New Code en el PR y confirmar SHA, Bug, Vulnerability y Security Hotspot (proceso separado).
2. Guardar issue key, rule key, type/severity, path, line, mensaje, flujo de datos, causa reproducible y referencia a código.
3. Separar issue Sonar real de riesgo de code review. Si UI/API no devuelve detalle, registrar permisos/error como BLOCKED_BY_MISSING_EVIDENCE; no inventar.
4. Asociar RED, fix SHA, GREEN e issue resultante del siguiente análisis. No declarar C→A hasta nuevo Sonar PASS.
5. No cambiar exclusions/quality profiles, desactivar reglas/tests, bajar umbral ni marcar false positives sin evaluación legítima.

| Issue key | Regla | Tipo | File:line | Test RED | Fix | Verificación |
|---|---|---|---|---|---|---|
| (ver tabla Q1 abajo) | — | — | — | — | — | — |

## Riesgos a investigar (NO Sonar issues confirmados)
- ClamAvMalwareScanAdapter: endsWith("OK") puede aceptar respuesta inesperada; validar protocolo exacto y fail closed.
- MinioFileStorageAdapter: transferTo(buffer) sin límite explícito al leer objeto; validar máximo real.
- CompressionPolicy.inflate: falta de límite de expansión; probar zip bomb sintético seguro.
- ArchivoController: Content-Disposition inline, cabeceras nosniff, nombre, content-type verificado.
- IT con valores dev por defecto: verificar si Sonar reporta secretos, sin imprimirlos.
- CoreViewJpaProjectionMapper String.valueOf(null) puede formar "null".
- ParameterCatalogJpaRepository Boolean.valueOf texto inválido transforma en false sin fallo: confirmar contrato.

## Security test candidates are not Sonar issue evidence
Three code-level RED candidate suites are prepared for protocol validation, decompression limits and MinIO bounded reads. No Sonar rule key has yet been retrieved or linked; classification remains NOT_RETRIEVED. Q1 triage is still required independently of these tests. Do not claim ratings improved without post-push report.

## Q1 — issues exactos recuperados (2026-10-08)
Fuente: API pública SonarCloud `api/issues/search?componentKeys=alejovh12_AsistenciasUCO&pullRequest=15&resolved=false` y `api/hotspots/search`, análisis del PR sobre `4cae0a3`. Total issues abiertos del PR: 185 (mayoría CODE_SMELL de mantenibilidad, rating A). Security/Reliability: 10 issues. Hotspots: 0.
Medidas de ese análisis: new_coverage 48.39 %, new_lines_to_cover 1604, new_uncovered_lines 816, new_security_rating 3.0 (C), new_reliability_rating 3.0 (C), new_maintainability_rating 1.0 (A).

| Issue key | Regla | Tipo / impacto | File:line | Causa verificada | Test RED (de714e8) | Fix |
|---|---|---|---|---|---|---|
| AaEaHMGDE62pkux_HRML | java:S2077 | VULNERABILITY / SECURITY:MEDIUM | EstudianteJpaRepository.java:62 | JPQL de conteo concatenado con un `where` construido en tiempo de ejecución; los valores sí se enlazaban (no había inyección explotable), pero el texto de la consulta variaba con la entrada | EstudianteJpaQueryContractTest.el_texto_jpql_no_depende_de_los_filtros_recibidos | c741b66: JPQL constante con predicados nulos-neutros; todos los filtros como parámetros |
| AaEaHMGDE62pkux_HRMM | java:S2077 | VULNERABILITY / SECURITY:MEDIUM | EstudianteJpaRepository.java:67 | Igual, consulta paginada | idem | c741b66 |
| AaEaHMBaE62pkux_HRL0 | java:S6218 | BUG / RELIABILITY:MEDIUM | DescargarArchivoResultado.java:3 | record con `byte[]`: equals/hashCode/toString por identidad | ByteArrayRecordValueSemanticsTest | df21fa4: equals/hashCode por contenido; toString sin payload (longitud) |
| AaEaHMBIE62pkux_HRLy | java:S6218 | BUG | DescargarArchivoResultadoEntity.java:7 | idem | idem | df21fa4 |
| AaEaHMA-E62pkux_HRLx | java:S6218 | BUG | CompressionDecision.java:6 | idem | idem | df21fa4 |
| AaEaHMAoE62pkux_HRLv | java:S6218 | BUG | SubirArchivoDTO.java:9 | idem | idem | df21fa4 |
| AaEaHL7XE62pkux_HRLu | java:S6218 | BUG | SubirArchivoDomain.java:5 | idem | idem | df21fa4 |
| AaEaHMCkE62pkux_HRL1 | java:S6218 | BUG | FileStoragePort.java:37 (StoreObjectCommand) | idem | idem | df21fa4 |
| AaEaHMCkE62pkux_HRL2 | java:S6218 | BUG | FileStoragePort.java:40 (StoredObject) | idem | idem | df21fa4 |
| AaEaHMLVE62pkux_HRMb | java:S8786 | CODE_SMELL / RELIABILITY:MEDIUM | ClamAvMalwareScanAdapter.java:32 | regex `stream:s*(.+)s+FOUND` con backtracking super-lineal; además aceptaba firma vacía y respuestas de tamaño arbitrario | ClamAvFailClosedBoundaryTest (firma vacía, respuesta 64 KiB) | df21fa4: parser exacto sin regex, respuesta ≤ 1 KiB terminada en NUL |

Riesgos de la auditoría previa (no eran issues Sonar) también corregidos con RED propio: ClamAV `endsWith("OK")` y EOF sin NUL (ClamAvProtocolBoundaryTest), lectura MinIO sin presupuesto (MinioReadBudgetTest), inflate sin límite (CompressionPolicyExpansionBoundaryTest), `"null"` literal en CoreView (CoreViewJpaProjectionBehaviorTest), NPE de ownership en descarga (DescargarArchivoFailClosedTest).
Siguen `DECISION_REQUIRED` (sin cambio): `X-Content-Type-Options: nosniff` en descarga y booleano inválido en ParameterCatalog (`Boolean.valueOf` ⇒ false, igual que el baseline).
Ninguna regla, exclusión, quality profile ni umbral fue modificado; ningún issue se marcó como falso positivo.

## Análisis Sonar del HEAD `812a313` (PR #15, 2026-10-08)
Quality Gate: ERROR solo por Reliability. new_coverage **87.47 %** (1690 líneas / 496 condiciones; 174 líneas y 100 condiciones sin cubrir) ✅; Security **A** (0 issues SECURITY) ✅; Maintainability A; duplicación 1.6 %; hotspots revisados 100 %. Los 10 issues Q1 quedaron cerrados por el análisis. Reliability **E** por 2 issues nuevos introducidos en este lote:

| Issue key | Regla | File:line | Causa | Fix |
|---|---|---|---|---|
| AaEadmQLnVWcy-F4pE3k | java:S2095 | CompressionPolicy.java:74 | `Inflater` liberado con `end()` en `finally`; en Java 25 es `AutoCloseable` y la regla exige try-with-resources | try-with-resources (sin cambio de comportamiento; GREEN de CompressionPolicy*/DescargarArchivo* intacto) |
| AaEadnGtnVWcy-F4pE30 | java:S5863 | ViewCompositeIdentityTest.java:39 (test propio, no RED congelado) | `assertEquals(key, key)` para reflexividad | `assertTrue(key.equals(key))` |

## Auditoría externa de salida (HEAD 2554312, 2026-10-08)
GitHub confirmó Sonar Quality Gate PASSED (new coverage 87,5 %, duplicación 1,6 %, 0 security hotspots, 0 accepted issues). El comentario del bot también reporta **206 New issues**: esto **no** significa 206 vulnerabilidades. FALTA inventario por tipo/regla/severidad del nuevo SHA para priorizar deuda de maintainability y confirmar distribución, sin inferir que 0 accepted=0 issues. Ver [INDEPENDENT_REVIEW](INDEPENDENT_REVIEW_2026-10-08.md). Los 10 issues de seguridad/fiabilidad originales y los 2 de fiabilidad reintroducidos quedan descritos históricamente arriba con sus fixes; no borrar esa trazabilidad.
