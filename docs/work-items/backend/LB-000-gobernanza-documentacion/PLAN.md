---
status: active
type: work-item
scope: backend
owner: backend-team
last-reviewed: 2026-09-20
---

# PLAN — LB-000: gobernanza y documentación

- Fecha: 2026-09-20. Base: `fa9aa901c73e55ae31071f4e74cfb2245189243a`.
- Autor: agente de consolidación, a solicitud explícita del usuario. Skill auxiliar usada: skill-creator; las skills UCO resultantes gobiernan trabajo futuro.
- Objetivo: repositorio autocontenido con autoridad documental, routers, evidencia y trazabilidad.

## AS-IS

Solo el paquete de gobernanza anidado estaba sin seguimiento. No había AGENTS/CLAUDE raíz; `.claude` contenía worktrees locales. Documentación técnica útil en docs/architecture, security, integration y testing; CI y config existentes. Inventario previo completo: [INVENTORY](INVENTORY.md).

## TARGET y alcance

Una entrada AGENTS, CLAUDE adaptador, seis funciones de agente, ocho skills router, seis plantillas, jerarquía docs indexada, una DoR/DoD/LINEA_BASE/TECHNICAL_DEBT, work items versionables y paquete retirado tras fusión. Mantener documentos técnicos buenos; corregir hechos comprobables y archivar historia. Agregar exclusivamente ignores del estado local de Claude.

## No alcance

Cero cambios en src/main, src/test, Java, pom.xml, Spring/YAML runtime, SQL, frontend, workflows, contratos funcionales, JPA/OpenAPI/WebSocket/Redis/Azure/serverless o historias. No commits, PR, despliegues, cambios DB/IdP ni rotación de secretos. No empezar LB-001.

## Fuentes, archivos y contratos afectados

Solicitud LB-000 del usuario, contenido original inventariado y evidencia de código/config/tests. [SOURCE_OF_TRUTH](../../governance/SOURCE_OF_TRUTH.md) registra precedencia. Archivos existentes/destinos: INVENTORY; nuevos y cambios finales: [REPORT](REPORT.md). No hay cambio contractual funcional; se documentan límites del AS-IS.

Consumidores: futuros agentes y mantenedores. Frontend/DB externos no están disponibles; su falta bloquea la formalización futura, no la reorganización documental. Hallazgos con alcance en [FINDINGS](FINDINGS.md).

## Riesgos y dependencias

- Perder información al consolidar: inventario previo, hashes, preservar historia útil y trasladar deudas a IDs estables antes de retirar pack.
- Convertir propuesta en AS-IS: separar normativa/estado/historia y enlazar fuentes.
- Mover worktrees: excluir su contenido de lectura documental/mutaciones y comprobar Git ignore/índice.
- Confundir build previo fallido con regresión: ejecutar verify previo/final y comparar sin cambiar Java.
- Dependencias Maven: JDK 25 instalado; primer acceso a Central restringido requiere reintento autorizado.

## Test plan

[TEST_PLAN](TEST_PLAN.md): validación documental y de alcance; RED Java NO APLICA, pues no hay comportamiento nuevo. Maven verify para comprobar estado previo/final.

## Rollback

Antes de commit, revertir solo los Markdown y las nueve reglas .gitignore de este trabajo revisando el inventario/diff. El pack original no estaba versionado: se conserva snapshot local de los documentos originales durante la tarea para recuperación; su contenido vigente queda en destinos versionables y prompts históricos en archive. No usar reset global, no tocar código/estado local ni borrar worktrees. Una vez commitido, revertir el commit documental con revisión.

## Stop conditions y deuda

No decidir CF-001/CF-002 ni información externa faltante; completar trabajo independiente. Referencias a TD/MV en FINDINGS. El fallo real de arquitectura impide DONE integral; no cambiar test ni implementación para ocultarlo.

## Definition of Ready

**READY para consolidación documental exclusivamente**, autorizado por la solicitud. Alcance, no alcance, inventario, consumidores documentales, riesgos, pruebas y rollback definidos. Los contratos funcionales no se alteran. NOT_READY para implementación de LB-001/002; ese trabajo no se inicia.
