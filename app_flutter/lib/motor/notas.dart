import 'modelo.dart';
import 'limpieza.dart';

final _reSeccionNotas = RegExp(
  r'<(section|div)\b[^>]*(?:id|class)="footnotes?"[^>]*>(.*?)</\1>',
  dotAll: true, caseSensitive: false,
);
final _reItemNota = RegExp(
  r'<li\b[^>]*id="fn(\d+)"[^>]*>(.*?)</li>',
  dotAll: true, caseSensitive: false,
);
final _reVinculoNotaPandoc = RegExp(
  r'<a\b[^>]*href="#fn(\d+)"[^>]*>.*?</a>',
  dotAll: true,
);
final _reVinculoRegreso = RegExp(
  r'<a\b[^>]*href="#fnref[^"]*"[^>]*>.*?</a>',
  dotAll: true,
);
final _reNotaLegacy = RegExp(r'\(NT(\d+)\)');
final _reNotaMdDef = RegExp(r'<p>\s*\[\^(\d+)\]:\s*(.*?)</p>', dotAll: true);
final _reNotaMdLlamada = RegExp(r'\[\^(\d+)\]');
final _reAnclaRegreso = RegExp(r'↩︎?');
final _reImg = RegExp(r'<img\b[^>]*?/?>', dotAll: true, caseSensitive: false);

const archivoNotas = 'notas_Finales.xhtml';

String formatearLlamada(int num) {
  String numFmt = num.toString().padLeft(2, '0');
  return '<a href="$archivoNotas#nt$numFmt" id="rf$numFmt">'
         '<sup>❮$numFmt❯</sup></a>';
}

String _reemplazarNotasLegacy(String html) {
  return html.replaceAllMapped(_reNotaLegacy, (m) => formatearLlamada(int.parse(m[1]!)));
}

String _procesarNotasMarkdown(String html, List<Nota> notas) {
  for (final m in _reNotaMdDef.allMatches(html)) {
    notas.add(Nota(
      num: int.parse(m[1]!),
      texto: limpiarTextoHtml(m[2]!.trim()),
    ));
  }
  html = html.replaceAll(_reNotaMdDef, '');
  return html.replaceAllMapped(_reNotaMdLlamada, (m) => formatearLlamada(int.parse(m[1]!)));
}

class ExtraerNotasResult {
  final String html;
  final List<Nota> notas;
  ExtraerNotasResult(this.html, this.notas);
}

ExtraerNotasResult extraerNotas(String html) {
  List<Nota> notas = [];
  final match = _reSeccionNotas.firstMatch(html);
  
  if (match != null) {
    String contenidoRaw = match.group(2)!;
    html = html.substring(0, match.start) + html.substring(match.end);

    for (final m in _reItemNota.allMatches(contenidoRaw)) {
      int num = int.parse(m[1]!);
      String htmlNota = m[2]!;
      htmlNota = htmlNota.replaceAll(_reVinculoRegreso, '');
      htmlNota = htmlNota.replaceAll(_reAnclaRegreso, '');
      htmlNota = htmlNota.trim().replaceAll(RegExp(r'^<p>'), '').replaceAll(RegExp(r'</p>$'), '');
      htmlNota = limpiarTextoHtml(htmlNota.trim());
      notas.add(Nota(num: num, texto: htmlNota));
    }

    html = html.replaceAllMapped(_reVinculoNotaPandoc, (m) => formatearLlamada(int.parse(m[1]!)));
  }

  html = _procesarNotasMarkdown(html, notas);
  html = _reemplazarNotasLegacy(html);
  return ExtraerNotasResult(html, notas);
}

void asignarCapitulos(List<Nota> notas, List<Chapter> capitulos, {int startNum = 1}) {
  for (var nota in notas) {
    String referencia = 'id="rf${nota.num.toString().padLeft(2, '0')}"';
    bool encontrada = false;
    
    for (int i = 0; i < capitulos.length; i++) {
      int num = startNum + i;
      if (capitulos[i].htmlCuerpo.contains(referencia)) {
        nota.capNum = num;
        nota.capArchivo = capitulos[i].archivo ?? 'C${num.toString().padLeft(2, '0')}.xhtml';
        encontrada = true;
        break;
      }
    }
    
    if (!encontrada) {
      nota.capNum = startNum;
      nota.capArchivo = 'C${startNum.toString().padLeft(2, '0')}.xhtml';
    }
  }
}

String _textoConImagenes(String texto, int num) {
  final numeros = _reImg.allMatches(texto).toList();
  if (numeros.isEmpty) return texto;

  List<String> partes = [];
  int posicion = 0;
  
  for (int i = 0; i < numeros.length; i++) {
    int indice = i + 1;
    final match = numeros[i];
    String sufijo = indice > 1 ? '-$indice' : '';
    String fragmento = texto.substring(posicion, match.start).trim();
    
    if (fragmento.isNotEmpty && partes.isNotEmpty) partes.add('<br/><br/>');
    if (fragmento.isNotEmpty) partes.add(fragmento);
    
    partes.add('<img src="../Images/nota-${num.toString().padLeft(2, '0')}$sufijo.jpg" alt=""/>');
    posicion = match.end;
  }

  String resto = texto.substring(posicion).trim();
  if (resto.isNotEmpty) {
    partes.add('<br/><br/>');
    partes.add(resto);
  }
  return partes.join(' ');
}

String formatearNota(Nota nota) {
  String numFmt = nota.num.toString().padLeft(2, '0');
  String archivo = nota.capArchivo ?? 'C${(nota.capNum ?? 1).toString().padLeft(2, '0')}.xhtml';
  String texto = _textoConImagenes(nota.texto, nota.num);
  
  String div = '<div class="nota">\n'
               ' <p id="nt$numFmt">\n'
               '   <a href="$archivo#rf$numFmt"><sup>❮$numFmt❯</sup> $texto</a>\n'
               ' </p>\n'
               '</div>';
               
  if (texto.contains('<img')) {
    return '<hr class="sigil_split_marker" />\n$div\n<hr class="sigil_split_marker" />';
  }
  return div;
}
