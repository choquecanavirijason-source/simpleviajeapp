// core/widgets/cajas/info_card.dart

import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/utils/copiar.dart';

class InfoCard extends StatelessWidget {
  final String text;

  const InfoCard({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[100], // fondo suave
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Texto mostrado
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 🧩 Botón copiar
          CopiarIcono(texto: text), // core/widgets/utils/copiar.dart'
        ],
      ),
    );
  }
}
