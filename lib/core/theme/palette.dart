// lib/core/theme/palette.dart
import 'package:flutter/material.dart';

/// 🎨 App Palette (según tu imagen)
/// #F20519 (rojo)
/// #0511F2 (azul)
/// #94D7F2 (celeste)
/// #034001 (verde oscuro)
/// #F2CC0C (amarillo)
class Palette {
  Palette._();

  // ===== Brand Colors =====
  static const Color red = Color(0xFFF20519);
  static const Color blue = Color(0xFF0511F2);
  static const Color sky = Color(0xFF94D7F2);
  static const Color greenDark = Color(0xFF034001);
  static const Color yellow = Color(0xFFF2CC0C);

  // ===== Neutrals =====
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ===== UI Defaults (recomendados) =====
  static const Color background = white;
  static const Color surface = white;

  /// Texto principal (sobre fondo blanco)
  static const Color textPrimary = Color(0xFF111827); // gris casi negro
  static const Color textSecondary = Color(0xFF6B7280);

  /// Bordes/divisores suaves
  static const Color border = Color(0xFFE5E7EB);

  // ===== Semantic (puedes mapear a tu gusto) =====
  static const Color success = greenDark;
  static const Color warning = yellow;
  static const Color info = sky;
  static const Color danger = red;

  // ===== Gradients (opcionales) =====
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, sky],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [yellow, red],
  );

  // ===== Theme Helpers (opcional) =====
  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: blue,
        secondary: sky,
        tertiary: yellow,
        error: red,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
    );
  }
}
