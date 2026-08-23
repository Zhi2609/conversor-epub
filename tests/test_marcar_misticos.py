"""Tests mínimos para marcar_misticos.py (script desechable de preprocesado)."""

import unittest

from marcar_misticos import procesar


class TestMarcarMisticos(unittest.TestCase):
    def test_rezo_de_tres_parrafos_se_marca(self):
        texto = ('Narrativa normal.\n\n«El Loco que no pertenece a esta era».\n\n'
                 '«El misterioso gobernante por encima de la niebla gris».\n\n'
                 '«Ruego para que abras las puertas a tu Reino».\n\nMás narrativa.')
        nuevo, n = procesar(texto, 3)
        self.assertEqual(n, 1)
        self.assertTrue(nuevo.startswith('Narrativa normal.\n\n[blockquote]\n\n«El Loco'))
        self.assertTrue(nuevo.endswith('tu Reino».\n\n[/blockquote]\n\nMás narrativa.'))

    def test_dialogo_de_dos_no_se_marca(self):
        nuevo, n = procesar('«Hola».\n\n«Adiós».\n\nFin.', 3)
        self.assertEqual(n, 0)
        self.assertNotIn('[blockquote]', nuevo)

    def test_cita_y_dialogo_adyacentes_no_se_fusionan(self):
        texto = '«A».\n\n«B».\n\n«C».\n\nDijo algo sin comillas.\n\n«D».\n\n«E».\n\n«F».'
        _, n = procesar(texto, 3)
        self.assertEqual(n, 2)

    def test_invisibles_no_rompen_la_deteccion(self):
        texto = '«que\u200c\u200c\u200c no pertenece».\n\n«gobernante».\n\n«Reino».'
        _, n = procesar(texto, 3)
        self.assertEqual(n, 1)


if __name__ == '__main__':
    unittest.main()
