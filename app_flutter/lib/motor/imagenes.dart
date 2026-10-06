final String separadorXhtml = '<p class="text align-center large"><b>※ ・ ※ ・ ※</b></p>';

final _reImgPandocP = RegExp(r'<p[^>]*>\s*<img\b[^>]*src="[^"]*?(?:Images/|image0*)(\d+)\.[a-zA-Z]+"[^>]*>\s*</p>', caseSensitive: false);
final _reImgPandoc = RegExp(r'<img\b[^>]*src="[^"]*?image0*(\d+)\.[a-zA-Z]+"[^>]*>', caseSensitive: false);
final _reImagenTagP = RegExp(r'<p[^>]*>\s*\[(?:IMAGEN|ILUSTRACI[OÓ]N|ILU)\s*0*(\d+)\]\s*</p>', caseSensitive: false);
final _reImagenTag = RegExp(r'\[(?:IMAGEN|ILUSTRACI[OÓ]N|ILU)\s*0*(\d+)\]', caseSensitive: false);
final _reSeparadorP = RegExp(r'<p[^>]*>\s*\[(?:HR|SEPARADOR|ESCENA)\]\s*</p>', caseSensitive: false);
final _reSeparador = RegExp(r'\[(?:HR|SEPARADOR|ESCENA)\]', caseSensitive: false);

String _reemplazoImagen(Match match) {
  int num = int.parse(match.group(1)!);
  String numFmt = num.toString().padLeft(2, '0');
  return '<figure class="fill break-before break-after"><img src="../Images/$numFmt.jpg" alt=""/></figure>';
}

final _reHrDuplicados = RegExp(
  r'(<hr\s+class="[^"]*"\s*/?>)(\s*(?:<!--.*?-->\s*)*<hr\s+class="[^"]*"\s*/?>)+',
  caseSensitive: false,
);

String limpiarHrDuplicados(String html) {
  return html.replaceAllMapped(_reHrDuplicados, (match) => match[1]!);
}

final _reFiguraImg = RegExp(
  r'<figure[^>]*>\s*<img\b[^>]*src="[^"]*?(?:Images/|image0*)(\d+)\.[a-zA-Z]+"[^>]*>\s*</figure>',
  caseSensitive: false,
);

final _reFiguraExistente = RegExp(
  r'<figure\b([^>]*)>\s*(<img\b[^>]*>)\s*</figure>',
  caseSensitive: false,
  dotAll: true,
);

String _normalizarFigura(Match match) {
  final attrs = match.group(1) ?? '';
  final img = match.group(2)!;
  final idMatch = RegExp(r'\bid="([^"]*)"', caseSensitive: false).firstMatch(attrs);
  final idAttr = idMatch != null ? ' id="${idMatch.group(1)}"' : '';
  return '<figure class="fill break-before break-after"$idAttr>$img</figure>';
}

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
  html = html.replaceAllMapped(_reFiguraExistente, _normalizarFigura);
  html = limpiarHrDuplicados(html);
  return (html: html, count: contador);
}

final _reSeparadorExistente = RegExp(
  r'<p\s+class="[^"]*(?:hr|centrado|grande)[^"]*">\s*(<b>\s*(?:[※†◇■*•]\s*・\s*[※†◇■*•]\s*・\s*[※†◇■*•]|\*\s*\*\s*\*)\s*</b>)\s*</p>',
  caseSensitive: false,
);

ProcesarResult procesarSeparadores(String html) {
  int contador = 0;
  String reemplazo(Match m) {
    contador++;
    return separadorXhtml;
  }
  html = html.replaceAllMapped(_reSeparadorP, reemplazo);
  html = html.replaceAllMapped(_reSeparador, reemplazo);
  html = html.replaceAllMapped(_reSeparadorExistente, (m) {
    return '<p class="text align-center large">${m.group(1)}</p>';
  });
  return (html: html, count: contador);
}
