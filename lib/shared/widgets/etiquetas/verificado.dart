import 'package:flutter/material.dart';

class VerificadoChip extends StatelessWidget {
  const VerificadoChip({
    super.key,
    this.text = 'Verificado',
    this.icon = Icons.verified,
    this.gradient,
    this.shadowColor,
    this.foregroundColor,
  });

  final String text;
  final IconData icon;
  final Gradient? gradient;
  final Color? shadowColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final defaultGradient = LinearGradient(
      colors: [cs.primary, cs.tertiary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final defaultShadowColor = cs.primary.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: gradient ?? defaultGradient,
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? defaultShadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor ?? Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: foregroundColor ?? Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/* Ejemplo de uso:
const VerificadoChip(
  text: 'VIP',
  icon: Icons.workspace_premium,
  gradient: LinearGradient(
    colors: [Colors.amber, Colors.orange],
  ),
  shadowColor: Colors.amber,
  foregroundColor: Colors.white,
),
// Verificado colores
const VerificadoChip(
  text: 'Verificado',
  icon: Icons.verified,
  gradient: LinearGradient(
    colors: [Colors.green, Colors.lightGreenAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  shadowColor: Colors.amber,
  foregroundColor: Colors.white,
),
// Aprobado colores icono
const VerificadoChip(
  text: 'Aprobado',
  icon: Icons.thumb_up,
  gradient: LinearGradient(
    colors: [Colors.blue, Colors.lightBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  shadowColor: Colors.blue,
  foregroundColor: Colors.white,
),
// Suspendido colores icono
const VerificadoChip(
  text: 'Suspendido',
  icon: Icons.block,
  gradient: LinearGradient(
    colors: [Colors.red, Colors.deepOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  shadowColor: Colors.red,
  foregroundColor: Colors.white,
),
*/
