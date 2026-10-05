import 'package:flutter/material.dart';
import '../../motor/secciones.dart';

class PanelSecciones extends StatelessWidget {
  final List<SectionItem> secciones;
  final SectionItem? seccionSeleccionada;
  final ValueChanged<SectionItem> onSeleccionar;
  final Function(int oldIndex, int newIndex) onReordenar;
  final ValueChanged<SectionItem> onActualizar;
  final Function(SectionKind kind) onAgregarSeccion;
  final ValueChanged<SectionItem> onEliminarSeccion;

  const PanelSecciones({
    super.key,
    required this.secciones,
    required this.seccionSeleccionada,
    required this.onSeleccionar,
    required this.onReordenar,
    required this.onActualizar,
    required this.onAgregarSeccion,
    required this.onEliminarSeccion,
  });

  Color _colorTipo(SectionKind kind) {
    switch (kind) {
      case SectionKind.cover:
      case SectionKind.illustrations:
      case SectionKind.backCover:
        return const Color(0xFFF9E2AF);
      case SectionKind.titlePage:
      case SectionKind.synopsis:
      case SectionKind.notice:
      case SectionKind.epigraph:
      case SectionKind.preface:
      case SectionKind.authorProfile:
        return const Color(0xFF89DCEB);
      case SectionKind.credits:
      case SectionKind.logos:
      case SectionKind.colophon:
        return const Color(0xFFA6ADC8);
      case SectionKind.tocVisual:
      case SectionKind.tocNav:
        return const Color(0xFF94E2D5);
      case SectionKind.prologue:
        return const Color(0xFFA6E3A1);
      case SectionKind.chapter:
        return const Color(0xFF89B4FA);
      case SectionKind.interlude:
        return const Color(0xFFFAB387);
      case SectionKind.part:
      case SectionKind.epilogue:
        return const Color(0xFFCBA6F7);
      case SectionKind.extra:
        return const Color(0xFFF5C2E7);
      case SectionKind.notes:
        return const Color(0xFFF38BA8);
      case SectionKind.author:
        return const Color(0xFFF9E2AF);
      case SectionKind.translator:
        return const Color(0xFF94E2D5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cabecera con contador y botón agregar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF181825),
            border: Border(bottom: BorderSide(color: Color(0xFF313244))),
          ),
          child: Row(
            children: [
              Text(
                'Secciones (${secciones.where((s) => s.enabled).length}/${secciones.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCDD6F4),
                ),
              ),
              const Spacer(),
              PopupMenuButton<SectionKind>(
                tooltip: 'Añadir nueva sección',
                icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF89B4FA)),
                color: const Color(0xFF1E1E2E),
                onSelected: onAgregarSeccion,
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('PRELIMINARES', style: TextStyle(fontSize: 10, color: Color(0xFF6C7086), fontWeight: FontWeight.bold)),
                  ),
                  _menuItem(SectionKind.cover),
                  _menuItem(SectionKind.synopsis),
                  _menuItem(SectionKind.illustrations),
                  _menuItem(SectionKind.authorProfile),
                  _menuItem(SectionKind.titlePage),
                  _menuItem(SectionKind.credits),
                  _menuItem(SectionKind.logos),
                  _menuItem(SectionKind.epigraph),
                  _menuItem(SectionKind.preface),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('CUERPO', style: TextStyle(fontSize: 10, color: Color(0xFF6C7086), fontWeight: FontWeight.bold)),
                  ),
                  _menuItem(SectionKind.prologue),
                  _menuItem(SectionKind.chapter),
                  _menuItem(SectionKind.interlude),
                  _menuItem(SectionKind.part),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('FINALES', style: TextStyle(fontSize: 10, color: Color(0xFF6C7086), fontWeight: FontWeight.bold)),
                  ),
                  _menuItem(SectionKind.epilogue),
                  _menuItem(SectionKind.extra),
                  _menuItem(SectionKind.author),
                  _menuItem(SectionKind.translator),
                  _menuItem(SectionKind.backCover),
                  _menuItem(SectionKind.notes),
                ],
              ),
            ],
          ),
        ),

        // Lista reordenable
        Expanded(
          child: secciones.isEmpty
              ? const Center(
                  child: Text(
                    'No hay secciones cargadas.',
                    style: TextStyle(color: Color(0xFF6C7086), fontSize: 13),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: secciones.length,
                  onReorderItem: onReordenar,
                  itemBuilder: (context, index) {
                    final sec = secciones[index];
                    final isSelected = seccionSeleccionada?.id == sec.id;
                    final colorTipo = _colorTipo(sec.kind);

                    return Material(
                      key: ValueKey(sec.id),
                      color: isSelected
                          ? const Color(0xFF313244)
                          : (sec.enabled ? Colors.transparent : const Color(0xFF181825).withValues(alpha: 0.5)),
                      child: InkWell(
                        onTap: () => onSeleccionar(sec),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFF252538), width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              // Drag Handle
                              ReorderableDragStartListener(
                                index: index,
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.drag_indicator, size: 16, color: Color(0xFF585B70)),
                                  ),
                                ),
                              ),

                              // Toggle Enabled
                              Checkbox(
                                value: sec.enabled,
                                activeColor: const Color(0xFF89B4FA),
                                checkColor: const Color(0xFF181825),
                                visualDensity: VisualDensity.compact,
                                onChanged: (v) {
                                  onActualizar(sec.copyWith(enabled: v ?? true));
                                },
                              ),

                              // Badge Tipo
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorTipo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: colorTipo.withValues(alpha: 0.5), width: 0.8),
                                ),
                                child: Text(
                                  sec.kind.label,
                                  style: TextStyle(
                                    color: colorTipo,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Título y Subtítulo
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sec.title.isNotEmpty ? sec.title : sec.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: sec.enabled
                                            ? (isSelected ? const Color(0xFF89B4FA) : const Color(0xFFCDD6F4))
                                            : const Color(0xFF6C7086),
                                        decoration: sec.enabled ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    if (sec.subtitle.isNotEmpty)
                                      Text(
                                        sec.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFA6ADC8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Botón Toggle TOC
                              IconButton(
                                tooltip: sec.inToc ? 'En el índice (TOC)' : 'Oculto del índice',
                                icon: Icon(
                                  sec.inToc ? Icons.menu_book : Icons.menu_book_outlined,
                                  size: 16,
                                  color: sec.inToc ? const Color(0xFFA6E3A1) : const Color(0xFF585B70),
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  onActualizar(sec.copyWith(inToc: !sec.inToc));
                                },
                              ),

                              // Botón Eliminar
                              IconButton(
                                tooltip: 'Eliminar sección',
                                icon: const Icon(Icons.close, size: 16, color: Color(0xFF6C7086)),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onEliminarSeccion(sec),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  PopupMenuItem<SectionKind> _menuItem(SectionKind kind) {
    return PopupMenuItem(
      value: kind,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _colorTipo(kind), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(kind.label, style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4))),
        ],
      ),
    );
  }
}
