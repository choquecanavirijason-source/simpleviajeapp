import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:buses2/features/home_empresa_features/servicios/services/guardar_tarifas.dart';
import 'package:buses2/features/home_empresa_features/servicios/tramo_row_card.dart';

import 'package:buses2/shared/services/save_traer_firebase/storage/storage.dart';
import 'package:buses2/shared/widgets/cajas/caja_edit/caja_edit.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import 'package:buses2/shared/widgets/cajas/caja_contenedora/caja_contenedora.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/shared/widgets/inputs/input_number.dart';

import './widgets/modal_inferior_servicios.dart';
import './widgets/modal_inferior_departamentos.dart';
import './widgets/tarifas_servicio.dart';
import './widgets/single_photo_card.dart';

import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';

// 👇 Import del overlay y helpers
import 'package:buses2/shared/widgets/overlays/btn_cargando.dart';

class NewServicePage extends StatefulWidget {
  const NewServicePage({super.key});

  @override
  State<NewServicePage> createState() => _NewServicePageState();
}

class _NewServicePageState extends State<NewServicePage> {
  // --- EDIT MODE ---
  bool _isEditing = false;
  String? _editingDepartamentoKey;
  String? _editingServicioKey;

  late final NumberEditingController _tarifaBaseCtrl;
  late final NumberEditingController _distBaseCtrl;
  late final NumberEditingController _porKmCtrl;
  late final NumberEditingController _porMinCtrl;
  late final NumberEditingController _horaPicoCtrl;
  late final NumberEditingController _nocturnoCtrl;
  late final NumberEditingController _comisionCtrl;
  bool _servicioActivo = true;

  final List<File> _imagenes = [];
  static const int _maxFotos = 1;

  // Mantener la URL actual del logo si existe (para no perderla si no se sube nueva)
  String? _logoUrl;

  // Overlay loading
  bool _loading = false;

  List<(String left, String right)> _tramosAero = const [
    ('10', '40.00'),
    ('20', '60.00'),
    ('30', '80.00'),
  ];

  List<({TimeOfDay desde, TimeOfDay hasta})> _franjasHoras = const [
    (
      desde: TimeOfDay(hour: 7, minute: 0),
      hasta: TimeOfDay(hour: 9, minute: 0),
    ),
    (
      desde: TimeOfDay(hour: 12, minute: 0),
      hasta: TimeOfDay(hour: 14, minute: 0),
    ),
    (
      desde: TimeOfDay(hour: 18, minute: 0),
      hasta: TimeOfDay(hour: 20, minute: 0),
    ),
  ];

  String? _servicioSeleccionado;
  String? _departamentoSeleccionado;

  List<String> _cacheServicios = [];
  List<String> _cacheDepartamentos = [];

  @override
  void initState() {
    super.initState();
    _tarifaBaseCtrl = NumberEditingController(
      allowDecimal: true,
      decimalPlaces: 2,
    );
    _distBaseCtrl = NumberEditingController(
      allowDecimal: true,
      decimalPlaces: 2,
    );
    _porKmCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
    _porMinCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
    _horaPicoCtrl = NumberEditingController(
      allowDecimal: true,
      decimalPlaces: 2,
    );
    _nocturnoCtrl = NumberEditingController(
      allowDecimal: true,
      decimalPlaces: 2,
    );
    _comisionCtrl = NumberEditingController(
      allowDecimal: true,
      decimalPlaces: 2,
    );

    (() async {
      _cacheServicios = await _traerServicios();
      _cacheDepartamentos = await _traerDepartamentos();
      if (mounted) setState(() {});
    })();

    _prefillFromArgs();
  }

  /// Normaliza el nombre del servicio para usarlo como key en el doc.
  /// Tiene que coincidir EXACTAMENTE con `_mapKey` de `guardar_tarifas.dart`.
  String _mapKey(String s) => s
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^\w\-]'), '')
      .toLowerCase();

  /// Llena los inputs (tarifas, tramos, franjas, logo, activo) a partir del
  /// mapa de un servicio. Reusable tanto desde `_prefillFromArgs` (edición)
  /// como desde `_prefillDesdeFirestore` (autocomplete al elegir servicio+depto).
  void _llenarDesdeServicioMap(Map<String, dynamic> servicioMap) {
    _servicioActivo = servicioMap['activo'] == true;

    final logo = (servicioMap['logo'] ?? '').toString();
    if (logo.isNotEmpty) {
      _logoUrl = logo;
    }

    final tarifas = (servicioMap['tarifas'] ?? {}) as Map<String, dynamic>;
    void _setNum(NumberEditingController c, dynamic v) {
      if (v == null) {
        c.text = '';
        return;
      }
      final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
      c.text = (n != null) ? n.toStringAsFixed(2) : '';
    }

    _setNum(_tarifaBaseCtrl, tarifas['tarifaBase']);
    _setNum(_distBaseCtrl, tarifas['distanciaBase']);
    _setNum(_porKmCtrl, tarifas['porKm']);
    _setNum(_porMinCtrl, tarifas['porMin']);
    _setNum(_horaPicoCtrl, tarifas['horaPicoExtra']);
    _setNum(_nocturnoCtrl, tarifas['nocturno']);
    _setNum(_comisionCtrl, tarifas['comision']);

    final tramos =
        (servicioMap['Tarifas_Aeropuerto']?['tramos'] as List?) ?? const [];
    _tramosAero = [
      for (final t in tramos)
        (
          (t['desdeKm'] ?? '').toString(),
          (() {
            final p = t['precio'];
            if (p is num) return p.toStringAsFixed(2);
            final d = double.tryParse(p?.toString() ?? '');
            return d?.toStringAsFixed(2) ?? '';
          })(),
        ),
    ];

    TimeOfDay _parseHHmm(dynamic s) {
      final txt = (s ?? '').toString();
      final parts = txt.split(':');
      if (parts.length != 2) return const TimeOfDay(hour: 0, minute: 0);
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }

    final franjas =
        (servicioMap['Horas_pico']?['franjas'] as List?) ?? const [];
    _franjasHoras = [
      for (final f in franjas)
        (desde: _parseHHmm(f['desde']), hasta: _parseHHmm(f['hasta'])),
    ];
  }

  void _prefillFromArgs() {
    final args = Modular.args.data as Map<String, dynamic>?;
    if (args == null) return;

    final departamento = args['departamento'] as String?;
    final servicioKey = args['servicioKey'] as String?;
    final servicioMap = (args['servicioMap'] ?? {}) as Map<String, dynamic>;

    _editingDepartamentoKey = departamento;
    _editingServicioKey = servicioKey;
    _isEditing = (departamento != null && servicioKey != null);

    if (departamento != null) _departamentoSeleccionado = departamento;

    _servicioSeleccionado =
        (servicioMap['servicio'] as String?) ??
        servicioKey ??
        _servicioSeleccionado;

    _llenarDesdeServicioMap(servicioMap);

    if (mounted) setState(() {});
  }

  /// Si ya hay servicio + departamento seleccionados, lee el doc en Firestore
  /// y, si encuentra este servicio guardado, autocompleta los inputs con sus
  /// valores actuales. Si no existe → deja los inputs como están (vacíos).
  /// No corre en modo edición (esos datos ya vienen por args).
  Future<void> _prefillDesdeFirestore() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🟢 [TARIFAS_FETCH] _prefillDesdeFirestore() called');

    if (_isEditing) {
      debugPrint('⏭️  [TARIFAS_FETCH] skip: estoy en modo edición');
      return;
    }

    final servicio = _servicioSeleccionado;
    final departamento = _departamentoSeleccionado;
    debugPrint(
      '📋 [TARIFAS_FETCH] selecciones: servicio="$servicio" depto="$departamento"',
    );

    if (servicio == null || departamento == null) {
      debugPrint(
        '⏭️  [TARIFAS_FETCH] skip: falta servicio o depto (espero a que el usuario complete ambos)',
      );
      return;
    }

    final key = _mapKey(servicio);
    final docPath = 'empresas/mujeresalvolante/tarifas/$departamento';
    debugPrint('🔑 [TARIFAS_FETCH] servicioKey normalizada: "$key"');
    debugPrint('🌐 [TARIFAS_FETCH] consultando docPath: "$docPath"');

    try {
      final stopwatch = Stopwatch()..start();
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc('mujeresalvolante')
          .collection('tarifas')
          .doc(departamento)
          .get();
      stopwatch.stop();
      debugPrint(
        '⏱️  [TARIFAS_FETCH] respuesta de Firestore en ${stopwatch.elapsedMilliseconds}ms',
      );
      debugPrint('📦 [TARIFAS_FETCH] snap.exists = ${snap.exists}');

      if (!snap.exists) {
        debugPrint(
          '❌ [TARIFAS_FETCH] doc NO existe en Firestore → no hay tarifas previas. Inputs quedan vacíos.',
        );
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return;
      }

      final data = snap.data() ?? {};
      debugPrint(
        '📄 [TARIFAS_FETCH] keys del doc (${data.length}): ${data.keys.toList()}',
      );

      final servicioMap = data[key];
      debugPrint(
        '🔍 [TARIFAS_FETCH] buscando key "$key" → tipo encontrado: ${servicioMap.runtimeType}',
      );

      if (servicioMap is! Map<String, dynamic>) {
        debugPrint(
          '❌ [TARIFAS_FETCH] servicio "$key" NO existe en este doc (o no es un Map). Inputs quedan vacíos.',
        );
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return;
      }

      debugPrint('✅ [TARIFAS_FETCH] servicio encontrado. Valores brutos:');
      final tarifas = servicioMap['tarifas'] as Map<String, dynamic>?;
      if (tarifas != null) {
        debugPrint('   tarifas:');
        tarifas.forEach((k, v) {
          debugPrint('     - $k: $v (${v.runtimeType})');
        });
      } else {
        debugPrint('   tarifas: null (no hay sub-mapa "tarifas")');
      }
      debugPrint('   activo: ${servicioMap['activo']}');
      debugPrint('   logo: ${servicioMap['logo']}');
      final tramos = servicioMap['Tarifas_Aeropuerto']?['tramos'];
      debugPrint(
        '   Tarifas_Aeropuerto.tramos: ${tramos is List ? "${tramos.length} tramos" : "vacío"}',
      );
      final franjas = servicioMap['Horas_pico']?['franjas'];
      debugPrint(
        '   Horas_pico.franjas: ${franjas is List ? "${franjas.length} franjas" : "vacío"}',
      );

      _llenarDesdeServicioMap(servicioMap);
      debugPrint(
        '✏️  [TARIFAS_FETCH] inputs poblados. Estado actual de los controllers:',
      );
      debugPrint('     tarifaBase  = "${_tarifaBaseCtrl.text}"');
      debugPrint('     distBase    = "${_distBaseCtrl.text}"');
      debugPrint('     porKm       = "${_porKmCtrl.text}"');
      debugPrint('     porMin      = "${_porMinCtrl.text}"');
      debugPrint('     horaPico    = "${_horaPicoCtrl.text}"');
      debugPrint('     nocturno    = "${_nocturnoCtrl.text}"');
      debugPrint('     comision    = "${_comisionCtrl.text}"');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tarifas existentes de "$servicio" en $departamento cargadas. '
              'Podés editarlas y guardar.',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('💥 [TARIFAS_FETCH] EXCEPTION: $e');
      debugPrint('$st');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  @override
  void dispose() {
    _tarifaBaseCtrl.dispose();
    _distBaseCtrl.dispose();
    _porKmCtrl.dispose();
    _porMinCtrl.dispose();
    _horaPicoCtrl.dispose();
    _nocturnoCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregarFotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null) return;
      final path = result.paths.first;
      if (path == null) return;

      setState(() {
        _imagenes
          ..clear()
          ..add(File(path));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la imagen: $e')),
      );
    }
  }

  void _eliminarFotoUnica() {
    if (_imagenes.isEmpty) return;
    setState(() {
      _imagenes.clear();
      _logoUrl = null; // si quiere eliminar el logo existente
    });
  }

  // Wrapper para mostrar overlay mientras corre _guardarTarifas
  Future<void> _submitGuardar() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _guardarTarifas();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _guardarTarifas() async {
    FocusScope.of(context).unfocus();

    double _toDouble(NumberEditingController c) {
      final t = c.text.trim();
      if (t.isEmpty) return 0.0;
      return double.tryParse(t.replaceAll(',', '.')) ?? 0.0;
    }

    if (_servicioSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Elige un servicio')));
      return;
    }
    if (_departamentoSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Elige un departamento')));
      return;
    }

    try {
      // === SUBIR FOTO NUEVA (si la hay) → SOLO guardamos 'logo' ===
      String? logoUrlFinal = _logoUrl; // valor existente por defecto
      if (_imagenes.isNotEmpty) {
        final storage = StorageService();
        final result = await storage.uploadPhotosSmart(
          files: _imagenes,
          folderPath: 'empresas/mujeresalvolante/tarifas',
          nombreFoto: 'logo',
          nombreImgAutomatico: true,
        );

        // Tomamos SOLO la primera URL como logo
        if (result is List<String> && result.isNotEmpty) {
          logoUrlFinal = result.first;
        } else if (result is Map<String, List<String>>) {
          final flat = result.values.expand((e) => e).toList();
          if (flat.isNotEmpty) logoUrlFinal = flat.first;
        }
      }

      // Solo enviamos 'logo' (sin 'fotos')
      final extra = <String, dynamic>{};
      if (logoUrlFinal != null && logoUrlFinal.isNotEmpty) {
        extra['logo'] = logoUrlFinal;
      }

      // === GUARDAR/ACTUALIZAR TARIFAS + LOGO (DocSets.set por dentro) ===
      await guardarTarifas(
        servicio: _servicioSeleccionado!,
        departamento: _departamentoSeleccionado!,
        activo: _servicioActivo,
        tarifaBase: _toDouble(_tarifaBaseCtrl),
        distanciaBase: _toDouble(_distBaseCtrl),
        porKm: _toDouble(_porKmCtrl),
        porMin: _toDouble(_porMinCtrl),
        horaPicoExtra: _toDouble(_horaPicoCtrl),
        nocturno: _toDouble(_nocturnoCtrl),
        comision: _toDouble(_comisionCtrl),
        tramosAero: _tramosAero,
        franjasHoras: _franjasHoras,
        extraFields: extra.isEmpty ? null : extra, // ← solo logo
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Cambios guardados' : 'Tarifas guardadas'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<List<String>> _traerServicios() async {
    final docs = await DocGet.documentosGet(
      rutas: ["servicios_departamentos/servicios_departamentos"],
      nombreMapas: ["Servicios"],
    );
    final data = docs.isNotEmpty ? docs[0]["data"] : null;
    if (data is List) return data.map((e) => e.toString()).toList();
    return <String>[];
  }

  Future<void> _mostrarPickerServicios() async {
    final seleccionado = await mostrarPickerServicios(
      context: context,
      fetchServicios: _traerServicios,
    );
    if (seleccionado != null && mounted) {
      setState(() => _servicioSeleccionado = seleccionado);
      // Si ya hay depto elegido, intenta traer tarifas existentes desde Firestore.
      await _prefillDesdeFirestore();
    }
  }

  Future<List<String>> _traerDepartamentos() async {
    final docs = await DocGet.documentosGet(
      rutas: ["servicios_departamentos/servicios_departamentos"],
      nombreMapas: ["departamentos"],
    );
    final data = docs.isNotEmpty ? docs[0]["data"] : null;
    if (data is List) return data.map((e) => e.toString()).toList();
    return <String>[];
  }

  Future<void> _mostrarPickerDepartamentos() async {
    final seleccionado = await mostrarPickerDepartamentos(
      context: context,
      fetchDepartamentos: _traerDepartamentos,
    );
    if (seleccionado != null && mounted) {
      setState(() => _departamentoSeleccionado = seleccionado);
      // Si ya hay servicio elegido, intenta traer tarifas existentes desde Firestore.
      await _prefillDesdeFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldConBottom(
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: _isEditing ? 'Editar Servicio' : 'Nuevo Servicio',
        backgroundColor: Colors.green,
        systemOverlayIsLight: true,
        textColor: Colors.white,
        hasShadow: false,
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.info,
        onTapDerecha: () => debugPrint('Ajustes'),
      ),
      scrollBody: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Foto única (subida a Storage)
              SinglePhotoCard(
                file: _imagenes.isEmpty ? null : _imagenes.first,
                onAddOrChange: _agregarFotos,
                onRemove: _eliminarFotoUnica,
              ),
              const SizedBox(height: 16),

              ServiceButton(
                title: _servicioSeleccionado == null
                    ? 'Seleccionar servicio. Ej: Taxi, Moto, Flete...'
                    : 'Servicio: $_servicioSeleccionado',
                icon: Icons.local_taxi,
                iconBgColor: Colors.grey,
                iconColor: Colors.white,
                backgroundColor: Colors.white,
                onTap: _mostrarPickerServicios,
              ),
              const SizedBox(height: 10),

              ServiceButton(
                title: _departamentoSeleccionado == null
                    ? 'Seleccionar departamento. Ej: La Paz, Cochabamba...'
                    : '$_departamentoSeleccionado',
                icon: Icons.location_city,
                iconBgColor: Colors.grey,
                iconColor: Colors.white,
                backgroundColor: Colors.white,
                onTap: _mostrarPickerDepartamentos,
              ),

              const SizedBox(height: 16),

              TarifasServicioBox(
                tarifaBaseCtrl: _tarifaBaseCtrl,
                distBaseCtrl: _distBaseCtrl,
                porKmCtrl: _porKmCtrl,
                porMinCtrl: _porMinCtrl,
                horaPicoCtrl: _horaPicoCtrl,
                nocturnoCtrl: _nocturnoCtrl,
                comisionCtrl: _comisionCtrl,
              ),

              const SizedBox(height: 16),
              InfoBox(
                numero: 1,
                titulo: "Servicio Activo",
                initialValue: _servicioActivo,
                onToggle: (v) {
                  setState(() => _servicioActivo = v);
                },
              ),

              const SizedBox(height: 16),

              TramoSection.inputs(
                boxTitle: 'Tarifa Aeropuerto por distancia',
                boxIconTitle: Icons.flight_takeoff,
                boxIconRight: Icons.attach_money,
                introText:
                    'El precio se aplicará según el tramo de distancia. '
                    'Ej.: menor a 10 km → Bs. 40; Menor a 20 km → Bs. 60; etc.',
                rowTitlePrefix: 'Tramo',
                leftLabel: 'Desde (km)',
                rightLabel: 'Precio (Bs.)',
                leftPlaceholder: '0.00',
                rightPlaceholder: '0.00',
                initialTramos: _tramosAero,
                helperBottom: Text(
                  'Ordena los tramos de forma ascendente (10, 20, 30…).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onChange: (items) => setState(() => _tramosAero = items),
              ),

              const SizedBox(height: 10),

              TramoSection.horas(
                boxTitle: 'Horas Pico',
                boxIconTitle: Icons.schedule,
                boxIconRight: Icons.trending_up,
                initialFranjas: _franjasHoras,
                introText:
                    'Define las franjas horarias en las que se aplicará el recargo '
                    'indicado en "Hora pico (extra)".',
                rowTitlePrefix: 'Hora Pico',
                labelDesde: 'Desde',
                labelHasta: 'Hasta',
                helperBottom: Text(
                  'Ejemplos: 23:00–05:00 (cruza medianoche) y 12:01–16:00.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onChange: (franjas) => setState(() => _franjasHoras = franjas),
              ),
            ],
          ),
        ),
      ),
      // ===== Botón fijo con OVERLAY de carga =====
      btnFijoAbajo: Btn_Cargando(
        loading: _loading,
        borde: BtnBorde.borde1, // pill; cambia a borde2/borde3 si quieres
        overlayColor: Colors.grey,
        overlayOpacity: 1.0,
        spinnerColor: Colors.white,
        workingLabel: _isEditing ? 'Guardando cambios...' : 'Guardando...',
        child: Boton1(
          label: _isEditing ? 'Guardar cambios' : 'Crear Servicio',
          color: BotonColor.color1,
          borde: BotonBorde.borde1,
          iconoIzquierdo: hideIconWhenLoading(_loading, Icons.save),
          iconoDerecho: hideIconWhenLoading(_loading, Icons.save),
          onPressed: disableOnLoading(_loading, _submitGuardar),
        ),
      ),
      // backgroundGradient: const LinearGradient(
      //   begin: Alignment.topCenter,
      //   end: Alignment.bottomCenter,
      //   colors: [Colors.lightGreen, Colors.lightGreenAccent],
      // ),
      // colorFondo: Colors.blueGrey,
    );
  }
}

// ===== ServiceButton (igual que antes) =====
class ServiceButton extends StatefulWidget {
  const ServiceButton({
    super.key,
    required this.title,
    required this.icon,
    this.iconBgColor = Colors.white,
    this.iconColor = Colors.blue,
    this.backgroundColor = Colors.blue,
    this.onTap,
    this.height = 50,
  });

  final String title;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final double height;

  @override
  State<ServiceButton> createState() => _ServiceButtonState();
}

class _ServiceButtonState extends State<ServiceButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final elevation = _pressed ? 2.0 : (_hovered ? 8.0 : 5.0);
    final scale = _pressed ? 0.98 : 1.0;

    return Semantics(
      button: true,
      label: widget.title,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          elevation: elevation,
          shadowColor: Colors.black.withOpacity(0.85),
          color: Colors.transparent,
          borderRadius: radius,
          child: ClipRRect(
            borderRadius: radius,
            child: Ink(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.grey, width: 0.4),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    widget.backgroundColor.withOpacity(0.95),
                    widget.backgroundColor,
                  ],
                ),
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: widget.onTap,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                onHover: (v) => setState(() => _hovered = v),
                splashColor: Colors.white.withOpacity(0.20),
                highlightColor: Colors.white.withOpacity(0.08),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      child: ColoredBox(
                        color: widget.iconBgColor,
                        child: Center(
                          child: Icon(
                            widget.icon,
                            color: widget.iconColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.black87.withOpacity(0.9),
                              size: 28,
                            ),
                          ],
                        ),
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
}

/* Ejemplo de uso:
  ServiceBox100(
    title: 'Taxi',
    icon: Icons.local_taxi,
    iconBgColor: Colors.blueGrey,
    iconColor: Colors.white,
    onTap: () => debugPrint('Crear servicio Taxi'),
  ),
*/
