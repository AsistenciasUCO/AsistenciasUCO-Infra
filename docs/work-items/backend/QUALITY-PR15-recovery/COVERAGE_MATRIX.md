---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---
# QUALITY-PR15 — cobertura histórica y pruebas equivalentes

Fuente: XML JaCoCo auditado del PR #15; NO re-ejecutado en Q0. Sonar new coverage 48.4%, global JaCoCo 82.6%. Distintos denominadores.

| Prioridad | Clase | Líneas sin cubrir | Cobertura histórica | Trabajo |
|---|---|---:|---:|---|
| P1 | MinioFileStorageAdapter | 99 | 0% | unit sdk/errores/limites; IT proveedor |
| P1 | ClamAvMalwareScanAdapter | 47 | 0% | unit respuestas, timeout, stream; IT EICAR |
| P1 | AcademicViewJpaProjectionMapper | 46 | 8% | proyecciones completas/null |
| P2 | EstudianteJpaRepository | 39 | 29.1% | filtros, paginación, vacío |
| P2 | MessageCatalogJpaRepository | 34 | 12.8% | caché, errores, formatos |
| P1 | CoreViewJpaProjectionMapper | 27 | 3.6% | mapeos completos/null |
| P2 | ParameterCatalogJpaRepository | 27 | 12.9% | tipos y valores inválidos |
| P2 | InstitutionalScopeJpaRepository | 22 | 35.3% | allow/deny/errores |

## Equivalencia JDBC→JPA (rellenar desde diff y suites existentes)
| Capacidad | Test antiguo eliminado / SHA | Contrato | Test unit JPA | IT real | Resultado |
|---|---|---|---|---|---|
| Asistencia | INVENTARIAR | query, command, rollback | INVENTARIAR | INVENTARIAR | PENDIENTE |
| Sesión/Grupo | INVENTARIAR | SP, error, tx | INVENTARIAR | INVENTARIAR | PENDIENTE |
| Estudiante | INVENTARIAR | filtros, cardinalidad | INVENTARIAR | INVENTARIAR | PENDIENTE |
| Catálogos | INVENTARIAR | caché, parse, fallback | INVENTARIAR | INVENTARIAR | PENDIENTE |
| Scope | INVENTARIAR | ownership, fail closed | INVENTARIAR | INVENTARIAR | PENDIENTE |

La auditoría previa reportó 41 archivos de test eliminados, 52 añadidos y 54 modificados, incluyendo auxiliares: no son 41 suites equivalentes por definición. Registrar path exacto y comportamiento recuperado, no contar cantidad de tests como prueba de paridad.

## Recalcular por commit
SHA + fecha + run Actions; Maven clean verify, reportes Surefire/JaCoCo XML frescos; LINE covered/missed y BRANCH covered/missed por clase; Sonar new_lines_to_cover, uncovered, new_coverage y ratings sobre mismo SHA. Verificar importación XML y reporte de excludes sin cambiarlos. Separar Failsafe -Pintegration y sus skips. Publicar diff coverage y evidencia de issues, no optimizar contadores cosméticos.

## Ampliación del inventario de cobertura

Nuevas suites candidatas por área, sin porcentaje prometido: `ParameterCatalogJpaBehaviorTest` ↔ ParameterCatalogJpaRepository; `MessageCatalogJpaBehaviorTest` ↔ MessageCatalogJpaRepository; `CoreViewJpaProjectionBehaviorTest` ↔ CoreViewJpaProjectionMapper; `AcademicViewJpaProjectionBehaviorTest` ↔ AcademicViewJpaProjectionMapper; `ArchivoControllerSecurityBoundaryTest` ↔ ArchivoController. Los resultados de cobertura se deberán recalcular desde XML CI del SHA final; las suites nuevas no alteran por sí solas la cobertura global ni Sonar hasta ejecutar y superar los tests.

## Recálculo 2026-10-08 (HEAD `812a313`, `clean verify` local Java 25)
JaCoCo global: LINE 90.25 %, BRANCH 80.22 % (antes, en `c741b66`: 85.05 % / 76.70 %).
Estimación New Code (líneas añadidas en `0b7905c..HEAD`, src/main): 87.6 % (1475/1644 líneas, 357/448 ramas). La cifra oficial es la de Sonar para el mismo SHA (ver VALIDATION).

| Clase (P1/P2 original) | Sonar 4cae0a3 sin cubrir | Pendiente estimado en HEAD | Suites conductuales |
|---|---:|---:|---|
| MinioFileStorageAdapter | 99 | 0 L / 0 B | MinioFileStorageAdapterTest, MinioReadBudgetTest; IT MinioFileStorageAdapterIT |
| ClamAvMalwareScanAdapter | 47 | 0 | ClamAvProtocolBoundaryTest, ClamAvFailClosedBoundaryTest; IT ClamAvMalwareScanAdapterIT |
| AcademicViewJpaProjectionMapper | 46 | 14 L (toAsignatura/toReporte/toMateria vía IT) | ViewEntityProjectionMappingTest, AcademicViewJpaProjection*Test |
| EstudianteJpaRepository | 39 | 0 | EstudianteJpaQueryContractTest; IT EstudianteAcademicFilterJpaParityIT |
| MessageCatalogJpaRepository | 34 | 0 | MessageCatalogJpaBehaviorTest; IT CatalogJpaParityIT |
| CoreViewJpaProjectionMapper | 27 | 0 | CoreViewJpaProjectionBehaviorTest, ViewEntityProjectionMappingTest |
| ParameterCatalogJpaRepository | 27 | 0 | ParameterCatalogJpaBehaviorTest; IT CatalogJpaParityIT |
| InstitutionalScopeJpaRepository | 22 | 0 | InstitutionalScopeJpaBehaviorTest, InstitutionalScopeSingleStatementPatternTest; IT AuthorizationReportJpaParityIT |

Pendientes menores (≤ 6 líneas c/u): repositorios académicos de una sola consulta (Horario*, Coordinador, Decano, PlanEstudio, Materia, Reporte), interactors y wiring de archivos; cubiertos por IT, no por Surefire.

## Equivalencia JDBC→JPA (inventario de los tests eliminados en 4cae0a3)
| Capacidad | Tests JDBC eliminados (4cae0a3) | Contrato | Unit JPA vigente | IT real (SQL Server) | Resultado 2026-10-08 |
|---|---|---|---|---|---|
| Asistencia | AsistenciaRepositorySqlServerAdapterTest, AsistenciaRepositoryHybrid*Test, AsistenciaJpaCommandPersistenceTest, AsistenciaQueryProviderContextIT | query, command SP 4 campos, rollback | AsistenciaJpaQueryPersistenceTest, AsistenciaJpaCommandNativeQueryPatternTest, AsistenciaJpaProjectionMapperTest | AsistenciaQueryJpaParityIT, AsistenciaCommandJpaParityIT, AsistenciaCommandsSpParityIT, AsistenciaCommandTransactionBoundaryIT, PersistenceTransactionParityIT | PASS (IT completa 191/191 ejecutables) |
| Sesión/Grupo | SesionRepositorySqlServerAdapterTest, GrupoRepositorySqlServerAdapterTest | SP, error, tx, proyección | SesionJpaCommandPatternTest, GrupoJpaCommandPatternTest, JpaQueryAdapterContractTest, CoreViewJpaProjectionBehaviorTest | SesionGrupoCommandsSpParityIT, CoreViewQueriesJpaParityIT | PASS; regresión `"null"` corregida (c741b66) |
| Estudiante | EstudianteRepositorySqlServerAdapterTest | filtros, cardinalidad, paginación | EstudianteJpaQueryContractTest | CoreViewQueriesJpaParityIT, EstudianteAcademicFilterJpaParityIT | PASS |
| Docente/Usuario/TipoId | Docente/Usuario/TipoIdentificacionRepositorySqlServerAdapterTest | identidad, optional | JpaQueryAdapterContractTest, UsuarioJpaCommandPatternTest, CoreViewJpaQueryErrorSemanticsTest | CoreViewQueriesJpaParityIT, AcademicUserCommands*ParityIT | PASS (1 skip de datos en DocenteRepositorySqlServerIT) |
| Académico | Asignatura/CierrePeriodo/Coordinador/Decano/Facultad/Horario*/PeriodoAcademico/PlanEstudio/SesionMateriaEstudiante SqlServerAdapterTest | queries de vistas, commands | *JpaCommandPatternTest, ViewEntityProjectionMappingTest, ViewCompositeIdentityTest, JpaQueryAdapterContractTest | AcademicQueryJpaParityIT, AcademicUserCommandsSpParityIT | PASS |
| Catálogos | SqlServerMessageCatalogAdapterTest, SqlServerParameterCatalogAdapterTest, CatalogAdapterConfigurationTest | caché, parse, fallback | MessageCatalogJpaBehaviorTest, ParameterCatalogJpaBehaviorTest | CatalogJpaParityIT | PASS; booleano inválido = `DECISION_REQUIRED` |
| Scope | InstitutionalScopeSqlServerAdapterTest | ownership, fail closed | InstitutionalScopeJpaBehaviorTest, InstitutionalScopeSingleStatementPatternTest | AuthorizationReportJpaParityIT | PASS |
| Reporte | ReporteAsistenciaSqlServerAdapterTest | proyección, UTC | ViewEntityProjectionMappingTest (mapper) | AuthorizationReportJpaParityIT | PASS |
| Auditoría | AuditEventJdbcRepositoryTest | inserción, errores | AuditEventJpaRepositoryTest | AuditHttpIT | PASS |
| Selectores jdbc/jpa y composition root | AsistenciaCommandProvider*Test, AsistenciaQueryProvider*Test, SqlServer*ConfigurationTest, JpaCapabilityRequiredConditionTest, AdapterCompositionRootRulesTest, JpaCommandIsolationRulesTest, FeaturesBeansConfigTest | retirados por ADR-003 (JPA-only, sin selector) | JpaRepositoryArchitectureRulesTest, JpaRepositoryBeanUniquenessTest | — | Retiro intencional; no hay comportamiento que conservar |
