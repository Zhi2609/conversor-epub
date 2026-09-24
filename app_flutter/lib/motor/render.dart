import 'dart:io';
import 'modelo.dart' show Nota;
import 'notas.dart' show formatearNota;
import 'plantillas.dart' show descomponerTitulo;

final _reMarcadorContenido = RegExp(r'<!--\s*Aquí va el contenido\s*-->(.*?)</section>', dotAll: true, caseSensitive: false);

String renderCapitulo(String template, String titulo, int num, String cuerpo) {
  final partes = descomponerTitulo(titulo, numeroPorDefecto: num);
  final tituloCompleto = (partes.subtitulo != null && partes.subtitulo!.isNotEmpty)
      ? '${partes.etiqueta}: ${partes.subtitulo}'
      : partes.etiqueta;

  String html = template;
  html = html.replaceAll('Capítulo X: Título del capítulo', tituloCompleto);
  html = html.replaceAll('Capítulo X', partes.etiqueta);

  if (partes.subtitulo != null && partes.subtitulo!.isNotEmpty) {
    html = html.replaceAll('Título del capítulo', partes.subtitulo!);
  } else {
    html = html.replaceAll(RegExp(r'\s*<br/>\s*<span class="versalita">.*?</span>', dotAll: true), '');
    html = html.replaceAll('Título del capítulo', '');
  }

  return html.replaceAll('{{CONTENIDO}}', cuerpo.trim());
}

String renderCapituloEspecial(String template, String titulo, int num, String cuerpo) {
  final match = _reMarcadorContenido.firstMatch(template);
  if (match == null) {
    throw Exception('La plantilla especial no tiene el marcador <!-- Aquí va el contenido -->');
  }

  final partes = descomponerTitulo(titulo, numeroPorDefecto: num);
  final tituloCompleto = (partes.subtitulo != null && partes.subtitulo!.isNotEmpty)
      ? '${partes.etiqueta}: ${partes.subtitulo}'
      : partes.etiqueta;

  String html = template.replaceRange(match.start, match.end, '<!-- Aquí va el contenido -->\n${cuerpo.trim()}');

  if (partes.esPrologo) {
    html = html.replaceAll('Prólogo: Título del capítulo', tituloCompleto);
    html = html.replaceAll('<i>Prólogo</i>', '<i>${partes.etiqueta}</i>');
    html = html.replaceAll('<title>Prólogo</title>', '<title>${partes.etiqueta}</title>');
    if (partes.subtitulo != null && partes.subtitulo!.isNotEmpty) {
      html = html.replaceAll('Título del capítulo', partes.subtitulo!);
    } else {
      html = html.replaceAll(RegExp(r'\s*<br/>\s*<span class="versalita">.*?</span>', dotAll: true), '');
      html = html.replaceAll('Título del capítulo', '');
    }
  } else if (partes.esEpilogo) {
    html = html.replaceAll('Epílogo: Título del capítulo', tituloCompleto);
    html = html.replaceAll('<i>Epílogo</i>', '<i>${partes.etiqueta}</i>');
    html = html.replaceAll('<title>Epílogo</title>', '<title>${partes.etiqueta}</title>');
    if (partes.subtitulo != null && partes.subtitulo!.isNotEmpty) {
      html = html.replaceAll('Título del capítulo', partes.subtitulo!);
    } else {
      html = html.replaceAll(RegExp(r'\s*<br/>\s*<span class="versalita">.*?</span>', dotAll: true), '');
      html = html.replaceAll('Título del capítulo', '');
    }
  } else if (partes.esAutor) {
    html = html.replaceAll('<h1>Palabras del autor</h1>', '<h1>${partes.etiqueta}</h1>');
    html = html.replaceAll('<title>Palabras finales</title>', '<title>${partes.etiqueta}</title>');
    html = html.replaceAll('Palabras del autor: Título del capítulo', tituloCompleto);
    html = html.replaceAll('Título del capítulo', partes.subtitulo ?? '');
  } else {
    html = html.replaceAll('Capítulo X', partes.etiqueta);
    html = html.replaceAll('Título del capítulo', partes.subtitulo ?? titulo);
  }

  return html;
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
