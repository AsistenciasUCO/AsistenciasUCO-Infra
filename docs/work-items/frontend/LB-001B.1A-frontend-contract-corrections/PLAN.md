# PLAN — LB-001B.1A frontend contract corrections

## Identidad y autorización

- Fecha: 2026-09-22 (America/Bogota).
- Change class: `BEHAVIOR_CHANGE`.
- Frontend: rama `develop`, base `71ee6d32bfe1c6c58c04d0e986e525850ff6eb52`, working tree limpio al iniciar.
- Backend de evidencia: rama `sergio`, HEAD `fa9aa901c73e55ae31071f4e74cfb2245189243a`, working tree previamente sucio. Se mantiene `READ ONLY`.
- Aprobación humana: instrucción de esta tarea para implementar DR-002, DR-003, DR-005, DR-007, DR-008 y TD-031/032/033.

## Objetivo

Corregir exclusivamente el consumer Angular del Golden Path de asistencia para que no invente datos contractuales, respete RBAC, preserve el `LocalDateTime` local sin conversiones de zona, recupere 401 antes de expirar sesión, elimine credenciales productivas por defecto y muestre feedback observable ante fallos relevantes.

Variable principal: alineación del comportamiento del frontend con las decisiones contractuales aprobadas.

## Alcance autorizado

- Modelo/mapeo y guardado de asistencia: estado local `SIN REGISTRAR` sin añadir valor al request API.
- Filtrado local de matrículas con `codigoEstado === 'A'` en `AttendanceControlComponent`.
- Mapeo explícito `fechaHoraInicio/Fin` a fecha y hora mediante strings, sin `Date`.
- Ruta y accesos visibles de `/app/asistencia` solo para `DOCENTE`.
- Coordinación de interceptores para refresh único ante 401; expiración solo tras fallo definitivo.
- Eliminación de fallbacks productivos de contraseña en registro, matrícula y servicio.
- UX de `EX` sin causa/observación no persistida.
- Feedback de error de sesiones y estados realtime terminales, evitando duplicados.
- Tests, cobertura y documentación local del work item.

## Fuera de alcance / rutas prohibidas

- Backend, DB, OpenAPI, JPA, dependencias nuevas, WebSocket, NgRx y tecnologías nuevas.
- DR-001 estado de sesión, DR-004 campos de sesión/presentación, DR-006 estado legacy, DR-009/TD-030 y LB-001B.1B.
- No modificar `ClassSession.status: 'PROGRAMADA'` sintetizado.
- No modificar configuración de cobertura para superar gates.

## Contrato TARGET aprobado

- Ausencia de fila de asistencia representa estado local `null`/“Sin registrar”; solo `AN|SJC|EX` se serializan.
- `markAllPresent` asigna `AN`; `markAllAbsent` asigna `SJC`; estados persistidos se conservan.
- Solo estudiantes con matrícula `A` aparecen/participan del batch.
- `2026-09-14T08:00:00` se mapea a `date=2026-09-14`, `startTime=08:00`; fin equivalente, sin conversión de timezone.
- `/app/asistencia` requiere `DOCENTE`.
- 401 intenta un único refresh compartido; éxito reintenta y conserva sesión; fallo expira una vez. 403 no refresca.
- La contraseña debe estar presente y pasar validación; ningún literal/fallback productivo completa el campo.
- `EX` solo cambia el estado; causa/observación queda como historia futura.
- Error de carga de sesiones y estados realtime `UNAUTHORIZED`/`ERROR` muestran feedback; HTTP sigue siendo fuente de verdad.

## Riesgos y rollback

- Hacer nullable el estado UI afecta render, filtros y navegación por teclado; se cubre con unit/component tests.
- El estado compartido del refresh puede producir carreras; se cubre concurrencia y fallo.
- Rollback: revertir exclusivamente los archivos listados en `VALIDATION.md`; no hay migración ni cambio externo.

## Definition of Ready

`READY`: decisiones del alcance tienen aprobación humana explícita; contratos/provider/consumer y consumidores fueron inspeccionados; suite base ejecutada con 97/97 tests y cobertura 76.43 % líneas / 55.09 % ramas usando el CLI Angular local; rutas permitidas/prohibidas y TEST_PLAN están definidos. El primer intento con `npm` no ejecutó por instalación local rota de `npm-cli.js`; ChromeHeadless requirió ejecución fuera del sandbox.

## Stop conditions

- Cualquier necesidad de cambiar backend/DB/OpenAPI/JPA.
- Conflicto con DR-001/004/006/009 o TD-030.
- Un RED que contradiga el TARGET aprobado (`TEST_CONTRACT_CONFLICT`).
- No iniciar LB-001B.1B.
