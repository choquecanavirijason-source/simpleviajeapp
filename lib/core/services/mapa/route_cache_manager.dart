import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Point;

/// Sistema de caché para geometrías de rutas de Mapbox
/// Reduce requests innecesarios y mejora performance
class RouteCacheManager {
  static final _instance = RouteCacheManager._();
  factory RouteCacheManager() => _instance;
  RouteCacheManager._();

  // Caché de geometrías (key = "lat1,lng1->lat2,lng2")
  final Map<String, RouteGeometry> _cache = {};

  // Control de requests en vuelo (evita requests duplicados)
  final Map<String, Future<RouteGeometry>> _pending = {};

  /// Genera una clave única para la ruta entre dos puntos
  /// Usa 5 decimales de precisión (~1.1 metros)
  String _makeKey(Point a, Point b) {
    final aKey =
        '${a.coordinates.lat.toStringAsFixed(5)},${a.coordinates.lng.toStringAsFixed(5)}';
    final bKey =
        '${b.coordinates.lat.toStringAsFixed(5)},${b.coordinates.lng.toStringAsFixed(5)}';
    return '$aKey->$bKey';
  }

  /// Obtiene la geometría desde caché o hace el fetch si es necesario
  ///
  /// - [a]: Punto de origen
  /// - [b]: Punto de destino
  /// - [fetcher]: Función que hace el request a la API
  /// - [cacheDuration]: Duración del caché (default: 5 minutos)
  Future<RouteGeometry> getOrFetch({
    required Point a,
    required Point b,
    required Future<RouteGeometry> Function() fetcher,
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    final key = _makeKey(a, b);

    // 1. Verificar caché
    if (_cache.containsKey(key)) {
      final cached = _cache[key]!;
      final age = DateTime.now().difference(cached.timestamp);

      if (age < cacheDuration) {
        print('✅ Ruta desde caché (edad: ${age.inSeconds}s)');
        return cached;
      } else {
        print('⏰ Caché expirado (edad: ${age.inMinutes}m), refrescando...');
        _cache.remove(key);
      }
    }

    // 2. Verificar si ya hay un request en vuelo para esta ruta
    if (_pending.containsKey(key)) {
      print('⏳ Request en vuelo, esperando resultado...');
      return await _pending[key]!;
    }

    // 3. Hacer el fetch
    print('🌐 Fetching nueva ruta desde API...');
    final future = fetcher();
    _pending[key] = future;

    try {
      final result = await future;
      _cache[key] = result;
      print('✅ Ruta cacheada exitosamente');
      return result;
    } finally {
      _pending.remove(key);
    }
  }

  /// Limpia toda la caché
  void clear() {
    _cache.clear();
    _pending.clear();
    print('🗑️ Caché de rutas limpiada');
  }

  /// Obtiene estadísticas del caché
  Map<String, dynamic> getStats() {
    return {
      'cachedRoutes': _cache.length,
      'pendingRequests': _pending.length,
      'cacheKeys': _cache.keys.toList(),
    };
  }
}

/// Representa la geometría y metadatos de una ruta
class RouteGeometry {
  final Map<String, dynamic> geometry;
  final double distance; // en metros
  final int duration; // en segundos
  final DateTime timestamp;

  RouteGeometry({
    required this.geometry,
    required this.distance,
    required this.duration,
  }) : timestamp = DateTime.now();

  /// Convierte a GeoJSON Feature
  Map<String, dynamic> toGeoJson() {
    return {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {"distance": distance, "duration": duration},
          "geometry": geometry,
        },
      ],
    };
  }
}
