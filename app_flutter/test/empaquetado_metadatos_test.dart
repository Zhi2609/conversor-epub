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
      expect(sinopsisHtml.contains('Esta es una sinopsis emocionante sobre un héroe.</p>'), isTrue);
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

    test('BookMetadata.defaultFileName genera Nombre de novela - V01 [GrupoTraductor].epub', () {
      const meta1 = BookMetadata(
        title: 'Akuma Koujo ~Yurui Akuma no Monogatari~',
        volume: '01',
        groupTag: 'KT',
      );
      expect(meta1.defaultFileName, equals('Akuma Koujo ~Yurui Akuma no Monogatari~ - V01 [KT].epub'));

      const meta2 = BookMetadata(
        series: 'The Devil Princess [NL]',
        volume: '1',
        publisher: 'Kyuden Translations',
      );
      expect(meta2.defaultFileName, equals('The Devil Princess - V01 [Kyuden Translations].epub'));
    });

    test('ordenarSubjectsCanonico respeta Edad -> Audiencia -> Géneros alfabéticos', () {
      final entrada = [
        'Aventura',
        'Comedia',
        'Drama',
        'Fantasía',
        'Maduro',
        'Adultos/Seinen',
        'Misterio',
        'Psicológico',
        'Recuentos de la vida',
        'Romance',
      ];

      final ordenado = ordenarSubjectsCanonico(entrada);
      expect(ordenado, equals([
        'Maduro',
        'Adultos/Seinen',
        'Aventura',
        'Comedia',
        'Drama',
        'Fantasía',
        'Misterio',
        'Psicológico',
        'Recuentos de la vida',
        'Romance',
      ]));
    });

    test('formatearIsbn13 y formatearIsbn10 agregan separaciones de guiones canónicas a números continuos', () {
      expect(formatearIsbn13('9784065280584'), equals('978-40-6528-058-4'));
      expect(formatearIsbn10('4065280583'), equals('40-6528-058-3'));

      // Si ya tienen guiones, los conserva
      expect(formatearIsbn13('978-40-6528-058-4'), equals('978-40-6528-058-4'));
      expect(formatearIsbn10('40-6528-058-3'), equals('40-6528-058-3'));
    });

    test('content.opf genera dc:description en una sola línea unida por &lt;br/&gt;&lt;br/&gt;', () {
      final bytesBase = File('assets/Base3_v1.15.0.epub').readAsBytesSync();
      const meta = BookMetadata(
        title: 'Novela Test',
        synopsis: 'Párrafo 1.\n\nPárrafo 2.\n\nPárrafo 3.',
        bookId: 'test-desc-uuid',
      );

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: [ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>C1</p>')],
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'C1')],
        metadatos: meta,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final opf = utf8.decode(zip.files.firstWhere((f) => f.name == 'OEBPS/content.opf').content as List<int>);

      expect(
        opf.contains('<dc:description>Párrafo 1.&lt;br/&gt;&lt;br/&gt;Párrafo 2.&lt;br/&gt;&lt;br/&gt;Párrafo 3.</dc:description>'),
        isTrue,
      );
      // No contiene saltos de línea dentro de dc:description
      final matchDesc = RegExp(r'<dc:description>(.*?)</dc:description>', dotAll: true).firstMatch(opf);
      expect(matchDesc, isNotNull);
      expect(matchDesc!.group(1)!.contains('\n'), isFalse);
    });

    test('Taxonomía trilingüe canónica: Español en titulo.xhtml y archivo, Japonés/Romaji en dc:title, Inglés en calibre:series', () {
      final bytesBase = File('assets/Base3_v1.15.0.epub').readAsBytesSync();
      final meta = BookMetadata(
        titleSpanish: 'La Princesa Demonio',
        subtitle: 'La Historia del Demonio Despreocupado',
        titleJapanese: 'Akuma Koujo ~Yurui Akuma no Monogatari~',
        series: 'The Devil Princess [NL]',
        volume: '01',
        groupTag: 'KT',
        publisher: 'Kyuden Translations',
        bookId: 'test-trilingual-uuid',
        date: DateTime.utc(2018, 10, 31),
      );

      // 1. Nombre de archivo generado canónico: Español - V01 [KT].epub
      expect(meta.defaultFileName, equals('La Princesa Demonio - V01 [KT].epub'));
      // 2. Título OPF dc:title: Romaji - Volumen 01 [KT]
      expect(meta.effectiveTitle, equals('Akuma Koujo ~Yurui Akuma no Monogatari~ - Volumen 01 [KT]'));

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: [ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>C1</p>')],
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'C1')],
        metadatos: meta,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final opf = utf8.decode(zip.files.firstWhere((f) => f.name == 'OEBPS/content.opf').content as List<int>);
      final titulo = utf8.decode(zip.files.firstWhere((f) => f.name == 'OEBPS/Text/titulo.xhtml').content as List<int>);

      // Verificar content.opf:
      // dc:title tiene japonés/romaji
      expect(opf.contains('<dc:title>Akuma Koujo ~Yurui Akuma no Monogatari~ - Volumen 01 [KT]</dc:title>'), isTrue);
      // belongs-to-collection y calibre:series tienen inglés
      expect(opf.contains('<meta id="serie" property="belongs-to-collection">The Devil Princess [NL]</meta>'), isTrue);
      expect(opf.contains('<meta content="The Devil Princess [NL]" name="calibre:series"/>'), isTrue);
      expect(opf.contains('<meta property="group-position" refines="#serie">1</meta>'), isTrue);
      expect(opf.contains('<meta content="1" name="calibre:series_index"/>'), isTrue);
      // dc:date está actualizado
      expect(opf.contains('<dc:date>2018-10-31T00:00:00Z</dc:date>'), isTrue);

      // Verificar titulo.xhtml:
      // Título en español en span grande
      expect(titulo.contains('<span class="grande" epub:type="title">La Princesa Demonio</span>'), isTrue);
      // Subtítulo en español
      expect(titulo.contains('<span epub:type="subtitle" role="doc-subtitle">La Historia del Demonio Despreocupado</span>'), isTrue);
      // Volumen y tipo de libro
      expect(titulo.contains('<h2 class="subtitulo sigil_not_in_toc">Volumen 01<br/><small>[Novela Ligera]</small></h2>'), isTrue);
    });

    test('titulo.xhtml elimina placeholder de subtítulo si está vacío', () {
      final bytesBase = File('assets/Base3_v1.15.0.epub').readAsBytesSync();
      const meta = BookMetadata(
        titleSpanish: 'Cómo no Invocar a un Señor Demonio',
        subtitle: '', // Vacío
        volume: '01',
      );

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: [ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>C1</p>')],
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'C1')],
        metadatos: meta,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final titulo = utf8.decode(zip.files.firstWhere((f) => f.name == 'OEBPS/Text/titulo.xhtml').content as List<int>);

      expect(titulo.contains('Cómo no Invocar a un Señor Demonio</span>'), isTrue);
      expect(titulo.contains('Aquí va el subtítulo'), isFalse);
      expect(titulo.contains('epub:type="subtitle"'), isFalse);
    });

    test('Empaqueta con Base3_v1.16.0.epub preservando fuentes de Zhi, CSS dual y sintaxis 1.16', () {
      File fileBase16 = File('assets/Base3_v1.16.0.epub');
      if (!fileBase16.existsSync()) {
        fileBase16 = File('../assets/Base3_v1.16.0.epub');
      }
      expect(fileBase16.existsSync(), isTrue, reason: 'Base3_v1.16.0.epub debe existir');
      final bytes16 = fileBase16.readAsBytesSync();

      const meta = BookMetadata(
        titleSpanish: 'Cómo no Invocar a un Señor Demonio',
        titleJapanese: 'Isekai Maou to Shoukan Shoujo no Dorei Majutsu',
        series: 'How NOT to Summon a Demon Lord [NL]',
        volume: '01',
        groupTag: 'Kyuden Translations',
        author: 'Yukiya Murasaki',
        authorJapanese: 'むらさきゆきや',
        illustrator: 'Takahiro Tsurusaki',
        illustratorJapanese: '鶴崎 貴大',
        synopsis: 'Un jugador es transportado a su MMORPG favorito como su personaje Diablo.\nAllí conoce a dos chicas que intentan esclavizarlo.',
      );

      final res = empaquetarEpub(
        bytesBaseEpub: bytes16,
        capitulosYEspeciales: [
          ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p class="no-indent">Capítulo de prueba</p>'),
        ],
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'Capítulo 1')],
        metadatos: meta,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final mapArchivos = {for (var f in zip.files) f.name: f.content as List<int>};

      // 1. Fuentes decorativas de Zhi preservadas
      final fuentesRequeridas = [
        'OEBPS/Fonts/Castellar.ttf',
        'OEBPS/Fonts/IMFellEnglish-Italic.ttf',
        'OEBPS/Fonts/Inkfree.ttf',
        'OEBPS/Fonts/Jokerman-Regular.ttf',
        'OEBPS/Fonts/Monotype-Corsiva.ttf',
        'OEBPS/Fonts/Oswald-Regular.ttf',
      ];
      for (final f in fuentesRequeridas) {
        expect(mapArchivos.containsKey(f), isTrue, reason: 'Fuente $f debe existir en Base 1.16');
      }

      // 2. CSS Personal de Zhi con alias duales en style.css
      final css = utf8.decode(mapArchivos['OEBPS/Styles/style.css']!);
      expect(css.contains('CSS PERSONAL DE ZHI'), isTrue);
      expect(css.contains('.rule') && css.contains('.regla'), isTrue);
      expect(css.contains('blockquote.mystic') && css.contains('blockquote.mistico'), isTrue);
      expect(css.contains('.warning-box') && css.contains('.aviso'), isTrue);
      expect(css.contains('.gp-info'), isTrue);
      expect(css.contains('.gp-warning'), isTrue);
      expect(css.contains('.gp-gold-info'), isTrue);

      // 3. content.opf usa metadatos de serie y alternate-script
      final opf = utf8.decode(mapArchivos['OEBPS/content.opf']!);
      expect(opf.contains('property="alternate-script"') && opf.contains('refines="#creator01"') && opf.contains('むらさきゆきや'), isTrue);
      expect(RegExp(r'<(?:opf:)?meta id="serie" property="belongs-to-collection">How NOT to Summon a Demon Lord \[NL\]</(?:opf:)?meta>').hasMatch(opf), isTrue);
      expect(RegExp(r'<(?:opf:)?meta content="How NOT to Summon a Demon Lord \[NL\]" name="calibre:series"/>').hasMatch(opf), isTrue);

      // 4. titulo.xhtml tiene estructura 1.16 (subtitle y role="doc-subtitle")
      final titulo = utf8.decode(mapArchivos['OEBPS/Text/titulo.xhtml']!);
      expect(titulo.contains('<h2 class="subtitle sigil_not_in_toc" role="doc-subtitle">Volumen 01<br/><small>[Novela Ligera]</small></h2>'), isTrue);
      expect(titulo.contains('<span class="large" epub:type="title">Cómo no Invocar a un Señor Demonio</span>'), isTrue);

      // 5. Corrección de novela y Epub (maquetador) están claramente separados
      expect(titulo.contains('<p><b>Corrección:</b> Corrector Apellido</p>'), isTrue);
      expect(titulo.contains('<p class="space-1"><b>Epub:</b> Zhi (<a href="https://www.facebook.com/ZeePubs">ZeePubs</a>)</p>'), isTrue);

      // 6. Base 1.16 contiene imágenes de muestra y código HTML (no deja cubierta ni resumen vacíos)
      expect(mapArchivos.containsKey('OEBPS/Images/cover.jpg'), isTrue);
      expect(mapArchivos.containsKey('OEBPS/Images/02.jpg'), isTrue);
      expect(mapArchivos.containsKey('OEBPS/Images/03.jpg'), isTrue);
      expect(mapArchivos.containsKey('OEBPS/Images/grupo.png'), isTrue);
      expect(mapArchivos.containsKey('OEBPS/Images/zeepubs.png'), isTrue);

      final cubierta = utf8.decode(mapArchivos['OEBPS/Text/cubierta.xhtml']!);
      expect(cubierta.contains('src="../Images/cover.jpg"'), isTrue);
      expect(cubierta.contains('<figure class="fill">'), isTrue);

      final resumen = utf8.decode(mapArchivos['OEBPS/Text/resumen.xhtml']!);
      expect(resumen.contains('src="../Images/02.jpg"'), isTrue);
      expect(resumen.contains('src="../Images/03.jpg"'), isTrue);
      expect(resumen.contains('<figure class="fill break-after" id="resumen_0001">'), isTrue);

      final contenido = utf8.decode(mapArchivos['OEBPS/Text/contenido.xhtml']!);
      expect(contenido.contains('src="../Images/02.jpg"'), isTrue);

      final logos = utf8.decode(mapArchivos['OEBPS/Text/logos.xhtml']!);
      expect(logos.contains('src="../Images/grupo.png"'), isTrue);
      expect(logos.contains('src="../Images/zeepubs.png"'), isTrue);

      // 7. Base 1.16 contiene y preserva creditos.xhtml y creditos.jpg
      expect(mapArchivos.containsKey('OEBPS/Text/creditos.xhtml'), isTrue);
      expect(mapArchivos.containsKey('OEBPS/Images/creditos.jpg'), isTrue);
      final creditosHtml = utf8.decode(mapArchivos['OEBPS/Text/creditos.xhtml']!);
      expect(creditosHtml.contains('src="../Images/creditos.jpg"'), isTrue);
      expect(creditosHtml.contains('epub:type="other-credits"'), isTrue);
      expect(creditosHtml.contains('role="doc-credits"'), isTrue);
      expect(creditosHtml.contains('class="space-3"'), isTrue);

      // 8. content.opf registra creditos en manifest y spine
      expect(opf.contains('<item id="creditos.xhtml" href="Text/creditos.xhtml" media-type="application/xhtml+xml"/>'), isTrue);
      expect(opf.contains('<item id="creditos.jpg" href="Images/creditos.jpg" media-type="image/jpeg"/>'), isTrue);
      expect(opf.contains('<itemref idref="creditos.xhtml"/>'), isTrue);

      // 9. toc.xhtml registra creditos en landmarks
      final toc = utf8.decode(mapArchivos['OEBPS/Text/toc.xhtml']!);
      expect(toc.contains('<li><a epub:type="other-credits" href="creditos.xhtml">Créditos</a></li>'), isTrue);

      // 10. Formato dual del volumen: '1' en serie y '01' en título
      expect(RegExp(r'<(?:opf:)?meta\b[^>]*property="group-position"[^>]*>1</(?:opf:)?meta>').hasMatch(opf), isTrue);
      expect(RegExp(r'<(?:opf:)?meta\b[^>]*content="1"[^>]*name="calibre:series_index"').hasMatch(opf) ||
             RegExp(r'<(?:opf:)?meta\b[^>]*name="calibre:series_index"[^>]*content="1"').hasMatch(opf), isTrue);
      expect(titulo.contains('Volumen 01'), isTrue);
    });

    test('Formato dual del volumen para Volumen 02: digito simple 2 en serie e indice, y 02 en titulos', () {
      File fileBase16 = File('assets/Base3_v1.16.0.epub');
      if (!fileBase16.existsSync()) {
        fileBase16 = File('../assets/Base3_v1.16.0.epub');
      }
      final bytes16 = fileBase16.readAsBytesSync();

      const meta = BookMetadata(
        titleSpanish: 'Cómo no Invocar a un Señor Demonio',
        series: 'How NOT to Summon a Demon Lord [NL]',
        volume: '02',
        groupTag: 'KT',
      );

      final res = empaquetarEpub(
        bytesBaseEpub: bytes16,
        capitulosYEspeciales: [ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>C1</p>')],
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'Capítulo 1')],
        metadatos: meta,
      );

      final zip = ZipDecoder().decodeBytes(res.bytesEpub);
      final mapArchivos = {for (var f in zip.files) f.name: f.content as List<int>};
      final opf = utf8.decode(mapArchivos['OEBPS/content.opf']!);
      final titulo = utf8.decode(mapArchivos['OEBPS/Text/titulo.xhtml']!);

      // group-position y calibre:series_index usan dígito '2'
      expect(RegExp(r'<(?:opf:)?meta\b[^>]*property="group-position"[^>]*>2</(?:opf:)?meta>').hasMatch(opf), isTrue);
      expect(RegExp(r'<(?:opf:)?meta\b[^>]*content="2"[^>]*name="calibre:series_index"').hasMatch(opf) ||
             RegExp(r'<(?:opf:)?meta\b[^>]*name="calibre:series_index"[^>]*content="2"').hasMatch(opf), isTrue);

      // dc:title y titulo.xhtml usan relleno '02'
      expect(RegExp(r'<dc:title[^>]*>Cómo no Invocar a un Señor Demonio - Volumen 02 \[KT\]</dc:title>').hasMatch(opf), isTrue);
      expect(titulo.contains('Volumen 02'), isTrue);

      // Nombre de archivo por defecto usa V02
      expect(meta.defaultFileName, equals('Cómo no Invocar a un Señor Demonio - V02 [KT].epub'));
    });
  });
}

