// Radar animado estilo Uber/Yango: anillos concéntricos que se expanden
// desde el punto del usuario, con íconos de vehículo y badge de conductores.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Datos del taxi más cercano para dibujarlo en su dirección real.
class RadarTaxiCercano {
  final double distanciaKm;

  /// Rumbo desde el pasajero hacia el taxi (0 = norte/arriba, 90 = este).
  final double rumboGrados;
  final String? servicio;

  const RadarTaxiCercano({
    required this.distanciaKm,
    required this.rumboGrados,
    this.servicio,
  });

  /// Texto corto de distancia: "350 m" o "1.2 km".
  String get distanciaTexto => distanciaKm < 1
      ? '${(distanciaKm * 1000).round()} m'
      : '${distanciaKm.toStringAsFixed(1)} km';
}

class RadarBuscando extends StatefulWidget {
  final int conductoresCercanos;
  final List<String> serviciosCercanos;

  /// Taxi más cercano; si no es null se dibuja resaltado en su dirección.
  final RadarTaxiCercano? masCercano;

  const RadarBuscando({
    super.key,
    this.conductoresCercanos = 0,
    this.serviciosCercanos = const [],
    this.masCercano,
  });

  @override
  State<RadarBuscando> createState() => _RadarBuscandoState();
}

// Representa un tipo de vehículo único para mostrar en el radar
class _TipoVehiculo {
  final IconData icono;
  final Color color;
  const _TipoVehiculo(this.icono, this.color);
}

class _RadarBuscandoState extends State<RadarBuscando>
    with TickerProviderStateMixin {
  static const _colorBase = Color(0xFF16A34A);
  static const int _waves = 3;
  static const double _radarSize = 230;
  static const double _center = _radarSize / 2; // 115
  static const double _iconRadius = 84; // distancia desde el centro
  static const double _iconBadgeSize = 38;
  static const double _nearestBadgeSize = 48;

  final List<AnimationController> _ctrls = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _waves; i++) {
      _ctrls.add(
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2400),
        ),
      );
    }
    _stagger();
  }

  Future<void> _stagger() async {
    for (int i = 0; i < _waves; i++) {
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      if (mounted) _ctrls[i].repeat();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  // Deriva tipos únicos de vehículo a partir de la lista de servicios
  static _TipoVehiculo _tipoDe(String? servicio) {
    final l = (servicio ?? '').toLowerCase();
    if (l.contains('moto')) {
      return const _TipoVehiculo(Icons.two_wheeler_rounded, Color(0xFFF59E0B));
    }
    if (l.contains('confort') || l.contains('premium') || l.contains('vip')) {
      return const _TipoVehiculo(Icons.drive_eta_rounded, Color(0xFF8B5CF6));
    }
    return const _TipoVehiculo(Icons.directions_car_filled_rounded, _colorBase);
  }

  List<_TipoVehiculo> _tiposUnicos() {
    final seen = <String>{};
    final result = <_TipoVehiculo>[];
    for (final s in widget.serviciosCercanos) {
      final l = s.toLowerCase();
      final String key;
      if (l.contains('moto')) {
        key = 'moto';
      } else if (l.contains('confort') ||
          l.contains('premium') ||
          l.contains('vip')) {
        key = 'confort';
      } else {
        key = 'auto';
      }
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(
          _TipoVehiculo(
            key == 'moto'
                ? Icons.two_wheeler_rounded
                : key == 'confort'
                ? Icons.drive_eta_rounded
                : Icons.directions_car_filled_rounded,
            key == 'moto'
                ? const Color(0xFFF59E0B)
                : key == 'confort'
                ? const Color(0xFF8B5CF6)
                : _colorBase,
          ),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tipos = _tiposUnicos();
    final count = tipos.length;

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _radarSize,
            height: _radarSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anillos pulsantes
                for (int i = 0; i < _waves; i++)
                  AnimatedBuilder(
                    animation: _ctrls[i],
                    builder: (_, __) {
                      final v = _ctrls[i].value;
                      final size = 56.0 + 156.0 * v;
                      final opacity = (1.0 - v).clamp(0.0, 1.0);
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorBase.withValues(alpha: opacity * 0.45),
                            width: 2.0,
                          ),
                          color: _colorBase.withValues(alpha: opacity * 0.06),
                        ),
                      );
                    },
                  ),

                // Íconos de tipos de vehículo (solo si no conocemos la
                // posición del más cercano, para no confundir direcciones)
                if (count > 0 && widget.masCercano == null)
                  ...tipos.asMap().entries.map((e) {
                    final i = e.key;
                    final tipo = e.value;
                    // Ángulo: empieza arriba (−π/2) y distribuye en sentido horario
                    final angle =
                        -math.pi / 2 + i * 2 * math.pi / count;
                    final dx =
                        _center + _iconRadius * math.cos(angle) -
                        _iconBadgeSize / 2;
                    final dy =
                        _center + _iconRadius * math.sin(angle) -
                        _iconBadgeSize / 2;
                    return Positioned(
                      left: dx,
                      top: dy,
                      child: _VehicleIconBadge(tipo: tipo),
                    );
                  }),

                // Taxi más cercano en su dirección real, resaltado
                if (widget.masCercano != null)
                  Builder(builder: (_) {
                    final m = widget.masCercano!;
                    // 0° = arriba; en pantalla el ángulo 0 de cos/sin es a la
                    // derecha, por eso se resta π/2.
                    final angle = m.rumboGrados * math.pi / 180 - math.pi / 2;
                    const size = _nearestBadgeSize;
                    final dx = _center + _iconRadius * math.cos(angle) - size / 2;
                    final dy = _center + _iconRadius * math.sin(angle) - size / 2;
                    return Positioned(
                      left: dx,
                      top: dy,
                      child: _VehicleIconBadge(
                        tipo: _tipoDe(m.servicio),
                        size: size,
                        resaltado: true,
                      ),
                    );
                  }),

                // Punto central (ubicación del usuario)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _colorBase,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _colorBase.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Badge de conductores debajo del radar
          if (widget.conductoresCercanos > 0)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_taxi, color: _colorBase, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    widget.masCercano != null
                        ? 'Más cercano a ${widget.masCercano!.distanciaTexto}'
                            '${widget.conductoresCercanos > 1 ? ' · ${widget.conductoresCercanos} cerca' : ''}'
                        : '${widget.conductoresCercanos} conductor'
                            '${widget.conductoresCercanos > 1 ? "es" : ""} cerca',
                    style: const TextStyle(
                      color: _colorBase,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleIconBadge extends StatelessWidget {
  const _VehicleIconBadge({
    required this.tipo,
    this.size = 38,
    this.resaltado = false,
  });
  final _TipoVehiculo tipo;
  final double size;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: resaltado ? Border.all(color: tipo.color, width: 3) : null,
        boxShadow: [
          BoxShadow(
            color: tipo.color.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          const BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(tipo.icono, color: tipo.color, size: size * 0.55),
    );
  }
}
