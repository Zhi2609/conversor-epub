import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/secciones.dart';
import 'package:conversor_epub/motor/busqueda_reemplazo.dart';

void main() {
  group('TestBusquedaReemplazoEngine', () {
    late List<SectionItem> secciones;

    setUp(() {
      secciones = [
        SectionItem(
          id: 'sec1',
          kind: SectionKind.chapter,
          matter: BookMatter.body,
          title: 'Capítulo 1',
          fileName: 'C01.xhtml',
          htmlContent: '<p>Había una vez en un reino lejano un valiente guerrero llamado Alex.</p>\n<p>Alex miró a su alrededor con determinación.</p>',
        ),
        SectionItem(
          id: 'sec2',
          kind: SectionKind.chapter,
          matter: BookMatter.body,
          title: 'Capítulo 2',
          fileName: 'C02.xhtml',
          htmlContent: '<p>En la taberna, Alex pidió una bebida fresca.</p>',
        ),
      ];
    });

    test('Búsqueda de texto plano encuentra todas las coincidencias con preview', () {
      final matches = SearchReplaceEngine.search(secciones, pattern: 'Alex');
      expect(matches.length, 3);

      expect(matches[0].sectionId, 'sec1');
      expect(matches[0].lineNumber, 1);
      expect(matches[0].matchText, 'Alex');
      expect(matches[0].previewBefore.contains('llamado '), isTrue);

      expect(matches[1].sectionId, 'sec1');
      expect(matches[1].lineNumber, 2);

      expect(matches[2].sectionId, 'sec2');
    });

    test('Búsqueda por Regex con grupos y caseSensitive', () {
      final matches = SearchReplaceEngine.search(
        secciones,
        pattern: r'reino\s+\w+',
        isRegex: true,
      );
      expect(matches.length, 1);
      expect(matches[0].matchText, 'reino lejano');
    });

    test('Regex inválida lanza FormatException', () {
      expect(
        () => SearchReplaceEngine.search(secciones, pattern: r'[invalido', isRegex: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('applyReplaceSingle reemplaza únicamente la coincidencia indicada', () {
      final matches = SearchReplaceEngine.search(secciones, pattern: 'Alex');
      final secModificada = SearchReplaceEngine.applyReplaceSingle(secciones[0], matches[0], 'Alexander');

      expect(secModificada.htmlContent.contains('llamado Alexander.'), isTrue);
      // La segunda mención sigue siendo Alex
      expect(secModificada.htmlContent.contains('Alex miró'), isTrue);
    });

    test('applyReplaceAll reemplaza globalmente en todas las secciones', () {
      final res = SearchReplaceEngine.applyReplaceAll(
        secciones,
        pattern: 'Alex',
        replacement: 'Alejandro',
      );

      expect(res.totalReplacements, 3);
      expect(res.updatedSections[0].htmlContent.contains('llamado Alejandro.'), isTrue);
      expect(res.updatedSections[0].htmlContent.contains('Alejandro miró'), isTrue);
      expect(res.updatedSections[1].htmlContent.contains('En la taberna, Alejandro'), isTrue);
      expect(res.updatedSections[0].htmlContent.contains('Alex'), isFalse);
    });

    test('Filtrado por onlySectionId restringe la búsqueda o reemplazo', () {
      final matches = SearchReplaceEngine.search(secciones, pattern: 'Alex', onlySectionId: 'sec2');
      expect(matches.length, 1);
      expect(matches[0].sectionId, 'sec2');

      final res = SearchReplaceEngine.applyReplaceAll(
        secciones,
        pattern: 'Alex',
        replacement: 'Alejandro',
        onlySectionId: 'sec2',
      );
      expect(res.totalReplacements, 1);
      expect(res.updatedSections[0].htmlContent.contains('Alex'), isTrue);
      expect(res.updatedSections[1].htmlContent.contains('Alex'), isFalse);
    });
  });
}
