class Chapter {
  String titulo;
  String htmlCuerpo;
  String htmlRaw;
  String? archivo;
  String? plantillaRuta;
  String? plantillaNombre;
  bool tituloEsImagen;
  String? numeroImagenTitulo;

  Chapter({
    required this.titulo,
    required this.htmlCuerpo,
    this.htmlRaw = "",
    this.archivo,
    this.plantillaRuta,
    this.plantillaNombre,
    this.tituloEsImagen = false,
    this.numeroImagenTitulo,
  });
}

class Nota {
  int num;
  String texto;
  int? capNum;
  String? capArchivo;

  Nota({
    required this.num,
    required this.texto,
    this.capNum,
    this.capArchivo,
  });
}

class Contadores {
  int capitulos;
  int notas;
  int imagenes;
  int separadores;

  Contadores({
    required this.capitulos,
    required this.notas,
    required this.imagenes,
    required this.separadores,
  });
}

class Resultado {
  List<Chapter> capitulos;
  List<Nota> notas;
  Contadores contadores;
  List<String> avisos;

  Resultado({
    required this.capitulos,
    required this.notas,
    required this.contadores,
    List<String>? avisos,
  }) : avisos = avisos ?? [];
}
