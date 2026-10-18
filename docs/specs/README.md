# Índice Maestro de Especificaciones Técnicas (Specs) — GestioAsistencia UCO
> **Metodología:** Spec-Driven Development (SDD) & Clean Architecture  
> **Constitución Suprema:** [`.specify/memory/constitution.md`](file:///.specify/memory/constitution.md)

---

## Índice
* [1. Flujo de Trabajo Tripartito (SDD)](#1-flujo-de-trabajo-tripartito-sdd)
* [2. Catálogo de Especificaciones del Sistema](#2-catálogo-de-especificaciones-del-sistema)
* [3. Estructura Canónica de Cada Especificación](#3-estructura-canónica-de-cada-especificación)
* [4. Protocolo de Derivación e Implementación](#4-protocolo-de-derivación-e-implementación)
* [Documentos Relacionados](#documentos-relacionados)

---

## 1. Flujo de Trabajo Tripartito (SDD)

Cada funcionalidad se descompone en tres artefactos complementarios con fronteras de responsabilidad estrictas:

```text
┌────────────────────────────────┐
│           spec.md              │  ¿QUÉ debe hacer el sistema?
│  (Lenguaje Ubicuo, Reglas de   │  • Invariantes institucionales UCO.
│   Negocio y Criterios Gherkin) │  • Criterios de aceptación BDD (Dado / Cuando / Entonces).
└───────────────┬────────────────┘  • Contratos funcionales observables.
                │
                │ Derivación Técnica
                ▼
┌────────────────────────────────┐
│           plan.md              │  ¿CÓMO se construye técnicamente?
│  (Arquitectura por Capas y     │  • Puertos y Adaptadores (Clean Architecture).
│   Diseño Detallado de Código)  │  • Stored Procedures transaccionales en SQL Server.
└───────────────┬────────────────┘  • Componentes Standalone y Signals en Angular.
                │
                │ Desglose Accionable
                ▼
┌────────────────────────────────┐
│           tasks.md             │  ¿En qué ORDEN se ejecuta?
│  (Checklist Atómico de Fases   │  • Tareas secuenciales: DB ➔ Backend ➔ Frontend.
│   y Quality Gates de Pruebas)  │  • Verificación en 4 capas con 0 errores de build.
└────────────────────────────────┘
```

---

## 2. Catálogo de Especificaciones del Sistema

| ID / Directorio | Historia | Título | Rol Actor | Estado | Documentos |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **`001-registro-asistencia-estudiante`** | `HU027` | Registro de Asistencia a Sesión de Clase | `Docente` | `COMPLETADA` | [spec](001-registro-asistencia-estudiante/spec.md) · [plan](001-registro-asistencia-estudiante/plan.md) · [tasks](001-registro-asistencia-estudiante/tasks.md) |
| **`002-radicacion-justificaciones-asistencia`** | `HU010`, `HU014` | Radicación y Revisión de Justificación Médica | `Estudiante` | `COMPLETADA` | [spec](002-radicacion-justificaciones-asistencia/spec.md) · [plan](002-radicacion-justificaciones-asistencia/plan.md) · [tasks](002-radicacion-justificaciones-asistencia/tasks.md) |
| **`_template`** | N/A | Plantilla Oficial Canónica | Todos | `PLANTILLA` | [spec](_template/spec.md) · [plan](_template/plan.md) · [tasks](_template/tasks.md) |

---

## 3. Estructura Canónica de Cada Especificación

Toda especificación reside en una carpeta normalizada `[NUM_3_DIGITOS]-[nombre-kebab-case]` con sus 3 artefactos:

```text
docs/specs/
├── README.md                                          # Este índice maestro
├── _template/                                         # Plantilla desacoplada
│   ├── spec.md                                        # Requerimientos funcionales
│   ├── plan.md                                        # Diseño técnico por capas
│   └── tasks.md                                       # Checklist de tareas
├── 001-registro-asistencia-estudiante/                # SPEC-001 (HU027)
└── 002-radicacion-justificaciones-asistencia/          # SPEC-002 (HU010, HU014)
```

---

## 4. Protocolo de Derivación e Implementación

1. **Crear `spec.md`:** Duplicar la plantilla `_template/` con el correlativo correspondiente. Redactar el negocio con Lenguaje Ubicuo y criterios Gherkin.
2. **Generar `plan.md`:** Derivar la arquitectura técnica:
   * **SQL Server:** SP con `SET XACT_ABORT ON;` y salida uniforme (`idResultado`, `exitoso`, `mensajeUsuario`, `mensajeTecnico`).
   * **Backend:** Flujo canónico `PrimaryPort` ➔ `UseCaseImpl` ➔ `SecondaryPort` ➔ `*RepositorySqlServerAdapter`.
   * **Frontend:** Standalone Component con `ChangeDetectionStrategy.OnPush` y Signals nativas.
3. **Generar `tasks.md`:** Crear checklist de ejecución (Fase 1: DB, Fase 2: Backend, Fase 3: Frontend, Fase 4: Pruebas).
4. **Ejecutar y Validar:** Marcar tareas `[x]` garantizando 0 errores en `mvnw test` y `npm run build`.

---
**Documentos Relacionados:**
* [Centro Maestro de Documentación](../README.md) - Mapa global de documentación.
* [Catálogo de Historias de Usuario](../historias-de-usuario.md) - Requerimientos funcionales HU001 a HU174.
* [Guía Operativa y Reglas de Construcción](../../AGENTS.md) - Estándares de desarrollo y pruebas.
