import argparse
import re
import sys
from pathlib import Path

RE_BODY = re.compile(r'<body[^>]*>(.*?)</body>', re.DOTALL | re.IGNORECASE)
RE_TITULO_CALIBRE = re.compile(r'<h[1-6][^>]*>(.*?)</h[1-6]>', re.DOTALL | re.IGNORECASE)

RE_SPAN_BASURA = re.compile(r'<span\b[^>]*(?:class|style|id)="[^"]*"[^>]*>')
RE_ATRIBUTOS_BASURA = re.compile(r'\s(?:class|id|style)="[^"]*"')
RE_VACIO_B_I = re.compile(r'<(b|i)></\1>')
RE_DIR_LTR = re.compile(r'\sdir="ltr"')
RE_P_LANG_ES = re.compile(r'<p\s+lang="es">')
RE_SPAN_LANG_ES = re.compile(r'<span\s+lang="es">')
RE_LANG_ES = re.compile(r'\slang="es"')
RE_UNIFICAR_I = re.compile(r'</i>(\s*)<i>')
RE_UNIFICAR_B = re.compile(r'</b>(\s*)<b>')
RE_ALINEAR_APERTURA = re.compile(r'(<(?:i|b)>)([\u00ab\u2018])')
RE_ALINEAR_CIERRE = re.compile(r'([\u00bb\u2019])(</(?:i|b)>)')

TAGS_HTML = frozenset({'p', 'b', 'i', 'hr', 'br', 'div', 'span'})
RE_RESTAURAR_HTML = re.compile(
    r'&lt;(/?)({})([^&]*)&gt;'.format('|'.join(TAGS_HTML))
)

def _normalizar_etiquetas(html: str) -> str:
    html = html.replace('<strong>', '<b>').replace('</strong>', '</b>')
    html = html.replace('<em>', '<i>').replace('</em>', '</i>')
    html = RE_RESTAURAR_HTML.sub(r'<\1\2\3>', html)
    html = html.replace('&lt;', '\u300c').replace('&gt;', '\u300d')
    return html

def _unificar_etiquetas_partidas(html: str) -> str:
    html = RE_UNIFICAR_I.sub(r'\1', html)
    html = RE_UNIFICAR_B.sub(r'\1', html)
    return html

def _es_apertura(texto: str, idx: int) -> bool:
    j = idx - 1
    while j >= 0 and texto[j] in ('"', "'"):
        j -= 1
    prev = texto[j] if j >= 0 else ''
    next_ = texto[idx + 1] if idx < len(texto) - 1 else ''

    es_apertura_prev = (prev == '' or prev in ' \n\t(\u2014-[\u00bf\u00a1>')
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
    html = re.sub('[\u201c\u201d\u00ab\u00bb\u2033]', '"', html)
    html = re.sub("[\u2018\u2019\u2032]", "'", html)

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
                resultado.append('\u00ab' if nivel == 1 else '\u2039')
            else:
                if nivel == 0:
                    resultado.append('\u00bb')
                elif nivel == 1:
                    resultado.append('\u00bb')
                    nivel -= 1
                else:
                    resultado.append('\u203a')
                    nivel -= 1

        elif char == "'":
            resultado.append('\u2018' if _es_apertura(html, i) else '\u2019')

        else:
            resultado.append(char)

    if nivel > 0:
        for j in range(len(resultado) - 1, -1, -1):
            if resultado[j] == '\u00ab':
                resultado[j] = '\u00bb'
                nivel -= 1
                if nivel == 0:
                    break
            elif resultado[j] == '\u2039':
                resultado[j] = '\u203a'
                nivel -= 1
                if nivel == 0:
                    break

    return ''.join(resultado)

def _alinear_comillas_y_etiquetas(html: str) -> str:
    while True:
        antes = html
        html = RE_ALINEAR_APERTURA.sub(r'\2\1', html)
        html = RE_ALINEAR_CIERRE.sub(r'\2\1', html)
        if html == antes:
            break
    return html

def _eliminar_basura_calibre(html: str) -> str:
    html = RE_SPAN_BASURA.sub('', html)
    html = html.replace('</span>', '')
    html = RE_DIR_LTR.sub('', html)
    html = RE_ATRIBUTOS_BASURA.sub('', html)
    html = RE_VACIO_B_I.sub('', html)
    html = RE_P_LANG_ES.sub('<p>', html)
    html = RE_SPAN_LANG_ES.sub('', html)
    html = RE_LANG_ES.sub('', html)
    html = re.sub(r'<div>\s*</div>', '', html)
    return html

def limpiar_texto_html(html: str) -> str:
    html = _normalizar_etiquetas(html)
    html = _unificar_etiquetas_partidas(html)
    html = _convertir_comillas(html)
    html = _alinear_comillas_y_etiquetas(html)
    html = _eliminar_basura_calibre(html)
    return html

def cargar_titulos(ruta_caps: Path, total: int) -> list[str]:
    if not ruta_caps.exists():
        return []
    lineas = [l.strip() for l in ruta_caps.read_text(encoding='utf-8').splitlines() if l.strip()]
    # si hay menos títulos que archivos, rellenar con genérico
    while len(lineas) < total:
        lineas.append(f"Cap\u00edtulo {len(lineas) + 1}")
    return lineas[:total]

def migrar_capitulos(carpeta_entrada: Path, carpeta_salida: Path, ruta_template: Path, ruta_caps: Path | None = None):
    if not ruta_template.exists():
        print(f"\u274c Error: No se encuentra el template en {ruta_template}")
        return

    template_data = ruta_template.read_text(encoding='utf-8')

    def _num_key(p: Path) -> list[int]:
        return [int(n) for n in re.findall(r'\d+', p.stem)]
    archivos_calibre = sorted(carpeta_entrada.glob("*.xhtml"), key=_num_key) + sorted(carpeta_entrada.glob("*.html"), key=_num_key)
    if not archivos_calibre:
        print(f"\u274c No se encontraron archivos .xhtml o .html en {carpeta_entrada}")
        return

    titulos = cargar_titulos(ruta_caps, len(archivos_calibre)) if ruta_caps else []

    carpeta_salida.mkdir(parents=True, exist_ok=True)

    print(f"--- INICIANDO MIGRACI\u00d3N DE {len(archivos_calibre)} ARCHIVOS ---")

    for i, ruta_archivo in enumerate(archivos_calibre, start=1):
        num_str = f"{i:02d}"
        contenido_raw = ruta_archivo.read_text(encoding='utf-8')

        match_body = RE_BODY.search(contenido_raw)
        if not match_body:
            print(f"\u26a0\ufe0f No se encontr\u00f3 <body> en {ruta_archivo.name}, saltando...")
            continue
        body_content = match_body.group(1)

        # quitar el h1 que Calibre mete (no nos interesa su título)
        match_titulo = RE_TITULO_CALIBRE.search(body_content)
        if match_titulo:
            body_content = body_content[:match_titulo.start()] + body_content[match_titulo.end():]

        titulo = titulos[i - 1] if titulos else f"Cap\u00edtulo {i}"
        contenido_limpio = limpiar_texto_html(body_content)

        nuevo_xhtml = template_data.replace('Cap\u00edtulo X', f'Cap\u00edtulo {i}')
        nuevo_xhtml = nuevo_xhtml.replace('T\u00edtulo del cap\u00edtulo', titulo)
        nuevo_xhtml = nuevo_xhtml.replace('{{CONTENIDO}}', contenido_limpio.strip())

        nombre_salida = f"C{num_str}.xhtml"
        ruta_final = carpeta_salida / nombre_salida
        ruta_final.write_text(nuevo_xhtml, encoding='utf-8')

        print(f"\u2705 {nombre_salida} creado (T\u00edtulo: {titulo})")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migra XHTML de Calibre a un Template limpio.")
    parser.add_argument("entrada", type=Path, help="Carpeta con los XHTML sucios de Calibre")
    parser.add_argument("-o", "--salida", type=Path, default=Path("./Capitulos_Nuevos"), help="Carpeta de salida")
    parser.add_argument("-t", "--template", type=Path, default=Path(__file__).parent / "template.xhtml", help="Ruta al template XHTML")
    parser.add_argument("-c", "--caps", type=Path, default=None, help="Archivo caps.txt con títulos (uno por línea)")
    args = parser.parse_args()

    if not args.entrada.is_dir():
        print(f"\u274c No se encuentra la carpeta de entrada: {args.entrada}")
        sys.exit(1)

    migrar_capitulos(args.entrada, args.salida, args.template, args.caps)
    print("\n\u00a1Migraci\u00f3n completada!")