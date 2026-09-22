import 'dart:core';

final _reRestaurarHtml = RegExp(r'&lt;(/?)(p|b|i|hr|br|div|span)([^&]*)&gt;');
final _reSpanBasura = RegExp(r'<span\b[^>]*(?:class|style|id)="[^"]*"[^>]*>');
final _reAtributosBasura = RegExp(r'\s(?:id(?!=["' "'" r']rf\d+")|style|class(?!=["' "'" r']mistico))="[^"]*"');
final _reDirLtr = RegExp(r'\sdir="ltr"');
final _reLangEs = RegExp(r'\slang="es"');
final _reVacioBI = RegExp(r'<(b|i)></\1>');
final _reDivVacio = RegExp(r'<div>\s*</div>', caseSensitive: false);
final _reUnificarI = RegExp(r'</i>(\s*)<i>');
final _reUnificarB = RegExp(r'</b>(\s*)<b>');
final _reAlinearApertura = RegExp(r'(<(?:i|b)>)([«‘])');
final _reAlinearCierre = RegExp(r'([»’])(</(?:i|b)>)');
final _reEtiqueta = RegExp(r'<[^>]+>');
final _reHVacio = RegExp(r'<h[1-3][^>]*>(?:\s|&nbsp;)*</h[1-3]>', caseSensitive: false);
final _reColgroup = RegExp(r'<colgroup>.*?</colgroup>', dotAll: true);
final _reStyleCenter = RegExp(r'\sstyle="[^"]*text-align:\s*center;?[^"]*"');

const _cortafuegos = {
  '</p>', '<br>', '<br/>', '</div>', '</section>', '</blockquote>', '<hr>'
};

const _caracteresAbren = ' \n\t(—-[{¿¡>:;';
const _caracteresCierran = ' \n\t.,;:!?)]}<';

bool _esApertura(String texto, int idx) {
  int j = idx - 1;
  while (j >= 0 && (texto[j] == '"' || texto[j] == "'")) {
    j--;
  }
  String prev = j >= 0 ? texto[j] : '';
  String next = idx < texto.length - 1 ? texto[idx + 1] : '';

  bool esAperturaPrev = prev == '' || _caracteresAbren.contains(prev);
  bool esCierreNext = next == '' || _caracteresCierran.contains(next);

  if (esAperturaPrev && !esCierreNext) return true;
  if (!esAperturaPrev && esCierreNext) return false;

  if (prev == '>') {
    int tagStart = texto.lastIndexOf('<', j);
    if (tagStart != -1 && tagStart + 1 < j && texto[tagStart + 1] == '/') {
      return false;
    }
  }

  return esAperturaPrev;
}

bool _cadenaConDoble(String texto, int idx, bool esApertura) {
  int j = idx;
  while (j > 0 && texto[j - 1] == "'") j--;
  int k = idx;
  while (k < texto.length - 1 && texto[k + 1] == "'") k++;
  if (k - j + 1 >= 3) return true;
  
  if (esApertura) {
    return j > 0 && texto[j - 1] == '"';
  }
  return k < texto.length - 1 && texto[k + 1] == '"';
}

String _convertirComillas(String html) {
  html = html.replaceAll(RegExp(r'[“”«»\u2033]'), '"');
  html = html.replaceAll(RegExp(r'[‘’\u2032]'), "'");

  List<String> resultado = [];
  int nivel = 0;
  int simplesLegitimas = 0;
  bool dentroDeTag = false;
  List<String> tagBuffer = [];

  for (int i = 0; i < html.length; i++) {
    String char = html[i];
    if (char == '<') {
      dentroDeTag = true;
      tagBuffer = ['<'];
      resultado.add(char);
      continue;
    }

    if (dentroDeTag) {
      tagBuffer.add(char);
      resultado.add(char);
      if (char == '>') {
        dentroDeTag = false;
        if (_cortafuegos.contains(tagBuffer.join('').toLowerCase())) {
          nivel = 0;
          simplesLegitimas = 0;
        }
      }
      continue;
    }

    if (char == '\n') {
      nivel = 0;
      simplesLegitimas = 0;
      resultado.add(char);
      continue;
    }

    if (char == '"') {
      if (_esApertura(html, i)) {
        nivel++;
        resultado.add('«');
      } else {
        resultado.add('»');
        if (nivel > 0) nivel--;
      }
    } else if (char == "'") {
      bool apertura = _esApertura(html, i);
      bool anidada = _cadenaConDoble(html, i, apertura);
      if (anidada && !apertura && simplesLegitimas > 0) {
        anidada = false;
        simplesLegitimas--;
      } else if (!anidada && apertura) {
        simplesLegitimas++;
      }
      if (anidada) {
        if (apertura) {
          nivel++;
          resultado.add('«');
        } else {
          resultado.add('»');
          if (nivel > 0) nivel--;
        }
      } else {
        resultado.add(apertura ? '\x01' : '\x02');
      }
    } else {
      resultado.add(char);
    }
  }

  if (nivel > 0) {
    for (int j = resultado.length - 1; j >= 0; j--) {
      if (resultado[j] == '«') {
        resultado[j] = '»';
        nivel--;
        if (nivel == 0) break;
      }
    }
  }

  return resultado.join('').replaceAll('\x01', '‘').replaceAll('\x02', '’');
}

String _normalizarEtiquetas(String html) {
  return html.replaceAll('<strong>', '<b>').replaceAll('</strong>', '</b>')
             .replaceAll('<em>', '<i>').replaceAll('</em>', '</i>');
}

String _restaurarHtmlEscapado(String html) {
  html = html.replaceAllMapped(_reRestaurarHtml, (m) => '<${m[1]}${m[2]}${m[3]}>');
  return html.replaceAll('&lt;', '「').replaceAll('&gt;', '」');
}

String _unificarEtiquetasPartidas(String html) {
  html = html.replaceAllMapped(_reUnificarI, (m) => m[1]!);
  return html.replaceAllMapped(_reUnificarB, (m) => m[1]!);
}

String _alinearComillasYEtiquetas(String html) {
  while (true) {
    String antes = html;
    html = html.replaceAllMapped(_reAlinearApertura, (m) => '${m[2]}${m[1]}');
    html = html.replaceAllMapped(_reAlinearCierre, (m) => '${m[2]}${m[1]}');
    if (html == antes) break;
  }
  return html;
}

String _eliminarBasura(String html) {
  html = html.replaceAll(_reColgroup, '');
  html = html.replaceAll(_reStyleCenter, ' class="centrado"');
  html = html.replaceAll(_reSpanBasura, '');
  html = html.replaceAll('</span>', '');
  html = html.replaceAll(_reDirLtr, '');
  html = html.replaceAll(_reLangEs, '');
  html = html.replaceAll(_reAtributosBasura, '');
  html = html.replaceAll(_reVacioBI, '');
  html = html.replaceAll(_reDivVacio, '');
  html = html.replaceAll(_reHVacio, '');
  return html;
}

String limpiarTextoHtml(String html) {
  html = _normalizarEtiquetas(html);
  html = _restaurarHtmlEscapado(html);
  html = _unificarEtiquetasPartidas(html);
  html = _convertirComillas(html);
  html = _alinearComillasYEtiquetas(html);
  html = _eliminarBasura(html);
  return html;
}

String textoPlano(String html) {
  return html.replaceAll(_reEtiqueta, '').replaceAll('&nbsp;', ' ').trim();
}
