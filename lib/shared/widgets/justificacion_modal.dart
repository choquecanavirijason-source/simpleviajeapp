// lib/shared/widgets/justificacion_modal.dart
import 'package:flutter/material.dart';

class JustificacionModal {
  const JustificacionModal._();

  static Future<JustificacionResult?> show({
    required BuildContext context,
    String title = 'Cancelar viaje',
    String subtitle = '¿Por qué deseas cancelar?',
    List<String> motivos = const [
      'Ya no necesito el viaje',
      'Cambio de planes',
      'Conductor demora mucho',
      'Encontré otra opción',
      'Error en la fecha/hora',
      'Problema con el precio',
      'Otro motivo',
    ],
  }) async {
    return showModalBottomSheet<JustificacionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JustificacionModalContent(
        title: title,
        subtitle: subtitle,
        motivos: motivos,
      ),
    );
  }
}

/// Resultado del modal
class JustificacionResult {
  final bool confirmed;
  final String motivo;

  JustificacionResult({required this.confirmed, required this.motivo});
}

class _JustificacionModalContent extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> motivos;

  const _JustificacionModalContent({
    required this.title,
    required this.subtitle,
    required this.motivos,
  });

  @override
  State<_JustificacionModalContent> createState() =>
      _JustificacionModalContentState();
}

class _JustificacionModalContentState
    extends State<_JustificacionModalContent> {
  String? _motivoSeleccionado;
  final TextEditingController _otroController = TextEditingController();

  @override
  void dispose() {
    _otroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Subtítulo
          Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            'Esta acción no se puede deshacer.',
            style: TextStyle(color: Colors.red, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Motivos predefinidos
          ...widget.motivos.map(
            (motivo) => RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(motivo, style: const TextStyle(fontSize: 15)),
              value: motivo,
              groupValue: _motivoSeleccionado,
              onChanged: (value) {
                setState(() {
                  _motivoSeleccionado = value;
                  if (value != 'Otro motivo') {
                    _otroController.clear();
                  }
                });
              },
            ),
          ),

          // Campo "Otro motivo"
          if (_motivoSeleccionado == 'Otro motivo') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otroController,
              decoration: InputDecoration(
                hintText: 'Escribe aquí el motivo de la cancelación...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 12),

          // Botones
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _motivoSeleccionado == null
                      ? null
                      : () {
                          final motivoFinal =
                              _motivoSeleccionado == 'Otro motivo'
                              ? _otroController.text.trim()
                              : _motivoSeleccionado!;

                          if (motivoFinal.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Por favor escribe un motivo'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(
                            context,
                            JustificacionResult(
                              confirmed: true,
                              motivo: motivoFinal,
                            ),
                          );
                        },
                  child: const Text('Confirmar cancelación'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
