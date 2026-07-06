// lib/core/services/mapa/mapbox/taxistas_markers_manager.dart
//
// Gestiona marcadores de taxistas online en el mapa Mapbox.
// Estrategia:
//   1. Al crear el manager, genera íconos PNG por tipo de servicio y los
//      registra como imágenes del estilo Mapbox (addStyleImage con RGBA).
//   2. Cada PointAnnotation referencia el ícono por nombre (iconImage).
//   3. Diff por uid: mueve, crea o borra según cambios en la lista.

import 'dart:typed_data';
import 'dart:ui' as ui;

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
  PointAnnotationManager? _manager;
  bool _iconsRegistered = false;
  bool _creatingManager = false;
  bool _disposed = false;

  /// uid → PointAnnotation activa
  final Map<String, PointAnnotation> _byUid = {};

  // Claves de tipo de servicio registradas en el estilo
  static const _tiposServicio = ['taxi', 'moto', 'confort', 'otro'];
  static const _iconSize = 48; // px del ícono generado
  static const _iconScale = 2.0; // pixel ratio → 48/2 = 24dp en pantalla

  static String _iconId(String key) => 'sv_taxista_$key';

  // ─────────────────────────────────────────────────────────────────────────
  // Inicialización
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _ensureManager() async {
    if (_manager != null) return;
    if (_creatingManager) return; // prevent concurrent creation
    _creatingManager = true;
    try {
      const maxAttempts = 8;
      int attempt = 0;
      while (_manager == null && attempt < maxAttempts) {
        try {
          _manager = await _map.annotations.createPointAnnotationManager();
        } catch (_) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 150 * attempt));
        }
      }
      if (_manager != null && !_iconsRegistered) {
        await _registrarIconosEstilo();
      }
    } finally {
      _creatingManager = false;
    }
  }

  /// Genera un ícono RGBA para cada tipo de servicio y lo registra en el
  /// estilo de Mapbox. Debe llamarse una vez después de crear el manager.
  Future<void> _registrarIconosEstilo() async {
    for (final key in _tiposServicio) {
      try {
        final rgba = await _generarIconoRgba(_servicioParaKey(key));
        await _map.style.addStyleImage(
          _iconId(key),
          _iconScale,
          MbxImage(width: _iconSize, height: _iconSize, data: rgba),
          false, // sdf
          [],
          [],
          null,
        );
        debugPrint('🎨 ícono registrado: ${_iconId(key)}');
      } catch (e) {
        debugPrint('🟥 error registrando ícono "$key": $e');
      }
    }
    _iconsRegistered = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API pública
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> sincronizar(List<TaxistaMarkerData> taxistas) async {
    if (_disposed) return;
    await _ensureManager();
    if (_manager == null || _disposed) return;

    final mgr = _manager!;
    final nuevos = {for (final t in taxistas) t.uid: t};

    // 1) Quitar del tracking los que ya no están
    //    No llamamos mgr.delete() — puede crashear con managerId stale
    //    si el estilo recargó entre el create y este delete.
    final toRemove =
        _byUid.keys.where((uid) => !nuevos.containsKey(uid)).toList();
    for (final uid in toRemove) {
      _byUid.remove(uid);
    }

    // 2) Crear o mover (nunca update — lanza Throwable nativo no capturable)
    for (final entry in nuevos.entries) {
      if (_disposed) return;
      final uid = entry.key;
      final t = entry.value;
      final existing = _byUid.remove(uid); // quita antes de cualquier await

      // Borrar anotación anterior al mover (delete es más seguro que update
      // porque no modifica datos nativos del objeto; si falla, continuamos).
      if (existing != null && !_disposed) {
        try {
          await mgr.delete(existing);
        } catch (_) {
          // Manager stale — abortar sync; el próximo creará manager fresco.
          if (!_disposed) {
            _manager = null;
            _byUid.clear();
            _iconsRegistered = false;
          }
          return;
        }
      }

      if (_disposed) return;

      final iconKey = _claveServicio(t.servicio);
      try {
        final created = await mgr.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(t.lng, t.lat)),
            iconImage: _iconId(iconKey),
            iconSize: 1.0,
            iconAnchor: IconAnchor.CENTER,
          ),
        );
        if (!_disposed) _byUid[uid] = created;
      } catch (e) {
        debugPrint('🟥 marker create FALLÓ uid=$uid: $e');
        if (!_disposed) {
          _manager = null;
          _byUid.clear();
          _iconsRegistered = false;
        }
        return;
      }
    }
  }

  Future<void> limpiar() async {
    final mgr = _manager;
    if (mgr == null) {
      _byUid.clear();
      return;
    }
    for (final p in List<PointAnnotation>.from(_byUid.values)) {
      try {
        await mgr.delete(p);
      } catch (_) {}
    }
    _byUid.clear();
  }

  void dispose() {
    _disposed = true;
    _byUid.clear();
    _manager = null;
    _iconsRegistered = false;
    _creatingManager = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Generación de íconos
  // ─────────────────────────────────────────────────────────────────────────

  /// Devuelve bytes en formato RGBA (lo que espera addStyleImage de Mapbox).
  ///
  /// Dibuja un badge circular con el GLIFO del vehículo según el servicio
  /// (auto/moto/confort) en lugar de un texto ("TAXI", "MOTO", …).
  static Future<Uint8List> _generarIconoRgba(String? servicio) async {
    const double sz = 48.0;
    final color = _colorPorServicio(servicio);
    final icon = _glyphPorServicio(servicio);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Sombra
    canvas.drawCircle(
      Offset(sz / 2 + 1.5, sz / 2 + 1.5),
      sz / 2 - 1,
      Paint()..color = const Color(0x55000000),
    );

    // Relleno
    canvas.drawCircle(
      Offset(sz / 2, sz / 2),
      sz / 2 - 1,
      Paint()..color = color,
    );

    // Borde blanco
    canvas.drawCircle(
      Offset(sz / 2, sz / 2),
      sz / 2 - 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Glifo del vehículo (fuente de íconos de Material)
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: sz * 0.5,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          height: 1,
        ),
      ),
    )..layout();

    tp.paint(
      canvas,
      Offset((sz - tp.width) / 2, (sz - tp.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_iconSize, _iconSize);
    // rawRgba es el formato que acepta MbxImage / addStyleImage
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers de clasificación
  // ─────────────────────────────────────────────────────────────────────────

  static String _claveServicio(String? s) {
    if (s == null) return 'otro';
    final l = s.trim().toLowerCase();
    if (l.contains('moto')) return 'moto';
    if (l.contains('confort') || l.contains('premium') || l.contains('vip')) {
      return 'confort';
    }
    if (l.contains('taxi') || l.contains('econ')) return 'taxi';
    return 'otro';
  }

  static String _servicioParaKey(String key) {
    switch (key) {
      case 'moto':
        return 'Moto Taxi';
      case 'confort':
        return 'Auto Confort';
      case 'taxi':
        return 'Taxi';
      default:
        return 'Otro';
    }
  }

  /// Glifo del vehículo según el servicio (para dibujar en el marcador).
  static IconData _glyphPorServicio(String? s) {
    switch (_claveServicio(s)) {
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'confort':
        return Icons.local_taxi_rounded;
      case 'taxi':
        return Icons.directions_car_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  static Color _colorPorServicio(String? s) {
    if (s == null) return const Color(0xFF3B82F6);
    final l = s.trim().toLowerCase();
    if (l.contains('moto')) return const Color(0xFFF59E0B); // naranja
    if (l.contains('confort') || l.contains('premium') || l.contains('vip')) {
      return const Color(0xFF8B5CF6); // violeta
    }
    if (l.contains('taxi') || l.contains('econ')) {
      return const Color(0xFF16A34A); // verde
    }
    return const Color(0xFF3B82F6); // azul
  }
}
