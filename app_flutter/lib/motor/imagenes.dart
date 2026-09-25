final String separadorXhtml = '<p class="hr centrado grande"><b>※ ・ ※ ・ ※</b></p>';

final _reImgPandocP = RegExp(r'<p[^>]*>\s*<img\b[^>]*src="[^"]*?image0*(\d+)\.[a-zA-Z]+"[^>]*>\s*</p>', caseSensitive: false);
final _reImgPandoc = RegExp(r'<img\b[^>]*src="[^"]*?image0*(\d+)\.[a-zA-Z]+"[^>]*>', caseSensitive: false);
final _reImagenTagP = RegExp(r'<p[^>]*>\s*\[IMAGEN\s*0*(\d+)\]\s*</p>', caseSensitive: false);
final _reImagenTag = RegExp(r'\[IMAGEN\s*0*(\d+)\]', caseSensitive: false);
final _reSeparadorP = RegExp(r'<p[^>]*>\s*\[(?:HR|SEPARADOR)\]\s*</p>', caseSensitive: false);
final _reSeparador = RegExp(r'\[(?:HR|SEPARADOR)\]', caseSensitive: false);

String _reemplazoImagen(Match match) {
  int num = int.parse(match.group(1)!);
  String numFmt = num.toString().padLeft(2, '0');
  return '<hr class="sigil_split_marker" />\n'
      '<figure class="dimg"><img src="../Images/$numFmt.jpg" alt=""/></figure>\n'
      '<hr class="sigil_split_marker" />';
}

final _reHrDuplicados = RegExp(
  r'(<hr\s+class="sigil_split_marker"\s*/?>)(\s*(?:<!--.*?-->\s*)*<hr\s+class="sigil_split_marker"\s*/?>)+',
  caseSensitive: false,
);

String limpiarHrDuplicados(String html) {
  return html.replaceAll(_reHrDuplicados, r'$1');
}

final _reFiguraImg = RegExp(
  r'<figure[^>]*>\s*<img\b[^>]*src="[^"]*?(?:Images/|image0*)(\d+)\.[a-zA-Z]+"[^>]*>\s*</figure>',
  caseSensitive: false,
);

String? extraerPrimeraImagen(String html) {
  final match = _reFiguraImg.firstMatch(html);
  if (match != null) {
    int num = int.tryParse(match.group(1)!) ?? 1;
    return num.toString().padLeft(2, '0');
  }
  final matchTag = _reImagenTag.firstMatch(html);
  if (matchTag != null) {
    int num = int.tryParse(matchTag.group(1)!) ?? 1;
    return num.toString().padLeft(2, '0');
  }
  final matchPandoc = _reImgPandoc.firstMatch(html);
  if (matchPandoc != null) {
    int num = int.tryParse(matchPandoc.group(1)!) ?? 1;
    return num.toString().padLeft(2, '0');
  }
  return null;
}

typedef ProcesarResult = ({String html, int count});

ProcesarResult procesarImagenes(String html) {
  int contador = 0;
  String reemplazo(Match m) {
    contador++;
    return _reemplazoImagen(m);
  }
  html = html.replaceAllMapped(_reImgPandocP, reemplazo);
  html = html.replaceAllMapped(_reImgPandoc, reemplazo);
  html = html.replaceAllMapped(_reImagenTagP, reemplazo);
  html = html.replaceAllMapped(_reImagenTag, reemplazo);
  html = limpiarHrDuplicados(html);
  return (html: html, count: contador);
}

ProcesarResult procesarSeparadores(String html) {
  int contador = 0;
  String reemplazo(Match m) {
    contador++;
    return separadorXhtml;
  }
  html = html.replaceAllMapped(_reSeparadorP, reemplazo);
  html = html.replaceAllMapped(_reSeparador, reemplazo);
  return (html: html, count: contador);
}
