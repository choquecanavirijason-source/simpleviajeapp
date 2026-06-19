import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

class InputStyles {
  // 🌐 Estilo general de inputs (como el del teléfono)
  static final BoxDecoration inputBoxDecoration = BoxDecoration(
    border: Border.all(color: AppColors.borderColor),
    borderRadius: BorderRadius.circular(8),
    color: AppColors.fondoInput,
  );

  static const TextStyle inputTextStyle = TextStyle(fontSize: 18);

  // 🔢 Estilo para casillas de código OTP
  static final BoxDecoration codeBoxDecoration = BoxDecoration(
    border: Border.all(color: Colors.grey),
    borderRadius: BorderRadius.circular(8),
    color: Colors.white,
  );

  static const TextStyle codeDigitTextStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const EdgeInsets codeBoxMargin = EdgeInsets.symmetric(horizontal: 4);
  static const double codeBoxWidth = 50;
  static const double codeBoxHeight = 60;
}
