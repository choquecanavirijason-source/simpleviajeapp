import 'package:flutter/material.dart';

class TermsText extends StatelessWidget {
  const TermsText({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Al registrarte en nuestra App, Aceptas nuestros términos de uso y políticas de privacidad',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          decoration: TextDecoration.underline,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
