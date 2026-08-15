"""Orquestador del pipeline completo (D6):

adaptador → limpieza → extracción de notas → imágenes/separadores → split → render."""

from pathlib import Path

from motor.adaptadores.calibre import documentos_calibre
from motor.adaptadores.docx import convertir_docx
from motor.adaptadores.markdown import _restaurar_imagenes, documentos_markdown
from motor.division import dividir_en_capitulos
from motor.imagenes import procesar_imagenes, procesar_separadores
from motor.limpieza import limpiar_texto_html
from motor.modelo import Chapter, Contadores, Nota, Resultado
from motor.notas import asignar_capitulos, extraer_notas
from motor.plantillas import clasificar_especial


def _procesar_documento(
    html: str,
    notas: list[Nota],
    imagenes_placeholder: list[str] | None = None,
) -> tuple[str, int, int]:
    """Pipeline común por documento: notas → limpieza → imágenes → separadores.
    Las notas se extraen ANTES de la limpieza porque ésta elimina los
    atributos id=/class= de las anclas de pandoc (<section id="footnotes">)."""
    html, notas_doc = extraer_notas(html)
    notas.extend(notas_doc)
    html = limpiar_texto_html(html)

    n_imagenes = 0
    if imagenes_placeholder:
        html = _restaurar_imagenes(html, imagenes_placeholder)
        n_imagenes += len(imagenes_placeholder)

    html, n_img = procesar_imagenes(html)
    n_imagenes += n_img

    html, n_sep = procesar_separadores(html)
    return html, n_imagenes, n_sep


def procesar(
    modo: str,
    ruta_entrada: Path,
    ruta_template: Path,
    titulos: list[str] | None = None,
    start_num: int = 1,
    ruta_plantillas: Path | None = None,
) -> Resultado:
    """Procesa el manuscrito completo y devuelve capítulos, notas y conteos.

    ruta_plantillas: carpeta con prologo.xhtml/epilogo.xhtml/auto.xhtml;
    si se indica, los capítulos cuyo título coincida con la tabla especial
    (§5.8) se marcan con su archivo y plantilla propios. Si la plantilla
    especial no existe, el capítulo se queda con la numeración normal y se
    añade un aviso."""
    if modo not in ('word', 'calibre', 'markdown'):
        raise ValueError(f'Modo desconocido: {modo}')

    template = ruta_template.read_text(encoding='utf-8')
    if '{{CONTENIDO}}' not in template:
        raise ValueError('El template no contiene el placeholder {{CONTENIDO}}')

    notas: list[Nota] = []
    capitulos: list[Chapter] = []
    avisos: list[str] = []
    n_imagenes_total = 0
    n_separadores_total = 0

    if modo == 'word':
        html = convertir_docx(ruta_entrada)
        html, n_img, n_sep = _procesar_documento(html, notas)
        n_imagenes_total += n_img
        n_separadores_total += n_sep
        capitulos = dividir_en_capitulos(html, titulos, start_num)

    else:
        if modo == 'calibre':
            documentos, avisos_doc = documentos_calibre(ruta_entrada)
        else:
            documentos, avisos_doc = documentos_markdown(ruta_entrada)
        avisos.extend(avisos_doc)
        for indice, (html_doc, titulo_auto, imagenes_placeholder) in enumerate(documentos):
            html, n_img, n_sep = _procesar_documento(html_doc, notas, imagenes_placeholder)
            n_imagenes_total += n_img
            n_separadores_total += n_sep

            num = start_num + indice
            titulo = (
                titulos[indice]
                if titulos and indice < len(titulos)
                else (titulo_auto or f'Capítulo {num}')
            )
            capitulos.append(Chapter(titulo=titulo, html_cuerpo=html.strip()))

    if ruta_plantillas is not None:
        for capitulo in capitulos:
            archivo = clasificar_especial(capitulo.titulo)
            if archivo:
                plantilla_ruta = ruta_plantillas / archivo
                if plantilla_ruta.is_file():
                    capitulo.archivo = archivo
                    capitulo.plantilla_ruta = plantilla_ruta
                else:
                    avisos.append(
                        f'"{capitulo.titulo}": plantilla especial no encontrada '
                        f'({archivo}), se usa la numeración normal'
                    )

    numero = start_num
    for capitulo in capitulos:
        if capitulo.archivo is None:
            capitulo.archivo = f'C{numero:02d}.xhtml'
            numero += 1

    asignar_capitulos(notas, capitulos, start_num)

    contadores = Contadores(
        capitulos=len(capitulos),
        notas=len(notas),
        imagenes=n_imagenes_total,
        separadores=n_separadores_total,
    )
    return Resultado(capitulos=capitulos, notas=notas, contadores=contadores, avisos=avisos)