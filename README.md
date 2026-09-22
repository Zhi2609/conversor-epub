# ConversorEpub — Limpieza y Maquetación de Manuscritos a ePub

Aplicación de escritorio **Linux** (Flutter / Dart) que automatiza la limpieza tipográfica y la maquetación de manuscritos para generar capítulos XHTML listos para ensamblar en un editor como Sigil. 

*Esta aplicación fue completamente reescrita desde Python a Dart nativo para mejorar el rendimiento, simplificar el empaquetado y disfrutar de una interfaz Flutter, usando Python solo como microservicio de extracción PDF.*

## Características

- **4 modos de entrada** con detección automática:
  - **Word**: `.docx` → pandoc → HTML, con notas al pie reales de Word
  - **PDF**: `.pdf` → pdf2docx (vía microservicio Python) → DOCX temporal → HTML
  - **Calibre**: carpeta con `.xhtml`/`.html` exportados desde Calibre
  - **Markdown**: carpeta con `.md` (procesado directamente vía pandoc)
- **Limpieza tipográfica canónica**: máquina de estados de comillas `«»` a todos los
  niveles (D1), comillas simples `‘’` (D2) con excepción para gritos anidados
  (`“‘‘Ahh!!’’”` → `«««Ahh!!»»»`, D9), remoción de basura de Word y Calibre,
  unificación de etiquetas `<strong>`→`<b>`, `<em>`→`<i>`.
- **Notas al pie** de pandoc y legacy `(NT##)` → `notas_Finales.xhtml` con llamadas
  enlazadas a su capítulo.
- **Imágenes** (pandoc, `[IMAGEN N]`, `!\ImageN\`) → `<figure>` con `sigil_split_marker`.
- **Separadores** `[HR]`/`[SEPARADOR]` → `※ ・ ※ ・ ※`.
- **Auto-splitter** por `<h1>/<h2>/<h3>` con tabla editable de títulos en la GUI.
- **Capítulos especiales sin numeración** (Prólogo, Epílogo, Palabras del autor) con plantillas independientes (`assets/Plantillas/`).
- **GUI moderna en Flutter** con visor de diferencias antes/después, dashboard con badges de color
  individuales (capítulos, notas, imágenes, separadores) y tema oscuro Catppuccin.
- **Drop zone** con borde discontinuo para arrastrar archivos o carpetas.
- **Suite de pruebas**: Tests (incluyendo Fuzzing con 5.000 iteraciones) traducidos completamente a Dart garantizan la pureza y fidelidad del comportamiento de limpieza heredado.

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

Para generar tu aplicación nativa e independiente:

```bash
cd app_flutter
flutter build linux
```

Una vez compilada, Flutter generará un ejecutable en:
`build/linux/x64/release/bundle/app_flutter`

> **NOTA DE RUTAS RELATIVAS:**  
> La aplicación compilada utiliza rutas relativas para leer los directorios de `assets/` y el microservicio `convertidor_pdf.py`. Si decides empaquetar o mover el binario final fuera de su carpeta original, asegúrate de mantener `assets/` y `convertidor_pdf.py` a un nivel superior, conservando la estructura de carpetas esperada.

## Estructura del Proyecto

```text
conversor-epub/
├── app_flutter/              # Proyecto principal en Flutter/Dart
│   ├── lib/                  # Código fuente (UI y motor core)
│   ├── test/                 # Suite de pruebas unitarias
│   ├── linux/                # Archivos de build nativo para Linux
│   └── pubspec.yaml          # Dependencias de Dart
├── assets/                   # Recursos estáticos
│   ├── Plantillas/           # Plantillas para capítulos especiales (prologo, etc.)
│   └── Conv_Xhtml/           # Template central (template.xhtml)
├── convertidor_pdf.py        # Microservicio diminuto en Python (sólo para PDF)
├── AGENTS.md                 # Especificación técnica y comportamiento canónico
├── Requisitos.md             # Especificación funcional
└── CHANGELOG.md              # Registro de cambios
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