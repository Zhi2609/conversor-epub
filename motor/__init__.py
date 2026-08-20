"""Motor unificado: limpieza canónica, adaptadores, split y render."""

import sys
from pathlib import Path

from motor.adaptadores import detectar_modo
from motor.modelo import Chapter, Contadores, Nota, Resultado
from motor.procesar import procesar


def ruta_template_empaquetado(ruta_relativa: str = 'assets/Conv_Xhtml/template.xhtml') -> Path:
    """Ruta del template según esté empaquetado (PyInstaller) o en el repo."""
    if getattr(sys, 'frozen', False):
        return Path(sys._MEIPASS) / ruta_relativa
    return Path(__file__).resolve().parent.parent / ruta_relativa


def ruta_plantillas_empaquetado(ruta_relativa: str = 'assets/Plantillas') -> Path:
    """Ruta de la carpeta de plantillas especiales (§5.8), empaquetada o del repo."""
    if getattr(sys, 'frozen', False):
        return Path(sys._MEIPASS) / ruta_relativa
    return Path(__file__).resolve().parent.parent / ruta_relativa