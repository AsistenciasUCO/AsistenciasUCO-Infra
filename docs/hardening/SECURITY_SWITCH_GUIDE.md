# 🛡️ Guía Operativa: Switch de Alternancia de Seguridad (Keycloak Propio vs Security Baseline)

> **Ámbito:** Infraestructura Transversal, Backend Spring Boot y Frontend Angular  
> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Versión:** 1.0.0  
> **Fecha:** Octubre 2026  

---

## 1. Propósito y Contexto

El sistema cuenta con dos arquitecturas de seguridad plenamente implementadas:
1. **Modo Propio Institucional (`own`) [ACTIVO]:** Utiliza el servidor Keycloak propio institucional (`asistencias-uco` en puerto `8081`), validación directa de JWT en Spring Security y autenticación directa (Resource Owner Password Credentials) en Angular.
2. **Modo Security Baseline (`baseline`) [STANDBY]:** Utiliza el componente transversal delegado provisto por el equipo externo (`security-baseline` v0.1.6 en puerto `19090`), con evaluación de políticas mediante PDP (`18080`) y Policy Enforcement Point HTTP (`PEP` en `18081`).

Para permitir que el equipo de desarrollo de Asistencias trabaje sin bloqueos mientras el equipo externo estabiliza su componente, se implementó un **mecanismo de alternancia (switch)** no destructivo que permite cambiar entre ambos modos de forma atómica y transparente, sin alterar código de negocio.

---

## 2. Matriz de Configuración por Modo

| Parámetro / Componente | Modo Propio (`own`) | Modo Security Baseline (`baseline`) |
| :--- | :--- | :--- |
| **Backend: Issuer URI** | `http://localhost:8081/realms/asistencias-uco` | `http://keycloak.localhost:19090/realms/security-baseline` |
| **Backend: PEP Enforcement** | `false` (Omitido) | `true` (Inspección en `http://localhost:18081`) |
| **Backend: Default Config** | `security.pep.enforcement.enabled = false` | Requiere `SECURITY_PEP_ENFORCEMENT_ENABLED = true` |
| **Frontend: Keycloak URL** | `http://127.0.0.1:8081` | `http://127.0.0.1:19090` |
| **Frontend: Realm** | `asistencias-uco` | `security-baseline` |
| **Frontend: Flag Baseline** | `SECURITY_BASELINE_ENABLED = false` | `SECURITY_BASELINE_ENABLED = true` |
| **Contenedor IAM en Docker** | `asistencias-uco-security` (o `keycloak_asistencias`: 8081) | `security-baseline-keycloak-1` (puerto 19090) |

---

## 3. Uso del Switch de Seguridad mediante el CLI Maestro (`infra.ps1`)

Desde la raíz del repositorio o dentro de `AsistenciasUCO-Infra/`:

### A. Consultar el estado activo actual
```powershell
.\AsistenciasUCO-Infra\infra.ps1 security-status
```
Salida esperada:
```text
==============================================================================
 ESTADO ACTUAL DEL SWITCH DE SEGURIDAD
==============================================================================
  * Backend  : KEYCLOAK PROPIO (Institucional: PEP inactivo, Keycloak 8081)
  * Frontend : KEYCLOAK PROPIO (Keycloak 8081, realm asistencias-uco)
==============================================================================
```

### B. Cambiar a Keycloak Propio Institucional (`own`)
```powershell
.\AsistenciasUCO-Infra\infra.ps1 security-switch -Mode own
```
* Sincroniza `GestioAsistenciaBackend\.env`, `GestioAsistenciaFrontend\public\assets\env.js` y `GestioAsistenciaFrontend\.env`.
* Desactiva el filtro PEP en Backend.
* Apunta el Frontend y el Backend a `http://localhost:8081` y realm `asistencias-uco`.

### C. Cambiar a Security Baseline Delegado (`baseline`)
```powershell
.\AsistenciasUCO-Infra\infra.ps1 security-switch -Mode baseline
```
* Sincroniza los entornos para apuntar a Keycloak en puerto `19090` y realm `security-baseline`.
* Activa el filtro PEP en Backend (`18081`).
* Recuerda levantar el stack de seguridad con:
  ```powershell
  .\AsistenciasUCO-Infra\infra.ps1 security-up
  ```

---

## 4. Directorio de Usuarios y Credenciales de Desarrollo (Modo Propio)

En el modo institucional propio (`asistencias-uco`), las credenciales unificadas de desarrollo son:

* **Contraseña común de desarrollo:** `Test1234!`

| Rol Realm | Usuario / Correo | GUID `dbo.Usuario` en BD | Ruta Principal en SPA |
| :--- | :--- | :--- | :--- |
| `ADMINISTRADOR` | `admin.institucional@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000000` | `/app/admin/decanos` |
| `DECANO` | `decano.ingenieria@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000001` | `/app/decano/coordinadores` |
| `COORDINADOR` | `coordinador.sistemas@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000002` | `/app/coordinador/docentes` |
| `DOCENTE` | `maria.rostagno@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000003` | `/app/docente/grupos` |
| `ESTUDIANTE` | `carlos.zapata@uco.edu.co` | `E1F2A3B4-0000-0000-0000-000000000004` | `/app/estudiante/horarios` |

---

## 5. Arquitectura del Código Preservado

1. **Backend (`GestioAsistenciaBackend`):**
   - [`SecurityPepEnforcementFilter.java`](file:///c:/Proyectos/GestioAsistencia/GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/security/SecurityPepEnforcementFilter.java): Permanece en el código fuente. Implementa `shouldNotFilter()`, donde `if (!enabled) return true;` garantiza que cuando el switch está en `own`, el filtro se omite completamente sin costo de rendimiento ni llamadas HTTP.
   - [`SecurityConfig.java`](file:///c:/Proyectos/GestioAsistencia/GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/infrastructure/config/security/SecurityConfig.java): Inyecta `@Value("${security.pep.enforcement.enabled:false}")`, garantizando seguridad por defecto en modo propio.
2. **Frontend (`GestioAsistenciaFrontend`):**
   - [`public/assets/env.js`](file:///c:/Proyectos/GestioAsistencia/GestioAsistenciaFrontend/public/assets/env.js): Modificable en caliente en tiempo de ejecución sin requerir recompilación (`ng build`).
   - [`src/environments/environment.ts`](file:///c:/Proyectos/GestioAsistencia/GestioAsistenciaFrontend/src/environments/environment.ts): Mantiene fallbacks alineados con `asistencias-uco` en puerto `8081`.
   - [`auth.service.ts`](file:///c:/Proyectos/GestioAsistencia/GestioAsistenciaFrontend/src/app/core/services/auth.service.ts): Mantiene tipado extendido (`numeroIdentificacion`) y scope OIDC estándar (`openid email profile`), 100% retrocompatible con ambos proveedores.
