"""Tests de capítulos especiales sin numeración: Prólogo, Epílogo y Palabras
del autor (§5.8)."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from motor.plantillas import clasificar_especial, numero_de_archivo
from motor.procesar import procesar
from motor.render import render_capitulo_especial

PROLOGO = (
    '<html><body><section id="prologue" aria-label="Prólogo">'
    '<header><h1 title="Prólogo: Título del capítulo">Prólogo'
    '<br/><span class="versalita">Título del capítulo</span>'
    '</h1></header>'
    '<!-- Aquí va el contenido -->'
    '<p>Lorem Ipsum</p>'
    '</section></body></html>'
)

TEMPLATE = (
    '<html><body>'
    '<h1>Capítulo X</h1><h2>Título del capítulo</h2>'
    '{{CONTENIDO}}</body></html>'
)


class TestClasificacion(unittest.TestCase):
    def test_titulos_especiales(self):
        casos = {
            'Prólogo': 'prologo.xhtml',
            'Prólogo: ¿Sueño o Realidad?': 'prologo.xhtml',
            'PROLOGO': 'prologo.xhtml',
            'Epílogo': 'epilogo.xhtml',
            'Palabras del autor': 'autor.xhtml',
            'Palabras del autor: Gracias': 'autor.xhtml',
        }
        for titulo, esperado in casos.items():
            self.assertEqual(clasificar_especial(titulo), esperado)

    def test_capitulos_normales(self):
        self.assertIsNone(clasificar_especial('Secreto Oculto 1'))
        self.assertIsNone(clasificar_especial('Capítulo 4'))
        self.assertIsNone(clasificar_especial('La Prólogo de la historia'))


class TestRenderEspecial(unittest.TestCase):
    def test_marcador_se_conserva_y_contenido_se_inyecta(self):
        html = render_capitulo_especial(PROLOGO, '¿Sueño o Realidad?', 1, '<p>Hola</p>')
        self.assertIn('<!-- Aquí va el contenido -->', html)
        self.assertNotIn('Lorem Ipsum', html)
        self.assertIn('<p>Hola</p>', html)
        self.assertIn('Prólogo: ¿Sueño o Realidad?', html)

    def test_titulo_estatico_se_conserva(self):
        html = render_capitulo_especial(PROLOGO, 'X', 1, 'y')
        self.assertIn('>Prólogo<', html)

    def test_sin_marcador_lanza_error(self):
        with self.assertRaises(ValueError):
            render_capitulo_especial('<section><header>s</header></section>', 't', 1, 'c')


class TestProcesarEspeciales(unittest.TestCase):
    def test_archivo_y_backlink_especiales(self):
        with TemporaryDirectory() as tmp:
            carpeta = Path(tmp)
            (carpeta / '01.html').write_text(
                '<html><body><h1>Prólogo</h1>'
                '<p>Inicio del libro<a href="#fn1">1</a>.</p>'
                '<section id="footnotes"><ol>'
                '<li id="fn1"><p>Nota del prólogo.</p></li>'
                '</ol></section></body></html>',
                encoding='utf-8',
            )
            (carpeta / '02.html').write_text(
                '<html><body><h1>Capítulo Uno</h1><p>Cuerpo.</p></body></html>',
                encoding='utf-8',
            )
            (carpeta / 'template.xhtml').write_text(TEMPLATE, encoding='utf-8')
            (carpeta / 'prologo.xhtml').write_text(PROLOGO, encoding='utf-8')
            resultado = procesar(
                'calibre',
                carpeta,
                carpeta / 'template.xhtml',
                ruta_plantillas=carpeta,
            )
        self.assertEqual(resultado.capitulos[0].archivo, 'prologo.xhtml')
        self.assertEqual(resultado.capitulos[0].plantilla_ruta, carpeta / 'prologo.xhtml')
        self.assertEqual(resultado.capitulos[1].archivo, 'C01.xhtml')
        self.assertEqual(resultado.notas[0].cap_archivo, 'prologo.xhtml')

    def test_numero_de_archivo(self):
        self.assertEqual(numero_de_archivo('C01.xhtml', 7), 1)
        self.assertEqual(numero_de_archivo('C23.xhtml', 7), 23)
        self.assertEqual(numero_de_archivo('prologo.xhtml', 7), 7)
        self.assertEqual(numero_de_archivo(None, 7), 7)

    def test_los_especiales_no_consumen_numero(self):
        with TemporaryDirectory() as tmp:
            carpeta = Path(tmp)
            for nombre, titulo, texto in (
                ('00.html', 'Prólogo', 'Inicio.'),
                ('01.html', 'Capítulo Uno', 'Cuerpo uno.'),
                ('02.html', 'Secreto Oculto 1', 'Interludio.'),
                ('03.html', 'Capítulo Dos', 'Cuerpo dos.'),
            ):
                (carpeta / nombre).write_text(
                    f'<html><body><h1>{titulo}</h1><p>{texto}</p></body></html>',
                    encoding='utf-8',
                )
            plantillas = carpeta / 'plantillas'
            plantillas.mkdir()
            (plantillas / 'template.xhtml').write_text(TEMPLATE, encoding='utf-8')
            (plantillas / 'prologo.xhtml').write_text(PROLOGO, encoding='utf-8')
            resultado = procesar(
                'calibre', carpeta, plantillas / 'template.xhtml',
                ruta_plantillas=plantillas,
            )
        archivos = [c.archivo for c in resultado.capitulos]
        self.assertEqual(
            archivos, ['prologo.xhtml', 'C01.xhtml', 'C02.xhtml', 'C03.xhtml']
        )

    def test_plantilla_especial_faltante_usa_numero_normal(self):
        with TemporaryDirectory() as tmp:
            carpeta = Path(tmp)
            (carpeta / '01.html').write_text(
                '<html><body><h1>Prólogo</h1>'
                '<p>Inicio.</p></body></html>',
                encoding='utf-8',
            )
            (carpeta / 'template.xhtml').write_text(TEMPLATE, encoding='utf-8')
            resultado = procesar(
                'calibre',
                carpeta,
                carpeta / 'template.xhtml',
                ruta_plantillas=carpeta,
            )
        self.assertEqual(resultado.capitulos[0].archivo, 'C01.xhtml')
        self.assertTrue(any('plantilla especial no encontrada' in a for a in resultado.avisos))


if __name__ == '__main__':
    unittest.main()