import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class AjustesApp {
  static File get _archivoConfig {
    final home = Platform.environment['HOME'] ?? '.';
    return File(p.join(home, '.config', 'conversor-epub', 'config.json'));
  }

  static String obtenerRutaBaseEpub() {
    try {
      final f = _archivoConfig;
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync());
        if (data is Map && data['rutaBaseEpub'] is String) {
          final ruta = data['rutaBaseEpub'] as String;
          if (File(ruta).existsSync()) return ruta;
        }
      }
    } catch (_) {}

    final candidatos = [
      p.join(Directory.current.path, 'Base3_v1.16.0.epub'),
      p.join(Directory.current.parent.path, 'Base3_v1.16.0.epub'),
      p.join(Directory.current.path, 'assets', 'Base3_v1.16.0.epub'),
      p.join(Directory.current.parent.path, 'assets', 'Base3_v1.16.0.epub'),
      p.join(Directory.current.path, 'Base3_v1.15.0.epub'),
      p.join(Directory.current.parent.path, 'Base3_v1.15.0.epub'),
      p.join(Directory.current.path, 'assets', 'Base3_v1.15.0.epub'),
      p.join(Directory.current.parent.path, 'assets', 'Base3_v1.15.0.epub'),
    ];

    for (final c in candidatos) {
      if (File(c).existsSync()) return File(c).absolute.path;
    }
    return '';
  }

  static void guardarRutaBaseEpub(String ruta) {
    try {
      final f = _archivoConfig;
      f.parent.createSync(recursive: true);
      Map<String, dynamic> data = {};
      if (f.existsSync()) {
        try {
          final parsed = jsonDecode(f.readAsStringSync());
          if (parsed is Map<String, dynamic>) data = parsed;
        } catch (_) {}
      }
      data['rutaBaseEpub'] = ruta;
      f.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }
}
