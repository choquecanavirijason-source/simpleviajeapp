import 'package:flutter/material.dart';

//* Ejemplo de uso:
//* final colors = AppColors(isDarkMode: true); // o false
//* color: colors.logoTextColor

//* Ejemplo Completo:
//* final colors = AppColors(isDarkMode: true); // o false
//* Text('Logo', style: TextStyle(color: colors.logoTextColor),);

class ColorPair {
  final Color light;
  final Color dark;
  const ColorPair(this.light, this.dark);
}

class AppColors {
  // Definimos pares de colores lado a lado, para que sea fácil verlos y modificarlos
  static const ColorPair logoText = ColorPair(Colors.black, Colors.white);
  static const ColorPair logoTextShadow = ColorPair(
    Colors.black87,
    Colors.white70,
  );
  static const ColorPair bodyText = ColorPair(
    Color(0xFF424242),
    Color(0xFFCCCCCC),
  );
  static const ColorPair buttonAccent = ColorPair(
    Color(0xFF00BCD4),
    Color(0xFF00BCD4),
  );
  static const ColorPair background = ColorPair(Colors.white, Colors.black);
  static const ColorPair error = ColorPair(
    Color(0xFFD32F2F),
    Color(0xFFEF5350),
  );

  final bool isDarkMode;

  AppColors({required this.isDarkMode});

  Color get logoTextColor => isDarkMode ? logoText.dark : logoText.light;
  Color get logoTextShadowColor =>
      isDarkMode ? logoTextShadow.dark : logoTextShadow.light;
  Color get bodyTextColor => isDarkMode ? bodyText.dark : bodyText.light;
  Color get buttonAccentColor =>
      isDarkMode ? buttonAccent.dark : buttonAccent.light;
  Color get backgroundColor => isDarkMode ? background.dark : background.light;
  Color get errorColor => isDarkMode ? error.dark : error.light;
}
