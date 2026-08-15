"""Tests de imágenes y separadores (§5.6)."""

import unittest

from motor.imagenes import procesar_imagenes, procesar_separadores

FIGURA_01 = (
    '<hr class="sigil_split_marker" />\n'
    '<figure class="dimg"><img src="../Images/01.jpg" alt=""/></figure>\n'
    '<hr class="sigil_split_marker" />'
)
SEPARADOR = '<p class="hr centrado grande"><b>※ ・ ※ ・ ※</b></p>'


class TestImagenes(unittest.TestCase):
    def test_imagen_pandoc_con_parrafo(self):
        html = '<p><img src="media/image00001.jpg" alt="foto"/></p>'
        resultado, conteo = procesar_imagenes(html)
        self.assertEqual(resultado, FIGURA_01)
        self.assertEqual(conteo, 1)

    def test_imagen_pandoc_sin_parrafo(self):
        html = 'texto <img src="media/image00001.jpg" alt=""/> fin'
        resultado, conteo = procesar_imagenes(html)
        self.assertIn(FIGURA_01, resultado)
        self.assertEqual(conteo, 1)

    def test_marca_imagen_manual(self):
        html = '<p>[IMAGEN 3]</p>'
        resultado, conteo = procesar_imagenes(html)
        self.assertIn('../Images/03.jpg', resultado)
        self.assertEqual(conteo, 1)

    def test_marca_imagen_sin_ceros(self):
        html = '[IMAGEN 1]'
        resultado, conteo = procesar_imagenes(html)
        self.assertIn('../Images/01.jpg', resultado)
        self.assertIn('<figure class="dimg">', resultado)
        self.assertEqual(conteo, 1)


class TestSeparadores(unittest.TestCase):
    def test_separador_en_parrafo(self):
        html = '<p>[HR]</p>'
        resultado, conteo = procesar_separadores(html)
        self.assertEqual(resultado, SEPARADOR)
        self.assertEqual(conteo, 1)

    def test_separador_palabra_completa(self):
        html = '<p>[SEPARADOR]</p>'
        resultado, conteo = procesar_separadores(html)
        self.assertEqual(resultado, SEPARADOR)
        self.assertEqual(conteo, 1)

    def test_separador_sueltos(self):
        html = 'a [HR] b [SEPARADOR]'
        resultado, conteo = procesar_separadores(html)
        self.assertEqual(conteo, 2)
        self.assertEqual(resultado.count(SEPARADOR), 2)


if __name__ == '__main__':
    unittest.main()