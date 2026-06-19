// lib/core/services/mapa_taxi/mapbox_taxi/mapbox_service_taxi.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:buses2/core/services/mapa_taxi/mapa_taxi/map_service_taxi.dart';

import 'circuloPuntoA_taxi.dart'
    show
        PuntoAStyle,
        IUserCircleManager,
        UserCircleManager,
        RadarUserCircleManager;
import 'circuloPunto_taxi.dart' show PuntoFijoCircleManager;
import './km_min_taxi.dart' show MapboxDirectionsClient;
import '../../mapa/route_cache_manager.dart';

class MapboxService implements MapService {
  MapboxMap? _map;
  Timer? _debounce;

  double? _initialLat;
  double? _initialLng;

  bool _isInitialized = false;
  bool _wasMoving = false;

  IUserCircleManager? _userCircleManager;
  PuntoFijoCircleManager? _puntoFijoMgr;
  MapboxDirectionsClient? _dirClient;

  final PuntoAStyle puntoAStyle;

  int _idleToken = 0;

  // ⭐ Control de rutas
  bool _routeLayerExists = false;
  String? _currentRouteGeometry;
  final RouteCacheManager _routeCache = RouteCacheManager();

  MapboxService({
    double? centerLat,
    double? centerLng,
    this.puntoAStyle = PuntoAStyle.simple,
  }) {
    _initialLat = centerLat;
    _initialLng = centerLng;
  }

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    final token = dotenv.env['MAPBOX_TOKEN'];
    if (token != null && token.isNotEmpty) {
      MapboxOptions.setAccessToken(token);
      _dirClient = MapboxDirectionsClient(token);
      _isInitialized = true;
    } else {
      throw Exception("Mapbox token no encontrado (.env MAPBOX_TOKEN)");
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(limpiarRuta());
    _routeCache.clear();
    _userCircleManager?.dispose();
    _puntoFijoMgr?.borrar();
    _map?.dispose();

    _map = null;
    _isInitialized = false;
    _userCircleManager = null;
    _puntoFijoMgr = null;
    _dirClient = null;
    _routeLayerExists = false;
    _currentRouteGeometry = null;
  }

  @override
  Widget buildMap({
    double? centerLat,
    double? centerLng,
    VoidCallback? onMoveStart,
    VoidCallback? onMoveEnd,
    void Function(double lat, double lng, String? direccion)?
    onUbicacionCambiada,
  }) {
    final double? lat = centerLat ?? _initialLat;
    final double? lng = centerLng ?? _initialLng;

    return MapWidget(
      key: ValueKey("mapWidgetTaxi_${lat ?? 0}_${lng ?? 0}"),
      styleUri: "mapbox://styles/mujeresalvolante/cmcw1hvs6010g01s47h9f9htu",
      cameraOptions: CameraOptions(
        center: (lat != null && lng != null)
            ? Point(coordinates: Position(lng, lat))
            : null,
        zoom: 15,
        padding: MbxEdgeInsets(top: -210, left: 0, bottom: 0, right: 0),
      ),
      onMapCreated: (mapboxMap) async {
        _map = mapboxMap;
        _configureMapSettings(mapboxMap);

        if (lat != null && lng != null) {
          _userCircleManager ??= (puntoAStyle == PuntoAStyle.radar)
              ? RadarUserCircleManager(_map!)
              : UserCircleManager(_map!);
          await _userCircleManager!.addUserCircle(lat, lng);
        }
      },
      onCameraChangeListener: (_) async {
        if (_map == null) return;

        if (!_wasMoving) {
          _wasMoving = true;
          onMoveStart?.call();
        }

        _debounce?.cancel();
        final int thisToken = ++_idleToken;

        _debounce = Timer(const Duration(seconds: 1), () async {
          if (thisToken != _idleToken) return;

          final state = await _map!.getCameraState();
          if (thisToken != _idleToken) return;

          final coords = (state.center.toJson()['coordinates'] as List)
              .cast<double>();
          final lng = coords[0], lat = coords[1];

          _wasMoving = false;
          onMoveEnd?.call();

          final direccion = await obtenerDireccionDesdeCoordenadas(lat, lng);
          if (thisToken != _idleToken) return;

          onUbicacionCambiada?.call(lat, lng, direccion);
        });
      },
    );
  }

  void _configureMapSettings(MapboxMap mapboxMap) {
    try {
      mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
      mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
      mapboxMap.attribution.updateSettings(AttributionSettings(enabled: false));
      mapboxMap.location.updateSettings(
        LocationComponentSettings(enabled: false),
      );
    } catch (_) {}
  }

  @override
  Future<void> moveTo(double lat, double lng, {double zoom = 14}) async {
    if (_map == null) return;
    await _map!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  @override
  Future<Point> getCameraCenter() async {
    if (_map == null) throw Exception('Mapa no inicializado');
    final state = await _map!.getCameraState();
    return state.center;
  }

  /// helper EdgeInsets -> MbxEdgeInsets (named params)
  MbxEdgeInsets _toMbx(EdgeInsets e) =>
      MbxEdgeInsets(top: e.top, left: e.left, bottom: e.bottom, right: e.right);

  /// 🔹 Borra la capa y el source de la ruta actual (si existen).
  Future<void> limpiarRuta() async {
    if (_map == null) return;
    const sourceId = 'route_source';
    const layerId = 'route_layer';
    final style = _map!.style;

    try {
      if (await style.styleLayerExists(layerId)) {
        await style.removeStyleLayer(layerId);
      }
    } catch (_) {}

    try {
      if (await style.styleSourceExists(sourceId)) {
        await style.removeStyleSource(sourceId);
      }
    } catch (_) {}

    _routeLayerExists = false;
    _currentRouteGeometry = null;
    debugPrint('🗑️ Ruta Taxi limpiada');
  }

  @override
  Future<void> dibujarRutaDesdeHasta({
    required Point puntoA,
    required Point puntoB,
    BuildContext? context,
    EdgeInsets? cameraPadding,
  }) async {
    final token = dotenv.env['MAPBOX_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception("Token de Mapbox no disponible");
    }
    if (_map == null) throw Exception("Mapa no inicializado");

    // 1. Padding dinámico
    MbxEdgeInsets padding;
    if (cameraPadding != null) {
      padding = _toMbx(cameraPadding);
    } else if (context != null) {
      final size = MediaQuery.of(context).size;
      final isLandscape = size.width > size.height;
      padding = isLandscape
          ? MbxEdgeInsets(top: 150, left: 100, bottom: 150, right: 100)
          : MbxEdgeInsets(top: 290, left: 50, bottom: 460, right: 50);
    } else {
      padding = MbxEdgeInsets(top: 100, left: 50, bottom: 100, right: 50);
    }

    // 2. Encuadre de cámara
    final framing = await _map!.cameraForCoordinates(
      [puntoA, puntoB],
      padding,
      0.0,
      0.0,
    );

    // 3. Obtener geometría con caché
    final cachedRoute = await _routeCache.getOrFetch(
      a: puntoA,
      b: puntoB,
      fetcher: () async {
        final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${puntoA.coordinates.lng},${puntoA.coordinates.lat};'
          '${puntoB.coordinates.lng},${puntoB.coordinates.lat}'
          '?geometries=geojson&access_token=$token',
        );

        final res = await http.get(url);
        if (res.statusCode != 200) {
          throw Exception("Error al obtener ruta: ${res.statusCode}");
        }

        final data = jsonDecode(res.body);
        final route = data['routes'][0];

        return RouteGeometry(
          geometry: route['geometry'],
          distance: (route['distance'] as num).toDouble(),
          duration: (route['duration'] as num).toInt(),
        );
      },
      cacheDuration: const Duration(minutes: 3),
    );

    final geometry = cachedRoute.geometry;
    final geojsonStr = jsonEncode(geometry);

    // 4. Solo actualizar si geometría cambió
    if (_currentRouteGeometry == geojsonStr && _routeLayerExists) {
      await _map!.easeTo(framing, MapAnimationOptions(duration: 800));
      debugPrint('✅ Ruta sin cambios (Taxi), solo ajuste de cámara');
      return;
    }

    const sourceId = "route_source";
    const layerId = "route_layer";

    final geojson = jsonEncode({
      "type": "FeatureCollection",
      "features": [
        {"type": "Feature", "properties": {}, "geometry": geometry},
      ],
    });

    final style = _map!.style;

    try {
      // ✅ La verdad es el estilo, no el flag
      final sourceExists = await style.styleSourceExists(sourceId);
      final layerExists = await style.styleLayerExists(layerId);

      if (sourceExists) {
        // actualiza data sin recrear
        await style.setStyleSourceProperty(sourceId, "data", geojson);
        debugPrint('✅ Ruta Taxi source actualizado');
      } else {
        // crea source por primera vez
        await style.addSource(GeoJsonSource(id: sourceId, data: geojson));
        debugPrint('✅ Ruta Taxi source creado');
      }

      if (!layerExists) {
        await style.addLayer(
          LineLayer(
            id: layerId,
            sourceId: sourceId,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
            lineColor: Colors.blue.value,
            lineWidth: 6.5,
          ),
        );
        debugPrint('✅ Ruta Taxi layer creado');
      }

      _routeLayerExists = true;
      _currentRouteGeometry = geojsonStr;

      await _map!.easeTo(framing, MapAnimationOptions(duration: 800));
    } catch (e) {
      debugPrint('❌ Error al dibujar ruta (Taxi): $e');
      await _recreateRoute(sourceId, layerId, geojson, framing);
    }
  }

  /// Fallback ultra defensivo para recrear ruta
  Future<void> _recreateRoute(
    String sourceId,
    String layerId,
    String geojson,
    CameraOptions framing,
  ) async {
    if (_map == null) return;
    final style = _map!.style;

    try {
      if (await style.styleLayerExists(layerId)) {
        await style.removeStyleLayer(layerId);
      }
    } catch (_) {}

    try {
      if (await style.styleSourceExists(sourceId)) {
        await style.removeStyleSource(sourceId);
      }
    } catch (_) {}

    try {
      await style.addSource(GeoJsonSource(id: sourceId, data: geojson));
    } catch (e) {
      // si todavía existe por race, solo actualiza
      try {
        await style.setStyleSourceProperty(sourceId, "data", geojson);
      } catch (_) {}
    }

    try {
      if (!await style.styleLayerExists(layerId)) {
        await style.addLayer(
          LineLayer(
            id: layerId,
            sourceId: sourceId,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
            lineColor: Colors.blue.value,
            lineWidth: 6.5,
          ),
        );
      }
    } catch (_) {}

    _routeLayerExists = true;

    try {
      await _map!.easeTo(framing, MapAnimationOptions(duration: 800));
    } catch (_) {}

    debugPrint('✅ Ruta Taxi recreada completamente (defensivo)');
  }

  @override
  Future<RutaInfo> obtenerMetricasDeRuta({
    required Point puntoA,
    required Point puntoB,
  }) async {
    if (!_isInitialized) await init();
    _dirClient ??= MapboxDirectionsClient(dotenv.env['MAPBOX_TOKEN'] ?? '');
    return _dirClient!.getRouteInfo(a: puntoA, b: puntoB);
  }

  @override
  Future<void> agregarPuntoFijo(
    Point punto, {
    Color? fillColor,
    Color? strokeColor,
    double? radius,
    double? strokeWidth,
  }) async {
    if (_map == null) return;
    _puntoFijoMgr ??= PuntoFijoCircleManager(_map!);
    await _puntoFijoMgr!.addFijoCircle(
      punto.coordinates.lat.toDouble(),
      punto.coordinates.lng.toDouble(),
      fillColor: fillColor ?? Colors.white,
      strokeColor: strokeColor ?? const Color(0xFF4CAF50),
      radius: radius ?? 6,
      strokeWidth: strokeWidth ?? 6,
    );
  }

  @override
  Future<void> borrarPuntoFijo() async {
    await _puntoFijoMgr?.borrar();
  }

  /// Borra solo el último punto fijo agregado (ej: el auto anterior)
  Future<void> borrarUltimoPuntoFijo() async {
    await _puntoFijoMgr?.borrarUltimo();
  }

  Future<String?> obtenerDireccionDesdeCoordenadas(
    double lat,
    double lng,
  ) async {
    final token = dotenv.env['MAPBOX_TOKEN'];
    if (token == null || token.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?access_token=$token&language=es&limit=1',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          return features.first['place_name'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
