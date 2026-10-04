import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:conversor_epub/motor/empaquetado.dart';
import 'package:conversor_epub/motor/metadatos.dart';
import 'package:conversor_epub/motor/secciones.dart';
import 'package:conversor_epub/motor/modelo.dart';

void main() {
  group('TestEmpaquetadoConMetadatosYSecciones', () {
    late Uint8List bytesBase;

    setUp(() {
      File fileBase = File('assets/Base3_v1.15.0.epub');
      if (!fileBase.existsSync()) {
        fileBase = File('../assets/Base3_v1.15.0.epub');
      }
      if (!fileBase.existsSync()) {
        fileBase = File('../Base3_v1.15.0.epub');
      }
      expect(fileBase.existsSync(), isTrue, reason: 'Base3_v1.15.0.epub debe existir');
      bytesBase = fileBase.readAsBytesSync();
    });

    test('Inyecta metadatos en content.opf, titulo.xhtml y sinopsis.xhtml', () {
      final metadatos = BookMetadata(
        title: 'Mi Gran Novela Ligera',
        series: 'Mi Gran Novela Ligera',
        volume: '05',
        author: 'Autor Legendario',
        illustrator: 'Artista Pro',
        translator: 'Equipo ZeePubs',
        synopsis: 'Esta es una sinopsis emocionante sobre un héroe.\nUn nuevo mundo lo espera.',
        bookId: '12345678-1234-7123-8123-123456789abc',
      );

      final caps = [
        ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>Capítulo 1</p>'),
      ];

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: caps,
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'Capítulo 1')],
        metadatos: metadatos,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final mapArchivos = {for (var f in zip.files) f.name: f.content as List<int>};

      // 1. Verificar content.opf
      final opf = utf8.decode(mapArchivos['OEBPS/content.opf']!);
      expect(opf.contains('<dc:title>Mi Gran Novela Ligera - Volumen 05</dc:title>'), isTrue);
      expect(opf.contains('<dc:creator id="creator01">Autor Legendario</dc:creator>'), isTrue);
      expect(opf.contains('<dc:creator id="creator02">Artista Pro</dc:creator>'), isTrue);
      expect(opf.contains('<dc:contributor id="contrib1">Equipo ZeePubs</dc:contributor>'), isTrue);
      expect(opf.contains('<dc:description>Esta es una sinopsis emocionante sobre un héroe.'), isTrue);
      expect(opf.contains('urn:uuid:12345678-1234-7123-8123-123456789abc'), isTrue);

      // 2. Verificar titulo.xhtml
      final titulo = utf8.decode(mapArchivos['OEBPS/Text/titulo.xhtml']!);
      expect(titulo.contains('Mi Gran Novela Ligera</span>'), isTrue);
      expect(titulo.contains('Volumen 05'), isTrue);
      expect(titulo.contains('<b>Autor:</b> Autor Legendario</p>'), isTrue);
      expect(titulo.contains('<b>Ilustraciones:</b> Artista Pro</p>'), isTrue);
      expect(titulo.contains('<b>Traducción al español:</b> Equipo ZeePubs</p>'), isTrue);

      // 3. Verificar sinopsis / resumen.xhtml
      final sinopsisKey = mapArchivos.containsKey('OEBPS/Text/sinopsis.xhtml')
          ? 'OEBPS/Text/sinopsis.xhtml'
          : 'OEBPS/Text/resumen.xhtml';
      final sinopsisHtml = utf8.decode(mapArchivos[sinopsisKey]!);
      expect(sinopsisHtml.contains('<p>Esta es una sinopsis emocionante sobre un héroe.</p>'), isTrue);
      expect(sinopsisHtml.contains('<p>Un nuevo mundo lo espera.</p>'), isTrue);
    });

    test('Excluye secciones deshabilitadas del EPUB, manifest y spine', () {
      final secciones = [
        SectionItem(id: 'c1', kind: SectionKind.chapter, matter: BookMatter.body, title: 'C1', fileName: 'C01.xhtml', enabled: true),
        SectionItem(id: 'c2', kind: SectionKind.chapter, matter: BookMatter.body, title: 'C2 Descartado', fileName: 'C02.xhtml', enabled: false),
        SectionItem(id: 'pro', kind: SectionKind.prologue, matter: BookMatter.body, title: 'Prólogo', fileName: 'prologo.xhtml', enabled: false),
      ];

      final caps = [
        ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>C1</p>'),
        ArchivoEpubEntrada(nombre: 'C02.xhtml', contenidoHtml: '<p>C2</p>'),
      ];

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: caps,
        ordenSpine: ['C01.xhtml', 'C02.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'C1')],
        secciones: secciones,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final nombresArchivos = zip.files.map((f) => f.name).toSet();

      expect(nombresArchivos.contains('OEBPS/Text/C01.xhtml'), isTrue);
      expect(nombresArchivos.contains('OEBPS/Text/C02.xhtml'), isFalse);
      expect(nombresArchivos.contains('OEBPS/Text/prologo.xhtml'), isFalse);

      final opf = utf8.decode(zip.files.firstWhere((f) => f.name == 'OEBPS/content.opf').content as List<int>);
      expect(opf.contains('href="Text/C02.xhtml"'), isFalse);
      expect(opf.contains('idref="C02.xhtml"'), isFalse);
    });

    test('El spine compilado respeta exactamente el orden canónico 1:1 de Base3 sin duplicados', () {
      final resMotor = Resultado(
        capitulos: [
          Chapter(titulo: 'Prólogo | Inicios', htmlCuerpo: '<p>Texto prólogo</p>'),
          Chapter(titulo: 'Capítulo 1 | Despertar', htmlCuerpo: '<p>Texto C1</p>'),
          Chapter(titulo: 'Epílogo | Conclusión', htmlCuerpo: '<p>Texto epílogo</p>'),
        ],
        notas: [Nota(num: 1, texto: 'Nota al pie 1', capNum: 1)],
        contadores: Contadores(capitulos: 3, notas: 1, imagenes: 0, separadores: 0),
      );

      final secciones = convertirResultadoASecciones(resMotor, sinopsisTexto: 'Sinopsis canónica.');

      final capsXhtml = [
        const ArchivoEpubEntrada(nombre: 'prologo.xhtml', contenidoHtml: '<p>Prólogo</p>'),
        const ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>C01</p>'),
        const ArchivoEpubEntrada(nombre: 'epilogo.xhtml', contenidoHtml: '<p>Epílogo</p>'),
      ];

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: capsXhtml,
        ordenSpine: secciones.where((s) => s.enabled).map((s) => s.fileName).toList(),
        entradasToc: [
          for (final s in secciones.where((s) => s.enabled && s.inToc))
            (archivo: s.fileName, titulo: s.effectiveHeading)
        ],
        secciones: secciones,
        contenidoNotas: '<div class="nota"><p id="nt1">Nota</p></div>',
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final opf = utf8.decode(zip.files.firstWhere((f) => f.name == 'OEBPS/content.opf').content as List<int>);

      final reSpineMatch = RegExp(r'<spine\b[^>]*>(.*?)</spine>', dotAll: true).firstMatch(opf);
      expect(reSpineMatch, isNotNull);
      final spineContent = reSpineMatch!.group(1)!;

      final itemrefs = RegExp(r'''<itemref\s+idref="([^"]+)"(?:\s+linear="([^"]+)")?\s*/>''')
          .allMatches(spineContent)
          .map((m) => (idref: m.group(1)!, linear: m.group(2)))
          .toList();

      final listaIdrefs = itemrefs.map((i) => i.idref).toList();

      // Ningún idref debe estar duplicado
      expect(listaIdrefs.toSet().length, equals(listaIdrefs.length));

      // Verificar orden canónico 1:1
      expect(listaIdrefs, [
        'cubierta.xhtml',
        'sinopsis.xhtml',
        'titulo.xhtml',
        'creditos.xhtml',
        'logos.xhtml',
        'contenido-2.xhtml',
        'prologo.xhtml',
        'C01.xhtml',
        'epilogo.xhtml',
        'contracubierta.xhtml',
        'notas.xhtml',
        'toc.xhtml',
      ]);

      // Cubierta debe tener linear="yes" y toc linear="no"
      expect(itemrefs.first.linear, 'yes');
      expect(itemrefs.last.linear, 'no');
    });

    test('Inyecta metadatos completos de Base3 con Kanji, Ruby, Identificadores y Constantes', () {
      final metadatos = BookMetadata(
        title: 'Tate no Yuusha no Nariagari',
        series: 'Tate no Yuusha no Nariagari',
        volume: '01',
        groupTag: 'SIGLAS-GRUPO',
        author: 'Aneko Yusagi',
        authorJapanese: 'アネコ ユサギ',
        authorFileAs: 'Yusagi, Aneko',
        illustrator: 'Minami Seira',
        illustratorJapanese: '弥南 せいら',
        illustratorFileAs: 'Seira, Minami',
        translator: 'Traductor Épico',
        proofreader: 'Zhi',
        publisher: 'Grupo Traductor',
        projectUrl: 'https://grupotraductor.com/tate-no-yuusha',
        bookType: 'Novela Ligera',
        subjects: ['Shounen', 'Acción', 'Isekai', 'Fantasía'],
        synopsis: 'Iwatani Naofumi es convocado a otro mundo...',
        isbn13: '978-4-04-066123-4',
        isbn10: '4-04-066123-4',
        amazonId: 'B00EXAMPLE',
        bookId: '12345678-1234-7123-8123-123456789abc',
      );

      final caps = [
        ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>Capítulo 1</p>'),
      ];

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: caps,
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'Capítulo 1')],
        metadatos: metadatos,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final mapArchivos = {for (var f in zip.files) f.name: f.content as List<int>};

      // 1. Verificar content.opf
      final opf = utf8.decode(mapArchivos['OEBPS/content.opf']!);

      // Título con grupo
      expect(opf.contains('<dc:title>Tate no Yuusha no Nariagari - Volumen 01 [SIGLAS-GRUPO]</dc:title>'), isTrue);

      // Autor latino, japonés (alternate-script) e indexación (file-as)
      expect(opf.contains('<dc:creator id="creator01">Aneko Yusagi</dc:creator>'), isTrue);
      expect(opf.contains('<meta property="alternate-script" refines="#creator01" xml:lang="ja">アネコ ユサギ</meta>'), isTrue);
      expect(opf.contains('<meta property="file-as" refines="#creator01">Yusagi, Aneko</meta>'), isTrue);

      // Ilustrador latino, japonés e indexación
      expect(opf.contains('<dc:creator id="creator02">Minami Seira</dc:creator>'), isTrue);
      expect(opf.contains('<meta property="alternate-script" refines="#creator02" xml:lang="ja">弥南 せいら</meta>'), isTrue);
      expect(opf.contains('<meta property="file-as" refines="#creator02">Seira, Minami</meta>'), isTrue);

      // Roles y colaboradores
      expect(opf.contains('<dc:contributor id="contrib1">Traductor Épico</dc:contributor>'), isTrue);
      expect(opf.contains('<dc:contributor id="contrib2">Zhi</dc:contributor>'), isTrue);
      expect(opf.contains('<meta property="role" refines="#contrib2" scheme="marc:relators">mrk</meta>'), isTrue);

      // Constantes canónicas inmutables
      expect(opf.contains('<dc:contributor id="contrib3">ZeePubs</dc:contributor>'), isTrue);
      expect(opf.contains('<meta property="role" refines="#contrib3" scheme="marc:relators">dst</meta>'), isTrue);
      expect(opf.contains('<meta content="9" name="calibre:rating"/>'), isTrue);

      // Tipo y subjects
      expect(opf.contains('<dc:type>Novela Ligera</dc:type>'), isTrue);
      expect(opf.contains('<dc:subject>Shounen</dc:subject>'), isTrue);
      expect(opf.contains('<dc:subject>Acción</dc:subject>'), isTrue);
      expect(opf.contains('<dc:subject>Isekai</dc:subject>'), isTrue);
      expect(opf.contains('<dc:subject>Fantasía</dc:subject>'), isTrue);

      // Identificadores
      expect(opf.contains('<dc:identifier id="isbn13">urn:isbn:978-4-04-066123-4</dc:identifier>'), isTrue);
      expect(opf.contains('<dc:identifier id="isbn10">urn:isbn:4-04-066123-4</dc:identifier>'), isTrue);
      expect(opf.contains('<dc:identifier id="amazon-id">urn:amazon:B00EXAMPLE</dc:identifier>'), isTrue);
      expect(opf.contains('<dc:identifier id="uri-id">urn:uri:https://grupotraductor.com/tate-no-yuusha</dc:identifier>'), isTrue);

      // 2. Verificar titulo.xhtml con tags <ruby>
      final titulo = utf8.decode(mapArchivos['OEBPS/Text/titulo.xhtml']!);
      expect(titulo.contains('<ruby>アネコ ユサギ<rp>(</rp><rt>Aneko Yusagi</rt><rp>)</rp></ruby>'), isTrue);
      expect(titulo.contains('<ruby>弥南 せいら<rp>(</rp><rt>Minami Seira</rt><rp>)</rp></ruby>'), isTrue);
      expect(titulo.contains('<b>Corrección:</b> Zhi</p>'), isTrue);
      expect(titulo.contains('<a href="https://grupotraductor.com/tate-no-yuusha">https://grupotraductor.com/tate-no-yuusha</a>'), isTrue);
    });

    test('BookMetadata.fromFileName deduce título, volumen y [SIGLAS]', () {
      final meta = BookMetadata.fromFileName('/libros/Overlord - Vol 14 [NL-FANS].docx');
      expect(meta.series, 'Overlord');
      expect(meta.volume, '14');
      expect(meta.groupTag, 'NL-FANS');
      expect(meta.effectiveTitle, 'Overlord - Volumen 14 [NL-FANS]');
    });
  });
}
