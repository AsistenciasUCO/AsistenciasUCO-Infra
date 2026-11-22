---
status: active
type: runbook
scope: demo-local-docker
owner: devops-team
last-reviewed: 2026-11-22
---

# Runbook: demo final en Docker local

Del equipo limpio a una demostración funcional. El alcance de TD-108 se limita a esta demo en Docker local (decisión
"publicación = demo Docker"): no cubre TLS, Keycloak en modo producción ni rollback de release (ver
[REQUISITOS_PRODUCCION](REQUISITOS_PRODUCCION.md)). Este documento no repite el detalle de
[PRUEBAS_LOCALES](PRUEBAS_LOCALES.md) ni de [stack/README](../../stack/README.md); los enlaza.

## 1. Requisitos

| Herramienta | Detalle |
| :--- | :--- |
| Docker Desktop | 4.30+ con Compose v2. Memoria de la VM: **10 GB** en `%USERPROFILE%\.wslconfig` (`[wsl2] memory=10GB`), luego `wsl --shutdown` y reiniciar Docker. El escenario `completo` usa unos 9,65 GB estimados |
| PowerShell | Windows PowerShell 5.1 o 7.x |
| Python 3 de Windows | Solo para Seguridad y los datos de prueba. Defina `ASISTENCIAS_PYTHON` con la ruta a `python.exe` si no hay lanzador `py` (el alias de la Microsoft Store no sirve) |
| Git | Para clonar los repos |
| Node.js y Java | **No hacen falta**: Backend y Frontend corren en contenedores (`asis-app`) |

## 2. Estructura de clonado

Los repos deben ser carpetas hermanas dentro del mismo directorio de trabajo (los scripts resuelven rutas relativas al
workspace):

```text
GestionAsistencia\
├── AsistenciasUCO-Infra\      # orquestación (infra.ps1)
├── GestioAsistenciaDB\
├── GestioAsistenciaBackend\   # incluye infra\security-baseline (aprovisionamiento de Seguridad)
└── GestioAsistenciaFrontend\
```

Todos los comandos se ejecutan desde la raíz del workspace con `.\AsistenciasUCO-Infra\infra.ps1`.

## 3. Archivos de entorno

Copie cada `.env.example` a `.env` y complete lo que indique el ejemplo. No se versionan ni se pegan en chats.

```powershell
Copy-Item .\AsistenciasUCO-Infra\.env.example        .\AsistenciasUCO-Infra\.env
Copy-Item .\GestioAsistenciaBackend\.env.example     .\GestioAsistenciaBackend\.env
Copy-Item .\GestioAsistenciaFrontend\.env.example    .\GestioAsistenciaFrontend\.env
Copy-Item .\GestioAsistenciaDB\.env.example          .\GestioAsistenciaDB\.env
```

- Las credenciales de laboratorio de Seguridad viven fuera del repo, en `%USERPROFILE%\.asistencias-security-lab\lab.env`
  (lo genera el aprovisionamiento de Seguridad, `provision_asistencias.py keycloak`; ver
  `GestioAsistenciaBackend/infra/security-baseline`). Nunca se imprime ni se versiona.
- `stack up` genera `stack/generado/backend.env` y `frontend.env` a partir de estos archivos; no se editan a mano.

## 4. Levantar

```powershell
.\AsistenciasUCO-Infra\infra.ps1 stack build            # una vez: imágenes asistencias-backend/frontend:develop
.\AsistenciasUCO-Infra\infra.ps1 stack build notificaciones   # una vez: imagen notificaciones-uco:0.1.0 (componente propio)
.\AsistenciasUCO-Infra\infra.ps1 stack up basico        # BD + Seguridad + Backend y Frontend
.\AsistenciasUCO-Infra\infra.ps1 stack status
```

Use `stack up completo` solo si la demo necesita mensajes (correos) y Catálogo de Parámetros; `soportes` agrega ClamAV
para adjuntos. No agregue más secciones a `completo` (memoria). Todos los escenarios con app incluyen `ext-notificaciones` (Servicio de Notificaciones UCO, `http://localhost:18090`): `stack up` genera sus secretos y crea su base; ver [stack/README](../../stack/README.md#ext-notificaciones-servicio-de-notificaciones-uco). El frontend queda en `http://localhost:4200`; el resto de
direcciones se imprimen al terminar `stack up`.

## 5. Datos de prueba y PDP

```powershell
$env:ASISTENCIAS_PYTHON = 'C:\Users\<usuario>\AppData\Local\Programs\Python\Python312\python.exe'   # si no hay `py`
.\AsistenciasUCO-Infra\infra.ps1 datos-prueba cargar -Yes
```

Recrea la base (con respaldo previo), carga 73 usuarios de todos los roles, los da de alta en Keycloak y el PDP y
verifica la visibilidad por rol (unos 10 minutos). Si falta Python, falla enseguida con un mensaje en español, antes de
tocar la base.

**Concesiones del PDP: automáticas.** `stack up` (con `ext-seguridad` y `asis-app`) y `datos-prueba cargar|seguridad`
ejecutan `provision_asistencias.py verify` y, si hay líneas `FALTA`, `pdp` (aditivo, nunca `--prune`) y verifican de
nuevo; solo imprimen conteos. Se omite con `-SinPdp`. Manual:
`python -X utf8 -I GestioAsistenciaBackend/infra/security-baseline/scripts/provision_asistencias.py verify`.

## 6. Usuarios por rol

La lista completa (rol, programa, grupos) está en
[USUARIOS.md](../../../GestioAsistenciaDB/scripts/datos-prueba/USUARIOS.md). La contraseña común de laboratorio está
documentada en `AGENTS.md`, sección 7; no se repite aquí. Se entra con el correo en `http://localhost:4200`.

| Rol | Ejemplo en los datos de prueba |
| :--- | :--- |
| Administrador | Ver USUARIOS.md |
| Decano | Decano de Ingeniería o de Económicas |
| Coordinador | Coordinadora de Sistemas o de Tec. Software (Diana Londoño es también docente) |
| Docente | Alejandro Cárdenas |
| Estudiante | Santiago, Kevin, Brayan, Mateo |

## 7. Qué mostrar por rol (guion corto)

Casos preparados y detalle: [PRUEBAS_LOCALES §3](PRUEBAS_LOCALES.md) y
[GUION-PRUEBAS-MANUALES](../work-items/CIERRE-001-cierre-proyecto/GUION-PRUEBAS-MANUALES.md).

1. **Administrador.** Período académico 2026-2: en la sección **Días de receso académico** agregar un día futuro dentro del
   período con su motivo (un día por registro; no acepta festivos, fechas pasadas ni repetidas). Mostrar que las sesiones de ese
   día quedan canceladas con el motivo «Receso académico: ...» y que un día ya aplicado no se puede retirar. Luego el cierre
   masivo del período 2026-1 (Alejandro Pineda supera el 20 %).
2. **Decano.** Solo ve su facultad; cambio de coordinador (Mauricio Quintero y Claudia Montoya están libres).
3. **Coordinador.** Grupos de sus programas, cambio de docente de un grupo, solicitudes de sesión extraordinaria
   pendientes; asistencia en solo lectura.
4. **Docente.** Tomar asistencia de una sesión (exclusiva del docente titular), QR/PIN, decisión sobre la revisión de Brayan
   (Ética, 26,7 %) y reclamos pendientes.
5. **Estudiante.** Horario (las sesiones de receso aparecen canceladas), historial y alertas (Santiago, Kevin y Brayan en
   pérdida; Mateo, Laura, Camila y Valeria en riesgo), radicar un reclamo.
6. **Tiempo real.** Docente y estudiante en dos ventanas: el cambio se refleja sin recargar (SSE).

Los correos van al buzón de prueba (`SMTP_NOTIFICATION_TEST_MODE_ENABLED=true`).

## 8. Apagar

```powershell
.\AsistenciasUCO-Infra\infra.ps1 stack down                 # todo menos asis-datos (nunca borra volúmenes)
.\AsistenciasUCO-Infra\infra.ps1 stack down -IncluirDatos   # también SQL Server y MinIO
```

## 9. Problemas frecuentes

| Síntoma | Causa y solución |
| :--- | :--- |
| 403 en una ruta o endpoint nuevo | El PDP no tiene la concesión. `stack up` y `datos-prueba` ya lo corrigen; manual: `provision_asistencias.py pdp` (aditivo) y luego `verify`. Nunca `--prune` en la demo |
| Contenedores que mueren o `stack up` rechaza por memoria | Docker sin memoria: suba `.wslconfig` a 10 GB o detenga secciones que no use (`stack down <sección>`); antes del gate de BD detenga MessageUcoLab, Kong, Catálogo y ClamAV |
| Error `engine.sock` o `docker` colgado | Reinicie Docker Desktop (`wsl --shutdown` y abrirlo de nuevo); verifique con `docker ps` |
| `datos-prueba cargar` pide definir Python | Defina `ASISTENCIAS_PYTHON` (sección 5) |
| Falta la imagen `asistencias-backend:develop` | `.\AsistenciasUCO-Infra\infra.ps1 stack build` |
| Error de collation al desplegar el esquema | La base debe crearse con la collation del esquema; use `datos-prueba cargar -Yes` (recrea desde cero) en vez de restaurar una base de otro servidor |
| Hay un backend local en el puerto 8080 | Deténgalo o use `datos-prueba cargar -Yes -StopBackend` |
| La sesión "se cae" durante la demo | Esperado en el laboratorio: el access token dura **5 minutos** (se renueva por PKCE) y la sesión SSO **30 minutos**; pasado ese tiempo hay que volver a iniciar sesión |
| Frontend sin estilos o en blanco | Tras un `stack build`, recree la app con `stack up asis-app -Conservar` |
