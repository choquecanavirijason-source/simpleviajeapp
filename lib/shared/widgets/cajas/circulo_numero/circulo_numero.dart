import 'package:flutter/material.dart';

class CirculoNumero extends StatelessWidget {
  final int numero;
  final MaterialColor colorBase;

  const CirculoNumero({
    super.key,
    required this.numero,
    this.colorBase = Colors.blue, // color base por defecto
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorBase.shade300, // tono más claro
            colorBase.shade700, // tono más oscuro
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          numero.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/* Ejemplos de uso:
  const CirculoNumero(numero: 1, colorBase: Colors.green)
*/
