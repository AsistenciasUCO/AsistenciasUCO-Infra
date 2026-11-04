# Guía Operativa: Actualización de Security Baseline y retiro del Keycloak propio del arranque

> **Ámbito:** Infraestructura Transversal  
> **Ecosistema:** Sistema de Gestión de Asistencia UCO  
> **Versión:** 1.0.0 · **Fecha:** Noviembre 2026  
> **Relacionado:** [`SECURITY_SWITCH_GUIDE.md`](SECURITY_SWITCH_GUIDE.md), [`SECURITY_BASELINE_INTEGRATION.md`](../governance/SECURITY_BASELINE_INTEGRATION.md)

---

## 1. Qué cambió

| Antes | Ahora |
| :--- | :--- |
| `infra.ps1 security-up` levantaba el compose de `Complementos/Seguridad` (Security Baseline **0.1.7**, puertos en `0.0.0.0`, proyecto `security-baseline`) | Levanta el compose **endurecido del Backend** (`GestioAsistenciaBackend/infra/security-baseline/compose.yaml`, versión **0.1.9**, puertos solo `127.0.0.1`, proyecto `asistencias-security-lab`) |
| El perfil `core` (y `full`) levantaba además **Keycloak propio + Postgres** (puerto 8081) | `core` = SQL Server + Security Baseline. El Keycloak propio solo arranca con `-Profile legacy` |
| `start-dev.ps1` esperaba, reconciliaba (`bootstrap.ps1`) y sembraba usuarios (`seed-users.ps1`) en el Keycloak propio siempre | Solo lo hace con `-Profile legacy` |
| Secretos literales dentro de un compose ajeno | `%USERPROFILE%\.asistencias-security-lab\lab.env` (fuera de Git, ACL solo del usuario) |

`Complementos/` **no se modificó**: sigue siendo la fuente de la *pantalla* de seguridad (`securityBaseline-vue`, puerto 5173), que
`security-ui`/`-WithUi` ejecuta sin cambios.

## 2. Imágenes (equipo de seguridad, Docker Hub `davidalzate/*`)

| Imagen | 0.1.7 | 0.1.8 → 0.1.11 |
| :--- | :--- | :--- |
| `security-pdp` | 192 MB | **144 MB** |
| `security-pep` | 162 MB | **118 MB** |
| `security-keycloak-local` | 255 MB | 255 MB |
| `security-opa` | 23 MB | 23 MB |

Versión adoptada: **0.1.9**, la validada por el Backend con evidencia por rol (`docs/security/…`). Existen `0.1.10` y `0.1.11`
(publicadas el 2026-11-02/03); no están validadas en este proyecto. Para probarlas basta cambiar `SECURITY_VERSION` en `lab.env`.

## 3. Migración realizada (no destructiva)

1. `lab.env` generado a partir de la instalación previa, para que los secretos coincidan con los datos existentes (verificado: el secreto interno del PEP obtiene token contra el realm actual).
2. Imágenes `0.1.9` descargadas; stack anterior **detenido** (no eliminado).
3. Datos copiados a los volúmenes nuevos del compose del Backend:

| Volumen anterior (conservado como respaldo) | Volumen nuevo |
| :--- | :--- |
| `security-baseline_keycloak-data` (solo `data/h2`) | `asistencias-security-lab_asistencias-security-lab-keycloak-data` (en `data/h2`, más el `import/` de la imagen) |
| `security-baseline_surrealdb-data` | `asistencias-security-lab_asistencias-security-lab-surrealdb-data` |
| `security-baseline_redis-data` | `asistencias-security-lab_asistencias-security-lab-redis-data` |

4. Orígenes permitidos del PDP ahora **parametrizados** en `lab.env`
   (`PDP_CORS_ALLOWED_ORIGINS`, `PDP_LOGIN_ALLOWED_RETURN_ORIGINS`, `PDP_SECURITY_LOGIN_ALLOWED_RETURN_ORIGINS`) con 4200, 5173, 5174 (MessageUcoLab) y 5175.

Cuando se confirme que todo funciona, los volúmenes `security-baseline_*` y los contenedores `security-baseline-*` pueden eliminarse
**solo con autorización explícita** (nunca `docker volume prune`).

## 4. Orden de arranque (importante)

La red fija del compose de seguridad (`172.31.240.0/24`) choca con redes que Docker asigna solo a otros stacks
(p. ej. `messageucolab_pulsar-network` tomó `172.31.0.0/16`). **Levanta siempre la seguridad primero:**

```powershell
.\AsistenciasUCO-Infra\infra.ps1 security-up        # 1) Security Baseline (127.0.0.1)
.\AsistenciasUCO-Infra\infra.ps1 messages-up-light  # 2) MessageUcoLab (toma otro rango libre)
```

Si aparece `Pool overlaps with other one on this address space`: `infra.ps1 messages-down` (conserva volúmenes), luego `security-up` y `messages-up-light`.

## 5. Comandos

| Comando | Acción |
| :--- | :--- |
| `security-up` / `security-down` | Levanta / detiene (sin `-v`) Security Baseline del Backend |
| `security-ui` | Lanza la pantalla de seguridad (5173) |
| `start-dev` (`-Profile core`) | SQL Server + Security Baseline |
| `start-dev -Profile legacy` | Además, Keycloak propio (8081) y su siembra |

## 6. Hallazgos para el equipo de seguridad

* **S-01:** el compose de `Complementos` 0.1.7 no reenviaba al PDP `PDP_CORS_ALLOWED_ORIGINS` / `PDP_LOGIN_ALLOWED_RETURN_ORIGINS`, por lo que el paso 1 de la guía de MessageUcoLab (editar el `.env`) no tenía efecto.
* **S-02:** secretos literales (contraseña admin de Keycloak, de SurrealDB y del cliente BFF) en el compose entregado y secreto por defecto del cliente técnico del PEP publicado en el `application.properties` del JAR.
* **S-03:** puertos publicados en `0.0.0.0` en la distribución original.
* **S-04:** red con subred fija en el compose de laboratorio; sugerible no fijarla o documentar el rango para evitar solapes.

## 7. Aprovisionamiento de Asistencias en el baseline (Fase B, ejecutado el 2026-11-03)

Se ejecutó `GestioAsistenciaBackend/infra/security-baseline/scripts/provision_asistencias.py` (idempotente) sobre la instalación migrada.
Con el Python de Windows (`python3.12.exe` de WindowsApps); el `python` de MSYS no ve `USERPROFILE` ni rutas Windows.

| Paso | Resultado |
| :--- | :--- |
| `catalog` (offline) | 159 endpoints, 0 sin regla, 0 obsoletos |
| `keycloak` | Clientes `asistencias-api`, `asistencias-uco-spa` (PKCE S256) y `asistencias-provisioner` creados; secreto del provisioner en `lab.env` |
| `pdp` | Aplicación `asistencias-uco`: 159 recursos, 298 concesiones, 5 perfiles; estado final sin faltantes ni sobrantes |
| `users` | 5 usuarios de prueba (`uco-administrador`, `uco-decano`, `uco-coordinador`, `uco-docente`, `uco-estudiante`); sesión BFF 200 y perfil asignado (201) |
| `verify` | `clean: true` |
| `verify-decisions` | **979 decisiones reales del PEP, 0 fallos** |

Verificación extremo a extremo (Backend en `baseline` con `start-backend-baseline.ps1`; token PKCE como el navegador):

| Rol | `/usuarios/perfil` | `/decano/coordinadores` | `/docentes` |
| :--- | :---: | :---: | :---: |
| ADMINISTRADOR | 200 | 403 | 200 |
| DECANO | 200 | 200 | 403 |
| COORDINADOR | 200 | 403 | 200 |
| DOCENTE | 200 | 403 | 403 |
| ESTUDIANTE | 200 | 403 | 403 |

Coincide con `access-catalog.json` (`GET /docentes` solo ADMINISTRADOR y COORDINADOR).

### Requisitos que el script da por hechos (hallazgos S-05 a S-07)

* **S-05:** `provision_asistencias.py pdp` exige el usuario `lab-pdp-admin` con rol `ADMIN` en `asistencias-backend` y su clave `LAB_USER_LAB_PDP_ADMIN_PASSWORD` en `lab.env`; ningún script del repo lo crea. Aquí se creó con `lab_pdp.ensure_lab_user` + primer login BFF y se le concedió `ADMIN` desde la pantalla (con autorización explícita).
* **S-06:** hay **dos roles `ADMIN`** (uno por aplicación) con el mismo nombre en el desplegable de asignación; elegir el de otra aplicación devuelve "La aplicación … está fuera del alcance del rol".
* **S-07:** la aplicación anterior `asistencias-backend` (141 recursos de un registro previo) sigue en el PDP junto a la nueva `asistencias-uco`. Pendiente decidir su retiro; no se eliminó.

### Notas operativas

* El `.env` del Backend conserva `APP_ADAPTERS_*_PROVIDER=keycloak`, pero el lanzador fuerza `baseline` por variable de proceso (y retira el selector de identidad), así que no hace falta editarlo.
* La JVM necesita `-Djdk.net.unixdomain.tmpdir=C:\jtmp` (`JAVA_TOOL_OPTIONS`) en equipos con espacio en la ruta de `TEMP`; sin eso falla con `Invalid argument: connect`.
* Frontend: `public/assets/env.js` quedó con `SECURITY_PROVIDER='baseline'` y `SECURITY_BASELINE_APPLICATION_ID` de esta máquina (`ASISTENCIAS_PDP_APPLICATION_ID` de `lab.env`). Es un cambio **local**: no se debe commitear.
