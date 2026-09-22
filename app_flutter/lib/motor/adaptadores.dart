import 'dart:io';
import 'package:path/path.dart' as p;
import 'limpieza.dart' show textoPlano;

final _reBody = RegExp(r'<body[^>]*>(.*?)</body>', dotAll: true, caseSensitive: false);
final _reTituloCalibre = RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', dotAll: true, caseSensitive: false);
final _reInvisibles = RegExp(r'[\u200B-\u200D\uFEFF]');
final _reImagen = RegExp(r'!\\Image(\d*)\\');
final _reH1Principal = RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true, caseSensitive: false);

class AdaptadorResult {
  final String html;
  final String? titulo;
  final List<String> imagenesPlaceholder;
  
  AdaptadorResult(this.html, this.titulo, this.imagenesPlaceholder);
}

class DocumentosResult {
  final List<AdaptadorResult> documentos;
  final List<String> avisos;
  
  DocumentosResult(this.documentos, this.avisos);
}

int _numKey(File file) {
  final matches = RegExp(r'\d+').allMatches(p.basenameWithoutExtension(file.path));
  if (matches.isEmpty) return 0;
  return int.parse(matches.last.group(0)!);
}

List<File> _ordenarArchivos(List<File> archivos) {
  archivos.sort((a, b) => _numKey(a).compareTo(_numKey(b)));
  return archivos;
}

Future<String> convertirDocx(String rutaDocx) async {
  final result = await Process.run('pandoc', [rutaDocx, '-t', 'html5', '--wrap=none']);
  if (result.exitCode != 0) {
    throw Exception('Error al ejecutar pandoc: ${result.stderr}');
  }
  return result.stdout.toString();
}

Future<String> convertirPdf(String rutaPdf) async {
  final result = await Process.run('python3', ['../convertidor_pdf.py', rutaPdf, 'temp.docx']);
  if (result.exitCode != 0) {
    throw Exception('Error al convertir PDF: ${result.stderr}');
  }
  final html = await convertirDocx('temp.docx');
  File('temp.docx').deleteSync();
  return html;
}

String detectarModo(String ruta) {
  bool isFile = FileSystemEntity.isFileSync(ruta);
  if (isFile) {
    String sufijo = p.extension(ruta).toLowerCase();
    if (sufijo == '.docx') return 'word';
    if (sufijo == '.pdf') return 'pdf';
    if (sufijo == '.md') return 'markdown';
    if (sufijo == '.xhtml' || sufijo == '.html') return 'calibre';
    throw Exception('No se reconoce el tipo de entrada: $ruta');
  }

  final dir = Directory(ruta);
  final archivos = dir.listSync();
  if (archivos.any((f) => f.path.toLowerCase().endsWith('.md'))) return 'markdown';
  if (archivos.any((f) => f.path.toLowerCase().endsWith('.xhtml') || f.path.toLowerCase().endsWith('.html'))) return 'calibre';
  
  throw Exception('No se encontraron archivos compatibles en $ruta');
}

DocumentosResult documentosCalibre(String ruta) {
  List<File> archivos = [];
  if (FileSystemEntity.isDirectorySync(ruta)) {
    final dir = Directory(ruta);
    final allFiles = dir.listSync().whereType<File>().toList();
    archivos = allFiles.where((f) => f.path.endsWith('.xhtml') || f.path.endsWith('.html')).toList();
    archivos = _ordenarArchivos(archivos);
  } else {
    archivos = [File(ruta)];
  }

  if (archivos.isEmpty) throw Exception('No se encontraron archivos en $ruta');

  List<AdaptadorResult> docs = [];
  List<String> avisos = [];

  for (var file in archivos) {
    String html = file.readAsStringSync();
    final matchBody = _reBody.firstMatch(html);
    if (matchBody == null) {
      avisos.add('${p.basename(file.path)}: sin <body>, omitido');
      continue;
    }
    String cuerpo = matchBody.group(1)!;
    String? titulo;
    
    final matchTitulo = _reTituloCalibre.firstMatch(cuerpo);
    if (matchTitulo != null) {
      titulo = textoPlano(matchTitulo.group(1)!);
      cuerpo = cuerpo.substring(0, matchTitulo.start) + cuerpo.substring(matchTitulo.end);
    }
    docs.add(AdaptadorResult(cuerpo, titulo, []));
  }
  return DocumentosResult(docs, avisos);
}

Future<DocumentosResult> documentosMarkdown(String ruta) async {
  List<File> archivos = [];
  if (FileSystemEntity.isDirectorySync(ruta)) {
    final dir = Directory(ruta);
    archivos = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
    archivos = _ordenarArchivos(archivos);
  } else {
    archivos = [File(ruta)];
  }

  if (archivos.isEmpty) throw Exception('No se encontraron archivos .md en $ruta');

  List<AdaptadorResult> docs = [];
  List<String> avisos = [];

  for (var file in archivos) {
    String texto = file.readAsStringSync();
    texto = texto.replaceAll(_reInvisibles, ' ');
    
    List<String> imagenes = [];
    texto = texto.replaceAllMapped(_reImagen, (m) {
      String num = m.group(1)!;
      String nombre = num.isNotEmpty ? '${num.padLeft(2, '0')}.jpg' : '';
      String html = '<hr class="sigil_split_marker" />\n'
                    '    <figure class="dimg"><img src="../Images/$nombre" alt="" /></figure>\n'
                    '    <hr class="sigil_split_marker" />';
      int indice = imagenes.length;
      imagenes.add(html);
      return '\x00IMG_$indice\x00';
    });

    texto = texto.replaceAll('[blockquote]', '<blockquote class="mistico">')
                 .replaceAll('[/blockquote]', '</blockquote>');

    final tempFile = File('temp_md.md');
    tempFile.writeAsStringSync(texto);
    final result = await Process.run('pandoc', ['temp_md.md', '-t', 'html5', '--wrap=none']);
    tempFile.deleteSync();
    if (result.exitCode != 0) {
      throw Exception('Error en pandoc para ${file.path}: ${result.stderr}');
    }
    String html = result.stdout.toString();

    String? titulo;
    final matchTitulo = _reH1Principal.firstMatch(html);
    if (matchTitulo != null) {
      titulo = textoPlano(matchTitulo.group(1)!);
      html = html.substring(matchTitulo.end).trim();
    } else {
      avisos.add('${p.basename(file.path)}: sin título detectado');
    }

    docs.add(AdaptadorResult(html, titulo, imagenes));
  }
  return DocumentosResult(docs, avisos);
}

String restaurarImagenesMarkdown(String texto, List<String> imagenes) {
  for (int i = 0; i < imagenes.length; i++) {
    texto = texto.replaceAll('\x00IMG_$i\x00', imagenes[i]);
  }
  return texto;
}
