// import 'package:buses2/shared/widgets/cajas/caja_subir_foto/box_subir_foto.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Caja reutilizable para subir o mostrar archivos (con pick/redimensionado interno opcional)
class FileBox extends StatelessWidget {
  const FileBox({
    super.key,
    required this.icon,
    required this.label,
    this.file, // archivo local para preview
    this.imageUrl, // url remota para preview
    this.onChanged, // callback al seleccionar foto
    this.enablePicker = true, // si true, maneja el pick internamente
    this.source = FileSource.camera, // cámara por defecto
    this.maxDimension = 720, // tope de pixels (lado mayor)
    this.imageQuality = 80, // 0-100 (compresión JPEG)
    this.height = 160,
    this.showChangeButton = true,
  });

  final IconData icon;
  final String label;

  final File? file;
  final String? imageUrl;

  /// Devuelve el archivo seleccionado (ya redimensionado) al padre
  final ValueChanged<File?>? onChanged;

  /// Si `true`, FileBox abre la cámara/galería internamente
  final bool enablePicker;

  /// Fuente de imagen
  final FileSource source;

  /// Límite de tamaño (lado mayor) al capturar/seleccionar
  final int maxDimension;

  /// Calidad JPEG (si aplica)
  final int imageQuality;

  final double height;
  final bool showChangeButton;

  Future<void> _handlePick(BuildContext context) async {
    if (!enablePicker) return;
    final picker = ImagePicker();

    final imgSource = switch (source) {
      FileSource.gallery => ImageSource.gallery,
      FileSource.camera => ImageSource.camera,
    };

    final picked = await picker.pickImage(
      source: imgSource,
      maxWidth: maxDimension.toDouble(),
      maxHeight: maxDimension.toDouble(),
      imageQuality: imageQuality,
    );

    if (picked != null) {
      onChanged?.call(File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final hasLocal = file != null;
    final hasRemote = (imageUrl != null && imageUrl!.isNotEmpty);

    Widget content;

    if (hasLocal || hasRemote) {
      final imageWidget = hasLocal
          ? Image.file(
              file!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
            )
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
            );

      content = Stack(
        children: [
          ClipRRect(borderRadius: radius, child: imageWidget),
          if (enablePicker && showChangeButton)
            Positioned(
              right: 8,
              bottom: 8,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.65),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _handlePick(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Cambiar'),
              ),
            ),
        ],
      );
    } else {
      content = Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.blueGrey.shade200),
          color: Colors.blueGrey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueGrey),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      );
    }

    return enablePicker
        ? InkWell(
            onTap: () => _handlePick(context),
            borderRadius: radius,
            child: content,
          )
        : content;
  }
}

/// Fuente del archivo (cámara o galería)
enum FileSource { camera, gallery }

/* Uso:
FileBox(
  icon: Icons.image,
  label: 'Foto de perfil',
  file: _selectedFile, // archivo local
  imageUrl: _imageUrl, // URL remota (opcional)
  onChanged: (file) {
    setState(() {
      _selectedFile = file; // Actualiza el estado con el nuevo archivo
    });
  },
),
*/
