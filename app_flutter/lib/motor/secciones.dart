import 'modelo.dart';
import 'plantillas.dart';
import 'render.dart';

enum BookMatter {
  front('Preliminares'),
  body('Cuerpo'),
  back('Finales');

  final String label;
  const BookMatter(this.label);
}

enum SectionKind {
  cover('Cubierta', BookMatter.front, 'cubierta.xhtml'),
  synopsis('Sinopsis', BookMatter.front, 'sinopsis.xhtml'),
  illustrations('Ilustraciones', BookMatter.front, 'resumen.xhtml'),
  titlePage('Página de título', BookMatter.front, 'titulo.xhtml'),
  notice('Advertencia', BookMatter.front, 'aviso.xhtml'),
  epigraph('Epígrafe', BookMatter.front, 'epigrafe.xhtml'),
  prologue('Prólogo', BookMatter.body, 'prologo.xhtml'),
  chapter('Capítulo', BookMatter.body, 'C01.xhtml'),
  interlude('Interludio', BookMatter.body, 'C01.xhtml'),
  part('Parte', BookMatter.body, 'parte.xhtml'),
  epilogue('Epílogo', BookMatter.back, 'epilogo.xhtml'),
  notes('Notas al pie', BookMatter.back, 'notas.xhtml'),
  author('Acerca del autor', BookMatter.back, 'autor.xhtml'),
  translator('Palabras del traductor', BookMatter.back, 'traductor.xhtml'),
  colophon('Créditos y logos', BookMatter.back, 'logos.xhtml');

  final String label;
  final BookMatter matter;
  final String defaultFileName;

  const SectionKind(this.label, this.matter, this.defaultFileName);
}

class SectionItem {
  final String id;
  SectionKind kind;
  BookMatter matter;
  String title;
  String subtitle;
  String fileName;
  bool inToc;
  bool enabled;
  String htmlContent;
  String htmlRaw;
  String? associatedImage;
  bool titleIsImage;
  String? titleImageNumber;

  SectionItem({
    required this.id,
    required this.kind,
    required this.matter,
    required this.title,
    this.subtitle = '',
    required this.fileName,
    this.inToc = true,
    this.enabled = true,
    this.htmlContent = '',
    this.htmlRaw = '',
    this.associatedImage,
    this.titleIsImage = false,
    this.titleImageNumber,
  });

  SectionItem copyWith({
    String? id,
    SectionKind? kind,
    BookMatter? matter,
    String? title,
    String? subtitle,
    String? fileName,
    bool? inToc,
    bool? enabled,
    String? htmlContent,
    String? htmlRaw,
    String? associatedImage,
    bool? titleIsImage,
    String? titleImageNumber,
  }) {
    return SectionItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      matter: matter ?? this.matter,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      fileName: fileName ?? this.fileName,
      inToc: inToc ?? this.inToc,
      enabled: enabled ?? this.enabled,
      htmlContent: htmlContent ?? this.htmlContent,
      htmlRaw: htmlRaw ?? this.htmlRaw,
      associatedImage: associatedImage ?? this.associatedImage,
      titleIsImage: titleIsImage ?? this.titleIsImage,
      titleImageNumber: titleImageNumber ?? this.titleImageNumber,
    );
  }

  /// Título completo formateado para la lista o el encabezado
  String get effectiveHeading {
    if (subtitle.trim().isNotEmpty) {
      return '$title: $subtitle';
    }
    return title;
  }
}

/// Convierte el `Resultado` generado por `procesar.dart` en una lista jerárquica
/// y configurable de `SectionItem` agrupada en Preliminares, Cuerpo y Finales.
List<SectionItem> convertirResultadoASecciones(
  Resultado res, {
  int startNum = 1,
  String? portadaDefault,
  String? sinopsisTexto,
}) {
  final secciones = <SectionItem>[];

  // 1. Preliminares estándar
  secciones.add(SectionItem(
    id: 'sec_cover',
    kind: SectionKind.cover,
    matter: BookMatter.front,
    title: 'Cubierta',
    fileName: 'cubierta.xhtml',
    inToc: false,
    enabled: true,
    associatedImage: portadaDefault,
  ));

  secciones.add(SectionItem(
    id: 'sec_titlepage',
    kind: SectionKind.titlePage,
    matter: BookMatter.front,
    title: 'Página de título',
    fileName: 'titulo.xhtml',
    inToc: true,
    enabled: true,
  ));

  final tieneSinopsis = sinopsisTexto != null && sinopsisTexto.trim().isNotEmpty;
  secciones.add(SectionItem(
    id: 'sec_synopsis',
    kind: SectionKind.synopsis,
    matter: BookMatter.front,
    title: 'Sinopsis',
    fileName: 'sinopsis.xhtml',
    inToc: tieneSinopsis,
    enabled: tieneSinopsis,
    htmlContent: tieneSinopsis ? sinopsisTexto : '',
  ));

  // 2. Capítulos extraídos del manuscrito
  final capitulosCuerpo = <SectionItem>[];
  final capitulosFinales = <SectionItem>[];

  int contadorCapitulosRegulares = startNum;

  for (int i = 0; i < res.capitulos.length; i++) {
    final cap = res.capitulos[i];
    final partes = descomponerTitulo(cap.titulo, numeroPorDefecto: contadorCapitulosRegulares);

    SectionKind kind;
    BookMatter matter;
    String nombreArchivo = cap.archivo ?? '';

    if (partes.esPrologo) {
      kind = SectionKind.prologue;
      matter = BookMatter.body;
      nombreArchivo = 'prologo.xhtml';
    } else if (partes.esEpilogo) {
      kind = SectionKind.epilogue;
      matter = BookMatter.back;
      nombreArchivo = 'epilogo.xhtml';
    } else if (partes.esAutor) {
      kind = SectionKind.author;
      matter = BookMatter.back;
      nombreArchivo = 'autor.xhtml';
    } else if (partes.esTraductor) {
      kind = SectionKind.translator;
      matter = BookMatter.back;
      nombreArchivo = 'traductor.xhtml';
    } else if (partes.esInterludio) {
      kind = SectionKind.interlude;
      matter = BookMatter.body;
      if (nombreArchivo.isEmpty) {
        nombreArchivo = 'C${contadorCapitulosRegulares.toString().padLeft(2, '0')}.xhtml';
        contadorCapitulosRegulares++;
      }
    } else {
      kind = SectionKind.chapter;
      matter = BookMatter.body;
      if (nombreArchivo.isEmpty) {
        nombreArchivo = 'C${contadorCapitulosRegulares.toString().padLeft(2, '0')}.xhtml';
        contadorCapitulosRegulares++;
      }
    }

    final item = SectionItem(
      id: 'cap_$i',
      kind: kind,
      matter: matter,
      title: partes.etiqueta,
      subtitle: partes.subtitulo ?? '',
      fileName: nombreArchivo,
      inToc: true,
      enabled: true,
      htmlContent: cap.htmlCuerpo,
      htmlRaw: cap.htmlRaw,
      titleIsImage: cap.tituloEsImagen,
      titleImageNumber: cap.numeroImagenTitulo,
    );

    if (matter == BookMatter.back) {
      capitulosFinales.add(item);
    } else {
      capitulosCuerpo.add(item);
    }
  }

  secciones.addAll(capitulosCuerpo);

  // 3. Finales: Notas al pie y secciones finales detectadas
  final tieneNotas = res.notas.isNotEmpty;
  if (tieneNotas) {
    secciones.add(SectionItem(
      id: 'sec_notes',
      kind: SectionKind.notes,
      matter: BookMatter.back,
      title: 'Notas',
      fileName: 'notas.xhtml',
      inToc: false,
      enabled: true,
      htmlContent: renderNotas(res.notas),
    ));
  }

  secciones.addAll(capitulosFinales);

  return secciones;
}

/// Convierte la lista de `SectionItem` de vuelta a `List<Chapter>` para renderizar
/// con las plantillas XHTML existentes.
List<Chapter> seccionesACapitulos(List<SectionItem> secciones) {
  final caps = <Chapter>[];
  for (final s in secciones) {
    if (!s.enabled) continue;
    // Solo secciones con contenido narrativo o que son capítulos
    if (s.kind == SectionKind.cover || s.kind == SectionKind.illustrations || s.kind == SectionKind.titlePage) {
      continue;
    }

    String? plantillaNombre;
    if (s.kind == SectionKind.prologue) plantillaNombre = 'prologo.xhtml';
    if (s.kind == SectionKind.epilogue) plantillaNombre = 'epilogo.xhtml';
    if (s.kind == SectionKind.author) plantillaNombre = 'autor.xhtml';
    if (s.kind == SectionKind.translator) plantillaNombre = 'traductor.xhtml';

    caps.add(Chapter(
      titulo: s.effectiveHeading,
      htmlCuerpo: s.htmlContent,
      htmlRaw: s.htmlRaw,
      archivo: s.fileName,
      plantillaNombre: plantillaNombre,
      tituloEsImagen: s.titleIsImage,
      numeroImagenTitulo: s.titleImageNumber,
    ));
  }
  return caps;
}
