import 'package:flutter/material.dart';
import '../../motor/metadatos.dart';

class FormularioMetadatos extends StatefulWidget {
  final BookMetadata metadatos;
  final ValueChanged<BookMetadata> onChanged;

  const FormularioMetadatos({
    super.key,
    required this.metadatos,
    required this.onChanged,
  });

  @override
  State<FormularioMetadatos> createState() => _FormularioMetadatosState();
}

class _FormularioMetadatosState extends State<FormularioMetadatos> {
  late TextEditingController _titleCtrl;
  late TextEditingController _seriesCtrl;
  late TextEditingController _volumeCtrl;
  late TextEditingController _groupTagCtrl;

  late TextEditingController _authorCtrl;
  late TextEditingController _authorJpCtrl;
  late TextEditingController _authorFileAsCtrl;

  late TextEditingController _illustratorCtrl;
  late TextEditingController _illustratorJpCtrl;
  late TextEditingController _illustratorFileAsCtrl;

  late TextEditingController _translatorCtrl;
  late TextEditingController _proofreaderCtrl;
  late TextEditingController _publisherCtrl;
  late TextEditingController _projectUrlCtrl;

  late TextEditingController _synopsisCtrl;
  late TextEditingController _isbn13Ctrl;
  late TextEditingController _isbn10Ctrl;
  late TextEditingController _amazonIdCtrl;

  final TextEditingController _customSubjectCtrl = TextEditingController();

  String _currentBookId = '';

  static const List<String> _demografiasEdad = [
    'Maduro',
    'Juvenil',
  ];

  static const List<String> _demografiasAudiencia = [
    'Adultas/Josei',
    'Adultos/Seinen',
    'Chicas/Shoujo',
    'Chicos/Shounen',
  ];

  static const List<String> _generosSugeridos = [
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

  static const List<String> _tiposLibro = [
    'Novela Ligera',
    'Web Novel',
    'Novela Corta',
    'Novela Visual',
    'Ficción',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.metadatos.bookId;
    _initControllers(widget.metadatos);
  }

  void _initControllers(BookMetadata m) {
    _titleCtrl = TextEditingController(text: m.title);
    _seriesCtrl = TextEditingController(text: m.series);
    _volumeCtrl = TextEditingController(text: m.volume);
    _groupTagCtrl = TextEditingController(text: m.groupTag);

    _authorCtrl = TextEditingController(text: m.author);
    _authorJpCtrl = TextEditingController(text: m.authorJapanese);
    _authorFileAsCtrl = TextEditingController(text: m.authorFileAs);

    _illustratorCtrl = TextEditingController(text: m.illustrator);
    _illustratorJpCtrl = TextEditingController(text: m.illustratorJapanese);
    _illustratorFileAsCtrl = TextEditingController(text: m.illustratorFileAs);

    _translatorCtrl = TextEditingController(text: m.translator);
    _proofreaderCtrl = TextEditingController(text: m.proofreader);
    _publisherCtrl = TextEditingController(text: m.publisher);
    _projectUrlCtrl = TextEditingController(text: m.projectUrl);

    _synopsisCtrl = TextEditingController(text: m.synopsis);
    _isbn13Ctrl = TextEditingController(text: m.isbn13);
    _isbn10Ctrl = TextEditingController(text: m.isbn10);
    _amazonIdCtrl = TextEditingController(text: m.amazonId);
  }

  @override
  void didUpdateWidget(covariant FormularioMetadatos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metadatos.bookId != _currentBookId) {
      _currentBookId = widget.metadatos.bookId;
      _disposeControllers();
      _initControllers(widget.metadatos);
    }
  }

  void _disposeControllers() {
    _titleCtrl.dispose();
    _seriesCtrl.dispose();
    _volumeCtrl.dispose();
    _groupTagCtrl.dispose();

    _authorCtrl.dispose();
    _authorJpCtrl.dispose();
    _authorFileAsCtrl.dispose();

    _illustratorCtrl.dispose();
    _illustratorJpCtrl.dispose();
    _illustratorFileAsCtrl.dispose();

    _translatorCtrl.dispose();
    _proofreaderCtrl.dispose();
    _publisherCtrl.dispose();
    _projectUrlCtrl.dispose();

    _synopsisCtrl.dispose();
    _isbn13Ctrl.dispose();
    _isbn10Ctrl.dispose();
    _amazonIdCtrl.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    _customSubjectCtrl.dispose();
    super.dispose();
  }

  String _autoInvertirNombre(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.length >= 2) {
      final apellido = partes.last;
      final resto = partes.sublist(0, partes.length - 1).join(' ');
      return '$apellido, $resto';
    }
    return nombre.trim();
  }

  void _actualizar(BookMetadata m) {
    widget.onChanged(m);
  }

  void _seleccionarDemografiaEdad(String demo) {
    final list = List<String>.from(widget.metadatos.subjects);
    if (list.contains(demo)) {
      list.remove(demo);
    } else {
      list.removeWhere((s) => _demografiasEdad.contains(s));
      list.add(demo);
    }
    _actualizar(widget.metadatos.copyWith(subjects: list));
  }

  void _seleccionarDemografiaAudiencia(String demo) {
    final list = List<String>.from(widget.metadatos.subjects);
    if (list.contains(demo)) {
      list.remove(demo);
    } else {
      list.removeWhere((s) => _demografiasAudiencia.contains(s));
      list.add(demo);
    }
    _actualizar(widget.metadatos.copyWith(subjects: list));
  }

  void _toggleSubject(String s) {
    final list = List<String>.from(widget.metadatos.subjects);
    if (list.contains(s)) {
      list.remove(s);
    } else {
      list.add(s);
    }
    _actualizar(widget.metadatos.copyWith(subjects: list));
  }

  void _agregarCustomSubject() {
    final val = _customSubjectCtrl.text.trim();
    if (val.isNotEmpty && !widget.metadatos.subjects.contains(val)) {
      final list = List<String>.from(widget.metadatos.subjects)..add(val);
      _actualizar(widget.metadatos.copyWith(subjects: list));
      _customSubjectCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.metadatos;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Banner informativo canónico
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF313244)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, size: 20, color: Color(0xFF89B4FA)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Metadatos Editoriales OPF (Estándar Base3)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFCDD6F4)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Título final: "${meta.effectiveTitle}" • Rating Calibre: ${BookMetadata.calibreRating} (Fijo) • Sello: ${BookMetadata.defaultDistributor} (Fijo)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFA6ADC8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Tarjeta 1: Título, Saga y Volumen
        _tarjetaContenedor(
          titulo: 'Título, Saga y Volumen',
          icono: Icons.book_outlined,
          colorAcento: const Color(0xFF89B4FA),
          children: [
            _campoTexto(
              controller: _titleCtrl,
              label: 'Título Principal',
              hint: 'Ej: Nombre de la Novela',
              icon: Icons.title,
              onChanged: (v) => _actualizar(meta.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _campoTexto(
                    controller: _seriesCtrl,
                    label: 'Saga / Nombre de la Novela (calibre:series)',
                    hint: 'Ej: Overlord [NL]',
                    icon: Icons.collections_bookmark_outlined,
                    onChanged: (v) => _actualizar(meta.copyWith(series: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _campoTexto(
                    controller: _volumeCtrl,
                    label: 'Volumen',
                    hint: '01',
                    icon: Icons.tag,
                    onChanged: (v) => _actualizar(meta.copyWith(volume: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _groupTagCtrl,
                    label: 'Siglas Grupo',
                    hint: 'Ej: SIGLAS-GRUPO',
                    icon: Icons.label_outline,
                    onChanged: (v) => _actualizar(meta.copyWith(groupTag: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Tarjeta 2: Creadores (Autores e Ilustradores con Kanji y file-as)
        _tarjetaContenedor(
          titulo: 'Autores e Ilustradores (Bilingüe / Kanji)',
          icono: Icons.people_outline,
          colorAcento: const Color(0xFFA6E3A1),
          children: [
            // Autor
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _authorCtrl,
                    label: 'Autor(a) (Alfabeto Latino)',
                    hint: 'Ej: Aneko Yusagi',
                    icon: Icons.edit_outlined,
                    onChanged: (v) => _actualizar(meta.copyWith(author: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _authorJpCtrl,
                    label: 'Autor en Kanji / Japonés (alternate-script)',
                    hint: 'Ej: アネコ ユサギ',
                    icon: Icons.translate,
                    onChanged: (v) => _actualizar(meta.copyWith(authorJapanese: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _authorFileAsCtrl,
                    label: 'Indexación Autor (file-as)',
                    hint: 'Ej: Yusagi, Aneko',
                    icon: Icons.sort_by_alpha,
                    onChanged: (v) => _actualizar(meta.copyWith(authorFileAs: v)),
                    suffixWidget: IconButton(
                      tooltip: 'Invertir formato (Apellido, Nombre)',
                      icon: const Icon(Icons.auto_fix_high, size: 16, color: Color(0xFF89B4FA)),
                      onPressed: () {
                        final auto = _autoInvertirNombre(_authorCtrl.text);
                        _authorFileAsCtrl.text = auto;
                        _actualizar(meta.copyWith(authorFileAs: auto));
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Ilustrador
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _illustratorCtrl,
                    label: 'Ilustrador(a) (Alfabeto Latino)',
                    hint: 'Ej: Minami Seira',
                    icon: Icons.brush_outlined,
                    onChanged: (v) => _actualizar(meta.copyWith(illustrator: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _illustratorJpCtrl,
                    label: 'Ilustrador en Kanji / Japonés',
                    hint: 'Ej: 弥南 せいら',
                    icon: Icons.translate,
                    onChanged: (v) => _actualizar(meta.copyWith(illustratorJapanese: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _illustratorFileAsCtrl,
                    label: 'Indexación Ilustrador (file-as)',
                    hint: 'Ej: Seira, Minami',
                    icon: Icons.sort_by_alpha,
                    onChanged: (v) => _actualizar(meta.copyWith(illustratorFileAs: v)),
                    suffixWidget: IconButton(
                      tooltip: 'Invertir formato (Apellido, Nombre)',
                      icon: const Icon(Icons.auto_fix_high, size: 16, color: Color(0xFF89B4FA)),
                      onPressed: () {
                        final auto = _autoInvertirNombre(_illustratorCtrl.text);
                        _illustratorFileAsCtrl.text = auto;
                        _actualizar(meta.copyWith(illustratorFileAs: auto));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Tarjeta 3: Equipo y Publicación
        _tarjetaContenedor(
          titulo: 'Equipo Editorial y Publicación',
          icono: Icons.groups_outlined,
          colorAcento: const Color(0xFFF9E2AF),
          children: [
            Row(
              children: [
                Expanded(
                  child: _campoTexto(
                    controller: _translatorCtrl,
                    label: 'Traductor(a) (Rol trl)',
                    hint: 'Ej: Traductor Apellido',
                    icon: Icons.record_voice_over_outlined,
                    onChanged: (v) => _actualizar(meta.copyWith(translator: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campoTexto(
                    controller: _proofreaderCtrl,
                    label: 'Corrector / Formateador (Rol mrk)',
                    hint: 'Por defecto: Zhi',
                    icon: Icons.rate_review_outlined,
                    onChanged: (v) => _actualizar(meta.copyWith(proofreader: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _campoTexto(
                    controller: _publisherCtrl,
                    label: 'Editorial / Grupo Traductor (dc:publisher)',
                    hint: 'Ej: Grupo Traductor',
                    icon: Icons.business_outlined,
                    onChanged: (v) => _actualizar(meta.copyWith(publisher: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campoTexto(
                    controller: _projectUrlCtrl,
                    label: 'Página Web / Enlace Oficial (uri-id)',
                    hint: 'https://...',
                    icon: Icons.link,
                    onChanged: (v) => _actualizar(meta.copyWith(projectUrl: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Tarjeta 4: Clasificación y Taxonomía (dc:type, dc:subject)
        _tarjetaContenedor(
          titulo: 'Clasificación y Taxonomía',
          icono: Icons.category_outlined,
          colorAcento: const Color(0xFFCBA6F7),
          children: [
            Row(
              children: [
                // Selector de tipo de obra (dc:type)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de Obra (dc:type)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFA6ADC8)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181825),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF313244)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _tiposLibro.contains(meta.bookType) ? meta.bookType : _tiposLibro.first,
                            dropdownColor: const Color(0xFF1E1E2E),
                            isExpanded: true,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4)),
                            items: _tiposLibro.map((tipo) {
                              return DropdownMenuItem(
                                value: tipo,
                                child: Text(tipo),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _actualizar(meta.copyWith(bookType: val));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Campo para añadir etiqueta/género personalizado
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Añadir Demografía o Género Personalizado',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFA6ADC8)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customSubjectCtrl,
                              style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4)),
                              decoration: InputDecoration(
                                hintText: 'Escribe un género y pulsa Enter o "+"...',
                                hintStyle: const TextStyle(color: Color(0xFF585B70), fontSize: 12),
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
                                  borderSide: const BorderSide(color: Color(0xFFCBA6F7), width: 1.5),
                                ),
                              ),
                              onSubmitted: (_) => _agregarCustomSubject(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCBA6F7),
                              foregroundColor: const Color(0xFF11111B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onPressed: _agregarCustomSubject,
                            child: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Demografías canónicas de ZeePubs (Edad + Audiencia)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF181825),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF89B4FA)),
                      const SizedBox(width: 8),
                      const Text(
                        'Demografías en ZeePubs',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCDD6F4)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Siempre dos: Edad + Audiencia',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF89B4FA)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Grupo 1: Edad / Madurez
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 130,
                        child: Text(
                          '• Edad / Madurez:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA6ADC8)),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: _demografiasEdad.map((demo) {
                          final activa = meta.subjects.contains(demo);
                          return FilterChip(
                            label: Text(demo),
                            selected: activa,
                            onSelected: (_) => _seleccionarDemografiaEdad(demo),
                            selectedColor: const Color(0xFF89B4FA).withValues(alpha: 0.25),
                            checkmarkColor: const Color(0xFF89B4FA),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: activa ? const Color(0xFF89B4FA) : const Color(0xFFCDD6F4),
                              fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: const Color(0xFF1E1E2E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: activa ? const Color(0xFF89B4FA) : const Color(0xFF45475A),
                                width: activa ? 1.5 : 1,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Grupo 2: Audiencia / Público
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 130,
                        child: Text(
                          '• Audiencia / Público:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA6ADC8)),
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _demografiasAudiencia.map((demo) {
                            final activa = meta.subjects.contains(demo);
                            return FilterChip(
                              label: Text(demo),
                              selected: activa,
                              onSelected: (_) => _seleccionarDemografiaAudiencia(demo),
                              selectedColor: const Color(0xFFA6E3A1).withValues(alpha: 0.25),
                              checkmarkColor: const Color(0xFFA6E3A1),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: activa ? const Color(0xFFA6E3A1) : const Color(0xFFCDD6F4),
                                fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                              ),
                              backgroundColor: const Color(0xFF1E1E2E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: activa ? const Color(0xFFA6E3A1) : const Color(0xFF45475A),
                                  width: activa ? 1.5 : 1,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Chips de géneros en ZeePubs
            Row(
              children: [
                const Icon(Icons.style_outlined, size: 16, color: Color(0xFFCBA6F7)),
                const SizedBox(width: 8),
                const Text(
                  'Géneros en ZeePubs (20 canónicos):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFA6ADC8)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _generosSugeridos.map((gen) {
                final activo = meta.subjects.contains(gen);
                return FilterChip(
                  label: Text(gen),
                  selected: activo,
                  onSelected: (_) => _toggleSubject(gen),
                  selectedColor: const Color(0xFFCBA6F7).withValues(alpha: 0.25),
                  checkmarkColor: const Color(0xFFCBA6F7),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: activo ? const Color(0xFFCBA6F7) : const Color(0xFFCDD6F4),
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: const Color(0xFF181825),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: activo ? const Color(0xFFCBA6F7) : const Color(0xFF313244),
                      width: activo ? 1.5 : 1,
                    ),
                  ),
                );
              }).toList(),
            ),

            if (meta.subjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF313244)),
              const SizedBox(height: 6),
              const Text(
                'Etiquetas activas para el ePub (dc:subject):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA6E3A1)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: meta.subjects.map((sub) {
                  return Chip(
                    label: Text(sub),
                    labelStyle: const TextStyle(fontSize: 11, color: Color(0xFFCDD6F4)),
                    backgroundColor: const Color(0xFF313244),
                    deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFFF38BA8)),
                    onDeleted: () => _toggleSubject(sub),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),

        // Tarjeta 5: Sinopsis e Identificadores (UUID, ISBN, Amazon)
        _tarjetaContenedor(
          titulo: 'Sinopsis e Identificadores Externos',
          icono: Icons.fingerprint,
          colorAcento: const Color(0xFFF38BA8),
          children: [
            const Text(
              'Sinopsis / Resumen (Alimenta sinopsis.xhtml y dc:description en OPF)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFA6ADC8)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _synopsisCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4)),
              decoration: InputDecoration(
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
                  borderSide: const BorderSide(color: Color(0xFFF38BA8), width: 1.5),
                ),
              ),
              onChanged: (v) => _actualizar(meta.copyWith(synopsis: v)),
            ),
            const SizedBox(height: 14),

            // BookId UUID v7 e identificadores
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BookId (UUID v7 RFC 9562)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFA6ADC8)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181825),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF313244)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                meta.bookId.isNotEmpty ? meta.bookId : 'Sin ID',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFA6E3A1)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Regenerar UUID v7',
                              icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF89B4FA)),
                              onPressed: () {
                                final nuevoId = uuidV7();
                                _actualizar(meta.copyWith(bookId: nuevoId));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _isbn10Ctrl,
                    label: 'ISBN-10 (Opcional)',
                    hint: 'Ej: 4840134086',
                    icon: Icons.qr_code,
                    onChanged: (v) => _actualizar(meta.copyWith(isbn10: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _isbn13Ctrl,
                    label: 'ISBN-13 (Opcional)',
                    hint: 'Ej: 978-40-6528-058-4',
                    icon: Icons.qr_code,
                    onChanged: (v) => _actualizar(meta.copyWith(isbn13: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _campoTexto(
                    controller: _amazonIdCtrl,
                    label: 'Amazon ASIN (Opcional)',
                    hint: 'Ej: B0B214451Y',
                    icon: Icons.shopping_bag_outlined,
                    onChanged: (v) => _actualizar(meta.copyWith(amazonId: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _tarjetaContenedor({
    required String titulo,
    required IconData icono,
    required Color colorAcento,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: colorAcento),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorAcento,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    Widget? suffixWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFA6ADC8)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF585B70), fontSize: 12),
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF89B4FA)),
            suffixIcon: suffixWidget,
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
        ),
      ],
    );
  }
}
