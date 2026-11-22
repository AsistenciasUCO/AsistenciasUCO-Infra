# Guía para autores del sitio de documentación (docs/sitio)

Sitio estático en HTML, sin compilación. Cada página parte de `_plantilla.html` y usa solo:
- `assets/estilos.css`: tokens de color (claro y oscuro) y componentes;
- `assets/app.js`: navegación, índice automático de los `h2[id]`, Mermaid, gráficas declarativas, flujos animados y pestañas;
- Mermaid 11.4.1 (jsDelivr) y Chart.js 4.4.1 (cdnjs), con las mismas etiquetas `<script>` de la plantilla.

No se agregan otras librerías, CSS en línea con colores fijos ni scripts propios por página. Los colores salen siempre de los tokens.

## Componentes disponibles
- **Encabezado:** `header.hero` con `h1`, resumen y `.etiquetas`.
- **Secciones:** `h2` con `id` en kebab-case; el índice lateral se arma solo con ellos. Las subsecciones van en `h3`.
- **Diagramas:** `figure.diagrama > pre.mermaid` y `figcaption`. Sirven `flowchart`, `sequenceDiagram`, `erDiagram`, `classDiagram`, `stateDiagram-v2` y `C4` simple con `flowchart` y `subgraph`. **El contenido de `pre.mermaid` NO lleva entidades HTML**: escribe `-->` tal cual. Evita `<` y `>` dentro de las etiquetas; si hacen falta, usa comillas `["texto"]`.
- **Gráficas:** `figure.grafica > div.lienzo > canvas[data-grafica='{JSON de Chart.js}']`.
  - El JSON debe ser válido, sin funciones y con comillas dobles; el atributo va entre comillas simples.
  - Los colores se asignan solos.
  - Siempre lleva `role="img"` y `aria-label`.
- **Flujo animado:** `div.flujo[data-flujo][data-titulo]` con hijos `div.paso[data-actor][data-detalle]` (acción corta como contenido). `data-tipo="error"` marca un camino de error. Úsalo para procesos de negocio y técnicos, de 4 a 9 pasos.
- **Tarjetas:** `.tarjetas > .tarjeta` (con `.icono` emoji opcional, `h4` y `p`). Indicadores: `.kpis > .kpi > .valor + .rotulo`.
- **Tablas:** siempre dentro de `div.tabla-contenedor`.
- **Avisos:** `.nota`, `.nota.exito`, `.nota.alerta` y `.nota.peligro`, con un `<strong>` inicial.
- **Otros:** `.pestanas` (tablist, tab y tabpanel), `details.acordeon` para listados largos y `.dos-columnas`.
- **Código:** `<pre><code>…</code></pre>` con fragmentos cortos y reales, citando el archivo.

## Reglas de contenido
1. Todo en español, claro para un desarrollador nuevo. Primero el porqué y luego el cómo.
2. **Verdad desde el código:** cada afirmación se comprueba leyendo los repos y se cita la ruta relativa al workspace, por ejemplo `GestioAsistenciaBackend/src/main/java/...`. No se inventan clases, SP ni endpoints. Si algo no se encuentra, no se menciona.
3. **Cifras reales:** los conteos (tablas, SP, endpoints, componentes, pruebas) se calculan con `grep` o `find` sobre los repos actuales (ramas `feat/p3-revision-final` en BD, Backend y Frontend, y `feat/p2-revision-final` en Infra) y se pone la fecha. Métricas ya medidas el 2026-11-22:
   - Gate de BD: 1100 casos y 0 fallos, migraciones 01–70.
   - Backend: 5177 pruebas; JaCoCo 95,9 % en líneas y 87,5 % en ramas.
   - Frontend: 3862 pruebas; realtime 95,24 % en líneas y 86,81 % en ramas; E2E 21/21.
   - Servicio de Notificaciones: 145 pruebas; 98,5 % en líneas y 92,6 % en ramas.
   - HU: 140 certificadas, 29 descartadas y 4 abiertas en develop, más HU179/180 (receso) por registrar; 175 en total.
   - Checklist: 113 CUMPLE, 22 PARCIAL y 5 PENDIENTE EXTERNO.
4. **Notificaciones:** está en plena separación. El estado destino es el servicio propio en `Complementos/Notificaciones`. El backend conserva la outbox y entrega por HTTP con una `idempotencyKey`; las plantillas, el SMTP y el tope de envíos viven en el servicio. Ver `docs/PLAN_COMPONENTE_NOTIFICACIONES.md` en la raíz del workspace y `Complementos/Notificaciones/README.md`. Describe el estado destino y marca con `.nota.alerta` lo que siga en curso.
5. **Nunca** incluyas secretos, contraseñas (ni siquiera las de prueba), tokens ni correos reales de personas. Los usuarios de prueba se nombran solo por rol.
6. **Accesibilidad:** encabezados en orden, `aria-label` en las gráficas, texto alternativo en los diagramas complejos (resumen en `figcaption`) y tablas con `th`.
7. **Verificación:** el sitio se sirve en `http://localhost:8765/` (servidor ya levantado). Antes de terminar, abre cada página tuya con Playwright y el Chrome del sistema:
   - `require` desde `C:\Proyectos\GestionAsistencia\GestioAsistenciaFrontend\node_modules\playwright` o `@playwright/test`;
   - `chromium.launch({ channel: 'chrome' })`;
   - PATH de Node: `export PATH="$LOCALAPPDATA/Programs/node-v22.23.5-win-x64:$PATH"`.

   Comprueba que:
   - no haya errores en la consola;
   - todos los `pre.mermaid` se hayan convertido en `svg` (si un diagrama falla, Mermaid deja el texto o un SVG de error con «Syntax error»: corrígelo);
   - todas las gráficas tengan un `canvas` con tamaño;
   - a 375 px no haya scroll horizontal de la página (`document.documentElement.scrollWidth <= 375`).

   Guarda una captura de cada página en `C:\Users\ARIASR~1\AppData\Local\Temp\claude\fe968ea5054f6735\56effef1-a32e-4a3a-b2d5-c73e6c0dfa8a\scratchpad\docs-capturas\`.
8. Solo edita tus páginas. `assets/` y `_plantilla.html` son compartidos: no los modifiques; si te falta algo, dilo en tu informe.
9. **Commits:** los hace el orquestador; tú no hagas commits.
