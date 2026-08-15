"""Procesamiento de imágenes y separadores (§5.6)."""

import re

SEPARADOR_XHTML = '<p class="hr centrado grande"><b>※ ・ ※ ・ ※</b></p>'

RE_IMG_PANDOC_P = re.compile(
    r'<p[^>]*>\s*<img\b[^>]*src="[^"]*?image0*(\d+)\.[a-zA-Z]+"[^>]*>\s*</p>',
    re.IGNORECASE,
)
RE_IMG_PANDOC = re.compile(
    r'<img\b[^>]*src="[^"]*?image0*(\d+)\.[a-zA-Z]+"[^>]*>',
    re.IGNORECASE,
)
RE_IMAGEN_TAG_P = re.compile(
    r'<p[^>]*>\s*\[IMAGEN\s*0*(\d+)\]\s*</p>',
    re.IGNORECASE,
)
RE_IMAGEN_TAG = re.compile(r'\[IMAGEN\s*0*(\d+)\]', re.IGNORECASE)
RE_SEPARADOR_P = re.compile(
    r'<p[^>]*>\s*\[(?:HR|SEPARADOR)\]\s*</p>',
    re.IGNORECASE,
)
RE_SEPARADOR = re.compile(r'\[(?:HR|SEPARADOR)\]', re.IGNORECASE)


def _reemplazo_imagen(match: re.Match) -> str:
    num_fmt = f'{int(match.group(1)):02d}'
    return (
        f'<hr class="sigil_split_marker" />\n'
        f'<figure class="dimg"><img src="../Images/{num_fmt}.jpg" alt=""/></figure>\n'
        f'<hr class="sigil_split_marker" />'
    )


def procesar_imagenes(html: str) -> tuple[str, int]:
    """Detecta imágenes nativas de pandoc y marcas [IMAGEN N] y las
    reemplaza por el formato ePub de Sigil. Devuelve el HTML y el conteo."""
    contador: list[int] = [0]

    def reemplazo(match: re.Match) -> str:
        contador[0] += 1
        return _reemplazo_imagen(match)

    html = RE_IMG_PANDOC_P.sub(reemplazo, html)
    html = RE_IMG_PANDOC.sub(reemplazo, html)
    html = RE_IMAGEN_TAG_P.sub(reemplazo, html)
    html = RE_IMAGEN_TAG.sub(reemplazo, html)
    return html, contador[0]


def procesar_separadores(html: str) -> tuple[str, int]:
    """Detecta marcas [HR] o [SEPARADOR] y las reemplaza por un
    separador XHTML estilizado. Devuelve el HTML y el conteo."""
    contador: list[int] = [0]

    def reemplazo(match: re.Match) -> str:
        contador[0] += 1
        return SEPARADOR_XHTML

    html = RE_SEPARADOR_P.sub(reemplazo, html)
    html = RE_SEPARADOR.sub(reemplazo, html)
    return html, contador[0]