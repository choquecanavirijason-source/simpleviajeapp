import 'dart:math' show cos, sin, sqrt, atan2;

/// Calcula distancia en KM entre dos puntos (lat,lng) con fórmula Haversine
/// Nos sirve para toma el Punto A del pasajero y buscar empresas cercanas.
/// Ej, 6km alrededor.

class GeoUtils {
  static const double _earthRadiusKm = 6371.0;

  /// Distancia Haversine en KM
  static double haversineKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Bounding box simple alrededor (lat,lng) a radio [km]
  /// Devuelve [minLat, maxLat, minLng, maxLng]
  static List<double> boundingBoxKm(double lat, double lng, double km) {
    // ~1° lat ≈ 111.32 km
    final dLat = km / 111.32;
    // ~1° lng ≈ 111.32 * cos(lat)
    final dLng = km / (111.32 * cos(_deg2rad(lat)).abs().clamp(0.00001, 1.0));

    final minLat = lat - dLat;
    final maxLat = lat + dLat;
    final minLng = lng - dLng;
    final maxLng = lng + dLng;
    return [minLat, maxLat, minLng, maxLng];
  }

  static double _deg2rad(double deg) => deg * (3.141592653589793 / 180.0);
}
