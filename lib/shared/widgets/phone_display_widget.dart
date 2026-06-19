import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:buses2/shared/utils/phone_formatter.dart';

/// Widget to display phone number with country flag
/// Handles legacy data (no country code) by defaulting to Bolivia
class PhoneDisplayWidget extends StatelessWidget {
  final String? phone;
  final String? countryCode;
  final TextStyle? textStyle;
  final bool showIcon;
  final IconData icon;
  final Color? iconColor;

  const PhoneDisplayWidget({
    Key? key,
    required this.phone,
    this.countryCode,
    this.textStyle,
    this.showIcon = true,
    this.icon = Icons.phone,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (phone == null || phone!.isEmpty) {
      return Text(
        'No definido',
        style: textStyle ?? TextStyle(color: Colors.grey[600]),
      );
    }

    // Default to Bolivia if no country code provided (legacy data)
    final code = countryCode ?? '+591';
    final formattedPhone = formatPhoneDisplay(phone, code);

    // Extract country code for flag display
    final countryIsoCode = _getIsoCode(code);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon)
          Icon(icon, size: 16, color: iconColor ?? Colors.grey[700]),
        if (showIcon) const SizedBox(width: 4),
        // Show flag using CountryCodePicker's flag widget
        if (countryIsoCode != null) ...[
          CountryCodePicker(
            onChanged: (_) {}, // Read-only, no action
            initialSelection: countryIsoCode,
            enabled: false,
            showCountryOnly: false,
            showOnlyCountryWhenClosed: false,
            showFlag: true,
            showFlagMain: true,
            flagWidth: 20,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(
              fontSize: 0,
            ), // Hide text, show flag only
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            formattedPhone,
            style: textStyle ?? const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
      default:
        return null;
    }
  }
}

/// Compact version without icon
class PhoneDisplayCompact extends StatelessWidget {
  final String? phone;
  final String? countryCode;
  final TextStyle? textStyle;

  const PhoneDisplayCompact({
    Key? key,
    required this.phone,
    this.countryCode,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PhoneDisplayWidget(
      phone: phone,
      countryCode: countryCode,
      textStyle: textStyle,
      showIcon: false,
    );
  }
}
