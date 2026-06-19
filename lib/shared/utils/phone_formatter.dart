// shared/utils/phone_formatter.dart

import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Utilities for formatting and parsing phone numbers using phone_numbers_parser

/// Extracts only digits from a phone string
String extractDigits(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Formats phone for display with country code using international standard
/// If countryCode is null, defaults to Bolivia (+591)
String formatPhoneDisplay(String? phone, String? countryCode) {
  if (phone == null || phone.isEmpty) {
    return 'No definido';
  }

  try {
    final code = countryCode ?? '+591';
    final isoCode = _getIsoCode(code);

    if (isoCode != null) {
      // Intentar parsear y formatear con la librería
      final phoneNumber = PhoneNumber.parse(
        phone,
        callerCountry: IsoCode.fromJson(isoCode),
      );

      // Formato internacional: +591 70123456
      return phoneNumber.international;
    }
  } catch (e) {
    // Si falla el parsing, usar formato manual
  }

  // Fallback: formato manual
  final digits = extractDigits(phone);
  if (digits.isEmpty) return 'No definido';

  final code = countryCode ?? '+591';
  if (phone.startsWith('+')) {
    return phone;
  }

  return '$code $digits';
}

/// Formats phone for WhatsApp (no + symbol, just digits)
/// Used for wa.me URLs and whatsapp:// URIs
String formatForWhatsApp(String phone, String? countryCode) {
  try {
    final code = countryCode ?? '+591';
    final isoCode = _getIsoCode(code);

    if (isoCode != null) {
      final phoneNumber = PhoneNumber.parse(
        phone,
        callerCountry: IsoCode.fromJson(isoCode),
      );

      // Formato sin espacios ni símbolos: 59170123456
      final countryCode = phoneNumber.countryCode;
      final nationalNumber = phoneNumber.nsn;
      return '$countryCode$nationalNumber';
    }
  } catch (e) {
    // Fallback manual
  }

  // Fallback
  final digits = extractDigits(phone);
  final code = countryCode ?? '+591';
  final codeDigits = extractDigits(code);

  if (digits.length > 10) {
    return digits;
  }

  return '$codeDigits$digits';
}

/// Formats phone for tel: URI (keeps + symbol)
String formatForTel(String phone, String? countryCode) {
  try {
    final code = countryCode ?? '+591';
    final isoCode = _getIsoCode(code);

    if (isoCode != null) {
      final phoneNumber = PhoneNumber.parse(
        phone,
        callerCountry: IsoCode.fromJson(isoCode),
      );

      // Formato E164: +59170123456
      return '+${phoneNumber.countryCode}${phoneNumber.nsn}';
    }
  } catch (e) {
    // Fallback
  }

  final digits = extractDigits(phone);
  final code = countryCode ?? '+591';

  if (digits.length > 10) {
    return '+$digits';
  }

  return '$code$digits';
}

/// Tries to detect country code from a full phone number
/// Returns null if cannot detect
String? getCountryCodeFromPhone(String? phone) {
  if (phone == null || phone.isEmpty) return null;

  try {
    // Usar la librería para detectar el país
    final phoneNumber = PhoneNumber.parse(phone);
    return '+${phoneNumber.countryCode}';
  } catch (e) {
    // Fallback manual para códigos comunes
    final digits = extractDigits(phone);

    if (digits.startsWith('591') && digits.length >= 11) return '+591';
    if (digits.startsWith('54') && digits.length >= 12) return '+54';
    if (digits.startsWith('51') && digits.length >= 11) return '+51';
    if (digits.startsWith('56') && digits.length >= 11) return '+56';
    if (digits.startsWith('55') && digits.length >= 13) return '+55';
    if (digits.startsWith('595') && digits.length >= 12) return '+595';

    return null;
  }
}

/// Extracts local number from full international format
/// Example: "+59170123456" -> "70123456"
String extractLocalNumber(String phone, String? countryCode) {
  try {
    final code = countryCode ?? '+591';
    final isoCode = _getIsoCode(code);

    if (isoCode != null) {
      final phoneNumber = PhoneNumber.parse(
        phone,
        callerCountry: IsoCode.fromJson(isoCode),
      );

      return phoneNumber.nsn; // National Significant Number
    }
  } catch (e) {
    // Fallback
  }

  final digits = extractDigits(phone);
  final code = countryCode ?? '+591';
  final codeDigits = extractDigits(code);

  if (digits.startsWith(codeDigits)) {
    return digits.substring(codeDigits.length);
  }

  return digits;
}

/// Maps dial code to ISO country code
String? _getIsoCode(String dialCode) {
  switch (dialCode) {
    case '+591':
      return 'BO';
    case '+54':
      return 'AR';
    case '+51':
      return 'PE';
    case '+56':
      return 'CL';
    case '+55':
      return 'BR';
    case '+595':
      return 'PY';
    case '+1':
      return 'US';
    case '+52':
      return 'MX';
    case '+57':
      return 'CO';
    case '+58':
      return 'VE';
    case '+593':
      return 'EC';
    case '+34':
      return 'ES';
    default:
      // Para códigos no mapeados, retornar null
      return null;
  }
}
