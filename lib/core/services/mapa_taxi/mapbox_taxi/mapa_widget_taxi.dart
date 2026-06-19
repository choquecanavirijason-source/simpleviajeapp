import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    as mb
    show MapboxMap, Point, Position;
import 'package:buses2/core/services/mapa_taxi/mapa_taxi/map_service_taxi.dart'
    show RutaInfo, MapService;
import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/mapbox_service_taxi.dart';
import 'package:buses2/core/services/mapa_taxi/mapbox_taxi/circuloPuntoA_taxi.dart'
    show PuntoAStyle;

/// [Versión 2025-11-24]
/// - añade lock/cola en dibujarRutaDesdeHasta para evitar duplicados.
/// - mantiene API intacta.
class MapaController {
  final MapService _svc;
  MapaController(this._svc);

  // ======= listeners y map crudo (wrappers tolerantes) =======

  void addOnStyleLoadedListener(VoidCallback cb) {
    try {
      final dyn = _svc as dynamic;
      final fn = dyn.addOnStyleLoadedListener as void Function(VoidCallback)?;
      fn?.call(cb);
    } catch (_) {}
  }

  void addOnMapIdleListener(VoidCallback cb) {
    try {
      final dyn = _svc as dynamic;
      final fn = dyn.addOnMapIdleListener as void Function(VoidCallback)?;
      fn?.call(cb);
    } catch (_) {}
  }

  mb.MapboxMap? get rawMapboxMap {
    try {
      final dyn = _svc as dynamic;
      return dyn.rawMapboxMap as mb.MapboxMap?;
    } catch (_) {
      return null;
    }
  }

  // ===================== API existente =====================

  Future<mb.Point> getCameraCenter() => _svc.getCameraCenter();

  // ✅ Lock simple para serializar trazados
  Completer<void>? _routeLock;

  Future<void> _withRouteLock(Future<void> Function() job) async {
    while (_routeLock != null) {
      try {
        await _routeLock!.future;
      } catch (_) {}
    }
    _routeLock = Completer<void>();
    try {
      await job();
    } finally {
      _routeLock?.complete();
      _routeLock = null;
    }
  }

  /// Dibuja la ruta A→B y (opcional) ajusta la cámara con padding.
  /// ✅ Serializado para evitar doble creación de fuentes.
  Future<void> dibujarRutaDesdeHasta({
    required mb.Point a,
    required mb.Point b,
    BuildContext? context,
    EdgeInsets? cameraPadding,
    bool autoClearFirst = false, // 👈 nuevo
  }) async {
    await _withRouteLock(() async {
      if (autoClearFirst) {
        await limpiarRuta();
      }
      await _svc.dibujarRutaDesdeHasta(
        puntoA: a,
        puntoB: b,
        context: context,
        cameraPadding: cameraPadding,
      );
    });
  }

  /// ❗ Limpia capa/source de la ruta si existen.
  Future<void> limpiarRuta() async {
    try {
      if (_svc is MapboxService) {
        await (_svc as MapboxService).limpiarRuta();
        return;
      }
      final dyn = _svc as dynamic;
      final fn = dyn.limpiarRuta as Future<void> Function()?;
      await fn?.call();
    } catch (_) {}
  }

  Future<void> borrarRuta() => limpiarRuta();
  Future<void> clearRoute() => limpiarRuta();
  Future<void> removeRoute() => limpiarRuta();

  Future<void> limpiarRutaConFallback({
    required mb.Point anyPoint,
    BuildContext? context,
  }) async {
    await limpiarRuta();
    try {
      await _svc.dibujarRutaDesdeHasta(
        puntoA: anyPoint,
        puntoB: anyPoint,
        context: context,
      );
    } catch (_) {}
  }

  Future<RutaInfo> obtenerMetricasDeRuta({
    required mb.Point a,
    required mb.Point b,
  }) => _svc.obtenerMetricasDeRuta(puntoA: a, puntoB: b);

  Future<RutaInfo> metricasEntre({
    required double aLat,
    required double aLng,
    required double bLat,
    required double bLng,
    bool dibujar = false,
    BuildContext? context,
    EdgeInsets? cameraPadding,
  }) async {
    final a = mb.Point(coordinates: mb.Position(aLng, aLat));
    final b = mb.Point(coordinates: mb.Position(bLng, bLat));

    if (dibujar) {
      await limpiarRuta();
      await dibujarRutaDesdeHasta(
        a: a,
        b: b,
        context: context,
        cameraPadding: cameraPadding,
      );
    }
    return _svc.obtenerMetricasDeRuta(puntoA: a, puntoB: b);
  }

  Future<void> agregarPuntoFijo(
    mb.Point punto, {
    Color? fillColor,
    Color? strokeColor,
    double? radius,
    double? strokeWidth,
    String? label,
  }) {
    return _svc.agregarPuntoFijo(
      punto,
      fillColor: fillColor,
      strokeColor: strokeColor,
      radius: radius,
      strokeWidth: strokeWidth,
    );
  }

  Future<void> borrarPuntoFijo() => _svc.borrarPuntoFijo();
  Future<void> borrarUltimoPuntoFijo() => _svc.borrarUltimoPuntoFijo();
  Future<void> moveTo(double lat, double lng, {double zoom = 15}) =>
      _svc.moveTo(lat, lng, zoom: zoom);
}

class MapaWidget extends StatefulWidget {
  final PuntoAStyle puntoA;
  const MapaWidget({
    super.key,
    this.puntoA = PuntoAStyle.simple,
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
      puntoAStyle: widget.puntoA,
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

// ==== Helpers de trazado sin crear marcador B ====

class TrazadoResultado {
  final double bLat;
  final double bLng;
  const TrazadoResultado({required this.bLat, required this.bLng});
}

class RutaTrazador {
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
      final media = MediaQuery.of(context);
      final isPortrait = media.orientation == Orientation.portrait;
      final cameraPadding = isPortrait ? paddingPortrait : paddingLandscape;

      final pA = mb.Point(coordinates: mb.Position(aLng, aLat));

      double resolvedBLat = bLat ?? 0.0;
      double resolvedBLng = bLng ?? 0.0;

      if (bLat == null || bLng == null) {
        final centro = await ctrl.getCameraCenter();
        final pos = centro.coordinates as mb.Position;
        resolvedBLat = pos.lat.toDouble();
        resolvedBLng = pos.lng.toDouble();
      }

      final pB = mb.Point(coordinates: mb.Position(resolvedBLng, resolvedBLat));

      await ctrl.dibujarRutaDesdeHasta(
        a: pA,
        b: pB,
        context: context,
        cameraPadding: cameraPadding,
        autoClearFirst: true, // ✅ ahora lo hace dentro del lock
      );

      return TrazadoResultado(bLat: resolvedBLat, bLng: resolvedBLng);
    } catch (e) {
      debugPrint('❌ Error en RutaTrazador.trazarAyB: $e');
      return null;
    }
  }
}
