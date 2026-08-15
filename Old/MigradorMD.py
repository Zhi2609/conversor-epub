import argparse
import re
import sys
from pathlib import Path
from Migrador import limpiar_texto_html, cargar_titulos

RE_BOLD_ITALIC = re.compile(r'\*\*\*(.+?)\*\*\*')
RE_BOLD = re.compile(r'\*\*(.+?)\*\*')
RE_ITALIC = re.compile(r'_(.+?)_')
RE_BACKSLASH = re.compile(r'\\(.)')
RE_H1 = re.compile(r'^# (.+)$', re.MULTILINE)
RE_INVISIBLES = re.compile(r'[\u200B-\u200D\uFEFF]')


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


RE_IMAGEN = re.compile(r'!\\Image(\d*)\\')


def _convertir_imagenes(texto: str) -> tuple[str, list[str]]:
    imagenes: list[str] = []
    def _reemplazo(m: re.Match) -> str:
        num = m.group(1)
        nombre = f"{int(num):02d}.jpg" if num else ""
        html = f'<hr class="sigil_split_marker" />\n    <figure class="dimg"><img src="../Images/{nombre}" alt="" /></figure>\n    <hr class="sigil_split_marker" />'
        idx = len(imagenes)
        imagenes.append(html)
        return f"\x00IMG_{idx}\x00"
    texto = RE_IMAGEN.sub(_reemplazo, texto)
    return texto, imagenes


def _restaurar_imagenes(texto: str, imagenes: list[str]) -> str:
    for i, html in enumerate(imagenes):
        texto = texto.replace(f"\x00IMG_{i}\x00", html)
    return texto


def _num_key(p: Path) -> list[int]:
    return [int(n) for n in re.findall(r'\d+', p.stem)]


def migrar_capitulos_md(carpeta_entrada: Path, carpeta_salida: Path, ruta_template: Path, ruta_caps: Path | None = None, start_num: int = 1):
    if not ruta_template.exists():
        print(f"\u274c Error: No se encuentra el template en {ruta_template}")
        return

    template_data = ruta_template.read_text(encoding='utf-8')

    archivos_md = sorted(carpeta_entrada.glob("*.md"), key=_num_key)
    if not archivos_md:
        print(f"\u274c No se encontraron archivos .md en {carpeta_entrada}")
        return

    titulos = cargar_titulos(ruta_caps, len(archivos_md)) if ruta_caps else []

    carpeta_salida.mkdir(parents=True, exist_ok=True)

    print(f"--- INICIANDO MIGRACI\u00d3N DE {len(archivos_md)} ARCHIVOS MD ---")

    for idx, ruta_archivo in enumerate(archivos_md):
        num = start_num + idx
        num_str = f"{num:02d}"
        contenido_raw = ruta_archivo.read_text(encoding='utf-8')

        contenido_raw = _limpiar_invisibles(contenido_raw)
        contenido_raw, imagenes = _convertir_imagenes(contenido_raw)

        contenido_html = _md_a_html(contenido_raw)
        contenido_html = _parrafos_a_html(contenido_html)
        contenido_limpio = limpiar_texto_html(contenido_html)
        contenido_limpio = _restaurar_imagenes(contenido_limpio, imagenes)

        titulo = titulos[idx] if titulos else f"Cap\u00edtulo {num}"

        nuevo_xhtml = template_data.replace('Cap\u00edtulo X', f'Cap\u00edtulo {num}')
        nuevo_xhtml = nuevo_xhtml.replace('T\u00edtulo del cap\u00edtulo', titulo)
        nuevo_xhtml = nuevo_xhtml.replace('{{CONTENIDO}}', contenido_limpio.strip())

        nombre_salida = f"C{num_str}.xhtml"
        ruta_final = carpeta_salida / nombre_salida
        ruta_final.write_text(nuevo_xhtml, encoding='utf-8')

        print(f"\u2705 {nombre_salida} creado (T\u00edtulo: {titulo})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migra archivos Markdown a XHTML limpio usando un template.")
    parser.add_argument("entrada", type=Path, help="Carpeta con los archivos .md")
    parser.add_argument("-o", "--salida", type=Path, default=Path("./Capitulos_Nuevos"), help="Carpeta de salida")
    parser.add_argument("-t", "--template", type=Path, default=Path(__file__).parent / "template.xhtml", help="Ruta al template XHTML")
    parser.add_argument("-c", "--caps", type=Path, default=None, help="Archivo caps.txt con títulos (uno por línea)")
    parser.add_argument("-n", "--start-num", type=int, default=1, help="Número inicial para la numeración de capítulos")
    args = parser.parse_args()

    if not args.entrada.is_dir():
        print(f"\u274c No se encuentra la carpeta de entrada: {args.entrada}")
        sys.exit(1)

    migrar_capitulos_md(args.entrada, args.salida, args.template, args.caps, args.start_num)
    print("\n\u00a1Migraci\u00f3n completada!")
