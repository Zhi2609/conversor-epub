import 'dart:math';
import 'secciones.dart';

class SearchMatch {
  final String sectionId;
  final String sectionTitle;
  final int startOffset;
  final int endOffset;
  final int lineNumber;
  final String previewBefore;
  final String matchText;
  final String previewAfter;

  const SearchMatch({
    required this.sectionId,
    required this.sectionTitle,
    required this.startOffset,
    required this.endOffset,
    required this.lineNumber,
    required this.previewBefore,
    required this.matchText,
    required this.previewAfter,
  });

  /// Fragmento formateado para mostrar en una lista
  String get fullPreview => '$previewBefore[$matchText]$previewAfter';
}

class SearchReplaceEngine {
  /// Busca ocurrencias del patrón en las secciones provistas.
  static List<SearchMatch> search(
    List<SectionItem> sections, {
    required String pattern,
    bool isRegex = false,
    bool caseSensitive = true,
    String? onlySectionId,
  }) {
    if (pattern.isEmpty) return const [];

    RegExp regExp;
    try {
      final safePattern = isRegex ? pattern : RegExp.escape(pattern);
      regExp = RegExp(safePattern, caseSensitive: caseSensitive, multiLine: true);
    } catch (e) {
      throw FormatException('Sintaxis de expresión regular inválida: $e');
    }

    final matches = <SearchMatch>[];

    for (final sec in sections) {
      if (onlySectionId != null && sec.id != onlySectionId) continue;
      if (sec.htmlContent.isEmpty) continue;

      final text = sec.htmlContent;
      for (final m in regExp.allMatches(text)) {
        final start = m.start;
        final end = m.end;
        final matchedText = text.substring(start, end);

        // Calcular número de línea (1-indexado)
        final line = '\n'.allMatches(text.substring(0, start)).length + 1;

        // Snippet contextual (hasta 30 caracteres antes y después)
        final snippetStart = max(0, start - 30);
        final snippetEnd = min(text.length, end + 30);

        String before = text.substring(snippetStart, start);
        String after = text.substring(end, snippetEnd);

        // Limpieza visual de saltos de línea para el preview
        before = before.replaceAll('\n', ' ');
        after = after.replaceAll('\n', ' ');

        matches.add(SearchMatch(
          sectionId: sec.id,
          sectionTitle: sec.title.isNotEmpty ? sec.title : sec.fileName,
          startOffset: start,
          endOffset: end,
          lineNumber: line,
          previewBefore: before,
          matchText: matchedText,
          previewAfter: after,
        ));
      }
    }

    return matches;
  }

  /// Reemplaza una única coincidencia específica en una sección.
  static SectionItem applyReplaceSingle(
    SectionItem section,
    SearchMatch match,
    String replacement,
  ) {
    final text = section.htmlContent;
    if (match.startOffset < 0 || match.endOffset > text.length) {
      return section;
    }

    return section.copyWith(htmlContent: text.replaceRange(match.startOffset, match.endOffset, replacement));
  }

  /// Reemplaza todas las coincidencias del patrón en todas las secciones (o la indicada).
  static ({List<SectionItem> updatedSections, int totalReplacements}) applyReplaceAll(
    List<SectionItem> sections, {
    required String pattern,
    required String replacement,
    bool isRegex = false,
    bool caseSensitive = true,
    String? onlySectionId,
  }) {
    if (pattern.isEmpty) {
      return (updatedSections: sections, totalReplacements: 0);
    }

    RegExp regExp;
    try {
      final safePattern = isRegex ? pattern : RegExp.escape(pattern);
      regExp = RegExp(safePattern, caseSensitive: caseSensitive, multiLine: true);
    } catch (e) {
      throw FormatException('Sintaxis de expresión regular inválida: $e');
    }

    int total = 0;
    final updated = <SectionItem>[];

    for (final sec in sections) {
      if (onlySectionId != null && sec.id != onlySectionId) {
        updated.add(sec);
        continue;
      }

      final text = sec.htmlContent;
      final count = regExp.allMatches(text).length;
      if (count == 0) {
        updated.add(sec);
        continue;
      }

      total += count;
      final newContent = text.replaceAll(regExp, replacement);
      updated.add(sec.copyWith(htmlContent: newContent));
    }

    return (updatedSections: updated, totalReplacements: total);
  }
}
