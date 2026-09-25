import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/limpieza.dart';
import 'package:conversor_epub/motor/plantillas.dart';
import 'package:conversor_epub/motor/render.dart';
import 'package:conversor_epub/motor/modelo.dart';
import 'package:conversor_epub/motor/imagenes.dart';

void main() {
  group('TestComillasCanonicas', () {
    test('grito triple', () {
      expect(limpiarTextoHtml('"""AHHH!!!!"""'), '«««AHHH!!!!»»»');
    });

    test('titulo nivel uno', () {
      final texto = 'se llama "Indigno de ser Humano" de Dazai';
      expect(limpiarTextoHtml(texto), 'se llama «Indigno de ser Humano» de Dazai');
    });

    test('comillas simples explicitas', () {
      final texto = "hablo con... un 'niño'";
      expect(limpiarTextoHtml(texto), 'hablo con... un ‘niño’');
    });

    test('titulo dentro de dialogo', () {
      final texto = '"me gusta "Indigno", dijo"';
      expect(limpiarTextoHtml(texto), '«me gusta «Indigno», dijo»');
    });

    test('comillas sin cerrar al final', () {
      expect(limpiarTextoHtml('"hola mi amigo'), '»hola mi amigo');
    });

    test('dialogos adyacentes', () {
      expect(limpiarTextoHtml('"hola", "adiós"'), '«hola», «adiós»');
    });

    test('cortafuegos por parrafo', () {
      final texto = '"primero</p><p>"segundo';
      expect(limpiarTextoHtml(texto), '«primero</p><p>»segundo');
    });

    test('cortafuegos por salto de linea', () {
      expect(limpiarTextoHtml('"a\n"b'), '«a\n»b');
    });

    test('abre despues de dos puntos', () {
      expect(limpiarTextoHtml('dijo: "hola"'), 'dijo: «hola»');
    });

    test('normaliza tipograficas', () {
      expect(limpiarTextoHtml('“dijo” «ella» ″otro″'), '«dijo» «ella» «otro»');
    });

    test('cierre despues de exclamacion', () {
      expect(limpiarTextoHtml('"¡AHHH!"'), '«¡AHHH!»');
    });

    test('grito anidado mixto', () {
      expect(limpiarTextoHtml('“‘‘Ahh!!’’”'), '«««Ahh!!»»»');
      expect(limpiarTextoHtml("'''AHHH!!'''"), '«««AHHH!!»»»');
    });

    test('simple legitima no encadenada se conserva', () {
      expect(
          limpiarTextoHtml('dijo "vaya" y luego \'niño\''),
          'dijo «vaya» y luego ‘niño’');
    });

    test('simple legitima cerrada pegada a doble', () {
      expect(
          limpiarTextoHtml('"Yo quiero ser una \'pared\'".'),
          '«Yo quiero ser una ‘pared’».');
    });
  });

  group('TestInvariantesComillas', () {
    final rng = Random(7);
    final reCortafuegos = RegExp(r'(</p>|<br/?>|</div>|</section>|</blockquote>|<hr>|\n)');
    final reTags = RegExp(r'<[^>]+>');
    final palabras = ['hola', 'mundo', 'dijo', 'susurró', 'Dazai', 'noche', 'luz', '¿qué?', '¡no!', 'y', 'pero', 'fin.'];

    String genPalabra() => palabras[rng.nextInt(palabras.length)];
    
    String genFrase() {
      int count = rng.nextInt(6) + 1;
      return List.generate(count, (_) => genPalabra()).join(' ');
    }
    
    String genPatron() {
      int choice = rng.nextInt(7);
      switch (choice) {
        case 0: return '"${genFrase()}"';
        case 1: return 'dijo: "${genFrase()}"';
        case 2: return '"${genFrase()}" —${genPalabra()}';
        case 3: return '${genPalabra()} "${genFrase()}" ${genPalabra()}';
        case 4: return '"${genFrase()} "${genFrase()}", dijo"';
        case 5: return "'${genFrase()}'";
        default: return genPalabra();
      }
    }
    
    String genDocumento() {
      int n = rng.nextInt(6) + 1;
      String sep = ['</p>', '\n', '<br/>'][rng.nextInt(3)];
      List<String> docs = [];
      for (int i = 0; i < n; i++) {
        int m = rng.nextInt(4) + 1;
        docs.add(List.generate(m, (_) => genPatron()).join(' '));
      }
      return docs.join(sep);
    }

    List<String> extraerSegmentos(String html) {
      List<String> partes = html.split(reCortafuegos);
      return partes.where((p) => p.isNotEmpty && !reCortafuegos.hasMatch(p)).toList();
    }

    test('sin comillas rectas sobrevivientes', () {
      for (int i = 0; i < 5000; i++) {
        String out = limpiarTextoHtml(genDocumento());
        String plano = out.replaceAll(reTags, '');
        expect(plano.contains('"'), isFalse);
        expect(plano.contains("'"), isFalse);
      }
    });

    test('balance por segmento', () {
      for (int i = 0; i < 5000; i++) {
        String out = limpiarTextoHtml(genDocumento());
        for (String seg in extraerSegmentos(out)) {
          String p = seg.replaceAll(reTags, '');
          int doblesBalance = p.split('»').length - p.split('«').length;
          int simplesBalance = p.split('’').length - p.split('‘').length;
          expect(doblesBalance >= 0 && doblesBalance <= 1, isTrue, reason: seg);
          expect(simplesBalance >= 0 && simplesBalance <= 1, isTrue, reason: seg);
        }
      }
    });
  });

  group('TestTitulosEspeciales', () {
    test('descomponerTitulo separa prefijo y subtitulo', () {
      final cap = descomponerTitulo('Capítulo 1: De Encantador a Espadachín', numeroPorDefecto: 1);
      expect(cap.etiqueta, 'Capítulo 1');
      expect(cap.subtitulo, 'De Encantador a Espadachín');

      final prologo = descomponerTitulo('Prólogo I: Expulsión');
      expect(prologo.esPrologo, isTrue);
      expect(prologo.etiqueta, 'Prólogo I');
      expect(prologo.subtitulo, 'Expulsión');

      final interludio = descomponerTitulo('Interludio 1: El Nuevo Grupo del Héroe');
      expect(interludio.esInterludio, isTrue);
      expect(interludio.etiqueta, 'Interludio 1');
      expect(interludio.subtitulo, 'El Nuevo Grupo del Héroe');

      final autor = descomponerTitulo('Palabras Finales');
      expect(autor.esAutor, isTrue);
      expect(autor.etiqueta, 'Palabras Finales');
    });

    test('clasificarYRenumerarCapitulos maneja libro completo con multiples prologos e interludios', () {
      final titulos = [
        'Prólogo I: Expulsión',
        'Prólogo II: El fin y el principio',
        'Capítulo 1: De Encantador a Espadachín',
        'Capítulo 2: Exploración Guiada',
        'Interludio 1: El Nuevo Grupo del Héroe',
        'Capítulo 3: El Juramento',
        'Interludio 2: Retorno Obligatorio',
        'Interludio 3: Impresiones',
        'Capítulo 4: Guía',
        'Epílogo I: En el centro del mundo',
        'Epílogo II: Para hacer realidad el mundo con el que soñaba el chico',
        'Palabras Finales',
        'Historia corta adicional de la edición digital “Un mundo de plata”',
      ];

      final capitulos = titulos.map((t) => Chapter(titulo: t, htmlCuerpo: '<p>texto</p>')).toList();

      clasificarYRenumerarCapitulos(capitulos, startNum: 1);

      expect(capitulos[0].archivo, 'prologo_01.xhtml');
      expect(capitulos[1].archivo, 'prologo_02.xhtml');
      expect(capitulos[2].archivo, 'C01.xhtml');
      expect(capitulos[3].archivo, 'C02.xhtml');
      expect(capitulos[4].archivo, 'interludio_01.xhtml');
      expect(capitulos[5].archivo, 'C03.xhtml'); // Sigue a C02 sin saltar!
      expect(capitulos[6].archivo, 'interludio_02.xhtml');
      expect(capitulos[7].archivo, 'interludio_03.xhtml');
      expect(capitulos[8].archivo, 'C04.xhtml');
      expect(capitulos[9].archivo, 'epilogo_01.xhtml');
      expect(capitulos[10].archivo, 'epilogo_02.xhtml');
      expect(capitulos[11].archivo, 'autor.xhtml');
      expect(capitulos[12].archivo, 'C05.xhtml'); // Historia corta es C05!
    });

    test('renderCapitulo no duplica el titulo', () {
      const template = '''
<header>
  <h1 title="Capítulo X: Título del capítulo"><i>Capítulo X</i>
    <br/><span class="versalita"><i>Título del capítulo</i></span>
  </h1>
</header>
{{CONTENIDO}}
''';

      final res = renderCapitulo(template, 'Capítulo 1: De Encantador a Espadachín', 1, '<p>Hola</p>');

      expect(res.contains('Capítulo 1: Capítulo 1:'), isFalse);
      expect(res.contains('<h1 title="Capítulo 1: De Encantador a Espadachín"><i>Capítulo 1</i>'), isTrue);
      expect(res.contains('<span class="versalita"><i>De Encantador a Espadachín</i></span>'), isTrue);
    });

    test('renderCapitulo formatea interludio sin la palabra Capitulo', () {
      const template = '''
<header>
  <h1 title="Capítulo X: Título del capítulo"><i>Capítulo X</i>
    <br/><span class="versalita"><i>Título del capítulo</i></span>
  </h1>
</header>
{{CONTENIDO}}
''';

      final res = renderCapitulo(template, 'Interludio 1: El Nuevo Grupo del Héroe', 3, '<p>Hola</p>');

      expect(res.contains('Capítulo'), isFalse);
      expect(res.contains('<h1 title="Interludio 1: El Nuevo Grupo del Héroe"><i>Interludio 1</i>'), isTrue);
      expect(res.contains('<span class="versalita"><i>El Nuevo Grupo del Héroe</i></span>'), isTrue);
    });

    test('renderTablaContenidos genera contenido-2.xhtml estructurado', () {
      final capitulos = [
        Chapter(titulo: 'Prólogo I: Expulsión', htmlCuerpo: '', archivo: 'prologo_01.xhtml'),
        Chapter(titulo: 'Capítulo 1: De Encantador a Espadachín', htmlCuerpo: '', archivo: 'C01.xhtml'),
        Chapter(titulo: 'Interludio 1: El Nuevo Grupo del Héroe', htmlCuerpo: '', archivo: 'interludio_01.xhtml'),
      ];
      final titulos = [
        'Prólogo I: Expulsión',
        'Capítulo 1: De Encantador a Espadachín',
        'Interludio 1: El Nuevo Grupo del Héroe',
      ];

      final toc = renderTablaContenidos(capitulos, titulos);

      expect(toc.contains('<body xml:lang="es" lang="es" epub:type="frontmatter">'), isTrue);
      expect(toc.contains('<section epub:type="toc" role="doc-toc" id="toc" aria-label="Contenido">'), isTrue);
      expect(toc.contains('<h1 class="oculto sigil_not_in_toc" title="Contenido"></h1>'), isTrue);
      expect(toc.contains('<div class="nivel-1">\n      <a href="prologo_01.xhtml">Prólogo I: Expulsión</a>\n    </div>'), isTrue);
      expect(toc.contains('<div class="nivel-1">\n      <a href="C01.xhtml">Capítulo 1: De Encantador a Espadachín</a>\n    </div>'), isTrue);
      expect(toc.contains('<div class="nivel-1">\n      <a href="interludio_01.xhtml">Interludio 1: El Nuevo Grupo del Héroe</a>\n    </div>'), isTrue);
    });

    test('descomponerTitulo y clasificar reconocen traductor y numeración con punto', () {
      final partes0 = descomponerTitulo('0. Una Oferta Dudosa');
      expect(partes0.etiqueta, 'Capítulo 0');
      expect(partes0.subtitulo, 'Una Oferta Dudosa');
      expect(partes0.tituloCompleto, 'Capítulo 0: Una Oferta Dudosa');

      final partes2 = descomponerTitulo('2: Palacio Real');
      expect(partes2.etiqueta, 'Capítulo 2');
      expect(partes2.subtitulo, 'Palacio Real');

      final traductor = descomponerTitulo('Palabras del Traductor');
      expect(traductor.esTraductor, isTrue);
      expect(traductor.etiqueta, 'Palabras del Traductor');

      final titulos = [
        '0. Una Oferta Dudosa',
        '1. La Melancolía del Espadachín Mágico',
        '2: Palacio Real',
        'Palabras del autor',
        'Palabras del Traductor',
      ];
      final capitulos = titulos.map((t) => Chapter(titulo: t, htmlCuerpo: '<p>texto</p>')).toList();
      clasificarYRenumerarCapitulos(capitulos, startNum: 1);

      expect(capitulos[0].archivo, 'C01.xhtml');
      expect(capitulos[1].archivo, 'C02.xhtml');
      expect(capitulos[2].archivo, 'C03.xhtml');
      expect(capitulos[3].archivo, 'autor.xhtml');
      expect(capitulos[3].plantillaNombre, 'autor.xhtml');
      expect(capitulos[4].archivo, 'traductor.xhtml');
      expect(capitulos[4].plantillaNombre, 'traductor.xhtml');
    });

    test('renderCapituloEspecial formatea traductor.xhtml correctamente', () {
      const template = '''
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>Palabras del traductor</title>
</head>
<body>
  <section epub:type="conclusion" role="doc-conclusion" id="conclusion" aria-label="Palabras del traductor">
    <header>
      <h1>Palabras del traductor</h1>
    </header>
    <!-- Aquí va el contenido -->
  </section>
</body>
</html>
''';

      final res = renderCapituloEspecial(template, 'Palabras del Traductor: Notas Finales', 5, '<p>Gracias por leer.</p>');

      expect(res.contains('<h1>Palabras del Traductor</h1>'), isTrue);
      expect(res.contains('<title>Palabras del Traductor</title>'), isTrue);
      expect(res.contains('<p>Gracias por leer.</p>'), isTrue);
      expect(res.contains('</section>'), isTrue);
    });

    test('limpiarHrDuplicados y procesarImagenes no generan hr repetidos', () {
      const htmlConDuplicados = '''
<figure class="dimg"><img src="../Images/05.jpg" alt=""/></figure>
<hr class="sigil_split_marker" />
<hr class="sigil_split_marker" />
<figure class="dimg"><img src="../Images/06.jpg" alt=""/></figure>
<hr class="sigil_split_marker" />
<!--Aqui va el contenido-->
<hr class="sigil_split_marker" />
''';
      final limpio = limpiarHrDuplicados(htmlConDuplicados);
      expect(limpio.contains('<hr class="sigil_split_marker" />\n<hr class="sigil_split_marker" />'), isFalse);
      expect(limpio.contains('<hr class="sigil_split_marker" />\n<!--Aqui va el contenido-->\n<hr class="sigil_split_marker" />'), isFalse);

      final imgProc = procesarImagenes('<p>[IMAGEN 5]</p>\n<p>[IMAGEN 6]</p>');
      expect(imgProc.html.contains('<hr class="sigil_split_marker" />\n<hr class="sigil_split_marker" />'), isFalse);
      expect(imgProc.count, 2);
    });

    test('renderCapitulo con tituloEsImagen false limpia comentario de figure', () {
      const template = '''
<section epub:type="chapter" role="doc-chapter" id="chapter">
<!--Si usa figure, colocar un título oculto antes del figure
    <h1 class="oculto" title="Capítulo X: Título del capítulo"></h1>
    <figure class="dimg"><img src="../Images/02.jpg" alt="" /></figure>
<hr class="sigil_split_marker" />
    <header>
      <h1 class="sigil_not_in_toc"><i>Capítulo X</i>
        <br/><span class="versalita"><i>Título del capítulo</i></span>
      </h1>
    </header>
 -->
    <header>
      <h1 title="Capítulo X: Título del capítulo"><i>Capítulo X</i>
        <br/><span class="versalita"><i>Título del capítulo</i></span>
      </h1>
    </header>
    <!--Aqui va el contenido-->
    {{CONTENIDO}}
</section>
''';

      final res = renderCapitulo(template, 'Capítulo 1: De Encantador a Espadachín', 1, '<p>Hola</p>', tituloEsImagen: false);

      expect(res.contains('<!--Si usa figure'), isFalse);
      expect(res.contains('<h1 title="Capítulo 1: De Encantador a Espadachín"><i>Capítulo 1</i>'), isTrue);
      expect(res.contains('<h1 class="oculto"'), isFalse);
    });

    test('renderCapitulo con tituloEsImagen true descomenta cabecera, preserva header y absorbe figura', () {
      const template = '''
<section epub:type="chapter" role="doc-chapter" id="chapter">
<!--Si usa figure, colocar un título oculto antes del figure
    <h1 class="oculto" title="Capítulo X: Título del capítulo"></h1>
    <figure class="dimg"><img src="../Images/02.jpg" alt="" /></figure>
<hr class="sigil_split_marker" />
    <header>
      <h1 class="sigil_not_in_toc"><i>Capítulo X</i>
        <br/><span class="versalita"><i>Título del capítulo</i></span>
      </h1>
    </header>
 -->
    <header>
      <h1 title="Capítulo X: Título del capítulo"><i>Capítulo X</i>
        <br/><span class="versalita"><i>Título del capítulo</i></span>
      </h1>
    </header>
    <!--Aqui va el contenido-->
    {{CONTENIDO}}
</section>
''';

      const cuerpoConImagenes = '''
<hr class="sigil_split_marker" />
<figure class="dimg"><img src="../Images/07.jpg" alt=""/></figure>
<hr class="sigil_split_marker" />
<figure class="dimg"><img src="../Images/08.jpg" alt=""/></figure>
<hr class="sigil_split_marker" />
<p>Texto</p>
''';

      final res = renderCapitulo(
        template,
        'Capítulo 1: La Melancolía de una Maestra (#47.5)',
        1,
        cuerpoConImagenes,
        tituloEsImagen: true,
        numeroImagenTitulo: '07',
      );

      // Tiene h1 oculto con el título completo
      expect(res.contains('<h1 class="oculto" title="Capítulo 1: La Melancolía de una Maestra (#47.5)"></h1>'), isTrue);
      // Tiene la figura del título con la imagen 07.jpg
      expect(res.contains('<figure class="dimg"><img src="../Images/07.jpg" alt="" /></figure>'), isTrue);
      // Conserva el header visible con sigil_not_in_toc
      expect(res.contains('<h1 class="sigil_not_in_toc"><i>Capítulo 1</i>'), isTrue);
      expect(res.contains('<span class="versalita"><i>La Melancolía de una Maestra (#47.5)</i></span>'), isTrue);
      // 07.jpg fue absorbida de la cabecera del cuerpo y no se repite dos veces
      final count07 = RegExp(r'07\.jpg').allMatches(res).length;
      expect(count07, 1);
      // No hay hr dobles pegados
      expect(res.contains('<hr class="sigil_split_marker" />\n<hr class="sigil_split_marker" />'), isFalse);
      expect(res.contains('<hr class="sigil_split_marker" />\n<!--Aqui va el contenido-->\n<hr class="sigil_split_marker" />'), isFalse);
      expect(res.contains(r'$1'), isFalse);
    });

    test('renderCapitulo con titulo imagen y contenido con imagenes consecutivas no deja \$1 ni split tras header', () {
      const template = '''
<section epub:type="chapter" role="doc-chapter" id="chapter">
<!--Si usa figure, colocar un título oculto antes del figure
    <h1 class="oculto" title="Capítulo X: Título del capítulo"></h1>
    <figure class="dimg"><img src="../Images/02.jpg" alt="" /></figure>
<hr class="sigil_split_marker" />
    <header>
      <h1 class="sigil_not_in_toc"><i>Capítulo X</i>
        <br/><span class="versalita"><i>Título del capítulo</i></span>
      </h1>
    </header>
 -->
    <header>
      <h1 title="Capítulo X: Título del capítulo"><i>Capítulo X</i>
        <br/><span class="versalita"><i>Título del capítulo</i></span>
      </h1>
    </header>
    <!--Aqui va el contenido-->
    {{CONTENIDO}}
</section>
''';

      const cuerpoConImagenes = '''
<hr class="sigil_split_marker" />
<figure class="dimg"><img src="../Images/05.jpg" alt=""/></figure>
<hr class="sigil_split_marker" />
<figure class="dimg"><img src="../Images/06.jpg" alt=""/></figure>
<hr class="sigil_split_marker" />
<p><i><b>(0/6)</b></i></p>
''';

      final res = renderCapitulo(
        template,
        'Capítulo 0: Las Llamas sobre la Vela',
        0,
        cuerpoConImagenes,
        tituloEsImagen: true,
        numeroImagenTitulo: '04',
      );

      // No debe contener el literal \$1
      expect(res.contains(r'$1'), isFalse);
      // No debe haber split marker inmediatamente tras el header / <!--Aqui va el contenido-->
      expect(RegExp(r'<!--Aqui va el contenido-->\s*<hr class="sigil_split_marker"', caseSensitive: false).hasMatch(res), isFalse);
      // Debe conservar la imagen 05 directamente bajo el contenido
      expect(res.contains('<figure class="dimg"><img src="../Images/05.jpg" alt=""/></figure>'), isTrue);
      // Debe conservar exactamente un split marker entre la imagen 05 y 06
      expect(RegExp(r'05\.jpg".*?</figure>\s*<hr class="sigil_split_marker"\s*/>\s*<figure', dotAll: true).hasMatch(res), isTrue);
      // La imagen 04 debe tener su split marker
      expect(RegExp(r'04\.jpg".*?</figure>\s*<hr class="sigil_split_marker"\s*/>\s*<header', dotAll: true).hasMatch(res), isTrue);
    });
  });
}

