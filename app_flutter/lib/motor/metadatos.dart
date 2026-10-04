import 'dart:math';
import 'package:path/path.dart' as p;

final _random = Random.secure();

/// RFC 9562: 48 bits de marca de tiempo en milisegundos, versión 7, variante 10.
/// Ordenable cronológicamente y canónico para BookId en ePub 3.
String uuidV7([DateTime? at]) {
  final millis = (at ?? DateTime.now()).millisecondsSinceEpoch;
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  for (var i = 0; i < 6; i++) {
    bytes[i] = (millis >> (8 * (5 - i))) & 0xff;
  }
  bytes[6] = 0x70 | (bytes[6] & 0x0f);
  bytes[8] = 0x80 | (bytes[8] & 0x3f);
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Demografías canónicas de ZeePubs divididas por categoría
const List<String> kDemografiasEdad = [
  'Maduro',
  'Juvenil',
];

const List<String> kDemografiasAudiencia = [
  'Adultas/Josei',
  'Adultos/Seinen',
  'Chicas/Shoujo',
  'Chicos/Shounen',
];

/// 20 Géneros canónicos de ZeePubs
const List<String> kGenerosZeePubs = [
  'Acción',
  'Aventura',
  'Bélico',
  'Ciencia ficción',
  'Comedia',
  'Deporte',
  'Drama',
  'Erótico',
  'Escolar',
  'Fantasía',
  'Histórico',
  'LGBTQI+',
  'Misterio',
  'Parodia',
  'Policial',
  'Psicológico',
  'Recuentos de la vida',
  'Romance',
  'Sobrenatural',
  'Terror',
];

/// Ordena la lista de etiquetas (dc:subject) según la regla estricta de ZeePubs:
/// 1. Demografía de Edad/Madurez (Maduro o Juvenil)
/// 2. Demografía de Audiencia/Público (Adultas/Josei, Adultos/Seinen, Chicas/Shoujo o Chicos/Shounen)
/// 3. Resto de etiquetas (géneros literarios y personalizadas) en orden alfabético.
List<String> ordenarSubjectsCanonico(Iterable<String> subjects) {
  String? demoEdad;
  String? demoAudiencia;
  final resto = <String>[];

  for (final item in subjects) {
    final s = item.trim();
    if (s.isEmpty) continue;
    if (demoEdad == null && kDemografiasEdad.contains(s)) {
      demoEdad = s;
    } else if (demoAudiencia == null && kDemografiasAudiencia.contains(s)) {
      demoAudiencia = s;
    } else {
      resto.add(s);
    }
  }

  // Orden alfabético insensible a mayúsculas/minúsculas
  resto.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final res = <String>[];
  if (demoEdad != null) res.add(demoEdad);
  if (demoAudiencia != null) res.add(demoAudiencia);
  res.addAll(resto);
  return res;
}

/// Formatea un ISBN-13 si se introdujo como 13 dígitos continuos sin guiones:
/// Patrón canónico de Base3: 000-00-0000-000-0 (3-2-4-3-1)
String formatearIsbn13(String raw) {
  final limpio = raw.trim();
  if (limpio.contains('-')) return limpio;
  final soloDigitos = limpio.replaceAll(RegExp(r'\s+'), '');
  if (soloDigitos.length == 13 && RegExp(r'^\d{13}$').hasMatch(soloDigitos)) {
    return '${soloDigitos.substring(0, 3)}-${soloDigitos.substring(3, 5)}-${soloDigitos.substring(5, 9)}-${soloDigitos.substring(9, 12)}-${soloDigitos.substring(12, 13)}';
  }
  return limpio;
}

/// Formatea un ISBN-10 si se introdujo como 10 caracteres/dígitos continuos sin guiones:
/// Patrón canónico de Base3: 00-0000-000-0 (2-4-3-1)
String formatearIsbn10(String raw) {
  final limpio = raw.trim();
  if (limpio.contains('-')) return limpio;
  final soloDigitos = limpio.replaceAll(RegExp(r'\s+'), '');
  if (soloDigitos.length == 10 && RegExp(r'^\d{9}[\dX]$', caseSensitive: false).hasMatch(soloDigitos)) {
    return '${soloDigitos.substring(0, 2)}-${soloDigitos.substring(2, 6)}-${soloDigitos.substring(6, 9)}-${soloDigitos.substring(9, 10).toUpperCase()}';
  }
  return limpio;
}

/// Representación estructurada de los metadatos OPF del libro según Base3_v1.15.0.epub.
class BookMetadata {
  final String title;
  final String titleSort;
  final String series;
  final String volume;
  final String groupTag; // Ej: SIGLAS-GRUPO

  // Autor (occidental + japonés + indexación)
  final String author;
  final String authorJapanese; // alternate-script xml:lang="ja"
  final String authorFileAs; // file-as (ej: Apellido, Autor)

  // Ilustrador (occidental + japonés + indexación)
  final String illustrator;
  final String illustratorJapanese; // alternate-script xml:lang="ja"
  final String illustratorFileAs; // file-as (ej: Apellido, Ilustrador)

  // Equipo y Publicación
  final String translator; // Rol trl
  final String proofreader; // Rol mrk (por defecto 'Zhi')
  final String publisher; // Editorial / Grupo Traductor
  final String projectUrl; // uri-id (URL web oficial)

  // Clasificación y Taxonomía
  final String bookType; // dc:type (ej: 'Novela Ligera')
  final List<String> subjects; // dc:subject (demografías y géneros)
  final String synopsis;

  // Identificadores y sistema
  final String isbn13; // urn:isbn:...
  final String isbn10;
  final String amazonId; // urn:amazon:...
  final String bookId; // UUID v7
  final String language;
  final DateTime? date;

  // Constantes canónicas inmutables de Base3
  static const int calibreRating = 9;
  static const String defaultDistributor = 'ZeePubs';

  const BookMetadata({
    this.title = '',
    this.titleSort = '',
    this.series = '',
    this.volume = '',
    this.groupTag = '',
    this.author = '',
    this.authorJapanese = '',
    this.authorFileAs = '',
    this.illustrator = '',
    this.illustratorJapanese = '',
    this.illustratorFileAs = '',
    this.translator = '',
    this.proofreader = 'Zhi',
    this.publisher = '',
    this.projectUrl = '',
    this.bookType = 'Novela Ligera',
    this.subjects = const [],
    this.synopsis = '',
    this.isbn13 = '',
    this.isbn10 = '',
    this.amazonId = '',
    this.language = 'es',
    this.bookId = '',
    this.date,
  });

  /// Crea metadatos iniciales deduciendo título y volumen a partir del nombre de archivo.
  factory BookMetadata.fromFileName(String filePath) {
    final baseName = p.basenameWithoutExtension(filePath).trim();
    String detectedTitle = baseName;
    String detectedSeries = '';
    String detectedVolume = '';
    String detectedTag = '';

    // Detectar etiqueta de grupo entre corchetes al final ej: "... [SIGLAS]"
    final matchTag = RegExp(r'\[([^\]]+)\]\s*$').firstMatch(baseName);
    if (matchTag != null) {
      detectedTag = matchTag.group(1)!.trim();
      detectedTitle = baseName.replaceAll(RegExp(r'\s*\[[^\]]+\]\s*$'), '').trim();
    }

    // Patrones típicos: "Nombre de la Novela - Vol 01", "Nombre de la Novela - Volumen 1", etc.
    final matchVol = RegExp(
      r'^(.*?)\s*[-_–]\s*(?:Vol(?:umen|\.?)?)\s*(\d+.*)$',
      caseSensitive: false,
    ).firstMatch(detectedTitle);

    if (matchVol != null) {
      detectedSeries = matchVol.group(1)!.trim();
      detectedTitle = detectedSeries;
      detectedVolume = matchVol.group(2)!.trim();
    }

    return BookMetadata(
      title: detectedTitle,
      series: detectedSeries,
      volume: detectedVolume,
      groupTag: detectedTag,
      language: 'es',
      bookId: uuidV7(),
      date: DateTime.now(),
    );
  }

  BookMetadata copyWith({
    String? title,
    String? titleSort,
    String? series,
    String? volume,
    String? groupTag,
    String? author,
    String? authorJapanese,
    String? authorFileAs,
    String? illustrator,
    String? illustratorJapanese,
    String? illustratorFileAs,
    String? translator,
    String? proofreader,
    String? publisher,
    String? projectUrl,
    String? bookType,
    List<String>? subjects,
    String? synopsis,
    String? isbn13,
    String? isbn10,
    String? amazonId,
    String? language,
    String? bookId,
    DateTime? date,
  }) {
    return BookMetadata(
      title: title ?? this.title,
      titleSort: titleSort ?? this.titleSort,
      series: series ?? this.series,
      volume: volume ?? this.volume,
      groupTag: groupTag ?? this.groupTag,
      author: author ?? this.author,
      authorJapanese: authorJapanese ?? this.authorJapanese,
      authorFileAs: authorFileAs ?? this.authorFileAs,
      illustrator: illustrator ?? this.illustrator,
      illustratorJapanese: illustratorJapanese ?? this.illustratorJapanese,
      illustratorFileAs: illustratorFileAs ?? this.illustratorFileAs,
      translator: translator ?? this.translator,
      proofreader: proofreader ?? this.proofreader,
      publisher: publisher ?? this.publisher,
      projectUrl: projectUrl ?? this.projectUrl,
      bookType: bookType ?? this.bookType,
      subjects: subjects ?? this.subjects,
      synopsis: synopsis ?? this.synopsis,
      isbn13: isbn13 ?? this.isbn13,
      isbn10: isbn10 ?? this.isbn10,
      amazonId: amazonId ?? this.amazonId,
      language: language ?? this.language,
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
    );
  }

  /// Título formal para encabezado o metadatos completos.
  /// En Base3: "Nombre de la novela en romamji – Volumen 01"
  String get displayTitle {
    final baseTitle = title.isNotEmpty ? title : (series.isNotEmpty ? series : 'Sin título');
    if (volume.isNotEmpty) {
      return '$baseTitle - Volumen $volume';
    }
    return baseTitle;
  }

  /// Título con etiqueta de grupo al final si existe (como en Base3: '... [SIGLAS-GRUPO]')
  String get effectiveTitle {
    final base = displayTitle;
    if (groupTag.trim().isNotEmpty) {
      final tag = groupTag.trim().startsWith('[') && groupTag.trim().endsWith(']')
          ? groupTag.trim()
          : '[${groupTag.trim()}]';
      return '$base $tag';
    }
    return base;
  }

  /// Nombre canónico para el archivo compilado:
  /// "Nombre de novela - V01 [GrupoTraductor].epub"
  String get defaultFileName {
    String nombre = title.isNotEmpty ? title : (series.isNotEmpty ? series : 'Novela');
    nombre = nombre.replaceAll(RegExp(r'\s*\[[^\]]+\]\s*$'), '').trim();

    String volStr = 'V01';
    final volLimpio = volume.trim().replaceAll(RegExp(r'^[Vv]ol(?:umen|\.?)?\s*', caseSensitive: false), '').trim();
    if (volLimpio.isNotEmpty) {
      final n = int.tryParse(volLimpio);
      volStr = n != null ? 'V${n.toString().padLeft(2, '0')}' : 'V$volLimpio';
    }

    final tag = groupTag.trim().isNotEmpty
        ? groupTag.trim().replaceAll(RegExp(r'^\[|\]$'), '')
        : (publisher.trim().isNotEmpty ? publisher.trim() : '');

    final buffer = StringBuffer(nombre);
    buffer.write(' - $volStr');
    if (tag.isNotEmpty) {
      buffer.write(' [$tag]');
    }
    return '${buffer.toString()}.epub';
  }
}
