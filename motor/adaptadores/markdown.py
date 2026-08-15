"""Adaptador de entrada: Markdown → HTML (§5.7). Las imágenes se procesan
con placeholders \x00IMG_x\x00 para que la limpieza no las toque."""

import re
from pathlib import Path

from motor.limpieza import texto_plano

RE_BOLD_ITALIC = re.compile(r'\*\*\*(.+?)\*\*\*')
RE_BOLD = re.compile(r'\*\*(.+?)\*\*')
RE_ITALIC = re.compile(r'_(.+?)_')
RE_BACKSLASH = re.compile(r'\\(.)')
RE_H1 = re.compile(r'^# (.+)$', re.MULTILINE)
RE_INVISIBLES = re.compile(r'[\u200B-\u200D\uFEFF]')
RE_IMAGEN = re.compile(r'!\\Image(\d*)\\')
RE_H1_PRINCIPAL = re.compile(r'<h1[^>]*>(.*?)</h1>', re.DOTALL | re.IGNORECASE)


def _md_a_html(texto: str) -> str:
    texto = texto.replace('\r\n', '\n')
    texto = texto.replace('[blockquote]', '<blockquote class="mistico">')
    texto = texto.replace('[/blockquote]', '</blockquote>')
    texto = RE_BOLD_ITALIC.sub(r'<b><i>\1</i></b>', texto)
    texto = RE_BOLD.sub(r'<b>\1</b>', texto)
    texto = RE_ITALIC.sub(r'<i>\1</i>', texto)
    texto = RE_BACKSLASH.sub(r'\1', texto)
    texto = RE_H1.sub(r'<h1>\1</h1>', texto)
    return texto


def _parrafos_a_html(texto: str) -> str:
    bloques = re.split(r'\n{2,}', texto)
    resultado: list[str] = []
    for bloque in bloques:
        bloque = bloque.strip()
        if not bloque:
            continue
        if bloque.startswith(('<h1', '<hr', '<figure')) or bloque.startswith('\x00IMG_'):
            resultado.append(bloque)
        else:
            bloque = bloque.replace('\n', ' ')
            bloque = re.sub(r' +', ' ', bloque)
            resultado.append(f'<p>{bloque}</p>')
    return '\n'.join(resultado)


def _limpiar_invisibles(texto: str) -> str:
    return RE_INVISIBLES.sub(' ', texto)


def _convertir_imagenes(texto: str) -> tuple[str, list[str]]:
    imagenes: list[str] = []

    def _reemplazo(match: re.Match) -> str:
        num = match.group(1)
        nombre = f'{int(num):02d}.jpg' if num else ''
        html = (
            '<hr class="sigil_split_marker" />\n'
            f'    <figure class="dimg"><img src="../Images/{nombre}" alt="" /></figure>\n'
            '    <hr class="sigil_split_marker" />'
        )
        indice = len(imagenes)
        imagenes.append(html)
        return f'\x00IMG_{indice}\x00'

    texto = RE_IMAGEN.sub(_reemplazo, texto)
    return texto, imagenes


def _restaurar_imagenes(texto: str, imagenes: list[str]) -> str:
    for i, html in enumerate(imagenes):
        texto = texto.replace(f'\x00IMG_{i}\x00', html)
    return texto


def _num_key(archivo: Path) -> list[int]:
    return [int(n) for n in re.findall(r'\d+', archivo.stem)]


def documentos_markdown(ruta: Path) -> tuple[list[tuple[str, str | None, list[str]]], list[str]]:
    """Lee cada archivo .md y devuelve tuplas (html_listo_para_limpiar,
    título_detectado, imágenes_placeholder) y una lista de avisos.
    El primer <h1> al inicio del archivo se extrae como título del capítulo
    y se elimina del cuerpo."""
    if ruta.is_dir():
        archivos = sorted(ruta.glob('*.md'), key=_num_key)
    else:
        archivos = [ruta]

    if not archivos:
        raise ValueError(f'No se encontraron archivos .md en {ruta}')

    documentos: list[tuple[str, str | None, list[str]]] = []
    avisos: list[str] = []
    for archivo in archivos:
        texto = archivo.read_text(encoding='utf-8')
        texto = _limpiar_invisibles(texto)
        texto, imagenes = _convertir_imagenes(texto)
        html = _md_a_html(texto)
        html = _parrafos_a_html(html)

        titulo: str | None = None
        match_titulo = RE_H1_PRINCIPAL.match(html)
        if match_titulo:
            titulo = texto_plano(match_titulo.group(1))
            html = html[match_titulo.end():].strip()
        else:
            avisos.append(f'{archivo.name}: sin título detectado')

        documentos.append((html, titulo, imagenes))
    return documentos, avisos