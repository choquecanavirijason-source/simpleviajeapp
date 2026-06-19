import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmailInput extends StatelessWidget {
  const EmailInput({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.autoValidate = false,
    this.requiredField = true,
    this.strictValidation = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool autoValidate;
  final bool requiredField;
  final bool strictValidation;

  // Regex para formato típico de correo
  static final _emailRx = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  String? _validator(String? v) {
    final value = v?.trim() ?? '';

    // Si es obligatorio
    if (value.isEmpty) {
      if (requiredField) return 'Requerido';
      return null; // no obligatorio y vacío = ok
    }

    // No permitir espacios
    if (value.contains(' ')) {
      return 'El correo no debe tener espacios';
    }

    // Validación estricta
    if (strictValidation) {
      if (!_emailRx.hasMatch(value)) {
        return 'Formato inválido';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autovalidateMode: autoValidate
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      inputFormatters: [
        // Solo caracteres válidos típicos de correo
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._%+\-]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
        border: const OutlineInputBorder(),
      ),
      validator: _validator,
    );
  }
}

/* Ejemplo de uso:
final _emailCtrl = TextEditingController();
EmailInput(
  controller: _emailCtrl,
  label: 'Correo',
  prefixIcon: Icons.email,   // opcional
  suffixIcon: Icons.check_circle, // opcional
  autoValidate: true, // 👈 valida mientras escribes
  requiredField: true, // true = obligatorio, false = opcional
  strictValidation: true, // true = valida con m@g.c, false = deja pasar todo
),
*/
