import 'package:flutter/material.dart';
import '../../motor/secciones.dart';

class InspectorSeccion extends StatefulWidget {
  final SectionItem? section;
  final List<String> imagenesDisponibles;
  final ValueChanged<SectionItem> onActualizar;

  const InspectorSeccion({
    super.key,
    required this.section,
    required this.imagenesDisponibles,
    required this.onActualizar,
  });

  @override
  State<InspectorSeccion> createState() => _InspectorSeccionState();
}

class _InspectorSeccionState extends State<InspectorSeccion> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _fileNameController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initControllers();
  }

  @override
  void didUpdateWidget(InspectorSeccion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section?.id != oldWidget.section?.id) {
      _initControllers();
    }
  }

  void _initControllers() {
    final s = widget.section;
    _titleController = TextEditingController(text: s?.title ?? '');
    _subtitleController = TextEditingController(text: s?.subtitle ?? '');
    _fileNameController = TextEditingController(text: s?.fileName ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  int get _conteoPalabras {
    final s = widget.section;
    if (s == null || s.htmlContent.isEmpty) return 0;
    final sinHtml = s.htmlContent.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return sinHtml.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final sec = widget.section;
    if (sec == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 40, color: Color(0xFF585B70)),
            SizedBox(height: 12),
            Text(
              'Selecciona una sección en el panel izquierdo',
              style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Panel Superior: Editor de Encabezado y Metadatos de la Sección
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            border: Border(bottom: BorderSide(color: Color(0xFF313244))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Dropdown de Tipo
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<SectionKind>(
                      initialValue: sec.kind,
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4)),
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Sección',
                        labelStyle: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final k in SectionKind.values)
                          DropdownMenuItem(
                            value: k,
                            child: Text(k.label),
                          ),
                      ],
                      onChanged: (nuevoKind) {
                        if (nuevoKind != null) {
                          widget.onActualizar(sec.copyWith(
                            kind: nuevoKind,
                            matter: nuevoKind.matter,
                          ));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Título Visible
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4)),
                      decoration: const InputDecoration(
                        labelText: 'Título del Encabezado',
                        labelStyle: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        sec.title = v;
                        widget.onActualizar(sec);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Subtítulo
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _subtitleController,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4)),
                      decoration: const InputDecoration(
                        labelText: 'Subtítulo (Versalita)',
                        labelStyle: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        sec.subtitle = v;
                        widget.onActualizar(sec);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Archivo .xhtml
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _fileNameController,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4)),
                      decoration: const InputDecoration(
                        labelText: 'Archivo',
                        labelStyle: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        sec.fileName = v;
                        widget.onActualizar(sec);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Opciones Gráficas (Portada / Ilustración / Título Imagen)
              Row(
                children: [
                  if (sec.kind == SectionKind.cover || sec.kind == SectionKind.illustrations) ...[
                    const Icon(Icons.image_outlined, size: 16, color: Color(0xFFF9E2AF)),
                    const SizedBox(width: 6),
                    const Text('Imagen Asignada: ', style: TextStyle(fontSize: 11, color: Color(0xFFA6ADC8))),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: widget.imagenesDisponibles.contains(sec.associatedImage)
                            ? sec.associatedImage
                            : null,
                        hint: const Text('Elegir imagen', style: TextStyle(fontSize: 11, color: Color(0xFF6C7086))),
                        dropdownColor: const Color(0xFF1E1E2E),
                        style: const TextStyle(fontSize: 11, color: Color(0xFFCDD6F4)),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final img in widget.imagenesDisponibles)
                            DropdownMenuItem(value: img, child: Text(img)),
                        ],
                        onChanged: (img) {
                          widget.onActualizar(sec.copyWith(associatedImage: img));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],

                  if (sec.kind == SectionKind.chapter || sec.kind == SectionKind.interlude) ...[
                    FilterChip(
                      selected: sec.titleIsImage,
                      label: Text(
                        sec.titleIsImage
                            ? 'Título Imagen (../Images/${sec.titleImageNumber ?? "02"}.jpg)'
                            : 'Título en Texto',
                        style: TextStyle(
                          fontSize: 11,
                          color: sec.titleIsImage ? const Color(0xFF181825) : const Color(0xFFA6ADC8),
                        ),
                      ),
                      selectedColor: const Color(0xFFFAB387),
                      onSelected: (val) {
                        widget.onActualizar(sec.copyWith(
                          titleIsImage: val,
                          titleImageNumber: val ? (sec.titleImageNumber ?? '02') : null,
                        ));
                      },
                    ),
                    const SizedBox(width: 16),
                  ],

                  const Spacer(),
                  // Badge contador de palabras
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181825),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF313244)),
                    ),
                    child: Text(
                      '$_conteoPalabras palabras',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFA6ADC8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Barra de pestañas Visor
        Container(
          color: const Color(0xFF181825),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF89B4FA),
            unselectedLabelColor: const Color(0xFF6C7086),
            indicatorColor: const Color(0xFF89B4FA),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.code, size: 14),
                    SizedBox(width: 6),
                    Text('HTML Limpio', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.difference_outlined, size: 14),
                    SizedBox(width: 6),
                    Text('Comparador Diff', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Contenido de las pestañas
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Pestaña 1: HTML Limpio
              Container(
                color: const Color(0xFF181825),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SelectableText(
                    sec.htmlContent.isNotEmpty ? sec.htmlContent : '<p>Sección sin contenido de texto.</p>',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFCDD6F4),
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              // Pestaña 2: Comparador Diff
              _construirVistaDiff(sec),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirVistaDiff(SectionItem sec) {
    if (sec.htmlRaw.isEmpty || sec.htmlContent.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos previos para comparar diferencias.',
          style: TextStyle(color: Color(0xFF6C7086), fontSize: 12),
        ),
      );
    }

    final lineasRaw = sec.htmlRaw.split('\n');
    final lineasClean = sec.htmlContent.split('\n');

    return Container(
      color: const Color(0xFF181825),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: lineasClean.length,
        itemBuilder: (context, i) {
          final linea = lineasClean[i];
          final rawExiste = i < lineasRaw.length ? lineasRaw[i] : null;
          final fueModificada = rawExiste != null && rawExiste != linea;

          if (fueModificada) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: const Color(0xFFF38BA8).withValues(alpha: 0.15),
                  child: Text(
                    '- $rawExiste',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFF38BA8),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: const Color(0xFFA6E3A1).withValues(alpha: 0.15),
                  child: Text(
                    '+ $linea',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFA6E3A1),
                    ),
                  ),
                ),
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Text(
              '  $linea',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFF6C7086),
              ),
            ),
          );
        },
      ),
    );
  }
}
