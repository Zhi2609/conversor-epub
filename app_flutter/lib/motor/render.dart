import 'dart:io';
import 'modelo.dart' show Nota, Chapter;
import 'notas.dart' show formatearNota;
import 'plantillas.dart' show descomponerTitulo;
import 'imagenes.dart' show limpiarHrDuplicados;

final _reMarcadorContenido = RegExp(r'<!--\s*Aquí va el contenido\s*-->(.*?)</section>', dotAll: true, caseSensitive: false);

final _reComentarioFigureConHeader = RegExp(
  r'<!--Si usa figure,.*?'
  r'(<h1 class="oculto".*?</header>)'
  r'\s*-->\s*'
  r'(<header>.*?</header>)',
  dotAll: true,
  caseSensitive: false,
);

final _reCualquierComentarioFigure = RegExp(
  r'<!--Si usa figure,.*?-->\s*',
  dotAll: true,
  caseSensitive: false,
);

String _aplicarCabeceraFigura(String html, bool tituloEsImagen, String? numeroImagenTitulo) {
  if (tituloEsImagen) {
    final numImg = numeroImagenTitulo ?? '02';
    html = html.replaceAllMapped(_reComentarioFigureConHeader, (m) {
      String bloque = m.group(1)!;
      return bloque.replaceAll(RegExp(r'\.\./Images/\d+\.jpg', caseSensitive: false), '../Images/$numImg.jpg');
    });
  } else {
    html = html.replaceAll(_reCualquierComentarioFigure, '');
  }
  return html;
}

String _absorberPrimeraFigura(String cuerpo, bool tituloEsImagen, String? numeroImagenTitulo) {
  if (!tituloEsImagen) return cuerpo;
  final numImg = numeroImagenTitulo ?? r'\d+';
  final rePrimeraFigura = RegExp(
    '^\\s*(?:<hr\\s+class="sigil_split_marker"\\s*/?>\\s*)?'
    '<figure class="dimg"><img\\b[^>]*src="[^"]*?(?:Images/|image0*)$numImg\\.[^"]*"[^>]*></figure>'
    '\\s*(?:<hr\\s+class="sigil_split_marker"\\s*/?>)?',
    caseSensitive: false,
  );
  return cuerpo.replaceFirst(rePrimeraFigura, '');
}

String renderCapitulo(
  String template,
  String titulo,
  int num,
  String cuerpo, {
  bool tituloEsImagen = false,
  String? numeroImagenTitulo,
}) {
  final partes = descomponerTitulo(titulo, numeroPorDefecto: num);
  final tituloCompleto = (partes.subtitulo != null && partes.subtitulo!.isNotEmpty)
      ? '${partes.etiqueta}: ${partes.subtitulo}'
      : partes.etiqueta;

  String html = _aplicarCabeceraFigura(template, tituloEsImagen, numeroImagenTitulo);
  cuerpo = _absorberPrimeraFigura(cuerpo, tituloEsImagen, numeroImagenTitulo);

  html = html.replaceAll('Capítulo X: Título del capítulo', tituloCompleto);
  html = html.replaceAll('Capítulo X', partes.etiqueta);

  if (partes.subtitulo != null && partes.subtitulo!.isNotEmpty) {
    html = html.replaceAll('Título del capítulo', partes.subtitulo!);
  } else {
    html = html.replaceAll(RegExp(r'\s*<br/>\s*<span class="versalita">.*?</span>', dotAll: true), '');
    html = html.replaceAll('Título del capítulo', '');
  }

  html = html.replaceAll('{{CONTENIDO}}', cuerpo.trim());
  return limpiarHrDuplicados(html);
}

String renderCapituloEspecial(
  String template,
  String titulo,
  int num,
  String cuerpo, {
  bool tituloEsImagen = false,
  String? numeroImagenTitulo,
}) {
  final match = _reMarcadorContenido.firstMatch(template);
  if (match == null) {
    throw Exception('La plantilla especial no tiene el marcador <!-- Aquí va el contenido -->');
  }

  final partes = descomponerTitulo(titulo, numeroPorDefecto: num);
  final tituloCompleto = (partes.subtitulo != null && partes.subtitulo!.isNotEmpty)
      ? '${partes.etiqueta}: ${partes.subtitulo}'
      : partes.etiqueta;

  String html = _aplicarCabeceraFigura(template, tituloEsImagen, numeroImagenTitulo);
  cuerpo = _absorberPrimeraFigura(cuerpo, tituloEsImagen, numeroImagenTitulo);

  final matchActualizado = _reMarcadorContenido.firstMatch(html) ?? match;
  html = html.replaceRange(
    matchActualizado.start,
    matchActualizado.end,
    '<!-- Aquí va el contenido -->\n${cuerpo.trim()}\n  </section>',
  );

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
  } else if (partes.esTraductor) {
    html = html.replaceAll('<h1>Palabras del traductor</h1>', '<h1>${partes.etiqueta}</h1>');
    html = html.replaceAll('<title>Palabras del traductor</title>', '<title>${partes.etiqueta}</title>');
    html = html.replaceAll('Palabras del traductor: Título del capítulo', tituloCompleto);
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

String renderTablaContenidos(List<Chapter> capitulos, List<String> titulos) {
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('');
  buffer.writeln('<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="es" xml:lang="es">');
  buffer.writeln('<head>');
  buffer.writeln('  <title>Contenido</title>');
  buffer.writeln('  <link rel="stylesheet" type="text/css" href="../Styles/style.css"/>');
  buffer.writeln('  ');
  buffer.writeln('</head>');
  buffer.writeln('');
  buffer.writeln('<body xml:lang="es" lang="es" epub:type="frontmatter">');
  buffer.writeln('<section epub:type="toc" role="doc-toc" id="toc" aria-label="Contenido">');
  buffer.writeln('  <h1 class="oculto sigil_not_in_toc" title="Contenido"></h1>');

  for (int i = 0; i < capitulos.length; i++) {
    final archivo = capitulos[i].archivo ?? 'C${(i + 1).toString().padLeft(2, '0')}.xhtml';
    final titulo = (i < titulos.length && titulos[i].trim().isNotEmpty)
        ? titulos[i].trim()
        : capitulos[i].titulo;
    buffer.writeln('    <div class="nivel-1">');
    buffer.writeln('      <a href="$archivo">$titulo</a>');
    buffer.writeln('    </div>');
  }

  buffer.writeln('  </section>');
  buffer.writeln('</body>');
  buffer.writeln('</html>');
  return buffer.toString();
}
