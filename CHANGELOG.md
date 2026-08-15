# CHANGELOG

Registro de todo cambio hecho al sistema, agrupado por día y por hora exacta.
Las nuevas entradas se añaden al final de cada sesión de trabajo.

---
## 15 de Agosto de 2026

      01:50 — 1 cambio hecho
- Creado `AGENTS.md`: especificación técnica del proyecto (arquitectura,
  comportamiento canónico de comillas D1/D2, títulos D4, ambigüedad D5,
  golden tests D7, estilo de código, hoja de ruta).

      01:55 — 9 cambios hechos
- Creado `motor/__init__.py`: exporta el motor unificado.
- Creado `motor/modelo.py`: `Chapter`, `Nota`, `Contadores`, `Resultado`.
- Creado `motor/imagenes.py`: imágenes pandoc/`[IMAGEN N]` y separadores.
- Creado `motor/division.py`: auto-splitter por `<h1>/<h2>/<h3>`.
- Creado `motor/adaptadores/__init__.py`: `detectar_modo`.
- Creado `motor/adaptadores/docx.py`: DOCX → HTML con pandoc (sin archivos temporales).
- Creado `motor/adaptadores/markdown.py`: MD → HTML con placeholders `\x00IMG_x\x00`.
- Creado `motor/render.py`: inyección en template y limpieza de carpeta de salida.
- Creado `motor/procesar.py`: pipeline completo (D6: limpieza → notas → imágenes → split).

      01:56 — 1 cambio hecho
- Creado `motor-cli.py`: entry point de consola con detección automática de modo.

      01:57 — 4 cambios hechos
- Creado `tests/golden/entrada_md/C02.md`: fixture con caso de dos puntos.
- Creados `tests/golden/entrada_calibre/01.xhtml` y `02.xhtml`: fixtures con basura de Calibre.
- Creado `motor/adaptadores/calibre.py`: extracción de `<body>` y quita de h1.
- Corregido error en `extraer_cuerpo` (grupo de regex equivocado).

      01:58 — 6 cambios hechos
- Creado `motor/limpieza.py`: máquina de comillas canónica (D1: todos los niveles
  `«`/`»`; D2: `'` → `‘ ’` independiente; cortafuegos; apertura tras `:`/`;`)
  y limpieza de basura unificada Word + Calibre (conserva `class="mistico"`).
- Corregido `tests/golden/entrada_md/C01.md`: diálogo con comillas correctas.
- Generadas las salidas golden `tests/golden/salida_md/` y `salida_calibre/`.

      01:59 — 6 cambios hechos
- Creado `tests/__init__.py`.
- Creado `tests/test_limpieza.py`: basura Word/Calibre, HTML escapado, alineación.
- Creado `tests/test_imagenes.py`: 3 sintaxis de imagen y separadores.
- Creado `tests/test_division.py`: split h1/h2/h3, contenido previo, `start_num`.
- Creado `tests/test_adaptadores.py`: `detectar_modo`, calibre y markdown.
- Creado `tests/test_procesar.py`: tests E2E contra golden (D7).

      02:00 — 3 cambios hechos
- Creado `motor/notas.py`: extracción de notas pandoc + legacy `(NT##)`, con el
  bug legacy `notas.xhtml` → `notas_Finales.xhtml` corregido y backlink por capítulo.
- Creado `tests/test_comillas.py`: los 3 casos canónicos de comillas (D1/D2).
- Creado `tests/test_notas.py`: extracción, formato ePub y asignación de capítulo.

      02:01 — 1 cambio hecho
- Actualizado `AGENTS.md`: apertura tras `:`/`;`, excepción `class="mistico"`,
  backlink de notas por capítulo, `<h1>` inicial de MD como título, ejemplo
  `"""AHHH!!!!"""` corregido a 4 exclamaciones, comando alternativo `unittest`.

      02:04 — 1 cambio hecho
- Creado `CHANGELOG.md`: este registro de cambios por día y hora exacta.

      02:08 — 2 cambios hechos
- Creado `app/app.py`: GUI PySide6 completa (Fase 2) — zona Drag&Drop universal
  con indicador de modo, dashboard de contadores, tabla editable de títulos
  con validación de conteo (§5.3), visor Diff con QTextBrowser y botón
  "Generar Archivos" que limpia y escribe los capítulos.
- Creado `tests/test_app.py`: tests de humo de la GUI en modo offscreen
  (creación, carga de carpeta, validación de conteo y relleno del Diff).

      02:09 — 1 cambio hecho
- Actualizado `AGENTS.md`: Fase 2 completada en la hoja de ruta.

      02:13 — 4 cambios hechos
- Actualizado `motor/modelo.py`: `Resultado` gana la lista `avisos`.
- Actualizado `motor/adaptadores/calibre.py`: archivos sin `<body>` se omiten
  con aviso (antes abortaba todo el lote).
- Actualizado `motor/adaptadores/markdown.py`: archivo sin título detectado
  genera aviso.
- Actualizado `motor/procesar.py`: propaga los avisos de los adaptadores.

      02:14 — 2 cambios hechos
- Actualizado `app/app.py` (Fase 3): QMessageBox de error visible, etiqueta
  de avisos ⚠️ bajo el dashboard, botón "Generar Archivos" deshabilitado sin
  carga y validación de `{{CONTENIDO}}` en el template antes de generar.
- Actualizado `motor-cli.py`: imprime los avisos ⚠️ en consola.

      02:15 — 2 cambios hechos
- Actualizado `tests/test_procesar.py`: tests de avisos (calibre sin `<body>`,
  markdown sin título).
- Actualizado `tests/test_adaptadores.py`: firma nueva de `documentos_markdown`
  y aviso de título ausente.
  Total suite: 68 passed, 2 skipped (pandoc ausente en este equipo).

      11:24 — 3 cambios hechos
- Creado `requirements.txt`: PySide6>=6.5 y pytest>=7.
- Creado `empaquetar.sh`: build PyInstaller onefile + AppImage con linuxdeploy
  (la plantilla se empaqueta con `--add-data`).
- Actualizados `motor/__init__.py`, `motor-cli.py` y `app/app.py`: la ruta de la
  plantilla usa `ruta_template_empaquetado()` (soporta PyInstaller).

      11:25 — 3 cambios hechos
- Movido `Conversor.py`, `Migrador.py` y `MigradorMD.py` a `Old/` (despedida
  legacy; el root tenía copia idéntica de `Old/Conversor.py`). La carpeta
  `Conv_Xhtml/` conserva `template.xhtml`, `caps.txt` y `NovelaMD/`.
- Actualizado `AGENTS.md`: rutas de los comandos legacy y Fase 4 completada.
- Nota: PyInstaller no pudo ejecutarse en este equipo (falta `binutils`/objdump);
  `empaquetar.sh` está listo para ejecutarse en la máquina del usuario.

      11:26 — 1 cambio hecho
- Limpieza del árbol: eliminados `Capitulos/`, `Conv_Xhtml/Capitulos/`, `caps.txt`
  (raíz y `Conv_Xhtml/`), `Instrucciones.md`, `Old/Conversor_v12..v19.py`,
  `Old/Old.7z` y todos los `__pycache__`/`.pytest_cache`. Se conservan los 3
  scripts de regresión (`Old/Conversor.py`, `Migrador.py`, `MigradorMD.py`),
  `Old/template.xhtml`, `Conv_Xhtml/template.xhtml` y `NovelaMD/`. Suite intacta:
  68 passed, 2 skipped.

      11:35 — 5 cambios hechos
- Corregido bug real de usuaria (1.er fallo reportado tras empaquetar): el
  DOCX con notas al pie daba 0 notas. Causa: la limpieza (§5.4) borraba los
  `id=` de pandoc (`<section id="footnotes">`, `<li id="fn1">`) ANTES de la
  extracción. Arreglado en `motor/procesar.py`: las notas se extraen antes de
  la limpieza (nuevo orden D6, §4) y `RE_ATRIBUTOS_BASURA` excluye `id="rfNN"`
  (anclas generadas por el motor). Reproducido con pandoc 3.10.2 real y con un
  .docx mínimo de notas al pie + nota final. Nuevos tests de regresión en
  `tests/test_notas.py` (pipeline calibre con sección de notas pandoc).
- Pulido `app/app.py`: los diálogos de explorar/generar usan
  `DontUseNativeDialog` (el segundo fallo reportado: el diálogo nativo de KDE/
  Dolphin vía portal se abría vacío en el AppImage).
- Prueba de campo con pandoc 3.10.2 (descargado a /tmp/opencode/pandoc, sin
  sudo) validando el flujo DOCX completo → 3 notas detectadas con sus backlinks.
- Actualizado `AGENTS.md` (orden D6 en §4 + excepción `id="rfNN"` en §5.4).
- Suite: 70 passed, 2 skipped.

      11:45 — 8 cambios hechos
- Nuevo §5.8 en AGENTS.md: capítulos especiales sin numeración (D8)
  — prólogo/epílogo/palabras del autor → `prologo.xhtml`/`epilogo.xhtml`/`auto.xhtml`
  con plantillas en `Plantillas/` clasificadas por prefijo del título (sin
  tildes). El resto (incluidos los especiales numerados tipo "Secreto Oculto 1")
  sigue con `C{NN:02d}.xhtml`.
- Nuevo `motor/plantillas.py`: `TABLA_ESPECIALES`, `clasificar_especial`
  (normalización NFD sin tildes) y `RE_MARCADOR_CONTENIDO`.
- `motor/modelo.py`: `Chapter.archivo` y `Chapter.plantilla_ruta`; `Nota.cap_archivo`.
- `motor/render.py`: `render_capitulo_especial` — el contenido se inyecta debajo
  del marcador `<!-- Aquí va el contenido -->` (se conserva como separador) y
  todo lo que había hasta `</section>` se sustituye; sin marcador → error.
- `motor/notas.py`: los backlinks usan el archivo real (`prologo.xhtml#rfXX`).
- `motor/procesar.py`: parámetro `ruta_plantillas` (opt-in, sin efectos si no
  se pasa); CLI `-p/--plantillas` y GUI detectan `Plantillas/` automáticamente
  (empaquetada vía `ruta_plantillas_empaquetado` y `--add-data` en empaquetar.sh).
- Al imprimir nombres se usa `capitulo.archivo or C{NN:02d}.xhtml`.
- Tests: `tests/test_plantillas.py` (clasificación, render con marcador + título
  dinámico, backlink a prólogo). Suite: 76 passed, 2 skipped. Commit `cd0d716`.

      11:49 — 3 cambios hechos
- Notas con imagen (§5.5): `motor/notas.py` gana `RE_IMG` y `_texto_con_imagenes`
  — las imágenes de una nota se reescriben a `../Images/nota-XX.jpg` (namespace
  propio; segunda imagen `nota-XX-2.jpg`), se normaliza `<img src alt=""/>`
  (sin width/height) y se separan de la nota con `<br/><br/>`. Estas notas se
  envuelven con `<hr class="sigil_split_marker" />` por ambos lados, tal como
  la plantilla canónica de la usuaria. Notas sin imagen: formato intacto.
- Tests: `TestFormatoConImagenes` en `tests/test_notas.py` (marcadores, renombrado,
  imágenes múltiples, formato simple intacto). Suite: 79 passed, 2 skipped.

      12:12 — 4 cambios hechos
- Bug reportado en AppImage: la plantilla de Palabras del autor estaba como
  `autor.xhtml` pero el mapeo canónico (§5.8) espera `auto.xhtml` → ENOENT en
  `/tmp/_MEIPASS/Plantillas/auto.xhtml` al generar. Renombrado a `auto.xhtml`.
- `motor/procesar.py`: si la plantilla especial no existe, el capítulo vuelve a
  la numeración normal y se añade un aviso (nunca más un crash) en vez de petar.
- Docstrings de `procesar` y help del CLI corregidos (autor.xhtml → auto.xhtml).
- Test `test_plantilla_especial_faltante_usa_numero_normal`. Suite: 80 passed,
  2 skipped.

---
