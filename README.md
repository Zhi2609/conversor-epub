# ConversorEpub — Limpieza y Maquetación de Manuscritos a ePub

Aplicación de escritorio **Linux** (PySide6) que unifica los tres scripts legacy del
proyecto (`Conversor.py`, `Migrador.py`, `MigradorMD.py`) en un solo motor central:
automatiza la limpieza tipográfica y la maquetación de manuscritos para generar
capítulos XHTML listos para ensamblar en un editor como Sigil.

## Características

- **3 modos de entrada** con detección automática:
  - **Word**: `.docx` → pandoc → HTML, con notas al pie reales de Word
  - **Calibre**: carpeta con `.xhtml`/`.html` exportados desde Calibre
  - **Markdown**: carpeta con `.md` (párrafos automáticos, imágenes, blockquotes)
- **Limpieza tipográfica canónica**: máquina de estados de comillas `«»` a todos los
  niveles (D1), comillas simples `‘’` (D2), remoción de basura de Word y Calibre,
  unificación de etiquetas `<strong>`→`<b>`, `<em>`→`<i>`.
- **Notas al pie** de pandoc y legacy `(NT##)` → `notas_Finales.xhtml` con llamadas
  enlazadas a su capítulo.
- **Imágenes** (pandoc, `[IMAGEN N]`, `!\ImageN\`) → `<figure>` con `sigil_split_marker`.
- **Separadores** `[HR]`/`[SEPARADOR]` → `※ ・ ※ ・ ※`.
- **Auto-splitter** por `<h1>/<h2>/<h3>` con tabla editable de títulos en la GUI.
- **Capítulos especiales sin numeración** (Prólogo, Epílogo, Palabras del autor) con plantillas independientes (`Plantillas/`).
- **GUI con visor de diferencias** antes/después, dashboard con badges de color
  individuales (capítulos, notas, imágenes, separadores) y tema oscuro Catppuccin.
- **Drop zone** con borde discontinuo para arrastrar archivos o carpetas.
- **Tests golden**: 84 tests que congelan el comportamiento de salida.

## Instalación

Requiere **Python 3.10+** y **pandoc** para el modo Word:

```bash
sudo apt install pandoc
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt   # PySide6, pytest
```

## Uso

### Interfaz gráfica

```bash
python3 app/app.py
```

Arrastra el archivo/carpeta a la ventana, edita los títulos y
pulsa **Generar Archivos**.

### Línea de comandos (motor sin GUI)

```bash
python3 motor-cli.py <entrada> -o <salida> [-t template.xhtml] [-c titulos.txt] [-p Plantillas] [-n 1] [--modo auto|word|calibre|markdown]
```

Ejemplos:

```bash
# DOCX (modo Word, requiere pandoc)
python3 motor-cli.py novela.docx -o Capitulos

# Carpeta de Markdown
python3 motor-cli.py carpeta_md/ -o Capitulos

# Carpeta de Calibre con títulos
python3 motor-cli.py carpeta_calibre/ -o Capitulos -c caps.txt
```

### Salida

- `Capitulos/C01.xhtml` … `C{NN:02d}.xhtml` por capítulo
- `Capitulos/notas_Finales.xhtml` con las notas al pie
- La carpeta de salida se limpia en cada ejecución

## Empaquetado (AppImage)

```bash
sudo apt install binutils        # PyInstaller lo necesita (objdump)
pip install pyinstaller
# linuxdeploy: binario de https://github.com/linuxdeploy/linuxdeploy/releases

./empaquetar.sh                  # PyInstaller onefile → dist/ConversorEpub
./empaquetar.sh appimage         # → ConversorEpub-x86_64.AppImage
```

Tras modificar el código, basta con repetir `./empaquetar.sh [appimage]` para
regenerar el binario.

## Tests

```bash
python3 -m pytest tests/
# o sin pytest:
python3 -m unittest discover tests
```

Los tests golden (`tests/golden/`) congelan la salida esperada por modo y son la
red de seguridad para cualquier cambio futuro del motor.

## Estructura

```
conversor-epub/
├── app/              # Interfaz gráfica de usuario (PySide6)
├── motor/            # Lógica central pura de conversión
├── assets/           # Recursos estáticos
│   ├── Plantillas/   # plantillas para capítulos especiales (prologo.xhtml, epilogo.xhtml, autor.xhtml)
│   └── Conv_Xhtml/   # template central
├── tests/            # Tests golden y unitarios
├── motor-cli.py      # entry point de consola
└── empaquetar.sh     # build PyInstaller + AppImage
```

## Documentación

- **AGENTS.md**: especificación técnica y comportamiento canónico (fuente de verdad)
- **Requisitos.md**: especificación funcional
- **CHANGELOG.md**: registro de cambios por fecha

## Limitaciones conocidas

- El modo Word requiere `pandoc` en el PATH.
- La ambigüedad entre títulos y citas anidadas NO se resuelve por heurísticas
  (D5): la red de seguridad es el visor de diferencias de la GUI.