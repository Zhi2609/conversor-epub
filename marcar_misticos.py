"""Preprocesado de una sola vez: marca bloques místicos en manuscritos .md.

Detecta carreras de N o más párrafos consecutivos completamente envueltos en
comillas («…», “…” o "…") y les inserta los marcadores [blockquote] …
[/blockquote] que el adaptador Markdown ya convierte a <blockquote class="mistico">.

El motor NO cambia: esta heurística vive fuera del pipeline canónico (§5.2).
Revisar siempre con git diff antes de aceptar el resultado.

Uso:
    python3 marcar_misticos.py carpeta_md/            # solo informe
    python3 marcar_misticos.py carpeta_md/ --aplicar  # reescribe los .md
    python3 marcar_misticos.py capitulo.md --min 4    # exigir más párrafos
"""

import argparse
import re
from pathlib import Path

RE_INVISIBLES = re.compile(r'[\u200B-\u200D\uFEFF]')
RE_PARRAFO_CITA = re.compile(r'^[«“"](.+)[»”"]$', re.DOTALL)


def _es_bloque_cita(bloque: str) -> bool:
    lineas = [l.strip() for l in bloque.strip().split('\n') if l.strip()]
    lineas = [l.rstrip(' .,;:!?…') for l in lineas]
    return bool(lineas) and all(RE_PARRAFO_CITA.match(l) for l in lineas)


def procesar(texto: str, minimo: int) -> tuple[str, int]:
    """Devuelve (texto_con_marcadores, cantidad_de_bloques_marcados)."""
    texto = RE_INVISIBLES.sub('', texto)
    partes = re.split(r'(\n{2,})', texto)
    es_cita = [i % 2 == 0 and _es_bloque_cita(p) for i, p in enumerate(partes)]

    salida = partes[:]
    marcados = 0
    i = 0
    while i < len(partes):
        if not es_cita[i]:
            i += 1
            continue
        j = i
        while j < len(partes) and es_cita[j]:
            j += 2  # salta el separador
        n_parrafos = (j - i) // 2
        if n_parrafos >= minimo:
            salida[i] = '[blockquote]\n\n' + salida[i]
            salida[j - 2] = salida[j - 2] + '\n\n[/blockquote]'
            marcados += 1
        i = j
    return ''.join(salida), marcados


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ruta', type=Path, help='archivo .md o carpeta con .md')
    parser.add_argument('--min', type=int, default=3,
                        help='mínimo de párrafos citados seguidos (default: 3)')
    parser.add_argument('--aplicar', action='store_true',
                        help='reescribe los archivos (sin esto, solo informe)')
    args = parser.parse_args()

    archivos = (sorted(args.ruta.glob('*.md')) if args.ruta.is_dir()
                else [args.ruta])
    total = 0
    for archivo in archivos:
        texto = archivo.read_text(encoding='utf-8')
        nuevo, marcados = procesar(texto, args.min)
        total += marcados
        print(f'{archivo.name}: {marcados} bloque(s) místico(s)')
        if args.aplicar and marcados:
            archivo.write_text(nuevo, encoding='utf-8')
    print(f'Total: {total} bloque(s)'
          + (' — REVISAR CON git diff' if args.aplicar else ' (informe, sin cambios)'))


if __name__ == '__main__':
    main()
