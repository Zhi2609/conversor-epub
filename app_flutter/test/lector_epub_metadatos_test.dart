import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/empaquetado.dart';
import 'package:conversor_epub/motor/metadatos.dart';
import 'package:conversor_epub/motor/lector_epub_metadatos.dart';

void main() {
  group('TestLectorEpubMetadatos', () {
    Uint8List obtenerBytesEpubPrueba() {
      const nombres = [
        '../Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations]_v1.16.2.epub',
        'Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations]_v1.16.2.epub',
        '../Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations]_v1.16.0.epub',
        'Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations]_v1.16.0.epub',
        '../Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations].epub',
        'Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations].epub',
      ];
      for (final n in nombres) {
        final f = File(n);
        if (f.existsSync()) return f.readAsBytesSync();
      }

      // Fallback autónomo para entornos sin el archivo externo gitignored
      File fileBase = File('assets/Base3_v1.16.0.epub');
      if (!fileBase.existsSync()) {
        fileBase = File('../assets/Base3_v1.16.0.epub');
      }
      expect(fileBase.existsSync(), isTrue, reason: 'Base3_v1.16.0.epub debe existir');

      final metaSeed = BookMetadata(
        titleSpanish: 'Cómo no Invocar a un Señor Demonio',
        titleJapanese: 'Isekai Maou to Shoukan Shoujo no Dorei Majutsu',
        titleKanji: '異世界魔王と召喚少女の奴隷魔術',
        series: 'How NOT to Summon a Demon Lord [NL]',
        groupTag: 'KT',
        volume: '1',
        author: 'Yukiya Murasaki',
        authorJapanese: 'むらさき ゆきや',
        authorFileAs: 'Murasaki, Yukiya',
        illustrator: 'Tsurusaki Takahiro',
        illustratorJapanese: '鶴崎 貴大',
        illustratorFileAs: 'Takahiro, Tsurusaki',
        translator: 'Rin-san & Edngo',
        proofreader: 'Rin-san & Mbeju',
        publisher: 'Kyuden Translations',
        subjects: ['Juvenil', 'Chicos/Shounen', 'Fantasía', 'Comedia'],
        synopsis: 'Takuma Sakamoto es invocado a otro mundo.',
      );

      final res = empaquetarEpub(
        bytesBaseEpub: fileBase.readAsBytesSync(),
        capitulosYEspeciales: [
          ArchivoEpubEntrada(nombre: 'C01.xhtml', contenidoHtml: '<p>Cap 1</p>'),
        ],
        ordenSpine: ['C01.xhtml'],
        entradasToc: [(archivo: 'C01.xhtml', titulo: 'Capítulo 1')],
        metadatos: metaSeed,
      );
      return Uint8List.fromList(res.bytesEpub);
    }

    test('Extrae metadatos de Cómo no Invocar a un Señor Demonio e incrementa volumen a 02', () {
      final bytes = obtenerBytesEpubPrueba();
      final meta = extraerMetadatosDeEpub(bytes, incrementarVolumen: true);

      // Títulos
      expect(meta.titleSpanish, equals('Cómo no Invocar a un Señor Demonio'));
      expect(meta.titleJapanese.contains('Isekai Maou to Shoukan Shoujo'), isTrue);
      expect(meta.titleKanji, equals('異世界魔王と召喚少女の奴隷魔術'));
      expect(meta.series, equals('How NOT to Summon a Demon Lord [NL]'));
      expect(meta.groupTag, equals('KT'));

      // Volumen auto-incrementado de 01 a 02
      expect(meta.volume, equals('02'));
      expect(meta.volumeIndex, equals('2'));
      expect(meta.volumePadded, equals('02'));

      // Autores con caracteres japoneses / alternate-script y file-as
      expect(meta.author, equals('Yukiya Murasaki'));
      expect(meta.authorJapanese, equals('むらさき ゆきや'));
      expect(meta.authorFileAs, equals('Murasaki, Yukiya'));

      // Ilustrador
      expect(meta.illustrator, equals('Tsurusaki Takahiro'));
      expect(meta.illustratorJapanese, equals('鶴崎 貴大'));
      expect(meta.illustratorFileAs, equals('Takahiro, Tsurusaki'));

      // Traductor, Corrector y Maquetador
      expect(meta.translator, equals('Rin-san & Edngo'));
      expect(meta.proofreader, equals('Rin-san & Mbeju'));
      expect(meta.publisher, equals('Kyuden Translations'));

      // Subjects / Géneros
      expect(meta.subjects, contains('Fantasía'));
      expect(meta.subjects, contains('Comedia'));

      // Sinopsis extraída sin tags basura
      expect(meta.synopsis.isNotEmpty, isTrue);
      expect(meta.synopsis, contains('Takuma Sakamoto'));

      // Nuevo BookId UUID v7 generado
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(meta.bookId), isTrue);

      // Nombre de archivo sugerido para V02
      expect(meta.defaultFileName, equals('Cómo no Invocar a un Señor Demonio - V02 [KT].epub'));
    });

    test('Extrae metadatos conservando volumen original si incrementarVolumen es false', () {
      final bytes = obtenerBytesEpubPrueba();
      final meta = extraerMetadatosDeEpub(bytes, incrementarVolumen: false);

      expect(meta.volume, equals('1'));
      expect(meta.volumeIndex, equals('1'));
      expect(meta.volumePadded, equals('01'));
    });
  });
}
