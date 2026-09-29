# 🏛️ AsistenciasUCO-Infra — 4ª Capa: Gobernanza, Documentación e Historias de Usuario

> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Propósito:** Capa transversal y única fuente de verdad (SSOT) para la gobernanza, especificación de contratos inmutables (WORM), gestión del ciclo de vida de Historias de Usuario (HU001 – HU174) y work items SDD/TDD.  
> **Versión:** 1.0.0  
> **Fecha:** Septiembre 2026

---

## 1. Visión y Propósito de la 4ª Capa

El ecosistema AsistenciasUCO se compone de 3 capas técnicas de ejecución y 1 capa transversal de gobernanza:

`	ext
┌─────────────────────────────────────────────────────────────────────────────┐
│                       4. AsistenciasUCO-Infra                               │
│  (Gobernanza, Especificaciones WORM, Historias de Usuario & Work Items)     │
│   • SSOT de Contratos OpenAPI, DDL/SPs y Eventos SSE                        │
│   • Trazabilidad de Historias de Usuario (HU001 – HU174)                    │
│   • Work Items SDD/TDD unificados (PLAN, CONTRACT, TEST_PLAN, VALIDATION)   │
│   • Orquestación de infraestructura Docker y automatización                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Rige y gobierna a:
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│ 1. Base de Datos │          │    2. Backend    │          │   3. Frontend    │
│  (SQL Server)    │          │  (Spring Boot)   │          │   (Angular 19)   │
└──────────────────┘          └──────────────────┘          └──────────────────┘
`

Al centralizar la documentación en AsistenciasUCO-Infra, evitamos la dispersión de especificaciones dentro de subcarpetas técnicas del Backend o Frontend y garantizamos que cada cambio funcional responda a un requerimiento formalmente congelado.

---

## 2. Estructura de Directorios

`	ext
AsistenciasUCO-Infra/
├── docs/
│   ├── governance/            # Reglas de negocio, arquitectura y constitución técnica
│   │   ├── CONSTITUTION.md    # Ley suprema del proyecto (Clean Architecture, SDD)
│   │   ├── SOURCE_OF_TRUTH.md # Precedencia de fuentes de verdad
│   │   └── API_DESIGN_RULES.md# Estándares HTTP, errores y paginación
│   ├── contracts/             # Contratos públicos WORM (Write Once, Read Many)
│   │   ├── openapi/           # Especificación formal OpenAPI 3.0 / YAML
│   │   ├── db/                # Firmas de Stored Procedures, Vistas y Esquemas
│   │   └── events/            # Contratos de eventos en tiempo real (SSE)
│   ├── user-stories/          # Catálogo maestro de Historias de Usuario (HU001 - HU174)
│   │   ├── HU-CATALOG.md      # Matriz integral de estado por capas
│   │   └── modules/           # Fichas técnicas detalladas por módulo (Estudiante, Docente...)
│   └── work-items/            # Pipeline SDD/TDD unificado por Historia de Usuario
│       └── HUxxx-nombre/      # Carpeta por HU con sus 5 artefactos estándar
│           ├── PLAN.md
│           ├── CONTRACT.md
│           ├── TEST_PLAN.md
│           ├── VALIDATION.md
│           └── CLOSURE.md
└── README.md                  # Este documento
`

---

## 3. Flujo Operativo para Nuevas Historias de Usuario

Cuando se aborde una nueva Historia de Usuario:

1. **Selección:** Se toma la historia desde docs/user-stories/HU-CATALOG.md.
2. **Apertura de Work Item:** Se crea la carpeta en docs/work-items/HUxxx-descripcion/ con la plantilla canónica:
   - PLAN.md: Análisis AS-IS vs TARGET, alcance y Definition of Ready.
   - CONTRACT.md: Congelamiento de SPs y Endpoints OpenAPI con firmas .sha256.
   - TEST_PLAN.md: Derivación de pruebas RED (Base de Datos, Backend y Frontend).
   - VALIDATION.md: Comandos ejecutados, salidas de Quality Gates y cobertura.
   - CLOSURE.md: Dictamen final y actualización del catálogo general a [CERTIFICADA].
