import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/metadatos.dart';
import 'package:conversor_epub/ui/widgets/formulario_metadatos.dart';

void main() {
  group('FormularioMetadatos Tests', () {
    testWidgets('Renderiza campo ISBN-10 y propaga cambios a BookMetadata', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      BookMetadata actual = const BookMetadata(bookId: 'test-uuid');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormularioMetadatos(
              metadatos: actual,
              onChanged: (nuevo) {
                actual = nuevo;
              },
            ),
          ),
        ),
      );

      // Encontrar el campo de texto de ISBN-10 por su hint o label
      final isbn10Finder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Ej: 40-6528-058-3',
      );
      expect(isbn10Finder, findsOneWidget);

      await tester.enterText(isbn10Finder, '4065280583');
      await tester.pump();

      // Debe formatearse automáticamente con separaciones de guiones
      expect(actual.isbn10, equals('40-6528-058-3'));
    });

    testWidgets('Selecciona demografías duales (Edad y Audiencia) de forma exclusiva por grupo', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      BookMetadata actual = const BookMetadata(bookId: 'test-uuid');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FormularioMetadatos(
                  metadatos: actual,
                  onChanged: (nuevo) {
                    setState(() {
                      actual = nuevo;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // 1. Seleccionar 'Juvenil'
      final chipJuvenil = find.widgetWithText(FilterChip, 'Juvenil');
      expect(chipJuvenil, findsOneWidget);
      await tester.tap(chipJuvenil);
      await tester.pump();

      expect(actual.subjects, contains('Juvenil'));

      // 2. Seleccionar 'Chicos/Shounen'
      final chipShounen = find.widgetWithText(FilterChip, 'Chicos/Shounen');
      expect(chipShounen, findsOneWidget);
      await tester.tap(chipShounen);
      await tester.pump();

      expect(actual.subjects, contains('Juvenil'));
      expect(actual.subjects, contains('Chicos/Shounen'));
      expect(actual.subjects.length, equals(2));

      // 3. Cambiar 'Juvenil' por 'Maduro' (debe reemplazar dentro del grupo de edad)
      final chipMaduro = find.widgetWithText(FilterChip, 'Maduro');
      expect(chipMaduro, findsOneWidget);
      await tester.tap(chipMaduro);
      await tester.pump();

      expect(actual.subjects, contains('Maduro'));
      expect(actual.subjects, isNot(contains('Juvenil')));
      expect(actual.subjects, contains('Chicos/Shounen'));
      expect(actual.subjects.length, equals(2));

      // 4. Cambiar 'Chicos/Shounen' por 'Adultos/Seinen' (debe reemplazar dentro del grupo de audiencia)
      final chipSeinen = find.widgetWithText(FilterChip, 'Adultos/Seinen');
      expect(chipSeinen, findsOneWidget);
      await tester.tap(chipSeinen);
      await tester.pump();

      expect(actual.subjects, contains('Maduro'));
      expect(actual.subjects, contains('Adultos/Seinen'));
      expect(actual.subjects, isNot(contains('Chicos/Shounen')));
      expect(actual.subjects.length, equals(2));
    });

    testWidgets('Permite seleccionar múltiples géneros de la lista canónica de ZeePubs', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      BookMetadata actual = const BookMetadata(bookId: 'test-uuid');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FormularioMetadatos(
                  metadatos: actual,
                  onChanged: (nuevo) {
                    setState(() {
                      actual = nuevo;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Seleccionar 'Acción'
      final chipAccion = find.widgetWithText(FilterChip, 'Acción');
      expect(chipAccion, findsOneWidget);
      await tester.tap(chipAccion);
      await tester.pump();

      // Seleccionar 'Fantasía'
      final chipFantasia = find.widgetWithText(FilterChip, 'Fantasía');
      expect(chipFantasia, findsOneWidget);
      await tester.tap(chipFantasia);
      await tester.pump();

      expect(actual.subjects, contains('Acción'));
      expect(actual.subjects, contains('Fantasía'));
    });

    testWidgets('Renderiza campos de títulos separados (Español, Subtítulo, Romaji, Inglés) y actualiza BookMetadata', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      BookMetadata actual = const BookMetadata(
        bookId: 'test-uuid-titulos',
        titleSpanish: 'La Princesa Demonio',
        volume: '01',
        groupTag: 'KT',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FormularioMetadatos(
                  metadatos: actual,
                  onChanged: (nuevo) {
                    setState(() {
                      actual = nuevo;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // 1. Encontrar los 4 campos de títulos por su hintText
      final spanishFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Ej: La Princesa Demonio',
      );
      final subtitleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Ej: La Historia del Demonio Despreocupado',
      );
      final japaneseFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Ej: Akuma Koujo ~Yurui Akuma no Monogatari~',
      );
      final englishFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Ej: The Devil Princess [NL]',
      );

      expect(spanishFinder, findsOneWidget);
      expect(subtitleFinder, findsOneWidget);
      expect(japaneseFinder, findsOneWidget);
      expect(englishFinder, findsOneWidget);

      // 2. Modificar Subtítulo
      await tester.enterText(subtitleFinder, 'La Historia del Demonio Despreocupado');
      await tester.pump();
      expect(actual.subtitle, equals('La Historia del Demonio Despreocupado'));

      // 3. Modificar Título en Romaji / Japonés
      await tester.enterText(japaneseFinder, 'Akuma Koujo ~Yurui Akuma no Monogatari~');
      await tester.pump();
      expect(actual.titleJapanese, equals('Akuma Koujo ~Yurui Akuma no Monogatari~'));
      expect(actual.effectiveTitle, equals('Akuma Koujo ~Yurui Akuma no Monogatari~ - Volumen 01 [KT]'));

      // 4. Modificar Título en Inglés / Colección
      await tester.enterText(englishFinder, 'The Devil Princess [NL]');
      await tester.pump();
      expect(actual.series, equals('The Devil Princess [NL]'));

      // 5. El archivo generado debe conservar el Título en Español
      expect(actual.defaultFileName, equals('La Princesa Demonio - V01 [KT].epub'));
    });
  });
}
