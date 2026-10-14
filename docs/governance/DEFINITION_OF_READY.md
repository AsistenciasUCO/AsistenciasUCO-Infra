---
status: active
type: normative
scope: transversal-all-layers
owner: architecture-team
last-reviewed: 2026-10-13
---

# 📋 Definition of Ready (DoR) — Criterios de Preparación Transversal

Este documento establece los criterios obligatorios que deben satisfacerse antes de autorizar el inicio de cualquier tarea, Historia de Usuario (HU) o work item en el **Sistema de Gestión de Asistencia UCO**.

---

## 1. Clasificación Obligatoria de Cambio

Todo plan de trabajo (`PLAN.md`) debe declarar formalmente:
1. **Clase de Cambio:**
   - `DOCUMENTATION_ONLY`: Ajustes o adiciones documentales y de gobernanza.
   - `CONTRACT_ANALYSIS`: Investigación y auditoría de alineación entre contratos y código.
   - `CONTRACT_CHANGE`: Modificación formal de contratos públicos WORM (exige actualización de `.sha256`).
   - `REFACTOR`: Reestructuración interna sin alteración de comportamiento observable ni de contratos.
   - `BEHAVIOR_CHANGE`: Implementación o modificación de lógica funcional de negocio.
   - `PERSISTENCE_MIGRATION`: Migración técnica de acceso a datos (ej. JDBC legacy $\to$ Spring Data JPA).
   - `INFRASTRUCTURE`: Modificación de contenedores Docker, perfiles, seguridad de red o scripts operativos.
2. **Rutas Permitidas:** Lista taxativa de archivos y carpetas autorizados para ser modificados.
3. **Rutas Prohibidas:** Rutas vetadas donde está estrictamente prohibido realizar cambios.
4. **Variable Principal:** Componente, puerto o capacidad central que se interviene.

---

## 2. Criterios de Preparación (READY) por Tipo de Tarea

### 2.1 READY para `CONTRACT_ANALYSIS` y `DOCUMENTATION_ONLY`
* Repositorios y contratos identificados con sus versiones y hashes SHA-256.
* Propietario del contrato (Provider) y consumidores (Consumers) claramente delimitados.
* Cero secretos expuestos en la evidencia.
* Entorno de inspección disponible.
* *Nota:* No exige build verde previo si el trabajo está estrictamente confinado a documentación.

### 2.2 READY para Implementación Técnica
Para autorizar la codificación en cualquier clase de cambio técnico (`CONTRACT_CHANGE`, `REFACTOR`, `BEHAVIOR_CHANGE`, `PERSISTENCE_MIGRATION`, `INFRASTRUCTURE`), se requiere cumplir la totalidad de los siguientes requisitos:

1. **Objetivo y Alcance Delimitados:** Criterios de aceptación claros; alcance y no alcance explícitos.
2. **Contratos Aprobados y Congelados:** Ninguna línea de código se escribe sin un contrato público previo validado en OpenAPI, SQL Server o Realtime SSE.
3. **Plan de Pruebas TDD (TEST_PLAN):** Matriz de pruebas derivada directamente de los criterios de aceptación y del contrato formal (Happy Path, Edge Cases, Errores y Roles).
4. **Build Base Saludable:** La línea base y los Quality Gates del proyecto deben encontrarse en estado verde (`mvn test` / `npm run test:ci`), salvo excepción justificada en el work item.
5. **Cero Conflictos Abiertos:** Cero estados bloqueantes de `CONTRACT_CONFLICT`, `TEST_CONTRACT_CONFLICT` o `BLOCKED_BY_MISSING_EVIDENCE` sobre el componente a intervenir.
6. **Plan de Rollback Viable:** Procedimiento documentado y probado para revertir los cambios ante cualquier regresión.

---

## 3. Estado `NOT_READY` y Prohibición de Implementación

> [!CAUTION]
> Si cualquiera de los criterios de la Sección 2.2 no se cumple, el estado del ítem es **`NOT_READY`**.
> 
> Un estado **`NOT_READY`** autoriza la investigación, planificación y formulación de contratos, pero **prohíbe tajantemente a cualquier desarrollador o agente de IA iniciar la codificación o modificación de código de producción**.
