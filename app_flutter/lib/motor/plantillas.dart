final Map<String, String> tablaEspeciales = {
  'prologo': 'prologo.xhtml',
  'epilogo': 'epilogo.xhtml',
  'palabras del autor': 'autor.xhtml',
};

final _reArchivoC = RegExp(r'^C(\d+)\.xhtml$');

int numeroDeArchivo(String? archivo, int porDefecto) {
  if (archivo == null) return porDefecto;
  return int.tryParse(_reArchivoC.firstMatch(archivo)?[1] ?? '') ?? porDefecto;
}

String? clasificarEspecial(String titulo) {
  final normalizado = titulo.toLowerCase().trim().replaceAll('ó', 'o').replaceAll('í', 'i');
  for (var entry in tablaEspeciales.entries) {
    if (normalizado.startsWith(entry.key)) {
      return entry.value;
    }
  }
  return null;
}
