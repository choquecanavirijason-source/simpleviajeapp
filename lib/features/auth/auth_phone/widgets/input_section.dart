import 'package:flutter/material.dart';
import 'package:buses2/features/auth/widgets/phone_input_reusable.dart'; // Aquí PhoneNumberField
import 'package:buses2/shared/theme/app_input_styles.dart';
import 'package:buses2/shared/widgets/cursor_input.dart';

class InputSection extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onTap;

  const InputSection({
    super.key,
    required this.phoneNumber,
    required this.onTap,
  });

  @override
  State<InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends State<InputSection> {
  late TextEditingController _controller;
  bool _showCursor = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.phoneNumber);
    _focusNode = FocusNode();

    // Opcional: escucha foco para mostrar cursor cuando se enfoque
    _focusNode.addListener(() {
      setState(() {
        _showCursor = _focusNode.hasFocus;
      });
    });
  }

  @override
  void didUpdateWidget(covariant InputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phoneNumber != widget.phoneNumber) {
      _controller.text = widget.phoneNumber;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double _calculateTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final textWidth = _calculateTextWidth(
      _controller.text,
      InputStyles.inputTextStyle,
    );

    return GestureDetector(
      onTap: () {
        widget.onTap();
        _focusNode.requestFocus();
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          PhoneNumberField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(
                  () {},
                ); // Esto lo hace menos agresivo y evita reconstrucción durante evento de entrada
              });
            },
            readOnly: true, // <-- No abre teclado
            showCursor: false, // <-- Oculta cursor nativo
            onCountryChanged: (code) {
              /* ... */
            },
          ),

          if (_showCursor)
            Positioned(
              left:
                  130 +
                  textWidth, // Ajusta según tamaño CountryCodePicker y padding
              top: 17, // Ajusta para alinear verticalmente
              child: const CursorInput(),
            ),
        ],
      ),
    );
  }
}
