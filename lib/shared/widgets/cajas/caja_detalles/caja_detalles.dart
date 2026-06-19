import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/etiquetas/etiqueta_estado.dart';

/// Caja para adjuntar/mostrar imagen de documento.
/// Estados del pill: "obligatorios", "pendiente" (default), "aprovado/aprobado", "rechazado".
class CajaDetalleImagen extends StatelessWidget {
  final String titulo; // Ej: "CI (frente)"
  final String estado; // default: pendiente
  final String? hint; // Ej: "Toca para seleccionar"
  final ImageProvider? image; // Network/File/Memory
  final Uint8List? imageBytes; // alternativa con bytes
  final VoidCallback onSeleccionar; // Tap en el área cuando no hay imagen
  final EdgeInsetsGeometry margin;
  final double aspectRatio;

  const CajaDetalleImagen({
    super.key,
    required this.titulo,
    required this.onSeleccionar,
    this.estado = "pendiente",
    this.hint,
    this.image,
    this.imageBytes,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    this.aspectRatio = 16 / 3, // default actual
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(18);
    // Gris único para ambos bordes (1 px)
    const borderColor = Color(0xFFD1D5DB); // gris 300 aprox.

    Widget buildHeader() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Row(
          children: [
            const Icon(
              Icons.image_outlined,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3F3F46),
                ),
              ),
            ),
            EtiquetaEstado(estado),
          ],
        ),
      );
    }

    Widget buildAreaImagen() {
      final hasImage = image != null || (imageBytes != null && image == null);
      final content = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: 1,
          ), // 👈 gris 1 px (interna)
        ),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasImage
                ? (image != null
                      ? Image(image: image!, fit: BoxFit.cover)
                      : Image.memory(imageBytes!, fit: BoxFit.cover))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: Color(0xFF4B5563),
                      ),
                      if (hint != null && hint!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          hint!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      );

      // Tap solo cuando NO hay imagen
      return hasImage
          ? content
          : InkWell(
              onTap: onSeleccionar,
              borderRadius: BorderRadius.circular(14),
              child: content,
            );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor,
          width: 1,
        ), // 👈 gris 1 px (externa)
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: buildAreaImagen(),
          ),
        ],
      ),
    );
  }
}
