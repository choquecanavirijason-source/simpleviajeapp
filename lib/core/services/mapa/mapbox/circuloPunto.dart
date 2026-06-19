import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class PuntoFijoCircleManager {
  final MapboxMap _map;
  CircleAnnotationManager? _manager;

  // guarda TODOS los círculos creados
  final List<CircleAnnotation> _circles = [];

  PuntoFijoCircleManager(this._map);

  Future<void> addFijoCircle(
    double lat,
    double lng, {
    Color fillColor = Colors.white,
    Color strokeColor = const Color(0xFF4CAF50),
    double radius = 6,
    double strokeWidth = 6,
  }) async {
    // 👇 FIX: crear manager con retry para evitar crash "No manager found"
    await _ensureManagerReady();
    if (_manager == null) {
      debugPrint(
        '⚠️ No se pudo crear CircleAnnotationManager (punto fijo passenger), se omite',
      );
      return;
    }

    final opts = CircleAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)), // (lng, lat)
      circleRadius: radius,
      circleColor: fillColor.value,
      circleOpacity: 1,
      circleStrokeWidth: strokeWidth,
      circleStrokeColor: strokeColor.value,
    );

    final circle = await _manager!.create(opts);
    _circles.add(circle); // acumulamos (soporta múltiples pins)
  }

  /// Intenta crear el CircleAnnotationManager con reintentos para evitar race condition.
  Future<void> _ensureManagerReady() async {
    if (_manager != null) return;

    const int maxAttempts = 10; // 🔧 Aumentado de 6 a 10 intentos
    int attempt = 0;
    Object? lastError;

    while (_manager == null && attempt < maxAttempts) {
      try {
        _manager = await _map.annotations.createCircleAnnotationManager();
        break;
      } catch (e) {
        lastError = e;
        attempt++;
        await Future.delayed(Duration(milliseconds: 150 * attempt));
      }
    }

    if (_manager == null) {
      debugPrint(
        '❌ _ensureManagerReady (punto fijo passenger) falló después de $maxAttempts intentos: $lastError',
      );
    }
  }

  /// Borra TODOS los puntos fijos creados.
  Future<void> borrar() async {
    if (_manager == null || _circles.isEmpty) return;
    for (final c in List<CircleAnnotation>.from(_circles)) {
      try {
        await _manager!.delete(c);
      } catch (_) {}
    }
    _circles.clear();
  }

  /// (Opcional) borra solo el último pin agregado.
  Future<void> borrarUltimo() async {
    if (_manager == null || _circles.isEmpty) return;
    final last = _circles.removeLast();
    try {
      await _manager!.delete(last);
    } catch (_) {}
  }

  void dispose() {
    _circles.clear();
    _manager = null;
  }
}
