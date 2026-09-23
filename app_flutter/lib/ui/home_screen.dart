import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../motor/modelo.dart';
import '../motor/procesar.dart';
import '../motor/adaptadores.dart';
import '../motor/render.dart';
import '../motor/plantillas.dart';
import '../motor/notas.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Resultado? _resultado;
  String? _rutaEntrada;
  int _startNumActual = 1;
  late final TextEditingController _startNumController;
  String _mensajeEstado = 'Sin archivo cargado';
  bool _isDragging = false;
  int _indiceSeleccionado = -1;
  final List<TextEditingController> _controladoresTitulos = [];
  String? _mensajeError;

  final String rutaTemplateDefecto = '../assets/Conv_Xhtml/template.xhtml';
  final String rutaPlantillasDefecto = '../assets/Plantillas';

  @override
  void initState() {
    super.initState();
    _startNumController = TextEditingController(text: _startNumActual.toString());
  }

  @override
  void dispose() {
    _startNumController.dispose();
    for (var c in _controladoresTitulos) {
      c.dispose();
    }
    super.dispose();
  }

  void _mostrarError(String msg) {
    setState(() {
      _mensajeError = msg;
    });
  }

  Future<void> _procesarArchivo(String ruta) async {
    setState(() {
      _mensajeEstado = '🔄 Procesando...';
      _mensajeError = null;
    });

    try {
      String modo = detectarModo(ruta);
      setState(() {
        _mensajeEstado = '🔄 Procesando... ($modo)';
      });

      String? plantillas = Directory(rutaPlantillasDefecto).existsSync() ? rutaPlantillasDefecto : null;

      _resultado = await procesar(
        modo: modo,
        rutaEntrada: ruta,
        rutaTemplate: rutaTemplateDefecto,
        startNum: _startNumActual,
        rutaPlantillas: plantillas,
      );

      _rutaEntrada = ruta;
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
    if (_resultado != null) {
      for (var cap in _resultado!.capitulos) {
        _controladoresTitulos.add(TextEditingController(text: cap.titulo));
      }
    }
  }

  void _renumerarCapitulos() {
    if (_resultado == null) return;
    int num = _startNumActual;
    for (var c in _resultado!.capitulos) {
      if (c.plantillaRuta == null) {
        c.archivo = 'C${num.toString().padLeft(2, '0')}.xhtml';
        num++;
      }
    }
    asignarCapitulos(_resultado!.notas, _resultado!.capitulos, startNum: _startNumActual);
    _resultado!.contadores.capitulos = _resultado!.capitulos.length;
  }

  void _anadirFila() {
    if (_resultado == null) return;
    setState(() {
      int insertIndex = (_indiceSeleccionado >= 0 && _indiceSeleccionado < _resultado!.capitulos.length)
          ? _indiceSeleccionado + 1
          : _resultado!.capitulos.length;
      _resultado!.capitulos.insert(insertIndex, Chapter(titulo: '', htmlCuerpo: ''));
      _controladoresTitulos.insert(insertIndex, TextEditingController(text: ''));
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

    // Sincronizar títulos actuales
    for (int i = 0; i < _controladoresTitulos.length; i++) {
      if (i < _resultado!.capitulos.length) {
        _resultado!.capitulos[i].titulo = _controladoresTitulos[i].text;
      }
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

  bool _puedeGenerar() => _resultado != null && _mensajeError == null;

  Future<void> _generar() async {
    String? salida = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Elige la carpeta de salida');
    if (salida == null) return;

    try {
      limpiarCarpeta(salida);
      String plantilla = File(rutaTemplateDefecto).readAsStringSync();
      
      for (int i = 0; i < _resultado!.capitulos.length; i++) {
        var cap = _resultado!.capitulos[i];
        String titulo = _controladoresTitulos[i].text.trim();
        int num = _startNumActual + i;
        String archivo = cap.archivo ?? 'C${num.toString().padLeft(2, '0')}.xhtml';
        int numero = numeroDeArchivo(archivo, num);
        
        String htmlFinal;
        if (cap.plantillaRuta != null) {
          String plantillaEspecial = File(cap.plantillaRuta!).readAsStringSync();
          htmlFinal = renderCapituloEspecial(plantillaEspecial, titulo, numero, cap.htmlCuerpo);
        } else {
          htmlFinal = renderCapitulo(plantilla, titulo, numero, cap.htmlCuerpo);
        }
        
        File(p.join(salida, archivo)).writeAsStringSync(htmlFinal);
      }
      
      if (_resultado!.notas.isNotEmpty) {
        File(p.join(salida, 'notas_Finales.xhtml')).writeAsStringSync(renderNotas(_resultado!.notas));
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Archivos generados en $salida')));
    } catch (e) {
      _mostrarError('Error al generar: $e');
    }
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF45475A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Iniciar numeración de capítulos en: '),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    controller: _startNumController,
                    onChanged: (v) {
                      setState(() {
                        _startNumActual = int.tryParse(v) ?? 1;
                        _renumerarCapitulos();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (details) {
                if (details.files.isNotEmpty) {
                  _procesarArchivo(details.files.first.path);
                }
              },
              child: InkWell(
                onTap: () async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false);
                  if (result != null) {
                    _procesarArchivo(result.files.single.path!);
                  }
                },
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isDragging ? const Color(0xFF252536) : const Color(0xFF1E1E2E),
                    border: Border.all(color: _isDragging ? const Color(0xFF89B4FA) : const Color(0xFF585B70), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('📂 Arrastra aquí tu .docx, .pdf o tu carpeta, o haz clic para explorar'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_mensajeEstado, style: const TextStyle(color: Color(0xFF89B4FA), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                _buildBadge('📄 Capítulos: ${_resultado?.contadores.capitulos ?? '—'}', const Color(0xFF89B4FA)),
                _buildBadge('📝 Notas: ${_resultado?.contadores.notas ?? '—'}', const Color(0xFFF9E2AF)),
                _buildBadge('🖼️ Imágenes: ${_resultado?.contadores.imagenes ?? '—'}', const Color(0xFFA6E3A1)),
                _buildBadge('✂️ Separadores: ${_resultado?.contadores.separadores ?? '—'}', const Color(0xFFF38BA8)),
              ],
            ),
            if (_resultado?.avisos.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('⚠️ ${_resultado!.avisos.join('; ')}', style: const TextStyle(color: Color(0xFFF9E2AF))),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF45475A)),
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFF313244),
                            ),
                            child: ListView.builder(
                              itemCount: _controladoresTitulos.length,
                              itemBuilder: (context, index) {
                                bool isSelected = index == _indiceSeleccionado;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _indiceSeleccionado = index;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF45475A) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF89B4FA) : const Color(0xFF3B3D52),
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: isSelected ? const Color(0xFF89B4FA) : const Color(0xFFA6ADC8),
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: _controladoresTitulos[index],
                                              onTap: () {
                                                if (_indiceSeleccionado != index) {
                                                  setState(() {
                                                    _indiceSeleccionado = index;
                                                  });
                                                }
                                              },
                                              onChanged: (v) {
                                                if (_resultado != null && index < _resultado!.capitulos.length) {
                                                  _resultado!.capitulos[index].titulo = v;
                                                }
                                                _validarConteo();
                                              },
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                  borderSide: BorderSide(
                                                    color: isSelected ? const Color(0xFF89B4FA) : const Color(0xFF585B70),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 16),
                                            color: const Color(0xFFF38BA8),
                                            tooltip: 'Eliminar este capítulo',
                                            splashRadius: 14,
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _quitarFila(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _anadirFila,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Añadir'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: (_resultado != null && _resultado!.capitulos.isNotEmpty && _indiceSeleccionado >= 0)
                                  ? () => _quitarFila()
                                  : null,
                              icon: const Icon(Icons.remove, size: 16),
                              label: Text(_indiceSeleccionado >= 0 && _resultado != null && _indiceSeleccionado < _resultado!.capitulos.length
                                  ? 'Eliminar (${_indiceSeleccionado + 1})'
                                  : 'Eliminar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        if (_resultado != null && _resultado!.capitulos.isNotEmpty)
                          DropdownButton<int>(
                            value: _indiceSeleccionado,
                            isExpanded: true,
                            items: List.generate(_resultado!.capitulos.length, (index) {
                              return DropdownMenuItem(
                                value: index,
                                child: Text('Capítulo ${index + _startNumActual} — ${_resultado!.capitulos[index].titulo}'),
                              );
                            }),
                            onChanged: (v) => setState(() => _indiceSeleccionado = v!),
                          ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF45475A)), color: const Color(0xFF1E1E2E)),
                                  child: SingleChildScrollView(
                                    child: Text(_indiceSeleccionado >= 0 && _indiceSeleccionado < (_resultado?.capitulos.length ?? 0) ? _resultado!.capitulos[_indiceSeleccionado].htmlRaw : '',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF45475A)), color: const Color(0xFF1E1E2E)),
                                  child: SingleChildScrollView(
                                    child: Text(_indiceSeleccionado >= 0 && _indiceSeleccionado < (_resultado?.capitulos.length ?? 0) ? _resultado!.capitulos[_indiceSeleccionado].htmlCuerpo : '',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_mensajeError != null)
                  Text(_mensajeError!, style: const TextStyle(color: Color(0xFFF38BA8), fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton(
                  onPressed: _puedeGenerar() ? _generar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA6E3A1),
                    foregroundColor: const Color(0xFF1E1E2E),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  ),
                  child: const Text('Generar Archivos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
