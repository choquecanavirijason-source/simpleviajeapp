import 'package:flutter/material.dart';

class PhoneTitleSection extends StatelessWidget {
  const PhoneTitleSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final double scale = (screenW / 360).clamp(0.9, 1.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inicia con tu número',
          style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6 * scale),
        Text(
          'Te enviaremos un código de verificación a tu número de WhatsApp.',
          style: TextStyle(fontSize: 14 * scale, color: Colors.black54),
        ),
      ],
    );
  }
}
