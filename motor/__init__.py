"""Motor unificado: limpieza canónica, adaptadores, split y render."""

import sys
from pathlib import Path

from motor.adaptadores import detectar_modo
from motor.modelo import Chapter, Contadores, Nota, Resultado
from motor.procesar import procesar


def ruta_template_empaquetado(ruta_relativa: str = 'Conv_Xhtml/template.xhtml') -> Path:
    """Ruta del template según esté empaquetado (PyInstaller) o en el repo."""
    if getattr(sys, 'frozen', False):
        return Path(sys._MEIPASS) / ruta_relativa
    return Path(__file__).resolve().parent.parent / ruta_relativa