import 'package:flutter/material.dart';
import 'app_borders.dart';
import '../layout/padding_margin.dart';
import 'package:buses2/shared/theme/app_colors.dart';

// Caja estilo 1
class Caja1 extends StatelessWidget {
  final Icon icono;
  final String titulo;
  final String subtitulo;

  const Caja1({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingABCD, // padding_margin.dart
      margin: AppSpacing.mAll, // padding_margin.dart
      decoration: borde2(
        // Bordes decorations.dart
        backgroundColor: AppColors.fondoCaja1, // Color Fondo Caja
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icono, // icono
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo, // texto
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo, // texto
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.subtitulo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Caja estilo 2 arreglar esta caja, esta feo
class Caja2 extends StatelessWidget {
  final Icon icono;
  final String titulo;
  final String subtitulo;

  const Caja2({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingABCD,
      margin: AppSpacing.mAll,
      decoration: borde1(
        // Bordes decorations.dart
        backgroundColor: Colors.white, // Color Fondo Caja
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          icono,
        ],
      ),
    );
  }
}

// Más cajas acá...
