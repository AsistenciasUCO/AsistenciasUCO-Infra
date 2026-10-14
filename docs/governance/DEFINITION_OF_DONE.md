---
status: active
type: normative
scope: transversal-all-layers
owner: architecture-and-devops-team
last-reviewed: 2026-10-13
---

# ✅ Definition of Done (DoD) — Criterios de Finalización Transversal

Este documento establece la lista taxativa de requisitos que deben certificarse objetivamente antes de que un work item, Historia de Usuario (HU) o entregable pueda declararse formalmente **DONE** (Completado) en el **Sistema de Gestión de Asistencia UCO**.

---

## 1. Matriz Transversal de Evidencias de Cierre

La mera compilación exitosa del código **no es suficiente** para cerrar una tarea. Se exige evidencia documental de los siguientes controles:

| Dimensión | Evidencia Requerida para Declarar DONE | Verificación Técnica |
| :--- | :--- | :--- |
| **1. Contratos y Alcance** | Cumplimiento del 100% de criterios de aceptación; paridad comprobada con contratos WORM (`verify-contracts.ps1`). | Inspección de diffs y hashes SHA-256. |
| **2. Ciclo TDD (RED $\to$ GREEN)** | Pruebas RED creadas primero y derivadas del contrato. Fallo RED confirmado. Solución GREEN implementada sin relajar pruebas. | Logs de ejecución de pruebas antes y después de implementar. |
| **3. Compilación y Build** | Compilación sin errores ni advertencias bloqueantes en todas las capas intervenidas. | `mvn verify` (Java) y `npm run verify` (Angular). |
| **4. Arquitectura Limpia** | Domain y Application independientes de frameworks y providers. Controladores REST desacoplados de persistencia. | Reglas automáticas de **ArchUnit**. |
| **5. Cobertura de Pruebas** | Backend: JaCoCo `LINE >= 80%` y `BRANCH >= 70%`. Frontend: Realtime `LINE >= 90%` y `BRANCH >= 80%`. | Reportes JaCoCo y Karma coverage. |
| **6. Persistencia y Transaccionalidad** | Cero transacciones huérfanas (`@@TRANCOUNT = 0`). Ejecución de `test_suite.sql` exitosa. Usuario `app_asistencias_user` sin permisos DDL ni DML directo. | Suite T-SQL en SQL Server y script de hardening. |
| **7. Seguridad y DevSecOps** | Validación de roles institucionales (5 perfiles Keycloak) y jurisdicción contextual (`UserScopeService`). Cero secretos nuevos en código o repositorios. | Escáner `AsistenciasUCO-Infra/scripts/security/check-secrets.ps1`. |
| **8. Observabilidad** | Propagación de `X-Correlation-Id`, trazas OTLP y logs estructurados JSONL sin datos sensibles expuestos. | Filtros OpenTelemetry y Actuator. |
| **9. Documentación y Trazabilidad** | Documentos actualizados en `docs/`; actualización de ledger de deuda técnica si aplica; registro formal de cierre (`CLOSURE.md`). | Verificación de documentación y enlaces rotos. |

---

## 2. Inviolabilidad de las Pruebas y Criterio Antifraude

> [!CAUTION]
> ### 🛑 REGLA SUPREMA: EL IMPLEMENTADOR NO ALTERA LOS TESTS
> Queda terminantemente prohibido modificar, relajar, comentar o desactivar pruebas unitarias o de integración para forzar un resultado verde.
> 
> Si un test falla:
> 1. El desarrollador o agente debe corregir el código productivo.
> 2. Si se demuestra fehacientemente que el test contradice el contrato formal, se declara `TEST_CONTRACT_CONFLICT` y se devuelve formalmente al rol de testing tras dictamen del auditor.

---

## 3. Cierre de Tareas Documentales vs. Tareas de Código

* **Tareas Documentales (`DOCUMENTATION_ONLY`):**
  - No requieren ejecución de pruebas de persistencia en vivo.
  - Exigen: verificación de coherencia técnica, validación de enlaces relativos, ausencia absoluta de secretos quemados (`check-secrets.ps1`) y confirmación de que no se modificó código fuera de las rutas autorizadas.
* **Tareas de Código e Infraestructura (`BEHAVIOR_CHANGE`, `REFACTOR`, `INFRASTRUCTURE`):**
  - Exigen la aprobación del 100% de las dimensiones de la tabla superior.
  - La presencia de cualquier prueba omitida o simulada (`NOT_RUN`) impide cerrar el ítem como DONE.
