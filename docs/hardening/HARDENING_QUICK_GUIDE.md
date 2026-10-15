# ⚡ HARDENING QUICK GUIDE — Guía Rápida de Operación y Orientación
> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Destinatarios:** Desarrolladores Full-Stack, Ingenieros DevOps, Agentes de IA autónomos.  
> **Objetivo:** Cheat Sheet operativa directa al grano para entender y aplicar el modelo de *hardening* en menos de 2 minutos.  
> **Versión:** 2.1.0 (Línea Base Congelada)

---

## 🧭 1. Resumen Ejecutivo: ¿Qué está Permitido y qué está Bloqueado?

| Capa / Dimensión | 🟢 PERMITIDO / OBLIGATORIO | 🛑 ESTRICTAMENTE PROHIBIDO |
| :--- | :--- | :--- |
| **Base de Datos** | • Conexión de App como `app_asistencias_user`<br>• Invocar Stored Procedures transaccionales (`EXEC usp_*`)<br>• Consultar Vistas optimizadas (`SELECT FROM uv_*`)<br>• Transacciones con `SET XACT_ABORT ON;` | • Escritura directa en tablas (`INSERT`, `UPDATE`, `DELETE`)<br>• Procedimientos Dios monolíticos<br>• Datos quemados (GUIDs o estados hardcodeados)<br>• Sentencias SQL inline desde controladores REST |
| **Red & Puertos** | • Bind exclusivo a interfaces loopback `127.0.0.1`<br>• Conexión directa desde IDE al host en modo dev<br>• Perfiles de compose (`core` por defecto: SQL Server + Keycloak) | • Bind abierto `0.0.0.0` expuesto en redes Wi-Fi públicas<br>• Levantar todos los servicios innecesarios saturando la RAM host |
| **Contratos WORM** | • Contratos inmutables versionados con `.sha256`<br>• Paridad absoluta (cero drift) entre repositorios<br>• Respuestas encapsuladas en `ApiDataResponse` / `ApiPageResponse` | • Modificar contratos sin recalcular hashes ni conciliar pares<br>• Contract drift entre Backend, DB y Frontend |
| **Seguridad & Secretos**| • Configuración vía `.env` local (ignorado en git)<br>• Gestión de secretos vía Azure Key Vault / App Configuration<br>• Claims estándar JWT (`idUsuario`, `sub`, `roles`) | • Commits con contraseñas, tokens JWT o connection strings<br>• Uso de credenciales `sa` en entornos de ejecución de aplicación |
| **Reactividad** | • Server-Sent Events (SSE) en `/api/v1/realtime/stream`<br>• Reactividad en cliente gobernada por Angular Signals | • Polling periódico HTTP (`setInterval`, timers cada 3 o 5s) |
| **Almacenamiento (MinIO & ClamAV)** | • S3 API en loopback `127.0.0.1:9000`<br>• Backend como único intermediario de carga/descarga<br>• Política de menor privilegio en `asistencias-soportes/soportes/*`<br>• Credenciales técnicas (`MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY`)<br>• Escaneo antivirus obligatorio (ClamAV daemon `127.0.0.1:3310` vía `INSTREAM`)<br>• Backend stateless (sin archivos locales ni BLOBs en BD) | • Habilitar consola web (`MINIO_BROWSER=off` obligatorio)<br>• Acceso directo o presigned URLs a Angular (`FORBIDDEN`)<br>• Guardar archivos en disco local de backend o BLOBs SQL<br>• Uso de credenciales root en la aplicación<br>• Creación/eliminación de buckets en tiempo de ejecución<br>• Acceso anónimo a objetos |

---

## 🛠️ 2. Flujos de Trabajo Cotidianos (Cheat Sheet)

### 2.1 "¿Qué comando ejecuto al iniciar mi jornada o tras clonar el repo?"
```powershell
# Iniciar servicios mínimos indispensables (SQL Server + Keycloak)
.\AsistenciasUCO-Infra\infra.ps1 up -Profile core

# Verificar que los puertos y contenedores estén activos
.\AsistenciasUCO-Infra\infra.ps1 status
```

### 2.2 "¿Qué comando corro si agregué o modifiqué un Stored Procedure o Vista en DB?"
```powershell
# 1. Recompilar el esquema completo en el contenedor de SQL Server
.\AsistenciasUCO-Infra\infra.ps1 db-deploy

# 2. Ejecutar la suite transaccional de pruebas de BD
.\AsistenciasUCO-Infra\infra.ps1 db-test
```
> [!IMPORTANT]
> Recuerda que si el objeto forma parte del manifiesto congelado de Base de Datos (`DB_DEVELOP_FREEZE_ADDENDUM.md`), debes verificar que su firma SHA-256 no genere conflicto corriendo `.\AsistenciasUCO-Infra\infra.ps1 verify-contracts`.

### 2.3 "¿Qué hago si el Backend me arroja error `The EXECUTE/SELECT permission was denied on object...`?"
1. **Causa:** El backend conecta bajo el usuario de mínimo privilegio `app_asistencias_user`.
2. **Solución:** Si creaste una nueva tabla, recuerda que la aplicación **NUNCA** debe acceder a tablas físicas. Debe existir un Stored Procedure orquestador (`usp_*`) o una Vista autorizada (`uv_*`).
3. Si creaste un nuevo SP o Vista y olvidaste otorgar permisos al rol de la app, vuelve a desplegar el esquema con:
   ```powershell
   .\AsistenciasUCO-Infra\infra.ps1 db-deploy
   ```
   *(El script `01-hardening-least-privilege.sql` se ejecuta al final de `db-deploy` garantizando que todo nuevo SP reciba `GRANT EXECUTE` y toda nueva vista reciba `GRANT SELECT` al rol `db_asistencias_app_role`).*

### 2.4 "¿Cómo obtengo un JWT Bearer válido para probar endpoints en Postman/Swagger?"
```powershell
# Obtener token de Docente
.\AsistenciasUCO-Infra\infra.ps1 kc-token -Role Docente

# Obtener token de Estudiante o Coordinador
.\AsistenciasUCO-Infra\infra.ps1 kc-token -Role Estudiante
.\AsistenciasUCO-Infra\infra.ps1 kc-token -Role Coordinador
```
El token resultante se imprime en consola listo para ser copiado en el header `Authorization: Bearer <TOKEN>`.

### 2.5 "¿Cómo valido mi rama antes de hacer un commit o Pull Request (Pre-Flight Check)?"
```powershell
# Ejecuta en secuencia escaneo de secretos + paridad de contratos WORM
.\AsistenciasUCO-Infra\infra.ps1 verify
```
Si el resultado es `[PASS]`, tu rama está certificada para commit.

### 2.6 "¿Cómo inicio y valido el almacenamiento de objetos (MinIO & ClamAV)?"
```powershell
# Iniciar servicios de almacenamiento (MinIO S3 API + ClamAV daemon)
.\AsistenciasUCO-Infra\infra.ps1 storage-up

# Validar salud y politicas de menor privilegio S3
.\AsistenciasUCO-Infra\infra.ps1 storage-test

# Detener contenedores de almacenamiento
.\AsistenciasUCO-Infra\infra.ps1 storage-down
```
> [!IMPORTANT]
> Recuerda que `FRONTEND_DIRECT_STORAGE_ACCESS: FORBIDDEN`: el Frontend Angular **nunca** accede a MinIO ni recibe presigned URLs; el Backend Spring Boot media todas las operaciones de carga/descarga y ClamAV escanea los archivos en memoria antes de la persistencia S3.

---

## 🌳 3. Árbol Rápido de Solución de Problemas (Troubleshooting)

```
                              ¿QUÉ ERROR ESTÁS EXPERIMENTANDO?
                                              │
         ┌────────────────────────────────────┼────────────────────────────────────┐
         ▼                                    ▼                                    ▼
[Colisión Puerto 1433]               [Fallo Hash SHA-256]                [Token sin idUsuario]
         │                                    │                                    │
¿SQL Server de Windows activo        ¿Modificaste un contrato            ¿Keycloak fue iniciado
o contenedor previo colgado?         (OpenAPI, DB, Eventos)?             con realm desactualizado?
         │                                    │                                    │
  [Solución]:                          [Solución]:                          [Solución]:
  1. Detén el servicio local           1. Si el cambio no fue pactado:      1. Diagnostica claims:
     de Windows SQL Server.               revierte la modificación.            .\infra.ps1 kc-diagnose
  2. O mata el PID en conflicto:       2. Si fue un cambio acordado:        2. Reconcilia realm & users:
     Stop-Process -Id <PID> -Force        actualiza el archivo .sha256         .\infra.ps1 kc-bootstrap
  3. Ejecuta:                             y replica en los repos pares         .\infra.ps1 kc-seed
     .\infra.ps1 down                     con:
     .\infra.ps1 up                       .\infra.ps1 verify-contracts
```

### 3.1 Detalle: Colisión en Puerto 1433
* **Síntoma:** Docker compose arroja `Bind for 127.0.0.1:1433 failed: port is already allocated` o advertencia de `start-dev.ps1`.
* **Diagnóstico:** Corre `.\AsistenciasUCO-Infra\infra.ps1 status` para ver el PID que ocupa el puerto.
* **Acción:**
  ```powershell
  # Si es un contenedor docker huérfano:
  docker stop sql_server_asistencias; docker rm sql_server_asistencias
  # Si es una instancia MSSQLSERVER de Windows local:
  Stop-Service MSSQLSERVER -Force
  ```

### 3.2 Detalle: Falla de Integridad WORM (`verify-contracts.ps1`)
* **Síntoma:** El verificador reporta `[FALLO INTEGRIDAD]` o `[PARIDAD FALLIDA]`.
* **Diagnóstico:** Un archivo de contrato en `GestioAsistenciaBackend` o `GestioAsistenciaDB` difiere del canónico en `AsistenciasUCO-Infra/docs/contracts/`.
* **Acción:** Asegura que ambas copias sean idénticas bit a bit. Ejecuta `.\AsistenciasUCO-Infra\infra.ps1 verify-contracts` para validar la reconciliación.

### 3.3 Detalle: Token Rechazado por Backend (401 Unauthorized / Claim Missing)
* **Síntoma:** El Backend rechaza el token con `Token no contiene claim 'idUsuario'`.
* **Diagnóstico:** Corre `.\AsistenciasUCO-Infra\infra.ps1 kc-diagnose`.
* **Acción:** Ejecuta `.\AsistenciasUCO-Infra\infra.ps1 kc-bootstrap` seguido de `.\AsistenciasUCO-Infra\infra.ps1 kc-seed` para asegurar que el client scope `asistencias-claims` mapee los atributos del usuario institucional.

### 3.4 Detalle: Error de Acceso en MinIO o Puerto 9000 Ocupado
* **Síntoma:** Backend arroja `AccessDenied` al subir soporte o fallo de bind en puerto 9000.
* **Diagnóstico:** Corre `.\AsistenciasUCO-Infra\infra.ps1 storage-test`. Si reporta `AccessDenied`, la política `asistencias-backend` o las credenciales técnicas no coinciden.
* **Acción:**
  1. Verifica que el backend use `MINIO_ACCESS_KEY` y `MINIO_SECRET_KEY`, nunca las credenciales root.
  2. Si el contenedor de MinIO está caído o en conflicto, reinícialo:
     ```powershell
     .\AsistenciasUCO-Infra\infra.ps1 storage-down
     .\AsistenciasUCO-Infra\infra.ps1 storage-up
     ```
  3. Ejecuta `.\AsistenciasUCO-Infra\infra.ps1 storage-test` para verificar que la suite de permisos S3 retorne `PASS` en `MINIO_APP_PUT_GET_DELETE_TARGET_BUCKET` y `DENIED` en las demás operaciones.

---

## 📌 4. Mapeo Rápido de Comandos CLI `infra.ps1`

| Acción Requerida | Comando Directo |
| :--- | :--- |
| **Menú y Ayuda Interactiva** | `.\AsistenciasUCO-Infra\infra.ps1 help` |
| **Arrancar TODO (Infra + BD + Backend + Frontend)** | `.\AsistenciasUCO-Infra\infra.ps1 all` (o `infra.ps1 dev`) |
| **Iniciar Backend y Frontend Juntos** | `.\AsistenciasUCO-Infra\infra.ps1 apps` |
| **Iniciar Solo Backend (Spring Boot 8080)** | `.\AsistenciasUCO-Infra\infra.ps1 backend` |
| **Iniciar Solo Frontend (Angular 4200)** | `.\AsistenciasUCO-Infra\infra.ps1 frontend` |
| **Iniciar Solo Contenedores (Core)** | `.\AsistenciasUCO-Infra\infra.ps1 up -ContainersOnly` |
| **Iniciar Almacenamiento (MinIO + ClamAV)** | `.\AsistenciasUCO-Infra\infra.ps1 storage-up` |
| **Detener Almacenamiento** | `.\AsistenciasUCO-Infra\infra.ps1 storage-down` |
| **Validar Políticas S3 y Salud Storage** | `.\AsistenciasUCO-Infra\infra.ps1 storage-test` |
| **Iniciar Stack Completo (Con OTel/Grafana)** | `.\AsistenciasUCO-Infra\infra.ps1 up -Profile full` |
| **Detener Todo y Liberar Puertos** | `.\AsistenciasUCO-Infra\infra.ps1 down` |
| **Ver Estado de Puertos y Servicios** | `.\AsistenciasUCO-Infra\infra.ps1 status` |
| **Desplegar Esquema SQL Server** | `.\AsistenciasUCO-Infra\infra.ps1 db-deploy` |
| **Sembrar 11 Usuarios en DB** | `.\AsistenciasUCO-Infra\infra.ps1 db-seed` |
| **Suite de Pruebas T-SQL** | `.\AsistenciasUCO-Infra\infra.ps1 db-test` |
| **Obtener JWT de Docente** | `.\AsistenciasUCO-Infra\infra.ps1 kc-token -Role Docente` |
| **Obtener JWT de Estudiante** | `.\AsistenciasUCO-Infra\infra.ps1 kc-token -Role Estudiante` |
| **Auditar Configuración Keycloak** | `.\AsistenciasUCO-Infra\infra.ps1 kc-diagnose` |
| **Pre-Flight Check (Secretos + Contratos)** | `.\AsistenciasUCO-Infra\infra.ps1 verify` |
| **Escanear Secretos Expuestos** | `.\AsistenciasUCO-Infra\infra.ps1 check-secrets` |
| **Auditar Paridad Contratos WORM** | `.\AsistenciasUCO-Infra\infra.ps1 verify-contracts` |
| **Sincronizar Work Items HUs** | `.\AsistenciasUCO-Infra\infra.ps1 sync-hus` |
