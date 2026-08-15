"""Tests de los adaptadores de entrada."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from motor.adaptadores import detectar_modo
from motor.adaptadores.calibre import extraer_cuerpo
from motor.adaptadores.markdown import documentos_markdown


class TestDetectarModo(unittest.TestCase):
    def test_archivo_docx(self):
        with TemporaryDirectory() as tmp:
            ruta = Path(tmp) / 'novela.docx'
            ruta.write_bytes(b'x')
            self.assertEqual(detectar_modo(ruta), 'word')

    def test_carpeta_md(self):
        with TemporaryDirectory() as tmp:
            (Path(tmp) / 'C01.md').write_text('x', encoding='utf-8')
            self.assertEqual(detectar_modo(Path(tmp)), 'markdown')

    def test_carpeta_xhtml(self):
        with TemporaryDirectory() as tmp:
            (Path(tmp) / 'C01.xhtml').write_text('x', encoding='utf-8')
            self.assertEqual(detectar_modo(Path(tmp)), 'calibre')

    def test_carpeta_vacia_error(self):
        with TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                detectar_modo(Path(tmp))


class TestAdaptadorCalibre(unittest.TestCase):
    def test_extrae_cuerpo_y_quita_h1(self):
        html = '<html><body><h1>Titulo Uno</h1><p>cuerpo</p></body></html>'
        cuerpo, titulo = extraer_cuerpo(html)
        self.assertEqual(cuerpo, '<p>cuerpo</p>')
        self.assertEqual(titulo, 'Titulo Uno')

    def test_sin_body_error(self):
        with self.assertRaises(ValueError):
            extraer_cuerpo('<html></html>')

    def test_se_quita_solo_el_primer_encabezado(self):
        html = '<html><body><h2>Segunda</h2><h3>tercera</h3></body></html>'
        cuerpo, titulo = extraer_cuerpo(html)
        self.assertEqual(cuerpo, '<h3>tercera</h3>')
        self.assertEqual(titulo, 'Segunda')


class TestAdaptadorMarkdown(unittest.TestCase):
    def test_primer_h1_es_titulo_y_se_elimina(self):
        with TemporaryDirectory() as tmp:
            ruta = Path(tmp) / 'C01.md'
            ruta.write_text('# Capítulo Uno\n\nTexto del capítulo.\n', encoding='utf-8')
            documentos, _avisos = documentos_markdown(Path(tmp))
            html, titulo, imagenes = documentos[0]
            self.assertEqual(titulo, 'Capítulo Uno')
            self.assertNotIn('<h1>', html)
            self.assertIn('<p>Texto del capítulo.</p>', html)
            self.assertEqual(imagenes, [])
            self.assertEqual(len(_avisos), 0)

    def test_md_sin_titulo(self):
        with TemporaryDirectory() as tmp:
            ruta = Path(tmp) / 'C01.md'
            ruta.write_text('Solo texto.\n', encoding='utf-8')
            documentos, avisos = documentos_markdown(Path(tmp))
            html, titulo, imagenes = documentos[0]
            self.assertIsNone(titulo)
            self.assertIn('<p>Solo texto.</p>', html)
            self.assertEqual(len(avisos), 1)
            self.assertIn('sin título', avisos[0])

    def test_negritas_cursivas_y_bold_italic(self):
        html, titulo, imagenes = self._ma(('**negrita** y _cursiva_ y ***ambas***'))
        self.assertIn('<b>negrita</b>', html)
        self.assertIn('<i>cursiva</i>', html)
        self.assertIn('<b><i>ambas</i></b>', html)

    def test_blockquote_mistico(self):
        html, titulo, imagenes = self._ma('[blockquote]\nCita mística.\n[/blockquote]')
        self.assertIn('blockquote class="mistico"', html)

    def test_invisibles_limpiados(self):
        html, titulo, imagenes = self._ma('hola\u200b mundo\u200c')
        self.assertNotIn('\u200b', html)
        self.assertNotIn('\u200c', html)

    def test_imagen_placeholder(self):
        html, titulo, imagenes = self._ma('\\n\n!\\Image03\\')
        self.assertEqual(len(imagenes), 1)
        self.assertIn('\x00IMG_0\x00', html)
        self.assertIn('../Images/03.jpg', imagenes[0])

    def test_parrafos_por_doble_salto(self):
        html, titulo, imagenes = self._ma('Primero.\n\nSegundo.\n')
        self.assertIn('<p>Primero.</p>', html)
        self.assertIn('<p>Segundo.</p>', html)

    def _ma(self, texto):
        with TemporaryDirectory() as tmp:
            ruta = Path(tmp) / 'C01.md'
            ruta.write_text(texto, encoding='utf-8')
            return documentos_markdown(Path(tmp))[0][0]


if __name__ == '__main__':
    unittest.main()