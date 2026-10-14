# LB-001B.1C final contract cleanup - VALIDATION

Fecha: 2026-09-22

## Entorno

- `npm ci`: PASS, instaló 969 paquetes. Auditoría npm reportó 46 vulnerabilidades transitivas existentes; no se modificaron dependencias.
- Primer `ng build` sin escalación: FAIL por sandbox `Access is denied`; repetido fuera del sandbox: PASS.

## RED

Ver `RED_SNAPSHOT.md`.

## GREEN

Comando:

```powershell
npm run verify
```

Resultado: PASS, exit code `0`.

Detalles:

- Tests: `184 SUCCESS`.
- Failures: `0`.
- Global coverage:
  - Statements: `59.88% (1551/2590)`
  - Branches: `42.58% (508/1193)`
  - Functions: `46.48% (311/669)`
  - Lines: `61.22% (1511/2468)`
- Realtime coverage:
  - Lines: `95.62% (131/137)`, threshold `>= 90%`
  - Branches: `87.50% (49/56)`, threshold `>= 80%`
- Build production: PASS.

## Focused rerun

Comando:

```powershell
.\node_modules\.bin\ng.cmd test --watch=false --browsers=ChromeHeadless --include=src/app/core/services/session.service.contract.spec.ts
```

Resultado: PASS, `10 SUCCESS`, exit code `0`.

## Scans

- DEFAULT_AN_BUSINESS_FALLBACK_COUNT: `0`.
- SYNTHETIC_ATTENDANCE_COUNT (`endsWith('2')` / `endsWith("2")`): `0`.
- Contrato paralelo muerto (`ClassSessionDTO`, `sessionFromDTO`, `sessionToDTO`, `studentFromDTO`, `studentToDTO`): `0`.
- `CourseMapper` / `course.mapper`: `0`.
- `CrearSesionRequest` / `crear-sesion-request`: `0`.
- `Docente UCO` / `Docente Titular`: `0`.
- `as unknown as ClassSession`: `0`.
- PASSWORD DEFAULT COUNT: `0` para credenciales por defecto productivas; quedan passwords explícitos en specs de validación.

## Clasificación de matches restantes

- `StudentAttendance.status`: contrato legítimo de asistencia.
- `Course.room` / formularios de grupo: `Grupo.aula`, legítimo.
- `HttpError.status`, `User.status`: otros dominios.
- `tipo/descripcion/aula`: catálogos, planes de estudio, errores, espacios físicos y otros dominios no `Sesion`.
