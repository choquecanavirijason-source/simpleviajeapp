import 'package:flutter/material.dart';

class CajaInput extends StatelessWidget {
  const CajaInput({
    super.key,
    required this.texto,
    required this.icono,
    this.onTap,
  });

  final String texto;
  final IconData icono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);

    return Material(
      elevation: 4,
      shadowColor: Colors.black87,
      color: Colors.grey.shade300,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: Colors.white, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                texto,
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
              Icon(icono, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}

/* Uso:
CajaInput(
  texto: 'Selecciona una Empresa',
  icono: Icons.chevron_right,
  onTap: () {
  // 
  },
),
*/
