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
    await _ensureManager();
    if (_manager == null) return;

    final mgr = _manager!;
    final nuevos = {for (final t in taxistas) t.uid: t};

    // 1) Borrar los que ya no están
    final toRemove =
        _byUid.keys.where((uid) => !nuevos.containsKey(uid)).toList();
    for (final uid in toRemove) {
      final p = _byUid.remove(uid);
      if (p != null) {
        try {
          await mgr.delete(p);
        } catch (e) {
          debugPrint('🟥 delete marker $uid: $e');
        }
      }
    }

    // 2) Crear o actualizar
    for (final entry in nuevos.entries) {
      final uid = entry.key;
      final t = entry.value;
      final existing = _byUid[uid];

      if (existing != null) {
        existing.geometry = Point(coordinates: Position(t.lng, t.lat));
        try {
          await mgr.update(existing);
        } catch (_) {}
      } else {
        final iconKey = _claveServicio(t.servicio);
        debugPrint(
          '🚖 crear marker uid=$uid servicio=${t.servicio} icon=${_iconId(iconKey)}',
        );
        try {
          final created = await mgr.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(t.lng, t.lat)),
              iconImage: _iconId(iconKey),
              iconSize: 1.0,
              iconAnchor: IconAnchor.CENTER,
            ),
          );
          _byUid[uid] = created;
          debugPrint('🚖 marker creado OK uid=$uid');
        } catch (e) {
          debugPrint('🟥 marker create FALLÓ uid=$uid: $e');
        }
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
    _byUid.clear();
    _manager = null;
    _iconsRegistered = false;
    _creatingManager = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Generación de íconos
  // ─────────────────────────────────────────────────────────────────────────

  /// Devuelve bytes en formato RGBA (lo que espera addStyleImage de Mapbox).
  static Future<Uint8List> _generarIconoRgba(String? servicio) async {
    const double sz = 48.0;
    final color = _colorPorServicio(servicio);
    final label = _labelPorServicio(servicio);

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

    // Texto del servicio
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: sz);

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

  static String _labelPorServicio(String? s) {
    if (s == null) return 'AUTO';
    final l = s.trim().toLowerCase();
    if (l.contains('moto')) return 'MOTO';
    if (l.contains('confort') || l.contains('premium') || l.contains('vip')) {
      return 'CONF';
    }
    if (l.contains('taxi')) return 'TAXI';
    // Servicio desconocido: primeras 4 letras
    final clean = s.trim().toUpperCase().replaceAll(' ', '');
    return clean.substring(0, clean.length.clamp(0, 4));
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
