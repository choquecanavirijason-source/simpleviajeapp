// validators/input_phone.dart

import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Validates phone numbers based on country code using phone_numbers_parser
/// Returns error message if invalid, null if valid
String? validatePhoneByCountry(String value, String countryCode) {
  if (value.isEmpty) return null;

  try {
    // Extraer el código ISO del país (ej: '+591' -> 'BO')
    final isoCode = _getIsoCode(countryCode);
    if (isoCode == null) {
      // Si no podemos determinar el país, solo verificar que tenga dígitos
      final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanValue.length < 6) {
        return 'Número muy corto';
      }
      return null;
    }

    // Intentar parsear el número con el código de país
    final phoneNumber = PhoneNumber.parse(
      value,
      callerCountry: IsoCode.fromJson(isoCode),
    );

    // Validar si es un número válido
    if (!phoneNumber.isValid()) {
      return 'Número inválido';
    }

    return null; // Válido
  } catch (e) {
    // Si hay error al parsear, intentar validación básica
    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanValue.length < 6) {
      return 'Número muy corto';
    }
    if (cleanValue.length > 15) {
      return 'Número muy largo';
    }
    return null; // Permitir si está en rango razonable
  }
}

/// Returns max length for phone input based on country code
int getMaxLengthForCountry(String countryCode) {
  // phone_numbers_parser maneja esto automáticamente,
  // pero podemos dar un límite general seguro
  return 15; // Máximo internacional
}

/// Maps dial code to ISO country code
String? _getIsoCode(String dialCode) {
  switch (dialCode) {
    case '+591':
      return 'BO'; // Bolivia
    case '+54':
      return 'AR'; // Argentina
    case '+51':
      return 'PE'; // Peru
    case '+56':
      return 'CL'; // Chile
    case '+55':
      return 'BR'; // Brazil
    case '+595':
      return 'PY'; // Paraguay
    case '+1':
      return 'US'; // USA/Canada
    case '+52':
      return 'MX'; // Mexico
    case '+57':
      return 'CO'; // Colombia
    case '+58':
      return 'VE'; // Venezuela
    case '+593':
      return 'EC'; // Ecuador
    case '+34':
      return 'ES'; // España
    default:
      // Para códigos no mapeados, retornar null
      return null;
  }
}

/// Legacy function for backward compatibility
/// Validates Bolivian phone numbers
String? validateBolivianPhone(String value) {
  return validatePhoneByCountry(value, '+591');
}
