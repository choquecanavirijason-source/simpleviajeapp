// lib/core/services/mapa/map_service.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/widgets.dart';
import '../mapbox/circuloPunto.dart';
import '../mapbox/taxistas_markers_manager.dart' show TaxistaMarkerData;

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

  /// Sincroniza los marcadores de taxistas online en el mapa.
  /// Llamar repetidamente (cada cambio del stream) — internamente hace diff
  /// por uid y solo crea/borra/mueve lo necesario.
  Future<void> sincronizarTaxistas(List<TaxistaMarkerData> taxistas);

  /// Borra todos los marcadores de taxistas.
  Future<void> limpiarTaxistas();

  void dispose();
}

class RutaInfo {
  final double distanciaKm; // routes[0].distance / 1000
  final int minutos; // round(routes[0].duration / 60)
  final Map<String, dynamic>? geometry; // opcional, por si la querés
  const RutaInfo({
    required this.distanciaKm,
    required this.minutos,
    this.geometry,
  });
}
