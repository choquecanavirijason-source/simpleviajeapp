// lib/core/services/mapa/mapbox/taxistas_markers_manager.dart
//
// Gestiona marcadores de taxistas online en el mapa Mapbox.
// Hace diff por uid: si un taxista ya está dibujado, solo mueve el círculo;
// si es nuevo, lo crea; si desapareció del set, lo borra.
//
// Eso evita destruir/recrear todos los markers en cada tick del stream,
// que es lo que generaría parpadeo y consumo alto.

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Datos mínimos para pintar un marcador de taxista.
class TaxistaMarkerData {
  final String uid;
  final double lat;
  final double lng;
  final String? servicio;

  const TaxistaMarkerData({
    required this.uid,
    required this.lat,
    required this.lng,
    this.servicio,
  });
}

class TaxistasMarkersManager {
  TaxistasMarkersManager(this._map);

  final MapboxMap _map;
  CircleAnnotationManager? _manager;

  /// uid → CircleAnnotation activa
  final Map<String, CircleAnnotation> _byUid = {};

  static const _radius = 9.0;
  static const _strokeWidth = 3.0;

  static const _colorTaxi = Color(0xFF16A34A); // verde
  static const _colorMoto = Color(0xFFF59E0B); // naranja
  static const _colorOtro = Color(0xFF3B82F6); // azul fallback

  Future<void> _ensureManager() async {
    if (_manager != null) return;
    const int maxAttempts = 8;
    int attempt = 0;
    while (_manager == null && attempt < maxAttempts) {
      try {
        _manager = await _map.annotations.createCircleAnnotationManager();
        break;
      } catch (_) {
        attempt++;
        await Future.delayed(Duration(milliseconds: 120 * attempt));
      }
    }
  }

  /// Sincroniza el conjunto de markers con [taxistas]:
  /// - mueve los que ya existen,
  /// - agrega los nuevos,
  /// - borra los que ya no aparecen.
  Future<void> sincronizar(List<TaxistaMarkerData> taxistas) async {
    await _ensureManager();
    if (_manager == null) return;

    final mgr = _manager!;
    final nuevos = {for (final t in taxistas) t.uid: t};

    // 1) Borrar los que ya no están
    final toRemove = _byUid.keys.where((uid) => !nuevos.containsKey(uid)).toList();
    for (final uid in toRemove) {
      final c = _byUid.remove(uid);
      if (c != null) {
        try {
          await mgr.delete(c);
        } catch (_) {}
      }
    }

    // 2) Crear o actualizar
    for (final entry in nuevos.entries) {
      final uid = entry.key;
      final t = entry.value;
      final existing = _byUid[uid];
      final color = _colorPorServicio(t.servicio);

      if (existing != null) {
        // Actualizar geometría in-place (no destruir/crear).
        existing.geometry = Point(coordinates: Position(t.lng, t.lat));
        existing.circleColor = color.value;
        try {
          await mgr.update(existing);
        } catch (_) {}
      } else {
        try {
          final created = await mgr.create(
            CircleAnnotationOptions(
              geometry: Point(coordinates: Position(t.lng, t.lat)),
              circleRadius: _radius,
              circleColor: color.value,
              circleOpacity: 1.0,
              circleStrokeWidth: _strokeWidth,
              circleStrokeColor: Colors.white.value,
            ),
          );
          _byUid[uid] = created;
        } catch (_) {}
      }
    }
  }

  Future<void> limpiar() async {
    final mgr = _manager;
    if (mgr == null) {
      _byUid.clear();
      return;
    }
    for (final c in List<CircleAnnotation>.from(_byUid.values)) {
      try {
        await mgr.delete(c);
      } catch (_) {}
    }
    _byUid.clear();
  }

  void dispose() {
    _byUid.clear();
    _manager = null;
  }

  Color _colorPorServicio(String? s) {
    if (s == null) return _colorOtro;
    final lower = s.trim().toLowerCase();
    if (lower.contains('moto')) return _colorMoto;
    if (lower.contains('taxi')) return _colorTaxi;
    return _colorOtro;
  }
}
