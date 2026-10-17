---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-29
---

# STATE INVENTORY — LB-004A / LB-004B.0

## Clasificación

- A `STATELESS_OK`
- B `EXTERNALIZED_STATE`
- C `LOCAL_FILESYSTEM_STATE`
- D `LOCAL_HEAP_STATE`
- E `INSTANCE_COUPLED`
- F `DECISION_REQUIRED`
- G `OUT_OF_SCOPE_LB004`

## Inventario comprobado

| ID | Clasificación | Componente/estado | Persistencia y efecto al reemplazar réplica | Impacto LB-004 |
|---|---|---|---|---|
| ST-001 | ~~C `LOCAL_FILESYSTEM_STATE`~~ → **B `EXTERNALIZED_STATE`** (LB-004B.2) | Bytes de soporte en MinIO (`asistencias-soportes`), no en `ArchivoController` | Volumen Docker dedicado al servicio `minio`, no al backend; certificado real con `MinioFileStorageAdapterIT` (restart simulado, dos clientes independientes) | **Resuelto** — ver `LB-004B.2-VALIDATION.md` |
| ST-002 | ~~E `INSTANCE_COUPLED`~~ → **B `EXTERNALIZED_STATE`** (LB-004B.2) | Endpoint MinIO fijo (`app.providers.minio.endpoint`), no working directory de la réplica | Host/path del backend ya no determinan la ubicación de los bytes | **Resuelto** |
| ST-003 | F `DECISION_REQUIRED` (parcial) | Ownership de upload/download | Estudiante propietario: `DECIDED YES`, implementado y probado (ownership técnico vía `ownerSubject`). Docente/coordinador/administrador: `DENY_BY_DEFAULT` en runtime hasta `DR-LB004-DB-002` | **Parcial** — estudiante resuelto; docente/coordinador/admin bloqueado por DB, no por decisión |
| ST-004 | F `DECISION_REQUIRED` | Retención, borrado, archivo huérfano, migración y URL estable | Lifecycle/rollback conceptual definido; valores producto e inventario operacional pendientes; `delete` existe en `FileStoragePort` pero sin UseCase/endpoint (no expuesto, `DELETE_ENDPOINT: NO`) | Bloqueador de implementación/cutover de retención (fuera de alcance LB-004B.2) |
| ST-005 | B `EXTERNALIZED_STATE` | SQL Server, JDBC/JPA | Estado de negocio compartido | Correcto para reemplazo; no cambiar DB Golden Path |
| ST-006 | B `EXTERNALIZED_STATE` | Keycloak runtime/provisioning | Identidad fuera de la JVM | Correcto arquitectónicamente; E2E real pendiente MV-002 |
| ST-007 | A `STATELESS_OK` | Bearer JWT + `SessionCreationPolicy.STATELESS` | No hay sesión de servidor | Correcto |
| ST-008 | A `STATELESS_OK` | `CorrelationIdContext`/MDC | Request-scoped y limpiado en `finally` | Correcto; debe preservarse |
| ST-009 | D `LOCAL_HEAP_STATE` | Caffeine Key Vault 50/5 min | Cache derivada; se reconstruye | No bloquea durabilidad; consistencia por réplica requiere test/decisión |
| ST-010 | D `LOCAL_HEAP_STATE` | Caffeine App Configuration parameters 1000/10 min | Cache derivada; se reconstruye | No justifica cache distribuida |
| ST-011 | D `LOCAL_HEAP_STATE` | Caffeine App Configuration messages 2×2000/30 min | Cache derivada; se reconstruye | Riesgo de staleness entre réplicas |
| ST-012 | D `LOCAL_HEAP_STATE` | SQL parameter/message `ConcurrentHashMap` | Derivada pero sin TTL/tamaño; diverge hasta restart/clear | Requiere política de freshness si se usa en alcance futuro |
| ST-013 | B `EXTERNALIZED_STATE` | App Configuration / Key Vault | Source of truth externo | Arquitectura apta; MV-003 no completa |
| ST-014 | E `INSTANCE_COUPLED` | Event Grid invalida la réplica receptora | No hay broadcast a todas las réplicas demostrado | No seleccionar Redis; registrar límite y test futuro |
| ST-015 | C `LOCAL_FILESYSTEM_STATE` | JSONL de logs | Puede perderse con la instancia | No es estado funcional; operación cloud pertenece a LB-006 |
| ST-016 | B `EXTERNALIZED_STATE` | Auditoría SQL cuando repository disponible | Durable y compartida | Correcto; TD-010 es deuda contractual distinta |
| ST-017 | D `LOCAL_HEAP_STATE` | Micrometer counters/gauges y buffers runtime | Locales hasta scrape/export | Telemetría, no source of truth |
| ST-018 | G `OUT_OF_SCOPE_LB004` | `Sinks.Many`, subscribers y SSE connections | Locales y efímeros | LB-005 / TD-003 |
| ST-019 | G `OUT_OF_SCOPE_LB004` | Outbox/durabilidad realtime | No existe | LB-005 / TD-011 si se exige |
| ST-020 | G `OUT_OF_SCOPE_LB004` | IaC, CD, recursos cloud, topology, Actuator exposure | No implementado/certificado aquí | LB-006 / TD-022, TD-023 residual, TD-027 |
| ST-021 | A `STATELESS_OK` | Objetos de request, DTO/domain, persistence contexts, pools/conexiones | Estado transitorio de ejecución | No confundir con estado contractual |
| ST-022 | A `STATELESS_OK` | OpenAPI/Swagger static resources | Read-only dentro del artefacto | No mutable |
| ST-023 | A `STATELESS_OK` | UUIDs y timestamps de operaciones | Datos por operación, persistidos cuando aplica | No coupling a instancia |
| ST-024 | E `INSTANCE_COUPLED` | Consumer frontend de `/archivos/**` | Consumer confirmado: upload/attach estudiante; download docente usa `window.open` sin Bearer | Requiere cambio frontend de download y unificar límite 10 MB/5 MiB |
| ST-025 | A `STATELESS_OK` | Buffer en memoria para generar reporte Excel | Se crea por request y puede reconstruirse desde la consulta | No es estado durable ni cache compartida |

## Resultado por escenario

| Escenario | Resultado AS-IS |
|---|---|
| Levantar dos réplicas A/B sobre la misma DB | Golden Path HTTP/DB puede compartir estado; storage local y SSE no. |
| Upload en A, download en B | `404` esperado salvo volumen compartido no evidenciado. |
| Destruir A tras upload | bytes potencialmente perdidos; referencia SQL puede sobrevivir rota. |
| Reiniciar una réplica | caches se vacían y se repueblan; storage depende de persistencia del disco/volumen. |
| Request autenticado por cualquier rol con nombre conocido | puede alcanzar download; no hay ownership. |
| Evento App Configuration/Key Vault con múltiples réplicas | solo se invalida cada réplica que reciba/procese el evento; distribución no demostrada. |
| Evento de asistencia publicado en A con cliente SSE conectado a B | no se entrega; LB-005. |

## Bloqueadores stateless reales de LB-004

1. Bytes contractuales en filesystem local (`ST-001/002`).
2. Ausencia de ownership y vínculo durable entre objeto y recurso funcional (`ST-003`).
3. Metadata/binding durable exige contrato DB; retención/delete exigen producto (`ST-003/004`).
4. Consumer confirmado pero descarga no compatible con Bearer y límite divergente (`ST-024`).

Las caches locales son estado derivado, no state store. Se requiere acordar freshness y probar invalidación por réplica, pero no hay evidencia para convertirlas en Redis u otra infraestructura distribuida.

