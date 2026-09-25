# ConversorEpub — Limpieza y Maquetación de Manuscritos a ePub

Aplicación de escritorio **Linux** (Flutter / Dart) que automatiza la limpieza tipográfica y la maquetación de manuscritos para generar capítulos XHTML listos para ensamblar en un editor como Sigil. 

*Esta aplicación fue completamente reescrita desde Python a Dart nativo para mejorar el rendimiento, simplificar el empaquetado y disfrutar de una interfaz Flutter, usando Python solo como microservicio de extracción PDF.*

## Características

- **4 modos de entrada** con detección automática:
  - **Word**: `.docx` → pandoc → HTML, con notas al pie reales de Word
  - **PDF**: `.pdf` → pdf2docx (vía microservicio embebido en Dart) → DOCX temporal → HTML
  - **Calibre**: carpeta con `.xhtml`/`.html` exportados desde Calibre
  - **Markdown**: carpeta con `.md` (procesado directamente vía pandoc)
- **Limpieza tipográfica canónica**: máquina de estados de comillas `«»` a todos los
  niveles (D1), comillas simples `‘’` (D2) con excepción para gritos anidados
  (`“‘‘Ahh!!’’”` → `«««Ahh!!»»»`, D9), remoción de basura de Word y Calibre,
  unificación de etiquetas `<strong>`→`<b>`, `<em>`→`<i>`.
- **Notas al pie** de pandoc y legacy `(NT##)` → `notas_Finales.xhtml` con llamadas
  enlazadas a su capítulo.
- **Generación automática de Tabla de Contenidos (`contenido-2.xhtml`)**: archivo TOC estructurado en XHTML para ePub (`<section epub:type="toc" role="doc-toc">`), enlazando automáticamente todos los capítulos procesados con sus títulos sincronizados.
- **Capítulos especiales avanzados y plantillas dedicadas (`assets/Plantillas/`)**:
  - **Prólogos y Epílogos múltiples**: numerados automáticamente (`prologo_01.xhtml`, `prologo_02.xhtml`, etc.) sin descontar numeración de capítulos normales.
  - **Interludios**: nombrados semánticamente (`interludio_01.xhtml`, etc.) y renderizados como tales sin forzar la palabra "Capítulo".
  - **Palabras del Autor**: plantilla `autor.xhtml` (`<section epub:type="afterword">`) reconociendo también "Palabras Finales".
  - **Palabras del Traductor**: plantilla `traductor.xhtml` (`<section epub:type="conclusion">`) reconociendo "Palabras del traductor" y "Notas del traductor".
  - **Capítulos e Historias Extras**: integrados de forma continua con numeración regular `C0X.xhtml`.
- **Desduplicación y parsing inteligente de títulos**:
  - Elimina prefijos repetidos en el cuerpo (evita `"Capítulo 1: Capítulo 1: Subtítulo"`).
  - Soporte para formatos numéricos directos como `0. Una Oferta Dudosa` o `2: Palacio Real`.
- **Imágenes** (pandoc, `[IMAGEN N]`, `!\ImageN\`) → `<figure>` con `sigil_split_marker`.
- **Separadores** `[HR]`/`[SEPARADOR]` → `※ ・ ※ ・ ※`.
- **Auto-splitter** por `<h1>/<h2>/<h3>` con tabla interactiva de títulos en la GUI (permite editar títulos y eliminar capítulos puntuales por fila).
- **GUI moderna en Flutter** con visor de diferencias antes/después, dashboard con badges de color
  individuales (capítulos, notas, imágenes, separadores) y tema oscuro Catppuccin.
- **Drop zone** con borde discontinuo para arrastrar archivos o carpetas.
- **Suite de pruebas**: Batería exhaustiva de tests unitarios y fuzzing de 5.000 documentos aleatorios en Dart (`flutter test`) que garantizan 100% de paridad y robustez.

## Instalación

Requiere **Flutter**, **pandoc** (para los modos Word y Markdown) y **Python 3** (únicamente con `pdf2docx` instalado, para usar el convertidor PDF).

```bash
# 1. Instalar dependencias del sistema (ejemplo Ubuntu/Debian)
sudo apt install pandoc python3 python3-pip

# 2. Instalar el paquete pdf2docx (requerido para procesar PDF)
pip3 install pdf2docx

# 3. Descargar y obtener dependencias de Flutter
cd conversor-epub/app_flutter
flutter pub get
```

## Uso y Ejecución en Desarrollo

Para probar la interfaz durante el desarrollo:

```bash
cd app_flutter
flutter run -d linux
```
*(Nota para usuarios de NixOS: `file_picker` requiere `zenity` para abrir los cuadros de diálogo. Si no lo tienes en tu sistema, usa: `nix-shell -p zenity --run "flutter run -d linux"`).*

## Compilación (Versión Final de Producción)

Para generar tu aplicación nativa e independiente para Linux:

```bash
cd app_flutter
flutter build linux
```

Una vez compilada, Flutter generará el bundle ejecutable en:
`build/linux/x64/release/bundle/ConversorEpubs`

### Compilar para Windows

Si deseas compilar la aplicación para ejecutarla en un sistema Windows:

1. Primero, asegúrate de estar en un entorno Windows o usar las herramientas adecuadas para generar la plantilla nativa:
   ```bash
   cd app_flutter
   flutter create --platforms windows .
   ```
2. Compila el ejecutable (requiere tener Visual Studio build tools instalado en Windows):
   ```bash
   flutter build windows
   ```
El archivo `.exe` se generará en la carpeta `build/windows/runner/Release/`.

> **DISTRIBUCIÓN Y PORTABILIDAD:**  
> La aplicación es **100% autónoma y portable**. Todas las plantillas XHTML (`template.xhtml`, `prologo.xhtml`, `epilogo.xhtml`, `autor.xhtml`, `traductor.xhtml`) están empaquetadas como assets nativos de Flutter dentro del binario compilado, y el microservicio de conversión de PDF está embebido directamente en el código de Dart.  
> Para compartir la aplicación, solo necesitas comprimir en un `.zip` la carpeta `build/linux/x64/release/bundle/` (o la carpeta `Release/` en Windows). El usuario final solo necesita tener `pandoc` y `python` con `pdf2docx` en su sistema.

## Estructura del Proyecto

```text
conversor-epub/
├── app_flutter/              # Proyecto principal en Flutter/Dart
│   ├── lib/                  # Código fuente (UI y motor core en Dart puro)
│   │   ├── main.dart         # Punto de entrada de la aplicación
│   │   ├── ui/               # Interfaz gráfica (home_screen.dart)
│   │   └── motor/            # Lógica pura (limpieza, plantillas, render, etc.)
│   ├── assets/               # Plantillas empaquetadas nativamente en el ejecutable
│   │   ├── Plantillas/       # prologo.xhtml, epilogo.xhtml, autor.xhtml, traductor.xhtml
│   │   └── Conv_Xhtml/       # template.xhtml
│   ├── test/                 # Suite de pruebas unitarias y fuzzing de comillas
│   ├── linux/                # Configuración de compilación nativa Linux
│   └── pubspec.yaml          # Metadatos y dependencias de la aplicación
├── assets/                   # Recursos estáticos de referencia
├── AGENTS.md                 # Especificación técnica y comportamiento canónico
├── Requisitos.md             # Especificación funcional
└── CHANGELOG.md              # Registro cronológico detallado de cambios
```

## Pruebas (Tests)

Ejecuta todas las pruebas unitarias y de estrés de estado (fuzzing) del motor:

```bash
cd app_flutter
flutter test
```

## Limitaciones conocidas

- Los modos Word y Markdown requieren que `pandoc` esté en el PATH del sistema.
- El modo PDF requiere que Python 3 y `pdf2docx` estén instalados en el sistema.
- La ambigüedad entre títulos y citas anidadas NO se resuelve por heurísticas (D5): la red de seguridad es el visor de diferencias de la GUI.