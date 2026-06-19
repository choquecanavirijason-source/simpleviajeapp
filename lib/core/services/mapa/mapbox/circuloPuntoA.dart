import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart';

/// 👇 Solo queda el estilo simple
enum PuntoAStyle { simple }

/// Interfaz común
abstract class IUserCircleManager {
  Future<void> addUserCircle(double lat, double lng);
  void dispose();
}

/// =========================
///  SIMPLE (círculo fijo)
/// =========================
class UserCircleManager implements IUserCircleManager {
  final MapboxMap _map;
  CircleAnnotationManager? _manager;
  CircleAnnotation? _dot;

  UserCircleManager(this._map);

  @override
  Future<void> addUserCircle(double lat, double lng) async {
    // A veces el mapa aún no tiene listo el manager de anotaciones en Android.
    // Hacemos un intento robusto con reintentos cortos para evitar el crash:
    await _ensureManagerReady();
    if (_manager == null) {
      debugPrint(
        '⚠️ No fue posible crear CircleAnnotationManager, se omite addUserCircle',
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

    _dot = await _manager!.create(circleOptions);
  }

  /// Intenta crear el CircleAnnotationManager con reintentos breves.
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
        // Espera creciente: 150ms, 300ms, 450ms... hasta 1500ms
        await Future.delayed(Duration(milliseconds: 150 * attempt));
      }
    }

    if (_manager == null) {
      debugPrint(
        '❌ _ensureManagerReady (passenger user circle) falló después de $maxAttempts intentos: $lastError',
      );
    }
  }

  @override
  void dispose() {
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
