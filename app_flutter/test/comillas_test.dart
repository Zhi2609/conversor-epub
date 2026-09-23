import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:conversor_epub/motor/limpieza.dart';

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
}
