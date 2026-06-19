import 'package:flutter/material.dart';

class CircularCountdown extends StatelessWidget {
  const CircularCountdown({
    super.key,
    required this.secondsLeft,
    required this.progress,
    required this.phaseColor,
    required this.scale,
  });

  final int secondsLeft; // 10..0
  final double progress; // 0..1 (ya transcurrido)
  final Color phaseColor;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    final remainingFraction = (1.0 - progress).clamp(0.0, 1.0);

    return Semantics(
      label: 'Tiempo restante',
      value: '$secondsLeft segundos',
      child: ScaleTransition(
        scale: scale,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: remainingFraction,
                  strokeWidth: 5.0,
                  backgroundColor: const Color(0xFFEFF1F5),
                  valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                ),
              ),
              Text(
                secondsLeft.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
