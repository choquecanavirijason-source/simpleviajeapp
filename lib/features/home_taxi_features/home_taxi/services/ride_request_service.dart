import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeoUtils {
  static const double earthRadiusKm = 6371.0;

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  static double calculateDistanceHaversine({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final rLat1 = _degreesToRadians(lat1);
    final rLon1 = _degreesToRadians(lon1);
    final rLat2 = _degreesToRadians(lat2);
    final rLon2 = _degreesToRadians(lon2);

    final dLat = rLat2 - rLat1;
    final dLon = rLon2 - rLon1;

    final a =
        pow(sin(dLat / 2), 2) + cos(rLat1) * cos(rLat2) * pow(sin(dLon / 2), 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }
}

class RideRequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Devuelve un stream de pedidos filtrado por distancia (km)
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getNearbyOrders({
    required double driverLat,
    required double driverLng,
    double radiusKm = 2.0,
    int limit = 100,
  }) {
    // Consulta básica a Firestore (estado == 'pedido')
    final query = _db
        .collectionGroup('ordenes')
        .where('estado', isEqualTo: 'pedido')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    // Stream transformado: solo pedidos dentro del radio
    return query.snapshots().map((snap) {
      return snap.docs.where((doc) {
        final data = doc.data();

        final double? origenLat = _toDouble(
          _firstNonNull([
            _fromMap(data, ['origen', 'lat']),
            data['origenLat'],
            data['aLat'],
          ]),
        );

        final double? origenLng = _toDouble(
          _firstNonNull([
            _fromMap(data, ['origen', 'lng']),
            data['origenLng'],
            data['aLng'],
          ]),
        );

        if (origenLat == null || origenLng == null) return false;

        final distance = GeoUtils.calculateDistanceHaversine(
          lat1: driverLat,
          lon1: driverLng,
          lat2: origenLat,
          lon2: origenLng,
        );

        return distance <= radiusKm;
      }).toList();
    });
  }

  // ================== Helpers ==================
  static T? _fromMap<T>(Map<String, dynamic> m, List<String> path) {
    dynamic cur = m;
    for (final k in path) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur as T?;
  }

  static T? _firstNonNull<T>(List<dynamic> list) {
    for (final v in list) {
      if (v != null) return v as T?;
    }
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
