"""Render: inyecta capítulos y notas en la salida final."""

from pathlib import Path

from motor.notas import formatear_nota
from motor.plantillas import RE_MARCADOR_CONTENIDO


def render_capitulo(template: str, titulo: str, num: int, cuerpo: str) -> str:
    """Sustituye los placeholders del template: 'Capítulo X',
    'Título del capítulo' y '{{CONTENIDO}}'."""
    html = template.replace('Capítulo X', f'Capítulo {num}')
    html = html.replace('Título del capítulo', titulo)
    return html.replace('{{CONTENIDO}}', cuerpo.strip())


def render_capitulo_especial(template: str, titulo: str, num: int, cuerpo: str) -> str:
    """Inyecta el contenido en una plantilla especial (§5.8): el marcador
    '<!-- Aquí va el contenido -->' se conserva como separador y todo lo que
    haya hasta el cierre de </section> se sustituye por el cuerpo."""
    match = RE_MARCADOR_CONTENIDO.search(template)
    if not match:
        raise ValueError(
            'La plantilla especial no tiene el marcador <!-- Aquí va el contenido -->'
        )
    html = (
        template[: match.start()]
        + '<!-- Aquí va el contenido -->\n'
        + cuerpo.strip()
        + template[match.end():]
    )
    html = html.replace('Capítulo X', f'Capítulo {num}')
    return html.replace('Título del capítulo', titulo)


def render_notas(notas) -> str:
    """Renderiza el archivo notas_Finales.xhtml desde la lista de notas."""
    return '\n'.join(formatear_nota(nota) for nota in notas)


def limpiar_carpeta(ruta: Path) -> None:
    """Crea o limpia la carpeta de salida antes de escribir."""
    ruta.mkdir(parents=True, exist_ok=True)
    for archivo in ruta.iterdir():
        if archivo.is_file():
            archivo.unlink()