# VAL-oleada7-pendientes-transversales - PLAN

Fecha: 2026-11-15. Rama de Infra `chore/VAL-oleada7-pendientes` desde `origin/develop` (9bc7eb4); rama del backend
`fix/VAL-oleada7-backend` desde `repo-antiguo/develop` (aa553578). Los dos cambios se hacen en worktrees aparte: los
checkouts principales de BD y backend los está usando otro agente para el conjunto de datos de las pruebas manuales
(`GestioAsistenciaDB/scripts/datos-prueba/` y `provision_asistencias.py dataset-users`).

## 1. Origen

Pendientes que no son del frontend en los work items de validación (oleadas 1 a 3 y `VAL-pendientes-rea-msg`) de
backend, BD e Infra, más la revisión de registros duplicados del 2026-11-15. Se revisó cada uno contra `develop`:

| Ítem | Estado en `develop` | Decisión |
| :--- | :--- | :--- |
| H2: `/actuator/prometheus` 401 en el puerto de gestión | Corregido (`ManagementEndpointsSecurityConfiguration`) | Cerrar en este plan como verificado |
| H3: ClamAV caído responde 500 | Corregido (`ERR_ANTIVIRUS_NO_DISPONIBLE`, 503) | Cerrar como verificado |
| `e2e_provisioning.py` y `e2e_profile_assignment.py` con `POST /api/v1/usuarios` | Corregido (alta con ámbito de decano) | Cerrar como verificado |
| ROL-12, comprobación 18 del E2E de 5 roles | Corregido (PR del backend #149) | Cerrar como verificado |
| `infra.ps1 verify` falla en el escaneo de secretos | Abierto: falso positivo en `.github/workflows/infra-validation.yml:44` | Paso A |
| Duplicados y varios roles | Abierto | Paso B (registro) y paso F (decisión) |
| H4: petición en vuelo con el PEP detenido esperó más de 30 s | Abierto | Paso C |
| Cachés de parámetros y mensajes sin vencimiento (2 réplicas) | Abierto | Paso D |
| H5: 502 durante ≈5 s al caer una réplica | Abierto | Paso E |
| Permisos de más en el PDP del laboratorio (`--prune`) | Abierto, aprobado por John, lo ejecuta José Alejandro | Paso G (requiere autorización explícita) |
| SEC-11, REA-01, F12-08, H1, LB-005 (TD-003), F12-10, carga con escrituras | Externos o requieren staging | Sección 4, sin cambios |

## 2. Pasos

### A. Falso positivo del escaneo de secretos (Infra)

- Causa: `check-secrets.ps1` busca `PASSWORD` seguido de `=` y un valor entre comillas. La línea 44 del workflow es un
  `grep -q '^GRAFANA_ADMIN_PASSWORD=' .env.example` (comprueba que la variable esté declarada, no tiene valor).
- Cambio: escribir el mismo patrón como `'^GRAFANA_ADMIN_PASSWORD[=]'`. Es equivalente para `grep` y ya no coincide con la
  regla. No se toca el escáner ni se agregan exclusiones: la regla queda igual de estricta.
- Prueba: `infra.ps1 verify` pasa del paso 1 al 3; `check-secrets.ps1 -SelfCheck` sigue verde.

### B. Registro de TD-093 (Infra)

- `docs/baseline/TECHNICAL_DEBT.md`: fila en la tabla y sección TD-093 con los ocho hallazgos de la revisión de
  duplicados (decano y coordinador, mismo número con otro tipo, rol inactivo, coordinador repetido, sin índices únicos
  ni bloqueos, segundo rol sin acceso en el PDP, docente fuera de alcance, documento `INT`).
- Sin cambios de código: la corrección queda para después del conjunto de datos de las pruebas manuales (paso F).

### C. H4: límite de tiempo del cliente del PEP (backend)

- Hipótesis: `java.net.http.HttpRequest.timeout` debería cortar a los 5 s. La evidencia (un solo 504 de Traefik a los
  30 s, la petición que estaba en vuelo al detener el contenedor) no prueba si se cortó o no el cliente.
- Prueba en rojo primero (`SecurityBaselinePepClientTest`): servidor local que acepta la conexión y no responde, y otro que
  responde los encabezados y no termina el cuerpo; con `request-timeout` corto, `evaluate` debe devolver `UNAVAILABLE`
  antes de `request-timeout + margen`.
- Si la prueba falla: corregir el cliente (cuerpo descartado con límite, o `sendAsync(...).get(timeout)` con cancelación).
  Si pasa: el cliente ya cumple; se deja la prueba como regresión y se documenta que la espera vino de otra parte
  (ventana del contenedor deteniéndose). No se repite la prueba con el PEP del laboratorio mientras el otro agente lo usa.

### D. Cachés de parámetros y mensajes con vencimiento (backend)

- Hoy `ParameterCatalogJpaRepository` y `MessageCatalogJpaRepository` usan un `ConcurrentHashMap` sin vencimiento; con dos
  réplicas, una edición solo invalida la réplica que la atendió.
- Cambio: entradas con instante de carga y vencimiento configurable (`ASISTENCIAS_CATALOGO_SQL_CACHE_TTL`, por defecto
  60 s, como las plantillas de notificación). La invalidación explícita sigue igual. Sin dependencias nuevas.
- Pruebas: con un reloj inyectable, una entrada vencida se vuelve a leer y una vigente no; la invalidación explícita sigue
  funcionando; la propiedad rechaza valores fuera de rango.
- Afecta solo a los proveedores SQL (respaldo); el Catálogo de Parámetros y MessageUcoLab tienen su propia caché.

### E. H5: reintento ante errores de red en el Traefik de réplicas (Infra)

- `components/proxy/replicas/dynamic/replicas.yml`: middleware `retry` (`attempts: 2`, `initialInterval: 100ms`) en el
  router `backend-replicas`. Traefik reintenta solo si no recibió respuesta del servidor, y el servicio ponderado manda el
  reintento a la otra réplica.
- Riesgo: un POST que la réplica procesó pero cuya conexión se cortó antes de responder podría repetirse. Los SP de
  escritura ya validan duplicados (sesiones, tomas, matrícula); se documenta en el comentario del archivo.
- Prueba: `docker compose -f docker-compose.replicas.yml config` y validación de la configuración dinámica con Traefik.
  La medición con carga (`scripts/load` del backend) se repite cuando el laboratorio esté libre.

### F. Segundo rol sin acceso en el PDP (decisión)

- El script de conjunto de datos del otro agente ya asigna en el PDP todos los perfiles de cada usuario de prueba, así
  que los usuarios sembrados con varios roles tendrán acceso.
- Quedan los roles que se agreguen desde la aplicación durante las pruebas (por ejemplo, hacer coordinador a un docente).
  Opciones: (1) encender la sincronización de perfiles en el laboratorio (`provision_asistencias.py keycloak` con la
  audiencia del PDP para `asistencias-provisioner` y `SECURITY_BASELINE_PDP_PROFILE_SYNC_ENABLED=true`); la API 0.1.7 del
  PDP no distingue administradores con esa audiencia, por eso no está por defecto. (2) Dejarla apagada y poner la
  reconciliación en el guion de pruebas manuales. Decide el responsable; no se cambia sin esa decisión.

### G. Permisos de más en el PDP del laboratorio

- `provision_asistencias.py verify` informa deriva; `pdp --prune` la revoca. Está aprobado por John y asignado a José
  Alejandro. Se ejecuta solo con autorización explícita en la conversación y cuando el otro agente haya terminado de
  aprovisionar el conjunto de datos.

### H. Inventario de rutas para el PDP (backend, hallado durante la oleada)

- `MensajesInterfazPublicaController` usa `@RequestMapping(RUTA_BASE)` y `extract_endpoints.py` solo acepta literales
  (TD-087): la suite offline del extractor y `provision_asistencias.py catalog|verify|pdp` fallan en `develop`.
- Cambio: literal en la anotación, `RUTA_BASE` se conserva para el filtro y una prueba comprueba que son iguales. No se
  cambia el extractor: rechazar constantes es intencional ("no adivina").

## 3. Entregables y gates

| Repo | Rama | Commits | Gates |
| :--- | :--- | :--- | :--- |
| Infra | `chore/VAL-oleada7-pendientes` | `docs(docs): registrar TD-093`, `docs(docs): plan VAL-oleada7`, `ci(scripts): evitar falso positivo del escaneo de secretos`, `chore(proxy): reintentar errores de red entre réplicas`, `docs(docs): validación VAL-oleada7` | `infra.ps1 verify`, `docker compose config`, CI del PR |
| Backend | `fix/VAL-oleada7-backend` | `test(backend/adapter): ...` (rojo), `fix(backend/adapter): ...`, `fix(backend/adapter): vencimiento de cachés SQL`, `docs(docs): validación` | `mvnw test` de las clases tocadas y de arquitectura, `mvnw verify` una vez al final, CI del PR |

Sin cambios de contratos WORM, de BD ni de frontend. Docente no se toca.

## 4. Fuera de alcance (externos o con entorno)

- SEC-11: Key Vault con Azure real.
- REA-01 y F12-08: p95 y dimensionamiento del pool con hardware de staging.
- H1: caché de decisiones del PDP (equipo de Security Baseline).
- LB-005 / TD-003: bus distribuido para SSE y límite de subidas por instancia.
- F12-10: entorno de producción documentado y prueba del outbox con SMTP real.
- Carga con escrituras: requiere BD desechable (`e2e_safety.py`).
- Corrección de TD-093 (BD y backend): después de las pruebas manuales, con su propio plan y contrato.
