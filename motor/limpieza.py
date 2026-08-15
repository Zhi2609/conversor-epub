"""Motor de limpieza tipográfica: máquina de estados de comillas (D1, D2) y
basura HTML (unión de los conjuntos legacy de Word y Calibre)."""

import re

RE_RESTAURAR_HTML = re.compile(
    r'&lt;(/?)(p|b|i|hr|br|div|span)([^&]*)&gt;'
)
RE_SPAN_BASURA = re.compile(
    r'<span\b[^>]*(?:class|style|id)="[^"]*"[^>]*>'
)
RE_ATRIBUTOS_BASURA = re.compile(
    r'\s(?:id(?!=["\']rf\d+")|style|class(?!=["\']mistico))="[^"]*"'
)
RE_DIR_LTR = re.compile(r'\sdir="ltr"')
RE_LANG_ES = re.compile(r'\slang="es"')
RE_VACIO_B_I = re.compile(r'<(b|i)></\1>')
RE_DIV_VACIO = re.compile(r'<div>\s*</div>', re.IGNORECASE)
RE_UNIFICAR_I = re.compile(r'</i>(\s*)<i>')
RE_UNIFICAR_B = re.compile(r'</b>(\s*)<b>')
RE_ALINEAR_APERTURA = re.compile(r'(<(?:i|b)>)([«‘])')
RE_ALINEAR_CIERRE = re.compile(r'([»’])(</(?:i|b)>)')
RE_ETIQUETA = re.compile(r'<[^>]+>')

CORTARAFUEGOS = frozenset({
    '</p>', '<br>', '<br/>', '</div>', '</section>', '</blockquote>', '<hr>',
})

CARACTERES_ABREN = ' \n\t(—-[{¿¡>:;'
CARACTERES_CIERRAN = ' \n\t.,;:!?)]}<'


def _es_apertura(texto: str, idx: int) -> bool:
    """Determina si una comilla abre o cierra mirando caracteres
    anterior y siguiente, saltando bloques de comillas consecutivas."""
    j = idx - 1
    while j >= 0 and texto[j] in ('"', "'"):
        j -= 1
    prev = texto[j] if j >= 0 else ''
    next_ = texto[idx + 1] if idx < len(texto) - 1 else ''

    es_apertura_prev = (prev == '' or prev in CARACTERES_ABREN)
    es_cierre_next = (next_ == '' or next_ in CARACTERES_CIERRAN)

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
    """Reemplaza comillas rectas por latinas con sistema de niveles:
    D1: todos los niveles de comillas dobles se escriben «/», el contador
    solo empareja y sostiene el cortafuegos.
    D2: las comillas simples explícitas se convierten en '…' independientes
    del contador de niveles."""
    html = re.sub(r'[“”«»\u2033]', '"', html)
    html = re.sub(r'[‘’\u2032]', "'", html)

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
                if "".join(tag_buffer).lower() in CORTARAFUEGOS:
                    nivel = 0
            continue

        if char == '\n':
            nivel = 0
            resultado.append(char)
            continue

        if char == '"':
            if _es_apertura(html, i):
                nivel += 1
                resultado.append('«')
            else:
                resultado.append('»')
                if nivel > 0:
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

    return ''.join(resultado).replace('\x01', '‘').replace('\x02', '’')


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


def _eliminar_basura(html: str) -> str:
    """Elimina la basura HTML de Word y de Calibre: spans con atributos,
    class/id/style, dir, lang, etiquetas vacías y divs vacíos."""
    html = RE_SPAN_BASURA.sub('', html)
    html = html.replace('</span>', '')
    html = RE_DIR_LTR.sub('', html)
    html = RE_LANG_ES.sub('', html)
    html = RE_ATRIBUTOS_BASURA.sub('', html)
    html = RE_VACIO_B_I.sub('', html)
    html = RE_DIV_VACIO.sub('', html)
    return html


def limpiar_texto_html(html: str) -> str:
    """Pipeline canónico de limpieza: normaliza etiquetas, restaura HTML
    escapado, unifica etiquetas partidas, convierte comillas a latinas,
    alinea comillas con etiquetas y elimina la basura."""
    html = _normalizar_etiquetas(html)
    html = _restaurar_html_escapado(html)
    html = _unificar_etiquetas_partidas(html)
    html = _convertir_comillas(html)
    html = _alinear_comillas_y_etiquetas(html)
    html = _eliminar_basura(html)
    return html


def texto_plano(html: str) -> str:
    """Extrae el texto de un fragmento HTML sin etiquetas."""
    return RE_ETIQUETA.sub('', html).strip()