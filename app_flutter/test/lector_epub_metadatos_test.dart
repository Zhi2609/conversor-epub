import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/metadatos.dart';
import 'package:conversor_epub/motor/lector_epub_metadatos.dart';

void main() {
  group('TestLectorEpubMetadatos', () {
    test('Extrae metadatos de Cómo no Invocar a un Señor Demonio e incrementa volumen a 02', () {
      File fileEpub = File('../Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations].epub');
      if (!fileEpub.existsSync()) {
        fileEpub = File('Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations].epub');
      }
      expect(fileEpub.existsSync(), isTrue, reason: 'El epub de Señor Demonio debe existir');

      final bytes = fileEpub.readAsBytesSync();
      final meta = extraerMetadatosDeEpub(bytes, incrementarVolumen: true);

      // Títulos
      expect(meta.titleSpanish, equals('Cómo no Invocar a un Señor Demonio'));
      expect(meta.titleJapanese, equals('Isekai Maou to Shoukan Shoujo Dorei Majutsu'));
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
      File fileEpub = File('../Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations].epub');
      if (!fileEpub.existsSync()) {
        fileEpub = File('Cómo no Invocar a un Señor Demonio - V01 [Kyuden Translations].epub');
      }
      expect(fileEpub.existsSync(), isTrue);

      final bytes = fileEpub.readAsBytesSync();
      final meta = extraerMetadatosDeEpub(bytes, incrementarVolumen: false);

      expect(meta.volume, equals('1'));
      expect(meta.volumeIndex, equals('1'));
      expect(meta.volumePadded, equals('01'));
    });
  });
}
