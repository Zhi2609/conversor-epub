"""Modelo de datos central del motor."""

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Chapter:
    """Un capítulo del libro: título + cuerpo HTML ya limpio.

    archivo: nombre de salida (p.ej. 'prologo.xhtml'); None → C{NN:02d}.xhtml.
    plantilla_ruta: plantilla especial (Prólogo/Epílogo/Palabras del autor)."""

    titulo: str
    html_cuerpo: str
    archivo: str | None = None
    plantilla_ruta: Path | None = None


@dataclass
class Nota:
    """Nota al pie extraída del manuscrito."""

    num: int
    texto: str
    cap_num: int | None = None
    cap_archivo: str | None = None


@dataclass
class Contadores:
    """Estadísticas del libro para el dashboard de la UI."""

    capitulos: int
    notas: int
    imagenes: int
    separadores: int


@dataclass
class Resultado:
    """Salida completa del pipeline: capítulos, notas, estadísticas y avisos."""

    capitulos: list[Chapter]
    notas: list[Nota]
    contadores: Contadores
    avisos: list[str] = field(default_factory=list)