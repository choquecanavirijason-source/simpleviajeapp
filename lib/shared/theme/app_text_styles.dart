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
    border: Border.all(color: AppColors.borderColor),
    borderRadius: BorderRadius.circular(8),
    color: AppColors.fondoInput,
  );

  static const TextStyle codeDigitTextStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const EdgeInsets codeBoxMargin = EdgeInsets.symmetric(horizontal: 4);
  static const double codeBoxWidth = 40;
  static const double codeBoxHeight = 50;

  // 📴 Estilo para inputs NO editables
  static const InputDecoration readOnlyInputDecoration = InputDecoration(
    labelText: 'No editable',
    border: OutlineInputBorder(),
    filled: true,
    fillColor: AppColors.fondoInputDisable,
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.borderColor),
    ),
    labelStyle: TextStyle(
      color: AppColors.textInputDisable, //texto titulo
    ),
  );

  static const TextStyle readOnlyTextStyle = TextStyle(
    fontSize: 18,
    color: AppColors.textInputDisable, //texto
  );
}
