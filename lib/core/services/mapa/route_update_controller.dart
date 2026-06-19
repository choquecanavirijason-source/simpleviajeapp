import 'dart:async';
import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Point;

/// Controlador de actualizaciones de rutas con debouncing y throttling
/// Previene actualizaciones excesivas tipo InDrive/Uber
class RouteUpdateController {
  Timer? _debounceTimer;
  DateTime? _lastUpdate;
  Point? _lastOrigin;
  Point? _lastDestination;

  // ⚙️ Configuración estilo InDrive
  final Duration minUpdateInterval;
  final double minDistanceMeters;
  final Duration debounceDelay;

  RouteUpdateController({
    this.minUpdateInterval = const Duration(seconds: 3),
    this.minDistanceMeters = 50.0,
    this.debounceDelay = const Duration(milliseconds: 800),
  });

  /// Verifica si se debe actualizar la ruta basándose en tiempo y distancia
  bool shouldUpdate({required Point newOrigin, Point? newDestination}) {
    // 1. Check tiempo mínimo desde última actualización
    if (_lastUpdate != null) {
      final elapsed = DateTime.now().difference(_lastUpdate!);
      if (elapsed < minUpdateInterval) {
        print(
          '⏭️ Update ignorado: muy pronto (${elapsed.inSeconds}s < ${minUpdateInterval.inSeconds}s)',
        );
        return false;
      }
    }

    // 2. Check distancia mínima desde última posición
    if (_lastOrigin != null) {
      final distance = _calculateDistance(
        _lastOrigin!.coordinates.lat.toDouble(),
        _lastOrigin!.coordinates.lng.toDouble(),
        newOrigin.coordinates.lat.toDouble(),
        newOrigin.coordinates.lng.toDouble(),
      );

      if (distance < minDistanceMeters) {
        print(
          '⏭️ Update ignorado: muy cerca (${distance.toStringAsFixed(1)}m < ${minDistanceMeters}m)',
        );
        return false;
      }
    }

    // 3. Check si el destino cambió significativamente
    if (newDestination != null && _lastDestination != null) {
      final destDistance = _calculateDistance(
        _lastDestination!.coordinates.lat.toDouble(),
        _lastDestination!.coordinates.lng.toDouble(),
        newDestination.coordinates.lat.toDouble(),
        newDestination.coordinates.lng.toDouble(),
      );

      // Si el destino cambió más de 100m, forzar update
      if (destDistance > 100.0) {
        print(
          '✅ Update permitido: destino cambió (${destDistance.toStringAsFixed(1)}m)',
        );
        return true;
      }
    }

    print('✅ Update permitido: condiciones cumplidas');
    return true;
  }

  /// Programa una actualización con debouncing
  /// Útil cuando hay muchos eventos seguidos (ej: GPS updates)
  void scheduleUpdate({
    required Point origin,
    Point? destination,
    required Future<void> Function() onUpdate,
  }) {
    // Cancelar timer anterior si existe
    _debounceTimer?.cancel();

    // Programar nueva actualización
    _debounceTimer = Timer(debounceDelay, () async {
      if (shouldUpdate(newOrigin: origin, newDestination: destination)) {
        _lastUpdate = DateTime.now();
        _lastOrigin = origin;
        _lastDestination = destination;

        await onUpdate();
      }
    });
  }

  /// Actualización inmediata (sin debouncing)
  /// Útil para casos donde necesitas respuesta instantánea
  Future<void> updateNow({
    required Point origin,
    Point? destination,
    required Future<void> Function() onUpdate,
  }) async {
    _debounceTimer?.cancel();

    if (shouldUpdate(newOrigin: origin, newDestination: destination)) {
      _lastUpdate = DateTime.now();
      _lastOrigin = origin;
      _lastDestination = destination;

      await onUpdate();
    }
  }

  /// Calcula distancia entre dos puntos en metros (Haversine)
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742000 *
        asin(sqrt(a)); // 2 * R * asin, R = 6371 km, resultado en metros
  }

  /// Fuerza el próximo update (ignora tiempo y distancia)
  void forceNextUpdate() {
    _lastUpdate = null;
    _lastOrigin = null;
    _lastDestination = null;
    print('🔄 Próximo update será forzado');
  }

  /// Obtiene información del estado actual
  Map<String, dynamic> getState() {
    final now = DateTime.now();
    return {
      'lastUpdate': _lastUpdate?.toIso8601String(),
      'secondsSinceLastUpdate': _lastUpdate != null
          ? now.difference(_lastUpdate!).inSeconds
          : null,
      'hasLastOrigin': _lastOrigin != null,
      'hasLastDestination': _lastDestination != null,
      'minUpdateIntervalSeconds': minUpdateInterval.inSeconds,
      'minDistanceMeters': minDistanceMeters,
    };
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    print('🗑️ RouteUpdateController disposed');
  }
}
