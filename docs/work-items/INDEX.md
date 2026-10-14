# Indice Maestro de Work Items y Tareas (Full-Stack)
> **Ecosistema:** Sistema de Gestion de Asistencia UCO  
> **Proposito:** Registro centralizado y trazabilidad de ciclo de vida SDD/TDD para Backend, Frontend y Base de Datos.  
> **Generacion:** Automatizada via AsistenciasUCO-Infra/scripts/quality/sync-work-items.ps1  
> **Ultima Actualizacion:** 2026-10-13 21:09:28  

---

## 1. Resumen Consolidado del Ecosistema

| Capa Tecnologica | Work Items / Fases | Archivos Sincronizados |
| :--- | :---: | :---: |
| **Backend API (Spring Boot)** | 14 | 142 |
| **Frontend Web (Angular 19)** | 6 | 25 |
| **Base de Datos (SQL Server)** | 3 | 10 |
| **TOTAL CONSOLIDADO** | **23** | **177** |

---

## 2. Catalogo Detallado de Work Items por Capa

### 2.1 Backend API (Spring Boot) (backend/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| HU050-matricula-manual-docente | 5 | N/A | [Ver carpeta](backend/HU050-matricula-manual-docente/) |
| HU050.2-jpa-queries-grupo-sesion | 5 | closed | [Ver carpeta](backend/HU050.2-jpa-queries-grupo-sesion/) |
| LB-000-gobernanza-documentacion | 7 | active | [Ver carpeta](backend/LB-000-gobernanza-documentacion/) |
| LB-001A-db-backend-asistencia | 4 | active | [Ver carpeta](backend/LB-001A-db-backend-asistencia/) |
| LB-001B-backend-frontend-asistencia | 5 | N/A | [Ver carpeta](backend/LB-001B-backend-frontend-asistencia/) |
| LB-001B.1-db-source-of-truth-cleanup | 6 | active | [Ver carpeta](backend/LB-001B.1-db-source-of-truth-cleanup/) |
| LB-001B.3-backend-db-alignment | 11 | active | [Ver carpeta](backend/LB-001B.3-backend-db-alignment/) |
| LB-001B.4-final-backend-contract-closure | 9 | active | [Ver carpeta](backend/LB-001B.4-final-backend-contract-closure/) |
| LB-001C-openapi-contract-first | 22 | done | [Ver carpeta](backend/LB-001C-openapi-contract-first/) |
| LB-001D-governance-hardening | 12 | N/A | [Ver carpeta](backend/LB-001D-governance-hardening/) |
| LB-002-jpa-incremental | 38 | N/A | [Ver carpeta](backend/LB-002-jpa-incremental/) |
| LB-002.1C-B1-registrar-estudiante | 6 | suspended | [Ver carpeta](backend/LB-002.1C-B1-registrar-estudiante/) |
| LB-003-quality-gate-golden-path | 7 | closed | [Ver carpeta](backend/LB-003-quality-gate-golden-path/) |
| TECH-001-restaurar-gate-arquitectura | 4 | active | [Ver carpeta](backend/TECH-001-restaurar-gate-arquitectura/) |

### 2.2 Frontend Web (Angular 19) (frontend/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| LB-001B.1A-frontend-contract-corrections | 4 | N/A | [Ver carpeta](frontend/LB-001B.1A-frontend-contract-corrections/) |
| LB-001B.1B-db-source-of-truth-cleanup | 5 | draft | [Ver carpeta](frontend/LB-001B.1B-db-source-of-truth-cleanup/) |
| LB-001B.1C-final-contract-cleanup | 6 | N/A | [Ver carpeta](frontend/LB-001B.1C-final-contract-cleanup/) |
| LB-001B.5-frontend-final-verification | 2 | N/A | [Ver carpeta](frontend/LB-001B.5-frontend-final-verification/) |
| LB-001C.2B-patch-consumer | 6 | N/A | [Ver carpeta](frontend/LB-001C.2B-patch-consumer/) |
| MV-001-golden-path-real-e2e | 2 | N/A | [Ver carpeta](frontend/MV-001-golden-path-real-e2e/) |

### 2.3 Base de Datos (SQL Server) (database/)

| Work Item / Fase | Archivos | Estado Documentado | Enlace Directo |
| :--- | :---: | :---: | :--- |
| DB-GP-001B-final-closure | 3 | N/A | [Ver carpeta](database/DB-GP-001B-final-closure/) |
| DB-GP-001C-develop-final-freeze | 6 | N/A | [Ver carpeta](database/DB-GP-001C-develop-final-freeze/) |
| LB-002.1C-A-db-contract-baseline-recovery | 1 | N/A | [Ver carpeta](database/LB-002.1C-A-db-contract-baseline-recovery/) |

---

## 3. Instrucciones de Gobernanza para Nuevas Historias de Usuario

1. Todo nuevo Work Item derivado de una Historia de Usuario (HU001 - HU174) debe crearse respetando el pipeline SDD/TDD con los 5 archivos estandar: PLAN.md, CONTRACT.md, TEST_PLAN.md, VALIDATION.md y CLOSURE.md.
2. Al concluir una fase, ejecute sync-work-items.ps1 para actualizar este indice y mantener paridad de auditoria en la 4a capa.
