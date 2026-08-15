"""Adaptador de entrada: DOCX → HTML con pandoc."""

import shutil
import subprocess
from pathlib import Path


def convertir_docx(ruta_docx: Path) -> str:
    """Convierte un .docx a HTML5 con pandoc y devuelve el HTML completo."""
    if shutil.which('pandoc') is None:
        raise RuntimeError('pandoc no está instalado o no está en el PATH')

    resultado = subprocess.run(
        ['pandoc', str(ruta_docx), '-t', 'html5', '--wrap=none'],
        capture_output=True,
        text=True,
        check=True,
    )
    return resultado.stdout