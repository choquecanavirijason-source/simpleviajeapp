import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:buses2/shared/widgets/botones/boton.dart';

// Inputs custom del proyecto
import 'package:buses2/shared/widgets/inputs/input_text.dart';
import 'package:buses2/shared/widgets/inputs/input_number.dart';

// Caja para subir/mostrar foto (con preview)
import 'package:buses2/shared/widgets/cajas/caja_subir_foto/box_subir_foto.dart';

// Controller
import './controller/controller.dart';
// Servicio para loguear la cuenta del usuario
import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';

// Servicio para guardar documentos
import 'package:buses2/core/services/doc_store/doc_store.dart';

import 'services/firebase_generic_page_loader.dart'; // para cargar datos de Firebase

import '../../../shared/widgets/overlays/cargando.dart'; // overlay de carga

import '../../../shared/widgets/overlays/success.dart'; // para mostrar éxito al guardar

import 'package:buses2/core/services/doc_store/doc_store_cache.dart'; // para caché local

class GenericPage extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final List<dynamic>? inputsConfig;
  final List<dynamic>? fileSectionsConfig;

  const GenericPage({
    super.key,
    this.title,
    this.subtitle,
    this.inputsConfig,
    this.fileSectionsConfig,
  });

  @override
  State<GenericPage> createState() => _GenericPageState();
}

class _GenericPageState extends State<GenericPage> {
  late final GenericPageController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = GenericPageController()
      ..init(
        args: Modular.args.data as Map<String, dynamic>?,
        fallbackTitle: widget.title,
        fallbackSubtitle: widget.subtitle,
        fallbackInputs: widget.inputsConfig,
        fallbackFiles: widget.fileSectionsConfig,
      );
    // Re-render cuando cambie canSave / files / etc.
    _controller.addListener(_onControllerChanged);

    // ⬇️ trae de Firebase y rellena vacíos
    _loadAndPrefill();
  }

  Future<void> _loadAndPrefill() async {
    final t0 = DateTime.now();
    try {
      final args = Modular.args.data as Map<String, dynamic>?;
      final docId = (args?['id'] as String?) ?? 'sin_id';

      final accountSvc = Modular.get<UserAccountService>();
      final acc = await accountSvc.current();
      if (acc == null) return;

      final cache = Modular.get<DocStoreCache>();
      final loader = GenericPageFirebaseLoader();
      final snapshot = await cache.fetchAndCache(
        uid: acc.uid, // uid del usuario actual
        docId: docId, // ID del documento
        preferCacheFirst: true, // ⬅️ lee cache primero si existe
        cacheEnabled: true, // ⬅️ guarda en el teléfono
        remoteFetch: (u, d) =>
            loader.fetch(uid: u, docId: d), // ⬅️ HOY Firebase
      );

      GenericPagePrefiller.apply(
        controller: _controller,
        data: (snapshot['data'] ?? const {}) as Map<String, dynamic>,
        files: (snapshot['files'] ?? const {}) as Map<String, dynamic>,
      );

      if (mounted) setState(() {}); // refresca para que se vean previews
    } catch (e) {
      // opcional: log/mostrar error
    }
  }

  void _onControllerChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose(); // libera controllers internamente
    super.dispose();
  }

  List<Widget> _buildInputs() {
    final widgets = <Widget>[];

    for (final input in _controller.inputsCfg) {
      final tipo = (input['tipo'] as String?)?.toLowerCase() ?? 'text';
      final label = input['label'] as String? ?? '';
      final key = _controller.keyForInput(input);
      final ctrl = _controller.ctrls[key]!;

      switch (tipo) {
        case 'number':
          widgets.add(NumberInput(controller: ctrl, label: label));
          break;
        case 'text':
        default:
          widgets.add(TextInput(controller: ctrl, label: label));
          break;
      }
      widgets.add(const SizedBox(height: 12));
    }

    if (widgets.isEmpty) {
      widgets.add(const Center(child: Text('No hay campos para mostrar.')));
    }

    return widgets;
  }

  List<Widget> _buildFileSections(ThemeData theme) {
    if (_controller.filesCfg.isEmpty) return const [];

    final widgets = <Widget>[];
    for (final sec in _controller.filesCfg) {
      final title = sec['title'] as String? ?? 'Archivo';
      final label = sec['label'] as String? ?? 'Agregar archivo';
      final icon = (sec['icon'] as IconData?) ?? Icons.camera_alt;
      final key = _controller.keyForFile(sec);
      final imageUrl = sec['initialUrl'] as String?;

      widgets.add(Text(title, style: theme.textTheme.titleMedium));
      widgets.add(const SizedBox(height: 8));

      widgets.add(
        FileBox(
          icon: icon,
          label: label,
          file: _controller.files[key],
          imageUrl: imageUrl,
          enablePicker: true,
          source: (sec['source'] == 'gallery')
              ? FileSource.gallery
              : FileSource.camera,
          maxDimension:
              (sec['maxDimension'] as int?) ?? 720, // puedes poner 1080, etc.
          imageQuality: (sec['imageQuality'] as int?) ?? 80,
          onChanged: (pickedFile) {
            setState(() {
              _controller.files[key] = pickedFile; // guarda en tu estado
              // si tu controller necesita recalcular "canSave", expón un método:
              // _controller.onFileChanged(key, pickedFile);
            });
          },
        ),
      );

      widgets.add(const SizedBox(height: 24));
    }
    return widgets;
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    Cargando.show(context, message: 'Guardando...'); // ⬅️ mostrar

    try {
      final result = _controller.buildResult(); // { id, data, files }

      // 1) uid del usuario actual
      final accountSvc = Modular.get<UserAccountService>();
      final acc = await accountSvc.current();
      if (acc == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay usuario autenticado')),
        );
        return;
      }

      // 2) guardar en Firebase (o el backend que esté enlazado)
      final docSvc = Modular.get<DocStoreService>();
      await docSvc.save(
        uid: acc.uid,
        docId: result['id'] as String,
        data: (result['data'] as Map).cast<String, String>(),
        files: (result['files'] as Map).cast<String, String?>(),
      );

      // Éxito: ocultar loader, mostrar confirmación, y cerrar
      Cargando.hide();
      await SuccessOverlay.flash(context, message: 'Guardado con éxito');
      if (mounted) Modular.to.pop(result);
    } catch (e) {
      Cargando.hide();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(
      context,
    ).viewInsets.bottom; // alto del teclado (0 si no hay)

    return Scaffold(
      resizeToAvoidBottomInset:
          true, // asegura que el body se reajuste con el teclado
      appBar: AppBar(
        title: Text(_controller.pageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Modular.to.pop(),
        ),
        bottom: _controller.pageSubtitle == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _controller.pageSubtitle!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          // un poco de espacio para que el contenido no quede oculto detrás del botón
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            ..._buildInputs(),
            if (_controller.filesCfg.isNotEmpty) ...[
              const Divider(height: 24),
              ..._buildFileSections(theme),
            ],
          ],
        ),
      ),

      // ⬇️ Botón pegado abajo; sube sobre el teclado automáticamente
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          // si hay teclado, lo elevamos justo por encima + margen
          bottom: bottomInset > 0 ? bottomInset + 16 : 16,
        ),
        child: SafeArea(
          top: false, // solo respetamos el safe area inferior
          child: Opacity(
            opacity: _controller.canSave ? 1 : 0.6,
            child: IgnorePointer(
              ignoring: !_controller.canSave,
              child: Boton1(
                label: 'Guardar y Cerrar',
                color: BotonColor.color1,
                borde: BotonBorde.borde1,
                iconoIzquierdo: Icons.save,
                iconoDerecho: Icons.check,
                onPressed: _onSave,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* Se puede usar así:
// Uso estático (nuevo) — ahora pasas *config*:
onTap: () async {
  final result = await Modular.to.pushNamed(
    '/pantalla-generica',
    arguments: {
      'id': 'doc_nit',                    // ID único del formulario
      'title': 'Registro de NIT',
      'subtitle': 'Completa estos datos',

      // Antes: 'inputs' con widgets
      // Ahora: 'inputsConfig' con mapas (GenericPage crea controllers)
      'inputsConfig': [
        {
          'key'  : 'nit_numero',
          'tipo' : 'number',
          'label': 'Número de NIT',
          'maxDigits': 10,           // si tu NumberInput lo soporta, puedes leerlo en GenericPage
          'initialValue': '',        // opcional
        },
        {
          'key'  : 'nit_nombre',
          'tipo' : 'text',
          'label': 'Nombre en NIT',
          'initialValue': 'ACME SRL', // opcional para precargar
        },
      ],

      // Antes: 'fileSections' con onTap y pickers
      // Ahora: 'fileSectionsConfig' (GenericPage maneja la cámara/galería)
      'fileSectionsConfig': [
        {
          'key'  : 'nit_frente',
          'title': 'Foto de NIT (frente)',
          'label': 'Agregar frente',
          'icon' : Icons.camera_alt,
        },
        {
          'key'  : 'nit_reverso',
          'title': 'Foto de NIT (reverso)',
          'label': 'Agregar reverso',
          'icon' : Icons.camera_alt,
        },
      ],

      // Opcional: puedes seguir enviando actions; GenericPage añadirá "Guardar y cerrar" igualmente
      // 'actions': [ ... ],
    },
  );

  // GenericPage hace pop devolviendo { id, data, files }
  if (result is Map<String, dynamic>) {
    final id    = result['id']   as String;
    final data  = (result['data']  as Map).cast<String, String>();     // textos
    final files = (result['files'] as Map).cast<String, String?>();    // paths locales de fotos
    // Aquí ya puedes subir a Firebase si prefieres hacerlo desde esta pantalla
    // await subirAFirebase(id, data, files);
  }
}
*/

/* Uso dinamico
onTap: () {
  Modular.to.pushNamed('/pantalla-generica', arguments: {
    'id'               : boton['id'],
    'title'            : boton['screenTitle'],
    'subtitle'         : boton['screenSubtitle'],
    'inputsConfig'     : boton['inputs'],       // lista de mapas {key,tipo,label,...}
    'fileSectionsConfig': boton['fileSections'] // lista de mapas {key,title,label,icon,...}
  });
}
*/
