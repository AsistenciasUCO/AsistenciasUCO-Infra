---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-10-08
---

# PR #15 — Auditoría independiente de lectura (2026-10-08)

## Contexto y alcance real

- Repo `alejovh12/AsistenciasUCO`, rama `jose-valencia/lb-004-stateless-serverless-readiness`, base `develop`.
- HEAD **revisado**: `255431254632975cac059bbef40bbcc48fc73b28`; PR abierto, mergeable, no fusionado (consulta GitHub del 2026-10-08). No presuponer ese HEAD en auditorías posteriores.
- Comparación desde los RED candidatos de `31dbddd`: 9 commits, 31 archivos afectados; cambios de producción en validación de archivos/compresión, JPA consultas y mappers, records con `byte[]`. También nuevos tests y reportes.
- Auditoría ejecutada por otra herramienta distinta del implementador anterior, **estática y remota**: inspección de archivos fuente, tests/documentos y API GitHub Actions. No compila ni vuelve a ejecutar Java 25, Maven, SQL Server, MinIO/ClamAV o Angular. No equivale a pentest independiente.
- Fuentes: [VALIDATION](VALIDATION.md), [RED_SNAPSHOT](RED_SNAPSHOT.md), [SONAR_TRIAGE](SONAR_TRIAGE.md), [COVERAGE_MATRIX](COVERAGE_MATRIX.md), docs normativas y fuentes actuales de DB en `johnjduque/gestion-asistencia-db` branch `develop` SHA `f2871a9564d6c4cc5abc3745854414243bfda238` (no se modificó).
- Dictamen: **PR_READY_FOR_HUMAN_REVIEW_WITH_RESIDUAL_ACTIONS**. Quality Gate verde, no `LB-004 DONE`; el merge necesita aprobación humana y criterio explícito para el skip de integración.

## CI remoto constatado en HEAD revisado

| Evidencia | Estado |
|---|---|
| Backend CI run 37746517241, job 113209173695 | SUCCESS: Java 25, Maven clean verify, JaCoCo, SonarCloud, JAR, Docker image |
| Backend Security run 37746517267, jobs 113209173650 / 113209173909 | SUCCESS: CodeQL Java Analysis y Dependency Review |
| Comentario Sonar del PR actualizado 2026-10-08T07:59:27Z | Quality Gate PASSED, new coverage 87,5 %, duplicación nueva 1,6 %, hotspots 0 y 0 accepted issues |
| Comentario Sonar: 206 New issues | **Requiere triage de tipos/severidad**; no atribuirlos automáticamente a security/bugs ni afirmar deuda cero |
| VALIDATION local del implementador | 1443 unit tests, 0 fallos; JaCoCo LINE ~90,24 %, BRANCH 80,22 % |
| VALIDATION integración del implementador | 191 IT; 0 failures, 0 errors, **1 skipped** (`DocenteRepositorySqlServerIT`: fixture de docente con múltiples asignaciones ausente) |
| E2E Angular estudiante→reclamo→docente | **NOT_RUN/NOT_READY**, relación durable DB aún inexistente |

Nota: Sonar del SHA `ab3e9fa` registró Security A, Reliability A, Maintainability A y los checks verdes; el HEAD actual agrega solo documentos según revisión de los dos commits siguientes. El Quality Gate actual está PASSED, pero hay que reevaluar el SHA después de nuevos pushes.

## Revisión de diseño, errores y seguridad

| ID | Severidad/prioridad | Evidencia estática | Acción propuesta / gate |
|---|---|---|---|
| AUD-01 | P1 de certificación | `DocenteRepositorySqlServerIT` omitido por fixture | Crear dataset mínimo reproducible y ejecutar la prueba realmente; si se acepta la excepción antes del merge, documentar alcance exacto y responsable. NO afirmar que todo IT ejecutó |
| AUD-02 | P1 de revisión | Sonar bot lista 206 New issues con Quality Gate PASSED | Exportar issues por tipo/regla/severidad; agrupar deuda de maintainability; comprobar ausencia de vulnerabilidades/bugs bloqueantes con reporte actual, no con conteo total |
| AUD-03 | P2 código: semántica de excepciones | `JpaQueryExecutor.execute` captura `PersistenceException | IllegalStateException | IllegalArgumentException | ArithmeticException` de todo el `Supplier`, incluyendo mapping/paginación | Distinguir fallo técnico JPA del fallo de programación/validación. Añadir tests de mapeador defectuoso y de persistencia y confirmar traducción/causa antes de reducir catches. **No cambiar** sin microfase READY |
| AUD-04 | P2 código: mutabilidad | Records con `byte[]` tienen `equals/hashCode` por contenido, pero constructor/accessors exponen arreglo mutable | Decidir si el contrato exige value-object inmutable: defensive copies o alternativa streaming. Verificar memoria (5 MiB) y compatibilidad antes de migrar; no bloquear el PR solo por observación |
| AUD-05 | P2 seguridad HTTP | `ArchivoController.descargarArchivo` responde `Content-Disposition: inline`; sanea CR/LF/comillas, pero `nosniff` sigue `DECISION_REQUIRED` | Registrar decisión con security/consumers antes de modificar cabeceras; probar documentos PDF e imágenes y evitar interpretación activa en browser |
| AUD-06 | P2 data validation | `ParameterCatalogJpaRepository` interpreta booleano no reconocido como `false` según baseline (ver SONAR_TRIAGE) | Política explícita del catálogo: valor inválido = rechazo o valor por defecto; contrato/RED antes de cambio |
| AUD-07 | P2 persistencia/operación | `EstudianteJpaRepository` usa HQL parametrizado constante, con `page * size` en int y predicados opcionales null | Evaluar overflow/paginación y plan de índices/performance con límites del contrato y fixture masiva. No inferir bug actual por inspección |
| AUD-08 | P2 defensa de storage | `MinioFileStorageAdapter.read` valida `stat.size <=5MiB` y comprueba tamaño del stream; metadata parsing inesperada se traduce a error técnico | Mantener pruebas tamper/corrupt, validación de metadata y ownership; evitar reportar provider sin su IT real |
| AUD-09 | Positivo | `ClamAvMalwareScanAdapter` exige NUL, respuesta exacta CLEAN, FOUND con firma y presupuesto 1024 bytes; IOException se envuelve en MalwareScanException | Buena separación de capas, fail-closed; monitorizar firma actualizada y reinicios en pruebas operacionales |
| AUD-10 | Positivo | `CompressionPolicy` acota inflate a 5MiB, usa `Inflater` con try-with-resources; `CoreViewJpaProjectionMapper` respeta null vs `"null"` | Mantener test RED congelado y regression suites; no duplicar transformaciones temporales |
| AUD-11 | Límite funcional | `DescargarArchivoUseCaseImpl` compara metadata de owner antes de retornar bytes; no existe consulta DB `fileId→revisión→sesión→grupo→docente` | Docente DENY_BY_DEFAULT correcto, no habilitar rol por atajo de controller; fase DB primero |

### Excepciones y trazabilidad

Ruta HTTP: errores de validación/negocio a `ApplicationException` → `GlobalExceptionHandler` y códigos HTTP desde catálogo; fallos genéricos a error 5xx controlado sin payload técnico al consumidor. En descarga: objeto faltante → `ObjectNotFoundException` → `ResourceNotFoundException`; metadata no correspondiente → 404 sin revelar existencia; checksum/compresión corruptos → error técnico fail-closed. En subida: ClamAV no disponible → `MalwareScanException` → `InternalApplicationException`. El adaptador MinIO traduce errores del SDK a puertos neutrales. `DbExceptionTranslator` conserva clasificación funcional del resultado SP por DBCODE y correlación, con saneamiento de mensajes de log.

**Riesgo residual no demostrado:** el capturador amplio de `JpaQueryExecutor` puede etiquetar como error DB una excepción `IllegalArgumentException`/aritmética originada en la proyección (ejemplo: mapper). Diseñar test negativo antes de cambiar. No se evidencia una vulnerabilidad explotable por esta observación.

### Arquitectura y clean code

- Se mantiene separación `Application secondary ports → Infrastructure adapters`, sin SDK MinIO/ClamAV en Application; JPA reside en Infrastructure.
- JPA query de estudiante ahora usa cadena HQL fija y parámetros enlazados, eliminando variación por filtro y reduciendo alerta Sonar S2077.
- Se corrigieron equals/hashCode de `byte[]`, sin registrar bytes en `toString`. Consistencia de valor y mutabilidad son propiedades distintas.
- Revisión estática no certifica complejidad/carga ni consumo de memoria bajo concurrencia: ejecutar smoke real y revisar telemetry cuando se retome LB-004.

## Checklist del reviewer para merge

1. Confirmar último SHA del PR y nuevo run: **todos required checks PASS para ese SHA**, sin conflictos; no reproducir ratios viejos.
2. Triage de los 206 issues Sonar de código nuevo por tipo y severidad, con decisión explícita sobre deuda no bloqueante.
3. Resolver el **skip** de `DocenteRepositorySqlServerIT` o aprobar excepción documentada con test/fixture de compensación; la DoD exige no esconder skips obligatorios.
4. Revisar diff de 406 archivos con foco en `src/main/**`, boundary contracts y cambios de tests RED; pedir aprobación de otro revisor humano.
5. No modificar backend/DB durante la aprobación de este PR solo para completar LB-004. Si surgen fallos reproducibles reales, abrir microfase/fix con pruebas.
6. Solo tras aprobación: merge controlado a `develop`, registrar SHA merge y actualizar baseline/cierre. **No está autorizado fusionar por esta auditoría.**

## Próximo trabajo

[LB-004 — PLAN DE REANUDACIÓN](../LB-004-stateless-serverless-readiness/RESUMPTION_CONTRACT_PLAN_2026-10-08.md). La primera fase es **DB CONTRACT ANALYSIS**, no un cambio automático de SQL. Mantener `PAUSE.md` como registro histórico y no declarar `REVIEW_BINDING` resuelto.
