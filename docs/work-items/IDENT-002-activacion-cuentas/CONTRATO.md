# IDENT-002 — Activación de cuentas por correo (sin contraseña en el registro)

Estado: contrato acordado con el responsable (2026-11-15). Implementación en `feat/activacion-cuentas` (BD, Backend,
Frontend, Infra).

## Problema

Las altas que hace otra persona (decano por el administrador, coordinador por el decano, docente por el coordinador,
estudiante por el administrador o por el docente) exigían una contraseña inicial escrita por quien registra. Esa
contraseña la conocían dos personas y había que entregarla por fuera; al personal no le llegaba ningún correo. Keycloak
la marcaba temporal y pedía cambiarla en el primer ingreso.

## Decisión

1. **Registro sin contraseña.** Las cinco altas hechas por otra persona dejan de recibir `password`. La matrícula
   autónoma por QR no cambia: el estudiante escribe su contraseña y verifica el correo (IDENT-001).
2. **Cuenta nueva en el proveedor de identidad: deshabilitada, correo sin verificar y sin credencial.** Una persona
   que ya tenía cuenta (otro rol) no cambia: solo se le suma el rol y no recibe correo.
3. **Correo `ACTIVACION_CUENTA`** con un enlace de un solo uso `{plataforma}/activar-cuenta#token=…` (mismo token de
   IDENT-001: 32 bytes aleatorios, solo su SHA-256 en la BD, vigencia `VERIFICACION_CORREO.TTL_HORAS`).
4. **Activación en la página pública:** la persona define su contraseña; el backend la guarda en el proveedor como
   definitiva, habilita la cuenta, marca el correo verificado y consume el token. La columna legada
   `Usuario.password` guarda el hash de un secreto aleatorio (la autenticación vive en el proveedor).
5. **Reenvío del enlace** por quien puede gestionar la cuenta (mismo alcance que el acceso a cuentas).
6. **Sin cambios** en la asignación del perfil del PDP: sigue la sincronización existente (opt-in) o la asignación
   manual del componente de Seguridad.

## Contrato HTTP

### Altas (cambia el cuerpo: se retira `password`)

`POST /api/v1/admin/decanos`, `POST /api/v1/decano/coordinadores`, `POST /api/v1/coordinador/docentes`,
`POST /api/v1/admin/estudiantes/admision`, `POST /api/v1/grupos/{grupoId}/estudiantes`.
Un `password` enviado por un cliente anterior se ignora. Respuestas sin cambios. Ninguna está en el contrato WORM
(`openapi-golden-path.yaml` solo congela el `GET` de `/grupos/{grupoId}/estudiantes`).

### `POST /api/v1/public/verificar-correo` (compatible hacia atrás)

Cuerpo: `{ "token": string, "password": string | null }`.

| Caso | HTTP | Código |
| :--- | :--- | :--- |
| Token inválido, vencido, usado o revocado | 400 | `VCE_002` (igual que hoy) |
| La cuenta no tiene contraseña y no se envió `password` (el token **no** se consume) | 400 | `VCE_009` |
| `password` no cumple la política | 400 | `ERR_PASSWORD_POLITICA_INVALIDA` / `ERR_PASSWORD_IGUAL_IDENTIFICACION` |
| Activación o verificación exitosa | 200 | `VCE_006` |

Si la cuenta ya tiene contraseña (QR), `password` se ignora y el flujo es el de IDENT-001.

### `POST /api/v1/identidad/cuentas/activacion/reenvios` (nuevo)

Roles: ADMINISTRADOR, DECANO, COORDINADOR. Cuerpo `{ "correo": string }`. Alcance de `InstitutionalScopePort
.canGestionarCuenta` (administrador: cualquiera; decano: coordinadores, docentes y estudiantes de su facultad;
coordinador: docentes y estudiantes de su programa).

| Caso | HTTP | Código |
| :--- | :--- | :--- |
| Enlace reenviado (cuenta pendiente de activación) | 200 | `ACT_001` |
| La cuenta ya está activa | 409 | `ACT_002` |
| Correo inexistente | 404 | `NOF_APP_010` |
| Fuera de alcance | 403 | `ACC_APP_013` |

`POST /api/v1/grupos/{grupoId}/estudiantes/{estudianteId}/reenviar-verificacion` envía `ACTIVACION_CUENTA` si la
cuenta no tiene contraseña y `VERIFICACION_CORREO` si la tiene.

## Base de datos

Plantilla `ACTIVACION_CUENTA` (marcadores `nombre`, `enlace`, `rol`) y mensajes `VCE_009`, `ACT_001`, `ACT_002`
(semilla y migración para bases existentes). El token reutiliza `usp_*_token_verificacion_correo`.

## Pruebas

- BD: semilla y migración idempotentes; plantilla y mensajes presentes.
- Backend: unitarias de cada alta (sin contraseña, correo de activación solo para cuenta nueva), de la activación
  (VCE_009 sin consumir el token, política, éxito) y del reenvío (alcance, ACT_002); adaptador Keycloak (alta sin
  credencial, contraseña definitiva). Cobertura según el gate del repositorio.
- Frontend: formularios sin contraseña, página de activación (paso de contraseña ante `VCE_009`) y botones de reenvío.
- E2E: `test_all_hus.ps1` sin `password` en las altas; prueba de laboratorio de punta a punta con el buzón de prueba.
