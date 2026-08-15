"""Tests de extracción y formateo de notas al pie (§5.5)."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from motor.modelo import Chapter, Nota
from motor.notas import (
    ARCHIVO_NOTAS,
    asignar_capitulos,
    extraer_notas,
    formatear_nota,
    formatear_llamada,
)
from motor.procesar import procesar

HTML_PANDOC = (
    '<html><body>'
    '<p>texto del cuerpo<a href="#fn1">1</a> y <a href="#fn2">2</a> fin</p>'
    '<section id="footnotes">'
    '<ol>'
    '<li id="fn1"><p>Primera nota <a href="#fnref1">↩︎</a></p></li>'
    '<li id="fn2"><p>Segunda nota.</p></li>'
    '</ol>'
    '</section>'
    '</body></html>'
)

TEMPLATE = (
    '<html><body>'
    '<h1>Capítulo X</h1><h2>Título del capítulo</h2>'
    '{{CONTENIDO}}</body></html>'
)


class TestExtraccionNotas(unittest.TestCase):
    def test_extrae_y_limpia_seccion(self):
        html, notas = extraer_notas(HTML_PANDOC)
        self.assertEqual(len(notas), 2)
        self.assertEqual(notas[0].texto, 'Primera nota')
        self.assertEqual(notas[1].texto, 'Segunda nota.')

    def test_seccion_eliminada_del_cuerpo(self):
        html, notas = extraer_notas(HTML_PANDOC)
        self.assertNotIn('footnotes', html)
        self.assertNotIn('fn1', html)

    def test_llamadas_inline_formato_ePub(self):
        html, notas = extraer_notas(HTML_PANDOC)
        self.assertIn(
            f'<a href="{ARCHIVO_NOTAS}#nt01" id="rf01"><sup>❮01❯</sup></a>',
            html,
        )
        self.assertIn('id="rf02"', html)
        self.assertNotIn('href="#fn1"', html)


class TestNotasLegacy(unittest.TestCase):
    def test_marca_legacy_nt(self):
        html, notas = extraer_notas('texto (NT01) con nota (NT12) al final')
        self.assertEqual(notas, [])
        self.assertIn(f'href="{ARCHIVO_NOTAS}#nt01" id="rf01"', html)
        self.assertIn('id="rf12"', html)
        self.assertIn('<sup>❮12❯</sup>', html)

    def test_no_se_usa_notas_xhtml_bug_legacy(self):
        html, notas = extraer_notas('(NT01)')
        self.assertNotIn('notas.xhtml', html)
        self.assertIn('notas_Finales.xhtml', html)


class TestPipelinePandoc(unittest.TestCase):
    def test_limpieza_no_borra_id_rf_generado(self):
        from motor.limpieza import limpiar_texto_html
        html, _ = extraer_notas(HTML_PANDOC)
        html = limpiar_texto_html(html)
        self.assertIn('id="rf01"', html)
        self.assertIn('id="rf02"', html)

    def test_procesar_cuenta_notas_de_docx(self):
        with TemporaryDirectory() as tmp:
            carpeta = Path(tmp)
            (carpeta / 'doc.html').write_text(HTML_PANDOC, encoding='utf-8')
            plantillas = carpeta / 'plantillas'
            plantillas.mkdir()
            template_ruta = plantillas / 'template.xhtml'
            template_ruta.write_text(TEMPLATE, encoding='utf-8')
            resultado = procesar('calibre', carpeta, template_ruta)
        self.assertEqual(resultado.contadores.notas, 2)
        self.assertIn('id="rf01"', resultado.capitulos[0].html_cuerpo)
        self.assertEqual(resultado.notas[0].cap_num, 1)


class TestFormato(unittest.TestCase):
    def test_formato_div_nota(self):
        nota = Nota(num=1, texto='Primera nota', cap_num=1)
        esperado = (
            '<div class="nota">\n'
            ' <p id="nt01">\n'
            '   <a href="C01.xhtml#rf01"><sup>❮01❯</sup> Primera nota</a>\n'
            ' </p>\n'
            '</div>'
        )
        self.assertEqual(formatear_nota(nota), esperado)

    def test_formato_llamada(self):
        self.assertEqual(
            formatear_llamada(1),
            '<a href="notas_Finales.xhtml#nt01" id="rf01"><sup>❮01❯</sup></a>',
        )

    def test_asignacion_de_capitulo(self):
        notas = [Nota(num=1, texto='x'), Nota(num=2, texto='y')]
        capitulos = [
            Chapter(titulo='Uno', html_cuerpo='<p>sin notas</p>'),
            Chapter(titulo='Dos', html_cuerpo='<p>con <a id="rf01">n</a> y <a id="rf02">n</a></p>'),
        ]
        asignar_capitulos(notas, capitulos)
        self.assertEqual(notas[0].cap_num, 2)
        self.assertEqual(notas[1].cap_num, 2)

    def test_asignacion_por_defecto(self):
        notas = [Nota(num=1, texto='x')]
        capitulos = [Chapter(titulo='Uno', html_cuerpo='<p>sin referencias</p>')]
        asignar_capitulos(notas, capitulos)
        self.assertEqual(notas[0].cap_num, 1)


class TestFormatoConImagenes(unittest.TestCase):
    def test_nota_con_imagen_se_envuelve_con_markers(self):
        nota = Nota(
            num=1,
            texto='<img src="media/image3.jpg" width="200" alt=""/> Figura.',
            cap_archivo='C01.xhtml',
        )
        html = formatear_nota(nota)
        self.assertTrue(html.startswith('<hr class="sigil_split_marker" />'))
        self.assertTrue(html.endswith('<hr class="sigil_split_marker" />'))
        self.assertIn('<img src="../Images/nota-01.jpg" alt=""/>', html)
        self.assertIn('<br/><br/>', html)
        self.assertIn('C01.xhtml#rf01', html)
        self.assertNotIn('media/image3.jpg', html)
        self.assertNotIn('width="200"', html)

    def test_nota_con_varias_imagenes_secuenciales(self):
        nota = Nota(
            num=3,
            texto='<img src="a.jpg" alt=""/> texto <img src="b.jpg" alt=""/>',
            cap_num=2,
        )
        html = formatear_nota(nota)
        self.assertIn('src="../Images/nota-03.jpg"', html)
        self.assertIn('src="../Images/nota-03-2.jpg"', html)

    def test_nota_sin_imagen_sin_markers(self):
        nota = Nota(num=1, texto='Solo texto.', cap_num=1)
        html = formatear_nota(nota)
        self.assertNotIn('<hr class="sigil_split_marker" />', html)
        self.assertNotIn('<br/><br/>', html)
        self.assertNotIn('<img', html)


if __name__ == '__main__':
    unittest.main()