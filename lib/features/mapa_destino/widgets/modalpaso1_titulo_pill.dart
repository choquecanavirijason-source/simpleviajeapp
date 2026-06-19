import 'package:flutter/material.dart';

class Paso1TituloPill extends StatelessWidget {
  final String texto;
  const Paso1TituloPill({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 5,
      ), // Contenedor padre más grande
      decoration: BoxDecoration(
        color: Colors.transparent, // Contenedor padre transparente
        border: Border.all(
          color: Colors.red, // Borde rojo
          width: 2, // Grosor del borde
        ),
        borderRadius: BorderRadius.circular(
          25,
        ), // Radio del borde para el contenedor padre
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ), // Contenedor hijo
        decoration: BoxDecoration(
          color: Colors.white, // Fondo blanco para el contenedor hijo
          border: Border.all(
            color: Colors.black54, // Borde rojo
            width: 0.5, // Grosor del borde
          ),
          borderRadius: BorderRadius.circular(
            18,
          ), // Mismo radio para el contenedor hijo
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.touch_app_rounded,
              size: 18,
              color: Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              texto,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/* ejemplo de uso:
Paso1TituloPill(texto: _tituloPaso1),
*/
