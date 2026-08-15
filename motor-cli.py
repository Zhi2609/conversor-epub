"""Entry point de consola del motor unificado (Fase 1)."""

import argparse
import sys
from pathlib import Path

from motor import detectar_modo, procesar, ruta_template_empaquetado
from motor.adaptadores import MODOS
from motor.render import limpiar_carpeta, render_capitulo, render_notas

RUTA_TEMPLATE_DEFECTO = ruta_template_empaquetado()
RUTA_SALIDA_DEFECTO = Path('Capitulos')


def _cargar_titulos(ruta: Path | None) -> list[str] | None:
    if ruta is None:
        return None
    if not ruta.exists():
        raise ValueError(f'No se encuentra el archivo de títulos: {ruta}')
    return [
        linea.strip()
        for linea in ruta.read_text(encoding='utf-8').splitlines()
        if linea.strip()
    ]


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Procesa DOCX, XHTML de Calibre o Markdown a capítulos XHTML limpios.'
    )
    parser.add_argument('entrada', type=Path, help='Archivo .docx o carpeta con .md/.xhtml/.html')
    parser.add_argument('-o', '--salida', type=Path, default=RUTA_SALIDA_DEFECTO, help='Carpeta de salida')
    parser.add_argument('-t', '--template', type=Path, default=RUTA_TEMPLATE_DEFECTO, help='Plantilla XHTML')
    parser.add_argument('-c', '--caps', type=Path, default=None, help='Archivo de títulos opcional (prefill)')
    parser.add_argument('-n', '--start-num', type=int, default=1, help='Número inicial de capítulos')
    parser.add_argument(
        '--modo', choices=sorted(MODOS) + ['auto'], default='auto',
        help='Forzar modo de entrada (por defecto: auto)',
    )
    args = parser.parse_args()

    if not args.entrada.exists():
        print(f'❌ Error: No se encuentra la entrada: {args.entrada}')
        sys.exit(1)

    try:
        modo = detectar_modo(args.entrada) if args.modo == 'auto' else args.modo
        titulos = _cargar_titulos(args.caps)
        resultado = procesar(
            modo,
            args.entrada,
            args.template,
            titulos=titulos,
            start_num=args.start_num,
        )
    except (ValueError, RuntimeError) as error:
        print(f'❌ Error: {error}')
        sys.exit(1)

    try:
        limpiar_carpeta(args.salida)
        template = args.template.read_text(encoding='utf-8')
        for num, capitulo in enumerate(resultado.capitulos, start=args.start_num):
            ruta = args.salida / f'C{num:02d}.xhtml'
            ruta.write_text(
                render_capitulo(template, capitulo.titulo, num, capitulo.html_cuerpo),
                encoding='utf-8',
            )

        if resultado.notas:
            ruta_notas = args.salida / 'notas_Finales.xhtml'
            ruta_notas.write_text(render_notas(resultado.notas), encoding='utf-8')

    except Exception as error:
        print(f'❌ Error al escribir la salida: {error}')
        sys.exit(1)

    contadores = resultado.contadores
    print(f'✅ Modo: {modo.upper()}')
    print(f'✅ Capítulos: {contadores.capitulos}')
    print(f'✅ Notas al pie: {contadores.notas}')
    print(f'✅ Imágenes: {contadores.imagenes}')
    print(f'✅ Separadores: {contadores.separadores}')
    for aviso in resultado.avisos:
        print(f'⚠️  {aviso}')
    print(f'📁 Salida: {args.salida}/')


if __name__ == '__main__':
    main()