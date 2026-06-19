import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

abstract class MapService {
  Future<void> init();
  Future<void> moveTo(double lat, double lng, {double zoom = 17});

  Widget buildMap({
    double? centerLat,
    double? centerLng,
    VoidCallback? onMoveStart,
    VoidCallback? onMoveEnd,
    void Function(double lat, double lng, String? direccion)?
    onUbicacionCambiada,
  });

  Future<Point> getCameraCenter();

  /// DIBUJA la ruta entre A y B (no devuelve métricas).
  Future<void> dibujarRutaDesdeHasta({
    required Point puntoA,
    required Point puntoB,
    BuildContext? context,
    EdgeInsets? cameraPadding, // 👈 IMPORTANTE: expuesto en la interfaz
  });

  /// NO dibuja. Devuelve métricas de la ruta (km/min) y geometría opcional.
  Future<RutaInfo> obtenerMetricasDeRuta({
    required Point puntoA,
    required Point puntoB,
  });

  Future<void> agregarPuntoFijo(
    Point punto, {
    Color? fillColor,
    Color? strokeColor,
    double? radius,
    double? strokeWidth,
  });

  Future<void> borrarPuntoFijo();

  /// Borra solo el último punto fijo agregado
  Future<void> borrarUltimoPuntoFijo();

  void dispose();
}

class RutaInfo {
  final double distanciaKm; // routes[0].distance / 1000
  final int minutos; // round(routes[0].duration / 60)
  final Map<String, dynamic>? geometry; // opcional
  const RutaInfo({
    required this.distanciaKm,
    required this.minutos,
    this.geometry,
  });
}
