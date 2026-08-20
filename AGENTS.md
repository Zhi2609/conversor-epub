# AGENTS.md — Especificación Técnica del Proyecto

Este archivo es la fuente de verdad para cualquier agente o desarrollador que trabaje en este
proyecto. Complementa a `Requisitos.md` (especificación funcional) con las decisiones técnicas,
reglas de comportamiento canónico, estilo de código y hoja de ruta resueltas al día de hoy.

---

## 1. Visión

Unificar los scripts legacy (`Old/Conversor.py`, `Old/Migrador.py`, `Old/MigradorMD.py`)
en una **aplicación de escritorio Linux** (PySide6) que automatiza la limpieza tipográfica y
maquetación de manuscritos para ePubs. Un solo motor central con 3 adaptadores de entrada
(DOCX, XHTML de Calibre, Markdown) + interfaz gráfica con visor de diferencias antes/después.

## 2. Stack

- Python 3.10+
- GUI: **PySide6 / PyQt6** (elegido sobre CustomTkinter porque CustomTkinter no renderiza HTML;
  el visor Diff necesita `QTextBrowser` o similar). CustomTkinter queda descartado.
- Dependencia externa: `pandoc` (DOCX → HTML). Verificar presencia con `shutil.which('pandoc')`.
- Distribución: PyInstaller → AppImage (Linux).
- Tests: `pytest` con archivos golden (salida esperada).

## 3. Estado actual (scripts legacy)

| Script | Entrada | Rol |
|---|---|---|
| `Old/Conversor.py` | `.docx` | pandoc → HTML; notas al pie; imágenes `[IMAGEN X]`; separadores `[HR]`; split por `caps.txt` |
| `Old/Migrador.py` | carpeta `.xhtml`/`.html` de Calibre | extrae `<body>`, quita h1 duplicado, limpia basura calibre, template, `caps.txt` |
| `Old/MigradorMD.py` | carpeta `.md` | md → HTML, párrafos auto, imágenes `!\ImageXX\`, template, `{{CONTENIDO}}` |

Los tres comparten ~70% del motor de limpieza (**duplicado y ya divergido**). Al unificar se debe
elegir un comportamiento canónico (ver §5) y verificar con golden tests antes de borrar legacy.

## 4. Arquitectura objetivo

```
app/                     # aplicación (capa GUI, PySide6)
motor/                   # núcleo puro: sin print, sin rutas globales
  __init__.py
  modelo.py              # Chapter(titulo: str, html_cuerpo: str) — pieza central
  limpieza.py            # máquina de estados de comillas + limpieza de basura
  notas.py               # extracción y formateo de notas al pie
  imagenes.py            # imágenes y separadores
  division.py            # auto-splitter: h1/h2/h3 → lista de Chapter
  plantillas.py          # clasificación y manejo de capítulos especiales sin numerar
  procesar.py            # orquestador del pipeline (adaptador → limpieza → notas → imágenes → split)
  adaptadores/
    __init__.py
    docx.py              # pandoc + extracción de notas ANTES del split
    calibre.py           # extraer <body>, quitar <h1> del cuerpo
    markdown.py          # md → HTML, párrafos, imágenes con placeholders \x00IMG_x\x00
  render.py              # inyecta Chapter en template.xhtml → C01.xhtml...
Plantillas/              # plantillas para capítulos especiales (prologo.xhtml, epilogo.xhtml, autor.xhtml)
tests/golden/            # archivos de entrada + salida esperada
CLI (motor-cli.py)       # entry point de consola para tests y uso sin GUI
```

Reglas de arquitectura:

- **D6: El pipeline es**: adaptador → extracción de notas → limpieza →
  procesado de imágenes/separadores → split → render. Las notas se extraen
  **antes** de la limpieza (que borra los `id=` de las anclas de pandoc) y
  antes de dividir capítulos.
- Todos los modos convergen a `list[Chapter]`. Numeración `C01.xhtml`, `C02.xhtml`...
  (soporte `start_num` heredado de MigradorMD).
- El núcleo es puro: funciones sin `print`, sin rutas hardcodeadas (parámetros), sin efectos
  de sistema. La GUI y el CLI solo orquestan y muestran.

## 5. Comportamiento canónico (CRÍTICO — no cambiar sin validación)

### 5.1 Máquina de estados de comillas (D1, D2)

- Normalización previa: `“ ” « » ″` → `"`; `‘ ’ ′` → `'`.
- **D1: TODOS los niveles de comillas dobles se escriben `«` (apertura) / `»` (cierre)**.
  El contador de niveles se mantiene SOLO para emparejar y para el cortafuegos.
  El ejemplo canónico:
  `"""AHHH!!!!"""` → `«««AHHH!!!!»»»`.
  (Descartado: `‘’` y `‹›` para nivel >1 — `‹›` venía de Migrador, se descarta.)
- **D2: Las comillas simples explícitas `'` → `‘ ’`**, independientes del contador de niveles.
  Ejemplo: `un 'niño'` → `un ‘niño’`.
- Cortafuegos: `\n`, `</p>`, `<br>`, `</div>`, `</section>`, `</blockquote>`, `<hr>` resetean
  el nivel a 0 (evita efecto cascada por errores del manuscrito).
- Cierre automático: al final del párrafo, las comillas abiertas sin cerrar se cierran en
  orden inverso.
- Apertura/cierre por contexto (`_es_apertura`): mirar carácter anterior/siguiente saltando
  comillas consecutivas. Caracteres anteriores que abren: espacio, `\n\t`, `(—-[{¿¡>` **y los
  dos puntos `:`/`;`** (corrige un agujero heredado: `dijo: "hola"` abría como cierre).
- Alinear: las comillas siempre FUERA de `<b>`/`<i>` (`«<i>x</i>»`, nunca `<i>«x»</i>`).

### 5.2 Ambigüedad irresoluble (D5)

El carácter `"` está sobrecargado (diálogo, grito, título) y `'` también (cita, énfasis).
El motor **NO debe adivinar por heurísticas** si un `«…»` interior es título o cita anidada.
La red de seguridad es el **visor Diff de la UI**: el autor ve el resultado y corrige en el
manuscrito o en la tabla. Prohibido añadir heurísticas tipo "título si termina en `de + Nombre`".

### 5.3 Títulos de capítulos (D4)

- `caps.txt` queda **eliminado** del flujo. Los títulos viven como `list[str]` en la app.
- Auto-splitter detecta `<h1>/<h2>/<h3>` y precarga la tabla de títulos.
- El usuario edita textos y puede añadir/eliminar filas (quitar falsos positivos).
- **Validación estricta de conteo**: filas ≠ capítulos detectados → error visible
  (`Títulos: 4/5 — falta 1`) y botón "Generar Archivos" deshabilitado.
- Importación opcional de `caps.txt` (via `cargar_titulos`) SOLO como prefill, sin autoridad.

### 5.4 Limpieza de basura (unificado)

- `<strong>` → `<b>`, `<em>` → `<i>`.
- Restaurar HTML escapado: `&lt;p&gt;` → `<p>`; etiquetas no reconocidas escapan a `「」`.
- Eliminar: `<span>` con class/style/id, `class=`, `id=`, `style=`, `dir="ltr"`, `lang="es"`.
  **Excepción**: `class="mistico"` del `<blockquote>` se conserva (viene del propio adaptador MD).
  **Excepción**: `id="rfNN"` se conserva (anclas generadas por el motor de notas, §5.5).
- Eliminar etiquetas vacías `<b></b>`, `<i></i>`; unificar `</i><i>` → nada; `<div></div>` vacíos.
- Unión de los dos conjuntos de regex legacy (Word y Calibre); el resultado debe ser
  superconjunto de ambos.

### 5.5 Notas al pie

- Extracción de `<section id="footnotes">` (pandoc), quitar anclas de retorno `↩︎`,
  limpiar basura.
- Formato nota: `<div class="nota"><p id="nt01"><a href="C01.xhtml#rf01"><sup>❮01❯</sup> …</a></p></div>`
- **Notas con imagen**: el div se envuelve con `<hr class="sigil_split_marker" />` (uno
  encima y otro debajo) y las imágenes se reescriben a `../Images/nota-XX.jpg`
  (namespace propio, independiente de la numeración `NN.jpg` de los capítulos;
  segunda imagen de una nota → `nota-XX-2.jpg`). La etiqueta se normaliza a
  `<img src="…" alt=""/>` (sin width/height) y el texto se separa de la imagen
  con `<br/><br/>`. Sin imagen → formato simple, sin markers.
- **El backlink `C0N.xhtml` apunta al capítulo que contiene la llamada** (`id="rfNN"`),
  detectado tras el split; por defecto `C01.xhtml` si la nota no está referenciada.
- Formato llamada inline: `<a href="notas_Finales.xhtml#nt01" id="rf01"><sup>❮01❯</sup></a>`
- Nombres canónicos: archivo único `notas_Finales.xhtml`.
- **BUG legacy conocido**: en `Conversor.py:246,286` los href apuntan a `notas.xhtml`
  pero el archivo se escribe como `notas_Finales.xhtml` (`:370`). Al unificar se usa
  `notas_Finales.xhtml` en ambos lados.
- Soporte legacy `(NT##)`.

### 5.6 Imágenes y separadores

- Detectadas: pandoc nativo `<img…image0N…>`, `[IMAGEN N]`, `!\ImageN\` (md).
- Reemplazo: `<hr class="sigil_split_marker" />` + `<figure class="dimg"><img src="../Images/NN.jpg" alt=""/></figure>` + `<hr class="sigil_split_marker" />`
- En MD se procesan con placeholders `\x00IMG_x\x00` para que la limpieza no los toque
  (heredado de MigradorMD).
- Separadores `[HR]` / `[SEPARADOR]` →
  `<p class="hr centrado grande"><b>※ ・ ※ ・ ※</b></p>`

### 5.7 Markdown → HTML

- Limpiar invisibles `\u200B-\u200D\uFEFF`.
- `***x***` → `<b><i>`, `**x**` → `<b>`, `_x_` → `<i>`, `\x` → `x`, `# x` (línea) → `<h1>`.
- `[blockquote]` → `<blockquote class="mistico">`.
- Párrafos: split por `\n{2,}`, envolver en `<p>` salvo bloques que ya empiezan por
  `<h1`, `<hr`, `<figure` o placeholder de imagen; unir líneas internas con espacio.
- **Un primer `<h1>` al inicio del archivo es el título del capítulo**: se extrae, se elimina
  del cuerpo (evita duplicar el título con el header del template) y alimenta la tabla
  de títulos. Los `#` intermedios se conservan en el cuerpo.

### 5.8 Capítulos especiales sin numeración (D8)

Solo existen 3 archivos sin numeración, clasificados por el título (minúsculas,
sin tildes, prefijo):
`prólogo`, `epílogo`, `palabras del autor` → `prologo.xhtml`, `epilogo.xhtml`,
`autor.xhtml`. El resto (incluidos los capítulos especiales/extras como
"Secreto Oculto 1") usan numeración normal `C{NN:02d}.xhtml`.
**Los especiales NO consumen número**: el primer capítulo normal tras el
prólogo es `C01.xhtml` (renumeración sobre los capítulos con numeración;
`Chapter.archivo` se asigna a todos y `numero_de_archivo` extrae el número
del placeholder `Capítulo X`).

- Las plantillas viven en `Plantillas/` (se empaquetan con `--add-data` y se
  resuelven con `ruta_plantillas_empaquetado`).
- **El contenido se inyecta debajo del marcador `<!-- Aquí va el contenido -->`**:
  el marcador se conserva como separador visible entre el encabezado y el
  contenido, y todo lo que haya entre él y el `</section>` de la plantilla se
  sustituye (borra relleno de ejemplo). Sin marcador → error visible.
- `Capítulo X` / `Título del capítulo` se sustituyen globalmente como en el
  template normal (p.ej. `Prólogo: Título del capítulo` → `Prólogo: ¿Sueño o Realidad?`).
- La clasificación se hace al cargar el manuscrito (tabla de títulos); si la
  usuaria edita un título en la GUI, hay que recargar para re-clasificar.
- Los backlinks de notas apuntan al **archivo real** (`prologo.xhtml#rfXX`),
  no a C0X (§5.5).

## 6. Formato de salida

- `C01.xhtml`…`C{NN:02d}.xhtml` por capítulo; `notas_Finales.xhtml`; carpeta `Capitulos/`.
  Los 3 capítulos especiales se escriben como `prologo.xhtml`, `epilogo.xhtml` y
  `autor.xhtml` (§5.8).
- Template `template.xhtml` con placeholders: `Capítulo X`, `Título del capítulo`,
  `{{CONTENIDO}}` (heredado; MigradorMD usa los tres, Conversor solo los dos primeros).
- Carpeta de salida se limpia antes de escribir (heredado de `preparar_entorno`).

## 7. Estilo de código

- Python 3.10+, type hints obligatorios en firmas.
- Nombres en español (convención del proyecto: `ruta_template`, `contenido_limpio`).
- `re.compile` a nivel de módulo con constantes `RE_*`; `Path` de pathlib; UTF-8 siempre.
- Docstrings en español; sin comentarios salvo que aporten (no repetir el código).
- Núcleo: funciones puras, sin prints ni rutas globales (esto es un cambio deliberado
  respecto a los scripts legacy, que usan constantes de ruta globales).
- Funciones internas con `_` prefijo (`_es_apertura`). Mantener los nombres existentes
  donde sea posible para facilitar la comparación con legacy.
- No añadir dependencias sin justificarlo en AGENTS.md.

## 8. Comandos

```bash
# Legacy (solo para regresión y extraer lógica)
python3 Old/Conversor.py --solo-convertir        # DOCX → Resultado_Completo.xhtml
python3 Old/Conversor.py --solo-capitulos        # caps.txt + template → Capitulos/
python3 Old/Migrador.py <carpeta> -o <salida> -t <template> -c <caps.txt>
python3 Old/MigradorMD.py <carpeta> -o <salida> -t <template> -c <caps.txt> -n 1

# Conversión pandoc (DOCX)
pandoc novela.docx -o temp_raw.html -t html5 --wrap=none

# Proyecto unificado (cuando exista)
python3 -m pytest tests/                     # golden tests
python3 -m unittest discover tests           # alternativa sin pytest (mismo suite)
python3 motor-cli.py <entrada> -o <salida>   # núcleo sin GUI
python3 app/app.py                           # GUI
```

## 9. Tests golden (obligatorios en Fase 1)

- **D7**: antes de refactorizar el núcleo, capturar la salida actual de los 3 modos con 2-3
  manuscritos de prueba y congelarla como golden (especifica la regresión de salida).
  Cumplido en Fase 1: salidas verificadas byte a byte contra `Conversor._convertir_comillas`
  y congeladas en `tests/golden/salida_{md,calibre}/`.
- Casos fijos de comillas (criticos):
  1. `"""AHHH!!!!"""` → `«««AHHH!!!!»»»`
  2. `se llama "Indigno de ser Humano" de Dazai` → nivel 1 `«…»`
  3. `hablo con... un 'niño'` → `hablo con... un ‘niño’`
- Incluir: comillas sin cerrar al final de párrafo, dobles talks adyacentes
  (`«hola», «adiós»`), cortafuegos por `</p>`, basura de Word y de Calibre,
  notas al pie pandoc + legacy `(NT01)`, imágenes (3 sintaxis), separadores, `{{CONTENIDO}}`.

## 10. Hoja de ruta

1. **Fase 1 — Núcleo unificado**: `motor/` con modelo, limpieza canónica (§5), adaptadores,
   split, notas, imágenes; `motor-cli.py`; golden tests. Los 3 scripts legacy quedan intactos
   hasta pasar los tests.
2. **Fase 2 — GUI (PySide6)**: selector Drag&Drop universal + indicador de modo (Word/Calibre/
   Markdown), dashboard (capítulos, notas, imágenes, separadores), tabla editable de títulos
   con validación de conteo (§5.3), visor Diff con QTextBrowser. **Completada.**
3. **Fase 3 — Generación**: limpieza de salida, render de template, `notas_Finales.xhtml`,
   validaciones y mensajes de error visibles en la UI (pandoc ausente, carpeta sin `<body>`,
   archivo sin títulos). **Completada** (avisos por archivo omitido en CLI y GUI).
4. **Fase 4 — Distribución**: PyInstaller → AppImage; `requirements.txt`; despedida de
   los scripts legacy una vez validados los tests. **Completada**: `empaquetar.sh`
   (build PyInstaller + AppImage con linuxdeploy), plantilla empaquetada vía
   `ruta_template_empaquetado`, legacy movido a `Old/`. Nota: PyInstaller requiere
   `binutils` (objdump) en el sistema.
5. **Fase 5 — Mejora visual de la GUI**: tema oscuro Catppuccin-inspired (Fusion + QPalette +
   QSS global ~180 líneas), campo de template eliminado (auto-detectado), dashboard con
   badges de color individuales, drop zone con borde discontinuo, jerarquía de botones
   (primario verde / secundario gris), labels con object names para QSS, tabla con filas
   alternadas, diff viewer monoespaciado. **Completada.**

## 11. Cambios y registro

- `Requisitos.md`: especificación funcional (referencia, no editar sin avisar).
- CHANGELOG: se redactará un archivo de cambios (`CHANGELOG.md`) documentando cada cambio
  hecho al sistema a partir de esta especificación. Actualizarlo en cada fase.
- Cualquier decisión nueva que afecte al comportamiento canónico debe registrarse aquí
  (§5) ANTES de implementarse.