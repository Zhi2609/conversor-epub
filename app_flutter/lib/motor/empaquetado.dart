import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'metadatos.dart';
import 'secciones.dart';

String _escXml(String text) => escXml(text);

class ArchivoEpubEntrada {
  final String nombre;
  final String contenidoHtml;

  const ArchivoEpubEntrada({
    required this.nombre,
    required this.contenidoHtml,
  });
}

class EntradaImagenEpub {
  final String nombreArchivo;
  final List<int> bytes;

  const EntradaImagenEpub({
    required this.nombreArchivo,
    required this.bytes,
  });
}

typedef ResultadoEmpaquetado = ({List<int> bytesEpub, List<String> avisos});

String generarUuidV4() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variante RFC 4122

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final _reUuidOpf = RegExp(r'<dc:identifier\s+id="BookId">.*?</dc:identifier>', caseSensitive: false);
final _reModifiedOpf = RegExp(r'<meta\s+property="dcterms:modified">.*?</meta>', caseSensitive: false);
final _reManifest = RegExp(r'<manifest>(.*?)</manifest>', dotAll: true, caseSensitive: false);
final _reSpine = RegExp(r'<spine\b[^>]*>(.*?)</spine>', dotAll: true, caseSensitive: false);
final _reItemOpf = RegExp(r'<item\b[^>]*>', dotAll: true, caseSensitive: false);
final _reItemrefOpf = RegExp(r'<itemref\b[^>]*>', dotAll: true, caseSensitive: false);
final _reNavTocOl = RegExp(r'(<nav\b[^>]*id="toc"[^>]*>\s*<h1>.*?</h1>\s*<ol>)(.*?)(</ol>)', dotAll: true, caseSensitive: false);
final _reNavLandmarksOl = RegExp(r'(<nav\b[^>]*id="landmarks"[^>]*>\s*<h\d>.*?</h\d>\s*<ol[^>]*>)(.*?)(</ol>)', dotAll: true, caseSensitive: false);
final _reImgSrc = RegExp(r'''src=["'](?:\.\./)?Images/([^"'#\?]+)["']''', caseSensitive: false);

ResultadoEmpaquetado empaquetarEpub({
  required List<int> bytesBaseEpub,
  required List<ArchivoEpubEntrada> capitulosYEspeciales,
  required List<String> ordenSpine,
  required List<({String archivo, String titulo})> entradasToc,
  String? contenidoNotas,
  List<EntradaImagenEpub> imagenes = const [],
  String? uuidCustom,
  DateTime? fechaModificacion,
  BookMetadata? metadatos,
  List<SectionItem>? secciones,
}) {
  final avisos = <String>[];
  final archiveBase = ZipDecoder().decodeBytes(bytesBaseEpub);
  final archivos = <String, Uint8List>{};

  for (final file in archiveBase.files) {
    if (file.name == 'mimetype' || file.name.endsWith('/')) continue;
    // Omitir Section000X.xhtml de muestra de la base
    if (RegExp(r'OEBPS/Text/Section\d+\.xhtml', caseSensitive: false).hasMatch(file.name)) {
      continue;
    }
    archivos[file.name] = file.content;
  }

  final nombresGenerados = capitulosYEspeciales.map((c) => c.nombre).toSet();
  final tienePrologo = nombresGenerados.any((n) => n.toLowerCase().startsWith('prologo')) ||
      (secciones?.any((s) => s.kind == SectionKind.prologue && s.enabled) ?? false);
  final tieneEpilogo = nombresGenerados.any((n) => n.toLowerCase().startsWith('epilogo')) ||
      (secciones?.any((s) => s.kind == SectionKind.epilogue && s.enabled) ?? false);
  final tieneAutor = nombresGenerados.any((n) => n.toLowerCase().startsWith('autor')) ||
      (secciones?.any((s) => s.kind == SectionKind.author && s.enabled) ?? false);
  final tieneTraductor = nombresGenerados.any((n) => n.toLowerCase().startsWith('traductor')) ||
      (secciones?.any((s) => s.kind == SectionKind.translator && s.enabled) ?? false);
  final tieneNotas = (contenidoNotas != null && contenidoNotas.trim().isNotEmpty) ||
      (secciones?.any((s) => s.kind == SectionKind.notes && s.enabled) ?? false);

  final deshabilitados = secciones != null
      ? secciones.where((s) => !s.enabled).map((s) => s.fileName.toLowerCase()).toSet()
      : <String>{};

  for (final des in deshabilitados) {
    archivos.removeWhere((k, _) => k.toLowerCase().endsWith('/$des') || k.toLowerCase().endsWith(des));
  }

  // Eliminar de archivos base los especiales que no existen en el manuscrito
  if (!tienePrologo || deshabilitados.contains('prologo.xhtml')) {
    archivos.removeWhere((k, _) => RegExp(r'OEBPS/Text/prologo.*\.xhtml$', caseSensitive: false).hasMatch(k));
  }
  if (!tieneEpilogo || deshabilitados.contains('epilogo.xhtml')) {
    archivos.removeWhere((k, _) => RegExp(r'OEBPS/Text/epilogo.*\.xhtml$', caseSensitive: false).hasMatch(k));
  }
  if (!tieneAutor || deshabilitados.contains('autor.xhtml')) {
    archivos.removeWhere((k, _) => RegExp(r'OEBPS/Text/autor.*\.xhtml$', caseSensitive: false).hasMatch(k));
  }
  if (!tieneTraductor || deshabilitados.contains('traductor.xhtml')) {
    archivos.removeWhere((k, _) => RegExp(r'OEBPS/Text/traductor.*\.xhtml$', caseSensitive: false).hasMatch(k));
  }
  if (!tieneNotas || deshabilitados.contains('notas.xhtml')) {
    archivos.remove('OEBPS/Text/notas.xhtml');
  }

  // Insertar capítulos y especiales generados
  for (final cap in capitulosYEspeciales) {
    if (!deshabilitados.contains(cap.nombre.toLowerCase())) {
      archivos['OEBPS/Text/${cap.nombre}'] = Uint8List.fromList(utf8.encode(cap.contenidoHtml));
    }
  }

  // Si hay secciones con contenido HTML personalizado que no fueron cubiertas por capitulosYEspeciales
  if (secciones != null) {
    for (final s in secciones) {
      if (!s.enabled || s.htmlContent.trim().isEmpty) continue;
      if (nombresGenerados.contains(s.fileName)) continue;
      if (s.kind == SectionKind.synopsis || s.kind == SectionKind.notes) continue;
      archivos['OEBPS/Text/${s.fileName}'] = Uint8List.fromList(utf8.encode(s.htmlContent));
    }
  }

  // Insertar notas si existen
  if (tieneNotas && !deshabilitados.contains('notas.xhtml')) {
    String notasHtmlBase;
    if (archivos.containsKey('OEBPS/Text/notas.xhtml')) {
      notasHtmlBase = utf8.decode(archivos['OEBPS/Text/notas.xhtml']!);
    } else {
      notasHtmlBase = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="es" xml:lang="es">
<head>
  <title>Notas</title>
  <link rel="stylesheet" type="text/css" href="../Styles/style.css"/>
  <meta charset="utf-8"/>
</head>
<body xml:lang="es" lang="es" epub:type="backmatter">
  <section epub:type="endnotes" aria-label="">
    <header>
      <h1 class="sigil_not_in_toc">Notas</h1>
    </header>
    <!-- Agregar notas con el siguiente formato -->
  </section>
</body>
</html>''';
    }

    const marcador = '<!-- Agregar notas con el siguiente formato -->';
    final textoNotas = (contenidoNotas ?? '').trim();
    String notasHtmlFinal;
    if (notasHtmlBase.contains(marcador)) {
      notasHtmlFinal = notasHtmlBase.replaceFirst(marcador, '$marcador\n$textoNotas');
    } else {
      notasHtmlFinal = notasHtmlBase.replaceFirst('</section>', '$textoNotas\n  </section>');
    }
    archivos['OEBPS/Text/notas.xhtml'] = Uint8List.fromList(utf8.encode(notasHtmlFinal));
  }

  // Insertar imágenes de usuario
  for (final img in imagenes) {
    archivos['OEBPS/Images/${img.nombreArchivo}'] = Uint8List.fromList(img.bytes);
  }

  // 1. Modificar content.opf
  final opfBytes = archivos['OEBPS/content.opf'];
  if (opfBytes != null) {
    String opf = utf8.decode(opfBytes);

    final uuidFinal = uuidCustom ?? (metadatos?.bookId.isNotEmpty == true ? metadatos!.bookId : generarUuidV4());
    opf = opf.replaceAll(_reUuidOpf, '<dc:identifier id="BookId">urn:uuid:$uuidFinal</dc:identifier>');

    final fechaUtc = '${(fechaModificacion ?? (metadatos?.date?.toUtc()) ?? DateTime.now().toUtc()).toIso8601String().split('.').first}Z';
    opf = opf.replaceAll(_reModifiedOpf, '<meta property="dcterms:modified">$fechaUtc</meta>');

    if (metadatos != null) {
      if (metadatos.effectiveTitle.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<dc:title>.*?</dc:title>', caseSensitive: false), '<dc:title>${_escXml(metadatos.effectiveTitle)}</dc:title>');
      }
      if (metadatos.date != null) {
        final fechaDateUtc = '${metadatos.date!.toUtc().toIso8601String().split('.').first}Z';
        opf = opf.replaceAll(RegExp(r'<dc:date>.*?</dc:date>', caseSensitive: false), '<dc:date>$fechaDateUtc</dc:date>');
      }
      if (metadatos.language.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<dc:language>.*?</dc:language>', caseSensitive: false), '<dc:language>${_escXml(metadatos.language)}</dc:language>');
      }
      if (metadatos.synopsis.isNotEmpty) {
        final parrafos = metadatos.synopsis
            .split(RegExp(r'\r?\n\s*\r?\n'))
            .map((p) => p.replaceAll(RegExp(r'\r?\n'), ' ').trim())
            .where((p) => p.isNotEmpty)
            .toList();
        final sinopsisOpf = parrafos.map((p) => _escXml(p)).join('&lt;br/&gt;&lt;br/&gt;');
        opf = opf.replaceAll(RegExp(r'<dc:description>.*?</dc:description>', caseSensitive: false), '<dc:description>$sinopsisOpf</dc:description>');
      }
      if (metadatos.bookType.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<dc:type>.*?</dc:type>', caseSensitive: false), '<dc:type>${_escXml(metadatos.bookType)}</dc:type>');
      }

      // Autor (creator01)
      if (metadatos.author.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<dc:creator\s+id="creator01">.*?</dc:creator>', caseSensitive: false), '<dc:creator id="creator01">${_escXml(metadatos.author)}</dc:creator>');
      }
      if (metadatos.authorJapanese.isNotEmpty) {
        opf = opf.replaceAll(
          RegExp(r'<meta\s+property="alternate-script"\s+refines="#creator01"[^>]*>.*?</meta>', caseSensitive: false),
          '<meta property="alternate-script" refines="#creator01" xml:lang="ja">${_escXml(metadatos.authorJapanese)}</meta>',
        );
      } else {
        opf = opf.replaceAll(
          RegExp(r'\s*<meta\s+property="alternate-script"\s+refines="#creator01"[^>]*>.*?</meta>', caseSensitive: false),
          '',
        );
      }
      if (metadatos.authorFileAs.isNotEmpty) {
        opf = opf.replaceAll(
          RegExp(r'<meta\s+property="file-as"\s+refines="#creator01"[^>]*>.*?</meta>', caseSensitive: false),
          '<meta property="file-as" refines="#creator01">${_escXml(metadatos.authorFileAs)}</meta>',
        );
      } else if (metadatos.author.isNotEmpty) {
        opf = opf.replaceAll(
          RegExp(r'<meta\s+property="file-as"\s+refines="#creator01"[^>]*>.*?</meta>', caseSensitive: false),
          '<meta property="file-as" refines="#creator01">${_escXml(metadatos.author)}</meta>',
        );
      }

      // Ilustrador (creator02)
      if (metadatos.illustrator.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<dc:creator\s+id="creator02">.*?</dc:creator>', caseSensitive: false), '<dc:creator id="creator02">${_escXml(metadatos.illustrator)}</dc:creator>');
        if (metadatos.illustratorJapanese.isNotEmpty) {
          opf = opf.replaceAll(
            RegExp(r'<meta\s+property="alternate-script"\s+refines="#creator02"[^>]*>.*?</meta>', caseSensitive: false),
            '<meta property="alternate-script" refines="#creator02" xml:lang="ja">${_escXml(metadatos.illustratorJapanese)}</meta>',
          );
        } else {
          opf = opf.replaceAll(
            RegExp(r'\s*<meta\s+property="alternate-script"\s+refines="#creator02"[^>]*>.*?</meta>', caseSensitive: false),
            '',
          );
        }
        if (metadatos.illustratorFileAs.isNotEmpty) {
          opf = opf.replaceAll(
            RegExp(r'<meta\s+property="file-as"\s+refines="#creator02"[^>]*>.*?</meta>', caseSensitive: false),
            '<meta property="file-as" refines="#creator02">${_escXml(metadatos.illustratorFileAs)}</meta>',
          );
        } else {
          opf = opf.replaceAll(
            RegExp(r'<meta\s+property="file-as"\s+refines="#creator02"[^>]*>.*?</meta>', caseSensitive: false),
            '<meta property="file-as" refines="#creator02">${_escXml(metadatos.illustrator)}</meta>',
          );
        }
      } else {
        opf = opf.replaceAll(RegExp(r'\s*<dc:creator\s+id="creator02">.*?</dc:creator>', caseSensitive: false), '');
        opf = opf.replaceAll(RegExp(r'\s*<meta\b[^>]*refines="#creator02"[^>]*>.*?</meta>', caseSensitive: false), '');
      }

      // Traductor (contrib1)
      if (metadatos.translator.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<dc:contributor\s+id="contrib1">.*?</dc:contributor>', caseSensitive: false), '<dc:contributor id="contrib1">${_escXml(metadatos.translator)}</dc:contributor>');
      }

      // Corrector / mrk (contrib2)
      final corrector = metadatos.proofreader.isNotEmpty ? metadatos.proofreader : 'Zhi';
      opf = opf.replaceAll(RegExp(r'<dc:contributor\s+id="contrib2">.*?</dc:contributor>', caseSensitive: false), '<dc:contributor id="contrib2">${_escXml(corrector)}</dc:contributor>');

      // Distribuidor (contrib3) siempre 'ZeePubs' (canónico inmutable)
      opf = opf.replaceAll(
        RegExp(r'<dc:contributor\s+id="contrib3">.*?</dc:contributor>', caseSensitive: false),
        '<dc:contributor id="contrib3">${BookMetadata.defaultDistributor}</dc:contributor>',
      );

      // Editorial / Publicador
      if (metadatos.publisher.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<dc:publisher>.*?</dc:publisher>', caseSensitive: false), '<dc:publisher>${_escXml(metadatos.publisher)}</dc:publisher>');
      } else {
        opf = opf.replaceAll(RegExp(r'\s*<dc:publisher>.*?</dc:publisher>', caseSensitive: false), '');
      }

      // Subjects (Taxonomía / Demografía y Géneros según orden estricto de ZeePubs)
      if (metadatos.subjects.isNotEmpty) {
        final subjectsCanonicos = ordenarSubjectsCanonico(metadatos.subjects);
        final nuevosSubjects = subjectsCanonicos
            .where((s) => s.trim().isNotEmpty)
            .map((s) => '    <dc:subject>${_escXml(s.trim())}</dc:subject>')
            .join('\n');
        final reTodosSubjects = RegExp(r'(?:\s*<dc:subject>.*?</dc:subject>)+', caseSensitive: false);
        if (reTodosSubjects.hasMatch(opf)) {
          opf = opf.replaceFirst(reTodosSubjects, '\n$nuevosSubjects');
        }
      }

      // Identificadores: isbn13, isbn10, amazon-id, uri-id
      if (metadatos.isbn13.isNotEmpty) {
        final isbn13Formateado = formatearIsbn13(metadatos.isbn13);
        opf = opf.replaceAll(
          RegExp(r'<dc:identifier\s+id="isbn13">.*?</dc:identifier>', caseSensitive: false),
          '<dc:identifier id="isbn13">urn:isbn:${_escXml(isbn13Formateado)}</dc:identifier>',
        );
      } else {
        opf = opf.replaceAll(RegExp(r'\s*<dc:identifier\s+id="isbn13">.*?</dc:identifier>', caseSensitive: false), '');
        opf = opf.replaceAll(RegExp(r'\s*<meta\b[^>]*refines="#isbn13"[^>]*>.*?</meta>', caseSensitive: false), '');
      }

      if (metadatos.isbn10.isNotEmpty) {
        final isbn10Formateado = formatearIsbn10(metadatos.isbn10);
        opf = opf.replaceAll(
          RegExp(r'<dc:identifier\s+id="isbn10">.*?</dc:identifier>', caseSensitive: false),
          '<dc:identifier id="isbn10">urn:isbn:${_escXml(isbn10Formateado)}</dc:identifier>',
        );
      } else {
        opf = opf.replaceAll(RegExp(r'\s*<dc:identifier\s+id="isbn10">.*?</dc:identifier>', caseSensitive: false), '');
        opf = opf.replaceAll(RegExp(r'\s*<meta\b[^>]*refines="#isbn10"[^>]*>.*?</meta>', caseSensitive: false), '');
      }

      if (metadatos.amazonId.isNotEmpty) {
        opf = opf.replaceAll(
          RegExp(r'<dc:identifier\s+id="amazon-id">.*?</dc:identifier>', caseSensitive: false),
          '<dc:identifier id="amazon-id">urn:amazon:${_escXml(metadatos.amazonId)}</dc:identifier>',
        );
      } else {
        opf = opf.replaceAll(RegExp(r'\s*<dc:identifier\s+id="amazon-id">.*?</dc:identifier>', caseSensitive: false), '');
        opf = opf.replaceAll(RegExp(r'\s*<meta\b[^>]*refines="#amazon-id"[^>]*>.*?</meta>', caseSensitive: false), '');
      }

      if (metadatos.projectUrl.isNotEmpty) {
        opf = opf.replaceAll(
          RegExp(r'<dc:identifier\s+id="uri-id">.*?</dc:identifier>', caseSensitive: false),
          '<dc:identifier id="uri-id">urn:uri:${_escXml(metadatos.projectUrl)}</dc:identifier>',
        );
      } else {
        opf = opf.replaceAll(RegExp(r'\s*<dc:identifier\s+id="uri-id">.*?</dc:identifier>', caseSensitive: false), '');
        opf = opf.replaceAll(RegExp(r'\s*<meta\b[^>]*refines="#uri-id"[^>]*>.*?</meta>', caseSensitive: false), '');
      }

      // Series y Colección
      if (metadatos.series.isNotEmpty) {
        opf = opf.replaceAll(RegExp(r'<meta\s+id="serie"\s+property="belongs-to-collection">.*?</meta>', caseSensitive: false), '<meta id="serie" property="belongs-to-collection">${_escXml(metadatos.series)}</meta>');
        opf = opf.replaceAll(RegExp(r'<meta\s+property="group-position"\s+refines="#serie">.*?</meta>', caseSensitive: false), '<meta property="group-position" refines="#serie">${_escXml(metadatos.volume.isNotEmpty ? metadatos.volume : '1')}</meta>');
        opf = opf.replaceAll(RegExp(r'<meta\s+content=".*?"\s+name="calibre:series"/>', caseSensitive: false), '<meta content="${_escXml(metadatos.series)}" name="calibre:series"/>');
        opf = opf.replaceAll(RegExp(r'<meta\s+content=".*?"\s+name="calibre:series_index"/>', caseSensitive: false), '<meta content="${_escXml(metadatos.volume.isNotEmpty ? metadatos.volume : '1')}" name="calibre:series_index"/>');
      }

      // Calibre rating: inmutable = 9
      opf = opf.replaceAll(
        RegExp(r'<meta\s+content=".*?"\s+name="calibre:rating"/>', caseSensitive: false),
        '<meta content="${BookMetadata.calibreRating}" name="calibre:rating"/>',
      );
    }

    // Limpiar manifest
    opf = opf.replaceFirstMapped(_reManifest, (m) {
      final lineas = m.group(1)!.split('\n');
      final nuevasLineas = <String>[];

      for (final l in lineas) {
        final match = _reItemOpf.firstMatch(l);
        if (match == null) {
          if (l.trim().isNotEmpty) nuevasLineas.add(l);
          continue;
        }

        final item = match.group(0)!;
        if (item.contains('Section000') || item.contains('Section0001') || item.contains('Section0002')) {
          continue;
        }
        if ((!tienePrologo || deshabilitados.contains('prologo.xhtml')) && item.contains('prologo.xhtml')) continue;
        if ((!tieneEpilogo || deshabilitados.contains('epilogo.xhtml')) && item.contains('epilogo.xhtml')) continue;
        if ((!tieneAutor || deshabilitados.contains('autor.xhtml')) && item.contains('autor.xhtml')) continue;
        if ((!tieneTraductor || deshabilitados.contains('traductor.xhtml')) && item.contains('traductor.xhtml')) continue;
        if ((!tieneNotas || deshabilitados.contains('notas.xhtml')) && item.contains('notas.xhtml')) continue;
        if (deshabilitados.any((d) => item.toLowerCase().contains(d))) continue;

        nuevasLineas.add(l);
      }

      // Añadir items generados si no existen
      for (final cap in capitulosYEspeciales) {
        if (deshabilitados.contains(cap.nombre.toLowerCase())) continue;
        final href = 'Text/${cap.nombre}';
        if (!nuevasLineas.any((l) => l.contains('href="$href"'))) {
          nuevasLineas.add('    <item id="${cap.nombre}" href="$href" media-type="application/xhtml+xml"/>');
        }
      }

      if (secciones != null) {
        for (final sec in secciones) {
          if (!sec.enabled) continue;
          final href = 'Text/${sec.fileName}';
          if (!nuevasLineas.any((l) => l.contains('href="$href"'))) {
            final idItem = (sec.fileName == 'contenido-1.xhtml') ? 'contenido.xhtml' : sec.fileName;
            nuevasLineas.add('    <item id="$idItem" href="$href" media-type="application/xhtml+xml"/>');
          }
        }
      }

      if (tieneNotas && !deshabilitados.contains('notas.xhtml') && !nuevasLineas.any((l) => l.contains('href="Text/notas.xhtml"'))) {
        nuevasLineas.add('    <item id="notas.xhtml" href="Text/notas.xhtml" media-type="application/xhtml+xml"/>');
      }

      // Añadir nuevas imágenes si no existen
      for (final img in imagenes) {
        final href = 'Images/${img.nombreArchivo}';
        if (!nuevasLineas.any((l) => l.contains('href="$href"'))) {
          final idImg = RegExp(r'^\d').hasMatch(img.nombreArchivo) ? 'x${img.nombreArchivo}' : img.nombreArchivo;
          final ext = img.nombreArchivo.split('.').last.toLowerCase();
          String mediaType = 'image/jpeg';
          if (ext == 'png') mediaType = 'image/png';
          if (ext == 'webp') mediaType = 'image/webp';
          if (ext == 'gif') mediaType = 'image/gif';
          if (ext == 'svg') mediaType = 'image/svg+xml';

          nuevasLineas.add('    <item id="$idImg" href="$href" media-type="$mediaType"/>');
        }
      }

      return '<manifest>\n${nuevasLineas.join('\n')}\n  </manifest>';
    });

    // Limpiar spine
    opf = opf.replaceFirstMapped(_reSpine, (m) {
      if (secciones != null) {
        final lineasSpine = <String>[];
        for (final s in secciones.where((s) => s.enabled)) {
          final idref = (s.fileName == 'contenido-1.xhtml') ? 'contenido.xhtml' : s.fileName;
          if (s.fileName == 'cubierta.xhtml') {
            lineasSpine.add('    <itemref idref="$idref" linear="yes"/>');
          } else if (s.fileName == 'toc.xhtml') {
            lineasSpine.add('    <itemref idref="$idref" linear="no"/>');
          } else {
            lineasSpine.add('    <itemref idref="$idref"/>');
          }
        }
        if (!deshabilitados.contains('toc.xhtml') &&
            archivos.containsKey('OEBPS/Text/toc.xhtml') &&
            !lineasSpine.any((l) => l.contains('idref="toc.xhtml"'))) {
          lineasSpine.add('    <itemref idref="toc.xhtml" linear="no"/>');
        }
        return '<spine>\n${lineasSpine.join('\n')}\n  </spine>';
      }

      final lineas = m.group(1)!.split('\n');
      final frontSpine = <String>[];
      final backSpine = <String>[];

      bool despuesDeNarrativa = false;
      for (final l in lineas) {
        final match = _reItemrefOpf.firstMatch(l);
        if (match == null) {
          if (l.trim().isNotEmpty) (despuesDeNarrativa ? backSpine : frontSpine).add(l);
          continue;
        }

        final itemref = match.group(0)!;
        if (itemref.contains('Section000') ||
            itemref.contains('prologo') ||
            itemref.contains('epilogo') ||
            itemref.contains('autor') ||
            itemref.contains('traductor') ||
            itemref.contains('notas')) {
          despuesDeNarrativa = true;
          continue;
        }

        if (deshabilitados.any((d) => itemref.toLowerCase().contains(d))) {
          continue;
        }

        if (itemref.contains('contracubierta') || itemref.contains('toc.xhtml')) {
          despuesDeNarrativa = true;
          backSpine.add(l);
          continue;
        }

        if (!despuesDeNarrativa) {
          frontSpine.add(l);
        } else {
          backSpine.add(l);
        }
      }

      final narrativaSpine = <String>[];
      for (final arch in ordenSpine) {
        if (!deshabilitados.contains(arch.toLowerCase())) {
          narrativaSpine.add('    <itemref idref="$arch"/>');
        }
      }

      // Si hay notas, insertarlas antes de toc.xhtml
      final finalBack = <String>[];
      for (final b in backSpine) {
        if (tieneNotas && !deshabilitados.contains('notas.xhtml') && b.contains('toc.xhtml')) {
          finalBack.add('    <itemref idref="notas.xhtml"/>');
        }
        finalBack.add(b);
      }
      if (tieneNotas && !deshabilitados.contains('notas.xhtml') && !finalBack.any((l) => l.contains('idref="notas.xhtml"'))) {
        finalBack.add('    <itemref idref="notas.xhtml"/>');
      }

      final todosSpine = [...frontSpine, ...narrativaSpine, ...finalBack];
      return '<spine>\n${todosSpine.join('\n')}\n  </spine>';
    });

    archivos['OEBPS/content.opf'] = Uint8List.fromList(utf8.encode(opf));
  }

  // Modificar titulo.xhtml si existe
  final tituloBytes = archivos['OEBPS/Text/titulo.xhtml'];
  if (tituloBytes != null && metadatos != null) {
    String tituloHtml = utf8.decode(tituloBytes);
    final titEspanol = metadatos.effectiveTitleSpanish;
    if (titEspanol.isNotEmpty) {
      tituloHtml = tituloHtml.replaceAllMapped(
        RegExp(r'(<span\s+class="grande"\s+epub:type="title">).*?(</span>)', caseSensitive: false),
        (m) => '${m.group(1)}${_escXml(titEspanol)}${m.group(2)}',
      );
    }
    final reSubtitle = RegExp(r'<br\s*/?>\s*<span\s+epub:type="subtitle"[^>]*>.*?</span>', caseSensitive: false);
    if (metadatos.subtitle.trim().isNotEmpty) {
      final subSpan = '<br/><span epub:type="subtitle" role="doc-subtitle">${_escXml(metadatos.subtitle.trim())}</span>';
      if (reSubtitle.hasMatch(tituloHtml)) {
        tituloHtml = tituloHtml.replaceAll(reSubtitle, subSpan);
      } else {
        tituloHtml = tituloHtml.replaceAllMapped(
          RegExp(r'(<span\s+class="grande"\s+epub:type="title">.*?</span>)', caseSensitive: false),
          (m) => '${m.group(1)}\n$subSpan',
        );
      }
    } else {
      tituloHtml = tituloHtml.replaceAll(reSubtitle, '');
    }
    if (metadatos.volume.isNotEmpty) {
      final tipoLibro = metadatos.bookType.isNotEmpty ? metadatos.bookType : 'Novela Ligera';
      tituloHtml = tituloHtml.replaceAll(
        RegExp(r'<h2\s+class="subtitulo\s+sigil_not_in_toc">.*?</h2>', caseSensitive: false, dotAll: true),
        '<h2 class="subtitulo sigil_not_in_toc">Volumen ${_escXml(metadatos.volume)}<br/><small>[$tipoLibro]</small></h2>',
      );
    }
    if (metadatos.author.isNotEmpty || metadatos.authorJapanese.isNotEmpty) {
      final autorStr = metadatos.authorJapanese.isNotEmpty
          ? '<ruby>${_escXml(metadatos.authorJapanese)}<rp>(</rp><rt>${_escXml(metadatos.author)}</rt><rp>)</rp></ruby>'
          : _escXml(metadatos.author);
      tituloHtml = tituloHtml.replaceAll(
        RegExp(r'<p\s+class="salto1"><b>Autor:</b>.*?</p>', caseSensitive: false),
        '<p class="salto1"><b>Autor:</b> $autorStr</p>',
      );
    }
    if (metadatos.illustrator.isNotEmpty || metadatos.illustratorJapanese.isNotEmpty) {
      final ilustradorStr = metadatos.illustratorJapanese.isNotEmpty
          ? '<ruby>${_escXml(metadatos.illustratorJapanese)}<rp>(</rp><rt>${_escXml(metadatos.illustrator)}</rt><rp>)</rp></ruby>'
          : _escXml(metadatos.illustrator);
      tituloHtml = tituloHtml.replaceAll(
        RegExp(r'<p><b>Ilustraciones:</b>.*?</p>', caseSensitive: false),
        '<p><b>Ilustraciones:</b> $ilustradorStr</p>',
      );
    }
    if (metadatos.translator.isNotEmpty) {
      tituloHtml = tituloHtml.replaceAll(
        RegExp(r'<p><b>Traducción al español:</b>.*?</p>', caseSensitive: false),
        '<p><b>Traducción al español:</b> ${_escXml(metadatos.translator)}</p>',
      );
    }
    if (metadatos.proofreader.isNotEmpty) {
      tituloHtml = tituloHtml.replaceAll(
        RegExp(r'<p><b>Corrección:</b>.*?</p>', caseSensitive: false),
        '<p><b>Corrección:</b> ${_escXml(metadatos.proofreader)}</p>',
      );
    }
    if (metadatos.projectUrl.isNotEmpty) {
      tituloHtml = tituloHtml.replaceAll(
        RegExp(r'<p\s+class="salto1"><b>Página Web</b><br/>\s*<a\s+href="[^"]*">.*?</a></p>', caseSensitive: false),
        '<p class="salto1"><b>Página Web</b><br/>\n        <a href="${_escXml(metadatos.projectUrl)}">${_escXml(metadatos.projectUrl)}</a></p>',
      );
    }
    archivos['OEBPS/Text/titulo.xhtml'] = Uint8List.fromList(utf8.encode(tituloHtml));
  }

  // Modificar cubierta.xhtml si hay imagen asociada
  final cubiertaBytes = archivos['OEBPS/Text/cubierta.xhtml'];
  if (cubiertaBytes != null && secciones != null) {
    final coverSec = secciones.where((s) => s.kind == SectionKind.cover && s.associatedImage != null && s.associatedImage!.isNotEmpty).firstOrNull;
    if (coverSec != null) {
      String cubiertaHtml = utf8.decode(cubiertaBytes);
      cubiertaHtml = cubiertaHtml.replaceAll(
        RegExp(r'''src=["'](?:\.\./)?Images/[^"']+["']''', caseSensitive: false),
        'src="../Images/${coverSec.associatedImage}"',
      );
      archivos['OEBPS/Text/cubierta.xhtml'] = Uint8List.fromList(utf8.encode(cubiertaHtml));
    }
  }

  // Modificar sinopsis.xhtml / resumen.xhtml si se proporcionó sinopsis
  if (metadatos != null && metadatos.synopsis.trim().isNotEmpty) {
    String? sinopsisKey = archivos.containsKey('OEBPS/Text/sinopsis.xhtml')
        ? 'OEBPS/Text/sinopsis.xhtml'
        : (archivos.containsKey('OEBPS/Text/resumen.xhtml') ? 'OEBPS/Text/resumen.xhtml' : null);
    if (sinopsisKey != null) {
      final parrafos = metadatos.synopsis.split(RegExp(r'\n\s*\n|\n')).where((p) => p.trim().isNotEmpty);
      final pTags = parrafos.map((p) => '    <p>${_escXml(p.trim())}</p>').join('\n');
      final nuevoHtml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="es" xml:lang="es">
<head>
  <title>Sinopsis</title>
  <link rel="stylesheet" type="text/css" href="../Styles/style.css"/>
  <meta charset="utf-8"/>
</head>
<body xml:lang="es" lang="es" epub:type="bodymatter">
  <section epub:type="abstract" id="abstract" aria-label="Sinopsis">
    <blockquote class="aviso">
      <p class="grande centrado"><b>Advertencia:</b></p>
      <p class="salto0">Esta novela contiene material y/o lenguaje que para algunos podría resultar ofensivo, explícito y vulgar, si usted es una persona sensible, se recomienda abstenerse de leerlo.</p>
    </blockquote>
    <hr class="sigil_split_marker"/>
    <!-- Borrar todo lo anterior si no se requiere -->
    <header>
      <h1 class="sigil_not_in_toc">Sinopsis</h1>
    </header>
$pTags
  </section>
</body>
</html>''';
      archivos[sinopsisKey] = Uint8List.fromList(utf8.encode(nuevoHtml));
    }
  }

  // 2. Modificar toc.xhtml
  final tocBytes = archivos['OEBPS/Text/toc.xhtml'];
  if (tocBytes != null) {
    String toc = utf8.decode(tocBytes);

    // Actualizar nav toc ol
    toc = toc.replaceFirstMapped(_reNavTocOl, (m) {
      final prefix = m.group(1)!;
      final olContenido = m.group(2)!;
      final suffix = m.group(3)!;

      if (secciones != null) {
        final itemsToc = <String>[];
        for (final ent in entradasToc) {
          itemsToc.add('      <li>\n        <a href="${ent.archivo}">${_escXml(ent.titulo)}</a>\n      </li>');
        }
        return '$prefix\n${itemsToc.join('\n')}\n    $suffix';
      }

      final itemsFijos = <String>[];
      final reLi = RegExp(r'<li>\s*<a\b[^>]*href="([^"]*)"[^>]*>(.*?)</a>\s*</li>', dotAll: true, caseSensitive: false);

      for (final match in reLi.allMatches(olContenido)) {
        final href = match.group(1)!;
        final texto = match.group(2)!.trim();

        if (deshabilitados.any((d) => href.toLowerCase().contains(d))) continue;

        if (href.contains('cubierta.xhtml') ||
            href.contains('resumen.xhtml') ||
            href.contains('perfil.xhtml') ||
            href.contains('titulo.xhtml') ||
            href.contains('contenido-1.xhtml') ||
            href.contains('epigrafe.xhtml') ||
            href.contains('prefacio.xhtml')) {
          itemsFijos.add('      <li>\n        <a href="$href">$texto</a>\n      </li>');
        }
      }

      final itemsNarrativa = <String>[];
      for (final ent in entradasToc) {
        itemsNarrativa.add('      <li>\n        <a href="${ent.archivo}">${ent.titulo}</a>\n      </li>');
      }

      return '$prefix\n${[...itemsFijos, ...itemsNarrativa].join('\n')}\n    $suffix';
    });

    // Actualizar nav landmarks ol
    toc = toc.replaceFirstMapped(_reNavLandmarksOl, (m) {
      final prefix = m.group(1)!;
      final olContenido = m.group(2)!;
      final suffix = m.group(3)!;

      final itemsLandmarks = <String>[];
      final reLi = RegExp(r'<li>\s*<a\b[^>]*>(.*?)</a>\s*</li>', dotAll: true, caseSensitive: false);

      for (final match in reLi.allMatches(olContenido)) {
        final liCompleto = match.group(0)!;
        if (liCompleto.contains('prologo.xhtml') ||
            liCompleto.contains('Section000') ||
            liCompleto.contains('bodymatter') ||
            liCompleto.contains('epilogo.xhtml') ||
            liCompleto.contains('autor.xhtml') ||
            liCompleto.contains('traductor.xhtml') ||
            liCompleto.contains('notas.xhtml')) {
          continue;
        }
        if (deshabilitados.any((d) => liCompleto.toLowerCase().contains(d))) {
          continue;
        }
        itemsLandmarks.add('      $liCompleto');
      }

      // Reinsertar landmarks narrativos según correspondan
      if (tienePrologo && !deshabilitados.contains('prologo.xhtml')) {
        final prologoArch = ordenSpine.firstWhere((a) => a.toLowerCase().startsWith('prologo'), orElse: () => 'prologo.xhtml');
        itemsLandmarks.add('      <li>\n        <a href="$prologoArch" epub:type="prologue">Prólogo</a>\n      </li>');
      }

      final primerCapitulo = secciones
              ?.where((s) => s.enabled && s.matter == BookMatter.body && s.kind != SectionKind.prologue)
              .map((s) => s.fileName)
              .firstOrNull ??
          ordenSpine.firstWhere(
            (a) => !a.toLowerCase().startsWith('prologo') && !a.toLowerCase().startsWith('cubierta'),
            orElse: () => ordenSpine.isNotEmpty ? ordenSpine.first : 'C01.xhtml',
          );
      itemsLandmarks.add('      <li>\n        <a href="$primerCapitulo" epub:type="bodymatter">Contenido principal</a>\n      </li>');

      if (tieneEpilogo && !deshabilitados.contains('epilogo.xhtml')) {
        final epilogoArch = ordenSpine.firstWhere((a) => a.toLowerCase().startsWith('epilogo'), orElse: () => 'epilogo.xhtml');
        itemsLandmarks.add('      <li>\n        <a href="$epilogoArch" epub:type="epilogue">Epílogo</a>\n      </li>');
      }

      if (tieneAutor && !deshabilitados.contains('autor.xhtml')) {
        final autorArch = ordenSpine.firstWhere((a) => a.toLowerCase().startsWith('autor'), orElse: () => 'autor.xhtml');
        itemsLandmarks.add('      <li>\n        <a href="$autorArch" epub:type="afterword">Palabras finales</a>\n      </li>');
      }

      if (tieneTraductor && !deshabilitados.contains('traductor.xhtml')) {
        final traductorArch = ordenSpine.firstWhere((a) => a.toLowerCase().startsWith('traductor'), orElse: () => 'traductor.xhtml');
        itemsLandmarks.add('      <li>\n        <a href="$traductorArch" epub:type="conclusion">Palabras del traductor</a>\n      </li>');
      }

      if (tieneNotas) {
        itemsLandmarks.add('      <li>\n        <a href="notas.xhtml" epub:type="endnotes">Notas</a>\n      </li>');
      }

      // toc landmark
      itemsLandmarks.add('      <li>\n        <a href="#toc" epub:type="toc">Índice de contenido</a>\n      </li>');

      return '$prefix\n${itemsLandmarks.join('\n')}\n    $suffix';
    });

    archivos['OEBPS/Text/toc.xhtml'] = Uint8List.fromList(utf8.encode(toc));
  }

  // 3. Revisar referencias a imágenes faltantes
  final imagenesExistentes = archivos.keys
      .where((k) => k.startsWith('OEBPS/Images/'))
      .map((k) => k.replaceFirst('OEBPS/Images/', ''))
      .toSet();

  for (final entry in archivos.entries) {
    if (!entry.key.endsWith('.xhtml')) continue;
    final html = utf8.decode(entry.value);
    for (final m in _reImgSrc.allMatches(html)) {
      final imgRef = m.group(1)!;
      if (!imagenesExistentes.contains(imgRef)) {
        final nombreDoc = entry.key.replaceFirst('OEBPS/Text/', '');
        avisos.add('⚠️ La imagen "$imgRef" referenciada en "$nombreDoc" no existe en el ePub.');
      }
    }
  }

  // 4. Crear archivo EPUB (ZIP)
  final archiveFinal = Archive();

  // mimetype como primer archivo sin compresión
  final mimetypeBytes = utf8.encode('application/epub+zip');
  final mimetypeFile = ArchiveFile.noCompress('mimetype', mimetypeBytes.length, mimetypeBytes);
  archiveFinal.addFile(mimetypeFile);

  // META-INF primero
  final clavesOrdenadas = archivos.keys.toList()
    ..sort((a, b) {
      if (a.startsWith('META-INF') && !b.startsWith('META-INF')) return -1;
      if (!a.startsWith('META-INF') && b.startsWith('META-INF')) return 1;
      if (a == 'OEBPS/content.opf') return -1;
      if (b == 'OEBPS/content.opf') return 1;
      return a.compareTo(b);
    });

  for (final clave in clavesOrdenadas) {
    final bytes = archivos[clave]!;
    archiveFinal.addFile(ArchiveFile(clave, bytes.length, bytes));
  }

  final zipData = ZipEncoder().encodeBytes(archiveFinal);
  return (bytesEpub: zipData, avisos: avisos);
}
