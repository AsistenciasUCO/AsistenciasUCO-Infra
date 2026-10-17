---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---

# SEC-002 — parches de dependencias runtime en Spring Boot 4.0.x

## Motivo y contrato de alcance

Origen: PR #16 Trivy Deep Security Scan [run 37869776047](https://github.com/alejovh12/AsistenciasUCO/actions/runs/37869776047), SHA `275d828fcca735feba20686f9a950e89cf74d362`. Trivy repository y image ambos COMPLETARON y sus reportes SARIF están en artifacts `11588914959` y `11590120454`. El workflow usa `exit-code:0` para inventario; PASSED no equivale a CVE=0. Baseline imagen: 125 registros (10 CRITICAL, 49 HIGH, 60 MEDIUM, 6 LOW), 104 ruleIds distintos; algunos CVE en varios componentes. POM Maven propio: Spring Boot parent `4.0.6`.

Esta microfase propone **parches mínimos** en `pom.xml`, SIN cambiar código Java, SQL, Angular, Dockerfile, OpenAPI ni contratos. No se afirma ausencia de CVE hasta inspeccionar imagen nueva generada con el POM modificado y validar Java25, ArchUnit, JaCoCo, CodeQL/Dependency Review, MinIO/SQL/ClamAV IT si aplican.

## Baseline CRITICAL imagen (identificadores observados en SARIF)

| Componente instalado | CVE críticos | Versión corregida observada en scan |
|---|---|---|
| `org.apache.tomcat.embed:tomcat-embed-core:11.0.21` | CVE-2026-41293, -43512, -43515, -65182, -65905, -68525 | Tomcat 11.0.25+ |
| `org.springframework:spring-webmvc:7.0.7` | CVE-2026-47884, -47890 | Spring Framework 7.0.9+ |
| `io.netty:netty-handler:4.2.12.Final` | CVE-2026-75595 | Netty 4.2.17.Final+ |
| `org.bouncycastle:bcprov-jdk18on:1.84` | CVE-2026-8763 | BC 1.85+ |

**Registros detectados no implican explotación**; evaluar reachability y advisories proveedor para cada CVE.

## Cambio 1 permitido: BOM y contenedor (este PR)

- `spring-boot-starter-parent 4.0.6 → 4.0.8`: release estable agosto 2026, preserva rama minor y compatibilidad Java25. Dependency appendix de Boot 4.0.8 administra Framework `7.0.9` y Netty `4.2.17.Final`.
- `tomcat.version 11.0.26`: el BOM Boot 4.0.8 administra `11.0.24`, debajo de fixed `11.0.25`. Override único de la **familia** Tomcat (no cada módulo) hasta próxima publicación de BOM que lo incluya. Tomcat 11.0.26 publicó en septiembre 2026.
- No cambiar `jackson-*`, `bcprov` ni librerías transitivas arbitrariamente en este lote; pendientes explicitados abajo.

## Plan de validación / DoR

DoR: APPROVED_SCOPE_POM_ONLY por solicitud de corrección de vulnerabilidades, release documentadas. Tests existentes son la regresión de comportamiento; este lote no introduce funcionalidad ni requiere nuevos RED unit. **NO validado aún con Maven** desde la herramienta que escribió este POM, cuyo entorno sólo tiene JDK21; Java25 se certificará en GitHub Actions.

1. Ejecutar `./mvnw -B -ntp clean verify` con JDK25 (Surefire + ArchUnit + JaCoCo LINE >=80%, BRANCH >=70%, OpenAPI).
2. Ejecutar `./mvnw -B -ntp dependency:tree` y guardar versiones efectivas del runtime: Spring Framework, Tomcat, Netty, Jackson, BouncyCastle.
3. Ejecutar `./mvnw -B -ntp clean verify -Pintegration` con SQL Server/MinIO/ClamAV si ambiente disponible; no convertir skip en PASS.
4. Construir `docker build` del SHA y rescaneo Trivy filesystem/image; comparar CVE y fixedVersion, separar OS y Java; no usar el reporte del PR16 como post-fix.
5. Aprobar merge sólo si checks remotos verdes, diff de dependencyTree esperado y sin regresiones; PR no se fusiona automáticamente.

## Pendientes explícitos posteriores

- `org.bouncycastle:bcprov-jdk18on 1.84`: salto a 1.85+ requiere verificar `dependency:tree`, quién la incluye (MinIO/SDK/otros), compatibilidad e integración TLS/certificados. **CVE-2026-8763 NO cerrado por este PR**.
- Jackson 2.x/3.x: existen varios HIGH con fixed versions diversas; evitar override por módulo que cree classpath mixto, estudiar BOM alineados o Boot update adicional.
- Tomcat/Netty/Spring: comprobar en Trivy nuevos CVEs o false positives; no inferir remediación completa desde POM.
- P1/P2 mantenibilidad pertenece a MAINT-001, en PR separado para no mezclar refactor con actualización de dependencias.

## Adenda correctiva — CVE restantes después del primer parche (HEAD 6d2d4b3)

Se inspeccionaron SARIF de [run 37872449097](https://github.com/alejovh12/AsistenciasUCO/actions/runs/37872449097) (Docker image artifact 11589969593, filesystem artifact 11591205030). Comparado con imagen previa: **125 → 24 registros**; **CRITICAL 10 → 1**; HIGH **49 → 12**; MEDIUM 11. Conteos de hallazgos en imagen (no explotabilidad). Nuevo baseline detectado:
- `org.bouncycastle:bcprov-jdk18on:1.84`: CVE-2026-8763 CRITICAL y CVE-2026-13506 HIGH (fixed 1.85). Usar un solo BOM `org.bouncycastle:bc-jdk18on-bom:1.85.2`.
- Jackson 2.x `2.21.5`: 5 HIGH, 2 MEDIUM en jackson-core/databind; fix `2.21.7`.
- Jackson 3.x `3.1.5`: 5 HIGH, 2 MEDIUM; fix `3.1.7`.
- `mssql-jdbc:13.2.1` (sin sufijo): CVE-2025-59250 HIGH en escáner, fixed `13.2.1.jre11` según SARIF; comprobar equivalencia de versión y advisory antes de cualquier override.
- `OpenTelemetry:1.55.0` MEDIUM (dos paquetes), `commons-compress:1.25.0` MEDIUM (dos CVE), `poi-ooxml:5.2.5` MEDIUM; pendientes en siguiente lote con origen transitivo/versión validada.
- Imagen Alpine: `libpng 1.6.58-r1` MEDIUM, `zlib 1.3.2-r0` MEDIUM; requieren parche de image base o paquetes, con nuevo Docker build.
- Trivy FS misconfig `DS-0002` HIGH: Dockerfile en stage final sin USER. Se añade `USER 10001:10001` tras COPY; no cambiar usuario del stage build. `DS-0026` LOW HEALTHCHECK pendiente de decisión (Kubernetes/Compose también puede definir healthcheck).

### Implementación del segundo lote
- Properties de Spring Boot parent: `jackson-2-bom.version=2.21.7`, `jackson-bom.version=3.1.7`. Actualiza las familias completas y evita versionado individual de módulos.
- Import de `org.bouncycastle:bc-jdk18on-bom:1.85.2` bajo dependencyManagement del módulo, sin nueva dependencia runtime directa.
- `USER 10001:10001` en imagen productiva, con UID/GID numéricos estables. No prometer compatibilidad con escrituras en `/app` hasta validar que la aplicación no intenta persistir allí.
- No se cambia código Java, esquema DB, frontend, rutas HTTP ni umbrales de Trivy.

### Gates exigidos
Maven JDK25 clean verify, ArchUnit, CI Sonar, Security y **nuevo Trivy image/fs** del SHA publicado. Revisar que efectivamente aparecen Jackson `2.21.7/3.1.7` y Bouncy Castle `1.85.2` en dependency:tree y Trivy. Comprobar `docker inspect --format='{{.Config.User}}'` y startup con UID sin privilegios. Las pruebas integradas SQL/MinIO/ClamAV quedan pendientes hasta ambiente real. No declarar DONE hasta nuevo escaneo y prueba de arranque.

## Tercer lote — remediación de hallazgos restantes después de Bouncy Castle/Jackson

Baseline **SHA f9a08f4** / [scan 37873166385](https://github.com/alejovh12/AsistenciasUCO/actions/runs/37873166385) (image SARIF artifact 11591685128, filesystem SARIF artifact 11591106912):
- **Imagen: 8 resultados**, CRITICAL 0, HIGH 1, MEDIUM 7. No tratar `exit-code:0` como ausencia CVE.
- `mssql-jdbc-13.2.1.jre11.jar`: `CVE-2025-59250` HIGH. Trivy identifica metadata como `13.2.1` y lista `13.2.1.jre11` entre versiones corregidas. **POTENTIAL_FALSE_POSITIVE / REQUIRES_ADVISORY_REVIEW** (no ignorado). Existe reporte upstream de ese mismo caso en https://github.com/aquasecurity/trivy/discussions/9745 . Confirmar paquete efectivo/artefacto Maven y advisory Microsoft antes de suppression o version bump; sin falsificar reportes.
- `org.apache.poi:poi-ooxml 5.2.5`: `CVE-2025-31672` MEDIUM; parser ZIP OOXML puede aceptar entradas duplicadas. Vendor Apache indica fix >=5.4.0. Propuesto `5.4.1` ([POM original](https://central.sonatype.com/artifact/org.apache.poi/poi-ooxml/5.4.1)).
- `org.apache.commons:commons-compress 1.25.0`: `CVE-2024-25710` y `CVE-2024-26308` MEDIUM; fixed >=1.26.0; override único en dependencyManagement `1.28.0` (versión estable Apache), preservando compatibilidad con POI.
- `libpng 1.6.58-r1`: `CVE-2026-46675` MEDIUM, fixed `1.6.59-r0`; `zlib 1.3.2-r0`: `CVE-2026-85091` MEDIUM, fixed `1.3.2-r1`. Se ejecuta `apk upgrade --no-cache libpng zlib` solo en stage runtime antes del USER. Si mirror Alpine no tiene versión fixed, el build debe bloquear y registrarse.
- `OpenTelemetry 1.55.0`: `CVE-2026-45292` MEDIUM en `api` y `extension-trace-propagators`; fixed `1.62.0`, **no actualizado en este lote** porque Boot 4.0.8 gestiona toda la familia 1.55.0 y el exporter/tracing puede sufrir incompatibilidad. Próximo lote específico con `opentelemetry.version` y pruebas de propagación/observabilidad.
- Filesystem SARIF: 7 resultados, incluyendo `DS-0026` LOW por `HEALTHCHECK` ausente en dos Dockerfiles. DECISION_REQUIRED: Compose/orchestrator puede definir probes; no añadir un `HEALTHCHECK` inconsistente con rutas de autorización o sin revisar los consumers.

### Validación de este lote

- Se cambia `pom.xml` (POI/Commons Compress), `Dockerfile` runtime (apk) y `security-deep-scan.yml` para **afirmar USER no-root en la imagen realmente construida**.
- Red Java: NO APLICA para actualización de dependencias; pruebas de regresión existentes + ArchUnit/OpenAPI/Sonar y Docker build real en CI. Pruebas OOXML malicioso de entradas ZIP duplicadas pueden ser añadidas en microfase si existe consumo de OOXML externo, previa validación de threat model.
- No se modifica API, JWT, autorización, acceso SQL Server, eventos ni contrato DB. `mvn dependency:tree` debe mostrar POI `5.4.1`, Commons Compress `1.28.0`; imagen reconstruida debe mostrar versiones `libpng`/`zlib` corregidas; si no aparecen, BLOCKED y no marcar CVE closed.
- Estado actual del tercer lote al escribir: `PROPOSED, NOT_TESTED`. Nuevo GitHub Actions run/SARIF deben documentarse en VALIDATION; no hacer merge hasta revisar.


## Fourth remediation batch — OpenTelemetry baggage propagation

Baseline: PR #17 HEAD `26a6301b72d3300635e001ae84760034360c91d9`, Trivy [run 37873876538](https://github.com/alejovh12/AsistenciasUCO/actions/runs/37873876538), image artifact `11591871596`, filesystem artifact `11591866278`. Image has **3 findings**: 0 CRITICAL, 1 HIGH (CVE-2025-59250 MSSQL JDBC), 2 MEDIUM (same CVE-2026-45292 for OTel API and trace propagators). Filesystem additionally reports 2 LOW Dockerfile HEALTHCHECK warnings. Reports were read from SARIF, not inferred from job status.

### Risk and targeted change

CVE-2026-45292 / GHSA-rcgg-9c38-7xpx is an unbounded baggage propagation resource-allocation issue. Affected `io.opentelemetry:opentelemetry-api` and `opentelemetry-extension-trace-propagators` through 1.61.0; patch is 1.62.0. Upstream introduced a 64-entry cap and 8192-byte limit. Ref: https://github.com/advisories/GHSA-rcgg-9c38-7xpx .

Spring Boot 4.0.8 exposes `opentelemetry.version` as a managed override property (https://docs.spring.io/spring-boot/4.0/appendix/dependency-versions/properties.html). Set to `1.62.0` to align the **whole core OTel family**, rather than fixing `api` alone. Upstream release https://github.com/open-telemetry/opentelemetry-java/releases/tag/v1.62.0 .

Behavioral regression suite `OtelBaggagePropagationBoundaryTest`: (1) valid baggage retains 3 fields, (2) 90 entries truncated to 64, (3) >8192-byte baggage ignored. It tests library behavior directly, not a simulated external tracer or E2E. Existing `CorrelationIdFilterTest`, architecture suites and observability tests remain mandatory. Original 1.55.0 behavior would fail the excessive-entry regression. Do not change the assertion to meet an incompatible package; investigate BOM convergence first.

Compatibility risk: OpenTelemetry exporter/autoconfiguration may have binary API evolution. Mandatory Java25 `clean verify`, Boot startup, trace-header propagation + SSE reconnection smoke, Docker build and new Trivy FS/image SARIF from same SHA. Do **not** declare CVE fixed without all new effective runtime components at >=1.62.0 and a completed scan.

**MSSQL JDBC HIGH is not hidden or ignored.** Trivy identifies `mssql-jdbc-13.2.1.jre11.jar` but reports installed Maven version `13.2.1` and fixed `13.2.1.jre11`. This discrepancy is under investigation: https://github.com/aquasecurity/trivy/discussions/9745 ; collect vendor advisory, effective dependency and embedded jar metadata before considering suppression, upgrade or compensating control. No `.trivyignore` without approved exception.

## SEC-002 Cierre de clasificación — CVE-2025-59250 (último SARIF del SHA 2c60cd5)

- Escaneo: [run 37896672082](https://github.com/alejovh12/AsistenciasUCO/actions/runs/37896672082), artefactos `11600089829` (imagen), `11599999561` (repositorio). Imagen: **1 HIGH CVE-2025-59250**, sin CRITICAL/MEDIUM. Repo: dos LOW `DS-0026` (HEALTHCHECK) para `Dockerfile` y `infra/files/minio/Dockerfile`.
- Hallazgo: Trivy muestra `Installed Version: 13.2.1`, pero la ruta real del archivo de imagen es `BOOT-INF/lib/mssql-jdbc-13.2.1.jre11.jar`; el propio resultado lista `13.2.1.jre11` en fixed versions.
- **Vendor de autoridad:** Microsoft release notes de JDBC driver [13.2.1 (13/10/2025)](https://learn.microsoft.com/en-us/sql/connect/jdbc/release-notes-for-the-jdbc-driver) explicitan el fix para CVE-2025-59250. Paquete Maven firmado/publicado en https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/13.2.1.jre11/ . Se reproduce la discrepancia en [Trivy discussion #9745](https://github.com/aquasecurity/trivy/discussions/9745).
- **Decisión de revisión**: `LIKELY_SCANNER_FALSE_POSITIVE / VENDOR_FIXED_ARTIFACT` sobre **ese artefacto específico**, condicionada a atestación de imagen; no significa que cualquier `13.2.1` genérico sea seguro, ni reemplaza el test SQL Server. No se añade `.trivyignore` ni se alteran severidades. Si cambia la familia/versión del driver, repetir triage y actualizar el guardia con aprobación del equipo.
- Control añadido: `scripts/security/verify_jdbc_artifact.py` inspecciona el JAR construido dentro de Docker y comprueba exactamente un `mssql-jdbc-13.2.1.jre11.jar` más Maven groupId/artifactId/version, evitando downgrade o classpath mixto. `test_verify_jdbc_artifact.py` cubre siete escenarios positivos/negativos. La prueba **no** certifica bytes contra checksum publicado ni explotabilidad, y no silencia el SARIF. Se debe conservar el HIGH reportado y agregar la decisión justificada al expediente.
- HEALTHCHECK: MinIO ya posee prueba de salud en `infra/files/compose.yaml` mediante Compose, por lo que meter un probe duplicado en su Dockerfile no es estrictamente necesario. Backend `docker-compose.yml` no define healthcheck: evaluar exposición de `/actuator/health`, comandos disponibles en imagen JRE, arranque y dependencia DB en nueva microfase; `DECISION_REQUIRED`. Nunca agregar `wget/curl` sin test de contenedor funcional.
- Próxima fase independiente tras SEC-002: `MAINT-001`, excepciones JPA/cache/paginación; no refactorizar en este PR de dependencias. 
