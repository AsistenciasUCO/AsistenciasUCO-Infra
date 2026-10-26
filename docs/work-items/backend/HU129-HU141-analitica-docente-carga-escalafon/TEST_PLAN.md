# TEST PLAN: HU129, HU141 - Carga Académica Docente y Escalafón

## 1. Alcance
Validar la orquestación del caso de uso de analítica docente, la correcta agregación porcentual de escalafón y la respuesta del controlador REST.

## 2. Casos de Prueba (TDD)
- **TC-01 (Caso de Uso - Cálculo Correcto):**
  - Dado un censo de 128 docentes con categorías de escalafón.
  - Cuando se invoca `consultarAnalitica()`.
  - Entonces retorna `AnaliticaDocenteCargaDTO` con las sumas y listas de carga docente.
- **TC-02 (Controlador REST - Respuesta 200 OK):**
  - Dado un administrador/decano autenticado.
  - Cuando envía `GET /api/v1/admin/docentes/analitica-carga-escalafon`.
  - Entonces el controlador retorna 200 OK con `ApiDataResponse` y `exitoso = true`.
