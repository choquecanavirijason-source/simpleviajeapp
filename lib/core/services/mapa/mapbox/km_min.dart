// lib/core/services/mapa/mapbox/km_min.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../mapa/map_service.dart';

class MapboxDirectionsClient {
  final String accessToken;
  MapboxDirectionsClient(this.accessToken);

  /// prefer: 'fastest' (default) o 'shortest'
  Future<RutaInfo> getRouteInfo({
    required Point a,
    required Point b,
    String prefer = 'fastest',
  }) async {
    if (accessToken.isEmpty) throw Exception('MAPBOX_TOKEN vacío');

    final base =
        'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/'
        '${a.coordinates.lng},${a.coordinates.lat};'
        '${b.coordinates.lng},${b.coordinates.lat}';

    final url = Uri.parse(
      '$base'
      '?geometries=geojson'
      '&alternatives=true'
      '&annotations=distance,duration,congestion'
      '&overview=full'
      '&steps=false'
      '&access_token=$accessToken',
    );

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Error Directions: ${res.statusCode} – ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final routes =
        (data['routes'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (routes.isEmpty) throw Exception('Directions sin rutas');

    // Elige ruta según preferencia
    Map<String, dynamic> pick;
    if (prefer == 'shortest') {
      pick = routes.reduce(
        (a, b) =>
            ((a['distance'] as num).toDouble() <=
                (b['distance'] as num).toDouble())
            ? a
            : b,
      );
    } else {
      // 'fastest' por defecto (con tráfico)
      pick = routes.reduce(
        (a, b) =>
            ((a['duration'] as num).toDouble() <=
                (b['duration'] as num).toDouble())
            ? a
            : b,
      );
    }

    final distanceMeters = (pick['distance'] as num).toDouble();
    final durationSeconds = (pick['duration'] as num).toDouble();

    return RutaInfo(
      distanciaKm: distanceMeters / 1000.0,
      minutos: (durationSeconds / 60.0).round(),
      geometry: pick['geometry'] as Map<String, dynamic>?,
    );
  }
}
