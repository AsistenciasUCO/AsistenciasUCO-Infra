---
status: active
type: normative
scope: transversal-http-api
owner: architecture-team
last-reviewed: 2026-10-13
---

# 🌐 Reglas de Diseño de API y Comunicación Inter-Capa

Este documento establece el estándar normativo transversal para la definición, exposición y consumo de endpoints HTTP REST y contratos de datos en el **Sistema de Gestión de Asistencia UCO**.

---

## 1. Autoridad y Precedencia Contractual

Antes de diseñar, modificar o consumir un endpoint en el sistema, es obligatorio consultar en este orden:

1. Este documento (`API_DESIGN_RULES.md`).
2. El contrato congelado [BACKEND_GOLDEN_PATH_CONTRACT.md](../contracts/openapi/BACKEND_GOLDEN_PATH_CONTRACT.md).
3. La especificación viva [OpenAPI Canónico 3.0](../contracts/openapi/openapi-golden-path.yaml).
4. El work item activo en la línea base.

> [!CAUTION]
> **Prohibición de Invención de Endpoints:** Los desarrolladores y agentes de IA no inventan endpoints, métodos HTTP, esquemas de payload o códigos de estado. OpenAPI YAML versionado es la única especificación autoritativa.

---

## 2. Estilo Arquitectónico: `PRAGMATIC_RESOURCE_PLUS_BUSINESS_COMMAND`

Las URLs y los verbos HTTP expresan semántica de recursos o intenciones explícitas de negocio. La persistencia subyacente en base de datos no condiciona el método HTTP: un `UPDATE` en SQL Server no implica forzosamente un PUT, y un *soft-delete* (desactivación lógica) no implica un DELETE.

### Árbol Canónico de Decisión

```text
¿Es una lectura sin efectos colaterales en el estado?
  └─► GET /recursos

¿Es la creación de un recurso cuyo identificador controla el servidor?
  └─► POST /recursos (Retorna 201 Created con URI del recurso)

¿Es una actualización parcial de campos permitidos?
  └─► PATCH /recursos/{id}

¿Es un reemplazo integral e idempotente de la representación?
  └─► PUT /recursos/{id} (Requiere METHOD_EXCEPTION documentada)

¿Es una transición de estado o acción del dominio institucional?
  └─► POST /recursos/{id}/{verbo-negocio}  (ej: /sesiones/{id}/cancelar, /grupos/{id}/cerrar)

¿Es una operación masiva transaccional de negocio?
  └─► POST /recursos/lote                 (ej: /asistencias/lote)

¿Es la destrucción física irrevocable de la entidad?
  └─► DELETE /recursos/{id} (Requiere METHOD_EXCEPTION documentada)
```

---

## 3. Uso Estricto de Métodos HTTP

### 3.1 GET (Lectura Idempotente)
* Prohibido utilizar GET para ejecutar comandos, mutar estados o realizar acciones por "comodidad" del frontend.
* Toda consulta de listados de tamaño medio o grande debe implementar paginación mediante `page` y `size`.

### 3.2 POST (Creación de Recursos y Business Commands)
* **Creación:** Genera la entidad y retorna `201 Created` junto con el DTO UI-Ready generado.
* **Business Commands:** Representa transiciones de negocio explícitas con verbos semánticos: `cancelar`, `reprogramar`, `aprobar`, `rechazar`, `cerrar`.
* Prohibido utilizar nombres genéricos o vagos como `doAction`, `process`, `execute`, `run` o `updateStatus`.

### 3.3 PATCH (Modificación Parcial)
* Actualiza exclusivamente los atributos enviados en el payload JSON. No exige enviar el recurso completo ni sobreescribe campos omitidos.

### 3.4 PUT y DELETE (`METHOD_EXCEPTION` Obligatoria)
* Tanto PUT como DELETE quedan restringidos por defecto. Todo nuevo endpoint propuesto con estos verbos exige una justificación formal en el work item:
  ```text
  METHOD_EXCEPTION: YES
  RATIONALE: <Justificación técnica de por qué aplica reemplazo total o eliminación física>
  FULL_REPLACEMENT_OR_TRUE_DELETE: <Evidencia de soporte>
  ALTERNATIVES_CONSIDERED: PATCH / POST BUSINESS COMMAND
  ```

---

## 4. Contratos de Respuesta Unificados

### 4.1 Tupla de Salida en Base de Datos (SQL Server ↔ Backend)
Toda mutación transaccional o Stored Procedure orquestador debe retornar obligatoriamente el resultset canónico de 4 columnas:
```sql
SELECT 
    @idResultado      AS idResultado,
    @exitoso          AS exitoso,
    @mensajeUsuario   AS mensajeUsuario,
    @mensajeTecnico   AS mensajeTecnico;
```

### 4.2 Envoltorio de Mutaciones y Consultas Simples (`ApiDataResponse<T>`)
Toda respuesta de recurso singular o mutación desde el Backend hacia el Frontend se encapsula en:
```json
{
  "exitoso": true,
  "mensajeUsuario": "Operación ejecutada con éxito.",
  "datos": { ... }
}
```

### 4.3 Envoltorio de Consultas Paginadas (`ApiPageResponse<T>`)
Todo listado filtrable y navegable expone metadatos de paginación uniformes:
```json
{
  "elementos": [ { ... }, { ... } ],
  "numeroPagina": 1,
  "tamanoPagina": 20,
  "totalElementos": 85,
  "totalPaginas": 5
}
```

---

## 5. Códigos de Estado HTTP Estándar

| Código HTTP | Nombre | Semántica Aplicada en Asistencias UCO |
| :---: | :--- | :--- |
| **200** | OK | Consulta exitosa (`GET`) o comando procesado retornando estado resultante. |
| **201** | Created | Recurso nuevo creado exitosamente con identificador único persistido. |
| **400** | Bad Request | Error de validación semántica o sintáctica de payload (`ValidationException`). |
| **401** | Unauthorized | Token JWT ausente, expirado o con firma criptográfica inválida. |
| **403** | Forbidden | Usuario autenticado pero sin jurisdicción institucional (`UserScopeService`). |
| **404** | Not Found | Entidad no encontrada por identificador (`ResourceNotFoundException`). |
| **409** | Conflict | Violación de regla de integridad o colisión de negocio (`ConflictException`). |
| **500** | Internal Error | Excepción inesperada del servidor; enmascara detalles técnicos internos. |
