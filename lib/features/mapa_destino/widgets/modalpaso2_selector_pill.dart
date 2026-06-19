import 'package:flutter/material.dart';

class Paso2SelectorPill extends StatelessWidget {
  const Paso2SelectorPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_taxi_rounded, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.accessibility_new_rounded,
            size: 18,
            color: Colors.black87,
          ),
        ],
      ),
    );
  }
}

/* Ejemplo de uso:
Paso2SelectorPill(),
*/
