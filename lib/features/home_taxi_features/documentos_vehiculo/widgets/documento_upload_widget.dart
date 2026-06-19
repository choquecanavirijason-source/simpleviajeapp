import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Widget para subir documento del conductor/vehículo
/// Permite al conductor subir documentos, pero NO puede verificarlos
/// La verificación solo se mostrará cuando esté en modo soloLectura (para admin)
class DocumentoUploadWidget extends StatefulWidget {
  final String titulo;
  final String? descripcion;
  final File? archivoInicial;
  final String? urlInicial;
  final bool verificado;
  final bool
  soloLectura; // Si es true, no se puede modificar (para modo taxista)
  final Function(File?)? onArchivoCambiado;
  final Function(bool)? onVerificacionCambiada;
  final bool requerido;

  const DocumentoUploadWidget({
    super.key,
    required this.titulo,
    this.descripcion,
    this.archivoInicial,
    this.urlInicial,
    this.verificado = false,
    this.soloLectura = false,
    this.onArchivoCambiado,
    this.onVerificacionCambiada,
    this.requerido = true,
  });

  @override
  State<DocumentoUploadWidget> createState() => _DocumentoUploadWidgetState();
}

class _DocumentoUploadWidgetState extends State<DocumentoUploadWidget> {
  File? _archivo;
  bool _verificado = false;

  @override
  void initState() {
    super.initState();
    _archivo = widget.archivoInicial;
    _verificado = widget.verificado;
  }

  Future<void> _seleccionarArchivo() async {
    if (widget.soloLectura) return;

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

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);

    if (picked != null) {
      final file = File(picked.path);
      setState(() => _archivo = file);
      widget.onArchivoCambiado?.call(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneArchivo = _archivo != null || widget.urlInicial != null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título y etiqueta de requerido
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.requerido)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Obligatorio',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            if (widget.descripcion != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.descripcion!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],

            const SizedBox(height: 12),

            // Preview del archivo o botón para subir
            InkWell(
              onTap: _seleccionarArchivo,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tieneArchivo
                        ? Colors.green.shade300
                        : (widget.requerido
                              ? Colors.orange.shade300
                              : Colors.grey.shade300),
                    width: 2,
                  ),
                ),
                child: tieneArchivo
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _archivo != null
                                ? Image.file(_archivo!, fit: BoxFit.cover)
                                : widget.urlInicial != null
                                ? Image.network(
                                    widget.urlInicial!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) {
                                      return const Center(
                                        child: Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                      );
                                    },
                                  )
                                : const SizedBox(),
                          ),
                          if (!widget.soloLectura)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _seleccionarArchivo,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.soloLectura
                                ? 'Sin documento'
                                : 'Toca para subir',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Indicador de estado (solo visible cuando está en modo lectura - para admin)
            if (widget.soloLectura && tieneArchivo)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _verificado
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _verificado ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _verificado ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: _verificado ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _verificado ? 'Verificado' : 'Pendiente de verificación',
                      style: TextStyle(
                        fontSize: 12,
                        color: _verificado
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
