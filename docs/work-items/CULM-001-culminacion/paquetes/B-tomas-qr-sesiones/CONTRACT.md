# CULM-001 · Paquete B — CONTRACT (tomas por horas, QR de asistencia, ventana de sesión, sesión cancelada y festivos)

> **Estado:** BORRADOR para la revisión de contratos de la sección 9.2 del prompt (revisor Opus independiente). Nada de este documento se congela ni se firma (`.sha256`) antes de que el revisor diga "sin objeciones".
> **Fecha:** 2026-11-06. **Fase SDD:** 02 CONTRACT (el RED empieza solo después de la revisión).
> **Fuentes:** `PROMPT_FABLE_CULMINACION.md` §3.2, §3.3, §3.4, §3.7 y §3.10; `DECISIONES.md` DEC-011 a DEC-018 (cerradas, no se reabren); `RESEARCH-MODELO-ACTUAL.md`; `FINDINGS-docente|estudiante|coordinador.md`; `AGENTS.md` §3.3.
> **Convenciones de ruta:** `DB:` = `GestioAsistenciaDB/`, `BE:` = `GestioAsistenciaBackend/src/main/java/co/edu/uco/asistenciasuco/`, `BE-T:` = `GestioAsistenciaBackend/src/test/java/co/edu/uco/asistenciasuco/`, `FE:` = `GestioAsistenciaFrontend/src/app/`, `INFRA:` = `AsistenciasUCO-Infra/`. Todos bajo `C:\Proyectos\GestionAsistencia-CULM001\`.

---

## 0. Supuestos aplicados y precisiones de diseño

Las decisiones DEC-011..DEC-018 se aplican tal cual. Lo que sigue son detalles que esas decisiones no fijan; cada uno es la opción más conservadora según §9.3 del prompt y queda marcado para el revisor.

| ID | Supuesto / precisión | Motivo |
| :--- | :--- | :--- |
| [SUPUESTO-B-01] | Los números de migración y semilla de B son `14_*`/`15_*` (migraciones) y `34_*`/`35_*`/`36_*` (semillas). `13_*`/`33_*` quedan reservados para el paquete A. Si A usa otros, B toma el siguiente libre sin cambiar el contenido. | A se integra antes que B |
| [SUPUESTO-B-02] | Los estados, modos y tipos se distinguen en los SP por **columnas bandera de catálogo** con índice único (`ModoTomaAsistencia.usaCodigoQr`, `EstadoTomaAsistencia.estaAbierta`, `TipoCancelacionSesion.esAutomatica`), nunca por literales de código. Los índices filtrados de "uno abierto/activo" usan `fechaCierreUtc IS NULL`, no un literal de estado. | Cero datos quemados sin la excepción técnica de HU176B |
| [SUPUESTO-B-03] | Los códigos de `RazonCausa` (`AN`, `SJC`, `EX`) se leen en los SP **nuevos** desde parámetros `ASISTENCIA/CODIGO_RAZON_*`. Las vistas reescritas (`uv_resumen_*`, `uv_asistencia_sesion_horas`) conservan los literales de `RazonCausa` que ya usan hoy (catálogo cerrado de ids fijos; leer parámetros por fila degrada el plan). | Comportamiento actual; se registra deuda TD nueva (§5) |
| [SUPUESTO-B-04] | Una toma implícita (creada por el lote legado `POST /asistencias/lote` o por el backfill) nace **CERRADA** (`esImplicita = 1`). Las siguientes escrituras del lote legado van a la toma ABIERTA si la hay o, si no, a la última toma (corrección del docente). | Evita tomas abiertas huérfanas y conserva "una toma = comportamiento actual" (DEC-013) |
| [SUPUESTO-B-05] | Precisión de DEC-012: `horasDictadas` cuenta **todas** las tomas de las sesiones vencidas, con registro y no canceladas, sin mirar si la toma quedó ABIERTA. Una toma ABIERTA en una sesión vencida la cierra el job (§3.7); el cálculo no depende de que el job haya corrido. | El denominador no puede depender de un proceso asíncrono |
| [SUPUESTO-B-06] | `tieneRegistroAsistencia` (en `uv_cumplimiento_sesion_grupo`) pasa a ser "existe `Asistencia` **o** existe `TomaAsistencia`". Una toma QR abierta y cerrada sin lecturas ni marcación cuenta como sesión ejecutada. | El docente sí ejecutó la toma |
| [SUPUESTO-B-07] | Máximo de tomas por sesión: `TOMA_ASISTENCIA/MAXIMO_TOMAS_POR_SESION = 4`. Abrir una toma nueva exige que no haya otra ABIERTA en la sesión. | Acota el reparto de horas |
| [SUPUESTO-B-08] | Cerrar una toma: si `marcarAusentes` llega `NULL` se aplica el valor del modo (`ModoTomaAsistencia.marcaAusentesAlCerrar`: MANUAL = 0, QR = 1). Después de cerrar, el docente puede seguir marcando faltantes en esa toma mientras dure la ventana `[inicio − TOLERANCIA, fin + MARGEN)`; vencida la ventana, la única vía es el reclamo (HU010). | DEC-013 + §3.4 ("los que no se marquen quedan como ausentes") |
| [SUPUESTO-B-09] | El job de rotación QR también **cierra** las tomas cuya ventana venció (`usp_cerrar_tomas_vencidas`), aplicando `marcaAusentesAlCerrar` del modo. | "o vencer la ventana" (§3.4) |
| [SUPUESTO-B-10] | HU047: solo se puede cancelar una sesión **sin** `Asistencia` ni `TomaAsistencia` (sin pérdida de datos). No hay "des-cancelar" en B. Una cancelación por un festivo que desaparece en una recarga **no se revierte**: la sesión se reporta. | Opción conservadora y reversible |
| [SUPUESTO-B-11] | `usp_internal_aplicar_festivos_grupo` cancela por festivo solo sesiones **sin** `Asistencia` ni `TomaAsistencia`; con `@soloFuturas = 1` (mantenimiento de grupos ya creados) solo las de `fechaHoraInicio > SYSUTCDATETIME()`; la generación (`usp_generar_sesiones_grupo_v2`) y la precarga usan `@soloFuturas = 0` (toda sesión nueva en festivo nace cancelada). | §3.7 [SUPUESTO] del prompt + "sesión en festivo creada cancelada" |
| [SUPUESTO-B-12] | Límites de intentos del QR de asistencia (3.4 [SUPUESTO] del prompt): por IP 600/min (5 grupos × 40 estudiantes detrás del mismo NAT = 200 lecturas en el primer minuto, margen ×3), por token 120/min, por estudiante 6/min. Valores en parámetros `ASISTENCIA_QR/LIMITE_*`. | No bloquear un salón completo detrás del NAT del campus |
| [SUPUESTO-B-13] | El contador de rotación del QR en el cliente **no usa ningún timer**: barra de progreso CSS (`animation-duration` calculada al recibir el evento y reiniciada por cada `ASISTENCIA_QR_ROTADO`) y texto fijo "Próxima rotación: HH:MM:SS" calculado de `fechaRotacionUtc + rotacionSegundos` que entrega el backend. | Regla anti-polling de AGENTS.md en su forma estricta |
| [SUPUESTO-B-14] | `DetalleAsistencia.codigo` pasa a obtenerse de la secuencia `dbo.seq_detalle_asistencia_codigo` (iniciada en `MAX(codigo) + 1`) en lugar de `MAX + 1` con `UPDLOCK, HOLDLOCK` sobre toda la tabla. Puede haber huecos tras un rollback. | El `MAX+1` serializa a todos los grupos del campus (prueba 5 × 40) y abre ciclos de bloqueo |
| [SUPUESTO-B-15] | Un estudiante con varias tomas en una sesión se muestra con un **estado consolidado** por sesión: `SJC` si alguna toma es `SJC`; si no, `EX` si alguna es `EX`; si no, `AN`. Si mezcla `AN` y `SJC` se marca `esParcial = 1` (estado `PARCIAL` en el DTO del estudiante). | Golden path de `GET /grupos/{id}/asistencias` sin cambio de esquema |
| [SUPUESTO-B-16] | El evento `ASISTENCIA_QR_ROTADO` lleva el token (dentro de `urlAsistencia` y `qrPngBase64`), igual que `MATRICULA_QR_ROTADO` (precedente HU176B): el texto en claro solo existe en memoria del backend al rotar. Se mitiga con la **política de audiencia por tipo de evento** (§3.8): ese tipo solo se entrega al docente titular. | Sin token en claro persistido; mismo mecanismo probado |
| [SUPUESTO-B-17] | El canal SSE se abre a estudiantes con matrícula `A` en el grupo, solo para los tipos de evento de audiencia `ESTUDIANTE_GRUPO` (en B: `SESION_CANCELADA`). | El estudiante ve la cancelación sin recargar; C reutiliza el canal para alertas |
| [SUPUESTO-B-18] | `usp_registrar_asistencia_estudiante_autonomo` (código estático `Sesion.codigo`) deja de tener consumidor en el backend y se le revoca el `EXECUTE` al rol de runtime; el objeto se conserva (sin `DROP`) hasta el paquete D. `Sesion.codigo` deja de ser una credencial. | Menor cambio reversible |
| [SUPUESTO-B-19] | El registro individual `POST /api/v1/asistencias` (501, TD-009) se **retira**: marcar a un estudiante es un lote de un elemento en `POST /tomas/{id}/asistencias`. TD-009 se cierra. | §4 del prompt: implementar o retirar |
| [SUPUESTO-B-20] | Las inserciones directas en `DetalleAsistencia` de pruebas y fixtures (lista en §2.15.3) se actualizan para pasar la columna obligatoria `toma`. Es un ajuste de prueba por cambio formal de contrato (nueva FK obligatoria); no se relaja ninguna aserción. | AGENTS.md §4 permite el ajuste por cambio de contrato |
| [SUPUESTO-B-21] | La aplicación de festivos a grupos ya creados se dispara (a) tras cada carga/recarga exitosa de un año (job o administrador) y (b) desde la migración no, porque la migración no puede llamar a internet: tras desplegar B.1 el job carga el año actual y el siguiente y aplica. | La BD nunca llama a internet (§3.7) |

---

## 1. Alcance

### 1.1 Subpaquetes

| Subpaquete | Contenido | Decisiones |
| :--- | :--- | :--- |
| **B.1 — Sesión cancelada, festivos, HU047 y ventana con tolerancia** | `SesionCancelacion` + `TipoCancelacionSesion` + `uv_sesion_estado`; `DiaFestivo` + `CargaDiaFestivo` + carga por año; `usp_generar_sesiones_grupo_v2`, precarga con festivos y `usp_aplicar_festivos_*`; `usp_cancelar_sesion` (HU047) con notificación `SESION_CANCELADA` y evento SSE; `CalendarioFestivosPort` con 3 adaptadores + job + pantalla de festivos del administrador; ventana SES-01 con `@toleranciaMinutos`/`@margenMinutos` opcionales y rechazo de sesiones canceladas; `uv_cumplimiento_sesion_grupo` sin canceladas; estado cancelado visible en todos los roles | DEC-014, DEC-016, DEC-017, DEC-018 |
| **B.2 — Tomas por horas, QR de asistencia y faltantes** | `TomaAsistencia` + catálogos; `DetalleAsistencia.toma` con migración y backfill; toma vigente en `usp_sincronizar_asistencia_estudiante_interno`; lote por toma; cierre con faltantes; cálculo por horas (`ufn_*`, `uv_resumen_*` y KPIs); `TokenAsistenciaToma` + SPs del QR + scheduler + rate limit + CIDR + SSE; nuevo `POST /estudiante/asistencia-qr` (token o PIN); pantallas del docente (modo, tomas, proyección, faltantes) y del estudiante (`/app/asistencia/qr`, PIN, indicadores por horas) | DEC-011, DEC-012, DEC-013, DEC-014, DEC-015, DEC-018 |

B.1 va primero porque B.2 necesita `uv_sesion_estado` (las tomas no se abren en sesiones canceladas y las horas excluyen canceladas).

### 1.2 HUs cubiertas

| HU | Efecto en B | Subpaquete |
| :--- | :--- | :--- |
| **HU047** Cancelar sesión con justificación | Implementada (501 → funcional), notificación al estudiante y SSE | B.1 |
| **HU175** Proyección de QR dinámico y PIN | Implementada sobre tomas QR (no sobre la sesión) | B.2 |
| **HU176** Auto-registro de asistencia con red del campus | Implementada: token o PIN, CIDR, límites, idempotente | B.2 |
| HU004, HU009, HU013 (estudiante: %, fallas, semáforo) | `GET /estudiante/materias` entrega indicadores **por horas** desde `uv_resumen_asistencia_estudiante_grupo` | B.2 |
| HU040, HU041 (docente: sábana y riesgo) | Endpoint de resumen por grupo; la sábana deja de calcular en el cliente | B.2 |
| HU065 (cumplimiento) | `uv_cumplimiento_sesion_grupo` excluye canceladas (B.1) y cuenta tomas (B.2) | B.1/B.2 |
| HU066, HU070 (alertas tempranas) | Vía `uv_resumen_*` por horas | B.2 |
| HU102, HU106 (decano) | `usp_consultar_kpis_decano` y comparativas por horas | B.2 |
| HU133, HU138 (institución) | `usp_consultar_kpis_institucion` por horas; cumplimiento sin canceladas | B.1/B.2 |
| HU061 (consolidado del coordinador) | Porcentajes por horas + `porcentajeSinRegistro` explícito (cierra F-COO-007) | B.2 |
| HU067, HU069, HU103, HU134, HU139 | Bitácora, historial, comparativas y tendencia agregan por sesión/horas | B.2 |
| HU002/HU010 (sesiones y reclamo del estudiante) | Estado consolidado por sesión, horas por sesión; una sesión cancelada no es reclamable | B.1/B.2 |
| HU144/HU145 (cronograma) | Las sesiones muestran `estado`/`cancelacion` | B.1 |

### 1.3 Hallazgos de la Fase 1

| Hallazgo | Resolución |
| :--- | :--- |
| F-DOC-002 (QR estático, PIN `392-817`) | **Cierra B.2**: se retira `attendance-projection-modal` y la proyección usa tokens reales |
| F-DOC-003 (`setInterval` + sondeo de `qr-token`) | **Cierra B.2**: contador sin timers ([SUPUESTO-B-13]); `getQrToken` retirado |
| F-DOC-004 (sábana con % local) | **Cierra B.2**: `GET /docente/grupos/{id}/resumen-asistencia` (§3.2.12) |
| F-DOC-012 (`asistio = 0` con `AN`) | **Parcial en B.2**: el cálculo por horas usa `codigoRazonCausa` (no `asistio`); la migración `15_up` **reporta** (no corrige) las filas incoherentes y la prueba de invariante falla si un SP nuevo las produce. La corrección de los datos queda para el paquete A (hallazgos críticos/altos) |
| F-DOC-015, F-DOC-016 (500 al abrir matrícula QR) | **Fuera de B** (HU176B, paquete A). **Dependencia:** B.2 reutiliza `TokenGeneratorPort`, `CodigoQrGeneratorPort` y el patrón del adaptador JPA; el GREEN de B.2 (QR) no empieza hasta conocer la causa raíz de F-DOC-015 |
| F-DOC-017 (sesiones solapadas) | **Fuera de B** (paquete D o hallazgos altos) |
| F-DOC-021 (horarios del docente vacíos) | **Fuera de B** (paquete D) |
| F-EST-002 (sin indicadores en materias) | **Cierra B.2** (§3.2.13) |
| F-EST-005 (sin campo token) | **Cierra B.2**: cuerpo `{token}` o `{pin}` |
| F-EST-009 (umbrales 85/75 en el cliente) | **Cierra B.2**: el cliente pinta `codigoPermanencia` y los umbrales que entrega el backend |
| F-EST-017 (exige `sesionId`) | **Cierra B.2**: el token/PIN resuelve la toma |
| F-EST-021 (Carlos sin registros) | **Fuera de B** (datos del recorrido; Fase 3). El flujo de faltantes de B evita que se repita |
| F-COO-007 (consolidado incoherente) | **Cierra B.2** (§2.9) |

### 1.4 Fuera de alcance

Cancelación por inasistencia (paquete C; B deja `usp_ejecutar_cierre_masivo_periodo` igual y documenta que con varias tomas cuenta detalles, ver §7), asignaturas N:M (B2), cruce de horarios del docente, catálogo de mensajes del equipo externo, identidad visual (E; los componentes nuevos de B nacen con los tokens de `styles.css`).

---

<!-- SECCION-2 -->
