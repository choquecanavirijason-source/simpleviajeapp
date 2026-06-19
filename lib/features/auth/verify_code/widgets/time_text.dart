import 'package:flutter/material.dart';

class TimeText extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback? onResend;

  const TimeText({Key? key, required this.secondsRemaining, this.onResend})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (secondsRemaining > 0) {
      return Text(
        'Puedes reenviar el código en $secondsRemaining segundos.',
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onResend,
          child: const Text('Obten un nuevo código'),
        ),
      );
    }
  }
}
