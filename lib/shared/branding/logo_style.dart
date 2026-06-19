import 'package:flutter/material.dart';

class LogoStyles {
  //** Ejemplo de uso:
  //** LogoStyles.circularLogo(assetPath: BrandingImages.logo),

  /// Logo circular con tamaño fijo
  static Widget circularLogo({required String assetPath, double size = 50}) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(assetPath, fit: BoxFit.cover),
    );
  }

  /// Logo con esquinas redondeadas
  static Widget esquinasRedondeadas({
    required String assetPath,
    double size = 50,
    double borderRadius = 12,
  }) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.9),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(assetPath, fit: BoxFit.cover),
    );
  }

  /// Logo plano sin decoración
  static Widget plano({required String assetPath, double size = 50}) {
    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(assetPath, fit: BoxFit.cover),
    );
  }
}
