// lib/features/home/services/taxistas_cercanos_service.dart
//
// Stream de taxistas conectados ("libres") cercanos al pasajero.
// Lee de RTDB en `taxistas_online/` y filtra por distancia Haversine en cliente.
//
// Reglas de selección (ver [TaxistasCercanosService.seleccionarCercanos]):
//   1. Se descartan nodos sin lat/lng, de otro servicio o con ubicación vieja
//      (campo `t` más antiguo que [TaxistasCercanosService.maxEdadUbicacion]).
//   2. Se buscan taxistas en radios crecientes (5 → 10 → 20 km por defecto):
//      se usa el primer radio en el que haya al menos uno.
//   3. La lista resultante va ORDENADA por distancia: `first` es el más cercano.
//
// Eficiencia:
//   - Una sola suscripción RTDB para todos los taxistas online.
//   - El filtro ocurre en cliente — para escalar a miles de taxistas habría
//     que pasar a geohashes (p. ej. geoflutterfire_plus / GeoFire).
//   - Throttling: el stream emite máximo cada 1.5s.

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

  /// Distancia en km al centro de búsqueda (punto del pasajero).
  final double distanciaKm;

  const TaxistaOnline({
    required this.uid,
    required this.lat,
    required this.lng,
    this.servicio,
    this.nombre,
    this.timestamp,
    this.distanciaKm = 0,
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

  /// Radios de búsqueda por defecto, de menor a mayor (km).
  static const List<double> radiosPorDefectoKm = [5.0, 10.0, 20.0];

  /// Antigüedad máxima de una ubicación para considerarla válida.
  /// El taxista publica cada 8 s si se mueve y hace heartbeat cada 60 s si
  /// está quieto (TaxistaPresenceService), así que 3 min deja margen para
  /// cortes breves de red sin mostrar "taxis fantasma".
  static const Duration maxEdadUbicacion = Duration(minutes: 3);

  /// Devuelve un Stream con los taxistas cercanos a (`centerLat`, `centerLng`),
  /// ordenados del más cercano al más lejano.
  ///
  /// Prueba los radios de [radiosKm] en orden y usa el primero que tenga al
  /// menos un taxista. Opcionalmente filtra por [servicio].
  Stream<List<TaxistaOnline>> streamCercanos({
    required double centerLat,
    required double centerLng,
    List<double> radiosKm = radiosPorDefectoKm,
    String? servicio,
  }) {
    final controller = StreamController<List<TaxistaOnline>>.broadcast();
    final db = FirebaseDatabase.instance;
    final ref = db.ref(_path);

    // Diferencia entre el reloj del teléfono y el del servidor, para comparar
    // correctamente contra `t` (que lo escribe el servidor).
    int serverOffsetMs = 0;
    final offsetSub = db.ref('.info/serverTimeOffset').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) serverOffsetMs = v.toInt();
    }, onError: (_) {});

    DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    List<TaxistaOnline>? pending;
    Timer? flushTimer;

    void emit(List<TaxistaOnline> list) {
      final now = DateTime.now();
      final since = now.difference(lastEmit).inMilliseconds;
      if (since >= _throttleMs) {
        lastEmit = now;
        if (!controller.isClosed) controller.add(list);
        pending = null;
        return;
      }
      // Programar flush diferido (coalescing).
      pending = list;
      flushTimer?.cancel();
      flushTimer = Timer(Duration(milliseconds: _throttleMs - since), () {
        final p = pending;
        if (p != null && !controller.isClosed) {
          lastEmit = DateTime.now();
          controller.add(p);
          pending = null;
        }
      });
    }

    debugPrint(
      '🧭 cercanos: suscrito a $_path centro=($centerLat,$centerLng) '
      'radios=${radiosKm}km',
    );

    final sub = ref.onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        if (raw is! Map) {
          debugPrint('🧭 cercanos: sin taxistas online (${raw.runtimeType})');
          emit(const []);
          return;
        }

        final result = seleccionarCercanos(
          raw: raw,
          centerLat: centerLat,
          centerLng: centerLng,
          radiosKm: radiosKm,
          servicio: servicio,
          nowMs: DateTime.now().millisecondsSinceEpoch + serverOffsetMs,
        );

        debugPrint(
          '🧭 cercanos: total=${raw.length} encontrados=${result.length}'
          '${result.isNotEmpty ? ' masCercano=${result.first.uid} '
              '(${result.first.distanciaKm.toStringAsFixed(2)} km)' : ''}',
        );

        emit(result);
      },
      onError: (e) {
        debugPrint('🟥 cercanos error (¿reglas RTDB?): $e');
        if (!controller.isClosed) controller.addError(e);
      },
    );

    controller.onCancel = () {
      sub.cancel();
      offsetSub.cancel();
      flushTimer?.cancel();
    };

    return controller.stream;
  }

  /// Lógica pura de selección (sin Firebase) para poder testearla.
  ///
  /// [raw] es el snapshot de `taxistas_online` ({uid: {lat, lng, t, servicio}}).
  /// Devuelve los taxistas del primer radio de [radiosKm] que tenga alguno,
  /// ordenados por distancia ascendente.
  @visibleForTesting
  static List<TaxistaOnline> seleccionarCercanos({
    required Map raw,
    required double centerLat,
    required double centerLng,
    List<double> radiosKm = radiosPorDefectoKm,
    String? servicio,
    required int nowMs,
    Duration maxEdad = maxEdadUbicacion,
  }) {
    final candidatos = <TaxistaOnline>[];
    final servicioBuscado = servicio?.trim().toLowerCase();

    raw.forEach((key, value) {
      if (value is! Map) return;
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      final t = (value['t'] as num?)?.toInt();
      if (t != null && nowMs - t > maxEdad.inMilliseconds) return;

      final srv = value['servicio']?.toString();
      if (servicioBuscado != null &&
          srv != null &&
          srv.trim().toLowerCase() != servicioBuscado) {
        return;
      }

      candidatos.add(TaxistaOnline(
        uid: key.toString(),
        lat: lat,
        lng: lng,
        servicio: srv,
        nombre: value['nombre']?.toString(),
        timestamp: t,
        distanciaKm: haversineKm(centerLat, centerLng, lat, lng),
      ));
    });

    candidatos.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));

    final radios = [...radiosKm]..sort();
    for (final r in radios) {
      final dentro = candidatos.where((c) => c.distanciaKm <= r).toList();
      if (dentro.isNotEmpty) return dentro;
    }
    return const [];
  }

  /// Distancia Haversine entre dos puntos lat/lng en kilómetros.
  static double haversineKm(
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

  /// Rumbo inicial desde el punto 1 al punto 2, en grados (0 = norte,
  /// 90 = este), en el rango [0, 360).
  static double rumboGrados(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final p1 = _deg2rad(lat1);
    final p2 = _deg2rad(lat2);
    final dl = _deg2rad(lng2 - lng1);
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dl);
    final deg = math.atan2(y, x) * 180.0 / math.pi;
    return (deg + 360.0) % 360.0;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
