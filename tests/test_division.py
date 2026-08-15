"""Tests del auto-splitter (§5.3)."""

import unittest

from motor.division import dividir_en_capitulos


class TestDivision(unittest.TestCase):
    def test_sin_cabeceras_un_solo_capitulo(self):
        capitulos = dividir_en_capitulos('<p>solo texto</p>')
        self.assertEqual(len(capitulos), 1)
        self.assertEqual(capitulos[0].titulo, 'Capítulo 1')
        self.assertEqual(capitulos[0].html_cuerpo, '<p>solo texto</p>')

    def test_dos_capitulos_por_h1(self):
        html = '<h1>Parte uno</h1><p>a</p><h1>Parte dos</h1><p>b</p>'
        capitulos = dividir_en_capitulos(html)
        self.assertEqual(len(capitulos), 2)
        self.assertEqual(capitulos[0].titulo, 'Parte uno')
        self.assertEqual(capitulos[0].html_cuerpo, '<p>a</p>')
        self.assertEqual(capitulos[1].titulo, 'Parte dos')
        self.assertEqual(capitulos[1].html_cuerpo, '<p>b</p>')

    def test_detecta_h1_h2_h3(self):
        html = '<h1>a</h1><p>x</p><h2>b</h2><p>y</p><h3>c</h3><p>z</p>'
        capitulos = dividir_en_capitulos(html)
        self.assertEqual([c.titulo for c in capitulos], ['a', 'b', 'c'])

    def test_contenido_previo_es_capitulo(self):
        html = '<p>prólogo</p><h1>Capítulo 1</h1><p>cuerpo</p>'
        capitulos = dividir_en_capitulos(html)
        self.assertEqual(len(capitulos), 2)
        self.assertEqual(capitulos[0].titulo, 'Capítulo 1')
        self.assertEqual(capitulos[1].titulo, 'Capítulo 1')

    def test_titulos_anulan_los_detectados(self):
        html = '<h1>Original</h1><p>x</p>'
        capitulos = dividir_en_capitulos(html, titulos=['Corregido'])
        self.assertEqual(capitulos[0].titulo, 'Corregido')

    def test_start_num(self):
        html = '<h1>a</h1><p>x</p>'
        capitulos = dividir_en_capitulos(html, start_num=5)
        self.assertEqual(capitulos[0].titulo, 'a')


if __name__ == '__main__':
    unittest.main()