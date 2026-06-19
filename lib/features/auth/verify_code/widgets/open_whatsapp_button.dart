import 'package:flutter/material.dart';

class OpenWhatsAppButton extends StatelessWidget {
  final VoidCallback onPressed;

  const OpenWhatsAppButton({Key? key, required this.onPressed})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        //icon: Icon(Icons.whatsapp), // si tienes un ícono personalizado, cámbialo aquí
        label: const Text('Abrir WhatsApp'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
