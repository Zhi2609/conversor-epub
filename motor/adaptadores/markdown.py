"""Adaptador de entrada: Markdown → HTML (§5.7). Las imágenes se procesan
con placeholders \x00IMG_x\x00 para que la limpieza no las toque."""

import re
import shutil
import subprocess
from pathlib import Path

from motor.limpieza import texto_plano
from motor.adaptadores import num_key

RE_INVISIBLES = re.compile(r'[\u200B-\u200D\uFEFF]')
RE_IMAGEN = re.compile(r'!\\Image(\d*)\\')
RE_H1_PRINCIPAL = re.compile(r'<h1[^>]*>(.*?)</h1>', re.DOTALL | re.IGNORECASE)


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


def documentos_markdown(ruta: Path) -> tuple[list[tuple[str, str | None, list[str]]], list[str]]:
    """Lee cada archivo .md y devuelve tuplas (html_listo_para_limpiar,
    título_detectado, imágenes_placeholder) y una lista de avisos.
    El primer <h1> al inicio del archivo se extrae como título del capítulo
    y se elimina del cuerpo."""
    if shutil.which('pandoc') is None:
        raise RuntimeError('pandoc no está instalado o no está en el PATH')

    if ruta.is_dir():
        archivos = sorted(ruta.glob('*.md'), key=num_key)
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
        
        # Preprocesar etiquetas exclusivas antes de pandoc
        texto = texto.replace('[blockquote]', '<blockquote class="mistico">')
        texto = texto.replace('[/blockquote]', '</blockquote>')

        resultado = subprocess.run(
            ['pandoc', '-f', 'markdown', '-t', 'html5', '--wrap=none'],
            input=texto,
            text=True,
            capture_output=True,
            check=True
        )
        html = resultado.stdout

        titulo: str | None = None
        match_titulo = RE_H1_PRINCIPAL.match(html)
        if match_titulo:
            titulo = texto_plano(match_titulo.group(1))
            html = html[match_titulo.end():].strip()
        else:
            avisos.append(f'{archivo.name}: sin título detectado')

        documentos.append((html, titulo, imagenes))
    return documentos, avisos