import 'modelo.dart';
import 'limpieza.dart' show textoPlano;

final _reEncabezado = RegExp(r'<h([1-3])(?:\s[^>]*)?>(.*?)</h\1>', dotAll: true, caseSensitive: false);
final _reEncabezadoVacio = RegExp(r'<h[1-3](?:\s[^>]*)?>(?:\s|&nbsp;)*</h[1-3]>', caseSensitive: false);

List<Chapter> dividirEnCapitulos(String html, {List<String>? titulos, int startNum = 1}) {
  final matches = _reEncabezado.allMatches(html).where((m) => textoPlano(m.group(2)!).isNotEmpty).toList();

  if (matches.isEmpty) {
    String titulo = (titulos != null && titulos.isNotEmpty) ? titulos[0] : 'Capítulo $startNum';
    return [Chapter(titulo: titulo, htmlCuerpo: html.replaceAll(_reEncabezadoVacio, '').trim())];
  }

  List<Chapter> capitulos = [];
  int contador = startNum;

  String pre = html.substring(0, matches[0].start).replaceAll(_reEncabezadoVacio, '').trim();
  if (pre.isNotEmpty) {
    String titulo = (titulos != null && titulos.isNotEmpty) ? titulos[0] : 'Capítulo $contador';
    capitulos.add(Chapter(titulo: titulo, htmlCuerpo: pre));
    contador++;
  }

  List<int> limites = matches.map((m) => m.start).toList()..add(html.length);
  for (int i = 0; i < matches.length; i++) {
    String subHtml = html.substring(limites[i], limites[i+1]);
    String cuerpo = subHtml.replaceFirst(_reEncabezado, '');
    cuerpo = cuerpo.replaceAll(_reEncabezadoVacio, '').trim();
    String texto = textoPlano(matches[i].group(2)!);
    int indice = contador - startNum;
    String titulo = (titulos != null && indice < titulos.length) ? titulos[indice] : (texto.isNotEmpty ? texto : 'Capítulo $contador');
    capitulos.add(Chapter(titulo: titulo, htmlCuerpo: cuerpo));
    contador++;
  }

  return capitulos;
}
