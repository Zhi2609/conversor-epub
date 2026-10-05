import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:conversor_epub/motor/empaquetado.dart';
import 'package:conversor_epub/motor/notas.dart';

void main() {
  group('TestUuid', () {
    test('generarUuidV4 produce UUID versión 4 RFC 4122 válido', () {
      final uuid1 = generarUuidV4();
      final uuid2 = generarUuidV4();

      final reUuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      expect(reUuidV4.hasMatch(uuid1), isTrue);
      expect(reUuidV4.hasMatch(uuid2), isTrue);
      expect(uuid1, isNot(equals(uuid2)));
    });
  });

  group('TestNotasConstante', () {
    test('archivoNotas es notas.xhtml y llamadas apuntan a notas.xhtml', () {
      expect(archivoNotas, equals('notas.xhtml'));
      final llamada = formatearLlamada(1);
      expect(llamada, contains('href="notas.xhtml#nt01"'));
    });
  });

  group('TestEmpaquetadoEpub', () {
    late Uint8List bytesBase;

    setUp(() {
      File fileBase = File('assets/Base3_v1.15.0.epub');
      if (!fileBase.existsSync()) {
        fileBase = File('../assets/Base3_v1.15.0.epub');
      }
      if (!fileBase.existsSync()) {
        fileBase = File('../Base3_v1.15.0.epub');
      }
      expect(fileBase.existsSync(), isTrue, reason: 'Base3_v1.15.0.epub debe existir en assets o en la raíz');
      bytesBase = fileBase.readAsBytesSync();
    });

    test('empaqueta libro con capitulos regulares, elimina Section000X y coloca mimetype primero sin comprimir', () {
      final capitulos = [
        const ArchivoEpubEntrada(
          nombre: 'C01.xhtml',
          contenidoHtml: '<html><body><section><h1>Capítulo 1</h1><p>Texto C01</p></section></body></html>',
        ),
        const ArchivoEpubEntrada(
          nombre: 'C02.xhtml',
          contenidoHtml: '<html><body><section><h1>Capítulo 2</h1><p>Texto C02</p></section></body></html>',
        ),
        const ArchivoEpubEntrada(
          nombre: 'contenido.xhtml',
          contenidoHtml: '<html><body><section><div class="duo"><img src="../Images/toc.jpg" alt="toc"/></div></section></body></html>',
        ),
      ];

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: capitulos,
        ordenSpine: ['C01.xhtml', 'C02.xhtml'],
        entradasToc: [
          (archivo: 'C01.xhtml', titulo: 'Capítulo 1: Inicio'),
          (archivo: 'C02.xhtml', titulo: 'Capítulo 2: Fin'),
        ],
        contenidoNotas: null, // Sin notas
        imagenes: [],
        uuidCustom: '12345678-1234-4234-8234-123456789abc',
        fechaModificacion: DateTime.utc(2026, 10, 3, 12, 0, 0),
      );

      final archive = ZipDecoder().decodeBytes(res.bytesEpub);

      // 1. mimetype debe ser el primer archivo
      expect(archive.files.first.name, equals('mimetype'));
      expect(archive.files.first.compression, equals(CompressionType.none));
      final mimetypeContent = utf8.decode(archive.files.first.content);
      expect(mimetypeContent, equals('application/epub+zip'));

      // 2. Section000X o capitulo0X deben haber sido eliminados
      final nombresArchivos = archive.files.map((f) => f.name).toList();
      expect(nombresArchivos.any((n) => n.contains('Section0001')), isFalse);
      expect(nombresArchivos.any((n) => n.contains('Section0002')), isFalse);
      expect(nombresArchivos.any((n) => n.contains('capitulo01')), isFalse);
      expect(nombresArchivos.any((n) => n.contains('capitulo02')), isFalse);

      // 3. Prologo y notas eliminados porque no se incluyeron en el libro
      expect(nombresArchivos.any((n) => n.contains('prologo.xhtml')), isFalse);
      expect(nombresArchivos.any((n) => n.contains('notas.xhtml')), isFalse);

      // 4. C01, C02 y contenido están presentes en OEBPS/Text/ (contenido-2 y creditos eliminados)
      expect(nombresArchivos, contains('OEBPS/Text/C01.xhtml'));
      expect(nombresArchivos, contains('OEBPS/Text/C02.xhtml'));
      expect(nombresArchivos, contains('OEBPS/Text/contenido.xhtml'));
      expect(nombresArchivos, isNot(contains('OEBPS/Text/contenido-2.xhtml')));
      expect(nombresArchivos, isNot(contains('OEBPS/Text/creditos.xhtml')));

      // 5. content.opf tiene el UUID nuevo y spine correcto
      final opfFile = archive.findFile('OEBPS/content.opf');
      expect(opfFile, isNotNull);
      final opfContent = utf8.decode(opfFile!.content);
      expect(opfContent, contains('urn:uuid:12345678-1234-4234-8234-123456789abc'));
      expect(opfContent, contains('2026-10-03T12:00:00Z'));
      expect(opfContent, contains('<item id="C01.xhtml" href="Text/C01.xhtml"'));
      expect(opfContent, contains('<item id="C02.xhtml" href="Text/C02.xhtml"'));
      expect(opfContent, isNot(contains('Section0001.xhtml')));
      expect(opfContent, isNot(contains('capitulo01.xhtml')));
      expect(opfContent, isNot(contains('prologo.xhtml')));
      expect(opfContent, isNot(contains('notas.xhtml')));
      expect(opfContent, isNot(contains('contenido-2.xhtml')));
      expect(opfContent, isNot(contains('creditos.xhtml')));

      // Spine contiene C01 y C02
      expect(opfContent, contains('<itemref idref="C01.xhtml"/>'));
      expect(opfContent, contains('<itemref idref="C02.xhtml"/>'));

      // 6. toc.xhtml no contiene prologo ni notas en nav ni landmarks
      final tocFile = archive.findFile('OEBPS/Text/toc.xhtml');
      expect(tocFile, isNotNull);
      final tocContent = utf8.decode(tocFile!.content);
      expect(tocContent, contains('href="C01.xhtml"'));
      expect(tocContent, contains('Capítulo 1: Inicio'));
      expect(tocContent, isNot(contains('href="prologo.xhtml"')));
      expect(tocContent, isNot(contains('href="notas.xhtml"')));
      expect(tocContent, contains('<a href="C01.xhtml" epub:type="bodymatter">Contenido principal</a>'));
    });

    test('empaqueta con prologo, notas, e imagenes personalizadas con aviso de faltantes', () {
      final capitulos = [
        const ArchivoEpubEntrada(
          nombre: 'prologo.xhtml',
          contenidoHtml: '<html><body><section><h1>Prólogo</h1><p>Texto prologo <img src="../Images/02.jpg" alt=""/></p></section></body></html>',
        ),
        const ArchivoEpubEntrada(
          nombre: 'C01.xhtml',
          contenidoHtml: '<html><body><section><h1>Capítulo 1</h1><p>Texto C01 <img src="../Images/04.jpg" alt=""/> <img src="../Images/inexistente.jpg" alt=""/></p></section></body></html>',
        ),
      ];

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: capitulos,
        ordenSpine: ['prologo.xhtml', 'C01.xhtml'],
        entradasToc: [
          (archivo: 'prologo.xhtml', titulo: 'Prólogo'),
          (archivo: 'C01.xhtml', titulo: 'Capítulo 1: El comienzo'),
        ],
        contenidoNotas: '<div class="nota"><p id="nt01"><a href="C01.xhtml#rf01">Nota 1</a></p></div>',
        imagenes: [
          EntradaImagenEpub(
            nombreArchivo: '04.jpg',
            bytes: [1, 2, 3, 4],
          ),
          EntradaImagenEpub(
            nombreArchivo: '02.jpg', // Sobrescribe el 02.jpg de la base
            bytes: [9, 8, 7],
          ),
        ],
        uuidCustom: '87654321-4321-4321-8321-cba987654321',
      );

      final archive = ZipDecoder().decodeBytes(res.bytesEpub);
      final nombresArchivos = archive.files.map((f) => f.name).toList();

      // Prologo y notas presentes
      expect(nombresArchivos, contains('OEBPS/Text/prologo.xhtml'));
      expect(nombresArchivos, contains('OEBPS/Text/notas.xhtml'));
      expect(nombresArchivos, contains('OEBPS/Images/04.jpg'));

      // Verificar contenido de notas.xhtml inyectado bajo comentario
      final notasFile = archive.findFile('OEBPS/Text/notas.xhtml');
      final notasContent = utf8.decode(notasFile!.content);
      expect(notasContent, contains('Nota 1'));
      expect(notasContent, contains('<!-- Agregar notas con el siguiente formato -->'));

      // 02.jpg sobrescrito con bytes nuevos
      final img02 = archive.findFile('OEBPS/Images/02.jpg');
      expect(img02!.content, equals([9, 8, 7]));

      // 04.jpg registrado en content.opf con id x04.jpg
      final opfContent = utf8.decode(archive.findFile('OEBPS/content.opf')!.content);
      expect(opfContent, contains('<item id="x04.jpg" href="Images/04.jpg" media-type="image/jpeg"/>'));

      // Avisos: debe avisar que inexistente.jpg no existe
      expect(res.avisos.any((a) => a.contains('inexistente.jpg')), isTrue);
    });
  });
}
