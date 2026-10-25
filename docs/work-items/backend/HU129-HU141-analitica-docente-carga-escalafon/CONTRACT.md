# CONTRACT: HU129, HU141 - Carga Académica Docente y Escalafón

## 1. Endpoint REST
`GET /api/v1/admin/docentes/analitica-carga-escalafon`

### 1.1 Seguridad
- Header: `Authorization: Bearer <JWT>`
- Rol Autorizado: `ROLE_ADMINISTRADOR`, `ROLE_DECANO`

### 1.2 Respuesta Exitosa (200 OK)
```json
{
  "idResultado": "ANALITICA_DOCENTE_CONSULTADA",
  "exitoso": true,
  "mensajeUsuario": "Analítica de carga docente y escalafón consultada exitosamente",
  "mensajeTecnico": "Distribución de escalafón y horas obtenida",
  "datos": {
    "totalDocentes": 128,
    "promedioHorasSemanales": 18.5,
    "totalHorasContratadas": 2368,
    "distribucionEscalafon": [
      {
        "categoria": "Titular",
        "total": 32,
        "porcentaje": 25.0
      },
      {
        "categoria": "Asociado",
        "total": 48,
        "porcentaje": 37.5
      },
      {
        "categoria": "Asistente",
        "total": 28,
        "porcentaje": 21.9
      },
      {
        "categoria": "Auxiliar",
        "total": 20,
        "porcentaje": 15.6
      }
    ],
    "docentesCarga": [
      {
        "docenteId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "nombreCompleto": "Dr. Fernando Morales",
        "documento": "71234567",
        "escalafon": "Titular",
        "tipoVinculacion": "Tiempo Completo",
        "gruposAsignados": 3,
        "horasSemanales": 20
      }
    ]
  }
}
```
