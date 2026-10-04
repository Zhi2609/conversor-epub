import 'modelo.dart';
import 'limpieza.dart' show textoPlano;
import 'plantillas.dart' show detectarTipoEspecial;

final _reEncabezado = RegExp(r'<h([1-3])(?:\s[^>]*)?>(.*?)</h\1>', dotAll: true, caseSensitive: false);
final _reEncabezadoVacio = RegExp(r'<h[1-3](?:\s[^>]*)?>(?:\s|&nbsp;)*</h[1-3]>', caseSensitive: false);
final _reParrafo = RegExp(r'<p(?:\s[^>]*)?>(.*?)</p>', dotAll: true, caseSensitive: false);

final _rePalabrasTitulo = RegExp(
  r'^\s*(?:[|｜\[(【<#]*\s*)?'
  r'(pr[oó]logo|ep[ií]logo|interludio|cap[ií]tulo|especial(?:\s+extra)?|extra|historia\s+extra|palabras\s+del?\s+(?:autor|traductor)|palabras\s+finales|nota[s]?\s+del?\s+(?:autor|traductor)|postfacio|prefacio|introducci[oó]n)'
  r'\b',
  caseSensitive: false,
);

final _reTituloConBarra = RegExp(
  r'^\s*[^|｜\n]{1,60}\s*[|｜]\s*[^|｜\n]{1,120}\s*$',
);

bool _pareceTitulo(String texto) {
  final t = texto.trim();
  if (t.isEmpty || t.length > 180) return false;
  if (_rePalabrasTitulo.hasMatch(t)) return true;
  if (detectarTipoEspecial(t) != null) return true;
  if (_reTituloConBarra.hasMatch(t)) return true;
  return false;
}

List<Chapter> dividirEnCapitulos(String html, {List<String>? titulos, int startNum = 1}) {
  final matches = _reEncabezado.allMatches(html).where((m) => textoPlano(m.group(2)!).isNotEmpty).toList();

  if (matches.isEmpty) {
    // Si no hay etiquetas <h1-3>, buscar si hay párrafos que funcionen como títulos de capítulo
    final matchesP = _reParrafo.allMatches(html).where((m) {
      final t = textoPlano(m.group(1)!).trim();
      return _pareceTitulo(t);
    }).toList();

    if (matchesP.length > 1) {
      List<Chapter> capsPorP = [];
      int contP = startNum;

      String preP = html.substring(0, matchesP[0].start).replaceAll(_reEncabezadoVacio, '').trim();
      if (preP.isNotEmpty) {
        String tPre = (titulos != null && titulos.isNotEmpty) ? titulos[0] : 'Capítulo $contP';
        capsPorP.add(Chapter(titulo: tPre, htmlCuerpo: preP));
        contP++;
      }

      List<int> limitesP = matchesP.map((m) => m.start).toList()..add(html.length);
      for (int i = 0; i < matchesP.length; i++) {
        String sub = html.substring(limitesP[i], limitesP[i+1]);
        String cuerpo = sub.replaceFirst(matchesP[i].group(0)!, '').replaceAll(_reEncabezadoVacio, '').trim();
        String texto = textoPlano(matchesP[i].group(1)!).trim();
        int indice = contP - startNum;
        String titulo = (titulos != null && indice < titulos.length) ? titulos[indice] : (texto.isNotEmpty ? texto : 'Capítulo $contP');
        capsPorP.add(Chapter(titulo: titulo, htmlCuerpo: cuerpo));
        contP++;
      }
      return capsPorP;
    }

    String titulo = (titulos != null && titulos.isNotEmpty) ? titulos[0] : 'Capítulo $startNum';
    return [Chapter(titulo: titulo, htmlCuerpo: html.replaceAll(_reEncabezadoVacio, '').trim())];
  }

  List<Chapter> capitulos = [];
  int contador = startNum;

  String pre = html.substring(0, matches[0].start).replaceAll(_reEncabezadoVacio, '').trim();
  if (pre.isNotEmpty) {
    String titulo;
    String cuerpoPre = pre;

    // Buscar el primer párrafo con texto en `pre`
    Match? matchTitulo;
    String? textoTitulo;
    final matchesParrafosPre = _reParrafo.allMatches(pre);
    for (final m in matchesParrafosPre) {
      final t = textoPlano(m.group(1)!).trim();
      if (t.isEmpty) continue;
      if (_pareceTitulo(t)) {
        matchTitulo = m;
        textoTitulo = t;
      }
      break; // Solo evaluar el primer párrafo con texto
    }

    if (matchTitulo != null && textoTitulo != null) {
      titulo = (titulos != null && titulos.isNotEmpty) ? titulos[0] : textoTitulo;
      cuerpoPre = pre.replaceFirst(matchTitulo.group(0)!, '').trim();
    } else {
      titulo = (titulos != null && titulos.isNotEmpty) ? titulos[0] : 'Capítulo $contador';
    }

    if (cuerpoPre.isNotEmpty || titulo.isNotEmpty) {
      capitulos.add(Chapter(titulo: titulo, htmlCuerpo: cuerpoPre));
      contador++;
    }
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
