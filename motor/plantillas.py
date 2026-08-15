"""Capítulos especiales sin numeración: Prólogo, Epílogo y Palabras del autor
(§5.8). Se clasifican por el título; su contenido se inyecta en la plantilla
justo debajo del marcador '<!-- Aquí va el contenido -->'."""

import re
import unicodedata

TABLA_ESPECIALES: dict[str, str] = {
    'prologo': 'prologo.xhtml',
    'epilogo': 'epilogo.xhtml',
    'palabras del autor': 'auto.xhtml',
}

RE_MARCADOR_CONTENIDO = re.compile(
    r'<!--\s*Aquí va el contenido\s*-->(.*?)</section>',
    re.DOTALL | re.IGNORECASE,
)


def _normalizar_titulo(titulo: str) -> str:
    """Minúsculas y sin tildes para clasificar títulos."""
    texto = unicodedata.normalize('NFD', titulo).encode('ascii', 'ignore').decode()
    return texto.lower().strip()


def clasificar_especial(titulo: str) -> str | None:
    """Devuelve el archivo especial ('prologo.xhtml', …) si el título
    empieza con una clave de TABLA_ESPECIALES; None si es capítulo normal."""
    normalizado = _normalizar_titulo(titulo)
    for clave, archivo in TABLA_ESPECIALES.items():
        if normalizado.startswith(clave):
            return archivo
    return None