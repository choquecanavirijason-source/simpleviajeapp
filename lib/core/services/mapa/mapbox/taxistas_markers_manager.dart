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
  bool _creatingManager = false;
  bool _disposed = false;

  /// uid → PointAnnotation activa
  final Map<String, PointAnnotation> _byUid = {};

  /// PNG por tipo de servicio (se generan una vez).
  static final Map<String, Uint8List> _pngPorTipo = {};

  static Future<Uint8List> _pngDe(String key) async =>
      _pngPorTipo[key] ??= await _generarIconoRgba(
        _servicioParaKey(key),
        formato: ui.ImageByteFormat.png,
      );

  static const _iconSize = 48; // px del ícono generado

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
      // Ya no se registran imágenes en el estilo: addStyleImage falla en
      // algunos dispositivos ("Unable to establish connection on channel
      // ...StyleManager.addStyleImage") y el marcador quedaba invisible.
      // Ahora cada marcador lleva su PNG en PointAnnotationOptions.image.
    } finally {
      _creatingManager = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API pública
  // ─────────────────────────────────────────────────────────────────────────

  // Serialización: si llega una lista mientras otra se está aplicando, se
  // guarda la ÚLTIMA y se aplica al terminar (antes se descartaba en
  // silencio si el manager aún se estaba creando, y el taxi no aparecía).
  bool _sincronizando = false;
  List<TaxistaMarkerData>? _pendiente;

  Future<void> sincronizar(List<TaxistaMarkerData> taxistas) async {
    if (_disposed) return;
    if (_sincronizando) {
      _pendiente = taxistas;
      return;
    }
    _sincronizando = true;
    try {
      var lista = taxistas;
      var reintentos = 0;
      while (true) {
        final ok = await _sincronizarUnaVez(lista);
        if (!ok && reintentos < 3 && !_disposed) {
          reintentos++;
          await Future.delayed(Duration(milliseconds: 300 * reintentos));
          continue; // reintenta la misma lista con un manager nuevo
        }
        reintentos = 0;
        final siguiente = _pendiente;
        if (siguiente == null || _disposed) break;
        _pendiente = null;
        lista = siguiente;
      }
    } finally {
      _sincronizando = false;
    }
  }

  /// Devuelve false si el manager quedó inválido y hay que reintentar.
  Future<bool> _sincronizarUnaVez(List<TaxistaMarkerData> taxistas) async {
    if (_disposed) return true;
    await _ensureManager();
    if (_disposed) return true;
    if (_manager == null) return false;

    final mgr = _manager!;
    final nuevos = {for (final t in taxistas) t.uid: t};

    // 1) Borrar del mapa los que ya no están (antes solo se quitaban del
    //    tracking y su ícono quedaba "fantasma" en el mapa).
    final toRemove =
        _byUid.keys.where((uid) => !nuevos.containsKey(uid)).toList();
    for (final uid in toRemove) {
      final p = _byUid.remove(uid);
      if (p == null || _disposed) continue;
      try {
        await mgr.delete(p);
      } catch (_) {
        // Manager stale (el estilo recargó): reiniciar; el próximo sync
        // creará un manager nuevo y repintará todo.
        if (!_disposed) {
          _manager = null;
          _byUid.clear();
        }
        return false;
      }
    }

    // 2) Crear o mover (nunca update — lanza Throwable nativo no capturable)
    for (final entry in nuevos.entries) {
      if (_disposed) return true;
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
          }
          return false;
        }
      }

      if (_disposed) return true;

      final iconKey = _claveServicio(t.servicio);
      try {
        final png = await _pngDe(iconKey);
        if (_disposed) return true;
        final created = await mgr.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(t.lng, t.lat)),
            image: png,
            // El PNG es de 48 px; en pantallas de alta densidad se veía
            // diminuto, así que se escala para que mida ~36 dp.
            iconSize: 2.0,
            iconAnchor: IconAnchor.CENTER,
          ),
        );
        if (!_disposed) _byUid[uid] = created;
      } catch (e) {
        debugPrint('🟥 marker create FALLÓ uid=$uid: $e');
        if (!_disposed) {
          _manager = null;
          _byUid.clear();
        }
        return false;
      }
    }
    return true;
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
    _creatingManager = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Generación de íconos
  // ─────────────────────────────────────────────────────────────────────────

  /// Devuelve bytes en formato RGBA (lo que espera addStyleImage de Mapbox).
  ///
  /// Dibuja un badge circular con el GLIFO del vehículo según el servicio
  /// (auto/moto/confort) en lugar de un texto ("TAXI", "MOTO", …).
  static Future<Uint8List> _generarIconoRgba(
    String? servicio, {
    ui.ImageByteFormat formato = ui.ImageByteFormat.rawRgba,
  }) async {
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
    final byteData = await image.toByteData(format: formato);
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
