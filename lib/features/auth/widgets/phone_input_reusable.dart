import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:buses2/features/auth/config/country_config.dart';
import 'package:buses2/shared/theme/app_input_styles.dart';
import '../validators/input_phonevalidators.dart';

class PhoneNumberField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function(String)? onCountryChanged;
  final bool readOnly;
  final bool showCursor;
  final String? initialCountryCode;
  final String? label;
  final String? hint;
  final bool showError;

  const PhoneNumberField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onCountryChanged,
    this.readOnly = false,
    this.showCursor = true,
    this.initialCountryCode,
    this.label,
    this.hint,
    this.showError = true,
  });

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  String? error;
  String _selectedCountryCode = '+591';
  int _maxLength = 8;

  @override
  void initState() {
    super.initState();
    _selectedCountryCode = widget.initialCountryCode ?? '+591';
    _maxLength = getMaxLengthForCountry(_selectedCountryCode);
    widget.controller.addListener(_validate);
  }

  void _validate() {
    setState(() {
      error = validatePhoneByCountry(
        widget.controller.text,
        _selectedCountryCode,
      );
    });
  }

  void _onCountryChanged(String dialCode) {
    setState(() {
      _selectedCountryCode = dialCode;
      _maxLength = getMaxLengthForCountry(dialCode);
      // Revalidate with new country
      error = validatePhoneByCountry(
        widget.controller.text,
        _selectedCountryCode,
      );
    });

    if (widget.onCountryChanged != null) {
      widget.onCountryChanged!(dialCode);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CountryCodePicker(
          onChanged: (country) {
            _onCountryChanged(country.dialCode ?? '+591');
          },
          initialSelection: widget.initialCountryCode ?? defaultCountryCode,
          favorite: favoriteCountries,
          showCountryOnly: false,
          showOnlyCountryWhenClosed: false,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: TextInputType.phone,
            readOnly: widget.readOnly,
            showCursor: widget.showCursor,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_maxLength),
            ],
            decoration: InputDecoration(
              labelText: widget.label ?? 'Número de teléfono',
              hintText: widget.hint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              errorText: widget.showError ? error : null,
            ),
            style: InputStyles.inputTextStyle,
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}
