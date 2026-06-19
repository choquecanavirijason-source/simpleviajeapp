import 'package:flutter/material.dart';

class TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? Function(String?)? validator;

  const TextInput({
    super.key,
    required this.controller,
    this.label = '',
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
      ),
      validator: validator,
    );
  }
}

/* Ejemplo de uso:
final _nameCtrl = TextEditingController();
TextInput(
  controller: _nameCtrl,
  label: 'Nombre',
  prefixIcon: Icons.person,   // opcional
  suffixIcon: Icons.check_circle, // opcional
  keyboardType: TextInputType.name, // opcional
  validator: (value) {
    if (value == null || value.isEmpty) return 'Requerido';
    return null; // o cualquier otra validación
  },
),
*/

class TextInput2 extends StatelessWidget {
  final TextEditingController controller;
  final String label; // 👈 título arriba (afuera del input)
  final String? placeholder; // 👈 placeholder dentro
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? Function(String?)? validator;

  const TextInput2({
    super.key,
    required this.controller,
    this.label = '',
    this.placeholder,
    this.keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                4,
              ), // 👈 esquinas suavemente redondeadas
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                4,
              ), // 👈 recto pero con esquinas suaves
              borderSide: const BorderSide(
                color: Colors.grey,
              ), // color por defecto
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4), // 👈 igual en focus
              borderSide: const BorderSide(
                color: Colors.blue,
                width: 2,
              ), // color al enfocar
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/* Ejemplo de uso:
final _marcaCtrl = TextEditingController();
TextInput2(
  controller: _marcaCtrl,
  label: 'Marca del Taxi',
  placeholder: 'Ej: Toyota',
  prefixIcon: Icons.local_taxi,
  suffixIcon: Icons.check_circle,
  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
),
*/
