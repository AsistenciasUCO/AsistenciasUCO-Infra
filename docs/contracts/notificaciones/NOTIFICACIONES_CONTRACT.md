---
status: active
type: normative
scope: infra
owner: infra-team
last-reviewed: 2026-11-22
---

# Addendum: contrato del Servicio de Notificaciones UCO (0.1.0)

Este addendum gobierna el contrato HTTP del componente propio **Servicio de Notificaciones UCO**
(`Complementos/Notificaciones`) tal como lo consumen las aplicaciones cliente (hoy, el Backend de Asistencias desde su outbox).
Acompaña a [`openapi-notificaciones.yaml`](openapi-notificaciones.yaml), congelado bajo principio WORM con su
[`.sha256`](openapi-notificaciones.sha256).

## 1. Alcance

- Fuente canónica del componente: `Complementos/Notificaciones/contrato/openapi-notificaciones.yaml` (+ `.sha256`).
  La copia de este directorio es la copia de gobierno de Infra; **deben ser idénticas**. `infra.ps1 verify` (y
  `verify-contracts.ps1`) comprueba la integridad del hash y la paridad byte a byte (normalizada CRLF -> LF) entre ambas.
- Cubre: recepción idempotente de avisos (`POST /api/v1/notificaciones`), cola administrativa y reintento, plantillas
  versionadas (listar, crear versión, activar, vista previa), correo de prueba, estado del canal y salud/métricas.
- No cubre: la resolución de destinatarios (la aplicación cliente entrega los correos ya resueltos), el contenido de negocio de
  cada aviso ni el transporte SMTP (detalle interno del componente).
- Reemplazo: otro servicio que cumpla este contrato puede sustituir al componente cambiando solo la URL y la clave en el
  Backend y la sección `ext-notificaciones` del stack.

## 2. Idempotencia

- `POST /api/v1/notificaciones` exige `aplicacion` e `idempotencyKey`. **Misma `aplicacion` + misma clave = el mismo envío.**
- Clave nueva: `202` con `estado: PENDIENTE` y `duplicada: false`. Clave repetida: `200` con la misma `id`, `duplicada: true`
  y **sin** segundo envío.
- Un `4xx` significa aviso inválido: no se reintenta. Un `5xx` o un tiempo de espera agotado se reintenta **con la misma
  `idempotencyKey`** (con backoff) y nunca genera duplicados.
- El Backend de Asistencias usa como clave el id de su `NotificacionSaliente`.

## 3. Códigos de error

Toda falla responde `{code, message, correlationId}`. El `code` es estable (parte del contrato); el `message` está listo para
mostrar. Códigos vigentes en 0.1.0:

`NO_AUTORIZADO`, `VALIDACION_FALLIDA`, `CUERPO_INVALIDO`, `PARAMETRO_INVALIDO`, `METODO_NO_PERMITIDO`,
`RECURSO_NO_ENCONTRADO`, `ERROR_INTERNO`, `APLICACION_INVALIDA`, `IDEMPOTENCY_KEY_INVALIDA`, `TIPO_NO_SOPORTADO`,
`IDIOMA_INVALIDO`, `DESTINATARIOS_OBLIGATORIOS`, `DESTINATARIOS_EXCEDIDOS`, `DESTINATARIO_INVALIDO`, `DATOS_EXCEDIDOS`,
`DATO_INVALIDO`, `CORRELACION_INVALIDA`, `TRACEPARENT_INVALIDO`, `ASUNTO_INVALIDO`, `MENSAJE_INVALIDO`, `ESTADO_INVALIDO`,
`NOTIFICACION_NO_ENCONTRADA`, `ESTADO_NO_REINTENTABLE`, `TIPO_NO_ENCONTRADO`, `VERSION_NO_ENCONTRADA`,
`PLANTILLA_ASUNTO_INVALIDO`, `PLANTILLA_CUERPO_INVALIDO`, `PLANTILLA_SIN_MARCADORES`,
`PLANTILLA_MARCADOR_OBLIGATORIO_AUSENTE`, `PLANTILLA_MARCADOR_NO_PERMITIDO`, `PLANTILLA_LLAVES_INVALIDAS`.

Estados HTTP: `202` aviso nuevo, `200` duplicado, `201` versión de plantilla creada, `400` validación, `401` sin clave o clave
incorrecta, `404` recurso inexistente, `409` `ESTADO_NO_REINTENTABLE`, `5xx` falla del servicio (reintentable).
Los mensajes de usuario que vea una persona los traduce el Backend (SSOT en el catálogo de mensajes), no la UI.

## 4. Autenticación

- Laboratorio: cabecera `X-Api-Key` (secreto compartido) en todo `/api/v1/**` y en `/actuator/prometheus`.
  `/actuator/health/**` e `info` son abiertas. Sin clave o con clave incorrecta: `401` `NO_AUTORIZADO`.
- El secreto **nunca** se versiona: lo genera `infra.ps1 stack up` en `AsistenciasUCO-Infra/stack/.env`
  (`NOTIFICACIONES_API_KEY`, `NOTIFICACIONES_DB_PASSWORD`; fuera de Git) y llega al Backend por `stack/generado/backend.env`
  como `NOTIFICACIONES_API_KEY` junto con `NOTIFICACIONES_SERVICE_URL`.
- Deuda registrada: migrar a OAuth2 client-credentials cuando Seguridad lo ofrezca para servicios (ver TD-124 en
  `docs/baseline/TECHNICAL_DEBT.md`). Ese cambio será un addendum con hash nuevo.
- Correlación: se acepta y devuelve `X-Correlation-Id` (hasta 64 caracteres `[A-Za-z0-9_.-]`) y se propaga `traceparent`.

## 5. Versionado y evolución

- Versión del contrato: `0.1.0` (campo `info.version` del OpenAPI). Cambios aditivos compatibles (campos opcionales nuevos,
  tipos de plantilla nuevos, códigos de error nuevos) suben la versión menor; cambios incompatibles, la mayor.
- Todo cambio exige: actualizar el OpenAPI en `Complementos/Notificaciones/contrato/`, regenerar su `.sha256`, copiar ambos a
  este directorio, actualizar este addendum y su hash, y ejecutar `.\AsistenciasUCO-Infra\infra.ps1 verify` (cero drift).
- Los tipos de aviso y sus marcadores (22 en 0.1.0) los publica `GET /api/v1/plantillas`; los clientes no los quedan quemados:
  consumen la lista del servicio.
