# ConversorEpub — Limpieza y Maquetación de Manuscritos a ePub

Aplicación de escritorio nativa para **Linux** y **Windows** (escrita en Flutter / Dart) que automatiza la limpieza tipográfica y la maquetación de manuscritos para generar capítulos XHTML profesionales listos para ensamblar en un editor de ePubs como Sigil.

---

## Características Principales

### 1. Interfaz Moderna a 3 Paneles (Flutter Desktop)
- **Panel Izquierdo (Configuración y Carga)**:
  - **Edición en lote**: Configura el número de inicio (`Start`), prefijo (`Cap. `) y sufijo (` - `) y aplícalos a todos los capítulos con un solo clic.
  - **Dropzone interactiva**: Zona de arrastrar y soltar con borde punteado dinámico, compatible con selección manual por clic y feedback de archivo cargado (nombre, tamaño formateado y estado).
  - **Acciones inferiores**: Botones estilizados para `+ Añadir`, `— Eliminar`, `Ajustes` y `Ayuda`.
- **Panel Central (Estructura y Tabla de Capítulos)**:
  - **Cápsulas de estadísticas en tiempo real**: Contadores instantáneos de *Capítulos*, *Notas al pie*, *Imágenes detectadas* y *Separadores*.
  - **Tabla interactiva de capítulos**:
    - Identificador con numeración de dos dígitos (`01`, `02`, ...).
    - Campo de texto editable en línea para personalizar el título de cada capítulo.
    - **Badge interactivo de Tipo de Capítulo**: Muestra la clasificación semántica con colores dedicados (*Cuerpo*, *Prólogo*, *Epílogo*, *Interludio*, *Autor*, *Traductor*) y permite reclasificar manualmente cualquier capítulo desplegando un menú contextual.
    - **Acciones por fila**: Botón de alternancia de *Título con Imagen* (permite asignar y editar el número de imagen de portada de capítulo) y eliminación individual con confirmación.
- **Panel Derecho (Resumen y Vista Previa)**:
  - **Métricas del manuscrito**: Conteo total de palabras del libro (*word count*) y estimación de páginas de lectura (~300 palabras por página).
  - **Vista previa limpia**: Muestra el código XHTML final generado del capítulo seleccionado (reemplaza el visor de diferencias raw para un flujo de trabajo más limpio y rápido).
  - **Compilación final**: Botón destacado `Compilar ePub Final [✓]` para exportar todo el lote a la carpeta deseada mediante el selector nativo del sistema.

### 2. Modos de Entrada con Detección Automática
- **Word (`.docx`)**: Procesado mediante `pandoc` → HTML5, extrayendo notas al pie reales de Word.
- **PDF (`.pdf`)**: Conversión estructurada con `pdf2docx` a DOCX temporal → HTML5 con soporte de detección inteligente de entornos (`.venv`, `python3` y `nix-shell` automático en NixOS).
- **Calibre (`.xhtml` / `.html`)**: Limpieza profunda de etiquetas residuales y basura de maquetación proveniente de Calibre.
- **Markdown (`.md`)**: Soporte para archivos individuales o lotes de carpetas procesados directamente.

### 3. Limpieza Tipográfica Canónica
- **Comillas canónicas**:
  - **D1**: Todos los niveles de comillas dobles se convierten a comillas angulares latinas `«` y `»`.
  - **D2**: Comillas simples explícitas convertidas a tipográficas inglesas `‘` y `’`.
  - **D9**: Comillas simples encadenadas a dobles o ternas (`“‘‘Ahh!!’’”` → `«««Ahh!!»»»`) se normalizan como anidadas sin romper el balance.
  - Cortafuegos canónicos por salto de párrafo (`<p>`, `</p>`) y saltos de línea (`<br>`).
  - Apertura automática tras dos puntos o punto y coma (`:`, `;`).
- **Limpieza de código basura**: Remoción de atributos y estilos residuales de Microsoft Word y Calibre, preservando clases semánticas autorizadas como `class="mistico"`.
- **Unificación de etiquetas**: `<strong>` → `<b>`, `<em>` → `<i>`.

### 4. Capítulos Especiales, Plantillas y Tabla de Contenidos
- **Tabla de Contenidos Automática (`contenido-2.xhtml`)**: Genera el archivo TOC estructurado en XHTML para ePub (`<section epub:type="toc" role="doc-toc">`) enlazando todos los capítulos con sus nombres reales de archivo y títulos actualizados.
- **Plantillas especiales dedicadas (`assets/Plantillas/`)**:
  - **Prólogos y Epílogos múltiples**: Clasificados y numerados automáticamente (`prologo_01.xhtml`, `prologo_02.xhtml`, etc.) sin consumir números de capítulos regulares.
  - **Interludios semánticos**: Nombrados como `interludio_01.xhtml` y formateados con la etiqueta "Interludio" en lugar de forzar "Capítulo".
  - **Palabras del Autor (`autor.xhtml`)**: `<section epub:type="afterword">` reconociendo también "Palabras Finales".
  - **Palabras del Traductor (`traductor.xhtml`)**: `<section epub:type="conclusion">` para notas y palabras del traductor.
  - **Capítulos e Historias Extras**: Mantenidos con numeración regular continua `C0X.xhtml`.
- **Deduplicación canónica de `<hr>`**: Elimina splits redundantes contiguos (`sigil_split_marker`), limpiando el límite entre el encabezado del capítulo y el inicio del contenido.
- **Soporte de Título con Imagen**: Descomenta y configura dinámicamente `<figure class="dimg"><img src="../Images/{NUM}.jpg" /></figure>` con título oculto accesible para Sigil, o elimina los comentarios residuales si no se utiliza imagen.

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

El repositorio incluye un archivo [`shell.nix`](shell.nix) listo para usar con todas las dependencias (Flutter, Pandoc, GTK3 y Python con `pdf2docx`):

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
│   │   ├── ui/               # Interfaz gráfica (home_screen.dart, widgets, pintores)
│   │   └── motor/            # Núcleo puro (limpieza, plantillas, render, adaptadores)
│   ├── assets/               # Plantillas XHTML empaquetadas nativamente en el ejecutable
│   │   ├── Conv_Xhtml/       # template.xhtml
│   │   └── Plantillas/       # prologo.xhtml, epilogo.xhtml, autor.xhtml, traductor.xhtml
│   ├── test/                 # Suite de pruebas unitarias y fuzzing de comillas (27 tests)
│   ├── linux/                # Configuración de compilación nativa en C++/GTK
│   └── pubspec.yaml          # Metadatos, dependencias y assets declarados
├── assets/                   # Recursos estáticos (ícono oficial PNG, archivo .desktop)
├── shell.nix                 # Entorno reproducible para NixOS (Flutter, Pandoc, Python pdf2docx)
├── AGENTS.md                 # Especificación técnica canónica y reglas del motor
├── CHANGELOG.md              # Registro cronológico detallado de cambios
└── README.md                 # Documentación general del proyecto
```

---

## Pruebas Automatizadas

La aplicación cuenta con una batería de pruebas de invariantes tipográficas, deduplicación de marcadores, títulos y plantillas especiales:

```bash
cd app_flutter
flutter test
```