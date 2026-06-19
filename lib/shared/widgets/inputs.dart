import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_input_styles.dart';

/// Widget base reutilizable
class InputText extends StatelessWidget {
  final FocusNode? focusNode;
  final String label;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final bool readOnly;
  final InputDecoration? decoration;

  const InputText({
    super.key,
    this.focusNode,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.readOnly = false,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          focusNode: readOnly ? null : focusNode,
          keyboardType: keyboardType,
          controller: controller,
          readOnly: readOnly,
          decoration:
              decoration ??
              InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Widget específico para el nombre
class InputNombre extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;

  const InputNombre({
    super.key,
    required this.focusNode,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return InputText(
      label: 'Nombre',
      focusNode: focusNode,
      controller: controller,
    );
  }
}

/// Widget específico para el email
class InputEmail extends StatelessWidget {
  final TextEditingController controller;

  const InputEmail({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return InputText(
      label: 'Correo electrónico',
      controller: controller,
      readOnly: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey,
        enabled: false,
        labelText: 'Correo electrónico',
      ),
    );
  }
}
