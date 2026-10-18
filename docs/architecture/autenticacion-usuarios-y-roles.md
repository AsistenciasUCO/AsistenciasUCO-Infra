# Autenticación, Usuarios y Control de Acceso por Rol (IAM) — GestioAsistencia UCO

Arquitectura de identidad con Keycloak 26, RBAC, credenciales institucionales y observabilidad en Grafana.

---

## Índice
* [1. Directorio Oficial de Usuarios y Mapeo Relacional](#1-directorio-oficial-de-usuarios-y-mapeo-relacional)
* [2. Infraestructura de Identidad y Observabilidad](#2-infraestructura-de-identidad-y-observabilidad)
* [3. Historial de Decisiones y Correcciones Técnicas](#3-historial-de-decisiones-y-correcciones-técnicas)
  * [A. Validación de Token JWT y CORS](#a-validación-de-token-jwt-y-cors)
  * [B. Autenticación Directa (Direct Grants)](#b-autenticación-directa-direct-grants)
  * [C. Alineación de Roles en Realm](#c-alineación-de-roles-en-realm)
  * [D. Parámetros de Sesión y Vigencia](#d-parámetros-de-sesión-y-vigencia)
* [Documentos Relacionados](#documentos-relacionados)

---

## 1. Directorio Oficial de Usuarios y Mapeo Relacional

Usuarios sincronizados entre **Keycloak** (Realm `asistencias-uco`) y **SQL Server 2022+** (`dbo.Usuario`).  
**Contraseña unificada de desarrollo:** `Test1234!`

| Rol Realm | Usuario / Correo | GUID `dbo.Usuario` | GUID Entidad Específica | Ruta de Entrada |
| :--- | :--- | :--- | :--- | :--- |
| `ADMINISTRADOR` | `admin.institucional@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000000` | N/A | `/app/admin/decanos` |
| `DECANO` | `decano.ingenieria@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000001` | `dbo.Decano`: `...0001` | `/app/decano/coordinadores` |
| `COORDINADOR` | `coordinador.sistemas@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000002` | `dbo.Coordinador`: `...0002` | `/app/coordinador/docentes` |
| `DOCENTE` | `maria.rostagno@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000003` | `dbo.Docente`: `...0003` | `/app/docente/grupos` |
| `ESTUDIANTE` | `carlos.zapata@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000004` | `dbo.Estudiante`: `...0004` | `/app/estudiante/horarios` |

---

## 2. Infraestructura de Identidad y Observabilidad

| Servicio | URL Local | URL LAN | Credenciales | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| **Frontend Web** | `http://localhost:4200` | `http://192.168.1.85:4200` | *(Ver tabla 1)* | Portal Angular Standalone |
| **Backend REST API** | `http://localhost:8080` | `http://192.168.1.85:8080` | Bearer JWT | Spring Boot 4 / Java 25 |
| **Keycloak Console** | `http://localhost:8081/admin` | `http://192.168.1.85:8081/admin` | `kcadmin` / `change-me` | Consola Realm `asistencias-uco` |
| **Grafana Logs** | `http://localhost:3000` | `http://192.168.1.85:3000` | `admin` / `change-me` | [Dashboard Logs Backend](http://localhost:3000/d/asistencias-uco-logs/asistencias-uco-logs-del-backend) |
| **SQL Server** | `localhost:1433` | `192.168.1.85:1433` | `sa` / `TuPasswordSeguro123` | Motor de base de datos relacional |

---

## 3. Historial de Decisiones y Correcciones Técnicas

### A. Validación de Token JWT y CORS
* **Problema:** Rechazo `401 Unauthorized` por discrepancia de issuer (`127.0.0.1` vs `localhost`), formato de claim de audiencia (`aud` como String único) y falta de headers CORS en red local.
* **Resolución en `SecurityConfig.java`:**
  * Uso de `sub` como principal de autenticación.
  * Validador de emisor flexible admitiendo cualquier host con terminación `/realms/asistencias-uco`.
  * Validación polimórfica de `aud` para cadenas y colecciones (`asistencias-api`, `account`, `asistencias-uco-frontend`).
  * Inclusión de orígenes CORS para `localhost` e IP LAN (`192.168.1.85`).
  * Resolución de usuario en `UserScopeService.java` mediante `email` o `preferred_username`.

### B. Autenticación Directa (Direct Grants)
* **Decisión:** Sustitución de la pantalla de login externa de Keycloak por formulario institucional nativo en Angular (`login.component.ts`).
* **Mecanismo:** Flujo Resource Owner Password Credentials (`/protocol/openid-connect/token`). Persistencia local del token y guardias `AuthGuard` nativas con redirección interna a `/login`.

### C. Alineación de Roles en Realm
* **Problema:** Usuarios `estudiante1`, `coordinador1`, `decano1` y `admin1` carecían de asignación formal de roles en Keycloak, cayendo en el fallback por defecto `DOCENTE`.
* **Resolución:** Asignación explícita mediante Admin API de roles institucionales canónicos (`ADMINISTRADOR`, `DECANO`, `COORDINADOR`, `DOCENTE`, `ESTUDIANTE`).

### D. Parámetros de Sesión y Vigencia
* **Configuración del Realm:**
  * `accessTokenLifespan = 86400` (24 horas).
  * `ssoSessionIdleTimeout = 86400` (24 horas).
* **Objetivo:** Prevenir caducidad de tokens durante pruebas y desarrollo continuo.

---
**Documentos Relacionados:**
* [Centro Maestro de Documentación](./README.md) - Mapa documental global.
* [Arquitectura Integral](./arquitectura-integral.md) - Modelo de seguridad y contexto de sesión.
* [Catálogo de Scripts](../scripts/README.md) - Comandos de inicio de Keycloak y pruebas de endpoints.
