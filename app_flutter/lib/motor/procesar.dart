import 'dart:io';
import 'package:path/path.dart' as p;
import 'modelo.dart';
import 'limpieza.dart';
import 'notas.dart';
import 'imagenes.dart';
import 'division.dart';
import 'adaptadores.dart';
import 'plantillas.dart';

class _ProcesarDocumentoResult {
  final String html;
  final int nImagenes;
  final int nSeparadores;
  _ProcesarDocumentoResult(this.html, this.nImagenes, this.nSeparadores);
}

_ProcesarDocumentoResult _procesarDocumento(String html, List<Nota> notas, {List<String>? imagenesPlaceholder}) {
  final extraerResult = extraerNotas(html);
  html = extraerResult.html;
  notas.addAll(extraerResult.notas);
  
  html = limpiarTextoHtml(html);

  int nImagenes = 0;
  if (imagenesPlaceholder != null && imagenesPlaceholder.isNotEmpty) {
    html = restaurarImagenesMarkdown(html, imagenesPlaceholder);
    nImagenes += imagenesPlaceholder.length;
  }

  final procesarImgResult = procesarImagenes(html);
  html = procesarImgResult.html;
  nImagenes += procesarImgResult.count;

  final procesarSepResult = procesarSeparadores(html);
  html = procesarSepResult.html;
  int nSeparadores = procesarSepResult.count;

  return _ProcesarDocumentoResult(html, nImagenes, nSeparadores);
}

Future<Resultado> procesar({
  required String modo,
  required String rutaEntrada,
  required String rutaTemplate,
  List<String>? titulos,
  int startNum = 1,
  String? rutaPlantillas,
}) async {
  if (!['word', 'calibre', 'markdown', 'pdf'].contains(modo)) {
    throw Exception('Modo desconocido: $modo');
  }

  String template = File(rutaTemplate).readAsStringSync();
  if (!template.contains('{{CONTENIDO}}')) {
    throw Exception('El template no contiene el placeholder {{CONTENIDO}}');
  }

  List<Nota> notas = [];
  List<Chapter> capitulos = [];
  List<String> avisos = [];
  int nImagenesTotal = 0;
  int nSeparadoresTotal = 0;

  if (modo == 'word' || modo == 'pdf') {
    String htmlRaw;
    if (modo == 'word') {
      htmlRaw = await convertirDocx(rutaEntrada);
    } else {
      htmlRaw = await convertirPdf(rutaEntrada);
    }
    
    final procResult = _procesarDocumento(htmlRaw, notas);
    nImagenesTotal += procResult.nImagenes;
    nSeparadoresTotal += procResult.nSeparadores;
    
    capitulos = dividirEnCapitulos(procResult.html, titulos: titulos, startNum: startNum);
    for (var cap in capitulos) {
      cap.htmlRaw = htmlRaw;
    }
  } else {
    DocumentosResult resultDocs;
    if (modo == 'calibre') {
      resultDocs = documentosCalibre(rutaEntrada);
    } else {
      resultDocs = await documentosMarkdown(rutaEntrada);
    }
    avisos.addAll(resultDocs.avisos);
    
    for (int indice = 0; indice < resultDocs.documentos.length; indice++) {
      final doc = resultDocs.documentos[indice];
      final procResult = _procesarDocumento(doc.html, notas, imagenesPlaceholder: doc.imagenesPlaceholder);
      nImagenesTotal += procResult.nImagenes;
      nSeparadoresTotal += procResult.nSeparadores;

      int num = startNum + indice;
      String titulo = (titulos != null && indice < titulos.length) ? titulos[indice] : (doc.titulo ?? 'Capítulo $num');
      capitulos.add(Chapter(titulo: titulo, htmlCuerpo: procResult.html.trim(), htmlRaw: doc.html));
    }
  }

  if (rutaPlantillas != null) {
    for (var capitulo in capitulos) {
      String? archivo = clasificarEspecial(capitulo.titulo);
      if (archivo != null) {
        String plantillaRuta = p.join(rutaPlantillas, archivo);
        if (File(plantillaRuta).existsSync()) {
          capitulo.archivo = archivo;
          capitulo.plantillaRuta = plantillaRuta;
        } else {
          avisos.add('"${capitulo.titulo}": plantilla especial no encontrada ($archivo), se usa la numeración normal');
        }
      }
    }
  }

  int numero = startNum;
  for (var capitulo in capitulos) {
    if (capitulo.archivo == null) {
      capitulo.archivo = 'C${numero.toString().padLeft(2, '0')}.xhtml';
      numero++;
    }
  }

  asignarCapitulos(notas, capitulos, startNum: startNum);

  return Resultado(
    capitulos: capitulos,
    notas: notas,
    contadores: Contadores(
      capitulos: capitulos.length,
      notas: notas.length,
      imagenes: nImagenesTotal,
      separadores: nSeparadoresTotal,
    ),
    avisos: avisos,
  );
}
