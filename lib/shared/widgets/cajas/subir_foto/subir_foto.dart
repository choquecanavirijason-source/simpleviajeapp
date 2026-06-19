// ... imports
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SubirFotoWidget extends StatefulWidget {
  final IconData icono;
  final String texto;
  final void Function(File file)? onPicked;
  final String? initialUrl;
  final File? initialFile;

  const SubirFotoWidget({
    super.key,
    this.icono = Icons.upload,
    this.texto = "Subir logo",
    this.onPicked,
    this.initialUrl,
    this.initialFile,
  });

  @override
  State<SubirFotoWidget> createState() => _SubirFotoWidgetState();
}

class _SubirFotoWidgetState extends State<SubirFotoWidget> {
  File? _logoFile;

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Selecciona el origen de tu foto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);

      if (picked != null) {
        final file = File(picked.path);
        setState(() => _logoFile = file);
        widget.onPicked?.call(file);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = (source == ImageSource.camera)
          ? 'No se pudo abrir la cámara. Revisa permisos en Ajustes.'
          : 'No se pudo abrir la galería. Revisa permisos en Ajustes.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$msg\n$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? bgImage;
    final localFile = _logoFile ?? widget.initialFile;

    if (localFile != null) {
      bgImage = FileImage(localFile);
    } else if ((widget.initialUrl ?? '').isNotEmpty) {
      bgImage = NetworkImage(widget.initialUrl!);
    }

    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
            color: Colors.grey[200],
            image: (bgImage != null)
                ? DecorationImage(image: bgImage, fit: BoxFit.cover)
                : null,
          ),
          child: (bgImage == null)
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icono, size: 32, color: Colors.grey),
                    const SizedBox(height: 4),
                    Text(
                      widget.texto,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

/// Posiciones del badge de cámara
enum CameraBadgePosition { topLeft, topRight, bottomLeft, bottomRight, center }

class SubirFotoWidget2 extends StatefulWidget {
  final IconData icono;
  final String texto;
  final void Function(File file)? onPicked;
  final String? initialUrl;
  final File? initialFile;

  final AlignmentGeometry alignment;
  final CameraBadgePosition badgePosition;
  final Color badgeColor;

  const SubirFotoWidget2({
    super.key,
    this.icono = Icons.upload,
    this.texto = "Subir Logo",
    this.onPicked,
    this.initialUrl,
    this.initialFile,
    this.alignment = Alignment.center,
    this.badgePosition = CameraBadgePosition.center,
    this.badgeColor = Colors.blue,
  });

  @override
  State<SubirFotoWidget2> createState() => _SubirFotoWidget2State();
}

class _SubirFotoWidget2State extends State<SubirFotoWidget2> {
  File? _logoFile;

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Selecciona el origen de tu foto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);

      if (picked != null) {
        final file = File(picked.path);
        setState(() => _logoFile = file);
        widget.onPicked?.call(file);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = (source == ImageSource.camera)
          ? 'No se pudo abrir la cámara. Revisa permisos en Ajustes.'
          : 'No se pudo abrir la galería. Revisa permisos en Ajustes.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$msg\n$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? bgImage;
    final localFile = _logoFile ?? widget.initialFile;

    if (localFile != null) {
      bgImage = FileImage(localFile);
    } else if ((widget.initialUrl ?? '').isNotEmpty) {
      bgImage = NetworkImage(widget.initialUrl!);
    }

    const double size = 110;
    const double grosorBorde = 5.0;
    final Color bordeBlanco = Colors.white;
    final Color fondoAvatar = Theme.of(context).primaryColor;
    const Color colorContenido = Colors.white70;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: bordeBlanco, width: grosorBorde),
        color: fondoAvatar,
        image: (bgImage != null)
            ? DecorationImage(image: bgImage, fit: BoxFit.cover)
            : null,
      ),
      child: (bgImage == null)
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icono, size: 32, color: colorContenido),
                const SizedBox(height: 4),
                Text(
                  widget.texto,
                  style: const TextStyle(
                    fontSize: 12,
                    color: colorContenido,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : null,
    );

    final badge = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickImage,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.badgeColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
        ),
      ),
    );

    Widget positionedBadge;
    switch (widget.badgePosition) {
      case CameraBadgePosition.topLeft:
        positionedBadge = Positioned(top: 0, left: 0, child: badge);
        break;
      case CameraBadgePosition.topRight:
        positionedBadge = Positioned(top: 0, right: 0, child: badge);
        break;
      case CameraBadgePosition.bottomLeft:
        positionedBadge = Positioned(bottom: 0, left: 0, child: badge);
        break;
      case CameraBadgePosition.bottomRight:
        positionedBadge = Positioned(bottom: 0, right: 0, child: badge);
        break;
      case CameraBadgePosition.center:
        positionedBadge = Positioned.fill(child: Center(child: badge));
        break;
    }

    return Align(
      alignment: widget.alignment,
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          clipBehavior: Clip.none,
          children: [avatar, positionedBadge],
        ),
      ),
    );
  }
}
