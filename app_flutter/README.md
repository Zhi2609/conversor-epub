# ConversorEpub (`app_flutter`)

Aplicación de escritorio nativa para **Linux** desarrollada en **Flutter / Dart** que conforma el motor tipográfico y la estación de trabajo editorial de **ConversorEpub** bajo el estándar **Base3 v1.16.2 / ZeePubs**.

> Para la documentación general del proyecto, instalación de dependencias del sistema e integración de escritorio (`.desktop`), consulta el [README principal](../README.md) y la especificación técnica en [AGENTS.md](../AGENTS.md).

---

## Arquitectura del Módulo

```text
app_flutter/
├── lib/
│   ├── main.dart                          # Punto de entrada y configuración de tema oscuro
│   ├── ui/                                # Capa de Interfaz Gráfica (Flutter Desktop)
│   │   ├── home_screen.dart               # Workstation principal a 3 paneles y Drag & Drop
│   │   └── widgets/
│   │       ├── formulario_metadatos.dart  # Editor OPF (estándar v1.16.2, importación desde .epub)
│   │       ├── panel_secciones.dart       # Gestión del spine canónico (19 posiciones)
│   │       ├── inspector_seccion.dart     # Previsualización XHTML y visor de cambios
│   │       └── dialogo_buscar_reemplazar.dart # Búsqueda y reemplazo con soporte Regex
│   └── motor/                             # Núcleo puro de procesamiento en Dart
│       ├── adaptadores.dart               # Wrappers de Pandoc (.docx/.md) y Python (.pdf)
│       ├── busqueda_reemplazo.dart        # Motor de búsqueda/reemplazo en memoria
│       ├── division.dart                  # División de capítulos por encabezados
│       ├── empaquetado.dart               # Compilador de contenedor ePub 3 (ZIP + OPF + XHTML)
│       ├── imagenes.dart                  # Procesamiento de figuras (<figure>) y separadores (<hr>)
│       ├── lector_epub_metadatos.dart     # Importador de metadatos desde volúmenes .epub previos
│       ├── limpieza.dart                  # Máquina de estados canónica de comillas (D1, D2, D9)
│       ├── metadatos.dart                 # Modelo BookMetadata, UUID v7, ISBN y taxonomía ZeePubs
│       ├── modelo.dart                    # Entidades Chapter, Nota, Resultado y Contadores
│       ├── notas.dart                     # Extracción e inyección de notas al pie (notas.xhtml)
│       ├── plantillas.dart                # Mapeo de secciones especiales (prólogo, epílogo, etc.)
│       ├── procesar.dart                  # Orquestador del pipeline (D6)
│       ├── render.dart                    # Renderizado e inyección en plantillas XHTML
│       └── secciones.dart                 # Estructura canónica de 19 secciones del ePub
├── assets/                                # Recursos empaquetados en el binario (rootBundle)
│   ├── Base3_v1.16.0.epub                 # Plantilla base oficial actualizada a especificación v1.16.2
│   ├── Base3_v1.15.0.epub                 # Plantilla base legacy
│   ├── Conv_Xhtml/                        # Plantilla general de capítulo (template.xhtml)
│   ├── Plantillas/                        # Plantillas de secciones (prólogo, epílogo, autor, notas, etc.)
│   └── ConversorEpub.png                  # Ícono de la aplicación
├── linux/                                 # Runner nativo C++ / GTK3 para Linux
├── test/                                  # Suite de pruebas unitarias, fuzzing y regresión (69 tests)
└── pubspec.yaml                           # Declaración de dependencias y assets
```

---

## Comandos de Desarrollo y Compilación

Ejecuta todos los comandos desde este directorio (`app_flutter/`):

### 1. Obtener dependencias
```bash
flutter pub get
```

### 2. Ejecutar suite de pruebas (69 tests)
Verifica la máquina de estados de comillas (incluyendo fuzzing), limpieza de HTML, extracción de notas, formato dual de volúmenes, importación de metadatos y empaquetado OPF v1.16.2:
```bash
flutter test
```

### 3. Análisis estático de código
```bash
flutter analyze
```

### 4. Ejecutar en modo desarrollo
```bash
flutter run -d linux
```

### 5. Compilar ejecutable nativo de producción (Linux Release)
```bash
flutter build linux --release
```

El paquete compilado y autónomo (binario, librerías compartidas y `flutter_assets`) se genera en:
```text
build/linux/x64/release/bundle/ConversorEpubs
```

---

## Características Técnicas Clave del Motor

- **Estándar Base3 v1.16.2**:
  - Esquema multilingüe simétrico en `content.opf` tanto para `#title` como para `#serie` (`title-type`, `file-as`, `alternate-script xml:lang="es"` y `alternate-script xml:lang="ja"` para Kanji).
  - Formato dual de volumen: entero sin ceros en propiedades estructurales (`group-position` y `calibre:series_index`, ej. `1`) y formato con cero a la izquierda (`01`) en títulos visibles y nombre de archivo.
  - Tipo de documento canónico `<dc:type>Novela ligera</dc:type>` y preservación íntegra de páginas estructurales (`creditos.xhtml`, `toc.xhtml`, `contenido-2.xhtml`).
- **Importación de Metadatos entre Volúmenes**:
  - Permite cargar un `.epub` de un volumen anterior para autocompletar títulos, autores, ilustradores, equipo editorial, demografías, géneros y sinopsis, reiniciando automáticamente el volumen e identificadores únicos.
- **Clases Tipográficas Modernas**:
  - Uso estricto de clases CSS de Base3 v1.16.x (`text align-center large`, `cita`, `mistico`, `lucida`, `dimg`) sin clases duplicadas.
