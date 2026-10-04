# Especificación de Diseño: Workstation Editorial y Portado de Herramientas ZeeTools

**Fecha**: 2026-10-03  
**Estado**: Borrador para Revisión  
**Autor**: Antigravity & Zhi  

---

## 1. Visión y Objetivos

Evolucionar `conversor-epub` de un procesador lineal directo a descarga hacia una **Workstation Editorial Integral** para novelas ligeras y manuscritos ePub. La aplicación permitirá:

1. **Flujo de Trabajo por Fases**:
   - Carga del manuscrito (`.docx`, `.md`, `.pdf`).
   - Detección inteligente de capítulos, prólogos, epílogos, notas al pie e ilustraciones.
   - Presentación de un entorno de dos columnas (**Workstation**) donde el usuario puede ajustar metadatos del libro, reordenar/excluir secciones, editar títulos/subtítulos y previsualizar cambios en vivo.
   - Compilación final a un `.epub` estándar y portable utilizando la plantilla canónica `Base3_v1.15.0.epub`.

2. **Integración de Herramientas de ZeeTools**:
   - **Taxonomía Editorial**: Clasificación de contenido en `frontmatter` (preliminares: cubierta, sinopsis, página de título), `bodymatter` (cuerpo: prólogo, capítulos, interludios) y `backmatter` (finales: epílogo, notas, autor, traductor).
   - **Metadatos OPF Estándar**: Soporte para Título, Serie, Volumen, Roles MARC (Autor, Traductor, Ilustrador, Editor), Sinopsis y generación de UUID v7 canónico.
   - **Búsqueda y Reemplazo Regex por Lotes (`search_replace`)**: Modal/herramienta para buscar y reemplazar expresiones regulares sobre todos los capítulos o el capítulo activo, con resaltado y previsualización de coincidencias contextuales.

---

## 2. Arquitectura de Componentes

### 2.1 Modelo de Datos (`lib/motor/secciones.dart`, `lib/motor/metadatos.dart`)

```text
BookMetadata
  ├── title: String
  ├── titleSort: String
  ├── series: String
  ├── volume: String
  ├── author: String
  ├── translator: String
  ├── illustrator: String
  ├── synopsis: String
  ├── bookId: String (UUID v7)
  └── language: String ('es')

SectionKind (Enum)
  ├── Front: cover, synopsis, titlePage, illustrations, notice, epigraph
  ├── Body: prologue, chapter, interlude, part
  └── Back: epilogue, notes, author, translator, colophon

SectionItem
  ├── id: String
  ├── kind: SectionKind
  ├── matter: BookMatter (front | body | back)
  ├── title: String
  ├── subtitle: String
  ├── fileName: String
  ├── inToc: bool
  ├── enabled: bool
  ├── htmlContent: String
  ├── htmlRaw: String
  └── associatedImage: String?
```

### 2.2 Motor de Búsqueda y Reemplazo (`lib/motor/busqueda_reemplazo.dart`)

- Operaciones puras en memoria sobre la lista de `SectionItem`.
- Detección de errores sintácticos en regex (`FormatException`).
- Generación de objetos `MatchItem` con snippets contextuales (prefijo, coincidencia, sufijo, número de línea).
- Métodos:
  - `buscar(pattern, {isRegex, caseSensitive})`
  - `reemplazarUno(match, replacement)`
  - `reemplazarTodo(pattern, replacement, {isRegex, caseSensitive})`

### 2.3 Compilación y Empaquetado (`lib/motor/empaquetado.dart`)

Se adapta la función `empaquetarEpub` para sincronizar los metadatos y la taxonomía con `Base3_v1.15.0.epub`:
1. `content.opf`:
   - Modifica `<dc:title>`, `<dc:creator>`, `<dc:description>` y `<dc:identifier id="BookId">`.
   - Limpia del `manifest` y del `spine` los elementos deshabilitados (`enabled == false`).
   - Inserta los nuevos items generados y asegura el orden de spine correspondiente.
2. `titulo.xhtml`:
   - Inyecta los títulos, volumen y autores/traductores configurados.
3. `resumen.xhtml`:
   - Si la sinopsis está presente, genera los párrafos limpios correspondientes.
4. `cubierta.xhtml`:
   - Si se definió portada, referencia la imagen en `../Images/<archivo_portada>`.
5. `toc.xhtml` y `toc.ncx`:
   - Reconstruye el índice incluyendo únicamente las secciones con `inToc == true`.
6. `notas.xhtml`:
   - Si existen notas al pie extraídas, inyecta los `aside` con enlaces bidireccionales. Si no hay notas y la sección está deshabilitada, se excluye del EPUB.

---

## 3. Diseño de la Interfaz (Workstation UI)

```
+---------------------------------------------------------------------------------------------------------+
| [conversor-epub] Manuscrito: novela.docx (2.4 MB)  |  [Imágenes: /ruta/imgs]  [Regex Buscar/Reemplazar] [Compilar EPUB] |
+--------------------------------------------+------------------------------------------------------------+
| PANEL IZQUIERDO (Navegación & Estructura)  | PANEL DERECHO (Inspector & Visor)                         |
| [ Pestaña: Secciones ] [ Pestaña: Metadatos]|                                                            |
|                                            | Inspector de Sección:                                      |
| PRELIMINARES                               | - Tipo: [Capítulo v]  Archivo: [C01.xhtml]                 |
| [ ] Cubierta [img: cover.jpg]              | - Título: [Capítulo 1]                                     |
| [✓] Sinopsis                               | - Subtítulo: [El inicio de la aventura]                    |
| [✓] Página de Título                       | - [✓] Incluir en TOC  - [✓] Activo en EPUB                 |
|                                            +------------------------------------------------------------+
| CUERPO                                     | Pestañas de Contenido:                                     |
| [✓] Prólogo                                | [ HTML Limpio ]  [ Comparador Diff ]                       |
| [✓] Cap. 01: El inicio                     |                                                            |
| [✓] Cap. 02: La batalla                    | <section id="c01">                                         |
|                                            |   <h1 id="encabezado">Capítulo 1<br/>                      |
| FINALES                                    |     <small class="versalita">El inicio...</small></h1>     |
| [✓] Epílogo                                |   <p>Texto del capítulo con comillas «latinas»...</p>       |
| [✓] Notas al pie (42 notas)                | </section>                                                 |
| [ ] Acerca del Autor                       |                                                            |
|                                            |                                                            |
| [+ Añadir Sección]                         |                                                            |
+--------------------------------------------+------------------------------------------------------------+
```

---

## 4. Estrategia de Pruebas y Validación

1. **Pruebas Unitarias**:
   - `test/secciones_test.dart`: Conversión de `Resultado` a lista de `SectionItem`, reordenamiento y filtrado de exclusiones.
   - `test/busqueda_reemplazo_test.dart`: Búsqueda de texto plano y regex, reemplazo simple y múltiple, respeto de mayúsculas/minúsculas.
   - `test/empaquetado_metadatos_test.dart`: Verificación de que `content.opf`, `titulo.xhtml` y `toc.xhtml` contengan los metadatos inyectados correctamente y sin archivos huérfanos.
2. **Pruebas de Invariantes**:
   - Mantener al 100% las 34 pruebas existentes de comillas (`« »`, `‘ ’`) y extracción de notas.
3. **Verificación Manual en Linux**:
   - Compilación nativa con `flutter run -d linux` y prueba con documentos reales DOCX/MD para verificar interacción de Drag & Drop, edición de metadatos, búsqueda regex y generación de EPUB válido en Sigil/Thorium.
