# Product Guidelines

## Core Principles
1. **Prevención de Errores y Transparencia:** La aplicación no asume ni adivina intenciones ambiguas. Se prioriza la visualización clara del estado de los datos (visor Diff) y validaciones estrictas (conteo de títulos) antes de permitir acciones destructivas o de generación.
2. **Arquitectura Desacoplada:** El núcleo (`motor/`) debe mantenerse libre de efectos secundarios y lógica de interfaz, limitando la UI únicamente a la orquestación y visualización.

## Tono y Voz
* **Técnico, directo y conciso.**
* Los mensajes de error, etiquetas de UI y la salida del CLI deben ir directo al punto.
* Se evita la jerga innecesaria, pero no se sacrifica la precisión técnica por amabilidad.
* Las advertencias y errores deben especificar qué falló y por qué (ej. "Títulos: 4/5 — falta 1" en lugar de "Hubo un error con los capítulos").

## UI / UX Design
* **Identidad Visual Estricta:** La aplicación utiliza de manera obligatoria un tema oscuro inspirado en *Catppuccin* gestionado a través de un QSS global.
* **Paleta de Colores:** 
  * Base: `#1e1e2e` y `#313244`.
  * Acento principal: `#89b4fa` (Azul).
  * Estados: `#a6e3a1` (Éxito), `#f9e2af` (Advertencia), `#f38ba8` (Error).
* **Jerarquía de Controles:** Los botones principales de acción (ej. "Generar Archivos") deben resaltar visualmente, mientras que las acciones secundarias usan tonos grises. Se utilizan iconos y *badges* de color para mejorar la lectura rápida en el dashboard.
