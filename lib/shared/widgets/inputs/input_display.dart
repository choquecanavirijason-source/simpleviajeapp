import 'package:flutter/material.dart';

/// Input de solo lectura (no editable), con el mismo estilo que TextInput2.
/// Puedes pasar EITHER:
///   - [controller] para setear el texto desde afuera, o
///   - [value] (string) si no quieres usar controller.
///
/// Nota: No permite edición ni teclado. Útil para mostrar datos en formularios.
class TextDisplay2 extends StatelessWidget {
  final TextEditingController? controller;
  final String? value;

  final String label; // título arriba (afuera del input)
  final String? placeholder; // placeholder dentro (si value vacío)
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  const TextDisplay2({
    super.key,
    this.controller,
    this.value,
    this.label = '',
    this.placeholder,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
  }) : assert(
         controller == null || value == null,
         'Usa controller O value, no ambos.',
       );

  @override
  Widget build(BuildContext context) {
    final bool useController = controller != null;
    final String? initial = useController ? null : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: useController ? controller : null,
          initialValue: initial,
          readOnly: true, // ← no editable
          enableInteractiveSelection: false, // ← sin selección/caret
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/inputs/input_display.dart';
...
final _licCtrl = TextEditingController(text: 'ABC-123-XYZ');
...
TextDisplay2(
  controller: _licCtrl,
  label: 'Número de licencia',
  prefixIcon: Icons.badge_outlined,
);
*/
