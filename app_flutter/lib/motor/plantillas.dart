import 'modelo.dart';

final Map<String, String> tablaEspeciales = {
  'prologo': 'prologo.xhtml',
  'epilogo': 'epilogo.xhtml',
  'palabras del autor': 'autor.xhtml',
  'palabras finales': 'autor.xhtml',
  'postfacio': 'autor.xhtml',
  'epilogo del autor': 'autor.xhtml',
  'nota del autor': 'autor.xhtml',
  'palabras del traductor': 'traductor.xhtml',
  'palabras de traductor': 'traductor.xhtml',
  'nota del traductor': 'traductor.xhtml',
  'notas del traductor': 'traductor.xhtml',
};

final _reArchivoC = RegExp(r'^C(\d+)\.xhtml$');

int numeroDeArchivo(String? archivo, int porDefecto) {
  if (archivo == null) return porDefecto;
  return int.tryParse(_reArchivoC.firstMatch(archivo)?[1] ?? '') ?? porDefecto;
}

enum TipoEspecial {
  prologo,
  epilogo,
  autor,
  traductor,
  interludio,
}

TipoEspecial? detectarTipoEspecial(String titulo) {
  final norm = titulo.toLowerCase().trim().replaceAll('ó', 'o').replaceAll('í', 'i');
  if (norm.startsWith('prologo')) return TipoEspecial.prologo;
  if (norm.startsWith('epilogo del autor')) return TipoEspecial.autor;
  if (norm.startsWith('epilogo')) return TipoEspecial.epilogo;
  if (norm.startsWith('interludio')) return TipoEspecial.interludio;
  if (norm.startsWith('palabras del traductor') ||
      norm.startsWith('palabras de traductor') ||
      norm.startsWith('nota del traductor') ||
      norm.startsWith('notas del traductor')) {
    return TipoEspecial.traductor;
  }
  if (norm.startsWith('palabras del autor') ||
      norm.startsWith('palabras finales') ||
      norm.startsWith('postfacio') ||
      norm.startsWith('nota del autor')) {
    return TipoEspecial.autor;
  }
  return null;
}

String? clasificarEspecial(String titulo) {
  final tipo = detectarTipoEspecial(titulo);
  switch (tipo) {
    case TipoEspecial.prologo:
      return 'prologo.xhtml';
    case TipoEspecial.epilogo:
      return 'epilogo.xhtml';
    case TipoEspecial.autor:
      return 'autor.xhtml';
    case TipoEspecial.traductor:
      return 'traductor.xhtml';
    case TipoEspecial.interludio:
      return null;
    case null:
      return null;
  }
}

class PartesTitulo {
  final String etiqueta; // Ej: "Capítulo 1", "Prólogo I", "Interludio 2"
  final String? subtitulo; // Ej: "De Encantador a Espadachín", "Expulsión"
  final String tituloCompleto;
  final bool esInterludio;
  final bool esPrologo;
  final bool esEpilogo;
  final bool esAutor;
  final bool esTraductor;

  PartesTitulo({
    required this.etiqueta,
    this.subtitulo,
    required this.tituloCompleto,
    this.esInterludio = false,
    this.esPrologo = false,
    this.esEpilogo = false,
    this.esAutor = false,
    this.esTraductor = false,
  });
}

final _rePrologo = RegExp(
  r'^\s*(pr[oó]logo(?:\s*(?:[ivxlcdm]+|\d+))?)\s*[:—–\-.]*\s*(.*)$',
  caseSensitive: false,
);

final _reEpilogo = RegExp(
  r'^\s*(ep[ií]logo(?:\s*(?:[ivxlcdm]+|\d+))?)\s*[:—–\-.]*\s*(.*)$',
  caseSensitive: false,
);

final _reInterludio = RegExp(
  r'^\s*(interludio(?:\s*(?:[ivxlcdm]+|\d+))?)\s*[:—–\-.]*\s*(.*)$',
  caseSensitive: false,
);

final _reTraductor = RegExp(
  r'^\s*(palabras\s+del?\s+traductor|notas?\s+del\s+traductor)\b\s*[:—–\-.]*\s*(.*)$',
  caseSensitive: false,
);

final _reAutor = RegExp(
  r'^\s*(palabras\s+finales|palabras\s+del\s+autor|postfacio|nota\s+del\s+autor|ep[ií]logo\s+del\s+autor)\b\s*[:—–\-.]*\s*(.*)$',
  caseSensitive: false,
);

final _reCapitulo = RegExp(
  r'^\s*(cap[ií]tulo\s*(?:[ivxlcdm]+|\d+))\s*[:—–\-.]*\s*(.*)$',
  caseSensitive: false,
);

final _reNumeroPunto = RegExp(
  r'^\s*(\d+)\s*[:.—–\-]\s*(.*)$',
  caseSensitive: false,
);

PartesTitulo descomponerTitulo(String titulo, {int? numeroPorDefecto}) {
  String t = titulo.trim();

  var m = _rePrologo.firstMatch(t);
  if (m != null) {
    String etiqueta = m.group(1)!.trim();
    String sub = m.group(2)!.trim();
    return PartesTitulo(
      etiqueta: etiqueta,
      subtitulo: sub.isNotEmpty ? sub : null,
      tituloCompleto: t,
      esPrologo: true,
    );
  }

  m = _reEpilogo.firstMatch(t);
  if (m != null && !t.toLowerCase().startsWith('epilogo del autor') && !t.toLowerCase().startsWith('epílogo del autor')) {
    String etiqueta = m.group(1)!.trim();
    String sub = m.group(2)!.trim();
    return PartesTitulo(
      etiqueta: etiqueta,
      subtitulo: sub.isNotEmpty ? sub : null,
      tituloCompleto: t,
      esEpilogo: true,
    );
  }

  m = _reInterludio.firstMatch(t);
  if (m != null) {
    String etiqueta = m.group(1)!.trim();
    String sub = m.group(2)!.trim();
    return PartesTitulo(
      etiqueta: etiqueta,
      subtitulo: sub.isNotEmpty ? sub : null,
      tituloCompleto: t,
      esInterludio: true,
    );
  }

  m = _reTraductor.firstMatch(t);
  if (m != null) {
    String etiqueta = m.group(1)!.trim();
    String sub = m.group(2)!.trim();
    return PartesTitulo(
      etiqueta: etiqueta,
      subtitulo: sub.isNotEmpty ? sub : null,
      tituloCompleto: t,
      esTraductor: true,
    );
  }

  m = _reAutor.firstMatch(t);
  if (m != null) {
    String etiqueta = m.group(1)!.trim();
    String sub = m.group(2)!.trim();
    return PartesTitulo(
      etiqueta: etiqueta,
      subtitulo: sub.isNotEmpty ? sub : null,
      tituloCompleto: t,
      esAutor: true,
    );
  }

  m = _reCapitulo.firstMatch(t);
  if (m != null) {
    String etiqueta = m.group(1)!.trim();
    String sub = m.group(2)!.trim();
    return PartesTitulo(
      etiqueta: etiqueta,
      subtitulo: sub.isNotEmpty ? sub : null,
      tituloCompleto: t,
    );
  }

  // Título que empieza con número seguido de punto/dos puntos (ej: "0. Una Oferta Dudosa", "2: Palacio Real")
  m = _reNumeroPunto.firstMatch(t);
  if (m != null) {
    int numDetectado = int.tryParse(m.group(1)!) ?? (numeroPorDefecto ?? 0);
    String sub = m.group(2)!.trim();
    return PartesTitulo(
      etiqueta: 'Capítulo $numDetectado',
      subtitulo: sub.isNotEmpty ? sub : null,
      tituloCompleto: sub.isNotEmpty ? 'Capítulo $numDetectado: $sub' : 'Capítulo $numDetectado',
    );
  }

  // Título sin prefijo de capítulo (ej. "El Juramento" o "Historia corta...")
  String etiqueta = numeroPorDefecto != null ? 'Capítulo $numeroPorDefecto' : t;
  return PartesTitulo(
    etiqueta: etiqueta,
    subtitulo: t,
    tituloCompleto: numeroPorDefecto != null ? '$etiqueta: $t' : t,
  );
}

void clasificarYRenumerarCapitulos(List<Chapter> capitulos, {int startNum = 1, String? rutaPlantillas}) {
  int totalPrologos = 0;
  int totalEpilogos = 0;
  int totalAutores = 0;
  int totalTraductores = 0;
  int totalInterludios = 0;

  for (var cap in capitulos) {
    final tipo = detectarTipoEspecial(cap.titulo);
    if (tipo == TipoEspecial.prologo) totalPrologos++;
    if (tipo == TipoEspecial.epilogo) totalEpilogos++;
    if (tipo == TipoEspecial.autor) totalAutores++;
    if (tipo == TipoEspecial.traductor) totalTraductores++;
    if (tipo == TipoEspecial.interludio) totalInterludios++;
  }

  int countPrologo = 0;
  int countEpilogo = 0;
  int countAutor = 0;
  int countTraductor = 0;
  int countInterludio = 0;
  int numeroCapitulo = startNum;

  for (var cap in capitulos) {
    final tipo = detectarTipoEspecial(cap.titulo);
    if (tipo == TipoEspecial.prologo) {
      countPrologo++;
      cap.plantillaNombre = 'prologo.xhtml';
      cap.archivo = (totalPrologos > 1)
          ? 'prologo_${countPrologo.toString().padLeft(2, '0')}.xhtml'
          : 'prologo.xhtml';
    } else if (tipo == TipoEspecial.epilogo) {
      countEpilogo++;
      cap.plantillaNombre = 'epilogo.xhtml';
      cap.archivo = (totalEpilogos > 1)
          ? 'epilogo_${countEpilogo.toString().padLeft(2, '0')}.xhtml'
          : 'epilogo.xhtml';
    } else if (tipo == TipoEspecial.autor) {
      countAutor++;
      cap.plantillaNombre = 'autor.xhtml';
      cap.archivo = (totalAutores > 1)
          ? 'autor_${countAutor.toString().padLeft(2, '0')}.xhtml'
          : 'autor.xhtml';
    } else if (tipo == TipoEspecial.traductor) {
      countTraductor++;
      cap.plantillaNombre = 'traductor.xhtml';
      cap.archivo = (totalTraductores > 1)
          ? 'traductor_${countTraductor.toString().padLeft(2, '0')}.xhtml'
          : 'traductor.xhtml';
    } else if (tipo == TipoEspecial.interludio) {
      countInterludio++;
      cap.plantillaNombre = null; // usa template.xhtml
      cap.archivo = (totalInterludios > 1)
          ? 'interludio_${countInterludio.toString().padLeft(2, '0')}.xhtml'
          : 'interludio.xhtml';
    } else {
      // Capítulo normal o historia extra/adicional
      cap.plantillaNombre = null;
      cap.archivo = 'C${numeroCapitulo.toString().padLeft(2, '0')}.xhtml';
      numeroCapitulo++;
    }

    if (rutaPlantillas != null && cap.plantillaNombre != null) {
      cap.plantillaRuta = '$rutaPlantillas/${cap.plantillaNombre}';
    }
  }
}
