/* Documentación técnica — Sistema de Gestión de Asistencia UCO
   Comportamiento común: navegación, tema, índice de la página, diagramas Mermaid,
   gráficas Chart.js declarativas, flujos animados paso a paso y pestañas. */
(function () {
  'use strict';

  var PAGINAS = [
    { grupo: 'Visión general', items: [
      ['index.html', 'Inicio y mapa del sistema'],
      ['arquitectura.html', 'Arquitectura y patrones'],
      ['negocio.html', 'Reglas y flujos de negocio']
    ] },
    { grupo: 'Capas', items: [
      ['base-datos.html', 'Base de datos (SQL Server)'],
      ['backend.html', 'Backend (Spring Boot)'],
      ['frontend.html', 'Frontend (Angular)']
    ] },
    { grupo: 'Componentes', items: [
      ['notificaciones.html', 'Notificaciones por correo'],
      ['componentes-externos.html', 'Seguridad, Mensajes y Parámetros']
    ] },
    { grupo: 'Operación y calidad', items: [
      ['operacion.html', 'Laboratorio y despliegue'],
      ['calidad.html', 'Pruebas, cobertura y HU']
    ] }
  ];

  function actual() {
    var p = location.pathname.split('/').pop();
    return p === '' ? 'index.html' : p;
  }

  /* ---------- Tema ---------- */
  var CLAVE_TEMA = 'docs-uco-tema';
  function leerTema() { try { return localStorage.getItem(CLAVE_TEMA); } catch (e) { return null; } }
  function guardarTema(v) { try { localStorage.setItem(CLAVE_TEMA, v); } catch (e) { /* sin almacenamiento */ } }
  function temaEfectivo() {
    var t = document.documentElement.getAttribute('data-theme');
    if (t) return t;
    return window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  var guardado = leerTema();
  if (guardado) document.documentElement.setAttribute('data-theme', guardado);

  /* ---------- Navegación ---------- */
  function construirNav() {
    var nav = document.querySelector('.nav');
    if (!nav) return;
    var html = '<a class="marca" href="index.html"><span class="logo">UCO</span><span>Asistencia UCO<br><small style="font-weight:400;color:var(--texto-suave)">Documentación técnica</small></span></a>';
    PAGINAS.forEach(function (g) {
      html += '<h4>' + g.grupo + '</h4>';
      g.items.forEach(function (it) {
        var cur = it[0] === actual() ? ' aria-current="page"' : '';
        html += '<a class="enlace" href="' + it[0] + '"' + cur + '>' + it[1] + '</a>';
        if (cur) html += '<div class="toc" data-toc></div>';
      });
    });
    html += '<button class="tema" type="button" data-tema>Cambiar a tema ' + (temaEfectivo() === 'dark' ? 'claro' : 'oscuro') + '</button>';
    nav.innerHTML = html;
    nav.querySelector('[data-tema]').addEventListener('click', function () {
      var nuevo = temaEfectivo() === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', nuevo);
      guardarTema(nuevo);
      location.reload(); // Mermaid y Chart.js se vuelven a dibujar con los colores del tema.
    });

    var barra = document.querySelector('.barra-movil');
    if (barra) {
      barra.innerHTML = '<button type="button" aria-label="Abrir menú" data-menu>☰</button><strong>Asistencia UCO · Docs</strong>';
      barra.querySelector('[data-menu]').addEventListener('click', function () { nav.classList.toggle('abierta'); });
      nav.addEventListener('click', function (e) { if (e.target.closest('a')) nav.classList.remove('abierta'); });
    }
  }

  /* ---------- Índice de la página (h2) con resaltado al desplazarse ---------- */
  function construirIndice() {
    var toc = document.querySelector('[data-toc]');
    if (!toc) return;
    var titulos = Array.prototype.slice.call(document.querySelectorAll('.contenido h2[id]'));
    toc.innerHTML = titulos.map(function (h) { return '<a href="#' + h.id + '">' + h.textContent + '</a>'; }).join('');
    if (!('IntersectionObserver' in window)) return;
    var enlaces = toc.querySelectorAll('a');
    var obs = new IntersectionObserver(function (entradas) {
      entradas.forEach(function (en) {
        if (en.isIntersecting) {
          enlaces.forEach(function (a) { a.classList.toggle('activo', a.getAttribute('href') === '#' + en.target.id); });
        }
      });
    }, { rootMargin: '0px 0px -70% 0px' });
    titulos.forEach(function (h) { obs.observe(h); });
  }

  /* ---------- Colores leídos de los tokens ---------- */
  function token(nombre) { return getComputedStyle(document.documentElement).getPropertyValue(nombre).trim(); }
  var SERIES = ['--acento', '--acento-2', '--alerta', '--violeta', '--peligro', '--texto-suave'];

  /* ---------- Mermaid ---------- */
  function iniciarMermaid() {
    if (!window.mermaid) return;
    var oscuro = temaEfectivo() === 'dark';
    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      theme: 'base',
      fontFamily: 'Inter, Segoe UI, system-ui, sans-serif',
      themeVariables: {
        darkMode: oscuro,
        background: token('--superficie'),
        primaryColor: token('--acento-suave'),
        primaryBorderColor: token('--acento'),
        primaryTextColor: token('--texto'),
        secondaryColor: token('--acento-2-suave'),
        secondaryBorderColor: token('--acento-2'),
        tertiaryColor: token('--violeta-suave'),
        tertiaryBorderColor: token('--violeta'),
        lineColor: token('--texto-suave'),
        textColor: token('--texto'),
        mainBkg: token('--acento-suave'),
        nodeBorder: token('--acento'),
        clusterBkg: token('--superficie-2'),
        clusterBorder: token('--borde'),
        actorBkg: token('--acento-suave'),
        actorBorder: token('--acento'),
        noteBkgColor: token('--alerta-suave'),
        noteBorderColor: token('--alerta')
      },
      flowchart: { htmlLabels: true, curve: 'basis' },
      sequence: { mirrorActors: false }
    });
    window.mermaid.run({ querySelector: '.mermaid' });
  }

  /* ---------- Gráficas declarativas: <canvas data-grafica='{...config Chart.js...}'> ----------
     Si un dataset no trae colores, se le asignan los de la serie del tema. */
  function iniciarGraficas() {
    if (!window.Chart) return;
    var texto = token('--texto-suave');
    var rejilla = token('--borde');
    window.Chart.defaults.color = texto;
    window.Chart.defaults.borderColor = rejilla;
    window.Chart.defaults.font.family = 'Inter, Segoe UI, system-ui, sans-serif';
    document.querySelectorAll('canvas[data-grafica]').forEach(function (cv) {
      var cfg;
      try { cfg = JSON.parse(cv.getAttribute('data-grafica')); } catch (e) { console.error('Configuración de gráfica inválida', cv, e); return; }
      var circular = cfg.type === 'doughnut' || cfg.type === 'pie' || cfg.type === 'polarArea';
      (cfg.data.datasets || []).forEach(function (ds, i) {
        if (circular) {
          if (!ds.backgroundColor) ds.backgroundColor = (cfg.data.labels || []).map(function (_, j) { return token(SERIES[j % SERIES.length]); });
          ds.borderColor = token('--superficie');
        } else {
          var c = token(SERIES[i % SERIES.length]);
          if (!ds.backgroundColor) ds.backgroundColor = cfg.type === 'line' ? c + '33' : c;
          if (!ds.borderColor) ds.borderColor = c;
        }
      });
      cfg.options = cfg.options || {};
      cfg.options.responsive = true;
      cfg.options.maintainAspectRatio = false;
      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) cfg.options.animation = false;
      new window.Chart(cv, cfg);
    });
  }

  /* ---------- Flujos animados ----------
     <div class="flujo" data-flujo data-titulo="...">
       <div class="paso" data-detalle="Texto largo" data-actor="Docente">Acción corta</div> ...
     </div>
     data-tipo="error" en un paso lo pinta como camino de error. */
  function iniciarFlujos() {
    document.querySelectorAll('[data-flujo]').forEach(function (raiz) {
      var pasosOrigen = Array.prototype.slice.call(raiz.querySelectorAll(':scope > .paso'));
      var titulo = raiz.getAttribute('data-titulo') || '';
      var carril = document.createElement('div');
      carril.className = 'carril';
      pasosOrigen.forEach(function (p) {
        var actor = p.getAttribute('data-actor') || '';
        var accion = p.innerHTML;
        p.innerHTML = (actor ? '<div class="actor">' + actor + '</div>' : '') + '<div class="accion">' + accion + '</div>';
        if (p.getAttribute('data-tipo') === 'error') p.classList.add('error');
        carril.appendChild(p);
      });
      raiz.innerHTML = '';
      if (titulo) { var t = document.createElement('div'); t.className = 'flujo-titulo'; t.textContent = titulo; raiz.appendChild(t); }
      raiz.appendChild(carril);
      var detalle = document.createElement('div');
      detalle.className = 'detalle';
      detalle.setAttribute('aria-live', 'polite');
      raiz.appendChild(detalle);
      var controles = document.createElement('div');
      controles.className = 'controles';
      controles.innerHTML = '<button type="button" class="primario" data-accion="play">▶ Reproducir</button>' +
        '<button type="button" data-accion="prev">◀ Anterior</button>' +
        '<button type="button" data-accion="next">Siguiente ▶</button>' +
        '<button type="button" data-accion="reset">↺ Reiniciar</button>';
      raiz.appendChild(controles);

      var i = -1, temporizador = null;
      var btnPlay = controles.querySelector('[data-accion="play"]');
      function pintar() {
        pasosOrigen.forEach(function (p, k) {
          p.classList.toggle('actual', k === i);
          p.classList.toggle('visto', k < i);
        });
        if (i >= 0) {
          detalle.innerHTML = '<strong>Paso ' + (i + 1) + ' de ' + pasosOrigen.length + '.</strong> ' + (pasosOrigen[i].getAttribute('data-detalle') || '');
          pasosOrigen[i].scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'smooth' });
        } else {
          detalle.textContent = 'Pulsa «Reproducir» o «Siguiente» para recorrer el flujo paso a paso.';
        }
      }
      function detener() { if (temporizador) { clearTimeout(temporizador); temporizador = null; } btnPlay.textContent = '▶ Reproducir'; }
      // Avance automático encadenado con setTimeout; se detiene al llegar al final (no es sondeo de datos).
      function avanzarAuto() {
        if (i < pasosOrigen.length - 1) { i++; pintar(); temporizador = setTimeout(avanzarAuto, 2200); }
        else { detener(); }
      }
      controles.addEventListener('click', function (e) {
        var b = e.target.closest('button'); if (!b) return;
        var a = b.getAttribute('data-accion');
        if (a === 'play') {
          if (temporizador) { detener(); return; }
          if (i >= pasosOrigen.length - 1) i = -1;
          btnPlay.textContent = '❚❚ Pausar';
          avanzarAuto();
        } else if (a === 'next') { detener(); if (i < pasosOrigen.length - 1) i++; pintar(); }
        else if (a === 'prev') { detener(); if (i > 0) i--; pintar(); }
        else if (a === 'reset') { detener(); i = -1; pintar(); }
      });
      pintar();
    });
  }

  /* ---------- Pestañas accesibles ---------- */
  function iniciarPestanas() {
    document.querySelectorAll('.pestanas').forEach(function (raiz, n) {
      var tabs = raiz.querySelectorAll('[role="tab"]');
      var panels = raiz.querySelectorAll('[role="tabpanel"]');
      tabs.forEach(function (t, k) {
        var idT = 'pt-' + n + '-' + k, idP = 'pp-' + n + '-' + k;
        t.id = idT; t.setAttribute('aria-controls', idP);
        if (panels[k]) { panels[k].id = idP; panels[k].setAttribute('aria-labelledby', idT); }
        function activar() {
          tabs.forEach(function (x, j) { x.setAttribute('aria-selected', String(j === k)); x.tabIndex = j === k ? 0 : -1; if (panels[j]) panels[j].hidden = j !== k; });
        }
        t.addEventListener('click', activar);
        t.addEventListener('keydown', function (e) {
          var j = k;
          if (e.key === 'ArrowRight') j = (k + 1) % tabs.length;
          else if (e.key === 'ArrowLeft') j = (k - 1 + tabs.length) % tabs.length;
          else return;
          tabs[j].click(); tabs[j].focus(); e.preventDefault();
        });
        if (k === 0) activar();
      });
    });
  }

  function pie() {
    var c = document.querySelector('.contenido');
    if (!c || c.querySelector('.pie')) return;
    var d = document.createElement('div');
    d.className = 'pie';
    d.innerHTML = 'Sistema de Gestión de Asistencia UCO · Documentación técnica generada a partir del código de los repositorios (BD, Backend, Frontend, Infra y Complementos). ' +
      'Fuentes de verdad: <code>AsistenciasUCO-Infra/docs/governance/CONSTITUTION.md</code> y los contratos de <code>docs/contracts/</code>.';
    c.appendChild(d);
  }

  function favicon() {
    if (document.querySelector('link[rel="icon"]')) return;
    var l = document.createElement('link');
    l.rel = 'icon';
    l.href = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="7" fill="#0b5cad"/><text x="16" y="21" font-size="11" font-family="Arial" font-weight="700" fill="#fff" text-anchor="middle">UCO</text></svg>');
    document.head.appendChild(l);
  }

  document.addEventListener('DOMContentLoaded', function () {
    favicon();
    construirNav();
    construirIndice();
    iniciarPestanas();
    iniciarFlujos();
    iniciarMermaid();
    iniciarGraficas();
    pie();
  });
})();
