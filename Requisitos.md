# Especificación de Requisitos: Aplicación de Limpieza y Maquetación de ePubs

## 1. Visión General del Proyecto
Desarrollar una aplicación de escritorio nativa multiplataforma que automatice la limpieza, estructuración y formateo de manuscritos para su uso en editores de ePub (como Sigil). La aplicación funcionará como un "Hub" centralizado capaz de ingerir tres tipos de formatos de entrada:
1. Archivos `.docx` (Microsoft Word).
2. Carpetas con archivos `.xhtml`/`.html` (Exportados de Calibre).
3. Carpetas con archivos `.md` (Markdown).
La app detectará el formato automáticamente, aplicará la pre-conversión necesaria, ejecutará un motor central de limpieza tipográfica (comillas, basura HTML) y generará capítulos perfectamente estructurados en base a una plantilla maestra.

## 2. Stack Tecnológico Sugerido
* **Lenguaje:** Python 3.10+
* **Interfaz Gráfica (GUI):** PySide6 / PyQt6 (elegido definitivamente porque el visor Diff necesita renderizado HTML, descartando CustomTkinter).
* **Dependencia Externa:** `pandoc` (debe estar instalado en el sistema para la conversión de DOCX a HTML).
* **Distribución:** Empaquetado nativo para Linux (binario ELF ejecutable, AppImage o Flatpak) usando PyInstaller o similar.

---

## 3. Requisitos de la Interfaz de Usuario (UI)
La ventana principal de la aplicación debe estar dividida en las siguientes áreas clave:

1. **Selector de Entrada Universal:** 
   * Una zona de "Drag & Drop" (Arrastrar y Soltar) o un botón de exploración que acepte: un archivo `.docx`, o una carpeta que contenga archivos `.xhtml`/`.html`, o una carpeta que contenga archivos `.md`.
   * Un indicador visual que muestre qué modo de procesamiento se activó automáticamente (Modo Word, Modo Calibre o Modo Markdown).
2. **Panel de Estadísticas (Dashboard):**
   * Tras analizar el archivo cargado, debe mostrar contadores en tiempo real:
     * 📄 Capítulos detectados.
     * 📝 Notas al pie detectadas.
     * 🖼️ Imágenes a procesar.
     * ✂️ Separadores de escena.
3. **Editor de Capítulos (Auto-Splitter):**
   * Una tabla o lista editable donde se muestren los títulos de los capítulos detectados automáticamente (mediante etiquetas `<h1>`, `<h2>`, etc.).
   * El usuario debe poder editar estos títulos o eliminar falsos positivos antes de generar los archivos finales.
4. **Visor de Diferencias (Diff / Preview):**
   * Pantalla dividida (Split View).
   * **Izquierda:** Código HTML original/sucio (salida cruda de Pandoc o Calibre).
   * **Derecha:** Código XHTML limpio, procesado con la lógica de limpieza y plantillas.

---

## 4. Requisitos de Lógica y Procesamiento (Core)

La aplicación debe mantener e integrar la lógica de los scripts anteriores, ejecutando las siguientes tareas en cadena:

### 4.1. Adaptadores de Entrada (Pre-procesamiento)
Dependiendo del origen de los datos, el programa ejecutará un pre-procesamiento antes de enviar el texto al motor central de limpieza:

* **Modo DOCX (Word):** Usa `pandoc` para convertir a HTML. Requiere auto-división del documento buscando etiquetas `<h1>` para separar los capítulos. Extrae y formatea las notas al pie nativas.
* **Modo Calibre (XHTML):** Extrae exclusivamente el contenido dentro de las etiquetas `<body>`. Elimina atributos invasivos (`class="calibre1"`, IDs, `dir`, `lang="es"`). Detecta el título del capítulo desde el primer `<h1>`-`<h6>` y lo elimina del cuerpo para no duplicarlo.
* **Modo Markdown (MD):** 
  * Limpia caracteres invisibles/unicode (`\u200B-\u200D\uFEFF`).
  * Convierte sintaxis MD a HTML (`***` -> `<b><i>`, `**` -> `<b>`, `_` -> `<i>`, `#` -> `<h1>`).
  * Soporta etiquetas personalizadas como `[blockquote]` -> `<blockquote class="mistico">` y sintaxis de imágenes `!\ImageXX\`.
  * Autogenera las etiquetas de párrafo (`<p>`) basándose en los dobles saltos de línea (`\n\n`), omitiendo envolver encabezados o figuras.

### 4.2. Auto-Splitter (División de Capítulos)
* **Eliminación del archivo `caps.txt`:** El programa debe leer el archivo HTML completo, detectar etiquetas de encabezado (`<h1>`, `<h2>` o `<h3>`) y usar cada aparición como punto de corte.
* El texto comprendido entre un encabezado y el siguiente será inyectado en una plantilla maestra (`template.xhtml`).
* Se creará un archivo enumerado por cada corte normal (ej. `C01.xhtml`, `C02.xhtml`).
* **Capítulos Especiales:** Los capítulos con títulos como "Prólogo", "Epílogo" o "Palabras del autor" usarán plantillas específicas ubicadas en la carpeta `Plantillas/`, y no consumirán numeración secuencial (`prologo.xhtml`, etc.).

### 4.3. Limpieza de Código (Basura de Word y Calibre)
* Normalizar etiquetas: Convertir `<strong>` a `<b>` y `<em>` a `<i>`.
* Restaurar etiquetas HTML válidas escapadas por Pandoc (`&lt;p&gt;` → `<p>`).
* Eliminar atributos y etiquetas inservibles mediante Expresiones Regulares (Regex):
  * `span` con `class`, `style` o `id`.
  * Atributos como `dir="ltr"`, `lang="es"`.
  * Clases basura (ej. `class="calibre1"`).
  * Etiquetas de formato vacías (`<b></b>`, `<i></i>`).
  * Unificar etiquetas partidas (`</i><i>` → fusionar).

### 4.4. Máquina de Estados: Comillas Anidadas
* **Normalización:** Las comillas dobles (rectas, tipográficas) se estandarizan a `"`. Las simples a `'`.
* **Rastreo de Niveles:** El programa debe iterar carácter por carácter para determinar la profundidad de la cita:
  * **Todos los niveles** de comillas dobles (rectas o tipográficas) se convierten en `«` (apertura) / `»` (cierre). El contador de niveles se mantiene solo para emparejar aperturas y cierres y para el cortafuegos de fin de párrafo.
* **Comillas Simples Independientes:** Las comillas simples explícitas originales se procesarán con tipografía curva (`‘` `’`) sin afectar el contador de niveles de las comillas dobles.
* **Cortafuegos de Párrafo:** El contador de nivel debe resetearse obligatoriamente a `0` al encontrar un salto de línea (`\n`) o un cierre de bloque (`</p>`, `<br>`, `</div>`, etc.) para evitar "efectos cascada" por errores de tipeo en el manuscrito original.

### 4.5. Alineación de Comillas y Etiquetas HTML
* Forzar que las comillas queden siempre por fuera de las etiquetas de formato (`<b>`, `<i>`).
* Ejemplo de corrección: `<i>«Texto»</i>` o `«<i>Texto»</i>` debe convertirse invariablemente en `«<i>Texto</i>»`.

### 4.6. Extracción y Formateo de Notas al Pie
* **Extracción:** Localizar la sección `<section id="footnotes">` generada por Pandoc.
* **Limpieza de Nota:** Arrancar la sección del documento principal, limpiar su contenido de basura HTML y quitar las anclas de retorno (`↩︎`).
* **Formateo ePub:** Generar un archivo único (`notas_Finales.xhtml`). Cada nota debe formatearse así:
  `<div class="nota"><p id="nt01"><a href="C01.xhtml#rf01"><sup>❮01❯</sup> Texto de nota.</a></p></div>`
* **Llamadas Inline:** Actualizar las llamadas en el cuerpo de los capítulos para que correspondan al nuevo formato (`<a href="notas_Finales.xhtml#nt01" id="rf01"><sup>❮01❯</sup></a>`).
* **Soporte Legacy:** Mantener compatibilidad con marcas previas manuales estilo `(NT01)`.

### 4.7. Procesamiento de Imágenes y Separadores
* **Imágenes:** Detectar la sintaxis de imagen nativa de Pandoc o los *placeholders* manuales `[IMAGEN XX]`.
  * Reemplazo: Bloque `<figure class="dimg">` con salto de página Sigil (`<hr class="sigil_split_marker" />`).
* **Separadores:** Detectar las palabras `[HR]` o `[SEPARADOR]`.
  * Reemplazo: `<p class="hr centrado grande"><b>※ ・ ※ ・ ※</b></p>`.

---

## 5. Flujo de Trabajo (User Journey)
1. El usuario abre la app.
2. Arrastra su archivo de trabajo (DOCX) o su carpeta de trabajo (Calibre o Markdown) al área principal.
3. La aplicación detecta el formato y ejecuta el "Adaptador de Entrada" correspondiente de manera oculta.
4. El texto pre-procesado pasa por el "Motor Central de Limpieza" (Máquina de estados de comillas, alineación, eliminación de basura).
5. La interfaz se actualiza mostrando las estadísticas (capítulos, notas, imágenes) y llena la tabla del Editor de Capítulos.
6. El usuario verifica los títulos detectados, revisa las diferencias en el "Visor Diff" y hace clic en "Generar Archivos".
7. La app limpia el directorio de salida y escribe los archivos `.xhtml` usando la plantilla maestra.
