"""Tests de limpieza de basura HTML (§5.4)."""

import unittest

from motor.limpieza import limpiar_texto_html


class TestBasuraWordYCalibre(unittest.TestCase):
    def test_basura_word(self):
        html = '<span class="MsoNormal" lang="es" dir="ltr" id="x1">hola</span> <strong>b</strong> <em>i</em> <b></b>'
        self.assertEqual(limpiar_texto_html(html), 'hola <b>b</b> <i>i</i> ')

    def test_basura_calibre(self):
        html = '<p class="calibre1" lang="es" dir="ltr">texto</p>'
        self.assertEqual(limpiar_texto_html(html), '<p>texto</p>')

    def test_restaura_html_escapado(self):
        self.assertEqual(
            limpiar_texto_html('&lt;p&gt;texto sano&lt;/p&gt;'),
            '<p>texto sano</p>',
        )

    def test_etiquetas_no_reconocidas_a_adornos(self):
        self.assertEqual(limpiar_texto_html('&lt;foo&gt;'), '「foo」')

    def test_se_conserva_clase_mistico(self):
        html = '[blockquote] → <blockquote class="mistico">x</blockquote>'
        self.assertIn('class="mistico"', limpiar_texto_html(html))

    def test_etiquetas_partidas_unificadas(self):
        self.assertEqual(limpiar_texto_html('x</i> <i>y'), 'x y')
        self.assertEqual(limpiar_texto_html('x</b><b>y'), 'xy')

    def test_div_vacio_eliminado(self):
        self.assertEqual(limpiar_texto_html('<div></div><p>x</p>'), '<p>x</p>')


class TestAlineacionConEtiquetas(unittest.TestCase):
    def test_comillas_fuera_de_b_i(self):
        self.assertEqual(limpiar_texto_html('<i>"texto"</i>'), '«<i>texto</i>»')
        self.assertEqual(limpiar_texto_html('"<i>texto</i>"'), '«<i>texto</i>»')
        self.assertEqual(limpiar_texto_html('"<b>texto"</b>'), '«<b>texto</b>»')


if __name__ == '__main__':
    unittest.main()