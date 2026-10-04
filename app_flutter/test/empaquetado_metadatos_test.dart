import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:conversor_epub/motor/empaquetado.dart';
import 'package:conversor_epub/motor/metadatos.dart';
import 'package:conversor_epub/motor/secciones.dart';

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
  });
}
