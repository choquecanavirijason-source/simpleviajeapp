import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/documento_config_model.dart';
import 'documento_upload_widget.dart';

/// Widget que renderiza diferentes tipos de campos según la configuración
/// Puede mostrar: fotos (DocumentoUploadWidget), campos de texto o campos numéricos
class CampoDinamicoWidget extends StatelessWidget {
  final DocumentoConfig documento;
  final File? archivoInicial;
  final String? valorTextoInicial;
  final bool soloLectura;
  final Function(File?)? onArchivoCambiado;
  final Function(String?)? onTextoCambiado;

  const CampoDinamicoWidget({
    super.key,
    required this.documento,
    this.archivoInicial,
    this.valorTextoInicial,
    this.soloLectura = false,
    this.onArchivoCambiado,
    this.onTextoCambiado,
  });

  @override
  Widget build(BuildContext context) {
    // Si es de tipo foto, usar el widget existente
    if (documento.tipo == 'foto') {
      return DocumentoUploadWidget(
        titulo: documento.nombre,
        descripcion: documento.descripcion,
        archivoInicial: archivoInicial,
        requerido: documento.requerido ?? false,
        soloLectura: soloLectura,
        onArchivoCambiado: onArchivoCambiado,
      );
    }

    // Para texto o número, usar TextField
    return _buildCampoTexto(context);
  }

  Widget _buildCampoTexto(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título y etiqueta de requerido
            Row(
              children: [
                Expanded(
                  child: Text(
                    documento.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (documento.requerido ?? false)
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
                if (documento.requerido == false)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Opcional',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (documento.descripcion != null &&
                documento.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                documento.descripcion!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Campo de texto según tipo
            TextFormField(
              initialValue: valorTextoInicial,
              enabled: !soloLectura,
              keyboardType: documento.tipo == 'numero'
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: documento.tipo == 'numero'
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              decoration: InputDecoration(
                hintText: documento.tipo == 'numero'
                    ? 'Ingresa un número'
                    : 'Ingresa el texto',
                prefixIcon: Icon(
                  documento.tipo == 'numero'
                      ? Icons.numbers
                      : Icons.text_fields,
                  color: Colors.green,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: soloLectura ? Colors.grey.shade100 : Colors.white,
              ),
              validator: (value) {
                if ((documento.requerido ?? false) &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Este campo es obligatorio';
                }
                return null;
              },
              onChanged: onTextoCambiado,
            ),
          ],
        ),
      ),
    );
  }
}
