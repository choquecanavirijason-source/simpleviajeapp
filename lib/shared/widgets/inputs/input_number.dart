// import 'package:prestamos1/shared/widgets/inputs/input_number.dart';
// lib/shared/widgets/inputs/input_number.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controller que expone el valor numérico ya parseado.
class NumberEditingController extends TextEditingController {
  final bool allowDecimal;
  final int decimalPlaces;
  final bool allowNegative;

  NumberEditingController({
    String? text,
    this.allowDecimal = true,
    this.decimalPlaces = 2,
    this.allowNegative = false,
  }) : super(text: text);

  /// Lee el valor numérico del texto (tolera coma o punto).
  num? get numberValue {
    final t = this.text.trim();
    if (t.isEmpty) return null;
    final normalized = t.replaceAll(',', '.');
    if (!allowDecimal) return int.tryParse(normalized);
    return num.tryParse(normalized);
  }

  /// Asigna un valor numérico y lo refleja en el texto.
  set numberValue(num? v) {
    if (v == null) {
      text = '';
      return;
    }
    if (!allowDecimal) {
      text = v.toInt().toString();
      return;
    }
    // Si es entero, evita decimales; si no, fija decimales.
    final isIntLike = (v is int) || (v == v.roundToDouble());
    text = isIntLike
        ? v.toString()
        : (v.toDouble()).toStringAsFixed(decimalPlaces);
  }
}

class NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int? maxDigits;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  /// Flags de formato/validación
  final bool allowDecimal;
  final int decimalPlaces;
  final bool allowNegative;

  /// 👇 nuevo: validador
  final String? Function(String?)? validator;

  const NumberInput({
    super.key,
    required this.controller,
    required this.label,
    this.maxDigits,
    this.prefixIcon,
    this.suffixIcon,
    this.allowDecimal = false,
    this.decimalPlaces = 2,
    this.allowNegative = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final decimalPart = allowDecimal ? '([.,]\\d{0,$decimalPlaces})?' : '';
    final sign = allowNegative ? '-?' : '';
    final pattern = '^$sign\\d*$decimalPart\$';
    final reg = RegExp(pattern);

    return TextFormField(
      // 👈 aquí estaba el detalle
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: allowDecimal,
        signed: allowNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(reg),
        if (maxDigits != null) LengthLimitingTextInputFormatter(maxDigits!),
      ],
      validator: validator, // 👈 conectamos el validador al formulario
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
      ),
    );
  }
}

/* Ejemplo de uso:
late final NumberEditingController _nightPctCtrl;

@override
void initState() {
  super.initState();
  _nightPctCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
}

@override
void dispose() {
  _nightPctCtrl.dispose();
  super.dispose();
}

NumberInput(
  controller: _nightPctCtrl,
  label: 'Recargo nocturno (%)',
  prefixIcon: Icons.nightlight_round,
  suffixIcon: Icons.percent,
  maxDigits: 3,
  allowDecimal: true, decimalPlaces: 2, // permite decimales
  validator: (value) {
    if (value == null || value.isEmpty) return 'El teléfono es obligatorio';
    if (value.length < 8) return 'Debe tener 8 dígitos';
    return null;
  },
),
*/

/// Controller que expone el valor numérico ya parseado.
class NumberEditingController2 extends TextEditingController {
  final bool allowDecimal;
  final int decimalPlaces;
  final bool allowNegative;

  NumberEditingController2({
    String? text,
    this.allowDecimal = true,
    this.decimalPlaces = 2,
    this.allowNegative = false,
  }) : super(text: text);

  num? get numberValue {
    final t = this.text.trim();
    if (t.isEmpty) return null;
    final normalized = t.replaceAll(',', '.');
    if (!allowDecimal) return int.tryParse(normalized);
    return num.tryParse(normalized);
  }

  set numberValue(num? v) {
    if (v == null) {
      text = '';
      return;
    }
    if (!allowDecimal) {
      text = v.toInt().toString();
      return;
    }
    final isIntLike = (v is int) || (v == v.roundToDouble());
    text = isIntLike
        ? v.toString()
        : (v.toDouble()).toStringAsFixed(decimalPlaces);
  }
}

/// Renderiza texto como si fuera un ícono en prefixIcon.
class _TextGlyphIcon extends StatelessWidget {
  final String text;
  const _TextGlyphIcon(this.text);

  @override
  Widget build(BuildContext context) {
    final it = IconTheme.of(context);
    final size = (it.size ?? 24.0);
    return Center(
      child: Text(
        text,
        // tamaño ligeramente menor para que “pese” como un ícono
        style: TextStyle(
          fontSize: size * 0.80,
          fontWeight: FontWeight.w700,
          color: it.color,
          height: 1.0,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class NumberInput2 extends StatelessWidget {
  final TextEditingController controller;
  final String label; // título arriba
  final String? placeholder; // hint
  final int? maxDigits;

  // Íconos (compatibilidad)
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  // Prefijos flexibles
  final String? prefixText; // ej. 'ARS'
  final TextStyle? prefixStyle;
  final Widget? prefixWidget;
  final String? prefixTextAsIcon; // ← “Bs.” como ícono
  final BoxConstraints?
  prefixIconConstraints; // ← ajustar caja del “icono” si quieres

  final bool allowDecimal;
  final int decimalPlaces;
  final bool allowNegative;

  final String? Function(String?)? validator;

  const NumberInput2({
    super.key,
    required this.controller,
    this.label = '',
    this.placeholder,
    this.maxDigits,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.prefixStyle,
    this.prefixWidget,
    this.prefixTextAsIcon,
    this.prefixIconConstraints,
    this.allowDecimal = false,
    this.decimalPlaces = 2,
    this.allowNegative = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final decimalPart = allowDecimal ? '([.,]\\d{0,$decimalPlaces})?' : '';
    final sign = allowNegative ? '-?' : '';
    final pattern = '^$sign\\d*$decimalPart\$';
    final reg = RegExp(pattern);

    // Prioridad: text-as-icon > widget > text > icon
    Widget? resolvedPrefix; // InputDecoration.prefix
    Widget? resolvedPrefixIcon; // InputDecoration.prefixIcon
    final BoxConstraints resolvedConstraints =
        prefixIconConstraints ??
        const BoxConstraints(
          minWidth: 48,
          maxWidth: 48,
          minHeight: 48,
          maxHeight: 48, // igual a un icono Material
        );

    if (prefixTextAsIcon != null && prefixTextAsIcon!.isNotEmpty) {
      resolvedPrefixIcon = _TextGlyphIcon(prefixTextAsIcon!);
    } else if (prefixWidget != null) {
      resolvedPrefix = prefixWidget;
    } else if (prefixText != null) {
      resolvedPrefix = Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Text(
          prefixText!,
          style:
              prefixStyle ??
              Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    } else if (prefixIcon != null) {
      resolvedPrefixIcon = Icon(prefixIcon);
    }

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
          keyboardType: TextInputType.numberWithOptions(
            decimal: allowDecimal,
            signed: allowNegative,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(reg),
            if (maxDigits != null) LengthLimitingTextInputFormatter(maxDigits!),
          ],
          validator: validator,
          decoration: InputDecoration(
            hintText: placeholder,
            prefix: resolvedPrefix, // texto/widget libre
            prefixIcon: resolvedPrefixIcon, // ícono o “Bs.” como ícono
            prefixIconConstraints:
                resolvedConstraints, // ← igual que otros íconos
            suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/* Ejemplo de uso:
final _carnetCtrl = TextEditingController();
NumberInput2(
  controller: _carnetCtrl,
  label: 'Carnet de identidad',
  placeholder: 'Ej: 12345678',
  prefixIcon: Icons.nightlight_round,
  prefixTextAsIcon: 'ARS',     --opcional en lugar del icono de prefixicon
  suffixIcon: Icons.percent,
  maxDigits: 10,
  allowDecimal: false, decimalPlaces: 0, // no permite decimales
  validator: (value) {
    if (value == null || value.isEmpty) return 'El teléfono es obligatorio';
    if (value.length < 8) return 'Debe tener 8 dígitos';
    return null;
  },
),

*/

class InputNumber extends StatelessWidget {
  const InputNumber({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.prefixIcon = Icons.phone_iphone,
    this.suffixIcon,
    this.validator,
    this.requiredField = false,
    this.minDigits = 8,
    this.onChanged,
    this.onSubmitted,
    this.borderRadius = 12,
    this.readOnly = false,
    this.enabled = true,
    this.maxLength,
    this.focusNode,
  });

  final TextEditingController controller;

  /// Texto de la etiqueta (labelText).
  final String? label;

  /// Placeholder (hintText).
  final String? placeholder;

  /// Iconos
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  /// Validación externa (si es null y requiredField=true, valida mínimo de dígitos).
  final String? Function(String?)? validator;
  final bool requiredField;

  /// Mínimo de dígitos (solo números) para considerar válido.
  final int minDigits;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final double borderRadius;

  final bool readOnly;
  final bool enabled;
  final int? maxLength;
  final FocusNode? focusNode;

  String? _defaultValidator(String? v) {
    final text = (v ?? '');
    final digits = text.replaceAll(RegExp(r'\D'), ''); // deja solo números

    if (requiredField && digits.isEmpty) return 'Requerido';
    if (digits.isNotEmpty && digits.length < minDigits)
      return 'Número no válido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Paleta “glass” fija (igual a TextInput3)
    final Color glassText = Colors.white;
    final Color glassFill = Colors.white.withOpacity(.06);
    final Color glassBorder = Colors.white.withOpacity(.25);
    final Color glassBorderFocus = Colors.white.withOpacity(.45);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      readOnly: readOnly,
      enabled: enabled,
      maxLength: maxLength,
      style: TextStyle(color: glassText),
      inputFormatters: <TextInputFormatter>[
        // Permite +, dígitos, espacios, guiones y paréntesis
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        labelStyle: TextStyle(color: glassText),
        hintStyle: TextStyle(color: glassText.withOpacity(.80)),
        filled: true,
        fillColor: glassFill,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: glassText),
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, color: glassText),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: glassBorderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        counterText: '',
      ),
      validator: validator ?? _defaultValidator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
    );
  }
}

/* Ejemplo de uso:
final _phoneCtrl = TextEditingController();

InputNumber(
  controller: _phoneCtrl,
  label: 'Número de celular',
  placeholder: 'Ej: +591 70000000',
  requiredField: true,      // solo valida que no esté vacío
  minDigits: 8,             // mínimo de dígitos para ser válido
  // onSubmitted: (_) => _submit(), // opcional
),
*/
