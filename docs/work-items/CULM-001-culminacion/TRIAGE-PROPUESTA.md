# CULM-001 — TRIAGE-PROPUESTA (Fase 1)

Propuesta del consolidador para la decisión del orquestador. Base: `FINDINGS.md` (113 filas tras deduplicar 148 hallazgos de origen). Nada de lo aquí propuesto está aprobado; los paquetes son A, B, B2, C, D, E de `PLAN.md`.

## (a) Conteos

### Por severidad

| Severidad | Antes de deduplicar | Después |
| :--- | ---: | ---: |
| crítica | 3 | 3 |
| alta | 29 | 24 |
| media | 68 | 52 |
| baja | 48 | 34 |
| **Total** | **148** | **113** |

### Por rol (origen del hallazgo) y severidad — antes / después

| Rol (archivo) | crítica | alta | media | baja | Total |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Estudiante | 0 / 0 | 11 / 9 | 19 / 10 | 14 / 11 | 44 / 30 |
| Docente | 1 / 1 | 4 / 3 | 11 / 7 | 6 / 4 | 22 / 15 |
| Coordinador | 2 / 2 | 3 / 3 | 5 / 5 | 4 / 2 | 14 / 12 |
| Decano | 0 / 0 | 1 / 0 | 8 / 6 | 7 / 3 | 16 / 9 |
| Administrador | 0 / 0 | 4 / 3 | 16 / 16 | 10 / 8 | 30 / 27 |
| Transversal (TRX) | 0 / 0 | 5 / 5 | 9 / 8 | 7 / 6 | 21 / 19 |
| Transversal (F-000) | 0 / 0 | 1 / 1 | 0 / 0 | 0 / 0 | 1 / 1 |
| **Total** | **3 / 3** | **29 / 24** | **68 / 52** | **48 / 34** | **148 / 113** |

Nota: el rol se cuenta por el archivo de origen del ID (EST incluye F-EST-S##). Una fila fusionada se cuenta bajo el ID conservado. Ninguna fusión exigió elevar severidad: en todas la fila conservada ya tenía la mayor.

## (b) Duplicados fusionados

35 hallazgos fusionados en 26 filas conservadas.

| Fila conservada | Severidad | Duplicados fusionados (severidad) | Criterio |
| :--- | :--- | :--- | :--- |
| F-ADM-016 | media | F-DOC-009 (baja), F-TRX-010 (baja) | Mismas banderas leídas de localStorage / obsoletas en environment.ts |
| F-ADM-023 | media | F-DEC-010 (baja), F-DOC-019 (media) | Mismo contrato ApiListResponse en vez de ApiPageResponse |
| F-COO-008 | media | F-DEC-002 (media) | Mismo ámbito en Application con HQL directo |
| F-COO-010 | media | F-DEC-008 (baja) | Mismo patrón de filtros sin etiqueta |
| F-DOC-012 | media | F-EST-021 (media) | Mismos registros SES-01/SES-02 vistos por estudiante |
| F-EST-001 | alta | F-DOC-001 (alta), F-DEC-001 (alta), F-ADM-001 (alta), F-COO-014 (baja) | Misma causa de entorno (JWKS/proveedor) en los 5 roles; ya corregida |
| F-EST-002 | alta | F-EST-S02 (alta) | Mismo síntoma en materias y dashboard |
| F-EST-003 | alta | F-EST-S15 (media) | Misma acción de retiro; F-EST-S15 es el lado de pantalla (ojo: el código expone el botón y la prueba de pantalla no lo encontró, ver (e)) |
| F-EST-004 | media | F-EST-S07 (media) | Mismo PUT /usuarios/perfil y botones Editar |
| F-EST-006 | media | F-EST-S09 (media) | Mismas HUs inexistentes en UI |
| F-EST-007 | media | F-EST-S08 (media), F-TRX-007 (media) | Mismo bloque HU026C: alertas, campana y emisores |
| F-EST-010 | media | F-EST-S10 (media), F-EST-S11 (baja), F-EST-S20 (baja) | Mismos modales de matrícula y auto-registro (teclado, etiquetas, PIN) |
| F-EST-017 | alta | F-EST-005 (media) | Mismo flujo de auto-registro |
| F-EST-018 | alta | F-EST-S04 (alta) | Mismo POST /estudiante/matricular-grupo con PIN inexistente |
| F-EST-019 | alta | F-DOC-020 (media) | Misma ruta pública /public/matricula-qr/validar |
| F-EST-S01 | alta | F-EST-020 (media) | Misma matrícula I visible como materia |
| F-EST-S03 | alta | F-EST-S12 (media) | Mismo patrón: falta de estado de error en el estudiante |
| F-EST-S06 | media | F-EST-023 (baja) | Horario vacío por falta de franjas |
| F-TRX-006 | media | F-DEC-012 (baja) | Mismo 403 de realtime/stream y falta de SSE en el decano |
| F-TRX-008 | alta | F-DEC-011 (media), F-DOC-014 (baja) | Misma ausencia de datos de un 2.º ámbito |
| F-TRX-009 | media | F-DOC-003 (media) | Mismo setInterval de QR en teacher-grupos |
| F-TRX-012 | media | F-ADM-021 (baja) | Mismo ruido de Azure App Configuration en el log |
| F-TRX-016 | baja | F-ADM-028 (baja) | Mismo POST /realtime/emit sin validación |
| F-TRX-017 | alta | F-DOC-016 (media) | Mismo 500 en matricula-qr con grupo inexistente |
| F-TRX-018 | media | F-COO-013 (baja) | Mismo 403 del administrador en rutas coordinador/decano |
| F-TRX-021 | baja | F-DEC-015 (baja) | Mismo 200 vacío por id inexistente |

Relacionados pero NO fusionados (se conservan como filas propias por rol o endpoint distinto): F-COO-001, F-COO-002 y F-DOC-013 (misma raíz: `GET /estudiantes` sin ámbito); F-TRX-004 (paraguas de 14 endpoints 501) frente a F-EST-003, F-COO-005, F-ADM-002, F-ADM-003, F-EST-004; F-DOC-015 frente a F-TRX-017 (el primero es el caso con grupo válido); F-TRX-005 frente a F-TRX-006; F-ADM-027 frente a F-TRX-017 (solapan solo en el reintento 500).

## (c) Hallazgos críticos y altos: paquete propuesto

| ID | Severidad | Título | Paquete propuesto | Nota |
| :--- | :--- | :--- | :--- | :--- |
| F-DOC-013 | crítica | Fuga de datos personales: GET /estudiantes (y por id) sin ámbito (docente) | A |  |
| F-COO-001 | crítica | Fuga de datos personales: GET /estudiantes sin ámbito (coordinador) | A |  |
| F-COO-002 | crítica | Fuga de datos personales: GET /estudiantes/{id} sin ámbito (coordinador) | A |  |
| F-EST-001 | alta | 401 en todos los endpoints por entorno (JWKS/proveedor) | entorno (ya corregido) | Ya corregido en el entorno; solo falta verificar en Fase 3. |
| F-EST-002 | alta | Estudiante no ve su % de inasistencia ni indicadores | B | El % del estudiante depende de la regla por horas (DEC-012). |
| F-EST-003 | alta | Retirar reclamo del estudiante responde 501 (botón expuesto en código) | A | 501 con botón expuesto: corrección inmediata (implementar o retirar botón). |
| F-EST-017 | alta | Auto-registro por PIN/token no funciona (exige sesionId) | B |  |
| F-EST-018 | alta | PIN de matrícula inexistente produce 500 | A |  |
| F-EST-019 | alta | Matrícula pública por QR/PIN devuelve 401 sin token | A |  |
| F-EST-S01 | alta | Matrícula inactiva (I) se muestra como materia inscrita | A | Depende de la decisión (e)-3. |
| F-EST-S03 | alta | Sin estado de error ni reintento en materias y horario | A |  |
| F-EST-S05 | alta | El estudiante no abre SSE en ninguna vista | C | Depende de abrir SSE al estudiante (F-TRX-006). |
| F-DOC-002 | alta | Proyección de QR falsa (QR y PIN estáticos) | B |  |
| F-DOC-015 | alta | Docente no puede abrir la matrícula por QR/PIN (500) | A |  |
| F-DOC-017 | alta | Se crean sesiones solapadas del docente sin validar | A |  |
| F-COO-003 | alta | Grupos, alumnos y asistencias del coordinador sin ámbito de programa | A | Seguridad alta; B2 recoge después el ámbito por programa en grupos mixtos. |
| F-COO-004 | alta | Coordinador puede matricular (regla: solo docente) y quedan stubs 501 | A | Depende de la decisión (e)-6. |
| F-COO-005 | alta | Desvincular asignatura de la malla responde 501 | A |  |
| F-ADM-002 | alta | Toggle de decano responde 501 (botón expuesto) | A |  |
| F-ADM-003 | alta | HU168: edición de parámetros globales no implementada | D | HU168 pendiente (D). |
| F-ADM-004 | alta | HU156: admisión de estudiante por el administrador no existe | D | HU156 pendiente (D). |
| F-TRX-002 | alta | Marcación autónoma no valida la red Wi-Fi del campus | B |  |
| F-TRX-003 | alta | Sin rate limit en asistencia-qr ni en subida de archivos | A |  |
| F-TRX-005 | alta | Resolver reclamo no emite evento SSE al estudiante | C | Requiere SSE abierto al estudiante (F-TRX-006). |
| F-TRX-008 | alta | Faltan datos de un 2.º ámbito para probar fugas | A | Hay que sembrar el 2.º ámbito antes de verificar los críticos de fuga. |
| F-TRX-017 | alta | 500 en /configuracion/* y errores no mapeados en matrícula QR/notificaciones | A | Depende en parte de App Configuration inaccesible (F-TRX-012). |
| F-000 | alta | Prueba LB-004D de BD falla en la línea base | D | Falla de BD preexistente en la línea base; LB-004D está en D según PLAN, pero el gate verde debe tenerse antes de cerrar A (ver (e)). |

Resumen críticos y altos por paquete: A: 17, B: 4, C: 2, D: 3, entorno: 1.

Justificación de los paquetes no-A en altos: B = toma/QR/%/sábana/red Wi-Fi de asistencia (F-EST-002, F-EST-017, F-DOC-002, F-TRX-002); C = SSE y alertas al estudiante (F-EST-S05, F-TRX-005); D = HU168 y HU156 pendientes y prueba LB-004D (F-ADM-003, F-ADM-004, F-000). Ningún crítico o alto se propone como «no se corrige».

## (d) Hallazgos medios y bajos: paquete propuesto

| ID | Severidad | Paquete propuesto |
| :--- | :--- | :--- |
| F-EST-004 | media | D |
| F-EST-006 | media | D |
| F-EST-007 | media | C |
| F-EST-008 | media | D |
| F-EST-010 | media | E |
| F-EST-011 | media | E |
| F-EST-012 | media | D |
| F-EST-022 | media | D |
| F-EST-S06 | media | D |
| F-EST-S13 | media | E |
| F-DOC-004 | media | B |
| F-DOC-005 | media | E |
| F-DOC-006 | media | D |
| F-DOC-007 | media | E |
| F-DOC-008 | media | E |
| F-DOC-012 | media | B |
| F-DOC-018 | media | D |
| F-COO-006 | media | B2 |
| F-COO-007 | media | B |
| F-COO-008 | media | B2 |
| F-COO-009 | media | E |
| F-COO-010 | media | E |
| F-DEC-003 | media | D |
| F-DEC-004 | media | E |
| F-DEC-005 | media | E |
| F-DEC-006 | media | E |
| F-DEC-013 | media | B |
| F-DEC-014 | media | D |
| F-ADM-005 | media | D |
| F-ADM-006 | media | E |
| F-ADM-007 | media | E |
| F-ADM-008 | media | D |
| F-ADM-009 | media | D |
| F-ADM-010 | media | E |
| F-ADM-011 | media | D |
| F-ADM-012 | media | D |
| F-ADM-013 | media | E |
| F-ADM-016 | media | D |
| F-ADM-018 | media | E |
| F-ADM-022 | media | D |
| F-ADM-023 | media | D |
| F-ADM-024 | media | D |
| F-ADM-025 | media | D |
| F-ADM-027 | media | D |
| F-TRX-001 | media | entorno |
| F-TRX-004 | media | D |
| F-TRX-006 | media | C |
| F-TRX-009 | media | B |
| F-TRX-012 | media | espera: equipo de mensajes/parámetros (Azure App Configuration) |
| F-TRX-013 | media | E |
| F-TRX-014 | media | E |
| F-TRX-018 | media | D |
| F-EST-009 | baja | B |
| F-EST-013 | baja | E |
| F-EST-014 | baja | E |
| F-EST-015 | baja | E |
| F-EST-016 | baja | A |
| F-EST-024 | baja | D |
| F-EST-S14 | baja | E |
| F-EST-S16 | baja | D |
| F-EST-S17 | baja | E |
| F-EST-S18 | baja | E |
| F-EST-S19 | baja | E |
| F-DOC-010 | baja | E |
| F-DOC-011 | baja | B |
| F-DOC-021 | baja | D |
| F-DOC-022 | baja | D |
| F-COO-011 | baja | E |
| F-COO-012 | baja | A |
| F-DEC-007 | baja | E |
| F-DEC-009 | baja | E |
| F-DEC-016 | baja | no se corrige (propuesta): el comportamiento es correcto y solo el texto es genérico |
| F-ADM-014 | baja | E |
| F-ADM-015 | baja | E |
| F-ADM-017 | baja | espera: equipos de seguridad y mensajes (HU169/HU170) |
| F-ADM-019 | baja | E |
| F-ADM-020 | baja | D |
| F-ADM-026 | baja | D |
| F-ADM-029 | baja | D |
| F-ADM-030 | baja | D |
| F-TRX-011 | baja | D |
| F-TRX-015 | baja | no se corrige (propuesta): cambiar Bearer en memoria por cookies HttpOnly altera la arquitectura de seguridad; se propone actualizar la regla escrita |
| F-TRX-016 | baja | D |
| F-TRX-019 | baja | D |
| F-TRX-020 | baja | D |
| F-TRX-021 | baja | D |

Resumen medios y bajos por paquete: A: 2, B: 7, B2: 2, C: 2, D: 36, E: 32, entorno: 1, espera: 2, no se corrige (propuesta): 2.

## (e) Cuestiones que el orquestador debe decidir

1. **F-TRX-006 — SSE solo para el docente titular.** El stream responde 403 a estudiante, coordinador, decano y administrador, pero el catálogo dice «cualquier rol autenticado». Decidir si se abre a los demás roles con filtro de ámbito (necesario para F-EST-S05, F-TRX-005 y la alerta HU026C del paquete C) o si el catálogo se corrige y esas pantallas quedan sin tiempo real.
2. **F-TRX-018 — Administrador con 403 en rutas de coordinador y decano.** 27 combinaciones: el SecurityConfig y el catálogo permiten al administrador, pero el SP exige perfil COORDINADOR/DECANO. Elegir entre quitar al administrador del catálogo (y de rutas-por-rol.md) o darle lectura transversal; hoy no es fuga.
3. **F-EST-S01 — Matrícula `I` visible como materia.** Definir qué estados de EstudianteGrupo cuentan como inscrito (¿solo `A`?) y qué hacer con las solicitudes de ingreso históricas del grupo 5C23 (Aceptada y Retirada a la vez); la regla afecta a materias, dashboard, oferta y a DEC-009/DEC-010.
4. **F-ADM-022 — Auditoría de acciones del administrador.** El proveedor de auditoría por defecto es `logging` y ninguna alta/cambio del administrador deja rastro (solo docente, estudiante y coordinador). Decidir si se audita todo `/admin/**` con actor, recurso, valor anterior/nuevo y `correlationId` (necesario también para HU168) y si el evento debe exponer `correlationId` en vez de `idTraza`.
5. **F-TRX-017 — 500 en `/configuracion/*`.** `configuracion/identidad` (alimenta HU159) y `registro-estudiante` fallan con 500 probablemente por Azure App Configuration inaccesible (F-TRX-012). Decidir si se corrige con valores por defecto desde BD (DEC-018) o se espera a que seguridad/mensajes habiliten el acceso; en ambos casos un grupo inexistente debe dar 404, no 500.
6. **F-COO-004 — Coordinador y matrícula.** El SP acepta perfil `DOCENTE,COORDINADOR` y el filtro HTTP deja pasar al coordinador, contra la regla «matrícula solo por QR o manual del docente». Decidir si se cierra con 403 (y se retiran los stubs 501 de `/coordinador/grupos/{id}/estudiantes`) o si el coordinador conserva matrícula manual.
7. **F-DOC-018 — HU044 (aforo) no operable por el docente.** El catálogo solo permite ADMINISTRADOR y COORDINADOR en `PUT /grupos/{id}`, aunque HU044 está certificada para el docente. Decidir si se permite al docente titular (con ámbito) o se corrige el catálogo de HUs.
8. **501 expuestos en pantalla: implementar o retirar.** F-EST-003 (retirar reclamo; el código expone el botón y la prueba de pantalla no lo vio), F-COO-005 (desvincular de la malla), F-ADM-002 (toggle de decano), F-EST-004 (PUT perfil: la decisión ya es retirar) y F-TRX-004 (los otros 9). Decidir cuáles se implementan en A/D y cuáles se retiran.
9. **F-TRX-008 / F-DEC-011 — Segundo ámbito de prueba.** Sin una 2.ª facultad, programa y docente con login no se puede certificar el aislamiento (solo 0 fugas con IDs inexistentes). El administrador ya creó `CULM1-Facultad B` y un decano sin login en Keycloak. Decidir quién siembra el 2.º programa/coordinador/docente y cuándo (antes de corregir F-COO-001/002/003 y F-DOC-013).
10. **F-EST-019 y F-TRX-015 — Seguridad web y rutas públicas.** `/public/matricula-qr/validar` responde 401 (posible efecto del PEP en modo baseline: depende del equipo de seguridad) y AGENTS exige cookies HttpOnly mientras el código usa Bearer en memoria. Decidir si se pide la exención de rutas públicas al equipo de seguridad y si se actualiza la regla escrita de AGENTS en vez de cambiar la arquitectura.

Otras observaciones menores: F-000 (prueba LB-004D de BD) rompe el gate de la línea base; F-EST-S03 se propone en A por ser alta, aunque su arreglo es de UI; F-TRX-001 (documentación de credenciales con `admin-cli`) y F-TRX-012 (ruido del log) se clasifican como «entorno» y «en espera», respectivamente. No existe aún `SCREEN-RESULTS-docente.md`.
