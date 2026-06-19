import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/cajas/caja_subir_foto/box_subir_foto.dart';
import 'package:buses2/shared/widgets/overlays/btn_cargando.dart';
import 'package:buses2/shared/widgets/notificacion/notificacion.dart';
import 'package:buses2/shared/widgets/botones/boton_desactivado.dart';

import 'package:buses2/shared/utils/dibujamos_n+1_cajas.dart';

import 'package:buses2/shared/services/save_traer_firebase/storage/storage.dart';
import 'package:buses2/shared/services/save_traer_firebase/escrituras/doc.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/doc.dart';

class GenericPageTaxi extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final List<dynamic>? inputsConfig;
  final List<dynamic>? fileSectionsConfig;

  const GenericPageTaxi({
    super.key,
    this.title,
    this.subtitle,
    this.inputsConfig,
    this.fileSectionsConfig,
  });

  @override
  State<GenericPageTaxi> createState() => _GenericPageState();
}

class _GenericPageState extends State<GenericPageTaxi> {
  final List<TextEditingController> _controllers = [];
  final _storage = StorageService();

  // Textos
  List<String> _etiquetas = [];

  // Archivos
  List<String> _archivoLabels = [];
  final Map<String, dynamic> _filesPorEtiqueta =
      {}; // label -> File? (o lo que FileBox entregue)
  final Map<String, String?> _imageUrlsPorEtiqueta =
      {}; // label -> url remota opcional

  String _titulo = '';
  String? _docId;

  bool _loading = false;

  bool _puedeGuardar = false; // botón desactivado por defecto

  @override
  void initState() {
    super.initState();
    final args = Modular.args.data as Map?;
    debugPrint('📥 Recibido args: $args');

    final tituloDoc = (args?['tituloDoc'] as String?) ?? '';
    final et = (args?['etiquetas'] as Map?) ?? {};

    _docId = et['docId'] as String?;
    final etiquetasTextos =
        (et['textos'] as List?)?.whereType<String>().toList() ?? <String>[];
    final etiquetasArchivos =
        (et['archivos'] as List?)?.whereType<String>().toList() ?? <String>[];

    _titulo = tituloDoc;
    _etiquetas = etiquetasTextos;

    // Archivos
    _archivoLabels = etiquetasArchivos;
    for (final label in _archivoLabels) {
      _filesPorEtiqueta[label] = null; // aún no eligieron archivo
      _imageUrlsPorEtiqueta[label] =
          null; // si tienes una URL previa, setéala aquí
    }

    // Controllers para inputs de texto
    _controllers.addAll(
      List.generate(_etiquetas.length, (_) => TextEditingController()),
    );
    _cargarDatosPrevios();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatosPrevios() async {
    if (_docId == null) return;

    // 🔹 Leer documento del taxista
    final docs = await DocGets.get(
      absoluteDocPath: ['taxistas/{uid}'],
      nombreMap: ['misDocumentos-$_docId'],
    );

    final data = docs.first;
    if (data == null) {
      // ✅ No existen datos → habilita botón
      setState(() {
        _puedeGuardar = true;
      });
      return;
    }

    // Rellenar textos
    for (int i = 0; i < _etiquetas.length; i++) {
      final key = 'campoTexto_${i + 1}';
      final valor = data[key];
      if (valor is String) {
        _controllers[i].text = valor;
      }
    }

    // Rellenar imágenes
    for (int i = 0; i < _archivoLabels.length; i++) {
      final key = 'campoArchivo_${i + 1}';
      final url = data[key];
      if (url is String && url.isNotEmpty) {
        _imageUrlsPorEtiqueta[_archivoLabels[i]] = url;
      }
    }
    setState(() {}); // refresca la UI
  }

  Future<void> _guardar() async {
    if (_docId == null) return;
    setState(() => _loading = true); // 👈 activa overlay
    try {
      final Map<String, dynamic> campos = {};

      // Campos de texto
      for (int i = 0; i < _etiquetas.length; i++) {
        campos['campoTexto_${i + 1}'] = _controllers[i].text.trim();
      }

      // Campos de archivo
      for (int i = 0; i < _archivoLabels.length; i++) {
        final file =
            _filesPorEtiqueta[_archivoLabels[i]]; // 👈 el File seleccionado
        String? url;
        if (file != null) {
          // ruta única en Firebase Storage
          final path =
              "taxistas/{uid}/misDocumentos/$_docId/campoArchivo_${i + 1}.jpg";
          url = await _storage.uploadPhoto(file, path);
        }
        campos['campoArchivo_${i + 1}'] = url ?? '';
      }

      await DocSets.set(
        absoluteDocPath: ['taxistas/{uid}'],
        nombreMap: ['misDocumentos-$_docId'],
        data: [
          campos,
          //'updatedAt': DateTime.now().millisecondsSinceEpoch,
        ],
      );
      notificacion(
        context,
        title: 'Documentos enviados',
        //subtitle: 'Se actualizó tu perfil correctamente',
        seconds: 6,
        icon: Icons.check_rounded,
        color: Colors.green, // usa tu color
        // position: NotificationPosition.bottom, // notificacion abajo
      );
      if (mounted) Modular.to.pop(true);
    } catch (e) {
      notificacion(
        context,
        title: '❌ Error al guardar: $e',
        //subtitle: 'Se actualizó tu perfil correctamente',
        seconds: 6,
        icon: Icons.check_rounded,
        color: Colors.red, // usa tu color
        // position: NotificationPosition.bottom, // notificacion abajo
      );
    } finally {
      if (mounted) setState(() => _loading = false); // 👈 desactiva overlay
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldConBottom(
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: _titulo,
        backgroundColor: Colors.blueAccent,
        textColor: Colors.white,
        hasShadow: false,
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.settings,
        onTapDerecha: () => debugPrint('Ajustes'),
      ),
      scrollBody: true,
      body: Padding(
        padding: const EdgeInsets.all(16), // 👈 único padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Inputs de texto (sin Padding por item)
            for (int i = 0; i < _etiquetas.length; i++) ...[
              TextInput2(
                controller: _controllers[i],
                label: _etiquetas[i],
                placeholder: 'Ingrese ${_etiquetas[i]}',
                keyboardType: TextInputType.text,
                //suffixIcon: Icons.local_taxi,
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              if (i < _etiquetas.length - 1) const SizedBox(height: 12),
            ],

            if (_etiquetas.isNotEmpty) const SizedBox(height: 20),

            // Pickers de archivo (sin Padding por item)
            for (int i = 0; i < _archivoLabels.length; i++) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _archivoLabels[i],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        // Ancho mínimo razonable para que no se vea “pequeño”
                        minWidth: 360,
                        // Límite máximo para que no se estire demasiado en pantallas grandes
                        maxWidth: 720,
                      ),
                      child: SizedBox(
                        // Ocupa el 95% del ancho disponible hasta el maxWidth
                        width: MediaQuery.of(context).size.width * 0.95,
                        child: FileBox(
                          icon: Icons.image,
                          label: 'Subir ${_archivoLabels[i]}',
                          file: _filesPorEtiqueta[_archivoLabels[i]],
                          imageUrl: _imageUrlsPorEtiqueta[_archivoLabels[i]],
                          onChanged: (file) {
                            setState(() {
                              _filesPorEtiqueta[_archivoLabels[i]] = file;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (i < _archivoLabels.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),

      btnFijoAbajo: _puedeGuardar
          ? Btn_Cargando(
              loading: _loading,
              borde: BtnBorde
                  .borde1, // borde1 (pill) | borde2 (12) | borde3 (cuadrado)
              workingLabel:
                  'Enviando Datos...', // 👈 texto que quieres ver mientras carga
              overlayColor: Colors.grey, // sólido
              spinnerColor: Colors.white, // visible sobre gris
              child: Boton1(
                label: 'Guardar y Cerrar',
                color: BotonColor.color1,
                borde: BotonBorde.borde1,
                iconoIzquierdo: Icons.save,
                iconoDerecho: Icons.save,
                onPressed: disableOnLoading(
                  _loading,
                  _guardar,
                ), // 👈 evita doble click
              ),
            )
          : const BotonDesactivado(
              label: 'Guardar y Cerrar',
              iconoIzquierdo: Icons.save,
              iconoDerecho: Icons.save,
            ),
    );
  }
}
