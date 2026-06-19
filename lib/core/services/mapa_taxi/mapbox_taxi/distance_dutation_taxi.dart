// lib/features/mapa_destino/service/route_distance.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class RouteSummary {
  final double distanceKm; // routes[0].distance / 1000
  final int durationMin; // round(routes[0].duration / 60)
  final Map<String, dynamic> raw;
  const RouteSummary({
    required this.distanceKm,
    required this.durationMin,
    required this.raw,
  });
}

/// Pide a Mapbox Directions la ruta A→B y devuelve distancia/duración.
/// NO dibuja nada; solo calcula.
Future<RouteSummary> obtenerResumenRuta({
  required Point puntoA,
  required Point puntoB,
}) async {
  final token = dotenv.env['MAPBOX_TOKEN'];
  if (token == null || token.isEmpty) {
    throw Exception("MAPBOX_TOKEN no disponible (.env)");
  }

  final url = Uri.parse(
    'https://api.mapbox.com/directions/v5/mapbox/driving/'
    '${puntoA.coordinates.lng},${puntoA.coordinates.lat};'
    '${puntoB.coordinates.lng},${puntoB.coordinates.lat}'
    '?geometries=geojson&access_token=$token',
  );

  final res = await http.get(url);
  if (res.statusCode != 200) {
    throw Exception("Error Directions: ${res.statusCode} ${res.body}");
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final routes = data['routes'] as List?;
  if (routes == null || routes.isEmpty) {
    throw Exception('No se encontró ruta.');
  }

  final r0 = routes.first as Map<String, dynamic>;
  final distanceMeters = (r0['distance'] as num).toDouble();
  final durationSeconds = (r0['duration'] as num).toDouble();

  return RouteSummary(
    distanceKm: distanceMeters / 1000.0,
    durationMin: (durationSeconds / 60.0).round(),
    raw: data,
  );
}

/// Azúcar sintáctico si prefieres pasar lat/lng directo:
Future<RouteSummary> obtenerResumenRutaLatLng({
  required double aLat,
  required double aLng,
  required double bLat,
  required double bLng,
}) {
  return obtenerResumenRuta(
    puntoA: Point(coordinates: Position(aLng, aLat)),
    puntoB: Point(coordinates: Position(bLng, bLat)),
  );
}
