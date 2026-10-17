# Indice Maestro de Work Items y Tareas (Full-Stack)
> **Ecosistema:** Sistema de Gestion de Asistencia UCO  
> **Proposito:** Registro centralizado y trazabilidad de ciclo de vida SDD/TDD para Backend, Frontend y Base de Datos.  
> **Generacion:** Automatizada via AsistenciasUCO-Infra/scripts/quality/sync-work-items.ps1  
> **Ultima Actualizacion:** 2026-10-17 18:48:33  

---

## 1. Resumen Consolidado del Ecosistema

| Capa Tecnologica | Work Items / Fases | Archivos Sincronizados |
| :--- | :---: | :---: |
| **Backend API (Spring Boot)** | 26 | 142 |
| **Frontend Web (Angular 19)** | 7 | 25 |
| **Base de Datos (SQL Server)** | 6 | 10 |
| **TOTAL CONSOLIDADO** | **39** | **279** |

---

## 2. Catalogo Detallado de Work Items por Capa

### 2.1 Backend API (Spring Boot) (backend/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| FIX-001-sse-error-content-negotiation | 3 | active | [Ver carpeta](backend/FIX-001-sse-error-content-negotiation/) |
| HU050-matricula-manual-docente | 5 | closed | [Ver carpeta](backend/HU050-matricula-manual-docente/) |
| LB-000-gobernanza-documentacion | 7 | active | [Ver carpeta](backend/LB-000-gobernanza-documentacion/) |
| LB-001A-db-backend-asistencia | 4 | active | [Ver carpeta](backend/LB-001A-db-backend-asistencia/) |
| LB-001B-backend-frontend-asistencia | 5 | N/A | [Ver carpeta](backend/LB-001B-backend-frontend-asistencia/) |
| LB-001B.1-db-source-of-truth-cleanup | 6 | active | [Ver carpeta](backend/LB-001B.1-db-source-of-truth-cleanup/) |
| LB-001B.3-backend-db-alignment | 11 | active | [Ver carpeta](backend/LB-001B.3-backend-db-alignment/) |
| LB-001B.4-final-backend-contract-closure | 9 | active | [Ver carpeta](backend/LB-001B.4-final-backend-contract-closure/) |
| LB-001C-openapi-contract-first | 22 | done | [Ver carpeta](backend/LB-001C-openapi-contract-first/) |
| LB-001D-governance-hardening | 12 | N/A | [Ver carpeta](backend/LB-001D-governance-hardening/) |
| LB-002-jpa-incremental | 38 | N/A | [Ver carpeta](backend/LB-002-jpa-incremental/) |
| LB-003-quality-gate-golden-path | 7 | closed | [Ver carpeta](backend/LB-003-quality-gate-golden-path/) |
| LB-004-stateless-serverless-readiness | 22 | active | [Ver carpeta](backend/LB-004-stateless-serverless-readiness/) |
| LB-008-jpa-only-persistence-migration | 5 | N/A | [Ver carpeta](backend/LB-008-jpa-only-persistence-migration/) |
| MAINT-001-maintainability-audit | 4 | active | [Ver carpeta](backend/MAINT-001-maintainability-audit/) |
| MAINT-002-parameter-cache-key | 3 | active | [Ver carpeta](backend/MAINT-002-parameter-cache-key/) |
| MAINT-003-backend-utc-pagination-readiness | 16 | active | [Ver carpeta](backend/MAINT-003-backend-utc-pagination-readiness/) |
| MAINT-003D-utc-contract-tests-handoff | 6 | N/A | [Ver carpeta](backend/MAINT-003D-utc-contract-tests-handoff/) |
| MAINT-003E-utc-unblock | 5 | N/A | [Ver carpeta](backend/MAINT-003E-utc-unblock/) |
| MAINT-003G-remediation | 3 | active | [Ver carpeta](backend/MAINT-003G-remediation/) |
| MAINT-003H-provider-contract-review | 6 | N/A | [Ver carpeta](backend/MAINT-003H-provider-contract-review/) |
| MAINT-003K-backend-only-release-gate | 6 | BACKEND_CI_GREEN_REVIEW_READY | [Ver carpeta](backend/MAINT-003K-backend-only-release-gate/) |
| QUALITY-PR15-recovery | 9 | active | [Ver carpeta](backend/QUALITY-PR15-recovery/) |
| SEC-001-trivy-archunit | 4 | active | [Ver carpeta](backend/SEC-001-trivy-archunit/) |
| SEC-002-runtime-dependency-remediation | 2 | active | [Ver carpeta](backend/SEC-002-runtime-dependency-remediation/) |
| TECH-001-restaurar-gate-arquitectura | 4 | active | [Ver carpeta](backend/TECH-001-restaurar-gate-arquitectura/) |

### 2.2 Frontend Web (Angular 19) (frontend/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| LB-001B.1A-frontend-contract-corrections | 4 | N/A | [Ver carpeta](frontend/LB-001B.1A-frontend-contract-corrections/) |
| LB-001B.1B-db-source-of-truth-cleanup | 5 | draft | [Ver carpeta](frontend/LB-001B.1B-db-source-of-truth-cleanup/) |
| LB-001B.1C-final-contract-cleanup | 6 | N/A | [Ver carpeta](frontend/LB-001B.1C-final-contract-cleanup/) |
| LB-001B.5-frontend-final-verification | 2 | N/A | [Ver carpeta](frontend/LB-001B.5-frontend-final-verification/) |
| LB-001C.2B-patch-consumer | 6 | N/A | [Ver carpeta](frontend/LB-001C.2B-patch-consumer/) |
| MAINT-004-frontend-backend-db-alignment | 7 | N/A | [Ver carpeta](frontend/MAINT-004-frontend-backend-db-alignment/) |
| MV-001-golden-path-real-e2e | 2 | N/A | [Ver carpeta](frontend/MV-001-golden-path-real-e2e/) |

### 2.3 Base de Datos (SQL Server) (database/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| CC-003G-01-public-user-plan-providers | 4 | N/A | [Ver carpeta](database/CC-003G-01-public-user-plan-providers/) |
| DB-GP-001B-final-closure | 3 | N/A | [Ver carpeta](database/DB-GP-001B-final-closure/) |
| DB-GP-001C-develop-final-freeze | 6 | N/A | [Ver carpeta](database/DB-GP-001C-develop-final-freeze/) |
| LB-002.1C-A-db-contract-baseline-recovery | 1 | N/A | [Ver carpeta](database/LB-002.1C-A-db-contract-baseline-recovery/) |
| MAINT-003K-DB-DEV-CONSOLIDATION | 4 | VALIDATED_LOCAL_DEV | [Ver carpeta](database/MAINT-003K-DB-DEV-CONSOLIDATION/) |
| UTC-D06-POST-FREEZE | 3 | active | [Ver carpeta](database/UTC-D06-POST-FREEZE/) |

---

## 3. Instrucciones de Gobernanza para Nuevas Historias de Usuario

1. Todo nuevo Work Item derivado de una Historia de Usuario (HU001 - HU174) debe crearse respetando el pipeline SDD/TDD con los 5 archivos estandar: PLAN.md, CONTRACT.md, TEST_PLAN.md, VALIDATION.md y CLOSURE.md.
2. Al concluir una fase, ejecute sync-work-items.ps1 para actualizar este indice y mantener paridad de auditoria en la 4a capa.
