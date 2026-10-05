# ConversorEpub — Limpieza, Maquetación y Compilación de ePubs

Aplicación de escritorio nativa para **Linux** (escrita en Flutter / Dart) que automatiza la limpieza tipográfica, la maquetación de manuscritos y la **compilación directa de archivos `.epub` completos** bajo el estándar editorial de **Base3 / ZeePubs**, listos para lectura o retoque final en Sigil.

---

## Características Principales

### 1. Compilación Integral a `.epub` (Estándar Base3 / ZeePubs)
- **Empaquetado directo a `.epub` (ePub 3)**: Genera un archivo `.epub` 100% estándar con el archivo `mimetype` sin comprimir al inicio del contenedor ZIP (offset byte 0).
- **Plantilla base integrada (`Base3_v1.15.0.epub`)**: Embebida como asset nativo de Flutter (`rootBundle`). Conserva tipografías incrustadas (`times.ttf`, `Castellar`, `Oswald`, etc.), hojas de estilo CSS (`style.css`, `nav-style.css`), páginas estructurales (`cubierta`, `sinopsis`, `resumen`, `perfil`, `titulo`, `creditos`, `logos`, etc.) y el contenedor `META-INF`.
- **Estructura canónica de 19 posiciones**: Alineación 1:1 con la espina dorsal (*spine*) de Base3, controlando la linealidad (`linear="yes"` / `linear="no"`) de cubiertas, páginas preliminares y de navegación.
- **Purga y exclusión limpia**: Elimina los capítulos de muestra (`Section0001.xhtml`, `Section0002.xhtml`) e inserta los capítulos del manuscrito (`C01.xhtml`, `C02.xhtml`, etc.). Las secciones deshabilitadas por el maquetador se purgan automáticamente del archivo ZIP, del manifiesto `<manifest>`, del `<spine>` y de la tabla de contenidos (`toc.xhtml` y `contenido-2.xhtml`).
- **Nomenclatura canónica de salida**: Autogenera el nombre del archivo final siguiendo el formato editorial:
  ```text
  Nombre de novela - V01 [GrupoTraductor].epub
  ```
- **Inyección de ilustraciones y portada**: Vincula carpetas locales con las imágenes de la novela (`01.jpg`, `cover.jpg`, etc.), asocia la cubierta automáticamente y alerta al usuario si alguna imagen referenciada en el texto no existe en la carpeta.
- **Exportación alternativa de XHTML**: Opción de exportar únicamente la carpeta con los archivos `.xhtml` limpios y maquetados para flujos de trabajo tradicionales en Sigil.

---

### 2. Gestor de Metadatos Editoriales OPF
Pantalla dedicada y accesible con un solo clic para configurar exhaustivamente el archivo `content.opf` y las páginas de créditos según las reglas de ZeePubs:

#### Taxonomía Trilingüe de Títulos
- **Título de la Novela en Español** (ej: *La Princesa Demonio*): Se deduce automáticamente al cargar el manuscrito. Alimenta el nombre del archivo `.epub` generado y el `<span class="grande" epub:type="title">` de la página de título interior (`titulo.xhtml`).
- **Subtítulo en Español (Opcional)** (ej: *La Historia del Demonio Despreocupado*): Se inyecta en `titulo.xhtml` bajo `<span epub:type="subtitle" role="doc-subtitle">`. Si se deja vacío, el marcador y el salto de línea se eliminan de forma limpia sin dejar texto residual.
- **Título de la Novela en Romaji / Japonés** (ej: *Akuma Koujo ~Yurui Akuma no Monogatari~*): Se utiliza en `<dc:title>` de `content.opf` produciendo:
  ```xml
  <dc:title>Akuma Koujo ~Yurui Akuma no Monogatari~ - Volumen 01 [KT]</dc:title>
  ```
  *(Si se deja vacío, hace fallback automático al título en español)*.
- **Título de la Novela en Inglés / Colección** (ej: *The Devil Princess [NL]*): Alimenta la colección de la obra tanto en ePub 3 como en metadatos de Calibre:
  ```xml
  <meta id="serie" property="belongs-to-collection">The Devil Princess [NL]</meta>
  <meta property="group-position" refines="#serie">01</meta>
  <meta name="calibre:series" content="The Devil Princess [NL]"/>
  <meta name="calibre:series_index" content="01"/>
  ```
- **Banner de previsualización en vivo**: Muestra en tiempo real cómo quedarán el `dc:title`, la colección y el nombre del archivo `.epub`.

#### Autores e Ilustradores Bilingües (Kanji + Ruby)
- Soporte para nombres en alfabeto latino y kanji/japonés (`<meta property="alternate-script" xml:lang="ja">`).
- Generación de anotaciones fonéticas `<ruby>` en la página de título:
  ```html
  <ruby>春の日びより<rp>(</rp><rt>Harunohi Biyori</rt><rp>)</rp></ruby>
  ```
- Indexación `file-as` con botón para inversión automática rápida (*Apellido, Nombre*).

#### Equipo Editorial, Identificadores y Publicación
- Roles de contribuyentes estándar: Traductor (`trl`), Corrector/Formateador (`mrk`, por defecto `Zhi`) y Distribuidor fijo (`ZeePubs`, rol `dst`).
- **Calibre Rating inmutable**: Valor canónico fijado en `9`.
- **Selector interactivo de fecha**: Campo con selector de calendario para establecer la fecha de publicación (`<dc:date>`).
- **Identificadores estructurados**:
  - **ISBN-13**: Formateo automático continuo con guiones canónicos 3-2-4-3-1 (`978-40-6528-058-4`).
  - **ISBN-10**: Formateo automático con guiones 2-4-3-1 (`40-6528-058-3`).
  - **Amazon ID**: Formato URN (`urn:amazon:...`).
  - **UUID v7**: Generación criptográfica RFC 9562 con ordenamiento cronológico para `BookId`.

#### Clasificación Canónica ZeePubs
- **Demografías duales exclusivas por grupo**:
  1. *Edad / Madurez*: `Maduro` o `Juvenil`.
  2. *Audiencia*: `Adultas/Josei`, `Adultos/Seinen`, `Chicas/Shoujo` o `Chicos/Shounen`.
- **20 Géneros Canónicos**: Chips de selección rápida (*Acción, Fantasía, Romance, Isekai, etc.*) + campo para etiquetas personalizadas.
- **Orden canónico estricto en `content.opf`**:
  ```xml
  <dc:subject>Maduro</dc:subject>
  <dc:subject>Adultos/Seinen</dc:subject>
  <dc:subject>Acción</dc:subject>
  <dc:subject>Fantasía</dc:subject>
  ```
- **Sinopsis editorial**: Generada en una sola línea unida por `&lt;br/&gt;&lt;br/&gt;` en el OPF e inyectada con advertencia previa para revisión en `sinopsis.xhtml` / `resumen.xhtml`.

---

### 3. Interfaz de Usuario y Workstation Editorial (Flutter Desktop)
- **Panel Izquierdo (Configuración y Carga)**:
  - **Dropzone interactiva**: Zona Drag & Drop con borde punteado dinámico, compatible con selección manual y feedback de peso/nombre.
  - **Edición en lote**: Configura el número de inicio (`Start`), prefijo (`Cap. `) y sufijo (` - `) y aplícalos a todos los capítulos con un solo clic.
- **Panel Central (Estructura y Tabla de Capítulos)**:
  - **Cápsulas estadísticas en vivo**: Contadores de *Capítulos*, *Notas al pie*, *Imágenes detectadas* y *Separadores*.
  - **Badges de tipo de capítulo**: Clasificación semántica con colores dedicados (*Cuerpo*, *Prólogo*, *Epílogo*, *Interludio*, *Historia Extra*, *Autor*, *Traductor*) reconfigurable mediante menú contextual.
  - **Acciones avanzadas**: Alternancia de títulos con imagen de cabecera (`dimg`), reordenamiento y borrado con opciones de fusión o descarte de texto.
- **Panel Derecho (Resumen y Vista Previa)**:
  - **Métricas de lectura**: Conteo total de palabras del libro y estimación de páginas.
  - **Visor XHTML**: Previsualización del código limpio del capítulo seleccionado.
  - **Botón `Compilar ePub Final [✓]`**: Orquesta la validación de archivos, imágenes y guardado con `FilePicker`.
- **Herramienta de Búsqueda y Reemplazo**: Modal con soporte de expresiones regulares (Regex), sensibilidad a mayúsculas/minúsculas, snippets de contexto en vivo y reemplazo por capítulo o en todo el libro.

---

### 4. Modos de Entrada con Detección Automática
- **Word (`.docx`)**: Procesado mediante `pandoc` → HTML5, extrayendo notas al pie nativas de Word.
- **PDF (`.pdf`)**: Conversión estructurada con `pdf2docx` a DOCX temporal → HTML5 con soporte de detección inteligente de entornos (`.venv`, `python3` global y fallback automático a `nix-shell` en NixOS).
- **Calibre (`.xhtml` / `.html`)**: Limpieza profunda de etiquetas residuales y basura de maquetación proveniente de Calibre.
- **Markdown (`.md`)**: Soporte para archivos individuales o lotes de carpetas procesados directamente.

---

### 5. Limpieza Tipográfica Canónica
- **Máquina de estados de comillas**:
  - **D1**: Todos los niveles de comillas dobles se convierten a comillas angulares latinas `«` y `»`.
  - **D2**: Comillas simples explícitas convertidas a tipográficas inglesas `‘` y `’`.
  - **D9**: Comillas simples encadenadas a dobles o ternas (`“‘‘Ahh!!’’”` → `«««Ahh!!»»»`) se normalizan como anidadas sin romper el balance.
  - Cortafuegos canónicos por salto de párrafo (`<p>`, `</p>`) y saltos de línea (`<br>`).
  - Apertura automática tras dos puntos o punto y coma (`:`, `;`).
- **Limpieza de código basura**: Remoción de atributos y estilos residuales de Microsoft Word y Calibre, preservando clases semánticas autorizadas como `class="mistico"`.
- **Unificación de etiquetas**: `<strong>` → `<b>`, `<em>` → `<i>`.

---

### 6. Capítulos Especiales, Plantillas y Notas al Pie
- **Notas al Pie Canónicas (`notas.xhtml`)**: Las llamadas numéricas en el cuerpo apuntan a `<a href="notas.xhtml#ntNN">` y se insertan directamente en la plantilla `notas.xhtml`.
- **Tabla de Contenidos Automática (`contenido-2.xhtml`)**: Genera el archivo TOC estructurado en XHTML para ePub (`<section epub:type="toc" role="doc-toc">`) enlazando todos los capítulos con sus nombres reales de archivo y títulos actualizados.
- **Plantillas especiales dedicadas (`assets/Plantillas/`)**:
  - **Prólogos y Epílogos múltiples**: Clasificados y numerados automáticamente (`prologo_01.xhtml`, etc.) sin consumir números de capítulos regulares.
  - **Interludios semánticos**: Nombrados como `interludio_01.xhtml` y formateados con la etiqueta "Interludio".
  - **Historias Extras**: Identificadas y ordenadas respetando la continuidad narrativa.
  - **Palabras del Autor (`autor.xhtml`)**: `<section epub:type="afterword">`.
  - **Palabras del Traductor (`traductor.xhtml`)**: `<section epub:type="conclusion">`.
- **Deduplicación canónica de `<hr>`**: Elimina splits redundantes contiguos (`sigil_split_marker`).

---

## Requisitos e Instalación

### Dependencias Externas
- **Pandoc**: Requerido para procesar documentos Word (`.docx`) y Markdown (`.md`).
- **Python 3 + pdf2docx**: Requerido únicamente si deseas convertir archivos `.pdf`.

### Instalación en Linux (Ubuntu / Debian / Fedora / Arch)

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y pandoc python3 python3-pip

# Instalar pdf2docx para soporte de PDF
pip3 install --user pdf2docx

# En Fedora
# sudo dnf install pandoc python3 python3-pip && pip3 install --user pdf2docx
```

### Instalación en NixOS

El repositorio incluye un archivo [`shell.nix`](shell.nix) listo para usar con todas las dependencias (Flutter, Pandoc, Ninja, CMake, Pkg-config, GTK3 y Python con `pdf2docx`):

```bash
# Entrar al entorno con todas las dependencias
nix-shell

# Ejecutar en desarrollo
cd app_flutter
flutter run -d linux
```

*(Nota: En NixOS, si abres la aplicación directamente fuera de `nix-shell`, el conversor invocará automáticamente `nix-shell -p python3Packages.pdf2docx` al procesar un PDF sin requerir configuración manual).*

---

## Compilación y Ejecución

### Modo Desarrollo

```bash
cd app_flutter
flutter run -d linux
```

### Compilación Nativa de Producción (Linux)

```bash
cd app_flutter
flutter build linux
```

El bundle ejecutable y autónomo se genera en:
`app_flutter/build/linux/x64/release/bundle/ConversorEpubs`

### Integración de Escritorio e Ícono (Wayland / KDE Plasma / GNOME)

El proyecto incluye el lanzador de escritorio [`assets/com.conversorepub.app.desktop`](assets/com.conversorepub.app.desktop) configurado con `StartupWMClass=com.conversorepub.app`. Para instalar el acceso directo y el ícono en tu sistema:

```bash
# Crear carpetas de usuario si no existen
mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/256x256/apps

# Copiar el icono oficial
cp assets/ConversorEpub.png ~/.local/share/icons/hicolor/256x256/apps/com.conversorepub.app.png

# Copiar el archivo .desktop
cp assets/com.conversorepub.app.desktop ~/.local/share/applications/

# Actualizar base de datos de aplicaciones
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
```

---

## Estructura del Proyecto

```text
conversor-epub/
├── app_flutter/              # Aplicación principal en Flutter / Dart
│   ├── lib/                  # Código fuente
│   │   ├── main.dart         # Punto de entrada de la aplicación
│   │   ├── ui/               # Interfaz gráfica
│   │   │   ├── home_screen.dart             # Dashboard principal a 3 paneles
│   │   │   └── widgets/
│   │   │       ├── formulario_metadatos.dart# Formulario OPF y taxonomía ZeePubs
│   │   │       ├── panel_secciones.dart     # Panel de gestión y orden del spine
│   │   │       ├── inspector_seccion.dart   # Inspector de capítulos y visor diff
│   │   │       └── dialogo_buscar_reemplazar.dart # Modal regex de búsqueda y reemplazo
│   │   └── motor/            # Núcleo puro portado a Dart
│   │       ├── modelo.dart            # Clases Chapter, Resultado, Nota, Contadores
│   │       ├── metadatos.dart         # Modelo BookMetadata, UUID v7, ISBN, subjects
│   │       ├── secciones.dart         # Modelado y spine canónico de 19 posiciones
│   │       ├── empaquetado.dart       # Generador de contenedor ePub 3 y manipulación OPF
│   │       ├── busqueda_reemplazo.dart# Motor de búsqueda y reemplazo en memoria
│   │       ├── limpieza.dart          # Máquina de estados canónica de comillas
│   │       ├── notas.dart             # Extractor y renderizador de notas al pie
│   │       ├── imagenes.dart          # Procesado de figuras y separadores
│   │       ├── division.dart          # Split por encabezados
│   │       ├── plantillas.dart        # Mapeo de capítulos especiales
│   │       ├── adaptadores.dart       # Wrappers de pandoc y microservicio PDF
│   │       ├── procesar.dart          # Orquestador del pipeline
│   │       └── render.dart            # Inyección en templates XHTML
│   ├── assets/               # Recursos empaquetados nativamente en el ejecutable
│   │   ├── Base3_v1.15.0.epub# Plantilla ePub base con estilos, fuentes y metadatos
│   │   ├── Conv_Xhtml/       # template.xhtml
│   │   ├── Plantillas/       # prologo.xhtml, epilogo.xhtml, autor.xhtml, traductor.xhtml, notas.xhtml
│   │   └── ConversorEpub.png # Ícono oficial de la aplicación
│   ├── test/                 # Suite de pruebas unitarias y de widgets (59 tests)
│   ├── linux/                # Configuración de compilación nativa en C++/GTK
│   └── pubspec.yaml          # Metadatos, dependencias y assets declarados
├── assets/                   # Recursos estáticos raíz (.desktop, ícono, plantillas)
├── shell.nix                 # Entorno reproducible para NixOS (Flutter, Pandoc, Python pdf2docx)
├── AGENTS.md                 # Especificación técnica canónica y reglas del motor
├── CHANGELOG.md              # Registro cronológico detallado de cambios
└── README.md                 # Documentación general del proyecto
```

---

## Pruebas Automatizadas

La aplicación cuenta con una suite completa de **59 pruebas automatizadas** que garantizan la integridad de:
- Máquina de estados y cortafuegos de comillas canónicas (`D1`, `D2`, `D9`).
- Fuzzing de balance tipográfico con documentos sintéticos.
- Deduplicación y formateo de marcadores `<hr>` y figuras de imágenes.
- Orden canónico de demografías y géneros (`ordenarSubjectsCanonico`).
- Formateo de identificadores ISBN-13 e ISBN-10 con guiones.
- Taxonomía trilingüe de títulos y subtítulos en `content.opf` y `titulo.xhtml`.
- Inyección y purga limpia en el manifiesto, spine y tabla de contenidos.

Para ejecutar toda la batería de pruebas:

```bash
cd app_flutter
flutter test
```