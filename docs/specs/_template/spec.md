# 📋 Especificación Funcional: [Nombre de la Funcionalidad]

> **Documento:** `docs/specs/_template/spec.md`  
> **ID:** `SPEC-[NUMERO]-[nombre-kebab-case]`  
> **Historia de Usuario:** [HUXXX - Título](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)  
> **Actor / Rol:** `Estudiante` | `Docente` | `Coordinador` | `Decano` | `Administrador`  
> **Plan:** [`plan.md`](plan.md) | **Tareas:** [`tasks.md`](tasks.md)  
> **Estado:** `[BORRADOR]` | `[APROBADA]`

---

## Índice de Contenidos
1. [Contexto de Negocio y Propósito](#1-contexto-de-negocio-y-propsito)
2. [Glosario de Lenguaje Ubicuo](#2-glosario-de-lenguaje-ubicuo-domain-driven-design)
3. [Reglas de Negocio Institucionales](#3-reglas-de-negocio-institucionales-invariantes-del-negocio)
4. [Criterios de Aceptación (BDD / Gherkin)](#4-criterios-de-aceptacin-formato-bdd--gherkin)
5. [Contrato Funcional de Intercambio](#5-contrato-funcional-de-intercambio-entradas-y-salidas-observables)
6. [Casos Límite y Condiciones de Excepción](#6-casos-lmite-y-condiciones-de-excepcin-edge-cases)
7. [Documentos Relacionados](#7-documentos-relacionados)

---

## 1. Contexto de Negocio y Propósito

*Describir la necesidad institucional en el contexto de la Universidad Católica de Oriente (UCO). ¿Qué problema resuelve para el actor? ¿Cuál es el impacto institucional de esta funcionalidad?*

---

## 2. Glosario de Lenguaje Ubicuo (Domain-Driven Design)

| Término Institucional | Definición en el Dominio |
| :--- | :--- |
| **[Término 1, ej. Sesión de Clase]** | Espacio temporal formalmente programado o ejecutado donde se imparte una asignatura a un grupo académico. |
| **[Término 2, ej. Falta Injustificada]** | Inasistencia registrada a una sesión de clase que computa hacia el límite institucional de pérdida del 20%. |
| **[Término 3, ej. Excusa Médica]** | Solicitud formal radicada por un estudiante adjuntando certificado de salud para exonerar una inasistencia. |
| **[Término 4, ej. Docente Titular]** | Docente que posee asignación académica oficial y jurisdicción sobre el grupo. |

---

## 3. Reglas de Negocio Institucionales (Invariantes del Negocio)

1. **RN-01 [Nombre de Regla]:** [Descripción clara e imperativa de la regla de negocio institucional].
2. **RN-02 [Control de Plazos / Restricciones]:** [Ej. El estudiante tiene máximo 5 días hábiles posteriores a la sesión para radicar justificaciones].
3. **RN-03 [Jurisdicción de Actor]:** [Ej. Solo el docente titular del grupo puede modificar la asistencia].
4. **RN-04 [Estado y Transiciones]:** [Estados válidos de la entidad y transiciones permitidas].

---

## 4. Criterios de Aceptación (Formato BDD / Gherkin)

```gherkin
Escenario: [Flujo principal exitoso - Happy Path]
  Dado que un usuario con rol "[ROL]" se encuentra autenticado en el sistema
  Y cumple con [condición previa del negocio]
  Cuando realiza la acción de [descripción de la acción]
  Entonces el sistema confirma la operación con código HTTP [200/201]
  Y el resultado refleja [resultado observable en el negocio]
  Y los participantes interesados son notificados en tiempo real.

Escenario: [Flujo alternativo o validación de regla de negocio]
  Dado que [condición que incumple una regla de negocio]
  Cuando el usuario intenta [acción no permitida]
  Entonces el sistema rechaza la operación con código HTTP [400/403/404/409]
  Y presenta un mensaje amigable y seguro explicando el motivo del rechazo.
```

---

## 5. Contrato Funcional de Intercambio (Entradas y Salidas Observables)

### 5.1 Datos de Entrada (Lo que el actor o cliente envía)
| Campo Funcional | Tipo de Dato | Obligatorio | Validación de Negocio |
| :--- | :--- | :---: | :--- |
| `idRecurso` | UUID | Sí | Debe existir y pertenecer al ámbito del usuario. |
| `motivo` | Texto | Sí | Longitud mínima 10 caracteres, máxima 500. |
| `soporteUrl` | URL | No | Formato válido de enlace a documento PDF/imagen. |

### 5.2 Datos de Salida (Lo que el actor o cliente recibe)
| Campo Funcional | Tipo de Dato | Significado para el Negocio |
| :--- | :--- | :--- |
| `idOperacion` | UUID | Identificador único del registro generado. |
| `estado` | Texto | Estado institucional resultante (ej. `REGISTRADO`, `PENDIENTE`). |
| `mensajeUsuario` | Texto | Mensaje confirmatorio legible para el usuario. |

---

## 6. Casos Límite y Condiciones de Excepción (Edge Cases)

- **C-01 [Concurrencia]:** ¿Qué ocurre si dos usuarios intentan operar sobre la misma entidad simultáneamente?
- **C-02 [Extemporaneidad]:** ¿Qué ocurre si la solicitud se envía fuera del calendario académico o periodo activo?
- **C-03 [Datos Incompletos]:** ¿Qué respuesta recibe el usuario si un dato obligatorio viene ausente o con formato inválido?

---

## 7. Documentos Relacionados
- [Plan Técnico de Arquitectura (plan.md)](plan.md)
- [Desglose de Tareas (tasks.md)](tasks.md)
- [Catálogo Maestro de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
- [Arquitectura Integral](file:///c:/Proyectos/GestioAsistencia/docs/arquitectura-integral.md)
