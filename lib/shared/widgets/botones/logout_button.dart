import 'dart:ui';
import 'package:flutter/material.dart';

/// Botón "Cerrar sesión" estándar: fondo glass (frosted) con borde y
/// texto blanco.
class LogoutButton extends StatelessWidget {
  const LogoutButton({
    super.key,
    required this.onPressed,
    this.label = 'Cerrar sesión',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
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
