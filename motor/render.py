"""Render: inyecta capítulos y notas en la salida final."""

from pathlib import Path

from motor.notas import formatear_nota


def render_capitulo(template: str, titulo: str, num: int, cuerpo: str) -> str:
    """Sustituye los placeholders del template: 'Capítulo X',
    'Título del capítulo' y '{{CONTENIDO}}'."""
    html = template.replace('Capítulo X', f'Capítulo {num}')
    html = html.replace('Título del capítulo', titulo)
    return html.replace('{{CONTENIDO}}', cuerpo.strip())


def render_notas(notas) -> str:
    """Renderiza el archivo notas_Finales.xhtml desde la lista de notas."""
    return '\n'.join(formatear_nota(nota) for nota in notas)


def limpiar_carpeta(ruta: Path) -> None:
    """Crea o limpia la carpeta de salida antes de escribir."""
    ruta.mkdir(parents=True, exist_ok=True)
    for archivo in ruta.iterdir():
        if archivo.is_file():
            archivo.unlink()