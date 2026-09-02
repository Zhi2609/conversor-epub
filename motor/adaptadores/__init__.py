"""Adaptadores de entrada: docx (pandoc), calibre (XHTML) y markdown."""

import re
from pathlib import Path

MODOS = frozenset({'word', 'calibre', 'markdown', 'pdf'})

def num_key(archivo: Path) -> list[int]:
    """Llave de ordenamiento natural por números en el nombre de archivo."""
    return [int(n) for n in re.findall(r'\d+', archivo.stem)]

from motor.adaptadores.calibre import documentos_calibre
from motor.adaptadores.docx import convertir_docx
from motor.adaptadores.markdown import documentos_markdown


def detectar_modo(ruta: Path) -> str:
    """Detecta el modo según el archivo o el contenido de la carpeta."""
    if ruta.is_file():
        sufijo = ruta.suffix.lower()
        if sufijo == '.docx':
            return 'word'
        if sufijo == '.pdf':
            return 'pdf'
        if sufijo == '.md':
            return 'markdown'
        if sufijo in ('.xhtml', '.html'):
            return 'calibre'
        raise ValueError(
            f'No se reconoce el tipo de entrada: {ruta} '
            '(se espera .docx, .pdf, carpeta .md o carpeta .xhtml/.html)'
        )

    if next(ruta.glob('*.md'), None):
        return 'markdown'
    if next(ruta.glob('*.xhtml'), None) or next(ruta.glob('*.html'), None):
        return 'calibre'

    raise ValueError(f'No se encontraron archivos compatibles en {ruta}')