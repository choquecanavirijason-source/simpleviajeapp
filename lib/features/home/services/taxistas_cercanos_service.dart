// lib/features/home/services/taxistas_cercanos_service.dart
//
// Stream de taxistas conectados ("libres") cercanos al pasajero.
// Lee de RTDB en `taxistas_online/` y filtra por distancia Haversine en cliente.
//
// Eficiencia:
//   - Una sola suscripción RTDB para todos los taxistas online.
//   - El filtro por radio ocurre en cliente — para escalar a miles de
//     taxistas habría que añadir geohashing en el servidor.
//   - Throttling: el stream emite máximo cada 1.5s (configurable).

import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Representación pública de un taxista online.
class TaxistaOnline {
  final String uid;
  final double lat;
  final double lng;
  final String? servicio; // 'Taxi', 'Moto Taxi', etc.
  final String? nombre;
  final int? timestamp;

  const TaxistaOnline({
    required this.uid,
    required this.lat,
    required this.lng,
    this.servicio,
    this.nombre,
    this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxistaOnline &&
          uid == other.uid &&
          lat == other.lat &&
          lng == other.lng &&
          servicio == other.servicio;

  @override
  int get hashCode => Object.hash(uid, lat, lng, servicio);
}

class TaxistasCercanosService {
  TaxistasCercanosService._();
  static final TaxistasCercanosService instance = TaxistasCercanosService._();

  static const _path = 'taxistas_online';
  static const _throttleMs = 1500;

  /// Devuelve un Stream de taxistas dentro de [radiusKm] del punto
  /// (`centerLat`, `centerLng`). Opcionalmente filtra por [servicio]
  /// (ej. solo "Taxi" o solo "Moto Taxi").
  ///
  /// El stream se completa al cerrarse la suscripción (cancel del listener).
  Stream<List<TaxistaOnline>> streamCercanos({
    required double centerLat,
    required double centerLng,
    double radiusKm = 5.0,
    String? servicio,
  }) {
    final controller = StreamController<List<TaxistaOnline>>.broadcast();
    final ref = FirebaseDatabase.instance.ref(_path);

    DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    List<TaxistaOnline>? _pending;
    Timer? _flushTimer;

    void _emit(List<TaxistaOnline> list) {
      final now = DateTime.now();
      final since = now.difference(_lastEmit).inMilliseconds;
      if (since >= _throttleMs) {
        _lastEmit = now;
        if (!controller.isClosed) controller.add(list);
        _pending = null;
        return;
      }
      // Programar flush diferido (coalescing).
      _pending = list;
      _flushTimer?.cancel();
      _flushTimer = Timer(Duration(milliseconds: _throttleMs - since), () {
        final p = _pending;
        if (p != null && !controller.isClosed) {
          _lastEmit = DateTime.now();
          controller.add(p);
          _pending = null;
        }
      });
    }

    debugPrint(
      '🧭 cercanos: suscrito a $_path centro=($centerLat,$centerLng) r=${radiusKm}km',
    );

    final sub = ref.onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        if (raw == null) {
          debugPrint('🧭 cercanos: snapshot vacío (no hay taxistas online)');
          _emit(const []);
          return;
        }
        if (raw is! Map) {
          debugPrint('🧭 cercanos: snapshot no es Map (${raw.runtimeType})');
          _emit(const []);
          return;
        }

        final result = <TaxistaOnline>[];
        int totalEnRtdb = 0;
        int descartadosPorDistancia = 0;
        int descartadosPorServicio = 0;

        raw.forEach((key, value) {
          totalEnRtdb++;
          if (value is! Map) return;
          final lat = (value['lat'] as num?)?.toDouble();
          final lng = (value['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return;

          final dKm = _haversineKm(centerLat, centerLng, lat, lng);
          if (dKm > radiusKm) {
            descartadosPorDistancia++;
            return;
          }

          final srv = value['servicio']?.toString();
          if (servicio != null &&
              srv != null &&
              srv.trim().toLowerCase() != servicio.trim().toLowerCase()) {
            descartadosPorServicio++;
            return;
          }

          result.add(TaxistaOnline(
            uid: key.toString(),
            lat: lat,
            lng: lng,
            servicio: srv,
            nombre: value['nombre']?.toString(),
            timestamp: (value['t'] as num?)?.toInt(),
          ));
        });

        debugPrint(
          '🧭 cercanos: total=$totalEnRtdb dentro=${result.length} '
          'fueraRadio=$descartadosPorDistancia otroServicio=$descartadosPorServicio',
        );

        _emit(result);
      },
      onError: (e) {
        debugPrint('🟥 cercanos error (¿reglas RTDB?): $e');
        if (!controller.isClosed) controller.addError(e);
      },
    );

    controller.onCancel = () {
      sub.cancel();
      _flushTimer?.cancel();
    };

    return controller.stream;
  }

  /// Distancia Haversine entre dos puntos lat/lng en kilómetros.
  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0; // radio de la Tierra en km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
