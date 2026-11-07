# Verificacion E.1 en pantalla: cambio de tokens @theme

Fecha: 2026-11-07. Worktree: `C:\Proyectos\GestionAsistencia-CULM001\GestioAsistenciaFrontend` (rama `integracion/CULM-001`). Entorno: `http://localhost:4200` (ng serve con recarga en caliente), backend y seguridad baseline locales.

## Valores de tokens

| Token | Original (HEAD) | Temporal de prueba |
| :--- | :--- | :--- |
| `--color-primary-500` | `#10b981` | `#ff00ff` |
| `--color-primary-600` | `#059669` | `#cc00cc` |
| `--color-danger-500` | `#ef4444` | `#0000ff` |

Los valores se aplicaron en `src/styles.css` y se comprobaron en runtime (`getPropertyValue` sobre `:root`): `#ff00ff`, `#cc00cc`, `#0000ff`.

## Comprobaciones

Comprobacion A: numero de elementos con colores antiguos (`rgb(16,185,129)`, `rgb(5,150,105)`, `rgb(239,68,68)`) en color, fondo o borde. Debe ser 0.
Comprobacion B: existe algun elemento con magenta (`rgb(255,0,255)` o `rgb(204,0,204)`). Debe ser true.

| Pantalla | Vista | A (restos antiguos) | B (magenta) |
| :--- | :--- | :---: | :---: |
| `/login` (pagina publica) | escritorio | 0 | false |
| `/app/dashboard` (Panel Principal) | escritorio | 0 | true |
| `/app/docente/grupos` (Mis Grupos) | escritorio | 0 | true |
| `/app/asistencia` (Control de Asistencia) | escritorio | 0 | true |
| `/app/docente/horarios` (Mis Horarios) | escritorio | 0 | true |
| `/app/dashboard` | movil 375x812 | 0 | true |
| `/app/asistencia` | movil 375x812 | 0 | true |

Sin desbordamiento horizontal en movil (`scrollWidth <= innerWidth`) en las dos pantallas comprobadas.

## Elementos que conservan color verde de identidad (fuera de la comprobacion A)

La comprobacion A solo busca los tres colores antiguos exactos. Los elementos siguientes siguen en verde porque usan otros tonos de la escala `primary` (no modificados por la prueba) o valores directos. Son un hallazgo para el paquete E.1: el cambio de `@theme` no reemplaza toda la identidad si hay tonos vecinos codificados.

- Boton "Ingresar con cuenta institucional" (`/login`): `button[type=submit]`, `background-color: rgb(4,120,87)` (`#047857`, `primary-700`). Se ve verde, no magenta.
- Boton "Nuevo grupo" (`/app/docente/grupos`): verde oscuro (tono `primary-700`/`800`, no verificado por selector exacto).
- Panel de hero del dashboard y tarjeta de "Sesion seleccionada" en `/app/asistencia`: fondo verde muy oscuro (tonos `primary-800`/`900`/`950`), no tocados por la prueba.
- Etiqueta "Carga Docente" (`/app/docente/horarios`): verde claro sobre fondo verde suave (`primary-100`/`700`), no tocada.
- Los botones de accion "Tomar Asistencia Ahora" y "Revisar Reclamos" del dashboard usan el color de acento (dorado), no `primary`.

Conclusion parcial: el cambio de `primary-500`, `primary-600` y `danger-500` se propaga a los elementos que los usan (comprobacion B positiva en todas las pantallas), pero hay una franja de tonos `primary-700` a `950` que no cambia con esos tres tokens. Si la prueba pretende demostrar que `@theme` controla toda la identidad visual, esa parte no se cumple todavia.

## Incidencias de proceso

- Durante la sesion de prueba el `ng serve` aplico los cambios sin reiniciar.
- El cierre de sesion se hizo desde el boton "Cerrar sesion" (ref en la barra lateral).
- Restauracion: se ejecuto `git checkout -- src/styles.css`. Despues `git status --short` muestra solo ` M public/assets/env.js` (preexistente). `grep` confirma `--color-primary-500: #10b981` y `--color-danger-500: #ef4444`.
- Aviso: tras la restauracion llego una notificacion de que `src/styles.css` habia cambiado en disco desde la ultima lectura. El checkout pudo descartar un cambio externo ocurrido en ese intervalo; no se pudo comprobar el contenido previo. Revisar si alguien edito ese archivo entre el Edit y el checkout.
- Credencial de prueba local usada solo en `localhost`/`keycloak.localhost` segun `docs/CREDENCIALES_PRUEBAS_LOCAL.md`; no se registra aqui.
