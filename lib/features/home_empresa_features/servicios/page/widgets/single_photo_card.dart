// widgets/single_photo_card.dart
import 'dart:io';
import 'package:flutter/material.dart';

/// Card blanca con preview para una sola foto.
/// - [file]: imagen actual (o null si no hay)
/// - [onAddOrChange]: abrir picker / cambiar imagen
/// - [onRemove]: eliminar imagen
/// - [title]: (opcional) título mostrado a la derecha
class SinglePhotoCard extends StatelessWidget {
  const SinglePhotoCard({
    super.key,
    required this.file,
    required this.onAddOrChange,
    required this.onRemove,
    this.title = 'Foto del servicio',
  });

  final File? file;
  final VoidCallback onAddOrChange;
  final VoidCallback onRemove;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withOpacity(.08),
      child: InkWell(
        onTap: onAddOrChange,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(.25)),
          ),
          child: Row(
            children: [
              // Preview cuadrado
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 86,
                  height: 86,
                  color: Colors.grey.shade100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (file == null)
                        Icon(
                          Icons.add_a_photo_rounded,
                          size: 30,
                          color: cs.primary.withOpacity(.75),
                        )
                      else
                        Image.file(file!, fit: BoxFit.cover),
                      if (file != null)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: InkWell(
                            onTap: onRemove,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Texto y botones
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      file == null
                          ? 'Toca para agregar una imagen'
                          : 'Toca para cambiar la imagen',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: onAddOrChange,
                          icon: const Icon(
                            Icons.photo_library_rounded,
                            size: 18,
                          ),
                          label: Text(file == null ? 'Agregar' : 'Cambiar'),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (file != null)
                          TextButton.icon(
                            onPressed: onRemove,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
