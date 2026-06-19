import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

/// Campo de fecha (pensado para fecha de nacimiento)
class FechaInput1 extends StatelessWidget {
  const FechaInput1({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    Future<void> _pickDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 100),
        lastDate: now,
      );
      if (picked != null) controller.text = dateFormat.format(picked);
    }

    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixIcon: Icon(suffixIcon ?? Icons.calendar_today),
          ),
        ),
      ),
    );
  }
}
/* // Ejemplo de uso:
final _dobCtrl  = TextEditingController();
FechaInput(
  controller: _dobCtrl,
),

Nota: Para que aparesca en espanol y funcione se debe agregar esto:
  flutter_localizations:
    sdk: flutter

  intl: ^0.20.2

Y en app_widget.dart:
// ▸  A)  Fuerza toda la app a español.
//     Si prefieres usar el idioma del sistema, elimina `locale: …`
//     y mantén solo `supportedLocales`.
locale: const Locale('es', ''),

// ▸  B)  Idiomas que tu app admite
supportedLocales: const [
  Locale('es', ''),   // Español
  Locale('en', ''),   // (opcional) Inglés
],

// ▸  C)  Delegados que traen las traducciones de Material/Cupertino
localizationsDelegates: const [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
],
*/

class FechaInput2 extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  const FechaInput2({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        _DateMaskFormatter(), // máscara con borrado de '/'
        LengthLimitingTextInputFormatter(10), // dd/MM/yyyy = 10
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd/mm/aaaa',
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
      ),
    );
  }
}

class _DateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Dígitos del valor anterior / nuevo.
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    var newDigits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Limita a 8 dígitos.
    if (newDigits.length > 8) newDigits = newDigits.substring(0, 8);

    final isAddition = newDigits.length > oldDigits.length;

    // ── Validaciones al añadir ──────────────────────────────────────────────
    if (isAddition) {
      switch (newDigits.length) {
        case 1: // 1º dígito del día  → 0-3
          if (int.parse(newDigits) > 3) return oldValue;
          break;
        case 2: // día completo
          final d = int.parse(newDigits.substring(0, 2));
          if (d == 0 || d > 31) return oldValue;
          break;
        case 3: // 1º dígito del mes → 0-1
          if (int.parse(newDigits[2]) > 1) return oldValue;
          break;
        case 4: // mes completo
          final m = int.parse(newDigits.substring(2, 4));
          if (m == 0 || m > 12) return oldValue;
          break;
        case 5: // 1º dígito del año → 1-2
          if (!(newDigits[4] == '1' || newDigits[4] == '2')) return oldValue;
          break;
      }
    }

    // ¿Se borró la barra final?
    final removedSlash =
        oldValue.text.endsWith('/') &&
        oldValue.text.length - newValue.text.length == 1;

    // ── Construye con barras ───────────────────────────────────────────────
    String formatted;
    switch (newDigits.length) {
      case 0:
        formatted = '';
        break;
      case 1:
        formatted = newDigits;
        break;
      case 2:
        formatted = removedSlash ? newDigits : '${newDigits}/';
        break;
      case 3:
        formatted = '${newDigits.substring(0, 2)}/${newDigits.substring(2)}';
        break;
      case 4:
        formatted = removedSlash
            ? '${newDigits.substring(0, 2)}/${newDigits.substring(2, 4)}'
            : '${newDigits.substring(0, 2)}/${newDigits.substring(2, 4)}/';
        break;
      default: // 5-8
        formatted =
            '${newDigits.substring(0, 2)}/${newDigits.substring(2, 4)}/${newDigits.substring(4)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/* Ejemplo de uso:
final TextEditingController _dobCtrl = TextEditingController();
FechaInput2(
  controller: _dobCtrl,
  label: 'Fecha de nacimiento',
  prefixIcon: Icons.cake,           // opcional
  suffixIcon: Icons.event,          // opcional
),
*/
