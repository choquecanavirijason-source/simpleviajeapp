// import 'package:buses2/core/services/mapbox/mapbox_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../mapa/map_service.dart';
// ⛔️ Sin radar: importamos solo la interfaz y el simple
import 'circuloPuntoA.dart' show IUserCircleManager, UserCircleManager;

import 'circuloPunto.dart';
import 'taxistas_markers_manager.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import './km_min.dart';
import '../route_cache_manager.dart';

class MapboxService implements MapService {
  MapboxMap? _map;
  Timer? _debounce;
  double? _initialLat;
  double? _initialLng;
  bool _isInitialized = false;
  bool _wasMoving = false;
  IUserCircleManager? _userCircleManager;
  int _idleToken = 0; // token para invalidar timers/respuestas viejas
  PuntoFijoCircleManager? _puntoFijoMgr;
  TaxistasMarkersManager? _taxistasMgr;
  MapboxDirectionsClient? _dirClient;

  // Control de rutas para evitar parpadeo
  bool _routeLayerExists = false;
  bool _labelLayerExists = false;
  String? _currentRouteGeometry;
  Map<String, dynamic>? _lastRouteGeometry; // para actualizar label externo
  final RouteCacheManager _routeCache = RouteCacheManager();

  MapboxService({double? centerLat, double? centerLng}) {
    _initialLat = centerLat;
    _initialLng = centerLng;
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

  @override
  Future<void> sincronizarTaxistas(List<TaxistaMarkerData> taxistas) async {
    if (_map == null) return;
    _taxistasMgr ??= TaxistasMarkersManager(_map!);
    await _taxistasMgr!.sincronizar(taxistas);
  }

  @override
  Future<void> limpiarTaxistas() async {
    await _taxistasMgr?.limpiar();
  }

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Token modular, usando .env
      final token = dotenv.env['MAPBOX_TOKEN'];
      if (token != null && token.isNotEmpty) {
        MapboxOptions.setAccessToken(token);
        _dirClient = MapboxDirectionsClient(token);
        _isInitialized = true;
      } else {
        throw Exception("Mapbox token no encontrado");
      }
    } catch (e) {
      print('❌ Error al inicializar Mapbox: $e');
      rethrow;
    }
  }

  @override
  Future<void> moveTo(double lat, double lng, {double zoom = 14}) async {
    if (_map == null) return;

    try {
      await _map!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: zoom,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      print('❌ Error al mover mapa: $e');
    }
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
      key: ValueKey("mapWidget_${lat ?? 0}_${lng ?? 0}"),
      // styleUri: "mapbox://styles/mujeresalvolante/cmcw2f89e00yz01qve4b276f3", // Noche
      styleUri:
          "mapbox://styles/mujeresalvolante/cmcw1hvs6010g01s47h9f9htu", // Día

      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(centerLng!, centerLat!)),
        zoom: 15,
        // sube el “centro” para que caiga sobre tu marcador
        padding: MbxEdgeInsets(top: -210, bottom: 0, left: 0, right: 0),
      ),

      onMapCreated: (mapboxMap) async {
        _map = mapboxMap;
        _configureMapSettings(mapboxMap);

        if (lat != null && lng != null) {
          // 👇 Siempre círculo simple (sin radar)
          _userCircleManager ??= UserCircleManager(_map!);
          await _userCircleManager!.addUserCircle(lat, lng);
        }
      },

      onCameraChangeListener: (_) async {
        if (_map == null) return;

        // Si no estaba moviéndose, marca inicio
        if (!_wasMoving) {
          _wasMoving = true;
          onMoveStart?.call(); // tu UI puede limpiar calle/ciudad/país
        }

        // Debounce
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

  @override
  Future<Point> getCameraCenter() async {
    if (_map == null) throw Exception('Mapa no inicializado');
    final state = await _map!.getCameraState();
    return state.center;
  }

  Future<MapboxDirectionsClient> _client() async {
    if (!_isInitialized) await init();
    _dirClient ??= MapboxDirectionsClient(dotenv.env['MAPBOX_TOKEN'] ?? '');
    return _dirClient!;
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
  Future<void> dibujarRutaDesdeHasta({
    required Point puntoA,
    required Point puntoB,
    BuildContext? context,
  }) async {
    final token = dotenv.env['MAPBOX_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception("Token de Mapbox no disponible");
    }
    if (_map == null) throw Exception("Mapa no inicializado");

    // 1. Padding dinámico según orientación
    MbxEdgeInsets padding = MbxEdgeInsets(
      top: 100,
      bottom: 100,
      left: 50,
      right: 50,
    );
    if (context != null) {
      final size = MediaQuery.of(context).size;
      final isLandscape = size.width > size.height;
      padding = isLandscape
          ? MbxEdgeInsets(top: 150, bottom: 150, left: 100, right: 100)
          : MbxEdgeInsets(top: 290, bottom: 460, left: 50, right: 50);
    }

    // 2. Encuadre de cámara
    final framing = await _map!.cameraForCoordinates(
      [puntoA, puntoB],
      padding,
      0.0,
      0.0,
    );

    // 3. ⭐ Obtener geometría con caché
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
      cacheDuration: const Duration(minutes: 5),
    );

    final geometry = cachedRoute.geometry;
    final geojsonStr = jsonEncode(geometry);

    // 4. ⭐ OPTIMIZACIÓN: Solo actualizar si la geometría cambió
    if (_currentRouteGeometry == geojsonStr && _routeLayerExists) {
      // Geometría idéntica, solo mover cámara suavemente
      await _map!.easeTo(framing, MapAnimationOptions(duration: 800));
      debugPrint('✅ Ruta sin cambios, solo ajuste de cámara');
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

    try {
      if (_routeLayerExists) {
        // ⭐ ACTUALIZAR source existente sin recrear (evita parpadeo)
        try {
          await _map!.style.setStyleSourceProperty(sourceId, "data", geojson);
          debugPrint('✅ Ruta actualizada sin recrear layer');
        } catch (e) {
          // Si falla setStyleSourceProperty, recrear
          debugPrint('⚠️ Fallback a recreación: $e');
          await _recreateRoute(sourceId, layerId, geojson, framing);
        }
      } else {
        // Primera vez: crear source y layer
        await _map!.style.addSource(GeoJsonSource(id: sourceId, data: geojson));
        await _map!.style.addLayer(
          LineLayer(
            id: layerId,
            sourceId: sourceId,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
            lineColor: Colors.blue.toARGB32(),
            lineWidth: 6.5,
          ),
        );
        _routeLayerExists = true;
        debugPrint('✅ Ruta creada por primera vez');
      }

      _currentRouteGeometry = geojsonStr;
      _lastRouteGeometry = geometry;

      // Label km/min en el punto medio de la ruta
      final distanciaKm = cachedRoute.distance / 1000.0;
      final minutos = (cachedRoute.duration / 60.0).round();
      await _actualizarLabelRuta(geometry, distanciaKm, minutos);

      // Animación suave de cámara
      await _map!.easeTo(framing, MapAnimationOptions(duration: 800));
    } catch (e) {
      debugPrint('❌ Error al dibujar ruta: $e');
      // Fallback: recrear todo
      await _recreateRoute(sourceId, layerId, geojson, framing);
    }
  }

  /// Calcula el punto medio de una geometría LineString de GeoJSON.
  List<double> _midpointOfGeometry(Map<String, dynamic> geometry) {
    final rawCoords = geometry['coordinates'] as List?;
    if (rawCoords == null || rawCoords.isEmpty) return [0.0, 0.0];
    final coords = rawCoords
        .map((c) => (c as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    return coords[coords.length ~/ 2];
  }

  /// Agrega o actualiza el label de km/min sobre la ruta.
  Future<void> _actualizarLabelRuta(
    Map<String, dynamic> geometry,
    double distanciaKm,
    int minutos,
  ) async {
    if (_map == null) return;
    const labelSourceId = 'route_label_source';
    const labelLayerId = 'route_label_layer';

    final mid = _midpointOfGeometry(geometry);
    final texto = '${distanciaKm.toStringAsFixed(1)} km · $minutos min';

    final labelGeoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'label': texto},
          'geometry': {
            'type': 'Point',
            'coordinates': mid,
          },
        },
      ],
    });

    try {
      if (_labelLayerExists) {
        await _map!.style.setStyleSourceProperty(
          labelSourceId,
          'data',
          labelGeoJson,
        );
      } else {
        await _map!.style.addSource(
          GeoJsonSource(id: labelSourceId, data: labelGeoJson),
        );
        await _map!.style.addLayer(
          SymbolLayer(
            id: labelLayerId,
            sourceId: labelSourceId,
            textFieldExpression: ['get', 'label'],
            textSize: 13.0,
            textColor: Colors.white.toARGB32(),
            textHaloColor: const Color(0xFF1565C0).toARGB32(),
            textHaloWidth: 10.0,
            textFont: ['DIN Pro Medium', 'Arial Unicode MS Regular'],
          ),
        );
        _labelLayerExists = true;
      }
    } catch (e) {
      debugPrint('⚠️ Error al actualizar label de ruta: $e');
    }
  }

  /// Actualiza el texto del label con valores externos (ej: los de metricasEntre).
  Future<void> actualizarDistanciaLabel(double km, int minutos) async {
    if (_lastRouteGeometry == null) return;
    await _actualizarLabelRuta(_lastRouteGeometry!, km, minutos);
  }

  /// Helper para recrear la ruta desde cero (fallback)
  Future<void> _recreateRoute(
    String sourceId,
    String layerId,
    String geojson,
    CameraOptions framing,
  ) async {
    try {
      await _map!.style.removeStyleLayer(layerId);
    } catch (_) {}
    try {
      await _map!.style.removeStyleSource(sourceId);
    } catch (_) {}

    await _map!.style.addSource(GeoJsonSource(id: sourceId, data: geojson));
    await _map!.style.addLayer(
      LineLayer(
        id: layerId,
        sourceId: sourceId,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineColor: Colors.blue.toARGB32(),
        lineWidth: 6.5,
      ),
    );
    _routeLayerExists = true;

    await _map!.easeTo(framing, MapAnimationOptions(duration: 800));
    debugPrint('✅ Ruta recreada completamente');
  }

  /// Limpia la ruta del mapa
  Future<void> limpiarRuta() async {
    if (_map == null) return;
    const sourceId = 'route_source';
    const layerId = 'route_layer';

    try {
      final hasLayer = await _map!.style.styleLayerExists(layerId);
      if (hasLayer) {
        await _map!.style.removeStyleLayer(layerId);
      }
    } catch (_) {}

    try {
      final hasSource = await _map!.style.styleSourceExists(sourceId);
      if (hasSource) {
        await _map!.style.removeStyleSource(sourceId);
      }
    } catch (_) {}

    _routeLayerExists = false;
    _currentRouteGeometry = null;
    debugPrint('🗑️ Ruta limpiada');
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
    } catch (e) {
      print('❌ Error al configurar mapa: $e');
    }
  }

  void dispose() {
    _debounce?.cancel();
    _map?.dispose();
    _userCircleManager?.dispose();
    _taxistasMgr?.dispose();
    _taxistasMgr = null;
    _routeCache.clear(); // ⭐ Limpiar caché al destruir
    _map = null;
    _isInitialized = false;
    _userCircleManager = null;
    _routeLayerExists = false;
    _currentRouteGeometry = null;
  }

  /// Convierte coordenadas (lat, lng) en una dirección legible usando Mapbox Geocoding API.
  Future<String?> obtenerDireccionDesdeCoordenadas(
    double lat,
    double lng,
  ) async {
    final token = dotenv.env['MAPBOX_TOKEN'];
    if (token == null || token.isEmpty) {
      print('❌ MAPBOX_TOKEN no disponible');
      return null;
    }

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$token&language=es&limit=1',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final placeName = features.first['place_name'] as String?;
          return placeName;
        }
      } else {
        print('❌ Error al obtener dirección: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Excepción al obtener dirección: $e');
    }

    return null;
  }
}
