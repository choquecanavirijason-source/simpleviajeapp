import 'package:flutter/material.dart';

class AppInputStyles {
  static InputDecoration defaultDecoration({
    required String label,
    IconData? prefixIcon,
    IconData? suffixIcon,
    String? hintText,
    Color? iconColor,
    bool enabled = true,
  }) {
    final usedIconColor = iconColor ?? Colors.blueGrey;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.green, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      floatingLabelStyle: TextStyle(color: usedIconColor),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: usedIconColor)
          : null,
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: usedIconColor)
          : null,
      enabled: enabled,
      filled: true,
      fillColor: Colors.grey[100],
      errorStyle: const TextStyle(color: Colors.orange, fontSize: 12),
    );
  }
}

// app_input_styles.dart

/// Paleta general (puedes centralizarla en otro archivo si quieres)
class AppInputColors {
  static const fill = Color(0xFFFFFFFF);
  static const grey = Colors.grey; // inactivo
  static const blue = Color(0xFF2196F3); // activo
}

/// Builders estáticos para bordes y decoraciones.
class AppInputStyles1 {
  static OutlineInputBorder border(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: width),
      );

  /// Devuelve una `InputDecoration` con iconos/bordes que se
  /// vuelven azules cuando `controller` contiene texto.
  static InputDecoration decoration({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onClear,
  }) {
    final bool hasText = controller.text.isNotEmpty;
    final Color iconCol = hasText ? AppInputColors.blue : AppInputColors.grey;
    final Color borderCol = hasText ? AppInputColors.blue : AppInputColors.grey;

    return InputDecoration(
      filled: true,
      fillColor: AppInputColors.fill,
      labelText: label,
      labelStyle: TextStyle(color: iconCol),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: iconCol),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: iconCol)
          : IconButton(
              tooltip: 'Limpiar',
              icon: const Icon(Icons.close),
              color: iconCol,
              onPressed: onClear ?? () {},
            ),
      enabledBorder: border(borderCol),
      focusedBorder: border(borderCol, width: 2),
    );
  }
}
