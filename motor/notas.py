"""Extracción y formateo de notas al pie (§5.5). Las notas se extraen ANTES
de dividir capítulos (D6); el backlink del capítulo se asigna tras el split."""

import re

from motor.limpieza import limpiar_texto_html
from motor.modelo import Chapter, Nota

RE_SECCION_NOTAS = re.compile(
    r'<(section|div)\b[^>]*(?:id|class)="footnotes?"[^>]*>(.*?)</\1>',
    re.DOTALL | re.IGNORECASE,
)
RE_ITEM_NOTA = re.compile(
    r'<li\b[^>]*id="fn(\d+)"[^>]*>(.*?)</li>',
    re.DOTALL | re.IGNORECASE,
)
RE_VINCULO_NOTA_PANDOC = re.compile(
    r'<a\b[^>]*href="#fn(\d+)"[^>]*>.*?</a>',
    re.DOTALL,
)
RE_VINCULO_REGRESO = re.compile(
    r'<a\b[^>]*href="#fnref[^"]*"[^>]*>.*?</a>',
    re.DOTALL,
)
RE_NOTA_LEGACY = re.compile(r'\(NT(\d+)\)')
RE_ANCLA_REGRESO = re.compile(r'↩︎?')

ARCHIVO_NOTAS = 'notas_Finales.xhtml'


def formatear_llamada(num: int) -> str:
    """Llamada inline: <a href="notas_Finales.xhtml#nt01" id="rf01">…"""
    num_fmt = f'{num:02d}'
    return (
        f'<a href="{ARCHIVO_NOTAS}#nt{num_fmt}" id="rf{num_fmt}">'
        f'<sup>❮{num_fmt}❯</sup></a>'
    )


def _reemplazar_notas_legacy(html: str) -> str:
    """Reemplaza referencias legacy (NT##) por llamadas en formato ePub."""

    def reemplazar(match: re.Match) -> str:
        return formatear_llamada(int(match.group(1)))

    return RE_NOTA_LEGACY.sub(reemplazar, html)


def extraer_notas(html: str) -> tuple[str, list[Nota]]:
    """Extrae la sección de notas (pandoc) del HTML y la devuelve formateada
    como lista de Nota; las llamadas inline se actualizan al formato ePub."""
    notas: list[Nota] = []

    match = RE_SECCION_NOTAS.search(html)
    if match:
        contenido_raw = match.group(2)
        html = html[:match.start()] + html[match.end():]

        for num_str, html_nota in RE_ITEM_NOTA.findall(contenido_raw):
            num = int(num_str)
            html_nota = RE_VINCULO_REGRESO.sub('', html_nota)
            html_nota = RE_ANCLA_REGRESO.sub('', html_nota)
            html_nota = re.sub(r'^<p>', '', html_nota.strip())
            html_nota = re.sub(r'</p>$', '', html_nota.strip())
            html_nota = limpiar_texto_html(html_nota.strip())
            notas.append(Nota(num=num, texto=html_nota))

        def reemplazar_llamada(match: re.Match) -> str:
            return formatear_llamada(int(match.group(1)))

        html = RE_VINCULO_NOTA_PANDOC.sub(reemplazar_llamada, html)

    html = _reemplazar_notas_legacy(html)
    return html, notas


def asignar_capitulos(notas: list[Nota], capitulos: list[Chapter], start_num: int = 1) -> None:
    """Asigna a cada nota el capítulo que contiene su llamada (id="rfNN"),
    guardando su nombre de archivo real (§5.8); por defecto el primer
    capítulo si no está referenciada."""
    for nota in notas:
        referencia = f'id="rf{nota.num:02d}"'
        for num, capitulo in enumerate(capitulos, start=start_num):
            if referencia in capitulo.html_cuerpo:
                nota.cap_num = num
                nota.cap_archivo = (
                    capitulo.archivo or f'C{num:02d}.xhtml'
                )
                break
        else:
            nota.cap_num = start_num
            nota.cap_archivo = f'C{start_num:02d}.xhtml'


def formatear_nota(nota: Nota) -> str:
    """Formatea una nota como div ePub con su backlink al capítulo."""
    num_fmt = f'{nota.num:02d}'
    archivo = nota.cap_archivo
    if archivo is None:
        archivo = f'C{nota.cap_num if nota.cap_num is not None else 1:02d}.xhtml'
    return (
        f'<div class="nota">\n'
        f' <p id="nt{num_fmt}">\n'
        f'   <a href="{archivo}#rf{num_fmt}"><sup>❮{num_fmt}❯</sup> {nota.texto}</a>\n'
        f' </p>\n'
        f'</div>'
    )