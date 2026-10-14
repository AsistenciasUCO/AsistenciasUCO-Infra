# TEST PLAN — LB-001B.1A frontend contract corrections

Flujo: requisito aprobado → contrato TARGET de `PLAN.md` → tests RED → snapshot → implementación → GREEN → validación.

## Matriz

| ID | Decisión | Escenario observable | Test previsto |
|---|---|---|---|
| T-01 | DR-002 | ausencia de asistencia produce `status=null`; AN/SJC/EX persistidos se conservan | `attendance.mapper.spec.ts` |
| T-02 | DR-002 | sin registros explícitos no se envía batch; marcar individual/masivo sí; persistidos se reenvían | `attendance-control.component.spec.ts` |
| T-03 | DR-007 | matrícula `A` aparece; estados distintos no participan del batch | `attendance-control.component.spec.ts` |
| T-04 | DR-003 | `LocalDateTime` se separa por string en fecha y `HH:mm`, sin `Date` | `session.service.spec.ts` |
| T-05 | DR-008 | ruta `/app/asistencia` declara únicamente `DOCENTE`; guard rechaza otro rol | `app.routes.spec.ts`, `role.guard.spec.ts` |
| T-06 | TD-031 | 401 + refresh exitoso reintenta con token nuevo sin expirar | `auth.interceptor.spec.ts` |
| T-07 | TD-031 | refresh fallido expira exactamente una vez | `auth.interceptor.spec.ts` |
| T-08 | TD-031 | 403 no refresca | `auth.interceptor.spec.ts` |
| T-09 | TD-031 | dos 401 concurrentes comparten un refresh y ambos reintentan | `auth.interceptor.spec.ts` |
| T-10 | TD-032 | registro/matrícula sin contraseña no llama al backend; servicio rechaza vacío | specs de registro, componente y `student.service.spec.ts` |
| T-11 | DR-005 | marcar EX no captura ni promete causa/observación; request conserva solo `estudianteId/estado` | `attendance-control.component.spec.ts` y búsqueda estática |
| T-12 | TD-033 | fallo de sesiones muestra toast y diferencia lista vacía válida | `attendance-control.component.spec.ts` |
| T-13 | TD-033 | `UNAUTHORIZED`/`ERROR` producen alerta sin duplicados; reconexiones no disparan alerta | `attendance-realtime-sync.service.spec.ts` |

## RED_SNAPSHOT

- Base commit: `71ee6d32bfe1c6c58c04d0e986e525850ff6eb52` (`develop`).
- Fecha: 2026-09-22.
- Comando: `node .\node_modules\@angular\cli\bin\ng.js test --watch=false --browsers=ChromeHeadless --code-coverage` (equivalente a `test:ci`; `npm` local no pudo arrancar por `npm-cli.js` ausente).
- Resultado RED: exit code `1`; `117` total, `100` pass, `17` fail.
- Causa esperada de los 17 fallos: AS-IS incumple mapeo sin registro/fecha, filtro de activos, batch explícito, EX sin captura, ruta DOCENTE, refresh 401, contraseña obligatoria y feedback sesiones/realtime. No hubo error de compilación ni fallo de arnés en esta captura.

SHA-256 de tests congelados:

| Archivo | SHA-256 |
|---|---|
| `src/app/app.routes.spec.ts` | `1a7dff69e733fb58a769514683f1e0a82750cf413a5395ca8f14c241f4c1aa09` |
| `src/app/core/guards/role.guard.spec.ts` | `5ebcd3c2c089a6823271de0bd1985c306521bd2c8d7a85211100e1410e4dc34e` |
| `src/app/core/interceptors/auth.interceptor.spec.ts` | `6abae7f9cfd5b03ab5fc1fed525244be94c0a5246b8c916fd6c2285ed33fff4b` |
| `src/app/core/mappers/attendance.mapper.spec.ts` | `5d2b2ab11a12ed96a9e7fdfb15a5cb9b21da1acd73a05d88ab0202b7283c16ab` |
| `src/app/core/services/session.service.spec.ts` | `e0cc363a94038b10fbfe115b6e9572ea30e7a7c3fb888ce9ff2eda7317ed401f` |
| `src/app/core/services/student.service.spec.ts` | `2885b37fdfd82c4662e77e89c22bbe66d5dbc3b68a979c76339d6f85d1999264` |
| `src/app/features/auth/register/register.component.spec.ts` | `f4ff7824b8e1a1927007c3c27ed41973f39ce4453797dcea738426394946d27e` |
| `src/app/features/attendance/attendance-control/attendance-control.component.spec.ts` | `9eeaa98902cb525ccf4ca5f8dda5964dc9178b8adf630da50a8e03056b372201` |
| `src/app/features/attendance/attendance-control/attendance-realtime-sync.service.spec.ts` | `7e29da6703fb432f599e07b15da2b979d60e807577e1633fe5eb82595b63c8b9` |

Estos tests quedan congelados. El implementador no los modifica salvo `TEST_CONTRACT_CONFLICT` documentado.

## Validación final

- `npm run test:ci` (o comando Angular equivalente si el launcher local de npm continúa roto).
- `npm run build`.
- `npm run coverage:realtime:check`.
- `npm run verify` o equivalente descompuesto.
- búsqueda de fallbacks/literales de contraseña productivos.
- `git diff --check`, `git status --short` y verificación de que backend no cambió.
