# Sistema de Diseño: Aurora Education — GestioAsistencia UCO
> **Versión:** 2.0.0 | **Stack:** Angular 18/19 (Signals & OnPush) & Tailwind CSS v4.0+  
> **Ámbito:** Frontend Institucional UCO

---

## Índice
* [1. Principios Visuales](#1-principios-visuales)
* [2. Paleta de Colores y Tokens Semánticos](#2-paleta-de-colores-y-tokens-semánticos)
  * [Escalas de Color](#escalas-de-color)
  * [Feedback Semántico](#feedback-semántico)
  * [Matriz de Accesibilidad (WCAG 2.1)](#matriz-de-accesibilidad-wcag-21)
* [3. Tipografía y Escala](#3-tipografía-y-escala)
* [4. Iconografía y Ecosistema Angular](#4-iconografía-y-ecosistema-angular)
* [5. Layout, Espaciado y Bento Grid](#5-layout-espaciado-y-bento-grid)
* [6. Configuración Tailwind CSS](#6-configuración-tailwind-css)
* [7. Componente de Referencia (Angular Signals & OnPush)](#7-componente-de-referencia-angular-signals--onpush)
* [Documentos Relacionados](#documentos-relacionados)

---

## 1. Principios Visuales

* **Claridad Intencional:** Interfaces orientadas a reducir la fatiga cognitiva mediante divulgado progresivo (acordeones, paneles laterales y pestañas).
* **Calidez Táctil (Japandi / Modern SaaS):** Esquinas generosas (`rounded-xl`, `rounded-2xl`), sombras suaves cálidas (`shadow-warm-*`) y bordes orgánicos (`border-warm-200`).
* **Consistencia Predictiva:** Alturas, radios interactivos y anillos de foco homogéneos en todos los módulos de los 5 roles institucionales.
* **Accesibilidad Silenciosa:** Cumplimiento estricto de contraste WCAG 2.1 AA/AAA y soporte 100% de navegación por teclado.

---

## 2. Paleta de Colores y Tokens Semánticos

### Escalas de Color

| Token | Tono Base | Hex Clave | Uso Principal |
| :--- | :--- | :--- | :--- |
| `primary-50`..`950` | Verde Botánico | `#2B7744` (`600`) | Acciones primarias, botones, branding institucional UCO. |
| `accent-50`..`950` | Oro Solar | `#EAB308` (`500`) | Acentos, llamadas a la atención, badges e hitos académicos. |
| `warm-50`..`950` | Lino / Alabastro | `#FAF8F5` (`50`) | Canvas general, fondos de tarjeta (`white`), bordes (`200`) y texto (`900`). |

### Feedback Semántico

| Estado | Texto | Fondo (`surface`) | Borde (`border`) |
| :--- | :--- | :--- | :--- |
| **Success** | `#15803D` (`emerald-700`) | `#F0FDF4` (`emerald-50`) | `#BBF7D0` (`emerald-200`) |
| **Warning** | `#B45309` (`amber-700`) | `#FFFBEB` (`amber-50`) | `#FDE68A` (`amber-200`) |
| **Danger** | `#B91C1C` (`red-700`) | `#FEF2F2` (`red-50`) | `#FECACA` (`red-200`) |
| **Info** | `#0369A1` (`sky-700`) | `#F0F9FF` (`sky-50`) | `#BAE6FD` (`sky-200`) |

### Matriz de Accesibilidad (WCAG 2.1)
* **Texto Primario (`warm-900` `#2A221C`) sobre Canvas (`warm-50` `#FAF8F5`):** 13.4:1 (WCAG AAA).
* **Texto Secundario (`warm-600` `#6E5F51`) sobre Blanco (`#FFFFFF`):** 5.1:1 (WCAG AA).
* **Blanco (`#FFFFFF`) sobre Botón Primario (`primary-600` `#2B7744`):** 4.8:1 (WCAG AA).

---

## 3. Tipografía y Escala

* **Sans-Serif Principal (UI, Formularios, Datos):** `Plus Jakarta Sans` / `Inter`.
* **Serif Secundaria (Encabezados H1/H2, Diplomas):** `Fraunces` / `Lora`.

| Nivel | Tipografía | Clase Tailwind | Tamaño / Interlínea | Peso |
| :--- | :--- | :--- | :--- | :--- |
| **Hero / Display** | Serif | `text-4xl md:text-5xl` | 36px / 48px | Bold (`700`) |
| **H1 Página** | Serif | `text-3xl md:text-4xl` | 30px / 36px | SemiBold (`600`) |
| **H2 Sección** | Serif | `text-2xl md:text-3xl` | 24px / 30px | SemiBold (`600`) |
| **H3 Tarjeta** | Sans | `text-lg md:text-xl` | 18px / 20px | SemiBold (`600`) |
| **Body Base** | Sans | `text-base` | 16px (1.5) | Regular (`400`) |
| **Body Small** | Sans | `text-sm` | 14px (1.45) | Regular (`400`) |
| **Caption** | Sans | `text-xs` | 12px (1.4) | Medium (`500`) |

---

## 4. Iconografía y Ecosistema Angular

* **Librería Oficial:** `lucide-angular` (`npm install lucide-angular`).
* **Trazo Estándar:** `stroke-width="2px"` para 16-20px; `1.75px` para 24px+.
* **Dimensiones:** `w-4 h-4` (badges/inputs), `w-5 h-5` (botones/sidebar), `w-8 h-8` a `w-12 h-12` (empty states).
* **Helper de Clases Inmutables:**
  ```typescript
  import { clsx, type ClassValue } from 'clsx';
  import { twMerge } from 'tailwind-merge';

  export function cn(...inputs: ClassValue[]): string {
    return twMerge(clsx(inputs));
  }
  ```

---

## 5. Layout, Espaciado y Bento Grid

```text
Breakpoint   Ancho      Patrón de Navegación            Contenedor
Base         < 640px    Bottom Bar fija + Top Header    px-4 py-4 (100%)
md           >= 768px   Sidebar Mini (72px)             px-8 py-6
lg           >= 1024px  Sidebar Completo (256px)        max-w-6xl mx-auto
xl           >= 1280px  Sidebar + Panel de Métricas     max-w-7xl mx-auto
```

* **Tarjetas:** `p-4 sm:p-6 lg:p-8`, bordes `border border-warm-200/80`, esquinas `rounded-2xl`.
* **Bento Grid:** `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-6`.

---

## 6. Configuración Tailwind CSS

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: ["./src/**/*.{html,ts}"],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#F0F7F2', 100: '#DCEDE1', 200: '#BCE0C6', 300: '#92CBA2',
          400: '#64B07B', 500: '#3F9359', 600: '#2B7744', 700: '#205F36',
          800: '#1C4C2D', 900: '#173F26', 950: '#0A2314',
          DEFAULT: '#2B7744', foreground: '#FFFFFF',
        },
        accent: {
          50: '#FEFCE8', 100: '#FEF9C3', 200: '#FEF08A', 300: '#FDE047',
          400: '#FACC15', 500: '#EAB308', 600: '#CA8A04', 700: '#A16207',
          800: '#854D0E', 900: '#713F12', 950: '#422206',
          DEFAULT: '#EAB308', foreground: '#2A221C',
        },
        warm: {
          50: '#FAF8F5', 100: '#F4EFEA', 200: '#E8E1D9', 300: '#D6CCC0',
          400: '#B4A696', 500: '#8E7E6E', 600: '#6E5F51', 700: '#54483D',
          800: '#3D332B', 900: '#2A221C', 950: '#18130F',
        },
      },
      fontFamily: {
        sans: ['"Plus Jakarta Sans"', 'Inter', 'system-ui', 'sans-serif'],
        serif: ['Fraunces', 'Lora', 'Georgia', 'serif'],
      },
      boxShadow: {
        'warm-sm': '0 1px 2px 0 rgba(42, 34, 28, 0.04)',
        'warm-md': '0 4px 12px -2px rgba(42, 34, 28, 0.06)',
        'warm-xl': '0 20px 32px -6px rgba(42, 34, 28, 0.10)',
      },
    },
  },
  plugins: [],
};
```

---

## 7. Componente de Referencia (Angular Signals & OnPush)

Conforme a las reglas arquitectónicas institucionales (Signals reactivas y OnPush mandatorio):

```typescript
import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LucideAngularModule, Clock, ArrowRight } from 'lucide-angular';

@Component({
  selector: 'app-course-card',
  standalone: true,
  imports: [CommonModule, LucideAngularModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <article class="group relative flex flex-col justify-between overflow-hidden rounded-2xl bg-white p-6 border border-warm-200/80 shadow-warm-sm hover:shadow-warm-md hover:border-primary-300 transition-all duration-300">
      <div>
        <div class="flex items-center justify-between gap-2 mb-4">
          <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-accent-100 text-accent-900 border border-accent-200">
            <span class="w-1.5 h-1.5 rounded-full bg-accent-600"></span>
            {{ category() }}
          </span>
          <span class="inline-flex items-center text-xs text-warm-500 gap-1">
            <lucide-icon [img]="ClockIcon" class="w-3.5 h-3.5 text-warm-400"></lucide-icon>
            {{ duration() }}
          </span>
        </div>

        <h3 class="font-serif text-xl font-semibold text-warm-900 group-hover:text-primary-700 transition-colors">
          {{ title() }}
        </h3>
        <p class="mt-2 text-sm text-warm-600 line-clamp-2 leading-relaxed">
          {{ description() }}
        </p>
      </div>

      <div class="mt-6 pt-4 border-t border-warm-100 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="w-7 h-7 rounded-full bg-primary-100 flex items-center justify-center text-primary-800 font-semibold text-xs">
            {{ instructorInitials() }}
          </div>
          <span class="text-xs font-medium text-warm-700">{{ instructorName() }}</span>
        </div>

        <button 
          type="button"
          class="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-primary-600 hover:bg-primary-700 text-white text-sm font-semibold shadow-warm-sm transition-all focus:outline-none focus:ring-2 focus:ring-primary-600/30 active:scale-95"
          [attr.aria-label]="'Ingresar al curso ' + title()">
          <span>Continuar</span>
          <lucide-icon [img]="ArrowRightIcon" class="w-4 h-4 transition-transform group-hover:translate-x-0.5"></lucide-icon>
        </button>
      </div>
    </article>
  `
})
export class CourseCardComponent {
  readonly title = input.required<string>();
  readonly description = input.required<string>();
  readonly category = input.required<string>();
  readonly duration = input.required<string>();
  readonly instructorName = input.required<string>();
  readonly instructorInitials = input.required<string>();

  readonly ClockIcon = Clock;
  readonly ArrowRightIcon = ArrowRight;
}
```

---
**Documentos Relacionados:**
* [Centro Maestro de Documentación](./README.md) - Navegación global.
* [Stack Tecnológico](./stack-tecnologico.md) - Versiones y frameworks UI.
* [Frontend README](../GestioAsistenciaFrontend/README.md) - Configuración de componentes y estilos.
