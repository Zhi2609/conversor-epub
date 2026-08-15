"""Tests E2E: pipeline completo contra salidas golden (D7)."""

import shutil
import unittest
from pathlib import Path

from motor import procesar
from motor.render import render_capitulo, render_notas

RUTA_TESTS = Path(__file__).resolve().parent
RUTA_GOLDEN = RUTA_TESTS / 'golden'
RUTA_RAIZ = RUTA_TESTS.parent
RUTA_TEMPLATE = RUTA_RAIZ / 'Conv_Xhtml' / 'template.xhtml'


class TestE2EMarkdown(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resultado = procesar(
            'markdown', RUTA_GOLDEN / 'entrada_md', RUTA_TEMPLATE
        )
        cls.renders = [
            render_capitulo(
                RUTA_TEMPLATE.read_text(encoding='utf-8'),
                cap.titulo,
                num,
                cap.html_cuerpo,
            )
            for num, cap in enumerate(cls.resultado.capitulos, start=1)
        ]

    def test_golden_c01(self):
        esperado = (RUTA_GOLDEN / 'salida_md' / 'C01.xhtml').read_text(encoding='utf-8')
        self.assertEqual(self.renders[0], esperado)

    def test_golden_c02(self):
        esperado = (RUTA_GOLDEN / 'salida_md' / 'C02.xhtml').read_text(encoding='utf-8')
        self.assertEqual(self.renders[1], esperado)

    def test_contadores(self):
        contadores = self.resultado.contadores
        self.assertEqual(contadores.capitulos, 2)
        self.assertEqual(contadores.notas, 0)
        self.assertEqual(contadores.imagenes, 1)
        self.assertEqual(contadores.separadores, 1)

    def test_titulos_detectados(self):
        self.assertEqual(
            [c.titulo for c in self.resultado.capitulos],
            ['Capítulo 1: El Puerto', 'Capítulo 2: Despedida'],
        )


class TestE2ECalibre(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resultado = procesar(
            'calibre', RUTA_GOLDEN / 'entrada_calibre', RUTA_TEMPLATE
        )
        cls.renders = [
            render_capitulo(
                RUTA_TEMPLATE.read_text(encoding='utf-8'),
                cap.titulo,
                num,
                cap.html_cuerpo,
            )
            for num, cap in enumerate(cls.resultado.capitulos, start=1)
        ]

    def test_golden_c01(self):
        esperado = (RUTA_GOLDEN / 'salida_calibre' / 'C01.xhtml').read_text(encoding='utf-8')
        self.assertEqual(self.renders[0], esperado)

    def test_golden_c02(self):
        esperado = (RUTA_GOLDEN / 'salida_calibre' / 'C02.xhtml').read_text(encoding='utf-8')
        self.assertEqual(self.renders[1], esperado)

    def test_titulos_detectados(self):
        self.assertEqual(
            [c.titulo for c in self.resultado.capitulos],
            ['Capítulo Uno', 'Segunda parte'],
        )


class TestAvisos(unittest.TestCase):
    def test_calibre_omite_archivo_sin_body(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            carpeta = Path(tmp)
            (carpeta / '01.xhtml').write_text(
                '<html><body><h1>Título</h1><p>ok</p></body></html>', encoding='utf-8'
            )
            (carpeta / '02.xhtml').write_text('<html><head></head></html>', encoding='utf-8')
            resultado = procesar('calibre', carpeta, RUTA_TEMPLATE)
            self.assertEqual(len(resultado.capitulos), 1)
            self.assertEqual(resultado.capitulos[0].titulo, 'Título')
            self.assertEqual(len(resultado.avisos), 1)
            self.assertIn('sin <body>', resultado.avisos[0])

    def test_md_sin_titulo_genera_aviso(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            carpeta = Path(tmp)
            (carpeta / 'C01.md').write_text('Solo texto sin encabezado.\n', encoding='utf-8')
            resultado = procesar('markdown', carpeta, RUTA_TEMPLATE)
            self.assertEqual(len(resultado.capitulos), 1)
            self.assertEqual(resultado.capitulos[0].titulo, 'Capítulo 1')
            self.assertEqual(len(resultado.avisos), 1)
            self.assertIn('sin título', resultado.avisos[0])


@unittest.skipUnless(shutil.which('pandoc'), 'pandoc no está instalado')
class TestE2EWord(unittest.TestCase):
    def test_docx_con_notas(self):
        import subprocess
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ruta_md = tmp / 'entrada.md'
            ruta_md.write_text(
                '# Capítulo de Prueba\n\n'
                'Texto con nota[^1] y más texto.\n\n'
                '[^1]: Nota de ejemplo.\n',
                encoding='utf-8',
            )
            ruta_docx = tmp / 'entrada.docx'
            subprocess.run(
                ['pandoc', str(ruta_md), '-o', str(ruta_docx)], check=True
            )
            resultado = procesar('word', ruta_docx, RUTA_TEMPLATE)
            self.assertEqual(len(resultado.capitulos), 1)
            self.assertEqual(resultado.capitulos[0].titulo, 'Capítulo de Prueba')
            self.assertEqual(resultado.contadores.notas, 1)
            render = render_notas(resultado.notas)
            self.assertIn('<div class="nota">', render)
            self.assertIn('Nota de ejemplo', render)

    def test_error_si_pandoc_ausente_no_aplica(self):
        pass


if __name__ == '__main__':
    unittest.main()