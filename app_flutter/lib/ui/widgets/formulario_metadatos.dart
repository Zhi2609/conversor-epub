import 'package:flutter/material.dart';
import '../../motor/metadatos.dart';

class FormularioMetadatos extends StatelessWidget {
  final BookMetadata metadatos;
  final ValueChanged<BookMetadata> onChanged;

  const FormularioMetadatos({
    super.key,
    required this.metadatos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _seccionHeader(context, 'Título y Colección', Icons.book_outlined),
        const SizedBox(height: 10),
        _campoTexto(
          label: 'Título Principal',
          value: metadatos.title,
          hint: 'Ej: Nombre de la Novela',
          icon: Icons.title,
          onChanged: (v) => onChanged(metadatos.copyWith(title: v)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _campoTexto(
                label: 'Serie / Colección',
                value: metadatos.series,
                hint: 'Ej: Novela Ligera',
                icon: Icons.collections_bookmark_outlined,
                onChanged: (v) => onChanged(metadatos.copyWith(series: v)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: _campoTexto(
                label: 'Volumen',
                value: metadatos.volume,
                hint: '01',
                icon: Icons.tag,
                onChanged: (v) => onChanged(metadatos.copyWith(volume: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _seccionHeader(context, 'Créditos y Personas', Icons.people_outline),
        const SizedBox(height: 10),
        _campoTexto(
          label: 'Autor(a)',
          value: metadatos.author,
          hint: 'Nombre del autor original',
          icon: Icons.edit_outlined,
          onChanged: (v) => onChanged(metadatos.copyWith(author: v)),
        ),
        const SizedBox(height: 10),
        _campoTexto(
          label: 'Traductor(a) / Grupo',
          value: metadatos.translator,
          hint: 'Grupo o traductor(a)',
          icon: Icons.translate_outlined,
          onChanged: (v) => onChanged(metadatos.copyWith(translator: v)),
        ),
        const SizedBox(height: 10),
        _campoTexto(
          label: 'Ilustrador(a)',
          value: metadatos.illustrator,
          hint: 'Artista de las ilustraciones',
          icon: Icons.brush_outlined,
          onChanged: (v) => onChanged(metadatos.copyWith(illustrator: v)),
        ),
        const SizedBox(height: 20),
        _seccionHeader(context, 'Sinopsis del Libro', Icons.description_outlined),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: metadatos.synopsis,
          maxLines: 5,
          style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4)),
          decoration: InputDecoration(
            labelText: 'Sinopsis / Resumen',
            labelStyle: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
            hintText: 'Escribe o pega aquí la sinopsis...',
            hintStyle: const TextStyle(color: Color(0xFF585B70), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF181825),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF313244)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF313244)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF89B4FA), width: 1.5),
            ),
          ),
          onChanged: (v) => onChanged(metadatos.copyWith(synopsis: v)),
        ),
        const SizedBox(height: 20),
        _seccionHeader(context, 'Identificador Único (BookId)', Icons.fingerprint),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF181825),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF313244)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  metadatos.bookId.isNotEmpty ? metadatos.bookId : 'Sin ID generado',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFA6E3A1),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Regenerar UUID v7',
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF89B4FA)),
                onPressed: () => onChanged(metadatos.copyWith(bookId: uuidV7())),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionHeader(BuildContext context, String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 16, color: const Color(0xFF89B4FA)),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFFCDD6F4),
          ),
        ),
      ],
    );
  }

  Widget _campoTexto({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF585B70), fontSize: 12),
        prefixIcon: Icon(icon, size: 16, color: const Color(0xFF89B4FA)),
        filled: true,
        fillColor: const Color(0xFF181825),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF313244)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF313244)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF89B4FA), width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
