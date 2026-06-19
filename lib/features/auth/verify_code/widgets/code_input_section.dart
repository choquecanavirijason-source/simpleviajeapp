import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_input_styles.dart';

class CodeInputSection extends StatelessWidget {
  final List<String> codeDigits;

  const CodeInputSection({Key? key, required this.codeDigits})
    : super(key: key);

  Widget _buildCodeBox(int index) {
    // Estilo inputs /core/theme/input_styles.dart';
    return Container(
      width: InputStyles.codeBoxWidth,
      height: InputStyles.codeBoxHeight,
      alignment: Alignment.center,
      margin: InputStyles.codeBoxMargin,
      decoration: InputStyles.codeBoxDecoration,
      child: Text(codeDigits[index], style: InputStyles.codeDigitTextStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Casillas OTP visibles
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, _buildCodeBox), // 👈 6 inputs
        ),
      ],
    );
  }
}
