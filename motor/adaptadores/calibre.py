"""Adaptador de entrada: XHTML de Calibre → contenido de <body> limpio."""

import re
from pathlib import Path

from motor.limpieza import texto_plano

RE_BODY = re.compile(r'<body[^>]*>(.*?)</body>', re.DOTALL | re.IGNORECASE)
RE_TITULO_CALIBRE = re.compile(
    r'<h[1-6][^>]*>(.*?)</h[1-6]>', re.DOTALL | re.IGNORECASE
)


def _num_key(archivo: Path) -> list[int]:
    return [int(n) for n in re.findall(r'\d+', archivo.stem)]


def extraer_cuerpo(html: str) -> tuple[str, str | None]:
    """Extrae el contenido de <body>, quita el primer encabezado (título
    que Calibre inyecta) y devuelve (cuerpo, título_detectado)."""
    match = RE_BODY.search(html)
    if not match:
        raise ValueError('No se encontró <body> en el archivo')

    cuerpo = match.group(1)
    titulo: str | None = None

    match_titulo = RE_TITULO_CALIBRE.search(cuerpo)
    if match_titulo:
        titulo = texto_plano(match_titulo.group(1))
        cuerpo = cuerpo[:match_titulo.start()] + cuerpo[match_titulo.end():]

    return cuerpo, titulo


def documentos_calibre(ruta: Path) -> tuple[list[tuple[str, str | None, list[str]]], list[str]]:
    """Lee cada archivo .xhtml/.html (o uno solo si es archivo) y devuelve
    tuplas (cuerpo_sin_titulo, título_detectado, imágenes_placeholder).
    Los archivos sin <body> se omiten con un aviso."""
    if ruta.is_dir():
        archivos = sorted(ruta.glob('*.xhtml'), key=_num_key) + sorted(
            ruta.glob('*.html'), key=_num_key
        )
    else:
        archivos = [ruta]

    if not archivos:
        raise ValueError(f'No se encontraron archivos .xhtml/.html en {ruta}')

    documentos: list[tuple[str, str | None, list[str]]] = []
    avisos: list[str] = []
    for archivo in archivos:
        html = archivo.read_text(encoding='utf-8')
        try:
            cuerpo, titulo = extraer_cuerpo(html)
        except ValueError:
            avisos.append(f'{archivo.name}: sin <body>, omitido')
            continue
        documentos.append((cuerpo, titulo, []))
    return documentos, avisos