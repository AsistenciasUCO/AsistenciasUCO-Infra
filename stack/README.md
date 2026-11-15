# Contenedores por secciones (`infra.ps1 stack`)

El laboratorio completo no cabe en la VM de Docker (10 GB, `%USERPROFILE%\.wslconfig`), así que se levanta **por
secciones** o por **escenarios de prueba**. Todo está descrito en [`secciones.json`](secciones.json); el comando es
[`scripts/orchestration/stack.ps1`](../scripts/orchestration/stack.ps1).

```powershell
.\AsistenciasUCO-Infra\infra.ps1 stack list              # secciones y escenarios
.\AsistenciasUCO-Infra\infra.ps1 stack plan mensajes     # qué levantaría y cuánta memoria (no cambia nada)
.\AsistenciasUCO-Infra\infra.ps1 stack up basico         # levanta el escenario y apaga lo que no usa
.\AsistenciasUCO-Infra\infra.ps1 stack up ext-mensajes -Conservar   # agrega una sección sin apagar las demás
.\AsistenciasUCO-Infra\infra.ps1 stack status            # estado y memoria por sección
.\AsistenciasUCO-Infra\infra.ps1 stack down              # todo menos asis-datos (nunca borra volúmenes)
.\AsistenciasUCO-Infra\infra.ps1 stack build             # imágenes asistencias-backend/frontend:develop
```

## Secciones

Docker Desktop agrupa los contenedores por proyecto: `asis-*` es de Asistencias UCO y `ext-*` son componentes de los
otros equipos.

| Sección | Qué tiene | Memoria | Cuándo |
| :--- | :--- | ---: | :--- |
| `asis-datos` | SQL Server (`sql_server_asistencias`) y MinIO | 2,5 GB | Siempre (único con reinicio automático) |
| `ext-seguridad` | Seguridad 0.1.13 del equipo (Keycloak, PDP, PEP, OPA) | 1,6 GB | Casi siempre |
| `ext-mensajes` | MessageUcoLab 0.3.0 (Kong, Pulsar, app; sin observabilidad ni Ollama) | 3,3 GB | Pruebas de mensajes |
| `ext-parametros` | Catálogo de Parámetros 0.1.7 y su microfrontend | 0,6 GB | Pruebas de parámetros |
| `asis-antivirus` | ClamAV | 1,3 GB | Pruebas de soportes |
| `asis-obs` | Grafana, Prometheus, Loki, Tempo, Alloy | 0,9 GB | Diagnóstico |
| `asis-contingencia` | Keycloak propio (realm `asistencias-uco`) | 0,9 GB | **Solo emergencias**, si falla la Seguridad del equipo |
| `asis-app` | Backend y Frontend (imágenes de `develop`) | 1,2 GB | Pruebas funcionales |

`ext-mensajes` y `ext-parametros` requieren `ext-seguridad` (se agrega solo). `asis-contingencia` y `ext-parametros` no
pueden convivir (ambos usan el puerto 8081 del PC).

## Escenarios

| Escenario | Secciones | Pruebas |
| :--- | :--- | :--- |
| `minimo` | datos | Gate de BD |
| `basico` | datos, seguridad, app | HU de los 5 roles (mensajes y parámetros desde la BD) |
| `mensajes` | `basico` + mensajes | Catálogo de mensajes, avisos → BD, textos `UI###` |
| `parametros` | `basico` + parámetros | Catálogo de Parámetros |
| `completo` | `basico` + mensajes + parámetros | Flujos completos (9,2 GB: no agregar más) |
| `soportes` | `basico` + antivirus | Adjuntos |
| `observabilidad` | `basico` + obs | Trazas y logs por `correlationId` |
| `contingencia` | datos, contingencia, app | Arranque sin la Seguridad del equipo |

## Configuración automática de `asis-app`

Con `asis-app`, `stack up` genera `stack/generado/backend.env` y `frontend.env` (fuera de Git: llevan secretos) a partir
del `.env` del Backend, de `lab.env` y de los `env.js` locales del Frontend, según lo que esté arriba:

| Si está arriba… | El Backend usa… |
| :--- | :--- |
| `ext-seguridad` | proveedor `baseline` (PEP/PDP/Keycloak dentro de `asis-red`) |
| `asis-contingencia` (sin `ext-seguridad`) | proveedor `legacy` |
| `ext-mensajes` | catálogo de mensajes `messageucolab` (Kong y Pulsar por `asis-red`); si no, `sqlserver` y sin avisos |
| `ext-parametros` | catálogo de parámetros `catalogoparametros`; si no, `sqlserver` |
| `asis-obs` | exporta trazas a Alloy |

El Frontend activa los textos del catálogo (`MENSAJES_UI_DESDE_CATALOGO`) solo con `ext-mensajes`.

## Validación de los escenarios (2026-11-15)

| Escenario | Resultado |
| :--- | :--- |
| `basico` | API 200 para los 5 roles y 401 sin token; login real en la SPA del contenedor |
| `mensajes` | Suscripción a Pulsar, reconciliación de 482 mensajes (0 fallidos), cambio en MessageUcoLab → BD en 2,8 s, textos `UI###` y alertas con texto |
| `parametros` | El Backend lee el Catálogo (un valor distinto solo en `dbo.CatalogoParametro` no se usa); microfrontend y API por el proxy de la SPA |
| `soportes` | Subida → ClamAV (`CLEAN`) → MinIO → descarga idéntica; ClamAV detecta EICAR |
| `observabilidad` | Trazas en Tempo, logs en Loki por `correlationId`, métricas en Prometheus (`up`) |
| `contingencia` | Token del Keycloak propio (`iss` `localhost:8081`) aceptado por el Backend en contenedor; SPA en modo `legacy` |

Ajustes que salieron de estas pruebas:

* `ext-mensajes` usa su propio volumen de Pulsar (`ext-mensajes-pulsar-data`): el anterior quedó con ledgers que el bookie ya no
  podía escribir (`Not enough non-faulty bookies available`, caso descrito en el README del kit). El volumen viejo se conserva.
* La salud de `ext-mensajes` incluye `brokers/health` de Pulsar y la de `ext-parametros` el `actuator/health` del Catálogo: la app
  no arranca hasta que estén listos (antes el Backend se suscribía o consultaba demasiado pronto).
* `asis-app` monta `GestioAsistenciaBackend/infra/observability/logs` (Alloy → Loki, archivo `backend-contenedor.jsonl`) y publica
  el puerto de gestión `8090` solo en `127.0.0.1`; el Backend lo abre (`MANAGEMENT_SERVER_ADDRESS=0.0.0.0`) solo con `asis-obs`.
* El Backend reintenta la suscripción a Pulsar si falla (PR del Backend `fix/int003-reintento-suscripcion-pulsar`).

## Cómo está armado

* Cada sección aplica un archivo propio de [`secciones/`](secciones/) **sobre el compose original** (el del Backend o el kit
  del otro equipo, que no se modifica): renombra contenedores, conecta a la red compartida `asis-red` solo los puntos de
  entrada (SQL, MinIO, ClamAV, Keycloak como `keycloak.localhost`, PDP, PEP, Kong, Pulsar, Catálogo, Alloy) y declara los
  **volúmenes existentes como externos** (no se pierden datos y `down -v` no los borra).
* `asis-app` vive en [`asis-app.compose.yml`](asis-app.compose.yml).
* Al levantar una sección se detienen los contenedores de su proyecto anterior (`asistencias-security-lab`, `messageucolab`,
  `catalogo-parametros`, …), que usan los mismos puertos. Esos contenedores viejos no se borran; quedan sin reinicio automático.
* `stack/.env` (fuera de Git) lleva `MSSQL_SA_PASSWORD`; plantilla en [`.env.example`](.env.example).
