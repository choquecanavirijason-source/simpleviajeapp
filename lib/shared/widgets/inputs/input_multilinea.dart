import 'package:flutter/material.dart';

class Multilinea2 extends StatelessWidget {
  final TextEditingController controller;
  final String label; // 👈 título arriba (afuera del input)
  final String? placeholder; // 👈 texto dentro
  final int minLines; // 👈 mínimo de líneas al inicio
  final int maxLines; // 👈 máximo de crecimiento
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? Function(String?)? validator;

  const Multilinea2({
    super.key,
    required this.controller,
    this.label = '',
    this.placeholder,
    this.minLines = 2,
    this.maxLines = 5,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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
          controller: controller,
          keyboardType: TextInputType.multiline,
          minLines: minLines, // empieza pequeño
          maxLines: maxLines, // crece dinámicamente
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
          validator: validator,
        ),
      ],
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/inputs/input_multilinea.dart';
...
final _descripcionCtrl = TextEditingController();
Multilinea2(
  controller: _descripcionCtrl,
  label: 'Descripción',
  placeholder: 'Escribe una nota o detalle del préstamo...',
  prefixIcon: Icons.notes,
  suffixIcon: Icons.check,
  minLines: 2,  // empieza con 2
  maxLines: 5,  // crece hasta 5
  validator: (v) {
    if (v == null || v.isEmpty) return 'La descripción es obligatoria';
    return null;
  },
),
*/
