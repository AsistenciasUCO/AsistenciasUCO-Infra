# Arquitectura Backend: Reactividad Nativa y Server-Sent Events (SSE)
> **Constitución Técnica:** [`.specify/memory/constitution.md`](file:///.specify/memory/constitution.md) (Artículo I, Sección 1.04)  
> **Ámbito:** Backend Spring Boot 4 / Java 25 & Frontend Angular 18/19  
> **Estado:** Implementado (Provider: `local-sse` vía Project Reactor)

---

## Índice
* [1. Principio Rector: Cero Polling](#1-principio-rector-cero-polling)
* [2. Topología del Subsistema Reactivo](#2-topología-del-subsistema-reactivo)
* [3. Especificación de Endpoints](#3-especificación-de-endpoints)
  * [GET /api/v1/realtime/stream](#31-get-apiv1realtimestream)
  * [GET /api/v1/realtime/status](#32-get-apiv1realtimestatus)
  * [POST /api/v1/realtime/emit](#33-post-apiv1realtimeemit)
* [4. Contrato de Integración en Application](#4-contrato-de-integración-en-application)
* [5. Catálogo de Tópicos y Acciones](#5-catálogo-de-tópicos-y-acciones)
* [6. Verificación y Smoke Testing](#6-verificación-y-smoke-testing)
* [7. Restricciones y Evolución Técnica](#7-restricciones-y-evolución-técnica)
* [Documentos Relacionados](#documentos-relacionados)

---

## 1. Principio Rector: Cero Polling

Queda **estrictamente prohibido simular reactividad mediante sondeos periódicos** (como timers de JavaScript `setInterval` o peticiones recurrentes cada 3 o 5 segundos en el cliente). 

El sistema implementa una **arquitectura reactiva orientada a eventos push** mediante **Server-Sent Events (SSE)** sobre HTTP continuo (`text/event-stream`).

---

## 2. Topología del Subsistema Reactivo

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ APPLICATION LAYER (GestioAsistenciaBackend)                                │
│   Caso de Uso (ej. RegistrarAsistenciaUseCaseImpl)                          │
│     │                                                                       │
│     ▼                                                                       │
│   RealtimePublisherPort.java (Puerto Secundario Neutral)                   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ RealtimeEvent.of(topic, action, payload)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ INFRASTRUCTURE LAYER                                                        │
│   ReactorRealtimeAdapter.java (Composition Root: app.adapters.realtime=local-sse)
│     ├── Sinks.Many<RealtimeEvent> (multicast().directBestEffort())          │
│     └── Enriquecimiento con CorrelationIdContext y TraceContextSnapshot    │
│                                                                             │
│   RealtimeEventsController.java                                             │
│     ├── GET  /api/v1/realtime/stream ──► Flux<ServerSentEvent<T>>           │
│     ├── GET  /api/v1/realtime/status ──► Diagnóstico de suscriptores         │
│     └── POST /api/v1/realtime/emit   ──► Utilidad Admin de diagnóstico      │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Eventos Push HTTP text/event-stream
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ CLIENTE WEB (GestioAsistenciaFrontend - Angular 18/19)                     │
│   ├── @microsoft/fetch-event-source (Consumo autenticado con Bearer JWT)   │
│   └── Angular Signals (Mutación atómica en memoria; cero polling)           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Especificación de Endpoints

### 3.1 `GET /api/v1/realtime/stream`
* **Content-Type:** `text/event-stream`
* **Seguridad:** Requiere cabecera `Authorization: Bearer <token_jwt>`. Prohibido pasar tokens por URL (`?token=...`).
* **Heartbeat:** Emite comentarios `:heartbeat` cada 25 segundos para mantener activo el socket contra proxies/intermediarios sin afectar contadores de métricas.
* **Formato de Salida:**
  ```text
  id: 6ba7b810-9dad-11d1-80b4-00c04fd430c8
  event: ASISTENCIA_REGISTRADA
  data: {"eventId":"...","type":"ASISTENCIA_REGISTRADA","occurredAt":"2026-09-17T20:00:00Z","correlationId":"...","payload":{...}}
  ```

### 3.2 `GET /api/v1/realtime/status`
* **Seguridad:** Requiere autenticación.
* **Respuesta:**
  ```json
  {
    "exitoso": true,
    "datos": {
      "activeSubscribers": 4,
      "status": "ONLINE"
    }
  }
  ```

### 3.3 `POST /api/v1/realtime/emit`
* **Seguridad:** Restringido exclusivamente al rol `ADMINISTRADOR`.
* **Propósito:** Diagnóstico y pruebas de humo en desarrollo; no constituye el flujo productivo de negocio.

---

## 4. Contrato de Integración en Application

El núcleo del negocio permanece completamente neutral a la tecnología de transporte (no importa `reactor`, `Flux` ni `SseEmitter`):

```java
// application.secondaryports.realtime.RealtimePublisherPort
public interface RealtimePublisherPort {
    void publish(RealtimeEvent event);
}
```

### Invocación Transaccional desde Casos de Uso
La publicación es estrictamente **secundaria y best-effort**. Se ejecuta solo tras una persistencia exitosa en SQL Server; una falla en la emisión SSE jamás revierte una transacción de base de datos ya comprometida:

```java
@Service
public class RegistrarAsistenciaUseCaseImpl implements RegistrarAsistenciaInputPort {
    private final AsistenciaRepositoryPort repositoryPort;
    private final RealtimePublisherPort realtimePort;

    @Override
    public RegistrarAsistenciaDTO ejecutar(final RegistrarAsistenciaDTO dto, final UUID correlationId) {
        // 1. Persistencia transaccional ACID en SQL Server
        final RegistrarAsistenciaDTO resultado = repositoryPort.registrarAsistencia(dto, correlationId);

        // 2. Notificación push reactiva best-effort
        realtimePort.publish(RealtimeEvent.of("ASISTENCIA", "ASISTENCIA_REGISTRADA", Map.of(
            "idSesion", dto.getIdGrupoSesion(),
            "idEstudianteGrupo", dto.getIdEstudianteGrupo(),
            "idEstadoAsistencia", dto.getIdEstadoAsistencia()
        )));

        return resultado;
    }
}
```

---

## 5. Catálogo de Tópicos y Acciones

| Tópico (`topic`) | Acción (`action`) | Disparador de Negocio | Impacto en Cliente Angular |
| :--- | :--- | :--- | :--- |
| `ASISTENCIA` | `ASISTENCIA_REGISTRADA` | Docente registra o modifica estado de asistencia. | Actualiza la lista reactiva de la sesión y el resumen computado. |
| `SESION` | `SESION_CREADA` | Docente programa sesión regular o extraordinaria. | Actualiza el calendario del estudiante y docente. |
| `SESION` | `SESION_CERRADA` | Docente finaliza la toma de asistencia. | Bloquea edición y consolida porcentaje de ausencias. |
| `JUSTIFICACION` | `RECLAMO_RADICADO` | Estudiante radica justificación con adjunto. | Incrementa contador en bandeja de pendientes del docente. |
| `JUSTIFICACION` | `RECLAMO_RESUELTO` | Docente o coordinador aprueba/rechaza justificación. | Actualiza estado de reclamo en vista del estudiante. |

---

## 6. Verificación y Smoke Testing

Para verificar el transporte reactivo y el handshake SSE sin interfaz gráfica:

```powershell
cd GestioAsistenciaFrontend
$env:API_URL="http://localhost:8080/api/v1"
$env:E2E_ACCESS_TOKEN="<token_jwt_keycloak>"
node scripts/realtime-smoke.mjs
```

---

## 7. Restricciones y Evolución Técnica

1. **Sin Replay Histórico:** La implementación `local-sse` es efímera y best-effort en memoria de una única instancia JVM. No almacena eventos para clientes desconectados; el frontend debe rehidratar su estado consultando los endpoints REST tras una reconexión.
2. **Escalabilidad Horizontal:** La distribución de eventos entre múltiples nodos del backend se delegará en una fase posterior a un broker de mensajería distribuido (**RabbitMQ**) conectado a través de `EventPublisherPort`.

---
**Documentos Relacionados:**
* [Especificación Backend Realtime](../GestioAsistenciaBackend/docs/architecture/reactive-realtime.md) - Decisiones de Project Reactor y `Sinks.Many`.
* [Stack Tecnológico](./stack-tecnologico.md) - Componentes y versiones de la plataforma.
* [Guía de Integración Frontend-Realtime](../GestioAsistenciaFrontend/docs/frontend-realtime.md) - Cliente Angular y consumo con Signals.
