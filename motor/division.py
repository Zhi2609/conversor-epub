"""Auto-splitter (§5.3): divide un HTML completo en capítulos usando
cabeceras <h1>, <h2> y <h3> como puntos de corte."""

import re

from motor.limpieza import texto_plano
from motor.modelo import Chapter

RE_ENCABEZADO = re.compile(r'<h([1-3])(?:\s[^>]*)?>(.*?)</h\1>', re.DOTALL | re.IGNORECASE)


def dividir_en_capitulos(
    html: str, titulos: list[str] | None = None, start_num: int = 1
) -> list[Chapter]:
    """Convierte un HTML completo en capítulos. La cabecera de cada corte se
    extrae del cuerpo y se usa como título cuando no hay lista de títulos.
    El contenido anterior a la primera cabecera forma su propio capítulo."""
    matches = list(RE_ENCABEZADO.finditer(html))

    if not matches:
        titulo = titulos[0] if titulos else f'Capítulo {start_num}'
        return [Chapter(titulo=titulo, html_cuerpo=html.strip())]

    capitulos: list[Chapter] = []
    contador = start_num

    pre = html[:matches[0].start()].strip()
    if pre:
        titulo = titulos[0] if titulos else f'Capítulo {contador}'
        capitulos.append(Chapter(titulo=titulo, html_cuerpo=pre))
        contador += 1

    limites = [m.start() for m in matches] + [len(html)]
    for i, match in enumerate(matches):
        cuerpo = RE_ENCABEZADO.sub('', html[limites[i]:limites[i + 1]], count=1).strip()
        texto = texto_plano(match.group(2))
        indice = contador - start_num
        titulo = titulos[indice] if titulos and indice < len(titulos) else (texto or f'Capítulo {contador}')
        capitulos.append(Chapter(titulo=titulo, html_cuerpo=cuerpo))
        contador += 1

    return capitulos