import 'package:flutter/material.dart';
import '../../motor/secciones.dart';
import '../../motor/busqueda_reemplazo.dart';

class DialogoBuscarReemplazar extends StatefulWidget {
  final List<SectionItem> secciones;
  final SectionItem? seccionActual;
  final ValueChanged<List<SectionItem>> onAplicarCambios;

  const DialogoBuscarReemplazar({
    super.key,
    required this.secciones,
    required this.seccionActual,
    required this.onAplicarCambios,
  });

  @override
  State<DialogoBuscarReemplazar> createState() => _DialogoBuscarReemplazarState();
}

class _DialogoBuscarReemplazarState extends State<DialogoBuscarReemplazar> {
  late final TextEditingController _patronController;
  late final TextEditingController _reemplazoController;

  bool _esRegex = false;
  bool _caseSensitive = true;
  bool _soloSeccionActual = false;

  List<SearchMatch> _coincidencias = [];
  String? _errorRegex;
  String? _mensajeStatus;

  late List<SectionItem> _seccionesLocales;

  @override
  void initState() {
    super.initState();
    _patronController = TextEditingController();
    _reemplazoController = TextEditingController();
    _seccionesLocales = List.from(widget.secciones);
  }

  @override
  void dispose() {
    _patronController.dispose();
    _reemplazoController.dispose();
    super.dispose();
  }

  void _ejecutarBusqueda() {
    final patron = _patronController.text;
    if (patron.isEmpty) {
      setState(() {
        _coincidencias = [];
        _errorRegex = null;
        _mensajeStatus = null;
      });
      return;
    }

    try {
      final matches = SearchReplaceEngine.search(
        _seccionesLocales,
        pattern: patron,
        isRegex: _esRegex,
        caseSensitive: _caseSensitive,
        onlySectionId: _soloSeccionActual ? widget.seccionActual?.id : null,
      );

      setState(() {
        _coincidencias = matches;
        _errorRegex = null;
        _mensajeStatus = '${matches.length} coincidencia(s) encontrada(s)';
      });
    } on FormatException catch (e) {
      setState(() {
        _errorRegex = e.message;
        _coincidencias = [];
        _mensajeStatus = null;
      });
    }
  }

  void _reemplazarTodo() {
    final patron = _patronController.text;
    final reemplazo = _reemplazoController.text;
    if (patron.isEmpty) return;

    try {
      final res = SearchReplaceEngine.applyReplaceAll(
        _seccionesLocales,
        pattern: patron,
        replacement: reemplazo,
        isRegex: _esRegex,
        caseSensitive: _caseSensitive,
        onlySectionId: _soloSeccionActual ? widget.seccionActual?.id : null,
      );

      setState(() {
        _seccionesLocales = res.updatedSections;
        _mensajeStatus = '✅ Se reemplazaron ${res.totalReplacements} coincidencia(s)';
      });

      widget.onAplicarCambios(_seccionesLocales);
      _ejecutarBusqueda();
    } on FormatException catch (e) {
      setState(() {
        _errorRegex = e.message;
      });
    }
  }

  void _reemplazarUno(SearchMatch match) {
    final secIndex = _seccionesLocales.indexWhere((s) => s.id == match.sectionId);
    if (secIndex == -1) return;

    final secActualizada = SearchReplaceEngine.applyReplaceSingle(
      _seccionesLocales[secIndex],
      match,
      _reemplazoController.text,
    );

    setState(() {
      _seccionesLocales[secIndex] = secActualizada;
      _mensajeStatus = '✅ Coincidencia reemplazada';
    });

    widget.onAplicarCambios(_seccionesLocales);
    _ejecutarBusqueda();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 700,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            Row(
              children: [
                const Icon(Icons.find_replace, color: Color(0xFF89B4FA), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Buscar y Reemplazar (Regex)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCDD6F4),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF6C7086)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Campos de texto
            TextField(
              controller: _patronController,
              style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4), fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Buscar patrón...',
                labelStyle: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF89B4FA)),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF181825),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => _ejecutarBusqueda(),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _reemplazoController,
              style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4), fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Reemplazar con...',
                labelStyle: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 12),
                prefixIcon: const Icon(Icons.edit_note, size: 16, color: Color(0xFFA6E3A1)),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF181825),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),

            // Opciones y Toggles
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Regex (.*)'),
                  selected: _esRegex,
                  selectedColor: const Color(0xFF89B4FA).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: _esRegex ? const Color(0xFF89B4FA) : const Color(0xFFA6ADC8),
                  ),
                  onSelected: (v) {
                    setState(() => _esRegex = v);
                    _ejecutarBusqueda();
                  },
                ),
                FilterChip(
                  label: const Text('Mayúsculas/Minúsculas [Aa]'),
                  selected: _caseSensitive,
                  selectedColor: const Color(0xFF89B4FA).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: _caseSensitive ? const Color(0xFF89B4FA) : const Color(0xFFA6ADC8),
                  ),
                  onSelected: (v) {
                    setState(() => _caseSensitive = v);
                    _ejecutarBusqueda();
                  },
                ),
                if (widget.seccionActual != null)
                  FilterChip(
                    label: Text('Solo en "${widget.seccionActual!.title}"'),
                    selected: _soloSeccionActual,
                    selectedColor: const Color(0xFF89B4FA).withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: _soloSeccionActual ? const Color(0xFF89B4FA) : const Color(0xFFA6ADC8),
                    ),
                    onSelected: (v) {
                      setState(() => _soloSeccionActual = v);
                      _ejecutarBusqueda();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Mensajes de error o status
            if (_errorRegex != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF38BA8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _errorRegex!,
                  style: const TextStyle(color: Color(0xFFF38BA8), fontSize: 11),
                ),
              ),

            if (_mensajeStatus != null && _errorRegex == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _mensajeStatus!,
                  style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 6),

            // Lista de Coincidencias
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF181825),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: _coincidencias.isEmpty
                    ? Center(
                        child: Text(
                          _patronController.text.isEmpty
                              ? 'Escribe un término o expresión para buscar.'
                              : 'No se encontraron coincidencias.',
                          style: const TextStyle(color: Color(0xFF6C7086), fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _coincidencias.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF252538)),
                        itemBuilder: (context, i) {
                          final match = _coincidencias[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: Row(
                              children: [
                                // Ubicación
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF313244),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${match.sectionTitle} : L.${match.lineNumber}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF89B4FA)),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Fragmento contextual con resaltado
                                Expanded(
                                  child: RichText(
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: Color(0xFFA6ADC8),
                                      ),
                                      children: [
                                        TextSpan(text: match.previewBefore),
                                        TextSpan(
                                          text: match.matchText,
                                          style: const TextStyle(
                                            backgroundColor: Color(0xFFF9E2AF),
                                            color: Color(0xFF181825),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: match.previewAfter),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Botón reemplazar uno
                                IconButton(
                                  tooltip: 'Reemplazar esta coincidencia',
                                  icon: const Icon(Icons.check, size: 16, color: Color(0xFFA6E3A1)),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _reemplazarUno(match),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Botones inferiores
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar', style: TextStyle(color: Color(0xFFA6ADC8))),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync_alt, size: 16),
                  label: const Text('Reemplazar Todo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89B4FA),
                    foregroundColor: const Color(0xFF181825),
                  ),
                  onPressed: _coincidencias.isNotEmpty ? _reemplazarTodo : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
