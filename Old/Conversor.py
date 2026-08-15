import argparse
import re
import subprocess
import sys
from pathlib import Path
from shutil import which

# ============================================================
#  CONFIGURACIÓN
# ============================================================

RUTA_DOCX = Path('novela.docx')
RUTA_CAPS_TXT = Path('caps.txt')
RUTA_TEMPLATE = Path('./Old/template.xhtml')
RUTA_SALIDA = Path('./Capitulos')
RUTA_COMPLETO = Path('Resultado_Completo.xhtml')
RUTA_TEMP_RAW = Path('temp_raw.html')

SEPARADOR_XHTML = '<p class="hr centrado grande"><b>※ ・ ※ ・ ※</b></p>'
TAGS_HTML_PERMITIDOS = frozenset({'p', 'b', 'i', 'hr', 'br', 'div', 'span'})

# --- Patrones de notas al pie ---
RE_SECCION_NOTAS = re.compile(
    r'<(section|div)\b[^>]*(?:id|class)="footnotes?"[^>]*>(.*?)</\1>',
    re.DOTALL | re.IGNORECASE
)
RE_ITEM_NOTA = re.compile(
    r'<li\b[^>]*id="fn(\d+)"[^>]*>(.*?)</li>',
    re.DOTALL | re.IGNORECASE
)
RE_VINCULO_NOTA_PANDOC = re.compile(
    r'<a\b[^>]*href="#fn(\d+)"[^>]*>.*?</a>',
    re.DOTALL
)
RE_VINCULO_REGRESO = re.compile(
    r'<a\b[^>]*href="#fnref[^>]*>.*?</a>',
    re.DOTALL
)
RE_NOTA_LEGACY = re.compile(r'\(NT(\d+)\)')

# --- Patrones de imágenes ---
RE_IMG_PANDOC_P = re.compile(
    r'<p[^>]*>\s*<img\b[^>]*src="[^"]*?image0*(\d+)\.[a-zA-Z]+"[^>]*>\s*</p>',
    re.IGNORECASE
)
RE_IMG_PANDOC = re.compile(
    r'<img\b[^>]*src="[^"]*?image0*(\d+)\.[a-zA-Z]+"[^>]*>',
    re.IGNORECASE
)
RE_IMAGEN_TAG_P = re.compile(
    r'<p[^>]*>\s*\[IMAGEN\s*0*(\d+)\]\s*</p>',
    re.IGNORECASE
)
RE_IMAGEN_TAG = re.compile(r'\[IMAGEN\s*0*(\d+)\]', re.IGNORECASE)

# --- Patrones de separadores ---
RE_SEPARADOR_P = re.compile(
    r'<p[^>]*>\s*\[(?:HR|SEPARADOR)\]\s*</p>',
    re.IGNORECASE
)
RE_SEPARADOR = re.compile(r'\[(?:HR|SEPARADOR)\]', re.IGNORECASE)

# --- Patrones de limpieza HTML ---
RE_RESTAURAR_HTML = re.compile(
    r'&lt;(/?)({})([^&]*)&gt;'.format('|'.join(TAGS_HTML_PERMITIDOS))
)
RE_SPAN_BASURA = re.compile(
    r'<span\b[^>]*(?:class|style|id)="[^"]*"[^>]*>'
)
RE_DIR_LTR = re.compile(r'\sdir="ltr"')
RE_CLASS = re.compile(r'\sclass="[^"]*"')
RE_VACIO_B_I = re.compile(r'<(b|i)></\1>')
RE_COMILLA_APERTURA = re.compile(r'(^|\s|\()"')
RE_COMILLA_CIERRE = re.compile(r'"($|\s|[.,;:!?])')
RE_UNIFICAR_I = re.compile(r'</i>(\s*)<i>')
RE_UNIFICAR_B = re.compile(r'</b>(\s*)<b>')
RE_ALINEAR_APERTURA = re.compile(r'(<(?:i|b)>)([«‘])')
RE_ALINEAR_CIERRE = re.compile(r'([»’])(</(?:i|b)>)')


# ============================================================
#  HELPERS DE LIMPIEZA HTML
# ============================================================

def _normalizar_etiquetas(html: str) -> str:
    """Convierte <strong> → <b> y <em> → <i>."""
    html = html.replace('<strong>', '<b>').replace('</strong>', '</b>')
    html = html.replace('<em>', '<i>').replace('</em>', '</i>')
    return html


def _restaurar_html_escapado(html: str) -> str:
    """Restaura etiquetas conocidas que pandoc escapó (&lt;p&gt; → <p>).
    Las etiquetas no reconocidas se convierten en adornos (「」)."""
    html = RE_RESTAURAR_HTML.sub(r'<\1\2\3>', html)
    html = html.replace('&lt;', '「').replace('&gt;', '」')
    return html


def _unificar_etiquetas_partidas(html: str) -> str:
    """Fusiona etiquetas contiguas del mismo tipo: </i><i> → (nada)."""
    html = RE_UNIFICAR_I.sub(r'\1', html)
    html = RE_UNIFICAR_B.sub(r'\1', html)
    return html


def _es_apertura(texto: str, idx: int) -> bool:
    """Determina si una comilla abre o cierra mirando caracteres
    anterior y siguiente, saltando bloques de comillas consecutivas."""
    j = idx - 1
    while j >= 0 and texto[j] in ('"', "'"):
        j -= 1
    prev = texto[j] if j >= 0 else ''
    next_ = texto[idx + 1] if idx < len(texto) - 1 else ''

    es_apertura_prev = (prev == '' or prev in ' \n\t(—-[{¿¡>')
    es_cierre_next = (next_ == '' or next_ in ' \n\t.,;:!?)]}<')

    if es_apertura_prev and not es_cierre_next:
        return True
    if not es_apertura_prev and es_cierre_next:
        return False

    if prev == '>':
        tag_start = texto.rfind('<', 0, j)
        if tag_start != -1 and tag_start + 1 < j and texto[tag_start + 1] == '/':
            return False

    return es_apertura_prev


def _convertir_comillas(html: str) -> str:
    """Reemplaza comillas rectas por latinas (« ») y simples (‘ ’) para anidación,
    respetando etiquetas HTML e incluye cortafuegos de párrafo.
    Las comillas dobles usan el sistema de niveles (anidación), las simples
    se convierten independientemente sin alterar el nivel."""
    html = re.sub(r'[“”«»\u2033]', '"', html)
    html = re.sub(r'[‘’\'\u2032]', "'", html)

    resultado: list[str] = []
    nivel = 0
    dentro_de_tag = False
    tag_buffer: list[str] = []

    for i, char in enumerate(html):
        if char == '<':
            dentro_de_tag = True
            tag_buffer = ['<']
            resultado.append(char)
            continue

        if dentro_de_tag:
            tag_buffer.append(char)
            resultado.append(char)
            if char == '>':
                dentro_de_tag = False
                tag_str = "".join(tag_buffer).lower()
                if tag_str in ('</p>', '<br>', '<br/>', '</div>', '</section>', '</blockquote>', '<hr>'):
                    nivel = 0
            continue

        if char == '\n':
            nivel = 0
            resultado.append(char)
            continue

        if char == '"':
            if _es_apertura(html, i):
                nivel += 1
                resultado.append('«' if nivel == 1 else '‘')
            else:
                if nivel == 0:
                    resultado.append('»')
                elif nivel == 1:
                    resultado.append('»')
                    nivel -= 1
                else:
                    resultado.append('’')
                    nivel -= 1

        elif char == "'":
            resultado.append('\x01' if _es_apertura(html, i) else '\x02')

        else:
            resultado.append(char)

    if nivel > 0:
        for j in range(len(resultado) - 1, -1, -1):
            if resultado[j] == '«':
                resultado[j] = '»'
                nivel -= 1
                if nivel == 0:
                    break
            elif resultado[j] == '‘':
                resultado[j] = '’'
                nivel -= 1
                if nivel == 0:
                    break

    return ''.join(resultado).replace('\x01', '‘').replace('\x02', '’')


def _eliminar_basura_word(html: str) -> str:
    """Elimina spans, clases, direcciones y etiquetas vacías que deja Word."""
    html = RE_SPAN_BASURA.sub('', html)
    html = html.replace('</span>', '')
    html = RE_DIR_LTR.sub('', html)
    html = RE_CLASS.sub('', html)
    html = RE_VACIO_B_I.sub('', html)
    return html


def _alinear_comillas_y_etiquetas(html: str) -> str:
    """Mueve comillas latinas («»‘’) al exterior de <i>/<b> para evitar
    asimetrías como «<i>texto»</i> o <i>«texto</i>»."""
    while True:
        antes = html
        html = RE_ALINEAR_APERTURA.sub(r'\2\1', html)
        html = RE_ALINEAR_CIERRE.sub(r'\2\1', html)
        if html == antes:
            break
    return html


# ============================================================
#  PROCESADORES DE CONTENIDO
# ============================================================

def limpiar_texto_html(html_content: str) -> str:
    """Limpia el HTML de Pandoc: normaliza etiquetas, restaura HTML escapado,
    unifica partidas, convierte comillas a latinas y elimina basura de Word."""
    html_content = _normalizar_etiquetas(html_content)
    html_content = _restaurar_html_escapado(html_content)
    html_content = _unificar_etiquetas_partidas(html_content)
    html_content = _convertir_comillas(html_content)
    html_content = _alinear_comillas_y_etiquetas(html_content)
    html_content = _eliminar_basura_word(html_content)
    return html_content


def _reemplazar_notas_legacy(html: str) -> str:
    """Reemplaza referencias legacy (NT##) por el formato ePub."""
    def reemplazar(match: re.Match) -> str:
        num = int(match.group(1))
        num_fmt = f"{num:02d}"
        return f'<a href="notas.xhtml#nt{num_fmt}" id="rf{num_fmt}"><sup>❮{num_fmt}❯</sup></a>'
    return RE_NOTA_LEGACY.sub(reemplazar, html)


def procesar_notas(html_content: str) -> tuple[str, str]:
    """Extrae las notas al pie del HTML de Pandoc, las limpia y formatea."""
    notas_html = ""
    match = RE_SECCION_NOTAS.search(html_content)

    if match:
        contenido_raw = match.group(2)
        html_content = html_content[:match.start()] + html_content[match.end():]

        items = RE_ITEM_NOTA.findall(contenido_raw)
        divs: list[str] = []

        for num_str, html_nota in items:
            num = int(num_str)
            num_fmt = f"{num:02d}"

            html_nota = RE_VINCULO_REGRESO.sub('', html_nota)
            html_nota = re.sub(r'↩︎?', '', html_nota)
            html_nota = re.sub(r'^<p>', '', html_nota.strip())
            html_nota = re.sub(r'</p>$', '', html_nota.strip())
            html_nota = limpiar_texto_html(html_nota)

            div = (
                f'<div class="nota">\n'
                f' <p id="nt{num_fmt}">\n'
                f'   <a href="C01.xhtml#rf{num_fmt}"><sup>❮{num_fmt}❯</sup> {html_nota.strip()}</a>\n'
                f' </p>\n'
                f'</div>'
            )
            divs.append(div)

        notas_html = "\n".join(divs)

        def reemplazar_llamada(match: re.Match) -> str:
            num = int(match.group(1))
            num_fmt = f"{num:02d}"
            return f'<a href="notas.xhtml#nt{num_fmt}" id="rf{num_fmt}"><sup>❮{num_fmt}❯</sup></a>'

        html_content = RE_VINCULO_NOTA_PANDOC.sub(reemplazar_llamada, html_content)

    html_content = _reemplazar_notas_legacy(html_content)
    return html_content, notas_html


def procesar_imagenes(html_content: str) -> str:
    """Detecta imágenes nativas de Pandoc y marcas [IMAGEN X],
    las reemplaza por el formato ePub de Sigil."""
    def reemplazo(match: re.Match) -> str:
        num = int(match.group(1))
        num_fmt = f"{num:02d}"
        return (
            f'<hr class="sigil_split_marker" />\n'
            f'<figure class="dimg"><img src="../Images/{num_fmt}.jpg" alt=""/></figure>\n'
            f'<hr class="sigil_split_marker" />'
        )

    html_content = RE_IMG_PANDOC_P.sub(reemplazo, html_content)
    html_content = RE_IMG_PANDOC.sub(reemplazo, html_content)
    html_content = RE_IMAGEN_TAG_P.sub(reemplazo, html_content)
    html_content = RE_IMAGEN_TAG.sub(reemplazo, html_content)
    return html_content


def procesar_separadores(html_content: str) -> str:
    """Detecta marcas [HR] o [SEPARADOR] y las reemplaza
    por un separador XHTML estilizado."""
    html_content = RE_SEPARADOR_P.sub(SEPARADOR_XHTML, html_content)
    html_content = RE_SEPARADOR.sub(SEPARADOR_XHTML, html_content)
    return html_content


# ============================================================
#  PASOS DEL FLUJO PRINCIPAL
# ============================================================

def preparar_entorno() -> None:
    """Paso 0: crea o limpia la carpeta de salida."""
    if not RUTA_SALIDA.exists():
        RUTA_SALIDA.mkdir(parents=True)
    else:
        print("--- 0. PREPARANDO ENTORNO ---")
        print("🧹 Limpiando todos los archivos anteriores (notas y capítulos)...")
        for archivo in RUTA_SALIDA.iterdir():
            try:
                if archivo.is_file():
                    archivo.unlink()
            except Exception as e:
                print(f"❌ Error al eliminar {archivo}: {e}")


def convertir_docx() -> None:
    """Paso 1: convierte el DOCX a XHTML limpio usando Pandoc."""
    print("\n--- 1. INICIANDO CONVERSIÓN ---")

    if not RUTA_DOCX.exists():
        print(f"❌ Error: No se encuentra {RUTA_DOCX}")
        return

    if which('pandoc') is None:
        print("❌ Error: pandoc no está instalado o no está en el PATH")
        return

    try:
        subprocess.run(
            ['pandoc', str(RUTA_DOCX), '-o', str(RUTA_TEMP_RAW),
             '-t', 'html5', '--wrap=none'],
            check=True
        )

        contenido = RUTA_TEMP_RAW.read_text(encoding='utf-8')
        contenido_sin_notas, notas_html = procesar_notas(contenido)
        contenido_limpio = limpiar_texto_html(contenido_sin_notas)
        contenido_con_imagenes = procesar_imagenes(contenido_limpio)
        contenido_final = procesar_separadores(contenido_con_imagenes)

        RUTA_COMPLETO.write_text(contenido_final, encoding='utf-8')
        RUTA_TEMP_RAW.unlink()
        print(f"✅ Archivo completo creado: {RUTA_COMPLETO}")

        if notas_html:
            ruta_notas = RUTA_SALIDA / "notas_Finales.xhtml"
            ruta_notas.write_text(notas_html, encoding='utf-8')
            print(f"✅ Archivo de notas extraído y creado: {ruta_notas}")

    except Exception as e:
        print(f"❌ Error en conversión: {e}")


def crear_capitulos() -> None:
    """Paso 2: crea archivos XHTML desde el template y caps.txt."""
    print("\n--- 2. CREANDO ARCHIVOS DE CAPÍTULO ---")

    if not RUTA_CAPS_TXT.exists():
        print(f"❌ Error: No se encuentra {RUTA_CAPS_TXT}")
        return
    if not RUTA_TEMPLATE.exists():
        print(f"❌ Error: No se encuentra {RUTA_TEMPLATE}")
        return

    RUTA_SALIDA.mkdir(parents=True, exist_ok=True)

    template = RUTA_TEMPLATE.read_text(encoding='utf-8')
    titulos = [
        linea.strip()
        for linea in RUTA_CAPS_TXT.read_text(encoding='utf-8').splitlines()
        if linea.strip()
    ]

    for i, titulo in enumerate(titulos, start=1):
        num_str = f"{i:02d}"
        contenido = template.replace('Capítulo X', f'Capítulo {i}')
        contenido = contenido.replace('Título del capítulo', titulo)
        ruta = RUTA_SALIDA / f"C{num_str}.xhtml"
        ruta.write_text(contenido, encoding='utf-8')
        print(f"Capítulo {num_str} creado: {titulo}")


# ============================================================
#  ENTRY POINT
# ============================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convierte DOCX a XHTML y genera capítulos desde template."
    )
    parser.add_argument(
        "--solo-convertir",
        action="store_true",
        help="Ejecuta solo la conversión del DOCX a XHTML completo.",
    )
    parser.add_argument(
        "--solo-capitulos",
        action="store_true",
        help="Ejecuta solo la creación de capítulos desde el template.",
    )
    args = parser.parse_args()

    if args.solo_convertir and args.solo_capitulos:
        print("❌ Error: Usa solo una de las flags --solo-convertir o --solo-capitulos")
        sys.exit(1)

    preparar_entorno()

    if args.solo_convertir:
        convertir_docx()
    elif args.solo_capitulos:
        crear_capitulos()
    else:
        convertir_docx()
        crear_capitulos()

    print("\n¡Todo listo!")
