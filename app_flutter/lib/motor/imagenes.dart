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

class ProcesarResult {
  final String html;
  final int count;
  ProcesarResult(this.html, this.count);
}

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
  return ProcesarResult(html, contador);
}

ProcesarResult procesarSeparadores(String html) {
  int contador = 0;
  String reemplazo(Match m) {
    contador++;
    return separadorXhtml;
  }
  html = html.replaceAllMapped(_reSeparadorP, reemplazo);
  html = html.replaceAllMapped(_reSeparador, reemplazo);
  return ProcesarResult(html, contador);
}
