// import 'package:buses2/core/services/ditanceAyB/distanceAyB.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:buses2/core/services/mapa/mapa/map_service.dart';

class DistanceHelper {
  /// Calcula la distancia en km entre dos coordenadas.
  static double calcularDistancia({
    required double latA,
    required double lngA,
    required double latB,
    required double lngB,
  }) {
    return Geolocator.distanceBetween(latA, lngA, latB, lngB);
  }

  /// Calcula la distancia entre punto A y el centro actual del mapa (punto B) en metros.
  static Future<double> calcularDistanciaDesdeMapa({
    required MapService mapService,
    required double latA,
    required double lngA,
  }) async {
    final center = await mapService.getCameraCenter();
    final coords = center.toJson()['coordinates'] as List;
    final lngB = coords[0];
    final latB = coords[1];

    return calcularDistancia(latA: latA, lngA: lngA, latB: latB, lngB: lngB);
  }

  /// Calcula la distancia entre punto A y centro del mapa, y la retorna en kilómetros.
  static Future<double> calcularDistanciaKmDesdeMapa({
    required MapService mapService,
    required double latA,
    required double lngA,
  }) async {
    final distanciaMetros = await calcularDistanciaDesdeMapa(
      mapService: mapService,
      latA: latA,
      lngA: lngA,
    );
    return distanciaMetros / 1000;
  }

  /// Estima el tiempo de viaje (en minutos) entre Punto A y el centro del mapa.
  /// Evitamos hacer peticiones a la API
  static Future<double> estimarTiempoDesdeMapa({
    required MapService mapService,
    required double latA,
    required double lngA,
    double velocidadKmH = 21, // Velocidad promedio por defecto
  }) async {
    final distanciaKm = await calcularDistanciaKmDesdeMapa(
      mapService: mapService,
      latA: latA,
      lngA: lngA,
    );

    return (distanciaKm / velocidadKmH) * 60;
  }
}
