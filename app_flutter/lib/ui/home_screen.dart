import 'dart:io';
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
import '../motor/notas.dart';
import '../motor/imagenes.dart' show extraerPrimeraImagen;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Resultado? _resultado;
  int _startNumActual = 1;
  late final TextEditingController _startNumController;
  late final TextEditingController _prefixController;
  late final TextEditingController _suffixController;
  String _mensajeEstado = 'Sin archivo cargado';
  String? _rutaArchivoCargado;
  int _tamanoArchivo = 0;
  bool _isDragging = false;
  int _indiceSeleccionado = -1;
  final List<TextEditingController> _controladoresTitulos = [];
  final List<FocusNode> _focusNodesTitulos = [];
  String? _mensajeError;

  final String rutaTemplateDefecto = '../assets/Conv_Xhtml/template.xhtml';
  final String rutaPlantillasDefecto = '../assets/Plantillas';

  @override
  void initState() {
    super.initState();
    _startNumController = TextEditingController(text: _startNumActual.toString());
    _prefixController = TextEditingController(text: 'Cap. ');
    _suffixController = TextEditingController(text: ' - ');
  }

  @override
  void dispose() {
    _startNumController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    for (var c in _controladoresTitulos) {
      c.dispose();
    }
    for (var f in _focusNodesTitulos) {
      f.dispose();
    }
    super.dispose();
  }

  void _mostrarError(String msg) {
    setState(() {
      _mensajeError = msg;
    });
  }

  int get _palabrasTotales {
    if (_resultado == null) return 0;
    int total = 0;
    for (var cap in _resultado!.capitulos) {
      final textoPlano = cap.htmlCuerpo.replaceAll(RegExp(r'<[^>]+>'), ' ');
      total += textoPlano.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
    }
    return total;
  }

  int get _paginasEstimadas {
    int palabras = _palabrasTotales;
    if (palabras == 0) return 0;
    return (palabras / 250).ceil();
  }

  String _formatearTamano(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  TipoEspecial _tipoDeCapitulo(Chapter cap) {
    if (cap.tipoForzado != null) return cap.tipoForzado!;
    final det = detectarTipoEspecial(cap.titulo);
    return det ?? TipoEspecial.cuerpo;
  }

  String _nombreTipo(TipoEspecial tipo) {
    switch (tipo) {
      case TipoEspecial.cuerpo:
        return 'Cuerpo';
      case TipoEspecial.prologo:
        return 'Prólogo';
      case TipoEspecial.epilogo:
        return 'Epílogo';
      case TipoEspecial.interludio:
        return 'Interludio';
      case TipoEspecial.autor:
        return 'Autor';
      case TipoEspecial.traductor:
        return 'Traductor';
    }
  }

  Color _colorTipo(TipoEspecial tipo) {
    switch (tipo) {
      case TipoEspecial.cuerpo:
        return const Color(0xFF89B4FA);
      case TipoEspecial.prologo:
        return const Color(0xFFA6E3A1);
      case TipoEspecial.epilogo:
        return const Color(0xFFCBA6F7);
      case TipoEspecial.interludio:
        return const Color(0xFFFAB387);
      case TipoEspecial.autor:
        return const Color(0xFFF9E2AF);
      case TipoEspecial.traductor:
        return const Color(0xFF94E2D5);
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
        _mensajeEstado = '🔄 Procesando ($modo)...';
      });

      String? plantillas = Directory(rutaPlantillasDefecto).existsSync() ? rutaPlantillasDefecto : null;

      _resultado = await procesar(
        modo: modo,
        rutaEntrada: ruta,
        rutaTemplate: rutaTemplateDefecto,
        startNum: _startNumActual,
        rutaPlantillas: plantillas,
      );
      _mensajeEstado = '✅ $modo — ${p.basename(ruta)}';
      _actualizarControladores();

      if (_resultado!.capitulos.isNotEmpty) {
        _indiceSeleccionado = 0;
      }
    } catch (e) {
      _mostrarError(e.toString());
      _mensajeEstado = '❌ Error';
      _resultado = null;
    }
    setState(() {});
  }

  void _actualizarControladores() {
    for (var c in _controladoresTitulos) {
      c.dispose();
    }
    _controladoresTitulos.clear();
    for (var f in _focusNodesTitulos) {
      f.dispose();
    }
    _focusNodesTitulos.clear();

    if (_resultado != null) {
      for (var cap in _resultado!.capitulos) {
        _controladoresTitulos.add(TextEditingController(text: cap.titulo));
        _focusNodesTitulos.add(FocusNode());
      }
    }
  }

  void _renumerarCapitulos() {
    if (_resultado == null) return;
    clasificarYRenumerarCapitulos(_resultado!.capitulos, startNum: _startNumActual);
    asignarCapitulos(_resultado!.notas, _resultado!.capitulos, startNum: _startNumActual);
    _resultado!.contadores.capitulos = _resultado!.capitulos.length;
  }

  void _aplicarPrefijoSufijo() {
    if (_resultado == null) return;
    final pref = _prefixController.text;
    final suf = _suffixController.text;

    setState(() {
      for (int i = 0; i < _resultado!.capitulos.length; i++) {
        final cap = _resultado!.capitulos[i];
        final tipo = _tipoDeCapitulo(cap);
        if (tipo == TipoEspecial.cuerpo) {
          final partes = descomponerTitulo(cap.titulo, numeroPorDefecto: _startNumActual + i);
          final sub = partes.subtitulo;
          final numFmt = (_startNumActual + i).toString().padLeft(2, '0');
          if (sub != null && sub.isNotEmpty) {
            _controladoresTitulos[i].text = '$pref$numFmt$suf$sub';
          } else {
            _controladoresTitulos[i].text = '$pref$numFmt';
          }
          cap.titulo = _controladoresTitulos[i].text;
        }
      }
      _renumerarCapitulos();
    });
  }

  void _anadirFila() {
    if (_resultado == null) return;
    setState(() {
      int insertIndex = (_indiceSeleccionado >= 0 && _indiceSeleccionado < _resultado!.capitulos.length)
          ? _indiceSeleccionado + 1
          : _resultado!.capitulos.length;
      _resultado!.capitulos.insert(insertIndex, Chapter(titulo: '', htmlCuerpo: ''));
      _controladoresTitulos.insert(insertIndex, TextEditingController(text: ''));
      _focusNodesTitulos.insert(insertIndex, FocusNode());
      _indiceSeleccionado = insertIndex;
      _renumerarCapitulos();
      _validarConteo();
    });
  }

  Future<void> _quitarFila([int? indice]) async {
    if (_resultado == null || _resultado!.capitulos.isEmpty) return;
    int fila = indice ?? _indiceSeleccionado;
    if (fila < 0 || fila >= _resultado!.capitulos.length) {
      fila = _resultado!.capitulos.length - 1;
    }

    final cap = _resultado!.capitulos[fila];

    if (cap.htmlCuerpo.trim().isNotEmpty) {
      final respuesta = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Eliminar capítulo', style: TextStyle(color: Color(0xFFCDD6F4))),
          content: Text(
            'El capítulo "${cap.titulo.isEmpty ? "Capítulo ${fila + 1}" : cap.titulo}" contiene texto.\n\n¿Deseas unir su contenido con el capítulo anterior o descartarlo?',
            style: const TextStyle(color: Color(0xFFA6ADC8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancelar'),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6C7086))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'descartar'),
              child: const Text('Descartar texto', style: TextStyle(color: Color(0xFFF38BA8))),
            ),
            if (fila > 0 || _resultado!.capitulos.length > 1)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'unir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF89B4FA),
                  foregroundColor: const Color(0xFF1E1E2E),
                ),
                child: const Text('Unir con adyacente'),
              ),
          ],
        ),
      );

      if (respuesta == null || respuesta == 'cancelar') return;

      if (respuesta == 'unir') {
        if (fila > 0) {
          _resultado!.capitulos[fila - 1].htmlCuerpo += '\n${cap.htmlCuerpo}';
        } else if (_resultado!.capitulos.length > 1) {
          _resultado!.capitulos[fila + 1].htmlCuerpo = '${cap.htmlCuerpo}\n${_resultado!.capitulos[fila + 1].htmlCuerpo}';
        }
      }
    }

    setState(() {
      _resultado!.capitulos.removeAt(fila);
      _controladoresTitulos[fila].dispose();
      _controladoresTitulos.removeAt(fila);
      _focusNodesTitulos[fila].dispose();
      _focusNodesTitulos.removeAt(fila);

      _renumerarCapitulos();

      if (_resultado!.capitulos.isEmpty) {
        _indiceSeleccionado = -1;
      } else if (_indiceSeleccionado >= _resultado!.capitulos.length) {
        _indiceSeleccionado = _resultado!.capitulos.length - 1;
      } else if (_indiceSeleccionado > fila) {
        _indiceSeleccionado--;
      }

      _validarConteo();
    });
  }

  Future<void> _toggleTituloImagen(int index) async {
    if (_resultado == null || index >= _resultado!.capitulos.length) return;
    final cap = _resultado!.capitulos[index];

    if (!cap.tituloEsImagen) {
      String sugerencia = cap.numeroImagenTitulo ??
          extraerPrimeraImagen(cap.htmlCuerpo) ??
          extraerPrimeraImagen(cap.htmlRaw) ??
          '02';

      final controlador = TextEditingController(text: sugerencia);
      final resultado = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Título con Imagen', style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capítulo: ${cap.titulo}',
                style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Número de la imagen (ej: 02, 07):',
                style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controlador,
                autofocus: true,
                style: const TextStyle(color: Color(0xFFCDD6F4)),
                decoration: InputDecoration(
                  hintText: '02',
                  prefixText: '../Images/',
                  suffixText: '.jpg',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6C7086))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: const Color(0xFF1E1E2E),
              ),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (resultado != null && resultado.isNotEmpty) {
        setState(() {
          cap.tituloEsImagen = true;
          cap.numeroImagenTitulo = resultado.padLeft(2, '0');
        });
      }
    } else {
      final accion = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Título con Imagen', style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 16)),
          content: Text(
            'Actualmente usa "../Images/${cap.numeroImagenTitulo ?? "02"}.jpg" como título.',
            style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'desactivar'),
              child: const Text('Desactivar imagen', style: TextStyle(color: Color(0xFFF38BA8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'editar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: const Color(0xFF1E1E2E),
              ),
              child: const Text('Cambiar número'),
            ),
          ],
        ),
      );

      if (accion == 'desactivar') {
        setState(() {
          cap.tituloEsImagen = false;
        });
      } else if (accion == 'editar' && mounted) {
        final controlador = TextEditingController(text: cap.numeroImagenTitulo ?? '02');
        final nuevoNum = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text('Cambiar Número de Imagen', style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 16)),
            content: TextField(
              controller: controlador,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFCDD6F4)),
              decoration: InputDecoration(
                prefixText: '../Images/',
                suffixText: '.jpg',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6C7086))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF89B4FA),
                  foregroundColor: const Color(0xFF1E1E2E),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
        if (nuevoNum != null && nuevoNum.isNotEmpty) {
          setState(() {
            cap.numeroImagenTitulo = nuevoNum.padLeft(2, '0');
          });
        }
      }
    }
  }

  void _validarConteo() {
    if (_resultado == null) return;
    int esperados = _resultado!.capitulos.length;
    int actuales = _controladoresTitulos.length;

    int vacios = _controladoresTitulos.where((c) => c.text.trim().isEmpty).length;

    if (vacios > 0) {
      _mensajeError = 'Títulos: ${actuales - vacios}/$esperados — hay $vacios título(s) vacío(s)';
    } else {
      _mensajeError = null;
    }
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

  bool _puedeGenerar() => _resultado != null && _mensajeError == null;

  Future<void> _generar() async {
    String? salida = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Elige la carpeta de salida');
    if (salida == null) return;

    try {
      limpiarCarpeta(salida);
      String plantilla = await _cargarPlantilla();

      for (int i = 0; i < _resultado!.capitulos.length; i++) {
        var cap = _resultado!.capitulos[i];
        String titulo = _controladoresTitulos[i].text.trim();
        int num = _startNumActual + i;
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

        File(p.join(salida, archivo)).writeAsStringSync(htmlFinal);
      }

      if (_resultado!.notas.isNotEmpty) {
        File(p.join(salida, 'notas_Finales.xhtml')).writeAsStringSync(renderNotas(_resultado!.notas));
      }

      final titulos = _controladoresTitulos.map((c) => c.text.trim()).toList();
      File(p.join(salida, 'contenido-2.xhtml')).writeAsStringSync(
        renderTablaContenidos(_resultado!.capitulos, titulos),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Archivos generados en $salida')));
    } catch (e) {
      _mostrarError('Error al generar: $e');
    }
  }

  void _mostrarAjustes() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Ajustes y Rutas', style: TextStyle(color: Color(0xFFCDD6F4))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plantilla base (template.xhtml):', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
            const SizedBox(height: 4),
            Text(rutaTemplateDefecto, style: const TextStyle(color: Color(0xFF89B4FA), fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(height: 12),
            const Text('Carpeta de plantillas especiales:', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
            const SizedBox(height: 4),
            Text(rutaPlantillasDefecto, style: const TextStyle(color: Color(0xFF89B4FA), fontSize: 11, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF89B4FA), foregroundColor: const Color(0xFF1E1E2E)),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarAyuda() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Ayuda y Atajos', style: TextStyle(color: Color(0xFFCDD6F4))),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Arrastra archivos .docx, .pdf, .md o carpetas de Calibre a la zona de carga.', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13)),
            SizedBox(height: 8),
            Text('• Haz clic en el badge de TIPO en cualquier capítulo para cambiarlo manualmente (Prólogo, Cuerpo, etc.).', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13)),
            SizedBox(height: 8),
            Text('• Usa el botón de imagen 🖼️ para marcar capítulos cuyo título es una ilustración.', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13)),
            SizedBox(height: 8),
            Text('• La aplicación genera automáticamente la tabla de contenidos (contenido-2.xhtml).', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF89B4FA), foregroundColor: const Color(0xFF1E1E2E)),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Chapter? capSeleccionado = (_resultado != null &&
            _indiceSeleccionado >= 0 &&
            _indiceSeleccionado < _resultado!.capitulos.length)
        ? _resultado!.capitulos[_indiceSeleccionado]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -----------------------------------------------------------
              // 1. PANEL IZQUIERDO: Configuración y Carga de Manuscrito
              // -----------------------------------------------------------
              SizedBox(
                width: 270,
                child: Column(
                  children: [
                    // Card Configurar Capítulos
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF313244)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune, size: 16, color: Color(0xFF89B4FA)),
                              const SizedBox(width: 6),
                              const Text('Configurar Capítulos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFCDD6F4))),
                              const Spacer(),
                              InkWell(
                                onTap: _aplicarPrefijoSufijo,
                                child: const Tooltip(
                                  message: 'Aplicar prefijo y sufijo a los títulos',
                                  child: Icon(Icons.auto_fix_high, size: 16, color: Color(0xFF89B4FA)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('Start:', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 14),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  if (_startNumActual > 0) {
                                    setState(() {
                                      _startNumActual--;
                                      _startNumController.text = _startNumActual.toString();
                                      _renumerarCapitulos();
                                    });
                                  }
                                },
                              ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '$_startNumActual',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCDD6F4)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 14),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _startNumActual++;
                                    _startNumController.text = _startNumActual.toString();
                                    _renumerarCapitulos();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const SizedBox(width: 48, child: Text('Prefix', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12))),
                              Expanded(
                                child: SizedBox(
                                  height: 28,
                                  child: TextField(
                                    controller: _prefixController,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const SizedBox(width: 48, child: Text('Suffix', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12))),
                              Expanded(
                                child: SizedBox(
                                  height: 28,
                                  child: TextField(
                                    controller: _suffixController,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFCDD6F4)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Card Dropzone
                    Expanded(
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
                            FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false);
                            if (result != null && result.files.single.path != null) {
                              _procesarArchivo(result.files.single.path!);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: CustomPaint(
                            painter: DashedRectPainter(
                              color: _isDragging ? const Color(0xFF89B4FA) : const Color(0xFF45475A),
                              strokeWidth: _isDragging ? 2.0 : 1.2,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isDragging ? const Color(0xFF252538) : const Color(0xFF1E1E2E).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 36,
                                    color: _isDragging ? const Color(0xFF89B4FA) : const Color(0xFF6C7086),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Carga tu Manuscrito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFCDD6F4))),
                                  const SizedBox(height: 4),
                                  const Text('.docx, .pdf, or directory.', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11)),
                                  const SizedBox(height: 2),
                                  const Text('[Arrastra aquí o haz clic]', style: TextStyle(color: Color(0xFF89B4FA), fontSize: 10)),
                                  if (_rutaArchivoCargado != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF313244),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            p.basename(_rutaArchivoCargado!),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatearTamano(_tamanoArchivo),
                                            style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _mensajeEstado.startsWith('✅') ? '[Listo]' : _mensajeEstado,
                                      style: TextStyle(
                                        color: _mensajeEstado.startsWith('❌')
                                            ? const Color(0xFFF38BA8)
                                            : const Color(0xFFA6E3A1),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Botones Inferiores del Panel Izquierdo
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _resultado != null ? _anadirFila : null,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Añadir', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF313244),
                              foregroundColor: const Color(0xFFCDD6F4),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_resultado != null && _resultado!.capitulos.isNotEmpty && _indiceSeleccionado >= 0)
                                ? () => _quitarFila()
                                : null,
                            icon: const Icon(Icons.remove, size: 14),
                            label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF313244),
                              foregroundColor: const Color(0xFFF38BA8),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _mostrarAjustes,
                            icon: const Icon(Icons.tune, size: 14, color: Color(0xFFA6ADC8)),
                            label: const Text('Ajustes', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11)),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _mostrarAyuda,
                            icon: const Icon(Icons.help_outline, size: 14, color: Color(0xFFA6ADC8)),
                            label: const Text('Ayuda', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // -----------------------------------------------------------
              // 2. PANEL CENTRAL: Tabla de Capítulos Profesional con Badges
              // -----------------------------------------------------------
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dashboard Superior (Pills)
                    Row(
                      children: [
                        _buildPill(Icons.format_list_bulleted, 'Capítulos: ${_resultado?.contadores.capitulos ?? 0}', const Color(0xFF89B4FA)),
                        const SizedBox(width: 8),
                        _buildPill(Icons.edit_note, 'Notas: ${_resultado?.contadores.notas ?? 0}', const Color(0xFFF9E2AF)),
                        const SizedBox(width: 8),
                        _buildPill(Icons.image, 'Imágenes: ${_resultado?.contadores.imagenes ?? 0}', const Color(0xFFA6E3A1)),
                        const SizedBox(width: 8),
                        _buildPill(Icons.content_cut, 'Separadores: ${_resultado?.contadores.separadores ?? 0}', const Color(0xFFF38BA8)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tabla de Capítulos
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF313244)),
                        ),
                        child: Column(
                          children: [
                            // Encabezado de la Tabla
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF181825),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(9),
                                  topRight: Radius.circular(9),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text('ID', style: TextStyle(color: Color(0xFFA6ADC8), fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                  Expanded(
                                    child: Text('TÍTULO DEL CAPÍTULO', style: TextStyle(color: Color(0xFFA6ADC8), fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Center(
                                      child: Text('TIPO', style: TextStyle(color: Color(0xFFA6ADC8), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 85,
                                    child: Center(
                                      child: Text('ACCIONES', style: TextStyle(color: Color(0xFFA6ADC8), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFF313244)),

                            // Lista de Capítulos
                            Expanded(
                              child: _resultado == null || _resultado!.capitulos.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Arrastra un manuscrito para comenzar',
                                        style: TextStyle(color: Color(0xFF6C7086), fontSize: 13),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: _controladoresTitulos.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF252538)),
                                      itemBuilder: (context, index) {
                                        bool isSelected = index == _indiceSeleccionado;
                                        final cap = _resultado!.capitulos[index];
                                        final tipo = _tipoDeCapitulo(cap);
                                        final colorTipo = _colorTipo(tipo);

                                        return InkWell(
                                          onTap: () => setState(() => _indiceSeleccionado = index),
                                          child: Container(
                                            color: isSelected ? const Color(0xFF313244) : Colors.transparent,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Row(
                                              children: [
                                                // ID
                                                SizedBox(
                                                  width: 32,
                                                  child: Text(
                                                    (index + 1).toString().padLeft(2, '0'),
                                                    style: TextStyle(
                                                      color: isSelected ? const Color(0xFF89B4FA) : const Color(0xFFA6ADC8),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),

                                                // Título
                                                Expanded(
                                                  child: SizedBox(
                                                    height: 32,
                                                    child: TextField(
                                                      controller: _controladoresTitulos[index],
                                                      focusNode: _focusNodesTitulos[index],
                                                      style: const TextStyle(fontSize: 13, color: Color(0xFFCDD6F4)),
                                                      onTap: () {
                                                        if (_indiceSeleccionado != index) {
                                                          setState(() => _indiceSeleccionado = index);
                                                        }
                                                      },
                                                      onChanged: (v) {
                                                        cap.titulo = v;
                                                        _validarConteo();
                                                      },
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(4),
                                                          borderSide: BorderSide(
                                                            color: isSelected ? const Color(0xFF89B4FA) : const Color(0xFF45475A),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Badge TIPO (Interactivo con PopupMenu)
                                                SizedBox(
                                                  width: 100,
                                                  child: PopupMenuButton<TipoEspecial>(
                                                    tooltip: 'Cambiar tipo de capítulo',
                                                    color: const Color(0xFF1E1E2E),
                                                    onSelected: (nuevoTipo) {
                                                      setState(() {
                                                        cap.tipoForzado = nuevoTipo;
                                                        _renumerarCapitulos();
                                                      });
                                                    },
                                                    itemBuilder: (ctx) => [
                                                      for (var t in TipoEspecial.values)
                                                        PopupMenuItem(
                                                          value: t,
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 10,
                                                                height: 10,
                                                                decoration: BoxDecoration(
                                                                  color: _colorTipo(t),
                                                                  shape: BoxShape.circle,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                _nombreTipo(t),
                                                                style: TextStyle(
                                                                  color: t == tipo ? _colorTipo(t) : const Color(0xFFCDD6F4),
                                                                  fontWeight: t == tipo ? FontWeight.bold : FontWeight.normal,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: colorTipo.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: colorTipo.withValues(alpha: 0.4)),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          _nombreTipo(tipo),
                                                          style: TextStyle(
                                                            color: colorTipo,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),

                                                // ACCIONES
                                                SizedBox(
                                                  width: 85,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, size: 15),
                                                        color: const Color(0xFFA6ADC8),
                                                        tooltip: 'Editar título',
                                                        splashRadius: 12,
                                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                                        padding: EdgeInsets.zero,
                                                        onPressed: () {
                                                          setState(() => _indiceSeleccionado = index);
                                                          _focusNodesTitulos[index].requestFocus();
                                                        },
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          cap.tituloEsImagen ? Icons.image : Icons.image_outlined,
                                                          size: 15,
                                                        ),
                                                        color: cap.tituloEsImagen ? const Color(0xFF89B4FA) : const Color(0xFF6C7086),
                                                        tooltip: cap.tituloEsImagen
                                                            ? 'Título con imagen (${cap.numeroImagenTitulo ?? "02"})'
                                                            : 'El título es una imagen (click para activar)',
                                                        splashRadius: 12,
                                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                                        padding: EdgeInsets.zero,
                                                        onPressed: () => _toggleTituloImagen(index),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline, size: 15),
                                                        color: const Color(0xFFF38BA8),
                                                        tooltip: 'Eliminar este capítulo',
                                                        splashRadius: 12,
                                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                                        padding: EdgeInsets.zero,
                                                        onPressed: () => _quitarFila(index),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // -----------------------------------------------------------
              // 3. PANEL DERECHO: Resumen del Archivo y Vista Previa Limpia
              // -----------------------------------------------------------
              SizedBox(
                width: 290,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Resumen del Archivo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF313244)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, size: 16, color: Color(0xFF89B4FA)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _rutaArchivoCargado != null ? p.basename(_rutaArchivoCargado!) : 'Resumen del Archivo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFCDD6F4)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('Páginas:', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
                              const Spacer(),
                              Text('~$_paginasEstimadas', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCDD6F4), fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Palabras:', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 12)),
                              const Spacer(),
                              Text(
                                _palabrasTotales > 1000 ? '${(_palabrasTotales / 1000).toStringAsFixed(1)}k' : '$_palabrasTotales',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCDD6F4), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFF313244)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Limpia Formatos', style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 11)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFA6E3A1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('[ON]', style: TextStyle(color: Color(0xFFA6E3A1), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Vista Previa del Archivo Seleccionado
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF313244)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF89B4FA)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    capSeleccionado != null
                                        ? (capSeleccionado.archivo ?? 'C01.xhtml')
                                        : 'Vista Previa',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFCDD6F4)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181825),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF252538)),
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    capSeleccionado != null && capSeleccionado.htmlCuerpo.isNotEmpty
                                        ? capSeleccionado.htmlCuerpo
                                        : 'Selecciona un capítulo para previsualizar su HTML limpio.',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Color(0xFFA6ADC8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Mensaje de error si existe
                    if (_mensajeError != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          _mensajeError!,
                          style: const TextStyle(color: Color(0xFFF38BA8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],

                    // Botón Principal de Compilación
                    ElevatedButton.icon(
                      onPressed: _puedeGenerar() ? _generar : null,
                      icon: const Icon(Icons.task_alt, size: 18),
                      label: const Text('Compilar ePub Final [✓]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF89B4FA),
                        foregroundColor: const Color(0xFF181825),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        const Radius.circular(10),
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
