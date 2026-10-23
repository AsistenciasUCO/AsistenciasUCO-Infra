# Plantilla Estándar de Work Item para Historias de Usuario

## Ubicación oficial (fuente de autoría)

Los work items **se crean y editan en el repositorio de la capa que lidera el cambio**, nunca en esta carpeta:

| Tipo de work item | Ubicación de autoría |
| :--- | :--- |
| Historias de Usuario (HU), aunque abarquen DB + Backend + Frontend | `GestioAsistenciaBackend/docs/work-items/HUxxx-nombre/` |
| Tareas exclusivas de base de datos (freeze, fixtures, contratos DB) | `GestioAsistenciaDB/docs/work-items/` |
| Tareas exclusivas de frontend (UX, contratos de cliente) | `GestioAsistenciaFrontend/docs/work-items/` |

Esta carpeta (`AsistenciasUCO-Infra/docs/work-items/`) es un **espejo de solo lectura** generado por
`scripts/quality/sync-work-items.ps1`, que copia las tres fuentes a `backend/`, `database/` y `frontend/` y
regenera `INDEX.md`. No editar a mano los archivos espejados: se sobrescriben en la siguiente sincronización.

> `HU050-matricula-manual-docente/` en la raíz de esta carpeta es un remanente previo a la convención;
> su copia vigente es `backend/HU050-matricula-manual-docente/`.

## Trazabilidad entre repositorios

- Los commits y PR de DB y Frontend referencian la HU (`Refs: HUxxx`) y la ruta del work item en el Backend.
- Tras cerrar una HU se ejecuta `sync-work-items.ps1` y se actualiza `docs/user-stories/HU-CATALOG.md`.

## Artefactos canónicos

Cada Historia de Usuario contendrá sus 5 artefactos canónicos (plantillas en `GestioAsistenciaBackend/.claude/templates/`):
1. PLAN.md: Análisis AS-IS vs TARGET, alcance y Definition of Ready (DoR).
2. CONTRACT.md: Contratos WORM (OpenAPI YAML y Stored Procedures T-SQL).
3. TEST_PLAN.md: Casos de prueba RED derivados del contrato antes de programar.
4. VALIDATION.md: Comandos ejecutados, evidencias de Quality Gates y cobertura.
5. CLOSURE.md: Dictamen final de cierre y actualización de la HU en HU-CATALOG.md.

## Granularidad de entrega

Un work item = una HU, o un grupo pequeño de HU acopladas (mismo SP, endpoint o componente). Cada work item
se entrega con una rama `feature/HUxxx-descripcion` y un PR por repositorio afectado, en orden DB → Backend → Frontend.
No se agrupan HU independientes en un mismo PR.
