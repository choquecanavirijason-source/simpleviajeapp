import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// Mapbox SDK oficial
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Tu clase de llaves
import 'package:buses2/core/services/config/api_keys.dart';

Future<void> mostrarOfertaRutaModal(
  BuildContext context, {
  required double origenLat,
  required double origenLng,
  required double destinoLat,
  required double destinoLng,
  double? precioSugerido,
  ValueChanged<double>? onEnviarOferta,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.70,
      maxChildSize: 0.98,
      builder: (_, controller) => _OfertaRutaModal(
        origen: Point(coordinates: Position(origenLng, origenLat)),
        destino: Point(coordinates: Position(destinoLng, destinoLat)),
        precioSugerido: precioSugerido,
        onEnviarOferta: onEnviarOferta,
        scrollController: controller,
      ),
    ),
  );
}

class _OfertaRutaModal extends StatefulWidget {
  const _OfertaRutaModal({
    required this.origen,
    required this.destino,
    required this.scrollController,
    this.precioSugerido,
    this.onEnviarOferta,
  });

  final Point origen;
  final Point destino;
  final ScrollController scrollController;
  final double? precioSugerido;
  final ValueChanged<double>? onEnviarOferta;

  @override
  State<_OfertaRutaModal> createState() => _OfertaRutaModalState();
}

class _OfertaRutaModalState extends State<_OfertaRutaModal> {
  late final TextEditingController _ofertaCtrl;
  MapboxMap? _mapbox;
  PolylineAnnotationManager? _polylineMgr;
  CircleAnnotationManager? _circleMgr;
  bool _cargandoRuta = true;

  @override
  void initState() {
    super.initState();
    // Establece el token para el SDK (tu versión usa esto, no resourceOptions)
    try {
      MapboxOptions.setAccessToken(ApiKeys.mapbox);
    } catch (_) {}
    _ofertaCtrl = TextEditingController(
      text: widget.precioSugerido == null ? '' : _fmt(widget.precioSugerido!),
    );
  }

  @override
  void dispose() {
    _ofertaCtrl.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapbox = mapboxMap;

    // � Pequeño delay para asegurar que el sistema de annotations esté listo
    await Future.delayed(const Duration(milliseconds: 300));

    // �👇 FIX: crear managers con retry para evitar crash "No manager found"
    await _ensureManagersReady();
    if (_polylineMgr == null || _circleMgr == null) {
      debugPrint('⚠️ No se pudieron crear annotation managers en oferta modal');
      if (mounted) {
        setState(() => _cargandoRuta = false);
      }
      return;
    }

    // Marcador origen (rojo)
    await _circleMgr!.create(
      CircleAnnotationOptions(
        geometry: widget.origen,
        circleColor: Colors.red.value, // int
        circleRadius: 8.0,
        circleStrokeColor: Colors.white.value, // int
        circleStrokeWidth: 2.0,
      ),
    );
    // Marcador destino (verde)
    await _circleMgr!.create(
      CircleAnnotationOptions(
        geometry: widget.destino,
        circleColor: Colors.green.value,
        circleRadius: 8.0,
        circleStrokeColor: Colors.white.value,
        circleStrokeWidth: 2.0,
      ),
    );

    // Ruta (Mapbox Directions)
    try {
      final coords = await _fetchPolyline(widget.origen, widget.destino);
      if (!mounted) return;

      if (coords.isNotEmpty) {
        await _polylineMgr!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: Colors.blueAccent.value, // int
            lineWidth: 5.0,
            lineOpacity: 1.0,
            // ⚠️ NO existen lineCap/lineJoin en tu versión
          ),
        );
      }

      setState(() => _cargandoRuta = false);
      _fitCameraToPositions([
        widget.origen.coordinates,
        widget.destino.coordinates,
        ...coords,
      ]);
    } catch (e) {
      setState(() => _cargandoRuta = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo trazar la ruta: $e')));
      _fitCameraToPositions([
        widget.origen.coordinates,
        widget.destino.coordinates,
      ]);
    }
  }

  /// Intenta crear los annotation managers con reintentos para evitar race condition.
  Future<void> _ensureManagersReady() async {
    const int maxAttempts = 10; // 🔧 Aumentado de 6 a 10 intentos
    int attempt = 0;
    Object? lastError;

    while ((_polylineMgr == null || _circleMgr == null) &&
        attempt < maxAttempts) {
      try {
        _polylineMgr ??= await _mapbox!.annotations
            .createPolylineAnnotationManager();
        _circleMgr ??= await _mapbox!.annotations
            .createCircleAnnotationManager();
        break;
      } catch (e) {
        lastError = e;
        attempt++;
        await Future.delayed(Duration(milliseconds: 150 * attempt));
      }
    }

    if (_polylineMgr == null || _circleMgr == null) {
      debugPrint(
        '❌ _ensureManagersReady (oferta modal) falló después de $maxAttempts intentos: $lastError',
      );
    }
  }

  Future<void> _fitCameraToPositions(List<Position> pts) async {
    if (_mapbox == null || pts.isEmpty) return;

    // toma el primero como double explícito
    double minLat = (pts.first.lat).toDouble();
    double maxLat = (pts.first.lat).toDouble();
    double minLng = (pts.first.lng).toDouble();
    double maxLng = (pts.first.lng).toDouble();

    for (final p in pts) {
      final double plat = (p.lat).toDouble();
      final double plng = (p.lng).toDouble();

      // math.min/max devuelven num → casteamos a double
      minLat = math.min(minLat, plat).toDouble();
      maxLat = math.max(maxLat, plat).toDouble();
      minLng = math.min(minLng, plng).toDouble();
      maxLng = math.max(maxLng, plng).toDouble();
    }

    final double centerLat = ((minLat + maxLat) / 2.0).toDouble();
    final double centerLng = ((minLng + maxLng) / 2.0).toDouble();
    final center = Position(centerLng, centerLat);

    final double latDiff = (maxLat - minLat).abs().toDouble();
    final double lngDiff = (maxLng - minLng).abs().toDouble();
    final double span = math.max(latDiff, lngDiff).toDouble();

    double zoom;
    if (span < 0.005) {
      zoom = 15.5;
    } else if (span < 0.015) {
      zoom = 14.5;
    } else if (span < 0.05) {
      zoom = 13.5;
    } else if (span < 0.15) {
      zoom = 12.5;
    } else {
      zoom = 11.5;
    }

    await _mapbox!.easeTo(
      CameraOptions(
        center: Point(coordinates: center),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estiloTitulo = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 10),

        // Título + cerrar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Ruta y oferta', style: estiloTitulo),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // MAPA
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: MapWidget(
                  key: const ValueKey('oferta-map'),
                  // ⚠️ En tu versión se usa el token global (initState arriba)
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  cameraOptions: CameraOptions(center: widget.origen, zoom: 14),
                  textureView: true,
                  onMapCreated: _onMapCreated,
                ),
              ),
              if (_cargandoRuta)
                const Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),

        // OFERTA + BOTONES
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16 + 8),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Hacer oferta',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ofertaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\.,]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          prefixText: 'ARS ',
                          hintText: '0.00',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.local_offer_rounded),
                        label: const Text('Hacer oferta'),
                        onPressed: () {
                          final raw = _ofertaCtrl.text
                              .replaceAll(',', '.')
                              .trim();
                          final val = double.tryParse(
                            raw.replaceAll('ARS', '').trim(),
                          );
                          if (val == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Monto inválido')),
                            );
                            return;
                          }
                          widget.onEnviarOferta?.call(val);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== HTTP & POLYLINE =====

  Future<List<Position>> _fetchPolyline(Point origen, Point destino) async {
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/'
        '${origen.coordinates.lng},${origen.coordinates.lat};'
        '${destino.coordinates.lng},${destino.coordinates.lat}'
        '?alternatives=false&geometries=polyline6&overview=full&language=es&access_token=${ApiKeys.mapbox}';

    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) {
      throw 'HTTP ${r.statusCode}: ${r.body}';
    }
    final data = json.decode(r.body) as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return <Position>[];
    final geometry = routes.first['geometry'] as String? ?? '';
    return _decodePolyline6(geometry);
  }

  /// Decodifica polyline precision=6 a lista de Position (lng, lat).
  List<Position> _decodePolyline6(String encoded) {
    final List<Position> points = <Position>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      // ⚠️ Casteo explícito a double
      points.add(Position((lng / 1e6).toDouble(), (lat / 1e6).toDouble()));
    }
    return points;
  }

  String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
}
