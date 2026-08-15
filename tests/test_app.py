"""Tests de humo de la GUI (Fase 2) en modo offscreen."""

import os
import unittest
from pathlib import Path

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')

from PySide6.QtWidgets import QApplication, QTableWidgetItem

from app.app import VentanaPrincipal

RUTA_TESTS = Path(__file__).resolve().parent
RUTA_ENTRADA_MD = RUTA_TESTS / 'golden' / 'entrada_md'


class TestVentana(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def test_se_crea_la_ventana(self):
        ventana = VentanaPrincipal()
        self.assertIsNotNone(ventana.windowTitle())
        ventana.close()

    def test_carga_carpeta_md(self):
        ventana = VentanaPrincipal()
        ventana._aceptar_entrada(RUTA_ENTRADA_MD)
        self.assertEqual(ventana._resultado.contadores.capitulos, 2)
        self.assertEqual(ventana.tabla.rowCount(), 2)
        self.assertEqual(ventana.selector_capitulo.count(), 2)
        self.assertTrue(ventana.boton_generar.isEnabled())
        ventana.close()

    def test_validacion_de_conteo(self):
        ventana = VentanaPrincipal()
        ventana._aceptar_entrada(RUTA_ENTRADA_MD)
        ventana.tabla.selectRow(0)
        ventana._quitar_fila()
        self.assertFalse(ventana.boton_generar.isEnabled())
        self.assertIn('1/2', ventana.etiqueta_validacion.text())
        ventana._anadir_fila()
        ventana.tabla.setItem(ventana.tabla.rowCount() - 1, 1, QTableWidgetItem('Capítulo nuevo'))
        self.assertTrue(ventana.boton_generar.isEnabled())
        ventana.close()

    def test_diff_se_rellena(self):
        ventana = VentanaPrincipal()
        ventana._aceptar_entrada(RUTA_ENTRADA_MD)
        self.assertNotEqual(ventana.original.toPlainText(), '')
        self.assertIn('<p', ventana.limpio.toHtml())
        ventana.close()


if __name__ == '__main__':
    unittest.main()