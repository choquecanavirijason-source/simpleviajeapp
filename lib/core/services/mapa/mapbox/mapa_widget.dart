import 'package:flutter/material.dart';
import 'package:buses2/core/services/mapa/mapa/map_service.dart';
import 'package:buses2/core/services/mapa/mapbox/mapbox_service.dart';
import 'package:buses2/core/services/mapa/mapbox/taxistas_markers_manager.dart'
    show TaxistaMarkerData;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    show Point, Position;
import 'package:buses2/core/services/mapa/mapa/map_service.dart'
    show RutaInfo, MapService;

/// [Versión 2025-10-10]
/// [v.2.0.0]
/// Para poder escribir encima desde cualquier page.
/// Es el mapa como tal ocupando todo el espacio disponible de la page.
/// No tiene botones ni controles, solo el mapa.
class MapaController {
  final MapService _svc;
  MapaController(this._svc);

  Future<Point> getCameraCenter() => _svc.getCameraCenter();

  Future<void> dibujarRutaDesdeHasta({
    required Point a,
    required Point b,
    BuildContext? context,
  }) => _svc.dibujarRutaDesdeHasta(puntoA: a, puntoB: b, context: context);

  // 👇 Obtenemos los (km y minutos) entre la ruta A → B
  Future<RutaInfo> obtenerMetricasDeRuta({
    required Point a,
    required Point b,
  }) => _svc.obtenerMetricasDeRuta(puntoA: a, puntoB: b);

  // 👇 Helper de (km y minutos) para usar parametros en el page
  Future<RutaInfo> metricasEntre({
    required double aLat,
    required double aLng,
    required double bLat,
    required double bLng,
    bool dibujar = false,
    BuildContext? context,
  }) async {
    final a = Point(coordinates: Position(aLng, aLat)); // (lng, lat)
    final b = Point(coordinates: Position(bLng, bLat));
    if (dibujar) {
      await _svc.dibujarRutaDesdeHasta(puntoA: a, puntoB: b, context: context);
    }
    return _svc.obtenerMetricasDeRuta(puntoA: a, puntoB: b);
  }

  Future<void> agregarPuntoFijo(
    Point punto, {
    Color? fillColor,
    Color? strokeColor,
    double? radius,
    double? strokeWidth,
  }) {
    return _svc.agregarPuntoFijo(
      punto,
      fillColor: fillColor,
      strokeColor: strokeColor,
      radius: radius,
      strokeWidth: strokeWidth,
    );
  }

  Future<void> borrarPuntoFijo() {
    return _svc.borrarPuntoFijo();
  }

  /// Sincroniza markers de taxistas online en el mapa (diff por uid).
  /// Llamar desde un StreamBuilder cada vez que cambie la lista de taxistas.
  Future<void> sincronizarTaxistas(List<TaxistaMarkerData> taxistas) =>
      _svc.sincronizarTaxistas(taxistas);

  /// Borra todos los markers de taxistas.
  Future<void> limpiarTaxistas() => _svc.limpiarTaxistas();

  Future<void> moveTo(double lat, double lng, {double zoom = 15}) =>
      _svc.moveTo(lat, lng, zoom: zoom);
}

class MapaWidget extends StatefulWidget {
  const MapaWidget({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.onMoveStart,
    this.onMoveEnd,
    this.onMapReady,
    this.onUbicacionCambiada,
  });

  final double centerLat;
  final double centerLng;
  final VoidCallback? onMoveStart;
  final VoidCallback? onMoveEnd;
  final void Function(MapaController controller)? onMapReady;
  final void Function(double lat, double lng, String? direccion)?
  onUbicacionCambiada;

  @override
  State<MapaWidget> createState() => _MapaWidgetState();
}

class _MapaWidgetState extends State<MapaWidget> {
  MapService? _svc;
  Widget? _view;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _svc = MapboxService(
      centerLat: widget.centerLat,
      centerLng: widget.centerLng,
    );
    await _svc!.init();
    final v = _svc!.buildMap(
      centerLat: widget.centerLat,
      centerLng: widget.centerLng,
      onMoveStart: widget.onMoveStart,
      onMoveEnd: widget.onMoveEnd,
      onUbicacionCambiada: widget.onUbicacionCambiada,
    );
    if (!mounted) return;
    setState(() => _view = v);
    widget.onMapReady?.call(MapaController(_svc!));
  }

  @override
  void dispose() {
    _svc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _view ?? const Center(child: CircularProgressIndicator());
  }
}

/// Realiza el Trazado del punto A al punto B.
class TrazadoResultado {
  final double bLat;
  final double bLng;

  const TrazadoResultado({required this.bLat, required this.bLng});
}

/// Traza A → B usando Mapbox SIN crear ningún marcador B.
class RutaTrazador {
  /// Si [bLat]/[bLng] vienen nulos, usa el centro de cámara como B.
  static Future<TrazadoResultado?> trazarAyB({
    required MapaController ctrl,
    required BuildContext context,
    required double aLat,
    required double aLng,
    double? bLat,
    double? bLng,
    EdgeInsets? paddingPortrait,
    EdgeInsets? paddingLandscape,
  }) async {
    try {
      // Punto A
      final pA = Point(coordinates: Position(aLng, aLat));

      // Resolver B (si no viene, tomar centro de cámara)
      double resolvedBLat = bLat ?? 0.0;
      double resolvedBLng = bLng ?? 0.0;

      if (bLat == null || bLng == null) {
        final centro = await ctrl
            .getCameraCenter(); // Point con Position(lng,lat)
        final pos = centro.coordinates as Position;
        resolvedBLat = pos.lat.toDouble();
        resolvedBLng = pos.lng.toDouble();
      }

      // Punto B final
      final pB = Point(coordinates: Position(resolvedBLng, resolvedBLat));

      // Dibujar ruta A → B (sin tocar cámara si así está implementado)
      await ctrl.dibujarRutaDesdeHasta(a: pA, b: pB, context: context);

      return TrazadoResultado(bLat: resolvedBLat, bLng: resolvedBLng);
    } catch (e) {
      debugPrint('❌ Error en RutaTrazador.trazarAyB: $e');
      return null;
    }
  }
}
