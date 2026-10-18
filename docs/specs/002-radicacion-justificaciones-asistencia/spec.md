# 📋 Especificación Funcional: Radicación de Justificación de Asistencia

> **Documento:** `docs/specs/002-radicacion-justificaciones-asistencia/spec.md`  
> **ID:** `SPEC-002-radicacion-justificaciones-asistencia`  
> **Historias Asociadas:** [HU010](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md) y [HU014](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md) (Radicación de justificaciones médicas)  
> **Actor / Rol:** `Estudiante` | **Plan:** [`plan.md`](plan.md) | **Tareas:** [`tasks.md`](tasks.md)  
> **Estado:** `[COMPLETADA]`

---

## Índice de Contenidos
1. [Contexto de Negocio y Propósito](#1-contexto-de-negocio-y-propsito)
2. [Glosario de Dominio](#2-glosario-de-dominio)
3. [Reglas de Negocio Institucionales](#3-reglas-de-negocio-institucionales)
4. [Criterios de Aceptación (BDD / Gherkin)](#4-criterios-de-aceptacin-bdd--gherkin)
5. [Contrato Funcional de Intercambio](#5-contrato-funcional-de-intercambio)
6. [Casos Límite y Condiciones de Excepción](#6-casos-lmite-y-condiciones-de-excepcin)
7. [Documentos Relacionados](#7-documentos-relacionados)

---

## 1. Contexto de Negocio y Propósito

El reglamento académico de la Universidad Católica de Oriente (UCO) contempla que ante una inasistencia originada por fuerza mayor, calamidad doméstica o condición médica certificada por una entidad de salud reconocida, el estudiante tiene derecho a radicar una **Solicitud de Justificación o Revisión de Asistencia**.

Esta funcionalidad provee al **Estudiante Matriculado** un mecanismo formal, transparente y digital para radicar su justificación adjuntando soporte documental, notificando en tiempo real al **Docente Titular** y al **Coordinador de Programa** para su evaluación y resolución.

---

## 2. Glosario de Dominio

| Término | Definición en el Dominio |
| :--- | :--- |
| **Solicitud de Justificación** | Trámite formal radicado por un estudiante para solicitar que una falta sea exonerada del cómputo de pérdida. |
| **Motivo de Justificación** | Causal normativa institucional tipificada (Médica, Calamidad Doméstica, Representación Institucional UCO, Deber Legal). |
| **Soporte Documental** | Certificado médico, constancia laboral o documento oficial digitalizado que respalda la causal invocada. |
| **Falta Justificada** | Inasistencia exonerada formalmente que no computa hacia el límite del 20% institucional. |
| **Estado de Solicitud** | Ciclo de vida del trámite: `PENDIENTE`, `APROBADA` o `RECHAZADA`. |

---

## 3. Reglas de Negocio Institucionales

- **RN-01 (Inasistencia Previa Obligatoria):** Solo es posible radicar solicitud sobre una sesión donde el estudiante tenga registrada una `FALTA`.
- **RN-02 (Prohibición sobre Asistencia Confirmada):** Queda prohibido radicar justificaciones sobre sesiones donde el estudiante figure con estado `PRESENTE`.
- **RN-03 (Unicidad de Solicitud):** No se permite más de una solicitud simultánea en estado `PENDIENTE` sobre la misma sesión.
- **RN-04 (Soporte Obligatorio para Causal Médica):** Las solicitudes de causal médica requieren obligatoriamente adjuntar el enlace al soporte documental digitalizado emitido por la EPS o entidad de salud.
- **RN-05 (Notificación al Docente):** Toda nueva solicitud genera una alerta inmediata en tiempo real al docente titular del grupo vía SSE.

---

## 4. Criterios de Aceptación (BDD / Gherkin)

```gherkin
Escenario: Radicación exitosa de justificación médica por el estudiante
  Dado que el estudiante "Carlos Zapata" se encuentra autenticado en el portal
  Y posee una inasistencia registrada en la sesión de "Arquitectura de Software"
  Cuando completa el formulario con motivo "Médico", descripción de la incapacidad y adjunta el certificado
  Entonces el sistema confirma la radicación asignando estado "PENDIENTE"
  Y emite una notificación en tiempo real al docente titular del curso
  Y la interfaz del estudiante muestra el estado de la falta como "En Revisión".

Escenario: Intento de radicación sobre una sesión donde el estudiante asistió
  Dado que el estudiante intenta justificar una sesión donde figura con estado "PRESENTE"
  Cuando envía la solicitud
  Entonces el sistema rechaza la operación con código de conflicto
  Y muestra un mensaje explicando que no se pueden radicar justificaciones sobre sesiones con asistencia confirmada.

Escenario: Intento de radicación de justificación médica sin soporte documental
  Dado que el estudiante selecciona causal "Médica" pero no adjunta el soporte
  Cuando intenta radicar
  Entonces el sistema bloquea el envío indicando que el certificado médico es obligatorio.
```

---

## 5. Contrato Funcional de Intercambio

### 5.1 Datos de Entrada
| Campo Funcional | Tipo de Dato | Obligatorio | Descripción |
| :--- | :--- | :---: | :--- |
| `idRegistroAsistencia` | UUID | Sí | Identificador de la inasistencia a justificar. |
| `idMotivoJustificacion`| UUID | Sí | Identificador de la causal normativa institucional. |
| `descripcion` | Texto | Sí | Explicación detallada de la causal (mín. 10, máx. 1000 caracteres). |
| `soporteUrl` | URL | Condicional | Obligatorio si el motivo es médico; enlace al documento digitalizado. |

### 5.2 Datos de Salida
| Campo Funcional | Tipo de Dato | Significado para el Negocio |
| :--- | :--- | :--- |
| `idRadicado` | UUID | Identificador único del trámite de revisión generado. |
| `estado` | Texto | Estado institucional inicial (`PENDIENTE`). |
| `fechaRadicacion` | Fecha/Hora | Marca temporal formal de radicación ante la universidad. |
| `mensajeUsuario` | Texto | "Solicitud de revisión radicada exitosamente." |

---

## 6. Casos Límite y Condiciones de Excepción

- **C-01 (Inasistencia Inexistente):** Si el registro no existe o no corresponde al estudiante autenticado, se rechaza por falta de jurisdicción académica.
- **C-02 (Cierre de Periodo Académico):** Si el periodo académico fue cerrado, se bloquea la radicación de nuevas solicitudes.

---

## 7. Documentos Relacionados
- [Plan Técnico de Arquitectura (plan.md)](plan.md)
- [Desglose de Tareas (tasks.md)](tasks.md)
- [Catálogo de Historias de Usuario](file:///c:/Proyectos/GestioAsistencia/docs/historias-de-usuario.md)
- [Sistema de Diseño Aurora](file:///c:/Proyectos/GestioAsistencia/docs/sistema-diseno.md)
