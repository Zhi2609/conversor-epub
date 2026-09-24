import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/limpieza.dart';
import 'package:conversor_epub/motor/plantillas.dart';
import 'package:conversor_epub/motor/render.dart';
import 'package:conversor_epub/motor/modelo.dart';

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

    String _palabra() => palabras[rng.nextInt(palabras.length)];
    
    String _frase() {
      int count = rng.nextInt(6) + 1;
      return List.generate(count, (_) => _palabra()).join(' ');
    }
    
    String _patron() {
      int choice = rng.nextInt(7);
      switch (choice) {
        case 0: return '"${_frase()}"';
        case 1: return 'dijo: "${_frase()}"';
        case 2: return '"${_frase()}" —${_palabra()}';
        case 3: return '${_palabra()} "${_frase()}" ${_palabra()}';
        case 4: return '"${_frase()} "${_frase()}", dijo"';
        case 5: return "'${_frase()}'";
        default: return _palabra();
      }
    }
    
    String _documento() {
      int n = rng.nextInt(6) + 1;
      String sep = ['</p>', '\n', '<br/>'][rng.nextInt(3)];
      List<String> docs = [];
      for (int i = 0; i < n; i++) {
        int m = rng.nextInt(4) + 1;
        docs.add(List.generate(m, (_) => _patron()).join(' '));
      }
      return docs.join(sep);
    }

    List<String> _segmentos(String html) {
      List<String> partes = html.split(reCortafuegos);
      return partes.where((p) => p.isNotEmpty && !reCortafuegos.hasMatch(p)).toList();
    }

    test('sin comillas rectas sobrevivientes', () {
      for (int i = 0; i < 5000; i++) {
        String out = limpiarTextoHtml(_documento());
        String plano = out.replaceAll(reTags, '');
        expect(plano.contains('"'), isFalse);
        expect(plano.contains("'"), isFalse);
      }
    });

    test('balance por segmento', () {
      for (int i = 0; i < 5000; i++) {
        String out = limpiarTextoHtml(_documento());
        for (String seg in _segmentos(out)) {
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
  });
}

