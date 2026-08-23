"""Tests de la máquina de estados de comillas (D1, D2)."""

import random
import re
import unittest

from motor.limpieza import limpiar_texto_html, _convertir_comillas


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

    def test_grito_anidado_mixto(self):
        # Comillas simples encadenadas a dobles son niveles de anidamiento (D1),
        # no citas simples (D2). Word genera “‘‘Ahh!!’’” para gritos anidados.
        self.assertEqual(limpiar_texto_html('“‘‘Ahh!!’’”'), '«««Ahh!!»»»')
        self.assertEqual(limpiar_texto_html("'''AHHH!!'''"), '«««AHHH!!»»»')

    def test_simple_legitima_no_encadenada_se_conserva(self):
        # Una simple con palabras alrededor (no pegada a una doble) sigue siendo D2.
        self.assertEqual(
            limpiar_texto_html('dijo "vaya" y luego \'niño\''),
            'dijo «vaya» y luego ‘niño’',
        )

    def test_simple_legitima_cerrada_pegada_a_doble(self):
        # La cita simple termina justo donde termina el diálogo ('…'".):
        # el cierre pegado a la doble NO la convierte en nivel de anidamiento,
        # porque su apertura fue una simple legítima (D2).
        self.assertEqual(
            limpiar_texto_html('"Yo quiero ser una \'pared\'".'),
            '«Yo quiero ser una ‘pared’».',
        )


RE_CORTAFUEGOS = re.compile(r'(</p>|<br/?>|</div>|</section>|</blockquote>|<hr>|\n)')
RE_TAGS = re.compile(r'<[^>]+>')

PALABRAS = ['hola', 'mundo', 'dijo', 'susurró', 'Dazai', 'noche', 'luz',
            '¿qué?', '¡no!', 'y', 'pero', 'fin.']


def _palabra(r: random.Random) -> str:
    return r.choice(PALABRAS)


def _frase(r: random.Random) -> str:
    return ' '.join(_palabra(r) for _ in range(r.randint(1, 6)))


def _patron(r: random.Random) -> str:
    return r.choice([
        lambda: '"%s"' % _frase(r),
        lambda: 'dijo: "%s"' % _frase(r),
        lambda: '"%s" —%s' % (_frase(r), _palabra(r)),
        lambda: '%s "%s" %s' % (_palabra(r), _frase(r), _palabra(r)),
        lambda: '"%s "%s", dijo"' % (_frase(r), _frase(r)),
        lambda: "'%s'" % _frase(r),
        lambda: _palabra(r),
    ])()


def _documento(r: random.Random) -> str:
    n = r.randint(1, 6)
    sep = r.choice(['</p>', '\n', '<br/>'])
    return sep.join(
        ' '.join(_patron(r) for _ in range(r.randint(1, 4)))
        for _ in range(n)
    )


class TestInvariantesComillas(unittest.TestCase):
    """Fuzzing con semilla fija: propiedades estructurales que deben cumplir
    para CUALQUIER manuscrito realista. Es la red de seguridad para modificar
    _es_apertura o los CARACTERES_* sin romper comillas (§5.1)."""

    def setUp(self):
        self.rng = random.Random(7)

    def _segmentos(self, html: str) -> list[str]:
        partes = RE_CORTAFUEGOS.split(html)
        return [p for p in partes if p and not RE_CORTAFUEGOS.fullmatch(p)]

    def test_sin_comillas_rectas_sobrevivientes(self):
        for _ in range(5000):
            out = _convertir_comillas(_documento(self.rng))
            plano = RE_TAGS.sub('', out)
            self.assertNotIn('"', plano)
            self.assertNotIn("'", plano)

    def test_balance_por_segmento(self):
        # Por segmento entre cortafuegos: » - « ∈ {0, 1} (el 1 es la comilla
        # sin cerrar del manuscrito, confinada por el cortafuegos).
        for _ in range(5000):
            out = _convertir_comillas(_documento(self.rng))
            for seg in self._segmentos(out):
                p = RE_TAGS.sub('', seg)
                self.assertIn(p.count('»') - p.count('«'), (0, 1), repr(seg))
                self.assertIn(p.count('’') - p.count('‘'), (0, 1), repr(seg))


if __name__ == '__main__':
    unittest.main()