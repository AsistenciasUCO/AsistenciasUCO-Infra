---
status: active
type: work-item
scope: backend
last-reviewed: 2026-10-09
---

# TEST_PLAN — backend real, contrato temporal y paginación

| ID | Requisito | Oracle y escenario | Nivel | Evidencia obligatoria |
|---|---|---|---|---|
| UTC-01 | RFC3339 con offset | Berlín +02/ Londres +01 / Bogotá -05 mapean al instante UTC | Unit codec | Tests HttpUtcInstantCodecTest |
| UTC-02 | No aceptar naive en contrato nuevo | cadena `2026-07-15T09:00:00` rechazada | Unit codec | 4xx v2 posteriormente |
| UTC-03 | Estabilidad DST | Berlín 25-Oct 02:30 offsets +02 y +01 son instantes distintos | Unit codec / contrato | assertions |
| UTC-04 | Escritura UTC | v2 POST con +02 → SQL DATETIME2 UTC y GET con Z | IT E2E | SQL SELECT + API response |
| UTC-05 | Edición y ownership | PATCH autorizada/not found/rechazo sin alterar UTC | SQL IT | before/after |
| UTC-06 | Históricos v1 | no reinterpretar registros ambiguos | read-only SQL + informe de clasificación | contrato acordado |
| PAG-01 | Paginación server-side | page 0/1/2 size 5 vs view COUNT_BIG + OFFSET | SQL IT PR18 | IDs, totales, orden |
| PAG-02 | Identidad 1:1 | estudiante multigrupo no duplica y filtros EXISTS | SQL IT | fixture certificada |
| PAG-03 | Límite de entrada | page negativo, size 0/101, offset > int | Unit/HTTP | 400 y cero interacciones JPA |
| PAG-04 | Aislamiento de roles | Coordinador y Admin autorizado; Estudiante/Docente sin permiso | HTTP real Keycloak | 200 / 403 sin PII |
| CAT-01 | Parámetros catálogo | consultas normalizadas, caché par compuesto, miss no cacheado | SQL IT PR19 | provider real, valores desensibilizados |
| CAT-02 | Seguridad | fallos de SQL nunca devuelven parámetro positivo inventado | Unit + IT | excepción/correlación |

**Test execution sequence:** `./mvnw -B -ntp clean verify`; `./mvnw -B -ntp -Pintegration verify` contra SQL Server local (inspeccionar tags, tags no ejecutados y assumptions: el skip es no certificado). Luego Docker, Sonar/CodeQL/Trivy, pruebas HTTP con token de roles real; guardar screenshots HAR sin JWT ni credenciales. No escribir fixtures en DB compartida/producción.

### Gate de salida
Sólo declarar backend READY_FOR_FRONTEND cuando: (a) PR18+19 merged tras aprobación y SQL IT PASS real; (b) API UTC v2 aprobada, implementada con contract tests, provider real y datos históricos clasificados; (c) versión del contrato publicada; (d) security+coverage+ArchUnit PASS. Hasta entonces FRONTEND_BLOCKED_BY_BACKEND_CONTRACT.
