import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/modelo.dart';
import 'package:conversor_epub/motor/plantillas.dart';
import 'package:conversor_epub/motor/secciones.dart';
import 'package:conversor_epub/motor/metadatos.dart';

void main() {
  group('TestTaxonomiaSecciones', () {
    test('BookMetadata deduce serie, volumen y genera UUID v7', () {
      final meta = BookMetadata.fromFileName('/ruta/novelas/Kumo Desu ga, Nani ka - Vol 01.docx');
      expect(meta.title, 'Kumo Desu ga, Nani ka');
      expect(meta.series, 'Kumo Desu ga, Nani ka');
      expect(meta.volume, '01');
      expect(meta.displayTitle, 'Kumo Desu ga, Nani ka - Volumen 01');

      // UUID v7 format: 8-4-4-4-12, version 7
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(meta.bookId), isTrue);
    });

    test('convertirResultadoASecciones estructura Preliminares, Cuerpo y Finales', () {
      final capPrologo = Chapter(titulo: 'Prólogo | Un nuevo inicio', htmlCuerpo: '<p>Texto prólogo</p>');
      final cap1 = Chapter(titulo: 'Capítulo 1 | El despertar', htmlCuerpo: '<p>Texto cap 1</p>');
      final cap2 = Chapter(titulo: 'Capítulo 2 | El viaje', htmlCuerpo: '<p>Texto cap 2</p>');
      final capEpilogo = Chapter(titulo: 'Epílogo | Despedida', htmlCuerpo: '<p>Texto epílogo</p>');

      final nota = Nota(num: 1, texto: 'Texto de la nota', capNum: 1);

      final resultado = Resultado(
        capitulos: [capPrologo, cap1, cap2, capEpilogo],
        notas: [nota],
        contadores: Contadores(capitulos: 4, notas: 1, imagenes: 0, separadores: 0),
      );

      final secciones = convertirResultadoASecciones(resultado, sinopsisTexto: 'Esta es la sinopsis.');

      // Front: 9 preliminares canónicos de Base 0.16.0 (sin creditos.xhtml ni contenido-2.xhtml)
      final front = secciones.where((s) => s.matter == BookMatter.front).toList();
      expect(front.length, 9);
      expect(front[0].kind, SectionKind.cover);
      expect(front[1].kind, SectionKind.synopsis);
      expect(front[1].enabled, isTrue);
      expect(front[2].kind, SectionKind.illustrations);
      expect(front[3].kind, SectionKind.authorProfile);
      expect(front[4].kind, SectionKind.titlePage);
      expect(front[5].kind, SectionKind.logos);
      expect(front[6].kind, SectionKind.tocVisual);
      expect(front[6].fileName, 'contenido.xhtml');
      expect(front[7].kind, SectionKind.epigraph);
      expect(front[8].kind, SectionKind.preface);

      // Body: Prólogo, Capítulo 1, Capítulo 2
      final body = secciones.where((s) => s.matter == BookMatter.body).toList();
      expect(body.length, 3);
      expect(body[0].kind, SectionKind.prologue);
      expect(body[0].title, 'Prólogo');
      expect(body[0].subtitle, 'Un nuevo inicio');
      expect(body[0].effectiveHeading, 'Prólogo: Un nuevo inicio');

      expect(body[1].kind, SectionKind.chapter);
      expect(body[1].title, 'Capítulo 1');
      expect(body[1].fileName, 'C01.xhtml');

      expect(body[2].kind, SectionKind.chapter);
      expect(body[2].title, 'Capítulo 2');
      expect(body[2].fileName, 'C02.xhtml');

      // Back: Epílogo, Autor, Traductor, Contracubierta, Notas, TocNav
      final back = secciones.where((s) => s.matter == BookMatter.back).toList();
      expect(back.length, 6);
      expect(back[0].kind, SectionKind.epilogue);
      expect(back[0].effectiveHeading, 'Epílogo: Despedida');
      expect(back[1].kind, SectionKind.author);
      expect(back[1].enabled, isFalse);
      expect(back[2].kind, SectionKind.translator);
      expect(back[2].enabled, isFalse);
      expect(back[3].kind, SectionKind.backCover);
      expect(back[4].kind, SectionKind.notes);
      expect(back[4].enabled, isTrue);
      expect(back[5].kind, SectionKind.tocNav);
    });

    test('seccionesACapitulos convierte secciones de vuelta a Chapter con plantillas adecuadas', () {
      final secciones = [
        SectionItem(id: '1', kind: SectionKind.cover, matter: BookMatter.front, title: 'Cubierta', fileName: 'cubierta.xhtml'),
        SectionItem(id: '2', kind: SectionKind.prologue, matter: BookMatter.body, title: 'Prólogo', subtitle: 'Inicio', fileName: 'prologo.xhtml', htmlContent: '<p>P</p>'),
        SectionItem(id: '3', kind: SectionKind.chapter, matter: BookMatter.body, title: 'Capítulo 1', fileName: 'C01.xhtml', htmlContent: '<p>C1</p>'),
        SectionItem(id: '4', kind: SectionKind.extra, matter: BookMatter.back, title: 'Historia Extra 1', fileName: 'extra_01.xhtml', htmlContent: '<p>Extra</p>'),
        SectionItem(id: '5', kind: SectionKind.chapter, matter: BookMatter.body, title: 'Capítulo Desactivado', fileName: 'C02.xhtml', enabled: false),
      ];

      final capitulos = seccionesACapitulos(secciones);
      expect(capitulos.length, 3);
      expect(capitulos[0].plantillaNombre, 'prologo.xhtml');
      expect(capitulos[0].titulo, 'Prólogo: Inicio');
      expect(capitulos[1].archivo, 'C01.xhtml');
      expect(capitulos[2].archivo, 'extra_01.xhtml');
      expect(capitulos[2].tipoForzado, TipoEspecial.extra);
    });

    test('detectarTipoEspecial y clasificarYRenumerarCapitulos reconocen Historia Extra y no alteran numeracion de capitulos', () {
      expect(detectarTipoEspecial('Historia Extra 1: El diario de los pequeños demonios'), TipoEspecial.extra);
      expect(detectarTipoEspecial('Historia Extra 2: ¿Necesitas una Princesa a la cual dedicarle tu corazón?'), TipoEspecial.extra);
      expect(detectarTipoEspecial('Historia Corta: Vacaciones'), TipoEspecial.extra);
      expect(detectarTipoEspecial('Capítulo Extra: Encuentro'), TipoEspecial.extra);
      expect(detectarTipoEspecial('Side Story 1: Recuerdos'), TipoEspecial.extra);

      final caps = [
        Chapter(titulo: 'Capítulo 1: Inicio', htmlCuerpo: '<p>1</p>'),
        Chapter(titulo: 'Capítulo 2: Mitad', htmlCuerpo: '<p>2</p>'),
        Chapter(titulo: 'EPÍLOGO', htmlCuerpo: '<p>E</p>'),
        Chapter(titulo: 'Historia Extra 1: El diario', htmlCuerpo: '<p>Ex1</p>'),
        Chapter(titulo: 'Historia Extra 2: La princesa', htmlCuerpo: '<p>Ex2</p>'),
      ];

      clasificarYRenumerarCapitulos(caps, startNum: 1);

      expect(caps[0].archivo, 'C01.xhtml');
      expect(caps[1].archivo, 'C02.xhtml');
      expect(caps[2].archivo, 'epilogo.xhtml');
      expect(caps[3].archivo, 'extra_01.xhtml');
      expect(caps[4].archivo, 'extra_02.xhtml');
    });
  });
}
