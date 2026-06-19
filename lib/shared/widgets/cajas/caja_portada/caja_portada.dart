import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/etiquetas/verificado.dart';

class CajaPortada extends StatelessWidget {
  const CajaPortada({
    super.key,
    this.height = 100,
    this.color = Colors.blue,
    this.showVerified = false,
    // ---- props de la etiqueta (opcionales) ----
    this.verifiedText = 'Verificado',
    this.verifiedIcon = Icons.verified,
    // Se actualizaron los parámetros para coincidir con el nuevo VerificadoChip
    this.verifiedGradient,
    this.verifiedShadowColor,
    this.verifiedForegroundColor,
  });

  final double height;
  final Color color;
  final bool showVerified;

  // Props que se pasan a VerificadoChip
  final String verifiedText;
  final IconData verifiedIcon;
  final Gradient? verifiedGradient;
  final Color? verifiedShadowColor;
  final Color? verifiedForegroundColor;

  static const double _kFadeStart = 0.55; // difuminado inferior fijo

  @override
  Widget build(BuildContext context) {
    // Caja base con color
    final baseBox = Container(
      height: height,
      width: double.infinity,
      color: color,
    );

    // Difuminado inferior (el chip no se difumina)
    final faded = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
          stops: [_kFadeStart, 1.0],
        ).createShader(rect);
      },
      child: baseBox,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        faded,
        if (showVerified)
          Positioned(
            top: 8,
            right: 12,
            child: VerificadoChip(
              text: verifiedText,
              icon: verifiedIcon,
              // Ahora se usan los nuevos parámetros de la etiqueta
              gradient: verifiedGradient,
              shadowColor: verifiedShadowColor,
              foregroundColor: verifiedForegroundColor,
            ),
          ),
      ],
    );
  }
}

/* Ejemplo de uso:
const CajaPortada(
  height: 120,
  color: Colors.blue,
  showVerified: true,
),

// VIP con efectos 3D y gradiente
const CajaPortada(
  height: 120,
  color: Colors.blue,
  showVerified: true,
  verifiedText: 'VIP',
  verifiedIcon: Icons.workspace_premium,
  // Ahora usamos verifiedGradient en lugar de verifiedBackgroundColor
  verifiedGradient: LinearGradient(
    colors: [Colors.amber, Colors.orange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // Añadimos una sombra para el efecto 3D
  verifiedShadowColor: Colors.amber,
  // El color del texto e ícono sigue siendo el mismo
  verifiedForegroundColor: Colors.white,
),
// Verificado colores
const CajaPortada(
  height: 120,
  color: Colors.blue, // El color de la portada, no de la etiqueta
  showVerified: true,
  verifiedText: 'Verificado',
  verifiedIcon: Icons.verified,
  verifiedGradient: LinearGradient(
    colors: [Colors.green, Colors.lightGreenAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  verifiedShadowColor: Colors.green,
  verifiedForegroundColor: Colors.white,
),
// Aprobado colores icono
const CajaPortada(
  height: 120,
  color: Colors.blue,
  showVerified: true,
  verifiedText: 'Aprobado',
  verifiedIcon: Icons.thumb_up,
  verifiedGradient: LinearGradient(
    colors: [Colors.blue, Colors.lightBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  verifiedShadowColor: Colors.blue,
  verifiedForegroundColor: Colors.white,
),
// Suspendido colores icono
const CajaPortada(
  height: 120,
  color: Colors.blue,
  showVerified: true,
  verifiedText: 'Suspendido',
  verifiedIcon: Icons.block,
  verifiedGradient: LinearGradient(
    colors: [Colors.red, Colors.deepOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  verifiedShadowColor: Colors.red,
  verifiedForegroundColor: Colors.white,
),
*/
