import 'package:flutter/material.dart';

class EtiquetaServicio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback? onTap;

  const EtiquetaServicio({
    super.key,
    required this.icono,
    required this.texto,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12), // fondo suave con el color
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                texto,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
