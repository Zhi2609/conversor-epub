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
  illustrations('Ilustraciones a color', BookMatter.front, 'resumen.xhtml'),
  authorProfile('Perfil del autor', BookMatter.front, 'perfil.xhtml'),
  titlePage('Página de título', BookMatter.front, 'titulo.xhtml'),
  credits('Créditos', BookMatter.front, 'creditos.xhtml'),
  logos('Logos editoriales', BookMatter.front, 'logos.xhtml'),
  tocVisual('Índice visual', BookMatter.front, 'contenido-1.xhtml'),
  tocList('Tabla de contenido', BookMatter.front, 'contenido-2.xhtml'),
  epigraph('Epígrafe', BookMatter.front, 'epigrafe.xhtml'),
  preface('Prefacio', BookMatter.front, 'prefacio.xhtml'),
  notice('Advertencia', BookMatter.front, 'aviso.xhtml'),
  prologue('Prólogo', BookMatter.body, 'prologo.xhtml'),
  chapter('Capítulo', BookMatter.body, 'C01.xhtml'),
  interlude('Interludio', BookMatter.body, 'C01.xhtml'),
  part('Parte', BookMatter.body, 'parte.xhtml'),
  extra('Historia Extra', BookMatter.back, 'extra.xhtml'),
  epilogue('Epílogo', BookMatter.back, 'epilogo.xhtml'),
  author('Acerca del autor', BookMatter.back, 'autor.xhtml'),
  translator('Palabras del traductor', BookMatter.back, 'traductor.xhtml'),
  backCover('Contracubierta', BookMatter.back, 'contracubierta.xhtml'),
  notes('Notas al pie', BookMatter.back, 'notas.xhtml'),
  tocNav('Navegación ePub', BookMatter.back, 'toc.xhtml'),
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
/// y configurable de `SectionItem` reflejando de forma idéntica las 19 posiciones
/// canónicas del spine de `Base3_v1.15.0.epub`.
List<SectionItem> convertirResultadoASecciones(
  Resultado res, {
  int startNum = 1,
  String? portadaDefault,
  String? sinopsisTexto,
}) {
  final secciones = <SectionItem>[];

  // ==========================================
  // 1. PRELIMINARES (Front Matter) — Base3 1:1
  // ==========================================

  // Posición 1: Cubierta
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

  // Posición 2: Sinopsis
  final tieneSinopsis = sinopsisTexto != null && sinopsisTexto.trim().isNotEmpty;
  final htmlSinopsisDefault = '''<blockquote class="aviso">
  <p class="grande centrado"><b>Advertencia:</b></p>
  <p class="salto0">Esta novela contiene material y/o lenguaje que para algunos podría resultar ofensivo, explícito y vulgar, si usted es una persona sensible, se recomienda abstenerse de leerlo.</p>
</blockquote>
<hr class="sigil_split_marker"/>
<!-- Borrar todo lo anterior si no se requiere -->
<header>
  <h1 class="sigil_not_in_toc">Sinopsis</h1>
</header>
<p>${tieneSinopsis ? sinopsisTexto : 'Aquí va el contenido de la sinopsis...'}</p>''';

  secciones.add(SectionItem(
    id: 'sec_synopsis',
    kind: SectionKind.synopsis,
    matter: BookMatter.front,
    title: 'Sinopsis',
    fileName: 'sinopsis.xhtml',
    inToc: tieneSinopsis,
    enabled: tieneSinopsis,
    htmlContent: htmlSinopsisDefault,
  ));

  // Posición 3: Ilustraciones a color (resumen.xhtml en Base3)
  secciones.add(SectionItem(
    id: 'sec_illustrations',
    kind: SectionKind.illustrations,
    matter: BookMatter.front,
    title: 'Ilustraciones a color',
    fileName: 'resumen.xhtml',
    inToc: true,
    enabled: false,
  ));

  // Posición 4: Perfil del autor (perfil.xhtml)
  secciones.add(SectionItem(
    id: 'sec_profile',
    kind: SectionKind.authorProfile,
    matter: BookMatter.front,
    title: 'Perfil del autor',
    subtitle: 'Acerca del autor(a)',
    fileName: 'perfil.xhtml',
    inToc: true,
    enabled: false,
  ));

  // Posición 5: Página de título (titulo.xhtml)
  secciones.add(SectionItem(
    id: 'sec_titlepage',
    kind: SectionKind.titlePage,
    matter: BookMatter.front,
    title: 'Página de título',
    fileName: 'titulo.xhtml',
    inToc: true,
    enabled: true,
  ));

  // Posición 6: Créditos de traducción (creditos.xhtml)
  secciones.add(SectionItem(
    id: 'sec_credits',
    kind: SectionKind.credits,
    matter: BookMatter.front,
    title: 'Créditos',
    fileName: 'creditos.xhtml',
    inToc: true,
    enabled: true,
  ));

  // Posición 7: Logos editoriales (logos.xhtml)
  secciones.add(SectionItem(
    id: 'sec_logos',
    kind: SectionKind.logos,
    matter: BookMatter.front,
    title: 'Logos editoriales',
    fileName: 'logos.xhtml',
    inToc: true,
    enabled: true,
  ));

  // Posición 8: Índice visual (contenido-1.xhtml)
  secciones.add(SectionItem(
    id: 'sec_toc_visual',
    kind: SectionKind.tocVisual,
    matter: BookMatter.front,
    title: 'Índice visual',
    fileName: 'contenido-1.xhtml',
    inToc: false,
    enabled: false,
  ));

  // Posición 9: Tabla de contenido textual (contenido-2.xhtml)
  secciones.add(SectionItem(
    id: 'sec_toc_list',
    kind: SectionKind.tocList,
    matter: BookMatter.front,
    title: 'Tabla de contenido',
    fileName: 'contenido-2.xhtml',
    inToc: true,
    enabled: true,
  ));

  // Posición 10: Epígrafe (epigrafe.xhtml)
  secciones.add(SectionItem(
    id: 'sec_epigraph',
    kind: SectionKind.epigraph,
    matter: BookMatter.front,
    title: 'Epígrafe',
    fileName: 'epigrafe.xhtml',
    inToc: false,
    enabled: false,
  ));

  // Posición 11: Prefacio (prefacio.xhtml)
  secciones.add(SectionItem(
    id: 'sec_preface',
    kind: SectionKind.preface,
    matter: BookMatter.front,
    title: 'Prefacio',
    fileName: 'prefacio.xhtml',
    inToc: false,
    enabled: false,
  ));

  // ==========================================
  // 2. CUERPO (Body Matter) — Base3 1:1
  // ==========================================

  // Separar especiales detectados en el manuscrito
  Chapter? capPrologo;
  Chapter? capEpilogo;
  Chapter? capAutor;
  Chapter? capTraductor;
  final capitulosNarrativa = <({Chapter cap, PartesTitulo partes, int index})>[];

  int contadorCapitulosRegulares = startNum;

  for (int i = 0; i < res.capitulos.length; i++) {
    final cap = res.capitulos[i];
    final partes = descomponerTitulo(cap.titulo, numeroPorDefecto: contadorCapitulosRegulares);

    if (partes.esPrologo && capPrologo == null) {
      capPrologo = cap;
    } else if (partes.esEpilogo && capEpilogo == null) {
      capEpilogo = cap;
    } else if (partes.esAutor && capAutor == null) {
      capAutor = cap;
    } else if (partes.esTraductor && capTraductor == null) {
      capTraductor = cap;
    } else {
      capitulosNarrativa.add((cap: cap, partes: partes, index: i));
      if (!partes.esInterludio && !partes.esExtra) {
        contadorCapitulosRegulares++;
      }
    }
  }

  // Posición 12: Prólogo (prologo.xhtml)
  if (capPrologo != null) {
    final partesPro = descomponerTitulo(capPrologo.titulo);
    secciones.add(SectionItem(
      id: 'sec_prologue',
      kind: SectionKind.prologue,
      matter: BookMatter.body,
      title: partesPro.etiqueta,
      subtitle: partesPro.subtitulo ?? '',
      fileName: 'prologo.xhtml',
      inToc: true,
      enabled: true,
      htmlContent: capPrologo.htmlCuerpo,
      htmlRaw: capPrologo.htmlRaw,
      titleIsImage: capPrologo.tituloEsImagen,
      titleImageNumber: capPrologo.numeroImagenTitulo,
    ));
  } else {
    secciones.add(SectionItem(
      id: 'sec_prologue',
      kind: SectionKind.prologue,
      matter: BookMatter.body,
      title: 'Prólogo',
      fileName: 'prologo.xhtml',
      inToc: true,
      enabled: false,
    ));
  }

  // Posición 13: Capítulos narrativos (C01.xhtml ... CNN.xhtml, interludios e historias extra)
  int numArchivo = startNum;
  int numExtra = 1;
  for (final item in capitulosNarrativa) {
    final cap = item.cap;
    final partes = item.partes;
    final i = item.index;

    final kind = partes.esExtra
        ? SectionKind.extra
        : (partes.esInterludio ? SectionKind.interlude : SectionKind.chapter);
    final matter = partes.esExtra ? BookMatter.back : BookMatter.body;
    String nombreArchivo = cap.archivo ?? '';
    if (nombreArchivo.isEmpty) {
      if (partes.esExtra) {
        nombreArchivo = 'extra_${numExtra.toString().padLeft(2, '0')}.xhtml';
        numExtra++;
      } else {
        nombreArchivo = 'C${numArchivo.toString().padLeft(2, '0')}.xhtml';
        numArchivo++;
      }
    }

    secciones.add(SectionItem(
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
    ));
  }

  // ==========================================
  // 3. FINALES (Back Matter) — Base3 1:1
  // ==========================================

  // Posición 14: Epílogo (epilogo.xhtml)
  if (capEpilogo != null) {
    final partesEpi = descomponerTitulo(capEpilogo.titulo);
    secciones.add(SectionItem(
      id: 'sec_epilogue',
      kind: SectionKind.epilogue,
      matter: BookMatter.back,
      title: partesEpi.etiqueta,
      subtitle: partesEpi.subtitulo ?? '',
      fileName: 'epilogo.xhtml',
      inToc: true,
      enabled: true,
      htmlContent: capEpilogo.htmlCuerpo,
      htmlRaw: capEpilogo.htmlRaw,
      titleIsImage: capEpilogo.tituloEsImagen,
      titleImageNumber: capEpilogo.numeroImagenTitulo,
    ));
  } else {
    secciones.add(SectionItem(
      id: 'sec_epilogue',
      kind: SectionKind.epilogue,
      matter: BookMatter.back,
      title: 'Epílogo',
      fileName: 'epilogo.xhtml',
      inToc: true,
      enabled: false,
    ));
  }

  // Posición 15: Acerca del autor (autor.xhtml)
  if (capAutor != null) {
    final partesAut = descomponerTitulo(capAutor.titulo);
    secciones.add(SectionItem(
      id: 'sec_author',
      kind: SectionKind.author,
      matter: BookMatter.back,
      title: partesAut.etiqueta,
      subtitle: partesAut.subtitulo ?? '',
      fileName: 'autor.xhtml',
      inToc: true,
      enabled: true,
      htmlContent: capAutor.htmlCuerpo,
      htmlRaw: capAutor.htmlRaw,
      titleIsImage: capAutor.tituloEsImagen,
      titleImageNumber: capAutor.numeroImagenTitulo,
    ));
  } else {
    secciones.add(SectionItem(
      id: 'sec_author',
      kind: SectionKind.author,
      matter: BookMatter.back,
      title: 'Acerca del autor',
      fileName: 'autor.xhtml',
      inToc: true,
      enabled: false,
    ));
  }

  // Posición 16: Palabras del traductor (traductor.xhtml)
  if (capTraductor != null) {
    final partesTra = descomponerTitulo(capTraductor.titulo);
    secciones.add(SectionItem(
      id: 'sec_translator',
      kind: SectionKind.translator,
      matter: BookMatter.back,
      title: partesTra.etiqueta,
      subtitle: partesTra.subtitulo ?? '',
      fileName: 'traductor.xhtml',
      inToc: true,
      enabled: true,
      htmlContent: capTraductor.htmlCuerpo,
      htmlRaw: capTraductor.htmlRaw,
      titleIsImage: capTraductor.tituloEsImagen,
      titleImageNumber: capTraductor.numeroImagenTitulo,
    ));
  } else {
    secciones.add(SectionItem(
      id: 'sec_translator',
      kind: SectionKind.translator,
      matter: BookMatter.back,
      title: 'Palabras del traductor',
      fileName: 'traductor.xhtml',
      inToc: true,
      enabled: false,
    ));
  }

  // Posición 17: Contracubierta (contracubierta.xhtml)
  secciones.add(SectionItem(
    id: 'sec_backcover',
    kind: SectionKind.backCover,
    matter: BookMatter.back,
    title: 'Contracubierta',
    fileName: 'contracubierta.xhtml',
    inToc: false,
    enabled: true,
  ));

  // Posición 18: Notas al pie (notas.xhtml)
  final tieneNotas = res.notas.isNotEmpty;
  secciones.add(SectionItem(
    id: 'sec_notes',
    kind: SectionKind.notes,
    matter: BookMatter.back,
    title: 'Notas al pie',
    fileName: 'notas.xhtml',
    inToc: false,
    enabled: tieneNotas,
    htmlContent: tieneNotas ? renderNotas(res.notas) : '',
  ));

  // Posición 19: Navegación ePub (toc.xhtml)
  secciones.add(SectionItem(
    id: 'sec_toc_nav',
    kind: SectionKind.tocNav,
    matter: BookMatter.back,
    title: 'Navegación ePub',
    fileName: 'toc.xhtml',
    inToc: false,
    enabled: true,
  ));

  return secciones;
}

/// Convierte la lista de `SectionItem` de vuelta a `List<Chapter>` para renderizar
/// con las plantillas XHTML existentes.
List<Chapter> seccionesACapitulos(List<SectionItem> secciones) {
  final caps = <Chapter>[];
  for (final s in secciones) {
    if (!s.enabled) continue;
    // Solo procesar secciones de contenido narrativo
    const narrativeKinds = {
      SectionKind.prologue,
      SectionKind.chapter,
      SectionKind.interlude,
      SectionKind.part,
      SectionKind.extra,
      SectionKind.epilogue,
      SectionKind.author,
      SectionKind.translator,
    };
    if (!narrativeKinds.contains(s.kind)) continue;

    final (plantillaNombre, tipoForzado) = switch (s.kind) {
      SectionKind.prologue => ('prologo.xhtml', TipoEspecial.prologo),
      SectionKind.epilogue => ('epilogo.xhtml', TipoEspecial.epilogo),
      SectionKind.author => ('autor.xhtml', TipoEspecial.autor),
      SectionKind.translator => ('traductor.xhtml', TipoEspecial.traductor),
      SectionKind.interlude => (null, TipoEspecial.interludio),
      SectionKind.extra => (null, TipoEspecial.extra),
      _ => (null, null),
    };

    caps.add(Chapter(
      titulo: s.effectiveHeading,
      htmlCuerpo: s.htmlContent,
      htmlRaw: s.htmlRaw,
      archivo: s.fileName,
      plantillaNombre: plantillaNombre,
      tituloEsImagen: s.titleIsImage,
      numeroImagenTitulo: s.titleImageNumber,
      tipoForzado: tipoForzado,
    ));
  }
  return caps;
}
