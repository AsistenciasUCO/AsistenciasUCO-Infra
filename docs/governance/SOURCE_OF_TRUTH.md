---
status: active
type: normative
scope: transversal-all-layers
owner: architecture-and-devops-team
last-reviewed: 2026-10-13
---

# 🏛️ Autoridad y Fuentes de Verdad (Single Source of Truth - SSOT)

Este documento establece la jerarquía de autoridad, precedencia documental y demarcación de límites entre las cuatro capas del **Sistema de Gestión de Asistencia UCO** (`GestioAsistenciaDB`, `GestioAsistenciaBackend`, `GestioAsistenciaFrontend` e `AsistenciasUCO-Infra`).

---

## 1. Precedencia Formal de Autoridad

Dentro de cualquier decisión técnica o implementación, la precedencia es estrictamente la siguiente:

1. **Contratos Aprobados WORM y Architecture Decision Records (ADRs) vigentes:**
   - Contratos inmutables formalizados en `AsistenciasUCO-Infra/docs/contracts/` con su correspondiente firma `.sha256`.
2. **Constitución Técnica y Documentación Normativa Activa (`type: normative`, `status: active`):**
   - [`CONSTITUTION.md`](CONSTITUTION.md) (Ley suprema del ecosistema).
   - Reglas de diseño y calidad (`API_DESIGN_RULES.md`, `DEFINITION_OF_READY.md`, `DEFINITION_OF_DONE.md`).
3. **Código y Tests Existentes para Describir el AS-IS:**
   - Evidencia observable y reproducible de comportamiento actual (nunca suposiciones ni código comentado).
4. **Work Item Activo:**
   - Delimita el alcance, pruebas RED y evidencia de una tarea específica en ejecución. Un work item no puede cambiar unilateralmente las normas del sistema.
5. **Runbooks Operativos:**
   - Describen cómo operar, verificar y desplegar, pero nunca inventan comportamiento funcional.
6. **Documentación Histórica o de Archivo:**
   - Provee trazabilidad histórica, pero carece de autoridad vigente ante contradicciones.

---

## 2. Matriz de Ámbitos Independientes

| Ámbito | Fuente de Autoridad Canónica | Límite y Restricción Inviolable |
| :--- | :--- | :--- |
| **DOMAIN & BUSINESS RULES** | Casos de uso e invariantes de negocio en `application/features/**/usecase/domain` y reglas institucionales UCO (20% inasistencia, asistencia potestad del docente). | No copiar reglas de librerías externas o repositorios ajenos sin adaptación. |
| **HTTP CONTRACT** | [OpenAPI Canónico](../contracts/openapi/openapi-golden-path.yaml) congelado bajo WORM. | Ni el frontend ni SQL Server pueden renombrar campos JSON, alterar códigos HTTP o inventar paginación no contratada. |
| **PERSISTENCE CONTRACT** | Esquema DDL, Stored Procedures (`usp_*`) y Vistas (`uv_*`, `uv_auth_*`) de `GestioAsistenciaDB`. | El backend no administra el esquema en runtime. Prohibido ejecutar SQL inline o JPA directo sin contrato en BD. |
| **SECURITY CONTRACT** | Keycloak Realm institucional (`asistencias-uco-realm.json`), RBAC y `UserScopeService`. | Prohibido inventar roles o claims por comodidad del frontend. El claim `idUsuario` es mandatorio en tokens. |
| **REALTIME CONTRACT** | [Estándar de Eventos SSE](../contracts/events/REALTIME_EVENT_CONTRACT.md) y stream `/api/v1/realtime/stream`. | La base de datos y la API conservan el estado; SSE no es almacén de datos ni admite simulación por polling. |
| **INFRASTRUCTURE & ENVIRONMENT** | Orquestadores Docker, Compose maestro, Least Privilege y `.env.example` en `AsistenciasUCO-Infra`. | Los secretos residen en Key Vault / variables de entorno locales; nunca se versionan contraseñas en Git. |
| **DYNAMIC CONFIG & MESSAGES** | Azure App Configuration (`messages:user:*`, `messages:technical:*`, `asistencias:*`). | Textos en enums de Java o TypeScript son únicamente *fallbacks* ante desconexión temporal. |

---

## 3. Repositorios Dueños de Contratos Externos

Cuando un módulo requiere consumir un contrato de otro componente, la evidencia versionada del módulo custodio prevalece de forma absoluta:

* **Persistencia:** Stored procedures y vistas liberadas en `GestioAsistenciaDB`.
* **API REST:** Especificación OpenAPI aprobada y congelada.
* **Frontend:** Su código y componentes solo evidencian lo que consumen; el cliente no redefine el contrato del backend.
* **Infraestructura:** Provee el entorno de ejecución, seguridad de red y orquestación; no muta las reglas de negocio.

---

## 4. Protocolo de Bloqueo y Resolución de Conflictos

Si durante una fase de desarrollo o auditoría se detecta una incongruencia entre fuentes autoritativas, el agente o desarrollador debe **detener inmediatamente la implementación dependiente** y aplicar el protocolo:

1. **`CONTRACT_CONFLICT`:** Dos contratos o fuentes normativas se contradicen formalmente. Se registra el ID, ambas fuentes y el ámbito en el work item.
2. **`TEST_CONTRACT_CONFLICT`:** Un test contradice el contrato aprobado. Se devuelve a revisión. **El implementador jamás altera el test RED para forzar su paso.**
3. **`BLOCKED_BY_MISSING_EVIDENCE`:** Falta una fuente necesaria o un ambiente indispensable.

La resolución de bloqueos contractuales exige:
1. Dictamen formal del rol de contratos y arquitectura.
2. Modificación consensuada del contrato y actualización de su firma `.sha256`.
3. Verificación de paridad con `AsistenciasUCO-Infra/scripts/quality/verify-contracts.ps1`.
