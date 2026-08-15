"""Tests de la máquina de estados de comillas (D1, D2)."""

import unittest

from motor.limpieza import limpiar_texto_html


class TestComillasCanonicas(unittest.TestCase):
    def test_grito_triple(self):
        self.assertEqual(limpiar_texto_html('"""AHHH!!!!"""'), '«««AHHH!!!!»»»')

    def test_titulo_nivel_uno(self):
        texto = 'se llama "Indigno de ser Humano" de Dazai'
        self.assertEqual(limpiar_texto_html(texto), 'se llama «Indigno de ser Humano» de Dazai')

    def test_comillas_simples_explicitas(self):
        texto = "hablo con... un 'niño'"
        self.assertEqual(limpiar_texto_html(texto), 'hablo con... un ‘niño’')

    def test_titulo_dentro_de_dialogo(self):
        texto = '"me gusta "Indigno", dijo"'
        self.assertEqual(limpiar_texto_html(texto), '«me gusta «Indigno», dijo»')

    def test_comillas_sin_cerrar_al_final(self):
        self.assertEqual(limpiar_texto_html('"hola mi amigo'), '»hola mi amigo')

    def test_dialogos_adyacentes(self):
        self.assertEqual(limpiar_texto_html('"hola", "adiós"'), '«hola», «adiós»')

    def test_cortafuegos_por_parrafo(self):
        texto = '"primero</p><p>"segundo'
        self.assertEqual(limpiar_texto_html(texto), '«primero</p><p>»segundo')

    def test_cortafuegos_por_salto_de_linea(self):
        self.assertEqual(limpiar_texto_html('"a\n"b'), '«a\n»b')

    def test_abre_despues_de_dos_puntos(self):
        self.assertEqual(limpiar_texto_html('dijo: "hola"'), 'dijo: «hola»')

    def test_normaliza_tipograficas(self):
        self.assertEqual(limpiar_texto_html('“dijo” «ella» ″otro″'), '«dijo» «ella» «otro»')

    def test_cierre_despues_de_exclamacion(self):
        self.assertEqual(limpiar_texto_html('"¡AHHH!"'), '«¡AHHH!»')


if __name__ == '__main__':
    unittest.main()