import 'package:flutter/material.dart';

/// Sombras del estilo "Modern Clean Light UI": muy suaves, amplias y de
/// opacidad bajísima, para separar tarjetas blancas de un fondo casi blanco
/// sin usar bordes sólidos.
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.09),
      offset: Offset(0, 12),
      blurRadius: 44,
    ),
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.05),
      offset: Offset(0, 3),
      blurRadius: 10,
    ),
  ];

  /// Versión un poco más marcada para elementos flotantes (ej. bottom nav).
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.12),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];
}
