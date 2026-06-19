import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:buses2/core/utils/string_extensions.dart';
import 'package:buses2/features/mapa_destino/data/models/servicio_empresa_model.dart';
import 'package:buses2/features/mapa_destino/service/servicios.dart';

import 'package:buses2/shared/widgets/modal_inferior/modal_inferior2.dart';
import 'package:buses2/features/mapa_destino/widgets/direccion.dart';
import '../service/servicios_de_empresa.dart';
import '../service/tarifas.dart';

// ✅ IMPORTA tu normalizador
import 'package:buses2/core/utils/particionarDireccion.dart'
    show normalizarDepartamento;

// ✅ TARIFA CARD (la que me mostraste)
import 'package:buses2/features/mapa_destino/widgets/tarifa_control_card.dart';

// 🔹 lector genérico de Firestore
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';

// ==================== BRAND COLORS ====================
const kBrandGreen = Color(0xFF4CB050);

class ModalInferior1 extends StatefulWidget {
  const ModalInferior1({
    super.key,
    required this.controller,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    // Punto A
    required this.puntoALat,
    required this.puntoALng,
    required this.puntoACalle,
    required this.puntoACiudad,
    required this.puntoAPais,
    required this.puntoADepartamento, // 👈 SOLO este se usa para tarifas
    // Punto B
    required this.puntoBLat,
    required this.puntoBLng,
    required this.puntoBCalle,
    required this.puntoBCiudad,
    required this.puntoBPais,

    // ✅ NUEVO: para pintar la card de tarifa dentro de este modal
    this.mostrarTarifaCard = false,
    this.precioEstimado,
    this.tarifa = 0,
    this.onTarifaChanged,

    // Callback opcional
    this.onComboChange,
    this.distanciaKm,
    this.minutos,
  });

  final DraggableScrollableController controller;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  // Punto A
  final double? puntoALat;
  final double? puntoALng;
  final String? puntoACalle;
  final String? puntoACiudad;
  final String? puntoAPais;
  final String? puntoADepartamento;

  // Punto B
  final double? puntoBLat;
  final double? puntoBLng;
  final String? puntoBCalle;
  final String? puntoBCiudad;
  final String? puntoBPais;

  /// Callback cuando se obtiene el combo de tarifas del servicio seleccionado.
  final void Function(TarifaHorasPicoAeropuerto combo, String servicio)?
  onComboChange;

  // Card de tarifa
  final bool mostrarTarifaCard;
  final double? precioEstimado;
  final num tarifa;
  final ValueChanged<num>? onTarifaChanged;

  // Distancia del trayecto
  final double? distanciaKm;
  final int? minutos;

  @override
  State<ModalInferior1> createState() => _ModalInferior1State();
}

/// Metadatos de un servicio guardado en Firestore
class ServiceMeta {
  final String firestoreKey; // clave real del mapa en Firestore
  final String label; // nombre visible
  final String? imageUrl; // logo/foto/iconoUrl
  final bool activo; // si false → ocultar

  const ServiceMeta({
    required this.firestoreKey,
    required this.label,
    this.imageUrl,
    required this.activo,
  });
}

class _ModalInferior1State extends State<ModalInferior1>
    with AutomaticKeepAliveClientMixin {
  // Empresa fija
  static const String _empresaFija = 'mujeresalvolante';

  // controlador de selección (exclusiva)
  final ServiceSelectionController _servicesCtrl = ServiceSelectionController();

  // cache metadatos por fingerprint
  String _lastMetaKey = '';
  Map<String, ServiceMeta> _metaByLabel = const {};

  // para onComboChange de tarifas
  String? _lastSentKey;

  // ───────── Provincias argentinas: lista canónica + bounding boxes ─────────
  //
  // Estrategia: las coordenadas son MUCHO más confiables que el string que
  // devuelve el reverse-geocoding (que puede ser un partido, una localidad,
  // un barrio, etc.). Si el lat/lng caen dentro de la provincia X, sabemos
  // con certeza que la provincia es X, sin importar qué texto haya devuelto
  // Google ("Belén de Escobar", "Manuel Alberti", "Quilmes" → todos mapean
  // a "Buenos Aires").
  //
  // Las bboxes son aproximadas (rectángulos), suficientes para casi todos
  // los casos. CABA se chequea antes que Buenos Aires (CABA está dentro de
  // la bbox de la provincia).

  /// Las 24 provincias canónicas, en el mismo orden y con los mismos nombres
  /// que los documentos `Argentina__{X}` en Firestore.
  static const List<String> _provinciasArgentinas = [
    'Buenos Aires',
    'Ciudad Autónoma de Buenos Aires',
    'Catamarca',
    'Chaco',
    'Chubut',
    'Córdoba',
    'Corrientes',
    'Entre Ríos',
    'Formosa',
    'Jujuy',
    'La Pampa',
    'La Rioja',
    'Mendoza',
    'Misiones',
    'Neuquén',
    'Río Negro',
    'Salta',
    'San Juan',
    'San Luis',
    'Santa Cruz',
    'Santa Fe',
    'Santiago del Estero',
    'Tierra del Fuego',
    'Tucumán',
  ];

  /// Bounding boxes [latMin, latMax, lngMin, lngMax] por provincia.
  /// CABA va PRIMERO porque está geométricamente dentro de Buenos Aires.
  static const List<List<double>> _bboxesArgentina = [
    // CABA (chequear PRIMERO)
    [-34.71, -34.53, -58.55, -58.34],
    // Buenos Aires (provincia, excluyendo CABA mediante orden)
    [-41.05, -33.27, -63.40, -56.66],
    // Catamarca
    [-29.10, -25.20, -69.10, -64.55],
    // Chaco
    [-28.10, -24.10, -63.40, -58.30],
    // Chubut
    [-46.10, -42.10, -72.10, -63.60],
    // Córdoba
    [-35.10, -29.45, -65.90, -61.75],
    // Corrientes
    [-30.85, -27.20, -59.70, -55.60],
    // Entre Ríos
    [-34.10, -30.10, -60.95, -57.80],
    // Formosa
    [-26.95, -22.30, -62.40, -57.55],
    // Jujuy
    [-24.65, -21.70, -67.30, -63.95],
    // La Pampa
    [-39.30, -34.75, -68.30, -62.35],
    // La Rioja
    [-31.95, -27.85, -69.65, -65.65],
    // Mendoza
    [-37.65, -31.85, -70.65, -66.40],
    // Misiones
    [-28.20, -25.45, -56.45, -53.60],
    // Neuquén
    [-41.10, -36.30, -71.95, -68.10],
    // Río Negro
    [-42.10, -37.40, -71.95, -62.80],
    // Salta
    [-26.55, -22.05, -68.65, -62.20],
    // San Juan
    [-32.65, -28.40, -70.65, -66.95],
    // San Luis
    [-35.80, -31.95, -67.30, -64.95],
    // Santa Cruz
    [-52.40, -45.95, -73.65, -65.80],
    // Santa Fe
    [-34.15, -27.95, -63.40, -58.85],
    // Santiago del Estero
    [-30.70, -25.55, -65.45, -61.65],
    // Tierra del Fuego
    [-55.10, -52.65, -68.70, -63.75],
    // Tucumán
    [-28.10, -26.05, -66.50, -64.45],
  ];

  /// Quita acentos para comparación de strings.
  String _sinAcentos(String s) {
    const map = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  /// Intenta matchear `raw` contra la lista canónica de provincias argentinas
  /// (ignorando mayúsculas y acentos). Devuelve el nombre canónico o null.
  String? _matchProvinciaAR(String raw) {
    if (raw.isEmpty) return null;
    final target = _sinAcentos(raw.toLowerCase().trim());
    for (final p in _provinciasArgentinas) {
      final pNorm = _sinAcentos(p.toLowerCase());
      if (target == pNorm || target.contains(pNorm) || pNorm.contains(target)) {
        return p;
      }
    }
    return null;
  }

  /// Devuelve la provincia argentina cuyas coords contienen el punto, o null.
  String? _provinciaArgentinaPorCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    for (int i = 0; i < _bboxesArgentina.length; i++) {
      final b = _bboxesArgentina[i];
      if (lat >= b[0] && lat <= b[1] && lng >= b[2] && lng <= b[3]) {
        return _provinciasArgentinas[i];
      }
    }
    return null;
  }

  bool get _esArgentina {
    final paisLow = (widget.puntoAPais ?? '').toLowerCase();
    if (paisLow.contains('argentina') ||
        paisLow == 'ar' ||
        paisLow == 'arg') {
      return true;
    }
    // Si las coordenadas caen dentro de cualquier provincia argentina,
    // también consideramos que es Argentina (cubre casos donde el campo
    // país viene raro o vacío).
    return _provinciaArgentinaPorCoords(
          widget.puntoALat,
          widget.puntoALng,
        ) !=
        null;
  }

  /// ✅ Clave de "departamento/provincia" para buscar tarifas.
  ///
  /// Bolivia: usa `puntoADepartamento` (fallback `puntoACiudad`).
  /// Argentina: prioriza las coordenadas (más confiable). Si no hay coords
  ///   válidas, matchea el texto contra la lista canónica de 24 provincias.
  String get _departamentoA {
    if (_esArgentina) {
      // 1) bbox por coordenadas (gana siempre que estén disponibles)
      final byCoords = _provinciaArgentinaPorCoords(
        widget.puntoALat,
        widget.puntoALng,
      );
      if (byCoords != null) return byCoords;

      // 2) matchear puntoADepartamento contra la lista canónica
      final depto = normalizarDepartamento(
        (widget.puntoADepartamento ?? '').trim(),
      );
      final m1 = _matchProvinciaAR(depto);
      if (m1 != null) return m1;

      // 3) matchear puntoACiudad
      final ciudad = normalizarDepartamento(
        (widget.puntoACiudad ?? '').trim(),
      );
      final m2 = _matchProvinciaAR(ciudad);
      if (m2 != null) return m2;

      // 4) último recurso: devolver el depto crudo normalizado
      return depto;
    }

    // Bolivia y otros países: comportamiento original
    final depto = (widget.puntoADepartamento ?? '').trim();
    final raw =
        depto.isNotEmpty ? depto : (widget.puntoACiudad ?? '').trim();
    return normalizarDepartamento(raw).trim();
  }

  /// ✅ País normalizado para construir el doc ID `{Pais}__{Departamento}`.
  String get _paisA {
    if (_esArgentina) return 'Argentina';

    final raw = (widget.puntoAPais ?? '').trim();
    if (raw.isEmpty) return '';

    final low = raw.toLowerCase();
    if (low.contains('bolivia') || low == 'bo' || low == 'bol') {
      return 'Bolivia';
    }

    // Fallback: último segmento separado por coma.
    final partes = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return partes.isNotEmpty ? partes.last : raw;
  }

  List<String> _docIdCandidates({required String departamento, String? pais}) {
    String titleCase(String value) {
      final parts = value
          .trim()
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      return parts
          .map(
            (w) => w.length <= 1
                ? w.toUpperCase()
                : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
          )
          .join(' ');
    }

    final depRaw = departamento.trim();
    final depLow = depRaw.toLowerCase();
    final depTitle = titleCase(depRaw);
    final out = <String>[];

    void addId(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty || out.contains(s)) return;
      out.add(s);
    }

    final pRaw = (pais ?? '').trim();
    if (pRaw.isNotEmpty) {
      final pLow = pRaw.toLowerCase();
      final pTitle = titleCase(pRaw);

      addId('${pRaw}__$depRaw');
      addId('${pTitle}__$depTitle');
      addId('${pRaw}__$depTitle');
      addId('${pTitle}__$depRaw');
      addId('${pLow}__$depLow');

      addId('${pRaw}_$depRaw');
      addId('${pTitle}_$depTitle');
      addId('${pRaw}_$depTitle');
      addId('${pTitle}_$depRaw');
      addId('${pLow}_$depLow');
    }

    addId(depRaw);
    addId(depLow);
    addId(depTitle);
    return out;
  }

  @override
  void dispose() {
    _servicesCtrl.dispose();
    super.dispose();
  }

  // ===== helpers =====
  String _mapKey(String s) => s
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^\w\-]'), '')
      .toLowerCase();

  String? _pickImageUrl(Map<String, dynamic> raw) {
    // prioridad: logo → logoUrl → foto → iconoUrl → fotos[0] → media.logo
    String getS(dynamic v) => (v is String) ? v.trim() : '';

    String? url = getS(raw['logo']).isNotEmpty ? getS(raw['logo']) : null;
    url ??= getS(raw['logoUrl']).isNotEmpty ? getS(raw['logoUrl']) : null;
    url ??= getS(raw['foto']).isNotEmpty ? getS(raw['foto']) : null;
    url ??= getS(raw['iconoUrl']).isNotEmpty ? getS(raw['iconoUrl']) : null;

    if (url == null || url.isEmpty) {
      final fotos = raw['fotos'];
      if (fotos is List && fotos.isNotEmpty && fotos.first is String) {
        final f = (fotos.first as String).trim();
        if (f.isNotEmpty) url = f;
      }
    }
    if ((url == null || url.isEmpty) && raw['media'] is Map) {
      final m = raw['media'] as Map;
      final f = (m['logo'] ?? '').toString().trim();
      if (f.isNotEmpty) url = f;
    }

    return (url != null && url.startsWith('http')) ? url : url;
  }

  /// Lee doc `empresas/{empresaId}/tarifas/{departamento}` y devuelve metadatos por etiqueta visible
  Future<Map<String, ServiceMeta>> _traerMetasServicios({
    required String empresaId,
    required String departamento,
    String? pais,
    required List<String> visibleLabels,
  }) async {
    try {
      final docIds = _docIdCandidates(departamento: departamento, pais: pais);
      debugPrint('🔍 [Metas] candidatos docId: $docIds');

      List<dynamic> docs = const [];
      String? docUsado;
      for (final docId in docIds) {
        final ruta = 'empresas/$empresaId/tarifas/$docId';
        debugPrint('🔍 [Metas] Consultando: $ruta');
        final intento = await DocGet.documentosGet(rutas: [ruta]);
        if (intento.isNotEmpty && intento.first['data'] != null) {
          docs = intento;
          docUsado = docId;
          break;
        }
      }

      if (docs.isEmpty) {
        debugPrint('⚠️ [Metas] sin documento para candidatos: $docIds');
        return {};
      }
      debugPrint('✅ [Metas] documento usado: $docUsado');

      final doc = docs.first;
      final data = (doc['data'] ?? {}) as Map<String, dynamic>;

      final out = <String, ServiceMeta>{};

      for (final label in visibleLabels) {
        final k1 = label;
        final k2 = _mapKey(label);

        Map<String, dynamic>? raw;
        String? realKey;

        final v1 = data[k1];
        if (v1 is Map<String, dynamic>) {
          raw = v1;
          realKey = k1;
        } else {
          final v2 = data[k2];
          if (v2 is Map<String, dynamic>) {
            raw = v2;
            realKey = k2;
          }
        }

        if (raw != null) {
          final activo = raw['activo'] is bool ? raw['activo'] as bool : true;
          final img = _pickImageUrl(raw);

          out[label] = ServiceMeta(
            firestoreKey: realKey!,
            label: (raw['servicio'] ?? label).toString(),
            imageUrl: img,
            activo: activo,
          );
        } else {
          out[label] = ServiceMeta(
            firestoreKey: k2,
            label: label,
            imageUrl: null,
            activo: true,
          );
        }
      }

      return out;
    } catch (e) {
      debugPrint('Error trayendo metas de servicios: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keepAlive

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: ModalInferior2(
          controller: widget.controller,
          initialChildSize: widget.initialChildSize,
          minChildSize: widget.minChildSize,
          maxChildSize: widget.maxChildSize,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              children: [
                const SizedBox(height: 8),
                Text(
                  'Destino',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
                Divider(color: Colors.grey[400], thickness: 1),
                const SizedBox(height: 4),
                Text(
                  'Servicios disponibles',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),

                // === Servicios SOLO por DEPARTAMENTO (NORMALIZADO) ===
                Builder(
                  builder: (context) {
                    final raw = (widget.puntoADepartamento ?? '').trim();
                    final deptoNorm = _departamentoA;

                    debugPrint(
                      '🏛️ ModalInferior1: dept RAW="$raw" | dept NORM="$deptoNorm" | ciudad="${widget.puntoACiudad}"',
                    );
                    debugPrint(
                      '🏛️ ModalInferior1: pais RAW="${widget.puntoAPais}" | pais NORM="$_paisA" → buscando en empresas/$_empresaFija/tarifas/${_paisA}__$deptoNorm',
                    );

                    if (deptoNorm.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No se detectó el DEPARTAMENTO del pasajero (Punto A). No se pueden cargar servicios/tarifas.',
                        ),
                      );  
                    }

                    return ServiciosDeEmpresa(
                      departamento: deptoNorm, 
                      pais: _paisA,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (snap.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Error: ${snap.error}'),
                          );
                        }

                        final servicios =
                            snap.data ?? const <ServicioEmpresa>[];
                        final labels = servicios
                            .map((e) => e.label.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();

                        if (labels.isEmpty) {
                          return Text(
                            'No hay servicios disponibles en este departamento ($deptoNorm).',
                          );
                        }

                        // fingerprint: empresa|departamento|labels
                        final fp =
                            '$_empresaFija|$deptoNorm|${labels.join('|')}';
                        final needMeta = _lastMetaKey != fp;

                        final futureMetas = needMeta
                            ? _traerMetasServicios(
                                empresaId: _empresaFija,
                                departamento: deptoNorm, // ✅ normalizado
                                pais: _paisA,
                                visibleLabels: labels,
                              )
                            : Future.value(_metaByLabel);

                        return FutureBuilder<Map<String, ServiceMeta>>(
                          future: futureMetas,
                          builder: (context, metaSnap) {
                            if (metaSnap.connectionState ==
                                    ConnectionState.waiting &&
                                needMeta) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(),
                              );
                            }

                            if (metaSnap.hasData && needMeta) {
                              _metaByLabel = metaSnap.data ?? {};
                              _lastMetaKey = fp;
                            }

                            // filtrar por activo:true
                            final visibles = labels.where((label) {
                              final m = _metaByLabel[label];
                              return m == null ? true : m.activo;
                            }).toList();

                            if (visibles.isEmpty) {
                              return const Text(
                                'No hay servicios activos en este departamento.',
                              );
                            }

                            // actualizar selección/orden
                            final fpVisible =
                                'visible|$fp|${visibles.join('|')}';
                            if (_servicesCtrl.fingerprint != fpVisible) {
                              _servicesCtrl.setServices(
                                visibles,
                                externalFingerprint: fpVisible,
                              );
                            }

                            return AnimatedBuilder(
                              animation: _servicesCtrl,
                              builder: (context, _) {
                                final seleccionado = _servicesCtrl.selected;

                                // nombre visible del servicio seleccionado
                                final selectedName = (seleccionado != null)
                                    ? (_metaByLabel[seleccionado]?.label ??
                                          seleccionado)
                                    : '';

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 120,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        itemCount: _servicesCtrl.items.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 10),
                                        itemBuilder: (context, idx) {
                                          final label =
                                              _servicesCtrl.items[idx];
                                          final meta = _metaByLabel[label];
                                          final isSelected =
                                              (seleccionado == label);

                                          final Widget imageWidget =
                                              (meta?.imageUrl != null &&
                                                  meta!.imageUrl!.isNotEmpty)
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.network(
                                                    meta.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    width: 56,
                                                    height: 56,
                                                    loadingBuilder:
                                                        (c, w, ev) => ev == null
                                                        ? w
                                                        : const SizedBox(
                                                            width: 22,
                                                            height: 22,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          ),
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => const Icon(
                                                          Icons.broken_image,
                                                        ),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.image_not_supported,
                                                );

                                          return _ServiceCard(
                                            label: meta?.label ?? label,
                                            isSelected: isSelected,
                                            onTap: () {
                                              _servicesCtrl.select(label);
                                            },
                                            image: imageWidget,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Chip distancia / tiempo del trayecto
                                    if (widget.distanciaKm != null || widget.minutos != null) ...[
                                      Row(
                                        children: [
                                          if (widget.distanciaKm != null)
                                            _TripChip(
                                              icono: Icons.straighten,
                                              texto: '${widget.distanciaKm!.toStringAsFixed(1)} km',
                                            ),
                                          if (widget.distanciaKm != null && widget.minutos != null)
                                            const SizedBox(width: 8),
                                          if (widget.minutos != null)
                                            _TripChip(
                                              icono: Icons.access_time,
                                              texto: '${widget.minutos!} min',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // ✅ TARIFA: directo del servicio ya cargado
                                    // (mismo objeto que pintó la tarjeta), sin
                                    // segunda lectura ni re-match por nombre.
                                    if (seleccionado != null)
                                      Builder(
                                        builder: (context) {
                                          final selNorm =
                                              normalizarNombreServicio(
                                                seleccionado,
                                              );
                                          ServicioEmpresa? servSel;
                                          for (final s in servicios) {
                                            if (normalizarNombreServicio(
                                                      s.label,
                                                    ) ==
                                                    selNorm ||
                                                normalizarNombreServicio(s.id) ==
                                                    selNorm) {
                                              servSel = s;
                                              break;
                                            }
                                          }

                                          if (servSel == null ||
                                              servSel.tarifas == null) {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 6,
                                              ),
                                              child: Text(
                                                'No se encontró tarifa para este servicio en este departamento.',
                                              ),
                                            );
                                          }

                                          final sendKey =
                                              '$_empresaFija|$deptoNorm|$seleccionado';
                                          if (_lastSentKey != sendKey) {
                                            _lastSentKey = sendKey;
                                            final combo =
                                                comboDesdeServicioEmpresa(
                                                  servSel,
                                                );
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  widget.onComboChange?.call(
                                                    combo,
                                                    seleccionado,
                                                  );
                                                });
                                          }

                                          // Mostrar información de precios
                                          final tarifa = servSel.tarifas!;
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Tarifas del servicio',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                _PrecioItem(
                                                  icono: Icons.attach_money,
                                                  label: 'Tarifa base',
                                                  valor:
                                                      'ARS ${tarifa.tarifaBase.toStringAsFixed(2)}',
                                                ),
                                                const SizedBox(height: 4),
                                                _PrecioItem(
                                                  icono: Icons.straighten,
                                                  label: 'Por kilómetro',
                                                  valor:
                                                      'ARS ${tarifa.porKm.toStringAsFixed(2)}',
                                                ),
                                                const SizedBox(height: 4),
                                                _PrecioItem(
                                                  icono: Icons.access_time,
                                                  label: 'Por minuto',
                                                  valor:
                                                      'ARS ${tarifa.porMin.toStringAsFixed(2)}',
                                                ),
                                                if (tarifa.horaPicoExtra > 0) ...[
                                                  const SizedBox(height: 4),
                                                  _PrecioItem(
                                                    icono: Icons.trending_up,
                                                    label: 'Hora pico (extra)',
                                                    valor:
                                                        'ARS ${tarifa.horaPicoExtra.toStringAsFixed(0)}',
                                                  ),
                                                ],
                                                if (tarifa.nocturno > 0) ...[
                                                  const SizedBox(height: 4),
                                                  _PrecioItem(
                                                    icono: Icons.nightlight_round,
                                                    label: 'Recargo nocturno',
                                                    valor:
                                                        'ARS ${tarifa.nocturno.toStringAsFixed(0)}',
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                    // ✅ NUEVO: CARD TARIFA (como tu screenshot 2)
                                    if (widget.mostrarTarifaCard &&
                                        seleccionado != null) ...[
                                      const SizedBox(height: 10),
                                      TarifaControlCard(
                                        servicio: selectedName,
                                        precioRecomendado:
                                            (widget.precioEstimado ?? 0)
                                                .toDouble(),
                                        valor: widget.tarifa,
                                        moneda: 'ARS',
                                        step: 50,
                                        min: 0,
                                        max: 999999,
                                        accentColor: Colors.green,
                                        onChanged: widget.onTarifaChanged,
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// Card compacta: imagen arriba + nombre abajo
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.image,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget image;

  static const Color kGreen = kBrandGreen;
  static const Color kGreenSoft = Color(0x144CB050);
  static const Color kBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: kGreen.withOpacity(.15),
        highlightColor: kGreen.withOpacity(.08),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? kGreen : kBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: isSelected ? kGreen.withOpacity(.18) : Colors.black12,
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: MediaQuery(
            data: media.copyWith(
              textScaleFactor: media.textScaleFactor.clamp(1.0, 1.10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(.18)
                        : kGreenSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: image,
                ),
                const SizedBox(height: 6),
                Text(
                  label.toTitleCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Controla orden y selección de servicios (exclusiva)
class ServiceSelectionController extends ChangeNotifier {
  List<String> _ordered = const [];
  String? _selected;
  String _fingerprint = '';

  List<String> get items => _ordered;
  String? get selected => _selected;
  String get fingerprint => _fingerprint;

  void setServices(List<String> raw, {String? externalFingerprint}) {
    final base = raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // ✅ prioridad #1: mujeres_al_volante
    String? mujeresAlVolante;

    bool isMujeresAlVolante(String s) {
      final l = s.trim().toLowerCase();

      // "mujeres_al_volante"
      if (l == 'mujeres_al_volante') return true;

      // "mujeresalvolante"
      if (l == 'mujeresalvolante') return true;

      // "mujeres al volante" => "mujeres_al_volante"
      if (l.replaceAll(' ', '_') == 'mujeres_al_volante') return true;

      // variantes con "_" o espacios mezclados
      if (l.replaceAll(RegExp(r'[\s_]+'), '') == 'mujeresalvolante')
        return true;

      return false;
    }

    for (final s in base) {
      if (isMujeresAlVolante(s)) {
        mujeresAlVolante = s;
        break;
      }
    }

    // ✅ prioridad #2: taxi (exacto)
    String? taxi;
    for (final s in base) {
      if (s.toLowerCase() == 'taxi') {
        taxi = s;
        break;
      }
    }

    // ✅ prioridad #3: moto (contiene "moto")
    String? moto;
    for (final s in base) {
      final l = s.toLowerCase();
      if (l.contains('moto')) {
        moto = s;
        break;
      }
    }

    // ✅ construir orden final
    final ordered = <String>[];
    if (mujeresAlVolante != null) ordered.add(mujeresAlVolante);
    if (taxi != null && taxi != mujeresAlVolante) ordered.add(taxi);
    if (moto != null && moto != taxi && moto != mujeresAlVolante)
      ordered.add(moto);

    for (final s in base) {
      if (s != mujeresAlVolante && s != taxi && s != moto) {
        ordered.add(s);
      }
    }

    final fp = externalFingerprint ?? ordered.join('|');
    final selectionStillValid =
        _selected != null && ordered.contains(_selected);
    final onlyFingerprintSame = (fp == _fingerprint) && selectionStillValid;
    if (onlyFingerprintSame) return;

    _ordered = ordered;
    _fingerprint = fp;

    // ✅ selección por defecto: mujeres_al_volante → taxi → moto → primero
    if (!selectionStillValid) {
      _selected =
          mujeresAlVolante ??
          taxi ??
          moto ??
          (_ordered.isNotEmpty ? _ordered.first : null);
    }
    notifyListeners();
  }

  void select(String label) {
    if (_selected == label) return;
    _selected = label;
    notifyListeners();
  }
}

// Widget auxiliar para mostrar items de precio
class _PrecioItem extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;

  const _PrecioItem({
    required this.icono,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 16, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(
          valor,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.green.shade700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _TripChip extends StatelessWidget {
  const _TripChip({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
