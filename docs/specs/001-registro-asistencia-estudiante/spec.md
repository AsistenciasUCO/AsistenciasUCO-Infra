# Especificación Funcional: Registro de Asistencia de Estudiante a Clase
> **ID:** `SPEC-001` | **Historia:** [`HU027`](../../historias-de-usuario.md#L55) | **Rol:** `Docente` | **Estado:** `COMPLETADA`  
> **Constitución Técnica:** [`.specify/memory/constitution.md`](file:///.specify/memory/constitution.md)

---

## Índice
* [1. Contexto de Negocio](#1-contexto-de-negocio)
* [2. Lenguaje Ubicuo (DDD)](#2-lenguaje-ubicuo-ddd)
* [3. Invariantes y Reglas de Negocio](#3-invariantes-y-reglas-de-negocio)
* [4. Criterios de Aceptación (Gherkin)](#4-criterios-de-aceptación-gherkin)
* [5. Contrato Funcional de Intercambio](#5-contrato-funcional-de-intercambio)
* [6. Casos Límite y Excepciones](#6-casos-límite-y-excepciones)
* [Documentos Relacionados](#documentos-relacionados)

---

## 1. Contexto de Negocio

Control del límite institucional de fallas (pérdida por inasistencia al acumular 20% de faltas injustificadas). Permite al **Docente Titular** asentar o actualizar el estado de presencia de cada **Estudiante Matriculado** en una **Sesión de Clase**, reflejándose reactivamente vía SSE.

---

## 2. Lenguaje Ubicuo (DDD)

| Término | Definición en el Dominio UCO |
| :--- | :--- |
| **Docente Titular** | Profesor asignado a la cátedra con potestad legal para abrir sesiones y asentar asistencia. |
| **Sesión de Clase** | Franja horaria formal (ordinaria o extraordinaria) de un grupo académico. |
| **Estudiante Matriculado** | Alumno con registro `EstudianteGrupo` activo en el período en curso. |
| **Estado de Asistencia** | Condición formal: `PRESENTE`, `FALTA`, `JUSTIFICADA` o `RETARDO`. |
| **Registro de Asistencia** | Tupla transaccional que vincula al estudiante con la sesión y su estado. |

---

## 3. Invariantes y Reglas de Negocio

1. **RN-01 (Titularidad Exclusiva):** Solo el docente asignado puede asentar o modificar asistencia en la sesión.
2. **RN-02 (Matrícula Activa):** El estudiante debe registrar matrícula activa previa en `EstudianteGrupo`.
3. **RN-03 (Catálogo Válido):** Estado restringido a valores de catálogo (`PRESENTE`, `FALTA`, `JUSTIFICADA`, `RETARDO`).
4. **RN-04 (Upsert Idempotente):** Re-asentar asistencia sobre el mismo alumno en la sesión actualiza el estado sin duplicar registros.
5. **RN-05 (Notificación Push SSE):** Todo asentamiento emite evento al broker SSE para actualización de interfaces sin sondeos.

---

## 4. Criterios de Aceptación (Gherkin)

```gherkin
Escenario: Registro exitoso de asistencia por el docente titular
  Dado que el docente titular "Maria Rostagno" está autenticado
  Y se encuentra en el control de asistencia del grupo "ARQ-402-01" con sesión activa
  Cuando marca al estudiante "Carlos Zapata" con estado "PRESENTE"
  Entonces el sistema registra la asistencia con HTTP 200
  Y el resumen computado de presentes se incrementa en 1
  Y se emite el evento SSE "ASISTENCIA_REGISTRADA" al canal reactivo.

Escenario: Docente intenta registrar asistencia en grupo ajeno
  Dado que un docente intenta registrar asistencia en un grupo no asignado
  Cuando envía la solicitud de registro
  Entonces el sistema responde con error 403 de jurisdicción académica
  Y la asistencia de la sesión no sufre modificaciones.

Escenario: Registro sobre estudiante sin matrícula activa
  Dado que se intenta asentar asistencia a un estudiante no matriculado en el grupo
  Cuando se procesa la solicitud
  Entonces el sistema rechaza la operación con código de validación de negocio.
```

---

## 5. Contrato Funcional de Intercambio

### 5.1 Datos de Entrada
| Campo | Tipo | Requerido | Descripción |
| :--- | :--- | :---: | :--- |
| `idEstudianteGrupo` | UUID | Sí | Matrícula activa del estudiante en el curso. |
| `idGrupoSesion` | UUID | Sí | Identificador de la sesión de clase. |
| `idEstadoAsistencia` | UUID | Sí | GUID del estado en catálogo (`cat_detalle`). |

### 5.2 Datos de Salida
| Campo | Tipo | Significado de Negocio |
| :--- | :--- | :--- |
| `idRegistro` | UUID | Identificador de la asistencia asentada. |
| `exitoso` | Booleano | Confirmación determinística de persistencia. |
| `mensajeUsuario` | Texto | "Asistencia registrada exitosamente." |
| `fechaRegistro` | Timestamp | Marca temporal de la transacción. |

---

## 6. Casos Límite y Excepciones

* **C-01 (Concurrencia):** Bloqueo transaccional `WITH (UPDLOCK, HOLDLOCK)` para prevenir condiciones de carrera entre registro docente y lectores QR simultáneos.
* **C-02 (Sesión Cerrada):** Sesión finalizada bloquea modificaciones directas; cualquier alteración posterior requiere solicitud ante Coordinación.

---
**Documentos Relacionados:**
* [Plan Técnico SPEC-001](./plan.md) - Diseño de SPs, puertos y componentes.
* [Checklist de Tareas SPEC-001](./tasks.md) - Fases de implementación y verificación.
* [Índice Maestro de Especificaciones](../README.md) - Catálogo general de specs.
