---
status: active
type: work-item
scope: fullstack-database-backend-frontend
owner: fullstack-team
last-reviewed: 2026-11-17
---

# CIERRE-001 — Cierre del proyecto (2026-11-16/17)

Cierre de la entrega: seguridad de dependencias, corrección de la auditoría del 2026-11-15 y seis paquetes que mueven al servidor
lo que el frontend filtraba, paginaba o calculaba. Todo quedó mezclado en `develop` de los tres repositorios con la CI en verde.
La entrega es una **demostración con imágenes Docker**; el despliegue real en la universidad es futuro
([REQUISITOS_PRODUCCION](../../runbooks/REQUISITOS_PRODUCCION.md)).

## Paquetes y pull requests

| Paquete | Contenido | BD | Backend | Frontend |
| :--- | :--- | :---: | :---: | :---: |
| Seguridad de dependencias | 0 alertas de Dependabot y de code scanning; OpenTelemetry 1.67.0 y `HEALTHCHECK` de MinIO | | 165 | 124, 125, 138, 139 |
| Ola 0 | Cierre masivo sin fallback; alta de decano con facultad exacta; acciones del docente desde el catálogo; saneamiento documental; tres listados en servidor; arranque que rechaza `USE_MOCKS=true` sin `ALLOW_MOCKS=true`; caché de nginx; aviso flotante corregido | 140 | 166 | 140 |
| W1A: docente, reclamos y padrón | Búsqueda y filtro por grupo en reclamos; folio `REC-XXXXXXXX`; padrón paginado | 141 | 167 | 141 |
| W1B: directorios con ámbito | Retiro de `/api/v1/docentes/**`; coordinadores del decano con filtros reales; nombres y apellidos del servidor; RBAC por perfil exacto | 142 | 168 | 142 |
| W2A: listados del coordinador | Grupos y materias en servidor; opciones del consolidado; estado del período | 143 | 169 | 143 |
| W3M: matriz de asistencia | Planilla y resumen de sesiones del docente desde la base | 144 | 170 | 144 |
| W3I: indicadores | Totales de portada por rol y nivel de permanencia desde la base | 146 | 172 | 145 |
| W2B: resumen del estudiante | Resumen de materias; sesiones ordenadas y paginadas | 145 | 171 | 146 |

Repositorios: BD `johnjduque/gestion-asistencia-db`, Backend `alejovh12/AsistenciasUCO`, Frontend `shesho22/AsistenciasUCO-Frontend`.
Contratos y planes de cada paquete: `GestioAsistenciaBackend/docs/work-items/CIERRE-W1A-docente-reclamos-padron/`, `CIERRE-W1B-directorios-ambito/`,
`CIERRE-W2A-coordinador-listados/`, `CIERRE-W2B-estudiante-resumen/`, `CIERRE-W3M-matriz-asistencia/` y `CIERRE-W3I-indicadores/`
(`CONTRACT.md`, `PLAN.md`, `VALIDATION.md`); de la Ola 0 en BD: `GestioAsistenciaDB/docs/work-items/FIX-CIERRE-001-cierre-decano-acciones/VALIDATION.md`.

## Decisiones del responsable (2026-11-16)

- El token Bearer vive solo en memoria; las cookies `HttpOnly` quedan diferidas a producción (TD-110).
- El backend puede leer vistas `uv_*`.
- El frontend es presentación pura: no filtra, no pagina y no calcula datos de negocio.
- El coordinador ve solo los docentes de sus programas.
- La entrega es una demostración con imágenes Docker.

## Estado del laboratorio (2026-11-17)

- Base actualizada conservando los datos (respaldo `gestionasistenciadb_antes_cierre_20261117.bak` en el volumen de SQL Server).
- PDP aprovisionado de forma incremental: 0 recursos y 0 permisos faltantes (sin `--prune`, TD-072 y TD-073).
- Imágenes reconstruidas desde `develop`.
- Verificación de solo lectura por rol: 20 de 20 rutas nuevas correctas; `verificar_datos_prueba.py` dio 26 de 28, con dos diferencias de
  conteo causadas por 14 cuentas de prueba creadas después de cargar el conjunto de datos (TD-122, ver la sección de datos del guion).

## Entregables de este work item

- [GUION-PRUEBAS-MANUALES.md](GUION-PRUEBAS-MANUALES.md): recorrido en el navegador por rol para la demostración.
- Registro de deuda actualizado: [TECHNICAL_DEBT](../../baseline/TECHNICAL_DEBT.md) (cierres de TD-097, TD-098, TD-102, TD-107 y TD-109; nuevas TD-111 a TD-123).
- Requisitos para un despliegue real: [REQUISITOS_PRODUCCION](../../runbooks/REQUISITOS_PRODUCCION.md).
- Cómo levantar el laboratorio: [PRUEBAS_LOCALES](../../runbooks/PRUEBAS_LOCALES.md).
- Base de regresión del 2026-11-06: [CULM-001-culminacion](../CULM-001-culminacion/) (`SCREEN-TESTS-<rol>.md`).
