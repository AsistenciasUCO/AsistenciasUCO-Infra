# Indice Maestro de Work Items y Tareas (Full-Stack)
> **Ecosistema:** Sistema de Gestion de Asistencia UCO  
> **Proposito:** Registro centralizado y trazabilidad de ciclo de vida SDD/TDD para Backend, Frontend y Base de Datos.  
> **Generacion:** Automatizada via AsistenciasUCO-Infra/scripts/quality/sync-work-items.ps1  
> **Ultima Actualizacion:** 2026-10-24 22:21:58  

---

## 1. Resumen Consolidado del Ecosistema

| Capa Tecnologica | Work Items / Fases | Archivos Sincronizados |
| :--- | :---: | :---: |
| **Backend API (Spring Boot)** | 54 | 142 |
| **Frontend Web (Angular 19)** | 14 | 25 |
| **Base de Datos (SQL Server)** | 8 | 10 |
| **TOTAL CONSOLIDADO** | **76** | **416** |

---

## 2. Catalogo Detallado de Work Items por Capa

### 2.1 Backend API (Spring Boot) (backend/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| FIX-001-sse-error-content-negotiation | 3 | active | [Ver carpeta](backend/FIX-001-sse-error-content-negotiation/) |
| FIX-002-overview-contador-reclamos-docente | 3 | N/A | [Ver carpeta](backend/FIX-002-overview-contador-reclamos-docente/) |
| HU035-HU036-bandeja-detalle-reclamos-docente | 5 | closed | [Ver carpeta](backend/HU035-HU036-bandeja-detalle-reclamos-docente/) |
| HU050-matricula-manual-docente | 5 | closed | [Ver carpeta](backend/HU050-matricula-manual-docente/) |
| HU062-HU089-HU063-HU090-HU091-vinculacion-docente | 3 | draft | [Ver carpeta](backend/HU062-HU089-HU063-HU090-HU091-vinculacion-docente/) |
| HU062-HU093-docentes-coordinacion | 5 | active | [Ver carpeta](backend/HU062-HU093-docentes-coordinacion/) |
| HU076-HU077-HU078-programa-academico-decano | 4 | frozen-implemented | [Ver carpeta](backend/HU076-HU077-HU078-programa-academico-decano/) |
| HU116-alta-facultad | 5 | closed | [Ver carpeta](backend/HU116-alta-facultad/) |
| HU117-HU110-HU111-gestion-facultad | 4 | active | [Ver carpeta](backend/HU117-HU110-HU111-gestion-facultad/) |
| HU120-crear-coordinador | 5 | closed | [Ver carpeta](backend/HU120-crear-coordinador/) |
| HU121-HU122-gestion-coordinador | 3 | contract-frozen | [Ver carpeta](backend/HU121-HU122-gestion-coordinador/) |
| HU129-HU141-analitica-docente-carga-escalafon | 5 | N/A | [Ver carpeta](backend/HU129-HU141-analitica-docente-carga-escalafon/) |
| HU154-HU023-HU151-HU152-catalogos-admin | 3 | active | [Ver carpeta](backend/HU154-HU023-HU151-HU152-catalogos-admin/) |
| HU176B-matricula-qr-autonoma | 3 | draft | [Ver carpeta](backend/HU176B-matricula-qr-autonoma/) |
| IAM-001-ciclo-vida-cuenta-identidad | 3 | draft | [Ver carpeta](backend/IAM-001-ciclo-vida-cuenta-identidad/) |
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
| LB-004-stateless-serverless-readiness | 29 | active | [Ver carpeta](backend/LB-004-stateless-serverless-readiness/) |
| LB-008-jpa-only-persistence-migration | 5 | N/A | [Ver carpeta](backend/LB-008-jpa-only-persistence-migration/) |
| LOCAL-STABILIZATION-LB004D-2026-10-20 | 4 | N/A | [Ver carpeta](backend/LOCAL-STABILIZATION-LB004D-2026-10-20/) |
| MAINT-001-maintainability-audit | 4 | active | [Ver carpeta](backend/MAINT-001-maintainability-audit/) |
| MAINT-002-parameter-cache-key | 3 | active | [Ver carpeta](backend/MAINT-002-parameter-cache-key/) |
| MAINT-003-backend-utc-pagination-readiness | 16 | active | [Ver carpeta](backend/MAINT-003-backend-utc-pagination-readiness/) |
| MAINT-003D-utc-contract-tests-handoff | 6 | N/A | [Ver carpeta](backend/MAINT-003D-utc-contract-tests-handoff/) |
| MAINT-003E-utc-unblock | 5 | N/A | [Ver carpeta](backend/MAINT-003E-utc-unblock/) |
| MAINT-003G-remediation | 3 | active | [Ver carpeta](backend/MAINT-003G-remediation/) |
| MAINT-003H-provider-contract-review | 6 | N/A | [Ver carpeta](backend/MAINT-003H-provider-contract-review/) |
| MAINT-003K-backend-only-release-gate | 6 | BACKEND_CI_GREEN_REVIEW_READY | [Ver carpeta](backend/MAINT-003K-backend-only-release-gate/) |
| MAINT-003L-pagination-e2e-local | 4 | N/A | [Ver carpeta](backend/MAINT-003L-pagination-e2e-local/) |
| P0-B-unificacion-repositorios | 6 | N/A | [Ver carpeta](backend/P0-B-unificacion-repositorios/) |
| P0-B2-local-consolidation | 3 | active | [Ver carpeta](backend/P0-B2-local-consolidation/) |
| P0-B2-log-hygiene | 3 | active | [Ver carpeta](backend/P0-B2-log-hygiene/) |
| P0-C-estabilizacion-cierre | 3 | active | [Ver carpeta](backend/P0-C-estabilizacion-cierre/) |
| P0-D-consolidacion-fisica | 4 | N/A | [Ver carpeta](backend/P0-D-consolidacion-fisica/) |
| P0-D-estabilizacion-workspace-oficial | 4 | active | [Ver carpeta](backend/P0-D-estabilizacion-workspace-oficial/) |
| P0-E-consolidacion-funcional | 3 | active | [Ver carpeta](backend/P0-E-consolidacion-funcional/) |
| P0-estabilizacion-multirrepositorio | 4 | N/A | [Ver carpeta](backend/P0-estabilizacion-multirrepositorio/) |
| P0-G-recuperacion-funcional | 4 | N/A | [Ver carpeta](backend/P0-G-recuperacion-funcional/) |
| P0-H-activar-version-funcional | 4 | N/A | [Ver carpeta](backend/P0-H-activar-version-funcional/) |
| P0-I-cierre-integracion-final | 5 | N/A | [Ver carpeta](backend/P0-I-cierre-integracion-final/) |
| P0-SEC-001-coordinador-asignatura-ownership | 3 | N/A | [Ver carpeta](backend/P0-SEC-001-coordinador-asignatura-ownership/) |
| QUALITY-PR15-recovery | 9 | active | [Ver carpeta](backend/QUALITY-PR15-recovery/) |
| REG-000-programa-registro-vinculacion-roles | 1 | draft | [Ver carpeta](backend/REG-000-programa-registro-vinculacion-roles/) |
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
| LB-004D-F1-soportes-reclamos | 1 | N/A | [Ver carpeta](frontend/LB-004D-F1-soportes-reclamos/) |
| LB-004D-F2-student-portal-contract | 1 | N/A | [Ver carpeta](frontend/LB-004D-F2-student-portal-contract/) |
| LB-004D-F3-student-attendance-states | 1 | N/A | [Ver carpeta](frontend/LB-004D-F3-student-attendance-states/) |
| MAINT-004-frontend-backend-db-alignment | 7 | N/A | [Ver carpeta](frontend/MAINT-004-frontend-backend-db-alignment/) |
| MV-001-golden-path-real-e2e | 2 | N/A | [Ver carpeta](frontend/MV-001-golden-path-real-e2e/) |
| P0-B2-teacher-regression | 3 | active | [Ver carpeta](frontend/P0-B2-teacher-regression/) |
| P0-C-chromeheadless | 3 | active | [Ver carpeta](frontend/P0-C-chromeheadless/) |
| P0-D-estabilizacion-workspace-oficial | 3 | active | [Ver carpeta](frontend/P0-D-estabilizacion-workspace-oficial/) |
| UX-006-dean-coordinator-view-split | 4 | N/A | [Ver carpeta](frontend/UX-006-dean-coordinator-view-split/) |

### 2.3 Base de Datos (SQL Server) (database/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| CC-003G-01-public-user-plan-providers | 4 | N/A | [Ver carpeta](database/CC-003G-01-public-user-plan-providers/) |
| DB-GP-001B-final-closure | 3 | N/A | [Ver carpeta](database/DB-GP-001B-final-closure/) |
| DB-GP-001C-develop-final-freeze | 6 | N/A | [Ver carpeta](database/DB-GP-001C-develop-final-freeze/) |
| LB-002.1C-A-db-contract-baseline-recovery | 1 | N/A | [Ver carpeta](database/LB-002.1C-A-db-contract-baseline-recovery/) |
| LB-004D-soporte-revision-binding | 6 | proposed | [Ver carpeta](database/LB-004D-soporte-revision-binding/) |
| MAINT-003K-DB-DEV-CONSOLIDATION | 4 | VALIDATED_LOCAL_DEV | [Ver carpeta](database/MAINT-003K-DB-DEV-CONSOLIDATION/) |
| P0-D-estabilizacion-workspace-oficial | 2 | active | [Ver carpeta](database/P0-D-estabilizacion-workspace-oficial/) |
| UTC-D06-POST-FREEZE | 3 | active | [Ver carpeta](database/UTC-D06-POST-FREEZE/) |

---

## 3. Instrucciones de Gobernanza para Nuevas Historias de Usuario

1. Todo nuevo Work Item derivado de una Historia de Usuario (HU001 - HU174) debe crearse respetando el pipeline SDD/TDD con los 5 archivos estandar: PLAN.md, CONTRACT.md, TEST_PLAN.md, VALIDATION.md y CLOSURE.md.
2. Al concluir una fase, ejecute sync-work-items.ps1 para actualizar este indice y mantener paridad de auditoria en la 4a capa.
