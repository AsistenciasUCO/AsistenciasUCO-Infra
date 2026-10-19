---
status: active
type: normative
scope: infra-validation
owner: infra-team
last-reviewed: 2026-10-18
---

# P0-D — Validación del workspace oficial Infra

## Objetivo

Verificar la naturaleza actual del repositorio Infra y dejar una señal CI
reproducible sin inventar infraestructura ejecutable ni iniciar despliegues.

## Evidencia AS-IS

La revisión de origin/develop en 6ae52da contiene documentación/gobernanza y
artefactos runtime versionados: docker-compose.yml, components/, scripts/ e
infra.ps1. También contiene componentes de Keycloak, SQL Server, observabilidad,
proxy y seguridad. Esta enumeración es evidencia AS-IS, no autorización de
ejecución.

## Alcance

Permitido: un workflow de inspección sin despliegue y este work item.

Prohibido: crear manifests o servicios por inferencia, iniciar recursos,
cambiar configuración de nube, tocar secretos, push, merge o modificar el
default branch.

## DoR

READY_FOR_CONTENT_VALIDATION: sí.

READY_FOR_RUNTIME_DEPLOYMENT: no; aunque existen artefactos runtime, esta fase
no tiene decisión de owner ni evidencia de validación controlada.

## Dictamen previsto

INFRA_CI: PASS para inspección de contenido cuando el workflow remoto ejecute.

RUNTIME_VALIDATION: BLOCKED_BY_OWNER_REVIEW hasta validar los artefactos
runtime existentes en una fase autorizada.
