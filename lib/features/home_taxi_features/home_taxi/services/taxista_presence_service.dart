// lib/features/home_taxi_features/home_taxi/services/taxista_presence_service.dart
//
// Publica la presencia del taxista en RTDB cuando está "libre", para que
// los pasajeros puedan verlo en el mapa en tiempo real.
//
// Path: taxistas_online/{uidTaxista}
// Campos: { lat, lng, t, servicio, nombre? }
//
// Eficiencia:
//   - Publica cada 8s pero SOLO si el taxista se movió >= 15m
//   - Usa onDisconnect() para eliminar automáticamente el nodo si la app
//     se cierra/pierde conexión (sin escritura cliente extra)
//   - setOcupado()/stop() borra inmediatamente el nodo

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

class TaxistaPresenceService {
  TaxistaPresenceService._();
  static final TaxistaPresenceService instance = TaxistaPresenceService._();

  static const int _tickSeconds = 8;
  static const double _minMeters = 15;

  Timer? _ticker;
  DatabaseReference? _ref;
  geo.Position? _lastUploaded;

  String? _servicio;
  String? _nombre;
  bool _publishing = false;

  bool get isPublishing => _publishing;

  /// Empieza a publicar la presencia del taxista (estado=libre).
  /// Si ya está publicando, actualiza el servicio/nombre sin reiniciar el timer.
  Future<void> startPublishing({
    required String servicio,
    String? nombre,
  }) async {
    _servicio = servicio;
    _nombre = nombre;

    if (_publishing) {
      debugPrint('🚖 presence: ya publica, refresco campos (servicio=$servicio)');
      if (_lastUploaded != null) {
        await _publishOnce(_lastUploaded!);
      }
      return;
    }

    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('🟥 presence: uid null, no publico');
      return;
    }

    _ref = FirebaseDatabase.instance.ref('taxistas_online/$uid');
    _publishing = true;
    debugPrint('🚖 presence START → taxistas_online/$uid (servicio=$servicio)');

    // Auto-borrar si la app pierde conexión / se mata.
    try {
      await _ref!.onDisconnect().remove();
    } catch (e) {
      debugPrint('🟥 presence onDisconnect setup: $e');
    }

    // Publicar inmediatamente la primera ubicación.
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      await _publishOnce(pos); // _lastUploaded se actualiza dentro si el write es exitoso
      debugPrint('🚖 presence: primera publicación @ ${pos.latitude},${pos.longitude}');
    } catch (e) {
      debugPrint('🟥 presence initial publish (¿permisos GPS?): $e');
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: _tickSeconds), (_) async {
      if (!_publishing) return;
      try {
        final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        // Si el último publish falló (_lastUploaded == null) siempre reintentamos.
        if (_shouldPublish(pos)) {
          await _publishOnce(pos);
        }
      } catch (e) {
        debugPrint('🟥 presence ticker error (¿GPS sin permiso?): $e');
      }
    });
  }

  /// Detiene la publicación y elimina el nodo (ya no aparezco en el mapa).
  Future<void> stopPublishing() async {
    _publishing = false;
    _ticker?.cancel();
    _ticker = null;
    _lastUploaded = null;

    final ref = _ref;
    _ref = null;
    if (ref == null) return;

    try {
      await ref.onDisconnect().cancel();
    } catch (_) {}

    try {
      await ref.remove();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ presence remove: $e');
    }
  }

  Future<void> _publishOnce(geo.Position pos) async {
    final ref = _ref;
    if (ref == null) return;
    try {
      await ref.set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        't': ServerValue.timestamp,
        if (_servicio != null) 'servicio': _servicio,
        if (_nombre != null && _nombre!.isNotEmpty) 'nombre': _nombre,
      });
      // Solo marcamos la posición como publicada si el write fue exitoso.
      // Así, si las reglas RTDB bloqueaban la escritura, el próximo tick reintenta.
      _lastUploaded = pos;
    } catch (e) {
      debugPrint('🟥 presence publish FALLÓ (¿reglas RTDB?): $e');
    }
  }

  bool _shouldPublish(geo.Position p) {
    final last = _lastUploaded;
    if (last == null) return true;
    final d = geo.Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      p.latitude,
      p.longitude,
    );
    return d >= _minMeters;
  }
}
