import 'dart:ui';
import 'package:flutter/material.dart';

/// Píldora de acceso rápido a otro modo de la app (ej. "Modo Driver",
/// "Modo Pasajero"), pensada para la esquina superior del drawer.
/// Estilo glass (frosted) blanco, siempre activa.
class QuickModeButton extends StatelessWidget {
  const QuickModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
