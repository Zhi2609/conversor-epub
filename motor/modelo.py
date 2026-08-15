"""Modelo de datos central del motor."""

from dataclasses import dataclass, field


@dataclass
class Chapter:
    """Un capítulo del libro: título + cuerpo HTML ya limpio."""

    titulo: str
    html_cuerpo: str


@dataclass
class Nota:
    """Nota al pie extraída del manuscrito."""

    num: int
    texto: str
    cap_num: int | None = None


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