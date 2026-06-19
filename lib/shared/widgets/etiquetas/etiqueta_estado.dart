import 'package:flutter/material.dart';

/// Etiqueta visual del estado de un documento o usuario.
/// Se puede tocar para abrir un modal con opciones de estado.
class EtiquetaEstado extends StatefulWidget {
  final String raw;
  final List<String>? opciones;
  final ValueChanged<String>? onEstadoCambiado;

  const EtiquetaEstado(
    this.raw, {
    super.key,
    this.opciones,
    this.onEstadoCambiado,
  });

  @override
  State<EtiquetaEstado> createState() => _EtiquetaEstadoState();
}

class _EtiquetaEstadoState extends State<EtiquetaEstado> {
  late String _estadoActual;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.raw.isEmpty ? 'pendiente' : widget.raw.toLowerCase();
  }

  @override
  void didUpdateWidget(covariant EtiquetaEstado oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el valor externo cambió, actualiza el estado interno
    if (widget.raw.toLowerCase() != _estadoActual.toLowerCase()) {
      setState(() {
        _estadoActual = widget.raw.toLowerCase();
      });
    }
  }

  /// 🔹 Cambia los colores, ícono y texto según el estado
  Map<String, dynamic> _getEstilo(String estado) {
    late Color bg, fg;
    late IconData icon;
    late String label;

    switch (estado) {
      case 'obligatorios':
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFEF4444);
        icon = Icons.error_outline;
        label = 'Obligatorios';
        break;
      case 'aprobado':
        bg = const Color(0xFFE8F7F1);
        fg = const Color(0xFF10B981);
        icon = Icons.check_circle_outline;
        label = 'Aprobado';
        break;
      case 'rechazado':
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFDC2626);
        icon = Icons.cancel_outlined;
        label = 'Rechazado';
        break;
      case 'sin imagen':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        icon = Icons.image_not_supported_outlined;
        label = 'Sin imagen';
        break;
      case 'ocupado':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        icon = Icons.event_busy;
        label = 'Ocupado';
        break;
      case 'disponible':
        bg = const Color(0xFFE8F7F1);
        fg = const Color(0xFF16A34A);
        icon = Icons.check_circle;
        label = 'Disponible';
        break;

      case 'suspendido':
        bg = const Color(0xFFF5F3FF); // lavanda claro
        fg = const Color(0xFF6D28D9); // violeta oscuro
        icon = Icons.pause_circle_outline; // ícono de pausa
        label = 'Suspendido';
        break;

      case 'pendiente':
      default:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFF59E0B);
        icon = Icons.hourglass_bottom_outlined;
        label = 'Pendiente';
    }

    return {'bg': bg, 'fg': fg, 'icon': icon, 'label': label};
  }

  @override
  Widget build(BuildContext context) {
    final estilo = _getEstilo(_estadoActual);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: estilo['bg'],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estilo['fg'], width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estilo['icon'], size: 16, color: estilo['fg']),
          const SizedBox(width: 6),
          Text(
            estilo['label'],
            style: TextStyle(color: estilo['fg'], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    // 🔹 Si no tiene opciones, solo muestra el contenido
    if (widget.opciones == null || widget.opciones!.isEmpty) {
      return content;
    }

    // 🔹 Si tiene opciones, abre el modal
    return GestureDetector(
      onTap: () async {
        if (widget.opciones == null || widget.opciones!.isEmpty) return;

        final seleccionado = await ModalSeleccionEstado.show(
          context,
          opciones: widget.opciones!,
          estadoActual: _estadoActual,
        );

        if (seleccionado != null) {
          // 🔹 refresca UI del chip inmediatamente
          setState(() {
            _estadoActual = seleccionado.toLowerCase();
          });

          // 🔹 y luego notifica al padre
          if (widget.onEstadoCambiado != null) {
            widget.onEstadoCambiado!(seleccionado);
          }
        }
      },
      child: MouseRegion(cursor: SystemMouseCursors.click, child: content),
    );
  }
}

/* Ejemplo de uso:
EtiquetaEstado(
  'pendiente',
  onEstadoCambiado: (nuevoEstado) {
    // Acción al cambiar el estado
    debugPrint('Nuevo estado: $nuevoEstado');
  },
  opciones: ['pendiente', 'aprobado', 'rechazado'],
),
*/

//import 'package:flutter/material.dart';

/// Modal inferior para seleccionar el estado del usuario.
/// Devuelve el estado seleccionado al cerrarse con "Aceptar".
class ModalSeleccionEstado extends StatefulWidget {
  final List<String> opciones;
  final String estadoActual;

  const ModalSeleccionEstado({
    super.key,
    required this.opciones,
    required this.estadoActual,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<String> opciones,
    required String estadoActual,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          ModalSeleccionEstado(opciones: opciones, estadoActual: estadoActual),
    );
  }

  @override
  State<ModalSeleccionEstado> createState() => _ModalSeleccionEstadoState();
}

class _ModalSeleccionEstadoState extends State<ModalSeleccionEstado> {
  late String _seleccionado;

  @override
  void initState() {
    super.initState();
    _seleccionado = widget.estadoActual;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Header del modal ---
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text(
            'Seleccionar nuevo estado',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // --- Lista de opciones ---
          ...widget.opciones.map((op) {
            final isSelected = op.toLowerCase() == _seleccionado.toLowerCase();

            return InkWell(
              onTap: () => setState(() => _seleccionado = op),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      op[0].toUpperCase() + op.substring(1),
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected
                            ? Colors.blue.shade700
                            : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // --- Botón confirmar ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Confirmar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
              onPressed: () => Navigator.pop(context, _seleccionado),
            ),
          ),
        ],
      ),
    );
  }
}
