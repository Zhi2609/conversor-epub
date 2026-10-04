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

/// Representación estructurada de los metadatos OPF del libro.
class BookMetadata {
  final String title;
  final String titleSort;
  final String series;
  final String volume;
  final String author;
  final String translator;
  final String illustrator;
  final String proofreader;
  final String publisher;
  final String synopsis;
  final String language;
  final String bookId;
  final DateTime? date;

  const BookMetadata({
    this.title = '',
    this.titleSort = '',
    this.series = '',
    this.volume = '',
    this.author = '',
    this.translator = '',
    this.illustrator = '',
    this.proofreader = '',
    this.publisher = '',
    this.synopsis = '',
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

    // Patrones típicos: "Nombre de la Novela - Vol 01", "Nombre de la Novela - Volumen 1", etc.
    final matchVol = RegExp(
      r'^(.*?)\s*[-_–]\s*(?:Vol(?:umen|\.?)?)\s*(\d+.*)$',
      caseSensitive: false,
    ).firstMatch(baseName);

    if (matchVol != null) {
      detectedSeries = matchVol.group(1)!.trim();
      detectedTitle = detectedSeries;
      detectedVolume = matchVol.group(2)!.trim();
    }

    return BookMetadata(
      title: detectedTitle,
      series: detectedSeries,
      volume: detectedVolume,
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
    String? author,
    String? translator,
    String? illustrator,
    String? proofreader,
    String? publisher,
    String? synopsis,
    String? language,
    String? bookId,
    DateTime? date,
  }) {
    return BookMetadata(
      title: title ?? this.title,
      titleSort: titleSort ?? this.titleSort,
      series: series ?? this.series,
      volume: volume ?? this.volume,
      author: author ?? this.author,
      translator: translator ?? this.translator,
      illustrator: illustrator ?? this.illustrator,
      proofreader: proofreader ?? this.proofreader,
      publisher: publisher ?? this.publisher,
      synopsis: synopsis ?? this.synopsis,
      language: language ?? this.language,
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
    );
  }

  /// Título formal para encabezado o metadatos completos.
  String get displayTitle {
    if (series.isNotEmpty && volume.isNotEmpty) {
      return '$series - Volumen $volume';
    }
    return title.isNotEmpty ? title : 'Sin título';
  }
}
