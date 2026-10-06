import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'metadatos.dart';

String _descXml(String text) => text
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .trim();

/// Extrae de forma exhaustiva los metadatos de un ePub generado previamente
/// para reutilizarlos en volúmenes sucesivos (V2, V3, etc.).
BookMetadata extraerMetadatosDeEpub(Uint8List bytesEpub, {bool incrementarVolumen = true}) {
  final zip = ZipDecoder().decodeBytes(bytesEpub);
  String? opfHtml;
  String? tituloHtml;

  for (final f in zip.files) {
    final lower = f.name.toLowerCase();
    if (lower.endsWith('.opf')) {
      opfHtml = utf8.decode(f.content as List<int>);
    } else if (lower.endsWith('titulo.xhtml')) {
      tituloHtml = utf8.decode(f.content as List<int>);
    }
  }

  if (opfHtml == null) {
    return const BookMetadata();
  }

  // 1. Título y Colección de OPF
  String titleRaw = '';
  final matchTitle = RegExp(r'<dc:title[^>]*>(.*?)</dc:title>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchTitle != null) {
    titleRaw = _descXml(matchTitle.group(1)!);
  }

  String groupTag = '';
  final matchTag = RegExp(r'\[([^\]]+)\]\s*$').firstMatch(titleRaw);
  if (matchTag != null) {
    groupTag = matchTag.group(1)!.trim();
  }

  String series = '';
  final matchSerie = RegExp(
    r'<(?:opf:)?meta\b[^>]*(?:id="serie"[^>]*property="belongs-to-collection"|property="belongs-to-collection"[^>]*id="serie")[^>]*>(.*?)</(?:opf:)?meta>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(opfHtml) ??
  RegExp(r'<(?:opf:)?meta\b[^>]*name="calibre:series"[^>]*content="([^"]*)"', caseSensitive: false).firstMatch(opfHtml);
  if (matchSerie != null) {
    series = _descXml(matchSerie.group(1)!);
  }

  String volumeRaw = '';
  final matchVol = RegExp(
    r'<(?:opf:)?meta\b[^>]*(?:property="group-position"[^>]*refines="#serie"|refines="#serie"[^>]*property="group-position")[^>]*>(.*?)</(?:opf:)?meta>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(opfHtml) ??
  RegExp(r'<(?:opf:)?meta\b[^>]*name="calibre:series_index"[^>]*content="([^"]*)"', caseSensitive: false).firstMatch(opfHtml);
  if (matchVol != null) {
    volumeRaw = _descXml(matchVol.group(1)!);
  }

  // 2. Personas (Autor, Ilustrador, Traductor, Corrector)
  String author = '';
  final matchAuthor = RegExp(r'<dc:creator\s+id="creator01"[^>]*>(.*?)</dc:creator>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchAuthor != null) {
    author = _descXml(matchAuthor.group(1)!);
  }

  String authorJapanese = '';
  final matchAuthorJp = RegExp(
    r'<(?:opf:)?meta\b[^>]*(?:property="alternate-script"[^>]*refines="#creator01"|refines="#creator01"[^>]*property="alternate-script")[^>]*>(.*?)</(?:opf:)?meta>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(opfHtml);
  if (matchAuthorJp != null) {
    authorJapanese = _descXml(matchAuthorJp.group(1)!);
  }

  String authorFileAs = '';
  final matchAuthorFileAs = RegExp(
    r'<(?:opf:)?meta\b[^>]*(?:property="file-as"[^>]*refines="#creator01"|refines="#creator01"[^>]*property="file-as")[^>]*>(.*?)</(?:opf:)?meta>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(opfHtml);
  if (matchAuthorFileAs != null) {
    authorFileAs = _descXml(matchAuthorFileAs.group(1)!);
  }

  String illustrator = '';
  final matchIlus = RegExp(r'<dc:creator\s+id="creator02"[^>]*>(.*?)</dc:creator>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchIlus != null) {
    illustrator = _descXml(matchIlus.group(1)!);
  }

  String illustratorJapanese = '';
  final matchIlusJp = RegExp(
    r'<(?:opf:)?meta\b[^>]*(?:property="alternate-script"[^>]*refines="#creator02"|refines="#creator02"[^>]*property="alternate-script")[^>]*>(.*?)</(?:opf:)?meta>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(opfHtml);
  if (matchIlusJp != null) {
    illustratorJapanese = _descXml(matchIlusJp.group(1)!);
  }

  String illustratorFileAs = '';
  final matchIlusFileAs = RegExp(
    r'<(?:opf:)?meta\b[^>]*(?:property="file-as"[^>]*refines="#creator02"|refines="#creator02"[^>]*property="file-as")[^>]*>(.*?)</(?:opf:)?meta>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(opfHtml);
  if (matchIlusFileAs != null) {
    illustratorFileAs = _descXml(matchIlusFileAs.group(1)!);
  }

  String translator = '';
  final matchTrl = RegExp(r'<dc:contributor\s+id="contrib0?1"[^>]*>(.*?)</dc:contributor>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchTrl != null) {
    translator = _descXml(matchTrl.group(1)!);
  }

  String publisher = '';
  final matchPub = RegExp(r'<dc:publisher[^>]*>(.*?)</dc:publisher>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchPub != null) {
    publisher = _descXml(matchPub.group(1)!);
  }

  String bookType = 'Novela Ligera';
  final matchType = RegExp(r'<dc:type[^>]*>(.*?)</dc:type>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchType != null) {
    bookType = _descXml(matchType.group(1)!);
  }

  String language = 'es';
  final matchLang = RegExp(r'<dc:language[^>]*>(.*?)</dc:language>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchLang != null) {
    language = _descXml(matchLang.group(1)!);
  }

  // 3. Sinopsis y Clasificación
  String synopsis = '';
  final matchDesc = RegExp(r'<dc:description[^>]*>(.*?)</dc:description>', caseSensitive: false, dotAll: true).firstMatch(opfHtml);
  if (matchDesc != null) {
    synopsis = matchDesc.group(1)!
        .replaceAll(RegExp(r'&lt;br\s*/?&gt;|<br\s*/?>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    synopsis = _descXml(synopsis);
  }

  final subjects = <String>[];
  for (final m in RegExp(r'<dc:subject[^>]*>(.*?)</dc:subject>', caseSensitive: false, dotAll: true).allMatches(opfHtml)) {
    final s = _descXml(m.group(1)!);
    if (s.isNotEmpty && !subjects.contains(s)) {
      subjects.add(s);
    }
  }

  // 4. Identificadores
  String isbn13 = '';
  final matchIsbn13 = RegExp(r'<dc:identifier\s+id="isbn13"[^>]*>(?:urn:isbn:)?(.*?)</dc:identifier>', caseSensitive: false).firstMatch(opfHtml);
  if (matchIsbn13 != null) isbn13 = _descXml(matchIsbn13.group(1)!);

  String isbn10 = '';
  final matchIsbn10 = RegExp(r'<dc:identifier\s+id="isbn10"[^>]*>(?:urn:isbn:)?(.*?)</dc:identifier>', caseSensitive: false).firstMatch(opfHtml);
  if (matchIsbn10 != null) isbn10 = _descXml(matchIsbn10.group(1)!);

  String amazonId = '';
  final matchAmz = RegExp(r'<dc:identifier\s+id="amazon-id"[^>]*>(?:urn:amazon:)?(.*?)</dc:identifier>', caseSensitive: false).firstMatch(opfHtml);
  if (matchAmz != null) amazonId = _descXml(matchAmz.group(1)!);

  String projectUrl = '';
  final matchUri = RegExp(r'<dc:identifier\s+id="uri-id"[^>]*>(?:urn:uri:)?(.*?)</dc:identifier>', caseSensitive: false).firstMatch(opfHtml);
  if (matchUri != null) projectUrl = _descXml(matchUri.group(1)!);

  // 5. Datos desde titulo.xhtml si existe
  String titleSpanish = '';
  String subtitle = '';
  String proofreader = '';

  if (tituloHtml != null) {
    final matchTitEsp = RegExp(
      r'<span[^>]*class="(?:grande|large)"[^>]*epub:type="title"[^>]*>(.*?)</span>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(tituloHtml);
    if (matchTitEsp != null) {
      titleSpanish = _descXml(matchTitEsp.group(1)!);
    }

    final matchSub = RegExp(
      r'<span[^>]*epub:type="subtitle"[^>]*>(.*?)</span>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(tituloHtml);
    if (matchSub != null) {
      subtitle = _descXml(matchSub.group(1)!);
    }

    final matchCorr = RegExp(
      r'<p[^>]*><b>Corrección:</b>\s*(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(tituloHtml);
    if (matchCorr != null) {
      proofreader = _descXml(matchCorr.group(1)!);
    }

    if (translator.isEmpty) {
      final matchTrlTit = RegExp(
        r'<p[^>]*><b>Traducción al español:</b>\s*(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(tituloHtml);
      if (matchTrlTit != null) {
        translator = _descXml(matchTrlTit.group(1)!);
      }
    }

    if (projectUrl.isEmpty) {
      final matchUrlTit = RegExp(
        r'<p\s+class="(?:salto1|space-1)"><b>Página Web</b>\s*<br\s*/?>\s*<a\s+href="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(tituloHtml);
      if (matchUrlTit != null) {
        projectUrl = _descXml(matchUrlTit.group(1)!);
      }
    }

    if (volumeRaw.isEmpty) {
      final matchVolH2 = RegExp(
        r'<h2[^>]*class="[^"]*(?:subtitulo|subtitle)[^"]*"[^>]*>\s*(?:Volumen|Vol\.?)\s*(\d+.*?)<',
        caseSensitive: false,
      ).firstMatch(tituloHtml);
      if (matchVolH2 != null) {
        volumeRaw = _descXml(matchVolH2.group(1)!);
      }
    }
  }

  // 6. Deducir título en romaji/japonés a partir de dc:title
  String titleJapanese = '';
  if (titleRaw.isNotEmpty) {
    String tLimpio = titleRaw.replaceAll(RegExp(r'\s*\[[^\]]+\]\s*$'), '').trim();
    tLimpio = tLimpio.replaceAll(RegExp(r'\s*[-_–]\s*(?:Vol(?:umen|\.?)?)\s*\d+.*$', caseSensitive: false), '').trim();
    if (tLimpio.toLowerCase() != titleSpanish.toLowerCase()) {
      titleJapanese = tLimpio;
    }
  }

  if (titleSpanish.isEmpty) {
    titleSpanish = titleRaw.replaceAll(RegExp(r'\s*\[[^\]]+\]\s*$'), '').trim();
    titleSpanish = titleSpanish.replaceAll(RegExp(r'\s*[-_–]\s*(?:Vol(?:umen|\.?)?)\s*\d+.*$', caseSensitive: false), '').trim();
  }

  // 7. Calcular sugerencia para el siguiente volumen
  String siguienteVolumen = volumeRaw;
  if (incrementarVolumen) {
    final numLimpio = volumeRaw.replaceAll(RegExp(r'\D'), '');
    final n = int.tryParse(numLimpio);
    if (n != null) {
      siguienteVolumen = (n + 1).toString().padLeft(2, '0');
    } else if (volumeRaw.isEmpty) {
      siguienteVolumen = '02';
    }
  }

  return BookMetadata(
    title: titleSpanish,
    titleSpanish: titleSpanish,
    subtitle: subtitle,
    titleJapanese: titleJapanese,
    series: series.isNotEmpty ? series : titleSpanish,
    volume: siguienteVolumen,
    groupTag: groupTag,
    author: author,
    authorJapanese: authorJapanese,
    authorFileAs: authorFileAs,
    illustrator: illustrator,
    illustratorJapanese: illustratorJapanese,
    illustratorFileAs: illustratorFileAs,
    translator: translator,
    proofreader: proofreader,
    publisher: publisher,
    projectUrl: projectUrl,
    bookType: bookType,
    subjects: ordenarSubjectsCanonico(subjects),
    synopsis: synopsis,
    isbn13: incrementarVolumen ? '' : isbn13, // ISBN nuevo por volumen físico si se incrementa
    isbn10: incrementarVolumen ? '' : isbn10,
    amazonId: incrementarVolumen ? '' : amazonId, // ID nuevo por volumen si se incrementa
    language: language,
    bookId: uuidV7(), // Nuevo BookId único RFC 9562
    date: DateTime.now(),
  );
}
