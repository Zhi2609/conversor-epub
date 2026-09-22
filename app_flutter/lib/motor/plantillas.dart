final Map<String, String> tablaEspeciales = {
  'prologo': 'prologo.xhtml',
  'epilogo': 'epilogo.xhtml',
  'palabras del autor': 'autor.xhtml',
};

final _reArchivoC = RegExp(r'^C(\d+)\.xhtml$');

int numeroDeArchivo(String? archivo, int porDefecto) {
  if (archivo != null) {
    final match = _reArchivoC.firstMatch(archivo);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
  }
  return porDefecto;
}

String _removerTildes(String texto) {
  // Simple accent removal for the specific keys
  return texto.replaceAll('ó', 'o').replaceAll('í', 'i');
}

String _normalizarTitulo(String titulo) {
  String texto = _removerTildes(titulo.toLowerCase().trim());
  return texto;
}

String? clasificarEspecial(String titulo) {
  String normalizado = _normalizarTitulo(titulo);
  for (var entry in tablaEspeciales.entries) {
    if (normalizado.startsWith(entry.key)) {
      return entry.value;
    }
  }
  return null;
}
