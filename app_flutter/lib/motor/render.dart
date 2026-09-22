import 'dart:io';
import 'modelo.dart' show Nota;
import 'notas.dart' show formatearNota;

final _reMarcadorContenido = RegExp(r'<!--\s*Aquí va el contenido\s*-->(.*?)</section>', dotAll: true, caseSensitive: false);

String renderCapitulo(String template, String titulo, int num, String cuerpo) {
  String html = template.replaceAll('Capítulo X', 'Capítulo $num');
  html = html.replaceAll('Título del capítulo', titulo);
  return html.replaceAll('{{CONTENIDO}}', cuerpo.trim());
}

String renderCapituloEspecial(String template, String titulo, int num, String cuerpo) {
  final match = _reMarcadorContenido.firstMatch(template);
  if (match == null) {
    throw Exception('La plantilla especial no tiene el marcador <!-- Aquí va el contenido -->');
  }
  
  String html = template.substring(0, match.start) +
                '<!-- Aquí va el contenido -->\n' +
                cuerpo.trim() +
                template.substring(match.end);
                
  html = html.replaceAll('Capítulo X', 'Capítulo $num');
  return html.replaceAll('Título del capítulo', titulo);
}

String renderNotas(List<Nota> notas) {
  return notas.map((n) => formatearNota(n)).join('\n');
}

void limpiarCarpeta(String ruta) {
  final dir = Directory(ruta);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
  dir.createSync(recursive: true);
}
