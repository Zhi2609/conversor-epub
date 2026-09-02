"""Adaptador de entrada: PDF → DOCX → HTML."""

import tempfile
from pathlib import Path

from pdf2docx import Converter
from motor.adaptadores.docx import convertir_docx


def convertir_pdf(ruta_pdf: Path) -> str:
    """Convierte un PDF a HTML usando pdf2docx como puente temporal."""
    with tempfile.NamedTemporaryFile(suffix=".docx", delete=False) as temp_docx:
        temp_path = temp_docx.name
        
    try:
        # Convertimos PDF a DOCX
        cv = Converter(str(ruta_pdf))
        cv.convert(temp_path)
        cv.close()
        
        # Usamos el adaptador existente de Word para obtener el HTML
        html = convertir_docx(Path(temp_path))
        return html
    finally:
        # Limpieza del archivo temporal
        Path(temp_path).unlink(missing_ok=True)
