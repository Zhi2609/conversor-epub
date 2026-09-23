import 'dart:io';
import 'package:path/path.dart' as p;
import 'limpieza.dart' show textoPlano;

final _reBody = RegExp(r'<body[^>]*>(.*?)</body>', dotAll: true, caseSensitive: false);
final _reTituloCalibre = RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', dotAll: true, caseSensitive: false);
final _reInvisibles = RegExp(r'[\u200B-\u200D\uFEFF]');
final _reImagen = RegExp(r'!\\Image(\d*)\\');
final _reH1Principal = RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true, caseSensitive: false);

typedef AdaptadorResult = ({String html, String? titulo, List<String> imagenesPlaceholder});
typedef DocumentosResult = ({List<AdaptadorResult> documentos, List<String> avisos});

int _numKey(File file) {
  final matches = RegExp(r'\d+').allMatches(p.basenameWithoutExtension(file.path));
  return matches.isEmpty ? 0 : int.parse(matches.last.group(0)!);
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

const _scriptPythonPdf = '''
import sys
from pdf2docx import Converter

def convertir(ruta_pdf: str, ruta_salida_docx: str):
    cv = Converter(ruta_pdf)
    cv.convert(ruta_salida_docx)
    cv.close()

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(1)
    try:
        convertir(sys.argv[1], sys.argv[2])
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
''';

Future<String> convertirPdf(String rutaPdf) async {
  final tempDocx = p.join(Directory.systemTemp.path, 'temp_pdf_${DateTime.now().millisecondsSinceEpoch}.docx');
  final pythonCmd = Platform.isWindows ? 'python' : 'python3';
  final result = await Process.run(pythonCmd, ['-c', _scriptPythonPdf, rutaPdf, tempDocx]);
  if (result.exitCode != 0) {
    throw Exception('Error al convertir PDF: ${result.stderr}');
  }
  final html = await convertirDocx(tempDocx);
  final tempFile = File(tempDocx);
  if (tempFile.existsSync()) {
    tempFile.deleteSync();
  }
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
    docs.add((html: cuerpo, titulo: titulo, imagenesPlaceholder: <String>[]));
  }
  return (documentos: docs, avisos: avisos);
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

    final tempMdPath = p.join(Directory.systemTemp.path, 'temp_md_${DateTime.now().millisecondsSinceEpoch}.md');
    final tempFile = File(tempMdPath);
    tempFile.writeAsStringSync(texto);
    final result = await Process.run('pandoc', [tempMdPath, '-t', 'html5', '--wrap=none']);
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
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

    docs.add((html: html, titulo: titulo, imagenesPlaceholder: imagenes));
  }
  return (documentos: docs, avisos: avisos);
}

String restaurarImagenesMarkdown(String texto, List<String> imagenes) {
  for (int i = 0; i < imagenes.length; i++) {
    texto = texto.replaceAll('\x00IMG_$i\x00', imagenes[i]);
  }
  return texto;
}
