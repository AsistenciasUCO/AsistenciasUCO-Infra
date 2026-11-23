# Addendum P3: tipo de cancelación RECESO en el Golden Path (2026-11-22)

## Cambio
- `components.schemas.CancelacionSesion.properties.tipo.enum` pasa de `[DOCENTE, FESTIVO]` a `[DOCENTE, FESTIVO, RECESO]`. Se documenta el significado de cada código.
- `nombreFestivo` aclara que solo trae valor cuando el tipo es `FESTIVO`. En `RECESO` va `null` y el `motivo` lleva el prefijo «Receso académico: ».

## Por qué
- DEC-081 (receso académico) agregó el tipo `RECESO` al catálogo `TipoCancelacionSesion` (migración 68). Desde entonces la BD y el backend lo devuelven en `CancelacionSesion`.
- El contrato congelado seguía declarando solo dos valores, así que una respuesta real de una sesión cancelada por receso no cumplía el esquema. Se detectó en la auditoría de Infra del 2026-11-22.
- `COORDINADOR` no es un tipo de cancelación: el catálogo real es `DOCENTE`, `FESTIVO` y `RECESO`. Por eso no se agrega.

## Alcance y compatibilidad
- Es un cambio aditivo en una enumeración de respuesta. Los clientes que ya trataban un `tipo` desconocido como cancelación genérica siguen funcionando. El frontend ya muestra `RECESO`.
- Copias actualizadas con el mismo contenido y el mismo hash (`e6615d8b…319c`):
  - `AsistenciasUCO-Infra/docs/contracts/openapi/openapi-golden-path.yaml`
  - `GestioAsistenciaBackend/docs/contracts/openapi/openapi-golden-path.yaml`
  - `GestioAsistenciaFrontend/docs/contracts/external/backend/openapi-golden-path.yaml`
- Cada copia lleva su `.sha256`. `infra.ps1 verify` comprueba la paridad.
