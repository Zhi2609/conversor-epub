import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../motor/modelo.dart';
import '../motor/procesar.dart';
import '../motor/adaptadores.dart';
import '../motor/render.dart';
import '../motor/plantillas.dart';
import '../motor/empaquetado.dart';
import '../motor/ajustes.dart';
import '../motor/secciones.dart';
import '../motor/metadatos.dart';

import 'widgets/panel_secciones.dart';
import 'widgets/formulario_metadatos.dart';
import 'widgets/inspector_seccion.dart';
import 'widgets/dialogo_buscar_reemplazar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Resultado? _resultado;
  List<SectionItem> _secciones = [];
  BookMetadata _metadatos = const BookMetadata();
  SectionItem? _seccionSeleccionada;
  int _tabPanelIzquierdo = 0; // 0: Secciones, 1: Metadatos

  String _mensajeEstado = 'Sin archivo cargado';
  String? _rutaArchivoCargado;
  int _tamanoArchivo = 0;
  bool _isDragging = false;
  String? _mensajeError;

  final String _rutaBaseEpub = AjustesApp.obtenerRutaBaseEpub();
  String? _rutaCarpetaImagenes;
  final List<String> _imagenesDisponibles = [];

  final String rutaTemplateDefecto = '../assets/Conv_Xhtml/template.xhtml';
  final String rutaPlantillasDefecto = '../assets/Plantillas';

  @override
  void initState() {
    super.initState();
  }

  void _mostrarError(String msg) {
    setState(() {
      _mensajeError = msg;
    });
  }

  String _formatearTamano(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _cargarImagenesCarpeta(String rutaCarpeta) {
    _imagenesDisponibles.clear();
    final dir = Directory(rutaCarpeta);
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.svg'].contains(ext)) {
            _imagenesDisponibles.add(p.basename(entity.path));
          }
        }
      }
      _imagenesDisponibles.sort();
    }
  }

  Future<void> _seleccionarCarpetaImagenes() async {
    final ruta = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Elegir carpeta con ilustraciones');
    if (ruta != null) {
      setState(() {
        _rutaCarpetaImagenes = ruta;
        _cargarImagenesCarpeta(ruta);
        // Asignar portada por defecto si existe cover.jpg o 01.jpg
        final coverCandidate = _imagenesDisponibles.firstWhere(
          (img) => RegExp(r'^(?:cover|0?1)\.(?:jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(img),
          orElse: () => _imagenesDisponibles.isNotEmpty ? _imagenesDisponibles.first : '',
        );
        if (coverCandidate.isNotEmpty) {
          final coverSec = _secciones.where((s) => s.kind == SectionKind.cover).firstOrNull;
          if (coverSec != null) {
            coverSec.associatedImage = coverCandidate;
          }
        }
      });
    }
  }

  Future<void> _procesarArchivo(String ruta) async {
    setState(() {
      _mensajeEstado = '🔄 Procesando...';
      _mensajeError = null;
      _rutaArchivoCargado = ruta;
      try {
        _tamanoArchivo = File(ruta).existsSync() ? File(ruta).lengthSync() : 0;
      } catch (_) {
        _tamanoArchivo = 0;
      }
    });

    try {
      String modo = detectarModo(ruta);
      setState(() {
        _mensajeEstado = modo == 'pdf'
            ? '🔄 Convirtiendo páginas del PDF...'
            : '🔄 Procesando ($modo)...';
      });

      String? plantillas = Directory(rutaPlantillasDefecto).existsSync() ? rutaPlantillasDefecto : null;

      _resultado = await procesar(
        modo: modo,
        rutaEntrada: ruta,
        rutaTemplate: rutaTemplateDefecto,
        startNum: 1,
        rutaPlantillas: plantillas,
      );

      _metadatos = BookMetadata.fromFileName(ruta);

      // Portada sugerida si ya había carpeta de imágenes
      String? portadaSugerida;
      if (_imagenesDisponibles.isNotEmpty) {
        portadaSugerida = _imagenesDisponibles.firstWhere(
          (img) => RegExp(r'^(?:cover|0?1)\.(?:jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(img),
          orElse: () => _imagenesDisponibles.first,
        );
      }

      _secciones = convertirResultadoASecciones(
        _resultado!,
        portadaDefault: portadaSugerida,
      );

      _seccionSeleccionada = _secciones.firstWhere(
        (s) => s.kind == SectionKind.chapter || s.kind == SectionKind.prologue,
        orElse: () => _secciones.first,
      );

      _mensajeEstado = '✅ $modo — ${p.basename(ruta)}';
    } catch (e) {
      _mostrarError(e.toString());
      _mensajeEstado = '❌ Error';
      _resultado = null;
      _secciones = [];
    }
    setState(() {});
  }

  void _onReordenarSecciones(int oldIndex, int newIndex) {
    setState(() {
      final item = _secciones.removeAt(oldIndex);
      _secciones.insert(newIndex, item);
    });
  }

  void _onActualizarSeccion(SectionItem sec) {
    setState(() {
      final index = _secciones.indexWhere((s) => s.id == sec.id);
      if (index != -1) {
        _secciones[index] = sec;
      }
      if (_seccionSeleccionada?.id == sec.id) {
        _seccionSeleccionada = sec;
      }
    });
  }

  void _onAgregarSeccion(SectionKind kind) {
    setState(() {
      final nuevoId = 'sec_${DateTime.now().millisecondsSinceEpoch}';
      final item = SectionItem(
        id: nuevoId,
        kind: kind,
        matter: kind.matter,
        title: kind.label,
        fileName: kind.defaultFileName,
        inToc: true,
        enabled: true,
        htmlContent: '<p>Contenido de ${kind.label}...</p>',
      );
      _secciones.add(item);
      _seccionSeleccionada = item;
    });
  }

  void _onEliminarSeccion(SectionItem sec) {
    setState(() {
      _secciones.removeWhere((s) => s.id == sec.id);
      if (_seccionSeleccionada?.id == sec.id) {
        _seccionSeleccionada = _secciones.isNotEmpty ? _secciones.first : null;
      }
    });
  }

  void _abrirDialogoBuscarReemplazar() {
    showDialog(
      context: context,
      builder: (ctx) => DialogoBuscarReemplazar(
        secciones: _secciones,
        seccionActual: _seccionSeleccionada,
        onAplicarCambios: (nuevasSecciones) {
          setState(() {
            _secciones = nuevasSecciones;
            if (_seccionSeleccionada != null) {
              _seccionSeleccionada = _secciones.firstWhere(
                (s) => s.id == _seccionSeleccionada!.id,
                orElse: () => _secciones.first,
              );
            }
          });
        },
      ),
    );
  }

  Future<String> _cargarPlantilla({String? nombreEspecial, String? rutaDisco}) async {
    if (rutaDisco != null && File(rutaDisco).existsSync()) {
      return File(rutaDisco).readAsStringSync();
    }
    final assetPath = nombreEspecial != null
        ? 'assets/Plantillas/$nombreEspecial'
        : 'assets/Conv_Xhtml/template.xhtml';
    final discoPath = nombreEspecial != null
        ? p.join(rutaPlantillasDefecto, nombreEspecial)
        : rutaTemplateDefecto;
    final disco = File(discoPath);
    return disco.existsSync() ? disco.readAsStringSync() : await rootBundle.loadString(assetPath);
  }

  Future<List<ArchivoEpubEntrada>> _prepararArchivosXhtml() async {
    final plantilla = await _cargarPlantilla();
    final lista = <ArchivoEpubEntrada>[];

    final caps = seccionesACapitulos(_secciones);

    for (int i = 0; i < caps.length; i++) {
      var cap = caps[i];
      String titulo = cap.titulo;
      int num = i + 1;
      String archivo = cap.archivo ?? 'C${num.toString().padLeft(2, '0')}.xhtml';
      int numero = numeroDeArchivo(archivo, num);

      String htmlFinal;
      if (cap.plantillaNombre != null || cap.plantillaRuta != null) {
        String plantillaEspecial = await _cargarPlantilla(
          nombreEspecial: cap.plantillaNombre,
          rutaDisco: cap.plantillaRuta,
        );
        htmlFinal = renderCapituloEspecial(
          plantillaEspecial,
          titulo,
          numero,
          cap.htmlCuerpo,
          tituloEsImagen: cap.tituloEsImagen,
          numeroImagenTitulo: cap.numeroImagenTitulo,
        );
      } else {
        htmlFinal = renderCapitulo(
          plantilla,
          titulo,
          numero,
          cap.htmlCuerpo,
          tituloEsImagen: cap.tituloEsImagen,
          numeroImagenTitulo: cap.numeroImagenTitulo,
        );
      }

      lista.add(ArchivoEpubEntrada(nombre: archivo, contenidoHtml: htmlFinal));
    }

    final titulos = caps.map((c) => c.titulo).toList();
    final tocHtml = renderTablaContenidos(caps, titulos);
    lista.add(ArchivoEpubEntrada(nombre: 'contenido-2.xhtml', contenidoHtml: tocHtml));

    return lista;
  }

  Future<void> _generarSoloXhtml() async {
    String? salida = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Elige la carpeta de salida para los XHTML');
    if (salida == null) return;

    try {
      limpiarCarpeta(salida);
      final archivos = await _prepararArchivosXhtml();

      for (final arch in archivos) {
        File(p.join(salida, arch.nombre)).writeAsStringSync(arch.contenidoHtml);
      }

      if (_resultado?.notas.isNotEmpty == true) {
        String plantillaNotas = await _cargarPlantilla(nombreEspecial: 'notas.xhtml');
        File(p.join(salida, 'notas.xhtml')).writeAsStringSync(renderArchivoNotas(plantillaNotas, _resultado!.notas));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Archivos XHTML generados en $salida')));
    } catch (e) {
      _mostrarError('Error al generar XHTML: $e');
    }
  }

  Future<void> _compilarEpub() async {
    final nombreBase = _metadatos.displayTitle.isNotEmpty
        ? '${_metadatos.displayTitle}.epub'
        : (_rutaArchivoCargado != null
            ? '${p.basenameWithoutExtension(_rutaArchivoCargado!)}.epub'
            : 'Novela.epub');

    String? destino = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar ePub compilado',
      fileName: nombreBase,
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );
    if (destino == null) return;
    if (!destino.toLowerCase().endsWith('.epub')) {
      destino = '$destino.epub';
    }

    try {
      final archivosXhtml = await _prepararArchivosXhtml();

      Uint8List bytesBase;
      if (_rutaBaseEpub.isNotEmpty && File(_rutaBaseEpub).existsSync()) {
        bytesBase = File(_rutaBaseEpub).readAsBytesSync();
      } else {
        final byteData = await rootBundle.load('assets/Base3_v1.15.0.epub');
        bytesBase = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      }

      final imagenes = <EntradaImagenEpub>[];
      if (_rutaCarpetaImagenes != null && Directory(_rutaCarpetaImagenes!).existsSync()) {
        for (final entity in Directory(_rutaCarpetaImagenes!).listSync()) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.svg'].contains(ext)) {
              imagenes.add(EntradaImagenEpub(
                nombreArchivo: p.basename(entity.path),
                bytes: entity.readAsBytesSync(),
              ));
            }
          }
        }
      }

      final coverSec = _secciones.where((s) => s.kind == SectionKind.cover).firstOrNull;
      final coverPath = coverSec?.associatedImage;
      if (coverPath != null && File(coverPath).existsSync()) {
        final bytesCover = File(coverPath).readAsBytesSync();
        imagenes.add(EntradaImagenEpub(
          nombreArchivo: 'cover.jpg',
          bytes: bytesCover,
        ));
      }

      final ordenSpine = _secciones.where((s) => s.enabled).map((s) => s.fileName).toList();
      final entradasToc = [
        for (final s in _secciones.where((s) => s.enabled && s.inToc))
          (archivo: s.fileName, titulo: s.effectiveHeading)
      ];

      final secNotas = _secciones.where((s) => s.kind == SectionKind.notes && s.enabled).firstOrNull;
      final contenidoNotas = secNotas?.htmlContent ?? (_resultado?.notas.isNotEmpty == true ? renderNotas(_resultado!.notas) : null);

      final res = empaquetarEpub(
        bytesBaseEpub: bytesBase,
        capitulosYEspeciales: archivosXhtml,
        ordenSpine: ordenSpine,
        entradasToc: entradasToc,
        contenidoNotas: contenidoNotas,
        imagenes: imagenes,
        metadatos: _metadatos,
        secciones: _secciones,
      );

      File(destino).writeAsBytesSync(res.bytesEpub);

      if (!mounted) return;

      if (res.avisos.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('ePub Compilado con Avisos', style: TextStyle(color: Color(0xFFF9E2AF))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Archivo guardado en:\n$destino\n', style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
                  const Text('Avisos detectados:', style: TextStyle(color: Color(0xFFF38BA8), fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...res.avisos.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $a', style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 11)),
                  )),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFA6E3A1),
            content: Text(
              '🎉 ePub guardado con éxito en: $destino',
              style: const TextStyle(color: Color(0xFF181825), fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al compilar ePub: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11111B),
      appBar: _construirAppBar(),
      body: _resultado == null ? _construirVistaDropzone() : _construirWorkstation(),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF181825),
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_stories, color: Color(0xFF89B4FA), size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Conversor ePub',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFCDD6F4)),
          ),
          if (_rutaArchivoCargado != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF313244),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: Color(0xFFA6ADC8)),
                  const SizedBox(width: 6),
                  Text(
                    p.basename(_rutaArchivoCargado!),
                    style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4)),
                  ),
                  if (_tamanoArchivo > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${_formatearTamano(_tamanoArchivo)})',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFA6ADC8)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_resultado != null) ...[
          // Botón selector de carpeta de imágenes
          TextButton.icon(
            icon: Icon(
              Icons.photo_library_outlined,
              size: 16,
              color: _rutaCarpetaImagenes != null ? const Color(0xFFA6E3A1) : const Color(0xFFA6ADC8),
            ),
            label: Text(
              _rutaCarpetaImagenes != null
                  ? '${p.basename(_rutaCarpetaImagenes!)} (${_imagenesDisponibles.length})'
                  : 'Imágenes',
              style: TextStyle(
                fontSize: 12,
                color: _rutaCarpetaImagenes != null ? const Color(0xFFA6E3A1) : const Color(0xFFA6ADC8),
              ),
            ),
            onPressed: _seleccionarCarpetaImagenes,
          ),
          const SizedBox(width: 6),

          // Botón Buscar y Reemplazar
          TextButton.icon(
            icon: const Icon(Icons.find_replace, size: 16, color: Color(0xFF89B4FA)),
            label: const Text('Regex Buscar/Reemplazar', style: TextStyle(fontSize: 12, color: Color(0xFF89B4FA))),
            onPressed: _abrirDialogoBuscarReemplazar,
          ),
          const SizedBox(width: 6),

          // Menú Exportar Solo XHTML
          PopupMenuButton<String>(
            tooltip: 'Opciones de exportación',
            icon: const Icon(Icons.more_vert, color: Color(0xFFA6ADC8)),
            color: const Color(0xFF1E1E2E),
            onSelected: (val) {
              if (val == 'xhtml') _generarSoloXhtml();
              if (val == 'nuevo') setState(() => _resultado = null);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'xhtml',
                child: Row(
                  children: [
                    Icon(Icons.folder_zip_outlined, size: 16, color: Color(0xFF89B4FA)),
                    SizedBox(width: 8),
                    Text('Exportar solo XHTMLs', style: TextStyle(fontSize: 12, color: Color(0xFFCDD6F4))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'nuevo',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 16, color: Color(0xFFF38BA8)),
                    SizedBox(width: 8),
                    Text('Cargar otro manuscrito', style: TextStyle(fontSize: 12, color: Color(0xFFF38BA8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Botón Compilar EPUB Destacado
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Compilar EPUB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: const Color(0xFF11111B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _compilarEpub,
            ),
          ),
        ],
      ],
    );
  }

  Widget _construirVistaDropzone() {
    return Center(
      child: Container(
        width: 620,
        height: 380,
        margin: const EdgeInsets.all(24),
        child: DropTarget(
          onDragEntered: (details) => setState(() => _isDragging = true),
          onDragExited: (details) => setState(() => _isDragging = false),
          onDragDone: (details) {
            if (details.files.isNotEmpty) {
              _procesarArchivo(details.files.first.path);
            }
          },
          child: InkWell(
            onTap: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                type: FileType.custom,
                allowedExtensions: ['docx', 'md', 'markdown', 'pdf', 'txt'],
              );
              if (result != null && result.files.single.path != null) {
                _procesarArchivo(result.files.single.path!);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: DashedRectPainter(
                color: _isDragging ? const Color(0xFF89B4FA) : const Color(0xFF45475A),
                strokeWidth: _isDragging ? 2.5 : 1.5,
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _isDragging
                      ? const Color(0xFF1E1E2E)
                      : const Color(0xFF181825).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF89B4FA).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        size: 56,
                        color: Color(0xFF89B4FA),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Arrastra tu novela aquí',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCDD6F4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Soporta archivos .docx, .md, .pdf o haz clic para explorar',
                      style: TextStyle(fontSize: 13, color: Color(0xFFA6ADC8)),
                    ),
                    const SizedBox(height: 16),
                    if (_mensajeError != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF38BA8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _mensajeError!,
                          style: const TextStyle(color: Color(0xFFF38BA8), fontSize: 12),
                        ),
                      )
                    else if (_mensajeEstado != 'Sin archivo cargado')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _mensajeEstado,
                          style: const TextStyle(color: Color(0xFF89B4FA), fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirWorkstation() {
    return Row(
      children: [
        // Columna Izquierda: Panel de Secciones y Metadatos (390px)
        Container(
          width: 390,
          decoration: const BoxDecoration(
            color: Color(0xFF181825),
            border: Border(right: BorderSide(color: Color(0xFF313244))),
          ),
          child: Column(
            children: [
              // Selector de Pestañas Izquierda (Secciones / Metadatos)
              Container(
                padding: const EdgeInsets.all(6),
                color: const Color(0xFF11111B),
                child: Row(
                  children: [
                    Expanded(
                      child: _tabBoton(
                        titulo: 'Secciones (${_secciones.length})',
                        icono: Icons.list_alt,
                        activo: _tabPanelIzquierdo == 0,
                        onTap: () => setState(() => _tabPanelIzquierdo = 0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _tabBoton(
                        titulo: 'Metadatos',
                        icono: Icons.menu_book,
                        activo: _tabPanelIzquierdo == 1,
                        onTap: () => setState(() => _tabPanelIzquierdo = 1),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido según pestaña
              Expanded(
                child: _tabPanelIzquierdo == 0
                    ? PanelSecciones(
                        secciones: _secciones,
                        seccionSeleccionada: _seccionSeleccionada,
                        onSeleccionar: (sec) => setState(() => _seccionSeleccionada = sec),
                        onReordenar: _onReordenarSecciones,
                        onActualizar: _onActualizarSeccion,
                        onAgregarSeccion: _onAgregarSeccion,
                        onEliminarSeccion: _onEliminarSeccion,
                      )
                    : FormularioMetadatos(
                        metadatos: _metadatos,
                        onChanged: (nuevos) => setState(() => _metadatos = nuevos),
                      ),
              ),
            ],
          ),
        ),

        // Columna Derecha: Inspector de Sección y Visor (Expanded)
        Expanded(
          child: InspectorSeccion(
            section: _seccionSeleccionada,
            imagenesDisponibles: _imagenesDisponibles,
            onActualizar: _onActualizarSeccion,
          ),
        ),
      ],
    );
  }

  Widget _tabBoton({
    required String titulo,
    required IconData icono,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF1E1E2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: activo ? const Color(0xFF89B4FA) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 14, color: activo ? const Color(0xFF89B4FA) : const Color(0xFFA6ADC8)),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                color: activo ? const Color(0xFFCDD6F4) : const Color(0xFFA6ADC8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    this.color = const Color(0xFF585B70),
    this.strokeWidth = 1.5,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ));
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + gap > metric.length) ? metric.length - distance : gap;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth || oldDelegate.gap != gap;
}
