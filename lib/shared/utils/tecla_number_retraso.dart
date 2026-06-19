// core/utils/tecla_number_retraso.dart
import 'package:flutter/material.dart';

typedef OnPhoneNumberChanged = void Function(String newPhoneNumber);

class PhoneNumberInputController {
  String phoneNumber;
  final OnPhoneNumberChanged onChanged;
  final TextEditingController? textController;

  PhoneNumberInputController({
    required this.phoneNumber,
    required this.onChanged,
    this.textController,
  });

  /// Actualiza el número de teléfono con la tecla pulsada,
  /// actualiza también el TextEditingController y llama callback.
  void onKeyTap(
    String key,
    String Function(String, String) modificarNumeroTelefonico,
  ) {
    phoneNumber = modificarNumeroTelefonico(phoneNumber, key);
    if (textController != null) {
      textController!.text = phoneNumber;
      textController!.selection = TextSelection.fromPosition(
        TextPosition(offset: phoneNumber.length),
      );
    }
    onChanged(phoneNumber);
  }
}
