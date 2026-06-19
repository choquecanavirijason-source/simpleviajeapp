import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart' show PlatformException;

/// 👇 NUEVO: enum para elegir estilo
enum PuntoAStyle { simple, radar }

/// 👇 NUEVO: interfaz común
abstract class IUserCircleManager {
  Future<void> addUserCircle(double lat, double lng);
  void dispose();
}

/// =========================
///  SIMPLE (tu clase actual)
/// =========================
class UserCircleManager implements IUserCircleManager {
  final MapboxMap _map;
  CircleAnnotationManager? _manager;
  CircleAnnotation? _dot;

  UserCircleManager(this._map);

  @override
  Future<void> addUserCircle(double lat, double lng) async {
    // A veces el mapa aún no tiene listo el manager de anotaciones en Android.
    // Reintentamos varias veces antes de fallar para evitar la excepción nativa.
    await _ensureManagerReady();
    if (_manager == null) {
      debugPrint(
        '⚠️ No fue posible crear CircleAnnotationManager (taxi), se omite addUserCircle',
      );
      return;
    }

    final circleOptions = CircleAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      circleRadius: 6,
      circleColor: const Color(0xFFFFFFFF).value,
      circleOpacity: 1,
      circleStrokeWidth: 6,
      circleStrokeColor: const Color(0xFF007AFF).value,
    );

    await _manager!.create(circleOptions);
  }

  /// Intenta crear el CircleAnnotationManager con reintentos cortos.
  Future<void> _ensureManagerReady() async {
    if (_manager != null) return;

    const int maxAttempts = 10; // 🔧 Aumentado de 6 a 10 intentos
    int attempt = 0;
    Object? lastError;

    while (_manager == null && attempt < maxAttempts) {
      try {
        _manager = await _map.annotations.createCircleAnnotationManager();
        break;
      } catch (e) {
        lastError = e;
        attempt++;
        await Future.delayed(Duration(milliseconds: 150 * attempt));
      }
    }

    if (_manager == null) {
      debugPrint(
        '❌ _ensureManagerReady (taxi user circle) falló después de $maxAttempts intentos: $lastError',
      );
    }
  }

  @override
  void dispose() {
    // 🔥 limpia
    try {
      _manager?.deleteAll();
    } catch (_) {
      try {
        if (_dot != null) _manager?.delete(_dot!);
      } catch (_) {}
    }
    _dot = null;
    _manager = null;
  }
}

/// ========================
///  RADAR / PULSE
/// ========================
class RadarUserCircleManager implements IUserCircleManager {
  final MapboxMap _map;
  CircleAnnotationManager? _manager;

  // Tres ondas
  CircleAnnotation? _wave1;
  CircleAnnotation? _wave2;
  CircleAnnotation? _wave3;

  // Punto fijo central (10px)
  CircleAnnotation? _centerDot;

  Timer? _timer;
  DateTime? _t0;
  bool _updating = false;
  bool _disposed = false;

  final Color color;
  final double minRadius;
  final double maxRadius;
  final Duration period; // ciclo completo (ej. 6s en tu config)
  final double baseDotRadius; // no usado aquí, se mantiene por firma
  final double strokeWidth; // idem

  /// Gap fijo entre ondas: 2 s (tu cambio)
  static const double _offsetGapMs = 2000.0; // 2s
  double get _offset1 => 0.0;
  double get _offset2 => _offsetGapMs; // ~2s
  double get _offset3 => _offsetGapMs * 2.0; // ~4s

  RadarUserCircleManager(
    this._map, {
    this.color = const Color(0xFF2563EB),
    this.minRadius = 5.0,
    this.maxRadius = 155.0,
    this.period = const Duration(seconds: 6),
    this.baseDotRadius = 12,
    this.strokeWidth = 2.5,
  });

  @override
  Future<void> addUserCircle(double lat, double lng) async {
    if (_disposed) return;

    // 👇 FIX: crear manager con retry para evitar crash "No manager found"
    await _ensureRadarManagerReady();
    if (_manager == null) {
      debugPrint(
        '⚠️ No se pudo crear CircleAnnotationManager (radar taxi), se omite',
      );
      return;
    }

    final p = Point(coordinates: Position(lng, lat));

    if (_wave1 == null ||
        _wave2 == null ||
        _wave3 == null ||
        _centerDot == null) {
      // Centro fijo 10px (mismo color que las ondas)
      _centerDot = await _manager!.create(
        CircleAnnotationOptions(
          geometry: p,
          circleRadius: 8, // 👈 fijo
          circleColor: color.value,
          circleOpacity: 1.0,
          circleStrokeWidth: 0,
          circleStrokeColor: Colors.transparent.value,
        ),
      );

      // Ondas
      _wave1 = await _manager!.create(
        CircleAnnotationOptions(
          geometry: p,
          circleRadius: minRadius,
          circleColor: color.withOpacity(1.0).value,
          circleOpacity: 1.0,
          circleStrokeWidth: 0,
          circleStrokeColor: Colors.transparent.value,
        ),
      );
      _wave2 = await _manager!.create(
        CircleAnnotationOptions(
          geometry: p,
          circleRadius: minRadius,
          circleColor: color.withOpacity(0.3).value,
          circleOpacity: 0.3,
          circleStrokeWidth: 0,
          circleStrokeColor: Colors.transparent.value,
        ),
      );
      _wave3 = await _manager!.create(
        CircleAnnotationOptions(
          geometry: p,
          circleRadius: minRadius,
          circleColor: color.withOpacity(0.3).value,
          circleOpacity: 0.3,
          circleStrokeWidth: 0,
          circleStrokeColor: Colors.transparent.value,
        ),
      );

      _startPulse();
    } else {
      // Reubicar si cambiaste coords
      _centerDot!.geometry = p;
      await _safeUpdate(_centerDot!);
      _wave1!.geometry = p;
      await _safeUpdate(_wave1!);
      _wave2!.geometry = p;
      await _safeUpdate(_wave2!);
      _wave3!.geometry = p;
      await _safeUpdate(_wave3!);
    }
  }

  void _startPulse() {
    if (_disposed) return;
    _t0 = DateTime.now();
    _timer?.cancel();
    // 30fps estable
    _timer = Timer.periodic(const Duration(milliseconds: 33), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      _tick();
    });
  }

  Future<void> _safeUpdate(CircleAnnotation ann) async {
    if (_disposed || _manager == null) return;
    try {
      await _manager!.update(ann);
    } on PlatformException catch (e) {
      debugPrint(
        '🛑 RadarUserCircleManager: canal cerrado, deteniendo animación: $e',
      );
      _hardStop();
    } catch (e) {
      debugPrint('🛑 RadarUserCircleManager: error inesperado en update: $e');
      _hardStop();
    }
  }

  void _tick() async {
    if (_disposed || _manager == null || _t0 == null) return;
    if (_wave1 == null || _wave2 == null || _wave3 == null) return;
    if (_updating) return;
    _updating = true;

    try {
      final elapsedMs = DateTime.now()
          .difference(_t0!)
          .inMilliseconds
          .toDouble();
      final T = period.inMilliseconds.toDouble();

      double phase(double offsetMs) =>
          ((((elapsedMs - offsetMs) % T) + T) % T) / T; // 0..1 con desfase

      final t1 = phase(_offset1);
      final t2 = phase(_offset2);
      final t3 = phase(_offset3);

      // Radio 5 → 150 (tu config)
      double radius(double t) => minRadius + (maxRadius - minRadius) * t;

      // Opacidad 1.0 → 0.1 (tal como tu código actual: 1 - 0.9*t)
      // Si quieres 1.0 → 0.3, usa: 1.0 - 0.7*t
      double opacity(double t) => 1.0 - 0.9 * t;

      final r1 = radius(t1), o1 = opacity(t1);
      final r2 = radius(t2), o2 = opacity(t2);
      final r3 = radius(t3), o3 = opacity(t3);

      _wave1!
        ..circleRadius = r1
        ..circleColor = color.withOpacity(o1).value
        ..circleOpacity = o1;
      await _safeUpdate(_wave1!);

      _wave2!
        ..circleRadius = r2
        ..circleColor = color.withOpacity(o2).value
        ..circleOpacity = o2;
      await _safeUpdate(_wave2!);

      _wave3!
        ..circleRadius = r3
        ..circleColor = color.withOpacity(o3).value
        ..circleOpacity = o3;
      await _safeUpdate(_wave3!);
    } finally {
      _updating = false;
    }
  }

  /// Intenta crear el CircleAnnotationManager con reintentos (radar taxi).
  Future<void> _ensureRadarManagerReady() async {
    if (_manager != null) return;

    const int maxAttempts = 10; // 🔧 Aumentado de 6 a 10 intentos
    int attempt = 0;
    Object? lastError;

    while (_manager == null && attempt < maxAttempts) {
      try {
        _manager = await _map.annotations.createCircleAnnotationManager();
        break;
      } catch (e) {
        lastError = e;
        attempt++;
        await Future.delayed(Duration(milliseconds: 150 * attempt));
      }
    }

    if (_manager == null) {
      debugPrint(
        '❌ _ensureRadarManagerReady (taxi radar) falló después de $maxAttempts intentos: $lastError',
      );
    }
  }

  void _hardStop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _deleteAllSafe() async {
    try {
      await _manager?.deleteAll();
    } catch (_) {
      try {
        if (_centerDot != null) await _manager?.delete(_centerDot!);
      } catch (_) {}
      try {
        if (_wave1 != null) await _manager?.delete(_wave1!);
      } catch (_) {}
      try {
        if (_wave2 != null) await _manager?.delete(_wave2!);
      } catch (_) {}
      try {
        if (_wave3 != null) await _manager?.delete(_wave3!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _hardStop();
    _deleteAllSafe();
    _centerDot = null;
    _wave1 = null;
    _wave2 = null;
    _wave3 = null;
    _manager = null;
  }
}

/*
class RadarUserCircleManager implements IUserCircleManager {
  final MapboxMap _map;
  CircleAnnotationManager? _manager;

  CircleAnnotation? _baseDot;
  CircleAnnotation? _rip1;
  CircleAnnotation? _rip2;
  CircleAnnotation? _rip3;

  Timer? _timer;
  DateTime? _t0;
  bool _updating = false;

  final Color color;
  final double minRadius;
  final double maxRadius;
  final Duration period;
  final double baseDotRadius;
  final double strokeWidth;

  RadarUserCircleManager(
    this._map, {
    this.color = const Color(0xFF2563EB),
    this.minRadius = 22,
    this.maxRadius = 220,
    this.period = const Duration(milliseconds: 6200),
    this.baseDotRadius = 9,
    this.strokeWidth = 2.5,
  });

  @override
  Future<void> addUserCircle(double lat, double lng) async {
    _manager ??= await _map.annotations.createCircleAnnotationManager();
    final p = Point(coordinates: Position(lng, lat));

    if (_baseDot == null) {
      _baseDot = await _manager!.create(
        CircleAnnotationOptions(
          geometry: p,
          circleRadius: baseDotRadius,
          circleColor: color.value,
          circleOpacity: 1,
          circleStrokeWidth: 0,
          circleStrokeColor: color.value,
        ),
      );

      _rip1 = await _manager!.create(_rippleOptions(p));
      _rip2 = await _manager!.create(_rippleOptions(p));
      _rip3 = await _manager!.create(_rippleOptions(p));

      _startPulse();
    } else {
      _baseDot!.geometry = p; await _manager!.update(_baseDot!);
      _rip1!.geometry = p;    await _manager!.update(_rip1!);
      _rip2!.geometry = p;    await _manager!.update(_rip2!);
      _rip3!.geometry = p;    await _manager!.update(_rip3!);
    }
  }

  CircleAnnotationOptions _rippleOptions(Point p) => CircleAnnotationOptions(
        geometry: p,
        circleRadius: 0.1,
        circleColor: color.withOpacity(0).value,
        circleOpacity: 0,
        circleStrokeWidth: strokeWidth,
        circleStrokeColor: color.withOpacity(0).value,
      );

  void _startPulse() {
    _t0 = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() async {
    if (_manager == null || _baseDot == null || _rip1 == null || _rip2 == null || _rip3 == null || _t0 == null) return;
    if (_updating) return;
    _updating = true;

    try {
      final elapsed = DateTime.now().difference(_t0!);
      final T = period.inMilliseconds.toDouble();
      final t = (elapsed.inMilliseconds % T) / T;

      await _animateRipple(_rip1!, (t + 0 / 3) % 1.0);
      await _animateRipple(_rip2!, (t + 1 / 3) % 1.0);
      await _animateRipple(_rip3!, (t + 2 / 3) % 1.0);

      final pulse = baseDotRadius + math.sin(t * 2 * math.pi) * 0.8;
      _baseDot!.circleRadius = pulse;
      await _manager!.update(_baseDot!);
    } finally {
      _updating = false;
    }
  }

  Future<void> _animateRipple(CircleAnnotation rip, double phase) async {
    final r = _lerp(minRadius, maxRadius, phase);
    final baseOpacity = (1 - phase) * 0.35;
    final fillOpacity = baseOpacity * 0.35;
    final strokeOpacity = baseOpacity;

    rip.circleRadius = r;
    rip.circleColor = color.withOpacity(fillOpacity).value;
    rip.circleOpacity = fillOpacity;
    rip.circleStrokeColor = color.withOpacity(strokeOpacity).value;
    rip.circleStrokeWidth = strokeWidth;

    await _manager!.update(rip);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _manager = null;
    _baseDot = null;
    _rip1 = null;
    _rip2 = null;
    _rip3 = null;
  }
}

*/
