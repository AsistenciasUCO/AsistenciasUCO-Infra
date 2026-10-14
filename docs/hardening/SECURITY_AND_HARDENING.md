---
status: active
type: normative
scope: infrastructure-and-security
owner: devsecops-team
last-reviewed: 2026-10-13
---

# 🛡️ Guía de Hardening, DevSecOps y Mínimo Privilegio

Este documento detalla la arquitectura de endurecimiento (*hardening*), políticas de mínimo privilegio y salvaguardas de seguridad implementadas en la 4ª capa transversal (**AsistenciasUCO-Infra**) para proteger la confidencialidad, integridad y disponibilidad del sistema.

---

## 1. Mínimo Privilegio en Base de Datos (SQL Server)

### 1.1 El Problema del Superusuario (`sa`)
Tradicionalmente, en entornos de desarrollo local se utilizaba la cuenta administrativa `sa`, lo que representaba un riesgo crítico:
* Acceso irrestricto de escritura a tablas físicas.
* Posibilidad de ejecutar sentencias DDL arbitrarias (`DROP TABLE`, `ALTER TABLE`).
* Fuga potencial de datos o bypass de Stored Procedures y auditorías.

### 1.2 Implementación del Rol `db_app_executor` y Usuario `app_asistencias_user`
En [`components/sqlserver/init/01-hardening-least-privilege.sql`](../../components/sqlserver/init/01-hardening-least-privilege.sql), se aplica un modelo estricto de menor privilegio:

```sql
-- 1. Creación del rol de ejecución
CREATE ROLE [db_app_executor];

-- 2. Permiso exclusivo de ejecución sobre Stored Procedures
GRANT EXECUTE ON SCHEMA::[dbo] TO [db_app_executor];

-- 3. Permiso de solo lectura sobre Vistas autorizadas (uv_* y uv_auth_*)
GRANT SELECT ON SCHEMA::[dbo] TO [db_app_executor];

-- 4. Veto estricto de escritura directa y alteración DDL
DENY INSERT, UPDATE, DELETE ON SCHEMA::[dbo] TO [db_app_executor];
DENY ALTER ON SCHEMA::[dbo] TO [db_app_executor];

-- 5. Creación del login de aplicación y asignación al rol
CREATE USER [app_asistencias_user] FOR LOGIN [app_asistencias_user];
ALTER ROLE [db_app_executor] ADD MEMBER [app_asistencias_user];
```

* **Beneficio:** Las aplicaciones (Backend / APIs) solo pueden invocar procedimientos almacenados (`EXEC usp_*`) o consultar vistas (`SELECT uv_*`). Queda bloqueado cualquier intento de ejecutar sentencias `DELETE FROM`, `UPDATE` directo o inyecciones SQL que intenten mutar tablas omitiendo las reglas de negocio.

---

## 2. Aislamiento de Red Local (`127.0.0.1` vs `0.0.0.0`)

### 2.1 Prevención de Escaneos y Accesos No Autorizados en Red Local
Por defecto, Docker enlaza los puertos en `0.0.0.0`, exponiendo los servicios a cualquier dispositivo conectado a la misma red Wi-Fi o LAN corporativa.

### 2.2 Política de Bind Local
En [`docker-compose.yml`](../../docker-compose.yml) y `.env.example`, todas las directivas de publicación de puertos utilizan explícitamente la variable `${HOST_BIND_IP:-127.0.0.1}`:
* SQL Server: `127.0.0.1:1433:1433`
* Keycloak HTTP: `127.0.0.1:8081:8080`
* Keycloak Management: `127.0.0.1:9001:9000`
* OpenTelemetry: `127.0.0.1:4317` y `127.0.0.1:4318`
* Prometheus: `127.0.0.1:9090:9090`
* Grafana: `127.0.0.1:3000:3000`
* Azurite: `127.0.0.1:10000..10002`

* **Beneficio:** Solo los procesos que residen en la máquina física del desarrollador pueden conectarse a los puertos de desarrollo. Los contenedores quedan invisibles ante escaneos de red externos.

---

## 3. Asignación de Recursos y Límites de Memoria (RAM Limits)

Para prevenir la saturación de memoria RAM en equipos de desarrollo (*Out-Of-Memory* que congela el sistema operativo), cada servicio cuenta con límites estrictos definidos en su sección `deploy.resources.limits.memory`:

| Contenedor / Servicio | Límite RAM por Defecto | Perfil Asociado | Variable de Ajuste |
| :--- | :---: | :---: | :--- |
| **Microsoft SQL Server 2022** | `2g` (2048 MB) | `core` | `SQL_MEM_LIMIT` |
| **Keycloak IAM (Java 21/Quarkus)** | `1g` (1024 MB) | `core` | `KEYCLOAK_MEM_LIMIT` |
| **PostgreSQL 17 (DB Keycloak)** | `512m` (512 MB) | `core` | `KC_DB_MEM_LIMIT` |
| **Azurite (Azure Emulation)** | `512m` (512 MB) | `azure` | N/A |
| **Prometheus Metrics** | `512m` (512 MB) | `observability` | N/A |
| **Grafana Dashboards** | `256m` (256 MB) | `observability` | N/A |
| **OpenTelemetry Collector** | `256m` (256 MB) | `observability` | N/A |
| **Traefik Reverse Proxy** | `128m` (128 MB) | `proxy` | N/A |

* **Total Perfil `core`:** Máximo ~3.5 GB de RAM.
* **Total Perfil `full`:** ~5.2 GB de RAM.

---

## 4. Hardening de Cabeceras HTTP en Proxy Inverso (Traefik)

El componente [`components/proxy/dynamic/middlewares.yml`](../../components/proxy/dynamic/middlewares.yml) implementa las mejores prácticas recomendadas por OWASP para mitigar ataques web:

1. **HTTP Strict Transport Security (HSTS):** `max-age=31536000; includeSubDomains; preload` (fuerza navegación cifrada).
2. **Protección contra Clickjacking:** `X-Frame-Options: DENY` y CSP `frame-ancestors 'none'`.
3. **MIME-Type Sniffing Protection:** `X-Content-Type-Options: nosniff`.
4. **Content Security Policy (CSP):** Política declarativa estricta que restringe fuentes de scripts, estilos, imágenes y conexiones WebSocket.
5. **Permissions Policy:** Desactiva accesos de hardware no requeridos (`camera=(), microphone=(), geolocation=()`).
6. **Enmascaramiento de Servidor:** Elimina cabeceras delatoras `Server` y `X-Powered-By`.
7. **Rate Limiting:** Regla de límite de tasa (100 req/min con ráfagas de 50) para prevenir denegación de servicio o fuerza bruta.

---

## 5. Higiene de Secretos y Escaneo Estático Continuo

En cumplimiento del estándar DevSecOps:
1. **Regla de Cero Secretos:** Ningún archivo `.env`, certificado privado (`.pem`, `.pfx`), backup de base de datos (`.bak`) o token puede versionarse en Git.
2. **`.gitignore` Blindado:** La raíz de `AsistenciasUCO-Infra` cuenta con un `.gitignore` integral que excluye todos los artefactos sensibles.
3. **Escáner Automatizado:** El script [`scripts/security/check-secrets.ps1`](../../scripts/security/check-secrets.ps1) audita todo el repositorio buscando contraseñas quemadas y llamadas CLI inseguras.
   - Cuenta con modo de auto-verificación: `.\check-secrets.ps1 -SelfCheck`.
   - **Garantía de Privacidad:** El reporte **jamás imprime el secreto**, protegiendo los logs de auditoría ante fugas secundarias.
