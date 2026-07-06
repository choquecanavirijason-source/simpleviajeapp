// lib/core/services/mapa_taxi/mapbox_taxi/vehiculo_marker_manager.dart
//
// Marcador del vehículo del conductor con MOVIMIENTO FLUIDO.
//
// Estrategia (evita el "salto" y el parpadeo del enfoque anterior que
// borraba y recreaba un círculo en cada tick):
//   1. Genera por código un ícono PNG/RGBA por tipo de servicio (auto, moto,
//      confort, otro) y lo registra como imagen del estilo Mapbox. No requiere
//      assets externos.
//   2. Dibuja el vehículo con un source GeoJSON + SymbolLayer (mismo patrón
//      confiable que usa la ruta), no con PointAnnotation (cuyo update()
//      lanza excepciones nativas en este proyecto).
//   3. Al recibir una nueva posición, INTERPOLA suavemente entre la posición
//      actual y la nueva (~900 ms, easeInOut) moviendo la data del source,
//      logrando un deslizamiento tipo Uber/InDrive en lugar de un salto.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class VehiculoMarkerManager {
  VehiculoMarkerManager(this._map);
  final MapboxMap _map;

  static const _sourceId = 'vehiculo_source';
  static const _layerId = 'vehiculo_layer';

  static const _tipos = ['auto', 'moto', 'confort', 'otro'];
  static const _iconPx = 96; // tamaño del bitmap generado
  static const _iconScale = 3.0; // 96 / 3 = 32dp en pantalla

  static String _iconId(String key) => 'sv_vehiculo_$key';

  bool _iconsRegistered = false;
  bool _layerReady = false;
  bool _creating = false;
  bool _disposed = false;

  // Estado de animación / posición actual "visible" del marcador
  Timer? _animTimer;
  double? _curLat;
  double? _curLng;
  String _curKey = 'auto';

  // ───────────────────────────────────────────────────────────────────────
  // API pública
  // ───────────────────────────────────────────────────────────────────────

  /// Coloca/actualiza el vehículo en (lat,lng) animando desde la posición
  /// anterior. [servicio] elige el ícono (auto/moto/confort/…).
  Future<void> actualizar(double lat, double lng, {String? servicio}) async {
    if (_disposed) return;
    final key = _claveServicio(servicio);

    await _ensureLayer(key);
    if (_disposed || !_layerReady) return;

    // Si cambió el tipo de servicio, cambia el ícono de la capa.
    if (key != _curKey) {
      _curKey = key;
      try {
        await _map.style.setStyleLayerProperty(
          _layerId,
          'icon-image',
          _iconId(key),
        );
      } catch (_) {}
    }

    // Primera colocación o salto grande (teleport): sin animación.
    final tienePrevia = _curLat != null && _curLng != null;
    final saltoGrande = tienePrevia &&
        _distanciaMetros(_curLat!, _curLng!, lat, lng) > 500;

    if (!tienePrevia || saltoGrande) {
      _animTimer?.cancel();
      _curLat = lat;
      _curLng = lng;
      await _setData(lat, lng);
      return;
    }

    _animarHasta(lat, lng);
  }

  /// Borra el vehículo del mapa (capa + source).
  Future<void> limpiar() async {
    _animTimer?.cancel();
    _animTimer = null;
    _curLat = null;
    _curLng = null;
    if (_disposed) return;
    try {
      if (await _map.style.styleLayerExists(_layerId)) {
        await _map.style.removeStyleLayer(_layerId);
      }
    } catch (_) {}
    try {
      if (await _map.style.styleSourceExists(_sourceId)) {
        await _map.style.removeStyleSource(_sourceId);
      }
    } catch (_) {}
    _layerReady = false;
  }

  void dispose() {
    _disposed = true;
    _animTimer?.cancel();
    _animTimer = null;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Animación
  // ───────────────────────────────────────────────────────────────────────

  void _animarHasta(double toLat, double toLng) {
    _animTimer?.cancel();

    final fromLat = _curLat!;
    final fromLng = _curLng!;
    const dur = 900; // ms — algo menor que el intervalo de tracking
    const frameMs = 16; // ~60 fps
    final inicio = DateTime.now();

    _animTimer = Timer.periodic(const Duration(milliseconds: frameMs), (
      t,
    ) async {
      if (_disposed) {
        t.cancel();
        return;
      }
      final ms = DateTime.now().difference(inicio).inMilliseconds;
      final p = (ms / dur).clamp(0.0, 1.0);
      final e = _easeInOut(p);

      final lat = fromLat + (toLat - fromLat) * e;
      final lng = fromLng + (toLng - fromLng) * e;
      _curLat = lat;
      _curLng = lng;

      await _setData(lat, lng);

      if (p >= 1.0) t.cancel();
    });
  }

  static double _easeInOut(double p) =>
      p < 0.5 ? 2 * p * p : 1 - math.pow(-2 * p + 2, 2) / 2;

  // ───────────────────────────────────────────────────────────────────────
  // Source / Layer
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _ensureLayer(String iconKey) async {
    if (_layerReady || _disposed) return;
    if (_creating) return;
    _creating = true;
    try {
      if (!_iconsRegistered) {
        await _registrarIconos();
      }

      final geojson = _geojson(_curLat ?? 0, _curLng ?? 0);

      try {
        if (!await _map.style.styleSourceExists(_sourceId)) {
          await _map.style.addSource(
            GeoJsonSource(id: _sourceId, data: geojson),
          );
        }
        if (!await _map.style.styleLayerExists(_layerId)) {
          await _map.style.addLayer(
            SymbolLayer(
              id: _layerId,
              sourceId: _sourceId,
              iconImage: _iconId(iconKey),
              iconSize: 1.0,
              iconAllowOverlap: true,
              iconIgnorePlacement: true,
              iconAnchor: IconAnchor.CENTER,
            ),
          );
        }
        _curKey = iconKey;
        _layerReady = true;
      } catch (e) {
        debugPrint('🟥 VehiculoMarker _ensureLayer: $e');
      }
    } finally {
      _creating = false;
    }
  }

  Future<void> _setData(double lat, double lng) async {
    if (_disposed) return;
    try {
      await _map.style.setStyleSourceProperty(
        _sourceId,
        'data',
        _geojson(lat, lng),
      );
    } catch (_) {}
  }

  static String _geojson(double lat, double lng) => jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': const {},
            'geometry': {
              'type': 'Point',
              'coordinates': [lng, lat],
            },
          },
        ],
      });

  // ───────────────────────────────────────────────────────────────────────
  // Íconos generados por código
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _registrarIconos() async {
    for (final key in _tipos) {
      try {
        final rgba = await _generarIconoRgba(key);
        await _map.style.addStyleImage(
          _iconId(key),
          _iconScale,
          MbxImage(width: _iconPx, height: _iconPx, data: rgba),
          false, // sdf
          [],
          [],
          null,
        );
      } catch (e) {
        debugPrint('🟥 VehiculoMarker icono "$key": $e');
      }
    }
    _iconsRegistered = true;
  }

  static Future<Uint8List> _generarIconoRgba(String key) async {
    final size = _iconPx.toDouble();
    final center = Offset(size / 2, size / 2);
    final color = _colorPorKey(key);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Sombra
    canvas.drawCircle(
      center.translate(0, 2.5),
      size / 2 - 6,
      Paint()..color = const Color(0x44000000),
    );
    // Relleno
    canvas.drawCircle(center, size / 2 - 8, Paint()..color = color);
    // Borde blanco
    canvas.drawCircle(
      center,
      size / 2 - 8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Glifo del vehículo (fuente de íconos de Material)
    final icon = _glyphPorKey(key);
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.46,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    final img = await recorder.endRecording().toImage(_iconPx, _iconPx);
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    return bd!.buffer.asUint8List();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Clasificación de servicio → ícono / color
  // ───────────────────────────────────────────────────────────────────────

  static String _claveServicio(String? s) {
    if (s == null) return 'auto';
    final l = s.trim().toLowerCase();
    if (l.contains('moto')) return 'moto';
    if (l.contains('confort') || l.contains('premium') || l.contains('vip')) {
      return 'confort';
    }
    if (l.contains('taxi') || l.contains('auto') || l.contains('econ')) {
      return 'auto';
    }
    return 'otro';
  }

  static IconData _glyphPorKey(String key) {
    switch (key) {
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'confort':
        return Icons.local_taxi_rounded;
      case 'auto':
        return Icons.directions_car_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }

  static Color _colorPorKey(String key) {
    switch (key) {
      case 'moto':
        return const Color(0xFFF59E0B); // naranja
      case 'confort':
        return const Color(0xFF8B5CF6); // violeta
      case 'auto':
        return const Color(0xFF16A34A); // verde
      default:
        return const Color(0xFF3B82F6); // azul
    }
  }

  static double _distanciaMetros(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const p = 0.017453292519943295; // pi/180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lng2 - lng1) * p)) /
            2;
    return 12742000 * math.asin(math.sqrt(a));
  }
}
