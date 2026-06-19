import 'package:flutter/material.dart';

class Empresas extends StatelessWidget {
  final ImageProvider imagen;
  final String texto;
  final VoidCallback? onTap;

  // Tamaños
  final double width;
  final double height;
  final double circleSize;

  // Estado
  final bool active;

  // Selección
  final Color?
  selectedColor; // color que mandas desde la page (p.ej. Colors.red)
  final double selectedTintStrength; // 0..1 cuánto tiñe (default 0.12)

  // Bordes (ACTIVOS)
  final Color? boxBorderColor;
  final double boxBorderWidth;
  final Color? circleBorderColor;
  final double circleBorderWidth;

  // Bordes (INACTIVOS)
  final Color? boxBorderColorInactive;
  final Color? circleBorderColorInactive;

  const Empresas({
    super.key,
    required this.imagen,
    required this.texto,
    this.onTap,
    this.width = 80,
    this.height = 110,
    this.circleSize = 56,
    this.active = false,
    this.selectedColor,
    this.selectedTintStrength = 0.15, // 👈 intensidad del tinte
    this.boxBorderColor,
    this.boxBorderWidth = 1.0,
    this.circleBorderColor,
    this.circleBorderWidth = 1.0,
    this.boxBorderColorInactive,
    this.circleBorderColorInactive,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseCard = Theme.of(context).cardColor;

    // Fondo opaco con tinte (no transparencia)
    final double t = selectedTintStrength.clamp(0.0, 1.0);
    final Color bgColor = active && selectedColor != null
        ? Color.lerp(baseCard, selectedColor, t)! // 👈 OPAQUE TINT
        : baseCard;

    final Color boxColor = active
        ? (boxBorderColor ??
              (selectedColor != null
                  ? Color.lerp(
                      Colors.black12,
                      selectedColor,
                      0.5,
                    )! // borde activo derivado
                  : Colors.black12))
        : (boxBorderColorInactive ?? Colors.black12);

    final Color circleColor = active
        ? (circleBorderColor ??
              (selectedColor != null
                  ? Color.lerp(
                      Colors.black26,
                      selectedColor,
                      0.6,
                    )! // borde círculo derivado
                  : Colors.black26))
        : (circleBorderColorInactive ?? Colors.black26);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor, // opaco, ya teñido
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: boxColor, width: boxBorderWidth),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 2,
            spreadRadius: 1,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: circleColor,
                    width: circleBorderWidth,
                  ),
                  image: DecorationImage(image: imagen, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                texto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*
Empresas(
  imagen: const AssetImage('assets/icon/app_icon.png'),
  texto: 'Radio Taxi',
  onTap: onMotoTap,
  circleSize: 58,
  active: true,
  selectedColor: Colors.red,
  boxBorderColor: Colors.red,
  circleBorderColor: Colors.grey,
),

Empresas(
  imagen: const AssetImage('assets/icon/app_icon.png'),
  texto: 'Radio Taxi',
  onTap: onMotoTap,
  circleSize: 58,
  active: false,
  boxBorderColorInactive: Colors.grey,    // inactivo
  circleBorderColorInactive: Colors.grey, // inactivo
)
*/
