# Módulo de Seguridad Institucional — Security Baseline v0.1.6

> **Ámbito:** Infraestructura Transversal y Seguridad Delegada  
> **Organización Proveedora:** [`Seguridad-UCO`](https://github.com/Seguridad-UCO)  
> **Versión Oficial:** `0.1.6`  
> **Fecha de Integración:** Octubre 2026  

---

## 1. Arquitectura General de Seguridad

El módulo institucional de seguridad desacopla la **identidad**, la **evaluación de políticas (PEP/PDP)** y la **lógica de negocio** de Gestión de Asistencia UCO:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. Frontend Host (Angular 19 en :4200)                                      │
│    • Inyecta el Microfrontend Security UI en /app/seguridad.                 │
│    • Administra recursos, roles y perfiles delegados en el puerto 5175.     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ HTTP / REST (Bearer JWT / Session)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. Backend (Spring MVC / Clean Architecture en :8080)                       │
│    • SecurityBaselinePepFilter intercepta peticiones tras Bearer JWT.       │
│    • Consulta decisión a PEP en /internal/v1/embedded-access-decisions.     │
│    • Política Fail-Closed: 503 Service Unavailable si PEP no responde.      │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ POST Decision
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. Stack Security Baseline (Docker Compose v0.1.6)                          │
│    • Keycloak (19090): Identidad central, Realm 'security-baseline'.        │
│    • PDP / BFF (18080): Motor de políticas OPA, base SurrealDB y Redis.     │
│    • PEP (18081): Policy Enforcement Point HTTP.                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mapa de Servicios, Puertos y Componentes

| Componente | Repositorio / Imagen | Puerto | Descripción |
| :--- | :--- | :--- | :--- |
| **Keycloak IAM** | `davidalzate/security-keycloak-local:0.1.6` | `19090` | Servidor OIDC/OAuth2 con Realm `security-baseline`. |
| **PDP / BFF** | `davidalzate/security-pdp:0.1.6` | `18080` | Motor de decisión y sesión web de administración. |
| **PEP Ingress** | `davidalzate/security-pep:0.1.6` | `18081` | Evaluador de políticas consumido por el backend. |
| **Security UI** | `github.com/Seguridad-UCO/security-ui` | `5175` | Microfrontend ESM exportando `remote.mount()` (`dist/security-administration.js`). |
| **Security Web**| `github.com/Seguridad-UCO/securityBaseline-vue` | `5173` | Panel de administración de seguridad en Vue 3. |

---

## 3. Datos y Credenciales de Configuración

* **Aplicación Registrada:** `asistencias-backend`
* **Entorno:** `local`
* **URL de API Registrada:** `http://localhost:8080`
* **Credencial de Aplicación (`PEP_REGISTRATION_TOKEN`):**
  * Variable de entorno: `SECURITY_BASELINE_PEP_APPLICATION_CREDENTIAL`
  * Administrada fuera de Git en archivos `.env` locales.
* **Usuario Administrador del Realm de Seguridad:**
  * **Usuario:** `security-demo`
  * **Contraseña:** `security-demo`
  * **Correo:** `security-demo@local.test`

---

## 4. Guía de Ejecución Local

### Paso 1: Levantar el Stack Docker de Seguridad
```powershell
cd Complementos\Seguridad\security-baseline-local
docker compose up -d
```
Comprobar salud:
* `http://localhost:18080/actuator/health` ➔ `{"status":"UP"}`
* `http://localhost:18081/actuator/health` ➔ `{"status":"UP"}`

### Paso 2: Servir el Microfrontend (Security UI)
```powershell
cd Complementos\Seguridad\security-ui
npm run preview
```
El bundle quedará expuesto en `http://localhost:5175/security-administration.js`.

### Paso 3: Servir el Panel de Gestión (Vue 3)
```powershell
cd Complementos\Seguridad\security-vue
npm run dev
```
Acceder en el navegador a `http://localhost:5173` con `security-demo / security-demo`.

### Paso 4: Visualizar en el Frontend Angular
Ingresar a:
`http://localhost:4200/app/seguridad`

---

## 5. Sincronización de Usuarios Institucionales

Para registrar o sincronizar un nuevo usuario con el componente de seguridad:
1. Crear el usuario en el Realm `security-baseline` de Keycloak (puerto `19090`):
   ```powershell
   docker exec security-baseline-keycloak-1 /opt/keycloak/bin/kcadm.sh create users -r security-baseline -s username="nuevo.docente@uco.edu.co" -s email="nuevo.docente@uco.edu.co" -s firstName="Nuevo" -s lastName="Docente" -s enabled=true -s emailVerified=true
   docker exec security-baseline-keycloak-1 /opt/keycloak/bin/kcadm.sh set-password -r security-baseline --username "nuevo.docente@uco.edu.co" --new-password "Test1234!"
   ```
2. En el panel de administración (`http://localhost:5173` o en `/app/seguridad`):
   * El usuario aparecerá en la pestaña **Usuarios**.
   * Ir a **Asignaciones** ➔ Asignar el rol/perfil correspondiente para la aplicación `asistencias-backend`.
